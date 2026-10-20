"""Orchestral sections for the PocketRTS soundtrack (the overtures and the later faction pieces).

The instruments in synth.py are single players built from a handful of sine partials. These are
*sections*: several slightly detuned, separately vibrating players read from band-limited wavetables
(cheap no matter how many partials), so a chord on "strings" sounds like a string section rather than
an organ. Also orchestral percussion (taiko, concert bass drum, crash/suspended cymbals, gong), chord
helpers that work with absolute chord names ("F#m", "Bb", "Esus") and a mastering chain with a slow
compressor and a look-ahead limiter, so loud climaxes are not squashed into distortion.

Every new instrument is registered in synth.INSTRUMENTS / synth.DRUMS under a new name; nothing that
the older pieces use is changed.
"""
import numpy as np
from scipy.ndimage import minimum_filter1d, uniform_filter1d

import synth
from synth import SR, _t, _lowpass, _bandpass, _highpass, _noise, _formant_weight, VOWEL_A, VOWEL_O, VOWEL_U

_rng = np.random.default_rng(4242)
WT = 2048
_tables = {}


# --------------------------------------------------------------------------- wavetable core

def _table(key, amps):
    """One cycle of sum(a_k * sin(k x)) with WT samples (+1 guard sample for interpolation)."""
    if key not in _tables:
        spec = np.zeros(WT // 2 + 1, complex)
        for k, a in enumerate(amps, start=1):
            if k < WT // 2:
                spec[k] = -1j * a * WT / 2
        tbl = np.fft.irfft(spec, WT)
        _tables[key] = np.append(tbl, tbl[0])
    return _tables[key]


def _osc(tbl, cycles):
    x = (cycles % 1.0) * WT
    i = x.astype(np.int64)
    f = x - i
    return tbl[i] * (1 - f) + tbl[i + 1] * f


def _cycles(freq, n, vib_rate=0.0, vib_depth=0.0, vib_delay=0.3, drift=0.0, scoop=0.0, scoop_t=0.05):
    t = _t(n)
    f = np.full(n, float(freq))
    if vib_depth:
        ramp = np.clip((t - vib_delay) / 0.5, 0, 1)
        f *= 1 + vib_depth * ramp * np.sin(2 * np.pi * vib_rate * t + _rng.uniform(0, 6.28))
    if drift:
        f *= 1 + drift * np.sin(2 * np.pi * _rng.uniform(0.15, 0.45) * t + _rng.uniform(0, 6.28))
    if scoop:
        f *= 1 - scoop * np.exp(-t / scoop_t)
    return np.cumsum(f) / SR + _rng.uniform(0, 1)


def _adsr(nh, n, attack, release, curve=1.0):
    e = np.ones(n)
    a = min(n, max(1, int(attack * SR)))
    e[:a] = np.linspace(0, 1, a) ** curve
    if nh < n:
        e[nh:] *= np.exp(-np.arange(n - nh) / max(1.0, release * SR / 5))
    return e


def _harmonics(freq, top=9000.0):
    return max(1, int(min(SR * 0.42, top) / (freq * 1.012)))


def _section(freq, dur, amps, key, voices, spread, attack, release, cutoff, vib=(5.4, 0.0035), drift=0.0012,
             smear=0.012, scoop=0.0, curve=1.0, scoop_t=0.05):
    nh = int(dur * SR)
    nn = nh + int(release * SR)
    tbl = _table(key, amps)
    out = np.zeros(nn)
    for v in range(voices):
        det = 1 + (v - (voices - 1) / 2) * spread + _rng.normal(0, spread * 0.25)
        off = int(_rng.uniform(0, smear) * SR) if v else 0
        c = _cycles(freq * det, nn - off, vib[0] * _rng.uniform(0.88, 1.12), vib[1], 0.2 + _rng.uniform(0, 0.2),
                    drift, scoop, scoop_t)
        out[off:] += _osc(tbl, c)
    out /= np.sqrt(voices)
    out = _lowpass(out, cutoff)
    return out * _adsr(nh, nn, attack, release, curve)


# --------------------------------------------------------------------------- strings

_BODY = [(290, 110, 0.7), (950, 320, 0.45), (2600, 700, 0.35)]


def _string_amps(freq, bright=1.0):
    h = _harmonics(freq, 6000 + 3000 * bright)
    return [(1.0 / k) * (0.45 + _formant_weight(k * freq, _BODY)) for k in range(1, h + 1)]


def strings(freq, dur, vel=0.7, bright=1.0, voices=5):
    """Bowed string section, legato. Soft notes swell in, loud ones bite."""
    key = ("str", int(freq * 4), bright)
    attack = 0.07 + 0.38 * (1 - vel) ** 1.5
    cutoff = 1400 + 6200 * bright * vel ** 1.4
    s = _section(freq, dur, _string_amps(freq, bright), key, voices, 0.0024, attack, 0.55, cutoff,
                 vib=(5.6, 0.0032), smear=0.018)
    n = len(s)
    bow = _bandpass(_noise(n), min(freq * 2, 5000), min(freq * 9, 12000)) * 0.03 * _adsr(int(dur * SR), n, attack, 0.3)
    return (s + bow) * vel * 0.26


def low_strings(freq, dur, vel=0.7):
    """Celli and basses: darker, a bit more weight in the fundamental."""
    return strings(freq, dur, vel, bright=0.55, voices=4) * 1.25


def spiccato(freq, dur, vel=0.7, bright=1.0):
    """Short bouncing bow strokes for ostinatos (duration is capped)."""
    d = min(dur, 0.22)
    key = ("spc", int(freq * 4), bright)
    s = _section(freq, d, _string_amps(freq, bright), key, 4, 0.0022, 0.008, 0.12, 2200 + 5500 * bright * vel,
                 vib=(5.5, 0.0), drift=0.0006, smear=0.008, curve=0.6)
    n = len(s)
    t = _t(n)
    s *= np.exp(-t * 7.0)
    scrape = _bandpass(_noise(n), 1800, 7000) * np.exp(-t * 60) * 0.25
    return (s + scrape) * vel * 0.34


def pizzicato(freq, dur, vel=0.7):
    return synth._pluck(freq, 0.25, vel, bright=0.35, decay=4.0, ring=0.35, pos=0.27) * 0.42


def tremolo(freq, dur, vel=0.7):
    """Measured bowed tremolo (~11 strokes a second): suspense under the dark pieces."""
    s = strings(freq, dur, vel, bright=0.8, voices=4)
    t = _t(len(s))
    return s * (0.62 + 0.38 * np.abs(np.sin(np.pi * 11 * t + _rng.uniform(0, 3))) ** 0.6)


# --------------------------------------------------------------------------- brass

def horns(freq, dur, vel=0.7):
    """French-horn section: round and warm, opens up when loud."""
    p = 2.4 - 1.15 * vel
    h = _harmonics(freq, 5000)
    key = ("hrn", int(freq * 4), round(vel, 1))
    s = _section(freq, dur, [1.0 / k ** p for k in range(1, h + 1)], key, 4, 0.0016, 0.06 + 0.09 * (1 - vel), 0.35,
                 650 + 2900 * vel ** 1.3, vib=(4.8, 0.0018), drift=0.001, smear=0.02, scoop=0.01)
    return s * vel * 0.32


def trumpets(freq, dur, vel=0.7):
    p = 1.85 - 0.95 * vel
    h = _harmonics(freq, 9000)
    key = ("tpt", int(freq * 4), round(vel, 1))
    s = _section(freq, dur, [1.0 / k ** p for k in range(1, h + 1)], key, 3, 0.0013, 0.03, 0.22,
                 1300 + 5600 * vel ** 1.2, vib=(5.2, 0.0022), smear=0.012, scoop=0.006, scoop_t=0.03)
    n = len(s)
    t = _t(n)
    blat = _bandpass(_noise(n), 900, 3500) * np.exp(-t * 30) * 0.18 * vel
    return (s + blat) * vel * 0.24


def low_brass(freq, dur, vel=0.7):
    """Trombones and tuba: the floor under the climaxes; they rasp when pushed."""
    p = 2.1 - 1.0 * vel
    h = _harmonics(freq, 6000)
    key = ("lbr", int(freq * 4), round(vel, 1))
    s = _section(freq, dur, [1.0 / k ** p for k in range(1, h + 1)], key, 3, 0.0018, 0.05, 0.3,
                 480 + 3000 * vel ** 1.5, vib=(4.5, 0.001), smear=0.015, scoop=0.008)
    drive = 1 + 2.5 * max(0.0, vel - 0.55)
    s = np.tanh(s * drive * 0.8) / (drive * 0.8)
    return s * vel * 0.4


# --------------------------------------------------------------------------- choir

def chorus(freq, dur, vel=0.7, vowel=VOWEL_A, voices=6):
    """A massed choir: six voices per note on a vowel."""
    h = _harmonics(freq, 5200)
    amps = [_formant_weight(k * freq, vowel) / k ** 0.3 for k in range(1, h + 1)]
    key = ("cho", int(freq * 4), id(vowel))
    attack = 0.18 + 0.25 * (1 - vel)
    s = _section(freq, dur, amps, key, voices, 0.0038, attack, 0.75, 5200, vib=(5.1, 0.0045), drift=0.002,
                 smear=0.05)
    n = len(s)
    breath = _bandpass(_noise(n), 700, 3500) * 0.02 * _adsr(int(dur * SR), n, attack, 0.5)
    return (s + breath) * vel * 0.36


# --------------------------------------------------------------------------- woodwinds, keys

def flute(freq, dur, vel=0.7):
    nh = int(dur * SR)
    nn = nh + int(0.18 * SR)
    t = _t(nn)
    c = _cycles(freq, nn, 5.0, 0.004, 0.3, 0.0008)
    s = np.sin(2 * np.pi * c) + 0.22 * np.sin(4 * np.pi * c) + 0.07 * np.sin(6 * np.pi * c)
    breath = _bandpass(_noise(nn), freq * 0.8, freq * 3.5) * 0.12
    chiff = np.exp(-t * 35) * _bandpass(_noise(nn), 1500, 6000) * 0.12
    return (s + breath + chiff) * _adsr(nh, nn, 0.05, 0.18) * vel * 0.34


def oboe(freq, dur, vel=0.7):
    h = _harmonics(freq, 7000)
    amps = [(_formant_weight(k * freq, [(1150, 380, 1.0), (2900, 700, 0.35)]) + 0.08) / k ** 0.55 for k in range(1, h + 1)]
    s = _section(freq, dur, amps, ("obo", int(freq * 4)), 1, 0.0, 0.04, 0.15, 5500, vib=(5.4, 0.0045), drift=0.0008)
    return s * vel * 0.32


def clarinet(freq, dur, vel=0.7):
    h = _harmonics(freq, 6000)
    amps = [(1.0 if k % 2 else 0.12) / k for k in range(1, h + 1)]
    s = _section(freq, dur, amps, ("cla", int(freq * 4)), 1, 0.0, 0.045, 0.18, 1800 + 2600 * vel, vib=(4.8, 0.002))
    return s * vel * 0.3


def celesta(freq, dur, vel=0.7):
    n = int(max(dur, 1.8) * SR)
    t = _t(n)
    c = _cycles(freq, n)
    s = (np.sin(2 * np.pi * c) * np.exp(-t * 1.6) + 0.3 * np.sin(8 * np.pi * c) * np.exp(-t * 5)
         + 0.08 * np.sin(2 * np.pi * 9.8 * c) * np.exp(-t * 12))
    s += _highpass(_noise(n), 4000) * np.exp(-t * 200) * 0.15
    a = int(0.002 * SR)
    s[:a] *= np.linspace(0, 1, a)
    return s * vel * 0.26


def cymbal_swell(freq, dur, vel=0.7):
    """Suspended cymbal rolled with soft mallets: grows over `dur`, then rings off. (freq is ignored)"""
    nh = int(dur * SR)
    nn = nh + int(1.4 * SR)
    t = _t(nn)
    env = np.where(t < dur, (t / max(dur, 1e-3)) ** 2.5, np.exp(-(t - dur) * 3.0))
    s = _highpass(_noise(nn), 2800) * 0.8 + _bandpass(_noise(nn), 900, 3000) * 0.25
    return s * env * vel * 0.16


synth.INSTRUMENTS.update({
    "strings": strings, "lowstr": low_strings, "spicc": spiccato, "pizz": pizzicato, "trem": tremolo,
    "horns": horns, "tpts": trumpets, "lowbr": low_brass,
    "chorus": chorus, "chorus_o": lambda f, d, v=0.7: chorus(f, d, v, VOWEL_O),
    "chorus_u": lambda f, d, v=0.7: chorus(f, d, v, VOWEL_U),
    "flute": flute, "oboe": oboe, "clar": clarinet, "celesta": celesta, "cymswell": cymbal_swell,
})


# --------------------------------------------------------------------------- percussion

def taiko(vel=0.8):
    n = int(2.0 * SR)
    t = _t(n)
    f = 44 + 64 * np.exp(-t * 22)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.8)
    body += np.sin(2 * np.pi * np.cumsum(f * 1.58) / SR) * np.exp(-t * 6) * 0.25
    skin = _lowpass(_noise(n), 1400) * np.exp(-t * 38) * 0.7
    return (body + skin) * vel * 0.62


