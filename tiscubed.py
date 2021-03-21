import dataclasses
import re
import typing
import operator
import functools
import enum
import collections
import typing

MEM_SIZE = 256

WAITING = object()

class Direction(enum.Enum):
    UP = 0
    DOWN = 1
    RIGHT = 2
    LEFT = 3
    ANY = 8

class RunState(enum.Enum):
    IDLE = 0
    RUNNING = 1
    BLOCKED = 2
    STOPPED = 3

@dataclasses.dataclass
class Node:
    # node memory
    # code is loaded in at the start of memory
    # the program counter is simply the last memory location
    memory: bytearray = dataclasses.field(default_factory=lambda: bytearray(MEM_SIZE))
    state: RunState = RunState.IDLE
    input_buffer: dict[Direction, int] = dataclasses.field(default_factory=dict)
    read_return_location: typing.Optional[int] = None
    #output_buffer: dict[Direction, int] = dataclasses.field(default_factory=dict)
    blocked_on: typing.Optional[Direction] = None

    def __getitem__(self, loc):
        return self.memory[loc]

    def __setitem__(self, loc, value):
        assert loc is not None
        if isinstance(value, list):
            for i, x in enumerate(value):
                self.memory[loc + i] = x % 256
        else:
            self.memory[loc] = value % 256

def pad_list(l, n, default):
    return l + [default] * (n - len(l))

def display_hex(x): return hex(x)[2:].zfill(2)

def memdump(mem):
    out = []
    out.append("   \x1b[31;1m" + " ".join(map(display_hex, range(16))) + "\x1b[0m")
    for i in range(0, len(mem), 16):
        out.append("\x1b[32;1m" + display_hex(i) + "\x1b[0m " + " ".join(map(display_hex, mem[i:i+16])))
    return "\n".join(out)

@dataclasses.dataclass
class ExecutionContext:
    node: Node
    params: tuple[int]
    io: any

@dataclasses.dataclass
class Op:
    name: str
    function: typing.Callable[ExecutionContext, None]
    ip_advancement: int

opcodes = {}

def make_binop_wrapper(name, fn):
    @functools.wraps(fn)
    def wrapper(ctx):
        ctx.node[ctx.params[0]] = fn(ctx.node[ctx.params[1]], ctx.node[ctx.params[2]])
    return Op(name, wrapper, 4)

def nop(node, *_): pass
opcodes[0x00] = Op("NOP", nop, 1)

def test_print(ctx):
    print(f"{ctx.node[-1]}: {display_hex(ctx.params[0])} = {display_hex(ctx.node[ctx.params[0]])}")
opcodes[0x01] = Op("PRINT", test_print, 2)

def mov(ctx): # MOV dest src
    ctx.node[ctx.params[0]] = ctx.node[ctx.params[1]]
opcodes[0x02] = Op("MOV", mov, 3)

opcodes[0x03] = make_binop_wrapper("ADD", operator.add) # ADD dest src1 src2

def mnz(ctx): # "move if not zero"; MEZ cond dest src
    if ctx.node[ctx.params[0]] != 0: ctx.node[ctx.params[1]] = ctx.node[ctx.params[2]]
opcodes[0x04] = Op("MNZ", mnz, 4)

def inc(ctx): # INC dest
    ctx.node[ctx.params[0]] += 1
opcodes[0x05] = Op("INC", inc, 2)

opcodes[0x06] = make_binop_wrapper("MUL", operator.mul)
opcodes[0x07] = make_binop_wrapper("MOD", operator.mod)
opcodes[0x08] = make_binop_wrapper("DIV", operator.floordiv)
opcodes[0x09] = make_binop_wrapper("SUB", operator.sub)
opcodes[0x10] = make_binop_wrapper("OR", operator.or_)
opcodes[0x11] = make_binop_wrapper("AND", operator.and_)
opcodes[0x12] = make_binop_wrapper("SHR", operator.rshift)
opcodes[0x13] = make_binop_wrapper("SHL", operator.lshift)

def mez(ctx): # "move if equal to zero"; MEZ cond dest src
    if ctx.node[ctx.params[0]] == 0: ctx.node[ctx.params[1]] = ctx.node[ctx.params[2]]
opcodes[0x14] = Op("MEZ", mez, 4)

def idm(ctx): # "indirect destination move" - destination parameter is a memory location to fetch the destination from; IDM idest src
    ctx.node[ctx.node[ctx.params[0]]] = ctx.node[ctx.params[1]]
opcodes[0x15] = Op("IDM", idm, 3)

