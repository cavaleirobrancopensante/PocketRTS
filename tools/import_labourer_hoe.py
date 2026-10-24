"""The Crown labourer's farm swing ('mine' strips) redrawn with a HOE.

The game has no mining, only farms and the powder mill, so the pose played when he works a
farm (`mine_<s|se|e|ne|n>`, scripts/unit.gd `_anim_name`: work "manning" on a farm) must be a
hoe, not the pickaxe the image-AI sheet drew (art/redraws/labourer_mine_idle_ne_idle_sack.png).

Sources (committed, so no git history is needed):
  art/redraws/new_mine/mine_<d>.png   the 4-frame strips tools/import_labourer_redraw.py writes
                                      (raise, mid, strike, recover; the new bulkier man whose size
                                      and outfit match the new walk / idle strips).
                                      Refresh with `--snapshot` straight after running
                                      import_labourer_redraw.py (only then are they pristine).
  art/redraws/old_mine/mine_<d>.png   the original 3-frame strips (git 37bb869; raise, swing, deep
                                      strike) kept as a reference for the swing arc and the weight.

What it does, per direction and frame (see docs/animation_audit_labourer.md for the evaluation):
  1. body: the new man (consistent with the new art); on the strike frames he crouches (rows are
     cut out of the thighs so the coat and head drop with the boots staying on row 33) and leans in;
     E frame 0 (the AI drew the arm hanging) gets a raised arm; N frame 1 (the AI hid the tool)
     gets its tool back;
  2. the pick is erased (per-frame boxes, the coat, face and hands are never touched);
  3. a hoe is drawn in its place: a long wooden handle, a short neck and a flat iron blade set at
     ~80 degrees to the handle (hanging down on the raise / swing, biting into the soil on the
     strike), hard pixels in the labourer's own wood / iron colours, no blur;
  4. the strike frame gets brown soil clods instead of grey stone chips.
Frame order stays raise, mid, strike, recover (STRIKE frame 2, as ArtData / unit.gd expect).

Run from the repo root after tools/import_labourer_redraw.py (tools/rebuild_art.sh does):
    python3 tools/import_labourer_hoe.py [--snapshot] [--contact FILE]
Needs Pillow and NumPy.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/units/labourer")
NEW = os.path.join(ROOT, "art/redraws/new_mine")
W, H = 42, 35
DIRS = ["s", "se", "e", "ne", "n"]

WOOD = [(196, 108, 51), (145, 93, 53), (121, 77, 41), (90, 48, 25)]    # light .. dark
IRON = [(161, 169, 189), (140, 142, 160), (110, 110, 128), (70, 70, 82), (17, 17, 18)]
SOIL = [(150, 95, 52), (121, 77, 41), (90, 48, 25), (62, 40, 24)]
COAT = [(255, 0, 0), (150, 0, 0)]
SKIN = (247, 197, 130)


def load(d):
    im = np.array(Image.open(os.path.join(NEW, f"mine_{d}.png")).convert("RGBA"))
    return [im[:, k * W:(k + 1) * W].copy() for k in range(im.shape[1] // W)]


def put(f, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        f[y, x, :3] = c
        f[y, x, 3] = 255


def is_coat(p):
    return p[3] > 0 and tuple(p[:3]) in COAT


def erase(f, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H and not is_coat(f[y, x]):
                f[y, x] = 0


def crouch(f, k, cut=24, lean=0, lean_rows=(0, 22)):
    """Drop everything above row `cut` by k rows (the thighs lose k rows, boots stay on 33);
    the upper body also leans `lean` px (+ = right) on rows lean_rows."""
    o = np.zeros_like(f)
    o[cut + k:] = f[cut + k:]
    o[k:cut + k] = f[:cut]
    # the rows between: the lower rows that were removed are simply dropped
    if lean:
        up = o[lean_rows[0]:lean_rows[1] + k].copy()
        o[lean_rows[0]:lean_rows[1] + k] = 0
        o[lean_rows[0]:lean_rows[1] + k, max(lean, 0):W + min(lean, 0)] = up[:, max(-lean, 0):W - max(lean, 0)]
    return o


def line(p0, p1):
    (x0, y0), (x1, y1) = p0, p1
    n = max(abs(x1 - x0), abs(y1 - y0))
    return [(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)) for i in range(n + 1)] if n else [p0]


BLADE = [1, 4, 5, 5]      # width (px, along the handle axis) of each row of the blade from the
                             # neck outwards: a 1 px neck, then a flat plate widening to the edge


def hoe(f, grip, end, angle=80.0, butt=0):
    """Draw the hoe: handle grip->end (wood, 2 px thick), then the blade at `angle` degrees to the
    handle, turned to point down. Pixels are put over whatever is there (the pick was erased)."""
    gx, gy = grip
    ex, ey = end
    hx, hy = ex - gx, ey - gy
    hl = math.hypot(hx, hy)
    hx, hy = hx / hl, hy / hl
    best = None
    for sgn in (1, -1):
        a = math.radians(angle) * sgn
        bx, by = hx * math.cos(a) - hy * math.sin(a), hx * math.sin(a) + hy * math.cos(a)
        score = by + 0.15 * bx
        if best is None or score > best[0]:
            best = (score, bx, by)
    _, bx, by = best
    pts = line((round(gx - hx * butt), round(gy - hy * butt)), (ex, ey))
    horiz = abs(hx) > abs(hy)
    sx, sy = (0, 1) if horiz else (1, 0)
    for (x, y) in pts:                       # underside first (darker), then the wood on top
        if 0 <= y + sy < H and 0 <= x + sx < W and f[y + sy, x + sx, 3] == 0:
            put(f, x + sx, y + sy, WOOD[3])
    for (x, y) in pts:
        put(f, x, y, WOOD[1])
    cells = {}
    n = len(BLADE)
    for yy in range(H):
        for xx in range(W):
            dx, dy = xx - ex, yy - ey
            u = dx * bx + dy * by
            v = dx * hx + dy * hy
            if 0.5 <= u < 0.5 + n:
                i = int(u - 0.5)
                if abs(v) <= BLADE[i] * 0.5:
                    cells[(xx, yy)] = (i, v)
    for (xx, yy), (i, v) in cells.items():
        if i == 0:
            c = IRON[3]                                    # neck
        elif i == n - 1:
            c = IRON[0]                                    # the cutting edge shines
        elif v < -0.5:
            c = IRON[1]
        else:
            c = IRON[2]
        put(f, xx, yy, c)
    for (xx, yy), (i, v) in list(cells.items()):           # dark outline on the outer side only
        for nx, ny in ((xx + 1, yy), (xx - 1, yy), (xx, yy + 1), (xx, yy - 1)):
            if (nx, ny) not in cells and 0 <= nx < W and 0 <= ny < H and f[ny, nx, 3] == 0:
                if (nx - ex) * bx + (ny - ey) * by > 1.0:
                    put(f, nx, ny, IRON[4])


def clods(f, pts):
    """Brown soil clods thrown by the blade: (x, y, w, h) boxes in the soil colours."""
    for i, (x, y, w, h) in enumerate(pts):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < W and 0 <= yy < H and f[yy, xx, 3] == 0:
                    put(f, xx, yy, SOIL[(i + xx + yy) % 3 if w * h > 1 else (0, 1, 2)[i % 3]])


def iron_clear(f, box):
    """Erase the pick's iron (grey / blue-grey: blue >= red) in a box, leaving brown hat, skin, coat."""
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            p = f[y, x]
            if 0 <= x < W and 0 <= y < H and p[3] and int(p[2]) >= int(p[0]) - 2 and not is_coat(p):
                f[y, x] = 0


