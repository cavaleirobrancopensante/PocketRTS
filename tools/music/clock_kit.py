"""The Clockwork's own sounds as instruments (used by clock_more.py).

The owner sent eight recordings for the Clockwork (art/audio_src/clockwork/, SOURCES.txt). Like the
snare solos under the Crown's marches, single hits are cut from them here and played on the grid as
percussion and texture, so the music is made of the faction's own clocks and machines:

  drums (synth.DRUMS codes)
    o  alarm clock tick (the light one)          O  alarm clock tock (the heavy one)
    I  a burst of the alarm ringing (a rattle)   L  the old clock bell, struck once, as recorded
    C  metal clang 1 (an anvil)                  Q  metal clang 2      U  metal clang 3
    v  typewriter key                            V  typewriter key, heavier      f  typewriter key, light
    g  the typewriter's bell                     R  a run of typewriter keys (a rattle)
    n  one turn of the old crank (a ratchet)     Z  the spring scrape and its long resonance
    X  a burst of metallic noise                 u  the wobble (a sprung sheet of metal)

  pitched instruments (synth.INSTRUMENTS: the recording resampled to the note)
    clockbell   the old clock bell (its hum at 326 Hz is taken as E4)
    tinebell    the typewriter's bell (3445 Hz, taken as A7), played down in the staff: a small glassy bell
    springres   the spring's resonance (562 Hz, C#5), without its scrape: a bowed-metal drone

The hits are found by their onsets (checked with numpy, see docs/music_clockwork.md) and normalised.
"""
import os
import subprocess

import numpy as np

import synth
from synth import SR, _highpass, _lowpass

SRC = os.path.join(os.path.dirname(__file__), "..", "..", "art", "audio_src", "clockwork")
_raw = {}


def _load(name):
    if name not in _raw:
        out = subprocess.run(["ffmpeg", "-v", "quiet", "-i", os.path.join(SRC, name + ".mp3"),
                              "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True).stdout
        _raw[name] = np.frombuffer(out, dtype=np.float32).astype(float)
    return _raw[name]


def _cut(name, t0, t1, fade_in=0.002, fade_out=0.04, hp=None, lp=None, peak=0.8, onset=True):
    """A slice of a recording; with onset=True t0 is moved to the attack found within 60 ms."""
    x = _load(name)
    i0, i1 = int(t0 * SR), int(t1 * SR)
    if onset:
        w = x[i0:i0 + int(0.06 * SR)]
        e = np.abs(w)
        th = 0.5 * e.max()
        k = int(np.argmax(e > th))
        i0 = max(0, i0 + k - int(0.002 * SR))
    s = x[i0:i1].copy()
    if hp:
        s = _highpass(s, hp)
    if lp:
        s = _lowpass(s, lp)
    a, b = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    s[:a] *= np.linspace(0, 1, a)
    s[-b:] *= np.linspace(1, 0, b) ** 2
    return s * peak / max(np.max(np.abs(s)), 1e-9)


_hits = {}


def hit(key):
    if key not in _hits:
        a = {
            "tick": lambda: _cut("alarm_clock", 3.375, 3.47, fade_out=0.03, hp=400),
            "tock": lambda: _cut("alarm_clock", 4.262, 4.38, fade_out=0.04, hp=250),
            "ring": lambda: _cut("alarm_clock", 9.0, 9.55, fade_in=0.01, fade_out=0.12, hp=300),
            "bell": lambda: _cut("old_clock_bell", 1.56, 3.55, fade_out=0.6, hp=150),
            "clang1": lambda: _cut("clang_group", 0.06, 0.88, fade_out=0.25, hp=120),
            "clang2": lambda: _cut("clang_group", 4.52, 5.5, fade_out=0.3, hp=120),
            "clang3": lambda: _cut("clang_group", 10.67, 11.6, fade_out=0.3, hp=120),
            "key1": lambda: _cut("typewriter", 1.9, 2.02, fade_out=0.03, hp=150),
            "key2": lambda: _cut("typewriter", 10.27, 10.40, fade_out=0.03, hp=120),
            "key3": lambda: _cut("typewriter", 4.06, 4.17, fade_out=0.03, hp=200),
            "ding": lambda: _cut("typewriter", 48.43, 48.84, fade_out=0.1, hp=1500),
            "run": lambda: _cut("typewriter", 10.12, 10.78, fade_out=0.1, hp=150),
            "crank": lambda: _cut("turn_crank_loop", 0.10, 0.50, fade_out=0.08, hp=150),
            "spring": lambda: _cut("metal_spring_scrape", 0.09, 5.4, fade_out=1.0, hp=120),
            "springres": lambda: _cut("metal_spring_scrape", 0.62, 1.9, fade_in=0.15, fade_out=0.5, hp=200, onset=False),
            "noise": lambda: _cut("metallic_noise", 0.0, 0.8, fade_out=0.25, hp=300),
            "wobble": lambda: _cut("liquid_wobble", 0.78, 1.55, fade_out=0.2, hp=80),
        }[key]()
        _hits[key] = a
    return _hits[key]


# level of each hit against the synth kit (anvil / tick ~0.3-0.5 peak at full velocity)
DRUM_KIT = {
    "o": ("tick", 0.6), "O": ("tock", 0.75), "I": ("ring", 0.3), "L": ("bell", 0.9),
    "C": ("clang1", 0.7), "Q": ("clang2", 0.7), "U": ("clang3", 0.7),
    "v": ("key1", 0.6), "V": ("key2", 0.75), "f": ("key3", 0.5),
    "g": ("ding", 0.45), "R": ("run", 0.5), "n": ("crank", 0.7), "Z": ("spring", 0.6),
    "X": ("noise", 0.5), "u": ("wobble", 0.5),
}


def _drum(key, gain):
    return lambda vel=0.8: hit(key) * vel * gain


def _resampled(key, base_hz, gain, max_len=None, release=None):
    def inst(freq, dur, vel=0.8):
        x = hit(key)
        ratio = freq / base_hz
        n = int(len(x) / ratio)
        if max_len:
            n = min(n, int(max_len * SR))
        pos = np.arange(n) * ratio
        y = np.interp(pos, np.arange(len(x)), x)
        if release is not None:
            hold = int((dur + release) * SR)
            if hold < n:
                r = min(n - hold, int(0.4 * SR))
                y[hold:hold + r] *= np.linspace(1, 0, r) ** 2
                y[hold + r:] = 0
                y = y[:hold + r]
        return y * vel * gain
    return inst


def register():
    for code, (key, gain) in DRUM_KIT.items():
        synth.DRUMS[code] = _drum(key, gain)
    synth.INSTRUMENTS["clockbell"] = _resampled("bell", synth.mtof(64) * 326 / 329.63, 0.5)
    synth.INSTRUMENTS["tinebell"] = _resampled("ding", synth.mtof(105) * 3445 / 3520.0, 0.6, max_len=3.0)
    synth.INSTRUMENTS["springres"] = _resampled("springres", synth.mtof(73) * 562 / 554.37, 0.35, release=0.3)
