"""The labourer's carry (gold sack) and carry_keg strips get the legs of the NEW walk (ChatGPT sheets of
2026-10-24, installed by import_labourer_v2.py): body, arms and load stay from the carry strips, the legs
are cut from walk_<d> frame k and pasted under them with import_labourer_redraw.compose (hips under hips,
joined under the coat hem). All five views, 6 frames. West views are these mirrored by the game.

Sources: art/redraws/gait_src/<pose>_<d>.png (pristine carry strips; e, se, ne are made by
import_labourer_gait.py --snapshot, s and n are copied here the first time this runs). Runs after
import_labourer_v2.py in tools/rebuild_art.sh (it needs the new walk strips). Usage: python3 tools/import_labourer_carry_legs.py [--contact FILE]
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import import_labourer_redraw as R  # noqa: E402

OUT = os.path.join(ROOT, "assets/units/labourer")
SRC = os.path.join(ROOT, "art/redraws/gait_src")
W, H = 42, 35
DIRS = ["s", "se", "e", "ne", "n"]
POSES = ["carry", "carry_keg"]


def strip(path):
    im = np.array(Image.open(path).convert("RGBA"))
    assert im.shape[1] == W * 6, path
    return [im[:, i * W:(i + 1) * W].copy() for i in range(6)]


def run():
    os.makedirs(SRC, exist_ok=True)
    res = {}
    for p in POSES:
        for d in DIRS:
            src = os.path.join(SRC, f"{p}_{d}.png")
            if not os.path.exists(src):
                shutil.copy(os.path.join(OUT, f"{p}_{d}.png"), src)
            body, walk = strip(src), strip(os.path.join(OUT, f"walk_{d}.png"))
            res[(p, d)] = [R.compose(b, w) for b, w in zip(body, walk)]
    for (p, d), fr in res.items():
        Image.fromarray(np.concatenate(fr, 1)).save(os.path.join(OUT, f"{p}_{d}.png"))
    return res


def contact(path, res, zoom=4):
    rows = [res[(p, d)] for p in POSES for d in DIRS]
    sheet = Image.new("RGBA", (W * 6, H * len(rows)), (60, 90, 60, 255))
    for i, fr in enumerate(rows):
        for k, f in enumerate(fr):
            sheet.alpha_composite(Image.fromarray(f), (W * k, H * i))
    sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST).save(path)


if __name__ == "__main__":
    r = run()
    if "--contact" in sys.argv:
        contact(sys.argv[sys.argv.index("--contact") + 1], r)
