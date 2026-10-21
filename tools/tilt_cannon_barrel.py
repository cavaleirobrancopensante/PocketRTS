# Leans the towed cannon in the south-walk frames: the barrel stood straight up like a
# chimney. The barrel is sheared (top 3-4 px to the right, base fixed, so no holes) and the
# right wheel lifted a little so the carriage reads as turned.
# usage: python3 tools/tilt_cannon_barrel.py original_walk_s.png out.png [k] [lift]
import sys
from PIL import Image
import numpy as np
src, dst = sys.argv[1], sys.argv[2]
k = float(sys.argv[3]) if len(sys.argv) > 3 else 0.16
lift = int(sys.argv[4]) if len(sys.argv) > 4 else 2
im = np.array(Image.open(src).convert('RGBA'))
W = 165
out = im.copy()
for i in range(im.shape[1] // W):
    f = im[:, i*W:(i+1)*W]
    o = f.copy()
    # barrel: rows 36..59, cols 66..82; shift each row right by k*(59-y)
    X0, X1, Y0, Y1 = 66, 83, 36, 60
    o[Y0:Y1, X0:X1+6] = f[Y0:Y1, X0:X1+6] * 0
    o[Y0:Y1, X1:X1+6] = f[Y0:Y1, X1:X1+6]
    for y in range(Y0, Y1):
        s = int(round(k * (Y1 - 1 - y)))
        row = f[y, X0:X1]
        dst_row = o[y, X0+s:X1+s]
        m = row[:, 3] > 0
        dst_row[m] = row[m]
    # right wheel: lift
    if lift:
        WX0, WX1, WY0, WY1 = 85, 94, 62, 97
        blk = f[WY0:WY1, WX0:WX1].copy()
        o[WY0:WY1, WX0:WX1] = 0
        o[WY0-lift:WY1-lift, WX0:WX1][blk[..., 3] > 0] = blk[blk[..., 3] > 0]
        # keep anything of the soldier that sat above the wheel block
        keep = f[WY0-lift:WY0, WX0:WX1]
        sub = o[WY0-lift:WY0, WX0:WX1]
        sub[sub[..., 3] == 0] = keep[sub[..., 3] == 0]
    out[:, i*W:(i+1)*W] = o
Image.fromarray(out).save(dst)
