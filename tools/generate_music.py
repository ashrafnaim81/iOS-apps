#!/usr/bin/env python3
"""Compose and render the two relaxed jazz background tracks (royalty-free, synthesised).

Requires numpy and imageio-ffmpeg:  pip install numpy imageio-ffmpeg
Run from the repo root:             python3 tools/generate_music.py
Writes SudokuGame/Sounds/music_home.m4a and music_game.m4a, and prints each
track's exact loop length in frames.

"Santai Pagi" is a bossa nova (nylon guitar, upright bass, brushes, soft piano);
"Santai Petang" is a slow ballad (finger-picked guitar, soft felt piano, bass).
Both follow Intro - A - A' - B - A. Note tails, reverb and the tone filter
wrap around the end of the buffer, so each file loops seamlessly.
"""
import os
import random
import subprocess
import wave

import imageio_ffmpeg
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "SudokuGame", "Sounds")


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def noise(n, seed):
    return np.random.default_rng(seed).standard_normal(n)


def smooth(x, width):
    return np.convolve(x, np.ones(width) / width, mode="same")


def highpass(x, times=1):
    for _ in range(times):
        x = np.diff(x, prepend=x[0])
    return x


# --------------------------------------------------------------------------- instruments

def pluck(freq, dur, vel, seed, brightness=0.5, decay=0.996, pick=0.2):
    """Karplus-Strong string, tuned exactly by resampling."""
    period = max(2, int(SR / freq))
    n = int((dur + 0.4) * SR * freq / (SR / (period + 0.5)))
    # A string pulled into a triangle at the pick point (strong fundamental), plus a little
    # noise for finger texture, smoothed relative to the period for a warm fingertip pluck.
    pos = np.arange(period) / period
    excite = np.where(pos < pick, pos / pick, (1 - pos) / (1 - pick)) - 0.5
    excite = excite + 0.06 * noise(period, seed)
    excite = smooth(np.tile(excite, 3), max(1, int(period * (0.02 + (1 - brightness) * 0.12))))[period:2 * period]
    y = np.zeros(n + period + 1)
    y[:period] = excite
    k = period
    while k < n:
        end = min(k + period, n)
        prev = y[k - period:end - period]
        prev1 = y[k - period - 1:end - period - 1] if k - period - 1 >= 0 else np.concatenate([[0], prev[:-1]])
        y[k:end] = decay * 0.5 * (prev + prev1)
        k = end
    y = y[:n]
    actual = SR / (period + 0.5)
    out_n = int((dur + 0.4) * SR)
    src = np.arange(out_n) * (freq / actual)
    out = np.interp(src, np.arange(n), y, right=0)
    t = np.arange(out_n) / SR
    damp = np.clip(1 - (t - dur) / 0.35, 0, 1)
    return vel * out / (np.max(np.abs(out)) + 1e-9) * damp


def nylon(freq, dur, vel, seed):
    return pluck(freq, dur, vel, seed, brightness=0.35, decay=0.9965, pick=0.18)


def upright(freq, dur, vel, seed):
    body = pluck(freq, dur, 1, seed, brightness=0.15, decay=0.992, pick=0.3)
    t = np.arange(len(body)) / SR
    # Add the octave so the bass is audible on phone speakers.
    return vel * np.tanh(1.4 * (body + 0.6 * np.sin(4 * np.pi * freq * t) * np.exp(-t / 0.5)))


def felt_piano(freq, dur, vel):
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    tone = sum(w * np.sin(2 * np.pi * freq * h * (1 + 0.0004 * h * h) * t) * np.exp(-t * h / 1.6)
               for h, w in [(1, 1), (2, 0.28), (3, 0.08), (4, 0.03)])
    env = np.minimum(1, t / 0.012) * np.exp(-t / 2.4) * np.clip(1 - (t - dur) / 0.6, 0, 1)
    return vel * tone * env


