"""Shared helpers for the importers of the image-AI redraw sheets in art/redraws/ (the
import_redraw_*.py scripts). The sheets are dark navy (0, 22, 48) with a title, column numbers
and row labels, and their figures are drawn two to three times larger than the game's cells:

  load_sheet()      the sheet's pixels and foreground mask (navy keyed out)
  runs()            [start, end) runs of a 1-D mask (rows or columns of figures)
  cut()             one figure out of a box of the sheet as RGBA at sheet size (backdrop keyed
                    out, edge pixels still tinted navy removed, specks and neighbours' bits dropped)
  to_cell()         shrink a figure to the game's pixel size (box filter, hard alpha, the team
                    reds snapped to the key reds) and put it on a cell: horizontally centred on a
                    given column (the middle of the red coat, not the musket) and its feet on the
                    cell's ground line
  contact()         a magnified contact sheet of strips (for looking at them)
  write_counts()    set the frame counts of an art in scripts/art_data.gd

Usage: imported by tools/import_redraw_*.py (run from the repo root).
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import clean, defringe  # noqa: E402

BG = np.array([0, 22, 48])
ART_DATA = "scripts/art_data.gd"
DIRS5 = ["s", "se", "e", "ne", "n"]


def runs(mask1d, gap=2, minw=1):
    out, s, g, e = [], None, 0, 0
    for i, v in enumerate(mask1d):
        if v:
            if s is None:
                s = i
            g = 0
            e = i + 1
        elif s is not None:
            g += 1
            if g >= gap:
                out.append((s, e))
                s = None
    if s is not None:
        out.append((s, e))
    return [r for r in out if r[1] - r[0] >= minw]


def load_sheet(name):
    px = np.asarray(Image.open("art/redraws/%s.png" % name).convert("RGB")).astype(int)
    fg = np.abs(px - BG).max(-1) > 24
    return px, fg


def cut(px, fg, box, keep_frac=0.04, closing=True):
    """The figure in box (x0, y0, x1, y1) of the sheet as RGBA (cropped to the box)."""
    x0, y0, x1, y1 = box
    m = fg[y0:y1, x0:x1].copy()
    if closing:
        m = ndimage.binary_closing(m, iterations=1) | m
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = (sizes >= keep_frac * sizes.max())[lab - 1] & (lab > 0)
    img = np.zeros(m.shape + (4,), np.uint8)
    img[..., :3] = px[y0:y1, x0:x1]
    img[..., 3] = np.where(m, 255, 0)
    return defringe(img, BG.astype(float))


def shrink(img, scale, keep=0.35):
    """Box-filter downscale with premultiplied alpha, then hard alpha from `keep` coverage."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= keep, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def is_red(rgb, a):
    return a & (rgb[..., 0] > 120) & (rgb[..., 1] < 70) & (rgb[..., 2] < 70)


def to_cell(img, scale, cell, anchor, cx=None, ground=None, dx=0, dy=0, keep=0.35, tidy=True):
    """img (RGBA at sheet size) shrunk by `scale` onto a (w, h) cell: its column `cx` (sheet px
    of img; default the middle of its red coat, else of its bounding box) on anchor x, its bottom
    row (or `ground`, a sheet row of img) on anchor y - 1."""
    a = img[..., 3] > 0
    ys, xs = np.nonzero(a)
    if len(xs) == 0:
        return np.zeros((cell[1], cell[0], 4), np.uint8)
    if cx is None:
        red = is_red(img[..., :3].astype(int), a)
        cx = float(np.median(np.nonzero(red)[1])) if red.sum() > 8 else (xs.min() + xs.max()) / 2.0
    if ground is None:
        ground = ys.max()
    small = shrink(img, scale, keep)
    if tidy:
        small = snap_team(clean(small))
    out = np.zeros((cell[1], cell[0], 4), np.uint8)
    x = int(round(anchor[0] - cx * scale)) + dx
    y = int(round(anchor[1] - 1 - ground * scale)) + dy
    h, w = small.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww, hh = min(w - sx0, cell[0] - dx0), min(h - sy0, cell[1] - dy0)
    if ww > 0 and hh > 0:
        part = small[sy0:sy0 + hh, sx0:sx0 + ww]
        m = part[..., 3] > 0
        out[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
    return out


def contact(path, strips, cell_w, scale=4, crop=None):
    """strips: [(label, [cells...])]: a magnified contact sheet on game green."""
    rows = []
    for _label, cells in strips:
        im = Image.fromarray(np.concatenate(cells, 1)) if cells else Image.new("RGBA", (cell_w, 8))
        rows.append(im)
    W = max(r.width for r in rows)
    H = sum(r.height + 2 for r in rows)
    sheet = Image.new("RGBA", (W * scale, H * scale), (104, 132, 84, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r.resize((r.width * scale, r.height * scale), Image.NEAREST), (0, y * scale))
        y += r.height + 2
    sheet.save(path)


def write_counts(art, counts, cell=None, anchor=None):
    """Set the frame counts of `art` in scripts/art_data.gd (keys in `counts` added or replaced)."""
    src = open(ART_DATA).read()
    m = re.search(r'\t"%s": \{"cell".*?\n\t\}\},\n' % art, src, re.S)
    assert m, art
    block = m.group(0)
    for k, v in counts.items():
        if re.search(r'"%s": \d+,' % k, block):
            block = re.sub(r'"%s": \d+,' % k, '"%s": %d,' % (k, v), block)
        else:
            block = block.replace('"frames": {\n', '"frames": {\n\t\t"%s": %d,\n' % (k, v), 1)
    open(ART_DATA, "w").write(src[:m.start()] + block + src[m.end():])


def col_boxes(fg, y0, y1, xspan, n):
    """n column boxes (x0, x1) over xspan = (a, b): the figures' columns in the band y0..y1 (their
    centres, boxes meeting halfway); a band whose gaps don't give n runs falls back to equal slices."""
    a, b = xspan
    cs = runs(fg[y0:y1, a:b].sum(0) > 0, 3, 6)
    if len(cs) == n:
        mid = [(r[0] + r[1]) / 2.0 + a for r in cs]
    else:
        w = (b - a) / float(n)
        mid = [a + w * (i + 0.5) for i in range(n)]
    edges = [mid[0] - (mid[1] - mid[0]) / 2.0] + [(mid[i] + mid[i + 1]) / 2.0 for i in range(n - 1)]
    edges.append(mid[-1] + (mid[-1] - mid[-2]) / 2.0)
    return [(int(round(max(a - 8, edges[i]))), int(round(edges[i + 1]))) for i in range(n)]


def save_strip(art, anim, d, cells):
    os.makedirs("assets/units/%s" % art, exist_ok=True)
    Image.fromarray(np.concatenate(cells, 1)).save("assets/units/%s/%s_%s.png" % (art, anim, d))
