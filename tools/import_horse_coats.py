#!/usr/bin/env python3
"""Horse coats: every horse in the game can come in one of five coats (dark, bay, grey, white,
spotted). The sprites keep their one painted horse; this pass writes, next to them, a mask
per sprite strip that a shader (shaders/team.gdshader) uses to repaint only the horse.

Sources
  assets/units/<unit>/<anim>_<dir>.png   the finished sprite strips (run this after every
                                         other pass that writes them: see rebuild_art.sh)
  art/crown/horse_coats.png              the designer's sheet of riderless horses in the five
                                         coats; only its colours are used (the "saddled"
                                         profiles in its right-hand column)

Output
  assets/units/horse_masks/<unit>/<anim>_<dir>.png  one per strip that shows a horse, the same
      size as the strip:  R = 255 on the horse's own pixels (body, legs, mane, tail; never the
      rider, tack, saddle cloth, gun, wagon or crew), G = 255 where a spotted coat has a patch
      (blobs fixed to the frame, so they stay put on the horse from frame to frame),
      B = the pixel's tone: its rank among all of that unit's horse pixels (0 dark .. 255 light)
  assets/units/horse_masks/coat_ramps.png  64 x 5: one row per coat ramp, dark to light:
      dark, bay, grey, white, and the spotted coat's patch colour (its base is the white row)

The shader maps a horse pixel's tone onto the coat's ramp, so the horse keeps its shading
and only its colour changes; near-black pixels (outlines) stay as painted. The coat matching
a unit's painted horse (NATIVE below, also in scripts/horse_coat.gd) is not repainted at all.

How the horse is found, per frame
  1. candidates by colour: the grey horses (Cuirassier, Field Cannon) are the low-saturation
     pixels that are not the rider's blue-tinted steel; the Mortar's chestnut the brown
     pixels; the Powder Wagon's near-black horse the dull dark browns (its wood is brighter)
  2. connected regions of the mid-tone candidates; small specks are dropped
  3. per-strip boxes (frame coordinates): KEEP boxes limit the horse to where it stands,
     DROP boxes take out what the colour test can't tell apart (a helmet, a sword, a wheel)
  4. the near-black outline pixels next to the horse join it
Every strip is checked by eye in the contact sheets (--contact DIR).

Usage (from the repo root, last in tools/rebuild_art.sh):
  python3 tools/import_horse_coats.py [--contact DIR] [--only UNIT] [--debug DIR]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys
import zlib

import numpy as np
from PIL import Image
from scipy import ndimage

SHEET = "art/crown/horse_coats.png"
UNITS_DIR = "assets/units"
OUT = "assets/units/horse_masks"
COATS = ["dark", "bay", "grey", "white", "spotted"]
RAMP_N = 64

# the saddled profiles on the designer's sheet (x0, y0, x1, y1), per coat ramp row
SHEET_BOXES = {
    "dark": [(1415, 93, 1536, 161)],
    "bay": [(1415, 332, 1536, 401), (1415, 430, 1536, 498)],
    "grey": [(1415, 743, 1536, 811), (1415, 833, 1536, 900)],
    "white": [(1415, 545, 1536, 610), (1415, 637, 1536, 703)],
    "spotted": [(1415, 916, 1536, 983)],
}

# The coat each unit's sprites are painted in (left as painted when it gets that coat).
# The Mortar has none: its towed walk shows a dark horse, its other strips a chestnut, so
# every coat (bay too) is repainted, the same on both.
NATIVE = {"cuirassier": "dark", "horseman": "dark", "cannon": "dark", "powder_wagon": "dark", "mortar": ""}
NONE5 = (0, 0, 0, 0, [5])       # an empty keep box: no horse in frame 5

# Per unit: the colour test, the strips with a horse (anim names; every direction), and
# boxes in frame coordinates. Box keys: "anim_dir", "anim_*", "*_dir" or "*"; a box is
# (x0, y0, x1, y1), exclusive ends, optionally with a 5th item: the frame indices it is for.
CONFIG = {
    "cuirassier": {
        "test": "grey",
        "anims": ["idle", "walk", "attack", "death"],
        # (rows into his coat: side on, his arm reaches the reins over the horse's neck;
        # head on, the horse's head is in front of his chest)
        # (not once he falls: the horse rears and rolls over above the red; a negative
        # frame, -(i + 1), takes frame i back: side on and from behind he's still in the
        # saddle in frame 1)
        "rider_head": {"pad": 4, "below": {"s": 3, "se": 4, "e": 10, "ne": 10, "n": 10},
                       "skip": [("death", 1), ("death", 2), ("death", 3), ("death_e", -2), ("death_n", -2)]},
        "blade_v": 0.5,
        "keep": {},
        "drop": {
            # the sword's backswing over the horse's head; his face between arm and shoulder
            "attack_e": [(48, 18, 57, 40, [2]), (66, 29, 98, 34, [2])],
            # the fallen rider beside his horse: his helmet, a raised boot
            "death_s": [(70, 52, 92, 70, [3])],
            "death_se": [(70, 52, 94, 70, [3])],
            "death_e": [(78, 50, 98, 70, [3]), (57, 38, 67, 52, [3])],
            "death_ne": [(70, 50, 94, 70, [3])],
            "death_n": [(6, 55, 24, 70, [3])],
        },
    },
    # the unarmoured Horseman (tools/import_horseman.py): the same grey horse and red coat; his
    # brown hat and boots fail the grey test by themselves. Thrown in the death frames 2-3.
    "horseman": {
        "test": "grey",
        "anims": ["idle", "walk", "attack", "death"],
        "rider_head": {"pad": 4, "below": {"s": 3, "se": 4, "e": 10, "ne": 10, "n": 10},
                       "skip": [("death", 1), ("death", 2), ("death", 3)]},
        "blade_v": 0.5,
        "keep": {},
        "drop": {},
    },
    "cannon": {
        "test": "grey",
        "anims": ["walk", "deploy", "death"],
        # the limber horse alone: not the gun crew's helmets, nor (side on) the driver at
        # its head; walk_se and walk_ne are walk_e
        "keep": {
            "walk_e": [(100, 38, 140, 86)], "walk_se": [(100, 38, 140, 86)], "walk_ne": [(100, 38, 140, 86)],
            "walk_s": [(58, 66, 86, 108)],
            "walk_n": [(58, 6, 86, 54)],
            # unlimbering: the horse is led off (and fades out in frame 3)
            "deploy_e": [(100, 38, 140, 86)], "deploy_se": [(100, 38, 140, 86)], "deploy_ne": [(100, 38, 140, 86)],
            "deploy_s": [(58, 66, 86, 108, [0, 1]), (78, 73, 100, 112, [2]), (84, 68, 106, 114, [3])],
            "deploy_n": [(58, 8, 84, 56, [0]), (60, 12, 86, 58, [1]), (58, 8, 86, 58, [2]), (56, 2, 88, 48, [3])],
            # wrecked: the dead horse (none to be seen from the south)
            "death_s": [(0, 0, 0, 0)],
            "death_se": [(18, 45, 86, 72)],
            "death_e": [(8, 76, 80, 114)],
            "death_ne": [(28, 78, 90, 112)],
            "death_n": [(26, 48, 90, 78)],
        },
        # the smoke of the blast (frames 0, 1) stays smoke
        "drop": {"death_*": [(50, 50, 84, 98, [0, 1])]},
    },
    "powder_wagon": {
        "test": "dark_brown",
        "anims": ["idle", "walk", "unload", "death"],
        # the horse in front of the wagon (ne is e); in death frames 2 and 3 the wagon has
        # blown up and the horse is gone
        "keep": {
            "*_e": [(33, 46, 58, 78)], "*_ne": [(33, 46, 58, 78)],
            "*_se": [(28, 44, 58, 78)],
            "*_s": [(18, 46, 44, 78)],
            "*_n": [(20, 52, 42, 78)],
        },
        # (and the kegs being unloaded in front of it)
        "drop": {"death_*": [(0, 0, 60, 80, [2, 3])],
                 "unload_s": [(36, 48, 48, 74), (24, 46, 38, 60)],
                 "unload_n": [(40, 56, 56, 76)]},
    },
    "mortar": {
        "test": "brown",
        # The towed walk (tools/import_mortar_walk.py) has a dark grey horse; the rest the
        # chestnut pack horse. Each test's strips get their own tone ranking (see tone_map).
        "tests": {"walk": "grey"},
        "anims": ["walk", "idle_packed", "deploy"],
        "keep": {
            # walking: the horse pulling the cart, without the crewman at its head (his legs)
            # nor the mortar on the cart (its iron is grey too: dropped below). From the north
            # the sheet shows its ears over the mortar and its hind legs and tail under the cart.
            "walk_s": [(72, 50, 89, 91)],
            "walk_se": [(84, 49, 105, 64), (84, 64, 101, 90)],
            "walk_e": [(86, 38, 114, 77), (114, 38, 121, 56)],
            "walk_ne": [(85, 33, 102, 58), (85, 58, 99, 74)],
            "walk_n": [(72, 30, 85, 37), (70, 57, 86, 85)],
            # standing packed: the pack horse between its crew, minus the pack and mortar on
            # its back (the same browns as the horse). From the north-east and north it pulls
            # the mortar's cart and shows little of itself.
            "idle_packed_e": [(68, 50, 104, 79)],
            "idle_packed_s": [(64, 47, 97, 79)],
            "idle_packed_se": [(60, 40, 95, 77)],
            "idle_packed_ne": [(78, 44, 94, 73)],
            "idle_packed_n": [(71, 42, 84, 62)],
            # setting up: unharnessed, the horse rears, is led off to the right past a crewman
            # (above his helmet only) and fades out; an empty box where it is out of sight
            "deploy_s": [(82, 38, 110, 70, [0]), (88, 36, 126, 72, [1]), (90, 36, 121, 72, [2]),
                         (122, 36, 152, 80, [3]), (112, 36, 122, 52, [3]), (110, 36, 152, 82, [4]), NONE5],
            "deploy_se": [(80, 38, 108, 76, [0]), (92, 34, 128, 70, [1]), (0, 0, 0, 0, [2]),
                          (126, 40, 153, 80, [3]), (118, 40, 126, 54, [3]), (112, 40, 153, 82, [4]), NONE5],
            "deploy_e": [(84, 38, 112, 72, [0]), (96, 36, 129, 74, [1]), (0, 0, 0, 0, [2]),
                         (128, 40, 158, 80, [3]), (118, 40, 128, 54, [3]), (112, 40, 158, 82, [4]), NONE5],
            "deploy_ne": [(76, 38, 99, 60, [0]), (88, 38, 108, 62, [1]), (0, 0, 0, 0, [2]),
                          (128, 40, 150, 82, [3]), (118, 40, 128, 58, [3]), (110, 40, 150, 82, [4]), NONE5],
            "deploy_n": [(80, 33, 106, 58, [0]), (0, 0, 0, 0, [1, 2]),
                         (128, 44, 150, 82, [3]), (118, 44, 128, 56, [3]), (110, 44, 150, 82, [4]), NONE5],
        },
        "drop": {
            "walk_se": [(76, 40, 93, 55)],
            "walk_ne": [(80, 44, 92, 62)],
            "idle_packed_e": [(68, 49, 92, 57)],
            "idle_packed_s": [(68, 46, 88, 55)],
            "idle_packed_se": [(63, 39, 85, 50)],
            "deploy_e": [(86, 60, 100, 78, [1])],     # the cart's wheel
        },
    },
}
DIRS = ["s", "se", "e", "ne", "n"]
MIN_REGION = 4          # mid-tone regions smaller than this are specks (a rivet, a glint)


def cells():
    """{unit: (cell_w, cell_h)} from scripts/art_data.gd."""
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
    return ((g == 0) & (b == 0) & ((r == 255) | (r == 150)))


def candidates(test, px):
    """(mid-tone candidates, dark candidates) for one frame (uint8 RGBA)."""
    a = px[..., 3] > 0
    rgb = px[..., :3].astype(np.float32) / 255.0
    h, s, v = hsv(rgb)
    ok = a & ~team_red(px)
    dark = ok & (v < 0.16)
    if test == "grey":
        steel = (rgb[..., 2] - rgb[..., 0] >= 9 / 255.0)
        mid = ok & (v >= 0.16) & (s < 0.30) & ~steel
    elif test == "dark_brown":
        # the Powder Wagon's near-black brown horse: dull warm darks (the wagon's wood is a
        # saturated orange-brown, its canvas a light beige)
        steel = (rgb[..., 2] - rgb[..., 0] >= 9 / 255.0)
        mid = ok & (v >= 0.13) & (v < 0.6) & (s < 0.5) & ~steel
    else:
        brown = ((h < 0.115) | (h > 0.97)) & (s >= 0.18)
        mid = ok & (v >= 0.16) & brown
    return mid, dark


def box_list(table, anim, d, fi):
    out = []
    for key in (anim + "_" + d, anim + "_*", "*_" + d, "*"):
        for b in table.get(key, []):
            if len(b) > 4 and fi not in b[4]:
                continue
            out.append(b[:4])
    return out


def box_mask(shape, boxes):
    m = np.zeros(shape, bool)
    for x0, y0, x1, y1 in boxes:
        m[max(y0, 0):max(y1, 0), max(x0, 0):max(x1, 0)] = True
    return m


def rider_head(px, pad, below):
    """Above a rider's shoulders: his coat is the topmost team-red region of 6+ pixels (with
    a raised sword arm, the arm is: so every red region starting within 12 rows of the top
    one counts). What is above each one's top (helmet, face, hand), over its width + pad,
    plus `below` rows into it."""
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
    # (bits of 2+ count too: a shoulder seen from behind is a few red pixels)
    regs = [sl for i, sl in objs if (lab[sl] == i + 1).sum() >= 2]
    for sl in regs:
        if sl[0].start <= top + 12:
            m[:max(sl[0].start + below, 0), max(sl[1].start - pad, 0):sl[1].stop + pad] = True
    return m


def frame_mask(cfg, anim, d, fi, px):
    if anim in cfg.get("alias", {}):
        anim, fi = cfg["alias"][anim]       # a strip that repeats another one's frame
    mid, dark = candidates(test_of(cfg, anim), px)
    out = np.zeros(mid.shape, bool)
    rh = cfg.get("rider_head")
    sk = rh.get("skip", []) if rh else []
    skipped = ((anim, fi) in sk or (anim + "_" + d, fi) in sk) and (anim + "_" + d, -fi - 1) not in sk
    if rh and not skipped:
        below = rh["below"]
        out |= rider_head(px, rh["pad"], below.get(d, 1) if isinstance(below, dict) else below)
    keep = box_list(cfg["keep"], anim, d, fi)
    if keep:
        out |= ~box_mask(mid.shape, keep)
    drop = box_list(cfg["drop"], anim, d, fi)
    if drop:
        out |= box_mask(mid.shape, drop)
    mid &= ~out
    lab, n = ndimage.label(mid, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(mid, lab, range(1, n + 1))
        # thin bright regions (nothing left after a 3x3 erosion) are blades and barrels
        # (the horse's own thin bits, cut up by its dark outlines, are mid-tones)
        thick = ndimage.sum(ndimage.binary_erosion(mid, structure=np.ones((3, 3))), lab, range(1, n + 1))
        v = px[..., :3].max(-1).astype(np.float32) / 255.0
        bright = ndimage.mean(v, lab, range(1, n + 1))
        good = np.zeros(n + 1, bool)
        good[1:] = (sizes >= MIN_REGION) & ((thick > 0) | (bright < cfg.get("blade_v", 2.0)))
        mid = good[lab]
    near = ndimage.binary_dilation(mid, structure=np.ones((3, 3)), iterations=2)
    return (mid | (dark & near)) & ~out


def spot_pattern(w, h, seed):
    """Blobs (~9 px) covering about 40% of a frame: the spotted coat's patches."""
    rng = np.random.default_rng(seed)
    step = 9
    gw, gh = w // step + 3, h // step + 3
    grid = rng.random((gh, gw))
    small = Image.fromarray((grid * 255).astype(np.uint8))
    big = np.asarray(small.resize((gw * step, gh * step), Image.BICUBIC)).astype(np.float32) / 255.0
    ox, oy = rng.integers(0, step), rng.integers(0, step)
    big = big[oy:oy + h, ox:ox + w]
    return big > np.quantile(big, 0.60)


