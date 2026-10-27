"""Great Winder WALK, WIND and SWEEP in code from ChatGPT's direction sheet (art/redraws/great_winder_dirs.png: rows S,
SE, E, NE, N; column 1 the machine with its winding arm stowed, column 2 the arm out), in the style of the Netter's
walk (tools/netter_guide/walk.py): painted parts cut out and moved, little drawn.

WALK (12 frames) on ChatGPT's painted leg (art/redraws/great_winder_leg_chatgpt.png: rows side / three-quarter / front,
columns standing / lifted back / swung forward / down ahead). The sheet's stubby legs (ball, collar, dome foot) are cut
off the body (cut_legs, ROWS) and the body stands higher on the new, longer legs: the ground moves down, the body stays
put in its window. LEGS = 4 (default: a slow, heavy walk, one leg at a time, LB LF RB RF) or 6 (a tripod gait). Side
legs in E, three-quarter legs in SE / NE, front legs in S / N; the far side's legs are the same paint behind the body,
darker. A planted leg: the standing cell cut into hip ball, rigid leg and flat foot; the foot stays put on the ground
(it slides back at the body's speed, so it is planted while the machine moves), the rigid leg turns about the hip to
reach it and slides up under the hip ball for the rest (REST_LEN is chosen so it never has to slide down; in S / N the
step is depth, so it is not turned). A stepping leg: the painted step poses (column 2, then column 3) turned about the
hip so the foot follows a smooth path from behind to ahead (S / N: turned so it stays under the hip), never through
the floor. The body dips 1 game px as each leg (tripod) lands; ground speed: 2 * STRIDE / duty * GS game px a loop.

WIND (12 frames): the winding arm (cut from column 2 and laid on the column-1 body) slides out of the machine along its
length (frames 0-2), then ChatGPT's painted key head at its end (art/redraws/great_winder_key_rollers_chatgpt.png, top)
turns about the arm in 8 painted steps of 45 deg (frames 2-9: face-on, 45, edge-on, ... back face), its shaft along
the arm, then the arm slides back in (10-11). Frames 2-9 loop while it winds. N: ChatGPT drew the arm where the big key on top stands, so
there it comes out a little to the left of the big key (the S view shows it reaching to the machine's left).

SWEEP (8 frames): the brush rollers turn (S and the 3/4 views: each blade shows ChatGPT's new roller band, its stripes
scrolling up the front; E: the end-on bristles turn in place under the roller's painted end cap, which turns too); the machine shakes a little. N: the brushes are hidden behind
the machine; it shakes and a few painted scraps (from the concept) are tossed up over it into the hopper.

WIND and SWEEP stand on the same legs, planted, at the same body height (SWEEP's rumble: the legs take it).

Out (GAME SCALE, GS game px per sheet px; one cell and anchor for all three, the anchor = the ground under the body):
art/redraws/great_winder_walk.png (5 rows x 12; also great_winder_walk_4legs.gif and _6legs.gif on the same cell), great_winder_wind.png (5 x 12), great_winder_sweep.png (5 x 8), and a
GIF of each at 3x (5 directions side by side).
  python3 tools/great_winder_guide/anim.py            (python3 tools/great_winder_guide/anim.py parts DIR: the parts)"""
import math, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NAVY = np.array([0, 22, 48])
SHEET = np.array(Image.open('art/redraws/great_winder_dirs.png').convert('RGB')).astype(int)
CONCEPT = np.array(Image.open('art/redraws/concepts/great_winder_v1a.png').convert('RGB')).astype(int)
GS = 0.30             # game px per sheet px (the Netter is 0.238, the Pendulum 0.283: a big machine)
DIRS = ['s', 'se', 'e', 'ne', 'n']
MARGIN = (40, 60, 220, 130)   # render window round the unit's box: left, top, right, bottom (sheet px; the arm and its key reach)
# "forward" on screen per row (side view across, front/back views a little down/up)
FWD = [(0.0, 0.22), (0.72, 0.25), (1.0, 0.0), (0.72, -0.25), (0.0, -0.22)]

# per row (sheet px, column 1): the unit's box; legs: role, kind ('full': ball + collar + foot; 'ball': only the
# ball shows), ball (x, y, r), box, foot (the row where the brass dome starts; found when not given), sw (how far
# the steel collar reaches either side, in ball radii), mirror (a far leg half hidden behind a near one: its foot is
# completed with its own other side, mirrored); far: (role, copy of which leg, dx, dy) drawn darker behind the body
ROWS = [
    dict(box=(209, 67, 427, 284),
         legs=[dict(role='rf', kind='full', ball=(232, 214, 13), box=(206, 198, 259, 266), foot=240),
               dict(role='lf', kind='full', ball=(398, 214, 13), box=(380, 198, 430, 266), foot=240)],
         far=[('rm', 0, -16, -11), ('lm', 1, 16, -11)]),
    dict(box=(169, 335, 447, 574),
         legs=[dict(role='rb', kind='full', ball=(205, 478, 15), box=(166, 460, 230, 529), foot=501),
               dict(role='rm', kind='full', ball=(274, 507, 17), box=(232, 488, 298, 563), foot=531),
               dict(role='rf', kind='ball', ball=(318, 543, 9), box=(304, 528, 336, 561))],
         far=[('lb', 0, 26, -16), ('lm', 1, 26, -16)]),
    dict(box=(161, 632, 429, 841),
         legs=[dict(role='rb', kind='full', ball=(197, 773, 16), box=(158, 754, 228, 833), foot=801),
               dict(role='rm', kind='full', ball=(293, 783, 18), box=(256, 764, 324, 843), foot=814),
               dict(role='rf', kind='ball', ball=(360, 815, 10), box=(348, 803, 374, 831))],
         far=[('lb', 0, 16, -9), ('lm', 1, 16, -9)]),
    dict(box=(171, 899, 433, 1133),
         legs=[dict(role='rb', kind='full', ball=(206, 1057, 16), box=(168, 1038, 230, 1107), foot=1080),
               dict(role='rm', kind='full', ball=(298, 1080, 17), box=(258, 1060, 324, 1135), foot=1105),
               dict(role='rf', kind='ball', ball=(338, 1108, 8), box=(328, 1096, 350, 1123))],
         far=[('lb', 0, 24, -14), ('lm', 1, 24, -14)]),
    dict(box=(205, 1208, 417, 1439),
         legs=[dict(role='lb', kind='full', ball=(258, 1380, 17), box=(216, 1362, 282, 1443), sw=2.4),
               dict(role='rb', kind='full', ball=(380, 1381, 17), box=(350, 1362, 418, 1443), sw=2.4),
               dict(role='lm', kind='full', ball=(222, 1362, 12), box=(199, 1336, 240, 1433), mirror=True),
               dict(role='rm', kind='full', ball=(400, 1362, 10), box=(392, 1340, 426, 1416), mirror=True)],
         far=[]),
]


def fg(a):
    return np.abs(a - NAVY).sum(-1) > 45


def solid(a):
    """the painted figure: clear of the navy, plus the dark paint it encloses (the importer, tools/import_tier3.py,
    keeps enclosed pixels that are not the navy itself: they must not become holes here)"""
    m = fg(a)
    return m | (ndi.binary_fill_holes(m) & (np.abs(a - NAVY).sum(-1) >= 12))


def rgba(rgb, m):
    o = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    o[..., :3] = np.clip(rgb, 0, 255)
    o[..., 3] = m * 255
    return o


def place(img, p0, p1, M):
    """img (an RGBA array) drawn so that point p0 lands on p1 and the rest follows matrix M about it (NEAREST)"""
    Mi = np.linalg.inv(M)
    a, b = Mi[0]
    d, e = Mi[1]
    im = Image.fromarray(img, 'RGBA')
    return np.array(im.transform(im.size, Image.AFFINE,
                                 (a, b, p0[0] - a * p1[0] - b * p1[1], d, e, p0[1] - d * p1[0] - e * p1[1]),
                                 resample=Image.NEAREST))


