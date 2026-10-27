"""Clock Soldier WEST views (SW, W, NW): the walk, attack and death built in code from ChatGPT's painted west idle
(art/redraws/clock_soldier_idle_west_chatgpt.png, rows SW W NW, 4 idle frames), the way walk_code.py, attack.py and
death.py built the east rows from the east idle. The sword stays in the soldier's RIGHT hand (owner, 2026-10-27): in the
west views that is the FAR arm, so it is cut out, swung about its shoulder and drawn BEHIND the body (only what clears the
body shows). The motion is the matching east row's mirrored (SW from SE, W from E, NW from NE).
  W: the far arm is hidden behind the shield and body in the painting (only the blade shows), so its arm is the east E
     idle's sword arm, mirrored and scaled to the west sheet, the painted blade taken off the body.
  Walk: the legs cut at the hip and sheared like walk_code.py, the forward vector mirrored (the body, arms, sword and
     shield stay as painted, with a small bob).
  Death: tips over about its feet like death.py, to the mirrored side.
Out (3 rows SW W NW on a 1536 x 1024 navy sheet, like the east sheets; tools/import_clock_soldier.py imports them):
  art/redraws/clock_soldier_{walk,attack,death}_west.png and a .gif of each.
  python3 tools/soldier_guide/west.py [--debug out.png]"""
import math
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

NAVY = np.array([0, 22, 48])
SRC = 'art/redraws/clock_soldier_idle_west_chatgpt.png'
EAST = 'art/redraws/clock_soldier_idle.png'
OUT = 'art/redraws/clock_soldier_%s_west.png'
H = 1024
WIDE = {'walk': 1536, 'attack': 1920, 'death': 2380}   # sheet widths: room for a raised sword or a body lying down
ROWS = ['sw', 'w', 'nw']
CH = H // 3
BASE = 300            # the feet's line in a row's cell (room above for a raised sword)

# per row, in the crop's own px: the idle frame's box, hip line, the x the legs split at, the far (back) leg, the forward
# vector on screen, what below the hip is NOT leg (x limits, a sword line (x0, y0, x1, y1, width), the shield ellipse
# (cx, cy, rx, ry)), and the far sword arm: polygon, sword line, shoulder pivot, wind-up and strike angles (PIL: + =
# counter-clockwise; the east row's mirrored), lean of the body (x, y px at full)
P = {
    'sw': dict(box=(145, 137, 310, 324), hip=118, split=85, far='L', fwd=(-0.7, 0.35),
               excl=(None, None, (4, 164, 40, 118, 7), (131, 117, 30, 37)),
               arm=[(24, 72), (46, 72), (46, 104), (52, 112), (50, 128), (40, 142), (26, 142), (10, 140), (5, 130), (16, 118), (22, 100)],
               sword=(0, 169, 40, 118, 7), pivot=(39, 60), wa=-135, sa=-40, lean=(-2, 1)),
    'w': dict(box=(150, 386, 268, 578), hip=135, split=72, far='R', fwd=(-1.0, 0.0),
              excl=(None, None, (5, 159, 37, 126, 7), (53, 115, 30, 37)),
              blade=(5, 159, 37, 126, 7), pivot=(82, 62), wa=-115, sa=-40, lean=(-3, 0)),
    'nw': dict(box=(152, 640, 319, 817), hip=108, split=85, far='R', fwd=(-0.7, -0.35),
               excl=(None, None, (112, 102, 162, 162, 7), (30, 105, 21, 37)),
               arm=[(108, 70), (140, 70), (148, 92), (147, 124), (130, 134), (114, 122), (106, 96)],
               sword=(112, 102, 164, 164, 7), pivot=(122, 60), wa=135, sa=25, lean=(-2, -1)),
}
# the east E idle's sword arm (attack.py ROW[2]): its box in the east sheet, polygon, sword line, pivot
E_BOX = (197, 409, 317, 566)
E_ARM = [(30, 64), (64, 64), (66, 110), (40, 110)]
E_SWORD = (54, 104, 120, 150, 8)
E_PIVOT = (45, 54)


