# random-stuff

In the interest of transparency and/or being vaguely useful, I'm releasing many random and/or deterministic small things accumulated from various projects folders over the years.
This comes with absolutely no guarantee of support or correct function, although if you need some of this for something I will *try* and answer any queries you might have.

## Contents (incomplete and rough list)

* some interpreters for various esolangs, written for competitions on an esolangs Discord server
* trivial x86-64 assembly hello world for some reason
* political compass visualizer thing for one Discord server
* simple un-hexadecimal-izer program (`base64 -d` exists but somehow not `base16 -d` or some equivalent)
* `generate-tape-image.py` - scripts for packing music + metadata onto Computronics (a Minecraft mod) tape images - these require LionRay to do the DFPWM conversion as of now. Can be played with something like [this](https://pastebin.com/SPyr8jrh).
* a thing to generate WAV files containing beeping noises
* fairly transferable small bits of an abandoned JS project
* an extremely bad cookie clicker-style incremental thing where you press the enter key instead of clicking
* a very simple web API wrapper for `luamin`
* a tweaked old version of [it-was-inevitable](https://github.com/BenLubar/it_was_inevitable) which runs a local webserver instead of sending to Mastodon. Used to be used by PotatOS but this was discontinued due to RAM use.
* an extremely accursed program which bruteforces regexes or something? Not that this actually does anything beyond using vast amounts of CPU and printing things.
* `realtau.txt`, which seemingly contains 100000 digits of τ. I wonder if there's a faketau somewhere.
* a strange thing which lets you use synonyms to get attributes on python objects
* code for generating random vaguely human readable names in Elm. Please note that I do NOT endorse the use of Elm and this is provided mostly just to make the languages list at the side weirder rather than for any actual uses.
* F# kerbal name generator & very basic stack calculator
* Wikipedia dump index indexer (I think some of this is just example code for an oddly specific crate which parses the dump XML)
* `ptt.py` - Python-based systemwide push to talk (mutes and unmutes microphone via PulseAudio) with tray icon
* `code-guessing` - contains my entries, some test code, and build processes for my submissions to the Esolangs code guessing competition. There are also some things which never made it into an entry, such as my abuse of [Z3](https://github.com/Z3Prover/z3) to solve mazes (it's surprisingly effective).
    * `list-sort.py`, which sorts lists of integers by interpreting a simple Lispy language and doing a continuation-passing-style quicksort (to avoid stack issues; it supports tail call optimization so this is "efficient").
    * `maze2.py`, which does simple depth first search to solve a maze in a pleasantly compact format.
    * `multiply_matrices.py`, which abuses many Python features and does matrix multiplication in an inefficient recursive way which *looks* like Strassen's algorithm but isn't.
    * `anagram.c`, which detects whether strings are (case-insensitively, and ignoring spaces) anagrams by uppercasing them, sorting them, and removing spaces and comparing them for equality. It does this by dividing the string into 16-byte chunks which can fit into a 128-bit `xmm` register (this had to run on Sandy Bridge systems, which lack AVX2), uppercasing them using three vector instructions (via the invariant that the input won't contain anything but `[A-Za-z ]`), applying a SIMD-based bubblesort to each chunk which swaps all the necessary pairs at once until it stops changing, and then using a 32-way (sequential; no idea how to parallelize this) merge to output a sorted string and discard spaces. These can then be checked for equality.
* `mcc.py` - a chat program. Unlike most chat programs, it runs over IPv6 multicast so you can talk to anyone on your LAN who also happens to have this program somehow. Very flaky, due to trying to autoguess a network interface to use and also limited testing, as well as quite barebones.
* `tiscubed.py` - an esolang somewhat like TIS-100, but with a somewhat exotic (almost no immediate operands, no registers, only 256B of memory per node) binary machine code format instead of assembly (there is an assembler available too). It's called "cubed" due to three dimensions, but I haven't actually done this yet.
* `iterated-prisoners-dilemma` - some scripts from an iterated prisoners' dilemma competition. Unfortunately, nobody came up with any particularly exciting algorithms for this.
* `calibre-indexer` - full text search for Calibre libraries, via SQLite.
    * SQLite may not have been a great choice for this, as it cannot do concurrent writes. Nevertheless, the code works, if not particularly efficiently, and allows you to build a full text table (using [FTS5](https://sqlite.org/fts5.html)) to rapidly search in your Calibre library.
    * While searches are near-instant, building the index is very slow (several deciseconds per book) and it takes up large amounts of disk space (though less than the original books, funnily, because those contain images). It's smart enough to not operate again on books it already has which haven't been changed, though.
    * It only works on EPUBs, because I couldn't be bothered to support other formats (calibre can convert them anyway).
    * Text (and chapter titles, ish) is extracted using a simple but seemingly fairly reliable state machine and `xml-rs`.
    * I have not gotten round to releasing a nice-to-use frontend for this. You can use `run-query.py` for a less nice one.
* `length_terminated_strings.c` - a revolution in computer science, combining the efficient `strlen` of null-terminated strings with the... inclusion of length? of length-prefixed/fat-pointer strings. A length-terminated string has its length at the *end*, occupying 1 to 8 bytes. To find its length, simply traverse the string until the data at the end matches the length traversed so far. Yes, this implementation might slightly have a bit of undefined behaviour.
* `discord-message-dump.py`, which reads a GDPR data dump from Discord and copies all the messages in public channels to a CSV file. I used this for training of a GPT-2 instance on my messages (available on request).
* `spudnet-http.py` - connect to the SPUDNET backend underlying [PotatOS](https://git.osmarks.net/osmarks/potatOS/)'s ~~backdoors~~ remote debugging system via the convenient new HTTP long-polling-based API.
* `fractalart-rs` - [this](https://github.com/TomSmeets/FractalArt/) in Rust and faster, see its own README for more details.
* `arbtt_wayland_toplevel.py` - interfaces [arbtt](https://arbtt.nomeata.de/) with Wayland foreign toplevel protocol and idle notifications.
* `fractalize_image.py` - used for making a profile picture for someone once.
* `goose2function.py` - converts goose neck profiles extracted from images of geese into activation functions for machine learning.
* `histretention.py` - dump Firefox `places.sqlite3` into a separate database (Firefox clears out old history internally for performance reasons or something like that) for later search.
* `memeticize.py` - the script I use to process memes from a large directory of heterogenous files.
* `rng_trainer.html` - a very unfinished attempt to implement a paper I found on training high-quality random number generation.
* `smtp2rss.py` - bridge SMTP (inbound emails) to RSS.
* `yearbox.html` - DokuWiki-type yearbox prototype for Minoteaur (I think this actually contains an off-by-one error somewhere; it isn't what's actually in use).
* `arbitrary-politics-graphs` - all you need to run your own election campaign.
* `heavbiome` - some work on biome generation with Perlin noise.
* `block_scope.py` - Python uses function scoping rather than block scoping. Some dislike this. I made a decorator to switch to block scoping.
* `mpris_smart_toggle.py` - playerctl play-pause sometimes does not play or pause the media I want played or paused (it seems to use some arbitrary selection order). This does it somewhat better by tracking the last thing which was playing.