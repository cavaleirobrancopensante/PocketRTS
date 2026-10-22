"""The Crown's mounting animation: a man climbing onto a still horse, from the designer's
sheets in art/crown/mount/ (1536x1024, dark navy, 5 rows top to bottom S, SE, E, NE, N; each
row a man beside a horse getting on, the last frame seated). The game plays it forwards while
a man gets on and backwards while he gets off (scripts/unit.gd, work "mounting" /
"dismounting"): side on from the SE and E rows (mirrored for SW and W), from the front
and from behind (S, N) by the strips below.

Many frames are hallucinated, so only these are used (the designer's choice):
  messenger_mount.png        Labourer -> Messenger            SE row, E row: all 6 frames
  missionary_mount.png       Missionary -> Mounted Missionary SE row, E row: all 6 frames
  horseman_mount.png         Dismounted -> Horseman (light)   SE row, E row: all 7 frames
  cuirassier_mount_b.png     armoured -> Cuirassier           SE row, E row: all 7 frames
                             (cuirassier_mount_a.png is not used)
  dragoon_armoured_mount.png Guardsman -> Armoured Dragoon    SE row, E row: frames 2-7 (frame 1
                             of SE has a ghost rider, of E two horses)
  dragoon_mount.png          Musketeer -> Dragoon             SE row: all 6 frames. Its E row is
                             broken (two men), so E comes from its remake:
  dragoon_mount_e.png        the light Dragoon's E strip      one horizontal strip, all 6 frames
                             facing right (drawn bigger: scaled by itself). Without it the SE
                             strip would serve for E.
  <set>_mount_s.png / _n.png the front (S) and back (N) views, one strip of 6 frames each
                             (2000x667 or 2172x724, each drawn at its own size), the man
                             climbing on from the left of the picture: dragoon_, dragoon_armoured_
                             (both _s made from _raw by tools/fix_mount_heads.py), horseman_,
                             cuirassier_, missionary_ (-> missionary_mounted); the Messenger's
                             are the S and N rows of messenger_mount.png. All frames used.

Frames are found by their foreground: a row is split at empty column runs, and the pieces
(a man standing apart from his horse is two) are merged, closest first, down to the row's
frame count. Each frame is aligned by its horse, so the horse stands still while the man
climbs: the horse is the grey (low-saturation, mid-tone, not steel-blue) pixels; each frame
is first placed by the front of the forelegs (the right edge of the horse's lowest third:
the man always stands on its left) and its bottom, then moved to where its horse best
overlaps the last (seated) frame's (IoU search). The sheet is scaled so its horse is the size
of the game's riderless horse (between matching its length and its height: sheet_scale),
which stands beside the man before he gets on and after he gets off (a sheet without an E
row: its seated SE frame as tall as the unit's idle, times the other sheets' ratio between
the two measures; a separate E strip gets its own scale). The whole row is placed on the
unit's cell (98x70, anchor 49,66) where its seated frame best overlaps the idle frame of
that direction (so the last frame of the mount is the unit standing). Front and back views
(FB_STRIPS, the Messenger's S / N rows) are aligned by the middle of the horse's legs and its
hooves instead (then sideways only), scaled by fb_scale (between the seated frame fitting the
idle and the first frame's horse as tall as the riderless horse) and placed hooves on the
idle's hooves. Red coats and saddle cloths are snapped to the team reds.
Where the man stands in the first frame (for the horse left beside him on dismounting) is
scripts/unit.gd MOUNT_MAN.

Output: assets/units/<art>/mount_s.png, mount_se.png, mount_e.png and mount_n.png for the
mounted units' arts (messenger, missionary_mounted, horseman, cuirassier, dragoon,
dragoon_armoured), their "mount_*" entries in scripts/art_data.gd (added to the art's block, nothing else touched).
Run after the units' own importers and before tools/import_horse_coats.py (its "mount" anims
give the strips' horses their coat masks).

Usage (from the repo root): python3 tools/import_mount.py [--contact DIR]
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import clean  # noqa: E402
from import_horse_units import load, runs, cut_frame, shrink  # noqa: E402

ART_DATA = "scripts/art_data.gd"
CELL = (98, 70)
ANCHOR = (49, 66)
ROW = {"s": 0, "se": 1, "e": 2, "ne": 3, "n": 4}

# sheet -> (mounted art, frames per row, {dir: frame indices used (0-based)})
SHEETS = {
    "messenger_mount": ("messenger", 6, {"se": range(6), "e": range(6), "s": range(6), "n": range(6)}),
    "missionary_mount": ("missionary_mounted", 6, {"se": range(6), "e": range(6)}),
    "horseman_mount": ("horseman", 7, {"se": range(7), "e": range(7)}),
    "cuirassier_mount_b": ("cuirassier", 7, {"se": range(7), "e": range(7)}),
    "dragoon_armoured_mount": ("dragoon_armoured", 7, {"se": range(1, 7), "e": range(1, 7)}),
    # (E row broken: see E_STRIPS)
    "dragoon_mount": ("dragoon", 6, {"se": range(6)}),
}
# a remade E row on its own sheet (one strip, facing right): art -> (file, frame count)
E_STRIPS = {"dragoon": ("dragoon_mount_e", 6)}
# no E strip of its own (yet): the SE strip serves
E_FALLBACK = {"dragoon": "se"}
# the front (S) and back (N) views, each a strip on its own sheet (6 frames, the man at the
# horse's left in the picture): art -> {dir: file}. Each sheet is scaled by itself (fit_scale).
# (The Messenger's come from the S and N rows of messenger_mount.png, at that sheet's scale.)
FB_STRIPS = {
    "dragoon": {"s": "dragoon_mount_s", "n": "dragoon_mount_n"},
    "dragoon_armoured": {"s": "dragoon_armoured_mount_s", "n": "dragoon_armoured_mount_n"},
    "horseman": {"s": "horseman_mount_s", "n": "horseman_mount_n"},
    "cuirassier": {"s": "cuirassier_mount_s", "n": "cuirassier_mount_n"},
    "missionary_mounted": {"s": "missionary_mount_s", "n": "missionary_mount_n"},
}
FB_COUNT = 6
FRONT_BACK = ("s", "n")


def find_frames(fg, y0, y1, count):
    """[(x0, x1)] of the row's `count` frames: column runs, the closest merged."""
    occ = fg[y0:y1].sum(0) > 0
    cols = [list(c) for c in runs(occ, 6) if c[1] - c[0] > 4]
    while len(cols) > count:
        gaps = [cols[i + 1][0] - cols[i][1] for i in range(len(cols) - 1)]
        i = int(np.argmin(gaps))
        cols[i:i + 2] = [[cols[i][0], cols[i + 1][1]]]
    assert len(cols) == count, "%d frames found, %d expected" % (len(cols), count)
    return cols


