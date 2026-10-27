"""The HEAVY WORKS (owner, 2026-10-27; docs/gear_rules.md): cut the top row of the owner's ChatGPT sheet
art/redraws/heavy_works_empty_chatgpt.png (navy background; built, under construction, damaged, destroyed: the bottom row's
winding key is badly drawn and is not used) into the 3x canvases tools/gear_art/import_buildings.py imports
(art/clockwork/gear/heavy_works_{built,construct,damaged,destroyed}.png, the base's bottom-centre on the canvas's
bottom-centre), and turn the winch house's painted key in code from the BUILT frame, as the Movement Works' key is
(tools/press_anim/movement_works_key.py): the bow is cut out, the shaft continued up under it, and the bow pasted back
squeezed by |cos| of its angle (flipped past the edge-on point, a little darker edge-on): 8 frames of a half turn
(heavy_works_work_0..7.png; the bow looks the same after half a turn). The bay is EMPTY on purpose: the game draws the
machine in training there (scripts/heavy_works.gd). Code-drawn: docs/art_style_inconsistency.md.
  python3 tools/press_anim/heavy_works_key.py && python3 tools/gear_art/import_buildings.py heavy_works"""
import math
import numpy as np
from PIL import Image, ImageEnhance

SHEET = 'art/redraws/heavy_works_empty_chatgpt.png'
OUT = 'art/clockwork/gear/heavy_works_%s.png'
CELL = (384, 512)
STATES = ['built', 'construct', 'damaged', 'destroyed']
# the key on the BUILT frame, in sheet px: the bow's box and its turning axis; the shaft under it
BOW = (38, 197, 100, 237)
AX = 69
SHAFT = (66, 238, 82, 244)         # a slice of the shaft below the bow, repeated up under it
N = 8

sheet = Image.open(SHEET).convert('RGB')
bg = np.array(sheet).astype(int)[4, 4]


def keyed(im):
    a = np.array(im).astype(int)
    d = np.abs(a - bg).sum(2)
    alpha = np.clip((d - 22) / 26.0, 0.0, 1.0)
    out = np.dstack([a, (alpha * 255).astype(int)]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


def canvas(cell_im):
    """The keyed cell moved so its bottom-centre (the box's middle, its lowest opaque row) is the canvas's bottom-centre."""
    a = np.array(cell_im)[..., 3] > 40
    ys, xs = np.nonzero(a)
    cx = (xs.min() + xs.max() + 1) / 2.0
    bottom = ys.max() + 1
    W = 384
    out = Image.new('RGBA', (W, bottom + 2), (0, 0, 0, 0))
    out.paste(cell_im, (int(round(W / 2 - cx)), 2), cell_im)
    return out, int(round(W / 2 - cx))


cells = {}
shift = {}
for i, st in enumerate(STATES):
    cell = keyed(sheet.crop((i * CELL[0], 0, (i + 1) * CELL[0], CELL[1])))
    cv, dx = canvas(cell)
    cells[st] = cv
    shift[st] = dx
    cv.save(OUT % st)
    print(st, 'canvas', cv.size, 'shift', dx)

# the crane's CHAIN and HOOK come off the built frame (and the work frames made from it): the game draws them
# (scripts/heavy_works.gd: lowered over the machine in training, at rest where they were painted when idle). Cut at
# 1/3 like the building: assets/buildings/heavy_works_hook.png and heavy_works_chain.png (a tile of the painted links).
built = keyed(sheet.crop((0, 0, CELL[0], CELL[1])))
HOOK = (218, 211, 244, 250)
CHAIN = (226, 150, 237, 186)        # (a run of whole links, repeated down)
ERASE = (216, 143, 246, 251)
hook = built.crop(HOOK)
chain = built.crop(CHAIN)
hook.resize((round(hook.width / 3), round(hook.height / 3)), Image.LANCZOS).save('assets/buildings/heavy_works_hook.png')
chain.resize((round(chain.width / 3), round(chain.height / 3)), Image.LANCZOS).save('assets/buildings/heavy_works_chain.png')
b = np.array(built)
b[ERASE[1]:ERASE[3], ERASE[0]:ERASE[2]] = 0
built = Image.fromarray(b, 'RGBA')
cv = Image.new('RGBA', cells['built'].size, (0, 0, 0, 0))
cv.paste(built, (shift['built'], 2), built)
cv.save(OUT % 'built')
b = np.array(built)
bow = built.crop(BOW)
base = b.copy()
base[BOW[1]:BOW[3], BOW[0]:BOW[2]] = 0          # (the bow out: transparent)
shaft = b[SHAFT[1]:SHAFT[3], SHAFT[0]:SHAFT[2]].copy()
h = SHAFT[3] - SHAFT[1]
for y in range(BOW[1] + 18, BOW[3], h):        # (the shaft carried up under the bow, to its middle)
    hh = min(h, BOW[3] - y)
    seg = shaft[:hh]
    region = base[y:y + hh, SHAFT[0]:SHAFT[2]]
    m = seg[..., 3:4] > 0
    base[y:y + hh, SHAFT[0]:SHAFT[2]] = np.where(m, seg, region)
base_im = Image.fromarray(base, 'RGBA')
for i in range(N):
    th = math.pi * i / N
    c = math.cos(th)
    w = max(0.13, abs(c))
    bw = max(3, int(round(bow.width * w)))
    bi = bow.resize((bw, bow.height), Image.LANCZOS)
    if c < 0:
        bi = bi.transpose(Image.FLIP_LEFT_RIGHT)
    rgb = ImageEnhance.Brightness(bi.convert('RGB')).enhance(0.78 + 0.22 * abs(c))
    bi = Image.merge('RGBA', (*rgb.split(), bi.split()[3]))
    f = base_im.copy()
    f.alpha_composite(bi, (int(round(AX - bw / 2)), BOW[1]))
    cv = Image.new('RGBA', cells['built'].size, (0, 0, 0, 0))
    cv.paste(f, (shift['built'], 2), f)
    cv.save(OUT % ('work_%d' % i))
print('work frames', N)
