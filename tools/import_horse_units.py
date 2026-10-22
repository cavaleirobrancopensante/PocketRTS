"""The horse system's units from the designer's sheets (flat slate backgrounds):

  art/crown/horse_riderless.png     the riderless saddled horse: 5 rows (S, SE, E, NE, N), each
                                    2 standing, 3 grazing (head down), 4-6 walking, 3 death frames
  art/crown/messenger.png           the Labourer on horseback: 5 rows, 2 standing, 8 gallop, 5 death
  art/crown/dragoons.png            8 rows: the light Dragoon (tricorne) S, SE, E, N, then the
                                    Armoured Dragoon (morion) S, SE, E, N: 2 standing, 10 gallop,
                                    5 death each. No NE row: the E strips are used for NE.
  art/crown/horseman_dismounted.png the Horseman on foot: 5 rows, 2 standing, 9 walking, aim and
                                    shot (with the muzzle flash), 5 sabre slashes, 5 death frames
  art/crown/cuirassier_dismounted.png the Cuirassier on foot (morion, red plume: team colour):
                                    5 rows, 2 standing, 7 walking, aim, aim, shot, 6 sabre poses,
                                    2 death frames. Its sabre poses don't show a cut: only the 1st
                                    (fist raised) and 2nd (sabre over his head) face the attack, the
                                    rest face the viewer with no sabre. The attack (sabre_attack) is
                                    4 frames: the 1st with a blade drawn in raised behind, the 2nd,
                                    the 1st with the blade swept forward (and its swing's trail),
                                    the 1st with it swept down.

Frames are found by themselves: the foreground (not the slate) is split into rows by empty
lines and into frames by empty columns; slivers (a sabre tip, a puff of smoke) join their
neighbour and frames drawn touching are split at their thinnest column. Each frame goes to its
animation by where it starts on the sheet (GROUPS: the animations stand in columns).

Scale: one per sheet, so that its standing frames in the E row stand as tall as the reference
(REF_H: the Horseman's idle_e for the riders, his horse for the riderless horse, the Musketeer's
idle_e for the man on foot). Cells: the mounted units and the horse on the Cuirassier's cell
(98x70, anchor 49,66), the man on foot on the Musketeer's (90x36, anchor 45,34). Every frame is
centred on its own middle and stands on its row's ground line (the standing frames' feet).

Fixes:
  - the grazing frames of the horse's S row are drawn side on: the SE row's are used for S.
  - the dismounted Horseman's slash: the sheet's 3rd slash pose has no sabre and the 4th and
    5th look backwards. The melee strip is the 1st and 2nd slash and the 2nd with its sabre
    turned down into the cut, so the head always faces the attack.

The red coats, banners and saddle cloths are snapped to the team key reds. Horse coat masks:
tools/import_horse_coats.py (its "horse", "messenger", "dragoon", "dragoon_armoured" entries;
run after this). Writes assets/units/<art>/<anim>_<dir>.png and the art's scripts/art_data.gd
entries (added or replaced; nothing else is touched).

Usage (from the repo root): python3 tools/import_horse_units.py [--contact DIR]
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402


def shrink(img, scale, keep=0.3):
    """Box-filter downscale with premultiplied alpha, then hard alpha from `keep` coverage
    (lower than import_art's 0.45, so a horse's thin legs stay whole)."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= keep, 255, 0)
    out[out[..., 3] == 0] = 0
    return out
from import_cannon2 import clean, defringe  # noqa: E402

ART_DATA = "scripts/art_data.gd"
CAV = ((98, 70), (49, 66))
FOOT = ((90, 36), (45, 34))
DIRS5 = ["s", "se", "e", "ne", "n"]
DIRS4 = ["s", "se", "e", "n"]

