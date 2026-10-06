"""Procedural sound effects for Archeoblocks.

Every sound is synthesized from scratch by this script (no samples), so the
output is original work of the project. Re-run to regenerate:
    python tools/generate_sfx.py
Requires numpy + scipy. Writes 16-bit mono WAV files to assets/audio/sfx/.
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(7)


def t_axis(duration):
    return np.arange(int(SR * duration)) / SR


def env(duration, attack=0.004, decay=8.0):
    t = t_axis(duration)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    return a * np.exp(-decay * t)


def bell(freq, duration, decay=6.0, bright=0.35):
    t = t_axis(duration)
    tone = np.sin(2 * np.pi * freq * t)
    tone += bright * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-3 * t)
    tone += 0.18 * np.sin(2 * np.pi * freq * 3.02 * t) * np.exp(-6 * t)
    return tone * env(duration, 0.003, decay)


def noise(duration):
    return rng.standard_normal(int(SR * duration))


def band(x, low, high):
    b, a = butter(2, [low / (SR / 2), high / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def lowpass(x, cutoff):
    b, a = butter(2, cutoff / (SR / 2), btype="low")
    return lfilter(b, a, x)


def place_at(total, clip, start):
    begin = int(start * SR)
    end = min(len(total), begin + len(clip))
    total[begin:end] += clip[: end - begin]


def canvas(duration):
    return np.zeros(int(SR * duration))


def note(n):  # MIDI note -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def save(name, x, peak_db=-6.0):
    x = x - np.mean(x)
    fade = min(len(x), int(0.004 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * (10 ** (peak_db / 20))
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def main():
    os.makedirs(OUT, exist_ok=True)

    # Soft UI tick.
    d = 0.05
    x = 0.6 * np.sin(2 * np.pi * 1500 * t_axis(d)) * env(d, 0.001, 90)
    x += 0.3 * band(noise(d), 2000, 6000) * env(d, 0.001, 120)
    save("ui_click", x, -12)

    # Piece picked up: short rising blip.
    d = 0.08
    t = t_axis(d)
    x = np.sin(2 * np.pi * (520 + 1800 * t) * t) * env(d, 0.002, 40)
    save("pick", x, -14)

    # Piece placed: low stone knock.
    d = 0.16
    t = t_axis(d)
    x = np.sin(2 * np.pi * (170 - 200 * t) * t) * env(d, 0.001, 32)
    x += 0.5 * band(noise(d), 300, 1800) * env(d, 0.001, 70)
    save("place", x, -9)

    # Cannot place: two soft low pulses.
    d = 0.26
    x = canvas(d)
    pulse = lowpass(np.sign(np.sin(2 * np.pi * 150 * t_axis(0.09))), 900) * env(0.09, 0.004, 30)
    place_at(x, pulse, 0.0)
    place_at(x, pulse * 0.8, 0.12)
    save("invalid", x, -14)

    # One line cleared: bright major arpeggio.
    d = 0.5
    x = canvas(d)
    for i, n in enumerate([84, 88, 91]):
        place_at(x, bell(note(n), 0.4, 7), i * 0.045)
    save("line_clear", x, -8)

    # Several lines: wider arpeggio with shimmer.
    d = 0.8
    x = canvas(d)
    for i, n in enumerate([79, 84, 88, 91, 96]):
        place_at(x, bell(note(n), 0.6, 6), i * 0.05)
    x += 0.15 * band(noise(d), 5000, 12000) * env(d, 0.05, 5)
    save("line_clear_multi", x, -7)

    # Soil removed: crumbly brown noise.
    d = 0.2
    grains = canvas(d)
    for i in range(7):
        place_at(grains, lowpass(noise(0.03), 1200) * env(0.03, 0.001, 90), rng.uniform(0, 0.14))
    save("dig", grains, -13)

    # Stone hit: crack + thump.
    d = 0.25
    x = band(noise(d), 1500, 7000) * env(d, 0.001, 45)
    x += 0.8 * np.sin(2 * np.pi * 95 * t_axis(d)) * env(d, 0.001, 25)
    save("stone_hit", x, -9)

    # Stone destroyed: several cracks falling apart.
    d = 0.5
    x = canvas(d)
    for i in range(6):
        crack = band(noise(0.12), 800 + 400 * i, 6000) * env(0.12, 0.001, 35)
        place_at(x, crack, i * 0.055)
    x += 0.7 * np.sin(2 * np.pi * 80 * t_axis(d)) * env(d, 0.001, 12)
    save("stone_break", x, -8)

    # Root cut: quick swish.
    d = 0.2
    t = t_axis(d)
    swish = noise(d)
    b, a = butter(2, [0.05, 0.4], btype="band")
    x = lfilter(b, a, swish) * np.sin(np.pi * t / d) ** 2
    save("root_cut", x, -11)

    # Root grows: low creak with wobble.
    d = 0.4
    t = t_axis(d)
    freq = 110 + 25 * np.sin(2 * np.pi * 9 * t)
    x = np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(d, 0.05, 5)
    x += 0.25 * lowpass(noise(d), 600) * env(d, 0.05, 6)
    save("root_grow", x, -13)

    # Fragment found: ascending pentatonic sparkle.
    d = 1.0
    x = canvas(d)
    for i, n in enumerate([79, 81, 84, 86, 88, 91]):
        place_at(x, bell(note(n), 0.5, 7, 0.5), i * 0.07)
    x += 0.12 * band(noise(d), 6000, 14000) * env(d, 0.1, 4)
    save("fragment_found", x, -7)

    # Expedition complete: short fanfare + chord.
    d = 1.8
    x = canvas(d)
    for i, n in enumerate([72, 76, 79, 84]):
        place_at(x, bell(note(n), 0.5, 5, 0.4), i * 0.13)
    for n in [72, 76, 79, 84, 88]:
        place_at(x, 0.6 * bell(note(n), 1.2, 2.5, 0.3), 0.55)
    save("victory", x, -6)

    # No moves left: gentle falling two-note.
    d = 0.8
    x = canvas(d)
    place_at(x, bell(note(67), 0.45, 5, 0.2), 0.0)
    place_at(x, bell(note(62), 0.6, 4, 0.2), 0.22)
    save("no_moves", x, -10)


if __name__ == "__main__":
    main()