def concert_bass_drum(vel=0.8):
    n = int(2.4 * SR)
    t = _t(n)
    f = 36 + 18 * np.exp(-t * 14)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6)
    thump = _lowpass(_noise(n), 380) * np.exp(-t * 18) * 0.6
    s = body + thump
    a = int(0.004 * SR)
    s[:a] *= np.linspace(0, 1, a)
    return s * vel * 0.85


def _metal(n, lo, hi, count, d0, d1, seed):
    r = np.random.default_rng(seed)
    t = _t(n)
    out = np.zeros(n)
    for _ in range(count):
        f = r.uniform(lo, hi)
        out += np.sin(2 * np.pi * f * t + r.uniform(0, 6.28)) * np.exp(-t * r.uniform(d0, d1)) * r.uniform(0.3, 1)
    return out / np.sqrt(count)


def crash(vel=0.8):
    n = int(3.2 * SR)
    t = _t(n)
    s = _highpass(_noise(n), 2600) * np.exp(-t * 1.5) * 0.9
    s += _highpass(_noise(n), 6000) * np.exp(-t * 18) * 0.8
    s += _metal(n, 3000, 11000, 40, 1.0, 3.5, 7) * 0.5
    s += _bandpass(_noise(n), 500, 2000) * np.exp(-t * 10) * 0.3
    return s * vel * 0.2