def ism(ctx): # "indirect source move"; ISM dest isrc
    ctx.node[ctx.params[0]] = ctx.node[ctx.node[ctx.params[1]]]
opcodes[0x16] = Op("ISM", ism, 3)

def imv(ctx): # "indirect move" - both destination and source are indirected; IMV idest isrc
    ctx.node[ctx.node[ctx.params[0]]] = ctx.node[ctx.node[ctx.params[1]]]
opcodes[0x17] = Op("IMV", imv, 3)

opcodes[0x18] = make_binop_wrapper("SADD", lambda a, b: min(a + b, 255))
opcodes[0x19] = make_binop_wrapper("SSUB", lambda a, b: max(a - b, 0))

def write(ctx):
    ctx.io["write"](ctx.params[0], ctx.node[ctx.params[1]])
opcodes[0x20] = Op("WR", write, 3)

def read(ctx):
    ctx.io["read"](ctx.params[0], ctx.params[1])
opcodes[0x21] = Op("RE", read, 3)

def dump(ctx):
    print(memdump(ctx.node.memory))
opcodes[0xfe] = Op("DUMP", dump, 1)

def halt(ctx):
    memdump(ctx.node.memory)
    ctx.node.state = RunState.STOPPED
opcodes[0xff] = Op("HALT", halt, 1)

def step_node(node, io):
    ip = node[-1]
    instr = node[ip:ip + 4].ljust(4, b"\x00")
    opcode, a, b, c = instr

    op = opcodes.get(opcode)
    if op:
        node[-1] += op.ip_advancement
        op.function(ExecutionContext(node, (a, b, c), io))
    else:
        print("unknown instr", " ".join(map(display_hex, instr)), "at", display_hex(ip))
        print(memdump(node.memory))
        node[-1] += 1
        node.state = RunState.STOPPED

def flatten(xs):
    for x in xs:
        if isinstance(x, (list, map, filter)):
            for y in x:
                yield y
        else:
            yield x

def assemble(code):
    instructions = {}
    for opcode, op in opcodes.items():
        instructions[op.name] = (opcode, op.ip_advancement)

    out = []
    # implicit "I" label for program counter for branching
    labels = { "I": MEM_SIZE - 1 }
    unresolved_labels = collections.defaultdict(set)
    backfill = collections.defaultdict(set)
    position = 0

    def resolve(param):
        # ! operator on params emulates this ISA having immediate parameters by 
        if param[0] == "!":
            # add to list of values needing storage, and add current output position to list of places to update when it gets a location
            backfill[param[1:]].add(position)
            return
        if re.match(r"[A-Za-z][A-Za-z0-9_\-]*", param): # is label
            try:
                return labels[param]
            except KeyError: # resolve label location later
                unresolved_labels[param].add(position)
                return 0
        else:
            return int(param, 16) % 256

    def write(*things):
        for value in flatten(things):
            if isinstance(value, int):
                out.append(value)
            else:
                out.append(resolve(value))
            nonlocal position
            position = len(out)

    for line in filter(lambda x: x != "", map(str.strip, code.split("\n"))):
        tokens = line.split()

        for index, token in enumerate(tokens):
            if token.startswith("#"):
                tokens = tokens[:index]
                break

        if len(tokens) == 0: continue

        # label definition
        if tokens[0].endswith(":"):
            label = tokens.pop(0)[:-1]
            labels[label] = position
            for unresolved_loc in unresolved_labels[label]:
                out[unresolved_loc] = position
            del unresolved_labels[label]
        
        if len(tokens) > 0:
            ltype = tokens[0].upper()
            
            # raw output
            if ltype == "!": write(tokens[1:])
            # NOP padding
            elif ltype == "!PAD":
                write([0] * int(tokens[1], 16))
            # instruction mnemonic
            else:
                instr = instructions[ltype]
                if instr[1] != 0: # special instructions might move it variable amounts at some point
                    assert len(tokens) == instr[1], f"{ltype} takes {instr[1] - 1} operands"
                write(instr[0], tokens[1:])

    while len(backfill) > 0:
        for value, locations in list(backfill.items()):
            newpos = position
            write(value)
            for location in locations:
                out[location] = newpos
            print(f"Backfilled {display_hex(newpos)}: {value}")
            del backfill[value]

    for k in unresolved_labels:
        print("Unresolved label:", k)

    if len(out) >= MEM_SIZE:
        print("Code space exceeded")

    return out

