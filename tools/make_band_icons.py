#!/usr/bin/env python3
"""The MARCHING BAND's stand-in icons (scripts/marching_band.gd), drawn in code until ChatGPT paints real ones
(logged in docs/art_style_inconsistency.md): the band's portrait (assets/icons/band.png) and its three instruments'
buttons (assets/icons/ab_band_drums.png, ab_band_pipes.png, ab_band_fife.png), 64x64 like the others.
Run: python3 tools/make_band_icons.py"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "icons")
S = 4                      # drawn 4x, then shrunk (smooth edges)
N = 64 * S


def base(top, bottom):
    im = Image.new("RGBA", (N, N))
    d = ImageDraw.Draw(im)
    for y in range(N):
        f = y / (N - 1)
        c = tuple(int(top[i] * (1 - f) + bottom[i] * f) for i in range(3)) + (255,)
        d.line([(0, y), (N, y)], fill=c)
    return im, d


def frame(im):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, N - 1, N - 1], outline=(20, 14, 8, 255), width=3 * S)
    d.rectangle([3 * S, 3 * S, N - 1 - 3 * S, N - 1 - 3 * S], outline=(120, 92, 48, 255), width=S)
    return im


def drum(d, cx, cy, w, h):
    # a side drum: red shell, white heads, gold cords
    d.ellipse([cx - w, cy + h - w * 0.35, cx + w, cy + h + w * 0.35], fill=(120, 20, 18), outline=(30, 10, 5), width=S)
    d.rectangle([cx - w, cy - h, cx + w, cy + h], fill=(178, 30, 26), outline=(30, 10, 5), width=S)
    n = 4
    for i in range(n):
        x0 = cx - w + 2 * w * i / n
        x1 = cx - w + 2 * w * (i + 1) / n
        d.line([(x0, cy - h + 2 * S), (x1, cy + h - 2 * S)], fill=(232, 200, 110), width=2 * S)
        d.line([(x0, cy + h - 2 * S), (x1, cy - h + 2 * S)], fill=(232, 200, 110), width=2 * S)
    d.ellipse([cx - w, cy - h - w * 0.35, cx + w, cy - h + w * 0.35], fill=(238, 232, 214), outline=(30, 10, 5), width=S)


def sticks(d, cx, cy):
    d.line([(cx - 14 * S, cy - 18 * S), (cx - 2 * S, cy - 4 * S)], fill=(92, 58, 26), width=3 * S)
    d.line([(cx + 16 * S, cy - 16 * S), (cx + 3 * S, cy - 5 * S)], fill=(92, 58, 26), width=3 * S)
    for x, y in [(cx - 14 * S, cy - 18 * S), (cx + 16 * S, cy - 16 * S)]:
        d.ellipse([x - 2 * S, y - 2 * S, x + 2 * S, y + 2 * S], fill=(150, 110, 60))


def fife(d, x0, y0, x1, y1, width=3):
    d.line([(x0, y0), (x1, y1)], fill=(214, 186, 128), width=width * S)
    d.line([(x0, y0), (x1, y1)], fill=(120, 90, 50), width=max(1, width - 2) * S)
    d.line([(x0, y0), (x1, y1)], fill=(214, 186, 128), width=max(1, width - 1) * S)
    for k in range(6):
        f = 0.3 + 0.1 * k
        x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
        d.ellipse([x - S, y - S, x + S, y + S], fill=(40, 25, 10))
    for f in (0.02, 0.98):
        x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
        d.ellipse([x - 2 * S, y - 2 * S, x + 2 * S, y + 2 * S], fill=(200, 160, 60))


def pipes(d, cx, cy):
    # the bag (tartan-ish green), three drones up and to the right, the chanter down
    d.ellipse([cx - 16 * S, cy - 8 * S, cx + 12 * S, cy + 14 * S], fill=(36, 92, 52), outline=(12, 30, 16), width=S)
    for i in range(3):
        d.line([(cx - 14 * S + i * 9 * S, cy - 6 * S), (cx - 14 * S + i * 9 * S, cy + 12 * S)], fill=(150, 40, 36), width=S)
        d.line([(cx - 15 * S, cy - 2 * S + i * 6 * S), (cx + 11 * S, cy - 2 * S + i * 6 * S)], fill=(20, 50, 30), width=S)
    for i, (dx, ln) in enumerate([(-2, 24), (4, 20), (10, 16)]):
        x0, y0 = cx + dx * S, cy - 6 * S
        x1, y1 = x0 + ln * 0.35 * S, y0 - ln * S
        d.line([(x0, y0), (x1, y1)], fill=(60, 36, 18), width=3 * S)
        d.ellipse([x1 - 2.5 * S, y1 - 2 * S, x1 + 2.5 * S, y1 + 2 * S], fill=(225, 220, 200))
        d.line([(x0 + S, (y0 + y1) / 2), (x1 - S, (y0 + y1) / 2 - 2 * S)], fill=(200, 40, 40), width=S)
    d.line([(cx - 8 * S, cy + 10 * S), (cx - 14 * S, cy + 24 * S)], fill=(60, 36, 18), width=3 * S)
    d.line([(cx - 4 * S, cy - 6 * S), (cx - 20 * S, cy - 16 * S)], fill=(60, 36, 18), width=2 * S)


def note(d, x, y, col):
    d.ellipse([x - 3 * S, y - 2 * S, x + 3 * S, y + 2 * S], fill=col)
    d.line([(x + 2.5 * S, y), (x + 2.5 * S, y - 10 * S)], fill=col, width=S)
    d.line([(x + 2.5 * S, y - 10 * S), (x + 6 * S, y - 7 * S)], fill=col, width=S)


def save(im, name):
    frame(im)
    im.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def main():
    im, d = base((70, 40, 30), (24, 14, 10))
    drum(d, 32 * S, 36 * S, 15 * S, 9 * S)
    sticks(d, 32 * S, 26 * S)
    note(d, 50 * S, 16 * S, (250, 220, 120, 255))
    save(im, "ab_band_drums")

    im, d = base((40, 66, 44), (14, 24, 16))
    pipes(d, 34 * S, 34 * S)
    note(d, 50 * S, 46 * S, (250, 220, 120, 255))
    save(im, "ab_band_pipes")

    im, d = base((40, 52, 80), (14, 18, 30))
    fife(d, 10 * S, 46 * S, 54 * S, 18 * S, 4)
    note(d, 18 * S, 22 * S, (250, 220, 120, 255))
    note(d, 44 * S, 48 * S, (250, 220, 120, 255))
    save(im, "ab_band_fife")

    # the band's portrait: the drum in front, the fife crossed behind, the pipes' drones peeping over
    im, d = base((90, 70, 40), (26, 18, 10))
    for i, (dx, ln) in enumerate([(-14, 22), (-8, 26), (-2, 20)]):
        x0, y0 = 32 * S + dx * S, 30 * S
        d.line([(x0, y0), (x0 + 6 * S, y0 - ln * S)], fill=(60, 36, 18), width=3 * S)
        d.ellipse([x0 + 6 * S - 2.5 * S, y0 - ln * S - 2 * S, x0 + 6 * S + 2.5 * S, y0 - ln * S + 2 * S], fill=(225, 220, 200))
    fife(d, 12 * S, 22 * S, 56 * S, 34 * S, 3)
    drum(d, 32 * S, 42 * S, 14 * S, 8 * S)
    note(d, 52 * S, 14 * S, (250, 220, 120, 255))
    save(im, "band")


if __name__ == "__main__":
    main()
