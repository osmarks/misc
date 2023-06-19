pub fn entry(s: &str) -> i32 {
    let digit = |c: u8| (c as i32) - 48;
    let mut acc = 0;
    let mut pos = 0;
    let b = s.as_bytes();
    loop {
        match b[pos] {
            b'+' => {
                acc += {
                    pos += 1;
                    let mut acc = 0;
                    while (pos + 1) < b.len() && (b[pos + 1] == b'/' || b[pos + 1] == b'*') {
                        println!("DIV or MUL {} {} {}", b[pos], b[pos + 1], b[pos + 2]);
                        if acc == 0 {
                            acc = digit(b[pos])
                        }
                        if b[pos + 1] == b'/' {
                            acc /= digit(b[pos + 2])
                        } else {
                            acc *= digit(b[pos + 2])
                        }
                        pos += 2;
                    }
                    if acc == 0 {
                        digit(b[pos])
                    } else {
                        acc
                    }
                };
                pos += 1;
            },
            b'-' => {
                acc -= {
                    pos += 1;
                    let mut acc = -1;
                    while (pos + 1) < b.len() && (b[pos + 1] == b'/' || b[pos + 1] == b'*') {
                        println!("DIV or MUL {} {} {}", b[pos], b[pos + 1], b[pos + 2]);
                        if acc == -1 {
                            acc = digit(b[pos])
                        }
                        if b[pos + 1] == b'/' {
                            acc /= digit(b[pos + 2])
                        } else {
                            acc *= digit(b[pos + 2])
                        }
                        pos += 2;
                    }
                    if acc == -1 {
                        digit(b[pos])
                    } else {
                        acc
                    }
                };
                pos += 1;
            },
            x => {
                acc += {
                    let mut acc = 0;
                    while (pos + 1) < b.len() && (b[pos + 1] == b'/' || b[pos + 1] == b'*') {
                        println!("DIV or MUL {} {} {}", b[pos], b[pos + 1], b[pos + 2]);
                        if acc == 0 {
                            acc = digit(b[pos])
                        }
                        if b[pos + 1] == b'/' {
                            acc /= digit(b[pos + 2])
                        } else {
                            acc *= digit(b[pos + 2])
                        }
                        pos += 2;
                    }
                    if acc == 0 {
                        digit(b[pos])
                    } else {
                        acc
                    }
                };
                pos += 1
            }
        }
        if pos >= b.len() {
            break
        }
    }
    acc
}