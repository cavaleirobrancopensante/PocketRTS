"""The Crown Mortar's crew: two men in every animation and facing, and no flag.

The mortar's sheets (tools/import_round10.py) draw a different crew in every view: the
deployed gun in idle and reload has two men, but firing it has three, the packed mortar
standing still three (with a small red pennant on a pole stuck in its pack), setting it up
three or four (the pennant on the cart, then planted by the bed), and the death throws in a
third man or leaves one. The towed walk (tools/import_mortar_walk.py) has two, one leading
the horse and one behind; the Field Cannon was put at two in tools/fix_cannon_crew.py. This
pass makes the mortar two everywhere, and takes the pennant out of every frame:

  walk, reload    two already (nothing to do)
  idle            n frame 0: the pennant over the right-hand man
  fire            the man furthest left goes (one man either side of the mortar stays)
  idle_packed     the man behind the left-hand man goes (the horse's leader on the right and
                  the man in front stay); the pennant on its pack
  deploy          0-2: the man standing off to the left goes (one at the cart, one leading
                  the horse; from the north-east/north where nobody leads it, the two at the
                  cart); 3-4: the pair working off to the left go, so the man crouched at the
                  bed and the man leading the horse off (fading out with it in 4) are the two;
                  5 (= idle): two. The pennant goes from the cart, the horse's pack and the
                  bed (the red cloth on the cart is filled in from the cart round it).
  death           0: a third man lying in front goes (from s, se and n); 1: the man knocked
                  down lies there instead (from se f0 where the facing has none of its own),
                  so two men show; 2: two already; 3: the wreck. The pennant goes from 0-2.

Every edit is a box in cell px (the mortar's 158 x 91 cell, anchor 79, 78):
  X  cut everything in the box (except `keep` boxes)
  C  cut the connected pieces lying wholly inside the box (a man standing on his own)
  R  cut the reds (the pennant's cloth) in the box, and the dark outline left round them
  F  fill the reds in the box from the nearest other colour (cloth lying on the cart)
  P  paste a piece of a frame (of the strips as they were before this pass) under this one
Specks left by a cut are swept up afterwards. Idempotent: run again on its own output it
changes nothing (cuts of nothing; pastes of what is already there).

Runs after import_round10.py, import_reload.py, fix_helmets.py and import_mortar_walk.py and
before import_horse_coats.py (tools/rebuild_art.sh), which masks the horse on what is left.

Usage (from the repo root): python3 tools/fix_mortar_crew.py
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = "assets/units/mortar"
CELL = (158, 91)
DIRS = ["s", "se", "e", "ne", "n"]


def X(x0, y0, x1, y1, keep=()):
    return ("X", (x0, y0, x1, y1), keep)


def C(x0, y0, x1, y1):
    return ("C", (x0, y0, x1, y1))


def R(x0, y0, x1, y1):
    return ("R", (x0, y0, x1, y1))


def F(x0, y0, x1, y1):
    return ("F", (x0, y0, x1, y1))


def L(x0, y0, x1, y1, w=1.3):
    """Cut a pole: the pixels within w px of the line from (x0, y0) to (x1, y1)."""
    return ("L", (x0, y0, x1, y1), w)


def P(strip, frame, box, to):
    """Paste box of (strip, frame) with its corner at `to`, under what is drawn there."""
    return ("P", strip, frame, box, to)


SE_BODY = P("death_se", 0, (44, 70, 64, 88), (44, 70))
N_BODY = P("death_n", 0, (96, 72, 116, 90), (96, 72))

# {strip: {frame (None: all): [edits]}}
EDITS = {
    # ------------------------------------------------------------- fire
    **{f"fire_{d}": {None: [C(0, 0, 50, 91)]} for d in DIRS},
    # ------------------------------------------------------------- idle
    "idle_n": {0: [X(78, 30, 92, 49)]},
    # ------------------------------------------------------------- idle_packed
    "idle_packed_s": {0: [X(48, 30, 59, 45), X(59, 30, 67, 75)]},
    "idle_packed_se": {0: [X(46, 30, 62, 49)]},
    "idle_packed_e": {0: [X(36, 48, 52, 80), X(47, 48, 54, 56)]},
    "idle_packed_ne": {0: [X(50, 32, 66, 49), R(60, 42, 66, 58), X(88, 36, 100, 49), R(86, 38, 98, 54)]},
    "idle_packed_n": {0: [X(86, 33, 91, 51), X(90, 33, 97, 40)]},
    # ------------------------------------------------------------- deploy
    "deploy_s": {
        0: [X(25, 30, 50, 85), X(46, 60, 57, 69), X(57, 44, 63, 51), R(57, 44, 66, 51), F(89, 39, 100, 49)],
        # the pair at the left (the one in front half hidden by the one behind) -> the man
        # standing in the same place in frame 2
        1: [X(35, 33, 60, 82), X(58, 62, 64, 75), P("deploy_s", 2, (40, 36, 62, 82), (40, 36)),
            F(102, 34, 114, 50)],
        2: [X(78, 35, 94, 42), R(78, 35, 93, 47), X(79, 35, 82, 45)],
        3: [X(10, 40, 52, 82)],
        4: [X(10, 40, 50, 82)],
    },
    "deploy_se": {
        0: [X(25, 30, 62, 85), X(50, 36, 64, 47), X(50, 68, 62, 78), R(56, 39, 68, 47), R(76, 36, 88, 45),
            X(84, 36, 92, 41), R(93, 38, 100, 52), X(93, 38, 100, 46), X(79, 39, 83, 44), X(62, 46, 66, 48),
            X(55, 71, 76, 80)],
        1: [C(20, 30, 70, 85), X(72, 37, 80, 49), R(72, 38, 81, 49), F(104, 36, 116, 44)],
        2: [X(28, 35, 71, 82), R(83, 37, 97, 49), X(76, 36, 80, 47), X(84, 38, 96, 46), X(60, 44, 71, 53),
            X(60, 70, 71, 80)],
        3: [X(10, 40, 57, 71), X(10, 71, 53, 82), X(62, 43, 72, 61)],
        4: [X(10, 40, 57, 71), X(10, 71, 53, 82), X(62, 43, 72, 61)],
    },
    "deploy_e": {
        0: [X(25, 35, 52, 85), X(50, 38, 66, 50), X(50, 50, 57, 52), X(70, 36, 83, 47), R(68, 36, 85, 51)],
        1: [C(15, 30, 64, 85), R(87, 38, 101, 52), X(88, 38, 92, 52), X(86, 38, 97, 48)],
        2: [X(40, 30, 66, 80)],
        3: [X(10, 35, 40, 82), X(40, 58, 46, 76), X(84, 45, 116, 82)],
        4: [X(10, 35, 40, 82), X(40, 58, 46, 76), X(83, 45, 112, 82)],
    },
    "deploy_ne": {
        0: [X(58, 42, 67, 51), F(60, 38, 96, 70)],
        1: [X(25, 30, 56, 85), X(56, 78, 59, 85)],
        2: [X(30, 40, 62, 80), X(55, 44, 64, 57), X(55, 57, 62, 70), X(70, 44, 77, 51)],
        3: [X(10, 40, 52, 82)],
        4: [X(10, 40, 52, 82)],
    },
    "deploy_n": {
        0: [X(25, 30, 55, 85), X(97, 36, 104, 49), X(93, 49, 101, 68), F(78, 37, 97, 51)],
        1: [X(25, 30, 60, 82)],
        2: [R(68, 40, 76, 47)],
        3: [X(10, 40, 53, 82), X(54, 45, 64, 63)],
        4: [X(10, 40, 53, 82), X(54, 45, 64, 63)],
        5: [X(78, 30, 92, 49)],
    },
    # ------------------------------------------------------------- death
    # (the pennant flies from a pole stuck in the gun: its cloth and the pole down to the gun)
    "death_s": {
        0: [X(45, 68, 64, 86)],
        1: [P("death_s", 0, (45, 68, 64, 86), (45, 68)), X(62, 49, 79, 59), X(63, 59, 72, 62),
            L(77, 57, 82, 63)],
        2: [X(76, 46, 88, 59), X(74, 50, 78, 61), X(80, 43, 85, 47)],
    },
    "death_se": {
        0: [X(44, 70, 64, 88)],
        1: [SE_BODY, X(60, 47, 74, 58), X(68, 44, 74, 48), L(70, 58, 70, 63)],
        2: [X(69, 46, 80, 59), L(79, 53, 79, 61)],
    },
    "death_e": {
        1: [SE_BODY, X(63, 48, 80, 58), X(64, 57, 72, 59), X(80, 55, 83, 58), L(78, 57, 82, 62)],
        2: [X(69, 45, 83, 59)],
    },
    "death_ne": {
        1: [SE_BODY, X(66, 50, 80, 59), X(66, 59, 77, 62), X(78, 57, 83, 65), L(76, 58, 80, 64)],
        2: [X(66, 50, 80, 62), X(64, 60, 71, 67), X(69, 47, 73, 51)],
    },
    "death_n": {
        0: [X(96, 72, 116, 90), X(84, 47, 97, 57), X(90, 56, 97, 59), X(108, 54, 120, 66)],
        1: [N_BODY, SE_BODY, X(61, 49, 72, 59), X(60, 58, 70, 60), L(67, 58, 67, 62)],
        2: [X(60, 49, 70, 61), X(60, 60, 63, 63), X(63, 46, 67, 50), L(68, 52, 77, 61, 1.6)],
    },
}


def reddish(cell):
    rgb = cell[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # the key reds and their shading: green and blue both low and alike (the chestnut horse
    # and the wood have far more green than blue)
    return (cell[..., 3] > 0) & (r >= 90) & (g <= 0.3 * r) & (b <= 0.35 * r) & (np.abs(g - b) <= 30)


def dark(cell):
    return (cell[..., 3] > 0) & (cell[..., :3].astype(int).max(-1) < 70)


def box_mask(box):
    x0, y0, x1, y1 = box
    m = np.zeros((CELL[1], CELL[0]), bool)
    m[max(0, y0):y1, max(0, x0):x1] = True
    return m


def frames_of(strip):
    return [strip[:, k * CELL[0]:(k + 1) * CELL[0]] for k in range(strip.shape[1] // CELL[0])]


def apply(cell, edit, before):
    """One edit on a cell (in place). Returns the mask of pixels it touched."""
    kind = edit[0]
    a = cell[..., 3] > 0
    if kind == "X":
        m = box_mask(edit[1]) & a
        for k in edit[2]:
            m &= ~box_mask(k)
        cell[m] = 0
        return box_mask(edit[1])
    if kind == "L":
        (x0, y0, x1, y1), w = edit[1], edit[2]
        yy, xx = np.mgrid[0:CELL[1], 0:CELL[0]].astype(float)
        dx, dy = x1 - x0, y1 - y0
        t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / max(dx * dx + dy * dy, 1e-6), 0, 1)
        m = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy)) <= w
        cell[m & a] = 0
        return m
    if kind == "C":
        inside = box_mask(edit[1])
        lab, n = ndimage.label(a, structure=np.ones((3, 3)))
        m = np.zeros_like(a)
        for i in range(1, n + 1):
            piece = lab == i
            if not (piece & ~inside).any():
                m |= piece
        cell[m] = 0
        return m
    if kind == "R":
        box = box_mask(edit[1])
        m = reddish(cell) & box
        # the dark outline round the cloth, where nothing but the cloth was next to it
        ring = ndimage.binary_dilation(m, structure=np.ones((3, 3))) & dark(cell) & box & ~m
        rest = a & ~m & ~ring
        lone = ring & (ndimage.convolve(rest.astype(int), np.ones((3, 3), int), mode="constant") <= 2)
        m |= lone
        cell[m] = 0
        return box
    if kind == "F":
        box = box_mask(edit[1])
        m = reddish(cell) & box
        if m.any():
            src = a & ~reddish(cell)
            _, (iy, ix) = ndimage.distance_transform_edt(~src, return_indices=True)
            cell[m] = cell[iy[m], ix[m]]
        return box
    if kind == "P":
        _, strip, frame, (x0, y0, x1, y1), (tx, ty) = edit
        src = frames_of(before[strip])[frame][y0:y1, x0:x1]
        dst = cell[ty:ty + (y1 - y0), tx:tx + (x1 - x0)]
        m = (src[..., 3] > 0) & (dst[..., 3] == 0)
        dst[m] = src[m]
        return np.zeros_like(a)
    raise ValueError(kind)


def sweep(cell, touched, min_size=6):
    """Specks (pieces under min_size px) the cuts left, within 2 px of what they touched."""
    near = ndimage.binary_dilation(touched, iterations=2)
    a = cell[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if not n:
        return
    size = ndimage.sum(a, lab, np.arange(1, n + 1))
    for i in np.flatnonzero(size < min_size):
        piece = lab == i + 1
        if (piece & near).all():
            cell[piece] = 0


def outline(cell, was):
    """Where a cut laid bare the edge of what stays (the horse a man stood in front of), that
    edge gets the dark outline the sprites have everywhere else."""
    a = cell[..., 3] > 0
    cut = (was[..., 3] > 0) & ~a
    edge = a & ndimage.binary_dilation(cut) & ~dark(cell)
    cell[edge, :3] = (cell[edge, :3].astype(float) * 0.3).astype(np.uint8)


def main():
    before = {}
    for name in EDITS:
        before[name] = np.array(Image.open(os.path.join(OUT, f"{name}.png")).convert("RGBA"))
    for edits in EDITS.values():
        for e in [e for es in edits.values() for e in es if e[0] == "P"]:
            if e[1] not in before:
                before[e[1]] = np.array(Image.open(os.path.join(OUT, f"{e[1]}.png")).convert("RGBA"))
    for name, per_frame in EDITS.items():
        strip = before[name].copy()
        for k, cell in enumerate(frames_of(strip)):
            todo = per_frame.get(None, []) + per_frame.get(k, [])
            if not todo:
                continue
            was = cell.copy()
            touched = np.zeros(cell.shape[:2], bool)
            for e in [e for e in todo if e[0] != "P"]:
                touched |= apply(cell, e, before)
            sweep(cell, touched)
            outline(cell, was)
            # pastes last: whole men from other frames, already outlined
            for e in [e for e in todo if e[0] == "P"]:
                apply(cell, e, before)
        Image.fromarray(strip).save(os.path.join(OUT, f"{name}.png"))
    # deploy east, frame 1: a second pair stood apart to the left of the cart (4 men in
    # all): only the two at the cart stay
    p = os.path.join(OUT, "deploy_e.png")
    im = np.array(Image.open(p).convert("RGBA"))
    im[:, 158 + 20:158 + 67, 3] = 0
    Image.fromarray(im).save(p)
    print("mortar crew: two men in every view, no pennant")


if __name__ == "__main__":
    main()
