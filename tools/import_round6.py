"""Round 6 art: the Crown Powder Wagon, the labourer's keg (carry / bury / blow up), the
buried keg mine, and small UI pieces (kegs, the bandage cross, digits).

Sources (generated sheets on a flat slate background):
  art/crown/powder_wagon.png    5 rows; groups walk (6, with stray standing driver figures
                                between the walk frames of row 0), unload (1), death (4)
  art/crown/labourer_keg.png    rows 0-4: walk with keg (6), idle with keg (4), bury (6),
                                death-explode (6); row 5: a back view walking (6) and two
                                small figures (unused); rows 6-7: the keg mine - idle (5),
                                arm (3) + explosion (6, ending in a crater)
  art/ui/keg_cross_numbers.png  7 kegs; the red cross; the digits 0-9

Every sprite on these sheets stands apart from its neighbours (empty columns between
them), so frames are cut at the gaps; specks and sparks between two drawings go to the
nearest one. Frames are converted with the round 4 machinery (tools/import_round4.py:
slate mask, box-filter shrink, team reds snapped to the key colours, specks and slate
fringe removed) - with one change: reds next to fire (flames, lanterns, explosions) are
nudged off the key colours instead of snapped to them, so fire never takes team colour.
The PLAN notes below say which source frames make each animation and direction.

Output:
  assets/units/powder_wagon/<anim>_<dir>.png       walk, idle, unload, death
  assets/units/labourer/{carry_keg,idle_keg,bury,death_keg}_<dir>.png
      (added to the labourer's own set, in its cell and on its anchor)
  assets/icons/powder_wagon.png                    64x64 button icon
  assets/effects/keg_mine.png, keg_mine_arm.png, keg_mine_blast.png
  assets/effects/keg.png, cross.png, digits.png
  scripts/art_data.gd: the "powder_wagon" entry of UNITS, the new keys in the labourer's
  "frames", and the keg_* / cross / digits entries of EFFECTS (added or replaced in
  place; nothing else in the file is touched)

Usage (from the repo root): python3 tools/import_round6.py [--contact DIR] [--debug DIR]
(--contact writes x3 contact sheets on grass green; --debug dumps the cut source frames)
Needs Pillow, NumPy and SciPy. Re-runnable. Run after tools/import_art.py (it reads the
labourer's cell, anchor and size from scripts/art_data.gd and assets/units/labourer).
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_round4 as r4  # noqa: E402
import import_cannon2 as c2  # noqa: E402
from import_art import load, make_icon  # noqa: E402
from import_cannon2 import bg_mask, clean  # noqa: E402
from import_round4 import (F, align, assemble, body_of, contact_sheet, mirror,  # noqa: E402
                           place, write_effects_data, write_units_data)

DIRS = ["s", "se", "e", "ne", "n"]
DEBUG = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
TEAM_LIGHT, TEAM_DARK = (255, 0, 0), (150, 0, 0)


# ---------------------------------------------------------------- cutting

def cut_sheet(path, min_mass=30):
    """[[frame, ...] per row] with frame = dict(img = source RGBA crop (alpha = mask),
    x0, y0, x1, y1), and the slate colour. Rows and frames are split at empty lines and
    columns; loose bits (sparks, smoke wisps) join the nearest drawing of their row."""
    px = load(path)
    bg, bgc = bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 4)[lab - 1] & (lab > 0))
    rows = []
    lines = fg.any(1)
    y = 0
    while y < len(lines):
        if not lines[y]:
            y += 1
            continue
        a = y
        while y < len(lines) and lines[y]:
            y += 1
        b = y
        cols = fg[a:b].sum(0)
        runs, x = [], 0
        while x < len(cols):
            if cols[x] > 0:
                s = x
                while x < len(cols) and cols[x] > 0:
                    x += 1
                runs.append([s, x, int(cols[s:x].sum())])
            else:
                x += 1
        big = [r for r in runs if r[2] > min_mass]
        if not big:
            continue
        spans = [[r[0], r[1]] for r in big]
        for r in runs:
            if r[2] > min_mass:
                continue
            c = (r[0] + r[1]) / 2.0
            k = min(range(len(big)), key=lambda i: min(abs(c - big[i][0]), abs(c - big[i][1])))
            spans[k] = [min(spans[k][0], r[0]), max(spans[k][1], r[1])]
        frames = []
        for x0, x1 in spans:
            m = np.zeros_like(fg)
            m[a:b, x0:x1] = fg[a:b, x0:x1]
            ys, xs = np.nonzero(m)
            y0, y1, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            img = px[y0:y1, xa:xb].copy()
            mm = m[y0:y1, xa:xb]
            img[~mm] = 0
            img[..., 3] = np.where(mm, 255, 0)
            frames.append(dict(img=img.astype(np.uint8), x0=xa, y0=y0, x1=xb, y1=y1))
        rows.append(frames)
    return rows, bgc


# ---------------------------------------------------------------- team reds next to fire

def fire_px(img):
    """Flame / lantern / explosion colours: bright orange and yellow."""
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    return (img[..., 3] > 0) & (r >= 170) & (g >= 0.38 * r) & (b <= 0.55 * g) & (r - b >= 90)


_snap = c2.snap_team


def snap_team(img, effect=False):
    """c2.snap_team, but reds touching fire pixels are treated as fire (nudged off the
    key colours), so flames and explosions don't take the team colour."""
    if effect:
        return _snap(img, True)
    near = ndimage.binary_dilation(fire_px(img), iterations=2)
    team = _snap(img, False)
    fx = _snap(img, True)
    team[near] = fx[near]
    return team


