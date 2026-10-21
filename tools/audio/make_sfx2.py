"""PocketRTS sound effects, fully procedural (groups A-E of AUDIO_PROMPTS.md).

    python3 tools/audio/make_sfx2.py            # everything
    python3 tools/audio/make_sfx2.py ui crown   # only names/folders containing these substrings

Writes mono 44.1 kHz 16-bit WAVs to assets/audio/<group>/ and 30 s .ogg loops to assets/audio/ambience/.
Deterministic: every file is seeded from its own name.
"""
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import *  # noqa: E402,F401,F403

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")

REG = []  # (relpath without ext, fn, variants, peak_db, kind)


def sfx(path, n=1, peak=-1.0, kind="wav"):
    def deco(fn):
        REG.append((path, fn, n, peak, kind))
        return fn
    return deco


PV = [1.0, 0.92, 1.08, 0.96]   # per-variant pitch factor


def drive(x, k):
    """Soft saturation for punch (normalise, tanh, renormalise)."""
    x = x / (np.max(np.abs(x)) + 1e-9)
    return np.tanh(k * x) / np.tanh(k)


# =================================================================== shared building blocks

def gunshot(rng, v, size=1.0, d=1.1):
    """Black-powder shot: lock click, pan flash, crack, body, low boom, outdoor tail."""
    p = PV[v]
    out = np.zeros(N(d))
    # flint lock snap + pan 'pfft' (very short, keeps the hit on frame one)
    lock = metal_hit(rng, 2600 * p, 0.03, decay=180, bright=0.7) * 0.25
    out = place(out, lock, 0)
    pan = bp(noise(rng, 0.03), 1500, 7000) * expenv(0.03, 90, 0.002) * 0.35
    out = place(out, pan, 0.004)
    t0 = 0.018 + 0.006 * v
    crack = hp(noise(rng, 0.02), 1800) * expenv(0.02, 260, 0.0003)
    body = lp(noise(rng, 0.25), 1400 * p) * expenv(0.25, 22 / size, 0.001)
    boom_d = 0.5 * size
    tb = T(boom_d)
    boom = np.sin(phase(expglide(110 * p, 45 * p, boom_d))) * np.exp(-tb * 9 / size)
    tail = lp(noise(rng, d), 700) * expenv(d, 3.5, 0.02) * 0.25
    puff = bp(noise(rng, 0.35), 300, 1200) * expenv(0.35, 9, 0.03) * 0.25
    out = place(out, crack * 1.0, t0)
    out = place(out, body * 0.9, t0)
    out = place(out, boom * 0.8 * size, t0)
    out = place(out, tail, t0 + 0.01)
    out = place(out, puff, t0 + 0.04)
    # outdoor slap-back echo from a tree line
    out = echo(out, 0.17 + 0.04 * v, 0.22, n=2, lowpass=1500)
    return drive(out, 3.0)


def explosion(rng, v, size=1.0, d=1.4, debris=1.0):
    p = PV[v]
    out = np.zeros(N(d))
    tb = T(d)
    sub = np.sin(phase(expglide(80 * p, 32 * p, d))) * np.exp(-tb * 4 / size)
    crack = hp(noise(rng, 0.03), 1200) * expenv(0.03, 150, 0.0005)
    body = lp(noise(rng, d), 900 * p) * expenv(d, 6 / size, 0.003)
    rumble = lp(noise(rng, d), 180) * expenv(d, 2.5 / size, 0.04) * 3
    out = place(out, sub * 1.0, 0)
    out = place(out, crack * 0.8, 0)
    out = place(out, body * 0.8, 0)
    out = place(out, rumble * 0.6, 0.01)
    # dirt rain and splinters
    dirt = grains(rng, d * 0.8, lambda t: 300 * np.exp(-t * 3), (0.004, 0.02), 400, 4000,
                  env=lambda t: np.exp(-t * 3))
    out = place(out, dirt * 0.35 * debris, 0.05)
    for _ in range(int(6 * debris)):
        tt = rng.uniform(0.08, d * 0.7)
        out = place(out, wood_hit(rng, rng.uniform(500, 1600), 0.08, 60) * rng.uniform(0.05, 0.18) * debris, tt)
    return drive(fit(out, d), 2.5)


def creature(rng, d, f0, f1, fm=(700, 1200, 2600), q=6, rough=0.3, breath=0.3, jitter=0.03,
             shape=1.0, vib=0.0, vibf=20):
    """Formant-filtered rough voice source with a pitch contour."""
    t = T(d)
    f = f0 + (f1 - f0) * (t / d) ** shape
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * vibf * t))
    src = glottal(rng, f, jitter=jitter, shimmer=0.25, rough=rough)
    src = src + breath * noise(rng, d) * 0.6
    fmts = []
    for i, fr in enumerate(fm):
        fmts.append((fr * (1 + 0.08 * smooth_rand(rng, d, 6, -1, 1)), 1.0 / (1 + 0.5 * i)))
    return formants(src, fmts, q)


def roar(rng, d, p=1.0, intensity=1.0):
    t = T(d)
    a = adsr(d, 0.08, 0.1, 0.85, d * 0.5)
    f = 70 * p * (1 + 0.35 * np.sin(np.pi * t / d)) * (1 + 0.04 * smooth_rand(rng, d, 9, -1, 1))
    v = creature(rng, d, 1, 1, fm=(380 * p, 900 * p, 2300 * p), q=4, rough=0.9, breath=0.8, jitter=0.08)
    src = glottal(rng, f, jitter=0.08, shimmer=0.4, rough=0.9)
    src = src + 0.9 * noise(rng, d)
    v = formants(src, [(380 * p, 1.0), (900 * p, 0.7), (2300 * p, 0.35)], 4)
    growl = lp(noise(rng, d), 200) * (1 + np.sin(2 * np.pi * 28 * t)) * 0.4
    return (v + growl) * a * intensity


def screech(rng, d, f0=2600, f1=1800, rough=0.5):
    t = T(d)
    f = glide(f0, f1, d, 0.7) * (1 + 0.03 * np.sin(2 * np.pi * 37 * t))
    ph = phase(f)
    mod = (2.5 + rough * 3) * np.sin(ph * 0.5 + 0.3)
    tone = np.sin(ph + mod) + 0.4 * np.sin(2 * ph + mod * 0.5)
    nz = bp(noise(rng, d), f0 * 0.6, f0 * 1.8) * rough
    a = adsr(d, 0.015, 0.05, 0.75, d * 0.5)
    return (tone + nz) * a * (1 + 0.35 * np.sin(2 * np.pi * 55 * t))


def chitter(rng, d, rate=28, f=3200, voices=1):
    out = np.zeros(N(d) + N(0.05))
    for vo in range(voices):
        r = rate * rng.uniform(0.85, 1.2)
        t = rng.uniform(0, 0.03)
        ff = f * rng.uniform(0.75, 1.3)
        while t < d:
            c = modal([ff * rng.uniform(0.9, 1.1), ff * 1.7], [1, 0.4], [400, 600], 0.015, rng)
            c = mix(c, hp(noise(rng, 0.004), 2500) * np.exp(-T(0.004) * 900) * 0.6)
            out = place(out, c * rng.uniform(0.4, 1.0), t)
            t += rng.exponential(1 / r) * 0.6 + 0.4 / r
    return out


def whoosh(rng, d, f0=600, f1=2400, q=2.5, peak_at=0.5):
    t = T(d)
    fc = f0 * (f1 / f0) ** np.clip(t / (d * peak_at), 0, 1)
    fc = np.where(t > d * peak_at, f1 * (f0 / f1) ** ((t - d * peak_at) / (d * (1 - peak_at))) ** 1, fc)
    x = svf_bp(noise(rng, d), fc, q)
    a = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    return x * a


