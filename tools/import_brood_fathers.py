#!/usr/bin/env python3
"""Import the new Brood's two later FATHERS (the owner, 2026-10-29: docs/brood_new.md "The three fathers") from the
owner's ChatGPT sheets in art/redraws/: the DILOPHOSAURUS (kind "dilophosaurus": Spitters and Mist Toads) and the
PTERODACTYL (kind "pterodactyl": Skywings; a flyer that lands on his nest to root).

Re-runnable: python3 -I tools/import_brood_fathers.py [--contact DIR] [--only KIND]. It uses tools/import_brood_new.py's
steps (the navy background keyed out, frames split, scaled to the creature's size, feet on the anchor, the red spikes
snapped to the team reds; west views are the east ones mirrored by the game).

THE SHEETS ARE PICKED UP BY NAME as the owner sends them; until a sheet is there, its stand-in is used (logged in
docs/art_style_inconsistency.md, "The fathers' stand-ins"). The game falls back to the nearest drawn direction, so a
missing direction simply shows the south-east (or the east mirrored) one.

DILOPHOSAURUS
  walk SE    dilophosaurus_walk_se_v2_chatgpt.png (the walk redo)   else row 1 of dilophosaurus_se_walk_spit_chatgpt.png (weak legs)
  attack SE  row 2 of dilophosaurus_se_walk_spit_chatgpt.png (the SPIT, frill spread)
  walk/attack S, E, NE, N   dilophosaurus_walk_<d>_chatgpt.png, dilophosaurus_spit_<d>_chatgpt.png   else SE (the game's fallback)
  root, uproot, death SE    rows 1, 3, 4 of dilophosaurus_nest_se_chatgpt.png (its row 2, spitting venom on its eggs, is BAD: unused)
  rooted SE  dilophosaurus_fertilise_se_v2_chatgpt.png (the good fertilising loop, 6 frames)
  portrait   dilophosaurus_portrait_chatgpt.png   else the head of dilophosaurus_concept_composed.png
PTERODACTYL
  fly SE (walk and idle)   frames 1-4 of pterodactyl_fly_se_v3_chatgpt.png (a wing-beat loop; frames 5-6 copy frame 1)
  attack SE  row 2 of pterodactyl_fly_dive_se_chatgpt.png (the DIVE)
  fly/dive S, E, NE, N   pterodactyl_fly_<d>_chatgpt.png, pterodactyl_dive_<d>_chatgpt.png   else SE
  root (landing), rooted (fertilising), uproot (take-off), death SE   pterodactyl_nest_se_v2_chatgpt.png (rows 5, 6, 5, 5)
             else: rooted = the LANDED FERTILISING figure of pterodactyl_concept_chatgpt.png (one frame; the game breathes
             it and pulses its eggs' glow, cross-fades flying to landed), death = frames 2-4 of the dive (a plunge)
             (pterodactyl_nest_se_chatgpt.png, where he turns into a four-legged dragon when landed, is NOT used)
  portrait   pterodactyl_portrait_chatgpt.png   else the head of the concept's flying figure
Prints each father's nest point (the eggs' middle from his feet: Defs.NB "nest_at") and the bottom of his rooted art
from his feet (Defs.NB "nest_y").
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402

R = ibn.R
DIRS = ["s", "e", "ne", "n"]
# south-east walk (fly) width in game px: the Dilophosaurus lean, smaller than the Tyrannosaur (142: a Barracks); the
# Pterodactyl's wingspan a little wider than the Tyrannosaur
TARGET_W = {"dilophosaurus": 112, "pterodactyl": 150}
# the parts of a nest frame left as drawn (the red eggs and the fire are not team colour): fractions of the frame
NEST_KEEP = {"dilophosaurus": [(0.25, 0.62, 1.0, 1.0)], "pterodactyl": [(0.3, 0.58, 1.0, 1.0), (0.62, 0.4, 1.0, 0.75)]}
# the concepts (x0, y0, x1, y1 on the sheet): the Pterodactyl's flying figure (scale) and landed fertilising figure;
# the heads for the stand-in portraits
PT_CONCEPT = "pterodactyl_concept_chatgpt.png"
PT_FLY_BOX = (0, 20, 640, 480)
PT_LAND_BOX = (660, 110, 1264, 500)
PT_HEAD = (470, 230, 640, 400)
DI_CONCEPT = "dilophosaurus_concept_composed.png"
DI_HEAD = (420, 90, 620, 290)
# the Dilophosaurus' spit sheets by direction: E is the owner's own E sheet (its stream falls down-right; the second
# south-east try, dilophosaurus_spit_se_v2_chatgpt.png, whose stream runs flat, is not used: SE keeps row 2 of the
# walk/spit sheet, the owner's "good" one); NE and N are the owner's photos of the sheets with his RED PEN CIRCLE over
# frame 3 (the mouth at a hallucinated angle): PEN_BOX is the circle's box (x0, y0, x1, y1 on the sheet), painted over
# with the background before the frames are cut, so no pen pixel reaches a frame, and frame 3 (inside it) is gone
DI_SPIT = {"ne": "dilophosaurus_spit_ne_marked_chatgpt.png", "n": "dilophosaurus_spit_n_marked_chatgpt.png"}
# (each sheet: the circle's box, then frame 3's legs and tail below it, kept clear of frame 4's tail)
PEN_BOX = {"dilophosaurus_spit_ne_marked_chatgpt.png": [(688, 60, 1028, 400), (640, 400, 962, 667)],
           "dilophosaurus_spit_n_marked_chatgpt.png": [(605, 25, 1000, 410), (700, 410, 965, 667)]}
# THE PTERODACTYL'S DIRECTIONS (the owner's sheets, one row of 6 each; frames counted from 0 here):
#  - fly S, NE, N: all 6 (in NE and N the first and last are near-copies with the wings up: the loop's ends);
#  - fly E: the owner's JPEG photo pterodactyl_fly_e_marked_chatgpt.png, his RED PEN over frame 2 (a third wing): the
#    whole of frame 2 is painted out (PEN_BOX) and the loop is frames 1, 3, 4, 5 (the 6th copies the 5th);
#  - dive S: frame 2 (the body seen from below, another pose) pops: dropped, frame 1 held twice instead (same timing);
#  - dive E, NE, N: all 6.
PT_SHEET = {("walk", "e"): "pterodactyl_fly_e_marked_chatgpt.png"}
PT_FRAMES = {("walk", "e"): [0, 1, 2, 3], ("attack", "s"): [0, 0, 2, 3, 4, 5]}
PEN_BOX["pterodactyl_fly_e_marked_chatgpt.png"] = [(300, 225, 600, 580)]
ibn.JPEG_SHEETS |= set(PEN_BOX)        # (photos: softer, noisy; cleaned as the turtle's JPEG walks)
_load = ia.load


def _load_pen(path):
    """ia.load, with the owner's pen circle painted out (PEN_BOX) in the background colour."""
    px = _load(path)
    for f, boxes in PEN_BOX.items():
        if path.endswith(f):
            px = px.copy()
            rgb = px[..., :3].astype(int)
            border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3)])
            for x0, y0, x1, y1 in boxes:
                px[y0:y1, x0:x1, :3] = np.median(border, 0).astype(px.dtype)
    return px


