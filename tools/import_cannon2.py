"""Build the Crown's Field Cannon sprite set from the three ChatGPT sheets
art/crown/cannon2_front.png, cannon2_side.png and cannon2_angles.png.

The sheets are inconsistent (horses that come and go, two guns in one frame, crew
counts that change, a different zoom in every column), so every frame is picked by
hand in the DRAWINGS table below: cut out, cleaned, scaled so its soldiers are K times
as tall as the musketeers (K: the horse matches the cuirassier's), split into a gun+crew layer and a horse layer, and then combined
into the animations in build_*().

Output: assets/units/cannon/<anim>_<dir>.png strips (walk, idle, fire, reload, deploy,
death x s, se, e, ne, n) that all share one cell size and one anchor - the ground point
under the gun's axle - and the "cannon" entry of scripts/art_data.gd.

Usage (from the repo root): python3 tools/import_cannon2.py [--out DIR]
Needs Pillow, NumPy and SciPy.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import TEAM_DARK, TEAM_LIGHT, load  # noqa: E402

SHEETS = {k: f"art/crown/cannon2_{k}.png" for k in ("front", "side", "angles")}
OUT = "assets/units/cannon"
DIRS = ["s", "se", "e", "ne", "n"]
# The whole gun is drawn K times bigger than "soldiers as tall as the musketeers", so its
# horse matches the cuirassier's horse (the cannon read too small next to the cavalry).
# Every hand-placed game-pixel number below (boxes, shifts, painted barrel, patches) is
# written at K = 1 and goes through g()/gf().
K = 1.15
SOLDIER_H = 33.0 * K      # the gun crew's height in game pixels (helmet to boots)
CELL, CELL_ANCHOR = (165, 129), (73, 89)   # the published strip layout (at K = 1.15)


def g(v):
    """A hand-placed game-pixel number (written for K = 1) at the current scale."""
    return int(round(v * K))


def gf(v):
    return v * K


def gbox(b):
    return tuple(g(v) for v in b)


# ---------------------------------------------------------------- cutting out

def bg_mask(px):
    """Background of a flat slate sheet, including the soft slate-blue ground shadows
    (same hue as the background, only darker). Flooded in from the border, so dark
    outlines stop it; enclosed pockets of plain background (between spokes and legs)
    are removed too."""
    rgb = px[..., :3].astype(float)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bgc = np.median(border, 0)
    near = np.abs(rgb - bgc).max(-1) <= 13
    k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
    resid = np.abs(rgb - k[..., None] * bgc).max(-1)
    shadow = (k >= 0.38) & (k <= 1.08) & (resid <= 7 + 6 * k)
    cand = near | shadow
    lab, n = ndimage.label(cand)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    lab2, n2 = ndimage.label(near & ~bg)
    if n2:
        size = ndimage.sum(near, lab2, np.arange(1, n2 + 1))
        bg |= (size >= 6)[lab2 - 1] & (lab2 > 0)
    return bg, bgc


_SHEET = {}


def sheet(name):
    if name not in _SHEET:
        px = load(SHEETS[name])
        bg, bgc = bg_mask(px)
        _SHEET[name] = (px, ~bg, bgc)
    return _SHEET[name]


def poly_mask(shape, origin, pts):
    """Boolean mask of a polygon given in sheet coordinates, on a crop at origin."""
    from PIL import ImageDraw
    h, w = shape
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon([(x - origin[0], y - origin[1]) for x, y in pts], fill=1)
    return np.array(im).astype(bool)


def is_effect(rgb):
    """Muzzle flash, sparks and powder smoke (pale, colourless) on the source sheets."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    flash = (r >= 200) & (g >= 120) & (mx - mn >= 40) & (b <= 200)
    flash |= (r >= 235) & (g >= 200) & (b >= 150)
    spark = (r >= 170) & (g <= 120) & (b <= 90) & (r - g >= 90)
    smoke = (mx - mn <= 28) & (rgb.mean(-1) >= 95)
    return flash, spark, smoke


# ---------------------------------------------------------------- the drawings
# box: crop on the sheet (x0, y0, x1, y1); soldier: a standing soldier's height there
# (source px) - sets the scale; anchor: ground point under the gun's axle (sheet px).
# horse: polygon (sheet px) holding the horse and its leader (moved/faded separately).
# erase: polygons removed outright; effect: polygon holding the painted flash+smoke.

# around the axle of the side-view walk gun (source px): breech knob at -43, the rammer
# rod of the man behind at -46..-40 high, trail end under his boot at about -64
def gun_side(muzzle):
    return [(-43, -72), (muzzle + 1, -72), (muzzle + 1, 9), (-64, 9), (-64, -14), (-52, -30), (-43, -38)]


def horse_side(tail):
    return [(tail, -140), (300, -140), (300, 20), (tail, 20)]