def fg(F):
    return np.abs(F - NAVY).sum(2) > 45


def poly_mask(shape, pts):
    m = Image.new('L', (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.array(m) > 0


def line_mask(shape, ln):
    x0, y0, x1, y1, w = ln
    h, ww = shape
    yy, xx = np.mgrid[0:h, 0:ww]
    dx, dy = x1 - x0, y1 - y0
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / float(dx * dx + dy * dy), 0, 1)
    return np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy)) < w


def ellipse_mask(shape, e):
    cx, cy, rx, ry = e
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0


def crop(r):
    im = np.array(Image.open(SRC).convert('RGB')).astype(int)
    x0, y0, x1, y1 = P[r]['box']
    return im[y0:y1, x0:x1]


def not_leg(shape, r):
    lo, hi, line, ell = P[r]['excl']
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros(shape, bool)
    if lo is not None:
        m |= xx < lo
    if hi is not None:
        m |= xx > hi
    if line:
        m |= line_mask(shape, line)
    if ell:
        m |= ellipse_mask(shape, ell)
    if 'arm' in P[r]:
        m |= poly_mask(shape, P[r]['arm'])        # (the sword hand hangs below the hip)
    return m


def rgba(F, m):
    o = np.zeros(F.shape[:2] + (4,), np.uint8)
    o[..., :3] = F
    o[..., 3] = m * 255
    return Image.fromarray(o, 'RGBA')


def feet_y(M):
    return int(np.nonzero(M.any(1))[0].max()) + 1


# ------------------------------------------------------------------ walk

def warp_leg(F, lm, hip, s, lift, fx, fy):
    """walk_code.py's leg warp: the leg stays on at the hip, its foot sheared s px along the forward vector and the leg
    shortened by `lift` when it lifts."""
    h, w = lm.shape
    out = np.zeros_like(F)
    ys, xs = np.nonzero(lm)
    if len(ys) == 0:
        return out, np.zeros_like(lm)
    Lh = max(1, ys.max() - hip)
    newL = max(4, Lh + fy * s - lift)
    yy, xx = np.mgrid[0:h, 0:w]
    ty = yy - hip
    frac = np.clip(ty / newL, 0, None)
    sy = (hip + frac * Lh).round().astype(int)
    sx = (xx - fx * s * np.clip(frac, 0, 1)).round().astype(int)
    ok = (ty >= 0) & (sy < h) & (sx >= 0) & (sx < w)
    sel = np.zeros_like(lm)
    sel[ok] = lm[sy[ok], sx[ok]]
    out[sel] = F[sy[sel], sx[sel]]
    return out, sel


def walk_frames(r):
    p = P[r]
    F = crop(r)
    M = fg(F)
    hip, split, far = p['hip'], p['split'], p['far']
    fx, fy = p['fwd']
    X = not_leg(M.shape, r)
    body = M.copy()
    body[hip:, :] &= X[hip:, :]
    M2 = M & ~X
    legL = np.zeros_like(M)
    legL[hip:, :split] = M2[hip:, :split]
    legR = np.zeros_like(M)
    legR[hip:, split:] = M2[hip:, split:]
    PD = 18
    Fp = np.zeros((F.shape[0] + PD, F.shape[1] + 2 * PD, 3), int)
    Fp[:] = NAVY
    Fp[:F.shape[0], PD:PD + F.shape[1]] = F

    def pad(m):
        o = np.zeros(Fp.shape[:2], bool)
        o[:m.shape[0], PD:PD + m.shape[1]] = m
        return o
    body, legL, legR = pad(body), pad(legL), pad(legR)
    A, L = 12.0, 8.0
    out = []
    for c in range(6):
        ph = c / 6.0
        sA = math.cos(2 * math.pi * ph) * A
        lA = max(0.0, math.sin(2 * math.pi * ph)) * L
        sB, lB = -sA, max(0.0, -math.sin(2 * math.pi * ph)) * L
        bob = round(1.5 * abs(math.cos(2 * math.pi * ph)))
        cell = np.zeros_like(Fp)
        cell[:] = NAVY
        legs = [('L', legL, sA, lA), ('R', legR, sB, lB)]
        legs.sort(key=lambda t: 0 if t[0] == far else 1)
        for name, lm, s, lift in legs:
            src = Fp.copy()
            if name == far:
                src = (src * 0.85).astype(int)
            o, om = warp_leg(src, lm, hip, s, lift, fx, fy)
            cell[om] = o[om]
        b = np.roll(body, bob, axis=0)
        bs = np.roll(Fp, bob, axis=0)
        cell[b] = bs[b]
        out.append((cell, PD))
    return out


