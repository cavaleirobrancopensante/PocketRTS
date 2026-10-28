#!/usr/bin/env python3
"""The STATS ROW's icons (scripts/ui/unit_stats.gd, docs/unit_stats.md): cut the owner's ChatGPT sheet
art/redraws/stat_icons_chatgpt.png, 14 square icons on a dark background, into assets/ui/stats/<name>.png.

Names, in reading order (row by row, left to right), the order the sheet was asked for:
  melee, ranged, area, range, attack_speed, armour, health, speed, sight, vs_armoured, vs_buildings, hits_air,
  supply, no_attack

Robust to the spacing and the grid (2 rows of 7, 4 + 4 + 4 + 2, one long row...): the background colour is taken
from the sheet's border, everything that differs from it is a picture; nearby pieces of one picture (a gap inside an
icon, a frame and what is in it) are joined; pieces too small to be an icon are dropped; if there are still more than
14, the smallest are joined to their nearest neighbour. Each icon is cut with a small margin, made square on the
background, scaled to 64 x 64, and its dark background made transparent (soft edge). The game picks the files up
by themselves (UnitStats.texture: the drawn placeholder is used while a file is missing).

Usage (from the repo root):
  python3 tools/import_stat_icons.py [SHEET] [--contact FILE] [--keep-bg]
  python3 tools/import_stat_icons.py --selftest     (cuts a made-up sheet with uneven spacing into a temp folder)
Then: godot --headless --import."""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

NAMES = ["melee", "ranged", "area", "range", "attack_speed", "armour", "health", "speed", "sight",
         "vs_armoured", "vs_buildings", "hits_air", "supply", "no_attack"]
SHEET = "art/redraws/stat_icons_chatgpt.png"
OUT = "assets/ui/stats"
SIZE = 64


