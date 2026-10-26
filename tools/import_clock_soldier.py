"""Import the Clock Soldier's ChatGPT sheets (art/redraws/clock_soldier_*.png, navy background RGB 0,22,48, 5 rows =
directions S SE E NE N; the west views are the east ones mirrored in the game) into the game's unit strips:
  assets/units/clock_soldier/{idle,walk,attack,death}_{s,se,e,ne,n}.png (frames side by side, one canvas for all)
and the cell / anchor line for scripts/cw_art.gd SHEETS (printed).

Per frame: slice the grid cell, key out the navy (tolerance ~40), drop specks, shrink to game size (about 1.3x the
Winder's height), snap the team reds to the shader's key reds. Alignment (the figures are not always at the cell's
centre): idle and walk frames are each put with their FEET (bounding box bottom) on the anchor and the body (centre of
the red chest) on the anchor's x, so they do not jitter; attack and death frames move on purpose, so every frame of a
row gets the shift of that row's first frame.
  python3 tools/import_clock_soldier.py"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = 'art/redraws/'
DST = 'assets/units/clock_soldier/'
SHEETS = {  # anim: (file, columns, align by first frame of the row)
    'idle': ('clock_soldier_idle.png', 4, False),
    'walk': ('clock_soldier_walk_mix.png', 6, False),
    'attack': ('clock_soldier_attack_final.png', 6, True),
    'death': ('clock_soldier_death_final.png', 7, True),
}
DIRS = ['s', 'se', 'e', 'ne', 'n']
NAVY = np.array([0, 22, 48])
TOL = 40
WINDER_H = 43          # px: the Winder's height in game (assets/units/winder/idle_s.png)
TALL = 1.3             # the Clock Soldier stands this much taller
TEAM_LIGHT = (255, 0, 0)
TEAM_DARK = (150, 0, 0)


def key(cell):
    a = np.array(cell.convert('RGB')).astype(int)
    m = np.abs(a - NAVY).sum(2) >= TOL
    lab, n = ndi.label(m)
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1))
        big = int(np.argmax(sz)) + 1
        keep = []
        H, W = m.shape
        for k, z in enumerate(sz):
            if z < 25:
                continue
            ys, xs = np.nonzero(lab == k + 1)
            # a piece of the next cell's figure spilling over the edge: not ours
            if k + 1 != big and (ys.min() <= 1 or ys.max() >= H - 2 or xs.min() <= 1 or xs.max() >= W - 2):
                continue
            keep.append(k + 1)
        m &= np.isin(lab, keep)
    m = ndi.binary_fill_holes(m) & (np.abs(a - NAVY).sum(2) >= 12) | m      # (dark glass-like insides stay solid)
    o = np.zeros(a.shape[:2] + (4,), np.uint8)
    o[..., :3] = a
    o[..., 3] = m * 255
    return o


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


def snap_team(img):
    """Team-coloured parts -> exact key reds the shader recolours (tools/import_art.py)."""
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    red = (img[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32)
    light = red & (r >= 175)
    img[light, :3] = TEAM_LIGHT
    img[red & ~light, :3] = TEAM_DARK
    return img


def main():
    # 1. cut and key every frame, note its anchor (feet bottom, body x) in the cell
    frames = {}      # (anim, dir) -> [(rgba, ax, ay)]
    for anim, (f, cols, by_first) in SHEETS.items():
        im = Image.open(SRC + f).convert('RGB')
        W, H = im.size
        for row, d in enumerate(DIRS):
            out = []
            first = None
            for c in range(cols):
                box = (round(c * W / cols), round(row * H / 5), round((c + 1) * W / cols), round((row + 1) * H / 5))
                o = key(im.crop(box))
                if not (o[..., 3] > 0).any():
                    continue
                ax, ay = red_x(o), bottom(o)
                if by_first:
                    if first is None:
                        first = (ax, ay)
                    ax, ay = first
                out.append((o, ax, ay))
            frames[(anim, d)] = out
    # 2. the scale: the idle figures' height to TALL x the Winder's
    hs = []
    for d in DIRS:
        for o, ax, ay in frames[('idle', d)]:
            ys = np.nonzero((o[..., 3] > 0).any(1))[0]
            hs.append(ys.max() - ys.min() + 1)
    scale = WINDER_H * TALL / float(np.median(hs))
    # 3. one canvas: the farthest any frame reaches from its anchor
    L = R = U = D = 0.0
    for fl in frames.values():
        for o, ax, ay in fl:
            ys, xs = np.nonzero(o[..., 3] > 0)
            L = max(L, ax - xs.min())
            R = max(R, xs.max() + 1 - ax)
            U = max(U, ay - ys.min())
            D = max(D, ys.max() + 1 - ay)
    half = int(np.ceil(max(L, R) * scale)) + 1
    cw = half * 2
    up = int(np.ceil(U * scale)) + 1
    down = int(np.ceil(D * scale)) + 1
    ch = up + down
    os.makedirs(DST, exist_ok=True)
    for (anim, d), fl in frames.items():
        strip = np.zeros((ch, cw * len(fl), 4), np.uint8)
        for i, (o, ax, ay) in enumerate(fl):
            # the source on a canvas cw/scale x ch/scale with its anchor at (half, up)/scale, then shrunk to cw x ch
            BW, BH = int(round(cw / scale)), int(round(ch / scale))
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / scale - ax)), int(round(up / scale - ay))))
            s = shrink(np.array(big), cw / BW)
            s = s[:ch, :cw]
            s = snap_team(s)
            strip[:s.shape[0], i * cw:i * cw + s.shape[1]] = s
        Image.fromarray(strip, 'RGBA').save(DST + '%s_%s.png' % (anim, d))
    print('clock_soldier: scale %.3f, cell %dx%d, anchor (%d, %d)' % (scale, cw, ch, half, up))
    print('SHEETS line: "clock_soldier": [%d, %d, %d, %d],' % (cw, ch, half, up))
    # 4. the card portrait (64 x 64): the S idle frame's upper body
    s0 = np.array(Image.open(DST + 'idle_s.png'))[:, :cw]
    ys, xs = np.nonzero(s0[..., 3] > 0)
    side = max(xs.max() - xs.min(), int((ys.max() - ys.min()) * 0.8)) + 2
    cx = (xs.min() + xs.max()) // 2
    crop = Image.fromarray(s0).crop((cx - side // 2, ys.min() - 1, cx - side // 2 + side, ys.min() - 1 + side))
    crop.resize((64, 64), Image.NEAREST).save('assets/icons/clock_soldier.png')


if __name__ == '__main__':
    main()
