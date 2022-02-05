import sqlite3, pyperclip, os.path, subprocess, sys

conn = sqlite3.connect(os.path.expanduser("~/.local/share/clipstack.sqlite3"))
conn.executescript("""CREATE TABLE IF NOT EXISTS stack (pos INTEGER PRIMARY KEY, data BLOB NOT NULL)""")

def push(data):
    c = conn.cursor()
    c.execute("SELECT max(pos) FROM stack")
    res = c.fetchone()[0]
    if res == None: nxt = 0
    else: nxt = res + 1
    c.execute("INSERT INTO stack VALUES (?, ?)", (nxt, data))
    conn.commit()

def pop():
    c = conn.cursor()
    c.execute("SELECT * FROM stack ORDER BY pos DESC LIMIT 1")
    res = c.fetchone()
    if not res: return
    pos, data = res
    c.execute("DELETE FROM stack WHERE pos = ?", (pos,))
    return data
    conn.commit()

mode = sys.argv[1]
if mode == "push":
    proc = subprocess.run(["xclip", "-selection", "clipboard", "-o"], stdout=subprocess.PIPE)
    if proc.returncode == 0:
        push(proc.stdout)
        print("push")
elif mode == "pop":
    data = pop()
    if data:
        proc = subprocess.run(["xclip", "-selection", "clipboard"], input=data)
        print("pop")