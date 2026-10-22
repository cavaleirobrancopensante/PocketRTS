"""The Crown's gate in a north-south palisade line (gate_v_*), seen side-on, from the
designer's sheet art/crown/palisade_gate_v.png (2172x724, flat slate background).

The sheet has six frames left to right, each a N-S palisade line running up the image
with the gate in the middle: the far post (top) and the near post (bottom), each with a
pennant, and the doors between them:

  1 closed   2 half open   3 open   4 damaged (closed, the near post broken and leaning)
  5 construction   6 destroyed

Only frames 1 and 4 can be used whole. In 2 and 3 the doors hang off the middle of the
gateway (and a plank stands in it), and 5 and 6 turn to face the viewer. So every
picture is COMPOSED from parts cut from the sheet, on the game's own layout:

  - the far post (cap and log) with its pennant on a pole, its log ending on the
    gateway's far edge (tile row GAP_TOP);
  - the gateway: the closed doors (frame 1's dark planks, edge on, squeezed to the
    gateway) or, open, nothing: the ground shows through;
  - the near post with its pennant, its cap on the gateway's near edge (GAP_BOT) and its
    foot on the tile's bottom row, where the next tile's stakes stand in front of it
    exactly as stake stands in front of stake in a palisade line;
  - open: the door boards of frame 3, each hinged on its post and standing out of the
    line, the far door to the east (behind the line), the near door to the west (in front
    of it); half open: frame 2's narrower boards, sheared to stand at about 45 degrees
    (the far door's free edge comes toward the viewer, the near door's goes away);
  - damaged: frame 4's posts and splintered doors; open damaged: its posts, frame 3's
    doors;
  - construction: two fresh-cut posts at half height (frame 5's scaffold posts) on dirt and
    frame 5's log pile, no doors yet; destroyed: frame 6's broken stumps at the posts and
    its smashed door boards lying in the gateway.

Scale: the posts are cut at SX (a post 45 sheet px wide -> 10.6 px, a little wider than
the palisade's stakes); along the line the gateway is squeezed to fit one tile. The
picture is GATE_W wide, centred on the tile (the line on its middle column, like the
wall_ns stakes), its bottom row 6 px below the tile (Building.body_offset).

The pennants are snapped to the team key reds (snap_team), the rest unteamed.

Runs after tools/import_palisade.py (it uses its cutting helpers and overwrites the
gate_v_* pictures that one makes). Usage (from the repo root):
  python3 tools/import_palisade_gate_v.py [--contact DIR]
(--contact writes a x4 contact sheet of every gate_v state between wall_ns pieces.)
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load, snap_team, unteam  # noqa: E402
from import_cannon2 import bg_mask, clean, defringe  # noqa: E402
import import_palisade as P  # noqa: E402

SHEET = "art/crown/palisade_gate_v.png"
OUT = "assets/buildings"
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None

TILE = P.TILE
FOOT = P.FOOT
GATE_W = P.GATE_W            # 48
CX = GATE_W // 2             # the line's column
SX = 0.235                   # sheet -> game
# Tile rows (0 = the tile's top edge). The posts stand on the tile's north and south
# edges, as tall as the palisade's stakes and a little more; seen from the south, the
# gateway between them shows over the far post's foot, under the near post's cap. The
# next tile's stakes stand in front of the near post's lower half, as stake does of stake.
FAR_FOOT = 0
NEAR_FOOT = TILE
GAP_TOP = -22                # the far post's log ends here (the doors / the ground below)
GAP_BOT = -8                 # the near post's cap
DOOR_W, DOOR_H = 11, 21      # an open door leaf, game px

# ---- the sheet (boxes are x0, y0, x1, y1; "cx" is the line's centre column per frame)
F1 = {"cx": 180.5,
      "far_flag": (176, 130, 220, 170), "far_post": (150, 176, 208, 251),
      "doors": (150, 251, 208, 372),
      "near_flag": (178, 370, 220, 404), "near_post": (156, 401, 202, 483)}
F4 = {"cx": 1266.5,
      "far_flag": (1262, 130, 1308, 170), "far_post": (1236, 176, 1296, 251),
      "doors": (1222, 251, 1306, 372),
      "near_flag": (1265, 370, 1308, 406), "near_post": (1222, 401, 1306, 489)}
CAP_TIP = {"far": 178, "near": 403}      # sheet rows of the posts' cap tips (cone masks)
CAP_FULL = {"far": 200, "near": 421}     # ... and where the cone is full width
F3_DOORS = {"w": (820, 243, 867, 394), "e": (933, 243, 981, 394)}
F2_DOORS = {"w": (496, 253, 528, 394), "e": (552, 253, 586, 372)}   # (e: above the pennant)
F5_POST = (1568, 204, 1607, 262)         # a fresh-cut scaffold post (flat top)
F5_LOGS = (1655, 370, 1736, 462)         # the log pile
F6_FAR = (1921, 205, 1969, 272)          # a broken stump (jagged top)
F6_NEAR = (1962, 397, 2014, 488)         # the near post broken off
F6_BOARDS = (1968, 304, 2068, 403)       # smashed door boards lying flat

_PX = load(SHEET)
_BG, _BGC = bg_mask(_PX)


# ---------------------------------------------------------------- cutting

def cut(box, mask=None):
    x0, y0, x1, y1 = box
    img = _PX[y0:y1, x0:x1].copy()
    fg = ~_BG[y0:y1, x0:x1]
    if mask is not None:
        fg &= mask
    img[..., 3] = np.where(fg, 255, 0)
    img[img[..., 3] == 0] = 0
    return img.astype(np.uint8)


def to_game(img, w=None, h=None):
    h0, w0 = img.shape[:2]
    out = P.resize(img, w or max(1, round(w0 * SX)), h or max(1, round(h0 * SX)))
    return clean(defringe(out, _BGC))


def cone(box, which):
    """The post's cap is a cone: drop the stakes of the line behind it on either side."""
    x0, y0, x1, y1 = box
    yy, xx = np.mgrid[y0:y1, x0:x1]
    tip, full = CAP_TIP[which], CAP_FULL[which]
    mid = (x0 + x1) / 2
    half = np.where(yy >= full, 99, 3 + (yy - tip) * (x1 - x0) / 2 / max(1, full - tip))
    return (yy >= tip) & (np.abs(xx - mid) <= half)


