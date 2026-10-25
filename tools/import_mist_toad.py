#!/usr/bin/env python3
"""Import the Brood's Mist Toad from art/brood/mist_toad.png (ChatGPT sheet, 5 rows).

The sheet doesn't fit import_art.py's Brood importer: it's painted on black with real
alpha (the black, and red / yellow / white smears, sit in the transparent pixels), its idle
row holds a whole idle loop per direction, and the fog row has a painted cloud over the
Toad that the game draws itself. So it gets its own pass, reusing import_art's helpers
(cut-out, box-filter shrink, team-red snapping, feet-anchored strips):

    row 0 idle   frames 0-4 face front (idle_s, a breathing loop), frame 7 is a 3/4 view
                 facing right (idle_se), frames 9-14 are back views (idle_n); idle_e is the
                 first walk frame (side on)
    row 1 walk   side on, facing right                   -> walk_e
    row 2 tongue side on; the tongue is out in ~4-8        -> tongue_e
    row 3 fog    side on; the painted fog cloud is keyed out -> fog_e
    row 4 death                                            -> death_e

Keying: alpha >= ALPHA (drops the soft halo); the fog row's cloud (light, low-chroma
pixels) is cut out and every bit left loose is dropped. Frames much smaller or bigger than
their row's median are dropped as broken. Scaled so the walk is HEIGHT px tall (a Spitter
is 34). Writes assets/units/mist_toad/*, the "mist_toad" entry of UNITS in
scripts/art_data.gd (added or replaced in place), the portrait assets/icons/mist_toad.png
and the ability icons ab_tongue (the Toad with its tongue out) and ab_fog (the miasma icon
turned grey-green). Run from the repo root: python3 tools/import_mist_toad.py
(--contact DIR writes a contact sheet of the result).
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

SHEET = "art/brood/mist_toad.png"
NAME = "mist_toad"
HEIGHT = 44
ALPHA = 150
ROWS = ["idle", "walk", "tongue", "fog", "death"]
IDLE = {"s": [0, 1, 2, 3, 4], "se": [7], "n": [9, 10, 11, 12, 13, 14]}


def foreground(px):
    return px[..., 3] >= ALPHA


def drop_cloud(px, fg, band):
    """The painted fog in the fog row: light, greyish pixels in big soft patches."""
    y0, y1 = band
    rgb = px[y0:y1, :, :3].astype(int)
    lum = rgb.mean(-1)
    chroma = rgb.max(-1) - rgb.min(-1)
    cloud = fg[y0:y1] & (lum > 92) & (chroma < 58)
    # only real patches (not a pale eye or a highlight on the skin)
    lab, n = ndimage.label(ndimage.binary_dilation(cloud, iterations=2))
    sizes = ndimage.sum(cloud, lab, range(1, n + 1))
    big = np.isin(lab, [i + 1 for i in range(n) if sizes[i] >= 60]) & cloud
    big = ndimage.binary_dilation(big, iterations=1) & (lum > 70) & (chroma < 70)
    out = fg.copy()
    out[y0:y1] &= ~big
    # loose crumbs left where the cloud was cut away
    lab2, n2 = ndimage.label(out[y0:y1])
    if n2:
        sizes2 = ndimage.sum(out[y0:y1], lab2, range(1, n2 + 1))
        keep = np.isin(lab2, [i + 1 for i in range(n2) if sizes2[i] >= 400])
        out[y0:y1] &= keep
    return out


def find_rows(fg):
    prof = fg.sum(1)
    on = prof > 20
    bands = []
    y = 0
    while y < len(on):
        if on[y]:
            s = y
            while y < len(on) and on[y]:
                y += 1
            if y - s > 40:
                bands.append((s, y))
        y += 1
    return bands


def row_frames(px, fg, band):
    y0, y1 = band
    m = np.zeros_like(fg)
    m[y0:y1] = fg[y0:y1]
    sprites = ia.components(m, 2, min_big=900, attach_dist=8)
    sprites.sort(key=lambda s: s["cx"])
    med = float(np.median([s["area"] for s in sprites]))
    good = [s for s in sprites if med * 0.45 <= s["area"] <= med * 1.8]
    if len(good) != len(sprites):
        print(f"  dropped {len(sprites) - len(good)} broken frame(s) in rows {band}")
    return [ia.cutout(px, s) for s in good]


def write_entry(cell, anchor, frames):
    path = "scripts/art_data.gd"
    src = open(path).read()
    lines = [f'\t"{NAME}": {{"cell": Vector2i({cell[0]}, {cell[1]}), "anchor": Vector2({anchor[0]}, {anchor[1]}), "frames": {{\n']
    for k in sorted(frames):
        lines.append(f'\t\t"{k}": {frames[k]},\n')
    lines.append("\t}},\n")
    entry = "".join(lines)
    pat = re.compile(r'\t"' + NAME + r'": \{.*?\n\t\}\},\n', re.S)
    if pat.search(src):
        src = pat.sub(lambda m: entry, src, count=1)
    else:
        start = src.index("const BASE_UNITS := {")
        end = src.index("\n}\n", start) + 1
        src = src[:end] + entry + src[end:]
    open(path, "w").write(src)


def make_fog_icon():
    img = Image.open(f"{ia.OUT}/icons/ab_miasma.png").convert("RGBA")
    px = np.array(img)
    inner = px[5:-5, 5:-5].astype(np.float64)
    lum = inner[..., :3] @ np.array([0.3, 0.55, 0.15])
    grey = lum[..., None] * np.array([0.78, 0.9, 0.82])[None, None, :] * 1.15
    inner[..., :3] = np.clip(inner[..., :3] * 0.15 + grey * 0.85, 0, 255)
    px[5:-5, 5:-5] = inner.astype(np.uint8)
    Image.fromarray(px).save(f"{ia.OUT}/icons/ab_fog.png")


def contact(out_dir, small):
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    for key in sorted(small):
        lst = small[key]
        h = max(im.shape[0] for im in lst)
        w = sum(im.shape[1] + 4 for im in lst)
        row = np.zeros((h + 4, w + 4, 4), np.uint8)
        row[..., :3] = (120, 140, 90)
        row[..., 3] = 255
        x = 2
        for im in lst:
            m = im[..., 3] > 0
            row[2:2 + im.shape[0], x:x + im.shape[1]][m] = im[m]
            x += im.shape[1] + 4
        rows.append(row)
    W = max(r.shape[1] for r in rows)
    H = sum(r.shape[0] for r in rows)
    sheet = np.zeros((H, W, 4), np.uint8)
    sheet[..., 3] = 255
    y = 0
    for r in rows:
        sheet[y:y + r.shape[0], :r.shape[1]] = r
        y += r.shape[0]
    Image.fromarray(sheet).resize((W * 4, H * 4), Image.NEAREST).save(f"{out_dir}/mist_toad_contact.png")


def main():
    px = ia.load(SHEET)
    fg = foreground(px)
    bands = find_rows(fg)
    if len(bands) != len(ROWS):
        sys.exit(f"{SHEET}: found {len(bands)} rows, expected {len(ROWS)}")
    fg = drop_cloud(px, fg, bands[ROWS.index("fog")])
    frames = {}
    for anim, band in zip(ROWS, bands):
        lst = row_frames(px, fg, band)
        if anim == "idle":
            for d, idx in IDLE.items():
                got = [lst[i] for i in idx if i < len(lst)]
                if got:
                    frames[(anim, d)] = got
        else:
            frames[(anim, "e")] = lst
    frames[("idle", "e")] = frames[("walk", "e")][:1]
    scale = HEIGHT / float(np.median([im.shape[0] for im in frames[("walk", "e")]]))
    small = {key: [ia.snap_team(ia.shrink(im, scale)) for im in lst] for key, lst in frames.items()}
    data = {"units": {}}
    ia.assemble(NAME, small, ROWS, data)
    u = data["units"][NAME]
    write_entry(u["cell"], u["anchor"], u["frames"])
    print("  " + ", ".join(f"{a}_{d} {len(v)}" for (a, d), v in sorted(small.items())))
    # portrait (until a painted one replaces it) and the ability icons: TONGUE from a frame
    # with the tongue out, FOG the miasma icon turned grey-green
    ia.make_icon(small[("idle", "s")][0], NAME)
    tongue = small[("tongue", "e")]
    out = max(tongue, key=lambda im: im.shape[1])      # the widest: the tongue at full stretch
    ia.make_icon(out, "ab_tongue")
    make_fog_icon()
    if "--contact" in sys.argv:
        contact(sys.argv[sys.argv.index("--contact") + 1], small)


if __name__ == "__main__":
    main()
