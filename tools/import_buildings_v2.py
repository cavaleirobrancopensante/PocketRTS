"""The Crown's second-generation Town Hall, Barracks and Horse Breeder from
art/crown/buildings_v2/{town_hall,barracks,horse_breeder}.png, each on a dark blue-grey
background. Top row: the building's four states left to right (built, construction, damaged,
destroyed). Bottom row: a part drawn on its own, in 4 frames or states:

- town_hall: a bronze bell on its yoke swinging (straight, tilted, straight, tilted the other
  way). The tower top is an open belfry with the bell space empty: the game hangs the bell
  in its right-hand opening and swings it while the hall trains Labourers
  (Building.BELL_ART). Written: the bell strip (yoke centred and level in every frame, scaled
  to fit the opening) and, per state that keeps the belfry (built, damaged), an overlay of
  the belfry round the opening (its pillars and roof), drawn over the bell.
- barracks: the drill yard on its own (unused: the top row already has it, and nothing of the
  building stands in front of the patch the game's drilling Musketeer stands on, so he is just
  drawn over the body). Written: the Musketeer's aim / fire / reload / idle strips facing east
  (assets/units/musketeer, after tools/import_round10.py and its fixes) shrunk to the
  building's scale, team-coloured as painted (Building.DRILL_ART).
- horse_breeder: the paddock on its own (unused: the game keeps the horses on the back part of
  the paddock, behind the fences' top rails, so nothing is in front of them). Written: the
  riderless horse's idle / walk / graze strips (assets/units/horse, tools/import_horse_units.py)
  and their coat masks (assets/units/horse_masks/horse, tools/import_horse_coats.py) shrunk to
  the building's scale, so the game draws them 1:1 with the coat shader (Building.PADDOCK_ART).

Each state is cut from its quarter of the top row (split at the emptiest column near each
quarter line, since some states touch), the slate keyed out (tools/import_horse_units.py's
test, then the slate-tinted fringe), the slate seen through gaps inside the drawing turned into
a warm shadow (tools/import_powder_mill.py: it would read as a hole into the night), scaled so
the built state is WIDTH px wide (the other states by the same factor; the old sprites were 150,
128 and 132 on footprints of 160, 128 and 128 px), the bottom middle on the building's base
point like every building. Only the banners and flags (red patches of at least BANNER sheet
px) are snapped to the team key reds: the market awning, the target's rings and the saddle
stay as painted. The Horse Breeder's build icon is the built state on the Cottage icon's frame
(the Town Hall's and Barracks' icons are painted separately, art/ui/icons.png: left alone).

The numbers the game needs (from the building's base point) are printed: they go in
Building.BELL_ART, DRILL_ART and PADDOCK_ART.

Output: assets/buildings/{town_hall,barracks,horse_breeder}_{built,construction,damaged,destroyed}.png,
assets/buildings/town_hall_bell.png, assets/buildings/town_hall_belfry_{built,damaged}.png,
assets/buildings/drill_musketeer/<anim>_e.png, assets/buildings/paddock_horse/<anim>_<dir>.png
(+ mask/), assets/icons/horse_breeder.png and BUILDING_SIZE in scripts/art_data.gd.
Usage (from the repo root): python3 tools/import_buildings_v2.py [--contact DIR]
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
from import_powder_mill import slate_to_shadow  # noqa: E402
from import_round12 import write_building_size  # noqa: E402

STATES = ["built", "construction", "damaged", "destroyed"]
WIDTH = {"town_hall": 152, "barracks": 140, "horse_breeder": 136}
# Strays on the sheet erased before cutting (sheet px: x0, y0, x1, y1): a thin line drawn from
# the built Barracks' roof to the scaffolding beside it.
ERASE = {"barracks": [(362, 280, 400, 302)]}
BANNER = 300         # sheet px: a red patch this big is a banner or flag (team-coloured)

# Town Hall: the belfry's right-hand opening per state that keeps it (sheet px: x0, y0, x1, y1,
# between the front and right pillars, from the roof's underside to the parapet), and the box
# round the belfry the overlay is cut from.
OPENING = {"built": (214, 213, 236, 245), "damaged": (967, 238, 991, 268)}
BELFRY = {"built": (150, 190, 262, 252), "damaged": (905, 215, 1015, 275)}
YOKE_OVER = 4         # sheet px: the yoke a little wider than the opening (its ends behind the pillars)

# Barracks: where the drilling Musketeer's feet stand and the target's middle (sheet px)
DRILL = {"built": {"feet": (250, 447), "target": (357, 392)},
         "damaged": {"feet": (1000, 447), "target": (1100, 393)}}
MAN_SCALE = 0.72      # of the Musketeer (34 px cell: about 20 px tall at the barracks)
MAN_ANIMS = ["aim_e", "fire_e", "reload_e", "idle_e"]

# Horse Breeder: the part of the paddock the horses walk (an ellipse on the ground, sheet px:
# centre, radii), behind the fences' top rails and clear of the trough
PADDOCK = {"built": ((243, 466), (62, 15)), "damaged": ((1022, 466), (52, 14))}
HORSE_SCALE = 0.42    # of the riderless horse (98x70 cell)
HORSE_ANIMS = ["idle", "walk", "graze"]
DIRS = ["s", "se", "e", "ne", "n"]


def quarters(fg, n=4):
    """Column ranges of the n states of a row: split at the emptiest column near each line."""
    occ = fg.sum(0)
    w = fg.shape[1]
    cuts = [0]
    for k in range(1, n):
        c = w * k // n
        lo, hi = c - 80, c + 80
        cuts.append(lo + int(np.argmin(occ[lo:hi])))
    cuts.append(w)
    return list(zip(cuts[:-1], cuts[1:]))


def cut(px, fg, bg, y0, y1, x0, x1):
    """The drawing in a slab of the sheet: its biggest piece and the specks inside its box.
    Returns RGBA (sheet scale, slate gaps turned to shadow) and its top-left on the sheet."""
    f = fg[y0:y1, x0:x1]
    f = ndimage.binary_closing(f, iterations=2) | f
    lab, n = ndimage.label(f, structure=np.ones((3, 3)))
    sizes = ndimage.sum(f, lab, range(1, n + 1))
    objs = ndimage.find_objects(lab)
    big = int(np.argmax(sizes))
    b = objs[big]
    m = lab == big + 1
    near = ndimage.binary_dilation(m, iterations=6)
    for k, sl in enumerate(objs):
        if k == big or sizes[k] < 12:
            continue
        cy, cx = (sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2
        # (a stray stroke out in the slate beside the drawing stays out)
        if b[0].start <= cy < b[0].stop and b[1].start <= cx < b[1].stop and (near & (lab == k + 1)).any():
            m |= lab == k + 1
    m = ndimage.binary_fill_holes(m)
    ys, xs = np.nonzero(m)
    ya, yb, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    img = np.zeros((yb - ya, xb - xa, 4), np.uint8)
    img[..., :3] = px[y0 + ya:y0 + yb, x0 + xa:x0 + xb]
    img[..., 3] = np.where(m[ya:yb, xa:xb], 255, 0)
    img = defringe(img, bg)
    img[..., :3] = slate_to_shadow(img[..., :3], bg)
    return img, (x0 + xa, y0 + ya)


def rows_of(fg):
    """The two rows of the sheet: (y0, y1) of the top and bottom one."""
    occ = fg.any(1)
    ys = np.nonzero(occ)[0]
    mid = len(occ) // 2
    # the widest empty band between the drawings, near the middle
    best, by = 0, mid
    y = ys.min()
    while y < ys.max():
        if not occ[y]:
            e = y
            while not occ[e]:
                e += 1
            if e - y > best and abs((y + e) / 2 - mid) < len(occ) * 0.3:
                best, by = e - y, (y + e) // 2
            y = e
        y += 1
    return (0, by), (by, len(occ))


def banners(img):
    """Sheet-scale mask of the banners and flags: red patches of BANNER px or more."""
    c = img[..., :3].astype(int)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    red = (img[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32)
    lab, n = ndimage.label(ndimage.binary_dilation(red, iterations=1))
    if n == 0:
        return np.zeros(red.shape, bool)
    sizes = ndimage.sum(red, lab, range(1, n + 1))
    return (sizes >= BANNER)[lab - 1] & (lab > 0)


def to_game(img, scale):
    """The state at the game's scale, its banners team-coloured and nothing else."""
    small = shrink(img, scale, 0.45)
    h, w = small.shape[:2]
    bm = np.array(Image.fromarray((banners(img) * 255).astype(np.uint8)).resize((w, h), Image.BOX)) >= 40
    bm = ndimage.binary_dilation(bm, iterations=1)
    team = snap_team(small.copy())
    plain = unteam(small.copy())
    return np.where(bm[..., None], team, plain).astype(np.uint8)


