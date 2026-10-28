#!/usr/bin/env python3
"""The GIF of the black powder smoke (docs/powder_smoke.md) from the frames tools/shot_powder_smoke.gd saved:
    python3 tools/powder_smoke_gif.py <outdir> [name]     (reads <outdir>/gif/f*.png, writes <outdir>/<name or powder_smoke>.gif)
One frame every half second (560 x 318) of play, shown at 4x speed (125 ms a frame), a 256-colour palette shared by all frames."""
import glob, os, sys
from PIL import Image

out = sys.argv[1]
name = (sys.argv[2] if len(sys.argv) > 2 else "powder_smoke") + ".gif"
files = sorted(glob.glob(os.path.join(out, "gif", "f*.png")))
if not files:
    sys.exit("no frames in %s/gif" % out)
frames = [Image.open(f).convert("RGB").resize((560, 318), Image.LANCZOS) for f in files]
# one palette from a few frames side by side (the smoke's greys and the ground's browns and greens)
pick = frames[:: max(1, len(frames) // 6)]
w, h = pick[0].size
sheet = Image.new("RGB", (w * len(pick), h))
for i, f in enumerate(pick):
    sheet.paste(f, (i * w, 0))
pal = sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
q[0].save(os.path.join(out, name), save_all=True, append_images=q[1:], duration=125, loop=0, optimize=True)
print("%d frames -> %s" % (len(q), os.path.join(out, name)))
