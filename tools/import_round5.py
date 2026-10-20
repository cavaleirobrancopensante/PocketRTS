"""Round 5 art: the Clockwork Ornithopter, the Brood Bloater and the Clockwork
Capacitor Works.

Sources (generated sheets on a flat slate background):
  art/clockwork/ornithopter.png      6 rows, groups fly/hover/attack/death (1 + 4 scatter)
  art/brood/bloater.png              5 rows = directions, groups drift/idle/swell/burst
  art/clockwork/capacitor_works.png  one row: built, construction, damaged, destroyed

The unit sheets are cut and converted with the round 4 machinery (tools/import_round4.py:
shadow-aware slate mask, glow un-blended from the slate, box-filter shrink, team reds
snapped to the key colours, specks and slate fringe removed, one shared cell per unit).
The PLAN functions below say which source frames make each animation and direction and
why (wrong-facing rows, rebuilt frames).

Output:
  assets/units/{ornithopter,bloater}/<anim>_<dir>.png   horizontal strips, one cell per frame
  assets/icons/{ornithopter,bloater,capacitor_works}.png 64x64 button icons
  assets/effects/bloat_cloud.png                         the burst's acid cloud alone
  assets/buildings/capacitor_works_{built,construction,damaged,destroyed}.png
  the "ornithopter" and "bloater" entries of UNITS, "bloat_cloud" of EFFECTS and
  "capacitor_works" of BUILDING_SIZE in scripts/art_data.gd (added or replaced in place;
  nothing else in the file is touched)

Usage (from the repo root): python3 tools/import_round5.py [--debug DIR] [--contact DIR]
(--contact writes x3 contact sheets on grass green; --debug also dumps the cut frames)
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_round4 as r4  # noqa: E402
from import_art import load, make_icon  # noqa: E402
from import_cannon2 import bg_mask, clean, defringe, shrink, snap_team  # noqa: E402
from import_round4 import (F, Src, align, assemble, body_of, mirror, on_green,  # noqa: E402
                           overlay, place, steady, to_game, write_effects_data,
                           write_units_data)

DIRS = ["s", "se", "e", "ne", "n"]
DEBUG = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None


# ---------------------------------------------------------------- sheets

SHEETS = {
    "ornithopter": dict(
        path="art/clockwork/ornithopter.png", rows=[205, 378, 553, 711, 865],
        groups=["fly", "hover", "attack", "death", "scatter"],
        counts=[[7, 4, 4, 1, 4]] * 2 + [[6, 4, 4, 1, 4]] * 4,
        panels=[[0, 522, 870, 1146, 1260, 1536],
                [0, 528, 870, 1150, 1260, 1536],
                [0, 532, 864, 1154, 1259, 1536],
                [0, 541, 868, 1156, 1263, 1536],
                [0, 540, 868, 1154, 1258, 1536],
                [0, 531, 866, 1148, 1254, 1536]]),
    "bloater": dict(
        path="art/brood/bloater.png", rows=[216, 392, 578, 770],
        groups=["drift", "idle", "swell", "burst"],
        counts=[[6, 6, 4, 5]] * 2 + [[5, 6, 4, 5]] * 3,
        panels=[[0, 405, 777, 1051, 1536],
                [0, 403, 775, 1058, 1536],
                [0, 400, 776, 1062, 1536],
                [0, 403, 774, 1060, 1536],
                [0, 395, 776, 1062, 1536]]),
}

UNITS = {
    "ornithopter": dict(scale=0.38, glow="blue", norm=[]),
    "bloater": dict(scale=0.4, glow="green", target=42, norm=["drift", "idle"],
                    borrow={"swell": "drift", "burst": "drift"}),
}


# Frame cuts read off the sheet where the drawings overlap too much to find them:
# (panel start, panel end, frames) -> x cuts.
CUT_FIX = {
    (531, 866, 4): [531, 616, 683, 760, 866],     # ornithopter, top-down hover: wingtips touch
}


def run_cuts(m, a, b, n):
    """x positions splitting columns a..b of mask m into n frames: the drawings are
    separated by empty columns; extra runs (flying parts, sparks) merge into the nearest
    neighbour, and figures drawn touching are split at their thinnest column."""
    if (a, b, n) in CUT_FIX:
        return CUT_FIX[(a, b, n)]
    cols = m[:, a:b].sum(0)
    runs, x = [], 0
    while x < len(cols):
        if cols[x] > 0:
            s = x
            while x < len(cols) and cols[x] > 0:
                x += 1
            runs.append([s, x])
        else:
            x += 1
    while len(runs) > n:
        # merge across the smallest gap, preferring tiny runs
        k = min(range(len(runs) - 1),
                key=lambda i: (runs[i + 1][0] - runs[i][1]) +
                0.5 * min(runs[i][1] - runs[i][0], runs[i + 1][1] - runs[i + 1][0]))
        runs[k] = [runs[k][0], runs[k + 1][1]]
        del runs[k + 1]
    while len(runs) < n:
        wid = [r[1] - r[0] for r in runs]
        k = int(np.argmax(wid))
        s, e = runs[k]
        parts = max(2, int(round(wid[k] / (sum(wid) / n))))
        parts = min(parts, n - len(runs) + 1)
        new = []
        lo = s
        for p in range(1, parts):
            g = s + (e - s) * p / parts
            w0, w1 = int(g - (e - s) / parts * 0.3), int(g + (e - s) / parts * 0.3)
            c = w0 + int(np.argmin(cols[w0:w1]))
            new.append([lo, c])
            lo = c
        new.append([lo, e])
        runs[k:k + 1] = new
    cuts = [a] + [a + (runs[i][1] + runs[i + 1][0]) // 2 for i in range(n - 1)] + [b]
    return cuts


def register():
    """Hand the sheets to the round 4 machinery (its extract/Src read these tables)."""
    r4.SHEETS.update(SHEETS)
    r4.UNITS.update(UNITS)
    r4.column_cuts = run_cuts
    r4.feet = feet


_feet4 = r4.feet


def feet(img, glow):
    """round 4's foot point; frames of loose parts or all light fall back to the bottom
    centre of everything drawn."""
    try:
        return _feet4(img, glow)
    except ValueError:
        ys, xs = np.nonzero(img[..., 3] > 0)
        if not len(ys):
            return img.shape[1] / 2.0, float(img.shape[0])
        return (xs.min() + xs.max() + 1) / 2.0, float(ys.max() + 1)




# ---------------------------------------------------------------- masks and anchors

def wing_px(img):
    """Wing membrane: team red (already snapped) or the pale canvas between the ribs."""
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    team = ((r == 255) | (r == 150)) & (g == 0) & (b == 0)
    canvas = (np.minimum(np.minimum(r, g), b) >= 120) & ((np.maximum(np.maximum(r, g), b) -
                                                         np.minimum(np.minimum(r, g), b)) <= 100)
    return team | canvas


def fuselage(f):
    """The ornithopter's brass body: solid pixels that are not wing (beating wings would
    drag a plain centroid around)."""
    return body_of(f.img, f.glow) & ~wing_px(f.img)


def sac(f):
    """The bloater's gas sac: the yellow-green body pixels."""
    r, g, b = [f.img[..., c].astype(int) for c in range(3)]
    return (f.img[..., 3] > 0) & ~f.glow & (g >= r + 5) & (g >= b + 40) & (g >= 110)


