"""The Crown labourer's pickaxe made into a hoe (he farms with it).

import_art.py cuts the labourer's frames from art/crown/labourer.png, where he swings a
pickaxe. A hoe has a single flat blade bent down from the end of the handle, so here the
pick's other arm (the spike on the far side of the handle, the one pointing up or back)
is cut away in every frame that shows the tool: the mine swing in all five facings and
the idle stance where he holds it at his side.

Each edit is a small box (frame-local pixels, x0, y0, x1, y1 inclusive) round that spike;
inside it only iron-coloured pixels (grey or near-black outline) are cleared, so the hat,
hands and handle are never touched. Clearing is idempotent: running this twice is the same
as running it once. Run after import_art.py and import_round6.py (the keg strips), as
tools/rebuild_art.sh does.

It then sweeps the source's leftover pale backdrop from every strip (clean_all()).

It also repaints the train-button portrait (assets/icons/labourer.png): see fix_icon().
"""
import colorsys
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DIR = os.path.join(ROOT, "assets/units/labourer")
CELL = 42  # labourer cell width (scripts/art_data.gd)

# anim -> {frame: [(x0, y0, x1, y1), ...]}
EDITS = {
    # mine: frame 0 raised, 1 mid-swing, 2 the strike (the blade is in the ground, the
    # spike points up out of it)
    "mine_s": {0: [(25, 2, 27, 5)], 1: [(28, 3, 34, 7), (35, 4, 35, 6)], 2: [(33, 23, 37, 26)]},
    "mine_se": {0: [(29, 2, 33, 6), (34, 4, 34, 6)], 1: [(23, 5, 28, 7)], 2: [(30, 14, 34, 18)]},
    "mine_e": {0: [(32, 8, 36, 11), (37, 8, 37, 10)], 1: [(33, 15, 35, 16)], 2: [(35, 17, 38, 21)]},
    "mine_ne": {1: [(33, 11, 37, 14)], 2: [(33, 18, 36, 22)]},
    "mine_n": {0: [(27, 2, 29, 5)], 1: [(29, 7, 33, 10)], 2: [(29, 23, 33, 26)]},
    # idle: the tool held at his side, head at the end of the handle; the spike is the
    # arm above the handle, the blade the one hanging below it. (idle_s / idle_n show
    # only a grey shaft, and idle_ne frame 0 the handle's end: nothing to cut there.)
    "idle_se": {0: [(32, 24, 33, 25)], 1: [(32, 23, 33, 25)]},
    "idle_e": {0: [(31, 16, 35, 19)], 1: [(32, 15, 35, 18)]},
    "idle_ne": {1: [(30, 10, 34, 12)]},
}


def is_iron(px):
    r, g, b, a = px
    if a < 20:
        return False
    _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v < 0.25 or s < 0.25


# ---------------------------------------------------------------- the train-button portrait
# assets/icons/labourer.png (64x64, cut by import_art.py from art/ui/icons.png) shows him
# in a grey knit cap with a hammer on his shoulder. Here the cap becomes the brimmed brown
# felt hat he wears in game, and the hammer a hoe. Painted at 4x and box-filtered down, so
# the new parts are as soft as the rest of the painting.

ICON = os.path.join(ROOT, "assets/icons/labourer.png")
S = 4                                   # paint scale
BG = (27, 30, 32)                       # the portrait's backdrop
# the in-game hat's felt (assets/units/labourer/idle_*), darkest to lightest
FELT = [(16, 10, 6), (48, 28, 12), (92, 55, 22), (134, 89, 44), (168, 126, 74), (198, 160, 108)]
FELT_AT = [0.0, 0.12, 0.27, 0.45, 0.68, 0.9]
WOOD_D, WOOD_M, WOOD_L = (58, 30, 8), (140, 80, 22), (206, 146, 66)
IRON_O, IRON_D, IRON_M, IRON_L = (8, 8, 10), (60, 62, 72), (118, 121, 132), (186, 189, 196)
# the old cap's outline (64 px coordinates)
CAP = [(21, 23), (22, 17), (25, 12), (30, 8.5), (38, 7.5), (45, 9.5), (49, 14), (50, 18), (49.5, 21.5),
       (44, 22), (38, 23.5), (33, 25), (29, 29), (25, 31), (21, 29)]