# per sheet: rows -> (art, dir); GROUPS: (anim, x from) in order; the E-row standing height
SHEETS = {
    "horse_riderless": {
        "rows": [("horse", d) for d in DIRS5],
        "groups": [("idle", 0), ("graze", 240), ("walk", 540), ("death", 1040)],
        "cell": CAV, "ref_h": 46, "expect": {"death": 3},
    },
    "messenger": {
        "rows": [("messenger", d) for d in DIRS5],
        "groups": [("idle", 0), ("walk", 240), ("death", 1010)], "expect": {"death": 5},
        "cell": CAV, "ref_h": 52,
    },
    "dragoons": {
        "rows": [("dragoon", d) for d in DIRS4] + [("dragoon_armoured", d) for d in DIRS4],
        "groups": [("idle", 0), ("walk", 195), ("death", 1060)], "expect": {"death": 5},
        "cell": CAV, "ref_h": 52,
    },
    "horseman_dismounted": {
        "rows": [("dismounted", d) for d in DIRS5],
        "groups": [("idle", 0), ("walk", 175), ("fire2", 700), ("slash", 850), ("death", 1180)],
        "cell": FOOT, "ref_h": 33, "expect": {"fire2": 2, "slash": 5, "death": 5},
    },
    # the Dismounted Cuirassier: 2 standing, 7 walking, aim, aim, shot (with the flash), 6 sabre
    # poses (only the first two face the attack, and none shows the cut: see sabre_attack), 2 death
    "cuirassier_dismounted": {
        "rows": [("dismounted_armoured", d) for d in DIRS5],
        "groups": [("idle", 0), ("walk", 180), ("fire3", 570), ("sabre", 845), ("death", 1285)],
        "cell": FOOT, "ref_h": 35, "expect": {"fire3": 3, "sabre": 6, "death": 2},
    },
}

# a blade drawn in at sheet resolution: steel, its edges, and the swing's trail
BLADE = {"len": 46, "steel": (214, 220, 228), "edge": (52, 54, 62), "hilt": (196, 156, 64), "trail": (236, 240, 246)}


def hand_of(img):
    """(sheet resolution) where his sword hand is: the gold of the hilt he holds, else the
    rightmost point of his upper half (the raised arm)."""
    a = img[..., 3] > 0
    rgb = img[..., :3].astype(int)
    ya = np.nonzero(a.any(1))[0]
    gold = a & (rgb[..., 0] > 150) & (rgb[..., 1] > 100) & (rgb[..., 2] < 90) & (rgb[..., 0] - rgb[..., 2] > 90)
    gold[int(ya.min() + (ya.max() - ya.min()) * 0.45):] = False      # (not his belt buckle)
    if gold.sum() >= 3:
        ys, xs = np.nonzero(gold)
        return float(np.median(ys)), float(np.median(xs))
    ys, xs = np.nonzero(a)
    up = ys < ys.min() + (ys.max() - ys.min()) * 0.45
    i = int(np.argmax(np.where(up, xs, -1)))
    return float(ys[i]), float(xs[i])


def with_blade(img, deg, trail_from=None):
    """The frame with a sabre drawn from his hand at `deg` (0 = straight ahead, + = down), and
    a swing trail from `trail_from` degrees to it. The picture grows to fit the blade."""
    L = BLADE["len"]
    pad = L + 8
    h, w = img.shape[:2]
    out = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.uint8)
    out[pad:pad + h, pad:pad + w] = img
    hy, hx = hand_of(img)
    hy += pad
    hx += pad

    def put(y, x, col):
        yi, xi = int(round(y)), int(round(x))
        if 0 <= yi < out.shape[0] and 0 <= xi < out.shape[1]:
            out[yi, xi, :3] = col
            out[yi, xi, 3] = 255

    if trail_from is not None:
        for t in np.linspace(np.radians(trail_from), np.radians(deg), 60):
            for r in (L - 3, L - 2, L - 1):
                put(hy + np.sin(t) * r, hx + np.cos(t) * r, BLADE["trail"])
    th = np.radians(deg)
    d = np.array([np.sin(th), np.cos(th)])
    n = np.array([d[1], -d[0]])
    for s in np.linspace(4, L, int(L * 2)):
        bend = 0.0025 * s * s            # a sabre's curve
        p = np.array([hy, hx]) + d * s + n * bend
        for o in (-2.0, 2.0):
            put(*(p + n * o), BLADE["edge"])
        for o in (-1.0, 0.0, 1.0):
            put(*(p + n * o), BLADE["steel"])
    for s in np.linspace(-3, 4, 12):
        put(*(np.array([hy, hx]) + n * s), BLADE["hilt"])
    return out, pad


def sabre_attack(sab):
    """The Dismounted Cuirassier's attack, 4 frames, from the sheet's sabre poses: only the
    1st (fist raised, facing the attack) and 2nd (sabre over his head) look the right way and
    no pose shows the cut. So: the 1st with the blade drawn raised behind, the 2nd as drawn,
    the 1st with the blade swept forward (a trail behind it), and the 1st with it swept down."""
    f0, f1 = sab[0], sab[1]
    out = []
    for deg, trail in ((-115, None), (None, None), (15, -100), (62, 0)):
        if deg is None:
            out.append(f1)
            continue
        img, pad = with_blade(f0[0], deg, trail)
        out.append((img, f0[1] - pad, f0[2] + pad, -pad))     # (the picture grew by `pad` all round)
    return out


