#!/usr/bin/env python3
"""Makes the GIFs and contact sheets of tools/shot_lead_anim.gd's frames.
  python3 tools/lead_anim_gif.py [frames_dir] [out_dir]
For each <prefix>_<case>: <prefix>_<case>.gif (10 fps, every frame) and <prefix>_<case>_sheet.png (every 4th
2nd frame from 0.8 s to 3.2 s, in two rows, numbered). The frames dir is deleted afterwards only with --clean."""
import glob
import os
import re
import shutil
import sys

from PIL import Image, ImageDraw

src = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "docs/shots/lead_anim/frames"
dst = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else "docs/shots/lead_anim"
GIFS = ["labourer_lead", "musketeer_lead", "officer_lead"]      # (GIFs only for these: the sheets cover the rest)
groups = {}
for p in sorted(glob.glob(os.path.join(src, "*.png"))):
    m = re.match(r"(.+)_(\d{3})\.png$", os.path.basename(p))
    if m:
        groups.setdefault(m.group(1), []).append(p)
for name, files in groups.items():
    ims = [Image.open(f).convert("RGB") for f in files]
    ims = [i.resize((i.width * 3 // 4, i.height * 3 // 4), Image.LANCZOS) for i in ims]     # (smaller files)
    # the GIF: the first 3.5 s (35 frames of 0.1 s: one picture every 3 game frames at 30 fps)
    gif = [i.convert("P", palette=Image.ADAPTIVE, colors=96) for i in ims[:35]]
    if GIFS and not any(name.endswith(g) for g in GIFS):
        gif = []
    if gif:
        gif[0].save(os.path.join(dst, name + ".gif"), save_all=True, append_images=gif[1:], duration=100, loop=0)
    # the sheet: pictures 8..32 every 2nd (0.2 s apart), two rows
    pick = ims[8:34:2]
    w, h = pick[0].size
    cols = (len(pick) + 1) // 2
    sheet = Image.new("RGB", (cols * w, 2 * h), (20, 20, 20))
    d = ImageDraw.Draw(sheet)
    for n, im in enumerate(pick):
        x, y = (n % cols) * w, (n // cols) * h
        sheet.paste(im, (x, y))
        d.rectangle([x + 2, y + 2, x + 62, y + 20], fill=(0, 0, 0))
        d.text((x + 6, y + 6), "%.1f s" % ((8 + n * 2) * 0.1), fill=(255, 255, 255))
    sheet.convert("P", palette=Image.ADAPTIVE, colors=128).save(os.path.join(dst, name + "_sheet.png"), optimize=True)
    print("wrote", name)
if "--clean" in sys.argv:
    shutil.rmtree(src)
