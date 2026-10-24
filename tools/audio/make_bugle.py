"""The Crown's bugle calls, played from the notation of the Brazilian Army's Manual de Toques (C 20-5,
1998; art/audio_src/bugle/): short bites of the real calls, synthesised as a cornet in B flat (so the
written pitch sounds a tone lower) in a stone-yard room.

  move_1     FA-55 Ordinario (marche)       a group is sent marching
  amove_1    FA-62 Avancar                  an attack-move
  charge_1   FA-58 Marche-marche            a focused attack by a group
  patrol_1   FA-134 Patrulha ou Ronda       a patrol
  trained_1  FA-74 Reunir                   a soldier joins the ranks (the first two bars)

Notes are (written pitch, beats); pitches are the bugle's harmonics G4 C5 E5 G5.
Run: python3 tools/audio/make_bugle.py   (then tools/audio/make_mix.py and godot --headless --import)"""
import os
import subprocess
import numpy as np

SR = 32000
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "voice", "crown_bugle")
G4, C5, E5, G5, G3 = 67, 72, 76, 79, 55
S, E, Q = 0.25, 0.5, 1.0


def tone(midi, dur, vel=0.8, rng=None):
    f = 440.0 * 2 ** ((midi - 2 - 69) / 12.0)          # B flat cornet: sounds a tone below the written note
    n = int((dur + 0.18) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.0035 * np.sin(2 * np.pi * 5.3 * t) * np.minimum(1, t * 3)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    # a bugle's tone: strong low harmonics, a bright bloom as the note speaks
    bloom = 1 - np.exp(-t * 22)
    s = np.zeros(n)
    for k, a in enumerate([1.0, 0.85, 0.62, 0.42, 0.28, 0.17, 0.1, 0.06], 1):
        s += a * np.sin(k * ph) * (1.0 if k < 3 else bloom ** (k - 1.5))
    lip = np.convolve(rng.standard_normal(n), np.ones(40) / 40, "same") * 0.05 * np.exp(-t * 14)
    s += lip
    att = np.minimum(1, t / 0.012)
    rel = np.minimum(1, np.maximum(0, (dur + 0.18 - t)) / 0.12)
    body = np.where(t < dur, 1.0, np.exp(-(t - dur) * 25))
    return s * att * rel * body * vel * 0.28


def play(notes, bpm, pickup=0.0):
    rng = np.random.default_rng(7)
    beat = 60.0 / bpm
    total = sum(d for _, d in notes) * beat + 0.4
    out = np.zeros(int((total + 1.2) * SR))
    t0 = 0.0
    for i, (m, d) in enumerate(notes):
        if m is not None:
            v = 0.85 if i == 0 else (0.95 if d >= 1.0 else 0.8)
            x = tone(m, d * beat * 0.93, v, rng)
            out[int(t0 * SR): int(t0 * SR) + len(x)] += x[: len(out) - int(t0 * SR)]
        t0 += d * beat
    # a stone-yard room: a few short echoes and a dark tail
    ir = np.zeros(int(0.9 * SR))
    ir[0] = 1.0
    for dly, g in ((0.037, 0.35), (0.081, 0.25), (0.14, 0.17)):
        ir[int(dly * SR)] += g
    tail = rng.standard_normal(len(ir)) * np.exp(-np.arange(len(ir)) / SR * 5.5) * 0.05
    from scipy.signal import fftconvolve, butter, lfilter
    b, a = butter(2, 2600 / (SR / 2))
    tail = lfilter(b, a, tail)
    wet = fftconvolve(out, ir + tail)[: len(out)]
    out = wet / (np.abs(wet).max() + 1e-9) * 0.8
    end = np.where(np.abs(out) > 0.004)[0][-1] + int(0.1 * SR)
    out = out[:end]
    out[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))
    return out


CALLS = {
    # FA-55 Ordinario: pickup G, a triplet C-G-E twice, then a C
    "move_1": ([(G4, E), (C5, 1 / 3), (G4, 1 / 3), (E5, 1 / 3), (C5, 1 / 3), (G4, 1 / 3), (E5, 1 / 3), (C5, 1.6)], 112),
    # FA-62 Avancar: G e. G G, G e. G G, G G C  (the written bar repeats)
    "amove_1": ([(G4, E), (G4, S), (G4, S), (G4, E), (G4, S), (G4, S), (G4, E), (G4, E), (C5, 1.4)], 116),
    # FA-58 Marche-marche: pickup G, then C C E E C C G G | C C G G C, and the closing E
    "charge_1": ([(G4, E), (C5, S), (C5, S), (E5, S), (E5, S), (C5, S), (C5, S), (G4, S), (G4, S),
                  (C5, S), (C5, S), (G4, S), (G4, S), (C5, Q), (E5, 1.8)], 132),
    # FA-134 Patrulha: C C C C, C E | G. E | C C C C, C C | C, E
    "patrol_1": ([(C5, S), (C5, S), (C5, S), (C5, S), (C5, E), (E5, E), (G5, 1.5), (E5, E),
                  (C5, S), (C5, S), (C5, S), (C5, S), (C5, E), (C5, E), (C5, Q), (E5, 1.6)], 108),
    # FA-74 Reunir: pickup E, C. G E | C G E C C G E (first two bars)
    "trained_1": ([(E5, E), (C5, 1.5), (G4, S), (E5, S), (C5, E), (G4, S), (E5, S), (C5, S), (C5, S), (G4, S), (E5, 1.4)], 112),
    # not read from the manual (I only transcribed the five above): short calls in the same idiom
    # stop: two long steady notes falling to the tonic
    "stop_1": ([(E5, Q), (C5, 1.8)], 100),
    # hold: a firm repeated note, then the low G
    "hold_1": ([(C5, E), (C5, E), (C5, E), (G4, 1.8)], 100),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (notes, bpm) in CALLS.items():
        x = play(notes, bpm)
        p = os.path.join(OUT, name + ".wav")
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2", p],
                       input=x.astype(np.float32).tobytes(), check=True)
        print(name, "%.1fs" % (len(x) / SR))


if __name__ == "__main__":
    main()
