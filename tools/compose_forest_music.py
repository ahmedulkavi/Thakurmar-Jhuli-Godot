"""Render the original, circular forest music bed to a stereo WAV.

Requires NumPy. Encode the result as Ogg Vorbis for Godot after rendering.
"""
import wave
from pathlib import Path

import numpy as np

RATE = 32000
BEAT = 60.0 / 72.0
BARS = 16
LENGTH = round(BARS * 4 * BEAT * RATE)
SECONDS = LENGTH / RATE
rng = np.random.default_rng(3721)
mix = np.zeros((2, LENGTH), dtype=np.float32)


def pitch(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def add(samples, start, pan=0.0, gain=1.0):
    """Wrap tails across the loop point so releases and echoes continue naturally."""
    start = round(start * RATE) % LENGTH
    left = gain * np.sqrt((1 - pan) / 2)
    right = gain * np.sqrt((1 + pan) / 2)
    remaining = len(samples)
    offset = 0
    while remaining:
        count = min(remaining, LENGTH - start)
        mix[0, start:start + count] += samples[offset:offset + count] * left
        mix[1, start:start + count] += samples[offset:offset + count] * right
        remaining -= count
        offset += count
        start = 0


def flute(note, duration, velocity=1.0):
    t = np.arange(round((duration + 0.32) * RATE), dtype=np.float32) / RATE
    vibrato = 0.004 * np.sin(2 * np.pi * 5.1 * t) * np.minimum(t / 0.35, 1)
    phase = 2 * np.pi * pitch(note) * (t + vibrato / (2 * np.pi * 5.1))
    tone = np.sin(phase) + 0.17 * np.sin(2 * phase + 0.4) + 0.05 * np.sin(3 * phase)
    breath = rng.standard_normal(len(t)).astype(np.float32)
    breath = np.convolve(breath, np.ones(9, dtype=np.float32) / 9, mode='same')
    attack = np.clip(t / 0.16, 0, 1)
    release = np.clip((duration + 0.32 - t) / 0.32, 0, 1)
    return (tone * 0.95 + breath * 0.09) * attack * release * velocity


def pluck(note, duration):
    t = np.arange(round(duration * RATE), dtype=np.float32) / RATE
    f = pitch(note)
    phase = 2 * np.pi * f * t
    sound = (np.sin(phase) * np.exp(-t * 1.6)
             + 0.44 * np.sin(phase * 2.01) * np.exp(-t * 4.1)
             + 0.19 * np.sin(phase * 3.02) * np.exp(-t * 7.0))
    return sound * np.minimum(t / 0.012, 1)


def drum(high=False):
    t = np.arange(round(0.65 * RATE), dtype=np.float32) / RATE
    f = 165 if high else 84
    phase = 2 * np.pi * (f * t + (115 if high else 75) * 0.03 * (1 - np.exp(-t / 0.03)))
    noise = rng.standard_normal(len(t)).astype(np.float32)
    return (np.sin(phase) * np.exp(-t * (11 if high else 7))
            + noise * 0.13 * np.exp(-t * 30)) * np.minimum(t / 0.006, 1)


# Slowly moving D and A drone; all oscillators complete whole cycles per loop.
t = np.arange(LENGTH, dtype=np.float32) / RATE
for note, level, pan in [(38, 0.10, -0.25), (45, 0.065, 0.25), (50, 0.035, -0.05)]:
    frequency = round(pitch(note) * SECONDS) / SECONDS
    phase = 2 * np.pi * frequency * t
    drift = 0.72 + 0.16 * np.cos(2 * np.pi * t / SECONDS + note)
    pad = (np.sin(phase) + 0.18 * np.sin(phase * 2)) * drift
    add(pad, 0, pan, level)

# A restrained D minor melody, written independently for the forest.
phrases = [
    [(0, 62, 1.4), (1.75, 65, .8), (2.8, 69, 1.0)],
    [(0.35, 72, .7), (1.2, 69, .9), (2.45, 65, 1.2)],
    [(0.15, 67, 1.1), (1.55, 65, .6), (2.5, 62, 1.15)],
    [(0.35, 60, .75), (1.4, 62, 1.7)],
    [(0, 62, .8), (1.0, 65, .7), (2.0, 69, 1.5)],
    [(0.3, 74, 1.0), (1.6, 72, .75), (2.6, 69, 1.0)],
    [(0.2, 70, .9), (1.4, 69, .7), (2.4, 65, 1.2)],
    [(0.4, 64, .8), (1.6, 62, 1.7)],
]
for bar in range(BARS):
    phrase = phrases[bar % 8]
    for beat, note, duration in phrase:
        start = (bar * 4 + beat) * BEAT
        add(flute(note, duration * BEAT), start, -0.18, 0.105 if bar < 8 else 0.115)
    root = [50, 46, 48, 45, 50, 46, 43, 45][bar % 8]
    for step, interval in [(0, 0), (1.5, 7), (2.5, 12), (3.25, 7)]:
        add(pluck(root + interval, 2.0), (bar * 4 + step) * BEAT, 0.35, 0.07)
    for step, high, gain in [(0, False, 0.13), (1.5, True, 0.05), (2.0, False, 0.085), (3.25, True, 0.045)]:
        add(drum(high), (bar * 4 + step) * BEAT, -0.15 if high else 0, gain)

# Circular, stereo echoes preserve the ambience across the loop boundary.
dry = mix.copy()
for delay, gain in [(0.31, 0.13), (0.57, 0.09), (1.03, 0.055), (1.61, 0.035)]:
    shift = round(delay * RATE)
    mix[0] += np.roll(dry[1], shift) * gain
    mix[1] += np.roll(dry[0], shift + 113) * gain
mix *= 0.76 / max(float(np.max(np.abs(mix))), 0.001)
pcm = (np.clip(mix.T, -1, 1) * 32767).astype('<i2')
Path('artifacts').mkdir(exist_ok=True)
with wave.open('artifacts/forest-music-render.wav', 'wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(pcm.tobytes())
print(f'Rendered {SECONDS:.2f} seconds')
