"""The mortar's fire frames draw a puff of smoke over the right-hand gunner's helmet (left
over from the source art): cut it, keeping the mortar's own smoke column and the helmet.
For each fire frame: the right-hand man is found by his red coat; above the top of his
helmet (TOP, read off the art) everything in his column, right of the mortar's smoke, goes,
and in the dome's top rows only the dome itself stays.
Re-runnable.  python3 tools/fix_mortar_smoke.py"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

OUT = "assets/units/mortar"
W = 158
# the top of the right-hand gunner's helmet (row) in each fire frame, read off the art
TOP = {"s": [47, 49], "se": [49, 50], "e": [50, 52], "ne": [50, 51], "n": [46, 46]}


def fix(path):
    im = np.array(Image.open(path).convert("RGBA"))
    cut = 0
    for k in range(im.shape[1] // W):
        f = im[:, k * W:(k + 1) * W]
        r, g, b, a = (f[..., i].astype(int) for i in range(4))
        red = (a > 0) & (r > 150) & (g < 80) & (b < 80)
        red[:, :90] = False                      # the right-hand man only
        lab, n = ndimage.label(ndimage.binary_dilation(red, iterations=1))
        if n == 0:
            continue
        sizes = ndimage.sum(red, lab, range(1, n + 1))
        coat = lab == (int(np.argmax(sizes)) + 1)
        ys, xs = np.nonzero(coat)
        top, x0, x1 = ys.min(), xs.min(), xs.max()
        lo, hi = max(x0 - 8, 92 if k == 0 else 86), min(x1 + 10, W)   # (frame 0: the mortar's own smoke is close)
        t = TOP[os.path.basename(path)[5:-4]][k]
        # the dome's middle: its dark outline in the rows just under its top
        dome = f[t:t + 6, lo:hi]
        mx = dome[..., :3].max(-1)
        dy, dx = np.nonzero((dome[..., 3] > 0) & (mx < 75))
        cx = lo + (int(round(dx.mean())) if dx.size else (hi - lo) // 2)
        for y in range(0, t + 4):
            for x in range(lo, hi):
                if f[y, x, 3] == 0:
                    continue
                keep = y >= t and abs(x - cx) <= (3 if y == t else 4)
                if not keep:
                    f[y, x, 3] = 0
                    cut += 1
    Image.fromarray(im).save(path)
    return cut


if __name__ == "__main__":
    for d in ["s", "se", "e", "ne", "n"]:
        p = os.path.join(OUT, "fire_%s.png" % d)
        print("mortar smoke:", p, fix(p), "px")
