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
            y0, y1, x0, x1 = b[0].start, b[0].stop, b[1].start, b[1].stop
            # the frame itself (portraits are a little taller than wide: squeezed square)
            crop = im.crop((x0, y0, x1, y1))
            crop.resize((64, 64), Image.LANCZOS).save(os.path.join("assets/icons", name + ".png"))
    print("horse icons: 13 written")


if __name__ == "__main__":
    main()
