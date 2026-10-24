"""The Crown Labourer's redrawn animations (art/redraws/labourer_*.png, drawn by an image AI
from docs/animation_redraw_prompts.md) into assets/units/labourer/<pose>_<dir>.png.

Sheets (all 1536x1024 on a flat dark navy ground, with titles, column numbers and row labels):
  labourer_build_hammer.png               build: 5 rows (s, se, e, ne, n) x 4 frames
  labourer_keg_carry_idle.png             carry_keg 6 + idle_keg 4, 5 rows (s, se, e, ne, n)
  labourer_walk_and_carry.png             walk 6 + carry (gold sack on his back) 6, same rows
  labourer_mine_idle_ne_idle_sack.png     mine 4, idle_ne 2 (the other rows are unused), idle_carry 2

What it does (see docs/animation_audit_labourer.md for the per-frame decisions):
  1. sprites are found as connected blobs of non-navy pixels (titles, numbers and labels are
     dropped by size and place), keyed out of the navy;
  2. each frame is shrunk to the game's pixel size (one scale per sheet, SCALE, so a man is as
     tall as the old labourer: box filter with premultiplied alpha, hard alpha, no blur),
     the coat is snapped to the two team key reds, specks and navy fringes are removed;
  3. every frame stands on the cell's ground line (bottom row y 33) and is centred on a
     reference x taken from the body that does not move with the tool (REFX);
  4. frames the image AI got wrong are REPAIRED in final_frames(): walk_legs() picks, per view,
     the legs of the best-drawn frames (mirrored / lifted / shifted so the feet alternate
     contact, passing, contact-other-foot); compose() cuts under the coat hem and pastes those
     legs under each frame's own torso, stretching the thighs so the boots stay on row 33;
     idle frames reuse frame 0's feet; build frames are reordered (BUILD_ORDER) and pinned below
     row BUILD_PIN so the body and stake stay still while only the arm and hammer move; tall
     hammers are shortened (shorten_handle) to fit the 35-row cell; known smudged hems are
     overridden (SMUDGED_HEM).
  5. the strips are written, and the labourer block of scripts/art_data.gd gets the new frame
     counts (walk 6, carry 6, mine 4, build 4, idle_keg_n 4, idle_carry 2).

Run from the repo root:  python3 tools/import_labourer_redraw.py [--contact DIR] [--dry]
Reads only art/redraws; the result is deterministic, so it is safe to run twice. It is
listed in tools/rebuild_art.sh (after import_build_still.py, which it supersedes for build_*).
Needs Pillow, NumPy, SciPy.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_cannon2 import clean  # noqa: E402
from import_art import snap_team  # noqa: E402

REDRAWS = os.path.join(ROOT, "art/redraws")
OUT = os.path.join(ROOT, "assets/units/labourer")
W, H = 42, 35
GROUND = 33                      # bottom row of the feet
CX = 21                          # anchor x
DIRS = ["s", "se", "e", "ne", "n"]
BG = np.array([6, 21, 48])
HIP = 23                         # first trouser row under the coat hem
ANKLE = 28                       # first boot row


def load_sheet(name):
    a = np.array(Image.open(os.path.join(REDRAWS, name)).convert("RGB")).astype(int)
    fg = np.abs(a - BG).sum(-1) > 45
    return a, fg


def blobs(name, min_area=2500):
    """Every sprite blob of a sheet: dicts with rgba (sheet resolution, tight crop), x, y of
    the crop's corner, centre and area. Titles / labels / dividers are smaller or thinner."""
    a, fg = load_sheet(name)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=5))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = fg[sl] & (lab[sl] == i + 1)
        if m.sum() < min_area:
            continue
        h, w = m.shape
        if w < 30 or h < 60:
            continue
        rgba = np.zeros((h, w, 4), np.uint8)
        rgba[..., :3] = a[sl]
        rgba[..., 3] = m * 255
        out.append({"rgba": rgba, "x": sl[1].start, "y": sl[0].start, "cx": sl[1].start + w / 2,
                    "cy": sl[0].start + h / 2, "area": int(m.sum())})
    return out