def everything(f):
    return f.img[..., 3] > 0


def centroid(m):
    ys, xs = np.nonzero(m)
    return xs.mean() + 0.5, ys.mean() + 0.5


def anchored(f, mask_fn, drop):
    """f with its anchor drop pixels below the centroid of mask_fn(f): the anchor follows
    the body's centre, not the beating wings, dangling tendrils or flying bolts."""
    g = f.copy()
    m = mask_fn(g)
    if m.sum() < 8:
        m = everything(g)
    cx, cy = centroid(m)
    g.ax, g.ay = cx, cy + drop
    return g


def bottom_drop(frames, mask_fn, solid_fn=lambda f: body_of(f.img, f.glow)):
    """How far the bottom of the solid figure sits below the centroid of mask_fn (median
    over frames): the anchor goes there, so it is the machine's / sac's centre-bottom."""
    ds = []
    for f in frames:
        _, cy = centroid(mask_fn(f))
        ds.append(np.flatnonzero(solid_fn(f).any(1)).max() + 1 - cy)
    return float(np.median(ds))


def steady_c(frames, mask_fn, drop):
    return [anchored(f, mask_fn, drop) for f in frames]


# ---------------------------------------------------------------- source-space edits

def split_bolt(img):
    """Source frame -> (frame without the bolt, bolt alone, bolt origin (x, y)). The bolt is
    the blue light outside the solid body hull."""
    rgb = img[..., :3].astype(float)
    fg = img[..., 3] > 0
    cand = fg & r4.glow_kind(rgb, "blue")
    hull = r4.body_hull(fg & ~cand)
    out = fg & ~hull
    lab, n = ndimage.label(out, structure=np.ones((3, 3)))
    keep = np.zeros_like(fg)
    for i in range(1, n + 1):
        m = lab == i
        if (m & cand).sum() >= 3:
            keep |= m
    bolt = img.copy()
    bolt[~keep] = 0
    rest = img.copy()
    rest[keep] = 0
    if keep.any():
        ys, xs = np.nonzero(keep)
        top = ys.min()
        ox = float(np.median(xs[ys <= top + 3]))
        return rest, bolt, (ox, float(top))
    ys, xs = np.nonzero(fg)
    return rest, bolt, ((xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0)


def rotate_src(img, deg, centre=None):
    """Nearest-neighbour rotation of a source frame (clockwise degrees) about centre,
    on a canvas big enough to hold it; returns the image and where centre went."""
    h, w = img.shape[:2]
    pad = int(np.hypot(h, w) / 2) + 2
    big = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.uint8)
    big[pad:pad + h, pad:pad + w] = img
    cx, cy = (w / 2.0, h / 2.0) if centre is None else centre
    im = Image.fromarray(big, "RGBA").rotate(-deg, resample=Image.NEAREST,
                                             center=(cx + pad, cy + pad))
    return np.array(im), (cx + pad, cy + pad)


