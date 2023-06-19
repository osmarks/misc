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
        entry = lib.entry
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
fn wrapped_entry(s: &str) -> PyResult<i32> {
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
    ("zero", "0", 0),
    ("add", "1+2", 3),
    ("sub", "2-1", 1),
    ("mul", "2*3", 6),
    ("div", "4/2", 2),
    ("floor", "4/3", 1),
    ("neg", "0-4", -4),
    ("chain", "4/2/2", 1),
    ("olivia", "1+7/4-0*4", 2),
    ("gollario", "4-4-4-4+8", 0)
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
        print(f"in test `{test_name}`:")
        print(textwrap.indent(value, " "*2))
        failures += 1
        continue
    if r == result:
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


def gen_random_json():
    s = random.choice("0123456789")
    for _ in range(random.randint(0, 10)):
        s += random.choice("+-*/")
        s += random.choice("0123456789")
    return s


print("beginning randomized testing.")
random_failures = 0
for _ in trange(100):
    while True:
        j = gen_random_json()
        try:
            tr = eval(j.replace("/", "//"))
        except ZeroDivisionError:
            continue
        else:
            break
    try:
        r = entry(j)
    except BaseException:
        print("error")
        traceback.print_exc()
        print("in randomized test case:")
        print(textwrap.indent(j, " "*2))
        random_failures += 1
        continue
    if r != tr:
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
