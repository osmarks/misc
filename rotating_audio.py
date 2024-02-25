import pathlib
import numpy as np
import wave
import math
import tempfile
import subprocess
import contextlib

cyc = 2
nsamples = 48000 * 60
path = pathlib.Path("~/Downloads/inputs").expanduser()

inputs = []
tempfiles = []
with contextlib.ExitStack() as stack:
    for file in path.glob("*"):
        mgr = tempfile.NamedTemporaryFile("w")
        stack.enter_context(mgr)
        tempfiles.append(mgr)
        subprocess.run(["ffmpeg", "-i", file, "-ar", "48000", "-ac", "1", "-filter:a", "dynaudnorm=p=1.0:s=5:g=15", "-y", "-f", "wav", mgr.name])

    for t in tempfiles:
        with wave.open(str(t.name), "r") as w:
            assert w.getsampwidth() == 2 and w.getnchannels() == 1 and w.getframerate() == 48000
            inputs.append(np.frombuffer(w.readframes(nsamples), np.dtype(np.int16).newbyteorder("<")).astype(float) / 32768)

inputs = np.array(inputs) * (1/len(inputs)) # wrong but close enough
offsets = np.broadcast_to(np.linspace(0, math.pi * 2, num=len(inputs) + 1)[:len(inputs)], (nsamples, len(inputs))).transpose()
phase = np.broadcast_to(np.linspace(0, math.pi * 2 * cyc, num=nsamples), (len(inputs), nsamples)) + offsets
empty = np.zeros_like(phase)
x = np.cos(phase)
y = np.sin(phase)

def writeaudio(file, array):
    wr = wave.open(file, "w")
    wr.setnchannels(1)
    wr.setsampwidth(2)
    wr.setframerate(48000)
    wr.writeframes((array * 32768).astype("<i2").tobytes())
    wr.close()

with tempfile.NamedTemporaryFile("wb") as left:
    with tempfile.NamedTemporaryFile("wb") as front:
        with tempfile.NamedTemporaryFile("wb") as right:
            with tempfile.NamedTemporaryFile("wb") as back:
                writeaudio(left, sum(np.where(-x > 0, -x, empty) * inputs))
                writeaudio(right, sum(np.where(x > 0, x, empty) * inputs))
                writeaudio(front, sum(np.where(y > 0, y, empty) * inputs))
                writeaudio(back, sum(np.where(-y > 0, -y, empty) * inputs))
                print(front.name)
                # layout is technically front left + front right + back left + back right - ignore
                subprocess.run(["ffmpeg", "-i", front.name, "-i", right.name, "-i", back.name, "-i", left.name, "-filter_complex", "[0:a][1:a]join=inputs=4:channel_layout=quad[a]", "-map", "[a]", "/tmp/out.opus"]).check_returncode()