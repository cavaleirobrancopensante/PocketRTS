"""Turn the ChatGPT art in art/ into game-ready sprites in assets/.

For every sheet it: removes the painted checkerboard (or uses real alpha),
finds each sprite, groups them into rows/directions/frames, shrinks them to
the true NES pixel size, snaps team reds to two exact key colours, lines the
frames up on a shared canvas, and writes scripts/art_data.gd with the layout.

Usage (from the repo root): python3 tools/import_art.py
Needs Pillow, NumPy and SciPy.
"""
import os
from collections import deque

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = "assets"
DIRS = ["s", "se", "e", "ne", "n"]

# Shrink factors: chosen so one "art pixel" in the sheet becomes ~one real pixel.
UNIT_SCALE = 0.34
BUILDING_SCALE = 0.36

UNITS = {
    "labourer": {"rows": ["idle", "walk", "mine", "build", "carry", "death"], "dilate": 2},
    # Musketeer and pikeman: second sheets on a flat grey background. "drop" removes
    # hallucinated frames: (anim, dir, index within that panel's row); "fill" reuses a good
    # frame in its place so the timing of the animation stays the same.
    "musketeer": {"rows": ["idle", "walk", "aim", "fire", "reload", "reload", "death"], "dilate": 1,
                  "mask": "flat_flood", "panels": [0, 270, 545, 955, 1245, 1536], "smoke_far": 18,
                  "walk_height": 33, "nosplit": True, "drop": [("idle", "e", 3)],
                  "by_coat": {"aim": "left", "fire": "left"}},
    "pikeman": {"rows": ["idle", "walk", "brace", "thrust", "skip", "death"], "dilate": 1,
                "last_only": ["brace", "thrust"], "jab": True,
                "by_coat": {"walk": "right", "brace": "left", "thrust": "left"},
                "mask": "flat_flood", "panels": [0, 295, 585, 910, 1218, 1536], "walk_height": 50,
                "nosplit": True,
                "drop": [("walk", "s", 2), ("walk", "se", 2), ("brace", "n", 0), ("thrust", "n", 0),
                         ("thrust", "n", 1), ("death", "s", 0), ("death", "se", 0), ("death", "e", 0),
                         ("death", "ne", 0), ("death", "n", 0), ("death", "n", 1)]},
    "cannon": {"rows": ["idle", "move", "fire", "reload", "death"], "dilate": 14, "drop_smoke": True, "scale": UNIT_SCALE * 1.3,
               "smoke_to_muzzle": True},
    # New units (flat slate background). Hallucinated frames dropped: (anim, dir, index).
    "missionary": {"rows": ["idle", "walk", "bandage", "bandage2", "skip", "death"], "dilate": 3,
                   "mask": "flat_flood", "panels": [0, 285, 610, 935, 1243, 1536], "walk_height": 33,
                   "nosplit": True, "merge_rows": {"bandage2": "bandage"}, "need_dark": ["bandage", "bandage2"],
                   "by_coat": {"bandage": "left", "bandage2": "left"}, "core": "black", "coat_gap": 30, "need_pair": "bandage", "drop_keys": [("bandage", "ne")],
                   "drop": [("bandage", "n", 1), ("bandage", "n", 2), ("bandage2", "n", 0), ("bandage2", "n", 1),
                            ("bandage2", "n", 2), ("bandage2", "n", 3), ("death", "n", 0), ("death", "n", 1)]},
    "skywing": {"rows": ["idle", "walk", "skip", "attack", "death", "death2"], "dilate": 1, "dir": "brood",
                "mask": "flat_flood", "panels": [0, 310, 625, 925, 1245, 1536], "walk_height": 34,
                "nosplit": True, "core": "dark", "by_coat": {}, "merge_rows": {"death2": "death"},
                "drop": [("death", "n", 0), ("death", "n", 1), ("death", "n", 2), ("death2", "n", 0),
                         ("death2", "n", 1)]},
    "tesla_cart": {"rows": ["walk", "deploy", "deployed", "attack", "death"], "dilate": 1, "dir": "clockwork",
                   "mask": "flat_flood", "panels": [0, 295, 585, 910, 1228, 1536], "walk_height": 54,
                   "nosplit": True, "by_coat": {"attack": "left"}, "coat_gap": 25, "idle_from": "walk"},
    "winder": {"rows": ["idle", "wind", "walk", "repair", "attack", "death"], "dilate": 2,
               "dir": "clockwork", "mask": "alpha", "scale": 0.27 * 1.5},
}
BUILDINGS = ["town_hall", "cottage", "barracks", "foundry"]
BROOD_BUILDINGS = ["hive", "clutch_mound", "warren", "gorge_pit"]

# Brood sheets: row 0 = idle facing each direction; every other row is drawn
# side-on (facing right) and gets mirrored in game. Height = in-game pixels.
BROOD_UNITS = {
    "grub": {"rows": ["idle", "walk", "burrow", "attack", "morph", "death"], "height": 17},
    "raptor": {"rows": ["idle", "walk", "leap", "attack", "death"], "height": 20},
    "spitter": {"rows": ["idle", "walk", "flare", "attack", "death"], "height": 34},
    "brute": {"rows": ["idle", "walk", "charge", "attack", "death"], "height": 52},
    # Clockwork: row 0 is a two-frame idle in one fixed direction.
    "gearknight": {"rows": ["idle", "walk", "attack", "block", "death"], "height": 51, "dir": "clockwork",
                   "row0": "s", "skip": {1: 2}},
    "bolt": {"rows": ["idle", "walk", "crank", "attack", "death"], "height": 42, "dir": "clockwork", "row0": "s"},
    "steam_walker": {"rows": ["idle", "walk", "attack", "vent", "death"], "height": 99, "dir": "clockwork", "row0": "e",
                     "mask": "flat"},
}
# Width in game pixels of each finished building (ChatGPT drew each at its own zoom).
BUILDING_WIDTH = {"town_hall": 150, "cottage": 72, "barracks": 128, "foundry": 118,
                  "hive": 158, "clutch_mound": 74, "warren": 130, "gorge_pit": 126}
BUILDING_STATES = ["built", "construction", "damaged", "destroyed"]

TEAM_LIGHT = (255, 0, 0)
TEAM_DARK = (150, 0, 0)


# ---------------------------------------------------------------- helpers

def load(path):
    return np.array(Image.open(path).convert("RGBA")).astype(np.int32)


