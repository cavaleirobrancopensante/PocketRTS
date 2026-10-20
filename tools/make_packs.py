"""Battery backpacks for the Clockwork constructs.

Every construct carries its charge in a brass-and-glass cell strapped to its back: the
glass shows a glowing yellow fluid (and the hot coil inside it) as high as the charge,
and a lamp on the top terminal is lit while there is any charge at all.

Output:
  assets/effects/pack_<type>.png   one row per view (s, se, e, ne, n), one column per
                                   charge level 0..13 (0 = empty glass, lamp out)
  the PACKS table at the end of scripts/art_data.gd (replaced in place, or appended):
  for each construct its pack type and, for every animation strip it has, which view of
  the pack to show, whether it hangs in front of or behind the body, and where its centre
  sits (game px from the unit's feet, unflipped art) in every frame of the strip - so it
  stays on the back through every step, swing and recoil.

The positions are found by following the body from frame to frame: for each construct
and direction a hand-placed point on a reference frame, and a patch of the torso around
it that is tracked (best match of the patch, alpha and colour) through every frame of
every strip drawn in that direction. HAND overrides fix single frames where the art
changes too much to track.

Usage (from the repo root): python3 tools/make_packs.py [--preview DIR]
--preview writes contact sheets of every strip with the pack composited on (x3).
Needs Pillow and NumPy.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

VIEWS = ["s", "se", "e", "ne", "n"]
LEVELS = 14

# ---------------------------------------------------------------- palette
OUT = (30, 22, 16)
OUT2 = (52, 38, 24)
BR = [(58, 40, 18), (96, 66, 24), (138, 96, 34), (180, 134, 56), (214, 178, 104), (238, 216, 150)]
ST = [(40, 42, 48), (74, 78, 86), (116, 120, 128), (168, 172, 178)]
GL = [(20, 24, 32), (32, 40, 52), (52, 64, 80), (88, 106, 122), (150, 170, 182)]
FL = [(150, 86, 4), (200, 136, 8), (232, 186, 26), (248, 218, 70), (253, 240, 140), (255, 251, 210)]
LE = [(36, 24, 14), (66, 44, 24), (98, 66, 36), (128, 90, 50)]


def shade(pal, u, hi=0.32):
    """Colour across a cylinder (u: 0 = left edge, 1 = right edge), lit from the upper
    left: highlight near u = hi, darkest at the right edge."""
    n = len(pal)
    if u <= hi:
        t = 0.55 + 0.45 * (u / hi)
    else:
        t = 1.0 - (u - hi) / (1.0 - hi) * 0.95
    return pal[max(0, min(n - 1, int(round(t * (n - 1)))))]


class Canvas:
    def __init__(self, w, h):
        self.a = np.zeros((h, w, 4), np.uint8)
        self.w, self.h = w, h

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.a[y, x, :3] = c
            self.a[y, x, 3] = 255

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h and self.a[y, x, 3]:
            return tuple(int(v) for v in self.a[y, x, :3])
        return None


# ---------------------------------------------------------------- the upright cell

def upright(cv, x0, y0, w, h, level, view, big=False):
    """A standing cell: terminal + lamp, top cap, glass (fluid, coil), bottom cap.
    (x0, y0) is the top-left of the body (caps and glass), w x h its size; the terminal
    stands above y0. view decides the shading tilt and which rim shows."""
    hi = {"n": 0.32, "ne": 0.26, "e": 0.36, "se": 0.36, "s": 0.32}[view]
    cap = 3 if big else 2
    gauge = [y0 + 2] if not big else [y0 + 2, y0 + 3]   # the sight slot in the top cap
    glass_top = gauge[-1] + 2
    glass_bot = y0 + h - cap - 2           # inclusive
    gh = glass_bot - glass_top + 1
    lit = level > 0
    f = level / (LEVELS - 1)
    fill = int(round(f * gh)) if level < LEVELS - 1 else gh
    if lit:
        fill = max(fill, 1)
    surface = glass_bot - fill + 1         # first fluid row
    # terminal (a stud with a lamp; the big cell has two studs)
    studs = [x0 + w // 2] if not big else [x0 + w // 2 - 3, x0 + w // 2 + 3]
    for k, sx in enumerate(studs):
        lamp = (FL[5] if level >= 10 else FL[4] if level >= 4 else FL[3]) if lit else ST[1]
        cv.px(sx - 1, y0 - 1, OUT)
        cv.px(sx, y0 - 1, ST[2] if not big or k == 0 else ST[1])
        cv.px(sx + 1, y0 - 1, OUT)
        cv.px(sx, y0 - 2, lamp if (k == 0) else ST[2])
        cv.px(sx - 1, y0 - 2, OUT)
        cv.px(sx + 1, y0 - 2, OUT)
        cv.px(sx, y0 - 3, OUT)
        if lit and k == 0 and level >= 7:
            cv.px(sx, y0 - 3, FL[2])        # the lamp's glow spilling up
    for x in range(x0, x0 + w):
        u = (x - x0 + 0.5) / w
        edge = x in (x0, x0 + w - 1)
        # outline top and bottom
        cv.px(x, y0, OUT)
        cv.px(x, y0 + h - 1, OUT)
        for y in range(y0 + 1, y0 + h - 1):
            if edge:
                cv.px(x, y, OUT)
                continue
            if y < glass_top or y > glass_bot:
                # brass caps: the top cap's first row catches the light
                c = shade(BR, u, hi)
                if y == y0 + 1:
                    c = shade(BR[1:], u, hi)
                if y == glass_top - 1 or y == glass_bot + 1:
                    c = shade(BR[:-1], u, hi)
                    c = tuple(int(v * 0.72) for v in c)   # the rim's shadow line
                if y == y0 + h - 2:
                    c = shade(BR[:4], u, hi)
                cv.px(x, y, c)
                continue
            # glass
            if y >= surface and lit:
                deep = (y - surface) / max(1, glass_bot - surface)
                c = shade(FL[1:5] if deep < 0.45 else FL[:4], u, hi)
                if y == surface:
                    c = shade(FL[2:], u, hi)         # bright meniscus
            else:
                c = shade(GL[:4], u, hi)
                if y == glass_top:
                    c = shade(GL[1:], u, hi)
            cv.px(x, y, c)
    # glass glint: a vertical streak left of centre (only on the empty part it reads
    # as glass; on the fluid it's the hot highlight)
    gx = x0 + max(1, int(round(w * hi)))
    for y in range(glass_top, glass_bot + 1):
        if (y - glass_top) % 5 == 3:
            continue
        if y >= surface and lit:
            cv.px(gx, y, FL[5] if y < surface + 3 else FL[4])
        else:
            cv.px(gx, y, GL[4] if y < glass_top + 3 else GL[3])
    # the coil inside: a zig-zag down the middle
    cx = x0 + w // 2
    for y in range(glass_top + 1, glass_bot):
        # a spring seen from the side: its turns cross left and right in turn
        dx = (-1 if (y - glass_top) % 2 else 1) if w >= 9 else 0
        if y >= surface and lit:
            cv.px(cx + dx, y, FL[5])
            if w >= 9:
                cv.px(cx, y, FL[4])
        else:
            cv.px(cx + dx, y, ST[2])
            if w >= 9:
                cv.px(cx, y, ST[1])
    # brass cage: rods over the glass on wide cells, a hoop across the middle on tall ones
    if w >= 11:
        for rx in (x0 + 2, x0 + w - 3):
            for y in range(glass_top, glass_bot + 1):
                cv.px(rx, y, shade(BR, (rx - x0 + 0.5) / w, hi))
    if gh >= 11:
        hy = glass_top + gh // 2
        for x in range(x0 + 1, x0 + w - 1):
            cv.px(x, hy, shade(BR, (x - x0 + 0.5) / w, hi))
        cv.px(x0, hy, OUT)
        cv.px(x0 + w - 1, hy, OUT)
        if w >= 9:
            cv.px(x0 + 1, hy, BR[4])           # rivet
    # the sight slot: a bar of the same glow across the top cap, so the charge reads even
    # when only the top of the cell shows over the shoulders
    sx0, sx1 = x0 + 2, x0 + w - 3
    n = sx1 - sx0 + 1
    fb = int(round(f * n)) if lit else 0
    if lit:
        fb = max(fb, 1)
    for gy in gauge:
        cv.px(sx0 - 1, gy, BR[1])
        cv.px(sx1 + 1, gy, BR[1])
        for x in range(sx0, sx1 + 1):
            on = x - sx0 < fb
            cv.px(x, gy, (FL[4] if gy == gauge[0] else FL[2]) if on else (GL[1] if gy == gauge[0] else GL[0]))
    cv.px(sx0 - 1, gauge[0] - 1, BR[5])
    # rivets on the bottom cap
    for rx in ((x0 + 2, x0 + w - 3) if w >= 9 else (x0 + 1,)):
        cv.px(rx, y0 + h - 2, BR[3])
    return glass_top, glass_bot


def strap(cv, pts, wide=False):
    """A leather strap along a pixel path (list of points), dark under-edge."""
    for i, (x, y) in enumerate(pts):
        cv.px(x, y, LE[2] if i % 3 else LE[3])
        if wide:
            cv.px(x, y + 1, LE[1])
        if cv.get(x, y + (2 if wide else 1)) is None:
            cv.px(x, y + (2 if wide else 1), LE[0])


def buckle(cv, x, y):
    cv.px(x, y, BR[4])


def draw_upright(view, level, w, h, big=False):
    """One view of a standing backpack cell, with its straps and clamps, on a canvas
    with room around it. Returns the canvas; the cell body is centred on it."""
    pad = 6 if not big else 8
    W, H = w + 2 * pad, h + 2 * pad
    W += W % 2
    H += H % 2
    cv = Canvas(W, H)
    x0, y0 = (W - w) // 2, (H - h) // 2 + 1
    hw = 2 if big else 1
    if view in ("n", "ne"):
        # seen from behind: shoulder straps rise from the top cap over the shoulders, a
        # waist strap runs out from the bottom cap; both clamped to the cell with brass
        lx, rx = x0 + 1, x0 + w - 2
        left = [(lx, y0 - 1), (lx - 1, y0 - 2), (lx - 1, y0 - 3), (lx - 2, y0 - 4)]
        right = [(rx, y0 - 1), (rx + 1, y0 - 2), (rx + 1, y0 - 3), (rx + 2, y0 - 4)]
        if view == "ne":
            right = right[:3]                  # turning away: the right strap foreshortens
        if big:
            left += [(lx - 2, y0 - 5), (lx - 3, y0 - 6)]
            right += [(rx + 2, y0 - 5), (rx + 3, y0 - 6)]
        strap(cv, left, big)
        strap(cv, right, big)
    upright(cv, x0, y0, w, h, level, view, big)
    by = y0 + h - 3
    if view in ("n", "ne"):
        # waist strap with brass clamps where it meets the cell
        span = 2 if not big else 3
        for k in range(1, span + 1):
            cv.px(x0 - k, by, LE[2])
            cv.px(x0 - k, by + 1, LE[0])
            if view == "n" or k < span:
                cv.px(x0 + w - 1 + k, by, LE[2])
                cv.px(x0 + w - 1 + k, by + 1, LE[0])
        cv.px(x0, by, BR[4])
        cv.px(x0 + w - 1, by, BR[3])
        cv.px(x0 + 1, y0, BR[3])
        cv.px(x0 + w - 2, y0, BR[2])
    if view in ("e", "se"):
        # in profile: the back is on the right. Two clamp arms reach from the cell into
        # the back, the shoulder strap runs from the top forward over the shoulder.
        for cy in (y0 + 2 + (1 if big else 0), y0 + h - 4):
            for k in range(0, 3 if not big else 4):
                cv.px(x0 + w - 1 + k, cy, BR[3] if k == 0 else BR[2])
                cv.px(x0 + w - 1 + k, cy + 1, BR[0])
            cv.px(x0 + w - 1, cy, BR[5])
        top = [(x0 + w - 2, y0 - 1), (x0 + w - 1, y0 - 2), (x0 + w, y0 - 2), (x0 + w + 1, y0 - 2),
               (x0 + w + 2, y0 - 1)]
        if big:
            top = [(x0 + w - 3, y0 - 1), (x0 + w - 2, y0 - 2), (x0 + w - 1, y0 - 3), (x0 + w, y0 - 3),
                   (x0 + w + 1, y0 - 3), (x0 + w + 2, y0 - 2), (x0 + w + 3, y0 - 1)]
        if view == "e":
            strap(cv, top, big)            # (from the front-quarter view it's behind the shoulder)
    if view == "s":
        # from the front only the top shows over the shoulders: the straps run forward
        # over them from the top cap
        lx, rx = x0 + 1, x0 + w - 2
        strap(cv, [(lx, y0 - 1), (lx - 1, y0 - 1)], big)
        strap(cv, [(rx, y0 - 1), (rx + 1, y0 - 1)], big)
    return cv


# ---------------------------------------------------------------- the slung cell

def draw_sling(view, level, L=13, D=7):
    """The ornithopter's cell, slung under its body along the fuselage: lying on its
    side in the side views (charge fills from the tail end toward the nose), seen
    end-on (a round lens) from the front and back."""
    W, H = L + 8, D + 10
    W += W % 2
    H += H % 2
    cv = Canvas(W, H)
    lit = level > 0
    f = level / (LEVELS - 1)
    if view in ("s", "n"):
        # end-on: a brass ring around a glass lens; the lens fills from the bottom
        d = D + 1
        x0, y0 = (W - d) // 2, (H - d) // 2 + 1
        ring = [(x, y) for y in range(d) for x in range(d)
                if (x - d / 2 + 0.5) ** 2 + (y - d / 2 + 0.5) ** 2 <= (d / 2) ** 2]
        inner = d / 2 - 1.6
        fill_y = d - 1.5 - f * (d - 3)
        for x, y in ring:
            r2 = (x - d / 2 + 0.5) ** 2 + (y - d / 2 + 0.5) ** 2
            u = (x + 0.5) / d
            if r2 > (d / 2 - 0.7) ** 2:
                c = OUT
            elif r2 > inner ** 2:
                c = shade(BR, (x + y * 0.6 + 0.5) / (d * 1.6), 0.3)
            elif lit and y >= fill_y:
                c = shade(FL[1:], u, 0.35)
            else:
                c = shade(GL[:4], u, 0.35)
            cv.px(x0 + x, y0 + y, c)
        cv.px(x0 + d // 2 - 1, y0 + 2, GL[4] if not (lit and f > 0.8) else FL[5])
        if lit:
            cv.px(x0 + d // 2, y0 + d // 2, FL[5])
        # two hangers up to the belly
        for hx in (x0 + 1, x0 + d - 2):
            cv.px(hx, y0 - 1, LE[2])
            cv.px(hx, y0 - 2, LE[1])
        return cv
    Lv = L if view == "e" else L - 2
    x0, y0 = (W - Lv) // 2, (H - D) // 2 + 1
    fill = int(round(f * (Lv - 6))) if lit else 0
    if lit:
        fill = max(fill, 1)
    for x in range(x0, x0 + Lv):
        for y in range(y0, y0 + D):
            v = (y - y0 + 0.5) / D
            endcap = x - x0 < 2 or x0 + Lv - 1 - x < 2
            if y in (y0, y0 + D - 1) or x in (x0, x0 + Lv - 1):
                c = OUT
            elif endcap:
                c = shade(BR, v, 0.3)
            else:
                gx = x - x0 - 2                       # 0 at the tail-end cap
                if lit and gx < fill:
                    c = shade(FL[:5], v, 0.35)
                    if gx == fill - 1:
                        c = shade(FL[2:], v, 0.35)    # the bright front of the charge
                else:
                    c = shade(GL[:4], v, 0.35)
            cv.px(x, y, c)
    # corners rounded off
    for (x, y) in ((x0, y0), (x0 + Lv - 1, y0), (x0, y0 + D - 1), (x0 + Lv - 1, y0 + D - 1)):
        cv.a[y, x] = 0
    # glint, coil, hoop, hangers
    for x in range(x0 + 3, x0 + Lv - 3):
        if (x - x0) % 4 != 1:
            gx = x - x0 - 2
            cv.px(x, y0 + 1, FL[5] if lit and gx < fill else GL[4] if x < x0 + 6 else GL[3])
        cy = y0 + D // 2 + [0, -1][(x - x0) % 2]
        gx = x - x0 - 2
        cv.px(x, cy, FL[5] if lit and gx < fill else ST[1])
    mid = x0 + Lv // 2
    for y in range(y0, y0 + D):
        cv.px(mid, y, BR[3] if y not in (y0, y0 + D - 1) else OUT)
    cv.px(mid, y0 + 1, BR[5])
    for hx in (x0 + 3, x0 + Lv - 4):
        cv.px(hx, y0 - 1, LE[2])
        cv.px(hx, y0 - 2, LE[1])
        cv.px(hx, y0, BR[4])
    # the tail-end terminal lamp
    cv.px(x0 - 1, y0 + D // 2, OUT)
    cv.px(x0, y0 + D // 2, (FL[5] if lit else ST[1]))
    return cv


# ---------------------------------------------------------------- the pack types

TYPES = {
    # name: (drawer, args)
    "small": lambda v, l: draw_upright(v, l, 7, 12),
    "medium": lambda v, l: draw_upright(v, l, 9, 15),
    "large": lambda v, l: draw_upright(v, l, 13, 22, big=True),
    "sling": lambda v, l: draw_sling(v, l),
}


def grime(a):
    """Worn metal: a fixed per-pixel speckle on the brass, steel and leather (not on the
    glowing fluid or the outline), the same in every charge frame so nothing flickers."""
    a = a.copy()
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    n = ((xx * 73856093) ^ (yy * 19349663)) % 997 / 996.0
    rgb = a[..., :3].astype(float)
    glow = (rgb[..., 0] > 140) & (rgb[..., 1] > 80) & (rgb[..., 2] < rgb[..., 1] * 0.75) & \
        (rgb[..., 0] - rgb[..., 2] > 120) & (rgb[..., 1] > rgb[..., 0] * 0.55)
    lum = rgb.sum(-1)
    m = (a[..., 3] > 0) & ~glow & (lum > 150)
    k = 0.9 + 0.16 * n
    rgb[m] *= k[m][:, None]
    a[..., :3] = rgb.clip(0, 255).astype(np.uint8)
    return a


def build_sheet(t):
    cells = [[grime(TYPES[t](v, lv).a) for lv in range(LEVELS)] for v in VIEWS]
    ch, cw = cells[0][0].shape[:2]
    for row in cells:
        for c in row:
            assert c.shape[:2] == (ch, cw), (t, c.shape, (ch, cw))
    sheet = np.zeros((ch * len(VIEWS), cw * LEVELS, 4), np.uint8)
    for r, row in enumerate(cells):
        for k, c in enumerate(row):
            sheet[r * ch:(r + 1) * ch, k * cw:(k + 1) * cw] = c
    return sheet, (cw, ch)


# ---------------------------------------------------------------- where the packs sit

# Per construct: the pack type, and per drawn direction the pack's view, whether it hangs
# in front of the body (True) or behind it (False), a reference frame, the pack centre
# on it (game px from the feet) and the torso patch (x0, y0, x1, y1, same coords) that
# is followed through the other frames. "skip" lists animations with no pack (death:
# the construct falls apart). HAND: (key, frame) -> (x, y[, view, front, rot]) for frames
# the tracker gets wrong or that need the pack turned (rot: degrees clockwise, e.g. lying
# on the back of a knight bent over his swing; view/front None = the direction's own).
CONSTRUCTS = {
    "gearknight": {"type": "medium", "dirs": {
        "e": dict(view="e", front=True, ref=("walk_e", 0), at=(-15, -33), patch=(-14, -50, 6, -24)),
        "s": dict(view="s", front=False, ref=("idle_s", 0), at=(-4, -40), patch=(-10, -49, 12, -30)),
    }},
    "bolt": {"type": "medium", "dirs": {
        "e": dict(view="se", front=False, ref=("walk_e", 0), at=(-7, -33), patch=(-15, -40, 10, -20)),
        "s": dict(view="s", front=False, ref=("idle_s", 0), at=(-6, -35), patch=(-14, -38, 14, -18)),
    }},
    "steam_walker": {"type": "large", "dirs": {
        "e": dict(view="e", front=True, ref=("walk_e", 0), at=(-21, -52), patch=(-18, -75, 20, -35), reach=50),
    }},
    "ornithopter": {"type": "sling", "dirs": {
        "s": dict(view="s", front=True, ref=("walk_s", 2), at=(-1, -7), patch=(-6, -16, 6, 0)),
        "se": dict(view="se", front=True, ref=("walk_se", 2), at=(-3, -2), patch=(-5, -17, 8, -1)),
        "e": dict(view="e", front=True, ref=("walk_e", 2), at=(-4, -1), patch=(-6, -15, 9, -1)),
        "ne": dict(view="ne", front=False, ref=("walk_ne", 2), at=(3, -4), patch=(-6, -20, 8, -6)),
        "n": dict(view="n", front=False, ref=("walk_n", 2), at=(0, -3), patch=(-4, -22, 4, -2)),
    }},
    "stormcaller": {"type": "small", "dirs": {
        "s": dict(view="s", front=False, ref=("walk_s", 0), at=(-5, -33), patch=(-8, -46, 8, -16)),
        "se": dict(view="se", front=False, ref=("walk_se", 0), at=(-7, -31), patch=(-8, -46, 8, -16)),
        "e": dict(view="e", front=True, ref=("walk_e", 0), at=(-9, -26), patch=(-8, -46, 8, -16)),
        "ne": dict(view="ne", front=True, ref=("walk_ne", 0), at=(-2, -25), patch=(-8, -46, 8, -16)),
        "n": dict(view="n", front=True, ref=("walk_n", 0), at=(0, -25), patch=(-8, -46, 8, -16)),
    }},
}
HAND = {
    "gearknight": {
        ("attack_e", 0): (-6, -42, "se", False),
        ("attack_e", 3): ("+", 2, 0),
        ("attack_e", 4): (2, -37, None, True, 70),
        ("attack_e", 5): (-6, -40, None, True, 60),
        ("attack_e", 6): (-7, -39, None, True, 60),
        ("attack_e", 7): (-4, -37, None, True, 40),
    },
    "steam_walker": {("attack_e", 3): ("+", -9, 2)},     # a bigger gear drawn on its back there
    # casting STORM he turns to the camera and raises both arms in every direction:
    # the cell goes behind his shoulders
    "stormcaller": {("cast_" + d, i): (-1, -31, "s", False) for d in ("s", "se", "e", "ne", "n") for i in (1, 2, 3)},
}
SKIP = ("death",)


def unit_art(src, kind):
    m = re.search(r'\t"%s": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), '
                  r'"frames": \{(.*?)\}\}' % kind, src, re.S)
    cw, ch, ax, ay = int(m[1]), int(m[2]), float(m[3]), float(m[4])
    frames = {k: int(n) for k, n in re.findall(r'"(\w+)": (\d+)', m[5])}
    return (cw, ch), (ax, ay), frames


PAD = 40


def strip_frames(kind, key, cell, anchor, n):
    """The frames of a strip, each on a canvas padded by PAD around the cell, with the
    feet (anchor) at (ax + PAD, ay + PAD) - sheets taller than the cell keep their feet
    at the bottom, as the game draws them."""
    im = np.array(Image.open(f"assets/units/{kind}/{key}.png").convert("RGBA"))
    cw, ch = cell
    extra = im.shape[0] - ch
    out = []
    for i in range(n):
        c = np.zeros((ch + 2 * PAD, cw + 2 * PAD, 4), np.uint8)
        part = im[extra:, i * cw:(i + 1) * cw]
        c[PAD:PAD + ch, PAD:PAD + part.shape[1]] = part
        out.append(c)
    return out


def track(ref, box, frm, anchor, reach=14):
    """(dx, dy) that best moves the torso patch `box` (feet coords) of ref onto frm."""
    ax, ay = anchor[0] + PAD, anchor[1] + PAD
    x0, y0, x1, y1 = [int(round(v)) for v in (box[0] + ax, box[1] + ay, box[2] + ax, box[3] + ay)]
    P = ref[y0:y1, x0:x1].astype(float)
    pa = P[..., 3] > 0
    best, bd = (0, 0), 1e18
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            if y0 + dy < 0 or x0 + dx < 0 or y1 + dy > frm.shape[0] or x1 + dx > frm.shape[1]:
                continue
            F = frm[y0 + dy:y1 + dy, x0 + dx:x1 + dx].astype(float)
            fa = F[..., 3] > 0
            both = pa & fa
            cost = (pa ^ fa).sum() * 120.0 + np.abs(P[..., :3] - F[..., :3]).mean(-1)[both].sum()
            cost += 2.0 * (dx * dx + dy * dy)
            if cost < bd:
                bd, best = cost, (dx, dy)
    return best


def placements(src):
    """{kind: {key: [(view, front, x, y, rot) per frame]}}"""
    out = {}
    for kind, cfg in CONSTRUCTS.items():
        cell, anchor, frames = unit_art(src, kind)
        refs = {}
        keys = {}
        for key, n in sorted(frames.items()):
            anim, d = key.rsplit("_", 1)
            if anim in SKIP or d not in cfg["dirs"]:
                continue
            dc = cfg["dirs"][d]
            rk, ri = dc["ref"]
            if rk not in refs:
                refs[rk] = strip_frames(kind, rk, cell, anchor, frames[rk])
            ref = refs[rk][ri]
            fr = strip_frames(kind, key, cell, anchor, n)
            pts = []
            for i, f in enumerate(fr):
                h = HAND.get(kind, {}).get((key, i))
                if h is not None and h[0] == "+":
                    # a nudge of the tracked spot
                    dx, dy = track(ref, dc["patch"], f, anchor, dc.get("reach", 14))
                    h = (dc["at"][0] + dx + h[1], dc["at"][1] + dy + h[2]) + tuple(h[3:])
                if h is not None:
                    h = tuple(h) + (None, None, 0)[len(h) - 2:]
                    pts.append((h[2] or dc["view"], dc["front"] if h[3] is None else h[3], h[0], h[1], h[4]))
                    continue
                dx, dy = track(ref, dc["patch"], f, anchor, dc.get("reach", 14))
                pts.append((dc["view"], dc["front"], dc["at"][0] + dx, dc["at"][1] + dy, 0))
            keys[key] = pts
        out[kind] = keys
    return out


# ---------------------------------------------------------------- output

def write_table(place, cells):
    lines = ["", "## Clockwork battery backpacks (tools/make_packs.py - edit there, not here):",
             "## kind -> pack type, its cell, and per animation strip one entry per frame:",
             "## [view (row of the sheet: s, se, e, ne, n), in front of the body, centre x, centre y",
             "## (game px from the feet, unflipped art), rotation (degrees clockwise)].",
             "const PACKS := {"]
    for kind in CONSTRUCTS:
        t = CONSTRUCTS[kind]["type"]
        cw, ch = cells[t]
        lines.append(f'\t"{kind}": {{"type": "{t}", "cell": Vector2i({cw}, {ch}), "keys": {{')
        for key, pts in sorted(place[kind].items()):
            ps = ", ".join(f'[{VIEWS.index(v)}, {"true" if f else "false"}, {x}, {y}, {r}]' for v, f, x, y, r in pts)
            lines.append(f'\t\t"{key}": [{ps}],')
        lines.append("\t}},")
    lines.append("}")
    block = "\n".join(lines) + "\n"
    path = "scripts/art_data.gd"
    src = open(path).read()
    pat = re.compile(r"\n## Clockwork battery backpacks.*?\nconst PACKS := \{.*?\n\}\n", re.S)
    if pat.search(src):
        src = pat.sub(lambda m: block, src, count=1)
    else:
        src = src.rstrip("\n") + "\n" + block
    open(path, "w").write(src)


def preview(place, sheets, cells, out, level=9, scale=4):
    """Every strip of every construct with its pack on, x3, one sheet per construct."""
    src = open("scripts/art_data.gd").read()
    os.makedirs(out, exist_ok=True)
    for kind, keys in place.items():
        cell, anchor, frames = unit_art(src, kind)
        t = CONSTRUCTS[kind]["type"]
        pw, ph = cells[t]
        rows = []
        for key, pts in sorted(keys.items()):
            fr = strip_frames(kind, key, cell, anchor, frames[key])
            row = []
            for f, (view, front, x, y, rot) in zip(fr, pts):
                r = VIEWS.index(view)
                pk = sheets[t][r * ph:(r + 1) * ph, level * pw:(level + 1) * pw]
                if rot:
                    pk = np.array(Image.fromarray(pk).rotate(-rot, resample=Image.NEAREST))
                bg = np.zeros_like(f)
                bg[..., :3] = (88, 112, 78)
                bg[..., 3] = 255
                px0 = int(anchor[0] + PAD + x - pw // 2)
                py0 = int(anchor[1] + PAD + y - ph // 2)
                lay = np.zeros_like(f)
                lay[py0:py0 + ph, px0:px0 + pw] = pk
                img = Image.fromarray(bg)
                for l in ((f, lay) if front else (lay, f)):
                    img.alpha_composite(Image.fromarray(l))
                row.append(img)
                al = (f[..., 3] > 0) | (lay[..., 3] > 0)
                ys, xs = np.nonzero(al)
                bb = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
                box = bb if "box" not in locals() else (min(box[0], bb[0]), min(box[1], bb[1]),
                                                        max(box[2], bb[2]), max(box[3], bb[3]))
            rows.append((key, row))
        box = (box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3)
        rows = [(k, [im.crop(box) for im in r]) for k, r in rows]
        del box
        cwp, chp = rows[0][1][0].size
        W = max(len(r) for _, r in rows) * (cwp + 2)
        H = len(rows) * (chp + 2)
        sheet = Image.new("RGBA", (W, H), (20, 20, 20, 255))
        for j, (key, row) in enumerate(rows):
            for i, im in enumerate(row):
                sheet.paste(im, (i * (cwp + 2), j * (chp + 2)))
        sheet = sheet.resize((W * scale, H * scale), Image.NEAREST)
        sheet.save(f"{out}/{kind}.png")
        for key, row in rows:
            st = Image.new("RGBA", (len(row) * (cwp + 2), chp), (20, 20, 20, 255))
            for i, im in enumerate(row):
                st.paste(im, (i * (cwp + 2), 0))
            st.resize((st.width * 6, st.height * 6), Image.NEAREST).save(f"{out}/{kind}_{key}.png")


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    sheets, cells = {}, {}
    for t in TYPES:
        sheets[t], cells[t] = build_sheet(t)
    if "--art-only" in sys.argv:
        out = sys.argv[sys.argv.index("--art-only") + 1]
        os.makedirs(out, exist_ok=True)
        for t in TYPES:
            Image.fromarray(sheets[t]).save(f"{out}/pack_{t}.png")
        return
    src = open("scripts/art_data.gd").read()
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else None
    if only:
        for k in list(CONSTRUCTS):
            if k not in only:
                del CONSTRUCTS[k]
    place = placements(src)
    if "--preview" in sys.argv:
        preview(place, sheets, cells, sys.argv[sys.argv.index("--preview") + 1])
        if only:
            return
    if only:
        raise SystemExit("--only is for previews")
    for t in TYPES:
        Image.fromarray(sheets[t]).save(f"assets/effects/pack_{t}.png")
    write_table(place, cells)
    print("packs: " + ", ".join(f"{k} {len(v)} strips" for k, v in place.items()))


if __name__ == "__main__":
    main()
