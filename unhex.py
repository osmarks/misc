#!/usr/bin/env python3
import fileinput
import sys

def process_char(c):
	return c + random.choice(zalgo)

for line in fileinput.input():
	#b = bytes()
	#for i in range(0, len(line), 2):
	#	b.appendline[i:i+2]
	sys.stdout.buffer.write(bytes.fromhex(line.replace("\n", "").replace(" ", "")))
