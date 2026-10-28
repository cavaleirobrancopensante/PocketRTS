#!/usr/bin/env python3
"""The Mound Turtle's import check (the owner, 2026-10-28: three of its sheets and the portrait came as JPEG screenshots).

Writes docs/shots/brood_new/turtle_quality.png: the first walk frame of every direction (S, SE, E, NE, N) and the card
portrait, as the game draws them (1x) and blown up 4x (nearest), on the ground colour, the south-east (a clean PNG
sheet) first; and prints per direction the body's size and three numbers to compare with the south-east:
  area   opaque pixels of the frame (body size),
  sharp  mean |Laplacian| of the brightness inside the body (blur lowers it, JPEG noise raises it),
  fringe share of the outline pixels that are dark navy (a halo left by the key).
python3 -I tools/turtle_quality.py [OUT.png]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
U = f"{ROOT}/assets/units/mound_turtle"
GROUND = (86, 104, 62)
CELL = (94, 65)


def frame(d):
    im = np.array(Image.open(f"{U}/walk_{d}.png").convert("RGBA"))
    return im[:, :CELL[0]]


def stats(im):
    a = im[..., 3] > 0
    ys, xs = np.nonzero(a)
    lum = im[..., :3].astype(float).mean(-1)
    inner = ndimage.binary_erosion(a, iterations=2)
    lap = np.abs(ndimage.laplace(lum))[inner].mean()
    edge = a & ~ndimage.binary_erosion(a)
    rgb = im[..., :3].astype(int)
    dark = (rgb.max(-1) < 55) & (rgb[..., 2] >= rgb[..., 0])
    return {"w": xs.max() - xs.min() + 1, "h": ys.max() - ys.min() + 1, "area": int(a.sum()),
            "sharp": lap, "fringe": float((edge & dark).sum()) / max(1, edge.sum())}


def on_ground(im):
    bg = Image.new("RGBA", (im.shape[1], im.shape[0]), GROUND + (255,))
    bg.alpha_composite(Image.fromarray(im))
    return bg


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else f"{ROOT}/docs/shots/brood_new/turtle_quality.png"
    dirs = ["se", "s", "e", "ne", "n"]
    frames = {d: frame(d) for d in dirs}
    port = Image.open(f"{ROOT}/assets/icons/mound_turtle.png").convert("RGBA")
    Z = 4
    pad = 12
    W = pad + len(dirs) * (CELL[0] * Z + pad) + 64 * Z + pad
    H = 30 + CELL[1] + pad + CELL[1] * Z + 40
    sheet = Image.new("RGBA", (W, H), (40, 44, 40, 255))
    dr = ImageDraw.Draw(sheet)
    x = pad
    print("dir   w   h  area  sharp  fringe")
    for d in dirs:
        s = stats(frames[d])
        print(f"{d:>3} {s['w']:3d} {s['h']:3d} {s['area']:5d} {s['sharp']:6.1f} {s['fringe']:6.2f}")
        g = on_ground(frames[d])
        dr.text((x, 6), d.upper() + (" (PNG)" if d in ("se", "e") else " (JPEG)"), fill=(240, 240, 220, 255))
        sheet.paste(g, (x, 24))
        sheet.paste(g.resize((CELL[0] * Z, CELL[1] * Z), Image.NEAREST), (x, 24 + CELL[1] + pad))
        dr.text((x, H - 30), f"{s['w']}x{s['h']} px, area {s['area']}", fill=(220, 220, 200, 255))
        x += CELL[0] * Z + pad
    dr.text((x, 6), "PORTRAIT (JPEG)", fill=(240, 240, 220, 255))
    sheet.paste(port, (x, 24))
    sheet.paste(port.resize((64 * Z, 64 * Z), Image.NEAREST), (x, 24 + CELL[1] + pad))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.convert("RGB").save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
