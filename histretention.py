import sqlite3, sys

longterm = sqlite3.connect(sys.argv[1])
longterm.executescript(f"""
CREATE TABLE IF NOT EXISTS places (
    guid TEXT PRIMARY KEY,
    url TEXT,
    title TEXT,
    visit_count INTEGER DEFAULT 0,
    last_visit_date INTEGER,
    description TEXT,
    preview_image_url TEXT
);
CREATE TABLE IF NOT EXISTS bookmarks (
    guid TEXT PRIMARY KEY,
    bookmark TEXT NOT NULL REFERENCES places(guid),
    title TEXT,
    dateAdded INTEGER,
    lastModified INTEGER
);
CREATE TABLE IF NOT EXISTS historyvisits (
    id TEXT PRIMARY KEY,
    place TEXT NOT NULL REFERENCES places(guid),
    date INTEGER NOT NULL,
    type INTEGER NOT NULL
);
""")
longterm.execute("ATTACH DATABASE '/tmp/places.sqlite' AS transient;")
longterm.execute("""INSERT INTO places SELECT guid, url, title, visit_count, last_visit_date, description, preview_image_url FROM moz_places WHERE true
ON CONFLICT DO UPDATE SET visit_count = excluded.visit_count, last_visit_date = excluded.last_visit_date, title = excluded.title, description = excluded.description, preview_image_url = excluded.preview_image_url;""")
longterm.execute("""INSERT INTO bookmarks SELECT moz_bookmarks.guid, moz_places.guid, moz_bookmarks.title, dateAdded, lastModified FROM moz_bookmarks JOIN moz_places ON moz_places.id = moz_bookmarks.fk WHERE true
ON CONFLICT DO UPDATE SET lastModified = excluded.lastModified, title = excluded.title;""")
# TODO: possibly wrong with new profile, might need to increment historyvisits or something
longterm.execute("INSERT INTO historyvisits SELECT (moz_historyvisits.id || '/' || visit_date), moz_places.guid, visit_date, visit_type FROM moz_historyvisits JOIN moz_places ON moz_places.id = moz_historyvisits.place_id ON CONFLICT DO NOTHING;")

longterm.commit()
