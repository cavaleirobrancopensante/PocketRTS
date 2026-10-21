"""The Winder's self-building crate (Clockwork): the crate he fetches from a Clocktower,
carries to a new site on his back and drops; there it unfolds into the building frame.

Source: art/clockwork/crate_unfold.png (2172x724 RGB), six frames in a row on a painted
(fake) transparency checkerboard:
  0 the closed crate (amber lamp, crank)   1 lid open, steam
  2-3 sides folding flat, arms unfolding   4 iron foundation plates with arms
  5 a frame with a hanging beam

The checkerboard is keyed out with import_art's checker_mask (flood fill of the light,
colourless background from the border, plus the trapped pockets and specks), the six
frames are its six big pieces (small bits such as steam go to the nearest one), shrunk
with import_art's box filter, red corner caps snapped to the team key reds.

Output (game pixels):
  assets/effects/crate_unfold_<kind>.png  one 6-frame strip for each Clockwork building
      (found in scripts/defs.gd: a BUILDINGS entry with "faction": "clockwork"): frame 4's
      foundation plates are as wide as that building's construction sprite
      (assets/buildings/<kind>_construction.png: a Boiler's is 126 px), so the frame
      cross-fades into it at the same size; every frame on one canvas, centred, feet on the
      bottom row (drawn like a building: bottom 6 px below the footprint's bottom edge).
      Frame size and the closed crate's width go into scripts/art_data.gd CRATE.
  assets/effects/crate_carried.png     frame 0, small enough to sit on a Winder's back
  assets/effects/crate_ground.png      frame 0, a little bigger: the crate on the ground

Usage (from the repo root): python3 tools/import_crate.py [--contact DIR]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
from import_cannon2 import clean  # noqa: E402

SRC = "art/clockwork/crate_unfold.png"
OUT = "assets/effects"
FOUND_FILL = 0.98             # frame 4's plates against the construction sprite's width
TALL = 1.35                   # frame 5 (the gantry) taller than this x the construction sprite:
                              # that building cross-fades from frame 4 (the plates) instead
CARRIED_W = 15                 # the crate on a Winder's back (he is ~16 px wide)
GROUND_W = 18                  # the crate lying on the ground
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None


def frames():
    px = ia.load(SRC)
    fg = ia.checker_mask(px)
    # leftover specks of checker: tiny islands of near-white, colourless pixels
    rgb = px[..., :3]
    pale = (rgb.min(-1) >= 200) & ((rgb.max(-1) - rgb.min(-1)) <= 14)
    lab, n = ndimage.label(fg)
    if n:
        size = ndimage.sum(fg, lab, np.arange(1, n + 1))
        paleness = ndimage.mean(pale, lab, np.arange(1, n + 1))
        drop = (size < 40) | ((size < 400) & (paleness > 0.8))
        fg &= ~(drop[lab - 1] & (lab > 0))
    sprites = ia.components(fg, 4, min_big=2000, attach_dist=40)
    sprites.sort(key=lambda s: s["cx"])
    assert len(sprites) == 6, [(s["x0"], s["area"]) for s in sprites]
    out = []
    for s in sprites:
        img = ia.cutout(px, s)
        # the fringe of the checker on the outline: pale colourless pixels at the edge
        a = img[..., 3] > 0
        rim = a & ~ndimage.binary_erosion(a, iterations=2)
        c = img[..., :3]
        light = (c.min(-1) >= 205) & ((c.max(-1) - c.min(-1)) <= 12)
        img[rim & light, 3] = 0
        out.append(img)
    # frame 1's painted steam keys out hollow (its white is the checker's white): take it
    # off, the game puffs its own steam out of the open lid
    st = out[1]
    c = st[..., :3]
    steam = (st[..., 3] > 0) & ((c.max(-1) - c.min(-1)) <= 22) & (c.mean(-1) >= 120)
    st[ndimage.binary_dilation(steam, iterations=2) & ((c.max(-1) - c.min(-1)) <= 30) & (c.mean(-1) >= 90), 3] = 0
    a = st[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n > 1:
        size = ndimage.sum(a, lab, np.arange(1, n + 1))
        st[(size < size.max() * 0.02)[lab - 1] & (lab > 0), 3] = 0
    return out


def body_width(img):
    """Width of the crate's body (frame 0 without the crank: the columns that are
    at least a third as tall as the tallest one)."""
    cols = (img[..., 3] > 0).sum(0)
    xs = np.flatnonzero(cols >= cols.max() / 3)
    return xs[-1] - xs[0] + 1


def game(img, scale):
    sm = ia.shrink(img, scale)
    return clean(ia.snap_team(sm))


def canvas(imgs):
    """Every frame on one canvas: centred on its bounding box, feet on the bottom row."""
    w = max(i.shape[1] for i in imgs) + 2
    h = max(i.shape[0] for i in imgs) + 1
    w += w % 2
    strip = np.zeros((h, w * len(imgs), 4), np.uint8)
    for k, im in enumerate(imgs):
        x = k * w + (w - im.shape[1]) // 2
        y = h - 1 - im.shape[0]
        region = strip[y:y + im.shape[0], x:x + im.shape[1]]
        m = im[..., 3] > 0
        region[m] = im[m]
    return strip, (w, h)


def clockwork_buildings():
    """Every Clockwork building in scripts/defs.gd (BUILDINGS entries: they have a size)."""
    kinds, key, block = [], None, []
    for line in open("scripts/defs.gd"):
        m = re.match(r'^\t"(\w+)": \{', line)
        if m:
            key, block = m.group(1), []
        if key:
            block.append(line)
            if '"faction": "clockwork"' in line and any('"size": Vector2i' in b for b in block):
                if key not in kinds:
                    kinds.append(key)
    return [k for k in kinds if os.path.exists(f"assets/buildings/{k}_construction.png")]


def update_art_data(sizes):
    path = "scripts/art_data.gd"
    src = open(path).read()
    body = ", ".join('"%s": [%d, %d, %.1f, %d]' % (k, w, h, cw, last) for k, (w, h, cw, last) in sorted(sizes.items()))
    block = ("## The Winder's crate unfolding into a building frame (tools/import_crate.py - edit there,\n"
             "## not here): building kind -> [frame width, frame height, width of the closed crate in\n"
             "## frame 0, the frame held and cross-faded into the construction sprite (5, the gantry; 4,\n"
             "## the plates, where the gantry would tower over a low building)] of\n"
             "## assets/effects/crate_unfold_<kind>.png (6 frames in a row, centred,\n"
             "## feet on the bottom row). CRATE_GROUND: the crate's width in crate_ground.png.\n"
             "const CRATE := {%s}\nconst CRATE_GROUND := %d\n" % (body, GROUND_W))
    pat = re.compile(r"## The Winder's crate unfolding.*?\nconst CRATE := \{[^\n]*\}\n(const CRATE_GROUND := \d+\n)?", re.S)
    if pat.search(src):
        src = pat.sub(block.replace("\\", "\\\\"), src)
    else:
        src = src.rstrip("\n") + "\n\n" + block
    open(path, "w").write(src)


def main():
    fr = frames()
    found_w = fr[4].shape[1]
    bw = body_width(fr[0])
    sizes = {}
    for k in clockwork_buildings():
        con = Image.open(f"assets/buildings/{k}_construction.png")
        scale = con.width * FOUND_FILL / found_w
        imgs = [game(f, scale) for f in fr]
        last = 5 if imgs[5].shape[0] <= con.height * TALL else 4
        strip, size = canvas(imgs)
        ia.save(strip, f"{OUT}/crate_unfold_{k}.png")
        sizes[k] = (size[0], size[1], bw * scale, last)
        print(f"  crate_unfold_{k}: frame {size}, scale {scale:.3f} (construction sprite {con.width}x{con.height}), "
              f"fades from frame {last}")
    for name, w in (("crate_carried", CARRIED_W), ("crate_ground", GROUND_W)):
        sm = game(fr[0], w / bw)
        ia.save(sm, f"{OUT}/{name}.png")
        print(f"  {name}: {sm.shape[1]}x{sm.shape[0]}")
    update_art_data(sizes)
    if CONTACT:
        os.makedirs(CONTACT, exist_ok=True)
        for n in sizes:
            im = Image.open(f"{OUT}/crate_unfold_{n}.png")
            for bg, tag in (((60, 90, 60, 255), "grass"), ((255, 0, 255, 255), "magenta")):
                c = Image.new("RGBA", im.size, bg)
                c.alpha_composite(im)
                c.resize((im.width * 3, im.height * 3), Image.NEAREST).save(f"{CONTACT}/unfold_{n}_{tag}.png")
        for name in ("crate_carried", "crate_ground"):
            im = Image.open(f"{OUT}/{name}.png")
            c = Image.new("RGBA", im.size, (255, 0, 255, 255))
            c.alpha_composite(im)
            c.resize((im.width * 8, im.height * 8), Image.NEAREST).save(f"{CONTACT}/{name}.png")


if __name__ == "__main__":
    main()
