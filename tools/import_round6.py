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
        # the blast's smoke rises higher than the cell allows: the blast frames (2 on)
        # are drawn a little smaller, all by the same factor, so they fit
        fit = 1.0
        for f in death[2:]:
            x0, x1, y0, y1 = bbox(f)
            fit = min(fit, anchor[1] / (f.ay - y0), anchor[0] / max(f.ax - x0, 1e-6),
                      (cell[0] - anchor[0]) / max(x1 - f.ax, 1e-6))
        if fit < 1.0:
            fit *= 0.97
            death[2:] = [conv(s, scale * fit) for s in groups[rb]["death"][2:]]
            BLAST_FIT[d] = fit
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
                out.append(lay(base, fl, dx=tx - (cx - fl.ax), dy=0))
            death = out + death[2:]
        A["death_keg", d] = death
    return A, cell, anchor, scale, rows, bgc


BLAST_FIT = {}


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


# ---------------------------------------------------------------- keg mine effects

MINE_W = 32             # the mound: one tile wide
MOUND_HALF_H = 5        # its ground point: this far above its lowest pixel


def mound_width(f):
    """Width of the dirt mound: the widest of the drawing's lowest 30% rows."""
    a = f.img[..., 3] > 0
    ys = np.flatnonzero(a.any(1))
    y0 = ys.max() - int((ys.max() - ys.min()) * 0.3)
    w = 0
    for y in range(y0, ys.max() + 1):
        xs = np.flatnonzero(a[y])
        if len(xs):
            w = max(w, xs[-1] - xs[0] + 1)
    return w


def ground_point(f):
    """The mound's (or blast's) middle on the ground: the centre of the lowest 30% rows,
    MOUND_HALF_H above the bottom."""
    a = f.img[..., 3] > 0
    ys, xs = np.nonzero(a)
    low = ys >= ys.max() - (ys.max() - ys.min()) * 0.3
    return (xs[low].min() + xs[low].max() + 1) / 2.0, ys.max() + 1 - MOUND_HALF_H


def centred_strip(frames, pad=1):
    """Frames on one cell, every frame's anchor in the cell's centre."""
    L = max(max(f.ax, f.img.shape[1] - f.ax) for f in frames)
    U = max(max(f.ay, f.img.shape[0] - f.ay) for f in frames)
    W, H = 2 * (int(np.ceil(L)) + pad), 2 * (int(np.ceil(U)) + pad)
    cells = [place(f, W, H, W / 2.0, H / 2.0)[0] for f in frames]
    return np.concatenate(cells, 1), W, H


def build_mine(rows, bgc):
    """rows[6]: the buried keg, fuse smouldering (5 frames, a loop); rows[7]: armed - the
    fuse burns down (3) - then the blast (6, the last one the scorched crater). The mound
    is scaled to one tile; idle and arm use their own row's mound width, the blast the
    arm row's scale. Every frame is placed with the mound's middle on the ground at the
    middle of its cell, so the three strips swap without a jump."""
    idle_src, arm_src = rows[6], rows[7][:3]
    blast_src = rows[7][3:]
    probe = 0.4

    def k_of(srcs):
        ws = [mound_width(frame_of(s, probe, bgc)) for s in srcs]
        return probe * MINE_W / float(np.median(ws))
    k_idle, k_arm = k_of(idle_src), k_of(arm_src)
    out = {}
    for name, srcs, k in (("keg_mine", idle_src, k_idle), ("keg_mine_arm", arm_src, k_arm),
                          ("keg_mine_blast", blast_src, k_arm)):
        frames = []
        for s in srcs:
            f = keep_main(frame_of(s, k, bgc), 4)
            f = anchored_at(f, *ground_point(f))
            frames.append(f)
        if name != "keg_mine_blast":
            frames = [frames[0]] + [align(frames[0], f, "low", 2) for f in frames[1:]]
        strip, W, H = centred_strip(frames)
        Image.fromarray(strip, "RGBA").save(f"assets/effects/{name}.png")
        out[name] = (len(frames), W, H)
        print(f"{name}: {len(frames)} frames {W}x{H}")
    return out


# ---------------------------------------------------------------- UI pieces

UI = "art/ui/keg_cross_numbers.png"
KEG_BODY_H = 12          # a standing keg's height before its 1 px outline (=> 14 px)
OUTLINE = (24, 16, 12, 255)


