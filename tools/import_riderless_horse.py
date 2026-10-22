"""The riderless horse (TEMPORARY art until the designer's own sheet comes): cut from the GRAY
section of the designer's horse sheet (art/crown/horse_coats.png, copied as
art/crown/horses_riderless_draft.png), which has standing, walking, galloping and special poses
in rough facings. Usable frames are picked by hand (boxes below), keyed out of the slate
background, scaled so the horse matches the Horseman's / Cuirassier's horse, and placed on one
cell with their hooves on the anchor line:

  idle_s   standing (head-on) frames          walk_se  the walking row (3/4 view)
  idle_se  one walking frame, standing        walk_e   the gallop row (side view), slowed down
  idle_e   the saddled profile               death_e  rearing, falling, lying

The north-facing views fall back to these in the game (Unit._set_anim). The saddle cloth's
reds are snapped to the team key reds. Horse coat masks: tools/import_horse_coats.py
(its "horse" entry; run after this).

Output: assets/units/horse/<anim>_<dir>.png and the "horse" entry of scripts/art_data.gd
(added or replaced; nothing else is touched).
Usage (from the repo root): python3 tools/import_riderless_horse.py [--contact PNG]
"""
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import shrink, snap_team  # noqa: E402
from import_cannon2 import clean  # noqa: E402

SRC = "art/crown/horse_coats.png"
DRAFT = "art/crown/horses_riderless_draft.png"
OUT = "assets/units/horse"
ART_DATA = "scripts/art_data.gd"
CELL = (64, 56)
ANCHOR = (32, 52)
# the horse's height (ground to ears) on the Horseman's sprites: ~38 px side on
SCALE = 0.8
SADDLED_SCALE = 0.52     # the saddled profile is drawn bigger on the sheet

# (x0, y0, x1, y1) boxes on the sheet, GRAY section
GRAY_STAND = [(101, 731, 135, 784), (138, 731, 165, 784), (168, 731, 194, 784), (198, 731, 225, 784)]
GRAY_WALK = [(305, 734, 340, 783), (341, 735, 374, 783), (374, 734, 409, 783), (409, 734, 442, 783),
             (443, 734, 476, 783), (475, 734, 508, 783), (508, 734, 540, 783), (541, 734, 572, 783)]
GRAY_GALLOP = [(678, 736, 720, 782), (723, 736, 770, 782), (772, 735, 819, 782), (819, 735, 866, 782),
               (864, 736, 911, 782), (909, 735, 957, 782), (956, 734, 1001, 781), (1005, 735, 1046, 782)]
GRAY_SADDLED = [(1430, 741, 1511, 813), (1430, 830, 1511, 902)]
GRAY_DEATH = [(1225, 739, 1272, 795), (1272, 756, 1326, 794), (1332, 764, 1399, 792)]

STRIPS = {
    "idle_s": (GRAY_STAND[1:3], SCALE),
    "idle_se": ([GRAY_WALK[0]], SCALE),
    "walk_se": (GRAY_WALK, SCALE),
    "idle_e": (GRAY_SADDLED, SADDLED_SCALE),
    "walk_e": (GRAY_GALLOP, SCALE),
    "death_e": (GRAY_DEATH, SCALE),
}


def key_out(px, box):
    x0, y0, x1, y1 = box
    sub = px[y0 - 2:y1 + 2, x0 - 2:x1 + 2].astype(int)
    border = np.concatenate([sub[0], sub[-1], sub[:, 0], sub[:, -1]])
    bg = np.median(border[:, :3], 0)
    d = np.abs(sub[..., :3] - bg).max(-1)
    fg = d > 22
    # the biggest piece (and what touches it): no neighbour's hoof or ear
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=1))
    if n > 1:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg &= lab == (int(np.argmax(sizes)) + 1)
    fg = ndimage.binary_fill_holes(fg) & (d > 10) | fg
    out = np.zeros(sub.shape[:2] + (4,), np.uint8)
    out[..., :3] = sub[..., :3]
    out[..., 3] = np.where(fg, 255, 0)
    return out


def place(img):
    """Put one scaled frame on the cell: centred, hooves on the anchor line."""
    cell = np.zeros((CELL[1], CELL[0], 4), np.uint8)
    ys, xs = np.nonzero(img[..., 3])
    if len(ys) == 0:
        return cell
    img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = img.shape[:2]
    x = ANCHOR[0] - w // 2
    y = ANCHOR[1] - h + 1
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww = min(w - sx0, CELL[0] - dx0)
    hh = min(h - sy0, CELL[1] - dy0)
    part = img[sy0:sy0 + hh, sx0:sx0 + ww]
    m = part[..., 3] > 0
    cell[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
    return cell


def write_art_data(counts):
    src = open(ART_DATA).read()
    lines = ['\t"horse": {"cell": Vector2i(%d, %d), "anchor": Vector2(%g, %g), "frames": {' % (CELL + ANCHOR)]
    for k in sorted(counts):
        lines.append('\t\t"%s": %d,' % (k, counts[k]))
    lines.append("\t}},\n")
    block = "\n".join(lines)
    m = re.search(r'\t"horse": \{"cell".*?\n\t\}\},\n', src, re.S)
    if m:
        src = src[:m.start()] + block + src[m.end():]
    else:
        m = re.search(r'\t"horseman": \{"cell".*?\n\t\}\},\n', src, re.S)
        src = src[:m.end()] + block + src[m.end():]
    open(ART_DATA, "w").write(src)


def main():
    if not os.path.exists(DRAFT):
        shutil.copyfile(SRC, DRAFT)
    px = np.asarray(Image.open(DRAFT).convert("RGB"))
    os.makedirs(OUT, exist_ok=True)
    counts = {}
    strips = {}
    for name, (boxes, scale) in STRIPS.items():
        frames = []
        for b in boxes:
            img = key_out(px, b)
            img = shrink(img, scale)
            img = clean(img)
            img = snap_team(img)
            frames.append(place(img))
        strip = np.concatenate(frames, 1)
        Image.fromarray(strip).save(os.path.join(OUT, name + ".png"))
        counts[name] = len(frames)
        strips[name] = strip
        print(name, len(frames))
    write_art_data(counts)
    if "--contact" in sys.argv:
        path = sys.argv[sys.argv.index("--contact") + 1]
        W = max(s.shape[1] for s in strips.values())
        sheet = Image.new("RGBA", (W * 3, len(strips) * CELL[1] * 3), (104, 132, 84, 255))
        for i, s in enumerate(strips.values()):
            im = Image.fromarray(s).resize((s.shape[1] * 3, s.shape[0] * 3), Image.NEAREST)
            sheet.alpha_composite(im, (0, i * CELL[1] * 3))
        sheet.save(path)


if __name__ == "__main__":
    main()
