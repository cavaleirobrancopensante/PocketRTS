"""The Field Cannon's crew: two men in every facing and every animation.

The cannon's sheets (tools/import_cannon2.py) draw a different crew in every view: the
limbered gun on the march has two men (one leading the horse, one at the trail), but the
deployed south-east and north guns have three, the south march a third man's helmet sticking
up behind the horse, and the reload (tools/import_reload.py) adds its rammer on top of the
idle crew. This pass makes it two everywhere:

  walk / deploy / idle / fire (run after import_cannon2.py, before import_reload.py):
    se  idle, fire, deploy's last frame: the man standing behind the gun goes
    n   idle, fire, deploy frames 1-4: the left-hand man goes
    se, e, ne  deploy frames 2-3 (the gun swung round through the south / north view while
        the march's horse leader takes the horse off): one man of that gun goes
    s   walk, deploy frames 0-3: the man leading the horse (only his helmet shows, over
        the horse's head) goes; the gun's breech, or the deployed gun, is drawn where it was
  reload (import_reload.py calls reload_room() on the idle gun before adding the rammer):
    the rammer takes the place of one more man - s: the left man, se: the left man,
    e: the upright man behind the trail, ne: the man standing behind the barrel, n: the
    right-hand man.

Each man is a polygon in cell px (the published cell, 165x129, anchor 73, 89); in the parts
where he overlaps the gun (`guard`), the gun's bronze and wood are kept. Erasing is
idempotent, so the pass can run again on its own output.

Usage (from the repo root): python3 tools/fix_cannon_crew.py   (tools/rebuild_art.sh)
"""
import os

import numpy as np
from PIL import Image, ImageDraw

OUT = "assets/units/cannon"
CELL = (165, 129)

# (polygon, guard box (x0, y0, x1, y1) in which gun-coloured pixels stay, or None)
MEN = {
    "se_back": ([(50, 31), (70, 31), (77, 45), (77, 60), (67, 60), (66, 63), (53, 63), (53, 44), (50, 44)],
                (50, 57, 80, 66)),
    "se_left": ([(29, 42), (53, 42), (53, 61), (51, 63), (51, 85), (29, 85)], (47, 60, 54, 86)),
    "n_left": ([(39, 35), (57, 35), (57, 51), (61, 57), (61, 65), (57, 66), (56, 79), (39, 79)],
               (54, 62, 62, 80)),
    "n_right": ([(82, 34), (108, 34), (108, 58), (101, 58), (101, 81), (90, 81), (90, 62), (82, 58)],
                (80, 60, 93, 82)),
    "s_left": ([(38, 38), (61, 38), (61, 62), (56, 62), (56, 81), (38, 81)], (54, 60, 62, 82)),
    "s_right": ([(87, 38), (103, 38), (112, 50), (112, 59), (104, 61), (104, 82), (91, 82), (91, 62),
                 (87, 62)], None),
    "e_back": ([(49, 47), (58, 47), (58, 62), (59, 69), (55, 71), (49, 71)], (54, 60, 60, 72)),
    "e_legs": ([(49, 80), (60, 78), (60, 90), (49, 90)], (49, 78, 60, 83)),
    "ne_back": ([(63, 31), (86, 31), (86, 55), (79, 58), (64, 58)], (63, 53, 86, 59)),
}
# (animation strip, frames (None: all), men erased)
STRIPS = [
    ("idle_se", None, ["se_back"]),
    ("fire_se", None, ["se_back"]),
    ("deploy_se", [4], ["se_back"]),
    ("idle_n", None, ["n_left"]),
    ("fire_n", None, ["n_left"]),
    ("deploy_n", [1, 2, 3, 4], ["n_left"]),
    # the side views unlimber through the south / north gun while the horse is led off by
    # the man who led it on the march: one gun man less in those two frames
    ("deploy_se", [2, 3], ["s_right"]),
    ("deploy_e", [2, 3], ["s_right"]),
    ("deploy_ne", [2, 3], ["n_left", "n_right"]),
]
REMOVE_FOR_RAMMER = {"s": ["s_left"], "se": ["se_left"], "e": ["e_back", "e_legs"],
                     "ne": ["ne_back"], "n": ["n_right"]}