DRAWINGS = {
    # --- side sheet (facing east) ---
    # Side walk frames: the sheet draws the limbered gun with its muzzle toward the horse.
    # A towed gun trails behind the limber with its muzzle backwards, so the gun ("gun",
    # cut around the axle) is mirrored in build(); the rear crewman stays ("main"), the
    # horse and leader ("horse") move up to the trail end. Polygons are relative to anchor.
    "W1": dict(sheet="side", box=(11, 82, 316, 222), soldier=96, anchor=(133, 208), rel=True,
               gun=gun_side(55), horse=horse_side(57), muzzle=55),
    "W2": dict(sheet="side", box=(363, 80, 632, 222), soldier=96, anchor=(470, 208), rel=True,
               gun=gun_side(41), horse=horse_side(30), muzzle=41),
    "W3": dict(sheet="side", box=(685, 80, 985, 222), soldier=96, anchor=(795, 206), rel=True,
               gun=gun_side(50), horse=horse_side(54), muzzle=50),
    "W4": dict(sheet="side", box=(1038, 80, 1306, 222), soldier=96, anchor=(1142, 206), rel=True,
               gun=gun_side(44), horse=horse_side(33), muzzle=44),
    "P1": dict(sheet="side", box=(8, 252, 346, 392), soldier=96, anchor=(143, 378),
               horse=[(203, 252), (346, 252), (346, 392), (203, 392)]),
    "F3": dict(sheet="side", box=(720, 434, 1039, 566), soldier=96, anchor=(847, 557),
               effect=[(893, 434), (1039, 434), (1039, 566), (893, 566)]),
    "R1": dict(sheet="side", box=(26, 614, 335, 760), soldier=96, anchor=(143, 746),
               erase=[[(200, 614), (335, 614), (335, 760), (200, 760)]]),
    "R2": dict(sheet="side", box=(393, 622, 702, 760), soldier=96, anchor=(526, 745),
               erase=[[(582, 622), (702, 622), (702, 760), (582, 760)]]),
    "F1": dict(sheet="side", box=(24, 438, 320, 570), soldier=96, anchor=(151, 548),
               erase=[[(197, 438), (320, 438), (320, 570), (197, 570)]]),
    # --- angles sheet, column 1: gun pointing south-east, horse behind on the left ---
    "A1R1": dict(sheet="angles", box=(305, 230, 512, 380), soldier=70, anchor=(434, 356),
                 horse=[(305, 230), (399, 230), (399, 262), (396, 274), (368, 274), (364, 300),
                        (360, 322), (356, 350), (305, 350)]),
    "A1R3": dict(sheet="angles", box=(305, 612, 512, 755), soldier=70, anchor=(434, 729),
                 horse=[(305, 612), (372, 612), (372, 646), (366, 650), (362, 676), (358, 700),
                        (352, 720), (305, 720)]),
    # --- angles sheet, column 1 row 2: gun pointing north-east, firing ---
    "A1R2": dict(sheet="angles", box=(310, 412, 560, 555), soldier=70, anchor=(425, 538),
                 horse=[(310, 412), (410, 412), (410, 440), (406, 452), (404, 470), (392, 474),
                        (382, 478), (378, 495), (372, 512), (366, 540), (310, 540)],
                 effect=[(482, 412), (560, 412), (560, 505), (482, 505)],
                 scrub=[[(466, 445), (482, 445), (482, 505), (466, 505)]],
                 erase=[[(466, 425), (500, 425), (500, 466), (466, 466)]]),
    # --- front sheet, column 0/1 row 0: gun pointing south, horse in the shafts behind
    # it facing south (the limbered gun); without the horse, the deployed gun. (The
    # angles sheet's south column draws the gun twice as big as the crew, so it isn't used.)
    "F0R0": dict(sheet="front", box=(60, 18, 212, 170), soldier=78, anchor=(130, 146),
                 horse=[(110, 15), (155, 15), (155, 100), (143, 100), (143, 89), (119, 89),
                        (119, 100), (110, 100)]),
    "F1R0": dict(sheet="front", box=(322, 18, 465, 172), soldier=78, anchor=(393, 143),
                 horse=[(364, 15), (407, 15), (407, 103), (405, 103), (405, 92), (383, 92),
                        (383, 103), (364, 103)]),
    # --- front sheet, column 5 last row: a horse seen from the front (head toward the
    # camera) with its leader behind its head, standing over a wreck - cut above the wreck.
    # Put in front of the south gun it leads the limbered gun south.
    "HS": dict(sheet="front", box=(1360, 790, 1402, 887), soldier=78, anchor=(1382, 887)),
    # --- angles sheet, column 5: horse leading north, gun behind ---
    "A5R1": dict(sheet="angles", box=(1332, 218, 1490, 400), soldier=75, anchor=(1404, 380)),
    "A5R3": dict(sheet="angles", box=(1330, 588, 1490, 762), soldier=77, anchor=(1404, 743),
                 horse=[(1378, 588), (1422, 588), (1422, 670), (1414, 672), (1394, 672), (1384, 670),
                        (1378, 660)]),
    # --- wrecks (angles sheet, last row) ---
    "D_E": dict(sheet="angles", box=(566, 830, 812, 950), soldier=70, anchor=(690, 895)),
    "D_S": dict(sheet="angles", box=(1103, 840, 1272, 956), soldier=70, anchor=(1190, 912)),
    "D_SE": dict(sheet="angles", box=(27, 818, 248, 965), soldier=70, anchor=(118, 905), mirror=True),
    "D_NE": dict(sheet="angles", box=(309, 812, 516, 955), soldier=70, anchor=(410, 900)),
    "D_N": dict(sheet="angles", box=(1305, 815, 1498, 955), soldier=70, anchor=(1400, 900)),
}


class Layer:
    """An RGBA image (game scale) with the anchor's position inside it."""

    def __init__(self, img, ax, ay):
        self.img, self.ax, self.ay = img, ax, ay

    def copy(self):
        return Layer(self.img.copy(), self.ax, self.ay)


def cut(name):
    """Source-resolution layers of a drawing: main (gun + crew), horse, effect."""
    d = DRAWINGS[name]
    px, fg, _ = sheet(d["sheet"])
    x0, y0, x1, y1 = d["box"]
    img = px[y0:y1, x0:x1].copy()
    m = fg[y0:y1, x0:x1].copy()
    for pts in d.get("erase", []):
        m &= ~poly_mask(m.shape, (x0, y0), pts)
    for pts in d.get("scrub", []):
        # leftover flash and sparks on the muzzle of a gun drawn firing
        fl, sp, sm = is_effect(img[..., :3].astype(int))
        m &= ~(poly_mask(m.shape, (x0, y0), pts) & (fl | sp | sm))
    parts = {}
    rest = m.copy()
    for key in ("effect", "horse", "gun"):
        if key in d:
            pts = d[key]
            if d.get("rel"):
                pts = [(d["anchor"][0] + x, d["anchor"][1] + y) for x, y in pts]
            pm = poly_mask(m.shape, (x0, y0), pts) & rest
            if key == "horse" and "muzzle" in d:
                # tail and hind legs drawn over/behind the muzzle: leave the gun's bronze and
                # wood to the gun
                rgb = img[..., :3].astype(int)
                r, g, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
                gunlike = (r > b_ + 25) & (g > b_ + 8) & (g > r * 0.42)
                xs = np.arange(m.shape[1])[None, :] + x0 - d["anchor"][0]
                pm &= ~(gunlike & (xs <= d["muzzle"] + 1))
            parts[key] = pm
            rest &= ~pm
    parts["main"] = rest
    out = {}
    for key, pm in parts.items():
        # drop crumbs: tiny pieces cut off by the polygons
        lab, n = ndimage.label(pm, structure=np.ones((3, 3)))
        if n:
            size = ndimage.sum(pm, lab, np.arange(1, n + 1))
            pm = pm & ~((size < 12)[lab - 1] & (lab > 0))
        a = img.copy()
        a[..., 3] = np.where(pm, 255, 0)
        a[~pm] = 0
        out[key] = a
    return out


