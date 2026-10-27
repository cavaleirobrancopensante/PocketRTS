"""Import the Clockwork's TIER 3 sheets (art/redraws/*, navy background RGB 0,22,48, rows = directions S SE E NE N; the west
views are the east ones mirrored in the game) into the game's unit strips, one canvas per kind:
  assets/units/pendulum/{idle,walk,attack,death}_{s,se,e,ne,n}.png
  assets/units/netter/{idle,walk,attack,death}_{s,se,e,ne,n}.png
the nets (assets/effects/netter_net.png in flight, netter_net_open.png and netter_net_open_big.png spread over a caught
unit), the card icons assets/icons/{pendulum,netter}.png, and prints the scripts/cw_art.gd SHEETS lines, the Netter's
muzzle per drawn direction (Defs.NET "mouth") and the effect sizes for ArtData.EFFECTS.

PENDULUM v2, two arms (tools/pendulum_v2_guide/: the idle, the walk and the two LOW SWEEPS are built in code from
ChatGPT's direction sheet art/redraws/pendulum_v2_dirs.png; the importer runs anim.py itself and takes its RGBA cells,
so no navy keying and the blade's see-through smear keeps its alpha; the unit's point is each cell's middle, 10 px
over its bottom):
  idle      4 frames (cells 236 x 302)
  walk      8 frames (236 x 302)
  attack_r  6 frames (314 x 368): the right arm's blow, THE HIT on the 4th frame (index 3)
  attack_l  6 frames: the left arm's blow, the same timing (the guide's frames 7-12)
  death     art/redraws/pendulum_v2_death_chatgpt_1.png (rows S, SE, E) and _2.png (rows NE, N), ChatGPT's, 6 frames a row.
            ChatGPT kept no grid (sheet 2's rows sit ~50 px lower, flying arms cross the column lines): rows are found as
            content bands, and in each band the biggest piece in each column is that frame's figure and every other piece
            goes to the figure NEAREST it (figure_cells). CODE EDIT: a pink puff in the dust (sheet 1, row SE, frame 4) is
            greyed like the dust round it (grey_pink). Each row is scaled so its standing first frame is as tall as that
            direction's idle, its feet on the ground line and its case over the anchor (as on the idle). Accepted as
            painted: the side view rolls so its clock face shows on the ground; every view falls to the screen's right.
            Also writes art/redraws/pendulum_v2_death.gif (the imported death at game size, x3).
The old one-armed Pendulum's sheets (art/redraws/pendulum_*.png, tools/pendulum_guide/) are no longer imported.
NETTER (tools/netter_guide/: built in code from ChatGPT's direction sheet; the unit's box bottom 12 px over the cell bottom):
  walk    netter_walk.png       5 x 8, cells 307 x 204 (a trot); its first frame is also the IDLE (one frame)
  attack  netter_fire.png       5 x 6, cells 307 x 204: the recoil (the net leaves on the 2nd frame, the strongest kick)
  death   netter_death_chatgpt.png when it exists (ChatGPT, 5 x 5: row bands y 15-207, 220-396, 402-581, 596-783, 793-981,
          columns ~307 wide; drawn SMALLER than the walk, by a different amount per row: each row is scaled so its first
          frame's figure is as big as the walk's first frame), else the code guide netter_death_guide.png (5 x 5, 307 x 204)

ALIGNMENT: a row's anchor (the unit's point) is under its BODY on the ground: the Pendulum's red case (its centre across,
on the idle's first frame), the Netter's drum (the middle of its four feet on the walk's first frame); the ground line
is the feet. The code-built sheets keep one anchor for every frame of a row (their motion is drawn: the walk's dip, the
swing, the recoil). Death rows: every frame gets the shift of that row's FIRST frame (its feet on the ground line, its
body over the anchor), so the fall plays as drawn and nothing jumps when the death starts.

Per frame: key out the navy (tolerance 40), keep the figure (its big pieces and the bright small ones: cogs and bolts
flying off), the Clockwork palette (tools/cw_palette.py), shrink to game size (the Pendulum's idle S PEND_H px tall, the
Netter's walk S NETTER_W px wide), snap the team reds to the shader's key reds.

PALETTE (owner, 2026-10-26; the rule for every Clockwork unit is in tools/cw_palette.py): BRASS + PLAYER COLOUR. The
Pendulum's red case and legs stay player colour and its blue ball joints become player colour; its blade is steel. The
Netter's red bands stay player colour; its blue ball joints and the blue spring on its cannon become player colour; its
drum's iron and the chain mesh in its window stay as painted.
  python3 tools/import_tier3.py [preview.png]"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cw_palette

SRC = 'art/redraws/'
DIRS = ['s', 'se', 'e', 'ne', 'n']
NAVY = np.array([0, 22, 48])
TOL = 40
PEND_H = 82.0          # px: the Pendulum's S idle in game (the Winder 43, the Clock Soldier 59, a Brute 65): a tall tower
NETTER_W = 62.0        # px: the Netter's S walk (a wide, low drum; the Springer is ~50 wide)
PEND_GROUND = 297      # the ground line in the Pendulum's code-built cells (the unit box bottom CH - 8, its crop pad 2)
NET_GROUND = 190       # ... in the Netter's (CH - 12, pad 2)
NET_FIRE_FRAME = 1     # the attack frame the net leaves on

# the Netter's muzzle, measured on the painted walk frame (cell px; the cannon is cut off the drum above CUT_Y,
# tools/netter_guide/fire.py): the end of the barrel in the way it points (S and N: the open muzzle ring itself)
NET_AIM = {'s': (0.0, -1.0), 'se': (0.92, -0.38), 'e': (1.0, -0.12), 'ne': (0.86, -0.52), 'n': (0.0, -1.0)}


def keyed(rgb):
    return np.abs(rgb - NAVY).sum(2) >= TOL


def figure(rgb, min_main=600):
    """The figure in a crop: its pieces of 20 px or more (bright small ones too: bolts and cogs), holes that are not the
    navy itself filled (dark glass, the drum's mesh)."""
    m = keyed(rgb)
    lab, n = ndi.label(m)
    if n == 0:
        return np.zeros(m.shape, bool)
    sz = ndi.sum(m, lab, range(1, n + 1))
    keep = []
    for i, s in enumerate(sz):
        if s >= 20:
            keep.append(i + 1)
        elif s >= 6 and rgb[lab == i + 1].sum(1).mean() > 300:
            keep.append(i + 1)          # (a bright speck: a spark or a bolt)
    m = np.isin(lab, keep)
    return (ndi.binary_fill_holes(m) & (np.abs(rgb - NAVY).sum(2) >= 12)) | m


def rgba(rgb, m):
    o = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    o[..., :3] = rgb.clip(0, 255)
    o[..., 3] = m * 255
    return o


def red_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r >= 110) & (g <= r * 0.35) & (b <= r * 0.4)


