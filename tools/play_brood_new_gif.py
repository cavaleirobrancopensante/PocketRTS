#!/usr/bin/env python3
"""Turn the clip frames of tools/play_brood_new.gd (<dir>/clip_<moment>_NN.png) into <dir>/<moment>.gif (the middle of
the screen, 480 px wide, 48 colours, every other frame at 0.3 s) and delete the frames.
    python3 -I tools/play_brood_new_gif.py <dir>
With --keep <dir> <out_dir> <name>... it copies the named pictures to out_dir at 960 px wide, 256 colours (for docs/shots/brood_new_play)."""
import glob
import os
import re
import sys

from PIL import Image


def gifs(d):
    clips = {}
    for f in glob.glob(os.path.join(d, "clip_*_[0-9][0-9].png")):
        m = re.match(r"clip_(.+)_(\d\d)\.png$", os.path.basename(f))
        clips.setdefault(m.group(1), []).append(f)
    for name, fs in clips.items():
        fs.sort()
        ims = []
        for f in fs[::2] if len(fs) > 20 else fs:
            im = Image.open(f).convert("RGB")
            w, h = im.size
            im = im.crop((w // 2 - 480, h // 2 - 270, w // 2 + 480, h // 2 + 270)).resize((480, 270), Image.LANCZOS)
            ims.append(im.quantize(colors=48, method=Image.Quantize.MEDIANCUT))
        out = os.path.join(d, name + ".gif")
        ims[0].save(out, save_all=True, append_images=ims[1:], duration=300 if len(fs) > 20 else 150, loop=0, optimize=True)
        # one still from the middle of the clip
        Image.open(fs[len(fs) // 2]).convert("RGB").save(os.path.join(d, name + "_still.png"))
        for f in fs:
            os.remove(f)
        print("%s: %d frames, %d KB" % (out, len(ims), os.path.getsize(out) // 1024))


def keep(d, out, names):
    os.makedirs(out, exist_ok=True)
    for n in names:
        src, _, dst = n.partition("=")
        p = os.path.join(d, src)
        q = os.path.join(out, dst or src)
        if src.endswith(".gif"):
            with open(p, "rb") as a, open(q, "wb") as b:
                b.write(a.read())
        else:
            im = Image.open(p).convert("RGB")
            im.resize((960, 540), Image.LANCZOS).quantize(colors=256, method=Image.Quantize.MEDIANCUT).save(q, optimize=True)
        print(q, os.path.getsize(q) // 1024, "KB")


if sys.argv[1] == "--keep":
    keep(sys.argv[2], sys.argv[3], sys.argv[4:])
else:
    gifs(sys.argv[1])
