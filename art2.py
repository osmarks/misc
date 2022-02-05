from PIL import Image
import numpy.fft as fft
import numpy as np
import random
import math

w, h = 512, 512
out = np.zeros((w, h, 3))

random.seed(4)

def operate_on_channel(n):
    mask = np.full((w, h), 1)
    midx, midy = w // 2, h // 2
    
    J = 1
    for x in range(midx - J, midx + J + 1):
        for y in range(midy - J, midy + J + 1):
            mask[x, y] = 0.5
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
    channel = fft.ifftshift(mask)
    rfft = fft.ifft2(channel)
    channel = np.abs(np.real(rfft))
    #red2 = np.abs(np.imag(rfft))
    #red = np.log(np.abs(np.real(red)))
    #red = np.abs(mask)

    channel = channel * (255 / np.max(channel))
    #red2 = red2 * (255 / np.max(red2))

    out[..., n] = channel

for i in range(3):
    operate_on_channel(i)

out = Image.fromarray(out, "RGB")
out.save("/tmp/out.png")