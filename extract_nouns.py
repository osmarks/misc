import openai
import json
import os
import shelve
import re
import random

openai.api_key = os.environ["OPENAI_API_KEY"]

client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

def chunks(text, size):
    out = [""]
    for line in text.split("\n"):
        out[-1] += line + "\n"
        if len(out[-1]) > size:
            out.append("")
    return [ x.removesuffix("\n") for x in out if x ]

def extract_nouns(text):
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "user", "content": f"""Extract all unique simple noun phrases from this document and put them in a JSON array in the singular:
```
{text}
```"""}],
        response_format={"type": "json_object"},
        max_tokens=16384,
        temperature=0.2 # should be 0 but repetition issues at 0
    )
    result = json.loads(completion.choices[0].message.content)
    return result[next(iter(result.keys()))]

with open("../website/strings.json", "r") as f:
    strings = json.load(f)

nouns = set()
with shelve.open("nouns_cache.db") as db:
    for bigstring in strings:
        for string in chunks(bigstring, 8192):
            if nouns: print(random.choices(list(nouns), k=10))
            if string in db:
                nouns.update(db[string])
            else:
                print("reading:", string[:100])
                s_nouns = extract_nouns(string)
                nouns.update(s_nouns)
                print(len(s_nouns), "/", len(nouns))
                db[string] = s_nouns

with open("nouns.json", "w") as f:
    json.dump(list(nouns), f)
