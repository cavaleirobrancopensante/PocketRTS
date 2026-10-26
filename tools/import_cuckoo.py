"""Import the Cuckoo's and the Ticking Owl's sheets (art/redraws/*, ChatGPT, navy background RGB 0,22,48, rows = directions
S SE E NE N; the west views are the east ones mirrored in the game) into the game's unit strips:
  assets/units/cuckoo/{idle,walk,attack,death}_{s,se,e,ne,n}.png
  assets/units/ticking_owl/{idle,walk,attack,bomb,death}_{s,se,e,ne,n}.png
(frames side by side, one canvas per kind), the bomb's effects assets/effects/owl_bomb.png (the weight falling, 4 frames)
and assets/effects/owl_blast.png (the explosion, 8 frames, the impact point in the middle of each cell), the card icons
assets/icons/{cuckoo,ticking_owl,research_ticking_owl,ab_morph_owl}.png, and prints the scripts/cw_art.gd SHEETS lines, the
Defs.OWL "drop" points (where the pendulum weight hangs, per drawn direction) and the effect sizes for ArtData.EFFECTS.

  fly     cuckoo_fly.png / ticking_owl_fly.png     5 x 4 (384 x 204.8 cells): wings up, level, down, level: the loop for
                                                    both idle and walk (the game flaps it at its own pace)
  attack  cuckoo_attack.png                         5 x 6 (256 x 204): pull back, lunge (the hit on the 3rd frame)
          owl_swoop.png                             5 x 6, drawn at 0.85 of the fly sheet: rise, wind up, dive, strike low
                                                    (the hit on the 4th frame), climb back
  bomb    owl_bomb.png                              5 x 6 at 0.85: the chain snaps on the 2nd frame; the falling weight
                                                    painted on the 2nd and 3rd frames is taken off (the game drops a real
                                                    one from where it hung), the owl bobs up, a new weight is lowered
  death   cuckoo_death_final.png / owl_death_final.png   5 x 6 (the owl's at 0.85): hit, spin, fall (frames 1-4, still in
                                                    the air: the game brings the sprite down), the wreck on the ground
                                                    (frames 5-6; the last one is the corpse)

Per frame: key out the navy (tolerance 40) and the dark oval shadow ChatGPT drew under the bird (the game draws its own
air shadow), keep the figure (its big pieces and its bright small ones: feathers, cogs and sparks flying off), and ALIGN
IT ON THE BODY: every frame of a direction is shifted so its body (the red case with the clock dial, holes filled: seen
from the front the dial splits the red in two) lies best on the fly loop's first frame's (overlap), so nothing jitters; the motion of the lunge, the swoop, the bob and the fall is the game's (code), not the
drawing's. The anchor (the unit's point) is the bottom of the figure under the body on the first fly frame: the game
lifts it to the flyers' height over its shadow. The wreck frames (death 5-6) sit with their middle on the anchor (on the
ground). Shrink to game size (a wingspan of SPAN px with the wings level), snap the team reds to the shader's key reds.
  python3 tools/import_cuckoo.py [preview.png]"""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = 'art/redraws/'
NAVY = np.array([0, 22, 48])
TOL = 40
DIRS = ['s', 'se', 'e', 'ne', 'n']
TEAM_LIGHT = (255, 0, 0)
TEAM_DARK = (150, 0, 0)
UP = 1.0 / 0.85          # the owl's swoop, bomb and death sheets were drawn at 0.85 of its fly sheet

