"""Reload animations of the Crown's Field Cannon and Mortar: the crew ramming the charge.

Sources (ChatGPT sheets, flat slate background, rows = facings s, se, e, ne, n):
  art/crown/reload_mortar.png    6 frames: tip in the powder, ram it with a short rammer,
                                 lift a bomb, lower it in, step back.
  art/crown/reload_rammer.png    6 frames of a lone gunner with a long rammer: standing,
                                 raising it, thrusting it forward/down twice, pulling back.
  art/crown/reload_cannon_a.png  two attempts at the whole cannon crew reloading. Their guns,
  art/crown/reload_cannon_b.png  crews and facings change from frame to frame; nothing in them
                                 matches the cannon's art closely enough to use, so they are
                                 kept only as reference.

Mortar: every frame of reload_mortar is cut out, scaled and hung on the mortar's anchor
(the bottom middle of its bed, as in import_round10), so the mortar stays put from idle ->
reload -> fire. Broken drawings are replaced by a neighbour (M_SUB). The crewman with the
short rammer leans into his strokes (his upper body and the rammer pushed down into the
bore, M_LEAN) and rams three times.

Cannon: the deployed idle frame of each facing, less the one crewman the rammer replaces
(fix_cannon_crew.reload_room: the gun keeps its two men, as on the march), with the lone
rammer from reload_rammer standing at the muzzle, scaled to the gun crew's height. In his
thrust frames the sheet's pole is cut off at his hands and a new one drawn into the muzzle; his whole body moves 2-4 px along the
bore between the pulls and the thrusts, three strokes per load.

Reads the published idle frames (assets/units/{cannon,mortar}/idle_*.png), so it runs after
import_cannon2.py, fix_cannon_crew.py and import_round10.py (tools/rebuild_art.sh). Writes
reload_<dir>.png of both units and their reload frame counts in scripts/art_data.gd.

Usage (from the repo root): python3 tools/import_reload.py [--out DIR]
(--out writes the strips there and leaves the game alone). Needs Pillow, NumPy and SciPy.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load  # noqa: E402
from import_cannon2 import Layer, bg_mask, clean, compose, defringe, shrink, snap_team  # noqa: E402
from fix_cannon_crew import reload_room  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
SRC = {
    "mortar": "art/crown/reload_mortar.png",
    "rammer": "art/crown/reload_rammer.png",
}
UNITS = {
    "cannon": dict(cell=(165, 129), anchor=(73, 89)),
    "mortar": dict(cell=(158, 91), anchor=(79, 78)),
}
OUT = "assets/units"


# ---------------------------------------------------------------- sheets

def runs(v, gap):
    """(start, end) of the runs of True in v, bridging holes shorter than gap."""
    out, i, n = [], 0, len(v)
    while i < n:
        if not v[i]:
            i += 1
            continue
        j, last = i, i
        while j < n and (v[j] or j - last < gap):
            if v[j]:
                last = j
            j += 1
        out.append((i, last + 1))
        i = j
    return out


class Sheet:
    """A source sheet cut into its grid of drawings (found from the empty rows/columns)."""

    def __init__(self, path):
        self.px = load(path).astype(np.uint8)
        bg, self.bgc = bg_mask(self.px.astype(np.int32))
        fg = ~bg
        lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
        if n:
            size = ndimage.sum(fg, lab, np.arange(1, n + 1))
            fg &= ~((size < 6)[lab - 1] & (lab > 0))
        self.fg = fg
        self.cells = []
        for y0, y1 in runs(fg.any(1), 12):
            row = [(x0, y0, x1, y1) for x0, x1 in runs(fg[y0:y1].any(0), 12)]
            self.cells.append(row)

    def cut(self, r, c):
        """RGBA drawing (row r, column c) and its sheet origin."""
        x0, y0, x1, y1 = self.cells[r][c]
        img = self.px[y0:y1, x0:x1].copy()
        m = self.fg[y0:y1, x0:x1]
        img[..., 3] = np.where(m, 255, 0)
        img[~m] = 0
        return img, (x0, y0)


def to_game(img, scale, bgc):
    """Source drawing -> game pixels: defringe the slate edge, downscale, key reds."""
    img = defringe(img, bgc)
    small = shrink(img, scale)
    return snap_team(small)


def published(unit, anim, d):
    """Frames of a published strip as Layers on the unit's anchor (cell coordinates
    relative to it)."""
    cw, ch = UNITS[unit]["cell"]
    ax, ay = UNITS[unit]["anchor"]
    strip = np.array(Image.open(f"{OUT}/{unit}/{anim}_{d}.png").convert("RGBA"))
    return [Layer(strip[:, k * cw:(k + 1) * cw].copy(), ax, ay) for k in range(strip.shape[1] // cw)]


# ---------------------------------------------------------------- mortar

M_SCALE = 0.33        # reload_mortar px -> game px: its crew a little under the idle crew's
                      # height, its mortar about the size of the firing mortar's
# Source frames: 0 powder tipped in, 1 rammer raised, 2 rammer in the bore, 3 bomb lifted,
# 4 bomb lowered in, 5 stepped back. The load: powder, then three strokes of the rammer
# (raise, push in, lean in deep), then the bomb. (frame, lean) pairs:
M_SEQ = [(0, 0), (1, 0), (2, 0), (2, 2), (1, 0), (2, 0), (2, 2), (1, 0), (2, 0), (2, 2),
         (3, 0), (4, 0), (5, 0)]
# Broken drawings, replaced by a neighbour: ne 0 and n 0 (a second, ghost head on the
# powder man), se 4 (the mortar drawn bigger and swung round).
M_SUB = {"ne": {0: 1}, "n": {0: 1}, "se": {4: 3}}
# The rammer's lean (frame 2): everything above the bore's rim (cell y < ycut) between
# x0 and x1 (the man holding the rammer, up to just past the pole) pushed down by `lean`
# px, so his shoulders and the rammer go into the bore. Cell coordinates (anchor 79, 78).
M_LEAN = {"s": (55, 86, 49), "se": (55, 83, 50), "e": (55, 85, 51), "ne": (55, 90, 50),
          "n": (55, 81, 50)}


def lean(lay, box, k, unit="mortar"):
    """Push the part of a frame inside box (cell x0, x1, y_cut: everything above y_cut)
    down by k px; what it covers below the cut stays underneath."""
    if not k:
        return lay
    ax, ay = UNITS[unit]["anchor"]
    ox, oy = int(round(lay.ax - ax)), int(round(lay.ay - ay))     # cell -> layer px
    x0, x1, yc = max(0, box[0] + ox), box[1] + ox, box[2] + oy
    img = lay.img.copy()
    part = np.zeros_like(img)
    part[:yc, x0:x1] = img[:yc, x0:x1]
    img[:yc, x0:x1] = 0
    moved = np.zeros_like(img)
    moved[k:] = part[:-k]
    m = moved[..., 3] > 0
    img[m] = moved[m]
    return Layer(img, lay.ax, lay.ay)


def bed_point(img):
    """Bottom middle of the mortar's bed: the middle of the widest run in the lowest rows."""
    a = img[..., 3] > 0
    rows = np.flatnonzero(a.sum(1) >= 3)
    yb = rows.max()
    band = a[yb - 2:yb + 1].any(0)
    best = max(runs(band, 2), key=lambda r: r[1] - r[0])
    return (best[0] + best[1]) / 2.0, yb + 1.0


