#!/usr/bin/env python3
"""The dismounted Cuirassier (the Armoured Officer on foot, art dismounted_armoured) from the owner's ChatGPT sheets,
one per direction (2026-10-29; backlog: "the dismounted Cuirassier art is bad: redo it so it matches the mounted
Cuirassier"):

  art/redraws/cuirassier_dismounted_<dir>_chatgpt.png   (dir: s, se, e, ne, n; 1536 x 1024, dark slate-navy ground)
      row 1  IDLE         4 frames
      row 2  WALK         6 frames
      row 3  PISTOL SHOT  6 frames; which are the aim and which the shot differs per sheet (SHOT below, by eye):
             s, se, e   1 pistol raised, 2 aiming, 3 firing (flash and smoke), 4-6 lowered / at rest
             ne, n      1 at rest, 2 pistol raised, 3 aiming, 4 firing, 5-6 lowering / at rest

Writes assets/units/dismounted_armoured/<anim>_<dir>.png (the west views are the east ones mirrored by the game):
      idle   4 frames  (row 1)
      walk   6 frames  (row 2; Unit.WALK_CYCLE_ART plays them in the old 8-frame walk's stride time)
      aim    2 frames  (the raise and the aim: the game holds the last one while he aims, Defs.PISTOL "aim")
      fire   3-4 frames (from the flash on: the shot goes off on the strip's first frame)
and their counts in scripts/art_data.gd. Melee and death are left as they were (the old art: a mixed set,
docs/art_style_inconsistency.md).

How: the ground colour is the sheet border's median; a pixel is the man's if it differs from it by more than 24
(the soft shadows under the feet are dropped). Per row, the men are the largest pieces; the flash, the smoke and
any loose bit go with the nearest man. One scale per sheet: helmet top to soles = BODY_H game px (the
median over its idle frames, so every direction comes out the same size; the Musketeer's BODY_H in tools/import_musket_aim_dirs.py; the old strips' helmet
was the same, under a 4 px plume). Every frame: soles on the cell's ground row, centred on the middle of his
breastplate and sash (the median column of the body's middle rows, so a pistol held out or the smoke does not
pull him sideways). Colours: below the head the reds (sash, breeches) are snapped to the team key reds
(import_art.snap_team) and the coat's whites to the Officers' coat whites (recolour_officers.COAT_LIGHT / DARK),
so tools/recolour_officers.py sees the strips as done and tools/import_vet_trim.py finds the coat (it marks the
helmet's comb and brim above it). The old strips' snapshots in art/redraws/officer_white_src are removed for
the strips written here (recolour_officers.py --redo would paint the old art back).

Usage (repo root): python3 tools/import_cuirassier_dismounted.py [--contact FILE]
Then: python3 tools/import_vet_trim.py --only dismounted_armoured; godot --headless --import.
tools/rebuild_art.sh runs it after recolour_officers.py."""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import clean, defringe  # noqa: E402
from redraw_lib import shrink, write_counts  # noqa: E402

SHEET = "art/redraws/cuirassier_dismounted_%s_chatgpt.png"
DIRS = ["s", "se", "e", "ne", "n"]
# the pistol row's frames (0-based) for aim and fire, per sheet (by eye: see the docstring)
SHOT = {"s": ([0, 1], [2, 3, 4, 5]), "se": ([0, 1], [2, 3, 4, 5]), "e": ([0, 1], [2, 3, 4, 5]),
        "ne": ([1, 2], [3, 4, 5]), "n": ([1, 2], [3, 4, 5])}
ART = "dismounted_armoured"
CELL = (90, 36)
ANCHOR = (45, 34)          # art_data's anchor: soles on row 33
BODY_H = 30                # helmet top to soles, game px
COUNTS = [4, 6, 6]         # figures per row on the sheet
HEAD = 9                   # game rows from the helmet's top that are the head (no team or coat colours there)
COAT_LIGHT = (237, 234, 223)       # tools/recolour_officers.py
COAT_DARK = (177, 173, 165)
SNAPS = "art/redraws/officer_white_src/" + ART


def load(d):
    px = np.asarray(Image.open(SHEET % d).convert("RGB")).astype(int)
    b = 6
    edge = np.concatenate([px[:b].reshape(-1, 3), px[-b:].reshape(-1, 3), px[:, :b].reshape(-1, 3), px[:, -b:].reshape(-1, 3)])
    bg = np.median(edge, 0)
    fg = np.abs(px - bg).max(-1) > 24
    return px, fg, bg


def row_bands(fg, n=3):
    """The n bands of rows with figures (top to bottom)."""
    on = fg.sum(1) > 2
    lab, k = ndimage.label(on)
    bands = [(s[0].start, s[0].stop) for s in ndimage.find_objects(lab)]
    bands = [b for b in bands if b[1] - b[0] > 40]
    assert len(bands) == n, bands
    return bands