def shift(img, dx, dy):
    return place(img, (0, 0), (dx, dy), np.eye(2))


def over(dst, src):
    m = src[..., 3] > 0
    dst[m] = src[m]
    return dst


def shade(img, k):
    o = img.copy()
    o[..., :3] = np.clip(o[..., :3].astype(float) * k, 0, 255).astype(np.uint8)
    return o


def window(R, src_box=None, off=(0, 0)):
    """the row's render window cut from the sheet (column 1, or column 2 moved by off): (rgb, mask, origin)"""
    bx0, by0, bx1, by1 = R['box']
    x0, y0, x1, y1 = bx0 - MARGIN[0], by0 - MARGIN[1], bx1 + MARGIN[2], by1 + MARGIN[3]
    W = np.full((y1 - y0, x1 - x0, 3), NAVY, int)
    sx0, sy0 = x0 + off[0], y0 + off[1]
    a0, b0 = max(0, sx0), max(0, sy0)
    a1, b1 = min(SHEET.shape[1], sx0 + (x1 - x0)), min(SHEET.shape[0], sy0 + (y1 - y0))
    W[b0 - sy0:b1 - sy0, a0 - sx0:a1 - sx0] = SHEET[b0:b1, a0:a1]
    M = solid(W)
    if src_box is not None:
        cx0, cy0, cx1, cy1 = src_box
        keep = np.zeros_like(M)
        keep[max(0, cy0 - sy0):cy1 - sy0, max(0, cx0 - sx0):cx1 - sx0] = True
        M &= keep
    return W, M, (x0, y0)


# ------------------------------------------------------------------ the legs

def foot_row(W, m, bx, by, r):
    """where the steel collar under the ball ends and the brass dome foot begins (a row of the leg's mask)"""
    R_, G_, B_ = W[..., 0], W[..., 1], W[..., 2]
    brass = m & (R_ > 120) & (G_ > 70) & (B_ < 100) & (R_ > B_ + 60)
    grey = m & (np.abs(R_ - B_) < 40) & ~brass
    for y in range(int(by + r + 2), m.shape[0]):
        xs = slice(int(bx - 1.3 * r), int(bx + 1.3 * r) + 1)
        nb, ng = int(brass[y, xs].sum()), int(grey[y, xs].sum())
        if nb >= 6 and nb > 1.3 * ng:
            return y
    return int(by + r)


def cut_legs(R, W, M, org):
    """the legs of a row (window coords): ball, shin (collar) and foot images, and the pixels they take"""
    x0, y0 = org
    H, Wd_ = M.shape
    yy, xx = np.mgrid[0:H, 0:Wd_]
    taken = np.zeros_like(M)
    legs = []
    for L in R['legs']:
        bx, by, br = L['ball'][0] - x0, L['ball'][1] - y0, L['ball'][2]
        b0, b1, b2, b3 = L['box']
        box = (xx >= b0 - x0) & (xx < b2 - x0) & (yy >= b1 - y0) & (yy < b3 - y0)
        ball = M & box & (np.hypot(xx - bx, yy - by) <= br + 1.5) & ~taken
        d = dict(role=L['role'], kind=L['kind'], b=(bx, by, br), ball=rgba(W, ball))
        part = ball.copy()
        if L['kind'] == 'full':
            fy = L['foot'] - y0 if 'foot' in L else foot_row(W, M & box & ~taken, bx, by, br)
            low = M & box & ~ball & ~taken & (yy >= by)
            shin = low & (yy < fy) & (yy >= by + 0.6 * br) & (np.abs(xx - bx) <= L.get('sw', 1.35) * br)
            foot = low & (yy >= fy)
            lab, n = ndi.label(foot)
            if n > 1:
                sz = ndi.sum(foot, lab, range(1, n + 1))
                foot &= lab == int(np.argmax(sz)) + 1
            Wl = W
            if L.get('mirror'):
                # a far leg's foot half hidden behind a near one: its hidden side is its own other side, mirrored
                fx = 2 * int(round(bx)) - xx
                ok = (fx >= 0) & (fx < Wd_)
                mir = np.zeros_like(foot)
                mir[ok] = foot[yy[ok], fx[ok]]
                add = mir & ~foot & box
                Wl = W.copy()
                Wl[add] = W[yy[add], fx[add]]
                foot = foot | add
            d.update(shin=rgba(W, shin), foot=rgba(Wl, foot), fy=fy, sole=float(np.nonzero(foot)[0].max()))
            part |= shin | foot
        legs.append(d)
        taken |= part
    return legs, taken


# ------------------------------------------------------------------ the winding arm (from column 2)

# per row, in column-2 sheet px: the arm's root (where it leaves the body) and tip (where the key's shaft meets its
# bow), its width, the key's bow box, how column 2 sits on column 1 (off: column 2 = column 1 + off; N: the root and
# tip on column 1 instead, see the docstring), and whether it is drawn in front of the body (S) or behind it
ARM = [
    dict(root=(683, 190), tip=(716, 276), width=26, bow=(690, 268, 751, 307), off=(356, 0), front=True),
    dict(root=(766, 414), tip=(890, 468), width=28, bow=(884, 452, 931, 506), off=(379, 0), front=False),
    dict(root=(752, 709), tip=(920, 726), width=30, bow=(916, 694, 956, 755), off=(384, 0), front=False),
    dict(root=(768, 984), tip=(879, 951), width=28, bow=(876, 918, 920, 978), off=(384, 0), front=False),
    dict(root=(688, 1290), tip=(688, 1213), width=24, bow=(663, 1183, 715, 1216), at=((302, 1264), (279, 1190)),
         front=False),
]


# ------------------------------------------------------------------ the painted key (WIND)

KEYS_SHEET = np.array(Image.open('art/redraws/great_winder_key_rollers_chatgpt.png').convert('RGB')).astype(int)
# ChatGPT's key sheet, top: the arm-tip key at four turns (columns: face-on, 45 deg, edge-on, back face; the five rows
# barely differ, row 1 is used). Only the key's head is taken: the bow and its neck down to the collar over the first
# blue ball (the arm has its own shaft and balls). Per column: the box (sheet px); the neck's bottom (the anchor) is
# found on its middle at row KEY_NECK
KEY_COLS = [(132, 26, 228, 93), (360, 26, 438, 93), (604, 26, 648, 93), (795, 26, 886, 93)]
KEY_NECK = 92          # the key's neck meets the collar here (sheet px)
KEY_BOW_W = 62.0       # the bow, face-on, this wide on the machine (sheet px; ChatGPT's is 83): ~19 game px, it reads
KEY_SINK = 4.0         # the key's neck starts this far back inside the arm's tip (sheet px)
KEY_TURN = 45.0        # deg a frame while it winds: 8 frames a turn
# the turn's 8 steps (0, 45 ... 315 deg) -> (column, mirrored about the shaft): face-on, 45, edge-on, 45 seen from the
# other side, the back face, then the same again (a bow is the same shape after half a turn)
KEY_STEPS = [(0, False), (1, False), (2, False), (1, True), (3, False), (1, False), (2, False), (1, True)]


def key_heads():
    out = []
    k = KEY_BOW_W / float(KEY_COLS[0][2] - KEY_COLS[0][0] - 13)
    for x0, y0, x1, y1 in KEY_COLS:
        C = KEYS_SHEET[y0:y1, x0:x1]
        m = solid(C)
        lab, n = ndi.label(m)
        if n > 1:
            sz = ndi.sum(m, lab, range(1, n + 1))
            m &= lab == int(np.argmax(sz)) + 1
        xs = np.nonzero(m[KEY_NECK - y0 - 6])[0]
        ax = (xs.min() + xs.max()) / 2.0
        im = Image.fromarray(rgba(C, m), 'RGBA')
        w, h = max(2, int(round(im.width * k))), max(2, int(round(im.height * k)))
        a = np.array(im.resize((w, h), Image.LANCZOS))
        a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
        a[a[..., 3] == 0] = 0
        out.append((a, np.array([ax * k, (KEY_NECK - y0) * k])))
    return out


KEY_HEADS = key_heads()


