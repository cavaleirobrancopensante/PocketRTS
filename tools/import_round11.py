"""Round 11 art: painted unit portraits, Crown research icons, ability icons for the
command card, the Clockwork Engine Hall and the musketeers' bayonet thrust.

Sources (generated sheets on a flat dark slate background, every icon in its own frame):
  art/ui/icons2/portraits_crown_a.png   musketeer (tricorne), musketeer_armoured, cuirassier
  art/ui/icons2/portraits_crown_b.png   mortar, balloon, powder_wagon, missionary (frames
                                        drawn taller than wide: see FIT)
  art/ui/icons2/portraits_brood_a.png   grub, raptor, spitter, brute
  art/ui/icons2/portraits_brood_b.png   skywing, spore_mother, bloater
  art/ui/icons2/portraits_clockwork.png top row winder, thresher, bulwark, windup_soldier;
                                        bottom row arc_thrower, steam_walker, stormcaller,
                                        tesla_cart, ornithopter
  art/ui/icons2/research_crown.png      armour, matchlock, flintlock, caplock
  art/ui/icons2/abilities_crown.png     3x3: load, unload, limber / round_shot, canister,
                                        supply / revive, rotate, bury
  art/ui/icons2/abilities_brood_clockwork.png  rows of 4, 4, 3: harvest, sacrifice, miasma,
                                        root / hold_gas, land, overload, storm / deploy,
                                        brace, windup (brass frames)
  art/clockwork/engine_hall.png         built, construction, damaged, destroyed
  art/crown/musketeer_bayonet.png       left half the tricorne musketeer, right half the
                                        armoured one; rows s, se, e, ne, n (n = back view);
                                        3 frames each: step, thrust, recover

Icons (64x64, fully opaque, key reds nudged off: icons are not team-coloured):
  * steel-framed sheets (portraits, research, Crown abilities): the picture inside the
    frame is cut out (the frame's inner black line found on scan lines from each side),
    made square (FIT: part cropped, part padded with the picture's own backdrop - the
    Crown B frames are 17% taller than wide), box-shrunk to 52x52, lightly sharpened and
    set in the 6 px steel bevel of the hand-painted Crown icons (per-side median profile
    of the cannon / pikeman / labourer icons), so every portrait matches assets/icons/musketeer
    .png: frame to the 64 px edge, picture 52x52 from (6, 6).
  * brass-framed sheet (Brood / Clockwork abilities): cut at the frame's outer outline and
    box-shrunk whole (like the round 7 Clockwork / Brood command icons), the bevelled
    corners filled with the frame's black.
  * the six Brood abilities (harvest, sacrifice, miasma, root, hold_gas, land) are drawn in
    the brass frame on the sheet: their picture (inside the brass frame) is re-framed in
    the Brood command icons' frame (per-pixel median of assets/icons/brood/*.png where
    those agree and aren't backdrop, corner knobs included), its navy shifted to theirs.
  * ab_courier (no icon on the sheet): the ornithopter from its portrait (lifted off its
    backdrop) carrying the battery of the OVERLOAD icon, in the brass frame of that sheet.
  Output: assets/icons/<kind>.png, assets/icons/research_<name>.png, assets/icons/ab_<name>.png

Engine Hall: every state cut from its panel, one scale for the sheet so the plinth of the
built hall is ENGINE_PLINTH px wide (a 4x4-tile footprint: Assembly Works, 4x3, is 136
px), each state centred on its own plinth (building.gd centres the texture and puts its
bottom on the footprint), slate fringe and specks cleaned. Plus the 64x64 building icon
(make_icon, like the other buildings). Output assets/buildings/engine_hall_<state>.png,
assets/icons/engine_hall.png. Not added to defs.gd / art_data.gd (BUILDING_SIZE is not
read by the game).

Bayonet: the "melee_<dir>" strips of musketeer and musketeer_armoured are replaced by the
sheet's frames (round 10 synthesized them from the aim pose): cut with the round 4
machinery (slate mask, box-filter shrink, team reds snapped to #FF0000 / #960000, fringe
cleanup), one scale per half fitted so the standing back view's body (no musket) is
MUSK_H (32) px like the round 10 musketeers, feet held steady on the legs, drawn on the
musketeer cell 90x36 with the soles on anchor (45, 34). The sheet's muskets are straight
already: tools/fix_weapons.py only repaints walk / idle and is not run on these. The
"melee_<dir>" counts in both entries of scripts/art_data.gd are rewritten in place.

Order (tools/rebuild_art.sh): last - after import_round10.py (writes the old melee strips
and some of the icons replaced here) and every other pass that writes icons.

Usage (from the repo root): python3 tools/import_round11.py [--contact DIR]
(--contact writes x3 contact sheets). Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # round 4 reads its own flags
import import_round4 as r4  # noqa: E402
import import_round5 as r5  # noqa: E402
import import_round10 as r10  # noqa: E402
sys.argv = _argv
from import_art import load, make_icon, unteam  # noqa: E402
from import_cannon2 import bg_mask, clean  # noqa: E402
from import_round4 import steady  # noqa: E402

CONTACT = _argv[_argv.index("--contact") + 1] if "--contact" in _argv else None
DIRS = ["s", "se", "e", "ne", "n"]
SRC = "art/ui/icons2"

# sheet -> names in reading order (row by row, left to right)
PORTRAITS = {
    "portraits_crown_a": ["musketeer", "musketeer_armoured", "cuirassier"],
    "portraits_crown_b": ["mortar", "balloon", "powder_wagon", "missionary"],
    "portraits_brood_a": ["grub", "raptor", "spitter", "brute"],
    "portraits_brood_b": ["skywing", "spore_mother", "bloater"],
    "portraits_clockwork": ["winder", "thresher", "bulwark", "windup_soldier",
                            "arc_thrower", "steam_walker", "stormcaller", "tesla_cart", "ornithopter"],
    "research_crown": ["research_armour", "research_matchlock", "research_flintlock", "research_caplock"],
    "abilities_crown": ["ab_load", "ab_unload", "ab_limber", "ab_round_shot", "ab_canister",
                        "ab_supply", "ab_revive", "ab_rotate", "ab_bury"],
}
BRASS = {"abilities_brood_clockwork": ["ab_harvest", "ab_sacrifice", "ab_miasma", "ab_root",
                                       "ab_hold_gas", "ab_land", "ab_overload", "ab_storm",
                                       "ab_deploy", "ab_brace", "ab_windup"]}

# Squaring a picture that isn't square: (share of the excess cropped - the rest is padded
# with the backdrop, where along the long side the crop is taken: 0 = keep the start
# (top / left), 0.5 = centre, 1 = keep the end). Default: half cropped, centred.
FIT = {
    "mortar": (1.0, 0.85),         # the arm and the bed touch the sides: crop the smoke
    "balloon": (0.0, 0.5),         # free on both sides, top and bottom used: pad
    "powder_wagon": (1.0, 0.3),    # touches both sides: a little canvas top, more wheel
    "missionary": (1.0, 0.0),      # a bust: keep the hat, crop the waist
    "research_armour": (1.0, 0.5),
}

ICON = 64
BEVEL = 6                          # the steel frame of the Crown icons (incl. its black line)
INNER = ICON - 2 * BEVEL


def lum(px):
    return px[..., :3].astype(float).mean(-1)


def frame_boxes(px, bg, n):
    """The n framed icons: biggest non-slate pieces, in reading order."""
    lab, k = ndimage.label(~bg, structure=np.ones((3, 3)))
    size = ndimage.sum(~bg, lab, np.arange(1, k + 1))
    objs = ndimage.find_objects(lab)
    boxes = [objs[i] for i in np.argsort(size)[::-1][:n]]
    boxes.sort(key=lambda s: (s[0].start // 120, s[1].start))
    return boxes


def outer_edges(bg, sl):
    """The frame's outer outline (the corner rivets / dots stick out of the bbox): first
    and last non-slate pixel on the middle row and column."""
    y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
    row = ~bg[(y0 + y1) // 2, x0:x1]
    col = ~bg[y0:y1, (x0 + x1) // 2]
    xs, ys = np.flatnonzero(row), np.flatnonzero(col)
    return y0 + ys.min(), y0 + ys.max() + 1, x0 + xs.min(), x0 + xs.max() + 1


def inner_depth(profile):
    """Depth of the frame along one scan line from outside in: past the bright steel and
    the black line after it. None where art covers the black line (no dark run found)."""
    n = len(profile)
    lim = max(12, n // 6)
    peak = int(np.argmax(profile[:lim]))
    i = peak
    while i < lim and profile[i] > 12:
        i += 1                                      # down the inner bevel to the black line
    if i >= lim:
        return None
    while i < n and profile[i] <= 12:
        i += 1                                      # across the black line
    return i


def side_depth(lines):
    """The depth most scan lines agree on (ties: the shallower); None if none found it."""
    vals = [v for v in lines if v is not None]
    if not vals:
        return None
    u, c = np.unique(vals, return_counts=True)
    return int(u[c == c.max()].min())


def inner_box(px, oy0, oy1, ox0, ox1):
    """The picture inside the frame: per side the depth most of nine scan lines agree on
    (art next to the frame or over its black line spoils single lines); a side where no
    line found the black line takes the median of the other sides."""
    L = lum(px)
    h, w = oy1 - oy0, ox1 - ox0
    fr = np.linspace(0.15, 0.85, 9)
    d = [side_depth([inner_depth(L[oy0 + int(h * f), ox0:ox1]) for f in fr]),
         side_depth([inner_depth(L[oy0 + int(h * f), ox0:ox1][::-1]) for f in fr]),
         side_depth([inner_depth(L[oy0:oy1, ox0 + int(w * f)]) for f in fr]),
         side_depth([inner_depth(L[oy0:oy1, ox0 + int(w * f)][::-1]) for f in fr])]
    known = [v for v in d if v is not None]
    d = [v if v is not None else int(np.median(known)) for v in d]
    left, right, top, bot = d
    return oy0 + top, oy1 - bot, ox0 + left, ox1 - right


def backdrop(pic):
    edge = np.concatenate([pic[:2].reshape(-1, pic.shape[2]), pic[-2:].reshape(-1, pic.shape[2]),
                           pic[:, :2].reshape(-1, pic.shape[2]), pic[:, -2:].reshape(-1, pic.shape[2])])
    dark = edge[lum(edge) < 45]
    return np.median(dark if len(dark) else edge, 0)


def square(pic, name):
    """The picture made square: part of the excess cropped, the rest padded (FIT)."""
    h, w = pic.shape[:2]
    if abs(h - w) <= 1:
        return pic
    crop_share, keep = FIT.get(name, (0.5, 0.5))
    long_, short = max(h, w), min(h, w)
    excess = long_ - short
    cut = int(round(excess * crop_share))
    a = int(round(cut * keep))
    if h > w:
        pic = pic[a:h - (cut - a)]
    else:
        pic = pic[:, a:w - (cut - a)]
    h, w = pic.shape[:2]
    side = max(h, w)
    out = np.empty((side, side, pic.shape[2]), pic.dtype)
    out[...] = backdrop(pic).round().astype(pic.dtype)
    oy, ox = (side - h) // 2, (side - w) // 2
    out[oy:oy + h, ox:ox + w] = pic
    return out


def shrink(pic, size):
    im = Image.fromarray(pic[..., :3].astype(np.uint8), "RGB").resize((size, size), Image.BOX)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    return np.array(im)


_RING = None
RING_REFS = ("cannon", "pikeman", "labourer")     # hand-painted by import_art, not rewritten here


def ring():
    """The steel bevel of the hand-painted Crown icons: per side (left, right, top,
    bottom; the bright line isn't at the same depth on every side) the median colour at
    each depth from the edge."""
    global _RING
    if _RING is None:
        refs = [np.array(Image.open(f"assets/icons/{n}.png").convert("RGB")).astype(float)
                for n in RING_REFS]
        sides = [lambda r: r[12:52, :BEVEL], lambda r: r[12:52, ::-1][:, :BEVEL],
                 lambda r: r[:BEVEL, 12:52].transpose(1, 0, 2), lambda r: r[::-1][:BEVEL, 12:52].transpose(1, 0, 2)]
        _RING = [np.median(np.concatenate([f(r) for r in refs], 0), 0).round().astype(np.uint8) for f in sides]
    return _RING


def framed(inner_rgb):
    icon = np.zeros((ICON, ICON, 4), np.uint8)
    icon[..., 3] = 255
    icon[BEVEL:ICON - BEVEL, BEVEL:ICON - BEVEL, :3] = inner_rgb
    left, right, top, bottom = ring()
    E = ICON - 1
    for d in range(BEVEL):
        icon[d, d:ICON - d, :3] = top[d]
        icon[E - d, d:ICON - d, :3] = bottom[d]
        icon[d + 1:E - d, d, :3] = left[d]
        icon[d + 1:E - d, E - d, :3] = right[d]
    return icon


def save_icon(icon, name):
    icon = unteam(icon.copy())
    Image.fromarray(icon, "RGBA").save(f"assets/icons/{name}.png")
    return icon


def build_steel_icons():
    made, pics = {}, {}
    for sheet, names in PORTRAITS.items():
        px = load(f"{SRC}/{sheet}.png")
        bg, _ = bg_mask(px)
        for name, sl in zip(names, frame_boxes(px, bg, len(names))):
            oy0, oy1, ox0, ox1 = outer_edges(bg, sl)
            iy0, iy1, ix0, ix1 = inner_box(px, oy0, oy1, ox0, ox1)
            pic = px[iy0:iy1, ix0:ix1].copy()
            pics[name] = pic
            made[name] = save_icon(framed(shrink(square(pic, name), INNER)), name)
            print(f"icons/{name}.png: frame {ox1 - ox0}x{oy1 - oy0} at ({ox0}, {oy0}), "
                  f"picture {ix1 - ix0}x{iy1 - iy0} (inset l{ix0 - ox0} r{ox1 - ix1} t{iy0 - oy0} b{oy1 - iy1})")
    return made, pics


def brass_crop(px, bg, sl):
    crop = px[sl].astype(np.uint8).copy()
    crop[..., 3] = 255
    crop[bg[sl]] = (14, 12, 12, 255)
    return crop


def brass_icon(crop):
    im = Image.fromarray(crop, "RGBA").resize((ICON, ICON), Image.BOX)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    a = np.array(im)
    a[..., 3] = 255
    return a


def build_brass_icons():
    made, crops = {}, {}
    for sheet, names in BRASS.items():
        px = load(f"{SRC}/{sheet}.png")
        bg, _ = bg_mask(px)
        for name, sl in zip(names, frame_boxes(px, bg, len(names))):
            crop = brass_crop(px, bg, sl)
            crops[name] = crop
            made[name] = save_icon(brass_icon(crop), name)
            print(f"icons/{name}.png from {crop.shape[1]}x{crop.shape[0]} at ({sl[1].start}, {sl[0].start})")
    return made, crops


# Brood abilities: the sheet drew them in the Clockwork brass frame; they are re-framed in
# the bone-and-sinew frame of the Brood command icons (assets/icons/brood/*.png, round 7).
BROOD_ABILITIES = ["ab_harvest", "ab_sacrifice", "ab_miasma", "ab_root", "ab_hold_gas", "ab_land"]
BROOD_CMDS = ["move", "attack", "stop", "build", "gather", "repair"]


def navyish(rgb):
    rgb = rgb.astype(int)
    return (rgb[..., 2] >= rgb[..., 0] + 8) & (rgb[..., :3].mean(-1) < 90)


def brood_frame():
    """The Brood frame as an overlay: the per-pixel median of the six Brood command icons,
    kept where they agree (std < 14), aren't the navy backdrop and lie within 11 px of the
    edge (the corner knobs reach that far in); plus the opening (y0, y1, x0, x1) inside
    the frame on the middle row / column and the backdrop colour."""
    A = np.stack([np.array(Image.open(f"assets/icons/brood/{n}.png").convert("RGB")).astype(float)
                  for n in BROOD_CMDS])
    med = np.median(A, 0)
    cons = A.std(0).mean(-1) < 14
    yy, xx = np.mgrid[0:ICON, 0:ICON]
    edge = np.minimum(np.minimum(yy, xx), np.minimum(ICON - 1 - yy, ICON - 1 - xx))
    mask = cons & ~navyish(med) & (edge <= 11)
    mask |= edge <= 4                               # the outer bevel always
    mid = ICON // 2
    row, col = mask[mid], mask[:, mid]
    x0 = int(np.flatnonzero(~row[:mid]).min())
    x1 = mid + int(np.flatnonzero(~row[mid:]).max()) + 1
    y0 = int(np.flatnonzero(~col[:mid]).min())
    y1 = mid + int(np.flatnonzero(~col[mid:]).max()) + 1
    inside = np.zeros_like(mask)
    inside[y0:y1, x0:x1] = True
    bgc = np.median(med[inside & ~mask & navyish(med) & cons], 0)
    return med.round().astype(np.uint8), mask, (y0, y1, x0, x1), bgc


def brass_inner(crop, box=False):
    """The picture inside a brass frame: per side the depth (mode of nine scan lines) at
    which the navy backdrop starts."""
    nv = navyish(crop[..., :3]) & (crop[..., :3].astype(int).mean(-1) < 70)
    H, W = nv.shape
    fr = np.linspace(0.2, 0.8, 9)

    def depth(line):
        lim = len(line) // 4
        i = 3
        while i < lim and not line[i]:
            i += 1
        return i if i < lim else None
    d = [side_depth([depth(nv[int(H * f)]) for f in fr]),
         side_depth([depth(nv[int(H * f)][::-1]) for f in fr]),
         side_depth([depth(nv[:, int(W * f)]) for f in fr]),
         side_depth([depth(nv[:, int(W * f)][::-1]) for f in fr])]
    known = [v for v in d if v is not None]
    left, right, top, bot = [v if v is not None else int(np.median(known)) for v in d]
    if box:
        return top, H - bot, left, W - right
    return crop[top:H - bot, left:W - right]


def rebackdrop(pic, to):
    """Shift the picture's navy backdrop to the Brood icons' navy (pixels near the old
    backdrop colour move fully, others less the further they are)."""
    rgb = pic[..., :3].astype(float)
    frm = backdrop(pic)[:3]
    dist = np.abs(rgb - frm).max(-1)
    w = np.clip(1 - dist / 40.0, 0, 1)[..., None]
    out = pic.copy()
    out[..., :3] = np.clip(rgb + w * (np.asarray(to, float) - frm), 0, 255).round().astype(np.uint8)
    return out


def build_brood_reframed(brass_crops):
    med, mask, (y0, y1, x0, x1), bgc = brood_frame()
    made = {}
    for name in BROOD_ABILITIES:
        pic = rebackdrop(brass_inner(brass_crops[name]), bgc)
        h, w = y1 - y0, x1 - x0
        im = Image.fromarray(pic[..., :3].astype(np.uint8), "RGB").resize((w, h), Image.BOX)
        im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
        icon = np.zeros((ICON, ICON, 4), np.uint8)
        icon[..., 3] = 255
        icon[..., :3] = bgc.round().astype(np.uint8)
        icon[y0:y1, x0:x1, :3] = np.array(im)
        icon[mask, :3] = med[mask]
        made[name] = save_icon(icon, name)
        print(f"icons/{name}.png re-framed in the Brood frame (opening {w}x{h} at ({x0}, {y0}))")
    return made


def lift(pic, tol=14):
    """Object mask of a picture on a flat backdrop: backdrop-coloured pixels connected to
    the picture's edge are dropped (dark parts inside the object stay)."""
    rgb = pic[..., :3].astype(float)
    bgc = backdrop(pic)[:3]
    near = np.abs(rgb - bgc).max(-1) <= tol
    lab, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    out = ~np.isin(lab, edge[edge > 0])
    out = ndimage.binary_opening(out, iterations=1)
    lab, n = ndimage.label(out, structure=np.ones((3, 3)))
    if n:
        size = ndimage.sum(out, lab, np.arange(1, n + 1))
        out &= (size >= size.max() * 0.01)[lab - 1] & (lab > 0)
    return out


def paste_scaled(dst, src_rgb, mask, scale, cx, cy):
    """src (masked) scaled by `scale` (box filter, alpha-weighted), centred on (cx, cy) in dst."""
    ys, xs = np.nonzero(mask)
    src_rgb = src_rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1, :3].astype(np.float32)
    m = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.float32)
    h, w = m.shape
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))

    def box(a):
        return np.array(Image.fromarray(a, "F").resize((nw, nh), Image.BOX))
    al = box(m * 255.0) / 255.0
    rgb = np.dstack([box(src_rgb[..., c] * m) for c in range(3)]) / np.maximum(al, 1e-6)[..., None]
    ox, oy = int(round(cx - nw / 2)), int(round(cy - nh / 2))
    sub = dst[oy:oy + nh, ox:ox + nw, :3].astype(np.float32)
    k = np.clip((al - 0.15) / 0.6, 0, 1)[..., None]
    dst[oy:oy + nh, ox:ox + nw, :3] = np.clip(rgb * k + sub * (1 - k), 0, 255).round().astype(np.uint8)


