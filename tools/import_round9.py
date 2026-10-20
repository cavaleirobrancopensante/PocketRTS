"""Round 9 art: the Clockwork Tesla Cart as a four-legged spider cart.

Source (generated sheet, 1536x1024, flat slate background):
  art/clockwork/tesla_spider.png  five rows = directions s, se, e, ne, n top to bottom;
                                  per row, groups left to right:
                                    WALK      6 frames (s, se, n), 5 (e, ne)
                                    IDLE      3
                                    DEPLOY    5 (s, se, n), 4 (e, ne) - the coil mast
                                              rising out of the body
                                    DEPLOYED  4 (sparks around the brass sphere)
                                    ATTACK    4 (s, se), 3 (e, ne, n)
                                    DEATH     4 (ending in a smoking wreck)
                                  The sheet also carries text: column headers with
                                  bracket lines on top and direction labels with arrows
                                  on the left. Both are blanked before cutting
                                  (LABEL_X / LABEL_Y).

The frames are cut and converted with the round 4 machinery (tools/import_round4.py:
slate mask with shadow handling, glow (zaps, sparks) un-blended from the slate, box-filter
shrink, team reds snapped to #FF0000 / #960000, specks and slate fringe removed) using
round 8's seam cuts (tools/import_round8.py: the spider legs touch between frames, so the
cuts follow the emptiest path instead of a straight column). The seams are searched close
to the gap between two bodies (found at body height, above the legs: body_gaps, or read
off the sheet: CUT_GUESS) on the mask closed up and down, so they cannot slide along the
slate between a body and its legs. The lightning of the attack
frames reaches sideways over the next frames' coils: everything inside the BOLTS
rectangles goes to the frame that fires it (the rectangles stop above the neighbours'
spheres). The game draws its own lightning from the coil to the target too
(game.gd tesla_zap, from Unit.coil_point()).

One scale for the whole sheet (SCALE): the packed body comes out about a Gearknight's
footprint (~36 px wide, ~49 px high, the old cart was 27-35 x 55 with its coil). Feet
(the middle between the outermost feet, round 8's four_feet) on the anchor. The cell is
fitted to the packed walk / idle frames; the raised coil of deploy / deployed / attack
gets extra rows on top of every strip and the bolts extra columns on the right (unit.gd
keeps the anchor's distance from the strip's bottom; the anchor's x from the left edge is
all that counts across).

Animations (the names unit.gd plays for the tesla_cart): walk and idle while packed,
deploy forward while deploying and reversed while packing, deployed while deployed,
attack when it fires deployed, death.

Output:
  assets/units/tesla_cart/{walk,idle,deploy,deployed,attack,death}_<dir>.png
    (every other strip in that folder is deleted)
  the "tesla_cart" entry of UNITS in scripts/art_data.gd: cell, anchor and frames replaced
  (or the entry added when tools/import_art.py's rebuild left it out); nothing else in the
  file is touched. Prints the coil sphere's position relative to the anchor per direction
  (for Unit.COIL_TOP in scripts/unit.gd).

tools/import_art.py no longer builds the tesla_cart (its old sheet,
art/clockwork/tesla_cart.png, is kept but unused); this runs after the other rounds, see
tools/rebuild_art.sh.

Usage (from the repo root): python3 tools/import_round9.py [--contact DIR] [--debug DIR]
(--contact writes an x3 contact sheet on grass green; --debug draws the seams on the
sheet). Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_round4 as r4  # noqa: E402
import import_round5 as r5  # noqa: E402
import import_round8 as r8  # noqa: E402
from import_cannon2 import bg_mask  # noqa: E402
from import_round4 import F, body_of, steady, to_game  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
DEBUG = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None

KIND = "tesla_cart"
ANIMS = ["walk", "idle", "deploy", "deployed", "attack", "death"]

# ---------------------------------------------------------------- sheet

LABEL_X = 68     # direction labels end at x 61, the first cart starts at 74
LABEL_Y = 74     # header text and bracket lines end at y 71, the first coil starts at 77

SHEET = dict(
    path="art/clockwork/tesla_spider.png", rows=[224, 397, 568, 756],
    groups=["walk", "idle", "deploy", "deployed", "attack", "death"],
    counts=[[6, 3, 5, 4, 4, 4],
            [6, 3, 5, 4, 4, 4],
            [5, 3, 4, 4, 3, 4],
            [5, 3, 4, 4, 3, 4],
            [6, 3, 5, 4, 3, 4]],
    panels=[[LABEL_X, 395, 575, 842, 1055, 1265, 1536],
            [LABEL_X, 398, 575, 844, 1055, 1267, 1536],
            [LABEL_X, 402, 580, 835, 1051, 1267, 1536],
            [LABEL_X, 398, 580, 838, 1060, 1265, 1536],
            [LABEL_X, 394, 579, 847, 1063, 1265, 1536]])

# The painted lightning: (row, group, frame that fires) -> sheet rectangles x0, y0, x1, y1.
# Everything drawn inside goes to that frame (read off the sheet; the rectangles stay
# above / beside the next frames' spheres, the second one takes the bolt's halo hanging
# down beside them). N's bolt goes straight up inside its own column: no entry.
BOLTS = {
    (0, "attack", 1): [(1105, 88, 1212, 125), (1105, 88, 1174, 134)],
    (1, "attack", 1): [(1110, 255, 1212, 298), (1110, 255, 1172, 306)],
    (2, "attack", 0): [(1105, 432, 1226, 468), (1105, 432, 1176, 480)],
    (3, "attack", 0): [(1115, 600, 1226, 650), (1115, 600, 1173, 668)],
}
GLOW_CUT = 0.4   # the bolts' and sparks' dim slate-blue halo is left out (round 4: 0.2)

# Where the frames of a group meet, read off the sheet where the even split guesses wrong
# (the deploy frames grow wider, the death wreck is twice as wide as the burning cart):
# (row, group) -> x between frames; the seam is searched within CUT_REACH of each.
CUT_GUESS = {
    (0, "deploy"): [636, 683, 730, 776],
    (1, "deploy"): [642, 688, 730, 775],
    (2, "deploy"): [648, 698, 750],
    (3, "deploy"): [646, 696, 750],
    (4, "deploy"): [642, 690, 737, 783],
    (0, "attack"): [1117, 1163, 1208],
    (0, "death"): [1328, 1377, 1427],
    (1, "death"): [1345, 1400, 1448],
    (2, "death"): [1343, 1391, 1447],
    (3, "death"): [1343, 1396, 1452],
    (4, "death"): [1336, 1390, 1447],
}
CUT_REACH = 10
GAP_REACH = 6    # the same for the gaps found between the bodies (body_gaps)
BODY_H = 68      # sheet px from the feet to the top of a packed body

SCALE = 0.72     # sheet px -> game px: packed body ~36 x 49, a Gearknight's footprint


def sheet_mask(px):
    """The slate mask with the header and the row labels counted as background."""
    bg, bgc = bg_mask(px)
    bg[:LABEL_Y] = True
    bg[:, :LABEL_X] = True
    return bg, bgc


def extract(kind):
    """Round 8's seam extract plus the BOLTS rectangles (see the docstring)."""
    cfg = r4.SHEETS[kind]
    px = r4.load(cfg["path"])
    bg, bgc = sheet_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 4)[lab - 1] & (lab > 0))
    bands = r4.row_bands(fg, cfg["rows"])
    H, W = fg.shape
    out = {}
    for r, band in enumerate(bands):
        m = fg & band
        ys_band = np.flatnonzero(m.any(1))
        y0, y1 = ys_band.min(), ys_band.max() + 1
        mb = m[y0:y1]
        # the seams run on the mask closed up and down: the slivers of slate between a
        # body and its legs would let a seam slide under the body and give its legs away
        mcost = ndimage.binary_dilation(mb, structure=np.ones((9, 1), bool))
        cuts = []
        first = {}                     # group -> slot of its first frame
        for g, cnt in enumerate(cfg["counts"][r]):
            a, b = cfg["panels"][r][g], cfg["panels"][r][g + 1]
            first[cfg["groups"][g]] = len(cuts)
            guess, reach = CUT_GUESS.get((r, cfg["groups"][g])), CUT_REACH
            if not guess:
                guess, reach = body_gaps(m, a, b, cnt), GAP_REACH
            cc = [a] + guess + [b] if guess else r5.run_cuts(m, a, b, cnt)
            cuts.append(np.full(y1 - y0, a))
            for k in range(1, cnt):
                half = reach if guess else int((cc[k + 1] - cc[k - 1]) * 0.22)
                lo, hi = max(a + 1, cc[k] - half), min(b - 1, cc[k] + half)
                cuts.append(r8.seam(mcost, lo, hi, cc[k]))
        cuts.append(np.full(y1 - y0, W))
        cuts = np.array(cuts)
        if DEBUG:
            r8.SEAMS.setdefault(kind, []).append((y0, cuts[1:-1]))
        yy, xx = np.nonzero(mb)
        slot = (xx[None, :] >= cuts[:, yy]).sum(0) - 1
        nslot = len(cuts) - 1
        lab, n = ndimage.label(mb, structure=np.ones((3, 3)))
        ls = lab[yy, xx]
        mass = np.zeros((n + 1, nslot))
        np.add.at(mass, (ls, slot), 1)
        whole = mass.max(1) >= 0.8 * mass.sum(1)
        own = mass.argmax(1)
        slots = np.full(mb.shape, -1, int)
        slots[yy, xx] = np.where(whole[ls], own[ls], slot)
        for (br, grp, i), rects in BOLTS.items():
            if br != r:
                continue
            for bx0, by0, bx1, by1 in rects:
                sl = (slice(max(0, by0 - y0), max(0, by1 - y0)), slice(bx0, bx1))
                slots[sl] = np.where(mb[sl], first[grp] + i, slots[sl])
        k = 0
        for g, cnt in enumerate(cfg["counts"][r]):
            for i in range(cnt):
                fm = slots == k
                fy, fx = np.nonzero(fm)
                fy0, fy1, fx0, fx1 = fy.min(), fy.max() + 1, fx.min(), fx.max() + 1
                img = px[y0 + fy0:y0 + fy1, fx0:fx1].copy()
                sel = fm[fy0:fy1, fx0:fx1]
                img[~sel] = 0
                img[..., 3] = np.where(sel, 255, 0)
                out.setdefault((r, cfg["groups"][g]), []).append(
                    dict(img=img.astype(np.uint8), x0=fx0, y0=y0 + fy0, x1=fx1, y1=y0 + fy1))
                k += 1
    return out, bgc


