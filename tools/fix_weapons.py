"""Repairs the weapons in the Crown infantry sprites (run after tools/import_art.py).

The generated art drew the pikeman's pike kinked at the butt and the musketeer's musket
at a different size in almost every frame. This finds the weapon (the thin parts that
stick out of the body), removes it, and paints a clean, straight weapon of one fixed
length, pixel by pixel, in the sprites' palette.

    python3 tools/fix_weapons.py [--only kind,kind]

Kinds: pikeman, musketeer and musketeer_armoured (the round 10 musketeers, both drawn
on the old musketeer's 90 px cell; tools/import_round10.py must run first). --only
repairs just those kinds (each kind must be repaired exactly once after its import).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SHAFT = [(40, 24, 14), (122, 74, 36)]             # outline, wood
STEEL = [(60, 60, 66), (150, 150, 160), (215, 215, 225)]
BARREL = [(34, 34, 40), (92, 92, 104), (140, 140, 152)]
STOCK = [(46, 26, 12), (110, 64, 30), (146, 92, 46)]


def frames(kind, anim, cw):
    path = f"assets/units/{kind}/{anim}.png"
    a = np.array(Image.open(path).convert("RGBA"))
    return path, a, [a[:, i * cw:(i + 1) * cw] for i in range(a.shape[1] // cw)]


def body_mask(f):
    op = f[..., 3] > 40
    core = ndi.binary_opening(op, structure=np.ones((3, 3)))
    lab, n = ndi.label(core)
    if n == 0:
        return core
    sizes = ndi.sum(core, lab, range(1, n + 1))
    big = lab == (np.argmax(sizes) + 1)
    return ndi.binary_dilation(big, iterations=1) & op


def is_skin(px):
    r, g, b, a = [int(v) for v in px]
    return a > 40 and r > 140 and 80 < g < 190 and b < 120 and 25 < r - g < 110


def paint(f, p, col, keep):
    """Paint one pixel unless it belongs to `keep` (head, gripping hand)."""
    x, y = int(round(p[0])), int(round(p[1]))
    if 0 <= x < f.shape[1] and 0 <= y < f.shape[0] and not keep(x, y):
        f[y, x] = (*col, 255)


def stroke(f, a, d, length, colour_at, keep):
    """A 2-pixel weapon from `a` along unit vector `d`; colour_at(t) -> (main, edge)."""
    nrm = np.array([-d[1], d[0]])
    if nrm[1] < 0 or (nrm[1] == 0 and nrm[0] < 0):
        nrm = -nrm
    for i in range(int(length * 2) + 1):
        t = i / 2.0
        p = a + d * t
        main, edge = colour_at(t)
        paint(f, p, main, keep)
        paint(f, p + nrm, edge, keep)


def outside_parts(f):
    op = f[..., 3] > 40
    w = op & ~body_mask(f)
    lab, n = ndi.label(w, structure=np.ones((3, 3)))
    return w, lab, n


def figure(f):
    """Body mask, its box, and a keep-test that protects the head and the hands."""
    b = body_mask(f)
    ys, xs = np.where(b)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    head_bottom = y0 + (y1 - y0) * 0.27
    return b, x0, x1, y0, y1, head_bottom


def hand_near(f, b, target, y_lo, y_hi):
    """The skin pixel of the body nearest `target` between two heights (None if none)."""
    best, bd = None, 1e9
    for y in range(int(y_lo), int(y_hi) + 1):
        for x in range(f.shape[1]):
            if b[y, x] and is_skin(f[y, x]):
                dd = (x - target[0]) ** 2 + (y - target[1]) ** 2
                if dd < bd:
                    bd, best = dd, np.array([x, y], float)
    return best


def keeper(f, b, head_bottom, hand, behind=False):
    """Pixels the weapon must not cover: the head, the gripping hand, and (for a weapon
    carried behind) the whole body."""
    grip = set()
    if hand is not None:
        for y in range(int(hand[1]) - 2, int(hand[1]) + 3):
            for x in range(int(hand[0]) - 2, int(hand[0]) + 3):
                if 0 <= y < f.shape[0] and 0 <= x < f.shape[1] and is_skin(f[y, x]):
                    grip.add((x, y))
    def keep(x, y):
        if (x, y) in grip:
            return True
        if b[y, x] and (behind or y < head_bottom):
            return True
        return False
    return keep


# ------------------------------------------------------------------ pikeman

PIKE = 44.0


def pike_colour(t):
    if t < 2:
        return STEEL[2], STEEL[0]
    if t < 5:
        return STEEL[1], STEEL[0]
    return SHAFT[1], SHAFT[0]


def pike_line(f):
    """(tip, direction) of the pike as drawn, or None when this frame's pike is a mess
    (missing, or not pointing up over the shoulder)."""
    w, lab, n = outside_parts(f)
    if n == 0:
        return None
    sizes = ndi.sum(w, lab, range(1, n + 1))
    if sizes.max() < 15:
        return None
    main = lab == (int(np.argmax(sizes)) + 1)
    ys, xs = np.where(main)
    pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0)
    d = np.linalg.svd(pts - c)[2][0]
    proj = (pts - c) @ d
    tip, end = c + d * proj.min(), c + d * proj.max()
    if tip[1] > end[1]:
        tip, end = end, tip
    b, x0, x1, y0, y1, head_bottom = figure(f)
    if tip[1] > y0 - 4 or abs((end - tip)[1]) < 4:
        return None
    return tip, (end - tip) / np.linalg.norm(end - tip)


def fix_pike(f, ref=None):
    """`ref` = (tip relative to the body's top-right corner, direction) from a good frame
    of the same animation, used when this frame's own pike is a mess."""
    w, lab, n = outside_parts(f)
    if n == 0:
        return
    sizes = ndi.sum(w, lab, range(1, n + 1))
    if pike_line(f) is None:
        if ref is None:
            return
        b, x0, x1, y0, y1, head_bottom = figure(f)
        for k in range(1, n + 1):
            if sizes[k - 1] > 6 and np.argwhere(lab == k)[:, 0].min() > head_bottom - 2 - 20 * (sizes[k - 1] > 25):
                f[lab == k] = 0
        tip = np.array([x1, y0], float) + ref[0]
        stroke(f, tip, ref[1], PIKE, pike_colour, keeper(f, b, head_bottom, None, behind=True))
        return
    mk = int(np.argmax(sizes)) + 1
    main = lab == mk
    ys, xs = np.where(main)
    pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0)
    d = np.linalg.svd(pts - c)[2][0]
    b, x0, x1, y0, y1, head_bottom = figure(f)
    body_c = np.array([(x0 + x1) / 2, (y0 + y1) / 2])
    proj = (pts - c) @ d
    tip, end = c + d * proj.min(), c + d * proj.max()
    # a shouldered pike points up: the tip is the higher end
    if tip[1] > end[1]:
        tip, end = end, tip
    d = (end - tip) / np.linalg.norm(end - tip)
    # any other long piece of pike (some frames have two) goes too
    for k in range(1, n + 1):
        if k != mk and sizes[k - 1] > 40:
            f[lab == k] = 0
    # the crooked butt sticks out where the hand is: find that hand
    kink = None
    kd = 1e9
    probe = end + d * 10.0
    for k in range(1, n + 1):
        comp = lab == k
        if k == mk:
            continue
        cy, cx = np.argwhere(comp).mean(0)
        q = np.array([cx, cy]) - tip
        if sizes[k - 1] <= 40 and abs(q[0] * d[1] - q[1] * d[0]) > 2.5:
            if np.argwhere(comp)[:, 0].min() <= head_bottom:
                continue      # part of the helmet, not the pike
            f[comp] = 0
            # the butt end is the stray bit in the upper body nearest where the line led
            dd = np.linalg.norm(np.array([cx, cy]) - probe)
            if cy < y0 + (y1 - y0) * 0.6 and dd < kd and dd < 16.0:
                kd, kink = dd, np.array([cx, cy])
    f[main] = 0
    hand = None
    if kink is not None:
        hand = hand_near(f, b, kink, head_bottom, y0 + (y1 - y0) * 0.6)
    if hand is None:
        # no grip found: keep the old line, passing behind the soldier
        keep = keeper(f, b, head_bottom, None, behind=True)
        stroke(f, tip, d, PIKE, pike_colour, keep)
        return
    # one straight pike from the tip through the gripping hand, 3 px past it; if that
    # would swing the pike far from how it was drawn, the "hand" was a mistake
    nd = (hand - tip) / np.linalg.norm(hand - tip)
    if float(nd @ d) < np.cos(np.radians(14)):
        stroke(f, tip, d, PIKE, pike_colour, keeper(f, b, head_bottom, None, behind=True))
        return
    start = hand + nd * 3 - nd * PIKE
    stroke(f, start, nd, PIKE, pike_colour, keeper(f, b, head_bottom, hand))


