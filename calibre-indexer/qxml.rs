// Earlier version attempting to use quick-xml
// Dropped because SQLite appears to be what most of the time is spent in anyway, and because quick-xml had some issues wrt. escaping

use std::fs;
use anyhow::{Result, Context};
use crossbeam::channel::{bounded};
use crossbeam::thread;
use std::path::PathBuf;
use rusqlite::{params, Connection};
use std::fs::File;
use xml::reader::{EventReader, XmlEvent, ParserConfig};
use quick_xml::{Reader, events::Event};
use std::io::BufReader;
use epub::doc::EpubDoc;
use lazy_static::lazy_static;
use std::collections::HashMap;

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

lazy_static! {
    static ref ESCAPES: HashMap<Vec<u8>, Vec<u8>> = {
        let mut m = HashMap::new();
        m.insert(b"nbsp".to_vec(), b"\xc2\xa0".to_vec());
        m.insert(b"copy".to_vec(), b"\xc2\xa9".to_vec());
        m.insert(b"eacute".to_vec(), b"\xc3\x89".to_vec());
        m.insert(b"shy".to_vec(), b"\xc2\xad".to_vec());
        m.insert(b"iuml".to_vec(), b"\xc3\x8f".to_vec());
        m
    };
}

// Extract text from an XHTML page in an ebook
// Ignores <script>, <style>, etc
// Also extracts chapter titles via assuming that any <hN> is part of a chapter title
fn extract_text(r: Vec<u8>) -> Result<(String, String)> {
    //println!("{:?}", String::from_utf8_lossy(r.as_slice()));
    let mut text = String::new();
    let conf = ParserConfig::new()
        .ignore_comments(true)
        .cdata_to_characters(true);

    let mut ignoring = false;
    let mut newline_appended_last = false;
    let mut in_header = None;
    let mut chapter = String::new();
    let mut reader = Reader::from_reader(r.as_slice());
    let mut buf = Vec::new();
    reader.trim_text_end(true);
    loop {
        match reader.read_event(&mut buf)? {
            Event::Start(ref e) => {
                match e.name() {
                    b"style" | b"script" | b"nav" | b"iframe" | b"svg" => { ignoring = true },
                    b"h1" | b"h2" | b"h3" | b"h4" | b"h5" | b"h6" => { ignoring = false; in_header = Some(e.name().to_vec()) }
                    _ => { ignoring = false }
                }
            },
            Event::Text(new) => {
                if !ignoring {
                    text += &new.unescape_and_decode_with_custom_entities(&reader, &*ESCAPES)?;
                    if in_header.is_some() && &*new != b"\xA7" && &*new != b"*" {
                        chapter += &new.unescape_and_decode_with_custom_entities(&reader, &*ESCAPES)?;
                    }
                    newline_appended_last = false;
                }
            },
            Event::Eof => break,
            Event::End(ref e) => {
                if let Some(ref h) = in_header {
                    if h == &e.name() {
                        chapter += "\n";
                        in_header = None;
                    }
                }
                ignoring = false;
                match e.name() {
                    b"span" | b"sub" | b"sup" | b"small" | b"i" | b"b" | b"em" | b"strike" | b"strong" | b"a" | b"link" | b"head" => {}
                    x => {
                        if !newline_appended_last {
                            text += "\n";
                            newline_appended_last = true;
                            if in_header.is_some() && x == b"br" {
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

fn main() -> Result<()> {
    let (tx, rx) = bounded::<PathBuf>(16);
    let res: Result<()> = thread::scope(|sc| {
        let db = Connection::open("./data.sqlite3")?;
        db.execute_batch("
        BEGIN;
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY,
            path BLOB NOT NULL,
            last_modified INTEGER NOT NULL
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS data USING fts5 (
            author,
            book,
            chapter,
            content,
            file
        );
        COMMIT;
        ").with_context(|| "database initialization")?;
    
        let mut threads: Vec<thread::ScopedJoinHandle<()>> = vec![];
        for i in 0..num_cpus::get() {
            let rx = rx.clone();
            let go = move || -> Result<()> {
                for book_dir in rx.iter() {
                    println!("{} begin handling {:?}", i, book_dir);
                    let meta = read_opf(path_append(&book_dir, "metadata.opf")).with_context(|| format!("OPF metadata parsing for {:?}", book_dir))?;
                    let epub_path = path_append(&book_dir, &format!("{} - {}.epub", meta.title, meta.author));
                    if epub_path.exists() {
                        let mut doc = EpubDoc::new(epub_path).with_context(|| format!("reading {:?}", book_dir))?;
                        let spine = doc.spine.clone();
                        for resource in spine {
                            let content = doc.get_resource(&resource).with_context(|| format!("reading {:?} in {:?}", &resource, book_dir))?;
                            let (mut content, chapter) = extract_text(content).with_context(|| format!("parsing {:?} in {:?}", &resource, book_dir))?;
                            let chapter = chapter.trim();
                            // in place trim of newlines - avoid allocating new string
                            while content.ends_with("\n") {
                                content.truncate(content.len() - 1);
                            }
                            if content != "" {
                                //println!("{}: {}: {}", meta.title, resource, chapter);
                            }
                        }
                        //println!("{} - {}", meta.author, meta.title);
                    }
                    println!("{} end handling {:?}", i, book_dir);
                }
                Ok(())
            };
            threads.push(sc.spawn(move |_| { go().unwrap() }));
        }
    
        for author_dir in fs::read_dir("/data/calibre").with_context(|| "reading library location")? {
            let author_dir = author_dir?;
            if author_dir.file_type()?.is_dir() {
                for book_dir in fs::read_dir(author_dir.path())? {
                    let path = book_dir?.path();
                    //println!("{:?}", path);
                    tx.send(path)?;
                }
            }
        }
        std::mem::drop(tx);
    
        for thread in threads {
            thread.join().unwrap();
        }
        Ok(())
    }).unwrap();
    res?;
    Ok(())
}
