"""Ten more pieces for the Clockwork (registered into compose.py), so the faction has twenty like the Crown.

Every piece is built on one short theme, the Clockwork's motif: the tonic, the fifth, the sharp fourth
and the fifth again (a tick and a tock, the escapement), then the ninth, left hanging:

    1 - 5 - #4 - 5 - 9          in C: C G F# G D'      (in semitones from the tonic: 0 7 6 7 14)

A music box plays it plainly in the calm pieces, the machine repeats and shifts it in the skirmishes,
and the full orchestra hammers it in the battles (there its last note falls to the flat ninth, 13).
The pieces are played dead on the grid (no human timing), in odd and shifting meters, with the owner's
recordings of clocks, a bell, clangs, a typewriter, a crank and a spring as percussion (clock_kit.py).

  clock_battle_6   The Great Escapement          B minor, 4/4, 96        opening: gears engage one by one
  clock_battle_7   Calibration                   E flat lydian, 5/4, 104 opening: the instruments tuned
  clock_battle_8   Tick, Tock, Alarm             D harmonic minor, 4/4   skirmish: an ostinato that shifts a note at a time
  clock_battle_9   The Watchful Gear             F sharp phrygian, 11/8  skirmish: a sentry gear scanning
  clock_battle_10  Pressure Rising               B flat minor, 9/8       skirmish: the gauge climbs a semitone at a time
  clock_battle_11  Cathedral of Gears            C sharp minor, 5/4 + 6/4  battle: organ, choir, change-ringing bells
  clock_battle_12  Anvil Chorus of a Thousand Hands  A phrygian, 7/8 and 8/8  battle: interlocking anvils
  clock_battle_13  The Grand Calculation         G sharp minor, 4/4 7/8 5/4 3/4  battle: the motif in every form at once
  clock_peace_6    The Clockmaker's Lament       F minor, 4/4, 60        calm: a music box in an empty workshop
  clock_peace_7    Canon of Perfect Order        D flat lydian, 3/2, 72  calm: one tune at three speeds

Roles (scripts/music.gd): clock_battle_6/7 "open", clock_battle_8/9/10 "skirmish"; 11-13 are the full
battle; the peace pieces are calm. Details, piece by piece: docs/music_clockwork.md.
Every piece is mastered to the loudness of the rest of the soundtrack (about -12.5 LUFS, see CSong).
"""
import os
import re
import subprocess
import tempfile
import wave

import numpy as np

MOT = [(0, 1.0), (7, 1.0), (6, 0.5), (7, 0.5), (14, 2.0)]      # the Clockwork's motif: semitones, beats
LUFS_GOAL = -12.5


