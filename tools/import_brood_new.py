#!/usr/bin/env python3
"""Import the NEW BROOD's three creatures (docs/brood_new.md) from the owner's ChatGPT sheets in art/redraws/:
the BROOD MOTHER (the Queen, kind "brood_mother"), the ROOTMAW (the swamp lizard, kind "rootmaw") and the
TYRANNOSAUR (the father of the ground warriors, kind "tyrannosaur").

Every sheet is drawn on a flat dark navy background. Steps (re-runnable: python3 -I tools/import_brood_new.py
[--contact DIR] [--only KIND]):
  1. Key out the navy: the background colour is the median of the sheet's border; a pixel more than KEY from it
     (sum of |dr|+|dg|+|db|) is drawing, except the soft dark-navy drop shadow (dark, blue over red, close to the
     background); pockets of background smaller than HOLE inside a drawing are filled back in (its own dark shading).
  2. Split the frames: each sprite is a big connected piece plus the small bits near it (egg sparkles, spit, dirt
     crumbs: import_art.components); pieces are grouped into rows by their height on the sheet, left to right.
  3. Scale: each creature has a target width for its south-east walk (TARGET_W, game px: the Queen as wide as the
     Clocktower's gear ring, the Rootmaw a bit wider than a Cottage, the Tyrannosaur as wide as a Barracks); that gives
     the creature's height H. Every other sheet is scaled so its reference frame (REF: a standing or walking pose)
     is H tall (times a small per-sheet fudge), so sheets ChatGPT drew at different sizes come out the same size.
  4. Box-filter shrink with premultiplied alpha, hard alpha; the red spikes snapped to the two key reds the team
     shader repaints (import_art.snap_team), as on every Brood creature.
  5. Feet on the ground: one canvas per creature; every frame is placed with its lowest row on the anchor line and
     its body's centre of mass (columns) on the anchor column, so a walk does not slide sideways frame to frame.
     West views are the east ones mirrored by the game.
Writes assets/units/<kind>/<anim>_<dir>.png, the kinds' entries in scripts/art_data.gd (BASE_UNITS), the portraits
assets/icons/<kind>.png (from the painted portraits) and the placeholder command icons assets/icons/brood/ab_uproot.png,
ab_haul.png (drawn from the existing Brood icons until the owner's arrive; docs/art_style_inconsistency.md).
"""
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

R = "art/redraws/"
KEY = 40
HOLE = 1500

# kind -> south-east walk width in game px (the anchor of the creature's size)
# (checked in game, tools/shot_brood_new.gd scale.png: the Clocktower's gear ring is about 350 px across, a Cottage 72 px
# wide, a Barracks 140 px: the Mother rooted in her nest about as wide as the ring, the Rootmaw a bit wider than the
# Cottage, the Tyrannosaur about the Barracks' width)
TARGET_W = {"brood_mother": 315, "rootmaw": 84, "tyrannosaur": 142,
            # (the Mound Turtle: rooted in its mud about a Clutch Mound's 74 px, so its walk about 66)
            "mound_turtle": 66}