def shrink(img, scale):
    """Area-average downscale with premultiplied alpha, then a hard alpha edge."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def drawing(name):
    """Game-scale layers {main, horse?, effect?} of a drawing, as Layers."""
    d = DRAWINGS[name]
    scale = SOLDIER_H / d["soldier"]
    x0, y0 = d["box"][:2]
    ax, ay = (d["anchor"][0] - x0) * scale, (d["anchor"][1] - y0) * scale
    out = {}
    for key, img in cut(name).items():
        small = shrink(img, scale)
        if key != "effect":
            small = snap_team(small)            # coats (and harness) -> the two key reds
        else:
            small = snap_team(small, effect=True)
        if d.get("mirror"):
            small = small[:, ::-1].copy()
        out[key] = Layer(small, small.shape[1] - ax if d.get("mirror") else ax, ay)
    return out


# ---------------------------------------------------------------- layer tools

def blank_like(h, w):
    return np.zeros((h, w, 4), np.uint8)


def compose(layers):
    """Stack Layers (first = bottom) on their shared anchor into one Layer."""
    L = max(l.ax for l in layers)
    U = max(l.ay for l in layers)
    R = max(l.img.shape[1] - l.ax for l in layers)
    D = max(l.img.shape[0] - l.ay for l in layers)
    ax, ay = int(np.ceil(L)), int(np.ceil(U))
    w, h = ax + int(np.ceil(R)) + 1, ay + int(np.ceil(D)) + 1
    out = blank_like(h, w)
    for l in layers:
        ox, oy = int(round(ax - l.ax)), int(round(ay - l.ay))
        ih, iw = l.img.shape[:2]
        reg = out[oy:oy + ih, ox:ox + iw]
        m = l.img[..., 3] > 0
        reg[m] = l.img[m]
    return Layer(out, ax, ay)


def shifted(layer, dx, dy):
    """The same picture moved by (dx, dy) relative to the anchor."""
    return Layer(layer.img, layer.ax - dx, layer.ay - dy)


def dither(layer, keep_phase=0):
    """Drop every other pixel in a checkerboard (an NES-style half fade)."""
    img = layer.img.copy()
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    off = (yy + xx + int(round(layer.ax)) + int(round(layer.ay)) + keep_phase) % 2 == 1
    img[off] = 0
    return Layer(img, layer.ax, layer.ay)


def bronze(img):
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (img[..., 3] > 0) & (r > 110) & (r > g + 20) & (g > b + 20) & (g > 70)


def align(ref, lay, search=4, mask=None):
    """Nudge lay's anchor so its gun (bronze pixels) sits best on ref's gun."""
    mask = mask or bronze
    rb, lb = mask(ref.img), mask(lay.img)
    P = search + 2
    W = int(max(ref.ax, lay.ax) + max(rb.shape[1] - ref.ax, lb.shape[1] - lay.ax)) + 2 * P + 2
    H = int(max(ref.ay, lay.ay) + max(rb.shape[0] - ref.ay, lb.shape[0] - lay.ay)) + 2 * P + 2
    cx, cy = int(max(ref.ax, lay.ax)) + P + 1, int(max(ref.ay, lay.ay)) + P + 1

    def put(m, l, dx=0, dy=0):
        c = np.zeros((H, W), bool)
        ox, oy = int(round(cx - l.ax + dx)), int(round(cy - l.ay + dy))
        c[oy:oy + m.shape[0], ox:ox + m.shape[1]] = m
        return c
    A = put(rb, ref)
    best, bd = (0, 0), -1e9
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            score = (A & put(lb, lay, dx, dy)).sum() - 0.05 * (dx * dx + dy * dy)
            if score > bd:
                bd, best = score, (dx, dy)
    return shifted(lay, *best), best


def snap_team(img, effect=False):
    """Coat reds -> the two exact key colours; anything else that happens to be a key
    red is nudged off it so the team shader leaves it alone."""
    img = img.copy()
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = img[..., 3] > 0
    if not effect:
        red = a & (r >= 95) & (g <= r * 0.32) & (b <= r * 0.34)
        light = red & (r >= 178)
        img[light, :3] = TEAM_LIGHT
        img[red & ~light, :3] = TEAM_DARK
        return img
    for key, nudge in ((TEAM_LIGHT, (255, 24, 0)), (TEAM_DARK, (150, 14, 0))):
        m = a & (r == key[0]) & (g == key[1]) & (b == key[2])
        img[m, :3] = nudge
    return img


def rotate(img, deg, sy=1.0):
    """Nearest-neighbour rotation (counter-clockwise, degrees) about the image origin
    corner (0, 0) of a padded canvas; returns image and where (0,0) went."""
    h, w = img.shape[:2]
    pad = int(np.ceil(np.hypot(h, w))) + 2
    big = np.zeros((2 * pad + h, 2 * pad + w, 4), np.uint8)
    big[pad:pad + h, pad:pad + w] = img
    th = np.deg2rad(deg)
    H, W = big.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    # output pixel -> source pixel (inverse map) about the old origin (pad, pad)
    x = xx - pad
    y = (yy - pad) / sy
    sx = np.cos(th) * x - np.sin(th) * y
    syy = np.sin(th) * x + np.cos(th) * y
    si = np.round(syy + pad).astype(int)
    sj = np.round(sx + pad).astype(int)
    ok = (si >= 0) & (si < H) & (sj >= 0) & (sj < W)
    out = np.zeros_like(big)
    out[ok] = big[si[ok], sj[ok]]
    ys, xs = np.nonzero(out[..., 3] > 0)
    y0, x0 = ys.min(), xs.min()
    return out[y0:ys.max() + 1, x0:xs.max() + 1], (pad - x0, pad - y0)


def clean(img, min_size=3, keep_near=2):
    """Remove stray specks: pieces smaller than min_size pixels that sit more than
    keep_near pixels away from any bigger piece, and all single loose pixels."""
    a = img[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if not n:
        return img
    size = ndimage.sum(a, lab, np.arange(1, n + 1))
    big = (size >= min_size)[lab - 1] & (lab > 0)
    near = ndimage.binary_dilation(big, iterations=keep_near)
    small = a & ~big
    drop = small & (~near | ((size == 1)[lab - 1]))
    out = img.copy()
    out[drop] = 0
    return out


def defringe(img, bgc):
    """Edge pixels still tinted like the slate background (or its shadow) go."""
    out = img.copy()
    for _ in range(2):
        a = out[..., 3] > 0
        edge = a & ~ndimage.binary_erosion(a, structure=np.ones((3, 3)))
        rgb = out[..., :3].astype(float)
        k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
        resid = np.abs(rgb - k[..., None] * bgc).max(-1)
        # the slate's own blue cast (b - r grows with brightness): neutral outlines stay
        cast = (rgb[..., 2] - rgb[..., 0]) >= 0.6 * (bgc[2] - bgc[0]) * k
        slate = edge & (k >= 0.3) & (k <= 1.25) & (resid <= 5 + 4 * k) & cast
        out[slate] = 0
    return out


# ---------------------------------------------------------------- figure motion

def move_figure(img, box, legs, bob=0, raise_l=0, raise_r=0, dx=0, dy=0):
    """Re-draw one figure inside box (game px of the layer): the body (rows above
    `legs`) lifted by `bob`, the left/right leg lifted by raise_l/raise_r, everything
    moved by (dx, dy). Used for walk cycles and crew 'working' in views the sheets
    drew only once."""
    x0, y0, x1, y1 = box
    out = img.copy()
    reg = img[y0:y1, x0:x1].copy()
    out[y0:y1, x0:x1][reg[..., 3] > 0] = 0
    h, w = reg.shape[:2]
    lg = legs - y0
    cx = w // 2

    def paint(part, oy, ox):
        ys, xs = np.nonzero(part[..., 3] > 0)
        ty, tx = ys + y0 + oy + dy, xs + x0 + ox + dx
        ok = (ty >= 0) & (ty < out.shape[0]) & (tx >= 0) & (tx < out.shape[1])
        out[ty[ok], tx[ok]] = part[ys[ok], xs[ok]]
    legs_l = np.zeros_like(reg)
    legs_l[lg:, :cx] = reg[lg:, :cx]
    legs_r = np.zeros_like(reg)
    legs_r[lg:, cx:] = reg[lg:, cx:]
    body = np.zeros_like(reg)
    body[:lg] = reg[:lg]
    waist = np.zeros_like(reg)
    if bob and lg >= 1:
        waist[lg - 1] = reg[lg - 1]          # stretch: keep the waist row under the lifted body
    paint(legs_l, -raise_l, 0)
    paint(legs_r, -raise_r, 0)
    paint(waist, 0, 0)
    paint(body, -bob, 0)
    return out


def walk_frames(layers, walkers, horse_bob=True):
    """4-frame walk cycle from a single drawing: men step (one leg lifted, body up a
    pixel) left and right in turn; the horse bobs. Frame 0 is the untouched drawing
    (the game shows it when the gun stands still)."""
    frames = []
    for k in range(4):
        main = layers["main"].img
        horse = layers["horse"].img if "horse" in layers else None
        if k in (1, 3):
            for wk in walkers:
                tgt = horse if wk.get("layer") == "horse" else main
                if wk["kind"] == "man":
                    kw = dict(bob=1, raise_l=2) if k == 1 else dict(bob=1, raise_r=2)
                    if wk.get("swap"):
                        kw = dict(bob=1, raise_r=2) if k == 1 else dict(bob=1, raise_l=2)
                else:
                    kw = dict(bob=1)
                tgt = move_figure(tgt, wk["box"], wk["legs"], **kw)
                if wk.get("layer") == "horse":
                    horse = tgt
                else:
                    main = tgt
            if horse is not None and horse_bob:
                horse = np.roll(horse, -1, axis=0)
        ls = []
        if horse is not None:
            ls.append(Layer(horse, layers["horse"].ax, layers["horse"].ay))
        ls.append(Layer(main, layers["main"].ax, layers["main"].ay))
        frames.append(compose(ls))
    return frames


# ---------------------------------------------------------------- muzzle effects

def effect_source(name, muzzle_src):
    """The painted flash + smoke of a drawing as an image whose (ex, ey) is the muzzle."""
    d = DRAWINGS[name]
    lay = drawing(name)["effect"]
    s = SOLDIER_H / d["soldier"]
    mx, my = (muzzle_src[0] - d["box"][0]) * s, (muzzle_src[1] - d["box"][1]) * s
    img = lay.img
    ys, xs = np.nonzero(img[..., 3] > 0)
    y0, x0 = ys.min(), xs.min()
    return img[y0:ys.max() + 1, x0:xs.max() + 1].copy(), (mx - x0, my - y0)


def classify(img):
    a = img[..., 3] > 0
    fl, sp, sm = is_effect(img[..., :3].astype(int))
    hot = a & (fl | sp)
    return hot, a & ~hot


def fill_smoke(img, hot):
    """Paint the flash's place inside the cloud with the nearest smoke colour."""
    out = img.copy()
    smoke = (img[..., 3] > 0) & ~hot
    _, (iy, ix) = ndimage.distance_transform_edt(~smoke, return_indices=True)
    inside = hot & ndimage.binary_fill_holes(smoke | hot) & ndimage.binary_dilation(smoke, iterations=2)
    out[inside] = img[iy[inside], ix[inside]]
    out[hot & ~inside] = 0
    return out