def build_mortar():
    sh = Sheet(SRC["mortar"])
    out = {}
    for r, d in enumerate(DIRS):
        sub = M_SUB.get(d, {})
        frames = {}
        for c in sorted({sub.get(c, c) for c, _ in M_SEQ}):
            img, _ = sh.cut(r, c)
            small = to_game(img, M_SCALE, sh.bgc)
            bx, by = bed_point(small)
            frames[c] = Layer(small, bx, by)
        out[d] = [lean(frames[sub.get(c, c)], M_LEAN[d], k) for c, k in M_SEQ]
    return out


# ---------------------------------------------------------------- cannon

R_SCALE = 38.0 / 113.0    # reload_rammer px -> game px: the gunner standing (helmet to boots,
                          # 113 px on the sheet) as tall as the cannon's crew (38 px)
# The rule: the rammer stands on the barrel's axis carried on past the muzzle, facing the
# muzzle, feet on the gun's ground; his pole runs along the axis into the bore, and his
# whole body moves 2-4 px along it with each stroke.
#
# Ways to show the pole:
#  "drawn" (se, e, ne: the axis runs across the screen): the side / three-quarter views
#     standing upright, hands at chest height (the muzzle's height); their upright pole is
#     cut away at the hands in the ramming frames and a new one drawn from his hands along
#     the axis into the muzzle.
#  "own" (s: the axis runs at the camera): the back view, standing in front of the muzzle
#     and pushing up into it, drawn over the gun, with the pole as drawn; its top is put in
#     the muzzle (and what of it is past the mouth hidden).
#  "crouch" (n: the axis runs away from the camera): the front view stooping over the
#     muzzle from beyond it (there is no room above the gun in the cell for him upright),
#     the sheet's pole cut at his hands and a new one drawn straight down into the muzzle;
#     drawn under the gun.
#
# The rammer sheet's frames: 0 standing with the rammer upright, 1 raising it, 2 / 3
# thrusting it (stooped), 4 pulling it back up, 5 standing ready (rammer upright). "Nc" is
# frame N with the pole cut off at his hands.
# The loads: (frame, step, out) - step = px his body has moved along the axis toward the
# muzzle; out = px of the rammer's head showing outside the muzzle (a pull), 0 = in the
# bore, None = standing with the pole as drawn.
C_SEQ = {
    "drawn": [(0, 0, None), (1, 0, None), ("0c", 2, 0), ("5c", 4, 0), ("0c", 0, 3),
              ("5c", 4, 0), ("0c", 0, 3), ("5c", 4, 0), (4, 0, None), (5, 0, None)],
    "own": [(0, 0, None), (0, 0, None), (5, 2, None), (0, 4, None), (5, 0, None), (0, 4, None),
            (5, 0, None), (0, 4, None), (5, 0, None), (0, 0, None)],
    "crouch": [("2c", 0, 3), ("3c", 0, 3), ("2c", 2, 0), ("3c", 4, 0), ("2c", 0, 3),
               ("3c", 4, 0), ("2c", 0, 3), ("3c", 4, 0), ("2c", 0, 3), ("3c", 0, 3)],
}
# Per facing: the rammer sheet's row (0 front, 1 three-quarter front, 2 side, 4 back) and
# whether it's mirrored; the muzzle (cell px, the middle of the bore's mouth); `axis`: the
# barrel's axis on screen, pointing out of the muzzle; `reach`: how far past the muzzle
# along the axis his hands are ("drawn") or how far into the bore his pole's end goes
# ("own", negative: in); `over`: drawn over the gun (he's in front of it) or under it.
C_SPEC = {
    "s": dict(mode="own", row=4, mirror=False, mouth=(73.0, 93.0), axis=(0.0, 1.0),
              reach=-7.0, over=True),
    "se": dict(mode="drawn", row=2, mirror=True, mouth=(88.5, 87.5), axis=(0.68, 0.73),
               reach=14.0, over=True),
    "e": dict(mode="drawn", row=2, mirror=True, mouth=(91.5, 65.5), axis=(1.0, 0.0),
              reach=15.0, over=False),
    "ne": dict(mode="drawn", row=1, mirror=True, mouth=(104.0, 55.0), axis=(0.96, -0.28),
               reach=14.0, over=False),
    "n": dict(mode="crouch", row=0, mirror=False, mouth=(73.0, 38.0), axis=(0.0, -1.0),
              reach=10.0, over=False),
}
# Read off the sheet (sheet px). "drawn" frames: `ref` = his front hand on the pole, `cut` =
# the pole's ends (the pole between the hand and each end is cut away). "own" frames:
# `ref` = the end of the pole that goes into the muzzle.
R_REF = {
    (2, 0): dict(ref=(170.0, 497.0), cut=[(170.0, 452.0), (170.0, 548.0)]),
    (2, 5): dict(ref=(1408.0, 497.0), cut=[(1408.0, 478.0), (1408.0, 547.0)]),
    (1, 0): dict(ref=(175.0, 311.0), cut=[(165.0, 253.0), (192.0, 345.0)]),
    (1, 5): dict(ref=(1406.0, 305.0), cut=[(1401.0, 255.0), (1410.0, 351.0)]),
    (4, 0): dict(ref=(163.0, 825.0)),
    (4, 5): dict(ref=(1398.0, 828.0)),
    (0, 2): dict(ref=(682.0, 147.0), cut=[(703.5, 175.0)]),
    (0, 3): dict(ref=(916.0, 147.0), cut=[(930.0, 179.0)]),
}
POLE = {"edge": (40, 22, 12), "lit": (214, 140, 74), "wood": (160, 92, 44)}
HEAD = {"edge": (26, 26, 30), "iron": (72, 74, 82), "lit": (138, 140, 150)}


