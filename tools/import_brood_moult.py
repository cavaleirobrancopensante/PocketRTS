#!/usr/bin/env python3
"""Import THE MOULT'S SHELL PIECES (the owner, 2026-10-29; docs/brood_anims.md): what is drawn while a young Brood unit
MATURES (scripts/brood_mature.gd, scripts/moult_look.gd). The young unit and the Challenger are the game's own sprites
(the same style as the rest of the Brood); only the SHELL, its CRACKING and what is LEFT ON THE GROUND come from the
owner's three GEMINI sheets (ChatGPT had run out):
  art/redraws/moult_venom_se_gemini.jpg   (Spitter -> Venom Challenger)
  art/redraws/moult_tyrant_se_gemini.jpg  (Raptor -> Tyrant Challenger)
  art/redraws/moult_storm_se_gemini.jpg   (Hatchling -> Storm Challenger: a 1024 grid of small frames)

THE GEMINI FRAMES ARE NOT PLAYED AS DRAWN (JPEG, softer, other shading, a grey stone shell, sizes and angles that wander).
What is taken, by a box on each sheet (BOXES, y0 x0 y1 x1), and what is done to it:
  shell_se  the closed shell, then its cracking frames (each line's own: Venom 1+3, Tyrant 1+2, Storm 1+3)
  open_se   the empty shell burst in two halves (the Storm sheet's bottom right: the only empty shell drawn; used for
            all three lines), its two halves and chips pulled closer together (OPEN_SQUEEZE)
  skin_se   the shed grey skin (the Venom sheet's; the Tyrant sheet has the very same drawing): Venom and Tyrant only (a
            lizard skin; the Storm line leaves only its broken shell)
Dropped: every frame with the creature in it (the young curling, the Challenger stepping out, the Tyrant's red-glowing
creature, the flying frames): the game uses its own sprites there.
CLEANING (JPEG): the navy keyed on a 3x3 median (ibn.key_mask jpeg), specks dropped, the colours denoised by a 3x3
median at sheet size, then shrunk straight to game size (a box filter: 3-5 sheet px to one game px), a mild unsharp mask,
and the outline darkened as the ChatGPT sprites' are. RECOLOUR to the cocoon's palette (art/redraws/grub_cocoon_se_chatgpt
.png, ChatGPT: the Brood's olive case with yellow-green glowing cracks): the grey stone takes the cocoon case's olive by
brightness rank (histogram matched); the green cracks and lightning and the red glow inside take the cocoon's
yellow-green glow; the shed skin a dull, half-greyed olive. No team colour in these pieces (the exact key reds nudged off).
SIZES (game px): the closed shell SHELL_W wide (about halfway from the young unit to the Challenger: the game swells it
from a little over the young one's size); the skin SKIN_W (the young one's length). One cell per line, the anchor at the
pieces' ground middle (each piece's bottom middle on it).
Writes art keys "moult_venom", "moult_tyrant", "moult_storm" (assets/units/moult_<line>/).
Re-runnable: python3 -I tools/import_brood_moult.py [--contact DIR]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
import matplotlib.colors as mcolors

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402
import import_sire_lure as isl  # noqa: E402
import import_brood_cocoon as icn  # noqa: E402

R = ibn.R
SHEET = {"venom": "moult_venom_se_gemini.jpg", "tyrant": "moult_tyrant_se_gemini.jpg", "storm": "moult_storm_se_gemini.jpg"}
# (sheet, box y0 x0 y1 x1)
BOXES = {
    "venom": {"shell": [("venom", (66, 735, 218, 890)), ("venom", (60, 1168, 218, 1330)), ("venom", (305, 48, 468, 216)),
                        ("venom", (292, 283, 467, 450))]},
    "tyrant": {"shell": [("tyrant", (316, 46, 480, 212)), ("tyrant", (296, 285, 480, 478)), ("tyrant", (298, 546, 478, 747))]},
    "storm": {"shell": [("storm", (268, 522, 346, 603)), ("storm", (354, 110, 434, 194)), ("storm", (356, 213, 434, 297)),
                        ("storm", (356, 311, 434, 403))]},
}
OPEN = ("storm", (930, 785, 1012, 975))
SKIN = ("venom", (636, 985, 735, 1161))
SHELL_W = {"venom": 54.0, "tyrant": 34.0, "storm": 38.0}
SKIN_W = {"venom": 42.0, "tyrant": 30.0}
OPEN_SQUEEZE = 0.45
COCOON = "grub_cocoon_se_chatgpt.png"


def load(name):
    return ia.load(R + SHEET[name])


def piece(px, box):
    """The keyed piece in box (y0, x0, y1, x1) of a JPEG sheet: RGBA, colours median-denoised, specks dropped."""
    y0, x0, y1, x1 = box
    sub = px[y0:y1, x0:x1].copy()
    fg = ibn.key_mask(px, jpeg=True)[y0:y1, x0:x1]
    lab, n = ndimage.label(fg)
    if n:
        sz = ndimage.sum(fg, lab, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sz >= 40
        fg = keep[lab]
    rgb = ndimage.median_filter(sub[..., :3], size=(3, 3, 1))
    out = np.zeros(sub.shape, np.int32)
    out[..., :3] = rgb
    out[..., 3] = np.where(fg, 255, 0)
    ys, xs = np.nonzero(fg)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def lum(rgb):
    return rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11


# ------------------------------------------------------------------ the cocoon's palette

def cocoon_palette():
    px = ia.load(R + COCOON)
    fg = ibn.key_mask(px)
    rgb = px[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    L = lum(rgb)
    glow = fg & (g >= 175) & (g >= r * 1.02) & (b < g * 0.5)
    case = fg & ~glow & (g >= r * 0.92) & (b < g * 0.75) & (L > 18)
    cs = rgb[case]
    cs = cs[np.argsort(lum(cs))]
    gl = rgb[glow]
    gl = gl[np.argsort(lum(gl))]
    return cs, gl


def ramp(sorted_cols, q):
    """The colour at rank q (0..1) of a brightness-sorted list (a little averaged)."""
    n = len(sorted_cols)
    i = np.clip((q * (n - 1)).astype(int), 0, n - 1)
    return sorted_cols[i]


def recolour(im, case, glow, dull=0.0):
    rgb = im[..., :3].astype(float)
    a = im[..., 3] > 0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = a & (g > r * 1.22) & (g > b * 1.35) & (g > 80)
    yellow = a & (r > 150) & (g > 150) & (b < 0.6 * g)          # (the Storm sheet's yellow lightning)
    red = a & (r > g * 1.5) & (r > 90)
    hot = green | yellow | red
    # (the cracks are 2-3 sheet px thin: a pixel more round them, or the shrink to game size loses them)
    hot = ndimage.binary_dilation(hot, iterations=1) & a
    stone = a & ~hot
    out = rgb.copy()
    L = lum(rgb)
    if stone.any():
        order = np.argsort(np.argsort(L[stone]))
        q = order / max(1, stone.sum() - 1)
        col = ramp(case, q)
        if dull:
            grey = lum(col)[:, None] * np.ones(3)
            col = col * (1 - dull) + grey * dull + np.array([8, 6, 0]) * dull
        out[stone] = col
    if hot.any():
        # the glow by its own brightness (red counts as bright: the hot inside)
        hl = np.maximum(L[hot], np.where(red[hot], r[hot] * 0.8, 0))
        q = np.clip((hl - 30) / 150.0, 0, 1)
        out[hot] = ramp(glow, q)
    o = im.copy()
    o[..., :3] = out.clip(0, 255).astype(np.int32)
    return o


def finish(small):
    """After the shrink: a mild unsharp mask, the outline darkened (as the ChatGPT sprites'), no exact key reds."""
    a = small[..., 3] > 0
    img = Image.fromarray(small[..., :3].astype(np.uint8)).filter(ImageFilter.UnsharpMask(radius=1, percent=70, threshold=2))
    rgb = np.array(img).astype(float)
    edge = a & ~ndimage.binary_erosion(a, iterations=1, border_value=0)
    rgb[edge] *= 0.55
    out = small.copy()
    out[..., :3] = np.where(a[..., None], rgb, 0).clip(0, 255).astype(np.int32)
    return isl._unteam_rest(out.astype(np.int32), np.zeros(a.shape, bool))


def bottom_mid(im):
    ys, xs = np.nonzero(im[..., 3] > 0)
    bot = ys.max()
    low = ys > bot - max(2, (bot - ys.min()) * 0.12)
    return float(xs[low].mean()), float(bot + 1)


def body_w(im):
    """The width of a shell piece's body (its widest solid rows: sparks and lightning outside it do not count)."""
    a = im[..., 3] > 0
    solid = ndimage.binary_opening(a, iterations=3)
    xs = np.nonzero(solid.any(0))[0]
    return float(xs.max() - xs.min() + 1) if len(xs) else float(a.shape[1])


def squeeze_open(im):
    """The two halves and the chips pulled toward the middle (OPEN_SQUEEZE of their distance from it)."""
    a = im[..., 3] > 0
    lab, n = ndimage.label(a)
    cx = a.shape[1] / 2.0
    parts = []
    for i in range(1, n + 1):
        m = lab == i
        ys, xs = np.nonzero(m)
        if len(ys) < 25:
            continue
        mx = xs.mean()
        dx = int(round((mx - cx) * (OPEN_SQUEEZE - 1.0)))
        parts.append((m, dx, len(ys)))
    W = a.shape[1]
    out = np.zeros_like(im)
    # the biggest pieces (the halves) last: on top of the chips
    for m, dx, _ in sorted(parts, key=lambda p: p[2]):
        ys, xs = np.nonzero(m)
        nx = np.clip(xs + dx, 0, W - 1)
        out[ys, nx] = im[ys, xs]
    ys, xs = np.nonzero(out[..., 3] > 0)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ------------------------------------------------------------------ the shell from the cocoon sheet (used)

# the cocoon sheet's frames (from 0) the moult's shell is made of: 5 the full case (closed), 6-8 it glows, shakes and
# cracks, 9-10 it splits open, 11 the empty broken shell
COC_CLOSED, COC_CRACK, COC_SPLIT, COC_EMPTY = 5, [6, 7, 8], [9, 10], 11
STONE = 0.55          # how far the case's olive goes toward a warm stone grey (the Gemini concept's grey shell)


def cocoon_frames():
    px = ia.load(R + COCOON)
    return [isl.crop(px, m)[0] for m in isl.slot_masks(px)]


def no_earth(im):
    """The cocoon frame without its earth mound (the brown clods): the case, its spikes and its glow; specks dropped."""
    rgb = im[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = im[..., 3] > 0
    # (by hue: the earth is orange-brown, 15-34 degrees; the case olive, 45-62; the spikes red, under 12 and saturated)
    hsv = mcolors.rgb_to_hsv(np.clip(rgb / 255.0, 0, 1))
    H, S = hsv[..., 0] * 360.0, hsv[..., 1]
    red = (r > g * 1.8) & (r > 90)
    brown = a & ~red & (H < 40) & (S > 0.18)
    # (only the mound: brown in the frame's lowest part, or beside the case (outside the columns its body covers higher
    # up); the dark brown inside a split case (its hollow) stays)
    h, w = a.shape
    band = (a & ~brown)[int(h * 0.3):int(h * 0.6)]
    cols = np.nonzero(ndimage.binary_opening(band, iterations=2).any(0))[0]
    x0, x1 = (cols.min() + 3, cols.max() - 3) if len(cols) else (0, w)
    xx = np.arange(w)[None, :]
    yy = np.arange(h)[:, None]
    # the case's round bottom (hidden in the mound on the sheet): an ellipse as wide as its body, as tall as wide less a
    # little (the case is a low egg), from its top; below its middle nothing outside the ellipse is kept
    top = np.nonzero((a & ~brown & ~red).any(1))[0]
    top = int(top.min()) if len(top) else 0
    rx = (x1 - x0) / 2.0 + 2.0
    cx = (x0 + x1) / 2.0
    ry = rx * 0.98
    cy = top + ry
    inside = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0
    brown = brown & ~inside | (a & ~inside & (yy > cy))
    dark = a & (rgb.max(-1) < 50) & ndimage.binary_dilation(brown, iterations=2)      # (the clods' dark shading)
    keep = a & ~brown & ~dark
    keep = ndimage.binary_opening(keep, iterations=1)
    lab, n = ndimage.label(keep)
    if n:
        sz = ndimage.sum(keep, lab, range(1, n + 1))
        big = int(np.argmax(sz)) + 1
        near = ndimage.binary_dilation(lab == big, iterations=6)
        ok = np.zeros(n + 1, bool)
        for i in range(1, n + 1):
            ok[i] = i == big or (sz[i - 1] >= 30 and (near & (lab == i)).any())
        keep = ok[lab] & (lab > 0)
    out = im.copy()
    out[~keep] = 0
    ys, xs = np.nonzero(keep)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def stone(im):
    """The olive case toward a warm stone grey (STONE); the yellow-green glow and the red spikes as drawn."""
    rgb = im[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = im[..., 3] > 0
    glow = (g >= 165) & (b < g * 0.6)
    red = (r > g * 1.8) & (r > 90)
    case = a & ~glow & ~red
    L = lum(rgb)[..., None]
    grey = L * np.array([1.04, 1.0, 0.86])
    out = rgb.copy()
    out[case] = (rgb * (1 - STONE) + grey * STONE)[case]
    o = im.copy()
    o[..., :3] = out.clip(0, 255).astype(np.int32)
    return o


def build(line, sheets, case, glow):
    fr = cocoon_frames()
    full = no_earth(fr[COC_CLOSED])
    s = SHELL_W[line] / body_w(full)

    def cut(i):
        return icn.snap(ia.shrink(stone(no_earth(fr[i])), s)).astype(np.int32)
    pieces = {"shell": [cut(i) for i in [COC_CLOSED] + COC_CRACK], "split": [cut(i) for i in COC_SPLIT],
              "open": [cut(COC_EMPTY)]}
    if line in SKIN_W:
        sk = recolour(piece(sheets[SKIN[0]], SKIN[1]), case, glow, dull=0.45)
        pieces["skin"] = [finish(ia.shrink(sk, SKIN_W[line] / sk.shape[1]))]
    print(f"  {line}: the cocoon's case at {s:.3f}" + (", the Gemini skin" if line in SKIN_W else ""))
    return pieces


# ------------------------------------------------------------------ the Gemini shell (tried, not used: --gemini)

def build_gemini(line, sheets, case, glow):
    shell = []
    for nm, box in BOXES[line]["shell"]:
        shell.append(recolour(piece(sheets[nm], box), case, glow))
    s = SHELL_W[line] / body_w(shell[0])
    pieces = {"shell": [finish(ia.shrink(p, s)) for p in shell]}
    op = squeeze_open(recolour(piece(sheets[OPEN[0]], OPEN[1]), case, glow))
    # (the open shell: its two halves together SHELL_W x 1.55, each about as wide as the closed shell's body)
    so = SHELL_W[line] * 1.55 / op.shape[1]
    pieces["open"] = [finish(ia.shrink(op, so))]
    if line in SKIN_W:
        sk = recolour(piece(sheets[SKIN[0]], SKIN[1]), case, glow, dull=0.45)
        pieces["skin"] = [finish(ia.shrink(sk, SKIN_W[line] / sk.shape[1]))]
    print(f"  {line}: shell scale {s:.3f} ({len(shell)} frames), open {so:.3f}" + (", skin" if line in SKIN_W else ""))
    return pieces


def assemble(line, pieces, data):
    placed = {k: [(im, -np.array(bottom_mid(im))) for im in lst] for k, lst in pieces.items()}
    L = R_ = U = 0.0
    for lst in placed.values():
        for im, (x, y) in lst:
            L = max(L, -x); R_ = max(R_, x + im.shape[1]); U = max(U, -y)
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    H = top + 2
    name = f"moult_{line}"
    counts = {}
    for k, lst in placed.items():
        strip = np.zeros((H, W * len(lst), 4), np.uint8)
        for i, (im, (x, y)) in enumerate(lst):
            ox, oy = int(round(half + x)), int(round(top + y))
            h, w = im.shape[:2]
            m = im[..., 3] > 0
            strip[:, i * W:(i + 1) * W][oy:oy + h, ox:ox + w][m] = im[m]
        ia.save(strip, f"{ia.OUT}/units/{name}/{k}_se.png")
        counts[f"{k}_se"] = len(lst)
    data[name] = {"cell": (W, H), "anchor": (half, top), "frames": counts}
    ibn.write_entry(name, data[name])
    print(f"  {name}: cell {W}x{H}, " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    sheets = {k: load(k) for k in SHEET}
    case, glow = cocoon_palette()
    data = {}
    if contact_dir and "--gemini" in sys.argv:
        # (the look of the Gemini shells, cleaned and recoloured, for the record; then the used pieces written over them)
        gd = {}
        for line in ("venom", "tyrant", "storm"):
            assemble(line, build_gemini(line, sheets, case, glow), gd)
        contact(contact_dir, gd, "moult_gemini_pieces")
    for line in ("venom", "tyrant", "storm"):
        assemble(line, build(line, sheets, case, glow), data)
    if contact_dir:
        contact(contact_dir, data)


# ------------------------------------------------------------------ the look at game size

YOUNG = {"venom": ("spitter", "venom_challenger"), "tyrant": ("raptor", "tyrant_challenger"),
         "storm": ("hatchlings", "storm_challenger")}


def unit_frame(kind, strip, i=0):
    import re
    src = open("scripts/art_data.gd").read()
    m = re.search(r'\t"' + kind + r'": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    W, H = int(m.group(1)), int(m.group(2))
    im = Image.open(f"{ia.OUT}/units/{kind}/{strip}.png").convert("RGBA")
    return im.crop((i * W, 0, (i + 1) * W, H)), (float(m.group(3)), float(m.group(4)))


def contact(d, data, stem="moult_pieces"):
    """Each line at game size on grass, feet on one line: the young unit, every shell frame, the open shell, the skin,
    the Challenger, and a cocoon frame (ChatGPT) for the style; then the same blown up 3x."""
    os.makedirs(d, exist_ok=True)
    rows = []
    for line in ("venom", "tyrant", "storm"):
        y, m = YOUNG[line]
        items = [unit_frame(y, "idle_se")]
        name = f"moult_{line}"
        e = data[name]
        for k in ("shell", "split", "open", "skin"):
            n = e["frames"].get(f"{k}_se", 0)
            for i in range(n):
                im = Image.open(f"{ia.OUT}/units/{name}/{k}_se.png").convert("RGBA")
                W, H = e["cell"]
                items.append((im.crop((i * W, 0, (i + 1) * W, H)), e["anchor"]))
        items.append(unit_frame(m, "idle_se"))
        items.append(unit_frame("brood_cocoon", "open_se", 3))
        up = int(max(a[1] for _, a in items)) + 2
        dn = int(max(im.height - a[1] for im, a in items)) + 2
        wd = sum(im.width for im, _ in items) + 6 * len(items)
        row = Image.new("RGBA", (wd, up + dn), (86, 110, 60, 255))
        x = 0
        for im, (ax, ay) in items:
            row.alpha_composite(im, (x, int(up - ay)))
            x += im.width + 6
        rows.append(row)
    W = max(r.width for r in rows)
    out = Image.new("RGBA", (W, sum(r.height for r in rows)), (86, 110, 60, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out.save(f"{d}/{stem}_1x.png")
    out.resize((out.width * 3, out.height * 3), Image.NEAREST).save(f"{d}/{stem}_3x.png")


if __name__ == "__main__":
    main()
