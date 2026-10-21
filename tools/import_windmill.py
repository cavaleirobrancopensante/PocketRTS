"""The Crown Farm's windmill, its turning sails and its scarecrows, from the ChatGPT sheet
art/crown/farm_windmill.png (1536x1024, flat slate background), three rows:

  1. the windmill tower without sails: built, construction (scaffold), damaged, destroyed
  2. the sails, six frames - NOT used as drawn: their blade angles (measured: 36, 76, 26,
     19, 8 and 21 degrees, mod 90) are no even sequence, and frame 2 is turned the wrong
     way. The clean first drawing is turned in code instead, in 15-degree steps: four
     blades repeat every 90 degrees, so six frames make a smooth endless loop.
  3. four scarecrows: straw hat, tricorne, sack head, crow on the arm

Output (assets/buildings/):
  farm_{built,construction,damaged,destroyed}.png   the tower, all four on ONE canvas
        with one anchor (the foot of the door): Building.FARM_ART["anchor"]
  farm_sails.png        a strip of SAIL_FRAMES frames, SAIL_CELL px square, hub in the middle;
        drawn over the tower at Building.FARM_ART["hub"] (from the anchor)
  farm_scarecrow.png    a strip of the four scarecrows, SCARE_CELL each, foot of the pole
        at the bottom middle
The destroyed tower gets one broken sail lying on the ground beside it.
assets/icons/farm.png (the build button) is remade from the windmill with its sails.
Team colour: the cap and the coats are snapped to the two key reds (snap_cap).

Usage (from the repo root): python3 tools/import_windmill.py
Prints the numbers Building.FARM_ART needs. Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import TEAM_DARK, TEAM_LIGHT, load  # noqa: E402
from import_cannon2 import bg_mask, clean, defringe, shrink, snap_team  # noqa: E402

SHEET = "art/crown/farm_windmill.png"
OUT = "assets/buildings"
SCALE = 0.4            # tower and sails (the tower is ~110 px wide: the 4x2-tile farmhouse block)
SCARE_SCALE = 0.13     # a scarecrow about as tall as a labourer
STATES = ["built", "construction", "damaged", "destroyed"]
# cell of each tower drawing on the sheet, and its anchor there: the foot of its door
# (damaged: lined up with the built one by the sail hub, the door is half hidden)
TOWER_CELLS = [(0, 384), (384, 768), (768, 1152), (1152, 1536)]
TOWER_ANCHOR = [(201, 292), (568, 293), (913, 297), (1327, 300)]
HUB = (219, 157)                   # the sail axle's tip on the built tower (sheet px)
ROWS = [(0, 390), (390, 680), (680, 1024)]
SAIL_SRC = 0                       # the sails drawing that is turned
SAIL_FRAMES = 6
SAIL_STEP = 15.0                   # degrees per frame, counter-clockwise
SCARE_ORDER = ["straw_hat", "tricorne", "sack_head", "crow"]   # left to right on the sheet


def pieces():
    px = load(SHEET)
    bg, bgc = bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    out = []
    for k, sl in enumerate(ndimage.find_objects(lab)):
        m = lab[sl] == k + 1
        if m.sum() < 4:
            continue
        ys, xs = np.nonzero(m)
        out.append({"lab": k + 1, "area": int(m.sum()), "cy": sl[0].start + ys.mean(), "cx": sl[1].start + xs.mean()})
    return px, lab, bgc, out


def cut(px, lab, bgc, labels, box):
    """The pieces `labels` inside box (x0, y0, x1, y1) as an RGBA array (uint8)."""
    x0, y0, x1, y1 = box
    m = np.isin(lab[y0:y1, x0:x1], labels)
    img = px[y0:y1, x0:x1].copy()
    img[..., 3] = np.where(m, 255, 0)
    img[~m] = 0
    return defringe(img.clip(0, 255).astype(np.uint8), bgc)


def in_cell(ps, row, x0, x1, big):
    """Labels of the pieces whose middle lies in this cell, small specks only near a big one."""
    y0, y1 = ROWS[row]
    mem = [p for p in ps if y0 <= p["cy"] < y1 and x0 <= p["cx"] < x1]
    top = max(p["area"] for p in mem)
    return [p["lab"] for p in mem if p["area"] >= top * big]


def rotate_about(img, cx, cy, deg, size):
    """Nearest-neighbour turn of img (counter-clockwise on screen) about (cx, cy), onto a
    size x size canvas centred on that point."""
    th = np.deg2rad(deg)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    dx, dy = xx - size / 2.0 + 0.5, yy - size / 2.0 + 0.5
    # screen y points down: a counter-clockwise turn on screen
    sx = np.cos(th) * dx - np.sin(th) * dy
    sy = np.sin(th) * dx + np.cos(th) * dy
    si, sj = np.round(cy + sy - 0.5).astype(int), np.round(cx + sx - 0.5).astype(int)
    h, w = img.shape[:2]
    ok = (si >= 0) & (si < h) & (sj >= 0) & (sj < w)
    out = np.zeros((size, size, 4), np.uint8)
    out[ok] = img[si[ok], sj[ok]]
    return out


def snap_cap(img):
    """snap_team, and the deep crimson shading round the team reds that it leaves (too dark
    for its test, it would stay red on every team): the darkest becomes a neutral outline,
    the rest the dark key red; and orange glints inside the red become the light key."""
    img = snap_team(img)
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    team = (img[..., 3] > 0) & (g == 0) & (b == 0) & ((r == TEAM_LIGHT[0]) | (r == TEAM_DARK[0]))
    near = ndimage.binary_dilation(team, iterations=3) & (img[..., 3] > 0) & ~team
    crimson = near & (r >= 30) & (g <= r * 0.2) & (b <= r * 0.25)
    img[crimson & (r < 60), :3] = (34, 24, 26)
    img[crimson & (r >= 60), :3] = TEAM_DARK
    # orange-red glints in the middle of the cap (most of their neighbours team red): light key
    team = (img[..., 3] > 0) & (img[..., 1] == 0) & (img[..., 2] == 0) & ((img[..., 0] == TEAM_LIGHT[0]) | (img[..., 0] == TEAM_DARK[0]))
    around = ndimage.convolve(team.astype(int), np.ones((3, 3), int), mode="constant") - team
    glint = (img[..., 3] > 0) & ~team & (around >= 5) & (r >= 140) & (g <= r * 0.62) & (b <= r * 0.45)
    img[glint, :3] = TEAM_LIGHT
    return img


def bbox(img):
    ys, xs = np.nonzero(img[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def main():
    px, lab, bgc, ps = pieces()
    # ---- the tower: each drawing scaled, placed on one canvas by its anchor
    imgs = []
    for (x0, x1), (ax, ay) in zip(TOWER_CELLS, TOWER_ANCHOR):
        labels = in_cell(ps, 0, x0, x1, 0.0005)
        y0, y1 = ROWS[0]
        im = cut(px, lab, bgc, labels, (x0, y0, x1, y1))
        # pad so the anchor lands on a whole pixel after scaling
        imgs.append((im, (ax - x0) * SCALE, (ay - y0) * SCALE))
    small = [(clean(snap_cap(shrink(im, SCALE))), ax, ay) for im, ax, ay in imgs]
    # the sails (made here so the destroyed tower can have a broken one)
    sx0 = [48, 288, 550, 804, 1050, 1300][SAIL_SRC]
    sail_labels = in_cell(ps, 1, sx0 - 20, sx0 + 230, 0.002)
    sl = cut(px, lab, bgc, sail_labels, (0, ROWS[1][0], 1536, ROWS[1][1]))
    ys, xs = np.nonzero(sl[..., 3] > 0)
    hub_y, hub_x = _hub(sl[..., 3] > 0)
    R = int(np.ceil(np.hypot(ys - hub_y, xs - hub_x).max())) + 2
    big = 2 * R
    frames = []
    for i in range(SAIL_FRAMES):
        fr = rotate_about(sl, hub_x + 0.5, hub_y + 0.5, i * SAIL_STEP, big)
        frames.append(clean(snap_team(shrink(fr, SCALE), effect=True)))
    cell = frames[0].shape[0]
    strip = np.zeros((cell, cell * SAIL_FRAMES, 4), np.uint8)
    for i, fr in enumerate(frames):
        strip[:, i * cell:(i + 1) * cell] = fr[:cell, :cell]
    Image.fromarray(strip).save(f"{OUT}/farm_sails.png")
    # a broken sail on the ground by the ruin: one blade (the one pointing right in the
    # frame turned so a blade lies level), squashed flat, a little darker
    lvl = rotate_about(sl, hub_x + 0.5, hub_y + 0.5, _level_angle(sl[..., 3] > 0, hub_y, hub_x), big)
    blade = lvl[R - R // 3:R + R // 3, R + 14:]
    blade = shrink(blade, SCALE)
    bh, bw = blade.shape[:2]
    flat = np.array(Image.fromarray(blade).resize((bw, max(1, bh // 2)), Image.NEAREST))
    flat = np.array(Image.fromarray(flat).rotate(-14, expand=True, resample=Image.NEAREST))
    flat[..., :3] = (flat[..., :3].astype(float) * 0.78).astype(np.uint8)
    # one canvas for all four states
    left = max(ax for _, ax, _ in small)
    top = max(ay for _, _, ay in small)
    right = max(im.shape[1] - ax for im, ax, _ in small)
    bottom = max(im.shape[0] - ay for im, _, ay in small)
    W, H = int(np.ceil(left + right)) + 2, int(np.ceil(top + bottom)) + 2
    AX, AY = int(round(left)) + 1, int(round(top)) + 1
    for st, (im, ax, ay) in zip(STATES, small):
        can = np.zeros((H, W, 4), np.uint8)
        ox, oy = int(round(AX - ax)), int(round(AY - ay))
        h, w = im.shape[:2]
        can[oy:oy + h, ox:ox + w] = np.where(im[..., 3:4] > 0, im, can[oy:oy + h, ox:ox + w])
        if st == "destroyed":
            # lying in front, to the right of the door, half on the dirt
            fh, fw = flat.shape[:2]
            px0, py0 = AX + 10, AY + 2
            px0, py0 = min(px0, W - fw), min(py0, H - fh)
            reg = can[py0:py0 + fh, px0:px0 + fw]
            can[py0:py0 + fh, px0:px0 + fw] = np.where(flat[..., 3:4] > 0, flat, reg)
        Image.fromarray(can).save(f"{OUT}/farm_{st}.png")
    hub = ((HUB[0] - TOWER_ANCHOR[0][0]) * SCALE, (HUB[1] - TOWER_ANCHOR[0][1]) * SCALE)
    # ---- the build button: the standing windmill with its sails (as import_art's make_icon)
    pad = cell
    whole = np.zeros((H + 2 * pad, W + 2 * pad, 4), np.uint8)
    body = np.array(Image.open(f"{OUT}/farm_built.png"))
    whole[pad:pad + H, pad:pad + W] = body
    hx, hy = int(round(pad + AX + hub[0] - cell / 2)), int(round(pad + AY + hub[1] - cell / 2))
    reg = whole[hy:hy + cell, hx:hx + cell]
    whole[hy:hy + cell, hx:hx + cell] = np.where(frames[0][:cell, :cell, 3:4] > 0, frames[0][:cell, :cell], reg)
    bx0, by0, bx1, by1 = bbox(whole)
    whole = whole[by0:by1, bx0:bx1]
    big = shrink(whole, 56.0 / max(whole.shape[:2]))
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (28, 30, 30)
    icon[..., 3] = 255
    icon[0:2, :, :3] = icon[-2:, :, :3] = icon[:, 0:2, :3] = icon[:, -2:, :3] = (70, 74, 72)
    bh, bw = big.shape[:2]
    oy, ox = (64 - bh) // 2, (64 - bw) // 2
    m = big[..., 3] > 0
    icon[oy:oy + bh, ox:ox + bw][m] = big[m]
    Image.fromarray(snap_team(icon)).save("assets/icons/farm.png")
    # ---- the scarecrows: a strip, each cell the same size, the pole's foot at the bottom middle
    sc = []
    for c in range(4):
        x0, x1 = c * 384, (c + 1) * 384
        labels = in_cell(ps, 2, x0, x1, 0.001)
        im = cut(px, lab, bgc, labels, (x0, ROWS[2][0], x1, ROWS[2][1]))
        bx0, by0, bx1, by1 = bbox(im)
        # the pole's foot: the middle of the lowest rows
        ys2, xs2 = np.nonzero(im[..., 3] > 0)
        foot_x = xs2[ys2 >= by1 - 6].mean()
        sm = clean(snap_cap(shrink(im, SCARE_SCALE)))
        sc.append((sm, foot_x * SCARE_SCALE, by1 * SCARE_SCALE))
    cw = int(np.ceil(max(2 * max(fx - bbox(s)[0], bbox(s)[2] - fx) for s, fx, _ in sc))) + 2
    ch = int(np.ceil(max(fy - bbox(s)[1] for s, _, fy in sc))) + 1
    sstrip = np.zeros((ch, cw * 4, 4), np.uint8)
    for i, (s, fx, fy) in enumerate(sc):
        ox, oy = int(round(i * cw + cw / 2 - fx)), int(round(ch - fy))
        h, w = s.shape[:2]
        for y in range(h):
            for x in range(w):
                if s[y, x, 3] and 0 <= oy + y < ch and i * cw <= ox + x < (i + 1) * cw:
                    sstrip[oy + y, ox + x] = s[y, x]
    Image.fromarray(sstrip).save(f"{OUT}/farm_scarecrow.png")
    print(f"tower canvas {W}x{H}, anchor ({AX}, {AY}); hub {hub[0]:.1f}, {hub[1]:.1f}")
    print(f"sails: {SAIL_FRAMES} frames of {cell}x{cell}, hub at the middle; scarecrows: 4 of {cw}x{ch}")


def _hub(m):
    """The sails' hub: the point the drawing is most nearly symmetric about (half-turn)."""
    ys, xs = np.nonzero(m)
    cy, cx = ys.mean(), xs.mean()
    best = (-1, cy, cx)
    for dy in range(-10, 11):
        for dx in range(-10, 11):
            yc, xc = cy + dy, cx + dx
            yy, xx = np.round(2 * yc - ys).astype(int), np.round(2 * xc - xs).astype(int)
            ok = (yy >= 0) & (yy < m.shape[0]) & (xx >= 0) & (xx < m.shape[1])
            s = m[yy[ok], xx[ok]].sum()
            if s > best[0]:
                best = (s, yc, xc)
    return best[1], best[2]


def _level_angle(m, cy, cx):
    """The counter-clockwise turn (degrees) that lays one blade level."""
    ys, xs = np.nonzero(m)
    r = np.hypot(ys - cy, xs - cx)
    ang = np.arctan2(-(ys - cy), xs - cx)[r > 30]
    a = np.degrees(np.angle(np.exp(4j * ang).mean())) / 4
    return -a


if __name__ == "__main__":
    main()
