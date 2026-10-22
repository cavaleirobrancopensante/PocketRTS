"""The Crown labourer's pickaxe made into a hoe (he farms with it).

import_art.py cuts the labourer's frames from art/crown/labourer.png, where he swings a
pickaxe. A hoe has a single flat blade bent down from the end of the handle, so here the
pick's other arm (the spike on the far side of the handle, the one pointing up or back)
is cut away in every frame that shows the tool: the mine swing in all five facings and
the idle stance where he holds it at his side.

Each edit is a small box (frame-local pixels, x0, y0, x1, y1 inclusive) round that spike;
inside it only iron-coloured pixels (grey or near-black outline) are cleared, so the hat,
hands and handle are never touched. Clearing is idempotent: running this twice is the same
as running it once. Run after import_art.py (tools/rebuild_art.sh does).
"""
import colorsys
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DIR = os.path.join(ROOT, "assets/units/labourer")
CELL = 42  # labourer cell width (scripts/art_data.gd)

# anim -> {frame: [(x0, y0, x1, y1), ...]}
EDITS = {
    # mine: frame 0 raised, 1 mid-swing, 2 the strike (the blade is in the ground, the
    # spike points up out of it)
    "mine_s": {0: [(25, 2, 27, 5)], 1: [(28, 3, 34, 7), (35, 4, 35, 6)], 2: [(33, 23, 37, 26)]},
    "mine_se": {0: [(29, 2, 33, 6), (34, 4, 34, 6)], 1: [(23, 5, 28, 7)], 2: [(30, 14, 34, 18)]},
    "mine_e": {0: [(32, 8, 36, 11), (37, 8, 37, 10)], 1: [(33, 15, 35, 16)], 2: [(35, 17, 38, 21)]},
    "mine_ne": {1: [(33, 11, 37, 14)], 2: [(33, 18, 36, 22)]},
    "mine_n": {0: [(27, 2, 29, 5)], 1: [(29, 7, 33, 10)], 2: [(29, 23, 33, 26)]},
    # idle: the tool held at his side, head at the end of the handle; the spike is the
    # arm above the handle, the blade the one hanging below it. (idle_s / idle_n show
    # only a grey shaft, and idle_ne frame 0 the handle's end: nothing to cut there.)
    "idle_se": {0: [(32, 24, 33, 25)], 1: [(32, 23, 33, 25)]},
    "idle_e": {0: [(31, 16, 35, 19)], 1: [(32, 15, 35, 18)]},
    "idle_ne": {1: [(30, 10, 34, 12)]},
}


def is_iron(px):
    r, g, b, a = px
    if a < 20:
        return False
    _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v < 0.25 or s < 0.25


def main():
    for anim, frames in EDITS.items():
        path = os.path.join(DIR, anim + ".png")
        im = Image.open(path).convert("RGBA")
        px = im.load()
        n = 0
        for f, boxes in frames.items():
            for x0, y0, x1, y1 in boxes:
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        X = f * CELL + x
                        if is_iron(px[X, y]):
                            px[X, y] = (0, 0, 0, 0)
                            n += 1
        im.save(path)
        print(f"fix_labourer_hoe: {anim}: {n} pick pixels cleared")


if __name__ == "__main__":
    main()
