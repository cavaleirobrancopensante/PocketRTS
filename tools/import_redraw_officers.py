"""The Officer's and the Armoured Officer's melee and walk strips from the image-AI redraw
sheets in art/redraws/ (see docs/animation_audit_units.md):

  officer_melee.png, armoured_officer_melee.png   4 frames x 5 directions each: wind-up, thrust,
        cut (a bright arc), follow-through, with a long sabre that the importer keeps
  officer_walk_A.png, officer_walk_B.png          an Officer walk and an Armoured Officer walk,
        8 frames x 5 directions each, two attempts

Writes assets/units/dismounted{,_armoured}/{melee,walk}_{s,se,e,ne,n}.png and their frame counts
in scripts/art_data.gd. Run after tools/import_horse_units.py (and before import_vet_trim.py,
import_barracks_props.py: see tools/rebuild_art.sh).

Usage (repo root): python3 tools/import_redraw_officers.py [--contact DIR]
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import (DIRS5, col_boxes, contact, cut, load_sheet, runs, save_strip, to_cell,  # noqa: E402
                        write_counts)
from redraw_rig import HIP, front_cycle, side_cycle  # noqa: E402

CELL = (90, 36)
ANCHOR = (45, 34)
TALL = 48                     # melee strips have headroom for the raised sabre (feet stay put)
TARGET_H = {"dismounted": 33, "dismounted_armoured": 34}      # hat (plume) to boots, as in idle_e


def brown(img):
    rgb = img[..., :3].astype(int)
    a = img[..., 3] > 0
    return a & (rgb[..., 0] > 80) & (rgb[..., 0] - rgb[..., 2] > 50) & (rgb[..., 1] < rgb[..., 0] - 20) & (rgb[..., 0] < 200)


def feet(img):
    """(foot-centre x, boots' bottom row) of a figure: the brown boots' lowest rows."""
    b = brown(img)
    ys, xs = np.nonzero(b)
    bot = ys.max()
    sel = ys >= bot - 10
    return float(xs[sel].mean()), int(bot)


def melee(art, sheet):
    """{dir: [4 figures at sheet size]} and {dir: scale}: the scale makes the upright frames' body
    (hat or plume to boots, frames 2 and 3) as tall as the idle's, in every direction (the sheet
    draws the man 117 to 142 px tall depending on the direction)."""
    px, fg = load_sheet(sheet)
    rows = runs(fg[100:, 240:].sum(1) > 0, 4, 40)
    rows = [(a + 100, b + 100) for a, b in rows]
    assert len(rows) == 5, rows
    out, scale = {}, {}
    for d, (y0, y1) in zip(DIRS5, rows):
        cs = runs(fg[y0:y1, 240:].sum(0) > 0, 3, 8)
        assert len(cs) == 4, (sheet, d, cs)
        cs = [(a + 240, b + 240) for a, b in cs]
        edges = [cs[0][0] - 20] + [(cs[i][1] + cs[i + 1][0]) // 2 for i in range(3)] + [cs[3][1] + 20]
        out[d] = [cut(px, fg, (edges[i], y0 - 6, edges[i + 1], y1 + 6)) for i in range(4)]
        hs = []
        for f in out[d][1:3]:
            ys = np.nonzero((f[..., 3] > 0).any(1))[0]
            hs.append(feet(f)[1] - ys.min() + 1)
        scale[d] = TARGET_H[art] / float(np.mean(hs))
    print(art, "melee scales", {d: round(v, 3) for d, v in scale.items()})
    return out, scale


def split_blade(f, arc=False):
    """(body, blade, arc) of a figure at sheet size: the sabre is the thin light steel the body's
    opening (5 px) leaves, with the dark outline next to it; the arc of the cut is its bluish part."""
    a = f[..., 3] > 0
    rgb = f[..., :3].astype(int)
    lum = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    steel = a & (lum > 140) & (rgb[..., 2] >= rgb[..., 0] - 4)
    thick = ndimage.binary_dilation(ndimage.binary_opening(a, structure=np.ones((5, 5))), iterations=2)
    blade = steel & ~thick
    lab, n = ndimage.label(blade, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(blade, lab, range(1, n + 1))
        blade = (sizes >= 14)[lab - 1] & (lab > 0)
    bluish = blade & (rgb[..., 2] - rgb[..., 0] > 55)
    if arc:
        arcm = ndimage.binary_dilation(bluish, iterations=2) & blade
    else:
        arcm = np.zeros_like(blade)
    sab = blade & ~arcm
    gone = ndimage.binary_dilation(blade, iterations=2) & ~thick & (lum < 160)
    body = f.copy()
    body[blade | gone] = 0
    layer = lambda m: np.where(m[..., None], f, 0).astype(np.uint8)
    return body, layer(sab), layer(arcm)


STEEL = {"back": (238, 242, 250), "edge": (156, 164, 182), "line": (44, 46, 56)}


def render_blade(cell_body, sab, arc):
    """The cell with the sabre drawn over the body: the shrunk blade layer thickened to two
    pixels (bright back, shaded edge) in a dark outline, then the cut's arc as shrunk."""
    out = cell_body.copy()
    t = sab[..., 3] > 0
    if t.any():
        ys, xs = np.nonzero(t)
        w, h = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        dup = np.zeros_like(t)
        if w >= h * 1.4:
            dup[1:] = t[:-1]
        elif h >= w * 1.4:
            dup[:, 1:] = t[:, :-1]
        else:
            dup[1:, :] = t[:-1, :]
        dup &= ~t
        body_a = cell_body[..., 3] > 0
        both = t | dup
        ring = ndimage.binary_dilation(both, structure=ndimage.generate_binary_structure(2, 1)) & ~both & ~body_a
        out[ring, :3] = STEEL["line"]
        out[ring, 3] = 255
        out[dup, :3] = STEEL["edge"]
        out[dup, 3] = 255
        out[t, :3] = STEEL["back"]
        out[t, 3] = 255
    m = arc[..., 3] > 0
    out[m] = arc[m]
    return out


