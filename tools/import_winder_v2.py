"""The new Winder (the Clockwork's one worker) from the owner's ChatGPT sheets in art/redraws/ (navy background, five
rows = the views S SE E NE N; the west views are the east ones mirrored by the game), all accepted by the owner:
  winder_idle_v2.png    2 frames a view (the rows the owner picked)
  winder_walk_v2.png    4 frames a view
  winder_wind_v2.png    4 frames a view: WINDING, his one job (working a Cog Press, building, repairing)
  winder_attack_v3.png  4 frames a view: the key off his back, raised, thrust into the enemy, back on (the final pass)
  winder_death_v2.png   6 frames a view: shaken, gears flying, he runs down and falls to pieces
into the game's strips assets/units/winder/<anim>_<view>.png (frames side by side, one cell for all; repair_<view> is the
wind strip: repairing is winding), the "winder" entry of scripts/art_data.gd and the card portrait
assets/icons/winder.png. Replaces the old Winder of tools/import_art.py and its code-built walk legs
(tools/import_gait_winder.py), which tools/rebuild_art.sh no longer runs.

Finding the figures: the navy and the painted shadow under the feet (the navy darkened; the game draws its own) are keyed
out. The sheets are not on a grid (ChatGPT spaces its columns as it likes), so each figure is found as a blob on the
background: the rows x frames biggest blobs are the figures, sorted into rows by height and left to right; the small bits
(sparks, flying gears, smoke) go to the nearest figure.

Placing them (the anchor is the feet, on the unit's position):
  idle, walk, wind  the head stays still: every frame of a row is lined up on the stem on top of the clock (the key bow
                    behind the head is skipped), and the row is put so that its feet, on average, are on the anchor
  attack            the feet are planted: each frame on its own feet (the key and the body swing above them)
  death             the first frame stands on its feet; the others keep the sheet's ground line and the place of their
                    weight (centroid) relative to the first, so the heap falls where he stood
Size: a standing Winder is HEIGHT px tall in every view and every strip (each sheet and view is scaled on its upright
frames; the views keep the proportions ChatGPT gave them, the median over the five sheets).

Colour: the owner's Clockwork rule (brass + the player's colour, no blue) in ONE call, clockwork_palette(): the blue
shoulder joints and the red heart become the shader's key reds (lit 255,0,0 and shaded 150,0,0, shaders/team.gdshader),
the navy fringe a warm dark; the white clock face and the steel greys stay. (A shared Clockwork recolour step may
replace this call later.)

The crank (code-drawn, docs/art_style_inconsistency.md): ChatGPT's wind frames hold the arms stiff, so a small steel crank
with a brass knob is drawn in his hands, a quarter turn further on every frame (the game plays the frames on the beat:
hammer, hammer, pause; Unit.WINDER_BEAT). Not in the back view (his hands are hidden).

  python3 tools/import_winder_v2.py [--preview DIR]     (DIR: a contact sheet and GIFs of every strip, 4x, on the beat)"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SRC = 'art/redraws/'
DST = 'assets/units/winder/'
ICON = 'assets/icons/winder.png'
ART_DATA = 'scripts/art_data.gd'
DIRS = ['s', 'se', 'e', 'ne', 'n']
# anim: (sheet, frames a view, the upright frames that set the size (None: all))
SHEETS = {
    'idle': ('winder_idle_v2.png', 2, None),
    'walk': ('winder_walk_v2.png', 4, None),
    'wind': ('winder_wind_v2.png', 4, None),
    'attack': ('winder_attack_v3.png', 4, [3]),       # (the last frame: the key back on his back)
    'death': ('winder_death_v2.png', 6, [0]),         # (the first: still standing)
}
HEIGHT = 40             # px: a standing Winder in the S view, feet to the top of the stem (the old one: 41-43 with the key)
TOL = 40                # key: summed RGB distance from the background
MIN_BIT = 6             # px (sheet): smaller specks are dropped
REACH = 70              # px (sheet): bits farther than this from every figure are dropped
TEAM_LIGHT = (255, 0, 0)
TEAM_DARK = (150, 0, 0)
# The crank in his hands (wind strips), per view in game px from the anchor (unflipped: facing east): the hub, the arm's
# length, the turn's ellipse (x and y radius factors: a circle when it faces us, a vertical swing side on) and the frames'
# angles (degrees, screen; 0 = right, 90 = down).
CRANK = {
    's': {'hub': (0, -14), 'arm': 5.0, 'ell': (1.0, 0.8)},
    'se': {'hub': (8, -15), 'arm': 5.0, 'ell': (0.75, 0.9)},
    'e': {'hub': (16, -16), 'arm': 4.5, 'ell': (0.45, 1.0)},
    'ne': {'hub': (16, -17), 'arm': 4.0, 'ell': (0.6, 0.9)},
}
CRANK_ANGLES = [-90, 0, 90, 180]
STEEL = (214, 220, 228)
STEEL_D = (110, 116, 128)
BRASS = (246, 190, 70)
BRASS_L = (255, 240, 160)
BRASS_D = (160, 98, 28)
INK = (24, 14, 10)
# The beat (keep in step with Unit.WINDER_BEAT): how long each frame is held, in seconds (preview only here)
T = 1.0 / 15.0         # (the game's animation tick)
BEAT = {'idle': [1.0, 1.0], 'walk': [T, 2 * T, T, 2 * T], 'wind': [7 * T, 2 * T, 7 * T, 2 * T],
        'attack': [T, 2 * T, 4 * T, 6 * T], 'death': [T, 2 * T, 3 * T, 3 * T, 4 * T, 1.2]}


# ------------------------------------------------------------------ finding the figures

def keyed(a):
    """Foreground mask and the background colour (the median of the border). The painted shadow is the navy darkened
    (bluer than it is bright, darker than the navy): it goes too."""
    bd = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(bd, 0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    shadow = (b <= bg[2] - 4) & (b >= r + 10) & (b >= g + 6)
    return (np.abs(a - bg).sum(2) >= TOL) & ~shadow, bg


def figures(fg, rows, cols):
    """[row][frame] -> (body mask, bits mask) of every figure on a sheet."""
    lab, n = ndi.label(ndi.binary_dilation(fg, iterations=2), np.ones((3, 3)))
    lab = np.where(fg, lab, 0)
    sizes = ndi.sum(fg, lab, range(1, n + 1))
    boxes = ndi.find_objects(lab)
    order = [int(i) for i in np.argsort(-sizes)]
    want = rows * cols
    bodies = order[:want]
    if len(order) > want and sizes[order[want]] * 3 > sizes[bodies[-1]]:
        raise SystemExit('figures: no clear gap between the %d figures and the bits (%d vs %d px)'
                         % (want, sizes[bodies[-1]], sizes[order[want]]))
    cy = {i: (boxes[i][0].start + boxes[i][0].stop) / 2 for i in bodies}
    srt = sorted(bodies, key=lambda i: cy[i])
    cuts = sorted(sorted(range(want - 1), key=lambda k: cy[srt[k]] - cy[srt[k + 1]])[:rows - 1])
    grid, s = [], 0
    for c in cuts + [want - 1]:
        grid.append(sorted(srt[s:c + 1], key=lambda i: boxes[i][1].start))
        s = c + 1
    if any(len(r) != cols for r in grid):
        raise SystemExit('figures: rows of %s, expected %d each' % ([len(r) for r in grid], cols))
    # the bits: to the nearest figure (gap between the boxes)
    bits = {i: [] for i in bodies}
    for j in order[want:]:
        if sizes[j] < MIN_BIT:
            continue
        o = boxes[j]
        best, bd = None, 1e9
        for i in bodies:
            bo = boxes[i]
            dy = max(bo[0].start - o[0].stop, 0, o[0].start - bo[0].stop)
            dx = max(bo[1].start - o[1].stop, 0, o[1].start - bo[1].stop)
            d = (dx * dx + dy * dy) ** 0.5
            if d < bd:
                bd, best = d, i
        if bd <= REACH:
            bits[best].append(j)
    return [[(lab == i + 1, np.isin(lab, [k + 1 for k in bits[i]])) for i in row] for row in grid]


def stem_x(body, view):
    """x of the stem on top of the clock: the top band's piece nearest the middle (S, N) or the front-most one (the east
    views face right, the key bow sits behind the head)."""
    ys, xs = np.nonzero(body)
    top, bot = ys.min(), ys.max()
    band = body[top:top + max(3, int((bot - top) * 0.05)), :]
    lab, n = ndi.label(band)
    pieces = []
    for k in range(1, n + 1):
        px = np.nonzero(lab == k)[1]
        if len(px) >= 4:
            pieces.append((px.min(), px.max()))
    if view in ('se', 'e', 'ne'):
        x0, x1 = max(pieces, key=lambda p: p[1])
    else:
        mid = (xs.min() + xs.max()) / 2
        x0, x1 = min(pieces, key=lambda p: abs((p[0] + p[1]) / 2 - mid))
    return (x0 + x1) / 2


def feet(body):
    """(x of the middle of the feet, y of the soles): the bottom 6% of the body."""
    ys, xs = np.nonzero(body)
    bot = ys.max()
    low = ys >= bot - (bot - ys.min()) * 0.06
    return (xs[low].min() + xs[low].max()) / 2, float(bot + 1)


def height(body):
    ys = np.nonzero(body.any(1))[0]
    return float(ys.max() - ys.min() + 1)


# ------------------------------------------------------------------ colour

def clockwork_palette(img):
    """The Clockwork palette rule (brass + the player's colour, no blue) on an RGBA frame at the sheet's size: the blue
    joints and the red heart become the key reds the team shader recolours (lit / shaded by their brightness); the
    bluish fringe the navy left along the edges (thin: no solid core, unlike a joint) is warmed to the brass's dark.
    The clock face's white, the brass and the steel greys stay. The heart is a pure red (green and blue both low); the
    copper shading next to it is orange (green well above blue) and stays."""
    out = img.copy()
    rgb = img[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    on = img[..., 3] > 0
    bluish = on & (b >= r + 25) & (b >= g + 18) & (rgb.max(-1) >= 70)
    lab, n = ndi.label(bluish, np.ones((3, 3)))
    core = np.unique(lab[ndi.binary_erosion(bluish, iterations=2)])
    joints = np.isin(lab, core[core > 0])
    red = on & (r >= 90) & (g <= r * 0.25) & (b <= r * 0.3) & (g - b <= r * 0.12)
    lit = (joints & (b >= 145)) | (red & (r >= 175))
    team = joints | red
    out[team & lit, :3] = TEAM_LIGHT
    out[team & ~lit, :3] = TEAM_DARK
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    fringe = on & ~team & (b >= r + 15) & (b >= g + 6) & (lum < 80)
    out[fringe, 0] = np.clip(lum[fringe] * 1.25, 0, 255)
    out[fringe, 1] = np.clip(lum[fringe] * 0.85, 0, 255)
    out[fringe, 2] = np.clip(lum[fringe] * 0.55, 0, 255)
    return out


def snap_team(img):
    """After shrinking: the reds near the keys -> the exact key reds (tools/import_art.py), pure reds only (an orange
    blend of the heart and the brass stays as it is)."""
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    red = (img[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32) & (g - b <= r * 0.15)
    light = red & (r >= 175)
    img[light, :3] = TEAM_LIGHT
    img[red & ~light, :3] = TEAM_DARK
    return img


def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then a hard alpha (tools/import_art.py)."""
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


# ------------------------------------------------------------------ the crank

def crank(frame, view, k, anchor):
    """Draw the crank on a game-size wind frame (RGBA array, unflipped) in the pose of frame k."""
    c = CRANK.get(view)
    if c is None:
        return frame
    im = Image.fromarray(frame, 'RGBA')
    d = ImageDraw.Draw(im)
    hx, hy = anchor[0] + c['hub'][0], anchor[1] + c['hub'][1]
    ang = np.radians(CRANK_ANGLES[k % len(CRANK_ANGLES)])
    kx = int(round(hx + np.cos(ang) * c['arm'] * c['ell'][0]))
    ky = int(round(hy + np.sin(ang) * c['arm'] * c['ell'][1]))
    # the arm (a light steel line with a dark edge under it), the axle (a dark pin), then the knob: 2 x 2 brass lit from
    # the top left in a dark rim, so it reads on the brass body and on grass
    d.line([(hx, hy + 1), (kx, ky + 1)], fill=INK + (255,), width=1)
    d.line([(hx, hy), (kx, ky)], fill=STEEL + (255,), width=1)
    d.point([(hx, hy)], fill=STEEL_D + (255,))
    d.rectangle([kx - 2, ky - 2, kx + 1, ky + 1], fill=INK + (255,))
    d.point([(kx - 1, ky - 1)], fill=BRASS_L + (255,))
    d.point([(kx, ky - 1), (kx - 1, ky)], fill=BRASS + (255,))
    d.point([(kx, ky)], fill=BRASS_D + (255,))
    return np.array(im)


# ------------------------------------------------------------------ main

def main():
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    # 1. every figure: its cut-out (sheet px), anchor and the reference height of its row
    cut = {}        # (anim, view) -> [(rgba, ax, ay)]
    href = {}       # (anim, view) -> height of the upright frames (sheet px)
    for anim, (f, cols, upright) in SHEETS.items():
        a = np.array(Image.open(SRC + f).convert('RGB')).astype(int)
        fg, _ = keyed(a)
        for r, row in enumerate(figures(fg, len(DIRS), cols)):
            view = DIRS[r]
            refs = [i for i in range(cols) if upright is None or i in upright]
            href[(anim, view)] = float(np.median([height(row[i][0]) for i in refs]))
            places = []
            if anim in ('idle', 'walk', 'wind'):
                # the head still, the feet on the anchor on average
                st = [stem_x(body, view) for body, _ in row]
                off = float(np.mean([feet(body)[0] - s for (body, _), s in zip(row, st)]))
                places = [(s + off, feet(body)[1]) for (body, _), s in zip(row, st)]
            elif anim == 'attack':
                places = [feet(body) for body, _ in row]
            else:
                fx0, fy0 = feet(row[0][0])
                cx0 = np.nonzero(row[0][0] | row[0][1])[1].mean()
                places = [(np.nonzero(body | bits)[1].mean() - cx0 + fx0, fy0) for body, bits in row]
            out = []
            for (body, bits), (ax, ay) in zip(row, places):
                m = body | bits
                ys, xs = np.nonzero(m)
                y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
                o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
                o[..., :3] = a[y0:y1, x0:x1]
                o[..., 3] = m[y0:y1, x0:x1] * 255
                out.append((clockwork_palette(o), ax - x0, ay - y0))
            cut[(anim, view)] = out
    # 2. the scale of each sheet and view: a standing Winder HEIGHT px tall in S, the other views as ChatGPT drew them
    ratio = {v: float(np.median([href[(an, v)] / href[(an, 's')] for an in SHEETS])) for v in DIRS}
    scale = {(an, v): HEIGHT * ratio[v] / href[(an, v)] for an in SHEETS for v in DIRS}
    # 3. one cell: the farthest any frame reaches from its anchor (the attack's raised key: extra room on top of its strips)
    L = U = D = 0.0
    U_att = 0.0
    for (an, v), fl in cut.items():
        s = scale[(an, v)]
        for o, ax, ay in fl:
            ys, xs = np.nonzero(o[..., 3] > 0)
            L = max(L, (ax - xs.min()) * s, (xs.max() + 1 - ax) * s)
            D = max(D, (ys.max() + 1 - ay) * s)
            if an == 'attack':
                U_att = max(U_att, (ay - ys.min()) * s)
            else:
                U = max(U, (ay - ys.min()) * s)
    half = int(np.ceil(L)) + 2
    cw = half * 2
    up = int(np.ceil(U)) + 1
    up_att = max(up, int(np.ceil(U_att)) + 1)
    down = int(np.ceil(D)) + 1
    ch = up + down
    os.makedirs(DST, exist_ok=True)
    counts = {}
    strips = {}
    for (an, v), fl in cut.items():
        top = up_att if an == 'attack' else up
        H = top + down
        strip = np.zeros((H, cw * len(fl), 4), np.uint8)
        s = scale[(an, v)]
        for i, (o, ax, ay) in enumerate(fl):
            # the cut-out on a canvas (cw x H) / s with its anchor at (half, top) / s, then shrunk to cw x H
            BW, BH = int(round(cw / s)), int(round(H / s))
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / s - ax)), int(round(top / s - ay))))
            g = snap_team(shrink(np.array(big), cw / BW))[:H, :cw]
            if an == 'wind':
                g = crank(g, v, i, (half, top))
            strip[:g.shape[0], i * cw:i * cw + g.shape[1]] = g
        Image.fromarray(strip, 'RGBA').save(DST + '%s_%s.png' % (an, v))
        counts['%s_%s' % (an, v)] = len(fl)
        strips[(an, v)] = strip
        if an == 'wind':
            Image.fromarray(strip, 'RGBA').save(DST + 'repair_%s.png' % v)      # repairing is winding
            counts['repair_%s' % v] = len(fl)
            strips[('repair', v)] = strip
    write_art_data((cw, ch), (half, up), counts)
    portrait()
    print('winder: cell %dx%d, anchor (%d, %d), attack strips %d px taller; views %s'
          % (cw, ch, half, up, up_att - up, ' '.join('%s %.3f' % (v, ratio[v]) for v in DIRS)))
    if preview:
        write_preview(preview, strips, cw, (half, up), up_att - up)