def brush_swish(vel, seed, length=0.32):
    n = int(length * SR)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.5
    return vel * smooth(highpass(noise(n, seed), 1), 4) * env * 0.12


def brush_tap(vel, seed):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    return vel * smooth(highpass(noise(n, seed), 1), 2) * np.exp(-t / 0.06) * 0.35


def soft_kick(vel):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 52 + 45 * np.exp(-t / 0.03)
    return vel * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)


# --------------------------------------------------------------------------- song renderer

class Song:
    def __init__(self, bpm, bars, seed, swing=0.0):
        self.spb = 60 / bpm
        self.n = int(round(bars * 4 * self.spb * SR))
        self.bus = np.zeros((2, self.n))
        self.rng = random.Random(seed)
        self.seed = seed
        self.swing_amount = swing
        self.plucks = 0

    def next_seed(self):
        self.plucks += 1
        return self.seed * 100000 + self.plucks

    def add(self, beat, samples, pan=0.0, gain=1.0):
        start = int((beat * self.spb + self.rng.uniform(-0.005, 0.005)) * SR) % self.n
        gl, gr = np.cos((pan + 1) * np.pi / 4) * gain, np.sin((pan + 1) * np.pi / 4) * gain
        pos = 0
        while pos < len(samples):
            s = (start + pos) % self.n
            chunk = min(len(samples) - pos, self.n - s)
            self.bus[0, s:s + chunk] += samples[pos:pos + chunk] * gl
            self.bus[1, s:s + chunk] += samples[pos:pos + chunk] * gr
            pos += chunk

    def swing(self, beat):
        return beat + self.swing_amount if abs(beat % 1 - 0.5) < 1e-6 else beat

    # -- parts

    def bossa_guitar(self, bar0, progression, gain=1.0):
        """Thumb plays root/fifth on 1 and 3; fingers pluck the chord on the syncopated bossa rhythm."""
        pattern = [(0, 1.2), (1.5, 1.0), (3, 0.9), (4.5, 1.2), (6, 1.0)]
        for i, bar in enumerate(progression):
            for (offset, root, voicing, length) in bar:
                b0 = (bar0 + i) * 4 + offset
                for k, thumb in enumerate([0, 2]):
                    if thumb < length:
                        note = root + 12 if k == 0 else root + 19
                        self.add(b0 + thumb, nylon(hz(note), 1.6 * self.spb, 0.5, self.next_seed()), pan=-0.15, gain=gain)
                bar_in_cycle = (bar0 + i) % 2
                for beat, dur in pattern:
                    local = beat - 4 * bar_in_cycle
                    if offset <= local < offset + length:
                        for j, note in enumerate(voicing[:4]):
                            self.add((bar0 + i) * 4 + local + j * 0.012,
                                     nylon(hz(note), dur * self.spb, 0.32, self.next_seed()),
                                     pan=0.1 + 0.08 * j, gain=gain)

    def arpeggio_guitar(self, bar0, progression, gain=1.0):
        order = [0, 1, 2, 3, 2, 1, 2, 3]
        for i, bar in enumerate(progression):
            for (offset, root, voicing, length) in bar:
                b0 = (bar0 + i) * 4 + offset
                self.add(b0, nylon(hz(root + 12), length * self.spb, 0.42, self.next_seed()), pan=-0.2, gain=gain)
                for step in range(1, int(length * 2)):
                    note = voicing[order[step % len(order)] % len(voicing)]
                    vel = 0.26 if step % 2 == 0 else 0.2
                    self.add(self.swing(b0 + step * 0.5), nylon(hz(note), 1.4 * self.spb, vel, self.next_seed()),
                             pan=0.2, gain=gain)

    def bass(self, bar0, progression, walking=False, gain=1.0):
        for i, bar in enumerate(progression):
            for (offset, root, voicing, length) in bar:
                b0 = (bar0 + i) * 4 + offset
                nxt = progression[(i + 1) % len(progression)][0][1]
                if length < 4:
                    self.add(b0, upright(hz(root), length * 0.9 * self.spb, 0.55, self.next_seed()), gain=gain)
                    continue
                notes = [(0, root, 1.6), (2, root + 7 if root + 7 <= 52 else root - 5, 1.6)]
                if walking:
                    notes = [(0, root, 0.95), (1, root + 4, 0.95), (2, root + 7, 0.95),
                             (3, nxt - 1 if nxt > root else nxt + 1, 0.95)]
                for beat, note, d in notes:
                    self.add(b0 + beat, upright(hz(note), d * self.spb, 0.55, self.next_seed()), gain=gain)

    def piano_pad(self, bar0, progression, gain=1.0):
        for i, bar in enumerate(progression):
            for (offset, root, voicing, length) in bar:
                b0 = (bar0 + i) * 4 + offset
                for j, note in enumerate(voicing):
                    self.add(b0 + 0.02 * j, felt_piano(hz(note), length * self.spb, 0.07),
                             pan=-0.3 + 0.2 * j, gain=gain)

    def melody(self, bar0, notes, voice="piano", gain=1.0, transpose=0, pan=0.05):
        for beat, midi, dur in notes:
            b = self.swing(bar0 * 4 + beat)
            f = hz(midi + transpose)
            vel = gain * self.rng.uniform(0.88, 1.0)
            if voice == "guitar":
                audio = nylon(f, max(dur, 1) * self.spb, vel, self.next_seed())
            else:
                audio = felt_piano(f, dur * self.spb, vel)
            self.add(b, audio, pan=pan)

    def brushes(self, bar0, bars, style, gain=1.0):
        for bar in range(bars):
            b0 = (bar0 + bar) * 4
            seed = self.seed * 1000 + b0
            for k in range(4):
                self.add(b0 + k - 0.08, brush_swish(0.8 if k % 2 == 0 else 0.6, seed + k), pan=0.25, gain=gain)
            for k in (1, 3):
                self.add(b0 + k, brush_tap(0.6, seed + 10 + k), pan=-0.1, gain=gain)
            kicks = (0, 2) if style == "bossa" else (0,)
            for k in kicks:
                self.add(b0 + k, soft_kick(0.45), gain=gain)
            if style == "bossa":
                for k in (1.5, 3.5):
                    self.add(b0 + k, brush_tap(0.3, seed + 20 + int(k)), pan=0.3, gain=gain)

    # -- mixdown

    def render(self):
        dry = self.bus
        wet = np.stack([self._reverb(dry[c], seed=11 + c) for c in range(2)])
        mix = dry + 0.32 * wet * (np.max(np.abs(dry)) / max(np.max(np.abs(wet)), 1e-9))
        mix += self._room_tone()
        mix = np.stack([self._tone(mix[c]) for c in range(2)])
        mix = np.tanh(mix / np.max(np.abs(mix)) * 1.1)
        return mix / np.max(np.abs(mix)) * 0.8

    def _reverb(self, x, seed):
        ir_len = int(2.8 * SR)
        t = np.arange(ir_len) / SR
        ir = smooth(noise(ir_len, seed), 40) * np.exp(-t / 0.8)
        ir /= np.sqrt(np.sum(ir ** 2))
        return np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(np.pad(ir, (0, self.n - ir_len)))))

    def _tone(self, x):
        f = np.fft.rfftfreq(self.n, 1 / SR)
        gain = 1 / (1 + (f / 7500) ** 4) * (1 / (1 + (40 / np.maximum(f, 1)) ** 4))
        return np.fft.irfft(np.fft.rfft(x) * gain, n=self.n)

    def _room_tone(self):
        rng = np.random.default_rng(self.seed)
        crackle = np.zeros(self.n)
        idx = rng.integers(0, self.n, size=int(self.n / SR * 3))
        crackle[idx] = rng.uniform(-1, 1, size=len(idx))
        crackle = smooth(crackle, 24) * 0.012
        return np.stack([crackle, np.roll(crackle, 517)])


