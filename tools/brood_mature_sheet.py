#!/usr/bin/env python3
"""The Brood Mother's three stages side by side (docs/shots/brood_mature/mother_stages.png): crops the middle of the
pictures tools/shot_brood_structures.gd takes in its "mature" mode (mother_s<N>_rooted.png, mother_s<N>_walk.png, all at
one zoom) into one sheet: rooted on top, walking below, stage 1 to 3 left to right, each labelled.
  python3 -I tools/brood_mature_sheet.py <shots dir> [<out png>]"""
import os
import sys

from PIL import Image, ImageDraw

W, H = 760, 520          # (the crop round the screen's middle: her whole nest at stage 3)


def main():
    d = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(d, "mother_stages.png")
    sheet = Image.new("RGB", (W * 3, H * 2 + 40), (20, 22, 20))
    dr = ImageDraw.Draw(sheet)
    for row, kind in enumerate(["rooted", "walk"]):
        for st in range(3):
            p = os.path.join(d, "mother_s%d_%s.png" % (st + 1, kind))
            if not os.path.exists(p):
                continue
            im = Image.open(p).convert("RGB")
            cx, cy = im.width // 2, im.height // 2 - 60
            crop = im.crop((cx - W // 2, cy - H // 2, cx + W // 2, cy + H // 2))
            sheet.paste(crop, (st * W, 40 + row * H))
            dr.text((st * W + 12, 44 + row * H), "STAGE %d  %s" % (st + 1, kind.upper()), fill=(255, 240, 160))
    dr.text((12, 12), "The Brood Mother: stage 1, 2, 3 (rooted in her nest, walking); one zoom", fill=(230, 230, 230))
    sheet.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
