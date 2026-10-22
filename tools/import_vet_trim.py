#!/usr/bin/env python3
"""Veterancy trim: a Crown soldier's veterancy shows on his clothes. A few small details of
each fighting man's sprite (the lace of a tricorne, the band of a plumed felt hat, the comb and
brim of a steel helmet) are drawn black while he has fewer than 25 kills, silver from 25 and
gold from 50 (Defs.VET). The sprites keep their painted colours; this pass writes, next to
them, a mask per sprite strip that shaders/team.gdshader uses to recolour only those details.

Sources
  assets/units/<art>/<anim>_<dir>.png   the finished sprite strips (run after every pass that
                                        writes them, mount strips included: see rebuild_art.sh)

Output
  assets/units/trim_masks/<art>/<anim>_<dir>.png  one per strip where the detail was found,
      the same size as the strip: R = 255 on the detail's pixels, G = the pixel's tone (its
      rank among all of that sprite set's detail pixels, 0 dark .. 255 light), so the shading
      survives the recolouring. The shader maps the tone onto black, silver or gold.

How the detail is found, per frame
  1. the head: above the top of the man's red coat (the topmost team-red regions, as in
     import_horse_coats.py: what is above each one's top over its width + a pad), so never
     the coat, the team colour, the musket's lock or the horse
  2. by the sprite set's STYLE, inside the head box:
     lace   the tricorne's gold lace: warm yellow/tan pixels (hue 0.085-0.2, saturated, not
            dark), lighter than the face's skin by hue; only in the hat's rows (above the
            face: the lowest lace row + 1 at most)
     band   the plumed felt hat's band: the dark pixels right under the brown felt, per column
            (the hat's lower edge), above the face
     helmet a steel helmet's comb (its top two steel rows) and brim (the lowest steel pixel
            of each column): the helmet is the largest blob of steel greys in the head box
            after an opening (the musket's 1-px barrel falls away)
  3. specks and pixels touching skin are dropped
Every strip is checked by eye in the contact sheets (--contact DIR): the strip as painted, the
mask in magenta, and the details black, silver and gold, in two team colours.

Usage (from the repo root, after import_horse_coats.py in tools/rebuild_art.sh):
  python3 tools/import_vet_trim.py [--contact DIR] [--only ART]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_horse_coats import fb_left  # noqa: E402

UNITS_DIR = "assets/units"
OUT = "assets/units/trim_masks"
DIRS = ["s", "se", "e", "ne", "n"]

# Per sprite set: the style of its detail and the strips it is in (anim names; every
# direction). Death strips too: a man who falls keeps his trim while he still has his hat on.
FOOT = ["idle", "walk", "aim", "fire", "aimup", "fireup", "reload", "melee", "death"]
RIDER = ["idle", "walk", "attack", "death", "mount"]
CONFIG = {
    "musketeer": {"style": "lace", "anims": FOOT},
    "dragoon": {"style": "lace", "anims": RIDER},
    "musketeer_armoured": {"style": "helmet", "anims": FOOT},
    "dismounted_armoured": {"style": "helmet", "anims": FOOT},
    # (DROP boxes, frame coordinates, optionally the frames they're for: the raised sabre's
    # hilt and hand over his head, not his helmet)
    "cuirassier": {"style": "helmet", "anims": RIDER,
                   "drop": {"attack_s": [(40, 0, 52, 14, [0])], "attack_se": [(40, 0, 50, 19, [1])],
                            "attack_n": [(40, 0, 50, 20, [1])]}},
    "dragoon_armoured": {"style": "helmet", "anims": RIDER},
    "dismounted": {"style": "band", "anims": FOOT},
    "horseman": {"style": "band", "anims": RIDER},
}


def cells():
    src = open("scripts/art_data.gd").read()
    out = {}
    for u in CONFIG:
        m = re.search(r'"%s": \{"cell": Vector2i\((\d+), (\d+)\)' % u, src)
        out[u] = (int(m.group(1)), int(m.group(2)))
    return out


def hsv(rgb):
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, ((g - b) / dd) % 6, h)
    h = np.where(mx == g, (b - r) / dd + 2, h)
    h = np.where(mx == b, (r - g) / dd + 4, h)
    h = np.where(d == 0, 0, h) / 6.0
    return h, s, mx


def lum(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def team_red(px):
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    return (g == 0) & (b == 0) & ((r == 255) | (r == 150))


def head_box(px, pad=3, whole=False):
    """Above the man's shoulders: the topmost team-red regions of 6+ pixels (a plume on his
    helmet, a raised arm: every red region starting within 12 rows of the top one counts).
    What is above each one's top, over its width + pad. `whole`: above the biggest one's top
    (his coat), over all their widths: a plume or a pennant on a helmet stays in the box."""
    red = team_red(px)
    lab, n = ndimage.label(red, structure=np.ones((3, 3)))
    m = np.zeros(red.shape, bool)
    if not n:
        return m
    objs = list(enumerate(ndimage.find_objects(lab)))
    big = [sl for i, sl in objs if (lab[sl] == i + 1).sum() >= 6]
    if not big:
        return m
    top = min(sl[0].start for sl in big)
    if whole:
        near = [(i, sl) for i, sl in objs if (lab[sl] == i + 1).sum() >= 6 and sl[0].start <= top + 12]
        coat = max(near, key=lambda o: (lab[o[1]] == o[0] + 1).sum())[1]
        x0 = min(sl[1].start for _, sl in near)
        x1 = max(sl[1].stop for _, sl in near)
        m[:coat[0].start, max(x0 - pad, 0):x1 + pad] = True
        return m
    for sl in big:
        if sl[0].start <= top + 12:
            m[:sl[0].start, max(sl[1].start - pad, 0):sl[1].stop + pad] = True
    return m


def skyline_box(px, pad=3):
    """Above the man's red per column: over each column of his coat (the team-red regions of
    12+ pixels starting within 16 rows of the topmost), what is above its topmost red pixel
    (the lowest of its neighbours' within `pad`, for the head's sides). A raised sword arm
    then leaves the head beside it in the box; a small plume on a helmet doesn't count."""
    red = team_red(px)
    lab, n = ndimage.label(red, structure=np.ones((3, 3)))
    m = np.zeros(red.shape, bool)
    if not n:
        return m
    objs = list(enumerate(ndimage.find_objects(lab)))
    big = [(i, sl) for i, sl in objs if (lab[sl] == i + 1).sum() >= 12]
    if not big:
        return m
    top = min(sl[0].start for _, sl in big)
    coat = np.isin(lab, [i + 1 for i, sl in big if sl[0].start <= top + 16])
    H, W = red.shape
    tops = np.full(W, -1)
    for x in np.nonzero(coat.any(0))[0]:
        tops[x] = np.nonzero(coat[:, x])[0].min()
    for x in range(W):
        near = tops[max(x - pad, 0):x + pad + 1]
        near = near[near >= 0]
        if len(near):
            m[:near.max() if tops[x] < 0 else tops[x], x] = True
    return m