def strips(unit):
    cfg = CONFIG[unit]
    for anim in cfg["anims"]:
        for d in DIRS:
            p = os.path.join(UNITS_DIR, unit, "%s_%s.png" % (anim, d))
            if os.path.exists(p):
                yield anim, d, p


def build_unit(unit, cell):
    """{key: (rgba strip, horse mask, spot mask)} for every strip of the unit."""
    cfg = CONFIG[unit]
    cw, ch = cell
    out = {}
    for anim, d, p in strips(unit):
        im = np.asarray(Image.open(p).convert("RGBA"))
        H, W = im.shape[:2]
        mask = np.zeros((H, W), bool)
        spots = np.zeros((H, W), bool)
        pat = spot_pattern(cw, H, zlib.crc32(("%s/%s" % (unit, d)).encode()))
        for fi in range(W // cw):
            fr = im[:, fi * cw:(fi + 1) * cw]
            mask[:, fi * cw:(fi + 1) * cw] = frame_mask(cfg, anim, d, fi, fr)
            spots[:, fi * cw:(fi + 1) * cw] = pat
        out["%s_%s" % (anim, d)] = (im, mask, spots)
    return out


BODY_L = 0.08     # below this a horse pixel is outline (kept as painted by the shader)


def test_of(cfg, anim):
    """The colour test for an animation's horse (a unit's strips can show two horses)."""
    return cfg.get("tests", {}).get(anim, cfg["test"])


def tone_map(data):
    """The unit's horse tones: luminance -> rank among its horse's body pixels (0..1; the
    outline darks all rank 0, so the body's shading spans the whole coat ramp)."""
    ls = np.concatenate([lum(im[..., :3].astype(np.float32) / 255.0)[m] for im, m, _ in data.values()])
    ls = np.sort(ls[ls >= BODY_L])
    def rank(l):
        return np.searchsorted(ls, l, side="right") / max(len(ls), 1)
    return rank


def sheet_ramps():
    """64-step ramps (dark -> light) of each coat's colours on the designer's sheet."""
    sh = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.float32) / 255.0
    bg = sh[20, 1480]
    ramps = {}
    for coat, boxes in SHEET_BOXES.items():
        px = np.concatenate([sh[y0:y1, x0:x1].reshape(-1, 3) for x0, y0, x1, y1 in boxes])
        h, s, v = hsv(px)
        horse = np.abs(px - bg).sum(-1) > 0.2                # not the slate background
        horse &= lum(px) >= 0.1                              # nor the outlines: the body's colours
        horse &= ~(((h < 0.045) | (h > 0.92)) & (s > 0.3))   # not the red saddle cloth (and its edge)
        if coat != "bay":
            horse &= ~(((h < 0.07) | (h > 0.9)) & (s > 0.22))   # (a reddish edge on a grey horse)
        horse &= ~((h > 0.03) & (h < 0.14) & (s > 0.55) & (v > 0.45))   # not the orange tack
        if coat == "spotted":
            horse &= lum(px) < 0.32                          # the dark patches only
        if coat == "bay":
            horse &= ~((s < 0.12) & (lum(px) > 0.25))        # not the grey saddle and bit
        px = px[horse]
        px = px[np.argsort(lum(px))]
        q = np.linspace(0, len(px), RAMP_N + 1).astype(int)
        r = np.array([px[q[i]:max(q[i + 1], q[i] + 1)].mean(0) for i in range(RAMP_N)])
        # a light blur along the ramp: no banding from single odd pixels
        k = np.array([1, 2, 3, 2, 1], np.float32); k /= k.sum()
        r = np.stack([np.convolve(np.pad(r[:, c], 2, mode="edge"), k, "valid") for c in range(3)], -1)
        ramps[coat] = r
    # The sheet's grey is barely lighter than the painted dark horse: lift it to a clear
    # dapple grey between dark and white. Patches a touch darker, so they read at game size.
    ramps["grey"] = np.clip(ramps["grey"] * 1.12 + 0.05, 0.0, 1.0)
    ramps["spotted"] = ramps["spotted"] * 0.8
    return ramps


