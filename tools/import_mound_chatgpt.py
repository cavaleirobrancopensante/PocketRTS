"""The Brood Clutch Mound with the Spore Vent's chimneys, from the owner's ChatGPT drawing
art/redraws/clutch_mound_vent_chatgpt.png (1536x1024, one building on flat navy #001630: a sac-covered
dome with two vent chimneys, red crystals and a spore plume). Replaces the plain mound (archived in
"old units obsolete for now/clutch_mound_plain/"; the Spore Vent art is in ".../spore_vent/").

BUILT: the navy is keyed out by flood fill from the border (the plume's green is far from navy), the
keyed edge eaten back 2 drawing px, then box-filtered with premultiplied alpha to the game pixel grid:
the building's bounding box is fitted to the old mound's width (74 px), so SCALE = box width / 74
(about 12.8 drawing px per game px; the picture is wide and low, so it ends up about 74x71, the same
footprint as the old 74x70; the sprite stands on its bottom edge).

The other states are derived from the built sprite in code (listed in docs/art_style_inconsistency.md):
 construction: the pale unfinished dome (the old one was a greyer, smaller, translucent mound): the
   chimneys, crystals and plume cut off by an elliptical dome mask, washed pale and shrunk to 90%.
 damaged: the built sprite with the small chimney and its plume knocked off, dark cracks across the
   dome, three burst sacs (dark torn patches) and a green ooze running down the front.
 destroyed: rubble: the dome squashed to about half height, darkened and browned, both chimneys gone
   (the big one lying toppled on the ground), sacs burst, a few bone shards.
Run (repo root): python3 tools/import_mound_chatgpt.py   then godot --headless --import
"""
import os
import random

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art/redraws/clutch_mound_vent_chatgpt.png")
OUT = os.path.join(ROOT, "assets/buildings")
OLD_W = 74
NAVY = (0, 22, 48)
ERODE = 2


def key_navy(im):
    d = np.abs(im.astype(int) - np.array(NAVY)).sum(2)
    bg = d < 40
    lab, _ = ndimage.label(bg)
    edge = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1])
    edge.discard(0)
    fg = ~np.isin(lab, list(edge))
    fg = ndimage.binary_opening(fg, iterations=1)
    return ndimage.binary_erosion(fg, iterations=ERODE)


def built():
    im = np.array(Image.open(SRC).convert("RGB"))
    fg = key_navy(im)
    ys, xs = np.nonzero(fg)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    scale = (x1 - x0) / OLD_W
    w, h = OLD_W, int(round((y1 - y0) / scale))
    box = (x0, y0, x0 + w * scale, y0 + h * scale)
    m = fg.astype(np.float32)
    cov = np.array(Image.fromarray(m).resize((w, h), Image.BOX, box=box))
    out = np.zeros((h, w, 4), np.uint8)
    ok = cov >= 0.5
    for c in range(3):
        ch = np.array(Image.fromarray(im[:, :, c].astype(np.float32) * m).resize((w, h), Image.BOX, box=box))
        out[:, :, c] = np.where(ok, np.clip(ch / np.maximum(cov, 1e-6) + 0.5, 0, 255), 0)
    out[:, :, 3] = np.where(ok, 255, 0)
    print("scale %.2f drawing px per game px, built %dx%d, drawing box x %d-%d y %d-%d" % (scale, w, h, x0, x1, y0, y1))
    return out, scale, (x0, y0)


def save(a, name):
    Image.fromarray(a).save(os.path.join(OUT, name))
    print(name, a.shape[1], "x", a.shape[0])


def fx(v, o, s):       # drawing px -> sprite px
    return (v - o) / s