def sus_cymbal(vel=0.8):
    n = int(0.7 * SR)
    t = _t(n)
    s = _highpass(_noise(n), 3500) * np.minimum(1, t / 0.004) * np.exp(-t * 5)
    return s * vel * 0.1


def gong(vel=0.8):
    n = int(6.0 * SR)
    t = _t(n)
    f0 = 58.0
    s = np.zeros(n)
    for r, a, d, bloom in [(1, 1.0, 0.5, 0.0), (1.47, 0.6, 0.7, 0.6), (2.03, 0.5, 0.8, 1.0), (2.56, 0.45, 0.9, 1.2),
                           (3.12, 0.35, 1.1, 1.5), (3.94, 0.3, 1.3, 1.8), (4.66, 0.22, 1.6, 2.0), (5.43, 0.18, 2.0, 2.2),
                           (6.8, 0.12, 2.6, 2.5), (8.3, 0.08, 3.0, 2.8)]:
        env = np.exp(-t * d) * (1 - np.exp(-t * (8.0 / (1 + bloom))))
        s += a * np.sin(2 * np.pi * f0 * r * t + _rng.uniform(0, 6.28)) * env
    s += _lowpass(_noise(n), 300) * np.exp(-t * 12) * 0.5
    s += _metal(n, 600, 3000, 20, 0.6, 1.5, 11) * (1 - np.exp(-t * 2)) * 0.4
    return s * vel * 0.35


