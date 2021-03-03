#!/usr/bin/env python3

import os, os.path, json, csv, re

OUT = "/tmp/messages.csv"
with open(OUT, "w") as g:
    outwriter = csv.writer(g)
    DATA_ROOT = "/tmp/messages"
    for x in os.listdir(DATA_ROOT):
        dir = os.path.join(DATA_ROOT, x)
        if os.path.isdir(dir):
            with open(os.path.join(dir, "channel.json")) as f:
                meta = json.load(f)
            if meta["type"] == 0 and ("guild" not in meta or meta["guild"]["id"] != "771081279403065344"):
                print(x, meta.get("name", "???"), meta.get("guild", "???"))
                with open(os.path.join(dir, "messages.csv")) as f:
                    r = csv.reader(f)
                    for row in r:
                        channel, timestamp, message, _ = row
                        message = re.sub("<@!?[0-9]+>", "", message)
                        message = re.sub("<:([A-Za-z0-9_-]+):[0-9]+>", lambda match: match.group(1), message)
                        outwriter.writerow((message, ))