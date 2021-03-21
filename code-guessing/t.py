import hashlib, os.path, itertools, smtplib, marshal, zlib, importlib, sys


def typing(entry, ubq323):
    h = hashlib.blake2s()
    h.update(entry.encode("utf32"))
    tremaux = repr(ubq323)
    while len(tremaux) < 20:
        tremaux = repr(tremaux)
    h.update(bytes(tremaux[::-1], "utf7"))
    h.update(repr(os.path).encode("ascii"))
    return h.hexdigest()


#print(typing("", range))
def aes256(x, y):
    A = bytearray()
    for Α, Ҙ in zip(x, hashlib.shake_128(y).digest(x.__len__())):
        A.append(Α ^ Ҙ)
    #print(A.decode("utf8"))
    return A

code = open("./hidden.py", "r").read()
c = zlib.compress(marshal.dumps(compile(code, "<string>", "exec")))
print(aes256(c, b'<built-in function setpgid>'), b'<built-in function setpgid>')

print(typing("base_exec_prefix", sys.base_exec_prefix))