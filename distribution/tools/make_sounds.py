#!/usr/bin/env python3
"""Synthesise the app's feedback sounds, one set per look.

    python3 distribution/tools/make_sounds.py

Writes App/Resources/Sounds/<sound>-<theme>.wav (16-bit mono, 44.1 kHz).
Midnight Den: square-wave chiptune. Gilded Atelier: plucked strings (Karplus-Strong) and a soft bell.
The canvas engine's sfx() plays the same notes with WebAudio.
"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'App', 'Resources', 'Sounds')

# (frequency Hz, start s, length s) per sound; shared by both looks so they feel related.
NOTES = {
    'correct': [(880, 0, .12), (1320, .08, .18)],
    'gentle':  [(392, 0, .22), (330, .12, .30)],
    'levelup': [(523, 0, .14), (659, .10, .14), (784, .20, .14), (1047, .30, .40)],
    'shiny':   [(1319, 0, .10), (1760, .07, .10), (2093, .14, .30)],
    'bell':    [(988, 0, .9), (1319, .18, .9)],
    'tap':     [(660, 0, .05)],
}

def env(n, attack=.004, release=None):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    r = np.exp(-t / (release or (n / SR) / 3))
    return a * r

def square(f, length, duty=.25):
    n = int(length * SR); t = np.arange(n) / SR
    wave_ = np.where((t * f) % 1 < duty, 1.0, -1.0)
    wave_ = np.round(wave_ * 7) / 7          # 4-bit-ish steps
    return wave_ * env(n, .002, length / 2.5) * .22

def pluck(f, length):
    n = int(length * SR); period = max(2, int(SR / f))
    rng = np.random.default_rng(int(f))
    buf = rng.uniform(-1, 1, period); out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = .5 * (buf[i % period] + buf[(i + 1) % period]) * .996
    return out * env(n, .001, length / 2) * .35

def soft_bell(f, length):
    n = int(length * SR); t = np.arange(n) / SR
    partials = [(1, 1), (2.76, .35), (5.40, .15), (8.93, .06)]   # inharmonic, like a small bell
    s = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * (2.2 + r)) for r, a in partials)
    return s * env(n, .003, length) * .25

def render(theme, sound):
    notes = NOTES[sound]
    total = max(s + l for _, s, l in notes) + .05
    out = np.zeros(int(total * SR))
    for f, start, length in notes:
        if theme == 'den':
            v = square(f, length, .125 if sound in ('shiny', 'tap') else .25)
        else:
            v = soft_bell(f, length) if sound in ('bell', 'shiny') else pluck(f, length)
        i = int(start * SR); out[i:i + len(v)] += v
    peak = np.max(np.abs(out)) or 1
    return (out / peak * .7 * 32767).astype('<i2')

def main():
    os.makedirs(OUT, exist_ok=True)
    for theme in ('den', 'atelier'):
        for sound in NOTES:
            path = os.path.join(OUT, f'{sound}-{theme}.wav')
            with wave.open(path, 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
                w.writeframes(render(theme, sound).tobytes())
            print(os.path.relpath(path))

if __name__ == '__main__':
    main()
