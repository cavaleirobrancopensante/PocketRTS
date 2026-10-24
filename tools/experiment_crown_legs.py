"""EXPERIMENT (nothing installed): the labourer's new walk legs under other Crown foot units' bodies.
Writes /tmp/crown_legs_<unit>.png: for each view, the current walk strip above the same strip with the
labourer's legs pasted under the unit's coat (import_labourer_redraw.compose on a 42x35 window around the
unit's anchor). Usage: python3 tools/experiment_crown_legs.py [unit ...]"""
import os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import import_labourer_redraw as R
U = os.path.join(ROOT, "assets/units")
# unit: (cell w, cell h, anchor x, anchor y, frames used from the 6 labourer frames)
UNITS = {"musketeer": (90, 36, 45, 34, [0,1,2,3,4,5]), "musketeer_armoured": (90, 36, 45, 34, [0,1,2,3,4,5]),
         "dismounted": (90, 36, 45, 34, [0,1,2,3,4,5]), "pikeman": (68, 66, 34, 64, [0,2,3,5]),
         "missionary": (48, 40, 24, 38, [0,2,3,5])}
DIRS = ["s", "se", "e", "ne", "n"]
Z = 4

def frames(path, cw):
    im = np.array(Image.open(path).convert("RGBA")); return [im[:, i*cw:(i+1)*cw].copy() for i in range(im.shape[1]//cw)]

GUN_ROWS = 3            # rows under the coat hem in which the musket's butt and the hands are kept


def keep_gun(body, new):
    """R.compose drops everything under the coat hem that is not red or skin: the musket's stock and the hands that
    hold it. Put those back (coloured pixels only: wood, gold, skin; grey trousers and outlines stay out) over the
    new legs, as a musket held in front of the body should be."""
    cut = R.hem_row(body) + 1
    out = new.copy()
    seg = body[cut:cut + GUN_ROWS]
    r, g, b = [seg[..., i].astype(int) for i in range(3)]
    spread = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    m = (seg[..., 3] > 0) & (spread > 22)
    tgt = out[cut:cut + GUN_ROWS]
    tgt[m] = seg[m]
    return out


def swap(fr, leg, ax, ay):
    x0, y0 = ax - 21, ay - 33          # the window's top-left in the unit's cell
    win = np.zeros((35, 42, 4), np.uint8)
    sx0, sy0 = max(0, x0), max(0, y0)
    sub = fr[sy0:y0+35, sx0:x0+42]; win[sy0-y0:sy0-y0+sub.shape[0], sx0-x0:sx0-x0+sub.shape[1]] = sub
    new = R.compose(win, leg)
    new = keep_gun(win, new)
    out = fr.copy()
    out[sy0:y0+35, sx0:x0+42][:sub.shape[0], :sub.shape[1]] = new[sy0-y0:sy0-y0+sub.shape[0], sx0-x0:sx0-x0+sub.shape[1]]
    return out

def main():
    units = sys.argv[1:] or list(UNITS)
    for u in units:
        cw, ch, ax, ay, use = UNITS[u]
        rows = []
        for d in DIRS:
            f = frames(f"{U}/{u}/walk_{d}.png", cw); lab = frames(f"{U}/labourer/walk_{d}.png", 42)
            n = len(f)
            u_ = [int(round(k * 6.0 / n)) % 6 for k in range(n)]
            rows.append(f); rows.append([swap(f[k], lab[u_[k]], ax, ay) for k in range(n)])
        n = max(len(r) for r in rows)
        sheet = Image.new("RGBA", (n*cw*Z, len(rows)*ch*Z), (60, 90, 60, 255))
        for r, fr in enumerate(rows):
            for k, f in enumerate(fr):
                sheet.alpha_composite(Image.fromarray(f).resize((cw*Z, ch*Z), Image.NEAREST), (k*cw*Z, r*ch*Z))
        sheet.save(f"/tmp/crown_legs_{u}.png"); print(u, sheet.size)
if __name__ == "__main__":
    main()
