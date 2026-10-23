"""The Brood Queen, who sits beside the capital Burrow (Game.capital): a still sprite for now.

Reads art/brood/queen.png (one picture on a baked-in white / grey checker backdrop, no real alpha)
and writes assets/buildings/brood_queen.png: the backdrop keyed out from the picture's border
(only the near-white, unsaturated pixels joined to it, so the pale bone spines stay), cropped to
the content and scaled to QUEEN_W game px wide (about a third of a Burrow), team-neutral (no
team key colours: the red crest is her own). BuildingLife.QUEEN_ART draws it at the capital's
front corner, on every hall level (scaled with the hall).

Usage (from the repo root): python3 tools/import_queen.py
Then open the project in Godot once (or run it headless) so the new PNG gets imported.
"""
import os
from collections import deque

import numpy as np
from PIL import Image

SRC = "art/brood/queen.png"
OUT = "assets/buildings/brood_queen.png"
QUEEN_W = 64          # game px wide (the Burrow sprite is 158 wide)
SAT_MAX = 0.10        # backdrop: unsaturated ...
VAL_MIN = 0.80        # ... and light


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    if not os.path.exists(SRC):
        print("no", SRC, ": nothing to do")
        return
    im = Image.open(SRC).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255.0
    mx, mn = a.max(2), a.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    cand = (sat < SAT_MAX) & (mx > VAL_MIN)
    h, w = cand.shape
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if cand[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if cand[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    rgba = np.dstack([np.asarray(im), alpha])
    out = Image.fromarray(rgba, "RGBA")
    out = out.crop(out.getchannel("A").getbbox())
    scale = QUEEN_W / out.width
    out = out.resize((QUEEN_W, max(1, round(out.height * scale))), Image.LANCZOS)
    # a clean edge: anything left faint is cut
    al = np.asarray(out.getchannel("A")).copy()
    al[al < 96] = 0
    al[al >= 96] = 255
    out.putalpha(Image.fromarray(al))
    out.save(OUT)
    print("%s: %dx%d" % (OUT, out.width, out.height))


if __name__ == "__main__":
    main()