def horse_mask(img):
    """The horse's pixels (sheet resolution): grey, mid-tone, not the blue-grey steel; its
    biggest piece."""
    a = img[..., 3] > 0
    rgb = img[..., :3].astype(np.float32) / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    steel = rgb[..., 2] - rgb[..., 0] >= 9 / 255.0
    m = a & (mx >= 0.18) & (mx <= 0.75) & (s < 0.25) & ~steel
    m = ndimage.binary_opening(m, iterations=1)
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return m
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    # the body and every big piece beside it (legs cut off by a boot or a stirrup)
    return np.isin(lab, 1 + np.nonzero(sizes >= 0.08 * sizes.max())[0])


def horse_anchor(img):
    """(x, y): the front of the horse's forelegs (the right edge of its lowest third, below the belly: the
    horse faces right and the man always stands on its left, so his legs, grey breeches or
    greaves can't pull it), and its bottom."""
    m = horse_mask(img)
    ys, xs = np.nonzero(m)
    top, bot = ys.min(), ys.max()
    low = ys >= bot - (bot - top) * 0.33
    return float(np.percentile(xs[low], 97)), float(np.percentile(ys, 99.5))


def hooves(img, low=0.12):
    """(front / back view) (x0, x1, bottom) of the horse's legs: the rightmost run of columns
    in the picture's lowest rows (the man stands at its left, his boots apart from its hooves)."""
    a = img[..., 3] > 0
    ys = np.nonzero(a.any(1))[0]
    bot = ys.max()
    band = a[bot - max(2, int((bot - ys.min() + 1) * low)):bot + 1].any(0)
    x0, x1 = runs(band, max(2, int(img.shape[1] * 0.02)))[-1]
    # (its own bottom: the man may stand a little nearer, lower in the picture)
    return x0, x1, int(np.nonzero(a[:, x0:x1].any(1))[0].max())


