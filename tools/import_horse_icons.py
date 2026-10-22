"""Cuts the horse system's portraits and command icons from the designer's sheet
(art/ui/icons3/crown_horse_icons.png: 7 portraits on top, 6 command icons below, each in
its own frame on navy) into 64x64 assets/icons/*.png.  python3 tools/import_horse_icons.py"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "art/ui/icons3/crown_horse_icons.png"
TOP = ["horse", "messenger", "dragoon", "dragoon_armoured", "dismounted", "dismounted_armoured",
       "mounted_missionary"]
# portraits of their own since (art/ui/icons2/portraits_officer.png / portraits_dragoon.png,
# cut by tools/import_round11.py): not overwritten here
OWN = ["dragoon", "dragoon_armoured", "dismounted", "dismounted_armoured"]
BOTTOM = ["horse_lead", "horse_release", "horse_mount", "horse_dismount", "horse_unhitch",
          "horse_harness"]


def main():
    im = Image.open(SRC).convert("RGBA")
    a = np.array(im).astype(int)
    bg = a[4, 4, :3]
    m = np.abs(a[..., :3] - bg).sum(-1) > 30
    lab, n = ndimage.label(m)
    boxes = [o for o in ndimage.find_objects(lab) if (o[0].stop - o[0].start) > 150 and (o[1].stop - o[1].start) > 150]
    mid = a.shape[0] // 2
    top = sorted([b for b in boxes if (b[0].start + b[0].stop) // 2 < mid], key=lambda b: b[1].start)
    bot = sorted([b for b in boxes if (b[0].start + b[0].stop) // 2 >= mid], key=lambda b: b[1].start)
    assert len(top) == 7 and len(bot) == 6, (len(top), len(bot))
    for names, row in [(TOP, top), (BOTTOM, bot)]:
        for name, b in zip(names, row):
            if name in OWN:
                continue          # (the designer's painted portrait: tools/import_round11.py)
            y0, y1, x0, x1 = b[0].start, b[0].stop, b[1].start, b[1].stop
            # the frame itself (portraits are a little taller than wide: squeezed square)
            crop = im.crop((x0, y0, x1, y1))
            crop.resize((64, 64), Image.LANCZOS).save(os.path.join("assets/icons", name + ".png"))
    # MOUNT / DISMOUNT: the stirrup picture with a bold red arrow, up to get on, down to get off
    for name, up in [("horse_mount", True), ("horse_dismount", False)]:
        arrow(os.path.join("assets/icons", name + ".png"), up)
    print("horse icons: %d written" % (13 - len(OWN)))


def arrow(path, up):
    from PIL import ImageDraw
    big = Image.open(path).convert("RGBA").resize((256, 256), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    x, w = 70, 34                     # the shaft's centre (left of the boot) and half the head's width
    top, bot = 44, 210
    if up:
        head = [(x, top), (x - w * 1.5, top + 62), (x + w * 1.5, top + 62)]
        shaft = (x - 15, top + 56, x + 15, bot)
    else:
        head = [(x, bot), (x - w * 1.5, bot - 62), (x + w * 1.5, bot - 62)]
        shaft = (x - 15, top, x + 15, bot - 56)
    for grow, col in [(9, (20, 10, 8, 255)), (0, (214, 32, 28, 255))]:
        hx = [(px + (grow if px > x else -grow if px < x else 0), py + (-grow if (up and py == top) or (not up and py != bot) else grow)) for px, py in head]
        d.polygon(hx, fill=col)
        d.rectangle((shaft[0] - grow, shaft[1] - (0 if up else grow), shaft[2] + grow, shaft[3] + (grow if up else 0)), fill=col)
    # a light edge on the red, so it reads at button size
    d.line([head[1], head[0]], fill=(255, 120, 100, 255), width=4)
    big.resize((64, 64), Image.LANCZOS).save(path)


if __name__ == "__main__":
    main()
