from z3 import *

iters = [ Int(f"x{i}") for i in range(20) ]

solver = Solver()

for n,x in enumerate(iters):
    if n == 0:
        solver.add(x == 1111)
    else:
        last = iters[n - 1]
        solver.add(Or(x == last, (x * 2) == last, x == ((last * 3) + 1)))

solver.add(iters[-1] == 1)

print(solver.check())
print(solver.model())