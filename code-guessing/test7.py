import sys
import importlib
import subprocess
import ctypes
import random
import traceback
import textwrap
import json
import os
import shutil
try:
    from tqdm import tqdm, trange
except ImportError:
    print("`tqdm` not found. there will be no progress bars")
    def tqdm(x):
        return x
    trange = range


filename = sys.argv[1]

if filename.endswith(".py"):
    print("importing as Python...")
    module = importlib.import_module(filename.removesuffix(".py"))
    print("done.")
    try:
        entry = module.entry
    except AttributeError:
        print("module is missing entrypoint `entry`. aborting.")
        sys.exit(1)
elif filename.endswith(".c"):
    print("compiling as C with `gcc`...")
    obj = "./" + filename.removesuffix(".c") + ".so"
    rc = subprocess.call(["gcc", "-shared", "-fPIC", *sys.argv[2:], filename, "-o", obj])
    if rc != 0:
        print("compilation failed. aborting.")
        sys.exit(rc)
    lib = ctypes.CDLL(obj)
    try:
        entry = lambda s: lib.entry(s.encode())
    except AttributeError:
        print("library is missing entrypoint `entry`. aborting.")
        sys.exit(1)
elif filename.endswith(".rs"):
    print("compiling as Rust...")
    os.makedirs("./entry-rs/src", exist_ok=True)
    with open("./entry-rs/Cargo.toml", "w") as f:
        f.write("""
[package]
name = "entry-rs"
version = "0.1.0"
edition = "2021"

[lib]
name = "entry_rs"
crate-type = ["cdylib"]

[dependencies.pyo3]
version = "0.14.5"
features = ["extension-module"]
""")
    with open("./entry-rs/src/lib.rs", "w") as f:
        f.write("""
use pyo3::prelude::*;

mod entry_impl;
use entry_impl::entry;

#[pyfunction]
fn wrapped_entry(s: &str) -> PyResult<bool> {
    Ok(entry(s))
}

#[pymodule]
fn entry_rs(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(wrapped_entry, m)?)?;
    Ok(())
}
""")
    shutil.copyfile(filename, "./entry-rs/src/entry_impl.rs")
    os.chdir("entry-rs")
    rc = subprocess.call(["cargo", "build", "--release"])
    os.chdir("..")
    if rc != 0:
        print("compilation failed. aborting.")
        sys.exit(1)
    sys.path.append("./entry-rs/target/release")
    os.rename("./entry-rs/target/release/libentry_rs.so", "./entry-rs/target/release/entry_rs.so")
    module = importlib.import_module("entry_rs")
    entry = module.wrapped_entry
else:
    print("unrecognized file extension")
    sys.exit(1)


tests = [
    ("zero", "0", True),
    ("leadingws", "\n\t 0", True),
    ("trailingws", "0\n\t ", True),
    ("one", "1", True),
    ("negativezero", "-0", True),
    ("negativeone", "-1", True),
    ("wsisbadhere", "- 1", False),
    ("multidigit", "100", True),
    ("leadingzero", "01", False),
    ("noplus", "+1", False),
    ("decimal", "1.0", True),
    ("leadingdot", ".0", False),
    ("trailingdot", "0.", False),
    ("bigdecimal", "13847432.35809092", True),
    ("scientific", "1e2", True),
    ("bigscientific", "-2376420.0033533e533", True),
    ("capitalscientific", "2E3", True),
    ("scientificminus", "2e-3", True),
    ("scientificplusisokay", "2E+3", True),
    ("nowshere", "2 e + 3", False),
    ("integerexponent", "2e3.0", False),
    ("emptystring", r'""', True),
    ("notemptystring", r'"not empty"', True),
    ("escapes", r'"\n\t\r\f\b\/"', True),
    ("unicodeescape", r'"\uaA0b"', True),
    ("moreescapes", r'"\\ \" "', True),
    ("evilescape", r'"\"', False),
    ("manybackslashes", r'"\\\\\\\\"', True),
    ("evilmanybackslashes", r'"\\\\\\\\\"', False),
    ("invalidescape", r'"\j"', False),
    ("invalidunicodeescape", r'"\u000j"', False),
    ("bigstring", r'"greetings people. this is a big string. \\[}[{]}}\"&*%4783.02 I am trying to break your code. am I doing a good job?\nplease say I am\\\\"', True),
    ("emptyarray", "[]", True),
    ("lessemptyarray", "[0]", True),
    ("evenlessemptyarray", "[0, 1]", True),
    ("heterogenousarray", '[0, 2.0, "string"]', True),
    ("unclosedarray", "[0", False),
    ("trailingcomma", "[0,]", False),
    ("leadingcomma", "[,0]", False),
    ("leadingcommaobj", '{,"bee":-4}', False),
    ("gap", "[0,,1]", False),
    ("nesting", "[[], [1, [2, []], [3, 4]]]", True),
    ("hugenest", "[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]", True),
    ("emptyobject", "{}", True),
    ("singletonobject", r'{"key": "value"}', True),
    ("imaginebeinghetero", r'{"key": "value", "otherkey": 1}', True),
    ("keysarestrings", "{0: 0}", False),
    ("dupesareokay", r'{"key": 0, "key": 1}', True),
    ("stillnotrailingcomma", r'{"key": "value",}', False),
    ("mixing", r'[0, {"O.O": [{"object in a list in an object in a list\nwhat will it do": "it will do this"}]}]', True),
    ("whitespacesilliness", '[    \t  0   , { "whitespace4all"  : \n  {"woah" :[\n [  \n  ] ,0 ]}  \t}]', True),
    ("true", "true", True),    # hehe
    ("false", "false", True),
    ("null", "null", True),
    ("nototherstuff", "asdf", False),
    ("alltogethernow", r"""
        {
            "this": "a JSON value",
            "people": [
                {
                    "name": "christina",
                    "value": 1e100
                },
                {
                    "name": "everyone else probably\nidk",
                    "value": 0.0e0
                }
            ],
            "peoplecoolerthanchristina": {
                "value": null,
                "ready": false,
                "status": "still processing"
            }
        }
    """, True),
    ("noextradata", '["stuff"]extra stuff', False),
]

