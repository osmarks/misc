#!/usr/bin/env python3
import subprocess
import tempfile
import os
import os.path
import collections
import json
import sys
import multiprocessing
import struct

ProcessedTrack = collections.namedtuple("ProcessedTrack", ["dfpwm_file", "metadata"])

def convert_wav_dfpwm(infile, outfile):
    subprocess.run(["java", "-jar", "LionRay.jar", infile, outfile])

def convert_any_wav(infile, outfile):
    subprocess.run(["ffmpeg", "-hide_banner", "-i", infile, "-ar", "48000", "-ac", "1", outfile], stderr=subprocess.PIPE)

def read_meta(path):
    proc = subprocess.run(["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", path], stdout=subprocess.PIPE)
    data = json.loads(proc.stdout)
    meta = {}
    # These are the two locations I've found tags in in my not very thorough testing
    try:
        meta.update(data["format"]["tags"])
    except KeyError: pass
    try:
        meta.update(data["streams"][0]["tags"])
    except KeyError: pass
    # lowercase all keys because in Opus files these seem to be uppercase sometimes
    return { k.lower(): v for k, v in meta.items() }

def process_file(filename):
    meta = read_meta(filename)
    wav_dest = tempfile.mktemp(".wav")
    convert_any_wav(filename, wav_dest)
    dfpwm_dest = tempfile.mktemp(".dfpwm")
    convert_wav_dfpwm(wav_dest, dfpwm_dest)
    os.remove(wav_dest)
    print(filename)
    return ProcessedTrack(dfpwm_dest, {
        "title": meta["title"],
        "artist": meta.get("artist", None) or meta.get("artists", None),
        "album": meta.get("album", None)
    })

def read_binary(filename):
    with open(filename, "rb") as f:
        return f.read()

def process_dir(dirname):
    files = list(map(lambda file: os.path.join(dirname, file), os.listdir(dirname)))
    with multiprocessing.Pool(8) as p:
        tracks = p.map(process_file, files)
    tape_image = b""
    tracks_meta = []
    for track in tracks:
        track.metadata["start"] = len(tape_image)
        data = read_binary(track.dfpwm_file)
        os.remove(track.dfpwm_file)
        track.metadata["end"] = track.metadata["start"] + len(data)
        tape_image += data
        tracks_meta.append(track.metadata)
    # dump in a compact format to save space
    meta = json.dumps({ "tracks": tracks_meta }, separators=(',', ':')).encode("utf-8")
    assert(len(meta) < 65536)
    # new format - 0x54 marker byte, then metadata length as 2-byte big endian integer, then metadata, then concatenated DFPWM files
    # start is now not an absolute position but just how far after the metadata it is
    tape_image = b"\x54" + struct.pack(">H", len(meta)) + meta + tape_image
    with open("tape.bin", "wb") as f:
        f.write(tape_image)
    # Tape lengths are measured in minutes. 6000 bytes are played per second because they use a 48000Hz sample rate and DFPWM is somehow 1 bit per sample.
    length_minutes = len(tape_image) / (6000*60)
    print(length_minutes, "minute tape required")

process_dir(sys.argv[1])
