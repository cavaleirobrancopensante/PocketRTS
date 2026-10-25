"""The Brood's creature voices, cut from the designer's seven insect clips (replaces the synthetic grub
calls of make_voices.py; the Raptor's lizard voice and the Skywing's calls are untouched).

    python3 tools/audio/make_brood_voices.py [SRC_DIR]     (then: python3 tools/audio/make_mix.py)

SRC_DIR holds the mp3s (default: $INSECT_DIR). Needs ffmpeg, numpy, scipy.
Each unit gets select_1..3 / move_1..3 / attack_1..2 under assets/voice/<unit>/ and death_1..3 under
assets/audio/combat/<unit>_death_N.wav. Bigger unit = lower pitch (resampled, so also longer); the move
voice of every walker is the insect-feet recording (steps, no cry). Edges are faded; peak -3 dBFS like
the other voices; make_mix.py then levels them (see OFFSET there for the gentle grub).
"""
import glob
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPS = {"small": "small-insect-monster", "gdying": "giant_insect_dying", "dying": "insect_dying",
         "walk": "insect_walking_2", "feet": "insect_foots", "monster": "giant-insect-monster",
         "hurts": "giant-insect-hurts"}


def load(src, key):
    p = [f for f in glob.glob(os.path.join(src, "*.mp3")) if CLIPS[key] in f][0]
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def cut(x, a, b):
    return x[int(a * SR):int(b * SR)].copy()


def pitch(x, semis):
    """Resample: lower = longer and darker (a bigger body), higher = shorter."""
    r = 2 ** (semis / 12.0)
    n = 1000
    return resample_poly(x, n, int(round(n * r)))


def lowpass(x, f, o=2):
    return sosfilt(butter(o, f, "low", fs=SR, output="sos"), x)


def highpass(x, f, o=2):
    return sosfilt(butter(o, f, "high", fs=SR, output="sos"), x)


def finish(x, fade_in=0.004, fade_out=0.05, peak_db=-3.0, lp=None, hp=60, drive=0.0):
    if drive:      # sparse footsteps are all peak and no body: squash them a little so they carry at a low level
        x = np.tanh(drive * x / (np.abs(x).max() + 1e-9)) / np.tanh(drive)
    if lp:
        x = lowpass(x, lp)
    x = highpass(x, hp)
    n_in, n_out = int(fade_in * SR), min(int(fade_out * SR), len(x) // 2)
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out) ** 1.5
    x = x * (10 ** (peak_db / 20) / (np.abs(x).max() + 1e-9))
    return x


def write(rel, x):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


# the three cut points of each source (seconds), chosen by hand on the clips' envelopes
FEET = [("feet", 0.22, 0.74), ("feet", 1.10, 1.92), ("walk", 0.52, 1.02)]
SMALL = [(0.00, 0.30), (0.10, 0.42), (0.04, 0.34)]


def voice(unit, sel_semis, move_semis, att_semis=None, att_src="hurts", sel_src="small", lp_sel=6500, lp_move=6500,
          sel_len=1.0):
    S = {k: None for k in CLIPS}
    out = {}
    for i in range(3):
        base = load(SRC, sel_src)
        a, b = SMALL[i] if sel_src == "small" else [(0.0, 0.40), (0.15, 0.60), (0.30, 0.75)][i]
        x = pitch(cut(base, a, b * sel_len if sel_src != "small" else b), sel_semis + [0, 1, -1][i])
        out[f"select_{i + 1}"] = finish(x, lp=lp_sel)
        k, a, b = FEET[i]
        x = pitch(cut(load(SRC, k), a, b), move_semis + [0, 0.7, -0.7][i])
        out[f"move_{i + 1}"] = finish(x, fade_in=0.006, fade_out=0.08, lp=lp_move, drive=5.0)
    if att_semis is not None:
        h = load(SRC, att_src)
        for i, (a, b) in enumerate([(0.0, 0.42), (0.04, 0.50)]):
            out[f"attack_{i + 1}"] = finish(pitch(cut(h, a, b), att_semis + [0, -1.2][i]), lp=6000)
    for k, x in out.items():
        write(f"assets/voice/{unit}/{k}.wav", x)


def death(unit, src, semis, length=0.8, lp=6000):
    base = load(SRC, src)
    for i, (a, off) in enumerate([(0.0, 0.0), (0.06, 0.8), (0.03, -0.8)]):
        x = pitch(cut(base, a, a + length), semis + off)
        write(f"assets/audio/combat/{unit}_death_{i + 1}.wav", finish(x, fade_out=0.25, lp=lp))


SRC = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("INSECT_DIR", "")

if __name__ == "__main__":
    if not os.path.isdir(SRC):
        sys.exit("give the folder of the insect mp3s (or set INSECT_DIR)")
    # unit:        select pitch, move pitch, attack pitch (None = keeps its old attack voice)
    voice("grub", 3, 0, lp_sel=5500)                      # chirp, soft + a little higher; feet
    voice("spitter", -2, -3)                              # (keeps its spitting attack)
    voice("brute", -5, -6, att_semis=-4, sel_src="monster", lp_sel=4500, lp_move=4500)
    voice("spore_mother", -7, -8, att_semis=-6, sel_src="monster", lp_sel=3500, lp_move=3500)
    voice("bloater", -4, -5, lp_sel=5000, lp_move=5000)
    voice("mist_toad", -1, -2)
    # deaths: small bodies the insect dying cry, the big ones the giant one
    death("grub", "dying", 3, 0.55)
    death("spitter", "dying", 0, 0.7)
    death("bloater", "dying", -3, 0.8)
    death("mist_toad", "dying", -1, 0.7)
    death("skywing", "dying", 4, 0.5, lp=6500)
    death("brute", "gdying", -2, 0.9, lp=4500)
    death("spore_mother", "gdying", -5, 0.9, lp=4000)
    print("done")