def outlined(img, colour=OUTLINE):
    """A 1 px dark outline around the silhouette (outside it): at this size the sheet's
    own black outline is averaged away."""
    a = img[..., 3] > 0
    h, w = a.shape
    out = np.zeros((h + 2, w + 2, 4), np.uint8)
    out[1:-1, 1:-1] = img
    big = np.zeros((h + 2, w + 2), bool)
    big[1:-1, 1:-1] = a
    ring = ndimage.binary_dilation(big, structure=np.ones((3, 3))) & ~big
    out[ring] = colour
    return out


def crisp(img, levels=None):
    """Hard alpha and a little extra contrast, so the shrunken picture reads as pixel art
    instead of a blur."""
    out = img.copy()
    a = out[..., 3] > 0
    rgb = out[..., :3].astype(float)
    mean = rgb[a].mean(0)
    rgb = np.clip((rgb - mean) * 1.18 + mean * 1.12, 0, 255)
    out[..., :3] = np.where(a[..., None], rgb.round(), 0).astype(np.uint8)
    out[..., 3] = np.where(a, 255, 0)
    return out


def build_kegs(rows, bgc):
    """The 7 kegs (standing x3, lying x2, broken, burning) at one scale - a standing keg
    KEG_BODY_H px tall plus the outline - bottom-aligned and centred in one cell each."""
    kegs = rows[0]
    h0 = kegs[0]["img"].shape[0]
    k = KEG_BODY_H / float(h0)
    frames = []
    for s in kegs:
        img = to_game(s["img"], k, bgc)
        img = clean(img, min_size=2, keep_near=1)
        ys, xs = np.nonzero(img[..., 3] > 0)
        img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        frames.append(outlined(crisp(img)))
    W = max(f.shape[1] for f in frames)
    H = max(f.shape[0] for f in frames)
    cells = []
    for f in frames:
        c = np.zeros((H, W, 4), np.uint8)
        h, w = f.shape[:2]
        x0 = (W - w) // 2
        c[H - h:, x0:x0 + w] = f
        cells.append(c)
    Image.fromarray(np.concatenate(cells, 1), "RGBA").save("assets/effects/keg.png")
    print(f"keg: {len(cells)} frames {W}x{H}")
    return {"keg": (len(cells), W, H)}


def off_key(c, margin=0.12):
    """A colour moved away from both team key colours (the shader swaps anything within
    0.08 of them), keeping its hue: the green/blue channels are raised a little."""
    c = np.array(c, float)
    for key in (TEAM_LIGHT, TEAM_DARK):
        while np.linalg.norm((c - np.array(key, float)) / 255.0) < margin:
            c[1] += 3
            c[2] += 3
    return tuple(int(round(v)) for v in c)


def ui_colours(src):
    """Red fill (light and dark) and gold rim colours sampled from a sheet drawing."""
    img = src["img"].astype(int)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    on = img[..., 3] > 0
    red = on & (r >= 140) & (g <= 0.35 * r) & (b <= 0.35 * r)
    gold = on & (r >= 170) & (g >= 0.55 * r) & (b <= 0.5 * g)
    ys = np.nonzero(red)[0]
    mid = np.median(ys)
    hi = img[red & (np.arange(img.shape[0])[:, None] < mid)][:, :3].mean(0)
    lo = img[red & (np.arange(img.shape[0])[:, None] >= mid)][:, :3].mean(0)
    gd = img[gold][:, :3].mean(0)
    return off_key(hi), off_key(lo), tuple(int(v) for v in gd)


# The digits drawn by hand as a bold 5x7 pixel font in the sheet's style (thick upright
# strokes, flat-topped 1, 4 and 7): shrunk from the sheet they come out as unreadable
# smudges at 7 px. Colours are the sheet's.
DIGITS = [
    [".###.", "##.##", "##.##", "##.##", "##.##", "##.##", ".###."],
    [".##..", "###..", ".##..", ".##..", ".##..", ".##..", "####."],
    [".###.", "##.##", "...##", "..##.", ".##..", "##...", "#####"],
    ["####.", "...##", "...##", ".###.", "...##", "...##", "####."],
    ["##.##", "##.##", "##.##", "#####", "...##", "...##", "...##"],
    ["#####", "##...", "####.", "...##", "...##", "##.##", ".###."],
    [".###.", "##...", "##...", "####.", "##.##", "##.##", ".###."],
    ["#####", "...##", "..##.", "..##.", ".##..", ".##..", ".##.."],
    [".###.", "##.##", "##.##", ".###.", "##.##", "##.##", ".###."],
    [".###.", "##.##", "##.##", ".####", "...##", "...##", ".###."],
]