def case_x(o):
    """The Pendulum's red case across (the red in the figure's upper 45%: the tower, not the legs)."""
    al = o[..., 3] > 0
    ys = np.nonzero(al.any(1))[0]
    top, bot = ys.min(), ys.max()
    red = red_mask(o) & al
    red[int(top + (bot - top) * 0.45):] = False
    if red.sum() < 30:
        xs = np.nonzero(al.any(0))[0]
        return (xs.min() + xs.max() + 1) * 0.5
    return float(np.nonzero(red)[1].mean()) + 0.5


def feet_x(o):
    """The middle of the figure's lowest 12% (the Netter's four feet)."""
    al = o[..., 3] > 0
    ys, xs = np.nonzero(al)
    low = ys >= ys.max() - 0.12 * (ys.max() - ys.min())
    return (xs[low].min() + xs[low].max() + 1) * 0.5


def bottom(o):
    ys = np.nonzero((o[..., 3] > 0).any(1))[0]
    return float(ys.max() + 1)


def bbox(o):
    ys, xs = np.nonzero(o[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then hard alpha (tools/import_clock_soldier.py)."""
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


def soft_shrink(img, scale):
    """The same, keeping the soft alpha (the nets' thin chains would break up under a hard edge)."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = np.clip(s[..., 3:4] / 255.0, 0, 1)
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = (np.clip(al[..., 0] * 1.25, 0, 1) * 255).astype(np.uint8)     # (a touch denser: the chains read)
    return out


# ------------------------------------------------------------------ slicing

def grid_cells(path, rows, cols, cw, ch, y0s=None):
    """[row][col] -> rgba crops of a regular grid (whole cells: their place in the cell is kept)."""
    rgb = np.array(Image.open(path).convert('RGB')).astype(int)
    out = []
    for r in range(rows):
        y0 = y0s[r] if y0s else r * ch
        row = []
        for c in range(cols):
            sub = rgb[y0:y0 + ch, c * cw:(c + 1) * cw]
            row.append(rgba(sub, figure(sub)))
        out.append(row)
    return out


BAND_PAD = 48         # px each side of a band's column: a falling figure's blade reaches over the column line


def band_cells(path, bands, cols, cw):
    """[row][col] -> (rgba crop, (x0, y0)) for sheets whose rows ChatGPT moved: each band is a row, cut into columns cw
    wide, each column BAND_PAD px wider on both sides (every crop of a band keeps its column's coordinates); a piece goes
    to the column its middle falls in, so a figure reaching over a column line stays whole and the neighbour's blade
    reaching in is not taken (a cannon or a blade flying off is a piece of its own)."""
    rgb = np.array(Image.open(path).convert('RGB')).astype(int)
    W = rgb.shape[1]
    out = []
    for (y0, y1) in bands:
        band = rgb[y0:y1 + 1]
        lab, n = ndi.label(figure(band))
        owner = np.full(n + 1, -1)
        for i, sl in enumerate(ndi.find_objects(lab)):
            xs = np.nonzero(lab[sl] == i + 1)[1] + sl[1].start
            owner[i + 1] = min(cols - 1, int(xs.mean() / cw))
        P = BAND_PAD
        padded = np.pad(band, ((0, 0), (P, P), (0, 0)))
        padded[:, :P] = NAVY
        padded[:, -P:] = NAVY
        lp = np.pad(owner[lab], ((0, 0), (P, P)), constant_values=-1)
        row = []
        for c in range(cols):
            x0, x1 = int(round(c * cw)), min(W, int(round((c + 1) * cw)))
            row.append((rgba(padded[:, x0:x1 + 2 * P], lp[:, x0:x1 + 2 * P] == c), (x0 - P, y0)))
        out.append(row)
    return out


def content_bands(path, rows, min_gap=10):
    """The y bands of `rows` rows of figures (ChatGPT's own layout): runs of lines with content, the biggest `rows`."""
    rgb = np.array(Image.open(path).convert('RGB')).astype(int)
    line = keyed(rgb).sum(1) > 3
    runs = []
    y = 0
    H = len(line)
    while y < H:
        if line[y]:
            s = y
            gap = 0
            while y < H and gap < min_gap:
                gap = 0 if line[y] else gap + 1
                y += 1
            runs.append((s, y - gap - 1))
        y += 1
    runs.sort(key=lambda r: r[1] - r[0], reverse=True)
    return sorted(runs[:rows])


# ------------------------------------------------------------------ one kind onto one canvas

def place_all(frames, scale, kind, soft=False):
    """frames: (anim, dir) -> [(rgba, ax, ay, s)] (s: this frame's own scale to the kind's sheet scale). One canvas for all
    (the farthest any frame reaches from its anchor); saves the strips; returns (strips, cw, ch, half, up)."""
    L = R = U = D = 0.0
    for fl in frames.values():
        for o, ax, ay, s in fl:
            x0, y0, x1, y1 = bbox(o)
            L = max(L, (ax - x0) * s)
            R = max(R, (x1 - ax) * s)
            U = max(U, (ay - y0) * s)
            D = max(D, (y1 - ay) * s)
    half = int(np.ceil(max(L, R) * scale)) + 1
    cw = half * 2
    up = int(np.ceil(U * scale)) + 1
    down = int(np.ceil(D * scale)) + 1
    ch = up + down
    dst = 'assets/units/%s/' % kind
    os.makedirs(dst, exist_ok=True)
    strips = {}
    for (anim, d), fl in frames.items():
        strip = np.zeros((ch, cw * len(fl), 4), np.uint8)
        for i, (o, ax, ay, s) in enumerate(fl):
            k = scale * s                 # this frame's px -> game px
            BW, BH = int(round(cw / k)), int(round(ch / k))
            o = cw_palette.recolour(o, kind)      # (after the anchors: case_x looks for the red case)
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / k - ax)), int(round(up / k - ay))))
            sm = shrink(np.array(big), cw / BW)[:ch, :cw]
            sm = cw_palette.snap_team(sm)
            strip[:sm.shape[0], i * cw:i * cw + sm.shape[1]] = sm
        strips[(anim, d)] = strip
        Image.fromarray(strip, 'RGBA').save(dst + '%s_%s.png' % (anim, d))
    print('%s: scale %.4f, cell %dx%d, anchor (%d, %d)' % (kind, scale, cw, ch, half, up))
    print('SHEETS line: "%s": [%d, %d, %d, %d],' % (kind, cw, ch, half, up))
    print('frames:', {a: len(fl) for (a, d), fl in frames.items() if d == 's'})
    return strips, cw, ch, half, up


