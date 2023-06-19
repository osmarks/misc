import cv2, numpy, matplotlib.pyplot as plt, scipy.interpolate, sys
from collections import defaultdict

img = cv2.imread(sys.argv[1]) 
H, S, L = cv2.split(cv2.cvtColor(img, cv2.COLOR_BGR2HSV))
img_blur = cv2.GaussianBlur(H, (15,15), 0) 
thresh = cv2.threshold(img_blur, 55, 255, cv2.THRESH_BINARY)[1]
edges = cv2.Canny(image=thresh, threshold1=100, threshold2=200)
c, hier = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
best = max(c, key=lambda x: x.shape[0])[:, 0, :]
min_x, max_x = min(best[:, 0]), max(best[:, 0])
min_y, max_y = min(best[:, 1]), max(best[:, 1])
xrange = max_x - min_x
yrange = max_y - min_y
coords = [[((x - min_x) / xrange) * 2 - 1, ((y - min_y) / yrange) * 2 - 1] for x, y in best ]
coords.sort(key=lambda x: x[0])
coords2 = defaultdict(list)
for x, y in coords:
    coords2[x].append(y)
coords3x = []
coords3y = []
last = -1
for x, ys in coords2.items():
    coords3y.append(min(ys, key=lambda x: abs(x - last)))
    coords3x.append(x)
    last = coords3y[-1]
i = scipy.interpolate.CubicSpline(coords3x, coords3y, extrapolate=True)
xs = numpy.arange(-1.0, 1.0, 0.02)
plt.plot(coords3x, coords3y, label='data')
plt.plot(xs, i(xs))
plt.show()