def chord(root, voicing, offset=0, length=4):
    return [(offset, root, voicing, length)]


def write(song, name):
    audio = song.render()
    tmp = os.path.join(HERE, f"_{name}.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((audio.T * 32767).astype("<i2").tobytes())
    out = os.path.join(OUT_DIR, f"{name}.m4a")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", tmp,
                    "-c:a", "aac", "-b:a", "128k", out], check=True)
    os.remove(tmp)
    print(f"wrote {out} ({song.n / SR:.1f}s, {os.path.getsize(out) // 1024} KB, loop frames {song.n})")


# --------------------------------------------------------------------------- "Santai Pagi" (home): bossa nova

def santai_pagi():
    Gm9, C9 = chord(43, [58, 62, 65, 69]), chord(36, [58, 62, 64, 67])
    Fmaj9, Dm9 = chord(41, [57, 60, 64, 67]), chord(38, [60, 64, 65, 69])
    Bbmaj7, Am7 = chord(46, [57, 62, 65, 69]), chord(45, [55, 60, 64, 67])
    Gm7, C7, Dm7 = chord(43, [53, 58, 62, 65]), chord(36, [58, 64, 67, 70]), chord(38, [53, 57, 60, 64])
    Gm7C7 = [(0, 43, [53, 58, 62, 65], 2), (2, 36, [58, 64, 67, 70], 2)]
    a_prog = [Gm9, C9, Fmaj9, Dm9] * 2
    b_prog = [Bbmaj7, Am7, Gm7, C7, Bbmaj7, Am7, Dm7, Gm7C7]

    theme = [(0.5, 74, .5), (1, 77, .5), (1.5, 81, 1), (2.5, 79, .5), (3, 77, 1),
             (4, 76, 1.5), (5.5, 74, .5), (6, 76, .5), (6.5, 79, 1.5),
             (8.5, 81, .5), (9, 79, .5), (9.5, 76, 1), (10.5, 72, .5), (11, 76, 1),
             (12, 74, 2.5), (15, 72, .5), (15.5, 74, .5),
             (16.5, 74, .5), (17, 77, .5), (17.5, 81, 1), (18.5, 79, .5), (19, 77, 1),
             (20, 76, 1.5), (21.5, 74, .5), (22, 72, .5), (22.5, 70, .5), (23, 69, 1),
             (24.5, 72, .5), (25, 74, .5), (25.5, 76, .5), (26, 79, 1), (27, 76, 1)]
    a1 = theme + [(28, 77, 3)]
    a2 = theme + [(28, 81, 1.5), (29.5, 79, .5), (30, 77, .5), (30.5, 79, 1.5)]
    a3 = theme + [(28, 77, 4)]
    bridge = [(0, 74, 1.5), (1.5, 77, .5), (2, 81, 2), (4, 79, 1.5), (5.5, 76, .5), (6, 72, 2),
              (8, 70, 1), (9, 74, 1), (10, 77, 1), (11, 76, 1), (12, 76, 3), (15, 79, 1),
              (16, 77, 1.5), (17.5, 74, .5), (18, 81, 2), (20, 79, 1), (21, 76, 1), (22, 72, 2),
              (24, 74, 1), (25, 77, 1), (26, 81, 1.5), (27.5, 79, .5),
              (28, 77, 1), (29, 76, 1), (30, 74, .5), (30.5, 76, .5), (31, 79, 1)]

    s = Song(bpm=100, bars=36, seed=3)
    s.bossa_guitar(0, a_prog[:4], gain=0.5); s.bass(0, a_prog[:4], gain=0.55)                         # intro: guitar + bass
    s.bossa_guitar(4, a_prog, gain=0.5); s.bass(4, a_prog, gain=0.55); s.brushes(4, 8, "bossa")
    s.melody(4, a1, "guitar", 0.38, pan=0.0)                                     # theme on guitar first
    s.bossa_guitar(12, a_prog, gain=0.5); s.bass(12, a_prog, gain=0.55); s.brushes(12, 8, "bossa")
    s.melody(12, a2, "piano", 0.3)                                              # then soft piano takes it
    s.bossa_guitar(20, b_prog, gain=0.5); s.bass(20, b_prog, gain=0.55); s.brushes(20, 8, "bossa")
    s.piano_pad(20, b_prog, gain=0.8)
    s.melody(20, bridge, "piano", 0.3)                                          # bridge on soft piano
    s.bossa_guitar(28, a_prog, gain=0.5); s.bass(28, a_prog, gain=0.55); s.brushes(28, 8, "bossa")
    s.melody(28, a3, "piano", 0.3)
    return s


