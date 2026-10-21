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

Cannon: the deployed idle frame of each facing (gun, carriage and crew unchanged; on the
north view the left crewman makes room) with the lone rammer from reload_rammer standing at
the muzzle, scaled to the gun crew's height. In his thrust frames the sheet's pole is cut
off at his hands and a new one drawn into the muzzle; his whole body moves 2-4 px along the
bore between the pulls and the thrusts, three strokes per load.

Reads the published idle frames (assets/units/{cannon,mortar}/idle_*.png), so it runs after
import_cannon2.py and import_round10.py (tools/rebuild_art.sh). Writes reload_<dir>.png of
both units and their reload frame counts in scripts/art_data.gd.

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
# The rammer's frames: 0 standing with the rammer, 1 raising it, 2 thrusting it, 3 thrust
# deeper, 4 pulling it back up, 5 standing ready. In the thrust frames (2, 3) the sheet's
# pole points wherever it likes, so it is cut off at his hands and a new one is drawn from
# his hands into the muzzle.
# The load: (frame, step, out) - step = px his whole body has moved toward the gun along
# the bore from where he stands to pull; out = px of the rammer's head showing outside the
# muzzle (0: it is in the bore). Three strokes: push in, ram deep, pull back.
C_SEQ = [(0, 0, None), (1, 0, None), (2, 2, 0), (3, 4, 0), (2, 0, 3), (3, 4, 0), (2, 0, 3),
         (3, 4, 0), (4, 0, None), (5, 0, None)]
# Per facing: the rammer sheet's row (0 s, 1 se, 2 e, 3 ne, 4 n) and whether it is
# mirrored; the muzzle (cell px: where the pole enters the bore); `bore`: the direction the
# pole goes in (his body moves along it); `hand`: where his front hand is when he pulls;
# `over`: he stands in front of the gun (drawn over it) or behind (under it); `erase`:
# cell boxes (x0, y0, x1, y1) of the gun crewman he replaces; `stand`: px he steps toward
# the camera to stand upright (no room for him and his raised rammer where he rams).
#   s:  muzzle toward the camera: he stands left of it and a step in front, side-on (the
#       side view), the pole across into the mouth.
#   se: muzzle toward the lower right: he stands right of it and in front, facing back at
#       it (side view mirrored).
#   e:  in front of the muzzle, facing back at it (side view mirrored).
#   ne: muzzle toward the upper right: he stands beyond it, facing down-left at it (the
#       south-east view mirrored); behind the gun.
#   n:  muzzle away from the camera: he stands behind the gun, left of the muzzle, facing
#       the camera, in place of the gun's left crewman; behind the gun.
C_SPEC = {
    "s": dict(row=2, mirror=False, mouth=(68.0, 93.0), bore=(1.0, -0.15), hand=(57.0, 95.0),
              over=True),
    "se": dict(row=2, mirror=True, mouth=(89.5, 87.5), bore=(-0.85, -0.5), hand=(102.0, 94.0),
               over=True),
    "e": dict(row=2, mirror=True, mouth=(91.5, 65.5), bore=(-1.0, -0.15), hand=(106.0, 70.0),
              over=False),
    "ne": dict(row=1, mirror=True, mouth=(104.0, 55.0), bore=(-0.8, 0.6), hand=(115.0, 47.0),
               over=False),
    "n": dict(row=0, mirror=False, mouth=(73.0, 39.0), bore=(0.35, 0.95), hand=(63.0, 31.0),
              over=False, erase=[(30, 25, 56, 76), (56, 25, 60, 66)], stand=(1, 6)),
}
# The thrust frames on the sheet (sheet px, read off it): where the pole leaves his front
# hand, and the middle of the rammer's head - the pole between them is cut away.
R_HAND = {(0, 2): (682.0, 147.0), (0, 3): (916.0, 147.0),
          (1, 2): (682.0, 335.0), (1, 3): (915.0, 336.0),
          (2, 2): (683.0, 512.0), (2, 3): (913.0, 512.0)}
R_TIP = {(0, 2): (703.5, 175.0), (0, 3): (930.0, 179.0),
         (1, 2): (700.0, 361.0), (1, 3): (931.0, 366.0),
         (2, 2): (723.0, 527.0), (2, 3): (957.0, 528.0)}
POLE = {"edge": (40, 22, 12), "lit": (214, 140, 74), "wood": (160, 92, 44)}
HEAD = {"edge": (26, 26, 30), "iron": (72, 74, 82), "lit": (138, 140, 150)}