def F(body, boxes, grip, end, crouch_=None, clod=(), iron=(), **kw):
    return dict(body=body, boxes=boxes, grip=grip, end=end, crouch=crouch_, clods=list(clod),
                iron=list(iron), kw=kw)


SPEC = {}
CLODS = [(30, 32, 2, 1), (32, 29, 1, 1), (38, 31, 2, 2), (40, 28, 1, 1), (36, 33, 2, 1),
         (40, 30, 1, 1), (34, 27, 1, 1), (31, 30, 1, 1)]
SPEC["s"] = [
    F(0, [(29, 0, 41, 8), (32, 9, 41, 11)], (29, 9), (35, 4), iron=[(25, 0, 41, 10)]),
    F(1, [(27, 14, 41, 32)], (25, 22), (36, 26), iron=[(27, 14, 41, 32)]),
    F(2, [(29, 14, 41, 34)], (28, 23), (36, 28), crouch_=(2, 0), iron=[(29, 14, 41, 34)], clod=CLODS),
    F(3, [(29, 0, 41, 8), (32, 9, 41, 11)], (29, 11), (36, 8), iron=[(25, 0, 41, 10)]),
]
SPEC["se"] = [
    F(0, [(30, 0, 41, 11)], (30, 11), (35, 5), iron=[(28, 0, 41, 12)]),
    F(1, [(27, 15, 41, 30)], (25, 22), (37, 26), iron=[(27, 15, 41, 30)]),
    F(2, [(30, 16, 41, 34), (28, 19, 32, 26)], (28, 23), (37, 28), crouch_=(2, 1),
      iron=[(28, 16, 41, 34)], clod=CLODS),
    F(3, [(30, 0, 41, 11)], (30, 12), (36, 9), iron=[(28, 0, 41, 12)]),
]
SPEC["e"] = [
    F(0, [(29, 0, 41, 9)], (27, 19), (35, 4), iron=[(24, 0, 41, 10)]),
    F(1, [(28, 11, 41, 30)], (27, 19), (37, 23), iron=[(28, 11, 41, 30)]),
    F(2, [(29, 14, 41, 34)], (28, 22), (37, 28), crouch_=(2, 1), iron=[(29, 14, 41, 34)], clod=CLODS),
    F(1, [(28, 11, 41, 30)], (27, 19), (35, 13), iron=[(28, 11, 41, 30)]),
]
SPEC["ne"] = [
    F(0, [(31, 0, 41, 9)], (30, 11), (35, 5), iron=[(26, 0, 41, 10)]),
    F(1, [(28, 13, 41, 28)], (26, 20), (37, 24), iron=[(28, 13, 41, 28)]),
    F(2, [(29, 14, 41, 34)], (27, 22), (37, 28), crouch_=(2, 1), iron=[(29, 14, 41, 34)], clod=CLODS),
    F(3, [(31, 0, 41, 9)], (30, 13), (35, 9), iron=[(26, 0, 41, 10)]),
]
SPEC["n"] = [
    F(0, [(28, 0, 41, 9)], (27, 10), (34, 4), iron=[(24, 0, 41, 10)]),
    F(1, [(28, 9, 41, 18)], (27, 17), (36, 15), iron=[(28, 9, 41, 18)]),
    F(2, [(27, 15, 41, 34)], (26, 22), (36, 28), crouch_=(2, 0), iron=[(27, 15, 41, 34)], clod=CLODS),
    F(3, [(28, 0, 41, 9)], (27, 11), (34, 7), iron=[(24, 0, 41, 10)]),
]