def legs_mask(img, hv):
    """(front / back view) the horse's legs and belly: the lowest 45% of its height, over the
    columns of its legs and half as much again each side (not the man's boots beside it)."""
    x0, x1, bot = hv
    a = img[..., 3] > 0
    top = np.nonzero(a[:, x0:x1].any(1))[0].min()
    m = np.zeros_like(a)
    w = x1 - x0
    y0 = int(bot - (bot - top) * 0.45)
    m[y0:bot + 1, max(0, x0 - w // 2):x1 + w // 2] = True
    return a & m


def idle_frame(art, d):
    im = np.asarray(Image.open("assets/units/%s/idle_%s.png" % (art, d)).convert("RGBA"))
    return im[:, :CELL[0]]


def place_on(f, H, W, x, y):
    c = np.zeros((H, W, 4), np.uint8)
    h, w = f.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    part = f[sy0:min(h, H - y), sx0:min(w, W - x)]
    m = part[..., 3] > 0
    c[y + sy0:y + sy0 + part.shape[0], x + sx0:x + sx0 + part.shape[1]][m] = part[m]
    return c


def iou_shift(a, b, search, step=1):
    """(dx, dy) moving mask a to best overlap mask b (same size)."""
    best, bo = -1.0, (0, 0)
    for dy in range(-search, search + 1, step):
        for dx in range(-search, search + 1, step):
            s = np.roll(np.roll(a, dy, 0), dx, 1)
            score = (s & b).sum() / max((s | b).sum(), 1) - 1e-5 * (abs(dx) + abs(dy))
            if score > best:
                best, bo = score, (dx, dy)
    return bo


def build_strip(frames, art, d, scale):
    """Cell frames from the sheet-resolution cuts, aligned by their horse: first by the
    front of its forelegs, then moved to where its grey body best overlaps the seated
    frame's."""
    front = d in FRONT_BACK
    if front:
        # (front / back: by the middle of its legs and its hooves)
        hvs = [hooves(f) for f in frames]
        anchors = [((x0 + x1) / 2.0, float(bot)) for x0, x1, bot in hvs]
    else:
        anchors = [horse_anchor(f) for f in frames]
    pad = 60
    W = max(f.shape[1] for f in frames) + 2 * pad
    H = max(f.shape[0] for f in frames) + 2 * pad
    CX, CY = W // 2, H - pad
    pos = [(int(round(CX - ax)), int(round(CY - ay))) for ax, ay in anchors]
    cans = []
    if front:
        def legs(i, x, y):
            x0, x1, bot = hvs[i]
            return legs_mask(place_on(frames[i], H, W, x, y), (x0 + x, x1 + x, bot + y))
        ref = legs(len(frames) - 1, *pos[-1])
        # (sideways only: the hooves are on one line; the rider's boots at the belly would
        # pull it up)
        for i, (x, y) in enumerate(pos):
            m = legs(i, x, y)
            dx = max(range(-6, 7), key=lambda k: (np.roll(m, k, 1) & ref).sum() / float(max((np.roll(m, k, 1) | ref).sum(), 1)) - 1e-5 * abs(k))
            cans.append(place_on(frames[i], H, W, x + dx, y))
    else:
        ref = horse_mask(place_on(frames[-1], H, W, *pos[-1]))
        for f, (x, y) in zip(frames, pos):
            m = horse_mask(place_on(f, H, W, x, y))
            dx, dy = iou_shift(m, ref, 24, 3)
            ex, ey = iou_shift(np.roll(np.roll(m, dy, 0), dx, 1), ref, 2)
            cans.append(place_on(f, H, W, x + dx + ex, y + dy + ey))
    small = [snap_team(clean(shrink(c, scale))) for c in cans]
    sh, sw = small[0].shape[:2]
    # the canvas's hoof point lands at first on the anchor; then the seated frame is moved
    # onto the idle frame
    ax0 = ANCHOR[0] - int(round(CX * scale))
    ay0 = ANCHOR[1] - int(round(CY * scale))

    def put(img, ox, oy):
        out = np.zeros((CELL[1], CELL[0], 4), np.uint8)
        x, y = ax0 + ox, ay0 + oy
        sx0, sy0 = max(0, -x), max(0, -y)
        dx0, dy0 = max(0, x), max(0, y)
        ww, hh = min(sw - sx0, CELL[0] - dx0), min(sh - sy0, CELL[1] - dy0)
        part = img[sy0:sy0 + hh, sx0:sx0 + ww]
        m = part[..., 3] > 0
        out[dy0:dy0 + hh, dx0:dx0 + ww][m] = part[m]
        return out

    last = put(small[-1], 0, 0)
    idle = idle_frame(art, d)
    if front:
        # (front / back: hooves on the idle's hooves, then sideways only: the rider's hat or
        # the horse's ears would pull it up or down)
        la, ia = last[..., 3] > 0, idle[..., 3] > 0
        oy = int(np.nonzero(ia.any(1))[0].max() - np.nonzero(la.any(1))[0].max())
        la = np.roll(la, oy, 0)
        ox = max(range(-12, 13), key=lambda dx: (np.roll(la, dx, 1) & ia).sum() / float((np.roll(la, dx, 1) | ia).sum()) - 1e-5 * abs(dx))
    else:
        ox, oy = iou_shift(last[..., 3] > 0, idle[..., 3] > 0, 12)
    cells = [put(s, ox, oy) for s in small]
    # what got cut off at the cell's edges (should be nothing)
    lost = 0
    for s, c in zip(small, cells):
        lost += int((s[..., 3] > 0).sum() - (c[..., 3] > 0).sum())
    return cells, lost


def sheet_frames(name, count, d=None, rows=None):
    """{dir: [frame cuts]} of a sheet (rows: dir -> indices), or the one strip of a single-row
    sheet as `d`."""
    px, fg, bg = load("mount/" + name)
    bands = [b for b in runs(fg.sum(1) > 0, 4) if b[1] - b[0] > 25]
    out = {}
    if rows is None:
        bands = [(min(b[0] for b in bands), max(b[1] for b in bands))]
        rows = {d: range(count)}
        rowof = {d: 0}
    else:
        assert len(bands) == 5, "%s: %d rows found" % (name, len(bands))
        rowof = ROW
    for dd, idx in rows.items():
        y0, y1 = bands[rowof[dd]]
        cols = find_frames(fg, y0, y1, count)
        cuts = []
        for i in idx:
            x0, x1 = cols[i]
            img = cut_frame(px, fg, bg, y0, y1, x0, x1)
            ys, xs = np.nonzero(img[..., 3] > 0)
            cuts.append(img[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
        out[dd] = cuts
    return out


def head_height(img, frac=0.3):
    """(side on, facing right) how tall the horse stands, ears to hooves: the height of the
    picture's rightmost 30% (its head and forelegs: the man and his saddle are further back)."""
    a = img[..., 3] > 0
    xs = np.nonzero(a.any(0))[0]
    x1 = xs.max()
    ys = np.nonzero(a[:, x1 - int((x1 - xs.min() + 1) * frac):x1 + 1].any(1))[0]
    return ys.max() - ys.min() + 1


def sheet_scale(cuts):
    """One scale per sheet, from its side-on (E) row: its horse the size of the game's
    riderless horse (the one standing beside the man before he gets on and after he gets
    off; the riders' horses are about its size). The sheets' horses are drawn longer for
    their height than the game's, so it can't match both: the scale is between the one
    matching its length (nose to tail, on the seated frame) and the one matching its height
    (ears to hooves, the median over the row; at most 1.3 times the other: a sheet whose
    horse holds its head low reads short), their geometric mean. None without an E row (see
    tall_scale)."""
    if "e" not in cuts:
        return None
    ref = idle_frame("horse", "e")
    xs = np.nonzero((ref[..., 3] > 0).any(0))[0]
    by_len = (xs.max() - xs.min() + 1) / float(cuts["e"][-1].shape[1])
    by_height = head_height(ref) / float(np.median([head_height(f) for f in cuts["e"]]))
    return float(np.sqrt(by_len * float(np.clip(by_height, by_len, 1.3 * by_len))))


def tall_scale(cuts, art):
    """The seated SE frame as tall as the unit's idle SE frame (for a sheet with no E row,
    times the other sheets' ratio of the two scales)."""
    idle = idle_frame(art, "se")
    ys = np.nonzero((idle[..., 3] > 0).any(1))[0]
    return (ys.max() - ys.min() + 1) / float(cuts["se"][-1].shape[0])


def fit_scale(seated, art, d):
    """A front / back strip's scale: its seated frame best overlapping the unit's idle frame of
    that direction (the same man on the same horse, so its horse is the game's): from the
    scale matching their heights, +-15% in 1% steps, each at its best shift (bottoms and
    middles lined up, then +-3 px). (scale, the height-matching scale, the best IoU)"""
    idle = idle_frame(art, d)[..., 3] > 0
    iy = np.nonzero(idle.any(1))[0]
    ix = np.nonzero(idle.any(0))[0]
    base = (iy.max() - iy.min() + 1) / float(seated.shape[0])
    best, bs = -1.0, base
    for k in np.arange(0.85, 1.1501, 0.01):
        sm = shrink(seated, base * k)[..., 3] > 0
        h, w = sm.shape
        c = np.zeros_like(idle)
        x = int(round((ix.min() + ix.max()) / 2.0 - w / 2.0))
        y = iy.max() + 1 - h
        c[max(y, 0):y + h, max(x, 0):x + w] = sm[max(-y, 0):, max(-x, 0):][:c.shape[0] - max(y, 0), :c.shape[1] - max(x, 0)]
        dx, dy = iou_shift(c, idle, 3)
        c = np.roll(np.roll(c, dy, 0), dx, 1)
        score = (c & idle).sum() / float((c | idle).sum())
        if score > best:
            best, bs = score, base * k
    return float(bs), base, best


def fb_scale(cuts, art, d):
    """A front / back strip's scale: between the one fitting its seated frame to the idle
    (fit_scale) and the one making its horse (the first frame's, the man beside it) as tall as
    the game's riderless horse, which is left standing there after he gets off: their
    geometric mean, so neither the end of getting on nor of getting off pops much. (The
    Horseman's and Cuirassier's idle horses are drawn smaller than the riderless one.)"""
    fit, tall, iou = fit_scale(cuts[-1], art, d)
    f0 = cuts[0]
    x0, x1, bot = hooves(f0)
    a = f0[..., 3] > 0
    top = np.nonzero(a[:, max(0, x0 - (x1 - x0) // 5):].any(1))[0].min()
    ref = idle_frame("horse", d)[..., 3] > 0
    ry = np.nonzero(ref.any(1))[0]
    by_horse = (ry.max() - ry.min() + 1) / float(bot - top + 1)
    s = float(np.sqrt(fit * by_horse))
    print("%s %s: fit to idle %.3f (IoU %.2f), horse as the riderless one %.3f -> %.3f" % (art, d, fit, iou, by_horse, s))
    return s


def write_counts(art, counts):
    """Adds (or replaces) the art's mount_* entries in scripts/art_data.gd."""
    src = open(ART_DATA).read()
    m = re.search(r'\t"%s": \{"cell".*?\n\t\}\},\n' % art, src, re.S)
    assert m, "no %s in art_data" % art
    block = m.group(0)
    i = block.index('"frames": {') + len('"frames": {')
    entries = dict(re.findall(r'\t\t"(\w+)": (\d+),', block[i:]))
    for k, v in counts.items():
        entries[k] = str(v)
    lines = [block[:i]]
    for k in sorted(entries):
        lines.append('\t\t"%s": %s,' % (k, entries[k]))
    lines.append("\t}},\n")
    src = src[:m.start()] + "\n".join(lines) + src[m.end():]
    open(ART_DATA, "w").write(src)


def main():
    contact = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else None
    results = {}
    sheets = {}
    ratios = []
    for name, (art, count, rows) in SHEETS.items():
        cuts = sheet_frames(name, count, rows=rows)
        scale = sheet_scale(cuts)
        if scale is not None:
            ratios.append(scale / tall_scale(cuts, art))
        # (a remade E row on its own sheet, drawn at its own size: its own scale)
        extra = None
        if art in E_STRIPS and os.path.exists("art/crown/mount/%s.png" % E_STRIPS[art][0]):
            fe, ne = E_STRIPS[art]
            extra = sheet_frames(fe, ne, d="e")
        sheets[name] = (art, cuts, scale, extra)
    for name, (art, cuts, scale, extra) in sheets.items():
        if scale is None:
            scale = tall_scale(cuts, art) * float(np.median(ratios))
        scales = {d: scale for d in cuts}
        # (front and back rows of a 5-row sheet: scaled like the separate front / back strips;
        # the sheet's side-on scale left them ~10% small)
        for d in FRONT_BACK:
            if d in cuts:
                scales[d] = fb_scale(cuts[d], art, d)
        if extra:
            cuts.update(extra)
            scales["e"] = sheet_scale(extra)
        for d, fb in FB_STRIPS.get(art, {}).items():
            if os.path.exists("art/crown/mount/%s.png" % fb):
                cuts.update(sheet_frames(fb, FB_COUNT, d=d))
                scales[d] = fb_scale(cuts[d], art, d)
        strips = {}
        for d, fr in cuts.items():
            cells, lost = build_strip(fr, art, d, scales[d])
            strips[d] = cells
            print("%s %s: %d frames, scale %.3f%s" % (art, d, len(cells), scales[d],
                  ", %d px cut off" % lost if lost else ""))
        if "e" not in strips:
            strips["e"] = strips[E_FALLBACK[art]]
            print("%s e: the %s strip" % (art, E_FALLBACK[art]))
        counts = {}
        for d, cells in strips.items():
            Image.fromarray(np.concatenate(cells, 1)).save("assets/units/%s/mount_%s.png" % (art, d))
            counts["mount_" + d] = len(cells)
        write_counts(art, counts)
        results[art] = strips
    if contact:
        os.makedirs(contact, exist_ok=True)
        for art, strips in results.items():
            rows = []
            for d in ("s", "se", "e", "n"):
                if d not in strips:
                    continue
                idle = idle_frame(art, d)
                rows.append(np.concatenate(strips[d] + [idle], 1))
            w = max(r.shape[1] for r in rows)
            sheet = Image.new("RGBA", (w * 4, CELL[1] * 4 * len(rows)), (104, 132, 84, 255))
            for i, r in enumerate(rows):
                im = Image.fromarray(r)
                sheet.alpha_composite(im.resize((im.width * 4, im.height * 4), Image.NEAREST), (0, i * CELL[1] * 4))
            # the anchor
            px = np.asarray(sheet).copy()
            for i in range(len(rows)):
                for f in range(w // CELL[0]):
                    x = (f * CELL[0] + ANCHOR[0]) * 4
                    y = (i * CELL[1] + ANCHOR[1]) * 4
                    px[y:y + 4, x - 8:x + 12] = (255, 255, 0, 255)
            Image.fromarray(px).save(os.path.join(contact, "mount_%s.png" % art))


if __name__ == "__main__":
    main()
