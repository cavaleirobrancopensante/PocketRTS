#!/usr/bin/env python3
"""The GIFs of docs/shots/brood_anims/ from tools/shot_brood_anims.gd's pictures:
  python3 -I tools/shot_brood_anims.py <shots dir> <out dir>
cocoon_rootmaw.gif, cocoon_mound_turtle.gif, moult_venom.gif, moult_tyrant.gif, moult_storm.gif (each cropped round the
middle of the screen, where the camera looks), cards.png (the five cards' panels side by side)."""
import glob
import os
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
BOX = {"cocoon": (230, 160, 570, 470), "moult": (260, 150, 540, 430)}


def gif(stem, box, ms=120):
    fs = sorted(glob.glob(f"{src}/{stem}_[0-9][0-9].png"))
    if not fs:
        return
    ims = [Image.open(f).convert("RGB").crop(box) for f in fs]
    # (one palette for the whole GIF, from a few of its pictures side by side; no dithering: small files)
    pick = [ims[int(i * (len(ims) - 1) / 5)] for i in range(6)]
    w, h = pick[0].size
    ref = Image.new("RGB", (w * 6, h))
    for i, im in enumerate(pick):
        ref.paste(im, (i * w, 0))
    pal = ref.quantize(colors=160, method=Image.MEDIANCUT)
    q = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in ims]
    q[0].save(f"{dst}/{stem}.gif", save_all=True, append_images=q[1:], duration=ms, loop=0, optimize=True)
    # a strip of 8 of its pictures for the doc
    pick = [ims[int(i * (len(ims) - 1) / 7)] for i in range(8)]
    w, h = pick[0].size
    st = Image.new("RGB", (w * 8, h))
    for i, im in enumerate(pick):
        st.paste(im, (i * w, 0))
    st.quantize(colors=200, method=Image.MEDIANCUT, dither=Image.Dither.NONE).save(f"{dst}/{stem}_strip.png")
    print(stem, len(ims), "frames")


for k in ("rootmaw", "mound_turtle"):
    gif(f"cocoon_{k}", BOX["cocoon"])
for ln in ("venom", "tyrant", "storm"):
    gif(f"moult_{ln}", BOX["moult"])
cards = sorted(glob.glob(f"{src}/card_*.png"))
if cards:
    ims = [Image.open(f).convert("RGB") for f in cards]
    W, H = ims[0].size
    band = [im.crop((0, int(H * 0.72), W, H)) for im in ims]
    out = Image.new("RGB", (W, sum(b.height for b in band)))
    y = 0
    for b in band:
        out.paste(b, (0, y))
        y += b.height
    out.quantize(colors=200, method=Image.MEDIANCUT, dither=Image.Dither.NONE).save(f"{dst}/cards.png")
    print("cards", [os.path.basename(c) for c in cards])
