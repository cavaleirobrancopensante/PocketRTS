"""The Crown Mortar's towed walk: the mortar on a two-wheeled cart pulled by one horse, a
crewman leading the horse and one walking behind, 8 frames per direction.

Source: art/crown/mortar_walk.png - 5 rows of 8 frames on a flat navy background. Its rows
face S, SW, W, NW and N; the middle three are mirrored here into SE, E and NE (the game
mirrors E into W, as for every unit).

  cutting   each frame is one connected piece (the reins join the men to the horse), found
            by connected components after a plain-background flood from the border (plus
            enclosed navy pockets between spokes and legs). No shadow test: the dark grey
            horse's blue-black shading is close to the navy (see import_cuirassier_gallop).
  scale     one factor for the whole sheet: its crewmen (about SHEET_CREW px from helmet to
            boots) come out CREW_H game px tall, as the Field Cannon's crew; at that size the
            cart and mortar match the mortar's own (deployed) art
  cleaning  import_cannon2's shrink (box filter), snap_team (coat reds -> team colours),
            defringe (navy edge pixels; only the light ones, so the horse's dark outline
            stays) and clean (specks)
  register  the cart is rigid: every frame is shifted so its cart (CART box, frame 0's
            coordinates) lies best on frame 0's, then the whole direction is placed on the
            mortar's cell so the ground under the cart's axle is the anchor (79, 78)

The side-on horse (E) on the sheet is pony-sized next to the cart (too short in the body
and the legs), so E gets the Field Cannon's limber horse instead (assets/units/cannon/
walk_e.png, the same role, pose and scale, its 4-step leg cycle played twice per 8 frames):
the sheet's horse is erased, the cannon's horse (harness on, its driver and traces cut off)
is put in front of the cart with its rump at the cart's front board and its hooves on the
cart's ground line, a shaft is drawn from the cart to its shoulder, and the leading crewman
is moved forward to walk at its head (drawn over it, as the cannon's driver is). The SE and
NE horses are foreshortened 3/4 views about as tall as the cannon's next to their crew, so
they stay as drawn.

Output: assets/units/mortar/walk_{s,se,e,ne,n}.png (8 cells of the mortar's 158 x 91 cell)
and the walk counts in the "mortar" entry of scripts/art_data.gd. Run before
import_horse_coats.py (which masks this horse for the coats).

Usage (from the repo root): python3 tools/import_mortar_walk.py [--contact DIR]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load  # noqa: E402
from import_cannon2 import clean, defringe, shrink, snap_team  # noqa: E402

SRC = "art/crown/mortar_walk.png"
OUT = "assets/units/mortar"
CANNON_WALK = "assets/units/cannon/walk_e.png"
ART_DATA = "scripts/art_data.gd"
N = 8
ROWS = ["s", "se", "e", "ne", "n"]          # game direction of each sheet row
MIRROR = {"se", "e", "ne"}                  # the sheet draws these facing west
CREW_H = 39.0                               # game px, helmet to boots (the cannon's crew)
SHEET_CREW = 89.0                           # the sheet's crewmen, source px
SCALE = CREW_H / SHEET_CREW
DEBUG = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None


def cell_info():
    src = open(ART_DATA).read()
    m = re.search(r'"mortar": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    return (int(m.group(1)), int(m.group(2))), (float(m.group(3)), float(m.group(4)))


# ---------------------------------------------------------------- cutting out

def navy_mask(px, tol=10):
    """Background: the flat navy within tol, flooded in from the border, plus enclosed
    pockets of it of 12+ px (between spokes, legs and arms)."""
    rgb = px[..., :3].astype(float)
    bgc = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), 0)
    near = np.abs(rgb - bgc).max(-1) <= tol
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    lab2, n2 = ndimage.label(near & ~bg)
    if n2:
        size = ndimage.sum(near, lab2, np.arange(1, n2 + 1))
        bg |= (size >= 12)[lab2 - 1] & (lab2 > 0)
    return bg, bgc


def sheet_frames(px, fg):
    """{(row, col): source mask} - each frame's big piece plus the specks near it."""
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    objs = ndimage.find_objects(lab)
    H, W = fg.shape
    frames = {}
    for i, sl in enumerate(objs):
        if size[i] < 2000:
            continue
        cy = (sl[0].start + sl[0].stop) / 2.0
        cx = (sl[1].start + sl[1].stop) / 2.0
        key = (int(cy // (H / 5.0)), int(cx // (W / float(N))))
        assert key not in frames, key
        frames[key] = lab == i + 1
    assert len(frames) == 5 * N, len(frames)
    # small pieces (a hoof, a rein end) join the frame within 6 px of them
    for i, sl in enumerate(objs):
        if size[i] >= 2000 or size[i] < 3:
            continue
        piece = lab == i + 1
        grown = ndimage.binary_dilation(piece, iterations=6)
        for k, m in frames.items():
            if (grown & m).any():
                frames[k] = m | piece
                break
    return frames


def src_crop(px, m, mirror):
    """A frame's source mask -> its source-size RGBA crop (mirrored for SE, E, NE)."""
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min() - 4, ys.max() + 5, xs.min() - 4, xs.max() + 5
    img = px[y0:y1, x0:x1].astype(np.uint8).copy()
    mm = m[y0:y1, x0:x1]
    img[..., 3] = np.where(mm, 255, 0)
    img[~mm] = 0
    if mirror:
        img = img[:, ::-1].copy()
    return img


def to_game(img, bgc, scale=SCALE):
    """Source RGBA crop -> game-size RGBA (crops of one size give aligned results)."""
    out = snap_team(shrink(img, scale))
    d = defringe(out, bgc)
    # defringe also takes the horse's dark blue-black outline for navy: only the light
    # (navy-ish) edge pixels it finds go
    rgb = out[..., :3].astype(float)
    k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
    lost = (out[..., 3] > 0) & (d[..., 3] == 0) & (k < 0.75)
    d[lost] = out[lost]
    return clean(d, min_size=4, keep_near=1)


# ---------------------------------------------------------------- registration

def paste(dst, src, ox, oy):
    """Alpha-over src onto dst with src's origin at (ox, oy) (clipped)."""
    H, W = dst.shape[:2]
    h, w = src.shape[:2]
    ya, yb, xa, xb = max(0, oy), min(H, oy + h), max(0, ox), min(W, ox + w)
    if ya >= yb or xa >= xb:
        return dst
    s = src[ya - oy:yb - oy, xa - ox:xb - ox]
    a = s[..., 3] > 0
    reg = dst[ya:yb, xa:xb]
    reg[a] = s[a]
    return dst


def on_canvas(img, ox, oy, H=160, W=240):
    c = np.zeros((H, W, 4), np.uint8)
    return paste(c, img, ox, oy)


def best_shift(ref, img, box, search=7):
    """(dx, dy) that puts img's box contents best on ref's (both on the same canvas)."""
    x0, y0, x1, y1 = box
    r = ref[y0:y1, x0:x1].astype(float)
    ra = r[..., 3] > 0
    best = None
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            s = img[y0 - dy:y1 - dy, x0 - dx:x1 - dx].astype(float)
            sa = s[..., 3] > 0
            both = ra & sa
            if both.sum() < 20:
                continue
            cost = np.abs(r[both, :3] - s[both, :3]).mean() + 120.0 * (ra ^ sa).mean() * 4
            if best is None or cost < best[0]:
                best = (cost, dx, dy)
    return best[1], best[2]


# ---------------------------------------------------------------- per-direction tables
# (frame 0's canvas coordinates: each game-size frame put at CANVAS_AT on a CANVAS canvas)

CANVAS = (110, 160)                 # h, w
CANVAS_AT = (10, 10)
# the cart (and the mortar on it), rigid from frame to frame: what the frames register on
CART = {"s": (30, 22, 57, 51), "se": (23, 16, 45, 49), "e": (27, 17, 48, 51),
        "ne": (21, 29, 46, 60), "n": (28, 26, 51, 58)}
# the ground under the cart's axle: goes on the cell's anchor
GROUND = {"s": (43, 53), "se": (34, 50), "e": (39, 51), "ne": (34, 62), "n": (41, 58)}
# Side on and three-quarter, the sheet's crewman walking behind the cart is drawn a fifth
# shorter than the one leading the horse (74 px against 89-96): he is cut out at the source
# size (everything left of his coat's right edge + TRAIL_CUT game px) and scaled up to the
# crew's height, standing on the same spot. From the north-east he is in front of the cart.
TRAIL = {"se": 1, "e": 2, "ne": 1}
TRAIL_SCALE = SHEET_CREW / 74.0
TRAIL_FRONT = {"ne"}

# E: the cannon's limber horse. Its cut in assets/units/cannon/walk_e.png frame coordinates:
# the box, and per frame the column where its driver starts (his helmet and coat; the
# horse's head ends just before it).
C_CELL = 165
C_BOX = (104, 34, 150, 90)
C_DRIVER = [139, 142, 141, 139]
C_RUMP = 105                        # its rump's back edge (all frames)
C_HOOF = 84                         # its lowest hoof (the cycle's ground line)
C_SHOULDER = (125, 61)              # where the shaft meets its harness (under the saddle pad)
E_CART_FRONT = 49                   # the cart's front board (canvas x): the sheet's horse is past it
E_HORSE_RUMP = 46                   # where the new horse's rump goes (over the front board)
E_GROUND = 50                       # its hooves' line (the cart wheels' is 51)


def team(img):
    return (img[..., 3] > 0) & (img[..., 1] == 0) & (img[..., 2] == 0) & ((img[..., 0] == 255) | (img[..., 0] == 150))


def hsv(img):
    rgb = img[..., :3].astype(float) / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return s, mx


def coats(img):
    """Team-red pieces of 6+ px, as (x0, x1, y0, y1), left to right."""
    lab, n = ndimage.label(team(img), structure=np.ones((3, 3)))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if (lab[sl] == i + 1).sum() >= 6:
            out.append((sl[1].start, sl[1].stop, sl[0].start, sl[0].stop))
    return sorted(out)


def build_frame(px, m, d, bgc):
    """One frame on the canvas, with the trailing crewman brought up to height."""
    crop = src_crop(px, m, d in MIRROR)
    g = to_game(crop, bgc)
    canvas = on_canvas(g, *CANVAS_AT, *CANVAS)
    if d not in TRAIL:
        return canvas
    # the trailing crewman: the leftmost coat
    cx1 = coats(g)[0][1]
    cut = cx1 + TRAIL[d]
    sx = int(round(cut / SCALE))
    man = crop.copy()
    man[:, sx:] = 0
    rest = crop.copy()
    rest[:, :sx] = 0
    g_rest = to_game(rest, bgc)
    g_man_small = to_game(man, bgc)
    g_man = to_game(man, bgc, SCALE * TRAIL_SCALE)

    def foot(a):
        ys, xs = np.nonzero(a[..., 3] > 0)
        return (xs.min() + xs.max()) / 2.0, ys.max()
    # the bigger man stands on the same spot: bottom-centre on bottom-centre
    fx, fy = foot(g_man_small)
    bx, by = foot(g_man)
    ox, oy = CANVAS_AT[0] + int(round(fx - bx)), CANVAS_AT[1] + int(fy - by)
    out = np.zeros_like(canvas)
    if d in TRAIL_FRONT:
        paste(out, g_rest, *CANVAS_AT)
        paste(out, g_man, ox, oy)
    else:
        paste(out, g_man, ox, oy)
        paste(out, g_rest, *CANVAS_AT)
    return out


def cannon_horse(fi):
    """The cannon's limber horse in its walk frame fi (RGBA, cannon-frame coordinates)."""
    a = np.array(Image.open(CANNON_WALK).convert("RGBA"))[:, fi * C_CELL:(fi + 1) * C_CELL].copy()
    x0, y0, x1, y1 = C_BOX
    keep = np.zeros(a.shape[:2], bool)
    keep[y0:y1, x0:min(x1, C_DRIVER[fi])] = True
    s, v = hsv(a)
    rgb = a[..., :3].astype(int)
    warm = (rgb[..., 0] > rgb[..., 2] + 25) & (s > 0.35) & ~team(a)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    keep &= ~(warm & (xx < 111) & (yy >= 60))            # the traces back to the limber
    # the driver's hand on the reins (skin, red cuff) just left of his column
    skin = (rgb[..., 0] > 150) & (rgb[..., 1] > 90) & (rgb[..., 0] > rgb[..., 2] + 40)
    keep &= ~((skin | team(a)) & (xx >= C_DRIVER[fi] - 5) & (yy >= 54))
    a[~keep] = 0
    return clean(a, min_size=4, keep_near=1)


def line_px(p0, p1):
    n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))) + 1
    return [(int(round(p0[0] + (p1[0] - p0[0]) * t)), int(round(p0[1] + (p1[1] - p0[1]) * t)))
            for t in np.linspace(0, 1, n)]


