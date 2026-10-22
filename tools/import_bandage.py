"""The Missionary bandaging a dismounted rider, from the designer's sheets (flat slate):

  art/crown/mount/missionary_bandage_a.png  4 rows x 6 frames: the Missionary (left) kneeling
        over the light Horseman (right), seen from the east (rows 1 and 2, near duplicates:
        row 1 is the cleaner), the same with the Cuirassier (row 3), and the Cuirassier from
        behind (row 4, the north view; its 1st frame has no cuirass)
  art/crown/mount/missionary_bandage_b.png  4 rows x 8 frames, each row: frames 1-4 the
        Horseman, 5-7 the Cuirassier, 8 the Cuirassier alone (not used). Rows 1-3 are seen
        from the south-east; row 4 shows the Missionary from behind (north) with the Horseman.

Frames are found by themselves: rows by empty lines of the slate, frames by empty columns.
Which frames make each strip is FRAMES (sheet, row, frames, 1-based). There is no front (S)
view: the game's _set_anim falls back to the SE strip for S, and to N for NE.

Scale: one per sheet, so that the kneeling Missionary (the left part of every frame: hat to
knees) is as tall as in his old bandage strips (MISSIONARY_H). Each frame is registered on
the Missionary (his middle and his knees, so he doesn't jitter), and each strip is centred on
the pair of men (the dropped weapon lying in front is left out of the centring).

Two men are wider than the Missionary's 48x40 cell, so the strips are their own art keys:
missionary_bandage_h (the Horseman) and missionary_bandage_c (the Cuirassier), on a 64x44
cell (anchor 32,39), each with bandage_<e|se|n>. Red coats and the stole are snapped to the
team key reds (the stole's crimson too). unit.gd plays them while a Missionary bandages a "dismounted" patient.

Run after tools/import_art.py (rebuild_art.sh does). Writes assets/units/<art>/bandage_<dir>.png
and the two art_data.gd entries (added or replaced).

Usage (from the repo root): python3 tools/import_bandage.py [--contact DIR]
"""
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import clean, defringe  # noqa: E402
from import_horse_units import load, runs, shrink  # noqa: E402

ART_DATA = "scripts/art_data.gd"
CELL = (64, 44)
ANCHOR = (32, 39)
MISSIONARY_H = 32          # the kneeling Missionary in assets/units/missionary/bandage_*.png
LEFT = 0.4                 # the Missionary is the left 40% of a frame

SHEETS = {"a": "mount/missionary_bandage_a", "b": "mount/missionary_bandage_b"}
ROWS = {"a": 4, "b": 4}
# art -> dir -> (sheet, row, [frames]) (1-based, as on the sheet)
FRAMES = {
    "missionary_bandage_h": {
        "e": ("a", 1, [2, 3, 4, 5]),
        "se": ("b", 1, [1, 2, 3]),
        "n": ("b", 4, [1, 2, 3]),
    },
    "missionary_bandage_c": {
        "e": ("a", 3, [2, 3, 4, 5]),
        "se": ("b", 1, [5, 6, 7]),
        "n": ("a", 4, [2, 3, 4, 5]),
    },
}


def snap_stole(img):
    """snap_team, and also the darker, bluish red of the stole in some frames (seen from
    behind: crimson going to magenta), which snap_team's rule leaves out."""
    r, g, b = (img[..., i].astype(int) for i in range(3))
    m = (img[..., 3] > 0) & (r >= 90) & (g <= r * 0.3) & (b > r * 0.32) & (b <= r * 0.75)
    img[m, 2] = (r[m] * 0.3).astype(np.uint8)
    return snap_team(img)


def find_frames(fg):
    """[[(x0, x1), ...] per row], and the row bands."""
    bands = [b for b in runs(fg.sum(1) > 0, 4) if b[1] - b[0] > 25]
    out = []
    for y0, y1 in bands:
        cols = [c for c in runs(fg[y0:y1].sum(0) > 0, 6) if c[1] - c[0] > 6]
        out.append(cols)
    return bands, out


def cut(px, fg, bg, y0, y1, x0, x1):
    img = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    img[..., :3] = px[y0:y1, x0:x1]
    img[..., 3] = np.where(fg[y0:y1, x0:x1], 255, 0)
    return defringe(img, bg)


def missionary(img):
    """(x middle, top, knees) of the Missionary: the left part of the frame."""
    w = img.shape[1]
    a = img[:, :int(w * LEFT), 3] > 0
    ys, xs = np.nonzero(a)
    return float(xs.mean()), int(ys.min()), int(ys.max())


