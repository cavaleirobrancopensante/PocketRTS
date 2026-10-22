"""The Crown Horseman: the unarmoured cavalryman (feathered hat, red coat) that a Cuirassier is
before his Armour refit. Same kind in the game ("cuirassier"), his own sprites ("horseman").

Sources (flat slate backgrounds, ChatGPT sheets):
  art/crown/horseman.png               5 rows (S, SE, E, NE, N); each row ~2 standing frames,
                                       then the gallop (8-10 frames; rows may differ)
  art/crown/horseman_attack_death.png  left block: 5 rows x 4 sabre blows; right block:
                                       5 rows x 4 death frames (the horse rears and falls,
                                       the rider is thrown, his hat lies on the ground); each
                                       drawing on its own darker panel, a divider in between

Frames are found automatically (no hand-placed boxes): the foreground (everything that is not
one of the sheet's background colours, flooded in from the border) is dilated a few pixels
and labelled, so a tail or a sabre drawn apart joins its horse; frames are then grouped into
rows by height and ordered left to right. On the second sheet the panels are found by their
colour and every frame goes to the panel it sits on (row = panel row, column = panel column).

Scale: one factor per direction (the Cuirassier's rows were each brought to one height):
on the gallop sheet the standing rider's coat top stands as high over the ground as the
Cuirassier's in that direction (assets/units/cuirassier idle); on the fight sheet the sabre
frames cover as much as the Horseman's own standing frames. So swapping between Horseman and
Cuirassier art doesn't jump. Placement on the Cuirassier's cell (98x70,
anchor (49, 66)): every frame's torso is centred where the Cuirassier's idle torso is for that
direction; the row's ground line (the lowest hoof on the sheet) goes on the anchor line. The
death frames keep their place on their panel relative to the row's sabre frames.

Output: assets/units/horseman/{idle,walk,attack,death}_{s,se,e,ne,n}.png and the "horseman"
entry of scripts/art_data.gd (added or replaced; nothing else is touched). The red coat and
saddle cloth are snapped to the team key reds. Horse coat masks: tools/import_horse_coats.py
(run after this; see rebuild_art.sh).

Usage (from the repo root): python3 tools/import_horseman.py [--contact DIR]
  (--contact: x3 contact sheet of every strip next to the Cuirassier's)
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load  # noqa: E402
from import_cannon2 import clean, defringe, shrink, snap_team  # noqa: E402

GALLOP = "art/crown/horseman.png"
FIGHT = "art/crown/horseman_attack_death.png"
OUT = "assets/units/horseman"
REF = "assets/units/cuirassier"
ART_DATA = "scripts/art_data.gd"
DIRS = ["s", "se", "e", "ne", "n"]
IDLE_N = 2                     # standing frames at the start of each gallop row
CONTACT = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None


# ---------------------------------------------------------------- the sheets

def bg_colours(rgb):
    """The sheet's background colours: the border's median, and (if there are panels) the
    commonest dark colour inside that is not it."""
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    outer = np.median(border, 0)
    q = (rgb // 4).reshape(-1, 3)
    vals, counts = np.unique(q, axis=0, return_counts=True)
    order = np.argsort(-counts)
    cols = [outer]
    for i in order[:12]:
        c = vals[i] * 4 + 2.0
        if np.abs(c - outer).max() > 6 and c.max() < 80 and counts[i] > q.shape[0] * 0.02:
            cols.append(c)
            break
    return cols


def fg_mask(px, tol=13):
    """Foreground: not near any background colour (flooded from the border, plus enclosed
    pockets of background bigger than a speck), and not a divider line."""
    rgb = px[..., :3].astype(float)
    cols = bg_colours(rgb)
    near = np.zeros(rgb.shape[:2], bool)
    for c in cols:
        near |= np.abs(rgb - c).max(-1) <= tol
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    lab2, n2 = ndimage.label(near & ~bg)
    if n2:
        size = ndimage.sum(near, lab2, np.arange(1, n2 + 1))
        bg |= (size >= 200)[lab2 - 1] & (lab2 > 0)
    fg = ~bg
    # dividers: whole columns / rows of foreground (a frame never spans the sheet)
    h, w = fg.shape
    fg[:, fg.mean(0) > 0.8] = False
    fg[fg.mean(1) > 0.8, :] = False
    return fg, cols[0]


def find_frames(fg, dilate=6, min_area=1500):
    """[(mask, bbox (y0, y1, x0, x1))] of every drawing, a dilation joining its pieces."""
    big = ndimage.binary_dilation(fg, iterations=dilate)
    lab, n = ndimage.label(big)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = (lab == i + 1) & fg
        if m.sum() < min_area:
            continue
        ys, xs = np.nonzero(m)
        out.append((m, (ys.min(), ys.max() + 1, xs.min(), xs.max() + 1)))
    return out


def rows_of(frames, n_rows=5):
    """Frames grouped into n_rows rows by their vertical centre, each left to right."""
    cy = np.array([(b[0] + b[1]) / 2.0 for _, b in frames])
    order = np.argsort(cy)
    gaps = np.diff(cy[order])
    cuts = sorted(np.argsort(-gaps)[:n_rows - 1])
    rows, start = [], 0
    for c in cuts + [len(order) - 1]:
        rows.append(sorted([frames[i] for i in order[start:c + 1]], key=lambda f: f[1][2]))
        start = c + 1
    return rows


def panels(px, cols):
    """Panel boxes (y0, y1, x0, x1) of the second sheet: big regions of the panel colour."""
    if len(cols) < 2:
        return []
    rgb = px[..., :3].astype(float)
    m = np.abs(rgb - cols[1]).max(-1) <= 6
    m = ndimage.binary_closing(m, iterations=3)
    lab, n = ndimage.label(m)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if hh * ww > 8000 and hh > 60 and ww > 60:
            out.append((sl[0].start, sl[0].stop, sl[1].start, sl[1].stop))
    # (the grid's cells: the 40 biggest; a stray patch of the colour elsewhere is not one)
    out.sort(key=lambda p: -(p[1] - p[0]) * (p[3] - p[2]))
    return out[:40] if len(out) > 40 else out


def crop(px, m, box, pad=4):
    y0, y1, x0, x1 = box
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(px.shape[0], y1 + pad), min(px.shape[1], x1 + pad)
    img = px[y0:y1, x0:x1].copy()
    mm = m[y0:y1, x0:x1]
    img[..., 3] = np.where(mm, 255, 0)
    img[~mm] = 0
    return img.clip(0, 255).astype(np.uint8), (y0, x0)


def to_game(img, scale, bgc):
    out = snap_team(shrink(img, scale))
    d = defringe(out, bgc)
    rgb = out[..., :3].astype(float)
    k = (rgb * bgc).sum(-1) / (bgc * bgc).sum()
    lost = (out[..., 3] > 0) & (d[..., 3] == 0) & (k < 0.75)       # the grey horse's dark edge
    d[lost] = out[lost]
    return clean(d, min_size=4, keep_near=1)


# ---------------------------------------------------------------- measuring a horse

def torso_band(a):
    ys = np.flatnonzero(a.any(1))
    top, bot = ys.min(), ys.max() + 1
    h = bot - top
    return top + int(h * 0.50), top + int(h * 0.72)


def red_height(f):
    """Ground (the frame's lowest pixel) to the top of the team-red coat."""
    a = f[..., 3] > 0
    red = a & (f[..., 1] == 0) & (f[..., 2] == 0) & ((f[..., 0] == 255) | (f[..., 0] == 150))
    return float(np.flatnonzero(a.any(1)).max() + 1 - np.flatnonzero(red.any(1)).min())


def torso_x(a):
    y0, y1 = torso_band(a)
    xs = np.nonzero(a[y0:y1])[1]
    return float(xs.mean())


def cell_info():
    src = open(ART_DATA).read()
    m = re.search(r'"cuirassier": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    return (int(m.group(1)), int(m.group(2))), (float(m.group(3)), float(m.group(4)))


def ref_frame(anim, d, i=0):
    (W, H), _ = cell_info()
    a = np.array(Image.open(f"{REF}/{anim}_{d}.png").convert("RGBA"))
    return a[:, i * W:(i + 1) * W]


def place(f, x_at, y_ground, gy, cell):
    """Put game frame f (ground line at its row gy) on a cell so its x_at lands... (see main)."""
    W, H = cell
    out = np.zeros((H, W, 4), np.uint8)
    ox = int(round(x_at))
    oy = int(round(y_ground - gy))
    fh, fw = f.shape[:2]
    ya, yb = max(0, oy), min(H, oy + fh)
    xa, xb = max(0, ox), min(W, ox + fw)
    if yb > ya and xb > xa:
        out[ya:yb, xa:xb] = f[ya - oy:yb - oy, xa - ox:xb - ox]
    lost = int((f[..., 3] > 0).sum() - (out[..., 3] > 0).sum())
    return out, lost


# ---------------------------------------------------------------- main

def main():
    cell, (AX, AY) = cell_info()
    W, H = cell
    ref_tx = {d: torso_x(ref_frame("idle", d)[..., 3] > 0) for d in DIRS}
    strips = {}
    report = []

    # --- the gallop sheet: idle + walk
    px = load(GALLOP)
    fg, bgc = fg_mask(px)
    rows = rows_of(find_frames(fg))
    report.append("gallop sheet rows: %s" % [len(r) for r in rows])
    # one scale per row: the rider's coat top to the ground as high as the Cuirassier's in
    # that direction (his rows were each brought to one height), so the swap doesn't jump
    trial = 0.3
    scales = {}
    for d, row in zip(DIRS, rows):
        hs = [red_height(to_game(crop(px, m, b)[0], trial, bgc)) for m, b in row[:IDLE_N]]
        scales[d] = trial * red_height(ref_frame("idle", d)) / float(np.median(hs))
    report.append("gallop scales %s" % {d: round(v, 4) for d, v in scales.items()})
    for d, row in zip(DIRS, rows):
        ground = max(b[1] for _, b in row)
        scale = scales[d]
        for anim, part in (("idle", row[:IDLE_N]), ("walk", row[IDLE_N:])):
            cells = []
            for m, b in part:
                img, (y0, x0) = crop(px, m, b)
                f = to_game(img, scale, bgc)
                gy = (ground - y0) * f.shape[0] / float(img.shape[0])
                tx = torso_x(f[..., 3] > 0)
                c, lost = place(f, ref_tx[d] - tx, AY, gy, cell)
                if lost:
                    report.append(f"  {anim}_{d}: {lost} px off the cell")
                cells.append(c)
            strips[f"{anim}_{d}"] = cells

    # --- the fight sheet: attack (left block) + death (right block)
    px = load(FIGHT)
    fg, bgc = fg_mask(px)
    pans = panels(px, bg_colours(px[..., :3].astype(float)))
    frames = find_frames(fg)
    if len(pans) == 40:
        # every frame to its panel: rows and columns from the panel grid
        ys = sorted(p[0] for p in pans)
        row_y = [ys[i * 8] for i in range(5)]
        pans = sorted(pans, key=lambda p: (int(np.argmin([abs(p[0] - y) for y in row_y])), p[2]))
        grid = [[None] * 8 for _ in range(5)]
        for m, b in frames:
            cy, cx = (b[0] + b[1]) / 2.0, (b[2] + b[3]) / 2.0
            for k, p in enumerate(pans):
                if p[0] <= cy < p[1] and p[2] <= cx < p[3]:
                    r, c = k // 8, k % 8
                    if grid[r][c] is None or grid[r][c][0].sum() < m.sum():
                        grid[r][c] = (m, b, p)
                    break
        assert all(all(g is not None for g in r) for r in grid), "a panel without a drawing"
        report.append("fight sheet: 40 panels, %d drawings" % len(frames))
    else:
        rows2 = rows_of(frames)
        report.append("fight sheet: no panel grid (%d panels); rows %s" % (len(pans), [len(r) for r in rows2]))
        grid = [[(m, b, (b[0], b[1], b[2], b[3])) for m, b in r] for r in rows2]
    # per row: the sabre frames' body (their area: the blade adds little) as big as the
    # Horseman's own standing frames in that direction
    scales2 = {}
    for d, row in zip(DIRS, grid):
        areas = [(to_game(crop(px, m, b)[0], trial, bgc)[..., 3] > 0).sum() for m, b, _ in row[:4]]
        own = np.mean([(f[..., 3] > 0).sum() for f in strips["idle_" + d]])
        scales2[d] = trial * float(np.sqrt(own / np.median(areas)))
    report.append("fight scales %s" % {d: round(v, 4) for d, v in scales2.items()})
    for d, row in zip(DIRS, grid):
        att, dth = row[:4], row[4:]
        scale2 = scales2[d]
        att_ground = max(b[1] for _, b, _ in att)
        dth_ground = max(b[1] for _, b, _ in dth)
        cells, pcs = [], []
        for m, b, p in att:
            img, (y0, x0) = crop(px, m, b)
            f = to_game(img, scale2, bgc)
            gy = (att_ground - y0) * f.shape[0] / float(img.shape[0])
            tx = torso_x(f[..., 3] > 0)
            ox = ref_tx[d] - tx
            pcs.append(ox + ((p[2] + p[3]) / 2.0 - x0) * scale2)     # where the panel's middle lands
            c, lost = place(f, ox, AY, gy, cell)
            if lost:
                report.append(f"  attack_{d}: {lost} px off the cell")
            cells.append(c)
        strips[f"attack_{d}"] = cells
        pc = float(np.mean(pcs))
        cells = []
        for m, b, p in dth:
            img, (y0, x0) = crop(px, m, b)
            f = to_game(img, scale2, bgc)
            gy = (dth_ground - y0) * f.shape[0] / float(img.shape[0])
            ox = pc - ((p[2] + p[3]) / 2.0 - x0) * scale2
            # (keep a lying horse on the cell: nudge it in rather than cut it)
            a = f[..., 3] > 0
            xs = np.flatnonzero(a.any(0))
            ox = min(max(ox, -xs.min() + 1), W - 1 - xs.max() - 1)
            c, lost = place(f, ox, AY, gy, cell)
            if lost:
                report.append(f"  death_{d}: {lost} px off the cell")
            cells.append(c)
        strips[f"death_{d}"] = cells

    os.makedirs(OUT, exist_ok=True)
    counts = {}
    for key, cells in strips.items():
        Image.fromarray(np.concatenate(cells, 1)).save(f"{OUT}/{key}.png")
        counts[key] = len(cells)
    write_art_data(cell, (AX, AY), counts)
    print("\n".join(report))
    print("horseman:", ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    if CONTACT:
        contact(cell, (AX, AY), counts)


def write_art_data(cell, anchor, counts):
    src = open(ART_DATA).read()
    lines = ['\t"horseman": {"cell": Vector2i(%d, %d), "anchor": Vector2(%g, %g), "frames": {' % (cell + anchor)]
    for k in sorted(counts):
        lines.append('\t\t"%s": %d,' % (k, counts[k]))
    lines.append("\t}},\n")
    block = "\n".join(lines)
    m = re.search(r'\t"horseman": \{"cell".*?\n\t\}\},\n', src, re.S)
    if m:
        src = src[:m.start()] + block + src[m.end():]
    else:
        m = re.search(r'\t"cuirassier": \{"cell".*?\n\t\}\},\n', src, re.S)
        src = src[:m.end()] + block + src[m.end():]
    open(ART_DATA, "w").write(src)


def contact(cell, anchor, counts, k=3):
    """x3: every strip of the Horseman under the Cuirassier's same strip, on grass."""
    W, H = cell
    AX, AY = anchor
    lines = []
    for anim in ("idle", "walk", "attack", "death"):
        for d in DIRS:
            for who in (REF, OUT):
                a = np.array(Image.open(f"{who}/{anim}_{d}.png").convert("RGBA"))
                lines.append(a)
    wmax = max(a.shape[1] for a in lines)
    sheet = Image.new("RGB", (wmax * k + 8, len(lines) * (H * k + 4)), (24, 24, 24))
    for i, a in enumerate(lines):
        bgi = np.zeros((a.shape[0], a.shape[1], 3), np.uint8)
        bgi[:] = (76, 112, 52) if (i // 2) % 2 == 0 else (88, 124, 60)
        al = a[..., 3:4] / 255.0
        img = (a[..., :3] * al + bgi * (1 - al)).astype(np.uint8)
        for c in range(a.shape[1] // W):
            img[int(AY), c * W + int(AX) - 2:c * W + int(AX) + 3] = (255, 255, 255)
            img[:, c * W] = (40, 70, 30)
        im = Image.fromarray(img).resize((a.shape[1] * k, a.shape[0] * k), Image.NEAREST)
        sheet.paste(im, (4, i * (H * k + 4)))
    os.makedirs(CONTACT, exist_ok=True)
    sheet.save(os.path.join(CONTACT, "contact_horseman.png"))


if __name__ == "__main__":
    main()
