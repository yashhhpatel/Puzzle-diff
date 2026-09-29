"""Synthesizes the game's sound effects into assets/sfx as 16-bit mono WAVs.

Run: python tool/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.85 / peak
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def env(t, a, d):
    if t < a:
        return t / a
    return math.exp(-(t - a) / d)


def tone(freq_fn, dur, a=0.004, d=0.08, harmonics=((1, 1.0),)):
    out = []
    phase = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        f = freq_fn(t)
        phase += 2 * math.pi * f / SR
        s = sum(amp * math.sin(phase * h) for h, amp in harmonics)
        out.append(s * env(t, a, d))
    return out


def mix(*tracks):
    n = max(len(t) for t, _ in tracks)
    out = [0.0] * n
    for t, off in tracks:
        o = int(off * SR)
        for i, s in enumerate(t):
            if o + i < n:
                out[o + i] += s
            else:
                out.append(s)
                n += 1
    return out


def pad(track, total):
    return track + [0.0] * max(0, int(total * SR) - len(track))


# Gem group lifted: quick rising glassy pop.
write('pick.wav', tone(lambda t: 520 + 2600 * t, 0.12, d=0.05, harmonics=((1, 1), (2, 0.35), (3, 0.15))))

# Single gem landing in a cell: short crystal tick.
write('drop.wav', tone(lambda t: 1500 - 1200 * t, 0.09, a=0.001, d=0.025, harmonics=((1, 1), (2.7, 0.4), (5.1, 0.2))))

# Gem landing on the shelf: softer, lower tick.
write('shelf.wav', tone(lambda t: 900 - 400 * t, 0.08, a=0.001, d=0.02, harmonics=((1, 1), (2.4, 0.3))))

# Row/region sparkle when a block completes.
sparkle = mix(*[(tone(lambda t, f=f: f, 0.35, d=0.12, harmonics=((1, 1), (2, 0.3))), i * 0.05)
                for i, f in enumerate([1318, 1568, 1976, 2637])])
write('sparkle.wav', sparkle)

# Level complete fanfare (C major arpeggio + chord).
notes = [523.25, 659.25, 783.99, 1046.5]
fan = mix(*[(tone(lambda t, f=f: f, 0.5, d=0.18, harmonics=((1, 1), (2, 0.4), (3, 0.2))), i * 0.09) for i, f in enumerate(notes)],
          *[(tone(lambda t, f=f: f, 1.0, d=0.45, harmonics=((1, 1), (2, 0.3))), 0.4) for f in notes])
write('complete.wav', fan)

# Coin collect: two-tone bling.
write('coin.wav', mix((tone(lambda t: 1975, 0.08, d=0.04, harmonics=((1, 1), (3, 0.2))), 0),
                      (tone(lambda t: 2637, 0.25, d=0.09, harmonics=((1, 1), (3, 0.2))), 0.06)))

# UI button tap.
write('click.wav', tone(lambda t: 700 - 300 * t, 0.06, a=0.001, d=0.018, harmonics=((1, 1), (2, 0.5))))

# Invalid move: low wobble buzz.
write('error.wav', tone(lambda t: 180 + 25 * math.sin(t * 60), 0.22, d=0.1, harmonics=((1, 1), (2, 0.5), (3, 0.3))))

# Popup whoosh: filtered noise sweep.
random.seed(3)
wh = []
lp = 0.0
for i in range(int(0.25 * SR)):
    t = i / SR
    k = 0.02 + 0.25 * (t / 0.25)
    lp += k * (random.uniform(-1, 1) - lp)
    wh.append(lp * math.sin(math.pi * t / 0.25))
write('whoosh.wav', wh)

# Background music: gentle looping arpeggio (8 bars).
prog = [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]] * 2
beat = 0.25
tracks = []
for bar, chord in enumerate(prog):
    for step in range(8):
        f = chord[step % 3] * (2 if step >= 4 else 1)
        tracks.append((tone(lambda t, f=f: f, 0.6, a=0.01, d=0.2, harmonics=((1, 1), (2, 0.25))), (bar * 8 + step) * beat))
    tracks.append((tone(lambda t, f=chord[0] / 2: f, 2.0, a=0.05, d=0.8, harmonics=((1, 1),)), bar * 8 * beat))
music = pad(mix(*tracks), len(prog) * 8 * beat)[: int(len(prog) * 8 * beat * SR)]
write('music.wav', [s * 0.5 for s in music])
print('ok')
