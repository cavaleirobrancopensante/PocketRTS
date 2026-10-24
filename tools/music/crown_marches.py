"""More Crown music (registered into compose.py):

  crown_battle_6..10   orchestral marches composed ON the five marching snare solos (art/audio_src/marching/
                       drums1..5.mp3): the solo is the rhythm section, laid on the tempo grid it was played to
  menu_6..10           the same five solos under five anthems (another cut of each, grander, drums lower)
  crown_battle_11..14  generated marches: brass, strings, timpani and snare over a seeded melody
  crown_peace_6..9     generated calm pieces (lute, recorder, harp, strings; no drums)
  menu_11..14          generated anthems (slower, grander)

The generated pieces are seeded: the same numbers give the same piece. Only the Crown has these so
far - the Brood and the Clockwork need as many (see CLAUDE.md backlog).
"""
import os
import subprocess

import numpy as np

SRC = os.path.join(os.path.dirname(__file__), "..", "..", "art", "audio_src", "marching")


class DrumPiece:
    """A cut of one of the snare solos, mastered like the rest of the music."""

    def __init__(self, C, name, title, solo, which, length=50.0):
        self.C, self.name, self.title, self.q = C, name, title, 3
        self.solo, self.which, self.length = solo, which, length

    def render(self):
        C = self.C
        raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", os.path.join(SRC, "drums%d.mp3" % self.solo),
                              "-f", "f32le", "-ac", "2", "-ar", str(C.SR), "-"], capture_output=True).stdout
        x = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)
        n = int(self.length * C.SR)
        n = min(n, len(x) - 2 * C.SR)
        hop = C.SR
        env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
        w = n // hop
        score = [(np.mean(env[i:i + w]), i) for i in range(2, len(env) - w)]
        ranked = sorted(score, reverse=True)
        i0 = ranked[0][1]
        if self.which == 1:       # the second cut: the best one that starts well away from the first
            far = [s for s in ranked if abs(s[1] - i0) >= max(8, w // 2)]
            i0 = far[0][1] if far else min(len(env) - w - 1, i0 + 12)
        seg = x[i0 * hop: i0 * hop + n].copy()
        fi, fo = int(0.3 * C.SR), int(2.5 * C.SR)
        seg[:fi] *= np.linspace(0, 1, fi)[:, None]
        seg[-fo:] *= (np.linspace(1, 0, fo) ** 1.5)[:, None]
        L, R = C.master(seg[:, 0].astype(float), seg[:, 1].astype(float), 0.15, 0.89)
        return L, R


SOLO_BPM = {1: 120, 2: 110, 3: 110, 4: 120, 5: 120}      # (found with librosa; solos 2 and 3 are dead steady)


def load_solo(C, solo):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", os.path.join(SRC, "drums%d.mp3" % solo),
                          "-f", "f32le", "-ac", "2", "-ar", str(C.SR), "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(float)


def solo_bars(C, solo):
    x = load_solo(C, solo)
    bar = 4 * 60.0 / SOLO_BPM[solo]
    return x, bar, int((len(x) / C.SR - 2) / bar)


def align(C, x, bpm, nbars, avoid=None):
    """Start time (s) in the solo where a grid of `bpm` fits its hits best (bar lines weigh more)."""
    import librosa
    hop = 64
    y = x.mean(1).astype(np.float32)
    y = librosa.resample(y, orig_sr=C.SR, target_sr=22050)
    env = librosa.onset.onset_strength(y=y, sr=22050, hop_length=hop)
    fps = 22050 / hop
    beat = 60.0 / bpm
    need = nbars * 4 * beat
    best, bs = 0.0, -1.0
    top = len(y) / 22050 - need - 0.5
    for s0 in np.arange(0.0, max(top, 0.01), 0.02):
        if avoid is not None and abs(s0 - avoid) < 8.0 and top > avoid + 8.0 or (avoid is not None and abs(s0 - avoid) < 8.0 and top <= 8.0 and False):
            continue
        k = np.arange(0, nbars * 4)
        idx = np.clip(((s0 + k * beat) * fps).astype(int), 0, len(env) - 1)
        e = env[idx]
        sc = e.sum() + 1.5 * e[::4].sum()
        if sc > bs:
            bs, best = sc, s0
    return best


def register(C):
    NAMES = C.orchestra.NAMES

    class BedSong(C.Song):
        """A Song whose rhythm section is one of the snare solos, laid on the song's own tempo grid."""
        bed_x = None
        bed_t0 = 0.0
        bed_ratio = 0.9

        def render(self):
            L, R = super().render()
            n = len(L)
            i0 = int(self.bed_t0 * C.SR)
            seg = self.bed_x[i0: i0 + n]
            seg = np.pad(seg, ((0, n - len(seg)), (0, 0)))
            f = int(0.5 * C.SR)
            seg[-int(3.0 * C.SR):] *= np.linspace(1, 0, int(3.0 * C.SR))[:, None]
            seg[:f] *= np.linspace(0.4, 1, f)[:, None]
            def lvl(a):
                m = np.abs(a) > 1e-4
                return float(np.sqrt(np.mean(a[m] ** 2))) if m.any() else 1e-6
            g = self.bed_ratio * lvl(L) / lvl(seg[:, 0])
            return C.master(L + seg[:, 0] * g, R + seg[:, 1] * g, 0.15, 0.89)
    notes = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

    def tok(i):
        o, d = divmod(i, 7)
        return str(d + 1) + ("'" * o if o > 0 else "," * -o)

    def chord_name(tonic_pc, mode, deg):
        iv = C.MODES[mode]
        r = (tonic_pc + iv[(deg - 1) % 7]) % 12
        third = (iv[(deg + 1) % 7] - iv[(deg - 1) % 7]) % 12
        fifth = (iv[(deg + 3) % 7] - iv[(deg - 1) % 7]) % 12
        q = "dim" if fifth == 6 else ("m" if third == 3 else "")
        return NAMES[r] + q

    def tonic_of(name):
        return notes[name[0]] + (1 if "#" in name else -1 if "b" in name else 0)

    MINOR = [[1, 1, 4, 1, 6, 4, 5, 1], [1, 6, 4, 5, 1, 4, 5, 1], [1, 3, 6, 4, 1, 5, 4, 5],
             [1, 4, 7, 3, 6, 4, 5, 5]]
    MAJOR = [[1, 5, 6, 4, 1, 4, 5, 1], [1, 4, 5, 1, 6, 4, 5, 1], [1, 6, 4, 5, 1, 3, 4, 5],
             [1, 5, 1, 4, 6, 2, 5, 1]]
    RHY4 = [[1, 1, 1, 1], [1.5, 0.5, 1, 1], [1, 1, 2], [2, 1, 1], [0.5, 0.5, 1, 2], [1, 0.5, 0.5, 2],
            [0.5, 0.5, 0.5, 0.5, 2], [1.5, 0.5, 2]]
    RHY3 = [[1, 1, 1], [2, 1], [1.5, 0.5, 1], [1, 2]]

    def melody(rng, tonic_pc, mode, prog, meter, calm, hi=9, lo=-2):
        """8 bars (a motif, its answer, the motif again, a cadence) on the chord tones of `prog`."""
        rhy = RHY4 if meter == 4 else RHY3
        if calm:
            rhy = [r for r in rhy if min(r) >= 1] or rhy
        motif_r = [rhy[int(rng.integers(len(rhy)))] for _ in range(2)]
        bars, prev = [], 7 if not calm else 4
        for b, deg in enumerate(prog):
            tones = [(deg - 1 + k) % 7 for k in (0, 2, 4)]
            r = motif_r[b % 2] if b < 6 else (rhy[int(rng.integers(len(rhy)))] if b == 6 else [meter])
            toks = []
            for j, d in enumerate(r):
                last = (b == 7 and j == len(r) - 1)
                if last:
                    cand = [i for i in range(lo, hi) if i % 7 == 0]
                elif j == 0 or d >= 1.5:
                    cand = [i for i in range(lo, hi) if i % 7 in tones]
                else:
                    cand = list(range(lo, hi))
                step = prev + int(rng.choice([-2, -1, -1, 0, 1, 1, 2]))
                prev = min(cand, key=lambda i: abs(i - step))
                prev = int(np.clip(prev, lo, hi))
                toks.append("%s:%s" % (tok(prev), d))
            bars.append(" ".join(toks))
        return bars

    def generated(name, title, seed, key, mode, bpm, meter, kind, bed=None):
        rng = np.random.default_rng(seed)
        tpc = tonic_of(key)
        pool = MINOR if mode in ("aeolian", "dorian", "harmonic") else MAJOR
        pa = pool[int(rng.integers(len(pool)))]
        pb = pool[int(rng.integers(len(pool)))]
        A = melody(rng, tpc, mode, pa, meter, kind == "peace")
        B = melody(rng, tpc, mode, pb, meter, kind == "peace")
        Ac = [chord_name(tpc, mode, d) for d in pa]
        Bc = [chord_name(tpc, mode, d) for d in pb]
        big = kind == "battle" or kind == "anthem"
        cls = BedSong if bed else C.Song
        s = cls(name, title, bpm, meter, C.n(key[0] + ("#" if "#" in key else ""), 4), mode,
                   reverb=(2.4 if kind != "battle" else 1.7, 0.45), seed=seed, q=1.5, mastering="epic",
                   predelay=0.02, target=0.15 if big else 0.13)
        nsec = 4
        if bed:
            solo, ratio, nsec, avoid = bed
            s.bed_x, bar_s, _ = solo_bars(C, solo)
            s.bed_ratio = ratio
            s.bed_t0 = align(C, s.bed_x, bpm, 2 + 8 * nsec + 4, avoid)
        if meter == 4:
            ost, step, bass = "01210121", 0.5, "1:1 5,:1 1:1 5,:1"
            w1 = {"S.s.S.s.": 0.12, "K...K...": 0.0}
            w2 = {"SsssS.ss": 0.12, "K.b.K.b.": 0.0}
            fill = {"S.ssssss": 0.12, "b.b.b.b.": 0.0}
        else:
            ost, step, bass = "012120", 0.5, "1:1 5,:1 5,:1"
            w1 = {"S.s.s.": 0.12, "K.....": 0.0}
            w2 = {"S.ssS.": 0.12, "b.....": 0.0}
            fill = {"S.ssss": 0.12, "b.b.b.": 0.0}
        o_ost, o_bass, o_pad, o_timp = C.o_ost, C.o_bass, C.o_pad, C.o_timp

        def timps(b, ch, v):
            for i, c in enumerate(ch):
                o_timp(s, s.bar(b + i), c, v)
        b = 0
        if kind == "peace":
            for rep in range(2):
                for mel, ch in ((A, Ac), (B, Bc)):
                    o_ost(s, "harp", b, ch, "012321" if meter == 3 else "0123210123210123"[:8] if False else ost,
                          step, 0.34, 55, 4, 0.35, 0.45, 1.5)
                    o_pad(s, "strings", b, ch, 0.22, 57, 3, -0.2, 0.6, 0.5, shape="arc")
                    o_bass(s, "pizz", b, ch, bass, 0.38, 38, 0.3)
                    if rep:
                        s.mel("strings", b, mel, 0.34, 0, -0.3, 0.4, legato=0.98)
                    s.mel("recorder", b, mel, 0.46, 1, 0.3, 0.35, legato=0.9)
                    b += 8
            o_pad(s, "organ", b, [Ac[0]], 0.3, 52, 3, 0.0, 0.5, 0.5, each=2, legato=0.97)
            return s
        s.note("lowstr", 0, s.meter * 2, C.n(key[0], 2), 0.4, 0.3, 0.3, "swell")
        C.o_timp_roll(s, s.bar(1), meter, Ac[0], 0.2, 0.8)
        b = 2
        for si in range(nsec):
            rep = 0 if si < nsec // 2 else 1
            for mel, ch in (((A, Ac), (B, Bc))[si % 2],):
                o_ost(s, "spicc", b, ch, ost, step, 0.36 + 0.05 * rep, 52, 3, -0.25, 0.15)
                o_bass(s, "lowstr", b, ch, bass, 0.42 + 0.05 * rep, 36, 0.3, 0.15)
                if not bed:
                    s.drums(b, 8, w1 if rep == 0 else w2, 0.4 + 0.1 * rep, fill=fill)
                timps(b, ch, 0.5 + 0.12 * rep)
                if kind == "anthem":
                    o_pad(s, "strings", b, ch, 0.3, 55, 3, -0.3, 0.6, 0.5, shape="arc")
                if rep == 0:
                    s.mel("horns", b, mel, 0.6, 0, -0.15, 0.3, legato=0.92)
                    if mel is B:
                        s.mel("recorder", b, mel, 0.36, 1, 0.35, 0.25, legato=0.85)
                else:
                    o_bass(s, "lowbr", b, ch, "1:%d" % meter, 0.55, 36, 0.3)
                    o_pad(s, "chorus", b, ch, 0.34, 57, 3, 0.0, 0.8, 0.5)
                    s.mel("strings", b, mel, 0.55, 1, -0.35, 0.3, legato=0.98)
                    s.mel("horns", b, mel, 0.55, 0, -0.15, 0.3)
                    s.mel("tpts", b, mel, 0.68, 0, 0.15, 0.3, legato=0.9)
                    if mel is A:
                        C.o_crash(s, s.bar(b), 0.7, None)
                b += 8
        # the build and the close
        C.o_timp_roll(s, s.bar(b), meter * 2, Ac[0], 0.3, 0.95)
        C.o_swell(s, s.bar(b), meter * 2, 0.7)
        if not bed:
            s.roll("s", s.bar(b), meter * 2, 0.25, 0.15, 0.8, 0.12)
        b += 2
        C.o_final(s, b, C.orchestra.NAMES[tpc] + ("m" if mode in ("aeolian", "dorian", "harmonic") else ""),
                  0.85, [("horns", 4, 0), ("strings", 4, 7), ("tpts", 3, 12), ("chorus", 3, 5)], 52, 2, 33)
        return s

    def add(name, title, make):
        C.SONGS[name] = make
        if name not in C.TRACK_ORDER:
            C.TRACK_ORDER.append(name)

    RN = "I II III IV V".split()
    BT = ["The Drummer's Road", "Tattoo at Dusk", "Over the Parapet", "Beating to Quarters", "Columns on the March"]
    AT = ["Anthem of the Drumline", "Banners and Drums", "Roll of the Regiment", "The Long Parade", "Drums for the King"]
    KEYS = [("D", "aeolian"), ("A", "harmonic"), ("G", "ionian"), ("E", "aeolian"), ("C", "ionian")]
    AKEYS = [("F", "ionian"), ("D", "ionian"), ("A", "aeolian"), ("G", "ionian"), ("E", "aeolian")]
    for k in range(1, 5):          # (solo 1 is left out: the Fifes and the old anthem replaced its pieces)
        solo = k + 1
        _, _, nb = solo_bars(C, solo)
        nsec = max(2, min(4, (nb - 6) // 8))
        bpm = SOLO_BPM[solo]
        add("crown_battle_%d" % (6 + k), BT[k],
            lambda k=k, solo=solo, nsec=nsec, bpm=bpm: generated("crown_battle_%d" % (6 + k), BT[k], 800 + k,
                KEYS[k][0], KEYS[k][1], bpm, 4, "battle", (solo, 0.95, nsec, None)))
        add("menu_%d" % (6 + k), AT[k],
            lambda k=k, solo=solo, nsec=nsec, bpm=bpm: generated("menu_%d" % (6 + k), AT[k], 820 + k,
                AKEYS[k][0], AKEYS[k][1], bpm, 4, "anthem", (solo, 0.5, max(2, nsec - 1), None)))
