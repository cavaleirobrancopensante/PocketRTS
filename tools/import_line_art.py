"""Import the Clockwork LINE art sheets (docs/clockwork_line_art_spec.md, prompts in
docs/clockwork_line_art_prompts.md) from art/redraws/ into the game's asset folders.

    python3 tools/import_line_art.py [--src art/redraws] [--out .] [--only tiles,damage,relay,drill,loco,cars]

The real sheets do NOT sit on an exact grid, so every sheet is cut by CONNECTED COMPONENTS: the navy
background (0, 22, 48, tolerance 24) is keyed out, the figures are merged by dilating the mask (so a
building and its smoke, or two halves of a broken pipe, are one piece), tiny blobs are ignored, and the
pieces are sorted into rows and then columns.

  line_tiles.png   15 pieces: EW NS NE ES SW WN T(NES) T(ESW) T(SWN) T(WNE) cross cap(N) cap(E) cap(S) cap(W)
                   -> assets/world/line/tile_<sides>.png, exactly 32x32 game px each. Piece 4 (ES) of the
                   first ChatGPT sheet is a duplicate of piece 5, so ES is made by mirroring SW (MIRROR_ES).
                   Every tile is warped (piecewise, nearest neighbour) so that the end of each arm lies on the
                   tile edge and the arm's centre line passes through the middle of that edge, and the junction
                   is at the tile centre: neighbouring tiles join without seams.
  line_damage.png  EW damaged, EW destroyed, NS damaged, NS destroyed (normalised like the tiles) then 4 steam
                   frames -> assets/world/line/dmg_{ew,ns}_{damaged,destroyed}.png and steam_1..4.png
  line_relay.png   built, construction / damaged, destroyed -> assets/buildings/pressure_relay_<state>.png,
                   the built picture 70 game px wide, the same factor for all four
  line_drill.png   built, construction, damaged, destroyed / 4 working frames -> assets/buildings/ore_drill_<state>.png
                   and ore_drill_working.png (a strip), the built picture 115 px wide
  line_loco.png    rows east, south, north; 4 frames -> assets/units/ore_locomotive/{run,idle}_{e,s,n}.png
                   (the east locomotive 52 px long, one factor for all 12)
  line_cars.png    columns empty ore car, loaded ore car, troop car; rows east, south, north
                   -> assets/units/{ore_car,troop_car}/{empty,full,idle}_{e,s,n}.png (east wagon 44 px long)

Buildings are trimmed to the art (the game stands them by the bottom centre of the picture). Frames of one
animation share one canvas, placed bottom-centre. Missing sheets are skipped (the game draws code art).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

NAVY = np.array([0, 22, 48])
TOL = 24
TILE = 32
TILE_ORDER = ["ew", "ns", "ne", "es", "sw", "nw", "nes", "esw", "nsw", "new", "nesw", "n", "e", "s", "w"]
MIRROR_ES = True            # ES = SW mirrored (the first sheet's piece 4 is a second SW)
ARMS = {"n": (0, -1), "e": (1, 0), "s": (0, 1), "w": (-1, 0)}


def key_out(img):
    a = np.array(img.convert("RGB")).astype(int)
    near = (np.abs(a - NAVY).max(axis=2) <= TOL)
    out = np.dstack([a.astype(np.uint8), np.where(near, 0, 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def pieces(img, merge=14, min_area=900):
    """The figures of a keyed sheet: [(RGBA image of the piece, (x0, y0, x1, y1))], rows then columns."""
    mask = np.array(img.getchannel("A")) > 0
    big = ndimage.binary_dilation(mask, structure=np.ones((3, 3)), iterations=merge)
    lab, n = ndimage.label(big)
    found = []
    for i in range(1, n + 1):
        part = (lab == i) & mask
        if part.sum() < min_area:
            continue
        ys, xs = np.where(part)
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        found.append(box)
    if not found:
        return []
    # rows: pieces whose centres are within half the median height of each other
    hs = sorted(b[3] - b[1] for b in found)
    tol = max(60, hs[len(hs) // 2] * 0.5)
    found.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows, cur = [], [found[0]]
    for b in found[1:]:
        if abs((b[1] + b[3]) / 2 - np.mean([(c[1] + c[3]) / 2 for c in cur])) <= tol:
            cur.append(b)
        else:
            rows.append(cur)
            cur = [b]
    rows.append(cur)
    out = []
    for r in rows:
        for b in sorted(r, key=lambda b: b[0]):
            out.append((img.crop(b), b))
    return out


def shrink(im, f):
    w, h = im.size
    return im.resize((max(1, round(w / f)), max(1, round(h / f))), Image.NEAREST)


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", os.path.relpath(path), im.size)


def common_canvas(frames):
    w = max(f.size[0] for f in frames)
    h = max(f.size[1] for f in frames)
    out = []
    for f in frames:
        cv = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        cv.paste(f, ((w - f.size[0]) // 2, h - f.size[1]))
        out.append(cv)
    return out


def strip(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


# ---------------------------------------------------------------- tiles

def arm_centre(alpha, side):
    """Centre (sheet px) of the arm that leaves the piece on `side`, across its width, from the outermost 8%."""
    h, w = alpha.shape
    if side in ("w", "e"):
        band = max(3, int(w * 0.08))
        cols = alpha[:, :band] if side == "w" else alpha[:, w - band:]
        ys = np.where(cols.any(axis=1))[0]
        return float(ys.mean()) if len(ys) else h / 2
    band = max(3, int(h * 0.08))
    rows = alpha[:band, :] if side == "n" else alpha[h - band:, :]
    xs = np.where(rows.any(axis=0))[0]
    return float(xs.mean()) if len(xs) else w / 2


def half_width(alpha, side):
    h, w = alpha.shape
    if side in ("w", "e"):
        band = max(3, int(w * 0.08))
        cols = alpha[:, :band] if side == "w" else alpha[:, w - band:]
        ys = np.where(cols.any(axis=1))[0]
        return (ys.max() - ys.min() + 1) / 2 if len(ys) else h / 4
    band = max(3, int(h * 0.08))
    rows = alpha[:band, :] if side == "n" else alpha[h - band:, :]
    xs = np.where(rows.any(axis=0))[0]
    return (xs.max() - xs.min() + 1) / 2 if len(xs) else w / 4


def normalise_tile(piece, sides, s0):
    """Warp a cut-out piece onto exactly 32x32 game px. `sides`: the arms ("ew", "nes", "n", ...). s0: the
    game px per sheet px used for a half-axis that has no arm end to anchor it (the cap's dome side)."""
    a = np.array(piece)
    alpha = a[:, :, 3] > 0
    h, w = alpha.shape
    # the junction centre (sheet px): x from the vertical arms' centre lines, y from the horizontal ones'
    xs = [arm_centre(alpha, s) for s in sides if s in "ns"]
    ys = [arm_centre(alpha, s) for s in sides if s in "ew"]
    hw = np.mean([half_width(alpha, s) for s in sides])
    if xs:
        cx = float(np.mean(xs))
    else:
        cx = w / 2.0
    if ys:
        cy = float(np.mean(ys))
    else:
        cy = h / 2.0
    # a cap: the dome end has no arm: the junction sits one pipe half-width inside the dome
    if len(sides) == 1:
        if sides == "n":
            cy = h - hw
        elif sides == "s":
            cy = hw
        elif sides == "w":
            cx = w - hw
        else:
            cx = hw
    half = TILE / 2.0

    def scale(lo_arm, hi_arm, c, size):
        lo = half / max(c, 1.0) if lo_arm else s0
        hi = half / max(size - c, 1.0) if hi_arm else s0
        return lo, hi

    sxl, sxr = scale("w" in sides, "e" in sides, cx, w)
    syt, syb = scale("n" in sides, "s" in sides, cy, h)
    out = np.zeros((TILE, TILE, 4), np.uint8)
    for oy in range(TILE):
        dy = oy + 0.5 - half
        sy = cy + dy / syt if dy < 0 else cy + dy / syb
        iy = int(np.floor(sy))
        if iy < 0 or iy >= h:
            continue
        for ox in range(TILE):
            dx = ox + 0.5 - half
            sx = cx + dx / sxl if dx < 0 else cx + dx / sxr
            ix = int(np.floor(sx))
            if 0 <= ix < w:
                out[oy, ox] = a[iy, ix]
    return Image.fromarray(out, "RGBA")


def tile_scale(plist):
    """Game px per sheet px of the plain straight pieces (the default for dome ends)."""
    vals = []
    for p, box in plist[:2]:
        vals.append(TILE / max(p.size))
    return float(np.mean(vals)) if vals else 1 / 8.0


def do_tiles(src, out):
    img = key_out(Image.open(src))
    pl = pieces(img)
    if len(pl) != 15:
        sys.exit("line_tiles: found %d pieces, expected 15" % len(pl))
    s0 = tile_scale(pl)
    done = {}
    for i, name in enumerate(TILE_ORDER):
        if name == "es" and MIRROR_ES:
            continue
        done[name] = normalise_tile(pl[i][0], name, s0)
    if MIRROR_ES:
        done["es"] = done["sw"].transpose(Image.FLIP_LEFT_RIGHT)
    for name, im in done.items():
        save(im, os.path.join(out, "assets/world/line", "tile_%s.png" % name))


def do_damage(src, out):
    img = key_out(Image.open(src))
    pl = pieces(img, merge=20, min_area=700)
    if len(pl) < 8:
        sys.exit("line_damage: found %d pieces, expected 8" % len(pl))
    names = [("dmg_ew_damaged", "ew"), ("dmg_ew_destroyed", "ew"), ("dmg_ns_damaged", "ns"), ("dmg_ns_destroyed", "ns")]
    for (name, sides), (p, box) in zip(names, pl[:4]):
        save(normalise_tile(p, sides, 1 / 8.0), os.path.join(out, "assets/world/line", name + ".png"))
    steam = [shrink(p, 9.0) for p, box in pl[4:8]]
    for i, f in enumerate(common_canvas(steam)):
        save(f, os.path.join(out, "assets/world/line", "steam_%d.png" % (i + 1)))


# ---------------------------------------------------------------- buildings and units

def do_relay(src, out):
    img = key_out(Image.open(src))
    pl = pieces(img, merge=10)
    if len(pl) != 4:
        sys.exit("line_relay: found %d pieces, expected 4" % len(pl))
    f = pl[0][0].size[0] / 70.0
    for st, (p, box) in zip(["built", "construction", "damaged", "destroyed"], pl):
        save(shrink(p, f), os.path.join(out, "assets/buildings", "pressure_relay_%s.png" % st))


def do_drill(src, out):
    img = key_out(Image.open(src))
    pl = pieces(img, merge=10)
    if len(pl) != 8:
        sys.exit("line_drill: found %d pieces, expected 8" % len(pl))
    f = pl[0][0].size[0] / 115.0
    for st, (p, box) in zip(["built", "construction", "damaged", "destroyed"], pl[:4]):
        save(shrink(p, f), os.path.join(out, "assets/buildings", "ore_drill_%s.png" % st))
    frames = common_canvas([shrink(p, f) for p, box in pl[4:8]])
    save(strip(frames), os.path.join(out, "assets/buildings", "ore_drill_working.png"))


def do_loco(src, out):
    img = key_out(Image.open(src))
    pl = pieces(img, merge=10)
    if len(pl) != 12:
        sys.exit("line_loco: found %d pieces, expected 12" % len(pl))
    east = max(p.size[0] for p, b in pl[:4])
    f = east / 52.0
    small = [shrink(p, f) for p, b in pl]
    w = max(s.size[0] for s in small)
    h = max(s.size[1] for s in small)
    for r, v in enumerate(["e", "s", "n"]):
        frames = []
        for s in small[r * 4:(r + 1) * 4]:
            cv = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            cv.paste(s, ((w - s.size[0]) // 2, h - s.size[1]))
            frames.append(cv)
        save(strip(frames), os.path.join(out, "assets/units/ore_locomotive", "run_%s.png" % v))
        save(frames[0], os.path.join(out, "assets/units/ore_locomotive", "idle_%s.png" % v))
    print("ore_locomotive cell %dx%d anchor (%d, %d)" % (w, h, w // 2, h - 2))


def do_cars(src, out):
    img = key_out(Image.open(src))
    pl = pieces(img, merge=10)
    if len(pl) != 9:
        sys.exit("line_cars: found %d pieces, expected 9" % len(pl))
    east = float(np.mean([p.size[0] for p, b in pl[:3]]))
    f = east / 44.0
    small = [shrink(p, f) for p, b in pl]
    w = max(s.size[0] for s in small)
    h = max(s.size[1] for s in small)
    names = [("ore_car", "empty"), ("ore_car", "full"), ("troop_car", "idle")]
    for r, v in enumerate(["e", "s", "n"]):
        for c, (kind, stem) in enumerate(names):
            s = small[r * 3 + c]
            cv = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            cv.paste(s, ((w - s.size[0]) // 2, h - s.size[1]))
            save(cv, os.path.join(out, "assets/units", kind, "%s_%s.png" % (stem, v)))
    print("cars cell %dx%d anchor (%d, %d)" % (w, h, w // 2, h - 2))


SHEETS = {"tiles": ("line_tiles.png", do_tiles), "damage": ("line_damage.png", do_damage),
          "relay": ("line_relay.png", do_relay), "drill": ("line_drill.png", do_drill),
          "loco": ("line_loco.png", do_loco), "cars": ("line_cars.png", do_cars)}


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(root, "art/redraws"))
    ap.add_argument("--out", default=root)
    ap.add_argument("--only", default=",".join(SHEETS))
    a = ap.parse_args()
    for k in a.only.split(","):
        fn, fnc = SHEETS[k]
        p = os.path.join(a.src, fn)
        if not os.path.exists(p):
            print("skip", fn, "(not found)")
            continue
        fnc(p, a.out)


if __name__ == "__main__":
    main()