# the hammer's head and the top of its handle, painted out
HAMMER = [(6, 22), (14, 21), (24, 25), (25, 33), (23, 38), (15, 38.5), (8, 40), (6, 38)]
# the brim: an ellipse (centre, radii, tilt in degrees, + = right side lower)
BRIM_C, BRIM_R, BRIM_T = (35.5, 20.5), (17.0, 3.6), 7.0
# the hoe: the handle runs along the hammer's, from the fist up to TIP; the blade hangs
# from TIP bent down and back toward the handle
FIST, TIP = (24.5, 50.0), (16.0, 17.0)
NECK = [(13.8, 15.4), (11.4, 15.4), (10.2, 17.4)]
BLADE = [(6.9, 17.6), (14.0, 18.4), (14.6, 27.6), (6.6, 27.0)]   # top left, top right, bottom right, bottom left


def _poly_mask(poly, w=64, h=64):
    from PIL import ImageDraw
    m = Image.new("L", (w * S, h * S), 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in poly], fill=255)
    return m


def _down(im):
    return im.resize((im.width // S, im.height // S), Image.BOX)


def _felt(lum):
    for i in range(len(FELT_AT) - 1):
        if lum <= FELT_AT[i + 1]:
            t = (lum - FELT_AT[i]) / (FELT_AT[i + 1] - FELT_AT[i])
            return tuple(round(a + (b - a) * t) for a, b in zip(FELT[i], FELT[i + 1]))
    return FELT[-1]


def _brim_y(x):
    """The brim's centre line at column x (64 px)."""
    import math
    return BRIM_C[1] + (x - BRIM_C[0]) * math.tan(math.radians(BRIM_T))


def fix_icon(src=ICON, dst=ICON):
    import math
    from PIL import ImageDraw, ImageFilter

    im = Image.open(src).convert("RGBA")
    px = im.load()
    cap = _down(_poly_mask(CAP)).load()
    greys = sum(1 for y in range(64) for x in range(64)
                if cap[x, y] > 128 and colorsys.rgb_to_hsv(*[c / 255 for c in px[x, y][:3]])[1] < 0.2
                and max(px[x, y][:3]) > 90)
    if greys < 40:
        print("fix_labourer_hoe: icon already has the hat and hoe")
        return

    # 1. the cap's grey felt -> the hat's brown felt, by brightness (keeps the brushwork)
    crown = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    cp = crown.load()
    for y in range(64):
        for x in range(64):
            if cap[x, y] < 128:
                continue
            r, g, b, _ = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.3 and v > 0.2:            # face, hair: not the cap
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            px[x, y] = _felt(min(1.0, lum * 1.0)) + (255,)
            if y < _brim_y(x) - 0.5:
                cp[x, y] = px[x, y]

    big = im.resize((64 * S, 64 * S), Image.NEAREST)
    d = ImageDraw.Draw(big)

    # 2. the hammer painted out: the backdrop, then the shoulder line it hid
    d.polygon([(x * S, y * S) for x, y in HAMMER], fill=BG + (255,))
    d.line([(6 * S, 41 * S), (14 * S, 38 * S), (21 * S, 35 * S)], fill=(10, 4, 2, 255), width=int(1.4 * S))
    d.polygon([(x * S, y * S) for x, y in [(6, 42), (14, 39), (21, 36), (23, 40), (8, 44), (6, 44)]],
              fill=(120, 6, 4, 255))

    # 3. the brim, in front of the head; the shadow it casts on the face
    cx, cy = BRIM_C[0] * S, BRIM_C[1] * S
    rx, ry = BRIM_R[0] * S, BRIM_R[1] * S
    t = math.radians(BRIM_T)

    def ell(k, dx=0.0, dy=0.0):
        pts = []
        for i in range(72):
            a = 2 * math.pi * i / 72
            ex, ey = rx * k * math.cos(a), ry * k * math.sin(a)
            pts.append((cx + dx * S + ex * math.cos(t) - ey * math.sin(t), cy + dy * S + ex * math.sin(t) + ey * math.cos(t)))
        return pts
    shade = Image.new("L", big.size, 0)
    ImageDraw.Draw(shade).polygon(ell(0.92, 0.6, 2.4), fill=110)
    shade = shade.filter(ImageFilter.GaussianBlur(S))
    big = Image.composite(Image.new("RGBA", big.size, (8, 4, 2, 255)), big, shade)
    d = ImageDraw.Draw(big)
    d.polygon(ell(1.0, 0, 0.5), fill=FELT[1] + (255,))            # outline / underside
    d.polygon(ell(0.94, 0, -0.1), fill=FELT[3] + (255,))          # upper face of the brim
    d.polygon(ell(0.80, -1.2, -0.5), fill=FELT[4] + (255,))       # its lit near edge
    d.polygon(ell(0.66, -1.0, -0.9), fill=FELT[3] + (255,))

    # 4. the hoe: handle (outline, wood, light stripe), then the blade
    def stick(a, b, w, col):
        d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=col + (255,), width=int(w * S))
    tip_out = (TIP[0] - 0.6, TIP[1] - 1.2)
    stick(FIST, tip_out, 3.2, WOOD_D)
    stick(FIST, TIP, 2.0, WOOD_M)
    stick((FIST[0] - 0.5, FIST[1]), (TIP[0] - 0.5, TIP[1]), 0.8, WOOD_L)
    # the gooseneck from the handle's end, bent out and down to the blade
    neck = [(TIP[0] * S, TIP[1] * S)] + [(x * S, y * S) for x, y in NECK]
    d.line(neck, fill=IRON_O + (255,), width=int(2.0 * S), joint="curve")
    d.line(neck, fill=IRON_D + (255,), width=int(1.0 * S), joint="curve")
    # the blade: a flat plate hanging below the neck, its sharpened edge at the bottom
    d.polygon([(x * S, y * S) for x, y in BLADE], fill=IRON_O + (255,))
    (ax, ay), (bx, by), (cx2, cy2), (dx2, dy2) = BLADE
    inset = [(ax + 0.7, ay + 0.7), (bx - 0.7, by + 0.7), (cx2 - 0.7, cy2 - 0.8), (dx2 + 0.7, dy2 - 0.8)]
    d.polygon([(x * S, y * S) for x, y in inset], fill=IRON_M + (255,))
    (ix, iy), (jx, jy), (kx, ky), (lx, ly) = inset
    d.polygon([(x * S, y * S) for x, y in [(ix, iy), (jx, jy), (jx - 1.6, jy + 2.6), (ix, iy + 2.4)]],
              fill=IRON_L + (255,))
    d.polygon([(x * S, y * S) for x, y in [(lx, ly - 1.0), (kx, ky - 1.0), (kx, ky), (lx, ly)]],
              fill=IRON_D + (255,))
    d.line([(lx * S, (ly + 0.4) * S), (kx * S, (ky + 0.4) * S)], fill=IRON_L + (255,), width=S)   # the edge

    out = _down(big)
    # the crown sits above the back half of the brim
    out.alpha_composite(crown)
    # the fist stays in front of the handle
    o, src_px = out.load(), im.load()
    for y in range(44, 62):
        for x in range(16, 34):
            r, g, b, _ = src_px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.03 < h < 0.12 and s > 0.35 and v > 0.55:      # skin
                o[x, y] = src_px[x, y]
    # the frame is untouched
    for y in range(64):
        for x in range(64):
            if x < 6 or x > 57 or y < 6 or y > 57:
                o[x, y] = src_px[x, y]
    # a solid iron socket joining the blade to the handle (a one-pixel neck looked wired on)
    H = lambda c: tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    edge, hi, mid, dk = H("101113"), H("8a8d97"), H("6a6c72"), H("404144")
    for x in range(10, 18):
        o[x, 15] = edge
        o[x, 16] = edge if x in (10, 17) else hi
        o[x, 17] = edge if x in (10, 17) else mid
    for x in range(13, 18):
        o[x, 18] = dk if x < 17 else edge
    out.save(dst)
    print("fix_labourer_hoe: icon: brown felt hat and a hoe")


# ---------------------------------------------------------------- leftover backdrop
# The source sheet's pale backdrop survives here and there in the cut frames: a fringe of
# near-white pixels on the silhouette and specks in the gaps (between the legs, under the
# arms, between handle and body) that flash white as he walks and works. Every strip in
# the folder is swept: a pale, greyish pixel on the edge of the silhouette is darkened to
# the outline (or dropped if it sticks out on its own), and one inside a gap is cleared.
# The labourer has no white in his own colours; what is light grey on purpose (the iron
# of his tools, the keg's hoops) sits inside the silhouette and is listed in KEEP.

PALE_V, PALE_S = 0.55, 0.22             # brighter than his trousers, greyer than his skin
GAP_V = 0.62                            # inside the silhouette only the clearly pale go
OUTLINE = (26, 18, 12)
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))
# strip -> {frame: [(x, y), ...]}: light pixels that are drawn, not backdrop
KEEP = {}
# the keg's iron hoops are pale grey runs across its middle: in the strips that show the
# keg only the edge is swept, not the inside
NO_GAPS = ("carry_keg", "idle_keg", "bury", "death_keg")


