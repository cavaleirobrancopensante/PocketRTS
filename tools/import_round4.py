"""Round 4 art: the Clockwork Stormcaller, the Crown Cuirassier, the Brood Spore Mother
and the Storm / Miasma spell effects.

Sources (generated sheets on a flat slate background):
  art/clockwork/stormcaller.png   rows = directions, groups walk/idle/attack/cast/death
  art/crown/cuirassier.png        rows = directions, groups idle/gallop/slash/thrust/death
  art/brood/spore_mother.png      rows = directions, groups walk/idle/fire/root/death
  art/world/storm_and_miasma.png  6 rows: storm in/loop/out, miasma in/loop/out

The sheets only roughly follow the five directions (s, se, e, ne, n): several rows or
groups are drawn facing the wrong way. The PLANS table below picks, for every animation
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

Usage (from the repo root): python3 tools/import_round4.py [--debug DIR]
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


def unblend(img, bgc, glow):
    """Float RGBA (alpha 0..1). Glow outside the solid body is un-blended from the
    slate: alpha = the least that explains the pixel as light over the background,
    colour solved from pixel = bg*(1-a) + colour*a. Body pixels stay opaque."""
    rgb = img[..., :3].astype(float)
    a = (img[..., 3] > 0).astype(float)
    if not glow:
        return np.dstack([rgb, a]), np.zeros(a.shape, bool)
    fg = a > 0
    cand = fg & glow_kind(rgb, glow)
    # faint glow: slate-tinted halo pixels next to the glow (brighter than the slate)
    lum = rgb.mean(-1)
    halo = fg & ~cand & (lum >= bgc.mean() + 6) & ndimage.binary_dilation(cand, iterations=3) & \
        ((rgb.max(-1) - rgb.min(-1)) <= 60)
    cand |= halo
    body = fg & ~cand
    body = ndimage.binary_opening(body, iterations=2)
    body = ndimage.binary_fill_holes(ndimage.binary_closing(body, iterations=3))
    glow_m = cand & ~body
    au = np.clip((rgb - bgc) / (255.0 - bgc), 0, None).max(-1).clip(0, 1)
    col = np.clip((rgb - bgc * (1 - au[..., None])) / np.maximum(au, 1e-6)[..., None], 0, 255)
    rgb = np.where(glow_m[..., None], col, rgb)
    a = np.where(glow_m, au, a)
    return np.dstack([rgb, a]), glow_m


def to_game(img, scale, bgc, glow=None, glow_cut=0.32, mirror=False):
    """Source frame -> game-size RGBA uint8 (hard alpha) plus its glow mask."""
    f, gm = unblend(img, bgc, glow)
    h, w = f.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))

    def box(arr):
        return np.array(Image.fromarray(arr.astype(np.float32), "F").resize((nw, nh), Image.BOX))
    a = f[..., 3]
    al = box(a)
    pre = [box(f[..., c] * a) for c in range(3)]
    gl = box(gm.astype(float) * a) / np.maximum(al, 1e-6)       # share of glow in each pixel
    rgb = np.dstack(pre) / np.maximum(al, 1e-6)[..., None]
    cut = np.where(gl > 0.5, glow_cut, 0.5)
    on = al >= cut
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).round()
    out[..., 3] = np.where(on, 255, 0)
    out[~on] = 0
    glow_small = on & (gl > 0.5)
    body = out.copy()
    body[glow_small] = 0
    body = snap_team(body)
    out[~glow_small] = body[~glow_small]
    out[glow_small] = snap_team(out, effect=True)[glow_small]
    out = defringe(out, bgc)
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


UNITS = {
    "stormcaller": dict(scale=0.336, glow="blue"),
    "cuirassier": dict(scale=0.48),
    "spore_mother": dict(scale=0.6, glow="green"),
}


def debug_boxes(kind, frames):
    im = Image.open(SHEETS[kind]["path"]).convert("RGB")
    d = ImageDraw.Draw(im)
    for (r, g), lst in frames.items():
        for i, f in enumerate(lst):
            d.rectangle([f["x0"], f["y0"], f["x1"] - 1, f["y1"] - 1], outline=(255, 255, 0))
            d.text((f["x0"] + 1, f["y1"] + 1), f"{r}{g[0]}{i}", fill=(255, 255, 255))
    im.save(os.path.join(DEBUG, f"boxes_{kind}.png"))


def main():
    if DEBUG:
        os.makedirs(DEBUG, exist_ok=True)
    for kind in SHEETS:
        frames, bgc = extract(kind)
        if DEBUG:
            debug_boxes(kind, frames)
            dump_source(kind, frames, bgc)


if __name__ == "__main__":
    main()
