"""Contact sheets of the Crown Labourer (assets/units/labourer/), one PNG per pose, for audits.

Every direction (s, se, e, ne, n) is a row of its frames, each followed by a row of the same
frames mirrored the way scripts/unit.gd draws the west views (sw = se mirrored, w = e mirrored,
nw = ne mirrored), at 4x nearest on grass green, with the frame number and the ground line
(the anchor row, y 33) marked so sliding feet and anchor drift show. Also prints, per strip,
the frame size and each frame's bounding box and feet span.

    python3 tools/labourer_contact.py [OUT_DIR]       (default /tmp/lab_contact)
Needs Pillow and NumPy.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/units/labourer")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lab_contact"
POSES = ["walk", "carry", "carry_keg", "idle", "idle_keg", "mine", "build", "bury", "death", "death_keg"]
DIRS = ["s", "se", "e", "ne", "n"]
W, H, S = 42, 35, 4
ANCHOR_Y = 33


def frames(path):
    im = Image.open(path).convert("RGBA")
    return [im.crop((i * W, 0, (i + 1) * W, H)) for i in range(im.width // W)]


def main():
    os.makedirs(OUT, exist_ok=True)
    for pose in POSES:
        rows = []
        for d in DIRS:
            fr = frames(os.path.join(SRC, f"{pose}_{d}.png"))
            rows.append((d, fr))
            rows.append((d + " mirrored (" + {"s": "s", "se": "sw", "e": "w", "ne": "nw", "n": "n"}[d] + ")",
                         [f.transpose(Image.FLIP_LEFT_RIGHT) for f in fr]))
            for k, f in enumerate(fr):
                a = np.array(f)[..., 3] > 20
                ys, xs = np.nonzero(a)
                feet = xs[ys >= ys.max() - 3]
                print(f"{pose}_{d}[{k}] bbox x{xs.min()}-{xs.max()} y{ys.min()}-{ys.max()} feet x{feet.min()}-{feet.max()}")
        n = max(len(f) for _, f in rows)
        sheet = Image.new("RGBA", (n * W * S + 150, len(rows) * H * S), (90, 110, 90, 255))
        dr = ImageDraw.Draw(sheet)
        for r, (name, fr) in enumerate(rows):
            dr.text((4, r * H * S + 4), name, fill=(255, 255, 255, 255))
            for k, f in enumerate(fr):
                x0 = 150 + k * W * S
                sheet.alpha_composite(f.resize((W * S, H * S), Image.NEAREST), (x0, r * H * S))
                dr.line([(x0, r * H * S + (ANCHOR_Y + 1) * S), (x0 + W * S, r * H * S + (ANCHOR_Y + 1) * S)], fill=(255, 255, 0, 120))
                dr.line([(x0 + 21 * S, r * H * S), (x0 + 21 * S, r * H * S + H * S)], fill=(255, 255, 255, 50))
                dr.text((x0 + 2, r * H * S + 2), str(k), fill=(255, 255, 255, 255))
        sheet.save(os.path.join(OUT, f"{pose}.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
