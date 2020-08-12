const { regex, sequenceOf, char, choice, many1, many, str, coroutine, possibly } = require("arcsecond")
const fs = require("fs").promises

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

const stdin = process.stdin
stdin.setRawMode(true)
stdin.resume()
let resolveNext = null
stdin.on("data", key => {
    // ctrl+C and ctrl+D
    if (key[0] === 3 || key[0] === 4) {
        return process.exit()
    }
    if (resolveNext) { resolveNext(key[0]) }
})
const awaitKeypress = () => new Promise((resolve, reject) => { resolveNext = resolve })

const DEBUG = false

const execute = async (code, env) => {
    for (const fn of code) {
        //console.log("stacks", stackL, stackR)
        // is bracketed, run if stack not empty
        if (Array.isArray(fn)) {
            if (currentStack().length !== 0) {
                if (DEBUG) console.log("brackets", fn)
                await execute(fn, env)
            }
        // is a regular function call or whatever, run it
        } else {
            const v = env[fn]
            if (!v) {
                throw new Error(fn + " is undefined")
            }
            if (typeof v === "function") {
                if (DEBUG) console.log("builtin", fn)
                await v()
            } else {
                if (DEBUG) console.log("normal", fn)
                await execute(v, env)
            }
        }
    }
}

const run = async () => {
    const code = await fs.readFile(process.argv[2], { encoding: "utf8" })
    const parseResult = program.run(code)
    if (parseResult.isError) {
        console.log(parseResult.error)
        process.exit(1)
    }
    const parsed = parseResult.result

    const env = {
        warp: wrap_warp,
        read: async () => {
            wrap_read(await awaitKeypress())
        },
        write: () => {
            process.stdout.write(Buffer.from([wrap_write()]))
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

    await execute(env.main, env)
}

const cleanup = () => {
    process.exit(0)
}
run().then(cleanup, cleanup)