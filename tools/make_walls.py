"""Draw the Crown's stone wall and gate pixel by pixel (no source sheet):
assets/buildings/{wall,gate}_{built,construction,damaged,destroyed}.png, gate_open.png
and their icons. Each piece fills one map tile and is drawn in the game's 3/4 view:
a lit top, a stone front face, crenellations; the gate has an oak door between two
posts and a pure-red pennant (recoloured to the team colour by the game).

Usage (from the repo root): python3 tools/make_walls.py
"""
import os
import random

from PIL import Image

OUT = "assets/buildings"
W, H = 34, 46          # one 32 px tile plus a 1 px margin each side; tall enough for merlons

OUTLINE = (34, 30, 28, 255)
TOP = [(150, 144, 131, 255), (140, 134, 122, 255), (160, 154, 140, 255)]
FACE = [(122, 116, 106, 255), (110, 104, 95, 255), (132, 126, 115, 255), (100, 95, 87, 255)]
MORTAR = (78, 73, 67, 255)
SHADE = (88, 83, 76, 255)
MOSS = (86, 112, 58, 255)
WOOD = [(120, 78, 42, 255), (104, 66, 35, 255), (134, 90, 50, 255)]
WOOD_DARK = (70, 44, 24, 255)
IRON = (58, 58, 64, 255)
IRON_HI = (110, 110, 118, 255)
RED = (255, 0, 0, 255)          # team key colours
RED_DARK = (150, 0, 0, 255)
SCAFF = (150, 110, 62, 255)
DARK = (22, 18, 16, 255)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, c)


