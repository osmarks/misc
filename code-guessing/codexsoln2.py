# Programs are to validate JSON according to the JSON spec (https://www.json.org/), with the exception that you may assume that the string will consist entirely of the classic printable ASCII characters (codepoints 32-127, horizontal tabs, and newlines).
# You may additionally assume that the input will not be nested more than 16 levels.
def entry(string):
    string = string.strip()
    if len(string) == 0:
        return True
    if string[0] == '{':
        return object(string)
    elif string[0] == '[':
        return array(string)
    elif string[0] in '-0123456789':
        return number(string)
    elif string[0] == '"':
        return string(string)
    else:
        return False

def object(string):
    if string[0] != '{':
        return False
    string = string[1:]
    if string[0] == '}':
        return True
    string = string.strip()
    if string[0] != '"':
        return False
    string = string[1:]
    if string[0] != ':':
        return False
    string = string[1:]
    string = string.strip()
    if not entry(string):
        return False
    string = string.strip()
    if string[0] == '}':
        return True
    if string[0] != ',':
        return False
    string = string[1:]
    string = string.strip()
    if not object(string):
        return False
    string = string.strip()
    if string[0] != '}':
        return False
    return True

def array(string):
    if string[0] != '[':
        return False
    string = string[1:]
    if string[0] == ']':
        return True
    string = string.strip()
    if not entry(string):
        return False
    string = string.strip()
    if string[0] == ']':
        return True
    if string[0] != ',':
        return False
    string = string[1:]
    string = string.strip()
    if not array(string):
        return False
    string = string.strip()
    if string[0] != ']':
        return False
    return True

def number(string):
    if string[0] not in '-0123456789':
        return False
    string = string[1:]
    if string[0] == '.':
        string = string[1:]
        if string[0] not in '0123456789':
            return False
        string = string[1:]
        while string[0] in '0123456789':
            string = string[1:]
    if string[0] not in '0123456789':
        return False
    string = string[1:]
    if string[0] not in 'eE':
        return False
    string = string[1:]
    if string[0] not in '+-':
        return False
    string = string[1:]
    if string[0] not in '0123456789':
        return False
    string = string[1:]
    while string[0] in '0123456789':
        string = string[1:]
    return True

def string(string):
    if string[0] != '"':
        return False
    string = string[1:]
    while string[0] != '"':
        if string[0] == '\\':
            string = string[1:]
            if string[0] not in '"\\/bfnrt':
                return False
            string = string[1:]
        else:
            string = string[1:]
    return True

def main():
    string = input()
    print(entry(string))

if __name__ == "__main__":
    main()