def runs(mask1d, min_gap):
    out, start, gap, end = [], None, 0, 0
    for i, v in enumerate(mask1d):
        if v:
            if start is None:
                start = i
            gap = 0
            end = i + 1
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                out.append([start, end])
                start = None
    if start is not None:
        out.append([start, end])
    return out


def load(name):
    px = np.asarray(Image.open("art/crown/%s.png" % name).convert("RGB"))
    border = np.concatenate([px[0], px[-1], px[:, 0], px[:, -1]]).astype(float)
    bg = np.median(border, 0)
    rgb = px.astype(float)
    fg = np.abs(rgb - bg).max(-1) > 16
    # the slate and its drop shadows (the slate, only darker, with its blue cast) are
    # background; the dark outlines of the legs (neutral, not blue) stay
    k = (rgb * bg).sum(-1) / (bg * bg).sum()
    resid = np.abs(rgb - k[..., None] * bg).max(-1)
    cast = (rgb[..., 2] - rgb[..., 0]) >= 0.6 * (bg[2] - bg[0]) * k
    fg &= ~((k >= 0.3) & (k <= 1.15) & (resid <= 9) & cast)
    # specks (noise in the slate) go; thin legs stay (no opening)
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = (sizes >= 12)[lab - 1] & (lab > 0)
    return px, fg, bg


def frames_in_band(fg, y0, y1, groups, expect, red=None):
    """[(anim, x0, x1)] of one row band."""
    occ = fg[y0:y1].sum(0)
    cols = [c for c in runs(occ > 0, 2) if c[1] - c[0] > 6]
    # slivers join the nearest neighbour
    merged = []
    for c in cols:
        if merged and c[1] - c[0] < 22 and c[0] - merged[-1][1] < 14:
            merged[-1][1] = c[1]
        else:
            merged.append(list(c))
    cols = []
    for c in merged:
        if cols and cols[-1][1] - cols[-1][0] < 22 and c[0] - cols[-1][1] < 14:
            cols[-1][1] = c[1]
        else:
            cols.append(c)
    out = []
    for c in cols:
        g = groups[0][0]
        for name, x in groups:
            if c[0] >= x:
                g = name
        out.append([g, c[0], c[1]])
    # frames drawn touching: while a group has fewer frames than it should (EXPECT), its widest
    # piece is split at its thinnest column near the middle
    res = []
    for g in dict.fromkeys(o[0] for o in out):
        part = [o for o in out if o[0] == g]
        if g in ("fire2", "fire3") and len(part) < int(expect.get(g, 0)) and red is not None:
            # aim and shot drawn touching: the aim's musket reaches the next man, so the cut
            # goes just left of the second man's red coat
            i = max(range(len(part)), key=lambda j: part[j][2] - part[j][1])
            o = part[i]
            cols = np.nonzero(red[y0:y1, o[1]:o[2]].any(0))[0]
            gaps = np.nonzero(np.diff(cols) > 3)[0]
            if len(gaps):
                cut = o[1] + int(cols[gaps[0] + 1]) - 4
                part[i:i + 1] = [[g, o[1], cut], [g, cut, o[2]]]
        while len(part) < int(expect.get(g, 0)):
            i = max(range(len(part)), key=lambda j: part[j][2] - part[j][1])
            o = part[i]
            w = o[2] - o[1]
            lo, hi = o[1] + int(w * 0.3), o[1] + int(w * 0.7)
            cut = lo + int(np.argmin(occ[lo:hi]))
            part[i:i + 1] = [[g, o[1], cut], [g, cut, o[2]]]
        res += part
    return res


def cut_frame(px, fg, bg, y0, y1, x0, x1):
    sub = px[y0:y1, x0:x1]
    m = fg[y0:y1, x0:x1]
    m = ndimage.binary_closing(m, iterations=1) | m
    # pieces of the neighbouring frame (a barrel's end cut off it) go: anything detached much
    # smaller than the figure (a muzzle flash or a fallen hat is big enough to stay)
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = (sizes >= 0.04 * sizes.max())[lab - 1] & (lab > 0)
    img = np.zeros(sub.shape[:2] + (4,), np.uint8)
    img[..., :3] = sub
    img[..., 3] = np.where(m, 255, 0)
    img = defringe(img, bg)
    return img


