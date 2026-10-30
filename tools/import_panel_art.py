#!/usr/bin/env python3
"""Import the owner's ChatGPT HUD frame sheet for one faction (docs/hud_panels.md).

    python3 tools/import_panel_art.py crown            # art/redraws/ui_panels_crown_chatgpt.png
    python3 tools/import_panel_art.py brood --sheet my.png --out /tmp/x

The sheet holds TWO frames on a transparent or flat background: a long thin frame on top
(the unit panel, about 7:1) and a squarer one below it (the command card, about 4:3).
It finds both (alpha, else distance from the corner colour), trims them, scales them (one scale, no squashing)
to the height of PANEL_SIZE / CARD_SIZE (2x the screen size) and writes
assets/ui/panels/<faction>_panel.png and <faction>_card.png. A flat background becomes
transparent. Then run `godot --headless --import` and tune PanelArt.MARGINS.
"""
import argparse
import os
import sys

from PIL import Image

PANEL_SIZE = (1600, 220)
CARD_SIZE = (520, 400)
ALPHA_CUT = 200          # alpha at or under this is background (the Brood sheet's glow)
FACTION_CORE = {"brood": 0.2}   # the Brood's claws and spikes stick out past its rope border
CORE = 0.5               # a frame's rows/columns hold at least this share of its fullest one (drops smudges)
FACTIONS = ("crown", "clockwork", "brood")


def mask_of(im):
    """1 where the art is: alpha when the sheet has real transparency, else not-background."""
    a = im.getchannel("A")
    lo, hi = a.getextrema()
    if lo < 16:
        # (> ALPHA_CUT: a soft glow halo round the frames, mostly low alpha, is not frame)
        return a.point(lambda v: 255 if v > ALPHA_CUT else 0)
    rgb = im.convert("RGB")
    w, h = rgb.size
    corners = [rgb.getpixel(p) for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))
    px = rgb.load()
    m = Image.new("L", (w, h), 0)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2]) > 40:
                mp[x, y] = 255
    return m


def row_bands(m):
    """Runs of rows holding art (gaps of background rows split frames)."""
    w, h = m.size
    small = m.resize((max(1, w // 4), h), Image.NEAREST)
    data = small.load()
    sw = small.size[0]
    full = [sum(1 for x in range(sw) if data[x, y]) > sw * 0.02 for y in range(h)]
    bands, start = [], None
    for y, on in enumerate(full + [False]):
        if on and start is None:
            start = y
        elif not on and start is not None:
            if y - start > h * 0.03:
                bands.append((start, y))
            start = None
    return bands


def find_frames(im):
    m = mask_of(im)
    bands = row_bands(m)
    if len(bands) < 2:
        sys.exit("found %d frame(s), want 2 (panel on top, card below)" % len(bands))
    # the two tallest bands, top one = panel
    bands = sorted(sorted(bands, key=lambda b: b[1] - b[0])[-2:])
    boxes = []
    for y0, y1 in bands:
        boxes.append(core_box(m, y0, y1))
    return m, boxes


def core_box(m, y0, y1):
    """The frame's box in rows y0..y1: the outermost rows and columns that are well filled, so
    faint junk (wavy smudges under a frame, stray dots) beside it is left out."""
    import numpy as np
    a = np.asarray(m.crop((0, y0, m.size[0], y1))) > 0
    cols = a.sum(axis=0)
    xs = np.nonzero(cols >= cols.max() * CORE)[0]
    x0, x1 = int(xs[0]), int(xs[-1]) + 1
    rows = a[:, x0:x1].sum(axis=1)
    ys = np.nonzero(rows >= rows.max() * CORE)[0]
    return (x0, y0 + int(ys[0]), x1, y0 + int(ys[-1]) + 1)


def cut(im, m, box, size):
    piece = im.crop(box)
    alpha = m.crop(box)
    if im.getchannel("A").getextrema()[0] >= 16:      # flat background: make it see-through
        piece.putalpha(alpha)
    else:                                             # glow under the cut: gone
        piece.putalpha(Image.composite(piece.getchannel("A"), Image.new("L", piece.size, 0), alpha))
    # one scale for both axes (the height of `size`): the corners keep their shape, and the
    # 9-slice stretches the middle in the game anyway
    k = size[1] / piece.size[1]
    return piece.resize((max(1, round(piece.size[0] * k)), size[1]), Image.LANCZOS)


def main():
    global CORE
    ap = argparse.ArgumentParser()
    ap.add_argument("faction", choices=FACTIONS)
    ap.add_argument("--sheet")
    ap.add_argument("--out", default="assets/ui/panels")
    ap.add_argument("--core", type=float, help="the CORE share (default %.2f; brood 0.2 keeps its claws)" % CORE)
    a = ap.parse_args()
    CORE = a.core if a.core is not None else FACTION_CORE.get(a.faction, CORE)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sheet = a.sheet or os.path.join(root, "art/redraws/ui_panels_%s_chatgpt.png" % a.faction)
    out = a.out if os.path.isabs(a.out) else os.path.join(root, a.out)
    im = Image.open(sheet).convert("RGBA")
    m, (pb, cb) = find_frames(im)
    pw, ph = pb[2] - pb[0], pb[3] - pb[1]
    cw, ch = cb[2] - cb[0], cb[3] - cb[1]
    print("panel %dx%d at %s (%.1f:1), card %dx%d at %s (%.2f:1)" % (pw, ph, pb[:2], pw / ph, cw, ch, cb[:2], cw / ch))
    if pw / ph < 3:
        print("WARNING: the top frame is not long and thin; is the sheet the right way up?")
    os.makedirs(out, exist_ok=True)
    for name, box, size in (("panel", pb, PANEL_SIZE), ("card", cb, CARD_SIZE)):
        p = os.path.join(out, "%s_%s.png" % (a.faction, name))
        piece = cut(im, m, box, size)
        piece.save(p)
        print("wrote", p, piece.size)


if __name__ == "__main__":
    main()
