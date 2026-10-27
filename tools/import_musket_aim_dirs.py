"""The Musketeer's and the Guardsman's AIM, FIRE and BAYONET toward the south-east, the north-east and the south, from
ChatGPT's one-direction sheets painted over the pose guides of tools/musket_guide/aim_dirs.py (2026-10-27; before them
every view aimed, fired and thrust to the east: docs/animation_audit_crown.md, finding 1).

  art/redraws/<unit>_aim_<dir>_chatgpt.png   (unit: musketeer, musketeer_armoured; dir: se, ne, s)
      one row of seven figures on navy: AIM 1, AIM 2, FIRE 1, FIRE 2, BAYONET 1, BAYONET 2, BAYONET 3 (the flash and
      the smoke of FIRE are pieces of their own beside the man)

Per sheet: the seven men are the seven tallest pieces; every other piece (smoke, a flash, a bayonet tip cut off by the
keying) goes with the man nearest to it. All seven are shrunk by one scale, so that hat to soles (over the middle of the coat: a raised musket is not counted) is BODY_H px like the
Musketeer's walk (tools/import_redraw_musketeer.py), centred on the middle of the red coat (not the musket), soles on
the cell's ground row; the team reds are snapped to the key reds (redraw_lib.to_cell).

Writes assets/units/<unit>/{aim,fire,melee}_<dir>.png (2, 2 and 3 frames, as before). Then run
tools/import_vet_trim.py --only <unit> (the hat's lace or the helmet's comb take the veterancy colour).
  python3 tools/import_musket_aim_dirs.py [unit dir ...]   (default: every sheet that exists) [--contact DIR]"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import contact, cut, is_red, load_sheet, save_strip, to_cell, write_counts  # noqa: E402

CELL = (90, 36)
ANCHOR = (45, 35)          # soles on row 34, as the walk's
BODY_H = 30                # hat to soles, game px
ANIMS = [("aim", 2), ("fire", 2), ("melee", 3)]


def figures(name):
    """The seven figures, left to right, as (rgba crop, the man's sole row in the crop, the man's height)."""
    px, fg = load_sheet(name)
    lab, n = ndimage.label(ndimage.binary_closing(fg, iterations=2) | fg)
    objs = ndimage.find_objects(lab)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    pieces = [(i + 1, sl, int(sizes[i])) for i, sl in enumerate(objs) if sizes[i] >= 30]
    # the men: the seven tallest pieces
    men = sorted(pieces, key=lambda p: -(p[1][0].stop - p[1][0].start))[:7]
    men.sort(key=lambda p: p[1][1].start)
    groups = {p[0]: [p] for p in men}
    for p in pieces:
        if p[0] in groups:
            continue
        cx = (p[1][1].start + p[1][1].stop) / 2.0
        cy = (p[1][0].start + p[1][0].stop) / 2.0
        best = min(men, key=lambda m: abs(cx - (m[1][1].start + m[1][1].stop) / 2.0) + 0.3 * abs(cy - (m[1][0].start + m[1][0].stop) / 2.0))
        groups[best[0]].append(p)
    out = []
    for m in men:
        g = groups[m[0]]
        y0 = min(p[1][0].start for p in g)
        y1 = max(p[1][0].stop for p in g)
        x0 = min(p[1][1].start for p in g)
        x1 = max(p[1][1].stop for p in g)
        keep = np.isin(lab[y0:y1, x0:x1], [p[0] for p in g])
        sub_fg = np.zeros_like(fg)
        sub_fg[y0:y1, x0:x1] = fg[y0:y1, x0:x1] & keep
        img = cut(px, sub_fg, (x0, y0, x1, y1), keep_frac=0.0)
        sole = m[1][0].stop - 1 - y0
        out.append((img, sole, sole - head_top(img)))
    return out


def head_top(img):
    """The top of the man's hat: the highest opaque pixel over the middle of his red coat (a musket raised past his
    head, or the smoke, lies to the side of it), so his height does not count the musket."""
    a = img[..., 3] > 0
    red = is_red(img[..., :3].astype(int), a)
    xs = np.nonzero(red)[1]
    cx = int(np.median(xs)) if len(xs) > 8 else img.shape[1] // 2
    cols = a[:, max(0, cx - 10):cx + 11]
    return int(np.nonzero(cols.any(1))[0].min())


def run(unit, d, contacts=None):
    name = "%s_aim_%s_chatgpt" % (unit, d)
    if not os.path.exists("art/redraws/%s.png" % name):
        return False
    figs = figures(name)
    assert len(figs) == 7, (name, len(figs))
    scale = BODY_H / float(np.median([h for _i, _s, h in figs]))
    k = 0
    strips = []
    for anim, n in ANIMS:
        part = figs[k:k + n]
        # a musket, a bayonet or the smoke above the cell's top (toward the north-east): the strip gets that much room on
        # top for all its frames, as fire_n and aim_n have (the game puts a taller strip's soles on the anchor)
        extra = 0
        for img, sole, _h in part:
            ys = np.nonzero(img[..., 3] > 0)[0]
            above = (sole - ys.min()) * scale - (ANCHOR[1] - 1)
            extra = max(extra, int(np.ceil(above)) + 1)
        cells = [to_cell(img, scale, (CELL[0], CELL[1] + extra), (ANCHOR[0], ANCHOR[1] + extra), ground=sole)
                 for img, sole, _h in part]
        save_strip(unit, anim, d, cells)
        strips.append(("%s_%s" % (anim, d), cells))
        k += n
    write_counts(unit, {"aim_%s" % d: 2, "fire_%s" % d: 2, "melee_%s" % d: 3})
    print("%s %s: scale %.3f, frames %s" % (unit, d, scale, [n for _a, n in ANIMS]))
    if contacts:
        os.makedirs(contacts, exist_ok=True)
        contact(os.path.join(contacts, "%s_aim_%s.png" % (unit, d)), strips, CELL[0])
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    contacts = None
    if "--contact" in sys.argv:
        contacts = sys.argv[sys.argv.index("--contact") + 1]
        args = [a for a in args if a != contacts]
    jobs = [(args[i], args[i + 1]) for i in range(0, len(args), 2)] if args else \
        [(u, d) for u in ("musketeer", "musketeer_armoured") for d in ("se", "ne", "s")]
    for u, d in jobs:
        if not run(u, d, contacts):
            print("%s %s: no sheet yet" % (u, d))


if __name__ == "__main__":
    main()