def crop_alpha(img):
    ys, xs = np.nonzero(img[..., 3] > 0)
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy(), xs.min(), ys.min()


def add_rotated_row(S, src_row, new_row, deg):
    """A new direction made by turning the top-down view: every frame of src_row turned
    deg degrees clockwise. Bolts are taken off first and put back unturned under the
    turned capacitor, so they still crackle straight down."""
    for g in SHEETS[S.kind]["groups"]:
        lst = []
        for fr in S.frames[(src_row, g)]:
            rest, bolt, origin = split_bolt(fr["img"])
            rot, (ox, oy) = rotate_src(rest, deg, origin)
            if bolt[..., 3].any():
                h, w = bolt.shape[:2]
                x0, y0 = int(round(ox - origin[0])), int(round(oy - origin[1]))
                m = bolt[..., 3] > 0
                rot[y0:y0 + h, x0:x0 + w][m] = bolt[m]
            img, _, _ = crop_alpha(rot)
            lst.append(dict(img=img, x0=fr["x0"], y0=fr["y0"], x1=fr["x1"], y1=fr["y1"]))
        S.frames[(new_row, g)] = lst


def cap_bolt(f, below):
    """Attack frames: the bolt is kept to a short crackle under the capacitor (the game
    draws the real zap to the target, which may be another flyer)."""
    g = f.copy()
    lim = int(round(g.ay + below))
    cut = np.zeros(g.glow.shape, bool)
    cut[lim:] = True
    m = cut & g.glow
    g.img[m] = 0
    g.glow &= ~m
    # the last 3 rows of the stub fade out
    for k, a in ((1, 170), (2, 95), (3, 95)):
        y = lim - k
        if 0 <= y < g.img.shape[0]:
            row = g.glow[y] & (g.img[y, :, 3] > a)
            g.img[y, row, 3] = a
    g.img = clean(g.img, min_size=3, keep_near=1)
    g.glow &= g.img[..., 3] > 0
    return g


# ---------------------------------------------------------------- ornithopter

ORN_BOLT = 12          # px of bolt kept under the capacitor


