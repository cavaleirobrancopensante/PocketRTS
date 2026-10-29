#!/usr/bin/env python3
"""THE STORM LINE (the owner, 2026-10-29; docs/storm_line.md): the Storm Sire's young, the HATCHLINGS (kind "hatchlings",
stage 2, two to an egg), and their mature form, the STORM CHALLENGER (kind "storm_challenger", stage 3), from the owner's
ChatGPT sheets art/redraws/hatchling_<d>_chatgpt.png and art/redraws/storm_challenger_<d>_chatgpt.png (d = se, s, e, ne,
n; 1536x1024, a dark navy background), three rows each:
  FLY 6 frames (a wing-beat loop), ATTACK 6 (the Hatchling's BITE, the Challenger's SWOOP), DEATH 5 (three falling, two
  lying on the ground; every death ends lying sideways facing east: accepted by the owner).
Strips walk_ (the fly loop), idle_ (the same loop: hovering, the wing beat goes on), attack_ and death_ in all five views;
the game mirrors the west ones. Both are FLYERS like the Storm Sire (tools/import_brood_fathers.py pterodactyl): in the
air the frames are lined up on the body's middle, the anchor (the shadow's point) FLY_DROP of the fly's height under it,
so a wing beat whose tips sweep down does not lift the body; the death's two lying frames stand on their lowest pixel
(the body hits the ground).

THE OWNER'S FRAME CHECK (2026-10-29), done here:
  - Hatchling NE: bite frame 3 turns the head toward the camera: fine at its size, kept.
  - The bite/swoop frame 4 has little motion-line marks (loose pale strokes by the beak): ERASED (MARK_MAX: loose pieces
    far smaller than the body). At the Hatchling's size they come out as 1-2 px yellow specks off the beak, which read as
    dirt, not as a hit; and they would pull the body's middle (its anchor) toward them. The game's own hit spark shows
    the blow.
  - Storm Challenger NE: the swoop row is mixed (its frames 1, 2 and 6 face south-east): the NE swoop is built from
    north-east frames only: NE_SWOOP (fly 1, fly 2, swoop 3, 4, 5, fly 1): the blow stays on the 4th frame.
  - Storm Challenger N: the owner could not get the dive to face north: the swoop row's frames 2, 3, 4 are FLIPPED
    top to bottom (the owner's idea) so the beak points north.

SIZES (game px): one scale per creature for all five sheets (ChatGPT drew them at one size: the first fly frames are
141-210 sheet px across): the south-east fly's first frame (wings up) HATCH_W wide for a Hatchling (about a Raptor: 33
long, 21 tall) and CHALLENGER_W for a Storm Challenger: half the Storm Sire's (his first south-east fly frame 150 wide,
tools/import_brood_fathers.py TARGET_W).

PORTRAITS: the owner's art/redraws/hatchling_portrait_chatgpt.png and storm_challenger_portrait_chatgpt.png (steel
frame, cut as the Sires' portraits: tools/import_brood_new.py portrait); without them, crops of the heads in the growth
concept art/redraws/storm_line_growth_concept_chatgpt.png (the big Hatchling top left, the Challenger top middle).

Re-runnable: python3 -I tools/import_storm_line.py [--contact DIR] [--only hatchlings|storm_challenger]. Run after
tools/anim_audit/fix_brood.py and before import_vet_skin.py (tools/rebuild_art.sh).
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
SHEET = {"hatchlings": "hatchling", "storm_challenger": "storm_challenger"}
HATCH_W = 28.0
CHALLENGER_W = 75.0
FLY_DROP = 0.4
MARK_MAX = 0.03          # a loose piece under this share of the body's area, off the body, is a motion mark: erased
# the Storm Challenger's NE swoop: (row, frame) from its own sheet, 0-based (row 0 fly, row 1 swoop)
NE_SWOOP = [(0, 0), (0, 1), (1, 2), (1, 3), (1, 4), (0, 0)]
N_FLIP = [1, 2, 3]       # the Storm Challenger's N swoop frames flipped top to bottom
CONCEPT = "storm_line_growth_concept_chatgpt.png"
PORTRAIT = {"hatchlings": "hatchling_portrait_chatgpt.png", "storm_challenger": "storm_challenger_portrait_chatgpt.png"}
HEADS = {"hatchlings": (132, 238, 246, 352), "storm_challenger": (768, 288, 888, 408)}


def rows_of(f):
    keep = ibn.split_wide
    ibn.split_wide = lambda row: row        # (the death rows' lying frames are twice as wide as the flying ones)
    try:
        px, rows = ibn.sheet_rows(f)
    finally:
        ibn.split_wide = keep
    print(f"  {f}: rows {[len(r) for r in rows]}")
    return [[ia.cutout(px, s) for s in r] for r in rows]


def drop_marks(im):
    """The frame without loose little pieces off the body (the motion-line marks by the beak)."""
    a = im[..., 3] > 0
    lab, n = ndimage.label(a)
    if n < 2:
        return im, 0
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    big = float(sizes.max())
    out = im.copy()
    gone = 0
    for i, s in enumerate(sizes):
        if s < big * MARK_MAX:
            out[lab == i + 1] = 0
            gone += int(s)
    return out, gone


def middle(im):
    ys, xs = np.nonzero(im[..., 3] > 0)
    return float(xs.mean()), float(ys.mean())


def build(kind, stand_ins):
    pre = SHEET[kind]
    sheets = {d: rows_of(f"{pre}_{d}_chatgpt.png") for d in DIRS}
    w0 = sheets["se"][0][0].shape[1]
    target = HATCH_W if kind == "hatchlings" else CHALLENGER_W
    sc = target / float(w0)
    print(f"  scale {sc:.4f} (the south-east fly's first frame {w0} sheet px wide -> {target:.0f})")
    small = {}
    for d, rows in sheets.items():
        fly, atk, death = rows[0], rows[1], rows[2]
        if kind == "storm_challenger" and d == "ne":
            atk = [rows[r][i] for r, i in NE_SWOOP]
            print("  NE swoop: fly 1, fly 2, swoop 3, 4, 5, fly 1 (the sheet's swoop 1, 2, 6 face south-east)")
        if kind == "storm_challenger" and d == "n":
            atk = [np.flipud(im).copy() if i in N_FLIP else im for i, im in enumerate(atk)]
            print("  N swoop: frames 2, 3, 4 flipped top to bottom (the beak points north)")
        clean = []
        for i, im in enumerate(atk):
            im2, gone = drop_marks(im)
            if gone:
                print(f"  {d} attack frame {i + 1}: {gone} px of loose marks erased")
            clean.append(im2)
        small[("walk", d)] = [ia.snap_team(ia.shrink(im, sc)) for im in fly]
        small[("idle", d)] = list(small[("walk", d)])
        small[("attack", d)] = [ia.snap_team(ia.shrink(im, sc)) for im in clean]
        small[("death", d)] = [ia.snap_team(ia.shrink(drop_marks(im)[0], sc)) for im in death]
    # IN THE AIR: lined up on the body's middle, the anchor FLY_DROP of the fly's height under it; the two lying death
    # frames on their lowest pixel
    ibn.FEET.clear()
    for (anim, d), lst in small.items():
        H = small[("walk", d)][0].shape[0]
        for k, im in enumerate(lst):
            if anim == "death" and k >= 3:
                ibn.FEET[((anim, d), k)] = ibn.anchor_of(im)
            else:
                mx, my = middle(im)
                ibn.FEET[((anim, d), k)] = (mx, my + FLY_DROP * H)
    w, h = small[("walk", "se")][0].shape[1], small[("walk", "se")][0].shape[0]
    print(f"  {kind}: the south-east fly's first frame {w}x{h} game px")
    return small


def portrait(kind, stand_ins):
    f = PORTRAIT[kind]
    if os.path.exists(R + f):
        # the owner's framed portrait (steel frame, as the other Brood portraits): cut as the Sires' (ibn.portrait)
        ibn.PORTRAIT[kind] = f
        ibn.portrait(kind)
        return
    px = ia.load(R + CONCEPT)
    x0, y0, x1, y1 = HEADS[kind]
    crop = px[y0:y1, x0:x1].astype(np.uint8)
    img = Image.fromarray(crop).convert("RGB").resize((60, 60), Image.LANCZOS)
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (70, 74, 72)
    icon[..., 3] = 255
    icon[2:62, 2:62, :3] = np.array(img)
    ia.save(ia.unteam(icon), f"{ia.OUT}/icons/{kind}.png")
    stand_ins.append(f"{kind} portrait: a crop of the growth concept's head until {PORTRAIT[kind]}")


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    stand_ins = []
    data = {}
    for kind in ["hatchlings", "storm_challenger"]:
        if only and kind != only:
            continue
        print(kind)
        small = build(kind, stand_ins)
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
