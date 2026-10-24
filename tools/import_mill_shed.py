"""The Crown Powder Mill's lean-to shed and hopper (owner decision: the labourer shovels the
three ingredients into a hopper, so the piles need a roof over them and the mill a hopper).

Run AFTER tools/import_powder_mill.py (tools/rebuild_art.sh does). That script writes the mill
sprites with three open heaps in front (saltpetre, sulphur, charcoal) and nothing else; this one
reads its untouched output from art/crown/mill_base/ (committed; `--snapshot` refreshes it from
assets/buildings, only right after import_powder_mill.py) so running it twice changes nothing,
and writes assets/buildings/powder_mill_{built,damaged}.png again with:

  * the old heaps wiped (every heap-coloured pixel in their boxes is painted over with the nearest
    dirt pixel) and three new ones in a row at the front, each its own look: pale crystalline
    saltpetre (left), yellow sulphur (middle), black charcoal (right);
  * a lean-to over them: a slate-tone shed roof (the main roof's four slate tones, soft, no
    noisy texture), three front posts in the building's timber colours, a dark shadow under the roof;
  * a wooden hopper at the right end of the shed, in front of the millstone's left rim, with a
    short chute to the stone and a grey-white level of ingredient in its mouth.

The sprite size, anchor and footprint are unchanged (the shed stays inside the picture), so
placement, collision and the build grid are as before. The constants below are also what
scripts/unit.gd uses to stand a labourer in front of each heap: PILE_X / HOPPER_X are sprite px
from the left edge (base point = column 62, row 107: Building.body_offset).

    python3 tools/import_mill_shed.py [--snapshot] [--sheet FILE]
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "art/crown/mill_base")
OUT = os.path.join(ROOT, "assets/buildings")
STATES = ["built", "damaged"]

# Slate of the main roof (sampled from the sprite), timber, outline.
SLATE = [(25, 25, 26), (50, 50, 52), (63, 70, 78), (81, 95, 107)]
WOOD = [(65, 40, 18), (86, 52, 25), (160, 115, 62), (173, 127, 73)]
OUTLINE = (25, 20, 16)
IRON = [(45, 43, 37), (71, 69, 60), (105, 102, 96), (150, 148, 140)]

PILE_X = [18, 31, 51]          # heap centres (sprite px): saltpetre, sulphur, charcoal
PILE_BASE = 103                # the heaps' bottom row
PILE_W = 14
PILE_H = 12
HOPPER_X = 64                  # hopper centre column
HOPPER_TOP = 87
SHED_L, SHED_R = 8, 75        # roof's left / right front corner
EAVE_Y = 79                    # front edge of the roof (its lowest row at the left)

CRYSTAL = [(236, 240, 244), (205, 212, 224), (165, 175, 192), (118, 128, 148)]   # saltpetre
SULPHUR = [(252, 226, 80), (232, 188, 38), (186, 138, 22), (128, 92, 16)]
COAL = [(86, 86, 94), (52, 52, 60), (30, 30, 36), (14, 14, 18)]


def put(a, x, y, c):
    if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
        a[y, x, :3] = c
        a[y, x, 3] = 255


def wipe_heaps(a):
    """Paint the old heaps over with the nearest dirt pixel."""
    h, w = a.shape[:2]
    rgb = a[:, :, :3].astype(int)
    lum = rgb.sum(2) / 3.0
    sat = rgb.max(2) - rgb.min(2)
    mask = np.zeros((h, w), bool)
    yy, xx = np.mgrid[0:h, 0:w]
    def bx(x0, x1, y0, y1):
        return (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    white = bx(15, 38, 82, 102) & (lum > 140) & (sat < 45)
    yellow = bx(35, 60, 78, 102) & (rgb[:, :, 0] > 170) & (rgb[:, :, 1] > 120) & (rgb[:, :, 2] < 120) & (sat > 80)
    black = bx(54, 80, 80, 100) & (rgb.max(2) < 75)
    box = bx(14, 81, 77, 103)
    mask = (white | yellow | black) & (a[:, :, 3] > 0)
    mask = ndimage.binary_dilation(mask, iterations=1) & box & (a[:, :, 3] > 0)
    # keep the dirt and nothing else as a source: dirt is tan, not wood-dark or stone-grey
    good = (a[:, :, 3] > 0) & ~mask & (lum > 100) & (lum < 200) & (rgb[:, :, 0] > rgb[:, :, 2] + 40) & (rgb[:, :, 0] >= rgb[:, :, 1])
    idx = ndimage.distance_transform_edt(~good, return_distances=False, return_indices=True)
    out = a.copy()
    sel = mask
    out[sel] = a[idx[0][sel], idx[1][sel]]
    out[sel, 3] = 255
    return out


def heap(a, cx, pal, kind):
    """A hard-pixel mound: dark outline, four tones lit from the upper left."""
    half = PILE_W // 2
    prof = {}
    for dy in range(PILE_H):
        t = dy / (PILE_H - 1.0)
        wd = half * (0.30 + 0.70 * t) if kind != "crystal" else half * (0.22 + 0.78 * t ** 0.85)
        if kind == "coal":
            wd = half * (0.35 + 0.65 * t ** 0.8)
        prof[dy] = int(round(wd))
    top = PILE_BASE - PILE_H + 1
    for dy in range(PILE_H):
        y = top + dy
        wd = prof[dy]
        for x in range(cx - wd, cx + wd + 1):
            u = (x - cx) / max(wd, 1)            # -1 .. 1 across
            v = dy / (PILE_H - 1.0)
            lit = 0.5 - 0.35 * u - 0.30 * (v - 0.5)
            k = 0 if lit > 0.72 else 1 if lit > 0.45 else 2 if lit > 0.2 else 3
            if x in (cx - wd, cx + wd) or dy == PILE_H - 1:
                k = min(k + 1, 3)
            put(a, x, y, pal[k])
    # outline: one dark row under it and a dark pixel at each side of the top
    for dy in range(PILE_H):
        y = top + dy
        wd = prof[dy]
        put(a, cx - wd - 1, y, OUTLINE)
        put(a, cx + wd + 1, y, OUTLINE)
    for x in range(cx - half, cx + half + 1):
        put(a, x, PILE_BASE + 1, OUTLINE)
    put(a, cx, top - 1, OUTLINE)
    if prof[0] > 0:
        for x in range(cx - prof[0], cx + prof[0] + 1):
            put(a, x, top - 1, OUTLINE)
    # character: crystals glint, sulphur lumps, coal chunks
    if kind == "crystal":
        for (dx, dy) in [(-3, 3), (1, 1), (3, 6), (-1, 8), (-5, 9), (4, 9)]:
            put(a, cx + dx, top + dy, CRYSTAL[0])
        for (dx, dy) in [(-2, 5), (2, 4), (0, 10)]:
            put(a, cx + dx, top + dy, CRYSTAL[3])
    elif kind == "sulphur":
        for (dx, dy) in [(-2, 4), (2, 6), (-4, 8), (3, 9)]:
            put(a, cx + dx, top + dy, SULPHUR[3])
            put(a, cx + dx - 1, top + dy - 1, SULPHUR[0])
    else:
        for (dx, dy) in [(-2, 4), (2, 7), (-4, 9), (1, 9)]:
            put(a, cx + dx, top + dy, COAL[0])


def roof(a):
    """Lean-to roof: a slate parallelogram sloping up to the back, soft banding, a wooden fascia."""
    l, r = SHED_L, SHED_R
    depth = 8                 # rows from the front edge to the back edge
    for x in range(l, r + 1):
        yf = EAVE_Y + int(round((x - l) * 0.05))        # front edge a touch lower to the right
        for k in range(depth):
            y = yf - k
            # the left end slants back (side view of the roof): the back edge is shifted right
            if x < l + (depth - k) * 0.5:
                continue
            band = (k // 3) % 2
            tone = 2 if band == 0 else 1
            if k > depth - 4:
                tone = 3 if band == 0 else 2          # the back, far from us, catches the light
            if k == 0:
                tone = 0
            put(a, x, y, SLATE[tone])
        put(a, x, yf + 1, WOOD[0])                  # fascia: dark, with a lighter board under it
        put(a, x, yf + 2, WOOD[1])
        put(a, x, yf - depth, OUTLINE)
    # slate courses: a faint lighter row every third row, broken (every other tile)
    for x in range(l, r + 1):
        yf = EAVE_Y + int(round((x - l) * 0.05))
        for k in (3, 6, 9):
            if (x + k) % 4 == 0 and x >= l + (depth - k) * 0.5:
                put(a, x, yf - k, SLATE[min(((k // 3) % 2) + 2, 3)])
    # left end: outline up the slanted edge
    for k in range(depth):
        put(a, int(l + (depth - k) * 0.5) - 1 + 1, EAVE_Y - k, OUTLINE)
    # right end outline
    for k in range(depth):
        yf = EAVE_Y + int(round((r - l) * 0.05))
        put(a, r + 1, yf - k, OUTLINE)


def posts(a):
    for px in (SHED_L + 3, 41, SHED_R - 3):
        yf = EAVE_Y + int(round((px - SHED_L) * 0.05))
        for y in range(yf + 3, PILE_BASE + 2):
            put(a, px - 1, y, OUTLINE)
            put(a, px, y, WOOD[3] if y % 6 else WOOD[2])
            put(a, px + 1, y, WOOD[1])
            put(a, px + 2, y, OUTLINE)


def back_wall(a):
    """The building's wall behind the heaps, under the roof: dark vertical planks (hides the
    old art, makes the heaps read), with a shadow row under the eave."""
    l, r = SHED_L, SHED_R
    for x in range(l + 2, r):
        yf = EAVE_Y + int(round((x - l) * 0.05))
        for y in range(yf + 3, 94):
            plank = ((x - l) // 5) % 2
            c = (52, 34, 18) if plank else (64, 41, 22)
            if (x - l) % 5 == 0:
                c = (34, 22, 12)
            if y < yf + 6:
                c = (30, 20, 12)                      # the roof's shadow
            put(a, x, y, c)
    for x in range(l + 2, r):                         # the floor line: the dark of the shed's ground
        put(a, x, 94, (34, 22, 12))


def hopper(a):
    cx = HOPPER_X
    top = HOPPER_TOP
    # legs
    for lx in (cx - 5, cx + 5):
        for y in range(top + 9, PILE_BASE + 2):
            put(a, lx, y, WOOD[1])
            put(a, lx - 1, y, OUTLINE)
            put(a, lx + 1, y, OUTLINE)
    # funnel body: wide rim at the top, narrowing; planks in two tones
    for dy in range(10):
        wd = 7 - (dy * 4) // 9
        for x in range(cx - wd, cx + wd + 1):
            c = WOOD[2] if x < cx else WOOD[1]
            if dy % 4 == 3:
                c = WOOD[0]
            put(a, x, top + dy, c)
        put(a, cx - wd - 1, top + dy, OUTLINE)
        put(a, cx + wd + 1, top + dy, OUTLINE)
    # iron band
    for x in range(cx - 6, cx + 7):
        if abs(x - cx) <= 7 - (3 * 4) // 9:
            put(a, x, top + 4, IRON[2] if x < cx else IRON[1])
    # the mouth: dark inside, the ingredient's level (grey-white) a little under the rim
    for x in range(cx - 6, cx + 7):
        put(a, x, top - 1, OUTLINE)
        put(a, x, top, WOOD[3])
    for x in range(cx - 5, cx + 6):
        put(a, x, top + 1, CRYSTAL[3] if (x + 1) % 3 else CRYSTAL[2])
    # bottom outline and the chute to the stone (a short plank going right and down)
    for x in range(cx - 3, cx + 4):
        put(a, x, top + 10, OUTLINE)
    for i in range(7):
        put(a, cx + 4 + i, top + 8 + i // 2, WOOD[2])
        put(a, cx + 4 + i, top + 9 + i // 2, WOOD[0])


def build(src):
    a = wipe_heaps(src)
    base = a.copy()
    back_wall(a)
    heap(a, PILE_X[0], CRYSTAL, "crystal")
    heap(a, PILE_X[1], SULPHUR, "sulphur")
    heap(a, PILE_X[2], COAL, "coal")
    hopper(a)
    posts(a)
    roof(a)
    return a


def main():
    if "--snapshot" in sys.argv:
        for s in STATES:
            shutil.copy(os.path.join(OUT, f"powder_mill_{s}.png"), os.path.join(BASE, f"powder_mill_{s}.png"))
        print("snapshot written to", BASE)
        return
    outs = []
    for s in STATES:
        src = np.array(Image.open(os.path.join(BASE, f"powder_mill_{s}.png")).convert("RGBA"))
        o = build(src)
        Image.fromarray(o).save(os.path.join(OUT, f"powder_mill_{s}.png"))
        outs.append(o)
    if "--sheet" in sys.argv:
        S = 4
        sh = Image.new("RGBA", (sum(o.shape[1] for o in outs) * S, outs[0].shape[0] * S), (90, 140, 80, 255))
        x = 0
        for o in outs:
            sh.alpha_composite(Image.fromarray(o).resize((o.shape[1] * S, o.shape[0] * S), Image.NEAREST), (x, 0))
            x += o.shape[1] * S
        sh.save(sys.argv[sys.argv.index("--sheet") + 1])
    print("wrote the mill with its shed and hopper")


if __name__ == "__main__":
    main()
