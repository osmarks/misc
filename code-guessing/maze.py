#!/usr/bin/env python3

from z3 import *

def chunks(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def main_solver(maze):
    MAX_PATH_LENGTH = 80
    walls = [ix for ix, cell in enumerate(maze) if cell]
    #path_components = [ Int("path" + str(i)) for i in range(MAX_PATH_LENGTH) ]
    #path_component_constraints = [ Or(c == -10, c == 10, c == -1, c == 1, c == 0) for c in path_components ]
    #print(path_component_constraints)
    #print(solve(path_component_constraints))
    """
    positions = [Int("pos" + str(i)) for i in range(MAX_PATH_LENGTH)]
    pos_constraints = []
    solver = Solver()
    for ix, pos in enumerate(positions):
        if ix == 0:
            pos_constraints.append(pos == 0)
        else:
            last = positions[ix - 1]
            pos_constraints.append(Or(pos == (last + 10), pos == (last - 10), If(pos % 10 != 0, pos == (last + 1), False), If(pos % 10 != 9, pos == (last - 1), False)))
            pos == (last + 1), pos == (last - 1)))
            pos_constraints.append(pos < 100)
            pos_constraints.append(pos >= 0)
            for cell in walls:
                pos_constraints.append(pos != cell)
    pos_constraints.append(positions[-1] == 99)
    print(pos_constraints)
    for c in pos_constraints: constraints.append(c)"""
    solver = Solver()
    xs = [Int(f"x{i}") for i in range(MAX_PATH_LENGTH)]
    ys = [Int(f"y{i}") for i in range(MAX_PATH_LENGTH)]
    things = list(zip(xs, ys))
    constraints = []
    for ix, (x, y) in enumerate(things):
        if ix == 0:
            constraints.append(x == 0)
            constraints.append(y == 0)
        else:
            last_x, last_y = things[ix - 1]
            constraints.append(Or(
                And(x == last_x + 1, y == last_y),
                And(x == last_x - 1, y == last_y),
                And(x == last_x, y == last_y + 1),
                And(x == last_x, y == last_y - 1),
                And(x == last_x, y == last_y)
            ))
            constraints.append(x >= 0)
            constraints.append(x <= 9)
            constraints.append(y >= 0)
            constraints.append(y <= 9)

            for wall_pos in walls:
                constraints.append(Not(And(x == (wall_pos % 10), y == (wall_pos // 10))))

    constraints.append(xs[-1] == 9)
    constraints.append(ys[-1] == 9)
    #print(constraints)
    for constraint in constraints: solver.add(constraint)
    print(solver.check())
    model = solver.model()
    out = []
    for ix, (x, y) in enumerate(zip(xs, ys)):
        xp, yp = model.evaluate(x), model.evaluate(y)
        #print(ix, xp, yp)
        out.append(xp.as_long() + yp.as_long() * 10)
    return out

def fail(e): raise Exception(e)

def print_maze(m, p):
	out = [ [ "█" if x else "_" for x in row ] for row in chunks(m, 10) ]
	for ix, pc in enumerate(p): 
		out[pc // 10][pc % 10] = chr(ix % 26 + 97) if m[pc] == 0 else fail("all is bees")
	print("\n".join([ " ".join(row) for row in out ]))
	assert p[-1] == 99

def entry(maze):
    p = main_solver(maze)
    print_maze(maze, p)
    print([{-10:1,1:2,10:3,-1:4}[y-x] for x,y in zip(p,p[1:]) if x != y])

print(entry([
0,1,0,0,0,1,0,0,0,1,
0,1,0,1,0,1,0,1,0,0,
0,1,0,1,0,1,0,1,1,0,
0,1,0,1,0,1,0,1,0,0,
0,1,0,1,0,1,0,1,0,1,
0,1,0,1,0,1,0,1,0,0,
0,1,0,1,0,1,0,1,1,0,
0,1,0,1,0,1,0,1,0,0,
0,1,0,1,0,1,0,1,0,1,
0,0,0,1,0,0,0,1,0,0]))

print(entry([
0,1,0,0,0,1,0,0,0,1,
0,1,0,1,0,1,0,1,0,0,
0,0,0,1,0,1,0,1,1,0,
0,1,0,1,0,1,0,1,0,0,
0,1,0,1,0,1,0,1,0,1,
0,1,0,1,0,1,0,1,0,0,
0,1,0,0,0,1,0,1,1,0,
0,1,0,0,0,1,0,1,0,0,
0,1,0,1,0,1,0,1,1,0,
0,0,0,1,0,0,0,0,1,0
]))

print(entry([
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0
]))

print(entry([
0,1,0,0,0,0,0,0,1,0,
0,0,0,0,0,1,1,0,0,0,
1,1,1,0,1,1,0,0,1,0,
0,1,1,0,0,0,1,0,0,1,
0,0,0,0,1,0,1,1,0,0,
1,0,0,0,0,1,0,0,0,1,
0,0,1,1,1,0,1,0,1,0,
1,0,0,0,1,0,1,0,0,0,
0,0,0,0,1,0,0,1,1,1,
1,0,1,0,0,0,0,0,0,0
]))

print(entry([
0,0,0,0,0,0,1,0,0,0,
0,0,1,0,1,0,0,0,1,0,
0,0,1,1,0,0,1,1,1,0,
0,0,0,0,1,0,0,0,0,0,
0,1,0,0,1,0,1,0,0,0,
0,0,1,0,0,0,0,0,0,0,
0,1,0,0,0,0,1,0,1,0,
0,0,0,1,0,0,0,1,0,0,
0,0,0,1,0,0,0,0,0,0,
1,0,0,0,0,1,0,0,0,0
]))
