"""PocketRTS soundtrack: hand-written pieces for the menu and for each faction.

Every faction has a calm piece (building up) and a battle piece (the game cross-fades to it
when fighting breaks out), plus a victory sting; there is one shared defeat sting.

  The Crown      17th-century pike-and-shot: lute, recorder (fife), shawm, horns, snare and timpani.
  The Brood      the swamp: buzzing drones, a low "throat" choir, log drums, big drums, phrygian modes.
  The Clockwork  music boxes and machinery: glass chimes, dulcimer, reedy regal, ticks, anvils, steam;
                 played dead on the grid (no human timing), the battle piece in 7/8.

Usage: python3 tools/music/compose.py [name ...]   -> assets/music/<name>.ogg
Needs numpy, scipy and ffmpeg. The instrument library (synth.py) is shared with TCG-RPG.
"""
import os
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import synth  # noqa: E402
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


# --------------------------------------------------------------------------- score

class Song:
    def __init__(self, name, title, bpm, meter, tonic, mode, reverb=(2.0, 0.4), humanize=0.006, seed=1):
        self.name, self.title = name, title
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

    def note(self, inst, beat, dur, midi, vel=0.7, pan=0.0, send=0.3):
        j = self.rng.normal(0, self.humanize) if self.humanize else 0.0
        v = float(np.clip(vel + (self.rng.normal(0, 0.04) if self.humanize else 0), 0.05, 1.0))
        self.ev.append((max(0.0, self.sec(beat) + j), "n", inst, midi, self.sec(dur), v, pan, send))

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
            tonic=None, mode=None):
        for i, b in enumerate(bars):
            for off, dur, di, acc in self.parse(b):
                strong = off % 1 == 0 and int(off) % 2 == 0
                self.note(inst, self.bar(bar0 + i) + off, dur * legato,
                          self.pitch(di, acc, tonic, mode) + 12 * octave,
                          vel + (accent if strong else 0), pan, send)
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

    # render
    def render(self):
        synth.clear_cache()
        end = max(e[0] + e[4] for e in self.ev) + 3.5
        L = np.zeros(int(end * SR) + SR)
        R = np.zeros_like(L)
        send = np.zeros_like(L)
        for t0, kind, inst, midi, dur, vel, pan, snd in self.ev:
            x = synth.render_note(inst, midi, dur, vel) if kind == "n" else synth.render_drum(inst, vel)
            i = int(t0 * SR)
            x = x[: len(L) - i]
            a = (pan + 1) * np.pi / 4
            L[i:i + len(x)] += x * np.cos(a)
            R[i:i + len(x)] += x * np.sin(a)
            send[i:i + len(x)] += x * snd
        ir = synth.reverb_ir(*self.reverb)
        L, R = synth.apply_reverb(L, R, send, ir)
        return master(L, R)


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


SONGS = {f.__name__: f for f in [menu, crown_peace, crown_battle, crown_win, brood_peace, brood_battle, brood_win,
                                 clock_peace, clock_battle, clock_win, defeat]}

if __name__ == "__main__":
    names = sys.argv[1:] or list(SONGS)
    for nm in names:
        song = SONGS[nm]()
        L, R = song.render()
        write_ogg(song.name, L, R)
        print("%-14s %-28s %5.1fs" % (song.name, song.title, len(L) / SR))
