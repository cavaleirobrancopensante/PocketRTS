#!/usr/bin/env python3
"""Brood veterancy skin: the Brood has no clothes to trim, so a creature's veterancy shows on
its skin, chameleon-like: as painted while it has fewer than 25 kills, amber-ochre from 25 and
near-black obsidian with a dark violet sheen from 50 (Defs.VET). The team colour (crests,
frills, wing membranes) stays as it is. This pass writes, next to the sprites, a mask per
sprite strip that shaders/team.gdshader uses to recolour only the skin (the same path as the
Crown's trim masks, tools/import_vet_trim.py).

Sources
  assets/units/<unit>/<anim>_<dir>.png   the finished sprite strips (every strip of each
                                         creature: alternate ones too, deaths included)

Output
  assets/units/skin_masks/<unit>/<anim>_<dir>.png  one per strip, the same size as the strip:
      R = 255 on the skin's pixels, G = the pixel's tone (its rank among all of that
      creature's skin pixels, 0 dark .. 255 light), so the shading survives and every
      creature spans the whole amber / obsidian ramp whatever its own colour (the Skywing's
      charcoal hide too)

What is skin: every pixel of the creature but
  - the team colour (the two key reds) and the dark reds of crests, mouths and tongues
  - claws, teeth, horns and dust: light, unsaturated pixels
  - eyes, acid, glowing sacs and spores: bright saturated yellows and limes
  - the dust the Brute kicks up in his charge (tan, by his feet)
The outline darks are skin but stay dark (the shader keeps pixels darker than ~0.08).
Check the contact sheets (--contact DIR): as painted, the mask in magenta, amber, obsidian.

Usage (from the repo root, after import_vet_trim.py in tools/rebuild_art.sh):
  python3 tools/import_vet_skin.py [--contact DIR] [--only UNIT]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

from import_vet_trim import hsv, lum, team_red, team_colour

UNITS_DIR = "assets/units"
OUT = "assets/units/skin_masks"
# The Brood's fighting creatures (the Grub is a worker: no veterancy shown, like the Crown's).
UNITS = ["raptor", "spitter", "brute", "bloater", "skywing", "spore_mother", "mist_toad"]


def cells():
    src = open("scripts/art_data.gd").read()
    out = {}
    for u in UNITS:
        m = re.search(r'"%s": \{"cell": Vector2i\((\d+), (\d+)\)' % u, src)
        out[u] = (int(m.group(1)), int(m.group(2)))
    return out


GLOW = {"spore_mother": (0.15, 0.32)}     # glowing spore pods: their hues


def skin_mask(unit, key, px):
    a = px[..., 3] > 0
    rgb = px[..., :3].astype(np.float32) / 255.0
    h, s, v = hsv(rgb)
    out = a & ~team_red(px)
    # crests' and mouths' dark reds, tongues
    out &= ~(((h < 0.035) | (h > 0.93)) & (s > 0.5) & (v > 0.25))
    # claws, teeth, horns, dust: light and unsaturated
    out &= ~((v > 0.62) & (s < 0.32))
    # eyes, acid, glows: bright saturated yellows and limes (not the Bloater's: his gas sac
    # is most of him and is skin, glowing core and all, so he turns amber or obsidian all over)
    if unit != "bloater":
        out &= ~((h > 0.1) & (h < 0.33) & (s > 0.6) & (v > 0.72))
    if unit in GLOW:
        # the Spore Mother's spore pods: glowing yellow-greens, out to their shaded edges
        # (the same hue, darker)
        lo, hi = GLOW[unit]
        hue = (h > lo) & (h < hi)
        core = hue & (s > 0.45) & (v > 0.4)
        out &= ~ndimage.binary_propagation(core, mask=hue & (s > 0.3) & (v > 0.2))
    if unit == "brute" and key.startswith("charge"):
        # the dust he kicks up: tan, by his feet (the lowest 30% of the figure)
        ys = np.nonzero(a.any(1))[0]
        low = np.zeros_like(a)
        low[int(ys.max() - 0.3 * (ys.max() - ys.min())):] = True
        out &= ~(low & (h > 0.085) & (h < 0.135) & (v > 0.42))
    return out


def strips(unit):
    d = os.path.join(UNITS_DIR, unit)
    for f in sorted(os.listdir(d)):
        if f.endswith(".png"):
            yield f[:-4], os.path.join(d, f)


def tone_map(data):
    ls = np.concatenate([lum(im[..., :3].astype(np.float32) / 255.0)[m] for im, m in data.values()])
    ls = np.sort(ls[ls >= BODY_L])
    def rank(l):
        return np.searchsorted(ls, l, side="right") / max(len(ls), 1)
    return rank


BODY_L = 0.08     # below this a skin pixel is outline (kept as painted by the shader)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a * (1 - t) + b * t


# What shaders/team.gdshader does to a skin pixel of tone t (keep the two in step).
def ramp(level, t):
    t = t[..., None]
    if level == 1:      # amber-ochre
        c = mix(np.array([0.20, 0.10, 0.03]), np.array([0.66, 0.42, 0.12]), smoothstep(0.0, 0.6, t))
        return mix(c, np.array([0.93, 0.74, 0.38]), smoothstep(0.6, 1.0, t))
    c = mix(np.array([0.025, 0.025, 0.035]), np.array([0.12, 0.11, 0.16]), smoothstep(0.0, 0.8, t))
    return mix(c, np.array([0.48, 0.45, 0.64]), smoothstep(0.86, 1.0, t))       # obsidian, its sheen


def recolour(im, mrgb, level):
    rgb = im[..., :3].astype(np.float32) / 255.0
    t = mrgb[..., 1].astype(np.float32) / 255.0
    k = ((mrgb[..., 0] > 127) * smoothstep(0.035, 0.10, lum(rgb)))[..., None]
    o = rgb * (1 - k) + ramp(level, t) * k
    out = im.copy()
    out[..., :3] = np.clip(o * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def contact(path, results, cw, scale=3):
    """One row per strip: as painted, the mask in magenta, amber and obsidian (each in
    another team colour), every frame cut to the strip's figure."""
    from PIL import ImageDraw
    rows = []
    for key, (im, mrgb) in results.items():
        a = im[..., 3] > 0
        n = im.shape[1] // cw
        ys = np.nonzero(a.any(1))[0]
        xs = np.nonzero(np.stack([a[:, i * cw:(i + 1) * cw].any(0) for i in range(n)]).any(0))[0]
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        def cut(x):
            return np.concatenate([np.concatenate([x[y0:y1, i * cw + x0:i * cw + x1], np.zeros((y1 - y0, 2, 4), np.uint8)], 1) for i in range(n)], 1)
        dbg = im.copy()
        dbg[mrgb[..., 0] > 127, :3] = [255, 0, 255]
        rows.append((key, [cut(im), cut(dbg), cut(team_colour(recolour(im, mrgb, 1), (40, 90, 230))),
                           cut(team_colour(recolour(im, mrgb, 2), (232, 197, 58)))]))
    W = max(r.shape[1] for _, row in rows for r in row) * scale + 70
    H = sum(sum(r.shape[0] * scale + 2 for r in row) + 8 for _, row in rows)
    sheet = Image.new("RGBA", (W, H), (104, 132, 84, 255))
    dr = ImageDraw.Draw(sheet)
    y = 0
    for key, row in rows:
        dr.text((2, y + 4), key, fill=(255, 255, 255, 255))
        for label, r in zip(["painted", "mask", "amber", "obsidian"], row):
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
    for unit in UNITS:
        if only and unit != only:
            continue
        data = {}
        for key, p in strips(unit):
            im = np.asarray(Image.open(p).convert("RGBA"))
            data[key] = (im, skin_mask(unit, key, im))
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
        print("%s: %d strips with skin (of %d)" % (unit, len(results), len(data)))
        if contact_dir:
            os.makedirs(contact_dir, exist_ok=True)
            anims = sorted({k.rsplit("_", 1)[0] for k in results})
            for anim in anims:
                sub = {k: v for k, v in results.items() if k.rsplit("_", 1)[0] == anim}
                contact(os.path.join(contact_dir, "skin_%s_%s.png" % (unit, anim)), sub, cs[unit][0])


if __name__ == "__main__":
    main()
