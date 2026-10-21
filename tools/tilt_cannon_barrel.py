# Tilts the limbered cannon barrel in the south-walk frames (it stood straight up like a chimney).
# usage: python3 tools/tilt_cannon_barrel.py assets/units/cannon/walk_s.png out.png 15
import sys
from PIL import Image
import numpy as np
src, dst, ang = sys.argv[1], sys.argv[2], float(sys.argv[3])
im = Image.open(src).convert('RGBA')
W = 165
n = im.width // W
out = im.copy()
X0, X1, Y0, Y1 = 63, 88, 30, 61
px, py = 75.5, 60
for i in range(n):
    fr = im.crop((i*W, 0, i*W+W, im.height))
    reg = fr.crop((X0, Y0, X1, Y1))
    big = Image.new('RGBA', (W, im.height), (0,0,0,0))
    big.paste(reg, (X0, Y0))
    rot = big.rotate(-ang, resample=Image.BICUBIC, center=(px, py)); ra = np.array(rot); ra[...,3] = np.where(ra[...,3] > 110, 255, 0); rot = Image.fromarray(ra)
    base = np.array(fr)
    base[Y0:Y1, X0:X1] = 0
    b = Image.fromarray(base)
    # rotated barrel goes under nothing: composite barrel then original lower parts on top
    comp = Image.new('RGBA', b.size, (0,0,0,0))
    comp.alpha_composite(rot)
    comp.alpha_composite(b)
    out.paste(comp, (i*W, 0))
out.save(dst)
