"""The MARCHING BAND's sound loop (scripts/marching_band.gd: MarchingBand.look_tick plays one phrase of each instrument
the band has every Defs.MARCHING_BAND "phrase" s, the lead one louder). Writes assets/audio/band/<instrument>.ogg and
<instrument>_lead.ogg, each one 4-second phrase (two bars of 4/4 at 120 bpm) so they tile and sound together:
  drums   cut from the owner's marching snare solos (art/audio_src/marching/drums1..5.mp3): a steady bar pair for the
          secondary, the busiest pair (rolls) for the solo
  fife    played from the real fife notes (art/audio_src/fife/notes/, tools/audio/fife_sampler.py): the march tune, and
          for the solo the same tune an octave of flourish higher with grace notes
  pipes   synthesised (no recording yet): two drones (B flat) and a reedy chanter with the pipes' grace notes; the solo
          louder and busier
Run: python3 tools/audio/make_band_sounds.py   (then godot --headless --import)"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fife_sampler as fs  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "assets", "audio", "band")
SR = fs.SR                 # 32000
LEN = 4.0                  # s: one phrase (Defs.MARCHING_BAND "phrase")
BPM = 120.0
BEAT = 60.0 / BPM


def write(name, x, peak=0.7):
    n = int(LEN * SR)
    y = np.zeros(n)
    y[:min(n, len(x))] = x[:n]
    fi, fo = int(0.01 * SR), int(0.12 * SR)
    y[:fi] *= np.linspace(0, 1, fi)
    y[-fo:] *= np.linspace(1, 0, fo)
    y *= peak / (np.abs(y).max() + 1e-9)
    p = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "4", p],
                   input=y.astype(np.float32).tobytes(), check=True)
    print(p, "rms %.3f" % np.sqrt(np.mean(y ** 2)))


# ------------------------------------------------------------------ drums

def load_mp3(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(float)


def drum_windows():
    """(steadiest window, busiest window) of LEN s over the five snare solos."""
    steady, busy = None, None
    for k in range(1, 6):
        p = os.path.join(ROOT, "art", "audio_src", "marching", "drums%d.mp3" % k)
        if not os.path.exists(p):
            continue
        x = load_mp3(p)
        hop = SR // 20
        env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
        w = int(LEN * 20)
        for i in range(20, len(env) - w - 20, 4):
            seg = env[i:i + w]
            sc_steady = np.mean(seg) - 0.8 * np.std(seg)
            sc_busy = np.mean(seg) + 0.3 * np.std(seg)
            if steady is None or sc_steady > steady[0]:
                steady = (sc_steady, x[i * hop:i * hop + int(LEN * SR)])
            if busy is None or sc_busy > busy[0]:
                busy = (sc_busy, x[i * hop:i * hop + int(LEN * SR)])
    return steady[1], busy[1]


# ------------------------------------------------------------------ fife

B, C, D, E, F, G, A = 70, 72, 74, 75, 77, 79, 81
B2, C2, D2 = 82, 84, 86
# two bars, eighth notes = 0.5 beat (16 of them fill the 4 s)
FIFE = [(F, .5), (F, .5), (B2, .5), (A, .5), (G, .5), (F, .5), (D, .5), (F, .5),
        (E, .5), (G, .5), (F, .5), (D, .5), (C, .5), (D, .5), (B, 1.0)]
FIFE_LEAD = [(F, .25), (A, .25), (B2, .5), (C2, .25), (B2, .25), (A, .5), (B2, .5), (D2, .5), (C2, .5), (A, .5),
             (B2, .25), (A, .25), (G, .5), (F, .5), (G, .25), (A, .25), (B2, .5), (F, .5), (B2, 1.0)]


def fife(tune):
    out = np.zeros(int((LEN + 1.0) * SR))
    t = 0.0
    for m, dur in tune:
        x = fs.note(m, dur * BEAT * 0.9)
        o = int(t * SR)
        out[o:o + len(x)] += x[:len(out) - o]
        t += dur * BEAT
    from scipy.signal import butter, lfilter
    b, a = butter(2, 3400 / (SR / 2))
    return lfilter(b, a, out)


# ------------------------------------------------------------------ pipes (synthesised)

def reed(freq, dur, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for h in range(1, 14):
        x += np.sin(2 * np.pi * freq * h * t + 0.3 * h) * (1.0 / h ** 0.8) * (1.15 if h % 2 else 0.85)
    return x * amp


def pipes(lead):
    n = int((LEN + 0.5) * SR)
    t = np.arange(n) / SR
    root = 116.54                     # B flat 2
    drone = np.zeros(n)
    for f, a in [(root, 0.5), (root * 2, 0.35), (root * 2 * 1.0015, 0.2)]:
        for h in range(1, 10):
            drone += np.sin(2 * np.pi * f * h * t + h) * a / h ** 1.1
    drone *= 0.45
    # the chanter: a mixolydian tune in B flat, eighths, a high-G grace note before each beat
    sc = {"B": 466.16, "C": 523.25, "D": 587.33, "E": 622.25, "F": 698.46, "G": 783.99, "A": 830.61, "b": 932.33}
    tune = "F F b F D F E D C D E F D C B B" if not lead else "b b F b D F b G F E D F E C B B"
    ch = np.zeros(n)
    pos = 0.0
    for k, nm in enumerate(tune.split()):
        dur = 0.5 * BEAT
        o = int(pos * SR)
        if k % 2 == 0 or lead:
            g = reed(sc["G"] * 1.0, 0.035, 0.8)       # grace note
            ch[o:o + len(g)] += g[:n - o]
            o += len(g)
        x = reed(sc[nm], dur * 0.97 - 0.035 if (k % 2 == 0 or lead) else dur * 0.97)
        ch[o:o + len(x)] += x[:n - o]
        pos += dur
    from scipy.signal import butter, lfilter
    b, a = butter(2, [300 / (SR / 2), 5000 / (SR / 2)], btype="band")
    ch = lfilter(b, a, ch)
    x = drone + ch * (0.9 if lead else 0.65)
    b, a = butter(2, 4500 / (SR / 2))
    return lfilter(b, a, x)


def main():
    os.makedirs(OUT, exist_ok=True)
    steady, busy = drum_windows()
    write("drums", steady, 0.6)
    write("drums_lead", busy, 0.8)
    write("fife", fife(FIFE), 0.5)
    write("fife_lead", fife(FIFE_LEAD), 0.7)
    write("pipes", pipes(False), 0.45)
    write("pipes_lead", pipes(True), 0.65)


if __name__ == "__main__":
    main()