def fire_effects(src, aim=0.0, squash=1.0):
    """Four effect images (each with its muzzle point): flash, flash + smoke, smoke
    drifting off, smoke thinning out. aim: barrel direction in degrees (0 = right,
    90 = up); squash < 1 flattens the plume along the view axis (guns pointing at or
    away from the camera)."""
    img, (ex, ey) = src
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.hypot(xx - ex, yy - ey)
    hot, smoke = classify(img)
    a = img.copy()
    a[dist > gf(9)] = 0                                     # the first flash, close to the muzzle
    b = img
    c = fill_smoke(img, hot)
    c[dist < gf(3)] = 0
    d = c.copy()
    d[dist < gf(9)] = 0
    out = []
    for im, drift in ((a, 0), (b, 0), (c, 2), (d, 5)):
        im = np.roll(im, drift, axis=1)
        if drift:
            im[:, :drift] = 0
        if im is d or drift == 5:
            im = dither(Layer(im, 0, 0)).img
        r, (ox, oy) = rotate(im, aim, squash)
        # where the muzzle went: rotate (ex, ey) the same way
        th = np.deg2rad(aim)
        px_, py_ = ex, ey
        nx = np.cos(th) * px_ + np.sin(th) * py_
        ny = (-np.sin(th) * px_ + np.cos(th) * py_) * squash
        out.append((snap_team(r, effect=True), (ox + nx, oy + ny)))
    return out


