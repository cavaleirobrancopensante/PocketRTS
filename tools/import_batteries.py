"""Cut the Clockwork battery cylinders out of art/clockwork/batteries.png into
assets/effects/battery_blue.png, battery_yellow.png (13-frame crackle loops) and
battery_charge.png (14 frames: an empty cylinder filling up, gauge green -> red).

Usage (from the repo root): python3 tools/import_batteries.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "art/clockwork/batteries.png"
OUT = "assets/effects"
H = 22          # height of a battery in game pixels
ROWS = {"battery_blue": (76, 225), "battery_yellow": (434, 579), "battery_charge": (786, 938)}

im = Image.open(SRC).convert("RGB")
a = np.asarray(im).astype(int)
bg = np.median(a[:5, :5].reshape(-1, 3), axis=0)
dist = np.abs(a - bg).sum(2)
alpha = np.clip((dist - 30) * 6, 0, 255).astype(np.uint8)
rgba = np.dstack([np.asarray(im), alpha])

for name, (y0, y1) in ROWS.items():
    band = (dist[y0:y1] > 40)
    cols = band.any(0)
    lab, n = ndimage.label(ndimage.binary_dilation(cols, iterations=6))
    frames = []
    for i in range(1, n + 1):
        xs = np.where(lab == i)[0]
        if len(xs) < 30:
            continue
        x0, x1 = xs[0], xs[-1] + 1
        sub = Image.fromarray(rgba[y0:y1, x0:x1], "RGBA")
        bb = sub.getbbox()
        sub = sub.crop(bb)
        s = H / sub.height
        sub = sub.resize((max(1, round(sub.width * s)), H), Image.BOX)
        # hard pixel-art alpha
        arr = np.asarray(sub).copy()
        arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
        frames.append(Image.fromarray(arr, "RGBA"))
    w = max(f.width for f in frames)
    strip = Image.new("RGBA", (w * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * w + (w - f.width) // 2, 0))
    strip.save(f"{OUT}/{name}.png")
    print(name, len(frames), "frames", w, "x", H)