def low_tom(vel=0.8):
    n = int(0.8 * SR)
    t = _t(n)
    f = 88 + 55 * np.exp(-t * 25)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    s += _lowpass(_noise(n), 2000) * np.exp(-t * 35) * 0.4
    return s * vel * 0.55


def hammer(vel=0.8):
    """Clockwork: a steam hammer on an iron plate - a deep thud, a clang and a hiss."""
    n = int(1.6 * SR)
    t = _t(n)
    f = 50 + 70 * np.exp(-t * 30)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4.5)
    clang = _metal(n, 380, 2600, 14, 3.0, 7.0, 23) * 0.9
    hiss = _bandpass(_noise(n), 2500, 9000) * (t > 0.05) * np.exp(-np.clip(t - 0.05, 0, None) * 6) * 0.2
    s = thud + clang + _bandpass(_noise(n), 300, 3000) * np.exp(-t * 50) * 0.5 + hiss
    return s * vel * 0.6


synth.DRUMS.update({"T": taiko, "b": concert_bass_drum, "Y": crash, "y": sus_cymbal, "G": gong, "l": low_tom,
                    "m": hammer})


# --------------------------------------------------------------------------- chords

PCN = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
QUAL = {"": (0, 4, 7), "m": (0, 3, 7), "5": (0, 7), "sus": (0, 5, 7), "sus2": (0, 2, 7), "dim": (0, 3, 6),
        "+": (0, 4, 8), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11), "add9": (0, 4, 7, 14),
        "madd9": (0, 3, 7, 14), "m6": (0, 3, 7, 9), "6": (0, 4, 7, 9), "7sus": (0, 5, 7, 10)}


