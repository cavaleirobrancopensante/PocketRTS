#!/usr/bin/env python3
"""Command icons from art/ui/icons2/commands_extra.png (3x2, steel frames):
hold_fire, fire_at_will, hold / patrol, rally, demolish, plus command_stop.png (stop) and
command_cancel.png (cancel) -> assets/icons/<name>.png (64x64),
cut and reframed exactly like the Crown ability icons (tools/import_round11.py)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import import_round11 as r

SHEETS = {"commands_extra": ["hold_fire", "fire_at_will", "hold_old", "patrol", "rally", "demolish"],
          "command_stop": ["stop"],        # (replaces the stop hand from icons.png)
          "command_cancel": ["cancel"],
          "command_back": ["back"],
          "command_hold": ["hold"]}       # (the bold shield; commands_extra's hold is unused)


def main():
  for sheet, names in SHEETS.items():
    px = r.load(f"{r.SRC}/{sheet}.png")
    bg, _ = r.bg_mask(px)
    for name, sl in zip(names, r.frame_boxes(px, bg, len(names))):
        oy0, oy1, ox0, ox1 = r.outer_edges(bg, sl)
        iy0, iy1, ix0, ix1 = r.inner_box(px, oy0, oy1, ox0, ox1)
        pic = px[iy0:iy1, ix0:ix1].copy()
        if name.endswith("_old"):
            continue
        r.save_icon(r.framed(r.shrink(r.square(pic, name), r.INNER)), name)
        print(f"icons/{name}.png: frame {ox1 - ox0}x{oy1 - oy0} at ({ox0}, {oy0})")


if __name__ == "__main__":
    main()
