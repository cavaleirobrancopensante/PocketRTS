"""The Horse Breeder from art/crown/horse_breeder.png: four building states left to right
(built, construction, damaged, destroyed), a stable with a fenced paddock, a trough and horses
inside, on a flat slate background.

Each state is found by its empty columns, keyed out (the slate and its shadows), scaled so the
built stable is as wide as the building's footprint (Defs: 4x3 tiles, 128 px; the other states
by the same factor) and its red banner snapped to the team key reds. The build icon is the
built state on the Cottage icon's frame.

Output: assets/buildings/horse_breeder_{built,construction,damaged,destroyed}.png and
assets/icons/horse_breeder.png.
Usage (from the repo root): python3 tools/import_horse_breeder.py
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import defringe  # noqa: E402
from import_horse_units import load, runs, shrink  # noqa: E402

STATES = ["built", "construction", "damaged", "destroyed"]
WIDTH = 132          # the built stable's width in the game (the footprint is 128 px)


def main():
    px, fg, bg = load("horse_breeder")
    fg = ndimage.binary_closing(fg, iterations=2) | fg
    cols = [c for c in runs(fg.sum(0) > 0, 12) if c[1] - c[0] > 100]
    assert len(cols) == 4, "%d states found" % len(cols)
    imgs = []
    for x0, x1 in cols:
        m = fg[:, x0:x1]
        lab, n = ndimage.label(m, structure=np.ones((3, 3)))
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = (sizes >= 0.01 * sizes.max())[lab - 1] & (lab > 0)
        m = ndimage.binary_fill_holes(m)
        ys = np.nonzero(m.any(1))[0]
        img = np.zeros((ys.max() - ys.min() + 1, x1 - x0, 4), np.uint8)
        img[..., :3] = px[ys.min():ys.max() + 1, x0:x1]
        img[..., 3] = np.where(m[ys.min():ys.max() + 1], 255, 0)
        imgs.append(defringe(img, bg))
    scale = WIDTH / float(imgs[0].shape[1])
    for st, img in zip(STATES, imgs):
        small = snap_team(shrink(img, scale, 0.45))
        Image.fromarray(small).save("assets/buildings/horse_breeder_%s.png" % st)
        print(st, small.shape[1], "x", small.shape[0])
    # the build icon: the built stable on the Cottage icon's frame
    icon = np.asarray(Image.open("assets/icons/cottage.png").convert("RGBA")).copy()
    inner = icon[6, 6].copy()
    icon[4:60, 4:60] = inner
    b = imgs[0]
    s = 54.0 / max(b.shape[0], b.shape[1])
    pic = snap_team(shrink(b, s, 0.45))
    h, w = pic.shape[:2]
    oy, ox = 5 + (54 - h) // 2, 5 + (54 - w) // 2
    m = pic[..., 3] > 0
    icon[oy:oy + h, ox:ox + w][m] = pic[m]
    Image.fromarray(icon).save("assets/icons/horse_breeder.png")


if __name__ == "__main__":
    main()