def key_step(i):
    """the key head at turn step i (of 8): (rgba, anchor = the neck's bottom middle); a mirrored step is re-lit with
    the painting's big light (the blurred brightness ratio), so its light still comes from the top left"""
    col, mir = KEY_STEPS[i % 8]
    a, anc = KEY_HEADS[col]
    if not mir:
        return a, anc
    b = a[:, ::-1].copy()
    m = b[..., 3] > 0
    lum = lambda x: (x[..., 0] * 0.3 + x[..., 1] * 0.59 + x[..., 2] * 0.11) * m
    sig = 4.0
    k = ndi.gaussian_filter(lum(a.astype(float)), sig) / np.maximum(ndi.gaussian_filter(lum(b.astype(float)), sig), 1.0)
    b[..., :3] = np.clip(b[..., :3] * np.clip(k, 0.7, 1.4)[..., None], 0, 255).astype(np.uint8)
    b[~m] = 0
    return b, np.array([a.shape[1] - 1 - anc[0], anc[1]])


def key_layer(size, tip, a, i):
    """the key head at step i laid at the arm's tip, its shaft along the arm (a: root -> tip on screen): turned in the
    picture plane (rotated paint, NEAREST) so the neck comes out of the tip and the bow stands beyond it"""
    Wd, H = size
    img, anc = key_step(i)
    ang = math.degrees(math.atan2(a[0], -a[1]))           # from 'up' (the paint's shaft) to a, clockwise on screen
    im = Image.fromarray(img, 'RGBA')
    pad = int(max(im.size)) + 4
    big = Image.new('RGBA', (2 * pad, 2 * pad), (0, 0, 0, 0))
    big.paste(im, (int(round(pad - anc[0])), int(round(pad - anc[1]))), im)
    big = big.rotate(-ang, resample=Image.NEAREST, center=(pad, pad))
    out = np.zeros((H, Wd, 4), np.uint8)
    _paste(out, np.array(big), int(round(tip[0] - pad)), int(round(tip[1] - pad)))
    return out


def seg_dist(xx, yy, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    t = np.clip(((xx - a[0]) * vx + (yy - a[1]) * vy) / float(vx * vx + vy * vy), 0, 1)
    return np.hypot(xx - (a[0] + t * vx), yy - (a[1] + t * vy))


def cut_arm(r, org, size):
    """the arm and its key's bow laid on the row's window: (arm rgba, bow rgba, root, tip) in window px"""
    A = ARM[r]
    x0, y0 = org
    Wd, H = size
    # column 2, in sheet px round the arm
    bx0 = min(A['root'][0], A['bow'][0]) - 30
    by0 = min(A['root'][1], A['bow'][1]) - 30
    bx1 = max(A['root'][0], A['bow'][2]) + 30
    by1 = max(A['root'][1], A['bow'][3]) + 30
    C = SHEET[by0:by1, bx0:bx1]
    CM = fg(C)
    yy, xx = np.mgrid[by0:by1, bx0:bx1]
    bow = CM & (xx >= A['bow'][0]) & (xx < A['bow'][2]) & (yy >= A['bow'][1]) & (yy < A['bow'][3])
    arm = CM & (seg_dist(xx, yy, A['root'], A['tip']) <= A['width'] / 2.0) & ~bow
    if 'off' in A:
        ox, oy = A['off']
        L = SHEET[by0 - oy:by1 - oy, bx0 - ox:bx1 - ox]
        LM = fg(L)
        if A['front']:
            arm &= np.abs(C - L).sum(2) > 90             # (in front of the body: where column 2 differs)
            arm = ndi.binary_closing(ndi.binary_opening(arm, iterations=1), iterations=1) & CM
        else:
            arm &= ~ndi.binary_dilation(LM, iterations=1)  # (behind it: only what stands clear of column 1's body)
        root_l = (A['root'][0] - ox, A['root'][1] - oy)
        tip_l = (A['tip'][0] - ox, A['tip'][1] - oy)
    else:
        arm &= yy < A['root'][1] + 2
        root_l, tip_l = A['at']
    lab, n = ndi.label(arm | bow)
    if n > 1:
        sz = ndi.sum(arm | bow, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s_ in enumerate(sz) if s_ >= 30])
        arm &= keep
        bow &= keep
    # the similarity that lays column 2's root -> tip on column 1's
    v0 = np.array(A['tip'], float) - A['root']
    v1 = np.array(tip_l, float) - root_l
    rot = math.atan2(v1[1], v1[0]) - math.atan2(v0[1], v0[0])
    sc = math.hypot(*v1) / math.hypot(*v0)
    M = sc * np.array([[math.cos(rot), -math.sin(rot)], [math.sin(rot), math.cos(rot)]])

    def lay(m):
        big = np.zeros((H, Wd, 4), np.uint8)
        im = rgba(C, m)
        # paste column 2's crop at its sheet place, then move it onto column 1
        tmp = np.zeros((H, Wd, 4), np.uint8)
        px, py = bx0 - x0 - (A['root'][0] - root_l[0]), by0 - y0 - (A['root'][1] - root_l[1])
        _paste(tmp, im, int(px), int(py))
        R0 = (root_l[0] - x0, root_l[1] - y0)
        big = place(tmp, R0, R0, M) if (abs(rot) > 1e-6 or abs(sc - 1) > 1e-6) else tmp
        return big
    return lay(arm), lay(bow), np.array(root_l, float) - (x0, y0), np.array(tip_l, float) - (x0, y0)


def _paste(dst, src, x, y):
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    w2, h2 = min(w - sx0, W - dx0), min(h - sy0, H - dy0)
    if w2 <= 0 or h2 <= 0:
        return
    s = src[sy0:sy0 + h2, sx0:sx0 + w2]
    m = s[..., 3] > 0
    d = dst[dy0:dy0 + h2, dx0:dx0 + w2]
    d[m] = s[m]


# ------------------------------------------------------------------ the brushes

# per row: the brush rollers' box (sheet px, column 1) and how they show: 'tread' (the roller's axis lies across the
# view: its front runs up the screen as it turns, S and the 3/4 views) or 'end' (seen end-on, E: a disc turning in
# place about its middle, hand-set: the circle through the bristles' outer edge); None: hidden (N)
BRUSH = [((278, 224, 368, 282), 'tread'), ((336, 486, 440, 568), 'tread'), ((393, 748, 433, 812), 'end', (393.3, 784.5)),
         ((358, 1040, 428, 1110), 'tread'), None]
BRUSH_ZOOM = 2.0       # the bristle stripes (5 sheet px apart, 1.5 game px: too fine to see move) shown 2x coarser
BRUSH_SPIN = 1.0       # the bristles we see go round by this many stripes over the 8 frames (end-on: 2 tufts)


