import os, sys, string

count = 0
words = 0
characters = 0
for dirpath, dirnames, filenames in os.walk(sys.argv[1]):
    for filename in filenames:
        with open(os.path.join(dirpath, filename)) as f:
            content = f.read()
            characters += len([c for c in content if c in string.ascii_letters])
            words += len([thing for thing in content.split() if thing.strip()])
            count += 1

print(words / count, characters / count)