HAT_H = 5         # rows of a felt hat, crown to brim
HELM_H = 7        # rows of a steel helmet, comb to brim


def skin_of(h, s, v):
    return (h >= 0.02) & (h < 0.085) & (s >= 0.25) & (s < 0.7) & (v >= 0.45)


def frame_mask(style, px, drop=()):
    a = px[..., 3] > 0
    for x0, y0, x1, y1 in drop:
        a[y0:y1, x0:x1] = False
    rgb = px[..., :3].astype(np.float32) / 255.0
    h, s, v = hsv(rgb)
    box = head_box(px) & a & ~team_red(px)
    out = np.zeros(box.shape, bool)
    if not box.any():
        return out
    skin = skin_of(h, s, v) & box
    if style == "lace":
        lace = box & (h >= 0.085) & (h < 0.2) & (s >= 0.25) & (v >= 0.33)
        # the hat's: bits of lace starting within 3 rows of the topmost one (not a glint on
        # the cheek, a buckle on the shoulder)
        lab, n = ndimage.label(lace, structure=np.ones((3, 3)))
        if n:
            sls = ndimage.find_objects(lab)
            top = min(sl[0].start for sl in sls)
            for i, sl in enumerate(sls):
                if sl[0].start <= top + 3:
                    out |= lab == i + 1
    elif style == "band":
        # the brim's edge: the lowest felt pixel of each column, in the hat's rows (from the
        # first row with 3+ felt pixels, HAT_H rows down: the face's browns are below)
        felt = box & (h >= 0.03) & (h < 0.12) & (s >= 0.3) & (v >= 0.2) & (v < 0.75)
        rows = np.nonzero(felt.sum(1) >= 3)[0]
        if len(rows):
            hat = felt.copy()
            hat[:rows[0]] = False
            hat[rows[0] + HAT_H:] = False
            for x in np.nonzero(hat.any(0))[0]:
                ys = np.nonzero(hat[:, x])[0]
                out[ys.max(), x] = True
                y = ys.max()
                over_face = y + 1 < px.shape[0] and skin_of(h[y + 1, x], s[y + 1, x], v[y + 1, x])
                if len(ys) >= 3 and hat[y - 1, x] and not over_face:
                    out[y - 1, x] = True     # (two rows where the felt is deep enough: a band; one over the face)
        skin = np.zeros_like(skin)     # (the felt's browns are the skin's)
    elif style == "helmet":
        box = (head_box(px, whole=True) | skyline_box(px)) & a & ~team_red(px)
        steel = box & (s < 0.25) & (v >= 0.17)
        lab, n = ndimage.label(steel, structure=np.ones((3, 3)))
        sls = ndimage.find_objects(lab)
        # not a musket's barrel or a blade: long thin bits
        def thin(sl):
            w, hh = sl[1].stop - sl[1].start, sl[0].stop - sl[0].start
            return min(w, hh) <= 3 and max(w, hh) >= 2 * min(w, hh) + 2
        def fill(i):
            sl = sls[i]
            return (lab[sl] == i + 1).sum() / float((sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start))
        # (and a raised sabre's curve: few of its box's pixels)
        keep = [i for i in range(n) if not thin(sls[i]) and fill(i) >= 0.3]
        if keep:
            # the helmet: from the top of its biggest bit HELM_H rows down (not a breastplate
            # under it), near its columns
            sizes = ndimage.sum(steel, lab, [k + 1 for k in keep])
            i = keep[int(np.argmax(sizes))]
            top = sls[i][0].start
            x0, x1 = sls[i][1].start, sls[i][1].stop
            helm = np.isin(lab, [k + 1 for k in keep])
            helm[:top] = False
            helm[top + HELM_H:] = False
            helm[:, :max(x0 - 4, 0)] = False
            helm[:, x1 + 4:] = False
            ys = np.nonzero(helm.any(1))[0]
            for y in ys[:2]:
                out[y] |= helm[y]
            for x in np.nonzero(helm.any(0))[0]:
                y = np.nonzero(helm[:, x])[0].max()
                if y + 1 < px.shape[0] and steel[y + 1, x]:
                    continue        # (more steel under it: not the brim's edge)
                if y < ys[-1] - 1:
                    continue        # (a gap in the steel, not its lower edge)
                out[y, x] = True
    # nothing touching the face
    if skin.any():
        out &= ~skin
    return out


