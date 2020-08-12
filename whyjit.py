#!/usr/bin/env python3
import argparse
import subprocess
import random
import string

parser = argparse.ArgumentParser(description="Compile a WHY program using WHYJIT.")
parser.add_argument("input", help="File containing WHY source code")
parser.add_argument("-o", "--output", help="Filename of the output executable to make", default="./a.why")
parser.add_argument("-O", "--optimize", help="Optimization level", type=int, default="0")
args = parser.parse_args()

def randomword(length):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(length))

def which(program):
    proc = subprocess.run(["which", program], stdout=subprocess.PIPE)
    if proc.returncode == 0:
        return proc.stdout.replace(b"\n", b"")
    else:
        return None

def find_C_compiler():
    compilers = ["gcc", "clang", "tcc", "cc"]
    for compiler in compilers:
        path = which(compiler)
        if path != None:
            return path

def build_output(code, mx):
    C_code = f"""
#define QUITELONG long long int
const QUITELONG max = {mx};

int main() {{
    volatile QUITELONG i = 0; // disable some "optimizations" that RUIN OUR BEAUTIFUL CODE!
    while (i < max) {{
        i++;
    }}
    {code}
}}
    """
    
    heredoc = randomword(100)
    devnull = "2>/dev/null"
    shell_script = f"""#!/bin/sh
TMP1=/tmp/ignore-me
TMP2=/tmp/ignore-me-too
TMP3=/tmp/dont-look-here
    cat << {heredoc} > $TMP1
{C_code}
{heredoc}
sed -e '1,/^exit \$?$/d' "$0" > $TMP3
chmod +x $TMP3
$TMP3 -x c -o $TMP2 $TMP1
chmod +x $TMP2
$TMP2
exit $?
""".encode("utf-8")    

    with open(find_C_compiler(), "rb") as f:
        return shell_script + f.read()

input = args.input
output = args.output
with open(input, "r") as f:
    contents = f.read()
    looplen = max(1000, (2 ** -args.optimize) * 1000000000)
    code = build_output(
        contents,
        looplen
    )
    with open(output, "wb") as out:
        out.write(code)
