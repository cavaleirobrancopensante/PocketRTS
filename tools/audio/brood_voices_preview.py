"""A listening aid: every Brood unit's select, move, attack, death in order, with the in-game gain applied.
python3 tools/audio/brood_voices_preview.py OUT.wav   (writes OUT.txt, the time key, beside it)"""
import os, re, sys
import numpy as np
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
gain = {m.group(1): float(m.group(2)) for m in re.finditer(r'"res://([^"]+)": (-?[\d.]+)', open(os.path.join(ROOT, "scripts/sound_mix.gd")).read())}
UNITS = ["grub", "spitter", "brute", "spore_mother", "bloater", "mist_toad", "skywing", "raptor"]
out, key, t, SR = [], [], 0.0, 44100
gap = np.zeros(int(0.7 * SR))
for u in UNITS:
    ev = []
    for what, n in (("select", 3), ("move", 3), ("attack", 2)):
        for i in range(1, n + 1):
            ev.append((what, f"assets/voice/{u}/{what}_{i}.wav"))
    for i in range(1, 4):
        ev.append(("death", f"assets/audio/combat/{u}_death_{i}.wav"))
    for what, rel in ev:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        sr, x = wavfile.read(p)
        x = x.astype(np.float64) / 32768 * 10 ** (gain.get(rel, 0.0) / 20)
        key.append("%6.1f s  %-13s %-7s %s (%+.1f dB)" % (t, u, what, os.path.basename(rel), gain.get(rel, 0.0)))
        out += [np.clip(x, -1, 1), gap]
        t += (len(x) + len(gap)) / SR
y = np.concatenate(out)
wavfile.write(sys.argv[1], SR, (y * 32767).astype(np.int16))
open(os.path.splitext(sys.argv[1])[0] + "_key.txt", "w").write("\n".join(key) + "\n")
print(len(key), "clips,", round(t), "s")
