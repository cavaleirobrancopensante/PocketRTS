"""Work sounds from the user's recordings (art/audio_src/work/): short BITES, not the whole pieces.
Farm (work/hoe_1..5): shovel_1 is the main sound (two of five), the rest bites of digging and
shovel_2. Construction (work/crown_build, crown_build_1): hammering_2 sped up a little so its
blows fall every 0.40 s (Unit.BUILD_CYCLE) with the first big blow at 0.46 s (Unit.BUILD_CLIP_BLOW),
the labourer's swing is locked to that. make_mix.py then levels them to the game."""
import os, subprocess
import numpy as np
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "art", "audio_src", "work")
OUT = os.path.join(ROOT, "assets", "audio", "work")
SR = 44100


def rd(name, a, d, tempo=1.0):
    cmd = ["ffmpeg", "-v", "quiet", "-ss", str(a), "-t", str(d), "-i", os.path.join(SRC, name + ".mp3")]
    if tempo != 1.0:
        cmd += ["-af", "atempo=%.4f" % tempo]
    cmd += ["-f", "f32le", "-ar", str(SR), "-ac", "1", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, np.float32).copy()


def fade(x, a=0.01, b=0.12):
    x = x.copy()
    x[:int(a * SR)] *= np.linspace(0, 1, int(a * SR))
    x[-int(b * SR):] *= np.linspace(1, 0, int(b * SR))
    return x


def save(name, x, peak=0.8):
    x = x / (np.abs(x).max() + 1e-9) * peak
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", os.path.join(OUT, name + ".wav")],
                   input=x.astype(np.float32).tobytes(), check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    save("hoe_1", fade(rd("shovel_1", 0, 1.15)))
    save("hoe_2", fade(rd("shovel_1", 0, 1.15)))
    save("hoe_3", fade(rd("digging", 1.55, 1.5), 0.02, 0.2))
    save("hoe_4", fade(rd("shovel_2", 1.95, 1.4), 0.02, 0.2))
    save("hoe_5", fade(rd("digging", 4.65, 1.5), 0.02, 0.2))
    t = 1.075                                   # 0.43 s between blows -> 0.40 s
    for name, first in (("crown_build", 0.88), ("crown_build_1", 2.62)):
        start = first - 0.46 * t
        save(name, fade(rd("hammering_2", start, 2.0 * t + 0.05, t)[:int(2.0 * SR)], 0.005, 0.15))


if __name__ == "__main__":
    main()