def main():
    sheets = {}
    for k, name in SHEETS.items():
        px, fg, bg = load(name)
        bands, frames = find_frames(fg)
        assert len(bands) == ROWS[k], "%s: %d rows found" % (name, len(bands))
        hs = []
        for (y0, y1), cols in zip(bands, frames):
            for x0, x1 in cols[:7]:
                _, top, knee = missionary(cut(px, fg, bg, y0, y1, x0, x1))
                hs.append(knee - top + 1)
        scale = MISSIONARY_H / float(np.median(hs))
        print("%s: %d rows, %s frames, scale %.3f" % (name, len(bands), [len(c) for c in frames], scale))
        sheets[k] = (px, fg, bg, bands, frames, scale)

    strips = {}
    for art, dirs in FRAMES.items():
        for d, (k, row, picks) in dirs.items():
            px, fg, bg, bands, frames, scale = sheets[k]
            y0, y1 = bands[row - 1]
            items = []
            for f in picks:
                x0, x1 = frames[row - 1][f - 1]
                img = cut(px, fg, bg, y0, y1, x0, x1)
                mx, top, knee = missionary(img)
                # the pair (not the weapon lying in front, below his knees)
                a = img[:knee - 4, :, 3] > 0
                xs = np.nonzero(a.any(0))[0]
                items.append((img, mx, knee, (xs.min() + xs.max()) / 2.0 - mx))
            off = float(np.median([it[3] for it in items]))
            cells = []
            for img, mx, knee, _ in items:
                ys, xs = np.nonzero(img[..., 3] > 0)
                crop = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
                small = snap_stole(clean(shrink(crop, scale)))
                out = np.zeros((CELL[1], CELL[0], 4), np.uint8)
                # the pair's middle on the anchor, the Missionary's knees on the ground line
                x = int(round(ANCHOR[0] - (mx + off - xs.min()) * scale))
                y = int(round(ANCHOR[1] - (knee - ys.min()) * scale))
                h, w = small.shape[:2]
                sx0, sy0 = max(0, -x), max(0, -y)
                dx0, dy0 = max(0, x), max(0, y)
                ww, hh = min(w - sx0, CELL[0] - dx0), min(h - sy0, CELL[1] - dy0)
                part = small[sy0:sy0 + hh, sx0:sx0 + ww]
                if ww < w or hh < h:
                    print("  warning: %s %s frame clipped" % (art, d))
                m = part[..., 3] > 0
                out[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
                cells.append(out)
            strips[(art, d)] = cells

    for art in FRAMES:
        os.makedirs("assets/units/%s" % art, exist_ok=True)
        counts = {}
        for d in FRAMES[art]:
            Image.fromarray(np.concatenate(strips[(art, d)], 1)).save("assets/units/%s/bandage_%s.png" % (art, d))
            counts["bandage_%s" % d] = len(strips[(art, d)])
        write_art_data(art, counts)
        print(art, ", ".join("%s %d" % (k, v) for k, v in sorted(counts.items())))

    if "--contact" in sys.argv:
        out = sys.argv[sys.argv.index("--contact") + 1]
        os.makedirs(out, exist_ok=True)
        keys = sorted(strips)
        W = max(len(strips[k]) for k in keys) * CELL[0]
        sheet = Image.new("RGBA", (W * 4, len(keys) * CELL[1] * 4), (104, 132, 84, 255))
        for i, k in enumerate(keys):
            s = Image.fromarray(np.concatenate(strips[k], 1))
            sheet.alpha_composite(s.resize((s.width * 4, s.height * 4), Image.NEAREST), (0, i * CELL[1] * 4))
        sheet.save(os.path.join(out, "contact_bandage.png"))


def write_art_data(art, counts):
    src = open(ART_DATA).read()
    lines = ['\t"%s": {"cell": Vector2i(%d, %d), "anchor": Vector2(%g, %g), "frames": {' % ((art,) + CELL + ANCHOR)]
    for k in sorted(counts):
        lines.append('\t\t"%s": %d,' % (k, counts[k]))
    lines.append("\t}},\n")
    block = "\n".join(lines)
    m = re.search(r'\t"%s": \{"cell".*?\n\t\}\},\n' % art, src, re.S)
    if m:
        src = src[:m.start()] + block + src[m.end():]
    else:
        m = re.search(r'\t"missionary": \{"cell".*?\n\t\}\},\n', src, re.S)
        src = src[:m.end()] + block + src[m.end():]
    open(ART_DATA, "w").write(src)


if __name__ == "__main__":
    main()
