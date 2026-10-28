#!/usr/bin/env python3
"""The ramp pictures of docs/ramp_funnel.md: for each direction, the owner's spec, the game in 0.15.3
and the game now, side by side (docs/shots/ramp_funnel/ramp_<dir>.jpg).
  python3 tools/ramp_funnel_sheet.py <new shots dir> [<0.15.3 sheets dir>]
The new shots come from tools/shot_ramp_funnel.gd (new_<dir>_<map>.png, and *_grid.png under them).
The 0.15.3 picture is the top right panel of the old sheets (ramp_<dir>.jpg of 0.15.3, kept as
ramp_<dir>_0153.jpg)."""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs/shots/ramp_funnel")
new_dir = sys.argv[1]
old_dir = sys.argv[2] if len(sys.argv) > 2 else OUT
H = 360

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
except OSError:
    font = ImageFont.load_default()


def fit(img, h=H):
    return img.resize((round(img.width * h / img.height), h), Image.LANCZOS)


def mid(img):
    """The middle of a shot (the ramp), so it shows at about the scale of the 0.15.3 pictures."""
    w, h = img.width * 0.62, img.height * 0.62
    x, y = (img.width - w) / 2, (img.height - h) / 2
    return img.crop((round(x), round(y), round(x + w), round(y + h)))


def label(img, text):
    d = ImageDraw.Draw(img)
    w = d.textlength(text, font=font)
    d.rectangle([0, 0, w + 12, 22], fill=(0, 0, 0))
    d.text((6, 3), text, fill=(240, 236, 220), font=font)
    return img


spec = Image.open(os.path.join(OUT, "owner_spec.png")).convert("RGB")
spec = spec.crop((0, 0, 660, spec.height))          # (the drawing, without its legend)
for dn in ["south", "north", "east", "west"]:
    shots = sorted(p for p in glob.glob(os.path.join(new_dir, "new_%s_*.png" % dn)) if not p.endswith("_grid.png"))
    if not shots:
        print("no new shot for", dn)
        continue
    new = mid(Image.open(shots[0]).convert("RGB"))
    grid = shots[0][:-4] + "_grid.png"
    old_p = os.path.join(old_dir, "ramp_%s_0153.jpg" % dn)
    panels = [label(fit(spec), "OWNER'S SPEC")]
    if os.path.exists(old_p):
        o = Image.open(old_p).convert("RGB")
        o = o.crop((852, 0, o.width, 281))            # (0.15.3: the old sheet's top right panel)
        panels.append(label(fit(o), "0.15.3"))
    panels.append(label(fit(new), "NEW (0.15.4)"))
    if os.path.exists(grid):
        panels.append(label(fit(mid(Image.open(grid).convert("RGB"))), "NEW: red no walk, yellow rails, green paths"))
    w = sum(p.width for p in panels) + 6 * (len(panels) - 1)
    sheet = Image.new("RGB", (w, H), (20, 20, 24))
    x = 0
    for p in panels:
        sheet.paste(p, (x, 0))
        x += p.width + 6
    path = os.path.join(OUT, "ramp_%s.jpg" % dn)
    sheet.save(path, quality=86)
    print(path, sheet.size, "from", os.path.basename(shots[0]))
