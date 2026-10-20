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
    "musketeer": {"rows": ["idle", "walk", "aim", "fire", "reload", "melee", "death"], "dilate": 2},
    "pikeman": {"rows": ["idle", "walk", "brace", "thrust", "death", "death"], "dilate": 2},
    "cannon": {"rows": ["idle", "move", "fire", "reload", "death"], "dilate": 14},
}
BUILDINGS = ["town_hall", "cottage", "barracks", "foundry"]
BROOD_BUILDINGS = ["hive", "clutch_mound", "warren", "gorge_pit"]

# Brood sheets: row 0 = idle facing each direction; every other row is drawn
# side-on (facing right) and gets mirrored in game. Height = in-game pixels.
BROOD_UNITS = {
    "grub": {"rows": ["idle", "walk", "burrow", "attack", "morph", "death"], "height": 17},
    "raptor": {"rows": ["idle", "walk", "leap", "attack", "death"], "height": 28},
    "spitter": {"rows": ["idle", "walk", "flare", "attack", "death"], "height": 26},
    "brute": {"rows": ["idle", "walk", "charge", "attack", "death"], "height": 40},
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
    # Drop the thin light-grey separator lines between panels.
    lines = (rgb.min(-1) >= 150) & ((rgb.max(-1) - rgb.min(-1)) <= 10)
    fg &= ~(lines & ndimage.binary_opening(lines, structure=np.ones((25, 1))))
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

def import_unit(name, cfg, data):
    px = load(f"art/crown/{name}.png")
    fg = checker_mask(px)
    sprites = components(fg, cfg["dilate"], min_big=900 if name == "cannon" else 350)
    bounds = panel_bounds(px)
    rows = cluster_1d(np.array([s["cy"] for s in sprites]), 45)
    rows.sort(key=lambda g: np.mean([sprites[i]["cy"] for i in g]))
    names = cfg["rows"]
    if len(rows) != len(names):
        print(f"  ! {name}: found {len(rows)} rows, expected {len(names)}")
    frames = {}   # (anim, dir) -> list of images (source scale)
    for ri, row in enumerate(rows[:len(names)]):
        anim = names[ri]
        for i in sorted(row, key=lambda k: sprites[k]["cx"]):
            s = sprites[i]
            p = max(0, min(4, int(np.searchsorted(bounds, s["cx"], side="right")) - 1))
            frames.setdefault((anim, DIRS[p]), []).append(cutout(px, s))
    # Two frames drawn touching come out as one sprite: split where the column
    # profile has a deep valley with plenty of body on both sides.
    def split(im, depth=0):
        a = im[..., 3] > 0
        cols = a.sum(0)
        w = im.shape[1]
        if depth > 2 or w < 30:
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
    if name != "cannon":
        for key, lst in list(frames.items()):
            if key[0] == "death":
                continue
            frames[key] = [p for im in lst for p in split(im)]
    small = {}
    for key, lst in frames.items():
        small[key] = [snap_team(shrink(im, UNIT_SCALE)) for im in lst]
    assemble(name, small, names, data)


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


def import_brood_unit(name, cfg, data):
    px = load(f"art/brood/{name}.png")
    fg = checker_mask(px)
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
        med = sorted(s["area"] for s in lst)[len(lst) // 2]
        lst = [s for s in lst if s["area"] >= med * 0.4]   # drop slash arcs / flying spit
        if ri == 0:
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
    make_icon(small[("idle", "s")][0], name)


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


def import_buildings(data):
    data["buildings"] = {}
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
    print("  effects", data["effects"])


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
        print(f"  {name}: ok")
    make_swamp_tile()
    print("buildings")
    import_buildings(data)
    print("world")
    import_mine(data)
    import_nature(data)
    import_tiles(data)
    import_effects(data)
    import_icons(data)
    os.makedirs("scripts", exist_ok=True)
    write_data(data)


if __name__ == "__main__":
    main()
