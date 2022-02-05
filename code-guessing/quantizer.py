import json, math, random
N_bits = 14
X_bits = 2 ** 14
with open("compr.json", "r") as f:
    with open("freqs.json", "w") as g:
        rawfreqs = { int(k): v for k, v in json.load(f)["frequencies"].items() }
        for i in range(1024):
            if i not in rawfreqs:
                rawfreqs[i] = 1
        bpe_freqs = sorted(rawfreqs.items(), key=lambda x: x[1])
        total = sum(map(lambda x: x[1], bpe_freqs))
        table = { k[0]: 1 for k in bpe_freqs }
        for i, freq in bpe_freqs:
            val = max(freq / total * X_bits - 1, 0)
            print(val)
            n = math.floor(val)
            q = val - n
            x = n + (random.random() < q)
            table[i] += x
        diff = X_bits - sum(table.values())
        adjust = random.choices(list(filter(lambda x: table[x] > 1, range(1024))), k=abs(diff))
        if diff > 0:
            for a in adjust:
                table[a] += 1
        elif diff < 0:
            for a in adjust:
                table[a] -= 1

        print(diff, sum(table.values()))
        json.dump(table, g)