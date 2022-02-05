from PIL import Image
import numpy.fft as fft
import numpy as np
import random
import math

w, h = 512, 512
out = np.zeros((w, h, 3), dtype=np.uint8)

def bitstring(x): return f"{x:06b}"
def concat(l):
    out = []
    for m in l:
        for n in m:
            out.append(n)
    return "".join(out)

for r in range(2**6):
    for g in range(2**6):
        for b in range(2**6):
            a = concat(zip(*(bitstring(r), bitstring(g), bitstring(b))))
            a = int(a, 2)
            x, y = a & 0b111111111, a >> 9
            out[x, y] = (r << 2, g << 2, b << 2)

out = Image.fromarray(out, "RGB")
out.save("/tmp/out.png")