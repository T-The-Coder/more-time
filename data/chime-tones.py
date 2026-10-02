#!/usr/bin/env python3
"""The chime tones of More Time, written as WAV files (44.1 kHz, mono, 16 bit).

    chime-tones.py <folder> [tone ...]

writes chime-<tone>-interval.wav and chime-<tone>-hour.wav for each tone
(all five when none is named) that is not there yet. The hour tone is a
fifth below the interval tone. Only the standard library is used; files are
written to a temporary name and renamed, so two instances never see half a
file.
"""
import math
import os
import struct
import sys
import wave

RATE = 44100
TWO_PI = 2 * math.pi

# tone: (interval pitch in Hz, length in seconds)
TONES = {
    "beep": (880.0, 0.12),    # a pure sine
    "bell": (660.0, 0.35),    # sine with decaying harmonics
    "wood": (1046.5, 0.13),   # marimba-like: triangle-ish, very fast decay
    "chirp": (1000.0, 0.11),  # a short upward sweep
    "glass": (1760.0, 0.25),  # high, two close partials beating
}


def sample(tone, f, t, length):
    def fade(attack, release):
        return max(0.0, min(1.0, t / attack, (length - t) / release))

    if tone == "bell":
        partials = ((1.0, 1.0, 0.12), (2.0, 0.5, 0.07), (3.0, 0.25, 0.04))
        return fade(0.005, 0.03) * sum(a * math.exp(-t / d) * math.sin(TWO_PI * f * m * t) for m, a, d in partials)
    if tone == "wood":
        # The first odd harmonics of a triangle wave, plus the bar's 4th partial.
        body = math.sin(TWO_PI * f * t) - math.sin(TWO_PI * 3 * f * t) / 9 + math.sin(TWO_PI * 5 * f * t) / 25
        return fade(0.002, 0.01) * math.exp(-t / 0.025) * (body + 0.2 * math.sin(TWO_PI * 4 * f * t))
    if tone == "chirp":
        low, high = 0.75 * f, 1.3 * f
        phase = TWO_PI * (low * t + (high - low) * t * t / (2 * length))
        return fade(0.005, 0.015) * math.sin(phase)
    if tone == "glass":
        return fade(0.003, 0.02) * math.exp(-t / 0.1) * (
            math.sin(TWO_PI * f * t) + math.sin(TWO_PI * f * 1.007 * t) + 0.3 * math.sin(TWO_PI * f * 2.76 * t))
    return fade(0.01, 0.01) * math.sin(TWO_PI * f * t)


def write(path, tone, f, length):
    n = int(RATE * length)
    values = [sample(tone, f, i / RATE, length) for i in range(n)]
    peak = max(abs(v) for v in values) or 1.0
    frames = b"".join(struct.pack("<h", int(0.6 * 32767 * v / peak)) for v in values)
    temp = "%s.%d" % (path, os.getpid())
    with wave.open(temp, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)
    os.replace(temp, path)


def main(argv):
    folder = argv[1]
    tones = [t for t in argv[2:] if t in TONES] or list(TONES)
    os.makedirs(folder, exist_ok=True)
    for tone in tones:
        pitch, length = TONES[tone]
        for role, f in (("interval", pitch), ("hour", pitch * 2 / 3)):
            path = os.path.join(folder, "chime-%s-%s.wav" % (tone, role))
            if os.path.isfile(path) and os.path.getsize(path) > 44:
                continue
            write(path, tone, f, length)


if __name__ == "__main__":
    main(sys.argv)
