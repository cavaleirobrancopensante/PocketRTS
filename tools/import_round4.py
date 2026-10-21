"""Round 4 art: the Clockwork Stormcaller, the Crown Cuirassier, the Brood Spore Mother
and the Storm / Miasma spell effects.

Sources (generated sheets on a flat slate background):
  art/clockwork/stormcaller.png   rows = directions, groups walk/idle/attack/cast/death
  art/crown/cuirassier.png        rows = directions, groups idle/gallop/slash/thrust/death
  art/brood/spore_mother.png      rows = directions, groups walk/idle/fire/root/death
  art/world/storm_and_miasma.png  6 rows: storm in/loop/out, miasma in/loop/out

The sheets only roughly follow the five directions (s, se, e, ne, n): several rows or
groups are drawn facing the wrong way. widen (in UNITS): per-row horizontal stretch for
rows drawn too narrow (the cuirassier's side-view horse). The PLANS table below picks, for every animation
and direction, which source frames to use (row, group, index, mirrored) - see the notes
there for what was dropped or rebuilt and why.

Every unit frame is cut out (shadow-aware slate mask), its glow (zaps, bolts, gas) is
un-blended from the slate so no slate fringe stays, shrunk to game size with a box
filter, team reds snapped to the key colours, specks and slate edge pixels removed, and
placed on one shared cell per unit with the feet on one anchor point.

Output:
  assets/units/<kind>/<anim>_<dir>.png   horizontal strips, one cell per frame
  assets/icons/<kind>.png                64x64 button icons
  assets/effects/{storm,miasma}_{in,loop,out}.png
  the "stormcaller", "cuirassier" and "spore_mother" entries of UNITS and the storm_* /
  miasma_* entries of EFFECTS in scripts/art_data.gd (added or replaced in place; nothing
  else in the file is touched)

Usage (from the repo root): python3 tools/import_round4.py [--debug DIR] [--contact DIR]
       [--only cuirassier]   (rebuild only the listed units, no effects)
(--contact writes x3 contact sheets on grass green; --debug also dumps the cut frames)
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load, make_icon  # noqa: E402
from import_cannon2 import bg_mask, clean, defringe, shrink, snap_team  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
DEBUG = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
# --only KIND[,KIND]: rebuild just these units (no effects); art_data.gd keeps the others
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else None


# ---------------------------------------------------------------- sheets

# rows: y guesses of the empty gaps between the five rows (refined per column strip).
# groups: animation groups left to right; counts[row]: frames per group;
# panels[row]: x boundaries of the groups.
SHEETS = {
    "stormcaller": dict(
        path="art/clockwork/stormcaller.png", rows=[210, 400, 590, 778],
        groups=["walk", "idle", "attack", "cast", "death"],
        counts=[[5, 3, 3, 4, 3]] * 5,
        panels=[[0, 390, 618, 884, 1212, 1536]] * 5),
    "cuirassier": dict(
        path="art/crown/cuirassier.png", rows=[240, 415, 595, 775],
        groups=["idle", "walk", "slash", "thrust", "death"],
        counts=[[4, 8, 3, 2, 4]] * 5,
        panels=[[0, 278, 752, 997, 1208, 1536]] * 5),
    "spore_mother": dict(
        path="art/brood/spore_mother.png", rows=[208, 390, 553, 742],
        groups=["walk", "idle", "fire", "root", "death"],
        counts=[[4, 4, 4, 6, 3]] + [[4, 3, 4, 6, 3]] * 4,
        panels=[[0, 282, 525, 791, 1274, 1536],
                [0, 289, 505, 790, 1288, 1536],
                [0, 303, 492, 786, 1289, 1536],
                [0, 292, 495, 786, 1284, 1536],
                [0, 296, 505, 779, 1283, 1536]]),
}


# Pieces painted out of single frames: (kind, row, group, index) -> sheet rectangles.
ERASE = {
    # SE slash 2: a carbine held out to the left (the cuirassier is melee only)
    ("cuirassier", 1, "slash", 2): [(870, 298, 913, 322)],
}


def row_bands(fg, guesses, strip=32, reach=34):
    """Masks of the five rows. The cut between two rows is, per vertical strip of the
    sheet, the middle of the longest empty (or emptiest) run of lines near the guess -
    the casting bolts and gas clouds reach up close to the row above."""
    h, w = fg.shape
    yy = np.arange(h)[:, None]
    cuts = []
    for g in guesses:
        c = np.zeros(w, int)
        for x0 in range(0, w, strip):
            sub = fg[g - reach:g + reach, x0:x0 + strip].sum(1)
            low = sub <= sub.min()
            best, bl = g, -1
            y = 0
            while y < len(low):
                if low[y]:
                    s = y
                    while y < len(low) and low[y]:
                        y += 1
                    if y - s > bl:
                        bl, best = y - s, g - reach + (s + y) // 2
                else:
                    y += 1
            c[x0:x0 + strip] = best
        cuts.append(c)
    bands, top = [], np.zeros(w, int)
    for k in range(len(guesses) + 1):
        bot = cuts[k] if k < len(guesses) else np.full(w, h)
        bands.append((yy >= top[None]) & (yy < bot[None]))
        top = bot
    return bands


def column_cuts(m, a, b, n):
    """x positions splitting columns a..b of mask m into n frames at the emptiest columns."""
    cols = m[:, a:b].sum(0).astype(float)
    cuts = [a]
    for k in range(1, n):
        g = (b - a) * k / n
        lo, hi = int(g - (b - a) / n * 0.35), int(g + (b - a) / n * 0.35)
        lo = max(lo, cuts[-1] - a + 8)
        seg = cols[lo:hi]
        best = np.flatnonzero(seg <= seg.min() + 0.5)
        c = lo + best[np.argmin(np.abs(best + lo - g))]
        cuts.append(a + int(c))
    cuts.append(b)
    return cuts


def extract(kind):
    """{(row, group): [frame]} with frame = source RGBA crop (alpha = mask) and its
    sheet position. Every connected piece goes whole to the frame holding most of it,
    unless it really spans two frames (figures drawn touching), then it is cut."""
    cfg = SHEETS[kind]
    px = load(cfg["path"])
    bg, bgc = bg_mask(px)
    fg = ~bg
    # crumbs of the background noise
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 4)[lab - 1] & (lab > 0))
    bands = row_bands(fg, cfg["rows"])
    out = {}
    for r, band in enumerate(bands):
        m = fg & band
        cuts = []
        for g, cnt in enumerate(cfg["counts"][r]):
            a, b = cfg["panels"][r][g], cfg["panels"][r][g + 1]
            cc = column_cuts(m, a, b, cnt)
            cuts += cc[:-1]
        cuts.append(px.shape[1])
        cuts = np.array(cuts)
        slot_of_col = np.searchsorted(cuts, np.arange(px.shape[1]), side="right") - 1
        lab, n = ndimage.label(m, structure=np.ones((3, 3)))
        slots = np.full(m.shape, -1, int)
        ys, xs = np.nonzero(m)
        ls = lab[ys, xs]
        cs = slot_of_col[xs]
        nslot = len(cuts) - 1
        mass = np.zeros((n + 1, nslot))
        np.add.at(mass, (ls, cs), 1)
        whole = mass.max(1) >= 0.8 * mass.sum(1)
        own = mass.argmax(1)
        slots[ys, xs] = np.where(whole[ls], own[ls], cs)
        k = 0
        for g, cnt in enumerate(cfg["counts"][r]):
            for i in range(cnt):
                fm = slots == k
                yy, xx = np.nonzero(fm)
                y0, y1, x0, x1 = yy.min(), yy.max() + 1, xx.min(), xx.max() + 1
                for ex0, ey0, ex1, ey1 in ERASE.get((kind, r, cfg["groups"][g], i), []):
                    fm[ey0:ey1, ex0:ex1] = False
                lab2, n2 = ndimage.label(fm, structure=np.ones((3, 3)))
                if n2 > 1:     # crumbs left over from an erase
                    sz = ndimage.sum(fm, lab2, np.arange(1, n2 + 1))
                    fm &= ~((sz < 15)[lab2 - 1] & (lab2 > 0))
                yy, xx = np.nonzero(fm)
                y0, y1, x0, x1 = yy.min(), yy.max() + 1, xx.min(), xx.max() + 1
                img = px[y0:y1, x0:x1].copy()
                img[..., 3] = np.where(fm[y0:y1, x0:x1], 255, 0)
                img[~fm[y0:y1, x0:x1]] = 0
                out.setdefault((r, cfg["groups"][g]), []).append(
                    dict(img=img.astype(np.uint8), x0=x0, y0=y0, x1=x1, y1=y1))
                k += 1
    return out, bgc


# ---------------------------------------------------------------- frames to game scale

def glow_kind(rgb, kind):
    """Pixels of painted light (zaps, bolts, gas) - candidates for un-blending."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if kind == "blue":
        return (b >= r + 30) & (b >= g + 5) & (b >= 95)
    if kind == "green":
        return (g >= r + 8) & (g >= b + 35) & (g >= 90)
    return np.zeros(rgb.shape[:2], bool)


