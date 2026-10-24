"""The Crown Powder Mill from the owner's ChatGPT drawing art/redraws/powder_mill_shed.png
(1312x1199 on flat navy: the original mill plus a lean-to roof over the three ingredient piles at
the front left, saltpetre white, sulphur yellow, charcoal black, and a wooden hopper with a chute
to the millstone). Replaces the code-drawn shed of tools/import_mill_shed.py (kept, unlisted).

Built: the picture is fitted onto the old built sprite (art/crown/mill_base/powder_mill_built.png,
124x113, so the building overlays it) by cross-correlating the roof, chimney and banner: SX/SY
px of the drawing per game px, (OX, OY) the drawing pixel that lands on game column/row 0. The
navy is keyed out by flood fill from the border (the slate roof is blue-grey too, so only the
background connected to the edge goes), the keyed edge is eaten back two drawing px (no navy
fringe), then box-filtered with premultiplied alpha down to 124x113, hard alpha edge at 50%
coverage, and snapped to the old sprites' palette where a pixel is within SNAP of a palette colour.

Damaged (125x113): the old damaged art is a different painting, so it cannot be diffed pixel for
pixel; its damage is carried over by kind instead: the holes in the main roof (where the old
damaged roof shows timber and darkness) and the rubble on the ground (slate bits, stones, charred
wood: its pixels over the new ground) are copied at the same coordinates onto the new built
sprite, then the new lean-to is damaged by hand (a hole, cracked and missing slates, a slipped
corner, slates on the floor, the piles dusted with rubble). Construction and destroyed stay.

Run (repo root): python3 tools/import_mill_chatgpt.py [--sheet FILE]
Prints the pile centres and the hopper mouth in sprite px for scripts/unit.gd (MILL_PILE_DX,
building.gd's dust puff).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art/redraws/powder_mill_shed.png")
BASE = os.path.join(ROOT, "art/crown/mill_base")
OUT = os.path.join(ROOT, "assets/buildings")
W, H = 124, 113
SX, SY, OX, OY = 10.08, 9.97, -0.495, 0.0      # fitted (see the docstring)
X0, Y0 = 26, 37                                  # drawing px of the building's top-left
NAVY = (3, 25, 51)
ERODE = 2
SNAP = 9


def key_navy(im):
    d = np.abs(im.astype(int) - np.array(NAVY)).sum(2)
    bg = d < 30
    lab, _ = ndimage.label(bg)
    edge = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1])
    edge.discard(0)
    fg = ~np.isin(lab, list(edge))
    fg = ndimage.binary_opening(fg, iterations=2)
    l, n = ndimage.label(fg)
    sz = ndimage.sum(fg, l, range(1, n + 1))
    fg = l == (1 + int(np.argmax(sz)))
    fg = ndimage.binary_fill_holes(fg)
    return ndimage.binary_erosion(fg, iterations=ERODE)


def box_down(im, fg):
    pad = 400
    imp = np.pad(im.astype(np.float32), ((pad, pad), (pad, pad), (0, 0)))
    m = np.pad(fg.astype(np.float32), pad)
    x0 = X0 + pad - OX * SX
    y0 = Y0 + pad - OY * SY
    box = (x0, y0, x0 + W * SX, y0 + H * SY)
    chans = []
    for c in range(3):
        chans.append(np.array(Image.fromarray(imp[:, :, c] * m).resize((W, H), Image.BOX, box=box)))
    cov = np.array(Image.fromarray(m).resize((W, H), Image.BOX, box=box))
    out = np.zeros((H, W, 4), np.uint8)
    ok = cov >= 0.5
    for c in range(3):
        out[:, :, c] = np.where(ok, np.clip(chans[c] / np.maximum(cov, 1e-6) + 0.5, 0, 255), 0)
    out[:, :, 3] = np.where(ok, 255, 0)
    return out


def palette():
    cols = {}
    for s in ("built", "damaged"):
        a = np.array(Image.open(os.path.join(BASE, f"powder_mill_{s}.png")).convert("RGBA"))
        for p in a[a[:, :, 3] > 0][:, :3]:
            cols[tuple(p)] = cols.get(tuple(p), 0) + 1
    keep = np.array([c for c, n in cols.items() if n >= 3])
    return keep, cKDTree(keep)


def snap(a):
    keep, tree = palette()
    m = a[:, :, 3] > 0
    d, i = tree.query(a[m][:, :3].astype(float), p=1)
    px = a[m][:, :3].copy()
    sel = d <= SNAP
    px[sel] = keep[i[sel]]
    a[m, :3] = px
    return a


def build_new():
    im = np.array(Image.open(SRC).convert("RGB"))
    fg = key_navy(im)
    return snap(box_down(im, fg))


def fringe(a):
    """Drop edge pixels that are still navy-ish (blue far above red, dark)."""
    for _ in range(2):
        al = a[:, :, 3] > 0
        edge = al & ~ndimage.binary_erosion(al, border_value=1)
        r, g, b = [a[:, :, i].astype(int) for i in range(3)]
        bad = edge & (b - r > 22) & (b > g + 6) & (r + g + b < 200)
        a[bad] = 0
    return a


def old_damaged():
    return np.array(Image.open(os.path.join(BASE, "powder_mill_damaged.png")).convert("RGBA"))


def lum(a):
    return a[:, :, :3].astype(int).sum(2) / 3.0


def slate_like(a):
    r, g, b = [a[:, :, i].astype(int) for i in range(3)]
    return (a[:, :, 3] > 0) & (b >= r + 4) & (lum(a) > 28) & (lum(a) < 125)


HOLES = [(46, 68, 9, 32), (69, 85, 25, 41)]      # windows (x0, x1, y0, y1) round the old roof's holes
SHED_ROOF = None


def roof_holes(new, old):
    """Copy the old damaged roof's holes (timber and darkness) where the new roof is slate."""
    r, g, b = [old[:, :, i].astype(int) for i in range(3)]
    hole = (old[:, :, 3] > 0) & ((r > b + 8) | (lum(old) < 24))
    win = np.zeros(hole.shape, bool)
    for x0, x1, y0, y1 in HOLES:
        win[y0:y1, x0:x1] = True
    hole = ndimage.binary_opening(hole & win, iterations=1) | (hole & win & ndimage.binary_dilation(ndimage.binary_opening(hole & win), iterations=1))
    ok = hole & slate_like(new) & (np.arange(new.shape[0])[:, None] < 52)
    out = new.copy()
    out[ok] = old[ok]
    return out, ok


