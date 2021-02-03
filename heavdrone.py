#!/usr/bin/env python3
import websockets, websockets.exceptions
import asyncio
import json
import os, os.path
import aiosqlite
import ast
import random

CORO_CODE = """
async def repl_coroutine():
    import asyncio
    import websockets
    import aiosqlite
"""
async def async_exec(code, loc, glob):
    user_code = ast.parse(code, mode='exec')
    wrapper = ast.parse(CORO_CODE, mode='exec')
    funcdef = wrapper.body[-1]
    funcdef.body.extend(user_code.body)
    last_expr = funcdef.body[-1]

    if isinstance(last_expr, ast.Expr):
        funcdef.body.pop()
        funcdef.body.append(ast.Return(last_expr.value))
    ast.fix_missing_locations(wrapper)

    exec(compile(wrapper, "<repl>", "exec"), loc, glob)
    return await (loc.get("repl_coroutine") or glob.get("repl_coroutine"))()

appdata_folder = os.path.join(os.environ.get("APPDATA") or os.environ.get("XDG_DATA_HOME") or os.environ.get("HOME"), "heavdrone")
if not os.path.exists(appdata_folder): os.makedirs(appdata_folder)

def jencode(x): return json.dumps(x, separators=(',', ':'))

SPUDNET = "wss://spudnet.osmarks.net/v4"

def gen_id():
    return "".join(random.choices("0123456789abcdef", k=6))

async def spudnet_connect():
    loop = asyncio.get_event_loop()

    db = await aiosqlite.connect(os.path.join(appdata_folder, "data.sqlite3"))
    db.row_factory = aiosqlite.Row

    # horrible misuse of relational databases, yes
    await db.executescript("""CREATE TABLE IF NOT EXISTS config (
        key TEXT PRIMARY KEY,
        value BLOB NOT NULL
    )""")

    async def getconf(k):
        async with await db.execute("SELECT * FROM config WHERE key = ?", (k,)) as csr:
            x = await csr.fetchone()
            if x: return x["value"]
            else: return None
    async def setconf(k, v):
        await db.execute("INSERT OR REPLACE INTO config VALUES (?, ?)", (k, v))
        await db.commit()

    hid = await getconf("id")
    if not hid:
         hid = gen_id()
         await setconf("id", hid)
    print(hid)

    conn = None
    def send_packet(x): return conn.send(jencode(x))
    def send(x): return send_packet({ "type": "send", "channel": "client:potatogood/web", "data": { "sender": hid, **x } })

    async def connect():
        print("conn")
        nonlocal conn
        if conn: await conn.close()
        conn = await websockets.connect(SPUDNET, close_timeout=1)
        await send_packet({ "type": "identify", "channels": [ f"client:potatogood/{hid}", f"client:potatogood/all" ] })
        assert json.loads(await conn.recv())["type"] == "ok"
        return True
    
    async def aliveness_loop():
        while True:
            if conn:
                await send({ "type": "alive_info", "name": await getconf("name"), "category": await getconf("category"),
                    "buttons": [ 
                        { "type": "textarea", "respondon": "set_name", "name": "Set Name" },
                        { "type": "textarea", "respondon": "set_cat", "name": "Set Category" } ,
                        { "type": "chatlike", "2way": "repl", "name": "Python REPL" },
                        { "type": "chatlike", "2way": "chat", "name": "Dronechat" }
                ]})
            await asyncio.sleep(1)

    loop.create_task(aliveness_loop())

    glo = globals()
    loc = locals()

    async def parse_incoming(data, rmsg):
        if data["type"] == "set_name":
            await setconf("name", data["data"])
        if data["type"] == "set_cat":
            await setconf("category", data["data"])
        if data["type"] == "repl":
            async def run():
                await send({ "type": "stream_upd", "streamid": "repl", "data": "> " + str(data["data"]) })
                try:
                    result = await async_exec(data["data"], loc, glo)
                    await send({ "type": "stream_upd", "streamid": "repl", "data": repr(result) })
                except BaseException as e:
                    await send({ "type": "stream_upd", "streamid": "repl", "data": "ERR: " + repr(e) })
            loop.create_task(run())
        if data["type"] == "chat":
            await send({ "type": "stream_upd", "streamid": "chat", "data": f"{rmsg['sid']}: {data['data']}" })

    while True:
        try:
            if conn:
                x = json.loads(await asyncio.wait_for(conn.recv(), timeout=15))
                if x["type"] == "ping":
                    await send_packet({ "type": "pong", "seq": x["seq"] })
                if x["type"] == "message":
                    try:
                        await parse_incoming(x["data"], x)
                    except Exception as e:
                        print("parse", e)
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosedError) as e:
            conn = None
            print("connection broke", e, repr(e), str(e))
        while not conn:
            try:
                if await connect(): break
                await asyncio.sleep(1)
            except Exception as e:
                print("connection failed", e)
                conn = None

asyncio.get_event_loop().run_until_complete(spudnet_connect())