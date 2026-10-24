"""The mounted units' walk (walk_{ne,se,e,n}) from the three image-AI attempts
art/redraws/mounted_walk_{A,B,C}.png (docs/animation_audit_units.md).

Each sheet has the Dragoon on the left and the Cuirassier on the right: 4 rows (NE, SE, E, N; no S
row) of 6 frames. Per art and direction SRC names the attempt used (or None: the old strip is
kept). The riders are scaled so that they are as tall as the old strips' in that direction (one
factor per art and direction, from the median of the old strip's height), centred on the old
strip's torso column, hooves on the cell's ground line (the lowest hoof of a frame, with the
damped bounce of the sheet's own motion kept: the ground is the median over the frames).

Writes assets/units/{dragoon,cuirassier}/walk_*.png and the "walk_*" counts. dragoon_armoured is a
different rider (the sheet has no armoured Dragoon): its strips are not touched. Run after tools/import_horse_units.py and import_cuirassier_gallop.py (see rebuild_art.sh),
before import_horse_coats.py and import_vet_trim.py (their masks derive from the strips).

Usage (repo root): python3 tools/import_redraw_mounted.py [--contact DIR] [--probe DIR]
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import col_boxes, contact, cut, load_sheet, runs, save_strip, to_cell, write_counts  # noqa: E402

CELL = (98, 70)
ANCHOR = (49, 66)
DIRS4 = ["ne", "se", "e", "n"]
SIDE = {"dragoon": (0, 1085), "cuirassier": (1100, 2172)}
# attempt used per art and direction (see the audit doc for why)
SRC = {
    "dragoon": {"ne": "C", "se": "C", "e": "C", "n": "C"},
    # kept: the sheets' Cuirassier is a brown horse with silver plate, trotting nearly in place;
    # all his other strips have the dark horse and the old gallop is a real one
    "cuirassier": {"ne": None, "se": None, "e": None, "n": None},
}


def sheet_rows(name, art):
    """{dir: [6 figures]} of one half of a sheet"""
    px, fg = load_sheet(name)
    a, b = SIDE[art]
    # row labels, column numbers and the title are light blue text
    txt = (px[..., 2] > px[..., 1] + 40) & (px[..., 2] > px[..., 0] + 40) & (px[..., 2] > 120)
    fg = fg & ~txt
    fg[:, :a] = False
    fg[:, b:] = False
    sub = fg.copy()
    sub[:, :250 if art == "dragoon" else 1330] = False
    rows = [r for r in runs(sub.sum(1) > 0, 8, 40)]
    assert len(rows) == 4, (name, art, rows)
    out = {}
    for d, (y0, y1) in zip(DIRS4, rows):
        xs = np.nonzero(sub[y0:y1].any(0))[0]
        x0, x1 = xs.min(), xs.max() + 1
        boxes = col_boxes(sub, y0, y1, (x0, x1), 6)
        figs = [cut(px, sub, (bx0, y0 - 4, bx1, y1 + 4)) for (bx0, bx1) in boxes]
        out[d] = figs
    return out


# the old strips' rider heights (px, median of the frames; measured before this importer ran)
OLD_H = {
    "dragoon": {"ne": 47.0, "se": 48.0, "e": 47.0, "n": 48.0},
    "cuirassier": {"ne": 51.0, "se": 51.0, "e": 55.0, "n": 51.0},
}


def height(f):
    ys = np.nonzero((f[..., 3] > 0).any(1))[0]
    return ys.max() - ys.min() + 1


def strips(art):
    out = {}
    for d in DIRS4:
        src = SRC[art][d]
        if src is None:
            continue
        figs = sheet_rows("mounted_walk_" + src, art)[d]
        sc = OLD_H[art][d] / float(np.median([height(f) for f in figs]))
        ground = float(np.median([np.nonzero((f[..., 3] > 0).any(1))[0].max() for f in figs]))
        cells = []
        for f in figs:
            a = f[..., 3] > 0
            ys, xs = np.nonzero(a)
            cells.append(to_cell(f, sc, CELL, ANCHOR, cx=(xs.min() + xs.max()) / 2.0, ground=ground))
        print(art, d, src, "scale %.3f" % sc)
        out[(art, "walk", d)] = cells
    return out


def main():
    cdir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
    allstrips = {}
    for art in ("dragoon", "cuirassier"):
        allstrips.update(strips(art))
    for (art, anim, d), cells in allstrips.items():
        save_strip(art, anim, d, cells)
        write_counts(art, {"%s_%s" % (anim, d): len(cells)})
    if cdir:
        os.makedirs(cdir, exist_ok=True)
        contact(os.path.join(cdir, "redraw_mounted.png"), [(k, allstrips[k]) for k in sorted(allstrips)], CELL[0], 3)


if __name__ == "__main__":
    main()
