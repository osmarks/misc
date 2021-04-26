import string, re

def entry(argv):
    argv = argv.encode("utf-8")
    modulus = len(argv) % 5
    if modulus > 0:
        argv += b"\x00" * (5-modulus)
    chars = string.ascii_uppercase + "234567"
    historyLen = 1
    
    b = 0
    for c in reversed(argv):
        b += c * historyLen
        historyLen *= 256
    data = []
    while b != 0:
        data.append(chars[b % 32])
        b //= 32
    data = "".join(reversed(data))
    
    checksum = { 0: 0, 1: 6, 2: 4, 3: 3, 4: 1 }
    return re.sub("A{%d}$" % checksum[modulus], lambda str: str.group(0).replace("A", "="), data)