# ------------------------------------------------------------------ the Pendulum (v2, two arms)

PEND2 = 'tools/pendulum_v2_guide'
PINK_PUFF = (1, 3, (905, 495, 955, 530))     # sheet 1, row SE (index 1), frame 4 (index 3): a pink puff in the dust (box)


def figure_cells(rgb, bands, cols):
    """[row][col] -> (rgba crop of the whole band, (x0, y0)) for sheets where ChatGPT kept no grid: in each band (a row of
    figures) the biggest piece in each column is that frame's figure, and every other piece (a flying arm, a cog, a puff
    of dust) goes to the figure it is NEAREST to (by the gap between them), whatever column line it crosses."""
    out = []
    for (y0, y1) in bands:
        band = rgb[y0:y1 + 1]
        H, W = band.shape[:2]
        m = figure(band)
        lab, n = ndi.label(m)
        sizes = ndi.sum(m, lab, range(1, n + 1))
        objs = ndi.find_objects(lab)
        cw = W / float(cols)
        seeds = []
        for c in range(cols):
            best, bs = 0, -1
            for i in range(n):
                xs = np.nonzero(lab[objs[i]] == i + 1)[1] + objs[i][1].start
                if int(xs.mean() / cw) == c and sizes[i] > bs:
                    best, bs = i + 1, sizes[i]
            seeds.append(best)
        dist = np.stack([ndi.distance_transform_edt(lab != sd) for sd in seeds])
        owner = np.full(n + 1, -1)
        for i in range(n):
            if i + 1 in seeds:
                owner[i + 1] = seeds.index(i + 1)
            else:
                owner[i + 1] = int(np.argmin(dist[:, lab == i + 1].min(1)))
        row = []
        P = FIG_PAD
        padded = np.pad(band, ((0, 0), (P, P), (0, 0)))
        lp = np.pad(owner[lab], ((0, 0), (P, P)), constant_values=-1)
        for c in range(cols):
            x0, x1 = int(round(c * cw)), int(round((c + 1) * cw))
            win = lp[:, x0:x1 + 2 * P] == c
            lost = (owner[lab] == c).sum() - win.sum()
            if lost:
                print('  figure_cells: %d px of frame %d fall outside its window' % (lost, c + 1))
            row.append((rgba(padded[:, x0:x1 + 2 * P], win), (x0 - P, y0)))
        out.append(row)
    return out


