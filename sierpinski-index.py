# https://www2.isye.gatech.edu/~jjb/research/mow/mow.pdf

def sierpinski_index(x, y, w):
	index = w
	result = 0

	if x > y:
		result += 1
		x = w - x
		y = w - y

	while index > 0:
		result *= 2
		if x + y > w:
			result += 1
			old_x = x
			x = w - y
			y = old_x
		x *= 2
		y *= 2
		result *= 2
		if y > w:
			result += 1
			old_x = x
			x = y - w
			y = w - old_x
		index //= 2
	return result

import itertools
from PIL import Image, ImageDraw
width = 22
thing = 16
border = 8
points = list(itertools.product(range(width), range(width)))
print(points)
points.sort(key=lambda xy: sierpinski_index(xy[0], xy[1], width))
print(points)

def scale(point):
	x, y = point
	return x * thing + border, y * thing + border

img = Image.new("RGB", ((width - 1) * thing + border * 2, (width - 1) * thing + border * 2))
draw = ImageDraw.Draw(img)

for sp, ep in zip(points, points[1:]):
	draw.line((scale(sp), scale(ep)), fill="white", width=0)

img.show()
img.save("/tmp/apio.png")