import regex

"""
WHITESPACE = r"[\t\n ]*"
NUMBER = r"\-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?"
ARRAY = f"(?:\[{WHITESPACE}(?:|(?R)|(?R)(?:,{WHITESPACE}(?R){WHITESPACE})*){WHITESPACE}])"
STRING = r'"(?:[^"\\\n]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*"'
TERMINAL = f"(?:true|false|null|{NUMBER}|{STRING})"
PAIR = f"(?:{WHITESPACE}{STRING}{WHITESPACE}:{WHITESPACE}(?R){WHITESPACE})"
OBJECT = f"(?:{{(?:{WHITESPACE}|{PAIR}|(?:{PAIR}(?:,{PAIR})*))}})"
VALUE = f"{WHITESPACE}(?:{ARRAY}|{OBJECT}|{TERMINAL}){WHITESPACE}"
print(VALUE)
def entry(s):
    return regex.fullmatch(VALUE, s, regex.V1)
"""
entry = lambda s: __import__("regex").fullmatch(r"""[\t\n ]*(?:(?:\[[\t\n ]*(?:|(?R)|(?R)(?:,[\t\n ]*(?R)[\t\n ]*)*)[\t\n ]*])|(?:{(?:[\t\n ]*|(?:[\t\n ]*"(?:[^"\\\n]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*"[\t\n ]*:[\t\n ]*(?R)[\t\n ]*)|(?:(?:[\t\n ]*"(?:[^"\\\n]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*"[\t\n ]*:[\t\n ]*(?R)[\t\n ]*)(?:,(?:[\t\n ]*"(?:[^"\\\n]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*"[\t\n ]*:[\t\n ]*(?R)[\t\n ]*))*))})|(?:true|false|null|\-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|"(?:[^"\\\n]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*"))[\t\n ]*""", s, regex.V1)