print("beginning testing suite")
failures = 0

for test_name, value, result in tqdm(tests):
    print(f"`{test_name}`... ", end="")
    try:
        r = entry(value)
    except BaseException:
        print("error")
        traceback.print_exc()
        failures += 1
        continue
    if bool(r) == result:
        print("ok")
    else:
        failures += 1
        print("failed")
        print(f"for test `{test_name}`:")
        print(textwrap.indent(value, " "*2))
        print(f"entry returned {r} when {result} was expected\n")
if not failures:
    print("test suite finished, all ok")
else:
    print(f"test suite finished. {failures} tests failed\n\n")
    print("skipping randomized testing because your program is clearly broken and the output from those isn't very helpful for finding bugs")
    sys.exit(2)


l = [r'\"', r'\\', r'\b', r'\f', r'\n', r'\r', r'\t', rf"\u{random.randint(0x0000, 0xFFFF):04{random.choice('xX')}}", *map(chr, range(ord(" "), ord("}")+1))]
l.remove("\\")
l.remove('"')

def gen_random_string():
    s = '"'
    for _ in range(random.randint(0, 8)):
        s += random.choice(l)
    s += '"'
    return wsify(s)

def wsify(s):
    return s + random.choice(" \t\n")*random.randint(0, 2)

def gen_random_json(n=1):
    if n >= 12:
        t = random.choice(["sentinel", "number", "string"])
    else:
        t = random.choice(["sentinel", "number", "array", "object", "string", "string", "number", "sentinel"])
    if t == "sentinel":
        return wsify(random.choice(["true", "false", "null"]))
    elif t == "string":
        return gen_random_string()
    elif t == "array":
        return wsify("[") + wsify(",").join(gen_random_json(n+1) for _ in range(5)) + wsify("]")
    elif t == "object":
        return wsify("{") + wsify(",").join(gen_random_string() + ":" + gen_random_json(n+1) for _ in range(5)) + wsify("}")
    elif t == "number":
        nt = random.choice(["int", "decimal", "sci"])
        if nt == "int":
            r = str(random.randint(0, 1000000000))
        elif nt == "decimal":
            r = str(random.uniform(0, 1000000000))
        elif nt == "sci":
            e = random.choice(["e", "E"])
            p = random.choice(["+", "-", ""])
            r = f"{random.uniform(0, 1000000000)}{e}{p}{random.randint(0, 1000000000)}"
        else:
            assert False
        return "-"*random.randint(0, 1) + r
    else:
        assert False


print("beginning randomized testing.")
random_failures = 0
for _ in trange(100):
    j = gen_random_json()
    tr = True
    if random.randint(0, 1):
        j = list(j)
        for _ in range(20):
            t = random.choice(["insert", "remove", "replace", "replace", "replace"])
            if not j and t in ("remove", "replace"):
                continue
            idx = random.randrange(0, len(j)+(t == "insert"))
            c = random.choice(["\n", "\t", " ", *map(chr, range(ord(" "), ord("}")+1))])
            if t == "replace":
                j[idx] = c
            elif t == "insert":
                j.insert(idx, c)
            elif t == "remove":
                j.pop(idx)
        j = "".join(j)
        try:
            json.loads(j)
        except json.JSONDecodeError:
            tr = False
    try:
        r = entry(j)
    except BaseException:
        print("error")
        traceback.print_exc()
        random_failures += 1
        continue
    if bool(r) != tr:
        print("randomized test case failed:")
        print(textwrap.indent(j, " "*2))
        print(f"entry returned {r} when {tr} was expected\n")
        random_failures += 1

if not random_failures:
    print("randomized testing finished. all ok\n\n")
else:
    print(f"randomized testing finished with {random_failures} failures\n\n")


print("overall report:")
overall = failures + random_failures
if not overall:
    print("no failures detected. all seems well!")
else:
    print(f"{overall} failures detected overall. you have some bugs to fix")
    sys.exit(2)
