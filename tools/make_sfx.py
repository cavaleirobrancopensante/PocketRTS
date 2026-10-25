"""Synthesise Holdfast sound effects (no samples).
   python3 tools/make_sfx.py [name ...]   -> assets/audio/<name>.wav  (22.05 kHz mono)"""
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def T(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(int(SR * d))


def bp(x, lo, hi, o=2):
    return sosfilt(butter(o, [lo, min(hi, SR / 2 - 50)], btype="band", fs=SR, output="sos"), x)


def lp(x, f, o=2):
    return sosfilt(butter(o, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, o=2):
    return sosfilt(butter(o, f, btype="high", fs=SR, output="sos"), x)


def env(d, a, decay):
    t = T(d)
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t * decay)


def sweep(f0, f1, d, shape=1.0):
    t = T(d)
    f = f0 + (f1 - f0) * (t / d) ** shape
    return 2 * np.pi * np.cumsum(f) / SR


def saw(ph, k=14):
    return sum(np.sin(i * ph) / i for i in range(1, k))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, s):
    return np.concatenate([np.zeros(int(s * SR)), x])


def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    f = min(len(x), int(SR * 0.01))
    x[-f:] *= np.linspace(1, 0, f)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


# ------------------------------------------------------------------ combat

def clash():          # pike or sword on steel
    d = 0.4
    t = T(d)
    ring = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, a, k in
               [(1830, 1, 14), (2650, .7, 18), (3920, .5, 22), (5100, .3, 30)])
    hit = bp(noise(d), 1500, 7000) * env(d, 0.001, 70)
    thud = np.sin(2 * np.pi * 140 * t) * env(d, 0.001, 35)
    return ring * 0.5 + hit + thud * 0.6


def bite():           # raptor or brute: snap of jaws, wet crunch
    d = 0.3
    snap = bp(noise(d), 900, 4000) * env(d, 0.001, 55)
    crunch = bp(noise(d), 300, 2500) * env(d, 0.002, 25) * (rng.random(int(SR * d)) > 0.55)
    growl = saw(sweep(170, 110, d)) * env(d, 0.01, 12) * 0.25
    return mix(snap, delay(crunch * 0.8, 0.02), lp(growl, 900))


def gear_hit():       # gearknight: heavy iron fist, clank
    d = 0.5
    t = T(d)
    body = np.sin(2 * np.pi * (90 + 60 * np.exp(-t * 30)) * t) * env(d, 0.001, 14)
    clank = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, a, k in
                [(420, 1, 16), (970, .7, 20), (1520, .5, 26)])
    return body + clank * 0.5 + bp(noise(d), 1500, 6000) * env(d, 0.001, 60) * 0.6


def acid():           # spitter: wet hawk, then sizzle
    d = 0.55
    spit = bp(noise(d), 600, 2500) * env(d, 0.005, 30)
    gurgle = np.sin(sweep(300, 900, 0.12)) * env(0.12, 0.005, 20) * 0.5
    sizzle = hp(noise(d), 3500) * env(d, 0.08, 6) * 0.35
    return mix(gurgle, delay(spit, 0.05), delay(sizzle, 0.15))


def bolt():           # bolt automaton: spring twang + air
    d = 0.45
    t = T(d)
    twang = saw(2 * np.pi * 220 * t * (1 + 0.04 * np.exp(-t * 20)), 10) * env(d, 0.001, 11)
    twang = bp(twang, 200, 3000)
    whoosh = bp(noise(d), 800, 4000) * env(d, 0.03, 12) * 0.5
    click = hp(noise(0.02), 3000) * 0.8
    return mix(click, twang * 0.6, delay(whoosh, 0.02))


def steam():          # steam walker: a roaring cone of steam and flame
    d = 0.9
    t = T(d)
    e = np.minimum(1, t / 0.04) * np.exp(-t * 3.2)
    roar = lp(noise(d), 900) * e
    hiss = bp(noise(d), 2500, 9000) * e * 0.6
    puff = np.sin(2 * np.pi * 70 * t) * env(d, 0.005, 12) * 0.6
    return roar + hiss + puff


def roar():           # brute charge
    d = 0.8
    ph = sweep(95, 70, d) + 0.6 * np.sin(2 * np.pi * 22 * T(d))
    s = lp(saw(ph, 20), 1100) * env(d, 0.05, 3.5)
    s += bp(noise(d), 300, 1500) * env(d, 0.05, 4) * 0.4
    return s


# ------------------------------------------------------------------ production

def hatch():          # Brood egg cracking open
    d = 0.5
    cracks = np.zeros(int(SR * d))
    for k in range(5):
        c = hp(noise(0.03), 1800) * env(0.03, 0.001, 140)
        i = int(SR * (0.02 + k * 0.045 + rng.random() * 0.02))
        cracks[i:i + len(c)] += c * (1 - k * 0.12)
    squelch = bp(noise(d), 200, 900) * env(d, 0.02, 9) * 0.6
    chirp = np.sin(sweep(900, 1700, 0.15, 0.6)) * env(0.15, 0.01, 18) * 0.35
    return mix(cracks, delay(squelch, 0.18), delay(chirp, 0.3))


def ready_crown():    # a short trumpet call
    out = np.zeros(1)
    for i, (f, d) in enumerate([(392, 0.12), (523, 0.12), (659, 0.32)]):
        t = T(d)
        s = sum(np.sin(2 * np.pi * f * k * t) / k ** 1.1 for k in range(1, 9))
        s = lp(s, 3000) * np.minimum(1, t / 0.015) * np.exp(-t * (2 if i == 2 else 6))
        out = mix(out, delay(s, i * 0.13))
    return out