def cut_brush(r, W, M, org):
    if BRUSH[r] is None:
        return None
    (b0, b1, b2, b3), kind = BRUSH[r][:2]
    x0, y0 = org
    H, Wd = M.shape
    yy, xx = np.mgrid[0:H, 0:Wd]
    R_, G_, B_ = W[..., 0], W[..., 1], W[..., 2]
    box = (xx >= b0 - x0) & (xx < b2 - x0) & (yy >= b1 - y0) & (yy < b3 - y0)
    bristle = box & (B_ > R_ + 25) & (B_ > 60)
    bristle = ndi.binary_closing(bristle, iterations=2) & box & (B_ > R_ + 5)
    lab, n = ndi.label(bristle)
    if n > 1:
        sz = ndi.sum(bristle, lab, range(1, n + 1))
        bristle &= np.isin(lab, [i + 1 for i, s_ in enumerate(sz) if s_ >= 40])
    lum = (0.3 * R_ + 0.59 * G_ + 0.11 * B_).astype(float)
    sig = 5.0
    light = ndi.gaussian_filter(lum * bristle, sig) / np.maximum(ndi.gaussian_filter(bristle.astype(float), sig), 1e-3)
    out = dict(kind=kind, mask=bristle, img=rgba(W, bristle), light=light, lum=lum)
    if kind == 'tread':
        # the stripes' period down the roller
        ys, xs = np.nonzero(bristle)
        best = (0, 5.0)
        for P in np.arange(3.0, 12.0, 0.5):
            sy = np.rint(ys + P).astype(int)
            ok = sy < H
            ok[ok] &= bristle[sy[ok], xs[ok]]
            if ok.sum() < 50:
                continue
            c = np.corrcoef(lum[ys[ok], xs[ok]], lum[sy[ok], xs[ok]])[0, 1]
            if c > best[0]:
                best = (c, float(P))
        out['period'] = best[1]
    else:
        # end-on: a disc turning about its middle
        cx, cy = BRUSH[r][2][0] - x0, BRUSH[r][2][1] - y0
        out.update(cx=cx, cy=cy)
        ys_, xs_ = np.nonzero(bristle)
        out['R'] = float(np.percentile(np.hypot(xs_ - cx, ys_ - cy), 95))
        # the tufts' angular period round the disc (at two thirds of the radius)
        ys, xs = np.nonzero(bristle)
        ang = np.degrees(np.arctan2(ys - cy, xs - cx))
        best = (0, 30.0)
        for P in np.arange(10.0, 50.0, 1.0):
            a = np.radians(ang + P)
            rr = np.hypot(xs - cx, ys - cy)
            sx = np.rint(cx + rr * np.cos(a)).astype(int)
            sy = np.rint(cy + rr * np.sin(a)).astype(int)
            ok = (sx >= 0) & (sx < Wd) & (sy >= 0) & (sy < H)
            ok[ok] &= bristle[sy[ok], sx[ok]]
            if ok.sum() < 50:
                continue
            c = np.corrcoef(lum[ys[ok], xs[ok]], lum[sy[ok], sx[ok]])[0, 1]
            if c > best[0]:
                best = (c, float(P))
        out['pitch'] = best[1]
    return out


# the new rollers (ChatGPT's key sheet, bottom: art/redraws/great_winder_key_rollers_chatgpt.png). TREAD_TEX: the side
# view's bristle band (row 1, column 1), the inside of its blue band (sheet px); each roller blade on the machine
# (a run of bristles: S and the 3/4 views) gets the band once across its width and scrolls it up its front. CAP: the
# end-on view (row 1, column 3): the roller's end cap, turned in place over the middle of E's end-on roller
TREAD_TEX = (154, 926, 177, 980)
TEX_ZOOM = 3.0         # the band 3x (ChatGPT's stripes are ~5.5 px apart, like the old ones: at 1x they blur to a flat blue)
TEX_P = 5.5            # its stripes' period down the band (measured: autocorrelation)
TEX_SPIN = 2.0         # stripes scrolled per 8-frame loop
CAP_BOX = (588, 909, 670, 1001)
CAP_K = 0.62           # the cap's radius, of the end-on roller's (the bristles stick out round it)
CAP_TURN = 90.0        # deg per loop (two of its eight lugs)


def roller_pieces():
    S_ = np.array(Image.open('art/redraws/great_winder_key_rollers_chatgpt.png').convert('RGB')).astype(int)
    x0, y0, x1, y1 = TREAD_TEX
    tex = S_[y0:y1, x0:x1].astype(float)
    x0, y0, x1, y1 = CAP_BOX
    C = S_[y0:y1, x0:x1]
    m = solid(C)
    r_, g_, b_ = C[..., 0], C[..., 1], C[..., 2]
    blue = m & (b_ > r_ + 40) & (b_ > 100)
    ys, xs = np.nonzero(blue)
    cx, cy = xs.mean(), ys.mean()
    yy, xx = np.mgrid[0:C.shape[0], 0:C.shape[1]]
    rr = np.hypot(xx - cx, yy - cy)
    # the cap's own radius: its lugs' tips (the stub over the top, a tuft, is left out)
    R = float(np.percentile(rr[m], 93))
    m &= rr <= R
    return tex, dict(img=rgba(C, m), c=(cx, cy), R=R, hub=blue)


TEX, CAP = roller_pieces()


def tread_texture(b, i, n):
    """the bristle runs (S, 3/4 views) painted with TEX: each blade (a connected run of bristles) gets the band once
    across its width; down a column the band's rows follow the run and scroll up by TEX_SPIN stripes a loop (wrapped
    a whole number of stripes, so it never jumps); re-lit with the painting's big light (the blade's old brightness
    over the band's mean)"""
    m = b['mask']
    H, Wd = m.shape
    out = np.zeros((H, Wd, 4), np.uint8)
    th, tw = TEX.shape[:2]
    Hw = math.floor((th - 1) / TEX_P) * TEX_P
    shift = TEX_SPIN * TEX_P * i / float(n)
    lab, nb = ndi.label(m)
    tmean = (TEX @ np.array([0.3, 0.59, 0.11])).mean()
    for k in range(1, nb + 1):
        ys, xs = np.nonzero(lab == k)
        if len(ys) < 20:
            continue
        x0, x1 = xs.min(), xs.max()
        for x in np.unique(xs):
            col = ys[xs == x]
            col.sort()
            for run in np.split(col, np.nonzero(np.diff(col) > 1)[0] + 1):
                L = run[-1] - run[0] + 1
                ty = ((run - run[0]) * (Hw / max(L, 1)) / TEX_ZOOM + shift) % Hw
                tx = (x - x0) / max(1.0, x1 - x0) * (tw - 1)
                rgb = np.stack([ndi.map_coordinates(TEX[..., c], [ty, np.full(len(ty), tx)], order=1)
                                for c in range(3)], -1)
                lk = np.clip(b['light'][run, x] / tmean, 0.5, 1.6)
                out[run, x, :3] = np.clip(rgb * lk[:, None], 0, 255).astype(np.uint8)
                out[run, x, 3] = 255
    return out


def cap_layer(b, i, n, size):
    """E: the roller's painted end cap turned in place (CAP_TURN a loop) over the middle of the end-on roller, its hub
    ball still; only where the roller shows (inside its bristles' outline)"""
    Wd, H = size
    R = CAP_K * b['R']
    k = R / CAP['R']
    img = Image.fromarray(CAP['img'], 'RGBA')
    big = img.resize((max(2, int(round(img.width * k))), max(2, int(round(img.height * k)))), Image.LANCZOS)
    c = (CAP['c'][0] * k, CAP['c'][1] * k)
    turned = big.rotate(-CAP_TURN * i / float(n), resample=Image.BICUBIC, center=c)
    a = np.array(turned)
    still = np.array(big)
    hub = np.hypot(*(np.mgrid[0:a.shape[0], 0:a.shape[1]][::-1] - np.array(c)[:, None, None])) <= 0.36 * R
    a[hub] = still[hub]
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    a[a[..., 3] == 0] = 0
    out = np.zeros((H, Wd, 4), np.uint8)
    _paste(out, a, int(round(b['cx'] - c[0])), int(round(b['cy'] - c[1])))
    out[~ndi.binary_dilation(b['mask'], iterations=2)] = 0
    return out


