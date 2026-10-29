#!/usr/bin/env python3
"""The Mist Toad hop GIF (docs/shots/toad_hop/) from the frames tools/shot_toad_hop.gd saved:
    python3 tools/toad_hop_gif.py <frames dir> <outdir>   (reads <frames dir>/f*.png, writes <outdir>/toad_hop.gif)
The 1600 x 900 view shrunk to 440 x 248, 64 colours, real time
(the frames were taken 1/15 s apart)."""
import glob
import os
import sys

from PIL import Image

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else src
files = sorted(glob.glob(os.path.join(src, "f*.png")))
frames = []
for f in files:
    im = Image.open(f).convert("RGB")
    frames.append(im.resize((440, 248), Image.LANCZOS))
pick = frames[:: max(1, len(frames) // 6)]
sheet = Image.new("RGB", (440 * len(pick), 248))
for i, f in enumerate(pick):
    sheet.paste(f, (i * 440, 0))
pal = sheet.quantize(colors=64, method=Image.Quantize.MEDIANCUT)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
dst = os.path.join(out, "toad_hop.gif")
q[0].save(dst, save_all=True, append_images=q[1:], duration=67, loop=0, optimize=True)
print("%d frames -> %s (%d KB)" % (len(q), dst, os.path.getsize(dst) // 1024))