def construction(b):
    h, w = b.shape[:2]
    a = b.copy()
    yy, xx = np.mgrid[0:h, 0:w]
    ground = int(h * 0.80)
    cx, rx, ry = w / 2.0, w * 0.46, ground - h * 0.36
    inside = ((xx - cx) / rx) ** 2 + ((yy - ground) / ry) ** 2 <= 1.0
    a[(yy < ground) & ~inside, 3] = 0
    rgb = a[:, :, :3].astype(float)
    grey = rgb.mean(2, keepdims=True)
    rgb = rgb * 0.45 + grey * 0.55
    rgb = rgb * 0.8 + np.array([205, 215, 150]) * 0.2
    a[:, :, :3] = np.clip(rgb, 0, 255)
    im = Image.fromarray(a)
    nw, nh = int(w * 0.9), int(h * 0.9)
    small = im.resize((nw, nh), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(small, ((w - nw) // 2, h - nh))
    return np.array(out)


def crack(a, rng, x, y, n, dx):
    h, w = a.shape[:2]
    for _ in range(n):
        if 0 <= x < w and 0 <= y < h and a[int(y), int(x), 3]:
            a[int(y), int(x), :3] = (28, 32, 10)
        y += 1
        x += dx + rng.choice([-1, 0, 0, 1])


def patch(a, rng, cx, cy, r):
    h, w = a.shape[:2]
    for y in range(max(0, cy - r), min(h, cy + r + 1)):
        for x in range(max(0, cx - r), min(w, cx + r + 1)):
            if a[y, x, 3] and (x - cx) ** 2 + (y - cy) ** 2 <= r * r + rng.uniform(-r, r):
                a[y, x, :3] = rng.choice([(48, 56, 18), (60, 66, 22), (36, 42, 14)])


def damaged(b, scale, org):
    a = b.copy()
    h, w = a.shape[:2]
    rng = random.Random("mound-damaged")
    # the small chimney and its plume knocked off (drawing px x 805-1000, y 255-425)
    for y in range(int(fx(255, org[1], scale)), int(fx(425, org[1], scale))):
        for x in range(int(fx(805, org[0], scale)), min(w, int(fx(1000, org[0], scale)))):
            if 0 <= y < h and 0 <= x < w:
                a[y, x, 3] = 0
    for cxy in [(0.30, 0.78), (0.62, 0.70), (0.80, 0.82)]:
        patch(a, rng, int(w * cxy[0]), int(h * cxy[1]), 4)
    crack(a, rng, w * 0.40, h * 0.50, 22, 0)
    crack(a, rng, w * 0.58, h * 0.55, 18, 1)
    crack(a, rng, w * 0.25, h * 0.62, 12, -1)
    x = int(w * 0.47)
    for y in range(int(h * 0.62), int(h * 0.90)):       # a thin ooze down the front, wobbling
        x += rng.choice([-1, 0, 0, 0, 1])
        if a[y, x, 3]:
            a[y, x, :3] = (150, 220, 60)
    for k in (-1, 0, 1):
        if a[int(h * 0.90), x + k, 3]:
            a[int(h * 0.90), x + k, :3] = (110, 180, 40)
    return a


def destroyed(b, scale, org):
    h, w = b.shape[:2]
    rng = random.Random("mound-destroyed")
    # keep the dome and the ground (below the crystals), squashed to about half height
    top = int(h * 0.40)
    body = Image.fromarray(b[top:])
    nh = int((h - top) * 0.62)
    body = body.resize((w, nh), Image.NEAREST)
    a = np.array(body)
    rgb = a[:, :, :3].astype(float)
    rgb = rgb * 0.62 + np.array([95, 70, 40]) * 0.38
    a[:, :, :3] = np.clip(rgb, 0, 255)
    nh2 = a.shape[0]
    for cxy in [(0.25, 0.55), (0.45, 0.45), (0.62, 0.60), (0.78, 0.50), (0.36, 0.72)]:
        patch(a, rng, int(w * cxy[0]), int(nh2 * cxy[1]), 4)
    # the big chimney lying toppled (drawing px x 600-790, y 230-420)
    ch = b[int(fx(230, org[1], scale)):int(fx(420, org[1], scale)), int(fx(600, org[0], scale)):int(fx(790, org[0], scale))]
    cim = Image.fromarray(ch).rotate(78, expand=True, resample=Image.NEAREST)
    out = Image.new("RGBA", (w, nh2 + 4), (0, 0, 0, 0))
    out.paste(Image.fromarray(a), (0, 4))
    out.alpha_composite(cim, (int(w * 0.30), max(0, nh2 - cim.height - 2)))
    o = np.array(out)
    for _ in range(9):                                    # bone shards
        x, y = rng.randrange(6, w - 6), rng.randrange(nh2 // 2, nh2)
        for k in range(rng.randint(2, 4)):
            if 0 <= x + k < w and 0 <= y < o.shape[0] and o[y, x + k, 3]:
                o[y, x + k, :3] = (205, 190, 150)
    return o


if __name__ == "__main__":
    b, scale, org = built()
    save(b, "clutch_mound_built.png")
    save(construction(b), "clutch_mound_construction.png")
    save(damaged(b, scale, org), "clutch_mound_damaged.png")
    save(destroyed(b, scale, org), "clutch_mound_destroyed.png")
