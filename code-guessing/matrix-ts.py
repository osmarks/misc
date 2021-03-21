#!/usr/bin/env python3

import random
import collections
import subprocess
import ctypes
import tempfile
import os

def random_matrix(n):
    return [
        [random.randint(-0xFFF, 0xFFF) for _ in range(n)]
        for _ in range(n) 
    ]

# https://en.wikipedia.org/wiki/Matrix_multiplication_algorithm#Iterative_algorithm
def simple_multiply(m1, m2):
    n = len(m1)
    out = [ [ None for _ in range(n) ] for _ in range(n) ]
    for i in range(n):
        for j in range(n):
            total = 0
            for k in range(n):
                total += m1[i][k] * m2[k][j]
            out[i][j] = total
    return out

def print_matrix(m):
    longest_of_col = collections.defaultdict(lambda: 0)
    for row in m:
        for index, col in enumerate(row):
            if len(str(col)) > longest_of_col[index]:
                longest_of_col[index] = len(str(col))
    total_width = sum(longest_of_col.values()) + len(m) + 1
    out = ["┌" + (" " * total_width) + "┐"]
    for row in m:
        things = ["│"]
        for index, col in enumerate(row):
            things.append(str(col).rjust(longest_of_col[index]))
        things.append("│")
        out.append(" ".join(things))
    out.append("└" + (" " * total_width) + "┘")
    return "\n".join(out)

def broken_entry(m1, m2):
    n = len(m1)
    out = [ [ None for _ in range(n) ] for _ in range(n) ]
    for i in range(n):
        for j in range(n):
            total = 0
            for k in range(n):
                total += m1[i][k] * m2[k][j] - 3
            out[i][j] = total
    return out

def flatten(arr):
    for xs in arr:
        for x in xs:
            yield x

def c_wrapper(file):
    print("Compiling", file)
    temp = tempfile.mktemp(prefix="lib-compile-")
    print(temp)
    if subprocess.run(["gcc", file, "-o", temp, "-shared"]).returncode != 0:
        raise ValueError("compilation failed")
    library = ctypes.CDLL(temp)
    entry = library.entry
    entry.restype = ctypes.POINTER(ctypes.c_int)
    def wrapper(m1, m2):
        n = len(m1)
        Matrix = (ctypes.c_int * (n * n))
        m1_c = Matrix(*flatten(m1))
        m2_c = Matrix(*flatten(m2))
        out = [ [ None for _ in range(n) ] for _ in range(n) ]
        out_p = entry(m1_c, m2_c, n)
        for i in range(n):
            for j in range(n):
                out[i][j] = out_p[i * n + j]
        return out
    return wrapper

def test(entry):
    for _ in range(100):
        n = random.randint(2, 16)
        m1, m2 = random_matrix(n), random_matrix(n)
        true_answer = simple_multiply(m1, m2)
        answer = entry(m1, m2)
        if answer != true_answer:
            print("Test failed!", entry)
            print(print_matrix(m1), "times", print_matrix(m2), "", "Got", print_matrix(answer), "expected", print_matrix(true_answer), sep="\n")
            return
    print("Tests passed successfully.", entry)

#test(c_wrapper("./c_matrix_test.c"))
#test(broken_entry)
import multiply_matrices
test(multiply_matrices.entry)