def roll_brush(b, i, n):
    """the bristles at frame i of n: a tread scrolls up (2x coarser stripes, one stripe per loop... BRUSH_SPIN), an
    end-on disc turns counterclockwise (its front, the right side, goes up: it scoops); re-lit with the painting's big
    light and shade; where the turn brings in bristles we cannot see, they come from one period further round"""
    m = b['mask']
    H, Wd = m.shape
    ys, xs = np.nonzero(m)
    out = np.zeros((H, Wd, 4), np.uint8)
    done = np.zeros(len(ys), bool)
    sy_f = np.zeros(len(ys), int)
    sx_f = np.zeros(len(ys), int)
    if b['kind'] == 'tread':
        P = b['period']
        Z = BRUSH_ZOOM
        shift = BRUSH_SPIN * P * Z * i / float(n)            # px on screen the stripes have gone up
        # each run of bristles down a column is a roller's front: magnify the stripes about its middle
        mid = np.zeros(len(ys))
        for x in np.unique(xs):
            col = np.nonzero(m[:, x])[0]
            for run in np.split(col, np.nonzero(np.diff(col) > 1)[0] + 1):
                c = (run[0] + run[-1]) / 2.0
                mid[(xs == x) & (ys >= run[0]) & (ys <= run[-1])] = c
        base = mid + (ys - mid + shift) / Z
        for k in (0, 1, -1, 2, -2, 3, -3):
            sy = np.rint(base + k * P).astype(int)
            ok = ~done & (sy >= 0) & (sy < H)
            ok[ok] &= m[sy[ok], xs[ok]]
            sy_f[ok], sx_f[ok] = sy[ok], xs[ok]
            done |= ok
    else:
        cx, cy, pitch = b['cx'], b['cy'], b['pitch']
        turn = 2.0 * BRUSH_SPIN * pitch * i / float(n)        # deg the disc has turned (counterclockwise)
        rr = np.hypot(xs - cx, ys - cy)
        ang = np.degrees(np.arctan2(ys - cy, xs - cx))
        for k in (0, 1, -1, 2, -2, 3, -3):
            a = np.radians(ang + turn + k * pitch)
            sx = np.rint(cx + rr * np.cos(a)).astype(int)
            sy = np.rint(cy + rr * np.sin(a)).astype(int)
            ok = ~done & (sx >= 0) & (sx < Wd) & (sy >= 0) & (sy < H)
            ok[ok] &= m[sy[ok], sx[ok]]
            sy_f[ok], sx_f[ok] = sy[ok], sx[ok]
            done |= ok
    sy_f[~done], sx_f[~done] = ys[~done], xs[~done]
    src = b['img'][sy_f, sx_f].astype(float)
    k_ = np.clip(b['light'][ys, xs] / np.maximum(b['light'][sy_f, sx_f], 1.0), 0.6, 1.6)
    src[:, :3] *= k_[:, None]
    out[ys, xs] = np.clip(src, 0, 255).astype(np.uint8)
    return out


# the scraps the sweep throws into the hopper: painted bits cut from the concept (art/redraws/concepts/
# great_winder_v1b.png: a cog and a brass-and-steel piece), and per row where they leave the brush and where the
# hopper's mouth is (sheet px, column 1; N: the brush is hidden: they come up from behind the machine)
SCRAPS = [((1219, 705, 1265, 738), 0.7), ((1273, 709, 1294, 726), 1.1)]     # (about twice their size in the concept: they must read)
THROW = [((322, 236), (282, 112)), ((392, 516), (236, 378)), ((410, 770), (226, 658)), ((392, 1066), (240, 956)),
         ((352, 1236), (296, 1270))]
THROW_H = 46.0         # how far above the higher end the scraps' arc peaks (sheet px)


def scrap_imgs():
    C = np.array(Image.open('art/redraws/concepts/great_winder_v1b.png').convert('RGB')).astype(int)
    bg = np.array([1, 25, 53])
    out = []
    for (x0, y0, x1, y1), k in SCRAPS:
        c = C[y0 - 2:y1 + 2, x0 - 2:x1 + 2]
        m = np.abs(c - bg).sum(2) > 70
        lab, n = ndi.label(m)
        sz = ndi.sum(m, lab, range(1, n + 1))
        m = ndi.binary_fill_holes(lab == int(np.argmax(sz)) + 1) & (np.abs(c - bg).sum(2) > 30)
        im = Image.fromarray(rgba(c, m), 'RGBA')
        im = im.resize((max(3, int(round(im.width * k))), max(3, int(round(im.height * k)))), Image.LANCZOS)
        a = np.array(im)
        a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
        out.append(a)
    return out


SCRAP = scrap_imgs()


def scraps_layer(r, i, n, size):
    """the scraps in the air at sweep frame i of n: two, half a loop apart, each flying for half the loop on an arc
    from the brush up into the hopper (N: from behind the machine down into it), turning as they go"""
    Wd, H = size
    x0, y0 = PARTS[r]['org']
    (sx, sy), (ex, ey) = THROW[r]
    sx, sy, ex, ey = sx - x0, sy - y0, ex - x0, ey - y0
    top = min(sy, ey) - THROW_H
    out = np.zeros((H, Wd, 4), np.uint8)
    for j, img in enumerate(SCRAP):
        t = ((i + j * n / 2.0) % n) / (n / 2.0)                # 0..1 in flight, 1..2 resting in the hopper
        if t <= 0.0 or t >= 1.0:
            continue
        # a parabola through the two ends with its peak at `top`
        x = sx + (ex - sx) * t
        a = sy + (ey - sy) * t
        lift = 4 * t * (1 - t) * (min(sy, ey) - top + abs(sy - ey) / 2.0)
        y = a - lift
        im = np.array(Image.fromarray(img, 'RGBA').rotate(-75.0 * (i + j * 3), resample=Image.NEAREST, expand=True))
        _paste(out, im, int(round(x - im.shape[1] / 2.0)), int(round(y - im.shape[0] / 2.0)))
    return out


# ------------------------------------------------------------------ a row's parts

def cut_row(r):
    R = ROWS[r]
    W, M, org = window(R)
    bx0, by0, bx1, by1 = R['box']
    x0, y0 = org
    unit = np.zeros_like(M)
    unit[by0 - y0 - 2:by1 - y0 + 2, bx0 - x0 - 2:bx1 - x0 + 2] = True
    M &= unit
    legs, taken = cut_legs(R, W, M, org)
    body = M & ~taken
    # fill where a leg leaves the body (the belly behind it), not the navy round it
    k = np.ones((11, 11))
    dens = ndi.convolve(body.astype(float), k, mode='constant') / k.sum()
    fill = taken & (dens > 0.55)
    _, (iy, ix) = ndi.distance_transform_edt(~body, return_indices=True)
    Wf = W.copy()
    Wf[fill] = W[iy[fill], ix[fill]]
    H, Wd = M.shape
    arm, bow, root, tip = cut_arm(r, org, (Wd, H))
    return dict(org=org, size=(Wd, H), body=rgba(Wf, body | fill), legs=legs, brush=cut_brush(r, W, M, org),
                arm=arm, bow=bow, root=root, tip=tip)


PARTS = [cut_row(_r) for _r in range(5)]


# ------------------------------------------------------------------ the new legs (ChatGPT's painted leg)

LEGS = 4               # 4: a slow, heavy walk, one leg at a time; 6: a tripod gait (the owner picks; 4 recommended)
LEG_SHEET = np.array(Image.open('art/redraws/great_winder_leg_chatgpt.png').convert('RGB')).astype(int)
# the leg sheet: rows = view (side, three-quarter, front), columns = one step (standing; foot lifted, leg back; foot
# swung forward in the air; foot down a little ahead). Which leg row each direction uses (S, SE, E, NE, N)
LEG_VIEW = [2, 1, 0, 1, 2]
LEG_K = 0.46           # leg sheet px -> body sheet px (the hip ball ~20 px across, the old balls 20-36: ~34 game px tall)
LEG_DARK = 0.72        # the far side's legs: the same paint behind the body, darker
STRIDE = 20.0          # a planted foot goes from +STRIDE to -STRIDE (body sheet px along the view's "forward")
N_WALK = 12
GAIT = {               # duty (the share of the loop a foot is down) and when each leg touches down
    4: dict(duty=0.75, off={'lb': 0.0, 'lf': 0.25, 'rb': 0.5, 'rf': 0.75}),
    6: dict(duty=0.5, off={'lf': 0.0, 'rm': 0.0, 'lb': 0.0, 'rf': 0.5, 'lm': 0.5, 'rb': 0.5}),
}
WALK_BOB = {4: [1, 0, 0] * 4, 6: [1, 0, 0, 0, 0, 0] * 2}   # the body dips a game px as a leg (a tripod) lands
SWEEP_BOB = [0, 1, 1, 0, 0, 1, 1, 0]       # it rumbles with the brushes (the legs stay planted: IK takes it)

