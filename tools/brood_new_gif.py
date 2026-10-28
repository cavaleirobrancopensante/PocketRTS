#!/usr/bin/env python3
"""Turn tools/shot_brood_new.gd's laying_NN.png frames into docs/shots/brood_new/laying.gif (small: cropped round the
Mother, 480 px wide, 64 colours, every other frame at 0.2 s) and keep one frame as laying.png; and the egg_NN.png
frames into egg.gif (one egg fertilised and hatching), keeping egg_red.png and egg_hatched.png.
    python3 -I tools/brood_new_gif.py docs/shots/brood_new"""
import glob
import os
import shutil
import sys

from PIL import Image

d = sys.argv[1]
fs = sorted(glob.glob(os.path.join(d, "laying_*.png")))
if not fs:
    sys.exit("no laying_NN.png frames in " + d)
ims = [Image.open(f).convert("RGB").crop((320, 90, 1280, 690)).resize((480, 300), Image.LANCZOS) for f in fs[::2]]
pal = [im.quantize(colors=64, method=Image.Quantize.MEDIANCUT) for im in ims]
pal[0].save(os.path.join(d, "laying.gif"), save_all=True, append_images=pal[1:], duration=200, loop=0, optimize=True)
shutil.copy(fs[len(fs) // 2], os.path.join(d, "laying.png"))
for f in fs:
    os.remove(f)
print("laying.gif: %d frames, %d KB" % (len(pal), os.path.getsize(os.path.join(d, "laying.gif")) // 1024))
# one egg: yellow-green, reddening under the father's breath, red, cracking, the Raptor on the open shell
es = sorted(glob.glob(os.path.join(d, "egg_*.png")))
if es:
    ims = [Image.open(f).convert("RGB").crop((440, 200, 1160, 680)).resize((480, 320), Image.LANCZOS) for f in es]
    pal = [im.quantize(colors=96, method=Image.Quantize.MEDIANCUT) for im in ims]
    pal[0].save(os.path.join(d, "egg.gif"), save_all=True, append_images=pal[1:], duration=110, loop=0, optimize=True)
    shutil.copy(es[min(12, len(es) - 1)], os.path.join(d, "egg_red.png"))
    shutil.copy(es[-1], os.path.join(d, "egg_hatched.png"))
    for f in es:
        os.remove(f)
    print("egg.gif: %d frames, %d KB" % (len(pal), os.path.getsize(os.path.join(d, "egg.gif")) // 1024))
