"""PocketRTS soundtrack: hand-written pieces for the menu and for each faction.

Every faction has five calm pieces (<f>_peace, <f>_peace_2.._5) and five battle pieces (<f>_battle,
<f>_battle_2.._5; the game cross-fades to one when fighting breaks out), plus a victory sting; there is
one shared defeat sting. The main menu shuffles five overtures (menu, menu_2.._5). The titles of all
pieces go to scripts/music_tracks.gd.

The later pieces (menu_2.., <f>_peace_5, <f>_battle_4/5) are orchestral: they use the string, brass and
choir sections, orchestral percussion and the mastering chain from orchestra.py (Song(mastering="epic")).

  The Crown      17th-century pike-and-shot: lute, recorder (fife), shawm, horns, snare and timpani.
  The Brood      the swamp: buzzing drones, a low "throat" choir, log drums, big drums, phrygian modes.
  The Clockwork  music boxes and machinery: glass chimes, dulcimer, reedy regal, ticks, anvils, steam;
                 played dead on the grid (no human timing), the battle piece in 7/8.

Usage: python3 tools/music/compose.py [name ...]   -> assets/music/<name>.ogg (+ scripts/music_tracks.gd)
       python3 tools/music/compose.py --tracks       -> only rewrite scripts/music_tracks.gd
Needs numpy, scipy and ffmpeg. The instrument library (synth.py) is shared with TCG-RPG.
"""
import os
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import synth  # noqa: E402
import orchestra  # noqa: E402,F401  (registers the orchestral sections and percussion)
from orchestra import chord, transpose, voicing, bass_of, rel_interval  # noqa: E402
from synth import SR, _t, _env, _phase, _additive, _lowpass, _bandpass, _highpass, _noise  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "music")

MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "phrygian_dom": [0, 1, 4, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "locrian": [0, 1, 3, 5, 6, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
}
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name, octave):
    return 12 * (octave + 1) + NOTE[name]


# --------------------------------------------------------------------------- extra instruments

def throat(freq, dur, vel=0.8):
    """Brood: a low, growling throat-drone (saw through a wobbling low-pass)."""
    nh = int(dur * SR)
    nn = nh + int(0.4 * SR)
    t = _t(nn)
    ph = _phase(freq, nn, 4.5, 0.008, 0.1, drift=0.004)
    s = _additive(ph, [(k, 1.0 / k, 0) for k in range(1, 24)], freq, t)
    wob = 500 + 350 * np.sin(2 * np.pi * 0.7 * t)
    lo = _lowpass(s, 380)
    hi = _bandpass(s, 400, 1400)
    s = lo + hi * (wob - 150) / 700 * 0.6
    s += _bandpass(_noise(nn), 200, 900) * 0.04
    return s * _env(nh, 0.12, 0.4, nn) * vel * 0.3


def log_drum(freq, dur, vel=0.8):
    """Brood: hollow wooden log, pitched."""
    nn = int(0.7 * SR)
    t = _t(nn)
    ph = _phase(freq, nn)
    s = _additive(ph, [(1, 1, 9), (2.0, 0.25, 16), (3.9, 0.12, 25)], freq, t)
    s += _bandpass(_noise(nn), 500, 2500) * np.exp(-t * 90) * 0.4
    return s * vel * 0.5


def music_box(freq, dur, vel=0.8):
    """Clockwork: a steel comb tine."""
    nn = int(max(dur, 1.6) * SR)
    t = _t(nn)
    ph = _phase(freq, nn)
    s = _additive(ph, [(1, 1, 1.6), (3.0, 0.18, 6), (5.8, 0.09, 10), (9.1, 0.04, 14)], freq, t)
    s += _highpass(_noise(nn), 5000) * np.exp(-t * 300) * 0.3
    return s * vel * 0.24


def brass(freq, dur, vel=0.8):
    """Crown: a brighter natural trumpet for fanfares."""
    nh = int(dur * SR)
    nn = nh + int(0.15 * SR)
    t = _t(nn)
    ph = _phase(freq, nn, 5.5, 0.004, 0.3)
    bright = 0.5 + 0.5 * vel
    s = _additive(ph, [(k, (1.0 / k ** (1.4 - bright * 0.5)), 0) for k in range(1, 12)], freq, t)
    s = _lowpass(s, 900 + 2600 * bright)
    blat = np.exp(-t * 25) * _bandpass(_noise(nn), 800, 3000) * 0.12
    return (s + blat) * _env(nh, 0.03, 0.12, nn) * vel * 0.28


def steam(vel=0.8):
    nn = int(0.5 * SR)
    t = _t(nn)
    e = np.minimum(1, t / 0.02) * np.exp(-t * 7)
    return _bandpass(_noise(nn), 2500, 9000) * e * vel * 0.18


def clank(vel=0.8):
    nn = int(0.4 * SR)
    t = _t(nn)
    ph = 2 * np.pi * 310 * t
    s = _additive(ph, [(1, 1, 14), (2.3, 0.8, 18), (3.7, 0.6, 22), (5.1, 0.4, 30)], 310, t)
    s += _bandpass(_noise(nn), 1500, 6000) * np.exp(-t * 50) * 0.5
    return s * vel * 0.3


def shaker(vel=0.8):
    nn = int(0.12 * SR)
    t = _t(nn)
    e = np.minimum(1, t / 0.015) * np.exp(-t * 40)
    return _highpass(_noise(nn), 4000) * e * vel * 0.16


synth.INSTRUMENTS.update({"throat": throat, "log": log_drum, "musicbox": music_box, "brass": brass})
synth.DRUMS.update({"h": steam, "c": clank, "x": shaker,
                    "K": lambda v: synth.big_drum(v * 0.8), "S": lambda v: synth.tabor(v * 1.3)})


# --- added for the second set of pieces (the first set never calls these)

def harpsichord(freq, dur, vel=0.8):
    """Crown: quilled harpsichord, an 8' and a 4' choir plucked together."""
    d = max(dur, 0.25)
    a = synth._pluck(freq, d, vel, bright=1.2, decay=2.4, ring=0.3, inharm=0.00004, pos=0.07)
    b = synth._pluck(freq * 2.003, d, vel, bright=1.0, decay=3.0, ring=0.3, pos=0.11)
    m = min(len(a), len(b))
    s = a[:m] + 0.3 * b[:m]
    t = _t(m)
    s += _highpass(_noise(m), 2500) * np.exp(-t * 250) * 0.12 * vel
    return _highpass(s, 90) * 0.2


def bone_flute(freq, dur, vel=0.8):
    """Brood: a breathy, scooping reed/bone flute."""
    nh = int(dur * SR)
    nn = nh + int(0.25 * SR)
    t = _t(nn)
    scoop = 1 - 0.035 * np.exp(-t * 14)
    vib = 1 + 0.01 * np.clip((t - 0.25) / 0.5, 0, 1) * np.sin(2 * np.pi * 4.2 * t)
    ph = 2 * np.pi * np.cumsum(freq * scoop * vib) / SR
    s = np.sin(ph) + 0.1 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    breath = _bandpass(_noise(nn), freq * 0.9, freq * 3) * 0.7
    puff = np.exp(-t * 30) * _bandpass(_noise(nn), 1500, 6000) * 0.25
    return (s + breath + puff) * _env(nh, 0.07, 0.22, nn) * vel * 0.36


def volt(freq, dur, vel=0.8):
    """Clockwork: an electrical buzz - square wave with mains hum and crackle."""
    nh = int(dur * SR)
    nn = nh + int(0.12 * SR)
    t = _t(nn)
    ph = _phase(freq, nn)
    s = _additive(ph, [(k, 1.0 / k, 0) for k in range(1, 26, 2)], freq, t)
    s *= 1 + 0.35 * np.sin(2 * np.pi * 50 * t)
    s = _bandpass(s, 80, 2600)
    crack = _highpass(_noise(nn), 4000) * (np.abs(_noise(nn)) > 3.0) * 0.6
    return (s + crack) * _env(nh, 0.008, 0.1, nn) * vel * 0.2


def croak(vel=0.8):
    nn = int(0.32 * SR)
    t = _t(nn)
    f = 95 - 25 * t / 0.32
    saw = 2 * ((np.cumsum(f) / SR) % 1) - 1
    rasp = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 24 * t))
    s = _bandpass(saw * rasp, 250, 1400)
    return s * np.minimum(1, t / 0.015) * np.exp(-t * 7) * vel * 0.5


def bubble(vel=0.8, base=420):
    nn = int(0.14 * SR)
    t = _t(nn)
    f = base * (1 + 1.6 * (1 - np.exp(-t * 35)))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, t / 0.003) * np.exp(-t * 30) * vel * 0.3


def insect(vel=0.8):
    nn = int(0.22 * SR)
    t = _t(nn)
    am = (0.5 + 0.5 * np.sin(2 * np.pi * 48 * t)) ** 4
    s = np.sin(2 * np.pi * 4300 * t + 0.4 * np.sin(2 * np.pi * 48 * t)) * am
    return s * np.minimum(1, t / 0.02) * np.exp(-t * 9) * vel * 0.12


def piston(vel=0.8):
    nn = int(0.5 * SR)
    t = _t(nn)
    f = 55 + 45 * np.exp(-t * 28)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    knock = _bandpass(_noise(nn), 400, 1800) * np.exp(-t * 60) * 0.4
    td = np.clip(t - 0.07, 0, None)
    puff = _bandpass(_noise(nn), 2000, 7000) * (t > 0.07) * np.minimum(1, td / 0.01) * np.exp(-td * 13) * 0.22
    return (body + knock + puff) * vel * 0.55


def ratchet(vel=0.8):
    nn = int(0.2 * SR)
    out = np.zeros(nn)
    for i in range(7):
        c = synth.tick(1.0 - i * 0.1)
        o = int(i * 0.024 * SR)
        out[o:o + len(c)] += c[:nn - o]
    return out * vel * 0.9


def spark(vel=0.8):
    nn = int(0.25 * SR)
    t = _t(nn)
    crack = _highpass(_noise(nn), 3500) * (np.abs(_noise(nn)) > 1.6) * np.exp(-t * 18)
    buzz = _bandpass(np.sign(np.sin(2 * np.pi * 100 * t)), 200, 3000) * np.exp(-t * 14) * 0.35
    return (crack * 0.5 + buzz) * vel * 0.35


synth.INSTRUMENTS.update({"harpsi": harpsichord, "boneflute": bone_flute, "volt": volt})
synth.DRUMS.update({"q": croak, "w": bubble, "W": lambda v: bubble(v, 260), "z": insect,
                    "p": piston, "r": ratchet, "e": spark})


# --------------------------------------------------------------------------- score

class Song:
    def __init__(self, name, title, bpm, meter, tonic, mode, reverb=(2.0, 0.4), humanize=0.006, seed=1,
                 q=3, ceiling=0.89, mastering="classic", predelay=0.0, target=0.16):
        self.name, self.title, self.q, self.ceiling = name, title, q, ceiling
        self.mastering, self.predelay, self.target = mastering, predelay, target
        self.bpm, self.meter, self.tonic, self.mode = bpm, meter, tonic, mode
        self.reverb, self.humanize = reverb, humanize
        self.rng = np.random.default_rng(seed)
        self.ev = []      # (seconds, kind, inst/code, midi, dur_s, vel, pan, send)

    # time
    def sec(self, beat):
        return beat * 60.0 / self.bpm

    def bar(self, b):
        return b * self.meter

    def pitch(self, di, acc=0, tonic=None, mode=None):
        o, d = divmod(di, 7)
        return (tonic if tonic is not None else self.tonic) + MODES[mode or self.mode][d] + 12 * o + acc

    def note(self, inst, beat, dur, midi, vel=0.7, pan=0.0, send=0.3, shape=None):
        """shape: None, or a dynamic over the note - "swell" (crescendo), "dim", "fp" (forte-piano),
        "fpc" (forte-piano then crescendo), "arc" (swell up and back)."""
        j = self.rng.normal(0, self.humanize) if self.humanize else 0.0
        v = float(np.clip(vel + (self.rng.normal(0, 0.04) if self.humanize else 0), 0.05, 1.0))
        e = (max(0.0, self.sec(beat) + j), "n", inst, midi, self.sec(dur), v, pan, send)
        self.ev.append(e + (shape,) if shape else e)

    def hit(self, code, beat, vel=0.7, pan=0.0, send=0.15):
        j = self.rng.normal(0, self.humanize * 0.7) if self.humanize else 0.0
        v = float(np.clip(vel + (self.rng.normal(0, 0.05) if self.humanize else 0), 0.05, 1.0))
        self.ev.append((max(0.0, self.sec(beat) + j), "d", code, 0, 0, v, pan, send))

    @staticmethod
    def parse(bar):
        """'1:1 5:0.5 6\\':2 r:1' -> [(offset, dur, degree_index, accidental)]"""
        evs, pos = [], 0.0
        for tok in bar.split():
            deg, dur = tok.split(":")
            dur = float(dur)
            if deg == "r":
                pos += dur
                continue
            acc = octv = 0
            while deg and deg[-1] in "',+-":
                c = deg[-1]
                octv += {"'": 1, ",": -1}.get(c, 0)
                acc += {"+": 1, "-": -1}.get(c, 0)
                deg = deg[:-1]
            evs.append((pos, dur, int(deg) - 1 + 7 * octv, acc))
            pos += dur
        return evs

    def mel(self, inst, bar0, bars, vel=0.7, octave=0, pan=0.0, send=0.3, legato=0.95, accent=0.08,
            tonic=None, mode=None, dshift=0, shape=None, shape_min=2.0):
        """dshift moves the whole line by scale steps (2 = a diatonic third above).
        shape (see note) is given to the notes at least shape_min beats long."""
        for i, b in enumerate(bars):
            for off, dur, di, acc in self.parse(b):
                strong = off % 1 == 0 and int(off) % 2 == 0
                self.note(inst, self.bar(bar0 + i) + off, dur * legato,
                          self.pitch(di + dshift, acc, tonic, mode) + 12 * octave,
                          vel + (accent if strong else 0), pan, send, shape if dur >= shape_min else None)
        return bar0 + len(bars)

    def tones(self, root, idx):
        return [root, root + 2, root + 4, root + 7, root + 9, root + 11, root + 14][idx]

    def pad(self, inst, bar0, roots, vel=0.4, octave=-1, pan=0.0, send=0.5, voicing=(0, 1, 2), bars_each=1):
        for i, r in enumerate(roots):
            for k, v in enumerate(voicing):
                self.note(inst, self.bar(bar0 + i * bars_each), self.meter * bars_each * 0.98,
                          self.pitch(self.tones(r, v)) + 12 * octave, vel,
                          pan + (k - 1) * 0.25, send)
        return bar0 + len(roots) * bars_each

    def arp(self, inst, bar0, roots, pattern, step, vel=0.5, octave=0, pan=0.0, send=0.3, legato=1.6):
        """pattern: chord-tone indices per step ('-' = rest), repeated across each bar."""
        steps = int(round(self.meter / step))
        for i, r in enumerate(roots):
            for s in range(steps):
                p = pattern[s % len(pattern)]
                if p == "-":
                    continue
                self.note(inst, self.bar(bar0 + i) + s * step, step * legato,
                          self.pitch(self.tones(r, int(p))) + 12 * octave,
                          vel + (0.1 if s == 0 else 0), pan, send)
        return bar0 + len(roots)

    def rel(self, inst, bar0, roots, rhythm, vel=0.6, octave=-1, pan=0.0, send=0.15, legato=0.9):
        """A line relative to each bar's chord root (1 = root, 5 = fifth, 8 = octave)."""
        for i, r in enumerate(roots):
            for off, dur, di, acc in self.parse(rhythm):
                self.note(inst, self.bar(bar0 + i) + off, dur * legato,
                          self.pitch(r + di, acc) + 12 * octave, vel, pan, send)
        return bar0 + len(roots)

    def drums(self, bar0, nbars, lines, vel=0.7, send=0.12, fill=None):
        """lines: {pattern: pan}; each pattern one bar of drum codes / '.' (rests)."""
        for b in range(nbars):
            pats = lines if not (fill and b == nbars - 1) else fill
            for pat, pan in pats.items():
                step = self.meter / len(pat)
                for s, c in enumerate(pat):
                    if c == ".":
                        continue
                    acc = 0.12 if s == 0 else 0.0
                    self.hit(c, self.bar(bar0 + b) + s * step, vel + acc, pan, send)
        return bar0 + nbars

    def timp(self, beat, di, vel=0.7, octave=-2):
        self.note("timpani", beat, 1.0, self.pitch(di) + 12 * octave, vel, 0.0, 0.25)

    def roll(self, code, beat0, beats, step, v0, v1, pan=0.0, send=0.12):
        """A drum roll / crescendo (or decrescendo) from v0 to v1."""
        k = max(1, int(round(beats / step)))
        for i in range(k):
            self.hit(code, beat0 + i * step, v0 + (v1 - v0) * i / max(1, k - 1), pan, send)

    def scatter(self, bar0, nbars, lo, hi, fn, grid=0.25):
        """Call fn(beat, rng) at lo..hi random grid positions in every bar (bubbles, rain, insects)."""
        cells = int(round(self.meter / grid))
        for b in range(bar0, bar0 + nbars):
            k = int(self.rng.integers(lo, hi + 1))
            for c in sorted(self.rng.choice(cells, size=min(k, cells), replace=False)):
                fn(self.bar(b) + c * grid, self.rng)

    # render
    def render(self):
        synth.clear_cache()
        end = max(e[0] + e[4] for e in self.ev) + 3.5
        L = np.zeros(int(end * SR) + SR)
        R = np.zeros_like(L)
        send = np.zeros_like(L)
        for e in self.ev:
            t0, kind, inst, midi, dur, vel, pan, snd = e[:8]
            x = synth.render_note(inst, midi, dur, vel) if kind == "n" else synth.render_drum(inst, vel)
            if len(e) > 8:
                x = x * _shape_curve(e[8], len(x), dur)
            i = int(t0 * SR)
            x = x[: len(L) - i]
            a = (pan + 1) * np.pi / 4
            L[i:i + len(x)] += x * np.cos(a)
            R[i:i + len(x)] += x * np.sin(a)
            send[i:i + len(x)] += x * snd
        if self.predelay:
            send = np.concatenate([np.zeros(int(self.predelay * SR)), send])[:len(L)]
        ir = synth.reverb_ir(*self.reverb)
        L, R = synth.apply_reverb(L, R, send, ir)
        if self.mastering == "epic":
            # a lower ceiling: the limited peaks are sharp and Vorbis overshoots them by ~10%
            return orchestra.master_epic(L, R, self.target, min(self.ceiling, 0.84))
        return master(L, R, ceiling=self.ceiling)


def _shape_curve(kind, n, dur):
    """A gain curve over a rendered note of n samples whose held part lasts dur seconds."""
    t = np.arange(n) / SR
    u = np.clip(t / max(dur, 1e-3), 0, 1)
    if kind == "swell":
        return 0.18 + 0.82 * u ** 1.6
    if kind == "dim":
        return 1.0 - 0.8 * u ** 0.8
    if kind == "fp":
        return 0.35 + 0.65 * np.exp(-t / 0.12)
    if kind == "fpc":
        return np.maximum(0.3 + 0.7 * np.exp(-t / 0.1), 0.3 + 0.75 * u ** 2)
    if kind == "arc":
        return 0.25 + 0.75 * np.sin(np.pi * u) ** 1.2
    return np.ones(n)


def master(l, r, target_rms=0.17, ceiling=0.89):
    pk = max(np.max(np.abs(l)), np.max(np.abs(r)), 1e-9)
    l, r = l / pk, r / pk
    mono = (l + r) * 0.5
    win = SR // 2
    frames = [np.sqrt(np.mean(mono[i:i + win] ** 2)) for i in range(0, len(mono) - win, win)]
    loud = float(np.median([f for f in frames if f > 0.01] or [0.1]))
    g = float(np.clip(target_rms / max(loud, 1e-4), 0.5, 6.0))
    l, r = np.tanh(l * g * 1.1) / 1.1, np.tanh(r * g * 1.1) / 1.1
    pk = max(np.max(np.abs(l)), np.max(np.abs(r)), 1e-9)
    if pk > ceiling:
        l, r = l * ceiling / pk, r * ceiling / pk
    # trim trailing silence, short fades (the game loops the pieces)
    loud_idx = np.where(np.abs(mono) > 0.002)[0]
    cut = min(len(l), (loud_idx[-1] if len(loud_idx) else len(l)) + int(0.3 * SR))
    l, r = l[:cut], r[:cut]
    f = int(0.01 * SR)
    for ch in (l, r):
        ch[:f] *= np.linspace(0, 1, f)
        ch[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))
    return l, r


def write_ogg(name, L, R, q=3):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    data = np.stack([L, R], 1)
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(q),
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)


# =========================================================================== THE CROWN

def crown_peace():
    s = Song("crown_peace", "The King's Muster", 84, 4, n("G", 4), "ionian", reverb=(2.2, 0.45), seed=11)
    A = ["1:2 3:1 5:1", "6:1 5:1 4:1 3:1", "2:1.5 3:0.5 4:1 2:1", "3:2 5,:2",
         "1:2 3:1 5:1", "6:1 1':1 7:1 6:1", "5:1 4:1 3:1 2:1", "1:4"]
    Ac = [0, 3, 4, 0, 0, 3, 4, 0]
    B = ["5:1 6:1 7:1 1':1", "2':2 1':2", "7:1 6:1 5:1 6:1", "5:4",
         "3':1.5 2':0.5 1':1 7:1", "6:1 5:1 6:1 7:1", "1':1 5:1 4:1 2:1", "1:4"]
    Bc = [0, 4, 4, 0, 5, 1, 4, 0]
    lute_pat = "0123" "2123"
    b = 0
    b = s.arp("lute", b, [0, 0], "0121", 1, 0.45, -1, -0.3)
    # A: recorder over lute and a soft bass
    s.arp("lute", b, Ac, lute_pat, 0.5, 0.38, -1, -0.3)
    s.rel("lute", b, Ac, "1:2 5,:2", 0.5, -2, 0.2)
    b = s.mel("recorder", b, A, 0.62, 1, 0.25, 0.35)
    # A again: shawm takes the tune, recorder an octave above in thirds
    s.arp("lute", b, Ac, lute_pat, 0.5, 0.38, -1, -0.3)
    s.rel("lute", b, Ac, "1:2 5,:2", 0.5, -2, 0.2)
    s.pad("organ", b, Ac, 0.18, -1, 0.0, 0.5)
    s.mel("recorder", b, A, 0.4, 1, 0.4, 0.4, tonic=s.tonic + 4)
    b = s.mel("shawm", b, A, 0.55, 0, -0.15, 0.3)
    # B: horns, soft march drum
    s.arp("lute", b, Bc, lute_pat, 0.5, 0.36, -1, -0.3)
    s.rel("lute", b, Bc, "1:2 5,:1 1:1", 0.5, -2, 0.2)
    s.pad("horn", b, Bc, 0.28, -1, 0.0, 0.4)
    s.drums(b, 8, {"S...s.s.S...s...": 0.1}, 0.32)
    b = s.mel("recorder", b, B, 0.6, 1, 0.2, 0.35)
    # A last time, everybody, timpani on the downbeats
    s.arp("lute", b, Ac, lute_pat, 0.5, 0.4, -1, -0.3)
    s.rel("lute", b, Ac, "1:2 5,:2", 0.55, -2, 0.2)
    s.pad("organ", b, Ac, 0.2, -1, 0.0, 0.5)
    s.drums(b, 8, {"S...s.s.S.s.s.s.": 0.1}, 0.36)
    for i, r in enumerate(Ac):
        s.timp(s.bar(b + i), r if r in (0, 4) else 0, 0.45)
    s.mel("brass", b, A, 0.45, 0, -0.2, 0.3)
    b = s.mel("recorder", b, A, 0.55, 1, 0.25, 0.35)
    s.arp("lute", b, [3, 4], "0123", 1, 0.4, -1, -0.3)
    s.note("lute", s.bar(b + 2), 4, s.pitch(0) - 12, 0.55)
    s.note("lute", s.bar(b + 2), 4, s.pitch(4) - 12, 0.45)
    s.note("recorder", s.bar(b + 2), 4, s.pitch(7), 0.5)
    return s