def at_muzzle(effect, base, muzzle):
    """A Layer placing an effect image so its muzzle point lands on `muzzle`
    (game px in base's image)."""
    img, (ex, ey) = effect
    return Layer(img, ex - (muzzle[0] - base.ax), ey - (muzzle[1] - base.ay))


def game_pt(name, src):
    d = DRAWINGS[name]
    s = SOLDIER_H / d["soldier"]
    return ((src[0] - d["box"][0]) * s, (src[1] - d["box"][1]) * s)


# ---------------------------------------------------------------- hand fixes

def paint_north_barrel(lay, profile):
    """Angles column 5 drew the deployed gun with the horse standing on its barrel.
    With the horse gone, paint the barrel running north (away from the camera) from
    behind the breech crewman's helmet: bronze shaded like the south-pointing barrel of
    the front sheet, tapering a little with distance, with a reinforcing band and a
    muzzle ring, black outline. Coat pixels are never painted over."""
    img = lay.img.copy()
    shades = [np.array(c, float) for c in profile if sum(c) > 120]   # drop the outline
    cx = lay.ax                              # barrel centre = anchor column
    top, bottom = g(23), g(40)
    red = (img[..., 0].astype(int) > 120) & (img[..., 1] < 70) & (img[..., 3] > 0)
    for y in range(top - 1, bottom + 1):
        t = (y - top) / (bottom - top)
        half = gf(2.2 + 1.4 * t)
        ring = y in (top, top + 1) or y in (top + g(7),)
        if ring:
            half += gf(0.9)
        x0, x1 = int(np.floor(cx - half)), int(np.ceil(cx + half))
        for x in range(x0 - 1, x1 + 1):
            if red[y, x]:
                continue
            if y == top - 1 or x in (x0 - 1, x1):
                if x0 <= x < x1 or y >= top:           # outline around the barrel
                    img[y, x] = (24, 14, 8, 255)
                continue
            u = (x - x0 + 0.5) / (x1 - x0)
            col = shades[min(len(shades) - 1, int(u * len(shades)))].copy()
            if ring and y != top + 1:
                col *= 0.8
            img[y, x, :3] = np.clip(col, 0, 255)
            img[y, x, 3] = 255
    return Layer(img, lay.ax, lay.ay)


# Hand-drawn pixel patches (game px of a drawing's main layer). "." keeps the pixel,
# " " clears it; letters are colours from the key.
NE_MUZZLE = dict(origin=(72, 24), clear=(72, 24, 84, 36), rows=[
    "            ",
    "       oo   ",
    "......olho  ",
    "......lLbHo ",
    "......mbbLo ",
    "....hmmbbho ",
    "..mm.mdmbmo ",
    ".hmm..dsmlo ",
    "......ssdo  ",
    "......ooo   ",
    "..... ",
    "......",
], key={"o": (29, 14, 9), "L": (243, 196, 130), "l": (198, 132, 66), "h": (243, 194, 126),
        "H": (216, 154, 85), "m": (157, 97, 47), "d": (120, 77, 44), "s": (99, 62, 36),
        "b": (30, 18, 12), "k": (45, 28, 18)})


def patch(lay, p):
    """Paint a patch drawn at K = 1, scaled by K (nearest pixel) onto the layer."""
    img = lay.img.copy()
    x0, y0, x1, y1 = gbox(p["clear"])
    keep = img.copy()
    img[y0:y1, x0:x1] = 0
    ox, oy = g(p["origin"][0]), g(p["origin"][1])
    rows = p["rows"]
    for y in range(oy, oy + g(len(rows))):
        j = min(len(rows) - 1, int((y - oy) / K))
        for x in range(ox, ox + g(max(len(r) for r in rows))):
            i = int((x - ox) / K)
            ch = rows[j][i] if i < len(rows[j]) else "."
            if ch == ".":
                img[y, x] = keep[y, x]
            elif ch != " ":
                img[y, x] = p["key"][ch] + (255,)
    return Layer(img, lay.ax, lay.ay)


