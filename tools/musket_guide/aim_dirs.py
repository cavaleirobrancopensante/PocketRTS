"""Pose guides for ChatGPT: the Musketeer and the Guardsman AIMING, FIRING and THRUSTING the bayonet toward the
south-east, the north-east and the south (docs/animation_audit_crown.md, finding 1: every view aims east today, and a
ChatGPT sheet asked to fix all five views at once on 2026-10-27 drew every row firing east again).

Each guide is built from the game's own east frames (aim 2, fire 2, melee 3 frames): the musket, the hands on it, the
flash and the smoke (everything in front of the front shoulder, above the waist) are turned about that shoulder, down for
the south-east, up for the north-east and steeply down for the south; the body stays as it is (the prompt says which
way to turn it). Then the figure is enlarged 8 times on the navy the import tools key out, one row of seven frames per
sheet. They show ChatGPT WHERE the barrel points; they are not meant to look finished.

Out: art/redraws/guides/<unit>_aim_<dir>_guide.png (unit: musketeer, musketeer_armoured; dir: se, ne, s).
  python3 tools/musket_guide/aim_dirs.py"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw

NAVY = (0, 22, 48)
SCALE = 8
TURN = {"se": 28.0, "ne": -32.0}       # degrees, + turns the barrel down (screen y grows downward)
ANIMS = [("aim", 2), ("fire", 2), ("melee", 3)]
CELL_H = 36


def frames(unit, anim):
    a = np.asarray(Image.open("assets/units/%s/%s_e.png" % (unit, anim)).convert("RGBA"))
    h = a.shape[0]
    n = {"aim": 2, "fire": 2, "melee": 3}[anim]
    cw = a.shape[1] // n
    return [a[:, i * cw:(i + 1) * cw] for i in range(n)]


def pivot(f):
    """The front shoulder: the torso's right edge at chest height (the opaque run at the body's column)."""
    al = f[..., 3] > 0
    ys = np.nonzero(al.any(1))[0]
    top, bot = ys.min(), ys.max()
    legs = al[bot - 6:bot + 1]
    xs = np.nonzero(legs.any(0))[0]
    body_x = (xs.min() + xs.max()) / 2.0
    chest_y = top + (bot - top) * 0.33
    return body_x + 3.0, chest_y, top + (bot - top) * 0.62


def turn(f, deg):
    """The part in front of the shoulder and above the waist, turned about the shoulder; the rest as it is."""
    px, py, waist = pivot(f)
    h, w = f.shape[:2]
    big = np.zeros((h * 3, w * 2, 4), np.uint8)
    oy, ox = h, w // 2
    al = f[..., 3] > 0
    yy, xx = np.nonzero(al)
    # (the hat's front corner and the face are in front of the shoulder too: the head stays)
    front = (xx > px + 1) & (yy < waist) & ~((yy < py - 2) & (xx < px + 8))
    for y, x in zip(yy[~front], xx[~front]):
        big[y + oy, x + ox] = f[y, x]
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    # inverse map over the target area so the turned part has no holes
    src = np.zeros((h, w), bool)
    src[yy[front], xx[front]] = True
    for ty in range(big.shape[0]):
        for tx in range(big.shape[1]):
            dx, dy = tx - ox - px, ty - oy - py
            sx = c * dx + s * dy + px
            sy = -s * dx + c * dy + py
            ix, iy = int(round(sx)), int(round(sy))
            if 0 <= ix < w and 0 <= iy < h and src[iy, ix] and big[ty, tx, 3] == 0:
                big[ty, tx] = f[iy, ix]
    ys, xs = np.nonzero(big[..., 3] > 0)
    return big[ys.min() - 2:ys.max() + 3, xs.min() - 2:xs.max() + 3], (ys.max() + 1 - (ys.min() - 2))


def south(unit):
    """The SOUTH frames: firing at the viewer cannot be turned out of a side view. The standing south frame with its
    shouldered musket taken off, and on it a short, foreshortened barrel from his right shoulder (on the screen's left)
    toward the middle of his chest, the flash and the smoke in front of him (lower on the screen: toward us), and for
    the bayonet a blade that reaches further toward us in the thrust. Crude on purpose: the prompt asks for the pose."""
    a = np.asarray(Image.open("assets/units/%s/idle_s.png" % unit).convert("RGBA"))
    cw = a.shape[1] // 2
    f = a[:, :cw].copy()
    al = f[..., 3] > 0
    ys, xs = np.nonzero(al)
    top = ys.min()
    # the shouldered musket: the columns that rise above the hat (rows top..top+1), and the next one in
    gun = sorted(set(int(x) for x in np.nonzero(al[top:top + 2].any(0))[0]))
    body = al[top + 10:top + 22]
    bx = np.nonzero(body.any(0))[0]
    if gun and min(gun) > (bx.min() + bx.max()) / 2:
        for x in range(min(gun) - 1, max(gun) + 2):
            f[:top + 24, x] = 0
    al = f[..., 3] > 0
    ys, xs = np.nonzero(al)
    L, R = xs.min(), xs.max()
    mid = (L + R) / 2.0
    sh = (L + 3, top + 12)                     # his right shoulder, on the screen's left
    WOOD, STEEL, FLASH, CORE, SMOKE = (92, 52, 28, 255), (190, 196, 204, 255), (255, 150, 30, 255), (255, 240, 150, 255), (160, 160, 165, 255)
    out = []
    specs = [("aim", 0.55, None, None), ("aim", 0.75, None, None), ("fire", 0.75, 3.2, 3.5), ("fire", 0.75, None, 5.0),
             ("melee", 0.7, None, None), ("melee", 1.15, None, None), ("melee", 0.7, None, None)]
    for anim, reach, flash, smoke in specs:
        g = Image.fromarray(f.copy(), "RGBA")
        big = Image.new("RGBA", (cw, a.shape[0] + 14), (0, 0, 0, 0))
        big.alpha_composite(g, (0, 0))
        dr = ImageDraw.Draw(big)
        end = (mid + 1.5, sh[1] + 9 * reach)
        dr.line([sh, end], fill=(20, 12, 8, 255), width=4)        # (an outline, so the barrel reads on the coat)
        dr.line([sh, end], fill=(176, 112, 60, 255), width=2)
        if anim == "melee":
            tip = (end[0] + 1.2 * reach, end[1] + 5 * reach)
            dr.line([end, tip], fill=(20, 12, 8, 255), width=3)
            dr.line([end, tip], fill=STEEL, width=1)
        if smoke:
            cy = end[1] + 2 + smoke
            dr.ellipse((end[0] - smoke, cy - smoke, end[0] + smoke, cy + smoke), fill=SMOKE)
        if flash:
            dr.ellipse((end[0] - flash, end[1] - flash + 1, end[0] + flash, end[1] + flash + 1), fill=FLASH)
            dr.ellipse((end[0] - 1.2, end[1], end[0] + 1.2, end[1] + 2.2), fill=CORE)
        b = np.asarray(big)
        ys2, xs2 = np.nonzero(b[..., 3] > 0)
        out.append((anim, b[ys2.min() - 2:ys2.max() + 3, xs2.min() - 2:xs2.max() + 3]))
    return out


def guide(unit, d):
    figs = []
    if d == "s":
        figs = south(unit)
    for anim, n in (ANIMS if d != "s" else []):
        for f in frames(unit, anim):
            g, _ = turn(f, TURN[d])
            figs.append((anim, g))
    cellw = max(g.shape[1] for a, g in figs) + 6
    cellh = max(g.shape[0] for a, g in figs) + 6
    sheet = Image.new("RGB", (cellw * len(figs) * SCALE, cellh * SCALE + 40), NAVY)
    dr = ImageDraw.Draw(sheet)
    for i, (anim, g) in enumerate(figs):
        im = Image.fromarray(g, "RGBA").resize((g.shape[1] * SCALE, g.shape[0] * SCALE), Image.NEAREST)
        x = i * cellw * SCALE + (cellw * SCALE - im.width) // 2
        y = 40 + cellh * SCALE - im.height - 3 * SCALE
        if d == "s":
            y = 40 + 4 * SCALE
        sheet.paste(im, (x, y), im)
        dr.text((i * cellw * SCALE + 8, 8), "%s %d" % (anim.upper().replace("MELEE", "BAYONET"), [0, 1, 0, 1, 0, 1, 2][i] + 1), fill=(160, 180, 230))
    os.makedirs("art/redraws/guides", exist_ok=True)
    out = "art/redraws/guides/%s_aim_%s_guide.png" % (unit, d)
    sheet.save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    for unit in ("musketeer", "musketeer_armoured"):
        for d in ("se", "ne", "s"):
            guide(unit, d)