def crown_battle():
    s = Song("crown_battle", "Pike and Shot", 126, 4, n("D", 4), "dorian", reverb=(1.6, 0.4), seed=12)
    A = ["1:1 1:0.5 2:0.5 3:1 1:1", "4:1 3:0.5 2:0.5 3:1 5:1", "6:1 5:0.5 4:0.5 3:1 2:1", "1:1.5 7,:0.5 1:2",
         "5:1 5:0.5 6:0.5 7:1 5:1", "1':1 7:0.5 6:0.5 5:1 3:1", "4:1 3:0.5 2:0.5 1:1 7,:1", "1:4"]
    Ac = [0, 2, 3, 0, 4, 0, 6, 0]
    B = ["5:1.5 5:0.5 1':2", "7:1 6:1 5:2", "4:1.5 4:0.5 6:1 4:1", "5:4",
         "5:1.5 5:0.5 1':1 2':1", "3':2 2':1 1':1", "7:1 5:1 6:1 7:1", "1':4"]
    Bc = [0, 4, 3, 4, 0, 2, 4, 0]
    march = {"S.ss s.s.S.ss s.s.".replace(" ", ""): 0.15, "K.......K.......": 0.0}
    march2 = {"S.ssS.s.S.ssS.ss": 0.15, "K...K...K...K.K.": 0.0}
    roll = {"S.s.s.s.ssssssss": 0.15, "K...K...K.K.K.K.": 0.0}
    bass = "1:1 1:0.5 1:0.5 5,:1 1:1"
    b = s.drums(0, 2, march, 0.55)
    s.drums(b, 2, march, 0.55)
    b = s.rel("lute", b, [0, 0], bass, 0.6, -2)
    # A: fife and drum
    s.drums(b, 8, march, 0.55, fill=roll)
    s.rel("lute", b, Ac, bass, 0.6, -2)
    b = s.mel("recorder", b, A, 0.65, 1, 0.2, 0.25, legato=0.85)
    # A: horns join, timpani
    s.drums(b, 8, march2, 0.6, fill=roll)
    s.rel("horn", b, Ac, "1:2 5,:1 1:1", 0.5, -1, -0.2, 0.25)
    s.rel("lute", b, Ac, bass, 0.6, -2)
    for i, r in enumerate(Ac):
        s.timp(s.bar(b + i), 0 if r in (0, 2, 6) else 4, 0.6)
        s.timp(s.bar(b + i) + 2, 4 if r in (0, 2, 6) else 0, 0.45)
    s.mel("recorder", b, A, 0.55, 1, 0.3, 0.25, legato=0.85)
    b = s.mel("shawm", b, A, 0.55, 0, -0.1, 0.25, legato=0.85)
    # B: trumpet call over the horns
    for rep in range(2):
        s.drums(b, 8, march2, 0.6, fill=roll)
        s.pad("horn", b, Bc, 0.3, -1, 0.0, 0.3)
        s.rel("lute", b, Bc, bass, 0.6, -2)
        for i, r in enumerate(Bc):
            s.timp(s.bar(b + i), 0 if r in (0, 2) else 4, 0.6)
        if rep:
            s.mel("recorder", b, B, 0.45, 1, 0.3, 0.3, legato=0.85)
        b = s.mel("brass", b, B, 0.7, 0, -0.15, 0.3, legato=0.9)
    # A: everyone
    s.drums(b, 8, march2, 0.62, fill=roll)
    s.rel("lute", b, Ac, bass, 0.62, -2)
    s.pad("horn", b, Ac, 0.25, -1)
    for i, r in enumerate(Ac):
        s.timp(s.bar(b + i), 0 if r in (0, 2, 6) else 4, 0.65)
    s.mel("brass", b, A, 0.5, 0, -0.2, 0.3, legato=0.85)
    b = s.mel("recorder", b, A, 0.6, 1, 0.25, 0.25, legato=0.85)
    s.drums(b, 1, {"S.s.s.s.ssssssss": 0.15}, 0.6)
    s.hit("K", s.bar(b + 1), 0.9)
    s.timp(s.bar(b + 1), 0, 0.8)
    s.pad("horn", b + 1, [0], 0.45, -1)
    s.note("brass", s.bar(b + 1), 3, s.pitch(7), 0.7)
    return s


def crown_win():
    s = Song("win_crown", "Te Deum (Victory)", 100, 4, n("G", 4), "ionian", reverb=(2.4, 0.4), seed=13)
    s.mel("brass", 0, ["1:0.5 1:0.5 1:0.5 3:0.5 5:2", "3:0.5 3:0.5 3:0.5 5:0.5 1':2", "7:1 6:1 5:1 7:1", "1':4"], 0.75)
    s.mel("brass", 0, ["r:2 1:2", "r:2 3:2", "4:2 2:2", "3:4"], 0.5, 0, 0.3)
    s.pad("organ", 0, [0, 0, 4, 0], 0.3, -1)
    s.drums(0, 3, {"S.s.s.s.S.s.S...": 0.1}, 0.5)
    for i in range(4):
        s.timp(s.bar(i), 0 if i != 2 else 4, 0.6)
    s.hit("K", s.bar(3), 0.8)
    return s


# =========================================================================== THE BROOD

def brood_peace():
    s = Song("brood_peace", "The Warm Swamp", 66, 4, n("A", 3), "phrygian", reverb=(3.4, 0.7), seed=21)
    call = ["5:1 4:0.5 2:0.5 1:2", "1:1 2:1 3:2", "2:1 1:0.5 7,:0.5 1:2", "r:4"]
    answer = ["5:2 6:2", "5:1 4:1 2:2", "3:1 2:1 1:2", "1:4"]
    high = ["1':2 2':1 1':1", "7:1 6:1 5:2", "6:1 5:0.5 4:0.5 3:1 2:1", "1:4"]
    roots = [0, 0, 1, 0]
    logs = "1:0.75 1:0.25 2:0.5 1:0.5 r:1 5,:0.5 7,:0.5"
    drums = {"D.......d...d...": 0.0, "..t.......t..t..": 0.4}
    b = 0
    # the swamp breathes: drone and throat
    for i in range(36):
        s.note("hurdy", s.bar(i), 4.02, s.pitch(0) - 24, 0.22, 0.0, 0.4)
        if i % 2 == 0:
            s.note("throat", s.bar(i), 8, s.pitch(0) - 12, 0.35, -0.2, 0.5)
    b = s.drums(b, 4, {"D...............": 0.0}, 0.4)
    # call and answer: shawm, then the throat-choir
    for rep in range(2):
        s.drums(b, 8, drums, 0.45)
        s.rel("log", b, roots * 2, logs, 0.45, 0, 0.3)
        b = s.mel("shawm", b, call, 0.5, 0, -0.25, 0.45)
        b = s.mel("choir_u", b, answer, 0.55, -1 + rep, 0.2, 0.6)
        b -= 0
    # the swamp wakes: big drum, high line
    s.drums(b, 8, {"B.......d...d.d.": 0.0, "..t...t...t..tt.": 0.4, "x.x.x.x.x.x.x.x.": -0.4}, 0.48)
    s.rel("log", b, roots * 2, logs, 0.5, 0, 0.3)
    s.pad("choir_u", b, [0, 0, 1, 0, 5, 0, 1, 0], 0.3, -1, 0.0, 0.6)
    b = s.mel("shawm", b, high + high[:2] + ["3:1 2:1 1:2", "1:4"], 0.5, 0, -0.2, 0.45)
    # fading back down
    s.drums(b, 4, {"D.......d.......": 0.0}, 0.35)
    s.mel("choir_u", b, answer, 0.45, -1, 0.2, 0.6)
    return s


def brood_battle():
    # 6/8, counted in eighths
    s = Song("brood_battle", "Hunger", 312, 6, n("A", 3), "phrygian_dom", reverb=(1.8, 0.6), seed=22)
    ost = "1:1 1:1 2:1 1:1 7,:1 1:1"
    A = ["5:3 6:1 5:1 4:1", "3:2 2:1 1:3", "5:2 6:1 7:2 6:1", "5:6",
         "1':3 7:1 6:1 5:1", "6:2 5:1 4:3", "3:1 2:1 3:1 2:1 1:2", "1:6"]
    Ar = [0, 0, 0, 4, 0, 3, 1, 0]
    beat1 = {"B..t.tB.tBt.": 0.0, "..D..d..D.dd": -0.3}
    beat2 = {"B.tt.tB.tBtt": 0.0, "D.dD.dD.dDdd": -0.3, "x.xx.xx.xx.x": 0.4}
    brk = {"B.....B.....": 0.0}
    b = s.drums(0, 4, brk, 0.7)
    s.drums(b, 8, beat1, 0.6)
    b = s.rel("log", b, [0] * 8, ost, 0.55, 0, 0.2, 0.15)
    # the melody bites
    for rep in range(2):
        s.drums(b, 8, beat1 if rep == 0 else beat2, 0.62)
        s.rel("log", b, [0] * 8, ost, 0.55, 0, 0.2, 0.15)
        s.rel("throat", b, Ar, "1:6", 0.45, -1, 0.0, 0.3)
        for i in range(8):
            if rep:
                s.note("choir_u", s.bar(b + i), 1.5, s.pitch(Ar[i] + 4) - 12, 0.5, 0.3, 0.5)
                s.note("choir_u", s.bar(b + i), 1.5, s.pitch(Ar[i]) - 12, 0.5, -0.3, 0.5)
        b = s.mel("shawm", b, A, 0.6, 1 if rep else 0, -0.15, 0.3, legato=0.9)
    # breakdown: drums and throat choir
    s.drums(b, 8, {"B.....B..B..": 0.0, "...t.t...ttt": 0.3}, 0.65)
    for i in range(0, 8, 2):
        s.note("throat", s.bar(b + i), 11, s.pitch(0) - 12, 0.5)
        s.note("choir_u", s.bar(b + i), 11, s.pitch(i % 4 and 1 or 0) - 12, 0.5, 0.2, 0.6)
    b += 8
    # last attack, everything up an octave
    s.drums(b, 8, beat2, 0.66)
    s.rel("log", b, [0] * 8, ost, 0.6, 0, 0.2, 0.15)
    s.rel("throat", b, Ar, "1:6", 0.5, -1)
    s.pad("choir_u", b, Ar, 0.35, -1)
    s.mel("horn", b, A, 0.45, -1, 0.2, 0.3)
    b = s.mel("shawm", b, A, 0.62, 1, -0.15, 0.3, legato=0.9)
    s.drums(b, 2, brk, 0.75)
    return s


def brood_win():
    s = Song("win_brood", "The Feast (Victory)", 300, 6, n("A", 3), "phrygian_dom", reverb=(2.5, 0.6), seed=23)
    s.drums(0, 3, {"B.tt.tB.tBtt": 0.0, "D.dD.dD.dDdd": -0.3}, 0.65)
    s.hit("B", s.bar(3), 0.9)
    s.mel("shawm", 0, ["5:3 6:1 5:1 4:1", "3:2 2:1 1:3", "5:2 1':4", "1':6"], 0.65, 1)
    s.pad("choir_u", 0, [0, 0, 4, 0], 0.5, -1)
    s.note("throat", s.bar(2), 10, s.pitch(0) - 12, 0.6)
    return s


# =========================================================================== THE CLOCKWORK

def clock_peace():
    s = Song("clock_peace", "Winding the Spring", 100, 4, n("D", 4), "dorian", reverb=(1.8, 0.3),
             humanize=0.0, seed=31)
    A = ["5:1 4:1 5:1 1':1", "7:2 5:2", "6:1 5:1 4:1 6:1", "5:4",
         "3:1 4:1 5:1 7:1", "6:2 5:1 4:1", "3:1 4:1 2:1 7,:1", "1:4"]
    Ac = [0, 6, 3, 4, 2, 0, 4, 0]
    B = ["1':1 2':1 3':2", "2':1 1':1 7:2", "6:1 7:1 1':1 6:1", "5:4",
         "1':1 2':1 3':1 4':1", "5':2 4':1 3':1", "2':1 1':1 7:1 5:1", "1':4"]
    Bc = [2, 6, 3, 4, 2, 0, 4, 0]
    tick = {"k.k.k.k.k.k.k.k.": 0.35}
    gears = {"k.k.k.k.k.k.k.k.": 0.35, "c.......c.....c.": -0.3}
    box = "0124" "2124"
    b = 0
    # the key turns: ticks, then the music box
    b = s.drums(b, 2, tick, 0.4)
    s.drums(b, 8, tick, 0.4)
    b = s.arp("musicbox", b, Ac, box, 0.5, 0.42, 0, 0.2, 0.25)
    # A: dulcimer tune over the music box and regal
    s.drums(b, 8, tick, 0.4)
    s.arp("musicbox", b, Ac, box, 0.5, 0.36, 0, 0.2, 0.25)
    s.rel("regal", b, Ac, "1:2 5,:2", 0.45, -2, -0.1, 0.2)
    b = s.mel("dulcimer", b, A, 0.6, 0, -0.2, 0.3)
    # B: glass chimes, gear clanks
    s.drums(b, 8, gears, 0.42)
    s.arp("musicbox", b, Bc, box, 0.5, 0.33, 0, 0.2, 0.25)
    s.pad("regal", b, Bc, 0.22, -1, 0.0, 0.3)
    s.rel("regal", b, Bc, "1:1 5,:1 1:1 5,:1", 0.45, -2, -0.1, 0.2)
    b = s.mel("glass", b, B, 0.65, 0, -0.25, 0.4)
    # A: everyone, then the spring runs down (slowing music box)
    s.drums(b, 8, gears, 0.42)
    s.arp("musicbox", b, Ac, box, 0.5, 0.36, 0, 0.2, 0.25)
    s.pad("regal", b, Ac, 0.2, -1, 0.0, 0.3)
    s.rel("regal", b, Ac, "1:2 5,:2", 0.45, -2, -0.1, 0.2)
    s.mel("glass", b, A, 0.4, 1, 0.3, 0.4)
    b = s.mel("dulcimer", b, A, 0.6, 0, -0.2, 0.3)
    beat = s.bar(b)
    gap = 0.5
    for k, d in enumerate([0, 2, 4, 7, 4, 2, 0, 4, 0]):
        s.note("musicbox", beat, 1, s.pitch(d), 0.42 - k * 0.02, 0.2, 0.3)
        beat += gap
        gap *= 1.17
    return s


def clock_battle():
    # 7/8 (2+2+3), counted in eighths
    s = Song("clock_battle", "Brass and Steam", 330, 7, n("C", 4), "aeolian", reverb=(1.4, 0.3),
             humanize=0.0, seed=32)
    ost = "1:2 1:2 5,:1 6,:1 7,:1"
    A = ["1:2 3:2 5:3", "4:2 3:2 2:3", "3:2 4:2 5:3", "2:2 7,:2 5,:3",
         "5:2 6:2 7:3", "1':2 7:2 5:3", "6:2 5:2 4:3", "5:7"]
    Ar = [0, 3, 0, 4, 5, 2, 3, 4]
    B = ["1':2 7:2 6:3", "5:2 4:2 3:3", "4:2 5:2 6:3", "5:7",
         "3:2 4:2 5:3", "6:2 7:2 1':3", "2':2 7:2 5:3", "1':7"]
    Br = [5, 0, 3, 4, 0, 5, 4, 0]
    mach = {"a.k.k.kk": 0.0, ".......": 0.0}
    mach = {"a.k.c.k": 0.0, "k.k.k.h": 0.35}
    mach2 = {"a.kca.k": 0.0, "kkkkkkh": 0.35, "K...K..": -0.1}
    b = s.drums(0, 2, {"a.....h": 0.0}, 0.6)
    s.drums(b, 4, mach, 0.55)
    b = s.rel("regal", b, [0] * 4, ost, 0.55, -1, -0.1)
    for rep in range(2):
        s.drums(b, 8, mach if rep == 0 else mach2, 0.58)
        s.rel("regal", b, Ar, ost, 0.55, -1, -0.1)
        s.arp("musicbox", b, Ar, "0122012", 1, 0.3, 1, 0.3, 0.2, 1.0)
        if rep:
            s.mel("glass", b, A, 0.45, 1, 0.3, 0.3)
        b = s.mel("horn", b, A, 0.62, 0, -0.2, 0.25, legato=0.92)
    s.drums(b, 8, mach2, 0.6)
    s.rel("regal", b, Br, ost, 0.55, -1, -0.1)
    s.pad("regal", b, Br, 0.22, 0, 0.0, 0.25)
    s.arp("dulcimer", b, Br, "0124212", 1, 0.32, 0, 0.3, 0.2, 1.0)
    b = s.mel("brass", b, B, 0.6, 0, -0.2, 0.25, legato=0.92)
    # gears only
    s.drums(b, 4, {"a.k.c.k": 0.0, "k.k.k.h": 0.35, "K..K...": -0.1}, 0.6)
    b = s.rel("regal", b, [0, 0, 5, 4], ost, 0.55, -1, -0.1)
    s.drums(b, 8, mach2, 0.62)
    s.rel("regal", b, Ar, ost, 0.58, -1, -0.1)
    s.pad("regal", b, Ar, 0.2, 0)
    s.mel("glass", b, A, 0.45, 1, 0.3, 0.3)
    b = s.mel("horn", b, A, 0.65, 0, -0.2, 0.25, legato=0.92)
    s.hit("a", s.bar(b), 0.9)
    s.hit("h", s.bar(b), 0.8)
    s.note("horn", s.bar(b), 4, s.pitch(0), 0.6)
    s.note("regal", s.bar(b), 4, s.pitch(0) - 12, 0.6)
    return s


def clock_win():
    s = Song("win_clockwork", "All Gears Turn (Victory)", 120, 4, n("D", 4), "ionian", reverb=(1.8, 0.3),
             humanize=0.0, seed=33)
    s.drums(0, 3, {"k.k.k.k.k.k.k.k.": 0.3, "a.......c...c...": 0.0}, 0.5)
    s.arp("musicbox", 0, [0, 3, 4, 0], "0124" "2124", 0.5, 0.4, 0, 0.2)
    s.mel("glass", 0, ["1:1 3:1 5:1 1':1", "6:1 1':1 4':2", "2':1 7:1 5:1 2':1", "1':4"], 0.6)
    s.pad("regal", 0, [0, 3, 4, 0], 0.3, -1)
    s.hit("a", s.bar(3), 0.8)
    s.hit("h", s.bar(3), 0.7)
    return s


# =========================================================================== shared

def defeat():
    s = Song("defeat", "The Field Is Lost", 60, 4, n("D", 4), "aeolian", reverb=(3.2, 0.6), seed=41)
    s.mel("choir_o", 0, ["5:2 4:1 3:1", "2:2 1:1 7,:1", "1:4"], 0.5)
    s.pad("organ", 0, [0, 4, 0], 0.25, -1)
    s.hit("K", 0, 0.6)
    s.hit("K", s.bar(2), 0.5)
    return s


def menu():
    """Overture: the Crown's call, the Brood's swamp, the Clockwork's box, then all three."""
    s = Song("menu", "PocketRTS Overture", 100, 4, n("G", 4), "ionian", reverb=(2.2, 0.45), seed=1)
    call = ["5:1.5 5:0.5 1':2", "7:1 6:1 5:2", "4:1.5 4:0.5 6:1 4:1", "5:4",
            "5:1.5 5:0.5 1':1 2':1", "3':2 2':1 1':1", "7:1 5:1 6:1 7:1", "1':4"]
    callc = [0, 4, 3, 4, 0, 5, 4, 0]
    b = 0
    # drums gather
    s.drums(b, 2, {"S.s.s.s.ssssssss": 0.1}, 0.4)
    b += 2
    # the Crown
    s.drums(b, 8, {"S.ssS.s.S.ssS.s.": 0.15, "K.......K.......": 0.0}, 0.5)
    s.pad("horn", b, callc, 0.3, -1)
    s.rel("lute", b, callc, "1:1 1:0.5 1:0.5 5,:1 1:1", 0.55, -2)
    for i, r in enumerate(callc):
        s.timp(s.bar(b + i), 0 if r in (0, 5) else 4, 0.55)
    b = s.mel("brass", b, call, 0.7, 0, -0.15, 0.3, legato=0.9)
    # the Brood: the same call, in the swamp's mode, low
    s.drums(b, 8, {"B.......d...d.d.": 0.0, "..t...t...t..tt.": 0.4}, 0.5)
    for i in range(0, 8, 2):
        s.note("throat", s.bar(b + i), 8, s.pitch(0) - 12, 0.4)
    s.pad("choir_u", b, [0, 1, 0, 1, 0, 1, 6, 0], 0.35, -1)
    b = s.mel("shawm", b, call, 0.55, -1, -0.1, 0.45, mode="phrygian")
    # the Clockwork: the call on the music box, dead on time
    s.drums(b, 8, {"k.k.k.k.k.k.k.k.": 0.35, "c.......c.....c.": -0.3}, 0.4)
    s.arp("musicbox", b, callc, "0124" "2124", 0.5, 0.35, 0, 0.2, 0.25)
    s.rel("regal", b, callc, "1:2 5,:2", 0.45, -2, -0.1)
    b = s.mel("glass", b, call, 0.6, 0, -0.25, 0.4, mode="dorian")
    # all three
    s.drums(b, 8, {"S.ssS.s.S.ssS.ss": 0.15, "B.......B...B...": 0.0, "k.k.k.k.k.k.k.k.": 0.35}, 0.55,
            fill={"S.s.s.s.ssssssss": 0.15, "B...B...B.B.B.B.": 0.0})
    s.pad("horn", b, callc, 0.3, -1)
    s.pad("choir_u", b, callc, 0.25, -1)
    s.arp("musicbox", b, callc, "0124" "2124", 0.5, 0.3, 1, 0.2, 0.25)
    s.rel("lute", b, callc, "1:1 1:0.5 1:0.5 5,:1 1:1", 0.55, -2)
    for i, r in enumerate(callc):
        s.timp(s.bar(b + i), 0 if r in (0, 5) else 4, 0.6)
    s.mel("shawm", b, call, 0.4, 0, 0.3, 0.3)
    b = s.mel("brass", b, call, 0.72, 0, -0.2, 0.3, legato=0.9)
    s.hit("B", s.bar(b), 0.8)
    s.timp(s.bar(b), 0, 0.8)
    s.hit("a", s.bar(b), 0.6)
    s.pad("horn", b, [0], 0.45, -1)
    s.note("brass", s.bar(b), 4, s.pitch(7), 0.65)
    return s


# =========================================================================== THE CROWN, more
# Calm: a harpsichord minuet with a trio (F, 3/4), a folk ballad (E minor), a quick march (B-flat).
# Battle: a harpsichord-driven harmonic-minor charge (A), a 6/8 cavalry gallop (C minor).

def _minuet_acc(s, b, roots, vel=0.32, open_=False):
    """Harpsichord left hand: bass on one, the chord on two and three (open fifths if open_)."""
    s.rel("harpsi", b, roots, "1:3", vel + 0.08, -2, -0.25, 0.25, 0.9)
    s.arp("harpsi", b, roots, "-22" if open_ else "-11", 1, vel, -1, 0.15, 0.3, 0.8)
    s.arp("harpsi", b, roots, "-33" if open_ else "-22", 1, vel * 0.85, -1, 0.3, 0.3, 0.8)
    return b + len(roots)


def crown_peace_2():
    s = Song("crown_peace_2", "The Orchard Minuet", 104, 3, n("F", 4), "ionian", reverb=(1.9, 0.4), seed=111, q=1.5)
    A1 = ["1:1 3:1 5:1", "6:1 5:0.5 4:0.5 3:1", "2:1 4:1 6:1", "5:2 7,:1",
          "4:1 6:1 1':1", "7:0.5 6:0.5 5:1 4:1", "3:1 1:1 7,:1", "2:3"]
    A1r = [0, 3, 1, 4, 3, 4, 0, 4]
    A2 = A1[:6] + ["5:1 4:0.5 3:0.5 2:1", "1:3"]
    A2r = [0, 3, 1, 4, 3, 4, 4, 0]
    B = ["6:1 7:1 1':1", "2':1.5 1':0.5 7:1", "1':1 7:1 5+:1", "6:3",
         "4:1 5:1 6:1", "5:1 4:1 3:1", "2:1 3:1 4:1", "5:3"]
    Br = [5, 1, 2, 5, 3, 0, 1, 4]
    T = ["5:2 6:1", "5:1 3:1 1:1", "2:2 4:1", "3:3", "3:2 4:1", "5:1 6:1 7:1", "1':1 5:1 2:1", "1:3"]
    Tr = [0, 0, 4, 0, 0, 3, 4, 0]
    b = _minuet_acc(s, 0, [0, 4], 0.34)
    s.mel("harpsi", 0, ["1:1 3:1 5:1", "2:1 7,:1 5,:1"], 0.4, 0, 0.0, 0.3)
    # the minuet: recorder over the harpsichord
    _minuet_acc(s, b, A1r)
    b = s.mel("recorder", b, A1, 0.6, 1, 0.2, 0.35, legato=0.85)
    _minuet_acc(s, b, A2r)
    b = s.mel("recorder", b, A2, 0.6, 1, 0.2, 0.35, legato=0.85)
    _minuet_acc(s, b, Br, 0.3, True)
    s.mel("lute", b, B, 0.35, 0, -0.35, 0.3, dshift=-2)
    b = s.mel("recorder", b, B, 0.58, 1, 0.2, 0.35, legato=0.85)
    _minuet_acc(s, b, A2r)
    s.mel("lute", b, A2, 0.38, 0, -0.35, 0.3, dshift=-2)
    b = s.mel("recorder", b, A2, 0.6, 1, 0.2, 0.35, legato=0.85)
    # trio, in B-flat: horns, lute, a tambourine
    s.tonic += 5
    for rep in range(2):
        s.pad("horn", b, Tr, 0.2, -1, 0.0, 0.45)
        s.rel("lute", b, Tr, "1:1 5,:1 5,:1", 0.42, -2, -0.2, 0.2)
        s.drums(b, 8, {"j.....j.j...": 0.35}, 0.22)
        if rep:
            s.mel("recorder", b, T, 0.42, 0, 0.35, 0.4, dshift=2, legato=0.85)
            b = s.mel("shawm", b, T, 0.5, -1, -0.15, 0.3)
        else:
            b = s.mel("recorder", b, T, 0.58, 0, 0.2, 0.4, legato=0.85)
    s.tonic -= 5
    # minuet da capo, a little grander
    for melody, roots in ((A1, A1r), (A2, A2r)):
        _minuet_acc(s, b, roots, 0.34)
        s.pad("organ", b, roots, 0.14, -1, 0.0, 0.5)
        for i, r in enumerate(roots):
            s.timp(s.bar(b + i), 0 if r in (0, 3, 5) else 4, 0.35)
        s.mel("lute", b, melody, 0.38, 0, -0.35, 0.3, dshift=-2)
        b = s.mel("recorder", b, melody, 0.6, 1, 0.2, 0.35, legato=0.85)
    _minuet_acc(s, b, [3, 4], 0.32)
    b = s.mel("recorder", b, ["6:1 5:1 4:1", "3:1 2:1 7,:1"], 0.5, 1, 0.2, 0.35, legato=0.85)
    for k, d in enumerate((0, 2, 4)):
        s.note("harpsi", s.bar(b) + k * 0.08, 3, s.pitch(d) - 12, 0.45, 0.0, 0.3)
    s.note("harpsi", s.bar(b), 3, s.pitch(0) - 24, 0.5)
    s.note("recorder", s.bar(b), 2.5, s.pitch(7), 0.5, 0.2, 0.35)
    return s