def ground_rubble(new, old):
    """Slate bits, stones and char from the old damaged ground, over the new bare dirt and grass."""
    r, g, b = [old[:, :, i].astype(int) for i in range(3)]
    l = lum(old)
    rub = (old[:, :, 3] > 0) & (((b >= r + 8) & (l > 40) & (l < 135)) | (l < 34) | ((l > 120) & (abs(r - g) < 14) & (abs(g - b) < 16)))
    nr, ng, nb = [new[:, :, i].astype(int) for i in range(3)]
    nl = lum(new)
    dirt = (new[:, :, 3] > 0) & (((nr > nb + 25) & (nl > 85) & (nl < 205)) | ((ng > nr + 6) & (ng > nb + 20)))
    yy, xx = np.mgrid[0:new.shape[0], 0:new.shape[1]]
    zone = (yy >= 62)
    zone &= ~((xx >= 4) & (xx <= 96) & (yy >= 56) & (yy <= 101))        # the shed and its piles
    zone &= ~((xx >= 62) & (xx <= 100) & (yy >= 60) & (yy <= 88))       # hopper
    ok = rub & dirt & zone
    rng = np.random.RandomState(7)
    ok &= rng.rand(*ok.shape) < 0.95
    out = new.copy()
    out[ok] = old[ok]
    return out


SLATE = [(25, 25, 26), (50, 50, 52), (63, 70, 78), (81, 95, 107)]
WOOD = [(65, 40, 18), (86, 52, 25), (160, 115, 62), (173, 127, 73)]
DARK = (22, 16, 12)
UNDER = (44, 32, 22)


def put(a, x, y, c):
    if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
        a[y, x, :3] = c
        a[y, x, 3] = 255