# ------------------------------------------------------------------ attack

def cut_hole(Fp, M, arm):
    """The body without the arm: where the arm lay over the body's hull, the nearest body pixels (attack.py)."""
    rest = M & ~arm
    lab, n = ndi.label(rest)
    if n > 1:
        sz = ndi.sum(rest, lab, range(1, n + 1))
        for k, z in enumerate(sz, 1):
            if z < 80:
                rest &= lab != k
    hull = ndi.binary_closing(rest, iterations=6)
    hole = arm & hull
    base = Fp.copy()
    base[arm] = NAVY
    if hole.any():
        _, (iy, ix) = ndi.distance_transform_edt(~rest, return_indices=True)
        base[hole] = Fp[iy[hole], ix[hole]]
    return base, rest | hole


def east_arm(scale):
    """The east E idle's sword arm, mirrored (it becomes the W view's far arm) and scaled: (RGBA image, pivot)."""
    im = np.array(Image.open(EAST).convert('RGB')).astype(int)
    x0, y0, x1, y1 = E_BOX
    F = im[y0:y1, x0:x1]
    M = fg(F)
    arm = (poly_mask(M.shape, E_ARM) | line_mask(M.shape, E_SWORD)) & M
    img = rgba(F, arm).transpose(Image.FLIP_LEFT_RIGHT)
    w = F.shape[1]
    piv = (w - 1 - E_PIVOT[0], E_PIVOT[1])
    img = img.resize((int(round(img.width * scale)), int(round(img.height * scale))), Image.NEAREST)
    return img, (piv[0] * scale, piv[1] * scale)


PAD_A = 70