def crown_peace_3():
    s = Song("crown_peace_3", "Ballad of the Lost Regiment", 76, 4, n("E", 4), "aeolian", reverb=(2.6, 0.5),
             seed=112, q=1.5)
    V = ["5,:1 1:1 2:1 3:1", "4:1.5 3:0.5 2:2", "3:1 2:1 1:1 7,:1", "1:3 5,:1",
         "5,:1 1:1 2:1 3:1", "5:1.5 4:0.5 3:1 4:1", "3:1 2:0.5 1:0.5 7,:1 2:1", "1:4"]
    Vr = [0, 3, 5, 0, 0, 2, 6, 0]
    R = ["3:1 5:1 1':2", "7:1 6:1 5:2", "6:1.5 5:0.5 4:1 3:1", "2:3 r:1",
         "3:1 5:1 1':1 2':1", "3':2 2':1 1':1", "7:1 5:1 4:1 2:1", "1:4"]
    Rr = [0, 6, 3, 6, 2, 5, 6, 0]
    Il = ["5,:0.5 7,:0.5 1:0.5 2:0.5 3:0.5 2:0.5 3:0.5 5:0.5", "4:0.5 5:0.5 4:0.5 3:0.5 2:1 7,:1",
          "3:0.5 4:0.5 3:0.5 2:0.5 1:0.5 2:0.5 1:0.5 7,:0.5", "1:2 r:2"]
    Ir = [0, 3, 5, 0]

    def guitar(b, roots, vel=0.34):
        s.arp("lute", b, roots, "0213", 0.5, vel, -1, -0.3, 0.3)
        s.rel("lute", b, roots, "1:2 5,:2", vel + 0.08, -2, 0.1, 0.2)

    b = 0
    guitar(b, [0, 5])
    b = 2
    # first verse: the recorder alone over the lute
    guitar(b, Vr)
    b = s.mel("recorder", b, V, 0.58, 1, 0.2, 0.4, legato=0.92)
    # refrain: organ and a low horn in tenths
    guitar(b, Rr)
    s.pad("organ", b, Rr, 0.13, -1, 0.0, 0.5)
    s.mel("horn", b, R, 0.28, -1, -0.3, 0.4, dshift=-2)
    b = s.mel("recorder", b, R, 0.58, 1, 0.2, 0.4, legato=0.92)
    # interlude: the harpsichord remembers the verse
    guitar(b, Ir, 0.28)
    b = s.mel("harpsi", b, Il, 0.48, 0, 0.0, 0.3)
    # second verse: harpsichord, recorder a third above
    guitar(b, Vr, 0.3)
    s.mel("recorder", b, V, 0.4, 1, 0.3, 0.4, dshift=2, legato=0.92)
    b = s.mel("harpsi", b, V, 0.5, 0, -0.2, 0.3)
    # last refrain: everyone, soft timpani
    guitar(b, Rr, 0.36)
    s.pad("organ", b, Rr, 0.16, -1, 0.0, 0.5)
    s.pad("horn", b, Rr, 0.2, -1, 0.0, 0.4)
    for i, r in enumerate(Rr):
        s.timp(s.bar(b + i), 0 if r in (0, 3, 5) else 4, 0.32)
    s.mel("shawm", b, R, 0.36, 0, -0.2, 0.3)
    b = s.mel("recorder", b, R, 0.58, 1, 0.25, 0.4, legato=0.92)
    guitar(b, [5, 6], 0.3)
    b = s.mel("recorder", b, ["3:2 2:1 1:1", "7,:2 2:2"], 0.45, 1, 0.2, 0.4)
    s.note("lute", s.bar(b), 4, s.pitch(0) - 24, 0.5)
    for k, d in enumerate((0, 2, 4, 7)):
        s.note("lute", s.bar(b) + k * 0.1, 4, s.pitch(d) - 12, 0.4, -0.2)
    s.note("recorder", s.bar(b) + 0.4, 3.5, s.pitch(7), 0.45, 0.2, 0.4)
    return s


def crown_peace_4():
    s = Song("crown_peace_4", "Raising the Bastion", 112, 4, n("B", 3) - 1, "ionian", reverb=(2.0, 0.4),
             seed=113, q=2)
    A = ["1:0.75 1:0.25 3:0.75 1:0.25 5:2", "6:0.75 5:0.25 4:0.75 3:0.25 2:2",
         "5,:0.75 5,:0.25 7,:0.75 2:0.25 4:1 3:0.5 2:0.5", "3:2 1:2",
         "1:0.75 1:0.25 3:0.75 5:0.25 1':2", "7:0.75 6:0.25 5:0.75 4:0.25 6:2", "5:1 3:1 2:1 5,:1", "1:4"]
    Ar = [0, 1, 4, 0, 0, 4, 4, 0]
    B = ["5:2 3:1 5:1", "1':3 7:1", "6:1 5:1 4:1 6:1", "5:4", "5:2 3:1 5:1", "2':3 1':1", "7:1 6:1 5:1 7:1", "1':4"]
    Br = [0, 0, 3, 0, 0, 4, 4, 0]
    D = ["6:1 5:1 6:1 1':1", "7:2 5:2", "6:1 5:1 4:1 6:1", "5:4",
         "4:1 3:1 4:1 6:1", "5:2 3:2", "2:1 3:1 4:1 6:1", "5:4"]
    Dr = [5, 2, 1, 4, 3, 0, 1, 4]
    light = {"S..sS...S..sS.s.": 0.1, "..j...j...j...j.": 0.35}

    def oompah(b, roots, vel=0.4):
        s.rel("lute", b, roots, "1:1 r:1 5,:1 r:1", vel + 0.1, -1, 0.15, 0.2)
        s.arp("harpsi", b, roots, "-1-1", 1, vel * 0.7, 0, -0.25, 0.25, 0.4)
        s.arp("harpsi", b, roots, "-2-2", 1, vel * 0.6, 0, -0.1, 0.25, 0.4)

    def timps(b, roots, vel=0.45):
        for i, r in enumerate(roots):
            s.timp(s.bar(b + i), r if r < 5 else r - 7, vel, -1)

    b = s.drums(0, 2, {"S..sS...S..sS.s.": 0.1}, 0.3)
    # the fife and the work-gang
    oompah(b, Ar)
    s.drums(b, 8, light, 0.3)
    b = s.mel("recorder", b, A, 0.6, 1, 0.2, 0.3, legato=0.85)
    # the trumpet takes it, fife a third above
    oompah(b, Ar)
    s.drums(b, 8, light, 0.33)
    s.mel("recorder", b, A, 0.4, 1, 0.3, 0.3, dshift=2, legato=0.85)
    b = s.mel("brass", b, A, 0.55, 1, -0.2, 0.3, legato=0.88)
    # trio in E-flat: a broad horn tune
    s.tonic += 5
    oompah(b, Br, 0.36)
    s.pad("horn", b, Br, 0.22, -1, 0.0, 0.4)
    s.drums(b, 8, {"S.......S.......": 0.1}, 0.25)
    s.mel("recorder", b, B, 0.32, 1, 0.3, 0.4, dshift=2)
    b = s.mel("brass", b, B, 0.5, 0, -0.15, 0.35)
    s.tonic -= 5
    # the walls go up: harpsichord and fife, the snare gathers
    oompah(b, Dr, 0.34)
    s.drums(b, 6, {"S...S...S...S...": 0.1}, 0.28)
    s.roll("s", s.bar(b + 6), 8, 0.25, 0.15, 0.6, 0.1)
    s.mel("recorder", b, D, 0.4, 1, 0.3, 0.35, dshift=2)
    b = s.mel("harpsi", b, D, 0.5, 1, -0.2, 0.3)
    # the march, everyone
    oompah(b, Ar, 0.42)
    s.drums(b, 8, {"S.ssS.s.S.ssS.s.": 0.1, "K.......K.......": 0.0, "..j...j...j...j.": 0.35}, 0.36)
    s.pad("horn", b, Ar, 0.22, -1)
    timps(b, Ar)
    s.mel("brass", b, A, 0.5, 0, -0.2, 0.3, legato=0.88)
    b = s.mel("recorder", b, A, 0.58, 1, 0.3, 0.3, legato=0.85)
    s.drums(b, 1, {"S.s.s.s.ssssssss": 0.1}, 0.4)
    s.timp(s.bar(b), 4, 0.5, -1)
    b = s.mel("brass", b, ["5,:0.75 5,:0.25 5,:0.75 5,:0.25 7,:1 2:1"], 0.6, 1, -0.2, 0.3)
    s.hit("K", s.bar(b), 0.7)
    s.timp(s.bar(b), 0, 0.6, -1)
    s.pad("horn", b, [0], 0.35, -1)
    s.note("brass", s.bar(b), 3, s.pitch(7), 0.55, -0.2)
    s.note("recorder", s.bar(b), 3, s.pitch(9) + 12, 0.45, 0.3)
    return s


def crown_battle_2():
    s = Song("crown_battle_2", "Volley Fire", 144, 4, n("A", 3), "harmonic", reverb=(1.5, 0.4), seed=121, q=2)
    A = ["5:0.5 5:0.5 1':0.5 5:0.5 3':1 2':0.5 1':0.5", "7:1 1':1 5:2",
         "6:0.5 6:0.5 1':0.5 6:0.5 3':1 2':0.5 1':0.5", "7:1 6:1 3:2",
         "4:0.5 4:0.5 6:0.5 4:0.5 1':1 7:0.5 6:0.5", "7:1 6:1 4:2",
         "5:0.5 7:0.5 2':0.5 7:0.5 5:1 7:1", "2':2 7:2"]
    Ar = [0, 0, 5, 5, 3, 3, 4, 4]
    B = ["1':2 7:1 6:1", "5:3 r:1", "6:2 5:1 4:1", "3:3 r:1", "4:2 3:1 2:1", "1:2 3:2", "2:1 3:1 4:1 5:1", "7,:2 5,:2"]
    Br = [5, 0, 3, 0, 1, 0, 4, 4]
    march = {"S.ssS.s.S.ssS.s.": 0.15, "K...K...K...K...": 0.0}
    march2 = {"SsssS.ssSsssS.sS": 0.15, "K...K.K.K...K.K.": 0.0}
    roll = {"S.s.s.s.ssssssss": 0.15, "K...K...K.K.KKKK": 0.0}
    bass = "1:0.5 1:0.5 8:0.5 1:0.5 1:0.5 1:0.5 5,:0.5 1:0.5"

    def engine(b, roots, vel=0.3):
        s.arp("harpsi", b, roots, "01213121", 0.25, vel, 0, -0.3, 0.2, 1.0)
        s.rel("lute", b, roots, bass, vel + 0.25, -1, 0.15, 0.12, 0.85)

    def timps(b, roots, vel=0.55):
        for i, r in enumerate(roots):
            s.timp(s.bar(b + i), r if r < 5 else r - 7, vel, -1)
            s.timp(s.bar(b + i) + 2.5, r if r < 5 else r - 7, vel * 0.7, -1)

    # drums gather
    s.roll("s", 0, 8, 0.25, 0.15, 0.7, 0.15)
    s.timp(0, 0, 0.6, -1)
    s.timp(s.bar(1), 0, 0.7, -1)
    b = 2
    engine(b, [0, 4])
    b = s.drums(b, 2, march, 0.5)
    # A: fife over the harpsichord engine
    engine(b, Ar)
    s.drums(b, 8, march, 0.52, fill=roll)
    b = s.mel("recorder", b, A, 0.62, 1, 0.2, 0.25, legato=0.85)
    # A: trumpet below, timpani
    engine(b, Ar)
    s.drums(b, 8, march2, 0.56, fill=roll)
    timps(b, Ar)
    s.mel("brass", b, A, 0.5, 0, -0.2, 0.25, legato=0.85)
    b = s.mel("recorder", b, A, 0.58, 1, 0.25, 0.25, legato=0.85)
    # B: the trumpet call
    engine(b, Br, 0.28)
    s.pad("horn", b, Br, 0.28, -1)
    s.drums(b, 8, march2, 0.58, fill=roll)
    timps(b, Br)
    s.mel("recorder", b, B, 0.4, 1, 0.3, 0.3, dshift=2, legato=0.85)
    b = s.mel("brass", b, B, 0.7, 1, -0.15, 0.3, legato=0.9)
    # reload: drums and timpani only, then the long roll
    s.drums(b, 4, {"S...S.s.S...SsSs": 0.15, "K.......K.K.....": 0.0}, 0.5)
    s.rel("lute", b, [0] * 4, bass, 0.5, -1, 0.15)
    for i in range(4):
        s.timp(s.bar(b + i), 0, 0.6, -1)
        s.timp(s.bar(b + i) + 1.5, 4, 0.45, -1)
        s.timp(s.bar(b + i) + 3, 0, 0.5, -1)
    b += 4
    engine(b, [3, 3, 4, 4], 0.32)
    s.roll("s", s.bar(b), 16, 0.25, 0.15, 0.8, 0.15)
    for i, r in enumerate([3, 3, 4, 4]):
        s.timp(s.bar(b + i), r, 0.45 + 0.1 * i, -1)
        s.note("horn", s.bar(b + i), 4, s.pitch(r) - 12, 0.2 + 0.08 * i, -0.2, 0.3)
    b = s.mel("brass", b, ["4:4", "6:4", "7:4", "2':2 7:2"], 0.55, 1, -0.15, 0.3)
    # A: everyone - fire!
    engine(b, Ar, 0.32)
    s.drums(b, 8, march2, 0.62, fill=roll)
    timps(b, Ar, 0.62)
    s.pad("horn", b, Ar, 0.25, -1)
    s.mel("brass", b, A, 0.55, 0, -0.2, 0.25, legato=0.85)
    s.mel("shawm", b, A, 0.4, 0, 0.35, 0.25, dshift=2, legato=0.85)
    b = s.mel("recorder", b, A, 0.6, 1, 0.25, 0.25, legato=0.85)
    engine(b, Br, 0.3)
    s.pad("horn", b, Br, 0.3, -1)
    s.drums(b, 8, march2, 0.62, fill=roll)
    timps(b, Br, 0.62)
    s.mel("recorder", b, B, 0.5, 1, 0.3, 0.3, dshift=2, legato=0.85)
    b = s.mel("brass", b, B, 0.72, 1, -0.15, 0.3, legato=0.9)
    s.drums(b, 1, {"S.s.s.s.ssssssss": 0.15, "K...K...K.K.K.K.": 0.0}, 0.6)
    engine(b, [4], 0.32)
    b = s.mel("brass", b, ["5:0.5 7:0.5 2':0.5 7:0.5 5:1 7:1"], 0.65, 1, -0.15, 0.3)
    s.hit("K", s.bar(b), 0.9)
    s.timp(s.bar(b), 0, 0.8, -1)
    s.pad("horn", b, [0], 0.45, -1)
    s.note("brass", s.bar(b), 3, s.pitch(7), 0.7, -0.15)
    s.note("lute", s.bar(b), 3, s.pitch(0) - 12, 0.6)
    return s


