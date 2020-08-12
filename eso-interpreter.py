code = input()
l = len(code)
acc = 0
pos = 0
incr = 1
num_lookup = { "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9 }
while pos < l:
	char = code[pos]
	if char == "i":
		h, g = list(range(pos + 1, l)), list(range(pos - 1, 0, -1))
		for i in h + g if incr == 1 else g + h:
			if code[i] == "i":
				pos = (i + 1) % l
				break
		continue
	elif char == "p": pos += incr
	elif char == "a": acc += 1
	elif char == "e": acc -= 1
	elif char == "v": incr *= -1
	elif char == "~":
		acc = 0
		for x, n in enumerate(reversed(input().split(" "))): acc += 10**x * num_lookup[n]
	elif char == "`": print(end=chr(acc))
	elif char == "[":
		if acc != 0:
			acc = int(str(acc) + bin(acc)[2:])
	else: print("wrong.")
	pos += incr