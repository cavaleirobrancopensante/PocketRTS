#!/usr/bin/env python3
"""The Farm's fields: the ground layer of the (6x5-tile) Farm, drawn under the units so the
labourers can be seen working the rows. Pixel art at 1:1 (no scaling), in the colours of the
farmhouse sprite's own little wheat field, seeded so it comes out the same every time.

    python3 tools/make_farm_field.py      -> assets/buildings/farm_field_{bare,young,ripe}.png

The windmill (assets/buildings/farm_*.png, tools/import_windmill.py) stands on the 4x2-tile
block in the middle (BLOCK: Building.FARM_BLOCK must match), on a packed-earth yard; the crop
rows (ROW px apart) run all round it: two rows behind, short plots down both sides, four rows
in front, split by a path from the windmill's door to a gap in the front fence.
"""
import random
from PIL import Image

W, H = 192, 160            # 6 x 5 tiles of 32 px
BLOCK = (32, 32, 160, 96)  # the windmill's 4x2 tiles (x0, y0, x1, y1)
PATH = (98, 112)           # the path from the windmill door (x ~105) down to the gate
ROW = 16
OUT = "assets/buildings/farm_field_%s.png"

SOIL = [(104, 68, 36), (112, 74, 40), (96, 62, 32), (118, 80, 44)]
FURROW = (70, 45, 24)
RIDGE = (138, 94, 52)
YARD = [(122, 98, 62), (114, 92, 58), (130, 104, 66)]
VERGE = [(78, 104, 44), (70, 96, 40), (88, 112, 50)]
RIPE = [(135, 69, 7), (157, 88, 14), (180, 114, 29), (195, 130, 41), (212, 154, 48), (224, 168, 55), (235, 188, 84)]
YOUNG = [(52, 82, 28), (70, 108, 34), (92, 138, 42), (118, 166, 56), (150, 192, 76)]
POST = (88, 54, 24)
POST_HI = (150, 102, 52)
RAIL = (124, 80, 36)
RAIL_HI = (166, 116, 60)
OUTLINE = (40, 26, 14)


def in_yard(x, y):
    """The packed earth: the windmill's block (its corners rounded) and the path to the gate."""
    x0, y0, x1, y1 = BLOCK
    if PATH[0] <= x < PATH[1] and y >= y1 - 8:
        return True
    r = 6
    qx, qy = min(max(x, x0 + r), x1 - 1 - r), min(max(y, y0 + r), y1 - 1 - r)
    return (x - qx) ** 2 + (y - qy) ** 2 <= r * r


def in_crops(x, y):
    """The cropped part: everything inside the fence but the yard and a grass verge round it."""
    for dx, dy in ((0, 0), (-2, 0), (2, 0), (0, -2), (0, 2)):
        if in_yard(x + dx, y + dy):
            return False
    return True


def make(stage, seed=7):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    # ground: a packed-earth yard under the windmill, a grass verge round it, tilled soil
    for y in range(2, H - 1):
        for x in range(2, W - 2):
            if in_crops(x, y):
                c = rnd.choice(SOIL)
                ry = (y - 2) % ROW
                if ry == ROW - 2:
                    c = FURROW
                elif ry == ROW - 1:
                    c = RIDGE
            elif in_yard(x, y):
                c = rnd.choice(YARD)
            else:
                c = rnd.choice(VERGE)
            px[x, y] = c + (255,)
    # clods on bare soil
    for _ in range(140 if stage == "bare" else 40):
        x, y = rnd.randrange(3, W - 3), rnd.randrange(3, H - 3)
        if in_crops(x, y):
            px[x, y] = rnd.choice([FURROW, RIDGE]) + (255,)
    # the crops: stalks growing up from each row's ridge (front to back, so nearer ones cover)
    if stage != "bare":
        pal = RIPE if stage == "ripe" else YOUNG
        lo, hi = (6, 11) if stage == "ripe" else (3, 6)
        for row_bottom in range(2 + ROW - 3, H, ROW):
            for x in range(4, W - 4):
                if not in_crops(x, row_bottom) or rnd.random() < (0.08 if stage == "ripe" else 0.2):
                    continue
                h = rnd.randint(lo, hi)
                for k in range(h):
                    y = row_bottom - k
                    if y < 3 or not in_crops(x, y):
                        break
                    # dark at the foot, bright at the ears
                    f = k / max(1, h - 1)
                    i = min(len(pal) - 1, int(f * (len(pal) - 1) + rnd.random() * 1.6))
                    if rnd.random() < 0.12:
                        i = max(0, i - 2)       # a shadowed stalk
                    px[x, y] = pal[i] + (255,)
                if stage == "ripe" and rnd.random() < 0.5:
                    # a heavy ear leaning over
                    y = row_bottom - h
                    xx = x + rnd.choice([-1, 1])
                    if 3 <= y and 3 <= xx < W - 3 and in_crops(xx, y):
                        px[xx, y] = pal[-1] + (255,)
    # the fence: rails round the edge, posts every 16 px (front and sides; the back is behind the house)
    def rail(x0, y0, x1, y1):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                px[x, y] = RAIL + (255,)
    def post(x, y):
        for yy in range(y - 6, y + 1):
            for xx in range(x, x + 2):
                if 0 <= xx < W and 0 <= yy < H:
                    px[xx, yy] = (POST_HI if xx == x else POST) + (255,)
        if 0 <= y - 7 < H:
            px[x, y - 7] = OUTLINE + (255,)
            px[x + 1, y - 7] = OUTLINE + (255,)
    # front, with a gap for the path (a post either side of it)
    for x0, x1 in ((1, PATH[0] - 2), (PATH[1] + 1, W - 2)):
        rail(x0, H - 5, x1, H - 5)
        rail(x0, H - 3, x1, H - 3)
        for x in range(x0, x1 + 1):
            px[x, H - 6] = RAIL_HI + (255,)
            px[x, H - 1] = OUTLINE + (200,)
    # sides
    for y in range(3, H - 2):
        px[1, y] = RAIL + (255,)
        px[W - 2, y] = RAIL + (255,)
        px[0, y] = OUTLINE + (200,)
        px[W - 1, y] = OUTLINE + (200,)
    # back
    for x in range(1, W - 1):
        px[x, 3] = RAIL + (255,)
        px[x, 2] = RAIL_HI + (255,)
    for x in list(range(1, W - 2, 16)) + [W - 3]:
        if not PATH[0] - 3 <= x < PATH[1] + 1:
            post(x, H - 2)
    post(PATH[0] - 3, H - 2)
    post(PATH[1] + 1, H - 2)
    for y in range(3 + 16, H - 2, 16):
        post(0, y)
        post(W - 2, y)
    post(W - 2, 9)
    return im


if __name__ == "__main__":
    for st in ["bare", "young", "ripe"]:
        make(st).save(OUT % st)
        print("wrote", OUT % st)