def body_hull(body):
    """Orthogonally convex hull of the solid body: inside it on its row AND its column.
    Sacs and coils on the silhouette stay body; light beyond hands or above heads doesn't."""
    body = ndimage.binary_opening(body, iterations=1)
    lab, n = ndimage.label(body, structure=np.ones((3, 3)))
    if n:
        size = ndimage.sum(body, lab, np.arange(1, n + 1))
        body &= ((size >= max(30, size.max() * 0.02))[lab - 1]) & (lab > 0)
    h, w = body.shape
    rows = np.zeros_like(body)
    cols = np.zeros_like(body)
    for y in np.flatnonzero(body.any(1)):
        xs = np.flatnonzero(body[y])
        rows[y, xs[0]:xs[-1] + 1] = True
    for x in np.flatnonzero(body.any(0)):
        ys = np.flatnonzero(body[:, x])
        cols[ys[0]:ys[-1] + 1, x] = True
    return rows & cols


def unblend(img, bgc, glow):
    """Float RGBA (alpha 0..1). Painted light outside the solid body is un-blended from
    the slate: alpha = the least that explains the pixel as light over the background,
    colour solved from pixel = bg*(1-a) + colour*a. Body pixels stay opaque."""
    rgb = img[..., :3].astype(float)
    a = (img[..., 3] > 0).astype(float)
    if not glow:
        return np.dstack([rgb, a]), np.zeros(a.shape, bool)
    fg = a > 0
    cand = fg & glow_kind(rgb, glow)
    hull = body_hull(fg & ~cand)
    glow_m = fg & ~hull & ndimage.binary_dilation(cand, iterations=12)
    au = np.clip((rgb - bgc) / (255.0 - bgc), 0, None).max(-1).clip(0, 1)
    col = np.clip((rgb - bgc * (1 - au[..., None])) / np.maximum(au, 1e-6)[..., None], 0, 255)
    rgb = np.where(glow_m[..., None], col, rgb)
    a = np.where(glow_m, au, a)
    return np.dstack([rgb, a]), glow_m


def deslate(img, bgc, iters=6, kmin=0.08):
    """Like defringe, but also eats darker slate (the dug pit under the rooted Spore
    Mother) from the outside in."""
    out = img.copy()
    for _ in range(iters):
        a = out[..., 3] > 0
        edge = a & ~ndimage.binary_erosion(a, structure=np.ones((3, 3)))
        rgb = out[..., :3].astype(float)
        k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
        resid = np.abs(rgb - k[..., None] * bgc).max(-1)
        cast = (rgb[..., 2] - rgb[..., 0]) >= 0.5 * (bgc[2] - bgc[0]) * k
        slate = edge & (k >= kmin) & (k <= 1.25) & (resid <= 6 + 5 * k) & cast
        if not slate.any():
            break
        out[slate] = 0
    # enclosed slate (the pit between the roots, slate showing through the gas)
    a = out[..., 3] > 0
    rgb = out[..., :3].astype(float)
    k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
    resid = np.abs(rgb - k[..., None] * bgc).max(-1)
    cast = (rgb[..., 2] - rgb[..., 0]) >= 0.5 * (bgc[2] - bgc[0]) * k
    slate = a & (k >= kmin) & (k <= 1.25) & (resid <= 6 + 5 * k) & cast
    lab, n = ndimage.label(slate)
    if n:
        size = ndimage.sum(slate, lab, np.arange(1, n + 1))
        out[(size >= 3)[lab - 1] & (lab > 0)] = 0
    return out


