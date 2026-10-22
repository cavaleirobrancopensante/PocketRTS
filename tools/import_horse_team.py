"""A gun's team horse: the draught horse in harness that a Field Cannon, Mortar or Powder Wagon
draws in front of its own horse for each extra horse of its team (Unit.team_horses).

  art/crown/horse_team.png   1536x1024, a dark navy slate: 5 rows (S, SE, E, NE, N), 6 frames
                             each of a pulling walk. A grey horse with collar, harness pad,
                             blinkers and long traces trailing behind it; no saddle, no rider.

Frames are found by the foreground (tools/import_horse_units.py's slate test and frame finder).
Fix: in the S row, frames 3-6 have a trace sticking out sideways to the left of the horse:
everything left of the horse's body there is erased (the body: the columns at least ~20
sheet pixels tall; the trace is a thin line).

Scale: the E row's horse stands as tall as the riderless horse (46 px, like
assets/units/horse); every frame is centred on its body (its tall columns: not the traces) and
stands with its lowest hoof on the anchor line. Cell 112x70, anchor 56,66 (the traces reach
back past the body). The red-brown collar and harness are leather, not team colour: any pixel
that would hit the shader's key reds is nudged off them (unteam).

Writes assets/units/horse_team/walk_<dir>.png (6 frames) and idle_<dir>.png (the first walk
frame) and the "horse_team" entry of scripts/art_data.gd. Coat masks: tools/import_horse_coats.py
(its "horse_team" entry; run after this).

Usage (from the repo root): python3 tools/import_horse_team.py [--contact DIR]
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_horse_units import load, runs, cut_frame, shrink, place, write_art_data, frames_in_band  # noqa: E402
from import_cannon2 import clean  # noqa: E402
from import_art import unteam  # noqa: E402

NAME = "horse_team"
DIRS = ["s", "se", "e", "ne", "n"]
CELL = (112, 70)
ANCHOR = (56, 66)
REF_H = 46            # the riderless horse's standing height in its E row
BODY_MIN = 20         # (sheet px) a column at least this tall is the horse's body, not a trace


def body_cols(img):
    """The horse's body columns of a frame (sheet resolution): tall enough not to be a trace."""
    occ = (img[..., 3] > 0).sum(0)
    return np.nonzero(occ >= BODY_MIN)[0]


def main():
    px, fg, bg = load(NAME)
    bands = [b for b in runs(fg.sum(1) > 0, 4) if b[1] - b[0] > 25]
    assert len(bands) == 5, "%d rows found" % len(bands)
    rows = []
    for d, (y0, y1) in zip(DIRS, bands):
        fr = frames_in_band(fg, y0, y1, [("walk", 0)], {"walk": 6})
        assert len(fr) == 6, "%s: %d frames" % (d, len(fr))
        frames = []
        for i, (_, x0, x1) in enumerate(fr):
            img = cut_frame(px, fg, bg, y0, y1, x0, x1)
            if d == "s" and i >= 2:
                # the stray trace to the left of the horse: nothing left of its body
                bc = body_cols(img)
                img[:, :max(int(bc.min()) - 2, 0)] = 0
            frames.append((img, x0))
        rows.append((d, y0, frames))
    hs = []
    for d, y0, frames in rows:
        if d == "e":
            for img, _ in frames:
                ys = np.nonzero((img[..., 3] > 0).any(1))[0]
                hs.append(ys.max() - ys.min() + 1)
    scale = REF_H / float(np.median(hs))
    print("%s: scale %.3f" % (NAME, scale))
    strips = {}
    for d, y0, frames in rows:
        cells = []
        for img, x0 in frames:
            a = img[..., 3] > 0
            ys = np.nonzero(a.any(1))[0]
            top, bot = int(ys.min()), int(ys.max())
            bc = body_cols(img)
            cx = x0 + (bc.min() + bc.max()) / 2.0
            crop = img[top:bot + 1]
            small = unteam(clean(shrink(crop, scale)))
            cells.append(place(CELL, ANCHOR, small, x0, y0 + top, cx, y0 + bot, scale))
        strips[("walk", d)] = cells
        strips[("idle", d)] = cells[:1]
    os.makedirs("assets/units/%s" % NAME, exist_ok=True)
    counts = {}
    for (g, d), lst in strips.items():
        Image.fromarray(np.concatenate(lst, 1)).save("assets/units/%s/%s_%s.png" % (NAME, g, d))
        counts["%s_%s" % (g, d)] = len(lst)
    write_art_data(NAME, CELL, ANCHOR, counts)
    print(NAME, ", ".join("%s %d" % (k, v) for k, v in sorted(counts.items())))
    if "--contact" in sys.argv:
        out = sys.argv[sys.argv.index("--contact") + 1]
        os.makedirs(out, exist_ok=True)
        keys = [("walk", d) for d in DIRS]
        cw, ch = CELL
        sheet = Image.new("RGBA", (6 * cw * 3, len(keys) * ch * 3), (104, 132, 84, 255))
        for i, k in enumerate(keys):
            s = Image.fromarray(np.concatenate(strips[k], 1))
            sheet.alpha_composite(s.resize((s.width * 3, s.height * 3), Image.NEAREST), (0, i * ch * 3))
        sheet.save(os.path.join(out, "contact_%s.png" % NAME))


if __name__ == "__main__":
    main()
