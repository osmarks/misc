import ast
import inspect
import types

class Sentinel: pass

SENTINEL = Sentinel()

def rewrite_recursion(f):
    _, pos = inspect.getsourcelines(f)
    source = inspect.getsource(f)
    source = '\n'.join(source.splitlines()[1:]) # remove the decorator first line.

    old_code_obj = f.__code__
    old_ast = ast.parse(source)

    def find_outermost_function_def(node):
        if isinstance(node, ast.FunctionDef):
            return node
        for child in ast.iter_child_nodes(node):
            if r := find_outermost_function_def(child): return r

    outer = find_outermost_function_def(old_ast)

    def rewrite(node):
        if node != outer and isinstance(node, ast.FunctionDef): return
        if isinstance(node, ast.Call):
            if node.func.id == outer.name:
                return ast.Yield(ast.Tuple([
                    ast.Tuple(node.args, ctx=ast.Load()),
                    ast.Tuple([ ast.Tuple([ast.Constant(value=kw.arg), kw.value], ctx=ast.Load()) for kw in node.keywords ], ctx=ast.Load())
                ], ctx=ast.Load()))

        for name, field in ast.iter_fields(node):
            if isinstance(field, ast.AST):
                replacement = rewrite(field)
                if replacement:
                    setattr(node, name, replacement)
            elif isinstance(field, list):
                for index, item in enumerate(field):
                    if isinstance(item, ast.AST):
                        replacement = rewrite(item)
                        if replacement:
                            field[index] = replacement

    rewrite(old_ast)
    ast.fix_missing_locations(old_ast)
    ast.increment_lineno(old_ast, pos)
    new_code_obj = compile(old_ast, old_code_obj.co_filename, "exec")
    inner_function = types.FunctionType(next(x for x in new_code_obj.co_consts if isinstance(x, types.CodeType)), f.__globals__, f.__name__, f.__defaults__)

    def trampoline(*args, **kwargs):
        stk = [inner_function(*args, **kwargs)]
        return_value = SENTINEL
        while stk:
            top = stk[-1]
            try:
                if return_value is not SENTINEL:
                    args, kwargs = top.send(return_value)
                else:
                    args, kwargs = next(top)
                kwargs = dict(kwargs)
                stk.append(inner_function(*args, **kwargs))
                return_value = SENTINEL
                continue
            except StopIteration as i:
                return_value = i.value
                stk.pop()
        return return_value if return_value is not SENTINEL else None

    return trampoline

@rewrite_recursion
def rec_demo(n):
    if n <= 1: return n
    return rec_demo(n-1)

print(rec_demo(10000))