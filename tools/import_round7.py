"""Round 7 art: the Brood Pen, the grub's cocoon animations and the Clockwork / Brood
command icons.

Sources (generated sheets on a flat slate background):
  art/brood/pen_cocoon.png         top row: the Brood Pen built, growing (construction),
                                   damaged, destroyed; rows 2-6: the grub with a cocoon,
                                   one row per direction, groups wrap (5), walk with the
                                   cocoon (6), idle with the cocoon (3), death (5)
  art/ui/commands_clock_brood.png  two rows of six framed command icons (row 1 Clockwork,
                                   row 2 Brood): move, attack, stop, build, gather, repair

The grub frames are cut and converted with the round 4 machinery (tools/import_round4.py:
shadow-aware slate mask, box-filter shrink, team reds snapped to the key colours, specks
and slate fringe removed). They are added to the existing "grub" unit: same cell width
and anchor as the grub's own art (read from scripts/art_data.gd), feet on the anchor.
The cocoon on the grub's back makes these frames taller than the grub's cell: the strips
get extra rows on top (unit.gd keeps the feet on the anchor for strips taller than the
cell, as for the musketeer's aim-up sheet).

Output:
  assets/units/grub/{wrap,carry_cocoon,idle_cocoon,death_cocoon}_<dir>.png
  assets/buildings/brood_pen_{built,construction,damaged,destroyed}.png
  assets/icons/brood_pen.png
  assets/icons/{clockwork,brood}/{move,attack,stop,build,gather,repair}.png (64x64)
  the new keys in the "grub" entry's "frames" of UNITS and "brood_pen" in BUILDING_SIZE
  of scripts/art_data.gd (targeted edits; nothing else in the file is touched)

Usage (from the repo root): python3 tools/import_round7.py [--contact DIR]
(--contact writes x3 contact sheets on grass green). Needs Pillow, NumPy and SciPy.
Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_round4 as r4  # noqa: E402
import import_round5 as r5  # noqa: E402
from import_art import load, make_icon, unteam  # noqa: E402
from import_cannon2 import bg_mask, clean  # noqa: E402
from import_round4 import F, body_of, bob, narrowest, place, steady, to_game  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None

PEN_SHEET = "art/brood/pen_cocoon.png"
ICON_SHEET = "art/ui/commands_clock_brood.png"
UNIT_Y0 = 395            # the grub rows start below the building row


# ---------------------------------------------------------------- the grub sheet

SHEET = dict(path=PEN_SHEET, rows=[123, 238, 355, 475],   # gaps, relative to UNIT_Y0
             groups=["wrap", "carry", "idle", "death"], counts=[[5, 6, 3, 5]] * 5,
             panels=[[0, 430, 890, 1125, 1536]] * 5)
# one scale for the whole sheet (its rows are drawn at the same size): the grub's body
# (without the cocoon) comes out the size of the grub's own sprites (front view ~22 px
# tall, back view ~27)
UNIT = dict(scale=0.4, norm=[])

_load = load
_glow4 = r4.glow_kind


def sheet_load(path):
    px = _load(path)
    return px[UNIT_Y0:] if path == PEN_SHEET else px


def glow_kind(rgb, kind):
    """Round 4's painted-light test plus the violet sparkles of the dissolving cocoon."""
    if kind == "violet":
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        return (b >= g + 35) & (r >= g + 10) & (b >= 110)
    return _glow4(rgb, kind)


def register():
    r4.load = sheet_load
    r4.glow_kind = glow_kind
    r4.column_cuts = r5.run_cuts
    r4.feet = r5.feet
    r4.SHEETS["grub_cocoon"] = SHEET
    r4.UNITS["grub_cocoon"] = UNIT


def cocoon_px(img):
    """The cocoon and its silk: pale lavender / violet pixels."""
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    return (img[..., 3] > 0) & (b >= r + 4) & (b >= g + 8) & (b >= 70)


def tan_px(img):
    """The grub's tan / ochre skin (no crest, no silk, no cocoon)."""
    r, g, b = [img[..., c].astype(int) for c in range(3)]
    return (img[..., 3] > 0) & (r >= g) & (g >= b + 25) & (r >= 90) & (r - g <= 70)


def grub_only(img):
    """The grub without the cocoon: the biggest non-cocoon piece."""
    a = (img[..., 3] > 0) & ~ndimage.binary_dilation(cocoon_px(img), iterations=1)
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if not n:
        return img[..., 3] > 0
    size = ndimage.sum(a, lab, np.arange(1, n + 1))
    return lab == (np.argmax(size) + 1)