def glow_kind(rgb, kind):
    """Round 4's blue light plus the bolts' white core and their dim halo (slate turned
    bluer: b well above r and g, still darker than round 4's test). Without the halo the
    ring around a bolt counts as solid body and stays an opaque dark-blue blob."""
    if kind != "blue":
        return r4_glow(rgb, kind)
    r, g, b = [rgb[..., c].astype(float) for c in range(3)]
    halo = (b - r >= 40) & (b - g >= 20) & (b >= 72)
    white = (rgb.min(-1) >= 200) & (b >= r - 5)
    return r4_glow(rgb, kind) | halo | white


r4_glow = r4.glow_kind


def body_gaps(m, a, b, n):
    """x between the bodies of a group's n frames: the middle of the empty columns between
    them at body height (a band of rows above the legs, which reach under the neighbours,
    and below the coils; a few bands tried from low to high). None unless some band shows
    exactly n bodies."""
    sub = m[:, a:b]
    bot = np.flatnonzero(sub.any(1)).max()
    for lo, hi in ((0.35, 0.7), (0.45, 0.8), (0.55, 0.9)):
        cols = sub[int(bot - BODY_H * hi):int(bot - BODY_H * lo)].any(0)
        runs, x = [], 0
        while x < len(cols):
            if cols[x]:
                s0 = x
                while x < len(cols) and cols[x]:
                    x += 1
                if x - s0 >= 12:
                    runs.append((s0, x))
            else:
                x += 1
        if len(runs) == n:
            return [a + (runs[i][1] + runs[i + 1][0]) // 2 for i in range(n - 1)]
    return None


def register():
    r4.SHEETS["tesla_spider"] = SHEET
    r4.UNITS["tesla_spider"] = dict(scale=SCALE, glow="blue", norm=[])
    r4.extract = extract
    r4.feet = r5.feet
    r4.glow_kind = glow_kind


class Src9(r4.Src):
    """Round 4's Src at one scale (no per-group normalising: the coil is meant to grow),
    the blue light un-blended, feet between the outermost legs."""
    OUTLIER = {}

    def factor(self, r, g):
        return 1.0

    def raw(self, r, g, i, scale):
        img, gl = to_game(self.frames[(r, g)][i]["img"], scale, self.bgc, "blue", GLOW_CUT)
        return F(img, gl, *r8.four_feet(img, gl))


def plan(S):
    """Rows as drawn: 0 = S, 1 = SE, 2 = E, 3 = NE, 4 = N, every group facing its row's
    way (the painted bolts all fly to the right). Walk and idle are held by the body (the
    legs move), the rest by the legs (the coil grows / the sparks change on top). The
    death frames keep their own feet (the cart sinks into a wreck)."""
    A = {}
    for r, d in enumerate(DIRS):
        A["walk", d] = steady(S.seq(r, "walk"), "high")
        A["idle", d] = steady(S.seq(r, "idle"), "high")
        A["deploy", d] = steady(S.seq(r, "deploy"), "low")
        A["deployed", d] = steady(S.seq(r, "deployed"), "low")
        A["attack", d] = steady(S.seq(r, "attack"), "low")
        A["death", d] = S.seq(r, "death")
    return A


def fit_cell(A):
    """Cell around the packed frames (walk, idle): anchor x = the furthest reach to the
    left of the feet over every frame (+1), the cell twice that wide; anchor y = the
    packed body's height above the feet (+1), the cell 2 px deeper than the lowest foot."""
    L = U = D = 0.0
    for (anim, d), fr in A.items():
        for f in fr:
            ys, xs = np.nonzero(f.img[..., 3] > 0)
            L = max(L, f.ax - xs.min())
            D = max(D, ys.max() + 1 - f.ay)
            if anim in ("walk", "idle"):
                U = max(U, f.ay - ys.min())
    ax, ay = int(np.ceil(L)) + 1, int(np.ceil(U)) + 1
    return (2 * ax, ay + int(np.ceil(D)) + 2), (float(ax), float(ay))


def coil_top(f):
    """The glowing sphere on top of the deployed coil, relative to the feet: the biggest
    patch of bright blue-white light above the solid body (the sparks around it are
    thinner and dimmer)."""
    top = np.nonzero(body_of(f.img, f.glow))[0].min()
    rgb = f.img[..., :3].astype(int)
    hot = (f.img[..., 3] > 0) & (rgb[..., 2] >= 200) & (rgb.sum(-1) >= 480)
    hot[top + 3:] = False
    lab, n = ndimage.label(hot, structure=np.ones((3, 3)))
    if not n:
        ys, xs = np.nonzero(body_of(f.img, f.glow))
        return float(np.median(xs[ys == top])) + 0.5 - f.ax, top - f.ay
    big = lab == (np.argmax(ndimage.sum(hot, lab, np.arange(1, n + 1))) + 1)
    ys, xs = np.nonzero(big)
    return xs.mean() + 0.5 - f.ax, ys.mean() + 0.5 - f.ay


# ---------------------------------------------------------------- art_data

def write_entry(cell, anchor, counts):
    """Replace the tesla_cart entry of UNITS (or add it before the end of UNITS)."""
    path = "scripts/art_data.gd"
    src = open(path).read()
    lines = [f'\t"{KIND}": {{"cell": Vector2i({cell[0]}, {cell[1]}), '
             f'"anchor": Vector2({anchor[0]:g}, {anchor[1]:g}), "frames": {{']
    lines += [f'\t\t"{k}": {n},' for k, n in sorted(counts.items())]
    lines.append("\t}},")
    block = "\n".join(lines) + "\n"
    key = '\t"%s": {"cell"' % KIND
    if key in src:
        start = src.index(key)
        end = src.index("\n\t}},\n", start) + len("\n\t}},\n")
    else:
        start = end = src.index("\n}\n", src.index("const UNITS := {")) + 1
    open(path, "w").write(src[:start] + block + src[end:])


def clear_old(keep):
    out = f"assets/units/{KIND}"
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(out)):
        if f.endswith(".png") and f[:-4] not in keep:
            os.remove(os.path.join(out, f))
            if os.path.exists(os.path.join(out, f + ".import")):
                os.remove(os.path.join(out, f + ".import"))
            print(f"  removed old {out}/{f}")


