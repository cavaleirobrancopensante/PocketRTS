"""The cocoon-grub sheet draws the grub tan; the game's grub is olive. Shift the tan body
pixels (not the red crest, not the purple cocoon) to the olive grub's hue and lightness.
Run after tools/import_round7.py.  python3 tools/recolour_grub_cocoon.py"""
import colorsys, glob
import numpy as np
from PIL import Image

DH, LK = 0.168 - 0.116, 0.239 / 0.343
for p in glob.glob("assets/units/grub/*cocoon*.png") + glob.glob("assets/units/grub/wrap_*.png"):
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im).astype(float) / 255.0
    out = a.copy()
    h, w = a.shape[:2]
    for y in range(h):
        for x in range(w):
            r, g, b, al = a[y, x]
            if al < 0.5:
                continue
            hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
            if 0.06 < hh < 0.2 and ss > 0.15:        # tan/ochre skin
                hh = hh + DH
                ll = min(1.0, ll * (0.5 + 0.5 * LK) if ll > 0.2 else ll)
                out[y, x, :3] = colorsys.hls_to_rgb(hh, ll, ss)
    Image.fromarray((out * 255).round().astype(np.uint8), "RGBA").save(p)
print("recoloured")
