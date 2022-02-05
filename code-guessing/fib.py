import subprocess
import ctypes
import tempfile
import bisect

fibs = [0, 1]
def make_fibs(n):
    while fibs[-1] < n:
        fibs.append(fibs[-1] + fibs[-2])

def dfs(target, inuse=set()):
    make_fibs(target)
    end_index = bisect.bisect_left(fibs, target)
    if fibs[end_index] == target and target not in inuse:
        return inuse | {end_index}
    for i, possibility in enumerate(fibs[end_index:1:-1]):
        reali = end_index - i
        if reali in inuse: continue
        new = inuse | {reali}
        if result := dfs(target - possibility, new): return result

make_fibs(2**63)
print(len(fibs))
"""
raise SystemExit()

for i in range(2, 10000):
    print("doing", i)
    res = dfs(i)
    print(res)
    assert sum(map(lambda x: fibs[x], res)) == i, "numbers do not sum to thing"
    assert tuple(sorted(set(res))) == tuple(sorted(res)), "things are not unique"
"""
def c_wrapper(file):
    print("Compiling", file)
    temp = tempfile.mktemp(prefix="lib-compile-")
    print(temp)
    if subprocess.run(["gcc", file, "-o", temp, "-shared", "-fPIC"]).returncode != 0:
        raise ValueError("compilation failed")
    library = ctypes.CDLL(temp)
    entry = library.f
    entry.restype = ctypes.POINTER(ctypes.c_int64)
    def wrapper(n):
        vlen_ptr = ctypes.c_int(0)
        out = entry(n, ctypes.byref(vlen_ptr))
        l_out = []
        for i in range(vlen_ptr.value):
            #print(out[i])
            l_out.append(out[i])
        return l_out
    return wrapper

def gollariosolver(n):
    #print(n, "is n")
    x = bisect.bisect_left(fibs, n)
    out = set()
    z = 0
    for i in range(x, 0, -1):
        #print("gollario", i, z, fibs[i])
        if (y := fibs[i] + z) <= n:
            z = y
            out.add(i)
        if z == n:
            return out

print(fibs[12]+ fibs[23] + fibs[34])

c_code = c_wrapper("fib.c")
for i in range(2, 2**16):
    res = c_code(i)
    #res = gollariosolver(i)
    assert sum(map(lambda x: fibs[x], res)) == i, "numbers do not sum to thing"
    assert tuple(sorted(set(res))) == tuple(sorted(res)), "things are not unique"