"""Join frames <dir>/<name>_NN.png (tools/shot_building_anim.gd) into <dir>/strip_<name>.png:
a grid of crops around the middle of the screen, `cols` to a row.  python3 tools/strip.py <dir> [cols]"""
import glob, os, sys
from PIL import Image, ImageDraw

d = sys.argv[1]
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 4
CROP = tuple(int(v) for v in os.environ.get("CROP", "350,120,930,660").split(","))
SCALE = 0.6
names = sorted({os.path.basename(f).rsplit("_", 1)[0] for f in glob.glob(d + "/*_[0-9][0-9].png")})
for n in names:
    files = sorted(glob.glob("%s/%s_[0-9][0-9].png" % (d, n)))
    ims = []
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB").crop(CROP)
        im = im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.NEAREST)
        ImageDraw.Draw(im).text((6, 4), str(i + 1), fill=(255, 255, 255))
        ims.append(im)
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (20, 20, 20))
    for i, im in enumerate(ims):
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    sheet.save("%s/strip_%s.png" % (d, n))
    print(n, sheet.size)
