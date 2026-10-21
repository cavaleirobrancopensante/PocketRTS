"""Battery backpacks for the Clockwork constructs.

Every construct carries its charge in a brass-and-glass cell strapped to its back. The
cell is the designer's battery (art/clockwork/batteries.png, 1536x1024, slate
background): rows 1-2 blue cells from several angles, rows 3-4 the same in yellow, the
bottom row a 14-step charge sequence (empty grey glass, green gauge -> full glass, red
gauge). Yellow is the constructs' normal energy, so the art is yellow:

  charge   the 14 charge columns are the 14 steps of the bottom row. Each step is
           registered on the last one and only its glass tube and gauge tube are taken,
           so the brass and steel are the same pixels at every level (nothing flickers
           as the charge changes). The blue glow and lightning are recoloured to the
           yellow of rows 3-4 (by brightness rank, so the darkest blue becomes the
           darkest yellow and the white cores stay white-hot); the empty grey glass
           and the gauge (green -> red) stay as drawn, the dormant amber lightning in
           the empty glass is greyed (at game size it would read as yellow charge).
  views    s, n   the charge-sequence cell itself (front-on, gauge tube at its side);
           se, ne the row-3 cell with the round dial and gauge bar (mirrored: the dial
                  faces away from the body);
           e      the row-3 cell seen in profile with the scale bar (mirrored).
           The yellow cells are drawn full; a lower charge is made from the sequence:
           row by row, the glass is blended from its full yellow to the empty sequence
           glass (matched by brightness rank) as far as the step at that level is lit,
           and the gauge bar is replaced by the sequence's gauge tube at that level.
  sizes    one scale per pack type (the whole cell, knob to feet, SIZE px tall); the
           ornithopter's sling cell is the charge-sequence cell in every view, lying
           on its side under the belly (charge filling from the tail end, gauge tube
           underneath), a little shorter in se/ne and foreshortened in s/n.
  scaling  box filter with premultiplied alpha and a hard alpha edge, slate fringe and
           specks removed (the import_cannon2 helpers), the outer ring darkened toward
           the sheet's outline colour so the silhouette keeps its dark outline, and
           every colour within reach of the team shader's keys (#FF0000 / #960000; the
           gauge's red comes close) nudged out of it.
  fittings small straps and clamps that hold the cell on, drawn after scaling in
           steel and brass sampled from the sheet: shoulder straps and a clamped waist
           band from behind (n, ne), clamp arms into the back and a shoulder strap in
           profile (e, se), straps over the shoulders from the front (s), two hangers up
           to the belly on the sling.

Output:
  assets/effects/pack_<type>.png   one row per view (s, se, e, ne, n), one column per
                                   charge level 0..13 (0 = empty grey glass)
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
  --preview DIR    also writes contact sheets of every strip with the pack on (x4/x6)
  --art-only DIR   only writes the pack sheets, into DIR (no table, nothing in assets)
  --blue           keeps the sequence blue (art for blue energy; with --art-only)
Needs Pillow, NumPy and SciPy.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_cannon2 import bg_mask, clean, defringe  # noqa: E402

VIEWS = ["s", "se", "e", "ne", "n"]
LEVELS = 14

# ---------------------------------------------------------------- the designer's sheet

SHEET = "art/clockwork/batteries.png"
CHARGE_ROW = (780, 945)                 # y band of the bottom row (the charge sequence)
# glass tube and gauge tube of the charge cell, sheet coords on its LAST step
SEQ_GLASS = (1427, 829, 1457, 908)
SEQ_GAUGE = (1459, 829, 1478, 908)
# yellow cells (row 3) for the turned views: crop box, glass tube, gauge bar
YELLOW = {
    "quarter": dict(box=(408, 434, 482, 580), glass=(420, 475, 449, 549), bar=(459, 515, 468, 546)),
    "profile": dict(box=(1432, 438, 1500, 580), glass=(1445, 480, 1482, 549), bar=(1483, 485, 1491, 546)),
}
VIEW_ART = {"s": "seq", "n": "seq", "se": "quarter", "ne": "quarter", "e": "profile"}

# per pack type: height of the whole cell in game px, and its canvas (the PACKS cell;
# the cell's feet sit on row FEET of it, centred across)
SIZE = {"small": 14, "medium": 18, "large": 26, "sling": 14}
CANVAS = {"small": (20, 24), "medium": (22, 28), "large": (30, 38), "sling": (22, 18)}
FEET = {"small": 19, "medium": 22, "large": 31}
SLING_CENTRE = (10.5, 9.5)
SLING_SHORT = 0.62                      # length of the s/n (foreshortened) sling view

TEAM_KEYS = (np.array([255, 0, 0]), np.array([150, 0, 0]))
KEY_REACH = 0.08 * 255 + 2              # the team shader's distance, plus a margin


def lum(rgb):
    return rgb[..., :3].astype(float).sum(-1)


def is_charged(rgb):
    """Blue glow and its white-hot lightning cores (the cores only next to blue)."""
    c = rgb[..., :3].astype(int)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    blue = (b - r > 50) & (b - g > 20)
    white = (lum(c) > 600) & (b >= r) & ndimage.binary_dilation(blue, iterations=3)
    return blue | white


def is_yellow(rgb):
    c = rgb[..., :3].astype(float)
    return ((c[..., 0] + c[..., 1]) / 2 - c[..., 2] > 60) | (lum(c) > 600)


class RankMap:
    """Recolour by brightness rank: a pixel's rank among the `src` colours picks the
    colour at the same rank among the `dst` colours (averaged over a small window)."""

    def __init__(self, src, dst):
        self.src = np.sort(lum(src))
        o = np.argsort(lum(dst))
        self.dst = dst[o].astype(float)

    def __call__(self, px):
        q = np.searchsorted(self.src, lum(px)) / max(1, len(self.src))
        n = len(self.dst)
        k = np.clip((q * (n - 1)).astype(int), 0, n - 1)
        w = max(1, n // 60)
        cs = np.concatenate([np.zeros((1, 3)), np.cumsum(self.dst, 0)])
        lo, hi = np.clip(k - w, 0, n), np.clip(k + w + 1, 0, n)
        return (cs[hi] - cs[lo]) / (hi - lo)[:, None]


def sub(r, box):
    """Rect r (sheet coords) as slices of a crop starting at box[:2]."""
    return slice(r[1] - box[1], r[3] - box[1]), slice(r[0] - box[0], r[2] - box[0])


class Source:
    """The sheet, cut and registered: the charge-sequence steps (full-res RGB on the
    last step's crop box) and the yellow cells, plus the colour maps between them."""

    def __init__(self, blue=False):
        px = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.uint8)
        self.px = px
        self.blue = blue
        y0, y1 = CHARGE_ROW
        bgc = np.median(px[:5, :5].reshape(-1, 3), 0)
        band = np.abs(px[y0:y1].astype(int) - bgc).sum(-1) > 40
        lab, n = ndimage.label(ndimage.binary_dilation(band.any(0), iterations=6))
        xs = [np.flatnonzero(lab == i) for i in range(1, n + 1)]
        xs = [(x[0], x[-1] + 1) for x in xs if len(x) >= 30]
        assert len(xs) == LEVELS, xs
        rx0, rx1 = xs[-1]
        self.box = (rx0 - 8, y0, rx1 + 8, y1)       # the last step's crop
        bx0, by0, bx1, by1 = self.box
        ref = px[by0:by1, bx0:bx1].astype(float)
        self.steps = []
        for x0, _ in xs:
            best = None
            for dy in range(-4, 5):
                for dx in range(-10, 11):
                    ox, oy = bx0 + (x0 - rx0) + dx, by0 + dy
                    c = px[oy:oy + by1 - by0, ox:ox + bx1 - bx0].astype(float)
                    d = np.abs(c[:55] - ref[:55]).mean() + np.abs(c[-40:] - ref[-40:]).mean()
                    if best is None or d < best[0]:
                        best = (d, c)
            self.steps.append(best[1].astype(np.uint8))
        # the dormant lightning in the empty glass is drawn amber: next to yellow energy
        # it would read as charge at game size, so it is greyed (kept a little warm)
        g = sub(SEQ_GLASS, self.box)
        for s in self.steps:
            c = s[g].astype(float)
            warm = ~is_charged(s[g]) & (c[..., 0] - c[..., 2] > 30)
            grey = c.mean(-1, keepdims=True)
            d = (grey * 0.75 + c * 0.25) * 0.8
            s[g] = np.where(warm[..., None], d, c).clip(0, 255).astype(np.uint8)
        bg, self.bgc = bg_mask(np.dstack([px[by0:by1, bx0:bx1], np.full(ref.shape[:2], 255, np.uint8)]))
        self.alpha = np.where(bg, 0, 255).astype(np.uint8)
        g = sub(SEQ_GLASS, self.box)
        last = self.steps[-1][g]
        blues = last[is_charged(last)]
        yb = YELLOW["profile"]
        yel = px[yb["glass"][1]:yb["glass"][3], yb["glass"][0]:yb["glass"][2]]
        self.yellows = yel[is_yellow(yel)]
        self.to_yellow = RankMap(blues, self.yellows)
        # how far each glass row is lit at each step, against the last step
        full = is_charged(last).mean(1)
        self.lit = []
        for s in self.steps:
            f = is_charged(s[g]).mean(1)
            f = np.where(full > 0.15, f / np.maximum(full, 1e-6), f > 0.1)
            f = np.convolve(np.pad(f.clip(0, 1), 3, mode="edge"), np.ones(7) / 7, "valid")
            self.lit.append(f)
        self.lit[-1][:] = 1.0
        self.empty = self.steps[0][g].reshape(-1, 3)

    def recolour(self, rgb):
        if self.blue:
            return rgb
        out = rgb.copy()
        m = is_charged(out)
        if m.any():
            out[m] = self.to_yellow(out[m]).clip(0, 255).astype(np.uint8)
        return out

    def seq_cell(self, level):
        """Full-res RGBA of the charge cell at a level: the last step's metal, the
        level's glass and gauge."""
        img = self.steps[-1].copy()
        for r in (SEQ_GLASS, SEQ_GAUGE):
            s = sub(r, self.box)
            img[s] = self.steps[level][s]
        return np.dstack([self.recolour(img), self.alpha])

    def yellow_cell(self, name, level):
        """Full-res RGBA of a row-3 yellow cell at a level (see the docstring)."""
        d = YELLOW[name]
        bx0, by0, bx1, by1 = d["box"]
        crop = self.px[by0:by1, bx0:bx1].copy()
        bg, _ = bg_mask(np.dstack([crop, np.full(crop.shape[:2], 255, np.uint8)]))
        if self.blue:
            # blue energy: the matching blue cell two rows up (same drawing)
            up = 434 - 76
            crop = self.px[by0 - up:by1 - up, bx0:bx1].copy()
            bg, _ = bg_mask(np.dstack([crop, np.full(crop.shape[:2], 255, np.uint8)]))
        g = sub(d["glass"], d["box"])
        glass = crop[g].astype(float)
        sel = is_yellow(glass) if not self.blue else is_charged(glass)
        empty = RankMap(glass[sel], self.empty)
        lit = self.lit[level]
        t = np.interp(np.linspace(0, 1, glass.shape[0]), np.linspace(0, 1, len(lit)), lit)
        e = np.zeros_like(glass)
        e[sel] = empty(glass[sel])
        k = t[:, None, None] * np.ones_like(glass[..., :1])
        mix = np.where(sel[..., None], glass * k + e * (1 - k), glass)
        crop[g] = mix.clip(0, 255).astype(np.uint8)
        # the gauge bar shows the sequence's gauge tube at this level
        b = sub(d["bar"], d["box"])
        bh, bw = crop[b].shape[:2]
        tube = self.recolour(self.steps[level][sub(SEQ_GAUGE, self.box)])
        crop[b] = np.array(Image.fromarray(tube).resize((bw, bh), Image.BOX))
        return np.dstack([crop, np.where(bg, 0, 255).astype(np.uint8)])

    def cell(self, view, level):
        name = VIEW_ART[view]
        img = self.seq_cell(level) if name == "seq" else self.yellow_cell(name, level)[:, ::-1]
        ys, xs = np.nonzero(img[..., 3])
        return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()