def strips(unit):
    for anim in CONFIG[unit]["anims"]:
        for d in DIRS:
            p = os.path.join(UNITS_DIR, unit, "%s_%s.png" % (anim, d))
            if os.path.exists(p):
                yield anim, d, p


FB_BESIDE = 2     # front / back mounting strips: frames where the man still stands beside the horse
UPRIGHT = 0.8    # a death frame at least this tall (of the strip's tallest) still has him up


def build_unit(unit, cell):
    cw = cell[0]
    style = CONFIG[unit]["style"]
    out = {}
    for anim, d, p in strips(unit):
        im = np.asarray(Image.open(p).convert("RGBA"))
        H, W = im.shape[:2]
        mask = np.zeros((H, W), bool)
        n = W // cw
        # (a front / back mounting strip: in its first frames the man stands beside the horse,
        # and its ears above the saddle cloth would pass for his helmet: only his side counts)
        beside = fb_left(im, cw) + 1 if anim == "mount" and d in ("s", "n") else None
        tall = [np.ptp(np.nonzero(im[:, i * cw:(i + 1) * cw, 3].any(1))[0]) if im[:, i * cw:(i + 1) * cw, 3].any() else 0 for i in range(n)]
        for fi in range(n):
            # (falling: only while he is still up; lying down his head is anywhere)
            if anim == "death" and tall[fi] < UPRIGHT * max(tall):
                continue
            drop = [b[:4] for b in CONFIG[unit].get("drop", {}).get(anim + "_" + d, []) if len(b) < 5 or fi in b[4]]
            if beside is not None and fi < FB_BESIDE:
                drop.append((beside, 0, cw, H))
            elif beside is not None and style == "helmet":
                # (on the horse, his helmet is the top of the picture: from behind, his back
                # plate is a bigger piece of steel)
                top = int(np.nonzero(im[:, fi * cw:(fi + 1) * cw, 3].any(1))[0].min())
                drop.append((0, top + HELM_H + 2, cw, H))
            mask[:, fi * cw:(fi + 1) * cw] = frame_mask(style, im[:, fi * cw:(fi + 1) * cw], drop)
        out["%s_%s" % (anim, d)] = (im, mask)
    return out


def tone_map(data):
    ls = np.concatenate([lum(im[..., :3].astype(np.float32) / 255.0)[m] for im, m in data.values()])
    ls = np.sort(ls)
    def rank(l):
        return np.searchsorted(ls, l, side="right") / max(len(ls), 1)
    return rank


# What shaders/team.gdshader does with a detail pixel's tone t, per veterancy level.
LEVELS = {
    0: ((0.05, 0.05, 0.06), (0.22, 0.22, 0.24)),       # black (still shaded: it reads as trim)
    1: ((0.42, 0.45, 0.50), (0.96, 0.97, 1.00)),       # silver
    2: ((0.50, 0.30, 0.04), (1.00, 0.88, 0.36)),       # gold
}