def grub_feet(f):
    """Foot point of the grub itself (the cocoon lies on the ground beside it while it is
    being wrapped): bottom of the whole frame, x = middle of the grub's lowest quarter."""
    a = grub_only(f.img)
    ys, xs = np.nonzero(a)
    low = ys >= ys.max() - max(2, (ys.max() - ys.min()) * 0.25)
    g = f.copy()
    g.ax = float(np.median(xs[low])) + 0.5
    allys = np.flatnonzero(body_of(f.img, f.glow).any(1))
    g.ay = float(allys.max() + 1)
    return g


CELL_HALF = 21           # the grub cell's half width (checked against art_data in build_grub)


def wrap_seq(frames):
    """Wrapping: the grub stands still while the silk covers its legs, so the frames are
    held by the centroid of the grub's own pixels (its feet as found in frame 0). The
    cocoon lies beside it, to the right: if it would stick out of the cell, the whole
    animation is moved left as one (the grub then stands a few px left of the anchor)."""
    out = []
    g0 = grub_feet(frames[0])
    c0 = centroid(tan_px(g0.img))
    for f in frames:
        g = grub_feet(f)
        c = centroid(tan_px(f.img))
        g.ax = c[0] + (g0.ax - c0[0])
        out.append(g)
    reach = max(f.img.shape[1] - f.ax for f in out)
    left = max(f.ax for f in out)
    shift = min(max(0.0, reach - CELL_HALF), max(0.0, CELL_HALF - left))
    for g in out:
        g.ax += shift
    return out


def centroid(m):
    ys, xs = np.nonzero(m)
    return xs.mean(), ys.mean()


class Src7(r4.Src):
    OUTLIER = {}

    def raw(self, r, g, i, scale):
        # the dissolving cocoon's sparkles are light over the slate: un-blended
        glow = "violet" if g == "death" and i >= 1 else None
        img, gl = to_game(self.frames[(r, g)][i]["img"], scale, self.bgc, glow)
        return F(img, gl)


def death_seq(S, r):
    """The grub slumps (frames 0-2, feet as usual), then the cocoon bursts into sparkles
    (3-4): those sit on the ground at the middle of what is left."""
    out = []
    fr = S.seq(r, "death")
    for i, f in enumerate(fr):
        if i >= 3:
            a = f.img[..., 3] > 0
            ys, xs = np.nonzero(a)
            solid = np.flatnonzero((f.img[..., 3] == 255).any(1))
            g = f.copy()
            g.ax = (xs.min() + xs.max() + 1) / 2.0
            g.ay = float((solid.max() if len(solid) else ys.max()) + 1)
            out.append(g)
        else:
            out.append(f)
    # the first frames stand where the grub stood: x from the cocoon-less grub's feet
    g0 = grub_feet(out[0])
    for k in range(3):
        out[k] = r4.align(g0, out[k], "low") if k else g0
    return out


def plan(S):
    """Rows: 0 = S, 1 = SE, 2 = E, 3 = NE, 4 = N. None of the rows is a true front view:
    row 0 is a front three-quarter turned slightly further to the camera than row 1, and
    is the S. Idle rows 1-3 all face the camera (front three-quarter): SE keeps row 1;
    E and NE stand in the most upright walk pose of their row with the cocoon bobbing,
    so a grub stopping on its way east doesn't swing round to the camera. Walk frame 0
    of rows 0-3 is a stray pose (the cocoon lifted half on, rows 3: no cocoon at all):
    the walks use frames 1-5. Death keeps every row as drawn (rows 1-3 slump facing the
    camera)."""
    A = {}
    for d, r in zip(DIRS, range(5)):
        A["wrap", d] = wrap_seq(S.seq(r, "wrap"))
        idx = None if r == 4 else [1, 2, 3, 4, 5]
        walk = steady(S.seq(r, "carry", idx), "high")
        A["carry_cocoon", d] = walk
        if d in ("e", "ne"):
            f = narrowest(walk)
            A["idle_cocoon", d] = [f, bob(f, 0.4, 1), f.copy()]
        else:
            A["idle_cocoon", d] = steady(S.seq({"s": 0, "se": 1, "n": 4}[d], "idle"))
        A["death_cocoon", d] = death_seq(S, r)
    return A


# ---------------------------------------------------------------- art_data edits