def turn_sabre(img):
    """(sheet resolution) the sabre held out in front, turned down into a cut: the light grey
    blade right of the red coat, rotated 55 degrees about its hilt."""
    a = img[..., 3] > 0
    rgb = img[..., :3].astype(float)
    red = a & (rgb[..., 0] > 120) & (rgb[..., 1] < 70) & (rgb[..., 2] < 70)
    ys, xs = np.nonzero(red)
    if len(xs) == 0:
        return img
    rx = xs.max()
    mx, mn = rgb.max(-1), rgb.min(-1)
    grey = a & ((mx - mn) < 40) & (mx > 70)
    blade = np.zeros_like(a)
    blade[:, rx - 2:] = grey[:, rx - 2:]
    lab, n = ndimage.label(blade, structure=np.ones((3, 3)))
    if n == 0:
        return img
    sizes = ndimage.sum(blade, lab, range(1, n + 1))
    blade = lab == int(np.argmax(sizes)) + 1
    by, bx = np.nonzero(blade)
    piv = np.array([by[np.argmin(bx)], bx.min()], float)
    out = img.copy()
    # the blade's pixels (and their dark edges) come off
    edge = ndimage.binary_dilation(blade, iterations=1) & (rgb.max(-1) < 60) & a
    edge[:, :rx - 2] = False
    vals = img[blade]
    out[blade | edge] = 0
    th = np.radians(55.0)
    rot = np.array([[np.cos(th), np.sin(th)], [-np.sin(th), np.cos(th)]])   # (dy, dx): turns down
    h, w = out.shape[:2]
    for (yy, xx), v in zip(zip(by, bx), vals):
        d = np.array([yy, xx], float) - piv
        dy = d[1] * np.sin(th) + d[0] * np.cos(th)
        dx = d[1] * np.cos(th) - d[0] * np.sin(th)
        for oy, ox in ((0, 0), (0.5, 0), (0, 0.5)):
            ny, nx = int(round(piv[0] + dy + oy)), int(round(piv[1] + dx + ox))
            if 0 <= ny < h and 0 <= nx < w:
                out[ny, nx] = v
    return out


