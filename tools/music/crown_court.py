"""The Crown's hand-composed court and camp pieces (registered into compose.py), 16th-18th century:
waltzes for the court (after the Bavarian court waltz and the Waltz of the Flowers) and fife-and-drum
marches for the camp (after the fife reference). Every melody is written out bar by bar.

  crown_peace_6   The Elector's Waltz           F major, 3/4
  crown_peace_7   Waltz of the Garrison Flowers A major, 3/4 (the lively one)
  crown_peace_8   Court Waltz by Candlelight    D minor, 3/4 (harpsichord and lute)
  crown_peace_9   The Colours Furled            D minor slow march: fife, muffled drum, strings
  crown_battle_6  Fifes at First Light          G major quickstep (the opening of a match)
  crown_battle_11 The Grenadiers' March         A minor quickstep with a trio in C (skirmish)
"""
import numpy as np


def register(C):
    from synth import _additive, _phase, _env, _bandpass, _t, _rng, SR
    import synth
    o_ost, o_bass, o_pad, o_timp = C.o_ost, C.o_bass, C.o_pad, C.o_timp

    def fife(freq, dur, vel=0.8):
        """A one-keyed wooden fife: thin, bright, breathy, a hard edge on the attack."""
        n_hold = int(dur * SR)
        n = n_hold + int(0.08 * SR)
        t = _t(n)
        ph = _phase(freq, n, 5.8, 0.004, 0.2)
        s = _additive(ph, [(1, 1.0, 0), (2, 0.5, 0), (3, 0.28, 0), (4, 0.12, 0), (5, 0.05, 0)], freq, t)
        breath = _bandpass(_rng.standard_normal(n), freq * 1.2, freq * 5) * 0.09
        chiff = np.exp(-t * 55) * _bandpass(_rng.standard_normal(n), 2500, 8000) * 0.2
        return (s + breath + chiff) * _env(n_hold, 0.025, 0.08, n) * vel * 0.4
    synth.INSTRUMENTS["fife"] = fife

    def song(name, title, bpm, meter, key, octv, mode, seed, **kw):
        return C.Song(name, title, bpm, meter, C.n(key, octv), mode, reverb=kw.pop("reverb", (2.2, 0.42)),
                      seed=seed, q=1.5, mastering="epic", predelay=0.02, target=kw.pop("target", 0.15), **kw)

    # ------------------------------------------------------------------------------- WALTZES
    def waltz_acc(s, b, ch, vel, rich=False, bass_inst="pizz"):
        o_bass(s, bass_inst, b, ch, "1:1", vel + 0.1, 38, 0.3, 0.2)
        o_ost(s, "strings" if rich else "pizz", b, ch, "-12", 1.0, vel, 55, 3, -0.2, 0.3, 0.55)
        if rich:
            o_pad(s, "strings", b, ch, 0.2, 55, 3, -0.3, 0.6, 0.45, shape="arc")

    def harp_arp(s, b, ch, vel=0.34):
        o_ost(s, "harp", b, ch, "012321", 0.5, vel, 55, 4, 0.35, 0.45, 1.4)

    def elector():
        s = song("crown_peace_6", "The Elector's Waltz", 112, 3, "F", 4, "ionian", 901)
        A = ["1:1 3:1 5:1", "1':2 7:1", "6:1.5 5:0.5 4:1", "3:3", "2:1 4:1 6:1", "5:2 3:1", "4:1 2:1 7,:1", "1:3"]
        Ac = ["F", "C7", "Bb", "F", "Gm", "C", "C7", "F"]
        A2 = ["5:1 1':1 3':1", "3':2 2':1", "1':1.5 7:0.5 6:1", "5:3", "6:1 1':1 4':1", "3':2 2':1", "1':1 7:1 2':1", "1':3"]
        A2c = ["F", "F", "Dm", "C", "Bb", "F", "C7", "F"]
        B = ["5:2 6:1", "5:2 3:1", "4:2 5:1", "6:3", "5:1 4:1 3:1", "2:2 3:1", "4:1 3:1 2:1", "5:3"]
        Bc = ["F", "F", "Bb", "Bb", "F", "Gm", "C7", "C"]
        T = ["1:2 3:1", "5:2 3:1", "6:1.5 5:0.5 4:1", "5:3", "4:1 6:1 1':1", "7:2 6:1", "5:1 6:1 7:1", "1':3"]
        Tc = ["Bb", "Bb", "Eb", "F", "Eb", "F7", "F7", "Bb"]
        T2 = ["3:1 5:1 1':1", "3':2 1':1", "2':1.5 1':0.5 7:1", "1':3", "6:1 1':1 3':1", "2':2 7:1", "6:1 7:1 2':1", "1':3"]
        T2c = ["Bb", "Bb", "F", "Bb", "Gm", "F7", "F7", "Bb"]
        TON = C.n("B", 3) - 1          # Bb for the trio
        b = 0
        # a harp flourish on the dominant, then the dance
        o_ost(s, "harp", b, ["C7", "C7", "C7", "C7"], "0123210123210123"[:6], 0.5, 0.38, 55, 4, 0.35, 0.45, 1.4)
        o_pad(s, "strings", b, ["C7", "C7", "C7", "C7"], 0.2, 55, 3, -0.2, 0.6, 0.45, shape="swell")
        b = 4
        for rep in range(2):             # A, A2
            for mel, ch in ((A, Ac), (A2, A2c)):
                waltz_acc(s, b, ch, 0.3 + 0.06 * rep, rich=bool(rep))
                s.mel("oboe" if rep == 0 else "flute", b, mel, 0.5, 0, -0.1, 0.35, legato=0.92)
                if rep:
                    s.mel("strings", b, mel, 0.4, 0, 0.1, 0.35, legato=0.97, dshift=-2)
                    s.mel("horns", b, mel, 0.34, -1, -0.2, 0.3, legato=0.9)
                b += 8
            if rep == 0:                 # B, twice, the second time with the horns
                for r2 in range(2):
                    waltz_acc(s, b, Bc, 0.32, rich=bool(r2))
                    harp_arp(s, b, Bc, 0.22)
                    s.mel("strings", b, B, 0.5, 0, 0.0, 0.4, legato=0.98)
                    s.mel("clar", b, B, 0.34, 0, 0.2, 0.3, legato=0.95, dshift=-2)
                    if r2:
                        s.mel("horns", b, B, 0.4, 0, -0.2, 0.3, legato=0.95)
                    b += 8
        # the trio in B flat: lighter, flute over plucked strings, then the full band
        for r2 in range(2):
            for mel, ch in ((T, Tc), (T2, T2c)):
                waltz_acc(s, b, ch, 0.28 + 0.07 * r2, rich=bool(r2))
                harp_arp(s, b, ch, 0.2)
                s.mel("flute", b, mel, 0.5, 0, -0.1, 0.4, legato=0.9, tonic=TON)
                if r2:
                    s.mel("strings", b, mel, 0.45, 0, 0.1, 0.4, legato=0.98, tonic=TON)
                    s.mel("tpts", b, mel, 0.4, 0, -0.15, 0.3, legato=0.9, tonic=TON)
                b += 8
        # last time: everything, timpani on the first beat
        for mel, ch in ((A, Ac), (A2, A2c)):
            waltz_acc(s, b, ch, 0.4, rich=True)
            o_bass(s, "lowbr", b, ch, "1:1", 0.4, 36, 0.3)
            for i, c in enumerate(ch):
                o_timp(s, s.bar(b + i), c, 0.4)
            s.mel("flute", b, mel, 0.5, 1, 0.2, 0.35, legato=0.9)
            s.mel("strings", b, mel, 0.5, 0, -0.2, 0.4, legato=0.97)
            s.mel("tpts", b, mel, 0.5, 0, 0.15, 0.3, legato=0.9)
            b += 8
        C.o_final(s, b, "F", 0.8, [("strings", 4, 7), ("horns", 4, 0), ("tpts", 3, 12)], 55, 2, 33)
        return s

    def flowers():
        s = song("crown_peace_7", "Waltz of the Garrison Flowers", 156, 3, "A", 4, "ionian", 902, reverb=(2.6, 0.45))
        A = ["1:1 5:1 3':1", "2':2 1':1", "7:1 1':1 2':1", "3':3", "4':1 3':1 2':1", "1':2 6:1", "5:1.5 4:0.5 2:1", "1:3"]
        Ac = ["A", "A", "E", "A", "D", "D", "E7", "A"]
        A2 = ["3:1 5:1 1':1", "3':2 5':1", "4':1.5 3':0.5 2':1", "1':3", "2':1 4':1 6':1", "5':2 3':1", "2':1 7:1 2':1", "1':3"]
        A2c = ["A", "A", "D", "A", "Bm", "A", "E7", "A"]
        B = ["3':2 2':1", "1':1 7:1 6:1", "7:2 1':1", "2':3", "3':2 5':1", "4':1 3':1 2':1", "3':1 2':1 1':1", "7:3"]
        Bc = ["A", "F#m", "E", "E", "A", "D", "F#m", "E"]
        T = ["5:2 3:1", "4:1 3:1 2:1", "1:2 5,:1", "6,:3", "1:1 3:1 5:1", "6:2 5:1", "4:1 6:1 1':1", "5:3"]
        Tc = ["D", "G", "D", "G", "D", "Bm", "G", "A"]
        TON = C.n("D", 4)
        b = 0
        # a harp cadenza: the flowers open
        o_ost(s, "harp", b, ["E7", "E7", "E7", "A"], "012345", 0.25, 0.4, 52, 4, 0.3, 0.5, 1.6)
        o_pad(s, "strings", b, ["E7", "E7", "E7", "A"], 0.18, 55, 3, -0.2, 0.7, 0.5, shape="swell")
        s.mel("flute", 1, ["5:1 6:1 7:1", "1':3"], 0.4, 0, 0.1, 0.4, legato=0.9)
        b = 4
        for rep in range(2):
            for mel, ch in ((A, Ac), (A2, A2c)):
                waltz_acc(s, b, ch, 0.28 + 0.06 * rep, rich=True)
                harp_arp(s, b, ch, 0.22)
                s.mel("flute" if rep == 0 else "oboe", b, mel, 0.5, 0, -0.1, 0.35, legato=0.9)
                if rep:
                    s.mel("strings", b, mel, 0.42, 1, 0.2, 0.4, legato=0.97)
                    s.mel("horns", b, mel, 0.34, -1, -0.25, 0.3, legato=0.9)
                b += 8
            waltz_acc(s, b, Bc, 0.3 + 0.06 * rep, rich=True)
            s.mel("strings", b, B, 0.5, 0, 0.0, 0.4, legato=0.98)
            s.mel("clar", b, B, 0.36, 0, 0.2, 0.3, legato=0.95, dshift=-2)
            if rep:
                s.mel("tpts", b, B, 0.36, 0, -0.15, 0.3, legato=0.9)
                for i, c in enumerate(Bc):
                    o_timp(s, s.bar(b + i), c, 0.34)
            b += 8
        # trio in D: celesta and flute over pizzicato, then the strings take it
        for r2 in range(2):
            for hi in (0, 1):
                waltz_acc(s, b, Tc, 0.26 + 0.08 * r2, rich=bool(r2))
                s.mel("flute", b, T, 0.46, hi, -0.1, 0.4, legato=0.9, tonic=TON)
                s.mel("celesta", b, T, 0.3, 1, 0.3, 0.45, legato=0.8, tonic=TON)
                if r2:
                    s.mel("strings", b, T, 0.44, 0, 0.1, 0.4, legato=0.98, tonic=TON)
                b += 8
        for mel, ch in ((A, Ac), (A2, A2c)):
            waltz_acc(s, b, ch, 0.42, rich=True)
            o_bass(s, "lowbr", b, ch, "1:1", 0.4, 36, 0.3)
            for i, c in enumerate(ch):
                o_timp(s, s.bar(b + i), c, 0.42)
            s.mel("flute", b, mel, 0.52, 1, 0.2, 0.35, legato=0.9)
            s.mel("strings", b, mel, 0.5, 0, -0.2, 0.4, legato=0.97)
            s.mel("tpts", b, mel, 0.5, 0, 0.15, 0.3, legato=0.9)
            b += 8
        C.o_final(s, b, "A", 0.8, [("strings", 4, 7), ("horns", 4, 0), ("tpts", 3, 12), ("flute", 2, 24)], 55, 2, 33)
        return s

    def candlelight():
        s = song("crown_peace_8", "Court Waltz by Candlelight", 92, 3, "D", 4, "aeolian", 903, reverb=(3.0, 0.5), target=0.14)
        A = ["5:2 3:1", "4:1 3:1 2:1", "1:2 7+,:1", "1:3", "5:2 6:1", "5:1 4:1 3:1", "2:1 7+,:1 2:1", "1:3"]
        Ac = ["Dm", "Gm", "A", "Dm", "Dm", "Gm", "A7", "Dm"]
        A2 = ["3:2 5:1", "6:2 5:1", "4:1 5:1 6:1", "5:3", "1':2 7:1", "6:1 5:1 4:1", "3:1 2:1 7+,:1", "1:3"]
        A2c = ["F", "Bb", "Gm", "A", "Dm", "Gm", "A7", "Dm"]
        B = ["5:1 1':2", "3':2 2':1", "1':1 7:1 6:1", "5:3", "4:1 6:1 1':1", "5':2 4':1", "3':1 2':1 1':1", "5:3"]
        Bc = ["F", "F", "Dm", "C", "Bb", "Bb", "F", "C7"]
        FT = C.n("F", 4)
        b = 0
        o_ost(s, "lute", b, ["Dm", "A", "Dm", "A"], "012", 1.0, 0.4, 50, 3, 0.3, 0.4, 1.0)
        s.mel("harpsi", 0, ["5:2 3:1", "4:1 3:1 2:1", "1:2 7+,:1", "1:3"], 0.34, 0, 0.2, 0.3, legato=0.9)
        b = 4
        for rep in range(2):
            for mel, ch in ((A, Ac), (A2, A2c)):
                o_bass(s, "lowstr", b, ch, "1:3", 0.3 + 0.05 * rep, 38, 0.3, 0.2)
                o_ost(s, "lute", b, ch, "-12", 1.0, 0.36, 50, 3, 0.3, 0.4, 0.95)
                o_ost(s, "harpsi", b, ch, "-21", 1.0, 0.18, 55, 3, -0.3, 0.3, 0.9)
                o_pad(s, "strings", b, ch, 0.2 + 0.06 * rep, 55, 3, -0.3, 0.6, 0.5, shape="arc")
                s.mel("oboe" if rep == 0 else "strings", b, mel, 0.5, 0, 0.0, 0.4, legato=0.97)
                if rep:
                    s.mel("horns", b, mel, 0.32, -1, -0.2, 0.3, legato=0.95)
                    s.mel("flute", b, mel, 0.34, 1, 0.3, 0.4, legato=0.9)
                b += 8
            # the major turn, in F
            o_bass(s, "lowstr", b, Bc, "1:3", 0.3, 38, 0.3, 0.2)
            o_ost(s, "lute", b, Bc, "-12", 1.0, 0.36, 50, 3, 0.3, 0.4, 0.95)
            o_pad(s, "strings", b, Bc, 0.24 + 0.06 * rep, 55, 3, -0.3, 0.6, 0.5, shape="arc")
            s.mel("flute", b, B, 0.5, 0, 0.0, 0.4, tonic=FT, mode="ionian", legato=0.95)
            if rep:
                s.mel("horns", b, B, 0.36, 0, -0.2, 0.3, tonic=FT, mode="ionian", legato=0.95)
                s.mel("strings", b, B, 0.4, 0, 0.2, 0.4, tonic=FT, mode="ionian", legato=0.98, dshift=-2)
            b += 8
        for mel, ch in ((A, Ac), (A2, A2c)):
            o_bass(s, "lowbr", b, ch, "1:3", 0.38, 36, 0.3, 0.2)
            o_ost(s, "lute", b, ch, "-12", 1.0, 0.34, 50, 3, 0.3, 0.4, 0.95)
            o_pad(s, "strings", b, ch, 0.3, 55, 3, -0.3, 0.6, 0.5, shape="arc")
            o_pad(s, "chorus", b, ch, 0.22, 57, 3, 0.0, 0.8, 0.5)
            for i, c in enumerate(ch):
                o_timp(s, s.bar(b + i), c, 0.36)
            s.mel("strings", b, mel, 0.5, 1, -0.2, 0.4, legato=0.98)
            s.mel("horns", b, mel, 0.48, 0, 0.1, 0.3, legato=0.95)
            s.mel("oboe", b, mel, 0.4, 0, 0.25, 0.4, legato=0.95)
            b += 8
        C.o_final(s, b, "Dm", 0.75, [("strings", 4, 7), ("horns", 4, 0), ("chorus", 3, 5)], 52, 2, 33)
        return s

    # ------------------------------------------------------------------------------- FIFE AND DRUM
    M1 = {"S.ssS.s.S.ssS.s.": 0.15, "K.......K.......": 0.0}
    M2 = {"S.ssS.ssS.ssS.ss": 0.15, "K...K...K...K...": 0.0}
    SOFT = {"..s...s...s...s.": 0.15, "K.......K.......": 0.0}
    ROLL = {"S.s.s.s.ssssssss": 0.15, "K...K...K.K.KKKK": 0.0}

    def quick_acc(s, b, ch, vel, rich=False):
        o_ost(s, "lute" if not rich else "spicc", b, ch, "0201", 1.0, vel, 50, 3, -0.2, 0.2, 0.7)
        o_bass(s, "lowstr" if rich else "pizz", b, ch, "1:1 5,:1 1:1 5,:1", vel + 0.08, 36, 0.3, 0.2)

    def timps(s, b, ch, v):
        for i, c in enumerate(ch):
            o_timp(s, s.bar(b + i), c, v)
            o_timp(s, s.bar(b + i) + 2.0, c, v * 0.7)

    def first_light():
        s = song("crown_battle_6", "Fifes at First Light", 100, 4, "G", 4, "ionian", 911, reverb=(1.8, 0.4))
        A = ["5:0.75 6:0.25 5:1 3:1 1:1", "2:0.75 3:0.25 2:1 7,:2", "5:0.75 6:0.25 5:1 3:1 5:1", "1':3 5:1",
             "6:0.75 7:0.25 1':1 7:1 6:1", "5:0.75 6:0.25 5:1 4:1 3:1", "2:1 4:1 3:1 2:1", "1:3 r:1"]
        Ac = ["G", "D", "G", "G", "Em", "C", "D7", "G"]
        B = ["3':1 3':0.5 2':0.5 1':1 5:1", "6:1 5:0.5 4:0.5 3:2", "3':1 3':0.5 2':0.5 1':1 5:1", "2':3 r:1",
             "4':1 4':0.5 3':0.5 2':1 6:1", "1':1 7:1 6:1 5:1", "2':1 1':1 7:1 2':1", "1':4"]
        Bc = ["G", "C", "G", "D", "Am", "Em", "D7", "G"]
        T = ["3:1 5:1 3':1 5':1", "4':1.5 3':0.5 2':2", "1':1 7:0.5 1':0.5 2':1 7:1", "1':4",
             "6:1 1':1 3':1 6':1", "5':1.5 4':0.5 3':2", "2':1 4':1 3':1 2':1", "1':4"]
        Tc = ["C", "F", "G", "C", "Am", "C", "G7", "C"]
        CT = C.n("C", 4)
        # a lone drum, then the fife calls the morning in
        s.roll("s", 0, 6, 0.25, 0.1, 0.5, 0.15)
        s.timp(0, 0, 0.4, -1)
        s.mel("fife", 1, ["5:0.75 6:0.25 5:1 3:1 1:1", "5:4"], 0.5, 1, 0.1, 0.3, legato=0.85)
        b = 2
        for rep in range(2):
            quick_acc(s, b, Ac, 0.3 + 0.05 * rep, bool(rep))
            s.drums(b, 8, SOFT if rep == 0 else M1, 0.4 + 0.1 * rep, fill=ROLL if rep else None)
            s.mel("fife", b, A, 0.55, 1, 0.15, 0.3, legato=0.82)
            if rep:
                s.mel("horns", b, A, 0.42, 0, -0.2, 0.3, legato=0.9, dshift=-2)
                timps(s, b, Ac, 0.45)
            b += 8
        for rep in range(2):
            quick_acc(s, b, Bc, 0.34 + 0.05 * rep, True)
            s.drums(b, 8, M1 if rep == 0 else M2, 0.5 + 0.08 * rep, fill=ROLL)
            s.mel("fife", b, B, 0.58, 1, 0.15, 0.3, legato=0.82)
            s.mel("strings", b, B, 0.42, 0, -0.2, 0.3, legato=0.95)
            if rep:
                s.mel("tpts", b, B, 0.46, 0, 0.1, 0.3, legato=0.9)
                o_bass(s, "lowbr", b, Bc, "1:2 1:2", 0.5, 36, 0.3)
            timps(s, b, Bc, 0.48 + 0.1 * rep)
            b += 8
        # the trio in C: the fife with a tabor and plucked strings only, then everyone joins
        for rep in range(2):
            quick_acc(s, b, Tc, 0.26 + 0.1 * rep, bool(rep))
            s.drums(b, 8, SOFT if rep == 0 else M1, 0.34 + 0.12 * rep)
            s.mel("fife", b, T, 0.5, 0, 0.15, 0.3, legato=0.85, tonic=CT)
            if rep:
                s.mel("horns", b, T, 0.45, 0, -0.2, 0.3, legato=0.92, tonic=CT)
                s.mel("strings", b, T, 0.4, 0, 0.2, 0.3, legato=0.96, tonic=CT, dshift=-2)
                timps(s, b, Tc, 0.5)
            b += 8
        # the last strain, full
        quick_acc(s, b, Ac, 0.42, True)
        s.drums(b, 8, M2, 0.6, fill=ROLL)
        timps(s, b, Ac, 0.6)
        o_bass(s, "lowbr", b, Ac, "1:2 1:2", 0.55, 36, 0.3)
        o_pad(s, "chorus", b, Ac, 0.3, 57, 3, 0.0, 0.8, 0.5)
        s.mel("fife", b, A, 0.6, 1, 0.15, 0.3, legato=0.82)
        s.mel("tpts", b, A, 0.55, 0, 0.1, 0.3, legato=0.9)
        s.mel("horns", b, A, 0.5, 0, -0.2, 0.3, legato=0.92)
        s.mel("strings", b, A, 0.5, 1, -0.3, 0.3, legato=0.96)
        b += 8
        C.o_crash(s, s.bar(b), 0.8, "b")
        C.o_final(s, b, "G", 0.8, [("horns", 4, 0), ("strings", 4, 7), ("tpts", 3, 12)], 52, 2, 31)
        return s

    def grenadiers():
        s = song("crown_battle_11", "The Grenadiers' March", 132, 4, "A", 4, "aeolian", 912, reverb=(1.6, 0.4), target=0.16)
        A = ["1:1 1:0.5 3:0.5 5:1 3:1", "6:1 5:0.5 4:0.5 3:2", "4:1 4:0.5 6:0.5 1':1 6:1", "5:3 r:1",
             "3':1 3':0.5 2':0.5 1':1 5:1", "6:1 5:0.5 4:0.5 3:1 2:1", "3:1 2:1 7+,:1 2:1", "1:3 r:1"]
        Ac = ["Am", "F", "Dm", "E", "Am", "F", "E7", "Am"]
        B = ["5:1 5:0.5 5:0.5 1':1 5:1", "3':1.5 2':0.5 1':2", "6:1 6:0.5 6:0.5 4':1 6:1", "5:3 r:1",
             "7:1 7:0.5 7:0.5 2':1 7:1", "6:1.5 5:0.5 4:2", "3:1 4:1 5:1 7:1", "1':3 r:1"]
        Bc = ["C", "C", "F", "G", "G", "F", "G7", "C"]
        CT = C.n("C", 4)
        s.roll("s", 0, 8, 0.25, 0.15, 0.7, 0.15)
        o_timp(s, 0, "Am", 0.6)
        o_timp(s, s.bar(1), "E", 0.7)
        b = 2
        for rep in range(2):
            quick_acc(s, b, Ac, 0.34 + 0.06 * rep, True)
            s.drums(b, 8, M1 if rep == 0 else M2, 0.5 + 0.06 * rep, fill=ROLL)
            timps(s, b, Ac, 0.5 + 0.1 * rep)
            s.mel("fife", b, A, 0.55, 1, 0.15, 0.3, legato=0.82)
            s.mel("horns", b, A, 0.5, 0, -0.15, 0.3, legato=0.9)
            if rep:
                s.mel("tpts", b, A, 0.5, 0, 0.1, 0.3, legato=0.9, dshift=2)
                o_bass(s, "lowbr", b, Ac, "1:2 1:2", 0.5, 36, 0.3)
            b += 8
        for rep in range(2):
            quick_acc(s, b, Bc, 0.38 + 0.06 * rep, True)
            s.drums(b, 8, M2, 0.56 + 0.06 * rep, fill=ROLL)
            timps(s, b, Bc, 0.55 + 0.1 * rep)
            s.mel("strings", b, B, 0.52, 1, -0.2, 0.3, legato=0.96, tonic=CT)
            s.mel("fife", b, B, 0.5, 1, 0.2, 0.3, legato=0.82, tonic=CT)
            s.mel("horns", b, B, 0.5, 0, -0.1, 0.3, legato=0.9, tonic=CT)
            if rep:
                s.mel("tpts", b, B, 0.5, 0, 0.1, 0.3, legato=0.9, tonic=CT)
                C.o_crash(s, s.bar(b), 0.7, None)
            b += 8
        # the drums alone, the fife over them: the column halts and re-forms
        s.drums(b, 4, ROLL, 0.55)
        o_timp(s, s.bar(b), "Am", 0.7)
        s.mel("fife", b, ["5:0.5 5:0.5 5:1 3:1 1:1", "2:1 3:1 5:2", "5:0.5 5:0.5 5:1 6:1 1':1", "7:4"], 0.55, 1, 0.15, 0.3, legato=0.8)
        b += 4
        quick_acc(s, b, Ac, 0.46, True)
        s.drums(b, 8, M2, 0.64, fill=ROLL)
        timps(s, b, Ac, 0.7)
        o_bass(s, "lowbr", b, Ac, "1:2 1:2", 0.58, 36, 0.3)
        o_pad(s, "chorus", b, Ac, 0.3, 57, 3, 0.0, 0.8, 0.5)
        s.mel("fife", b, A, 0.6, 1, 0.15, 0.3, legato=0.82)
        s.mel("tpts", b, A, 0.58, 0, 0.1, 0.3, legato=0.9)
        s.mel("horns", b, A, 0.52, 0, -0.2, 0.3, legato=0.92)
        s.mel("strings", b, A, 0.5, 1, -0.3, 0.3, legato=0.96)
        b += 8
        C.o_crash(s, s.bar(b), 0.8, "b")
        C.o_final(s, b, "Am", 0.8, [("horns", 4, 0), ("strings", 4, 7), ("tpts", 3, 12)], 52, 2, 33)
        return s

    def furled():
        s = song("crown_peace_9", "The Colours Furled", 68, 4, "D", 4, "aeolian", 913, reverb=(3.2, 0.5), target=0.13)
        A = ["1:2 3:2", "5:3 4:1", "3:2 2:2", "1:4", "5:2 6:2", "1':3 7:1", "6:2 5:2", "5:4"]
        Ac = ["Dm", "Dm", "Gm", "Dm", "Bb", "F", "Gm", "A"]
        B = ["3':2 2':2", "1':3 7:1", "6:2 5:2", "4:2 3:2", "2:2 4:2", "6:2 5:2", "7+,:2 2:2", "1:4"]
        Bc = ["F", "F", "Bb", "Gm", "Gm", "Bb", "A", "Dm"]
        MUFFLE = {"K...............": 0.0, "..............s.": 0.0}
        o_pad(s, "strings", 0, ["Dm", "Dm"], 0.22, 52, 3, -0.2, 0.6, 0.5, shape="swell")
        s.drums(0, 2, {"K...............": 0.0}, 0.3)
        b = 2
        for rep in range(2):
            for mel, ch in ((A, Ac), (B, Bc)):
                o_pad(s, "strings", b, ch, 0.24 + 0.08 * rep, 52, 3, -0.2, 0.6, 0.5, shape="arc")
                o_bass(s, "lowstr", b, ch, "1:4", 0.34 + 0.06 * rep, 36, 0.3, 0.2)
                s.drums(b, 8, MUFFLE, 0.34 + 0.08 * rep)
                s.mel("fife" if rep == 0 else "strings", b, mel, 0.5, 1 if rep == 0 else 0, 0.1, 0.4, legato=0.96)
                if rep:
                    s.mel("horns", b, mel, 0.4, 0, -0.2, 0.3, legato=0.97, dshift=-2)
                    s.mel("fife", b, mel, 0.36, 1, 0.3, 0.4, legato=0.95)
                    o_pad(s, "chorus", b, ch, 0.22, 57, 3, 0.0, 0.8, 0.5)
                    for i, c in enumerate(ch):
                        o_timp(s, s.bar(b + i), c, 0.3)
                b += 8
        C.o_final(s, b, "Dm", 0.6, [("strings", 4, 7), ("horns", 3, 0), ("chorus", 3, 5)], 52, 3, 33)
        return s

    for f in (elector, flowers, candlelight, furled, first_light, grenadiers):
        nm = f.__name__
        C.SONGS[{"elector": "crown_peace_6", "flowers": "crown_peace_7", "candlelight": "crown_peace_8",
                 "furled": "crown_peace_9", "first_light": "crown_battle_6", "grenadiers": "crown_battle_11"}[nm]] = f

    for nm in ("crown_peace_6", "crown_peace_7", "crown_peace_8", "crown_peace_9", "crown_battle_6", "crown_battle_11"):
        if nm not in C.TRACK_ORDER:
            C.TRACK_ORDER.append(nm)
