"""The labourer WALKING with a loaded shovel (Powder Mill workflow): strips walk_shovel_<s|se|e|ne|n>.png.

18 frames of 42x35, anchor (21, 33) like every labourer strip: frames 0-5 the saltpetre load
(grey-white), 6-11 sulphur (yellow), 12-17 charcoal (black). The body is the 'lift' frame of
shovel_<d>.png (the loaded blade raised: frame 4*load + 1), the legs are the new walk's
(walk_<d> frame k, 6 frames) put under it with import_labourer_redraw.compose (hips under hips,
joined under the coat hem), the body rising one row at the two passing frames (2 and 5) as the
carry strips do. West views are these mirrored by the game. Code-drawn composite: it is listed in
docs/art_style_inconsistency.md. scripts/unit.gd drives it from the distance walked (LAB_STRIDE
37 px a 6-frame cycle) and picks the load from the heap he fetched it at.

    python3 tools/import_labourer_shovel_walk.py [--contact FILE]
Run after import_labourer_shovel.py and the walk passes (tools/rebuild_art.sh). Needs Pillow and NumPy.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import import_labourer_redraw as R  # noqa: E402

OUT = os.path.join(ROOT, "assets/units/labourer")
W, H = 42, 35
DIRS = ["s", "se", "e", "ne", "n"]


def frames(path, n):
    im = np.array(Image.open(path).convert("RGBA"))
    assert im.shape[1] == W * n, path
    return [im[:, i * W:(i + 1) * W].copy() for i in range(n)]


def run():
    res = {}
    for d in DIRS:
        shovel = frames(os.path.join(OUT, f"shovel_{d}.png"), 12)
        walk = frames(os.path.join(OUT, f"walk_{d}.png"), 6)
        out = []
        for load in range(3):
            body = shovel[load * 4 + 1]
            for k in range(6):
                b = R.shift(body, 0, -1) if k in (2, 5) else body
                out.append(R.compose(b, walk[k]))
        res[d] = out
        Image.fromarray(np.concatenate(out, 1)).save(os.path.join(OUT, f"walk_shovel_{d}.png"))
    return res


def contact(path, res, zoom=4):
    sheet = Image.new("RGBA", (W * 18, H * len(DIRS)), (60, 90, 60, 255))
    for i, d in enumerate(DIRS):
        for k, f in enumerate(res[d]):
            sheet.alpha_composite(Image.fromarray(f), (W * k, H * i))
    sheet.resize((sheet.width * zoom // 2, sheet.height * zoom // 2), Image.NEAREST).save(path)


if __name__ == "__main__":
    r = run()
    if "--contact" in sys.argv:
        contact(sys.argv[sys.argv.index("--contact") + 1], r)