def build_courier(brass_crops, pics):
    """COURIER: an Ornithopter carrying a battery, in the brass frame. Frame from the
    OVERLOAD icon (its picture replaced by its own navy backdrop), the ornithopter lifted
    off its portrait, the battery (the brass / yellow cylinder in the middle of OVERLOAD,
    without its lightning) hanging under it."""
    ov = brass_crops["ab_overload"]
    y0, y1, x0, x1 = brass_inner(ov, box=True)
    mid = ov[y0:y1, x0:x1]
    hh, ww = mid.shape[:2]
    navy = backdrop(mid)
    rgb = mid[..., :3].astype(int)
    # the battery: warm, not the pale lightning, in the middle column band
    band = np.zeros((hh, ww), bool)
    band[int(hh * 0.12):int(hh * 0.95), int(ww * 0.38):int(ww * 0.62)] = True
    warm = (rgb[..., 0] >= rgb[..., 2] + 30) | ((rgb.max(-1) < 70) & ~navyish(rgb))
    bat = ndimage.binary_opening(band & warm, iterations=1)
    lab, n = ndimage.label(bat)
    size = ndimage.sum(bat, lab, np.arange(1, n + 1))
    bat = ndimage.binary_fill_holes(lab == (np.argmax(size) + 1))
    out = ov.copy()
    yy = np.arange(hh)[:, None, None]
    out[y0:y1, x0:x1, :3] = np.clip(navy[:3] + (yy - hh / 2) * -0.04, 0, 255).round().astype(np.uint8)
    pic = pics["ornithopter"]
    m = lift(pic)
    oys, oxs = np.nonzero(m)
    span = max(np.ptp(oys), np.ptp(oxs)) + 1
    bys, bxs = np.nonzero(bat)
    paste_scaled(out, mid, bat, hh * 0.36 / (np.ptp(bys) + 1), x0 + ww * 0.5, y0 + hh * 0.79)
    paste_scaled(out, pic, m, ww * 0.64 / span, x0 + ww * 0.5, y0 + hh * 0.34)
    print(f"icons/ab_courier.png: ornithopter portrait + OVERLOAD battery ({np.ptp(bxs) + 1}x{np.ptp(bys) + 1} src px)")
    return save_icon(brass_icon(out), "ab_courier")


