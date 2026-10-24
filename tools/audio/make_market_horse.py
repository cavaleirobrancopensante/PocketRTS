"""From the user's recordings (art/audio_src/city/): the Town Hall's select (a market square bite),
the horse neighs (horse/neigh_1..4: horse selects), the Horse Breeder's recruit (hooves + a neigh)."""
import os, subprocess
import numpy as np
SR = 32000
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "art", "audio_src", "city")
A = os.path.join(ROOT, "assets")


def rd(f, a=0.0, d=None):
    cmd = ["ffmpeg", "-v", "quiet", "-ss", str(a)] + (["-t", str(d)] if d else []) + ["-i", os.path.join(SRC, f), "-f", "f32le", "-ar", str(SR), "-ac", "1", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, np.float32).copy()


def fade(x, a=0.05, b=0.4):
    x = x.copy()
    x[:int(a * SR)] *= np.linspace(0, 1, int(a * SR))
    x[-int(b * SR):] *= np.linspace(1, 0, int(b * SR))
    return x


def norm(x, peak=0.7):
    return x / (np.abs(x).max() + 1e-9) * peak


def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2", path],
                   input=norm(x).astype(np.float32).tobytes(), check=True)


def main():
    # the market square: two quiet bites of the busy parts, long fades so it breathes in and out
    save(os.path.join(A, "audio", "select", "town_hall.wav"), fade(rd("ac9a5b90-medieval-city.wav", 4.2, 2.8), 0.35, 0.9))
    save(os.path.join(A, "audio", "select", "town_hall_1.wav"), fade(rd("ac9a5b90-medieval-city.wav", 13.0, 2.8), 0.35, 0.9))
    for i in range(1, 5):
        save(os.path.join(A, "audio", "horse", "neigh_%d.wav" % i), fade(rd("neigh%d.mp3" % i), 0.01, 0.15))
    g = fade(rd("6dff7504-galop.mp3", 0.3, 2.6), 0.1, 0.8)
    n = fade(rd("neigh1.mp3"), 0.01, 0.2)
    o = np.zeros(int(3.8 * SR))
    o[:len(g)] += g * 0.8
    o[int(1.1 * SR): int(1.1 * SR) + len(n)] += n
    save(os.path.join(A, "voice", "crown_recruit", "horse_breeder_1.wav"), o)


if __name__ == "__main__":
    main()