def ready_brood():    # screech
    d = 0.35
    s = saw(sweep(700, 1300, d, 0.5) + 0.3 * np.sin(2 * np.pi * 35 * T(d)), 12)
    return bp(s, 600, 5000) * env(d, 0.02, 8)


def ready_clock():    # wind-up ratchet, then a ding
    out = np.zeros(int(SR * 0.65))
    for k in range(6):
        c = bp(noise(0.02), 2000, 8000) * env(0.02, 0.001, 200)
        i = int(SR * k * 0.045)
        out[i:i + len(c)] += c
    t = T(0.6)
    ding = (np.sin(2 * np.pi * 1568 * t) + 0.3 * np.sin(2 * np.pi * 1568 * 2.76 * t)) * np.exp(-t * 6)
    return mix(out, delay(ding * 0.6, 0.3))


def built_crown():    # hammer knocks and a bell
    out = np.zeros(1)
    for k in range(3):
        t = T(0.12)
        knock = np.sin(2 * np.pi * 260 * t) * np.exp(-t * 50) + bp(noise(0.12), 800, 3000) * np.exp(-t * 80) * 0.5
        out = mix(out, delay(knock, k * 0.16))
    t = T(1.4)
    bell = sum(a * np.sin(2 * np.pi * 523 * r * t) * np.exp(-t * (1.5 + r)) for r, a in
               [(1, 1), (2, .5), (2.4, .4), (3, .25), (4.1, .15)])
    return mix(out, delay(bell * 0.5, 0.5))


def built_brood():    # wet heave, low groan
    d = 1.0
    groan = lp(saw(sweep(60, 85, d), 16), 600) * env(d, 0.15, 3)
    wet = bp(noise(d), 200, 1200) * env(d, 0.05, 5) * 0.5
    return groan + wet


def built_clock():    # gears catch, steam whistle
    out = np.zeros(1)
    for k in range(4):
        out = mix(out, delay(gear_click(), k * 0.07))
    t = T(0.5)
    whistle = (np.sin(2 * np.pi * 1180 * t) + 0.4 * np.sin(2 * np.pi * 1770 * t)) * np.minimum(1, t / 0.05) * np.exp(-t * 3)
    whistle += bp(noise(0.5), 1000, 3000) * np.exp(-t * 4) * 0.3
    return mix(out, delay(whistle * 0.6, 0.3))


def gear_click():
    t = T(0.06)
    return (np.sin(2 * np.pi * 1300 * t) + bp(noise(0.06), 2000, 7000)) * np.exp(-t * 90)


def ratchet():        # winder repairing / seeding
    out = np.zeros(int(SR * 0.4))
    for k in range(8):
        c = gear_click() * (0.6 + 0.4 * (k % 2))
        i = int(SR * k * 0.045)
        out[i:i + len(c)] += c
    return out


def burrow():         # grub burrowing / morphing
    d = 0.5
    s = lp(noise(d), 700) * env(d, 0.05, 6) * (1 + 0.8 * np.sin(2 * np.pi * 18 * T(d)))
    return s


# ------------------------------------------------------------------ deaths

def death_crown():    # a body falls, armour rattles
    d = 0.5
    t = T(d)
    thud = np.sin(2 * np.pi * (70 + 40 * np.exp(-t * 20)) * t) * env(d, 0.002, 10)
    rattle = bp(noise(d), 2000, 6000) * env(d, 0.002, 18) * (rng.random(int(SR * d)) > 0.7) * 0.6
    groan = lp(saw(sweep(190, 120, 0.35)), 1000) * env(0.35, 0.03, 8) * 0.3
    return mix(groan, delay(thud, 0.12), delay(rattle, 0.12))


def death_brood():    # shriek
    d = 0.5
    s = saw(sweep(1100, 380, d, 0.7) + 0.5 * np.sin(2 * np.pi * 45 * T(d)), 12)
    return bp(s, 400, 5000) * env(d, 0.01, 6)


def death_clock():    # spring snaps, parts clatter
    d = 0.8
    t = T(0.3)
    snap = np.sin(sweep(2400, 400, 0.3, 0.4)) * np.exp(-t * 12) * 0.6
    out = np.zeros(int(SR * d))
    for k in range(9):
        c = gear_click() * rng.uniform(0.4, 1)
        i = int(SR * (0.08 + rng.random() * 0.6))
        out[i:i + len(c)] += c
    hiss = bp(noise(d), 2500, 8000) * env(d, 0.02, 5) * 0.3
    return mix(snap, out, hiss)


def zap():            # Tesla arc: crackling electric snap
    d = 0.45
    t = T(d)
    buzz = np.sign(np.sin(2 * np.pi * 95 * t)) * 0.3 + np.sign(np.sin(2 * np.pi * 143 * t)) * 0.2
    crack = hp(noise(d), 2500) * (rng.random(int(SR * d)) > 0.86)
    return (buzz * 0.6 + crack) * env(d, 0.002, 7)


def collapse():       # a building falls
    d = 1.6
    t = T(d)
    rumble = lp(noise(d), 260) * env(d, 0.04, 2.2) * 2.0
    debris = bp(noise(d), 600, 4000) * env(d, 0.1, 3) * (rng.random(int(SR * d)) > 0.8)
    boom = np.sin(2 * np.pi * (45 + 30 * np.exp(-t * 6)) * t) * env(d, 0.005, 4)
    return rumble + debris * 0.6 + boom


SOUNDS = {f.__name__: f for f in [clash, bite, gear_hit, acid, bolt, steam, roar, hatch, ready_crown, ready_brood,
                                  ready_clock, built_crown, built_brood, built_clock, ratchet, burrow,
                                  death_crown, death_brood, death_clock, zap, collapse]}

if __name__ == "__main__":
    for nm in sys.argv[1:] or list(SOUNDS):
        save(nm, SOUNDS[nm]())
        print(nm)
