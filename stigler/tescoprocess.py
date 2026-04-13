from curl_cffi import AsyncSession
from bs4 import BeautifulSoup
import asyncio
import re
import base64
from urllib.parse import unquote
import collections
import json

targets = (
    "energy",
    "fat",
    "saturate",
    "carbohydrate",
    "sugar",
    "protein",
    "salt",
    "fibre",
    "starch"
)

def fix_commas(x):
    return re.sub(r"(\d+),(\d{1,2})", r"\1.\2", re.sub(r"(\d+),(\d{3})", r"\1\2", x))

def process():
    with open("tesco.jsonl", "r") as f:
        with open("items.jsonl", "a") as h:
            for line in f:
                obj = json.loads(line.strip())
                cost = obj["price"]
                values = {}

                #print(obj["title"], obj["details"]["nutrition"])
                nutrition = obj["details"]["nutrition"]

                try:
                    for target in targets:
                        # TODO check perComp first line is reasonable
                        for row in nutrition:
                            label = row["name"]
                            value = row["perComp"]
                            if label and target.lower() in label.lower():
                                value = fix_commas(value.lower().removeprefix("(").removeprefix("nutritioninformation/").split("/")[0].split("(")[0].strip().split("kcal")[0])
                                if value.lower() == "trace" or value == "-" or value == "nil": value = "0"
                                is_kj = "kj" in value or "kj" in label.split("/")[0].strip()
                                if target not in values:
                                    if is_kj:
                                        value = value.split("kj")[0].removeprefix("<").strip().replace(" ", "")
                                        value = float(value) / 4.2 # kcal
                                    elif value.endswith("%"):
                                        value = value.removeprefix("less than").strip().removeprefix("<").removesuffix("%")
                                        value = float(value) / 100 * 1000
                                    else:
                                        value = value.removeprefix("less than").replace(" ", "").removeprefix("<").removesuffix(")").removesuffix("*").removesuffix("g").removesuffix("calories").removeprefix("=")
                                        value = float(value)
                                    values[target] = value
                                    break
                except:
                    import traceback
                    traceback.print_exc()

                if cost["unitOfMeasure"] not in {"ltr", "kg"}:
                    continue
                cost = cost["unitPrice"]

                if values:
                    json.dump({
                        "slug": "tesco/" + obj["id"],
                        "nutrition": values,
                        "cost": cost,
                        "name": obj["title"]
                    }, h)
                    h.write("\n")

process()
