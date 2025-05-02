use anyhow::{Context, Result};
use compact_str::CompactString;
use std::{fs, io::{BufRead, BufReader, BufWriter, Write}, path::PathBuf, sync::{Arc, Mutex}};
use sonic_rs::JsonValueTrait;
use foldhash::{HashMap, HashMapExt};
use rayon::prelude::*;

#[derive(Debug)]
struct ScannerState {
    may_start_number: bool,
    current_number_start: Option<usize>,
    number_has_digits: bool,
    was_hyphen: bool,
    was_alpha: bool,
    multiple_hyphens: bool
}

fn extract_numbers<'a, F: FnMut(&'a str)>(s: &'a str, mut callback: F) {
    let mut state = ScannerState {
        may_start_number: true,
        current_number_start: None,
        number_has_digits: false,
        was_hyphen: false,
        was_alpha: false,
        multiple_hyphens: false
    };

    let mut commit_segment = |segment: &'a str| {
        let dot_count = segment.chars().filter(|x| *x == '.').count();
        if dot_count > 1 { return; }
        let buffer = segment.strip_suffix(".").unwrap_or(segment);
        if buffer.len() > 0 {
            callback(buffer);
        }
    };

    let mut commit = |pos, state: &mut ScannerState| {
        if let Some(start) = state.current_number_start {
            if state.number_has_digits {
                let chunk = &s[start..pos];
                let mut interpret_as_contiguous = true;
                // postprocessing
                for (i, seg) in chunk.split(",").enumerate() {
                    if i > 0 && seg.len() != 3 && seg.len() > 0 {
                        interpret_as_contiguous = false;
                    }
                }
                if interpret_as_contiguous {
                    commit_segment(chunk.strip_suffix(",").unwrap_or(chunk));
                } else {
                    for seg in chunk.split(",") {
                        commit_segment(seg);
                    }
                }
            }
        }
        state.current_number_start = None;
        state.may_start_number = true;
        state.number_has_digits = false;
    };

    for (i, c) in s.char_indices() {
        //println!("{:?} {:?}", c, state);
        if c == '-' {
            state.multiple_hyphens = state.was_hyphen;
        } else {
            state.multiple_hyphens = false;
        }
        if state.may_start_number {
            if c.is_ascii_digit() {
                state.current_number_start = Some(i);
                state.number_has_digits = true;
                state.may_start_number = false;
            }
            if c == '-' && !state.was_hyphen && !state.was_alpha {
                state.current_number_start = Some(i);
                state.number_has_digits = false;
                state.may_start_number = false;
                state.was_hyphen = true;
            }
        }
        match c {
            c if c.is_ascii_digit() => {
                state.number_has_digits = true;
            },
            '%' => commit(i+1, &mut state),
            '-' => {
                if !state.was_hyphen || state.number_has_digits || state.multiple_hyphens { commit(i, &mut state); }
                state.was_hyphen = true;
            },
            '–' => commit(i, &mut state),
            ',' => (),
            '.' => (),
            _ => {
                commit(i, &mut state);
                if c.is_whitespace() { state.was_hyphen = false; }
            }
        }
        state.was_alpha = c.is_alphabetic();
    }

    commit(s.len(), &mut state);
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let root = PathBuf::from(args.get(1).context("root path required")?);
    let mut numbers: Arc<Mutex<HashMap<CompactString, u64>>> = Arc::new(Mutex::new(HashMap::new()));
    let mut paths = vec![];

    for target in root.read_dir()? {
        let target = target?;
        if target.file_name().to_str().context("non-UTF8 filepath (no)")?.ends_with(".jsonl.zst") {
            paths.push(target.path());
        }
    }

    paths.into_par_iter().try_for_each_with(numbers.clone(), |global_numbers, path| -> Result<()> {
        let mut numbers: HashMap<CompactString, u64> = HashMap::new();

        let file = BufReader::with_capacity(32*1024*1024, fs::File::open(path)?);
        let mut decoder = BufReader::new(zstd::Decoder::new(file)?);
        let mut input = String::with_capacity(8192);
        loop {
            if decoder.read_line(&mut input)? == 0 {
                break;
            }
            let text = sonic_rs::get_from_str(&input, &["text"])?;
            let text = text.as_str().context("invalid format")?;
            //println!("{:?}", text);
            extract_numbers(text, |num| {
                let key = num.replace(",", "");
                if key == "%" {
                    return;
                }
                let has_percent = key.ends_with("%");
                let has_minus = key.starts_with("-");
                let key = key.trim_start_matches("0").trim_end_matches("%").trim_start_matches("-");
                let mut key = if key.starts_with(".") || key.is_empty() {
                    let mut new_key = CompactString::new("0");
                    new_key.push_str(key);
                    new_key
                } else {
                    CompactString::from(key)
                };

                if let Some(decimal_point) = key.find('.') {
                    key.truncate(decimal_point + &key[decimal_point..key.len()].trim_end_matches("0").len());
                    if key.ends_with(".") {
                        key.truncate(key.len() - 1);
                    }
                    if key.len() == 0 {
                        key.push_str("0");
                    }
                }

                if has_minus {
                    key.insert(0, '-');
                }

                if has_percent {
                    key.push_str("%");
                }

                *numbers.entry(key).or_default() += 1;
            });
            input.clear();
        }

        {
            let mut global_numbers = global_numbers.lock().unwrap();
            for (key, count) in numbers {
                *global_numbers.entry(key).or_default() += count;
            }
        }

        Ok(())
    })?;

    let mut out_file = BufWriter::new(fs::File::create(args.get(2).context("output path required")?)?);

    write!(&mut out_file, "number,count\n")?;
    for (key, count) in std::mem::replace(Arc::get_mut(&mut numbers).unwrap(), Mutex::new(HashMap::new())).into_inner().unwrap() {
        write!(&mut out_file, "{},{}\n", key, count)?;
    }

    Ok(())
}

