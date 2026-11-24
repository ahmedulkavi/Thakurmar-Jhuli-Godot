"""Render short original bow and dodge sounds without external packages."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 32000
OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
random.seed(42)


def save(name, duration, sample):
    values = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        edge = min(1.0, t / 0.006, (duration - t) / 0.012)
        values.append(max(-1.0, min(1.0, sample(t) * edge)) * 25000)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(struct.pack(f"<{len(values)}h", *map(int, values)))


save("hunter_bow", 0.23, lambda t: math.exp(-t * 23) * (
    0.72 * math.sin(2 * math.pi * (380 * t - 650 * t * t))
    + 0.28 * random.uniform(-1, 1)))
save("hunter_roll", 0.34, lambda t: math.sin(math.pi * t / 0.34) ** 1.5 * (
    0.58 * random.uniform(-1, 1)
    + 0.35 * math.sin(2 * math.pi * (125 * t - 85 * t * t))))
