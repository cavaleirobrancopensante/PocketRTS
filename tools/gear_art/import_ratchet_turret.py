"""Slice the Ratchet Turret and its screw shot out of the ChatGPT sheets (navy background RGB 0,22,48) and import them.

  art/redraws/ratchet_turret.png (1536x1024, drawn at 3x):
    row 1: the BASE alone, 4 cells (built, under construction, damaged, destroyed: the head lies in the rubble)
    row 2: the HEAD alone, 5 cells facing S, SE, E, NE, N (W/SW/NW are mirrors of E/SE/NE, like the units)
  art/redraws/jack_screw_fx.png (1536x1024, drawn at 4x):
    row 1: 4 frames of the screw spinning (pointing right), row 2: 4 frames muzzle burst, row 3: 4 frames impact sparks

The cells are not exactly on a grid, so the figures are found as connected components of the keyed mask (each figure's
loose bits, smoke and rubble joined by a dilation) and each component goes to the cell its centre falls in.

Writes
  art/clockwork/gear/ratchet_turret_{built,construct,damaged,destroyed}.png  base at 3x, bottom-centre on one canvas
  art/clockwork/gear/ratchet_turret_head_{s,se,e,ne,n}.png                 head at 3x, its round bottom collar's centre
                                                                            at the canvas centre
  art/clockwork/gear/screw_{fly,muzzle,impact}_{0..3}.png                   the fx frames at 4x
  assets/buildings/ratchet_turret_{built,construction,damaged,destroyed}.png  the game's base sprites (1/3)
  assets/buildings/ratchet_turret_head_<dir>.png                              the game's head sprites (1/4, collar centred)
  assets/effects/screw.png, screw_muzzle.png, screw_impact.png                game strips (1/4; ArtData.EFFECTS sizes printed)
  assets/icons/ratchet_turret.png                                             64x64 card portrait (base + head S)
  python3 tools/gear_art/import_ratchet_turret.py"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NAVY = np.array([0, 22, 48])
GEAR = 'art/clockwork/gear/'
HEAD_DIRS = ['s', 'se', 'e', 'ne', 'n']
BASE_STATES = ['built', 'construct', 'damaged', 'destroyed']
GAME_STATE = {'built': 'built', 'construct': 'construction', 'damaged': 'damaged', 'destroyed': 'destroyed'}


def figures(path, rows, cols_per_row, join=20, min_px=12):
    """[[RGBA crop, (x0, y0)] per cell] per row: every component (a pixel group off the navy) goes to the cell its centre
    falls in (rows split the height evenly, each row's width split in cols_per_row[r])."""
    rgb = np.array(Image.open(path).convert('RGB')).astype(int)
    H, W = rgb.shape[:2]
    m = np.abs(rgb - NAVY).sum(2) >= 40
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=join))
    cells = [[np.zeros((H, W), bool) for _ in range(cols_per_row[r])] for r in range(rows)]
    for i, sl in enumerate(ndi.find_objects(lab)):
        part = m & (lab == i + 1)
        if part.sum() < min_px:
            continue
        ys, xs = np.nonzero(part)
        r = min(rows - 1, int(ys.mean() / (H / rows)))
        c = min(cols_per_row[r] - 1, int(xs.mean() / (W / cols_per_row[r])))
        cells[r][c] |= part
    out = []
    for r in range(rows):
        row = []
        for c in range(cols_per_row[r]):
            cm = cells[r][c]
            ys, xs = np.nonzero(cm)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
            o[..., :3] = rgb[y0:y1, x0:x1]
            o[..., 3] = cm[y0:y1, x0:x1] * 255
            row.append([Image.fromarray(o, 'RGBA'), (x0, y0)])
        out.append(row)
    return out


def on_canvas(ims, anchors, w, h, at):
    """Each image pasted so its anchor lands on `at` of a w x h canvas."""
    res = []
    for im, a in zip(ims, anchors):
        o = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        o.paste(im, (int(round(at[0] - a[0])), int(round(at[1] - a[1]))), im)
        res.append(o)
    return res


def collar(im):
    """The head's round bottom collar: its centre (x, y) in the crop. x: the middle of the figure's span over its lowest
    15% of rows (the collar is the widest, lowest part; the screw never reaches down there); y: an eighth of the head's
    height up from its bottom edge (the collar is about the lowest quarter of the head)."""
    a = np.array(im)[..., 3] > 0
    h = a.shape[0]
    band = a[int(h * 0.85):]
    xs = np.nonzero(band.any(0))[0]
    cx = (xs.min() + xs.max() + 1) * 0.5
    cy = h - h * 0.125
    return cx, cy


def rings(im):
    """The centroid of a muzzle frame's brass (orange) pixels: its muzzle rings."""
    a = np.array(im).astype(int)
    m = (a[..., 3] > 0) & (a[..., 0] > 140) & (a[..., 1] > 60) & (a[..., 1] < 190) & (a[..., 2] < 90) & (a[..., 0] - a[..., 2] > 90)
    ys, xs = np.nonzero(m)
    return float(xs.mean()), float(ys.mean())


