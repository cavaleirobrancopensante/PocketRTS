"""Technical clean-ups from the Clockwork animation audit (docs/animation_audit_clockwork.md). Safe to run again: every
step leaves an already clean picture as it is. Run it after tools/import_clock_soldier.py, tools/soldier_guide/shield.py
or tools/import_tier3.py (they make the strips it cleans).

1. Stray specks: pixel islands of 1 to 3 px lying 3 px or more from the figure, in the strips that are not deaths (a
   death's flying gears and bolts are meant). Found by tools/anim_audit/measure_clockwork.py in the Clock Soldier's walk_ne
   and SHIELD FORWARD strips (guard, guard_walk) and the Pendulum's swings.
2. The Clock Aviary's working loop (assets/buildings/cuckoo_house_work_0..3.png): the four frames were painted one by one,
   so the whole tower "boiled" (2,400 to 3,900 px changed between frames, about a third of the tower) and starting or
   stopping work popped from the built picture. Every frame is now the built picture with only what is meant to move put
   back from its own frame: the doors (the box round them, where the frame differs clearly from the built picture) and
   the bird once it is out in the air.

Before/after GIFs of every fix of the audit: python3 tools/anim_audit/before_after.py (old files from git).
  python3 tools/anim_audit/fix_clockwork.py
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPECK_STRIPS = {  # kind: (cell width, [strip names])
    "clock_soldier": (78, ["walk_ne", "guard_e", "guard_s", "guard_se", "guard_n", "guard_ne", "guard_sw", "guard_w",
                           "guard_nw", "guard_walk_e", "guard_walk_s", "guard_walk_se", "guard_walk_ne", "guard_walk_n",
                           "guard_walk_sw", "guard_walk_w", "guard_walk_nw"]),
    "pendulum": (130, ["attack_l_n", "attack_r_se", "attack_l_s", "attack_l_se", "attack_l_e", "attack_l_ne",
                       "attack_r_s", "attack_r_e", "attack_r_ne", "attack_r_n"]),
}
AVIARY_DOORS = (62, 50, 94, 80)      # x0, y0, x1, y1 in the 138 x 144 picture: the doors and the bird's perch
AVIARY_FRAMES = 4


def despeck(cell):
    a = cell[..., 3] > 0
    lab, n = ndi.label(a, structure=np.ones((3, 3)))
    if n <= 1:
        return cell, 0
    sizes = ndi.sum(a, lab, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    dist = ndi.distance_transform_edt(lab != big)
    out = cell.copy()
    gone = 0
    for i in range(1, n + 1):
        if i == big or sizes[i - 1] > 3:
            continue
        m = lab == i
        if dist[m].min() >= 3:
            out[m] = 0
            gone += int(m.sum())
    return out, gone


def fix_specks():
    for kind, (cw, names) in SPECK_STRIPS.items():
        for nm in names:
            p = os.path.join(ROOT, "assets/units/%s/%s.png" % (kind, nm))
            if not os.path.exists(p):
                continue
            im = np.array(Image.open(p).convert("RGBA"))
            n = im.shape[1] // cw
            total = 0
            for i in range(n):
                c, g = despeck(im[:, i * cw:(i + 1) * cw])
                im[:, i * cw:(i + 1) * cw] = c
                total += g
            if total:
                Image.fromarray(im, "RGBA").save(p)
                print("%s %s: %d speck px removed" % (kind, nm, total))


def fix_aviary():
    base = os.path.join(ROOT, "assets/buildings/cuckoo_house_")
    built = np.array(Image.open(base + "built.png").convert("RGBA")).astype(int)
    x0, y0, x1, y1 = AVIARY_DOORS
    for i in range(AVIARY_FRAMES):
        p = base + "work_%d.png" % i
        w = np.array(Image.open(p).convert("RGBA")).astype(int)
        out = built.copy()
        box = np.zeros(built.shape[:2], bool)
        box[y0:y1, x0:x1] = True
        m = box & (np.abs(w - built).sum(-1) > 90)
        m = ndi.binary_closing(m, iterations=2) & box
        m = ndi.binary_dilation(m, iterations=1) & box
        out[m] = w[m]
        # the bird out in the air (outside the tower's own outline)
        air = (built[..., 3] == 0) & (w[..., 3] > 0)
        lab, n = ndi.label(air)
        if n:
            sz = ndi.sum(air, lab, range(1, n + 1))
            for j in range(n):
                if sz[j] >= 20:
                    out[lab == j + 1] = w[lab == j + 1]
        if not np.array_equal(out, w):
            Image.fromarray(out.astype(np.uint8), "RGBA").save(p)
            print("cuckoo_house work_%d: %d px now from the built picture" % (i, int(np.any(out != w, -1).sum())))


if __name__ == "__main__":
    fix_specks()
    fix_aviary()