# kind: the wingspan in game px of the level-wing fly frame (S view), and its sheets: anim -> (file, columns, scale up to the
# fly sheet's). The owl is the heavy flyer: bigger than the Cuckoo (its fly sheet is drawn about 1.18x the Cuckoo's).
KINDS = {
    'cuckoo': {'span': 62.0, 'sheets': {
        'fly': ('cuckoo_fly.png', 4, 1.0),
        'attack': ('cuckoo_attack.png', 6, 1.0),
        'death': ('cuckoo_death_final.png', 6, 1.0)}},
    'ticking_owl': {'span': 84.0, 'sheets': {
        'fly': ('ticking_owl_fly.png', 4, 1.0),
        'attack': ('owl_swoop.png', 6, UP),
        'bomb': ('owl_bomb.png', 6, UP),
        'death': ('owl_death_final.png', 6, UP)}},
}
GROUND = [4, 5]          # death frames on the ground (0-based)
WRECK_MID = 0.32         # the wreck's middle (the anchor) this share of its height up from its bottom
DROPPED = [1, 2]         # bomb frames whose painted falling weight is taken off (0-based)


def red_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r >= 110) & (g <= r * 0.35) & (b <= r * 0.4)


def keyed(rgb):
    """The figure mask: off the navy, and not the dark oval shadow (its blue-black tone in a flat solid blob)."""
    m = np.abs(rgb - NAVY).sum(2) >= TOL
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    st = (r <= 15) & (g <= 18) & (b <= 45) & (b - g >= 10)
    op = ndi.binary_opening(st, structure=np.ones((3, 3)), iterations=2)
    lab, n = ndi.label(op)
    shadow = np.zeros_like(m)
    for i, sl in enumerate(ndi.find_objects(lab)):
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if (lab[sl] == i + 1).sum() >= 60 and w >= 1.8 * h:
            shadow[sl] |= lab[sl] == i + 1
    loose = (r <= 25) & (g <= 25) & (b <= 55) & (b - g >= 6)
    shadow = ndi.binary_dilation(shadow, iterations=2) & loose
    return m & ~shadow


def figures(path, rows, cols):
    """[row][col] -> (rgba crop, (x0, y0) in the sheet): the main figures are the big pieces, clustered into rows and
    columns by their centres (ChatGPT's grid is not exact: figures cross the cell lines); every smaller piece kept (bright
    ones of 20 px or more, any of 200 or more) goes to the nearest figure."""
    rgb = np.array(Image.open(path).convert('RGB')).astype(int)
    H, W = rgb.shape[:2]
    m = keyed(rgb)
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    objs = ndi.find_objects(lab)
    pieces = []
    for i, sl in enumerate(objs):
        part = lab[sl] == i + 1
        sz = int(sizes[i])
        if sz < 200:
            bright = rgb[sl][part].sum(1).mean()
            if sz < 20 or bright < 90:
                continue
        ys, xs = np.nonzero(part)
        pieces.append({'sl': sl, 'part': part, 'size': sz, 'cy': ys.mean() + sl[0].start, 'cx': xs.mean() + sl[1].start})
    # the main body of each frame: the biggest piece in each grid cell (by its centre)
    mains = {}
    for p in pieces:
        r = min(rows - 1, int(p['cy'] / (H / rows)))
        c = min(cols - 1, int(p['cx'] / (W / cols)))
        if p['size'] >= 1200 and ((r, c) not in mains or mains[(r, c)]['size'] < p['size']):
            mains[(r, c)] = p
    assert len(mains) == rows * cols, '%s: %d main figures, expected %d' % (path, len(mains), rows * cols)
    groups = {k: [] for k in mains}
    for p in pieces:
        best = min(mains, key=lambda k: (mains[k]['cx'] - p['cx']) ** 2 + (mains[k]['cy'] - p['cy']) ** 2 * 1.5)
        groups[best].append(p)
    out = [[None] * cols for _ in range(rows)]
    for (r, c), parts in groups.items():
        y0 = min(p['sl'][0].start for p in parts)
        y1 = max(p['sl'][0].stop for p in parts)
        x0 = min(p['sl'][1].start for p in parts)
        x1 = max(p['sl'][1].stop for p in parts)
        mm = np.zeros((y1 - y0, x1 - x0), bool)
        main = np.zeros((y1 - y0, x1 - x0), bool)
        for p in parts:
            sl = p['sl']
            mm[sl[0].start - y0:sl[0].stop - y0, sl[1].start - x0:sl[1].stop - x0] |= p['part']
            if p is mains[(r, c)]:
                main[sl[0].start - y0:sl[0].stop - y0, sl[1].start - x0:sl[1].stop - x0] |= p['part']
        sub = rgb[y0:y1, x0:x1]
        # holes inside the figure that are not the navy itself stay solid (dark glass, shadowed coils)
        mm = (ndi.binary_fill_holes(mm) & (np.abs(sub - NAVY).sum(2) >= 12)) | mm
        o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        o[..., :3] = sub
        o[..., 3] = mm * 255
        out[r][c] = {'o': o, 'xy': (x0, y0), 'main': main}
    return out