def ramp_rows(ramps):
    """The 5 rows of coat_ramps.png: dark, bay, grey, white, spotted patch."""
    return np.stack([ramps["dark"], ramps["bay"], ramps["grey"], ramps["white"], ramps["spotted"]])


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def recolour(im, mask_rgb, rows, coat_i):
    """What shaders/team.gdshader does to a horse pixel (coat_i: row; 4 = spotted)."""
    rgb = im[..., :3].astype(np.float32) / 255.0
    m = mask_rgb[..., 0] > 127
    t = mask_rgb[..., 2].astype(np.float32) / 255.0
    sp = mask_rgb[..., 1].astype(np.float32) / 255.0
    def ramp(row):
        x = np.clip(t * (RAMP_N - 1), 0, RAMP_N - 1)
        i0 = np.floor(x).astype(int); i1 = np.minimum(i0 + 1, RAMP_N - 1); f = (x - i0)[..., None]
        return rows[row][i0] * (1 - f) + rows[row][i1] * f
    if coat_i == 4:
        col = ramp(3) * (1 - sp[..., None]) + ramp(4) * sp[..., None]
    else:
        col = ramp(coat_i)
    k = (smoothstep(0.035, 0.10, lum(rgb)) * m)[..., None]
    o = rgb * (1 - k) + col * k
    out = im.copy()
    out[..., :3] = np.clip(o * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def team_colour(im, col):
    out = im.copy()
    r = (im[..., 0] == 255) & (im[..., 1] == 0) & (im[..., 2] == 0)
    r2 = (im[..., 0] == 150) & (im[..., 1] == 0) & (im[..., 2] == 0)
    out[r, :3] = col
    out[r2, :3] = [int(c * 0.6) for c in col]
    return out


def mask_image(mask, spots, tone):
    o = np.zeros(mask.shape + (3,), np.uint8)
    o[..., 0] = mask * 255
    o[..., 1] = (spots & mask) * 255
    o[..., 2] = np.where(mask, np.clip(tone * 255 + 0.5, 0, 255), 0).astype(np.uint8)
    return o


TEAM_SHOW = [(255, 0, 0), (40, 90, 230), (240, 200, 30), (150, 60, 200), (30, 170, 160)]


def contact(path, unit, results, rows, scale=2, mode="coats"):
    """One sheet per animation: for each direction, the strip in every coat (each coat row in
    another team colour), or (mode "mask") as painted with the horse mask in magenta and
    the white and bay coats, the ones that show mistakes best."""
    from PIL import ImageDraw
    native = COATS.index(NATIVE[unit]) if NATIVE[unit] in COATS else -1
    lines = []
    for key, (im, mrgb) in results.items():
        if mode == "mask":
            dbg = im.copy()
            m = mrgb[..., 0] > 127
            dbg[m, :3] = (dbg[m, :3] * 0.35 + np.array([255, 0, 255]) * 0.65).astype(np.uint8)
            lines.append((key, "painted", im))
            lines.append((key, "mask", dbg))
            for ci in (3, 1):
                lines.append((key, COATS[ci], recolour(im, mrgb, rows, ci)))
        else:
            for ci in range(5):
                im2 = im if ci == native else recolour(im, mrgb, rows, ci)
                lines.append((key, COATS[ci], team_colour(im2, TEAM_SHOW[ci])))
    W = max(l[2].shape[1] for l in lines) * scale + 96
    Hl = sum(l[2].shape[0] * scale + 2 for l in lines) + 8 * len(results)
    sheet = Image.new("RGBA", (W, Hl), (104, 132, 84, 255))
    dr = ImageDraw.Draw(sheet)
    y = 0
    last = None
    for key, label, im in lines:
        if last is not None and key != last:
            dr.line([(0, y + 3), (W, y + 3)], fill=(40, 50, 40, 255))
            y += 8
        last = key
        ii = Image.fromarray(im)
        ii = ii.resize((ii.width * scale, ii.height * scale), Image.NEAREST)
        sheet.alpha_composite(ii, (96, y))
        dr.text((4, y + 4), key, fill=(255, 255, 255, 255))
        dr.text((4, y + 16), label, fill=(255, 255, 160, 255))
        y += ii.height + 2
    sheet.save(path)


def main():
    args = sys.argv[1:]
    contact_dir = args[args.index("--contact") + 1] if "--contact" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    cs = cells()
    ramps = sheet_ramps()
    rows = ramp_rows(ramps)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(rows * 255 + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "coat_ramps.png"))
    for unit in CONFIG:
        if only and unit != only:
            continue
        data = build_unit(unit, cs[unit])
        # one tone ranking per painted horse (per colour test): a dark horse ranked among a
        # chestnut one's pixels would come out darker than it in every coat
        cfg = CONFIG[unit]
        groups = {}
        for key, v in data.items():
            groups.setdefault(test_of(cfg, key.rsplit("_", 1)[0]), {})[key] = v
        ranks = {t: tone_map(g) for t, g in groups.items()}
        udir = os.path.join(OUT, unit)
        os.makedirs(udir, exist_ok=True)
        for f in os.listdir(udir):
            if f.endswith(".png"):
                os.remove(os.path.join(udir, f))
        results = {}
        for key, (im, mask, spots) in data.items():
            if not mask.any():
                continue
            rank = ranks[test_of(cfg, key.rsplit("_", 1)[0])]
            tone = rank(lum(im[..., :3].astype(np.float32) / 255.0))
            mrgb = mask_image(mask, spots, tone)
            Image.fromarray(mrgb).save(os.path.join(udir, key + ".png"))
            results[key] = (im, mrgb)
        print("%s: %d strips with a horse" % (unit, len(results)))
        if contact_dir:
            os.makedirs(contact_dir, exist_ok=True)
            for anim in CONFIG[unit]["anims"]:
                sub = {k: v for k, v in results.items() if k.rsplit("_", 1)[0] == anim}
                if not sub:
                    continue
                for mode in ("mask", "coats"):
                    contact(os.path.join(contact_dir, "%s_%s_%s.png" % (mode, unit, anim)), unit, sub, rows, mode=mode)


if __name__ == "__main__":
    main()