def cut_pole(img, origin, hand, ends):
    """Erase the sheet's pole from just past the hand to each end (sheet px): its wood and
    the dark outline along it, and the iron head at an end that lies below the hand. Only
    wood-coloured pixels (and their outline) go, so a helmet or face the pole passes stays."""
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    xx += origin[0]
    yy += origin[1]
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    wood = (r > 70) & (g < 0.72 * r) & (b < 0.48 * r) & (g > b)
    dark = rgb.max(-1) < 75
    hx, hy = hand
    gone = np.zeros((h, w), bool)
    for tx, ty in ends:
        L = np.hypot(tx - hx, ty - hy)
        ux, uy = (tx - hx) / L, (ty - hy) / L
        t = (xx - hx) * ux + (yy - hy) * uy
        dist = np.abs((xx - hx) * uy - (yy - hy) * ux)
        band = (t > 4) & (t < L + 6) & (dist <= 8)
        w_ = band & wood
        gone |= w_ | (band & dark & ndimage.binary_dilation(w_, iterations=2))
        if ty > hy:
            gone |= np.hypot(xx - tx, yy - ty) <= 12       # the iron rammer head
    out = img.copy()
    out[gone] = 0
    return out


def heel_of(img, back):
    """The rear heel: the back-most pixel of the lowest rows of his back half (back = -1:
    his back is to the left; 0: seen from the front/back, the middle of his feet). The back
    half only: the rammer's head, resting on the ground in front of him, reaches lower than
    his boots."""
    a = img[..., 3] > 0
    xs = np.flatnonzero(a.any(0))
    mid = (xs.min() + xs.max() + 1) // 2
    rear = a.copy()
    if back < 0:
        rear[:, mid:] = False
    elif back > 0:
        rear[:, :mid] = False
    yb = np.flatnonzero(rear.any(1)).max()
    xs = np.flatnonzero(rear[yb - 6:yb + 1].any(0))
    if back == 0:
        return (xs.min() + xs.max() + 1) / 2.0, yb + 1.0
    return (xs.min() if back < 0 else xs.max() + 1.0), yb + 1.0


