"""The Crown Powder Mill from art/crown/powder_mill_horse.png: four building states left to right
(built, construction, damaged, destroyed) on a dark blue-grey background. An open timber and
stone works with a slate roof, heaps of saltpetre, sulphur and charcoal, barrels, and a round
millstone with a centre post on an empty circular dirt track at the front right: a horse mill
(the game walks a harnessed horse round that track: Building.MILL_ART).

It replaces the old water-wheel mill (art/crown/structures2.png's middle row, which
tools/import_art.py no longer writes).

Each state is one big connected piece on the sheet (the small specks round it join the
nearest one); keyed out like the Horse Breeder (tools/import_horse_units.py's slate test, then
the slate-tinted fringe goes), scaled so the built mill is WIDTH px wide (the footprint is 3x3
tiles, 96 px; the old mill was 112, the track needs a little more), the other states by the
same factor, and its banner (only: not the barrels' red hoops) snapped to the team key reds. The build icon is the built state on
the Cottage icon's frame (like the Horse Breeder's).

The millstone and its post (measured on the sheet: STONE) in the built and damaged states are
also written alone, as an overlay the game draws over the horse while it walks behind them.
The numbers the game needs (the track's ellipse and the post's top, from the sprite's base
point) are printed: they go in Building.MILL_ART.

The horse: the harnessed team horse's walk strips (assets/units/horse_team/walk_<dir>.png,
tools/import_horse_team.py) painted bay through their coat masks (the same ramp and blend the
shader uses: assets/units/horse_masks/coat_ramps.png row 1), the traces trailing behind it cut
off (the sweep replaces them), shrunk to the mill's scale (HORSE_SCALE of the team horse), so
the game draws it 1:1 without a coat shader and it stays team-neutral. Run after
tools/import_horse_team.py and tools/import_horse_coats.py.

The runner (art/crown/mill_runner_top.png, a strict top-down picture of the turning millstone
with its iron hub and the timber arm ending in the swingle-bar and two chains) is keyed out and
written 2x oversampled (assets/buildings/mill_runner.png: the game draws it at half size, turned
and squashed like the track, so turning stays crisp). Its stone is RUNNER_R px in the game (a
little under the painted bed stone's), and the plain middle of the arm is cut out so the hub to
the swingle-bar is the track's radius (TRACK_R): the stone keeps its size. The hub's centre
(the pivot, in texture px) is printed for Building.MILL_ART.

Output: assets/buildings/powder_mill_{built,construction,damaged,destroyed}.png,
assets/buildings/mill_runner.png,
assets/buildings/powder_mill_stone_{built,damaged}.png, assets/buildings/mill_horse/walk_<dir>.png,
assets/icons/powder_mill.png and the "powder_mill" entry of BUILDING_SIZE in scripts/art_data.gd.
Usage (from the repo root): python3 tools/import_powder_mill.py
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team, unteam  # noqa: E402
from import_cannon2 import defringe  # noqa: E402
from import_horse_units import load, shrink  # noqa: E402
from import_round12 import write_building_size  # noqa: E402

STATES = ["built", "construction", "damaged", "destroyed"]
WIDTH = 124          # the built mill's width in the game (footprint 96 px, the old mill 112)
HORSE_SCALE = 0.44   # of the team horse (46 px tall: about 20 px at the mill, a little under a man)
DIRS = ["s", "se", "e", "ne", "n"]
TEAM_CELL = (112, 70)
TEAM_ANCHOR = (56, 66)
BAY = 1              # coat_ramps.png row

# The millstone, measured on the sheet (sheet px) in the states that keep it whole: its top
# face (an ellipse: centre, half width, half height), how thick its rim is, and its centre
# post's columns and top. The track's ground centre is under the face's centre by the rim; the
# horse walks it at TRACK times the stone's half width (the middle of the trodden ring), as
# flat as the face.
STONE = {
    "built": {"face": (287, 563.5, 37, 16.5), "rim": 12, "post": (284, 292, 547)},
    "damaged": {"face": (1057.5, 571, 37.5, 15.5), "rim": 11, "post": (1053, 1061, 547)},
}
TRACK = 1.5
SHADOW = np.array([46.0, 39.0, 33.0])   # a warm dark for the slate seen inside the drawing


def slate_to_shadow(rgb, bg):
    """The slate background seen through the scaffolding, the open front and the broken roof
    (it stays inside the drawing) is blue: on the map it would read as a hole into the night.
    Those pixels (the slate's colour, darker or lighter, with its blue cast) become a warm
    shadow of the same depth."""
    c = rgb.astype(float)
    k = (c * bg).sum(-1) / (bg * bg).sum()
    resid = np.abs(c - k[..., None] * bg).max(-1)
    cast = (c[..., 2] - c[..., 0]) >= 0.5 * (bg[2] - bg[0]) * k
    slate = (k >= 0.2) & (k <= 1.6) & (resid <= 10 + 4 * k) & cast
    out = c.copy()
    out[slate] = k[slate, None] * SHADOW
    return out.clip(0, 255).astype(np.uint8)


def snap_banner(img):
    """snap_team, but only on the banner (the biggest red patch, and any nearly as big): the
    barrels' red hoops stay as painted."""
    r, g, b = (img[..., i].astype(int) for i in range(3))
    red = (img[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32)
    lab, n = ndimage.label(ndimage.binary_dilation(red, iterations=1))
    if n == 0:
        return img
    sizes = ndimage.sum(red, lab, range(1, n + 1))
    keep = (sizes >= 0.4 * sizes.max())[lab - 1] & (lab > 0)
    out = snap_team(img.copy())
    out[~keep] = unteam(img.copy())[~keep]
    return out


def cut_states(px, fg, bg):
    """The four states (RGBA, sheet scale) and their crops' top-left corners on the sheet."""
    fg = ndimage.binary_closing(fg, iterations=2) | fg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    objs = ndimage.find_objects(lab)
    big = sorted(np.argsort(-sizes)[:4], key=lambda i: objs[i][1].start)
    boxes = [objs[i] for i in big]
    masks = [lab == i + 1 for i in big]
    # specks: to the state whose box they sit in (grown a little)
    for k, sl in enumerate(objs):
        if k in big or sl is None or sizes[k] < 12:
            continue
        cy, cx = (sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2
        for j, b in enumerate(boxes):
            if b[1].start - 8 <= cx < b[1].stop + 8 and b[0].start - 8 <= cy < b[0].stop + 8:
                masks[j] |= lab == k + 1
                break
    imgs, origins = [], []
    for m in masks:
        m = ndimage.binary_fill_holes(m)
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        img = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        img[..., :3] = px[y0:y1, x0:x1]
        img[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0)
        img = defringe(img, bg)
        img[..., :3] = slate_to_shadow(img[..., :3], bg)
        imgs.append(img)
        origins.append((x0, y0))
    return imgs, origins


def stone_mask(shape, origin, st):
    """The stone's and post's pixels (sheet scale, in the state's crop)."""
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    xx += origin[0]
    yy += origin[1]
    cx, cy, rx, ry = STONE[st]["face"]
    rim = STONE[st]["rim"]
    face = ((xx - cx) / (rx + 1)) ** 2 + ((yy - cy) / (ry + 1)) ** 2 <= 1
    low = ((xx - cx) / (rx + 1)) ** 2 + ((yy - cy - rim) / (ry + 1)) ** 2 <= 1
    band = (np.abs(xx - cx) <= rx + 1) & (yy >= cy) & (yy <= cy + rim)
    px0, px1, ptop = STONE[st]["post"]
    post = (xx >= px0) & (xx <= px1) & (yy >= ptop) & (yy <= cy)
    return face | low | band | post


# the runner sheet (px): the hub's centre, the stone's radius, the swingle-bar's centre, and a
# stretch of plain timber (between the hub plate and the iron collar) that is cut out
RUNNER_HUB = (584.0, 602.5)
RUNNER_STONE_R = 195.0
RUNNER_BAR_X = 1128.0
RUNNER_CUT_FROM = 790
RUNNER_R = 10.5      # the stone's radius in the game (the painted bed stone's is 12.2)
TRACK_R = 18.5       # the arm's length, hub to swingle-bar: the track's half width


def runner():
    """The turning millstone and its arm (see the module doc): mill_runner.png, 2x."""
    px = np.asarray(Image.open("art/crown/mill_runner_top.png").convert("RGB"))
    border = np.concatenate([px[0], px[-1], px[:, 0], px[:, -1]]).astype(float)
    bg = np.median(border, 0)
    fg = np.abs(px.astype(float) - bg).max(-1) > 24
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    fg = ndimage.binary_fill_holes(lab == int(np.argmax(sizes)) + 1)
    ys, xs = np.nonzero(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    img = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    img[..., :3] = px[y0:y1, x0:x1]
    img[..., 3] = np.where(fg[y0:y1, x0:x1], 255, 0)
    img = defringe(img, bg)
    s2 = 2.0 * RUNNER_R / RUNNER_STONE_R             # texture px per sheet px (2x oversampled)
    cut = int(round((RUNNER_BAR_X - RUNNER_HUB[0]) - 2.0 * TRACK_R / s2))
    c0 = RUNNER_CUT_FROM - x0
    img = np.concatenate([img[:, :c0], img[:, c0 + cut:]], 1)
    small = shrink(img, s2, 0.45)
    Image.fromarray(small).save("assets/buildings/mill_runner.png")
    hub = ((RUNNER_HUB[0] - x0) * s2, (RUNNER_HUB[1] - y0) * s2)
    print("runner %d x %d (2x), hub (%.1f, %.1f), cut %d sheet px" % (small.shape[1], small.shape[0], hub[0], hub[1], cut))


def horse_strips():
    ramps = np.asarray(Image.open("assets/units/horse_masks/coat_ramps.png").convert("RGB")).astype(float)
    os.makedirs("assets/buildings/mill_horse", exist_ok=True)
    cw, ch = TEAM_CELL
    for d in DIRS:
        strip = np.asarray(Image.open("assets/units/horse_team/walk_%s.png" % d).convert("RGBA")).copy()
        mask = np.asarray(Image.open("assets/units/horse_masks/horse_team/walk_%s.png" % d).convert("RGB"))
        rgb = strip[..., :3].astype(float)
        horse = mask[..., 0] > 127
        t = mask[..., 2].astype(float) / 255.0
        col = ramps[BAY][np.clip((t * 63).round().astype(int), 0, 63)]
        lum = (rgb * [0.299, 0.587, 0.114]).sum(-1) / 255.0
        k = np.clip((lum - 0.035) / (0.10 - 0.035), 0, 1)
        k = k * k * (3 - 2 * k)
        out = rgb * (1 - k[..., None]) + col * k[..., None]
        strip[..., :3] = np.where(horse[..., None], out, rgb).clip(0, 255).astype(np.uint8)
        n = strip.shape[1] // cw
        if d in ("e", "se", "ne"):
            # the traces trailing back: only the columns where the body stands tall stay
            for f in range(n):
                fr = strip[:, f * cw:(f + 1) * cw]
                xs = np.nonzero((fr[..., 3] > 0).sum(0) >= 14)[0]
                if len(xs):
                    fr[:, :max(0, xs.min() - 1)] = 0
        frames = [unteam(shrink(strip[:, f * cw:(f + 1) * cw], HORSE_SCALE)) for f in range(n)]
        sh, sw = frames[0].shape[:2]
        out = np.zeros((sh, sw * n, 4), np.uint8)
        for f, fr in enumerate(frames):
            out[:, f * sw:(f + 1) * sw] = fr[:sh, :sw]
        Image.fromarray(out).save("assets/buildings/mill_horse/walk_%s.png" % d)
    print("horse cell %d x %d, anchor (%.1f, %.1f)" % (sw, sh, TEAM_ANCHOR[0] * HORSE_SCALE, TEAM_ANCHOR[1] * HORSE_SCALE))


def main():
    px, fg, bg = load("powder_mill_horse")
    imgs, origins = cut_states(px, fg, bg)
    scale = WIDTH / float(imgs[0].shape[1])
    sizes = []
    for st, img, org in zip(STATES, imgs, origins):
        small = snap_banner(shrink(img, scale, 0.45))
        Image.fromarray(small).save("assets/buildings/powder_mill_%s.png" % st)
        sizes.append(small.shape[1::-1])
        print(st, small.shape[1], "x", small.shape[0])
        if st not in STONE:
            continue
        sh, sw = small.shape[:2]
        mask = stone_mask(img.shape[:2], org, st)
        ms = np.array(Image.fromarray((mask * 255).astype(np.uint8)).resize((sw, sh), Image.BOX)) >= 110
        ov = np.where((ms & (small[..., 3] > 0))[..., None], small, 0).astype(np.uint8)
        Image.fromarray(ov).save("assets/buildings/powder_mill_stone_%s.png" % st)
        # in game px from the base point (the sprite's bottom middle is 6 px under it:
        # Building.body_offset)
        bx, by = -sw / 2.0, -sh + 6.0

        def g(x, y):
            return (bx + (x - org[0]) * scale, by + (y - org[1]) * scale)
        cx, cy, rx, ry = STONE[st]["face"]
        px0, px1, ptop = STONE[st]["post"]
        c = g(cx, cy + STONE[st]["rim"])
        post = g((px0 + px1) / 2.0, ptop)
        print('  "%s": {"centre": Vector2(%.1f, %.1f), "radius": Vector2(%.1f, %.1f), "post": Vector2(%.1f, %.1f)},'
              % (st, c[0], c[1], rx * TRACK * scale, ry * TRACK * scale, post[0], post[1] + 1))
    write_building_size("powder_mill", tuple(sizes[0]))
    # the build icon: the built mill on the Cottage icon's frame
    icon = np.asarray(Image.open("assets/icons/cottage.png").convert("RGBA")).copy()
    inner = icon[6, 6].copy()
    icon[4:60, 4:60] = inner
    b = imgs[0]
    s = 54.0 / max(b.shape[0], b.shape[1])
    pic = snap_banner(shrink(b, s, 0.45))
    h, w = pic.shape[:2]
    oy, ox = 5 + (54 - h) // 2, 5 + (54 - w) // 2
    m = pic[..., 3] > 0
    icon[oy:oy + h, ox:ox + w][m] = pic[m]
    Image.fromarray(icon).save("assets/icons/powder_mill.png")
    horse_strips()
    runner()


if __name__ == "__main__":
    main()