def body(o):
    """The body, solid: the red case and the clock dial in it (the dial splits the red into two halves seen from the
    front, which would let a ring of red match itself half a body off), holes filled; its biggest blob."""
    a = o[..., :3].astype(int)
    al = o[..., 3] > 0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dial = (r >= 190) & (g >= 170) & (b >= 120) & (np.abs(r - g) < 50)
    rm = (red_mask(a) | dial) & al
    rm = ndi.binary_fill_holes(ndi.binary_closing(rm, iterations=2)) & al
    lab, n = ndi.label(rm)
    if n == 0:
        return None
    sz = ndi.sum(rm, lab, range(1, n + 1))
    return lab == int(np.argmax(sz)) + 1


def scaled_mask(m, s):
    if abs(s - 1.0) < 1e-6:
        return m
    h, w = m.shape
    return np.array(Image.fromarray((m * 255).astype(np.uint8)).resize((max(1, round(w * s)), max(1, round(h * s))), Image.NEAREST)) > 127


def align(ref, m):
    """The shift t (ref px) that lays mask m (already at the ref's scale, its own crop coordinates) best on ref: a point x of
    m lies at x + t in ref's coordinates. Starts from the centroids, then searches +-14 px for the best overlap (IoU)."""
    ry, rx = np.nonzero(ref)
    my, mx = np.nonzero(m)
    t0 = (round(rx.mean() - mx.mean()), round(ry.mean() - my.mean()))
    best, bt = -1.0, t0
    # paint ref into a padded grid, look up the shifted pixels of m
    pad = 60
    H = max(ref.shape[0], m.shape[0]) + 2 * pad + 40
    W = max(ref.shape[1], m.shape[1]) + 2 * pad + 40
    grid = np.zeros((H, W), bool)
    grid[pad:pad + ref.shape[0], pad:pad + ref.shape[1]] = ref
    nr = ref.sum()
    for dy in range(-14, 15):
        for dx in range(-14, 15):
            tx, ty = t0[0] + dx, t0[1] + dy
            yy, xx = my + ty + pad, mx + tx + pad
            ok = (yy >= 0) & (yy < H) & (xx >= 0) & (xx < W)
            inter = grid[yy[ok], xx[ok]].sum()
            iou = inter / float(nr + len(my) - inter)
            if iou > best:
                best, bt = iou, (tx, ty)
    return bt, best


def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then hard alpha (tools/import_jack.py)."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.45, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def snap_team(img):
    """The red body -> the exact key reds the shader recolours (light and dark; its dark shading to the dark key)."""
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    red = (img[..., 3] > 0) & (r >= 60) & (g <= r * 0.3) & (b <= r * 0.35)
    light = red & (r >= 175)
    img[light, :3] = TEAM_LIGHT
    img[red & ~light, :3] = TEAM_DARK
    return img


