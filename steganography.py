from PIL import Image
import numpy.fft as fft
import numpy as np
import random
import math

with Image.open("/tmp/in.png") as im:
    rgb_im = im.convert("RGB")
    data = np.asarray(rgb_im, dtype=np.uint8)
out = np.zeros_like(data)
#out2 = np.zeros_like(data)

random.seed(4)

def operate_on_channel(n):
    red = data[..., n]

    red = fft.fft2(red)
    red = fft.fftshift(red)

    w, h = red.shape
    mask = np.full_like(red, 1)
    midx, midy = w // 2, h // 2
    print(red.shape)
    
    J = 48
    for x in range(midx - J, midx + J + 1):
        for y in range(midy - J, midy + J + 1):
            mask[x, y] = random.uniform(0.0, 2.0)
    """
    for x in range(w):
        for y in range(h):
            dist = (x - midx) ** 2 + abs(y - midy) ** 2
            #if 1024 > dist > 4:
    #                mask[x, y] = 1
            #mask[x, y] = math.sqrt(dist) / 500
            if dist < 256: mask[x, y] = 1
    """
    """
    for x in range(w):
        for y in range(h):
            mask[x, y] = random.uniform(0.7, 1)
    """
    red = fft.ifftshift(red * mask)
    rfft = fft.ifft2(red)
    red = np.abs(np.real(rfft))
    #red2 = np.abs(np.imag(rfft))
    #red = np.log(np.abs(np.real(red)))
    #red = np.abs(mask)

    red = red * (255 / np.max(red))
    #red2 = red2 * (255 / np.max(red2))

    out[..., n] = red
    #out2[..., n] = red2

for i in range(3):
    operate_on_channel(i)

out = Image.fromarray(out, "RGB")
out.save("/tmp/out.png")
#out2 = Image.fromarray(out2, "RGB")
#out2.save("/tmp/out2.png")