# ---------------------------------------------------------------- contact sheet

def contact(counts, size, anchor):
    os.makedirs(CONTACT, exist_ok=True)
    cw, H = size
    ref = []
    for rk, key in (("gearknight", "idle_s"), ("gearknight", "walk_e")):
        (rcw, _), _ = r8.unit_entry(rk)
        f = r8.old_frames(rk, key, rcw)[0]
        f = np.concatenate([np.zeros((H - f.shape[0], f.shape[1], 4), np.uint8), f], 0)
        ref.append(f)
    lines = [("gearknight\nidle_s/walk_e", ref)]
    for an in ANIMS:
        for d in DIRS:
            key = f"{an}_{d}"
            lines.append((key, r8.frames_of(f"assets/units/{KIND}/{key}.png", cw, counts[key], anchor)))
    r4.contact_sheet(os.path.join(CONTACT, "contact_tesla_cart_round9.png"), lines)


def main():
    register()
    S = Src9("tesla_spider")
    if DEBUG:
        os.makedirs(DEBUG, exist_ok=True)
        r8.debug_seams("tesla_spider")
    A = plan(S)
    cell, anchor = fit_cell(A)
    keys = {f"{a}_{d}" for a, d in A}
    clear_old(keys)
    os.makedirs(f"assets/units/{KIND}", exist_ok=True)
    # write_strips adds the found keys to the existing entry: give it a fresh one first
    write_entry(cell, anchor, {})
    counts, size, strip_anchor = r8.write_strips(KIND, A, cell, anchor)
    write_entry(cell, anchor, counts)
    print("coil sphere relative to the feet (deployed frames, median; as drawn, facing "
          "right) - Unit.COIL_TOP in scripts/unit.gd:")
    for d in DIRS:
        x, y = np.median(np.array([coil_top(f) for f in A["deployed", d]]), 0)
        print(f"  {d}: ({x:.1f}, {y:.1f})")
    if CONTACT:
        contact(counts, size, strip_anchor)


if __name__ == "__main__":
    main()
