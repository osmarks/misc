use std::collections::HashMap;
use std::io;
use rmp::{encode, decode, decode::NumValueReadError};
use std::convert::TryFrom;
use num_enum::{IntoPrimitive, TryFromPrimitive};
use thiserror::Error;

#[derive(IntoPrimitive, TryFromPrimitive)]
#[derive(PartialEq, Eq, Debug, Hash, Clone, Copy)]
#[repr(u8)]
enum CommonTag {
    Div = 0,
    Span = 1,
    P = 2,
    H1 = 3,
}
#[derive(IntoPrimitive, TryFromPrimitive)]
#[derive(PartialEq, Eq, Debug, Hash, Clone, Copy)]
#[repr(u8)]
enum CommonAttr {
    Class = 0,
    Id = 1,
    Href = 2,
}
#[derive(PartialEq, Eq, Debug, Hash, Clone)]
enum Attribute { Common(CommonAttr), Other(String) }
#[derive(PartialEq, Eq, Debug, Hash, Clone)]
enum Tag { Common(CommonTag), Other(String) }
#[derive(PartialEq, Eq, Debug, Clone)]
enum Node {
    Text(String),
    Element { tag: Tag, attributes: HashMap<Attribute, String>, children: Vec<Node> },
    SimpleElement { tag: Tag, children: Vec<Node> },
    EmptyElement(Tag)
}

fn encode_tag<W: io::Write>(wr: &mut W, tag: &Tag) -> Result<(), encode::ValueWriteError> {
    match tag {
        Tag::Common(t) => encode::write_u8(wr, (*t).into()),
        Tag::Other(t) => encode::write_str(wr, t)
    }
}
fn encode_attr<W: io::Write>(wr: &mut W, attr: &Attribute) -> Result<(), encode::ValueWriteError> {
    match attr {
        Attribute::Common(a) => encode::write_u8(wr, (*a).into()),
        Attribute::Other(a) => encode::write_str(wr, a)
    }
}

fn encode_node<W: io::Write>(wr: &mut W, node: &Node) -> Result<(), encode::ValueWriteError> {
    match node {
        Node::Text(s) => encode::write_str(wr, s),
        Node::Element { tag, attributes, children } => {
            encode::write_array_len(wr, 3)?;
            encode_tag(wr, tag)?;
            encode::write_map_len(wr, attributes.len() as u32)?;
            for (k, v) in attributes {
                encode_attr(wr, k)?;
                encode::write_str(wr, v)?;
            }
            encode::write_array_len(wr, children.len() as u32)?;
            for child in children {
                encode_node(wr, child)?;
            }
            Ok(())
        },
        Node::SimpleElement { tag, children } => {
            encode::write_array_len(wr, 2)?;
            encode_tag(wr, tag)?;
            encode::write_array_len(wr, children.len() as u32)?;
            for child in children {
                encode_node(wr, child)?;
            }
            Ok(())
        },
        Node::EmptyElement(tag) =>{
            encode::write_array_len(wr, 1)?;
            encode_tag(wr, tag)?;
            Ok(())
        }
    }
}

#[derive(Error, Debug)]
enum DecodeError {
    #[error("tag ID {0} not known")]
    InvalidTagID(u8),
    #[error("attribute ID {0} not known")]
    InvalidAttrID(u8),
    // TODO
    #[error("parse fail")]
    ParseError
}

fn decode_string<R: io::Read>(r: &mut R) -> Result<String, DecodeError> {
    let len = decode::read_str_len(r).map_err(|_| DecodeError::ParseError)?;
    let mut buf = Vec::with_capacity(len as usize);
    println!("{:?}", buf);
    r.read(&mut buf).map_err(|_| DecodeError::ParseError)?;
    Ok(String::from_utf8(buf).map_err(|_| DecodeError::ParseError)?)
}

