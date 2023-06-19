from PIL import Image
from functools import cache
from collections import namedtuple
Region = namedtuple("Region", ["left", "upper", "right", "lower"])
glasses = Image.open("./pv.webp")
glasses = glasses.crop(glasses.getbbox())
def scale(i, x):
    if i.size[0] // x == 0 or i.size[1] // x == 0:
        return False
    return i.resize((int(i.size[0] // x), int(i.size[1] // x)))
output = Image.new("RGBA", (256, 256))
def paste_at_centre(src: Image, x, y):
    #dc = Region(*dc)
    left = x - src.size[0] // 2
    upper = y - src.size[1] // 2
    output.alpha_composite(src, (left, upper))

paste_at_centre(glasses, output.size[0] // 2, output.size[1] // 2)
def do_transpositions(im, parity, count):
    if count == 0: return im
    if parity: 
        return do_transpositions(im.transpose(Image.Transpose.ROTATE_90), parity, count - 1)
    else:
        return do_transpositions(im.transpose(Image.Transpose.ROTATE_270), parity, count - 1)
k = 1
while True:
    #output.show()
    s = 2**k
    bounds = Region(*output.getbbox())
    print(bounds)
    if not scale(output, s):
        break
    g = do_transpositions(scale(output, s), True, k)
    h = do_transpositions(scale(output, s), False, k)
    paste_at_centre(g, bounds.left, bounds.upper)
    paste_at_centre(h, bounds.right, bounds.upper)
    paste_at_centre(g, bounds.left, bounds.lower)
    paste_at_centre(h, bounds.right, bounds.lower)
    k += 1
output.show()
output.save("./pvf.webp")