def figures(px, fg, bg, band, count):
    """The `count` men of one band, left to right: (rgba crop, sole row in the crop)."""
    y0, y1 = band
    sub = fg[y0:y1]
    lab, n = ndimage.label(ndimage.binary_closing(sub, iterations=2) | sub, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lab)
    sizes = ndimage.sum(sub, lab, range(1, n + 1))
    pieces = [(i + 1, sl, int(sizes[i])) for i, sl in enumerate(objs) if sizes[i] >= 20]
    men = sorted(pieces, key=lambda p: -p[2])[:count]
    assert len(men) == count and min(m[2] for m in men) > 0.3 * max(m[2] for m in men), [m[2] for m in men]
    men.sort(key=lambda p: p[1][1].start)
    groups = {m[0]: [m] for m in men}
    for p in pieces:
        if p[0] in groups:
            continue
        cx = (p[1][1].start + p[1][1].stop) / 2.0
        # (a piece right of a man, like the smoke, belongs to him: distance to his box, not his middle)
        best = min(men, key=lambda m: max(0, m[1][1].start - cx, cx - m[1][1].stop))
        groups[best[0]].append(p)
    out = []
    for m in men:
        g = groups[m[0]]
        gy0 = min(p[1][0].start for p in g)
        gy1 = max(p[1][0].stop for p in g)
        gx0 = min(p[1][1].start for p in g)
        gx1 = max(p[1][1].stop for p in g)
        keep = np.isin(lab[gy0:gy1, gx0:gx1], [p[0] for p in g]) & sub[gy0:gy1, gx0:gx1]
        img = np.zeros(keep.shape + (4,), np.uint8)
        img[..., :3] = px[y0 + gy0:y0 + gy1, gx0:gx1]
        img[..., 3] = np.where(keep, 255, 0)
        img = defringe(img, bg.astype(float))
        man = lab[gy0:gy1, gx0:gx1] == m[0]
        ys = np.nonzero(man.any(1))[0]
        out.append({"img": img, "sole": int(ys.max()), "top": int(ys.min()), "man": man})
    return out


def centre(f):
    """The column of his body's middle: the median column of the man's pixels in the rows of his breastplate and
    sash (30% to 55% of his height), the widest outliers (an arm held out) cut."""
    man = f["man"]
    h = f["sole"] - f["top"]
    r0, r1 = f["top"] + int(h * 0.3), f["top"] + int(h * 0.55)
    xs = np.nonzero(man[r0:r1])[1]
    lo, hi = np.percentile(xs, [20, 80])
    return float(np.median(xs[(xs >= lo) & (xs <= hi)]))


def recolour(cell, head_row):
    """Below the head: reds to the team keys, the coat's whites to the Officers' coat whites."""
    body = np.zeros(cell.shape[:2], bool)
    body[head_row:] = True
    part = cell.copy()
    snap_team(part)
    team = body & (part[..., :3] != cell[..., :3]).any(-1)
    cell[team] = part[team]
    rgb = cell[..., :3].astype(int)
    a = cell[..., 3] > 0
    lo, hi = rgb.min(-1), rgb.max(-1)
    white = body & a & (lo >= 150) & (hi - lo <= 40) & ~team
    lum = rgb.mean(-1)
    cell[white & (lum >= 200), :3] = COAT_LIGHT
    cell[white & (lum < 200), :3] = COAT_DARK
    return cell


def to_cell(f, scale):
    small = clean(shrink(f["img"], scale))
    cx = centre(f) * scale
    sole = (f["sole"] + 1) * scale
    out = np.zeros((CELL[1], CELL[0], 4), np.uint8)
    x = int(round(ANCHOR[0] - cx))
    y = int(round(ANCHOR[1] - sole))
    h, w = small.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww, hh = min(w - sx0, CELL[0] - dx0), min(h - sy0, CELL[1] - dy0)
    part = small[sy0:sy0 + hh, sx0:sx0 + ww]
    m = part[..., 3] > 0
    out[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
    head_top = int(round(ANCHOR[1] - (f["sole"] + 1 - f["top"]) * scale))
    return recolour(out, max(0, head_top + HEAD))


def contact_sheet(path, strips):
    rows = [np.concatenate(c, 1) for _k, c in strips]
    W = max(r.shape[1] for r in rows)
    H = sum(r.shape[0] + 2 for r in rows)
    sheet = Image.new("RGBA", (W * 4, H * 4), (104, 132, 84, 255))
    y = 0
    for r in rows:
        im = Image.fromarray(r)
        sheet.alpha_composite(im.resize((im.width * 4, im.height * 4), Image.NEAREST), (0, y * 4))
        y += r.shape[0] + 2
    sheet.save(path)


def strips_of(d):
    aim, fire = SHOT[d]
    return [("idle", 0, [0, 1, 2, 3]), ("walk", 1, [0, 1, 2, 3, 4, 5]), ("aim", 2, aim), ("fire", 2, fire)]


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    strips = []
    counts = {}
    for d in DIRS:
        if os.path.exists(SHEET % d):
            run(d, strips, counts)
        else:
            print("%s: no sheet" % d)
    write_counts(ART, counts)
    if "--contact" in sys.argv:
        contact_sheet(sys.argv[sys.argv.index("--contact") + 1], strips)


def run(d, strips, counts):
    px, fg, bg = load(d)
    bands = row_bands(fg)
    rows = [figures(px, fg, bg, b, n) for b, n in zip(bands, COUNTS)]
    heights = [f["sole"] + 1 - f["top"] for f in rows[0]]
    scale = BODY_H / float(np.median(heights))
    for anim, r, idx in strips_of(d):
        cells = [to_cell(rows[r][i], scale) for i in idx]
        key = "%s_%s" % (anim, d)
        Image.fromarray(np.concatenate(cells, 1)).save("assets/units/%s/%s.png" % (ART, key))
        counts[key] = len(cells)
        strips.append((key, cells))
        snap = os.path.join(SNAPS, key + ".png")
        for p in (snap, snap + ".import"):
            if os.path.exists(p):
                os.remove(p)
    print("%-2s scale %.4f (idle heights %s), aim %s fire %s" % (d, scale, heights, SHOT[d][0], SHOT[d][1]))


if __name__ == "__main__":
    main()
