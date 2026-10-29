#!/usr/bin/env python3
"""THE SPITTER REDO (the owner, 2026-10-29; docs/spitter_redo.md): the Spitter, the Venom line's young (only a tiny
ruff, no glow; concept art/redraws/venom_line_growth_concept_chatgpt.png), from the owner's ChatGPT sheets
art/redraws/spitter_<d>_chatgpt.png (d = se, s, e, ne, n; 1536x1024, a dark navy background), three rows each:
  WALK 6 frames, SPIT 6 frames (1 rest, 2 ruff opening, 3 ruff and mouth open, 4 the glob leaves the mouth, 5 the glob
  gone, 6 back to rest), DEATH 5 frames (the S sheet's last death frame is cut whole: no wide-frame split here).
It replaces import_art.py's Spitter (rows idle, walk, flare, attack, death, east only): strips walk_, attack_, death_
and idle_ (the walk's first frame) in all five views; the game mirrors the west ones. The old "flare" strip is not made
(the game never played it).

THE GLOB: the game draws its own missile when a Spitter spits (Game.acid_shot / ground_shot_fx / fog_miss), so the glob
and its drops are taken out of every spit frame 4 (all painted pixels farther than GLOB_GAP sheet px from the creature);
what is left at the mouth is the stream just leaving it. The EAST sheet's glob (it slanted upward; the owner: "select the
spit shot and rotate it so it's a straight shot") is cut out, turned along its own long axis so it flies straight to the
right, and becomes the Spitter's missile: assets/effects/spitter_glob.png (ArtData.EFFECTS "spitter_glob"; the Shot turns
it along its flight).

SIZE: every view at one scale (the five sheets are drawn at one size: the first walk frames' bodies cover 11.9k to 14.6k
sheet px), the east walk's first frame SPITTER_LEN game px long, tail to snout: about a third of the Venom Sire's
(125) and a little over the Raptor's (33); the Venom Challenger sits between (100).

Re-runnable: python3 -I tools/import_spitter_redo.py [--contact DIR]. Run after import_art.py and
tools/anim_audit/fix_brood.py (which still write and touch the old strips), before import_vet_skin.py and
import_venom_colours.py (tools/rebuild_art.sh).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402
import import_brood_mature as ibm  # noqa: E402

DIRS = ["se", "s", "e", "ne", "n"]
SPITTER_LEN = 44.0
GLOB_GAP = 7            # sheet px: painted pixels farther than this from the creature are the glob and its drops
SPIT_FRAME = 3          # (0-based) the frame the glob leaves the mouth: the game's shot comes on it (aim 0.35 s at 9 fps)
GLOB_LEN = 16.0         # game px: the missile's length, glob and tail
HEADS = ("venom_line_growth_concept_chatgpt.png", (205, 268, 365, 428))      # the young's head on the concept


def rows_of(f):
    keep = ibn.split_wide
    ibn.split_wide = lambda row: row        # (the death rows' lying frames are twice as wide as the standing ones)
    try:
        px, rows = ibn.sheet_rows(f)
    finally:
        ibn.split_wide = keep
    print(f"  {f}: rows {[len(r) for r in rows]}")
    return [[ia.cutout(px, s) for s in r] for r in rows]


def creature(im):
    """The creature's own pixels: the biggest painted piece once the bright venom is set aside, its venom and drool
    touching it back in."""
    a = im[..., 3] > 0
    body = a & ~ibm.venom(im)
    lab, n = ndimage.label(body)
    if n > 1:
        sizes = ndimage.sum(body, lab, range(1, n + 1))
        body = lab == (1 + int(np.argmax(sizes)))
    return body


def split_glob(im):
    """(the frame without the glob, the glob's own picture or None)."""
    a = im[..., 3] > 0
    near = ndimage.binary_dilation(creature(im), iterations=GLOB_GAP)
    glob = a & ~near
    if glob.sum() < 30:
        return im, None
    out = im.copy()
    out[glob] = 0
    g = im.copy()
    g[~glob] = 0
    return out, g


def straight(g):
    """The glob turned along its long axis (the biggest piece, its trailing drops with it), pointing right."""
    a = g[..., 3] > 0
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=3))
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    main = (lab == 1 + int(np.argmax(sizes))) & a
    ys, xs = np.nonzero(main)
    w = np.ones(len(xs))
    # the head of the glob: its brightest part; the tail: the rest; the axis from the tail's middle to the head's
    lum = g[ys, xs, :3].astype(float).sum(1)
    head = lum >= np.percentile(lum, 80)
    hx, hy = xs[head].mean(), ys[head].mean()
    cx, cy = np.average(xs, weights=w), np.average(ys, weights=w)
    cov = np.cov(np.stack([xs - cx, ys - cy]))
    ev, evec = np.linalg.eigh(cov)
    vx, vy = evec[:, 1]
    if vx * (hx - cx) + vy * (hy - cy) < 0:
        vx, vy = -vx, -vy
    ang = np.degrees(np.arctan2(vy, vx))
    print(f"  the east glob turned {ang:.1f} degrees (it slanted off the horizontal): now straight")
    pic = Image.fromarray(np.where(main[..., None], g, 0).astype(np.uint8))
    rot = np.array(pic.rotate(ang, resample=Image.BICUBIC, expand=True))
    rot[..., 3] = np.where(rot[..., 3] >= 128, 255, 0)
    rot[rot[..., 3] == 0] = 0
    ys, xs = np.nonzero(rot[..., 3])
    return rot[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    sheets = {d: rows_of(f"spitter_{d}_chatgpt.png") for d in DIRS}
    e0 = sheets["e"][0][0]
    xs = np.nonzero(creature(e0).any(0))[0]
    sc = SPITTER_LEN / float(xs.max() - xs.min() + 1)
    print(f"  scale {sc:.4f} (the east walk's first frame {xs.max() - xs.min() + 1} sheet px long)")
    small = {}
    glob = None
    for d, rows in sheets.items():
        spit = list(rows[1])
        if len(spit) > SPIT_FRAME:
            spit[SPIT_FRAME], g = split_glob(spit[SPIT_FRAME])
            if d == "e" and g is not None:
                glob = straight(g)
        for name, lst in (("walk", rows[0]), ("attack", spit), ("death", rows[2])):
            small[(name, d)] = ibm.shrink_all(lst, sc)
        small[("idle", d)] = small[("walk", d)][:1]
    ibn.FEET.clear()
    ibm.feet_all(small)
    data = {}
    ibn.assemble("spitter", small, data)
    ibn.write_entry("spitter", data["spitter"])
    if glob is not None:
        gs = ia.shrink(glob, GLOB_LEN / glob.shape[1])
        ia.save(ia.unteam(gs), f"{ia.OUT}/effects/spitter_glob.png")
        write_effect("spitter_glob", gs.shape[1], gs.shape[0])
        print(f"  spitter_glob: {gs.shape[1]}x{gs.shape[0]}")
    portrait()
    if contact_dir:
        ibn.contact(contact_dir, "spitter", small)


def write_effect(name, w, h):
    path = "scripts/art_data.gd"
    src = open(path).read()
    line = f'\t"{name}": {{"frames": 1, "size": Vector2i({w}, {h})}},\n'
    start = src.index("const EFFECTS := {")
    end = src.index("\n}\n", start) + 1
    body = src[start:end]
    import re
    pat = re.compile(r'\t"' + name + r'": \{[^\n]*\n')
    body = pat.sub(lambda m: line, body) if pat.search(body) else body + line
    open(path, "w").write(src[:start] + body + src[end:])


def portrait():
    """The card's portrait: the young's head from the concept (a stand-in until a painted one comes)."""
    src, (x0, y0, x1, y1) = HEADS
    px = ia.load(ibn.R + src)
    crop = px[y0:y1, x0:x1].astype(np.uint8)
    img = Image.fromarray(crop).convert("RGB").resize((60, 60), Image.LANCZOS)
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (70, 74, 72)
    icon[..., 3] = 255
    icon[2:62, 2:62, :3] = np.array(img)
    ia.save(ia.unteam(icon), f"{ia.OUT}/icons/spitter.png")


if __name__ == "__main__":
    main()
