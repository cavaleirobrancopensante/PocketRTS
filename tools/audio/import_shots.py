"""Bring the designer's recordings into the game: Crown gunfire (replaces the synthesised shots) and
the Cuirassier's horse (*horse*).

    python3 tools/audio/import_shots.py <folder with the recordings>

Looks for *musket_shot_1*, *musket_shot_2*, *cannon_shot_1* (round shot), *cannon_shot_2* (canister)
and *mortar_shot* (any format ffmpeg reads). Each is mixed to mono 44.1 kHz, its leading silence
cut so the bang lands at once, its tail cut where it fades out (or at the length below) with a
gentle fade, peak -1 dBFS, and written as a 16-bit WAV under assets/audio/combat/.
Then run make_mix.py to level them.
"""
import glob
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import SR, hp, write_wav  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")

# source pattern -> (game sound under assets/audio, longest length in s, fade-out s)
SHOTS = [
    ("*musket_shot_1*", "combat/musketeer_attack_1", 1.4, 0.35),
    ("*musket_shot_2*", "combat/musketeer_attack_2", 1.4, 0.35),   # 3.6 s long: keep the shot and its echo
    ("*cannon_shot_1*", "combat/cannon_attack", 1.5, 0.5),
    ("*cannon_shot_2*", "combat/cannon_canister", 2.2, 0.5),
    ("*mortar_shot*", "combat/mortar_attack", 2.2, 0.5),
    ("*horse*", "horse/whinny", 1.6, 0.4),          # the Cuirassier's horse, now and then on an order
]


def load(p):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def env(x, win=0.01):
    w = max(1, int(SR * win))
    return np.sqrt(np.convolve(x ** 2, np.ones(w) / w, mode="same"))


def prepare(x, max_len, fade):
    x = hp(x, 25)
    a = np.abs(x)
    pk = a.max() + 1e-12
    start = int(np.nonzero(a > pk * 10 ** (-30 / 20))[0][0])      # first sample within 30 dB of the peak
    x = x[max(0, start - int(0.002 * SR)):]
    e = env(x)
    above = np.nonzero(e > e.max() * 10 ** (-45 / 20))[0]          # where the tail sinks 45 dB under the bang
    end = min(len(x), int(above[-1]) + int(0.02 * SR), int(max_len * SR))
    x = x[:end].copy()
    fi = int(0.002 * SR)
    x[:fi] *= np.linspace(0, 1, fi)
    fo = min(len(x) // 2, int(fade * SR))
    x[-fo:] *= np.linspace(1, 0, fo) ** 2
    return x / (np.max(np.abs(x)) + 1e-12) * 10 ** (-1 / 20)


def main(src):
    for pat, name, max_len, fade in SHOTS:
        found = sorted(glob.glob(os.path.join(src, pat)))
        if not found:
            print("missing", pat)
            continue
        x = load(found[0])
        y = prepare(x, max_len, fade)
        write_wav(os.path.join(OUT, name + ".wav"), y)
        print(f"ok {name:22s} {len(x) / SR:5.2f}s -> {len(y) / SR:5.2f}s  ({os.path.basename(found[0])})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
