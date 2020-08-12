#!/usr/bin/env python3
import gmpy2

def to_ternary(byte):
	return gmpy2.digits(byte, 3).zfill(6)

def to_emoji(digit):
	if digit == "0": return ":cactus:"
	if digit == "1": return ":hash:"
	if digit == "2": return ":pig:"

def emojiternarize(string):
	out = ""
	for byte in string.encode("utf-8"):
		out += " ".join([to_emoji(d) for d in to_ternary(byte)]) + " "
	return out

print(emojiternarize(input()))
