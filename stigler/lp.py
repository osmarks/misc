import scipy.optimize
import json
import numpy as np

foods = []

constraint_metrics = {
    "energy": (2000, 3000),
    "fat": (50, 90),
    "saturate": (0, 25),
    "carbohydrate": (0, 5000),
    "sugar": (0, 5000),
    "protein": (150, 500),
    "salt": (0, 6),
    "fibre": (30, 60),
    "starch": (0, 5000)
}

# thanks, Codex
protein_quality = {
    "protein_supplement": 1.00,
    "egg": 1.00,
    "dairy": 0.98,
    "meat_fish": 1.00,
    "soy": 0.95,
    "legume": 0.80,
    "nuts_seeds": 0.70,
    "pseudo_meat": 0.75,
    "cereal": 0.55,
    "mixed_or_ambiguous": 0.70,
    "unknown": 0.65,
}

protein_keywords = {
    "protein_supplement": [
        "protein powder", "protein shake", "protein bar", "clear whey",
        "mass gainer", "meal replacement", "rtd protein",
    ],

    "egg": [
        "egg", "eggs", "omelette", "omelet", "frittata", "quiche",
        "egg mayo", "egg salad",
    ],

    "dairy": [
        "milk", "whole milk", "semi skimmed", "skimmed", "yoghurt", "yogurt",
        "greek yoghurt", "greek yogurt", "skyr", "kefir", "buttermilk",
        "cheese", "cheddar", "mozzarella", "parmesan", "grana padano",
        "pecorino", "edam", "gouda", "brie", "camembert", "stilton",
        "halloumi", "paneer", "cottage cheese", "cream cheese", "quark",
        "ricotta", "mascarpone", "whey", "casein", "custard",
    ],

    "meat_fish": [
        "chicken", "turkey", "beef", "steak", "mince", "pork", "ham",
        "bacon", "gammon", "sausage", "salami", "pepperoni", "chorizo",
        "prosciutto", "lamb", "mutton", "duck", "venison", "veal",
        "liver", "kidney", "black pudding", "pate", "paté",
        "fish", "salmon", "tuna", "cod", "haddock", "mackerel", "sardine",
        "sardines", "anchovy", "anchovies", "trout", "pollock", "hake",
        "seabass", "sea bass", "bream", "prawn", "prawns", "shrimp",
        "crab", "lobster", "mussel", "mussels", "clam", "clams",
        "oyster", "oysters", "squid", "calamari", "octopus",
    ],

    "soy": [
        "soy", "soya", "soybean", "soybeans", "tofu", "tempeh", "edamame",
        "miso", "natto", "tvp", "textured vegetable protein",
        "soy mince", "soya mince", "soy chunks", "soya chunks",
        "soy protein", "soya protein",
    ],

    "legume": [
        "bean", "beans", "baked beans", "kidney bean", "kidney beans",
        "black bean", "black beans", "pinto", "haricot", "cannellini",
        "borlotti", "butter bean", "butter beans", "broad bean", "broad beans",
        "fava", "lentil", "lentils", "red lentil", "green lentil",
        "puy", "chickpea", "chickpeas", "gram", "split pea", "split peas",
        "pea", "peas", "yellow pea", "green pea", "garden peas",
        "mung", "adzuki", "azuki", "urad",
        "hummus", "houmous", "falafel",
    ],

    "nuts_seeds": [
        "peanut", "peanuts", "peanut butter",
        "almond", "almonds", "cashew", "cashews", "walnut", "walnuts",
        "hazelnut", "hazelnuts", "pecan", "pecans", "pistachio", "pistachios",
        "macadamia", "brazil nut", "brazil nuts", "pine nut", "pine nuts",
        "mixed nuts",
        "seed", "seeds", "pumpkin seed", "pumpkin seeds", "sunflower seed",
        "sunflower seeds", "sesame", "tahini", "linseed", "flax", "flaxseed",
        "chia", "hemp", "poppy seed", "poppy seeds",
    ],

    "pseudo_meat": [
        "seitan", "mycoprotein", "quorn", "meat free", "meat-free",
        "plant based", "plant-based", "vegan mince", "veg mince",
        "meatless", "veggie burger", "vegetarian burger",
    ],

    "cereal": [
        "bread", "wholemeal bread", "wholewheat bread", "toastie", "toast",
        "roll", "rolls", "bagel", "bagels", "bap", "baps", "bun", "buns",
        "pitta", "pita", "wrap", "wraps", "naan", "flatbread", "crumpet",
        "muffin", "english muffin", "teacake", "scone",
        "flour", "wheat", "wholewheat", "wholemeal", "bran", "germ",
        "semolina", "bulgur", "burghul", "freekeh", "couscous",
        "rice", "brown rice", "white rice", "basmati", "jasmine rice",
        "wild rice", "risotto rice", "arborio",
        "oat", "oats", "oatmeal", "porridge", "muesli", "granola",
        "barley", "pearl barley", "rye", "spelt", "farro", "emmer",
        "einkorn", "millet", "sorghum", "maize", "corn", "polenta",
        "quinoa", "buckwheat", "amaranth", "teff",
        "cereal", "breakfast cereal", "flakes", "bran flakes", "cornflakes",
        "weetabix", "shredded wheat", "rice krispies", "special k", "cheerios",
        "pasta", "wholewheat pasta", "wholemeal pasta", "fresh pasta",
        "dried pasta", "egg pasta", "noodle", "noodles", "ramen", "udon",
        "soba", "vermicelli", "cappelletti", "tortellini", "ravioli",
        "lasagne", "lasagna", "cannelloni", "gnocchi",
        "spaghetti", "linguine", "fettuccine", "tagliatelle", "pappardelle",
        "fusilli", "penne", "rigatoni", "macaroni", "farfalle", "conchiglie",
        "shells", "orecchiette", "bucatini", "capellini", "angel hair",
        "tagliolini", "casarecce", "cavatappi", "tortiglioni", "ditalini",
        "orzo", "strozzapreti", "radiatori",
    ],

    "mixed_or_ambiguous": [
        "ready meal", "meal deal", "sandwich", "burger", "pizza", "pie",
        "sausage roll", "pasty", "curry", "stew", "chilli", "chili",
        "soup", "salad", "pasta bake", "lasagne al forno", "noodle pot",
    ],
}

