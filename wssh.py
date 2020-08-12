import asyncio
import asyncio.subprocess
import websockets
import pty

def get_shell():
    pty.spawn("/bin/fish")
    return asyncio.create_subprocess_exec("/bin/fish", stdout=asyncio.subprocess.PIPE, stdin=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, bufsize = 0)

async def input_handler(proc, ws):
    while True:
        msg = await ws.recv()
        await ws.send(msg)
        print(msg)

async def output_handler(proc, ws):
    while True:
        output = (await proc.stdout.readline()).decode("utf-8")
        if output != "":
            print(output)
            await ws.send(output)
    await ws.send("[PROCESS ENDED]")

async def shell_ws(ws, _):
    proc = await get_shell()

    done, pending = await asyncio.wait(
        [asyncio.ensure_future(input_handler(proc, ws)), asyncio.ensure_future(output_handler(proc, ws))],
        return_when=asyncio.FIRST_COMPLETED
    )

    for task in pending:
        task.cancel()

server = websockets.serve(shell_ws, "localhost", 1234)
asyncio.get_event_loop().run_until_complete(server)
asyncio.get_event_loop().run_forever()