def register(C):
    import synth
    import orchestra
    import clock_kit
    from synth import SR, _t, _noise, _bandpass, _lowpass, VOWEL_O
    from orchestra import voicing, bass_of, chord, rel_interval
    clock_kit.register()

    # ------------------------------------------------------------------ two more timbres
    def mchoir(freq, dur, vel=0.7):
        """A choir of brass pipes: voices on 'o' with no vibrato and no drift, pulsing at 7 a second."""
        h = orchestra._harmonics(freq, 5000)
        amps = [synth._formant_weight(k * freq, VOWEL_O) / k ** 0.25 for k in range(1, h + 1)]
        s = orchestra._section(freq, dur, amps, ("mch", int(freq * 4)), 4, 0.0011, 0.14, 0.6, 4600,
                               vib=(5.0, 0.0), drift=0.0, smear=0.0)
        t = _t(len(s))
        s *= 0.88 + 0.12 * np.sign(np.sin(2 * np.pi * 7.0 * t))
        return _lowpass(s, 4200) * vel * 0.34

    def glassharm(freq, dur, vel=0.7):
        """A glass harmonica: two nearly equal sines that beat slowly, a faint octave, a soft rim."""
        nh = int(dur * SR)
        n = nh + int(0.5 * SR)
        t = _t(n)
        s = np.sin(2 * np.pi * freq * t) + 0.8 * np.sin(2 * np.pi * (freq + 0.7) * t + 1.0)
        s += 0.18 * np.sin(4 * np.pi * freq * t) + 0.05 * np.sin(6 * np.pi * freq * t)
        s += _bandpass(_noise(n), freq * 1.5, min(freq * 6, 12000)) * 0.03
        return s * orchestra._adsr(nh, n, 0.18, 0.45) * vel * 0.16

    synth.INSTRUMENTS.update({"mchoir": mchoir, "glassharm": glassharm})

    # ------------------------------------------------------------------ the song, mastered to the others' loudness
    def lufs(L, R):
        fd, path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        with wave.open(path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(np.stack([L, R], 1), -1, 1) * 32767).astype(np.int16).tobytes())
        out = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                             capture_output=True, text=True).stderr
        os.remove(path)
        m = re.findall(r"I:\s+(-?[\d.]+) LUFS", out)
        return float(m[-1]) if m else -20.0

    class CSong(C.Song):
        def __init__(self, name, title, bpm, meter, tonic, mode, seed, reverb=(1.8, 0.35), lufs=LUFS_GOAL,
                     target=0.15):
            super().__init__(name, title, bpm, meter, tonic, mode, reverb=reverb, humanize=0.0, seed=seed, q=1.5,
                             mastering="epic", predelay=0.015, target=target)
            self.goal = lufs

        def mix(self):
            synth.clear_cache()
            end = max(e[0] + e[4] for e in self.ev) + 4.0
            L = np.zeros(int(end * SR) + SR)
            R = np.zeros_like(L)
            send = np.zeros_like(L)
            for e in self.ev:
                t0, kind, inst, midi, dur, vel, pan, snd = e[:8]
                x = synth.render_note(inst, midi, dur, vel) if kind == "n" else synth.render_drum(inst, vel)
                if len(e) > 8:
                    x = x * C._shape_curve(e[8], len(x), dur)
                i = int(t0 * SR)
                x = x[: len(L) - i]
                a = (pan + 1) * np.pi / 4
                L[i:i + len(x)] += x * np.cos(a)
                R[i:i + len(x)] += x * np.sin(a)
                send[i:i + len(x)] += x * snd
            send = np.concatenate([np.zeros(int(self.predelay * SR)), send])[:len(L)]
            ir = synth.reverb_ir(*self.reverb)
            return synth.apply_reverb(L, R, send, ir)

        def render(self):
            L0, R0 = self.mix()
            tgt = self.target
            for _ in range(4):
                L, R = orchestra.master_epic(L0.copy(), R0.copy(), tgt, 0.84)
                got = lufs(L, R)
                if abs(got - self.goal) < 0.25:
                    break
                tgt *= 10 ** ((self.goal - got) / 20)
            self.measured = got
            return L, R

    # ------------------------------------------------------------------ writing on absolute beats
    def total(notes):
        return sum(float(tok.split(":")[1]) for tok in notes.split())

    def line(s, inst, beat, notes, vel=0.6, octave=0, pan=0.0, send=0.3, legato=0.95, tonic=None, mode=None,
             dshift=0, shape=None, shape_min=2.0, scale=1.0, accent=0.05):
        """A melody in scale degrees ('1:1 5:0.5 4+:0.5 2\\':2 r:1') from an absolute beat."""
        for off, dur, di, acc in s.parse(notes):
            strong = off % 1 == 0
            s.note(inst, beat + off * scale, dur * scale * legato,
                   s.pitch(di + dshift, acc, tonic, mode) + 12 * octave,
                   vel + (accent if strong else 0), pan, send, shape if dur * scale >= shape_min else None)
        return beat + total(notes) * scale

    def semis(s, inst, beat, notes, vel=0.6, base=0, pan=0.0, send=0.3, legato=0.95, shape=None, shape_min=2.0,
              scale=1.0, tonic=None):
        """A melody in semitones from the tonic: [(semitones or None for a rest, beats), ...]."""
        t0 = s.tonic if tonic is None else tonic
        b = beat
        for st, d in notes:
            if st is not None:
                s.note(inst, b, d * scale * legato, t0 + base + st, vel, pan, send,
                       shape if d * scale >= shape_min else None)
            b += d * scale
        return b

    def motif(s, inst, beat, vel=0.6, base=0, scale=1.0, end=None, last=14, rhythm=None, **kw):
        """The motif; `last` its final note (14 the ninth, 13 the flat ninth, 12 resolved), `end` notes after it,
        `rhythm` other durations for its five notes."""
        rh = rhythm or [d for _, d in MOT]
        notes = [(st, d) for (st, _), d in zip(MOT, rh)]
        notes[-1] = (last, notes[-1][1])
        return semis(s, inst, beat, notes + (end or []), vel, base, scale=scale, **kw)

    def drum(s, beat, pat, step, vel, pan=0.0, send=0.12, reps=1, acc=None, accent=0.1):
        """A drum line: one code per step, '.' a rest; acc marks accents with '>' (default: the first step)."""
        k = 0
        for r in range(reps):
            for i, c in enumerate(pat):
                if c != ".":
                    a = accent if ((acc[i % len(acc)] == ">") if acc else i == 0) else 0.0
                    s.hit(c, beat + k * step, vel + a, pan, send)
                k += 1
        return beat + k * step

    def fill(s, beat, beats, pat, step, vel, pan=0.0, send=0.12, acc=None, accent=0.1):
        """A drum pattern repeated to fill `beats` (the last repeat cut short)."""
        k = 0
        while k * step < beats - 1e-6:
            c = pat[k % len(pat)]
            if c != ".":
                i = k % len(pat)
                a = accent if ((acc[i % len(acc)] == ">") if acc else i == 0) else 0.0
                s.hit(c, beat + k * step, vel + a, pan, send)
            k += 1
        return beat + beats

    def pad(s, inst, beat, dur, c, vel, center, count=3, pan=0.0, spread=0.5, send=0.45, shape=None, legato=0.99,
            octave=0):
        ms = voicing(c, center, count)
        for k, m in enumerate(ms):
            p = pan + (k / (len(ms) - 1) - 0.5) * spread if len(ms) > 1 else pan
            s.note(inst, beat, dur * legato, m + 12 * octave, vel, p, send, shape)
        return beat + dur

    def ost(s, inst, beat, dur, c, pattern, step, vel, center, count=4, pan=0.0, send=0.25, legato=0.9, acc=None,
            accent=0.08):
        """An ostinato on the chord's tones (digits index the voicing, past `count` an octave up)."""
        ms = voicing(c, center, count)
        k = 0
        while k * step < dur - 1e-6:
            p = pattern[k % len(pattern)]
            if p != "-":
                d = int(p)
                m = ms[d % len(ms)] + 12 * (d // len(ms))
                i = k % len(pattern)
                a = accent if ((acc[i % len(acc)] == ">") if acc else i == 0) else 0.0
                s.note(inst, beat + k * step, step * legato, m, vel + a, pan, send)
            k += 1
        return beat + dur

    def bass(s, inst, beat, dur, c, rhythm, vel, lo=36, pan=0.2, send=0.2, legato=0.92, shape=None):
        """A line on the chord (1 3 5 7 8, ',' and \"'\" octaves), its rhythm repeated to fill `dur`."""
        r, iv, _ = chord(c)
        root = lo + (r - lo) % 12
        toks = [(t.split(":")[0], float(t.split(":")[1])) for t in rhythm.split()]
        b = beat
        while b < beat + dur - 1e-6:
            for tok, d in toks:
                if b >= beat + dur - 1e-6:
                    break
                d2 = min(d, beat + dur - b)
                if tok != "r":
                    m = bass_of(c, lo) + 12 * (tok.count("'") - tok.count(",")) if tok.strip("',") == "1" else \
                        root + rel_interval(tok, iv)
                    s.note(inst, b, d2 * legato, m, vel, pan, send, shape)
                b += d
        return beat + dur

    def prog(beat, items, fn):
        """Run fn(beat, dur, chord, index) over [(chord, dur), ...]; returns the end beat."""
        for i, (c, d) in enumerate(items):
            fn(beat, d, c, i)
            beat += d
        return beat

    def timp(s, beat, c, vel, lo=38):
        s.note("timpani", beat, 1.0, bass_of(c, lo) if isinstance(c, str) else c, vel, -0.1, 0.25)

    def troll(s, beat, beats, c, v0, v1, lo=38):
        m = bass_of(c, lo) if isinstance(c, str) else c
        step = s.bpm / 60.0 / 13.0
        k = max(2, int(beats / step))
        for i in range(k):
            s.note("timpani", beat + i * step, 1.0, m, (v0 + (v1 - v0) * i / (k - 1)) * 0.35, -0.1, 0.25)

    def swell(s, beat, beats, vel=0.6):
        s.note("cymswell", beat, beats, 60, vel, 0.25, 0.5)

    def crash(s, beat, vel=0.75, drum="m"):
        s.hit("Y", beat, vel, 0.3, 0.4)
        if drum:
            s.hit(drum, beat, vel, 0.0, 0.25)

    def final(s, beat, dur, c, vel, insts, bass_lo=36):
        for inst, center, cnt in insts:
            pad(s, inst, beat, dur, c, vel, center, cnt, 0.0, 0.7, 0.5, legato=0.97)
        bass(s, "lowbr", beat, dur, c, "1:%g" % dur, vel * 0.85, bass_lo, 0.2, 0.25, 0.97)
        bass(s, "lowstr", beat, dur, c, "1:%g" % dur, vel * 0.8, bass_lo, 0.3, 0.3, 0.97)
        timp(s, beat, c, vel)

    H = dict(line=line, semis=semis, motif=motif, drum=drum, fill=fill, pad=pad, ost=ost, bass=bass, prog=prog,
             timp=timp, troll=troll, swell=swell, crash=crash, final=final, CSong=CSong, n=C.n)
    pieces = {}
    define(H, pieces)
    for name, f in pieces.items():
        C.SONGS[name] = f
        if name not in C.TRACK_ORDER:
            C.TRACK_ORDER.append(name)


# =========================================================================== the pieces

def define(H, pieces):
    line, semis, motif, drum, fill = H["line"], H["semis"], H["motif"], H["drum"], H["fill"]
    pad, ost, bass, prog = H["pad"], H["ost"], H["bass"], H["prog"]
    timp, troll, swell, crash, final = H["timp"], H["troll"], H["swell"], H["crash"], H["final"]
    CSong, n = H["CSong"], H["n"]

    def piece(name):
        def deco(f):
            pieces[name] = f
            return f
        return deco

    # ------------------------------------------------------------------ OPENING 1
    @piece("clock_battle_6")
    def escapement():
        """B minor, 4/4, 96. The great machine winds up: one gear engages after another, each turning in its
        own cycle (3, 5 and 4 eighths against the bar), the motif passed from the music box to the horns."""
        s = CSong("clock_battle_6", "The Great Escapement", 96, 4, n("B", 3), "aeolian", 1601, reverb=(2.0, 0.38))
        # the clock that never stops (until the very end): tick, tock on every beat
        fill(s, 0, 288, "Oo", 1.0, 0.42, pan=0.3, acc=">.")
        # bars 0-3: the key is turned
        s.hit("L", 0, 0.6, -0.2, 0.45)
        for b in (6, 14):
            s.hit("n", b, 0.45, 0.4, 0.2)
        s.note("lowstr", 4, 12, 35, 0.3, 0.0, 0.3, "swell")
        s.note("springres", 8, 6, 59, 0.4, -0.35, 0.5)
        # bars 4-11: the first gear: the music box plays the motif, plainly
        b = motif(s, "musicbox", 16, 0.5, base=12, end=[(12, 1), (10, 1), (7, 2)], pan=0.2, send=0.35)
        semis(s, "glass", 26, [(18, 0.5), (19, 0.5)], 0.3, base=12, pan=-0.3, send=0.5)
        motif(s, "musicbox", 32, 0.48, base=19, end=[(12, 1), (10, 1), (8, 1), (7, 2)], pan=0.2, send=0.35)
        def calm(bt, d, c, i):
            pad(s, "regal", bt, d, c, 0.13, 54, 3, 0.0, 0.5, 0.4)
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.26, 35, 0.2, 0.3)
        prog(16, [("Bm", 8), ("Bm/A", 8), ("Gmaj7", 8), ("F#sus", 4), ("F#", 4)], calm)
        # bars 12-19: the second gear, a dulcimer turning in threes against the bar
        P2 = [("Bm", 8), ("G", 8), ("Em", 8), ("F#sus", 4), ("F#", 4)]
        def gear2(bt, d, c, i, v=0.22):
            ost(s, "dulcimer", bt, d, c, "012", 0.5, v, 62, 3, -0.3, 0.25, 1.4)
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.28, 35, 0.2, 0.3)
            pad(s, "regal", bt, d, c, 0.11, 54, 3, 0.0, 0.5, 0.4)
        prog(48, P2, gear2)
        line(s, "musicbox", 48, "5:1 4+:0.5 5:0.5 3':2 2':1 1':1 7:2 6:1 5:1 4+:0.5 5:0.5 6:1 5:4 "
             "1':1 5:1 4+:0.5 5:0.5 2':1 3':2 2':1 1':1 7:1.5 6:0.5 5:1 4+:1 5:4", 0.42, 1, 0.2, 0.35)
        for b in range(48, 80, 8):
            s.hit("C", b, 0.32, -0.4, 0.3)
        # bars 20-27: the third gear: plucked basses in fives; the motif in canon, celesta and music box
        P3 = [("Bm", 8), ("Bm/A", 8), ("Gmaj7", 8), ("C#dim", 4), ("F#", 4)]
        def gear3(bt, d, c, i):
            ost(s, "dulcimer", bt, d, c, "012", 0.5, 0.2, 62, 3, -0.3, 0.25, 1.4)
            bass(s, "pizz", bt, d, c, "1:1 5:0.5 1':1", 0.34, 35, 0.15, 0.2)
            pad(s, "regal", bt, d, c, 0.12, 54, 3, 0.0, 0.5, 0.4)
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.24, 35, 0.2, 0.3)
        prog(80, P3, gear3)
        motif(s, "celesta", 80, 0.42, base=12, end=[(12, 1), (10, 1), (7, 2)], pan=-0.2)
        motif(s, "musicbox", 82, 0.36, base=24, end=[(12, 1), (10, 1), (7, 2)], pan=0.3)
        motif(s, "celesta", 96, 0.42, base=19, last=13, end=[(12, 2), (11, 2)], pan=-0.2)
        motif(s, "musicbox", 98, 0.34, base=19, last=13, end=[(12, 2), (11, 2)], pan=0.3)
        s.hit("n", 94, 0.4, 0.4)
        # bars 28-35: the fourth gear: bows and typewriter keys in sixteenths; the horns take the motif, slowly
        P4 = [("Bm", 8), ("Bm/A", 8), ("G", 8), ("F#", 8)]
        def gear4(bt, d, c, i):
            ost(s, "dulcimer", bt, d, c, "012", 0.5, 0.2, 62, 3, -0.3, 0.25, 1.4)
            bass(s, "pizz", bt, d, c, "1:1 5:0.5 1':1", 0.34, 35, 0.15, 0.2)
            ost(s, "spicc", bt, d, c, "0102", 0.25, 0.2, 50, 3, 0.3, 0.15, acc=">...")
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.3, 35, 0.2, 0.3)
            timp(s, bt, c, 0.3)
        prog(112, P4, gear4)
        fill(s, 112, 64, "f..f..f.f..f..f.", 0.25, 0.3, pan=-0.45)
        motif(s, "horns", 112, 0.42, base=0, scale=2, end=[(12, 4), (10, 2), (7, 2)], pan=-0.15)
        motif(s, "horns", 130, 0.44, base=7, scale=1.4, last=13, end=[(11, 3)], pan=-0.15)
        # bars 36-43: all four turning; the strings sing the motif and then its mirror; a cymbal swells
        P5 = [("Gmaj7", 8), ("Em", 4), ("Cmaj7", 4), ("G", 4), ("F#sus", 4), ("F#7", 8)]
        def all4(bt, d, c, i):
            ost(s, "dulcimer", bt, d, c, "012", 0.5, 0.22, 62, 3, -0.3, 0.25, 1.4)
            bass(s, "pizz", bt, d, c, "1:1 5:0.5 1':1", 0.36, 35, 0.15, 0.2)
            ost(s, "spicc", bt, d, c, "0102", 0.25, 0.24, 50, 3, 0.3, 0.15, acc=">...")
            pad(s, "mchoir", bt, d, c, 0.2, 55, 3, 0.0, 0.6, 0.5)
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.34, 35, 0.2, 0.3)
            timp(s, bt, c, 0.34)
        prog(144, P5, all4)
        fill(s, 144, 32, "f..f..f.f..f..f.", 0.25, 0.32, pan=-0.45)
        motif(s, "strings", 144, 0.5, base=12, scale=1.6, end=[(12, 2)], pan=-0.3, send=0.35, legato=1.0)
        semis(s, "strings", 160, [(0, 2), (-7, 2), (-6, 1), (-7, 1), (-14, 4), (-17, 6)], 0.52, base=24, pan=-0.3,
              send=0.35, legato=1.0)
        semis(s, "horns", 160, [(-12, 8), (-17, 8)], 0.36, base=24, pan=0.1)
        swell(s, 168, 8, 0.5)
        # bars 44-51: a breath: only the clock and the music box; the motif backwards, then ending a step too low
        pad(s, "glassharm", 176, 16, "Bm", 0.14, 62, 3, 0.0, 0.6, 0.55, shape="arc")
        semis(s, "musicbox", 176, [(14, 2), (7, 0.5), (6, 0.5), (7, 1), (0, 4)], 0.5, base=12, pan=0.2, send=0.45)
        motif(s, "musicbox", 184, 0.5, base=12, last=13, end=[(None, 3)], pan=0.2, send=0.45)
        s.hit("L", 188, 0.5, -0.2, 0.5)
        s.note("springres", 192, 8, 54, 0.32, -0.3, 0.5)
        s.note("lowstr", 192, 16, 42, 0.32, 0.0, 0.3, "swell")
        for b in (196, 200, 204):
            s.hit("n", b, 0.42, 0.4)
        s.roll("r", 200, 8, 0.25, 0.1, 0.5, -0.3)
        # bars 52-67: every gear at once, the horns and trumpets in canon; held back, never at full power
        P6 = [("Bm", 4), ("G", 4), ("D", 4), ("A", 4), ("Bm", 4), ("G", 4), ("Em", 4), ("F#", 4)]
        def full(bt, d, c, i, k):
            ost(s, "dulcimer", bt, d, c, "012", 0.5, 0.24, 62, 3, -0.3, 0.25, 1.4)
            bass(s, "pizz", bt, d, c, "1:1 5:0.5 1':1", 0.38, 35, 0.15, 0.2)
            ost(s, "spicc", bt, d, c, "0102", 0.25, 0.26 + 0.03 * k, 50, 3, 0.3, 0.15, acc=">...")
            pad(s, "mchoir", bt, d, c, 0.22 + 0.04 * k, 55, 3, 0.0, 0.6, 0.5)
            bass(s, "lowstr", bt, d, c, "1:2 5,:1 1:1", 0.38 + 0.03 * k, 35, 0.2, 0.3)
            timp(s, bt, c, 0.36 + 0.06 * k)
            timp(s, bt + 2, c, 0.26 + 0.05 * k)
            s.hit("T", bt, 0.26 + 0.06 * k, 0.0, 0.2)
        for k in (0, 1):
            b0 = 208 + 32 * k
            prog(b0, P6, lambda bt, d, c, i: full(bt, d, c, i, k))
            fill(s, b0, 32, "f..f..f.f..f..f.", 0.25, 0.34, pan=-0.45)
            for j, (base, last) in enumerate([(0, 14), (7, 14), (0, 14), (5, 14)]):
                bt = b0 + 8 * j
                motif(s, "horns", bt, 0.48 + 0.06 * k, base=base, last=last, end=[(12, 1), (10, 1), (7, 1)], pan=-0.15)
                if k:
                    motif(s, "tpts", bt + 2, 0.42, base=base + (12 if base < 5 else 0), last=last, end=[(12, 1)], pan=0.2)
            line(s, "strings", b0, "1':4 7:4 6:4 5:4 1':4 2':4 3':4 4+':4", 0.4 + 0.08 * k, 1, -0.35, 0.35,
                 legato=1.0, shape="arc", shape_min=4)
        s.hit("m", 208, 0.45, 0.0, 0.25)
        s.hit("C", 208, 0.4, -0.4, 0.3)
        s.hit("m", 240, 0.55, 0.0, 0.25)
        swell(s, 264, 8, 0.55)
        # bars 68-71: the escapement locks
        pad(s, "horns", 272, 8, "F#sus", 0.5, 54, 3)
        pad(s, "strings", 272, 4, "F#sus", 0.45, 66, 3)
        pad(s, "strings", 276, 4, "F#", 0.5, 66, 3)
        troll(s, 272, 8, "F#", 0.3, 0.8)
        s.hit("C", 272, 0.4, -0.4)
        final(s, 280, 8, "B5", 0.7, [("horns", 54, 3), ("strings", 66, 3), ("mchoir", 59, 3)], 35)
        s.hit("L", 280, 0.75, -0.2, 0.5)
        s.note("clockbell", 280, 6, 47, 0.6, 0.2, 0.5)
        s.hit("m", 280, 0.7)
        s.hit("O", 290, 0.5, 0.3, 0.3)
        return s

    # ------------------------------------------------------------------ OPENING 2
    @piece("clock_battle_7")
    def calibration():
        """E flat lydian, 5/4 (3+2), 104. The instruments are tuned against each other: a harpsichord checks
        the tritone, the motif fits one 5/4 bar exactly and climbs through the keys, the horns and a trembling
        string section push it to B major and a long dominant, then everything settles back in tune."""
        s = CSong("clock_battle_7", "Calibration", 104, 5, n("E", 4) - 1, "lydian", 1602, reverb=(2.2, 0.4))
        # bars 0-3: tuning
        for bt, m, v in [(0, 75, 0.5), (3, 75, 0.4), (5, 75, 0.5), (8, 81, 0.45), (10, 75, 0.5), (13, 81, 0.45),
                         (14, 82, 0.4), (15, 75, 0.5), (15, 82, 0.45), (18, 87, 0.4)]:
            s.note("harpsi", bt, 1.5, m, v, 0.25, 0.35)
        s.note("glassharm", 0, 19, 87, 0.3, -0.3, 0.5, "arc")
        for bt in (2, 7, 12, 17):
            s.hit("v", bt, 0.4, -0.4)
        s.hit("g", 19, 0.5, 0.4, 0.4)
        fill(s, 10, 10, "Oo", 1.0, 0.3, pan=0.35)
        # A: the motif on the harpsichord, a 3+2 dulcimer, ticking
        PA = [("Eb", 5), ("F/Eb", 5), ("Gm", 5), ("F", 5), ("Cm7", 5), ("Dm7", 5), ("Ebmaj7", 5), ("F", 5),
              ("Abmaj7", 5), ("Gm", 5), ("Fsus", 5), ("F", 5)]

        def bedA(bt, d, c, i, v=0.0, rich=False):
            ost(s, "dulcimer", bt, d, c, "0121012123", 0.5, 0.21 + v, 63, 4, -0.3, 0.25, 1.3, acc=">..>.>..>.")
            bass(s, "pizz", bt, d, c, "1:3 5,:2", 0.36 + v, 39, 0.15, 0.2)
            fill(s, bt, d, "Oooo.", 1.0, 0.3 + v, pan=0.35, acc=">..>.")
            fill(s, bt, d, "f.f.ff.f..", 0.5, 0.3 + v, pan=-0.45, acc=">..>......")
            if rich:
                pad(s, "mchoir", bt, d, c, 0.22, 55, 3, 0.0, 0.6, 0.5)
                bass(s, "lowstr", bt, d, c, "1:5", 0.36, 39, 0.2, 0.3)
                ost(s, "spicc", bt, d, c, "0102010201020102010201", 0.25, 0.24, 51, 3, 0.3, 0.15, acc=">...........>.......")
                timp(s, bt, c, 0.34)
                s.hit("C", bt, 0.38, -0.4, 0.3)
            else:
                pad(s, "strings", bt, d, c, 0.14, 58, 3, 0.0, 0.5, 0.45)

        def tune(inst, b0, vel, oc, **kw):
            """The calibration tune: the motif from five tonics, each answered (twelve bars)."""
            o = 12 * oc
            motif(s, inst, b0, vel, base=o + 12, **kw)
            line(s, inst, b0 + 5, "3:2 2:1 1:2", vel, oc + 1, **kw)
            motif(s, inst, b0 + 10, vel, base=o + 7, **kw)
            line(s, inst, b0 + 15, "4:1 3:1 2:3", vel, oc + 1, **kw)
            motif(s, inst, b0 + 20, vel, base=o + 9, **kw)
            line(s, inst, b0 + 25, "6:2 5:1 4:2", vel, oc + 1, **kw)
            motif(s, inst, b0 + 30, vel, base=o + 12, **kw)
            line(s, inst, b0 + 35, "3:1 2:1 1:1 7,:2", vel, oc + 1, **kw)
            motif(s, inst, b0 + 40, vel, base=o + 5, **kw)
            line(s, inst, b0 + 45, "2:2 1:1 7,:2", vel, oc + 1, **kw)
            motif(s, inst, b0 + 50, vel, base=o + 2, last=12, **kw)
            line(s, inst, b0 + 55, "2:5", vel, oc + 1, **kw)

        prog(20, PA, bedA)
        tune("harpsi", 20, 0.5, 0, pan=0.25, send=0.3)
        # B: the clarinet sings, the celesta answers with the motif's first three notes in stretto
        PB = [("Gm", 5), ("Ebmaj7", 5), ("Cm", 5), ("Dm", 5), ("Bb", 5), ("F/A", 5), ("Abmaj7", 5), ("Bb", 5),
              ("Gm", 5), ("Ebmaj7", 5), ("Cm7", 5), ("Bb7sus", 5)]

        def bedB(bt, d, c, i):
            bass(s, "pizz", bt, d, c, "1:3 5,:2", 0.34, 39, 0.15, 0.2)
            pad(s, "strings", bt, d, c, 0.18, 58, 3, 0.0, 0.5, 0.45)
            fill(s, bt, d, "o", 1.0, 0.3, pan=0.35)
            ost(s, "harpsi", bt, d, c, "0-1-2-1-0-", 0.5, 0.2, 63, 3, 0.35, 0.3)
        prog(80, PB, bedB)
        line(s, "clar", 80, "5:3 4:1 3:1 2:3 1:2 5:2 6:2 7:1 6:5 4:2 5:2 6:1 5:3 3:2 4-:2 3:2 1:1 2:5 "
             "5:3 6:1 7:1 1':3 7:2 6:2 5:2 3:1 4-:3 2:2", 0.5, 0, -0.15, 0.4, legato=0.98)
        for k, bt in enumerate([85, 87.5, 95, 97.5, 105, 107.5, 115, 117.5, 125, 127.5, 135, 137.5]):
            semis(s, "celesta", bt, [(0, 1), (7, 1), (6, 1)], 0.32, base=24 if k % 2 == 0 else 31, pan=0.35,
                  send=0.4)
        for bt, m in [(84, 82), (94, 79), (104, 77), (114, 82), (124, 79), (134, 77)]:
            s.note("tinebell", bt, 1.0, m, 0.4, 0.4, 0.45)
        # C: tension: the strings tremble, the horns take the motif slowly through foreign keys to a long dominant
        PC = [("Abmaj7", 10), ("Fm", 10), ("B", 10), ("Bb7sus", 10), ("Bb7", 20)]

        def bedC(bt, d, c, i):
            pad(s, "trem", bt, d, c, 0.18 + 0.07 * i, 58 + i, 3, 0.0, 0.5, 0.45, shape="swell")
            ost(s, "dulcimer", bt, d, c, "0121012123", 0.5, 0.22 + 0.02 * i, 63, 4, -0.3, 0.25, 1.3, acc=">..>.>..>.")
            bass(s, "lowstr", bt, d, c, "1:3 1:2", 0.32 + 0.04 * i, 39, 0.2, 0.3)
            fill(s, bt, d, "Oooo.", 1.0, 0.32, pan=0.35, acc=">..>.")
            for k in range(0, d, 5):
                timp(s, bt + k, c, 0.28 + 0.06 * i)
                s.hit("C" if k % 10 == 0 else "Q", bt + k, 0.3 + 0.04 * i, -0.4, 0.3)
            if i >= 2:
                ost(s, "spicc", bt, d, c, "0102", 0.25, 0.2 + 0.04 * i, 51, 3, 0.3, 0.15, acc=">...")
        prog(140, PC, bedC)
        motif(s, "horns", 140, 0.44, base=5, scale=2, pan=-0.15)
        motif(s, "horns", 150, 0.46, base=2, scale=2, pan=-0.15)
        motif(s, "horns", 160, 0.5, base=8, scale=2, pan=-0.15)
        motif(s, "horns", 170, 0.52, base=7, scale=2, pan=-0.15)
        pad(s, "horns", 180, 20, "Bb7", 0.42, 53, 4, -0.1, 0.4, 0.35, shape="swell")
        s.note("regal", 170, 30, 34, 0.38, 0.0, 0.25)
        troll(s, 190, 10, "Bb", 0.3, 0.9)
        swell(s, 192, 8, 0.6)
        s.hit("I", 199, 0.35, 0.4, 0.4)
        # A': everything, the horns with the tune, the glass two octaves above, the trumpets a beat behind
        prog(200, PA, lambda bt, d, c, i: bedA(bt, d, c, i, 0.04, True))
        tune("horns", 200, 0.56, -1, pan=-0.15, send=0.3)
        tune("glass", 200, 0.34, 1, pan=0.35, send=0.4)
        for k in range(0, 12, 2):
            base = [12, 7, 9, 12, 5, 2][k // 2]
            motif(s, "tpts", 200 + 5 * k + 1, 0.36, base=base, last=12 if k == 10 else 14, pan=0.2)
        crash(s, 200, 0.6)
        # outro: in tune
        final(s, 260, 15, "Eb", 0.62, [("horns", 55, 3), ("strings", 63, 4), ("mchoir", 58, 3)], 39)
        s.note("glassharm", 260, 15, 81, 0.35, 0.3, 0.5, "dim")
        for bt, v in [(260, 0.55), (263, 0.45), (265, 0.45), (268, 0.36), (270, 0.36), (273, 0.28)]:
            s.note("harpsi", bt, 1.5, 75, v, 0.25, 0.35)
            s.note("harpsi", bt, 1.5, 87, v * 0.7, 0.25, 0.35)
        s.hit("L", 260, 0.7, -0.2, 0.5)
        s.hit("g", 275, 0.5, 0.4, 0.4)
        fill(s, 260, 18, "Oo", 1.0, 0.28, pan=0.35)
        return s

    # ------------------------------------------------------------------ SKIRMISH 1
    @piece("clock_battle_8")
    def tick_tock_alarm():
        """D harmonic minor, 4/4, 132. An alarm clock ticks in eighths; over it an ostinato made of the motif
        changes one note every six bars, its top climbing from E to A, layer after layer joining, alarms going
        off at the turns; it never breaks into the full battle."""
        s = CSong("clock_battle_8", "Tick, Tock, Alarm", 132, 4, n("D", 4), "harmonic", 1603, reverb=(1.6, 0.32))
        V = [[0, 7, 6, 7, 14, 7, 6, 7], [0, 7, 6, 7, 15, 7, 6, 7], [0, 7, 6, 7, 15, 7, 5, 7],
             [0, 8, 6, 7, 15, 7, 5, 7], [0, 8, 6, 8, 15, 7, 5, 7], [-1, 8, 6, 8, 15, 7, 5, 7],
             [-1, 8, 5, 8, 15, 7, 5, 7], [-1, 8, 5, 8, 15, 8, 5, 7], [-1, 8, 5, 8, 17, 8, 5, 7],
             [0, 8, 5, 8, 17, 8, 5, 7], [0, 8, 5, 8, 17, 8, 5, 8], [0, 8, 5, 8, 19, 8, 5, 8],
             [1, 8, 5, 8, 19, 8, 5, 8]]
        ROOT = ["Dm", "Dm", "Bb", "Bb", "Gm", "A", "A", "A", "A", "Bb", "Gm", "E", "A"]
        fill(s, 0, 400, "Oo", 0.5, 0.46, pan=0.35, acc=">.")

        def run(inst, beat, bars, v, vel, base=0, pan=0.0, send=0.2, delay=0.0, step=0.5, rep=1):
            for b in range(bars * 8):
                for r in range(rep):
                    t = beat + delay + b * step + r * step / rep
                    s.note(inst, t, step / rep * 0.85, s.tonic + base + v[b % 8], vel + (0.06 if b % 4 == 0 else 0),
                           pan, send)

        s.note("lowstr", 0, 16, 38, 0.3, 0.0, 0.3, "swell")
        run("regal", 8, 1, V[0], 0.2, pan=-0.3)
        run("regal", 12, 1, V[0], 0.24, pan=-0.3)

        def variant(i, b0, big=0.0):
            v = V[i]
            c = ROOT[i]
            run("regal", b0, 6, v, 0.27 + 0.012 * i + big, pan=-0.3)
            bass(s, "lowstr", b0, 24, c, "1:8", 0.3 + 0.015 * i + big, 36, 0.2, 0.3)
            if i >= 1:
                run("harpsi", b0, 6, v, 0.22 + big, base=12, pan=0.3)
            if i >= 2:
                bass(s, "pizz", b0, 24, c, "1:1 1:1 5,:1 1:1", 0.32 + big, 36, 0.15, 0.2)
            if i >= 3:
                run("spicc", b0, 6, v, 0.18 + 0.01 * i + big, base=-12, pan=0.15, rep=2)
            if i >= 4:
                for k in range(0, 24, 8):
                    s.note("timpani", b0 + k, 1, 38 + (bass_pc(c) - 38) % 12, 0.3 + 0.02 * i + big, -0.1, 0.25)
            if i >= 5:
                run("dulcimer", b0, 6, v, 0.18 + big, base=12, pan=-0.45, delay=0.5)
            if i >= 6:
                fill(s, b0, 24, "v..v..v.", 0.25, 0.3 + big, pan=-0.4)
            if i >= 7:
                motif(s, "horns", b0, 0.38 + 0.02 * i + big, base=0 if c != "Bb" else 8, scale=3,
                      last=13 if i in (8, 12) else 14, pan=-0.1)
            if i >= 9:
                pad(s, "mchoir", b0, 24, c, 0.2 + big, 57, 3, 0.0, 0.6, 0.5, shape="swell")
                motif(s, "tpts", b0 + 2, 0.34 + big, base=12 if c != "Bb" else 8, scale=3,
                      last=13 if i == 12 else 14, pan=0.2)
            s.note("tinebell", b0, 1.5, s.tonic + 12 + v[4], 0.45, 0.4, 0.4)

        def bass_pc(c):
            from orchestra import bass_of as bo
            return bo(c, 38)

        b = 16
        for i in range(9):
            variant(i, b)
            if i in (4, 8):
                s.hit("I", b, 0.4, 0.45, 0.4)
            b += 24
        # the bridge: only the clock, a tolling bell, the motif muted in the horns, the strings trembling
        s.note("springres", b, 8, 62, 0.35, -0.3, 0.5)
        for k in range(0, 32, 8):
            s.note("clockbell", b + k, 4, 50, 0.45, -0.2, 0.5)
        motif(s, "horns", b + 4, 0.3, base=-12, scale=2, last=13, end=[(12, 4), (11, 6)], pan=-0.1)
        pad(s, "trem", b, 16, "Dm", 0.16, 57, 3, 0.0, 0.5, 0.45, shape="swell")
        pad(s, "trem", b + 16, 16, "A", 0.22, 57, 3, 0.0, 0.5, 0.45, shape="swell")
        s.note("lowstr", b + 16, 16, 33, 0.34, 0.0, 0.3, "swell")
        s.roll("r", b + 24, 8, 0.25, 0.1, 0.55, -0.3)
        b += 32
        for i in range(9, 13):
            variant(i, b, 0.04)
            if i == 12:
                s.hit("I", b, 0.45, 0.45, 0.4)
                swell(s, b + 16, 8, 0.5)
                troll(s, b + 16, 8, "A", 0.3, 0.8)
            b += 24
        # back to the start, quiet: the music box sings the motif, resolved
        run("regal", b, 6, V[0], 0.24, pan=-0.3)
        run("harpsi", b, 6, V[0], 0.18, base=12, pan=0.3)
        bass(s, "lowstr", b, 24, "Dm", "1:8", 0.28, 36, 0.2, 0.3)
        motif(s, "musicbox", b + 4, 0.48, base=12, last=12, end=[(10, 1), (8, 1), (7, 4)], pan=0.2, send=0.4)
        b += 24
        # the alarm runs down
        run("regal", b, 1, V[0], 0.22, pan=-0.3)
        semis(s, "regal", b + 4, [(0, 0.5), (7, 0.5), (6, 0.5), (7, 0.5), (None, 2)], 0.2, pan=-0.3)
        semis(s, "regal", b + 8, [(0, 0.5), (7, 0.5), (None, 3)], 0.18, pan=-0.3)
        s.hit("I", b + 8, 0.4, 0.45, 0.4)
        s.hit("L", b + 12, 0.55, -0.2, 0.5)
        s.note("lowstr", b + 12, 4, 38, 0.3, 0.0, 0.3, "dim")
        s.hit("O", b + 14, 0.5, 0.35)
        return s

    # ------------------------------------------------------------------ SKIRMISH 2
    @piece("clock_battle_9")
    def watchful_gear():
        """F sharp phrygian, 11/8 (3+3+3+2), eighth = 300. A sentry gear turns and scans: the bows and a dulcimer
        circle in elevens, the motif fits one bar (3+3+1+1+3) and ends on the flat ninth; it climbs a key at a
        time, then the whole guard turns out, and thins away note by note."""
        s = CSong("clock_battle_9", "The Watchful Gear", 300, 11, n("F", 3) + 1, "phrygian", 1604, reverb=(1.7, 0.33))
        OST = "1:1 5:1 8:1 1:1 5:1 9:1 1:1 5:1 8:1 "
        LAST = ["7:1 5:1", "7:1 6:1", "8:1 6:1", "9:1 7:1"]
        MR = [3, 3, 1, 1, 3]
        END = 814
        fill(s, 0, 803, "O..o..o..o.", 1, 0.3, pan=0.35, acc=">..........")
        # the gear starts
        for bar in range(4):
            s.hit("r", bar * 11, 0.45, -0.3)
        s.note("springres", 0, 30, 54, 0.4, -0.3, 0.5)
        for bt in range(22, 44, 3):
            s.note("pizz", bt, 1, 42, 0.3, 0.15, 0.2)

        def gear(bt, nbars, vel, last=0, shift=0, oct_d=1, dvel=None):
            for k in range(nbars):
                line(s, "spicc", bt + 11 * k, OST + LAST[last], vel, 0, -0.3, 0.15, legato=0.8,
                     tonic=s.tonic + shift)
                line(s, "dulcimer", bt + 11 * k, OST + LAST[last], dvel or vel * 0.9, oct_d, 0.3, 0.25, legato=1.2,
                     tonic=s.tonic + shift)

        PA = [("F#m", 22), ("G", 22), ("F#m", 22), ("Em", 22), ("D", 22), ("Em", 22), ("G", 22), ("F#m", 22)]

        def bedA(bt, d, c, i, v=0.0):
            bass(s, "lowstr", bt, d, c, "1:3 1:3 1:3 5,:2", 0.3 + v, 36, 0.2, 0.3)
            pad(s, "regal", bt, d, c, 0.12 + v * 0.5, 54, 3, 0.0, 0.5, 0.4)
        # A: the watch
        gear(44, 16, 0.2)
        prog(44, PA, bedA)
        for k, base in enumerate([12, 12, 17, 19]):
            motif(s, "clar", 44 + 44 * k, 0.48, base=base, rhythm=MR, last=13, pan=-0.15, send=0.35)
            semis(s, "glass", 66 + 44 * k, [(0, 3), (-7, 3), (-6, 1), (-7, 1), (-13, 3)], 0.34, base=24 + base - 12,
                  pan=0.35, send=0.45)
        for bt in range(44, 220, 44):
            s.hit("r", bt, 0.4, -0.3)
        # B: on alert: a buzzing current, muted horns calling the motif's head, keys, scans of a small bell
        PB = [("Bm", 22), ("F#m", 22), ("G", 22), ("A", 22), ("Bm", 22), ("G", 22), ("Em", 22), ("F#", 22)]
        gear(220, 16, 0.23)
        prog(220, PB, lambda bt, d, c, i: (bedA(bt, d, c, i, 0.03),
                                         bass(s, "volt", bt, d, c, "1:%d" % d, 0.2, 30, 0.0, 0.08)))
        for k in range(16):
            bt = 220 + 11 * k
            semis(s, "horns", bt, [(0, 3), (7, 3), (6, 2)], 0.3, base=0 if k % 2 == 0 else 5, pan=-0.2)
            semis(s, "horns", bt + 6, [(0, 3), (7, 2)], 0.26, base=7 if k % 2 == 0 else 12, pan=-0.25)
            drum(s, bt, "v..v..v..v.", 1, 0.32, pan=-0.4)
            s.hit("c", bt + 9, 0.3, 0.3)
            deg = [0, 7, 12, 13, 15, 19][int(s.rng.integers(0, 6))]
            s.note("tinebell", bt + [0, 3, 6, 9][int(s.rng.integers(0, 4))], 1.5, s.tonic + 24 + deg, 0.36, 0.45, 0.45)
        # C: the gear climbs a key at a time, its last turn changing by a note
        PC = [("F#m", 44), ("G", 44), ("A", 44), ("Bm", 44)]
        for k, (c, d) in enumerate(PC):
            bt = 396 + 44 * k
            shift = [0, 1, 3, 5][k]
            gear(bt, 4, 0.24 + 0.025 * k, last=k, shift=shift)
            bass(s, "lowstr", bt, d, c, "1:3 1:3 1:3 5,:2", 0.33 + 0.03 * k, 36, 0.2, 0.3)
            pad(s, "trem", bt, d, c, 0.18 + 0.05 * k, 57, 3, 0.0, 0.5, 0.45, shape="swell")
            if k >= 2:
                pad(s, "mchoir", bt, d, c, 0.2, 57, 3, 0.0, 0.6, 0.5)
            for j in range(4):
                timp(s, bt + 11 * j, c, 0.28 + 0.04 * k)
                drum(s, bt + 11 * j, "V..v..v..v.", 1, 0.3, pan=-0.4)
            motif(s, "horns", bt, 0.4 + 0.03 * k, base=shift, rhythm=[6, 6, 2, 2, 6], last=13, pan=-0.15)
            s.roll("r", bt + 33, 11, 0.5, 0.1, 0.45, -0.3)
        swell(s, 550, 22, 0.5)
        # D: the guard turns out (held back from the full battle: no cymbals, no great drums)
        s.hit("I", 572, 0.4, 0.45, 0.4)
        PD = [("F#m", 22), ("G", 22), ("F#m", 22), ("Em", 22), ("D", 22), ("G", 22), ("Em", 22), ("F#", 22)]
        gear(572, 16, 0.3, dvel=0.24)
        for k in range(16):
            line(s, "harpsi", 572 + 11 * k, OST + LAST[0], 0.2, 1, 0.45, 0.25, legato=0.9)
            drum(s, 572 + 11 * k, "a.....C....", 1, 0.38, pan=-0.1)
            drum(s, 572 + 11 * k, "V..v..v..v.", 1, 0.34, pan=-0.4)

        def bedD(bt, d, c, i):
            bass(s, "lowbr", bt, d, c, "1:3 1:3 1:3 5,:2", 0.4, 36, 0.2, 0.25)
            bass(s, "lowstr", bt, d, c, "1:3 1:3 1:3 5,:2", 0.38, 36, 0.2, 0.3)
            pad(s, "mchoir", bt, d, c, 0.24, 57, 3, 0.0, 0.6, 0.5)
            timp(s, bt, c, 0.42)
            timp(s, bt + 11, c, 0.34)
        prog(572, PD, bedD)
        for k in range(8):
            bt = 572 + 22 * k
            motif(s, "horns", bt, 0.5, base=0 if k % 2 == 0 else 7, rhythm=MR, last=13, pan=-0.15)
            if k % 2 == 1:
                motif(s, "tpts", bt + 3, 0.4, base=12 if k % 4 == 1 else 19, rhythm=MR, last=13, pan=0.2)
        # coda: the gear loses its teeth one by one
        b = 748
        line(s, "spicc", b, OST + LAST[0], 0.26, 0, -0.3, 0.15, legato=0.8)
        line(s, "dulcimer", b, OST + LAST[0], 0.22, 1, 0.3, 0.25, legato=1.2)
        line(s, "spicc", b + 11, "1:1 5:1 r:1 1:1 5:1 r:1 1:1 5:1 r:1 7:1 5:1", 0.24, 0, -0.3, 0.15, legato=0.8)
        line(s, "dulcimer", b + 11, "1:1 5:1 r:1 1:1 5:1 r:1 1:1 5:1 r:1 7:1 5:1", 0.2, 1, 0.3, 0.25, legato=1.2)
        line(s, "dulcimer", b + 22, "1:3 1:3 1:3 1:2", 0.2, 1, 0.3, 0.25, legato=1.2)
        line(s, "dulcimer", b + 33, "1:11", 0.18, 1, 0.3, 0.25)
        bass(s, "lowstr", b, 44, "F#m", "1:11", 0.3, 36, 0.2, 0.3)
        motif(s, "tinebell", b + 44, 0.45, base=24, rhythm=MR, last=13, pan=0.4, send=0.5)
        s.hit("g", b + 55, 0.5, 0.4, 0.4)
        s.hit("L", b + 55, 0.55, -0.2, 0.5)
        s.note("pizz", b + 55, 2, 42, 0.4, 0.15, 0.3)
        s.note("lowstr", b + 55, 11, 42, 0.3, 0.0, 0.3, "dim")
        return s

    # ------------------------------------------------------------------ SKIRMISH 3
    @piece("clock_battle_10")
    def pressure_rising():
        """B flat minor, 9/8 (2+2+2+3), eighth = 288. A boiler under pressure: pistons on the beats, a low
        ostinato, the motif upside down in the horns; every twelve bars the whole machine rises a semitone
        (B flat, B, C, C sharp, D); at D the alarm sounds, then the valve opens: steam, a spring, the music box
        plays the motif the right way up, and the machine settles back to B flat."""
        s = CSong("clock_battle_10", "Pressure Rising", 288, 9, n("B", 3) - 1, "aeolian", 1605, reverb=(1.6, 0.32))
        from orchestra import NAMES
        OSTP = [0, 7, 0, 8, 0, 7, 0, 5, 3]
        INV = [(0, 2), (-7, 2), (-6, 1), (-7, 1), (-14, 3)]

        def ostinato(inst, bt, bars, vel, tonic, base=0, pan=0.0, send=0.15):
            for b in range(bars):
                for k, st in enumerate(OSTP):
                    acc = 0.07 if k in (0, 2, 4, 6) else 0.0
                    s.note(inst, bt + 9 * b + k, 0.8, tonic + base + st, vel + acc, pan, send)

        # intro: the boiler is lit
        fill(s, 0, 54, "p.p.p.h..", 1, 0.3, acc=">........")
        s.note("lowstr", 0, 54, 46, 0.3, 0.0, 0.3, "swell")
        ostinato("regal", 18, 4, 0.2, s.tonic, pan=-0.3)
        s.hit("n", 36, 0.45, 0.4)
        b = 54
        for k in range(5):
            t0 = s.tonic + k
            pc = t0 % 12
            im, vi, v = NAMES[pc] + "m", NAMES[(pc + 8) % 12], NAMES[(pc + 7) % 12]
            plan = [(im, 54), (vi, 36), (v, 18)]
            ostinato("spicc", b, 12, 0.22 + 0.035 * k, t0, -12, pan=-0.2)
            ostinato("regal", b, 12, 0.16 + 0.015 * k, t0, 0, pan=0.25)
            fill(s, b, 108, "p.p.p.h..", 1, 0.3 + 0.05 * k, acc=">........")
            if k >= 1:
                fill(s, b, 108, ".......c.", 1, 0.28 + 0.03 * k, pan=0.35)
            for j in range(0, 12, 2):
                s.hit("n", b + 9 * j, 0.4, 0.4)

            def bed(bt, d, c, i):
                bass(s, "lowstr", bt, d, c, "1:9", 0.3 + 0.04 * k, 34, 0.2, 0.3)
                if k >= 1:
                    bass(s, "pizz", bt, d, c, "1:2 1:2 5,:2 1:3", 0.32 + 0.02 * k, 34, 0.15, 0.2)
                if k >= 2:
                    pad(s, "trem", bt, d, c, 0.16 + 0.05 * k, 58, 3, 0.0, 0.5, 0.45, shape="swell")
                if k >= 3:
                    pad(s, "mchoir", bt, d, c, 0.2 + 0.03 * k, 57, 3, 0.0, 0.6, 0.5)
                    for j in range(0, d, 9):
                        timp(s, bt + j, c, 0.32 + 0.04 * k)
            prog(b, plan, bed)
            semis(s, "horns", b, INV, 0.52 + 0.04 * k, base=12, tonic=t0, pan=-0.15)
            semis(s, "horns", b + 54, INV, 0.52 + 0.04 * k, base=7, tonic=t0, pan=-0.15)
            motif(s, "glass", b + 72, 0.46 + 0.02 * k, base=24, rhythm=[2, 2, 1, 1, 3], tonic=t0, pan=0.35, send=0.45)
            if k >= 3:
                ostinato("spicc", b, 12, 0.18 + 0.03 * k, t0, 0, pan=0.3)
                fill(s, b, 108, "V.v.v.v..", 1, 0.3, pan=-0.4)
            if k == 4:
                s.hit("I", b, 0.42, 0.45, 0.4)
                s.hit("I", b + 54, 0.42, 0.45, 0.4)
                fill(s, b, 108, "a.....a..", 1, 0.36, pan=-0.1)
                semis(s, "tpts", b + 2, INV, 0.4, base=24, tonic=t0, pan=0.2)
                semis(s, "tpts", b + 56, INV, 0.42, base=19, tonic=t0, pan=0.2)
                swell(s, b + 90, 18, 0.55)
                troll(s, b + 90, 18, v, 0.3, 0.85)
            s.roll("r", b + 90, 18, 0.5, 0.1, 0.4 + 0.05 * k, -0.3)
            b += 108
        # the valve opens
        s.roll("h", b, 18, 0.5, 0.75, 0.05, 0.2)
        s.hit("Z", b, 0.6, -0.3, 0.5)
        s.note("volt", b, 27, 34, 0.25, 0.0, 0.1, "dim")
        pad(s, "glassharm", b, 108, "Bbm", 0.3, 65, 3, 0.0, 0.6, 0.5, shape="arc")
        bass(s, "lowstr", b + 9, 99, "Bbm", "1:99", 0.28, 34, 0.2, 0.3, shape="arc")
        motif(s, "musicbox", b + 18, 0.5, base=12, scale=2, last=12, end=[(10, 2), (8, 2), (7, 6)], pan=0.2, send=0.45)
        motif(s, "musicbox", b + 60, 0.44, base=19, scale=2, last=12, end=[(10, 4), (8, 4), (5, 8)], pan=-0.2,
              send=0.45)
        fill(s, b + 18, 90, "o........", 1, 0.3, pan=0.35)
        b += 108
        # it settles
        ostinato("spicc", b, 6, 0.2, s.tonic, -12, pan=-0.2)
        ostinato("regal", b, 5, 0.18, s.tonic, 0, pan=0.25)
        fill(s, b, 45, "p.p.p.h..", 1, 0.3, acc=">........")
        bass(s, "lowstr", b, 45, "Bbm", "1:9", 0.3, 34, 0.2, 0.3)
        b += 45
        s.hit("p", b + 3, 0.6)
        s.hit("h", b + 4, 0.55, 0.3)
        s.hit("L", b + 3, 0.55, -0.2, 0.5)
        pad(s, "strings", b + 3, 12, "Bbm", 0.32, 58, 3, 0.0, 0.5, 0.5, shape="dim")
        s.note("lowstr", b + 3, 12, 34, 0.32, 0.0, 0.3, "dim")
        return s

    # ------------------------------------------------------------------ FULL BATTLE 1
    @piece("clock_battle_11")
    def cathedral():
        """C sharp minor, 5/4 + 6/4 (an eleven-beat pair), 126. A cathedral of gears: bells change-ringing
        (the old clock bell, resampled), an organ, a choir singing the motif stretched over one pair; the
        brass answer with its flat ninth; the gears alone pass the motif from bell to bell; the whole
        building climbs to D minor and rings out on an open chord, the motif's last note left hanging."""
        s = CSong("clock_battle_11", "Cathedral of Gears", 126, 11, n("C", 4) + 1, "aeolian", 1606, reverb=(2.8, 0.42))
        P5 = ("0120121010", ">..>..>.>.")
        P6 = ("012012012012", ">..>..>..>..")
        AUG = [2, 2, 1, 1, 5]

        def peal(bt, beats, vel, base=12, step=1.0, pan=-0.25):
            bells = [12, 10, 8, 7, 5, 3]
            row = list(range(6))
            k, i = 0, 0
            while k * step < beats - 1e-6:
                if k and k % 6 == 0:
                    sw = (0, 2, 4) if (k // 6) % 2 else (1, 3)
                    for a in sw:
                        if a + 1 < 6:
                            row[a], row[a + 1] = row[a + 1], row[a]
                pos = k % 6
                s.note("clockbell", bt + k * step, 2.0, s.tonic + base - 12 + bells[row[pos]], vel - 0.05 * (pos % 2),
                       pan + 0.1 * (pos - 2.5) / 2.5, 0.5)
                k += 1

        def gears(bt, items, vel, drums=True, big=0.0):
            b = bt
            for c, d in items:
                pat, acc = P5 if d == 5 else P6
                ost(s, "spicc", b, d, c, pat, 0.5, vel, 52, 3, -0.25, 0.15, acc=acc)
                if drums:
                    fill(s, b, d, "T..T..T.T." if d == 5 else "T..T..T..T..", 0.5, 0.3 + big, acc=">.........")
                    fill(s, b, d, "a.....C.a." if d == 5 else "a..C..a..C..", 0.5, 0.3 + big, pan=-0.15)
                b += d
            return b

        def pairs(bt, items, fn):
            return prog(bt, items, fn)
        # intro: the bells
        s.hit("G", 0, 0.55, 0.0, 0.5)
        peal(0, 22, 0.42)
        s.note("organ", 0, 22, 37, 0.3, 0.0, 0.4, "swell")
        s.note("lowstr", 4, 18, 37, 0.32, 0.0, 0.3, "swell")
        s.hit("m", 11, 0.45)
        s.roll("r", 18, 4, 0.25, 0.1, 0.5, -0.3)
        # A: the choir
        A = [("C#m", 5), ("A", 6), ("F#m", 5), ("G#", 6), ("C#m", 5), ("E/B", 6), ("A", 5), ("F#m", 6),
             ("D", 5), ("G#", 6), ("C#m", 5), ("G#7", 6)]

        def bedA(bt, d, c, i, v=0.0):
            pad(s, "organ", bt, d, c, 0.09 + v, 56, 3, 0.0, 0.5, 0.45)
            bass(s, "lowstr", bt, d, c, "1:2 1:1 5,:2" if d == 5 else "1:2 1:1 5,:1 1:2", 0.36 + v, 37, 0.2, 0.3)
            timp(s, bt, c, 0.36 + v)
        prog(22, A, bedA)
        gears(22, A, 0.24)
        peal(22, 66, 0.26)
        for k, (base, last) in enumerate([(0, 14), (7, 13), (8, 14)]):
            motif(s, "chorus_o", 22 + 22 * k, 0.62, base=base, rhythm=AUG, last=last, pan=0.0, send=0.5)
            motif(s, "mchoir", 22 + 22 * k, 0.36, base=base - 12, rhythm=AUG, last=last, pan=0.0, send=0.5)
        for k, ans in enumerate(["3':2 2':2 1':1 7+:6", "3':2 1':2 6:1 5:6", "5:2 4:2 3:1 2:6"]):
            line(s, "strings", 33 + 22 * k, ans, 0.56, 0, -0.35, 0.4, legato=1.0)
        # B: the brass
        B = [("A", 5), ("D", 6), ("Bm", 5), ("F#m", 6), ("C#m", 5), ("A", 6), ("D", 5), ("G#7", 6),
             ("A", 5), ("Bm", 6), ("G#sus", 5), ("G#", 6)]

        def bedB(bt, d, c, i):
            bedA(bt, d, c, i, 0.04)
            bass(s, "lowbr", bt, d, c, "1:2 1:1 5,:2" if d == 5 else "1:2 1:1 5,:1 1:2", 0.42, 37, 0.25, 0.25)
            pad(s, "chorus_u", bt, d, c, 0.2, 57, 3, 0.0, 0.7, 0.5)
        prog(88, B, bedB)
        gears(88, B, 0.27, big=0.05)
        peal(88, 66, 0.22, base=24, step=0.5, pan=0.3)
        motif(s, "horns", 88, 0.56, base=0, rhythm=AUG, last=13, pan=-0.15)
        semis(s, "chorus_o", 99, [(0, 2), (-7, 2), (-6, 1), (-7, 1), (-13, 5)], 0.48, base=12, send=0.5)
        motif(s, "tpts", 110, 0.54, base=7, rhythm=AUG, last=13, pan=0.2)
        motif(s, "horns", 121, 0.56, base=1, rhythm=AUG, last=13, pan=-0.15)
        motif(s, "horns", 132, 0.58, base=8, rhythm=AUG, pan=-0.15)
        motif(s, "chorus_o", 132, 0.5, base=8, rhythm=AUG, send=0.5)
        pad(s, "horns", 143, 11, "G#", 0.5, 56, 3, -0.1, 0.4, 0.35, shape="swell")
        pad(s, "tpts", 148, 6, "G#", 0.42, 63, 3, 0.2, 0.4, 0.3, shape="swell")
        troll(s, 143, 11, "G#", 0.25, 0.7)
        swell(s, 146, 8, 0.6)
        # C: the gears alone; the motif handed from bell to bell
        crash(s, 154, 0.55)
        C_ = [("C#m", 11), ("A", 11), ("F#m", 11), ("G#sus", 5), ("G#", 6)]
        prog(154, C_, lambda bt, d, c, i: (pad(s, "organ", bt, d, c, 0.07, 56, 3, 0.0, 0.5, 0.45),
                                          bass(s, "lowstr", bt, d, c, "1:%d" % d, 0.28, 37, 0.2, 0.3)))
        fill(s, 154, 44, "O.o.o.o.o.o.o.o.o.o.o.", 0.5, 0.4, pan=0.35, acc=">.....>.....>...>.....")
        fill(s, 154, 44, "v..v..v.v.v..v..v..v..", 0.5, 0.4, pan=-0.4)
        for k, c in enumerate(["C", "Q", "U", "C"]):
            s.hit(c, 154 + 11 * k, 0.4, -0.3, 0.35)
            s.hit("R", 154 + 11 * k + 9, 0.36, 0.35, 0.3)
        insts = ["glass", "tinebell", "musicbox", "harpsi", "clockbell"]
        for j, (base, inv) in enumerate([(12, False), (12, True), (7, False), (19, True)]):
            bt = 154 + 11 * j
            for q, ((st, _), d) in enumerate(zip(MOT, AUG)):
                st = -st if inv else st
                if q == 4 and not inv:
                    st = 13
                s.note(insts[q], bt, d * 1.2, s.tonic + base + st, 0.66, -0.5 + 0.25 * q, 0.5)
                bt += d
        # D: the build, out of the key and up a semitone
        D_ = [("C#m", 5), ("A", 6), ("F#m", 5), ("D", 6), ("E", 5), ("B", 6), ("A", 5), ("F#m", 6),
              ("Bb", 5), ("A", 6), ("A", 11)]

        def bedD(bt, d, c, i):
            v = 0.02 * i
            pad(s, "organ", bt, d, c, 0.1 + v, 56, 3, 0.0, 0.5, 0.45)
            pad(s, "chorus_u", bt, d, c, 0.2 + v, 57, 3, 0.0, 0.7, 0.5)
            bass(s, "lowstr", bt, d, c, "1:2 1:1 5,:2" if d == 5 else "1:2 1:1 5,:1 1:2", 0.38 + v, 37, 0.2, 0.3)
            bass(s, "lowbr", bt, d, c, "1:%d" % d, 0.36 + v, 37, 0.25, 0.25)
            timp(s, bt, c, 0.38 + v)
        prog(198, D_, bedD)
        gears(198, D_[:-1], 0.28, big=0.06)
        for k, base in enumerate([0, 2, 4, 5, 7]):
            motif(s, "horns", 198 + 11 * k, 0.5 + 0.02 * k, base=base, rhythm=AUG, last=13, pan=-0.15)
        line(s, "strings", 198, "1:5 2:6 3:5 4:6 5:5 6:6 7:5 7+:6 1':11", 0.44, 0, -0.35, 0.4, legato=1.0,
             shape="swell", shape_min=5)
        line(s, "strings", 198, "5:5 6:6 7:5 1':6 2':5 3':6 4':5 4+':6 5':11", 0.4, -1, 0.35, 0.4, legato=1.0,
             shape="swell", shape_min=5)
        troll(s, 253, 11, "A", 0.3, 1.0)
        swell(s, 256, 8, 0.75)
        fill(s, 253, 11, "a.a.a.a.aaaaaaaaaaaa", 0.5, 0.4, acc=">")
        # E: the climax, in D minor: the motif in canon (choir, horns, trumpets), the full peal, hammers
        s.tonic += 1
        E = [("Dm", 5), ("Bb", 6), ("Gm", 5), ("A", 6), ("Dm", 5), ("F/C", 6), ("Bb", 5), ("Eb", 6),
             ("Dm", 5), ("Bb", 6), ("Gm", 5), ("A7", 6), ("Bb", 5), ("Eb", 6), ("A", 11)]

        def bedE(bt, d, c, i):
            pad(s, "organ", bt, d, c, 0.12, 57, 3, 0.0, 0.5, 0.45)
            pad(s, "chorus_u", bt, d, c, 0.26, 57, 4, 0.0, 0.7, 0.5)
            pad(s, "strings", bt, d, c, 0.3, 62, 4, -0.2, 0.6, 0.45)
            bass(s, "lowstr", bt, d, c, "1:2 1:1 5,:2" if d == 5 else "1:2 1:1 5,:1 1:2", 0.44, 38, 0.2, 0.3)
            bass(s, "lowbr", bt, d, c, "1:2 1:1 5,:2" if d == 5 else "1:2 1:1 5,:1 1:2", 0.5, 38, 0.25, 0.25)
            timp(s, bt, c, 0.52)
            timp(s, bt + 3, c, 0.4)
        prog(264, E, bedE)
        gears(264, E[:-1], 0.32, big=0.12)
        peal(264, 88, 0.32, base=24, step=0.5, pan=0.3)
        for k in range(7):
            bt = 264 + 11 * k
            base = [0, 7, 0, 5, 0, 7, 8][k]
            last = 13 if k % 2 else 14
            motif(s, "chorus_o", bt, 0.6, base=base, rhythm=AUG, last=last, send=0.5)
            motif(s, "horns", bt + 2, 0.56, base=base, rhythm=AUG, last=last, pan=-0.15)
            motif(s, "tpts", bt + 4, 0.52, base=base + (12 if base < 5 else 0), rhythm=AUG, last=last, pan=0.2)
            s.hit("m", bt, 0.6)
        crash(s, 264, 0.8)
        crash(s, 308, 0.75)
        pad(s, "horns", 341, 11, "A", 0.6, 57, 3, -0.1, 0.4, 0.35, shape="swell")
        pad(s, "tpts", 341, 11, "A", 0.5, 64, 3, 0.2, 0.4, 0.3, shape="swell")
        troll(s, 341, 11, "A", 0.4, 1.0)
        fill(s, 341, 11, "a.a.a.a.aaaaaaaaaaaa", 0.5, 0.45, acc=">")
        # the end: an open chord, the motif's ninth hanging in the bells
        final(s, 352, 14, "Dsus2", 0.85, [("horns", 54, 3), ("strings", 62, 4), ("tpts", 62, 3),
                                          ("chorus_o", 57, 3), ("organ", 50, 3)], 38)
        crash(s, 352, 0.85)
        s.hit("G", 352, 0.7, 0.0, 0.5)
        s.note("clockbell", 352, 6, s.tonic + 14, 0.6, 0.3, 0.5)
        s.note("tinebell", 353, 3, s.tonic + 26, 0.5, 0.4, 0.5)
        s.note("clockbell", 357, 6, s.tonic + 14 - 12, 0.45, -0.3, 0.6)
        return s

    # ------------------------------------------------------------------ FULL BATTLE 2
    @piece("clock_battle_12")
    def anvil_chorus():
        """A phrygian, 7/8 (2+2+3) and 8/8 (3+3+2), eighth = 360. A forge of a thousand hands: anvils, clangs and a
        steam hammer interlock, each hand on its own beat of the bar; the low brass grind a riff on the flat
        second; the strings sing a long line over the 3+3+2; the motif, short enough for one 7/8 bar, is
        hammered by everyone at the climax; then the hands stop one by one and all strike once together."""
        s = CSong("clock_battle_12", "Anvil Chorus of a Thousand Hands", 360, 7, n("A", 3), "phrygian", 1607,
                  reverb=(1.6, 0.34))
        HANDS = {7: ["m......", "a.a.a..", ".C.Q..U", "....a.a"], 8: ["m.......", "a..a..a.", ".C..Q..U", "..a..a.a"]}
        RIFF = {7: [(0, 1), (0, 1), (1, 1), (0, 1), (-5, 2), (-2, 1)], 8: [(0, 1), (None, 1), (0, 1), (1, 2), (0, 1), (-5, 2)]}
        OSTP = {7: ("0101012", ">.>.>.."), 8: ("01201201", ">..>..>.")}
        MR = {7: [2, 2, 1, 1, 1], 8: [2, 2, 1, 1, 2]}

        def bars(bt, lens, chords, fn):
            for k, L in enumerate(lens):
                fn(bt, L, chords[k % len(chords)] if chords else None, k)
                bt += L
            return bt

        def hands(bt, L, vel, which=(0, 1, 2, 3)):
            for h in which:
                drum(s, bt, HANDS[L][h], 1, vel - 0.04 * h, pan=[-0.05, -0.35, 0.35, 0.15][h], send=0.15)

        def riff(bt, L, c, vel, base=-12):
            semis(s, "lowbr", bt, RIFF[L], vel, base=base, pan=0.2, send=0.2, legato=0.85)
            semis(s, "lowstr", bt, RIFF[L], vel - 0.04, base=base, pan=-0.1, send=0.2, legato=0.85)

        def gears(bt, L, c, vel):
            pat, acc = OSTP[L]
            ost(s, "spicc", bt, L, c, pat, 1, vel, 57, 3, -0.25, 0.15, acc=acc)
        # the hands start, one by one
        s.note("lowstr", 0, 56, 45, 0.3, 0.0, 0.3, "swell")
        b = 0
        for k in range(8):
            hands(b, 7, 0.36 + 0.02 * k, which=tuple(range(min(4, k + 1))))
            if k >= 4:
                drum(s, b, "v.v.vv.", 1, 0.3, pan=-0.45)
            b += 7
        s.hit("n", 28, 0.45, 0.4)
        s.roll("r", 42, 14, 0.5, 0.1, 0.5, -0.3)
        # A: the riff, the gears, the trumpets with the motif
        CA = ["Am", "Am", "Bb", "Bb", "Am", "Am", "Gm", "Gm", "F", "F", "Gm", "Gm", "Bb", "Bb", "Am", "Am",
              "Dm", "Dm", "C", "C", "Bb", "Bb", "A", "A"]

        def barA(bt, L, c, k, big=0.0):
            hands(bt, L, 0.42 + big)
            riff(bt, L, c, 0.44 + big)
            gears(bt, L, c, 0.26 + big)
            s.hit("T", bt, 0.36 + big, 0.0, 0.2)
            if k % 2 == 0:
                timp(s, bt, c, 0.38 + big)
                pad(s, "horns", bt, 14, c, 0.3 + big, 55, 3, -0.15, 0.4, 0.3)
        b = bars(b, [7] * 24, CA, barA)
        for k in range(6):
            motif(s, "tpts", 56 + 28 * k, 0.5, base=12 if k % 2 == 0 else 19, rhythm=MR[7], last=13,
                  end=[(13, 7)], pan=0.2)
        # B: 3+3+2, the strings sing over the forge
        CB = ["F", "F", "C", "C", "Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "Dm", "Dm", "Bb", "Bb", "C", "C",
              "F", "F", "Bb", "Bb", "Gm", "Gm", "A", "A"]
        B0 = b

        def barB(bt, L, c, k):
            hands(bt, L, 0.38, which=(0, 1, 2))
            gears(bt, L, c, 0.27)
            bass(s, "lowstr", bt, L, c, "1:3 1:3 5,:2", 0.42, 33, 0.2, 0.3)
            bass(s, "lowbr", bt, L, c, "1:3 1:3 5,:2", 0.36, 33, 0.25, 0.25)
            s.hit("T", bt, 0.34, 0.0, 0.2)
            if k % 2 == 0:
                pad(s, "chorus_o", bt, 16, c, 0.3, 57, 3, 0.0, 0.7, 0.5)
                timp(s, bt, c, 0.36)
        b = bars(b, [8] * 24, CB, barB)
        SONG = ("5:8 4:4 3:4 2:8 1:8 3:8 4:8 5:12 6:4 5:8 4:8 3:8 2:8 4:8 5:8 6:16 "
                "1':8 7:4 6:4 5:16 4:8 3:8 2:16")
        assert abs(sum(float(t.split(':')[1]) for t in SONG.split()) - 192) < 1e-6
        line(s, "strings", B0, SONG, 0.55, 1, -0.35, 0.4, legato=1.0, shape="arc", shape_min=8)
        line(s, "strings", B0, SONG, 0.42, 0, 0.2, 0.4, legato=1.0, dshift=-2, shape="arc", shape_min=8)
        for k in range(0, 24, 4):
            motif(s, "horns", B0 + 8 * k + 16, 0.42, base=0 if k % 8 == 0 else 7, rhythm=MR[8], scale=1.0, last=13,
                  pan=-0.15)
        # A': the riff again, louder, the choir in it
        def barA2(bt, L, c, k):
            barA(bt, L, c, k, 0.06)
            if k % 2 == 0:
                pad(s, "chorus_u", bt, 14, c, 0.28, 57, 3, 0.0, 0.7, 0.5)
        A2 = b
        b = bars(b, [7] * 16, CA[:16], barA2)
        for k in range(4):
            motif(s, "tpts", A2 + 28 * k, 0.54, base=12 if k % 2 == 0 else 19, rhythm=MR[7], last=13,
                  end=[(13, 7)], pan=0.2)
            motif(s, "horns", A2 + 28 * k + 2, 0.5, base=0 if k % 2 == 0 else 7, rhythm=MR[7], last=13, pan=-0.15)
        crash(s, A2, 0.65)
        # C: the forge falls quiet; the motif runs fast in canon in glass, celesta and a little bell; then it builds
        C0 = b
        lens = [7, 7, 8] * 8
        CC = ["Am", "Am", "Am", "Bb", "Bb", "Bb", "Gm", "Gm", "Gm", "A", "A", "A"]

        def barC(bt, L, c, k):
            if k < 9:
                hands(bt, L, 0.32, which=(1,) if k % 3 else (0, 1))
                drum(s, bt, "v.v.vv.." [:L], 1, 0.3, pan=-0.45)
                pad(s, "organ", bt, L, c, 0.14, 56, 3, 0.0, 0.5, 0.45)
                bass(s, "lowstr", bt, L, c, "1:%d" % L, 0.3, 33, 0.2, 0.3)
            else:
                v = (k - 9) / 15.0
                hands(bt, L, 0.34 + 0.12 * v)
                gears(bt, L, c, 0.22 + 0.1 * v)
                bass(s, "lowstr", bt, L, c, "1:%d" % L, 0.32 + 0.1 * v, 33, 0.2, 0.3)
                pad(s, "trem", bt, L, c, 0.2 + 0.2 * v, 57 + int(4 * v), 3, 0.0, 0.5, 0.45)
                if k % 3 == 0:
                    s.hit("R", bt + 4, 0.34, 0.35)
        b = bars(b, lens, ["Am"] * 9 + CC * 2, barC)
        for k, (inst, base) in enumerate([("glass", 24), ("celesta", 19), ("tinebell", 24), ("glass", 19),
                                          ("celesta", 24), ("tinebell", 19)]):
            bt = C0 + 7 * k
            motif(s, inst, bt, 0.42, base=base, scale=0.5, last=13, end=[(13, 1), (12, 1), (13, 1)], pan=-0.4 + 0.16 * k,
                  send=0.45)
            motif(s, inst, bt + 3, 0.34, base=base - 5, scale=0.5, last=13, pan=0.4 - 0.16 * k, send=0.45)
        line(s, "strings", C0 + 63, "1:14 2:14 2+:14 3:14 3+:14 4:14 4+:14 5:13", 0.42, 0, -0.35, 0.4,
             legato=1.0, shape="swell", shape_min=8)
        troll(s, b - 22, 22, "A", 0.3, 1.0)
        swell(s, b - 16, 16, 0.75)
        s.roll("r", b - 14, 14, 0.5, 0.15, 0.6, -0.3)
        # D: everything; the motif hammered in octaves, a bar each, by brass, strings and choir
        D0 = b
        CD = ["Am", "Bb", "Am", "Gm", "F", "Gm", "Bb", "A"]

        def barD(bt, L, c, k):
            hands(bt, L, 0.5)
            riff(bt, L, c, 0.52)
            gears(bt, L, c, 0.32)
            s.hit("T", bt, 0.45, 0.0, 0.2)
            s.hit("T", bt + 4, 0.36, 0.0, 0.2)
            timp(s, bt, c, 0.5)
            pad(s, "chorus_o", bt, L, c, 0.34, 57, 4, 0.0, 0.7, 0.5)
            pad(s, "mchoir", bt, L, c, 0.24, 52, 3, 0.0, 0.6, 0.5)
            if k % 4 == 0:
                pad(s, "strings", bt, 28, c, 0.36, 64, 4, -0.2, 0.6, 0.45)
        b = bars(b, [7] * 32, [c for c in CD for _ in range(4)], barD)
        for k in range(16):
            bt = D0 + 14 * k
            base = [0, 1, 0, -2, -4, -2, 1, 0][(k // 2) % 8]
            if k % 2 == 0:
                motif(s, "tpts", bt, 0.6, base=base + 12, rhythm=MR[7], last=13, end=[((13 if k % 4 >= 2 else 12), 7)], pan=0.2)
                motif(s, "horns", bt, 0.58, base=base, rhythm=MR[7], last=13, end=[((13 if k % 4 >= 2 else 12), 7)], pan=-0.2)
            else:
                motif(s, "strings", bt, 0.56, base=base + 12, rhythm=MR[7], last=13, end=[((13 if k % 4 >= 2 else 12), 7)], pan=-0.35,
                      legato=1.0)
                motif(s, "chorus_o", bt, 0.5, base=base, rhythm=MR[7], last=13, end=[((13 if k % 4 >= 2 else 12), 7)])
        crash(s, D0, 0.85)
        crash(s, D0 + 112, 0.8)
        swell(s, b - 14, 14, 0.7)
        # the hands stop one by one, then everyone strikes once
        E0 = b
        for k in range(6):
            which = [(0, 1, 2, 3), (0, 1, 2, 3), (0, 1, 2), (0, 1), (0,), ()][k]
            hands(b, 7, 0.48 - 0.03 * k, which)
            if k < 2:
                riff(b, 7, "Am", 0.5 - 0.05 * k)
                gears(b, 7, "Am", 0.3)
            b += 7
        final(s, b, 14, "A5", 0.9, [("horns", 52, 3), ("strings", 57, 4), ("tpts", 64, 2), ("chorus_o", 57, 3)], 33)
        crash(s, b, 0.9)
        s.hit("G", b, 0.7, 0.0, 0.5)
        for c in "aCQU":
            s.hit(c, b, 0.6, 0.0, 0.3)
        return s

    # ------------------------------------------------------------------ FULL BATTLE 3
    @piece("clock_battle_13")
    def grand_calculation():
        """G sharp minor, a phrase of 4/4, 7/8, 5/4 and 3/4 (31 eighths), eighth = 280. The machine computes:
        the motif in the low brass; then the motif and its mirror at once; then backwards in the bells; then
        all its forms together, slow in the choir, as written in the trumpets, mirrored in the horns, four
        times as fast in the glass; at the end everyone plays it as one and it resolves at last."""
        s = CSong("clock_battle_13", "The Grand Calculation", 280, 8, n("G", 3) + 1, "aeolian", 1608, reverb=(1.8, 0.36))
        PH = [8, 7, 10, 6]
        GR = {8: [3, 3, 2], 7: [2, 2, 3], 10: [3, 3, 2, 2], 6: [3, 3]}
        RH = [2, 2, 1, 1, 4]
        O = [0, 7, 6, 7, 14]
        I_ = [0, -7, -6, -7, -14]

        def form(inst, bt, vel, notes, rh, base=0, scale=1.0, **kw):
            return semis(s, inst, bt, list(zip(notes, rh)), vel, base, scale=scale, **kw)

        def opat(L):
            pat, acc = "", ""
            for g in GR[L]:
                pat += "012"[:g] if g == 3 else "01"
                acc += ">" + "." * (g - 1)
            return pat, acc

        def phrase(bt, chords, vel, kit=0.0, big=False, harps=False, low=True):
            b = bt
            for L, c in zip(PH, chords):
                pat, acc = opat(L)
                if harps:
                    ost(s, "harpsi", b, L, c, pat, 1, vel, 60, 3, 0.3, 0.25, acc=acc)
                else:
                    ost(s, "spicc", b, L, c, pat, 1, vel, 55, 3, -0.25, 0.15, acc=acc)
                    if big:
                        ost(s, "spicc", b, L, c, pat, 1, vel * 0.8, 67, 3, 0.3, 0.15, acc=acc)
                kpat = "".join("O" + "o" * (g - 1) for g in GR[L])
                fill(s, b, L, kpat, 1, 0.3 + kit * 0.5, pan=0.35, acc=acc)
                if low:
                    rh = " ".join("1:%d" % g for g in GR[L])
                    bass(s, "lowstr", b, L, c, rh, 0.34 + kit, 32, 0.2, 0.3)
                s.hit("p", b, 0.3 + kit, -0.1)
                if kit >= 0.08:
                    fill(s, b, L, "".join("T" + "." * (g - 1) for g in GR[L]), 1, 0.22 + kit * 0.6, acc=">")
                    timp(s, b, c, 0.34 + kit)
                if kit >= 0.14:
                    fill(s, b, L, "".join(("a" if i % 2 == 0 else "C") + "." * (g - 1) for i, g in enumerate(GR[L])),
                         1, 0.3 + kit, pan=-0.15)
                b += L
            return b

        b = 0
        s.hit("m", 0, 0.5)
        s.note("lowstr", 0, 31, 44, 0.3, 0.0, 0.3, "swell")
        # I: the theorem: the motif stated in the low brass
        CI = ["G#m", "E", "F#", "D#"]
        for k in range(5):
            phrase(b, CI, 0.22 + 0.02 * k, kit=0.02 * k)
            s.hit("m", b, 0.4 + 0.03 * k)
            if k >= 1:
                form("lowbr", b, 0.44 + 0.02 * k, O, RH, base=-12, pan=0.2)
                form("lowstr", b, 0.36, O, RH, base=-12, pan=-0.1)
            if k >= 2:
                form("horns", b + 15, 0.38 + 0.02 * k, O, RH, base=7, pan=-0.15)
                pad(s, "regal", b, 31, CI[0], 0.12, 55, 3)
            b += 31
        # II: the motif and its mirror together
        for k in range(6):
            ch = ["G#m", "C#m", "D#sus", "D#"] if k % 2 == 0 else ["E", "B", "F#", "G#m"]
            phrase(b, ch, 0.28, kit=0.1)
            form("horns", b, 0.5, O, RH, base=0, pan=-0.2)
            form("strings", b, 0.48, I_, RH, base=12 + (0 if k % 2 == 0 else -4), pan=0.3, legato=1.0)
            form("lowbr", b + 15, 0.42, O, RH, base=-12 + (0 if k % 2 == 0 else 7), pan=0.2)
            bb = b
            for L, c in zip(PH, ch):
                pad(s, "mchoir", bb, L, c, 0.22, 57, 3, 0.0, 0.6, 0.5)
                bb += L
            s.hit("m", b, 0.5)
            b += 31
        crash(s, 155, 0.6)
        # III: the working: backwards in the bells, upside down and backwards in the music box
        for k in range(4):
            ch = ["G#m", "G#m", "E", "E"] if k < 3 else ["E", "C#m", "D#sus", "D#"]
            phrase(b, ch, 0.2, kit=0.0, harps=True, low=(k == 3))
            pad(s, "glassharm", b, 31, ch[0], 0.26, 63, 3, 0.0, 0.6, 0.5)
            s.note("lowstr", b, 31, 39, 0.28, 0.0, 0.3)
            form("clockbell", b, 0.5, [14, 7, 6, 7, 0], [4, 1, 1, 2, 2], base=12, scale=1.5, pan=-0.3, send=0.5)
            form("musicbox", b + 15, 0.44, [-14, -7, -6, -7, 0], [4, 1, 1, 2, 2], base=24, pan=0.3, send=0.45)
            for j in range(3):
                form("tinebell", b + 5 + 9 * j, 0.32, O, RH, base=24, scale=0.5, pan=0.45, send=0.5)
            fill(s, b, 31, "v.vv.v.v..v.v.vv.v..v.vv.v.v.v.", 0.5, 0.28, pan=-0.45)
            s.hit("R", b + 26, 0.34, 0.35)
            b += 31
        s.roll("r", b - 16, 16, 0.5, 0.15, 0.6, -0.3)
        troll(s, b - 16, 16, "D#", 0.3, 1.0)
        swell(s, b - 16, 16, 0.75)
        # IV: every form at once
        for k in range(8):
            ch = ["G#m", "E", "C#m", "D#"] if k % 2 == 0 else ["G#m", "B", "E", "D#"]
            phrase(b, ch, 0.32, kit=0.18, big=True)
            base = 0 if k % 2 == 0 else 7
            form("chorus_o", b, 0.5, O, RH, base=base, scale=3.0, send=0.5)
            form("mchoir", b, 0.32, O, RH, base=base - 12, scale=3.0, send=0.5)
            form("tpts", b, 0.56, O, RH, base=12, pan=0.2)
            form("tpts", b + 15, 0.54, O, RH, base=19, pan=0.2)
            form("horns", b + 5, 0.54, I_, RH, base=12, pan=-0.2)
            form("horns", b + 20, 0.52, I_, RH, base=19, pan=-0.2)
            for j in range(6):
                form("glass", b + 5 * j, 0.34, O, RH, base=24, scale=0.5, pan=0.4, send=0.4)
            bb = b
            for L, c in zip(PH, ch):
                pad(s, "strings", bb, L, c, 0.32, 62, 4, -0.2, 0.6, 0.45)
                bass(s, "lowbr", bb, L, c, " ".join("1:%d" % g for g in GR[L]), 0.46, 32, 0.25, 0.25)
                bb += L
            s.hit("m", b, 0.62)
            if k % 2 == 0:
                crash(s, b, 0.75 + 0.02 * k)
            b += 31
        # coda: everyone, the motif as one, then the answer
        C0 = b
        for st, d in zip(O, RH):
            dd = d * 2
            for inst, base, v in [("horns", 0, 0.62), ("tpts", 12, 0.6), ("strings", 12, 0.58), ("lowbr", -12, 0.58),
                                  ("chorus_o", 0, 0.55), ("lowstr", -12, 0.5)]:
                s.note(inst, b, dd * 0.95, s.tonic + base + st, v, 0.0, 0.4)
            s.hit("m", b, 0.7)
            s.hit("T", b, 0.55)
            timp(s, b, s.tonic - 12 + (st % 12), 0.6)
            b += dd
        troll(s, b - 8, 8, "D#", 0.4, 1.0)
        final(s, b, 20, "G#m", 0.9, [("horns", 55, 3), ("strings", 63, 4), ("tpts", 63, 3), ("chorus_o", 56, 3),
                                    ("mchoir", 51, 3)], 32)
        crash(s, b, 0.9)
        s.hit("G", b, 0.7, 0.0, 0.5)
        s.hit("L", b, 0.7, -0.2, 0.5)
        s.note("clockbell", b, 6, s.tonic, 0.6, 0.3, 0.5)
        return s

    # ------------------------------------------------------------------ CALM 1
    @piece("clock_peace_6")
    def lament():
        """F minor, 4/4, 60. An empty workshop: one clock still ticking, a music box playing the motif and a
        lament built on it (its sharp fourth is the B natural against F minor); the strings take the lament,
        the clockmaker's bell tolls; at the end the box runs down, the clock stops, the last note hangs."""
        s = CSong("clock_peace_6", "The Clockmaker's Lament", 60, 4, n("F", 4), "aeolian", 1609, reverb=(3.2, 0.5))
        L = ("1:1 5:1 4+:0.5 5:0.5 2':1 3':2 2':1 1':1 7:1.5 6:0.5 5:1 4:1 5:4 "
             "1:1 5:1 4+:0.5 5:0.5 3':1 4':2 3':1 2':1 1':1 6:1 7+:1 2':1 1':4")
        CH = [("Fm", 4), ("Db", 4), ("Bbm", 4), ("C", 4), ("Fm", 4), ("Bbm", 4), ("Db", 2), ("C", 2), ("Fm", 4)]
        fill(s, 0, 140, "o", 1.0, 0.3, pan=0.3)
        fill(s, 140, 12, "o...", 1.0, 0.26, pan=0.3)
        pad(s, "glassharm", 0, 16, "Fm", 0.2, 65, 3, 0.0, 0.6, 0.55, shape="arc")
        s.note("lowstr", 0, 16, 41, 0.22, 0.0, 0.35, "arc")
        motif(s, "musicbox", 4, 0.5, base=12, pan=0.2, send=0.5)
        semis(s, "musicbox", 10, [(3, 1), (2, 1), (0, 2)], 0.44, base=12, pan=0.2, send=0.5)

        def soft(bt, d, c, i, v=0.0):
            pad(s, "glassharm", bt, d, c, 0.1 + v, 60, 3, 0.0, 0.6, 0.55)
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.24 + v, 36, 0.2, 0.35)
        # the music box plays the lament
        prog(16, CH[:-1] + [("Fm", 4)], soft)
        line(s, "musicbox", 16, L, 0.52, 1, 0.2, 0.5)
        # the strings take it; the box answers with the motif's head; the bell tolls
        def mid(bt, d, c, i):
            soft(bt, d, c, i, 0.03)
            ost(s, "dulcimer", bt, d, c, "0-1-2-1-", 0.5, 0.15, 60, 3, -0.4, 0.4, 1.6)
        prog(48, CH, mid)
        line(s, "strings", 48, L, 0.44, 0, -0.25, 0.45, legato=1.0, shape="arc", shape_min=2)
        for k, base in enumerate([24, 19, 24, 19]):
            semis(s, "musicbox", 48 + 8 * k + 4, [(0, 1), (7, 1), (6, 0.5), (7, 0.5)], 0.32, base=base, pan=0.35, send=0.5)
        for k in range(0, 32, 8):
            s.note("clockbell", 48 + k, 6, 53, 0.36, -0.25, 0.55)
        # the lament at its fullest: strings an octave up, the horns with the motif slowed, a choir of pipes
        def full(bt, d, c, i):
            pad(s, "strings", bt, d, c, 0.24, 58, 3, -0.2, 0.5, 0.5)
            pad(s, "mchoir", bt, d, c, 0.16, 53, 3, 0.0, 0.6, 0.55)
            bass(s, "lowstr", bt, d, c, "1:%g" % d, 0.32, 36, 0.2, 0.35)
            pad(s, "glassharm", bt, d, c, 0.14, 72, 2, 0.3, 0.4, 0.55)
        prog(80, CH, full)
        line(s, "strings", 80, L, 0.52, 1, -0.3, 0.45, legato=1.0, shape="arc", shape_min=2)
        motif(s, "horns", 80, 0.36, base=0, scale=2, end=[(12, 6)], pan=0.15, send=0.45)
        motif(s, "horns", 96, 0.36, base=5, scale=2, last=12 + 5 - 3, end=[(7, 6)], pan=0.15, send=0.45)
        s.note("clockbell", 80, 6, 41, 0.42, -0.25, 0.55)
        s.note("clockbell", 96, 6, 41, 0.4, -0.25, 0.55)
        # the box alone again, and it runs down
        prog(112, CH[:4], soft)
        evs = [(off, dur, di, acc) for off, dur, di, acc in s.parse(L)]
        first = [e for e in evs if e[0] < 16]
        for off, dur, di, acc in first:
            s.note("musicbox", 112 + off, dur, s.pitch(di + 7, acc), 0.54, 0.2, 0.5)
        bt, g = 128.0, 1.0
        for k, (off, dur, di, acc) in enumerate([e for e in evs if e[0] >= 16]):
            d = min(dur * g, 3.0)
            s.note("musicbox", bt, d, s.pitch(di + 7, acc), max(0.34, 0.54 - 0.01 * k), 0.2, 0.5)
            bt += d
            g *= 1.07
        pad(s, "glassharm", 128, bt - 128, "Fm", 0.14, 60, 3, 0.0, 0.6, 0.55, shape="dim")
        s.note("lowstr", 128, bt - 128, 41, 0.22, 0.0, 0.35, "dim")
        # the clock has stopped; the motif once more, very slowly, and the bell
        b = bt + 2
        motif(s, "musicbox", b, 0.48, base=12, scale=1.8, end=[(None, 2)], pan=0.2, send=0.55)
        pad(s, "glassharm", b + 6, 12, "Fmadd9", 0.2, 65, 4, 0.0, 0.7, 0.6, shape="arc")
        s.note("clockbell", b + 10, 8, 41, 0.42, -0.2, 0.6)
        return s

    # ------------------------------------------------------------------ CALM 2
    @piece("clock_peace_7")
    def canon():
        """D flat lydian, 3/2, 72. Perfect order: one tune made of the motif, played by the celesta, while a glass
        harmonica plays it at half speed and the strings at a quarter: three speeds that start together and end
        together. Then the music box plays it upside down; then a mirror canon (upright in the dulcimer, upside
        down in the celesta) over the tune at half speed in the old clock bell; at last the motif, resolved."""
        s = CSong("clock_peace_7", "Canon of Perfect Order", 72, 6, n("D", 4) - 1, "lydian", 1610, reverb=(3.0, 0.48))
        M = ("1:1 5:1 4:0.5 5:0.5 2':2 1':1 7:1 5:1 6:2 5:2 3:1 4:1 5:1.5 4:0.5 3:1 2:1 1:2 5,:2 1:2")

        def inv(notes):
            out = []
            for tok in notes.split():
                deg, dur = tok.split(":")
                o = deg.count("'") - deg.count(",")
                i = -(int(deg.strip("',")) - 1 + 7 * o)
                q, r = divmod(i, 7)
                out.append("%d%s:%s" % (r + 1, "'" * q if q > 0 else "," * -q, dur))
            return " ".join(out)
        MI = inv(M)
        fill(s, 0, 228, "o.o.o.", 1.0, 0.24, pan=0.3)
        # the tune alone
        line(s, "celesta", 0, M, 0.5, 1, 0.25, 0.45)
        s.note("glassharm", 0, 24, s.tonic + 12, 0.14, -0.3, 0.55, "arc")
        s.note("glassharm", 0, 24, s.tonic + 19, 0.12, 0.3, 0.55, "arc")
        for k in range(0, 24, 6):
            s.note("pizz", k, 1, s.tonic - 24, 0.32, 0.15, 0.35)
        # the three speeds
        for k in range(4):
            line(s, "celesta", 24 + 24 * k, M, 0.46, 1, 0.3, 0.45)
        for k in range(2):
            line(s, "glassharm", 24 + 48 * k, M, 0.36, 0, -0.3, 0.5, legato=1.0, scale=2.0)
        line(s, "strings", 24, M, 0.3, -1, 0.0, 0.5, legato=1.0, scale=4.0, shape="arc", shape_min=4)
        for k in range(24, 120, 6):
            s.note("pizz", k, 1, s.tonic - 24, 0.28, 0.15, 0.35)
        s.note("lowstr", 24, 96, s.tonic - 24, 0.18, 0.0, 0.4, "arc")
        # the music box, upside down, over a drone; the harpsichord rings the motif's head
        line(s, "musicbox", 120, MI + " " + MI, 0.46, 2, 0.2, 0.5)
        s.note("lowstr", 120, 48, s.tonic - 24, 0.22, 0.0, 0.4, "arc")
        s.note("glassharm", 120, 48, s.tonic + 7, 0.16, -0.3, 0.55, "arc")
        for k in range(0, 48, 12):
            semis(s, "harpsi", 120 + k + 6, [(0, 1), (7, 1), (6, 0.5), (7, 0.5)], 0.22, base=0, pan=-0.35, send=0.4)
        # the mirror canon over the tune in the bell
        line(s, "dulcimer", 168, M + " " + M, 0.4, 1, -0.35, 0.4)
        line(s, "celesta", 168, MI + " " + MI, 0.42, 2, 0.35, 0.45)
        line(s, "clockbell", 168, M, 0.42, 0, 0.0, 0.55, legato=1.0, scale=2.0)
        pad(s, "strings", 168, 48, "Db", 0.18, 56, 3, 0.0, 0.5, 0.5, shape="arc")
        s.note("lowstr", 168, 48, s.tonic - 24, 0.22, 0.0, 0.4, "arc")
        # the motif, at last resolved
        motif(s, "musicbox", 216, 0.46, base=12, scale=2, last=12, end=[(12, 4)], pan=0.2, send=0.55)
        motif(s, "glassharm", 216, 0.32, base=0, scale=2, last=12, end=[(12, 4)], pan=-0.2, send=0.55)
        pad(s, "strings", 216, 16, "Dbadd9", 0.22, 56, 4, 0.0, 0.6, 0.55, shape="arc")
        s.note("lowstr", 216, 16, s.tonic - 24, 0.24, 0.0, 0.4, "dim")
        s.note("clockbell", 228, 8, s.tonic - 12, 0.4, -0.2, 0.6)
        s.note("celesta", 228, 3, s.tonic + 24, 0.3, 0.3, 0.6)
        return s
