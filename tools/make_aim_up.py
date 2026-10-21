"""Musketeer frames for shooting at flyers: the aim and fire frames with the barrel swung
up 40 degrees from where it leaves the shoulder, the flash and smoke moved to the new
muzzle. Frames get PAD extra pixels on top (the unit code accounts for taller sheets).
Writes aimup_<dir>.png / fireup_<dir>.png for the musketeer and the armoured musketeer
(round 10: both on the 90 px cell) and registers them in scripts/art_data.gd.
Run after tools/fix_weapons.py:   PYTHONPATH=tools python3 tools/make_aim_up.py [--only kind,kind]
"""
import os
import sys
import re
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from fix_weapons import body_mask, figure

CW = 90
PAD = 22
ANGLE = np.radians(28)


def lift(f):
    """Lean the soldier back from the hips so the whole upper body, the musket with it,
    points up at the sky; the legs stay planted."""
    f = np.concatenate([np.zeros((PAD, f.shape[1], 4), np.uint8), f], 0)
    b, x0, x1, y0, y1, head_bottom = figure(f)
    ys, xs = np.where(f[..., 3] > 40)
    hip_y = int(y0 + (y1 - y0) * 0.62)
    # which way he faces: the musket sticks out further on that side
    bx = np.where(b)[1].mean()
    right = (xs.max() - bx) > (bx - xs.min())
    pivot = np.array([bx, hip_y], float)
    ang = ANGLE * (1 if right else -1)          # anticlockwise on screen when facing right
    c, s_ = np.cos(ang), np.sin(ang)
    out = f.copy()
    out[:hip_y] = 0
    h, w = f.shape[:2]
    for y in range(h):
        for x in range(w):
            dx, dy = x - pivot[0], y - pivot[1]
            # inverse rotation (screen y points down)
            sx = pivot[0] + c * dx - s_ * dy
            sy = pivot[1] + s_ * dx + c * dy
            ix, iy = int(round(sx)), int(round(sy))
            if 0 <= ix < w and 0 <= iy < hip_y and f[iy, ix, 3] > 40:
                if y < hip_y or out[y, x, 3] <= 40:
                    out[y, x] = f[iy, ix]
    return out


KINDS = ["musketeer", "musketeer_armoured"]


def main():
    kinds = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else KINDS
    for kind in kinds:
        if os.path.isdir(f"assets/units/{kind}"):
            make(kind)


def make(kind):
    art = open("scripts/art_data.gd").read()
    added = {}
    for anim in ["aim", "fire"]:
        for d in ["e", "se", "ne", "s", "n"]:
            a = np.array(Image.open(f"assets/units/{kind}/{anim}_{d}.png").convert("RGBA"))
            n = a.shape[1] // CW
            outs = []
            for i in range(n):
                f = a[:, i * CW:(i + 1) * CW]
                if d == "n":   # seen from behind the musket already points up
                    outs.append(np.concatenate([np.zeros((PAD, CW, 4), np.uint8), f], 0))
                else:
                    outs.append(lift(f))
            Image.fromarray(np.concatenate(outs, 1)).save(f"assets/units/{kind}/{anim}up_{d}.png")
            added[f"{anim}up_{d}"] = n
    m = re.search(r'("%s": \{"cell".*?"frames": \{)' % kind, art, re.S)
    start = m.end()
    for k, n in added.items():
        seg = art[start:art.index("}", start)]
        if f'"{k}"' not in seg:
            art = art[:start] + f'\n\t\t"{k}": {n},' + art[start:]
    open("scripts/art_data.gd", "w").write(art)
    print(f"{kind} aim-up frames made:", ", ".join(added))


if __name__ == "__main__":
    main()
