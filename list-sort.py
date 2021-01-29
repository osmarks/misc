from dataclasses import dataclass, field
import string
import functools
import operator
import random

@dataclass
class Symbol:
    name: str

@dataclass
class Quote:
    content: any

# Raised in case of fatal parsing errors, i.e. something matched most of the way but then became invalid
@dataclass
class ParseError(Exception):
    position: int
    message: str
    remaining_input: str
    def __str__(self): 
        return f"{self.message} at position {self.position}"

# Raised if the current parser cannot run on the current input
class NoParse(Exception):
    pass

# approximate grammar
# symbol ::= [^'0-9()" \t\n][^'()" \t\n]+
# int ::= -? [0-9]+
# str ::= '"' [^"]+ '"'
# whitespace ::= [ \t\n]+
# list ::= '(' (expr whitespace)+ ')'
# quoted ::= ' expr
# expr ::= symbol | int | str | list | quoted

# Recursive descent parser
class Parser:
    def __init__(self, s):
        self.s = s
        self.pos = 0
    
    # Helper function for parsing errors
    def error(self, msg):
        raise ParseError(self.pos, msg, self.s[self.pos:])

    # Gets the current character being parsed
    def current(self):
        try:
            return self.s[self.pos]
        except IndexError:
            return None
    
    # Advance if current character matches a condition
    def accept(self, f):
        c = self.current()
        if c:
            match = f(c) if callable(f) else c in f
            if match:
                self.pos += 1
                return c
    
    # Advance if current character matches a condition, else switch to alternate parser
    def expect(self, f):
        x = self.accept(f)
        if not x: raise NoParse
        return x
    
    # Advance if current character matches a condition, else raise parse error
    def expect_strong(self, f, m):
        x = self.accept(f)
        if not x: self.error(m)
        return x
    
    # Try multiple parsers in sequence
    def choose(self, parsers):
        for parser in parsers:
            try:
                return parser()
            except NoParse:
                pass

    # Parse an integer. Does not actually support negative numbers due to parsing ambiguities.
    def int(self):
        buf = self.expect("1234567890")
        while c := self.accept("1234567890"):
            buf += c
        return int(buf)

    # Parse a string. No escape sequences are supported.
    def str(self):
        if not self.expect('"'): return
        buf = ""
        while c := self.accept(lambda x: True):
            if c == '"': return buf
            buf += c
        self.error("unterminated string")

    # Parse a symbol.
    def symbol(self):
        buf = self.expect(lambda x: x not in "'0123456789()\"\t\n ")
        while c := self.accept(lambda x: x not in "'()\"\t\n "):
            buf += c
        return Symbol(buf)

    # Parse a quoted expr.
    def quoted(self):
        self.expect("'")
        return Quote(self.expr())

    # Skip whitespace
    def whitespace(self):
        while self.accept(" \t\n"): pass

    # Parse a list of exprs
    def list(self):
        self.expect("(")
        items = []

        def whitespace_expr():
            self.whitespace()
            r = self.expr()
            self.whitespace()
            return r
        
        while (x := whitespace_expr()) != None:
            items.append(x)
        
        self.expect_strong(")", "unterminated list")
        return items

    def expr(self):
        return self.choose([self.list, self.str, self.int, self.quoted, self.symbol])

    # Parse an entire program; error on trailing things, allow whitespace at start/end
    def parse(self):
        self.whitespace()
        expr = self.expr()
        self.whitespace()
        if self.pos != len(self.s):
            self.error(f"trailing {repr(self.s[self.pos:])}")
        return expr

# The environment is a stack of increasingly general scopes.
class Environment:
    binding_stack: list[dict[str, any]]

    def __init__(self, s):
        self.binding_stack = s

    def __getitem__(self, key):
        for bindings in self.binding_stack:
            if bindings.get(key) != None: return bindings.get(key)
        raise KeyError(key)

    def __setitem__(self, key, value):
        self.binding_stack[0][key] = value

    def child(self, initial_bindings=None):
        if initial_bindings == None: initial_bindings = {}
        return Environment([initial_bindings] + self.binding_stack)

@dataclass
class Function:
    params: list[str]
    body: any
    environment: Environment
    name: str = "[anonymous]"

    def __repr__(self):
        return f"<{self.name}({', '.join(self.params)})>"

