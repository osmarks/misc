# binary-html

Contains a failed attempt at making a msgpack-based binary serialization format for HTML.
This would have a number of advantages, such as likely being much faster to parse, not having to deal with all the weird parsing irregularities textual HTML has to for backward compatibility reasons, and being more compact.
Unfortunately, this implementation doesn't actually work (quite possibly because I misunderstood how readers work), the code is kind of terrible anyway, and I cannot be bothered to fix it.

## Format

A node is either text or an element. An element has a tag name and optionally children and attributes.
Text is serialized directly to strings.
An element becomes `[tag, attributes, children]`, where tag is either a string or a number representing one of the more common tag types, attributes is a map of strings/numbers (same idea) to strings, and children is a list of nodes. Attributes can be omitted. Children can also be omitted if attributes are too.