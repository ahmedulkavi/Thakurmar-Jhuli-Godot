"""Render Shakchunni's original, looping boss theme. Requires NumPy."""
from pathlib import Path
import wave

import numpy as np

RATE = 32000
BEAT = 0.5  # 120 BPM
BARS = 32
LENGTH = round(BARS * 4 * BEAT * RATE)
SECONDS = LENGTH / RATE
rng = np.random.default_rng(8287)
mix = np.zeros((2, LENGTH), dtype=np.float32)


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def add(sound, when, pan, level):
    start = round(when * RATE) % LENGTH
    pos = 0
    while pos < len(sound):
        count = min(len(sound) - pos, LENGTH - start)
        part = sound[pos:pos + count] * level
        mix[0, start:start + count] += part * np.sqrt((1 - pan) / 2)
        mix[1, start:start + count] += part * np.sqrt((1 + pan) / 2)
        pos += count
        start = 0


def plucked(note, duration=1.0):
    # A bright, buzzing, decaying string with a few inharmonic sympathetic tones.
    t = np.arange(round(RATE * duration), dtype=np.float32) / RATE
    phase = 2 * np.pi * hz(note) * t
    envelope = np.minimum(t / .009, 1) * np.exp(-t * 3.1)
    string = np.sin(phase) + .45 * np.sin(2 * phase) * np.exp(-t * 2)
    string += .27 * np.sin(3.01 * phase) * np.exp(-t * 3)
    string += .12 * np.sin(5.02 * phase) * np.exp(-t * 4)
    return envelope * string


def tabla(low=False):
    t = np.arange(round(RATE * .34), dtype=np.float32) / RATE
    if low:
        phase = 2 * np.pi * (72 * t + 3.8 * (1 - np.exp(-t * 25)))
        tone = np.sin(phase) * np.exp(-t * 10)
    else:
        tone = (np.sin(2 * np.pi * 205 * t) + .45 * np.sin(2 * np.pi * 325 * t)) * np.exp(-t * 18)
    click = rng.standard_normal(len(t)).astype(np.float32) * np.exp(-t * 75) * .23
    return (tone + click) * np.minimum(t / .004, 1)


def reed(note, duration):
    # Bowed, nasal lead with a slow pitch glide and vibrato.
    t = np.arange(round(RATE * (duration + .15)), dtype=np.float32) / RATE
    glide = -.045 * np.exp(-t * 10) + .003 * np.sin(2 * np.pi * 5.4 * t)
    phase = np.cumsum((2 * np.pi * hz(note) / RATE) * (1 + glide))
    tone = np.sin(phase) + .43 * np.sin(2 * phase) + .18 * np.sin(3 * phase) + .09 * np.sin(4 * phase)
    attack = np.minimum(t / .07, 1)
    release = np.clip((duration + .15 - t) / .18, 0, 1)
    return tone * attack * release


# Sustained tanpura-like D/A drone, tuned to an exact number of loop cycles.
t = np.arange(LENGTH, dtype=np.float32) / RATE
for note, level, pan in [(38, .105, -.38), (45, .07, .32), (50, .035, 0)]:
    frequency = round(hz(note) * SECONDS) / SECONDS
    phase = 2 * np.pi * frequency * t
    pulse = .73 + .15 * np.sin(2 * np.pi * t / (SECONDS / 4) + note)
    add((np.sin(phase) + .22 * np.sin(2 * phase) + .1 * np.sin(3 * phase)) * pulse, 0, pan, level)

# Original melody using a dark D-centered scale and short answered phrases.
melodies = [
    [(0, 62, .7), (.8, 63, .4), (1.35, 65, .5), (2.1, 69, .85), (3.2, 67, .6)],
    [(0, 65, .6), (.75, 63, .45), (1.3, 62, .8), (2.35, 60, .5), (3.0, 62, .7)],
    [(0, 69, .6), (.7, 70, .45), (1.25, 72, .75), (2.2, 70, .45), (2.9, 69, .8)],
    [(0, 67, .55), (.7, 65, .5), (1.35, 63, .6), (2.1, 62, 1.4)],
    [(0, 74, .65), (.8, 72, .45), (1.4, 70, .5), (2.1, 69, .8), (3.15, 67, .55)],
    [(0, 65, .55), (.75, 67, .4), (1.3, 69, .9), (2.5, 65, .45), (3.05, 63, .7)],
    [(0, 62, .55), (.7, 65, .45), (1.3, 67, .6), (2.1, 70, .55), (2.8, 69, .8)],
    [(0, 67, .5), (.65, 65, .4), (1.2, 63, .45), (1.8, 62, 1.6)],
]
ostinato = [50, 57, 62, 63, 57, 53, 55, 57]
for bar in range(BARS):
    for beat, note, duration in melodies[bar % len(melodies)]:
        add(reed(note, duration * BEAT), (bar * 4 + beat) * BEAT, -.15, .075 if bar % 16 < 8 else .09)
    for step in range(8):
        note = ostinato[(step + (bar % 4) * 2) % len(ostinato)]
        add(plucked(note, .65), (bar * 4 + step * .5) * BEAT, .36, .08 if step % 2 == 0 else .055)
    for step, low, level in [(0, True, .21), (.75, False, .095), (1.5, False, .08), (2, True, .15), (2.5, False, .10), (3.25, False, .085), (3.5, True, .10)]:
        add(tabla(low), (bar * 4 + step) * BEAT, -.18 if low else .22, level)
    if bar % 4 == 3:
        for step in [3.0, 3.5, 3.75]:
            add(tabla(False), (bar * 4 + step) * BEAT, .25, .085)

# Circular delay keeps the ringing strings continuous across the loop.
dry = mix.copy()
for delay, gain in [(.19, .10), (.38, .08), (.71, .06), (1.13, .035)]:
    shift = round(delay * RATE)
    mix[0] += np.roll(dry[1], shift) * gain
    mix[1] += np.roll(dry[0], shift + 91) * gain
mix *= .78 / max(float(np.max(np.abs(mix))), .001)
pcm = (np.clip(mix.T, -1, 1) * 32767).astype('<i2')
Path('artifacts').mkdir(exist_ok=True)
with wave.open('artifacts/shakchunni-music-render.wav', 'wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(pcm.tobytes())
print(f'Rendered {SECONDS:.2f} seconds')
