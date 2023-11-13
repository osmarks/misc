import json
from PIL import Image
import os

def chunks(x, l):
    return [ x[i:i+l] for i in range(0, len(x), l) ]

ls = []
for f in os.listdir("cc-tiles"):
    if "fs8" in f:
        im = Image.open(os.path.join("cc-tiles", f))
        ls.append(([ int(b.hex().rjust(6, "0"), 16) for b in chunks(im.palette.getdata()[1], 3) ], list(im.getdata())))

print(json.dumps(ls).replace("[", "{").replace("]", "}"))