def side_horse(fr, k):
    """E frame k (registered canvas): the sheet's pony out, the cannon's horse in."""
    s, v = hsv(fr)
    yy, xx = np.mgrid[0:fr.shape[0], 0:fr.shape[1]]
    # the leading crewman: the coat right of the horse, and the biggest piece right of 3 px
    # before it
    lc = [c for c in coats(fr) if c[0] > E_CART_FRONT + 10][0]
    lead = fr.copy()
    lead[xx < lc[0] - 3] = 0
    lab, n = ndimage.label(lead[..., 3] > 0, structure=np.ones((3, 3)))
    sizes = ndimage.sum(lead[..., 3] > 0, lab, np.arange(1, n + 1))
    lead[lab != int(np.argmax(sizes)) + 1] = 0
    # the cart (and the man behind it): left of the front board, minus the pony's grey rump
    cart = fr.copy()
    cart[xx >= E_CART_FRONT] = 0
    cart[(s < 0.22) & (xx >= E_CART_FRONT - 6) & (yy > 20 + CANVAS_AT[1])] = 0
    cart = clean(cart, min_size=4, keep_near=1)
    # the cannon's horse: its 4-step cycle twice over the 8 frames
    h = cannon_horse(k % 4)
    dx, dy = E_HORSE_RUMP - C_RUMP, E_GROUND - C_HOOF
    out = cart.copy()
    paste(out, h, dx, dy)
    # the near shaft: cart bed to the horse's harness, light wood over a dark edge
    p0 = (E_CART_FRONT - 1, 31)
    p1 = (C_SHOULDER[0] + dx, C_SHOULDER[1] + dy)
    for x, y in line_px(p0, p1):
        out[y, x] = (158, 104, 52, 255)
        out[y + 1, x] = (74, 44, 22, 255)
    # the leading crewman at its head: his coat starts 2 px short of the muzzle
    hm = h[..., 3] > 0
    head_x = int(np.flatnonzero(hm[:C_HOOF - 22].any(0)).max()) + dx
    paste(out, lead, (head_x - 2) - lc[0], 0)
    return out


