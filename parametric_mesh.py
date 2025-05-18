from solid2 import *
import numpy as np

THICKNESS = 3
XYSIZE = 58
HOLE_SIZE = 4
LINE_SIZE = 0.5

LINE_SPACING = HOLE_SIZE + LINE_SIZE
XYSIZE = (XYSIZE // LINE_SPACING) * LINE_SPACING + LINE_SIZE
print(XYSIZE)

xlines = [ cube(LINE_SIZE, XYSIZE, THICKNESS).translate(x, 0, 0) for x in np.arange(0, XYSIZE, LINE_SPACING) ]
ylines = [ cube(XYSIZE, LINE_SIZE, THICKNESS).translate(0, y, 0) for y in np.arange(0, XYSIZE, LINE_SPACING) ]

model = union()(*xlines).union()(*ylines)

model.save_as_scad()
