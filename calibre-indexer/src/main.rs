use std::fs;
use anyhow::{Result, Context};
use std::path::PathBuf;
use rusqlite::{params, Connection, OptionalExtension};
use std::fs::File;
use xml::reader::{EventReader, XmlEvent, ParserConfig};
use std::io::BufReader;
use epub::doc::EpubDoc;
use std::time::SystemTime;

#[derive(Debug, Clone)]
struct BookMeta {
    title: String,
    author: String,
    description: String
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum XMLReadState {
    None,
    ReadingTitle,
    ReadingAuthor,
    ReadingDescription
}

// Extract text from an XHTML page in an ebook
// Ignores <script>, <style>, etc
// Also extracts chapter titles via assuming that any <hN> is part of a chapter title
fn extract_text<R: std::io::Read>(r: R) -> Result<(String, String)> {
    let mut text = String::new();
    let conf = ParserConfig::new()
        .ignore_comments(true)
        .cdata_to_characters(true)
        .add_entity("nbsp", "\u{A0}");

    let mut ignoring = false;
    let mut newline_appended_last = false;
    let mut in_header = None;
    let mut chapter = String::new();
    for e in EventReader::new_with_config(r, conf) {
        match e? {
            XmlEvent::StartElement { name, .. } => {
                match name.local_name.as_str() {
                    "style" | "script" | "nav" | "iframe" | "svg" => { ignoring = true },
                    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => { ignoring = false; in_header = Some(name.local_name) }
                    _ => { ignoring = false }
                }
            },
            XmlEvent::Characters(new) => {
                if !ignoring {
                    text += &new;
                    if in_header.is_some() && new != "§" && new != "*" {
                        chapter += &new;
                    }
                    newline_appended_last = false;
                }
            },
            XmlEvent::EndElement { name, .. } => {
                if let Some(ref h) = in_header {
                    if h == &name.local_name {
                        chapter += "\n";
                        in_header = None;
                    }
                }
                ignoring = false;
                match name.local_name.as_str() {
                    "span" | "sub" | "sup" | "small" | "i" | "b" | "em" | "strike" | "strong" | "a" | "link" | "head" => {}
                    x => {
                        if !newline_appended_last {
                            text += "\n";
                            newline_appended_last = true;
                            if in_header.is_some() && x == "br" {
                                chapter += "\n";
                            }
                        }
                    }
                }
            }
            _ => {}
        }
    }
    Ok((text, chapter))
}

fn read_opf(path: PathBuf) -> Result<BookMeta> {
    let file = File::open(path)?;
    let file = BufReader::new(file);
    let conf = ParserConfig::new()
        .ignore_comments(true)
        .cdata_to_characters(true);
    
    let mut meta = BookMeta {
        title: "".to_string(),
        author: "".to_string(),
        description: "".to_string()
    };
    let mut buf = String::new();
    let mut state = XMLReadState::None;
    for e in EventReader::new_with_config(file, conf) {
        match e? {
            XmlEvent::StartElement { name, .. } => {
                match name.local_name.as_str() {
                    "title" => { state = XMLReadState::ReadingTitle },
                    "creator" => { state = XMLReadState::ReadingAuthor },
                    "description" => { state = XMLReadState::ReadingDescription },
                    _ => {}
                }
            },
            XmlEvent::Characters(s) => {
                if state != XMLReadState::None {
                    buf += &s;
                }
            },
            XmlEvent::EndElement { .. } => {
                match state {
                    XMLReadState::ReadingTitle => { meta.title = buf.clone() },
                    XMLReadState::ReadingDescription => { meta.description = buf.clone() },
                    XMLReadState::ReadingAuthor => { meta.author = buf.clone() },
                    XMLReadState::None => {}
                }
                state = XMLReadState::None;
                buf.clear();
            }
            _ => {}
        }
    }
    Ok(meta)
}

fn path_append(p: &PathBuf, c: &str) -> PathBuf {
    let mut o = p.clone();
    o.push(c);
    o
}

fn run(db: &mut Connection, book_dir: PathBuf) -> Result<()> {
    let meta = read_opf(path_append(&book_dir, "metadata.opf")).with_context(|| format!("OPF metadata parsing for {:?}", book_dir))?;

    let dirent = book_dir.read_dir()?.collect::<std::io::Result<Vec<fs::DirEntry>>>()?.into_iter().filter(|ent| ent.file_name().to_str().unwrap().ends_with(".epub")).next();
    if let Some(dirent) = dirent {
        let epub_path = dirent.path();
        let path_str = epub_path.to_str().unwrap().to_string();
        let row: Option<i64> = db.query_row("SELECT last_modified FROM files WHERE path = ?", params![path_str], |row| row.get(0)).optional()?;

        let timestamp = epub_path.metadata()?.modified()?;
        let timestamp = timestamp.duration_since(SystemTime::UNIX_EPOCH)?.as_secs() as i64;
        match row {
            Some(orig_last_modified) if orig_last_modified == timestamp => {
                println!("Already have {} - {}", meta.title, meta.author);
                return Ok(())
            }
            _ => {}
        }

        println!("Processing {} - {}", meta.title, meta.author);
        let tx = db.transaction()?;

        tx.execute("INSERT OR REPLACE INTO files (path, last_modified) VALUES (?, ?)", params![path_str, timestamp])?;
        let fid = tx.last_insert_rowid();
        tx.execute("DELETE FROM data WHERE file = ?", params![fid])?;

        let mut doc = EpubDoc::new(epub_path).with_context(|| format!("reading {:?}", book_dir))?;
        let spine = doc.spine.clone();
        for resource in spine {
            let content = doc.get_resource(&resource).with_context(|| format!("reading {:?} in {:?}", &resource, book_dir))?;
            let (mut content, chapter) = extract_text(content.as_slice()).with_context(|| format!("parsing {:?} in {:?}", &resource, book_dir))?;
            let chapter = chapter.trim();
            // in place trim of newlines - avoid allocating new string
            while content.ends_with("\n") {
                content.truncate(content.len() - 1);
            }
            if content != "" {
                tx.execute("INSERT INTO data VALUES (?, ?, ?, ?, ?)", params![meta.author, meta.title, chapter, content, fid])?;
            }
        }

        tx.commit()?;
        println!("Done {} - {}", meta.title, meta.author);
    } else {
        println!("No EPUB for {} - {}", meta.title, meta.author);
    }
    Ok(())
}

// TODO: Make this work concurrently again, by finding a more performant backend
fn main() -> Result<()> {
    let argv: Vec<String> = std::env::args().collect();

    let mut db = Connection::open(argv[1].clone())?;
    db.execute_batch("
    BEGIN;
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY,
        path BLOB NOT NULL UNIQUE,
        last_modified INTEGER NOT NULL
    );
    CREATE VIRTUAL TABLE IF NOT EXISTS data USING fts5 (
        author,
        book,
        chapter,
        content,
        file UNINDEXED
    );
    COMMIT;
    PRAGMA journal_mode = WAL;
    ").with_context(|| "database initialization")?;

    for author_dir in fs::read_dir(argv[2].clone()).with_context(|| "reading library location")? {
        let author_dir = author_dir?;
        if author_dir.file_type()?.is_dir() {
            for book_dir in fs::read_dir(author_dir.path())? {
                let path = book_dir?.path();
                run(&mut db, path)?;
            }
        }
    }

    Ok(())
}
