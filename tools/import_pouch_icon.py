"""The Shot Pouch research icon: art/crown/research_pouch_icon.png (one framed picture on a
navy backdrop, the designer's sheet) is cut inside its frame and set in the Crown icons'
steel bevel, exactly like the Armoury's other research icons (import_armoury.build_icons).
Output: assets/icons/research_pouch.png. Re-runnable (from the repo root).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import import_round11 as r11  # noqa: E402
from import_art import load  # noqa: E402
from import_armoury import flat_bg  # noqa: E402

SRC = "art/crown/research_pouch_icon.png"


def main():
    px = load(SRC)
    bg = flat_bg(px)
    sl = r11.frame_boxes(px, bg, 1)[0]
    oy0, oy1, ox0, ox1 = r11.outer_edges(bg, sl)
    iy0, iy1, ix0, ix1 = r11.inner_box(px, oy0, oy1, ox0, ox1)
    pic = px[iy0:iy1, ix0:ix1].copy()
    r11.save_icon(r11.framed(r11.shrink(r11.square(pic, "research_pouch"), r11.INNER)), "research_pouch")
    print(f"icons/research_pouch.png: picture {ix1 - ix0}x{iy1 - iy0} at ({ix0}, {iy0})")


if __name__ == "__main__":
    main()
