"""Splits the Crown Powder Mill's four state sprites into a STRUCTURE and a GROUND layer.

The mill's picture is one piece that y-sorts as the building does, so the dirt track and the
grass edge (which labourers walk on, to the right of the footprint and in front) were drawn
over any unit whose y is above the building's base line. The game now draws
powder_mill_<state>_ground.png as a ground sprite (z_index -1, like the farm field: under
every unit) and powder_mill_<state>.png (the shed, hopper, barrels, banner, piles, millstone,
scaffold: everything that stands) y-sorted as before. Same size, same anchor, the two are
disjoint and together are the old picture pixel for pixel.

The split is geometric (coordinates in the built sprite's px, 124x113, base point column 62,
row 107; the other states by their offset from that base point):
 - built / damaged: the ground is everything except (a) the shed, lean-to and piles (x <= 61,
   y <= 99), (b) the hopper block (x 61..90, y <= 82), (c) the back half of the yard behind the
   millstone (x >= 61, y <= 69; x >= 96, y <= 70: the barrels' feet) and (d) the millstone and
   post (the stone overlay's pixels, grown by one).
 - construction: the ground is the yard right of the crate (x >= 64 from the left, y >= 68) and
   the grass fringe below the piles (y >= 105).
 - destroyed: all rubble is low, so the ground is the track at the right (x >= 76, y >= 52) and
   the fringe (y >= 84).

    python3 tools/split_mill_ground.py     (after import_powder_mill.py and import_mill_chatgpt.py)
Idempotent: if a state's ground file is newer than its structure file, the pair is first put
back together. Needs Pillow and NumPy.
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/buildings")
STATES = ["built", "damaged", "construction", "destroyed"]


def structure_mask(state, shape):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    if state in ("built", "damaged"):
        s = (xx <= 61) & (yy <= 99)
        s |= (xx >= 61) & (xx <= 90) & (yy <= 82)
        s |= (xx >= 61) & (yy <= 69)
        s |= (xx >= 96) & (yy <= 70)
        st = Image.open(os.path.join(OUT, "powder_mill_stone_%s.png" % state)).convert("RGBA")
        a = np.array(st)[:, :, 3] > 0
        if a.shape == s.shape:
            s |= ndimage.binary_dilation(a, iterations=1)
        return s
    if state == "construction":
        return ~((xx >= 64) & (yy >= 68)) & ~(yy >= 105)
    return ~((xx >= 76) & (yy >= 52)) & ~(yy >= 84)


def split(state, full=None):
    p = os.path.join(OUT, "powder_mill_%s.png" % state)
    g = os.path.join(OUT, "powder_mill_%s_ground.png" % state)
    if full is None:
        full = Image.open(p).convert("RGBA")
        if os.path.exists(g) and os.path.getmtime(g) >= os.path.getmtime(p):
            full.alpha_composite(Image.open(g).convert("RGBA"))
        full = np.array(full)
    s = structure_mask(state, full.shape[:2])
    vis = full[:, :, 3] > 0
    stru = full.copy()
    stru[~s] = 0
    grnd = full.copy()
    grnd[s] = 0
    Image.fromarray(stru).save(p)
    Image.fromarray(grnd).save(g)
    print("%s: %d structure px, %d ground px" % (state, int((vis & s).sum()), int((vis & ~s).sum())))


if __name__ == "__main__":
    for st in STATES:
        split(st)
