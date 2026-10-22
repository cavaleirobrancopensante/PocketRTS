"""Horse Breeder: TEMPORARY art until the designer's sheet comes. The Cottage's four states,
tinted to a stable brown, stood at the back of a 3x3-tile paddock with a split-rail fence round
its front, plus a build icon (the Cottage's icon with a rail across it).

Output: assets/buildings/horse_breeder_{built,construction,damaged,destroyed}.png and
assets/icons/horse_breeder.png. The game draws a building's picture with its bottom middle on
the footprint's bottom edge (Building.body_offset), so the fence's front rail sits on that edge.
Usage (from the repo root): python3 tools/make_breeder_placeholder.py
"""
import numpy as np
from PIL import Image, ImageDraw

W, H = 100, 112           # the picture (the footprint is 96 x 96 px)
TINT = np.array([1.08, 0.9, 0.7])
RAIL = (122, 86, 52, 255)
RAIL_DK = (70, 46, 26, 255)
POST = (96, 64, 36, 255)


def tinted(path):
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    rgb = im[..., :3]
    team = (im[..., 0] > 140) & (im[..., 1] < 40) & (im[..., 2] < 40)
    rgb = np.where(team[..., None], rgb, np.clip(rgb * TINT, 0, 255))
    im[..., :3] = rgb
    return Image.fromarray(im.astype(np.uint8))


def fence(dr, broken=False):
    # a paddock seen from the front: rails along the bottom and up both sides
    y0, y1 = 40, H - 8
    pts = [(4, y1), (W - 5, y1)]
    for x in range(4, W - 4, 16):
        if broken and x in (36, 68):
            continue
        dr.rectangle([x, y1 - 14, x + 2, y1 + 2], fill=POST, outline=RAIL_DK)
    for side in (4, W - 7):
        for y in range(y0, y1, 14):
            dr.rectangle([side, y, side + 2, y + 10], fill=POST, outline=RAIL_DK)
        dr.line([(side + 1, y0), (side + 1, y1)], fill=RAIL, width=2)
    for dy in (-11, -5):
        if broken:
            dr.line([(4, y1 + dy), (34, y1 + dy)], fill=RAIL, width=2)
            dr.line([(72, y1 + dy), (W - 5, y1 + dy)], fill=RAIL, width=2)
        else:
            dr.line([(pts[0][0], y1 + dy), (pts[1][0], y1 + dy)], fill=RAIL, width=2)
            dr.line([(pts[0][0], y1 + dy + 2), (pts[1][0], y1 + dy + 2)], fill=RAIL_DK, width=1)
    # hay at the back corner
    dr.ellipse([W - 30, y0 - 2, W - 12, y0 + 10], fill=(196, 170, 84, 255), outline=(120, 96, 40, 255))


def main():
    for state in ["built", "construction", "damaged", "destroyed"]:
        house = tinted("assets/buildings/cottage_%s.png" % state)
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dr = ImageDraw.Draw(canvas)
        if state != "construction":
            # the trodden paddock floor
            dr.rectangle([6, 44, W - 7, H - 9], fill=(116, 104, 64, 110))
        scale = 0.78
        house = house.resize((int(house.width * scale), int(house.height * scale)), Image.NEAREST)
        canvas.alpha_composite(house, (14, max(0, H - 40 - house.height)))
        fence(ImageDraw.Draw(canvas), broken=state in ("damaged", "destroyed"))
        if state == "construction":
            a = np.asarray(canvas).copy()
            a[..., 3] = (a[..., 3] * 0.85).astype(np.uint8)
            canvas = Image.fromarray(a)
        canvas.save("assets/buildings/horse_breeder_%s.png" % state)
    icon = tinted("assets/icons/cottage.png")
    d = ImageDraw.Draw(icon)
    for y in (46, 53):
        d.line([(2, y), (61, y)], fill=RAIL, width=3)
    for x in (6, 30, 54):
        d.rectangle([x, 40, x + 3, 60], fill=POST, outline=RAIL_DK)
    icon.save("assets/icons/horse_breeder.png")
    print("horse breeder placeholder written")


if __name__ == "__main__":
    main()
