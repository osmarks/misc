def step(x):
    return ((x * 1039) + (x * 6177) + 1605 + (x * 4253)) % 8041

points = set()
a, b, c = None, None, 417
for n in range(100000):
    a, b, c = b, c, step(c)
    if a is not None and b is not None:
        points.add((a, b, c))

import numpy as np
import matplotlib.pyplot as plt
 
fig = plt.figure()
ax = plt.axes(projection="3d")
def unzip(l):
    ls = []
    for x in l:
        for i, v in enumerate(x):
            if len(ls) <= i:
                ls.append([])
            ls[i].append(v)
    return ls
ax.scatter(*unzip(points))
plt.show()