def draw_pole(a, b, head):
    """A rammer pole from a to b (cell px) - 4 px thick, lit on its upper side - with the
    rammer's iron head at b if `head`. Returns a Layer on the cannon's anchor."""
    ax, ay = UNITS["cannon"]["anchor"]
    cw, ch = UNITS["cannon"]["cell"]
    img = np.zeros((ch, cw, 4), np.uint8)
    yy, xx = np.mgrid[0:ch, 0:cw].astype(float) + 0.5
    (x0, y0), (x1, y1) = a, b
    L = max(np.hypot(x1 - x0, y1 - y0), 1e-3)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux                      # the side facing down (or right)
    if ny < 0 or (ny == 0 and nx < 0):
        nx, ny = -nx, -ny
    t = (xx - x0) * ux + (yy - y0) * uy
    s = (xx - x0) * nx + (yy - y0) * ny
    on = (t >= 0) & (t <= L) & (np.abs(s) <= 1.9)
    col = np.where((s < -1.0)[..., None] | (s > 1.0)[..., None], POLE["edge"],
                   np.where((s < 0)[..., None], POLE["lit"], POLE["wood"]))
    img[on, :3] = col[on]
    img[on, 3] = 255
    if head:
        r = np.hypot(xx - x1, yy - y1)
        ball = r <= 2.6
        img[ball, :3] = HEAD["edge"]
        inner = r <= 1.7
        img[inner, :3] = HEAD["iron"]
        lit = inner & (yy < y1) & (xx < x1 + 0.5)
        img[lit, :3] = HEAD["lit"]
        img[ball, 3] = 255
    return Layer(img, ax, ay)


def into_bore(lay, mouth):
    """Seen from the front (s), the pole above the middle of the muzzle's mouth is inside
    the bore: its wood there goes (the rammer's helmet and shoulders stay)."""
    ax, ay = UNITS["cannon"]["anchor"]
    img = lay.img.copy()
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    cx = xx + 0.5 - lay.ax + ax
    cy = yy + 0.5 - lay.ay + ay
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    wood = (r > g + 25) & (g > b + 10) | (rgb.max(-1) < 60)      # wood and its dark outline
    zone = (np.abs(cx - mouth[0]) <= 3.0) & (cy < mouth[1])
    img[zone & wood] = 0
    return Layer(img, lay.ax, lay.ay)


