"""Round 10 art: the new Crown musketeers (tricorne base + armoured), the Crown Mortar and
the Clockwork Arc Thrower, with their effects and button icons.

Sources (generated sheets on a flat dark slate background):
  art/crown/musketeer_v2_armoured.png  2172x724. Top half = the ARMOURED musketeer (morion,
        breastplate), bottom half = the BASE musketeer (tricorne, red coat). Four rows per
        half, facings s, se, e, ne (all drawn facing right; ne is a front three-quarter
        like the old musketeer's ne), groups idle / walk / aim / fire / reload / bayonet /
        death - but the generator spread the groups unevenly (extra standing frames, a
        fire frame whose flash came loose, half-hidden figures), so every frame used is
        picked by hand below (MUSK_FRONT: sheet x ranges inside each row band).
  art/crown/musketeer_v2_back.png      2172x724. The north (back) view: row 1 "HELMET SET"
        = armoured, row 2 "HAT SET" = base; groups walk 7 / deploy 5 / idle 3 / fire 5 /
        reload 3 / death 5, then a lightning-ball row (ignored). The generator drew the
        fire frames as lightning (and the hat set's fire frames 3-5 with morions): every
        blue/white lightning pixel is blanked, the deploy group (a turn to the side) is
        not used. North aim = the idle pose with the musket raised by the right shoulder
        (painted, fix_weapons' palette), fire = that plus a painted flash and smoke.
  art/crown/mortar_a.png   1536x1024, rows s..n, groups WALK / DEPLOY / IDLE / FIRE /
        RELOAD / DEATH (header and row labels blanked) + a bottom row MORTAR SHELL (4) and
        EXPLOSION (6). Used for the deployed mortar: idle, fire, reload, death, and the
        effects.
  art/crown/mortar_b.png   2172x724, rows s..n: a second WALK (7: a standing view, then a
        6-frame walk cycle of the horse with the mortar cart and its crew) and DEPLOY (4:
        unhitching, the mortar set on its bed with the horse standing aside). Used for walk
        and deploy (its horse walks properly; mortar_a's doesn't).
  art/clockwork/arc_thrower.png  1536x1024, rows s..n, groups WALK 6 / IDLE 3 / ATTACK 5 /
        DRAINED 2 / DEATH 5 (labels blanked) + bottom row LIGHTNING BALL 3 and IMPACT 4.

Frames are cut with the round 4 machinery (tools/import_round4.py to_game: slate mask with
shadow handling, glow un-blended from the slate, box-filter shrink, team reds snapped to
#FF0000 / #960000, speck and slate-fringe cleanup), one scale per sheet half fitted to the
existing units (SCALE notes), feet on one anchor per kind.

Musketeers: cell 90x36, anchor (45, 34) like the old musketeer (soles on row 34), so the
derived strips keep working: tools/fix_weapons.py repaints the muskets of walk / idle,
tools/make_aim_up.py derives aimup / fireup, tools/import_balloon.py cuts its gunners from
the base musketeer. "melee" (the bayonet) is built from the levelled aim pose: lunge and
recover, a bayonet painted on the muzzle (the sheet's bayonet group is a muddle).

Mortar: anchor = the middle of the mortar bed's bottom edge in every deployed frame (idle,
fire, reload, death, and deploy's last frames), found by matching a bed template; walk is
centred on the team. The horse of mortar_b's last deploy frame stands beside the mortar:
the deploy goes on with that horse dithered out (as the cannon's horse leaves) and ends on
the idle frame, so the deployed mortar never keeps a horse in its cell. "idle_packed" = the
first walk frame. Played reversed, deploy packs up.

Output:
  assets/units/musketeer/{idle,walk,aim,fire,reload,melee,death}_<dir>.png   (base)
  assets/units/musketeer_armoured/... the same anims (aimup/fireup come from make_aim_up)
  assets/units/mortar/{walk,deploy,idle,fire,reload,death,idle_packed}_<dir>.png
  assets/units/arc_thrower/{walk,idle,attack,drained,death}_<dir>.png
  assets/effects/{mortar_shell,mortar_blast,arc_ball,arc_impact}.png
  assets/icons/{musketeer_armoured,mortar,arc_thrower}.png (64x64; the musketeer's own icon
  is hand-painted from art/ui/icons.png by import_art.py and is left alone)
  the "musketeer", "musketeer_armoured", "mortar" and "arc_thrower" entries of UNITS and
  the four effects in EFFECTS of scripts/art_data.gd (added or replaced in place; nothing
  else in the file is touched).

Order (tools/rebuild_art.sh): after import_art.py (which writes the old musketeer) and the
other rounds, BEFORE fix_weapons.py, make_aim_up.py and import_balloon.py.

Usage (from the repo root): python3 tools/import_round10.py [--contact DIR] [--debug DIR]
(--contact writes x3 contact sheets on grass green and a scale line-up). Needs Pillow,
NumPy and SciPy. Re-runnable.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # round 4 reads its own flags
import import_round4 as r4  # noqa: E402
sys.argv = _argv
from import_art import load  # noqa: E402
from import_cannon2 import bg_mask, clean, is_effect, shrink  # noqa: E402
from import_round4 import F, body_of, place, steady  # noqa: E402
import fix_weapons as fw  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
CONTACT = _argv[_argv.index("--contact") + 1] if "--contact" in _argv else None
DEBUG = _argv[_argv.index("--debug") + 1] if "--debug" in _argv else None


# ---------------------------------------------------------------- cutting

class Sheet:
    """A source sheet: pixels, foreground mask (slate, labels and blanked pixels off)."""

    def __init__(self, path, blank=(), erase_fn=None):
        self.path = path
        self.px = load(path)
        bg, self.bgc = bg_mask(self.px)
        fg = ~bg
        for x0, y0, x1, y1 in blank:
            fg[y0:y1, x0:x1] = False
        if erase_fn is not None:
            fg &= ~erase_fn(self.px)
        lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
        if n:
            size = ndimage.sum(fg, lab, np.arange(1, n + 1))
            fg &= ~((size < 4)[lab - 1] & (lab > 0))
        self.fg = fg

    def cut(self, rects, erase=()):
        """RGBA crop of everything in the rectangles (x0, y0, x1, y1; x1/y1 exclusive),
        minus the erase rectangles; returns (img, sheet x0, sheet y0)."""
        m = np.zeros(self.fg.shape, bool)
        for x0, y0, x1, y1 in rects:
            m[y0:y1, x0:x1] = self.fg[y0:y1, x0:x1]
        for x0, y0, x1, y1 in erase:
            m[y0:y1, x0:x1] = False
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        img = self.px[y0:y1, x0:x1].copy()
        sel = m[y0:y1, x0:x1]
        img[~sel] = 0
        img[..., 3] = np.where(sel, 255, 0)
        return img.astype(np.uint8), x0, y0


def game(sheet, rects, scale, glow=None, glow_cut=0.2, erase=()):
    img, x0, y0 = sheet.cut(rects, erase)
    out, gl = r4.to_game(img, scale, sheet.bgc, glow, glow_cut)
    f = F(out, gl)
    f.src = (x0, y0, scale)          # sheet origin of the crop, for sheet -> game points
    return f


def to_frame(sheet, scale, pt, f):
    """A sheet point -> pixel coordinates in frame f (cut from that sheet)."""
    x0, y0, s = f.src
    return (pt[0] - x0) * s, (pt[1] - y0) * s


def body_height(f):
    b = fw.body_mask(f.img)
    ys = np.flatnonzero(b.any(1))
    return ys.max() - ys.min() + 1


def fit_scale(sheet, rect_lists, target, guess):
    """Scale that makes the median body height (fix_weapons' body mask: no musket) of
    the given frames `target` game px."""
    hs = [body_height(game(sheet, rects, guess)) for rects in rect_lists]
    return guess * target / float(np.median(hs))


def shift_upper(f, frac, dx, dy):
    """The figure above frac of its height moved by (dx, dy) - a lunge. Moved up, the
    gap at the waist is filled with the row under it."""
    pad = 4
    img = np.zeros((f.img.shape[0] + 2 * pad, f.img.shape[1] + 2 * pad, 4), np.uint8)
    img[pad:-pad, pad:-pad] = f.img
    ys = np.flatnonzero((img[..., 3] > 0).any(1))
    hip = ys.min() + int((ys.max() - ys.min()) * frac)
    upper = img.copy()
    upper[hip:] = 0
    out = img.copy()
    out[:hip] = 0
    for k in range(1, -dy + 1):
        out[hip - k] = out[hip]
    moved = np.roll(np.roll(upper, dy, 0), dx, 1)
    m = moved[..., 3] > 0
    out[m] = moved[m]
    g = F(out, np.zeros(out.shape[:2], bool), f.ax + pad, f.ay + pad)
    return trim(g)


def trim(f):
    ys, xs = np.nonzero(f.img[..., 3] > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return F(f.img[y0:y1, x0:x1].copy(), f.glow[y0:y1, x0:x1].copy(), f.ax - x0, f.ay - y0)


def pad_frame(f, p):
    img = np.zeros((f.img.shape[0] + 2 * p, f.img.shape[1] + 2 * p, 4), np.uint8)
    img[p:-p, p:-p] = f.img
    gl = np.zeros(img.shape[:2], bool)
    gl[p:-p, p:-p] = f.glow
    return F(img, gl, f.ax + p, f.ay + p)


# ---------------------------------------------------------------- musketeers

MUSK_CELL = (90, 36)
MUSK_ANCHOR = (45, 34)       # art_data anchor: the soles sit on row 34 (as before)
MUSK_H = 32                  # body height in game px (helmet/hat to soles): the old musketeer
MUSK_SRC = "art/crown/musketeer_v2_armoured.png"
BACK_SRC = "art/crown/musketeer_v2_back.png"

# sheet bands (y0, y1) per facing, and the frames (sheet x ranges, inclusive) per anim
MUSK_BANDS = {"musketeer_armoured": [(18, 98), (98, 188), (188, 282), (282, 368)],
              "musketeer": [(388, 474), (474, 562), (562, 649), (649, 724)]}
MUSK_FRONT = {
    "musketeer_armoured": {
        "s": dict(idle=[(36, 65), (87, 117)], walk=[(162, 191), (207, 236), (255, 283)],
                  aim=[(327, 373), (400, 443)], fire=[(580, 688)],
                  reload=[(742, 769), (789, 815), (832, 863), (881, 907), (926, 950)],
                  death=[(1400, 1422), (1456, 1483), (1515, 1545), (1568, 1617)]),
        "se": dict(idle=[(36, 66), (81, 109)], walk=[(161, 202), (215, 256), (271, 309), (322, 370)],
                   aim=[(423, 481), (498, 560)], fire=[(689, 788)],
                   reload=[(837, 866), (889, 922), (938, 971), (992, 1023), (1045, 1073)],
                   death=[(1580, 1606), (1643, 1681), (1694, 1734), (1752, 1807)]),
        "e": dict(idle=[(36, 69), (85, 124)],
                  walk=[(157, 194), (219, 248), (270, 304), (323, 360), (372, 402), (420, 462)],
                  aim=[(532, 574), (613, 674)], fire=[(690, 807)],
                  reload=[(854, 891), (929, 967), (987, 1024), (1184, 1215), (1296, 1325),
                          (1353, 1381), (1406, 1434), (1462, 1488)],
                  death=[(1814, 1840), (1896, 1928), (2058, 2134)]),
        "ne": dict(idle=[(37, 77), (89, 134)], walk=[(162, 189), (209, 234), (255, 289), (314, 351), (365, 407)],
                   aim=[(533, 592), (439, 500)], fire=[(707, 810)],
                   reload=[(855, 889), (899, 925), (944, 971), (994, 1023), (1043, 1071), (1084, 1112)],
                   death=[(1614, 1638), (1667, 1707), (1723, 1780)]),
    },
    "musketeer": {
        "s": dict(idle=[(37, 69), (87, 115)], walk=[(162, 189), (209, 241), (256, 283)],
                  aim=[(327, 368), (400, 442)], fire=[(585, 691)],
                  reload=[(742, 768), (784, 811), (827, 858), (875, 900), (922, 946)],
                  death=[(1389, 1414), (1449, 1479), (1516, 1553), (1571, 1626)]),
        "se": dict(idle=[(37, 61), (83, 111)], walk=[(169, 204), (221, 247), (271, 296), (319, 364)],
                   aim=[(421, 476), (495, 559)], fire=[(689, 789)],
                   reload=[(836, 866), (884, 916), (931, 962), (987, 1015), (1038, 1063)],
                   death=[(1579, 1604), (1644, 1681), (1698, 1734), (1750, 1804)]),
        "e": dict(idle=[(36, 67), (83, 116)],
                  walk=[(157, 187), (218, 244), (271, 297), (323, 356), (373, 399), (423, 454)],
                  aim=[(533, 575), (616, 672)], fire=[(690, 794)],
                  reload=[(851, 888), (932, 968), (989, 1027), (1185, 1217), (1296, 1324),
                          (1353, 1378), (1406, 1432), (1461, 1491)],
                  death=[(1815, 1842), (1897, 1928), (2059, 2134)]),
        "ne": dict(idle=[(37, 62), (90, 133)], walk=[(166, 192), (213, 239), (265, 294), (319, 343), (367, 404)],
                   aim=[(535, 584), (443, 502)], fire=[(704, 799)],
                   reload=[(851, 881), (896, 923), (943, 968), (994, 1019), (1042, 1068), (1084, 1112)],
                   death=[(1626, 1653), (1681, 1713), (1727, 1780)]),
    },
}
BACK_BANDS = {"musketeer_armoured": (100, 262), "musketeer": (300, 452)}
MUSK_BACK = {
    "musketeer_armoured": dict(
        walk=[(110, 153), (171, 215), (234, 280), (296, 341), (356, 398), (416, 458), (474, 517)],
        idle=[(951, 994), (1019, 1062), (1084, 1125)],
        reload=[(1515, 1551), (1577, 1615), (1641, 1675)],
        death=[(1732, 1778), (1811, 1866), (1887, 1949), (1966, 2038), (2052, 2135)]),
    "musketeer": dict(
        walk=[(112, 156), (177, 219), (239, 282), (302, 345), (361, 404), (425, 465), (483, 525)],
        idle=[(953, 994), (1021, 1062), (1085, 1124)],
        reload=[(1514, 1549), (1575, 1615), (1638, 1675)],
        death=[(1738, 1775), (1812, 1866), (1887, 1943), (1966, 2038), (2050, 2135)]),
}
BACK_LABELS = [(0, 0, 2172, 92), (0, 0, 100, 500), (0, 470, 2172, 724)]


def lightning(px):
    """Blue / white lightning and its halo (the back sheet's hallucinated fire)."""
    rgb = px[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    blue = (b - r >= 55) & (b >= 100) & (b - g >= 10)
    dark = (b - r >= 32) & (b >= 50) & (b - g >= 14) & (r <= 45)   # navy halo, outline
    white = (rgb.min(-1) >= 185) & (b >= r + 8)
    m = blue | dark | white
    return ndimage.binary_dilation(m, iterations=1) & ((b - r >= 18) | m)


FLASH_RED = ((255, 92, 24), (196, 52, 10))


def away(f, reach=11):
    """Pixels out past the figure (facing right): where the flash and smoke are."""
    m = np.zeros(f.img.shape[:2], bool)
    m[:, int(round(f.ax)) + reach:] = True
    return m


def unteam_flash(f):
    """The muzzle flash's red tips were snapped to the team keys like the coat: anything
    keyed red out past the figure goes back to flame orange."""
    g = f.copy()
    rgb = g.img[..., :3]
    for key, col in zip(((255, 0, 0), (150, 0, 0)), FLASH_RED):
        m = (rgb == key).all(-1) & away(g) & (g.img[..., 3] > 0)
        g.img[m, :3] = col
    return g


EFFECT_K = 0.7


def smaller_shot(f):
    """The flash and smoke drawn smaller, toward the muzzle, so the shot fits the old
    90 px cell (the sheet's smoke ball is a third wider than the old musketeer's)."""
    g = f.copy()
    rgb = g.img[..., :3].astype(int)
    r, b = rgb[..., 0], rgb[..., 2]
    flash, spark, smoke = is_effect(rgb)
    hot = (flash | spark | ((r >= 150) & (r - b >= 60))) & (g.img[..., 3] > 0) & away(g, 14)
    if not hot.any():
        return g
    # everything from the flash on (the musket ends where the flash starts)
    hy, hx = np.nonzero(hot)
    ex0 = hx.min()
    cy = hy.mean()
    eff = g.img[..., 3] > 0
    eff[:, :ex0] = False
    layer = np.where(eff[..., None], g.img, 0).astype(np.uint8)
    g.img[eff] = 0
    ys = np.flatnonzero(eff.any(1))
    y0, y1 = ys.min(), ys.max() + 1
    small = shrink(layer[y0:y1, ex0:], EFFECT_K)
    oy = int(round(cy - (cy - y0) * EFFECT_K))
    h, w = small.shape[:2]
    h, w = min(h, g.img.shape[0] - oy), min(w, g.img.shape[1] - ex0)
    m = (small[:h, :w, 3] > 0) & (g.img[oy:oy + h, ex0:ex0 + w, 3] == 0)
    g.img[oy:oy + h, ex0:ex0 + w][m] = small[:h, :w][m]
    return trim(g)


def no_flash(f):
    """The fire frame a moment later: flash gone, the smoke left (holes the flash leaves
    inside the smoke are filled with smoke)."""
    g = f.copy()
    rgb = g.img[..., :3].astype(int)
    r, b = rgb[..., 0], rgb[..., 2]
    hot = (((r >= 150) & (r - b >= 60)) | ((r >= 200) & (r - b >= 20))) & (g.img[..., 3] > 0) & away(g)
    _, _, smoke = is_effect(rgb)
    smoke &= (g.img[..., 3] > 0) & away(g)
    near = ndimage.convolve(smoke.astype(int), np.ones((3, 3), int), mode="constant")
    g.img[hot] = 0
    fill = hot & (near >= 4)
    g.img[fill] = (196, 196, 198, 255)
    return trim(F(clean(g.img), g.glow, g.ax, g.ay))


BAYONET = 5


def add_bayonet(f, side):
    """A bayonet past the muzzle of the levelled musket (fix_weapons' steel)."""
    g = f.copy()
    hl = fw.held_line(g.img)
    if hl is None:
        return g
    muzzle, d = hl
    p = muzzle + d * 1.0
    for i in range(BAYONET * 2):
        q = p + d * (i / 2.0)
        x, y = int(round(q[0])), int(round(q[1]))
        if 0 <= x < g.img.shape[1] and 0 <= y < g.img.shape[0]:
            g.img[y, x] = (*(fw.STEEL[2] if i < 3 else fw.STEEL[1]), 255)
    return g


def melee_from_aim(aim, d):
    """Bayonet thrust: levelled musket, lunge forward (up for the back view), recover."""
    base = add_bayonet(pad_frame(aim, 8), d)
    if d == "n":
        lunge = shift_upper(base, 0.62, 0, -1)
    else:
        lunge = shift_upper(base, 0.62, 3, 0)
    return [trim(base), trim(lunge), trim(base)]


def musket_raised(f):
    """North aim: the idle back view with the musket raised at the right shoulder, the
    muzzle well above the head (seen from behind, aimed away)."""
    g = pad_frame(f, 14)
    b, x0, x1, y0, y1, hb = fw.figure(g.img)
    h = y1 - y0
    hand = fw.hand_near(g.img, b, np.array([x1 - 2, y0 + h * 0.42]), y0 + h * 0.25, y0 + h * 0.6)
    if hand is None:
        hand = np.array([x1 - 2.0, y0 + h * 0.42])
    butt = np.array([hand[0] - 1.0, hand[1] + 5.0])
    top = np.array([x1 + 2.0, y0 - 5.0])
    dvec = (top - butt) / np.linalg.norm(top - butt)
    keep = fw.keeper(g.img, b, hb, hand)
    stroke_len = np.linalg.norm(top - butt)
    fw.stroke(g.img, top, -dvec, stroke_len, fw.musket_colour_up, keep)
    g.muzzle = top
    return g


SMOKE = [(118, 118, 122), (160, 160, 164), (204, 204, 204)]


def puff(img, cx, cy, rad):
    """A round powder-smoke puff, lit from the upper left, ragged edge."""
    for y in range(int(cy - rad - 1), int(cy + rad + 2)):
        for x in range(int(cx - rad - 1), int(cx + rad + 2)):
            dd = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dd > rad or not (0 <= y < img.shape[0] and 0 <= x < img.shape[1]):
                continue
            if dd > rad - 0.7 and (x * 3 + y) % 4 == 0:
                continue
            lit = (x - cx) + (y - cy)
            k = 2 if lit < -rad * 0.5 else (1 if lit < rad * 0.6 else 0)
            img[y, x] = (*SMOKE[k], 255)


def flash_smoke(f, muzzle, phase):
    """Painted muzzle flash and a first puff (phase 0), then the smoke rising and
    spreading (phase 1) - the back view's shot, fired away from the camera."""
    g = f.copy()
    img = g.img
    mx, my = muzzle[0], muzzle[1]
    if phase == 0:
        puff(img, mx + 0.5, my - 3.0, 2.2)
        for (dx, dy), c in [((0, 0), (255, 250, 210)), ((0, -1), (255, 226, 110)), ((-1, 0), (255, 180, 50)),
                            ((1, 0), (255, 180, 50)), ((0, -2), (255, 140, 30)), ((0, 1), (240, 120, 30))]:
            x, y = int(round(mx)) + dx, int(round(my)) + dy
            if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
                img[y, x] = (*c, 255)
    else:
        puff(img, mx + 1.5, my - 4.5, 2.8)
        puff(img, mx - 1.0, my - 2.0, 1.8)
    return g


def build_musketeers():
    front = Sheet(MUSK_SRC)
    back = Sheet(BACK_SRC, blank=BACK_LABELS, erase_fn=lightning)
    out = {}
    for kind in ("musketeer", "musketeer_armoured"):
        bands = MUSK_BANDS[kind]
        spec = MUSK_FRONT[kind]

        def rects(d, xr, bands=bands):
            y0, y1 = bands[DIRS.index(d)]
            return [(xr[0], y0, xr[1] + 1, y1)]
        sc = fit_scale(front, [rects(d, x) for d in ("s", "se") for x in spec[d]["idle"]], MUSK_H, 0.53)
        by0, by1 = BACK_BANDS[kind]
        bspec = MUSK_BACK[kind]
        bsc = fit_scale(back, [[(x0, by0, x1 + 1, by1)] for x0, x1 in bspec["idle"]], MUSK_H, 0.37)
        print(f"{kind}: front scale {sc:.4f}, back scale {bsc:.4f}")
        A = {}
        for d in ("s", "se", "e", "ne"):
            fr = {an: [game(front, rects(d, x), sc) for x in xs] for an, xs in spec[d].items()}
            A["idle", d] = steady(fr["idle"], "low")
            A["walk", d] = steady(fr["walk"], "high")
            A["aim", d] = steady(fr["aim"], "low")
            fire = smaller_shot(unteam_flash(fr["fire"][0]))
            A["fire", d] = [fire, no_flash(fire)]
            A["reload", d] = steady(fr["reload"], "low")
            A["death", d] = steady(fr["death"], "low", chain=True)
            A["melee", d] = melee_from_aim(A["aim", d][-1], d)
        fr = {an: [game(back, [(x0, by0, x1 + 1, by1)], bsc) for x0, x1 in xs] for an, xs in bspec.items()}
        death = fr["death"]
        # the last body lies under a wisp of smoke: the smoke goes
        last = death[-1].copy()
        red = ((last.img[..., :3] == (255, 0, 0)).all(-1) | (last.img[..., :3] == (150, 0, 0)).all(-1))
        top = np.flatnonzero(red.any(1)).min() - 3
        last.img[:top] = 0
        _, _, smoke = is_effect(last.img[..., :3].astype(int))
        last.img[smoke] = 0
        rgb = last.img[..., :3].astype(int)
        wisp = (rgb.max(-1) - rgb.min(-1) <= 24) & (rgb[..., 2] >= rgb[..., 0]) & (rgb.mean(-1) >= 40)
        wisp[top + 6:] = False
        last.img[wisp] = 0
        last = trim(F(clean(last.img), last.glow, last.ax, last.ay))
        death[-1] = last
        A["idle", "n"] = steady(fr["idle"], "low")
        A["walk", "n"] = steady(fr["walk"], "high")
        A["reload", "n"] = steady(fr["reload"], "low")
        A["death", "n"] = steady(death, "low", chain=True)
        aim = musket_raised(A["idle", "n"][0])
        A["aim", "n"] = [trim(aim)]
        f0 = flash_smoke(aim, aim.muzzle, 0)
        f1 = flash_smoke(aim, aim.muzzle, 1)
        A["fire", "n"] = [trim(f0), trim(f1)]
        A["melee", "n"] = melee_from_aim(trim(aim), "n")
        out[kind] = write_musk(kind, A)
    return out


def write_musk(kind, A):
    W, H = MUSK_CELL
    ax, ay = MUSK_ANCHOR
    folder = f"assets/units/{kind}"
    os.makedirs(folder, exist_ok=True)
    keys = {f"{a}_{d}" for a, d in A}
    for f in os.listdir(folder):
        if f.endswith(".png") and f[:-4] not in keys:
            os.remove(os.path.join(folder, f))
            if os.path.exists(os.path.join(folder, f + ".import")):
                os.remove(os.path.join(folder, f + ".import"))
    counts = {}
    for (anim, d), fr in sorted(A.items()):
        # frames reaching above the cell (the north musket raised, its smoke) get extra
        # rows on top of their strip: unit.gd keeps the feet where they were
        up = max(f.ay - np.flatnonzero((f.img[..., 3] > 0).any(1)).min() for f in fr)
        extra = max(0, int(np.ceil(up - (ay + 1))))
        strip = np.concatenate([place(f, W, H + extra, ax, ay + 1 + extra)[0] for f in fr], 1)
        Image.fromarray(strip).save(f"{folder}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(fr)
    print(f"{kind}: " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    return (MUSK_CELL, MUSK_ANCHOR, counts)


# ---------------------------------------------------------------- mortar

MORTAR_A = "art/crown/mortar_a.png"
MORTAR_B = "art/crown/mortar_b.png"
CREW_H = 36          # a crewman's height in game px: between the musketeer (32) and the
                     # cannon's crew (38). mortar_b draws a pony next to its crew: its horse
                     # comes out ~30 px high, the cannon's is ~40 - matching that would make
                     # the crew 1.5x a musketeer, so the crew decides

A_LABELS = [(0, 0, 1536, 76), (0, 0, 64, 860)]
A_BANDS = [(62, 215), (225, 380), (385, 530), (540, 690), (700, 860)]
B_BANDS = [(30, 150), (160, 290), (300, 420), (430, 560), (570, 690)]
# mortar_a groups (x range per group, frames per group) - split at the emptiest columns
A_GROUPS = {"idle": ((668, 812), 2), "fire": ((826, 1034), 2), "reload": ((1050, 1190), 2),
            "death": ((1205, 1520), 4)}
# the cut between the two fire frames: before the smoking mortar (per row, read off the sheet)
A_FIRE_CUT = [940, 943, 950, 948, 948]
B_WALK = [[(262, 386), (439, 563), (586, 683), (727, 863), (885, 1002), (1025, 1125)],
          [(253, 393), (422, 562), (576, 685), (722, 854), (885, 1001), (1024, 1125)],
          [(222, 390), (412, 547), (559, 707), (728, 869), (887, 1011), (1027, 1125)],
          [(254, 380), (422, 546), (585, 688), (738, 861), (890, 997), (1028, 1125)],
          [(268, 368), (438, 533), (589, 671), (745, 840), (893, 977), (1026, 1107)]]
B_DEPLOY = [[(1166, 1347), (1402, 1586), (1640, 1798), (1881, 2143)],
            [(1167, 1332), (1396, 1586), (1637, 1796), (1875, 2140)],
            [(1161, 1334), (1393, 1615), (1651, 1796), (1861, 2142)],
            [(1183, 1325), (1406, 1584), (1654, 1795), (1862, 2122)],
            [(1168, 1332), (1412, 1591), (1682, 1787), (1877, 2125)]]
# bottom middle of the mortar bed in mortar_b's last deploy frame (sheet px, read off it)
B_BED = [(2001, 133), (1990, 263), (1985, 398), (1985, 527), (1990, 665)]
# mortar_a bed template: the smoking mortar of the south fire group (bed rows only), its
# bottom middle at BED_PT
A_TEMPLATE = (945, 186, 992, 203)
BED_PT = (968.0, 202.0)
BED_FIX = {}     # (row, anim, i) -> sheet point, where the template match is wrong


def col_cuts(fg, y0, y1, a, b, n):
    return r4.column_cuts(fg[y0:y1], a, b, n)


def match_bed(sheet, tpl, tmask, rect):
    """Best position of the bed template inside rect (sheet px): colour distance over the
    template's own pixels, a pixel of slate under one counting as far off."""
    x0, y0, x1, y1 = rect
    px = sheet.px[y0:y1, x0:x1, :3].astype(float)
    fg = sheet.fg[y0:y1, x0:x1]
    th, tw = tmask.shape
    best, bp = 1e18, None
    for y in range(0, px.shape[0] - th + 1):
        for x in range(0, px.shape[1] - tw + 1):
            win = px[y:y + th, x:x + tw]
            d = np.abs(win - tpl).sum(-1)
            d = np.where(fg[y:y + th, x:x + tw], d, 300.0)
            sc = d[tmask].mean()
            if sc < best:
                best, bp = sc, (x0 + x, y0 + y)
    return bp, best


TPL_W = A_TEMPLATE[2] - A_TEMPLATE[0]


def drop_crumbs(f, small=15, reach=4):
    """Loose specks (a wisp of smoke, a chip) away from the wreck go."""
    g = f.copy()
    a = g.img[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n > 1:
        size = ndimage.sum(a, lab, np.arange(1, n + 1))
        big = np.isin(lab, np.flatnonzero(size >= small) + 1)
        near = ndimage.binary_dilation(big, iterations=reach)
        for k in range(1, n + 1):
            comp = lab == k
            if size[k - 1] < small and not (comp & near).any():
                g.img[comp] = 0
    return g


def fire_crew(A, sa, cuts, band, frames, pts):
    """The sheet splits the shot over two drawings: the crew on the left with the mortar
    firing, then the smoking mortar with a crewman on its right. Each frame gets the
    other's crew too (placed by the mortar bed), so the crew stays put while it fires."""
    (_, _, _, p1), (_, _, _, p2) = pts
    y0, y1 = band
    bx0 = int(p1[0] - (BED_PT[0] - A_TEMPLATE[0]))
    bx1 = int(p2[0] - (BED_PT[0] - A_TEMPLATE[0])) + TPL_W
    # crew height only: the smoke drifting over them belongs to the other drawing
    left = game(A, [(cuts[0], int(p1[1]) - 68, bx0 - 1, y1)], sa)
    left.ax, left.ay = to_frame(A, sa, p1, left)
    right = game(A, [(bx1 + 1, int(p2[1]) - 68, cuts[2], y1)], sa)
    right.ax, right.ay = to_frame(A, sa, p2, right)
    return [r4.overlay(frames[0], right), r4.overlay(frames[1], left)]


def unteam_column(f, half=8, above=15):
    """The flame column out of the mortar's mouth had its red tips snapped to the team
    keys: keyed pixels right above the mortar go back to flame orange."""
    g = f.copy()
    rgb = g.img[..., :3]
    zone = np.zeros(rgb.shape[:2], bool)
    x0 = max(0, int(round(g.ax - half)))
    zone[:max(0, int(round(g.ay - above))), x0:int(round(g.ax + half))] = True
    for key, col in zip(((255, 0, 0), (150, 0, 0)), FLASH_RED):
        m = (rgb == key).all(-1) & zone
        g.img[m, :3] = col
    return g


def dither_out(f, mask, keep_phase):
    """Every other pixel of mask (a checkerboard) removed - the horse fading away."""
    g = f.copy()
    yy, xx = np.mgrid[0:g.img.shape[0], 0:g.img.shape[1]]
    g.img[mask & (((xx + yy) % 2) == keep_phase)] = 0
    return g


def build_mortar():
    A = Sheet(MORTAR_A, blank=A_LABELS + [(0, 860, 1536, 1024)])
    B = Sheet(MORTAR_B)
    sa = CREW_H / 60.5
    sb = CREW_H / 73.0
    ty0 = A_TEMPLATE[1]
    tpl = A.px[A_TEMPLATE[1]:A_TEMPLATE[3], A_TEMPLATE[0]:A_TEMPLATE[2], :3].astype(float)
    tmask = A.fg[A_TEMPLATE[1]:A_TEMPLATE[3], A_TEMPLATE[0]:A_TEMPLATE[2]]
    toff = (BED_PT[0] - A_TEMPLATE[0], BED_PT[1] - ty0)
    out = {}
    debug = []
    for r, d in enumerate(DIRS):
        ay0, ay1 = A_BANDS[r]
        by0, by1 = B_BANDS[r]
        # ---- deployed (mortar_a): every frame hung from its mortar bed
        for anim, ((ga, gb), n) in A_GROUPS.items():
            if anim == "fire":
                cuts = [ga, A_FIRE_CUT[r], gb]
            else:
                cuts = col_cuts(A.fg, ay0, ay1, ga, gb, n)
            frames = []
            for i in range(n):
                rect = (cuts[i], ay0, cuts[i + 1], ay1)
                if (r, anim, i) in BED_FIX:
                    pt = BED_FIX[(r, anim, i)]
                else:
                    pos, sc = match_bed(A, tpl, tmask, rect)
                    pt = (pos[0] + toff[0], pos[1] + toff[1])
                erase = []
                if anim == "fire" and i == 1:
                    # the first drawing's smoke column drifts over this one's left edge
                    erase = [(cuts[1], ay0, int(pt[0]) - 4, int(pt[1]) - 66)]
                f = game(A, [rect], sa, erase=erase)
                debug.append((r, anim, i, pt))
                f.ax, f.ay = to_frame(A, sa, pt, f)
                if anim == "fire":
                    f = unteam_column(f)
                frames.append(f)
            if anim in ("death", "fire"):
                frames = [drop_crumbs(f, 25 if anim == "fire" else 15) for f in frames]
            if anim == "fire":
                frames = fire_crew(A, sa, cuts, (ay0, ay1), frames, debug[-2:])
            out[anim, d] = frames
        # ---- walk (mortar_b): centred on the team, feet on the ground
        walk = []
        for x0, x1 in B_WALK[r]:
            f = game(B, [(x0, by0, x1 + 1, by1)], sb)
            ys, xs = np.nonzero(body_of(f.img, f.glow))
            f.ax = (xs.min() + xs.max() + 1) / 2.0
            f.ay = float(np.flatnonzero(np.bincount(ys) >= 2).max() + 1)
            walk.append(f)
        walk = steady(walk, "all")
        out["walk", d] = walk
        out["idle_packed", d] = [walk[0].copy()]
        # ---- deploy (mortar_b): unhitch, the mortar set down, the horse led aside and
        # dithered out, then the deployed mortar (idle's first frame)
        dep = []
        for x0, x1 in B_DEPLOY[r]:
            dep.append(game(B, [(x0, by0, x1 + 1, by1)], sb))
        last = dep[-1]
        bx, byy = to_frame(B, sb, B_BED[r], last)
        boxes = []
        for f in dep:
            ys, xs = np.nonzero(body_of(f.img, f.glow))
            boxes.append(((xs.min() + xs.max() + 1) / 2.0, float(np.flatnonzero(np.bincount(ys) >= 2).max() + 1)))
        offx, offy = bx - boxes[-1][0], byy - boxes[-1][1]
        for k, f in enumerate(dep):
            t = k / float(len(dep) - 1)
            f.ax, f.ay = boxes[k][0] + t * offx, boxes[k][1] + t * offy
        # the horse: everything right of the emptiest column between bed and horse
        x0 = B_DEPLOY[r][-1][0]
        cols = B.fg[by0:by1, B_BED[r][0] + 25:B_BED[r][0] + 75].sum(0)
        hx = B_BED[r][0] + 25 + int(np.argmin(cols))
        hgx = int(round((hx - last.src[0]) * sb))
        horse = np.zeros(last.img.shape[:2], bool)
        horse[:, hgx:] = last.img[:, hgx:, 3] > 0
        gone = last.copy()
        gone.img[horse] = 0
        fading = dither_out(last, horse, 0)
        out["deploy", d] = dep + [fading, out["idle", d][0].copy()]
        out["_dep_nohorse", d] = [gone]
    if DEBUG:
        im = Image.open(MORTAR_A).convert("RGB")
        dr = ImageDraw.Draw(im)
        for r, anim, i, (x, y) in debug:
            dr.line([(x - 6, y), (x + 6, y)], fill=(255, 255, 0))
            dr.line([(x, y - 6), (x, y)], fill=(255, 255, 0))
        im.save(os.path.join(DEBUG, "mortar_a_beds.png"))
    for key in [k for k in out if k[0] == "_dep_nohorse"]:
        del out[key]
    return {"mortar": write_kind("mortar", out)}


def write_kind(kind, A):
    """One symmetric cell around the anchor for every frame (round 4's assemble), the
    strips written, old strips of the kind removed."""
    strips, cell, anchor = r4.assemble(A)
    folder = f"assets/units/{kind}"
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.endswith(".png") and f[:-4] not in strips:
            os.remove(os.path.join(folder, f))
            if os.path.exists(os.path.join(folder, f + ".import")):
                os.remove(os.path.join(folder, f + ".import"))
    counts = {}
    for key, strip in sorted(strips.items()):
        Image.fromarray(strip).save(f"{folder}/{key}.png")
        counts[key] = strip.shape[1] // cell[0]
    print(f"{kind}: cell {cell[0]}x{cell[1]}, anchor {anchor}")
    print("  " + ", ".join(f"{k} {n}" for k, n in sorted(counts.items())))
    return (cell, anchor, counts)


# ---------------------------------------------------------------- arc thrower

ARC_SRC = "art/clockwork/arc_thrower.png"
ARC_H = 46           # body height (game px): a Gearknight's size (50 with its pack)
ARC_LABELS = [(0, 0, 1536, 86), (0, 0, 68, 850), (0, 850, 1536, 1024)]
ARC_BANDS = [(100, 215), (255, 370), (405, 520), (560, 676), (716, 830)]
ARC = [
    dict(walk=[(74, 116), (125, 167), (172, 218), (228, 268), (278, 323), (334, 378)],
         idle=[(411, 462), (474, 527), (533, 584)],
         attack=[(619, 662), (679, 729), (739, 785), (796, 844), (855, 910)],
         drained=[(991, 1030), (1046, 1086)],
         death=[(1132, 1190), (1208, 1263), "split", (1436, 1509)]),
    dict(walk=[(74, 117), (129, 172), (183, 223), (236, 275), (287, 331), (342, 381)],
         idle=[(422, 461), (475, 524), (534, 581)],
         attack=[(623, 662), (680, 730), (738, 788), (797, 845), (858, 910)],
         drained=[(993, 1031), (1048, 1086)],
         death=[(1135, 1192), (1209, 1260), (1268, 1338), (1346, 1429), (1433, 1510)]),
    dict(walk=[(82, 121), (135, 170), (185, 221), (235, 269), (284, 323), (335, 375)],
         idle=[(425, 466), (475, 523), (530, 582)],
         attack=[(626, 665), (680, 730), (739, 787), (798, 846), (859, 911)],
         drained=[(994, 1031), (1050, 1086)],
         death=[(1135, 1203), (1215, 1264), (1281, 1346), (1351, 1431), (1436, 1510)]),
    dict(walk=[(76, 114), (124, 162), (178, 217), (235, 273), (285, 327), (339, 381)],
         idle=[(425, 461), (474, 521), (534, 580)],
         attack=[(621, 664), (679, 731), (739, 787), (797, 845), (858, 912)],
         drained=[(992, 1030), (1047, 1086)],
         death=[(1136, 1194), (1216, 1266), (1277, 1347), (1350, 1438), (1441, 1509)]),
    dict(walk=[(78, 121), (133, 175), (185, 227), (236, 278), (290, 332), (343, 386)],
         idle=[(419, 463), (477, 522), (536, 580)],
         attack=[(620, 663), (678, 720), (737, 780), (798, 841), (856, 910)],
         drained=[(986, 1028), (1047, 1087)],
         death=[(1133, 1179), (1208, 1261), (1277, 1342), (1348, 1429), (1434, 1510)]),
]
ARC_DEATH_SPLIT = (1274, 1429)     # row 0: death frames 3 and 4 drawn touching


def no_bolt(f):
    """The thrower's own frame without lightning flying loose off it (the game draws the
    projectile): light not touching the figure goes, the charge in its hands stays."""
    g = f.copy()
    a = g.img[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n > 1:
        size = ndimage.sum(a, lab, np.arange(1, n + 1))
        main = lab == (int(np.argmax(size)) + 1)
        near = ndimage.binary_dilation(main, iterations=2)
        for k in range(1, n + 1):
            comp = lab == k
            if not (comp & near).any() or (comp & g.glow).sum() >= 0.5 * comp.sum() and \
                    not (comp & ndimage.binary_dilation(main, iterations=1)).any():
                g.img[comp] = 0
                g.glow &= ~comp
    return trim(g)


def build_arc():
    # round 9's blue light: the bolts' white core and dim halo count as light too (else
    # the halo round the ball in its hands stays an opaque navy ring)
    import import_round9 as r9
    old, r4.glow_kind = r4.glow_kind, r9.glow_kind
    try:
        return _build_arc()
    finally:
        r4.glow_kind = old


def _build_arc():
    S = Sheet(ARC_SRC, blank=ARC_LABELS)
    y0, y1 = ARC_BANDS[0]
    sc = fit_scale(S, [[(x0, y0, x1 + 1, y1)] for x0, x1 in ARC[0]["idle"]], ARC_H, 0.56)
    print(f"arc_thrower: scale {sc:.4f}")
    out = {}
    for r, d in enumerate(DIRS):
        y0, y1 = ARC_BANDS[r]
        fr = {}
        for anim, xs in ARC[r].items():
            rects = []
            for x in xs:
                if x == "split":
                    a, b = ARC_DEATH_SPLIT
                    c = col_cuts(S.fg, y0, y1, a, b, 2)
                    rects += [(c[0], c[1]), (c[1], c[2] - 1)]
                else:
                    rects.append(x)
            fr[anim] = [game(S, [(x0, y0, x1 + 1, y1)], sc, glow="blue", glow_cut=0.35) for x0, x1 in rects]
        out["walk", d] = steady(fr["walk"], "high")
        out["idle", d] = steady(fr["idle"], "low")
        out["attack", d] = steady([no_bolt(f) for f in fr["attack"]], "low")
        out["drained", d] = steady(fr["drained"], "low")
        out["death", d] = steady(fr["death"], "low", chain=True)
    return {"arc_thrower": write_kind("arc_thrower", out)}


# ---------------------------------------------------------------- effects

def light_frame(sheet, rect, scale):
    """A frame of painted light on the slate: un-blended from the slate as a whole
    (colour-to-alpha), box-shrunk, alpha in three steps like round 4's glow."""
    x0, y0, x1, y1 = rect
    rgb = sheet.px[y0:y1, x0:x1, :3].astype(float)
    bg = sheet.bgc
    al = np.clip((rgb - bg) / (255.0 - bg), 0, None).max(-1).clip(0, 1)
    al[~sheet.fg[y0:y1, x0:x1]] = 0
    col = np.clip((rgb - bg * (1 - al[..., None])) / np.maximum(al, 1e-6)[..., None], 0, 255)
    h, w = al.shape
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))

    def box(arr):
        return np.array(Image.fromarray(arr.astype(np.float32), "F").resize((nw, nh), Image.BOX))
    A = box(al)
    rgbs = np.dstack([box(col[..., c] * al) for c in range(3)]) / np.maximum(A, 1e-6)[..., None]
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = np.clip(rgbs, 0, 255).round()
    out[..., 3] = np.select([A >= 0.55, A >= 0.3, A >= 0.14], [255, 170, 95], 0)
    out[out[..., 3] == 0] = 0
    return clean(out, min_size=2, keep_near=2)


def solid_frame(sheet, rect, scale):
    img, _, _ = sheet.cut([rect])
    out, gl = r4.to_game(img, scale, sheet.bgc)
    # an effect has no team colour: keyed reds back to flame
    for key, colr in zip(((255, 0, 0), (150, 0, 0)), FLASH_RED):
        m = (out[..., :3] == key).all(-1)
        out[m, :3] = colr
    return out


def effect_strip(name, frames, centres):
    """Frames on one cell, each with its own centre point on the cell's middle."""
    tr = []
    for img, (cx, cy) in zip(frames, centres):
        ys, xs = np.nonzero(img[..., 3] > 0)
        tr.append((img[ys.min():ys.max() + 1, xs.min():xs.max() + 1], (cx - xs.min(), cy - ys.min())))
    frames, centres = [t[0] for t in tr], [t[1] for t in tr]
    L = R = U = D = 0
    for img, (cx, cy) in zip(frames, centres):
        h, w = img.shape[:2]
        L, R, U, D = max(L, cx), max(R, w - cx), max(U, cy), max(D, h - cy)
    hw, hh = int(np.ceil(max(L, R))) + 1, int(np.ceil(max(U, D))) + 1
    W, H = 2 * hw, 2 * hh
    cells = []
    for img, (cx, cy) in zip(frames, centres):
        c = np.zeros((H, W, 4), np.uint8)
        ox, oy = int(round(hw - cx)), int(round(hh - cy))
        h, w = img.shape[:2]
        m = img[..., 3] > 0
        c[oy:oy + h, ox:ox + w][m] = img[m]
        cells.append(c)
    Image.fromarray(np.concatenate(cells, 1)).save(f"assets/effects/{name}.png")
    print(f"effect {name}: {len(frames)} frames {W}x{H}")
    return (len(frames), W, H)


def bbox_centre(img):
    ys, xs = np.nonzero(img[..., 3] > 0)
    return (xs.min() + xs.max() + 1) / 2.0, (ys.min() + ys.max() + 1) / 2.0


def weighted_centre(img, mask=None):
    a = (img[..., 3] / 255.0) * (img[..., :3].astype(float).sum(-1) / 765.0) ** 2
    if mask is not None:
        a = a * mask
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    return (a * xx).sum() / a.sum() + 0.5, (a * yy).sum() / a.sum() + 0.5


SHELL_SCALE = 0.25    # the bomb ~10 px across
BLAST_SCALE = 0.5     # the burst ~60 px across (about two tiles)
ARC_BALL_SCALE = 0.42
ARC_IMPACT_SCALE = 0.42
FX_BAND_A = (866, 1010)
SHELLS = [(119, 168), (197, 238), (274, 310), (351, 393)]
BLASTS = [(595, 697), (717, 826), (826, "cut"), ("cut", 1070), (1094, 1223), (1255, 1377)]
FX_BAND_ARC = (880, 1000)
BALLS = [(164, 247), (257, 343), (358, 478)]
IMPACTS = [(652, 753), (764, 886), (893, 993), (1013, 1102)]


def build_effects():
    made = {}
    A = Sheet(MORTAR_A, blank=A_LABELS + [(0, 0, 1536, 862), (440, 862, 600, 1024)])
    y0, y1 = FX_BAND_A
    fr = [solid_frame(A, (a, y0, b + 1, y1), SHELL_SCALE) for a, b in SHELLS]
    # every shell on the middle of its black ball (the fuse sparkle changes)
    cents = []
    for img in fr:
        rgb = img[..., :3].astype(int)
        dark = (img[..., 3] > 0) & (rgb.max(-1) < 90)
        cents.append(weighted_centre(np.dstack([np.full(img.shape[:2] + (3,), 255, np.uint8), img[..., 3:]]), dark))
    made["mortar_shell"] = effect_strip("mortar_shell", fr, cents)
    c = col_cuts(A.fg, y0, y1, 826, 1070, 2)[1]
    rects = [(a if a != "cut" else c, b if b != "cut" else c) for a, b in BLASTS]
    fr = [solid_frame(A, (a, y0, b, y1), BLAST_SCALE) for a, b in rects]
    made["mortar_blast"] = effect_strip("mortar_blast", fr, [bbox_centre(f) for f in fr])
    S = Sheet(ARC_SRC, blank=[(0, 0, 1536, 860), (0, 860, 150, 1024), (500, 860, 640, 1024)])
    y0, y1 = FX_BAND_ARC
    fr = [light_frame(S, (a, y0, b + 1, y1), ARC_BALL_SCALE) for a, b in BALLS]
    made["arc_ball"] = effect_strip("arc_ball", fr, [weighted_centre(f) for f in fr])
    fr = [light_frame(S, (a, y0, b + 1, y1), ARC_IMPACT_SCALE) for a, b in IMPACTS]
    made["arc_impact"] = effect_strip("arc_impact", fr, [bbox_centre(f) for f in fr])
    return made


# ---------------------------------------------------------------- icons

def bevel_icon(img, name, size=52):
    """64x64 button icon in the frame of the hand-made Crown icons (the balloon's
    recipe): dark panel, the bevel profile of the cannon / musketeer icons."""
    ys, xs = np.nonzero(img[..., 3] > 0)
    img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    refs = [np.array(Image.open(f"assets/icons/{n}.png").convert("RGBA")).astype(float)
            for n in ("cannon", "pikeman")]
    B = 5
    prof = np.median(np.concatenate([np.concatenate(
        [r[12:52, :B], r[12:52, ::-1][:, :B], r[:B, 12:52].transpose(1, 0, 2),
         r[::-1][:B, 12:52].transpose(1, 0, 2)], 0) for r in refs], 0), 0)
    icon = np.zeros((64, 64, 4), np.uint8)
    yy = np.arange(64)[:, None]
    icon[..., :3] = np.clip(np.array([31, 34, 37]) - yy[..., None] * 0.15, 0, 255).astype(np.uint8)
    icon[..., 3] = 255
    h, w = img.shape[:2]
    inner = 64 - 2 * B
    ox, oy = B + (inner - w) // 2, B + (inner - h) // 2
    m = img[..., 3] > 0
    icon[oy:oy + h, ox:ox + w][m] = img[m]
    for dpt in range(B):
        c = prof[dpt].round().astype(np.uint8)
        icon[dpt, dpt:64 - dpt] = c
        icon[63 - dpt, dpt:64 - dpt] = c
        icon[dpt:64 - dpt, dpt] = c
        icon[dpt:64 - dpt, 63 - dpt] = c
    Image.fromarray(icon).save(f"assets/icons/{name}.png")


def source_icon(sheet, rect, name, size=52, keep=1.0, glow=None):
    """The drawing rendered straight from the sheet at icon size (sprites are too small
    to blow up), cut to its top `keep` share (a bust)."""
    img, _, _ = sheet.cut([rect])
    ys = np.flatnonzero((img[..., 3] > 0).any(1))
    img = img[:ys.min() + int((ys.max() + 1 - ys.min()) * keep)]
    xs = np.flatnonzero((img[..., 3] > 0).any(0))
    img = img[:, xs.min():xs.max() + 1]
    scale = size / max(img.shape[:2])
    out, _ = r4.to_game(img, scale, sheet.bgc, glow)
    bevel_icon(out, name)


def build_icons():
    front = Sheet(MUSK_SRC)
    # the armoured musketeer: three-quarter idle, waist up
    source_icon(front, (36, 98, 67, 188), "musketeer_armoured", size=56, keep=0.62)
    B = Sheet(MORTAR_B)
    source_icon(B, (1975, 72, 2031, 137), "mortar")          # the mortar on its bed
    S = Sheet(ARC_SRC, blank=ARC_LABELS)
    source_icon(S, (679, 255, 731, 370), "arc_thrower", glow="blue")


# ---------------------------------------------------------------- contact sheets

def strip_frames(kind, key, cw, n, anchor, ch):
    a = np.array(Image.open(f"assets/units/{kind}/{key}.png").convert("RGBA"))
    extra = a.shape[0] - ch
    out = []
    for i in range(n):
        fr = a[:, i * cw:(i + 1) * cw].copy()
        y = int(anchor[1]) + extra
        x = int(anchor[0])
        for xx in range(max(0, x - 2), min(cw, x + 3)):
            if fr[y, xx, 3] == 0:
                fr[y, xx] = (255, 255, 255, 140)
        fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
        fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
        out.append(fr)
    return out


def effects_contact(fx):
    lines = []
    for name, (n, w, h) in fx.items():
        strip = np.array(Image.open(f"assets/effects/{name}.png").convert("RGBA"))
        frames = []
        for i in range(n):
            fr = strip[:, i * w:(i + 1) * w].copy()
            fr[h // 2, w // 2] = (255, 255, 255, 160)          # the centre the game draws on
            fr[0, :, 3] = np.maximum(fr[0, :, 3], 40)
            fr[-1, :, 3] = np.maximum(fr[-1, :, 3], 40)
            frames.append(fr)
        lines.append((name, frames))
    os.makedirs(CONTACT, exist_ok=True)
    r4.contact_sheet(os.path.join(CONTACT, "contact_effects_round10.png"), lines)


def unit_contact(kind, entry, name=None, anims=None):
    cell, anchor, counts = entry
    lines = []
    keys = sorted(counts, key=lambda k: (k.rsplit("_", 1)[0], DIRS.index(k.rsplit("_", 1)[1])))
    H = 0
    for k in keys:
        H = max(H, Image.open(f"assets/units/{kind}/{k}.png").size[1])
    for k in keys:
        if anims and k.rsplit("_", 1)[0] not in anims:
            continue
        fr = strip_frames(kind, k, cell[0], counts[k], anchor, cell[1])
        fr = [np.concatenate([np.zeros((H - f.shape[0], f.shape[1], 4), np.uint8), f], 0) for f in fr]
        lines.append((k, fr))
    os.makedirs(CONTACT, exist_ok=True)
    r4.contact_sheet(os.path.join(CONTACT, f"contact_{name or kind}.png"), lines)


LINEUP = [("musketeer", "idle_s"), ("musketeer_armoured", "idle_s"), ("pikeman", "idle_s"),
          ("cannon", "walk_e"), ("mortar", "walk_e"), ("mortar", "idle_e"),
          ("arc_thrower", "idle_s"), ("gearknight", "idle_s")]


def lineup(path, k=3):
    """Scale line-up: first frames at game scale, feet on one ground line, x k."""
    import re
    src = open("scripts/art_data.gd").read()
    pics = []
    for kind, key in LINEUP:
        m = re.search(r'"%s": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)' % kind, src)
        cw, ch, ax, ay = int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(4))
        a = np.array(Image.open(f"assets/units/{kind}/{key}.png").convert("RGBA"))
        ex = a.shape[0] - ch
        f = a[:, :cw]
        ys, xs = np.nonzero(f[..., 3] > 0)
        x0, x1 = xs.min(), xs.max() + 1
        pics.append((kind + "\n" + key, f[:ys.max() + 1, x0:x1], ay + ex))
    up = max(int(np.ceil(g)) for _, _, g in pics)
    down = max(p.shape[0] - int(g) for _, p, g in pics)
    W = sum(p.shape[1] + 10 for _, p, _ in pics) + 10
    H = up + down + 4
    can = np.zeros((H, W, 4), np.uint8)
    can[..., :3] = (0x55, 0x8B, 0x45)
    can[..., 3] = 255
    x = 10
    labels = []
    for lab, p, g in pics:
        oy = up - int(g) + 1
        m = p[..., 3] > 0
        can[oy:oy + p.shape[0], x:x + p.shape[1]][m] = p[m]
        labels.append((x, lab))
        x += p.shape[1] + 10
    can[up + 1, :, :3] = (40, 70, 34)
    im = Image.fromarray(can).resize((W * k, H * k), Image.NEAREST)
    out = Image.new("RGB", (W * k, H * k + 30), (24, 24, 24))
    out.paste(im, (0, 0))
    d = ImageDraw.Draw(out)
    for x, lab in labels:
        d.text((x * k, H * k + 2), lab, fill=(255, 255, 255))
    out.save(path)


def main():
    if DEBUG:
        os.makedirs(DEBUG, exist_ok=True)
    entries = {}
    if "--only" not in _argv or "musketeer" in _argv[_argv.index("--only") + 1]:
        entries.update(build_musketeers())
    if "--only" not in _argv or "mortar" in _argv[_argv.index("--only") + 1]:
        entries.update(build_mortar())
    if "--only" not in _argv or "arc" in _argv[_argv.index("--only") + 1]:
        entries.update(build_arc())
    fx = {}
    if "--only" not in _argv or "effects" in _argv[_argv.index("--only") + 1]:
        fx = build_effects()
        r4.write_effects_data(fx)
    if "--only" not in _argv or "icons" in _argv[_argv.index("--only") + 1]:
        build_icons()
    r4.write_units_data(entries)
    if CONTACT:
        for kind, e in entries.items():
            unit_contact(kind, e)
        if fx:
            effects_contact(fx)
        lineup(os.path.join(CONTACT, "lineup.png"))


if __name__ == "__main__":
    main()
