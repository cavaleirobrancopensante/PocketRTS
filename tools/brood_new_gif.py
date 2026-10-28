#!/usr/bin/env python3
"""Turn tools/shot_brood_new.gd's frame series into small GIFs in docs/shots/brood_new/ (the frames are deleted):
  laying_NN.png      -> laying.gif (the Mother walking and laying; one frame kept as laying.png)
  egg_NN.png         -> egg.gif (the rooted Tyrannosaur's nest: its queue fertilised and hatching; egg_hatched.png kept)
  root_NN.png        -> root.gif (the Tyrannosaur settling on his nest beside the Mother)
  lay_NN.png         -> lay.gif (the rooted Mother laying)
  loop_<kind>_NN.png -> loop_<kind>.gif (each rooted creature's loop, close)
    python3 -I tools/brood_new_gif.py docs/shots/brood_new"""
import glob
import os
import re
import shutil
import sys

from PIL import Image

d = sys.argv[1]


def make(pattern, name, crop, size, colors, ms, step=1, keep=None):
    fs = sorted(glob.glob(os.path.join(d, pattern)))
    if not fs:
        return
    ims = [Image.open(f).convert("RGB").crop(crop).resize(size, Image.LANCZOS) for f in fs[::step]]
    pal = [im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT) for im in ims]
    pal[0].save(os.path.join(d, name), save_all=True, append_images=pal[1:], duration=ms, loop=0, optimize=True)
    for src, dst in (keep or []):
        shutil.copy(fs[src], os.path.join(d, dst))
    for f in fs:
        os.remove(f)
    print("%s: %d frames, %d KB" % (name, len(pal), os.path.getsize(os.path.join(d, name)) // 1024))


make("laying_*.png", "laying.gif", (320, 90, 1280, 690), (480, 300), 64, 200, step=2, keep=[(18, "laying.png")])
make("egg_*.png", "egg.gif", (400, 150, 1200, 750), (480, 360), 96, 180, keep=[(-1, "egg_hatched.png")])
make("root_*.png", "root.gif", (300, 100, 1300, 800), (500, 350), 96, 100)
make("lay_*.png", "lay.gif", (300, 100, 1300, 800), (500, 350), 128, 70)
kinds = sorted({re.sub(r"_\d+\.png$", "", os.path.basename(f))[len("loop_"):] for f in glob.glob(os.path.join(d, "loop_*_[0-9][0-9].png"))})
for k in kinds:
    make("loop_%s_[0-9][0-9].png" % k, "loop_%s.gif" % k, (450, 150, 1150, 750), (420, 360), 128, 100)
