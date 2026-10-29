#!/usr/bin/env python3
"""Import YOUNG AND MATURE (the owner, 2026-10-29 12:40-14:40; docs/brood_new.md "Young and mature") from the owner's
ChatGPT sheets in art/redraws/: the TYRANT CHALLENGER (kind "tyrant_challenger", a matured Raptor, a young Tyrant Sire;
its sheets are named young_tyrant_*), the VENOM CHALLENGER ("venom_challenger", a matured Spitter, a young Venom Sire),
and the BROOD MOTHER'S STAGE 2 AND 3 art (art keys "brood_mother_2", "brood_mother_3": the game switches her art when she
grows). (The Viper and the Hooded Serpent were dropped by the owner, 14:40; their sheets stay in art/redraws.)

Re-runnable: python3 -I tools/import_brood_mature.py [--contact DIR] [--only NAME]. It uses tools/import_brood_new.py's
steps (the navy background keyed out, frames split, feet on the anchor, the red spikes snapped to the team reds; west
views are the east ones mirrored by the game).

SIZES (game px; the Raptor's south-east walk is 21 tall, the Brute's east walk about 64 tall):
  - TYRANT CHALLENGER: about twice a Raptor: its south-east run TYRANT_H tall; every other view so its first run frame
    covers as much as the south-east one (the north-east, drawn upright and stretched, keeps the same body size).
  - VENOM CHALLENGER: about twice a Spitter (the owner's concept): the Venom Sire scaled to VENOM_SCALE (a young Venom
    Sire) until its own sheets come.
  - THE MOTHER'S STAGES: each stage's art is brought to her STAGE-1 BODY (its south-east walk's first frame covers as
    much as stage 1's); the game still scales her sprite by her stage (Defs.NB "stages" scale: x1.15, x1.3), so stage 2 is
    drawn 1.15x and stage 3 1.3x her stage-1 body, whatever size ChatGPT drew them (no double scaling).

SHEETS
  young_tyrant_<d>_chatgpt.png (d = se, s, e, ne, n): rows run 6 (the SE legs weak), bite 6, death 5. The N sheet is weak
    (from behind every frame nearly the same); used anyway.
  venom_challenger_<d>_chatgpt.png (rows walk, spit, death), picked up by name when the owner's come; until then the
    VENOM SIRE's own sheets (tools/import_brood_fathers.py: walk and spit in every view, his death) at VENOM_SCALE: a
    stand-in (docs/art_style_inconsistency.md).
  brood_mother_stage<N>_se_walk_swipe_death_chatgpt.png: walk 6, swipe 6 (its frame 3 has a paw growing out of her back:
    dropped, frame 2 held twice), death 5; brood_mother_stage<N>_se_nest_chatgpt.png: rooting 5, rooted loop 4 (stage 3:
    5), laying 6, uprooting 5. brood_mother_stage<N>_<d>_walk_swipe_chatgpt.png (d = s, e, ne, n; 0.20.2): walk 6,
    swipe 6, each view at her stage-1 body in that view (mother_views); the north swipes drop frame 4 (MOTHER_DROP).
Portraits: the owner's <kind>_portrait_chatgpt.png when it comes; until then a crop of the concept's head
(young_tyrant_concept_chatgpt.png, venom_challenger_concept_chatgpt.png: a JPEG screenshot).
Prints, for Defs.NB / BroodMature: each stage's rooted art bottom from her feet (nest_y) and where her last laying frame
draws the new egg (lay_egg).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402
import import_brood_fathers as ibf  # noqa: E402

R = ibn.R
DIRS = ["se", "s", "e", "ne", "n"]
TYRANT_H = 42.0
# (the owner's concept, venom_challenger_concept_chatgpt.png: "about twice a Spitter"; the Venom Sire's frames at this
# scale give an east walk about 1.75x the Spitter's length (101 px against 58), a young Sire still clearly smaller than
# the Sire himself)
VENOM_SCALE = 0.8
# with the owner's own five sheets: the east walk's first frame this long, tail to snout (the Spitter 44, the Venom Sire
# 125: "about twice a Spitter", the concept's middle size), and its glob missile's length
VENOM_LEN = 88.0
VENOM_GLOB_LEN = 22.0
# concept heads for the stand-in portraits (x0, y0, x1, y1 on the sheet)
HEADS = {"tyrant_challenger": ("young_tyrant_concept_chatgpt.png", (430, 300, 620, 490)),
         "venom_challenger": ("venom_challenger_concept_chatgpt.png", (695, 190, 875, 370))}


def have(f):
    return os.path.exists(R + f)


def venom(im):
    rgb = im[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (im[..., 3] > 0) & (g > 160) & (b < 110) & (r > 110) & (g > r * 0.9)


def body_area(im):
    """Painted pixels without the bright venom (a spit's stream would count as body)."""
    return float(((im[..., 3] > 0) & ~venom(im)).sum())


def rows_of(f):
    px, rows = ibn.sheet_rows(f)
    print(f"  {f}: rows {[len(r) for r in rows]}")
    return [[ia.cutout(px, s) for s in r] for r in rows]


def shrink_all(imgs, sc):
    return [ia.snap_team(ia.shrink(im, sc)) for im in imgs]


def body_feet(im):
    """Where a frame stands: the body without the venom (and loose droplets), its columns' middle and lowest row."""
    body = (im[..., 3] > 0) & ~venom(im)
    lab, n = ndimage.label(body)
    if n > 1:
        sizes = ndimage.sum(body, lab, range(1, n + 1))
        body = lab == (1 + int(np.argmax(sizes)))
    ys, xs = np.nonzero(body)
    if len(xs) < 20:
        return ibn.anchor_of(im)
    return float(xs.mean()), float(ys.max())


def feet_all(small):
    for key, lst in small.items():
        if key[0] in ("walk", "idle", "attack", "death"):
            for k, im in enumerate(lst):
                ibn.FEET[(key, k)] = body_feet(im)


# ------------------------------------------------------------------ the Tyrant Challenger

def tyrant_challenger(stand_ins):
    small = {}
    rows = rows_of("young_tyrant_se_chatgpt.png")
    sc = TYRANT_H / rows[0][0].shape[0]
    for name, ri in (("walk", 0), ("attack", 1), ("death", 2)):
        if ri < len(rows):
            small[(name, "se")] = shrink_all(rows[ri], sc)
    small[("idle", "se")] = small[("walk", "se")][:1]
    for d in DIRS[1:]:
        f = f"young_tyrant_{d}_chatgpt.png"
        if have(f):
            r2 = rows_of(f)
            # (the same body in every view: its first run frame covers as much as the south-east one; a view drawn
            # upright and stretched, the north-east, comes out at the same body size, not shrunk to the same height)
            s2 = (body_area(small[("walk", "se")][0]) / body_area(r2[0][0])) ** 0.5
            for name, ri in (("walk", 0), ("attack", 1), ("death", 2)):
                if ri < len(r2):
                    small[(name, d)] = shrink_all(r2[ri], s2)
            small[("idle", d)] = small[("walk", d)][:1]
        else:
            stand_ins.append(f"tyrant challenger {d.upper()}: the south-east frames (game fallback) until {f}")
    stand_ins.append("tyrant challenger run SE: the owner's sheet's legs are weak (as he said); kept until a redraw")
    stand_ins.append("tyrant challenger N: the owner's weak sheet (from behind, frames nearly the same); used as drawn")
    feet_all(small)
    return small


# ------------------------------------------------------------------ the Venom Challenger

def venom_challenger(stand_ins):
    """The owner's venom_challenger_<d>_chatgpt.png (walk, spit, death) when they come; else the Venom Sire's frames at
    VENOM_SCALE (his walk, spit and death; not his nest)."""
    own = {d: f"venom_challenger_{d}_chatgpt.png" for d in DIRS if have(f"venom_challenger_{d}_chatgpt.png")}
    small = {}
    if len(own) == len(DIRS):
        # all five of the owner's sheets (2026-10-29): cut as the Spitter's (tools/import_spitter_redo.py): one scale, the
        # east walk VENOM_LEN long; the glob out of spit frame 4 (the game flies its own), the east one straightened
        # into its missile, assets/effects/venom_challenger_glob.png
        import import_spitter_redo as isr
        small, glob = isr.build("venom_challenger", VENOM_LEN)
        isr.write_glob("venom_challenger", glob, VENOM_GLOB_LEN)
        stand_ins.append("venom challenger NE walk: stiff (little leg movement), as drawn; every death ends side-on facing east")
        return small
    if "se" in own:
        rows = rows_of(own["se"])
        sire_w = ibf.TARGET_W["dilophosaurus"] * VENOM_SCALE
        sc = sire_w / rows[0][0].shape[1]
        for d, f in own.items():
            r2 = rows if d == "se" else rows_of(f)
            s2 = sc if d == "se" else (body_area(small[("walk", "se")][0]) / body_area(r2[0][0])) ** 0.5
            for name, ri in (("walk", 0), ("attack", 1), ("death", 2)):
                if ri < len(r2):
                    small[(name, d)] = shrink_all(r2[ri], s2)
            small[("idle", d)] = small[("walk", d)][:1]
        feet_all(small)
        return small
    tw = ibf.TARGET_W["dilophosaurus"]
    ibf.TARGET_W["dilophosaurus"] = tw * VENOM_SCALE
    try:
        sire = ibf.dilophosaurus([])
    finally:
        ibf.TARGET_W["dilophosaurus"] = tw
    for (a, d), lst in sire.items():
        if a in ("walk", "attack", "idle", "death"):
            small[(a, d)] = lst
    # (his nest frames dropped; their feet entries too: assemble lines up only what it is given)
    stand_ins.append("venom challenger: the Venom Sire's walk, spit and death at %d%% until venom_challenger_<d>_chatgpt.png" % int(VENOM_SCALE * 100))
    return small


# ------------------------------------------------------------------ the Brood Mother's stages

def mother_stage1():
    """Her stage-1 frames, as tools/import_brood_new.py makes them (not written again)."""
    got = {}
    orig = ibn.assemble
    ibn.assemble = lambda name, small, data: got.update(small)
    try:
        ibn.import_kind("brood_mother", {}, "")
    finally:
        ibn.assemble = orig
    return got


def nest_bottom(im, feet):
    """The rooted art's bottom from its feet: the lowest row a sixth as wide as the picture (Defs.NB nest_y)."""
    a = im[..., 3] > 0
    rows = np.nonzero(a.sum(1) >= max(3, int(im.shape[1] / 6)))[0]
    return float(rows.max() - feet[1])


def mother_stage(n, s1, stand_ins):
    small = {}
    ws = rows_of(f"brood_mother_stage{n}_se_walk_swipe_death_chatgpt.png")
    ns = rows_of(f"brood_mother_stage{n}_se_nest_chatgpt.png")
    a1 = float((s1[("walk", "se")][0][..., 3] > 0).sum())
    sc = (a1 / float((ws[0][0][..., 3] > 0).sum())) ** 0.5
    small[("walk", "se")] = shrink_all(ws[0], sc)
    small[("idle", "se")] = small[("walk", "se")][:1]
    sw = ws[1]
    sw = [sw[0], sw[1], sw[1]] + sw[3:] if len(sw) >= 6 else sw      # (frame 3: a paw out of her back)
    small[("attack", "se")] = shrink_all(sw, sc)
    small[("death", "se")] = shrink_all(ws[2], sc)
    # the nest sheet: her rooted loop's first frame (her curled body and nest) covers as much as stage 1's rooted frame,
    # so her rooted picture is x1.15 / x1.3 her stage-1 nest in the game (the stage's scale) whatever size the sheet drew
    # her (a first try matched the standing rooting frame to the walk: the stage-2 nest came out 1.4x stage 1's)
    a1r = float((s1[("rooted", "se")][0][..., 3] > 0).sum())
    scn = (a1r / float((ns[1][0][..., 3] > 0).sum())) ** 0.5
    for name, ri in (("root", 0), ("rooted", 1), ("lay", 2), ("uproot", 3)):
        if ri < len(ns):
            small[(name, "se")] = shrink_all(ns[ri], scn)
    print(f"  stage {n}: walk scale {sc:.4f}, nest {scn:.4f} (her body brought to stage 1's; the game scales it by the stage)")
    # the laying row lined up on the nest as her rooted loop (mother_lay's rule), the new egg found in the last frames
    rf = small[("rooted", "se")][0]
    rcx, rw, ry = ibn.nest_box(rf)
    rax, ray = ibn.anchor_of(rf)
    lay = small[("lay", "se")]
    for k, im in enumerate(lay):
        cx, w, y1 = ibn.nest_box(im)
        ibn.FEET[(("lay", "se"), k)] = (cx + (rax - rcx), y1 + (ray - ry))
    egg = lay_egg(lay, n)
    if egg is not None and egg[2] < len(lay) - 1:
        small[("lay", "se")] = lay[:egg[2] + 1]     # (her last frame took the egg back in: end on the frame that shows it)
        print(f"  stage {n}: laying ends on frame {egg[2] + 1} (the egg out)")
    # the other views: the owner's stage sheets (mother_views); a view without its sheet keeps her stage-1 frames
    mother_views(n, s1, small, stand_ins)
    for (a, d), lst in s1.items():
        if d != "se" and (a, d) not in small:
            small[(a, d)] = lst
    for key in [("rooted", "se"), ("lay", "se")]:
        small[("glow_" + key[0], key[1])] = [ibn.glow_of("brood_mother", im) for im in small[key]]
    feet = ibn.anchor_of(small[("rooted", "se")][0])
    print(f"  stage {n}: nest_y {nest_bottom(small[('rooted', 'se')][0], feet):.0f} (the rooted art's bottom from her feet)")
    if egg is not None:
        print(f"  stage {n}: lay_egg: middle ({egg[0]:.0f}, {egg[1]:.0f}), bottom {egg[4]:.0f} from her feet (BroodNew.LAY_EGG: (x, bottom))")
    return small


def _core(im):
    """A frame's body for lining up: the alpha opened (dust specks and thin streaks gone), its biggest piece."""
    a = ndimage.binary_opening(im[..., 3] > 0, iterations=2)
    lab, nn = ndimage.label(a)
    if nn > 1:
        sz = ndimage.sum(a, lab, range(1, nn + 1))
        a = lab == (1 + int(np.argmax(sz)))
    return a


def _drop_specks(im, least=30):
    """Clears the frame's loose pieces smaller than least px (in place)."""
    a = im[..., 3] > 0
    lab, nn = ndimage.label(a, structure=np.ones((3, 3)))
    if nn > 1:
        sz = ndimage.sum(a, lab, range(1, nn + 1))
        for i in range(nn):
            if sz[i] < least:
                im[lab == i + 1] = 0


def _shift_to(ref, im, reach=30):
    """The (dx, dy) that lays frame im best over frame ref (both placed at their top-left): the most shared body,
    searched round the shift that puts their bodies' feet (bottom rows) and middles together."""
    a, b = _core(ref), _core(im)
    ya, xa = np.nonzero(a)
    yb, xb = np.nonzero(b)
    gx, gy = int(round(xa.mean() - xb.mean())), int(ya.max() - yb.max())
    P = reach + 2 + max(abs(gx), abs(gy))
    H = max(a.shape[0], b.shape[0]) + 2 * P
    W = max(a.shape[1], b.shape[1]) + 2 * P
    A = np.zeros((H, W), bool)
    A[P:P + a.shape[0], P:P + a.shape[1]] = a

    def score(dx, dy):
        B = np.zeros((H, W), bool)
        B[P + dy:P + dy + b.shape[0], P + dx:P + dx + b.shape[1]] = b
        return float((A & B).sum()) / float((A | B).sum())

    best, at = -1.0, (gx, gy)
    for dy in range(gy - reach, gy + reach + 1, 2):
        for dx in range(gx - reach, gx + reach + 1, 2):
            s = score(dx, dy)
            if s > best:
                best, at = s, (dx, dy)
    x0, y0 = at
    for dy in range(y0 - 1, y0 + 2):
        for dx in range(x0 - 1, x0 + 2):
            s = score(dx, dy)
            if s > best:
                best, at = s, (dx, dy)
    return at


# the swipe frame (from 0) the NORTH views drop, both stages (the owner: "a strange frame with the tail and earth":
# frame 4, the slam, shows the tail and a dust burst oddly); frame 3 (the claw up) is held in its place, so the paw
# comes down on frame 5, the frame the game shows when the blow lands (9 fps from the start of her 0.5 s aim: index 4)
MOTHER_DROP = {"n": 3}
# the swipe's slam frame (from 0) in every view's sheet: the claw strikes the ground in a dust burst
SLAM = 3


def mother_views(n, s1, small, stand_ins):
    """Her S, E, NE, N walk and swipe at stage n from brood_mother_stage<n>_<d>_walk_swipe_chatgpt.png (rows: walk 6,
    swipe 6; west views are the east ones mirrored by the game). Each view is brought to her STAGE-1 body in that view
    (its first walk frame covers as much as stage 1's), as her south-east is: turning keeps her size as at stage 1 and
    the game scales every view by the stage. (Matching every view to the south-east's area instead made her north and
    south views about 1.5 times taller than the south-east: ChatGPT drew those views long.) Swipe frames are lined up
    on their first frame's body (the raised arm and the dust burst do not move her feet)."""
    for d in ("s", "e", "ne", "n"):
        f = f"brood_mother_stage{n}_{d}_walk_swipe_chatgpt.png"
        if not have(f):
            stand_ins.append(f"brood mother stage {n} {d.upper()}: walk and swipe are her stage-1 frames until {f}")
            continue
        rows = rows_of(f)
        a1 = float((s1[("walk", d)][0][..., 3] > 0).sum())
        sc = (a1 / float((rows[0][0][..., 3] > 0).sum())) ** 0.5
        small[("walk", d)] = shrink_all(rows[0], sc)
        small[("idle", d)] = small[("walk", d)][:1]
        sw = list(rows[1])
        if d in MOTHER_DROP and len(sw) >= 6:
            k = MOTHER_DROP[d]
            sw[k] = sw[k - 1]
        att = shrink_all(sw, sc)
        for k, im in enumerate(att):
            if k != SLAM or d in MOTHER_DROP:
                _drop_specks(im)        # (a stray dust speck beside a frame with no burst)
        small[("attack", d)] = att
        # feet: across, where the frame's body lies best over the first frame's (a raised arm does not slide her);
        # down, each frame's lowest body row (dust specks opened away), the feet on one line; the slam frame (SLAM),
        # whose dust burst joins the claw, by its body's fit instead (its burst would lift her)
        ax = ibn.anchor_of(att[0])[0]
        ay = float(np.nonzero(_core(att[0]))[0].max())
        shifts = []
        for k, im in enumerate(att):
            dx, dy = (0, 0) if k == 0 else _shift_to(att[0], im)
            y = ay - dy if (k == SLAM and d not in MOTHER_DROP) else float(np.nonzero(_core(im))[0].max())
            ibn.FEET[(("attack", d), k)] = (ax - dx, y)
            shifts.append((dx, dy))
        print(f"  stage {n} {d}: scale {sc:.4f}, height {small[('walk', d)][0].shape[0]}, swipe shifts {shifts}")


def lay_egg(lay, n):
    """The new egg her laying frames drop: the biggest bright blob a later frame has that the first hasn't, placed as
    assemble lays the frames (the anchor at a common point). (x, y, frame) from the anchor, or None."""
    def bright(im):
        rgb = im[..., :3].astype(int)
        return (im[..., 3] > 0) & (rgb[..., 1] > 170) & (rgb[..., 0] > 120) & (rgb[..., 2] < 140)
    S = 1200
    def stamp(m, k):
        ax, ay = ibn.FEET[(("lay", "se"), k)]
        out = np.zeros((S, S), bool)
        oy, ox = int(round(S / 2 - ay)), int(round(S / 2 - ax))
        out[oy:oy + m.shape[0], ox:ox + m.shape[1]] = m
        return out
    first = ndimage.binary_dilation(stamp(bright(lay[0]), 0), iterations=2)
    cands = []
    for k in range(1, len(lay)):
        new = stamp(bright(lay[k]), k) & ~first
        lab, nn = ndimage.label(ndimage.binary_closing(new, iterations=2))
        if not nn:
            continue
        sz = ndimage.sum(new, lab, range(1, nn + 1))
        i = int(np.argmax(sz))
        if sz[i] < 12:
            continue
        ys, xs = np.nonzero(lab == i + 1)
        cands.append((float(xs.mean() - S / 2), float(ys.mean() - S / 2), k, float(sz[i]), float(np.percentile(ys, 97) - S / 2)))
    if not cands:
        return None
    # the egg out on the ground: the lowest blob; of the frames that show it there (within 10 px), the last
    low = max(c[1] for c in cands)
    return max([c for c in cands if c[1] >= low - 10.0], key=lambda c: c[2])


# ------------------------------------------------------------------ portraits

def portrait(kind, stand_ins):
    f = f"{kind}_portrait_chatgpt.png"
    if have(f):
        ibn.PORTRAIT[kind] = f
        ibn.portrait(kind)
        return
    if kind not in HEADS:
        import shutil
        shutil.copy(f"{ia.OUT}/icons/dilophosaurus.png", f"{ia.OUT}/icons/{kind}.png")
        stand_ins.append(f"{kind} portrait: the Venom Sire's until {f}")
        return
    src, (x0, y0, x1, y1) = HEADS[kind]
    px = ia.load(R + src)
    crop = px[y0:y1, x0:x1].astype(np.uint8)
    img = Image.fromarray(crop).convert("RGB").resize((60, 60), Image.LANCZOS)
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (70, 74, 72)
    icon[..., 3] = 255
    icon[2:62, 2:62, :3] = np.array(img)
    ia.save(ia.unteam(icon), f"{ia.OUT}/icons/{kind}.png")
    stand_ins.append(f"{kind} portrait: a crop of the concept's head until {f}")


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    stand_ins = []
    data = {}
    todo = ["tyrant_challenger", "venom_challenger", "brood_mother_2", "brood_mother_3"]
    for name in todo:
        if only and name != only:
            continue
        print(name)
        ibn.FEET.clear()
        if name == "tyrant_challenger":
            small = tyrant_challenger(stand_ins)
        elif name == "venom_challenger":
            small = venom_challenger(stand_ins)
        else:
            s1 = mother_stage1()
            ibn.FEET.clear()
            small = mother_stage(int(name[-1]), s1, stand_ins)
        ibn.assemble(name, small, data)
        ibn.write_entry(name, data[name])
        if not name.startswith("brood_mother"):
            portrait(name, stand_ins)
        if contact_dir:
            ibn.contact(contact_dir, name, small)
    print("stand-ins:" if stand_ins else "no stand-ins")
    for s in stand_ins:
        print("  - " + s)


if __name__ == "__main__":
    main()
