#!/usr/bin/env python3
"""THE VENOM LINE COLOUR SWAP (the owner, 2026-10-29 15:17; docs/brood_replace.md, mock-up
docs/shots/venom_colours/swap_mockup.png): the Spitter, the Venom Challenger, the Venom Sire (art
"dilophosaurus") and the Mist Toad wear their SCALES in the team colour and their SPIKES and FRILL in
OLIVE (the other way round from every other Brood creature, whose crests are the team colour). The
venom's glow (the drool, the acid, the eyes) keeps its yellow-green.

The strips are not changed: this pass writes, next to them, one mask per strip that
shaders/team.gdshader reads when the unit's `venom_swap` is on (VetLook.update_mask sets it):

  assets/units/venom_masks/<unit>/<anim>_<dir>.png   the same size as the strip
      R = 255 on a scale pixel (the team colour goes there)
      G = that scale pixel's tone (its rank among all the creature's scale pixels, 0 dark .. 255
          light), so the shading survives in every team colour
      B = 0, or 1 + the tone (0..254) of a SPIKE pixel (the olive goes there)

What is a spike: the team-red pixels as painted (the two key reds), the reds shading them (red
hues within 2 px of a key red: their edges and the frill's dark folds) and the frill's bright
orange-yellow folds between its red ribs (within 3 px of one; the drool and the glob are limes). What is a scale: the
Brood's skin (tools/import_vet_skin.py: no claws, teeth, eyes, acid, glows, mouths) in the body's
olive-to-green hues (0.095 .. 0.30): the Venom Sire's nest, its fire and its red eggs, the pale
claws and the tan dust stay as painted. Outline darks stay dark (the shader keeps pixels darker
than ~0.08).

Usage (from the repo root; after the importers of these units and tools/import_vet_skin.py in
tools/rebuild_art.sh): python3 tools/import_venom_colours.py [--contact DIR] [--only UNIT]
--contact writes one sheet per unit: as painted, then the swap in red and in blue (the shader's
sums done here in NumPy, keep the two in step). Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_vet_trim import hsv, lum, team_red        # noqa: E402
from import_vet_skin import skin_mask                 # noqa: E402

UNITS_DIR = "assets/units"
OUT = "assets/units/venom_masks"
UNITS = ["spitter", "venom_challenger", "dilophosaurus", "mist_toad"]
SCALE_HUE = (0.095, 0.30)
BODY_L = 0.08


def strips(unit):
    d = os.path.join(UNITS_DIR, unit)
    for f in sorted(os.listdir(d)):
        if f.endswith(".png") and not f.startswith("glow_"):      # (glow_*: the glow masks, not pictures)
            yield f[:-4], os.path.join(d, f)


def masks(unit, key, px):
    a = px[..., 3] > 0
    rgb = px[..., :3].astype(np.float32) / 255.0
    h, s, v = hsv(rgb)
    key_red = team_red(px) & a
    reds = a & ((h < 0.06) | (h > 0.92)) & (s > 0.45) & (v > 0.15)
    near = ndimage.binary_dilation(key_red, iterations=2)
    # the frill's bright orange-yellow folds between its red ribs (the drool and the glob are limes, h > 0.15)
    frill = a & (h > 0.04) & (h < 0.15) & (s > 0.55) & (v > 0.56) & ndimage.binary_dilation(key_red, iterations=3)
    spike = key_red | (reds & near) | frill
    skin = skin_mask(unit if unit != "venom_challenger" else "spitter", key, px)
    lime = (h > 0.16) & (s > 0.6) & (v > 0.45)        # (the venom's drool and drops, darker ones too: they keep their glow)
    scale = skin & (h >= SCALE_HUE[0]) & (h <= SCALE_HUE[1]) & (s > 0.15) & ~spike & ~lime
    return scale, spike


def ranker(values):
    vs = np.sort(values[values >= BODY_L]) if values.size else values
    def rank(l):
        return np.searchsorted(vs, l, side="right") / max(len(vs), 1)
    return rank


# what shaders/team.gdshader does (keep in step): the team ramp on a scale, the olive ramp on a spike
OLIVE = (np.array([0.235, 0.243, 0.078]), np.array([0.435, 0.443, 0.129]), np.array([0.675, 0.682, 0.31]))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a * (1 - t) + b * t


def team_ramp(team, t):
    t = t[..., None]
    c = mix(team * 0.24, team * 0.85, smoothstep(0.0, 0.7, t))
    return mix(c, mix(team, np.ones(3), 0.35), smoothstep(0.7, 1.0, t))


def olive_ramp(t):
    t = t[..., None]
    return mix(mix(OLIVE[0], OLIVE[1], smoothstep(0.0, 0.5, t)), OLIVE[2], smoothstep(0.5, 1.0, t))


def preview(im, m, team):
    rgb = im[..., :3].astype(np.float32) / 255.0
    l = lum(rgb)
    k = ((m[..., 0] > 127) * smoothstep(0.035, 0.10, l))[..., None]
    o = rgb * (1 - k) + team_ramp(np.array(team) / 255.0, m[..., 1].astype(np.float32) / 255.0) * k
    sp = m[..., 2] > 0
    ol = olive_ramp((m[..., 2].astype(np.float32) - 1.0) / 254.0)
    o[sp] = ol[sp]
    # (what is left of the key reds, none: they are all spikes)
    out = im.copy()
    out[..., :3] = np.clip(o * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def main():
    args = sys.argv[1:]
    contact_dir = args[args.index("--contact") + 1] if "--contact" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    for unit in UNITS:
        if only and unit != only:
            continue
        data = {}
        for key, p in strips(unit):
            im = np.asarray(Image.open(p).convert("RGBA"))
            data[key] = (im,) + masks(unit, key, im)
        all_l = lambda which: np.concatenate([lum(im[..., :3].astype(np.float32) / 255.0)[m] for im, sc, sp in data.values() for m in [(sc if which == 0 else sp)]])
        rank_scale = ranker(all_l(0))
        rank_spike = ranker(all_l(1))
        udir = os.path.join(OUT, unit)
        os.makedirs(udir, exist_ok=True)
        for f in os.listdir(udir):
            if f.endswith(".png"):
                os.remove(os.path.join(udir, f))
        shown = []
        n_sc = n_sp = 0
        for key, (im, sc, sp) in data.items():
            l = lum(im[..., :3].astype(np.float32) / 255.0)
            o = np.zeros(sc.shape + (3,), np.uint8)
            o[..., 0] = sc * 255
            o[..., 1] = np.where(sc, np.clip(rank_scale(l) * 255 + 0.5, 0, 255), 0).astype(np.uint8)
            o[..., 2] = np.where(sp, 1 + np.clip(rank_spike(l) * 254 + 0.5, 0, 254), 0).astype(np.uint8)
            Image.fromarray(o).save(os.path.join(udir, key + ".png"))
            n_sc += int(sc.sum())
            n_sp += int(sp.sum())
            shown.append((key, im, o))
        print("%s: %d strips, %d scale and %d spike pixels" % (unit, len(data), n_sc, n_sp))
        if contact_dir:
            os.makedirs(contact_dir, exist_ok=True)
            rows = []
            for key, im, o in shown[:6]:
                rows.append(np.concatenate([im, preview(im, o, (214, 40, 40)), preview(im, o, (46, 98, 230))], 0))
            W = max(r.shape[1] for r in rows)
            H = sum(r.shape[0] + 4 for r in rows)
            sheet = Image.new("RGBA", (W, H), (20, 26, 30, 255))
            y = 0
            for r in rows:
                sheet.alpha_composite(Image.fromarray(r), (0, y))
                y += r.shape[0] + 4
            sheet.save(os.path.join(contact_dir, "%s.png" % unit))


if __name__ == "__main__":
    main()