def outline(im):
    """A 1 px dark outline around everything opaque."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and src.getpixel((nx, ny))[3] > 0:
                        im.putpixel((x, y), OUTLINE)
                        break


def stone_block(im, x0, x1, top_y, face_y, bottom_y, rng, merlons=True):
    """A block of masonry: lit top from top_y to face_y, brick face down to bottom_y."""
    # the walkway on top: flagstones, each slab one shade
    for sy in range(top_y, face_y, 4):
        off = 0 if ((sy - top_y) // 4) % 2 == 0 else 3
        for sx in range(x0 - off, x1 + 1, 6):
            c = rng.choice(TOP)
            for y in range(sy, min(sy + 4, face_y)):
                for x in range(max(sx, x0), min(sx + 6, x1 + 1)):
                    px(im, x, y, c)
            for x in range(max(sx, x0), min(sx + 6, x1 + 1)):
                px(im, x, min(sy + 3, face_y - 1), SHADE)
            if sx >= x0:
                for y in range(sy, min(sy + 4, face_y)):
                    px(im, sx, y, SHADE)
    # brick courses on the face, staggered
    course = 0
    y = face_y
    while y <= bottom_y:
        h = 4
        off = 0 if course % 2 == 0 else 4
        for yy in range(y, min(y + h, bottom_y + 1)):
            for x in range(x0, x1 + 1):
                px(im, x, yy, rng.choice(FACE))
        for x in range(x0, x1 + 1):
            px(im, x, min(y + h - 1, bottom_y), MORTAR)
        for x in range(x0 + off, x1 + 1, 8):
            for yy in range(y, min(y + h - 1, bottom_y + 1)):
                px(im, x, yy, MORTAR)
        y += h
        course += 1
    # shade under the top edge, a little moss at the foot
    for x in range(x0, x1 + 1):
        px(im, x, face_y, SHADE)
        if rng.random() < 0.3:
            px(im, x, bottom_y, MOSS)
    if merlons:
        # crenellations: little merlons standing on the top's front edge
        mx = x0 + 1
        while mx + 3 <= x1:
            rect(im, mx, top_y - 5, mx + 3, top_y - 1, FACE[0])
            rect(im, mx, top_y - 5, mx + 3, top_y - 5, TOP[2])
            px(im, mx + 3, top_y - 3, SHADE)
            mx += 7


def wall(state, seed=1):
    rng = random.Random(seed)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if state == "destroyed":
        # a heap of rubble
        for _ in range(70):
            x = rng.randint(3, 30)
            y = rng.randint(H - 12, H - 3)
            px(im, x, y, rng.choice(FACE + TOP))
        rect(im, 6, H - 8, 26, H - 4, FACE[3])
        for _ in range(30):
            px(im, rng.randint(6, 26), rng.randint(H - 8, H - 4), rng.choice(FACE))
        outline(im)
        return im
    top_y, face_y, bottom_y = 18, 30, H - 4
    if state == "construction":
        # the lower courses laid, scaffolding poles beside them
        stone_block(im, 1, 32, 32, 36, bottom_y, rng, merlons=False)
        for x in (3, 30):
            rect(im, x, 14, x, bottom_y, SCAFF)
        rect(im, 3, 16, 30, 16, SCAFF)
        rect(im, 3, 26, 30, 26, SCAFF)
        outline(im)
        return im
    stone_block(im, 1, 32, top_y, face_y, bottom_y, rng)
    if state == "damaged":
        # a bite out of the top and cracks down the face
        for y in range(top_y - 6, face_y + 3):
            for x in range(18, 27):
                if (x - 22) ** 2 + (y - top_y + 2) ** 2 < 30:
                    px(im, x, y, (0, 0, 0, 0))
        for i in range(10):
            px(im, 12 + (i % 3), face_y + 2 + i, DARK)
            px(im, 25 - (i % 2), face_y + 4 + i, DARK)
    outline(im)
    return im


def gate(state, open_=False, seed=2):
    rng = random.Random(seed)
    if state in ("destroyed", "construction"):
        im = wall(state, seed)
        if state == "construction":
            rect(im, 11, 34, 22, H - 5, WOOD_DARK)
        return im
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    top_y, face_y, bottom_y = 18, 30, H - 4
    # two stone posts
    stone_block(im, 1, 8, top_y - 4, face_y - 4, bottom_y, rng)
    stone_block(im, 25, 32, top_y - 4, face_y - 4, bottom_y, rng)
    # the lintel over the opening
    stone_block(im, 9, 24, top_y, face_y - 4, face_y - 1, rng, merlons=False)
    if open_:
        # the door swung back: a dark passage with the doors' edges at the sides
        rect(im, 9, face_y, 24, bottom_y, DARK)
        rect(im, 9, face_y, 10, bottom_y, WOOD[1])
        rect(im, 23, face_y, 24, bottom_y, WOOD[1])
        for x in range(11, 23):
            if rng.random() < 0.5:
                px(im, x, bottom_y, (60, 50, 40, 255))
    else:
        # oak planks with two iron bands and studs
        for x in range(9, 25):
            c = WOOD[(x // 3) % 3]
            for y in range(face_y, bottom_y + 1):
                px(im, x, y, c)
            if x % 3 == 2:
                for y in range(face_y, bottom_y + 1):
                    px(im, x, y, WOOD_DARK)
        for by in (face_y + 3, bottom_y - 3):
            rect(im, 9, by, 24, by, IRON)
            for x in range(10, 24, 3):
                px(im, x, by, IRON_HI)
        rect(im, 16, face_y, 17, bottom_y, WOOD_DARK)      # the seam of the two leaves
        px(im, 15, face_y + 8, IRON_HI)
        px(im, 18, face_y + 8, IRON_HI)
    if state == "damaged":
        for i in range(8):
            px(im, 4 + (i % 2), face_y + 2 + i, DARK)
            px(im, 28, face_y + i, DARK)
        if not open_:
            for y in range(face_y + 10, face_y + 15):
                px(im, 12, y, DARK)
                px(im, 21, y + 2, DARK)
    # a pennant on the left post, in the team colour
    rect(im, 4, 2, 4, top_y - 9, IRON)
    for i in range(6):
        for j in range(5 - i // 2):
            px(im, 5 + j, 3 + i, RED if j < 3 else RED_DARK)
    outline(im)
    return im


def gate_v(state, open_=False, seed=3):
    """The gate turned 90 degrees, for a wall running north-south: a gatehouse on the
    north side with its parapets along the east and west edges (the wall walk runs
    north-south), the east-west road through the gap south of it, and the door seen
    end-on (its top edge and thickness) across the road. Open, the leaf is swung back
    east against the gatehouse and shows its planked face; the road runs clear through."""
    rng = random.Random(seed)
    if state == "destroyed":
        im = wall("destroyed", seed)
        # a split plank or two lying across the rubble, north-south
        rect(im, 15, H - 13, 16, H - 6, WOOD_DARK)
        rect(im, 19, H - 11, 19, H - 7, WOOD[1])
        return im
    if state == "construction":
        im = wall("construction", seed)
        # the door post going up on the wall line, north-south
        rect(im, 15, 20, 18, H - 5, WOOD_DARK)
        rect(im, 16, 20, 17, H - 5, WOOD[1])
        return im
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    road_y, bottom_y = 25, H - 4
    door_h = 13
    # the road through the gap: packed earth running east-west; it reaches the canvas
    # edges (no outline there) and is frayed into the grass at the end, so it reads as
    # a track crossing the wall line
    for y in range(road_y, bottom_y + 1):
        for x in range(0, W):
            c = rng.choice(((112, 96, 72, 255), (120, 104, 78, 255), (104, 89, 67, 255)))
            if y in (road_y + 6, road_y + 12):
                c = (88, 75, 58, 255)          # cart ruts along the road
            px(im, x, y, c)
    for x in range(1, 33):
        px(im, x, road_y, DARK)                     # the gatehouse's shadow at the north edge
        px(im, x, road_y + 1, (72, 60, 46, 255))
    # the gatehouse
    top_y, face_y = 3, 14
    stone_block(im, 1, 32, top_y, face_y, road_y - 1, rng, merlons=False)
    # parapets along the east and west edges of the walk, each with crenels; they stand
    # up off the walk, so a dark line and a shadow run down their inner side
    for x0 in (1, 28):
        rect(im, x0, top_y - 3, x0 + 4, face_y - 1, FACE[0])
        rect(im, x0, top_y - 3, x0 + 4, top_y - 3, TOP[2])
        inner, shadow = (x0 + 4, x0 + 5) if x0 == 1 else (x0, x0 - 1)
        rect(im, inner, top_y - 3, inner, face_y - 1, OUTLINE)
        rect(im, shadow, top_y, shadow, face_y - 1, SHADE)
        for cy in (top_y + 2, top_y + 7):
            rect(im, x0, cy, x0 + 4, cy + 1, MORTAR)          # a crenel: a gap in the parapet
            rect(im, x0, cy + 2, x0 + 4, cy + 2, TOP[2])
    # the jamb: a groove in the gatehouse face where the door hangs (behind the shut
    # door; open, only a thin shadow beside the hinge shows)
    if open_:
        rect(im, 18, road_y - door_h, 18, road_y - 1, SHADE)
    else:
        rect(im, 15, face_y + 2, 18, road_y - 1, DARK)
    if open_:
        # the leaf swung east against the gatehouse: its planked face seen front-on
        x0, x1, y0 = 19, 29, road_y - door_h
        for x in range(x0, x1 + 1):
            c = WOOD[(x // 3) % 3] if x % 3 != 2 else WOOD_DARK
            for y in range(y0, road_y + 1):
                px(im, x, y, c)
        for by in (y0 + 2, road_y - 2):
            rect(im, x0, by, x1, by, IRON)
            for x in range(x0 + 1, x1, 3):
                px(im, x, by, IRON_HI)
        rect(im, x1 + 1, y0, x1 + 1, road_y, WOOD_DARK)   # its free edge
        rect(im, x0, y0, x1 + 1, y0, WOOD[2])              # and its lit top
        # the open road: a worn, lighter track straight through
        for x in range(1, 33):
            if rng.random() < 0.6:
                px(im, x, road_y + 9, (134, 118, 90, 255))
    else:
        # the shut door end-on: its lit top edge and thickness from the gatehouse jamb
        # to the south jamb, a seam where the two leaves meet, iron straps round it
        y0 = road_y - door_h
        for y in range(y0, bottom_y + 1):
            px(im, 14, y, WOOD_DARK)
            px(im, 15, y, WOOD[2])
            px(im, 16, y, WOOD[0])
            px(im, 17, y, WOOD[0])
            px(im, 18, y, WOOD[1])
            px(im, 19, y, WOOD_DARK)
        rect(im, 15, y0, 18, y0, (160, 112, 66, 255))
        mid = (y0 + bottom_y) // 2
        rect(im, 14, mid, 19, mid, DARK)
        rect(im, 15, mid + 1, 18, mid + 1, (160, 112, 66, 255))
        for by in (y0 + 3, mid - 3, mid + 4, bottom_y - 4):
            rect(im, 14, by, 19, by, IRON)
            px(im, 15, by, IRON_HI)
            px(im, 18, by, IRON_HI)
        # the door's shadow on the road to the west
        for y in range(road_y + 2, bottom_y + 1):
            px(im, 13, y, (78, 66, 50, 255))
            px(im, 12, y, (92, 78, 60, 255))
    # the south jamb: a short stone post on the wall line where the door shuts
    rect(im, 13, bottom_y - 3, 20, bottom_y, FACE[3])
    rect(im, 13, bottom_y - 4, 20, bottom_y - 4, TOP[0])
    rect(im, 13, bottom_y - 3, 20, bottom_y - 3, SHADE)
    if state == "damaged":
        for y in range(0, 9):
            for x in range(20, 31):
                if (x - 25) ** 2 + (y - 3) ** 2 < 20:
                    px(im, x, y, (0, 0, 0, 0))
        for i in range(8):
            px(im, 6 + (i % 2), face_y + 2 + i, DARK)
            px(im, 25 - (i % 2), face_y + 3 + i, DARK)
        if not open_:
            for y in range(road_y + 4, road_y + 10):
                px(im, 16 + (y % 2), y, DARK)
    # a pennant on the gatehouse, in the team colour
    rect(im, 3, 0, 3, top_y + 5, IRON)
    for i in range(6):
        for j in range(5 - i // 2):
            px(im, 4 + j, 0 + i, RED if j < 3 else RED_DARK)
    outline(im)
    # fray the road's ends into the grass
    for y in range(road_y + 2, bottom_y + 1):
        for x in range(0, 3):
            if rng.random() < 0.3 * (3 - x):
                px(im, x, y, (0, 0, 0, 0))
            if rng.random() < 0.3 * (3 - x):
                px(im, W - 1 - x, y, (0, 0, 0, 0))
    return im


def icon(img):
    """A 64 px icon: the piece scaled up twice on a soft backdrop like the others."""
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    big = img.resize((img.width * 2 - 8, img.height * 2 - 8), Image.NEAREST) if img.height * 2 > 64 else img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    bb = big.getbbox()
    big = big.crop(bb)
    s = min(60 / big.width, 60 / big.height)
    big = big.resize((max(1, int(big.width * s)), max(1, int(big.height * s))), Image.NEAREST)
    out.alpha_composite(big, ((64 - big.width) // 2, (64 - big.height) // 2))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for st in ("built", "construction", "damaged", "destroyed"):
        wall(st).save(f"{OUT}/wall_{st}.png")
        gate(st).save(f"{OUT}/gate_{st}.png")
    gate("built", open_=True).save(f"{OUT}/gate_open.png")
    gate("damaged", open_=True).save(f"{OUT}/gate_open_damaged.png")
    # the same gate turned 90 degrees, for walls running north-south
    for st in ("built", "construction", "damaged", "destroyed"):
        gate_v(st).save(f"{OUT}/gate_v_{st}.png")
    gate_v("built", open_=True).save(f"{OUT}/gate_v_open.png")
    gate_v("damaged", open_=True).save(f"{OUT}/gate_v_open_damaged.png")
    icon(wall("built")).save("assets/icons/wall.png")
    icon(gate("built")).save("assets/icons/gate.png")
    print("walls and gates written")


if __name__ == "__main__":
    main()
