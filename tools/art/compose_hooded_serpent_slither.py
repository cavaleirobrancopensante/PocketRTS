# Builds art/redraws/hooded_serpent_slither_se_composed.png: the coiling slither (hooded_serpent_slither_coil_chatgpt.png,
# the better body motion) with the TAIL FAN taken from the other try (hooded_serpent_slither_fan_chatgpt.png) and grafted
# onto the very end of each frame's tail (the owner, 2026-10-29: the first composite placed the fans too far left).
# Per frame: the fan = the fan frame's pixels within FAN_R of the fan's yellow centre; its joint = where the tail leaves
# the fan (the body pixels just outside FAN_R); the coil frame's tail tip spike (within CUT of its topmost pixel) is cut
# off and the fan is placed so its joint lands on the coil tail's end (the body just below the cut).
#   python3 tools/art/compose_hooded_serpent_slither.py [out.png] [preview.png]
import sys
from PIL import Image
import numpy as np
from scipy import ndimage
R = 'art/redraws/'
FAN_R = 80      # px (sheet): the fan's radius round its yellow centre
CUT = 34        # px: the coil tail's plain tip cut off before the fan goes on


def comps(f):
    im = np.array(Image.open(R + f).convert('RGB')).astype(float)
    bg = im[5, 5]
    d = np.sqrt(((im - bg) ** 2).sum(-1))
    m = ndimage.binary_closing(d > 40, iterations=2)
    lab, n = ndimage.label(m)
    out = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        if (lab[s] == i + 1).sum() > 3000:
            out.append((s[1].start, ndimage.binary_dilation(lab == i + 1, iterations=1)))
    out.sort(key=lambda t: t[0])
    return im, bg, [o[1] for o in out]


fim, fbg, fcs = comps('hooded_serpent_slither_fan_chatgpt.png')
cim, cbg, ccs = comps('hooded_serpent_slither_coil_chatgpt.png')
H, W = cim.shape[:2]
yy, xx = np.mgrid[0:H, 0:W]
CW = 470
sheet = Image.new('RGB', (CW * 6, 560), tuple(int(v) for v in cbg))
for i in range(6):
    fm, cm = fcs[i], ccs[i]
    # the fan: its yellow-green membrane's centre in the top part of the fan frame's body
    ys, xs = np.nonzero(fm)
    top = ys.min()
    band = fm & (yy < top + 140)
    yel = band & (fim[..., 0] > 140) & (fim[..., 1] > 120) & (fim[..., 2] < 90)
    cy, cx = np.argwhere(yel).mean(0)
    dist = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
    fan = fm & (dist <= FAN_R)
    ring = fm & (dist > FAN_R) & (dist <= FAN_R + 14) & (yy > cy)      # the tail leaving the fan (below its centre)
    jy, jx = np.argwhere(ring).mean(0)
    # the coil frame: its tail's topmost pixel, cut the tip, the tail's end just below the cut
    ys, xs = np.nonzero(cm)
    ty = ys.min()
    tx = int(xs[ys == ty].mean())
    tdist = np.sqrt((yy - ty) ** 2 + (xx - tx) ** 2)
    body = cm & ~(tdist < CUT)
    end = cm & (tdist >= CUT) & (tdist < CUT + 12)
    ey, ex = np.argwhere(end).mean(0)
    # compose on a canvas: the coil body, then the fan moved so its joint lands on the tail's end
    P = 160                                  # (padding: a fan may reach past the sheet's edge)
    can = np.zeros((H + 2 * P, W + 2 * P, 4), np.uint8)
    can[P:P + H, P:P + W, :3] = cim.astype(np.uint8)
    can[P:P + H, P:P + W, 3] = body * 255
    dy, dx = int(round(ey - jy)) + P, int(round(ex - jx)) + P
    fy, fx = np.nonzero(fan)
    ny, nx = fy + dy, fx + dx
    ok = (ny >= 0) & (ny < H + 2 * P) & (nx >= 0) & (nx < W + 2 * P)
    can[ny[ok], nx[ok], :3] = fim[fy[ok], fx[ok]].astype(np.uint8)
    can[ny[ok], nx[ok], 3] = 255
    a = np.argwhere(can[..., 3] > 0)
    y0, x0 = a.min(0)
    y1, x1 = a.max(0)
    piece = Image.fromarray(can[y0:y1 + 1, x0:x1 + 1], 'RGBA')
    # feet (the head's bottom) on one ground line, each piece centred in its cell
    sheet.paste(piece, (i * CW + (CW - piece.width) // 2, 560 - 10 - piece.height), piece)
out = sys.argv[1] if len(sys.argv) > 1 else R + 'hooded_serpent_slither_se_composed.png'
sheet.save(out)
if len(sys.argv) > 2:
    sheet.resize((sheet.width // 2, sheet.height // 2)).save(sys.argv[2])
