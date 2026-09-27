#!/usr/bin/env python3
"""Compose and render the two lo-fi background tracks (royalty-free, fully synthesised).

Requires numpy and imageio-ffmpeg:  pip install numpy imageio-ffmpeg
Run from the repo root:             python3 tools/generate_music.py
Writes SudokuGame/Sounds/music_home.m4a and music_game.m4a.

Each track is a written song (fixed melody, chord changes, drum groove) in
the form Intro - A - A' - B - A. Every note tail, the reverb and the tone
filter wrap around the end of the buffer, so the files loop seamlessly.
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


# --------------------------------------------------------------------------- instruments

def env_adsr(n, attack, decay_tau, hold, release):
    t = np.arange(n) / SR
    env = np.minimum(1, t / attack) * np.exp(-t / decay_tau)
    rel = np.clip(1 - (t - hold) / release, 0, 1)
    return env * rel


def epiano(freq, dur, vel):
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    index = 1.6 * np.exp(-t / 0.22) + 0.25
    mod = index * np.sin(2 * np.pi * freq * t)
    tone = np.sin(2 * np.pi * freq * t + mod) + 0.12 * np.sin(2 * np.pi * freq * 4.01 * t) * np.exp(-t / 0.08)
    trem = 1 + 0.07 * np.sin(2 * np.pi * 4.2 * t)
    return vel * tone * trem * env_adsr(n, 0.004, 1.6, dur, 0.35)


def kalimba(freq, dur, vel):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    tone = (np.sin(2 * np.pi * freq * t) + 0.22 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.15)
            + 0.07 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.05))
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.clip(t / 0.4, 0, 1)
    tone = np.sin(2 * np.pi * freq * np.cumsum(vib) / SR) + (tone - np.sin(2 * np.pi * freq * t))
    return vel * tone * env_adsr(n, 0.002, 0.9, dur + 0.3, 0.6)


def bass(freq, dur, vel):
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    # Upper harmonics keep the bass audible on small phone speakers.
    tone = np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(4 * np.pi * freq * t) + 0.18 * np.sin(6 * np.pi * freq * t)
    return vel * np.tanh(1.3 * tone) * env_adsr(n, 0.01, 1.2, dur, 0.1)


def noise(n, seed):
    return np.random.default_rng(seed).standard_normal(n)


def highpass(x, times=2):
    for _ in range(times):
        x = np.diff(x, prepend=x[0])
    return x


def kick(vel):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 46 + 90 * np.exp(-t / 0.035)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22)
    click = noise(n, 1) * np.exp(-t / 0.002) * 0.3
    return vel * (body + click)


def rim(vel, seed):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    snap = highpass(noise(n, seed), 1) * np.exp(-t / 0.045) * 0.5
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05) * 0.6
    return vel * (snap + body)


def hat(vel, seed, open_=False):
    n = int((0.25 if open_ else 0.08) * SR)
    t = np.arange(n) / SR
    return vel * highpass(noise(n, seed), 3) * np.exp(-t / (0.09 if open_ else 0.022)) * 0.35


def shaker(vel, seed):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    return vel * highpass(noise(n, seed), 2) * np.minimum(1, t / 0.012) * np.exp(-t / 0.04) * 0.25


# --------------------------------------------------------------------------- song renderer

class Song:
    def __init__(self, bpm, bars, seed):
        self.spb = 60 / bpm
        self.n = int(round(bars * 4 * self.spb * SR))
        self.music = np.zeros((2, self.n))
        self.drums = np.zeros((2, self.n))
        self.kick_env = np.zeros(self.n)
        self.rng = random.Random(seed)
        self.seed = seed

    def add(self, bus, beat, samples, pan=0.0):
        start = int((beat * self.spb + self.rng.uniform(-0.006, 0.006)) * SR) % self.n
        gl, gr = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        pos = 0
        while pos < len(samples):
            s = (start + pos) % self.n
            chunk = min(len(samples) - pos, self.n - s)
            bus[0, s:s + chunk] += samples[pos:pos + chunk] * gl
            bus[1, s:s + chunk] += samples[pos:pos + chunk] * gr
            pos += chunk

    def swing(self, beat, amount=0.09):
        return beat + amount if abs(beat % 1 - 0.5) < 1e-6 else beat

    def chords(self, bar0, progression, style):
        for i, bar in enumerate(progression):
            for (offset, root, voicing, length) in bar:
                b = (bar0 + i) * 4 + offset
                hits = [(0, min(1.4, length)), (2.5, min(1.2, length - 2.5))] if length >= 4 else [(0, length - 0.1)]
                if style == "pad":
                    hits = [(0, length - 0.05)]
                for h, d in hits:
                    vel = self.rng.uniform(0.85, 1.0) * (0.13 if h == 0 else 0.1)
                    for k, note in enumerate(voicing):
                        self.add(self.music, b + h + k * 0.018, epiano(hz(note), d * self.spb, vel),
                                 pan=-0.35 + 0.7 * k / max(1, len(voicing) - 1))
                self.bassline(b, root, length, bar, progression, i)

    def bassline(self, b, root, length, bar, progression, i):
        if length < 4:
            self.add(self.music, b, bass(hz(root), length * 0.8 * self.spb, 0.32))
            return
        self.add(self.music, b, bass(hz(root), 1.3 * self.spb, 0.34))
        self.add(self.music, b + 2.5, bass(hz(root + 7 if root + 7 < 55 else root - 5), 0.45 * self.spb, 0.24))
        nxt = progression[(i + 1) % len(progression)][0][1]
        approach = nxt - 1 if nxt > root else nxt + 2
        self.add(self.music, b + 3.5, bass(hz(approach), 0.4 * self.spb, 0.2))

    def melody(self, bar0, notes, voice, gain=1.0, transpose=0, pan=0.1):
        for beat, midi, dur in notes:
            b = self.swing((bar0 * 4) + beat, 0.06)
            vel = gain * self.rng.uniform(0.85, 1.0)
            self.add(self.music, b, voice(hz(midi + transpose), dur * self.spb, vel), pan=pan)

    def groove(self, bar0, bars, style):
        for bar in range(bars):
            b0 = (bar0 + bar) * 4
            seed = self.seed * 1000 + b0
            if style in ("full", "light"):
                for k in (0, 1.75, 2.5):
                    self.add(self.drums, b0 + k, kick(0.9 if k == 0 else 0.7))
                    self.kick_env[int((b0 + k) * self.spb * SR) % self.n] = 1
                for k in (1, 3):
                    self.add(self.drums, b0 + k, rim(0.55 if style == "full" else 0.4, seed + k), pan=-0.1)
            if style in ("full", "half"):
                for k in range(8):
                    beat = self.swing(k * 0.5)
                    vel = 0.5 if k % 2 == 0 else 0.32
                    self.add(self.drums, b0 + beat, hat(vel * self.rng.uniform(0.8, 1.1), seed + 10 + k,
                                                       open_=(k == 7 and bar % 4 == 3)), pan=0.3)
            if style == "half":
                self.add(self.drums, b0, kick(0.7))
                self.kick_env[int(b0 * self.spb * SR) % self.n] = 1
                self.add(self.drums, b0 + 3, rim(0.45, seed), pan=-0.1)
            if style == "soft":
                for k in (0, 2.5):
                    self.add(self.drums, b0 + k, kick(0.55))
                    self.kick_env[int((b0 + k) * self.spb * SR) % self.n] = 1
                self.add(self.drums, b0 + 3, rim(0.28, seed), pan=-0.1)
                for k in range(8):
                    self.add(self.drums, b0 + self.swing(k * 0.5),
                             shaker(0.35 if k % 2 else 0.5, seed + 20 + k), pan=0.35)

    def render(self):
        n = self.n
        # Gentle side-chain: chords and bass dip slightly under each kick.
        tail = np.exp(-np.arange(int(0.3 * SR)) / SR / 0.12)
        duck_env = np.real(np.fft.ifft(np.fft.fft(self.kick_env) * np.fft.fft(np.pad(tail, (0, n - len(tail))))))
        music = self.music * (1 - 0.22 * np.clip(duck_env, 0, 1))
        dry = music + self.drums
        wet = np.stack([self._reverb(music[c] + 0.3 * self.drums[c], seed=11 + c) for c in range(2)])
        mix = dry + 0.28 * wet * (np.max(np.abs(dry)) / max(np.max(np.abs(wet)), 1e-9))
        mix += self._vinyl()
        mix = np.stack([self._tone(mix[c]) for c in range(2)])
        mix = np.tanh(mix / np.max(np.abs(mix)) * 1.2)
        return mix / np.max(np.abs(mix)) * 0.85

    def _reverb(self, x, seed):
        n = self.n
        ir_len = int(2.6 * SR)
        t = np.arange(ir_len) / SR
        ir = np.convolve(noise(ir_len, seed), np.ones(32) / 32, mode="same") * np.exp(-t / 0.7)
        ir /= np.sqrt(np.sum(ir ** 2))
        return np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(np.pad(ir, (0, n - ir_len)))))

    def _tone(self, x):
        f = np.fft.rfftfreq(self.n, 1 / SR)
        gain = 1 / (1 + (f / 6500) ** 4) * (1 / (1 + (35 / np.maximum(f, 1)) ** 4))
        return np.fft.irfft(np.fft.rfft(x) * gain, n=self.n)

    def _vinyl(self):
        rng = np.random.default_rng(self.seed)
        crackle = np.zeros(self.n)
        idx = rng.integers(0, self.n, size=int(self.n / SR * 6))
        crackle[idx] = rng.uniform(-1, 1, size=len(idx))
        crackle = np.convolve(crackle, np.hanning(24), mode="same") * 0.02
        hiss = highpass(rng.standard_normal(self.n), 1) * 0.0015
        return np.stack([crackle + hiss, np.roll(crackle, 431) + hiss])


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
    print(f"wrote {out} ({song.n / SR:.1f}s, {os.path.getsize(out) // 1024} KB)")


# --------------------------------------------------------------------------- "Santai Pagi" (home)

def santai_pagi():
    Gm9, C9 = chord(43, [58, 62, 65, 69]), chord(48, [58, 62, 64, 67])
    Fmaj9, Dm9 = chord(41, [57, 60, 64, 67]), chord(50, [60, 64, 65, 69])
    Bbmaj7, Am7 = chord(46, [57, 62, 65, 69]), chord(45, [55, 60, 64, 67])
    Gm7, C7, Dm7 = chord(43, [53, 58, 62, 65]), chord(48, [58, 64, 67, 70]), chord(50, [53, 57, 60, 64])
    Gm7C7 = [(0, 43, [53, 58, 62, 65], 2), (2, 48, [58, 64, 67, 70], 2)]
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

    s = Song(bpm=82, bars=36, seed=1)
    s.chords(0, a_prog[:4], "pad")          # intro: keys only
    s.chords(4, a_prog, "comp"); s.melody(4, a1, kalimba, 0.5); s.groove(4, 8, "light")
    s.chords(12, a_prog, "comp"); s.melody(12, a2, kalimba, 0.5); s.groove(12, 8, "full")
    s.melody(12, a2, epiano, 0.1, transpose=-12, pan=-0.2)
    s.chords(20, b_prog, "comp"); s.melody(20, bridge, epiano, 0.28, pan=-0.1); s.groove(20, 8, "half")
    s.chords(28, a_prog, "comp"); s.melody(28, a3, kalimba, 0.5); s.groove(28, 8, "full")
    return s


# --------------------------------------------------------------------------- "Santai Petang" (in game)

def santai_petang():
    Cmaj9, Em7 = chord(48, [52, 55, 59, 62]), chord(40, [55, 59, 62, 64])
    Am9, Fmaj9 = chord(45, [55, 59, 60, 64]), chord(41, [52, 55, 57, 60])
    Dm9, G9sus = chord(50, [53, 57, 60, 64]), chord(43, [53, 57, 60, 62])
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

    s = Song(bpm=70, bars=28, seed=2)
    s.chords(0, a_prog[:4], "pad")
    s.chords(4, a_prog, "comp"); s.melody(4, theme, epiano, 0.3, pan=0.15); s.groove(4, 8, "soft")
    s.chords(12, b_prog, "comp"); s.melody(12, bridge, kalimba, 0.42); s.groove(12, 8, "soft")
    s.chords(20, a_prog, "comp"); s.melody(20, theme, kalimba, 0.42); s.groove(20, 8, "soft")
    s.melody(20, theme, epiano, 0.08, transpose=-12, pan=-0.2)
    return s


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write(santai_pagi(), "music_home")
    write(santai_petang(), "music_game")
