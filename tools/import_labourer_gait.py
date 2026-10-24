"""Give the Crown labourer a real gait in the SIDE and DIAGONAL walk views (e, se, ne; the west views are
these strips mirrored by DIR_FLIP in scripts/unit.gd): walk, carry and carry_keg, 6 frames each.

Why: the image-AI legs (kept by tools/import_labourer_redraw.py) stay at about the same spread from one
frame to the next, so he shuffled. This pass keeps each frame's torso, head, arms and carried sack / keg
(rows above the trouser line) and REBUILDS the legs under it with hard pixels in his own trouser grey and
boot browns:

  frame 0  contact:  near foot (heel strike) ahead, far foot behind on its toe (widest stance)
  frame 1  down:     near foot flat under him, far leg lifting, knee forward, foot tucked behind
  frame 2  passing:  near leg straight, far foot swung ahead and lifted (body highest, 1 px up)
  frame 3-5          the same with the legs swapped (far foot ahead, near foot lifting, swinging)

The stance foot slides back 3.7 px a frame, which is exactly what LAB_STRIDE (22 px per 6-frame strip) walks
the ground, so a planted boot stays planted. Near leg is drawn lighter and last, the far leg a shade darker.
In se the foot behind sits 1 row higher (depth), in ne the foot ahead does.

Source: art/redraws/gait_src/<pose>_<d>.png (the redraw's strips, pristine; refresh with `--snapshot`
straight after tools/import_labourer_redraw.py + import_labourer_hoe.py). Runs after those in
tools/rebuild_art.sh. Usage (repo root):  python3 tools/import_labourer_gait.py [--snapshot] [--contact FILE]
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/units/labourer")
SRC = os.path.join(ROOT, "art/redraws/gait_src")
W, H = 42, 35
POSES = ["walk", "carry", "carry_keg"]
DIRS = ["e", "se", "ne"]

TR_NEAR = [(129, 127, 124), (101, 98, 96), (68, 65, 64)]   # light, mid, dark
TR_FAR = [(101, 98, 96), (79, 76, 75), (58, 55, 54)]
BOOT_NEAR = [(129, 75, 37), (121, 62, 20), (45, 21, 7)]
BOOT_FAR = [(121, 62, 20), (91, 48, 25), (35, 16, 4)]

# per frame: (near foot heel offset, near lift rows, near kind, far ..., body dy)
# kind: "flat" planted, "toe" push-off (heel raised, toe down), "swing" lifted foot
# near leg: contact ahead (+), stance slides back, push-off, swing through
POSE = [
    # near x, near lift, near kind | far x, far lift, far kind | dy
    (+4.5, 0, "heel", -5.0, 0, "toe", 0),
    (+1.0, 0, "flat", -3.0, 3, "swing", 0),
    (-2.5, 0, "flat", +3.5, 2, "swing", -1),
    (-5.0, 0, "toe", +4.5, 0, "heel", 0),
    (-3.0, 3, "swing", +1.0, 0, "flat", 0),
    (+3.5, 2, "swing", -2.5, 0, "flat", -1),
]
AMP = {"e": 1.0, "se": 0.72, "ne": 0.72}


def snapshot():
    os.makedirs(SRC, exist_ok=True)
    for p in POSES:
        for d in DIRS:
            shutil.copy(os.path.join(OUT, f"{p}_{d}.png"), os.path.join(SRC, f"{p}_{d}.png"))


def put(f, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        f[y, x, :3] = c
        f[y, x, 3] = 255


def seg(f, x0, y0, x1, y1, wid, cols, edge_dark=True):
    """thick near-vertical segment: per row a bar `wid` wide centred on the line."""
    ya, yb = int(round(min(y0, y1))), int(round(max(y0, y1)))
    for y in range(ya, yb + 1):
        t = 0.0 if yb == ya else (y - y0) / (y1 - y0) if y1 != y0 else 0.0
        t = min(max(t, 0.0), 1.0)
        cx = x0 + (x1 - x0) * t
        xl = int(round(cx - wid / 2.0 + 0.001))
        for i in range(wid):
            c = cols[0] if i == 0 else cols[2] if i == wid - 1 else cols[1]
            put(f, xl + i, y, c)


def boot(f, hx, fy, kind, cols, d, depth_up):
    """boot with its heel column at hx and its sole on row fy; toe points forward (+x)."""
    L = 6 if d == "e" else 5
    lt, md, dk = cols
    if kind == "toe":                # push-off: toe on the ground, heel raised and trailing
        rows = [(fy - 4, 0, 4), (fy - 3, 0, 5), (fy - 2, 0, 5), (fy - 1, 1, L), (fy, 3, L)]
    elif kind == "swing":            # lifted, toe hanging a little
        rows = [(fy - 3, 0, 4), (fy - 2, 0, 5), (fy - 1, 0, L), (fy, 1, L)]
    else:                            # planted
        rows = [(fy - 3, 0, 4), (fy - 2, 0, 5), (fy - 1, 0, L), (fy, 0, L)]
    for (y, a, b) in rows:
        for x in range(a, b):
            c = md
            if y == rows[0][0]:
                c = lt
            if y == fy and kind != "toe":
                c = dk
            if x == b - 1 and y == fy - 1:
                c = dk
            put(f, hx + x, y, c)


def leg(f, hipx, ytop, hx, lift, kind, cols_t, cols_b, d, fy_off):
    fy = 33 - lift - fy_off
    # ankle sits on the boot's shaft (x hx+1..hx+2)
    ax = hx + 1.5
    ay = fy - 3
    if kind == "swing":
        # knee forward of the hip-ankle line, shin trailing
        kx = hipx + (3 if d == "e" else 2)
        ky = ytop + 3
        seg(f, hipx, ytop, kx, ky, 4, cols_t)
        seg(f, kx, ky + 1, ax, ay, 3, cols_t)
    elif kind == "toe":
        seg(f, hipx, ytop, ax, ay, 4, cols_t)
    else:
        seg(f, hipx, ytop, ax, ay, 4, cols_t)
    boot(f, hx, fy, kind, cols_b, d, fy_off)


def rebuild(fr, k, d):
    near_x, near_l, near_k, far_x, far_l, far_k, dy = POSE[k]
    a = AMP[d]
    f = fr.copy()
    alpha = f[..., 3] > 0
    grey = alpha & (np.abs(f[..., 0].astype(int) - f[..., 1]) < 25) & (np.abs(f[..., 1].astype(int) - f[..., 2]) < 40)
    cut = 24
    for y in range(21, 25):
        if grey[y].sum() >= 6 and not ((f[y, :, 0] > 140) & (f[y, :, 1] < 60) & alpha[y]).any():
            cut = y
            break
    cut = min(cut, 24)
    cx = int(round(np.mean(np.nonzero(grey[cut:cut + 3])[1]))) if grey[cut:cut + 3].any() else 21
    body = fr.copy()
    body[cut:] = 0
    out = np.zeros_like(fr)
    ys = np.arange(cut)
    for y in range(cut):
        ny = y + dy
        if 0 <= ny < H:
            out[ny] = body[y]
    ytop = cut + dy
    # hip block
    for y in (ytop, ytop + 1):
        for x in range(cx - 4, cx + 5):
            put(out, x, y, TR_FAR[1] if x < cx - 1 else TR_NEAR[1])
    def pos(off):
        return cx - 3 + int(round(off * a))
    def yoff(off, other_lift):
        # depth: se - the foot behind sits higher; ne - the foot ahead sits higher (only while both
        # feet are down, so one boot always stands on row 33)
        if other_lift:
            return 0
        if d == "se":
            return 1 if off < 0 else 0
        if d == "ne":
            return 1 if off > 0 else 0
        return 0
    leg(out, cx - 1, ytop + 1, pos(far_x), far_l, far_k, TR_FAR, BOOT_FAR, d, yoff(far_x, near_l))
    leg(out, cx + 1, ytop + 1, pos(near_x), near_l, near_k, TR_NEAR, BOOT_NEAR, d, yoff(near_x, far_l))
    return out


def run():
    if not os.path.isdir(SRC):
        snapshot()
    for p in POSES:
        for d in DIRS:
            im = np.array(Image.open(os.path.join(SRC, f"{p}_{d}.png")).convert("RGBA"))
            n = im.shape[1] // W
            assert n == 6, (p, d, n)
            frames = [rebuild(im[:, i * W:(i + 1) * W], i, d) for i in range(n)]
            Image.fromarray(np.concatenate(frames, 1)).save(os.path.join(OUT, f"{p}_{d}.png"))


def contact(path, zoom=4):
    rows = [Image.open(os.path.join(OUT, f"{p}_{d}.png")).convert("RGBA") for p in POSES for d in DIRS]
    sheet = Image.new("RGBA", (W * 6, H * len(rows)), (60, 90, 60, 255))
    for i, r in enumerate(rows):
        sheet.alpha_composite(r, (0, H * i))
    sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST).save(path)


if __name__ == "__main__":
    if "--snapshot" in sys.argv:
        snapshot()
        print("snapshot written to", SRC)
    else:
        run()
        if "--contact" in sys.argv:
            contact(sys.argv[sys.argv.index("--contact") + 1])