def attack_frames(r):
    p = P[r]
    F = crop(r)
    Fp = np.zeros((F.shape[0] + 2 * PAD_A, F.shape[1] + 2 * PAD_A, 3), int)
    Fp[:] = NAVY
    Fp[PAD_A:PAD_A + F.shape[0], PAD_A:PAD_A + F.shape[1]] = F
    M = fg(Fp)
    sh = lambda pts: [(x + PAD_A, y + PAD_A) for x, y in pts]
    if r == 'w':
        x0, y0, x1, y1, wd = p['blade']
        blade = line_mask(M.shape, (x0 + PAD_A, y0 + PAD_A, x1 + PAD_A, y1 + PAD_A, wd)) & M
        cx, cy, rx, ry = P['w']['excl'][3]
        blade &= ~ellipse_mask(M.shape, (cx + PAD_A, cy + PAD_A, rx, ry))
        base, restm = cut_hole(Fp, M, blade)
        restm &= ~blade
        # the arm: the east E arm mirrored, at the west sheet's size (W idle 185 px tall, E idle 157)
        ARM0, piv0 = east_arm(185.0 / 157.0)
        piv = (p['pivot'][0] + PAD_A, p['pivot'][1] + PAD_A)
        big = Image.new('RGBA', (Fp.shape[1], Fp.shape[0]), (0, 0, 0, 0))
        big.alpha_composite(ARM0, (int(round(piv[0] - piv0[0])), int(round(piv[1] - piv0[1]))))
        ARM = big
    else:
        arm = (poly_mask(M.shape, sh(p['arm'])) | line_mask(M.shape, tuple(
            v + PAD_A if i < 4 else v for i, v in enumerate(p['sword'])))) & M
        base, restm = cut_hole(Fp, M, arm)
        ARM = rgba(Fp, arm)
        piv = (p['pivot'][0] + PAD_A, p['pivot'][1] + PAD_A)
    # the far arm a shade darker (it is behind the body)
    a = np.array(ARM).astype(float)
    a[..., :3] *= 0.88
    ARM = Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGBA')
    wa, sa = p['wa'], p['sa']
    seq = [0, 0.5 * wa, wa, sa, 0.6 * sa, 0.2 * sa]
    lean = [0, -0.4, -0.6, 1.0, 0.7, 0.2]
    out = []
    for ang, l in zip(seq, lean):
        dx, dy = int(round(p['lean'][0] * l)), int(round(p['lean'][1] * l))
        img = Image.new('RGBA', ARM.size, (0, 0, 0, 0))
        a2 = ARM.rotate(ang, resample=Image.NEAREST, center=piv, translate=(dx, dy))
        img.alpha_composite(a2)                               # the far arm first: the body goes over it
        shm = np.roll(np.roll(restm, dy, 0), dx, 1)
        bs = np.roll(np.roll(base, dy, 0), dx, 1)
        img.alpha_composite(rgba(bs, shm))
        f = Image.new('RGB', img.size, tuple(NAVY))
        f.paste(img, (0, 0), img)
        out.append((np.array(f).astype(int), PAD_A))
    return out


# ------------------------------------------------------------------ death

FALL = {'sw': 1, 'w': -1, 'nw': -1}        # death.py FALL of SE, E, NE mirrored (-1: the top goes left)
ANG = [0, 6, 28, 62, 92, 84, 90]
DROP = [0, -2, 0, 2, 6, 4, 6]
LAND = 27


