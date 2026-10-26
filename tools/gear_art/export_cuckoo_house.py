"""Export the Cuckoo House frames from the ChatGPT sheet art/redraws/cuckoo_house.png (1536 x 1024, 4 x 2 cells of
384 x 512, navy background RGB 0,22,48): row 1 BUILT (doors shut), UNDER CONSTRUCTION, DAMAGED, DESTROYED; row 2 four
WORKING frames (the doors open, a little brass bird pops out and flies off) -> art/clockwork/gear/cuckoo_house_{built,
construct,damaged,destroyed,work_0..3}.png on one common canvas (like tools/press_anim/export_building_frames.py), the
building's base at the canvas's bottom centre. tools/gear_art/import_buildings.py then makes the game's sprites.

ChatGPT drew the house at a different place in each cell (the working frames drift up to ~46 px), and the flying bird,
the smoke and the rubble make the bounding boxes useless for lining them up: every frame is aligned on its stone PLINTH
instead (the bottom band of the figure, matched against the built frame's), so the house stands still while the doors
open and the bird flies off.
  python3 tools/gear_art/export_cuckoo_house.py"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = 'art/redraws/cuckoo_house.png'
OUT = 'art/clockwork/gear/'
NAVY = np.array([0, 22, 48])
NAMES = ['built', 'construct', 'damaged', 'destroyed', 'work_0', 'work_1', 'work_2', 'work_3']
BAND = 95          # px of the figure's bottom that is the plinth (the matched band)


def cells():
    rgb = np.array(Image.open(SRC).convert('RGB')).astype(int)
    out = []
    for i in range(8):
        r, c = i // 4, i % 4
        cell = rgb[r * 512:(r + 1) * 512, c * 384:(c + 1) * 384]
        m = np.abs(cell - NAVY).sum(2) >= 40
        lab, n = ndi.label(m)
        sz = ndi.sum(m, lab, range(1, n + 1))
        keep = np.isin(lab, [k + 1 for k, z in enumerate(sz) if z >= 60])
        main = lab == int(np.argmax(sz)) + 1
        o = np.zeros(cell.shape[:2] + (4,), np.uint8)
        o[..., :3] = cell
        o[..., 3] = keep * 255
        out.append((o, main))
    return out


def band(main):
    ys = np.nonzero(main.any(1))[0]
    b = np.zeros_like(main)
    b[ys.max() - BAND:ys.max() + 1] = main[ys.max() - BAND:ys.max() + 1]
    return b


def shift_to(ref, m, R=(70, 14)):
    """(dx, dy) moving m's plinth band onto ref's (best IoU)."""
    ry, rx = np.nonzero(ref)
    my, mx = np.nonzero(m)
    H, W = ref.shape
    best, bt = -1.0, (0, 0)
    for dy in range(-R[1], R[1] + 1):
        for dx in range(-R[0], R[0] + 1, 1):
            yy, xx = my + dy, mx + dx
            ok = (yy >= 0) & (yy < H) & (xx >= 0) & (xx < W)
            inter = ref[yy[ok], xx[ok]].sum()
            iou = inter / float(len(ry) + len(my) - inter)
            if iou > best:
                best, bt = iou, (dx, dy)
    return bt, best


def main():
    cs = cells()
    ref = band(cs[0][1])
    # the anchor of the built frame: the middle of the plinth's widest rows (the footprint's centre line) and its bottom
    ys, xs = np.nonzero(ref)
    widest = max(range(ys.min(), ys.max() + 1), key=lambda y: np.count_nonzero(ref[y]))
    row = np.nonzero(ref[widest])[0]
    ax, ay = (row.min() + row.max() + 1) / 2.0, float(ys.max() + 1)
    shifts = []
    for i, (o, m) in enumerate(cs):
        if i == 0:
            shifts.append(((0, 0), 1.0))
            continue
        shifts.append(shift_to(ref, band(m)))
    for n, (t, iou) in zip(NAMES, shifts):
        print('%-10s shift %+4d %+3d  plinth overlap %.2f' % (n, t[0], t[1], iou))
    # one canvas for all: the anchor at the bottom centre, room for every frame round it
    L = R = U = D = 0.0
    for (o, m), (t, iou) in zip(cs, shifts):
        yy, xx = np.nonzero(o[..., 3] > 0)
        L = max(L, ax - (xx.min() + t[0]))
        R = max(R, xx.max() + 1 + t[0] - ax)
        U = max(U, ay - (yy.min() + t[1]))
        D = max(D, yy.max() + 1 + t[1] - ay)
    half = int(np.ceil(max(L, R))) + 2
    w, h = half * 2, int(np.ceil(U + max(D, 0.0))) + 4
    base = h - 2 - int(np.ceil(max(D, 0.0)))
    for n, (o, m), (t, iou) in zip(NAMES, cs, shifts):
        c = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        c.paste(Image.fromarray(o, 'RGBA'), (int(round(half - ax + t[0])), int(round(base - ay + t[1]))))
        c.save(OUT + 'cuckoo_house_%s.png' % n)
    print('canvas %dx%d, the plinth centre at (%d, %d)' % (w, h, half, base))


if __name__ == '__main__':
    main()
