#!/bin/env python3

chars = [chr(n) for n in range(126)]
firstchar = chars[0]
lastchar = chars[len(chars) - 1]

def increment_char(character):
    return chr(ord(character) + 1)

def old_increment_string(string_to_increment):
    reversed_string = list(reversed(string_to_increment)) # Reverse the string for easier work.
    for rindex, char in enumerate(reversed_string):
        if char == lastchar: # If we can't increment this char further, try the next ones.
            reversed_string[rindex] = firstchar # Set the current char back to the first one.
            reversed_string[rindex + 1] = increment_char(reversed_string[rindex + 1]) # Increment the next one along.
        else:
             # We only want to increment ONE char, unless we need to "carry".
            reversed_string[rindex] = increment_char(reversed_string[rindex])
            break
    return ''.join(list(reversed(reversed_string)))

def increment_string(to_increment):
    reversed_string = list(to_increment) # Reverse the string for easier work.
    for rindex, char in enumerate(reversed_string):
        if char == lastchar: # If we can't increment this char further, try the next ones.
            reversed_string[rindex] = firstchar # Set the current char back to the first one.
            reversed_string[rindex + 1] = increment_char(reversed_string[rindex + 1]) # Increment the next one along.
        else:
             # We only want to increment ONE char, unless we need to "carry".
            reversed_string[rindex] = increment_char(reversed_string[rindex])
            break
    return ''.join(list(reversed_string))

def string_generator():
    length = 0
    while 1:
        length += 1
        string = chars[0] * length
        while True:
            try:
                string = increment_string(string)
            except IndexError: # Incrementing has gone out of the char array, move onto next length
                break
            yield string