def barrel_profile():
    """Bronze shades across the south-pointing barrel of F0R0 (left to right)."""
    lay = drawing("F0R0")["main"]
    y = int(round(lay.ay)) - g(8)
    row = lay.img[y]
    xs = [x for x in range(row.shape[0]) if abs(x - lay.ax) <= gf(5) and row[x, 3]]
    return [tuple(int(c) for c in row[x, :3]) for x in xs]


# ---------------------------------------------------------------- the animations

WALKERS = {
    "F0R0": [dict(kind="man", box=gbox((1, 8, 18, 47)), legs=g(31)),
             dict(kind="man", box=gbox((39, 10, 64, 47)), legs=g(31), swap=True)],
    "A5R1": [dict(kind="man", box=gbox((1, 28, 16, 63)), legs=g(47)),
             dict(kind="man", box=gbox((46, 28, 67, 62)), legs=g(47), swap=True),
             dict(kind="horse", box=gbox((19, 2, 42, 36)), legs=g(36))],
}


def without(layers, *keys):
    return {k: v for k, v in layers.items() if k not in keys}


def stack(layers, order=("horse", "main", "gun", "effect")):
    return compose([layers[k] for k in order if k in layers])


def deploy_frames(walk0, with_horse, idle, step, mid=None):
    """walk pose -> (drawing with the horse) -> horse led away -> horse fading -> deployed.
    The game plays these backwards to limber up again."""
    main, horse = with_horse["main"], with_horse["horse"]
    fr = [walk0]
    if mid is not None:
        fr.append(mid)
    fr.append(compose([shifted(horse, step[0], step[1]), main]))
    fr.append(compose([dither(shifted(horse, 2 * step[0], 2 * step[1])), main]))
    fr.append(idle)
    return fr


def blast(effect, wreck, up=0):
    """Death: the gun's own blast turned to rise from the wreck."""
    fx = fire_effects(effect, aim=90, squash=0.8)
    out = []
    for k, (img, (ex, ey)) in enumerate(fx[1:]):
        out.append(Layer(img, ex, ey - up))
    return out


HITCH_SHIFT = gf(10)     # game px the horse moves forward so the trail end reaches it


def mirror(lay):
    """Flip a layer left-right about its anchor."""
    return Layer(lay.img[:, ::-1].copy(), lay.img.shape[1] - lay.ax, lay.ay)


def pole(a, b):
    """The limber pole: a 2 px wooden line between two points (game px relative to the
    anchor), dark underside."""
    (x0, y0), (x1, y1) = a, b
    xs0, ys0 = int(np.floor(min(x0, x1))) - 2, int(np.floor(min(y0, y1))) - 2
    w, h = int(np.ceil(abs(x1 - x0))) + 6, int(np.ceil(abs(y1 - y0))) + 6
    img = np.zeros((h, w, 4), np.uint8)
    n = int(max(abs(x1 - x0), abs(y1 - y0))) * 2 + 1
    for t in np.linspace(0, 1, n):
        x = int(round(x0 + (x1 - x0) * t)) - xs0
        y = int(round(y0 + (y1 - y0) * t)) - ys0
        img[y, x] = (104, 68, 34, 255)
        if img[y + 1, x, 3] == 0:
            img[y + 1, x] = (44, 28, 14, 255)
    return Layer(img, -xs0, -ys0)


def fill_gaps(lay, it=2):
    """Close small notches in a figure (where another object hid it) with the nearest
    colour of the figure."""
    img = lay.img.copy()
    a = img[..., 3] > 0
    closed = ndimage.binary_fill_holes(ndimage.binary_closing(a, iterations=it)) & \
        ndimage.binary_dilation(a, iterations=1)
    new = closed & ~a
    _, (iy, ix) = ndimage.distance_transform_edt(~a, return_indices=True)
    img[new] = img[iy[new], ix[new]]
    return Layer(img, lay.ax, lay.ay)


def limbered_side(name, ref, gun=None):
    """A side walk drawing with the gun turned round: trail toward the horse, muzzle back,
    wheel on the same spot. The horse steps forward so its rump stands at the trail end
    (the same spot in every frame) and a pole joins them. `gun` (already mirrored) replaces
    the frame's own gun so the gun stays put through the cycle. Returns (frame, parts)."""
    d = DRAWINGS[name]
    L = drawing(name)
    _, (dx, dy) = align(ref, L["gun"], search=4)
    L = {k: shifted(v, dx, dy) for k, v in L.items()}
    mg = gun if gun is not None else mirror(L["gun"])
    s = SOLDIER_H / d["soldier"]
    horse = fill_gaps(shifted(L["horse"], HITCH_SHIFT + (57 - d["horse"][0][0]) * s, 0))
    # trail end: the right-most gun pixel in the lowest third of the gun
    a = mg.img[..., 3] > 0
    ys, xs = np.nonzero(a)
    low = ys >= ys.max() - (ys.max() - ys.min()) // 3
    i = np.argmax(xs[low])
    trail = (xs[low][i] - mg.ax - 0.5, ys[low][i] - mg.ay - 1)
    # the horse's trace: its left-most pixel at harness height
    ha = horse.img[..., 3] > 0
    hy, hx = np.nonzero(ha)
    band = (hy - horse.ay >= -gf(22)) & (hy - horse.ay <= -gf(16))
    j = np.argmin(hx[band])
    trace = (hx[band][j] - horse.ax + 1, hy[band][j] - horse.ay)
    parts = dict(gun=mg, horse=horse, crew=L["main"], pole=pole(trail, trace))
    return compose([horse, parts["pole"], L["main"], mg]), parts