fn decode_tag<R: io::Read>(r: &mut R) -> Result<Tag, DecodeError> {
    match decode::read_int(r) {
        Ok(x) => {
            let x: u8 = x; // satisfy type inference
            Ok(Tag::Common(CommonTag::try_from(x).map_err(|x: num_enum::TryFromPrimitiveError<CommonTag>| DecodeError::InvalidTagID(x.number))?))
        },
        Err(e) => match e {
            NumValueReadError::TypeMismatch(_) => Ok(Tag::Other(decode_string(r)?)),
            _ => Err(DecodeError::ParseError)
        }
    }
}

fn decode_attr<R: io::Read>(r: &mut R) -> Result<Attribute, DecodeError> {
    match decode::read_int(r) {
        Ok(x) => {
            let x: u8 = x; // satisfy type inference
            Ok(Attribute::Common(CommonAttr::try_from(x)
                .map_err(|x: num_enum::TryFromPrimitiveError<CommonAttr>| DecodeError::InvalidAttrID(x.number))?))
        },
        Err(e) => match e {
            NumValueReadError::TypeMismatch(_) => Ok(Attribute::Other(decode_string(r)?)),
            _ => Err(DecodeError::ParseError)
        }
    }
}

fn decode_nodes<R: io::Read>(r: &mut R) -> Result<Vec<Node>, DecodeError> {
    let len = decode::read_array_len(r).map_err(|_| DecodeError::ParseError)?;
    let mut out = Vec::with_capacity(len as usize);
    for _ in 0..len {
        out.push(decode_node(r)?);
    }
    Ok(out)
}

fn decode_node<R: io::Read>(r: &mut R) -> Result<Node, DecodeError> {
    match decode::read_array_len(r) {
        Ok(len) => {
            if len > 3 || len < 1 {
                return Err(DecodeError::ParseError)
            }
            let tag = decode_tag(r)?;
            if len > 1 {
                if len > 2 {
                    let maplen = decode::read_map_len(r).map_err(|_| DecodeError::ParseError)?;
                    let mut attrs = HashMap::with_capacity(maplen as usize);
                    for _ in 0..maplen {
                        let key = decode_attr(r)?;
                        let val = decode_string(r)?;
                        attrs.insert(key, val);
                    }
                    let children = decode_nodes(r)?;
                    Ok(Node::Element { tag, attributes: attrs, children })
                } else {
                    Ok(Node::SimpleElement { tag, children: decode_nodes(r)? })
                }
            } else {
                Ok(Node::EmptyElement(tag))
            }
        },
        Err(decode::ValueReadError::TypeMismatch(_)) => decode_string(r).map(Node::Text),
        Err(_) => Err(DecodeError::ParseError)
    }
}

fn main() {
    let mut out = Vec::new();
    let attrs1 = vec![
        (Attribute::Common(CommonAttr::Class), "test1".to_string()),
        (Attribute::Common(CommonAttr::Id), "idtest".to_string()),
        (Attribute::Other("test-attr".to_string()), "test attr content".to_string())
    ].into_iter().collect();
    let attrs2 = vec![
        (Attribute::Common(CommonAttr::Href), "/test-href".to_string()),
        (Attribute::Other("test-attr-2".to_string()), "test attr 2 content".to_string()),
        (Attribute::Common(CommonAttr::Id), "id2".to_string()),
    ].into_iter().collect();
    let node2 = Node::Element { tag: Tag::Common(CommonTag::Div), attributes: attrs2, 
        children: vec![Node::Text(String::from("hello, 2"))] };
    let node1 = Node::Element { tag: Tag::Common(CommonTag::Div), attributes: attrs1, 
        children: vec![Node::Text(String::from("hello, world")), node2] };
    encode_node(&mut out, &node1).unwrap();
    println!("{:?} {:?}", out, node1);
    let res = decode_node(&mut std::io::Cursor::new(out)).unwrap();
    assert_eq!(res, node1);
}
