"""Repairs the weapons in the Crown infantry sprites (run after tools/import_art.py).

The generated art drew the pikeman's pike kinked at the butt and the musketeer's musket
at a different size in almost every frame. This finds the weapon (the thin parts that
stick out of the body), removes it, and paints a clean, straight weapon of one fixed
length, pixel by pixel, in the sprites' palette.

    python3 tools/fix_weapons.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SHAFT = [(40, 24, 14), (122, 74, 36)]             # outline, wood
STEEL = [(60, 60, 66), (150, 150, 160), (215, 215, 225)]
BARREL = [(34, 34, 40), (92, 92, 104), (140, 140, 152)]
STOCK = [(46, 26, 12), (110, 64, 30), (146, 92, 46)]


def frames(kind, anim, cw):
    path = f"assets/units/{kind}/{anim}.png"
    a = np.array(Image.open(path).convert("RGBA"))
    return path, a, [a[:, i * cw:(i + 1) * cw] for i in range(a.shape[1] // cw)]


def body_mask(f):
    op = f[..., 3] > 40
    core = ndi.binary_opening(op, structure=np.ones((3, 3)))
    lab, n = ndi.label(core)
    if n == 0:
        return core
    sizes = ndi.sum(core, lab, range(1, n + 1))
    big = lab == (np.argmax(sizes) + 1)
    return ndi.binary_dilation(big, iterations=1) & op


def put(f, p, col, only_empty=False):
    x, y = int(round(p[0])), int(round(p[1]))
    if 0 <= x < f.shape[1] and 0 <= y < f.shape[0]:
        if only_empty and f[y, x, 3] > 40:
            return
        f[y, x] = (*col, 255)


def line(f, a, d, length, colour_at, behind_from=1e9, behind_to=-1.0):
    """A 2-pixel shaft from `a` along unit vector `d`; colour_at(t) -> (main, outline)."""
    nrm = np.array([-d[1], d[0]])
    if nrm[1] < 0 or (nrm[1] == 0 and nrm[0] < 0):
        nrm = -nrm
    for i in range(int(length * 2) + 1):
        t = i / 2.0
        p = a + d * t
        hide = behind_to <= t <= behind_from if behind_to >= 0 else t >= behind_from
        main, edge = colour_at(t)
        put(f, p, main, hide)
        put(f, p + nrm, edge, hide)


def outside_parts(f):
    op = f[..., 3] > 40
    w = op & ~body_mask(f)
    lab, n = ndi.label(w, structure=np.ones((3, 3)))
    return w, lab, n


# ------------------------------------------------------------------ pikeman

PIKE = 44.0


def pike_colour(t):
    if t < 2:
        return STEEL[2], STEEL[0]
    if t < 5:
        return STEEL[1], STEEL[0]
    return SHAFT[1], SHAFT[0]


def fix_pike(f):
    w, lab, n = outside_parts(f)
    if n == 0:
        return
    sizes = ndi.sum(w, lab, range(1, n + 1))
    main = lab == (np.argmax(sizes) + 1)
    if sizes.max() < 12:
        return
    ys, xs = np.where(main)
    pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0)
    d = np.linalg.svd(pts - c)[2][0]
    body_c = np.argwhere(body_mask(f)).mean(0)[::-1]
    proj = (pts - c) @ d
    tip, end = c + d * proj.min(), c + d * proj.max()
    if np.linalg.norm(tip - body_c) < np.linalg.norm(end - body_c):
        tip, end = end, tip
    d = (end - tip) / np.linalg.norm(end - tip)
    # remove the old pike and the stray kinked bits of it outside the body
    for k in range(1, n + 1):
        comp = lab == k
        cy, cx = np.argwhere(comp).mean(0)
        q = np.array([cx, cy]) - tip
        off = abs(q[0] * d[1] - q[1] * d[0])
        if k == np.argmax(sizes) + 1 or (sizes[k - 1] <= 40 and off > 2.5):
            f[comp] = 0
    # one straight pike, passing behind the soldier
    line(f, tip, d, PIKE, pike_colour, behind_from=10.0)


# ------------------------------------------------------------------ musketeer

MUSKET = 27.0


def musket_colour(t):
    # t runs from the butt (0) to the muzzle (MUSKET)
    if t < 2:
        return STOCK[2], STOCK[0]
    if t < 10:
        return STOCK[1], STOCK[0]
    if t > MUSKET - 1.5:
        return BARREL[2], BARREL[0]
    return BARREL[1], BARREL[0]


def clear_stray(f):
    """Remove the scraps of the old musket that stick out of the body."""
    w, lab, n = outside_parts(f)
    for k in range(1, n + 1):
        comp = lab == k
        if comp.sum() <= 60:
            f[comp] = 0


def anchors(f):
    b = body_mask(f)
    ys, xs = np.where(b)
    return b, xs.min(), xs.max(), ys.min(), ys.max()


def fix_musket(f, anim):
    clear_stray(f)
    b, x0, x1, y0, y1 = anchors(f)
    hgt = y1 - y0
    if anim in ("walk_e", "walk_se", "walk_ne"):
        # carried at the port: butt at the front hip, muzzle forward and up
        yh = int(y0 + hgt * 0.55)
        row = np.where(b[yh])[0]
        hand = np.array([row.max() - 1 if len(row) else x1, yh], float)
        ang = np.radians(-58 if anim != "walk_ne" else -66)
        d = np.array([np.cos(ang), np.sin(ang)])
        line(f, hand - d * 6, d, MUSKET, musket_colour)
    elif anim in ("walk_s", "walk_n", "idle_s", "idle_n"):
        # shouldered, upright on the right (front view) or left (back view) side
        side_x = x1 + 1 if anim.endswith("_s") else x0 - 2
        base = np.array([side_x, y0 + hgt * 0.75])
        d = np.array([0.0, -1.0])
        line(f, base, d, MUSKET, musket_colour, behind_from=-1, behind_to=-1)
    elif anim in ("idle_e", "idle_se", "idle_ne"):
        # order arms: butt on the ground beside the front foot, muzzle up past the head
        base = np.array([x1 + 1, y1])
        d = np.array([-0.08, -1.0])
        d /= np.linalg.norm(d)
        line(f, base, d, MUSKET, musket_colour)


def main():
    for anim in ["walk_e", "walk_se", "walk_ne", "walk_s", "walk_n"]:
        path, a, fs = frames("pikeman", anim, 68)
        for f in fs:
            fix_pike(f)
        Image.fromarray(a).save(path)
    for anim in ["walk_e", "walk_se", "walk_ne", "walk_s", "walk_n", "idle_e", "idle_se", "idle_ne", "idle_s", "idle_n"]:
        path, a, fs = frames("musketeer", anim, 90)
        for f in fs:
            fix_musket(f, anim)
        Image.fromarray(a).save(path)
    print("weapons repaired")


if __name__ == "__main__":
    main()