FIG_PAD = 160         # px each side of a column the pieces of its figure may reach (a flying arm)


def grey_pink(rgb, box):
    """CODE EDIT: a pink puff ChatGPT left in the dust -> the dust's own grey (by brightness, tinted like the dust round it)"""
    x0, y0, x1, y1 = box
    a = rgb[y0:y1, x0:x1]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    pink = (r - g > 25) & (b - g > 5) & (r < 235) & (np.abs(a - NAVY).sum(2) >= TOL)
    # the dust next to it: low saturation, mid grey
    ring = rgb[y0 - 20:y1 + 20, x0 - 20:x1 + 20].reshape(-1, 3)
    mx, mn = ring.max(1), ring.min(1)
    dust = ring[(mx - mn < 30) & (mx > 70)]
    tint = dust.mean(0) / max(1.0, dust.mean()) if len(dust) else np.ones(3)
    lum = a[pink].mean(1, keepdims=True)
    a[pink] = (lum * tint).clip(0, 255).astype(int)
    return int(pink.sum())


def pendulum():
    """the Pendulum v2 (tools/pendulum_v2_guide: idle, walk and the two low sweeps built in code from ChatGPT's
    direction sheet; the death painted by ChatGPT from the code guides)"""
    sys.path.insert(0, PEND2)
    import anim
    A = anim.all_anims()                     # (also rewrites the guide sheets and GIFs in art/redraws)
    import rig
    frames = {}
    idle = A['idle']
    icw, ich = idle[0][0].size
    acw, ach = A['attack'][0][0].size
    def cells(c, cw, ch):
        return [(np.array(im), cw / 2.0, ch - (rig.CH - rig.GROUND), 1.0) for im in c]
    for r, d in enumerate(DIRS):
        frames[('idle', d)] = cells(idle[r], icw, ich)
        frames[('walk', d)] = cells(A['walk'][r], icw, ich)
        at = cells(A['attack'][r], acw, ach)
        frames[('attack_r', d)] = at[:6]
        frames[('attack_l', d)] = at[6:]
    # the death: ChatGPT's sheets, cut by figure (no grid kept: sheet 2's rows sit lower, flying arms cross the lines)
    rows = []
    for k, n in ((1, 3), (2, 2)):
        path = SRC + 'pendulum_v2_death_chatgpt_%d.png' % k
        rgb = np.array(Image.open(path).convert('RGB')).astype(int)
        if k == PINK_PUFF[0]:
            print('pendulum death: %d pink pixels in the dust greyed' % grey_pink(rgb, PINK_PUFF[2]))
        rows += figure_cells(rgb, content_bands(path, n), 6)
    for r, d in enumerate(DIRS):
        i0 = np.array(idle[r][0])
        x0, y0, x1, y1 = bbox(i0)
        f0 = rows[r][0][0]
        fx0, fy0, fx1, fy1 = bbox(f0)
        k = (y1 - y0) / float(fy1 - fy0)          # the row's scale: its standing first frame as tall as the idle
        # the anchor: under the case as on the idle (the idle's anchor is its cell's middle), feet on the ground line
        off = icw / 2.0 - case_x(i0)
        a0 = (case_x(f0) + off / k, bottom(f0))
        frames[('death', d)] = [(o, a0[0], a0[1], k) for o, xy in rows[r]]
        print('pendulum death %s: scale %.3f of the idle' % (d.upper(), k))
    x0, y0, x1, y1 = bbox(np.array(idle[0][0]))
    scale = PEND_H / float(y1 - y0)
    out = place_all(frames, scale, 'pendulum')
    death_gif(out[0], out[1])
    return out


