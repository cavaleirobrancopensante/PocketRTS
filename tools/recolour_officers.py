"""The Officers and the riders in white coats and team-colour breeches (owner, 2026-10-27:
"The Officer is hard to tell apart from the Musketeer").

The Musketeer keeps his red coat (the team colour) and light trousers. The Horseman (mounted:
assets/units/horseman/, on foot the Officer: assets/units/dismounted/) and the Cuirassier
(assets/units/cuirassier/, on foot the Armoured Officer: assets/units/dismounted_armoured/, his
steel kept) get, in code, on the painted strips:

  * a WHITE COAT: the coat's key reds (shaders/team.gdshader repaints only (255,0,0) and
    (150,0,0)) become a shaded white well outside the keys, and the pinkish anti-aliased
    pixels round it a light grey;
  * TEAM-COLOUR BREECHES: the Officers' grey breeches (the band between the coat's skirts and
    the boots) are painted with the key reds by tone; the riders' legs are already painted red
    and stay so;
  * a TEAM-COLOUR SASH at the waist (two rows of the coat stay red); on the riders the coat's
    lower rows stay red over the thighs, the same idea;
  * a TEAM-COLOUR PLUME: the Officer's / Horseman's white hat feather in the key reds (the
    Armoured Officer's helmet plume was already red and stays so);
  * a TEAM-COLOUR SADDLE CLOTH on the riders' horses (idle, walk, sabre, pistol and the
    upright death frames): the horse's pixels round the rider's legs, below his seat, in the
    key reds by the horse's tone (the horse coat mask still marks them, but the shader's key
    reds come first). The mounting strips already have their painted cloth.

The team-colour pixels this tool paints are near-keys, not the exact keys (well within the
shader's 0.08: the game shows them in the team colour), so the tool can tell what it painted
from what the painter did: run twice it changes nothing. The coat whites are exact values not
found in the art (tools/import_vet_trim.py reads them as the coat, like the reds it reads).

Also: the four units' portraits (assets/icons/<unit>.png, painted reds, not team keys): the
coat to white, the hat feather crimson. The Barracks' drill strips (assets/buildings/drill_*)
are made from these strips by tools/import_barracks_props.py, which runs after this one.

Per-strip rules (RULES below) cover what the colour test can't: the lying death frames, a few
frames' boxes kept as painted.

Usage (repo root): python3 tools/recolour_officers.py [--dry] [--only unit[/strip]]
tools/rebuild_art.sh runs it after the horse coat masks (tools/import_horse_coats.py) and before
tools/import_barracks_props.py and tools/import_vet_trim.py.
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
U = os.path.join(ROOT, "assets/units")
DRY = "--dry" in sys.argv
ONLY = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
REDO = "--redo" in sys.argv
# the strips as the importers left them (written on the first run: a strip that already wears
# the white coat is done; --redo recolours it again from here, after this tool's rules change)
SRC = os.path.join(ROOT, "art/redraws/officer_white_src")

# the coat's whites (exact values the art doesn't use: keep tools/import_vet_trim.py in step)
COAT_LIGHT = (237, 234, 223)
COAT_DARK = (177, 173, 165)
COAT_DEEP = (121, 117, 111)       # (a dark red anti-aliased pixel at the coat's edge)
WHITES = (COAT_LIGHT, COAT_DARK, COAT_DEEP)
# team colour this tool paints: near the keys (light, dark), so a second run knows them
SASH = ((253, 1, 1), (148, 1, 1))
BREECHES = ((250, 2, 2), (146, 2, 2))
CLOTH = ((251, 3, 3), (147, 3, 3))
PLUME = ((252, 2, 1), (149, 2, 1))
MARKS = SASH + BREECHES + CLOTH + PLUME

UNITS = {
    #                 foot / rider, plume: "feather" (his hat's white feather to red) or None
    "dismounted": {"rider": False, "plume": "feather"},
    "dismounted_armoured": {"rider": False, "plume": None},
    "horseman": {"rider": True, "plume": "feather"},
    "cuirassier": {"rider": True, "plume": None},
}
# the shoulders: the first row with this many coat pixels (a plume or a raised sleeve has fewer)
SHOULDER_MIN = {False: 5, True: 3}
NEAR = 7               # px beside his head's columns a piece of his coat is centred
HEAD_ROWS = 4          # (and at least this many rows below the top of the man: not a helmet's plume)
# rows of white from the shoulders down (foot: then the sash, then white skirts again;
# rider: below this the coat's skirt over his thighs stays red, then his red legs)
WHITE_ROWS = {False: 6, True: 7}
SASH_ROWS = 2
CLOTH_ANIMS = ("idle", "walk", "attack", "pistol", "death")
CLOTH_REACH = 3        # px from his legs
CLOTH_ROWS = 10        # rows below his seat
LEG_DOWN = 5           # rows below his seat a leg reaches
CLOTH_SIDE = 4         # px before and behind his leg, seen from the side
LYING_COAT = 0.55      # of a lying rider's red, from his head's end: his coat (the rest: his legs)
MOUNT_STANDING = (0, 1)   # mounting strips: the frames where he still stands beside the horse
UPRIGHT = 0.8          # a death frame at least this tall (of the strip's tallest) still has him up

# Per strip ("anim_dir") rules: "keep": boxes (x0, y0, x1, y1 in frame px, frames or None) left
# as painted; "lying": frames to treat as lying down (by default: shorter than UPRIGHT of the
# strip's tallest, death strips only); "head": "left" / "right", the lying man's head side.
RULES = {
    # His horse's painted saddle cloth right beside him as he steps up to mount: stays red.
    "cuirassier/mount_e": {"keep": [(37, 30, 64, 52, [0]), (44, 30, 64, 52, [1])]},
    "cuirassier/mount_se": {"keep": [(36, 30, 54, 50, [0]), (40, 30, 54, 50, [1])]},
    # The Cuirassier's fall: his horse's painted saddle cloth (frames 2-3, and the whole tumble
    # in frame 1 seen from the front and the diagonals) stays red; frame 3 he lies beside it.
    "cuirassier/death_s": {"keep": [(30, 35, 50, 52, [1]), (38, 42, 54, 55, [2, 3])], "lying": [3], "head": "right"},
    "cuirassier/death_se": {"keep": [(30, 35, 50, 52, [1]), (38, 43, 51, 53, [2, 3])], "lying": [3], "head": "right"},
    "cuirassier/death_e": {"keep": [(38, 46, 50, 53, [2, 3])], "lying": [3], "head": "right"},
    "cuirassier/death_ne": {"keep": [(30, 35, 50, 50, [1]), (41, 45, 56, 54, [2, 3])], "lying": [3], "head": "right"},
    "cuirassier/death_n": {"keep": [(39, 39, 54, 56, [2, 3])], "lying": [3], "head": "left"},
}


def exact_key(px):
    r, g, b = px[..., 0].astype(int), px[..., 1].astype(int), px[..., 2].astype(int)
    return (g == 0) & (b == 0) & ((r == 255) | (r == 150))


def is_any(px, cols):
    m = np.zeros(px.shape[:2], bool)
    for c in cols:
        m |= (px[..., 0] == c[0]) & (px[..., 1] == c[1]) & (px[..., 2] == c[2])
    return m


def lum(px):
    p = px[..., :3].astype(np.float32)
    return p[..., 0] * 0.299 + p[..., 1] * 0.587 + p[..., 2] * 0.114


def sat(px):
    p = px[..., :3].astype(np.float32)
    mx, mn = p.max(-1), p.min(-1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)


def cells():
    src = open(os.path.join(ROOT, "scripts/art_data.gd")).read()
    out = {}
    for u in UNITS:
        m = re.search(r'"%s": \{"cell": Vector2i\((\d+), (\d+)\)' % u, src)
        out[u] = (int(m.group(1)), int(m.group(2)))
    return out


def put(arr, m, light, dark, is_light):
    arr[m & is_light, :3] = light
    arr[m & ~is_light, :3] = dark


def pinkish(px):
    """The snap's leftovers round the coat: reddish, no yellow in them (not skin, not leather)."""
    p = px[..., :3].astype(int)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    return (r >= 70) & (r * 10 > g * 16) & (r * 10 > b * 16) & (np.abs(g - b) < 18) & ~exact_key(px) & ~is_any(px, MARKS)


