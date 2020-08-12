#!/usr/bin/env python3
import subprocess
import tempfile
import os
import os.path
import collections
import json
import sys

ProcessedTrack = collections.namedtuple("ProcessedTrack", ["dfpwm_file", "artist", "track"])

def convert_wav_dfpwm(infile, outfile):
    subprocess.run(["java", "-jar", "LionRay.jar", infile, outfile])

def convert_any_wav(infile, outfile):
    subprocess.run(["ffmpeg", "-hide_banner", "-i", infile, "-ac", "1", outfile], stderr=subprocess.PIPE)

def process_file(filename):
    parts = list(map(str.strip, os.path.splitext(os.path.basename(filename))[0].split("-")))
    artist = parts[0]
    track = parts[1]
    wav_dest = tempfile.mktemp(".wav")
    convert_any_wav(filename, wav_dest)
    dfpwm_dest = tempfile.mktemp(".dfpwm")
    convert_wav_dfpwm(wav_dest, dfpwm_dest)
    os.remove(wav_dest)
    return ProcessedTrack(dfpwm_dest, artist, track)

def read_binary(filename):
    with open(filename, "rb") as f:
        return f.read()

def process_dir(dirname):
    tracks = []
    for file in os.listdir(dirname):
        tracks.append(process_file(os.path.join(dirname, file)))
    tape_image = b""
    tracks_meta = []
    for track in tracks:
        track_meta = {}
        track_meta["start"] = len(tape_image) + 8193
        data = read_binary(track.dfpwm_file)
        os.remove(track.dfpwm_file)
        track_meta["end"] = track_meta["start"] + len(data)
        track_meta["artist"] = track.artist
        track_meta["title"] = track.track
        tape_image += data
        tracks_meta.append(track_meta)
        print(track.track, track.artist)
    meta = json.dumps({ "tracks": tracks_meta }).encode("utf-8").ljust(8192, b"\0")
    tape_image = meta + tape_image
    with open("tape.bin", "wb") as f:
        f.write(tape_image)


process_dir(sys.argv[1])