# per direction, the hips (body sheet px, column 1) of each leg: (role, x, y, layer); layer 'near' (over the body),
# 'back' (a near-side leg drawn behind the body: the front legs in the side views stand behind the brush housing),
# 'far' (the far side, behind the body and darker). The far legs are the near ones moved by the row's FAR offset
# (up and along, into the picture). Which legs are used: LEG_SET[LEGS]
HIPS = [
    # S: the front legs at the corners; the middle and back legs behind them, outside
    dict(near=[('rf', 232, 214, 'near'), ('lf', 398, 214, 'near')],
         extra=[('rm', 215, 203, 'far'), ('lm', 415, 203, 'far'), ('rb', 224, 190, 'far'), ('lb', 406, 190, 'far')],
         far=None),
    # SE
    dict(near=[('rb', 205, 478, 'near'), ('rm', 274, 507, 'near'), ('rf', 316, 527, 'back')], far=(26, -16)),
    # E
    dict(near=[('rb', 197, 776, 'near'), ('rm', 293, 776, 'near'), ('rf', 356, 780, 'back')], far=(16, -9)),
    # NE
    dict(near=[('rb', 206, 1057, 'near'), ('rm', 298, 1080, 'near'), ('rf', 336, 1091, 'back')], far=(24, -14)),
    # N: the back legs near; the middle and front legs behind them, outside
    dict(near=[('lb', 258, 1380, 'near'), ('rb', 380, 1380, 'near')],
         extra=[('lm', 222, 1362, 'far'), ('rm', 400, 1362, 'far'), ('lf', 236, 1346, 'far'), ('rf', 394, 1346, 'far')],
         far=None),
]
LEG_SET = {4: ('lf', 'rf', 'lb', 'rb'), 6: ('lf', 'rf', 'lm', 'rm', 'lb', 'rb')}
# 4 legs in S / N: the far pair stands where 6 legs put the middle ones (the back legs of 6 are hidden further in)
FOUR_AT = {0: {'rb': 'rm', 'lb': 'lm'}, 4: {'lf': 'lm', 'rf': 'rm'}}


def _leg_cells():
    """the 12 painted cells: [row][col] = dict(rgba crop, o (its origin), hip (centre of the top ball), mask)"""
    m = solid(LEG_SHEET)
    lab, n = ndi.label(m)
    objs = ndi.find_objects(lab)
    cells = []
    for i, sl in enumerate(objs):
        if (lab[sl] == i + 1).sum() < 5000:
            continue
        y0, y1, x0, x1 = sl[0].start - 3, sl[0].stop + 3, sl[1].start - 3, sl[1].stop + 3
        cm = lab[y0:y1, x0:x1] == i + 1
        C = LEG_SHEET[y0:y1, x0:x1]
        R_, G_, B_ = C[..., 0], C[..., 1], C[..., 2]
        blue = ndi.binary_opening(cm & (B_ > R_ + 40) & (B_ > 90))
        bl, nb = ndi.label(blue)
        tops = sorted((ndi.find_objects(bl)[j][0].start, j + 1) for j in range(nb) if (bl == j + 1).sum() > 300)
        ys, xs = np.nonzero(bl == tops[0][1])
        hip = np.array([(xs.min() + xs.max()) / 2.0 + x0, (ys.min() + ys.max()) / 2.0 + y0])
        cells.append(dict(rgba=rgba(C, cm), o=np.array([x0, y0]), hip=hip, mask=cm, hip_r=(ys.max() - ys.min()) / 2.0,
                          cy=y0, cx=x0))
    cells.sort(key=lambda c: c['cy'])
    rows = [sorted(cells[k:k + 4], key=lambda c: c['cx']) for k in (0, 4, 8)]
    return rows


def _split_standing(c):
    """the standing cell cut in three: the hip ball, the rigid leg (hip collar, thigh, knee, ankle collar) and the
    flat brass foot; the ankle (where the leg meets the foot), the sole and the foot's middle"""
    m = c['mask']
    C = c['rgba'][..., :3].astype(int)
    H, Wd = m.shape
    yy, xx = np.mgrid[0:H, 0:Wd]
    hx, hy = c['hip'] - c['o']
    split = int(round(hy + c['hip_r'])) + 2            # under the ball: its collar starts
    R_, G_, B_ = C[..., 0], C[..., 1], C[..., 2]
    brass = m & (R_ > 120) & (G_ > 60) & (B_ < 110) & (R_ > B_ + 60)
    wid = brass.sum(1)
    sole = int(np.nonzero(m.any(1))[0].max())
    full = wid[sole - 30:sole].max()
    ank = sole - 30
    for y in range(int(hy + 2 * c['hip_r']), sole):
        if wid[y] >= 0.7 * full:
            ank = y
            break
    leg = m & (yy >= split) & (yy < ank)
    xs = np.nonzero(leg[ank - 1])[0]
    ankle = np.array([(xs.min() + xs.max()) / 2.0, ank]) + c['o']
    foot = m & (yy >= ank)
    fy, fx = np.nonzero(foot)
    return dict(ball=rgba(C, m & (yy < split)), leg=rgba(C, leg), foot=rgba(C, foot), ankle=ankle,
                sole=np.array([fx.mean(), sole]) + c['o'], footc=np.array([fx.mean(), fy.mean()]) + c['o'],
                o=c['o'], hip=c['hip'])


def _foot_centre(c):
    """a swing cell's foot middle: the paint furthest from the hip (its outer fifth)"""
    ys, xs = np.nonzero(c['mask'])
    p = np.stack([xs, ys], 1) + c['o']
    d = np.hypot(*(p - c['hip']).T)
    return p[d >= 0.8 * d.max()].mean(0)


LEG_CELLS = _leg_cells()
STAND = [_split_standing(r[0]) for r in LEG_CELLS]
for _r in LEG_CELLS:
    for _c in _r:
        _c['footc'] = _foot_centre(_c)


def xform(img, o, ps, th, pd, size, dark=None):
    """a leg-sheet piece (rgba, its origin o) turned th deg (clockwise on screen) about its point ps, scaled LEG_K and
    laid so ps lands on pd (window px): a full-window rgba (2x supersampled, premultiplied, alpha cut at half)"""
    Wd, H = size
    h, w = img.shape[:2]
    c, s = math.cos(math.radians(th)), math.sin(math.radians(th))
    K = LEG_K
    corners = np.array([[0, 0], [w, 0], [0, h], [w, h]], float) + o - ps
    dst = (np.array([[c, -s], [s, c]]) @ corners.T).T * K + pd
    tx0, ty0 = np.floor(dst.min(0)).astype(int) - 2
    tx1, ty1 = np.ceil(dst.max(0)).astype(int) + 2
    tw, tht = tx1 - tx0, ty1 - ty0
    a, b = c / (2 * K), s / (2 * K)
    cx = ps[0] - o[0] + (c * (tx0 - pd[0]) + s * (ty0 - pd[1])) / K
    cy = ps[1] - o[1] + (-s * (tx0 - pd[0]) + c * (ty0 - pd[1])) / K
    im = Image.fromarray(img, 'RGBA').convert('RGBa')
    t = im.transform((2 * tw, 2 * tht), Image.AFFINE, (a, b, cx, -b, a, cy), resample=Image.BILINEAR)
    t = t.resize((tw, tht), Image.BOX).convert('RGBA')
    t = np.array(t)
    t[..., 3] = np.where(t[..., 3] >= 128, 255, 0)
    t[t[..., 3] == 0] = 0
    if dark:
        t = shade(t, dark)
    out = np.zeros((H, Wd, 4), np.uint8)
    _paste(out, t, tx0, ty0)
    return out


def hips_of(r):
    """[(role, hip (window px), layer)] of the legs in use in direction r"""
    x0, y0 = PARTS[r]['org']
    Hd = HIPS[r]
    allh = {}
    for role, x, y, layer in Hd['near']:
        allh[role] = (np.array([x - x0, y - y0], float), layer)
        if Hd['far'] is not None:
            fr = 'l' + role[1]
            allh[fr] = (np.array([x - x0 + Hd['far'][0], y - y0 + Hd['far'][1]], float), 'far')
    for role, x, y, layer in Hd.get('extra', []):
        allh[role] = (np.array([x - x0, y - y0], float), layer)
    out = []
    for role in LEG_SET[LEGS]:
        src = FOUR_AT.get(r, {}).get(role, role) if LEGS == 4 else role
        out.append((role,) + allh[src])
    return out