ia.load = _load_pen


def have(f):
    return os.path.exists(R + f)


def rows_of(f):
    px, rows = ibn.sheet_rows(f)
    print(f"  {f}: rows {[len(r) for r in rows]}")
    return [[ia.cutout(px, s) for s in r] for r in rows]


def one_row(f):
    """A one-row sheet whose frames sit at different heights (the fly's wings-down frame drops below the others): all
    its frames left to right."""
    sw = ibn.split_wide
    hole = ibn.HOLE
    ibn.split_wide = lambda row: row       # (no splitting: a flight's wings-spread frames are twice as wide as its wings-up ones)
    if f in PEN_BOX:
        ibn.HOLE = 120          # (the photos: the gap under a wing is background, not dark shading to fill back in)
    try:
        px, rows = ibn.sheet_rows(f)
    finally:
        ibn.split_wide = sw
        ibn.HOLE = hole
    sprites = sorted([s for r in rows for s in r], key=lambda s: s["cx"])
    # (two neighbours whose spread wings touch come out as one piece: the sheets hold 6 frames, 5 with the pen's frame
    # painted out; the widest piece is cut where its columns are emptiest round its middle until the count is right)
    expect = 6 - (1 if f in PEN_BOX else 0)
    while len(sprites) < expect:
        wi = max(range(len(sprites)), key=lambda i: sprites[i]["x1"] - sprites[i]["x0"])
        s = sprites[wi]
        w = s["x1"] - s["x0"]
        col = s["mask"][:, s["x0"]:s["x1"]].sum(0).astype(float)
        cut = s["x0"] + int(w * 0.3) + int(np.argmin(col[int(w * 0.3):int(w * 0.7)]))
        parts = []
        for a, b in ((s["x0"], cut), (cut, s["x1"])):
            m = s["mask"].copy()
            m[:, :a] = False
            m[:, b:] = False
            parts.append(ibn._piece(m))
        sprites = sorted(sprites[:wi] + parts + sprites[wi + 1:], key=lambda o: o["cx"])
    print(f"  {f}: {len(sprites)} frames in one row")
    return [ia.cutout(px, s) for s in sprites]