def crown_battle_3():
    # 6/8 gallop, counted in eighths
    s = Song("crown_battle_3", "Sabres at the Ford", 360, 6, n("C", 4), "aeolian", reverb=(1.6, 0.4), seed=122, q=2)
    M1 = ["1:2 3:1 5:2 3:1", "1':3 5:3", "6:2 5:1 4:2 3:1", "2:6",
          "2:2 4:1 6:2 4:1", "7:3 5:3", "6:2 5:1 4:2 2:1", "1:6"]
    M1r = [0, 0, 3, 4, 1, 4, 3, 0]
    M2 = ["5:2 6:1 7:2 1':1", "2':3 1':3", "7:2 6:1 5:2 4:1", "3:6",
          "4:2 5:1 6:2 7:1", "1':3 6:3", "5:2 4:1 3:2 2:1", "1:6"]
    M2r = [4, 6, 6, 0, 3, 3, 4, 0]
    gallop = {"S.sS.sS.sS.s": 0.15, "K.....K.....": 0.0}
    gallop2 = {"SssS.sSssSss": 0.15, "K..K..K..K..": 0.0}
    fill = {"S.s.s.ssssss": 0.15, "K.....K.K.KK": 0.0}
    gbass = "1:2 1:1 5,:2 5,:1"

    def timps(b, roots, vel=0.55):
        for i, r in enumerate(roots):
            s.timp(s.bar(b + i), r if r < 5 else r - 7, vel)

    # hooves in the distance: timpani roll, the snare picks up the gallop
    for i in range(24):
        s.timp(i, 0 if (i // 6) % 2 == 0 else 4, 0.15 + 0.4 * i / 23)
    s.drums(2, 2, {"S..S..S..S..": 0.15}, 0.4)
    b = 4
    for rep in range(2):
        for mel, roots in ((M1, M1r), (M2, M2r)):
            s.drums(b, 8, gallop if rep == 0 else gallop2, 0.55 if rep == 0 else 0.6, fill=fill)
            s.rel("lute", b, roots, gbass, 0.55, -2, 0.15, 0.12)
            if rep:
                s.rel("horn", b, roots, "1:3 5,:3", 0.32, -1, -0.2, 0.3)
                timps(b, roots)
            if mel is M1:
                if rep:
                    s.mel("shawm", b, mel, 0.42, 0, -0.3, 0.25, dshift=-2)
                b = s.mel("recorder", b, mel, 0.62, 1, 0.2, 0.25, legato=0.85)
            else:
                if rep:
                    s.mel("recorder", b, mel, 0.4, 1, 0.3, 0.3, legato=0.85)
                b = s.mel("brass" if rep else "horn", b, mel, 0.62, 0, -0.15, 0.3, legato=0.9)
    # a trot in E-flat major: harpsichord and fife, light snare
    s.tonic, s.mode = n("E", 4) - 1, "ionian"
    for mel, roots, inst in ((M1, M1r, "harpsi"), (M2, M2r, "recorder")):
        s.drums(b, 8, {"S..s..S..s..": 0.15}, 0.35)
        s.rel("lute", b, roots, gbass, 0.45, -2, 0.15, 0.12)
        s.pad("horn", b, roots, 0.16, -1, 0.0, 0.4)
        if inst == "recorder":
            s.mel("harpsi", b, mel, 0.35, 0, -0.3, 0.3, dshift=-2)
        b = s.mel(inst, b, mel, 0.55, 1 if inst == "recorder" else 0, 0.2, 0.3, legato=0.85)
    s.tonic, s.mode = n("C", 4), "aeolian"
    # regroup: long horn calls, then everything builds
    Hr = [0, 4, 5, 4, 3, 4, 5, 4]
    s.drums(b, 8, {"S...........": 0.15}, 0.3)
    s.rel("lute", b, Hr, "1:6", 0.4, -2, 0.15)
    timps(b, Hr, 0.3)
    s.pad("organ", b, Hr, 0.12, -1, 0.0, 0.5)
    b = s.mel("horn", b, ["1:6", "7,:6", "6,:6", "5,:6", "4,:6", "5,:6", "6,:6", "5,:6"], 0.45, 0, -0.1, 0.4)
    Ur = [0, 0, 5, 5, 3, 3, 4, 4]
    s.arp("harpsi", b, Ur, "012312", 1, 0.3, 0, -0.3, 0.2, 1.0)
    s.rel("lute", b, Ur, gbass, 0.5, -2, 0.15)
    s.roll("s", s.bar(b), 48, 0.5, 0.12, 0.75, 0.15)
    for i, r in enumerate(Ur):
        s.timp(s.bar(b + i), r if r < 5 else r - 7, 0.3 + 0.06 * i)
        s.timp(s.bar(b + i) + 3, r if r < 5 else r - 7, 0.25 + 0.06 * i)
    b = s.mel("brass", b, ["1:6", "1:6", "3:6", "3:6", "4:6", "4:6", "5:6", "5:3 7:3"], 0.55, 0, -0.15, 0.3)
    # the charge
    for mel, roots in ((M1, M1r), (M2, M2r)):
        s.drums(b, 8, gallop2, 0.64, fill=fill)
        s.rel("lute", b, roots, gbass, 0.6, -2, 0.15, 0.12)
        s.rel("horn", b, roots, "1:3 5,:3", 0.35, -1, -0.2, 0.3)
        s.pad("organ", b, roots, 0.1, -1, 0.0, 0.4)
        timps(b, roots, 0.62)
        s.mel("brass", b, mel, 0.55, 0, -0.15, 0.3, legato=0.9)
        b = s.mel("recorder", b, mel, 0.6, 1, 0.25, 0.25, legato=0.85)
    s.drums(b, 1, fill, 0.62)
    s.mel("brass", b, ["5:3 5:3"], 0.65, 0, -0.15)
    s.timp(s.bar(b), 4, 0.6)
    b += 1
    s.hit("K", s.bar(b), 0.9)
    s.timp(s.bar(b), 0, 0.8)
    s.pad("horn", b, [0], 0.45, -1)
    s.note("brass", s.bar(b), 4, s.pitch(7), 0.7, -0.15)
    s.note("recorder", s.bar(b), 4, s.pitch(9) + 12, 0.5, 0.3)
    return s


# =========================================================================== THE BROOD, more
# Calm: a locrian pool in 5/4 (F#), a dorian night song (C), a slow dorian procession (G).
# Battle: phrygian polyrhythm with a call-and-response (E), a 9/8 swarm that keeps building (D).

def _bubbles(s, bar0, nbars, lo=2, hi=4, vel=0.3):
    s.scatter(bar0, nbars, lo, hi, lambda bt, r: s.hit("w" if r.random() < 0.6 else "W", bt,
                                                      vel * r.uniform(0.6, 1.3), r.uniform(-0.7, 0.7), 0.45))


def brood_peace_2():
    s = Song("brood_peace_2", "Spawning Pools", 66, 5, n("F", 3) + 1, "locrian", reverb=(3.8, 0.75), seed=211, q=2)
    P1 = ["1:2 2:1 1:2", "3:3 2:2", "1:1 7,:1 6,:3", "r:5"]
    P2 = ["5:3 4:1 3:1", "2:2 3:3", "6,:2 7,:1 1:2", "1:5"]
    Q = ["1':2 7:1 6:2", "5:1 6:1 5:3", "4:2 3:1 2:2", "1:5", "3:2 4:1 5:2", "6:3 5:2", "4:1 3:1 2:1 1:2", "1:5"]
    total = 26
    for i in range(total):
        s.note("hurdy", s.bar(i), 5.02, s.pitch(0) - 12, 0.18, 0.0, 0.4)
        if i % 2 == 0:
            s.note("throat", s.bar(i), 10, s.pitch(0) - 12, 0.3, -0.2, 0.5)
    _bubbles(s, 0, total)
    s.scatter(0, total, 0, 1, lambda bt, r: s.hit("q", bt, r.uniform(0.25, 0.45), r.uniform(-0.6, 0.6), 0.4), 1.0)
    b = 1
    # a flute calls over the water, the choir answers from under it
    b = s.mel("boneflute", b, P1, 0.55, 1, -0.25, 0.5)
    b = s.mel("choir_o", b, P2, 0.45, 0, 0.2, 0.6)
    # the pools stir: a log pattern in five, shakers
    s.rel("log", b, [0] * 8, "1:1 1:0.5 5,:0.5 1:1 2:1 1:1", 0.38, 0, 0.25, 0.3)
    s.drums(b, 8, {"x...x.x...x...x.x...": -0.4}, 0.3)
    s.drums(b, 8, {"D.......d.......d...": 0.0}, 0.32)
    s.pad("choir_o", b, [0, 0, 5, 5, 3, 3, 1, 0], 0.16, -1, 0.0, 0.6, voicing=(0, 1))
    b = s.mel("boneflute", b, Q, 0.55, 1, -0.2, 0.5)
    # everything sinks back: the low choir sings the call, the flute floats above
    s.rel("log", b, [0] * 8, "1:2 5,:1 1:2", 0.3, 0, 0.25, 0.3)
    s.drums(b, 8, {"D.........d.........": 0.0}, 0.28)
    s.mel("choir_u", b, P1 + P2, 0.45, 0, 0.25, 0.6)
    b = s.mel("boneflute", b, P1 + P2, 0.45, 1, -0.25, 0.55, dshift=2)
    s.mel("boneflute", b, ["1:5"], 0.35, 1, -0.2, 0.6)
    return s


def brood_peace_3():
    s = Song("brood_peace_3", "Moonlit Mudflats", 84, 4, n("C", 4), "dorian", reverb=(3.0, 0.65), seed=212, q=2)
    A = ["5:2 4:1 3:1", "4:2 6:2", "5:1.5 4:0.5 3:1 1:1", "2:4",
         "3:2 5:1 7:1", "6:3 5:1", "4:1 2:1 7,:1 2:1", "1:4"]
    Ar = [0, 3, 0, 6, 2, 3, 6, 0]
    B = ["1':2 2':1 3':1", "4':2 3':1 2':1", "1':1.5 7:0.5 6:1 5:1", "6:4",
         "5:1 6:1 7:1 1':1", "2':2 1':1 7:1", "6:1 5:1 4:1 2:1", "1:4"]
    Br = [0, 3, 4, 3, 6, 4, 3, 0]

    def mud(b, roots, vel=0.4):
        s.arp("log", b, roots, "02132312", 0.5, vel, 0, 0.25, 0.3, 1.0)
        s.rel("throat", b, roots, "1:4", 0.22, -1, -0.2, 0.5)
        s.drums(b, len(roots), {"..x...x...x...x.": -0.4}, 0.22)

    total = 36
    s.scatter(0, total, 0, 2, lambda bt, r: s.hit("z", bt, r.uniform(0.3, 0.6), r.choice([-0.8, 0.8]), 0.5), 0.5)
    b = 0
    mud(b, [0, 0], 0.36)
    b = 2
    mud(b, Ar)
    s.drums(b, 8, {"D.......d.......": 0.0}, 0.25)
    b = s.mel("boneflute", b, A, 0.55, 0, -0.2, 0.5)
    # the log drums take the tune, the flute a third above
    mud(b, Ar, 0.3)
    s.drums(b, 8, {"D.......d.......": 0.0}, 0.25)
    s.mel("log", b, A, 0.55, 1, -0.1, 0.35)
    b = s.mel("boneflute", b, A, 0.38, 0, 0.3, 0.5, dshift=2)
    # moonrise
    mud(b, Br, 0.34)
    s.pad("choir_o", b, Br, 0.2, -1, 0.0, 0.6)
    s.drums(b, 8, {"D.......d...d...": 0.0}, 0.3)
    b = s.mel("boneflute", b, B, 0.55, 0, -0.2, 0.5)
    # the tune once more, the low choir humming underneath
    mud(b, Ar, 0.36)
    s.pad("choir_o", b, Ar, 0.15, -1, 0.0, 0.6)
    s.drums(b, 8, {"D.......d.......": 0.0}, 0.25)
    s.mel("choir_u", b, A, 0.35, -1, 0.2, 0.6)
    b = s.mel("boneflute", b, A, 0.55, 1, -0.2, 0.5)
    mud(b, [0, 0], 0.3)
    s.mel("boneflute", b, ["5:2 4:1 3:1", "1:4"], 0.45, 0, -0.2, 0.5)
    return s


def brood_peace_4():
    s = Song("brood_peace_4", "The Queen Stirs", 88, 4, n("G", 3), "dorian", reverb=(3.2, 0.7), seed=213,
             q=2, ceiling=0.8)
    A = ["1:2 5:2", "4:1 3:1 4:1 6:1", "5:2 4:1 3:1", "2:2 7,:2",
         "1:2 3:1 5:1", "6:2 4:2", "5:1 4:1 2:1 7,:1", "1:4"]
    Ar = [0, 3, 0, 6, 0, 3, 6, 0]
    B = ["5:1 6:1 5:1 4:1", "3:2 1:2", "2:1 3:1 4:1 5:1", "6:4",
         "1':1 7:1 6:1 5:1", "4:2 6:2", "5:1 4:1 3:1 2:1", "1:4"]
    Br = [0, 0, 6, 3, 6, 3, 4, 0]
    logs = "1:1.5 1:0.5 5,:1 1:1"
    proc = {"B.......B...d.d.": 0.0, "..t...t...t...t.": 0.4}
    total = 38
    s.scatter(0, total, 0, 1, lambda bt, r: s.hit("q", bt, r.uniform(0.3, 0.5), r.uniform(-0.6, 0.6), 0.35), 1.0)
    # a heartbeat under the mud
    for i in range(4):
        s.hit("B", s.bar(i), 0.45 + 0.06 * i)
        s.hit("B", s.bar(i) + 0.6, 0.3 + 0.05 * i)
    s.note("throat", 0, 16, s.pitch(0) - 12, 0.4, 0.0, 0.5)
    b = 4
    # the hive hums the anthem
    s.rel("throat", b, Ar, "1:4", 0.35, -1, 0.0, 0.4)
    s.rel("log", b, Ar, logs, 0.42, -1, 0.2, 0.25)
    s.drums(b, 8, {"B.......d...d...": 0.0, "x.x.x.x.x.x.x.x.": -0.4}, 0.4)
    b = s.mel("choir_u", b, A, 0.55, 0, 0.0, 0.6)
    # the procession: horn and shawm
    s.rel("throat", b, Ar, "1:4", 0.35, -1, 0.0, 0.4)
    s.rel("log", b, Ar, logs, 0.45, -1, 0.2, 0.25)
    s.drums(b, 8, proc, 0.44)
    s.mel("shawm", b, A, 0.45, 1, -0.25, 0.35)
    b = s.mel("horn", b, A, 0.55, 0, 0.2, 0.35)
    # the queen's call
    s.pad("choir_u", b, Br, 0.3, 0, 0.0, 0.6)
    s.rel("throat", b, Br, "1:4", 0.35, -1)
    s.drums(b, 8, {"D...d...D.d.d...": 0.0, "..t...t...t..tt.": 0.4, "x.xxx.xxx.xxx.xx": -0.4}, 0.42)
    b = s.mel("shawm", b, B, 0.55, 1, -0.2, 0.4)
    # the anthem, all of the swamp
    s.pad("choir_u", b, Ar, 0.28, 0, 0.0, 0.6)
    s.rel("throat", b, Ar, "1:4", 0.38, -1)
    s.rel("log", b, Ar, logs, 0.48, -1, 0.2, 0.25)
    s.drums(b, 8, {"B.......B...d.d.": 0.0, "..t...t...t...t.": 0.4, "x.x.x.x.x.x.x.x.": -0.4}, 0.48,
            fill={"B...B...B.B.BBBB": 0.0, "..t...t...tttttt": 0.4})
    s.mel("horn", b, A, 0.55, 0, 0.2, 0.35)
    s.mel("choir_u", b, A, 0.4, 1, 0.0, 0.6)
    b = s.mel("shawm", b, A, 0.55, 1, -0.25, 0.35)
    s.hit("B", s.bar(b), 0.7)
    s.hit("q", s.bar(b) + 0.5, 0.5)
    s.note("throat", s.bar(b), 6, s.pitch(0) - 12, 0.45)
    for d in (0, 4, 7):
        s.note("choir_u", s.bar(b), 5, s.pitch(d), 0.4, 0.0, 0.6)
    return s


def brood_battle_2():
    s = Song("brood_battle_2", "Teeth in the Reeds", 148, 4, n("E", 4), "phrygian", reverb=(1.8, 0.6), seed=221, q=2)
    A = ["1:1 2:0.5 1:0.5 5:2", "4:1 3:0.5 2:0.5 1:2", "1:0.5 2:0.5 3:0.5 4:0.5 5:1 6:1", "5:4",
         "1':1 7:0.5 6:0.5 5:1 6:1", "5:1 4:0.5 3:0.5 2:2", "3:1 2:0.5 1:0.5 7,:1 2:1", "1:4"]
    Ar = [0, 0, 5, 0, 5, 1, 1, 0]
    C = ["5:0.5 5:0.5 r:0.5 6:0.5 5:1 r:1", "2':0.5 1':0.5 r:0.5 7:0.5 6:1 r:1",
         "5:0.5 5:0.5 r:0.5 6:0.5 5:0.5 4:0.5 3:0.5 2:0.5", "1:2 r:2"]
    Cresp = ["r:3 1:0.5 1:0.5", "r:3 2:0.5 1:0.5", "r:4", "r:2 5,:0.5 5,:0.5 1:1"]
    Cr = [0, 5, 0, 0]
    ost = "1:0.75 1:0.75 2:0.5 1:1 7,:1"
    beat1 = {"B......B..B.....": 0.0, "..t...t...t..t.t": 0.4, "....D.......D...": -0.3}
    beat2 = {"B..B...B..B..B..": 0.0, "..t.t.t...t.ttt.": 0.4, "....D..d....D.dd": -0.3, "xxxxxxxxxxxxxxxx": -0.5}
    fill = {"B.B.B.B.D.D.dddd": 0.0, "..t.t.t.tttttttt": 0.4, "xxxxxxxxxxxxxxxx": -0.5}

    def reeds(b, nbars, vel=0.45):
        """Log drums in dotted eighths: three against the four of the drums."""
        degs = [0, 0, 4, 1, 0, 3, 0, 1]
        for k in range(int(nbars * 4 / 0.75)):
            s.note("log", s.bar(b) + k * 0.75, 0.5, s.pitch(degs[k % 8]) - 12,
                   vel + (0.1 if k % 4 == 0 else 0), 0.3, 0.2)

    def croaks(b, nbars):
        for i in range(0, nbars, 2):
            s.hit("q", s.bar(b + i) + 3, 0.55, -0.4, 0.2)

    b = 0
    reeds(b, 4, 0.4)
    s.rel("throat", b, [0] * 4, ost, 0.35, -2)
    s.drums(b + 2, 2, {"B.......B.......": 0.0}, 0.55)
    b = 4
    # A: the shawm bites
    reeds(b, 8)
    s.rel("throat", b, Ar, ost, 0.4, -2)
    s.drums(b, 8, beat1, 0.55, fill=fill)
    croaks(b, 8)
    b = s.mel("shawm", b, A, 0.6, 0, -0.15, 0.3, legato=0.9)
    # A: an octave up, the choir growls under it
    reeds(b, 8)
    s.rel("throat", b, Ar, ost, 0.42, -2)
    s.drums(b, 8, beat2, 0.58, fill=fill)
    croaks(b, 8)
    s.pad("choir_u", b, Ar, 0.3, -1)
    b = s.mel("shawm", b, A, 0.6, 1, -0.15, 0.3, legato=0.9)
    # call and response
    for rep in range(2):
        reeds(b, 4)
        s.rel("throat", b, Cr, ost, 0.42, -2)
        s.drums(b, 4, beat2, 0.6, fill=fill if rep else None)
        s.mel("choir_u", b, Cresp, 0.6, 0, 0.3, 0.5)
        b = s.mel("shawm", b, C, 0.62, rep, -0.2, 0.3, legato=0.8)
    # the reeds alone, then the swarm gathers
    reeds(b, 8, 0.42)
    s.rel("throat", b, [0] * 8, ost, 0.38, -2)
    s.drums(b, 4, {"B...............": 0.0, "q.......q.......": 0.3}, 0.5)
    s.roll("D", s.bar(b + 4), 16, 0.25, 0.15, 0.75, -0.2)
    s.roll("x", s.bar(b + 4), 16, 0.25, 0.1, 0.6, 0.5)
    s.mel("horn", b + 4, ["1:4", "2:4", "4:4", "5:4"], 0.4, -1, 0.2, 0.3)
    b += 8
    # A: everything
    reeds(b, 8, 0.5)
    s.rel("throat", b, Ar, ost, 0.45, -2)
    s.drums(b, 8, beat2, 0.62, fill=fill)
    croaks(b, 8)
    s.pad("choir_u", b, Ar, 0.32, -1)
    s.mel("horn", b, A, 0.45, -1, 0.2, 0.3)
    b = s.mel("shawm", b, A, 0.62, 1, -0.15, 0.3, legato=0.9)
    for rep in range(2):
        reeds(b, 4, 0.5)
        s.rel("throat", b, Cr, ost, 0.45, -2)
        s.drums(b, 4, beat2, 0.62, fill=fill)
        s.mel("choir_u", b, Cresp, 0.62, 0, 0.3, 0.5)
        b = s.mel("shawm", b, C, 0.62, 1, -0.2, 0.3, legato=0.8)
    s.drums(b, 1, {"B.B.B.B.BBBBBBBB": 0.0}, 0.68)
    b += 1
    s.hit("B", s.bar(b), 0.9)
    s.hit("q", s.bar(b), 0.6)
    s.note("throat", s.bar(b), 3, s.pitch(0) - 24, 0.6)
    s.note("shawm", s.bar(b), 2, s.pitch(0) + 12, 0.6)
    return s


def brood_battle_3():
    # 9/8 (2+2+2+3), counted in eighths
    s = Song("brood_battle_3", "The Swarm Rises", 352, 9, n("D", 4), "harmonic", reverb=(2.0, 0.6), seed=222, q=2)
    ost = "1:2 1:2 6,:2 7,:1 1:2"
    A = ["5:2 6:2 5:2 4:3", "3:2 2:2 3:2 1:3", "5:2 6:2 7:2 1':3", "7:4 6:2 5:3",
         "4:2 5:2 6:2 4:3", "3:2 2:2 1:2 7,:3", "1:2 2:2 3:2 5:3", "1:9"]
    Ar = [0, 0, 5, 4, 3, 4, 0, 0]
    B = ["3':4 2':2 1':3", "7:4 6:2 5:3", "6:4 5:2 4:3", "5:9",
         "3':4 2':2 1':3", "7:4 6:2 5:3", "6:2 5:2 4:2 3:3", "2:9"]
    Br = [2, 4, 3, 4, 2, 4, 3, 4]
    d1 = {"D...d...d...D.....": 0.0, "..t...t...t...t.t.": 0.4}
    d2 = {"B...d...d...B..d..": 0.0, "..t.t.t.t.t.t.t.tt": 0.4, "x.xxx.xxx.xxx.xxx.": -0.4}
    d3 = {"B..dB..dB..dB..d.d": 0.0, "..t.t.t.t.ttt.t.tt": 0.4, "xxxxxxxxxxxxxxxxxx": -0.4,
          "q...........q.....": 0.3}
    fill = {"B.B.B.B.B.B.BBBBBB": 0.0, "tttttttttttttttttt": 0.4}

    def swarm(b, roots, vel=0.45):
        s.rel("log", b, roots, ost, vel, 0, 0.25, 0.15)
        s.rel("throat", b, roots, "1:9", 0.35, -1, 0.0, 0.3)

    # it wakes: shakers, a throat pulse, then the log
    s.drums(0, 4, {"x.x.x.x.x.x.x.x.x.": -0.4}, 0.35)
    s.rel("throat", 0, [0] * 4, "1:9", 0.3, -1, 0.0, 0.3)
    swarm(4, [0] * 4, 0.42)
    s.drums(4, 4, {"x.x.x.x.x.x.x.x.x.": -0.4, "..t...t...t...t.t.": 0.4}, 0.4)
    b = 8
    # the throat-choir sings it
    swarm(b, Ar)
    s.drums(b, 8, d1, 0.48)
    b = s.mel("choir_u", b, A, 0.55, 0, 0.0, 0.5)
    # the shawm, the big drums
    swarm(b, Ar, 0.48)
    s.drums(b, 8, d2, 0.55, fill=fill)
    b = s.mel("shawm", b, A, 0.6, 0, -0.15, 0.3, legato=0.9)
    # it takes flight
    swarm(b, Br, 0.48)
    s.pad("choir_u", b, Br, 0.3, -1)
    s.drums(b, 8, d2, 0.58, fill=fill)
    b = s.mel("shawm", b, B, 0.6, 0, -0.2, 0.35)
    # the drums gather everyone
    s.drums(b, 4, {"B........B........": 0.0}, 0.6)
    s.roll("D", s.bar(b), 36, 0.5, 0.12, 0.75, -0.2)
    s.roll("t", s.bar(b + 2), 18, 0.5, 0.15, 0.7, 0.4)
    s.rel("throat", b, [0, 0, 4, 4], "1:9", 0.4, -1)
    b += 4
    # all of it
    swarm(b, Ar, 0.52)
    s.pad("choir_u", b, Ar, 0.32, -1)
    s.drums(b, 8, d3, 0.62, fill=fill)
    s.mel("horn", b, A, 0.45, -1, 0.2, 0.3)
    b = s.mel("shawm", b, A, 0.62, 1, -0.15, 0.3, legato=0.9)
    swarm(b, Ar, 0.52)
    s.drums(b, 8, d3, 0.64, fill=fill)
    s.mel("choir_u", b, A, 0.5, 0, 0.3, 0.5, dshift=2)
    s.mel("horn", b, A, 0.45, -1, 0.2, 0.3)
    b = s.mel("shawm", b, A, 0.62, 1, -0.15, 0.3, legato=0.9)
    s.drums(b, 1, fill, 0.66)
    b += 1
    s.hit("B", s.bar(b), 0.9)
    s.hit("q", s.bar(b) + 1, 0.6)
    s.note("throat", s.bar(b), 6, s.pitch(0) - 12, 0.6)
    s.note("shawm", s.bar(b), 4, s.pitch(0) + 12, 0.6)
    s.note("choir_u", s.bar(b), 6, s.pitch(0), 0.5)
    return s


# =========================================================================== THE CLOCKWORK, more
# Calm: a lydian orrery in 3/4 (E), a rainy music box (A minor), a busy assembly line (F).
# Battle: a 16th-note overclock that shifts up a gear (E minor), a phrygian 5/4 gearstorm (G).

def clock_peace_2():
    s = Song("clock_peace_2", "The Orrery", 92, 3, n("E", 4), "lydian", reverb=(2.4, 0.35), humanize=0.0,
             seed=311, q=2, ceiling=0.8)
    A = ["1:1 2:1 3:1", "5:3", "4:1.5 3:1.5", "2:3", "3:1 4:1 5:1", "7:2 6:1", "5:3", "5:3",
         "1':1 7:1 6:1", "5:2 3:1", "4:2 3:1", "2:3", "3:1 2:1 1:1", "7,:2 2:1", "1:3", "1:3"]
    Ar = [0, 0, 1, 1, 0, 4, 0, 0, 5, 0, 1, 1, 0, 4, 0, 0]
    B1 = ["3':1.5 2':1.5", "1':3", "7:1 1':1 7:1", "5:3", "4:1.5 3:1.5", "6:3", "2':1.5 1':1.5", "7:3"]
    B2 = ["3':1.5 2':1.5", "1':3", "7:1 1':1 2':1", "3':3", "4':1.5 3':1.5", "2':3", "7:1 6:1 7:1", "5:3"]
    Br = [5, 5, 2, 2, 1, 1, 4, 4]
    tick = {"k...k...k...": 0.35}

    def bells(b, nbars, vel=0.25):
        for i in range(0, nbars, 2):
            s.note("bell", s.bar(b + i), 3, s.pitch(0) - 12, vel, -0.1, 0.5)

    s.drums(0, 2, tick, 0.35)
    bells(0, 2, 0.3)
    b = 2
    # the planets turn: music box wheels, a glass tune
    s.drums(b, 16, tick, 0.35)
    s.arp("musicbox", b, Ar, "012321", 0.5, 0.36, 0, 0.25, 0.3)
    s.rel("regal", b, Ar, "1:3", 0.32, -2, -0.1, 0.2)
    b = s.mel("glass", b, A, 0.6, 1, -0.2, 0.4)
    # B: the dulcimer, a reedy pad
    s.drums(b, 16, {"k...k...k...": 0.35, "c...........": -0.3}, 0.36)
    s.arp("musicbox", b, Br * 2, "024242", 0.5, 0.3, 0, 0.25, 0.3)
    s.pad("regal", b, Br * 2, 0.18, -1, 0.0, 0.35)
    b = s.mel("dulcimer", b, B1 + B2, 0.55, 0, -0.2, 0.35)
    # A again, an octave of wheels higher, the bells marking the hours
    s.drums(b, 16, tick, 0.35)
    s.arp("musicbox", b, Ar, "012321", 0.5, 0.3, 1, 0.25, 0.3)
    s.pad("regal", b, Ar, 0.14, -1, 0.0, 0.35)
    bells(b, 16)
    s.mel("dulcimer", b, A, 0.35, 0, 0.3, 0.3, dshift=2)
    b = s.mel("glass", b, A, 0.55, 1, -0.2, 0.4)
    # the orrery slows to a stop
    beat, gap = s.bar(b), 0.5
    for k, d in enumerate([0, 1, 2, 4, 2, 1, 0, 4, 0]):
        s.note("musicbox", beat, 1, s.pitch(d), 0.42 - k * 0.02, 0.2, 0.3)
        beat += gap
        gap *= 1.15
    s.note("bell", beat, 3, s.pitch(0) - 12, 0.3, -0.1, 0.5)
    return s


def clock_peace_3():
    s = Song("clock_peace_3", "Rust and Rain", 76, 4, n("A", 4), "aeolian", reverb=(2.8, 0.45), humanize=0.0,
             seed=312, q=2, ceiling=0.8)
    A = ["5:2 4:1 3:1", "4:2 2:2", "3:1 2:1 1:1 7,:1", "1:3 r:1",
         "6:2 5:1 4:1", "5:2 3:2", "4:1 3:1 2:1 3:1", "2:4"]
    Ar = [0, 3, 5, 0, 5, 2, 3, 4]
    A2 = A[:6] + ["4:1 3:1 2:1 5,:1", "1:4"]
    A2r = [0, 3, 5, 0, 5, 2, 4, 0]
    B = ["3':2 2':1 1':1", "7:2 5:2", "6:1 7:1 1':1 2':1", "3':4",
         "4':2 3':1 2':1", "1':2 6:2", "7:1 1':1 2':1 7:1", "5:4"]
    Br = [2, 4, 3, 2, 3, 5, 4, 4]
    ticks = {"k...k..k..k.k...": 0.3}
    rain_deg = [0, 2, 4, 7, 9, 11, 14]

    def rain(b, nbars):
        s.scatter(b, nbars, 2, 5, lambda bt, r: s.note("glass", bt, 1, s.pitch(int(r.choice(rain_deg))) + 12,
                                                       r.uniform(0.1, 0.22), r.uniform(-0.8, 0.8), 0.6))

    total = 35
    rain(0, total - 1)
    for i in range(3, total - 1, 4):
        s.hit("h", s.bar(i) + 2, 0.3, 0.4, 0.4)
    s.drums(0, 2, ticks, 0.3)
    b = 2
    # the old music box
    s.drums(b, 8, ticks, 0.3)
    s.pad("regal", b, Ar, 0.14, -1, 0.0, 0.4)
    s.rel("regal", b, Ar, "1:4", 0.3, -2)
    b = s.mel("musicbox", b, A, 0.58, 0, -0.15, 0.4)
    # the dulcimer, the box ticking along beneath
    s.drums(b, 8, ticks, 0.3)
    s.arp("musicbox", b, A2r, "0212", 1, 0.28, 0, 0.3, 0.3)
    s.rel("regal", b, A2r, "1:4", 0.3, -2)
    b = s.mel("dulcimer", b, A2, 0.55, 0, -0.2, 0.35)
    # a break in the clouds
    s.pad("regal", b, Br, 0.18, -1)
    s.drums(b, 8, {"k.k.k.k.k.k.k.k.": 0.3, "c.......c.......": -0.3}, 0.32)
    s.arp("musicbox", b, Br, "01230123", 0.5, 0.26, 0, 0.3, 0.3)
    b = s.mel("glass", b, B, 0.6, 0, -0.2, 0.4)
    # the tune again, glass a third above, then the box runs down
    s.drums(b, 8, ticks, 0.3)
    s.pad("regal", b, A2r, 0.14, -1, 0.0, 0.4)
    s.rel("regal", b, A2r, "1:4", 0.3, -2)
    s.mel("glass", b, A2, 0.32, 0, 0.3, 0.4, dshift=2)
    b = s.mel("musicbox", b, A2, 0.58, 0, -0.15, 0.4)
    s.hit("h", s.bar(b), 0.4, 0.3, 0.4)
    s.note("musicbox", s.bar(b), 2, s.pitch(0), 0.4, -0.1)
    s.note("musicbox", s.bar(b) + 1.5, 2, s.pitch(4) - 12, 0.32, 0.1)
    s.note("bell", s.bar(b) + 1.5, 3, s.pitch(0) - 24, 0.25)
    return s


def clock_peace_4():
    s = Song("clock_peace_4", "The Assembly Line", 116, 4, n("F", 4), "ionian", reverb=(1.6, 0.3), humanize=0.0,
             seed=313, q=1.5, ceiling=0.78)
    A = ["1:1 3:1 5:1.5 3:0.5", "4:1 6:1 1':2", "7:1 6:1 5:1 4:1", "3:2 5:2",
         "1:1 3:1 5:1.5 3:0.5", "4:1 6:1 2':2", "1':1 7:1 6:1 7:1", "1':4"]
    Ar = [0, 3, 4, 0, 0, 1, 4, 0]
    B = ["3:0.5 4:0.5 5:0.5 6:0.5 5:1 3:1", "2:0.5 3:0.5 4:0.5 5:0.5 4:1 2:1",
         "3:0.5 4:0.5 5:0.5 6:0.5 7:1 5:1", "1':2 5:2",
         "6:0.5 7:0.5 1':0.5 2':0.5 1':1 6:1", "5:0.5 6:0.5 7:0.5 1':0.5 7:1 5:1", "4:1 3:1 2:1 7,:1", "1:4"]
    Br = [0, 1, 4, 0, 1, 4, 4, 0]
    line = {"p.......p.......": 0.0, "k.k.k.k.k.k.k.k.": 0.35}
    line2 = {"p.......p.......": 0.0, "k.k.k.k.k.k.k.k.": 0.35, "....r.......r...": -0.35, "..............h.": 0.3}

    def belt(b, roots, vel=0.24):
        s.arp("dulcimer", b, roots, "01210121", 0.25, vel, 0, -0.3, 0.2, 1.0)
        s.rel("regal", b, roots, "1:1 3:1 5:1 3:1", 0.4, -2, 0.1, 0.15)

    b = s.drums(0, 2, {"p.......p.......": 0.0, "k...k...k...k...": 0.35}, 0.4)
    # the belt starts: a music-box tune over the dulcimer
    belt(b, Ar)
    s.drums(b, 8, line, 0.4)
    b = s.mel("musicbox", b, A, 0.6, 1, 0.2, 0.35)
    # glass takes the tune, ratchets and steam
    belt(b, Ar)
    s.drums(b, 8, line2, 0.42)
    s.pad("regal", b, Ar, 0.16, -1)
    s.mel("musicbox", b, A, 0.35, 1, 0.3, 0.35, dshift=-2)
    b = s.mel("glass", b, A, 0.6, 1, -0.2, 0.35)
    # B: the dulcimer runs
    s.arp("musicbox", b, Br, "0-2-1-2-", 0.5, 0.3, 1, 0.3, 0.3)
    s.rel("regal", b, Br, "1:1 3:1 5:1 3:1", 0.4, -2, 0.1, 0.15)
    s.drums(b, 8, line2, 0.42)
    b = s.mel("dulcimer", b, B, 0.6, 1, -0.2, 0.3)
    # the line stops: a hum, steam, a spark - then it starts again
    s.drums(b, 4, {"p...............": 0.0, "......h.........": 0.3}, 0.4)
    s.note("volt", s.bar(b), 16, s.pitch(0) - 24, 0.3, 0.0, 0.3)
    s.mel("musicbox", b, ["5:2 3:2", "4:2 2:2", "3:2 1:2", "2:4"], 0.5, 1, 0.2, 0.4)
    s.hit("e", s.bar(b + 3) + 3, 0.5, 0.3)
    b += 4
    belt(b, [4] * 4, 0.2)
    s.drums(b, 2, {"p...p...p...p...": 0.0, "k.k.k.k.k.k.k.k.": 0.35}, 0.36)
    s.drums(b + 2, 2, {"p...p...p...p...": 0.0, "kkkkkkkkkkkkkkkk": 0.35}, 0.4)
    s.roll("r", s.bar(b + 3), 4, 0.5, 0.2, 0.5, -0.35)
    b = s.mel("glass", b, ["5:1 6:1 7:1 1':1", "2':2 7:2", "5:1 6:1 7:1 2':1", "4':4"], 0.55, 0, -0.2, 0.35)
    # everyone on the line
    belt(b, Ar, 0.26)
    s.drums(b, 8, line2, 0.45)
    s.pad("regal", b, Ar, 0.16, -1)
    for i in range(0, 8, 2):
        s.note("bell", s.bar(b + i), 3, s.pitch(0) - 12, 0.22, -0.1, 0.4)
    s.mel("musicbox", b, A, 0.4, 0, 0.3, 0.35)
    b = s.mel("glass", b, A, 0.58, 1, -0.2, 0.35)
    s.arp("musicbox", b, Br, "0-2-1-2-", 0.5, 0.3, 1, 0.3, 0.3)
    s.rel("regal", b, Br, "1:1 3:1 5:1 3:1", 0.42, -2, 0.1, 0.15)
    s.pad("regal", b, Br, 0.15, -1)
    s.drums(b, 8, line2, 0.45)
    s.mel("glass", b, B, 0.42, 1, 0.3, 0.35)
    b = s.mel("dulcimer", b, B, 0.6, 1, -0.2, 0.3)
    s.hit("p", s.bar(b), 0.7)
    s.hit("h", s.bar(b) + 0.5, 0.6, 0.3)
    s.note("glass", s.bar(b), 2, s.pitch(7), 0.55)
    s.note("regal", s.bar(b), 2, s.pitch(0) - 24, 0.4)
    for d in (0, 2, 4):
        s.note("musicbox", s.bar(b), 2, s.pitch(d), 0.4, 0.2)
    return s


def clock_battle_2():
    s = Song("clock_battle_2", "Overclock", 152, 4, n("E", 4), "aeolian", reverb=(1.3, 0.3), humanize=0.0,
             seed=321, q=2)
    A = ["1:1.5 2:0.5 3:1 5:1", "4:1 3:0.5 2:0.5 3:2", "5:1.5 6:0.5 7:1 5:1", "4:2 2:2",
         "3:1.5 4:0.5 5:1 3:1", "6:2 5:1 3:1", "4:1 5:1 6:1 7:1", "2':2 7:2"]
    Ar = [0, 0, 2, 6, 5, 5, 6, 6]
    B = ["1':1 1':0.5 7:0.5 1':1 2':1", "3':2 2':2", "1':1 1':0.5 7:0.5 1':1 5:1", "6:4",
         "6:1 6:0.5 5:0.5 6:1 7:1", "1':2 7:2", "6:1 5:1 4:1 3:1", "2:2 7,+:2"]
    Br = [5, 2, 5, 3, 3, 0, 3, 4]
    ost = "1:0.5 8:0.5 5:0.5 8:0.5 1:0.5 8:0.5 6:0.5 5:0.5"
    m1 = {"p...a...p...a...": 0.0, "k.k.k.k.k.k.k.k.": 0.35}
    m2 = {"p...a..pp...a...": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "c.....c.....c...": -0.3, "..............h.": 0.2}
    fill = {"p.a.p.a.aaaaaaaa": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "...............h": 0.2}

    def machine(b, roots, vel=0.42):
        s.rel("regal", b, roots, ost, vel, -1, -0.1, 0.15, 0.9)
        s.rel("volt", b, roots, "1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5", 0.35, -2, 0.1, 0.1, 0.8)

    # spin-up: the ticking doubles, then doubles again
    s.drums(0, 1, {"k...k...k...k...": 0.35}, 0.4)
    s.drums(1, 1, {"k.k.k.k.k.k.k.k.": 0.35}, 0.45)
    s.drums(2, 2, {"kkkkkkkkkkkkkkkk": 0.35, "p.......p.......": 0.0}, 0.5)
    s.roll("h", s.bar(3), 4, 0.25, 0.1, 0.6, 0.2)
    s.note("volt", 0, 16, s.pitch(0) - 24, 0.3)
    s.rel("regal", 2, [0, 0], ost, 0.4, -1, -0.1)
    b = 4
    machine(b, Ar)
    s.drums(b, 8, m1, 0.55, fill=fill)
    b = s.mel("horn", b, A, 0.62, 0, -0.2, 0.25, legato=0.92)
    machine(b, Ar)
    s.drums(b, 8, m2, 0.58, fill=fill)
    s.mel("glass", b, A, 0.4, 1, 0.3, 0.3, dshift=2)
    s.mel("brass", b, A, 0.4, 0, 0.2, 0.25, legato=0.9)
    b = s.mel("horn", b, A, 0.6, 0, -0.2, 0.25, legato=0.92)
    # B: pressure rising
    machine(b, Br)
    s.pad("regal", b, Br, 0.2, 0, 0.0, 0.25, voicing=(0, 2, 3))
    s.arp("musicbox", b, Br, "0-2-3-2-", 0.5, 0.3, 1, 0.3, 0.2, 1.0)
    s.drums(b, 8, m2, 0.6, fill=fill)
    b = s.mel("brass", b, B, 0.65, 0, -0.2, 0.3, legato=0.9)
    # valves open: pistons and buzz only
    s.drums(b, 4, {"p.......p..p....": 0.0, "......e.........": 0.3}, 0.55)
    s.rel("volt", b, [0, 0, 5, 6], "1:0.5 r:0.5 1:0.5 r:0.5 1:0.5 r:0.5 1:0.5 r:0.5", 0.42, -2)
    b += 4
    # build: anvils in eighths, a steam roll, the horn climbs
    machine(b, [5, 5, 6, 6], 0.4)
    s.roll("a", s.bar(b), 16, 0.5, 0.15, 0.6, 0.0)
    s.roll("h", s.bar(b + 2), 8, 0.25, 0.1, 0.7, 0.2)
    s.drums(b, 4, {"kkkkkkkkkkkkkkkk": 0.35}, 0.45)
    b = s.mel("horn", b, ["5:4", "6:4", "7:4", "2':4"], 0.5, 0, -0.2, 0.25)
    # A, a whole tone up: overclocked
    s.tonic += 2
    machine(b, Ar, 0.45)
    s.drums(b, 8, m2, 0.62, fill=fill)
    s.pad("regal", b, Ar, 0.18, 0, 0.0, 0.25)
    s.mel("glass", b, A, 0.42, 1, 0.3, 0.3, dshift=2)
    s.mel("brass", b, A, 0.45, 0, 0.2, 0.25, legato=0.9)
    b = s.mel("horn", b, A, 0.62, 0, -0.2, 0.25, legato=0.92)
    s.tonic -= 2
    machine(b, Br, 0.45)
    s.pad("regal", b, Br, 0.2, 0, 0.0, 0.25, voicing=(0, 2, 3))
    s.arp("musicbox", b, Br, "0-2-3-2-", 0.5, 0.3, 1, 0.3, 0.2, 1.0)
    s.drums(b, 8, m2, 0.62, fill=fill)
    s.mel("horn", b, B, 0.45, -1, 0.2, 0.3, legato=0.9)
    b = s.mel("brass", b, B, 0.66, 0, -0.2, 0.3, legato=0.9)
    machine(b, [4], 0.45)
    s.drums(b, 1, fill, 0.65)
    b += 1
    s.hit("a", s.bar(b), 0.9)
    s.hit("h", s.bar(b), 0.8)
    s.hit("p", s.bar(b), 0.8)
    s.note("horn", s.bar(b), 3, s.pitch(0), 0.6)
    s.note("volt", s.bar(b), 1.5, s.pitch(0) - 24, 0.5)
    s.note("regal", s.bar(b), 3, s.pitch(0) - 12, 0.5)
    return s


def clock_battle_3():
    # 5/4 (3+2)
    s = Song("clock_battle_3", "Gearstorm", 140, 5, n("G", 4), "phrygian", reverb=(1.4, 0.3), humanize=0.0,
             seed=322, q=1.5, ceiling=0.8)
    ost = "1:1 1:0.5 1:0.5 2:1 1:1 7,:1"
    A = ["5:1.5 4:0.5 5:1 6:1 5:1", "4:1 3:1 2:1 1:2", "5:1.5 4:0.5 5:1 1':1 7:1", "6:5",
         "1':1.5 7:0.5 6:1 5:1 4:1", "3:1 4:1 5:3", "4:1 3:1 2:1 1:1 2:1", "1:5"]
    Ar = [0, 0, 0, 5, 3, 0, 1, 0]
    B = ["1':2 7:1 6:2", "5:2 4:1 3:2", "4:2 5:1 6:2", "5:5",
         "1':2 2':1 3':2", "2':2 1':1 7:2", "6:1 5:1 4:1 3:1 2:1", "1:5"]
    Br = [5, 0, 3, 0, 5, 6, 1, 0]
    g1 = {"a...k...k...a...k...": 0.0, "k.k.k.k.k.k.k.k.k.k.": 0.35}
    g2 = {"a..ca...k.c.a..ck.c.": 0.0, "kkkkkkkkkkkkkkkkkkkk": 0.35, "p...........p.......": -0.1,
          "...........r........": -0.35}
    fill = {"a.a.a.a.a.aaaaaaaaaa": 0.0, "kkkkkkkkkkkkkkkkkkkk": 0.35, "...................h": 0.2}

    def gears(b, roots, vel=0.42):
        s.rel("volt", b, roots, ost, vel, -2, 0.0, 0.1, 0.9)

    # spin-up: ratchets wind it, the buzz rises
    s.note("volt", 0, 20, s.pitch(0) - 24, 0.3)
    s.drums(0, 1, {"r...................": 0.0}, 0.5)
    s.drums(1, 1, {"r.........r.........": 0.0}, 0.5)
    s.drums(2, 2, {"k.k.k.k.k.k.k.k.k.k.": 0.35, "r....r....r....r....": -0.2}, 0.5)
    s.roll("h", s.bar(3) + 2, 3, 0.25, 0.1, 0.6, 0.2)
    b = 4
    gears(b, Ar)
    s.drums(b, 8, g1, 0.55, fill=fill)
    b = s.mel("horn", b, A, 0.62, 0, -0.2, 0.25, legato=0.92)
    gears(b, Ar)
    s.drums(b, 8, g2, 0.58, fill=fill)
    s.arp("musicbox", b, Ar, "0-2-1-3-2-", 0.5, 0.3, 0, 0.3, 0.2, 1.0)
    s.mel("horn", b, A, 0.45, -1, 0.2, 0.25, legato=0.92)
    b = s.mel("brass", b, A, 0.62, 0, -0.2, 0.25, legato=0.9)
    # B: the brass over a reedy wall
    gears(b, Br)
    s.pad("regal", b, Br, 0.22, 0, 0.0, 0.25)
    s.arp("glass", b, Br, "0-2-1-3-2-", 0.5, 0.3, 1, 0.3, 0.25, 1.0)
    s.drums(b, 8, g2, 0.6, fill=fill)
    b = s.mel("brass", b, B, 0.65, 0, -0.2, 0.3, legato=0.9)
    # a stall: steam and sparks
    s.hit("h", s.bar(b), 0.7, 0.2)
    s.hit("e", s.bar(b) + 2, 0.6, 0.3)
    s.hit("e", s.bar(b) + 2.75, 0.5, -0.3)
    s.hit("a", s.bar(b + 1) + 3, 0.7)
    s.note("volt", s.bar(b), 8, s.pitch(0) - 24, 0.3)
    b += 2
    # build: the gears catch again
    gears(b, [0, 0, 1, 1], 0.4)
    s.rel("regal", b + 2, [1, 1], ost, 0.35, -1, -0.1)
    s.roll("c", s.bar(b), 20, 0.5, 0.15, 0.6, -0.3)
    s.roll("k", s.bar(b + 2), 10, 0.25, 0.2, 0.7, 0.35)
    b = s.mel("horn", b, ["1:5", "2:5", "4:5", "5:5"], 0.5, 0, -0.2, 0.25)
    # everything
    gears(b, Ar, 0.45)
    s.pad("regal", b, Ar, 0.2, 0, 0.0, 0.25)
    s.drums(b, 8, g2, 0.62, fill=fill)
    s.arp("musicbox", b, Ar, "0-2-1-3-2-", 0.5, 0.3, 0, 0.3, 0.2, 1.0)
    s.mel("glass", b, A, 0.35, 1, 0.3, 0.3)
    s.mel("horn", b, A, 0.45, -1, 0.2, 0.25, legato=0.92)
    b = s.mel("brass", b, A, 0.65, 0, -0.2, 0.25, legato=0.9)
    s.drums(b, 1, fill, 0.65)
    gears(b, [0], 0.45)
    b += 1
    s.hit("a", s.bar(b), 0.9)
    s.hit("h", s.bar(b), 0.8)
    s.hit("p", s.bar(b), 0.8)
    s.note("brass", s.bar(b), 3, s.pitch(0), 0.6)
    s.note("volt", s.bar(b), 1.5, s.pitch(0) - 24, 0.5)
    s.note("regal", s.bar(b), 3, s.pitch(0) - 12, 0.5)
    return s


# =========================================================================== ORCHESTRA
# Helpers for the orchestral pieces (menu_2.., and the later faction pieces). Harmony is written with
# absolute chord names ("Bm", "D/F#", "Bbsus"); melodies stay in scale degrees (Song.mel).
# Instruments: strings / lowstr (legato section), spicc (ostinato), pizz, trem; horns, tpts, lowbr;
# chorus / chorus_o / chorus_u (massed choir); flute, oboe, clar, celesta, harp; cymswell.
# Percussion codes: T taiko, b concert bass drum, Y crash, y suspended cymbal, G gong, l low tom, m steam hammer.

def _rel_parse(rhythm):
    out, pos = [], 0.0
    for tok in rhythm.split():
        deg, dur = tok.split(":")
        out.append((pos, float(dur), deg))
        pos += float(dur)
    return out


def o_pad(s, inst, b, chords, vel, center, count=3, pan=0.0, spread=0.5, send=0.45, each=1, legato=0.99,
          shape=None, offset=0.0, beats=None):
    """Sustained chords, one per `each` bars, voiced closely upward from `center` (a MIDI note)."""
    for i, c in enumerate(chords):
        if not c:
            continue
        ms = voicing(c, center, count)
        for k, m in enumerate(ms):
            p = pan + (k / (len(ms) - 1) - 0.5) * spread if len(ms) > 1 else pan
            s.note(inst, s.bar(b + i * each) + offset, (beats or s.meter * each) * legato, m, vel, p, send, shape)
    return b + len(chords) * each


def o_bass(s, inst, b, chords, rhythm, vel, lo=36, pan=0.2, send=0.2, legato=0.92, each=1, shape=None):
    """A line relative to each chord: 1 3 5 7 8 (',' down an octave, "'" up); a slash chord's 1 is its bass."""
    for i, c in enumerate(chords):
        if not c:
            continue
        r, iv, sl = chord(c)
        root = lo + (r - lo) % 12
        for off, dur, tok in _rel_parse(rhythm):
            if tok == "r":
                continue
            m = bass_of(c, lo) + 12 * (tok.count("'") - tok.count(",")) if tok.strip("',") == "1" else \
                root + rel_interval(tok, iv)
            s.note(inst, s.bar(b + i * each) + off, dur * legato, m, vel, pan, send, shape)
    return b + len(chords) * each


def o_ost(s, inst, b, chords, pattern, step, vel, center, count=4, pan=0.0, send=0.25, legato=0.9, each=1,
          acc=None, accent=0.1):
    """Ostinato on the chord tones: pattern digits index the voiced chord (past `count` = an octave up)."""
    steps = int(round(s.meter * each / step))
    for i, c in enumerate(chords):
        if not c:
            continue
        ms = voicing(c, center, count)
        for k in range(steps):
            p = pattern[k % len(pattern)]
            if p == "-":
                continue
            d = int(p)
            m = ms[d % len(ms)] + 12 * (d // len(ms))
            a = accent if (acc[k % len(acc)] == ">" if acc else k == 0) else 0.0
            s.note(inst, s.bar(b + i * each) + k * step, step * legato, m, vel + a, pan, send)
    return b + len(chords) * each


def o_timp(s, beat, c, vel=0.6, lo=38):
    s.note("timpani", beat, 1.0, bass_of(c, lo) if isinstance(c, str) else c, vel, -0.1, 0.25)


def o_timp_roll(s, beat, beats, c, v0, v1, lo=38, rate=13.0):
    """A timpani roll (single strokes, ~13 a second) from v0 to v1."""
    m = bass_of(c, lo) if isinstance(c, str) else c
    step = s.bpm / 60.0 / rate
    k = max(2, int(beats / step))
    for i in range(k):
        s.note("timpani", beat + i * step, 1.0, m, (v0 + (v1 - v0) * i / (k - 1)) * 0.5, -0.1, 0.25)


def o_timps(s, b, chords, vel, beats=(0,), lo=38):
    for i, c in enumerate(chords):
        if c:
            for k, bt in enumerate(beats):
                o_timp(s, s.bar(b + i) + bt, c, vel * (1.0 if k == 0 else 0.75), lo)


def o_swell(s, beat, beats, vel=0.6):
    """Cymbal swell into `beat + beats`."""
    s.note("cymswell", beat, beats, 60, vel, 0.25, 0.5)


def o_crash(s, beat, vel=0.75, drum="b"):
    s.hit("Y", beat, vel, 0.3, 0.4)
    if drum:
        s.hit(drum, beat, vel, 0.0, 0.25)


def o_final(s, b, c, vel, insts, center=55, bars=2, bass_lo=36):
    """The last chord: everyone holds it, with a timpani stroke, a crash and the bass."""
    for inst, cnt, off in insts:
        o_pad(s, inst, b, [c], vel, center + off, cnt, 0.0, 0.7, 0.5, each=bars, legato=0.97)
    o_bass(s, "lowbr", b, [c], "1:%d" % (s.meter * bars), vel * 0.85, bass_lo, 0.2, 0.25, 0.97, each=bars)
    o_bass(s, "lowstr", b, [c], "1:%d" % (s.meter * bars), vel * 0.8, bass_lo, 0.3, 0.3, 0.97, each=bars)
    o_timp(s, s.bar(b), c, vel)
    o_crash(s, s.bar(b), vel)


# =========================================================================== MENU, the overtures
# The menu shuffles through all of these (scripts/music.gd), never the same twice in a row.

def menu_2():
    """A heroic march in D that climbs to E for the last statement."""
    s = Song("menu_2", "The Banners Rise", 104, 4, n("D", 4), "ionian", reverb=(2.8, 0.45), seed=501, q=1.5,
             mastering="epic", predelay=0.02)
    A = ["1:1.5 5,:0.5 1:1 3:1", "6:2 5:1 4:1", "2:1.5 6,:0.5 2:1 4:1", "2:1 1:1 2:2",
         "3:1.5 4:0.5 5:1 3:1", "1':2 7:1 6:1", "5:1.5 4:0.5 3:1 2:1", "1:4"]
    Ac = ["D", "G", "Em", "A", "Bm", "G", "A7", "D"]
    K = ["5:4", "4:4", "5,:4", "7,:4", "1:4", "1:4", "2:2 7,:2", "3,:4"]          # horn counter-line
    B = ["3:2 4:1 5:1", "6:3 5:1", "4:2 3:1 2:1", "3:4", "6:2 7:1 1':1", "2':3 1':1", "7:1.5 6:0.5 5:1 4:1", "5:4"]
    Bc = ["Bm", "G", "Em", "D", "Em", "A", "F#m", "A"]
    march1 = {"S..sS...S..sS.s.": 0.12}
    march2 = {"S.ssS.s.S.ssS.s.": 0.12, "b.......b.......": 0.0}
    march3 = {"S.ssS.s.S.ssS.ss": 0.12, "T.......T...T...": 0.0, "b.......b.......": 0.0}
    fill = {"S.s.s.s.ssssssss": 0.12, "T...T...T.T.TTTT": 0.0}
    # intro: the host gathers in the dark, a horn calls, the drums answer
    s.note("lowstr", 0, 15.5, n("D", 2), 0.45, 0.25, 0.3, "swell")
    s.note("lowstr", 0, 15.5, n("A", 2), 0.35, 0.3, 0.3, "swell")
    s.note("trem", 0, 15.5, n("D", 4), 0.28, -0.3, 0.5, "swell")
    s.note("trem", 0, 15.5, n("A", 4), 0.24, -0.4, 0.5, "swell")
    s.mel("horns", 1, ["1:1.5 5,:0.5 1:2", "3:1.5 2:0.5 1:1 5,:1"], 0.5, 0, -0.2, 0.5)
    o_timp_roll(s, s.bar(3), 4, "D", 0.15, 0.8)
    s.roll("s", s.bar(3), 4, 0.25, 0.1, 0.6, 0.12)
    o_swell(s, s.bar(3), 4, 0.6)
    b = 4
    # A: the horns carry the banner over a spiccato march
    o_crash(s, s.bar(b), 0.55)
    s.mel("horns", b, A, 0.58, 0, -0.2, 0.35, legato=0.97)
    o_ost(s, "spicc", b, Ac, "01210121", 0.5, 0.4, 50, 3, 0.25, 0.2)
    o_bass(s, "lowstr", b, Ac, "1:2 5,:1 1:1", 0.45, 38, 0.25)
    o_pad(s, "strings", b, Ac, 0.2, 69, 3, -0.3, 0.4)
    s.drums(b, 8, march1, 0.32)
    o_timps(s, b, Ac, 0.38)
    b += 8
    # A: trumpets and violins, the horns sing a counter-line, the whole army marches
    o_crash(s, s.bar(b), 0.7)
    s.mel("tpts", b, A, 0.66, 0, 0.15, 0.3, legato=0.92)
    s.mel("strings", b, A, 0.55, 1, -0.35, 0.35, legato=1.0)
    s.mel("horns", b, K, 0.5, 0, -0.15, 0.35)
    o_ost(s, "spicc", b, Ac, "0121", 0.25, 0.38, 50, 3, 0.25, 0.2)
    o_bass(s, "lowbr", b, Ac, "1:2 5,:1 1:1", 0.5, 38, 0.3)
    o_bass(s, "lowstr", b, Ac, "1:1 1:1 5,:1 1:1", 0.45, 38, 0.25)
    o_pad(s, "chorus", b, Ac, 0.28, 62, 3)
    s.drums(b, 8, march2, 0.45, fill=fill)
    o_timps(s, b, Ac, 0.55, (0, 2))
    b += 8
    # B: the long road - the violins sing, the flute answers, a harp keeps time
    s.mel("strings", b, B, 0.55, 0, -0.3, 0.45, legato=1.0, shape="arc", shape_min=3)
    s.mel("flute", b + 4, B[4:], 0.38, 1, 0.3, 0.5, dshift=-2)
    o_ost(s, "harp", b, Bc, "01232123", 0.5, 0.42, 50, 4, 0.35, 0.4, 1.4)
    o_pad(s, "horns", b, Bc, 0.24, 55, 3, -0.1, 0.4, 0.5)
    o_bass(s, "lowstr", b, Bc, "1:4", 0.4, 38, 0.25)
    for i in range(0, 8, 2):
        o_timp(s, s.bar(b + i), Bc[i], 0.28)
    b += 8
    # a chorale: horns, trombones and the choir
    Cc = ["G", "D/F#", "Em", "Bm", "C", "A"]
    o_pad(s, "horns", b, Cc, 0.42, 55, 4, -0.1, 0.5, 0.45, shape="arc")
    o_pad(s, "chorus_o", b, Cc, 0.36, 62, 3, 0.0, 0.8, 0.6, shape="arc")
    o_bass(s, "lowbr", b, Cc, "1:4", 0.38, 36, 0.3, 0.3, 0.98)
    o_bass(s, "pizz", b, Cc, "1:1 r:1 5,:1 r:1", 0.45, 38, 0.3)
    s.mel("strings", b, ["7:2 1':2", "1':4", "7:2 6:2", "5:4", "5:2 3:2", "4+:2 5:2"], 0.4, 0, -0.35, 0.5,
          legato=1.0, shape="arc")
    b += 6
    # the build: the whole host climbs towards a new key
    Dc = ["G", "A", "C", "B"]
    for i, c in enumerate(Dc):
        o_ost(s, "spicc", b + i, [c], "0101", 0.25, 0.35 + 0.08 * i, 50, 3, 0.25, 0.2)
    s.mel("tpts", b, ["4:4", "5:4", "7-:4", "6:1 7:1 1+':2"], 0.55, 0, 0.15, 0.35, shape="swell", shape_min=4)
    o_pad(s, "horns", b, Dc, 0.45, 55, 3, -0.15, 0.5, shape="swell")
    o_pad(s, "strings", b, Dc, 0.4, 62, 3, -0.3, 0.5, shape="swell")
    o_bass(s, "lowbr", b, Dc, "1:4", 0.45, 36, 0.3, shape="swell")
    o_bass(s, "lowstr", b, Dc, "1:1 1:1 1:1 1:1", 0.48, 38, 0.25)
    s.roll("s", s.bar(b), 16, 0.25, 0.1, 0.75, 0.12)
    o_timp_roll(s, s.bar(b + 2), 8, "B", 0.25, 0.9)
    o_swell(s, s.bar(b + 2), 8, 0.75)
    b += 4
    # A in E: everyone, the choir sings the banner song
    s.tonic += 2
    Ac2, K2 = transpose(Ac, 2), K
    o_crash(s, s.bar(b), 0.9, "T")
    s.mel("tpts", b, A, 0.75, 0, 0.15, 0.3, legato=0.92)
    s.mel("horns", b, A, 0.68, 0, -0.15, 0.3)
    s.mel("strings", b, A, 0.68, 1, -0.35, 0.35, legato=1.0)
    s.mel("chorus", b, A, 0.55, 0, 0.0, 0.5, legato=1.0)
    s.mel("lowstr", b, K2, 0.5, -1, 0.3, 0.3)
    o_ost(s, "spicc", b, Ac2, "0121", 0.25, 0.42, 52, 3, 0.25, 0.2)
    o_bass(s, "lowbr", b, Ac2, "1:2 5,:1 1:1", 0.62, 40, 0.3)
    s.drums(b, 8, march3, 0.55, fill=fill)
    o_timps(s, b, Ac2, 0.7, (0, 2))
    o_crash(s, s.bar(b + 4), 0.6, None)
    b += 8
    # coda: broadening, then the last chord
    Ec = ["A", "F#m7", "Bsus", "B"]
    o_crash(s, s.bar(b), 0.7, "b")
    s.mel("tpts", b, ["1':1.5 7:0.5 6:2", "6:1.5 5:0.5 4:2", "5:4", "7,:2 2:2"], 0.72, 0, 0.15, 0.35)
    s.mel("strings", b, ["1':1.5 7:0.5 6:2", "6:1.5 5:0.5 4:2", "5:4", "7,:2 2:2"], 0.62, 1, -0.35, 0.35, legato=1.0)
    o_pad(s, "horns", b, Ec, 0.6, 52, 4, -0.1, 0.5)
    o_pad(s, "chorus", b, Ec, 0.5, 59, 3)
    o_bass(s, "lowbr", b, Ec, "1:4", 0.6, 36, 0.3)
    o_bass(s, "lowstr", b, Ec, "1:2 1:1 1:1", 0.55, 38, 0.25)
    o_timps(s, b, Ec[:3], 0.65, (0, 2))
    s.drums(b, 3, {"S...S...S.s.S.s.": 0.12, "b.......b.......": 0.0}, 0.5)
    s.drums(b + 3, 1, fill, 0.6)
    o_timp_roll(s, s.bar(b + 3), 4, "B", 0.4, 0.9)
    b += 4
    o_final(s, b, "E", 0.82, [("horns", 4, 0), ("strings", 4, 7), ("chorus", 4, 4), ("tpts", 3, 12)], 52, 2, 40)
    s.hit("T", s.bar(b), 0.85)
    s.hit("G", s.bar(b), 0.5)
    s.note("tpts", s.bar(b), 7.5, s.pitch(7), 0.72, 0.15, 0.35)
    return s


def menu_3():
    """A dark prelude in C minor: the theme rises from the low strings to a storm, then a dawn in C major."""
    s = Song("menu_3", "Before the Long Night", 64, 4, n("C", 4), "aeolian", reverb=(3.6, 0.6), seed=502, q=1.5,
             mastering="epic", predelay=0.03, humanize=0.008)
    T = ["5:3 6:1", "5:2 4:1 3:1", "4:3 3:0.5 2:0.5", "3:4",
         "1':2 7:1 6:1", "5:2 6:1 4:1", "3:1.5 2:0.5 1:1 7+,:1", "1:4"]
    Tc = ["Cm", "Ab", "Bb", "Cm", "Ab", "Fm", "G", "Cm"]
    K = ["3':4", "1':4", "2':4", "1':2 7:2", "1':4", "6:2 1':2", "7+:2 2':2", "1':4"]
    beat = {"T.......T.......": 0.0}
    beat2 = {"T.......T..T....": 0.0, "....l.......l.l.": 0.35}
    storm = {"T..TT...T..TT.T.": 0.0, "b.......b.......": 0.0, "....l.......l.ll": 0.35}
    # the dark: a gong, a pedal in the basses, a heartbeat, the clarinet remembers something
    s.hit("G", 0, 0.55)
    s.note("lowstr", 0, 23.5, n("C", 2), 0.42, 0.3, 0.3, "arc")
    s.note("lowstr", s.bar(1), 19.5, n("G", 2), 0.3, 0.35, 0.3, "arc")
    o_pad(s, "trem", 0, ["Cm"], 0.2, 60, 3, -0.3, 0.6, each=6, shape="swell")
    s.note("chorus_u", s.bar(2), 15.5, n("C", 3), 0.38, 0.0, 0.6, "arc")
    for i in range(6):
        s.hit("T", s.bar(i), 0.32 + 0.04 * i, 0.0, 0.3)
        s.hit("T", s.bar(i) + 0.75, 0.2 + 0.03 * i, 0.0, 0.3)
    s.mel("clar", 2, T[:4], 0.5, -1, 0.2, 0.5, legato=1.0)
    b = 6
    # the celli take the theme
    s.mel("lowstr", b, T, 0.55, -1, 0.25, 0.4, legato=1.0, shape="arc", shape_min=3)
    o_pad(s, "trem", b, Tc, 0.2, 67, 3, -0.3, 0.6)
    o_bass(s, "lowstr", b, Tc, "1:4", 0.36, 36, 0.35)
    o_pad(s, "chorus_u", b, Tc, 0.24, 55, 3)
    s.drums(b, 8, beat, 0.4)
    s.hit("G", s.bar(b + 4), 0.3)
    o_timps(s, b, Tc, 0.3)
    b += 8
    # the horns, the violins weeping above them, trombones underneath
    s.mel("horns", b, T, 0.58, 0, -0.15, 0.4, shape="arc", shape_min=3)
    s.mel("strings", b, K, 0.45, 0, -0.35, 0.45, legato=1.0, shape="arc", shape_min=3)
    o_pad(s, "lowbr", b, Tc, 0.3, 43, 2, 0.3, 0.3, 0.3, shape="swell")
    o_bass(s, "lowstr", b, Tc, "1:2 1:1 5,:1", 0.42, 36, 0.35)
    o_pad(s, "chorus_o", b, Tc, 0.26, 55, 3)
    s.drums(b, 8, beat2, 0.45)
    o_timps(s, b, Tc, 0.42, (0, 2.5))
    # the storm gathers
    o_timp_roll(s, s.bar(b + 7), 4, "G", 0.3, 0.95)
    o_swell(s, s.bar(b + 7), 4, 0.8)
    s.roll("l", s.bar(b + 7), 4, 0.25, 0.2, 0.7, 0.35)
    b += 8
    # the storm: the choir and the trumpets cry the theme
    for half in (0, 4):
        o_crash(s, s.bar(b + half), 0.85 if half == 0 else 0.7, "b")
    s.mel("tpts", b, T, 0.72, 0, 0.15, 0.3)
    s.mel("horns", b, T, 0.66, 0, -0.15, 0.3)
    s.mel("chorus", b, T, 0.6, 0, 0.0, 0.55, legato=1.0)
    s.mel("strings", b, T, 0.62, 1, -0.35, 0.4, legato=1.0)
    s.mel("lowstr", b, K, 0.55, -2, 0.3, 0.3, legato=1.0)
    o_pad(s, "trem", b, Tc, 0.35, 67, 3, -0.3, 0.6)
    o_bass(s, "lowbr", b, Tc, "1:2 1:1 5,:1", 0.68, 36, 0.3, 0.3)
    s.drums(b, 8, storm, 0.58, fill={"T.T.TTT.TTTTTTTT": 0.0, "b...b...b.b.bbbb": 0.0})
    o_timps(s, b, Tc, 0.7, (0, 1.5, 2.5))
    b += 8
    # after the storm: the oboe alone, the choir humming, the heart slowing
    s.hit("G", s.bar(b), 0.55)
    s.mel("oboe", b, T, 0.55, 0, 0.2, 0.5, legato=1.0)
    o_pad(s, "strings", b, Tc, 0.26, 55, 3, -0.2, 0.6, 0.55)
    o_pad(s, "chorus_u", b, Tc, 0.22, 48, 3, 0.0, 0.6)
    o_bass(s, "lowstr", b, Tc, "1:4", 0.34, 36, 0.35)
    for i in (0, 2, 4, 6):
        s.hit("T", s.bar(b + i), 0.4 - 0.04 * i, 0.0, 0.35)
    b += 8
    # dawn: C major
    o_pad(s, "chorus_o", b, ["C"], 0.45, 55, 4, 0.0, 0.8, 0.6, each=2, shape="arc")
    o_pad(s, "strings", b, ["C"], 0.4, 60, 4, -0.3, 0.6, 0.6, each=2, shape="arc")
    o_pad(s, "horns", b, ["C"], 0.38, 48, 3, -0.1, 0.4, 0.5, each=2, shape="arc")
    s.note("lowstr", s.bar(b), 7.8, n("C", 2), 0.45, 0.3, 0.3, "arc")
    s.note("flute", s.bar(b) + 2, 5.5, n("E", 5), 0.35, 0.3, 0.6)
    s.hit("G", s.bar(b), 0.35)
    o_timp(s, s.bar(b), "C", 0.35)
    return s


def menu_4():
    """A soaring theme in E-flat: a lone horn, then the strings, then everyone, lifted into F."""
    s = Song("menu_4", "Over the High Passes", 84, 4, n("E", 4) - 1, "ionian", reverb=(3.0, 0.45), seed=503,
             q=1.5, mastering="epic", predelay=0.025)
    A = ["5,:1 1:1 5:2", "4:1.5 3:0.5 2:2", "3:1 5:1 1':2", "6:1.5 5:0.5 6:1 1':1",
         "5:2 3:1 1:1", "4:1 6:1 1':1 3':1", "2':2 1':1 7:1", "1':4"]
    Ac = ["Eb", "Bb/D", "Cm", "Ab", "Eb/Bb", "Ab", "Bb", "Eb"]
    B = ["3':2 2':1 1':1", "1':2 6:2", "5:1 6:1 7:1 1':1", "2':4",
         "3':1.5 4':0.5 5':2", "4':1 3':1 2':1 1':1", "1':1.5 7:0.5 1':1 5:1", "2':4"]
    Bc = ["Cm", "Ab", "Eb", "Bb", "Cm", "Ab", "Eb/Bb", "Bb7"]
    K = ["3:4", "2:4", "1:2 7,:2", "1:4", "7,:4", "1:4", "4:2 2:2", "3:4"]         # cello counter-line
    harp = "01232123"
    # dawn on the mountain: harp, a flute, the strings breathing in
    Ic = ["Eb", "Cm", "Ab", "Bb"]
    o_ost(s, "harp", 0, Ic, harp, 0.5, 0.42, 51, 4, 0.35, 0.45, 1.6)
    o_pad(s, "strings", 0, Ic, 0.3, 58, 3, -0.2, 0.6, 0.55, shape="arc")
    s.mel("flute", 1, ["5:1 1':1 2':2", "1':4", "7:2 5:2"], 0.4, 0, 0.3, 0.55)
    o_bass(s, "lowstr", 0, Ic, "1:4", 0.32, 36, 0.3)
    b = 4
    # a lone horn sings the theme
    s.mel("horns", b, A, 0.58, -1, -0.15, 0.45, legato=0.98, shape="arc", shape_min=3)
    o_ost(s, "harp", b, Ac, harp, 0.5, 0.36, 51, 4, 0.35, 0.45, 1.6)
    o_pad(s, "strings", b, Ac, 0.24, 58, 3, -0.2, 0.6, 0.5)
    o_bass(s, "lowstr", b, Ac, "1:4", 0.36, 36, 0.3)
    b += 8
    # the violins take it up, the flute an octave above, the celli answer
    s.mel("strings", b, A, 0.58, 0, -0.35, 0.45, legato=1.0, shape="arc", shape_min=3)
    s.mel("flute", b, A, 0.3, 1, 0.3, 0.5)
    s.mel("lowstr", b, K, 0.45, -1, 0.3, 0.4, legato=1.0)
    o_ost(s, "harp", b, Ac, harp, 0.5, 0.34, 51, 4, 0.35, 0.45, 1.6)
    o_pad(s, "horns", b, Ac, 0.26, 51, 3, -0.1, 0.4, 0.45)
    o_bass(s, "lowstr", b, Ac, "1:2 5,:2", 0.38, 36, 0.3)
    for i in range(0, 8, 2):
        o_timp(s, s.bar(b + i), Ac[i], 0.28)
    b += 8
    # B: higher, the choir comes in, the horns in harmony
    s.mel("strings", b, B, 0.62, 0, -0.35, 0.45, legato=1.0, shape="arc", shape_min=3)
    s.mel("horns", b, B, 0.4, -1, -0.1, 0.4, dshift=-2)
    o_pad(s, "chorus", b, Bc, 0.3, 58, 3, 0.0, 0.8, 0.6)
    o_ost(s, "harp", b, Bc, harp, 0.5, 0.32, 51, 4, 0.35, 0.45, 1.6)
    o_bass(s, "lowstr", b, Bc, "1:2 5,:2", 0.42, 36, 0.3)
    o_bass(s, "lowbr", b, Bc, "1:4", 0.3, 36, 0.3, 0.3)
    o_timps(s, b, Bc, 0.38)
    b += 8
    # the pass: up a tone
    Mc = ["Cm", "Ab", "Bb", "C7"]
    s.mel("strings", b, ["3:4", "4:2 6:2", "5:2 7:2", "1+':4"], 0.55, 0, -0.35, 0.45, legato=1.0, shape="swell",
          shape_min=4)
    s.mel("tpts", b + 2, ["5:2 7:2", "1+':4"], 0.5, 0, 0.15, 0.4, shape="swell", shape_min=4)
    o_pad(s, "horns", b, Mc, 0.45, 51, 3, -0.1, 0.5, shape="swell")
    o_pad(s, "chorus", b, Mc, 0.38, 58, 3, 0.0, 0.8, 0.6, shape="swell")
    o_bass(s, "lowbr", b, Mc, "1:4", 0.45, 36, 0.3, shape="swell")
    o_bass(s, "lowstr", b, Mc, "1:1 1:1 1:1 1:1", 0.45, 36, 0.3)
    o_timp_roll(s, s.bar(b + 2), 8, "C", 0.25, 0.9)
    o_swell(s, s.bar(b + 2), 8, 0.75)
    s.roll("s", s.bar(b + 3), 4, 0.25, 0.1, 0.55, 0.12)
    b += 4
    # over the top: everyone, in F
    s.tonic += 2
    A2c, B2c = transpose(Ac, 2), transpose(Bc, 2)
    o_crash(s, s.bar(b), 0.9, "T")
    s.mel("tpts", b, A, 0.72, 0, 0.15, 0.3, legato=0.95)
    s.mel("horns", b, A, 0.66, -1, -0.15, 0.35)
    s.mel("strings", b, A, 0.66, 1, -0.35, 0.4, legato=1.0)
    s.mel("chorus", b, A, 0.55, 0, 0.0, 0.55, legato=1.0)
    s.mel("lowstr", b, K, 0.52, -1, 0.3, 0.35, legato=1.0)
    o_ost(s, "spicc", b, A2c, "01210121", 0.5, 0.38, 53, 3, 0.2, 0.2)
    o_ost(s, "harp", b, A2c, harp, 0.5, 0.3, 53, 4, 0.35, 0.45, 1.6)
    o_bass(s, "lowbr", b, A2c, "1:2 5,:2", 0.6, 36, 0.3, 0.3)
    s.drums(b, 8, {"b.......b.......": 0.0, "T...............": 0.0, "y...y...y...y...": 0.4}, 0.45)
    o_timps(s, b, A2c, 0.6, (0, 2))
    b += 8
    o_crash(s, s.bar(b), 0.75, "b")
    s.mel("strings", b, B, 0.68, 0, -0.35, 0.4, legato=1.0)
    s.mel("tpts", b, B, 0.66, -1, 0.15, 0.3)
    s.mel("chorus", b, B, 0.55, -1, 0.0, 0.55, legato=1.0)
    s.mel("horns", b, B, 0.55, -1, -0.15, 0.35, dshift=-2)
    o_ost(s, "spicc", b, B2c, "01210121", 0.5, 0.4, 53, 3, 0.2, 0.2)
    o_bass(s, "lowbr", b, B2c, "1:2 5,:2", 0.62, 36, 0.3, 0.3)
    o_bass(s, "lowstr", b, B2c, "1:2 1:1 1:1", 0.5, 36, 0.3)
    s.drums(b, 8, {"b.......b.......": 0.0, "T...............": 0.0, "y...y...y...y...": 0.4}, 0.48,
            fill={"b...b...b.b.bbbb": 0.0, "S.s.s.s.ssssssss": 0.12})
    o_timps(s, b, B2c, 0.62, (0, 2))
    b += 8
    # coda: the summit, then the long view
    Cc = ["Bb", "Gm7", "Csus", "C"]
    s.mel("tpts", b, ["1':1.5 7:0.5 6:2", "6:1.5 5:0.5 4:2", "5:4", "5:2 7,:2"], 0.7, 0, 0.15, 0.35)
    s.mel("strings", b, ["1':1.5 7:0.5 6:2", "6:1.5 5:0.5 4:2", "5:4", "5:2 7,:2"], 0.6, 1, -0.35, 0.4, legato=1.0)
    o_pad(s, "horns", b, Cc, 0.58, 53, 4, -0.1, 0.5)
    o_pad(s, "chorus", b, Cc, 0.5, 58, 3)
    o_bass(s, "lowbr", b, Cc, "1:4", 0.58, 36, 0.3)
    o_timps(s, b, Cc[:3], 0.55, (0, 2))
    o_timp_roll(s, s.bar(b + 3), 4, "C", 0.35, 0.85)
    o_swell(s, s.bar(b + 3), 4, 0.6)
    b += 4
    o_final(s, b, "F", 0.78, [("horns", 4, 0), ("strings", 4, 5), ("chorus", 4, 2), ("tpts", 3, 12)], 53, 2, 41)
    s.note("tpts", s.bar(b), 7.5, s.pitch(7), 0.7, 0.15, 0.35)
    for k, m in enumerate(voicing("F", 53, 12)):
        s.note("harp", s.bar(b) + 0.06 * k, 3, m, 0.5, 0.35, 0.5)
    return s


def menu_5():
    """The Clockwork's anthem in F minor: hammers, pistons and a choir of steel."""
    s = Song("menu_5", "The Iron Anthem", 96, 4, n("F", 4), "aeolian", reverb=(2.6, 0.4), seed=504, q=1.5,
             humanize=0.002, mastering="epic", predelay=0.02)
    A = ["1:1.5 1:0.5 3:1 5:1", "4:1.5 3:0.5 2:2", "3:1 4:1 5:1 6:1", "5:4",
         "1':1.5 7:0.5 6:1 5:1", "6:1 5:1 4:2", "3:1 2:1 7+,:1 2:1", "1:4"]
    Ac = ["Fm", "Eb", "Db", "C", "Db", "Bbm", "C", "Fm"]
    B = ["6:2 1':1 3':1", "3':2 1':2", "1':1.5 7:0.5 6:2", "7:2 6:1 2-':1",
         "6:1 1':1 3':2", "4':2 3':1 1':1", "2-':2 1':1 7:1", "7+:2 5:2"]
    Bc = ["Db", "Ab", "Bbm", "Gb", "Db", "Bbm", "Gb", "C"]
    works1 = {"m...............": 0.0, "k.k.k.k.k.k.k.k.": 0.35, "....c.......c...": -0.3, "p..p..p.p..p..p.": 0.1}
    works2 = {"m.......m.......": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "....a.......a...": -0.3,
              "p..p..p.p..p..p.": 0.1, "T.......T..T....": 0.0}
    works3 = {"m.......m...m...": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "....a.......a..a": -0.3,
              "p..p..p.p..p..p.": 0.1, "T..T....T..T.T..": 0.0, "..............h.": 0.3}
    fill = {"m.......m.m.mmmm": 0.0, "aaaaaaaaaaaaaaaa": -0.3, "...............h": 0.3}

    def engine(b, chords, vel=0.42):
        o_ost(s, "spicc", b, chords, "0001000200010002", 0.25, vel, 41, 3, 0.2, 0.15, acc=">..>..>.>..>..>.")
        o_bass(s, "regal", b, chords, "1:0.5 1:0.5 8:0.5 1:0.5 1:0.5 8:0.5 1:0.5 5,:0.5", vel * 0.9, 36, -0.15, 0.15)

    # the key turns: a ratchet, the music box plays the anthem small, the hammer wakes
    s.drums(0, 1, {"r...........r...": 0.0}, 0.5)
    s.drums(1, 3, {"k...k...k...k...": 0.35}, 0.4)
    s.mel("musicbox", 0, ["1:1.5 1:0.5 3:1 5:1", "4:1.5 3:0.5 2:2", "3:1 4:1 5:1 6:1", "5:4"], 0.5, 1, 0.2, 0.45)
    s.note("volt", 0, 15.5, n("F", 2), 0.25, 0.0, 0.3, "swell")
    s.hit("m", s.bar(2), 0.6)
    s.hit("h", s.bar(2) + 0.5, 0.5, 0.3)
    engine(3, ["Fm"], 0.35)
    o_swell(s, s.bar(3), 4, 0.5)
    b = 4
    # the anthem in the low brass and the horns
    engine(b, Ac)
    s.mel("lowbr", b, A, 0.6, -1, 0.3, 0.3)
    s.mel("horns", b, A, 0.55, 0, -0.15, 0.35)
    o_pad(s, "regal", b, Ac, 0.14, 60, 3, 0.0, 0.5, 0.3)
    s.drums(b, 8, works1, 0.5)
    o_timps(s, b, Ac, 0.45)
    b += 8
    # trumpets and violins, the steel choir underneath
    o_crash(s, s.bar(b), 0.75, "m")
    engine(b, Ac, 0.45)
    s.mel("tpts", b, A, 0.68, 0, 0.15, 0.3, legato=0.92)
    s.mel("strings", b, A, 0.58, 1, -0.35, 0.35, legato=1.0)
    s.mel("lowbr", b, A, 0.55, -1, 0.3, 0.3)
    o_pad(s, "chorus_o", b, Ac, 0.36, 56, 3, 0.0, 0.8, 0.5)
    s.drums(b, 8, works2, 0.52, fill=fill)
    o_timps(s, b, Ac, 0.6, (0, 2.5))
    b += 8
    # the factory floor: D-flat major, the violins over ticking and glass
    s.mel("strings", b, B, 0.58, 0, -0.35, 0.45, legato=1.0, shape="arc", shape_min=2)
    s.mel("glass", b, B, 0.32, 1, 0.3, 0.45)
    o_pad(s, "horns", b, Bc, 0.3, 53, 3, -0.1, 0.45)
    o_pad(s, "chorus", b, Bc, 0.24, 56, 3, 0.0, 0.8, 0.55)
    o_ost(s, "musicbox", b, Bc, "0-2-1-3-", 0.5, 0.3, 65, 4, 0.3, 0.35, 1.2)
    o_bass(s, "lowstr", b, Bc, "1:2 5,:2", 0.42, 36, 0.3)
    s.drums(b, 8, {"p..p..p.p..p..p.": 0.1, "k.k.k.k.k.k.k.k.": 0.35, "m...............": 0.0}, 0.42)
    b += 8
    # the line stops: steam, a hum, sparks... then the gears catch
    s.hit("h", s.bar(b), 0.7, 0.3)
    s.note("volt", s.bar(b), 15.5, n("F", 2), 0.32, 0.0, 0.3)
    s.mel("musicbox", b, ["1':1.5 7:0.5 6:1 5:1", "6:1 5:1 4:2"], 0.45, 1, 0.2, 0.5)
    s.hit("e", s.bar(b + 1) + 3, 0.5, 0.3)
    s.drums(b + 2, 2, {"r.......r.......": 0.0, "k.k.k.k.kkkkkkkk": 0.35}, 0.45)
    engine(b + 2, ["C", "C"], 0.38)
    s.roll("a", s.bar(b + 2), 8, 0.5, 0.15, 0.65, -0.3)
    o_timp_roll(s, s.bar(b + 2), 8, "C", 0.25, 0.9)
    o_swell(s, s.bar(b + 2), 8, 0.75)
    o_pad(s, "lowbr", b + 2, ["C"], 0.5, 36, 2, 0.3, 0.3, 0.3, each=2, shape="swell")
    b += 4
    # the anthem, everyone - twice, the second time with a descant
    for rep in range(2):
        o_crash(s, s.bar(b), 0.9 if rep == 0 else 0.8, "T")
        engine(b, Ac, 0.48)
        s.mel("tpts", b, A, 0.74, 0, 0.15, 0.3, legato=0.92)
        s.mel("horns", b, A, 0.66, 0, -0.15, 0.3)
        s.mel("chorus", b, A, 0.58, 0, 0.0, 0.5, legato=1.0)
        s.mel("strings", b, A, 0.64, 1, -0.35, 0.35, legato=1.0)
        s.mel("lowbr", b, A, 0.62, -1, 0.3, 0.3)
        if rep:
            s.mel("glass", b, A, 0.4, 2, 0.35, 0.4, dshift=2)
            s.mel("flute", b, ["5:4", "5:4", "6:4", "7+:4", "3':4", "1':4", "7+:2 2':2", "1':4"], 0.4, 0, 0.35, 0.45)
        s.drums(b, 8, works3, 0.56, fill=fill)
        o_timps(s, b, Ac, 0.68, (0, 2.5))
        b += 8
    # coda: stamped chords, then F major and the great hammer
    for i, c in enumerate(["Db", "Eb", "C", "C"]):
        o_pad(s, "horns", b + i, [c], 0.7, 53, 4, -0.1, 0.5, beats=2)
        o_pad(s, "tpts", b + i, [c], 0.65, 60, 3, 0.15, 0.4, beats=2)
        o_pad(s, "chorus", b + i, [c], 0.55, 56, 3, beats=3.5)
        o_bass(s, "lowbr", b + i, [c], "1:2 1:1 1:1", 0.65, 36)
        s.hit("m", s.bar(b + i), 0.8)
        s.hit("T", s.bar(b + i) + 2, 0.6)
        o_timp(s, s.bar(b + i), c, 0.7)
    o_timp_roll(s, s.bar(b + 3), 4, "C", 0.4, 0.95)
    s.roll("a", s.bar(b + 3), 4, 0.25, 0.3, 0.7, -0.3)
    b += 4
    o_final(s, b, "F", 0.85, [("horns", 4, 0), ("strings", 4, 7), ("chorus", 4, 3), ("tpts", 3, 12)], 53, 2, 41)
    s.hit("m", s.bar(b), 0.95)
    s.hit("T", s.bar(b), 0.85)
    s.hit("h", s.bar(b) + 0.3, 0.6, 0.3)
    s.hit("G", s.bar(b), 0.5)
    return s


# =========================================================================== THE CROWN, orchestral
def crown_battle_4():
    s = Song("crown_battle_4", "The Forlorn Hope", 138, 4, n("G", 4), "aeolian", reverb=(1.8, 0.4), seed=601, q=1.5,
             mastering="epic", predelay=0.015)
    A = ["1:0.5 1:0.5 5:1 4:0.5 3:0.5 2:1", "3:1.5 4:0.5 5:2", "6:0.5 6:0.5 5:1 4:0.5 3:0.5 2:1", "7+,:1.5 1:0.5 2:2",
         "1:0.5 1:0.5 5:1 6:0.5 7:0.5 1':1", "7:1 6:0.5 5:0.5 6:2", "5:1 4:0.5 3:0.5 2:1 7+,:1", "1:4"]
    Ac = ["Gm", "Gm", "Cm", "D", "Gm", "Eb", "D", "Gm"]
    B = ["3:1 5:1 1':2", "7:1 6:1 5:2", "6:1 1':1 3':2", "2':4", "3':1.5 2':0.5 1':1 7:1", "1':1 6:1 5:2",
         "4:1 5:1 6:1 7+:1", "1':2 5:2"]
    Bc = ["Gm", "F", "Eb", "F", "Cm", "Eb", "D", "Gm"]
    march = {"S.ssS.s.S.ssS.s.": 0.12, "K.......K.......": 0.0}
    march2 = {"SsssS.ssSsssS.sS": 0.12, "b...K...b...K.K.": 0.0}
    fill = {"S.s.s.s.ssssssss": 0.12, "b...b...b.b.bbbb": 0.0}

    def engine(b, chords, vel=0.4, pat="0101"):
        o_ost(s, "spicc", b, chords, pat, 0.25, vel, 50, 3, -0.25, 0.15)
        o_bass(s, "lowstr", b, chords, "1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 5,:0.5 1:0.5", vel + 0.05, 36, 0.3, 0.15)

    # the drums of the forlorn hope
    for i in range(8):
        o_timp(s, i * 0.5, "G", 0.3 + 0.05 * i)
    s.roll("s", s.bar(1), 4, 0.25, 0.15, 0.7, 0.12)
    s.note("trem", 0, 8, n("G", 3), 0.3, -0.3, 0.4, "swell")
    engine(2, ["Gm", "Gm"], 0.36)
    b = s.drums(2, 2, march, 0.45)
    # A: horns over the spiccato
    engine(b, Ac)
    s.drums(b, 8, march, 0.48, fill=fill)
    o_timps(s, b, Ac, 0.5)
    b = s.mel("horns", b, A, 0.62, 0, -0.15, 0.3, legato=0.92)
    # A: trumpets, the fife above, the trombones
    o_crash(s, s.bar(b), 0.7, None)
    engine(b, Ac, 0.42, "0121")
    s.drums(b, 8, march2, 0.52, fill=fill)
    o_timps(s, b, Ac, 0.6, (0, 2))
    o_bass(s, "lowbr", b, Ac, "1:2 5,:1 1:1", 0.5, 36, 0.3)
    s.mel("recorder", b, A, 0.42, 1, 0.35, 0.25, legato=0.85)
    s.mel("strings", b, A, 0.5, 1, -0.35, 0.3, legato=0.98)
    b = s.mel("tpts", b, A, 0.68, 0, 0.15, 0.3, legato=0.9)
    # B: the trumpet call, the strings swell beneath
    o_crash(s, s.bar(b), 0.6, "b")
    engine(b, Bc, 0.4)
    o_pad(s, "strings", b, Bc, 0.38, 55, 4, -0.3, 0.6, 0.4, shape="fpc")
    o_pad(s, "horns", b, Bc, 0.36, 50, 3, -0.1, 0.4)
    o_bass(s, "lowbr", b, Bc, "1:4", 0.45, 36, 0.3)
    s.drums(b, 8, march2, 0.52, fill=fill)
    o_timps(s, b, Bc, 0.6, (0, 2))
    b = s.mel("tpts", b, B, 0.72, 0, 0.15, 0.3, legato=0.92)
    # the breach: drums, stabs, the strings churn
    Dc = ["Gm", "Gm", "Eb", "D"]
    engine(b, Dc, 0.44, "0120")
    for i, c in enumerate(Dc):
        for bt in (0, 1.5, 3):
            o_pad(s, "lowbr", b + i, [c], 0.6, 43, 2, 0.3, 0.3, 0.2, beats=0.6, offset=bt)
            o_pad(s, "horns", b + i, [c], 0.55, 55, 3, -0.15, 0.4, 0.25, beats=0.6, offset=bt)
    s.drums(b, 4, {"b..b..b.S.s.S.s.": 0.0, "S...S...S...S.SS": 0.12}, 0.55)
    o_timps(s, b, Dc, 0.65, (0, 1.5, 3))
    b += 4
    # the climb
    Uc = ["Cm", "Cm", "D", "D"]
    engine(b, Uc, 0.42)
    s.mel("tpts", b, ["4:4", "5:4", "7+:4", "2':4"], 0.6, 0, 0.15, 0.3, shape="swell", shape_min=4)
    o_pad(s, "strings", b, Uc, 0.45, 55, 4, -0.3, 0.6, 0.4, each=2, shape="swell")
    o_bass(s, "lowbr", b, Uc, "1:4", 0.5, 36, 0.3, shape="swell")
    s.roll("s", s.bar(b), 16, 0.25, 0.12, 0.8, 0.12)
    o_timp_roll(s, s.bar(b + 2), 8, "D", 0.3, 0.9)
    o_swell(s, s.bar(b + 2), 8, 0.7)
    b += 4
    # A and B: everyone
    for mel, ch in ((A, Ac), (B, Bc)):
        o_crash(s, s.bar(b), 0.85, "b")
        engine(b, ch, 0.46, "0121")
        s.drums(b, 8, march2, 0.58, fill=fill)
        o_timps(s, b, ch, 0.7, (0, 2))
        o_bass(s, "lowbr", b, ch, "1:2 5,:1 1:1", 0.62, 36, 0.3)
        o_pad(s, "chorus", b, ch, 0.36, 55, 3, 0.0, 0.8, 0.5)
        s.mel("horns", b, mel, 0.62, 0, -0.15, 0.3)
        s.mel("strings", b, mel, 0.6, 1, -0.35, 0.3, legato=0.98)
        s.mel("recorder", b, mel, 0.4, 1, 0.35, 0.25, legato=0.85)
        b = s.mel("tpts", b, mel, 0.74, 0, 0.15, 0.3, legato=0.92)
    o_final(s, b, "Gm", 0.82, [("horns", 4, 0), ("strings", 4, 7), ("tpts", 3, 7)], 50, 1, 38)
    s.hit("S", s.bar(b), 0.8, 0.12)
    return s


def crown_battle_5():
    """A scherzo in 3/4 - the regiments wheel and storm the breach (hemiolas in the middle)."""
    s = Song("crown_battle_5", "Storm the Breach", 168, 3, n("A", 4), "aeolian", reverb=(1.7, 0.4), seed=602,
             q=1.5, mastering="epic", predelay=0.015)
    A = ["1:1 3:1 5:1", "1':2 7:1", "6:1 5:1 4:1", "3:3", "4:1 6:1 1':1", "7+:2 6:1", "5:1 4:1 7+,:1", "1:3"]
    Ac = ["Am", "Am", "Dm", "Am", "Dm", "E", "E", "Am"]
    A2 = ["3:1 5:1 1':1", "3':2 2':1", "1':1 7+:1 6:1", "7+:3", "6:1 1':1 3':1", "2':2 1':1", "7+:1 6:1 7+:1", "1':3"]
    A2c = ["Am", "C", "Am", "E", "F", "Dm", "E", "Am"]
    H = ["5:2 4:2", "r:1 3:2", "4:2 3:2", "r:1 2:2", "3:2 2:2", "r:1 1:2", "2:3", "7+,:3"]   # hemiola
    Hc = ["C", "C", "F", "F", "Dm", "Am", "E", "E"]
    w1 = {"S.s.s.": 0.12, "K.....": 0.0}
    w2 = {"S.ssS.": 0.12, "b.....": 0.0}
    hem = {"b...b.": 0.0, "..S...": 0.12}      # with the hemiola: strong beats every two
    fill = {"S.ssss": 0.12, "b.b.b.": 0.0}

    def engine(b, chords, vel=0.4):
        o_ost(s, "spicc", b, chords, "012120", 0.5, vel, 52, 3, -0.25, 0.15)
        o_bass(s, "lowstr", b, chords, "1:1 5,:1 5,:1", vel + 0.05, 36, 0.3, 0.15)

    def timps(b, chords, vel):
        for i, c in enumerate(chords):
            o_timp(s, s.bar(b + i), c, vel)

    s.note("trem", 0, 12, n("E", 4), 0.3, -0.3, 0.4, "swell")
    s.note("lowstr", 0, 12, n("E", 2), 0.4, 0.3, 0.3, "swell")
    o_timp_roll(s, s.bar(2), 6, "E", 0.2, 0.85)
    o_swell(s, s.bar(2), 6, 0.5)
    b = 4
    for rep in range(2):
        for mel, ch in ((A, Ac), (A2, A2c)):
            engine(b, ch, 0.38 + 0.04 * rep)
            s.drums(b, 8, w1 if rep == 0 else w2, 0.45 + 0.05 * rep, fill=fill)
            timps(b, ch, 0.5 + 0.1 * rep)
            if rep == 0:
                s.mel("horns", b, mel, 0.6, 0, -0.15, 0.3, legato=0.92)
                if mel is A2:
                    s.mel("recorder", b, mel, 0.38, 1, 0.35, 0.25, legato=0.85)
            else:
                o_bass(s, "lowbr", b, ch, "1:2 1:1", 0.55, 36, 0.3)
                s.mel("strings", b, mel, 0.55, 1, -0.35, 0.3, legato=0.98)
                s.mel("horns", b, mel, 0.55, 0, -0.15, 0.3)
                s.mel("tpts", b, mel, 0.68, 0, 0.15, 0.3, legato=0.9)
            if mel is A and rep:
                o_crash(s, s.bar(b), 0.7, None)
            b += 8
    # hemiola: the regiments wheel
    for rep in range(2):
        o_ost(s, "spicc", b, Hc, "010101", 0.5, 0.4, 52, 3, -0.25, 0.15)
        o_bass(s, "lowstr", b, Hc, "1:2 1:1", 0.45, 36, 0.3)
        o_pad(s, "strings", b, Hc, 0.36, 57, 3, -0.3, 0.6, 0.4, shape="arc")
        s.drums(b, 8, hem, 0.5)
        timps(b, Hc, 0.55)
        if rep:
            s.mel("tpts", b, H, 0.66, 0, 0.15, 0.3)
            s.mel("horns", b, H, 0.55, 0, -0.15, 0.3, dshift=-2)
            o_bass(s, "lowbr", b, Hc, "1:3", 0.5, 36, 0.3)
        else:
            s.mel("horns", b, H, 0.6, 0, -0.15, 0.3)
            s.mel("recorder", b, H, 0.35, 1, 0.35, 0.3)
        b += 8
    # the build
    Uc = ["Dm", "Dm", "E", "E"]
    o_ost(s, "spicc", b, Uc, "010101", 0.5, 0.46, 52, 3, -0.25, 0.15)
    s.roll("s", s.bar(b), 12, 0.5, 0.15, 0.8, 0.12)
    o_timp_roll(s, s.bar(b + 2), 6, "E", 0.3, 0.95)
    o_swell(s, s.bar(b + 2), 6, 0.7)
    s.mel("tpts", b, ["4:3", "6:3", "7+:3", "2':3"], 0.6, 0, 0.15, 0.3, shape="swell", shape_min=3)
    o_pad(s, "horns", b, Uc, 0.5, 52, 3, -0.15, 0.5, shape="swell")
    o_bass(s, "lowbr", b, Uc, "1:3", 0.55, 36, 0.3, shape="swell")
    b += 4
    for mel, ch in ((A, Ac), (A2, A2c)):
        o_crash(s, s.bar(b), 0.85, "b")
        engine(b, ch, 0.48)
        s.drums(b, 8, w2, 0.58, fill=fill)
        timps(b, ch, 0.72)
        o_bass(s, "lowbr", b, ch, "1:2 1:1", 0.62, 36, 0.3)
        o_pad(s, "chorus", b, ch, 0.38, 57, 3, 0.0, 0.8, 0.5)
        s.mel("strings", b, mel, 0.62, 1, -0.35, 0.3, legato=0.98)
        s.mel("horns", b, mel, 0.62, 0, -0.15, 0.3)
        s.mel("recorder", b, mel, 0.4, 1, 0.35, 0.25, legato=0.85)
        b = s.mel("tpts", b, mel, 0.74, 0, 0.15, 0.3, legato=0.9)
    # coda: E... A
    for i, c in enumerate(["F", "Dm", "E", "E"]):
        o_pad(s, "horns", b + i, [c], 0.65, 52, 4, -0.15, 0.5, beats=2.5)
        o_pad(s, "tpts", b + i, [c], 0.62, 64, 3, 0.15, 0.4, beats=1.5)
        o_bass(s, "lowbr", b + i, [c], "1:3", 0.6, 36)
        o_timp(s, s.bar(b + i), c, 0.7)
        s.hit("b", s.bar(b + i), 0.6)
    s.roll("s", s.bar(b + 2), 6, 0.25, 0.2, 0.85, 0.12)
    b += 4
    o_final(s, b, "Am", 0.85, [("horns", 4, 0), ("strings", 4, 7), ("tpts", 3, 12), ("chorus", 3, 5)], 52, 2, 33)
    return s


def crown_peace_5():
    """A morning hymn: organ and strings, the choir, a recorder over the harp."""
    s = Song("crown_peace_5", "The Chapel at Dawn", 66, 3, n("G", 4), "ionian", reverb=(3.2, 0.5), seed=611,
             q=1.5, mastering="epic", predelay=0.03, target=0.15)
    H = ["1:2 2:1", "3:2 5:1", "4:1 3:1 2:1", "1:3", "5:2 6:1", "5:2 3:1", "4:1 3:1 2:1", "2:3",
         "3:2 4:1", "5:2 1':1", "7:1 6:1 5:1", "6:3", "5:1 6:1 4:1", "3:2 2:1", "1:1 2:1 7,:1", "1:3"]
    Hc = ["G", "C", "Am", "G", "C", "Em", "Am", "D", "C", "G", "Em", "Am", "C", "G/B", "D", "G"]
    b = 0
    # the harp and a few strings at first light
    o_ost(s, "harp", b, ["G", "C", "G", "D"], "012321", 0.5, 0.4, 55, 4, 0.35, 0.45, 1.5)
    o_pad(s, "strings", b, ["G", "C", "G", "D"], 0.24, 59, 3, -0.2, 0.6, 0.55, shape="arc")
    b = 4
    # the hymn on the recorder over the organ
    o_pad(s, "organ", b, Hc, 0.16, 55, 3, 0.0, 0.5, 0.5)
    o_bass(s, "pizz", b, Hc, "1:1 5,:1 1:1", 0.4, 38, 0.3)
    o_ost(s, "harp", b, Hc, "012321", 0.5, 0.3, 55, 4, 0.35, 0.45, 1.5)
    b = s.mel("recorder", b, H, 0.55, 1, 0.2, 0.45, legato=0.95)
    # the strings sing it, the horns in harmony
    s.mel("strings", b, H, 0.52, 0, -0.35, 0.5, legato=1.0, shape="arc", shape_min=2)
    s.mel("horns", b, H, 0.32, -1, -0.1, 0.5, dshift=-2)
    o_bass(s, "lowstr", b, Hc, "1:3", 0.36, 36, 0.3)
    o_pad(s, "organ", b, Hc, 0.12, 55, 3, 0.0, 0.5, 0.5)
    b += 16
    # the choir, everyone, soft timpani
    s.mel("chorus_o", b, H, 0.5, 0, 0.0, 0.6, legato=1.0)
    s.mel("strings", b, H, 0.45, 1, -0.35, 0.5, legato=1.0)
    s.mel("recorder", b + 8, H[8:], 0.38, 1, 0.35, 0.5, dshift=2)
    o_pad(s, "horns", b, Hc, 0.26, 52, 3, -0.1, 0.4, 0.5)
    o_pad(s, "organ", b, Hc, 0.12, 55, 3, 0.0, 0.5, 0.5)
    o_bass(s, "lowstr", b, Hc, "1:3", 0.4, 36, 0.3)
    o_ost(s, "harp", b, Hc, "012321", 0.5, 0.28, 55, 4, 0.35, 0.45, 1.5)
    for i in range(0, 16, 4):
        o_timp(s, s.bar(b + i), Hc[i], 0.25)
    b += 16
    # amen
    o_pad(s, "chorus_o", b, ["C", "G"], 0.42, 55, 4, 0.0, 0.8, 0.6, each=2, shape="arc")
    o_pad(s, "strings", b, ["C", "G"], 0.36, 55, 4, -0.2, 0.6, 0.6, each=2, shape="arc")
    o_pad(s, "organ", b, ["C", "G"], 0.14, 55, 3, 0.0, 0.5, 0.5, each=2)
    o_bass(s, "lowstr", b, ["C", "G"], "1:6", 0.38, 36, 0.3, each=2)
    s.note("recorder", s.bar(b + 2), 5.5, s.pitch(4) + 12, 0.38, 0.3, 0.6)
    s.note("bell", s.bar(b + 2), 3, s.pitch(0) - 12, 0.25, -0.2, 0.6)
    return s


# =========================================================================== THE BROOD, orchestral
def brood_battle_4():
    """A war-rite in C# phrygian: taiko, the throat choir chanting, a shawm, the trombones growling."""
    s = Song("brood_battle_4", "Blood Moon Rite", 128, 4, n("C", 4) + 1, "phrygian", reverb=(2.2, 0.6), seed=621,
             q=1.5, mastering="epic", predelay=0.02)
    A = ["1:1.5 1:0.5 2:1 1:1", "3:1 2:1 1:2", "1:1.5 1:0.5 2:1 4:1", "3:2 2:2",
         "5:1.5 5:0.5 6:1 5:1", "4:1 3:1 2:2", "3:1 2:1 1:1 7,:1", "1:4"]
    Ac = ["C#m", "D", "C#m", "A", "C#m", "F#m", "D", "C#m"]
    B = ["1':3 7:1", "6:2 5:2", "6:3 5:1", "4:2 2:2", "5:3 6:1", "5:2 4:2", "3:2 2:1 3:1", "1:4"]
    Bc = ["A", "D", "Bm", "D", "C#m", "A", "D", "C#m"]
    rite1 = {"T.......T..T....": 0.0, "..t...t...t...t.": 0.4, "....D.......D...": -0.3}
    rite2 = {"T..T..T.T..T..T.": 0.0, "..t.t.t...t.ttt.": 0.4, "D...D..dD...D.dd": -0.3, "x.xxx.xxx.xxx.xx": -0.5}
    rite3 = {"T..T..T.T..TT.T.": 0.0, "b.......b.......": 0.0, "..t.t.t.t.t.tttt": 0.4, "D..dD..dD..dD.dd": -0.3,
             "xxxxxxxxxxxxxxxx": -0.5, "....q.......q...": 0.3}
    fill = {"T.T.T.T.TTTTTTTT": 0.0, "tttttttttttttttt": 0.4, "b.......b.b.b.b.": 0.0}

    def ground(b, chords, vel=0.42):
        o_ost(s, "spicc", b, chords, "0010001000100120", 0.25, vel, 37, 3, 0.25, 0.15, acc=">..>..>.>..>..>.")
        o_bass(s, "log", b, chords, "1:0.75 1:0.75 1:0.5 5,:1 1:1", vel, 49, 0.35, 0.2)
        o_bass(s, "throat", b, chords, "1:4", 0.36, 37, 0.0, 0.3)

    # moonrise: croaks, insects, the heart of the swamp
    s.scatter(0, 4, 1, 3, lambda bt, r: s.hit("z", bt, r.uniform(0.3, 0.5), r.choice([-0.8, 0.8]), 0.5), 0.5)
    for i in range(4):
        s.hit("T", s.bar(i), 0.45 + 0.08 * i)
        s.hit("T", s.bar(i) + 0.75, 0.3 + 0.06 * i)
        s.hit("q", s.bar(i) + 2.5, 0.45, 0.4, 0.3)
    s.note("throat", 0, 16, s.pitch(0) - 24, 0.4, 0.0, 0.4, "swell")
    s.note("lowstr", 0, 16, s.pitch(0) - 24, 0.4, 0.3, 0.3, "swell")
    o_swell(s, s.bar(2), 8, 0.5)
    b = 4
    # the chant
    ground(b, Ac)
    s.drums(b, 8, rite1, 0.55, fill=fill)
    s.mel("chorus_u", b, A, 0.62, -1, -0.1, 0.45, legato=0.95)
    b = s.mel("throat", b, A, 0.4, -1, 0.15, 0.35)
    # the shawm screams it, horns underneath
    o_crash(s, s.bar(b), 0.6, None)
    ground(b, Ac, 0.46)
    s.drums(b, 8, rite2, 0.58, fill=fill)
    o_pad(s, "chorus_u", b, Ac, 0.3, 49, 3, 0.0, 0.7, 0.5)
    s.mel("horns", b, A, 0.55, -1, -0.15, 0.3)
    b = s.mel("shawm", b, A, 0.62, 1, 0.15, 0.3, legato=0.9)
    # the rite: trombones, the choir in long chords, the bone flute wailing
    ground(b, Bc, 0.44)
    s.drums(b, 8, rite2, 0.55, fill=fill)
    o_pad(s, "chorus", b, Bc, 0.42, 52, 3, 0.0, 0.8, 0.55, shape="arc")
    o_bass(s, "lowbr", b, Bc, "1:3 1:0.5 1:0.5", 0.55, 37, 0.3, 0.25)
    o_timps(s, b, Bc, 0.55, (0, 2.5))
    s.mel("boneflute", b, B, 0.55, 1, -0.3, 0.45)
    b = s.mel("lowstr", b, B, 0.52, -1, 0.3, 0.35, legato=1.0)
    # the drums alone, then the swamp rises
    s.drums(b, 2, {"T..T..T.T..T..T.": 0.0, "..t.t.t...t.ttt.": 0.4, "q.......q.......": 0.3}, 0.6)
    s.drums(b + 2, 2, {"T.T.T.T.TTTTTTTT": 0.0, "..t.t.t.tttttttt": 0.4}, 0.62)
    s.note("throat", s.bar(b), 16, s.pitch(0) - 24, 0.45)
    o_timp_roll(s, s.bar(b + 2), 8, "C#m", 0.3, 0.95)
    o_swell(s, s.bar(b + 2), 8, 0.7)
    o_pad(s, "lowbr", b + 2, ["C#5"], 0.5, 37, 2, 0.3, 0.3, 0.3, each=2, shape="swell")
    b += 4
    # all of it - then a half-step higher, in D
    for k in (0, 1):
        ch = transpose(Ac, k)
        o_crash(s, s.bar(b), 0.85, "b")
        ground(b, ch, 0.5)
        s.drums(b, 8, rite3, 0.6, fill=fill)
        o_pad(s, "chorus", b, ch, 0.42, 52, 3, 0.0, 0.8, 0.5)
        o_bass(s, "lowbr", b, ch, "1:1.5 1:0.5 1:1 5,:1", 0.62, 37, 0.3, 0.25)
        o_timps(s, b, ch, 0.65, (0, 1.5, 2.5))
        s.mel("chorus_u", b, A, 0.6, -1, -0.1, 0.45)
        s.mel("horns", b, A, 0.6, -1, -0.15, 0.3)
        s.mel("strings", b, A, 0.58, 1, -0.35, 0.3, legato=0.98)
        b = s.mel("shawm", b, A, 0.62, 1, 0.15, 0.3, legato=0.9)
        s.tonic += 1
    s.tonic -= 1
    o_final(s, b, "D5", 0.85, [("chorus_u", 3, 0), ("horns", 3, 0), ("strings", 3, 12)], 50, 1, 38)
    s.hit("T", s.bar(b), 0.9)
    s.hit("q", s.bar(b) + 1, 0.6, 0.3)
    s.hit("G", s.bar(b), 0.45)
    return s


def brood_battle_5():
    """The swarm in 6/8 (counted in eighths), B phrygian dominant: strings and choir boil over."""
    s = Song("brood_battle_5", "The Hive Unleashed", 300, 6, n("B", 3), "phrygian_dom", reverb=(2.0, 0.6), seed=622,
             q=1.5, mastering="epic", predelay=0.015)
    A = ["1:2 2:1 3:2 2:1", "1:3 7,:3", "1:2 2:1 3:2 4:1", "5:6", "6:2 5:1 4:2 3:1", "4:3 2:3",
         "3:2 2:1 1:2 7,:1", "1:6"]
    Ac = ["B", "Am", "B", "B", "Em", "Am", "C", "B"]
    B = ["5:3 6:3", "5:2 4:1 3:3", "4:3 5:3", "4:2 3:1 2:3", "3:3 4:3", "5:2 6:1 5:3", "4:2 3:1 2:2 1:1", "2:6"]
    Bc = ["Em", "B", "Am", "Em", "C", "B", "Am", "C"]
    d1 = {"B.....B..B..": 0.0, "..t..t..t.tt": 0.4, "x.xx.xx.xx.x": -0.4}
    d2 = {"T..T..T..TT.": 0.0, "..t.tt..t.tt": 0.4, "D.dD.dD.dDdd": -0.3, "xxxxxxxxxxxx": -0.4}
    d3 = {"T.TT.TT.TTTT": 0.0, "b.....b.....": 0.0, "..t.tt.ttttt": 0.4, "D.dD.dD.dDdd": -0.3, "xxxxxxxxxxxx": -0.4}
    fill = {"T.T.T.TTTTTT": 0.0, "tttttttttttt": 0.4}

    def boil(b, chords, vel=0.42):
        o_ost(s, "spicc", b, chords, "001002", 1, vel, 47, 3, 0.25, 0.15, legato=0.8)
        o_bass(s, "lowstr", b, chords, "1:2 1:1 1:2 5,:1", vel + 0.05, 35, 0.3, 0.15)

    # the hive hums: insects, bubbles, a swelling drone
    s.scatter(0, 4, 2, 4, lambda bt, r: s.hit("z", bt, r.uniform(0.3, 0.55), r.uniform(-0.8, 0.8), 0.5), 1.0)
    _bubbles(s, 0, 4, 2, 3, 0.3)
    s.note("chorus_u", 0, 24, s.pitch(0) - 12, 0.4, 0.0, 0.5, "swell")
    s.note("trem", 0, 24, s.pitch(0), 0.28, -0.3, 0.5, "swell")
    s.drums(2, 2, {"B.....B.....": 0.0}, 0.55)
    o_swell(s, s.bar(2), 12, 0.55)
    b = 4
    # the shawm leads the swarm
    boil(b, Ac)
    s.drums(b, 8, d1, 0.55, fill=fill)
    b = s.mel("shawm", b, A, 0.6, 0, 0.15, 0.3, legato=0.9)
    # the choir and horns take it, the strings boil
    o_crash(s, s.bar(b), 0.65, None)
    boil(b, Ac, 0.46)
    s.drums(b, 8, d2, 0.58, fill=fill)
    o_bass(s, "lowbr", b, Ac, "1:3 5,:3", 0.5, 35, 0.3)
    s.mel("chorus", b, A, 0.55, 0, 0.0, 0.5)
    s.mel("strings", b, A, 0.55, 1, -0.35, 0.3, legato=0.98)
    b = s.mel("horns", b, A, 0.6, 0, -0.15, 0.3)
    # B: wings - the horns in long notes, the bone flute above
    for rep in range(2):
        boil(b, Bc, 0.44)
        s.drums(b, 8, d2 if rep else d1, 0.55, fill=fill)
        o_pad(s, "chorus_u", b, Bc, 0.36, 47, 3, 0.0, 0.7, 0.5)
        o_timps(s, b, Bc, 0.55, (0, 3))
        if rep:
            s.mel("strings", b, B, 0.6, 1, -0.35, 0.35, legato=1.0)
            s.mel("boneflute", b, B, 0.45, 1, 0.3, 0.4, dshift=2)
            o_bass(s, "lowbr", b, Bc, "1:6", 0.5, 35, 0.3)
        b = s.mel("horns", b, B, 0.6, 0, -0.15, 0.35)
    # the queen calls: drums only, then everything rises
    s.drums(b, 2, {"T.....T..T..": 0.0, "q.....q.....": 0.3}, 0.6)
    s.drums(b + 2, 2, {"T..T..TTTTTT": 0.0, "..t..ttttttt": 0.4}, 0.62)
    o_timp_roll(s, s.bar(b + 2), 12, "B", 0.3, 0.95)
    o_swell(s, s.bar(b + 2), 12, 0.7)
    o_pad(s, "lowbr", b, ["B5"], 0.5, 35, 2, 0.3, 0.3, 0.3, each=4, shape="swell")
    o_pad(s, "chorus", b, ["B"], 0.45, 54, 3, 0.0, 0.8, 0.5, each=4, shape="swell")
    b += 4
    # everything
    for mel, ch in ((A, Ac), (B, Bc), (A, Ac)):
        o_crash(s, s.bar(b), 0.85, "b")
        boil(b, ch, 0.5)
        s.drums(b, 8, d3, 0.6, fill=fill)
        o_bass(s, "lowbr", b, ch, "1:3 5,:3", 0.6, 35, 0.3)
        o_timps(s, b, ch, 0.65, (0, 3))
        s.mel("chorus", b, mel, 0.58, 0, 0.0, 0.5)
        s.mel("horns", b, mel, 0.62, 0, -0.15, 0.3)
        s.mel("strings", b, mel, 0.6, 1, -0.35, 0.3, legato=0.98)
        b = s.mel("shawm", b, mel, 0.55, 1, 0.15, 0.3, legato=0.9)
    o_final(s, b, "B", 0.85, [("chorus", 4, 0), ("horns", 3, 0), ("strings", 4, 12)], 47, 3, 35)
    s.hit("T", s.bar(b), 0.9)
    s.hit("q", s.bar(b) + 2, 0.55, 0.3)
    return s


def brood_peace_5():
    """Mist on the water: low choir, a bone flute, the tremolo strings and slow bubbles."""
    s = Song("brood_peace_5", "Mist on the Brood-Mere", 60, 4, n("B", 3), "aeolian", reverb=(4.0, 0.7), seed=631,
             q=1.5, mastering="epic", predelay=0.035, target=0.14)
    A = ["5:2 4:1 3:1", "4:3 2:1", "3:2 1:1 7,:1", "1:4", "1:2 3:1 5:1", "6:3 5:1", "4:1 3:1 2:1 7,:1", "1:4"]
    Ac = ["Bm", "Em", "G", "Bm", "Bm", "G", "Em", "Bm"]
    B = ["3':2 2':1 1':1", "7:4", "6:2 5:1 4:1", "5:4", "1':2 7:1 6:1", "5:3 4:1", "3:1 4:1 2:2", "1:4"]
    Bc = ["Em", "G", "Em", "Bm", "G", "Em", "F#", "Bm"]
    total = 34
    _bubbles(s, 0, total, 1, 2, 0.25)
    s.scatter(0, total, 0, 1, lambda bt, r: s.hit("q", bt, r.uniform(0.2, 0.35), r.uniform(-0.6, 0.6), 0.45), 1.0)
    s.scatter(0, total, 0, 2, lambda bt, r: s.hit("z", bt, r.uniform(0.2, 0.4), r.choice([-0.8, 0.8]), 0.5), 0.5)
    s.hit("G", 0, 0.4)
    o_pad(s, "trem", 0, ["Bm"], 0.18, 59, 3, -0.3, 0.6, 0.6, each=2, shape="swell")
    s.note("chorus_u", 0, 7.8, s.pitch(0) - 12, 0.4, 0.0, 0.6, "arc")
    b = 2
    # a bone flute over the mist
    o_pad(s, "chorus_u", b, Ac, 0.3, 47, 3, 0.0, 0.7, 0.6)
    o_bass(s, "lowstr", b, Ac, "1:4", 0.32, 35, 0.3, 0.35)
    o_bass(s, "log", b, Ac, "1:1.5 1:0.5 r:1 5,:1", 0.3, 47, 0.35, 0.35)
    b = s.mel("boneflute", b, A, 0.55, 1, -0.25, 0.55)
    # the low choir sings it, the flute a third above
    o_pad(s, "trem", b, Ac, 0.17, 59, 3, -0.3, 0.6, 0.6)
    o_bass(s, "lowstr", b, Ac, "1:4", 0.34, 35, 0.3, 0.35)
    s.mel("boneflute", b, A, 0.38, 1, -0.3, 0.55, dshift=2)
    s.drums(b, 8, {"D.......d.......": 0.0}, 0.25)
    b = s.mel("chorus_u", b, A, 0.55, 0, 0.15, 0.6, legato=1.0)
    # the mist parts: the strings sing, a gong far away
    s.hit("G", s.bar(b), 0.3)
    s.mel("strings", b, B, 0.5, 0, -0.3, 0.55, legato=1.0, shape="arc", shape_min=2)
    o_pad(s, "chorus_o", b, Bc, 0.24, 52, 3, 0.0, 0.7, 0.6)
    o_bass(s, "lowstr", b, Bc, "1:2 5,:2", 0.36, 35, 0.3, 0.35)
    s.drums(b, 8, {"D.......d...d...": 0.0, "..x...x...x...x.": -0.4}, 0.25)
    b += 8
    # the tune once more, sinking
    o_pad(s, "chorus_u", b, Ac, 0.28, 47, 3, 0.0, 0.7, 0.6)
    o_pad(s, "trem", b, Ac, 0.15, 59, 3, -0.3, 0.6, 0.6)
    o_bass(s, "lowstr", b, Ac, "1:4", 0.32, 35, 0.3, 0.35)
    s.mel("boneflute", b, A, 0.5, 1, -0.25, 0.55)
    b += 8
    s.note("chorus_u", s.bar(b), 7.5, s.pitch(0) - 12, 0.4, 0.0, 0.6, "dim")
    s.note("boneflute", s.bar(b), 4, s.pitch(4), 0.35, -0.25, 0.6)
    s.hit("G", s.bar(b), 0.3)
    return s


# =========================================================================== THE CLOCKWORK, orchestral
def clock_battle_4():
    s = Song("clock_battle_4", "The Iron Tide", 152, 4, n("D", 4), "aeolian", reverb=(1.5, 0.3), humanize=0.0,
             seed=641, q=1.5, mastering="epic", predelay=0.01)
    A = ["1:1 5:1 4:0.5 3:0.5 2:1", "3:1 1:1 5,:2", "6,:1 3:1 2:0.5 1:0.5 7,:1", "1:2 5,:2",
         "1:1 5:1 6:0.5 5:0.5 4:1", "3:1 4:1 5:2", "6:1 5:0.5 4:0.5 3:1 2:1", "1:4"]
    Ac = ["Dm", "Dm", "Gm", "Asus", "Dm", "F", "Gm", "Dm"]
    B = ["5:2 6:1 5:1", "4:2 3:2", "4:2 5:1 4:1", "3:2 2:2", "6:2 7:1 6:1", "5:2 4:2", "3:1 4:1 5:1 6:1", "5:2 7+,:2"]
    Bc = ["Dm", "Bb", "Gm", "A", "Bb", "F", "Gm", "A"]
    m1 = {"p...a...p...a...": 0.0, "k.k.k.k.k.k.k.k.": 0.35}
    m2 = {"p..pa...p.p.a...": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "c.....c.....c...": -0.3, "T.......T.......": 0.0}
    m3 = {"m..pa..pm.p.a..p": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "c.....c.....c...": -0.3, "T..T....T..T....": 0.0,
          "..............h.": 0.3}
    fill = {"p.a.p.a.aaaaaaaa": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "T...T...T.T.TTTT": 0.0, "...............h": 0.3}

    def machine(b, chords, vel=0.42):
        o_ost(s, "spicc", b, chords, "0102010201020102", 0.25, vel, 50, 3, -0.25, 0.15, acc=">...>...>...>...")
        o_bass(s, "regal", b, chords, "1:0.5 1:0.5 8:0.5 1:0.5 1:0.5 8:0.5 7:0.5 5:0.5", vel, 38, 0.1, 0.12)
        o_bass(s, "volt", b, chords, "1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5 1:0.5", 0.32, 26, 0.0, 0.08, 0.8)

    s.drums(0, 1, {"r...........r...": 0.0, "k...k...k...k...": 0.35}, 0.45)
    s.drums(1, 1, {"k.k.k.k.k.k.k.k.": 0.35, "p.......p.......": 0.0}, 0.5)
    s.note("volt", 0, 8, n("D", 2), 0.35, 0.0, 0.3, "swell")
    s.note("lowbr", 0, 8, n("D", 2), 0.45, 0.3, 0.3, "swell")
    machine(2, ["Dm", "Dm"], 0.36)
    s.drums(2, 2, {"kkkkkkkkkkkkkkkk": 0.35, "p...p...p...p...": 0.0}, 0.52)
    o_swell(s, s.bar(2), 8, 0.55)
    b = 4
    machine(b, Ac)
    s.drums(b, 8, m1, 0.55, fill=fill)
    b = s.mel("horns", b, A, 0.64, 0, -0.15, 0.3, legato=0.92)
    o_crash(s, s.bar(b), 0.7, "m")
    machine(b, Ac, 0.45)
    s.drums(b, 8, m2, 0.58, fill=fill)
    o_bass(s, "lowbr", b, Ac, "1:2 5,:1 1:1", 0.55, 38, 0.3)
    o_timps(s, b, Ac, 0.6, (0, 2))
    s.mel("strings", b, A, 0.52, 1, -0.35, 0.3, legato=0.98)
    b = s.mel("tpts", b, A, 0.7, 0, 0.15, 0.3, legato=0.9)
    # B: the brass in long lines over the gears, glass sparks above
    machine(b, Bc, 0.44)
    s.drums(b, 8, m2, 0.58, fill=fill)
    o_pad(s, "chorus_o", b, Bc, 0.36, 55, 3, 0.0, 0.8, 0.5, shape="fpc")
    o_ost(s, "glass", b, Bc, "0-2-1-3-", 0.5, 0.3, 74, 4, 0.35, 0.3, 1.0)
    o_bass(s, "lowbr", b, Bc, "1:4", 0.55, 38, 0.3)
    o_timps(s, b, Bc, 0.6, (0, 2))
    b = s.mel("horns", b, B, 0.66, 0, -0.15, 0.3)
    # pressure: pistons, sparks, the strings climb
    Uc = ["Gm", "Gm", "A", "A"]
    s.drums(b, 2, {"p.......p..p....": 0.0, "......e.........": 0.3}, 0.55)
    s.drums(b + 2, 2, {"p...p...p.p.pppp": 0.0, "kkkkkkkkkkkkkkkk": 0.35}, 0.58)
    machine(b, Uc, 0.42)
    s.mel("strings", b, ["4:4", "5:4", "7+:4", "2':4"], 0.6, 0, -0.35, 0.3, shape="swell", shape_min=4)
    o_pad(s, "lowbr", b, Uc, 0.5, 38, 2, 0.3, 0.3, 0.25, each=2, shape="swell")
    o_timp_roll(s, s.bar(b + 2), 8, "A", 0.3, 0.95)
    o_swell(s, s.bar(b + 2), 8, 0.7)
    b += 4
    # full tide: twice, the second time a whole tone up
    for k in (0, 2):
        ch = transpose(Ac, k)
        s.tonic += k
        o_crash(s, s.bar(b), 0.85, "m")
        machine(b, ch, 0.48)
        s.drums(b, 8, m3, 0.6, fill=fill)
        o_bass(s, "lowbr", b, ch, "1:2 5,:1 1:1", 0.62, 38, 0.3)
        o_timps(s, b, ch, 0.7, (0, 2))
        o_pad(s, "chorus", b, ch, 0.4, 55, 3, 0.0, 0.8, 0.5)
        s.mel("horns", b, A, 0.62, 0, -0.15, 0.3)
        s.mel("strings", b, A, 0.6, 1, -0.35, 0.3, legato=0.98)
        s.mel("glass", b, A, 0.35, 2, 0.35, 0.3)
        b = s.mel("tpts", b, A, 0.74, 0, 0.15, 0.3, legato=0.9)
    o_final(s, b, "E5", 0.85, [("horns", 3, 0), ("strings", 3, 12), ("tpts", 2, 12)], 52, 1, 40)
    s.hit("m", s.bar(b), 0.9)
    s.hit("h", s.bar(b) + 0.4, 0.6, 0.3)
    return s


def clock_battle_5():
    """F# minor, 4/4 split 3+3+2: everything in the machine accents the same off-kilter pulse."""
    s = Song("clock_battle_5", "Calibrated Fury", 144, 4, n("F", 4) + 1, "aeolian", reverb=(1.5, 0.3), humanize=0.0,
             seed=642, q=1.5, mastering="epic", predelay=0.01)
    A = ["1:1.5 3:1.5 5:1", "4:1.5 3:1.5 2:1", "3:1.5 5:1.5 1':1", "7:1.5 6:1.5 5:1",
         "6:1.5 5:1.5 4:1", "5:1.5 4:1.5 3:1", "4:1 3:0.5 2:1.5 7+,:1", "1:4"]
    Ac = ["F#m", "D", "F#m", "E", "D", "C#m", "Bm", "F#m"]
    B = ["3':3 2':1", "1':3 7:1", "6:3 5:1", "4:4", "5:3 6:1", "7:3 1':1", "2':2 1':1 7:1", "7+:4"]
    Bc = ["D", "A", "Bm", "D", "E", "C#m", "Bm", "C#"]
    g1 = {"a..k..a.a..k..a.": 0.0, "k.k.k.k.k.k.k.k.": 0.35}
    g2 = {"a..c..a.a..c..a.": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "T..T..T.T..T..T.": 0.0, "x.xx.xx.x.xx.xx.": -0.4}
    g3 = {"m..c..a.m..c..a.": 0.0, "kkkkkkkkkkkkkkkk": 0.35, "T..T..T.T..T..TT": 0.0, "xxxxxxxxxxxxxxxx": -0.4,
          "..............h.": 0.3}
    fill = {"a.a.a.a.aaaaaaaa": 0.0, "T..T..T.TTTTTTTT": 0.0, "...............h": 0.3}

    def gears(b, chords, vel=0.42):
        o_ost(s, "spicc", b, chords, "0120120101201201", 0.25, vel, 54, 3, -0.25, 0.15, acc=">..>..>.>..>..>.")
        o_bass(s, "regal", b, chords, "1:0.75 1:0.75 5,:0.5 1:0.75 1:0.75 8:0.5", vel, 42, 0.1, 0.12)
        o_bass(s, "lowstr", b, chords, "1:0.75 1:0.75 1:0.5 1:0.75 1:0.75 1:0.5", vel, 30, 0.3, 0.12, 0.8)

    s.drums(0, 1, {"r.......r.......": 0.0}, 0.5)
    s.drums(1, 1, {"k..k..k.k..k..k.": 0.35}, 0.45)
    gears(2, ["F#m", "F#m"], 0.36)
    s.drums(2, 2, {"kkkkkkkkkkkkkkkk": 0.35, "a..a..a.a..a..a.": 0.0}, 0.48)
    o_ost(s, "musicbox", 0, ["F#m", "F#m"], "0120120101201201", 0.25, 0.32, 66, 3, 0.3, 0.3)
    b = 4
    gears(b, Ac)
    s.drums(b, 8, g1, 0.55, fill=fill)
    o_ost(s, "musicbox", b, Ac, "0-2-1-3-", 0.5, 0.26, 66, 4, 0.35, 0.3)
    b = s.mel("horns", b, A, 0.64, 0, -0.15, 0.3, legato=0.92)
    o_crash(s, s.bar(b), 0.7, "m")
    gears(b, Ac, 0.45)
    s.drums(b, 8, g2, 0.58, fill=fill)
    o_bass(s, "lowbr", b, Ac, "1:1.5 1:1.5 5,:1", 0.55, 30, 0.3)
    o_timps(s, b, Ac, 0.6, (0, 1.5, 3))
    s.mel("strings", b, A, 0.52, 1, -0.35, 0.3, legato=0.98)
    b = s.mel("tpts", b, A, 0.7, 0, 0.15, 0.3, legato=0.9)
    # B: the choir of steel, glass in the gears
    gears(b, Bc, 0.44)
    s.drums(b, 8, g2, 0.56, fill=fill)
    o_pad(s, "chorus_o", b, Bc, 0.38, 57, 3, 0.0, 0.8, 0.5)
    o_ost(s, "glass", b, Bc, "0120120101201201", 0.25, 0.22, 78, 3, 0.35, 0.3, 1.0)
    o_bass(s, "lowbr", b, Bc, "1:4", 0.55, 30, 0.3)
    o_timps(s, b, Bc, 0.6, (0, 1.5, 3))
    s.mel("strings", b, B, 0.56, 0, -0.35, 0.35, legato=1.0)
    b = s.mel("horns", b, B, 0.6, -1, -0.15, 0.3)
    # the stall
    s.hit("h", s.bar(b), 0.7, 0.3)
    s.hit("e", s.bar(b) + 1.5, 0.6, 0.3)
    s.hit("e", s.bar(b) + 2.25, 0.5, -0.3)
    s.note("volt", s.bar(b), 8, n("F", 2) + 1, 0.35)
    s.drums(b + 2, 2, {"r.......r.......": 0.0, "a..a..a.aaaaaaaa": 0.0, "kkkkkkkkkkkkkkkk": 0.35}, 0.55)
    gears(b + 2, ["C#", "C#"], 0.4)
    o_timp_roll(s, s.bar(b + 2), 8, "C#", 0.3, 0.95)
    o_swell(s, s.bar(b + 2), 8, 0.7)
    o_pad(s, "lowbr", b + 2, ["C#"], 0.5, 37, 2, 0.3, 0.3, 0.25, each=2, shape="swell")
    o_pad(s, "tpts", b + 2, ["C#"], 0.5, 61, 3, 0.15, 0.4, 0.3, each=2, shape="swell")
    b += 4
    for mel, ch in ((A, Ac), (B, Bc), (A, Ac)):
        o_crash(s, s.bar(b), 0.85, "m")
        gears(b, ch, 0.48)
        s.drums(b, 8, g3, 0.6, fill=fill)
        o_bass(s, "lowbr", b, ch, "1:1.5 1:1.5 5,:1", 0.62, 30, 0.3)
        o_timps(s, b, ch, 0.7, (0, 1.5, 3))
        o_pad(s, "chorus", b, ch, 0.4, 57, 3, 0.0, 0.8, 0.5)
        s.mel("strings", b, mel, 0.6, 1, -0.35, 0.3, legato=0.98)
        s.mel("horns", b, mel, 0.6, 0, -0.15, 0.3)
        b = s.mel("tpts", b, mel, 0.72, 0, 0.15, 0.3, legato=0.9)
    o_final(s, b, "F#m", 0.85, [("horns", 4, 0), ("strings", 4, 12), ("tpts", 3, 7), ("chorus", 3, 5)], 54, 1, 42)
    s.hit("m", s.bar(b), 0.9)
    s.hit("h", s.bar(b) + 0.4, 0.6, 0.3)
    return s


def clock_peace_5():
    """A waltz under the lanterns of the workshop: celesta and music box, pizzicato, a clarinet."""
    s = Song("clock_peace_5", "The Lantern Waltz", 112, 3, n("B", 3) - 1, "lydian", reverb=(2.4, 0.35),
             humanize=0.0, seed=651, q=1.5, mastering="epic", predelay=0.02, target=0.15)
    A = ["5:2 3:1", "4:3", "5:2 6:1", "5:3", "3:2 1:1", "2:2 3:1", "4:3", "3:3",
         "5:2 3:1", "4:3", "5:2 1':1", "2':3", "1':1 7:1 6:1", "5:2 4:1", "2:2 3:1", "1:3"]
    Ac = ["Bb", "C", "Bb", "Bb", "Gm", "C", "C", "F", "Bb", "C", "Bb", "Gm", "F", "Bb", "C", "Bb"]
    B = ["3':2 2':1", "1':3", "7:2 6:1", "5:3", "6:2 5:1", "4:3", "3:2 4:1", "5:3",
         "3':2 2':1", "1':3", "7:2 1':1", "2':3", "3':1 2':1 1':1", "7:2 6:1", "7:3", "1':3"]
    Bc = ["Gm", "Eb", "C", "F", "Dm", "Bb", "Gm", "C", "Gm", "Eb", "C", "Bb", "Gm", "C", "F", "Bb"]
    tick = {"k.....": 0.35, "....k.": 0.35}

    def waltz(b, chords, vel=0.36):
        o_bass(s, "pizz", b, chords, "1:1 r:2", vel + 0.08, 34, 0.25, 0.25)
        o_ost(s, "pizz", b, chords, "-12", 1, vel, 53, 3, -0.15, 0.3, legato=0.8)

    s.drums(0, 2, {"r.....": 0.0}, 0.4)
    o_ost(s, "musicbox", 0, ["Bb", "C"], "012321", 0.5, 0.35, 70, 4, 0.25, 0.35)
    b = 2
    # the waltz on the music box and celesta
    waltz(b, Ac)
    s.drums(b, 16, tick, 0.3)
    s.mel("musicbox", b, A, 0.42, 1, 0.3, 0.35)
    b = s.mel("celesta", b, A, 0.55, 1, -0.2, 0.35)
    # the clarinet takes it, the strings under it
    waltz(b, Ac)
    s.drums(b, 16, tick, 0.3)
    o_pad(s, "strings", b, Ac, 0.22, 58, 3, -0.2, 0.6, 0.5)
    s.mel("celesta", b, A, 0.32, 2, 0.3, 0.35)
    b = s.mel("clar", b, A, 0.55, 0, -0.2, 0.4)
    # B: G minor, the violins, glass sparks
    waltz(b, Bc, 0.34)
    s.drums(b, 16, {"k.....": 0.35, "....k.": 0.35, "c.....": -0.3}, 0.3)
    s.mel("strings", b, B, 0.5, 0, -0.35, 0.45, legato=1.0, shape="arc", shape_min=2)
    s.mel("clar", b, B, 0.35, -1, 0.25, 0.4, dshift=-2)
    o_ost(s, "glass", b, Bc, "0-2-1-", 0.5, 0.2, 77, 3, 0.35, 0.4)
    b += 16
    # the waltz once more, everyone, then the lanterns go out one by one
    waltz(b, Ac, 0.38)
    s.drums(b, 16, tick, 0.32)
    o_pad(s, "strings", b, Ac, 0.25, 58, 3, -0.2, 0.6, 0.5)
    o_pad(s, "horns", b, Ac, 0.2, 53, 3, -0.1, 0.4, 0.45)
    s.mel("clar", b, A, 0.4, 0, -0.2, 0.4, dshift=-2)
    s.mel("strings", b, A, 0.45, 1, -0.35, 0.45, legato=1.0)
    b = s.mel("celesta", b, A, 0.55, 1, 0.25, 0.35)
    beat, gap = s.bar(b), 0.5
    for k, d in enumerate([4, 2, 0, 4, 2, 0, -3, 0]):
        s.note("musicbox", beat, 1, s.pitch(d) + 12, 0.4 - k * 0.025, 0.25, 0.4)
        beat += gap
        gap *= 1.15
    o_pad(s, "strings", b, ["Bb"], 0.25, 58, 3, -0.2, 0.6, 0.6, each=3, shape="dim")
    s.note("bell", s.bar(b + 2), 3, s.pitch(0) - 12, 0.25, -0.1, 0.5)
    return s


SONGS = {f.__name__: f for f in [menu, crown_peace, crown_battle, crown_win, brood_peace, brood_battle, brood_win,
                                 clock_peace, clock_battle, clock_win, defeat,
                                 crown_peace_2, crown_peace_3, crown_peace_4, crown_battle_2, crown_battle_3,
                                 brood_peace_2, brood_peace_3, brood_peace_4, brood_battle_2, brood_battle_3,
                                 clock_peace_2, clock_peace_3, clock_peace_4, clock_battle_2, clock_battle_3,
                                 menu_2, menu_3, menu_4, menu_5,
                                 crown_peace_5, crown_battle_4, crown_battle_5,
                                 brood_peace_5, brood_battle_4, brood_battle_5,
                                 clock_peace_5, clock_battle_4, clock_battle_5]}

# the pieces the game picks from (stings excluded), in the order of scripts/music_tracks.gd;
# the game finds them by name: <faction>_peace*, <faction>_battle*, menu*
TRACK_ORDER = [f + m for f in ("crown", "brood", "clock")
               for m in ("_peace", "_peace_2", "_peace_3", "_peace_4", "_peace_5",
                         "_battle", "_battle_2", "_battle_3", "_battle_4", "_battle_5")] + \
              ["menu", "menu_2", "menu_3", "menu_4", "menu_5"]


def write_tracks():
    lines = ["class_name MusicTracks",
             "## Generated by tools/music/compose.py - every piece of music, by faction and mood.",
             "const TRACKS := {"]
    for nm in TRACK_ORDER:
        lines.append('\t"%s": "%s",' % (nm, SONGS[nm]().title.replace('"', '\\"')))
    lines.append("}")
    with open(os.path.join(ROOT, "scripts", "music_tracks.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")

if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a != "--tracks"]
    if not names and "--tracks" not in sys.argv:
        names = list(SONGS)
    for nm in names:
        song = SONGS[nm]()
        L, R = song.render()
        write_ogg(song.name, L, R, song.q)
        print("%-14s %-28s %5.1fs" % (song.name, song.title, len(L) / SR))
    write_tracks()
