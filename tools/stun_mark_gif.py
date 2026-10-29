#!/usr/bin/env python3
"""The STUN MARK's GIF (docs/shots/stun_mark/) from the frames tools/shot_stun_mark.gd saved:
    python3 tools/stun_mark_gif.py <frames dir> <out gif>   (reads <frames dir>/gif/f*.png)
Every other frame (15 a second), 320 x 200, 48 colours: a small GIF."""
import glob, os, sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(src, "gif", "f*.png")))[::2]
frames = [Image.open(f).convert("RGB").resize((320, 200), Image.LANCZOS) for f in files]
w, h = frames[0].size
sheet = Image.new("RGB", (w * 4, h))
for i, f in enumerate(frames[:: max(1, len(frames) // 4)][:4]):
    sheet.paste(f, (i * w, 0))
pal = sheet.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
q[0].save(dst, save_all=True, append_images=q[1:], duration=66, loop=0, optimize=True)
print("%d frames -> %s (%d KB)" % (len(q), dst, os.path.getsize(dst) // 1024))