# kind -> list of sheets: (file, [row specs], ref (row, frame), fudge)
# a row spec: (anim, dir) or None (row skipped); frames: all of the row, or (anim, dir, [indices])
SHEETS = {
    "brood_mother": [
        ("brood_mother_se_walk_stride_chatgpt.png", [("walk", "se")], (0, 0), 1.0),
        ("brood_mother_s_walk_stride_chatgpt.png", [("walk", "s")], (0, 0), 1.0),
        ("brood_mother_e_walk_stride_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
        ("brood_mother_ne_walk_stride_chatgpt.png", [("walk", "ne")], (0, 0), 1.0),
        ("brood_mother_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
        ("brood_mother_se_rooting_chatgpt.png", [("root", "se"), ("rooted", "se"), ("uproot", "se")], (0, 0), 1.0),
        ("brood_mother_se_walk_lay_death_chatgpt.png", [None, None, ("death", "se")], (0, 0), 1.0),
        ("brood_mother_se_attack_fixed.png", [("attack", "se")], (0, 0), 1.0),
        ("brood_mother_s_attack_chatgpt.png", [("attack", "s")], (0, 0), 1.0),
        ("brood_mother_e_attack_chatgpt.png", [("attack", "e")], (0, 0), 1.0),
        ("brood_mother_ne_attack_chatgpt.png", [("attack", "ne")], (0, 0), 1.0),
        ("brood_mother_n_attack_fixed.png", [("attack", "n")], (0, 0), 1.0),
    ],
    "rootmaw": [
        ("rootmaw_lizard_se_chatgpt.png", [("walk", "se"), ("root", "se"), ("fill", "se"), ("uproot", "se"), ("death_full", "se")], (0, 0), 1.0),
        ("rootmaw_lizard_s_walk_chatgpt.png", [("walk", "s")], (0, 0), 1.0),
        ("rootmaw_lizard_e_walk_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
        ("rootmaw_lizard_ne_walk_chatgpt.png", [("walk", "ne")], (0, 0), 1.0),
        ("rootmaw_lizard_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
        ("rootmaw_lizard_thin_death_chatgpt.png", [("death", "se")], (0, 0), 1.0),
        ("rootmaw_lizard_se_attack_chatgpt.png", [("attack", "se")], (0, 0), 1.0),
        ("rootmaw_lizard_s_attack_chatgpt.png", [("attack", "s")], (0, 0), 1.0),
        ("rootmaw_lizard_e_attack_chatgpt.png", [("attack", "e")], (0, 0), 1.0),
        ("rootmaw_lizard_ne_attack_chatgpt.png", [("attack", "ne")], (0, 0), 1.0),
        ("rootmaw_lizard_n_attack_chatgpt.png", [("attack", "n")], (0, 0), 1.0),
    ],
    "tyrannosaur": [
        ("tyrannosaur_se_walk_bite_chatgpt.png", [("walk", "se"), ("attack", "se")], (0, 0), 1.0),
        ("tyrannosaur_se_breath_death_chatgpt.png", [("breath", "se"), ("death", "se")], (0, 0), 1.0),
        ("tyrannosaur_s_walk_chatgpt.png", [("walk", "s")], (0, 0), 1.0),
        ("tyrannosaur_e_walk_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
        ("tyrannosaur_ne_walk_chatgpt.png", [("walk", "ne")], (0, 0), 1.0),
        ("tyrannosaur_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
        ("tyrannosaur_s_bite_chatgpt.png", [("attack", "s")], (0, 0), 1.0),
        ("tyrannosaur_e_bite_chatgpt.png", [("attack", "e")], (0, 0), 1.0),
        ("tyrannosaur_ne_bite_chatgpt.png", [("attack", "ne")], (0, 0), 1.0),
        ("tyrannosaur_n_bite_chatgpt.png", [("attack", "n")], (0, 0), 1.0),
    ],
}
# THE MOUND TURTLE (the owner's sheets, 14:18): the south-east sheet in 5 rows (walk 6, rooting 6, rooted loop 4,
# uprooting 5, death 5); the east sheet's first row is the east walk; the south walk is 2 rows of 3 (a JPEG made PNG).
# The north-east walk: 7 frames in 2 rows (4 + 3), the second row drawn about an eighth bigger (ROW_EVEN brings it to
# the first row's size); its 5th frame (the second row's first: lower, with no bubbles) breaks the step and is dropped,
# leaving a 6-frame loop; it is drawn flatter, so at the same height its body is bigger: 0.95 brings its area to the
# east walk's. The north walk (one row of 6) is drawn too tall and narrow, almost upright: SHEET_FIT scales
# it to the south walk's width and squashes it to 78% of its height, so it sits as low and wide as the south walk.
SHEETS["mound_turtle"] = [
    ("mound_turtle_se_chatgpt.png", [("walk", "se"), ("root", "se"), ("rooted", "se"), ("uproot", "se"), ("death", "se")], (0, 0), 1.0),
    ("mound_turtle_e_sheet_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
    ("mound_turtle_s_walk_chatgpt.png", [("walk", "s"), ("walk", "s2")], (0, 0), 1.0),
    ("mound_turtle_ne_walk_chatgpt.png", [("walk", "ne"), ("walk", "ne2", [1, 2])], (0, 0), 0.95),
    ("mound_turtle_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
]
ROW_BY_MIDDLE = {"mound_turtle_se_chatgpt.png": 5, "mound_turtle_e_sheet_chatgpt.png": 5}
ROW_EVEN = {"mound_turtle_ne_walk_chatgpt.png"}      # each row scaled to the first row's mean frame width
# sheet: (the sheet whose first frame's width in game it takes, its height squashed by this much)
SHEET_FIT = {"mound_turtle_n_walk_chatgpt.png": ("mound_turtle_s_walk_chatgpt.png", 0.78)}
PORTRAIT = {"brood_mother": "brood_mother_portrait_chatgpt.png", "rootmaw": "rootmaw_lizard_portrait_chatgpt.png",
            "tyrannosaur": "tyrannosaur_portrait_chatgpt.png", "mound_turtle": "mound_turtle_portrait_chatgpt.png"}
# HAUL (the Rootmaw walking full; its swollen body stands about HAUL_UP times as tall as the thin walk)
HAUL_UP = 1.3
OPTIONAL = {"rootmaw": [("rootmaw_lizard_haul_%s_chatgpt.png" % d, [("haul", d)], (0, 0), HAUL_UP)
                        for d in ["se", "s", "e", "ne", "n"]]}
# THE ROOTED TYRANNOSAUR (the owner, 15:45: rooted he becomes the Brood's barracks): the FERTILISING figure of his
# concept sheet (its right half: head lowered, breathing fire-gold onto a nest of red eggs), nest and sparks included,
# cut out as his one rooted frame. NEST_BOX: the figure's box on the concept sheet (x0, y0, x1, y1; the label under it
# left out); STAND_BOX: the STANDING figure beside it, which sets the scale (as wide as his east walk in game).
CONCEPT_T = "tyrannosaur_concept_chatgpt.png"
NEST_BOX = (790, 40, 1536, 598)
STAND_BOX = (0, 30, 790, 600)
# Sheets the owner asked ChatGPT for (imported when they land; until then the code animates the still frames):
#  - the rooted Tyrannosaur: rows rooting 5, fertilising loop 6, uprooting 5 (scaled so his standing first frame is as
#    tall as his south-east walk, lined up on his feet);
#  - the Rootmaw rooted and breathing, one sheet per food stage, 3 frames each (MAW_STAGES; the owner's numbers in the
#    names are guesses): each sheet is given to the stage of the original filling row it matches best (shape and share
#    of glowing food), scaled to that stage's width: strips fill1_se .. fill6_se; a stage no sheet matches keeps its
#    still frame (breathing in code). (The first try, rootmaw_rooted_breath_se_chatgpt.png, is replaced: its stages 1-5
#    stayed thin.) MAW_DROP: frames left out (stage 1's middle frame grows a big glowing ball a thin stage can't have).
# (the Mother cannot attack while rooted (owner, 15:58): her rooted-swipe sheet, brood_mother_rooted_attack_se_REJECTED.png,
# is not used.)
NEST_SHEET = "tyrannosaur_nest_se_chatgpt.png"
MAW_STAGES = ["rootmaw_breath_stage1_chatgpt.png", "rootmaw_breath_stage2_chatgpt.png", "rootmaw_breath_stage3_chatgpt.png",
              "rootmaw_breath_stage4or5_chatgpt.png", "rootmaw_breath_stage6_chatgpt.png"]
MAW_DROP = {"rootmaw_breath_stage1_chatgpt.png": [1]}
# the Mother laying in her nest (one row of 6; until it comes the game heaves her rooted frame in code)
MOTHER_LAY = "brood_mother_rooted_lay_se_chatgpt.png"
ICONS = "icons_brood_root_uproot_haul_chatgpt.png"
GRUB_SHEET = "grub_harvest_chatgpt.png"         # rows S, SE, E, (a second E: not used), N
GRUB_SHEET_NE = "grub_harvest_ne_chatgpt.png"   # one row: NE


# Sheets that came as JPEG screenshots at odd sizes (the owner, 2026-10-28): soft edges and colour noise in the dark
# background. Their key is taken on a 3x3 median of the sheet (the noise does not pass the tolerance), islands smaller
# than ISLAND source pixels are dropped (speckle), and the dark navy fringe JPEG leaves round the outline is peeled off
# (FRINGE passes: an outline pixel that is dark and near the background goes).
JPEG_SHEETS = {"mound_turtle_s_walk_chatgpt.png", "mound_turtle_ne_walk_chatgpt.png", "mound_turtle_n_walk_chatgpt.png"}
ISLAND = 60
FRINGE = 3


def key_mask(px, jpeg=False):
    rgb = px[..., :3].astype(int)
    if jpeg:
        rgb = ndimage.median_filter(rgb, size=(3, 3, 1))
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3), rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
    bg = np.median(border, 0)
    d = np.abs(rgb - bg).sum(-1)
    fg = d > KEY
    # the soft navy drop shadow under the feet: dark, bluish, not far from the background
    v = rgb.max(-1)
    shadow = (v < 70) & (rgb[..., 2] >= rgb[..., 0]) & (d < KEY * 2.2)
    fg &= ~shadow
    fg = ndimage.binary_opening(fg, iterations=1)
    # pockets of background inside a drawing (its dark shading) go back in
    holes = ndimage.binary_fill_holes(fg) & ~fg
    lab, n = ndimage.label(holes)
    if n:
        sz = ndimage.sum(holes, lab, range(1, n + 1))
        small = np.zeros(n + 1, bool)
        small[1:] = sz < HOLE
        fg |= small[lab] & (lab > 0)
    if jpeg:
        lab, n = ndimage.label(fg)
        if n:
            sz = ndimage.sum(fg, lab, range(1, n + 1))
            keep = np.zeros(n + 1, bool)
            keep[1:] = sz >= ISLAND
            fg = keep[lab]
        v = px[..., :3].astype(int).max(-1)
        draw = np.abs(px[..., :3].astype(int) - bg).sum(-1)
        for _ in range(FRINGE):
            edge = fg & ~ndimage.binary_erosion(fg)
            fg &= ~(edge & (v < 90) & (draw < KEY * 2.5))
    return fg


def sheet_rows(path):
    px = ia.load(R + path)
    fg = key_mask(px, path in JPEG_SHEETS)
    big = max(2500, int(fg.sum() * 0.012))
    sprites = ia.components(fg, 4, min_big=big, attach_dist=40)
    if not sprites:
        return px, []
    # a piece much smaller than the frames (a food blob held out, a splash): it goes with the nearest frame
    top = max(s["area"] for s in sprites)
    big_ones = [s for s in sprites if s["area"] >= top * 0.3]
    for s in sprites:
        if s["area"] >= top * 0.3:
            continue
        def gap(o):
            dy = max(o["y0"] - s["y1"], 0, s["y0"] - o["y1"])
            dx = max(o["x0"] - s["x1"], 0, s["x0"] - o["x1"])
            return dx * dx + dy * dy
        i = min(range(len(big_ones)), key=lambda j: gap(big_ones[j]))
        big_ones[i] = _piece(big_ones[i]["mask"] | s["mask"])
    sprites = split_tall(big_ones)
    # rows by the frames' feet; a sheet whose rows' feet wander (the turtle's last uprooting frame stands up, its feet
    # nearer the next row's) is cut into its known number of rows (ROW_BY_MIDDLE) at the widest gaps between the frames'
    # middles
    if path in ROW_BY_MIDDLE:
        cys = np.array([s["cy"] for s in sprites])
        order = list(np.argsort(cys))
        gaps = sorted(range(len(order) - 1), key=lambda i: cys[order[i + 1]] - cys[order[i]], reverse=True)[:ROW_BY_MIDDLE[path] - 1]
        groups, cur = [], []
        for i, o in enumerate(order):
            cur.append(o)
            if i in gaps:
                groups.append(cur)
                cur = []
        groups.append(cur)
    else:
        groups = ia.cluster_1d(np.array([s["y1"] for s in sprites]), 80)
    rows = [sorted([sprites[i] for i in g], key=lambda s: s["cx"]) for g in groups]
    rows = [split_wide(r) for r in rows]
    rows.sort(key=lambda r: np.mean([s["cy"] for s in r]))
    return px, rows


def _piece(mask):
    ys, xs = np.nonzero(mask)
    return {"mask": mask, "y0": ys.min(), "y1": ys.max() + 1, "x0": xs.min(), "x1": xs.max() + 1,
            "cy": (ys.min() + ys.max()) / 2, "cx": (xs.min() + xs.max()) / 2, "area": len(ys)}


def split_tall(sprites):
    """Two frames of neighbouring rows joined by a bubble or a splash (one piece about twice as tall as the others): cut
    where the rows are emptiest round its middle."""
    if len(sprites) < 3:
        return sprites
    med = float(np.median([sp["y1"] - sp["y0"] for sp in sprites]))
    out = []
    for sp in sprites:
        h = sp["y1"] - sp["y0"]
        if h > med * 1.7:
            prof = sp["mask"][sp["y0"]:sp["y1"]].sum(1).astype(float)
            lo, hi = int(h * 0.3), int(h * 0.7)
            cut = sp["y0"] + lo + int(np.argmin(prof[lo:hi]))
            for a0, b0 in ((sp["y0"], cut), (cut, sp["y1"])):
                m = sp["mask"].copy()
                m[:a0] = False
                m[b0:] = False
                if m.any():
                    out.append(_piece(m))
        else:
            out.append(sp)
    return out


def split_wide(row):
    """Two frames joined by a spray or a claw (one piece about twice as wide as the others): cut where the columns are
    emptiest round its middle."""
    if len(row) < 3:
        return row
    med = float(np.median([s["x1"] - s["x0"] for s in row]))
    out = []
    for s in row:
        w = s["x1"] - s["x0"]
        if w > med * 1.6:
            n = int(round(w / med))
            col = s["mask"][:, s["x0"]:s["x1"]].sum(0).astype(float)
            cuts = []
            for k in range(1, n):
                g = int(w * k / n)
                lo, hi = max(1, g - int(med * 0.3)), min(w - 1, g + int(med * 0.3))
                cuts.append(s["x0"] + lo + int(np.argmin(col[lo:hi])))
            edges = [s["x0"]] + cuts + [s["x1"]]
            for a, b in zip(edges[:-1], edges[1:]):
                m = s["mask"].copy()
                m[:, :a] = False
                m[:, b:] = False
                if m.any():
                    out.append(_piece(m))
        else:
            out.append(s)
    return sorted(out, key=lambda s: s["cx"])


def snap_jpeg(img):
    """ia.snap_team for a JPEG sheet: JPEG smears the red spikes' colour into their neighbours (orange-brown edges), so
    a less pure red still counts as team colour (green at most 0.45 of the red, not 0.3)."""
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    red = (img[..., 3] > 0) & (r >= 95) & (g <= r * 0.45) & (b <= r * 0.45)
    light = red & (r >= 175)
    img[light, :3] = ia.TEAM_LIGHT
    img[red & ~light, :3] = ia.TEAM_DARK
    return img


def shrink2(img, sx, sy):
    """ia.shrink with its own vertical scale (a sheet drawn too tall is squashed)."""
    if abs(sx - sy) < 1e-6:
        return ia.shrink(img, sx)
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * sx))), max(1, int(round(h * sy)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.45, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def anchor_of(im):
    a = im[..., 3] > 0
    ys, xs = np.nonzero(a)
    return float(xs.mean()), float(ys.max())


def load_kind(kind, sheets, required=True):
    out = {}
    for spec in sheets:
        f, rowspec, ref, fudge = spec
        if not os.path.exists(R + f):
            if required:
                sys.exit(f"missing sheet {R + f}")
            continue
        px, rows = sheet_rows(f)
        print(f"  {f}: rows {[len(r) for r in rows]}")
        if len(rows) < len([r for r in rowspec if r is not None]):
            print(f"  ! {f}: found {len(rows)} rows, expected {len(rowspec)}")
        cut = [[ia.cutout(px, s) for s in r] for r in rows]
        out[f] = (cut, rowspec, ref, fudge)
    return out


def import_kind(kind, data, contact_dir):
    sheets = SHEETS[kind] + OPTIONAL.get(kind, [])
    raw = load_kind(kind, SHEETS[kind])
    raw.update(load_kind(kind, OPTIONAL.get(kind, []), required=False))
    # the creature's height from the south-east walk
    se_cut = raw[SHEETS[kind][0][0]][0]
    w0 = se_cut[0][0].shape[1]
    h0 = se_cut[0][0].shape[0]
    base = TARGET_W[kind] / w0
    H = h0 * base
    small = {}
    width_in_game = {}
    for f, rowspec, ref, fudge in sheets:
        if f not in raw:
            continue
        cut = raw[f][0]
        r0, i0 = ref
        refimg = cut[r0][i0]
        scale = H * fudge / refimg.shape[0] if f != SHEETS[kind][0][0] else base
        squash = 1.0
        if f in SHEET_FIT:
            other, squash = SHEET_FIT[f]
            scale = width_in_game[other] / refimg.shape[1]
        width_in_game[f] = refimg.shape[1] * scale
        row0_w = np.mean([im.shape[1] for im in cut[0]])
        for ri, spec in enumerate(rowspec):
            if spec is None or ri >= len(cut):
                continue
            anim, d = spec[0], spec[1]
            imgs = cut[ri]
            sc = scale
            if f in ROW_EVEN:
                sc = scale * row0_w / np.mean([im.shape[1] for im in imgs])
            if len(spec) > 2:
                imgs = [imgs[i] for i in spec[2] if i < len(imgs)]
            snap = snap_jpeg if f in JPEG_SHEETS else ia.snap_team
            small[(anim, d)] = [snap(shrink2(im, sc, sc * squash)) for im in imgs]
    # a walk drawn in two rows (the turtle's south walk: 2 x 3): one strip
    for d in ["s", "se", "e", "ne", "n"]:
        if (("walk", d + "2")) in small:
            small[("walk", d)] = small.get(("walk", d), []) + small.pop(("walk", d + "2"))
    # standing: the first walk frame in each direction (the rooted Queen and Rootmaw have their own strips)
    for d in ["s", "se", "e", "ne", "n"]:
        if ("walk", d) in small:
            small[("idle", d)] = small[("walk", d)][:1]
    rooted_extras(kind, small)
    # the glow the game pulses over a rooted creature's food, eggs and breath (glow_<strip>: the same frames, only the
    # glowing pixels; drawn added on, Unit sprite "Glow")
    for key in [("rooted", "se"), ("fill", "se"), ("lay", "se")] + [("fill%d" % i, "se") for i in range(1, 7)]:
        if key in small:
            small[("glow_" + key[0], key[1])] = [glow_of(kind, im) for im in small[key]]
    assemble(kind, small, data)
    if contact_dir:
        contact(contact_dir, kind, small)


def assemble(name, small, data):
    feet = {}
    L = R_ = U = D = 0
    for key, lst in small.items():
        for k, im in enumerate(lst):
            # (a glow strip sits exactly on its strip's frames)
            bk = (key[0][len("glow_"):], key[1]) if key[0].startswith("glow_") else key
            base = small.get(bk) if key[0].startswith("glow_") else None
            ax, ay = FEET.get((bk, k)) or anchor_of(base[k] if base else im)
            feet[(key, k)] = (ax, ay)
            L = max(L, ax); R_ = max(R_, im.shape[1] - ax); U = max(U, ay); D = max(D, im.shape[0] - ay)
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    Hh = top + int(np.ceil(D)) + 1
    counts = {}
    os.makedirs(f"{ia.OUT}/units/{name}", exist_ok=True)
    keep = {f"{a}_{d}.png" for (a, d) in small}
    for f in os.listdir(f"{ia.OUT}/units/{name}"):
        base = f[:-len(".import")] if f.endswith(".png.import") else f
        if base.endswith(".png") and base not in keep:
            os.remove(f"{ia.OUT}/units/{name}/{f}")      # (a strip no longer made; the others keep their .import)
    for (anim, d), lst in small.items():
        strip = np.zeros((Hh, W * len(lst), 4), np.uint8)
        for k, im in enumerate(lst):
            ax, ay = feet[((anim, d), k)]
            ox, oy = int(round(half - ax)), int(round(top - ay))
            h, w = im.shape[:2]
            ys0, xs0 = max(0, oy), max(0, ox)
            ys1, xs1 = min(Hh, oy + h), min(W, ox + w)
            src = im[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
            m = src[..., 3] > 0
            cell = strip[:, k * W:(k + 1) * W]
            cell[ys0:ys1, xs0:xs1][m] = src[m]
        ia.save(strip, f"{ia.OUT}/units/{name}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(lst)
    data[name] = {"cell": (W, Hh), "anchor": (half, top), "frames": counts}
    print(f"  {name}: cell {W}x{Hh}, " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


def _snap_body(im, keep_box):
    """Team colour on the body's red spikes but not inside keep_box (fractions x0, y0, x1, y1 of the frame): the red
    eggs and the fire stay as drawn."""
    snapped = ia.snap_team(im.copy())
    h, w = im.shape[:2]
    for x0, y0, x1, y1 in keep_box:
        a, b, c, d = int(w * x0), int(h * y0), int(w * x1), int(h * y1)
        snapped[b:d, a:c] = im[b:d, a:c]
    return snapped


# the parts of the rooted Tyrannosaur's frame left as drawn (the breath under his jaws, the nest of red eggs)
NEST_KEEP = [(0.50, 0.53, 0.82, 0.80), (0.30, 0.68, 1.0, 1.0)]
# (the nest sheet's frames: the nest fills their lower 40% from a fifth of the way in; the breath runs from his jaws)
NEST_KEEP_SHEET = [(0.2, 0.6, 1.0, 1.0), (0.55, 0.45, 0.95, 0.6)]


FEET = {}      # ((anim, dir), frame) -> (x, y) anchor: frames lined up on the creature's feet (assemble)


def claw_feet(im):
    """Where a Tyrannosaur frame stands: the middle of his green body (columns) and its lowest rows (his feet), so
    frames line up on him, not on his nest (the last uprooting frame stands beside the empty mud ring). The brown mud,
    the red eggs and the yellow fire are not counted."""
    rgb = im[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    body = (im[..., 3] > 0) & (g >= r * 0.85) & (g > b * 1.4) & (g > 40)
    ys, xs = np.nonzero(body)
    if len(xs) < 50:
        return anchor_of(im)
    return float(xs.mean()), float(np.percentile(ys, 99.5))


def rooted_extras(kind, small):
    """The rooted frames that don't come from the creature's own sheets: the Tyrannosaur's nest (the owner's nest sheet,
    else his concept's FERTILISING figure) and the Rootmaw's breathing food levels (the owner's sheet's rows, each used
    only for a level it matches: MAW_MATCH)."""
    if kind == "tyrannosaur":
        if os.path.exists(R + NEST_SHEET):
            # rooting 5, fertilising 6, uprooting 5; scaled so his standing first frame is as tall as his south-east
            # walk's (the same body size), lined up on his feet
            npx, rows = sheet_rows(NEST_SHEET)
            print(f"  {kind}: nest sheet rows {[len(r) for r in rows]}")
            ref = ia.cutout(npx, rows[0][0])
            want = small[("walk", "se")][0].shape[0]
            sc = want / float(ref.shape[0])
            for name, row in zip(["root", "rooted", "uproot"], rows[:3]):
                fr = [_snap_body(ia.shrink(ia.cutout(npx, sp), sc), NEST_KEEP_SHEET) for sp in row]
                small[(name, "se")] = fr
                for k, im in enumerate(fr):
                    FEET[((name, "se"), k)] = claw_feet(im)
            lo = small[("rooted", "se")][0]
            fx, fy = FEET[(("rooted", "se"), 0)]
            # the nest's eggs: the middle of the red-orange pixels in the lower right, from his feet (BroodNew.NEST_AT)
            rgb = lo[..., :3].astype(int)
            hh, ww = rgb.shape[:2]
            yy, xx = np.mgrid[0:hh, 0:ww]
            egg = (lo[..., 3] > 0) & (rgb[..., 0] > 150) & (rgb[..., 1] < 140) & (yy > hh * 0.6) & (xx > ww * 0.3)
            ys, xs = np.nonzero(egg)
            print(f"  {kind}: scale {sc:.3f}; rooted {ww}x{hh}; the nest's eggs at ({xs.mean() - fx:.0f}, {ys.mean() - fy:.0f}) from his feet")
        else:
            px = ia.load(R + CONCEPT_T)
            fg = key_mask(px)
            def biggest(box):
                x0, y0, x1, y1 = box
                m = np.zeros_like(fg)
                m[y0:y1, x0:x1] = fg[y0:y1, x0:x1]
                sp = ia.components(m, 4, min_big=20000, attach_dist=30)
                return max(sp, key=lambda o: o["area"])
            stand = biggest(STAND_BOX)
            nest = biggest(NEST_BOX)
            e_w = small[("walk", "e")][0].shape[1] if ("walk", "e") in small else TARGET_W[kind]
            sc = e_w / float(stand["x1"] - stand["x0"])
            frame = ia.shrink(ia.cutout(px, nest), sc)
            small[("rooted", "se")] = [_snap_body(frame, NEST_KEEP)]
            print(f"  {kind}: rooted (concept) {frame.shape[1]}x{frame.shape[0]} (scale {sc:.3f})")
    if kind == "rootmaw" and ("fill", "se") in small:
        maw_stages(small)
    if kind == "brood_mother" and os.path.exists(R + MOTHER_LAY) and ("rooted", "se") in small:
        mother_lay(small)


def nest_box(im):
    """A rooted frame's nest: the columns of its lowest 25% (the mud ring): (middle column, width, lowest row)."""
    a = im[..., 3] > 0
    ys, xs = np.nonzero(a)
    y1 = ys.max()
    band = a[int(y1 - (y1 - ys.min()) * 0.25):y1 + 1]
    bx = np.nonzero(band.any(0))[0]
    return (bx.min() + bx.max()) / 2.0, float(bx.max() - bx.min() + 1), float(y1)


def mother_lay(small):
    """Her laying in the nest (MOTHER_LAY, one row of 6): scaled so its resting first frame covers as much as her rooted
    loop's (the same body size), and lined up on the nest (the nest never shifts against the rooted loop); prints where frame 6 draws the new egg (BroodNew
    LAY_EGG_AT: the game's egg takes over there)."""
    npx, rows = sheet_rows(MOTHER_LAY)
    if not rows:
        return
    cut = [ia.cutout(npx, sp) for sp in rows[0]]
    rf = small[("rooted", "se")][0]
    rcx, rw, ry = nest_box(rf)
    rax, ray = anchor_of(rf)
    sc = float(np.median([rw / nest_box(c)[1] for c in cut]))
    # (her body drawn bigger against the nest than in the rooted loop: the rest frame's area matched to the loop's,
    # so she does not swell when she starts to lay)
    a0 = float((ia.shrink(cut[0], sc)[..., 3] > 0).sum())
    sc *= float(np.sqrt((rf[..., 3] > 0).sum() / a0))
    fr = [ia.snap_team(ia.shrink(c, sc)) for c in cut]
    small[("lay", "se")] = fr
    for k, im in enumerate(fr):
        cx, w, y1 = nest_box(im)
        # the same place for the nest as in the rooted frame: its anchor that far from the nest's middle and bottom
        FEET[(("lay", "se"), k)] = (cx + (rax - rcx), y1 + (ray - ry))
    # the new egg in frame 6: the biggest bright yellow-green blob that frame 1 hasn't got
    def bright(im):
        rgb = im[..., :3].astype(int)
        return (im[..., 3] > 0) & (rgb[..., 1] > 170) & (rgb[..., 0] > 120) & (rgb[..., 2] < 140)
    def placed(k):
        # (the frame as assemble lays it on the cell: its anchor at a common point)
        ax, ay = FEET[(("lay", "se"), k)]
        return fr[k], ax, ay
    f6, ax6, ay6 = placed(len(fr) - 1)
    f1, ax1, ay1 = placed(0)
    big = np.zeros((f6.shape[0] + f1.shape[0] + 400, f6.shape[1] + f1.shape[1] + 400), bool)
    def stamp(m, ax, ay):
        out = np.zeros_like(big)
        oy, ox = int(round(big.shape[0] / 2 - ay)), int(round(big.shape[1] / 2 - ax))
        out[oy:oy + m.shape[0], ox:ox + m.shape[1]] = m
        return out
    new = stamp(bright(f6), ax6, ay6) & ~ndimage.binary_dilation(stamp(bright(f1), ax1, ay1), iterations=1)
    lab, n = ndimage.label(ndimage.binary_closing(new, iterations=2))
    if n:
        sz = ndimage.sum(new, lab, range(1, n + 1))
        ys, xs = np.nonzero(lab == int(np.argmax(sz)) + 1)
        print("  brood_mother: laying in the nest, %d frames (scale %.3f); the new egg in frame 6: middle (%.0f, %.0f), bottom %.0f from her anchor" % (
            len(fr), sc, xs.mean() - big.shape[1] / 2, ys.mean() - big.shape[0] / 2, np.percentile(ys, 97) - big.shape[0] / 2))


def _frames3(path):
    """A breathing sheet's frames: its three biggest pieces, left to right (a black bar some screenshots have along the
    edge is left out: pieces touching the sheet's edge)."""
    npx, rows = sheet_rows(path)
    hh, ww = npx.shape[:2]
    pieces = [sp for r in rows for sp in r if sp["x0"] > 2 and sp["y0"] > 2 and sp["x1"] < ww - 2 and sp["y1"] < hh - 2]
    pieces = sorted(sorted(pieces, key=lambda sp: -sp["area"])[:3], key=lambda sp: sp["cx"])
    return [ia.cutout(npx, sp) for sp in pieces]


def maw_stages(small):
    levels = small[("fill", "se")]
    want = []
    for lv in levels:
        w, h = _box(lv)
        want.append((h / float(w), food_share(lv), w))
    have = []
    for f in MAW_STAGES:
        if not os.path.exists(R + f):
            continue
        fr = _frames3(f)
        fr = [im for k, im in enumerate(fr) if k not in MAW_DROP.get(f, [])]
        w, h = _box(fr[0])
        probe = ia.shrink(fr[0], 90.0 / w)
        have.append((f, fr, h / float(w), food_share(probe)))
    if not have:
        return
    # the assignment with the least total mismatch (aspect and food share), each sheet to its own stage
    import itertools
    def cost(hv, st):
        return abs(hv[2] - want[st][0]) * 4.0 + abs(hv[3] - want[st][1]) * 8.0
    best = None
    for perm in itertools.permutations(range(len(levels)), len(have)):
        c = sum(cost(have[i], st) for i, st in enumerate(perm))
        if best is None or c < best[0]:
            best = (c, perm)
    notes = []
    for i, st in enumerate(best[1]):
        f, fr, a, fs = have[i]
        sc = want[st][2] / float(_box(fr[0])[0])
        small[("fill%d" % (st + 1), "se")] = [ia.snap_team(ia.shrink(im, sc)) for im in fr]
        notes.append("%s -> stage %d (%d frames; its aspect %.2f, food %.3f; the stage's %.2f, %.3f)" % (
            f.replace("rootmaw_breath_", "").replace("_chatgpt.png", ""), st + 1, len(fr), a, fs, want[st][0], want[st][1]))
    missing = [st + 1 for st in range(len(levels)) if st not in best[1]]
    print("  rootmaw: breathing: " + "; ".join(notes) + "; still frame (code breathing): stage %s" % missing)


# a breathing row is used for a Rootmaw food level only when, scaled to the level's width, its height is within 5% and
# its share of glowing food within 2 points of the level's own frame
MAW_MATCH = {"height": 0.05, "food": 0.02}


def _box(im):
    ys, xs = np.nonzero(im[..., 3] > 0)
    return xs.max() - xs.min() + 1, ys.max() - ys.min() + 1


def food_share(im):
    rgb = im[..., :3].astype(int)
    a = im[..., 3] > 0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = a & (g > 140) & (r > 100) & (b < 120) & (g >= r * 0.85)
    return m.sum() / max(1, a.sum())


def glow_of(kind, im):
    """Only the glowing pixels of a rooted frame (the Mother's and the Rootmaw's yellow-green food and eggs, the
    Tyrannosaur's fire and red eggs), a pixel's halo round them; the game adds it over the frame with a slow pulse."""
    rgb = im[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    a = im[..., 3] > 0
    key = ((r == 255) & (g == 0) & (b == 0)) | ((r == 150) & (g == 0) & (b == 0))
    if kind == "tyrannosaur":
        h, w = r.shape
        yy, xx = np.mgrid[0:h, 0:w]
        zone = (yy > h * 0.45) & (xx > w * 0.3)
        m = a & ~key & zone & (r > 170) & (g > 40) & (b < 140)
    else:
        m = a & ~key & (g > 140) & (r > 100) & (b < 120) & (g >= r * 0.85)
    soft = ndimage.gaussian_filter(m.astype(float), 0.8)
    out = np.zeros_like(im)
    col = np.where(m[..., None], rgb, 0)
    # (the colour spread into the halo: the mean colour of the glowing pixels round each)
    for c in range(3):
        num = ndimage.gaussian_filter(col[..., c].astype(float), 0.8)
        out[..., c] = np.clip(num / np.maximum(soft, 1e-3), 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(soft * 255 * 1.4, 0, 255).astype(np.uint8)
    out[out[..., 3] < 8] = 0
    return out


def write_entry(name, e):
    path = "scripts/art_data.gd"
    src = open(path).read()
    lines = [f'\t"{name}": {{"cell": Vector2i({e["cell"][0]}, {e["cell"][1]}), "anchor": Vector2({e["anchor"][0]}, {e["anchor"][1]}), "frames": {{\n']
    for k in sorted(e["frames"]):
        lines.append(f'\t\t"{k}": {e["frames"][k]},\n')
    lines.append("\t}},\n")
    entry = "".join(lines)
    pat = re.compile(r'\t"' + name + r'": \{.*?\n\t\}\},\n', re.S)
    if pat.search(src):
        src = pat.sub(lambda m: entry, src, count=1)
    else:
        start = src.index("const BASE_UNITS := {")
        end = src.index("\n}\n", start) + 1
        src = src[:end] + entry + src[end:]
    open(path, "w").write(src)


def portrait(kind):
    px = ia.load(R + PORTRAIT[kind])
    h, w = px.shape[:2]
    s = min(h, w)
    crop = px[(h - s) // 2:(h - s) // 2 + s, (w - s) // 2:(w - s) // 2 + s].astype(np.uint8)
    img = Image.fromarray(crop).convert("RGB").resize((60, 60), Image.LANCZOS)
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (70, 74, 72)
    icon[..., 3] = 255
    icon[2:62, 2:62, :3] = np.array(img)
    ia.save(ia.unteam(icon), f"{ia.OUT}/icons/{kind}.png")


def command_icons():
    """ROOT, UPROOT and HAUL: the owner's three framed icons (ICONS, left to right), cut on their frames and shrunk to
    the 64 px button. Named ab_nb_root / ab_uproot / ab_haul so the old Brood's Spore Mother keeps its own ROOT icon."""
    px = ia.load(R + ICONS)
    fg = key_mask(px)
    sprites = ia.components(fg, 3, min_big=20000, attach_dist=0)
    sprites = sorted([s for s in sprites if s["area"] > 20000], key=lambda s: s["cx"])[:3]
    for s, name in zip(sprites, ["ab_nb_root", "ab_uproot", "ab_haul"]):
        crop = px[s["y0"]:s["y1"], s["x0"]:s["x1"]].astype(np.uint8)
        img = Image.fromarray(crop).convert("RGB").resize((64, 64), Image.BOX)
        out = np.zeros((64, 64, 4), np.uint8)
        out[..., :3] = np.array(img)
        out[..., 3] = 255
        ia.save(ia.unteam(out), f"{ia.OUT}/icons/brood/{name}.png")
    print(f"  icons: {len(sprites)} cut (ab_nb_root, ab_uproot, ab_haul)")


def _grub_frames(px, row, scale):
    return [ia.snap_team(ia.shrink(ia.cutout(px, s), scale)) for s in row]


def grub_harvest():
    """The grub taking food from a Rootmaw's flank (GRUB_SHEET: rows S, SE, E, a second E not used, N; GRUB_SHEET_NE:
    NE; 5 frames: mouth open, at the flank, the food coming out, held, held). Each row is scaled so its first frame is as
    tall as the grub's own idle in that view (the NE grub stands up a little: its row is scaled by its body's width
    instead), set on the grub's cell with the feet on its anchor, and written as harvest_<dir> strips (west mirrored by
    the game); the grub's entry in art_data gets the strips."""
    px, rows = sheet_rows(GRUB_SHEET)
    pxn, rows_ne = sheet_rows(GRUB_SHEET_NE)
    print(f"  {GRUB_SHEET}: rows {[len(r) for r in rows]}, {GRUB_SHEET_NE}: rows {[len(r) for r in rows_ne]}")
    if len(rows) < 5 or not rows_ne:
        print("  ! grub harvest: rows missing")
        return
    src = open("scripts/art_data.gd").read()
    m = re.search(r'\t"grub": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    cw, ch, axx, ayy = int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(4))

    def size_of(strip):
        im = np.array(Image.open(f"{ia.OUT}/units/grub/{strip}.png").convert("RGBA"))
        n = im.shape[1] // cw
        ws = []
        hs = []
        for k in range(n):
            ys, xs = np.nonzero(im[:, k * cw:(k + 1) * cw, 3] > 0)
            hs.append(ys.max() - ys.min() + 1)
            ws.append(xs.max() - xs.min() + 1)
        return float(np.median(hs)), float(np.median(ws))

    # one scale for the whole five-row sheet (from its front view against the grub's idle_s); the NE sheet by the
    # width of the grub's own north-east walk
    s_ref = ia.cutout(px, rows[0][0])
    main_scale = size_of("idle_s")[0] / s_ref.shape[0]
    ne_ref = ia.cutout(pxn, rows_ne[0][0])
    ne_scale = size_of("walk_ne")[1] / ne_ref.shape[1]
    sets = {"s": (px, rows[0]), "se": (px, rows[1]), "e": (px, rows[2]), "n": (px, rows[4]), "ne": (pxn, rows_ne[0])}
    counts = {}
    for d, (p, row) in sets.items():
        scale = ne_scale if d == "ne" else main_scale
        frames = _grub_frames(p, row, scale)
        strip = np.zeros((ch, cw * len(frames), 4), np.uint8)
        for k, im in enumerate(frames):
            yy, xx = np.nonzero(im[..., 3] > 0)
            low = yy >= yy.max() - 3
            ax = float(np.median(xx[low])) if low.any() else float(xx.mean())
            ox, oy = int(round(axx - ax)), int(round(ayy - yy.max()))
            h, w = im.shape[:2]
            ys0, xs0 = max(0, oy), max(0, ox)
            ys1, xs1 = min(ch, oy + h), min(cw, ox + w)
            sub = im[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
            mm = sub[..., 3] > 0
            cell = strip[:, k * cw:(k + 1) * cw]
            cell[ys0:ys1, xs0:xs1][mm] = sub[mm]
        ia.save(strip, f"{ia.OUT}/units/grub/harvest_{d}.png")
        counts[f"harvest_{d}"] = len(frames)
    a = src.index('\t"grub": {')
    b = src.index("\n\t}},\n", a)
    body = re.sub(r'\n\t\t"harvest_\w+": \d+,', "", src[a:b])
    for k in sorted(counts):
        body += f'\n\t\t"{k}": {counts[k]},'
    open("scripts/art_data.gd", "w").write(src[:a] + body + src[b:])
    print("  grub: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


EGG_SHEET = "brood_egg_chatgpt.png"      # row 1: 5 pulse frames (waiting), row 2: 5 hatching frames (ending on the open shell)
PILE_SHEET = "food_pile_chatgpt.png"    # 4 frames: fresh to almost gone (rotted)
EGG_H = 22                              # game px: the egg with its dirt about one grub tall
PILE_W = 72                             # game px: the fresh pile about a Rootmaw wide


def _drop_loose(im, keep_below=0.55):
    """Small loose bits above the egg's middle (the yellow motion arcs drawn at the top right of the 4th pulse frame) go;
    the egg and the dirt crumbs at its foot stay."""
    a = im[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n <= 1:
        return im
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    h = im.shape[0]
    out = im.copy()
    for i in range(1, n + 1):
        if i == big:
            continue
        ys = np.nonzero(lab == i)[0]
        if ys.mean() < h * keep_below:
            out[lab == i] = 0
    return out


def still_art():
    """The egg and the food pile from the owner's sheets (EGG_SHEET, PILE_SHEET). The egg: idle_s the waiting pulse,
    hatch_s the hatching (the game puts the creature on the open shell and tints a fertilised egg red), death_s the
    broken shell (the hatch's last three frames) when one is killed. The pile: idle_s, four frames from fresh to
    rotted (the game picks the one that matches what is left and what has rotted)."""
    data = {}
    px, rows = sheet_rows(EGG_SHEET)
    if len(rows) < 2:
        sys.exit("brood egg sheet: expected 2 rows")
    ref = ia.cutout(px, rows[0][0])
    scale = EGG_H / ref.shape[0]
    pulse = [ia.unteam(ia.shrink(_drop_loose(ia.cutout(px, sp)), scale)) for sp in rows[0]]
    hatch = [ia.unteam(ia.shrink(ia.cutout(px, sp), scale)) for sp in rows[1]]
    small = {("idle", "s"): pulse, ("hatch", "s"): hatch, ("death", "s"): hatch[2:]}
    _place("brood_egg", small, data)
    pp, prow = sheet_rows(PILE_SHEET)
    piles = [ia.cutout(pp, sp) for sp in prow[0]]
    pscale = PILE_W / piles[0].shape[1]
    small = {("idle", "s"): [ia.unteam(ia.shrink(im, pscale)) for im in piles]}
    small[("death", "s")] = small[("idle", "s")][-1:]
    _place("food_pile", small, data)
    for k, v in data.items():
        write_entry(k, v)
    print("  brood_egg, food_pile from the owner's sheets")


def _place(name, small, data):
    """One canvas, each frame's bottom on the anchor line and its middle (columns) on the anchor column."""
    L = R_ = U = D = 0
    feet = {}
    for key, lst in small.items():
        for k, im in enumerate(lst):
            ys, xs = np.nonzero(im[..., 3] > 0)
            ax, ay = (xs.min() + xs.max()) / 2.0, float(ys.max())
            feet[(key, k)] = (ax, ay)
            L = max(L, ax); R_ = max(R_, im.shape[1] - ax); U = max(U, ay); D = max(D, im.shape[0] - ay)
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    Hh = top + int(np.ceil(D)) + 1
    os.makedirs(f"{ia.OUT}/units/{name}", exist_ok=True)
    keep = {f"{a}_{d}.png" for (a, d) in small}
    for f in os.listdir(f"{ia.OUT}/units/{name}"):
        base = f[:-len(".import")] if f.endswith(".png.import") else f
        if base.endswith(".png") and base not in keep:
            os.remove(f"{ia.OUT}/units/{name}/{f}")      # (a strip no longer made; the others keep their .import)
    counts = {}
    for (anim, d), lst in small.items():
        strip = np.zeros((Hh, W * len(lst), 4), np.uint8)
        for k, im in enumerate(lst):
            ax, ay = feet[((anim, d), k)]
            ox, oy = int(round(half - ax)), int(round(top - ay))
            h, w = im.shape[:2]
            m = im[..., 3] > 0
            strip[oy:oy + h, k * W + ox:k * W + ox + w][m] = im[m]
        ia.save(strip, f"{ia.OUT}/units/{name}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(lst)
    data[name] = {"cell": (W, Hh), "anchor": (half, top), "frames": counts}


def contact(out_dir, kind, small):
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    for key in sorted(small):
        lst = small[key]
        h = max(im.shape[0] for im in lst)
        w = sum(im.shape[1] + 4 for im in lst)
        row = np.zeros((h + 4, w + 4, 4), np.uint8)
        row[..., :3] = (96, 120, 70)
        row[..., 3] = 255
        x = 2
        for im in lst:
            m = im[..., 3] > 0
            row[2:2 + im.shape[0], x:x + im.shape[1]][m] = im[m]
            x += im.shape[1] + 4
        rows.append(row)
    Wd = max(r.shape[1] for r in rows)
    Ht = sum(r.shape[0] for r in rows)
    sheet = np.zeros((Ht, Wd, 4), np.uint8)
    sheet[..., 3] = 255
    y = 0
    for r in rows:
        sheet[y:y + r.shape[0], :r.shape[1]] = r
        y += r.shape[0]
    Image.fromarray(sheet).save(f"{out_dir}/{kind}_contact.png")


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    data = {}
    for kind in SHEETS:
        if only and kind != only:
            continue
        print(kind)
        import_kind(kind, data, contact_dir)
        write_entry(kind, data[kind])
        if os.path.exists(R + PORTRAIT.get(kind, "-")):
            portrait(kind)
        elif kind == "mound_turtle":
            # (no portrait yet: the Clutch Mound's icon on its card meanwhile)
            shutil.copy(f"{ia.OUT}/icons/clutch_mound.png", f"{ia.OUT}/icons/mound_turtle.png")
    if not only:
        command_icons()
        grub_harvest()
        still_art()


if __name__ == "__main__":
    main()