def cut_pole(img, origin, hand, tip):
    """Erase the sheet's pole from just past the hand to the head (sheet px)."""
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    xx += origin[0]
    yy += origin[1]
    hx, hy = hand
    tx, ty = tip
    L = np.hypot(tx - hx, ty - hy)
    ux, uy = (tx - hx) / L, (ty - hy) / L
    t = (xx - hx) * ux + (yy - hy) * uy
    dist = np.abs((xx - hx) * uy - (yy - hy) * ux)
    pole = (t > 3) & (t < L) & (dist <= 8)
    head = np.hypot(xx - tx, yy - ty) <= 13
    out = img.copy()
    out[pole | head] = 0
    return out


def heel_of(img, back):
    """The rear heel: the back-most pixel of the lowest rows of his back half (back = -1:
    his back is to the left). The back half only: the rammer's head, resting on the ground
    in front of him, reaches lower than his boots."""
    a = img[..., 3] > 0
    xs = np.flatnonzero(a.any(0))
    mid = (xs.min() + xs.max() + 1) // 2
    rear = a.copy()
    if back < 0:
        rear[:, mid:] = False
    else:
        rear[:, :mid] = False
    yb = np.flatnonzero(rear.any(1)).max()
    xs = np.flatnonzero(rear[yb - 6:yb + 1].any(0))
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


def erase_boxes(lay, boxes):
    img = lay.img.copy()
    ax, ay = UNITS["cannon"]["anchor"]
    for x0, y0, x1, y1 in boxes:
        ox, oy = int(round(lay.ax - ax)), int(round(lay.ay - ay))
        img[max(0, y0 + oy):y1 + oy, max(0, x0 + ox):x1 + ox] = 0
    return Layer(img, lay.ax, lay.ay)


def build_cannon():
    sh = Sheet(SRC["rammer"])
    ax, ay = UNITS["cannon"]["anchor"]
    out = {}
    for d in DIRS:
        sp = C_SPEC[d]
        bore = np.array(sp["bore"], float)
        bore /= np.hypot(*bore)
        back = 1 if sp["mirror"] else -1          # which side his back (rear heel) is on
        gun = published("cannon", "idle", d)[0]
        if "erase" in sp:
            gun = erase_boxes(gun, sp["erase"])
        figs, hands = {}, {}
        for c in sorted({c for c, _, _ in C_SEQ}):
            img, (x0, y0) = sh.cut(sp["row"], c)
            key = (sp["row"], c)
            if key in R_HAND:
                img = cut_pole(img, (x0, y0), R_HAND[key], R_TIP[key])
            small = to_game(img, R_SCALE, sh.bgc)
            k = small.shape[1] / img.shape[1]
            if key in R_HAND:
                hands[c] = ((R_HAND[key][0] - x0) * k, (R_HAND[key][1] - y0) * k)
            if sp["mirror"]:
                small = small[:, ::-1].copy()
                if c in hands:
                    hands[c] = (small.shape[1] - hands[c][0], hands[c][1])
            figs[c] = small
        # where he stands to pull: his rear heel when frame 2's hand is at sp["hand"]
        hx, hy = heel_of(figs[2], back)
        heel0 = (sp["hand"][0] + hx - hands[2][0], sp["hand"][1] + hy - hands[2][1])
        frames = []
        for c, step, outpx in C_SEQ:
            dx, dy = bore * step
            hx, hy = heel_of(figs[c], back)
            if outpx is None:
                # standing: by the rear heel, rammer upright as drawn (`stand`: a step from
                # the ramming spot, where there's no room for him upright)
                sx, sy = sp.get("stand", (0, 0))
                lay = Layer(figs[c], hx - (heel0[0] + sx - ax), hy - (heel0[1] + sy - ay))
                layers = [lay]
            else:
                # by the hand; the hand moves with the body, so pin the rear heel first and
                # read where that puts his hand
                lay = Layer(figs[c], hx - (heel0[0] + dx - ax), hy - (heel0[1] + dy - ay))
                hand = (hands[c][0] - lay.ax + ax, hands[c][1] - lay.ay + ay)
                end = (sp["mouth"][0] - bore[0] * outpx, sp["mouth"][1] - bore[1] * outpx)
                layers = [draw_pole(hand, end, outpx > 0), lay]
            fig = compose(layers)
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
