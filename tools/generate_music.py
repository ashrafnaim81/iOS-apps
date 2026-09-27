#!/usr/bin/env python3
"""Synthesise the calm background music loop (royalty-free, fully procedural).

Requires numpy and imageio-ffmpeg:  pip install numpy imageio-ffmpeg
Run from the repo root:             python3 tools/generate_music.py
Writes SudokuGame/Sounds/music.m4a. The loop is seamless: every note tail and
the reverb wrap around the end of the buffer back to its start.
"""
import os
import random
import subprocess
import wave

import imageio_ffmpeg
import numpy as np

SR = 32000
BPM = 72
BEAT = 60 / BPM
BAR = 4 * BEAT
EIGHTH = BEAT / 2

# Fmaj7 - Em7 - Dm7 - Cmaj7, two bars each: a slow, descending, restful loop.
CHORDS = [(41, [53, 57, 60, 64]), (40, [52, 55, 59, 62]), (38, [50, 53, 57, 60]), (36, [48, 52, 55, 59])]
PENTATONIC = [72, 74, 76, 79, 81, 84, 86, 88]
CYCLES = 3
LENGTH = int(round(CYCLES * len(CHORDS) * 2 * BAR * SR))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "SudokuGame", "Sounds", "music.m4a")

rng = random.Random(20260927)
buf = np.zeros(LENGTH)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def add(start_sec, samples):
    """Mix samples into the loop, wrapping past the end back to the start."""
    start = int(start_sec * SR) % LENGTH
    idx = (start + np.arange(len(samples))) % LENGTH
    np.add.at(buf, idx, samples)


def voice(freq, dur, partials, attack, decay, amp):
    t = np.arange(int(dur * SR)) / SR
    wave_ = sum(w * np.sin(2 * np.pi * freq * m * t) for m, w in partials)
    env = np.minimum(1, t / attack) * np.exp(-t / decay)
    return amp * wave_ * env


def pad(freq, dur, amp):
    t = np.arange(int((dur + 2.5) * SR)) / SR
    tone = (np.sin(2 * np.pi * freq * 0.998 * t) + np.sin(2 * np.pi * freq * 1.002 * t)
            + 0.25 * np.sin(2 * np.pi * freq * 2 * t)) / 2.25
    attack = np.clip(t / 1.6, 0, 1)
    release = np.clip(1 - (t - dur) / 2.5, 0, 1)
    swell = 0.85 + 0.15 * np.sin(2 * np.pi * t / 5.5)
    return amp * tone * attack * release * swell


segment = 2 * BAR
for cycle in range(CYCLES):
    density = [0.2, 0.34, 0.27][cycle]
    idx = rng.randrange(2, 5)
    for c, (root, chord) in enumerate(CHORDS):
        t0 = (cycle * len(CHORDS) + c) * segment
        for note in chord:
            add(t0, pad(hz(note), segment, 0.09))
        for bar in range(2):
            add(t0 + bar * BAR, voice(hz(root), 3.2, [(1, 1), (2, 0.3)], 0.02, 1.6, 0.26))
        for step in range(16):
            strong = step in (0, 8)
            if not strong and rng.random() > density:
                continue
            if strong:
                tones = [n + 12 for n in chord if n + 12 in PENTATONIC or n + 24 in PENTATONIC]
                pitch = rng.choice(tones) + 12 if tones and rng.random() < 0.6 else PENTATONIC[idx]
            else:
                idx = max(0, min(len(PENTATONIC) - 1, idx + rng.choice([-2, -1, -1, 1, 1, 2])))
                pitch = PENTATONIC[idx]
            swing = 0.03 if step % 2 else 0
            amp = rng.uniform(0.13, 0.22) * (1.2 if strong else 1)
            add(t0 + step * EIGHTH + swing,
                voice(hz(pitch), 2.4, [(1, 1), (2, 0.28), (3, 0.1), (4.2, 0.04)], 0.004, 0.75, amp))

# Circular convolution with a soft, dark reverb tail keeps the loop seamless.
ir_len = int(3.0 * SR)
t = np.arange(ir_len) / SR
noise = np.random.default_rng(7).standard_normal(ir_len)
kernel = np.ones(24) / 24
ir = np.convolve(noise, kernel, mode="same") * np.exp(-t / 0.8)
ir /= np.sqrt(np.sum(ir ** 2))
ir_full = np.zeros(LENGTH)
ir_full[:ir_len] = ir
wet = np.real(np.fft.ifft(np.fft.fft(buf) * np.fft.fft(ir_full)))
mix = 0.72 * buf + 0.45 * wet * (np.max(np.abs(buf)) / max(np.max(np.abs(wet)), 1e-9))
mix = np.tanh(mix / np.max(np.abs(mix)) * 1.1)
mix = mix / np.max(np.abs(mix)) * 0.8

tmp = os.path.join(HERE, "_music.wav")
with wave.open(tmp, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", tmp,
                "-c:a", "aac", "-b:a", "80k", OUT], check=True)
os.remove(tmp)
print(f"wrote {OUT} ({LENGTH / SR:.1f}s, {os.path.getsize(OUT) // 1024} KB)")