def fwd_of(r):
    return np.array(FWD[r], float)


def stance_geom(r, hip, x_off, rest_len, bob=0.0):
    """a planted leg's pose: (ankle, turn of the rigid leg, its slide up the hip) for its foot flat on the ground at
    x_off along forward from under the rest hip (hip: the rest hip; bob: how far the body has dipped)"""
    st = STAND[LEG_VIEW[r]]
    f = fwd_of(r)
    ank0 = (st['ankle'] - st['hip']) * LEG_K                 # the rest leg, hip -> ankle
    sole0 = (st['sole'] - st['ankle']) * LEG_K
    sole = np.array([hip[0] + ank0[0] + sole0[0], hip[1] + rest_len]) + x_off * f
    ankle = sole - sole0
    hp = hip + np.array([0.0, bob])
    dx = ankle[0] - hp[0]
    L = math.hypot(*ank0)
    th = 0.0
    if abs(f[0]) > 1e-6:
        th = math.degrees(math.atan2(ank0[0], ank0[1])) - math.degrees(math.asin(max(-1.0, min(1.0, dx / L))))
    c, s = math.cos(math.radians(th)), math.sin(math.radians(th))
    rot = np.array([[c, -s], [s, c]]) @ ank0
    return ankle, th, (ankle - (hp + rot))[1]


def stance_leg(r, hip, x_off, size, dark, rest_len, bob=0.0):
    """a planted leg: its foot flat on the ground, the rigid leg (hip collar, thigh, knee, ankle collar) turned about
    the hip to reach it (in the front views not turned: there the step is depth, foreshortened) and slid up under the
    hip ball for the rest (never down: REST_LEN is chosen so it never has to); the standing cell's hip ball on top"""
    st = STAND[LEG_VIEW[r]]
    ankle, th, slide = stance_geom(r, hip, x_off, rest_len, bob)
    hp = hip + np.array([0.0, bob])
    return [xform(st['foot'], st['o'], st['ankle'], 0.0, ankle, size, dark),
            xform(st['leg'], st['o'], st['hip'], th, hp + np.array([0.0, slide]), size, dark),
            xform(st['ball'], st['o'], st['hip'], 0.0, hp, size, dark)]


SWING_LIFT = 7.0       # a stepping foot clears the ground by at least this (body sheet px; the painted lift is small)


def swing_leg(r, hip, u, size, dark, ground=None):
    """a stepping leg at u (0 lift-off .. 1 touch-down): the painted step poses (column 2 early, column 3 late) turned
    about the hip so the foot follows a smooth path from behind to ahead (the front views: so it stays under the
    hip), never through the floor, the standing cell's hip ball laid over its own"""
    cells = LEG_CELLS[LEG_VIEW[r]]
    st = STAND[LEG_VIEW[r]]
    c = cells[1] if u < 0.45 else cells[2]
    f = fwd_of(r)
    fn = f / max(1e-6, np.hypot(*f))
    x_off = -STRIDE + 2 * STRIDE * (1 - math.cos(math.pi * u)) / 2.0
    if abs(f[0]) < 1e-6:
        # front views: the step is depth; ChatGPT's lifted feet lean to one side, so the pose is turned back until
        # the foot is under the hip again
        fn, want = np.array([1.0, 0.0]), ((st['footc'] - st['hip']) * LEG_K)[0]
    else:
        want = ((st['footc'] - st['hip']) * LEG_K) @ fn + x_off * np.hypot(*f)
    v = (c['footc'] - c['hip']) * LEG_K
    best = None
    for t in np.arange(-70.0, 70.1, 0.5):
        cc, ss = math.cos(math.radians(t)), math.sin(math.radians(t))
        e = abs((np.array([[cc, -ss], [ss, cc]]) @ v) @ fn - want)
        if best is None or e < best[0]:
            best = (e, t)
    th = best[1]
    leg = xform(c['rgba'], c['o'], c['hip'], th, hip, size, dark)
    if ground is not None:
        # never through the floor: the whole pose slides up under the hip ball until the foot clears it
        ys = np.nonzero(leg[..., 3].any(1))[0]
        g = ground + x_off * f[1] - (2.0 + SWING_LIFT * math.sin(math.pi * u))
        up = int(math.ceil(ys.max() - g)) if len(ys) else 0
        if up > 0:
            leg = shift(leg, 0, -up)
    return [leg, xform(st['ball'], st['o'], st['hip'], 0.0, hip, size, dark)]


def legs_layers(r, t, bob=0.0, stand=False):
    """{'far': [...], 'back': [...], 'near': [...]} full-window rgba layers of the legs at walk time t (0..1 a loop;
    stand: every foot planted under its hip), the hips dipped by bob (window px)"""
    P = PARTS[r]
    g = GAIT[LEGS]
    out = {'far': [], 'back': [], 'near': []}
    hl = sorted(hips_of(r), key=lambda h: h[1][1])
    for role, hip, layer in hl:
        dark = LEG_DARK if layer == 'far' else None
        if stand:
            lay = stance_leg(r, hip, 0.0, P['size'], dark, REST_LEN, bob)
        else:
            p = (t - g['off'][role] + 0.5 / N_WALK) % 1.0
            if p < g['duty']:
                x_off = STRIDE - 2 * STRIDE * p / g['duty']
                lay = stance_leg(r, hip, x_off, P['size'], dark, REST_LEN, bob)
            else:
                lay = swing_leg(r, hip + np.array([0.0, bob]), (p - g['duty']) / (1 - g['duty']), P['size'], dark,
                                hip[1] + REST_LEN)
        out[layer] += lay
    return out


def rest_len():
    """the hip-to-sole height at rest: as long as the painted leg allows with no gap at the hip in any planted pose
    (the leg only ever slides up under the ball)"""
    best = 1e9
    for r in range(5):
        st = STAND[LEG_VIEW[r]]
        ank0 = (st['ankle'] - st['hip']) * LEG_K
        sole0 = (st['sole'] - st['ankle']) * LEG_K
        base = ank0[1] + sole0[1]
        for x_off in np.linspace(-STRIDE, STRIDE, 21):
            sl = stance_geom(r, np.array([200.0, 100.0]), x_off, base)[2]
            best = min(best, base - sl)
    return best


def body_layer(img, bob):
    return shift(img, 0, bob) if bob else img


def bob_px(b):
    return int(round(b / GS))


def walk_frame(r, i):
    bob = bob_px(WALK_BOB[LEGS][i])
    L = legs_layers(r, i / float(N_WALK), bob)
    return [(x, False) for x in L['far'] + L['back']] + [(body_layer(PARTS[r]['body'], bob), False)] + \
        [(x, False) for x in L['near']]


def wind_frame(r, t, step):
    L = legs_layers(r, 0.0, stand=True)
    arm = arm_layers(r, t, step)
    g = [(x, False) for x in L['far'] + L['back']]
    if ARM[r]['front']:
        return g + [(PARTS[r]['body'], False)] + [(x, False) for x in L['near']] + [(arm, False)]
    return g + [(arm, False), (PARTS[r]['body'], False)] + [(x, False) for x in L['near']]


def sweep_frame(r, i):
    bob = bob_px(SWEEP_BOB[i])
    L = legs_layers(r, 0.0, bob, stand=True)
    g = [(x, False) for x in L['far'] + L['back']] + [(body_layer(PARTS[r]['body'], bob), False)]
    b = PARTS[r]['brush']
    if b is not None:
        if b['kind'] == 'tread':
            g.append((body_layer(tread_texture(b, i, N_SWEEP), bob), False))
        else:
            # (E: the bristles round it turn at their painted size, BRUSH_ZOOM is for the old treads only)
            g.append((body_layer(roll_brush(b, i, N_SWEEP), bob), False))
            g.append((body_layer(cap_layer(b, i, N_SWEEP, PARTS[r]['size']), bob), False))
    return g + [(x, False) for x in L['near']] + [(scraps_layer(r, i, N_SWEEP, PARTS[r]['size']), False)]


