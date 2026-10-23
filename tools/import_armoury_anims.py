"""The Armoury's research experiments: the rooftop inventor's nine 6-frame comic experiments, from
the six sheets in art/crown/armoury_anim/ (armour, matchlock, flintlock_caplock, bayonet_pouch,
charges_quadrant, charge) to assets/buildings/armoury_anim_<research id>.png (a 6-frame strip each).

Every sheet is cut into its rows (the widest empty band) and its 6 frames (the 5 widest empty
column gaps of the row: frames differ in width, props and effects stick out), thin divider lines
drawn across a sheet are erased first, the navy is keyed out like import_buildings_v2.py does.
One scale per experiment: the old inventor's ground patch (import_buildings_v2.inventor(): INV_SCALE
of the building sheet's scale) is measured as the widest span of its lowest rows; each experiment
is scaled so ITS patch (the same measure, median over its frames) is that wide in game px, so every
experiment fits the roof like the old one. Every frame's patch (bottom middle: the lowest row,
the middle of the lower rows' extent) is put on the same point of one cell, so nothing jitters;
the grass rim of the patch is taken out like the old strip's; the shirt's reds are snapped to the
team key reds (the game gives the sprite the building's team material), others are unteamed.

Usage (from the repo root): python3 tools/import_armoury_anims.py [--contact DIR]
Prints each strip's cell, the anchor (feet in the cell) for BuildingLife.ARMOURY_ART.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_buildings_v2 as b2  # noqa: E402
from import_art import snap_team, unteam  # noqa: E402
from import_cannon2 import defringe  # noqa: E402
from import_horse_units import load, shrink  # noqa: E402
from import_powder_mill import slate_to_shadow  # noqa: E402

SHEETS = {
    "armour": ["armour"],
    "matchlock": ["matchlock"],
    "flintlock_caplock": ["flintlock", "caplock"],
    "bayonet_pouch": ["bayonet", "pouch"],
    "charges_quadrant": ["charges", "quadrant"],
    "charge": ["charge"],
}
FRAMES = 6
HOLE_MAX = 250        # sheet px: a hole in a frame's mask this small is filled
BAND = 60            # the patch is measured in the lowest BAND px of the old sheet (game px: x INV scale)
RED_MIN = 120        # sheet px: a red patch this big is the man's shirt (team-coloured)
GRASS_MIN = 60       # sheet px: a green patch this big is the patch's grass rim (taken out)
OUT = "assets/buildings/armoury_anim_%s.png"


def erase_dividers(fg):
    """Thin lines drawn across the whole sheet between rows: erased; returns their middle row
    (or None)."""
    h = fg.shape[0]
    full = np.nonzero(fg.mean(1) > 0.97)[0]
    full = full[(full > h * 0.2) & (full < h * 0.8)]
    for y in full:
        fg[max(y - 1, 0):y + 2] = False
    return int(full.mean()) if len(full) else None


def frame_cuts(fg, y0, y1, n=FRAMES):
    occ = fg[y0:y1].any(0)
    w = len(occ)
    gaps, x = [], 0
    while x < w:
        if not occ[x]:
            e = x
            while e < w and not occ[e]:
                e += 1
            if x > 0 and e < w:
                gaps.append((e - x, x, e))
            x = e
        else:
            x += 1
    best = sorted(sorted(gaps, reverse=True)[:n - 1], key=lambda g: g[1])
    if len(best) != n - 1:
        raise SystemExit("cannot find %d frames in a row (%d gaps)" % (n, len(best)))
    xs = [0] + [(g[1] + g[2]) // 2 for g in best] + [w]
    return list(zip(xs[:-1], xs[1:]))


def patch_box(f, kmax):
    """(left, right, bottom) of the ground patch in a frame's mask: the lowest row and the
    extent of the rows within kmax of it."""
    ys = np.nonzero(f.any(1))[0]
    bot = int(ys.max())
    lo = max(int(bot - kmax), 0)
    xs = np.nonzero(f[lo:bot + 1].any(0))[0]
    return xs.min(), xs.max() + 1, bot + 1


def cut_frame(px, fg, bg, y0, y1, x0, x1):
    f = fg[y0:y1, x0:x1]
    f = ndimage.binary_closing(f, iterations=2) | f
    lab, n = ndimage.label(f, structure=np.ones((3, 3)))
    sizes = ndimage.sum(f, lab, range(1, n + 1))
    f = (sizes >= 12)[lab - 1] & (lab > 0)
    # (small holes inside the drawing are filled; big ones, between a man and his prop, stay open)
    holes = ndimage.binary_fill_holes(f) & ~f
    hl, hn = ndimage.label(holes)
    if hn:
        hs = ndimage.sum(holes, hl, range(1, hn + 1))
        f = f | ((hs < HOLE_MAX)[hl - 1] & (hl > 0))
    ys, xs = np.nonzero(f)
    ya, yb, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    img = np.zeros((yb - ya, xb - xa, 4), np.uint8)
    img[..., :3] = px[y0 + ya:y0 + yb, x0 + xa:x0 + xb]
    img[..., 3] = np.where(f[ya:yb, xa:xb], 255, 0)
    img = defringe(img, bg)
    img[..., :3] = slate_to_shadow(img[..., :3], bg)
    return img, f[ya:yb, xa:xb]


def old_reference():
    """The old inventor's patch: its width in game px (median over its frames), and the scale."""
    px, fg, bg = load("buildings_v2/armoury")
    top, bottom = b2.rows_of(fg)
    slabs = b2.quarters(fg[top[0]:top[1]])
    img0 = b2.cut(px, fg, bg, top[0], top[1], *slabs[0])[0]
    bscale = b2.WIDTH["armoury"] / float(img0.shape[1])
    s = bscale * b2.INV_SCALE
    ws = []
    for x0, x1 in frame_cuts(fg, bottom[0], bottom[1]):
        f = fg[bottom[0]:bottom[1], x0:x1]
        lft, rgt, _ = patch_box(f, BAND)
        ws.append(rgt - lft)
    return float(np.median(ws)) * s, s