def death_gif(strips, cw):
    """art/redraws/pendulum_v2_death.gif: the imported death (palette applied, game size) of the five facings side by
    side, x3, on the guides' navy; the last frame held"""
    n = strips[('death', 's')].shape[1] // cw
    ch = strips[('death', 's')].shape[0]
    gif = []
    for i in range(n):
        im = Image.new('RGBA', (5 * cw, ch), tuple(NAVY) + (255,))
        for r, d in enumerate(DIRS):
            im.alpha_composite(Image.fromarray(strips[('death', d)][:, i * cw:(i + 1) * cw]), (r * cw, 0))
        gif.append(im.convert('RGB').resize((5 * cw * 3, ch * 3), Image.NEAREST))
    gif[0].save(SRC + 'pendulum_v2_death.gif', save_all=True, append_images=gif[1:], duration=[160] * (n - 1) + [1200],
                loop=0)


# ------------------------------------------------------------------ the Netter

def netter():
    walk = grid_cells(SRC + 'netter_walk.png', 5, 8, 307, 204)
    fire = grid_cells(SRC + 'netter_fire.png', 5, 6, 307, 204)
    ax = [feet_x(walk[r][0]) for r in range(5)]
    frames = {}
    for r, d in enumerate(DIRS):
        frames[('idle', d)] = [(walk[r][0], ax[r], NET_GROUND, 1.0)]
        frames[('walk', d)] = [(o, ax[r], NET_GROUND, 1.0) for o in walk[r]]
        frames[('attack', d)] = [(o, ax[r], NET_GROUND, 1.0) for o in fire[r]]
    cg = SRC + 'netter_death_chatgpt.png'
    if os.path.exists(cg):
        rows = band_cells(cg, [(15, 207), (220, 396), (402, 581), (596, 783), (793, 981)], 5, 1536 / 5.0)
        print('netter death: ChatGPT (netter_death_chatgpt.png), each row scaled to the walk')
        for r, d in enumerate(DIRS):
            f0 = rows[r][0][0]
            # the row's own scale: its first frame as big as the walk's first frame (width and height together)
            wx0, wy0, wx1, wy1 = bbox(walk[r][0])
            dx0, dy0, dx1, dy1 = bbox(f0)
            s = float(np.sqrt((wx1 - wx0) / float(dx1 - dx0) * (wy1 - wy0) / float(dy1 - dy0)))
            a0 = (feet_x(f0), bottom(f0))
            frames[('death', d)] = [(o, a0[0], a0[1], s) for o, xy in rows[r]]
            print('  %s: scaled x%.3f (w %.2f, h %.2f)' % (d, s, (wx1 - wx0) / float(dx1 - dx0), (wy1 - wy0) / float(dy1 - dy0)))
    else:
        guide = grid_cells(SRC + 'netter_death_guide.png', 5, 5, 307, 204)
        print('netter death: the code guide (netter_death_guide.png; ChatGPT\'s not in yet)')
        for r, d in enumerate(DIRS):
            frames[('death', d)] = [(o, ax[r], NET_GROUND, 1.0) for o in guide[r]]
    x0, y0, x1, y1 = bbox(walk[0][0])
    scale = NETTER_W / float(x1 - x0)
    res = place_all(frames, scale, 'netter')
    # the muzzle per drawn direction on the fire frame (game px from the feet): the gun's farthest point the way it
    # points (S and N: the middle of the muzzle ring, which faces the viewer or points away)
    mouth = {}
    for r, d in enumerate(DIRS):
        o = fire[r][NET_FIRE_FRAME]
        al = o[..., 3] > 0
        ys, xs = np.nonzero(al)
        top = ys.min()
        gun = al.copy()
        gun[int(top + (ys.max() - top) * 0.36):] = False       # (the cannon sits on top of the drum)
        gy, gx = np.nonzero(gun)
        v = np.array(NET_AIM[d])
        if d in ('s', 'n'):
            sel = gy <= gy.min() + 14
            mx, my = gx[sel].mean(), gy[sel].mean() + 3.0
        else:
            proj = gx * v[0] + gy * v[1]
            sel = proj >= proj.max() - 6
            mx, my = gx[sel].mean(), gy[sel].mean()
        mouth[d] = ((mx - ax[r]) * scale, (my - NET_GROUND) * scale)
    print('mouth: {' + ', '.join('"%s": Vector2(%d, %d)' % (d, round(m[0]), round(m[1])) for d, m in mouth.items()) + '}')
    return res + (scale,)