def recolour_frame(f, horse, rider, plume, cloth, lying, keep, head, view="s", legs_rows=9, raised=False, beside=False):
    """f: the frame (H, W, 4) uint8, changed in place. horse: its horse mask (bool) or None."""
    a = f[..., 3] >= 128
    man = a & ~horse if horse is not None else a.copy()
    for x0, y0, x1, y1 in keep:
        man[y0:y1, x0:x1] = False
    ex = exact_key(f) & man
    light = f[..., 0] >= 200          # (the key's light red; for the whites, the light white)
    white = is_any(f, WHITES) & man
    sash = is_any(f, SASH) & man
    coatlike = ex | white | sash
    if not coatlike.any():
        return
    H, W = coatlike.shape
    lab, n = ndimage.label(coatlike, structure=np.ones((3, 3)))
    sizes = ndimage.sum(coatlike, lab, range(1, n + 1))
    if lying:
        # lying down: the whole coat white, but a small piece apart from it (his plume) stays;
        # his breeches by the head side: the half of the man away from his head
        big = int(np.argmax(sizes)) + 1
        coat = np.zeros_like(ex)
        for i in range(n):
            if sizes[i] >= 6 or i + 1 == big:
                coat |= lab == i + 1
        to_white = ex & coat
        if not rider and head in ("left", "right") and to_white.any():
            # (an Officer: his grey breeches are past his coat's end away from his head)
            xs = np.nonzero(to_white.any(0))[0]
            xx = np.arange(W)[None, :] * np.ones((H, 1), int)
            S, L, p = sat(f), lum(f), f[..., :3].astype(int)
            grey = man & (S < 0.45) & (L >= 38) & (p[..., 2] <= p[..., 0] + 10) & ~exact_key(f) & ~is_any(f, WHITES + MARKS)
            br = grey & ((xx <= xs.min() + 2) if head == "right" else (xx >= xs.max() - 2))
            put(f, br, BREECHES[0], BREECHES[1], L >= 105)
        elif head in ("left", "right") and to_white.any():
            # (his legs, the half away from his head, stay red: the rider's breeches)
            xs = np.nonzero(to_white.any(0))[0]
            split = xs.min() + (xs.max() - xs.min()) * LYING_COAT
            xx = np.arange(W)[None, :] * np.ones((H, 1), int)
            to_white &= (xx >= xs.max() - (xs.max() - xs.min()) * LYING_COAT) if head == "right" else (xx <= split)
        put(f, to_white, COAT_LIGHT, COAT_DARK, light)
        aa = pinkish(f) & man & ndimage.binary_dilation(to_white, np.ones((3, 3)))
        put(f, aa, COAT_LIGHT, COAT_DEEP, f[..., 0] >= 140)
        return
    top = int(np.nonzero(man.any(1))[0].min())
    # (only what hangs under his head: not a painted saddle cloth beside him as he mounts)
    hx = np.nonzero(man[top:top + 6].any(0))[0]
    cx = np.array([ndimage.center_of_mass(lab == i + 1)[1] for i in range(n)])
    under = np.isin(lab, [i + 1 for i in range(n) if hx.min() - NEAR <= cx[i] <= hx.max() + NEAR or not beside])
    # (a plume: a small piece starting at the top of him; it stays red. With the sabre raised
    # (a rider's attack strips: no plume on them) the top is his fist and red up there is his sleeve)
    plumes = [i + 1 for i, sl in enumerate(ndimage.find_objects(lab)) if sl[0].start <= top + 3 and sizes[i] <= 25]
    if not raised:
        under &= ~np.isin(lab, plumes)
    coatlike &= under
    ex &= under | ((np.arange(H)[:, None] > top + 30) if rider else False)
    rows = coatlike.sum(1)
    rows[:top + HEAD_ROWS] = 0
    sh = np.nonzero(rows >= SHOULDER_MIN[rider])[0]
    if not len(sh):
        # (only a sleeve shows: a big plume over a turned body)
        rows[:top + 8] = 0
        sh = np.nonzero(rows >= 2)[0]
    if not len(sh):
        return
    s = int(sh[0])
    # the coat's pieces: those in the shoulder rows (and what joins them above: a raised arm)
    band = np.zeros_like(coatlike)
    band[s:s + 3] = True
    ids = np.unique(lab[band & coatlike])
    coat = np.isin(lab, ids[ids > 0])
    ys = np.arange(H)[:, None] * np.ones((1, W), int)
    wr = WHITE_ROWS[rider]
    in_white = ((ys >= s) & (ys < s + wr)) | ((ys < s) & (coat | raised))
    in_sash = (ys >= s + wr) & (ys < s + wr + SASH_ROWS)
    if rider:
        to_white = ex & in_white
        to_sash = np.zeros_like(ex)
    else:
        to_white = ex & (in_white | (ys >= s + wr + SASH_ROWS))
        to_sash = ex & in_sash
    put(f, to_white, COAT_LIGHT, COAT_DARK, light)
    put(f, to_sash, SASH[0], SASH[1], light)
    aa = pinkish(f) & man & (ys >= s - 1) & ndimage.binary_dilation(to_white, np.ones((3, 3)))
    if rider:
        aa &= ys < s + wr
    put(f, aa, COAT_LIGHT, COAT_DEEP, f[..., 0] >= 140)
    L = lum(f)
    S = sat(f)
    p = f[..., :3].astype(int)
    # the Officers' breeches: under the coat's skirts per column, down to the boots
    if not rider:
        coat_now = is_any(f, WHITES + SASH) & man
        ground = int(np.nonzero(a.any(1))[0].max())
        grey = man & (S < 0.45) & (L >= 38) & (p[..., 2] <= p[..., 0] + 10) & ~is_any(f, WHITES) & ~exact_key(f)
        done = is_any(f, BREECHES) & man
        trouser = grey | done      # (what an earlier run painted counts as the breeches it was: run twice, the same)
        boot = man & (S >= 0.45) & (p[..., 0] > p[..., 1]) & (p[..., 1] > p[..., 2])
        br = np.zeros_like(man)
        for x in range(W):
            cy = np.nonzero(coat_now[s + wr:, x])[0]
            if not len(cy):
                continue
            yc = s + wr + int(cy.max())
            found = False
            for y in range(yc + 1, min(yc + legs_rows, ground - 3)):
                if not a[y, x]:
                    break
                if boot[y, x] and (found or y > yc + 4):
                    break           # (his boot; a bit of brown just under the coat's hem is its tail or a belt)
                if trouser[y, x]:
                    br[y, x] = True
                    found = True
        if br.any():
            ys_br = np.nonzero(br.any(1))[0]
            zone = (ys >= ys_br.min()) & (ys <= ys_br.max())
            for _ in range(2):
                br |= trouser & zone & ndimage.binary_dilation(br, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
        br &= ~done
        put(f, br, BREECHES[0], BREECHES[1], L >= 105)
    # the hat's white feather: red
    if plume == "feather":
        head = man & (ys <= s - 3)
        fe = head & (S < 0.22) & (L >= 105) & (p[..., 2] <= p[..., 0] + 8)
        # (on the hat: next to its felt)
        felt = head & (S >= 0.3) & (p[..., 0] > p[..., 1]) & (p[..., 1] > p[..., 2]) & (L >= 30) & (L < 150)
        # (his hat: the biggest piece of felt up there, not a muzzle flash's orange)
        labf, nf = ndimage.label(felt, structure=np.ones((3, 3)))
        if nf:
            felt = labf == 1 + int(np.argmax(ndimage.sum(felt, labf, range(1, nf + 1))))
        near = ndimage.binary_dilation(felt, np.ones((5, 5)))
        lab2, n2 = ndimage.label(fe, structure=np.ones((3, 3)))
        for i in range(1, n2 + 1):
            comp = lab2 == i
            sl = ndimage.find_objects(comp.astype(int))[0]
            w, hh = sl[1].stop - sl[1].start, sl[0].stop - sl[0].start
            blade = min(w, hh) <= 3 and max(w, hh) >= 2 * min(w, hh) + 2      # (a raised sabre, not a feather)
            if comp.sum() >= 4 and not blade and w <= 9 and hh <= 7 and (comp & near).any():
                put(f, comp, PLUME[0], PLUME[1], L >= 170)
    # the saddle cloth: the horse round his legs, below his seat
    if cloth and horse is not None:
        seat = s + wr
        red = (exact_key(f) | is_any(f, SASH)) & man & (ys >= seat - 1)
        # (his legs: the red pieces from his seat hanging LEG_DOWN rows below it, not a sleeve
        # reaching forward at the saddle's height, nor a speck of red tack lower down)
        lab3, n3 = ndimage.label(red, structure=np.ones((3, 3)))
        legs = np.zeros_like(red)
        for i, sl in enumerate(ndimage.find_objects(lab3)):
            if sl is not None and sl[0].stop - 1 >= seat + LEG_DOWN and sl[0].start <= seat + 3:
                legs |= lab3 == i + 1
        if legs.any():
            near = ndimage.binary_dilation(legs, np.ones((2 * CLOTH_REACH + 1, 2 * CLOTH_REACH + 1)))
            if view in ("e", "se", "ne"):
                # (from the side: a cloth hanging down the horse's flank round his leg)
                lx = np.nonzero(legs.any(0))[0]
                near = np.zeros_like(legs)
                near[:, max(lx.min() - CLOTH_SIDE, 0):lx.max() + CLOTH_SIDE + 1] = True
            # (the horse: its mask, and its grey coat round the saddle, which the mask leaves out with
            # the rider's tack; not a blade's bluish steel, not his white coat)
            coat_grey = (S < 0.25) & (p[..., 2] <= p[..., 0] + 6) & ~is_any(f, WHITES + MARKS)
            cl = near & (horse | coat_grey) & a & (L >= 30) & (ys >= seat) & (ys < seat + CLOTH_ROWS) & ~exact_key(f)
            if cl.any():
                t = np.median(L[cl])
                put(f, cl, CLOTH[0], CLOTH[1], L >= t)


def strip_list(unit):
    d = os.path.join(U, unit)
    for fn in sorted(os.listdir(d)):
        if fn.endswith(".png"):
            yield fn[:-4]


def done_already(im):
    return is_any(im, (COAT_LIGHT, COAT_DARK)).sum() >= 3


def source(p, snap, done, log):
    """The strip to recolour: as it is (snapshotted first), or None: done already; --redo: the snapshot."""
    im = np.array(Image.open(p).convert("RGBA"))
    if not done(im):
        if not DRY:
            os.makedirs(os.path.dirname(snap), exist_ok=True)
            Image.fromarray(im).save(snap)
        return im
    if REDO and os.path.exists(snap):
        return np.array(Image.open(snap).convert("RGBA"))
    return None


def do_strip(unit, key, cell, log):
    cfg = UNITS[unit]
    p = os.path.join(U, unit, key + ".png")
    im = source(p, os.path.join(SRC, unit, key + ".png"), done_already, log)
    if im is None:
        return
    before = np.array(Image.open(p).convert("RGBA"))
    hp = os.path.join(U, "horse_masks", unit, key + ".png")
    hm = np.array(Image.open(hp).convert("RGB"))[..., 0] > 127 if os.path.exists(hp) else None
    cw = cell[0]
    n = im.shape[1] // cw
    anim = key.split("_")[0]
    rule = RULES.get(unit + "/" + key, {})
    tall = []
    for i in range(n):
        ys = np.nonzero(im[:, i * cw:(i + 1) * cw, 3].any(1))[0]
        xs = np.nonzero(im[:, i * cw:(i + 1) * cw, 3].any(0))[0]
        tall.append(int(np.ptp(ys)) if len(ys) else 0)
    for i in range(n):
        sl = slice(i * cw, (i + 1) * cw)
        f = im[:, sl]
        horse = hm[:, sl] if hm is not None else None
        if "lying" in rule:
            lying = i in rule["lying"]
        else:
            lying = anim == "death" and tall[i] < UPRIGHT * max(tall)
            if cfg["rider"] and anim == "death":
                # (a rider falls: his own height, not the horse's)
                man = (f[..., 3] >= 128) & (~horse if horse is not None else True)
                mys = np.nonzero(man.any(1))[0]
                mxs = np.nonzero(man.any(0))[0]
                lying = len(mys) > 0 and (np.ptp(mys) + 1) < 0.9 * (np.ptp(mxs) + 1)
            elif anim == "death":
                # (an Officer: lying when he is wider than tall; kneeling as he falls he is still up)
                ys = np.nonzero(f[..., 3].any(1))[0]
                xs = np.nonzero(f[..., 3].any(0))[0]
                lying = len(ys) > 0 and (np.ptp(xs) + 1) > 1.2 * (np.ptp(ys) + 1)
        keep = [b[:4] for b in rule.get("keep", []) if len(b) < 5 or b[4] is None or i in b[4]]
        cloth = cfg["rider"] and anim in CLOTH_ANIMS and not lying and (anim != "death" or tall[i] >= UPRIGHT * max(tall))
        head = rule.get("head", "right" if anim == "death" else None)     # (every lying man lies with his head to the right)
        if cfg["rider"] and anim == "mount" and i in MOUNT_STANDING:
            # (still on foot beside the horse: dressed like the Officer, the coat white to the hem
            # and the breeches red; the horse coat mask took his grey breeches for the horse's)
            recolour_frame(f, None, False, cfg["plume"], False, False, keep, None, key.split("_")[-1], legs_rows=13, beside=True)
        else:
            recolour_frame(f, horse, cfg["rider"], cfg["plume"], cloth, lying, keep, head, key.split("_")[-1], raised=cfg["rider"] and anim == "attack", beside=anim == "mount")
        im[:, sl] = f
    if (im != before).any():
        log.append("%s/%s: %d px" % (unit, key, int((im != before).any(-1).sum())))
        if not DRY:
            Image.fromarray(im).save(p)


# ---- portraits (painted, smooth reds: not team keys) ----
# per icon: boxes (x0, y0, x1, y1) where red is the coat; feather boxes (white to crimson)
ICONS = {
    "dismounted": {"coat": [(0, 26, 64, 64)], "feather": [(0, 0, 33, 28)]},
    "dismounted_armoured": {"coat": [(0, 30, 64, 64)], "feather": []},
    "horseman": {"coat": [(0, 27, 50, 64)], "feather": [(0, 0, 40, 24)]},
    "cuirassier": {"coat": [(0, 0, 64, 64)], "feather": []},
}


def icon_red(px):
    p = px[..., :3].astype(int)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    deep = (r >= 40) & (r > g + 35) & (r > b + 35) & (g * 10 < r * 5) & (np.abs(g - b) < 30)
    pink = (r >= 100) & (r > g + 35) & (g * 10 < r * 7) & (np.abs(g - b) < 20)     # (the reds' light edges)
    return (px[..., 3] > 0) & (deep | pink)


def do_icon(name, log):
    p = os.path.join(ROOT, "assets/icons", name + ".png")
    cfg = ICONS[name]
    box = np.zeros((64, 64), bool)
    for x0, y0, x1, y1 in cfg["coat"]:
        box[y0:y1, x0:x1] = True
    # (done: hardly any red coat left in its box)
    im = source(p, os.path.join(SRC, "icons", name + ".png"), lambda a: (icon_red(a) & box).sum() < 20, log)
    if im is None:
        return
    before = np.array(Image.open(p).convert("RGBA"))
    red = icon_red(im) & box
    r = im[..., 0].astype(np.float32)
    # the red's value to a warm white's: 0.30 .. 1.0 of the light
    t = np.clip((r - 40) / 200.0, 0, 1)
    wv = 92 + t * (238 - 92)
    out = np.stack([wv, wv * 0.985, wv * 0.95], -1)
    im[red, :3] = out[red].astype(np.uint8)
    fb = np.zeros_like(box)
    for x0, y0, x1, y1 in cfg["feather"]:
        fb[y0:y1, x0:x1] = True
    p3 = im[..., :3].astype(int)
    L = lum(im)
    S = sat(im)
    fe = fb & (S < 0.32) & (L >= 110) & (im[..., 3] > 0)
    # (the feather: light pixels, crimson by their lightness)
    lt = np.clip((L - 120) / 135.0, 0, 1)
    crim = np.stack([120 + lt * 120, 10 + lt * 30, 16 + lt * 34], -1)
    im[fe, :3] = crim[fe].astype(np.uint8)
    if (im != before).any():
        log.append("icon %s: %d px" % (name, int((im != before).any(-1).sum())))
        if not DRY:
            Image.fromarray(im).save(p)


def main():
    cs = cells()
    log = []
    for unit in UNITS:
        if ONLY and ONLY.split("/")[0] != unit:
            continue
        for key in strip_list(unit):
            if ONLY and "/" in ONLY and ONLY.split("/")[1] != key:
                continue
            do_strip(unit, key, cs[unit], log)
    if not ONLY:
        for name in ICONS:
            do_icon(name, log)
    print("\n".join(log) if log else "recolour_officers: nothing to change")


if __name__ == "__main__":
    main()