# ------------------------------------------------------------------ musketeer

MUSKET = 27.0
_ORIG = {}


def musket_colour_up(t):
    # drawn from the muzzle (t=0) down to the butt (t=MUSKET)
    if t < 1.5:
        return BARREL[2], BARREL[0]
    if t < MUSKET - 10:
        return BARREL[1], BARREL[0]
    if t < MUSKET - 2:
        return STOCK[1], STOCK[0]
    return STOCK[2], STOCK[0]


def clear_stray(f):
    """Remove the scraps of the old musket that stick out of the body (never anything on
    the head: thin bits of helmet brim also stick out)."""
    w, lab, n = outside_parts(f)
    b, x0, x1, y0, y1, head_bottom = figure(f)
    for k in range(1, n + 1):
        comp = lab == k
        pts = np.argwhere(comp)
        size = len(pts)
        length = float(np.hypot(*(pts.max(0) - pts.min(0))))
        # a long thin piece is a musket even where it reaches past the head (the round
        # 10 musketeers hold theirs up at the port); short bits by the head are brims
        dy, dx = pts.max(0) - pts.min(0)
        if (size <= 60 and pts[:, 0].min() > head_bottom) or (length >= 12 and size <= 3.2 * length) \
                or (length >= 5 and size <= 3.0 * length and dy >= 0.8 * dx):
            f[comp] = 0


