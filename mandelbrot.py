from PIL import Image
import math

H = 512
W = math.floor(H * 1.5)
ITERATIONS = 32
Wdiv3, Hdiv2 = W / 3, H / 2
im = Image.new("RGB", (W, H))
data = im.load()
for px in range(W):
    for py in range(H):
        x, y = px / Wdiv3 - 2, py / Hdiv2 - 1
        c = x + (y*1j)
        v = 0j
        for it in range(ITERATIONS + 1):
            if abs(v) > 5:
                break
            nondiverging_iterations = it
            v = v*v + c
        if ITERATIONS != nondiverging_iterations:
            data[px, py] = (0, 0, math.floor(255 * min(nondiverging_iterations / ITERATIONS, 1)))
im.save("/tmp/mandelbrot.png")