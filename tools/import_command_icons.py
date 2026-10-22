#!/usr/bin/env python3
"""Command icons from art/ui/icons2/commands_extra.png (3x2, steel frames):
hold_fire, fire_at_will, hold / patrol, rally, demolish -> assets/icons/<name>.png (64x64),
cut and reframed exactly like the Crown ability icons (tools/import_round11.py)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import import_round11 as r

NAMES = ["hold_fire", "fire_at_will", "hold", "patrol", "rally", "demolish"]


def main():
    px = r.load(f"{r.SRC}/commands_extra.png")
    bg, _ = r.bg_mask(px)
    for name, sl in zip(NAMES, r.frame_boxes(px, bg, len(NAMES))):
        oy0, oy1, ox0, ox1 = r.outer_edges(bg, sl)
        iy0, iy1, ix0, ix1 = r.inner_box(px, oy0, oy1, ox0, ox1)
        pic = px[iy0:iy1, ix0:ix1].copy()
        r.save_icon(r.framed(r.shrink(r.square(pic, name), r.INNER)), name)
        print(f"icons/{name}.png: frame {ox1 - ox0}x{oy1 - oy0} at ({ox0}, {oy0})")


if __name__ == "__main__":
    main()
