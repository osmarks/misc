import sqlite3
import re

conn = sqlite3.connect("./data.sqlite3")
#conn.row_factory = sqlite3.Row
csr = conn.execute("""SELECT author, book, chapter, snippet(data, -1, '[!]', '[!]', ' ... ', 32)
FROM data WHERE data MATCH ? AND rank MATCH 'bm25(10.0, 10.0, 5.0, 1.0)' ORDER BY rank LIMIT 100""", (input("query:"),))
while x := csr.fetchone():
    author, book, chapter, snippet = x
    snippet = re.sub("\n+", "\n", snippet)
    chapter = chapter.replace("\n", " ")
    print(f"[{author}: {book}] {'<' + chapter + '> ' if chapter != '' else ''}{snippet}")