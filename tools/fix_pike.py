"""Pikeman thrust sheets: the second frame (pulling back after the thrust) was drawn with a
pike far shorter than in every other frame. Replace it with the first frame drawn 4 px back,
so the pike keeps its length. Run after tools/import_art.py."""
from PIL import Image
import numpy as np

CW = 68
for d in ["e", "se", "ne", "s", "n"]:
    p = f"assets/units/pikeman/thrust_{d}.png"
    a = np.array(Image.open(p).convert("RGBA"))
    n = a.shape[1] // CW
    if n < 2:
        continue
    def width(i):
        xs = np.where(a[:, i * CW:(i + 1) * CW, 3].max(0) > 40)[0]
        return xs.max() - xs.min()
    if width(1) < width(0) * 0.8:
        f0 = a[:, 0:CW].copy()
        moved = np.zeros_like(f0)
        moved[:, :-4] = f0[:, 4:]
        a[:, CW:2 * CW] = moved
        Image.fromarray(a).save(p)
        print("fixed", p)
