#!/usr/bin/env python3
"""Before/after pictures of the map enlargement (docs/map_sizes.md, docs/shots/map_sizes/).

  python3 tools/map_sizes_sheet.py <before dir> <before.json> <after dir> <after.json> <out dir>

The dirs hold tools/shot_map_sizes.gd's pictures (<map>.png, <map>_<n>p.png); the json files are
tools/map_sizes.gd's (json:...). Both pictures of a map are drawn at the same scale (PX pixels a tile),
so the growth shows. Writes <out>/<map>_before_after.jpg (the new map alone: docs/shots/expansion_spots/)."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PX = 4.0


def sizes(path):
    out = {}
    for r in json.load(open(path)):
        out[(r["id"], r["n"])] = r
    return out


def font(sz):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def main():
    bdir, bjs, adir, ajs, out = sys.argv[1:6]
    os.makedirs(out, exist_ok=True)
    bs, as_ = sizes(bjs), sizes(ajs)
    f = font(18)
    for (mid, n), a in sorted(as_.items()):
        name = mid if n == 2 else "%s_%dp" % (mid, n)
        ap = os.path.join(adir, name + ".png")
        bp = os.path.join(bdir, name + ".png")
        if not os.path.exists(ap):
            continue
        aimg = Image.open(ap).convert("RGB")
        b = bs.get((mid, n))
        if b is None or not os.path.exists(bp):
            continue
        bimg = Image.open(bp).convert("RGB")
        bimg = bimg.resize((int(b["w"] * PX), int(b["h"] * PX)), Image.LANCZOS)
        aimg = aimg.resize((int(a["w"] * PX), int(a["h"] * PX)), Image.LANCZOS)
        pad = 16
        top = 54
        W = bimg.width + aimg.width + pad * 3
        H = max(bimg.height, aimg.height) + top + pad
        sheet = Image.new("RGB", (W, H), (24, 24, 28))
        sheet.paste(bimg, (pad, top))
        sheet.paste(aimg, (pad * 2 + bimg.width, top))
        d = ImageDraw.Draw(sheet)
        def lab(x, r, what):
            per = r["per"]
            d.text((x, 6), "%s %dx%d" % (what, r["w"], r["h"]), fill=(240, 230, 200), font=f)
            d.text((x, 28), "walk %d tiles (%d s), sites %s" % (r["walk"], r["secs"], "/".join(str(p) for p in per)), fill=(200, 200, 200), font=font(14))
        lab(pad, b, "BEFORE")
        lab(pad * 2 + bimg.width, a, "AFTER")
        sheet.save(os.path.join(out, name + "_before_after.jpg"), quality=70)
        print(name)


if __name__ == "__main__":
    main()
