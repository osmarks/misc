from fractions import Fraction
from functools import reduce
import sys
from math import floor
import random

def interpolate(points):
	def mul_polys(p1, p2):
		out = [0] * (len(p1) + len(p2) - 1)
		for i1, c1 in enumerate(p1):
			for i2, c2 in enumerate(p2):
				out[i1 + i2] += c1 * c2
		return out
	def sum_polys(ps):
		out = [0] * max(map(len, ps))
		for p in ps:
			for i, c in enumerate(p):
				out[i] += c
		return out
	def basis(j):
		px = points[j][0]
		out = []
		for x, y in points:
			if x != px:
				div = px - x
				out.append([-Fraction(x, div), Fraction(1, div)])
		return reduce(mul_polys, out)
	out = []
	for i, (x, y) in enumerate(points):
		out.append([c * y for c in basis(i)])
	return sum_polys(out)

def evaluate(poly, x):
	y = 0
	for c in reversed(poly):
		y *= x
		y += c
	return y

indents = {"\t": 8, " ": 1, " ": Fraction(2, 3), " ": 2, " ": 4, " ": Fraction(4, 3), "​": 0}
def get_indent(line):
	i = 0
	e = 0
	for j, c in enumerate(line):
		if c in indents:
			i += indents[c]
			e = j + 1
		else: break
	return i, e

with open(sys.argv[1]) as tplfile:
	counts = [ (lnum, get_indent(line)[0]) for lnum, line in enumerate(tplfile.readlines()) ]

counts = random.sample(counts, k=4)
poly = interpolate(counts)

lindents = [ (Fraction(size), char) for char, size in indents.items() if size != 0 ]
lindents.sort()
def gen_indent(n):
	n = Fraction(abs(n))
	out = ""
	for (csize, cchar), (nsize, _) in zip(lindents, lindents[1:] + [(100000000000000, " ")]):
		nmult = 0
		while True:
			nxt = nmult + nsize
			if nxt <= n:
				nmult = nxt
			else: break

		dif = floor((n - nmult) / csize)
		n -= dif * csize
		out += cchar * dif
	return out

with open(sys.argv[2]) as infile:
	for lnum, line in enumerate(infile.readlines()):
		line = line[get_indent(line)[1]:]
		print(gen_indent(evaluate(poly, lnum)) + line, end="")
