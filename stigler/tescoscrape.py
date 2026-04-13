import argparse
import asyncio
import json
import sys

from curl_cffi import AsyncSession


XAPI_URL = "https://xapi.tesco.com/"

# This key is shipped to browsers in Tesco's own groceries page config.
XAPI_KEY = "TvOSZJHlEk0pjniDGQFAc9Q59WGAR4dA"

HEADERS = {
    "accept": "application/json",
    "content-type": "application/json",
    "origin": "https://www.tesco.com",
    "referer": "https://www.tesco.com/groceries/en-GB/search?consumer=ghsapp-uk",
    "x-apikey": XAPI_KEY,
}

DEFAULT_TERMS = [
    "bread",
    "butter",
    "cheese",
    "egg",
    "flour",
    "milk",
    "oats",
    "pasta",
    "potato",
    "rice",
    "tomato",
    "vegetable",
]

TAXONOMY_QUERY = """
query Taxonomy($includeInspirationEvents: Boolean = false, $configs: [ConfigArgType]) {
  taxonomy(includeInspirationEvents: $includeInspirationEvents, configs: $configs) {
    catId: id
    name
    label
    parent
    children {
      catId: id
      name
      label
      parent
      children {
        catId: id
        name
        label
        parent
        children {
          catId: id
          name
          label
          parent
        }
      }
    }
  }
}
"""

SEARCH_QUERY = """
query Search($query: String!, $page: Int, $count: Int, $sortBy: String) {
  search(query: $query, page: $page, count: $count, sortBy: $sortBy) {
    results {
      node {
        ... on ProductInterface {
          id
          tpnb
          tpnc
          gtin
          title
          brandName
          superDepartmentName
          departmentName
          aisleName
          shelfName
          price {
            actual
            unitPrice
            unitOfMeasure
          }
        }
      }
    }
  }
}
"""

CATEGORY_QUERY = """
query Category($facet: ID, $page: Int, $count: Int, $sortBy: String) {
  category(facet: $facet, page: $page, count: $count, sortBy: $sortBy) {
    info {
      total
      page
      count
      pageSize
      offset
    }
    results {
      node {
        ... on ProductInterface {
          id
          tpnb
          tpnc
          gtin
          title
          brandName
          superDepartmentName
          departmentName
          aisleName
          shelfName
          price {
            actual
            unitPrice
            unitOfMeasure
          }
        }
      }
    }
  }
}
"""

PRODUCT_QUERY = """
query GetProduct($tpnc: String) {
  product(tpnc: $tpnc) {
    id
    tpnb
    tpnc
    gtin
    title
    brandName
    description
    foodIcons
    superDepartmentName
    departmentName
    aisleName
    shelfName
    price {
      actual
      unitPrice
      unitOfMeasure
    }
    details {
      ingredients
      netContents
      packSize {
        value
        units
      }
      nutrition {
        name
        perComp: value1
        perServing: value2
        referenceIntake: value3
        referencePercentage: value4
      }
      guidelineDailyAmount {
        title
        dailyAmounts {
          name
          value
          percent
          rating
        }
      }
      productMarketing
      preparationAndUsage
      storage
      features
      healthClaims
    }
  }
}
"""


async def graphql(session, query, variables):
    while True:
        response = await session.post(
            XAPI_URL,
            json={"query": query, "variables": variables},
        )
        if response.status_code != 504:
            response.raise_for_status()
        payload = response.json()
        if payload.get("errors"):
            print(json.dumps(payload["errors"], indent=2))
        else:
            return payload["data"]


async def search_page(session, term, page, count):
    data = await graphql(
        session,
        SEARCH_QUERY,
        {"query": term, "page": page, "count": count, "sortBy": "price-ascending"},
    )
    nodes = []
    for result in data["search"]["results"]:
        node = result.get("node")
        if node and node.get("tpnc"):
            nodes.append(node)
    return nodes


async def category_page(session, cat_id, page, count):
    data = await graphql(
        session,
        CATEGORY_QUERY,
        {"facet": cat_id, "page": page, "count": count, "sortBy": "price-ascending"},
    )
    category = data["category"]
    nodes = []
    for result in category["results"]:
        node = result.get("node")
        if node and node.get("tpnc"):
            nodes.append(node)
    return category["info"], nodes


