import math, itertools

count = 0
for permutation in itertools.permutations(range(7)):
    perm = [
        list(range(7)),
        list(permutation)
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
    if math.lcm(*map(len, cycs)) == 4:
        count += 1
print(count)