# Evaluator with some tail recursion optimization capability. Env/scope handling is mildly broken and only per-function instead of per-expr.
# special forms:
# let: define functions or values
# either mutate the existing environment or create a new temporary one
# functions are (let (x y z) (+ x y z)), values are (let x "string")
# if used as (let thing "stuff"), works mutably
# if used as (let otherthing "not stuff" (+ otherthing " but things")) then creates new scope
# cond: do different things based on some conditionals
# used as (cond (condition1 action1) (condition2 action2)) - the expr corresponding to the first true condition is evaluated
# do: group side-effectful exprs together - evaluate them in sequence and return the last one
# lambda: define functions without binding them to a name
def evaluate(x, env):
    while True:
        if isinstance(x, list):
            # special form handling
            if isinstance(x[0], Symbol):
                name = x[0].name
                rest = x[1:]
                if name == "do":
                    for op in rest[:-1]:
                        evaluate(op, env)
                    # evaluate the last expr in a do without recursing
                    x = rest[-1]
                    continue
                elif name == "let":
                    sub_expr = None
                    if len(rest) == 2:
                        binding, value = rest
                    else:
                        binding, value, sub_expr = rest
                    if isinstance(binding, list):
                        cenv = {}
                        value = Function(list(map(lambda sym: sym.name, binding[1:])), value, env.child(cenv), binding[0].name)
                        cenv[binding[0].name] = value
                        binding = binding[0]
                    else:
                        value = evaluate(value, env)

                    if sub_expr:
                        # evaluate the sub-expr nonrecursively
                        x = sub_expr
                        env = env.child({ binding.name: value })
                        continue
                    else:
                        env[binding.name] = value
                        return
                
                elif name == "cond":
                    # Check each condition in turn. 
                    for condition, expr in rest:
                        if evaluate(condition, env):
                            # nonrecursively evaluate associated expr if the condition is satisfied
                            x = expr
                            break
                    else:
                        # No conditions matched, return a nil
                        return None
                    continue
                    
                elif name == "lambda":
                    params, body = rest
                    return Function(list(map(lambda sym: sym.name, params)), body, env)

            val = evaluate(x[0], env)
            
            # evaluate user-defined function
            if isinstance(val, Function):
                params = dict(zip(val.params, map(lambda x: evaluate(x, env), x[1:])))
                env = val.environment.child(params)
                x = val.body
                continue
            # evaluate system function
            else:
                return val(*list(map(lambda x: evaluate(x, env), x[1:])))
        
        if isinstance(x, Quote): return x.content
        if isinstance(x, Symbol): return env[x.name]
        return x

# Sorting functionality, as well as some other things in here for testing
# Uses a tail-recursive continuation-passing-style Haskell-style quicksort (so not actually that quick)
expr = Parser("""
(do
    (let (id x) x)
    (let (snd xs) (head (tail xs)))

    (let (take_rec out xs n) (cond
        ((= n 0) out)
        (true (take_rec (cons (head xs) out) (tail xs) (- n 1)))
    ))

    (let (reverse_rec xs a) (cond
        ((= xs '()) a)
        (true (reverse_rec (tail xs) (cons (head xs) a)))
    ))

    (let (drop xs n) (cond
        ((= n 0) xs)
        (true (drop (tail xs) (- n 1)))
    ))

    (let (take xs n) (reverse_rec (take_rec '() xs n) '()))

    (let (count_rec xs n) (cond
        ((= n 0) xs)
        (true (count_rec (cons n xs) (- n 1)))
    ))
    (let (count n) (count_rec '() n))

    (let (filter_rec xs pred acc) (cond
        ((= xs '()) acc)
        (true (filter_rec (tail xs) pred (cond
            ((pred (head xs)) (cons (head xs) acc))
            (true acc)
        )))
    ))
    (let (filter pred xs) (reverse (filter_rec xs pred '())))
    (let (partition_rec xs pred acc) (cond
        ((= xs '()) acc)
        (true (partition_rec (tail xs) pred (cond
            ((pred (head xs)) (list (cons (head xs) (head acc)) (snd acc)))
            (true (list (head acc) (cons (head xs) (snd acc))))
        )))
    ))

    (let (qsort xs cont) (cond
        ((= xs '()) (cont '()))
        (true (do
            (let h (head xs))
            (let t (tail xs))
            (let part_result (partition_rec t (lambda (x) (< x h)) '(() ())))
            (qsort (head part_result)
                (lambda (ls) (qsort (snd part_result) 
                    (lambda (rs) (cont (+ ls (list h) rs))))))
        ))
    ))
)
""").parse()

env = Environment([{
    "+": lambda *args: functools.reduce(operator.add, args),
    "-": operator.sub,
    "*": lambda *args: functools.reduce(operator.mul, args),
    "/": operator.floordiv,
    "head": lambda xs: None if len(xs) == 0 else xs[0],
    "tail": lambda xs: xs[1:],
    "cons": lambda x, xs: [x] + xs,
    "reverse": lambda xs: xs[::-1], # can be implemented inside the language, but this is much faster
    "length": len,
    "print": print,
    "=": operator.eq,
    "!=": operator.ne,
    ">": operator.gt,
    "<": operator.lt,
    ">=": operator.ge,
    "<=": operator.le,
    "rand": lambda: random.randint(0, 1),
    "true": True,
    "false": False,
    "nil": None,
    "list": lambda *args: list(args),
}])

evaluate(expr, env)

def entry(to_sort):
    return evaluate([Symbol("qsort"), Quote(to_sort), Symbol("id"), to_sort], env)