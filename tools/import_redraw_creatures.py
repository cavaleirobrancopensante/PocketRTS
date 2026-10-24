"""The Raptor's and the Grub's walk (walk_{s,se,e,ne,n}, 6 frames in every direction) from the
image-AI sheet art/redraws/raptor_grub_walk.png (docs/animation_audit_units.md).

The sheet has the Raptor on the left and the Grub on the right, 5 rows (s, se, e, ne, n) of 6
frames. The game only had an E strip for both (unit.gd flipped / fell back to it for every other
heading), so every direction other than E is new. One scale per creature (set so that the E row's
body is as long as the old E strip's) is used for all rows, the soles of every frame on the
cell's ground line.

Writes assets/units/{raptor,grub}/walk_*.png and the "walk_*" counts in scripts/art_data.gd. Run
after tools/import_round10.py / import_round11.py (see tools/rebuild_art.sh), before
import_vet_skin.py (the Brood skin masks derive from these strips).

Usage (repo root): python3 tools/import_redraw_creatures.py [--contact DIR]
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import DIRS5, contact, cut, is_red, load_sheet, save_strip, to_cell, write_counts  # noqa: E402

FRAMES = 6
# row bands (sheet y) of s, se, e, ne, n
ROWS = {
    "raptor": [(196, 312), (334, 430), (476, 572), (620, 750), (784, 904)],
    "grub": [(198, 300), (338, 430), (486, 566), (626, 730), (788, 902)],
}
SPAN = {"raptor": (135, 745), "grub": (925, 1520)}
CELL = {"raptor": (58, 30), "grub": (42, 29)}
ANCHOR = {"raptor": (29, 28), "grub": (21, 27)}
# the old E strip's height (px, crest to soles): the new E row is scaled to it, and the other
# rows with the same scale (the other strips of the creature keep their size)
OLD_H = {"raptor": 20.0, "grub": 17.0}


def split_cols(fg, y0, y1, xspan, n, win=30):
    """n column boxes over xspan. The raptor's tail reaches into the previous frame's snout, so
    the figures of a row touch; the boundary between two is put on the column with the fewest
    pixels (the tail alone, a hair) near the midpoint of the two figures."""
    a, b = xspan
    w = (b - a) / float(n)
    cnt = fg[y0:y1].sum(0)
    cuts = [a - 8]
    for i in range(1, n):
        mid = int(round(a + w * i))
        lo, hi = mid - win, mid + win
        seg = cnt[lo:hi]
        j = int(np.argmax(seg <= seg.min() + 1))
        cuts.append(lo + j)
    cuts.append(b + 8)
    return [(cuts[i], cuts[i + 1]) for i in range(n)]


def figs(art):
    px, fg = load_sheet("raptor_grub_walk")
    fg = fg & ~((px[..., 2] > px[..., 1] + 40) & (px[..., 2] > px[..., 0] + 40) & (px[..., 2] > 120))   # row labels
    out = {}
    for d, (y0, y1) in zip(DIRS5, ROWS[art]):
        boxes = split_cols(fg, y0, y1, SPAN[art], FRAMES)
        out[d] = [trim_red(cut(px, fg, (x0, y0 - 4, x1, y1 + 4))) for (x0, x1) in boxes]
    return out


def height(f):
    ys = np.nonzero((f[..., 3] > 0).any(1))[0]
    return ys.max() - ys.min() + 1


def trim_red(f):
    """The next frame's tail tip pokes out in front of the snout as a red speck: red pixels
    right of the right-most non-red pixel are dropped."""
    a = f[..., 3] > 0
    red = is_red(f[..., :3].astype(int), a)
    cols = np.nonzero((a & ~red).any(0))[0]
    out = f.copy()
    out[:, cols.max() + 2:] = 0
    return out


def body_mean(rgba):
    """mean colour of the body (not the red crest, not the yellow claws and belly highlights)"""
    a = rgba[..., 3] > 0
    rgb = rgba[..., :3].astype(int)
    m = a & ~is_red(rgb, a) & ~((rgb[..., 0] > 170) & (rgb[..., 1] > 130))
    return rgb[m].mean(0)


def walk(art):
    F = figs(art)
    sc = OLD_H[art] / float(np.median([height(f) for f in F["e"]]))
    cw = CELL[art][0]
    old = np.asarray(Image.open("assets/units/%s/walk_e.png" % art))     # the kept E strip
    cells_e = [to_cell(f, sc, CELL[art], ANCHOR[art], cx=None, ground=None) for f in F["e"]]
    gain = body_mean(old) / body_mean(np.concatenate(cells_e, 1))
    gain = np.clip(gain, 0.8, 1.5)
    print(art, "scale %.3f" % sc, "colour gain", np.round(gain, 2))
    strips = {}
    for d in DIRS5:
        if d == "e":
            continue                      # the old E strip has the real gait and is kept
        cells = []
        for f in F[d]:
            a = f[..., 3] > 0
            ys, xs = np.nonzero(a)
            c = to_cell(f, sc, CELL[art], ANCHOR[art], cx=(xs.min() + xs.max()) / 2.0, ground=ys.max())
            m = (c[..., 3] > 0) & ~is_red(c[..., :3].astype(int), c[..., 3] > 0)
            c[m, :3] = np.clip(c[m, :3] * gain, 0, 255).astype(np.uint8)
            cells.append(c)
        strips[(art, "walk", d)] = cells
    return strips


def main():
    cdir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
    for art in ("raptor", "grub"):
        strips = walk(art)
        counts = {}
        for (a, anim, d), cells in strips.items():
            save_strip(a, anim, d, cells)
            counts["%s_%s" % (anim, d)] = len(cells)
        counts["walk_e"] = np.asarray(Image.open("assets/units/%s/walk_e.png" % art)).shape[1] // CELL[art][0]
        write_counts(art, counts)
        if cdir:
            os.makedirs(cdir, exist_ok=True)
            contact(os.path.join(cdir, "redraw_%s.png" % art), [(k, strips[k]) for k in sorted(strips)], CELL[art][0], 4)


if __name__ == "__main__":
    main()