# ------------------------------------------------------------------ the nets and the icons

def nets(scale):
    os.makedirs('assets/effects', exist_ok=True)
    out = {}
    for name, src, width in (('netter_net', 'netter_net_fly.png', 30.0), ('netter_net_open', 'netter_net_open.png', 46.0),
            ('netter_net_open_big', 'netter_net_open.png', 74.0)):
        im = np.array(Image.open(SRC + src).convert('RGBA'))
        x0, y0, x1, y1 = bbox(im)
        im = im[y0:y1, x0:x1]
        sm = soft_shrink(im, width / float(im.shape[1]))
        Image.fromarray(sm, 'RGBA').save('assets/effects/%s.png' % name)
        out[name] = sm.shape[1], sm.shape[0]
        print('EFFECTS: "%s": {"frames": 1, "size": Vector2i(%d, %d)},' % (name, sm.shape[1], sm.shape[0]))
    return out


def icon_upper(strip, cw, name, share=0.62):
    """A square of the figure's upper part (the head and body; the long legs cut), 64 x 64."""
    s = strip[:, :cw]
    ys, xs = np.nonzero(s[..., 3] > 0)
    side = int((ys.max() - ys.min()) * share) + 2
    cx = int(round((xs.min() + xs.max()) / 2))
    y0 = ys.min() - 1
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(Image.fromarray(s).crop((cx - side // 2, y0, cx - side // 2 + side, y0 + side)), (0, 0))
    sq.resize((64, 64), Image.NEAREST).save('assets/icons/%s.png' % name)


def icon_whole(strip, cw, name):
    """The whole figure, square, 64 x 64."""
    s = strip[:, :cw]
    ys, xs = np.nonzero(s[..., 3] > 0)
    side = max(xs.max() - xs.min(), ys.max() - ys.min()) + 4
    cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(Image.fromarray(s).crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)), (0, 0))
    sq.resize((64, 64), Image.NEAREST).save('assets/icons/%s.png' % name)


def make_preview(kinds, path):
    """Every strip at 3x on a grey-green ground, each frame's anchor marked: for checking the alignment by eye."""
    rows = []
    for kind, (strips, cw, ch, half, up) in kinds.items():
        for (anim, d), s in strips.items():
            rows.append((s, cw, half, up))
    Z = 3
    W = max(r[0].shape[1] for r in rows) * Z + 10
    Ht = sum(r[0].shape[0] * Z + 6 for r in rows)
    img = Image.new('RGBA', (W, Ht), (90, 110, 90, 255))
    y = 0
    for s, cw, half, up in rows:
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


def main():
    pv = {}
    ps, pcw, pch, phalf, pup = pendulum()
    pv['pendulum'] = (ps, pcw, pch, phalf, pup)
    ns, ncw, nch, nhalf, nup, nscale = netter()
    pv['netter'] = (ns, ncw, nch, nhalf, nup)
    nets(nscale)
    icon_upper(ps[('idle', 's')], pcw, 'pendulum', 0.84)      # (the tower, the clock and the two arms)
    icon_whole(ns[('idle', 'se')], ncw, 'netter')
    if len(sys.argv) > 1:
        make_preview(pv, sys.argv[1])


if __name__ == '__main__':
    main()