def to_game(img, scale, bgc, glow=None, glow_cut=0.2, mirror=False, sx=1.0):
    """Source frame -> game-size RGBA uint8 plus its glow mask. The body gets a hard
    alpha edge; painted light keeps three alpha steps (95/170/255). sx: extra horizontal
    stretch, applied in the same box-filter downscale (so it stays crisp)."""
    f, gm = unblend(img, bgc, glow)
    h, w = f.shape[:2]
    nw, nh = max(1, int(round(w * scale * sx))), max(1, int(round(h * scale)))

    def box(arr):
        return np.array(Image.fromarray(arr.astype(np.float32), "F").resize((nw, nh), Image.BOX))
    a = f[..., 3]
    al = box(a)
    pre = [box(f[..., c] * a) for c in range(3)]
    gl = box(gm.astype(float) * a) / np.maximum(al, 1e-6)       # share of glow in each pixel
    rgb = np.dstack(pre) / np.maximum(al, 1e-6)[..., None]
    isg = gl > 0.5
    on = np.where(isg, al >= glow_cut, al >= 0.5)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).round()
    # body: hard edge; painted light: three alpha steps so it glows without slate fringe
    ga = np.select([al >= 0.75, al >= 0.45], [255, 170], 95)
    out[..., 3] = np.where(on, np.where(isg, ga, 255), 0)
    out[~on] = 0
    glow_small = on & (gl > 0.5)
    body = out.copy()
    body[glow_small] = 0
    body = snap_team(body)
    out[~glow_small] = body[~glow_small]
    out[glow_small] = snap_team(out, effect=True)[glow_small]
    out = deslate(out, bgc) if glow == "green" else defringe(out, bgc)
    out = clean(out, min_size=4, keep_near=1)
    glow_small &= out[..., 3] > 0
    if mirror:
        out, glow_small = out[:, ::-1].copy(), glow_small[:, ::-1].copy()
    return out, glow_small


def on_green(img, k=3):
    h, w = img.shape[:2]
    bg = Image.new("RGBA", (w, h), (0x55, 0x8B, 0x45, 255))
    bg.alpha_composite(Image.fromarray(img, "RGBA"))
    return bg.resize((w * k, h * k), Image.NEAREST)