def background(px):
    """The sheet's ground: the median of its border pixels."""
    b = max(2, min(px.shape[:2]) // 100)
    edge = np.concatenate([px[:b].reshape(-1, 3), px[-b:].reshape(-1, 3), px[:, :b].reshape(-1, 3),
                           px[:, -b:].reshape(-1, 3)])
    return np.median(edge, 0)


def distance(px, bg):
    return np.abs(px - bg).max(-1)


def label(mask):
    """4-connected components of a small boolean grid: a list of [y0, y1, x0, x1] (inclusive-exclusive)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    boxes = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            y0, y1, x0, x1 = y, y, x, x
            while stack:
                cy, cx = stack.pop()
                y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            boxes.append([y0, y1 + 1, x0, x1 + 1])
    return boxes


def near(a, b, pad):
    return not (a[1] + pad < b[0] or b[1] + pad < a[0] or a[3] + pad < b[2] or b[3] + pad < a[2])


def join(a, b):
    return [min(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), max(a[3], b[3])]


def area(b):
    return (b[1] - b[0]) * (b[3] - b[2])


def find_icons(px, n=len(NAMES)):
    """The n icons' boxes on the sheet (full-size pixels), in reading order."""
    H, W = px.shape[:2]
    bg = background(px)
    mask = distance(px, bg) > 48
    # a coarse grid (about 300 cells wide): a cell is on if any pixel in it is, then grown by one cell
    f = max(1, W // 300)
    hh, ww = H // f, W // f
    small = mask[:hh * f, :ww * f].reshape(hh, f, ww, f).any(axis=(1, 3))
    grown = small.copy()
    grown[1:] |= small[:-1]
    grown[:-1] |= small[1:]
    grown[:, 1:] |= small[:, :-1]
    grown[:, :-1] |= small[:, 1:]
    boxes = [[b[0] * f, b[1] * f, b[2] * f, b[3] * f] for b in label(grown)]
    pieces = [b for b in boxes if area(b) >= H * W * 0.0008]            # (specks, stray marks)
    # pieces of one picture: join boxes closer than 1.5% of the sheet's width (icons packed tighter than that: less)
    for share in (0.015, 0.006, 0.0):
        boxes = [list(b) for b in pieces]
        pad = W * share
        changed = True
        while changed:
            changed = False
            for i in range(len(boxes)):
                for j in range(i + 1, len(boxes)):
                    if near(boxes[i], boxes[j], pad):
                        boxes[i] = join(boxes[i], boxes.pop(j))
                        changed = True
                        break
                if changed:
                    break
        if len(boxes) >= n:
            break
    # still too many: the smallest joins its nearest neighbour
    while len(boxes) > n:
        k = min(range(len(boxes)), key=lambda i: area(boxes[i]))
        b = boxes.pop(k)
        c = ((b[0] + b[1]) / 2, (b[2] + b[3]) / 2)
        m = min(range(len(boxes)), key=lambda i: (((boxes[i][0] + boxes[i][1]) / 2 - c[0]) ** 2
                                                  + ((boxes[i][2] + boxes[i][3]) / 2 - c[1]) ** 2))
        boxes[m] = join(boxes[m], b)
    if len(boxes) != n:
        raise SystemExit("found %d pictures on the sheet, expected %d: check the sheet (or cut it by hand)" % (len(boxes), n))
    # reading order: rows by the centres' height (a row: centres within half an icon's height), then left to right
    med_h = float(np.median([b[1] - b[0] for b in boxes]))
    boxes.sort(key=lambda b: (b[0] + b[1]) / 2)
    rows, cur = [], [boxes[0]]
    for b in boxes[1:]:
        if (b[0] + b[1]) / 2 - (cur[-1][0] + cur[-1][1]) / 2 > med_h * 0.5:
            rows.append(cur)
            cur = [b]
        else:
            cur.append(b)
    rows.append(cur)
    return [b for r in rows for b in sorted(r, key=lambda b: b[2])], bg


def cut(px, box, bg, keep_bg=False):
    """One icon: a small margin, square on the ground, SIZE x SIZE, the ground made transparent."""
    H, W = px.shape[:2]
    y0, y1, x0, x1 = box
    m = int(max(y1 - y0, x1 - x0) * 0.06)
    y0, y1, x0, x1 = max(0, y0 - m), min(H, y1 + m), max(0, x0 - m), min(W, x1 + m)
    side = max(y1 - y0, x1 - x0)
    sq = np.empty((side, side, 3))
    sq[:] = bg
    oy, ox = (side - (y1 - y0)) // 2, (side - (x1 - x0)) // 2
    sq[oy:oy + y1 - y0, ox:ox + x1 - x0] = px[y0:y1, x0:x1]
    im = Image.fromarray(sq.round().clip(0, 255).astype(np.uint8), "RGB").resize((SIZE, SIZE), Image.LANCZOS)
    rgb = np.array(im).astype(float)
    alpha = np.full(rgb.shape[:2], 255.0) if keep_bg else np.clip((distance(rgb, bg) - 14.0) / 40.0, 0, 1) * 255.0
    return Image.fromarray(np.dstack([rgb, alpha]).round().clip(0, 255).astype(np.uint8), "RGBA")


def run(sheet, out, contact=None, keep_bg=False):
    px = np.array(Image.open(sheet).convert("RGB")).astype(float)
    boxes, bg = find_icons(px)
    os.makedirs(out, exist_ok=True)
    icons = []
    for name, b in zip(NAMES, boxes):
        ic = cut(px, b, bg, keep_bg)
        ic.save(os.path.join(out, name + ".png"))
        icons.append(ic)
        print("%-13s from %4d,%4d  %dx%d" % (name, b[2], b[0], b[3] - b[2], b[1] - b[0]))
    if contact:
        sheet_im = Image.new("RGBA", (len(icons) * (SIZE + 30) + 10, SIZE + 40), (40, 34, 28, 255))
        d = ImageDraw.Draw(sheet_im)
        for i, (ic, name) in enumerate(zip(icons, NAMES)):
            sheet_im.alpha_composite(ic, (10 + i * (SIZE + 30), 6))
            d.text((10 + i * (SIZE + 30), SIZE + 14), name[:12], fill=(240, 230, 200, 255))
        sheet_im.save(contact)
    print("%d icons -> %s" % (len(icons), out))


def selftest():
    """A made-up sheet: 4 + 4 + 4 + 2 framed icons at uneven spacing, one with a gap inside; cut and checked."""
    import random
    import tempfile
    random.seed(5)
    W, H = 1400, 1100
    im = Image.new("RGB", (W, H), (22, 20, 24))
    d = ImageDraw.Draw(im)
    want = []
    y = 60
    for row, count in enumerate([4, 4, 4, 2]):
        x = 50 + random.randint(0, 40)
        for i in range(count):
            s = random.randint(170, 210)
            d.rounded_rectangle([x, y, x + s, y + s], 18, fill=(60, 50, 40), outline=(200, 170, 90), width=6)
            d.ellipse([x + 40, y + 40, x + s - 40, y + s // 2], fill=(220, 200, 150))
            d.rectangle([x + 50, y + s // 2 + 14, x + s - 50, y + s - 40], fill=(150, 90, 60))   # a part apart
            want.append((x, y))
            x += s + random.randint(40, 120)
        y += 250 + random.randint(0, 30)
    tmp = tempfile.mkdtemp()
    path = os.path.join(tmp, "sheet.png")
    im.save(path)
    px = np.array(im).astype(float)
    boxes, _ = find_icons(px)
    ok = len(boxes) == 14 and all(abs(b[2] - w[0]) < 12 and abs(b[0] - w[1]) < 12 for b, w in zip(boxes, want))
    run(path, os.path.join(tmp, "out"))
    print("selftest:", "PASS" if ok else "FAIL", tmp)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    args = sys.argv[1:]
    if "--selftest" in args:
        selftest()
    contact = None
    if "--contact" in args:
        contact = args[args.index("--contact") + 1]
        del args[args.index("--contact"):args.index("--contact") + 2]
    keep = "--keep-bg" in args
    args = [a for a in args if a != "--keep-bg"]
    run(args[0] if args else SHEET, OUT, contact, keep)
