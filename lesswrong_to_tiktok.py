import wave, sys
import nltk
from balacoon_tts import TTS
from collections import namedtuple
import struct
from PIL import Image, ImageDraw
import cv2
import numpy
import subprocess

WIDTH = 400

AUDIO = "/tmp/x.wav"
VIDEO = "/tmp/x.avi"
BACKDROP = "/tmp/x.mkv"
OUTPUT = "/tmp/x.mp4"

def render_text(text: str):
    render_params = {"font_size": 24}
    im  = Image.new("RGBA", (WIDTH, WIDTH))
    draw = ImageDraw.Draw(im)
    loc = [0, 0]
    toks = text.split()
    toks.reverse()
    text_commands = []
    while toks:
        chunk = []
        while draw.textbbox(loc, " ".join(chunk), **render_params)[2] < WIDTH:
            if not toks: break
            chunk.append(toks.pop())
        else: toks.append(chunk.pop())
        bbox = draw.textbbox(loc, " ".join(chunk), **render_params)
        text_commands.append((tuple(loc), " ".join(chunk)))
        loc[1] = bbox[3]
    draw.rectangle([0, 0, WIDTH, loc[1]], fill="white")
    for loc, text in text_commands:
        draw.text(loc, text, fill="black", **render_params)
    return im

Pause = namedtuple("Pause", ["length"])

text = open("/home/osmarks/Downloads/seq1.txt").read()

tts = TTS("/home/osmarks/Downloads/en_us_hifi_jets_cpu.addon")
#supported_speakers = tts.get_speakers()
speaker = "6670"

def chunks(text: str) -> list[str | Pause]:
    out = []
    for line in text.splitlines():
        if line:
            for sent in nltk.sent_tokenize(line):
                out.append(sent)
                out.append(Pause(0.5))
            out.append(Pause(1))
    return out

RATE = tts.get_sampling_rate()
FPS = 30

def wavblank(seconds):
    return struct.pack(">h", 0) * round(seconds * RATE / 2)

blank_frame = render_text("")

fourcc = cv2.VideoWriter_fourcc(*"MJPG")
video_writer = cv2.VideoWriter(VIDEO, fourcc, FPS, (WIDTH, WIDTH))
total_dur = 0
with wave.open(AUDIO, "w") as fp:
    fp.setparams((1, 2, RATE, 0, "NONE", "NONE"))
    for chunk in chunks(text):
        if isinstance(chunk, str):
            samples = tts.synthesize(chunk, speaker)
            image = render_text(chunk)
        elif isinstance(chunk, Pause):
            samples = wavblank(chunk.length)
            image = blank_frame
        fp.writeframes(samples)
        duration = len(samples) / RATE # what
        total_dur += duration
        frame = cv2.cvtColor(numpy.array(image), cv2.COLOR_RGBA2BGR)
        for _ in range(round(duration * FPS)): video_writer.write(frame)
        print(chunk, duration)
video_writer.release()
subprocess.run([
    "ffmpeg",
    "-i", BACKDROP, "-i", AUDIO, "-i", VIDEO,
    "-filter_complex", "overlay=x=200:y=200,format=nv12,hwupload",
    "-to", str(total_dur),
    "-y",
    "-vaapi_device", "/dev/dri/renderD128", "-c:v", "h264_vaapi",
    OUTPUT
]).check_returncode()