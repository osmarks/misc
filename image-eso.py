from PIL import Image
import random

im = Image.open("/tmp/out.png")
px = im.load()

rng = random.Random()
def randomize(x, pos, m):
    rng.seed(bytes(x) + pos[0].to_bytes(4, "little") + pos[1].to_bytes(4, "little"), 2)
    return rng.randint(0, m), rng.randint(0, 255)

COMMANDS = 18
size = im.size
position = (0, 0)
direction = (1, 0)
matrix_1 = ((0, 1), (-1, 0))
matrix_2 = ((0, -1), (1, 0))
def rotate(matrix):
    global direction
    a = direction[0] * matrix[0][0] + direction[1] * matrix[0][1]
    b = direction[0] * matrix[1][0] + direction[1] * matrix[1][1]
    direction = (a, b)
stack = []
inbuf = ["b", "e", "e", "s", "i", "n", "c", "u", "r", "s", "e"]

class Command(__import__("enum").Enum):
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
    EXIT = 15
    UNASSIGNED_1 = 14
    DIV = 0
    OUT = 16
    SWAP = 17
    NOP = 18

while True:
    command, param = randomize(px[position], position, COMMANDS)
    print(command, position, direction, stack, Command(command))
    if command == 4:
        # read input
        if len(inbuf) > 0:
            stack.append(ord(inbuf.pop(0)))
        else:
            rotate(matrix_1)
    elif command == 5:
        # add 
        if len(stack) >= 2:
            stack.append(stack.pop() + stack.pop())
        else:
            rotate(matrix_2)
    elif command == 3:
        # mod
        if len(stack) >= 2:
            stack.append(stack.pop() % stack.pop())
        else:
            rotate(matrix_2)
    elif command == 0:
        # div
        if len(stack) >= 2:
            stack.append(stack.pop() // stack.pop())
        else:
            rotate(matrix_2)
    elif command == 6: # push
        stack.append(param)
    elif command == 8:
        # rot
        if len(stack) > 0:
            stack = [stack.pop()] + stack
    elif command == 9:
        # unrot
        if len(stack) > 0:
            stack.append(stack.pop(0))
    elif command == 10:
        stack.extend([stack.pop()] * 2)
    elif command == 7:
        # mul 
        if len(stack) >= 2:
            stack.append(stack.pop() * stack.pop())
        else:
            rotate(matrix_2)
    elif command == 11:
        rotate(matrix_1)
    elif command == 12:
        rotate(matrix_2)
    elif command == 13: # setdir
        arg = param
        lowbits = (arg & 0b111) - 3
        highbits = ((arg >> 3) & 0b111) - 3
        direction = highbits, lowbits
    elif command == 2: # setdir if zero
        if len(stack) > 0 and stack[-1] == 0:
            arg = param
            lowbits = (arg & 0b111) - 3
            highbits = ((arg >> 3) & 0b111) - 3
            direction = highbits, lowbits
    elif command == 16:
        inbuf.append(chr(stack.pop()))
    elif command == 17:
        if len(stack) >= 2:
            a, b = stack.pop(), stack.pop()
            stack.append(a)
            stack.append(b)
    elif command == 1:
        if len(stack) > 0: stack.pop()
    elif command == 15:
        break

    position = (position[0] + direction[0], position[1] + direction[1])
    while position[0] < 0 or position[1] < 0 or position[0] >= size[0] or position[1] >= size[1]:
        position = (position[0] % size[0], position[1] % size[1])
print(stack, inbuf)