def build(d):
    src = load(d)
    out = []
    for sp in SPEC[d]:
        f = src[sp["body"]].copy()
        for b in sp["boxes"]:
            erase(f, b)
        for b in sp["iron"]:
            iron_clear(f, b)
        if sp["crouch"]:
            iron_clear(f, (20, 30, 32, 34))     # grey chips of the old debris under the boots
        gx, gy = sp["grip"]
        if sp["crouch"]:
            k, lean = sp["crouch"]
            f = crouch(f, k, lean=lean)
            if gy < 24:
                gy += k
            gx += lean
        hoe(f, (gx, gy), sp["end"], **sp["kw"])
        clods(f, sp["clods"])
        out.append(f)
    return out


def contact(rows, path, S=4):
    from PIL import ImageDraw
    sh = Image.new("RGBA", (4 * W * S, len(rows) * H * S), (90, 110, 90, 255))
    for r, fr in enumerate(rows):
        for k, f in enumerate(fr):
            sh.alpha_composite(Image.fromarray(f).resize((W * S, H * S), Image.NEAREST), (k * W * S, r * H * S))
    sh.save(path)


def main():
    if "--snapshot" in sys.argv:
        for d in DIRS:
            Image.open(os.path.join(OUT, f"mine_{d}.png")).save(os.path.join(NEW, f"mine_{d}.png"))
        print("snapshot of the current mine strips written to", NEW)
        return
    rows = []
    for d in DIRS:
        fr = build(d)
        rows.append(fr)
        Image.fromarray(np.concatenate(fr, 1)).save(os.path.join(OUT, f"mine_{d}.png"))
    if "--contact" in sys.argv:
        contact(rows, sys.argv[sys.argv.index("--contact") + 1])
    print("wrote the hoe strips (4 frames x 5 directions) to", OUT)


if __name__ == "__main__":
    main()
