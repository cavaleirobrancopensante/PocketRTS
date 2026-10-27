"""Technical fixes from the Crown animation audit (docs/animation_audit_crown.md, "What was fixed").

Edits the shipped strips in assets/units/ in place, and the masks that sit beside them (horse coat masks in
assets/units/horse_masks/, veterancy trim masks in assets/units/trim_masks/) by the same amount, so the masks keep
lining up. Every step is idempotent: it measures the strip and only moves what is still off, so running it twice
changes nothing. tools/rebuild_art.sh runs it after the horse coat masks and before import_vet_trim.py.

Usage (repo root): python3 tools/anim_audit/fix_crown.py [--dry]

  1. Officer and Armoured Officer walk, every view: each frame stands on the ground row (33), as their idle does.
     The rigged walk lifted whole frames 1 to 4 px (s and n views most), so the man hopped as he walked and jumped
     up when he started walking.
  2. Armoured Officer aim and fire (s, e, ne): the strip stood 1 to 2 px above his idle; lowered to row 33.
  3. Horseman idle_se: the horse stood 3 px above every other se strip (walk, sabre, pistol), so it bobbed up
     each time it stopped; lowered so its hooves are on row 65 like the others.
  4. Messenger walk_e frames 4 and 5: each cell held parts of two or three riders (the sheet's figures touch).
     Frame 4 is now the first whole rider of that cell, frame 5 the second, each placed where frames 1 to 3 stand.
  5. Mortar idle, every view: frame 2 drew the two gunners somewhere else (both on one side), so at 2 fps the crew
     jumped from side to side twice a second. Frame 2 is now frame 1 (the pose the deploy strip ends on).
  6. Stray pixels: a lone 3 px dash under the Musketeer's muzzle in fireup_e (both frames), nothing near it.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
U = os.path.join(ROOT, "assets/units")
MASKS = ("horse_masks", "trim_masks", "skin_masks")
DRY = "--dry" in sys.argv
DIRS = ["s", "se", "e", "ne", "n"]
log = []


def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def save(path, arr):
    if not DRY:
        Image.fromarray(arr).save(path)


def masks_of(kind, key):
    out = []
    for m in MASKS:
        p = os.path.join(U, m, kind, key + ".png")
        if os.path.exists(p):
            out.append(p)
    return out


def shift_cell(arr, x0, cw, dy, dx=0):
    """Moves the cell [x0, x0 + cw) of arr by (dx, dy) in place (what leaves the cell is dropped)."""
    cell = arr[:, x0:x0 + cw].copy()
    h, w = cell.shape[:2]
    new = np.zeros_like(cell)
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    new[ys0:ys1, xs0:xs1] = cell[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    arr[:, x0:x0 + cw] = new


def bottom(cell):
    ys = np.nonzero((cell[:, :, 3] >= 128).any(1))[0]
    return int(ys.max()) if len(ys) else None


def plant_frames(kind, key, cw, ground, whole=False):
    """Every frame (or, whole=True, the strip as one: its lowest frame) stands on `ground`; masks follow."""
    p = os.path.join(U, kind, key + ".png")
    a = load(p)
    n = a.shape[1] // cw
    bots = [bottom(a[:, i * cw:(i + 1) * cw]) for i in range(n)]
    if whole:
        dys = [ground - max(b for b in bots if b is not None)] * n
    else:
        dys = [0 if b is None else ground - b for b in bots]
    if not any(dys):
        return
    for i, dy in enumerate(dys):
        if dy:
            shift_cell(a, i * cw, cw, dy)
    save(p, a)
    for mp in masks_of(kind, key):
        m = load(mp)
        for i, dy in enumerate(dys):
            if dy:
                shift_cell(m, i * cw, cw, dy)
        save(mp, m)
    log.append(f"{kind}/{key}: frames moved down {dys}")


def officers():
    for kind in ("dismounted", "dismounted_armoured"):
        for d in DIRS:
            plant_frames(kind, "walk_" + d, 90, 33)
    for key in ("aim_s", "aim_e", "aim_ne", "fire_s", "fire_e", "fire_ne"):
        plant_frames("dismounted_armoured", key, 90, 33, whole=True)


def horseman():
    plant_frames("horseman", "idle_se", 98, 65, whole=True)


def messenger():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    key, cw = "walk_e", 98
    p = os.path.join(U, "messenger", key + ".png")
    a = load(p)
    al = a[:, :, 3] > 0
    c3, c4 = al[:, 3 * cw:4 * cw], al[:, 4 * cw:5 * cw]
    # done already? (frame 5 then holds one rider: a gap of empty columns on both sides of it)
    cols5 = np.nonzero(c4.any(0))[0]
    if len(cols5) and cols5.max() - cols5.min() < 60:
        return
    cols4 = np.nonzero(c3.any(0))[0]
    x0, x1 = cols4.min(), cols4.max()
    # the two riders of cell 4 touch: split at the column with the fewest pixels near the middle
    counts = c3.sum(0)
    mid = (x0 + x1) // 2
    lo, hi = mid - 8, mid + 8
    split = lo + int(np.argmin(counts[lo:hi + 1]))
    # where frames 1-3 stand: their left edge in the cell
    lefts = [np.nonzero(al[:, i * cw:(i + 1) * cw].any(0))[0].min() for i in range(3)]
    left = int(round(np.mean(lefts)))
    srcs = [a] + [load(mp) for mp in masks_of("messenger", key)]
    for s in srcs:
        cell4 = s[:, 3 * cw:4 * cw].copy()
        r1 = np.zeros_like(cell4)
        r2 = np.zeros_like(cell4)
        w1 = split - x0 + 1
        w2 = x1 - split
        r1[:, left:left + w1] = cell4[:, x0:split + 1]
        r2[:, left:left + w2] = cell4[:, split + 1:x1 + 1]
        s[:, 3 * cw:4 * cw] = r1
        s[:, 4 * cw:5 * cw] = r2
    # crumbs of the neighbour that crossed the split line (islands of a few px): cleared in the strip and the mask
    from measure_crown import islands
    for f in (3, 4):
        for pts in islands(srcs[0][:, f * cw:(f + 1) * cw, 3] > 0):
            if len(pts) <= 6:
                for py, px in pts:
                    for s in srcs:
                        s[py, f * cw + px] = 0
    save(p, srcs[0])
    for mp, m in zip(masks_of("messenger", key), srcs[1:]):
        save(mp, m)
    log.append(f"messenger/{key}: frames 4-5 = the two whole riders of cell 4 (split at column {split}), left edge {left}")


def mortar():
    cw = 158
    for d in DIRS:
        key = "idle_" + d
        p = os.path.join(U, "mortar", key + ".png")
        a = load(p)
        if np.array_equal(a[:, :cw], a[:, cw:2 * cw]):
            continue
        a[:, cw:2 * cw] = a[:, :cw]
        save(p, a)
        for mp in masks_of("mortar", key):
            m = load(mp)
            m[:, cw:2 * cw] = m[:, :cw]
            save(mp, m)
        log.append(f"mortar/{key}: frame 2 = frame 1")


# (kind, key, cell width, frame (0-based), x, y): a lone stray island's pixel(s); cleared with any island of
# 1 to 3 px that touches the 5x5 square round (x, y) and has no other opaque pixel within 3 px.
SPECKS = [
    ("musketeer", "fireup_e", 90, 0, 79, 45), ("musketeer", "fireup_e", 90, 1, 79, 45),
]
# (the other 1 px islands the audit lists sit within 3 px of the drawing: gaps in a barrel or a leg line, kept)


def specks():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from measure_crown import islands
    for kind, key, cw, fi, x, y in SPECKS:
        p = os.path.join(U, kind, key + ".png")
        a = load(p)
        cell = a[:, fi * cw:(fi + 1) * cw]
        al = cell[:, :, 3] > 0
        gone = 0
        for pts in islands(al):
            if len(pts) > 3:
                continue
            if not any(abs(py - y) <= 2 and abs(px - x) <= 2 for py, px in pts):
                continue
            # nothing else within 3 px
            ring = np.zeros_like(al)
            for py, px in pts:
                ring[max(0, py - 3):py + 4, max(0, px - 3):px + 4] = True
            for py, px in pts:
                ring[py, px] = False
            if (al & ring).any():
                continue
            for py, px in pts:
                cell[py, px] = 0
                gone += 1
        if gone:
            a[:, fi * cw:(fi + 1) * cw] = cell
            save(p, a)
            for mp in masks_of(kind, key):
                m = load(mp)
                mc = m[:, fi * cw:(fi + 1) * cw]
                mc[(cell[:, :, 3] == 0)] = 0
                m[:, fi * cw:(fi + 1) * cw] = mc
                save(mp, m)
            log.append(f"{kind}/{key} f{fi + 1}: {gone} stray px cleared near ({x},{y})")


if __name__ == "__main__":
    officers()
    horseman()
    messenger()
    mortar()
    specks()
    print("\n".join(log) if log else "fix_crown: nothing to do")
