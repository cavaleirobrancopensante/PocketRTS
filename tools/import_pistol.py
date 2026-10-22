"""The Horseman and the Cuirassier firing their pistol from the saddle.

Sources (the designer's sheets, flat slate background, every drawing on its own darker cell):
  art/crown/horseman_pistol.png     5 rows (S, SE, E, NE, N, the order of the left half of
  art/crown/cuirassier_pistol.png   horseman_attack_death.png) x 4 frames: draw, aim, fire
                                    (muzzle flash and smoke), lower

Cut like tools/import_horseman.py cuts horseman_attack_death.png (its machinery is reused):
the foreground (not a background colour, flooded in from the border) is taken per cell, so
the smoke puff drawn apart from the rider stays with his frame; specks are dropped. The cells
are found by their colour (import_horseman.panels) and ordered row by row.

Scale and anchoring, so the rider doesn't jump when the strip changes: one scale per row,
the draw frame (the pistol still low, no smoke) as tall as the unit's own standing frame in
that direction (assets/units/<art>/idle_<dir>.png, frame 0: the Horseman's for the Horseman,
the Cuirassier's for the Cuirassier); every frame on the 98x70 Cuirassier cell with the
horse's torso centred where the Cuirassier's idle torso is for that direction (as the
Horseman's strips are), and its lowest hoof on the anchor line. The W-side directions are
these mirrored by the game, as for every mounted strip. The red coat and saddle cloth are
snapped to the team key reds (to_game), so they take the player colour.

Output: assets/units/{horseman,cuirassier}/pistol_{s,se,e,ne,n}.png (4 frames each) and the
"pistol_<dir>" counts in those two entries of scripts/art_data.gd (added or replaced; nothing
else in them is touched). Horse coat and veterancy trim masks: tools/import_horse_coats.py and
tools/import_vet_trim.py (run after this; see rebuild_art.sh).

Usage (from the repo root): python3 tools/import_pistol.py [--contact DIR]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import import_horseman as hm  # noqa: E402
sys.argv = _argv
from import_art import load  # noqa: E402

SHEETS = {"horseman": "art/crown/horseman_pistol.png", "cuirassier": "art/crown/cuirassier_pistol.png"}
DIRS = ["s", "se", "e", "ne", "n"]
N_FRAMES = 4
ART_DATA = "scripts/art_data.gd"
CONTACT = _argv[_argv.index("--contact") + 1] if "--contact" in _argv else None


def cells_of(px):
    """The 20 drawing cells (y0, y1, x0, x1), row by row, left to right."""
    cols = hm.bg_colours(px[..., :3].astype(float))
    pans = hm.panels(px, cols)
    pans = [p for p in pans if (p[1] - p[0]) > 100 and (p[3] - p[2]) > 100]
    assert len(pans) == len(DIRS) * N_FRAMES, "expected 20 cells, found %d" % len(pans)
    pans.sort(key=lambda p: p[0])
    rows = [sorted(pans[i * N_FRAMES:(i + 1) * N_FRAMES], key=lambda p: p[2]) for i in range(len(DIRS))]
    return rows


def frame_in(fg, cell, inset=3):
    """The drawing in one cell: its foreground (specks dropped), and the main body (the
    biggest piece: horse and rider, without the smoke)."""
    y0, y1, x0, x1 = cell
    m = np.zeros_like(fg)
    m[y0 + inset:y1 - inset, x0 + inset:x1 - inset] = fg[y0 + inset:y1 - inset, x0 + inset:x1 - inset]
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return m, m, None
    size = ndimage.sum(m, lab, np.arange(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = size >= 12
    m = keep[lab]
    body = lab == (int(np.argmax(size)) + 1)
    ys, xs = np.nonzero(m)
    return m, body, (ys.min(), ys.max() + 1, xs.min(), xs.max() + 1)


def import_art(art, cell, anchor, ref_tx, report):
    W, H = cell
    AX, AY = anchor
    px = load(SHEETS[art])
    fg, bgc = hm.fg_mask(px)
    rows = cells_of(px)
    strips = {}
    trial = 0.3
    for d, row in zip(DIRS, rows):
        frames = [frame_in(fg, c) for c in row]
        # the row's scale: the draw frame as tall as his own standing frame
        own = np.array(Image.open(f"assets/units/{art}/idle_{d}.png").convert("RGBA"))[:, :W]
        ys = np.flatnonzero((own[..., 3] > 0).any(1))
        own_h = float(ys.max() + 1 - ys.min())
        m0, b0, box0 = frames[0]
        f0 = hm.to_game(hm.crop(px, m0, box0)[0], trial, bgc)
        ys0 = np.flatnonzero((f0[..., 3] > 0).any(1))
        scale = trial * own_h / float(ys0.max() + 1 - ys0.min())
        report.append(f"{art} pistol_{d}: scale {scale:.4f}")
        out = []
        for i, (m, body, box) in enumerate(frames):
            img, (y0, x0) = hm.crop(px, m, box)
            f = hm.to_game(img, scale, bgc)
            # the body alone, shrunk the same way, for the torso and the ground line
            bimg, _ = hm.crop(px, body, box)
            fb = hm.to_game(bimg, scale, bgc)
            if fb.shape[:2] != f.shape[:2]:
                fb = np.array(Image.fromarray(fb).resize((f.shape[1], f.shape[0]), Image.NEAREST))
            ba = fb[..., 3] > 0
            gy = float(np.flatnonzero(ba.any(1)).max() + 1)
            tx = hm.torso_x(ba)
            c, lost = hm.place(f, ref_tx[d] - tx, AY, gy, cell)
            if lost:
                report.append(f"  pistol_{d} frame {i}: {lost} px off the cell")
            out.append(c)
        strips[d] = out
    os.makedirs(f"assets/units/{art}", exist_ok=True)
    for d, cells in strips.items():
        Image.fromarray(np.concatenate(cells, 1)).save(f"assets/units/{art}/pistol_{d}.png")
    return strips


def write_counts(art):
    src = open(ART_DATA).read()
    m = re.search(r'\t"%s": \{"cell".*?\n\t\}\},\n' % art, src, re.S)
    block = m.group(0)
    block = re.sub(r'\t\t"pistol_\w+": \d+,\n', "", block)
    lines = [l for l in block.split("\n")]
    head, body, tail = lines[0], lines[1:-2], lines[-2:]
    body += ['\t\t"pistol_%s": %d,' % (d, N_FRAMES) for d in DIRS]
    body.sort()
    block2 = "\n".join([head] + body + tail)
    open(ART_DATA, "w").write(src[:m.start()] + block2 + src[m.end():])


def main():
    cell, anchor = hm.cell_info()
    ref_tx = {d: hm.torso_x(hm.ref_frame("idle", d)[..., 3] > 0) for d in DIRS}
    report = []
    made = {}
    for art in SHEETS:
        made[art] = import_art(art, cell, anchor, ref_tx, report)
        write_counts(art)
    print("\n".join(report))
    print("pistol: horseman and cuirassier, pistol_{s,se,e,ne,n} x %d frames" % N_FRAMES)
    if CONTACT:
        contact(cell, anchor)


def contact(cell, anchor, k=3):
    """x3: each direction's idle frame 0 then the 4 pistol frames, on grass, anchor marked."""
    W, H = cell
    AX, AY = anchor
    rows = []
    for art in SHEETS:
        for d in DIRS:
            idle = np.array(Image.open(f"assets/units/{art}/idle_{d}.png").convert("RGBA"))[:, :W]
            pis = np.array(Image.open(f"assets/units/{art}/pistol_{d}.png").convert("RGBA"))
            rows.append(np.concatenate([idle, pis], 1))
    sheet = Image.new("RGB", (rows[0].shape[1] * k + 8, len(rows) * (H * k + 4)), (24, 24, 24))
    for i, a in enumerate(rows):
        bgi = np.zeros((a.shape[0], a.shape[1], 3), np.uint8)
        bgi[:] = (76, 112, 52)
        al = a[..., 3:4] / 255.0
        img = (a[..., :3] * al + bgi * (1 - al)).astype(np.uint8)
        for c in range(a.shape[1] // W):
            img[int(AY), c * W + int(AX) - 2:c * W + int(AX) + 3] = (255, 255, 255)
            img[:, c * W] = (40, 70, 30)
        sheet.paste(Image.fromarray(img).resize((a.shape[1] * k, a.shape[0] * k), Image.NEAREST), (4, i * (H * k + 4)))
    os.makedirs(CONTACT, exist_ok=True)
    sheet.save(os.path.join(CONTACT, "contact_pistol.png"))


if __name__ == "__main__":
    main()
