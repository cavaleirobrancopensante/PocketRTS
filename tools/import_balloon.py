"""The Crown Observation Balloon: a layered sprite set so the two musketeers in the basket
can each idle, fire down at the ground or fire up at flyers independently.

Sources:
  art/crown/balloon_v2.png   rows = directions, groups drift(5) idle(4) death(4) wreck(1)
                             and eight basket close-ups (not used). Flat slate background.
  assets/units/musketeer/*   the game's musketeer, cut at the waist for the gunners

Rows of the sheet: 0 = s, 1 = e (the strongest sideways lean), 2 = se, 3 = ne (drawn
leaning the other way: its lean is flipped so every side view leans the same way - the
basket leads, the envelope trails), 4 = n. The sheet draws each frame at its own zoom, so
every piece is rescaled on its own.

How a body frame is built (drift and idle):
  * the envelope is cut from each source frame (turned upright, everything below the
    load ring dropped), scaled to one envelope width, and turned to the frame's lean;
  * the basket is ONE cleaned basket per direction (from the idle drawing): the painted
    crew is cut away above the wicker, and the open top is repainted pixel by pixel - the
    back rim, the dark inside of the far wall, and the front rim - so the gunners can stand
    in it;
  * the rigging (four ropes, ring to basket) is drawn between them.
  Everything hangs from one anchor: the middle of the basket's bottom.
Death frames are the sheet's collapsing balloon (crew still painted in - no gunners are
drawn while it dies) ending on the smoking wreck, whose ground point is the anchor.

Output (assets/units/balloon/):
  drift_<dir>, idle_<dir>, death_<dir>           body strips
  front_drift_<dir>, front_idle_<dir>            the basket's front wall/rim only
  gunner_idle_<dir>, gunner_down_<dir>, gunner_up_<dir>   one musketeer, waist up
assets/icons/balloon.png, and the "balloon" entry of UNITS in scripts/art_data.gd
(added or replaced in place; nothing else in the file is touched).

Usage (from the repo root): python3 tools/import_balloon.py [--contact DIR]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # import_round4 reads its own flags
import import_round4 as R  # noqa: E402
sys.argv = _argv
from import_art import TEAM_DARK, TEAM_LIGHT  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
ROW_OF = {"s": 0, "e": 1, "se": 2, "ne": 3, "n": 4}
FLIP_LEAN = {"ne"}                 # drawn leaning the other way
OUT = "assets/units/balloon"
CONTACT = _argv[_argv.index("--contact") + 1] if "--contact" in _argv else None

ENV_W = 42          # envelope width in game px (the whole balloon is ~2 musketeers tall)
LEAN_K = 0.55       # share of the sheet's sideways lean that is kept
ROPE_COL = (92, 62, 30)
ROPE_DARK = (52, 34, 18)

R.SHEETS["balloon"] = dict(
    path="art/crown/balloon_v2.png", rows=[205, 402, 588, 785],
    groups=["drift", "idle", "death", "wreck", "poses"], counts=[[5, 4, 4, 1, 8]] * 5,
    panels=[[0, 400, 672, 905, 1010, 1536]] * 5)


# ---------------------------------------------------------------- colour classes (source)

def wicker(rgb):
    r, g, b = [rgb[..., c].astype(int) for c in range(3)]
    return (r > 60) & (r > g) & (g > b) & (r - b > 40) & (g > r * 0.42) & (r < 235)


def envelope_col(rgb):
    r, g, b = [rgb[..., c].astype(int) for c in range(3)]
    red = (r > 120) & (g < r * 0.4) & (b < r * 0.4)
    cream = (r > 150) & (g > 115) & (b > 80) & (r - b < 110)
    return red | cream


# ---------------------------------------------------------------- geometry helpers

def rotate(img, deg, cx, cy, pad=40):
    """Nearest-neighbour turn of img by deg (anticlockwise on screen) about (cx, cy).
    Returns the padded result and a function mapping source points to it."""
    h, w = img.shape[:2]
    H, W = h + 2 * pad, w + 2 * pad
    th = np.deg2rad(deg)
    c, s = np.cos(th), np.sin(th)
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    xo, yo = xx - pad - cx, yy - pad - cy
    sx = xo * c - yo * s + cx          # inverse of the anticlockwise turn
    sy = xo * s + yo * c + cy
    ix, iy = np.round(sx).astype(int), np.round(sy).astype(int)
    ok = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
    out = np.zeros((H, W) + img.shape[2:], img.dtype)
    out[ok] = img[iy[ok], ix[ok]]

    def fwd(px, py):
        dx, dy = px - cx, py - cy
        return dx * c + dy * s + cx + pad, -dx * s + dy * c + cy + pad
    return out, fwd


def largest(m):
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if not n:
        return m
    size = ndimage.sum(m, lab, np.arange(1, n + 1))
    return lab == (np.argmax(size) + 1)


def crop(img):
    ys, xs = np.nonzero(img[..., 3] > 0)
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1], xs.min(), ys.min()


def line(img, p0, p1, col):
    x0, y0 = int(round(p0[0])), int(round(p0[1]))
    x1, y1 = int(round(p1[0])), int(round(p1[1]))
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = int(round(x0 + (x1 - x0) * i / n))
        y = int(round(y0 + (y1 - y0) * i / n))
        if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
            img[y, x] = (*col, 255)


def paste(dst, src, ox, oy, under=False):
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    y0, x0 = max(0, oy), max(0, ox)
    y1, x1 = min(H, oy + h), min(W, ox + w)
    if y1 <= y0 or x1 <= x0:
        return
    s = src[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    m = s[..., 3] > 0
    if under:
        m &= dst[y0:y1, x0:x1, 3] == 0
    dst[y0:y1, x0:x1][m] = s[m]


# ---------------------------------------------------------------- the source frames

def lean_of(img):
    """Sideways lean of a drawing (degrees, + = envelope right of the basket)."""
    a = img[..., 3] > 0
    rgb = img[..., :3]
    ys = np.flatnonzero(a.any(1))
    y0, y1 = ys.min(), ys.max() + 1
    env = a & envelope_col(rgb)
    env[y0 + int((y1 - y0) * 0.6):] = False
    bas = a & wicker(rgb)
    bas[:y0 + int((y1 - y0) * 0.6)] = False
    bas = largest(bas)
    ey, ex = np.nonzero(env)
    by, bx = np.nonzero(bas)
    return np.degrees(np.arctan2(ex.mean() - bx.mean(), by.mean() - ey.mean())), (ex.mean(), ey.mean())


def envelope_part(img):
    """The envelope of one source frame, turned upright: (RGBA crop, width, ring box
    (x0, x1, y) in the crop, distance ring -> top of the wicker in source px)."""
    lean, (ecx, ecy) = lean_of(img)
    up, fwd = rotate(img, lean, ecx, ecy)
    a = up[..., 3] > 0
    solid = ndimage.binary_opening(a, structure=np.ones((3, 3)), iterations=2)
    ys = np.flatnonzero(solid.any(1))
    top = ys.min()
    env = solid.copy()
    env[top + int((ys.max() - top) * 0.62):] = False
    env = largest(env)
    widths = np.array([np.ptp(np.flatnonzero(r)) + 1 if r.any() else 0 for r in env])
    wmax = widths.max()
    yw = int(np.argmax(widths))
    ring = yw
    for y in range(yw, len(widths)):
        if widths[y] < 0.22 * wmax:
            break
        ring = y
    keep = ndimage.binary_dilation(env, iterations=2) & a
    keep[ring + 1:] = False
    part = up.copy()
    part[~keep] = 0
    xs = np.flatnonzero(keep[ring - 2:ring + 1].any(0))
    # wicker top below the ring, in the upright drawing
    wk = a & wicker(up[..., :3])
    wk[:ring + 4] = False
    wk = largest(wk)
    wy = np.flatnonzero(wk.any(1))
    rows = [y for y in wy if wk[y].sum() >= 0.6 * wk.sum(1).max()]
    drop = (rows[0] if rows else wy.min()) - ring
    c, ox, oy = crop(part)
    return c, wmax, (xs.min() - ox, xs.max() - ox, ring - oy), drop


def basket_part(img):
    """The wicker basket (with its sandbags) of an upright source drawing, cut below the
    painted crew: (RGBA crop, wicker width, rim row in the crop)."""
    up = img
    a = up[..., 3] > 0
    wk = a & wicker(up[..., :3])
    ys = np.flatnonzero(a.any(1))
    wk[:ys.min() + int((ys.max() - ys.min()) * 0.6)] = False
    wk = largest(ndimage.binary_closing(wk, iterations=2) & a)
    wy, wx = np.nonzero(wk)
    x0, x1 = wx.min(), wx.max()
    cx0, cx1 = x0 + (x1 - x0) // 4, x1 - (x1 - x0) // 4
    frac = (a & wicker(up[..., :3]))[:, cx0:cx1].mean(1)
    rim = next(y for y in range(wy.min(), wy.max()) if frac[y] >= 0.4 and frac[y + 1] >= 0.4 and frac[y + 2] >= 0.4)
    solid = ndimage.binary_opening(a, structure=np.ones((3, 3)))
    body = solid.copy()
    body[:rim] = False
    body = largest(body)
    keep = ndimage.binary_dilation(body, iterations=1) & a
    keep[:rim] = False
    part = up.copy()
    part[~keep] = 0
    # wicker width on the rows just under the rim (sandbags excluded)
    wrows = (a & wicker(up[..., :3]))[rim:rim + 12]
    width = np.median([np.ptp(np.flatnonzero(r)) + 1 for r in wrows if r.sum() > 3])
    c, ox, oy = crop(part)
    return c, width, rim - oy


def to_game(img, scale, bgc):
    return R.to_game(img.astype(np.int32), scale, bgc)[0]


# ---------------------------------------------------------------- the clean basket

class Basket:
    """Game-scale basket of one direction with its open top repainted.
    body: full basket image; front: the front wall and rim only; geometry of the rim
    ellipse (cx, cy, a, b) in the image."""

    def __init__(self, img, rim):
        img = img[rim:]
        h, w = img.shape[:2]
        # the sheet paints the crew over the upper part of the front wall: grow the wall
        # back up by repeating the weave of the rows below, inside the top row's outline
        xs = np.flatnonzero(img[..., 3].any(0))
        ww = xs.max() - xs.min() + 1
        ext = int(round(ww * 0.36))
        top_pad = ext + 8
        full = np.zeros((h + top_pad, w, 4), np.uint8)
        full[top_pad:] = img
        span = np.flatnonzero(img[0, :, 3] > 0)
        x0, x1 = span.min(), span.max()
        period = max(3, min(h - 2, ext))
        for k in range(ext):
            y = top_pad - ext + k
            srow = img[1 + (k % period)]
            for x in range(x0, x1 + 1):
                full[y, x] = srow[x] if srow[x, 3] > 0 else img[0, x]
            full[y, x0, :3] = (34, 20, 12)
            full[y, x1, :3] = (34, 20, 12)
            full[y, x0, 3] = full[y, x1, 3] = 255
        rim = top_pad - ext
        self.ext = ext
        a_ = full[..., 3] > 0
        rgb = full[..., :3].astype(int)
        wk = a_ & wicker(rgb)
        rows = wk[rim:rim + 4]
        xs = np.flatnonzero(rows.any(0))
        x0, x1 = xs.min(), xs.max()
        cx = (x0 + x1) / 2.0
        ra = (x1 - x0) / 2.0 + 0.5
        rb = max(2.0, round(ra * 0.36))
        cy = rim + 0.5
        # palette from the wicker itself
        wc = rgb[wk]
        lum = wc.sum(1)
        light = np.median(wc[lum >= np.percentile(lum, 80)], 0)
        mid = np.median(wc, 0)
        dark = np.median(wc[lum <= np.percentile(lum, 20)], 0)
        outline = (34, 20, 12)
        inner = np.clip(mid * 0.42, 0, 255)
        inner_d = np.clip(mid * 0.28, 0, 255)
        yy, xx = np.mgrid[0:full.shape[0], 0:full.shape[1]]
        u = (xx + 0.5 - cx) / ra
        v = (yy + 0.5 - cy) / rb
        inside = u * u + v * v <= 1.0
        outer =((xx + 0.5 - cx) / (ra + 1.0)) ** 2 + ((yy + 0.5 - cy) / (rb + 1.0)) ** 2 <= 1.0
        ring_band = outer & ~inside
        front_half = yy + 0.5 >= cy
        out = full.copy()
        # everything above the front wall and inside the rim is repainted
        out[(yy < rim) & ~outer] = 0
        # inside of the far wall: dark wicker, darker low down, a weave of lighter rows
        ins = inside
        t = np.clip((yy + 0.5 - (cy - rb)) / (2 * rb), 0, 1)
        col = inner[None, None] * (1 - t[..., None]) + inner_d[None, None] * t[..., None]
        weave = ((xx + (yy // 2)) % 3 == 0) & ((yy % 2) == 0)
        col = np.where(weave[..., None], col * 1.25, col)
        out[ins, :3] = np.clip(col[ins], 0, 255).astype(np.uint8)
        out[ins, 3] = 255
        # back rim: a lit band; front rim: a lighter, thicker band
        back = ring_band & ~front_half
        out[back, :3] = np.clip(mid * 0.85, 0, 255).astype(np.uint8)
        out[back, 3] = 255
        # the outline just outside the back rim
        edge = (((xx + 0.5 - cx) / (ra + 2.0)) ** 2 + ((yy + 0.5 - cy) / (rb + 2.0)) ** 2 <= 1.0) & ~outer & (yy < rim)
        out[edge, :3] = outline
        out[edge, 3] = 255
        frim = ring_band & front_half
        # the front rim one more pixel thick: the band and the row inside it
        ins_front = inside & front_half & ~(((xx + 0.5 - cx) / ra) ** 2 + ((yy + 1.5 - cy) / rb) ** 2 <= 1.0)
        frim2 = frim | ins_front
        out[frim2, :3] = light.astype(np.uint8)
        out[frim2, 3] = 255
        out[frim, :3] = np.clip(light * 0.8, 0, 255).astype(np.uint8)
        # the rim's ends where it meets the side walls: outline
        for sx in (int(np.floor(cx - ra - 1)), int(np.floor(cx + ra))):
            for y in range(int(cy - 1), int(cy + 2)):
                if 0 <= sx < out.shape[1] and out[y, sx, 3] > 0:
                    out[y, sx, :3] = outline
        self.body = out
        # front overlay: the front wall below the rim line, the front rim, sandbags
        fm = (out[..., 3] > 0) & ((yy + 0.5 > cy + rb * np.sqrt(np.clip(1 - ((xx + 0.5 - cx) / ra) ** 2, 0, 1)) - 1.6) | ~outer)
        fm &= yy >= int(cy) - 1
        fm &= ~(ins & ~frim2)
        front = np.zeros_like(out)
        front[fm] = out[fm]
        self.front = front
        self.cx, self.cy, self.a, self.b = cx, cy, ra, rb
        ys = np.flatnonzero(img[..., 3].any(1))
        self.bottom = top_pad + ys.max() + 1
        bx = np.flatnonzero(img[ys.max() - 3:ys.max() + 1, :, 3].any(0))
        self.bx = (bx.min() + bx.max() + 1) / 2.0
        self.colours = (light, mid, dark)


def despeckle_red(img):
    """Lone team-red pixels left on the wicker (a crewman's cuff) take a neighbour's colour."""
    out = img.copy()
    rgb = out[..., :3].astype(int)
    red = (out[..., 3] > 0) & (rgb[..., 0] >= 140) & (rgb[..., 1] < 40) & (rgb[..., 2] < 40)
    red |= (out[..., 3] > 0) & (rgb[..., 0] == TEAM_DARK[0]) & (rgb[..., 1] == 0) & (rgb[..., 2] == 0)
    for y, x in zip(*np.nonzero(red)):
        nb = [out[yy, xx] for yy, xx in ((y, x - 1), (y, x + 1), (y - 1, x), (y + 1, x))
              if 0 <= yy < out.shape[0] and 0 <= xx < out.shape[1] and out[yy, xx, 3] > 0
              and not red[yy, xx]]
        if nb:
            out[y, x] = nb[0]
    return out


# ---------------------------------------------------------------- body frames

CAN_W, CAN_H, CAN_AX, CAN_AY = 160, 200, 80, 150     # work canvas and its anchor


class Direction:
    """Everything one direction's body frames share: the clean basket, scales, rope length."""

    def __init__(self, fr, bgc, d):
        self.d, self.r, self.bgc = d, ROW_OF[d], bgc
        idle = fr[(self.r, "idle")]
        self.drift_src = fr[(self.r, "drift")]
        self.idle_src = idle
        # the basket from the idle drawing that hangs straightest
        best = min(idle, key=lambda f: abs(lean_of(f["img"])[0]))
        env_w = envelope_part(best["img"])[1]
        s = ENV_W / env_w
        c, wsrc, rim = basket_part(best["img"])
        self.basket = Basket(despeckle_red(to_game(c, s, bgc)), int(round(rim * s)))
        self.basket_w = wsrc * s                       # wicker width in game px
        drops = []
        for f in idle:
            e = envelope_part(f["img"])
            drops.append(e[3] * ENV_W / e[1])
        # the rim drawn above the wicker top: the ropes are that much shorter
        self.rope = float(np.median(drops)) - self.basket.ext
        bk = self.basket
        self.ox = int(round(CAN_AX - bk.bx))
        self.oy = CAN_AY - bk.bottom
        self.rim = (self.ox + bk.cx, self.oy + bk.cy)
        # the two gunner slots: A back-left, B front-right (waist on the rim line)
        self.slots = [(self.rim[0] - bk.a * 0.42, self.rim[1] - 0.5),
                      (self.rim[0] + bk.a * 0.42, self.rim[1] + 1.5)]

    def theta(self, lean, anim):
        k = LEAN_K if anim == "drift" else 0.3
        if self.d in ("s", "n"):
            return -lean * k
        return abs(lean) * k          # side views: the envelope trails up-left, basket leads

    def frame(self, src, anim):
        img = src["img"]
        lean, _ = lean_of(img)
        th = self.theta(lean, anim)
        env, wmax, (rx0, rx1, ry), _ = envelope_part(img)
        s = ENV_W / wmax
        rcx = (rx0 + rx1) / 2.0
        turned, fwd = rotate(env, th, rcx, ry)
        g = to_game(turned, s, self.bgc)
        pts = [fwd(x, ry) for x in (rx0, rx0 + (rx1 - rx0) * 0.3, rx0 + (rx1 - rx0) * 0.7, rx1)]
        pts = [(px * s, py * s) for px, py in pts]
        rc = fwd(rcx, ry)
        rc = (rc[0] * s, rc[1] * s)
        t = np.deg2rad(th)
        tx = self.rim[0] - self.rope * np.sin(t)
        ty = self.rim[1] - self.rope * np.cos(t)
        ex, ey = int(round(tx - rc[0])), int(round(ty - rc[1]))
        can = np.zeros((CAN_H, CAN_W, 4), np.uint8)
        bk = self.basket
        # ropes behind the basket mouth first, then the basket, envelope, outer ropes
        back_l = (self.rim[0] - bk.a * 0.5, self.rim[1] - bk.b * 0.85)
        back_r = (self.rim[0] + bk.a * 0.5, self.rim[1] - bk.b * 0.85)
        P = [(px + ex, py + ey) for px, py in pts]
        line(can, P[1], back_l, ROPE_DARK)
        line(can, P[2], back_r, ROPE_DARK)
        paste(can, bk.body, self.ox, self.oy)
        line(can, P[0], (self.rim[0] - bk.a + 0.3, self.rim[1]), ROPE_COL)
        line(can, P[3], (self.rim[0] + bk.a - 0.7, self.rim[1]), ROPE_COL)
        paste(can, g, ex, ey)
        front = np.zeros_like(can)
        paste(front, bk.front, self.ox, self.oy)
        return can, front


# ---------------------------------------------------------------- the gunners

MUSK = "assets/units/musketeer"
MCW = 90                # musketeer cell width
DOWN = 28.0             # degrees the gunner leans to shoot down (the aim-up frames use 28 up)
KICK = 9.0              # recoil: the musket kicks back up this much


def musk_frames(anim, d):
    a = np.array(Image.open(f"{MUSK}/{anim}_{d}.png").convert("RGBA"))
    pad = 0 if a.shape[0] == 36 else a.shape[0] - 36     # aim-up sheets are taller on top
    return [a[pad:, i * MCW:(i + 1) * MCW].copy() if pad == 0 else a[:, i * MCW:(i + 1) * MCW].copy()
            for i in range(a.shape[1] // MCW)], pad


def effects_mask(f):
    """Muzzle flash and powder smoke of a musketeer frame."""
    rgb = f[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = f[..., 3] > 0
    flash = a & (r >= 200) & (g >= 90) & (b <= 150) & (r - b >= 80)
    smoke = a & (np.abs(r - g) <= 18) & (np.abs(g - b) <= 22) & (r >= 95)
    return flash, smoke


def body_box(f):
    op = f[..., 3] > 0
    core = ndimage.binary_opening(op, structure=np.ones((3, 3)))
    core = largest(core)
    ys, xs = np.nonzero(core)
    return xs.min(), xs.max(), ys.min(), ys.max(), xs.mean()


def turn_upper(f, deg, px, py):
    """The rows above py turned by deg (anticlockwise on screen) about (px, py)."""
    up = f.copy()
    up[int(py) + 1:] = 0
    t, _ = rotate(up, deg, px, py, pad=0)
    out = f.copy()
    out[:int(py) + 1] = 0
    m = t[..., 3] > 0
    out[m] = t[m]
    return out


class Gunners:
    """Waist-up musketeer frames for one direction, all on the musketeer's own cell
    (90 wide, the waist at row WAIST + top padding)."""
    PAD = 30          # room above the head for the musket and smoke when firing up

    def __init__(self, d):
        self.d = d
        idle, _ = musk_frames("idle", d)
        b = body_box(idle[0])
        self.y0, self.y1, self.bx = b[2], b[3], b[4]
        self.waist = int(round(self.y0 + (self.y1 - self.y0) * 0.56))
        self.px = int(round(self.bx))
        self.anims = {
            "idle": [self.cut(f) for f in idle[:2]],
            "down": self.down(),
            "up": self.up(),
        }

    def padded(self, f, pad_top=None):
        P = self.PAD
        out = np.zeros((36 + P + 20, MCW, 4), np.uint8)
        h = f.shape[0]
        out[P + 36 - h:P + 36] = f
        return out

    def cut(self, f, keep_below=2):
        """Padded frame with everything under the waist (+ keep_below rows) removed."""
        g = self.padded(f) if f.shape[0] == 36 else self.padded_tall(f)
        g[self.PAD + self.waist + keep_below + 1:] = 0
        return g

    def padded_tall(self, f):
        P = self.PAD
        out = np.zeros((36 + P + 20, MCW, 4), np.uint8)
        h = f.shape[0]
        top = P + 36 - h
        if top < 0:
            f = f[-top:]
            top = 0
        out[top:top + f.shape[0]] = f
        return out

    def fire_frame(self, frames):
        """The fire frame with the most flash and smoke in it."""
        best = max(frames, key=lambda f: sum(m.sum() for m in effects_mask(f)))
        return best

    def recoil(self, aim, fire, base_deg):
        """The shot just gone: musket kicked up, the gunner rocked back a pixel, the
        smoke from the shot drifting on."""
        P, w = self.PAD, self.waist
        g = turn_upper(aim, KICK, self.px, P + w) if base_deg is not None else aim.copy()
        g = np.roll(g, -1, 1)
        g[P + w + 3:] = 0
        _, smoke = effects_mask(fire)
        sm = fire.copy()
        sm[~smoke] = 0
        sm = np.roll(np.roll(sm, -1, 0), 1, 1)
        m = (sm[..., 3] > 0) & (g[..., 3] == 0)
        g[m] = sm[m]
        return g

    def down(self):
        P, w = self.PAD, self.waist
        if self.d == "n":
            return self.down_n()
        aims, _ = musk_frames("aim", self.d)
        fires, _ = musk_frames("fire", self.d)
        aim = self.cut(aims[-1], 3)
        fire = self.cut(self.fire_frame(fires), 3)
        aim_d = turn_upper(aim, -DOWN, self.px, P + w)
        fire_d = turn_upper(fire, -DOWN, self.px, P + w)
        rec = self.recoil(aim_d, fire_d, -DOWN)
        return [self.clip(f) for f in (aim_d, fire_d, rec)]

    def up(self):
        P, w = self.PAD, self.waist
        aims, pad = musk_frames("aimup", self.d)
        fires, _ = musk_frames("fireup", self.d)
        aim = self.cut(aims[-1], 3)
        fire = self.cut(self.fire_frame(fires), 3)
        rec = self.recoil(aim, fire, 0.0 if self.d != "n" else None)
        if self.d == "n":
            rec = aim.copy()
            _, smoke = effects_mask(fire)
            sm = fire.copy()
            sm[~smoke] = 0
            sm = np.roll(sm, -2, 0)
            m = (sm[..., 3] > 0) & (rec[..., 3] == 0)
            rec[m] = sm[m]
            rec = np.roll(rec, 1, 0)
        return [self.clip(f) for f in (aim, fire, rec)]

    def down_n(self):
        """Seen from behind: the musket comes out at his right side, pointing down past
        the basket, with the flash and smoke borrowed from the side view's shot."""
        P, w = self.PAD, self.waist
        aims, _ = musk_frames("aim", "n")
        base = self.cut(aims[-1], 3)
        # the barrel standing up over his head goes: keep the solid body only
        core = largest(ndimage.binary_opening(base[..., 3] > 0, structure=np.ones((3, 3))))
        body = ndimage.binary_dilation(core, iterations=1) & (base[..., 3] > 0)
        base[~body] = 0
        # leaning over the rim: the head and shoulders a pixel lower
        top = base[:P + w].copy()
        base[:P + w] = 0
        sh = np.zeros_like(base)
        sh[1:P + w + 1] = top
        m = sh[..., 3] > 0
        base[m] = sh[m]
        bx0, bx1, by0, by1, _ = body_box(base)
        sx, sy = bx1 - 1, by0 + (P + w - by0) * 0.45
        ang = np.deg2rad(-25.0)
        dvec = np.array([np.cos(ang), -np.sin(ang)])
        L = 12
        aim = base.copy()
        wood, dark, steel = (112, 70, 36), (54, 34, 18), (96, 96, 104)
        for i in range(L * 2 + 1):
            t = i / 2.0
            p = np.array([sx, sy]) + dvec * t
            col = steel if t > L * 0.55 else wood
            x, y = int(round(p[0])), int(round(p[1]))
            if aim[y, x, 3] == 0 or t > 2:
                aim[y, x] = (*col, 255)
            if aim[y + 1, x, 3] == 0:
                aim[y + 1, x] = (*dark, 255)
        muzzle = np.array([sx, sy]) + dvec * (L + 0.5)
        # the shot of the east view, turned to this barrel
        fires, _ = musk_frames("fire", "e")
        ef = self.fire_frame(fires)
        flash, smoke = effects_mask(ef)
        fx = np.nonzero(flash)[1].min() if flash.any() else 60
        fy = int(np.median(np.nonzero(flash)[0])) if flash.any() else 20
        core = largest(ndimage.binary_opening(ef[..., 3] > 0, structure=np.ones((3, 3))))
        eff = ef.copy()
        keep = (ef[..., 3] > 0) & ~core
        keep[:, :fx - 1] = False
        eff[~keep] = 0
        eff, fwd = rotate(eff, -25.0, fx, fy, pad=20)
        mx, my = fwd(fx, fy)
        fire = aim.copy()
        paste(fire, eff, int(round(muzzle[0] - mx)), int(round(muzzle[1] - my)))
        smoke_only = eff.copy()
        fl, _ = effects_mask(eff)
        smoke_only[fl] = 0
        rec = turn_upper(aim, 8.0, self.px, P + w)
        rec = np.roll(rec, -1, 1)
        rec[P + w + 3:] = 0
        paste(rec, smoke_only, int(round(muzzle[0] - mx)) + 1, int(round(muzzle[1] - my)) - 1, under=True)
        return [self.clip(f) for f in (aim, fire, rec)]

    def clip(self, f):
        """Smoke may hang lower than the waist; nothing of the body does."""
        return f
