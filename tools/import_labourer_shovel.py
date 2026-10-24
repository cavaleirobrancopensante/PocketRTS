"""The Crown labourer shovelling at the Powder Mill: strips shovel_<s|se|e|ne|n>.png.

He stands in front of the mill's shed (tools/import_mill_shed.py), digs the shovel into one of
the three heaps, lifts the load, swings it toward the hopper and tips it in. Four frames per
load, three loads in a row: frames 0-3 pale saltpetre (grey-white), 4-7 sulphur (yellow),
8-11 charcoal (black): 12 frames, 42x35 cells, anchor (21, 33), west views are these mirrored
(the same as every labourer strip). The cycle inside a load: 0 dig (crouched, blade in the heap),
1 lift (load on the blade), 2 swing (blade out toward the hopper), 3 tip (blade up and over,
the load falling). scripts/unit.gd picks the load from the heap he stands at.

Built from the farm swing's body (art/redraws/new_mine, the redraw's pristine strips, the same
man as the walk and idle strips): the same pick-erasing boxes as tools/import_labourer_hoe.py
(this script uses its helpers), then a spade instead of the hoe: a wooden shaft, a flat iron
blade in line with it, the load heaped on the blade in the ingredient's own four tones, hard
pixels, no blur.

    python3 tools/import_labourer_shovel.py [--contact FILE]
Run after tools/import_labourer_hoe.py (tools/rebuild_art.sh does). Needs Pillow and NumPy.
"""
import math
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_labourer_hoe as H  # noqa: E402

ROOT = H.ROOT
OUT = H.OUT
W, HT = H.W, H.H
DIRS = H.DIRS
WOOD, IRON = H.WOOD, H.IRON

LOADS = {
    "saltpetre": [(240, 244, 248), (205, 212, 224), (165, 175, 192), (118, 128, 148)],
    "sulphur": [(252, 226, 80), (232, 188, 38), (186, 138, 22), (128, 92, 16)],
    "charcoal": [(78, 78, 86), (48, 48, 56), (28, 28, 34), (14, 14, 18)],
}
ORDER = ["saltpetre", "sulphur", "charcoal"]
FRAMES_PER_LOAD = 4


def put(f, x, y, c):
    H.put(f, x, y, c)


def shovel(f, grip, end, load=None, tip=False):
    """Shaft grip->end, then the blade (5 long, 4 wide, in line with the shaft). `load` is a
    palette: heaped on the blade's upper side (or falling off it when `tip`)."""
    gx, gy = grip
    ex, ey = end
    hx, hy = ex - gx, ey - gy
    hl = math.hypot(hx, hy)
    hx, hy = hx / hl, hy / hl
    # the side that is "up" for the blade: perpendicular, pointing to the top of the picture
    nx, ny = -hy, hx
    if ny > 0:
        nx, ny = -nx, -ny
    horiz = abs(hx) > abs(hy)
    sx, sy = (0, 1) if horiz else (1, 0)
    pts = H.line((gx, gy), (ex, ey))
    for (x, y) in pts:
        if 0 <= y + sy < HT and 0 <= x + sx < W and f[y + sy, x + sx, 3] == 0:
            put(f, x + sx, y + sy, WOOD[3])
    for (x, y) in pts:
        put(f, x, y, WOOD[1])
    put(f, gx, gy, WOOD[0])           # the T grip
    # blade: a flat plate in line with the shaft (local u along it, v across, up = +v side)
    cells = {}
    prof = {1: 1.5, 2: 2.0, 3: 2.0, 4: 2.0, 5: 1.5, 6: 0.5}     # half width at u
    for yy in range(HT):
        for xx in range(W):
            dx, dy = xx - ex, yy - ey
            u = dx * hx + dy * hy
            v = dx * nx + dy * ny
            iu = int(round(u))
            if 1 <= iu <= 6 and abs(v) <= prof[iu]:
                cells[(xx, yy)] = (iu, v)
    for (xx, yy), (iu, v) in cells.items():
        c = IRON[3] if iu <= 1 else IRON[0] if iu >= 6 else IRON[2] if v > 0.4 else IRON[1]
        put(f, xx, yy, c)
    ring = {}
    for (xx, yy) in cells:
        for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (xx + ax, yy + ay)
            if q not in cells and 0 <= q[0] < W and 0 <= q[1] < HT and f[q[1], q[0], 3] == 0:
                ring[q] = 1
    for (xx, yy) in ring:
        put(f, xx, yy, (17, 17, 18))
    if load is not None and not tip:
        # a heap on the blade (up side): profile in rows above it, 5 / 4 / 2 wide
        for r_, (u0, u1) in ((1, (2, 6)), (2, (3, 5)), (3, (3, 4))):
            for iu in range(u0, u1 + 1):
                xx = int(round(ex + hx * iu + nx * r_ * 1.0))
                yy = int(round(ey + hy * iu + ny * r_ * 1.0))
                put(f, xx, yy, load[0 if (r_ == 3 or (iu == u0 and r_ == 2)) else 1 if (iu + r_) % 2 else 2])
    if load is not None and tip:
        # the blade tilted over and the load pouring off it (grains and a few lumps, falling)
        tipx = ex + hx * 6
        tipy = ey + hy * 6
        for (dx, dy, k, big) in ((1, 2, 0, 1), (2, 4, 1, 0), (0, 6, 2, 1), (2, 8, 0, 0), (1, 10, 1, 1), (3, 12, 2, 0), (-1, 4, 3, 0)):
            x0 = int(round(tipx + dx))
            y0 = int(round(tipy + dy))
            put(f, x0, y0, load[k])
            if big:
                put(f, x0 + 1, y0, load[(k + 1) % 4])
                put(f, x0, y0 + 1, load[(k + 2) % 4])