def chord(name):
    """'F#m7' -> (root pitch class, intervals); an optional '/X' bass is returned third."""
    bass = None
    if "/" in name:
        name, b = name.split("/")
        bass = chord(b)[0]
    r = PCN[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        r += 1 if name[i] == "#" else -1
        i += 1
    return r % 12, QUAL[name[i:]], bass


def transpose(chords, k):
    out = []
    for c in chords:
        if not c:
            out.append(c)
            continue
        r, _, bass = chord(c)
        q = c.split("/")[0]
        i = 1
        while i < len(q) and q[i] in "#b":
            i += 1
        nm = NAMES[(r + k) % 12] + q[i:]
        if bass is not None:
            nm += "/" + NAMES[(bass + k) % 12]
        out.append(nm)
    return out


def voicing(name, center, count):
    """`count` chord tones stacked upward from just below `center` (a closed voicing)."""
    r, iv, _ = chord(name)
    pcs = {(r + x) % 12 for x in iv}
    cands = [m for m in range(center - 4, center + 30) if m % 12 in pcs]
    return cands[:count]


def bass_of(name, lo=36):
    r, _, bass = chord(name)
    pc = bass if bass is not None else r
    return lo + (pc - lo) % 12


def rel_interval(tok, iv):
    """Chord-relative degree for bass lines: 1 3 5 7 8 (and 2 4 6), ',' an octave down, "'" up."""
    octv = tok.count("'") - tok.count(",")
    tok = tok.strip("',")
    third = next((x for x in iv if x in (3, 4)), 4)
    fifth = next((x for x in iv if x in (6, 7, 8)), 7)
    sev = next((x for x in iv if x in (10, 11)), 10)
    base = {"1": 0, "2": 2, "3": third, "4": 5, "5": fifth, "6": 9, "7": sev, "8": 12}[tok]
    return base + 12 * octv


# --------------------------------------------------------------------------- mastering

def master_epic(l, r, target=0.16, ceiling=0.89, comp_ratio=2.2):
    """Slow compressor (tames the climaxes), loudness to `target` median RMS, look-ahead limiter."""
    # a little air: ~+2 dB shelf above 2.5 kHz (synthetic sections are darker than real ones)
    l, r = l + 0.25 * _highpass(l, 2500), r + 0.25 * _highpass(r, 2500)
    pk = max(np.max(np.abs(l)), np.max(np.abs(r)), 1e-9)
    l, r = l / pk, r / pk
    mono = (l + r) * 0.5
    # slow RMS compressor above the 80th percentile level
    lev = np.sqrt(uniform_filter1d(mono ** 2, int(0.35 * SR)) + 1e-10)
    db = 20 * np.log10(lev)
    active = db[db > -50]
    thr = np.percentile(active, 80) if len(active) else -20
    red = np.where(db > thr, (db - thr) * (1 - 1 / comp_ratio), 0.0)
    red = uniform_filter1d(red, int(0.25 * SR))
    g = 10 ** (-red / 20)
    l, r = l * g, r * g
    # loudness
    mono = (l + r) * 0.5
    win = SR // 2
    frames = np.array([np.sqrt(np.mean(mono[i:i + win] ** 2)) for i in range(0, len(mono) - win, win)])
    frames = frames[frames > 0.005]
    loud = float(np.median(frames)) if len(frames) else 0.1
    gain = target / max(loud, 1e-4)
    # do not let the loudest passages go beyond ~+5 dB over the target before limiting
    if len(frames):
        top = float(np.percentile(frames, 97)) * gain
        if top > target * 1.8:
            gain *= target * 1.8 / top
    l, r = l * gain, r * gain
    # look-ahead brickwall limiter (min-filter then box-smooth: never above the ceiling)
    L = int(0.03 * SR) | 1
    env = np.maximum(np.abs(l), np.abs(r))
    gt = np.minimum(1.0, ceiling / np.maximum(env, 1e-9))
    gl = uniform_filter1d(minimum_filter1d(gt, L), L)
    l, r = l * gl, r * gl
    l, r = np.clip(l, -ceiling, ceiling), np.clip(r, -ceiling, ceiling)
    # trim the silent tail, short fades
    loud_idx = np.where(np.abs((l + r) * 0.5) > 0.0015)[0]
    cut = min(len(l), (loud_idx[-1] if len(loud_idx) else len(l)) + int(0.3 * SR))
    l, r = l[:cut].copy(), r[:cut].copy()
    f = int(0.01 * SR)
    fo = int(1.2 * SR)
    for ch in (l, r):
        ch[:f] *= np.linspace(0, 1, f)
        ch[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    return l, r
