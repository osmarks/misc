use rusqlite::types::ToSql;
use rusqlite::{params, Connection};
use std::io::BufRead;
use lazy_static::lazy_static;
use regex::Regex;
use std::io::Seek;

lazy_static! {
    static ref INDEX_LINE_RE: Regex = Regex::new(r"^(\d+):(\d+):(.+)$").unwrap();
}

fn decompress_file(filename: &str) -> std::io::Result<std::io::BufReader<bzip2::bufread::BzDecoder<std::io::BufReader<std::fs::File>>>> {
    let file = std::fs::File::open(filename)?;
    let file = std::io::BufReader::new(file);
    let file = bzip2::bufread::BzDecoder::new(file);
    Ok(std::io::BufReader::new(file))
}

fn import(filename: &str, conn: &mut Connection) -> Result<(), Box<std::error::Error>> {
    let file = decompress_file(filename)?;

    let tx = conn.transaction()?;
    tx.execute("DELETE FROM page_locations", params![])?;

    for line in file.lines() {
        let line = &(line)?;
        let caps = INDEX_LINE_RE.captures(line).unwrap();
        let title = String::from(caps.get(3).unwrap().as_str());
        let start = caps.get(1).unwrap().as_str().parse::<i64>()?;

        tx.execute("INSERT INTO page_locations (title, start) VALUES (?1, ?2)", params![title, start])?;
    }

    tx.commit()?;

    conn.execute("VACUUM", params![])?;

    Ok(())
}

fn view(page: &str, conn: &mut Connection) -> Result<(), Box<std::error::Error>> {
    let result: Option<rusqlite::Result<i64>> = conn.prepare("SELECT start FROM page_locations WHERE title = ?1")?.query_map(params![page], |row| {
        Ok(row.get(0)?)
    })?.nth(0);

    match result {
        Some(start) => {
            let start = start?;
            let file = std::fs::File::open("data.bz2")?;
            let mut file = std::io::BufReader::new(file);
            file.seek(std::io::SeekFrom::Start(start as u64))?;
            let file = bzip2::bufread::BzDecoder::new(file);
            let file = std::io::BufReader::new(file);

            for result in parse_mediawiki_dump::parse(file) {
                match result {
                    Err(error) => {
                        eprintln!("Parse Error: {}", error);
                        break;
                    },
                    Ok(page) => if page.namespace == 0 && match &page.format {
                        None => false,
                        Some(format) => format == "text/x-wiki"
                    } && match &page.model {
                        None => false,
                        Some(model) => model == "wikitext"
                    } {
                        println!(
                            "The page {title:?} is an ordinary article with byte length {length}.",
                            title = page.title,
                            length = page.text.len()
                        );
                    } else {
                        println!("The page {:?} has something special to it.", page.title);
                    }
                }
            }
        },
        None => {
            eprintln!("{} not found", page);
        }
    };

    Ok(())
}

fn main() -> Result<(), Box<std::error::Error>> {
    let mut conn = Connection::open("database.sqlite")?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS page_locations (
            title TEXT PRIMARY KEY,
            start INTEGER
        )",
        params![],
    )?;

    let args: Vec<String> = std::env::args().collect();

    match args[1].as_str() {
        "import" => import("index.bz2", &mut conn)?,
        "view" => view(&args[2], &mut conn)?,
        _ => eprintln!("Invalid argument {}", args[1])
    };

    Ok(())
}