def shrink_all(imgs, sc, keep=None, jpeg=False):
    if jpeg:
        return [ibn.snap_jpeg(ia.shrink(im, sc)) for im in imgs]
    if keep:
        return [ibn._snap_body(ia.shrink(im, sc), keep) for im in imgs]
    return [ia.snap_team(ia.shrink(im, sc)) for im in imgs]


def biggest(px, box, min_big=20000):
    fg = ibn.key_mask(px)
    x0, y0, x1, y1 = box
    m = np.zeros_like(fg)
    m[y0:y1, x0:x1] = fg[y0:y1, x0:x1]
    sp = ia.components(m, 4, min_big=min_big, attach_dist=30)
    return max(sp, key=lambda o: o["area"])


def eggs_and_bottom(kind, small, key):
    """The nest's eggs' middle and the rooted art's bottom, from the feet (for Defs.NB nest_at, nest_y)."""
    lo = small[key][0]
    fx, fy = ibn.FEET.get((key, 0)) or ibn.anchor_of(lo)
    rgb = lo[..., :3].astype(int)
    hh, ww = rgb.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    egg = (lo[..., 3] > 0) & (rgb[..., 0] > 150) & (rgb[..., 1] < 150) & (rgb[..., 2] < 90) & (yy > hh * 0.55) & (xx > ww * 0.25)
    a = lo[..., 3] > 0
    rows = np.nonzero(a.sum(1) >= max(3, int(ww / 6)))[0]
    bottom = rows.max() if len(rows) else np.nonzero(a.any(1))[0].max()
    ays, axs = np.nonzero(a)
    print(f"  {kind}: the rooted art from the feet: x {axs.min() - fx:.0f}..{axs.max() - fx:.0f}, y {ays.min() - fy:.0f}..{ays.max() - fy:.0f}")
    ys, xs = np.nonzero(egg)
    if len(xs):
        print(f"  {kind}: the nest's eggs at ({xs.mean() - fx:.0f}, {ys.mean() - fy:.0f}) from the feet; "
              f"the rooted art's bottom {bottom - fy:.0f} from the feet (rooted frame {ww}x{hh})")


def dirs_from(small, base, prefix, anim, H, sc_first=None):
    """Optional per-direction sheets (one row each), scaled so the first frame is H tall."""
    for d in DIRS:
        f = f"{prefix}_{d}_chatgpt.png"
        if not have(f):
            continue
        cut = rows_of(f)
        if not cut:
            continue
        sc = H / cut[0][0].shape[0]
        small[(anim, d)] = shrink_all(cut[0], sc)