def steam_hiss(rng, d, attack=0.02, decay=2.0, bright=1.0):
    t = T(d)
    x = hp(noise(rng, d), 1800 * bright, 3)
    x += 0.4 * bp(noise(rng, d), 600, 2500)
    a = np.minimum(1, t / attack) * np.exp(-t * decay)
    a *= 1 + 0.15 * smooth_rand(rng, d, 25, -1, 1)
    return x * a


def tesla_zap(rng, d, p=1.0, buzz=1.0):
    t = T(d)
    a = expenv(d, 5 / d, 0.001)
    cr = crackle(rng, d, 900, a, lo=1200) * 3
    gate = (smooth_rand(rng, d, 120, 0, 1) > 0.45).astype(float)
    gate = lp(gate, 300)
    bz = bl_saw(np.full(N(d), 120 * p) * (1 + 0.02 * smooth_rand(rng, d, 30, -1, 1)))
    bz = bp(bz, 200, 5000) * a * gate * 0.5 * buzz
    hiss = hp(noise(rng, d), 4000) * a * gate * 0.3
    arc = bp(noise(rng, d), 1500, 7000) * a * gate * 0.6
    return drive(cr + bz * 1.6 + hiss + arc, 2.0)


def spring_boing(rng, d=0.4, f0=180, p=1.0):
    t = T(d)
    f = f0 * p * (1 + 1.6 * np.exp(-t * 18)) * (1 + 0.15 * np.sin(2 * np.pi * 11 * t) * np.exp(-t * 6))
    x = np.sin(phase(f)) + 0.4 * np.sin(phase(f * 2.9))
    return x * expenv(d, 9, 0.002)


def ratchet(rng, d, rate, f0=2800, decay=320, accel=0.0):
    times = []
    t = 0.0
    while t < d:
        times.append(t)
        r = rate * (1 + accel * t / d)
        t += 1 / max(r, 1) * rng.uniform(0.92, 1.08)
    out = click_train(rng, times, f0, decay)
    # pawl thunk under each click
    for tt in times:
        out = place(out, lp(noise(rng, 0.01), 500) * np.exp(-T(0.01) * 300) * 0.3, tt)
    return out


def snare_roll(rng, d, rate=24, amp=1.0, cresc=True):
    out = np.zeros(N(d) + N(0.1))
    t = 0.0
    i = 0
    while t < d:
        g = (0.4 + 0.6 * t / d) if cresc else 1.0
        g *= 0.85 if i % 2 else 1.0
        hit = bp(noise(rng, 0.06), 1500, 8000) * expenv(0.06, 55)
        hit += 0.5 * np.sin(2 * np.pi * 190 * T(0.06)) * expenv(0.06, 45)
        out = place(out, hit * g * amp, t)
        t += 1 / rate * rng.uniform(0.95, 1.05)
        i += 1
    return out


def drum(rng, d=0.8, f0=95, f1=48, p=1.0):
    t = T(d)
    body = np.sin(phase(expglide(f0 * p, f1 * p, d * 0.5).repeat(1)[:N(d)] if False else expglide(f0 * p, f1 * p, d)))
    body *= expenv(d, 5.5, 0.002)
    skin = lp(noise(rng, 0.1), 1200) * expenv(0.1, 40)
    return place(body, skin * 0.5, 0)


def brass_seq(rng, notes, gap=0.0, vib=5.5, bright=1.0, voices=1, detune=0.004):
    """notes: list of (start_s, freq, dur)."""
    out = np.zeros(1)
    for (st, f, du) in notes:
        for k in range(voices):
            fv = f * (1 + detune * (k - (voices - 1) / 2))
            out = place(out, brass(rng, fv, du, vib=vib, bright=bright) / voices, st + 0.006 * k)
    return out