def write_art_data(cell, anchor, counts):
    """The "winder" entry of scripts/art_data.gd (replaced, or added after the labourer's when tools/import_art.py wrote
    none)."""
    src = open(ART_DATA).read()
    lines = ['\t"winder": {"cell": Vector2i(%d, %d), "anchor": Vector2(%d, %d), "frames": {' % (cell + anchor)]
    for k in sorted(counts):
        lines.append('\t\t"%s": %d,' % (k, counts[k]))
    lines.append('\t}},\n')
    block = '\n'.join(lines)
    m = re.search(r'\t"winder": \{"cell".*?\n\t\}\},\n', src, re.S)
    if m:
        src = src[:m.start()] + block + src[m.end():]
    else:
        m = re.search(r'\t"labourer": \{"cell".*?\n\t\}\},\n', src, re.S)
        src = src[:m.end()] + block + src[m.end():]
    open(ART_DATA, 'w').write(src)


def portrait():
    """The card portrait (64 x 64): the S idle figure's head and chest from the sheet itself, on a clear background like
    the other new Clockwork units' (the Clock Soldier's, the Jack's)."""
    f, cols, _ = SHEETS['idle']
    a = np.array(Image.open(SRC + f).convert('RGB')).astype(int)
    fg, _ = keyed(a)
    body, bits = figures(fg, len(DIRS), cols)[0][0]
    m = body | bits
    ys, xs = np.nonzero(m)
    o = np.zeros(a.shape[:2] + (4,), np.uint8)
    o[..., :3] = a
    o[..., 3] = m * 255
    o = clockwork_palette(o)
    side = int((ys.max() - ys.min()) * 0.78)
    cx = (xs.min() + xs.max()) // 2
    y0 = ys.min() - 4
    crop = o[y0:y0 + side, cx - side // 2:cx - side // 2 + side]
    small = snap_team(shrink(crop, 62.0 / side))
    icon = np.zeros((64, 64, 4), np.uint8)
    h, w = small.shape[:2]
    oy, ox = 64 - h, (64 - w) // 2
    icon[oy:oy + h, ox:ox + w] = small
    Image.fromarray(icon, 'RGBA').save(ICON)


def write_preview(out, strips, cw, anchor, extra):
    """Contact sheet and one GIF per view and strip (4x, on grass, the frames held on the beat)."""
    os.makedirs(out, exist_ok=True)
    Z = 4
    grass = (64, 96, 52, 255)
    rows = []
    for an in ['idle', 'walk', 'wind', 'attack', 'death']:
        for v in DIRS:
            st = strips[(an, v)]
            rows.append(st[extra:] if an == 'attack' else st)
    W = max(r.shape[1] for r in rows)
    sheet = Image.new('RGBA', (W * Z, sum(r.shape[0] for r in rows) * Z), grass)
    y = 0
    for r in rows:
        im = Image.fromarray(r, 'RGBA')
        sheet.alpha_composite(im.resize((im.width * Z, im.height * Z), Image.NEAREST), (0, y))
        y += r.shape[0] * Z
    sheet.save(os.path.join(out, 'contact.png'))
    for an in ['idle', 'walk', 'wind', 'attack', 'death']:
        frames = []
        durs = []
        n = strips[(an, 's')].shape[1] // cw
        for k in range(n):
            canvas = Image.new('RGBA', (cw * Z * len(DIRS), strips[(an, 's')].shape[0] * Z), grass)
            for j, v in enumerate(DIRS):
                st = strips[(an, v)]
                im = Image.fromarray(st[:, k * cw:(k + 1) * cw], 'RGBA')
                canvas.alpha_composite(im.resize((cw * Z, st.shape[0] * Z), Image.NEAREST), (j * cw * Z, 0))
            frames.append(canvas.convert('RGB'))
            durs.append(int(BEAT[an][k] * 1000))
        frames[0].save(os.path.join(out, '%s.gif' % an), save_all=True, append_images=frames[1:], duration=durs, loop=0)


if __name__ == '__main__':
    main()
