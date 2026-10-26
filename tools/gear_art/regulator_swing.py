"""The Regulator's working loop (art/clockwork/gear/regulator_work_0..7.png): the painted pendulum of the BUILT frame cut
out of its glass window, the glass filled in behind it, and the pendulum swung in code about its pivot (8 frames, one
full swing). Also closes the pin holes the navy key left in the dark glass of every Regulator frame.
  python3 tools/gear_art/regulator_swing.py   (then tools/gear_art/import_buildings.py)"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

D = 'art/clockwork/gear/'
WIN = (177, 249, 233, 309)        # the glass window's inside (x0, y0, x1, y1) on the 3x canvas
PIVOT = (203.5, 249.0)
ANG = [0, 6, 10, 6, 0, -6, -10, -6]


def close_holes(path):
    im = np.array(Image.open(path).convert('RGBA'))
    a = im[..., 3] > 0
    filled = ndi.binary_fill_holes(a)
    holes = filled & ~a
    if holes.any():
        # fill each hole pixel with the mean of its solid neighbours
        rgb = im[..., :3].astype(float)
        for _ in range(4):
            sol = im[..., 3] > 0
            acc = np.zeros_like(rgb)
            cnt = np.zeros(sol.shape)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                s = np.roll(np.roll(sol, dy, 0), dx, 1)
                acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * s[..., None]
                cnt += s
            fill = holes & ~sol & (cnt > 0)
            rgb[fill] = acc[fill] / cnt[fill][:, None]
            im[fill, :3] = rgb[fill].astype(np.uint8)
            im[fill, 3] = 255
    Image.fromarray(im, 'RGBA').save(path)
    return im


def main():
    for s in ('built', 'construct', 'damaged', 'destroyed'):
        close_holes(D + 'regulator_%s.png' % s)
    B = np.array(Image.open(D + 'regulator_built.png').convert('RGBA'))
    x0, y0, x1, y1 = WIN
    sub = B[y0:y1, x0:x1, :3].astype(int)
    warm = (sub[..., 0] > sub[..., 2] + 10) & (sub.sum(2) > 160)
    warm = ndi.binary_dilation(warm, iterations=1)
    lab, n = ndi.label(warm)
    # the pendulum: the warm blob that the rod (just under the pivot) belongs to
    px, py = int(PIVOT[0]) - x0, 4
    k = lab[py, px] or lab[py:py + 8, px - 2:px + 3].max()
    pm = np.zeros(B.shape[:2], bool)
    pm[y0:y1, x0:x1] = ndi.binary_dilation(ndi.binary_fill_holes(lab == k), iterations=2)     # (with its dark outline)
    # the glass behind: each row interpolated across the pendulum
    glass = B.copy()
    for y in range(y0, y1):
        row = pm[y, x0:x1]
        if not row.any():
            continue
        good = np.nonzero(~row)[0]
        for x in np.nonzero(row)[0]:
            lft = good[good < x]
            rgt = good[good > x]
            if len(lft) and len(rgt):
                t = (x - lft[-1]) / (rgt[0] - lft[-1])
                glass[y, x0 + x, :3] = (1 - t) * B[y, x0 + lft[-1], :3] + t * B[y, x0 + rgt[0], :3]
            elif len(lft):
                glass[y, x0 + x, :3] = B[y, x0 + lft[-1], :3]
            elif len(rgt):
                glass[y, x0 + x, :3] = B[y, x0 + rgt[0], :3]
    pend = B.copy()
    pend[..., 3] = pm * 255
    P = Image.fromarray(pend, 'RGBA')
    clip = Image.new('L', P.size, 0)
    ImageDraw.Draw(clip).rectangle((x0, y0, x1 - 1, y1 - 1), fill=255)
    for i, a in enumerate(ANG):
        f = Image.fromarray(glass, 'RGBA')
        p = P.rotate(a, resample=Image.NEAREST, center=PIVOT)
        al = np.minimum(np.array(p)[..., 3], np.array(clip)).astype(np.uint8)
        p.putalpha(Image.fromarray(al))
        f.alpha_composite(p)
        f.save(D + 'regulator_work_%d.png' % i)
    print('regulator: pendulum %d px, %d frames' % (pm.sum(), len(ANG)))


if __name__ == '__main__':
    main()