def main():
    sheet = figures('art/redraws/ratchet_turret.png', 2, [4, 5])
    # the base: bottom-centre on one canvas
    bases = [f[0] for f in sheet[0]]
    bw = max(b.width for b in bases) + 4
    bh = max(b.height for b in bases) + 4
    framed = on_canvas(bases, [(b.width * 0.5, b.height) for b in bases], bw, bh, (bw * 0.5, bh - 2))
    for st, im in zip(BASE_STATES, framed):
        im.save(GEAR + 'ratchet_turret_%s.png' % st)
    # the game's base sprites: one crop for all (symmetric about the centre line, down to the bottom), 1/3
    left, top = bw, bh
    for im in framed:
        bb = im.getbbox()
        left = min(left, bb[0], bw - bb[2])
        top = min(top, bb[1])
    box = (left, top, bw - left, bh)
    size = (round((box[2] - box[0]) / DOWN), round((box[3] - box[1]) / DOWN))
    game_base = {}
    for st, im in zip(BASE_STATES, framed):
        g = im.crop(box).resize(size, Image.LANCZOS)
        g.save('assets/buildings/ratchet_turret_%s.png' % GAME_STATE[st])
        game_base[st] = g
    print('base canvas', bw, bh, 'game', size)
    # the heads: collar centre at the canvas centre
    heads = [f[0] for f in sheet[1]]
    anchors = [collar(h) for h in heads]
    half_w = max(max(a[0], h.width - a[0]) for h, a in zip(heads, anchors)) + 2
    half_h = max(max(a[1], h.height - a[1]) for h, a in zip(heads, anchors)) + 2
    # (a multiple of 2 * DOWN: the centre stays on a whole game px)
    hw, hh = int(np.ceil(half_w / DOWN)) * 2 * DOWN, int(np.ceil(half_h / DOWN)) * 2 * DOWN
    framed_h = on_canvas(heads, anchors, hw, hh, (hw * 0.5, hh * 0.5))
    game_head = {}
    for dr, im in zip(HEAD_DIRS, framed_h):
        im.save(GEAR + 'ratchet_turret_head_%s.png' % dr)
        g = im.resize((hw // DOWN, hh // DOWN), Image.LANCZOS)
        g.save('assets/buildings/ratchet_turret_head_%s.png' % dr)
        game_head[dr] = g
    print('head canvas', hw, hh, 'game', hw // DOWN, hh // DOWN, 'collars', [(round(a[0]), round(a[1])) for a in anchors])
    # the card portrait: the built base with the head S on its turntable (TURRET_HEAD_AT below), square, 64 px
    comp = game_base['built'].copy()
    hx = comp.width * 0.5 + HEAD_AT[0]
    hy = comp.height - 6 + HEAD_AT[1]        # (Building.body_offset: the base's bottom sits 6 px below the anchor)
    hd = game_head['s']
    comp.alpha_composite(hd, (int(round(hx - hd.width * 0.5)), int(round(hy - hd.height * 0.5)))) if hy - hd.height * 0.5 >= 0 else None
    bb = comp.getbbox()
    side = max(bb[2] - bb[0], bb[3] - bb[1])
    cx, cy = (bb[0] + bb[2]) * 0.5, (bb[1] + bb[3]) * 0.5
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(comp.crop(bb), (int((side - (bb[2] - bb[0])) / 2), int((side - (bb[3] - bb[1])) / 2)))
    sq.resize((64, 64), Image.LANCZOS).save('assets/icons/ratchet_turret.png')

    # the screw shot: 3 rows of 4
    fx = figures('art/redraws/jack_screw_fx.png', 3, [4, 4, 4])
    for r, (name, align) in enumerate([('screw', 'centre'), ('screw_muzzle', 'rings'), ('screw_impact', 'centre')]):
        ims = [f[0] for f in fx[r]]
        tag = ['fly', 'muzzle', 'impact'][r]
        for i, im in enumerate(ims):
            im.save(GEAR + 'screw_%s_%d.png' % (tag, i))
        if align == 'rings':
            # the burst is aligned on its brass rings (the barrel's muzzle ring in every frame), which land on the cell's
            # MUZZLE_AT share of its width, half way down: the game puts that point on the barrel tip
            anc = [rings(im) for im in ims]
            left = max(a[0] for a in anc) + 2
            right = max(im.width - a[0] for im, a in zip(ims, anc)) + 2
            half = max(max(a[1], im.height - a[1]) for im, a in zip(ims, anc)) + 2
            w, h = int(np.ceil(left + right)), int(np.ceil(half)) * 2
            cells = on_canvas(ims, anc, w, h, (left, h * 0.5))
            print('muzzle rings at %.3f of the cell width' % (left / w))
        else:
            w = max(im.width for im in ims) + 4
            h = max(im.height for im in ims) + 4
            cells = on_canvas(ims, [(im.width * 0.5, im.height * 0.5) for im in ims], w, h, (w * 0.5, h * 0.5))
        cw, ch = int(round(w / 4.0)), int(round(h / 4.0))
        strip = Image.new('RGBA', (cw * 4, ch), (0, 0, 0, 0))
        for i, c in enumerate(cells):
            strip.paste(c.resize((cw, ch), Image.LANCZOS), (i * cw, 0))
        strip.save('assets/effects/%s.png' % name)
        print('"%s": {"frames": 4, "size": Vector2i(%d, %d)},' % (name, cw, ch))


# where the head's collar centre sits on the built base, game px from the building's anchor (its footprint's bottom
# centre): found by eye on the built base's turntable (keep in step with Defs.TURRET "head_at")
HEAD_AT = (0, -70)
DOWN = 4        # the sheet is drawn at 4x the game's size for a squat 2x2 (3x, like the 3x3 buildings, stood far over it)

if __name__ == '__main__':
    main()