def build():
    A = {}
    prof = barrel_profile()

    # ---- east (side sheet) ----
    F3 = drawing("F3")
    idle_e = F3["main"]
    walk, parts = [], []
    fr, pt = limbered_side("W1", idle_e)
    walk.append(fr)
    parts.append(pt)
    ref = mirror(pt["gun"])                 # W1's gun as drawn, aligned
    for n in ("W2", "W3", "W4"):
        fr, p2 = limbered_side(n, ref, gun=pt["gun"])
        walk.append(fr)
        parts.append(p2)
    A["walk", "e"] = walk
    A["idle", "e"] = [idle_e]
    fx = fire_effects(effect_source("F3", (895, 497)))
    mz = game_pt("F3", (895, 497))
    A["fire", "e"] = [compose([idle_e, at_muzzle(f, idle_e, mz)]) for f in fx]
    rel = []
    for n in ("R2", "R1", "F1"):
        r, _ = align(idle_e, drawing(n)["main"])
        rel.append(r)
    A["reload", "e"] = rel
    # unlimbering: unhitch, swing the gun round (through a muzzle-toward-camera pose),
    # lead the horse off, deployed muzzle forward. Played backwards to limber up.
    pt = parts[0]
    unhitched = compose([shifted(pt["horse"], g(2), 0), pt["crew"], pt["gun"]])
    swing_horse = shifted(pt["horse"], g(4), 0)
    off_horse = dither(shifted(pt["horse"], g(6), 0))

    def deploy_side(mid, end):
        return [walk[0], unhitched, compose([swing_horse, mid]), compose([off_horse, mid]), end]

    # ---- south-east (angles col 1) ----
    S1 = drawing("A1R1")
    idle_se = S1["main"]
    A["idle", "se"] = [idle_se]
    # limbered, moving diagonally: the side view (horse leading); the sheets only draw
    # the south-east/north-east gun with the horse behind it
    A["walk", "se"] = list(A["walk", "e"])
    fx = fire_effects(effect_source("F3", (895, 497)), aim=-40)
    mz = game_pt("A1R1", (468, 357))
    A["fire", "se"] = [compose([idle_se, at_muzzle(f, idle_se, mz)]) for f in fx]
    r3, _ = align(idle_se, drawing("A1R3")["main"])
    A["reload", "se"] = [idle_se, r3, r3]

    # ---- north-east (angles col 1, firing row) ----
    N1 = drawing("A1R2")
    N1["main"] = patch(N1["main"], NE_MUZZLE)
    idle_ne = N1["main"]
    A["idle", "ne"] = [idle_ne]
    A["walk", "ne"] = list(A["walk", "e"])
    fx = fire_effects(effect_source("A1R2", (484, 469)))
    mz = game_pt("A1R2", (484, 469))
    A["fire", "ne"] = [compose([idle_ne, at_muzzle(f, idle_ne, mz)]) for f in fx]
    w1 = move_figure(idle_ne.img, gbox((46, 10, 62, 33)), g(33), dx=1, dy=1)
    w2 = move_figure(w1, gbox((26, 28, 44, 59)), g(46), bob=1)
    A["reload", "ne"] = [Layer(w1, idle_ne.ax, idle_ne.ay), Layer(w2, idle_ne.ax, idle_ne.ay), idle_ne]

    # ---- south (front sheet cols 0-1) ----
    F0 = drawing("F0R0")
    idle_s = F0["main"]
    A["idle", "s"] = [idle_s]
    fx = fire_effects(effect_source("F3", (895, 497)), aim=-90, squash=0.55)
    mz = game_pt("F0R0", (131, 160))
    A["fire", "s"] = [compose([idle_s, at_muzzle(f, idle_s, mz)]) for f in fx]
    r1, _ = align(idle_s, drawing("F1R0")["main"])
    w = move_figure(idle_s.img, gbox((39, 10, 64, 47)), g(31), dx=-1, dy=1)
    A["reload", "s"] = [r1, Layer(w, idle_s.ax, idle_s.ay), r1]
    # ---- deployed north gun (needed for the limbered south view) ----
    N5 = drawing("A5R3")
    idle_n = paint_north_barrel(N5["main"], prof)

    # limbered, heading south: horse and leader toward the camera, the gun towed behind
    # them by its trail, muzzle away (north): the deployed north gun without its two side
    # men, the front sheet's two front-facing crew beside it.
    HS = shifted(drawing("HS")["main"], 0, gf(12))
    gi = idle_n.img.copy()
    hh, ww = gi.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    side = (xx <= g(15)) | ((xx <= g(22)) & (yy < g(44))) | (xx >= g(48)) | ((xx >= g(40)) & (yy < g(44)))
    gi[side] = 0
    gunN = Layer(clean(gi, min_size=7, keep_near=1), idle_n.ax, idle_n.ay)
    c = idle_s.img.copy()
    hh, ww = c.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    men = ((xx <= g(17)) & (yy < g(33))) | ((xx <= g(13)) & (yy < g(48))) | \
          ((xx >= g(41)) & (yy < g(33))) | ((xx >= g(46)) & (yy < g(48)))
    c[~men] = 0
    crewS = c
    ws = []
    for k in range(4):
        crew, horse = crewS, HS.img
        if k in (1, 3):
            for wk in WALKERS["F0R0"]:
                kw = dict(bob=1, raise_l=2) if (k == 1) != bool(wk.get("swap")) else dict(bob=1, raise_r=2)
                crew = move_figure(crew, wk["box"], wk["legs"], **kw)
            h, w = horse.shape[:2]
            hk = dict(bob=1, raise_r=2) if k == 1 else dict(bob=1, raise_l=2)
            horse = move_figure(horse, (0, 0, w, h), g(30), **hk)
        ws.append(compose([gunN, Layer(crew, idle_s.ax, idle_s.ay), Layer(horse, HS.ax, HS.ay)]))
    A["walk", "s"] = ws
    crewL = Layer(crewS, idle_s.ax, idle_s.ay)
    A["deploy", "s"] = [ws[0],
                        compose([gunN, crewL, shifted(HS, 0, gf(4))]),
                        compose([idle_e, shifted(HS, gf(13), gf(6))]),
                        compose([idle_s, dither(shifted(HS, gf(18), gf(8)))]),
                        idle_s]

    # side unlimbering (east, and reused by south-east / north-east)
    A["deploy", "e"] = deploy_side(idle_s, idle_e)
    A["deploy", "se"] = deploy_side(idle_s, idle_se)
    A["deploy", "ne"] = deploy_side(idle_n, idle_ne)

    # ---- north (angles col 5) ----
    A["idle", "n"] = [idle_n]
    mz = (idle_n.ax, gf(23) - 0.5)
    fx = fire_effects(effect_source("F3", (895, 497)), aim=90, squash=0.6)
    A["fire", "n"] = [compose([idle_n, at_muzzle(f, idle_n, (mz[0], mz[1] - 0.5))]) for f in fx]
    m1 = move_figure(idle_n.img, gbox((1, 18, 19, 52)), g(40), bob=1)
    m2 = move_figure(idle_n.img, gbox((40, 18, 64, 52)), g(40), bob=1)
    m2 = move_figure(m2, gbox((24, 42, 40, 75)), g(62), dy=1)
    A["reload", "n"] = [Layer(m1, idle_n.ax, idle_n.ay), Layer(m2, idle_n.ax, idle_n.ay), idle_n]
    W5 = drawing("A5R1")
    wn = walk_frames(W5, WALKERS["A5R1"])
    A["walk", "n"] = wn
    N5b = dict(N5, main=idle_n)
    A["deploy", "n"] = deploy_frames(wn[0], N5b, idle_n, (0, -gf(5)), mid=stack(N5))

    # ---- death: the wreck, with the gun's own blast rising from it ----
    for d, name in (("e", "D_E"), ("s", "D_S"), ("se", "D_SE"), ("ne", "D_NE"), ("n", "D_N")):
        wreck = drawing(name)["main"]
        bl = blast(effect_source("F3", (895, 497)), wreck, up=gf(6))
        A["death", d] = [compose([wreck, bl[0]]), compose([wreck, bl[2]]), wreck]
    return A