def shed_damage(a):
    """The new lean-to: a hole through the slates with the rafters showing, bare patches where
    slates are gone, hairline cracks, slates fallen on the floor, the piles dusted with rubble."""
    rng = np.random.RandomState(11)
    roof = slate_like(a)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    roof &= (xx >= 6) & (xx <= 58) & (yy >= 57) & (yy <= 82)
    # main hole and a small one: flattened ellipses on the roof plane
    for cx, cy, rx, ry in [(26, 67, 7.5, 3.6), (43, 73, 4.2, 2.0)]:
        hole = roof & (((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0)
        a[hole, :3] = DARK
        # a rafter across the big hole and a broken one across the small
        for t in range(-8, 9):
            x = int(round(cx + t * 0.9))
            y = int(round(cy + t * 0.42))
            if 0 <= y < a.shape[0] and hole[y, x]:
                a[y, x, :3] = WOOD[1]
                if y + 1 < a.shape[0] and hole[y + 1, x]:
                    a[y + 1, x, :3] = WOOD[0]
        # torn rim: lighter slate chips and timber splinters round the edge
        rim = ndimage.binary_dilation(hole, iterations=1) & ~hole & roof
        chips = rim & (rng.rand(*rim.shape) < 0.35)
        a[chips, :3] = np.array(UNDER)
    # bare patches (slates gone): 3x2 blocks of the underlay
    for cx, cy in [(15, 65), (33, 71), (50, 74), (22, 72)]:
        for dy in range(2):
            for dx in range(3):
                if roof[cy + dy, cx + dx]:
                    put(a, cx + dx, cy + dy, UNDER if (dx + dy) % 2 == 0 else WOOD[0])
    # cracks: a dark 1px line running down the slope (down-left to up-right)
    for sx_, sy_ in [(36, 68), (17, 69), (48, 71)]:
        for t in range(6):
            x, y = sx_ + t, sy_ - t // 2
            if 0 <= y < a.shape[0] and roof[y, x]:
                put(a, x, y, SLATE[0])
    # slates on the floor, in front of and beside the shed
    for cx, cy in [(14, 95), (24, 99), (38, 101), (52, 99), (62, 94), (9, 90), (70, 92), (56, 106)]:
        for dy in range(2):
            for dx in range(3 - dy):
                c = SLATE[int(rng.randint(1, 4))]
                put(a, cx + dx, cy + dy, c)
    # the piles dusted with rubble: a few slate and timber bits on them
    for cx, cy in [(19, 84), (22, 88), (30, 85), (33, 90), (46, 88), (50, 91)]:
        put(a, cx, cy, SLATE[2])
        put(a, cx + 1, cy, SLATE[1])
    return a


def loose_rubble(a):
    """Extra fallen slates and timber splinters on bare ground, thickest below the roof holes."""
    rng = np.random.RandomState(5)
    nr, ng, nb = [a[:, :, i].astype(int) for i in range(3)]
    nl = lum(a)
    dirt = (a[:, :, 3] > 0) & (nr > nb + 25) & (nl > 90) & (nl < 205)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    dirt &= (yy >= 70) & ~((xx >= 4) & (xx <= 96) & (yy >= 56) & (yy <= 101)) & ~((xx >= 62) & (xx <= 100) & (yy >= 60) & (yy <= 88))
    ys, xs = np.where(dirt)
    pick = rng.rand(len(ys)) < 0.05
    for x, y in zip(xs[pick], ys[pick]):
        kind = rng.rand()
        if kind < 0.55:
            c = SLATE[int(rng.randint(0, 3))]
            put(a, x, y, c)
            if rng.rand() < 0.6:
                put(a, x + 1, y, SLATE[int(rng.randint(1, 4))])
        else:
            put(a, x, y, WOOD[int(rng.randint(0, 3))])
            put(a, x + 1, y - 1, WOOD[0])
    return a


def damaged(built):
    old = old_damaged()
    built = np.pad(built, ((0, 0), (0, 1), (0, 0)))
    out, holes = roof_holes(built, old)
    out = ground_rubble(out, old)
    out = loose_rubble(out)
    out = shed_damage(out)
    return out


def main():
    built = fringe(build_new())
    Image.fromarray(built).save(os.path.join(OUT, "powder_mill_built.png"))
    dm = damaged(built)
    Image.fromarray(dm).save(os.path.join(OUT, "powder_mill_damaged.png"))
    print("built and damaged written")


if __name__ == "__main__":
    main()