def grub_entry():
    src = open("scripts/art_data.gd").read()
    m = re.search(r'"grub": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    return (int(m.group(1)), int(m.group(2))), (float(m.group(3)), float(m.group(4)))


def write_grub_frames(counts):
    """Add / replace the given keys in the "grub" entry's frames (re-read right before)."""
    path = "scripts/art_data.gd"
    src = open(path).read()
    start = src.index('\t"grub": {"cell"')
    end = src.index("\n\t}},\n", start) + 1
    block = src[start:end]
    for k, n in sorted(counts.items()):
        line = f'\t\t"{k}": {n},\n'
        pat = re.compile(r'\t\t"' + k + r'": \d+,\n')
        if pat.search(block):
            block = pat.sub(lambda _m: line, block, count=1)
        else:
            block = block + line
    # keep the keys sorted like the generated entries
    head, *lines = block.split("\n")
    lines = [ln for ln in lines if ln]
    block = head + "\n" + "\n".join(sorted(lines)) + "\n"
    open(path, "w").write(src[:start] + block + src[end:])


# ---------------------------------------------------------------- grub out

NEW_ANIMS = ["wrap", "carry_cocoon", "idle_cocoon", "death_cocoon"]


def build_grub():
    S = Src7("grub_cocoon")
    A = plan(S)
    (cw, ch), (ax, ay) = grub_entry()
    # how far the frames reach from the feet
    L = R = U = D = 0
    for fr in A.values():
        for f in fr:
            h, w = f.img.shape[:2]
            L, R = max(L, f.ax), max(R, w - f.ax)
            U, D = max(U, f.ay), max(D, h - f.ay)
    below = ch - ay
    if L > ax + 0.5 or R > cw - ax + 0.5 or D > below + 0.5:
        print(f"  WARNING: cocoon frames reach L{L:.1f} R{R:.1f} D{D:.1f}, cell allows "
              f"L{ax} R{cw - ax} D{below}: clipped")
    extra = max(0, int(np.ceil(U - ay)))
    H = ch + extra
    out = "assets/units/grub"
    counts = {}
    for (anim, d), fr in A.items():
        strip = np.concatenate([place(f, cw, H, ax, ay + extra)[0] for f in fr], 1)
        Image.fromarray(strip).save(f"{out}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(fr)
    print(f"grub cocoon anims: cell {cw}x{ch} anchor ({ax:g}, {ay:g}), strips {cw}x{H} "
          f"({extra} extra rows on top); reach L{L:.1f} R{R:.1f} up {U:.1f} down {D:.1f}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    write_grub_frames(counts)
    return counts, (cw, H), (ax, ay + extra)


# ---------------------------------------------------------------- the pen

PEN = dict(kind="brood_pen", states=["built", "construction", "damaged", "destroyed"],
           panels=[0, 420, 770, 1120, 1536], y1=390)
WARREN_W = 130           # the Warren (also 4x3 tiles) is 130 px wide: same scale


def pen_pictures():
    px = load(PEN_SHEET)
    bg, bgc = bg_mask(px)
    fg = ~bg
    fg[PEN["y1"]:] = False
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 6)[lab - 1] & (lab > 0))
    pics = []
    P = PEN["panels"]
    for a, b in zip(P[:-1], P[1:]):
        m = fg.copy()
        m[:, :a] = False
        m[:, b:] = False
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        img = px[y0:y1, x0:x1].copy()
        img[~m[y0:y1, x0:x1]] = 0
        img[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0)
        # the middle: mass-weighted median column of the biggest piece
        l2, n2 = ndimage.label(m[y0:y1, x0:x1], structure=np.ones((3, 3)))
        big = l2 == (np.argmax(ndimage.sum(l2 > 0, l2, np.arange(1, n2 + 1))) + 1)
        cx = float(np.median(np.nonzero(big)[1])) + 0.5
        pics.append((img.astype(np.uint8), cx))
    return pics, bgc


def build_pen():
    pics, bgc = pen_pictures()
    kind = PEN["kind"]
    scale = WARREN_W / pics[0][0].shape[1]
    out = {}
    for state, (img, cx) in zip(PEN["states"], pics):
        small, _ = to_game(img, scale, bgc, None)
        ys, xs = np.nonzero(small[..., 3] > 0)
        small = small[:ys.max() + 1]
        c = cx * scale
        half = int(np.ceil(max(c - xs.min(), xs.max() + 1 - c)))
        W = 2 * half
        canvas = np.zeros((ys.max() + 1 - ys.min(), W, 4), np.uint8)
        ox = int(round(half - c))
        part = small[ys.min():]
        canvas[:, max(0, ox):ox + part.shape[1]] = part[:, max(0, -ox):W - ox][:, :W - max(0, ox)]
        canvas = clean(canvas, min_size=3, keep_near=1)
        Image.fromarray(canvas, "RGBA").save(f"assets/buildings/{kind}_{state}.png")
        out[state] = canvas
        print(f"{kind}_{state}: {canvas.shape[1]}x{canvas.shape[0]} (scale {scale:.3f})")
    img = pics[0][0]
    icon, _ = to_game(img, 56 / max(img.shape[:2]), bgc, None)
    make_icon(icon, kind)
    r5.flatten_icon(kind)
    r5.write_building_size(kind, out["built"].shape[1::-1])
    return out


# ---------------------------------------------------------------- command icons

COMMANDS = ["move", "attack", "stop", "build", "gather", "repair"]
FACTION_ROWS = ["clockwork", "brood"]


def build_command_icons():
    """Every framed icon cut at its outer outline (the frame's own edge, like the Crown
    set's frame reaching the 64x64 edge), box-shrunk to 64x64, lightly sharpened, fully
    opaque, exact key reds nudged off (icons are not team-coloured)."""
    px = load(ICON_SHEET)
    bg, _ = bg_mask(px)
    lab, n = ndimage.label(~bg, structure=np.ones((3, 3)))
    size = ndimage.sum(~bg, lab, np.arange(1, n + 1))
    objs = ndimage.find_objects(lab)
    boxes = [objs[i] for i in np.argsort(size)[::-1][:12]]
    boxes.sort(key=lambda s: (s[0].start // 150, s[1].start))
    made = {}
    for k, sl in enumerate(boxes):
        faction, name = FACTION_ROWS[k // 6], COMMANDS[k % 6]
        crop = px[sl].astype(np.uint8).copy()
        crop[..., 3] = 255
        # the frame's bevelled corners and its drop shadow show the slate: filled with
        # the frame's black outline, so the icon is a full opaque square like the Crown's
        crop[bg[sl]] = (14, 12, 12, 255)
        im = Image.fromarray(crop, "RGBA").resize((64, 64), Image.BOX)
        im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
        a = np.array(im)
        a[..., 3] = 255
        a = unteam(a)
        os.makedirs(f"assets/icons/{faction}", exist_ok=True)
        Image.fromarray(a, "RGBA").save(f"assets/icons/{faction}/{name}.png")
        made[faction, name] = a
        h, w = crop.shape[:2]
        print(f"icons/{faction}/{name}.png from {w}x{h} at ({sl[1].start}, {sl[0].start})")
    return made


# ---------------------------------------------------------------- contact sheets

def frames_of(path, cw, n, anchor=None):
    strip = np.array(Image.open(path).convert("RGBA"))
    out = []
    for i in range(n):
        fr = strip[:, i * cw:(i + 1) * cw].copy()
        if anchor:
            fr[int(anchor[1]), max(0, int(anchor[0]) - 2):int(anchor[0]) + 3] = (255, 255, 255, 110)
        fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
        fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
        out.append(fr)
    return out


def contacts(counts, size, anchor, pen, icons):
    os.makedirs(CONTACT, exist_ok=True)
    cw, H = size
    ref = []
    for n in ("idle_s", "idle_e", "walk_e", "idle_n"):
        f = frames_of(f"assets/units/grub/{n}.png", cw, 1)[0]
        ref.append(np.concatenate([np.zeros((H - f.shape[0], cw, 4), np.uint8), f], 0))
    lines = [("old grub s/e/\nwalk e/n", ref)]
    for an in NEW_ANIMS:
        for d in DIRS:
            key = f"{an}_{d}"
            lines.append((key, frames_of(f"assets/units/grub/{key}.png", cw, counts[key], anchor)))
    r4.contact_sheet(os.path.join(CONTACT, "contact_grub_cocoon.png"), lines)
    # pen next to the Warren
    imgs = [np.array(Image.open("assets/buildings/warren_built.png").convert("RGBA"))]
    imgs += [pen[s] for s in PEN["states"]]
    Hb = max(x.shape[0] for x in imgs)
    pad = [np.concatenate([np.zeros((Hb - x.shape[0], x.shape[1], 4), np.uint8), x], 0) for x in imgs]
    ic = [np.array(Image.open(f"assets/icons/{k}.png").convert("RGBA")) for k in ("warren", "brood_pen")]
    r4.contact_sheet(os.path.join(CONTACT, "contact_brood_pen.png"),
                     [("warren | built,\nconstr., damaged,\ndestroyed", pad), ("icons", ic)])
    rows = [("crown", [np.array(Image.open(f"assets/icons/{c}.png").convert("RGBA")) for c in COMMANDS])]
    for fct in FACTION_ROWS:
        rows.append((fct, [icons[fct, c] for c in COMMANDS]))
    r4.contact_sheet(os.path.join(CONTACT, "contact_commands.png"), rows)


def main():
    register()
    counts, size, anchor = build_grub()
    pen = build_pen()
    icons = build_command_icons()
    if CONTACT:
        contacts(counts, size, anchor, pen, icons)


if __name__ == "__main__":
    main()