def debris(S, r):
    """The loose parts of a death row (scatter frames 1 and 2, as drawn on the sheet)
    as one game-scale frame, anchored at the middle of the parts."""
    k = S.cfg["scale"]
    parts = [S.frames[(r, "scatter")][i] for i in (1, 2) if i < len(S.frames[(r, "scatter")])]
    x0 = min(p["x0"] for p in parts)
    y0 = min(p["y0"] for p in parts)
    x1 = max(p["x1"] for p in parts)
    y1 = max(p["y1"] for p in parts)
    canvas = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    for p in parts:
        h, w = p["img"].shape[:2]
        m = p["img"][..., 3] > 0
        canvas[p["y0"] - y0:p["y0"] - y0 + h, p["x0"] - x0:p["x0"] - x0 + w][m] = p["img"][m]
    img, gl = to_game(canvas, k, S.bgc, "blue")
    return F(img, gl, img.shape[1] / 2.0, img.shape[0] / 2.0)


def spread(parts, k, dy):
    """Parts pushed away from their middle by factor k (each loose piece moved whole)."""
    a = parts.img[..., 3] > 0
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=1), structure=np.ones((3, 3)))
    lab = lab * a
    h, w = a.shape
    W, H = int(w * k) + 8, int(h * k) + 8 + abs(dy)
    out = np.zeros((H, W, 4), np.uint8)
    gl = np.zeros((H, W), bool)
    cx, cy = w / 2.0, h / 2.0
    for i in range(1, n + 1):
        m = lab == i
        ys, xs = np.nonzero(m)
        px, py = xs.mean() - cx, ys.mean() - cy
        ox = int(round(px * (k - 1) + (W - w) / 2.0))
        oy = int(round(py * (k - 1) + (H - h) / 2.0 + dy))
        ys2, xs2 = ys + oy, xs + ox
        ok = (ys2 >= 0) & (ys2 < H) & (xs2 >= 0) & (xs2 < W)
        out[ys2[ok], xs2[ok]] = parts.img[ys[ok], xs[ok]]
        gl[ys2[ok], xs2[ok]] = parts.glow[ys[ok], xs[ok]]
    return F(out, gl, W / 2.0, H / 2.0)


def plan_ornithopter(S):
    """Rows as drawn: 0 = S (front), 1 = SE (front three-quarter, tail to the left),
    2 = between SE and E, 3 = E (side profile), 4 = a second SE (a repeat: unused),
    5 = top-down, nose up: used as N (the sheet's row 4 is not a north view at all).
    No NE was drawn: NE is the top-down view turned 45 degrees clockwise (bolts are put
    back unturned, straight down). The hover frames of rows 1-4 are all drawn as front
    three-quarter views; E hovers on its own fly cycle instead (the side profile beats
    its wings in place) so it doesn't swing round to the camera when it stops.
    Attack: the bolt is cut to a short crackle under the capacitor.
    Death: the hit frame, the break-up, then the hull with the scattered parts (the
    sheet's loose-part frames) flung out and falling, then the falling hull."""
    add_rotated_row(S, 5, 6, 45)
    rows = {"s": 0, "se": 1, "e": 3, "ne": 6, "n": 5}
    drop = bottom_drop(S.seq(0, "hover"), fuselage)
    A = {}
    for d, r in rows.items():
        A["walk", d] = steady_c(S.seq(r, "fly"), fuselage, drop)
        A["idle", d] = A["walk", d] if d == "e" else steady_c(S.seq(r, "hover"), fuselage, drop)
        A["attack", d] = [cap_bolt(f, ORN_BOLT - drop) for f in
                          steady_c(S.seq(r, "attack"), fuselage, drop)]
        sc = S.seq(r, "scatter")
        hit = anchored(S(r, "death", 0), fuselage, drop)
        brk = anchored(sc[0], fuselage, drop)
        hull = anchored(sc[-1], fuselage, drop)
        parts = debris(S, 5 if r == 6 else r)
        near = overlay(hull, spread(parts, 0.75, 0), dy=-drop)
        far = overlay(hull, spread(parts, 1.0, 6), dy=-drop + 2)
        A["death", d] = [hit, brk, near, far, hull]
    return A


