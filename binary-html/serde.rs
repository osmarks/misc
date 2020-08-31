use std::collections::HashMap;
use serde::{Serialize, Deserialize, Serializer, ser::SerializeTuple, de, de::Visitor, de::SeqAccess};
use serde_repr::{Serialize_repr, Deserialize_repr};

#[derive(Serialize_repr, Deserialize_repr, PartialEq, Eq, Debug, Hash)]
#[repr(u8)]
enum CommonTag {
    Div,
    Span,
    P,
    H1,
}
#[derive(Serialize_repr, Deserialize_repr, PartialEq, Eq, Debug, Hash)]
#[repr(u8)]
enum CommonAttr {
    Class,
    Id,
    Href,
}
#[derive(Serialize, Deserialize, PartialEq, Eq, Debug, Hash)]
enum Attribute { Common(CommonAttr), Other(String) }
#[derive(Serialize, Deserialize, PartialEq, Eq, Debug, Hash)]
enum Tag { Common(CommonTag), Other(String) }
#[derive(Serialize, Deserialize, PartialEq, Eq, Debug)]
enum Node {
    Text(String),
    Element { tag: Tag, attributes: HashMap<Attribute, String>, children: Vec<Node> },
    ChildlessElement { tag: Tag, attributes: HashMap<Attribute, String> },
    AttributelessElement { tag: Tag, children: Vec<Node> },
    ContentlessElement(Tag)
}

use html5ever::driver::ParseOpts;
use html5ever::tendril::TendrilSink;
use html5ever::tree_builder::TreeBuilderOpts;
use html5ever::{parse_document, serialize};

fn main() {
    let opts = ParseOpts {
        tree_builder: TreeBuilderOpts {
            drop_doctype: true,
            ..Default::default()
        },
        ..Default::default()
    };
    println!("Hello, world!");
}