# South march: the man leading the horse shows only as a helmet over the horse's head, under
# the breech of the gun (towed muzzle first, away from the camera). Where the gun is behind it
# (the march, and the deploy while the horse is still hitched) the barrel's last rows are
# carried on over it, from row 59 down to the row given; when the horse is led off past the
# deployed gun (deploy 2: over the east gun, 3: over the south gun), the box round the
# helmet shows that idle frame instead.
BREECH = {("walk_s", None): 66, ("deploy_s", 0): 66, ("deploy_s", 1): 70}
BREECH_X, BREECH_SRC = (70, 80), (52, 59)
LEADER = {("deploy_s", 2): ((82, 67, 91, 73), "idle_e"), ("deploy_s", 3): ((87, 69, 96, 76), "idle_s")}


def gunlike(img):
    """Bronze and wood (the barrel, carriage and wheels)."""
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (img[..., 3] > 0) & (r > 70) & (r > g + 12) & (g > b + 10) & (r - b > 40)


def man_mask(key):
    pts, guard = MEN[key]
    im = Image.new("L", CELL, 0)
    ImageDraw.Draw(im).polygon(pts, fill=1)
    return np.array(im).astype(bool), guard


def erase(cell, keys):
    """cell: one frame (h, w, 4) in cell px; the men `keys` erased (in place)."""
    for key in keys:
        m, guard = man_mask(key)
        if guard:
            x0, y0, x1, y1 = guard
            keep = np.zeros_like(m)
            keep[y0:y1, x0:x1] = True
            m &= ~(keep & gunlike(cell))
        cell[m] = 0
    return cell


def breech(cell, y1):
    """The helmet behind the horse becomes the gun's breech (rows 59 to y1)."""
    x0, x1 = BREECH_X
    s0, s1 = BREECH_SRC
    rows = cell[s0:s1, x0:x1].copy()
    for k, y in enumerate(range(s1, y1)):
        cell[y, x0:x1] = rows[k % len(rows)]
    # the dark carriage either side of it
    cell[s1:y1, x0 - 1] = cell[s1:y1, x0 - 2]
    cell[s1:y1, x1] = cell[s1:y1, x1 + 1]
    return cell


def unled(cell, box, under):
    """The box round the helmet shows the frame `under` (the deployed gun) instead."""
    x0, y0, x1, y1 = box
    cell[y0:y1, x0:x1] = under[y0:y1, x0:x1]
    return cell


def reload_room(d, img):
    """The idle gun of facing d (a cell-sized RGBA array) with the man the rammer replaces
    erased. Used by import_reload.py."""
    return erase(img.copy(), REMOVE_FOR_RAMMER[d])


def frames_of(strip):
    return [strip[:, k * CELL[0]:(k + 1) * CELL[0]] for k in range(strip.shape[1] // CELL[0])]


def main():
    for name, which, keys in STRIPS:
        path = os.path.join(OUT, f"{name}.png")
        strip = np.array(Image.open(path).convert("RGBA"))
        for k, cell in enumerate(frames_of(strip)):
            if which is None or k in which:
                erase(cell, keys)
        Image.fromarray(strip).save(path)
    for (name, k), y1 in BREECH.items():
        path = os.path.join(OUT, f"{name}.png")
        strip = np.array(Image.open(path).convert("RGBA"))
        for j, cell in enumerate(frames_of(strip)):
            if k is None or j == k:
                breech(cell, y1)
        Image.fromarray(strip).save(path)
    for (name, k), (box, under) in LEADER.items():
        path = os.path.join(OUT, f"{name}.png")
        strip = np.array(Image.open(path).convert("RGBA"))
        ref = frames_of(np.array(Image.open(os.path.join(OUT, f"{under}.png")).convert("RGBA")))[0]
        unled(frames_of(strip)[k], box, ref)
        Image.fromarray(strip).save(path)
    print("cannon crew: two men in every view")


if __name__ == "__main__":
    main()
