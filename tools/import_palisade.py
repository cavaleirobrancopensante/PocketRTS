"""The Crown's palisade (kind "wall") and its gate (kind "gate") from the designer's sheet
art/crown/palisade.png (1536x1024, flat navy background):

  row 1  a long left-right run, a front-back piece, a post cluster, four end caps
  row 2  corners, T-junctions and a cross (drawn isometric: not used, see below)
  row 3  the left-right straight: intact, construction, damaged, destroyed
  row 4  the front-back piece in the same four states
  row 5  the gate in a left-right line: closed, half open, open, damaged, construction,
         destroyed
  row 6  the same six gate states for a front-back line: not used (a front-facing gate
         squeezed narrow); the gate in a N-S line (gate_v_*) is drawn side-on by
         tools/import_palisade_gate_v.py from its own sheet

The pieces auto-tile like Age of Empires 2: every wall cell picks a picture by which of
its four neighbours (N, E, S, W) are walls or gates of the same side. The sheet's corners
and junctions are drawn on an isometric diagonal, so they can't meet the game's square
grid; every joined piece is instead COMPOSED from two parts cut from the sheet, which
makes every join seamless by construction:

  - the E-W segment: a one-tile cut (six stakes, gap to gap) from the middle of the long
    run, so it repeats left-right without a seam; a piece with E or W uses its right or
    left half (split at a stake gap near the middle);
  - single stakes from the same run, stacked one behind the other every 8 px for the
    N-S line (the logs receding, like the sheet's front-back piece), each on its patch
    of the run's dirt; the tile's stake at the foot line doubles as the centre post of
    corners, junctions and end caps.

Every stake of the N-S column has its foot inside its own tile, so a column of tiles
(y-sorted, the lower tile drawn last) joins exactly.

Geometry (Defs.TILE = 32; Building.body_offset puts a picture's bottom row 6 px below
the tile's bottom edge, centred): the stakes stand on the tile line y = BASE (20 px down
the tile); the N-S stakes' feet are at 4, 12, 20 (the centre) and 28. Every wall picture
is 32 px wide (neighbours abut exactly) and as tall as it needs (transparent top rows
trimmed, the bottom fixed). Gates are 40 px wide: their posts stand on the tile's edges
and overlap the neighbouring palisade by 4 px (the game draws gates over walls).

Output (assets/buildings):
  wall_<links>_built.png      links = the neighbours joined, in "nesw" order ("n", "es",
                              "nesw", ...), "post" for none: 16 pieces
  wall_ew_<state>.png, wall_ns_<state>.png   construction / damaged / destroyed
  wall_<state>.png            the E-W pictures again (built = the straight): fallbacks
  gate_<state>.png            built (closed), half, open, open_damaged, damaged,
                              construction, destroyed (gate_v_*: import_palisade_gate_v.py)
  assets/icons/wall.png, gate.png

Usage (from the repo root): python3 tools/import_palisade.py [--contact DIR]
(--contact writes a x4 contact sheet of every piece on green, and a mock layout.)
Needs Pillow, NumPy and SciPy.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load, make_icon, snap_team, unteam  # noqa: E402
from import_cannon2 import bg_mask, clean, defringe  # noqa: E402

SHEET = "art/crown/palisade.png"
OUT = "assets/buildings"
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None

TILE = 32
BASE = 20            # the tile row the stakes stand on
FOOT = 6             # pictures reach this far below the tile (Building.body_offset)
STEP = 8             # N-S stakes: one every STEP px down the line
NS_FEET = {"n": [4, 12], "c": [BASE], "s": [28]}

# ---- the sheet: boxes are (x0, y0, x1, y1); "foot" is the sheet row the stakes stand on
RUN = (136, 40, 227, 175)        # six stakes, from one gap to the next: one tile
RUN_FOOT = 152
S_RUN = TILE / (RUN[2] - RUN[0])     # 0.352: the scale of the whole palisade
STAKES = [(148, 167), (166, 184), (209, 228)]   # single stakes in the run (x ranges)
DIRT = (136, 152, 172, 170)      # a patch of the run's ground
POST = (618, 30, 707, 190)       # the post cluster (row 1)
POST_FOOT = 172
# row 3 (E-W states, drawn smaller than row 1: stake 77 px long vs 105): a one-tile window
ROW3_SCALE = S_RUN * 105 / 77
EW_STATES = {"construction": (548, 380, 618, 500), "damaged": (936, 380, 1006, 500),
             "destroyed": (1300, 380, 1370, 500)}
ROW3_FOOT = 470
# row 4 (N-S states): narrow crops, as a front-back piece seen end on
ROW4_SCALE = S_RUN * 105 / 111
NS_STATES = {"construction": (520, 505, 612, 645), "damaged": (858, 505, 950, 645),
             "destroyed": (1268, 505, 1360, 645)}
ROW4_FOOT = 617
# gates: the flag poles (the posts' centres) of each state, which go on the tile's edges
GATE_SY = 0.36
GATE_W = TILE + 16   # posts overhang 4 px each side; the right pennant flies past that
FLAG_W = 26          # sheet px a pennant flies right of its pole's post
GATE_ROWS = {
    "gate": {"y": (640, 805), "foot": 786, "flag_bottom": 677, "poles": {
        "built": (107, 217), "half": (347, 465), "open": (597, 708), "damaged": (833, 944),
        "construction": (1089, 1203), "destroyed": (1371, 1461)}},
}
POST_HALF = 14       # sheet px from a pole to the outside of its post

DIRS = {"n": 1, "e": 2, "s": 4, "w": 8}


# ---------------------------------------------------------------- cutting

_PX = load(SHEET)
_BG, _BGC = bg_mask(_PX)


def cut(box, fill=True):
    x0, y0, x1, y1 = box
    img = _PX[y0:y1, x0:x1].copy()
    fg = ~_BG[y0:y1, x0:x1]
    if fill:
        # pockets of background caught between stakes: wood, not holes
        fg = ndimage.binary_fill_holes(fg)
    img[..., 3] = np.where(fg, 255, 0)
    return img.astype(np.uint8)


def resize(img, w, h):
    """Area-average resize to exactly w x h, premultiplied alpha, hard alpha edge."""
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((w, h), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def scaled(box, foot, sx, sy=None, w=None, fill=True):
    """A sheet box at game scale and the row of the result its stakes stand on."""
    sy = sx if sy is None else sy
    img = cut(box, fill)
    h0, w0 = img.shape[:2]
    out = resize(img, w if w else max(1, round(w0 * sx)), max(1, round(h0 * sy)))
    out = defringe(out, _BGC)
    return out, round((foot - box[1]) * sy)


# ---------------------------------------------------------------- composing

ORIGIN = 64          # the tile's top edge on the working canvas
CANVAS_H = ORIGIN + TILE + FOOT


def canvas(w=TILE):
    return np.zeros((CANVAS_H, w, 4), np.uint8)


def paste(dst, img, x, foot_y, img_foot):
    """Lay img on dst with its foot row on tile row foot_y and its left edge at x."""
    y = ORIGIN + foot_y - img_foot
    h, w = img.shape[:2]
    sy0, sx0 = max(0, -y), max(0, -x)
    sy1, sx1 = min(h, dst.shape[0] - y), min(w, dst.shape[1] - x)
    if sy1 <= sy0 or sx1 <= sx0:
        return
    src = img[sy0:sy1, sx0:sx1]
    m = src[..., 3] > 0
    dst[y + sy0:y + sy1, x + sx0:x + sx1][m] = src[m]


def trim(img):
    """Drop the empty rows on top (the bottom stays: it's the anchor)."""
    rows = np.nonzero(img[..., 3].any(1))[0]
    return img[rows.min():] if len(rows) else img[-1:]


SEG, SEG_FOOT = scaled(RUN, RUN_FOOT, S_RUN, w=TILE)


def _split():
    """The stake gap nearest the middle of the segment (the darkest column by the stakes'
    middles), where a half segment ends."""
    a = SEG_FOOT - 30
    lum = SEG[a:SEG_FOOT - 4, :, :3].astype(float).mean(-1).mean(0)
    return min(range(13, 20), key=lambda x: lum[x])


SPLIT = _split()
STAKE_IMGS = [scaled((x0, RUN[1], x1, RUN[3]), RUN_FOOT, S_RUN) for x0, x1 in STAKES]


def _dirt():
    d, _ = scaled(DIRT, DIRT[1], S_RUN)
    h, w = d.shape[:2]
    # round its corners into a soft patch
    yy, xx = np.mgrid[0:h, 0:w]
    inside = ((xx - (w - 1) / 2) / (w / 2)) ** 2 + ((yy - (h - 1) / 2) / (h / 2 + 0.5)) ** 2 <= 1.15
    d[~inside] = 0
    return d


DIRT_IMG = _dirt()


ZIG = int(os.environ.get("PAL_ZIG", "2"))


def stake(foot_y, i, dst):
    """One stake of the N-S line, its foot on tile row foot_y. The line zigzags a little
    (every other stake ZIG px left / right), like the sheet's front-back piece."""
    img, foot = STAKE_IMGS[i % len(STAKE_IMGS)]
    dx = ZIG if (foot_y // STEP) % 2 else -ZIG
    paste(dst, DIRT_IMG, TILE // 2 - DIRT_IMG.shape[1] // 2, foot_y - 1, 0)
    paste(dst, img, TILE // 2 - img.shape[1] // 2 + dx, foot_y, foot)


def wall_piece(mask):
    n, e, s, w = (bool(mask & DIRS[k]) for k in "nesw")
    out = canvas()
    if mask == 0:
        post, foot = scaled(POST, POST_FOOT, S_RUN)
        paste(out, post, TILE // 2 - post.shape[1] // 2, BASE, foot)
        return trim(out)
    if n:
        for k, fy in enumerate(NS_FEET["n"]):
            stake(fy, k, out)
    if e and w:
        paste(out, SEG, 0, BASE, SEG_FOOT)
    else:
        if w:
            paste(out, SEG[:, :SPLIT + 1], 0, BASE, SEG_FOOT)
        if e:
            paste(out, SEG[:, SPLIT:], SPLIT, BASE, SEG_FOOT)
    if not (e and w):
        stake(BASE, 2, out)              # the centre post (the N-S line's own stake)
    if s:
        stake(NS_FEET["s"][0], 0, out)
    return trim(out)


def links(mask):
    return "".join(k for k in "nesw" if mask & DIRS[k]) or "post"


def ew_state(st):
    out = canvas()
    img, foot = scaled(EW_STATES[st], ROW3_FOOT, ROW3_SCALE, w=TILE)
    paste(out, img, 0, BASE, foot)
    return trim(out)


def ns_state(st):
    out = canvas()
    img, foot = scaled(NS_STATES[st], ROW4_FOOT, ROW4_SCALE)
    paste(out, img, TILE // 2 - img.shape[1] // 2, BASE, foot)
    return trim(out)


def gate_piece(row, st):
    cfg = GATE_ROWS[row]
    pl, pr = cfg["poles"][st]
    sx = TILE / (pr - pl)
    y0, y1 = cfg["y"]
    # the posts and what's between them; to the right only the pennant (above the post)
    box = (pl - POST_HALF, y0, pr + POST_HALF + FLAG_W, y1)
    img = cut(box, fill=False)       # no hole filling: the open gateway shows the ground
    img[cfg["flag_bottom"] - y0:, POST_HALF * 2 + (pr - pl) + 1:] = 0
    h0, w0 = img.shape[:2]
    img = defringe(resize(img, round(w0 * sx), round(h0 * GATE_SY)), _BGC)
    foot = round((cfg["foot"] - y0) * GATE_SY)
    img = clean(img)
    out = canvas(GATE_W)
    # the poles' midpoint on the tile's middle
    paste(out, img, GATE_W // 2 - round(((pl + pr) / 2 - box[0]) * sx), BASE, foot)
    out = unteam(out)
    # the pennants (above the posts' tops) in the team colour
    top = ORIGIN + BASE - round((cfg["foot"] - cfg["flag_bottom"]) * GATE_SY)
    out[:top] = snap_team(out[:top])
    return trim(out)


def gate_open_damaged(row):
    """No such picture on the sheet: the open gate with the damaged gate's posts."""
    op = gate_piece(row, "open")
    dm = gate_piece(row, "damaged")
    h = max(op.shape[0], dm.shape[0])
    a = np.zeros((h, GATE_W, 4), np.uint8)
    b = np.zeros((h, GATE_W, 4), np.uint8)
    a[h - op.shape[0]:] = op
    b[h - dm.shape[0]:] = dm
    mid = GATE_W // 2
    for x0, x1 in ((0, mid - TILE // 2 + 5), (mid + TILE // 2 - 5, GATE_W)):
        a[:, x0:x1] = b[:, x0:x1]
    return trim(a)


# ---------------------------------------------------------------- output

def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img).save(f"{OUT}/{name}.png")


def build():
    pics = {}
    for m in range(16):
        pics[f"wall_{links(m)}_built"] = unteam(wall_piece(m))
    for st in ("construction", "damaged", "destroyed"):
        pics[f"wall_ew_{st}"] = unteam(ew_state(st))
        pics[f"wall_ns_{st}"] = unteam(ns_state(st))
        pics[f"wall_{st}"] = pics[f"wall_ew_{st}"]
    pics["wall_built"] = pics["wall_ew_built"]
    for row in GATE_ROWS:
        for st in GATE_ROWS[row]["poles"]:
            pics[f"{row}_{st}"] = gate_piece(row, st)
        pics[f"{row}_open_damaged"] = gate_open_damaged(row)
    return pics


def icon_art(pics):
    """A short run for the build button: west end, straight, east end."""
    parts = [pics["wall_e_built"], pics["wall_ew_built"], pics["wall_w_built"]]
    h = max(p.shape[0] for p in parts)
    out = np.zeros((h, TILE * 3, 4), np.uint8)
    for i, p in enumerate(parts):
        out[h - p.shape[0]:, i * TILE:(i + 1) * TILE] = p
    return out


def on_green(img, k=4, pad=4):
    h, w = img.shape[:2]
    g = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.uint8)
    g[...] = (78, 118, 52, 255)
    m = img[..., 3] > 0
    g[pad:pad + h, pad:pad + w][m] = img[m]
    return Image.fromarray(g).resize(((w + 2 * pad) * k, (h + 2 * pad) * k), Image.NEAREST)


def contact(pics, d):
    os.makedirs(d, exist_ok=True)
    from PIL import ImageDraw
    names = sorted(pics)
    k = 4
    cells = [(n, on_green(pics[n], k)) for n in names if not (n.startswith("wall_") and n.count("_") == 1)]
    cw = max(c.width for _, c in cells) + 8
    ch = max(c.height for _, c in cells) + 22
    cols = 8
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * ch), (30, 30, 30))
    dr = ImageDraw.Draw(sheet)
    for i, (n, c) in enumerate(cells):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.paste(c, (x + 4, y + 18 + (ch - 22 - c.height)))
        dr.text((x + 4, y + 3), n, fill=(240, 240, 200))
    sheet.save(f"{d}/contact.png")
    print("contact sheet:", f"{d}/contact.png")
    mock(pics, d)


MOCK = [
    "...............",
    ".#######..#....",
    ".#.....#..#....",
    ".#..#..G..#.#.#",
    ".#.###.#..#....",
    ".#..#..#.#g#...",
    ".###H###..#....",
    "..........#....",
]


def mock(pics, d):
    """A test layout on grass, drawn in y order like the game: # wall, G closed gate,
    H open gate (both drawn E-W), g gate in a N-S line."""
    rows, cols = len(MOCK), len(MOCK[0])
    W, H = cols * TILE, rows * TILE + 40
    img = np.zeros((H, W, 4), np.uint8)
    img[...] = (78, 118, 52, 255)
    img[40::TILE, :, :3] = (70, 108, 46)
    img[40:, ::TILE, :3] = (70, 108, 46)

    def at(x, y):
        return 0 <= y < rows and 0 <= x < cols and MOCK[y][x] != "."
    for y in range(rows):
        for x in range(cols):
            ch = MOCK[y][x]
            if ch == ".":
                continue
            if ch == "#":
                # (as Game.wall_links: walls join every way, a gate along its line: E-W
                # gates G, H east and west, N-S gates g north and south)
                m = sum(DIRS[k] for k, (dx, dy) in zip("nesw", ((0, -1), (1, 0), (0, 1), (-1, 0)))
                        if at(x + dx, y + dy) and (MOCK[y + dy][x + dx] == "#"
                                                   or (k in "ew") == (MOCK[y + dy][x + dx] != "g")))
                p = pics[f"wall_{links(m)}_built"]
            else:
                p = (np.array(Image.open(f"{OUT}/gate_v_built.png").convert("RGBA")) if ch == "g"
                     else pics["gate_open" if ch == "H" else "gate_built"])
            h, w = p.shape[:2]
            bx = x * TILE + TILE // 2 - w // 2
            by = 40 + (y + 1) * TILE + FOOT - h
            for yy in range(h):
                for xx in range(w):
                    if p[yy, xx, 3] and 0 <= bx + xx < W:
                        img[by + yy, bx + xx] = p[yy, xx]
    Image.fromarray(img).resize((W * 3, H * 3), Image.NEAREST).save(f"{d}/mock.png")
    print("mock layout:", f"{d}/mock.png")


def main():
    pics = build()
    for n, img in pics.items():
        save(img, n)
    make_icon(icon_art(pics), "wall")
    make_icon(pics["gate_built"], "gate")
    if CONTACT:
        contact(pics, CONTACT)
    print("palisade: %d pictures" % len(pics))


if __name__ == "__main__":
    main()