# --------------------------------------------------------------------------- "Santai Petang" (in game): ballad

def santai_petang():
    Cmaj9, Em7 = chord(36, [52, 55, 59, 62]), chord(40, [55, 59, 62, 64])
    Am9, Fmaj9 = chord(45, [55, 59, 60, 64]), chord(41, [52, 55, 57, 60])
    Dm9, G9sus = chord(38, [53, 57, 60, 64]), chord(43, [53, 57, 60, 62])
    Fm6 = chord(41, [53, 56, 60, 62])
    a_prog = [Cmaj9, Em7, Am9, Fmaj9] * 2
    b_prog = [Dm9, G9sus, Em7, Am9, Dm9, Fm6, Cmaj9, G9sus]

    theme = [(0, 76, 1), (1, 79, 1), (2, 74, 2), (4, 71, 1), (5, 74, 1), (6, 79, 1.5), (7.5, 76, .5),
             (8, 72, 1.5), (9.5, 76, .5), (10, 81, 2), (12, 79, 3), (15, 76, 1),
             (16, 76, 1), (17, 79, 1), (18, 84, 1.5), (19.5, 83, .5), (20, 79, 2), (22, 76, 1), (23, 74, 1),
             (24, 72, 1), (25, 74, 1), (26, 76, 1), (27, 81, 1), (28, 79, 4)]
    bridge = [(0, 77, 1.5), (1.5, 76, .5), (2, 74, 2), (4, 72, 1), (5, 74, 1), (6, 77, 2),
              (8, 76, 1.5), (9.5, 79, .5), (10, 83, 2), (12, 81, 3), (15, 79, 1),
              (16, 77, 1), (17, 81, 1), (18, 84, 2), (20, 80, 2), (22, 77, 2),
              (24, 76, 1), (25, 74, 1), (26, 72, 2), (28, 74, 3)]

    s = Song(bpm=64, bars=28, seed=4, swing=0.08)
    s.arpeggio_guitar(0, a_prog[:4], gain=0.75); s.piano_pad(0, a_prog[:4])
    s.arpeggio_guitar(4, a_prog, gain=0.75); s.piano_pad(4, a_prog); s.bass(4, a_prog, gain=0.62); s.brushes(4, 8, "ballad", gain=0.7)
    s.melody(4, theme, "piano", 0.32)                                            # soft piano theme
    s.arpeggio_guitar(12, b_prog, gain=0.75); s.piano_pad(12, b_prog); s.bass(12, b_prog, walking=True, gain=0.62)
    s.brushes(12, 8, "ballad", gain=0.7)
    s.melody(12, bridge, "piano", 0.32)                                           # soft piano answers
    s.arpeggio_guitar(20, a_prog, gain=0.75); s.piano_pad(20, a_prog); s.bass(20, a_prog, gain=0.62); s.brushes(20, 8, "ballad", gain=0.7)
    s.melody(20, theme, "piano", 0.32)
    return s


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write(santai_pagi(), "music_home")
    write(santai_petang(), "music_game")
