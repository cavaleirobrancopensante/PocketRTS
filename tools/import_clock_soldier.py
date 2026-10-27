"""Import the Clock Soldier's ChatGPT sheets (art/redraws/clock_soldier_*.png, navy background RGB 0,22,48, 5 rows =
directions S SE E NE N) and its WEST sheets (3 rows = SW W NW: the sword stays in its right hand, so the west views are
not the east ones mirrored; owner, 2026-10-27) into the game's unit strips:
  assets/units/clock_soldier/{idle,walk,attack,death}_{s,se,e,ne,n,sw,w,nw}.png (frames side by side, one canvas for all)
and the cell / anchor line for scripts/cw_art.gd SHEETS (printed). The game draws a unit's own sw/w/nw strip unflipped
when it has one (Unit._set_anim), else the east strip mirrored.
WEST: the idle is ChatGPT's (clock_soldier_idle_west_chatgpt.png, painted a little bigger than the east sheet); the
walk, attack and death are built in code from it (tools/soldier_guide/west.py). Each west row is shrunk so its idle is
as tall as the matching east row's idle (SW as SE, W as E, NW as NE), so both halves of the compass are one size.

Per frame: key out the navy (tolerance ~40), take the pieces whose middle falls in the frame's grid cell (whole: ChatGPT's
figures cross the grid lines, the back views' caps and a raised sword; keyed_cells), drop specks, the Clockwork palette
(tools/cw_palette.py), shrink to game size (the S idle S_IDLE_H px tall: 42), snap the team reds to the shader's key reds.
Alignment (the figures are not always at the cell's centre): idle and walk frames are each put with their FEET (bounding
box bottom) on the
anchor and the body (centre of the red chest, taken before the palette makes it brass) on the anchor's x, so they do not
jitter; attack and death frames move on purpose, so every frame of a row gets the shift of that row's first frame.

PALETTE (owner, 2026-10-26; the rule for every Clockwork unit is in tools/cw_palette.py): the Clock Soldier is ALL
BRASS BUT ITS HEAD. Its round body, painted red, is repainted along its own brass ramp, and its blue shoulders and knee
gems go brass too (cw_palette.SOLDIER_HEAD_ONLY); its HEAD (the cap with the crown spike on top of the body) alone is
player colour, so it reads apart from the Jack (body and shoulders in player colour); the clock face stays white. The cap is found in every frame: on the idle frame of each direction
by its place (on the middle of the body's top), then laid on every frame of that direction (turned, scaled and shifted
around the body's middle until its colours and shading match: cw_palette.find_cap). The attack and death sheets use
their own first (upright) frame's cap as the template for the rest of their row (the same drawing). In the death the
body tips over: the search turns about the body's own axis, starting from the angle the code guide tipped it by
(DEATH_TILT); a frame where the cap is hidden (attack E, 3rd frame: the raised arm took its place) gets none.
  python3 tools/import_clock_soldier.py"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cw_palette

SRC = 'art/redraws/'
DST = 'assets/units/clock_soldier/'
SHEETS = {  # anim: (file, columns, align by first frame of the row)
    'idle': ('clock_soldier_idle.png', 4, False),
    'walk': ('clock_soldier_walk_mix.png', 6, False),
    'attack': ('clock_soldier_attack_final.png', 6, True),
    'death': ('clock_soldier_death_final.png', 7, True),
}
WEST_SHEETS = {  # the same anims, frame counts and timings, rows SW W NW
    'idle': ('clock_soldier_idle_west_chatgpt.png', 4, False),
    'walk': ('clock_soldier_walk_west.png', 6, False),
    'attack': ('clock_soldier_attack_west.png', 6, True),
    'death': ('clock_soldier_death_west.png', 7, True),
}
DIRS = ['s', 'se', 'e', 'ne', 'n']
WEST_DIRS = ['sw', 'w', 'nw']
EAST_OF = {'sw': 'se', 'w': 'e', 'nw': 'ne'}
NAVY = np.array([0, 22, 48])
TOL = 40
S_IDLE_H = 42.0        # px: the S idle's height in game. The owner (2026-10-26): 59 was too big; about 30% smaller, by a
                       # Musketeer (35), a Labourer (32) and a Netter (45), and well under the Jack (59, its own size in
                       # tools/import_jack.py), which helps tell the two apart
ICON_SCALE = 0.359     # the card portrait's own scale (the size the unit had until 0.14.32: the icon keeps its detail)
# The death's tip, as the code guide drew it (tools/soldier_guide/death.py FALL, ANG; ChatGPT's clean-up kept the poses):
# per row the side it falls to (-1: its top goes left), per frame the angle; the cap is searched WINDOW degrees round it.
DEATH_FALL = {'s': -1, 'se': -1, 'e': 1, 'ne': 1, 'n': 1, 'sw': 1, 'w': -1, 'nw': -1}   # (west: the east row's mirrored)
DEATH_ANG = [0, 6, 28, 62, 92, 84, 90]
WINDOW, WINDOW_TIPPED = 16.0, 30.0


PAD = 64               # px round a grid cell: ChatGPT's figures cross the grid lines (the back views' caps by up to 28 px,
                       # a raised sword by 51), so a frame is the cell this much bigger all round


def keyed_cells(path, cols, rows=5):
    """{(row, col): keyed frame}: each frame is its grid cell PAD px bigger all round (so every frame of a sheet keeps its
    cell's coordinates), with the sheet's pieces whose middle falls in that cell: a figure crossing the grid lines stays
    whole (its cap, a raised sword), a neighbour's spilling into the cell is not taken; pieces under 25 px are dropped."""
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    H, W = a.shape[:2]
    m = np.abs(a - NAVY).sum(2) >= TOL
    lab, n = ndi.label(m)
    sz = ndi.sum(m, lab, range(1, n + 1)) if n else []
    owner = np.full(n + 1, -1)
    for i, sl in enumerate(ndi.find_objects(lab)):
        if sz[i] < 25:
            continue
        ys, xs = np.nonzero(lab[sl] == i + 1)
        r = min(rows - 1, int((ys.mean() + sl[0].start) / (H / float(rows))))
        c = min(cols - 1, int((xs.mean() + sl[1].start) / (W / float(cols))))
        owner[i + 1] = r * cols + c
    ap = np.pad(a, ((PAD, PAD), (PAD, PAD), (0, 0)))
    ap[:PAD], ap[-PAD:], ap[:, :PAD], ap[:, -PAD:] = NAVY, NAVY, NAVY, NAVY
    lp = np.pad(owner[lab], PAD, constant_values=-1)
    out = {}
    for r in range(rows):
        for c in range(cols):
            x0, y0 = round(c * W / cols), round(r * H / rows)
            x1, y1 = round((c + 1) * W / cols) + 2 * PAD, round((r + 1) * H / rows) + 2 * PAD
            sub = ap[y0:y1, x0:x1]
            mine = lp[y0:y1, x0:x1] == r * cols + c
            mine = ndi.binary_fill_holes(mine) & (np.abs(sub - NAVY).sum(2) >= 12) | mine   # (dark glass-like insides stay solid)
            o = np.zeros(sub.shape[:2] + (4,), np.uint8)
            o[..., :3] = sub
            o[..., 3] = mine * 255
            out[(r, c)] = o
    return out


def red_x(o):
    """x of the body: the centre of the red chest pixels (else the box's centre)."""
    r, g, b, al = [o[..., i].astype(int) for i in range(4)]
    red = (al > 0) & (r >= 100) & (g <= r * 0.35) & (b <= r * 0.4)
    if red.sum() > 30:
        return float(np.nonzero(red)[1].mean())
    xs = np.nonzero(al.any(0))[0]
    return (xs.min() + xs.max()) * 0.5


def bottom(o):
    ys = np.nonzero((o[..., 3] > 0).any(1))[0]
    return float(ys.max() + 1)


def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then hard alpha (tools/import_art.py)."""
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


def palette(frames):
    """Every frame through the Clockwork palette (tools/cw_palette.py), in place: (anim, dir) -> [(rgba, ax, ay)]. The cap's
    template per direction: the idle's first frame; an attack or death row then uses its own first frame's cap."""
    for d in DIRS + WEST_DIRS:
        idle_ref = frames[('idle', d)][0][0]
        for anim in SHEETS:
            fl = frames[(anim, d)]
            if anim == 'death':
                assert len(fl) == len(DEATH_ANG), 'death %s: %d frames, the tilt table has %d' % (d, len(fl), len(DEATH_ANG))
            ref = idle_ref
            for i, (o, ax, ay) in enumerate(fl):
                tilt = DEATH_FALL[d] * DEATH_ANG[i] if anim == 'death' else 0.0
                tipped = abs(tilt) > 15
                info = {}
                o2 = cw_palette.recolour(o, 'clock_soldier', ref=ref, tilt=tilt, window=WINDOW_TIPPED if tipped else WINDOW,
                                         tipped=tipped, info=info)
                if not info['cap'].any():
                    print('clock_soldier %s %s frame %d: no cap found (match %.2f, shading %.2f)' % (
                        anim, d, i, info.get('cap_score', 0), info.get('cap_ncc', 0)))
                if anim in ('attack', 'death') and i == 0:
                    ref = cw_palette.template_from(o, info['cap']) or idle_ref
                fl[i] = (o2, ax, ay)


def main():
    # 1. cut and key every frame, note its anchor (feet bottom, body x) in the cell
    frames = {}      # (anim, dir) -> [(rgba, ax, ay)]
    for sheets, dirs in ((SHEETS, DIRS), (WEST_SHEETS, WEST_DIRS)):
        for anim, (f, cols, by_first) in sheets.items():
            cells = keyed_cells(SRC + f, cols, len(dirs))
            for row, d in enumerate(dirs):
                out = []
                first = None
                for c in range(cols):
                    o = cells[(row, c)]
                    if not (o[..., 3] > 0).any():
                        continue
                    ax, ay = red_x(o), bottom(o)
                    if by_first:
                        if first is None:
                            first = (ax, ay)
                        ax, ay = first
                    out.append((o, ax, ay))
                frames[(anim, d)] = out
    # 2. the scale: the S idle S_IDLE_H px tall; a west row: its idle as tall as the matching east row's
    def idle_h(d):
        hs = []
        for o, ax, ay in frames[('idle', d)]:
            ys = np.nonzero((o[..., 3] > 0).any(1))[0]
            hs.append(ys.max() - ys.min() + 1)
        return float(np.median(hs))
    scale = S_IDLE_H / idle_h('s')
    SC = {d: scale for d in DIRS}
    for d in WEST_DIRS:
        SC[d] = scale * idle_h(EAST_OF[d]) / idle_h(d)
    # 3. one canvas: the farthest any frame reaches from its anchor (in game px)
    L = R = U = D = 0.0
    for (anim, d), fl in frames.items():
        for o, ax, ay in fl:
            ys, xs = np.nonzero(o[..., 3] > 0)
            L = max(L, (ax - xs.min()) * SC[d])
            R = max(R, (xs.max() + 1 - ax) * SC[d])
            U = max(U, (ay - ys.min()) * SC[d])
            D = max(D, (ys.max() + 1 - ay) * SC[d])
    half = int(np.ceil(max(L, R))) + 1
    cw = half * 2
    up = int(np.ceil(U)) + 1
    down = int(np.ceil(D)) + 1
    ch = up + down
    os.makedirs(DST, exist_ok=True)
    palette(frames)          # (after the anchors: they look for the red body the palette makes brass)
    for (anim, d), fl in frames.items():
        scale = SC[d]
        strip = np.zeros((ch, cw * len(fl), 4), np.uint8)
        for i, (o, ax, ay) in enumerate(fl):
            # the source on a canvas cw/scale x ch/scale with its anchor at (half, up)/scale, then shrunk to cw x ch
            BW, BH = int(round(cw / scale)), int(round(ch / scale))
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / scale - ax)), int(round(up / scale - ay))))
            s = shrink(np.array(big), cw / BW)
            s = s[:ch, :cw]
            s = cw_palette.snap_team(s)
            strip[:s.shape[0], i * cw:i * cw + s.shape[1]] = s
        Image.fromarray(strip, 'RGBA').save(DST + '%s_%s.png' % (anim, d))
    print('clock_soldier: scale %.3f (west %s), cell %dx%d, anchor (%d, %d)' % (
        SC['s'], ' '.join('%s %.3f' % (d, SC[d]) for d in WEST_DIRS), cw, ch, half, up))
    print('SHEETS line: "clock_soldier": [%d, %d, %d, %d],' % (cw, ch, half, up))
    # 4. the card portrait (64 x 64): the S idle frame's upper body, shrunk at its own ICON_SCALE
    o, ax, ay = frames[('idle', 's')][0]
    s0 = cw_palette.snap_team(shrink(o, ICON_SCALE))   # (the S frame, painted at the main sheet's size)
    ys, xs = np.nonzero(s0[..., 3] > 0)
    side = max(xs.max() - xs.min(), int((ys.max() - ys.min()) * 0.8)) + 2
    cx = (xs.min() + xs.max()) // 2
    crop = Image.fromarray(s0).crop((cx - side // 2, ys.min() - 1, cx - side // 2 + side, ys.min() - 1 + side))
    crop.resize((64, 64), Image.NEAREST).save('assets/icons/clock_soldier.png')


if __name__ == '__main__':
    main()