def weight_centre(o, main):
    """The pendulum weight under the owl: the dark grey ball at the bottom of the main figure. Its centre in crop px."""
    r, g, b = o[..., 0].astype(int), o[..., 1].astype(int), o[..., 2].astype(int)
    grey = (o[..., 3] > 0) & (r >= 25) & (r <= 130) & (np.abs(r - g) <= 22) & (np.abs(g - b) <= 28) & main
    ys, xs = np.nonzero(main)
    low = ys >= ys.min() + (ys.max() - ys.min()) * 0.62
    cand = np.zeros_like(grey)
    cand[ys[low], xs[low]] = True
    m = grey & cand
    lab, n = ndi.label(ndi.binary_closing(m, iterations=2))
    if n == 0:
        return None
    sz = ndi.sum(m, lab, range(1, n + 1))
    k = int(np.argmax(sz)) + 1
    yy, xx = np.nonzero(lab == k)
    return xx.mean() + 0.5, yy.mean() + 0.5


def drop_bombs(o, main):
    """The bomb frames 2-3: the weight already falling (a piece below the owl, apart from it) is taken off."""
    alpha = o[..., 3] > 0
    lab, n = ndi.label(alpha)
    keep = np.zeros_like(alpha)
    my = np.nonzero(main)[0]
    body_low = my.min() + (my.max() - my.min()) * 0.7
    for i, sl in enumerate(ndi.find_objects(lab)):
        part = lab[sl] == i + 1
        ys = np.nonzero(part)[0] + sl[0].start
        overlaps_main = (part & main[sl]).any()
        if overlaps_main or ys.mean() < body_low:
            keep[sl] |= part
    o = o.copy()
    o[~keep] = 0
    return o


def import_kind(kind, info, preview):
    sheets = info['sheets']
    figs = {a: figures(SRC + f, 5, cols) for a, (f, cols, up) in sheets.items()}
    frames = {}          # (anim, dir) -> [(rgba, ax, ay, up)]
    drop = {}
    report = []
    for row, d in enumerate(DIRS):
        ref_f = figs['fly'][row][0]
        ref = body(ref_f['o'])
        ry, rx = np.nonzero(ref)
        c0 = (rx.mean(), ry.mean())
        # the anchor: under the body at the bottom of the figure's main piece (the feet, the owl's weight)
        mys, mxs = np.nonzero(ref_f['main'])
        near = np.abs(mxs - c0[0]) <= 12
        bottom = float(mys[near].max() + 1)
        A0 = (c0[0], bottom)
        for anim, (f, cols, up) in sheets.items():
            out = []
            for c in range(cols):
                fr = figs[anim][row][c]
                o = fr['o']
                if anim == 'bomb' and c in DROPPED:
                    o = drop_bombs(o, fr['main'])
                if anim == 'death' and c in GROUND:
                    bm = body(o)
                    by, bx = np.nonzero(bm)
                    my_, mx_ = np.nonzero(fr['main'])
                    h = my_.max() + 1 - my_.min()
                    ax, ay = bx.mean(), (my_.max() + 1) - WRECK_MID * h
                    out.append((o, ax, ay, up))
                    continue
                bm = body(o)
                t, iou = align(ref, scaled_mask(bm, up))
                report.append((anim, d, c, round(iou, 2), t))
                # the anchor in this frame's own crop (its scale): A0 - t in ref px, divided by up
                ax, ay = (A0[0] - t[0]) / up, (A0[1] - t[1]) / up
                out.append((o, ax, ay, up))
                if anim == 'bomb' and c == 0:
                    w = weight_centre(o, fr['main'])
                    if w is not None:
                        drop[d] = ((w[0] - ax) * up, (w[1] - ay) * up)     # ref px from the anchor
            frames[(anim, d)] = out
    # the scale: the S level-wing fly frame (the 2nd) is SPAN px wide
    o1 = figs['fly'][0][1]['main']
    xs = np.nonzero(o1.any(0))[0]
    scale = info['span'] / float(xs.max() + 1 - xs.min())
    # one canvas: the farthest any frame reaches from its anchor (in game px)
    L = R = U = D = 0.0
    for fl in frames.values():
        for o, ax, ay, up in fl:
            ys, xs = np.nonzero(o[..., 3] > 0)
            s = up
            L = max(L, (ax - xs.min()) * s)
            R = max(R, (xs.max() + 1 - ax) * s)
            U = max(U, (ay - ys.min()) * s)
            D = max(D, (ys.max() + 1 - ay) * s)
    half = int(np.ceil(max(L, R) * scale)) + 1
    cw = half * 2
    up_px = int(np.ceil(U * scale)) + 1
    down = int(np.ceil(D * scale)) + 1
    ch = up_px + down
    dst = 'assets/units/%s/' % kind
    os.makedirs(dst, exist_ok=True)
    strips = {}
    for (anim, d), fl in frames.items():
        strip = np.zeros((ch, cw * len(fl), 4), np.uint8)
        for i, (o, ax, ay, up) in enumerate(fl):
            s = scale * up            # this sheet's px -> game px
            BW, BH = int(round(cw / s)), int(round(ch / s))
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / s - ax)), int(round(up_px / s - ay))))
            sm = shrink(np.array(big), cw / BW)[:ch, :cw]
            sm = snap_team(sm)
            strip[:sm.shape[0], i * cw:i * cw + sm.shape[1]] = sm
        strips[(anim, d)] = strip
        names = ['idle', 'walk'] if anim == 'fly' else [anim]
        for nm in names:
            Image.fromarray(strip, 'RGBA').save(dst + '%s_%s.png' % (nm, d))
    print('%s: scale %.4f, cell %dx%d, anchor (%d, %d)' % (kind, scale, cw, ch, half, up_px))
    print('SHEETS line: "%s": [%d, %d, %d, %d],' % (kind, cw, ch, half, up_px))
    print('frames:', {a: len(frames[(a, 's')]) for a in sheets})
    worst = sorted(report, key=lambda r: r[3])[:6]
    print('weakest body overlaps:', worst)
    if drop:
        print('drop: {' + ', '.join('"%s": Vector2(%d, %d)' % (d, round(v[0] * scale), round(v[1] * scale)) for d, v in drop.items()) + '}')
    if preview is not None:
        preview[kind] = (strips, cw, ch, half, up_px)
    return strips, cw, ch, half, up_px, scale