def solve_scale(masks, wref, kg):
    """Scale at which the median patch width over the frames is wref (game px), the patch
    measured over the lowest kg game px."""
    s = wref / 250.0
    w = 0.0
    for _ in range(8):
        ws = [patch_box(m, kg / s)[1] - patch_box(m, kg / s)[0] for m in masks]
        w = float(np.median(ws))
        s = wref / w
    return s, w * s


def clean_grass(img, keep_y):
    """The patch's grass rim out (like the old strip), then specks not joined to a big piece."""
    c = img[..., :3].astype(int)
    a = img[..., 3] > 0
    g = a & (c[..., 1] > c[..., 0] + 6) & (c[..., 1] > c[..., 2] + 6)
    g[:keep_y] = False                      # (goggle lenses and the like stay)
    lab, n = ndimage.label(ndimage.binary_dilation(g, iterations=3))
    if n:
        sz = ndimage.sum(g, lab, range(1, n + 1))
        g &= (sz >= GRASS_MIN)[lab - 1] & (lab > 0)
    # (the little yellow flowers in the rim go with it: pale yellow right next to the grass)
    flower = a & (c[..., 0] > 120) & (c[..., 1] > 105) & (c[..., 2] < 0.5 * c[..., 1]) & (abs(c[..., 0] - c[..., 1]) < 0.2 * c[..., 1])
    flower[:keep_y] = False
    g |= flower & ndimage.binary_dilation(g, iterations=8)
    img[g] = 0
    a = img[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n:
        sz = ndimage.sum(a, lab, range(1, n + 1))
        img[~((sz >= 25)[lab - 1] & (lab > 0))] = 0
    return img


def team_small(cell, s):
    """Shrink a cell; the shirt's reds team-coloured, any other exact key red nudged."""
    small = shrink(cell, s, 0.4)
    h, w = small.shape[:2]
    c = cell[..., :3].astype(int)
    r, g, bl = c[..., 0], c[..., 1], c[..., 2]
    red = (cell[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (bl <= r * 0.32)
    lab, n = ndimage.label(ndimage.binary_dilation(red, iterations=1))
    mask = np.zeros(red.shape, bool)
    if n:
        sizes = ndimage.sum(red, lab, range(1, n + 1))
        mask = (sizes >= RED_MIN)[lab - 1] & (lab > 0)
    bm = np.array(Image.fromarray((mask * 255).astype(np.uint8)).resize((w, h), Image.BOX)) >= 40
    bm = ndimage.binary_dilation(bm, iterations=1)
    team = snap_team(small.copy())
    plain = unteam(small.copy())
    return np.where(bm[..., None], team, plain).astype(np.uint8)


def main():
    contact = None
    if "--contact" in sys.argv:
        contact = sys.argv[sys.argv.index("--contact") + 1]
        os.makedirs(contact, exist_ok=True)
    wref, s_old = old_reference()
    kg = BAND * s_old
    print("old inventor patch: %.1f game px wide (lowest %.1f px), scale %.4f" % (wref, kg, s_old))
    for sheet, ids in SHEETS.items():
        px, fg, bg = load("armoury_anim/" + sheet)
        div = erase_dividers(fg)
        if len(ids) == 2:
            rows = [(0, div), (div, fg.shape[0])] if div else list(b2.rows_of(fg))
        else:
            rows = [(0, fg.shape[0])]
        for rid, (y0, y1) in zip(ids, rows):
            cuts = frame_cuts(fg, y0, y1)
            raw = []
            for x0, x1 in cuts:
                img, m = cut_frame(px, fg, bg, y0, y1, x0, x1)
                raw.append((img, m))
            s, w = solve_scale([m for _, m in raw], wref, kg)
            frames = []
            for img, m in raw:
                lft, rgt, bot = patch_box(m, kg / s)
                foot = ((lft + rgt) / 2.0, float(bot))
                top_keep = int(m.shape[0] - 0.55 * (rgt - lft))      # grass is only cleared in the patch's rows
                img = clean_grass(img, max(top_keep, 0))
                frames.append((img, foot))
            left = max(f[1][0] for f in frames)
            right = max(f[0].shape[1] - f[1][0] for f in frames)
            up = max(f[1][1] for f in frames)
            down = max(f[0].shape[0] - f[1][1] for f in frames)
            cw, ch = int(np.ceil(left + right)) + 1, int(np.ceil(up + down)) + 1
            cells = []
            for img, foot in frames:
                c = np.zeros((ch, cw, 4), np.uint8)
                ox, oy = int(round(left - foot[0])), int(round(up - foot[1]))
                sub = img[:ch - oy, :cw - ox]
                c[oy:oy + sub.shape[0], ox:ox + sub.shape[1]] = sub
                cells.append(c)
            small = [team_small(c, s) for c in cells]
            strip = b2.join(small)
            Image.fromarray(strip).save(OUT % rid)
            sw, sh = small[0].shape[1], small[0].shape[0]
            print("%-9s scale %.4f patch %.1f px, cell %d x %d, anchor Vector2(%.1f, %.1f)" % (
                rid, s, w, sw, sh, left * s, up * s))
            if contact:
                Image.fromarray(strip).resize((strip.shape[1] * 4, strip.shape[0] * 4), Image.NEAREST).save(
                    os.path.join(contact, "armoury_anim_%s.png" % rid))


if __name__ == "__main__":
    main()
