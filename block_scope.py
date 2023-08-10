import ast
import inspect
import types

BLOCKS = (
    ast.If,
    ast.For, ast.AsyncFor, ast.While,
    ast.Try,
    ast.With, ast.AsyncWith,
    ast.Match
)

def block_scope(f):
    _, pos = inspect.getsourcelines(f)
    source = inspect.getsource(f)
    source = '\n'.join(source.splitlines()[1:]) # remove the decorator first line.

    old_code_obj = f.__code__
    old_ast = ast.parse(source)

    def rewrite(node, varstack):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            varstack[-1].update(x.asname or x.name for x in node.names)
        if isinstance(node, BLOCKS):
            varstack = varstack + [set()]
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            varstack[-1].add(node.name)
            varstack = varstack + [set(arg.arg for arg in node.args.args)]
        if isinstance(node, (ast.Nonlocal, ast.Global)):
            varstack[-1].update(node.names)
        if isinstance(node, ast.Name):
            if isinstance(node.ctx, ast.Load):
                if all(node.id not in s for s in varstack):
                    node.id += "\u200b" * len(varstack)
            elif isinstance(node.ctx, ast.Store):
                varstack[-1].add(node.id)

        for child in ast.iter_child_nodes(node):
            rewrite(child, varstack)
        return node

    new_ast = rewrite(old_ast, [set(f.__globals__) | set(dir(__builtins__))])
    ast.increment_lineno(new_ast, pos)
    new_code_obj = compile(new_ast, old_code_obj.co_filename, "exec")
    new_f = types.FunctionType(new_code_obj.co_consts[0], f.__globals__)
    return new_f

@block_scope
def example(demo1, demo2):
    import random as rand
    import random
    from random import randint
    if demo1:
        if random.randint(0, 1) or randint(0, 3) == 3 or rand.randint(0, 5) == 5:
            x = 3
        else:
            x = 4
        print(x) # error
    x = 723
    def test():
        nonlocal x
        x = 4
    if demo2:
        test()
    print(x)

print(example)
example(False, True)