#[test]
fn test_regex() {
    let test_cases = &[
        ("106 bees approach 45675 nonbees", vec!["106", "45675"]),
        ("2, then fewer, then -5", vec!["2", "-5"]),
        ("1--3 is a weird thing to write", vec!["1", "3"]),
        ("version 4.6.0 of the software", vec![]),
        ("it has been shown that 841% of users, or up to 25, liked the new version", vec!["841%", "25"]),
        ("by then, 1,401,041 numbers had been found by 6,436 people and -44,036,110", vec!["1,401,041", "6,436", "-44,036,110"]),
        ("translate(0,0,0)", vec!["0", "0", "0"]),
        ("in this case, 10-30 means ten to thirty and 10–30 (en dash) also means that", vec!["10", "30", "10", "30"]),
        ("issued Dec. 21, 1999, and U.S. Pat. No. 5,777,999, entitled", vec!["21", "1999", "5,777,999"]),
        ("Forty days after Farkhunda, a 27-year-old Afghan woman falsely accused of burning a copy of the Quran, was publicly beaten and burnt to death on 1, March 19, 2015,", vec!["27", "1", "19", "2015"]),
        ("4.6 million integers, -0 negative zeroes, 1,2,3", vec!["4.6", "-0", "1", "2", "3"]),
        ("move -20px and consume $30 at once, then 11,22,33", vec!["-20", "30", "11", "22", "33"]),
        ("I used up a DC-8 doing my W-2 form", vec!["8", "2"]),
        ("[[@b11-kjim-2015-406],[@b20-kjim-2015-406]\\]", vec!["11", "2015", "406", "20", "2015", "406"]),
        ("--385.12 and ---411 and 0", vec!["385.12", "411", "0"])
    ];

    for (input, output) in test_cases {
        let mut matches: Vec<&str> = vec![];
        extract_numbers(input, |mat| matches.push(mat));
        assert_eq!(matches.as_slice(), output.as_slice());
    }
}
