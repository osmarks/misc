#!/bin/env python3
import re, sys, allstrings, multiprocessing
from setproctitle import setproctitle # https://github.com/dvarrazzo/py-setproctitle

string = sys.argv[1]

def gen_strings(out_queue):
    setproctitle("AutoRegexer StringGen")
    for string in allstrings.string_generator():
        out_queue.put(string)

def test_strings(regex_queue, substring_queue, out_queue, search_in):
    setproctitle("AutoRegexer Tester")

    while 1:
        try: # Regexes are errory things and we shove in random ones, so ignore errors.
            regex_raw = regex_queue.get()
            substring = substring_queue.get()

            regex = re.compile(regex_raw)
            result = re.sub(regex, substring, string)

            out_queue.put({"result": result, "regex": regex_raw, "substring": substring}) # Package the values used and send them off.
        except:
            pass

def print_strings(in_queue, ignore):
    i = 0
    setproctitle("AutoRegexer IO")

    while 1:
        i += 1

        attempt = in_queue.get()

        if attempt["result"] == ignore: # Ignore regexes deemed boring..
            continue

        print(str(i) + "th attempt: replacing " + attempt["substring"] +
        " with " + attempt["regex"] + " results in " + attempt["result"] + ".")

if __name__ == "__main__":
    print_queue = multiprocessing.Queue() # Create the IO queue
    regex_queue = multiprocessing.Queue() # Create queue to distribute generated strings.
    substring_queue = multiprocessing.Queue()

    print_process = multiprocessing.Process(target=print_strings, args=(print_queue, string), name="AutoRegexer IO") # Spawn a process to handle our IO.
    regex_gen_process = multiprocessing.Process(target=gen_strings, args=(regex_queue,), name="AutoRegexer RegexGen") # Create process to generate our regexes.
    substring_gen_process = multiprocessing.Process(target=gen_strings, args=(substring_queue,), name="AutoRegexer SubstringGen") # Make a process to generate the replaced substrings.
    print_process.start()
    regex_gen_process.start()
    substring_gen_process.start()

    #with multiprocessing.Pool(processes=7) as pool:
    for local_process_id in range(7):
        #while True:
        proc_name = "AutoRegexer " + str(local_process_id)
        proc = multiprocessing.Process(target=test_strings, args=(regex_queue, substring_queue, print_queue, string), name=proc_name)
        proc.start()

        #string_gen_process = multiprocessing.Process(target=gen_strings, args=(string_queue,), name="AutoRegexer StringGen")
        #string_gen_process.start()

    setproctitle("AutoRegexer Master")

# Obsolete old version.
'''
for iterations, regex_and_sub in enumerate(allstrings.string_generator()):
    result = ""
    try:
        half_point = len(regex_and_sub) // 2
        regex_raw = regex_and_sub[:half_point]
        substring = regex_and_sub[half_point:]

        regex = re.compile(regex_raw)
        result = re.sub(regex_raw, substring, string)
    except:
        pass
    finally:
        if result != string and result != "":
            print("Replacing `" + regex_raw + "` with `" + substring + "` produces `" + result + "`.")
'''