def place_melee(fig, scale, is_cut):
    fx, fb = feet(fig)
    body, sab, arc = split_blade(fig, arc=is_cut)
    kw = dict(cx=fx, ground=fb)
    cell, anchor = (CELL[0], TALL), (ANCHOR[0], ANCHOR[1] + TALL - CELL[1])
    cb = to_cell(body, scale, cell, anchor, **kw)
    cs = to_cell(sab, scale, cell, anchor, keep=0.16, tidy=False, **kw)
    ca = to_cell(arc, scale, cell, anchor, keep=0.22, tidy=False, **kw)
    return render_blade(cb, cs, ca)


# officer_walk_A / _B: row bands (y0, y1) of the five directions and the column spans of the two
# 8-frame sets (the Officer on the left, the Armoured Officer on the right)
WALK_SHEETS = {
    "A": {"rows": [(194, 304), (343, 451), (492, 603), (645, 757), (797, 908)],
          "sets": {"dismounted": (180, 740), "dismounted_armoured": (915, 1510)}},
    "B": {"rows": [(181, 291), (323, 434), (466, 578), (616, 732), (778, 892)],
          "sets": {"dismounted": (180, 740), "dismounted_armoured": (930, 1500)}},
}
# which sheet and which of its figures give the legs (the contact pose with both legs clear)
WALK_SRC = {"dismounted": "A", "dismounted_armoured": "A"}
LEGS_SRC = {"dismounted": "B", "dismounted_armoured": "B"}      # (front and back views only)
STRIDE = 1.2          # the sheet's contact stride, lengthened: a brisk march (the strips slide less)
WALK_TOP = 34         # rows from the cell's top to the soles: the tallest frame (the body rises as a leg straightens)


def walk_figs(sheet, art):
    px, fg = load_sheet("officer_walk_" + sheet)
    spec = WALK_SHEETS[sheet]
    out = {}
    for d, (y0, y1) in zip(DIRS5, spec["rows"]):
        boxes = col_boxes(fg, y0 - 4, y1 + 4, spec["sets"][art], 8)
        out[d] = [cut(px, fg, (a, y0 - 6, b, y1 + 6)) for (a, b) in boxes]
    return out


def walk(art):
    figs = walk_figs(WALK_SRC[art], art)
    legs = walk_figs(LEGS_SRC[art], art)
    strips = {}
    for d in DIRS5:
        if d in ("s", "n"):
            # seen from the front or back the contact poses of sheet A have the boots stuck
            # together: its torsos with the legs of sheet B (boots apart), stepping up and down
            frames, ground = front_cycle(figs[d], 0, legs_fig=legs[d][0])
        else:
            frames, ground = side_cycle(figs[d], 0, alpha=None, stride=STRIDE)
        hs = []
        for f in frames:
            ys = np.nonzero((f[..., 3] > 0).any(1))[0]
            hs.append(ground - ys.min() + 1)
        sc = min(33.0 / float(np.median(hs)), WALK_TOP / float(max(hs)))
        print(art, "walk", d, "heights", hs, "scale %.3f" % sc)
        strips[(art, "walk", d)] = [to_cell(f, sc, CELL, ANCHOR, cx=HIP[0], ground=ground) for f in frames]
    return strips


def main():
    cdir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
    strips = {}
    for art, sheet in (("dismounted", "officer_melee"), ("dismounted_armoured", "armoured_officer_melee")):
        figs, scale = melee(art, sheet)
        for d in DIRS5:
            cells = []
            for i, f in enumerate(figs[d]):
                sc = scale[d]
                if art == "dismounted" and d == "n" and i == 0:
                    # the sheet's wind-up from behind has no sabre (a hallucination): the north-east one
                    f, sc = figs["ne"][0], scale["ne"]
                cells.append(place_melee(f, sc, i == 2))
            strips[(art, "melee", d)] = cells
        strips.update(walk(art))
    counts = {}
    for (art, anim, d), cells in strips.items():
        save_strip(art, anim, d, cells)
        counts.setdefault(art, {})["%s_%s" % (anim, d)] = len(cells)
    for art, c in counts.items():
        write_counts(art, c)
    if cdir:
        os.makedirs(cdir, exist_ok=True)
        for art in counts:
            contact(os.path.join(cdir, "redraw_%s.png" % art),
                    [(k, strips[k]) for k in sorted(strips) if k[0] == art], CELL[0], 4)


if __name__ == "__main__":
    main()