def icon_from(strip, cw, f, name, upper=False, tight=False):
    s = strip[:, f * cw:(f + 1) * cw]
    ys, xs = np.nonzero(s[..., 3] > 0)
    if tight:
        # a square as tall as the figure, on its middle: the body big, the spread wings cut at the sides
        side = int(ys.max() - ys.min()) + 6
        cx = int(round((xs.min() + xs.max()) / 2))
        y0 = ys.min() - 3
    elif upper:
        # the head and body, square (the wings cut at the sides)
        side = int((ys.max() - ys.min()) * 0.9) + 2
        cx = int(round((xs.min() + xs.max()) / 2))
        y0 = ys.min() - 1
    else:
        side = max(xs.max() - xs.min(), ys.max() - ys.min()) + 4
        cx = (xs.min() + xs.max()) // 2
        y0 = (ys.min() + ys.max()) // 2 - side // 2
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(Image.fromarray(s).crop((cx - side // 2, y0, cx - side // 2 + side, y0 + side)), (0, 0))
    sq.resize((64, 64), Image.NEAREST).save('assets/icons/%s.png' % name)


# ------------------------------------------------------------------ the bomb and its explosion (owl_bomb_fx.png)

def fx_cells():
    rgb = np.array(Image.open(SRC + 'owl_bomb_fx.png').convert('RGB')).astype(int)
    H, W = rgb.shape[:2]
    ch, cw = H / 3.0, W / 4.0
    m = np.abs(rgb - NAVY).sum(2) >= 30
    out = []
    for r in range(3):
        for c in range(4):
            y0, y1 = int(round(r * ch)), int(round((r + 1) * ch))
            x0, x1 = int(round(c * cw)), int(round((c + 1) * cw))
            cm = m[y0:y1, x0:x1]
            lab, n = ndi.label(cm)
            sz = ndi.sum(cm, lab, range(1, n + 1)) if n else []
            keep = np.isin(lab, [i + 1 for i in range(n) if sz[i] >= 6])
            o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
            # soft edges for smoke: alpha from the distance to the navy (faint wisps stay faint), and the navy taken back
            # out of their colour (c = a * fg + (1 - a) * navy), so thin smoke is grey, not blue
            c = rgb[y0:y1, x0:x1].astype(np.float32)
            d = np.abs(c - NAVY).sum(2)
            a = np.clip((d - 18.0) / 70.0, 0.0, 1.0)
            fg = (c - (1.0 - a[..., None]) * NAVY) / np.maximum(a[..., None], 0.05)
            o[..., :3] = np.clip(fg, 0, 255).astype(np.uint8)
            o[..., 3] = (a * keep * 255).astype(np.uint8)
            out.append(o)
    return out


def soft_shrink(img, scale):
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.LANCZOS)).astype(np.float32)
    al = np.clip(s[..., 3:4] / 255.0, 0, 1)
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = (al[..., 0] * 255).astype(np.uint8)
    return out


def import_fx(bomb_px, blast_px):
    cells = fx_cells()
    # the falling weight (row 1): each frame centred on the ball (its biggest dark part), bomb_px wide
    balls = []
    for o in cells[:4]:
        al = o[..., 3] > 128
        lab, n = ndi.label(al)
        sz = ndi.sum(al, lab, range(1, n + 1))
        k = int(np.argmax(sz)) + 1
        ys, xs = np.nonzero(lab == k)
        balls.append((o, (xs.min() + xs.max() + 1) / 2.0, (ys.min() + ys.max() + 1) / 2.0, xs.max() + 1 - xs.min(), ys.min()))
    bw = np.median([b[3] for b in balls])
    s = bomb_px / bw
    # (the red light on top reaches above the ball: the canvas is centred on the ball, so it has room above)
    ext = max(max(b[1] - np.nonzero(b[0][..., 3] > 0)[1].min(), np.nonzero(b[0][..., 3] > 0)[1].max() + 1 - b[1]) for b in balls)
    exty = max(max(b[2] - np.nonzero(b[0][..., 3] > 0)[0].min(), np.nonzero(b[0][..., 3] > 0)[0].max() + 1 - b[2]) for b in balls)
    half = int(np.ceil(max(ext, exty) * s)) + 1
    side = half * 2
    strip = np.zeros((side, side * 4, 4), np.uint8)
    for i, (o, cx, cy, w, top) in enumerate(balls):
        B = int(round(side / s))
        big = Image.new('RGBA', (B, B), (0, 0, 0, 0))
        big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / s - cx)), int(round(half / s - cy))))
        sm = shrink(np.array(big), side / B)[:side, :side]
        strip[:sm.shape[0], i * side:i * side + sm.shape[1]] = sm
    Image.fromarray(strip, 'RGBA').save('assets/effects/owl_bomb.png')
    print('EFFECTS: "owl_bomb": {"frames": 4, "size": Vector2i(%d, %d)},' % (side, side))
    # the explosion: row 2 centred on the flash of its first frame (the impact), row 3 placed by the scorch of its last
    # frame (the scorch's middle on the impact point); each row keeps its frames' places in the cell as drawn
    flash = cells[4][..., 3] > 128
    lab, n = ndi.label(flash)
    sz = ndi.sum(flash, lab, range(1, n + 1))
    ys, xs = np.nonzero(lab == int(np.argmax(sz)) + 1)
    p2 = ((xs.min() + xs.max() + 1) / 2.0, (ys.min() + ys.max() + 1) / 2.0)
    last = cells[11]
    lr, lg, lb = last[..., 0].astype(int), last[..., 1].astype(int), last[..., 2].astype(int)
    dark = (last[..., 3] > 60) & (lr + lg + lb < 150)
    lab, n = ndi.label(ndi.binary_closing(dark, iterations=2))
    sz = ndi.sum(dark, lab, range(1, n + 1))
    ys, xs = np.nonzero(lab == int(np.argmax(sz)) + 1)
    p3 = ((xs.min() + xs.max() + 1) / 2.0, (ys.min() + ys.max() + 1) / 2.0)
    # the size: the 2nd frame's fireball (its solid part) about blast_px across
    f2 = cells[5][..., 3] > 200
    xs2 = np.nonzero(f2.any(0))[0]
    s2 = blast_px / float(np.percentile(xs2, 95) - np.percentile(xs2, 5))
    ext = 0.0
    for i, o in enumerate(cells[4:]):
        p = p2 if i < 4 else p3
        ys, xs = np.nonzero(o[..., 3] > 20)
        if len(xs):
            ext = max(ext, p[0] - xs.min(), xs.max() + 1 - p[0], p[1] - ys.min(), ys.max() + 1 - p[1])
    half = int(np.ceil(ext * s2)) + 1
    side = half * 2
    strip = np.zeros((side, side * 8, 4), np.uint8)
    for i, o in enumerate(cells[4:]):
        p = p2 if i < 4 else p3
        B = int(round(side / s2))
        big = Image.new('RGBA', (B, B), (0, 0, 0, 0))
        big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / s2 - p[0])), int(round(half / s2 - p[1]))))
        sm = soft_shrink(np.array(big), side / B)[:side, :side]
        strip[:sm.shape[0], i * side:i * side + sm.shape[1]] = sm
    Image.fromarray(strip, 'RGBA').save('assets/effects/owl_blast.png')
    print('EFFECTS: "owl_blast": {"frames": 8, "size": Vector2i(%d, %d)},' % (side, side))


