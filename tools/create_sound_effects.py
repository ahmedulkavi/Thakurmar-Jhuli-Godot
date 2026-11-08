"""Create the game's short original sound effects. Requires NumPy."""
from pathlib import Path
import wave

import numpy as np

RATE = 32000
rng = np.random.default_rng(1427)
out = Path('assets/sfx')
out.mkdir(parents=True, exist_ok=True)


def times(duration):
    return np.arange(round(duration * RATE)) / RATE


def tone(t, start, end):
    duration = max(t[-1], 1 / RATE)
    return np.sin(2 * np.pi * (start * t + (end - start) * t * t / (2 * duration)))


def noise(t, smooth=1):
    x = rng.standard_normal(len(t))
    return np.convolve(x, np.ones(smooth) / smooth, mode='same') if smooth > 1 else x


def bell(t, frequency, start=0.0, decay=5.0):
    x = np.maximum(t - start, 0)
    envelope = np.exp(-decay * x) * np.minimum(x / 0.009, 1) * (t >= start)
    return envelope * (np.sin(2 * np.pi * frequency * x) + 0.33 * np.sin(2 * np.pi * frequency * 2.76 * x))


def save(name, sound):
    sound = sound / max(np.max(np.abs(sound)), 1e-6) * 0.78
    # A short fade guarantees silent edges, even for resonant effects.
    fade = min(round(0.008 * RATE), len(sound) // 2)
    sound[:fade] *= np.linspace(0, 1, fade)
    sound[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(out / (name + '.wav')), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype('<i2').tobytes())


t = times(0.23)
env = np.sin(np.pi * t / t[-1]) ** 1.5
save('jump', env * (0.55 * tone(t, 230, 410) + 0.40 * noise(t, 12)))

t = times(0.19)
save('land', np.exp(-t * 24) * (tone(t, 150, 62) + 0.55 * noise(t, 8)))

t = times(0.28)
env = np.sin(np.pi * t / t[-1]) ** 2
save('swing', env * (noise(t, 4) - noise(t, 18)) + 0.12 * env * tone(t, 740, 280))

t = times(0.30)
save('hit', 0.8 * np.exp(-t * 30) * noise(t, 3) + 0.8 * bell(t, 780, decay=18) + 0.35 * bell(t, 1270, decay=15))

t = times(0.32)
save('hurt', np.exp(-t * 13) * (0.7 * tone(t, 180, 75) + 0.75 * noise(t, 7)))

t = times(0.50)
save('counter', np.exp(-t * 23) * noise(t, 3) + 0.9 * bell(t, 680, decay=8) + 0.55 * bell(t, 1040, decay=11))

t = times(0.85)
save('item', bell(t, 660, 0.0, 5) + bell(t, 830, 0.10, 5) + bell(t, 990, 0.20, 4) + 0.5 * bell(t, 1320, 0.32, 5))

t = times(0.32)
save('essence', bell(t, 1050, decay=12) + 0.5 * bell(t, 1575, 0.04, 11))

t = times(0.75)
save('heal', bell(t, 440, 0.0, 4) + bell(t, 660, 0.12, 4) + bell(t, 880, 0.24, 4) + 0.25 * np.sin(2 * np.pi * 190 * t) * np.sin(np.pi * t / t[-1]))

t = times(0.45)
save('stance', bell(t, 540, 0.0, 8) + 0.6 * bell(t, 810, 0.07, 7) + 0.2 * noise(t, 6) * np.exp(-t * 15))

# Soft turf compresses and rustles; wood gives a hollow knock; stone is sharper.
t = times(0.27)
thud = tone(t, 105, 54) * np.exp(-t * 17)
rustle = noise(t, 11) * np.exp(-((t - 0.055) / 0.055) ** 2)
soft_squelch = tone(t, 240, 115) * np.exp(-((t - 0.045) / 0.045) ** 2)
save('land_grass', 0.8 * thud + 0.5 * rustle + 0.12 * soft_squelch)

t = times(0.22)
save('land_wood', np.exp(-t * 21) * (0.8 * tone(t, 220, 120) + 0.4 * np.sin(2 * np.pi * 370 * t) + 0.3 * noise(t, 6)))

t = times(0.22)
save('land_stone', np.exp(-t * 27) * (0.55 * tone(t, 195, 85) + 0.65 * noise(t, 3)) + 0.3 * bell(t, 1100, decay=25))
print('Generated 13 sound effects in', out)
