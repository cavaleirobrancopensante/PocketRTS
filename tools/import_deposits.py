"""Resource deposits: saltpetre and ore outcrops (four mining states each), the small
carried-load chips, their 64x64 resource icons and a sparkle effect.

Source (generated sheet, 1536x1024, flat slate background ~#24303F):
  art/map/deposits.png  row 1: SALTPETRE outcrop, full / half mined / nearly spent /
                               exhausted (left to right)
                        row 2: ORE outcrop, the same four states
                        row 3: a small saltpetre crystal cluster, a small ore chunk, and a
                               4-frame sparkle (a gold star growing)

Everything is cut with the round 4 machinery (tools/import_cannon2.py / import_round4.py:
shadow-aware slate mask, box-filter shrink with a hard alpha edge, slate fringe and specks
removed). There is no team colour on this sheet, so nothing is snapped to the team keys:
instead every pixel the team shader would recolour (within its 0.08 RGB distance of
#FF0000 or #960000 - the ore's rust veins come close) is nudged out of reach. The
sparkle is painted light: it is un-blended from the slate (alpha from how far each pixel
is lifted above the background), not masked.

Scale: one factor for both outcrop rows (OUTCROP_SCALE) so a full outcrop is ~72 px wide,
i.e. it covers a 2x2-tile footprint (Defs.TILE = 32) with a little overhang, like the
3x2 gold mine (112 px) and the 2x2 cottage (72 px); smaller than the 3x3 farm (112x78).
All 8 outcrop pictures share one canvas and one anchor: each state is placed with the
bottom of its rock mass on the ground line and its rock mass centred, so the states swap
in place (the sheet draws them on a common ground line already).

Output:
  assets/deposits/saltpetre_{0,1,2,3}.png  0 = full ... 3 = exhausted (same canvas)
  assets/deposits/ore_{0,1,2,3}.png
  assets/deposits/saltpetre_chip.png, assets/deposits/ore_chip.png  carried-load icons
  assets/deposits/README.txt     canvas size, anchor, footprint
  assets/effects/deposit_sparkle.png  horizontal strip, 4 frames, one cell size
  assets/icons/saltpetre.png, assets/icons/ore.png  64x64 icons (dark panel, like the
                                 other icons in assets/icons), made from the chips at
                                 icon resolution (re-shrunk from the sheet, not
                                 upscaled from the small chip)

Usage (from the repo root): python3 tools/import_deposits.py [--contact DIR]
(--contact writes an x3 contact sheet on grass green and a mock mineral line - saltpetre,
ore, saltpetre, ore at game scale on grass beside the farm - into DIR).
Needs Pillow, NumPy and SciPy. Re-runnable; touches no script.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load  # noqa: E402
from import_cannon2 import bg_mask, clean, defringe, shrink  # noqa: E402

CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None

SHEET = "art/map/deposits.png"
TILE = 32
FOOTPRINT = (2, 2)
OUTCROP_SCALE = 0.21        # full saltpetre (358 px on the sheet) -> ~72 px
CHIP_SCALE = 0.13           # the chips as carried loads: ~20 px across
SPARKLE_SCALE = 0.25
ICON_FIT = 50               # chips re-shrunk so their longer side is this in the icon

# x ranges of the pictures on the sheet (read off it; the rows are far apart)
ROW_Y = {"saltpetre": (40, 395), "ore": (395, 740), "chips": (760, 960)}
OUTCROP_X = [(20, 400), (405, 772), (775, 1140), (1145, 1515)]
CHIP_X = {"saltpetre": (270, 470), "ore": (485, 665)}
SPARKLE_X = [(705, 825), (830, 955), (955, 1098), (1098, 1272)]

TEAM_KEYS = (np.array([255, 0, 0]), np.array([150, 0, 0]))
KEY_REACH = 0.08 * 255 + 2   # the shader's distance, plus a margin


# ---------------------------------------------------------------- cutting

def cut(px, bg, x0, x1, y0, y1):
    """The biggest figure (plus anything near it) in the box, as RGBA with a hard alpha."""
    fg = ~bg[y0:y1, x0:x1]
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    big = lab == (np.argmax(size) + 1)
    keep = fg & ndimage.binary_dilation(big, iterations=14)   # loose pebbles beside it
    img = px[y0:y1, x0:x1].copy()
    img[~keep] = 0
    img[..., 3] = np.where(keep, 255, 0)
    ys, xs = np.nonzero(keep)
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8)


def unkey(img):
    """Nudge every colour the team shader would swap (near #FF0000 / #960000) out of its
    reach by lifting green and blue: a rust vein stays rust."""
    out = img.copy()
    a = out[..., 3] > 0
    for _ in range(8):
        rgb = out[..., :3].astype(float)
        hit = np.zeros(a.shape, bool)
        for key in TEAM_KEYS:
            hit |= a & (np.sqrt(((rgb - key) ** 2).sum(-1)) < KEY_REACH)
        if not hit.any():
            break
        rgb[hit, 1] += 8
        rgb[hit, 2] += 4
        out[..., :3] = np.where(hit[..., None], rgb.clip(0, 255), out[..., :3]).astype(np.uint8)
    return out


def to_small(img, scale, bgc):
    out = shrink(img, scale)
    out = defringe(out, bgc)
    out = clean(out, min_size=3, keep_near=1)
    return unkey(out)


def rock_point(img):
    """Ground point of an outcrop: x = middle of the solid mass (pebbles off), y = the
    bottom of the solid mass (the lowest row with a real run of pixels)."""
    a = ndimage.binary_opening(img[..., 3] > 0, iterations=2)
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n:
        a = lab == (np.argmax(ndimage.sum(a, lab, np.arange(1, n + 1))) + 1)
    ys, xs = np.nonzero(a)
    rows = np.bincount(ys)
    bottom = int(np.flatnonzero(rows >= 3).max()) + 1
    return (xs.min() + xs.max() + 1) / 2.0, float(bottom)


def put(img, W, H, ox, oy):
    out = np.zeros((H, W, 4), np.uint8)
    h, w = img.shape[:2]
    m = img[..., 3] > 0
    out[oy:oy + h, ox:ox + w][m] = img[m]
    return out


# ---------------------------------------------------------------- outcrops

def build_outcrops(px, bg, bgc):
    pics = {}
    for kind in ("saltpetre", "ore"):
        y0, y1 = ROW_Y[kind]
        for i, (x0, x1) in enumerate(OUTCROP_X):
            small = to_small(cut(px, bg, x0, x1, y0, y1), OUTCROP_SCALE, bgc)
            pics[kind, i] = (small, rock_point(small))
    # one canvas: room left / right / above / below the ground point for every picture
    L = max(p[0] for _, p in pics.values())
    R = max(im.shape[1] - p[0] for im, p in pics.values())
    U = max(p[1] for _, p in pics.values())
    D = max(im.shape[0] - p[1] for im, p in pics.values())
    half = int(np.ceil(max(L, R)))
    W = 2 * half
    ay = int(np.ceil(U))
    H = ay + int(np.ceil(D))
    ax = half
    os.makedirs("assets/deposits", exist_ok=True)
    out = {}
    for (kind, i), (im, (px_, py_)) in pics.items():
        canvas = put(im, W, H, int(round(ax - px_)), int(round(ay - py_)))
        Image.fromarray(canvas).save(f"assets/deposits/{kind}_{i}.png")
        out[kind, i] = canvas
    return out, (W, H), (ax, ay)


# ---------------------------------------------------------------- chips and icons

def build_chips(px, bg, bgc):
    y0, y1 = ROW_Y["chips"]
    chips, icons = {}, {}
    for kind, (x0, x1) in CHIP_X.items():
        src = cut(px, bg, x0, x1, y0, y1)
        chip = to_small(src, CHIP_SCALE, bgc)
        Image.fromarray(chip).save(f"assets/deposits/{kind}_chip.png")
        chips[kind] = chip
        k = ICON_FIT / max(src.shape[:2])
        big = to_small(src, k, bgc)
        icon = np.zeros((64, 64, 4), np.uint8)
        icon[..., :3] = (28, 30, 30)
        icon[..., 3] = 255
        icon[0:2, :, :3] = icon[-2:, :, :3] = icon[:, 0:2, :3] = icon[:, -2:, :3] = (70, 74, 72)
        bh, bw = big.shape[:2]
        oy, ox = (64 - bh) // 2, (64 - bw) // 2
        m = big[..., 3] > 0
        icon[oy:oy + bh, ox:ox + bw][m] = big[m]
        Image.fromarray(icon).save(f"assets/icons/{kind}.png")
        icons[kind] = icon
    return chips, icons


# ---------------------------------------------------------------- sparkle

def build_sparkle(px, bgc):
    """Each frame un-blended from the slate: alpha = how far the pixel is lifted towards
    white above the background, colour solved from pixel = bg*(1-a) + c*a. Shrunk with
    premultiplied alpha; alpha kept soft (it is light), tiny alphas dropped. Every frame
    centred on its star in one shared cell."""
    y0, y1 = ROW_Y["chips"]
    frames = []
    for x0, x1 in SPARKLE_X:
        rgb = px[y0:y1, x0:x1, :3].astype(float)
        a = np.clip((rgb - bgc) / (255.0 - bgc), 0, None).max(-1).clip(0, 1)
        a[a < 0.06] = 0
        col = np.clip((rgb - bgc * (1 - a[..., None])) / np.maximum(a, 1e-6)[..., None], 0, 255)
        h, w = a.shape
        nw, nh = int(round(w * SPARKLE_SCALE)), int(round(h * SPARKLE_SCALE))

        def box(arr):
            return np.array(Image.fromarray(arr.astype(np.float32), "F").resize((nw, nh), Image.BOX))
        al = box(a)
        c = np.dstack([box(col[..., i] * a) for i in range(3)]) / np.maximum(al, 1e-6)[..., None]
        al = np.clip(al * 1.6, 0, 1)                 # the shrink thins the rays: lift them
        img = np.zeros((nh, nw, 4), np.uint8)
        img[..., :3] = c.clip(0, 255).round()
        img[..., 3] = (al * 255).round()
        img[img[..., 3] < 40] = 0
        # the star's centre: the brightest point
        lum = al * c.mean(-1)
        cy, cx = np.unravel_index(np.argmax(ndimage.uniform_filter(lum, 3)), lum.shape)
        ys, xs = np.nonzero(img[..., 3] > 0)          # crop to the visible light
        img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        frames.append((unkey(img), cx - xs.min(), cy - ys.min()))
    R = 0
    for im, cx, cy in frames:                  # reach of the visible light from the centre
        ys, xs = np.nonzero(im[..., 3] > 0)
        R = max(R, cx - xs.min(), xs.max() + 1 - cx, cy - ys.min(), ys.max() + 1 - cy)
    S = 2 * int(R) + 2
    strip = np.concatenate([put(im, S, S, S // 2 - cx, S // 2 - cy) for im, cx, cy in frames], 1)
    Image.fromarray(strip).save("assets/effects/deposit_sparkle.png")
    return strip, S


# ---------------------------------------------------------------- notes, checks

def write_readme(size, anchor, chips, cell):
    W, H = size
    ax, ay = anchor
    ch = {k: f"{v.shape[1]}x{v.shape[0]}" for k, v in chips.items()}
    txt = f"""Deposit sprites (made by tools/import_deposits.py from art/map/deposits.png).

saltpetre_0..3.png, ore_0..3.png
  0 = full, 1 = half mined, 2 = nearly spent, 3 = exhausted.
  canvas: {W}x{H} px, the same for all 8 (states swap in place)
  anchor: ({ax}, {ay}) px from the top-left = the ground point: middle of the outcrop's
          base, on the ground line. Draw with centered = false and
          offset = Vector2(-{ax}, -{ay}), position = the footprint's bottom-centre
          (pixels below the anchor are front rubble spilling over the edge).
  footprint: {FOOTPRINT[0]}x{FOOTPRINT[1]} tiles ({FOOTPRINT[0] * TILE}x{FOOTPRINT[1] * TILE} px at TILE = {TILE});
          the picture is {W} px wide, a little wider than the footprint.
  meant to stand in a line at the back of a base site, saltpetre and ore alternating.

saltpetre_chip.png ({ch['saltpetre']}), ore_chip.png ({ch['ore']})
  small loads a worker carries; no anchor (centre them over the carrier).

../effects/deposit_sparkle.png
  horizontal strip, 4 frames of {cell}x{cell} px, star centred in each cell; soft alpha.

../icons/saltpetre.png, ../icons/ore.png
  64x64 resource icons.
"""
    open("assets/deposits/README.txt", "w").write(txt)


def check_keys(paths):
    bad = 0
    for p in paths:
        a = np.array(Image.open(p).convert("RGBA")).astype(float)
        on = a[..., 3] > 0
        for key in TEAM_KEYS:
            d = np.sqrt(((a[..., :3] - key) ** 2).sum(-1))
            n = int((on & (d < 0.08 * 255)).sum())
            if n:
                print(f"  WARNING {p}: {n} px the team shader would recolour")
                bad += n
    return bad


# ---------------------------------------------------------------- contact sheets

GRASS = (0x55, 0x8B, 0x45, 255)


def on_green(img, k=3, mark=None):
    h, w = img.shape[:2]
    bg = Image.new("RGBA", (w, h), GRASS)
    bg.alpha_composite(Image.fromarray(img, "RGBA"))
    if mark:
        d = ImageDraw.Draw(bg)
        d.rectangle([0, 0, w - 1, h - 1], outline=(255, 255, 255, 60))
        d.line([(mark[0] - 2, mark[1]), (mark[0] + 2, mark[1])], fill=(255, 255, 255, 255))
    return bg.resize((w * k, h * k), Image.NEAREST)


def contact(out, size, anchor, chips, icons, strip, cell):
    os.makedirs(CONTACT, exist_ok=True)
    k = 3
    lines = [("saltpetre 0-3", [on_green(out["saltpetre", i], k, anchor) for i in range(4)]),
             ("ore 0-3", [on_green(out["ore", i], k, anchor) for i in range(4)]),
             ("chips / icons", [on_green(chips["saltpetre"], k), on_green(chips["ore"], k),
                                Image.fromarray(icons["saltpetre"]).resize((128, 128), Image.NEAREST).convert("RGBA"),
                                Image.fromarray(icons["ore"]).resize((128, 128), Image.NEAREST).convert("RGBA")]),
             ("sparkle", [on_green(strip[:, i * cell:(i + 1) * cell], k) for i in range(4)])]
    W = max(120 + sum(i.width + 6 for i in ims) for _, ims in lines)
    H = sum(max(i.height for i in ims) + 6 for _, ims in lines)
    sheet = Image.new("RGB", (W, H), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    y = 0
    for label, ims in lines:
        d.text((4, y + 4), label, fill=(255, 255, 255))
        x = 120
        for im in ims:
            sheet.paste(im, (x, y), im)
            x += im.width + 6
        y += max(i.height for i in ims) + 6
    sheet.save(os.path.join(CONTACT, "contact_deposits.png"))

    # mock mineral line at game scale: a grass field with a 32 px grid, four 2x2 deposits
    # in a row (saltpetre, ore, saltpetre, ore; one empty tile between them), the farm
    # (3x3) and a cottage (2x2) in front for scale; drawn x2 so it can be seen
    gw, gh = 17, 9
    field = Image.new("RGBA", (gw * TILE, gh * TILE), GRASS)
    g = Image.open("assets/terrain/grass_0.png").convert("RGBA")
    for ty in range(gh):
        for tx in range(gw):
            field.paste(g, (tx * TILE, ty * TILE))
    d = ImageDraw.Draw(field)
    W_, H_ = size
    ax, ay = anchor
    for j, kind in enumerate(["saltpetre", "ore", "saltpetre", "ore"]):
        cx = 1 + j * 3                       # footprint cells cx..cx+1, rows 1..2
        d.rectangle([cx * TILE, 1 * TILE, (cx + 2) * TILE - 1, 3 * TILE - 1], outline=(255, 255, 255, 70))
    # the other states along the bottom, to see them at game size too
    items = []
    for j, kind in enumerate(["saltpetre", "ore", "saltpetre", "ore"]):
        cx = 1 + j * 3
        items.append((3 * TILE, out[kind, 0], ((cx + 1) * TILE - ax, 3 * TILE - ay)))
    farm = Image.open("assets/buildings/farm_built.png").convert("RGBA")
    fx, fy = 13, 1                            # farm 3x3 at cells 13..15, rows 1..3
    d.rectangle([fx * TILE, fy * TILE, (fx + 3) * TILE - 1, (fy + 3) * TILE - 1], outline=(255, 255, 255, 70))
    items.append((4 * TILE, np.array(farm), (fx * TILE + 48 - farm.width // 2, 4 * TILE + 6 - farm.height)))
    row2 = [("saltpetre", 1), ("ore", 1), ("saltpetre", 2), ("ore", 2), ("saltpetre", 3), ("ore", 3)]
    for j, (kind, st) in enumerate(row2):
        cx = 1 + j * 2.5
        items.append((7 * TILE, out[kind, st], (int(cx * TILE + TILE - ax), 7 * TILE - ay)))
    for _, im, (x, y) in sorted(items, key=lambda t: t[0]):
        field.alpha_composite(Image.fromarray(np.asarray(im), "RGBA"), (int(x), int(y)))
    # a carried chip and the sparkle next to the farm
    field.alpha_composite(Image.fromarray(chips["saltpetre"]), (int(10.6 * TILE), int(4.4 * TILE)))
    field.alpha_composite(Image.fromarray(chips["ore"]), (int(11.6 * TILE), int(4.4 * TILE)))
    field.alpha_composite(Image.fromarray(strip[:, 3 * cell:4 * cell]), (int(2 * TILE - cell / 2), int(1.6 * TILE)))
    field.resize((field.width * 2, field.height * 2), Image.NEAREST).save(
        os.path.join(CONTACT, "mineral_line.png"))


def main():
    px = load(SHEET)
    bg, bgc = bg_mask(px)
    out, size, anchor = build_outcrops(px, bg, bgc)
    chips, icons = build_chips(px, bg, bgc)
    strip, cell = build_sparkle(px, bgc)
    write_readme(size, anchor, chips, cell)
    paths = [f"assets/deposits/{k}_{i}.png" for k in ("saltpetre", "ore") for i in range(4)]
    paths += ["assets/deposits/saltpetre_chip.png", "assets/deposits/ore_chip.png",
              "assets/effects/deposit_sparkle.png", "assets/icons/saltpetre.png", "assets/icons/ore.png"]
    bad = check_keys(paths)
    print(f"deposits: canvas {size[0]}x{size[1]}, anchor {anchor}, footprint "
          f"{FOOTPRINT[0]}x{FOOTPRINT[1]} tiles; chips " +
          ", ".join(f"{k} {v.shape[1]}x{v.shape[0]}" for k, v in chips.items()) +
          f"; sparkle {cell}x{cell} x4; team-key pixels: {bad}")
    if CONTACT:
        contact(out, size, anchor, chips, icons, strip, cell)


if __name__ == "__main__":
    main()
