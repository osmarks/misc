from requests_futures.sessions import FuturesSession
import concurrent.futures as futures
import random
try:
    import cPickle as pickle
except ImportError:
    import pickle

try:
    words_to_synonyms = pickle.load(open(".wtscache"))
    synonyms_to_words = pickle.load(open(".stwcache"))
except:
    words_to_synonyms = {}
    synonyms_to_words = {}

def add_to_key(d, k, v):
    d[k] = d.get(k, set()).union(set(v))

def add_synonyms(syns, word):
    for syn in syns:
        add_to_key(synonyms_to_words, syn, [word])
    add_to_key(words_to_synonyms, word, syns)

def concat(list_of_lists):
    return sum(list_of_lists, [])

def add_words(words):
    s = FuturesSession(max_workers=100)
    future_to_word = {s.get("https://api.datamuse.com/words", params={"ml": word}): word for word in words}
    future_to_word.update({s.get("https://api.datamuse.com/words", params={"ml": word, "v": "enwiki"}): word for word in words})
    for future in futures.as_completed(future_to_word):
        word = future_to_word[future]
        try:
            data = future.result().json()
        except Exception as exc:
            print(f"{exc} fetching {word}")
        else:
            add_synonyms([w["word"] for w in data], word)

def getattr_hook(obj, key):
    results = list(synonyms_to_words.get(key, set()).union(words_to_synonyms.get(key, set())))
    if len(results) > 0:
        return obj.__getattribute__(random.choice(results))
    else:
        raise AttributeError(f"Attribute {key} not found.")

def wrap(obj):
    add_words(dir(obj))

    obj.__getattr__ = lambda key: getattr_hook(obj, key)

wrap(__builtins__)
print(words_to_synonyms["Exception"])

raise __builtins__.quibble("abcd")