n = Node()
n.state = RunState.RUNNING
n[0] = assemble("""
LOOP:
inc INCBUF
add TEMP !-50 INCBUF
# debug print
#! 01 INCBUF
#wr 0 INCBUF
#re 0 INCBUF
mnz TEMP I !LOOP
halt

INCBUF: ! 1
TEMP: ! 0
OUT: ! 44
""")
n2 = Node()
n2.state = RunState.RUNNING
n2[0] = assemble("""
LOOP2:
inc INCBUF
add TEMP !-50 INCBUF
mnz TEMP I !LOOP2
LOOP:
re 8 BEE
#wr 1 BEE
#! 01 BEE
mov I !LOOP

TEMP: ! 0
BEE: ! 0
INCBUF: ! 4
""")
n3 = Node()
n3.state = RunState.RUNNING
n3[0] = assemble("""
mov M !0
mov B !0
LOOP:
sub X M !40
mez X I !DONE
wr 0 M
ism B M
inc M
wr 0 B
mov I !LOOP
DONE:
wr 0 !0FF
halt

M: ! 0
X: ! 87
B: ! 0
""")

def offset(tup, idx, by): 
    return tup[:idx] + (tup[idx] + by,) + tup[idx + 1:]

opposite_directions = { Direction.UP: Direction.DOWN, Direction.DOWN: Direction.UP, Direction.LEFT: Direction.RIGHT, Direction.RIGHT: Direction.LEFT }

def apply_direction(coords, dir):
    if dir == Direction.UP: return offset(coords, 1, 1)
    elif dir == Direction.DOWN: return offset(coords, 1, -1)
    elif dir == Direction.LEFT: return offset(coords, 0, -1)
    elif dir == Direction.RIGHT: return offset(coords, 0, 1)

bootloader = """
!PAD E0
LOOP:
re 8 RI # read target location from arbitrary side into buffer
add RJ RI !1
mez RJ I !0 # if target location is 255, jump to 0 (normal thing start)
re 8 RJ # read data into other buffer
idm RI RJ # transfer data into specified location
mov I !LOOP # unconditional jump back to start
RI: ! 0
RJ: ! 0
"""
bootloader_machine_code = assemble(bootloader)

def new_node():
    n = Node()
    print("starting node")
    n.state = RunState.RUNNING
    n[0] = bootloader_machine_code
    return n

grid = collections.defaultdict(new_node)
grid[0, 0] = n
grid[0, 1] = n2
grid[0, 2] = n3

def write(node, orig, dir, val):
    #print("WR", orig, dir, hex(val))
    if dir in node.input_buffer:
        print("deadlock (write) by", orig, "in", dir, "target", grid[apply_direction(orig, dir)], node.input_buffer)
        node.state = RunState.BLOCKED
        return
    other = grid[apply_direction(orig, dir)]
    opp = opposite_directions[dir]
    # if the other node is waiting on communication from this node, dump data from here into memory
    # and unblock it
    if opp == other.blocked_on or other.blocked_on == Direction.ANY:
        other.blocked_on = None
        other.state = RunState.RUNNING
        other[other.read_return_location] = val
    # if it is not, then put data into its input buffer (it will unblock this node if it ever reads on this)
    else:
        other.input_buffer[opp] = val
        # switch state to blocked
        node.state = RunState.BLOCKED
        node.blocked_on = dir

def read(node, orig, dir, ret):
    #print("RE", orig, dir)
    if dir == Direction.ANY and len(node.input_buffer) > 0:
        rdir, val = node.input_buffer.popitem()
        other = grid[apply_direction(orig, rdir)]
        opp = opposite_directions[rdir]
        if other.blocked_on == opp or other.blocked_on == Direction.ANY:
            other.blocked_on = None
            other.state = RunState.RUNNING
        node[ret] = val
        return
    # if input already buffered
    if dir in node.input_buffer:
        other = grid[apply_direction(orig, dir)]
        opp = opposite_directions[dir]
        # remove blocking state
        if other.blocked_on == opp or other.blocked_on == Direction.ANY:
            other.blocked_on = None
            other.state = RunState.RUNNING
        # put buffered data into memory at specified return address
        node[ret] = node.input_buffer[dir]
        del node.input_buffer[dir]
    else:
        # set to blocked, put return address in node data
        node.read_return_location = ret
        node.state = RunState.BLOCKED
        node.blocked_on = dir

while True:
    ran_one = False
    for coords, node in list(grid.items()):
        #the reason being is that then you could play an awesome game of core-war on itprint(coords, node.state)
        if node.state == RunState.RUNNING:
            step_node(node, {
                "write": lambda dir, val: write(node, coords, Direction(dir), val),
                "read": lambda dir, ret: read(node, coords, Direction(dir), ret)
            })
            ran_one = True

    if not ran_one: break
