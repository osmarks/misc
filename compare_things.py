import json
import random

with open("nouns.json", "r") as f:
    nouns = set(json.load(f))

with open("comparisons.jsonl", "a") as f:
    def writeline(obj):
        f.write(json.dumps(obj, separators=(",", ":")) + "\n")

    for noun in nouns:
        other_noun = random.choice(list(nouns - {noun}))
        print(noun, "/",other_noun)
        pref = input("a/b/e/x/y: ")
        writeline({"a": noun, "b": other_noun, "pref": pref})
        if pref == "x":
            writeline({"a": noun, "b": other_noun, "pref": "x"})
            nouns.remove(noun)
        elif pref == "y":
            writeline({"a": other_noun, "b": noun, "pref": "y"})
            nouns.remove(other_noun)

        f.flush()