def checker_mask(px, min_level=196, max_chroma=14):
    """Foreground mask of a sheet with a painted light checkerboard: flood fill
    the near-white, colourless background inward from the image border."""
    rgb = px[..., :3]
    bgl = (rgb.min(-1) >= min_level) & ((rgb.max(-1) - rgb.min(-1)) <= max_chroma)
    h, w = bgl.shape
    seen = np.zeros_like(bgl)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bgl[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bgl[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bgl[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    fg = ~seen
    fg &= ~checker_holes(px, fg, seen)
    fg &= ~checker_specks(px, fg, seen)
    fg |= patch_smoke(px, fg)
    # Drop the thin light-grey separator lines between panels.
    lines = (rgb.min(-1) >= 150) & ((rgb.max(-1) - rgb.min(-1)) <= 10)
    fg &= ~(lines & ndimage.binary_opening(lines, structure=np.ones((25, 1))))
    return fg


def flat_mask(px, tol=46):
    """Foreground mask of a sheet on one flat background colour (taken from the border)."""
    rgb = px[..., :3]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    fg = np.abs(rgb - bg).sum(-1) > tol
    return ndimage.binary_opening(fg, iterations=1)


def patch_smoke(px, fg, it=9):
    """The flood fill eats stripes of painted checker showing through smoke puffs.
    Close those narrow gaps where the neighbours are pale, colourless smoke, and
    paint them with the surrounding smoke colour (px is changed in place)."""
    rgb = px[..., :3].astype(float)
    closed = ndimage.binary_closing(fg, iterations=it)
    gap = closed & ~fg
    if not gap.any():
        return gap
    w = fg.astype(float)
    k = np.ones((13, 13))
    wsum = ndimage.convolve(w, k, mode="constant")
    mean = np.stack([ndimage.convolve(rgb[..., c] * w, k, mode="constant") for c in range(3)], -1) / np.maximum(wsum, 1)[..., None]
    sq = np.stack([ndimage.convolve((rgb[..., c] ** 2) * w, k, mode="constant") for c in range(3)], -1) / np.maximum(wsum, 1)[..., None]
    chroma = mean.max(-1) - mean.min(-1)
    smoke = gap & (wsum >= 8) & (mean.mean(-1) >= 165) & (chroma <= 18) & (np.sqrt(np.maximum(sq - mean ** 2, 0)).mean(-1) < 40)
    px[smoke, :3] = mean[smoke].astype(px.dtype)
    px[smoke, 3] = 255
    return smoke


def checker_specks(px, fg, bg_seen):
    """Tiny pockets (a few pixels, between wheel spokes or fingers) in the background's own
    two exact greys. Real white details (teeth, eyes, steam) are shaded, so they don't match."""
    rgb = px[..., :3]
    grey = rgb.mean(-1)
    flat = (rgb.max(-1) - rgb.min(-1)) <= 3
    bgvals = grey[bg_seen & flat]
    if bgvals.size < 100:
        return np.zeros_like(fg)
    hist, edges = np.histogram(bgvals, bins=np.arange(200, 257, 2))
    shades = edges[np.argsort(-hist)[:2]] + 1
    cand = fg & flat & ((np.abs(grey - shades[0]) <= 3) | (np.abs(grey - shades[1]) <= 3))
    lab, n = ndimage.label(cand)
    if n == 0:
        return np.zeros_like(fg)
    idx = np.arange(1, n + 1)
    size = ndimage.sum(cand, lab, idx)
    std = ndimage.standard_deviation(grey, lab, idx)
    bad = (size >= 3) & (size < 25) & (std <= 6)
    out = bad[lab - 1] & (lab > 0)
    return ndimage.binary_dilation(out, iterations=1) & fg & (grey >= 215) & ((rgb.max(-1) - rgb.min(-1)) <= 10)


def checker_holes(px, fg, bg_seen):
    """Painted checkerboard trapped inside a sprite (between legs, wheel spokes):
    enclosed pockets made of the background's own two greys. Smoke, steam and white
    details don't match: they need both checker shades, or one flat shade over a big area."""
    rgb = px[..., :3]
    grey = rgb.mean(-1)
    neutral = (rgb.max(-1) - rgb.min(-1)) <= 10
    bgvals = grey[bg_seen & neutral]
    if bgvals.size < 100:
        return np.zeros_like(fg)
    hist, edges = np.histogram(bgvals, bins=np.arange(200, 257, 2))
    top = np.argsort(-hist)[:2]
    shades = sorted(edges[top] + 1)
    near = [neutral & (np.abs(grey - c) <= 4) for c in shades]
    cand = fg & (near[0] | near[1])
    lab, n = ndimage.label(cand)
    if n == 0:
        return np.zeros_like(fg)
    idx = np.arange(1, n + 1)
    size = ndimage.sum(cand, lab, idx)
    a = ndimage.sum(near[0] & cand, lab, idx) / np.maximum(size, 1)
    b = ndimage.sum(near[1] & cand, lab, idx) / np.maximum(size, 1)
    std = ndimage.standard_deviation(grey, lab, idx)
    keep = (size >= 25) & (((a >= 0.15) & (b >= 0.15)) | ((size >= 60) & (std < 2.5)))
    holes = keep[lab - 1] & (lab > 0)
    # Noisier pockets: enclosed, colourless, very light and fairly even.
    pale = fg & neutral & (grey >= 228)
    lab2, n2 = ndimage.label(pale)
    if n2:
        i2 = np.arange(1, n2 + 1)
        sz2 = ndimage.sum(pale, lab2, i2)
        mean2 = ndimage.mean(grey, lab2, i2)
        std2 = ndimage.standard_deviation(grey, lab2, i2)
        ok2 = (sz2 >= 40) & (mean2 >= 236) & (std2 <= 6.5)
        holes |= ok2[lab2 - 1] & (lab2 > 0)
    # Keep pockets whose rim is pale too (light inside smoke or steam, not a gap).
    lab3, n3 = ndimage.label(holes)
    if n3:
        dark = (grey < 200) | ~neutral
        rim = ndimage.binary_dilation(holes, iterations=2) & ~holes
        i3 = np.arange(1, n3 + 1)
        grown = ndimage.grey_dilation(lab3, size=(5, 5))
        rim_n = ndimage.sum(rim, grown * rim, i3)
        rim_dark = ndimage.sum(rim & dark, grown * rim, i3)
        real = (rim_dark / np.maximum(rim_n, 1)) >= 0.55
        holes = real[lab3 - 1] & (lab3 > 0)
    # the soft edge of the pocket
    edge = ndimage.binary_dilation(holes, iterations=2) & fg & neutral & (grey >= shades[0] - 14)
    return holes | edge


def flat_flood_mask(px, tol=10):
    """Sprites on a flat grey background (panels may differ a little in shade): flood the
    background in from the border through near-neutral pixels of the background's greys;
    sprite outlines stop it. Pockets of the same flat grey trapped inside go too."""
    rgb = px[..., :3].astype(int)
    grey = rgb.mean(-1)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bgc = np.median(border, 0)
    spread = np.abs(border - bgc).max(-1)
    bgl = np.abs(rgb - bgc).max(-1) <= np.percentile(spread, 97) + tol
    lab, n = ndimage.label(bgl)
    edge_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    seen = np.isin(lab, list(edge_labels))
    fg = ~seen
    if n:
        idx = np.arange(1, n + 1)
        size = ndimage.sum(bgl, lab, idx)
        std = ndimage.standard_deviation(grey, lab, idx)
        dist = np.abs(rgb - bgc).max(-1).astype(float)
        mdist = ndimage.mean(dist, lab, idx)
        pocket = ((size >= 20) & (std <= 3.0)) | ((size >= 12) & (mdist <= 7.0))
        fg &= ~(pocket[lab - 1] & (lab > 0))
    # thin separator lines between panels (only lines: at most 4 px wide)
    lines = ndimage.binary_opening(fg, structure=np.ones((400, 1)))
    if lines.any():
        wide = ndimage.binary_opening(lines, structure=np.ones((1, 5)))
        lab, n = ndimage.label(lines)
        bad = np.zeros(n + 1, bool)
        for k in np.unique(lab[wide]):
            bad[k] = True
        lines &= ~bad[lab]
        fg &= ~ndimage.binary_dilation(lines, structure=np.ones((1, 3)))
    return fg


def alpha_mask(px, threshold=128):
    return px[..., 3] >= threshold


def components(fg, dilate, min_big=350, attach_dist=26):
    """Sprites as lists of pixel masks. Small bits (smoke, sparks, chips) are
    attached to the nearest big sprite; specks far from everything are dropped."""
    grown = ndimage.binary_dilation(fg, iterations=dilate) if dilate else fg
    lab, n = ndimage.label(grown)
    lab = np.where(fg, lab, 0)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    objs = ndimage.find_objects(lab)
    big = [i for i in range(n) if sizes[i] >= min_big and objs[i] is not None]
    small = [i for i in range(n) if 25 <= sizes[i] < min_big and objs[i] is not None]
    groups = {i: [i] for i in big}
    centers = {}
    for i in big:
        o = objs[i]
        centers[i] = ((o[0].start + o[0].stop) / 2, (o[1].start + o[1].stop) / 2, o)
    for j in small:
        o = objs[j]
        cy, cx = (o[0].start + o[0].stop) / 2, (o[1].start + o[1].stop) / 2
        best, bd = None, 1e9
        for i in big:
            bo = centers[i][2]
            # gap between the two boxes (0 if they touch/overlap), ties by centre distance
            dy = max(bo[0].start - o[0].stop, 0, o[0].start - bo[0].stop)
            dx = max(bo[1].start - o[1].stop, 0, o[1].start - bo[1].stop)
            d = (dx * dx + dy * dy) ** 0.5 + abs(centers[i][1] - cx) * 0.01
            if d < bd:
                bd, best = d, i
        if best is not None and bd <= attach_dist:
            groups[best].append(j)
    out = []
    for i, members in groups.items():
        m = np.isin(lab, [k + 1 for k in members])
        ys, xs = np.nonzero(m)
        out.append({"mask": m, "y0": ys.min(), "y1": ys.max() + 1, "x0": xs.min(), "x1": xs.max() + 1,
                    "cy": (ys.min() + ys.max()) / 2, "cx": (xs.min() + xs.max()) / 2, "area": len(ys)})
    return out


def cluster_1d(values, gap):
    """Indices grouped into clusters wherever sorted values jump by more than gap."""
    order = np.argsort(values)
    groups, cur = [], [order[0]]
    for a, b in zip(order[:-1], order[1:]):
        if values[b] - values[a] > gap:
            groups.append(cur)
            cur = []
        cur.append(b)
    groups.append(cur)
    return groups


def panel_bounds(px, n=5):
    """x boundaries between the 5 direction panels, from the faint separator
    lines if they exist, otherwise equal widths."""
    rgb = px[..., :3]
    h, w = rgb.shape[:2]
    line = (rgb.min(-1) >= 150) & (rgb.min(-1) <= 226) & ((rgb.max(-1) - rgb.min(-1)) <= 8)
    score = line.sum(0) / h
    cands = []
    for k in range(1, n):
        guess = w * k / n
        lo, hi = int(guess - w * 0.06), int(guess + w * 0.06)
        x = lo + int(np.argmax(score[lo:hi]))
        cands.append(x if score[x] > 0.25 else int(guess))
    return [0] + cands + [w]


def cutout(px, sprite):
    y0, y1, x0, x1 = sprite["y0"], sprite["y1"], sprite["x0"], sprite["x1"]
    img = px[y0:y1, x0:x1].copy()
    img[..., 3] = np.where(sprite["mask"][y0:y1, x0:x1], 255, 0)
    return img


def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then hard alpha."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.45, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def snap_team(img):
    """Team-coloured parts -> exact key reds the shader recolours."""
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    red = (img[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32)
    light = red & (r >= 175)
    dark = red & ~light
    img[light, :3] = TEAM_LIGHT
    img[dark, :3] = TEAM_DARK
    return img


def unteam(img):
    """Nudge any exact key reds in non-team art so the shader leaves them alone."""
    m = (img[..., 0] == 255) & (img[..., 1] == 0) & (img[..., 2] == 0)
    img[m, 1] = 18
    m = (img[..., 0] == 150) & (img[..., 1] == 0) & (img[..., 2] == 0)
    img[m, 1] = 12
    return img


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(img.astype(np.uint8)).save(path)


# ---------------------------------------------------------------- units

def split_by_coat(px, row_sprites, bounds, rule, margin=14, core="red", gap=40, half_width=34, head=34):
    """One frame per soldier: find each red coat, then give every pixel of the row to a
    soldier. rule 'left': weapons stick out to the right, so a pixel belongs to the nearest
    soldier on its left; 'right': the other way round; 'near': the nearest soldier."""
    out = {}
    union = np.zeros(px.shape[:2], bool)
    for s in row_sprites:
        union |= s["mask"]
    rgb = px[..., :3]
    if core == "black":
        g = rgb.mean(-1)
        red = ndimage.binary_opening(union & (g < 50), iterations=2)     # cassocks and hats
    elif core == "dark":
        g = rgb.mean(-1)
        dark = union & (g < 95) & ((rgb.max(-1) - rgb.min(-1)) < 40)
        red = ndimage.binary_opening(dark, iterations=2)       # torso, not wing bones
    else:
        red = union & (rgb[..., 0] >= 170) & (rgb[..., 1] <= 70) & (rgb[..., 2] <= 70)
    for p in range(len(bounds) - 1):
        x0, x1 = bounds[p], bounds[p + 1]
        m = union.copy()
        m[:, :x0] = False
        m[:, x1:] = False
        r = red.copy()
        r[:, :x0] = False
        r[:, x1:] = False
        lab, n = ndimage.label(ndimage.binary_dilation(r, iterations=3))
        if n == 0:
            continue
        sizes = ndimage.sum(r, lab, range(1, n + 1))
        cxs = [c[1] for c in ndimage.center_of_mass(r, lab, range(1, n + 1))]
        bodies = sorted(cx for cx, sz in zip(cxs, sizes) if sz >= 40)
        merged = []
        for cx in bodies:
            if merged and cx - merged[-1] < gap:
                merged[-1] = (merged[-1] + cx) / 2
            else:
                merged.append(cx)
        if not merged:
            continue
        # Grow each soldier out from his coat through connected pixels (geodesic Voronoi):
        # a musket or pike stays with the hands holding it, bodies are never sliced.
        yb, xb = np.nonzero(m)
        Y0, Y1, X0, X1 = yb.min(), yb.max() + 1, xb.min(), xb.max() + 1
        m_full = m
        m = m[Y0:Y1, X0:X1]
        r = r[Y0:Y1, X0:X1]
        merged_full = merged
        merged = [cx - X0 for cx in merged]
        rl, rn = ndimage.label(r)
        seeds = np.zeros(m.shape, np.int32)
        for k in range(1, rn + 1):
            yk, xk = np.nonzero(rl == k)
            if yk.size < 10:
                continue
            owner = int(np.argmin([abs(xk.mean() - cx) for cx in merged]))
            seeds[rl == k] = owner + 1
        lab_img = seeds.copy()
        frontier = lab_img > 0
        for _ in range(400):
            grown = ndimage.grey_dilation(lab_img, size=(3, 3))
            add = (lab_img == 0) & m & (grown > 0)
            if not add.any():
                break
            lab_img[add] = grown[add]
        # pieces not joined to any soldier: by side rule
        ys, xs = np.nonzero(m & (lab_img == 0))
        if ys.size:
            c = np.array(merged)
            d = xs[:, None] - c[None, :]
            if rule == "left":
                score = np.where(d >= -margin, np.abs(d), 1e6 + np.abs(d))
            elif rule == "right":
                score = np.where(d <= margin, np.abs(d), 1e6 + np.abs(d))
            else:
                score = np.abs(d)
            lab_img[ys, xs] = np.argmin(score, 1) + 1
        ys, xs = np.nonzero(m)
        own = lab_img[ys, xs] - 1
        ys, xs = ys + Y0, xs + X0
        m = m_full
        merged = merged_full
        for k in range(len(merged)):
            sel = own == k
            if sel.sum() < 30:
                continue
            mk = np.zeros_like(m)
            mk[ys[sel], xs[sel]] = True
            # keep what is joined to this soldier's body (drops stray tips of neighbours)
            lab2, n2 = ndimage.label(ndimage.binary_dilation(mk, iterations=1) & union)
            core = lab2[int(np.median(ys[sel])), int(round(merged[k]))] if n2 else 0
            if core:
                mk &= lab2 == core
            yy, xx = np.nonzero(mk)
            out.setdefault(DIRS[p], []).append(cutout(px, {"mask": mk, "y0": yy.min(), "y1": yy.max() + 1,
                                                           "x0": xx.min(), "x1": xx.max() + 1}))
    return out


def smoke_to_muzzle(im):
    """Muzzle smoke drawn far from the gun: slide it onto the muzzle flash and fill the
    ring's hollow middle (the cut-out took it for background)."""
    a = im[..., 3] > 0
    rgb = im[..., :3].astype(int)
    grey = rgb.mean(-1)
    chroma = rgb.max(-1) - rgb.min(-1)
    flash = a & (rgb[..., 0] >= 200) & (rgb[..., 1] >= 110) & (rgb[..., 2] <= 120) & (chroma >= 80)
    smoke = a & (chroma <= 30) & (grey >= 140)
    if flash.sum() < 2 or smoke.sum() < 6:
        return im
    lab, n = ndimage.label(ndimage.binary_dilation(smoke, iterations=1) & a)
    fy, fx = np.nonzero(flash)
    fc = np.array([fy.mean(), fx.mean()])
    sizes = ndimage.sum(smoke, lab, range(1, n + 1))
    k = int(np.argmax(sizes)) + 1
    puff = (lab == k) & a
    py, px_ = np.nonzero(puff)
    pc = np.array([py.mean(), px_.mean()])
    i = np.argmin((py - fc[0]) ** 2 + (px_ - fc[1]) ** 2)
    j = np.argmin((fy - pc[0]) ** 2 + (fx - pc[1]) ** 2)
    dy, dx = int(round(fy[j] - py[i])), int(round(fx[j] - px_[i]))
    if abs(dx) + abs(dy) <= 2:
        return im
    out = im.copy()
    filled = ndimage.binary_fill_holes(puff)
    col = rgb[puff].mean(0)
    src = im.copy()
    src[filled & ~puff, :3] = np.clip(col * 1.05, 0, 255)
    src[filled & ~puff, 3] = 255
    out[puff] = 0
    ys, xs = np.nonzero(filled)
    ny, nx = ys + dy, xs + dx
    ok = (ny >= 0) & (ny < im.shape[0]) & (nx >= 0) & (nx < im.shape[1])
    ys, xs, ny, nx = ys[ok], xs[ok], ny[ok], nx[ok]
    keep = out[ny, nx, 3] == 0
    out[ny[keep], nx[keep]] = src[ys[keep], xs[keep]]
    cols = np.nonzero((out[..., 3] > 0).any(0))[0]
    rows = np.nonzero((out[..., 3] > 0).any(1))[0]
    return out[rows.min():rows.max() + 1, cols.min():cols.max() + 1]


def blast_up(im):
    """Back view: the painted flash and smoke shoot out sideways past a crewman's head,
    but the barrel points up. Cut them out (they sit in the frame's upper right), turn
    them to point up and set them on the muzzle (top of the barrel, a little left of
    the middle). Positions are fractions of the frame, measured on the sheet."""
    h, w = im.shape[:2]
    a = im[..., 3] > 0
    rgb = im[..., :3].astype(int)
    grey = rgb.mean(-1)
    chroma = rgb.max(-1) - rgb.min(-1)
    flash = a & (rgb[..., 0] >= 190) & (rgb[..., 1] >= 100) & (rgb[..., 2] <= 160) & (chroma >= 50)
    pale = a & (chroma <= 40) & (grey >= 110)
    box = np.zeros_like(a)
    box[: int(h * 0.55), int(w * 0.66):] = True
    eff = box & (flash | pale)
    if eff.sum() < 5:
        return im
    ey, ex = np.nonzero(eff)
    y0, x0 = ey.min(), ex.min()
    patch = np.zeros((ey.max() - y0 + 1, ex.max() - x0 + 1, 4), np.uint8)
    patch[ey - y0, ex - x0] = im[ey, ex]
    fy = np.nonzero((flash & eff)[y0:ey.max() + 1, x0:ex.max() + 1])[0]
    root_row = int(fy.mean()) if fy.size else patch.shape[0] // 2
    out = im.copy()
    out[eff] = 0
    # loose specks left behind
    lab, n = ndimage.label(out[..., 3] > 0, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(out[..., 3] > 0, lab, range(1, n + 1))
        tiny = (sizes <= 8)[lab - 1] & (lab > 0)
        out[tiny] = 0
    rot = np.rot90(patch, 1)                    # pointing right -> pointing up
    my, mx = int(h * 0.21), int(w * 0.38)       # the muzzle
    oy = my - rot.shape[0]
    ox = mx - root_row
    pad_top = max(0, -oy)
    big = np.zeros((h + pad_top, w + max(0, ox + rot.shape[1] - w), 4), np.uint8)
    big[pad_top:pad_top + h, :w] = out
    reg = big[oy + pad_top:oy + pad_top + rot.shape[0], ox:ox + rot.shape[1]]
    put = (rot[..., 3] > 0) & (reg[..., 3] == 0)
    reg[put] = rot[put]
    rows = np.nonzero((big[..., 3] > 0).any(1))[0]
    cols = np.nonzero((big[..., 3] > 0).any(0))[0]
    return big[rows.min():rows.max() + 1, cols.min():cols.max() + 1]


def import_unit(name, cfg, data):
    px = load(f"art/{cfg.get('dir', 'crown')}/{name}.png")
    if cfg.get("mask") == "alpha":
        fg = alpha_mask(px, 160)
    elif cfg.get("mask") == "flat_flood":
        fg = flat_flood_mask(px)
    else:
        fg = checker_mask(px)
    if cfg.get("panels"):
        fg[:, cfg["panels"][-1]:] = False
    if cfg.get("smoke_far"):
        # Painted smoke floats away from the soldier; white belts sit on the red coat.
        rgb = px[..., :3].astype(float)
        g = rgb.mean(-1)
        pale = fg & ((rgb.max(-1) - rgb.min(-1)) <= 26) & (g >= 110)
        coat = (rgb[..., 0] >= 170) & (rgb[..., 1] <= 70) & (rgb[..., 2] <= 70)
        dist = ndimage.distance_transform_edt(~coat)
        lab, n = ndimage.label(ndimage.binary_dilation(pale, iterations=2) & fg)
        if n:
            i = np.arange(1, n + 1)
            near = ndimage.minimum(dist, lab, i)
            far = near > cfg["smoke_far"]
            fg &= ~(far[lab - 1] & (lab > 0))
    if cfg.get("drop_smoke"):
        # Painted muzzle smoke is full of checker gaps; the game makes its own smoke.
        rgb = px[..., :3].astype(float)
        g = rgb.mean(-1)
        pale = fg & ((rgb.max(-1) - rgb.min(-1)) <= 22) & (g >= 150)
        lab, n = ndimage.label(pale)
        if n:
            i = np.arange(1, n + 1)
            min_size = cfg["drop_smoke"] if cfg["drop_smoke"] is not True else 20
            bad = (ndimage.sum(pale, lab, i) >= min_size) & (ndimage.mean(g, lab, i) >= 165)
            fg &= ~(bad[lab - 1] & (lab > 0))
    sprites = components(fg, cfg["dilate"], min_big=900 if name == "cannon" else 350)
    bounds = cfg.get("panels") or panel_bounds(px)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 45)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    names = cfg["rows"]
    if len(rows) != len(names):
        print(f"  ! {name}: found {len(rows)} rows, expected {len(names)}")
    frames = {}   # (anim, dir) -> list of images (source scale)
    for ri, row in enumerate(rows[:len(names)]):
        anim = names[ri]
        if anim == "skip":
            continue
        rowframes = {}
        if cfg.get("by_coat") is not None:
            rowframes = split_by_coat(px, [sprites[i] for i in row], bounds, cfg["by_coat"].get(anim, "near"),
                                      core=cfg.get("core", "red"), gap=cfg.get("coat_gap", 40))
        else:
          for i in sorted(row, key=lambda k: sprites[k]["cx"]):
            s = sprites[i]
            p = max(0, min(4, int(np.searchsorted(bounds, s["cx"], side="right")) - 1))
            rowframes.setdefault(DIRS[p], []).append(cutout(px, s))
        for d, lst in rowframes.items():
            bad = {k for a, dd, k in cfg.get("drop", []) if a == anim and dd == d}
            lst = [im for k, im in enumerate(lst) if k not in bad]
            if anim in cfg.get("last_only", []) and lst:
                lst = lst[-1:]   # the others are crossed by their neighbour's pike
            if anim in cfg.get("need_dark", []):
                # frames of the wounded soldier alone (no black cassock) are dropped
                def cassock(im):
                    a = im[..., 3] > 0
                    g = im[..., :3].astype(int).mean(-1)
                    return ndimage.binary_opening((g < 50) & a, iterations=1).sum()
                cs = [cassock(im) for im in lst]
                if cs:
                    med = float(np.median(cs))
                    lst = [im for im, c in zip(lst, cs) if c >= med * 0.4]
            frames.setdefault((cfg.get("merge_rows", {}).get(anim, anim), d), []).extend(lst)
    if cfg.get("jab"):
        # thrust = braced, then extended
        for d in DIRS:
            if frames.get(("brace", d)) and frames.get(("thrust", d)):
                frames[("thrust", d)] = frames[("brace", d)][-1:] + frames[("thrust", d)][-1:]
    frames = {k: v for k, v in frames.items() if v}
    if cfg.get("idle_from"):
        for d in DIRS:
            if frames.get((cfg["idle_from"], d)):
                frames[("idle", d)] = frames[(cfg["idle_from"], d)][:1]
    # Two frames drawn touching come out as one sprite: split where the column
    # profile has a deep valley with plenty of body on both sides.
    def split(im, depth=0):
        a = im[..., 3] > 0
        cols = a.sum(0)
        w = im.shape[1]
        if depth > 4 or w < 30:
            return [im]
        lo, hi = int(w * 0.22), int(w * 0.78)
        cut = lo + int(np.argmin(cols[lo:hi]))
        total = cols.sum()
        if cols[cut] <= max(3, 0.15 * cols.max()) and cols[:cut].sum() > total * 0.3 and cols[cut:].sum() > total * 0.3:
            out = []
            for part in (im[:, :cut], im[:, cut:]):
                xs = np.nonzero((part[..., 3] > 0).any(0))[0]
                out += split(part[:, xs.min():xs.max() + 1], depth + 1)
            return out
        return [im]
    if name != "cannon" and not cfg.get("nosplit"):
        for key, lst in list(frames.items()):
            if key[0] == "death":
                continue
            frames[key] = [p for im in lst for p in split(im)]
    # frames still holding several figures side by side: cut into equal figures at the
    # thinnest columns
    widths = [im.shape[1] for k2, lst in frames.items() if k2[0] in ("walk", "idle") for im in lst]
    if widths:
        medw = float(np.median(widths))
        for key, lst in list(frames.items()):
            if key[0] in ("death", "bandage", "fire", "aim", "attack"):
                continue
            out = []
            for im in lst:
                w = im.shape[1]
                k = max(2, int(round(w / medw)))
                if w <= medw * 1.75 or k < 2:
                    out.append(im)
                    continue
                cols = (im[..., 3] > 0).sum(0)
                cuts = [0]
                for j in range(1, k):
                    g = int(w * j / k)
                    lo, hi = max(cuts[-1] + 4, g - int(w / k * 0.3)), min(w - 4, g + int(w / k * 0.3))
                    cuts.append(lo + int(np.argmin(cols[lo:hi])) if hi > lo else g)
                cuts.append(w)
                for x0, x1 in zip(cuts[:-1], cuts[1:]):
                    part = im[:, x0:x1]
                    xs = np.nonzero((part[..., 3] > 0).any(0))[0]
                    ys = np.nonzero((part[..., 3] > 0).any(1))[0]
                    if xs.size:
                        out.append(part[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
            frames[key] = out
    # stray fragments (a pick, a scrap of a neighbour) are not frames, and a frame with
    # two figures drawn over each other (far more body than its neighbours) is dropped
    for key, lst in list(frames.items()):
        areas = [int((im[..., 3] > 0).sum()) for im in lst]
        if len(lst) > 1:
            med = float(np.median(areas))
            big_ok = key[0] in ("death", "bandage", "fire", "attack", "deploy", "deployed")
            keep = [im for im, a in zip(lst, areas) if a >= med * 0.3 and (big_ok or len(lst) < 3 or a <= med * 1.55)]
            frames[key] = keep or lst
    scale = cfg.get("scale", UNIT_SCALE)
    if cfg.get("walk_height"):
        hs = [im.shape[0] for im in frames.get(("walk", "s")) or frames[("walk", "e")]]
        scale = cfg["walk_height"] / float(np.median(hs))
    small = {}
    for key, lst in frames.items():
        small[key] = [snap_team(shrink(im, scale)) for im in lst]
    if cfg.get("need_pair"):
        # keep frames showing both the priest (black hat and cassock) and the soldier
        # (grey helmet); other directions fall back to the nearest one that has them
        def has_both(im):
            a = im[..., 3] > 0
            rgb = im[..., :3].astype(int)
            g = rgb.mean(-1)
            neutral = (rgb.max(-1) - rgb.min(-1)) <= 18
            black = ndimage.binary_opening(a & (g < 45), iterations=1).sum()
            helmet = ndimage.binary_opening(a & neutral & (g >= 70) & (g <= 170), iterations=1).sum()
            return black >= 25 and helmet >= 8

        def black_area(im):
            a = im[..., 3] > 0
            g = im[..., :3].astype(int).mean(-1)
            return int(ndimage.binary_opening(a & (g < 45), iterations=1).sum()) + int(a.sum()) // 4
        for d in DIRS:
            key = (cfg["need_pair"], d)
            if key in small:
                good = [im for im in small[key] if has_both(im)]
                if good:
                    small[key] = [max(good, key=black_area)]   # the clearest priest-and-patient frame
                else:
                    del small[key]
        for key in cfg.get("drop_keys", []):
            small.pop(tuple(key), None)
    if cfg.get("smoke_to_muzzle"):
        for key in small:
            if key == ("fire", "n"):
                small[key] = [blast_up(im) for im in small[key]]
            elif key[0] == "fire":
                small[key] = [smoke_to_muzzle(im) for im in small[key]]
    print(f"  {name}: " + ", ".join(f"{a}_{d} {len(v)}" for (a, d), v in sorted(small.items())))
    assemble(name, small, names, data)
    if cfg.get("dir") == "clockwork" or name in ("missionary", "skywing"):
        first = small.get(("idle", "s")) or small.get(("idle", "e")) or small[("walk", "e")]
        make_icon(first[0], name)


def assemble(name, small, names, data):
    """One shared canvas per unit with every frame anchored at the feet."""
    feet = {}
    L = R = U = D = 0
    for key, lst in small.items():
        for k, im in enumerate(lst):
            a = im[..., 3] > 0
            ys, xs = np.nonzero(a)
            bottom = ys.max()
            low = ys >= bottom - max(2, (bottom - ys.min()) * 0.25)
            ax = float(np.median(xs[low]))
            feet[(key, k)] = (ax, bottom)
            L = max(L, ax); R = max(R, im.shape[1] - ax); U = max(U, bottom); D = max(D, im.shape[0] - bottom)
    half = int(np.ceil(max(L, R))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    H = top + int(np.ceil(D)) + 1
    counts = {}
    for (anim, d), lst in small.items():
        strip = np.zeros((H, W * len(lst), 4), np.uint8)
        for k, im in enumerate(lst):
            ax, ay = feet[((anim, d), k)]
            ox, oy = int(round(half - ax)), int(round(top - ay))
            h, w = im.shape[:2]
            ys0, xs0 = max(0, oy), max(0, ox)
            ys1, xs1 = min(H, oy + h), min(W, ox + w)
            src = im[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
            m = src[..., 3] > 0
            cell = strip[:, k * W:(k + 1) * W]
            cell[ys0:ys1, xs0:xs1][m] = src[m]
        save(strip, f"{OUT}/units/{name}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(lst)
    # Directions missing for an animation fall back to the nearest one.
    data["units"][name] = {"cell": (W, H), "anchor": (half, top), "frames": counts, "anims": sorted(set(n for n in names))}
    print(f"  {name}: cell {W}x{H}, {len(counts)} strips")


# ---------------------------------------------------------------- buildings and world

def frames_in_a_row(px, fg, n, dilate=10, min_big=3000):
    sprites = components(fg, dilate, min_big=min_big, attach_dist=60)
    sprites.sort(key=lambda s: -s["area"])
    sprites = sorted(sprites[:n], key=lambda s: s["cx"])
    return [cutout(px, s) for s in sprites]


def frames_by_slot(px, fg, n):
    """n frames laid out left to right: every piece goes to the slot its centre is in."""
    h, w = fg.shape
    sprites = components(fg, 3, min_big=60, attach_dist=0)
    out = []
    for k in range(n):
        lo, hi = w * k / n, w * (k + 1) / n
        mem = [s for s in sprites if lo <= s["cx"] < hi]
        big = max(s["area"] for s in mem)
        mem = [s for s in mem if s["area"] >= big * 0.004]
        m = np.zeros_like(fg)
        for s in mem:
            m |= s["mask"]
        ys, xs = np.nonzero(m)
        out.append(cutout(px, {"mask": m, "y0": ys.min(), "y1": ys.max() + 1, "x0": xs.min(), "x1": xs.max() + 1}))
    return out


def merge_row(px, lst, gap=5):
    """Pieces of one frame (loose gears, slash arcs, steam) -> one sprite each,
    by merging sprites whose x-ranges overlap or nearly touch."""
    lst = sorted(lst, key=lambda s: s["x0"])
    out = []
    for s in lst:
        if out and s["x0"] <= out[-1]["x1"] + gap:
            o = out[-1]
            o["mask"] = o["mask"] | s["mask"]
            o["x0"], o["x1"] = min(o["x0"], s["x0"]), max(o["x1"], s["x1"])
            o["y0"], o["y1"] = min(o["y0"], s["y0"]), max(o["y1"], s["y1"])
            o["area"] += s["area"]
            o["cx"] = (o["x0"] + o["x1"]) / 2
        else:
            out.append(dict(s))
    return out


def import_brood_unit(name, cfg, data):
    px = load(f"art/{cfg.get('dir', 'brood')}/{name}.png")
    fg = flat_mask(px) if cfg.get("mask") == "flat" else checker_mask(px)
    sprites = components(fg, 2, min_big=350)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 45)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    names = cfg["rows"]
    if len(rows) != len(names):
        print(f"  ! {name}: found {len(rows)} rows, expected {len(names)}")
    frames = {}
    for ri, row in enumerate(rows[:len(names)]):
        anim = names[ri]
        lst = sorted([sprites[i] for i in row], key=lambda s: s["cx"])
        if cfg.get("dir") == "clockwork":
            lst = merge_row(px, lst)
        med = sorted(s["area"] for s in lst)[len(lst) // 2]
        lst = [s for s in lst if s["area"] >= med * 0.4]   # drop slash arcs / flying spit
        lst = lst[cfg.get("skip", {}).get(ri, 0):]
        if ri == 0 and cfg.get("row0"):
            frames[("idle", cfg["row0"])] = [cutout(px, s) for s in lst]
        elif ri == 0:
            n = len(lst)
            for k, s in enumerate(lst):
                aspect = (s["x1"] - s["x0"]) / (s["y1"] - s["y0"])
                if k == 0:
                    d = "s"
                elif k == n - 1:
                    d = "n"
                elif aspect >= 1.2:
                    d = "e"
                elif k == 1:
                    d = "se"
                else:
                    d = "ne"
                frames.setdefault(("idle", d), []).append(cutout(px, s))
        else:
            frames[(anim, "e")] = [cutout(px, s) for s in lst]
    walk = frames[("walk", "e")]
    scale = cfg["height"] / float(np.median([im.shape[0] for im in walk]))
    small = {key: [snap_team(shrink(im, scale)) for im in lst] for key, lst in frames.items()}
    assemble(name, small, names, data)
    first = small.get(("idle", "s")) or small.get(("idle", "e"))
    make_icon(first[0], name)


def make_icon(img, name):
    """Square button icon from a sprite until hand-made icons exist."""
    a = img[..., 3] > 0
    ys, xs = np.nonzero(a)
    crop = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = crop.shape[:2]
    k = max(1, int(52 / max(h, w)))
    big = np.array(Image.fromarray(crop).resize((w * k, h * k), Image.NEAREST))
    if max(big.shape[:2]) > 56:
        f = 56 / max(big.shape[:2])
        big = np.array(Image.fromarray(big).resize((max(1, int(big.shape[1] * f)), max(1, int(big.shape[0] * f))), Image.NEAREST))
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (28, 30, 30)
    icon[..., 3] = 255
    icon[0:2, :, :3] = icon[-2:, :, :3] = icon[:, 0:2, :3] = icon[:, -2:, :3] = (70, 74, 72)
    bh, bw = big.shape[:2]
    oy, ox = (64 - bh) // 2, (64 - bw) // 2
    m = big[..., 3] > 0
    icon[oy:oy + bh, ox:ox + bw][m] = big[m]
    save(icon, f"{OUT}/icons/{name}.png")


def make_swamp_tile():
    rng = np.random.default_rng(5)
    t = np.zeros((32, 32, 4), np.uint8)
    base = np.array([46, 58, 24])
    noise = rng.integers(-8, 9, (32, 32, 1))
    t[..., :3] = np.clip(base + noise, 0, 255)
    t[..., 3] = 255
    for _ in range(14):
        y, x = rng.integers(0, 32, 2)
        t[y, x, :3] = (34, 42, 18)
        t[(y + 1) % 32, x, :3] = (34, 42, 18)
    for _ in range(5):
        y, x = rng.integers(0, 32, 2)
        t[y, x, :3] = (176, 200, 64)
    for _ in range(6):
        y, x = rng.integers(0, 32, 2)
        t[y, x, :3] = (78, 94, 38)
    save(t, f"{OUT}/tiles/swamp.png")


CLOCKWORK_BUILDINGS = ["clocktower", "drill_rig", "spring_tower", "assembly_works"]
CLOCKWORK_WIDTH = {"clocktower": 128, "drill_rig": 100, "spring_tower": 58, "assembly_works": 136}


def import_clockwork_structures(data):
    """All four structures in one 4x4 image: one building per row, its states across."""
    px = load("art/clockwork/structures.png")
    fg = checker_mask(px)
    h, w = fg.shape
    sprites = components(fg, 3, min_big=60, attach_dist=0)
    for r, name in enumerate(CLOCKWORK_BUILDINGS):
        imgs = []
        for c in range(4):
            mem = [s for s in sprites if int(s["cy"] * 4 / h) == r and int(s["cx"] * 4 / w) == c]
            big = max(s["area"] for s in mem)
            mem = [s for s in mem if s["area"] >= big * 0.004]
            m = np.zeros_like(fg)
            for s in mem:
                m |= s["mask"]
            ys, xs = np.nonzero(m)
            imgs.append(cutout(px, {"mask": m, "y0": ys.min(), "y1": ys.max() + 1, "x0": xs.min(), "x1": xs.max() + 1}))
        scale = CLOCKWORK_WIDTH[name] / imgs[0].shape[1]
        sizes = []
        for state, im in zip(BUILDING_STATES, imgs):
            sm = snap_team(shrink(im, scale))
            save(sm, f"{OUT}/buildings/{name}_{state}.png")
            sizes.append(sm.shape[1::-1])
            if state == "built":
                make_icon(sm, name)
        data["buildings"][name] = sizes[0]
        print(f"  {name}: {sizes}")


# Second structure sheets: one building per row, its four states across, flat background.
STRUCTURES2 = {
    "art/crown/structures2.png": {"names": ["farm", "powder_mill", "church"], "rows": [0, 345, 640, 1024],
                                  "width": {"farm": 112, "powder_mill": 112, "church": 100}},
    "art/brood/structures2.png": {"names": ["feeding_pit", "bone_midden", "spore_vent", "roost"],
                                  "rows": [0, 252, 458, 712, 1024],
                                  "width": {"feeding_pit": 108, "bone_midden": 104, "spore_vent": 70, "roost": 100}},
    "art/clockwork/structures2.png": {"names": ["boiler", "ore_crusher", "charging_pylon"], "rows": [0, 352, 662, 1024],
                                      "width": {"boiler": 100, "ore_crusher": 112, "charging_pylon": 70}},
}


def import_structures2(data):
    for path, cfg in STRUCTURES2.items():
        px = load(path)
        fg = flat_flood_mask(px)
        h, w = fg.shape
        rows = cfg["rows"]
        lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
        pieces = []
        for k, sl in enumerate(ndimage.find_objects(lab)):
            mk = lab == k + 1
            area = mk.sum()
            if area < 30:
                continue
            ys, xs = np.nonzero(mk)
            # a piece that spans two rows (touching neighbours) is split at the row line
            for ri in range(len(rows) - 1):
                part = mk.copy()
                part[:rows[ri]] = False
                part[rows[ri + 1]:] = False
                if part.sum() >= 30:
                    py, px_ = np.nonzero(part)
                    pieces.append({"mask": part, "cy": py.mean(), "cx": px_.mean()})
        for r, name in enumerate(cfg["names"]):
            imgs = []
            for c in range(4):
                # whole pieces whose middle lies in this cell (plumes may cross the line)
                x0, x1 = int(w * c / 4), int(w * (c + 1) / 4)
                m = np.zeros_like(fg)
                for piece in pieces:
                    if rows[r] <= piece["cy"] < rows[r + 1] and x0 <= piece["cx"] < x1:
                        m |= piece["mask"]
                ys, xs = np.nonzero(m)
                imgs.append(cutout(px, {"mask": m, "y0": ys.min(), "y1": ys.max() + 1, "x0": xs.min(), "x1": xs.max() + 1}))
            scale = cfg["width"][name] / imgs[0].shape[1]
            sizes2 = []
            for state, im in zip(BUILDING_STATES, imgs):
                sm = snap_team(shrink(im, scale))
                save(sm, f"{OUT}/buildings/{name}_{state}.png")
                sizes2.append(sm.shape[1::-1])
                if state == "built":
                    make_icon(sm, name)
            data["buildings"][name] = sizes2[0]
            print(f"  {name}: {sizes2}")


def import_buildings(data):
    data["buildings"] = {}
    import_structures2(data)
    import_clockwork_structures(data)
    for name in BROOD_BUILDINGS:
        px = load(f"art/brood/buildings/{name}.png")
        fg = alpha_mask(px, 200) if name == "hive" else checker_mask(px)
        imgs = frames_by_slot(px, fg, 4)
        scale = BUILDING_WIDTH[name] / imgs[0].shape[1]
        sizes = []
        for state, im in zip(BUILDING_STATES, imgs):
            sm = snap_team(shrink(im, scale))
            save(sm, f"{OUT}/buildings/{name}_{state}.png")
            sizes.append(sm.shape[1::-1])
            if state == "built":
                make_icon(sm, name)
        data["buildings"][name] = sizes[0]
        print(f"  {name}: {sizes}")
    for name in BUILDINGS:
        px = load(f"art/crown/buildings/{name}.png")
        fg = checker_mask(px)
        imgs = frames_by_slot(px, fg, 4)
        scale = BUILDING_WIDTH[name] / imgs[0].shape[1]
        sizes = []
        for state, im in zip(BUILDING_STATES, imgs):
            s = snap_team(shrink(im, scale))
            save(s, f"{OUT}/buildings/{name}_{state}.png")
            sizes.append(s.shape[1::-1])
        data["buildings"][name] = sizes[0]
        print(f"  {name}: {sizes}")


def import_mine(data):
    px = load("art/world/gold_mine.png")
    imgs = frames_by_slot(px, alpha_mask(px), 3)
    for state, im in zip(["full", "half", "empty"], imgs):
        s = unteam(shrink(im, 0.17))
        save(s, f"{OUT}/world/mine_{state}.png")
    data["mine"] = s.shape[1::-1]
    print("  mine", s.shape[1::-1])


def import_nature(data):
    px = load("art/world/nature.png")
    fg = alpha_mask(px, 150)
    sprites = components(fg, 3, min_big=800, attach_dist=12)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 120)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    names = []
    for ri, row in enumerate(rows[:2]):
        kind = "tree" if ri == 0 else "rock"
        for k, i in enumerate(sorted(row, key=lambda j: sprites[j]["cx"])):
            s = unteam(shrink(cutout(px, sprites[i]), 0.25 if kind == "tree" else 0.2))
            save(s, f"{OUT}/world/{kind}_{k}.png")
            names.append(f"{kind}_{k}")
    data["nature"] = names
    print("  nature", names)


def import_tiles(data):
    px = load("art/world/ground_tiles.png")
    h, w = px.shape[:2]
    names = [["grass_0", "grass_1", "grass_2", "grass_3"], ["dirt_0", "dirt_1", "dirt_2", "dirt_3"],
             ["edge_top", "edge_bottom", "edge_left", "edge_right"], ["water", "shore", "mud", "flowers"]]
    for r in range(4):
        for c in range(4):
            y0, y1 = int(h * r / 4), int(h * (r + 1) / 4)
            x0, x1 = int(w * c / 4), int(w * (c + 1) / 4)
            tile = Image.fromarray(px[y0 + 3:y1 - 3, x0 + 3:x1 - 3].astype(np.uint8)).resize((32, 32), Image.BOX)
            save(unteam(np.array(tile)), f"{OUT}/tiles/{names[r][c]}.png")
    print("  tiles 16")


def import_effects(data):
    px = load("art/world/effects.png")
    fg = alpha_mask(px, 120)
    sprites = components(fg, 4, min_big=400, attach_dist=45)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 70)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    row_names = ["smoke", "blast", "fire", "dust", "hit"]
    data["effects"] = {}
    for ri, row in enumerate(rows[:5]):
        lst = [sprites[i] for i in sorted(row, key=lambda j: sprites[j]["cx"])]
        name = row_names[ri]
        top = max(s["area"] for s in lst[1:] or lst) if name == "blast" else max(s["area"] for s in lst)
        lst = [s for k, s in enumerate(lst) if s["area"] >= top * 0.12 or (name == "blast" and k == 0)]
        if name == "blast":
            ball = unteam(shrink(cutout(px, lst[0]), 0.16))
            save(ball, f"{OUT}/effects/cannonball.png")
            lst = lst[1:]
        imgs = [unteam(shrink(cutout(px, s), 0.16)) for s in lst]
        W = max(i.shape[1] for i in imgs)
        H = max(i.shape[0] for i in imgs)
        strip = np.zeros((H, W * len(imgs), 4), np.uint8)
        for k, im in enumerate(imgs):
            oy, ox = (H - im.shape[0]) // 2 if name in ("smoke", "hit") else H - im.shape[0], (W - im.shape[1]) // 2
            strip[oy:oy + im.shape[0], k * W + ox:k * W + ox + im.shape[1]] = im
        save(strip, f"{OUT}/effects/{name}.png")
        data["effects"][name] = (len(imgs), W, H)
    import_effects2(data)
    print("  effects", data["effects"])


# effects2.png: projectiles and fire / explosion varieties, one effect per row.
EFFECTS2 = [  # (name, scale, align, frame slice)
    [("acid_ball", 0.2, "c", (0, 1)), ("acid_splash", 0.2, "c", (3, 8))],
    [("bolt", 0.2, "c", (2, 3))],
    [("ball", 0.2, "c", (0, 1)), ("ball_big", 0.2, "c", (1, 2))],
    [("explosion", 0.22, "c", (0, 9))],
    [("blaze", 0.3, "b", (0, 10))],
    [("smoke_big", 0.22, "c", (0, 9))],
    [("burst", 0.2, "c", (0, 6)), ("flame", 0.22, "c", (6, 10))],
]


def import_effects2(data):
    px = load("art/world/effects2.png")
    fg = checker_mask(px)
    sprites = components(fg, 3, min_big=40, attach_dist=0)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 40)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    rows = [r for r in rows if sum(sprites[i]["area"] for i in r) > 3000]
    for ri, row in enumerate(rows[:len(EFFECTS2)]):
        lst = merge_row(px, [sprites[i] for i in row], gap=14)
        lst = [s for s in lst if s["area"] > 30]
        print(f"  effects2 row {ri}: {len(lst)} frames")
        for name, scale, align, (a, b) in EFFECTS2[ri]:
            imgs = [unteam(shrink(cutout(px, s), scale)) for s in lst[a:b]]
            W = max(i.shape[1] for i in imgs)
            H = max(i.shape[0] for i in imgs)
            strip = np.zeros((H, W * len(imgs), 4), np.uint8)
            for k, im in enumerate(imgs):
                oy = H - im.shape[0] if align == "b" else (H - im.shape[0]) // 2
                ox = (W - im.shape[1]) // 2
                strip[oy:oy + im.shape[0], k * W + ox:k * W + ox + im.shape[1]] = im
            save(strip, f"{OUT}/effects/{name}.png")
            data["effects"][name] = (len(imgs), W, H)


def import_icons(data):
    px = load("art/ui/icons.png")
    fg = checker_mask(px)
    sprites = components(fg, 2, min_big=5000, attach_dist=0)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 60)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    names = [["labourer", "musketeer", "pikeman", "cannon"], ["town_hall", "cottage", "barracks", "foundry"],
             ["move", "attack", "stop", "build", "gather", "repair"]]
    for ri, row in enumerate(rows[:3]):
        for k, i in enumerate(sorted(row, key=lambda j: sprites[j]["cx"])):
            if k >= len(names[ri]):
                break
            s = sprites[i]
            im = px[s["y0"]:s["y1"], s["x0"]:s["x1"]].astype(np.uint8)
            icon = np.array(Image.fromarray(im).resize((64, 64), Image.BOX))
            icon[..., 3] = 255
            save(unteam(icon), f"{OUT}/icons/{names[ri][k]}.png")
    print("  icons done")


# ---------------------------------------------------------------- data file

def import_cannon_wheel():
    """The cannon's spinning wheel (drawn over the painted one in game)."""
    px = load("art/crown/cannon_wheel.png")
    fg = flat_mask(px)
    sprites = components(fg, 2, min_big=2000, attach_dist=0)
    s = min(sprites, key=lambda q: (q["cy"], q["cx"]))     # top-left: face-on
    im = cutout(px, s)
    side = max(im.shape[:2])
    sq = np.zeros((side, side, 4), np.uint8)
    oy, ox = (side - im.shape[0]) // 2, (side - im.shape[1]) // 2
    sq[oy:oy + im.shape[0], ox:ox + im.shape[1]] = im
    small = shrink(sq, 32 / side)
    save(small, f"{OUT}/units/cannon_wheel.png")
    yy, xx = np.mgrid[0:32, 0:32]
    disc = np.zeros((32, 32, 4), np.uint8)
    inside = (yy - 15.5) ** 2 + (xx - 15.5) ** 2 <= 13.5 ** 2
    disc[inside] = (52, 34, 20, 255)
    save(disc, f"{OUT}/units/cannon_wheel_back.png")
    print("  cannon wheel", small.shape)


def write_data(data):
    def v2(t, cls="Vector2i"):
        return f"{cls}({t[0]}, {t[1]})"
    lines = ["class_name ArtData", "## Generated by tools/import_art.py - do not edit by hand.", ""]
    lines.append("const DIRS := " + str(DIRS).replace("'", '"'))
    lines.append("")
    lines.append("const UNITS := {")
    for name, u in data["units"].items():
        lines.append(f'\t"{name}": {{"cell": {v2(u["cell"])}, "anchor": {v2(u["anchor"], "Vector2")}, "frames": {{')
        for k, n in sorted(u["frames"].items()):
            lines.append(f'\t\t"{k}": {n},')
        lines.append("\t}},")
    lines.append("}")
    lines.append("")
    lines.append("const BUILDING_SIZE := {")
    for name, s in data["buildings"].items():
        lines.append(f'\t"{name}": {v2(s)},')
    lines.append("}")
    lines.append("")
    lines.append("const NATURE := " + str(data["nature"]).replace("'", '"'))
    lines.append("")
    lines.append("const EFFECTS := {")
    for name, (n, w, h) in data["effects"].items():
        lines.append(f'\t"{name}": {{"frames": {n}, "size": Vector2i({w}, {h})}},')
    lines.append("}")
    with open("scripts/art_data.gd", "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    data = {"units": {}}
    print("units")
    for name, cfg in UNITS.items():
        import_unit(name, cfg, data)
    for name, cfg in BROOD_UNITS.items():
        import_brood_unit(name, cfg, data)
    make_swamp_tile()
    print("buildings")
    import_buildings(data)
    print("world")
    import_mine(data)
    import_nature(data)
    import_tiles(data)
    import_cannon_wheel()
    import_effects(data)
    import_icons(data)
    os.makedirs("scripts", exist_ok=True)
    write_data(data)


if __name__ == "__main__":
    main()