def glyph_image(mask, hi, lo, gold, split):
    """Red glyph (rows above split light, below dark) with a 1 px gold rim around it."""
    h, w = mask.shape
    out = np.zeros((h + 2, w + 2, 4), np.uint8)
    m = np.zeros((h + 2, w + 2), bool)
    m[1:-1, 1:-1] = mask
    rim = ndimage.binary_dilation(m, structure=np.ones((3, 3))) & ~m
    out[rim] = gold + (255,)
    yy = np.arange(h + 2)[:, None].repeat(w + 2, 1)
    out[m & (yy <= split)] = hi + (255,)
    out[m & (yy > split)] = lo + (255,)
    return out


def build_digits(rows):
    hi, lo, gold = ui_colours(rows[2][0])
    frames = []
    for g in DIGITS:
        mask = np.array([[ch == "#" for ch in line] for line in g])
        frames.append(glyph_image(mask, hi, lo, gold, 3))
    W, H = frames[0].shape[1], frames[0].shape[0]
    Image.fromarray(np.concatenate(frames, 1), "RGBA").save("assets/effects/digits.png")
    print(f"digits: 10 frames {W}x{H}")
    return {"digits": (10, W, H)}


def build_cross(rows):
    """The cross's shape from the sheet (arm thickness relative to its span) on a 10 px
    square, then the gold rim: 12x12. Red shifted off the team key."""
    src = rows[1][0]
    hi, lo, gold = ui_colours(src)
    sil = src["img"][..., 3] > 0
    ys, xs = np.nonzero(sil)
    span = xs.max() - xs.min() + 1
    # the vertical bar's width a quarter of the way down (rim and outline included on
    # both sides, as in the full span)
    thick = np.flatnonzero(sil[ys.min() + span // 4]).size
    n = 10
    t = int(round(thick / float(span) * (n + 2))) - 2
    t = t + (n - t) % 2                       # centred: same parity as the square
    a = (n - t) // 2
    mask = np.zeros((n, n), bool)
    mask[a:a + t, :] = True
    mask[:, a:a + t] = True
    out = glyph_image(mask, hi, lo, gold, a + t // 2)
    Image.fromarray(out, "RGBA").save("assets/effects/cross.png")
    print(f"cross: 1 frame {out.shape[1]}x{out.shape[0]} (arm {t} px of {n})")
    return {"cross": (1, out.shape[1], out.shape[0])}


def build_ui():
    rows, bgc = cut_sheet(UI)
    fx = {}
    fx.update(build_kegs(rows, bgc))
    fx.update(build_cross(rows))
    fx.update(build_digits(rows))
    return fx


# ---------------------------------------------------------------- output

def write_strips(kind, strips, owned=None):
    """Strips to assets/units/<kind>/. owned: the names this script owns in a folder it
    shares (the labourer's): only those are replaced; stale ones of them removed."""
    out = f"assets/units/{kind}"
    os.makedirs(out, exist_ok=True)
    if owned is None:
        for f in os.listdir(out):
            if f.endswith(".png") and f[:-4] not in strips:
                os.remove(os.path.join(out, f))
                if os.path.exists(os.path.join(out, f + ".import")):
                    os.remove(os.path.join(out, f + ".import"))
    for key, strip in sorted(strips.items()):
        Image.fromarray(strip, "RGBA").save(f"{out}/{key}.png")


def write_labourer_frames(counts):
    """The new keys added to (or updated in) the labourer entry's "frames" - nothing else
    in the entry or the file changes."""
    path = "scripts/art_data.gd"
    src = open(path).read()
    start = src.index('\t"labourer": {"cell"')
    end = src.index("\n\t}},\n", start) + 1
    block = src[start:end]
    for key in sorted(counts):
        line = f'\t\t"{key}": {counts[key]},\n'
        pat = re.compile(r'\t\t"' + key + r'": \d+,\n')
        if pat.search(block):
            block = pat.sub(lambda m: line, block, count=1)
        else:
            block = block + line
    open(path, "w").write(src[:start] + block + src[end:])


def wagon_icon(groups, bgc):
    """The wagon in three-quarter view (row 1, walk frame 0), rendered from the source."""
    src = groups[1][0][0]["img"]
    img = to_game(src, 54.0 / max(src.shape[:2]), bgc)
    make_icon(img, "powder_wagon")
    path = "assets/icons/powder_wagon.png"
    a = np.array(Image.open(path).convert("RGBA")).astype(float)
    al = a[..., 3:4] / 255.0
    a[..., :3] = a[..., :3] * al + np.array([28, 30, 30], float) * (1 - al)
    a[..., 3] = 255
    Image.fromarray(a.round().astype(np.uint8), "RGBA").save(path)


def strip_frames(strip, w, n):
    return [strip[:, i * w:(i + 1) * w].copy() for i in range(n)]


def marked(fr, anchor):
    fr = fr.copy()
    ax, ay = int(anchor[0]), int(anchor[1])
    fr[ay, max(0, ax - 2):ax + 3] = (255, 255, 255, 110)
    fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
    fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
    return fr


def contacts(wagon, lab, fx):
    cell, anchor, counts = wagon
    ref = []
    for rk, rn in (("cannon", "walk_e"), ("cannon", "walk_s")):
        a = np.array(Image.open(f"assets/units/{rk}/{rn}.png").convert("RGBA"))
        ref.append(a[:, :152])
    lines = [("cannon e / s", ref)]
    for an in ("walk", "idle", "unload", "death"):
        for d in DIRS:
            key = f"{an}_{d}"
            s = np.array(Image.open(f"assets/units/powder_wagon/{key}.png").convert("RGBA"))
            lines.append((key, [marked(f, anchor) for f in strip_frames(s, cell[0], counts[key])]))
    lines.append(("icon", [np.array(Image.open("assets/icons/powder_wagon.png").convert("RGBA")),
                           np.array(Image.open("assets/icons/cannon.png").convert("RGBA"))]))
    contact_sheet(os.path.join(CONTACT, "contact_powder_wagon.png"), lines)

    lcell, lanchor, lcounts = lab
    lines = []
    for rn in ("walk_s", "carry_e"):
        s = np.array(Image.open(f"assets/units/labourer/{rn}.png").convert("RGBA"))
        lines.append(("old " + rn, strip_frames(s, lcell[0], s.shape[1] // lcell[0])))
    for an in ("carry_keg", "idle_keg", "bury", "death_keg"):
        for d in DIRS:
            key = f"{an}_{d}"
            s = np.array(Image.open(f"assets/units/labourer/{key}.png").convert("RGBA"))
            lines.append((key, [marked(f, lanchor) for f in strip_frames(s, lcell[0], lcounts[key])]))
    contact_sheet(os.path.join(CONTACT, "contact_labourer_keg.png"), lines)

    lines = []
    for name, (n, w, h) in fx.items():
        s = np.array(Image.open(f"assets/effects/{name}.png").convert("RGBA"))
        fr = strip_frames(s, w, n)
        if name.startswith("keg_mine"):
            fr = [marked(f, (w // 2, h // 2)) for f in fr]
        lines.append((name, fr))
    contact_sheet(os.path.join(CONTACT, "contact_keg_effects.png"), lines)


def main():
    if DEBUG:
        os.makedirs(DEBUG, exist_ok=True)
    # powder wagon
    A, groups, bgc = plan_wagon()
    A = finish_wagon(A)
    A = {k: [trim(f) for f in fr] for k, fr in A.items()}
    strips, cell, anchor = assemble(A)
    write_strips("powder_wagon", strips)
    counts = {k: s.shape[1] // cell[0] for k, s in strips.items()}
    write_units_data({"powder_wagon": (cell, anchor, counts)})
    wagon_icon(groups, bgc)
    print(f"powder_wagon: cell {cell[0]}x{cell[1]}, anchor {anchor}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    # labourer with keg
    L, lcell, lanchor, lscale, lrows, lbgc = plan_labourer()
    lstrips, clipped = fit_cell(L, lcell, lanchor)
    if clipped:
        print("WARNING: labourer frames clipped by the cell:", clipped)
    write_strips("labourer", lstrips, owned=True)
    lcounts = {k: s.shape[1] // lcell[0] for k, s in lstrips.items()}
    write_labourer_frames(lcounts)
    print(f"labourer (keg): cell {lcell}, anchor {lanchor}, scale {lscale:.3f}, "
          f"blast frames shrunk {', '.join(f'{d} x{k:.2f}' for d, k in BLAST_FIT.items()) or 'none'}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(lcounts.items())))
    # effects
    os.makedirs("assets/effects", exist_ok=True)
    fx = build_mine(lrows, lbgc)
    fx.update(build_ui())
    write_effects_data(fx)
    if CONTACT:
        os.makedirs(CONTACT, exist_ok=True)
        contacts((cell, anchor, counts), (lcell, lanchor, lcounts), fx)


if __name__ == "__main__":
    main()
