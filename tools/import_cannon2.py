"""Build the Crown's Field Cannon sprite set from the three ChatGPT sheets
art/crown/cannon2_front.png, cannon2_side.png and cannon2_angles.png.

The sheets are inconsistent (horses that come and go, two guns in one frame, crew
counts that change), so every frame is picked by hand in the tables below, cut out,
cleaned, scaled to the musketeers' size and, where needed, combined from parts of
several source frames. Output: assets/units/cannon/<anim>_<dir>.png strips that share
one cell size and one anchor (the ground point under the gun's axle), and the
"cannon" entry of scripts/art_data.gd.

Usage (from the repo root): python3 tools/import_cannon2.py [--debug DIR]
Needs Pillow, NumPy and SciPy.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import TEAM_DARK, TEAM_LIGHT, load  # noqa: E402

SHEETS = {k: f"art/crown/cannon2_{k}.png" for k in ("front", "side", "angles")}
OUT = "assets/units/cannon"
DIRS = ["s", "se", "e", "ne", "n"]


# ---------------------------------------------------------------- cutting out

def bg_mask(px):
    """Background of a flat slate sheet, including the soft slate-blue ground shadows
    (same hue as the background, only darker). Flooded in from the border, so dark
    outlines stop it; enclosed pockets of plain background (between spokes and legs)
    are removed too."""
    rgb = px[..., :3].astype(float)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bgc = np.median(border, 0)
    near = np.abs(rgb - bgc).max(-1) <= 13
    # shadow: a darker copy of the background colour
    k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
    resid = np.abs(rgb - k[..., None] * bgc).max(-1)
    shadow = (k >= 0.38) & (k <= 1.08) & (resid <= 7 + 6 * k)
    cand = near | shadow
    lab, n = ndimage.label(cand)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    # enclosed pockets of exact background colour (not shadow: dark paint inside sprites)
    lab2, n2 = ndimage.label(near & ~bg)
    if n2:
        idx = np.arange(1, n2 + 1)
        size = ndimage.sum(near, lab2, idx)
        pocket = size >= 6
        bg |= pocket[lab2 - 1] & (lab2 > 0)
    return bg, bgc


def groups(fg, dilate=6, min_area=400):
    """Connected sprite groups (pieces within `dilate` px merged)."""
    grown = ndimage.binary_dilation(fg, iterations=dilate)
    lab, n = ndimage.label(grown)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = (lab[sl] == i + 1) & fg[sl]
        if m.sum() < min_area:
            continue
        out.append({"y0": sl[0].start, "y1": sl[0].stop, "x0": sl[1].start, "x1": sl[1].stop,
                    "area": int(m.sum())})
    return out


if __name__ == "__main__" and "--list" in sys.argv:
    for name, path in SHEETS.items():
        px = load(path)
        bg, bgc = bg_mask(px)
        gs = groups(~bg)
        gs.sort(key=lambda g: (round((g["y0"] + g["y1"]) / 2 / 205), g["x0"]))
        print(name, bgc)
        for g in gs:
            print("   ", g)
