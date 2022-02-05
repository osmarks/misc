# Programs are to validate JSON according to the JSON spec (https://www.json.org/), with the exception that you may assume that the string will consist entirely of the classic printable ASCII characters (codepoints 32-127, horizontal tabs, and newlines).
# You may additionally assume that the input will not be nested more than 16 levels.
def entry(string):
    if string == "":
        return True
    elif string[0] == '{':
        return entry_object(string)
    elif string[0] == '[':
        return entry_array(string)
    elif string[0] == '"':
        return entry_string(string)
    elif string[0] in '-0123456789':
        return entry_number(string)
    elif string[0] == 't':
        return entry_true(string)
    elif string[0] == 'f':
        return entry_false(string)
    elif string[0] == 'n':
        return entry_null(string)
    else:
        return False

def entry_object(string):
    if string[0] != '{':
        return False
    string = string[1:]
    if string[0] == '}':
        return True
    while True:
        if not entry_string(string):
            return False
        if not entry_colon(string):
            return False
        if not entry(string):
            return False
        if string[0] == '}':
            return True
        if not entry_comma(string):
            return False

def entry_array(string):
    if string[0] != '[':
        return False
    string = string[1:]
    if string[0] == ']':
        return True
    while True:
        if not entry(string):
            return False
        if string[0] == ']':
            return True
        if not entry_comma(string):
            return False

def entry_string(string):
    if string[0] != '"':
        return False
    string = string[1:]
    while True:
        if string[0] == '"':
            return True
        if string[0] == '\\':
            string = string[1:]
            if string[0] == 'u':
                string = string[1:]
                if not string[0] in '0123456789abcdef':
                    return False
                string = string[1:]
                if not string[0] in '0123456789abcdef':
                    return False
                string = string[1:]
                if not string[0] in '0123456789abcdef':
                    return False
                string = string[1:]
                if not string[0] in '0123456789abcdef':
                    return False
                string = string[1:]
            elif string[0] == '"':
                pass
            elif string[0] == '\\':
                pass
            elif string[0] == '/':
                pass
            elif string[0] == 'b':
                pass
            elif string[0] == 'f':
                pass
            elif string[0] == 'n':
                pass
            elif string[0] == 'r':
                pass
            elif string[0] == 't':
                pass
            else:
                return False
        else:
            string = string[1:]

def entry_number(string):
    if string[0] not in '-0123456789':
        return False
    string = string[1:]
    if string[0] == '.':
        string = string[1:]
        if string[0] not in '0123456789':
            return False
        string = string[1:]
    if string[0] in 'eE':
        string = string[1:]
        if string[0] in '+-':
            string = string[1:]
        if string[0] not in '0123456789':
            return False
        string = string[1:]
    if string[0] not in '0123456789':
        return False
    string = string[1:]
    return True

def entry_colon(string):
    if string[0] != ':':
        return False
    string = string[1:]
    return True

def entry_comma(string):
    if string[0] != ',':
        return False
    string = string[1:]
    return True

def entry_true(string):
    if string[0:4] != 'true':
        return False
    string = string[4:]
    return True

def entry_false(string):
    if string[0:5] != 'false':
        return False
    string = string[5:]
    return True

def entry_null(string):
    if string[0:4] != 'null':
        return False
    string = string[4:]
    return True

def main():
    string = input()
    if entry(string):
        print("Valid JSON")
    else:
        print("Invalid JSON")

if __name__ == "__main__":
    main()
