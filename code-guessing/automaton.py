import collections

def do_thing(s):
    if len(s) == 1: return { s: True }
    out = {}
    for i, c in enumerate(s):
        without = s[:i] + s[i + 1:]
        things = do_thing(without)
        out[c] = things
    return out

def match(r, s):
    print(r)
    c = r
    for i, x in enumerate(s):
        print(x)
        try:
            c = c[x]
            if c == True:
                if i + 1 == len(s):
                    return True # full match
                else:
                    return False # characters remain
        except KeyError:
            return False # no match
    return False # incomplete match

def to_fsm(treeoid):
    s_map = {}
    count = 1
    final = {}
    alphabet = set()
    def go(treeoid, current=0):
        nonlocal count
        s_map[current] = {}
        for k, v in treeoid.items():
            alphabet.add(k)
            c = count
            count += 1
            if v == True: #final
                if k not in final:
                    final[k] = c
                    s_map[current][k] = c
                else:
                    s_map[current][k] = final[k]
            else: # unfinal
                s_map[current][k] = c
                go(v, c)
                
    go(treeoid)
    print(treeoid)

    print(len(s_map), "states")

    from greenery import fsm
    return fsm.fsm(
        alphabet = alphabet,
        states = set(s_map.keys()) | set(final.values()),
        map = s_map,
        finals = set(final.values()),
        initial = 0
    )

def entry(apiomemetic_entity, entity_apiomemetic):
    from greenery import lego
    aut = do_thing(apiomemetic_entity)
    fsm = to_fsm(aut)
    print("accepts", fsm.cardinality(), "strings")
    regex = str(lego.from_fsm(fsm))
    print(regex)
    import re
    return bool(re.match(regex, entity_apiomemetic))

if __name__ == "__main__":
    print(entry("apioform", "beeeeese"))