def dilophosaurus(stand_ins):
    kind = "dilophosaurus"
    small = {}
    ws = rows_of("dilophosaurus_se_walk_spit_chatgpt.png")
    if have("dilophosaurus_walk_se_v2_chatgpt.png"):
        walk = rows_of("dilophosaurus_walk_se_v2_chatgpt.png")[0]
    else:
        walk = ws[0]
        stand_ins.append("dilophosaurus walk SE: the first walk row (weak legs) until dilophosaurus_walk_se_v2_chatgpt.png")
    base = TARGET_W[kind] / walk[0].shape[1]
    H = walk[0].shape[0] * base
    small[("walk", "se")] = shrink_all(walk, base)
    # the spit: scaled so its first (standing) frame is as tall as the walk's first
    sp = ws[1]
    small[("attack", "se")] = shrink_all(sp, H / sp[0].shape[0])
    # the other directions (one row of 6 each): the walks; the spits (NE and N: the owner's marked sheets, frame 3 dropped)
    for d in DIRS:
        f = f"dilophosaurus_walk_{d}_chatgpt.png"
        if have(f):
            fr = one_row(f)
            small[("walk", d)] = shrink_all(fr, H / fr[0].shape[0], jpeg=f in ibn.JPEG_SHEETS)
        f = DI_SPIT.get(d, f"dilophosaurus_spit_{d}_chatgpt.png")
        if have(f):
            fr = one_row(f)
            sc = H / fr[0].shape[0]
            if f in PEN_BOX:
                # (frame 3, under the owner's pen circle, is dropped; frame 2 is held for two steps so the spit keeps its
                # timing and its release stays on the stream frame, the 4th)
                fr = [fr[0], fr[1], fr[1]] + fr[2:]
            small[("attack", d)] = shrink_all(fr, sc, jpeg=f in ibn.JPEG_SHEETS)
    for d in DIRS:
        if ("walk", d) not in small:
            stand_ins.append(f"dilophosaurus walk {d.upper()}: the south-east walk (game fallback) until dilophosaurus_walk_{d}_chatgpt.png")
        if ("attack", d) not in small:
            stand_ins.append(f"dilophosaurus spit {d.upper()}: the south-east spit until dilophosaurus_spit_{d}_chatgpt.png")
    for d in ["se"] + DIRS:
        if ("walk", d) in small:
            small[("idle", d)] = small[("walk", d)][:1]
    # the nest: rooting 5, (fertilising: bad), uprooting 5, death 5; scaled so his standing first frame is as tall as
    # his walk (the same body), lined up on his green body's feet
    nest = "dilophosaurus_nest_se_chatgpt.png" if have("dilophosaurus_nest_se_chatgpt.png") else "dilophosaurus_nest_se_try1_chatgpt.png"
    nr = rows_of(nest)
    sc = H / nr[0][0].shape[0]
    keep = NEST_KEEP[kind]
    for name, ri in (("root", 0), ("uproot", 2), ("death", 3)):
        if ri < len(nr):
            small[(name, "se")] = shrink_all(nr[ri], sc, keep)
    # the good fertilising loop: its frames as wide as the nest sheet's (bad) fertilising row at that scale
    fert = rows_of("dilophosaurus_fertilise_se_v2_chatgpt.png")[0]
    ref_w = np.mean([im.shape[1] for im in nr[1]]) * sc if len(nr) > 1 else TARGET_W[kind] * 1.1
    scf = ref_w / np.mean([im.shape[1] for im in fert])
    small[("rooted", "se")] = shrink_all(fert, scf, keep)
    for name in ["root", "rooted", "uproot"]:
        for k, im in enumerate(small.get((name, "se"), [])):
            ibn.FEET[((name, "se"), k)] = ibn.claw_feet(im)
    small[("glow_rooted", "se")] = [ibn.glow_of("tyrannosaur", im) for im in small[("rooted", "se")]]
    eggs_and_bottom(kind, small, ("rooted", "se"))
    return small