REST_LEN = rest_len()


# ------------------------------------------------------------------ the frames

def arm_layers(r, t, step):
    """the arm out by t (0 in, 1 all out), with ChatGPT's painted key at its tip at turn step `step` (of 8)"""
    P = PARTS[r]
    root, tip = P['root'], P['tip']
    L = float(np.hypot(*(tip - root)))
    a = (tip - root) / L
    back = -(1.0 - t) * (L + 30.0) * a
    H, Wd = P['arm'].shape[:2]
    yy, xx = np.mgrid[0:H, 0:Wd]
    out = shift(P['arm'], *back)
    over(out, key_layer((Wd, H), tip + back - KEY_SINK * a, a, step))
    # hidden inside the machine: anything behind the root along the arm
    inside = ((xx - root[0]) * a[0] + (yy - root[1]) * a[1]) < 0
    out[inside] = 0
    return out


N_SWEEP = 8
# WIND: (how far out, the key's turn step): out in 2 frames, a full turn in 8 (frames 2-9 loop while it winds), back
# in 2
WIND = [(0.0, 0), (0.55, 0), (1.0, 0), (1.0, 1), (1.0, 2), (1.0, 3), (1.0, 4), (1.0, 5), (1.0, 6), (1.0, 7),
        (0.6, 0), (0.2, 0)]


def cropped(groups):
    """merge runs of layers that ride alike, cut to their boxes: [(rgba, x, y, rides)]"""
    merged = []
    for img, rides in groups:
        if merged and merged[-1][1] == rides:
            over(merged[-1][0], img)
        else:
            merged.append((img.copy(), rides))
    out = []
    for img, rides in merged:
        ys, xs = np.nonzero(img[..., 3])
        if len(ys):
            out.append((img[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy(), xs.min(), ys.min(), rides))
    return out


def anim_frames(name, r):
    if name == 'walk':
        return [(cropped(walk_frame(r, i)), 0) for i in range(N_WALK)]
    if name == 'wind':
        return [(cropped(wind_frame(r, t, ph)), 0) for t, ph in WIND]
    return [(cropped(sweep_frame(r, i)), 0) for i in range(N_SWEEP)]


def anchor(r):
    """the unit's point (window px): under the middle of its near-side hips (all of HIPS[r]['near'], so it does not
    move with LEGS), on the ground (the lowest rest sole)"""
    x0, y0 = PARTS[r]['org']
    near = HIPS[r]['near']
    return (float(np.mean([h[1] for h in near])) - x0, max(h[2] for h in near) - y0 + REST_LEN + 1.0)


def shrink(img, w, h):
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s_ = np.array(Image.fromarray(pre).resize((w, h), Image.BOX)).astype(np.float32)
    al = s_[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s_[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.45, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def to_cell(r, groups, bob, cell):
    CW, CH, AX, AY = cell
    ax, ay = anchor(r)
    ox, oy = int(round(ax - AX / GS)), int(round(ay - AY / GS))
    w, h = int(round(CW / GS)), int(round(CH / GS))
    out = np.zeros((CH, CW, 4), np.uint8)
    for img, gx, gy, rides in groups:
        crop = np.zeros((h, w, 4), np.uint8)
        _paste(crop, img, gx - ox, gy - oy)
        sm = shrink(crop, CW, CH)
        if rides and bob:
            sm = np.roll(sm, bob, axis=0)
            if bob > 0:
                sm[:bob] = 0
            else:
                sm[bob:] = 0
        over(out, sm)
    return out


def extents(frames):
    L = Rr = U = D = 0.0
    for (name, r), fr in frames.items():
        ax, ay = anchor(r)
        for groups, bob in fr:
            for img, gx, gy, rides in groups:
                h, w = img.shape[:2]
                L, Rr = max(L, ax - gx), max(Rr, gx + w - ax)
                U, D = max(U, ay - gy), max(D, gy + h - ay + (bob / GS if rides else 0))
    return L, Rr, U, D


def save(name, rows, cell, dur, png=True):
    CW, CH = cell[:2]
    n = len(rows[0])
    sheet = Image.new('RGB', (n * CW, 5 * CH), tuple(NAVY))
    for r in range(5):
        for c, img in enumerate(rows[r]):
            im = Image.fromarray(img, 'RGBA')
            sheet.paste(im, (c * CW, r * CH), im)
    if png:
        sheet.save('art/redraws/great_winder_%s.png' % name)
    g = []
    for c in range(n):
        o = Image.new('RGB', (5 * CW, CH), tuple(NAVY))
        for r in range(5):
            o.paste(sheet.crop((c * CW, r * CH, (c + 1) * CW, (r + 1) * CH)), (r * CW, 0))
        g.append(o.resize((o.width * 3, o.height * 3), Image.NEAREST))
    g[0].save('art/redraws/great_winder_%s.gif' % name, save_all=True, append_images=g[1:], duration=dur, loop=0)


WALK_MS = {4: 130, 6: 110}     # a heavy creep; the tripod a little quicker


def main():
    """the three strips with LEGS legs on one cell; and both walks as GIFs (great_winder_walk_4legs / _6legs.gif) on
    that cell, so the owner can pick"""
    global LEGS
    frames = {(name, r): anim_frames(name, r) for name in ('walk', 'wind', 'sweep') for r in range(5)}
    other = 6 if LEGS == 4 else 4
    keep = LEGS
    LEGS = other
    walk2 = {('walk', r): anim_frames('walk', r) for r in range(5)}
    LEGS = keep
    both = dict(frames)
    both.update({('walk2', r): v for (_, r), v in walk2.items()})
    L, Rr, U, D = extents(both)
    half = int(math.ceil(max(L, Rr) * GS)) + 1
    up, down = int(math.ceil(U * GS)) + 1, int(math.ceil(D * GS)) + 1
    cell = (2 * half, up + down, half, up)
    print('cell %dx%d, anchor (%d, %d) (game px, GS %.3f), %d legs' % (cell + (GS, LEGS)))
    for name, dur in (('walk', WALK_MS[LEGS]), ('wind', 110), ('sweep', 100)):
        rows = [[to_cell(r, g, bob, cell) for g, bob in frames[(name, r)]] for r in range(5)]
        save(name, rows, cell, dur)
        if name == 'walk':
            save('walk_%dlegs' % LEGS, rows, cell, dur, png=False)
    LEGS = other
    rows = [[to_cell(r, g, bob, cell) for g, bob in walk2[('walk', r)]] for r in range(5)]
    save('walk_%dlegs' % other, rows, cell, WALK_MS[other], png=False)
    LEGS = keep
    print('ok')


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'parts':
        out = sys.argv[2]
        os.makedirs(out, exist_ok=True)
        for r in range(5):
            P = PARTS[r]
            tiles = [P['body'], P['arm'], P['bow']] + [d['ball'] for d in P['legs']]
            tiles += [d[k] for d in P['legs'] if d['kind'] == 'full' for k in ('shin', 'foot')]
            if P['brush'] is not None:
                tiles.append(P['brush']['img'])
                print(DIRS[r], 'brush', P['brush']['kind'], P['brush'].get('period'), P['brush'].get('pitch'))
            ims = []
            for t in tiles:
                im = Image.fromarray(t, 'RGBA')
                bb = im.getbbox() or (0, 0, 4, 4)
                im = im.crop(bb)
                ims.append(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
            Wt = sum(i.width for i in ims) + 10 * len(ims)
            Ht = max(i.height for i in ims)
            sheet = Image.new('RGB', (Wt, Ht), (40, 70, 40))
            x = 0
            for im in ims:
                sheet.paste(im, (x, 0), im)
                x += im.width + 10
            sheet.save('%s/parts_%s.png' % (out, DIRS[r]))
    else:
        main()