def recolour(im, mrgb, level):
    t = (mrgb[..., 1].astype(np.float32) / 255.0)[..., None]
    lo, hi = (np.array(c, np.float32) for c in LEVELS[level])
    col = lo + (hi - lo) * t
    m = mrgb[..., 0] > 127
    out = im.copy()
    out[m, :3] = np.clip(col[m] * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def team_colour(im, col):
    out = im.copy()
    r = (im[..., 0] == 255) & (im[..., 1] == 0) & (im[..., 2] == 0)
    r2 = (im[..., 0] == 150) & (im[..., 1] == 0) & (im[..., 2] == 0)
    out[r, :3] = col
    out[r2, :3] = [int(c * 0.6) for c in col]
    return out


def cropper(im, mask, cw):
    """Each frame cut to the strip's head (the rows of its detail, a few above and more below
    for the face and shoulders; the columns of the figure), side by side with a 2 px gap."""
    a = im[..., 3] > 0
    n = im.shape[1] // cw
    ys = np.nonzero(mask.any(1))[0]
    xs = np.nonzero(np.stack([a[:, i * cw:(i + 1) * cw].any(0) for i in range(n)]).any(0))[0]
    y0, y1 = max(ys.min() - 3, 0), min(ys.max() + 9, im.shape[0])
    x0, x1 = xs.min(), xs.max() + 1
    def cut(x):
        parts = []
        for i in range(n):
            parts.append(x[y0:y1, i * cw + x0:i * cw + x1])
            parts.append(np.zeros((y1 - y0, 2, 4), np.uint8))
        return np.concatenate(parts, 1)
    return cut


SHOW = [(255, 0, 0), (40, 90, 230), (30, 170, 160)]


def contact(path, results, cw, scale=4):
    """One row per strip: as painted, the mask in magenta, then black, silver and gold (each
    in another team colour)."""
    from PIL import ImageDraw
    rows = []
    for key, (im, mrgb) in results.items():
        m = mrgb[..., 0] > 127
        dbg = im.copy()
        dbg[m, :3] = [255, 0, 255]
        cut = cropper(im, m, cw)
        row = [cut(im), cut(dbg)] + [cut(team_colour(recolour(im, mrgb, lv), SHOW[lv])) for lv in range(3)]
        rows.append((key, row))
    W = max(r.shape[1] for _, row in rows for r in row) * scale + 70
    H = sum(sum(r.shape[0] * scale + 2 for r in row) + 8 for _, row in rows)
    sheet = Image.new("RGBA", (W, H), (104, 132, 84, 255))
    dr = ImageDraw.Draw(sheet)
    y = 0
    for key, row in rows:
        dr.text((2, y + 4), key, fill=(255, 255, 255, 255))
        for label, r in zip(["painted", "mask", "black", "silver", "gold"], row):
            dr.text((2, y + 16), label, fill=(255, 255, 160, 255))
            ii = Image.fromarray(r)
            ii = ii.resize((ii.width * scale, ii.height * scale), Image.NEAREST)
            sheet.alpha_composite(ii, (70, y))
            y += ii.height + 2
        dr.line([(0, y + 3), (W, y + 3)], fill=(40, 50, 40, 255))
        y += 8
    sheet.save(path)


def main():
    args = sys.argv[1:]
    contact_dir = args[args.index("--contact") + 1] if "--contact" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    cs = cells()
    os.makedirs(OUT, exist_ok=True)
    for unit in CONFIG:
        if only and unit != only:
            continue
        data = build_unit(unit, cs[unit])
        rank = tone_map(data)
        udir = os.path.join(OUT, unit)
        os.makedirs(udir, exist_ok=True)
        for f in os.listdir(udir):
            if f.endswith(".png"):
                os.remove(os.path.join(udir, f))
        results = {}
        for key, (im, mask) in data.items():
            if not mask.any():
                continue
            tone = rank(lum(im[..., :3].astype(np.float32) / 255.0))
            o = np.zeros(mask.shape + (3,), np.uint8)
            o[..., 0] = mask * 255
            o[..., 1] = np.where(mask, np.clip(tone * 255 + 0.5, 0, 255), 0).astype(np.uint8)
            Image.fromarray(o).save(os.path.join(udir, key + ".png"))
            results[key] = (im, o)
        print("%s: %d strips with trim (of %d)" % (unit, len(results), len(data)))
        if contact_dir:
            os.makedirs(contact_dir, exist_ok=True)
            for anim in CONFIG[unit]["anims"]:
                sub = {k: v for k, v in results.items() if k.rsplit("_", 1)[0] == anim}
                if sub:
                    contact(os.path.join(contact_dir, "%s_%s.png" % (unit, anim)), sub, cs[unit][0])


if __name__ == "__main__":
    main()