def pterodactyl(stand_ins):
    kind = "pterodactyl"
    small = {}
    fly = one_row("pterodactyl_fly_se_v3_chatgpt.png")[:4]
    base = TARGET_W[kind] / fly[0].shape[1]
    H = fly[0].shape[0] * base
    small[("walk", "se")] = shrink_all(fly, base)
    dv = rows_of("pterodactyl_fly_dive_se_chatgpt.png")
    dive = dv[1] if len(dv) > 1 else dv[0]
    scd = TARGET_W[kind] / dive[0].shape[1]           # (its first frame is the same wings-up pose as the fly's first)
    small[("attack", "se")] = shrink_all(dive, scd)
    # (the other directions: their first frame as wide as the south-east fly's)
    for prefix, anim in (("pterodactyl_fly", "walk"), ("pterodactyl_dive", "attack")):
        for d in DIRS:
            f = PT_SHEET.get((anim, d), f"{prefix}_{d}_chatgpt.png")
            if have(f):
                fr = one_row(f)
                sc = H / fr[0].shape[0]
                if (anim, d) in PT_FRAMES:
                    fr = [fr[i] for i in PT_FRAMES[(anim, d)] if i < len(fr)]
                small[(anim, d)] = shrink_all(fr, sc, jpeg=f in ibn.JPEG_SHEETS)
            else:
                stand_ins.append(f"pterodactyl {'fly' if anim == 'walk' else 'dive'} {d.upper()}: the south-east one until {f}")
    for d in ["se"] + DIRS:
        if ("walk", d) in small:
            small[("idle", d)] = list(small[("walk", d)])        # (hovering: the wing beat goes on)
    keep = NEST_KEEP[kind]
    if have("pterodactyl_nest_se_v2_chatgpt.png"):
        nr = rows_of("pterodactyl_nest_se_v2_chatgpt.png")
        sc = TARGET_W[kind] / nr[0][0].shape[1]          # (the first landing frame: still flying, as wide as the fly)
        for name, ri in (("root", 0), ("rooted", 1), ("uproot", 2), ("death", 3)):
            if ri < len(nr):
                small[(name, "se")] = shrink_all(nr[ri], sc, keep)
    else:
        px = ia.load(R + PT_CONCEPT)
        flyc = biggest(px, PT_FLY_BOX)
        land = biggest(px, PT_LAND_BOX)
        sc = TARGET_W[kind] / float(flyc["x1"] - flyc["x0"])
        small[("rooted", "se")] = shrink_all([ia.cutout(px, land)], sc, keep)
        small[("death", "se")] = small[("attack", "se")][1:4]
        stand_ins.append("pterodactyl rooted: the concept's landed fertilising figure (one frame; breathing and the eggs' glow in code; "
                         "flying to landed cross-faded) until pterodactyl_nest_se_v2_chatgpt.png (landing 5, fertilising 6, take-off 5, death 5)")
        stand_ins.append("pterodactyl death: frames 2-4 of the dive (a plunge) until pterodactyl_nest_se_v2_chatgpt.png")
    for name in ["root", "rooted", "uproot"]:
        for k, im in enumerate(small.get((name, "se"), [])):
            ibn.FEET[((name, "se"), k)] = ibn.claw_feet(im)
    # IN THE AIR the frames are lined up on the body's middle (its centre of mass), not on the lowest pixel: a wing beat
    # whose wingtips sweep down would lift the body otherwise. The anchor (his place on the ground, his shadow) is
    # FLY_DROP of the fly's height under that middle.
    for (anim, d), lst in small.items():
        if anim in ("walk", "idle", "attack"):
            for k, im in enumerate(lst):
                ys, xs = np.nonzero(im[..., 3] > 0)
                ibn.FEET[((anim, d), k)] = (float(xs.mean()), float(ys.mean()) + FLY_DROP * H)
    small[("glow_rooted", "se")] = [ibn.glow_of("tyrannosaur", im) for im in small[("rooted", "se")]]
    eggs_and_bottom(kind, small, ("rooted", "se"))
    return small


FLY_DROP = 0.4


def portrait(kind, stand_ins):
    f = f"{kind}_portrait_chatgpt.png"
    if have(f):
        ibn.PORTRAIT[kind] = f
        ibn.portrait(kind)
        return
    src, box = (PT_CONCEPT, PT_HEAD) if kind == "pterodactyl" else (DI_CONCEPT, DI_HEAD)
    px = ia.load(R + src)
    x0, y0, x1, y1 = box
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
    for kind, fn in (("dilophosaurus", dilophosaurus), ("pterodactyl", pterodactyl)):
        if only and kind != only:
            continue
        print(kind)
        small = fn(stand_ins)
        ibn.assemble(kind, small, data)
        ibn.write_entry(kind, data[kind])
        portrait(kind, stand_ins)
        if contact_dir:
            ibn.contact(contact_dir, kind, small)
    print("stand-ins:" if stand_ins else "no stand-ins")
    for s in stand_ins:
        print("  - " + s)


if __name__ == "__main__":
    main()
