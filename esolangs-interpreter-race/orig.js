const { regex, sequenceOf, char, choice, many1, many, str, coroutine, possibly } = require("arcsecond")
const readline = require("readline-sync")

const spaces = regex(/^ */)
const whitespace = regex(/^[ \n\t]*/)
const name = regex(/^[^ \n\t():]+/)
const code = many(coroutine(function*() {
    yield spaces
    return yield choice([
        coroutine(function*() {
            yield char("(")
            const x = yield code
            yield spaces
            yield char(")")
            return x
        }),
        name
    ])
}))
const program = sequenceOf([
    many1(coroutine(function*() {
        yield whitespace
        const n = yield name
        yield whitespace
        yield str(":=")
        const c = yield code
        return { code: c, name: n }
    })),
    possibly(whitespace)
]).map(([x, _]) => x)

const parsed = program.run(`_mulloop := (pop warp new new new new new new new new new new warp _mulloop)
10* := warp new enter warp _mulloop exit pop warp exit send warp enter
[ := new enter
0 := 10*
1 := 10* new
2 := 10* new new
3 := 10* new new new
4 := 10* new new new new
5 := 10* new new new new new
6 := 10* new new new new new new
7 := 10* new new new new new new new
8 := 10* new new new new new new new new
9 := 10* new new new new new new new new new
] := exit
. := ] write [

main := [ 7 2 . 1 0 1 . 1 0 8 . 1 0 8 . 1 1 1 . 4 4 . 3 2 . 1 1 9 . 1 1 1 . 1 1 4 . 1 0 8 . 1 0 0 . 3 3 . 1 0 . ]
`).result
//const parsed = program.run(`main := read write main`).result

// ---------

let stackL = {depth: 0, children: []}, stackR = {depth: 0, children: []};
let currentIsLeft = true;

function depthDelta(x) {
    if(currentIsLeft)
        stackL["depth"]+=x;
    else
        stackR["depth"]+=x;
}

function currentStack() {
    let depth, currentStack;
    
    if(currentIsLeft) {
        depth = stackL["depth"];
        currentStack = stackL["children"];
    } else {
        depth = stackR["depth"];
        currentStack = stackR["children"];
    }
    
    for(let i = 0; i < depth; i++) {
        const s = currentStack.length - 1
        currentStack = currentStack[s];
    }
    
    return currentStack;
}

// ---------

function wrap_new() {
    currentStack().push([]);
}

function wrap_pop() {
    currentStack().pop();
}

function wrap_enter() {
    depthDelta(1)
}

function wrap_exit() {
    depthDelta(-1)
}

function wrap_warp() {
    currentIsLeft = !currentIsLeft;
}

function wrap_send() {
    let toMove = currentStack().pop();
    
    wrap_warp();
    
    currentStack().push(toMove);

    wrap_warp()
}

function wrap_read(n) {
    let thisStack = [];
    
    for(let i = 0; i < n; i++) {
        thisStack.push([]);
    }
    
    currentStack().push(thisStack);
}

function wrap_write() {
    return currentStack().pop().length;
}

// ---------

const env = {
    warp: wrap_warp,
    read: () => {
        wrap_read(readline.question("input char: ").codePointAt(0))
    },
    write: () => {
        console.log("output char:", String.fromCodePoint(wrap_write()))
    },
    send: wrap_send,
    exit: wrap_exit,
    enter: wrap_enter,
    pop: wrap_pop,
    new: wrap_new,
}

for (const def of parsed) {
    env[def.name] = def.code
}

const DEBUG = false

const execute = code => {
    for (const fn of code) {
        //console.log("stacks", stackL, stackR)
        // is bracketed, run if stack not empty
        if (Array.isArray(fn)) {
            if (currentStack().length !== 0) {
                if (DEBUG) console.log("brackets", fn)
                execute(fn)
            }
        // is a regular function call or whatever, run it
        } else {
            const v = env[fn]
            if (!v) {
                throw new Error(fn + " is undefined")
            }
            if (typeof v === "function") {
                if (DEBUG) console.log("builtin", fn)
                v()
            } else {
                if (DEBUG) console.log("normal", fn)
                execute(v)
            }
        }
    }
}

execute(env.main)