def death_frames(r):
    F = crop(r)
    M = fg(F)
    s = rgba(F, M)
    w, h = s.size
    fall = FALL[r]
    out = []
    fy0 = feet_y(M)
    for c, (a, dy) in enumerate(zip(ANG, DROP)):
        big = Image.new('RGBA', (w * 4, h * 3), (0, 0, 0, 0))
        fx, fy = w * 2, h * 2          # (room all round: a body lying down reaches below its feet)
        big.alpha_composite(s, (fx - w // 2, fy - fy0))
        rot = big.rotate(a * (-fall), resample=Image.BICUBIC, center=(fx, fy))
        if c >= 5:
            arr = np.array(rot).astype(float)
            arr[..., :3] *= 0.8 if c == 6 else 0.9
            rot = Image.fromarray(arr.clip(0, 255).astype(np.uint8), 'RGBA')
        al = np.array(rot)[..., 3]
        rot = Image.fromarray(np.where(al[..., None] >= 128, np.array(rot), 0).astype(np.uint8), 'RGBA')
        f = Image.new('RGB', rot.size, tuple(NAVY))
        f.paste(rot, (0, 0), rot)
        # it falls onto the ground: its lowest point on the feet's line (plus the bounce, DROP), and as it goes over it
        # slides back under where it stood and a little toward us (LAND), as ChatGPT's east deaths lie: centred under
        # the anchor, 5-8 game px below the feet
        ys, xs = np.nonzero(al >= 128)
        low = int(ys.max()) + 1
        k = min(1.0, a / 90.0)
        bcx = (xs.min() + xs.max() + 1) * 0.5
        out.append((np.array(f).astype(int), (int(round(fx + (bcx - fx) * k)), int(round(low - dy - LAND * k)))))
    return out


# ------------------------------------------------------------------ the sheets

def place(sheet, cell, r, c, cols, foot, at=0.5):
    """Paste `cell` (RGB, navy ground) so its point `foot` (x, y) lands at the cell's middle on the row's BASE line."""
    W = sheet.shape[1]
    CW = W // cols
    x = c * CW + int(CW * at) - foot[0]
    y = r * CH + BASE - foot[1]
    fgm = np.abs(cell - NAVY).sum(2) > 0
    ys, xs = np.nonzero(fgm)
    for yy, xx in zip(ys, xs):
        X, Y = x + xx, y + yy
        if 0 <= X < W and r * CH <= Y < (r + 1) * CH:
            sheet[Y, X] = cell[yy, xx]


def gif(sheet, cols, path, dur):
    CW = sheet.shape[1] // cols
    frames = []
    for c in range(cols):
        o = Image.new('RGB', (3 * CW, CH), tuple(NAVY))
        for r in range(3):
            o.paste(Image.fromarray(sheet[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW].astype(np.uint8)), (r * CW, 0))
        frames.append(o)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=dur, loop=0)


def build():
    for anim, cols, dur in (('walk', 6, 140), ('attack', 6, [110, 110, 160, 90, 110, 140]),
                            ('death', 7, [150, 100, 90, 80, 120, 120, 900])):
        sheet = np.zeros((H, WIDE[anim], 3), int)
        sheet[:] = NAVY
        for ri, r in enumerate(ROWS):
            F = crop(r)
            fy = feet_y(fg(F))
            xm = F.shape[1] // 2
            if anim == 'walk':
                for c, (cell, pd) in enumerate(walk_frames(r)):
                    place(sheet, cell, ri, c, cols, (xm + pd, fy))
            elif anim == 'attack':
                for c, (cell, pd) in enumerate(attack_frames(r)):
                    place(sheet, cell, ri, c, cols, (xm + pd, fy + pd))
            else:
                for c, (cell, foot) in enumerate(death_frames(r)):
                    place(sheet, cell, ri, c, cols, foot)
        Image.fromarray(sheet.astype(np.uint8)).save(OUT % anim)
        gif(sheet, cols, (OUT % anim).replace('.png', '.gif'), dur)
        print('saved', OUT % anim)


def debug(path):
    """The masks over each row's idle frame (legs blue/green, not-leg red, the arm yellow), 4x."""
    tiles = []
    for r in ROWS:
        p = P[r]
        F = crop(r)
        M = fg(F)
        img = F.astype(float).copy()
        X = not_leg(M.shape, r)
        hip, split = p['hip'], p['split']
        leg = np.zeros_like(M)
        leg[hip:] = (M & ~X)[hip:]
        L = leg.copy()
        L[:, split:] = False
        R = leg & ~L
        img[L] = img[L] * 0.4 + np.array([0, 0, 255]) * 0.6
        img[R] = img[R] * 0.4 + np.array([0, 255, 0]) * 0.6
        xm = X & M
        xm[:hip] = False
        img[xm] = img[xm] * 0.5 + np.array([255, 0, 0]) * 0.5
        if 'arm' in p:
            am = (poly_mask(M.shape, p['arm']) | line_mask(M.shape, p['sword'])) & M
            img[am] = img[am] * 0.4 + np.array([255, 255, 0]) * 0.6
        t = Image.fromarray(img.clip(0, 255).astype(np.uint8))
        d = ImageDraw.Draw(t)
        d.ellipse([p['pivot'][0] - 2, p['pivot'][1] - 2, p['pivot'][0] + 2, p['pivot'][1] + 2], outline=(255, 255, 255))
        tiles.append(t.resize((t.width * 4, t.height * 4), Image.NEAREST))
    o = Image.new('RGB', (sum(t.width for t in tiles) + 20, max(t.height for t in tiles)), (30, 30, 30))
    x = 0
    for t in tiles:
        o.paste(t, (x, 0))
        x += t.width + 10
    o.save(path)


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--debug':
        debug(sys.argv[2])
    else:
        build()
