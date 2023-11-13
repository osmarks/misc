import sqlite3
import time
import requests
from datetime import datetime, timezone

CHUNK = 1000

def do_query(offset):
    return requests.get("https://krist.dev/transactions", params={"excludeMined": True, "limit": CHUNK, "offset": CHUNK * offset}).json()

conn = sqlite3.connect("krist.sqlite3")
conn.row_factory = sqlite3.Row
conn.executescript("""CREATE TABLE IF NOT EXISTS tx (
    id INTEGER PRIMARY KEY, 
    fromaddr TEXT, 
    toaddr TEXT NOT NULL,
    value INTEGER NOT NULL,
    time INTEGER NOT NULL,
    name TEXT,
    meta TEXT,
    sent_metaname TEXT,
    sent_name TEXT
);""")


i = 0
while True:
    results = do_query(i)
    print(list(results.keys()))
    if results.get("count") == 0:
        print("done")
        break
    elif results["ok"] == False and "rate limit" in results.get("error", ""):
        print(results.get("error"))
        time.sleep(90)
    elif results["ok"] == False:
        print(results.get("error"))
    else:
        conn.executemany("INSERT INTO tx VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", [ (x["id"], x["from"], x["to"], x["value"], int(datetime.strptime(x["time"], "%Y-%m-%dT%H:%M:%S.%f%z").astimezone(timezone.utc).timestamp() * 1000), x["name"], x["metadata"], x["sent_metaname"], x["sent_name"]) for x in results["transactions"] ])
        conn.commit()
        i += 1