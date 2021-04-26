#!/usr/bin/env python3

import random
import collections
import subprocess
import ctypes
import tempfile
import os
import shutil
import os.path
import base64

class CWrapper:
    def __init__(self, file):
        self.filename = file
    def __enter__(self):
        self.tempfile = tempfile.mktemp(prefix="shlib-")
        print("Compiling C file", self.filename)
        if subprocess.run(["gcc", self.filename, "-o", self.tempfile , "-shared", "-fPIC"]).returncode != 0:
            raise ValueError("compilation failed")
        library = ctypes.CDLL(self.tempfile)
        self.function = entry = library.entry
        entry.restype = ctypes.c_char_p
        return self

    def __call__(self, s): return self.function(ctypes.c_char_p(s.encode("ascii"))).decode("ascii")
    def __repr__(self): return f"<wrapper for C solution {self.filename}>"
    def __exit__(self, type, value, traceback): os.unlink(self.tempfile)

class JavaWrapper:
    main = """
import java.io.*;
public class Main {
    public static void main(String[] args) {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        try {
            while (true) {
                String line = br.readLine();
                if (line == null) { return; }
                System.err.println("got");
                System.err.println(line);
                System.out.println(Entry.entry(line));
            }
        } catch (IOException ioe) {
            System.err.println(ioe);
            System.exit(1);
        }
    }
}
    """

    def __init__(self, file):
        self.filename = file
    def __enter__(self):
        self.tempdir = tempfile.mkdtemp(prefix="javacompile-")
        code_path = os.path.join(self.tempdir, "Entry.java")
        shutil.copyfile(self.filename, code_path)
        main_path = os.path.join(self.tempdir, "Main.java")
        with open(main_path, "w") as f:
            f.write(JavaWrapper.main)
        print("Compiling Java file", self.filename)
        if subprocess.run(["javac", code_path, main_path]).returncode != 0:
            raise ValueError("compilation failed")
        main_class_path = os.path.join(self.tempdir, "Main.class")
        self.process = subprocess.Popen(["java", "-cp", self.tempdir, "Main"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        return self

    def __call__(self, s):
        self.process.stdin.write(s.encode("ascii") + os.linesep.encode("ascii"))
        self.process.stdin.flush()
        return self.process.stdout.readline().decode("ascii")
    def __repr__(self): return f"<wrapper for Java solution {self.filename}>"
    def __exit__(self, type, value, traceback):
        shutil.rmtree(self.tempdir)
        self.process.kill()

def test(entry):
    for _ in range(500):
        s = "".join(chr(random.randint(32, 126)) for _ in range(random.randint(1, 256)))
        answer = base64.b32encode(s.encode("ascii")).decode("ascii")
        result = entry(s)
        assert answer == result, f"test failed for {entry}: got {result}, should be {answer}, for {s}"
    print(entry, "passed all tests")

import base32
test(base32.entry)