def build_cannon():
    sh = Sheet(SRC["rammer"])
    ax, ay = UNITS["cannon"]["anchor"]
    out = {}
    for d in DIRS:
        sp = C_SPEC[d]
        seq = C_SEQ[sp["mode"]]
        axis = np.array(sp["axis"], float)
        axis /= np.hypot(*axis)
        if sp["mode"] == "own":
            back = 0
        else:
            back = 1 if sp["mirror"] else -1        # which side his back (rear heel) is on
        gun = published("cannon", "idle", d)[0]
        gun = Layer(reload_room(d, gun.img), gun.ax, gun.ay)    # the rammer takes a man's place
        figs, refs = {}, {}
        for c in {c for c, _, _ in seq}:
            n = int(str(c)[0])
            img, (x0, y0) = sh.cut(sp["row"], n)
            info = R_REF.get((sp["row"], n))
            if str(c).endswith("c"):
                img = cut_pole(img, (x0, y0), info["ref"], info["cut"])
            small = to_game(img, R_SCALE, sh.bgc)
            k = small.shape[1] / img.shape[1]
            if info:
                refs[c] = ((info["ref"][0] - x0) * k, (info["ref"][1] - y0) * k)
            if sp["mirror"]:
                small = small[:, ::-1].copy()
                if c in refs:
                    refs[c] = (small.shape[1] - refs[c][0], refs[c][1])
            figs[c] = small
        mouth = np.array(sp["mouth"])
        home = mouth + axis * sp["reach"]       # where the reference point sits at step 0
        # his heel at step 0 (from frame 0's reference point at home)
        f0 = seq[2][0]
        hx, hy = heel_of(figs[f0], back)
        heel0 = home + np.array([hx - refs[f0][0], hy - refs[f0][1]])
        frames = []
        for c, step, outpx in seq:
            shift = -axis * step                # toward the muzzle along the axis
            if c in refs:
                at = home + shift
                lay = Layer(figs[c], refs[c][0] - (at[0] - ax), refs[c][1] - (at[1] - ay))
            else:
                hx, hy = heel_of(figs[c], back)
                at = heel0 + shift
                lay = Layer(figs[c], hx - (at[0] - ax), hy - (at[1] - ay))
            layers = [lay]
            if sp["mode"] != "own" and outpx is not None:
                hand = home + shift
                end = mouth + axis * outpx
                pole = draw_pole(tuple(hand), tuple(end), outpx > 0)
                # facing the camera (crouch) the pole is in front of him; else behind his arm
                layers = [lay, pole] if sp["mode"] == "crouch" else [pole, lay]
            fig = compose(layers)
            if d == "s":
                fig = into_bore(fig, mouth)
            frames.append(compose([gun, fig]) if sp["over"] else compose([fig, gun]))
        out[d] = frames
    return out


# ---------------------------------------------------------------- output

def strip_of(unit, frames):
    cw, ch = UNITS[unit]["cell"]
    ax, ay = UNITS[unit]["anchor"]
    strip = np.zeros((ch, cw * len(frames), 4), np.uint8)
    for k, l in enumerate(frames):
        img = clean(l.img, min_size=7, keep_near=1)
        ox, oy = int(round(ax - l.ax)), int(round(ay - l.ay))
        h, w = img.shape[:2]
        # clip to the cell
        sx0, sy0 = max(0, -ox), max(0, -oy)
        sx1, sy1 = min(w, cw - ox), min(h, ch - oy)
        if sx0 > 0 or sy0 > 0 or sx1 < w or sy1 < h:
            lost = (img[..., 3] > 0).sum() - (img[sy0:sy1, sx0:sx1, 3] > 0).sum()
            if lost:
                print(f"  ! {unit} frame {k}: {lost} px outside the cell")
        cell = strip[:, k * cw:(k + 1) * cw]
        sub = img[sy0:sy1, sx0:sx1]
        m = sub[..., 3] > 0
        cell[oy + sy0:oy + sy1, ox + sx0:ox + sx1][m] = sub[m]
    return strip


def write_counts(unit, counts):
    path = "scripts/art_data.gd"
    src = open(path).read()
    m = re.search(r'\t"%s": \{"cell".*?\n\t\}\},\n' % unit, src, re.S)
    if not m:
        raise SystemExit(f"{unit} entry not found in {path}")
    entry = m.group(0)
    for key, n in counts.items():
        entry, k = re.subn(r'(\t\t"%s": )\d+,' % key, r"\g<1>%d," % n, entry)
        if not k:
            raise SystemExit(f"{unit} {key} not in {path}")
    open(path, "w").write(src[:m.start()] + entry + src[m.end():])


def main():
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else None
    built = {"mortar": build_mortar(), "cannon": build_cannon()}
    for unit, per_dir in built.items():
        counts = {}
        for d, frames in per_dir.items():
            strip = strip_of(unit, frames)
            folder = os.path.join(out, unit) if out else os.path.join(OUT, unit)
            os.makedirs(folder, exist_ok=True)
            Image.fromarray(strip).save(os.path.join(folder, f"reload_{d}.png"))
            counts[f"reload_{d}"] = len(frames)
        print(f"{unit}: " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
        if not out:
            write_counts(unit, counts)


if __name__ == "__main__":
    main()