def main():
    (W, H), (AX, AY) = cell_info()
    px = load(SRC)
    bg, bgc = navy_mask(px)
    frames = sheet_frames(px, ~bg)
    strips = {}
    for r, d in enumerate(ROWS):
        fr = [build_frame(px, frames[(r, c)], d, bgc) for c in range(N)]
        reg = [fr[0]]
        for k in range(1, N):
            dx, dy = best_shift(fr[0], fr[k], CART[d])
            reg.append(on_canvas(fr[k], dx, dy, *CANVAS))
            print(f"{d} frame {k}: shift {dx:+d} {dy:+d}")
        if d == "e":
            reg = [side_horse(f, k) for k, f in enumerate(reg)]
        if DEBUG:
            os.makedirs(DEBUG, exist_ok=True)
            Image.fromarray(np.concatenate(reg, 1)).save(os.path.join(DEBUG, f"reg_{d}.png"))
        gx, gy = GROUND[d]
        ox, oy = int(AX) - gx, int(AY) - gy
        strip = np.zeros((H, W * N, 4), np.uint8)
        for k, f in enumerate(reg):
            cell = np.zeros((H, W, 4), np.uint8)
            paste(cell, f, ox, oy)
            assert (cell[..., 3] > 0).sum() == (f[..., 3] > 0).sum(), f"{d} frame {k} doesn't fit the cell"
            strip[:, k * W:(k + 1) * W] = cell
        strips[d] = strip
        Image.fromarray(strip).save(f"{OUT}/walk_{d}.png")
        print(f"walk_{d}: {N} frames")

    src = open(ART_DATA).read()
    m = re.search(r'\t"mortar": \{"cell".*?\n\t\}\},\n', src, re.S)
    block = m.group(0)
    for d in ROWS:
        block = re.sub(r'"walk_%s": \d+,' % d, f'"walk_{d}": {N},', block)
    open(ART_DATA, "w").write(src[:m.start()] + block + src[m.end():])

    if CONTACT:
        contact((W, H), (AX, AY))