def main():
    preview = {} if len(sys.argv) > 1 else None
    res = {}
    for kind, info in KINDS.items():
        res[kind] = import_kind(kind, info, preview)
    # icons: the Cuckoo and the Owl (level wings, S), the research (the owl's head and body), the morph button (the owl
    # seen from the side, E)
    st, cw = res['cuckoo'][0], res['cuckoo'][1]
    icon_from(st[('fly', 's')], cw, 1, 'cuckoo', tight=True)
    so, ow = res['ticking_owl'][0], res['ticking_owl'][1]
    icon_from(so[('fly', 's')], ow, 1, 'ticking_owl', tight=True)
    icon_from(so[('fly', 's')], ow, 0, 'research_ticking_owl', upper=True)
    icon_from(so[('fly', 'e')], ow, 1, 'ab_morph_owl')
    # the falling weight as wide as the hanging one (measured on the owl's fly sheet: ~33 sheet px), the blast about two
    # tiles across (its damage reaches about a tile round the impact)
    import_fx(round(33 * res['ticking_owl'][5]) + 2, 60)
    if preview is not None:
        make_preview(preview, sys.argv[1])


def make_preview(pv, path):
    """All strips at 3x on a grey checker, each frame's anchor marked: for checking the alignment by eye."""
    rows = []
    for kind, (strips, cw, ch, half, up) in pv.items():
        for (anim, d), s in strips.items():
            rows.append((kind, anim, d, s, cw, ch, half, up))
    Z = 3
    W = max(r[3].shape[1] for r in rows) * Z + 10
    Ht = sum(r[3].shape[0] * Z + 6 for r in rows)
    img = Image.new('RGBA', (W, Ht), (90, 110, 90, 255))
    y = 0
    for kind, anim, d, s, cw, ch, half, up in rows:
        im = Image.fromarray(s).resize((s.shape[1] * Z, s.shape[0] * Z), Image.NEAREST)
        img.alpha_composite(im, (0, y))
        px = img.load()
        for i in range(s.shape[1] // cw):
            ax, ay = (i * cw + half) * Z, y + up * Z
            for k in range(-4, 5):
                if 0 <= ax + k < W:
                    px[ax + k, ay] = (255, 255, 0, 255)
                if 0 <= ay + k < Ht:
                    px[ax, ay + k] = (255, 255, 0, 255)
        y += s.shape[0] * Z + 6
    img.save(path)


if __name__ == '__main__':
    main()
