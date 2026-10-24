"""A fife phrase played from REAL fife recordings (the user's 'fife_music.mp3', a B flat fife):
one clean note per pitch is cut out (art/audio_src/fife/notes/), others are made by shifting the
nearest note by a few semitones at most. Demo phrase: assets/voice/crown_bugle/../fife_demo.wav (see main)."""
import os, sys, subprocess, wave
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
SR = 32000
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
NOTES = os.path.join(ROOT, "art", "audio_src", "fife", "notes")
# midi -> (start s in fife_music.mp3, length s)
CUT = {70: (129.93, 1.7), 72: (46.6, 2.3), 73: (138.52, 1.2), 74: (58.31, 0.6), 75: (41.63, 0.58),
       77: (131.93, 2.1), 82: (136.02, 1.25), 84: (25.17, 0.42), 87: (122.31, 0.46)}


def cut(src):
    os.makedirs(NOTES, exist_ok=True)
    for m, (a, d) in CUT.items():
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-ss", str(a - 0.02), "-t", str(d + 0.02), "-i", src,
                        "-ac", "1", "-ar", str(SR), os.path.join(NOTES, "%d.wav" % m)], check=True)


def load(m):
    w = wave.open(os.path.join(NOTES, "%d.wav" % m))
    x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float) / 32768
    return x / (np.sqrt((x[int(0.1 * SR):int(0.3 * SR)] ** 2).mean()) + 1e-9) * 0.12


def note(midi, dur, vel=1.0):
    src = min(CUT, key=lambda k: abs(k - midi))
    s = load(src)
    r = 2 ** ((midi - src) / 12.0)
    if abs(r - 1) > 1e-3:
        idx = np.arange(0, len(s) - 1, r)
        s = np.interp(idx, np.arange(len(s)), s)
    n = int(dur * SR)
    if n > len(s) - int(0.1 * SR):
        a, b = int(0.3 * len(s)), int(0.85 * len(s))
        x = s[:b].copy()
        xf = int(0.04 * SR)
        while len(x) < n + int(0.2 * SR):
            seg = s[a:b]
            f = np.linspace(0, 1, xf)
            x[-xf:] = x[-xf:] * (1 - f) + seg[:xf] * f
            x = np.concatenate([x, seg[xf:]])
        s = x
    out = s[: n + int(0.08 * SR)].copy()
    out[n:] *= np.linspace(1, 0, len(out) - n)
    return out * vel


def phrase(notes, bpm):
    beat = 60.0 / bpm
    out = np.zeros(int((sum(d for _, d in notes) * beat + 1.5) * SR))
    t = 0.0
    for m, d in notes:
        if m:
            x = note(m, d * beat * 0.92)
            o = int(t * SR)
            out[o:o + len(x)] += x[:len(out) - o]
        t += d * beat
    out = out / np.abs(out).max() * 0.8
    end = np.where(np.abs(out) > 0.004)[0][-1] + int(0.1 * SR)
    return out[:end]


# a short march in B flat (original): pickup, two bars of tune, answer, close
B, C, D, E, F, G, A = 70, 72, 74, 75, 77, 79, 81
TUNE = [(F, 1), (B, 1), (C, 1), (D, 2), (B, 1), (D, 1), (E, 1), (F, 3), (E, 1), (D, 1), (C, 1), (B, 2), (C, 1), (D, 1), (C, 1), (B, 3)]

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cut(sys.argv[1])
    x = phrase(TUNE, 88)
    from scipy.signal import butter, lfilter
    b, a = butter(2, 3200 / (SR / 2))
    x = lfilter(b, a, x) * 0.9
    p = os.path.join(ROOT, "art", "audio_src", "fife", "fife_demo.wav")
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2", p],
                   input=x.astype(np.float32).tobytes(), check=True)
    print(p, "%.1fs" % (len(x) / SR))
