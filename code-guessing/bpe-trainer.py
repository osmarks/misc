import os, csv, re, itertools, numpy, collections, json

rawbuffer = bytearray()

with open("/tmp/input.csv") as f:
    r = csv.reader(f)
    for row in r:
        channel, timestamp, message, _ = row
        message = re.sub("<@!?[0-9]+>", "", message)
        message = re.sub("<:([A-Za-z0-9_-]+):[0-9]+>", lambda match: match.group(1), message)
        rawbuffer += (message.strip() + " ").encode("utf-8")

#print(rawbuffer.count(b"\x0f"))
#raise SystemExit()

print(len(rawbuffer))
buffer = numpy.array(rawbuffer, dtype=numpy.uint16)
dc = {}
for newindex in range(256, 1024):
    freqs = collections.Counter(zip(buffer, buffer[1:]))
    (fst, snd), count = freqs.most_common(1)[0]
    print(newindex, count, repr(chr(fst)), repr(chr(snd)))
    dc[newindex] = int(fst), int(snd)
    pending = False
    newbuffer = numpy.zeros_like(buffer)
    z = 0
    for code in buffer:
        if pending:
            if code == snd:
                newbuffer[z] = newindex
                z += 1
                pending = False
                continue
            else:
                newbuffer[z] = fst
                z += 1
                pending = False
        if code == fst:
            pending = True
        else:
            newbuffer[z] = code
            z += 1
    buffer = newbuffer[:z]
with open("compr.json", "w") as f:
    json.dump({
        "dicts": dc,
        "frequencies": dict(collections.Counter(map(int, buffer)))
    }, f, separators=",:")