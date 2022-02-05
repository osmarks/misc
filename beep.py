#!/usr/bin/python 
# based on : www.daniweb.com/code/snippet263775.html
# from https://stackoverflow.com/questions/33879523/python-how-can-i-generate-a-wav-file-with-beeps
import math
import wave
import struct

# Audio will contain a long list of samples (i.e. floating point numbers describing the
# waveform).  If you were working with a very long sound you'd want to stream this to
# disk instead of buffering it all in memory list this.  But most sounds will fit in 
# memory.
audio = []
sample_rate = 48000.0
phase = 0

def append_silence(duration_milliseconds=500):
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    for x in range(int(num_samples)): 
        audio.append(0.0)
    return


def append_sinewave(
        freq=440.0, 
        duration_milliseconds=500, 
        volume=1.0):
    global phase
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    pc = math.tau * freq / sample_rate
    for x in range(int(num_samples)):
        phase += pc
        audio.append(volume * math.sin(phase))

def append_squarewave(
        freq=440.0,
        duration_milliseconds=500,
        volume=1.0):
    global audio
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    samples_per_toggle = math.floor(sample_rate / freq)
    for x in range(int(num_samples)):
        on = math.floor(x / samples_per_toggle) % 2
        audio.append(volume * on)

def save_wav(file_name):
    wav_file=wave.open(file_name,"w")
    nchannels = 1
    sampwidth = 2
    nframes = len(audio)
    comptype = "NONE"
    compname = "not compressed"
    wav_file.setparams((nchannels, sampwidth, sample_rate, nframes, comptype, compname))
    for sample in audio:
        wav_file.writeframes(struct.pack('h', int( sample * 32767.0 )))

    wav_file.close()
    return

import random
freq = 6
for i in range(160):
    append_sinewave(volume=1.0, freq=math.exp(freq), duration_milliseconds=50)
    freq += random.uniform(-0.2, 0.2)
    freq = max(4.5, min(freq, 9))
save_wav("output.wav")
