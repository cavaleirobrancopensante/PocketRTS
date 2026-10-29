#!/usr/bin/env python3
"""Import THE GRUB'S COCOON (the owner, 2026-10-29; docs/brood_anims.md): what a grub turns into while it morphs into a
ROOTMAW or a MOUND TURTLE (scripts/brood_root.gd cocoon_look; the Sires use lures, not cocoons). It replaces the code
stand-in (the old Brood's construction mound, assets/buildings/clutch_mound_construction.png).

SHEET: art/redraws/grub_cocoon_se_chatgpt.png (1536x1024, navy, 2 rows of 6 on a 256x512 grid; one south-east view:
it does not turn). Frames 1-2 (a larva curling and wrapping itself in slime) are NOT USED (the owner: the Brood's grubs
are small reptiles, not larvae); the game shows the grub's own sprite fading into frame 3 instead. Used, as the strip
"open_se" of art key "brood_cocoon" (10 frames, counted from 0 in the game):
  0-3   sheet 3-6: the small scaly case on the earth growing to full size
  4-6   sheet 7-9: it glows, shakes, cracks
  7-8   sheet 10-11: it splits open (the creature comes out)
  9     sheet 12: the empty broken shell left on the ground (fades)
Every frame is lined up on the bottom middle of its EARTH (the brown mound: the anchor), all at one scale: the earth of
the full-size case (sheet 6) MUD_W game px wide, the width of a 3-tile footprint (the game scales it to the creature's
footprint, Defs.NB "cocoon_scale"). The red spikes snap to the team reds (as the lures').
Re-runnable: python3 -I tools/import_brood_cocoon.py [--contact DIR]
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402
import import_sire_lure as isl  # noqa: E402

R = ibn.R
SHEET = "grub_cocoon_se_chatgpt.png"
USE = list(range(2, 12))         # sheet frames (from 0) used: 3-12
MUD_W = 96.0                     # the full case's earth, game px (3 tiles)
NAME = "brood_cocoon"


def snap(im):
    """The red spikes to the team reds: a little looser than the lures' snap (the sheet's spikes are shaded deep red,
    under its "light" level, with no light red beside many of them): every saturated red, light or dark."""
    r, g, b = im[..., 0].astype(int), im[..., 1].astype(int), im[..., 2].astype(int)
    red = (im[..., 3] > 0) & (r >= 90) & (g <= r * 0.45) & (b <= r * 0.5)
    light = red & (r >= 170)
    im[light, :3] = ia.TEAM_LIGHT
    im[red & ~light, :3] = ia.TEAM_DARK
    return isl._unteam_rest(im, red)


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    px = ia.load(R + SHEET)
    masks = isl.slot_masks(px)
    crops = [isl.crop(px, m) for m in masks]
    _, w_full = isl.mud(crops[5][0])
    s = MUD_W / max(w_full, 1.0)
    print(f"  scale {s:.3f} (the full case's earth {w_full:.0f} sheet px)")
    lst = []
    for i in USE:
        im, o = crops[i]
        gp, _ = isl.mud(im)
        small = snap(ia.shrink(im, s))
        lst.append((small, -np.array(gp) * s))
    L = R_ = U = Dn = 0.0
    for im, (x, y) in lst:
        L = max(L, -x); R_ = max(R_, x + im.shape[1]); U = max(U, -y); Dn = max(Dn, y + im.shape[0])
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    H = top + int(np.ceil(Dn)) + 1
    strip = np.zeros((H, W * len(lst), 4), np.uint8)
    for k, (im, (x, y)) in enumerate(lst):
        ox, oy = int(round(half + x)), int(round(top + y))
        h, w = im.shape[:2]
        m = im[..., 3] > 0
        strip[:, k * W:(k + 1) * W][oy:oy + h, ox:ox + w][m] = im[m]
    os.makedirs(f"{ia.OUT}/units/{NAME}", exist_ok=True)
    ia.save(strip, f"{ia.OUT}/units/{NAME}/open_se.png")
    ibn.write_entry(NAME, {"cell": (W, H), "anchor": (half, top), "frames": {"open_se": len(lst)}})
    print(f"  {NAME}: cell {W}x{H}, anchor ({half}, {top}), open_se {len(lst)}")
    if contact_dir:
        os.makedirs(contact_dir, exist_ok=True)
        im = Image.fromarray(strip)
        out = Image.new("RGBA", (im.width, im.height), (70, 100, 60, 255))
        out.alpha_composite(im)
        out = out.resize((out.width * 3, out.height * 3), Image.NEAREST)
        out.save(f"{contact_dir}/{NAME}.png")


if __name__ == "__main__":
    main()
