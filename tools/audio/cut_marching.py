"""Cuts the Crown army-select sound (a bite of marching feet) from art/audio_src/marching/feet.mp3
into assets/voice/crown_army/select_1..2.wav. Run: python3 tools/audio/cut_marching.py
(then tools/audio/make_mix.py to level it, and godot --headless --import)."""
import os, subprocess
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "art", "audio_src", "marching", "feet.mp3")
OUT = os.path.join(ROOT, "assets", "voice", "crown_army")
SR = 22050
BITE = 3.4


def load():
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", SRC, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def best_windows(x, n=2):
    """The n loudest, steadiest BITE-second windows that don't overlap (steady = even step energy)."""
    hop = SR // 10
    env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
    w = int(BITE * 10)
    score = [(np.mean(env[i:i + w]) - 0.6 * np.std(env[i:i + w]), i) for i in range(0, len(env) - w)]
    out, taken = [], []
    for sc, i in sorted(score, reverse=True):
        if all(abs(i - t) > w for t in taken):
            out.append(i / 10.0)
            taken.append(i)
        if len(out) == n:
            break
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    x = load()
    for k, t0 in enumerate(best_windows(x), 1):
        seg = x[int(t0 * SR): int((t0 + BITE) * SR)].copy()
        fi, fo = int(0.04 * SR), int(0.7 * SR)
        seg[:fi] *= np.linspace(0, 1, fi)
        seg[-fo:] *= np.linspace(1, 0, fo) ** 1.5
        seg *= 0.9 / (np.abs(seg).max() + 1e-9)
        p = os.path.join(OUT, "select_%d.wav" % k)
        subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-ac", "2", p], input=seg.astype(np.float32).tobytes(), check=True)
        print(p, "from %.1fs" % t0)


if __name__ == "__main__":
    main()
