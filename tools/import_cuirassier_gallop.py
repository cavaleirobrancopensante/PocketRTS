"""The Crown Cuirassier's side-view gallop (walk_e; W is the game's mirror of E).

Source: art/crown/cuirassier_gallop_e.png - one row of 8 frames galloping right in pure
side profile on a flat slate background. (The E row of cuirassier.png turns toward the
camera, so import_round4.py only leaves a stand-in walk_e for this pass to replace.)

Each frame is found by connected components (the spacing varies): the 8 biggest pieces
are the horses, and every other piece (tails and hooves drawn apart, stray specks) joins
the nearest horse, or is dropped when far from all of them. The frames are then cut out
with the same helpers as round 4 (slate mask, defringe, box-filter downscale, snap_team
so the red coat and saddle cloth take the team colour) and placed on the cuirassier's
existing cell:

  scale     one factor for all frames, so the horse's body (rump to chest, and helmet to
            belly) is the size of idle_e frame 0's
  x         every frame's crop is centred on its saddle cloth (the red below the rider's
            waist), so the body doesn't slide while the legs swing; the saddle lands on
            idle_e's saddle
  y         the sheet's own ground line goes on the anchor line, keeping the small bob
            the art has (the lowest hoof of the cycle stands on the anchor)

Output: assets/units/cuirassier/walk_e.png (8 cells) and its "walk_e" count in the
cuirassier entry of scripts/art_data.gd (nothing else is touched).

Usage (from the repo root, after import_round4.py): python3 tools/import_cuirassier_gallop.py
       [--contact DIR [--old OLD_WALK_E.png]]  (x3 contact sheet: [old walk_e,] idle_e,
       new walk_e, walk_se)
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load  # noqa: E402
from import_cannon2 import clean, defringe, shrink, snap_team  # noqa: E402
from import_round4 import contact_sheet  # noqa: E402

SRC = "art/crown/cuirassier_gallop_e.png"
OUT = "assets/units/cuirassier"
ART_DATA = "scripts/art_data.gd"
N = 8
ORDER = list(range(N))          # play order of the sheet's frames (left to right)
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
OLD = sys.argv[sys.argv.index("--old") + 1] if "--old" in sys.argv else None


def cell_info():
    src = open(ART_DATA).read()
    m = re.search(r'"cuirassier": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    return (int(m.group(1)), int(m.group(2))), (float(m.group(3)), float(m.group(4)))


def slate_mask(px, tol=14):
    """Background: the flat slate within tol, flooded in from the border, plus big enclosed
    pockets of it (small ones are the horse's own blue-grey darks). Unlike import_cannon2.bg_mask there is no ground shadow
    to take, and its shadow test would eat the grey horse's bluish darks (tail, legs)."""
    rgb = px[..., :3].astype(float)
    bgc = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), 0)
    near = np.abs(rgb - bgc).max(-1) <= tol
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    lab2, n2 = ndimage.label(near & ~bg)
    if n2:
        size = ndimage.sum(near, lab2, np.arange(1, n2 + 1))
        bg |= (size >= 200)[lab2 - 1] & (lab2 > 0)
    return bg, bgc


def to_game(img, scale, bgc):
    """Source crop -> game-size RGBA: box-filter shrink, team reds snapped, slate fringe
    and specks removed. defringe also takes the dark blue-grey edge of this grey horse
    (tail, legs) for slate, so only the light (mostly slate) edge pixels it finds go."""
    out = snap_team(shrink(img, scale))
    d = defringe(out, bgc)
    rgb = out[..., :3].astype(float)
    k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
    lost = (out[..., 3] > 0) & (d[..., 3] == 0) & (k < 0.75)
    d[lost] = out[lost]
    return clean(d, min_size=4, keep_near=1)


def frames_of(fg):
    """Per-frame masks: the N biggest pieces, every other piece added to the nearest."""
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    main = np.argsort(-size)[:N] + 1
    objs = ndimage.find_objects(lab)
    main = sorted(main, key=lambda i: objs[i - 1][1].start)       # left to right
    masks = [lab == i for i in main]
    # distance from every pixel to each horse
    dist = np.stack([ndimage.distance_transform_edt(~m) for m in masks])
    for i in range(1, n + 1):
        if i in main or size[i - 1] < 4:
            continue
        piece = lab == i
        d = dist[:, piece].min(1)
        k = int(d.argmin())
        if d[k] <= 24:              # tails / hooves drawn apart; farther = a speck
            masks[k] |= piece
    return masks