def dump_source(kind, frames, bgc):
    """Every source frame at game scale, x3 on green, one line per (row, group)."""
    cfg = UNITS[kind]
    k = 3
    lines = []
    for r in range(5):
        ims = []
        for g in SHEETS[kind]["groups"]:
            lst = frames[(r, g)]
            ims += [(f"{g[0]}{i}", on_green(to_game(f["img"], cfg["scale"], bgc, cfg.get("glow"))[0], k))
                    for i, f in enumerate(lst)]
        lines.append((f"r{r}", ims))
    W = max(sum(i.width + 6 for _, i in ims) + 30 for _, ims in lines)
    H = sum(max(i.height for _, i in ims) + 6 for _, ims in lines)
    sheet = Image.new("RGB", (W, H), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    y = 0
    for label, ims in lines:
        d.text((4, y + 4), label, fill=(255, 255, 255))
        x = 30
        for lab, im in ims:
            sheet.paste(im, (x, y))
            d.text((x + 2, y + 2), lab, fill=(255, 255, 0))
            x += im.width + 6
        y += max(i.height for _, i in ims) + 6
    sheet.save(os.path.join(DEBUG, f"src_{kind}.png"))


# scale: source px -> game px (first guess); target: body height in game px that every
# (row, group) listed in norm is rescaled to - the sheets draw each row and even each
# group at its own size. last: groups sized by their last frame instead (the rooted
# pose). borrow: groups that take another group's factor (their poses
# are not standing, so their own height says nothing). view: per-row height multipliers.
UNITS = {
    "stormcaller": dict(scale=0.336, glow="blue", target=45,          # 1.3x a musketeer
                        norm=["walk", "idle", "attack", "cast"], borrow={"death": "idle"}),
    "cuirassier": dict(scale=0.48, target=51,                         # horse ~ the cannon's
                       norm=["idle", "walk", "slash"], borrow={"thrust": "slash", "death": "idle"},
                       widen={2: 1.2, 1: 1.08},      # E (side) and SE rows drew the horse squashed
                       # E gallop frames 1-2 turn toward the camera (narrower horse): stretch
                       # them to the idle side view's width so the gallop doesn't pump in and out
                       widen_frame={(2, "walk", 0): 1.07, (2, "walk", 1): 1.19, (2, "walk", 2): 1.26}),
    "spore_mother": dict(scale=0.6, glow="green", target=58,          # about the Brute
                         norm=["walk", "idle", "fire"], borrow={"death": "fire"},
                         last={"root": 54},           # the rooted pose: same size in every row
                         view={(2, "walk"): 0.88}),                    # side view: less depth
}


# ---------------------------------------------------------------- frames with anchors

class F:
    """A game-scale frame: RGBA image, glow mask and the foot point (ax, ay) in it."""

    def __init__(self, img, glow, ax=None, ay=None):
        self.img, self.glow = img, glow
        if ax is None:
            ax, ay = feet(img, glow)
        self.ax, self.ay = ax, ay

    def copy(self):
        return F(self.img.copy(), self.glow.copy(), self.ax, self.ay)


def body_of(img, glow):
    a = (img[..., 3] > 0) & ~glow
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n:
        size = ndimage.sum(a, lab, np.arange(1, n + 1))
        a &= (size >= max(6, size.max() * 0.05))[lab - 1] & (lab > 0)
    return a


def feet(img, glow):
    """Ground point: the lowest row of the solid body, and the middle of the legs
    (median x of the body's lowest quarter)."""
    a = body_of(img, glow)
    ys, xs = np.nonzero(a)
    rows = np.bincount(ys)
    bottom = int(np.flatnonzero(rows >= 2).max())
    low = ys >= bottom - max(2, (bottom - ys.min()) * 0.25)
    return float(np.median(xs[low])) + 0.5, float(bottom + 1)


def place(f, W, H, ax, ay):
    """Frame f drawn on a W*H canvas with its foot point at (ax, ay)."""
    out = np.zeros((H, W, 4), np.uint8)
    g = np.zeros((H, W), bool)
    ox, oy = int(round(ax - f.ax)), int(round(ay - f.ay))
    h, w = f.img.shape[:2]
    ys0, xs0 = max(0, oy), max(0, ox)
    ys1, xs1 = min(H, oy + h), min(W, ox + w)
    src = f.img[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
    m = src[..., 3] > 0
    out[ys0:ys1, xs0:xs1][m] = src[m]
    g[ys0:ys1, xs0:xs1] = f.glow[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox] & m
    return out, g


def align(ref, f, part="low", search=3):
    """Shift f's foot point so its body overlaps ref's best (feet steady between frames).
    part: 'low' compares the legs (bottom 35%), 'high' the body above the roots (top 60%),
    'all' everything."""
    def region(fr):
        a = body_of(fr.img, fr.glow)
        ys = np.flatnonzero(a.any(1))
        y0, y1 = ys.min(), ys.max() + 1
        if part == "low":
            a[:y1 - int((y1 - y0) * 0.35)] = False
        elif part == "high":
            a[y0 + int((y1 - y0) * 0.6):] = False
        return a
    S = 160
    A = place(F(region(ref)[..., None].repeat(4, -1).astype(np.uint8) * 255, np.zeros(ref.glow.shape, bool),
                ref.ax, ref.ay), S, S, S / 2, S * 0.75)[0][..., 3] > 0
    fb = region(f)[..., None].repeat(4, -1).astype(np.uint8) * 255
    best, bs = (0, 0), -1e9
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            B = place(F(fb, np.zeros(f.glow.shape, bool), f.ax - dx, f.ay - dy), S, S, S / 2, S * 0.75)[0][..., 3] > 0
            sc = (A & B).sum() - (A ^ B).sum() * 0.5 - 0.3 * (dx * dx + dy * dy)
            if sc > bs:
                bs, best = sc, (dx, dy)
    g = f.copy()
    g.ax -= best[0]
    g.ay -= best[1]
    return g


def steady(frames, part="low", chain=False):
    """Align every frame to the first one (or each to the one before it)."""
    out = [frames[0]]
    for f in frames[1:]:
        out.append(align(out[-1] if chain else out[0], f, part))
    return out


def mirror(f):
    w = f.img.shape[1]
    return F(f.img[:, ::-1].copy(), f.glow[:, ::-1].copy(), w - f.ax, f.ay)


def tint(f, mask_fn, gain):
    """Brighten (gain > 1) the pixels picked by mask_fn - a glow pulse on tanks or sacs."""
    g = f.copy()
    m = mask_fn(g.img) & (g.img[..., 3] > 0)
    rgb = g.img[..., :3].astype(float)
    rgb[m] = np.clip(rgb[m] * gain + (gain - 1) * 40, 0, 255)
    g.img[..., :3] = rgb.round().astype(np.uint8)
    return g


def bob(f, frac=0.45, dy=1):
    """The top part of the figure (above frac of its height) moved down dy pixels - a
    rider settling in the saddle, for a breathing idle from a single drawing."""
    g = f.copy()
    a = g.img[..., 3] > 0
    ys = np.flatnonzero(a.any(1))
    cut = ys.min() + int((ys.max() - ys.min()) * frac)
    top = g.img[:cut].copy()
    tg = g.glow[:cut].copy()
    g.img[ys.min():cut] = 0
    m = top[..., 3] > 0
    region = g.img[dy:cut + dy]
    region[m] = top[m]
    g.glow[dy:cut + dy] |= tg
    return g


def blue_tanks(img):
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    return (b >= r + 40) & (b >= 120)


def green_sacs(img):
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    return (g >= r + 5) & (g >= b + 40) & (g >= 110)


def overlay(base, top, dx=0, dy=0, under=False):
    """base with top drawn over it (or under it), top's foot point moved by (dx, dy)
    relative to base's. Returns a new frame with base's foot point."""
    H = max(base.img.shape[0], top.img.shape[0]) * 3
    W = max(base.img.shape[1], top.img.shape[1]) * 3
    ax, ay = W / 2, H * 0.6
    bi, bg = place(base, W, H, ax, ay)
    ti, tg = place(top, W, H, ax + dx, ay + dy)
    tm = ti[..., 3] > 0
    if under:
        tm &= bi[..., 3] == 0
    bi[tm] = ti[tm]
    bg = np.where(tm, tg, bg)
    ys, xs = np.nonzero(bi[..., 3] > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return F(bi[y0:y1, x0:x1].copy(), bg[y0:y1, x0:x1].copy(), ax - x0, ay - y0)


def only(f, keep):
    """Frame with only the pixels where keep(f) is True."""
    g = f.copy()
    m = keep(g)
    g.img[~m] = 0
    g.glow &= m
    return g


# ---------------------------------------------------------------- the plans

class Src:
    """Game-scale source frames of one sheet, cut, size-corrected and converted once."""

    def __init__(self, kind):
        self.kind = kind
        self.cfg = UNITS[kind]
        self.frames, self.bgc = extract(kind)
        self.cache = {}
        self.factors = {}
        self.heights = {}

    def raw(self, r, g, i, scale):
        img, gl = to_game(self.frames[(r, g)][i]["img"], scale, self.bgc, self.cfg.get("glow"),
                          sx=self.cfg.get("widen", {}).get(r, 1.0)
                          * self.cfg.get("widen_frame", {}).get((r, g, i), 1.0))
        return F(img, gl)

    def hs(self, r, g):
        """Body heights of a group's frames (at the first-guess scale)."""
        if (r, g) not in self.heights:
            hs = []
            for i in range(len(self.frames[(r, g)])):
                f = self.raw(r, g, i, self.cfg["scale"])
                ys = np.flatnonzero(body_of(f.img, f.glow).any(1))
                hs.append(ys.max() - ys.min() + 1)
            self.heights[(r, g)] = hs
        return self.heights[(r, g)]

    def factor(self, r, g):
        cfg = self.cfg
        g = cfg.get("borrow", {}).get(g, g)
        if (r, g) not in self.factors:
            if g in cfg.get("last", {}):
                self.factors[(r, g)] = cfg["last"][g] / float(self.hs(r, g)[-1])
            elif g in cfg["norm"]:
                want = cfg["target"] * cfg.get("view", {}).get((r, g), 1.0)
                self.factors[(r, g)] = want / float(np.median(self.hs(r, g)))
            else:
                self.factors[(r, g)] = 1.0
        return self.factors[(r, g)]

    # single frames drawn much smaller or bigger than the rest of their group
    OUTLIER = {"walk": 0.045, "idle": 0.045, "root": 0.12}

    def __call__(self, r, g, i, m=False):
        key = (r, g, i)
        if key not in self.cache:
            k = self.factor(r, g)
            if g in self.OUTLIER:
                hs = self.hs(r, g)
                dev = float(np.median(hs)) / hs[i]
                if abs(dev - 1) > self.OUTLIER[g]:
                    k *= dev
            self.cache[key] = self.raw(r, g, i, self.cfg["scale"] * k)
        f = self.cache[key]
        return mirror(f) if m else f.copy()

    def seq(self, r, g, idx=None, m=False):
        n = len(self.frames[(r, g)])
        return [self(r, g, i, m) for i in (range(n) if idx is None else idx)]


def narrowest(frames):
    """The walk frame with the feet closest together (to stand still on)."""
    def spread(f):
        a = body_of(f.img, f.glow)
        ys, xs = np.nonzero(a)
        low = ys >= ys.max() - max(2, (ys.max() - ys.min()) * 0.2)
        return xs[low].max() - xs[low].min()
    return min(frames, key=spread).copy()


def pulse(f, fn, gains=(1.0, 1.12, 1.24, 1.12)):
    return [tint(f, fn, k) if k != 1.0 else f.copy() for k in gains]


def plan_stormcaller(S):
    """Rows: 0 = S, 1 = SE, 2 = E, 3 = NE (back three-quarter), 4 = a second front view
    (a mistake: no back view was drawn) - N reuses NE. Idle frames are drawn facing the
    camera in every row: S and SE keep them, E/NE/N stand in the most upright walk pose
    with the chest tanks pulsing. Attacks are drawn side-on (facing right) in every row.
    Cast row 2 frame 3 is a stray side-on pose: replaced by frame 1 (arms raised)."""
    A = {}
    rows = {"s": 0, "se": 1, "e": 2, "ne": 3, "n": 3}
    for d, r in rows.items():
        A["walk", d] = steady(S.seq(r, "walk"), "high")
        if d in ("s", "se"):
            A["idle", d] = steady(S.seq(r, "idle"))
        else:
            # the most upright walk pose of that row (E: frame 4, NE: frame 2)
            A["idle", d] = pulse(S(r, "walk", 4 if r == 2 else 2), blue_tanks, (1.0, 1.15, 1.3))
        A["attack", d] = steady(S.seq(r, "attack"))
        cast = S.seq(r, "cast", [0, 1, 2, 1] if r == 2 else None)
        A["cast", d] = steady(cast)
        A["death", d] = S.seq(r, "death")
    return A


def plan_cuirassier(S):
    """Rows: 0 = S, 1 = SE, 2 = E, 3 = N (rear view; meant as NE), 4 = N (rear).
    No NE was drawn: NE uses row 3's rear idle and row 4's rear gallop. Row 2 (E) turns
    toward the camera from idle 1 and gallop 3 on (gallop 5-7 are front views, gallop 3
    holds a carbine): E gallops on frames 0-2 only, and E idles on idle 0 with the rider
    bobbing a pixel. Row 3's gallop mixes front and rear
    views (not used). The sabre frames face right three-quarter in every
    row, also in the rear-view rows, and several "slash" frames show no sabre at all
    (E, N), or a pistol (S slash 1) or a carbine (SE slash 2, painted out), so each
    direction's attack is put together from the frames that do show the sabre:
    ready/raise -> cut -> point.
    Death: the sheet's last frame lost the horse (just the rider lying); it is rebuilt
    as the fallen horse (frame 2) with the thrown rider (frame 3) beside it."""
    A = {}
    for d, (ri, rw, ra) in {"s": (0, 0, 0), "se": (1, 1, 1), "e": (2, 2, 2), "ne": (3, 4, 3),
                            "n": (4, 4, 4)}.items():
        if d == "e":
            i0 = S(2, "idle", 0)
            A["idle", d] = [i0, bob(i0)]
            A["walk", d] = steady(S.seq(2, "walk", [0, 1, 2]), "high")
        else:
            A["idle", d] = steady(S.seq(ri, "idle"))
            A["walk", d] = steady(S.seq(rw, "walk"), "high")
        att = {0: [("thrust", 0), ("slash", 0), ("slash", 2), ("thrust", 1)],
               1: [("slash", 0), ("thrust", 0), ("slash", 2), ("thrust", 1)],
               2: [("slash", 0), ("thrust", 0), ("thrust", 1), ("slash", 1)],
               3: [("slash", 0), ("thrust", 0), ("slash", 2), ("thrust", 1)],
               4: [("slash", 0), ("thrust", 0), ("thrust", 1), ("slash", 1)]}[ra]
        A["attack", d] = steady([S(ra, g, i) for g, i in att])
        dd = S.seq(ra if d != "ne" else 3, "death")
        horse, rider = dd[2], dd[3]
        dx = horse.img.shape[1] - horse.ax + rider.ax - rider.img.shape[1] * 0.35
        last = overlay(horse, rider, dx=dx if d != "n" else -dx, dy=2 if d in ("s", "se") else -1,
                       under=d in ("ne", "n"))
        A["death", d] = [dd[0], dd[1], dd[2], last]
    return A


def plan_spore_mother(S):
    """Rows: 0 = S, 1 = SE, 2 = side view facing WEST (mirrored for E), 3 = a second
    front three-quarter (meant as NE; no NE/back three-quarter exists), 4 = N (rear).
    E walk = row 2 mirrored; NE reuses E. Idle in rows 2-3 faces the camera, so E/NE
    stand in a walk pose with the sacs pulsing.
    The root frames turn from her walking pose to face the camera as she digs in
    (rows 1 and 2 are mirrored so they start facing right). deployed = the rooted pose
    with the sacs pulsing. The sheet's fire frames stand on walking legs, so fire is
    rebuilt on the rooted pose: sacs swell, then the vent cloud of fire frames 2-3."""
    A = {}
    for d, (rw, mw, ri, rr, mr) in {"s": (0, False, 0, 0, False), "se": (1, False, 1, 1, True),
                                    "e": (2, True, None, 2, True), "ne": (2, True, None, 2, True),
                                    "n": (4, False, 4, 4, False)}.items():
        walk = steady(S.seq(rw, "walk", m=mw), "high")
        A["walk", d] = walk
        if ri is not None:
            A["idle", d] = steady(S.seq(ri, "idle"))
        else:
            A["idle", d] = pulse(narrowest(walk), green_sacs, (1.0, 1.08, 1.16))
        root = S.seq(rr, "root", m=mr)
        root = steady(root, "high", chain=True)
        A["deploy", d] = root
        rooted = root[-1]
        A["deployed", d] = pulse(rooted, green_sacs, (1.0, 1.07, 1.14, 1.07))
        fire = S.seq(rr, "fire", m=mr)
        # cloud position: relative to the fire frame's own body top, put on the rooted body
        out = [tint(rooted, green_sacs, 1.12), tint(rooted, green_sacs, 1.25)]
        top_r = np.flatnonzero(body_of(rooted.img, rooted.glow).any(1)).min() - rooted.ay
        # the standing fire frame 0 has no cloud yet: its body top is the vent
        f0 = fire[0]
        top_f = np.flatnonzero(body_of(f0.img, f0.glow).any(1)).min() - f0.ay
        for k in (2, 3):
            fk = fire[k]
            vent = int(round(fk.ay + top_f)) + 4
            gas = only(fk, lambda g: g.glow & (np.arange(g.img.shape[0])[:, None] < vent))
            out.append(overlay(tint(rooted, green_sacs, 1.25 if k == 2 else 1.1), gas,
                               dy=top_r - top_f))
        A["fire", d] = out
        A["death", d] = S.seq(rr, "death", m=mr)
    return A


PLANS = {"stormcaller": plan_stormcaller, "cuirassier": plan_cuirassier,
         "spore_mother": plan_spore_mother}


# ---------------------------------------------------------------- output

def assemble(A):
    """One cell for all frames: the foot point in the middle of the cell's width."""
    L = R = U = D = 0
    for fr in A.values():
        for f in fr:
            h, w = f.img.shape[:2]
            L, R = max(L, f.ax), max(R, w - f.ax)
            U, D = max(U, f.ay), max(D, h - f.ay)
    half = int(np.ceil(max(L, R))) + 1
    top = int(np.ceil(U)) + 1
    W, H = 2 * half, top + int(np.ceil(D)) + 1
    strips = {}
    for (anim, d), fr in A.items():
        strips[f"{anim}_{d}"] = np.concatenate([place(f, W, H, half, top)[0] for f in fr], 1)
    return strips, (W, H), (half, top)


def write_units_data(entries):
    path = "scripts/art_data.gd"
    src = open(path).read()
    for kind, (cell, anchor, counts) in entries.items():
        lines = [f'\t"{kind}": {{"cell": Vector2i({cell[0]}, {cell[1]}), "anchor": Vector2({anchor[0]}, {anchor[1]}), "frames": {{']
        lines += [f'\t\t"{k}": {counts[k]},' for k in sorted(counts)]
        lines.append("\t}},")
        entry = "\n".join(lines) + "\n"
        pat = re.compile(r'\t"' + kind + r'": \{"cell".*?\n\t\}\},\n', re.S)
        if pat.search(src):
            src = pat.sub(lambda m: entry, src, count=1)
        else:
            i = src.index("\n}\n", src.index("const UNITS := {")) + 1
            src = src[:i] + entry + src[i:]
    open(path, "w").write(src)


def write_effects_data(entries):
    path = "scripts/art_data.gd"
    src = open(path).read()
    for name, (n, w, h) in entries.items():
        line = f'\t"{name}": {{"frames": {n}, "size": Vector2i({w}, {h})}},\n'
        pat = re.compile(r'\t"' + name + r'": \{"frames".*\n')
        if pat.search(src):
            src = pat.sub(lambda m: line, src, count=1)
        else:
            i = src.index("\n}\n", src.index("const EFFECTS := {")) + 1
            src = src[:i] + line + src[i:]
    open(path, "w").write(src)


# Icon drawings: (row, group, index, share of the figure's height kept from the top).
# Rendered straight from the source at icon size (the sprites are too small to blow up).
ICONS = {
    "stormcaller": (0, "idle", 0, 0.6),      # bust: the coil head, chest tanks and tabard
    "cuirassier": (1, "idle", 0, 0.62),      # rider and the horse's head, three-quarter
    "spore_mother": (1, "idle", 0, 1.0),     # three-quarter view
}


def make_unit_icon(S, kind, size=54):
    r, g, i, keep = ICONS[kind]
    src = S.frames[(r, g)][i]["img"].copy()
    ys = np.flatnonzero((src[..., 3] > 0).any(1))
    src = src[:ys.min() + int((ys.max() + 1 - ys.min()) * keep)]
    xs = np.flatnonzero((src[..., 3] > 0).any(0))
    src = src[:, xs.min():xs.max() + 1]
    scale = size / max(src.shape[:2])
    img, _ = to_game(src, scale, S.bgc, S.cfg.get("glow"))
    make_icon(img, kind)


def build_unit(kind):
    S = Src(kind)
    if DEBUG:
        debug_boxes(kind, S.frames)
        dump_source(kind, S.frames, S.bgc)
    A = PLANS[kind](S)
    strips, cell, anchor = assemble(A)
    out = f"assets/units/{kind}"
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png") and f[:-4] not in strips:
            os.remove(os.path.join(out, f))
            if os.path.exists(os.path.join(out, f + ".import")):
                os.remove(os.path.join(out, f + ".import"))
    counts = {}
    for key, strip in sorted(strips.items()):
        Image.fromarray(strip).save(f"{out}/{key}.png")
        counts[key] = strip.shape[1] // cell[0]
    if not ONLY:            # the icons have since been replaced by painted portraits
        make_unit_icon(S, kind)
    if CONTACT:
        os.makedirs(CONTACT, exist_ok=True)
        unit_contact(kind, cell, anchor, counts)
    print(f"{kind}: cell {cell[0]}x{cell[1]}, anchor {anchor}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    return cell, anchor, counts


def contact_sheet(path, lines, k=3):
    """lines: [(label, [RGBA frame, ...])] -> one labelled line each, x k, on grass green,
    with the cell border drawn faintly so the shared cell and anchor can be checked."""
    rows = []
    for label, frames in lines:
        rows.append((label, [on_green(f, k) for f in frames]))
    W = max(110 + sum(i.width + 4 for i in ims) for _, ims in rows)
    H = sum(max(i.height for i in ims) + 4 for _, ims in rows)
    sheet = Image.new("RGB", (W, H), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    y = 0
    for label, ims in rows:
        d.text((4, y + 4), label, fill=(255, 255, 255))
        x = 110
        for im in ims:
            sheet.paste(im, (x, y))
            x += im.width + 4
        y += max(i.height for i in ims) + 4
    sheet.save(path)


def unit_contact(kind, cell, anchor, counts):
    lines = []
    ref = []
    for rk, rn in (("musketeer", "idle_s"), ("brute", "idle_e"), ("cannon", "walk_e")):
        a = np.array(Image.open(f"assets/units/{rk}/{rn}.png").convert("RGBA"))
        cw = int(re.search(r'"%s": \{"cell": Vector2i\((\d+)' % rk, open("scripts/art_data.gd").read()).group(1))
        ref.append(a[:, :cw])
    own = np.array(Image.open(f"assets/units/{kind}/idle_s.png").convert("RGBA"))[:, :cell[0]]
    H = max(r.shape[0] for r in ref + [own])
    pad = [np.concatenate([np.zeros((H - r.shape[0], r.shape[1], 4), np.uint8), r], 0) for r in ref + [own]]
    lines.append(("scale: musk/brute/\ncannon/" + kind[:8], pad))
    for anim in sorted({k.rsplit("_", 1)[0] for k in counts}):
        for d in DIRS:
            key = f"{anim}_{d}"
            if key not in counts:
                continue
            strip = np.array(Image.open(f"assets/units/{kind}/{key}.png").convert("RGBA"))
            frames = []
            for i in range(counts[key]):
                fr = strip[:, i * cell[0]:(i + 1) * cell[0]].copy()
                # anchor cross (faint) and cell border
                fr[anchor[1], max(0, anchor[0] - 2):anchor[0] + 3] = (255, 255, 255, 110)
                fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
                fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
                frames.append(fr)
            lines.append((key, frames))
    contact_sheet(os.path.join(CONTACT, f"contact_{kind}.png"), lines)


def debug_boxes(kind, frames):
    im = Image.open(SHEETS[kind]["path"]).convert("RGB")
    d = ImageDraw.Draw(im)
    for (r, g), lst in frames.items():
        for i, f in enumerate(lst):
            d.rectangle([f["x0"], f["y0"], f["x1"] - 1, f["y1"] - 1], outline=(255, 255, 0))
            d.text((f["x0"] + 1, f["y1"] + 1), f"{r}{g[0]}{i}", fill=(255, 255, 255))
    im.save(os.path.join(DEBUG, f"boxes_{kind}.png"))


# ---------------------------------------------------------------- spell effects

FX_SRC = "art/world/storm_and_miasma.png"
FX_ROWS = {  # name: (y0, y1, x cuts between frames) - read off the sheet
    "storm_in": (0, 190, [0, 165, 325, 505, 690, 895, 1090, 1290, 1536]),
    "storm_loop": (190, 383, [0, 268, 497, 740, 987, 1240, 1536]),
    "storm_out": (383, 556, [0, 260, 510, 755, 1000, 1250, 1536]),
    "miasma_in": (556, 710, [0, 165, 315, 490, 672, 865, 1070, 1275, 1536]),
    "miasma_loop": (710, 872, [0, 250, 462, 674, 887, 1093, 1304, 1536]),
    "miasma_out": (872, 1024, [0, 240, 456, 670, 891, 1091, 1285, 1536]),
}
TILE = 32
STORM_RING_W = 6 * TILE          # ring diameter across: a 3-tile radius
FIELD_Y = 435.0 / 512.0          # the game's ground ellipse (field ring) height/width
STORM_W, MIASMA_W = 208, 200     # frame widths (ring/cloud plus its sparks)
MIASMA_CLOUD_W = 190


def fx_cells():
    import import_lightning as L
    rgb = np.asarray(Image.open(FX_SRC).convert("RGB")).astype(np.float64)
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
                             rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    # colour-to-alpha for light over the slate (only channels brighter than the slate
    # count, so the dark debris and noise vanish instead of turning into a dark fringe)
    al = np.clip((rgb - bg) / (255.0 - bg), 0, None).max(axis=2).clip(0, 1)
    col = np.clip((rgb - bg * (1 - al[..., None])) / np.maximum(al, 1e-6)[..., None], 0, 255)
    pm = np.dstack([col * al[..., None], al * 255.0])
    cells = {}
    for name, (y0, y1, cuts) in FX_ROWS.items():
        cells[name] = [pm[y0:y1, a:b].copy() for a, b in zip(cuts[:-1], cuts[1:])]
    return cells, L


def light_box(c, thr=0.3):
    ys, xs = np.nonzero(c[..., 3] / 255.0 > thr)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def ring_geometry(c):
    """Storm ring in a cell: centre x, equator y (the row where the ring is widest) and
    half-width. Rows are smoothed so a lone spark doesn't win."""
    m = c[..., 3] / 255.0 > 0.3
    x0, x1, y0, y1 = light_box(c)
    w = np.zeros(m.shape[0])
    for y in range(y0, y1):
        xs = np.flatnonzero(m[y])
        if xs.size >= 2:
            w[y] = xs[-1] - xs[0]
    ws = ndimage.uniform_filter1d(w, 9)
    # the ring's equator: the widest smoothed row in the lower 3/4 (bolts rise above)
    lo = y0 + (y1 - y0) // 4
    ey = lo + int(np.argmax(ws[lo:y1]))
    xs = np.flatnonzero(ndimage.binary_dilation(m, iterations=2)[max(0, ey - 4):ey + 5].any(0))
    return (xs[0] + xs[-1] + 1) / 2.0, ey + 0.5, (xs[-1] + 1 - xs[0]) / 2.0


def ring_top(c, cx, ey, a):
    """Top of the ring's far edge (where the ellipse ends and rising bolts begin): the
    bottom of the ring measured below the equator, mirrored."""
    m = c[..., 3] / 255.0 > 0.45
    xs = np.arange(int(cx - a * 0.25), int(cx + a * 0.25))
    bottoms = []
    for x in xs:
        ys = np.flatnonzero(m[int(ey):, x])
        if ys.size:
            bottoms.append(ys.max())
    b = float(np.median(bottoms)) if bottoms else a * 0.45
    return b


def build_effects():
    cells, L = fx_cells()
    made = {}
    # ---- storm: one ring geometry per row (from the loop), each frame centred on its
    # own ring; appear grows to the loop's size, fade starts from it.
    loop_geo = [ring_geometry(c) for c in cells["storm_loop"]]
    A = float(np.median([g[2] for g in loop_geo]))
    B = float(np.median([ring_top(c, *g) for c, g in zip(cells["storm_loop"], loop_geo)]))
    sx = STORM_RING_W / (2 * A)
    ring_h = STORM_RING_W * FIELD_Y / 2          # half-height in game px
    sy = ring_h / B
    up = 0
    geos = {}
    for name in ("storm_in", "storm_loop", "storm_out"):
        gs = [ring_geometry(c) for c in cells[name]]
        # one equator height per row (single frames' estimates wander with the flares)
        # row zoom: the sheet draws appear ending smaller than the loop and fade starting
        # smaller; scale those rows so they meet the loop's ring size
        k_ref = len(gs) - 1 if name == "storm_in" else 0
        zoom = 1.0 if name == "storm_loop" else A / gs[k_ref][2]
        if name == "storm_loop":
            ey_row = float(np.median([g[1] for g in gs]))
        else:
            # the bare rings of appear/fade: the biggest ring's near edge (bottom) sits
            # on the ellipse's bottom
            m = cells[name][k_ref][..., 3] / 255.0 > 0.45
            cx, _, a = gs[k_ref]
            cols = m[:, int(cx - a * 0.3):int(cx + a * 0.3)]
            ey_row = float(np.flatnonzero(cols.any(1)).max()) + 1 - B / zoom
        gs = [(cx, ey_row, a) for cx, _, a in gs]
        geos[name] = (gs, zoom)
        for c, (cx, ey, a) in zip(cells[name], gs):
            ys = np.flatnonzero((c[..., 3] / 255.0 > 0.1).any(1))
            above = ey - ys.min()                    # source px above the equator
            ring_part = min(above, B / zoom)
            up = max(up, ring_part * sy * zoom + (above - ring_part) * sx * zoom)
    half_h = int(np.ceil(max(up, ring_h + 14))) + 2
    H = 2 * half_h
    W = STORM_W
    for name in ("storm_in", "storm_loop", "storm_out"):
        gs, zoom = geos[name]
        frames = []
        for c, (cx, ey, a) in zip(cells[name], gs):
            def fn(U, V, cx=cx, ey=ey, zoom=zoom):
                kx, ky = sx * zoom, sy * zoom        # game px per source px
                X = cx + (U - W / 2) / kx
                dv = V - half_h                      # game px below (+) / above (-) centre
                # the ring band is squashed onto the ground ellipse; above its far edge the
                # rising bolts keep the horizontal scale (not stretched tall)
                lim = ring_h
                Y = np.where(dv >= -lim, ey + dv / ky, ey - lim / ky + (dv + lim) / kx)
                return X, Y
            frames.append(L.warp(c, W, H, fn))
        made[name] = frames
    # ---- miasma: one scale for all rows (cloud ~190 px across in the loop), every
    # frame centred on its light-weighted centre.
    widths = [light_box(c)[1] - light_box(c)[0] for c in cells["miasma_loop"]]
    s = MIASMA_CLOUD_W / float(np.median(widths))
    hs = []
    cents = {}
    for name in ("miasma_in", "miasma_loop", "miasma_out"):
        lst = cells[name]
        if name == "miasma_in":
            lst = lst[:-1]     # the sheet's last appear frame shrinks back (a fumble)
            cells[name] = lst
        cs = []
        for c in lst:
            w = c[..., 3]
            yy, xx = np.mgrid[0:w.shape[0], 0:w.shape[1]]
            cs.append(((w * xx).sum() / w.sum() + 0.5, (w * yy).sum() / w.sum() + 0.5))
            ys = np.flatnonzero((w / 255.0 > 0.1).any(1))
            hs.append(max(cs[-1][1] - ys.min(), ys.max() + 1 - cs[-1][1]))
        cents[name] = cs
    # the fade row is drawn smaller than the loop: it starts at the loop's width
    zooms = {"miasma_in": 1.0, "miasma_loop": 1.0,
             "miasma_out": float(np.median(widths)) / (light_box(cells["miasma_out"][0])[1] -
                                                        light_box(cells["miasma_out"][0])[0])}
    H = 2 * int(np.ceil(max(hs) * s * max(zooms.values()))) + 4
    W = MIASMA_W
    for name in ("miasma_in", "miasma_loop", "miasma_out"):
        k = s * zooms[name]
        made[name] = [L.warp(c, W, H, lambda U, V, cx=cx, cy=cy, k=k: (cx + (U - W / 2) / k, cy + (V - H / 2) / k))
                      for c, (cx, cy) in zip(cells[name], cents[name])]
    out = {}
    os.makedirs("assets/effects", exist_ok=True)
    for name, frames in made.items():
        fin = [L.finish(f) for f in frames]
        strip = np.concatenate(fin, axis=1)
        Image.fromarray(strip, "RGBA").save(f"assets/effects/{name}.png")
        h, w = fin[0].shape[:2]
        out[name] = (len(fin), w, h)
        print(f"{name}: {len(fin)} frames {w}x{h}")
    print(f"  storm ring: {STORM_RING_W}x{STORM_RING_W * FIELD_Y:.0f} ellipse centred in the frame;"
          f" miasma cloud centred in the frame")
    return out


def effects_contact(entries):
    lines = []
    for name, (n, w, h) in entries.items():
        strip = np.array(Image.open(f"assets/effects/{name}.png").convert("RGBA"))
        frames = []
        for i in range(n):
            fr = strip[:, i * w:(i + 1) * w].copy()
            if name.startswith("storm"):
                # the 3-tile ground ellipse the ring must cover (faint white guide)
                yy, xx = np.mgrid[0:h, 0:w]
                r = ((xx + 0.5 - w / 2) / (STORM_RING_W / 2)) ** 2 + \
                    ((yy + 0.5 - h / 2) / (STORM_RING_W * FIELD_Y / 2)) ** 2
                guide = (np.abs(r - 1) < 0.02) & (fr[..., 3] < 60)
                fr[guide] = (255, 255, 255, 90)
            fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
            fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
            frames.append(fr)
        lines.append((name, frames))
    contact_sheet(os.path.join(CONTACT, "contact_effects.png"), lines, k=2 if False else 3)


def main():
    if DEBUG:
        os.makedirs(DEBUG, exist_ok=True)
    entries = {kind: build_unit(kind) for kind in SHEETS if not ONLY or kind in ONLY}
    write_units_data(entries)
    if ONLY:
        return
    fx = build_effects()
    write_effects_data(fx)
    if CONTACT:
        effects_contact(fx)


if __name__ == "__main__":
    main()
