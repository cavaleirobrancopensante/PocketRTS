#!/usr/bin/env python3
"""Import YOUNG AND MATURE (the owner, 2026-10-29 12:40-13:58; docs/brood_new.md "Young and mature") from the owner's
ChatGPT sheets in art/redraws/: the VIPER (kind "viper", the Venom Sire's young), the YOUNG TYRANT ("young_tyrant", a
matured Raptor), the HOODED SERPENT ("hooded_serpent", a matured Viper), and the BROOD MOTHER'S STAGE 2 AND 3 art (art
keys "brood_mother_2", "brood_mother_3": the game switches her art when she grows).

Re-runnable: python3 -I tools/import_brood_mature.py [--contact DIR] [--only NAME]. It uses tools/import_brood_new.py's
steps (the navy background keyed out, frames split, feet on the anchor, the red spikes snapped to the team reds; west
views are the east ones mirrored by the game).

SIZES (game px; the Raptor's east walk is 33 px long, 21 tall south-east):
  - VIPER: its east slither as long as a Raptor's east walk (VIPER_E_W); every other sheet scaled so its first slither
    frame covers as much as the east one (the same snake: the same painted area).
  - YOUNG TYRANT: about twice a Raptor: its south-east run TYRANT_H tall (the Raptor 21, the Brute about 64).
  - HOODED SERPENT: about three Vipers long: its slither frame's diagonal SERPENT_LONG times the Viper's south-east one;
    the spit and death sheets so their first frame covers as much as the slither's (venom left out).
  - THE MOTHER'S STAGES: each stage's art is brought to her STAGE-1 BODY (its south-east walk's first frame covers as
    much as stage 1's); the game still scales her sprite by her stage (Defs.NB "stages" scale: x1.15, x1.3), so stage 2 is
    drawn 1.15x and stage 3 1.3x her stage-1 body, whatever size ChatGPT drew them (no double scaling).

SHEETS
  viper_<d>_chatgpt.png (d = se, s, e, ne, n): rows slither 6, spit 6, death 5 or 6 (N: all 6 kept).
  young_tyrant_se_chatgpt.png: rows run 6, bite 6, death 5 (SOUTH-EAST ONLY: the game shows it in every view until the
    owner's young_tyrant_<d>_chatgpt.png come; picked up by name).
  hooded_serpent_slither_se_composed.png: the owner's composite, 6 cells of 470 x 560 (cut by cell: the tail fan is a
    separate piece); hooded_serpent_spit_se_chatgpt.png (6); hooded_serpent_death_se_chatgpt.png (5). South-east only
    (hooded_serpent_<d>_... picked up later by name).
  brood_mother_stage<N>_se_walk_swipe_death_chatgpt.png: walk 6, swipe 6 (its frame 3 has a paw growing out of her back:
    dropped, frame 2 held twice), death 5; brood_mother_stage<N>_se_nest_chatgpt.png: rooting 5, rooted loop 4 (stage 3:
    5), laying 6, uprooting 5. The other views (walk and swipe S, E, NE, N) are her stage-1 frames (the same body size):
    stand-ins until the owner's sheets come.
Portraits: crops of the concepts' heads until the owner's portraits come (<kind>_portrait_chatgpt.png, by name).
Prints, for Defs.NB / BroodNew: each stage's rooted art bottom from her feet (nest_y) and where her last laying frame draws
the new egg (lay_egg).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402

R = ibn.R
DIRS = ["se", "s", "e", "ne", "n"]
VIPER_E_W = 34.0
TYRANT_H = 42.0
SERPENT_LONG = 3.0
SERPENT_CELL = (470, 560)
# concept heads for the stand-in portraits (x0, y0, x1, y1 on the sheet)
HEADS = {"viper": ("viper_concept_chatgpt.png", (1125, 175, 1290, 340)),
         "young_tyrant": ("young_tyrant_concept_chatgpt.png", (430, 300, 620, 490)),
         "hooded_serpent": ("hooded_serpent_concept2_chatgpt.png", (835, 175, 1015, 355))}


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


# ------------------------------------------------------------------ the Viper

def viper(stand_ins):
    small = {}
    cut = {d: rows_of(f"viper_{d}_chatgpt.png") for d in DIRS if have(f"viper_{d}_chatgpt.png")}
    ref = cut["e"][0][0] if "e" in cut else cut["se"][0][0]
    base = VIPER_E_W / ref.shape[1]
    A = body_area(ref) * base * base
    for d, rows in cut.items():
        sc = (A / body_area(rows[0][0])) ** 0.5
        for name, ri in (("walk", 0), ("attack", 1), ("death", 2)):
            if ri < len(rows):
                small[(name, d)] = shrink_all(rows[ri], sc)
        small[("idle", d)] = small[("walk", d)][:1]
        print(f"  viper {d}: scale {sc:.4f}")
    for d in DIRS:
        if d not in cut:
            stand_ins.append(f"viper {d.upper()}: the nearest drawn view until viper_{d}_chatgpt.png")
    feet_all(small)
    return small


# ------------------------------------------------------------------ the Young Tyrant

def young_tyrant(stand_ins):
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
            stand_ins.append(f"young tyrant {d.upper()}: the south-east frames (game fallback) until {f}")
    stand_ins.append("young tyrant run SE: the owner's sheet's legs are weak (as he said); kept until a redraw")
    feet_all(small)
    return small


# ------------------------------------------------------------------ the Hooded Serpent

def cells(f, cw, ch):
    """A composite sheet cut by its cells (each cell's drawing, all its pieces)."""
    px = ia.load(R + f)
    fg = ibn.key_mask(px)
    out = []
    for i in range(px.shape[1] // cw):
        m = np.zeros_like(fg)
        m[:ch, i * cw:(i + 1) * cw] = fg[:ch, i * cw:(i + 1) * cw]
        lab, n = ndimage.label(m)
        if n:
            sz = ndimage.sum(m, lab, range(1, n + 1))
            keep = np.zeros(n + 1, bool)
            keep[1:] = sz >= 40           # (specks out)
            m = keep[lab]
        if m.any():
            out.append(ia.cutout(px, ibn._piece(m)))
    print(f"  {f}: {len(out)} cells")
    return out


def one_row(f):
    px, rows = ibn.sheet_rows(f)
    sprites = sorted([s for r in rows for s in r], key=lambda s: s["cx"])
    print(f"  {f}: {len(sprites)} frames")
    return [ia.cutout(px, s) for s in sprites]


def diag(im):
    ys, xs = np.nonzero(im[..., 3] > 0)
    return float(np.hypot(xs.max() - xs.min() + 1, ys.max() - ys.min() + 1))


def hooded_serpent(stand_ins, viper_small):
    small = {}
    sl = cells("hooded_serpent_slither_se_composed.png", *SERPENT_CELL)
    want = SERPENT_LONG * diag(viper_small[("walk", "se")][0])
    sc = want / diag(sl[0])
    small[("walk", "se")] = shrink_all(sl, sc)
    small[("idle", "se")] = small[("walk", "se")][:1]
    A = body_area(small[("walk", "se")][0])
    for name, f in (("attack", "hooded_serpent_spit_se_chatgpt.png"), ("death", "hooded_serpent_death_se_chatgpt.png")):
        fr = one_row(f)
        s2 = (A / body_area(fr[0])) ** 0.5
        small[(name, "se")] = shrink_all(fr, s2)
        print(f"  hooded_serpent {name}: scale {s2:.4f}")
    print(f"  hooded_serpent: slither scale {sc:.4f} (diagonal {want:.0f} px, the Viper's x{SERPENT_LONG})")
    for d in DIRS[1:]:
        stand_ins.append(f"hooded serpent {d.upper()}: the south-east frames (game fallback) until the owner's {d.upper()} sheets")
    feet_all(small)
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
    # the nest sheet: its first rooting frame (standing) as tall as her walk's first
    scn = small[("walk", "se")][0].shape[0] / float(ns[0][0].shape[0])
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
    # the other views: her stage-1 frames (the same body), stand-ins
    for (a, d), lst in s1.items():
        if d != "se" and (a, d) not in small:
            small[(a, d)] = lst
    stand_ins.append(f"brood mother stage {n}: walk and swipe S, E, NE, N are her stage-1 frames (scaled by the stage) until the owner's stage-{n} sheets")
    for key in [("rooted", "se"), ("lay", "se")]:
        small[("glow_" + key[0], key[1])] = [ibn.glow_of("brood_mother", im) for im in small[key]]
    feet = ibn.anchor_of(small[("rooted", "se")][0])
    print(f"  stage {n}: nest_y {nest_bottom(small[('rooted', 'se')][0], feet):.0f} (the rooted art's bottom from her feet)")
    if egg is not None:
        print(f"  stage {n}: lay_egg: middle ({egg[0]:.0f}, {egg[1]:.0f}), bottom {egg[4]:.0f} from her feet (BroodNew.LAY_EGG: (x, bottom))")
    return small


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
    vs = None
    todo = ["viper", "young_tyrant", "hooded_serpent", "brood_mother_2", "brood_mother_3"]
    for name in todo:
        if only and name != only and not (only == "hooded_serpent" and name == "viper"):
            continue
        print(name)
        ibn.FEET.clear()
        if name == "viper":
            small = viper(stand_ins)
            vs = small
        elif name == "young_tyrant":
            small = young_tyrant(stand_ins)
        elif name == "hooded_serpent":
            small = hooded_serpent(stand_ins, vs)
        else:
            s1 = mother_stage1()
            ibn.FEET.clear()
            small = mother_stage(int(name[-1]), s1, stand_ins)
        if only and name != only:
            continue
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
