"""Synthetic test sheets for tools/import_line_art.py. They imitate the real ChatGPT sheets: NO exact grid
(every figure is jittered in position and size), pipes drawn by their arms, junk blobs between figures.
Nothing here goes into assets/.
    python3 tools/line_art_test/make_sheets.py <tmp dir>
Checks: tile files are exactly 32x32 with every arm touching its edge midpoint (ES made by mirroring cell 5),
relay/drill/loco/cars scale by ONE factor per sheet to the target widths, steam frames share one canvas.
"""
import os
import random
import subprocess
import sys

import numpy as np
from PIL import Image

NAVY = (0, 22, 48)
d = sys.argv[1]
src = os.path.join(d, "src")
out = os.path.join(d, "out")
os.makedirs(src, exist_ok=True)
rnd = random.Random(7)
ORDER = ["ew", "ns", "ne", "es", "sw", "nw", "nes", "esw", "nsw", "new", "nesw", "n", "e", "s", "w"]


def canvas():
    a = np.zeros((1024, 1536, 3), np.uint8)
    a[:, :] = NAVY
    return a


def blk(a, x0, y0, x1, y1, col):
    a[max(0, y0):y1, max(0, x0):x1] = col


def sheet(cols, rows, fn, draw):
    a = canvas()
    sw, sh = 1536 / cols, 1024 / rows
    for i in range(cols * rows):
        c, r = i % cols, i // cols
        cx = int((c + 0.5) * sw) + rnd.randint(-25, 25)
        cy = int((r + 0.5) * sh) + rnd.randint(-25, 25)
        draw(a, i, cx, cy)
    Image.fromarray(a).save(os.path.join(src, fn))


def tile_draw(a, i, cx, cy):
    sides = ORDER[i]
    if i == 3:
        sides = "sw"          # the real sheet repeats SW in cell 4
    col = (40 + i * 12, 200 - i * 8, 90 + i * 5)
    w = rnd.randint(52, 70)
    arm = rnd.randint(78, 100)
    jy, jx = rnd.randint(-8, 8), rnd.randint(-8, 8)
    blk(a, cx - w // 2 + jx, cy - w // 2 + jy, cx + w // 2 + jx, cy + w // 2 + jy, col)
    for s in sides:
        if s == "n":
            blk(a, cx - w // 2 + jx, cy - arm + jy, cx + w // 2 + jx, cy + jy, col)
        if s == "s":
            blk(a, cx - w // 2 + jx, cy + jy, cx + w // 2 + jx, cy + arm + jy, col)
        if s == "w":
            blk(a, cx - arm + jx, cy - w // 2 + jy, cx + jx, cy + w // 2 + jy, col)
        if s == "e":
            blk(a, cx + jx, cy - w // 2 + jy, cx + arm + jx, cy + w // 2 + jy, col)


def figure(wmin, wmax, hmin, hmax, col):
    def f(a, i, cx, cy):
        w, h = rnd.randint(wmin, wmax), rnd.randint(hmin, hmax)
        c = tuple(min(255, v + (i % 5) * 9) for v in col)
        blk(a, cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2, c)
        blk(a, cx + w // 2 + 3, cy - h // 2 - 5, cx + w // 2 + 12, cy - h // 2 + 6, c)   # a smoke speck
    return f


sheet(5, 3, "line_tiles.png", tile_draw)
sheet(4, 2, "line_damage.png", figure(130, 190, 120, 200, (200, 60, 50)))
sheet(2, 2, "line_relay.png", figure(260, 320, 200, 300, (180, 120, 40)))
sheet(4, 2, "line_drill.png", figure(280, 330, 300, 380, (90, 120, 200)))
sheet(4, 3, "line_loco.png", figure(250, 320, 150, 220, (220, 60, 60)))
sheet(3, 3, "line_cars.png", figure(200, 300, 140, 200, (60, 200, 120)))
subprocess.check_call([sys.executable, os.path.join(os.path.dirname(__file__), "..", "import_line_art.py"), "--src", src, "--out", out])

errs = []


def img(p):
    return Image.open(os.path.join(out, p)).convert("RGBA")


def need(p):
    if not os.path.exists(os.path.join(out, p)):
        errs.append("missing " + p)
        return False
    return True


for n in ORDER:
    p = "assets/world/line/tile_%s.png" % n
    if not need(p):
        continue
    im = img(p)
    if im.size != (32, 32):
        errs.append("%s is %s" % (p, im.size))
        continue
    al = np.array(im)[:, :, 3] > 0
    # each arm must touch its edge middle (+-3 px)
    for s in n if n != "nesw" else "nesw":
        if len(n) == 1 and s != n:
            continue
        edge = {"n": al[0, 10:22], "s": al[31, 10:22], "w": al[10:22, 0], "e": al[10:22, 31]}[s]
        if not edge.any():
            errs.append("%s: arm %s does not reach the middle of its edge" % (p, s))
sw = np.array(img("assets/world/line/tile_sw.png"))
es = np.array(img("assets/world/line/tile_es.png"))
if not (es == sw[:, ::-1]).all():
    errs.append("tile_es is not the mirror of tile_sw")
for k in ("dmg_ew_damaged", "dmg_ew_destroyed", "dmg_ns_damaged", "dmg_ns_destroyed"):
    if need("assets/world/line/%s.png" % k) and img("assets/world/line/%s.png" % k).size != (32, 32):
        errs.append(k + " not 32x32")
st = [img("assets/world/line/steam_%d.png" % i).size for i in range(1, 5)]
if len(set(st)) != 1:
    errs.append("steam frames differ: %s" % st)
for s in ("built", "construction", "damaged", "destroyed"):
    need("assets/buildings/pressure_relay_%s.png" % s)
    need("assets/buildings/ore_drill_%s.png" % s)
if need("assets/buildings/pressure_relay_built.png") and abs(img("assets/buildings/pressure_relay_built.png").size[0] - 70) > 1:
    errs.append("relay not 70 wide")
if need("assets/buildings/ore_drill_built.png") and abs(img("assets/buildings/ore_drill_built.png").size[0] - 115) > 1:
    errs.append("drill not 115 wide")
if need("assets/buildings/ore_drill_working.png"):
    w, h = img("assets/buildings/ore_drill_working.png").size
    if w % 4:
        errs.append("working strip not 4 frames")
for v in "esn":
    need("assets/units/ore_locomotive/run_%s.png" % v)
    need("assets/units/ore_locomotive/idle_%s.png" % v)
    for k, s in (("ore_car", "empty"), ("ore_car", "full"), ("troop_car", "idle")):
        need("assets/units/%s/%s_%s.png" % (k, s, v))
print("FAIL: " + "; ".join(errs) if errs else "line art importer: PASS")
sys.exit(1 if errs else 0)
