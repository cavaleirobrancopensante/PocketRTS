#!/usr/bin/env python3
"""The GIFs of TURNING GEARS (docs/gear_turn.md) from the frames tools/shot_gear_turn.gd saved:
    python3 tools/gear_turn_gif.py <outdir>      (reads <outdir>/gif_<scene>/f*.png, writes <outdir>/<scene>.gif)
800 x 450, played at about twice the game's speed, one 256-colour palette per GIF."""
import glob, os, sys
from PIL import Image

out = sys.argv[1]
for d in sorted(glob.glob(os.path.join(out, "gif_*"))):
    name = os.path.basename(d)[4:]
    files = sorted(glob.glob(os.path.join(d, "f*.png")))
    if not files:
        continue
    frames = [Image.open(f).convert("RGB").resize((800, 450), Image.LANCZOS) for f in files]
    pick = frames[:: max(1, len(frames) // 6)]
    w, h = pick[0].size
    sheet = Image.new("RGB", (w * len(pick), h))
    for i, f in enumerate(pick):
        sheet.paste(f, (i * w, 0))
    pal = sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(os.path.join(out, name + ".gif"), save_all=True, append_images=q[1:], duration=100, loop=0, optimize=True)
    print("%d frames -> %s" % (len(q), os.path.join(out, name + ".gif")))
