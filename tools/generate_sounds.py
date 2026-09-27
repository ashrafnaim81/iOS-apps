#!/usr/bin/env python3
"""Synthesise the game's sound effects (royalty-free, no external assets).

Run from the repo root:  python3 tools/generate_sounds.py
Writes 16-bit mono WAV files into SudokuGame/Sounds/.
"""
import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "SudokuGame", "Sounds")

MARIMBA = [(1.0, 1.0), (3.93, 0.28), (9.4, 0.06)]
BELL = [(1.0, 1.0), (2.0, 0.45), (3.01, 0.22), (4.2, 0.1), (5.4, 0.05)]
SOFT = [(1.0, 1.0), (2.0, 0.15)]


def note(freq, dur, partials=SOFT, decay=0.2, attack=0.004, amp=1.0, glide_to=None):
    n = int(SR * dur)
    out = [0.0] * n
    for mult, weight in partials:
        phase = 0.0
        for i in range(n):
            t = i / SR
            f = freq if glide_to is None else freq + (glide_to - freq) * min(1.0, t / dur)
            phase += 2 * math.pi * f * mult / SR
            env = min(1.0, t / attack) * math.exp(-t / (decay / math.sqrt(mult)))
            out[i] += weight * env * math.sin(phase)
    return [s * amp for s in out]


def mix(parts, dur):
    buf = [0.0] * int(SR * dur)
    for offset, samples in parts:
        start = int(offset * SR)
        for i, s in enumerate(samples):
            if start + i < len(buf):
                buf[start + i] += s
    return buf


def write(name, samples, peak):
    top = max(abs(s) for s in samples) or 1.0
    fade = int(SR * 0.006)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    path = os.path.join(OUT, f"{name}.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s / top * peak * 32767)) for s in samples))
    print("wrote", path)


def main():
    os.makedirs(OUT, exist_ok=True)
    write("tap", note(1320, 0.06, SOFT, decay=0.012, attack=0.001), 0.35)
    write("button", note(520, 0.09, SOFT, decay=0.03, attack=0.002, glide_to=300), 0.45)
    write("place", mix([(0, note(784, 0.4, MARIMBA, decay=0.1)),
                        (0, note(1568, 0.3, SOFT, decay=0.05, amp=0.2))], 0.4), 0.6)
    write("erase", note(620, 0.14, SOFT, decay=0.045, attack=0.002, glide_to=340), 0.45)
    write("error", mix([(0.0, note(233, 0.2, [(1, 1), (3, 0.25)], decay=0.07)),
                        (0.11, note(185, 0.3, [(1, 1), (3, 0.25)], decay=0.1))], 0.42), 0.55)
    write("hint", mix([(0.00, note(1568, 0.3, BELL, decay=0.12)),
                       (0.05, note(2093, 0.3, BELL, decay=0.12)),
                       (0.10, note(2637, 0.4, BELL, decay=0.16))], 0.55), 0.5)
    write("group", mix([(0.00, note(1047, 0.6, BELL, decay=0.22)),
                        (0.07, note(1319, 0.6, BELL, decay=0.22)),
                        (0.14, note(1568, 0.6, BELL, decay=0.22)),
                        (0.21, note(2093, 0.7, BELL, decay=0.28))], 0.95), 0.6)
    write("star", mix([(0, note(1319, 0.55, BELL, decay=0.2)),
                       (0, note(2637, 0.45, BELL, decay=0.14, amp=0.35))], 0.55), 0.55)
    arpeggio = [(i * 0.11, note(f, 0.45, MARIMBA, decay=0.14))
                for i, f in enumerate([523, 659, 784, 1047])]
    chord = [(0.48, note(f, 2.0, BELL, decay=0.7, amp=0.7)) for f in (1047, 1319, 1568, 2093)]
    sparkle = [(0.5 + i * 0.07, note(f, 0.4, BELL, decay=0.12, amp=0.25))
               for i, f in enumerate([2637, 3136, 3520, 4186])]
    write("win", mix(arpeggio + chord + sparkle, 2.6), 0.75)


if __name__ == "__main__":
    main()
