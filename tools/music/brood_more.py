"""The Brood's second set of ten pieces (registered into compose.py), so the Brood has twenty in the
Crown's shape: two pieces that open a match, three skirmish pieces, three full battle pieces and two
calm ones. Every melody is written out bar by bar.

THE HIVE CALL, the Brood's theme, comes back in all ten: a low fifth, a leap up to the tonic and a
fourth higher, then a sigh down by steps to the tonic again (in phrygian: 5, 1 4 b3 b2 1). It is
stated plainly in the calm pieces, broken into pieces and chased in the skirmishes, and roared by
the choir in long notes in the battles; "Night over the Drowned Wood" turns it upside down.

  brood_battle_6   The Brood Wakes             open      F phrygian, 4/4, 70-82
  brood_battle_7   The Hive Gathers            open      G aeolian with a flat second, 7/4 (3+2+2), 92
  brood_battle_8   Something in the Water      skirmish  B flat phrygian, 5/4 (3+2), 112
  brood_battle_9   The Scent of Blood          skirmish  G phrygian, 7/8 (2+2+3), 250 eighths
  brood_battle_10  Circling                    skirmish  E flat locrian, 4/4, 88
  brood_battle_11  The Swarm at Full Cry       battle    E phrygian dominant, 7/8 (2+2+3), 280 eighths
  brood_battle_12  The Queen's War-Song        battle    F sharp phrygian, 5/4 (3+2), 132
  brood_battle_13  Ten Thousand Mouths         battle    G sharp aeolian, 11/8 (3+3+3+2), 290-312 eighths
  brood_peace_6    The Queen's Lullaby         calm      F aeolian, 3/4, 58 (slowing to 48)
  brood_peace_7    Night over the Drowned Wood calm      G sharp phrygian, 6/4, 54

The Brood's timing breathes: every piece has a tempo that drifts a little (a slow sine over four bars),
some speed up into their climaxes, and the notes are placed more loosely than the Crown's.
New sounds: a bullroarer (a whirring, roaring drone), an udu (a clay water-pot drum with a rising
"bloop"), a bone clack and a seed rattle.
"""
import numpy as np