def game_xy(st_info, x, y):
    """Sheet px of a state -> game px from the building's base point (the sprite's bottom
    middle is 6 px under it: Building.body_offset)."""
    org, (sw, sh), scale = st_info
    return (-sw / 2.0 + (x - org[0]) * scale, -sh + 6.0 + (y - org[1]) * scale)


def strip_frames(path, cell_w):
    s = np.asarray(Image.open(path).convert("RGBA")).copy()
    return [s[:, i * cell_w:(i + 1) * cell_w] for i in range(s.shape[1] // cell_w)]


def join(frames):
    h = max(f.shape[0] for f in frames)
    w = max(f.shape[1] for f in frames)
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:f.shape[0], i * w:i * w + f.shape[1]] = f
    return out


# ---------------------------------------------------------------- Town Hall's bell

def bell(px, fg, bg, row, info, contact):
    y0, y1 = row
    f = fg[y0:y1]
    lab, n = ndimage.label(ndimage.binary_closing(f, iterations=2) | f, structure=np.ones((3, 3)))
    sizes = ndimage.sum(f, lab, range(1, n + 1))
    objs = sorted([ndimage.find_objects(lab)[i] for i in np.argsort(-sizes)[:4]], key=lambda s: s[1].start)
    frames = []
    for sl in objs:
        img, org = cut(px, fg, bg, y0 + sl[0].start - 2, y0 + sl[0].stop + 2, sl[1].start - 2, sl[1].stop + 2)
        a = img[..., 3] > 0
        # the yoke: the top rows (the beam), its middle and top
        top = np.nonzero(a.any(1))[0][0]
        beam = a[top:top + 12]
        xs = np.nonzero(beam.any(0))[0]
        frames.append((unteam(img), (xs.min() + xs.max()) / 2.0, top, xs.max() - xs.min() + 1))
    yoke_w = max(f[3] for f in frames)
    # one cell, every frame's yoke middle on its centre line and its top on the top row
    half = int(max(max(c, f[0].shape[1] - c) for f in frames for c in [f[1]])) + 1
    hgt = max(f[0].shape[0] - f[2] for f in frames)
    cell = []
    for img, cx, top, _ in frames:
        c = np.zeros((hgt, 2 * half, 4), np.uint8)
        ox = int(round(half - cx))
        sub = img[top:]
        c[:sub.shape[0], ox:ox + sub.shape[1]] = sub
        cell.append(c)
    ox0, oy0, ox1, oy1 = OPENING["built"]
    st_scale = info["built"][2]
    want = (ox1 - ox0 + YOKE_OVER) * st_scale            # the yoke's width in the game
    s = want / yoke_w
    oh = (oy1 - oy0) * st_scale
    if hgt * s > oh - 1:
        s = (oh - 1) / hgt
    small = [unteam(shrink(c, s, 0.4)) for c in cell]
    strip = join(small)
    Image.fromarray(strip).save("assets/buildings/town_hall_bell.png")
    bw, bh = small[0].shape[1], small[0].shape[0]
    print("bell cell %d x %d (4 frames), its pivot (the yoke's top middle) at (%.1f, 0)" % (bw, bh, bw / 2.0))
    for st in ("built", "damaged"):
        ox0, oy0, ox1, oy1 = OPENING[st]
        p = game_xy(info[st], (ox0 + ox1) / 2.0, oy0)
        print('  "%s": Vector2(%.1f, %.1f),' % (st, p[0], p[1] + 1))
        # the belfry round the opening, drawn over the bell (the opening itself left out)
        body = np.asarray(Image.open("assets/buildings/town_hall_%s.png" % st).convert("RGBA"))
        h, w = body.shape[:2]
        bx0, by0, bx1, by1 = BELFRY[st]
        gx0, gy0 = game_xy(info[st], bx0, by0)
        gx1, gy1 = game_xy(info[st], bx1, by1)
        qx0, qy0 = game_xy(info[st], ox0, oy0)
        qx1, qy1 = game_xy(info[st], ox1, oy1)
        # game px from the base point -> the sprite's pixels
        tx, ty = w / 2.0, h - 6.0
        keep = np.zeros((h, w), bool)
        keep[int(gy0 + ty):int(np.ceil(gy1 + ty)), int(gx0 + tx):int(np.ceil(gx1 + tx))] = True
        keep[int(round(qy0 + ty)):int(round(qy1 + ty)), int(round(qx0 + tx)):int(round(qx1 + tx))] = False
        ov = np.where((keep & (body[..., 3] > 0))[..., None], body, 0).astype(np.uint8)
        Image.fromarray(ov).save("assets/buildings/town_hall_belfry_%s.png" % st)
    if contact:
        big = np.array(Image.fromarray(strip).resize((strip.shape[1] * 6, strip.shape[0] * 6), Image.NEAREST))
        Image.fromarray(big).save(os.path.join(contact, "town_hall_bell.png"))


# ---------------------------------------------------------------- Barracks' drilling Musketeer

def drill(info):
    cw = 90
    anchor = (45, 34)
    os.makedirs("assets/buildings/drill_musketeer", exist_ok=True)
    for a in MAN_ANIMS:
        frames = [snap_team(shrink(f, MAN_SCALE, 0.4)) for f in strip_frames("assets/units/musketeer/%s.png" % a, cw)]
        Image.fromarray(join(frames)).save("assets/buildings/drill_musketeer/%s.png" % a)
        sw, sh = frames[0].shape[1], frames[0].shape[0]
        print("drill %s: %d frames of %d x %d" % (a, len(frames), sw, sh))
    print("drill man's feet in his cell: (%.1f, %.1f)" % (anchor[0] * MAN_SCALE, anchor[1] * MAN_SCALE))
    for st, d in DRILL.items():
        f = game_xy(info[st], *d["feet"])
        t = game_xy(info[st], *d["target"])
        print('  "%s": {"feet": Vector2(%.0f, %.0f), "target": Vector2(%.0f, %.0f)},' % (st, f[0], f[1], t[0], t[1]))


# ---------------------------------------------------------------- Horse Breeder's horses

def paddock_horses(info):
    cw = 98
    os.makedirs("assets/buildings/paddock_horse/mask", exist_ok=True)
    for a in HORSE_ANIMS:
        for d in DIRS:
            name = "%s_%s" % (a, d)
            frames = strip_frames("assets/units/horse/%s.png" % name, cw)
            mask = np.asarray(Image.open("assets/units/horse_masks/horse/%s.png" % name).convert("RGB"))
            out, mout = [], []
            for i, f in enumerate(frames):
                sm = snap_team(shrink(f, HORSE_SCALE, 0.4))
                h, w = sm.shape[:2]
                mk = mask[:, i * cw:(i + 1) * cw].astype(np.float32)
                hm = mk[..., 0] > 127
                # the tone and the patches averaged over the horse's own pixels only
                wgt = np.array(Image.fromarray((hm * 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(np.float32) / 255.0
                m = np.zeros((h, w, 3), np.uint8)
                for c in (1, 2):
                    v = np.array(Image.fromarray((mk[..., c] * hm).astype(np.uint8)).resize((w, h), Image.BOX)).astype(np.float32)
                    m[..., c] = np.where(wgt > 0.01, v / np.maximum(wgt, 0.01), 0).clip(0, 255)
                m[..., 0] = np.where((wgt >= 0.5) & (sm[..., 3] > 0), 255, 0)
                out.append(sm)
                mout.append(np.concatenate([m, np.full((h, w, 1), 255, np.uint8)], -1))
            Image.fromarray(join(out)).save("assets/buildings/paddock_horse/%s.png" % name)
            Image.fromarray(join(mout)[..., :3]).save("assets/buildings/paddock_horse/mask/%s.png" % name)
    print("paddock horse cell %d x %d, its hooves at (%.1f, %.1f)" % (out[0].shape[1], out[0].shape[0], 49 * HORSE_SCALE, 66 * HORSE_SCALE))
    for st, (c, r) in PADDOCK.items():
        g = game_xy(info[st], *c)
        s = info[st][2]
        print('  "%s": {"centre": Vector2(%.1f, %.1f), "radius": Vector2(%.1f, %.1f)},' % (st, g[0], g[1], r[0] * s, r[1] * s))


# ---------------------------------------------------------------- main

def building(name, contact):
    px, fg, bg = load("buildings_v2/" + name)
    for x0, y0, x1, y1 in ERASE.get(name, []):
        fg[y0:y1, x0:x1] = False
    top, bottom = rows_of(fg)
    imgs = [cut(px, fg, bg, top[0], top[1], x0, x1) for x0, x1 in quarters(fg[top[0]:top[1]])]
    scale = WIDTH[name] / float(imgs[0][0].shape[1])
    info, sizes, smalls = {}, [], []
    for st, (img, org) in zip(STATES, imgs):
        small = to_game(img, scale)
        Image.fromarray(small).save("assets/buildings/%s_%s.png" % (name, st))
        info[st] = (org, (small.shape[1], small.shape[0]), scale)
        sizes.append(small.shape[1::-1])
        smalls.append(small)
        print("%s %s: %d x %d" % (name, st, small.shape[1], small.shape[0]))
    write_building_size(name, tuple(sizes[0]))
    if name == "town_hall":
        bell(px, fg, bg, bottom, info, contact)
    elif name == "barracks":
        drill(info)
    elif name == "horse_breeder":
        paddock_horses(info)
        # the build icon: the built stable on the Cottage icon's frame
        icon = np.asarray(Image.open("assets/icons/cottage.png").convert("RGBA")).copy()
        icon[4:60, 4:60] = icon[6, 6].copy()
        b = imgs[0][0]
        pic = to_game(b, 54.0 / max(b.shape[0], b.shape[1]))
        h, w = pic.shape[:2]
        oy, ox = 5 + (54 - h) // 2, 5 + (54 - w) // 2
        m = pic[..., 3] > 0
        icon[oy:oy + h, ox:ox + w][m] = pic[m]
        Image.fromarray(icon).save("assets/icons/horse_breeder.png")
    if contact:
        h = max(s.shape[0] for s in smalls)
        sheet = np.zeros((h, sum(s.shape[1] + 8 for s in smalls), 4), np.uint8)
        sheet[...] = (70, 100, 60, 255)
        x = 0
        for s in smalls:
            a = s[..., 3:4] / 255.0
            reg = sheet[h - s.shape[0]:, x:x + s.shape[1]]
            reg[..., :3] = (s[..., :3] * a + reg[..., :3] * (1 - a)).astype(np.uint8)
            x += s.shape[1] + 8
        big = Image.fromarray(sheet).resize((sheet.shape[1] * 3, sheet.shape[0] * 3), Image.NEAREST)
        big.save(os.path.join(contact, "%s.png" % name))


def main():
    contact = None
    if "--contact" in sys.argv:
        contact = sys.argv[sys.argv.index("--contact") + 1]
        os.makedirs(contact, exist_ok=True)
    for name in ("town_hall", "barracks", "horse_breeder"):
        building(name, contact)


if __name__ == "__main__":
    main()