def place(cell, anchor, img, sx, sy, cx, ground, scale):
    """The scaled frame on its cell: its middle (cx) on the anchor, the row's ground on the
    anchor line."""
    cw, ch = cell
    out = np.zeros((ch, cw, 4), np.uint8)
    h, w = img.shape[:2]
    x = int(round(anchor[0] - (cx - sx) * scale))
    y = int(round(anchor[1] - (ground - sy) * scale))
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww, hh = min(w - sx0, cw - dx0), min(h - sy0, ch - dy0)
    if ww <= 0 or hh <= 0:
        return out
    part = img[sy0:sy0 + hh, sx0:sx0 + ww]
    m = part[..., 3] > 0
    out[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
    return out


def import_sheet(name, spec, strips):
    px, fg, bg = load(name)
    pi = px.astype(int)
    red = fg & (pi[..., 0] > 120) & (pi[..., 1] < 70) & (pi[..., 2] < 70)
    bands = [b for b in runs(fg.sum(1) > 0, 4) if b[1] - b[0] > 25]
    assert len(bands) == len(spec["rows"]), "%s: %d rows found, %d expected" % (name, len(bands), len(spec["rows"]))
    cell, anchor = spec["cell"]
    found = []
    for (art, d), (y0, y1) in zip(spec["rows"], bands):
        found.append((art, d, y0, y1, frames_in_band(fg, y0, y1, spec["groups"], spec["expect"], red)))
    # the sheet's scale from its E row's standing frames
    hs = []
    for art, d, y0, y1, fr in found:
        if d == "e":
            for g, x0, x1 in fr:
                if g == "idle":
                    ys = np.nonzero(fg[y0:y1, x0:x1].any(1))[0]
                    hs.append(ys.max() - ys.min() + 1)
    scale = spec["ref_h"] / float(np.median(hs))
    print("%s: scale %.3f" % (name, scale))
    for art, d, y0, y1, fr in found:
        ground = 0
        for g, x0, x1 in fr:
            if g == "idle":
                ys = np.nonzero(fg[y0:y1, x0:x1].any(1))[0]
                ground = max(ground, y0 + ys.max())
        frames = {}
        for g, x0, x1 in fr:
            img = cut_frame(px, fg, bg, y0, y1, x0, x1)
            frames.setdefault(g, []).append((img, x0, x1))
        if "slash" in frames:
            sl = frames.pop("slash")
            frames["melee"] = [sl[0], sl[1], (turn_sabre(sl[1][0]), sl[1][1], sl[1][2])]
        if "sabre" in frames:
            frames["melee"] = sabre_attack(frames.pop("sabre"))
        if "fire3" in frames:
            f3 = frames.pop("fire3")
            frames["aim"] = [f3[0]]
            frames["fire"] = [f3[1], f3[-1]]
        if "fire2" in frames:
            f2 = frames.pop("fire2")
            frames["aim"] = [f2[0]]
            frames["fire"] = [f2[0], f2[-1]]
        for g, lst in frames.items():
            cells = []
            for item in lst:
                img, x0, x1 = item[0], item[1], item[2]
                yoff = item[3] if len(item) > 3 else 0
                a = img[..., 3] > 0
                ys, xs = np.nonzero(a)
                if len(xs) == 0:
                    continue
                rgb = img[..., :3].astype(int)
                red = a & (rgb[..., 0] > 120) & (rgb[..., 1] < 70) & (rgb[..., 2] < 70)
                if cell == FOOT[0] and red.any() and g != "death":
                    # a man on foot: centred on his red coat (not on the musket, flash or sabre)
                    cx = x0 + float(np.median(np.nonzero(red)[1]))
                else:
                    cx = x0 + xs.mean()
                top = ys.min()
                crop = img[top:ys.max() + 1]
                small = snap_team(clean(shrink(crop, scale)))
                cells.append(place(cell, anchor, small, x0, y0 + yoff + top, cx, ground, scale))
            strips[(art, g, d)] = cells
    # fixes: the horse's S grazing is drawn side on: the SE row's
    if name == "horse_riderless":
        strips[("horse", "graze", "s")] = strips[("horse", "graze", "se")]
    if name == "dragoons":
        for art in ("dragoon", "dragoon_armoured"):
            for g in ("idle", "walk", "death"):
                strips[(art, g, "ne")] = strips[(art, g, "e")]
    return cell, anchor


def write_art_data(art, cell, anchor, counts):
    src = open(ART_DATA).read()
    lines = ['\t"%s": {"cell": Vector2i(%d, %d), "anchor": Vector2(%g, %g), "frames": {' % ((art,) + tuple(cell) + tuple(anchor))]
    for k in sorted(counts):
        lines.append('\t\t"%s": %d,' % (k, counts[k]))
    lines.append("\t}},\n")
    block = "\n".join(lines)
    m = re.search(r'\t"%s": \{"cell".*?\n\t\}\},\n' % art, src, re.S)
    if m:
        src = src[:m.start()] + block + src[m.end():]
    else:
        m = re.search(r'\t"horseman": \{"cell".*?\n\t\}\},\n', src, re.S)
        src = src[:m.end()] + block + src[m.end():]
    open(ART_DATA, "w").write(src)


def main():
    strips = {}
    cells = {}
    for name, spec in SHEETS.items():
        c = import_sheet(name, spec, strips)
        for art, _ in spec["rows"]:
            cells[art] = c
    counts = {}
    for (art, g, d), lst in strips.items():
        if not lst:
            continue
        os.makedirs("assets/units/%s" % art, exist_ok=True)
        Image.fromarray(np.concatenate(lst, 1)).save("assets/units/%s/%s_%s.png" % (art, g, d))
        counts.setdefault(art, {})["%s_%s" % (g, d)] = len(lst)
    for art, cn in counts.items():
        write_art_data(art, cells[art][0], cells[art][1], cn)
        print(art, ", ".join("%s %d" % (k, v) for k, v in sorted(cn.items())))
    if "--contact" in sys.argv:
        out = sys.argv[sys.argv.index("--contact") + 1]
        os.makedirs(out, exist_ok=True)
        for art in counts:
            keys = sorted(k for k in strips if k[0] == art)
            cw, ch = cells[art][0]
            W = max(len(strips[k]) for k in keys) * cw
            sheet = Image.new("RGBA", (W * 3, len(keys) * ch * 3), (104, 132, 84, 255))
            for i, k in enumerate(keys):
                s = Image.fromarray(np.concatenate(strips[k], 1))
                sheet.alpha_composite(s.resize((s.width * 3, s.height * 3), Image.NEAREST), (0, i * ch * 3))
            sheet.save(os.path.join(out, "contact_%s.png" % art))


if __name__ == "__main__":
    main()