def _hsv(p):
    return colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)


def clean_strip(path, keep=None, gaps=True):
    """The backdrop left in one strip cleaned; returns (darkened, cleared)."""
    im = Image.open(path).convert("RGBA")
    px = im.load()
    W, H = im.size
    keep = {(f * CELL + x, y) for f, pts in (keep or {}).items() for x, y in pts}

    def solid(x, y):
        return 0 <= x < W and 0 <= y < H and px[x, y][3] >= 20 and (x // CELL) == (cx // CELL)

    def pale(x, y, vmin):
        p = px[x, y]
        if p[3] < 20 or (x, y) in keep:
            return False
        h, s, v = _hsv(p)
        if v >= vmin and s < PALE_S:
            return True
        # the backdrop blended into the red coat: pale pink (his skin is orange-hued)
        if v >= vmin + 0.13 and s < 0.42 and (h < 0.035 or h > 0.85):
            return True
        # ... and into the straw-yellow of the source's lighting: lemon white
        return v >= 0.88 and s < 0.36 and 0.13 < h < 0.2

    darkened = cleared = 0
    for _ in range(8):      # until nothing changes: a fringe two deep, a gap opened by the last
        changes = []
        # on the silhouette's edge: darkened to the outline, or dropped if it sticks out
        for y in range(H):
            for x in range(W):
                cx = x
                if not pale(x, y, PALE_V):
                    continue
                if all(solid(x + dx, y + dy) for dx, dy in N4):
                    continue
                around = [px[x + dx, y + dy] for dx, dy in N8 if solid(x + dx, y + dy)
                          and not pale(x + dx, y + dy, PALE_V)]
                if sum(1 for dx, dy in N4 if solid(x + dx, y + dy)) <= 1 or not around:
                    changes.append((x, y, (0, 0, 0, 0)))
                else:
                    dark = min(around, key=lambda p: _hsv(p)[2])
                    col = dark if _hsv(dark)[2] < 0.3 else OUTLINE + (255,)
                    changes.append((x, y, col[:3] + (255,)))
        # specks in the gaps (between the legs, under the arms): cleared
        for y in range(H):
            for x in range(W):
                cx = x
                if gaps and pale(x, y, GAP_V) and all(solid(x + dx, y + dy) for dx, dy in N4) \
                        and sum(1 for dx, dy in N8 if _hsv(px[x + dx, y + dy])[2] < 0.35) >= 2:
                    # (a gap is seen between dark edges; a pale glint on the sack is not one)
                    changes.append((x, y, (0, 0, 0, 0)))
        if not changes:
            break
        for x, y, c in changes:
            px[x, y] = c
            if c[3] == 0:
                cleared += 1
            else:
                darkened += 1
    # the backdrop blended into the coat: a pink the team shader leaves pink. Where it
    # touches the coat's team red it becomes the coat's shadow red (tinted like the coat)
    TEAM = ((255, 0, 0), (150, 0, 0))
    recoloured = 0
    for y in range(H):
        for x in range(W):
            p = px[x, y]
            if p[3] < 20 or (x, y) in keep or p[:3] in TEAM:
                continue
            h, s, v = _hsv(p)
            if v > 0.7 and 0.25 < s < 0.75 and (h > 0.9 or h < 0.02) and any(
                    0 <= x + dx < W and px[x + dx, y + dy][:3] in TEAM and px[x + dx, y + dy][3] >= 20
                    for dx, dy in N8 if 0 <= y + dy < H and (x + dx) // CELL == x // CELL):
                px[x, y] = TEAM[1] + (255,)
                recoloured += 1
    im.save(path)
    return darkened, cleared, recoloured


def clean_all(folder=DIR):
    for f in sorted(os.listdir(folder)):
        if f.endswith(".png"):
            name = f[:-4]
            d, c, r = clean_strip(os.path.join(folder, f), KEEP.get(name), not name.startswith(NO_GAPS))
            if d or c or r:
                print(f"fix_labourer_hoe: {name}: backdrop pixels {d} darkened, {c} cleared, {r} pink to coat red")


def main():
    fix_icon()
    for anim, frames in EDITS.items():
        path = os.path.join(DIR, anim + ".png")
        im = Image.open(path).convert("RGBA")
        px = im.load()
        n = 0
        for f, boxes in frames.items():
            for x0, y0, x1, y1 in boxes:
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        X = f * CELL + x
                        if is_iron(px[X, y]):
                            px[X, y] = (0, 0, 0, 0)
                            n += 1
        im.save(path)
        print(f"fix_labourer_hoe: {anim}: {n} pick pixels cleared")
    clean_all()


if __name__ == "__main__":
    main()