# ---------------------------------------------------------------- engine hall

ENGINE_SRC = "art/clockwork/engine_hall.png"
ENGINE_STATES = ["built", "construction", "damaged", "destroyed"]
ENGINE_PLINTH = 132      # px: the built hall's plinth (4 tiles = 128, Assembly Works 136)


def engine_pictures():
    px = load(ENGINE_SRC)
    bg, bgc = bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 6)[lab - 1] & (lab > 0))
    # panels: the widest empty column runs between the four pictures
    cols = fg.any(0)
    runs, x = [], 0
    while x < len(cols):
        if not cols[x]:
            s = x
            while x < len(cols) and not cols[x]:
                x += 1
            if s > 0 and x < len(cols):
                runs.append((x - s, s, x))
        x += 1
    cuts = sorted((s + e) // 2 for _, s, e in sorted(runs, reverse=True)[:3])
    P = [0] + cuts + [px.shape[1]]
    pics = []
    for a, b in zip(P[:-1], P[1:]):
        m = fg.copy()
        m[:, :a] = False
        m[:, b:] = False
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        img = px[y0:y1, x0:x1].copy()
        sel = m[y0:y1, x0:x1]
        img[~sel] = 0
        img[..., 3] = np.where(sel, 255, 0)
        pics.append((img.astype(np.uint8), plinth(sel)))
    print(f"engine hall panels: {P}")
    return pics, bgc


def plinth(sel):
    """(left, right) of the stone plinth: the extent of the solid rows in the lowest fifth
    (smoke and the crane's hook hang higher)."""
    ys = np.flatnonzero(sel.any(1))
    y0, y1 = ys.min(), ys.max() + 1
    band = sel[y1 - (y1 - y0) // 5:y1]
    rows = [np.flatnonzero(r) for r in band if r.sum() > 3]
    lefts = [r.min() for r in rows]
    rights = [r.max() + 1 for r in rows]
    return float(np.percentile(lefts, 10)), float(np.percentile(rights, 90))


def build_engine_hall():
    pics, bgc = engine_pictures()
    l0, r0 = pics[0][1]
    scale = ENGINE_PLINTH / (r0 - l0)
    out = {}
    for state, (img, (pl, pr)) in zip(ENGINE_STATES, pics):
        small, _ = r4.to_game(img, scale, bgc, None)
        ys, xs = np.nonzero(small[..., 3] > 0)
        small = small[:ys.max() + 1]
        c = (pl + pr) / 2 * scale
        half = int(np.ceil(max(c - xs.min(), xs.max() + 1 - c)))
        W = 2 * half
        part = small[ys.min():]
        canvas = np.zeros((part.shape[0], W, 4), np.uint8)
        ox = int(round(half - c))
        canvas[:, max(0, ox):ox + part.shape[1]] = part[:, max(0, -ox):W - ox][:, :W - max(0, ox)]
        canvas = clean(canvas, min_size=3, keep_near=1)
        Image.fromarray(canvas, "RGBA").save(f"assets/buildings/engine_hall_{state}.png")
        out[state] = canvas
        print(f"engine_hall_{state}: {canvas.shape[1]}x{canvas.shape[0]} (scale {scale:.3f}, "
              f"plinth {(pr - pl) * scale:.0f} px)")
    img = pics[0][0]
    icon, _ = r4.to_game(img, 56 / max(img.shape[:2]), bgc, None)
    make_icon(icon, "engine_hall")
    r5.flatten_icon("engine_hall")
    return out


# ---------------------------------------------------------------- bayonet

BAY_SRC = "art/crown/musketeer_bayonet.png"
BAY_HALVES = {"musketeer": (0, 768), "musketeer_armoured": (768, 1536)}


def bayonet_cells(sheet):
    """Row bands and per-row frame column ranges, found from the empty gaps."""
    fg = sheet.fg
    r = fg.any(1)
    e = np.flatnonzero(np.diff(r.astype(int)))
    bands = list(zip(e[::2] + 1, e[1::2] + 1))
    assert len(bands) == 5, bands
    cells = {}
    for kind, (hx0, hx1) in BAY_HALVES.items():
        for d, (y0, y1) in zip(DIRS, bands):
            c = fg[y0:y1, hx0:hx1].any(0)
            ce = np.flatnonzero(np.diff(np.concatenate([[0], c.astype(int), [0]])))
            runs = [(hx0 + a, hx0 + b) for a, b in zip(ce[::2], ce[1::2]) if b - a > 20]
            assert len(runs) == 3, (kind, d, runs)
            cells[kind, d] = [(a, y0, b, y1) for a, b in runs]
    return cells


def build_bayonet():
    sheet = r10.Sheet(BAY_SRC)
    cells = bayonet_cells(sheet)
    entries = {}
    for kind in BAY_HALVES:
        # the standing back view sets the scale (the front rows lunge, so they're lower)
        sc = r10.fit_scale(sheet, [[rc] for rc in cells[kind, "n"]], r10.MUSK_H, 0.25)
        A = {}
        for d in DIRS:
            fr = [r10.game(sheet, [rc], sc) for rc in cells[kind, d]]
            A[d] = steady(fr, "low")
        counts = write_melee(kind, A)
        entries[kind] = counts
        print(f"{kind} bayonet: scale {sc:.4f}, " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    write_counts(entries)
    return entries


def write_melee(kind, A):
    W, H = r10.MUSK_CELL
    ax, ay = r10.MUSK_ANCHOR
    counts = {}
    for d, fr in A.items():
        reach = max(f.ax - np.flatnonzero((f.img[..., 3] > 0).any(0)).min() for f in fr)
        right = max(np.flatnonzero((f.img[..., 3] > 0).any(0)).max() + 1 - f.ax for f in fr)
        up = max(f.ay - np.flatnonzero((f.img[..., 3] > 0).any(1)).min() for f in fr)
        if reach > ax + 0.5 or right > W - ax + 0.5:
            print(f"  WARNING: {kind} melee_{d} reaches L{reach:.1f} R{right:.1f}: clipped")
        extra = max(0, int(np.ceil(up - (ay + 1))))
        strip = np.concatenate([r4.place(f, W, H + extra, ax, ay + 1 + extra)[0] for f in fr], 1)
        Image.fromarray(strip).save(f"assets/units/{kind}/melee_{d}.png")
        counts[f"melee_{d}"] = len(fr)
    return counts


def write_counts(entries):
    """Replace the melee_<dir> counts in the given UNITS entries (nothing else touched)."""
    path = "scripts/art_data.gd"
    src = open(path).read()
    for kind, counts in entries.items():
        start = src.index(f'\t"{kind}": {{"cell"')
        end = src.index("\n\t}},\n", start) + 1
        block = src[start:end]
        for k, n in counts.items():
            pat = re.compile(r'\t\t"' + k + r'": \d+,\n')
            assert pat.search(block), (kind, k)
            block = pat.sub(lambda _m: f'\t\t"{k}": {n},\n', block, count=1)
        src = src[:start] + block + src[end:]
    open(path, "w").write(src)


# ---------------------------------------------------------------- contact sheets

def icon_grid(path, names, k=3, cols=8):
    cw, chh = ICON * k + 12, ICON * k + 26
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols + 8, chh * rows + 8), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = Image.open(f"assets/icons/{n}.png").convert("RGB").resize((ICON * k, ICON * k), Image.NEAREST)
        x, y = 8 + (i % cols) * cw, 8 + (i // cols) * chh
        sheet.paste(im, (x, y))
        d.text((x, y + ICON * k + 4), n, fill=(255, 255, 255))
    sheet.save(path)


def contacts(eh, bay):
    os.makedirs(CONTACT, exist_ok=True)
    portraits = [n for s in ("portraits_crown_a", "portraits_crown_b", "portraits_brood_a",
                             "portraits_brood_b", "portraits_clockwork") for n in PORTRAITS[s]]
    icon_grid(os.path.join(CONTACT, "contact_portraits.png"),
              ["pikeman", "cannon", "labourer"] + portraits)
    clock = [n for n in BRASS["abilities_brood_clockwork"] if n not in BROOD_ABILITIES] + ["ab_courier"]
    icon_grid(os.path.join(CONTACT, "contact_abilities.png"),
              PORTRAITS["research_crown"] + PORTRAITS["abilities_crown"] + ["clockwork/" + c for c in BROOD_CMDS]
              + clock + ["brood/" + c for c in BROOD_CMDS] + BROOD_ABILITIES, cols=6)
    imgs = [np.array(Image.open("assets/buildings/assembly_works_built.png").convert("RGBA"))]
    imgs += [eh[s] for s in ENGINE_STATES]
    Hb = max(x.shape[0] for x in imgs)
    pad = [np.concatenate([np.zeros((Hb - x.shape[0], x.shape[1], 4), np.uint8), x], 0) for x in imgs]
    ic = [np.array(Image.open(f"assets/icons/{k}.png").convert("RGBA")) for k in ("assembly_works", "engine_hall")]
    r4.contact_sheet(os.path.join(CONTACT, "contact_engine_hall.png"),
                     [("assembly works |\nbuilt, constr.,\ndamaged,\ndestroyed", pad), ("icons", ic)])
    lines = []
    W, H = r10.MUSK_CELL
    for kind, counts in bay.items():
        for d in DIRS:
            ref = r10.strip_frames(kind, f"aim_{d}", W, 1, r10.MUSK_ANCHOR, H)
            fr = r10.strip_frames(kind, f"melee_{d}", W, counts[f"melee_{d}"], r10.MUSK_ANCHOR, H)
            Hm = max(f.shape[0] for f in ref + fr)
            fr = [np.concatenate([np.zeros((Hm - f.shape[0], f.shape[1], 4), np.uint8), f], 0) for f in ref + fr]
            lines.append((f"{kind[:10]}\naim | melee_{d}", fr))
    r4.contact_sheet(os.path.join(CONTACT, "contact_bayonet.png"), lines)


def main():
    _, pics = build_steel_icons()
    _, crops = build_brass_icons()
    build_courier(crops, pics)
    build_brood_reframed(crops)
    eh = build_engine_hall()
    bay = build_bayonet()
    if CONTACT:
        contacts(eh, bay)


if __name__ == "__main__":
    main()