def contact(cell, anchor):
    """x3 sheet per direction: the new walk, the cannon's walk, the mortar's idle_packed
    and deploy, all lined up on their anchors (white tick)."""
    from PIL import ImageDraw
    os.makedirs(CONTACT, exist_ok=True)
    W, H = cell
    AX, AY = anchor
    src = open(ART_DATA).read()
    cm = re.search(r'"cannon": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    CW, CAX, CAY = int(cm.group(1)), float(cm.group(3)), float(cm.group(4))
    FW, FH, FAX, FAY = 180, 120, 85, 95          # a common frame, anchor at (FAX, FAY)
    k = 3

    def frames_of(path, cw, ax, ay):
        a = np.array(Image.open(path).convert("RGBA"))
        out = []
        for i in range(a.shape[1] // cw):
            f = np.zeros((FH, FW, 4), np.uint8)
            paste(f, a[:, i * cw:(i + 1) * cw], FAX - int(ax), FAY - int(ay))
            f[FAY, FAX - 3:FAX + 4] = (255, 255, 255, 255)
            out.append(f)
        return out
    rows = []
    for d in ROWS:
        rows += [("mortar walk_" + d, frames_of(f"{OUT}/walk_{d}.png", W, AX, AY)),
                 ("cannon walk_" + d, frames_of(f"assets/units/cannon/walk_{d}.png", CW, CAX, CAY)),
                 ("idle_packed, deploy", frames_of(f"{OUT}/idle_packed_{d}.png", W, AX, AY)
                  + frames_of(f"{OUT}/deploy_{d}.png", W, AX, AY))]
    n = max(len(f) for _, f in rows)
    for part, sub in (("a", rows[:9]), ("b", rows[9:])):
        sheet = Image.new("RGB", (100 + n * (FW * k + 4), len(sub) * (FH * k + 4)), (24, 24, 24))
        dr = ImageDraw.Draw(sheet)
        for li, (label, fs) in enumerate(sub):
            y = li * (FH * k + 4)
            dr.text((4, y + 4), label, fill=(255, 255, 255))
            for i, f in enumerate(fs):
                im = Image.new("RGBA", (FW, FH), (92, 120, 72, 255))
                im.alpha_composite(Image.fromarray(f))
                sheet.paste(im.convert("RGB").resize((FW * k, FH * k), Image.NEAREST), (100 + i * (FW * k + 4), y))
        sheet.save(os.path.join(CONTACT, f"contact_mortar_walk_{part}.png"))


if __name__ == "__main__":
    main()
