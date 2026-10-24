"""The Crown's bugle calls played from REAL bugle recordings (art/audio_src/bugle/, the user's
'Bugle Calls: every bugle call' compilation): one clean long note per harmonic is cut out once
(art/audio_src/bugle/notes/), then each call of the Manual de Toques is played from them, notes
held longer than the recording are looped in their steady part.
  python3 tools/audio/bugle_sampler.py <compilation.mp3>   (cuts the notes; first time only)
  python3 tools/audio/bugle_sampler.py                     (renders assets/voice/crown_bugle/*.wav)"""
import os, sys, subprocess
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import make_bugle as MB

SR = MB.SR
ROOT = MB.ROOT
NOTES = os.path.join(ROOT, "art", "audio_src", "bugle", "notes")
# the compilation's cleanest long note of each harmonic (start s, length s)
CUT = {"h2": (301.26, 2.4), "h3": (146.26, 1.0), "h4": (53.2, 1.6), "h5": (274.25, 2.9), "h6": (283.4, 2.1)}
HARM = {MB.G3: "h2", MB.G4: "h3", MB.C5: "h4", MB.E5: "h5", MB.G5: "h6"}


def cut(src):
    os.makedirs(NOTES, exist_ok=True)
    for k, (a, d) in CUT.items():
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-ss", str(a - 0.03), "-t", str(d + 0.03), "-i", src,
                        "-ac", "1", "-ar", str(SR), os.path.join(NOTES, k + ".wav")], check=True)


def load(k):
    import wave
    w = wave.open(os.path.join(NOTES, k + ".wav"))
    x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float) / 32768
    x = x[int(0.01 * SR):]
    body = x[int(0.15 * SR): int(0.6 * SR)]
    return x / (np.sqrt((body ** 2).mean()) + 1e-9) * 0.12


def note(k, dur, vel):
    s = load(k)
    n = int(dur * SR)
    if n > len(s) - int(0.1 * SR):                 # hold longer than the recording: loop the steady part
        a, b = int(0.3 * len(s)), int(0.85 * len(s))
        x = list(s[:b])
        xf = int(0.05 * SR)
        while len(x) < n + int(0.2 * SR):
            seg = s[a:b].copy()
            y = np.array(x)
            f = np.linspace(0, 1, xf)
            y[-xf:] = y[-xf:] * (1 - f) + seg[:xf] * f
            x = list(y) + list(seg[xf:])
        s = np.array(x)
    out = s[: n + int(0.12 * SR)].copy()
    out[n:] *= np.linspace(1, 0, len(out) - n) if len(out) > n else 1
    out[:int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return out * vel


def play(notes, bpm):
    beat = 60.0 / bpm
    total = sum(d for _, d in notes) * beat + 0.4
    out = np.zeros(int((total + 1.2) * SR))
    t0 = 0.0
    for i, (m, d) in enumerate(notes):
        if m is not None:
            x = note(HARM[m], max(0.09, d * beat * 0.95), 1.0 if (i == 0 or d >= 1.0) else 0.9)
            o = int(t0 * SR)
            out[o: o + len(x)] += x[: len(out) - o]
        t0 += d * beat
    out = out / (np.abs(out).max() + 1e-9) * 0.8
    end = np.where(np.abs(out) > 0.004)[0][-1] + int(0.1 * SR)
    out = out[:end]
    out[-int(0.15 * SR):] *= np.linspace(1, 0, int(0.15 * SR))
    return out


def main():
    if len(sys.argv) > 1:
        cut(sys.argv[1])
    for name, (notes, bpm) in MB.CALLS.items():
        x = play(notes, bpm)
        p = os.path.join(MB.OUT, name + ".wav")
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2", p],
                       input=x.astype(np.float32).tobytes(), check=True)
        print(name, "%.1fs" % (len(x) / SR))


if __name__ == "__main__":
    main()
