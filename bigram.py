from PIL import Image
import sys
from collections import defaultdict
import math

out = Image.new("RGB", (256, 256))

ctr = defaultdict(lambda: 0)

BS = 2<<18

with open(sys.argv[2], "rb") as f:
    last = b""
    while xs := f.read(BS):
        for a, b in zip(last + xs, last + xs[1:]):
            ctr[a, b] += 1
        last = bytes([xs[-1]])

ctrl = { k: math.log(v) for k, v in ctr.items() }
maxv = max(ctrl.values())
for x, y in ctrl.items():
    s = int(y / maxv * 255)
    out.putpixel((x[0], x[1]), (0, s, 0))

out.save(sys.argv[1])
