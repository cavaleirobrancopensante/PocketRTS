"""The Crown Labourer's hammering with a body that stays still: only the arm and the tool move.

The labourer's `build_<dir>` strips (cut by import_art.py from art/crown/labourer.png, hoe
fixes by fix_labourer_hoe.py) were drawn with the whole man moving between frames: the head
bobs 1-3 px, the torso leans and crouches, the legs shift. That reads as a wavy man (the
designer's words: "too wavy; I want his body to stay mostly still and his arm do the
hammering"). This pass rebuilds each strip from its own frames:

  1. one still body: the REF frame (BODY_FRAME[dir], the most upright one) is the body of
     every output frame;
  2. every other frame is aligned to it (the integer shift of up to +-3 px that best matches
     the pixels outside the ARM box: hat, head, torso, legs);
  3. inside the ARM box (hand-tuned per direction: the shoulder, the arm, the tool and the
     post it strikes, never the head) the aligned frame's pixels replace the still body's;
     pixels of that box that differ from the still body in no frame stay as they are.
  4. the stake/post (STAKE box, where there is one) is rigid on the ground: it is cut from
     the unshifted frame so it does not shift with the body.

Team colour: the strips carry the key reds directly (no mask file); pixels are only copied,
never recoloured, so the team snap stays exactly as import_art made it. Frame counts, cell
size and order are unchanged (ArtData does not change).

Safe to run twice (a still body re-aligns with zero shift). Run after fix_labourer_hoe.py.
    python3 tools/import_build_still.py [--before DIR]    (DIR: writes before-strips there too)
Needs Pillow and NumPy.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets/units/labourer")
CELL_W, CELL_H = 42, 35
DIRS = ["s", "se", "e", "ne", "n"]

# frame that gives the still body
BODY_FRAME = {"s": 0, "se": 0, "e": 0, "ne": 1, "n": 1}
# the box (x0, y0, x1, y1; exclusive) where the arm and tool live, per direction
ARM_BOX = {
    "s": (21, 12, 36, 30),
    "se": (21, 12, 36, 22),
    "e": (21, 9, 38, 23),
    "ne": (26, 0, 42, 28),
    "n": (21, 12, 36, 28),
}
# the rigid post the labourer strikes (cut from the unshifted frame): (x0, y0, x1, y1)
STAKE_BOX = {
    "s": (25, 24, 33, 35),
    "se": (24, 22, 33, 35),
    "e": (22, 23, 30, 35),
    "ne": None,
    "n": None,
}
MAX_SHIFT = 3


def split(strip):
    return [strip[:, i * CELL_W:(i + 1) * CELL_W].copy() for i in range(strip.shape[1] // CELL_W)]


def shifted(fr, dx, dy):
    out = np.zeros_like(fr)
    h, w = fr.shape[:2]
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = fr[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def mismatch(a, b, keep):
    """Pixels (inside keep) where a and b differ in coverage or colour."""
    aa, ba = a[..., 3] > 0, b[..., 3] > 0
    diff = (aa != ba) | (aa & ba & (np.abs(a[..., :3].astype(int) - b[..., :3].astype(int)).sum(-1) > 60))
    return int((diff & keep).sum())


def best_shift(fr, ref, keep):
    best = None
    for dy in range(-MAX_SHIFT, MAX_SHIFT + 1):
        for dx in range(-MAX_SHIFT, MAX_SHIFT + 1):
            c = mismatch(shifted(fr, dx, dy), ref, keep) + 0.01 * (abs(dx) + abs(dy))
            if best is None or c < best[0]:
                best = (c, dx, dy)
    return best[1], best[2]


def box_mask(box, shape=(CELL_H, CELL_W)):
    m = np.zeros(shape, bool)
    if box:
        x0, y0, x1, y1 = box
        m[y0:y1, x0:x1] = True
    return m


def still_strip(frames, d):
    ref = frames[BODY_FRAME[d]]
    arm = box_mask(ARM_BOX[d])
    stake = box_mask(STAKE_BOX[d])
    keep = ~arm & ~stake
    out = []
    for k, fr in enumerate(frames):
        if k == BODY_FRAME[d]:
            out.append(ref.copy())
            continue
        dx, dy = best_shift(fr, ref, keep)
        al = shifted(fr, dx, dy)
        o = ref.copy()
        region = arm & ~stake
        o[region] = al[region]
        o[stake] = ref[stake]
        out.append(o)
    # the reference frame's own stake/arm stay as drawn
    return out, ref


def main():
    before_dir = None
    src_dir = sys.argv[sys.argv.index("--src") + 1] if "--src" in sys.argv else None
    if "--before" in sys.argv:
        before_dir = sys.argv[sys.argv.index("--before") + 1]
        os.makedirs(before_dir, exist_ok=True)
    for d in DIRS:
        path = os.path.join(DIR, f"build_{d}.png")
        src = os.path.join(src_dir, f"build_{d}.png") if src_dir else path
        strip = np.array(Image.open(src).convert("RGBA"))
        if before_dir:
            Image.fromarray(strip).save(os.path.join(before_dir, f"build_{d}.png"))
        frames = split(strip)
        out, _ = still_strip(frames, d)
        Image.fromarray(np.concatenate(out, axis=1)).save(path)
        print(f"import_build_still: build_{d}: {len(out)} frames, body of frame {BODY_FRAME[d]}")


if __name__ == "__main__":
    main()