def pennant(box):
    """The pennant alone (red cloth and its dark outline), team-snapped."""
    img = cut(box)
    rgb = img[..., :3].astype(int)
    red = (rgb[..., 0] > rgb[..., 1] + 45) & (rgb[..., 0] > rgb[..., 2] + 45)
    first = np.nonzero(red.any(0))[0].min()
    red = ndimage.binary_dilation(red, iterations=1) & (img[..., 3] > 0) & (
        red | (rgb.max(-1) < 90))
    red[:, :first] = False           # (not the doors or the post left of the cloth)
    img[~red] = 0
    ys, xs = np.nonzero(red)
    img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return snap_team(to_game(img))


# ---------------------------------------------------------------- composing

ORIGIN = 64                  # the tile's top edge on the working canvas
CANVAS_H = ORIGIN + TILE + FOOT


def canvas():
    return np.zeros((CANVAS_H, GATE_W, 4), np.uint8)


def put(dst, img, x, y):
    """img with its top-left at tile column x, tile row y."""
    y += ORIGIN
    h, w = img.shape[:2]
    sy0, sx0 = max(0, -y), max(0, -x)
    sy1, sx1 = min(h, dst.shape[0] - y), min(w, dst.shape[1] - x)
    if sy1 <= sy0 or sx1 <= sx0:
        return
    src = img[sy0:sy1, sx0:sx1]
    m = src[..., 3] > 0
    dst[y + sy0:y + sy1, x + sx0:x + sx1][m] = src[m]


def put_bottom(dst, img, cx, bottom):
    """img centred on column cx, its last row on tile row bottom - 1."""
    put(dst, img, round(cx - img.shape[1] / 2), bottom - img.shape[0])


def col(frame, sheet_x):
    """The game column of a sheet column of a frame."""
    return CX + (sheet_x - frame["cx"]) * SX


POLE = np.array([[[96, 82, 66, 255]], [[64, 54, 44, 255]]], np.uint8).reshape(1, 2, 4)


def flag_pole(dst, frame, which, top_row, length):
    """A thin pole on the post's cap and the pennant flying from its top."""
    x = round(CX) - 1
    put(dst, np.repeat(POLE, length, 0), x, top_row)
    fl = pennant(frame[f"{which}_flag"])
    put(dst, fl, x + 1, top_row)


def far_post(dst, frame, flag=True):
    box = frame["far_post"]
    img = unteam(to_game(cut(box, cone(box, "far"))))
    top = GAP_TOP - img.shape[0]
    if flag:
        flag_pole(dst, frame, "far", top - 9, 10)
    put(dst, img, round(col(frame, box[0])), top)