# ---------------------------------------------------------------- bloater

def plan_bloater(S):
    """Rows: 0 = S, 1 = SE, 2 = E (side: the sac bulges to the right), 3 = another front
    three-quarter (meant as NE; no back three-quarter exists: unused), 4 = N (the back
    with its spine). NE reuses E. Every group is drawn facing its row's way.
    Anchor: the sac's centre-bottom (from the S drift frames), the same for every
    animation - the sac's centroid stays put while the tendrils swing and the burst cloud
    spreads around it."""
    rows = {"s": 0, "se": 1, "e": 2, "ne": 2, "n": 4}
    drop = bottom_drop(S.seq(0, "drift"), sac, sac)
    A = {}
    for d, r in rows.items():
        A["walk", d] = steady_c(S.seq(r, "drift"), sac, drop)
        A["idle", d] = steady_c(S.seq(r, "idle"), sac, drop)
        A["attack", d] = steady_c(S.seq(r, "swell"), sac, drop)
        burst = S.seq(r, "burst")
        # the sac bursts: from frame 2 on there is no sac left, the cloud is centred on
        # where it was (its centroid: the cloud's light-weighted middle)
        A["death", d] = [anchored(f, sac if i < 2 else everything, drop) for i, f in enumerate(burst)]
    return A


PLANS = {"ornithopter": plan_ornithopter, "bloater": plan_bloater}


# ---------------------------------------------------------------- bloat cloud effect

CLOUD_W = 150          # frame width; the game scales it to the 2.1 x 72 px zone anyway
CLOUD_FILL = 138       # the biggest cloud's width in it


def build_cloud(S, row=0):
    """The last three burst frames' acid cloud alone: un-blended from the slate, the crest,
    bone shards and tendrils taken out (only the yellow-green gas stays), each frame
    centred on the gas's light-weighted middle, one scale for all three."""
    import import_lightning as L
    cells = []
    for fr in S.frames[(row, "burst")][-3:]:
        img = fr["img"]
        rgb = img[..., :3].astype(float)
        bg = S.bgc
        al = np.clip((rgb - bg) / (255.0 - bg), 0, None).max(-1).clip(0, 1)
        al[img[..., 3] == 0] = 0
        col = np.clip((rgb - bg * (1 - al[..., None])) / np.maximum(al, 1e-6)[..., None], 0, 255)
        r, g, b = col[..., 0], col[..., 1], col[..., 2]
        gas = (g >= r + 6) & (g >= b + 40)
        # the opaque crest / shards / tendrils and a 1 px halo round them go
        solid = (img[..., 3] > 0) & ~gas
        solid = ndimage.binary_dilation(solid & (al > 0.6), iterations=1) & ~gas
        al = np.where(gas & ~solid, al, 0)
        al = ndimage.uniform_filter(al, 3) * (al > 0)
        cells.append(np.dstack([col * al[..., None], al * 255.0]))
    widths = []
    for c in cells:
        xs = np.flatnonzero((c[..., 3] / 255.0 > 0.25).any(0))
        widths.append(xs.max() - xs.min() + 1)
    k = CLOUD_FILL / float(max(widths))
    cents, hs = [], []
    for c in cells:
        w = c[..., 3]
        yy, xx = np.mgrid[0:w.shape[0], 0:w.shape[1]]
        cx, cy = (w * xx).sum() / w.sum() + 0.5, (w * yy).sum() / w.sum() + 0.5
        cents.append((cx, cy))
        ys = np.flatnonzero((w / 255.0 > 0.1).any(1))
        hs.append(max(cy - ys.min(), ys.max() + 1 - cy))
    W = CLOUD_W
    H = 2 * int(np.ceil(max(hs) * k)) + 4
    frames = [L.finish(L.warp(c, W, H, lambda U, V, cx=cx, cy=cy: (cx + (U - W / 2) / k, cy + (V - H / 2) / k)))
              for c, (cx, cy) in zip(cells, cents)]
    strip = np.concatenate(frames, 1)
    os.makedirs("assets/effects", exist_ok=True)
    Image.fromarray(strip, "RGBA").save("assets/effects/bloat_cloud.png")
    print(f"bloat_cloud: {len(frames)} frames {W}x{H}")
    return {"bloat_cloud": (len(frames), W, H)}