r4.snap_team = snap_team


def to_game(img, scale, bgc):
    out, gl = r4.to_game(img, scale, bgc, None)
    return out


def frame_of(src, scale, bgc):
    img = to_game(src["img"], scale, bgc)
    return F(img, np.zeros(img.shape[:2], bool))


def keep_main(f, min_size=6):
    """Drop loose pieces smaller than min_size far from the drawing (clean() does the
    1-3 pixel specks)."""
    g = f.copy()
    g.img = clean(g.img, min_size=min_size, keep_near=1)
    g.glow &= g.img[..., 3] > 0
    return g


def trim(f):
    ys, xs = np.nonzero(f.img[..., 3] > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return F(f.img[y0:y1, x0:x1].copy(), f.glow[y0:y1, x0:x1].copy(), f.ax - x0, f.ay - y0)


def bbox(f):
    ys, xs = np.nonzero(f.img[..., 3] > 0)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def anchored_at(f, ax, ay):
    g = f.copy()
    g.ax, g.ay = ax, ay
    return g


def dump(name, rows, scale, bgc):
    lines = []
    for r, fr in enumerate(rows):
        lines.append((f"r{r}", [to_game(f["img"], scale, bgc) for f in fr]))
    contact_sheet(os.path.join(DEBUG, f"src_{name}.png"), lines)


# ---------------------------------------------------------------- overlays

def smoke_px(img):
    """Grey smoke: low chroma, not the dark outline."""
    rgb = img[..., :3].astype(int)
    mx, mn = rgb.max(-1), rgb.min(-1)
    return (img[..., 3] > 0) & (mx - mn <= 30) & (rgb.mean(-1) >= 55)


def fire_layer(f):
    """The flames (and the smoke rising from them) of frame f alone, as a frame with the
    same anchor: the big blobs of fire pixels plus the dark-red / smoke pixels around
    them (loose embers and lit lanterns are left out)."""
    fire = fire_px(f.img)
    lab, n = ndimage.label(ndimage.binary_dilation(fire, iterations=1), structure=np.ones((3, 3)))
    if n:
        size = ndimage.sum(fire, lab, np.arange(1, n + 1))
        fire &= (size >= max(12, size.max() * 0.2))[lab - 1] & (lab > 0)
    reach = ndimage.binary_dilation(fire, iterations=2)
    sm = smoke_px(f.img)
    lab, n = ndimage.label(sm | fire, structure=np.ones((3, 3)))
    keep = fire | (reach & (f.img[..., 3] > 0) & (f.img[..., 0].astype(int) > f.img[..., 2].astype(int) + 40))
    for i in range(1, n + 1):
        m = lab == i
        if (m & fire).any():
            keep |= m & sm
    # smoke above the drawing's top half only (grey wood and iron below are not smoke)
    ys = np.flatnonzero((f.img[..., 3] > 0).any(1))
    cut = ys.min() + int((ys.max() - ys.min()) * 0.55)
    keep &= fire | reach | (np.arange(f.img.shape[0])[:, None] < cut)
    g = f.copy()
    g.img[~keep] = 0
    g.glow[:] = False
    return g


def mass_centre(img, m=None):
    m = (img[..., 3] > 0) if m is None else m
    ys, xs = np.nonzero(m)
    return xs.mean() + 0.5, ys.mean() + 0.5


def lay(base, top, dx=0, dy=0):
    """base with top drawn over it; top's anchor at base's anchor + (dx, dy)."""
    return r4.overlay(base, top, dx=dx, dy=dy)


def bob_rect(f, rect, dy=1):
    """The pixels in rect (x0, y0, x1, y1 relative to the anchor) moved down dy: a horse
    lowering its head, for an idle from one drawing."""
    g = f.copy()
    x0, y0, x1, y1 = [int(round(v)) for v in (rect[0] + f.ax, rect[1] + f.ay, rect[2] + f.ax, rect[3] + f.ay)]
    h, w = g.img.shape[:2]
    x0, x1, y0, y1 = max(0, x0), min(w, x1), max(0, y0), min(h - dy, y1)
    part = f.img[y0:y1, x0:x1].copy()
    g.img[y0:y0 + dy, x0:x1] = 0
    # the vacated top row keeps whatever was behind... nothing: the head moved
    m = part[..., 3] > 0
    tgt = g.img[y0 + dy:y1 + dy, x0:x1]
    tgt[m] = part[m]
    return g


# ---------------------------------------------------------------- powder wagon

WAGON = "art/crown/powder_wagon.png"
WAGON_SCALE = 0.40        # horse about the size of the field cannon's horses
WAGON_DEPTH = 8           # the anchor sits this far above the lowest pixel (footprint middle)


def wagon_anchor(f):
    x0, x1, y0, y1 = bbox(f)
    return anchored_at(f, (x0 + x1) / 2.0, y1 - WAGON_DEPTH)


def plan_wagon():
    """Rows as drawn: 0 = S (front, horse towards the camera), 1 = between SE and E,
    2 = E (three-quarter, the most side-on), 3 = between S and SE (used as SE), 4 = N
    (the back of the wagon with its kegs). Rows 1 and 3 are near-repeats of the same
    front three-quarter; no back three-quarter (NE) was drawn: NE reuses E.
    Row 0 has a standing driver drawn between walk frames (and one with a keg): dropped.
    Death: the sheet draws every row's burning wagon as a three-quarter side view; S and N
    keep their own wagon (walk frame 0) with that row's flames laid over it, then the
    explosion and the wreck as drawn."""
    rows, bgc = cut_sheet(WAGON)
    if DEBUG:
        dump("wagon", rows, WAGON_SCALE, bgc)
    groups = []
    for r, fr in enumerate(rows):
        walk = [fr[i] for i in (0, 1, 2, 4, 6, 8)] if r == 0 else fr[:6]
        unload, death = fr[-5], fr[-4:]
        groups.append((walk, unload, death))

    def conv(s):
        return keep_main(wagon_anchor(frame_of(s, WAGON_SCALE, bgc)))
    use = {"s": 0, "se": 3, "e": 2, "ne": 2, "n": 4}
    A = {}
    for d, r in use.items():
        walk, unload, death = groups[r]
        w = [conv(s) for s in walk]
        w = [w[0]] + [align(w[0], f, "high", 4) for f in w[1:]]
        A["walk", d] = w
        A["unload", d] = [align(w[0], conv(unload), "high", 4)]
        dd = [conv(s) for s in death]
        if d in ("s", "n"):
            burn = []
            wx0, wx1, wy0, wy1 = bbox(w[0])
            # where the flames go: the wagon box (its upper middle), not the horse
            tx = (wx0 + wx1) / 2.0 - w[0].ax
            ty = wy0 + (wy1 - wy0) * BURN_AT[d] - w[0].ay
            for k in (0, 1):
                fl = fire_layer(dd[k])
                cx, cy = mass_centre(fl.img, fire_px(fl.img))
                burn.append(lay(w[0], fl, dx=tx - (cx - fl.ax), dy=ty - (cy - fl.ay)))
            A["death", d] = burn + [dd[2], dd[3]]
        else:
            first = align(w[0], dd[0], "low", 4)
            A["death", d] = [first, align(first, dd[1], "low", 4), dd[2], dd[3]]
    return A, groups, bgc


BURN_AT = {"s": 0.38, "n": 0.42}   # flame centre: share of the wagon's height from the top


def finish_wagon(A):
    """idle: walk frame 0 and the same with the horse's head lowered a pixel."""
    heads = WAGON_HEADS
    for d in DIRS:
        w0 = A["walk", d][0]
        A["idle", d] = [w0.copy(), bob_rect(w0, heads[d], 1)]
    return A


# horse head boxes for the idle nod, relative to the anchor (x0, y0, x1, y1), game px
WAGON_HEADS = {
    "s": (-6, -4, 6, 6),
    "se": (2, -12, 14, 0),
    "e": (6, -12, 18, 0),
    "ne": (6, -12, 18, 0),
    "n": (-6, -4, 6, 6),
}


# ---------------------------------------------------------------- labourer with keg

LAB = "art/crown/labourer_keg.png"


def labourer_layout():
    """The labourer's cell and anchor as import_art.py wrote them, and his standing
    height (median over the walk_s frames), which the keg frames are scaled to."""
    src = open("scripts/art_data.gd").read()
    m = re.search(r'"labourer": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    cell = (int(m.group(1)), int(m.group(2)))
    anchor = (float(m.group(3)), float(m.group(4)))
    strip = np.array(Image.open("assets/units/labourer/walk_s.png").convert("RGBA"))
    hs = []
    for i in range(strip.shape[1] // cell[0]):
        a = strip[:, i * cell[0]:(i + 1) * cell[0], 3] > 0
        ys = np.flatnonzero(a.any(1))
        hs.append(ys.max() - ys.min() + 1)
    return cell, anchor, float(np.median(hs))


def height(f):
    ys = np.flatnonzero(body_of(f.img, f.glow).any(1))
    return ys.max() - ys.min() + 1


def plan_labourer():
    """Rows as drawn: 0 = S (front), 1 = SE, 2 = E (the most side-on), 3 and 4 = two more
    front three-quarter views (near-repeats of SE/E; row 3 is used for NE, row 4 not at
    all), 5 = N (the back: the keg on his back; walk frames only).
    carry_keg = walk with keg; idle_keg = the idle group (N: the walk's first frame and a
    breath, the top half settling a pixel). bury and death_keg are drawn as a kneeling /
    standing three-quarter view in every row: SE, E, NE use their own rows; S uses row 0
    and N row 4 as drawn. death_keg: the keg's fuse catches and he goes up - in S and N
    the first two frames are his own front / back pose (idle) with that row's flames laid
    over the keg, so he doesn't turn round before exploding; then the blast as drawn."""
    rows, bgc = cut_sheet(LAB)
    cell, anchor, target = labourer_layout()
    # first guess, then every row/group scaled so the S walk matches the old labourer
    k0 = 0.326
    probe = [frame_of(s, k0, bgc) for s in rows[0][:6]]
    scale = k0 * target / float(np.median([height(f) for f in probe]))
    if DEBUG:
        dump("labourer", rows, scale, bgc)

    def conv(s, k=scale):
        return keep_main(frame_of(s, k, bgc))
    groups = {}
    for r in range(5):
        fr = rows[r]
        groups[r] = dict(walk=fr[0:6], idle=fr[6:10], bury=fr[10:16], death=fr[16:22])
    groups[5] = dict(walk=rows[5][0:6])
    use = {"s": 0, "se": 1, "e": 2, "ne": 3, "n": 5}
    A = {}
    for d, r in use.items():
        walk = r4.steady([conv(s) for s in groups[r]["walk"]], "low")
        A["carry_keg", d] = walk
        if "idle" in groups[r]:
            A["idle_keg", d] = r4.steady([conv(s) for s in groups[r]["idle"]], "low")
        else:
            st = r4.narrowest(walk)
            A["idle_keg", d] = [st, r4.bob(st, 0.45, 1)]
        rb = r if r < 5 else 4
        bury = [conv(s) for s in groups[rb]["bury"]]
        A["bury", d] = bury_anchors(bury)
        death = [conv(s) for s in groups[rb]["death"]]
        death = [death[0], align(death[0], death[1], "low", 3)] + death[2:]
        if d in ("s", "n"):
            base = A["idle_keg", d][0]
            out = []
            for k in (0, 1):
                fl = fire_layer(death[k])
                if not fire_px(fl.img).any():
                    out.append(base.copy())
                    continue
                cx, cy = mass_centre(fl.img, fire_px(fl.img))
                # flames on the keg: the middle of the figure, at the height drawn
                bx0, bx1, by0, by1 = bbox(base)
                tx = (bx0 + bx1) / 2.0 - base.ax
                out.append(lay(base, fl, dx=tx - (cx - fl.ax), dy=cy - fl.ay))
            death = out + death[2:]
        A["death_keg", d] = death
    return A, cell, anchor, scale, rows, bgc


def bury_anchors(fr):
    """The kneeling frames: anchored at his knees (frame 0's foot point), every later frame
    lined up on frame 0 by the figure's upper body (the mound grows in front of him)."""
    out = [fr[0]]
    for f in fr[1:]:
        out.append(align(fr[0], f, "high", 4))
    return out


def fit_cell(A, cell, anchor):
    """The labourer's frames placed in his existing cell on his anchor; frames that would
    be clipped are reported."""
    W, H = cell
    ax, ay = anchor
    strips, clipped = {}, []
    for (anim, d), fr in A.items():
        cells = []
        for i, f in enumerate(fr):
            img, _ = place(f, W, H, ax, ay)
            lost = int((f.img[..., 3] > 0).sum() - (img[..., 3] > 0).sum())
            if lost > 0:
                clipped.append((anim, d, i, lost))
            cells.append(img)
        strips[f"{anim}_{d}"] = np.concatenate(cells, 1)
    return strips, clipped
