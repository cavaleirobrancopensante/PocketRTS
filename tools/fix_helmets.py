"""Steel helmets on the Crown's gun crews: the mortar's and the cannon's morions are drawn with
a warm, pinkish sheen on the sheets, and the importers' team-colour snap (snap_team) turns
the reddest of it - the brim's shadow, a highlight - into the exact key reds that the team
shader (shaders/team.gdshader) recolours. So on a blue team some helmets came out pink, with
blue or red flecks. This pass finds each helmet and puts it back to neutral steel grey,
keeping its shading.

A helmet is a small 4-connected patch of reddish pixels (key reds, and reds the shader would
take for a key, plus the pinkish sheen) that holds some of the pinkish sheen - a coat never
does: its reds are all snapped to the two keys - and is no bigger than MAX_AREA. Each of its
pixels becomes grey at about its own brightness (the key reds, which carry no brightness of
their own, a dark and a mid steel).

Runs on the published strips after the importers (tools/rebuild_art.sh: after
import_reload.py). Idempotent: a helmet put right holds no red any more.

Usage (from the repo root): python3 tools/fix_helmets.py [--check]
(--check only reports what it would change.)
"""
import glob
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

UNITS = ["mortar", "cannon"]
MAX_AREA = 40          # px: a morion at game scale is ~8x6
MIN_SHEEN = 3          # pinkish (non-key) pixels a helmet holds at least (and a quarter of it)
MIN_AREA = 10          # px: smaller patches are glints on a sleeve or a rammer
KEY_TOL = 0.08 * 255   # the team shader's tolerance round each key
CROWN = 5              # px: how far below the top of a figure a helmet patch may start


def classify(img):
    """key: what the team shader takes for a key red; sheen: the helmets' pinkish steel (red
    over equal green and blue - skin, wood and brass all have green well above blue);
    pale: its highlights."""
    rgb = img[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = img[..., 3] > 0
    key = a & ((np.sqrt((r - 255) ** 2 + g ** 2 + b ** 2) < KEY_TOL) |
               (np.sqrt((r - 150) ** 2 + g ** 2 + b ** 2) < KEY_TOL))
    sheen = a & ~key & (r >= 100) & (g >= r * 0.3) & (r - g >= 25) & \
        (np.abs(g - b) <= np.maximum(12, r * 0.12))
    pale = sheen & (r >= 170) & (g >= r * 0.55)
    return key, sheen, pale


def helmets(img):
    """Pixels of the reddened helmets: small 4-connected patches of key red and pinkish
    steel holding at least MIN_SHEEN of the steel and one pale highlight."""
    key, sheen, pale = classify(img)
    red = key | sheen
    lab, n = ndimage.label(red)            # 4-connected
    if not n:
        return np.zeros(red.shape, bool)
    idx = np.arange(1, n + 1)
    area = ndimage.sum(red, lab, idx)
    sh = ndimage.sum(sheen, lab, idx)
    hi = ndimage.sum(pale, lab, idx)
    kc = ndimage.sum(key, lab, idx)
    # (powder smoke and muzzle flash have the sheen's colour but no key red in them)
    ok = (area >= MIN_AREA) & (area <= MAX_AREA) & (sh >= MIN_SHEEN) & (sh >= 0.25 * area) & \
        (hi >= 1) & ((kc >= 1) | (sh >= 15))
    # and it is in the crown of a figure: over most of its columns, open air at most CROWN px
    # above its top pixel (the steel top of the helmet may be grey already; trousers,
    # sleeves and powder smoke have a whole man or cloud drawn above them)
    # and shaped like a helmet's band: 3-10 px wide, at most 8 px tall
    air = img[..., 3] == 0
    for k in np.flatnonzero(ok):
        ys, xs = np.nonzero(lab == k + 1)
        cols = np.unique(xs)
        near = 0
        for x in cols:
            y0 = ys[xs == x].min()
            if y0 < CROWN or air[y0 - CROWN:y0, x].any():
                near += 1
        ok[k] = near >= 0.8 * len(cols) and 4 <= len(cols) <= 10 and ys.max() - ys.min() < 8
    m = ok[lab - 1] & (lab > 0)
    # the rest of the same helmet's sheen, cut off from the patch by a grey pixel or two
    for _ in range(2):
        m |= ndimage.binary_dilation(m) & sheen
    # and every other red pixel of the helmet: in the rows of each patch (not below it -
    # that's the face), 2 px either side and above (a crimson brim the snap left as it was)
    rgb = img[..., :3].astype(int)
    reddish = (img[..., 3] > 0) & (rgb[..., 0] >= rgb[..., 1] + 30) & (rgb[..., 0] >= rgb[..., 2] + 30) \
        & (rgb[..., 0] >= 50)
    lab2, n2 = ndimage.label(m, structure=np.ones((3, 3)))
    out = m.copy()
    for sl in ndimage.find_objects(lab2):
        y0, y1 = max(0, sl[0].start - 2), sl[0].stop
        x0, x1 = max(0, sl[1].start - 2), sl[1].stop + 2
        out[y0:y1, x0:x1] |= reddish[y0:y1, x0:x1]
    return out


def to_steel(img, m):
    rgb = img[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.3 * r + 0.55 * g + 0.15 * b
    key_l = np.sqrt((r - 255) ** 2 + g ** 2 + b ** 2) < KEY_TOL
    key_d = np.sqrt((r - 150) ** 2 + g ** 2 + b ** 2) < KEY_TOL
    lum = np.where(key_l, 112, np.where(key_d, 70, np.maximum(lum, 40)))
    out = img.copy()
    grey = np.stack([lum - 2, lum, lum + 6], -1).clip(0, 255).astype(np.uint8)
    out[m, :3] = grey[m]
    return out


def main():
    check = "--check" in sys.argv
    total = 0
    for unit in UNITS:
        for path in sorted(glob.glob(f"assets/units/{unit}/*.png")):
            img = np.array(Image.open(path).convert("RGBA"))
            m = helmets(img)
            n = int(m.sum())
            if not n:
                continue
            total += n
            print(f"  {os.path.basename(os.path.dirname(path))}/{os.path.basename(path)}: {n} px")
            if not check:
                Image.fromarray(to_steel(img, m)).save(path)
    print(f"helmets: {total} px {'would be ' if check else ''}put back to steel")


if __name__ == "__main__":
    main()
