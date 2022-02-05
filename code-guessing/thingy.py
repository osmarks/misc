# -*- coding: utf-8 -*-
"""
Created on Mon Mar 30 08:37:12 2015

@author: jonathan
"""

import clang.cindex
import clang.enumerations
import random

# set the config
clang.cindex.Config.set_library_file("/lib/libclang.so")

class Tokenizer:
    # creates the object, does the inital parse
    def __init__(self, path):
        self.index = clang.cindex.Index.create()
        self.tu = self.index.parse(path)
        self.path = self.extract_path(path)
    
    # To output for split_functions, must have same path up to last two folders
    def extract_path(self, path):
        return "".join(path.split("/")[:-2])
    
    # tokenizes the contents of a specific cursor
    def full_tokenize_cursor(self, cursor):
    
        return [ token.spelling for token in cursor.get_tokens() ]
    
    # tokenizes the entire document
    def full_tokenize(self):
        cursor = self.tu.cursor
        return self.full_tokenize_cursor(cursor)

copypasta = """
What the fuck did you just fucking say about me, you little bitch? I'll have you know I graduated top of my class in the Navy Seals, and I've been involved in numerous secret raids on Al-Quaeda, and I have over three hundred confirmed kills. I am trained in gorilla warfare and I'm the top sniper in the entire US Armed Forces. You are nothing to me but just another target. I will wipe you the fuck out with precision the likes of which has never been seen before on this Earth, mark my fucking words. You think you can get away with saying that shit to me over the Internet? Think again, fucker. As we speak, I am contacting my secret network of spies across the USA and your IP is being traced right now so you better prepare for the storm, maggot. The storm that wipes out the pathetic little thing you call your life. You're fucking dead, kid. I can be anywhere, anytime, and I can kill you in over seven hundred ways, and that's just with my bare hands. Not only am I extensively trained in unarmed combat, but I have access to the entire arsenal of the United States Marine Corps and I will use it to its full extent to wipe your miserable ass off the face of the continent, you little shit. If only you could have known what unholy retribution your little clever comment was about to bring down upon you, maybe you would have held your fucking tongue. But you couldn't, you didn't, and now you're paying the price, you goddamn idiot. I will shit fury all over you and you will drown in it. You're fucking dead, kiddo.
What the f--- did you just f---ing type about me, you little bitch? I'll have you know I graduated top of my class at MIT, & I've been involved in numerous secret raids with Anonymous, & I have over three hundred confirmed DDoSes. I am trained in online trolling & I'm the top hacker in the entire world. You are nothing to me but just another virus host. I will wipe you the f--- out with precision the likes of which has never been seen before on the Internet, mark my f---ing words. You think you can get away with typing that shit to me over the Internet? Think again, f---er. As we chat over IRC I am tracing your IP with my damn bare hands so you better prepare for the storm, maggot. The storm that wipes out the pathetic little thing you call your computer. You're f---ing dead, kid. I can be anywhere, anytime, & I can hack into your files in over seven hundred ways, & that's just with my bare hands. Not only am I extensively trained in hacking, but I have access to the entire arsenal of every piece of malware ever created & I will use it to its full extent to wipe your miserable ass off the face of the world wide web, you little shit. If only you could have known what unholy retribution your little clever comment was about to bring down upon you, maybe you would have held your f---ing fingers. But you couldn't, you didn't, & now you're paying the price, you goddamn idiot. I will shit code all over you & you will drown in it. You're f---ing dead, kiddo.
""".lower().replace("-", "_").replace("&", " and ")
for punct in "?'.,":
    copypasta = copypasta.replace(punct, " ")
copypasta = [ x.strip() for x in copypasta.split(" ") if x.strip() ]

import sys

if len(sys.argv) != 2:
    print("please provide a file argument")
    exit(1)
    
def modcase(s):
    return "".join([ c.upper() if random.randint(0, 1) else c.lower() for c in s ] )

tok = Tokenizer(sys.argv[1]) # path to a C++ file
results = tok.full_tokenize()
tmap = {"if": None, "for": None}
seq = []
for cpasta, c in zip(copypasta, results):
    while cpasta in tmap and tmap[cpasta] != c:
        for i in range(200):
            tr = modcase(cpasta)
            if tr not in tmap or tmap[tr] == c:
                cpasta = tr
                break
        else: cpasta += "_"
    tmap[cpasta] = c
    seq.append(cpasta)
print("""#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <complex.h>
#include <string.h>
#include <stdlib.h>

#define nfibs 93""")
for k, v in tmap.items():
    if v: print(f"#define {k} {v}")
print(" ".join(seq))