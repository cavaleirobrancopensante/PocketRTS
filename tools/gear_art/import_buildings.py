"""Import the painted Cog Press, Mainspring, Movement Works, Regulator, Escapement and Cuckoo House frames (art/clockwork/gear/<kind>_*.png, drawn at 3x on one canvas per kind,
the building's base bottom-centre on the canvas's bottom-centre) into the game's building sprites:
  assets/buildings/<kind>_{built,construction,damaged,destroyed}.png and <kind>_work_0..7.png (the Cuckoo House: 0..3), and
  a 64x64 card portrait assets/icons/<kind>.png (a crop of the built frame).
Every frame of a kind gets the same crop (the union of their boxes, kept symmetric about the canvas's centre line and
down to the canvas's bottom), so the game's bottom-centre anchor (Building.body_offset) holds for all of them.
  python3 tools/gear_art/import_buildings.py [kind ...]      (no kinds: all of them, and the ring strips and floor plate)"""
import sys
from PIL import Image

SRC = 'art/clockwork/gear/'
DST = 'assets/buildings/'
SCALE = 1.0 / 3.0
# (the Regulator, a squat 2x2, a little smaller than 3x so it sits on its footprint; the Cuckoo House, a tall narrow 2x2:
# its stone plinth about as wide as its footprint)
SCALES = {'regulator': 1.0 / 3.5, 'cuckoo_house': 1.0 / 3.3}
# working-loop frames (8 unless said)
WORK = {'cuckoo_house': 4}
KINDS = ('cog_press', 'mainspring', 'movement_works', 'regulator', 'escapement', 'cuckoo_house')
ONLY = [k for k in sys.argv[1:] if k in KINDS]
# Painted reds the team shader would take for its key reds (within 0.08 of 255,0,0 or 150,0,0: scripts/../shaders/team.gdshader)
# and recolour as specks of the side's colour: nudged just off the key (a little green). Only for these kinds (the older
# buildings keep their sprites as they are).
OFF_KEY = ('cuckoo_house',)


def off_key(im):
    import numpy as np
    a = np.array(im).astype(np.float32)
    rgb = a[..., :3] / 255.0
    near = ((np.sqrt(((rgb - [1.0, 0.0, 0.0]) ** 2).sum(2)) < 0.1) | (np.sqrt(((rgb - [150 / 255.0, 0.0, 0.0]) ** 2).sum(2)) < 0.1)) & (a[..., 3] > 0)
    a[near, 1] = np.maximum(a[near, 1], 30.0)
    a[near, 2] = np.maximum(a[near, 2], 18.0)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGBA')
STATES = {'built': 'built', 'construct': 'construction', 'damaged': 'damaged', 'destroyed': 'destroyed'}

for kind in (ONLY or KINDS):
    names = list(STATES) + ['work_%d' % i for i in range(WORK.get(kind, 8))]
    ims = {n: Image.open(SRC + '%s_%s.png' % (kind, n)).convert('RGBA') for n in names}
    W, H = ims['built'].size
    left, top = W, H
    for im in ims.values():
        bb = im.getbbox()
        left = min(left, bb[0], W - bb[2])
        top = min(top, bb[1])
    box = (left, top, W - left, H)
    sc = SCALES.get(kind, SCALE)
    size = (round((box[2] - box[0]) * sc), round((box[3] - box[1]) * sc))
    for n, im in ims.items():
        out = im.crop(box).resize(size, Image.LANCZOS)
        if kind in OFF_KEY:
            out = off_key(out)
        name = STATES.get(n, n)
        out.save(DST + '%s_%s.png' % (kind, name))
    # the portrait: the upper body of the built frame, square
    b = ims['built']
    bb = b.getbbox()
    side = bb[2] - bb[0]
    cy = bb[1] + side // 2
    crop = b.crop((bb[0], max(0, cy - side // 2), bb[2], max(0, cy - side // 2) + side))
    crop.resize((64, 64), Image.LANCZOS).save('assets/icons/%s.png' % kind)
    print(kind, 'crop', box, '->', size)

if ONLY:
    sys.exit(0)

# the gear-ring strips the game rebuilds its rings from (scripts/gear_art.gd): art/ is not exported, so they are copied
import os, shutil
os.makedirs('assets/gear', exist_ok=True)
for f in ('tooth.png', 'band_small.png', 'band_big.png', 'band_tower.png'):
    shutil.copy(SRC + f, 'assets/gear/' + f)

# the FLOOR PLATE under every ring (scripts/gear_art.gd plate()): the round deck of floor_plate_src.png keyed off its
# navy background by a circle fitted to it, cropped to the circle, 512 px, soft 1 px edge
import numpy as np
src = np.array(Image.open(SRC + 'floor_plate_src.png').convert('RGB')).astype(int)
m = np.abs(src - np.array([0, 22, 48])).sum(2) >= 40
ys, xs = np.nonzero(m)
cx, cy = (xs.min() + xs.max() + 1) * 0.5, (ys.min() + ys.max() + 1) * 0.5
rad = ((xs.max() + 1 - xs.min()) + (ys.max() + 1 - ys.min())) * 0.25
box = (int(round(cx - rad)), int(round(cy - rad)), int(round(cx + rad)), int(round(cy + rad)))
plate = Image.open(SRC + 'floor_plate_src.png').convert('RGB').crop(box).resize((512, 512), Image.LANCZOS)
yy, xx = np.mgrid[0:512, 0:512]
d = np.hypot(xx + 0.5 - 256, yy + 0.5 - 256)
alpha = (np.clip(255.5 - d, 0, 1) * 255).astype(np.uint8)
out = np.dstack([np.array(plate), alpha])
Image.fromarray(out, 'RGBA').save('assets/gear/floor_plate.png')
print('floor plate: circle r %.0f at (%.0f, %.0f) -> assets/gear/floor_plate.png' % (rad, cx, cy))
