"""Recruit bites for the Crown, one voice per building (all from the user's real recordings):
town hall = the bugle call Reunir (made by bugle_sampler: trained_1), Barracks = a short fife
phrase, Foundry = kettledrum strokes cut from the timpani solo. Output: assets/voice/crown_recruit/."""
import os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import fife_sampler as FS
ROOT = FS.ROOT
OUT = os.path.join(ROOT, "assets", "voice", "crown_recruit")
SR = FS.SR


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = x / (np.abs(x).max() + 1e-9) * 0.7
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-ac", "2",
                    os.path.join(OUT, name + ".wav")], input=x.astype(np.float32).tobytes(), check=True)


def main():
    from scipy.signal import butter, lfilter
    B, C, D, F = FS.B, FS.C, FS.D, FS.F
    x = FS.phrase([(F, 1), (B, 1), (C, 1), (D, 3)], 96)
    b, a = butter(2, 3200 / (SR / 2))
    save("barracks_1", lfilter(b, a, x) * 0.9)
    src = os.path.join(ROOT, "art", "audio_src", "orchestra", "timpani_solo_clean.ogg")
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", src, "-t", "8", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-"],
                         capture_output=True).stdout
    t = np.frombuffer(raw, np.float32)
    env = np.convolve(np.abs(t), np.ones(320) / 320, "same")
    on = np.where(env > env.max() * 0.5)[0][0] - int(0.03 * SR)
    seg = t[max(on, 0): max(on, 0) + int(1.9 * SR)].copy()
    seg[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))
    save("foundry_1", seg)


if __name__ == "__main__":
    main()