def lengthen(img, h, band=(10, 3)):
    """The post's log carried on down to h rows (the sheet hides its foot behind the
    stakes in front): a band of rows near its bottom repeated, its last rows kept."""
    if img.shape[0] >= h:
        return img
    a, b = img.shape[0] - band[0], img.shape[0] - band[1]
    rep = img[a:b]
    mid = np.concatenate([rep] * (1 + (h - img.shape[0]) // len(rep)))[:h - img.shape[0]]
    return np.concatenate([img[:b], mid, img[b:]])


def near_post(dst, frame, flag=True):
    box = frame["near_post"]
    img = unteam(lengthen(to_game(cut(box, cone(box, "near"))), NEAR_FOOT - GAP_BOT))
    if flag:
        flag_pole(dst, frame, "near", GAP_BOT - 7, 8)
    dirt(dst, NEAR_FOOT)
    put(dst, img, round(col(frame, box[0])), GAP_BOT)


def doors_closed(dst, frame):
    box = frame["doors"]
    img = unteam(to_game(cut(box), h=GAP_BOT - GAP_TOP + 1))
    put(dst, img, round(col(frame, box[0])), GAP_TOP)


def passage(dst):
    """The open gateway: trodden ground between the posts (it hides the stakes of the
    line beyond, which the far post's foot would)."""
    d, _ = P.scaled(P.DIRT, P.DIRT[1], P.S_RUN)
    g = P.resize(d, 12, GAP_BOT - GAP_TOP + 2)
    solid = g[..., 3] > 0
    g[~solid, :3] = g[solid, :3].mean(0).astype(np.uint8)      # (holes: the dirt's own colour)
    g[..., 3] = 255
    g[0, :, :3] = (g[0, :, :3] * 0.55).astype(np.uint8)        # the far post's shadow line
    g[:, [0, -1], :3] = (g[:, [0, -1], :3] * 0.75).astype(np.uint8)
    put(dst, unteam(g), CX - 6, GAP_TOP)


def dirt(dst, row, cx=CX):
    d = P.DIRT_IMG
    put(dst, d, round(cx - d.shape[1] / 2), row - d.shape[0] + 2)


def leaf(box, w, h):
    return unteam(to_game(cut(box), w=w, h=h))


def shear(img, dy):
    """The free edge of a leaf moved dy rows (the hinge edge stays): a door at an angle.
    dy > 0 drops the right edge; the hinge is the other edge."""
    h, w = img.shape[:2]
    out = np.zeros((h + abs(dy), w, 4), np.uint8)
    for x in range(w):
        t = x / max(1, w - 1)
        off = round(t * dy) if dy > 0 else round((1 - t) * -dy)
        out[off:off + h, x] = img[:, x]
    return out


# Open, both door leaves hang on the far post and stand square to the line, one each side
# of it, framing the gateway (hung on the near post, a leaf would stand a whole tile lower,
# down among the next tile's stakes, and read as a stray board): the east leaf is drawn
# behind the posts, the west leaf in front of the far post (and behind the near one). Half
# open, at about 45 degrees: narrower, and each leaf's free edge comes toward the viewer.
def open_doors(dst, behind):
    """behind: the east leaf, drawn before the posts; else the west one."""
    if behind:
        put(dst, leaf(F3_DOORS["e"], DOOR_W, DOOR_H), CX + 5, FAR_FOOT + 1 - DOOR_H)
    else:
        put(dst, leaf(F3_DOORS["w"], DOOR_W, DOOR_H), CX - 5 - DOOR_W, FAR_FOOT + 1 - DOOR_H)


SWING = 6                    # half open: a leaf's free edge this many rows below its hinge


def half_doors(dst, behind):
    w = round(DOOR_W * 0.72)
    if behind:
        put(dst, shear(leaf(F2_DOORS["e"], w, DOOR_H), SWING), CX + 4, FAR_FOOT + 1 - DOOR_H)
    else:
        put(dst, shear(leaf(F2_DOORS["w"], w, DOOR_H), -SWING), CX - 4 - w, FAR_FOOT + 1 - DOOR_H)


def gate_closed(frame):
    out = canvas()
    far_post(out, frame)
    doors_closed(out, frame)
    near_post(out, frame)
    return out


def gate_swung(frame, doors):
    out = canvas()
    doors(out, True)
    passage(out)
    far_post(out, frame)
    doors(out, False)
    near_post(out, frame)
    return out


def gate_construction():
    out = canvas()
    post = unteam(to_game(cut(F5_POST), w=10, h=20))
    logs = unteam(to_game(cut(F5_LOGS)))
    dirt(out, FAR_FOOT + 1)
    put_bottom(out, post, CX, FAR_FOOT + 1)
    put_bottom(out, logs, CX + 10, TILE // 2 + 8)
    dirt(out, NEAR_FOOT)
    put_bottom(out, post, CX, NEAR_FOOT)
    return out


def gate_destroyed():
    out = canvas()
    far = unteam(to_game(cut(F6_FAR)))
    near = unteam(to_game(cut(F6_NEAR)))
    boards = unteam(to_game(cut(F6_BOARDS)))
    dirt(out, FAR_FOOT + 1)
    put_bottom(out, far, CX, FAR_FOOT + 1)
    put_bottom(out, boards, CX + 3, TILE // 2 + 8)
    dirt(out, NEAR_FOOT)
    put_bottom(out, near, CX, NEAR_FOOT)
    return out


def build():
    pics = {
        "gate_v_built": gate_closed(F1),
        "gate_v_half": gate_swung(F1, half_doors),
        "gate_v_open": gate_swung(F1, open_doors),
        "gate_v_damaged": gate_closed(F4),
        "gate_v_open_damaged": gate_swung(F4, open_doors),
        "gate_v_construction": gate_construction(),
        "gate_v_destroyed": gate_destroyed(),
    }
    return {k: P.trim(v) for k, v in pics.items()}


# ---------------------------------------------------------------- contact sheet

def stacked(pic, above, below):
    """The gate between wall pieces (from assets/buildings), drawn in y order like the
    game: each picture centred on its tile, its bottom 6 px below it."""
    tiles = [above, pic, below]
    H = 3 * TILE + 80
    W = GATE_W + 8
    img = np.zeros((H, W, 4), np.uint8)
    img[...] = (78, 118, 52, 255)
    img[70::TILE, :, :3] = (70, 108, 46)
    for i, p in enumerate(tiles):
        if p is None:
            continue
        h, w = p.shape[:2]
        bx = W // 2 - w // 2
        by = 70 + (i + 1) * TILE + FOOT - h
        m = p[..., 3] > 0
        img[by:by + h, bx:bx + w][m] = p[m]
    return img


def contact(pics, d):
    from PIL import ImageDraw
    os.makedirs(d, exist_ok=True)
    wall = {n: np.array(Image.open(f"{OUT}/{n}.png").convert("RGBA"))
            for n in ("wall_ns_built", "wall_s_built", "wall_n_built")}
    order = ["gate_v_built", "gate_v_half", "gate_v_open", "gate_v_damaged",
             "gate_v_open_damaged", "gate_v_construction", "gate_v_destroyed"]
    cells = [("wall_ns x3", stacked(wall["wall_ns_built"], wall["wall_ns_built"], wall["wall_ns_built"]))]
    cells += [(n[7:], stacked(pics[n], wall["wall_ns_built"], wall["wall_ns_built"])) for n in order]
    cells += [("built, ends", stacked(pics["gate_v_built"], wall["wall_s_built"], wall["wall_n_built"]))]
    cells += [("alone", stacked(pics["gate_v_built"], None, None))]
    k = 4
    cw, ch = cells[0][1].shape[1] * k + 8, cells[0][1].shape[0] * k + 22
    sheet = Image.new("RGB", (len(cells) * cw, ch), (30, 30, 30))
    dr = ImageDraw.Draw(sheet)
    for i, (n, c) in enumerate(cells):
        im = Image.fromarray(c).resize((c.shape[1] * k, c.shape[0] * k), Image.NEAREST)
        sheet.paste(im, (i * cw + 4, 18))
        dr.text((i * cw + 4, 3), n, fill=(240, 240, 200))
    sheet.save(f"{d}/gate_v_contact.png")
    # the bare pictures at x4
    W = sum(p.shape[1] + 4 for p in pics.values())
    H = max(p.shape[0] for p in pics.values())
    raw = np.zeros((H, W, 4), np.uint8)
    raw[...] = (78, 118, 52, 255)
    x = 0
    for n in order:
        p = pics[n]
        m = p[..., 3] > 0
        raw[H - p.shape[0]:, x:x + p.shape[1]][m] = p[m]
        x += p.shape[1] + 4
    Image.fromarray(raw).resize((W * 4, H * 4), Image.NEAREST).save(f"{d}/gate_v_raw.png")
    print("contact sheet:", f"{d}/gate_v_contact.png")


def main():
    pics = build()
    os.makedirs(OUT, exist_ok=True)
    for n, img in pics.items():
        Image.fromarray(img).save(f"{OUT}/{n}.png")
    if CONTACT:
        contact(pics, CONTACT)
    print("palisade gate_v: %d pictures" % len(pics))


if __name__ == "__main__":
    main()