async def get_taxonomy(session):
    data = await graphql(
        session,
        TAXONOMY_QUERY,
        {"includeInspirationEvents": False, "configs": []},
    )
    return data["taxonomy"]


def flatten_taxonomy(nodes, path=()):
    for node in nodes:
        current_path = (*path, node["name"])
        yield {
            "catId": node["catId"],
            "name": node["name"],
            "label": node["label"],
            "path": " > ".join(current_path),
        }
        yield from flatten_taxonomy(node.get("children") or [], current_path)


def category_filter(categories, args):
    selected = categories
    if args.category_label:
        selected = [c for c in selected if c["label"] in args.category_label]
    if args.category_contains:
        needles = [needle.lower() for needle in args.category_contains]
        selected = [
            c for c in selected
            if any(needle in c["path"].lower() for needle in needles)
        ]
    return selected


async def get_product(session, tpnc):
    data = await graphql(session, PRODUCT_QUERY, {"tpnc": tpnc})
    return data["product"]


async def bounded_gather(limit, items, fn):
    semaphore = asyncio.Semaphore(limit)

    async def run(item):
        async with semaphore:
            return await fn(item)

    return await asyncio.gather(*(run(item) for item in items))


async def scrape(args):
    seen = set()

    async with AsyncSession(headers=HEADERS, impersonate="chrome120", timeout=30) as session:
        with open(args.output, "w") as output:
            if args.categories:
                taxonomy = await get_taxonomy(session)
                categories = category_filter(list(flatten_taxonomy(taxonomy)), args)
                print(f"{len(categories)} categories selected", file=sys.stderr)

                for category in categories:
                    print(f"category {category['path']!r}", file=sys.stderr)
                    for page in range(1, args.pages + 1):
                        info, rows = await category_page(
                            session, category["catId"], page, args.count
                        )
                        if not rows:
                            break

                        rows = [row for row in rows if row["tpnc"] not in seen]
                        for row in rows:
                            seen.add(row["tpnc"])

                        products = await bounded_gather(
                            args.concurrency,
                            rows,
                            lambda row: get_product(session, row["tpnc"]),
                        )

                        for product in products:
                            product["matchedCategory"] = category
                            json.dump(product, output, ensure_ascii=False)
                            output.write("\n")

                        output.flush()
                        print(
                            f"  page {page}: {len(products)} new products "
                            f"({info['total']} listed)",
                            file=sys.stderr,
                        )

                        if info["offset"] + info["count"] >= info["total"]:
                            break
                return

            terms = args.term or DEFAULT_TERMS
            for term in terms:
                print(f"search {term!r}", file=sys.stderr)
                for page in range(1, args.pages + 1):
                    rows = await search_page(session, term, page, args.count)
                    if not rows:
                        break

                    rows = [row for row in rows if row["tpnc"] not in seen]
                    for row in rows:
                        seen.add(row["tpnc"])

                    products = await bounded_gather(
                        args.concurrency,
                        rows,
                        lambda row: get_product(session, row["tpnc"]),
                    )

                    for product in products:
                        product["matchedSearchTerm"] = term
                        json.dump(product, output, ensure_ascii=False)
                        output.write("\n")

                    output.flush()
                    print(
                        f"  page {page}: {len(products)} new products",
                        file=sys.stderr,
                    )

                    if len(rows) < args.count:
                        break


def parse_args():
    parser = argparse.ArgumentParser(
        description="Scrape Tesco-owned price and nutrition data through Tesco XAPI."
    )
    parser.add_argument("term", nargs="*", help="Search terms to scrape")
    parser.add_argument("-o", "--output", default="tesco.jsonl")
    parser.add_argument(
        "--categories",
        action="store_true",
        help="Scrape Tesco taxonomy categories instead of keyword search.",
    )
    parser.add_argument(
        "--category-label",
        action="append",
        choices=["superDepartment", "department", "aisle", "shelf"],
        help="Restrict --categories to a taxonomy level. Repeatable.",
    )
    parser.add_argument(
        "--category-contains",
        action="append",
        help="Restrict --categories to paths containing this text. Repeatable.",
    )
    parser.add_argument("--pages", type=int, default=2)
    parser.add_argument("--count", type=int, default=48)
    parser.add_argument("--concurrency", type=int, default=8)
    return parser.parse_args()


if __name__ == "__main__":
    asyncio.run(scrape(parse_args()))
