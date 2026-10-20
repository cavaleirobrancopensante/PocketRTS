"""Round 8 art: the Skywing on the ground and the Bloater deflated.

Sources (generated sheets, 1536x1024, flat slate background, five rows = directions
s, se, e, ne, n top to bottom):
  art/brood/skywing_grounded.png  per row, groups LAND (wings spread, coming down;
                                  3 frames in row 1, 4 in the others), GROUND WALK
                                  (row 1: 3, others 4; a four-legged prowl, wings folded),
                                  GROUND IDLE (3), GROUND ATTACK (3), GROUND DEATH (3)
  art/brood/bloater_deflated.png  per row 17 frames: DEFLATE (5, the sac shrinking from
                                  full to empty), DEFLATED FLY (4), REFILL (4, swelling
                                  back up), DEFLATED DEATH (4, ending in a gas puff)

The frames are cut and converted with the round 4 machinery (tools/import_round4.py:
slate mask, box-filter shrink, team reds snapped to the key colours #FF0000 / #960000,
specks and slate fringe removed; touching figures split at their thinnest column as in
round 5). They are added to the existing "skywing" and "bloater" units: the units' own
cell and anchor (read from scripts/art_data.gd) are kept. Frames reaching above the cell
get extra rows on top of the strip (unit.gd keeps the anchor at the same distance from
the strip's bottom, as for the musketeer's aim-up and the grub's cocoon strips); frames
reaching past the cell's right edge would get extra columns on the right (the sprite is
not centred: its offset is -anchor, so the anchor's x from the left edge is all that
counts). Nothing reaches past the left edge or below the cell (checked, warned).

Skywing: one scale for the whole sheet (SKY_SCALE): the landing frames (wings spread,
front view) come out the size of the flying Skywing's front view, the grounded body
reads as the same creature. Feet on the anchor.
Bloater: one scale for the sheet, the one that makes the first (still full) deflate
frame as tall, crest tip to tendril ends, as the existing idle frames (median over the
directions). The anchor follows
the crest (the sac shrinks and swells under it), placed where the existing idle frames
have their crest relative to the anchor, so the full sac sits where the existing art
puts it.

Output:
  assets/units/skywing/{land,gwalk,gidle,gattack,gdeath}_<dir>.png
  assets/units/bloater/{deflate,dwalk,refill,ddeath}_<dir>.png
  the new keys in the "skywing" and "bloater" entries' "frames" of UNITS in
  scripts/art_data.gd (targeted edits; nothing else in the file is touched)

Runs after tools/import_round5.py (which rebuilds the bloater and its art_data entry);
see tools/rebuild_art.sh.

Usage (from the repo root): python3 tools/import_round8.py [--contact DIR] [--debug DIR]
(--contact writes x3 contact sheets on grass green; --debug draws the frame boxes on the
sheets). Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_round4 as r4  # noqa: E402
import import_round5 as r5  # noqa: E402
from import_round4 import F, body_of, place, steady, to_game  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
DEBUG = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None


# ---------------------------------------------------------------- sheets

SHEETS = {
    "skywing_ground": dict(
        path="art/brood/skywing_grounded.png", rows=[218, 392, 562, 760],
        groups=["land", "walk", "idle", "attack", "death"],
        counts=[[3, 3, 3, 3, 3]] + [[4, 4, 3, 3, 3]] * 4,
        panels=[[0, 358, 672, 900, 1220, 1536]] * 5),
    "bloater_deflated": dict(
        path="art/brood/bloater_deflated.png", rows=[233, 410, 592, 778],
        groups=["deflate", "fly", "refill", "death"],
        counts=[[5, 4, 4, 4]] * 5,
        panels=[[0, 400, 742, 1090, 1536]] * 5),
}

SKY_SCALE = 0.37          # landing front view (wings spread) ~ the flying front view
BLOATER_SCALE = 0.4       # first guess (round 5's), then fitted to the existing art
UNITS = {
    "skywing_ground": dict(scale=SKY_SCALE, norm=[]),
    "bloater_deflated": dict(scale=BLOATER_SCALE, norm=[]),
}

# frames with painted light un-blended from the slate: (sheet, group, index) -> kind
GLOW = {("bloater_deflated", "death", 3): "puff"}

_glow4 = r4.glow_kind


def glow_kind(rgb, kind):
    """Round 4's painted-light test plus the deflated bloater's last gas: a dull grey
    green, lighter than the slate."""
    if kind == "puff":
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        return (g >= r - 4) & (g >= b + 6) & (rgb.mean(-1) >= 70)
    return _glow4(rgb, kind)


def seam(m, lo, hi, guess, step=2):
    """A cut from the top of m to the bottom, one x per row, moving at most step columns
    a row, through as few figure pixels as it can between columns lo..hi: the landing
    Skywings' raised wings reach over the frame before them, so no straight column
    separates them."""
    sub = m[:, lo:hi].astype(float)
    h, w = sub.shape
    cost = sub + 0.003 * np.abs(np.arange(w) + lo - guess)[None, :]
    acc = cost[0].copy()
    back = np.zeros((h, w), int)
    for y in range(1, h):
        best = np.full(w, np.inf)
        arg = np.zeros(w, int)
        for dx in range(-step, step + 1):
            sh = np.full(w, np.inf)
            if dx >= 0:
                sh[dx:] = acc[:w - dx] if dx else acc
            else:
                sh[:dx] = acc[-dx:]
            sh = sh + 0.02 * abs(dx)
            better = sh < best
            best[better] = sh[better]
            arg[better] = (np.arange(w) - dx)[better]
        acc = best + cost[y]
        back[y] = arg
    xs = np.zeros(h, int)
    xs[-1] = int(np.argmin(acc))
    for y in range(h - 1, 0, -1):
        xs[y - 1] = back[y, xs[y]]
    return xs + lo


def extract(kind):
    """Round 4's extract with seams instead of straight column cuts between the frames of
    a group (see seam); the panel edges stay straight. Pieces still go whole to the frame
    holding 80% of them."""
    cfg = r4.SHEETS[kind]
    px = r4.load(cfg["path"])
    bg, bgc = r4.bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 4)[lab - 1] & (lab > 0))
    bands = r4.row_bands(fg, cfg["rows"])
    H, W = fg.shape
    out = {}
    for r, band in enumerate(bands):
        m = fg & band
        ys_band = np.flatnonzero(m.any(1))
        y0, y1 = ys_band.min(), ys_band.max() + 1
        mb = m[y0:y1]
        cuts = []                      # per cut: x for every row y0..y1
        for g, cnt in enumerate(cfg["counts"][r]):
            a, b = cfg["panels"][r][g], cfg["panels"][r][g + 1]
            cc = r5.run_cuts(m, a, b, cnt)
            cuts.append(np.full(y1 - y0, a))
            for k in range(1, cnt):
                fix = SEAM_FIX.get((kind, r, cfg["groups"][g], k))
                if fix:
                    ys = np.arange(y0, y1)
                    xs = np.full(y1 - y0, fix[0][1])
                    for fy, fx in fix:
                        xs[ys >= fy] = fx
                    cuts.append(xs)
                    continue
                half = int((cc[k + 1] - cc[k - 1]) * 0.22)
                lo, hi = max(a + 1, cc[k] - half), min(b - 1, cc[k] + half)
                cuts.append(seam(mb, lo, hi, cc[k]))
        cuts.append(np.full(y1 - y0, W))
        cuts = np.array(cuts)          # (slots + 1, rows)
        if DEBUG:
            SEAMS.setdefault(kind, []).append((y0, cuts[1:-1]))
        yy, xx = np.nonzero(mb)
        slot = (xx[None, :] >= cuts[:, yy]).sum(0) - 1
        nslot = len(cuts) - 1
        lab, n = ndimage.label(mb, structure=np.ones((3, 3)))
        ls = lab[yy, xx]
        mass = np.zeros((n + 1, nslot))
        np.add.at(mass, (ls, slot), 1)
        whole = mass.max(1) >= 0.8 * mass.sum(1)
        own = mass.argmax(1)
        slots = np.full(mb.shape, -1, int)
        slots[yy, xx] = np.where(whole[ls], own[ls], slot)
        k = 0
        for g, cnt in enumerate(cfg["counts"][r]):
            for i in range(cnt):
                fm = slots == k
                for ex0, ey0, ex1, ey1, *only in ERASE.get((kind, r, cfg["groups"][g], i), []):
                    sl = (slice(max(0, ey0 - y0), max(0, ey1 - y0)), slice(ex0, ex1))
                    if only:           # "red": only the reddish pixels in the rectangle
                        c = px[y0:y1][sl].astype(int)
                        fm[sl] &= ~(c[..., 0] >= c[..., 1] + 30)
                    else:
                        fm[sl] = False
                fy, fx = np.nonzero(fm)
                fy0, fy1, fx0, fx1 = fy.min(), fy.max() + 1, fx.min(), fx.max() + 1
                img = px[y0 + fy0:y0 + fy1, fx0:fx1].copy()
                sel = fm[fy0:fy1, fx0:fx1]
                img[~sel] = 0
                img[..., 3] = np.where(sel, 255, 0)
                out.setdefault((r, cfg["groups"][g]), []).append(
                    dict(img=img.astype(np.uint8), x0=fx0, y0=y0 + fy0, x1=fx1, y1=y0 + fy1))
                k += 1
    return out, bgc


SEAMS = {}

# Cuts read off the sheet where the seam picks the wrong side of an overlap:
# (sheet, row, group, cut k between frames k-1 and k) -> [(from sheet y, x), ...]
SEAM_FIX = {
    # NE landing: frame 1's far wing hangs down beside frame 0's snout
    ("skywing_ground", 3, "land", 1): [(0, 100), (678, 106)],
}

# Pieces painted out of single frames: (sheet, row, group, index) -> sheet rectangles.
ERASE = {
    # NE landing 1: a faint red drip under the far wing (turns into a dark stalk)
    ("skywing_ground", 3, "land", 1): [(105, 680, 116, 708)],
    # E walk 1: the tip of frame 2's tail curls under its chin
    ("skywing_ground", 2, "walk", 1): [(509, 484, 525, 508, "red")],
}


def debug_seams(kind):
    im = np.array(Image.open(r4.SHEETS[kind]["path"]).convert("RGB"))
    for y0, cuts in SEAMS.get(kind, []):
        for c in cuts:
            ys = np.arange(len(c)) + y0
            im[ys, np.clip(c, 0, im.shape[1] - 1)] = (255, 255, 0)
    Image.fromarray(im).save(os.path.join(DEBUG, f"seams_{kind}.png"))


def register():
    r4.SHEETS.update(SHEETS)
    r4.UNITS.update(UNITS)
    r4.column_cuts = r5.run_cuts
    r4.extract = extract
    r4.feet = r5.feet
    r4.glow_kind = glow_kind


class Src8(r4.Src):
    """Round 4's Src with one scale factor per row (no per-group normalising, no outlier
    resizing: the deflating sac is meant to change size)."""
    OUTLIER = {}

    def __init__(self, kind, row_factor=None):
        r4.Src.__init__(self, kind)
        self.row_factor = row_factor or {}

    def factor(self, r, g):
        return self.row_factor.get(r, 1.0)

    def raw(self, r, g, i, scale):
        glow = GLOW.get((self.kind, g, i))
        img, gl = to_game(self.frames[(r, g)][i]["img"], scale, self.bgc, glow)
        if self.kind == "skywing_ground":
            return F(img, gl, *four_feet(img, gl))
        return F(img, gl)


def four_feet(img, glow):
    """Ground point of a four-legged figure: the lowest row of the body and the middle
    between its outermost feet (the median of the lowest pixels, round 4's rule, sits on
    whichever paw is drawn bigger: a lunging Skywing would stand on its hind foot)."""
    a = body_of(img, glow)
    ys, xs = np.nonzero(a)
    bottom = int(np.flatnonzero(np.bincount(ys) >= 2).max())
    low = ys >= bottom - max(2, (bottom - ys.min()) * 0.15)
    return (xs[low].min() + xs[low].max() + 1) / 2.0, float(bottom + 1)


# ---------------------------------------------------------------- art_data

def unit_entry(kind):
    src = open("scripts/art_data.gd").read()
    m = re.search(r'"%s": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)' % kind, src)
    return (int(m.group(1)), int(m.group(2))), (float(m.group(3)), float(m.group(4)))


def write_frames(kind, counts):
    """Add / replace the given keys in the kind's "frames" (re-read right before). Only
    the keys' own lines change: other lines (even a duplicated key) are left as they are;
    new keys go in sorted among the existing ones."""
    path = "scripts/art_data.gd"
    src = open(path).read()
    start = src.index('\t"%s": {"cell"' % kind)
    end = src.index("\n\t}},\n", start) + 1
    head, *lines = src[start:end].split("\n")
    lines = [ln for ln in lines if ln]
    for k, n in sorted(counts.items()):
        line = f'\t\t"{k}": {n},'
        hit = [i for i, ln in enumerate(lines) if ln.startswith(f'\t\t"{k}": ')]
        if hit:
            lines[hit[0]] = line
        else:
            pos = next((i for i, ln in enumerate(lines) if ln > line), len(lines))
            lines.insert(pos, line)
    block = head + "\n" + "\n".join(lines) + "\n"
    open(path, "w").write(src[:start] + block + src[end:])


def write_strips(kind, A, cell, anchor):
    """Strips on the unit's own cell, the frame's anchor on the cell's anchor. Extra rows
    on top / columns on the right when frames reach out of the cell."""
    (cw, ch), (ax, ay) = cell, anchor
    # a frame reaching past the cell's left edge (a lunge) or below it is moved right / up
    # just enough to fit: the strip cannot grow to the left or downwards
    for (anim, d), fr in sorted(A.items()):
        for i, f in enumerate(fr):
            xs = np.flatnonzero((f.img[..., 3] > 0).any(0))
            over = f.ax - xs.min() - ax
            if over > 0.5:
                f.ax -= np.ceil(over - 0.5)
                print(f"  {kind} {anim}_{d} {i}: moved {np.ceil(over - 0.5):g} px right to fit the cell")
            ys = np.flatnonzero((f.img[..., 3] > 0).any(1))
            over = ys.max() + 1 - f.ay - (ch - ay)
            if over > 0.5:
                f.ay += np.ceil(over - 0.5)
                print(f"  {kind} {anim}_{d} {i}: moved {np.ceil(over - 0.5):g} px up to fit the cell")
    L = R = U = D = 0
    for fr in A.values():
        for f in fr:
            h, w = f.img.shape[:2]
            ys, xs = np.nonzero(f.img[..., 3] > 0)
            L, R = max(L, f.ax - xs.min()), max(R, xs.max() + 1 - f.ax)
            U, D = max(U, f.ay - ys.min()), max(D, ys.max() + 1 - f.ay)
    if L > ax + 0.5 or D > ch - ay + 0.5:
        print(f"  WARNING: {kind} frames reach L{L:.1f} D{D:.1f}, cell allows L{ax:g} "
              f"D{ch - ay:g}: clipped")
        for (anim, d), fr in sorted(A.items()):
            for i, f in enumerate(fr):
                ys, xs = np.nonzero(f.img[..., 3] > 0)
                l, dn = f.ax - xs.min(), ys.max() + 1 - f.ay
                if l > ax + 0.5 or dn > ch - ay + 0.5:
                    print(f"    {anim}_{d} {i}: L{l:.1f} D{dn:.1f}")
    extra = max(0, int(np.ceil(U - ay - 0.5)))
    wide = max(0, int(np.ceil(R - (cw - ax) - 0.5)))
    W, H = cw + wide, ch + extra
    counts = {}
    out = f"assets/units/{kind}"
    for (anim, d), fr in sorted(A.items()):
        strip = np.concatenate([place(f, W, H, ax, ay + extra)[0] for f in fr], 1)
        Image.fromarray(strip).save(f"{out}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(fr)
    print(f"{kind}: cell {cw}x{ch} anchor ({ax:g}, {ay:g}); new strips {W}x{H} per frame "
          f"({extra} extra rows on top, {wide} extra columns on the right); reach "
          f"L{L:.1f} R{R:.1f} up {U:.1f} down {D:.1f}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    write_frames(kind, counts)
    return counts, (W, H), (ax, ay + extra)


# ---------------------------------------------------------------- skywing

SKY_ANIMS = ["land", "gwalk", "gidle", "gattack", "gdeath"]


def plan_skywing(S):
    """Rows as drawn: 0 = S, 1 = SE, 2 = E, 3 = NE, 4 = N. Landing, walk and idle face
    their row's way, except: row 0's walk is drawn side-on facing right (no front-view
    prowl exists; used as drawn), and the idle of rows 1 and 3 faces the camera. The
    attack and death of every row, also row 4 (N), are drawn side-on facing right: used
    as drawn. Feet on the anchor; walks held by the body (top 60%), the rest by the legs."""
    A = {}
    for r, d in enumerate(DIRS):
        A["land", d] = steady(S.seq(r, "land"), "low")
        A["gwalk", d] = steady(S.seq(r, "walk"), "high")
        A["gidle", d] = steady(S.seq(r, "idle"))
        A["gattack", d] = steady(S.seq(r, "attack"))
        A["gdeath", d] = S.seq(r, "death")
    return A


def build_skywing():
    S = Src8("skywing_ground")
    if DEBUG:
        debug_seams("skywing_ground")
    A = plan_skywing(S)
    cell, anchor = unit_entry("skywing")
    return write_strips("skywing", A, cell, anchor)


# ---------------------------------------------------------------- bloater

BL_ANIMS = ["deflate", "dwalk", "refill", "ddeath"]
BL_ROWS = {"s": 0, "se": 1, "e": 2, "ne": 2, "n": 4}


def team_red(img):
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    return (img[..., 3] > 0) & (g == 0) & (b == 0) & ((r == 255) | (r == 150))


def crest_point(img):
    """Where the bloater hangs from: y = the crest's tip (top row of the biggest team-red
    piece), x = the middle of the head and sac (the mean x of the figure with the thin
    tendrils and wing ribs opened away; a tilted crest tip would make it sway)."""
    m = team_red(img)
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if not n:
        return None
    big = lab == (np.argmax(ndimage.sum(m, lab, np.arange(1, n + 1))) + 1)
    top = np.nonzero(big)[0].min()
    body = ndimage.binary_opening(img[..., 3] > 0, iterations=2)
    l2, n2 = ndimage.label(body, structure=np.ones((3, 3)))
    if n2:
        body = l2 == (np.argmax(ndimage.sum(body, l2, np.arange(1, n2 + 1))) + 1)
    return float(np.nonzero(body)[1].mean()) + 0.5, float(top)


def figure_height(img):
    """Height of everything drawn: crest tip to tendril ends."""
    ys = np.flatnonzero((img[..., 3] > 0).any(1))
    return ys.max() + 1 - ys.min()


def old_frames(kind, key, cw):
    a = np.array(Image.open(f"assets/units/{kind}/{key}.png").convert("RGBA"))
    return [a[:, i * cw:(i + 1) * cw] for i in range(a.shape[1] // cw)]


def old_bloater(cell, anchor):
    """Per direction, from the existing idle frames: the median figure height and where
    the crest tip sits relative to the anchor."""
    ref = {}
    for d in DIRS:
        hs, off = [], []
        for f in old_frames("bloater", f"idle_{d}", cell[0]):
            hs.append(figure_height(f))
            cx, cy = crest_point(f)
            off.append((anchor[0] - cx, anchor[1] - cy))
        ref[d] = (float(np.median(hs)), tuple(np.median(np.array(off), 0)))
    return ref


def at_crest(f, off):
    g = f.copy()
    p = crest_point(g.img)
    if p is None:
        ys, xs = np.nonzero(g.img[..., 3] > 0)
        p = ((xs.min() + xs.max() + 1) / 2.0, float(ys.min()))
    g.ax, g.ay = p[0] + off[0], p[1] + off[1]
    return g


def centroid(img):
    ys, xs = np.nonzero(img[..., 3] > 0)
    return xs.mean() + 0.5, ys.mean() + 0.5


def plan_bloater(S, ref):
    """Rows: 0 = S, 1 = SE, 2 = E (side view), 3 = a front view (meant as NE: unused,
    NE reuses E as for the existing bloater), 4 = N (the back). Rows 1 and 2 deflate
    facing their way but their fly and refill frames turn to the camera (front
    three-quarter): used as drawn. Deflate, fly, refill and the first death frame are
    held by the crest tip (height) and the body's middle (x), see crest_point; the
    torn-up death frames 1-3 (bits flying, then the gas puff) keep frame 0's centre of
    mass."""
    A = {}
    for d, r in BL_ROWS.items():
        off = ref[d][1]
        A["deflate", d] = [at_crest(f, off) for f in S.seq(r, "deflate")]
        A["dwalk", d] = [at_crest(f, off) for f in S.seq(r, "fly")]
        A["refill", d] = [at_crest(f, off) for f in S.seq(r, "refill")]
        death = S.seq(r, "death")
        f0 = at_crest(death[0], off)
        c0 = centroid(f0.img)
        out = [f0]
        for f in death[1:]:
            g = f.copy()
            c = centroid(g.img)
            g.ax, g.ay = c[0] + (f0.ax - c0[0]), c[1] + (f0.ay - c0[1])
            out.append(g)
        A["ddeath", d] = out
    return A


def build_bloater():
    cell, anchor = unit_entry("bloater")
    ref = old_bloater(cell, anchor)
    S = Src8("bloater_deflated")
    if DEBUG:
        debug_seams("bloater_deflated")
    # the new sheet's rows are drawn at one size: one scale, the median over the
    # directions of (existing idle height / first deflate frame's height)
    ks = [ref[d][0] / float(figure_height(S.raw(r, "deflate", 0, BLOATER_SCALE).img))
          for d, r in BL_ROWS.items() if d != "ne"]
    k = float(np.median(ks))
    S.row_factor = {r: k for r in range(5)}
    print(f"bloater scale {BLOATER_SCALE * k:.3f} (per direction s/se/e/n: " +
          ", ".join(f"{BLOATER_SCALE * x:.3f}" for x in ks) + ")")
    A = plan_bloater(S, ref)
    return write_strips("bloater", A, cell, anchor)


# ---------------------------------------------------------------- contact sheets

def frames_of(path, cw, n, anchor=None):
    strip = np.array(Image.open(path).convert("RGBA"))
    out = []
    for i in range(n):
        fr = strip[:, i * cw:(i + 1) * cw].copy()
        if anchor:
            fr[int(anchor[1]), max(0, int(anchor[0]) - 2):int(anchor[0]) + 3] = (255, 255, 255, 110)
        fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
        fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
        out.append(fr)
    return out


def contact(kind, anims, refs, counts, size, anchor):
    os.makedirs(CONTACT, exist_ok=True)
    cw, H = size
    (ocw, och), _ = unit_entry(kind)
    ref = []
    for key, i in refs:
        f = old_frames(kind, key, ocw)[i]
        f = np.concatenate([np.zeros((H - f.shape[0], f.shape[1], 4), np.uint8), f], 0)
        f = np.concatenate([f, np.zeros((H, cw - f.shape[1], 4), np.uint8)], 1)
        ref.append(f)
    lines = [("old: " + "/\n".join(k for k, _ in refs), ref)]
    for an in anims:
        for d in DIRS:
            key = f"{an}_{d}"
            lines.append((key, frames_of(f"assets/units/{kind}/{key}.png", cw, counts[key], anchor)))
    r4.contact_sheet(os.path.join(CONTACT, f"contact_{kind}_round8.png"), lines)


def main():
    register()
    if DEBUG:
        os.makedirs(DEBUG, exist_ok=True)
    sky = build_skywing()
    blo = build_bloater()
    if CONTACT:
        contact("skywing", SKY_ANIMS, [("walk_s", 0), ("walk_e", 0), ("idle_s", 0), ("walk_n", 0)], *sky)
        contact("bloater", BL_ANIMS, [("idle_s", 0), ("idle_se", 0), ("idle_e", 0), ("idle_n", 0)], *blo)


if __name__ == "__main__":
    main()
