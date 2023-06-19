import os
import os.path

for person in os.listdir("people"):
    for submission in os.listdir(os.path.join("people", person)):
        print(person, submission)