# ---------------------------------------------------------------- capacitor works

BUILDING = dict(path="art/clockwork/capacitor_works.png", kind="capacitor_works",
                states=["built", "construction", "damaged", "destroyed"],
                panels=[0, 390, 775, 1150, 1536], width=76)


def smoke_or_blue(rgb, kind):
    """Round 4's painted-light test plus grey smoke (low chroma, lighter than the slate)
    for the building's damaged / destroyed pictures."""
    if kind == "blue_smoke":
        mx, mn = rgb.max(-1), rgb.min(-1)
        smoke = (mx - mn <= 26) & (rgb.mean(-1) >= 70) & (rgb.mean(-1) <= 200)
        return _glow4(rgb, "blue") | smoke
    return _glow4(rgb, kind)


_glow4 = r4.glow_kind


def building_pictures():
    px = load(BUILDING["path"])
    bg, bgc = bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 6)[lab - 1] & (lab > 0))
    pics = []
    P = BUILDING["panels"]
    for a, b in zip(P[:-1], P[1:]):
        m = fg.copy()
        m[:, :a] = False
        m[:, b:] = False
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        img = px[y0:y1, x0:x1].copy()
        img[~m[y0:y1, x0:x1]] = 0
        img[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0)
        # the main mass's middle: the mass-weighted median column of the biggest piece
        l2, n2 = ndimage.label(m[y0:y1, x0:x1], structure=np.ones((3, 3)))
        big = l2 == (np.argmax(ndimage.sum(l2 > 0, l2, np.arange(1, n2 + 1))) + 1)
        cx = float(np.median(np.nonzero(big)[1])) + 0.5
        pics.append((img.astype(np.uint8), cx))
    return pics, bgc


def build_building():
    r4.glow_kind = smoke_or_blue
    pics, bgc = building_pictures()
    kind = BUILDING["kind"]
    scale = BUILDING["width"] / pics[0][0].shape[1]
    out = {}
    for state, (img, cx) in zip(BUILDING["states"], pics):
        small, _ = to_game(img, scale, bgc, "blue_smoke")
        # tight crop, then padded sideways so the building's middle is the image's middle
        ys, xs = np.nonzero(small[..., 3] > 0)
        small = small[:ys.max() + 1]
        c = cx * scale
        left, right = c - xs.min(), xs.max() + 1 - c
        half = int(np.ceil(max(left, right)))
        W = 2 * half
        canvas = np.zeros((ys.max() + 1 - ys.min(), W, 4), np.uint8)
        ox = int(round(half - c))
        part = small[ys.min():]
        canvas[:, max(0, ox):ox + part.shape[1]] = part[:, max(0, -ox):W - ox][:, :W - max(0, ox)]
        canvas = clean(canvas, min_size=3, keep_near=1)
        Image.fromarray(canvas, "RGBA").save(f"assets/buildings/{kind}_{state}.png")
        out[state] = canvas
        print(f"{kind}_{state}: {canvas.shape[1]}x{canvas.shape[0]}")
    r4.glow_kind = _glow4
    # icon: the built picture rendered straight from the source at icon size
    img = pics[0][0]
    r4.glow_kind = smoke_or_blue
    icon, _ = to_game(img, 56 / max(img.shape[:2]), bgc, "blue_smoke")
    r4.glow_kind = _glow4
    make_icon(icon, kind)
    return out


def write_building_size(kind, size):
    path = "scripts/art_data.gd"
    src = open(path).read()
    line = f'\t"{kind}": Vector2i({size[0]}, {size[1]}),\n'
    start = src.index("const BUILDING_SIZE := {")
    end = src.index("\n}\n", start) + 1
    block = src[start:end]
    pat = re.compile(r'\t"' + kind + r'": Vector2i\(.*\n')
    if pat.search(block):
        block = pat.sub(lambda m: line, block, count=1)
    else:
        block = block + line
    open(path, "w").write(src[:start] + block + src[end:])