def register(C):
    import synth
    from synth import SR, _t, _env, _noise, _bandpass, _lowpass, _highpass
    o_pad, o_bass, o_ost = C.o_pad, C.o_bass, C.o_ost
    o_timp, o_timp_roll, o_timps, o_swell, o_crash, o_final = (C.o_timp, C.o_timp_roll, C.o_timps,
                                                                C.o_swell, C.o_crash, C.o_final)
    transpose = C.transpose

    # ------------------------------------------------------------------------------- new sounds
    def bullroar(freq, dur, vel=0.7):
        """A bullroarer: a slat whirled on a cord, a breathy roar that wobbles with each turn."""
        nh = int(dur * SR)
        nn = nh + int(0.9 * SR)
        t = _t(nn)
        rot = 2.3 + 0.7 * np.sin(2 * np.pi * 0.11 * t)
        rph = 2 * np.pi * np.cumsum(rot) / SR
        f = freq * (1 + 0.16 * np.sin(rph))
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = sum(np.sin(k * ph) / k for k in range(1, 8))
        air = _bandpass(_noise(nn), freq * 1.5, freq * 7) * 0.9
        am = 0.35 + 0.65 * np.sin(rph * 0.5) ** 2
        s = _lowpass((tone * 0.35 + air) * am, 2000)
        return s * _env(nh, min(2.0, dur * 0.4), 0.8, nn) * vel * 0.2

    def udu(vel=0.8, base=105.0):
        """A clay water pot struck on its hole: a low 'bloop' that bends upward, a slap on top."""
        nn = int(0.7 * SR)
        t = _t(nn)
        f = base * (0.78 + 0.42 * (1 - np.exp(-t * 9)))
        ph = 2 * np.pi * np.cumsum(f) / SR
        s = np.sin(ph) * np.exp(-t * 5.5) + 0.25 * np.sin(2 * ph) * np.exp(-t * 11)
        slap = _bandpass(_noise(nn), 700, 2600) * np.exp(-t * 90) * 0.35
        return (s + slap) * np.minimum(1, t / 0.004) * vel * 0.5

    def clack(vel=0.8):
        """Two bones knocked together."""
        nn = int(0.12 * SR)
        t = _t(nn)
        s = (np.sin(2 * np.pi * 2150 * t) * np.exp(-t * 90) + 0.6 * np.sin(2 * np.pi * 3420 * t) * np.exp(-t * 120))
        s += _bandpass(_noise(nn), 1500, 6000) * np.exp(-t * 140) * 0.6
        return s * vel * 0.22

    def rattle(vel=0.8):
        """A gourd of seeds shaken once: a swish of tiny clicks."""
        nn = int(0.3 * SR)
        t = _t(nn)
        grains = (np.random.default_rng(int(vel * 100)).random(nn) > 0.985).astype(float)
        e = np.minimum(1, t / 0.05) * np.exp(-t * 14)
        s = _highpass(_noise(nn) * 0.3 + grains * 3.0, 2800)
        return s * e * vel * 0.12

    synth.INSTRUMENTS["bullroar"] = bullroar
    synth.DRUMS.update({"u": udu, "U": lambda v: udu(v, 72.0), "o": clack, "v": rattle})

    # ------------------------------------------------------------------------------- the score
    class BSong(C.Song):
        """A Song whose tempo breathes: `tempo` [(beat, bpm), ...] (eased between), plus a slow drift."""

        def __init__(self, *a, tempo=None, breathe=0.012, **kw):
            super().__init__(*a, **kw)
            pts = tempo or [(0, self.bpm)]
            self._st = 1.0 / 16
            beats = np.arange(0, 12000, self._st)
            bpm = np.interp(beats, [p[0] for p in pts], [p[1] for p in pts])
            per = self.meter * 4.0
            bpm = bpm * (1 + breathe * np.sin(2 * np.pi * beats / per) + 0.4 * breathe * np.sin(2 * np.pi * beats / (per * 2.7) + 1.3))
            self._cum = np.concatenate([[0.0], np.cumsum(60.0 / bpm * self._st)])

        def sec(self, beat):
            x = max(0.0, beat) / self._st
            i = int(x)
            f = x - i
            return float(self._cum[i] * (1 - f) + self._cum[i + 1] * f)

        def note(self, inst, beat, dur, midi, vel=0.7, pan=0.0, send=0.3, shape=None):
            j = self.rng.normal(0, self.humanize) if self.humanize else 0.0
            v = float(np.clip(vel + (self.rng.normal(0, 0.05) if self.humanize else 0), 0.05, 1.0))
            e = (max(0.0, self.sec(beat) + j), "n", inst, midi, self.sec(beat + dur) - self.sec(beat), v, pan, send)
            self.ev.append(e + (shape,) if shape else e)

        def mel(self, inst, bar0, bars, *a, **kw):
            for b in bars:          # every bar must fill the meter exactly
                tot = sum(float(tok.split(":")[1]) for tok in b.split())
                if abs(tot - self.meter) > 1e-6:
                    raise ValueError("%s: bar '%s' lasts %g, not %d" % (self.name, b, tot, self.meter))
            return super().mel(inst, bar0, bars, *a, **kw)

    def song(name, title, bpm, meter, key, octv, mode, seed, acc=0, **kw):
        return BSong(name, title, bpm, meter, C.n(key, octv) + acc, mode, reverb=kw.pop("reverb", (2.6, 0.6)),
                     seed=seed, q=1.5, mastering="epic", predelay=kw.pop("predelay", 0.025),
                     target=kw.pop("target", 0.15), humanize=kw.pop("humanize", 0.014), **kw)

    # ------------------------------------------------------------------------------- helpers
    def bed(s, b, nb, ins=(0, 2), bub=(0, 2), cro=(0, 1), vel=1.0, u=1):
        """The swamp itself: insects, bubbles and frogs scattered over the bars."""
        if ins[1]:
            s.scatter(b, nb, ins[0], ins[1], lambda bt, r: s.hit("z", bt, vel * r.uniform(0.2, 0.45),
                                                              r.choice([-0.8, -0.5, 0.5, 0.8]), 0.5), 0.5 * u)
        if bub[1]:
            s.scatter(b, nb, bub[0], bub[1], lambda bt, r: s.hit("w" if r.random() < 0.6 else "W", bt,
                                                              vel * r.uniform(0.15, 0.35), r.uniform(-0.7, 0.7), 0.45),
                      0.5 * u)
        if cro[1]:
            s.scatter(b, nb, cro[0], cro[1], lambda bt, r: s.hit("q", bt, vel * r.uniform(0.25, 0.45),
                                                              r.uniform(-0.6, 0.6), 0.4), 1.0 * u)

    def heart(s, b, nb, v0, v1=None, code="B", u=1, per=1, pan=0.0):
        """A heartbeat: lub-dub at the start of every bar (twice a bar with per=2), v0 -> v1."""
        v1 = v0 if v1 is None else v1
        for i in range(nb):
            v = v0 + (v1 - v0) * i / max(1, nb - 1)
            for k in range(per):
                bt = s.bar(b + i) + k * s.meter / per
                s.hit(code, bt, v, pan, 0.2)
                s.hit(code, bt + 0.6 * u, v * 0.62, pan, 0.2)

    def drone(s, b, nb, midi, inst="throat", vel=0.3, span=2, pan=0.0, send=0.5, shape=None):
        for i in range(b, b + nb, span):
            k = min(span, b + nb - i)
            s.note(inst, s.bar(i), s.meter * k + 0.3, midi, vel, pan, send, shape)

    def ramp(v0, v1, i, n):
        return v0 + (v1 - v0) * i / max(1, n - 1)

    # =============================================================================== OPENINGS
    def wakes():
        """The swamp before dawn, then the eggs crack and the hive gathers. Tense under the calm."""
        s = song("brood_battle_6", "The Brood Wakes", 70, 4, "F", 3, "phrygian", 1601,
                 tempo=[(0, 68), (4 * 16, 72), (4 * 40, 78), (4 * 50, 82), (4 * 54, 74), (4 * 60, 66)],
                 reverb=(3.6, 0.65), target=0.128)
        CALL = ["5,:1 1:1 4:2", "3:1 2:1 1:2"]
        CALL_AUG = ["5,:2 1:2", "4:4", "3:2 2:2", "1:4"]
        ANSWER_AUG = ["1:2 4:2", "5:4", "4:2 3:2", "2:4"]          # ends on the flat second: unanswered
        HIGH = ["1:1 4:1 3:2", "2:1 1:1 7,:2", "1:1 4:1 5:2", "2:4"]
        N = 60
        bed(s, 0, 8, (0, 1), (1, 2), (0, 0))
        bed(s, 8, N - 10, (1, 3), (1, 3), (0, 1))
        bed(s, N - 2, 2, (1, 2), (1, 2), (0, 0))
        T0 = s.pitch(0)
        s.note("throat", 0, 32.3, T0 - 12, 0.24, 0.0, 0.5, "swell")
        drone(s, 8, N - 8, T0 - 12, "throat", 0.22, 4)
        s.note("bullroar", s.bar(2), 22, T0, 0.45, -0.55, 0.65)
        s.note("bullroar", s.bar(40), 28, T0 + 7, 0.55, 0.55, 0.65, "arc")
        heart(s, 4, 12, 0.18, 0.34, "B")
        # the first call, slow, over the water; the low choir answers and leaves it hanging
        o_pad(s, "trem", 8, ["Fm", "Gb"], 0.12, 60, 3, -0.2, 0.6, 0.6, each=4, shape="arc")
        s.mel("boneflute", 8, CALL_AUG, 0.4, 1, -0.25, 0.6)
        s.mel("choir_u", 12, ANSWER_AUG, 0.36, 0, 0.25, 0.6)
        # the hive gathers: a log drum in 3+3+2, shakers, the choir humming, the call passed around
        roots = [0, 0, 1, 0, 0, 0, 6, 0, 0, 1, 0, 0]
        logs = "1:0.75 1:0.75 5,:0.5 1:0.75 2:0.75 1:0.5"
        heart(s, 16, 24, 0.34, 0.44, "B")
        s.rel("log", 16, roots, logs, 0.36, 0, 0.3, 0.3)
        s.drums(16, 12, {"x...x.x...x.x...": -0.45}, 0.22)
        s.pad("choir_o", 16, roots, 0.14, -1, 0.0, 0.6, voicing=(0, 1))
        s.mel("lowstr", 18, CALL, 0.42, -1, 0.3, 0.35)
        s.mel("boneflute", 22, CALL, 0.48, 1, -0.3, 0.5)
        s.mel("choir_u", 26, CALL, 0.45, 0, 0.2, 0.55)
        # the tension underneath: tremolo swells, the flute higher, frame drums
        r2 = [0, 0, 1, 1, 0, 0, 6, 6, 0, 0, 1, 1]
        s.rel("log", 28, r2, logs, 0.4, 0, 0.3, 0.3)
        s.drums(28, 12, {"D.......d...d...": 0.0, "..t.......t.....": 0.4, "x...x.x...x.x...": -0.45}, 0.32)
        o_pad(s, "trem", 28, ["Fm", "Gb", "Fm", "Ebm", "Fm", "Gb"], 0.16, 60, 3, -0.2, 0.6, 0.6, each=2, shape="swell")
        for i, d in enumerate([0, 1, 0, 6, 0, 1]):
            s.note("chorus_u", s.bar(28 + 2 * i), 7.6, s.pitch(d) - 12, 0.3, 0.1, 0.6, "arc")
        s.mel("boneflute", 30, HIGH, 0.5, 1, -0.3, 0.5)
        s.mel("boneflute", 36, CALL, 0.46, 1, -0.3, 0.5)
        # the swell: taiko, the choir sings the call in fourths, the horns low, the bass on the tonic
        s.rel("log", 40, [0] * 12, logs, 0.46, 0, 0.3, 0.3)
        s.drums(40, 12, {"T.......T..T....": 0.0, "..t...t...t...t.": 0.4, "x.x.x.x.x.x.x.x.": -0.45,
                         "....D.......D...": -0.2}, 0.36, fill={"T...T...T.T.TTTT": 0.0, "..t...t.tttttttt": 0.4})
        for k in range(3):
            s.mel("chorus_u", 40 + 4 * k, CALL_AUG, ramp(0.4, 0.55, k, 3), 0, -0.1, 0.55)
            s.mel("chorus_o", 40 + 4 * k, CALL_AUG, ramp(0.3, 0.45, k, 3), 0, 0.15, 0.55, dshift=3)
        s.mel("horns", 44, CALL_AUG, 0.42, -1, -0.25, 0.35)
        s.mel("horns", 48, CALL_AUG, 0.55, -1, -0.25, 0.35)
        s.mel("lowstr", 48, CALL_AUG, 0.5, -1, 0.3, 0.35)
        s.mel("boneflute", 48, CALL_AUG, 0.45, 1, 0.4, 0.45)
        C.o_bass(s, "lowbr", 44, ["F5"] * 8, "1:4", 0.36, 29, 0.3, 0.25, 0.98, shape="arc")
        o_pad(s, "trem", 44, ["Fm", "Gb", "Fm", "Gb"], 0.24, 60, 3, -0.2, 0.6, 0.6, each=2, shape="swell")
        o_swell(s, s.bar(48), 16, 0.5)
        # it settles; the call once more, half of it, and then the tonic
        heart(s, 52, 6, 0.4, 0.2, "B")
        s.rel("log", 52, [0] * 4, logs, 0.32, 0, 0.3, 0.3)
        s.hit("G", s.bar(52), 0.45)
        s.mel("boneflute", 53, ["5,:1 1:1 4:2", "r:4", "3:2 2:2", "1:4"], 0.45, 1, -0.25, 0.55)
        s.mel("choir_u", 54, ["r:4", "5,:2 1:2", "1:4"], 0.38, 0, 0.25, 0.6)
        s.pad("chorus_u", 57, [0], 0.32, 0, 0.0, 0.6, voicing=(0, 1, 2), bars_each=2)
        s.note("throat", s.bar(57), 9, T0 - 12, 0.4, 0.0, 0.5, "dim")
        s.hit("G", s.bar(57), 0.4)
        s.hit("B", s.bar(57), 0.5)
        s.hit("q", s.bar(58) + 1, 0.4, 0.4)
        return s

    def gathers():
        """In seven: the log drums call the hive together, the choir hums the call, the strings walk."""
        s = song("brood_battle_7", "The Hive Gathers", 92, 7, "G", 3, "aeolian", 1602,
                 tempo=[(0, 90), (7 * 20, 93), (7 * 32, 97), (7 * 38, 92), (7 * 44, 86)], reverb=(2.8, 0.6),
                 target=0.146)
        LOG7 = "1:1 1:0.5 5,:0.5 1:1 2-:1 1:1 7,:1 1:1"
        CALL7 = ["5,:1 1:1 4:2 3:1 2-:1 1:1"]
        ANS7 = ["1:2 7,:1 6,:1 5,:3"]
        ANS7b = ["1:3 7,:2 1:2"]
        B = ["5:3 4:1 3:1 4:2", "5:2 6:1 5:1 4:3", "3:3 2-:1 1:1 7,:2", "1:7"]
        WALK = "1:1 5,:0.5 1:0.5 3:1 1:1 5,:1 2-:1 1:1"
        T0 = s.pitch(0)
        N = 44
        bed(s, 0, N, (0, 2), (1, 2), (0, 1))
        s.rel("log", 0, [0] * 12, LOG7, 0.38, 0, 0.3, 0.25)
        s.drums(0, 12, {"v.....v...v...": -0.5}, 0.25)
        drone(s, 2, 10, T0 - 12, "throat", 0.28, 2)
        # the low choir hums the call, the throat a fifth under
        for k in range(4):
            b = 4 + 2 * k
            s.mel("choir_u", b, CALL7, 0.45 + 0.02 * k, 0, 0.2, 0.55)
            s.mel("choir_u", b + 1, ANS7 if k % 2 == 0 else ANS7b, 0.4, -1 if k < 2 else 0, -0.2, 0.55)
            if k >= 2:
                s.mel("throat", b, CALL7, 0.32, -1, 0.0, 0.4)
        # the strings walk in 3+2+2, a flute line over them, the taiko keeps the groups
        roots = [0, 0, 5, 3, 0, 0, 5, 6]       # Gm, Eb, Cm, F
        heart(s, 12, 24, 0.24, 0.4, "T", 1)
        s.rel("log", 12, [0] * 24, LOG7, 0.36, 0, 0.3, 0.25)
        s.rel("pizz", 12, roots, WALK, 0.4, -1, 0.25, 0.2)
        s.drums(12, 8, {"T.....T...T...": 0.0, "v.....v...v...": -0.5}, 0.3)
        s.pad("choir_o", 12, roots, 0.15, -1, 0.0, 0.6, voicing=(0, 1, 2))
        s.mel("boneflute", 12, B, 0.5, 1, -0.3, 0.5)
        s.mel("boneflute", 16, B, 0.45, 1, -0.3, 0.5, dshift=2)
        s.mel("choir_u", 16, B, 0.36, 0, 0.25, 0.55)
        # rising: the low strings take the call, horns join, the drums grow
        s.rel("pizz", 20, roots, WALK, 0.45, -1, 0.25, 0.2)
        s.drums(20, 8, {"T.....T...T...": 0.0, "..t...t.t.t.t.": 0.4, "D.....d...d...": -0.25, "v.v.v.v.v.v.v.": -0.5},
                0.36, fill={"T.T.T.T.T.TTTT": 0.0, "tttttttttttttt": 0.4})
        for k in range(4):
            s.mel("lowstr", 20 + 2 * k, CALL7, 0.42 + 0.03 * k, -1, 0.3, 0.35)
            s.mel("lowstr", 21 + 2 * k, ANS7, 0.38, -1, 0.3, 0.35)
        s.mel("horns", 24, CALL7 + ANS7 + CALL7 + ANS7b, 0.4, -1, -0.25, 0.35)
        o_pad(s, "trem", 20, ["Gm", "Eb", "Gm", "Eb"], 0.16, 62, 3, -0.2, 0.6, 0.6, each=2, shape="swell")
        o_swell(s, s.bar(26), 14, 0.45)
        # the gathering at its height (still no crash: the fight has not come)
        chords = ["Gm", "Gm", "Eb", "Cm", "Gm", "Gm", "Eb", "F"]
        s.rel("pizz", 28, roots, WALK, 0.48, -1, 0.25, 0.2)
        o_bass(s, "lowbr", 28, chords, "1:3 1:2 5,:2", 0.4, 31, 0.3, 0.25)
        s.drums(28, 8, {"T.....T...T...": 0.0, "..t.t.t.t.t.tt": 0.4, "D.d.d.d...d.d.": -0.25, "vvvvvvvvvvvvvv": -0.5},
                0.4, fill={"T.T.T.T.TTTTTT": 0.0, "tttttttttttttt": 0.4})
        o_timps(s, 28, chords, 0.4, (0, 3, 5))
        for k in range(4):
            s.mel("chorus_u", 28 + 2 * k, CALL7, 0.5, 0, -0.1, 0.5)
            s.mel("chorus_o", 28 + 2 * k, CALL7, 0.36, 0, 0.15, 0.5, dshift=2)
            s.mel("chorus_u", 29 + 2 * k, ANS7, 0.45, 0, -0.1, 0.5)
        s.mel("strings", 28, B + B, 0.44, 1, -0.3, 0.35, legato=0.98)
        s.mel("boneflute", 32, B, 0.4, 2, 0.35, 0.5)
        # it subsides: the logs alone again, the choir hums the answer, the tonic
        s.rel("log", 36, [0] * 6, LOG7, 0.36, 0, 0.3, 0.25)
        heart(s, 36, 6, 0.32, 0.18, "T", 1)
        s.mel("choir_u", 37, ANS7 + ["r:7"] + ANS7b, 0.4, 0, 0.2, 0.6)
        s.mel("boneflute", 38, CALL7, 0.42, 1, -0.3, 0.55)
        drone(s, 36, 6, T0 - 12, "throat", 0.3, 3)
        s.pad("chorus_u", 42, [0], 0.3, 0, 0.0, 0.6)
        s.note("throat", s.bar(42), 7.5, T0 - 12, 0.38, 0.0, 0.5, "dim")
        s.hit("T", s.bar(42), 0.5)
        s.hit("G", s.bar(42), 0.38)
        s.hit("q", s.bar(42) + 3, 0.4, -0.3)
        return s

    # =============================================================================== SKIRMISHES
    def water():
        """Something hunts in the shallows: a stalking ostinato, a heartbeat, the call in broken pieces."""
        s = song("brood_battle_8", "Something in the Water", 112, 5, "A", 3, "phrygian", 1603, acc=1,
                 tempo=[(0, 110), (5 * 30, 114), (5 * 36, 108), (5 * 56, 116), (5 * 60, 112)], reverb=(2.2, 0.55),
                 target=0.162)
        OST = "1:0.5 1:0.5 5,:0.5 1:0.5 2:0.5 1:0.5 r:0.5 1:0.5 7,:0.5 1:0.5"
        FRAG = ["5,:0.5 1:0.5 4:1 r:3"]
        FRAG2 = ["r:2 3:0.5 2:0.5 1:2"]
        HEAD = ["5,:0.5 1:0.5 4:1.5 r:2.5"]
        CALL = ["5,:1 1:1 4:2 r:1", "3:1 2:1 1:3"]
        HB = {"l..b......l..b......": 0.0}
        T0 = s.pitch(0)
        N = 64
        bed(s, 0, N, (0, 2), (0, 1), (0, 1))
        s.scatter(0, N, 0, 2, lambda bt, r: s.hit("v", bt, r.uniform(0.25, 0.45), r.choice([-0.7, 0.7]), 0.4), 0.5)
        drone(s, 0, N - 4, T0 - 12, "throat", 0.26, 4)
        s.drums(0, 4, HB, 0.36)
        # the stalk: pizzicato and log on the ostinato, a pedal high above
        s.rel("pizz", 4, [0] * 16, OST, 0.38, -1, 0.25, 0.15)
        s.rel("log", 4, [0] * 16, OST, 0.3, 0, -0.3, 0.2)
        s.drums(4, 16, HB, 0.4)
        o_pad(s, "trem", 4, ["Bb5"], 0.13, 70, 2, 0.0, 0.5, 0.55, each=16, shape="arc")
        for b in (6, 10, 14, 18):
            s.mel("boneflute", b, FRAG, 0.5, 1, -0.35, 0.55)
        for b in (8, 12, 16):
            s.mel("choir_u", b, FRAG2, 0.4, 0, 0.3, 0.55)
            s.hit("q", s.bar(b) + 4, 0.45, 0.5, 0.3)
        # the hunt quickens: spiccato strings, the head of the call climbing step by step
        ch = ["Bbm", "Bbm", "B", "Bbm", "Bbm", "Abm", "B", "Bbm"]
        o_ost(s, "spicc", 20, ch + ch, "00100010000120010010", 0.25, 0.32, 46, 3, 0.25, 0.15,
              acc=">...>.......>.......")
        s.rel("log", 20, [0] * 16, OST, 0.34, 0, -0.3, 0.2)
        s.drums(20, 16, {"l..b......l..b......": 0.0, "....t.......t.....t.": 0.4, "v.v.v.v.v.v.v.v.v.v.": -0.5}, 0.42)
        for k in range(4):
            s.mel("lowstr", 20 + 2 * k, HEAD, 0.45 + 0.03 * k, -1, 0.3, 0.35, dshift=k)
            s.mel("boneflute", 21 + 2 * k, HEAD, 0.4, 1, -0.35, 0.5, dshift=k + 2)
        s.mel("boneflute", 28, CALL, 0.5, 1, -0.3, 0.5)
        s.mel("choir_u", 30, CALL, 0.45, 0, 0.25, 0.5)
        s.mel("boneflute", 32, CALL, 0.5, 1, -0.3, 0.5, dshift=1)
        s.mel("choir_u", 34, ["5,:1 1:1 4:2 r:1", "r:5"], 0.45, 0, 0.25, 0.5, dshift=1)
        o_pad(s, "horns", 32, ["Bb5"], 0.3, 46, 2, -0.2, 0.4, 0.4, each=4, shape="swell")
        # it stops and listens
        s.drums(36, 8, HB, 0.32)
        s.rel("log", 36, [0] * 8, OST, 0.24, 0, -0.3, 0.3)
        s.mel("boneflute", 38, FRAG, 0.38, 1, 0.5, 0.7)
        s.mel("boneflute", 41, FRAG2, 0.34, 1, -0.5, 0.7)
        s.hit("q", s.bar(40), 0.5, -0.3)
        # the second wave, closer: taiko for the heart, the horns low with the call
        ch2 = ["Bbm", "B", "Bbm", "Abm"]
        o_ost(s, "spicc", 44, ch2 * 4, "00100010000120010010", 0.25, 0.38, 46, 3, 0.25, 0.15,
              acc=">...>.......>.......")
        s.rel("pizz", 44, [0] * 16, OST, 0.4, -1, 0.25, 0.15)
        s.drums(44, 16, {"T..T......T..T......": 0.0, "..t.t...t...t.t...t.": 0.4, "....D.......D.....d.": -0.25,
                         "v.v.v.v.v.v.v.v.v.v.": -0.5}, 0.44, fill={"T..T..T..T..T.T.TTTT": 0.0})
        o_pad(s, "chorus_u", 44, ch2 * 4, 0.26, 49, 3, 0.0, 0.6, 0.5)
        for k, b in enumerate((44, 48, 52)):
            s.mel("horns", b, CALL, 0.42 + 0.05 * k, -1, -0.25, 0.35, dshift=k)
            s.mel("boneflute", b + 2, HEAD + ["r:5"], 0.45, 1, 0.35, 0.5, dshift=k + 4)
        s.mel("chorus_u", 56, CALL + CALL, 0.55, 0, -0.1, 0.5)
        s.mel("horns", 56, CALL + CALL, 0.5, -1, -0.25, 0.35, dshift=2)
        o_pad(s, "trem", 52, ["Bbm", "B"], 0.26, 58, 3, -0.2, 0.6, 0.6, each=4, shape="swell")
        o_swell(s, s.bar(56), 19.5, 0.5)
        # gone again: one blow, then only the heart and the call fading
        s.hit("T", s.bar(60), 0.8)
        s.hit("U", s.bar(60), 0.7)
        s.hit("q", s.bar(60) + 1, 0.5, 0.4)
        s.note("throat", s.bar(60), 18, T0 - 24, 0.4, 0.0, 0.5, "dim")
        s.drums(61, 3, HB, 0.28)
        s.mel("boneflute", 61, ["r:2 3:1 2:1 1:1", "1:5"], 0.4, 1, -0.3, 0.6)
        return s

    def scent():
        """In seven eighths: restless strings and toms, the shawm on the scent, held back from the kill."""
        s = song("brood_battle_9", "The Scent of Blood", 250, 7, "G", 3, "phrygian", 1604,
                 tempo=[(0, 244), (7 * 48, 248), (7 * 60, 258), (7 * 80, 256), (7 * 96, 240)], reverb=(1.9, 0.55),
                 target=0.152, humanize=0.012)
        U = 2
        CALL = ["5,:2 1:2 4:3", "3:2 2:2 1:3"]
        HUNT = ["5,:1 1:1 4:2 r:3"]
        HUNT2 = ["1:1 4:1 5:2 r:3"]
        M = ["1:2 2:2 3:3", "4:2 3:2 2:3", "1:2 2:2 4:3", "3:7"]
        M2 = ["5:2 4:2 3:3", "4:2 3:2 2:3", "3:2 2:2 1:2 7,:1", "1:7"]
        LOGP = "1:2 1:2 2:1 1:2"
        T0 = s.pitch(0)
        N = 98
        bed(s, 0, N, (0, 2), (0, 1), (0, 1), u=U)
        drone(s, 0, 40, T0 - 12, "throat", 0.24, 8)
        s.drums(0, 8, {"l.l.l..": 0.0, "v...v..": -0.5}, 0.3)
        # the scent: strings in 2+2+3, the shawm calls, the choir hunts
        A = ["Gm", "Gm", "Ab", "Gm"]
        o_ost(s, "spicc", 8, A * 4, "0102010", 1, 0.32, 43, 3, 0.25, 0.15, acc=">.>.>..")
        s.rel("log", 8, [0] * 16, LOGP, 0.36, 0, -0.3, 0.2)
        s.drums(8, 16, {"l.l.l..": 0.0, "..t...t": 0.4, "v.v.v.v": -0.5}, 0.36)
        s.mel("shawm", 8, CALL, 0.48, 0, -0.2, 0.3, legato=0.9)
        s.mel("choir_u", 12, HUNT + HUNT2, 0.42, 0, 0.25, 0.45)
        s.mel("shawm", 16, M, 0.46, 0, -0.2, 0.3, legato=0.9)
        s.mel("shawm", 20, M2, 0.46, 0, -0.2, 0.3, legato=0.9)
        s.mel("choir_u", 20, ["r:7", "r:7", "r:4 7,:3", "1:7"], 0.38, -1, 0.25, 0.5)
        # tension: a pedal on the flat second high up, the call climbing in the choir
        o_ost(s, "spicc", 24, ["Gm", "Ab"] * 8, "0102010", 1, 0.34, 43, 3, 0.25, 0.15, acc=">.>.>..")
        s.rel("log", 24, [0] * 16, LOGP, 0.38, 0, -0.3, 0.2)
        s.drums(24, 16, {"l.l.l.l": 0.0, "..t.t.t": 0.4, "D...d..": -0.25, "v.v.v.v": -0.5}, 0.38)
        s.note("trem", s.bar(24), 7 * 16, s.pitch(1) + 12, 0.15, 0.3, 0.5, "swell")
        drone(s, 40, 58, T0 - 12, "throat", 0.26, 8)
        for k in range(4):
            s.mel("choir_u", 24 + 4 * k, CALL, 0.42 + 0.03 * k, 0, -0.1, 0.45, dshift=k)
            s.mel("boneflute", 26 + 4 * k, HUNT + ["r:7"], 0.38, 1, 0.4, 0.5, dshift=k + 2)
        # it loses the trail: drums and frogs, a far flute
        s.drums(40, 8, {"l...l..": 0.0, "v...v..": -0.5}, 0.3)
        bed(s, 40, 8, (1, 2), (1, 2), (0, 1), u=U)
        s.mel("boneflute", 42, HUNT + ["r:7"] + HUNT2, 0.36, 1, -0.5, 0.75)
        # the trail again, closer and closer
        for i in range(8):
            v = ramp(0.22, 0.38, i, 8)
            o_ost(s, "spicc", 48 + i, [A[i % 4]], "0102010", 1, v, 43, 3, 0.25, 0.15, acc=">.>.>..")
            s.drums(48 + i, 1, {"l.l.l..": 0.0, "..t...t": 0.4}, v + 0.06)
        s.rel("log", 48, [0] * 8, LOGP, 0.34, 0, -0.3, 0.2)
        s.mel("lowstr", 52, CALL, 0.42, -1, 0.3, 0.35)
        o_swell(s, s.bar(52), 28, 0.4)
        # held at the edge: horns low with the call, the choir in chords, taiko on each bar
        P = ["Gm", "Gm", "Ab", "Gm", "Fm", "Eb", "Ab", "Gm"]
        o_ost(s, "spicc", 56, P * 3, "0102010", 1, 0.4, 43, 3, 0.25, 0.15, acc=">.>.>..")
        s.rel("log", 56, [0] * 24, LOGP, 0.4, 0, -0.3, 0.2)
        o_bass(s, "lowstr", 56, P * 3, "1:4 5,:3", 0.42, 31, 0.3, 0.15)
        s.drums(56, 24, {"T.l.l..": 0.0, "..t.t.t": 0.4, "D.d.d.d": -0.25, "v.v.v.v": -0.5}, 0.42,
                fill={"T.T.TTT": 0.0, "ttttttt": 0.4})
        o_pad(s, "chorus_u", 56, P * 3, 0.26, 49, 3, 0.0, 0.6, 0.5)
        s.mel("shawm", 56, M + M2, 0.5, 0, -0.2, 0.3, legato=0.9)
        for k in range(4):
            s.mel("horns", 56 + 2 * k, CALL, 0.4 + 0.03 * k, -1, 0.25, 0.35)
        s.mel("shawm", 64, M + M2, 0.52, 1, -0.2, 0.3, legato=0.9)
        s.mel("choir_u", 64, M + M2, 0.42, 0, 0.25, 0.45)
        s.mel("chorus_u", 72, CALL * 4, 0.52, 0, -0.05, 0.45)
        s.mel("horns", 72, CALL * 4, 0.45, -1, 0.25, 0.35, dshift=2)
        o_pad(s, "trem", 72, ["Gm", "Ab"] * 4, 0.22, 62, 3, -0.2, 0.6, 0.6, shape="swell")
        # the scent goes cold: the pulse fades, the call twice, a last blow
        for i in range(16):
            v = ramp(0.34, 0.16, i, 16)
            o_ost(s, "spicc", 80 + i, [A[i % 4]], "0102010", 1, v, 43, 3, 0.25, 0.15, acc=">.>.>..")
            s.drums(80 + i, 1, {"l.l.l..": 0.0}, v + 0.05)
        s.mel("shawm", 82, CALL, 0.42, 0, -0.2, 0.4, legato=0.9)
        s.mel("boneflute", 88, CALL, 0.36, 1, 0.35, 0.6)
        s.hit("B", s.bar(96), 0.7)
        s.hit("U", s.bar(96), 0.6)
        s.note("throat", s.bar(96), 12, T0 - 12, 0.42, 0.0, 0.5, "dim")
        s.note("choir_u", s.bar(96), 10, T0, 0.4, 0.0, 0.6, "dim")
        return s

    def circling():
        """Round and round the prey: the call turned and turned, a tritone pedal, two waves that pull back."""
        s = song("brood_battle_10", "Circling", 88, 4, "D", 3, "locrian", 1605, acc=1,
                 tempo=[(0, 86), (4 * 30, 92), (4 * 36, 84), (4 * 54, 96), (4 * 58, 84), (4 * 66, 76)],
                 reverb=(2.6, 0.6), target=0.148)
        R = [["5,:1 1:1 4:1 3:1", "2:1 1:1 5,:2"],
             ["4:1 3:1 2:1 1:1", "5,:1 1:1 4:2"],
             ["3:1 2:1 1:1 5,:1", "1:1 4:1 3:2"],
             ["2:1 1:1 5,:1 1:1", "4:1 3:1 2:2"]]
        FAST = ["5,:0.5 1:0.5 4:0.5 3:0.5 2:0.5 1:0.5 5,:1"]
        LOG = "1:1.5 1:0.5 2:1 1:1"
        T0 = s.pitch(0)
        N = 66
        bed(s, 0, N, (0, 2), (0, 1), (0, 1))
        heart(s, 0, 6, 0.2, 0.32, "T")
        s.note("bullroar", s.bar(1), 18, T0 + 12, 0.42, 0.5, 0.6, "arc")
        # the tritone pedal: tonic and flat fifth in the tremolo strings, the throat under them
        for b0, nb, v in ((2, 32, 0.12), (40, 18, 0.16)):
            s.note("trem", s.bar(b0), 4 * nb, T0 + 12, v, -0.3, 0.55, "arc")
            s.note("trem", s.bar(b0), 4 * nb, s.pitch(4) + 12, v * 0.85, 0.3, 0.55, "arc")
        drone(s, 2, 56, T0 - 12, "throat", 0.28, 4)
        # the flute circles: the call begun from each of its notes in turn
        heart(s, 6, 28, 0.32, 0.4, "T")
        s.rel("log", 6, [0] * 16, LOG, 0.34, 0, 0.3, 0.25)
        s.drums(6, 16, {"u.....u.....u.u.": -0.3}, 0.32)
        for k in range(8):
            s.mel("boneflute", 6 + 2 * k, R[k % 4], 0.48, 1, -0.3, 0.5)
        s.mel("choir_u", 14, R[0] + R[2] + R[1] + R[3], 0.36, 0, 0.3, 0.55)
        # wave one rises
        roots = [0, 0, 1, 1, 0, 0, 5, 1, 0, 0, 1, 1]
        s.arp("spicc", 22, roots, "0101020101010201", 0.25, 0.3, -1, 0.25, 0.15, 0.8)
        s.rel("log", 22, [0] * 12, LOG, 0.38, 0, 0.3, 0.25)
        s.drums(22, 12, {"T..T........T...": 0.0, "..t...t...t...t.": 0.4, "....D.......D.d.": -0.25}, 0.38)
        s.pad("chorus_u", 22, roots, 0.22, -1, 0.0, 0.55, voicing=(0, 1))
        for k in range(3):
            s.mel("horns", 22 + 4 * k, R[(k + 1) % 4] + R[(k + 2) % 4], 0.38 + 0.05 * k, -1, -0.25, 0.35)
            s.mel("boneflute", 22 + 4 * k, R[k % 4] + R[(k + 3) % 4], 0.46, 1, 0.3, 0.45)
        o_swell(s, s.bar(28), 22, 0.45)
        # it breaks off and listens
        heart(s, 34, 6, 0.36, 0.24, "T")
        s.mel("boneflute", 35, ["5,:1 1:1 4:2", "r:4", "3:1 2:1 1:2"], 0.36, 1, -0.5, 0.7)
        s.hit("q", s.bar(38) + 1, 0.45, 0.4)
        # wave two: tighter circles, quicker, higher
        roots2 = [0, 1, 0, 5, 0, 1, 0, 1, 0, 1, 0, 5, 0, 1, 1, 1]
        s.arp("spicc", 40, roots2, "0102010201020102", 0.25, 0.36, -1, 0.25, 0.15, 0.8)
        s.rel("pizz", 40, roots2, "1:0.5 1:0.5 2:0.5 1:0.5 1:0.5 5,:0.5 1:1", 0.36, -1, -0.25, 0.15)
        s.drums(40, 16, {"T..T....T..T....": 0.0, "..t.t.t...t.t.tt": 0.4, "D...D.d.D...D.dd": -0.25,
                         "v.v.v.v.v.v.v.v.": -0.5}, 0.42, fill={"T.T.T.T.TTTTTTTT": 0.0})
        s.pad("chorus_u", 40, roots2, 0.26, -1, 0.0, 0.55, voicing=(0, 1, 2))
        o_bass(s, "lowbr", 44, ["Eb5"] * 12, "1:4", 0.34, 27, 0.3, 0.25, shape="arc")
        for b in range(40, 56):
            s.mel("boneflute" if b % 2 == 0 else "choir_u", b, FAST, 0.44 if b % 2 == 0 else 0.4, 1 if b % 2 == 0 else 0,
                  -0.3 if b % 2 == 0 else 0.3, 0.45, dshift=(b - 40) // 4)
        for k in range(4):
            s.mel("horns", 40 + 4 * k, R[k] + R[(k + 2) % 4], 0.42 + 0.04 * k, -1, -0.2, 0.35)
        s.mel("chorus_u", 48, ["5,:2 1:2", "4:4", "3:2 2:2", "1:4", "5,:2 1:2", "4:4", "3:2 2:2", "1:4"],
              0.5, 0, 0.0, 0.5)
        o_pad(s, "trem", 48, ["E", "Ebdim"] * 4, 0.2, 60, 3, -0.2, 0.6, 0.6, shape="swell")
        o_swell(s, s.bar(52), 16, 0.55)
        # pulled back at the last moment: one stroke, the call alone in the low strings
        s.hit("T", s.bar(56), 0.85)
        s.hit("U", s.bar(56), 0.7)
        s.hit("q", s.bar(56) + 2, 0.5, -0.4)
        s.mel("lowstr", 57, ["5,:2 1:2", "4:4", "3:2 2:2", "1:4"], 0.42, -1, 0.2, 0.45)
        heart(s, 57, 8, 0.3, 0.14, "T")
        s.mel("boneflute", 61, R[1] + ["1:4"], 0.36, 1, -0.3, 0.65)
        s.note("throat", s.bar(61), 18, T0 - 12, 0.36, 0.0, 0.5, "dim")
        s.note("chorus_u", s.bar(63), 10, T0, 0.3, 0.0, 0.6, "dim")
        return s

    # =============================================================================== FULL BATTLE
    def full_cry():
        """In seven eighths: the swarm in full cry. A war tune, a long build, the choir roars the call."""
        s = song("brood_battle_11", "The Swarm at Full Cry", 280, 7, "E", 3, "phrygian_dom", 1606,
                 tempo=[(0, 262), (7 * 8, 270), (7 * 72, 276), (7 * 80, 284), (7 * 112, 288)], reverb=(2.0, 0.6),
                 target=0.158, humanize=0.011)
        CALL = ["5,:2 1:2 4:3", "3:2 2:2 1:3"]
        ROAR = ["5,:4 1:3", "4:7", "3:4 2:3", "1:7"]
        W = ["1:2 2:2 3:3", "4:2 5:2 6:3", "5:2 4:2 3:3", "2:7", "3:2 4:2 5:3", "6:2 5:2 4:3",
             "3:2 2:2 1:2 7,:1", "1:7"]
        Wc = ["E", "E", "Am", "F", "Am", "Dm", "F", "E"]
        Bm = ["5:7", "6:4 5:3", "4:7", "3:4 2:3", "1:4 2:3", "3:7", "2:4 1:3", "7,:7"]
        Bc = ["Am", "F", "Dm", "Am", "Dm", "Am", "F", "E"]
        d1 = {"B...B..": 0.0, "..t...t": 0.4, "x.x.x.x": -0.4}
        d2 = {"T.d.T..": 0.0, ".tt.t.t": 0.4, "x.x.x.x": -0.4, "....D..": -0.25}
        d3 = {"T.TdT.d": 0.0, "b......": 0.0, "tttt.tt": 0.4, "xxxxxxx": -0.4, "D.d.D.d": -0.25}
        fill = {"T.T.TTT": 0.0, "ttttttt": 0.4}

        def swarm(b, chords, vel=0.42):
            o_ost(s, "spicc", b, chords, "0102010", 1, vel, 45, 3, 0.25, 0.15, acc=">.>.>..")
            o_bass(s, "log", b, chords, "1:2 1:2 5,:1 1:2", vel, 52, -0.3, 0.2)

        T0 = s.pitch(0)
        # the swamp holds its breath: lone taiko, bullroarers, a throat swelling
        for i in range(8):
            s.hit("T", s.bar(i), 0.35 + 0.05 * i)
            s.hit("q", s.bar(i) + 4, 0.35, 0.4) if i % 2 else None
        s.note("bullroar", 0, 7 * 8, T0, 0.5, -0.5, 0.6, "swell")
        s.note("bullroar", s.bar(3), 7 * 5, T0 + 7, 0.45, 0.5, 0.6, "swell")
        s.note("throat", 0, 7 * 8, T0 - 12, 0.4, 0.0, 0.4, "swell")
        s.note("lowstr", 0, 7 * 8, T0 - 12, 0.35, 0.3, 0.3, "swell")
        b = 8
        # the choir calls the swarm
        swarm(b, ["E"] * 16)
        s.drums(b, 16, d1, 0.5, fill=fill)
        for k in range(4):
            s.mel("choir_u", b + 4 * k, CALL, 0.5, 0, -0.1, 0.45)
            s.mel("throat", b + 4 * k + 2, ["5,:2 1:2 4:3", "1:7"], 0.38, -1, 0.15, 0.35)
        s.mel("chorus_u", b + 8, CALL + ["r:7"] * 2 + CALL, 0.42, 0, 0.2, 0.45, dshift=3)
        b += 16
        # the war tune: shawm and horns, the strings boil
        for rep in range(2):
            o_crash(s, s.bar(b), 0.6 + 0.1 * rep, None)
            swarm(b, Wc, 0.45)
            s.drums(b, 8, d2, 0.55, fill=fill)
            o_bass(s, "lowbr", b, Wc, "1:4 5,:3", 0.45 + 0.05 * rep, 33, 0.3)
            o_pad(s, "chorus_u", b, Wc, 0.28, 49, 3, 0.0, 0.6, 0.5)
            s.mel("shawm", b, W, 0.55, 1 if rep else 0, 0.15, 0.3, legato=0.9)
            s.mel("horns", b, W, 0.5, 0, -0.15, 0.3)
            if rep:
                s.mel("strings", b, W, 0.48, 1, -0.35, 0.3, legato=0.98)
            b += 8
        # B: wings over the water; strings in long notes, the bone flute above, then the shawm
        for rep in range(2):
            swarm(b, Bc, 0.44)
            s.drums(b, 8, d2 if rep else d1, 0.52, fill=fill)
            o_pad(s, "chorus", b, Bc, 0.32 + 0.05 * rep, 52, 3, 0.0, 0.7, 0.5, shape="arc")
            o_timps(s, b, Bc, 0.45, (0, 4))
            s.mel("strings", b, Bm, 0.52, 1, -0.3, 0.35, legato=1.0)
            s.mel("horns", b, Bm, 0.45, 0, 0.2, 0.35)
            s.mel("boneflute" if rep == 0 else "shawm", b, Bm, 0.45, 1, 0.35, 0.4, dshift=2)
            b += 8
        # the breakdown: drums, logs, frogs and the throat; the call in pieces
        s.drums(b, 8, {"T...T.T": 0.0, "..t.t.t": 0.4, "q......": 0.3}, 0.55)
        o_bass(s, "log", b, ["E"] * 8, "1:2 1:2 5,:1 1:2", 0.45, 52, -0.3, 0.2)
        drone(s, b, 8, T0 - 12, "throat", 0.45, 4)
        s.mel("boneflute", b + 1, ["5,:2 1:2 4:3", "r:7", "r:7", "3:2 2:2 1:3"], 0.45, 1, -0.4, 0.6)
        s.mel("choir_u", b + 5, ["5,:2 1:2 4:3", "r:7"], 0.42, 0, 0.4, 0.6)
        b += 8
        # the long build: a timpani roll, the choir begins the roar under its breath
        swarm(b, ["E"] * 8, 0.3)
        s.drums(b, 8, {"T......": 0.0, "..t...t": 0.4}, 0.45, fill={"T.T.TTT": 0.0, "ttttttt": 0.4})
        o_timp_roll(s, s.bar(b), 7 * 8, "E", 0.15, 0.9)
        o_swell(s, s.bar(b + 2), 7 * 6, 0.75)
        s.mel("chorus_u", b, ROAR + ROAR, 0.48, 0, 0.0, 0.5, shape="swell", shape_min=3)
        o_pad(s, "lowbr", b, ["E5"], 0.5, 33, 2, 0.3, 0.3, 0.3, each=8, shape="swell")
        o_pad(s, "strings", b + 4, ["E"], 0.4, 56, 4, -0.2, 0.7, 0.4, each=4, shape="swell")
        b += 8
        # THE ROAR: the whole choir sings the call in long notes over the war tune
        for k in range(3):
            ch = transpose(Wc, 1) if k == 2 else Wc
            if k == 2:
                s.tonic += 1
            o_crash(s, s.bar(b), 0.85, "b")
            o_crash(s, s.bar(b + 4), 0.6, None)
            swarm(b, ch, 0.5)
            s.drums(b, 8, d3, 0.6, fill=fill)
            o_bass(s, "lowbr", b, ch, "1:2 1:2 5,:3", 0.62, 33, 0.3)
            o_bass(s, "lowstr", b, ch, "1:4 1:3", 0.55, 33, 0.25)
            o_timps(s, b, ch, 0.62, (0, 2, 4))
            s.mel("chorus", b, ROAR + ROAR, 0.62, 0, -0.1, 0.5)
            s.mel("chorus_u", b, ROAR + ROAR, 0.55, -1, 0.1, 0.5)
            if k:
                s.mel("chorus_o", b, ROAR + ROAR, 0.45, 0, 0.25, 0.5, dshift=2)
            s.mel("strings", b, W, 0.58, 1, -0.35, 0.3, legato=0.98)
            s.mel("horns", b, W, 0.6, 0, -0.15, 0.3)
            if k:
                s.mel("shawm", b, W, 0.52, 1, 0.15, 0.3, legato=0.9)
            b += 8
        # coda in F: the call stabbed out by everyone, then the end
        chs = ["F", "F"]
        for k in range(2):
            o_crash(s, s.bar(b + 2 * k), 0.75, "b")
            swarm(b + 2 * k, chs, 0.5)
            s.drums(b + 2 * k, 2, {"T.T.T..": 0.0, "ttttttt": 0.4, "xxxxxxx": -0.4}, 0.62)
            s.mel("chorus", b + 2 * k, CALL, 0.62, 0, -0.1, 0.5, legato=0.85)
            s.mel("horns", b + 2 * k, CALL, 0.62, 0, -0.15, 0.3, legato=0.85)
            s.mel("strings", b + 2 * k, CALL, 0.58, 1, 0.3, 0.3, legato=0.85)
            s.mel("lowbr", b + 2 * k, CALL, 0.55, -1, 0.3, 0.25, legato=0.85)
        b += 4
        s.drums(b, 1, {"T.T.TTT": 0.0, "ttttttt": 0.4}, 0.7)
        b += 1
        o_final(s, b, "F", 0.85, [("chorus", 4, 0), ("horns", 3, 0), ("strings", 4, 12)], 48, 3, 29)
        s.hit("T", s.bar(b), 0.95)
        s.hit("G", s.bar(b), 0.5)
        s.note("throat", s.bar(b), 14, s.pitch(0) - 12, 0.55)
        s.hit("q", s.bar(b + 2), 0.5, 0.3)
        return s

    def war_song():
        """In five: the Queen's war-song, begun by a lone choir and taken up by the whole swamp."""
        s = song("brood_battle_12", "The Queen's War-Song", 132, 5, "F", 3, "phrygian", 1607, acc=1,
                 tempo=[(0, 128), (5 * 24, 132), (5 * 48, 134), (5 * 56, 140), (5 * 86, 142)], reverb=(2.2, 0.6),
                 target=0.158)
        C1 = ["1:1.5 1:0.5 1:1 2:1 1:1", "3:1.5 2:0.5 1:1 7,:2"]
        CALL = ["5,:1 1:1 4:2 r:1", "3:1 2:1 1:3"]
        CHANT = C1 + CALL
        CALL_AUG = ["5,:2 1:2 4:1", "4:5", "3:2 2:2 1:1", "1:5"]
        W5 = ["5:2 4:1 3:2", "4:1 5:1 6:3", "5:2 4:1 2:2", "3:5", "1':2 7:1 6:2", "5:1 4:1 3:3",
              "2:1.5 1:0.5 2:1 3:2", "1:5"]
        Wc = ["F#m", "G", "Em", "F#m", "D", "Bm", "G", "F#m"]
        Cc = ["F#m", "F#m", "F#m", "G"]
        r1 = {"T.....T.....T...T...": 0.0, "..t...t...t...t...t.": 0.4}
        r2 = {"T.....T..T..T...T.T.": 0.0, "..t.t.t...t.t.t.t.tt": 0.4, "D.......d...D.....d.": -0.25,
              "x.x.x.x.x.x.x.x.x.x.": -0.45}
        r3 = {"T..T..T..T..T.T.T.T.": 0.0, "b...........b.......": 0.0, "..t.t.t.t.t.t.t.tttt": 0.4,
              "D...D.d.D...D.d.D.dd": -0.25, "xxxxxxxxxxxxxxxxxxxx": -0.45}
        fill = {"T.T.T.T.T.T.TTTTTTTT": 0.0, "tttttttttttttttttttt": 0.4}
        RIFF = "1:1.5 1:0.5 1:1 2:1 1:1"
        T0 = s.pitch(0)
        # a lone throat choir chants, one taiko a bar
        for i in range(8):
            s.hit("T", s.bar(i), 0.4 + 0.03 * i)
        s.mel("choir_u", 0, CHANT + CHANT, 0.5, 0, 0.0, 0.5)
        s.mel("throat", 4, CHANT, 0.38, -1, 0.0, 0.4)
        bed(s, 0, 8, (0, 1), (0, 1), (0, 1))
        # the swamp answers: logs, low strings
        s.drums(8, 8, r1, 0.48)
        s.rel("log", 8, [0, 0, 0, 1] * 2, RIFF, 0.42, 0, -0.3, 0.2)
        o_bass(s, "lowstr", 8, Cc * 2, "1:3 5,:2", 0.42, 30, 0.3, 0.2)
        s.mel("chorus_u", 8, CHANT + CHANT, 0.52, 0, -0.1, 0.5)
        s.mel("throat", 8, CHANT + CHANT, 0.36, -1, 0.15, 0.4)
        # then the low brass and the spiccato; the shawm doubles the chant
        o_crash(s, s.bar(16), 0.55, None)
        s.drums(16, 8, r2, 0.52, fill=fill)
        s.rel("log", 16, [0, 0, 0, 1] * 2, RIFF, 0.42, 0, -0.3, 0.2)
        o_bass(s, "lowbr", 16, Cc * 2, RIFF, 0.48, 30, 0.3, 0.25)
        o_ost(s, "spicc", 16, Cc * 2, "00100010001000100120", 0.25, 0.36, 42, 3, 0.25, 0.15,
              acc=">.....>.....>...>...")
        s.mel("chorus_u", 16, CHANT + CHANT, 0.54, 0, -0.1, 0.5)
        s.mel("shawm", 16, CHANT + CHANT, 0.48, 1, 0.2, 0.3, legato=0.9)
        # B: the war-song itself, horns and strings; the second time with the full choir
        for rep in range(2):
            o_crash(s, s.bar(24 + 8 * rep), 0.7, "b")
            s.drums(24 + 8 * rep, 8, r2, 0.55, fill=fill)
            o_ost(s, "spicc", 24 + 8 * rep, Wc, "00100010001000100120", 0.25, 0.4, 42, 3, 0.25, 0.15,
                  acc=">.....>.....>...>...")
            o_bass(s, "lowbr", 24 + 8 * rep, Wc, "1:3 1:1 5,:1", 0.5, 30, 0.3, 0.25)
            o_timps(s, 24 + 8 * rep, Wc, 0.48, (0, 3))
            s.mel("horns", 24 + 8 * rep, W5, 0.55, 0, -0.15, 0.3)
            s.mel("strings", 24 + 8 * rep, W5, 0.5, 1, -0.35, 0.3, legato=0.98)
            if rep:
                o_pad(s, "chorus", 32, Wc, 0.4, 52, 3, 0.0, 0.8, 0.5)
                s.mel("shawm", 32, W5, 0.48, 1, 0.2, 0.3, legato=0.9)
            else:
                o_pad(s, "chorus_u", 24, Wc, 0.3, 49, 3, 0.0, 0.7, 0.5)
        # the breakdown: a lone bone flute sings the call slowly, the udu and logs, the frogs
        bed(s, 40, 8, (1, 2), (1, 2), (0, 1))
        s.drums(40, 8, {"U.....u.....u...u...": 0.0, "o.....o...o...o.....": 0.3}, 0.45)
        s.rel("log", 40, [0] * 8, "1:1.5 1:1.5 5,:1 1:1", 0.36, 0, -0.3, 0.3)
        drone(s, 40, 8, T0 - 12, "throat", 0.4, 4)
        s.mel("boneflute", 40, CALL_AUG + CALL_AUG, 0.5, 1, -0.3, 0.6, dshift=0)
        s.mel("choir_u", 44, CALL_AUG, 0.4, 0, 0.3, 0.6, dshift=2)
        # the build: timpani roll, the chant comes back in the choir, rising
        o_ost(s, "spicc", 48, ["F#m"] * 8, "00100010001000100120", 0.25, 0.3, 42, 3, 0.25, 0.15,
              acc=">.....>.....>...>...")
        s.drums(48, 8, {"T.........T.........": 0.0, "..t...t...t...t...t.": 0.4}, 0.48, fill=fill)
        o_timp_roll(s, s.bar(52), 20, "F#m", 0.2, 0.95)
        o_swell(s, s.bar(52), 20, 0.75)
        s.mel("chorus_u", 48, CHANT + CHANT, 0.5, 0, 0.0, 0.5, shape="swell", shape_min=1.9)
        o_pad(s, "lowbr", 48, ["F#5"], 0.5, 30, 2, 0.3, 0.3, 0.3, each=8, shape="swell")
        # the climax: everyone; the choir roars the call, the war-song, then a step higher
        for k, (mel, ch, roar) in enumerate(((W5, Wc, True), (CHANT + CHANT, Cc * 2, True), (W5, Wc, False))):
            b = 56 + 8 * k
            if k == 2:
                s.tonic += 1
                ch = transpose(ch, 1)
            o_crash(s, s.bar(b), 0.85, "b")
            o_crash(s, s.bar(b + 4), 0.6, None)
            s.drums(b, 8, r3, 0.6, fill=fill)
            o_ost(s, "spicc", b, ch, "00100010001000100120", 0.25, 0.46, 42, 3, 0.25, 0.15,
                  acc=">.....>.....>...>...")
            o_bass(s, "lowbr", b, ch, "1:1.5 1:0.5 1:1 2:1 1:1" if k == 1 else "1:3 1:1 5,:1", 0.6, 30, 0.3, 0.25)
            o_bass(s, "lowstr", b, ch, "1:3 5,:2", 0.55, 30, 0.25)
            o_timps(s, b, ch, 0.6, (0, 1.5, 3))
            o_pad(s, "chorus", b, ch, 0.36, 54, 3, 0.0, 0.8, 0.5)
            if roar:
                s.mel("chorus_u", b, CALL_AUG + CALL_AUG, 0.58, 0, 0.0, 0.5)
            else:
                s.mel("chorus_u", b, mel, 0.55, 0, 0.0, 0.5)
            s.mel("horns", b, mel, 0.6, 0, -0.15, 0.3)
            s.mel("strings", b, mel, 0.58, 1, -0.35, 0.3, legato=0.98)
            s.mel("shawm", b, mel, 0.5, 1, 0.2, 0.3, legato=0.9)
        # coda in G: the chant once more by all, and the end
        b = 80
        ch = transpose(Cc, 1)
        o_crash(s, s.bar(b), 0.8, "b")
        s.drums(b, 4, r3, 0.62, fill=fill)
        o_bass(s, "lowbr", b, ch, RIFF, 0.62, 31, 0.3, 0.25)
        o_pad(s, "chorus", b, ch, 0.4, 55, 3, 0.0, 0.8, 0.5)
        for inst, o, v in (("chorus_u", 0, 0.6), ("horns", 0, 0.6), ("strings", 1, 0.56), ("shawm", 1, 0.5)):
            s.mel(inst, b, CHANT, v, o, 0.0, 0.35, legato=0.9)
        b += 4
        o_final(s, b, "Gm", 0.85, [("chorus", 4, 0), ("horns", 3, 0), ("strings", 4, 12)], 50, 3, 31)
        s.hit("T", s.bar(b), 0.95)
        s.hit("G", s.bar(b), 0.5)
        s.note("throat", s.bar(b), 13, s.pitch(0) - 12, 0.55)
        return s

    def mouths():
        """In eleven: one long gathering crescendo, a layer at a time, until ten thousand mouths roar the call."""
        s = song("brood_battle_13", "Ten Thousand Mouths", 290, 11, "G", 3, "aeolian", 1608, acc=1,
                 tempo=[(0, 288), (11 * 56, 300), (11 * 60, 296), (11 * 64, 306), (11 * 88, 312), (11 * 91, 300)],
                 reverb=(2.1, 0.6), target=0.158, humanize=0.011)
        CALL11 = ["5,:3 1:3 4:3 3:1 2-:1", "1:11"]
        AUG = ["5,:6 1:5", "4:11", "3:6 2-:5", "1:11"]
        M = ["1:3 1:3 2:3 3:2", "4:3 3:3 2-:3 1:2", "5,:3 6,:3 7,:3 1:2", "1:11"]
        Mc = ["G#m", "C#m", "E", "G#m"]
        M2 = ["5:3 4:3 3:3 4:2", "5:3 6:3 5:3 4:2", "3:3 2-:3 1:3 7,:2", "1:11"]
        M2c = ["G#m", "E", "A", "G#m"]
        ACC = ">..>..>..>."
        OST = "00200200101"

        def ost(b, chords, v):
            o_ost(s, "spicc", b, chords, OST, 1, v, 44, 3, 0.25, 0.15, acc=ACC)

        T0 = s.pitch(0)
        U = 2
        # B0: the hum before the swarm: bullroarers, the throat, udu on the groups
        bed(s, 0, 64, (0, 2), (0, 2), (0, 1), u=U)
        s.note("bullroar", 0, 11 * 8, T0, 0.45, -0.5, 0.6, "arc")
        s.note("bullroar", s.bar(4), 11 * 8, T0 + 7, 0.4, 0.5, 0.6, "arc")
        drone(s, 0, 56, T0 - 12, "throat", 0.34, 4)
        s.drums(0, 64, {"U..u..u..u.": 0.0}, 0.32)
        # B1: logs, the choir hums the call
        s.rel("log", 8, [0] * 56, "1:3 1:3 5,:3 1:2", 0.34, 0, -0.3, 0.2)
        for k in range(4):
            s.mel("choir_u", 8 + 2 * k, CALL11, 0.4 + 0.02 * k, 0, 0.2, 0.5)
        # B2: strings, frame drums, the bone flute's chant
        for b in range(16, 56, 4):
            v = ramp(0.22, 0.42, (b - 16) // 4, 10)
            ost(b, Mc if (b // 4) % 2 == 0 else M2c, v)
        s.drums(16, 40, {"D..d..d..d.": -0.25, "..t..t..t.t": 0.4}, 0.32)
        s.mel("boneflute", 16, M + M2, 0.46, 1, -0.3, 0.5)
        # B3: taiko on the groups, the low choir sings the chant
        s.drums(24, 32, {"T........T.": 0.0}, 0.42)
        s.mel("chorus_u", 24, M + M2, 0.46, 0, -0.1, 0.5)
        s.mel("throat", 24, M + M2, 0.34, -1, 0.15, 0.4)
        # B4: low brass, horns take the chant, rattles
        s.drums(32, 24, {"v.v.v.v.v.v": -0.5}, 0.34)
        o_bass(s, "lowbr", 32, Mc + M2c + Mc + M2c + Mc + M2c, "1:6 1:5", 0.44, 30, 0.3, 0.25)
        s.mel("horns", 32, M + M2, 0.5, 0, -0.15, 0.3)
        s.mel("boneflute", 32, CALL11 * 4, 0.42, 1, 0.4, 0.5, dshift=2)
        # B5: the strings an octave up, the choir in chords, a crash
        o_crash(s, s.bar(40), 0.62, None)
        s.drums(40, 16, {"T..T..T..T.": 0.0, "xxxxxxxxxxx": -0.45}, 0.44)
        o_pad(s, "chorus", 40, Mc + M2c + Mc + M2c, 0.34, 52, 3, 0.0, 0.8, 0.5)
        s.mel("strings", 40, M + M2 + M + M2, 0.5, 1, -0.35, 0.3, legato=0.98)
        s.mel("chorus_u", 40, M + M2, 0.5, 0, -0.1, 0.5)
        o_timps(s, 40, Mc + M2c + Mc + M2c, 0.44, (0, 6))
        # B6: the shawm, the full drums
        s.drums(48, 8, {"b..........": 0.0, "..t.tt.t.tt": 0.4}, 0.48)
        s.mel("shawm", 48, M + M2, 0.5, 1, 0.2, 0.3, legato=0.9)
        s.mel("horns", 48, M + M2, 0.54, 0, -0.15, 0.3)
        # B7: a dip, a held breath - then the drums roll it in
        ost(56, ["G#m"] * 4, 0.24)
        s.drums(56, 4, {"T..........": 0.0}, 0.48)
        s.mel("choir_u", 56, CALL11 + CALL11, 0.42, 0, 0.0, 0.5)
        drone(s, 56, 8, T0 - 12, "throat", 0.48, 8)
        ost(60, ["G#m"] * 4, 0.34)
        s.drums(60, 4, {"T.....T..T.": 0.0, "..t..t..ttt": 0.4}, 0.5, fill={"T.T.T.TTTTT": 0.0, "ttttttttttt": 0.4})
        o_timp_roll(s, s.bar(60), 44, "G#m", 0.2, 0.95)
        o_swell(s, s.bar(60), 44, 0.75)
        o_pad(s, "lowbr", 60, ["G#5"], 0.5, 30, 2, 0.3, 0.3, 0.3, each=4, shape="swell")
        o_pad(s, "chorus", 60, ["G#m"], 0.4, 52, 3, 0.0, 0.8, 0.5, each=4, shape="swell")
        # B8: THE ROAR - every mouth sings the call in long notes, the chant underneath
        for k in range(2):
            b = 64 + 8 * k
            o_crash(s, s.bar(b), 0.85, "b")
            o_crash(s, s.bar(b + 4), 0.65, None)
            ch = (Mc + M2c)
            ost(b, ch, 0.48)
            s.drums(b, 8, {"T..T..T..T.": 0.0, "b.....b....": 0.0, "..t.tt.t.tt": 0.4, "D..d..d..dd": -0.25,
                           "xxxxxxxxxxx": -0.45}, 0.58, fill={"T.T.T.TTTTT": 0.0, "ttttttttttt": 0.4})
            o_bass(s, "lowbr", b, ch, "1:3 1:3 5,:3 1:2", 0.6, 30, 0.3, 0.25)
            o_bass(s, "lowstr", b, ch, "1:6 1:5", 0.55, 30, 0.25)
            o_timps(s, b, ch, 0.6, (0, 3, 6, 9))
            s.mel("chorus", b, AUG + AUG, 0.62, 0, -0.1, 0.5)
            s.mel("chorus_u", b, AUG + AUG, 0.55, -1, 0.1, 0.5)
            if k:
                s.mel("chorus_o", b, AUG + AUG, 0.45, 0, 0.25, 0.5, dshift=2)
            s.mel("strings", b, M + M2, 0.58, 1, -0.35, 0.3, legato=0.98)
            s.mel("horns", b, M + M2, 0.6, 0, -0.15, 0.3)
            s.mel("shawm", b, M + M2, 0.5, 1, 0.2, 0.3, legato=0.9)
        # B9: a half step higher, the peak
        s.tonic += 1
        b = 80
        ch = transpose(Mc + M2c, 1)
        o_crash(s, s.bar(b), 0.9, "b")
        o_crash(s, s.bar(b + 4), 0.7, "b")
        ost(b, ch, 0.5)
        s.drums(b, 8, {"T..T..TT.T.": 0.0, "b..b..b..b.": 0.0, "tt.ttt.tttt": 0.4, "D..d..d..dd": -0.25,
                       "xxxxxxxxxxx": -0.45}, 0.6, fill={"T.T.T.TTTTT": 0.0, "ttttttttttt": 0.4})
        o_bass(s, "lowbr", b, ch, "1:3 1:3 5,:3 1:2", 0.62, 31, 0.3, 0.25)
        o_bass(s, "lowstr", b, ch, "1:6 1:5", 0.56, 31, 0.25)
        o_timps(s, b, ch, 0.62, (0, 3, 6, 9))
        s.mel("chorus", b, AUG + AUG, 0.62, 0, -0.1, 0.5)
        s.mel("chorus_u", b, M + M2, 0.55, 0, 0.1, 0.5)
        s.mel("strings", b, AUG + AUG, 0.58, 1, -0.35, 0.3, legato=1.0)
        s.mel("horns", b, M + M2, 0.62, 0, -0.15, 0.3)
        s.mel("shawm", b, M + M2, 0.52, 1, 0.2, 0.3, legato=0.9)
        # B10: the call stabbed out by everyone, and the end
        b = 88
        for inst, o, v in (("chorus", 0, 0.62), ("horns", 0, 0.62), ("strings", 1, 0.58), ("lowbr", -1, 0.55),
                           ("chorus_u", -1, 0.55)):
            s.mel(inst, b, CALL11 + CALL11[:1] + ["r:11"], v, o, 0.0, 0.35, legato=0.85)
        s.drums(b, 4, {"T..T..T..T.": 0.0, "ttttttttttt": 0.4, "xxxxxxxxxxx": -0.45}, 0.62,
                fill={"T.T.T.TTTTT": 0.0, "ttttttttttt": 0.4})
        o_crash(s, s.bar(b), 0.8, "b")
        o_crash(s, s.bar(b + 2), 0.8, "b")
        b += 4
        o_final(s, b, "Am", 0.85, [("chorus", 4, 0), ("horns", 3, 0), ("strings", 4, 12)], 50, 2, 33)
        s.hit("T", s.bar(b), 0.95)
        s.hit("G", s.bar(b), 0.55)
        s.note("throat", s.bar(b), 30, s.pitch(0) - 12, 0.55)
        return s

    # =============================================================================== CALM
    def lullaby():
        """The Queen sings her brood to sleep: the call plainly, slowly, in a rocking three."""
        s = song("brood_peace_6", "The Queen's Lullaby", 58, 3, "F", 3, "aeolian", 1609,
                 tempo=[(0, 56), (3 * 8, 58), (3 * 36, 60), (3 * 44, 56), (3 * 52, 50), (3 * 57, 44)],
                 breathe=0.025, reverb=(3.8, 0.7), predelay=0.035, target=0.132, humanize=0.02)
        CALL = ["5,:1 1:2", "4:3", "3:1.5 2:0.5 1:1", "1:3"]
        ANS = ["1:1 3:1 5:1", "6:2 5:1", "4:1.5 3:0.5 2:1", "1:3"]
        A = CALL + ANS
        Ac = ["Fm", "Fm", "Bbm", "Fm", "Fm", "Db", "Eb", "Fm"]
        B = ["5:2 6:1", "5:2 4:1", "3:2 4:1", "5:3", "6:1.5 5:0.5 4:1", "3:1 2:1 7,:1", "1:2 2:1", "1:3"]
        Bc = ["Db", "Db", "Ab", "Ab", "Db", "Eb", "Bbm", "Fm"]
        ROCK = "1:2 5,:1"
        T0 = s.pitch(0)
        N = 57

        def rock(b, chords, v):
            o_bass(s, "log", b, chords, ROCK, v, 41, 0.3, 0.4, 0.95)
            o_bass(s, "lowstr", b, chords, "1:3", v * 0.8, 29, -0.2, 0.4, 0.99)

        bed(s, 0, N, (0, 1), (1, 2), (0, 1), 0.8)
        drone(s, 0, N - 3, T0 - 12, "throat", 0.16, 4)
        o_pad(s, "chorus_o", 0, ["Fm"], 0.24, 53, 3, 0.0, 0.7, 0.6, each=4, shape="swell")
        s.mel("boneflute", 2, ["5,:1 1:2", "4:3"], 0.32, 1, 0.5, 0.75)
        # the call, plainly
        rock(4, Ac, 0.3)
        o_pad(s, "chorus_o", 4, Ac, 0.18, 53, 3, 0.0, 0.7, 0.6)
        s.mel("boneflute", 4, A, 0.5, 1, -0.2, 0.55)
        # the choir hums it; the flute floats a third above in the second half
        rock(12, Ac, 0.32)
        s.mel("chorus_o", 12, A, 0.44, 0, 0.1, 0.6, legato=1.0)
        s.mel("boneflute", 16, ANS, 0.38, 1, -0.35, 0.6, dshift=2)
        o_bass(s, "lowstr", 12, Ac, "1:3", 0.28, 29, -0.2, 0.4)
        # the Queen's own verse: low voices, a halo of tremolo strings
        rock(20, Bc, 0.32)
        o_pad(s, "trem", 20, Bc, 0.1, 63, 3, -0.2, 0.6, 0.6, shape="arc")
        s.mel("chorus_u", 20, B, 0.48, 0, 0.0, 0.6, legato=1.0)
        s.mel("choir_u", 20, B, 0.3, -1, 0.2, 0.6, legato=1.0)
        s.hit("G", s.bar(20), 0.22)
        # the call in canon: flute, and the choir one bar behind
        rock(28, Ac, 0.32)
        o_pad(s, "chorus_o", 28, Ac, 0.16, 53, 3, 0.0, 0.7, 0.6)
        s.mel("boneflute", 28, A, 0.5, 1, -0.3, 0.55)
        s.mel("choir_u", 29, A[:7] + ["1:2 r:1"], 0.38, 0, 0.3, 0.6)
        # the verse on the flute, the strings swell beneath it
        rock(36, Bc, 0.34)
        o_pad(s, "strings", 36, Bc, 0.2, 56, 3, -0.2, 0.6, 0.6, shape="arc")
        o_pad(s, "chorus_o", 36, Bc, 0.2, 53, 3, 0.0, 0.7, 0.6)
        s.mel("boneflute", 36, B, 0.52, 1, -0.2, 0.55)
        s.mel("strings", 36, B, 0.3, 0, 0.3, 0.55, legato=1.0, dshift=-2)
        s.hit("G", s.bar(40), 0.25)
        # the last time, slower: the throat low, the flute alone with the call, the answer left open
        rock(44, Ac[:4] + ["Fm", "Db", "Eb", "Eb"], 0.28)
        s.mel("throat", 44, CALL, 0.26, 0, 0.0, 0.5)
        s.mel("boneflute", 44, CALL + ["1:1 3:1 5:1", "6:2 5:1", "4:3", "r:3"], 0.46, 1, -0.2, 0.6)
        o_pad(s, "chorus_o", 44, Ac[:4] + ["Fm", "Db", "Eb", "Eb"], 0.15, 53, 3, 0.0, 0.7, 0.6)
        # asleep: the head of the call, and the tonic
        s.mel("boneflute", 52, ["5,:1 1:2", "4:3", "r:3"], 0.38, 1, -0.3, 0.7)
        s.mel("chorus_o", 54, ["3:1.5 2:0.5 1:1", "1:3"], 0.4, 0, 0.1, 0.65, legato=1.0)
        o_pad(s, "chorus_o", 55, ["Fm"], 0.2, 53, 3, 0.0, 0.7, 0.65, each=2, shape="dim")
        s.note("lowstr", s.bar(55), 6, T0 - 24, 0.28, 0.2, 0.5, "dim")
        s.hit("G", s.bar(55), 0.2)
        return s

    def drowned():
        """Night over a sunken forest: the call turned upside down, a lament, one slow swell and silence."""
        s = song("brood_peace_7", "Night over the Drowned Wood", 54, 6, "G", 3, "phrygian", 1610, acc=1,
                 tempo=[(0, 52), (6 * 14, 54), (6 * 19, 56), (6 * 24, 50), (6 * 28, 44)], breathe=0.02,
                 reverb=(4.4, 0.75), predelay=0.04, target=0.12, humanize=0.02)
        INV = ["4:2 1:2 5,:2", "6,:1 7,:1 1:4"]           # the call, upside down
        CALL = ["5,:2 1:2 4:2", "3:1 2:1 1:4"]
        L = ["1:3 2:1 3:2", "4:4 3:2", "2:2 1:2 7,:2", "1:6"]
        Lc = ["G#m", "C#m", "A", "G#m"]
        L2 = ["5:3 6:1 5:2", "4:4 3:2", "2:3 3:1 2:2", "1:6"]
        L2c = ["E", "C#m", "A", "G#m"]
        T0 = s.pitch(0)
        N = 29
        # the frogs, slow bubbles, a far bullroarer, a cluster of strings (a minor second rubbing)
        s.scatter(0, N, 1, 3, lambda bt, r: s.hit("q", bt, r.uniform(0.18, 0.38), r.uniform(-0.8, 0.8), 0.5), 1.0)
        bed(s, 0, N, (1, 3), (1, 3), (0, 0), 0.9)
        s.note("bullroar", s.bar(1), 6 * 4, T0, 0.3, -0.6, 0.7, "arc")
        for m, p in ((T0 + 12, -0.3), (s.pitch(1) + 12, 0.3), (s.pitch(4) + 12, 0.0)):
            s.note("trem", 0, 6 * 3, m, 0.1, p, 0.6, "arc")
        drone(s, 0, N - 2, T0 - 12, "throat", 0.16, 3)
        # the upside-down call, with its echo across the water
        o_pad(s, "chorus_o", 3, ["G#m", "G#m", "A", "G#m"], 0.16, 55, 3, 0.0, 0.7, 0.65)
        s.mel("boneflute", 3, INV + INV, 0.5, 1, -0.3, 0.55)
        s.mel("boneflute", 3, ["r:1.5 4:2 1:2.5", "r:6"] * 2, 0.24, 1, 0.6, 0.85)
        # the lament: the throat choir in slow chords
        o_pad(s, "chorus_u", 7, Lc, 0.3, 47, 3, 0.0, 0.7, 0.6, shape="arc")
        o_bass(s, "lowstr", 7, Lc, "1:6", 0.3, 32, 0.25, 0.4)
        s.mel("choir_u", 7, L, 0.36, 0, 0.0, 0.6, legato=1.0)
        s.mel("throat", 7, L, 0.22, -1, 0.0, 0.5)
        s.hit("G", s.bar(7), 0.22)
        # the call the right way up, dark in the low strings; the flute answers upside down
        s.mel("lowstr", 11, CALL, 0.42, -1, 0.25, 0.5, legato=1.0)
        s.mel("boneflute", 13, INV, 0.44, 1, -0.3, 0.6)
        o_pad(s, "chorus_o", 11, ["G#m", "G#m", "E", "G#m"], 0.16, 55, 3, 0.0, 0.7, 0.65)
        s.drums(11, 4, {"u.........u.": 0.0}, 0.2)
        # the one swell: strings sing the lament high, the choir opens, a gong
        o_pad(s, "chorus", 15, L2c + Lc[:2], 0.4, 52, 3, 0.0, 0.8, 0.6, shape="arc")
        o_bass(s, "lowstr", 15, L2c + Lc[:2], "1:6", 0.46, 32, 0.25, 0.4)
        s.mel("strings", 15, L2 + L[:2], 0.6, 1, -0.25, 0.55, legato=1.0, shape="arc", shape_min=2)
        s.mel("choir_u", 15, L2, 0.45, 0, 0.25, 0.6, legato=1.0)
        s.mel("chorus_u", 17, L[:2] + ["r:6"] * 2, 0.4, -1, -0.2, 0.6, legato=1.0)
        s.note("bullroar", s.bar(16), 6 * 3, T0 + 7, 0.3, 0.6, 0.7, "arc")
        s.hit("G", s.bar(17), 0.32)
        s.note("trem", s.bar(17), 12, s.pitch(4) + 24, 0.1, 0.3, 0.6, "arc")
        # dying away: the call slowly on the flute, the choir humming
        o_pad(s, "chorus_o", 21, ["G#m", "A", "G#m", "G#m"], 0.15, 55, 3, 0.0, 0.7, 0.65)
        s.mel("boneflute", 21, CALL + ["r:6", "5,:2 1:2 4:2"], 0.42, 1, -0.25, 0.6)
        s.mel("choir_u", 22, ["r:6", "3:2 2:2 1:2"], 0.32, 0, 0.3, 0.65)
        # the last upside-down call comes home to the tonic
        s.mel("boneflute", 25, INV, 0.4, 1, -0.2, 0.65)
        o_pad(s, "chorus_o", 26, ["G#m"], 0.18, 55, 3, 0.0, 0.7, 0.65, each=2, shape="dim")
        s.note("lowstr", s.bar(26), 11, T0 - 24, 0.24, 0.2, 0.5, "dim")
        s.hit("G", s.bar(26), 0.2)
        return s

    for f, nm in ((wakes, "brood_battle_6"), (gathers, "brood_battle_7"), (water, "brood_battle_8"),
                  (scent, "brood_battle_9"), (circling, "brood_battle_10"), (full_cry, "brood_battle_11"),
                  (war_song, "brood_battle_12"), (mouths, "brood_battle_13"), (lullaby, "brood_peace_6"),
                  (drowned, "brood_peace_7")):
        C.SONGS[nm] = f
        if nm not in C.TRACK_ORDER:
            C.TRACK_ORDER.append(nm)
