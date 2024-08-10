from fractions import Fraction

def uniform(syms):
    def pdist(seq):
        return {s: Fraction(1, len(syms)) for s in syms}
    return pdist

def cdfs(distribution):
    cdf_lo = {}
    cdf_hi = {}
    total_probability = 0
    for sym, prob in distribution.items():
        cdf_lo[sym] = total_probability # we could also use the last symbol as the lower bound but this is more explicit
        total_probability += prob
        cdf_hi[sym] = total_probability
    return cdf_lo, cdf_hi

def encode(sequence, pdist):
    a = Fraction(0, 1)
    b = Fraction(1, 1)

    bits = []

    for i, x in enumerate(sequence):
        distribution = pdist(sequence[:i])
        cdf_lo, cdf_hi = cdfs(distribution)
        rang = b - a
        b = a + rang * cdf_hi[x]
        a += rang * cdf_lo[x]

        # if our interval is sufficiently constrained, emit bits
        while True:
            if a < b < Fraction(1, 2):
                bits.append(0)
                a *= 2
                b *= 2
            elif Fraction(1, 2) < a < b:
                bits.append(1)
                a *= 2
                b *= 2
                a -= 1
                b -= 1
            else:
                break

    # it may still be the case that a and b are in [0,1], i.e. we have not emitted enough bits
    # to constrain it in the decoder
    while a > 0 or b < 1:
        c = (a + b) / 2 # slightly suboptimal: try and write out midpoint
        if c < Fraction(1, 2):
            bits.append(0)
            a *= 2
            b *= 2
        else:
            bits.append(1)
            a *= 2
            a -= 1
            b *= 2
            b -= 1

    return bits

def decode(bits, pdist):
    a = Fraction(0, 1)
    b = Fraction(1, 1)
    scale = Fraction(1, 2)

    sequence = []
    while bits:
        distribution = pdist(sequence)
        cdf_lo, cdf_hi = cdfs(distribution)
        for (lo, hi), sym in zip(zip(cdf_lo.values(), cdf_hi.values()), cdf_lo.keys()):
            if lo <= a < b <= hi: # if message interval is subset of symbol interval, emit symbol
                sequence.append(sym)
                # expand working interval and adjust scale up
                # (effectively, consume symbol in weird base)
                range = hi - lo
                a = (a - lo) / range
                b = (b - lo) / range
                scale /= range
                break
        else:
            # consume a bit
            bit = bits.pop(0)
            a += bit * scale
            b = a + scale
            scale /= 2
    
    return sequence

dist = lambda seq: {"a": Fraction(98, 100), "b": Fraction(1, 100), "c": Fraction(1, 100)}
input = "abbabaccabbabbbbbba"
bits = encode(input, dist)
print(bits)
result = "".join(decode(bits, dist))
print(input, result)
assert input == result, "oh no"