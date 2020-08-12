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
sample_rate = 44100.0


def append_silence(duration_milliseconds=500):
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    for x in range(int(num_samples)): 
        audio.append(0.0)
    return


def append_sinewave(
        freq=440.0, 
        duration_milliseconds=500, 
        volume=1.0):
    global audio # using global variables isn't cool.
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    for x in range(int(num_samples)):
        audio.append(volume * math.sin(2 * math.pi * freq * ( x / sample_rate )))

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

#for _ in range(8):
#    append_sinewave(volume=1.0, freq=1000.0)
#    append_silence()
append_sinewave(freq=500, duration_milliseconds=500)
append_sinewave(freq=1000, duration_milliseconds=500)
append_sinewave(freq=2000, duration_milliseconds=500)
append_sinewave(freq=500, duration_milliseconds=500)
save_wav("output.wav")