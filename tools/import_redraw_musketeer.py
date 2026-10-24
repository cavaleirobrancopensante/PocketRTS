"""The Musketeer's walk (walk_{s,se,e,ne,n}, 6 frames in every direction) from the image-AI sheet
art/redraws/musketeer_walk.png (docs/animation_audit_units.md).

The sheet has two full 5-direction sets of 6 frames: a "front view" set and a "back view" set,
both of the same man (black slouch hat with a red band and plume, red coat, musket on the
shoulder). Per direction the better one is used:
  s   front set (the back set's "south" row shows his back); its hat has a grey-green plume in
      every frame (a hallucination: the other rows are red): repainted red here
  se  front set (the back set's "south-east" shows the back of his head)
  e   front set
  ne  back set (the front set's "north-east" shows his face)
  n   back set
Every contact pose of the sheet is the same wide stride (no gait), so as for the Officers
(tools/import_redraw_officers.py) the torsos are used frame by frame and the legs are posed again
by tools/redraw_rig.py: a real 6-frame cycle (contact, passing, contact with the other leg ...).
The men are scaled so that hat to soles is as tall as the old walk's (30 px), soles on row 34.

Writes assets/units/musketeer/walk_*.png and the "walk_*" counts in scripts/art_data.gd. Run
after tools/import_round10.py / import_round11.py (see tools/rebuild_art.sh), before
import_vet_trim.py.

Usage (repo root): python3 tools/import_redraw_musketeer.py [--contact DIR]
"""
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import DIRS5, col_boxes, contact, cut, load_sheet, save_strip, to_cell, write_counts  # noqa: E402
from redraw_rig import HIP, front_cycle, side_cycle  # noqa: E402

ROWS = [(178, 305), (330, 453), (483, 605), (639, 758), (795, 919)]
SETS = {"front": (180, 760), "back": (990, 1500)}
SRC = {"s": "front", "se": "front", "e": "front", "ne": "back", "n": "back"}
CELL = (90, 36)
ANCHOR = (45, 35)          # the old walk's soles are on row 34
BODY_H = 30                # hat to soles
STRIDE = 1.15
FRAMES = 6


def sheet_figs():
    px, fg = load_sheet("musketeer_walk")
    out = {}
    for d, (y0, y1) in zip(DIRS5, ROWS):
        a, b = SETS[SRC[d]]
        boxes = col_boxes(fg, y0 - 4, y1 + 4, (a, b), FRAMES)
        out[d] = [cut(px, fg, (x0, y0 - 6, x1, y1 + 6)) for (x0, x1) in boxes]
    return out


def red_plume(fig):
    """The front view's plume, grey-green in the sheet, painted red: of the light-grey blobs in the
    top third of the figure (the hat crown's highlight, the plume, the musket's barrel) the
    right-most one that is not long and thin."""
    a = fig[..., 3] > 0
    rgb = fig[..., :3].astype(int)
    lum = rgb.sum(-1) / 3.0
    ys = np.nonzero(a.any(1))[0]
    top, h = ys.min(), ys.max() - ys.min() + 1
    region = np.zeros_like(a)
    region[top:top + int(0.34 * h)] = True
    grey = a & ((rgb.max(-1) - rgb.min(-1)) < 45) & (lum > 80) & region
    lab, n = ndimage.label(ndimage.binary_closing(grey, structure=np.ones((3, 3))) & region, structure=np.ones((3, 3)))
    best, bx = None, -1
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = lab[sl] == i + 1
        hh, ww = m.shape
        if m.sum() < 25 or max(hh, ww) > 2.4 * min(hh, ww):
            continue
        cx = sl[1].start + ww / 2.0
        if cx > bx:
            best, bx = i + 1, cx
    out = fig.copy()
    if best is not None:
        m = (lab == best) & grey
        t = np.clip(lum[m] / 255.0, 0, 1)
        out[m, 0] = (70 + 190 * t).astype(np.uint8)
        out[m, 1] = (10 + 50 * t * t).astype(np.uint8)
        out[m, 2] = (10 + 50 * t * t).astype(np.uint8)
    return out


def hat_top(f):
    """first row with a broad dark brim (the plume and the bayonet reach higher)"""
    a = f[..., 3] > 0
    lum = f[..., :3].astype(int).sum(-1) / 3.0
    dark = a & (lum < 75)
    rows = np.nonzero(dark.sum(1) >= 14)[0]
    return int(rows.min())


def walk():
    figs = sheet_figs()
    figs["s"] = [red_plume(f) for f in figs["s"]]
    strips = {}
    for d in DIRS5:
        if d in ("s", "n"):
            frames, ground = front_cycle(figs[d], 0, frames=FRAMES)
        else:
            frames, ground = side_cycle(figs[d], 0, frames=FRAMES, stride=STRIDE)
        hs = []
        for f in frames[:1] + frames[3:4]:                      # the contact frames
            hs.append(ground - hat_top(f) + 1)
        sc = BODY_H / float(np.median(hs))
        print("musketeer walk", d, "hat to sole", hs, "scale %.3f" % sc)
        strips[("musketeer", "walk", d)] = [to_cell(f, sc, CELL, ANCHOR, cx=HIP[0], ground=ground) for f in frames]
    return strips


def main():
    cdir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
    strips = walk()
    counts = {}
    for (art, anim, d), cells in strips.items():
        save_strip(art, anim, d, cells)
        counts["%s_%s" % (anim, d)] = len(cells)
    write_counts("musketeer", counts)
    if cdir:
        os.makedirs(cdir, exist_ok=True)
        contact(os.path.join(cdir, "redraw_musketeer.png"), [(k, strips[k]) for k in sorted(strips)], CELL[0], 4)


if __name__ == "__main__":
    main()
