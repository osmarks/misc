perm = [
    [1, 2, 3, 4, 5, 6, 7, 8],
    [5, 7, 8, 2, 3, 6, 4, 1]
]
perm = dict(zip(*perm))
vals = set(perm)

print(perm)
cycs = []
while vals:
    nxt = vals.pop()
    seen = []
    while nxt not in seen:
        lnxt = nxt
        nxt = perm[nxt]
        seen.append(lnxt)
    cycs.append(seen)
    vals -= set(seen)
print(cycs)