"""The Crown Armoury (building, its build icon) and the Armoury's research icons and new portraits.

Building source: art/crown/armoury.png - the four states left to right (built, construction,
damaged, destroyed) on a flat navy background. Nothing on the sheet is placed by hand, so a
replacement sheet with the same layout (four drawings in a row, any spacing or size) imports
by re-running this script:
  * the four drawings are split at the three widest empty column runs between them (like the
    Engine Hall in import_round11.py);
  * one scale for all four, so the built Armoury drawing (yard and all) is WIDTH px wide -
    about the Barracks (4x3 tiles, 128 px wide);
  * every state is centred on its own plinth (building.gd centres the texture and stands its
    bottom on the footprint), navy fringe and specks cleaned, banners snapped to the two team
    key reds (snap_team);
  * the build button (assets/icons/armoury.png) is made from the built state, like the other
    buildings' icons (import_art.make_icon).
Output: assets/buildings/armoury_{built,construction,damaged,destroyed}.png, assets/icons/armoury.png

Icon source: art/ui/icons3/crown_armoury_icons.png - framed pictures, top row: socket bayonet,
artillery reload (cannon, powder bag, rammer), gunner's quadrant, cavalry charge, cavalry
breastplate stand; bottom row: the Horseman (feathered hat), the Guardsman (morion and
breastplate). Each is cut inside its frame and set in the Crown icons' steel bevel (the
round 11 machinery: import_round11.build_steel_icons does the same for its sheets).
Output: assets/icons/research_{bayonet,charges,quadrant,charge,armour}.png and the portraits
assets/icons/{horseman,guardsman}.png (guardsman.png is also copied to musketeer_armoured.png,
the armoured Musketeer's portrait on his card).

Usage (from the repo root): python3 tools/import_armoury.py [--contact DIR]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import import_round11 as r11  # noqa: E402
import import_round4 as r4  # noqa: E402
from import_art import load, make_icon  # noqa: E402
from import_cannon2 import bg_mask, clean, snap_team  # noqa: E402
import import_round5 as r5  # noqa: E402

CONTACT = _argv[_argv.index("--contact") + 1] if "--contact" in _argv else None
SRC = "art/crown/armoury.png"
ICONS = "art/ui/icons3/crown_armoury_icons.png"
STATES = ["built", "construction", "damaged", "destroyed"]
WIDTH = 136           # px: the built Armoury drawing, yard included (the Barracks drawing is 128 px wide)
ICON_NAMES = ["research_bayonet", "research_charges", "research_quadrant", "research_charge",
              "research_armour", "horseman", "guardsman"]


def pictures():
    px = load(SRC)
    bg, bgc = bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 6)[lab - 1] & (lab > 0))
    cols = fg.any(0)
    runs, x = [], 0
    while x < len(cols):
        if not cols[x]:
            s = x
            while x < len(cols) and not cols[x]:
                x += 1
            if s > 0 and x < len(cols):
                runs.append((x - s, s, x))
        x += 1
    cuts = sorted((s + e) // 2 for _, s, e in sorted(runs, reverse=True)[:3])
    P = [0] + cuts + [px.shape[1]]
    pics = []
    for a, b in zip(P[:-1], P[1:]):
        m = fg.copy()
        m[:, :a] = False
        m[:, b:] = False
        # the drawing: its biggest piece and whatever lies close to it (smoke drawn apart
        # from the chimney, loose stones); far specks go
        lab, n = ndimage.label(m, structure=np.ones((3, 3)))
        size = ndimage.sum(m, lab, np.arange(1, n + 1))
        main = lab == (int(np.argmax(size)) + 1)
        near = ndimage.binary_dilation(main, iterations=24)
        keep = np.isin(lab, np.unique(lab[near & m]))
        m &= keep
        ys, xs = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        img = px[y0:y1, x0:x1].copy()
        sel = m[y0:y1, x0:x1]
        img[~sel] = 0
        img[..., 3] = np.where(sel, 255, 0)
        pics.append((img.astype(np.uint8), r11.plinth(sel)))
    print(f"armoury panels: {P}")
    return pics, bgc


def build_armoury():
    pics, bgc = pictures()
    scale = WIDTH / pics[0][0].shape[1]
    out = {}
    for state, (img, (pl, pr)) in zip(STATES, pics):
        small, _ = r4.to_game(img, scale, bgc, None)
        small = snap_team(small)
        ys, xs = np.nonzero(small[..., 3] > 0)
        small = small[:ys.max() + 1]
        c = (pl + pr) / 2 * scale
        half = int(np.ceil(max(c - xs.min(), xs.max() + 1 - c)))
        W = 2 * half
        part = small[ys.min():]
        canvas = np.zeros((part.shape[0], W, 4), np.uint8)
        ox = int(round(half - c))
        canvas[:, max(0, ox):ox + part.shape[1]] = part[:, max(0, -ox):W - ox][:, :W - max(0, ox)]
        canvas = clean(canvas, min_size=3, keep_near=1)
        Image.fromarray(canvas, "RGBA").save(f"assets/buildings/armoury_{state}.png")
        out[state] = canvas
        print(f"armoury_{state}: {canvas.shape[1]}x{canvas.shape[0]} (scale {scale:.3f}, "
              f"plinth {(pr - pl) * scale:.0f} px)")
    # the build button from the built state
    make_icon(out["built"], "armoury")
    r5.flatten_icon("armoury")
    return out


def flat_bg(px, tol=6):
    """The icon sheet's flat navy, flooded in from the border. (import_cannon2.bg_mask also
    takes darker shades of it for ground shadows, and with them the frames' dark outer line
    and steel: the frame's edges would come out too far in.)"""
    rgb = px[..., :3].astype(float)
    bgc = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), 0)
    near = np.abs(rgb - bgc).max(-1) <= tol
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(edge))


def build_icons():
    px = load(ICONS)
    bg = flat_bg(px)
    made = {}
    for name, sl in zip(ICON_NAMES, r11.frame_boxes(px, bg, len(ICON_NAMES))):
        oy0, oy1, ox0, ox1 = r11.outer_edges(bg, sl)
        iy0, iy1, ix0, ix1 = r11.inner_box(px, oy0, oy1, ox0, ox1)
        pic = px[iy0:iy1, ix0:ix1].copy()
        made[name] = r11.save_icon(r11.framed(r11.shrink(r11.square(pic, name), r11.INNER)), name)
        print(f"icons/{name}.png: picture {ix1 - ix0}x{iy1 - iy0} at ({ix0}, {iy0})")
    shutil.copyfile("assets/icons/guardsman.png", "assets/icons/musketeer_armoured.png")
    return made


def main():
    b = build_armoury()
    ic = build_icons()
    if CONTACT:
        os.makedirs(CONTACT, exist_ok=True)
        bar = [np.array(Image.open(f"assets/buildings/barracks_{s}.png").convert("RGBA")) for s in STATES]
        H = max(x.shape[0] for x in bar + list(b.values()))
        pad = [np.concatenate([np.zeros((H - x.shape[0], x.shape[1], 4), np.uint8), x], 0) for x in bar + list(b.values())]
        icons = [np.array(Image.open(f"assets/icons/{k}.png").convert("RGBA"))
                 for k in ["armoury", "barracks"] + ICON_NAMES]
        r4.contact_sheet(os.path.join(CONTACT, "contact_armoury.png"),
                         [("barracks |\narmoury", pad), ("icons", icons)])


if __name__ == "__main__":
    main()
