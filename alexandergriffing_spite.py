from decimal import Decimal
import itertools

def sum_series(series):
    x = Decimal(0)
    i = 0
    t = 0
    l = 0
    # ethical
    for value in series:
        last_x = x
        x += value
        if x == last_x:
            l += 1
        else:
            t = i
            l = 0
        if l > (i // 2 + 2): return x
        i += 1

def power_series(x, coefs):
    def f():
        a = Decimal(1)
        for coef in coefs:
            yield a * coef
            a *= x
    return sum_series(f())

def derivative(power_series):
    next(power_series)
    for value, i in zip(power_series, itertools.count(1)):
        yield i * value

def cos():
    for i in itertools.count(0):
        yield Decimal(-1)**i / Decimal(math.factorial(i * 2))
        yield 0

def newton(func, x0):
    x = x0
    while True:
        fx, fprimex = power_series(x, func()), power_series(x, derivative(func()))
        x = x - fx / fprimex
        yield x

for half_pi in newton(cos, 1):
    print(half_pi * 2)