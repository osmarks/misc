from PIL import Image
import enum
import random

rng = random.Random()
def randomize(x, pos, m):
    rng.seed(bytes(x) + pos[0].to_bytes(4, "little") + pos[1].to_bytes(4, "little"), 2)
    return rng.randint(0, m), rng.randint(0, 255)

class Command(enum.Enum):
    DIV = 0
    DRP = 1
    SDIZ = 2
    MOD = 3
    READ_IN = 4
    ADD = 5
    PUSH = 6
    MUL = 7
    ROT = 8
    UNROT = 9
    DUP = 10
    CWROTATE = 11
    ACWROTATE = 12
    SETDIR = 13
    UNASSIGNED_1 = 14
    EXIT = 15
    OUT = 16
    SWP = 17
    NOP = 18

dirs = { "up": (0, -1), "down": (0, 1), "right": (1, 0), "left": (-1, 0), "downright": (1, 1), "upright": (1, -1), "up2": (0, -2), "upleft": (-1, -1), "up3": (0, -3) }
def setdir(d):
    x, y = dirs[d]
    x, y = x + 3, y + 3
    return (x << 3) + y

def go(d): return Command.SETDIR, setdir(d)

inp = [
    [ Command.ACWROTATE,                 Command.ROT,       (Command.SETDIR, setdir("right")),  (Command.SETDIR, setdir("down"))],
    [ Command.NOP,                      (Command.PUSH, 32),  Command.UNROT,                      Command.NOP ],
    [ (Command.PUSH, 0)             ,    Command.UNROT,      Command.DUP,                        Command.MUL ],
    [ (Command.PUSH, 1),                 Command.DRP,        Command.ROT       ,                 Command.UNROT         ,  go("down"),  Command.NOP,         (Command.SETDIR, setdir("left")) ],
    [ (Command.SETDIR, setdir("right")), Command.READ_IN,    Command.CWROTATE    ,               Command.ADD,             go("right"), (Command.PUSH, 128), Command.ADD, Command.MUL ],
    [ go("down"),                        Command.EXIT,       Command.NOP,                        Command.ROT,             Command.NOP ],
    [ Command.DUP,                       go("upleft") ,        Command.NOP,                        go("upright")  ],
    [ Command.UNROT,             (Command.SDIZ, setdir("up2"))],
    [ Command.DUP    ,                  Command.NOP ],
    [ Command.ROT ,                    Command.NOP],
    [ Command.MOD ,                    Command.NOP],
    [ Command.OUT                , Command.NOP ],
    [ Command.DUP, Command.NOP ],
    [ Command.UNROT, go("up") ],
    [ Command.DIV, Command.SWP ],
    [ go("right"), go("up") ],
    [ None,         go("up3") ]
]

im = Image.new("RGB", (max(map(len, inp)), len(inp)))
px = im.load()
for y, row in enumerate(inp):
    for x, op in enumerate(row):
        if op:
            param = None
            if isinstance(op, tuple):
                op, param = op
            print(x, y, op, param)
            # brute force muahahaha
            command_id = op.value
            while True:
                rgb = (random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
                cmd, arg = randomize(rgb, (x, y), Command.NOP.value)
                if cmd == command_id and (param is None or arg == param):
                    px[x, y] = rgb
                    break
im.save("/tmp/out.png")