# ---------------------------------------------------------------- scaling

def shrink(img, w, h):
    """Area-average downscale to w x h with premultiplied alpha, then a hard alpha edge."""
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((w, h), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def outline(img, col, k=0.6):
    """Darken the outer ring toward the sheet's outline colour."""
    a = img[..., 3] > 0
    edge = a & ~ndimage.binary_erosion(a, structure=np.ones((3, 3)))
    out = img.copy()
    rgb = out[..., :3].astype(float)
    rgb[edge] = rgb[edge] * (1 - k) + np.array(col, float) * k
    out[..., :3] = rgb.clip(0, 255).astype(np.uint8)
    return out


def unkey(img):
    """Nudge every colour the team shader would swap out of its reach (lift green and
    blue: the gauge's red stays red)."""
    out = img.copy()
    a = out[..., 3] > 0
    for _ in range(12):
        rgb = out[..., :3].astype(float)
        hit = np.zeros(a.shape, bool)
        for key in TEAM_KEYS:
            hit |= a & (np.sqrt(((rgb - key) ** 2).sum(-1)) < KEY_REACH)
        if not hit.any():
            break
        rgb[hit, 1] += 8
        rgb[hit, 2] += 4
        out[..., :3] = np.where(hit[..., None], rgb.clip(0, 255), out[..., :3]).astype(np.uint8)
    return out


def small(src, img, w, h):
    out = shrink(img, w, h)
    out = defringe(out, src.bgc)
    out = clean(out, min_size=3, keep_near=1)
    return outline(out, src.ink)


# ---------------------------------------------------------------- fittings

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

    def paste(self, img, x0, y0):
        h, w = img.shape[:2]
        m = img[..., 3] > 0
        self.a[y0:y0 + h, x0:x0 + w][m] = img[m]


def metal(src):
    """Steel and brass ramps (dark -> light) and the outline colour, sampled from the
    last charge step's caps."""
    img = src.steps[-1].astype(int)
    a = src.alpha > 0
    for r in (SEQ_GLASS, SEQ_GAUGE):
        a[sub(r, src.box)] = False
    c = img[a]
    L = c.sum(-1)
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    brass = c[(r - b > 70) & (r > g) & (g > b) & (L > 150)]
    steel = c[(c.max(-1) - c.min(-1) < 28) & (L > 90)]

    def ramp(p, qs):
        o = np.argsort(p.sum(-1))
        return [tuple(int(v) for v in np.median(p[o[int(q * (len(o) - 1)) - 3:int(q * (len(o) - 1)) + 4]], 0))
                for q in qs]
    src.ink = tuple(int(v) for v in np.median(c[L <= np.percentile(L, 4)], 0))
    return ramp(brass, (0.1, 0.35, 0.65, 0.92)), ramp(steel, (0.08, 0.35, 0.65, 0.9))


def strap(cv, pts, ST, wide=False):
    """A steel strap along a pixel path, dark under-edge."""
    for i, (x, y) in enumerate(pts):
        cv.px(x, y, ST[2] if i % 3 else ST[3])
        if wide:
            cv.px(x, y + 1, ST[1])
        if cv.get(x, y + (2 if wide else 1)) is None:
            cv.px(x, y + (2 if wide else 1), ST[0])


def upright(src, t, view, level, pals):
    """One view of a standing backpack cell at a level, with its straps and clamps, on
    the type's canvas."""
    BR, ST = pals
    W, H = CANVAS[t]
    big = t == "large"
    full = src.cell(view, level)
    k = SIZE[t] / src.seq_h
    h = max(1, int(round(full.shape[0] * k)))
    w = max(1, int(round(full.shape[1] * k)))
    img = small(src, full, w, h)
    cv = Canvas(W, H)
    x0 = (W - w) // 2
    top = FEET[t] - h
    # the body proper (below the knob) for the fittings: the cap rim is ~13% down
    y0 = top + int(round(h * 0.13))
    ys, xs = np.nonzero(img[h // 2:, :, 3])
    bx0, bx1 = x0 + xs.min(), x0 + xs.max() + 1
    bw = bx1 - bx0
    if view in ("n", "ne"):
        lx, rx = bx0 + 1, bx1 - 2
        left = [(lx, y0 - 1), (lx - 1, y0 - 2), (lx - 1, y0 - 3), (lx - 2, y0 - 4)]
        right = [(rx, y0 - 1), (rx + 1, y0 - 2), (rx + 1, y0 - 3), (rx + 2, y0 - 4)]
        if view == "ne":
            right = right[:3]
        if big:
            left += [(lx - 2, y0 - 5), (lx - 3, y0 - 6)]
            right += [(rx + 2, y0 - 5), (rx + 3, y0 - 6)]
        strap(cv, left, ST, big)
        strap(cv, right, ST, big)
    cv.paste(img, x0, top)
    by = FEET[t] - max(3, int(round(h * 0.2)))
    if view in ("n", "ne"):
        span = 2 if not big else 3
        for kk in range(1, span + 1):
            cv.px(bx0 - kk, by, ST[2])
            cv.px(bx0 - kk, by + 1, ST[0])
            if view == "n" or kk < span:
                cv.px(bx1 - 1 + kk, by, ST[2])
                cv.px(bx1 - 1 + kk, by + 1, ST[0])
        cv.px(bx0, by, BR[3])
        cv.px(bx1 - 1, by, BR[2])
    if view in ("e", "se"):
        # in profile the back is on the right: two brass clamp arms reach into it, the
        # shoulder strap runs from the top forward over the shoulder
        for cy in (y0 + 2 + (1 if big else 0), FEET[t] - max(4, int(round(h * 0.25)))):
            for kk in range(0, 3 if not big else 4):
                cv.px(bx1 - 1 + kk, cy, BR[2] if kk == 0 else BR[1])
                cv.px(bx1 - 1 + kk, cy + 1, BR[0])
            cv.px(bx1 - 1, cy, BR[3])
        if view == "e":
            tp = [(bx1 - 2, y0 - 1), (bx1 - 1, y0 - 2), (bx1, y0 - 2), (bx1 + 1, y0 - 2), (bx1 + 2, y0 - 1)]
            if big:
                tp = [(bx1 - 3, y0 - 1), (bx1 - 2, y0 - 2), (bx1 - 1, y0 - 3), (bx1, y0 - 3),
                      (bx1 + 1, y0 - 3), (bx1 + 2, y0 - 2), (bx1 + 3, y0 - 1)]
            strap(cv, tp, ST, big)
    if view == "s":
        lx, rx = bx0 + 1, bx1 - 2
        strap(cv, [(lx, y0 - 1), (lx - 1, y0 - 1)], ST, big)
        strap(cv, [(rx, y0 - 1), (rx + 1, y0 - 1)], ST, big)
    return cv.a


def sling(src, view, level, pals):
    """The ornithopter's cell, lying under the belly along the fuselage: the upright cell
    turned so its feet point to the tail (the charge fills from the tail end toward the
    nose), foreshortened when seen from the front or back; two hangers up to the belly."""
    BR, ST = pals
    W, H = CANVAS["sling"]
    # always the charge-sequence cell (gauge tube underneath): the turned cells' dial
    # turns to mud at this size
    full = np.ascontiguousarray(np.rot90(src.cell("s", level), -1))   # feet -> left (tail)
    k = SIZE["sling"] / src.seq_h
    L = full.shape[1] * k * {"s": SLING_SHORT, "n": SLING_SHORT, "se": 0.85, "ne": 0.85}.get(view, 1.0)
    D = full.shape[0] * k
    w, h = max(1, int(round(L))), max(1, int(round(D)))
    img = small(src, full, w, h)
    cv = Canvas(W, H)
    x0 = int(round(SLING_CENTRE[0] - w / 2 + 0.5))
    y0 = int(round(SLING_CENTRE[1] - h / 2 + 0.5))
    for hx in ((x0 + 2, x0 + w - 3) if w >= 8 else (x0 + 1, x0 + w - 2)):
        cv.px(hx, y0 - 1, ST[2])
        cv.px(hx, y0 - 2, ST[1])
    cv.paste(img, x0, y0)
    for hx in ((x0 + 2, x0 + w - 3) if w >= 8 else (x0 + 1, x0 + w - 2)):
        cv.px(hx, y0, BR[3])
    return cv.a


TYPES = ("small", "medium", "large", "sling")


def build_sheets(blue=False):
    src = Source(blue)
    src.seq_h = src.cell("s", 0).shape[0]
    pals = metal(src)
    sheets, cells = {}, {}
    for t in TYPES:
        cw, ch = CANVAS[t]
        sheet = np.zeros((ch * len(VIEWS), cw * LEVELS, 4), np.uint8)
        for r, v in enumerate(VIEWS):
            for lv in range(LEVELS):
                c = sling(src, v, lv, pals) if t == "sling" else upright(src, t, v, lv, pals)
                assert c.shape[:2] == (ch, cw), (t, c.shape)
                sheet[r * ch:(r + 1) * ch, lv * cw:(lv + 1) * cw] = c
        sheet = unkey(sheet)
        rgb = sheet[..., :3][sheet[..., 3] > 0]
        for key in TEAM_KEYS:
            assert not (rgb == key).all(-1).any(), (t, key)
        sheets[t], cells[t] = sheet, (cw, ch)
    return sheets, cells


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
    blue = "--blue" in sys.argv
    sheets, cells = build_sheets(blue)
    if "--art-only" in sys.argv:
        out = sys.argv[sys.argv.index("--art-only") + 1]
        os.makedirs(out, exist_ok=True)
        for t in TYPES:
            Image.fromarray(sheets[t]).save(f"{out}/pack_{t}{'_blue' if blue else ''}.png")
        return
    if blue:
        raise SystemExit("--blue is for --art-only")
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