def hopper_free(f):
    return f


def body(src, sp, which):
    f = src[sp["body"]].copy()
    for b in sp["boxes"]:
        H.erase(f, b)
    for b in sp["iron"]:
        H.iron_clear(f, b)
    if sp["crouch"]:
        H.iron_clear(f, (20, 30, 32, 34))
        k, lean = sp["crouch"]
        f = H.crouch(f, k, lean=lean)
    return f


# per direction: grips and ends of the four poses (x, y in the cell). The hoe's own grips are
# the starting point (H.SPEC); only the shaft's end differs: dig low and forward, lift up and
# forward, swing out to the right, tip up high.
def poses(d):
    sp = H.SPEC[d]
    g_dig = sp[2]["grip"]
    g_mid = sp[1]["grip"]
    g_up = sp[3]["grip"]
    k = sp[2]["crouch"]
    if k:
        g_dig = (g_dig[0] + k[1], g_dig[1] + (k[0] if g_dig[1] < 24 else 0))
    return [
        dict(body=2, grip=g_dig, end=(g_dig[0] + 5, g_dig[1] + 3), load=False),
        dict(body=1, grip=g_mid, end=(g_mid[0] + 5, g_mid[1] - 4), load=True),
        dict(body=1, grip=g_mid, end=(g_mid[0] + 7, g_mid[1] - 7), load=True),
        dict(body=3, grip=g_up, end=(g_up[0] + 5, g_up[1] - 3), load=True, tip=True),
    ]


def build(d, load_name):
    src = H.load(d)
    out = []
    pal = LOADS[load_name]
    for sp_h, ps in zip([H.SPEC[d][2], H.SPEC[d][1], H.SPEC[d][1], H.SPEC[d][3]], poses(d)):
        spec = dict(sp_h)
        spec["body"] = ps["body"]
        f = body(src, spec, ps["body"])
        shovel(f, ps["grip"], ps["end"], pal if ps["load"] else None, ps.get("tip", False))
        out.append(f)
    return out


def write_art_data(n):
    p = os.path.join(ROOT, "scripts/art_data.gd")
    s = open(p).read()
    s = re.sub(r'\t\t"shovel_\w+": \d+,\n', "", s)
    add = "".join('\t\t"shovel_%s": %d,\n' % (d, n) for d in DIRS)
    key = '\t\t"mine_se": 4,\n'
    assert key in s
    s = s.replace(key, key + add, 1)
    open(p, "w").write(s)


def main():
    rows = []
    for d in DIRS:
        frames = []
        for ln in ORDER:
            frames += build(d, ln)
        rows.append(frames)
        Image.fromarray(np.concatenate(frames, 1)).save(os.path.join(OUT, f"shovel_{d}.png"))
    write_art_data(FRAMES_PER_LOAD * len(ORDER))
    if "--contact" in sys.argv:
        S = 4
        path = sys.argv[sys.argv.index("--contact") + 1]
        sh = Image.new("RGBA", (12 * W * S, len(rows) * HT * S), (90, 110, 90, 255))
        for r, fr in enumerate(rows):
            for k, f in enumerate(fr):
                sh.alpha_composite(Image.fromarray(f).resize((W * S, HT * S), Image.NEAREST), (k * W * S, r * HT * S))
        sh.save(path)
    print("wrote the shovel strips (12 frames x 5 directions) to", OUT)


if __name__ == "__main__":
    main()