def hz(note):
    """'C5' -> Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = names[note[0]]
    i = 1
    if note[1] in "#b":
        n += 1 if note[1] == "#" else -1
        i = 2
    octv = int(note[i:])
    return 440 * 2 ** ((n + (octv - 4) * 12) / 12)


def wet_squelch(rng, d, f=600, dens=180):
    t = T(d)
    g = grains(rng, d, lambda tt: dens * np.exp(-tt * 3), (0.01, 0.05), 80, 400, src="bubble")
    nz = lp(noise(rng, d), f) * expenv(d, 8, 0.01)
    sl = svf_bp(noise(rng, d), 300 + 900 * np.exp(-t * 10), 3.0) * expenv(d, 6, 0.005)
    return fit(g, d) * 0.6 + nz * 0.5 + sl * 0.7


def splat(rng, d=0.3, p=1.0):
    x = lp(noise(rng, d), 2200 * p) * expenv(d, 18, 0.001)
    x += grains(rng, d, 400, (0.003, 0.02), 150, 700, src="bubble")[:N(d)] * 0.6
    x += np.sin(2 * np.pi * 90 * p * T(d)) * expenv(d, 25) * 0.6
    return x


# =================================================================== A. UI

@sfx("ui/click", peak=-6)
def ui_click(rng, v):
    x = wood_hit(rng, 820, 0.06, 70)
    tick = metal_hit(rng, 4300, 0.04, decay=140, bright=0.6) * 0.18
    return place(x, tick, 0.003)


@sfx("ui/hover", peak=-14)
def ui_hover(rng, v):
    x = bp(noise(rng, 0.07), 2500, 9000) * expenv(0.07, 60, 0.004)
    x += grains(rng, 0.06, 300, (0.002, 0.006), 3000, 8000)[:N(0.07)] * 0.5 if True else 0
    return x


@sfx("ui/back", peak=-6)
def ui_back(rng, v):
    slide = bp(noise(rng, 0.1), 300, 1500) * adsr(0.1, 0.03, 0.03, 0.6, 0.04) * 0.25
    hit = wood_hit(rng, 430, 0.12, 40)
    return place(slide, hit, 0.022)


@sfx("ui/open_panel", peak=-6)
def ui_open_panel(rng, v):
    d = 0.3
    dens = lambda t: 250 + 900 * np.sin(np.pi * t / d)
    x = grains(rng, d, dens, (0.002, 0.012), 1200, 7000, env=lambda t: np.sin(np.pi * min(t / d, 1)) ** 0.5)
    sw = whoosh(rng, d, 500, 2500, 1.5, 0.4) * 0.6
    return mix(fit(x, d), sw, wood_hit(rng, 300, 0.08, 60) * 0.1)


@sfx("ui/toggle", peak=-6)
def ui_toggle(rng, v):
    a = metal_hit(rng, 3100, 0.05, decay=120, bright=0.7)
    b = metal_hit(rng, 3900, 0.06, decay=110, bright=0.7) * 0.8
    out = place(a * 0.6, b, 0.028)
    return place(out, wood_hit(rng, 1200, 0.03, 120) * 0.4, 0.028)


@sfx("ui/slider", peak=-8)
def ui_slider(rng, v):
    x = metal_hit(rng, 2700, 0.05, decay=220, bright=0.7) * 0.7
    return place(x, wood_hit(rng, 1000, 0.04, 120) * 0.5, 0)


@sfx("ui/error", peak=-6)
def ui_error(rng, v):
    out = np.zeros(1)
    for i, (tt, f) in enumerate([(0, 170), (0.11, 150)]):
        k = lp(wood_hit(rng, f, 0.12, 38), 900) + np.sin(2 * np.pi * f * 0.5 * T(0.12)) * expenv(0.12, 40) * 0.6
        out = place(out, k * (1 - 0.15 * i), tt)
    return out


@sfx("ui/start_match", peak=-3)
def ui_start_match(rng, v):
    d = 1.5
    out = drum(rng, 1.2, 105, 45) * 1.2
    out = place(out, drum(rng, 0.8, 120, 55) * 0.6, 0.18)
    chord = [hz("C3"), hz("G3"), hz("C4"), hz("E4"), hz("G4")]
    sw = np.zeros(N(1.4))
    swell = np.clip(T(1.4) / 1.1, 0, 1) ** 1.6
    for f in chord:
        b = brass(rng, f, 1.4, vib=5.0, vib_depth=0.006, attack=0.6, release=0.25)
        sw += b * swell
    out = place(out, sw * 0.5, 0.1)
    out = place(out, snare_roll(rng, 1.0, 22, 0.25), 0.25)
    return fit(out, d)


@sfx("ui/pause", peak=-6)
def ui_pause(rng, v):
    g = metal_hit(rng, 92, 0.45, decay=5, bright=0.85, ratios=[1, 1.47, 2.09, 2.56, 3.2, 4.1])
    g = lp(g, 900) * adsr(0.45, 0.012, 0.1, 0.8, 0.25)
    return mix(g, lp(noise(rng, 0.05), 300) * expenv(0.05, 60) * 0.5)


@sfx("ui/select_box", peak=-10)
def ui_select_box(rng, v):
    d = 0.32
    w = whoosh(rng, d, 900, 3500, 2.0, 0.6)
    grit = grains(rng, d, 1200, (0.001, 0.004), 2500, 9000, env=lambda t: np.sin(np.pi * min(t / d, 1)))
    return w + fit(grit, d) * 0.5


@sfx("ui/group_set", peak=-6)
def ui_group_set(rng, v):
    out = metal_hit(rng, 1800, 0.12, decay=35, bright=0.5)
    return place(out * 0.8, metal_hit(rng, 2400, 0.16, decay=30, bright=0.5), 0.085)


@sfx("ui/minimap_ping", peak=-6)
def ui_minimap_ping(rng, v):
    return mix(fm_bell(1760, 0.45, ratio=3.5, index=1.5, decay=9), 0.3 * fm_bell(3520, 0.3, 2.0, 0.5, 14))


# =================================================================== B. faction interface — Crown

@sfx("crown/ready", peak=-9.0)
def crown_ready(rng, v):
    # heard every time a soldier steps out: a soft, distant two-note horn (rising fourth),
    # mellow and short, so it reads as "the Crown" without nagging
    out = np.zeros(1)
    for st, f, du in [(0.0, hz("G3"), 0.16), (0.15, hz("C4"), 0.38)]:
        b = brass(rng, f, du, vib=4.5, vib_depth=0.004, bright=0.45, attack=0.06, release=0.18, scoop=0.01)
        out = place(out, b, st)
    return reverb(lp(out, 1600), rng, rt=0.7, wet=0.2)


@sfx("crown/placed")
def crown_placed(rng, v):
    out = np.zeros(1)
    for i, tt in enumerate([0, 0.16]):
        h = wood_hit(rng, 310 * (1 + 0.05 * i), 0.2, 30)
        h = mix(h, metal_hit(rng, 1650, 0.08, decay=60, bright=0.5) * 0.25, lp(noise(rng, 0.06), 400) * expenv(0.06, 50) * 0.8)
        out = place(out, h * (0.75 + 0.25 * i), tt)
    return out


@sfx("crown/built", peak=-4.0)
def crown_built(rng, v):
    out = snare_roll(rng, 0.5, 26, 0.6, cresc=False)
    notes = [(0.42, hz("C4"), 0.16), (0.58, hz("E4"), 0.16), (0.74, hz("G4"), 0.16), (0.9, hz("C5"), 0.8)]
    br = brass_seq(rng, notes, voices=2, bright=0.7)
    br = place(br, brass_seq(rng, [(0.9, hz("E4"), 0.8), (0.9, hz("G3"), 0.8)], voices=1, bright=0.6) * 0.5, 0)
    br = lp(br, 2600)
    out = place(out, br, 0)
    out = place(out, drum(rng, 0.6, 110, 55) * 0.8, 0.9)
    return out


@sfx("crown/research")
def crown_research(rng, v):
    d = 0.35
    strokes = np.zeros(N(d))
    for i, st in enumerate([0.0, 0.1, 0.2]):
        sd = 0.08
        s = bp(noise(rng, sd), 2500, 9000) * np.sin(np.pi * T(sd) / sd) ** 2
        s *= 1 + 0.8 * (rng.random(N(sd)) > 0.85)
        strokes = place(strokes, s * 0.25, st)
    out = place(strokes, bell(rng, hz("E5"), 1.6, decay=2.2), 0.3)
    out = place(out, bell(rng, hz("B5"), 1.2, decay=3) * 0.35, 0.3)
    return out


@sfx("crown/no_res")
def crown_no_res(rng, v):
    d = 0.6
    out = bp(noise(rng, d), 300, 3000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 7 * T(d)))) * adsr(d, 0.03, 0.1, 0.6, 0.2) * 0.25
    for tt in [0.03, 0.17, 0.31]:
        c = metal_hit(rng, rng.uniform(3200, 4200), 0.15, decay=30, bright=0.8, ratios=[1, 1.62, 2.41, 3.33])
        out = place(out, c * rng.uniform(0.5, 0.8), tt)
    return out


@sfx("crown/no_supply")
def crown_no_supply(rng, v):
    d = 0.8
    crowd = np.zeros(N(d))
    for k in range(7):
        f0 = rng.uniform(95, 170)
        f = f0 * (1 + 0.15 * smooth_rand(rng, d, 5, -1, 1))
        src = glottal(rng, f, 0.02, 0.4) * (smooth_rand(rng, d, 9, 0, 1) > 0.4)
        crowd += formants(src, [(smooth_rand(rng, d, 7, 350, 800), 1), (smooth_rand(rng, d, 7, 900, 2000), 0.6)], 6)
    crowd = lp(crowd, 2500) * adsr(d, 0.1, 0.1, 0.8, 0.25) * 0.25
    horn = brass_seq(rng, [(0.15, hz("D3"), 0.14), (0.31, hz("A2"), 0.3)], vib=0, bright=0.7)
    return place(crowd, horn, 0)


@sfx("crown/alert", peak=-5.0)
def crown_alert(rng, v):
    # a low horn from the walls: firm, but rounded rather than blaring
    d = 0.75
    b = brass(rng, hz("D3"), d, vib=4.5, vib_depth=0.006, bright=0.7, attack=0.08, release=0.25, scoop=0.05)
    b2 = brass(rng, hz("A3"), d, vib=4.6, vib_depth=0.006, bright=0.6, attack=0.09, release=0.25, scoop=0.05) * 0.45
    return reverb(lp(b + b2, 2200), rng, rt=0.8, wet=0.18)


@sfx("crown/base_alert")
def crown_base_alert(rng, v):
    out = np.zeros(1)
    for i in range(3):
        out = place(out, bell(rng, hz("A4") * (1 - 0.01 * i), 1.0, decay=3.2, bright=0.9), 0.19 * i)
    return lp(out, 7000)


@sfx("crown/select_building")
def crown_select_building(rng, v):
    d = 0.5
    rate = 70 + 120 * smooth_rand(rng, d, 6, 0, 1)
    times, t = [], 0.0
    while t < d:
        times.append(t)
        t += 1 / np.interp(t, np.linspace(0, d, len(rate)), rate) * rng.uniform(0.85, 1.15)
    x = np.zeros(N(d) + 100)
    for tt in times:
        x[int(tt * SR)] = rng.uniform(0.5, 1)
    y = lp(formants(x, [(650, 1.0), (1450, 0.7), (2600, 0.4)], 15), 4000, 4)
    y *= adsr(len(y) / SR, 0.06, 0.1, 0.8, 0.12)
    return y


# =================================================================== B. Brood

@sfx("brood/ready")
def brood_ready(rng, v):
    out = np.zeros(1)
    for i in range(4):
        out = place(out, bubble(rng, rng.uniform(250, 500), 0.07, 6) * 0.8, 0.035 * i + rng.uniform(0, 0.01))
        out = place(out, lp(noise(rng, 0.02), 1500) * expenv(0.02, 120) * 0.4, 0.035 * i)
    ch = screech(rng, 0.18, 3200, 4200, 0.2) * 0.5
    return place(out, ch, 0.17)


@sfx("brood/placed")
def brood_placed(rng, v):
    x = wet_squelch(rng, 0.6, 700)
    th = np.sin(2 * np.pi * 70 * T(0.3)) * expenv(0.3, 14) * 0.7
    return place(x, th, 0.02)


def heartbeat(rng, amp=1.0, p=1.0):
    lub = np.sin(phase(expglide(70 * p, 45 * p, 0.18))) * expenv(0.18, 22, 0.01)
    dub = np.sin(phase(expglide(85 * p, 55 * p, 0.14))) * expenv(0.14, 26, 0.008) * 0.7
    return place(lub + lp(noise(rng, 0.18), 200) * expenv(0.18, 30) * 0.3, dub, 0.16) * amp


@sfx("brood/built")
def brood_built(rng, v):
    out = np.zeros(1)
    for i, tt in enumerate([0, 0.45, 0.85]):
        out = place(out, heartbeat(rng, 0.5 + 0.25 * i), tt)
    g = roar(rng, 0.8, 1.15, 0.6)
    out = place(out, g, 0.8)
    return out


@sfx("brood/research")
def brood_research(rng, v):
    d = 0.9
    c = chitter(rng, d, 25, 3000, 4)
    c = fit(c, d) * np.linspace(0.2, 1, N(d)) ** 1.5
    sc = screech(rng, 0.25, 3000, 4000, 0.3) * 0.4
    return place(c, sc, d - 0.2)


@sfx("brood/no_res")
def brood_no_res(rng, v):
    d = 0.8
    g = grains(rng, d, 70, (0.04, 0.12), 60, 200, src="bubble")
    t = T(d)
    rum = svf_bp(noise(rng, d), 150 + 250 * smooth_rand(rng, d, 6, 0, 1), 4) * adsr(d, 0.1, 0.1, 0.8, 0.3)
    return fit(g, d) + rum * 0.8


@sfx("brood/no_supply")
def brood_no_supply(rng, v):
    d = 0.6
    x = bp(noise(rng, d), 2200, 6500) * adsr(d, 0.06, 0.1, 0.7, 0.3)
    x += bp(noise(rng, d), 500, 1200) * adsr(d, 0.06, 0.1, 0.7, 0.3) * 0.4
    return x


@sfx("brood/alert")
def brood_alert(rng, v):
    return screech(rng, 0.45, 3400, 2800, 0.7) + screech(rng, 0.45, 2200, 1900, 0.5) * 0.5


@sfx("brood/base_alert")
def brood_base_alert(rng, v):
    d = 1.5
    out = lp(noise(rng, d), 90) * adsr(d, 0.3, 0.2, 0.9, 0.6) * 5
    for k in range(4):
        out = place(out, roar(rng, 1.0 + 0.2 * k, 0.75 + 0.15 * k, 0.6), 0.08 * k)
    return fit(out, d)


@sfx("brood/select_building")
def brood_select_building(rng, v):
    d = 0.6
    t = T(d)
    breath = svf_bp(noise(rng, d), 500 + 400 * np.sin(np.pi * t / d), 2) * np.sin(np.pi * t / d) ** 2
    wet = grains(rng, d, 60, (0.02, 0.06), 100, 300, src="bubble")
    return breath + fit(wet, d) * 0.6 + fit(heartbeat(rng, 0.4), d)


# =================================================================== B. Clockwork

@sfx("clock/ready")
def clock_ready(rng, v):
    s = steam_hiss(rng, 0.45, 0.01, 6) * 0.6
    return place(s, bell(rng, hz("A5"), 0.8, decay=4.0), 0.14)


@sfx("clock/placed")
def clock_placed(rng, v):
    m = metal_hit(rng, 165, 0.5, decay=9, bright=0.8)
    th = lp(noise(rng, 0.08), 300) * expenv(0.08, 40) * 1.5
    out = place(m, th, 0)
    return place(out, metal_hit(rng, 900, 0.1, decay=40, bright=0.6) * 0.3, 0.06)


@sfx("clock/built")
def clock_built(rng, v):
    d = 1.0
    r = ratchet(rng, d, 9, 2400, 260, accel=2.5)
    whir = bl_saw(glide(60, 260, d, 1.2)) * np.linspace(0.1, 1, N(d)) * 0.08
    whir = bp(whir, 150, 3000)
    out = mix(fit(r, d) * 0.7, whir)
    out = place(out, metal_hit(rng, 200, 0.2, decay=20) * 0.5, d - 0.02)
    out = place(out, bell(rng, hz("E6"), 0.9, decay=3.5) * 0.9, d)
    out = place(out, bell(rng, hz("B5"), 0.9, decay=3.5) * 0.5, d + 0.005)
    return out


@sfx("clock/research")
def clock_research(rng, v):
    d = 0.9
    z = tesla_zap(rng, 0.35, 1.0) * 0.6
    t = T(d)
    f = expglide(300, 1200, d)
    tone = (np.sin(phase(f)) + 0.3 * np.sin(phase(2 * f)) + 0.15 * np.sin(phase(3 * f))) * adsr(d, 0.05, 0.1, 0.8, 0.2)
    return place(tone * 0.5, z, 0)


@sfx("clock/no_res")
def clock_no_res(rng, v):
    d = 0.9
    r = ratchet(rng, 0.7, 18, 2200, 300, accel=-0.8) * 0.6
    sp = spring_boing(rng, 0.5, 140)
    out = place(fit(r, 0.7), sp * 0.6, 0.45)
    sput = steam_hiss(rng, 0.4, 0.01, 6) * (smooth_rand(rng, 0.4, 25, 0, 1) > 0.5) * 0.3
    return place(out, sput, 0.4)


@sfx("clock/no_supply")
def clock_no_supply(rng, v):
    d = 0.7
    t = T(d)
    f = 2200 * (1 + 0.03 * np.sin(2 * np.pi * 6 * t))
    w = np.sin(phase(f)) * 0.5 + reson(noise(rng, d), 2200, 25) * 0.6
    gate = np.clip(np.sin(2 * np.pi * 2.9 * t), 0, 1) ** 0.3
    return w * gate * adsr(d, 0.01, 0.05, 0.9, 0.05)


@sfx("clock/alert")
def clock_alert(rng, v):
    d = 0.65
    t = T(d)
    f = np.where(t < 0.3, 520, 520) * 1.0
    x = pulse(np.full(N(d), 520.0), 0.25) + 0.6 * pulse(np.full(N(d), 655.0), 0.3)
    gate = ((t % 0.33) < 0.26).astype(float)
    gate = lp(gate, 60)
    x = bp(x, 300, 3500) * gate
    return reverb(x, rng, 0.3, 0.1)


@sfx("clock/base_alert")
def clock_base_alert(rng, v):
    d = 1.5
    f = glide(220, 820, d, 0.7)
    x = bl_saw(f) + 0.5 * bl_saw(f * 1.006)
    x = formants(x, [(f * 1.2, 1.0), (1800, 0.4)], 4) * adsr(d, 0.1, 0.1, 0.9, 0.2)
    return reverb(x, rng, 0.8, 0.15)


@sfx("clock/select_building")
def clock_select_building(rng, v):
    out = np.zeros(1)
    for i in range(5):
        f = 3400 if i % 2 == 0 else 2600
        out = place(out, metal_hit(rng, f, 0.05, decay=200, bright=0.6) * (1 if i % 2 == 0 else 0.7), i * 0.11)
    hum = np.sin(2 * np.pi * 60 * T(0.55)) * 0.06
    return place(out, hum * adsr(0.55, 0.05, 0.1, 1, 0.1), 0)


# =================================================================== C. Combat — Crown

@sfx("combat/musketeer_attack", 3)
def musketeer_attack(rng, v):
    return gunshot(rng, v, size=1.0 + 0.1 * v, d=1.1)


@sfx("combat/pikeman_attack", 3)
def pikeman_attack(rng, v):
    p = PV[v]
    d = 0.5
    w = whoosh(rng, 0.16, 700 * p, 1800 * p, 2.0, 0.25) * 0.7
    t = T(0.3)
    scr = svf_bp(noise(rng, 0.3), 2500 * p + 1500 * np.sin(np.pi * t / 0.3), 12) * expenv(0.3, 9, 0.01)
    scr *= 1 + 0.5 * (rng.random(N(0.3)) > 0.9)
    ring = metal_hit(rng, 1900 * p, 0.35, decay=12, bright=0.6)
    out = place(w, scr * 0.5, 0.05)
    out = place(out, ring * 0.45, 0.06)
    return fit(out, d)


@sfx("combat/cannon_attack", 2)
def cannon_attack(rng, v):
    d = 1.45
    x = gunshot(rng, v, size=2.4, d=d)
    car = mix(wood_hit(rng, 140, 0.25, 15) * 0.4, lp(noise(rng, 0.2), 500) * expenv(0.2, 18) * 0.3)
    creak = lp(formants(np.where(rng.random(N(0.25)) > 0.993, 1.0, 0.0), [(700, 1), (1600, .5)], 20), 2500, 4) * 0.6
    x = place(x, car, 0.22 + 0.03 * v)
    x = place(x, creak, 0.28)
    return fit(x, d)


@sfx("combat/cannon_hit", 2)
def cannon_hit(rng, v):
    return explosion(rng, v, size=0.8, d=1.2, debris=1.4)


@sfx("combat/crown_death", 3)
def crown_death(rng, v):
    d = [0.55, 0.45, 0.65][v]
    t = T(d)
    f0 = [175, 150, 200][v]
    f = f0 * (1 + 0.15 * np.exp(-t * 12)) * (1 - 0.35 * (t / d) ** 1.5)
    vowels = [((750, 1150, 2500), (520, 1000, 2400)), ((650, 1080, 2650), (430, 900, 2300)),
              ((800, 1250, 2600), (600, 1000, 2500))][v]
    a, b = vowels
    src = glottal(rng, f, jitter=0.04, shimmer=0.3, rough=0.25) + noise(rng, d) * 0.25
    fm = [(glide(a[i], b[i], d), 1 / (1 + 0.6 * i)) for i in range(3)]
    x = formants(src, fm, 7)
    x *= adsr(d, 0.03, 0.08, 0.8, d * 0.6)
    x = lp(x, 2600)  # muffled
    thud = lp(noise(rng, 0.15), 250) * expenv(0.15, 25) * 0.8
    return place(x, thud, d * 0.8)


@sfx("combat/missionary_heal")
def missionary_heal(rng, v):
    d = 1.9
    t = T(d)
    out = np.zeros(N(d))
    chord = [hz("A3"), hz("C#4"), hz("E4"), hz("A4"), hz("E5")]
    for f in chord:
        for k in range(3):
            ff = f * (1 + rng.uniform(-0.004, 0.004))
            vib = 1 + 0.006 * np.sin(2 * np.pi * rng.uniform(4.5, 5.8) * t + rng.uniform(0, 6))
            src = glottal(rng, np.full(N(d), ff) * vib, 0.004, 0.08)
            out += formants(src, [(730, 1.0), (1100, 0.6), (2600, 0.25)], 6)
    out += hp(noise(rng, d), 4000) * 0.02
    out *= np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.2
    out = reverb(out, rng, 1.0, 0.25)[:N(d)]
    out /= np.max(np.abs(out)) + 1e-9
    for i, tt in enumerate([0.5, 0.8, 1.1]):
        sd = 0.22
        cloth = bp(noise(rng, sd), 900, 5000) * np.sin(np.pi * T(sd) / sd) ** 2 * 0.25
        out = place(out, cloth, tt)
    return fit(out, d)


# =================================================================== C. Combat — Brood

@sfx("combat/raptor_attack", 3)
def raptor_attack(rng, v):
    p = PV[v]
    sl = whoosh(rng, 0.12, 2000 * p, 7000 * p, 1.5, 0.3)
    sl = mix(sl, hp(noise(rng, 0.1), 3000) * expenv(0.1, 30) * 0.3)
    snap = modal([1300 * p, 2900 * p, 4700 * p], [1, .6, .4], [120, 160, 220], 0.06, rng)
    snap = mix(snap, hp(noise(rng, 0.008), 1500) * expenv(0.008, 500))
    hiss = screech(rng, 0.15, 3000 * p, 2400 * p, 0.8) * 0.25
    out = place(sl, snap * 0.9, 0.09 + 0.02 * v)
    return place(out, hiss, 0.0)


@sfx("combat/spitter_attack", 3)
def spitter_attack(rng, v):
    p = PV[v]
    gur = fit(grains(rng, 0.3, 120, (0.02, 0.05), 90 * p, 250 * p, src="bubble"), 0.3)
    croak = creature(rng, 0.2, 110 * p, 90 * p, (450, 1000, 2400), 5, 0.6, 0.6) * 0.4
    ptoo = bp(noise(rng, 0.08), 600, 4000) * expenv(0.08, 35, 0.002)
    out = place(gur * 0.6, croak, 0.0)
    out = place(out, ptoo, 0.22)
    return place(out, splat(rng, 0.3, p) * 0.7, 0.5 + 0.05 * v)


@sfx("combat/spitter_hit", 2)
def spitter_hit(rng, v):
    d = 1.2
    t = T(d)
    a = expenv(d, 2.8, 0.005)
    siz = hp(noise(rng, d), 3000) * a * (0.6 + 0.4 * smooth_rand(rng, d, 40, 0, 1))
    pops = crackle(rng, d, 500 + 200 * v, a, lo=2000) * 1.8
    sp = splat(rng, 0.25) * 0.8
    tinny = metal_hit(rng, 2600 + 400 * v, 0.3, decay=15, bright=0.5) * 0.15
    return place(siz * 0.6 + pops, sp + tinny[:N(0.25)], 0)


@sfx("combat/brute_attack", 2)
def brute_attack(rng, v):
    p = PV[v]
    d = 1.3
    slam = np.sin(phase(expglide(70 * p, 35, 0.6))) * expenv(0.6, 7, 0.002) * 1.4
    slam = mix(slam, lp(noise(rng, 0.25), 700) * expenv(0.25, 16) * 0.9)
    dirt = grains(rng, 0.4, 250, (0.004, 0.015), 300, 2500) * 0.25
    r = roar(rng, 0.9, 0.85 * p, 0.8)
    out = place(r, slam, 0.12)
    return fit(place(out, dirt, 0.14), d)


@sfx("combat/skywing_attack", 2)
def skywing_attack(rng, v):
    p = PV[v]
    out = np.zeros(1)
    for i in range(3):
        fl = lp(noise(rng, 0.09), 900) * np.sin(np.pi * T(0.09) / 0.09) ** 2
        out = place(out, fl * (0.5 + 0.2 * i), i * 0.11)
    dive = whoosh(rng, 0.5, 400, 2200, 2, 0.8) * 0.6
    sc = screech(rng, 0.45, 2900 * p, 1700 * p, 0.6)
    out = place(out, dive, 0.15)
    return place(out, sc * 0.8, 0.3)


@sfx("combat/brood_death", 3)
def brood_death(rng, v):
    p = PV[v]
    d = 0.5
    sq = creature(rng, d, 900 * p, 300 * p, (1800 * p, 3200 * p, 4500), 6, 0.5, 0.4, shape=0.6, vib=0.05, vibf=30)
    sq *= adsr(d, 0.01, 0.05, 0.8, 0.3)
    col = wet_squelch(rng, 0.5, 600, 260)
    col += np.sin(2 * np.pi * 65 * T(0.5)) * expenv(0.5, 12) * 0.5
    return place(sq, col * 0.8, 0.35)


# =================================================================== C. Combat — Clockwork

@sfx("combat/gearknight_attack", 3)
def gearknight_attack(rng, v):
    p = PV[v]
    sw = whoosh(rng, 0.18, 500 * p, 2600 * p, 2.5, 0.7) * 0.6
    ring = metal_hit(rng, 1450 * p, 0.8, decay=5, bright=0.75) * 1.0
    out = place(sw, ring, 0.15)
    for k in range(3):
        cl = metal_hit(rng, rng.uniform(350, 650), 0.12, decay=40, bright=0.7) * 0.35
        out = place(out, cl, rng.uniform(0.0, 0.22))
    return fit(out, 1.0)


@sfx("combat/bolt_attack", 3)
def bolt_attack(rng, v):
    p = PV[v]
    out = ratchet(rng, 0.2 + 0.03 * v, 24 + 4 * v, 2300 * p, 320) * 0.5
    tw = karplus(rng, 105 * p, 0.6, 0.994, 0.8)
    tw *= expenv(0.6, 5)
    thunk = mix(lp(noise(rng, 0.05), 600) * expenv(0.05, 60), metal_hit(rng, 600, 0.1, decay=30) * 0.4)
    t0 = 0.26 + 0.03 * v
    out = place(out, thunk, t0)
    out = place(out, tw * 0.9, t0)
    out = place(out, whoosh(rng, 0.25, 800, 3000, 2, 0.3) * 0.3, t0 + 0.02)
    return out


@sfx("combat/steam_walker_attack", 2)
def steam_walker_attack(rng, v):
    p = PV[v]
    stomp = mix(np.sin(phase(expglide(80 * p, 40, 0.4))) * expenv(0.4, 10), lp(noise(rng, 0.1), 400) * expenv(0.1, 40))
    bang = metal_hit(rng, 240 * p, 0.6, decay=8, bright=0.8)
    hiss = steam_hiss(rng, 0.9, 0.01, 3.0)
    out = place(stomp, bang, 0.18)
    out = place(out, hiss * 0.5, 0.2)
    out = place(out, lp(noise(rng, 0.2), 1500) * expenv(0.2, 20) * 0.8, 0.18)
    return fit(out, 1.3)


@sfx("combat/tesla_attack", 3)
def tesla_attack(rng, v):
    p = PV[v]
    d = 0.55 + 0.08 * v
    crack = hp(noise(rng, 0.015), 1000) * expenv(0.015, 200, 0.0002) * 1.5
    z = tesla_zap(rng, d, p, 1.0)
    thump = np.sin(2 * np.pi * 60 * T(0.15)) * expenv(0.15, 25) * 0.5
    return drive(place(place(z, crack, 0), thump, 0), 5.0)


@sfx("combat/tesla_deploy")
def tesla_deploy(rng, v):
    d = 1.5
    t = T(d)
    f = 380 + 500 * np.sin(np.pi * np.clip(t / 1.2, 0, 1)) ** 0.7
    servo = bp(bl_saw(f) + 0.3 * np.sin(phase(f * 2.01)), 300, 4000) * adsr(d, 0.05, 0.1, 0.8, 0.35) * 0.25
    r = fit(ratchet(rng, 1.1, 14, 2600, 280), d) * 0.4
    out = servo + r
    for tt in [0.35, 0.8]:
        out = place(out, metal_hit(rng, 420, 0.2, decay=25) * 0.4, tt)
    out = place(out, metal_hit(rng, 180, 0.3, decay=14) * 0.8, 1.2)
    out = place(out, tesla_zap(rng, 0.25) * 0.25, 1.22)
    return fit(out, d)


@sfx("combat/clock_death", 3)
def clock_death(rng, v):
    d = 1.3
    out = metal_hit(rng, 300 * PV[v], 0.4, decay=10) * 0.8
    out = place(out, lp(noise(rng, 0.1), 900) * expenv(0.1, 30), 0)
    n = 10 + 3 * v
    for k in range(n):
        tt = rng.uniform(0.05, 0.9) ** 1.4
        f = rng.uniform(800, 4000)
        out = place(out, metal_hit(rng, f, 0.12, decay=rng.uniform(25, 60), bright=0.7) * rng.uniform(0.15, 0.4), tt)
    for k in range(1 + v % 2 + 1):
        out = place(out, spring_boing(rng, 0.45, rng.uniform(120, 260)) * 0.35, rng.uniform(0.05, 0.4))
    return fit(out, d)


# =================================================================== C. shared

@sfx("combat/explosion_small", 2)
def explosion_small(rng, v):
    return explosion(rng, v, size=0.6, d=0.9, debris=0.6)


@sfx("combat/explosion_big", 2)
def explosion_big(rng, v):
    return explosion(rng, v, size=1.6, d=1.5, debris=2.0)


@sfx("combat/building_collapse", 2)
def building_collapse(rng, v):
    d = 1.5
    t = T(d)
    out = np.zeros(N(d))
    for k in range(5 + 2 * v):
        tt = rng.uniform(0, 0.5)
        crack = hp(noise(rng, 0.05), 800) * expenv(0.05, 60, 0.0005) * rng.uniform(0.3, 0.8)
        out = place(out, crack, tt)
    crumble = grains(rng, d, lambda tt: 600 * np.exp(-((tt - 0.6) / 0.4) ** 2) + 50, (0.005, 0.03), 200, 2500)
    out += fit(crumble, d) * 0.6
    rum = lp(noise(rng, d), 150) * adsr(d, 0.3, 0.3, 0.7, 0.6) * 3
    out += rum * 0.5
    for tt in [0.45 + 0.05 * v, 0.7, 0.95]:
        out = place(out, wood_hit(rng, rng.uniform(90, 160), 0.4, 12) * 0.7, tt)
    return fit(out, d)


@sfx("combat/arrow_whoosh")
def arrow_whoosh(rng, v):
    d = 0.4
    t = T(d)
    fc = 1200 * 2 ** (-1.3 * (t / d - 0.5))
    x = svf_bp(noise(rng, d), fc * 2, 5)
    a = np.exp(-((t - 0.12) / 0.07) ** 2)
    tone = np.sin(phase(fc * 1.5)) * a * 0.15
    return x * a + tone


# =================================================================== D. Work and buildings

def loop2(fn, rng, d=2.0, xf=0.15):
    x = fn(d + xf)
    return loopify(x, d, xf)


@sfx("work/crown_build", peak=-3, kind="wloop")
def crown_build(rng, v):
    def gen(d):
        out = np.zeros(N(d))
        for tt in np.arange(0.05, d, 0.42):
            out = place(out, mix(wood_hit(rng, 260, 0.15, 30), metal_hit(rng, 2100, 0.06, decay=60) * 0.2), tt + rng.uniform(-0.02, 0.02))
        # saw strokes
        t = T(d)
        stroke = np.clip(np.sin(2 * np.pi * 1.4 * t), 0, 1) ** 0.6
        teeth = 1 + 0.8 * np.sin(2 * np.pi * (90 + 30 * np.sin(2 * np.pi * 1.4 * t)) * t)
        saw = bp(noise(rng, d), 1500, 6000) * stroke * teeth * 0.25
        return fit(out, d) + saw
    return loop2(gen, rng)


@sfx("work/farm_harvest", peak=-3)
def farm_harvest(rng, v):
    sw = whoosh(rng, 0.3, 1500, 6000, 1.5, 0.5) * 0.8
    sw += grains(rng, 0.3, 900, (0.002, 0.008), 2000, 7000, env=lambda t: np.sin(np.pi * min(t / 0.3, 1)))[:N(0.3)] * 0.3
    rustle = grains(rng, 0.35, 700, (0.003, 0.02), 800, 5000, env=lambda t: np.exp(-t * 8)) * 0.6
    thud = mix(wood_hit(rng, 120, 0.25, 18) * 0.6, lp(noise(rng, 0.1), 600) * expenv(0.1, 30))
    out = place(sw, rustle, 0.42)
    return place(out, thud, 0.42)


@sfx("work/mill_grind", peak=-3, kind="wloop")
def mill_grind(rng, v):
    def gen(d):
        t = T(d)
        grind = lp(noise(rng, d), 350) * (0.7 + 0.3 * np.sin(2 * np.pi * 1.0 * t)) * 1.5
        grind += bp(noise(rng, d), 600, 2000) * (rng.random(N(d)) > 0.7) * 0.15
        out = grind
        for tt in np.arange(0.2, d, 1.0):
            cr = crown_select_building(rng, 0)
            out = place(out, cr * 0.3, tt)
            out = place(out, wood_hit(rng, 180, 0.2, 20) * 0.4, tt + 0.5)
        return fit(out, d)
    return loop2(gen, rng)


@sfx("work/powder_ready", peak=-3)
def powder_ready(rng, v):
    d = 0.8
    t = T(d)
    roll = lp(noise(rng, d), 250) * (1 + 0.6 * np.sin(2 * np.pi * 9 * t)) * adsr(d, 0.05, 0.1, 0.8, 0.1) * 1.5
    out = roll
    for tt in np.arange(0.0, d, 0.11):
        out = place(out, wood_hit(rng, 200, 0.05, 50) * 0.2, tt)
    out = place(out, mix(wood_hit(rng, 110, 0.35, 15), lp(noise(rng, 0.08), 400) * expenv(0.08, 40)), d)
    return out


@sfx("work/brood_build", peak=-3, kind="wloop")
def brood_build(rng, v):
    def gen(d):
        w = grains(rng, d, 90, (0.02, 0.07), 70, 300, src="bubble")
        t = T(d)
        sl = svf_bp(noise(rng, d), 250 + 300 * smooth_rand(rng, d, 3, 0, 1), 3) * 0.6
        str_ = grains(rng, d, 40, (0.03, 0.08), 300, 1200) * 0.4
        return fit(w, d) * 0.8 + sl + fit(str_, d)
    return loop2(gen, rng)


@sfx("work/grub_feed", peak=-3)
def grub_feed(rng, v):
    out = np.zeros(1)
    for i, tt in enumerate(np.arange(0, 0.8, 0.13)):
        ch = lp(noise(rng, 0.07), 2500) * expenv(0.07, 35, 0.004)
        ch = mix(ch, grains(rng, 0.06, 500, (0.002, 0.008), 1500, 5000) * 0.4, bubble(rng, rng.uniform(300, 600), 0.05, 5) * 0.3)
        out = place(out, ch * rng.uniform(0.6, 1.0), tt + rng.uniform(0, 0.02))
    return out


@sfx("work/grub_deliver", peak=-3)
def grub_deliver(rng, v):
    x = mix(bubble(rng, 180, 0.2, 3, 22), splat(rng, 0.25) * 0.6)
    return x


@sfx("work/midden_essence", peak=-3)
def midden_essence(rng, v):
    d = 1.4
    t = T(d)
    wh = np.zeros(N(d))
    for k in range(3):
        fm = [(smooth_rand(rng, d, 4, 500, 900), 1.0), (smooth_rand(rng, d, 4, 1200, 2200), 0.7), (2800, 0.4)]
        wh += formants(noise(rng, d), fm, 10) * (smooth_rand(rng, d, 5, 0, 1) ** 2)
    wh *= np.sin(np.pi * t / d) * 0.4
    bub = fit(place(grains(rng, d, 10, (0.06, 0.15), 120, 400, src="bubble"), bubble(rng, 200, 0.12, 4), 0), d)
    return reverb(wh + bub * 0.8, rng, 0.8, 0.3)


@sfx("work/clock_build", peak=-3, kind="wloop")
def clock_build(rng, v):
    def gen(d):
        r = fit(ratchet(rng, 0.6, 12, 2300, 280), d)
        r = place(r, ratchet(rng, 0.6, 12, 2400, 280), 1.0)[:N(d)]
        t = T(d)
        weld_env = ((t % 1.0) > 0.6).astype(float)
        weld_env = lp(weld_env, 30)
        sparks = crackle(rng, d, 1500, weld_env, lo=2500) * 1.5
        buzz = bp(bl_saw(np.full(N(d), 100.0)), 200, 4000) * weld_env * 0.08
        return r * 0.6 + sparks + buzz + hp(noise(rng, d), 5000) * weld_env * 0.1
    return loop2(gen, rng)


@sfx("work/winder_crank", peak=-3, kind="wloop")
def winder_crank(rng, v):
    def gen(d):
        r = ratchet(rng, d, 10, 2000, 220)
        t = T(d)
        creak = svf_bp(noise(rng, d), 700 + 300 * np.sin(2 * np.pi * 1.0 * t), 15) * 0.1
        spring = np.sin(phase(150 + 60 * (t % 1.0))) * 0.05
        return fit(r, d) * 0.7 + creak + spring
    return loop2(gen, rng)


@sfx("work/boiler", peak=-3)
def boiler(rng, v):
    d = 2.0
    t = T(d)
    chug = np.zeros(N(d))
    for tt in np.arange(0, 1.4, 0.2):
        c = lp(noise(rng, 0.15), 500) * expenv(0.15, 25, 0.005) + np.sin(2 * np.pi * 55 * T(0.15)) * expenv(0.15, 25) * 0.5
        chug = place(chug, c * 0.8, tt)
    chug = fit(chug, d)
    rel = steam_hiss(rng, 0.8, 0.02, 2.5)
    whistle = reson(noise(rng, 0.8), 1800, 30) * expenv(0.8, 3) * 0.6
    return place(chug, rel + whistle, 1.2)


@sfx("work/crusher", peak=-3)
def crusher(rng, v):
    d = 1.6
    t = T(d)
    roll = lp(noise(rng, d), 120) * 3 + bp(noise(rng, d), 150, 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t))
    crunch = grains(rng, d, lambda tt: 120 + 350 * (np.sin(2 * np.pi * 1.5 * tt) > 0.3), (0.004, 0.02), 400, 4000)
    out = roll * 0.5 + fit(crunch, d) * 0.7
    for tt in [0.2, 0.9]:
        out = place(out, metal_hit(rng, 140, 0.3, decay=12) * 0.25, tt)
    return fit(out, d)


@sfx("work/pylon_charge", peak=-3)
def pylon_charge(rng, v):
    d = 1.5
    t = T(d)
    f = 100 * (1 + 0.6 * (t / d) ** 2)
    hum = bl_saw(f) * 0.3 + np.sin(phase(f)) * 0.7
    hum = lp(hum, 3000) * (0.2 + 0.8 * (t / d) ** 1.2)
    cr = crackle(rng, d, 300, (t / d) ** 3, lo=1500) * 2
    return hum + cr


@sfx("work/husk_power_down", peak=-3)
def husk_power_down(rng, v):
    d = 2.0
    t = T(d)
    f = 520 * np.exp(-t * 1.6) + 20
    whir = bp(bl_saw(f), 80, 4000) * (1 - t / d) ** 1.5 * 0.35
    times, tt = [], 0.0
    while tt < d * 0.85:
        times.append(tt)
        tt += 0.05 * np.exp(tt * 1.8)
    cl = fit(click_train(rng, times, 2500, 250), d) * 0.4 * (1 - t / d)
    return whir + cl + fit(metal_hit(rng, 200, 0.4, decay=8) * 0.2, d) * 0


# =================================================================== E. Ambience (30 s loops)

AMB_LEN = 30.0
AMB_XF = 2.0


def wind(rng, d, base=400, spread=1.5, gust_rate=0.15, amt=1.0, q=1.2):
    t = T(d)
    out = np.zeros(N(d))
    for k in range(3):
        fc = base * (k + 1) ** 0.8 * (1 + 0.4 * spread * smooth_rand(rng, d, gust_rate * 3, -1, 1))
        a = smooth_rand(rng, d, gust_rate * 2, 0.2, 1.0) ** 2
        out += svf_bp(noise(rng, d), fc, q) * a / (k + 1)
    return out * amt


def bird(rng, kind=0):
    d = rng.uniform(0.08, 0.2)
    t = T(d)
    f0 = rng.uniform(2500, 4500)
    if kind == 0:
        f = f0 * (1 + 0.3 * np.sin(2 * np.pi * rng.uniform(15, 40) * t))
    else:
        f = glide(f0, f0 * rng.uniform(0.6, 1.4), d)
    return np.sin(phase(f)) * np.sin(np.pi * t / d) ** 2


def birdsong(rng, d, rate=0.3, amp=0.05):
    out = np.zeros(N(d) + N(2))
    t = rng.uniform(0, 2)
    while t < d:
        n = rng.integers(2, 7)
        kind = rng.integers(0, 2)
        g = amp * rng.uniform(0.3, 1)
        for i in range(n):
            out = place(out, bird(rng, kind) * g, t + i * rng.uniform(0.12, 0.2))
        t += rng.exponential(1 / rate) + 1
    return lp(out[:N(d)], 7000)


def crow(rng):
    d = rng.uniform(0.3, 0.45)
    t = T(d)
    f = 520 * (1 - 0.15 * t / d)
    src = glottal(rng, f, 0.05, 0.4, rough=0.8) + noise(rng, d) * 0.5
    return formants(src, [(1000, 1), (1600, 0.8), (2600, 0.4)], 5) * adsr(d, 0.03, 0.05, 0.8, 0.15)


def frog(rng):
    out = np.zeros(1)
    f0 = rng.uniform(250, 450)
    for i in range(rng.integers(2, 5)):
        d = 0.09
        t = T(d)
        pulses = (np.sin(2 * np.pi * 45 * t) > 0).astype(float)
        src = bl_saw(np.full(N(d), f0)) * lp(pulses, 300)
        c = formants(src, [(f0 * 2, 1), (1200, 0.4)], 6) * np.sin(np.pi * t / d)
        out = place(out, c, i * 0.14)
    return out


def scatter(rng, d, rate, maker, amp, out=None):
    out = np.zeros(N(d) + N(3)) if out is None else out
    t = rng.uniform(0, 3)
    while t < d:
        out = place(out, maker(rng) * amp * rng.uniform(0.4, 1), t)
        t += rng.exponential(1 / rate) + 0.5
    return out[:N(d)]


# Ambience: soft and natural. Everything is low-passed; nothing clicks or crackles in the
# high end (the first versions' leaf "grains" read as static and scratching). Wind is a slow
# swell of dark noise; leaves and sand are gentle gusts of rustle that follow the wind.

def breeze(rng, d, cutoff=600, swell=0.06, amt=1.0):
    """A soft, dark wind that rises and falls slowly."""
    body = lp(lp(noise(rng, d), cutoff, 2), cutoff * 1.4, 2)
    gust = 0.35 + 0.65 * smooth_rand(rng, d, swell, 0, 1) ** 1.5
    low = lp(noise(rng, d), cutoff * 0.35, 2) * 1.6
    return (body + low) * gust * amt


def rustle(rng, d, gust, f0=900, f1=2600, amt=0.05):
    """Leaves or grass stirring: band-limited noise that swells with the wind, no clicks."""
    band = lp(hp(noise(rng, d), f0, 2), f1, 2)
    return band * lp(gust, 3) * amt


@sfx("ambience/grass", peak=-20, kind="loop")
def amb_grass(rng, v):
    d = AMB_LEN + AMB_XF
    gust = smooth_rand(rng, d, 0.08, 0, 1) ** 2
    w = breeze(rng, d, 550, 0.07, 1.0)
    r = rustle(rng, d, gust, 800, 2400, 0.08)
    b = birdsong(rng, d, 0.12, 0.6)
    return w + r + lp(b, 5000) * 0.12


@sfx("ambience/autumn", peak=-20, kind="loop")
def amb_autumn(rng, v):
    d = AMB_LEN + AMB_XF
    gust = smooth_rand(rng, d, 0.07, 0, 1) ** 2
    w = breeze(rng, d, 500, 0.06, 1.0)
    leaves = rustle(rng, d, gust, 700, 2200, 0.11)
    crows = lp(scatter(rng, d, 0.03, crow, 0.12), 2500)      # rare and distant
    return w + leaves + crows


@sfx("ambience/desert", peak=-20, kind="loop")
def amb_desert(rng, v):
    d = AMB_LEN + AMB_XF
    gust = smooth_rand(rng, d, 0.05, 0, 1) ** 2
    w = breeze(rng, d, 420, 0.05, 1.1)
    sand = rustle(rng, d, gust, 1200, 3000, 0.05)
    return w + sand


@sfx("ambience/snow", peak=-20, kind="loop")
def amb_snow(rng, v):
    d = AMB_LEN + AMB_XF
    w = breeze(rng, d, 380, 0.05, 1.0)
    # a low, slow moan of wind over the snow
    moan = svf_bp(noise(rng, d), 260 + 120 * smooth_rand(rng, d, 0.06, 0, 1), 6) * smooth_rand(rng, d, 0.05, 0, 1) ** 2 * 0.5
    return w + lp(moan, 900)


@sfx("ambience/marsh", peak=-20, kind="loop")
def amb_marsh(rng, v):
    d = AMB_LEN + AMB_XF
    w = breeze(rng, d, 350, 0.05, 0.6)
    frogs = lp(scatter(rng, d, 0.35, frog, 0.10), 2500)
    bub = lp(fit(grains(rng, d, 0.8, (0.06, 0.14), 90, 260, src="bubble"), d), 1200) * 0.2
    return w + frogs + bub


@sfx("ambience/volcanic", peak=-20, kind="loop")
def amb_volcanic(rng, v):
    d = AMB_LEN + AMB_XF
    rum = lp(noise(rng, d), 70, 4) * (0.6 + 0.4 * smooth_rand(rng, d, 0.15, 0, 1)) * 8
    bub = lp(fit(grains(rng, d, 0.5, (0.1, 0.25), 50, 120, src="bubble"), d), 600) * 0.4
    w = breeze(rng, d, 450, 0.05, 0.35)
    return rum + bub + w


# =================================================================== main

def seed_for(name):
    return zlib.crc32(name.encode()) & 0xFFFFFFFF


def build(filters):
    made = []
    for path, fn, n, peak, kind in REG:
        if filters and not any(f in path for f in filters):
            continue
        for v in range(n):
            name = f"{path}_{v + 1}" if n > 1 else path
            rng = np.random.default_rng(seed_for(name))
            try:
                x = fn(rng, v)
            except Exception as e:  # report and keep going
                import traceback
                tb = traceback.extract_tb(e.__traceback__)[-1]
                print("FAIL", name, f"line {tb.lineno}: {tb.line}", repr(e)[:120], flush=True)
                continue
            if kind == "loop":
                x = loopify(hp(x, 25), AMB_LEN, AMB_XF)
                x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak / 20)
                write_ogg(os.path.join(OUT, name + ".ogg"), x)
            elif kind == "wloop":   # already seamless (loop2): no trim / fades
                x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak / 20)
                write_wav(os.path.join(OUT, name + ".wav"), x)
            else:
                write_wav(os.path.join(OUT, name + ".wav"), finish(x, peak))
            made.append(name)
            print("ok", name, flush=True)
    return made


if __name__ == "__main__":
    build(sys.argv[1:])