# ---------------------------------------------------------------- units out

ICONS = {
    "ornithopter": (1, "hover", 0, 1.0),      # front three-quarter, wings spread
    "bloater": (1, "drift", 0, 1.0),          # three-quarter view, the sac showing
}


def build_unit(kind):
    S = Src(kind)
    S.OUTLIER = {}                 # the sheets' size changes are drawn on purpose
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
    r4.ICONS.update(ICONS)
    r4.make_unit_icon(S, kind)
    print(f"{kind}: cell {cell[0]}x{cell[1]}, anchor {anchor}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    return S, (cell, anchor, counts)


# ---------------------------------------------------------------- contact sheets

def unit_contact(kind, cell, anchor, counts, ref):
    rk, rn = ref
    data = open("scripts/art_data.gd").read()
    cw = int(re.search(r'"%s": \{"cell": Vector2i\((\d+)' % rk, data).group(1))
    a = np.array(Image.open(f"assets/units/{rk}/{rn}.png").convert("RGBA"))[:, :cw]
    own = np.array(Image.open(f"assets/units/{kind}/idle_s.png").convert("RGBA"))[:, :cell[0]]
    H = max(a.shape[0], own.shape[0])
    pad = [np.concatenate([np.zeros((H - x.shape[0], x.shape[1], 4), np.uint8), x], 0) for x in (a, own)]
    lines = [(f"scale: {rk}/\n{kind}", pad)]
    for an in ("walk", "idle", "attack", "death"):
        for d in DIRS:
            key = f"{an}_{d}"
            if key not in counts:
                continue
            strip = np.array(Image.open(f"assets/units/{kind}/{key}.png").convert("RGBA"))
            frames = []
            for i in range(counts[key]):
                fr = strip[:, i * cell[0]:(i + 1) * cell[0]].copy()
                fr[anchor[1], max(0, anchor[0] - 2):anchor[0] + 3] = (255, 255, 255, 110)
                fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
                fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
                frames.append(fr)
            lines.append((key, frames))
    if kind == "bloater":
        strip = np.array(Image.open("assets/effects/bloat_cloud.png").convert("RGBA"))
        w = CLOUD_W
        frames = []
        for i in range(strip.shape[1] // w):
            fr = strip[:, i * w:(i + 1) * w].copy()
            fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
            fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
            frames.append(fr)
        lines.append(("bloat_cloud", frames))
    icon = np.array(Image.open(f"assets/icons/{kind}.png").convert("RGBA"))
    lines.append(("icon", [icon]))
    r4.contact_sheet(os.path.join(CONTACT, f"contact_{kind}.png"), lines)


def building_contact(imgs):
    kind = BUILDING["kind"]
    ref = [np.array(Image.open(f"assets/buildings/charging_pylon_{s}.png").convert("RGBA"))
           for s in ("built",)]
    own = [imgs[s] for s in BUILDING["states"]]
    H = max(x.shape[0] for x in ref + own)
    pad = [np.concatenate([np.zeros((H - x.shape[0], x.shape[1], 4), np.uint8), x], 0) for x in ref + own]
    icons = [np.array(Image.open(f"assets/icons/{k}.png").convert("RGBA"))
             for k in ("charging_pylon", kind)]
    r4.contact_sheet(os.path.join(CONTACT, "contact_capacitor.png"),
                     [("pylon | built,\nconstr., damaged,\ndestroyed", pad), ("icons", icons)])


def main():
    register()
    entries = {}
    built = {}
    for kind in SHEETS:
        S, entries[kind] = build_unit(kind)
        built[kind] = S
    write_units_data(entries)
    fx = build_cloud(built["bloater"])
    write_effects_data(fx)
    imgs = build_building()
    write_building_size(BUILDING["kind"], imgs["built"].shape[1::-1])
    if CONTACT:
        os.makedirs(CONTACT, exist_ok=True)
        unit_contact("ornithopter", *entries["ornithopter"], ref=("skywing", "idle_s"))
        unit_contact("bloater", *entries["bloater"], ref=("spitter", "idle_s"))
        building_contact(imgs)


if __name__ == "__main__":
    main()
