"""Five options for the Crown Town Hall's select sound, from the user's real recordings."""
import os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import bugle_sampler as BS, fife_sampler as FS, make_bugle as MB
SR = 32000
OUT = sys.argv[1]
HORN = sys.argv[2]
ROOT = FS.ROOT


def rd(path, a, d):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-ss", str(a), "-t", str(d), "-i", path, "-f", "f32le", "-ar", str(SR), "-ac", "1", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.float32).copy()


def fade(x, a=0.03, b=0.5):
    x = x.copy()
    x[:int(a * SR)] *= np.linspace(0, 1, int(a * SR))
    x[-int(b * SR):] *= np.linspace(1, 0, int(b * SR))
    return x


def mix(parts):
    n = max(int(t * SR) + len(x) for t, x in parts)
    o = np.zeros(n)
    for t, x in parts:
        o[int(t * SR): int(t * SR) + len(x)] += x
    return o


def save(name, x):
    x = x / (np.abs(x).max() + 1e-9) * 0.7
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2",
                    os.path.join(OUT, name + ".wav")], input=x.astype(np.float32).tobytes(), check=True)


tim_src = os.path.join(ROOT, "art", "audio_src", "orchestra", "timpani_solo_clean.ogg")
t8 = rd(tim_src, 0, 8)
env = np.convolve(np.abs(t8), np.ones(320) / 320, "same")
on = np.where(env > env.max() * 0.5)[0][0] - int(0.03 * SR)
stroke = t8[max(on, 0): max(on, 0) + int(1.6 * SR)]
stroke = fade(stroke, 0.005, 0.7)
horn1 = fade(rd(HORN, 4.63, 1.4), 0.06, 0.5)       # G4
horn2 = fade(rd(HORN, 0.97, 1.8), 0.06, 0.8)       # D5

# 1 bugle: a rising fourth, the second held
b = BS.soften(BS.play([(MB.G4, 0.5), (MB.C5, 2.2)], 84))
save("1_bugle_rise", b)
# 2 fife: a little flourish
f = FS.phrase([(FS.F, 0.5), (FS.B, 0.5), (FS.D, 1.5)], 92)
from scipy.signal import butter, lfilter
bb, aa = butter(2, 3200 / (SR / 2))
save("2_fife_flourish", lfilter(bb, aa, f))
# 3 timpani: two strokes
save("3_timpani_two", mix([(0, stroke * 0.8), (0.55, stroke)]))
# 4 horn: a rising fifth
save("4_horn_fifth", mix([(0, horn1), (0.7, horn2)]))
# 5 horn over a kettledrum stroke
save("5_horn_and_drum", mix([(0, stroke * 0.9), (0.05, horn1 * 1.2), (0.9, horn2)]))