def grid(bl, xr, nrows=5):
    """Blobs inside the x range xr as rows (top to bottom) of frames (left to right)."""
    b = sorted([s for s in bl if xr[0] <= s["cx"] < xr[1]], key=lambda s: s["cy"])
    rows = []
    for s in b:
        if rows and abs(rows[-1][-1]["cy"] - s["cy"]) < 60 and abs(np.mean([t["cy"] for t in rows[-1]]) - s["cy"]) < 60:
            rows[-1].append(s)
        else:
            rows.append([s])
    assert len(rows) == nrows, (name_of(bl), xr, [len(r) for r in rows])
    return [sorted(r, key=lambda s: s["cx"]) for r in rows]


def name_of(bl):
    return "?"


# ---------------------------------------------------------------- shrinking and placing

SCALE = {"build": 0.20, "keg": 0.268, "walk": 0.28, "mine": 0.28}


def shrink_canvas(rgba, ref, bottom, scale, keep=0.5):
    """Place the sheet-resolution sprite so its reference point `ref` (sheet x, relative to
    the crop) lands on the cell's anchor column and its bottom edge on the ground line, then
    box-filter the whole cell down by `scale` (premultiplied alpha, hard alpha)."""
    cw, ch = int(round(W / scale)), int(round(H / scale))
    s = W / cw                                     # the exact factor (cell width)
    canvas = np.zeros((ch, cw, 4), np.uint8)
    ox = int(round(CX / s - ref))
    oy = int(round((GROUND + 1) / s - bottom))
    h, w = rgba.shape[:2]
    sy0, sy1, dy0 = max(0, -oy), min(h, ch - oy), max(0, oy)
    sx0, sx1, dx0 = max(0, -ox), min(w, cw - ox), max(0, ox)
    if sy1 > sy0 and sx1 > sx0:
        canvas[dy0:dy0 + sy1 - sy0, dx0:dx0 + sx1 - sx0] = rgba[sy0:sy1, sx0:sx1]
    a = canvas[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([canvas[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    sm = np.array(Image.fromarray(pre).resize((W, H), Image.BOX)).astype(np.float32)
    al = sm[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, sm[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= keep, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def coat_x(rgba):
    r, g, b, a = [rgba[..., i].astype(int) for i in range(4)]
    m = (a > 0) & (r > 130) & (g < 70) & (b < 70)
    if m.sum() < 20:
        m = a > 0
    return float(np.nonzero(m)[1].mean())


def feet_x(rgba):
    """Centre of the lowest rows (boots, stake): steady while the arm and tool move."""
    a = rgba[..., 3] > 0
    ys = np.nonzero(a.any(1))[0]
    lo = a[max(ys.min(), ys.max() - 12):]
    xs = np.nonzero(lo.any(0))[0]
    return float((xs.min() + xs.max()) / 2.0)


def bottom_y(rgba):
    ys = np.nonzero((rgba[..., 3] > 0).any(1))[0]
    return float(ys.max() + 1)


def tidy(img):
    """Pink glows on the sleeves and cuffs pulled back to coat red, blue specks to steel grey,
    team reds snapped, navy tint at the edges and loose specks removed."""
    img = img.copy()
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = img[..., 3] > 0
    pink = a & (r > 100) & (r > g + 70) & (b > g + 15) & (r > b + 40)
    img[pink, 2] = img[pink, 1]
    blue = a & (b > r + 28) & (b > g + 10) & (r < 130)
    img[blue, 2] = np.minimum(img[blue, 2], np.maximum(r[blue], g[blue]) + 8)
    maroon = a & (r >= 45) & (r < 95) & (g < 0.3 * r) & (b < 0.5 * r)      # a dull red glow: outline
    img[maroon, :3] = (28, 16, 14)
    img = snap_team(img)
    rgb = img[..., :3].astype(int)
    a = img[..., 3] > 0
    navy = a & (rgb[..., 2] - rgb[..., 0] > 18) & (rgb[..., 2] > rgb[..., 1] + 4) & (rgb.sum(-1) < 150)
    edge = a & ~ndimage.binary_erosion(a, structure=np.ones((3, 3)))
    img[navy & edge] = 0
    # a lone coat-red pixel up in the face or hat (the AI's red glints) takes its neighbours' colour
    redk = (img[..., 3] > 0) & (img[..., 0] >= 150) & (img[..., 1] == 0) & (img[..., 2] == 0)
    nred = ndimage.convolve(redk.astype(int), np.ones((3, 3), int), mode="constant") - redk
    for y, x in zip(*np.nonzero(redk & (nred == 0))):
        if y < 13:
            win = img[max(0, y - 1):y + 2, max(0, x - 1):x + 2].reshape(-1, 4)
            ok = (win[:, 3] > 0) & ~((win[:, 0] >= 150) & (win[:, 1] == 0) & (win[:, 2] == 0))
            if ok.any():
                img[y, x, :3] = np.median(win[ok][:, :3], axis=0).astype(np.uint8)
    return clean(img, min_size=3, keep_near=1)


def drop_bright(img, y0=21):
    """Isolated white sparkles (a stray glint at the hip or hand) removed below row y0."""
    out = img.copy()
    m = (out[..., 3] > 0) & (out[..., :3].min(-1) > 185)
    m[:y0] = False
    out[m] = 0
    return out


def shorten_handle(rgba, scale):
    """A raised hammer drawn taller than the cell has room for (34 rows above the ground
    line): rows are cut out of the handle just under the hammer head, so the arm is a little
    shorter and the head stays whole. Returns the sprite unchanged if it fits."""
    a = rgba[..., 3] > 0
    ys = np.nonzero(a.any(1))[0]
    top, bot = int(ys.min()), int(ys.max())
    k = (bot - top + 1) - int((GROUND + 1) / scale)
    if k <= 0:
        return rgba
    k += 1
    r, g, b = [rgba[..., i].astype(int) for i in range(3)]
    grey = a & (abs(r - g) < 18) & (abs(g - b) < 24) & (r > 45) & (r < 140)
    rows = np.nonzero(grey.sum(1) >= 4)[0]
    rows = rows[rows < top + 70]
    head_bottom = top
    for y in range(top, top + 70):
        if y in set(rows.tolist()):
            head_bottom = y
        elif y > head_bottom + 3 and head_bottom > top:
            break
    cut = head_bottom + 4
    return np.concatenate([rgba[:cut], rgba[cut + k:]], 0)


def make(sprite, sc, mode="coat"):
    rgba = sprite["rgba"]
    if mode == "feet":
        rgba = shorten_handle(rgba, sc)
    rx = coat_x(rgba) if mode == "coat" else feet_x(rgba)
    return tidy(shrink_canvas(rgba, rx, bottom_y(rgba), sc))


def contact(frames, pose, path, dirs=DIRS, zoom=4):
    """One PNG: a row per direction, frames left to right at 4x on green, ground line marked."""
    from PIL import ImageDraw
    n = max(len(frames[(pose, d)]) for d in dirs)
    sheet = Image.new("RGBA", (n * W * zoom + 40, len(dirs) * H * zoom), (90, 110, 90, 255))
    dr = ImageDraw.Draw(sheet)
    for r, d in enumerate(dirs):
        dr.text((4, r * H * zoom + 4), d, fill=(255, 255, 255, 255))
        for k, f in enumerate(frames[(pose, d)]):
            x0 = 40 + k * W * zoom
            sheet.alpha_composite(Image.fromarray(f).resize((W * zoom, H * zoom), Image.NEAREST), (x0, r * H * zoom))
            dr.line([(x0, r * H * zoom + (GROUND + 1) * zoom), (x0 + W * zoom, r * H * zoom + (GROUND + 1) * zoom)], fill=(255, 255, 0, 120))
            dr.line([(x0 + CX * zoom, r * H * zoom), (x0 + CX * zoom, r * H * zoom + H * zoom)], fill=(255, 255, 255, 50))
            dr.text((x0 + 2, r * H * zoom + 2), str(k), fill=(255, 255, 255, 255))
    sheet.save(path)


# ---------------------------------------------------------------- frankenstein tools
# All of these work on finished game-size frames (42x35 RGBA), so every repair keeps the
# sheet's palette and hard pixel edges.

def is_red(img):
    r, g, b, a = [img[..., i].astype(int) for i in range(4)]
    return (a > 0) & (r > 120) & (g < 70) & (b < 70)


def hem_row(img):
    """Last row of the coat (team red) above the knees: the first trouser row is hem + 1."""
    cnt = is_red(img)[:27].sum(1)
    ys = np.nonzero(cnt >= 3)[0]
    return int(ys.max()) if len(ys) else 22


def leg_pixels(img):
    """Mask of trouser / boot / outline pixels (no coat, no hands)."""
    r, g, b, a = [img[..., i].astype(int) for i in range(4)]
    upper = np.arange(H)[:, None] < ANKLE - 1                  # (boots keep their highlights and dark reds)
    skin = (r > 165) & (g > 105) & upper
    return (a > 0) & ~(is_red(img) & upper) & ~skin


def top_centre(img, row, n=2):
    """Mean x of the leg pixels in rows row..row+n-1."""
    m = leg_pixels(img)[row:row + n]
    xs = np.nonzero(m.any(0))[0]
    return float(xs.mean()) if len(xs) else float(CX)


def shift(img, dx=0, dy=0):
    out = np.zeros_like(img)
    h, w = img.shape[:2]
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = img[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def mirror(img):
    return img[:, ::-1].copy()


def lift_foot(img, side, dy, knee=28):
    """Front / back views: raise one foot (side 'l' or 'r' of the legs' centre line, in the
    picture) by dy rows from row `knee` down; what the shift uncovers stays empty."""
    out = img.copy()
    mid = int(round(top_centre(img, knee - 4, 3)))
    cols = slice(0, mid) if side == "l" else slice(mid, W)
    part = img[knee:, cols].copy()
    out[knee:, cols] = 0
    out[knee - dy:H - dy, cols] = np.where(part[..., 3:4] > 0, part, out[knee - dy:H - dy, cols])
    # trousers above the foot come down to meet it
    return out


def compose(body, legs, align=True, hem=None):
    """The coat, head and arms of `body` on the legs of `legs`: the body is cut below its
    coat hem (`hem`: the row to cut under, when the picture's own hem is smudged), the donor
    legs (from their own hem down, coat and hands left out) are moved so their hips sit under
    the body's (align=False: left where they were, so the feet stay put while the body sways),
    stretched or squeezed one thigh row at a time so the boots stay on the ground line, and
    the join is under the hem so no cut shows."""
    cut_b = (hem_row(body) if hem is None else hem) + 1
    cut_l = hem_row(legs) + 1
    ox = 0
    if align:                                      # hips under hips
        ox = int(round(top_centre(body, cut_b) - top_centre(legs, cut_l)))
    donor = shift(legs, ox, 0)
    mask = leg_pixels(donor)
    lp = donor.copy()
    lp[~mask] = 0
    rows = list(range(cut_l, H))
    n_b = H - cut_b
    n_l = len(rows)
    if n_b < n_l:                                  # body higher in the picture? it is lower: squeeze
        for _ in range(n_l - n_b):
            rows.pop(1)
    elif n_b > n_l:
        for _ in range(n_b - n_l):
            rows.insert(1, rows[0])
    out = body.copy()
    out[cut_b:] = 0
    # the body's own hands / sleeves below the hem stay under the legs (a few rows)
    keep = body.copy()
    keep[:cut_b] = 0
    keep[cut_b + 3:] = 0
    keepm = ~leg_pixels(body) & (keep[..., 3] > 0)
    out[keepm] = body[keepm]
    stretched = lp[rows]
    sel = stretched[..., 3] > 0
    tgt = out[cut_b:]
    tgt[sel] = stretched[sel]
    return out



def graft(base, donor, xmin, ymax, dx, dy, clear=None):
    """`base` with a piece of `donor` pasted over it: the donor's pixels right of column xmin
    and above row ymax (a raised arm and its tool), moved by (dx, dy). `clear` = (y0, y1, x0,
    x1): base pixels in that box that are not coat or trousers (a hand that hangs where the
    new arm comes down) are painted coat red first."""
    out = base.copy()
    if clear:
        y0, y1, x0, x1 = clear
        reg = out[y0:y1, x0:x1]
        r, g, b = [reg[..., i].astype(int) for i in range(3)]
        notred = (reg[..., 3] > 0) & ~((r > 120) & (g < 70) & (b < 70)) & ~((abs(r - g) < 22) & (abs(g - b) < 28))
        reg[notred] = (200, 0, 0, 255)
        reg[...] = snap_team(reg.copy())
    sub = np.zeros_like(donor)
    sub[:ymax + 1, xmin:] = donor[:ymax + 1, xmin:]
    sub = shift(sub, dx, dy)
    m = sub[..., 3] > 0
    out[m] = sub[m]
    return out


# ---------------------------------------------------------------- the sheets

# sheet, x range of the pose's columns, pose, scale key, reference x
SHEETS = [
    ("labourer_build_hammer.png", (0, 1536), "build", "build", "feet"),
    ("labourer_keg_carry_idle.png", (150, 880), "carry_keg", "keg", "coat"),
    ("labourer_keg_carry_idle.png", (1000, 1536), "idle_keg", "keg", "coat"),
    ("labourer_walk_and_carry.png", (150, 780), "walk", "walk", "coat"),
    ("labourer_walk_and_carry.png", (900, 1536), "carry", "walk", "coat"),
    ("labourer_mine_idle_ne_idle_sack.png", (150, 700), "mine", "mine", "coat"),
    ("labourer_mine_idle_ne_idle_sack.png", (700, 1130), "idle", "mine", "coat"),
    ("labourer_mine_idle_ne_idle_sack.png", (1150, 1536), "idle_carry", "mine", "coat"),
]


def raw_frames():
    """Every pose of every sheet, shrunk and placed, no repairs: {(pose, dir): [rgba, ...]}."""
    out = {}
    cache = {}
    for name, xr, pose, sc, mode in SHEETS:
        if name not in cache:
            cache[name] = blobs(name)
        rows = grid(cache[name], xr)
        for d, row in zip(DIRS, rows):
            out[(pose, d)] = [make(s, SCALE[sc], mode) for s in row]
    return out


def walk_legs(raw):
    """The legs of each of the plain walk's 6 frames, per view. A frame keeps its own legs
    unless they repeat a neighbour's (the image AI's feet hardly moved in places):
      s   frame 3 repeated frame 2: the first frame's legs mirrored, left foot a pixel higher
      se  frame 4 repeated 1 and 5 repeated 0: frame 2's and frame 0's legs mirrored
      ne  frames 3 and 4 repeated 2: frames 0's and 1's legs mirrored
      n   frame 5 repeated 4: frame 2's legs mirrored
      e   all six differ: untouched."""
    w = {d: raw[("walk", d)] for d in DIRS}
    out = {}
    out["s"] = [w["s"][0], w["s"][1], w["s"][2], lift_foot(mirror(w["s"][0]), "l", 1), w["s"][4], w["s"][5]]
    out["se"] = [w["se"][0], w["se"][1], w["se"][2], w["se"][3], mirror(w["se"][2]), mirror(w["se"][0])]
    out["e"] = list(w["e"])
    out["ne"] = [w["ne"][0], w["ne"][1], w["ne"][2], mirror(w["ne"][0]), mirror(w["ne"][1]), w["ne"][5]]
    out["n"] = [w["n"][0], w["n"][1], w["n"][2], w["n"][3], w["n"][4], mirror(w["n"][2])]
    return out


# the hammer strips in swing order (raise, drop, strike, lift): the E sheet row drew them
# in another order (its frame 3 is the high hammer, frame 0 the one on its way up)
BUILD_ORDER = {"e": [3, 1, 2, 0]}
BUILD_PIN = 24

# frames whose coat hem is smudged by the AI (a dull red glow where the left hip should be:
# the sack man's south-east frame 1 on the sheet): the legs are cut in under this row instead
SMUDGED_HEM = {("carry", "se", 0): 21}


def final_frames(raw):
    """The replaced poses, repaired: {(pose, dir): [rgba, ...]}."""
    out = {}
    wl = walk_legs(raw)
    for d in DIRS:
        body = raw[("walk", d)]
        out[("walk", d)] = [body[i] if wl[d][i] is body[i] else compose(body[i], wl[d][i]) for i in range(6)]
        # the sack and keg men have hardly any gait of their own: the walk's legs go under them
        for pose in ("carry", "carry_keg"):
            b = raw[(pose, d)]
            out[(pose, d)] = [compose(b[i], wl[d][i], hem=SMUDGED_HEM.get((pose, d, i))) for i in range(6)]
        # standing still: his feet were redrawn in every idle frame (steps of up to 3 px), so
        # the first frame's legs stay under every breath
        for pose in ("idle_keg", "idle_carry"):
            b = raw[(pose, d)]
            out[(pose, d)] = [b[0]] + [compose(b[i], b[0], align=False) for i in range(1, len(b))]
        order = BUILD_ORDER.get(d, [0, 1, 2, 3])
        bf = [raw[("build", d)][i] for i in order]
        # his legs and the stake stay put: rows from BUILD_PIN down are the strike frame's
        # (frame 2) in every frame (the sheet's boots and stake wander by a pixel)
        for f in bf:
            f[BUILD_PIN:] = bf[2][BUILD_PIN:]
        out[("build", d)] = bf
        out[("mine", d)] = list(raw[("mine", d)])
    # the new north-east idle (the other idles stay as they were)
    out[("idle", "ne")] = list(raw[("idle", "ne")])
    # mining, east: the recovery frame lost the pick altogether: the swing frame stands in
    m = raw[("mine", "e")]
    out[("mine", "e")] = [m[0], m[1], m[2], m[1]]
    # mining, north: his back is to us and the AI drew no pick in the raise and recovery frames:
    # the north-east frames' raised arm and pick go over his shoulder
    mn, mne = raw[("mine", "n")], raw[("mine", "ne")]
    out[("mine", "n")] = [graft(mn[0], mne[0], 27, 13, -3, -2, clear=(15, 22, 22, 28)), mn[1], mn[2],
                          graft(mn[3], mne[3], 28, 14, -4, -1, clear=(15, 22, 22, 28))]
    for key in out:
        if key[0] in ("walk", "carry", "carry_keg", "idle_keg", "idle_carry"):
            out[key] = [drop_bright(f) for f in out[key]]
    return out


def write_strips(fr):
    os.makedirs(OUT, exist_ok=True)
    counts = {}
    for (pose, d), frames in sorted(fr.items()):
        Image.fromarray(np.concatenate(frames, 1), "RGBA").save(os.path.join(OUT, f"{pose}_{d}.png"))
        counts[f"{pose}_{d}"] = len(frames)
    return counts


def write_art_data(counts):
    """The labourer entry's frame counts in scripts/art_data.gd (new keys added, nothing
    else in the file changes)."""
    import re
    path = os.path.join(ROOT, "scripts/art_data.gd")
    src = open(path).read()
    start = src.index('\t"labourer": {"cell"')
    end = src.index("\n\t}},\n", start) + 1
    block = src[start:end]
    for key in sorted(counts):
        line = f'\t\t"{key}": {counts[key]},\n'
        pat = re.compile(r'\t\t"' + key + r'": \d+,\n')
        if pat.search(block):
            block = pat.sub(lambda m: line, block, count=1)
        else:
            block = block + line
    open(path, "w").write(src[:start] + block + src[end:])


def check(fr):
    """Warnings: a frame touching the cell's edge (clipped), a frame whose feet are off the
    ground line, a frame much taller or shorter than the rest of its strip."""
    bad = 0
    for (pose, d), frames in sorted(fr.items()):
        tops = []
        for k, f in enumerate(frames):
            a = f[..., 3] > 0
            ys, xs = np.nonzero(a)
            tops.append(int(ys.min()))
            if ys.max() != GROUND:
                print(f"  warn {pose}_{d}[{k}] lowest row {ys.max()} (ground line {GROUND})")
                bad += 1
            if ys.min() == 0 or xs.min() == 0 or xs.max() == W - 1:
                print(f"  warn {pose}_{d}[{k}] touches the cell edge: x {xs.min()}-{xs.max()} y {ys.min()}-{ys.max()}")
                bad += 1
        if pose in ("walk", "carry", "carry_keg", "idle_keg", "idle_carry"):
            med = int(np.median(tops))
            for k, t in enumerate(tops):
                if abs(t - med) > 2:
                    print(f"  warn {pose}_{d}[{k}] top row {t}, strip median {med}")
                    bad += 1
    return bad


def main():
    args = sys.argv[1:]
    raw = raw_frames()
    fr = final_frames(raw)
    bad = check(fr)
    if "--contact" in args:
        cdir = args[args.index("--contact") + 1]
        os.makedirs(cdir, exist_ok=True)
        for pose in sorted({k[0] for k in fr}):
            contact(fr, pose, os.path.join(cdir, pose + ".png"), dirs=[d for d in DIRS if (pose, d) in fr])
        print("contact sheets in", cdir)
    if "--pkl" in args:
        import pickle
        pickle.dump(fr, open(args[args.index("--pkl") + 1], "wb"))
    if "--dry" in args:
        print("dry run: nothing written;", bad, "warnings")
        return
    counts = write_strips(fr)
    write_art_data(counts)
    print(f"wrote {len(counts)} strips to {OUT} and their frame counts to scripts/art_data.gd; {bad} warnings")


if __name__ == "__main__":
    main()