def musket(f, butt, d_up, keep):
    """A musket whose butt is at `butt`, pointing along d_up."""
    muzzle = butt + d_up * MUSKET
    stroke(f, muzzle, -d_up, MUSKET, musket_colour_up, keep)


def held_line(src):
    """(muzzle, direction toward the muzzle) of the musket as this frame holds it, or None."""
    b = body_mask(src)
    w = (src[..., 3] > 40) & ~b
    lab, n = ndi.label(w, structure=np.ones((3, 3)))
    if n == 0:
        return None
    sizes = ndi.sum(w, lab, range(1, n + 1))
    if sizes.max() < 5:
        return None
    main = lab == (int(np.argmax(sizes)) + 1)
    ys, xs = np.where(main)
    pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0)
    d = np.linalg.svd(pts - c)[2][0]
    if abs(d[1]) > 0.5:
        if d[1] > 0:
            d = -d        # sloped: the muzzle is the upper end
    elif (c[0] - np.where(b)[1].mean()) * d[0] < 0:
        d = -d            # level: the muzzle points away from the body
    return c + d * ((pts - c) @ d).max(), d


def held(f, b, head_bottom, muzzle, d):
    """Standing side views: the musket kept in the pose it was drawn in, at full length."""
    entry = muzzle - d * 8
    hand = hand_near(f, b, entry, head_bottom, f.shape[0] - 1)
    stroke(f, muzzle, -d, MUSKET, musket_colour_up, keeper(f, b, head_bottom, hand))