def protein_quality_factor(name):
    s = name.lower()
    for cls, kws in protein_keywords.items():
        for kw in kws:
            if kw in s:
                return protein_quality[cls]
    return protein_quality["unknown"]

mask_data_errors = {
    "tesco/293283636",
    "tesco/262750183"
}

with open("items.jsonl", "r") as f:
    for line in f:
        obj = json.loads(line.strip())
        if obj["slug"] not in mask_data_errors:
            if "protein" in obj["nutrition"]:
                obj["nutrition"]["protein"] *= protein_quality_factor(obj["name"])
            foods.append(obj)

cost = np.zeros(len(foods))
constraints_mtx = np.zeros((len(foods), len(constraint_metrics) * 2))

for i, food in enumerate(foods):
    cost[i] = food["cost"]
    for j, metric in enumerate(constraint_metrics):
        # greater than/less than
        constraints_mtx[i, j*2] = -food["nutrition"].get(metric, 0)
        constraints_mtx[i, j*2+1] = food["nutrition"].get(metric, 0)

constraints_vec = np.zeros(len(constraint_metrics)*2)
for j, (lb, ub) in enumerate(constraint_metrics.values()):
    constraints_vec[j*2] = -lb
    constraints_vec[j*2+1] = ub

print(cost, constraints_mtx, constraints_vec)

res = scipy.optimize.linprog(cost, A_ub=constraints_mtx.T, b_ub=constraints_vec)
print(res)

for i, v in enumerate(res.x):
    if v > 0:
       print(foods[i], v)