def saddle_x(px, m):
    """x of the saddle cloth's middle: the red under the rider's waist."""
    rgb = px[..., :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    red = m & (r >= 95) & (g <= r * 0.32) & (b <= r * 0.34)
    ys = np.flatnonzero(m.any(1))
    top, bot = ys.min(), ys.max()
    red[:top + int((bot - top) * 0.42)] = False      # the coat is above, the cloth below
    yy, xx = np.nonzero(red)
    return float(xx.mean())


def red_box(img):
    """Box (x0, y0, x1, y1) of the team colours under the rider's waist (the cloth)."""
    a = img[..., 3] > 0
    team = a & (((img[..., 0] == 255) | (img[..., 0] == 150)) & (img[..., 1] == 0) & (img[..., 2] == 0))
    ys = np.flatnonzero(a.any(1))
    top, bot = ys.min(), ys.max()
    team[:top + int((bot - top) * 0.42)] = False
    yy, xx = np.nonzero(team)
    return xx.min(), yy.min(), xx.max() + 1, yy.max() + 1


def body_size(img):
    """(body length, body height) of a side-view horseman: length = the horse's run from
    rump to chest (the middle of the rows through the lower half of the saddle cloth);
    height = helmet top to the bottom of the cloth."""
    a = ndimage.binary_fill_holes(img[..., 3] > 0)
    x0, y0, x1, y1 = red_box(img)
    cx = (x0 + x1) // 2
    lens = []
    for y in range((y0 + y1) // 2, y1):
        row = a[y]
        if not row[cx]:
            continue
        l = cx
        while l > 0 and row[l - 1]:
            l -= 1
        r = cx
        while r < len(row) - 1 and row[r + 1]:
            r += 1
        lens.append(r - l + 1)
    top = np.flatnonzero(a.any(1)).min()
    return float(np.median(lens)), float(y1 - top)


def main():
    (W, H), (AX, AY) = cell_info()
    px = load(SRC)
    bg, bgc = slate_mask(px)
    fg = ~bg
    masks = frames_of(fg)
    ground = max(np.flatnonzero(m.any(1)).max() + 1 for m in masks)    # the sheet's ground line
    top = min(np.flatnonzero(m.any(1)).min() for m in masks)
    sx = [saddle_x(px, m) for m in masks]
    half = int(max(max(np.flatnonzero(m.any(0)).max() + 1 - c, c - np.flatnonzero(m.any(0)).min())
                   for m, c in zip(masks, sx))) + 4
    y0, y1 = top - 4, ground + 4

    def crops(scale):
        out = []
        for m, c in zip(masks, sx):
            x0 = int(round(c)) - half
            img = np.zeros((y1 - y0, 2 * half, 4), np.uint8)
            xa, xb = max(0, x0), min(px.shape[1], x0 + 2 * half)
            sub = px[y0:y1, xa:xb].astype(np.uint8)
            mm = m[y0:y1, xa:xb]
            sub[..., 3] = np.where(mm, 255, 0)
            sub[~mm] = 0
            img[:, xa - x0:xb - x0] = sub
            out.append(to_game(img, scale, bgc))
        return out

    # scale: match idle_e frame 0's body (rump-chest length and helmet-belly height)
    idle = np.array(Image.open(f"{OUT}/idle_e.png").convert("RGBA"))[:, :W]
    il, ih = body_size(idle)
    trial = 0.25
    sizes = np.array([body_size(f) for f in crops(trial)])
    gl, gh = np.median(sizes, 0)
    scale = trial * float(np.sqrt((il / gl) * (ih / gh)))
    frames = crops(scale)
    sizes = np.array([body_size(f) for f in frames])
    print("per frame", sizes.round(1).tolist())
    print(f"idle_e body {il:.0f} x {ih:.0f}; gallop scale {scale:.4f}, body "
          f"{np.median(sizes[:, 0]):.1f} x {np.median(sizes[:, 1]):.1f}")

    # placement: crop centre (saddle) on idle_e's saddle, sheet ground on the anchor line
    ix0, _, ix1, _ = red_box(idle)
    isx = (ix0 + ix1) / 2.0
    fh, fw = frames[0].shape[:2]
    gy = (ground - y0) * fh / float(y1 - y0)           # ground line in the game crop
    ox = int(round(isx - fw / 2.0))
    oy = int(round(AY - gy))
    strip = np.zeros((H, W * N, 4), np.uint8)
    for k, i in enumerate(ORDER):
        f = frames[i]
        cell = np.zeros((H, W, 4), np.uint8)
        ya, yb = max(0, oy), min(H, oy + fh)
        xa, xb = max(0, ox), min(W, ox + fw)
        part = f[ya - oy:yb - oy, xa - ox:xb - ox]
        assert (f[..., 3] > 0).sum() == (part[..., 3] > 0).sum(), "frame doesn't fit the cell"
        cell[ya:yb, xa:xb] = part
        strip[:, k * W:(k + 1) * W] = cell
    Image.fromarray(strip).save(f"{OUT}/walk_e.png")
    bottoms = [int(np.flatnonzero((strip[:, k * W:(k + 1) * W, 3] > 0).any(1)).max()) + 1 for k in range(N)]
    print(f"walk_e: {N} frames, hoof lines {bottoms} (anchor {AY:g})")

    src = open(ART_DATA).read()
    m = re.search(r'\t"cuirassier": \{"cell".*?\n\t\}\},\n', src, re.S)
    block = re.sub(r'"walk_e": \d+,', f'"walk_e": {N},', m.group(0))
    open(ART_DATA, "w").write(src[:m.start()] + block + src[m.end():])

    if CONTACT:
        os.makedirs(CONTACT, exist_ok=True)

        def cells(a):
            return [a[:, i * W:(i + 1) * W].copy() for i in range(a.shape[1] // W)]

        def marked(fr):
            fr[int(AY), max(0, int(AX) - 2):int(AX) + 3] = (255, 255, 255, 110)
            return fr
        lines = []
        if OLD:
            lines.append(("old walk_e", [marked(c) for c in cells(np.array(Image.open(OLD).convert("RGBA")))]))
        lines.append(("idle_e", [marked(c) for c in cells(idle_full())]))
        lines.append(("new walk_e", [marked(c) for c in cells(strip)]))
        lines.append(("walk_se", [marked(c) for c in cells(np.array(Image.open(f"{OUT}/walk_se.png").convert("RGBA")))]))
        contact_sheet(os.path.join(CONTACT, "contact_cuirassier_gallop.png"), lines)


def idle_full():
    return np.array(Image.open(f"{OUT}/idle_e.png").convert("RGBA"))


if __name__ == "__main__":
    main()