def fix_musket(f, anim, ref=None):
    clear_stray(f)
    b, x0, x1, y0, y1, head_bottom = figure(f)
    h = y1 - y0
    side = anim.split("_")[1]
    if anim.startswith("walk") and side in ("e", "se", "ne"):
        # at the port: gripped at the front hip, muzzle forward and up
        hand = hand_near(f, b, np.array([x1, y0 + h * 0.55]), y0 + h * 0.35, y0 + h * 0.7)
        if hand is None:
            hand = np.array([x1 - 1, y0 + h * 0.55])
        ang = np.radians(-66 if side == "ne" else -58)
        d = np.array([np.cos(ang), np.sin(ang)])
        musket(f, hand - d * 7, d, keeper(f, b, head_bottom, hand))
    elif side in ("s", "n"):
        # shouldered: butt in the hand at the hip, barrel up against the shoulder
        # (right side seen from the front, left side seen from behind)
        front = side == "s"
        ref = np.array([x1 if front else x0, y0 + h * 0.55])
        hand = hand_near(f, b, ref, y0 + h * 0.4, y0 + h * 0.75)
        if hand is None:
            hand = np.array([x1 - 2 if front else x0 + 2, y0 + h * 0.55])
        shoulder_x = (x1 - 3) if front else (x0 + 3)
        butt = np.array([hand[0], hand[1] + 3])
        top = np.array([shoulder_x + (2 if front else -2), butt[1] - MUSKET])
        d = (top - butt) / np.linalg.norm(top - butt)
        musket(f, butt, d, keeper(f, b, head_bottom, hand))
    elif ref is not None:
        # one pose for the whole animation, so the musket doesn't jump between frames
        held(f, b, head_bottom, np.array([x1, y0], float) + ref[0], ref[1])
    else:
        # standing at order arms: butt on the ground by the front foot, held at the hip
        hand = hand_near(f, b, np.array([x1, y0 + h * 0.55]), y0 + h * 0.35, y0 + h * 0.75)
        if hand is None:
            hand = np.array([x1 - 1, y0 + h * 0.55])
        butt = np.array([hand[0] + 1, y1])
        d = np.array([-0.04, -1.0])
        d /= np.linalg.norm(d)
        musket(f, butt, d, keeper(f, b, head_bottom, hand))


MUSKETEERS = ["musketeer", "musketeer_armoured"]


def main():
    kinds = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else ["pikeman"] + MUSKETEERS
    if "pikeman" in kinds:
        fix_pikeman()
    for kind in MUSKETEERS:
        if kind in kinds and os.path.isdir(f"assets/units/{kind}"):
            fix_musketeer(kind)
    print("weapons repaired:", ", ".join(kinds))


def fix_pikeman():
    for anim in ["walk_e", "walk_se", "walk_ne", "walk_s", "walk_n"]:
        path, a, fs = frames("pikeman", anim, 68)
        ref = None
        for f in fs:
            pl = pike_line(f)
            if pl is not None:
                b, x0, x1, y0, y1, hb = figure(f)
                ref = (pl[0] - np.array([x1, y0], float), pl[1])
                break
        for f in fs:
            fix_pike(f, ref)
        Image.fromarray(a).save(path)


def fix_musketeer(kind):
    for anim in ["walk_e", "walk_se", "walk_ne", "walk_s", "walk_n", "idle_e", "idle_se", "idle_ne", "idle_s", "idle_n"]:
        path, a, fs = frames(kind, anim, 90)
        ref = None
        # standing: keep the pose of the frame that drew the musket most fully
        # (south-east is drawn muzzle-down, so that one stands at order arms instead)
        if anim in ("idle_e", "idle_ne"):
            best = 0
            for f in fs:
                hl = held_line(f)
                size = int(((f[..., 3] > 40) & ~body_mask(f)).sum())
                if hl is not None and size > best:
                    b, x0, x1, y0, y1, hb = figure(f)
                    best, ref = size, (hl[0] - np.array([x1, y0], float), hl[1])
        for f in fs:
            _ORIG["f"] = f.copy()
            fix_musket(f, anim, ref)
        Image.fromarray(a).save(path)


if __name__ == "__main__":
    main()