# ---------------------------------------------------------------- output

def finish(img, bgc, anim):
    img = defringe(img, bgc)
    if anim == "death":
        img = clean(img)                      # keep the scattered debris chips
    else:
        img = clean(img, min_size=7, keep_near=1)
    return img


def assemble(A):
    L = max(l.ax for v in A.values() for l in v)
    U = max(l.ay for v in A.values() for l in v)
    R = max(l.img.shape[1] - l.ax for v in A.values() for l in v)
    D = max(l.img.shape[0] - l.ay for v in A.values() for l in v)
    ax, ay = int(np.ceil(L)) + 1, int(np.ceil(U)) + 1
    W, H = ax + int(np.ceil(R)) + 1, ay + int(np.ceil(D)) + 1
    # keep the published layout (the game and its health bar are tuned to it); grow only
    # if the art no longer fits
    if ax <= CELL_ANCHOR[0] and ay <= CELL_ANCHOR[1] and \
            W - ax <= CELL[0] - CELL_ANCHOR[0] and H - ay <= CELL[1] - CELL_ANCHOR[1]:
        (W, H), (ax, ay) = CELL, CELL_ANCHOR
    else:
        print(f"  ! art outgrew the {CELL} cell: now {(W, H)} anchor {(ax, ay)}")
    strips = {}
    for (anim, d), frames in A.items():
        strip = np.zeros((H, W * len(frames), 4), np.uint8)
        for k, l in enumerate(frames):
            ox, oy = int(round(ax - l.ax)), int(round(ay - l.ay))
            h, w = l.img.shape[:2]
            cell = strip[:, k * W:(k + 1) * W]
            m = l.img[..., 3] > 0
            cell[oy:oy + h, ox:ox + w][m] = l.img[m]
        strips[f"{anim}_{d}"] = strip
    return strips, (W, H), (ax, ay)


def team_check(img, keep):
    """Every exact key red must be a coat (or harness); report any stray one."""
    rgb = img[..., :3].astype(int)
    key = ((rgb == TEAM_LIGHT).all(-1) | (rgb == TEAM_DARK).all(-1)) & (img[..., 3] > 0)
    return int((key & ~keep).sum())


def write_art_data(cell, anchor, counts):
    path = "scripts/art_data.gd"
    src = open(path).read()
    lines = [f'\t"cannon": {{"cell": Vector2i({cell[0]}, {cell[1]}), "anchor": Vector2({anchor[0]}, {anchor[1]}), "frames": {{']
    for k in sorted(counts):
        lines.append(f'\t\t"{k}": {counts[k]},')
    lines.append("\t}},")
    entry = "\n".join(lines) + "\n"
    pat = re.compile(r'\t"cannon": \{"cell".*?\n\t\}\},\n', re.S)
    if not pat.search(src):
        raise SystemExit("cannon entry not found in scripts/art_data.gd")
    src = pat.sub(lambda m: entry, src, count=1)
    open(path, "w").write(src)


def main():
    """--out DIR writes the strips there instead (for trying changes) and leaves
    scripts/art_data.gd alone."""
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else OUT
    A = build()
    bgc = sheet("side")[2]
    A = {k: [Layer(finish(l.img, bgc, k[0]), l.ax, l.ay) for l in v] for k, v in A.items()}
    strips, cell, anchor = assemble(A)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        # old strips go; the replaced move_* sheets lose their .import files too (the
        # other .import files stay and Godot re-imports the new pictures under them)
        if re.match(r"(walk|idle|fire|reload|deploy|death|move)_\w+\.png$", f) or \
                re.match(r"move_\w+\.png\.import$", f):
            os.remove(os.path.join(out, f))
    counts = {}
    for key, strip in sorted(strips.items()):
        Image.fromarray(strip).save(f"{out}/{key}.png")
        counts[key] = strip.shape[1] // cell[0]
    print(f"cannon: cell {cell[0]}x{cell[1]}, anchor {anchor}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    with open(os.path.join(out, "_layout.txt") if out != OUT else os.devnull, "w") as f:
        f.write(f"{cell[0]} {cell[1]} {anchor[0]} {anchor[1]}\n")
    if out == OUT:
        write_art_data(cell, anchor, counts)


if __name__ == "__main__":
    main()
