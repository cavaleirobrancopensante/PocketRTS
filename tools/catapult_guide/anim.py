"""Spring Catapult THROW and MOVE in code from ChatGPT's direction sheet (art/redraws/catapult_dirs.png: rows S, SE, E,
NE, N; column 1 the whole unit, column 2 the arm alone). The sheet already shows the LOADED pose: the arm lies back
(the cup over the rear, by the crank), as the owner wanted (ChatGPT's first concept had it forward in both poses).

Cut-out parts per row (sheet px, hand-set in ROWS):
- the ARM: the cup (anchored at J, where the beam meets it) and the beam from J to the hinge H over the spring drum.
  The beam is the body's own paint where it shows; in E and NE the part hidden behind the drum's gear rim is the
  visible beam copied along its length (a whole number of px, no resampling). The hinge ball / knuckle stays on the
  body. Side and 3/4 views: the arm sits in the middle of the machine, BEHIND the drum's near rim (drawn under the
  body); S: in front (as painted); N: in front while it leans back towards us, behind once it passes the top.
- the WHEELS: cut out of the body and replaced by ChatGPT's painted cog (art/redraws/catapult_wheel_chatgpt.png),
  rebuilt with even teeth and bolts and turned in code by cog.py (face-on squashed into each wheel's fitted ellipse;
  S and N: the edge-on paint, its tread rolling down / up; S's painted face-on wheels are erased: REWHEEL; SE: squashed
  to SQUASH_34). Far wheels turn behind the body (their rim and teeth come off it; OCC
  keeps what stands in front of them); behind a near wheel's tooth gaps the body's paint is reflected inward, shaded.
- S/N ARM POSES: away from the loaded pose the arm is ChatGPT's own painted arm (art/redraws/catapult_arm_poses_
  chatgpt.png: straight up, and tipped toward the viewer for the S follow-through; N and NE's cup in EVERY frame:
  the cup seen from below, its back to us, the loaded soldier peeking over its far rim), its beam tiled.
- the BODY: the rest, with the holes the arm and wheels leave filled from the neighbouring paint (S and N: the drum
  behind the upright beam is filled row by row between its two sides).
- the PAYLOAD: ChatGPT's curled-up Clock Soldier from the concept (art/redraws/concepts/catapult_v1.png, the flying
  one, speed lines removed), shrunk to sit in the cup; the cup's front wall is drawn over it.

The arm in 3D: angle T (deg) from the machine's forward horizontal (0 = pointing forward, 90 = up, 180 = back); the
joint is at H + L (cos T F + sin T U) on screen, U = straight up, F = the row's forward axis on screen (E: across;
SE/NE: fitted to the painted arm; S/N: towards/away from us, i.e. down/up the screen by DEPTH). The painted arm is the
loaded pose T0 (N: ChatGPT drew it nearer upright, about 130 deg, so the loaded N pose is built: the cup comes down
in front of the machine's back). The beam is mapped from its painted vector onto the new one (turned and stretched
along its length, its width kept): foreshortening in the front/back views, a turn in the picture plane in the side
view. The cup turns with the beam on screen (side and 3/4 views; S/N it only moves).

THROW (12 frames): loaded and held (a Clock Soldier curled in the cup), a slight extra pull, the fast release over the
top, the soldier leaving the cup ahead of it, the follow-through and a bounce off the stop, the slow wind back, and
the next soldier dropping into the cup. MOVE (8 frames): the wheels turn a quarter turn (their four bolts come round
again), the body rides 1 game px up and down twice over them, the arm loaded and the cup empty.

Out (GAME SCALE, GS game px per sheet px; one cell size and anchor for both, the anchor = the ground under the axles):
art/redraws/catapult_throw.png (5 rows x 12), catapult_move.png (5 x 8), and a GIF of each at 3x (5 directions side
by side). Also art/redraws/catapult_payload.png (the curled soldier, sheet scale) and catapult_cup.json (the cup's
middle per THROW frame and row, in cell px from the cell's top-left, and the release frame) for the game's projectile.
  python3 tools/catapult_guide/anim.py            (python3 tools/catapult_guide/anim.py parts DIR [-v]: the cut parts)"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cog
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NAVY = np.array([0, 22, 48])
SHEET = np.array(Image.open('art/redraws/catapult_dirs.png').convert('RGB')).astype(int)
CONCEPT = np.array(Image.open('art/redraws/concepts/catapult_v1.png').convert('RGB')).astype(int)
GS = 0.357            # game px per sheet px: 1.5x the Netter's 0.238 (the owner: about 1.5x the Netter; it was 0.26)
DIRS = ['s', 'se', 'e', 'ne', 'n']
T0 = 168.6            # the loaded pose (deg), from the side view's painted arm
ARM_L = 116.3         # the arm's true length, hinge to cup joint (sheet px), from the side view
DEPTH = 0.36          # S/N: screen px down (S) or up (N) per px towards/away from us, from the S view's painted arm
DEPTH_AWAY = 0.53     # N follow-through only (see arm_vec)
MARGIN = (70, 175, 70, 14)   # render window around the unit's box: left, top, right, bottom (sheet px)
SQUASH_34 = 0.72     # SE: the near wheels' faces are turned ~45 deg from us: their ellipse is this wide (of its height)
N_BACK_T = 100.0     # N / NE (seen from behind): the cup always shows its back; above this angle it stays tipped as here

# per row (sheet px): the unit's box; H the hinge, J the cup joint (where the beam meets the cup); bw the beam's
# width; clean: the stretch (from J) where the beam shows whole; past it (behind the drum's rim) the beam is that
# stretch repeated (None: it shows whole all the way); cup: the cup's box;
# rim: the cup's rim ellipse (cx, cy, rx, ry); hub: the hinge's knuckle box drawn on top of the arm (S, N);
# F: the forward axis on screen; tpaint: the painted arm's angle; arm: 'behind' / 'front' / 'n' (see the docstring);
# wheels: (cx, cy, rx, ry, kind, turn): 'near' turns whole, 'far' only its visible tooth ring, 'edge' (seen edge-on)
# scrolls its tooth bars; turn: +1 clockwise on screen while rolling forward, -1 the other way (S: the right-hand
# wheel shows its other face); edge-on wheels are listed nearest first
ROWS = [
    dict(box=(184, 59, 446, 298), H=(325, 186), J=(326, 122), bw=30, clean=None, cup=(292, 55, 369, 135),
         rim=(330.5, 70.5, 33, 9), hub=(306, 176, 345, 209), F=(0.0, DEPTH), tpaint=T0, arm='front',
         # (S, facing us: the wheels are seen EDGE-ON, laid out like the N view's: the front pair (near) at the sides,
         # the rear pair (far) at the body's ends, higher, behind it; ChatGPT painted them face-on: see REWHEEL)
         wheels=[(227, 256, 17, 47, 'edge'), (423, 256, 17, 47, 'edge'), (251, 228, 16, 46, 'edge'),
                 (399, 228, 16, 46, 'edge')],
         anchor=(323.0, 303.0), roll=1, tones=(1.03, 1.03, 0.85, 0.85)),
    dict(box=(169, 354, 476, 587), H=(349, 425), J=(297, 392), bw=28, clean=None, cup=(226, 352, 300, 409),
         rim=(263, 366, 33, 10), hub=None, F=None, tpaint=T0, arm='behind',
         wheels=[(220, 505, 44, 44, 'near'), (371, 547, 40, 40, 'near'), (440, 486, 46, 46, 'far')], squash=SQUASH_34,
         occ=[(330, 425), (385, 425), (400, 440), (420, 444), (438, 446), (447, 455), (449, 470), (444, 484), (442, 500), (436, 512),
              (425, 522), (412, 530), (385, 545), (330, 545)]),
    dict(box=(139, 656, 493, 856), H=(351, 706), J=(237, 683), bw=28, clean=(5, 27), cup=(162, 655, 240, 708),
         rim=(201, 671, 33, 9), hub=None, F=(1.0, 0.0), tpaint=T0, arm='behind',
         wheels=[(233, 797, 47, 47, 'near'), (429, 810, 44, 44, 'near'), (448, 772, 47, 47, 'far')],
         occ=[(340, 715), (395, 715), (410, 722), (430, 725), (445, 733), (450, 745), (446, 758), (440, 765), (395, 770), (340, 770)]),
    dict(box=(179, 927, 495, 1150), H=(360, 980), J=(276, 960), bw=29, clean=(4, 27), cup=(200, 926, 279, 981),
         rim=(238, 942, 33, 10), hub=None, F=None, tpaint=T0, arm='behind',
         wheels=[(221, 1055, 45, 45, 'near'), (348, 1103, 45, 45, 'near'), (442, 1076, 44, 44, 'far')],
         occ=[(340, 1020), (395, 1020), (430, 1022), (462, 1028), (462, 1048), (450, 1056), (440, 1062), (440, 1095), (420, 1110),
              (395, 1120), (340, 1120)], back_t=N_BACK_T),
    dict(box=(207, 1200, 465, 1452), H=(323, 1320), J=(322, 1257), bw=30, clean=None, cup=(284, 1196, 362, 1268),
         rim=(322.5, 1211, 35, 10), hub=(302, 1305, 345, 1363), F=(0.0, -DEPTH), tpaint=130.0, arm='n',
         wheels=[(249, 1407, 16, 46, 'edge'), (397, 1407, 17, 46, 'edge'), (228, 1378, 18, 48, 'edge'),
                 (425, 1380, 17, 48, 'edge')], roll=-1, back_t=N_BACK_T),
]

# S: ChatGPT painted the wheels face-on (as if turned 90 deg). REWHEEL erases them (and the rear wheels' face-on teeth
# peeking out behind them) off the body: old: their ellipses (sheet px); peeks: boxes of the rear teeth; block: the
# body's riveted base, whose ends the wheels covered: filled from its own plate further in (CODE EDIT)
REWHEEL = dict(old=[(233, 256, 38, 55), (413, 256, 39, 55)], peeks=[(196, 186, 252, 228), (382, 160, 448, 228)],
               block=(247, 196, 401, 271), mid=325, shift=7)


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


def rotm(deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return np.array([[c, -s], [s, c]])


def stretch_to(v0, v1):
    """turn v0 onto v1 and stretch along it, keeping the width"""
    rot = math.atan2(v1[1], v1[0]) - math.atan2(v0[1], v0[0])
    n0 = math.hypot(*v0)
    u = np.array(v0) / n0
    c, s = math.cos(rot), math.sin(rot)
    return np.array([[c, -s], [s, c]]) @ (np.eye(2) + (math.hypot(*v1) / n0 - 1) * np.outer(u, u))


def over(dst, src):
    """alpha-composite src over dst (both RGBA uint8 arrays, hard alpha)"""
    m = src[..., 3] > 0
    dst[m] = src[m]
    return dst


def fill_nearest(rgb, known, todo):
    """todo pixels take the colour of the nearest known pixel"""
    _, (iy, ix) = ndi.distance_transform_edt(~known, return_indices=True)
    out = rgb.copy()
    out[todo] = rgb[iy[todo], ix[todo]]
    return out


# ------------------------------------------------------------------ the payload (the curled-up Clock Soldier)

def payload_img():
    S = CONCEPT[195:318, 950:1092]
    m = fg(S)
    r, g, b = S[..., 0], S[..., 1], S[..., 2]
    m &= ~((b > r + 30) & (b > 120) & (r < 160) & (g > 100))      # the speed lines
    lab, n = ndi.label(m)
    sz = ndi.sum(m, lab, range(1, n + 1))
    m &= lab == int(np.argmax(sz)) + 1
    m = ndi.binary_fill_holes(m)
    ys, xs = np.nonzero(m)
    S = recolour_payload(S, m)
    im = Image.fromarray(rgba(S, m)[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')
    return im


KEY_LIT, KEY_SHADE = (255, 0, 0), (150, 0, 0)    # the team-colour key the game's shader turns into the player's colour


def recolour_payload(S, m):
    """the curled soldier coloured like the new Clock Soldier (CODE COLOUR): all brass except its head in the team
    key. The red case (the round head with the clock face, the part that reads as the head in the curl) becomes the
    key in two tones (KEY_LIT where it is lit, KEY_SHADE in its shade, split at the red's median brightness); the blue
    joints and the gunmetal become brass: each takes the painting's own brass at its brightness (a ramp sampled from the
    soldier's brass pixels); the clock face and the dark outline stay"""
    S = S.astype(float).copy()
    r, g, b = S[..., 0], S[..., 1], S[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    red = m & (r > 90) & (g < 0.42 * r) & (b < 0.42 * r) & (np.abs(g - b) < 32)     # (brass's dark orange has g >> b)
    blue = m & (b > r + 30) & (b > 70)
    grey = m & (np.abs(r - g) < 28) & (np.abs(g - b) < 28) & (lum > 45) & (lum < 175) & ~red & ~blue
    brass = m & (r > 120) & (g > 70) & (b < 110) & (r > b + 60) & ~red
    # the brass ramp: the median brass colour per brightness band
    ramp = np.zeros((256, 3))
    bl = lum[brass]
    bc = S[brass]
    bands = np.clip((bl / 16).astype(int), 0, 15)
    have = [k for k in range(16) if (bands == k).sum() >= 5]
    cols = np.array([np.median(bc[bands == k], 0) for k in have])
    lv = np.array([np.median(bl[bands == k]) for k in have])
    for c in range(3):
        ramp[:, c] = np.interp(np.arange(256), lv, cols[:, c])
    for mm in (blue, grey):
        # (stretched onto the brass's own range so a dark joint is dark brass, not black)
        l2 = lum[mm]
        if mm.sum():
            t = (l2 - l2.min()) / max(1.0, l2.max() - l2.min())
            S[mm] = ramp[np.clip((lv.min() + t * (lv.max() - lv.min())).astype(int), 0, 255)]
    # (stray red specks in the brass's shade are brass)
    lab, n = ndi.label(red)
    if n > 1:
        sz = ndi.sum(red, lab, range(1, n + 1))
        speck = np.isin(lab, [i + 1 for i, s_ in enumerate(sz) if s_ < 12])
        S[speck] = ramp[np.clip(lum[speck].astype(int), 0, 255)]
        red &= ~speck
    if red.sum():
        thr = np.median(lum[red])
        S[red & (lum >= thr)] = KEY_LIT
        S[red & (lum < thr)] = KEY_SHADE
    return S.astype(int)


def snap_key(a):
    """after a shrink, the payload's reds back onto the two key colours (a box filter mixes them with their
    neighbours, and the game's team shader only knows the pure reds)"""
    a = a.copy()
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    red = (a[..., 3] > 0) & (r > g + 70) & (r > b + 70) & (g < 90) & (b < 90)
    a[red & (r >= 200)] = KEY_LIT + (255,)
    a[red & (r < 200)] = KEY_SHADE + (255,)
    return a


PAYLOAD_SRC = payload_img()


def payload_at(width):
    w = int(round(width))
    h = int(round(PAYLOAD_SRC.height * w / PAYLOAD_SRC.width))
    p = np.array(PAYLOAD_SRC.resize((w, h), Image.LANCZOS))
    p[..., 3] = np.where(p[..., 3] >= 128, 255, 0)
    return p


# ------------------------------------------------------------------ cutting a row into parts

FACE = 0.70            # a wheel's face plate (hub, bolts) reaches this far out (of the rim's radius)
EDGE_PITCH = 22.0      # the edge-on wheels' tooth bars (N), measured down their middles
TEETH_PER_LOOP = 3     # MOVE: the teeth go round 3 pitches in the 8 frames (3/8 of a tooth a frame: clearly forward;
                       # at 1/2 a tooth a frame the eye cannot tell which way they turn)
TOOTH_PITCH = 26.0
TRIM_TOP = 13          # S/N: body px this far under the painted joint (and above) are the old arm's leftovers
FAR_RIM = 0.58         # a far wheel is replaced from here out (of its tips' radius); its middle stays painted
GAP_SHADE = 0.7       # the body seen through a near wheel's tooth gaps, in the wheel's shadow


def fit_wheel(WM, cx, cy, rx, ry, circle=True):
    """the wheel's own outline: an axis-aligned ellipse fitted to where its teeth meet the navy (round the hand-set
    guess); returns its middle and radii (the teeth's tips at about 1.0). ChatGPT drew the hubs a few px off the
    middle of the rims (they stick out of the face): the face turns about the rim's middle, the hub stays put"""
    edge = WM & ndi.binary_dilation(~WM)
    H, Wd = WM.shape
    yy, xx = np.mgrid[0:H, 0:Wd]
    rn = np.hypot((xx - cx) / rx, (yy - cy) / ry)
    ang = np.degrees(np.arctan2((yy - cy) / ry, (xx - cx) / rx)) % 360
    bins = (ang // 10).astype(int)
    outside = (rn > 1.12) & (rn < 1.3)
    cnt = np.bincount(bins[outside], minlength=36)
    hit = np.bincount(bins[outside & WM], minlength=36)
    clean = (hit / np.maximum(cnt, 1)) < 0.1
    sel = edge & (rn > 0.8) & (rn < 1.2) & clean[bins]
    y, x = np.nonzero(sel)
    if len(x) < 40:
        return cx, cy, rx, ry
    x, y = x.astype(float), y.astype(float)
    if circle:
        c, d, e = np.linalg.lstsq(np.c_[x, y, np.ones_like(x)], -(x * x + y * y), rcond=None)[0]
        ex, ey = -c / 2, -d / 2
        erx = ery = math.sqrt(max(1.0, ex * ex + ey * ey - e))
    else:
        a, b, c, d = np.linalg.lstsq(np.c_[x * x, y * y, x, y], np.ones_like(x), rcond=None)[0]
        ex, ey = -c / (2 * a), -d / (2 * b)
        k = 1 + c * c / (4 * a) + d * d / (4 * b)
        if k / a <= 0 or k / b <= 0:
            return cx, cy, rx, ry
        erx, ery = math.sqrt(k / a), math.sqrt(k / b)
    tip = float(np.percentile(np.hypot((x - ex) / erx, (y - ey) / ery), 92))
    if abs(ex - cx) > 15 or abs(ey - cy) > 15:
        return cx, cy, rx, ry
    return ex, ey, erx * tip, ery * tip


def measure_pitch(wh):
    """deg between the wheel's teeth: the autocorrelation of the teeth-or-gap signal round its tips, where they stand
    against the navy (ChatGPT's cogs have 11 to 17 teeth); TOOTH_PITCH when the teeth are too irregular to tell"""
    m = wh['mask']
    H, Wd = m.shape
    clean = wh['known'] if wh['kind'] == 'far' else wh['clean']
    sig, ok = [], []
    for a in np.arange(0, 360, 0.5):
        ar = math.radians(a)
        v = c = 0
        good = True
        for rr in np.linspace(0.93, 1.06, 6):
            x = int(round(wh['cx'] + rr * wh['rx'] * math.cos(ar)))
            y = int(round(wh['cy'] + rr * wh['ry'] * math.sin(ar)))
            if not (0 <= x < Wd and 0 <= y < H):
                good = False
                continue
            v += m[y, x]
            c += 1
            if rr > 1.0 and not clean[y, x]:
                good = False
        sig.append(v / max(c, 1))
        ok.append(good)
    sig, ok = np.array(sig, float), np.array(ok)
    best = (0.0, TOOTH_PITCH)
    for lag in range(30, 82):
        o = ok & np.roll(ok, -lag)
        if o.sum() < 40:
            continue
        x_ = sig[o] - sig[o].mean()
        y_ = np.roll(sig, -lag)[o] - np.roll(sig, -lag)[o].mean()
        c_ = (x_ * y_).sum() / math.sqrt((x_ * x_).sum() * (y_ * y_).sum() + 1e-9)
        if c_ > best[0]:
            best = (c_, lag / 2.0)
    return best[1] if best[0] > 0.45 else TOOTH_PITCH


def wheel_parts(R, W, WM, win):
    """the wheel layers of a row: a list of dicts (img, mask, ...); edge-on wheels nearest first"""
    x0, y0 = win[0], win[1]
    H, Wd = WM.shape
    yy, xx = np.mgrid[0:H, 0:Wd]
    r_, g_, b_ = W[..., 0], W[..., 1], W[..., 2]
    brass = WM & (r_ > 105) & (g_ > 45) & (b_ < 110) & (r_ > b_ + 50)
    blue = WM & (b_ > r_ + 40) & (b_ > 100)
    taken = np.zeros_like(WM)
    out = []
    nears = [w for w in R['wheels'] if w[4] == 'near']
    ang = None
    for w in R['wheels']:
        cx, cy, rx, ry, kind = w[0] - x0, w[1] - y0, w[2], w[3], w[4]
        if kind != 'edge':
            cx, cy, rx, ry = fit_wheel(WM, cx, cy, rx, ry, circle=abs(rx - ry) < 8)
            if '-v' in sys.argv:
                print('  wheel %s (%.1f, %.1f) r %.1f x %.1f' % (kind, cx + x0, cy + y0, rx, ry))
        rn = np.hypot((xx - cx) / rx, (yy - cy) / ry)
        if kind == 'edge':
            # seen edge-on: a rounded upright bar of tooth tops
            sil = (np.abs((xx - cx) / (rx + 1.5)) ** 4 + np.abs((yy - cy) / (ry + 1.5)) ** 4) <= 1
            m = WM & sil & ~taken
            if R['arm'] == 'front':
                m = np.zeros_like(WM)          # (S: the painted body stays whole behind them; see rewheel)
            out.append(dict(kind='edge', mask=m, img=rgba(W, m), cx=cx, cy=cy, rx=rx, ry=ry, overlap=np.zeros_like(WM)))
            taken |= m
            continue
        tip = rn <= 1.12
        ang = np.degrees(np.arctan2((yy - cy) / ry, (xx - cx) / rx)) % 360
        if kind == 'near':
            # round the ring: where the paint just outside the teeth is the body (not the navy), the gaps between
            # the teeth show the body behind: there only brass and the dark edge next to it is wheel
            outside = (rn > 1.13) & (rn < 1.25)
            bins = (ang // 6).astype(int)
            cnt = np.bincount(bins[outside], minlength=60)
            hit = np.bincount(bins[outside & WM], minlength=60)
            busy = (hit / np.maximum(cnt, 1)) > 0.5
            busy = busy | np.roll(busy, 1) | np.roll(busy, -1)
            over_body = busy[bins]
            ring = (rn <= 1.05) & (rn >= 0.84)
            red = (r_ > 140) & (g_ < 70) & (b_ < 70)
            grey = (np.abs(r_ - b_) < 18) & (np.abs(r_ - g_) < 18) & ((r_ + g_ + b_) > 150)
            foreign = blue | red | grey      # (a ball, a red band or grey frame poking into the ring is not wheel)
            m = WM & ((rn < 0.84) | (ring & ~over_body) | (ring & over_body & ~foreign) |
                      ((rn > 1.05) & (rn <= 1.12) & ~over_body))     # (the teeth tips poke a little past the ring)
            m &= ~taken
            hub = ndi.binary_dilation(blue & (rn < 0.38), iterations=1) & m
            lab_, nl_ = ndi.label(hub)
            if nl_ > 1:
                sz_ = ndi.sum(hub, lab_, range(1, nl_ + 1))
                hub &= lab_ == int(np.argmax(sz_)) + 1
            hys, hxs = np.nonzero(hub)
            hcx, hcy = (float(hxs.mean()), float(hys.mean())) if len(hxs) else (cx, cy)
            known = tip & ~over_body          # the teeth that stand against the navy, and the navy between them
            overlap = ring & over_body
            overb = over_body
        else:
            # a far wheel: only the teeth that stand out against the navy (no near wheel or body round them) turn
            cover = np.zeros_like(WM)
            for o_ in out:
                if o_['kind'] == 'near':
                    cover |= o_['rn'] <= 1.12
            outside = (rn > 1.13) & (rn < 1.3)
            bins = (ang // 6).astype(int)
            cnt = np.bincount(bins[outside], minlength=60)
            hit = np.bincount(bins[outside & (WM | cover)], minlength=60)
            busy = (hit / np.maximum(cnt, 1)) > 0.25
            busy = busy | np.roll(busy, 1) | np.roll(busy, -1)
            band = (rn >= 0.86) & tip & ~cover & ~busy[bins]
            m = WM & band
            hub = np.zeros_like(WM)
            hcx, hcy = cx, cy
            known = band.copy()               # the teeth there and the navy between them
            overlap = np.zeros_like(WM)
            overb = np.zeros_like(WM)
        img = rgba(W, m)
        # the painting's big light and shade (blurred brightness over the wheel)
        lum = (0.3 * r_ + 0.59 * g_ + 0.11 * b_) * m
        sig = 0.16 * max(rx, ry)
        light = ndi.gaussian_filter(lum.astype(float), sig) / np.maximum(ndi.gaussian_filter(m.astype(float), sig), 1e-3)
        # the face plate (hub and bolts) turns about the hub, which ChatGPT drew a few px off the rim's middle
        face_r = FACE * rx
        dh = np.hypot((xx - hcx) / rx, (yy - hcy) / ry) * rx
        out.append(dict(kind=kind, cx=cx, cy=cy, rx=rx, ry=ry, mask=m, img=img, hub=rgba(W, hub), hubm=hub,
                        known=known, light=light, rn=rn, overlap=overlap, overb=overb, cw=w[5] if len(w) > 5 else 1,
                        hcx=hcx, hcy=hcy, face=m & (dh <= face_r), clean=known & (dh > face_r)))
        out[-1]['pitch'] = measure_pitch(out[-1])
        taken |= m
    return out, taken


def _turn(wh, deg, centre, want, src_ok, steps=(0.0,)):
    """pixels in `want` (within the wheel's box) taken from where the turn by deg about centre brings them from
    (un-squashing the ellipse); only from `src_ok`; re-lit with the painting's big light and shade"""
    H, Wd = wh['mask'].shape
    cx, cy, rx, ry = wh['cx'], wh['cy'], wh['rx'], wh['ry']
    bx0, by0 = max(0, int(cx - 1.25 * rx)), max(0, int(cy - 1.25 * ry))
    bx1, by1 = min(Wd, int(cx + 1.25 * rx) + 2), min(H, int(cy + 1.25 * ry) + 2)
    sub = (slice(by0, by1), slice(bx0, bx1))
    yy, xx = np.mgrid[by0:by1, bx0:bx1].astype(float)
    ox, oy = centre
    Rr = float(max(rx, ry))
    X, Y = (xx - ox) * Rr / rx, (yy - oy) * Rr / ry
    outb = np.zeros((by1 - by0, bx1 - bx0, 4), np.uint8)
    w_ = want[sub]
    tried = np.zeros(w_.shape, bool)
    light = wh['light'][sub]
    for k in steps:
        a = math.radians(-(deg + k))
        c, s_ = math.cos(a), math.sin(a)
        ix = np.clip(np.rint(ox + (c * X - s_ * Y) * rx / Rr).astype(int), 0, Wd - 1)
        iy = np.clip(np.rint(oy + (s_ * X + c * Y) * ry / Rr).astype(int), 0, H - 1)
        ok = w_ & ~tried & src_ok[iy, ix]
        src = wh['img'][iy, ix]
        lit = src.astype(float)
        lit[..., :3] *= np.clip(light / np.maximum(wh['light'][iy, ix], 1.0), 0.6, 1.6)[..., None]
        lit = np.clip(lit, 0, 255).astype(np.uint8)
        outb[ok] = lit[ok]
        outb[ok & (src[..., 3] == 0)] = 0
        tried |= ok
    out = np.zeros((H, Wd, 4), np.uint8)
    out[sub] = outb
    return out, tried, sub


def turn_wheel(wh, frac, pitch=None):
    """the wheel turned on by frac of a MOVE loop (screen clockwise): its tooth ring about the rim's middle by
    TEETH_PER_LOOP pitches, its face plate (four bolts) about the hub by a quarter turn, so both come round in one
    loop (nobody sees that the two go at slightly different speeds); the hub ball stays still"""
    deg = TEETH_PER_LOOP * pitch * frac
    face_deg = 90.0 * frac
    if wh['kind'] == 'far':
        out, tried, sub = _turn(wh, deg, (wh['cx'], wh['cy']), wh['known'], wh['known'],
                                [0.0] + [k * pitch for j in range(1, 5) for k in (j, -j)])
        rest = np.zeros_like(wh['mask'])
        rest[sub] = wh['mask'][sub] & ~tried
        out[rest] = wh['img'][rest]
        return out
    # the teeth against the navy go round (taken one pitch round where the turn brings in teeth that stand over the
    # body, which stay as painted); the face plate turns about the hub
    st = [0.0] + [k * pitch for j in range(1, 5) for k in (j, -j)]
    out = wh['img'].copy()
    out[wh['clean']] = 0
    ring, _, _ = _turn(wh, deg, (wh['cx'], wh['cy']), wh['clean'], wh['clean'], st)
    over(out, ring)
    face, _, _ = _turn(wh, face_deg, (wh['hcx'], wh['hcy']), wh['face'], wh['face'])
    over(out, face)
    return over(out, wh['hub'])


def scroll_edge(wh, frac, pitch):
    """an edge-on wheel: its tooth bars move down the tread by frac of a pitch"""
    m = wh['mask']
    H, Wd = m.shape
    s = (frac * pitch) % pitch
    out = np.zeros((H, Wd, 4), np.uint8)
    ys, xs = np.nonzero(m)
    done = np.zeros(len(ys), bool)
    for k in (0, 1, -1, 2, -2):
        sy = np.rint(ys - s + k * pitch).astype(int)
        ok = ~done & (sy >= 0) & (sy < H)
        ok[ok] &= m[sy[ok], xs[ok]]
        out[ys[ok], xs[ok]] = wh['img'][sy[ok], xs[ok]]
        done |= ok
    out[ys[~done], xs[~done]] = wh['img'][ys[~done], xs[~done]]      # (no bar comes round there: as painted)
    return out


def rewheel(Wf, bodym, win, xx, yy):
    """S: ChatGPT's face-on wheels (and the rear wheels' face-on teeth peeking out behind them) come off the body
    (REWHEEL), the blue balls and the crank stay; where they covered the ends of the body's riveted base, the base
    is filled from its own plate SHIFT px further in (left end; past the red band where it is in the way), and the right end is the left end mirrored about the
    middle (the base is painted symmetric: plates, red bands, the clock in the middle); its outermost column and
    bottom row are darkened to the base's outline (CODE EDIT). The edge-on cogs are drawn over it later."""
    x0, y0 = win[0], win[1]
    X, Y = xx + x0, yy + y0
    r_, g_, b_ = Wf[..., 0], Wf[..., 1], Wf[..., 2]
    blue = (b_ > r_ + 40) & (b_ > 100)
    old = np.zeros_like(bodym)
    for cx, cy, rx, ry in REWHEEL['old']:
        old |= ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1
    keep = ndi.binary_dilation(blue & bodym & ~old, iterations=2)     # (the old hubs' balls go with their wheels)
    for bx0_, by0_, bx1_, by1_ in REWHEEL['peeks']:
        old |= (X >= bx0_) & (X <= bx1_) & (Y >= by0_) & (Y <= by1_)
    kx0, ky0, kx1, ky1 = REWHEEL['block']
    block = (X >= kx0) & (X <= kx1) & (Y >= ky0) & (Y <= ky1)
    bodym = bodym & ~(old & ~keep & ~block)
    Wf = Wf.copy()
    cov = old & block
    mid, sh = REWHEEL['mid'], REWHEEL['shift']
    ys, xs = np.nonzero(cov & (X < mid))
    for y, x in zip(ys, xs):
        k = 1
        while cov[y, x + k * sh] or (r_[y, x + k * sh] > g_[y, x + k * sh] + 60):    # (not from the red band)
            k += 1
        Wf[y, x] = Wf[y, x + k * sh]
    ys, xs = np.nonzero(cov & (X >= mid))
    for y, x in zip(ys, xs):
        Wf[y, x] = Wf[y, x - (2 * (X[y, x] - mid))]
    edge = cov & ((X <= kx0 + 1) | (X >= kx1 - 1) | (Y >= ky1 - 1))
    Wf[edge] = (Wf[edge] * 0.25).astype(int)
    bodym = bodym | cov
    return Wf, bodym


def squash_wheels(R, wheels, Wb, bodym2, painted, xx, yy):
    """SE: the wheels' faces are turned about 45 deg from us, so each cog is drawn in an ellipse SQUASH_34 as wide as
    tall (ChatGPT painted round, face-on wheels). The painted round wheel was cut out whole; the strips of it left on
    either side of the narrower cog (lunes) are filled where they lie inside the body's outline (a smooth fill from
    the surrounding body paint, in the wheel's shadow: CODE FILL), and left empty (navy) where they stood out of it"""
    k = R['squash']
    new = np.zeros_like(bodym2)
    lune = np.zeros_like(bodym2)
    for wh in wheels:
        if wh['kind'] not in ('near', 'far'):
            continue
        wh['rx0'] = wh['rx']
        wh['rx'] = wh['rx'] * k
        rn2 = np.hypot((xx - wh['cx']) / wh['rx'], (yy - wh['cy']) / wh['ry'])
        new |= rn2 <= 1.02
        lune |= (wh['rn'] <= 1.12) & (rn2 > 0.97)
    lune &= ~painted                  # (the gap fills made for the round wheel are redone there)
    bodym2 = bodym2 & ~lune
    disk = np.hypot(*np.mgrid[-6:7, -6:7]) <= 6
    sil = ndi.binary_fill_holes(ndi.binary_closing(bodym2 | new, structure=disk, iterations=1))
    todo = lune & sil & ~new
    if todo.any():
        # a smooth fill: repeated blurs of the known body paint (harmonic-like; not from the blue balls), then shaded
        r_, g_, b_ = Wb[..., 0], Wb[..., 1], Wb[..., 2]
        known = (bodym2 & ~((b_ > r_ + 30) & (b_ > 70))).astype(float)
        acc = Wb.astype(float) * known[..., None]
        wsum = known.copy()
        for sig in (2, 4, 8, 16):
            a_ = np.stack([ndi.gaussian_filter(acc[..., c], sig) for c in range(3)], -1)
            w_ = ndi.gaussian_filter(wsum, sig)
            fillc = a_ / np.maximum(w_, 1e-4)[..., None]
            t_ = todo & (w_ > 0.02)
            Wb = Wb.copy()
            Wb[t_] = (fillc[t_] * GAP_SHADE).astype(int)
            acc[t_] = Wb[t_]
            wsum[t_] = 1.0
            todo = todo & ~t_
            bodym2 = bodym2 | t_
    return Wb, bodym2


def cut_row(r):
    R = ROWS[r]
    bx0, by0, bx1, by1 = R['box']
    win = (bx0 - MARGIN[0], by0 - MARGIN[1], bx1 + MARGIN[2], by1 + MARGIN[3])
    x0, y0, x1, y1 = win
    W = np.full((y1 - y0, x1 - x0, 3), NAVY, int)
    sx0, sy0, sx1, sy1 = max(0, x0), max(0, y0), min(SHEET.shape[1], x1), min(SHEET.shape[0], y1)
    W[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = SHEET[sy0:sy1, sx0:sx1]
    WM = solid(W)
    unit = np.zeros_like(WM)
    unit[by0 - y0 - 2:by1 - y0 + 2, bx0 - x0 - 2:bx1 - x0 + 2] = True
    WM &= unit
    Hh, Wd = WM.shape
    yy, xx = np.mgrid[0:Hh, 0:Wd]
    r_, g_, b_ = W[..., 0], W[..., 1], W[..., 2]
    H = np.array(R['H'], float) - (x0, y0)
    J = np.array(R['J'], float) - (x0, y0)
    L = float(np.hypot(*(H - J)))
    a = (H - J) / L
    n = np.array([-a[1], a[0]])
    t = (xx - J[0]) * a[0] + (yy - J[1]) * a[1]
    v = (xx - J[0]) * n[0] + (yy - J[1]) * n[1]
    corridor = (np.abs(v) <= R['bw'] / 2.0) & (t >= -1)
    # the cup (and in S/N its joint ball): the box, before the beam starts
    cx0, cy0, cx1, cy1 = R['cup']
    cupbox = (xx >= cx0 - x0) & (xx < cx1 - x0) & (yy >= cy0 - y0) & (yy < cy1 - y0)
    if R['arm'] == 'behind':
        cup = WM & cupbox & ~(corridor & (t >= 0))
    else:
        cup = WM & cupbox & (t <= 2)
    lab, nl = ndi.label(cup)
    if nl > 1:
        sz = ndi.sum(cup, lab, range(1, nl + 1))
        cup &= lab == int(np.argmax(sz)) + 1
    # the beam: greys (its dark body, light edge, outline) and its small brass rivets
    grey = (np.abs(r_ - g_) < 45) & (np.abs(g_ - b_) < 45)
    brass = (r_ > 140) & (g_ > 80) & (b_ < 110)
    lab, nl = ndi.label(brass & WM)
    small = np.zeros_like(WM)
    if nl:
        sz = ndi.sum(brass & WM, lab, range(1, nl + 1))
        small = np.isin(lab, [i + 1 for i, s_ in enumerate(sz) if s_ <= 25])
    hubm = np.zeros_like(WM)
    if R['hub']:
        hx0, hy0, hx1, hy1 = R['hub']
        hubm = WM & (xx >= hx0 - x0) & (xx < hx1 - x0) & (yy >= hy0 - y0) & (yy < hy1 - y0)
    if R['arm'] == 'behind':
        # (the hinge's blue ball stays on the body: the beam stops at it)
        ball = ndi.binary_dilation((b_ > r_ + 40) & (b_ > 100) & (np.hypot(xx - H[0], yy - H[1]) < 16), iterations=1)
        beam = WM & corridor & (grey | small) & ~cup & (t <= L) & ~ball
        beam = ndi.binary_fill_holes(beam) & WM & corridor
        if R['clean']:
            # behind the drum's rim: the stretch that shows whole, repeated along the beam (whole px, no resampling)
            ta, tb = R['clean']
            beam &= t <= tb
            P = tb - ta
            sh = np.rint(P * a).astype(int)
            beam_img = rgba(W, beam)
            need = corridor & (t > tb) & (t <= L)
            ys, xs = np.nonzero(need)
            for k in range(1, 12):
                if len(ys) == 0:
                    break
                sy, sx = ys - k * sh[1], xs - k * sh[0]
                inb = (sy >= 0) & (sy < Hh) & (sx >= 0) & (sx < Wd)
                src_t = t[np.clip(sy, 0, Hh - 1), np.clip(sx, 0, Wd - 1)]
                ok = inb & (src_t <= tb)
                beam_img[ys[ok], xs[ok]] = beam_img[sy[ok], sx[ok]]
                ys, xs = ys[~ok], xs[~ok]
            # what shows of the beam past the clean stretch (above the rim) comes off the body too; the rim stays
            rim = ndi.binary_dilation(WM & ~grey & ~small, iterations=1)
            extra = WM & corridor & (t > tb) & (t <= L) & (grey | small) & ~rim & ~ball
            cut = beam | cup | extra
        else:
            beam_img = rgba(W, beam)
            cut = beam | cup
    else:
        beam = WM & corridor & (t <= L) & ~cup & ~hubm
        beam_img = rgba(W, beam)
        cut = beam | cup
    body = WM & ~cut
    # thin leftovers of the beam's outline sticking out into the navy along its way (1-2 px lines) go too
    near = ndi.binary_dilation(cut, iterations=3)
    k = np.ones((9, 9))
    sparse = ndi.convolve(body.astype(float), k, mode='constant') / k.sum() < 0.45
    body &= ~(near & sparse & ~ndi.binary_opening(body, structure=np.ones((3, 3))))
    # fill what the arm leaves behind
    fill = np.zeros_like(WM)
    Wf = W.copy()
    if R['arm'] == 'behind':
        # where the beam lay over the machine: the cut pixels inside the body's outline (its notches up to ~12 px
        # closed) take the nearest body paint; where it stood out over the navy, nothing
        k = np.ones((11, 11))
        dens = ndi.convolve(body.astype(float), k, mode='constant') / k.sum()
        disk = np.hypot(*np.mgrid[-6:7, -6:7]) <= 6
        fill = cut & ((dens > 0.55) | ndi.binary_closing(body, structure=disk))
        Wf = fill_nearest(W, body, fill)
    else:
        # the drum behind the upright beam and ball: row by row between its two sides (a few px out, past the
        # beam's outline), where the result is paint and not the navy
        for y in range(Hh):
            row = cut[y]
            if not row.any():
                continue
            xs_ = np.nonzero(row)[0]
            for seg in np.split(xs_, np.nonzero(np.diff(xs_) > 1)[0] + 1):
                l, rr = seg[0] - 2, seg[-1] + 2
                if l < 2 or rr >= Wd - 2:
                    continue
                cl = np.median(W[y, l - 2:l + 1], axis=0)
                cr = np.median(W[y, rr:rr + 3], axis=0)
                for xq in range(l + 1, rr):
                    f = (xq - l) / float(rr - l)
                    c = (1 - f) * cl + f * cr
                    if np.abs(c - NAVY).sum() > 45 and (body[y, l] or body[y, rr]):
                        Wf[y, xq] = c
                        fill[y, xq] = True
                    elif cut[y, xq]:
                        fill[y, xq] = False
    bodym = body | fill
    if R['arm'] != 'behind':
        # (S/N: what is left of the upright beam and the joint ball above the drum's arch, a dark scrap the row fill
        # left standing, goes; the painted arm is drawn there in every frame)
        bodym &= ~((yy < J[1] + TRIM_TOP) & (np.abs(xx - J[0]) <= R['bw'] / 2.0 + 8))
    if R['arm'] == 'front':
        Wf, bodym = rewheel(Wf, bodym, win, xx, yy)
    # the wheels come off the body: each is replaced by the rebuilt painted cog (cog.py), turned in code
    wheels, taken = wheel_parts(R, Wf, bodym, win)
    Wb = Wf.copy()
    bodym2 = bodym & ~taken
    near_cover = np.zeros_like(WM)
    far_cover = np.zeros_like(WM)
    for wh in wheels:
        if wh['kind'] == 'near':
            near_cover |= wh['rn'] <= 1.12
        elif wh['kind'] == 'far':
            far_cover |= wh['rn'] <= 0.8      # (the far cog is solid in there)
    ang_of = {}
    for wh in wheels:
        if wh['kind'] == 'far':
            # the far wheel's visible rim and teeth come off the body (not what stands in front of it: OCC, hand-set);
            # its painted middle (behind the chassis, only a dark face shows) stays; the new cog is drawn behind
            occ = np.zeros_like(WM)
            if R.get('occ'):
                from PIL import ImageDraw
                om = Image.new('L', (Wd, Hh), 0)
                ImageDraw.Draw(om).polygon([(x - x0, y - y0) for x, y in R['occ']], fill=255)
                occ = np.array(om) > 0
            vis = bodym2 & (wh['rn'] >= FAR_RIM) & (wh['rn'] <= 1.15) & ~near_cover & ~occ
            bodym2 &= ~vis
            wh['cutout'] = vis
    # behind a near wheel's tooth gaps, where it stands over the body: the body's own paint, reflected inward from
    # just outside the wheel's tips (so its texture carries on), in the wheel's shadow (CODE SHADE x GAP_SHADE);
    # over the far wheel nothing (the turning far cog shows through); over the navy nothing
    painted = bodym2.copy()           # (the body as painted, before the fills under the wheels)
    _, (iy0, ix0) = ndi.distance_transform_edt(~bodym2, return_indices=True)
    for wh in wheels:
        if wh['kind'] != 'near':
            continue
        rn = wh['rn']
        k_ = np.ones((11, 11))
        dens = ndi.convolve(bodym2.astype(float), k_, mode='constant') / k_.sum()
        gap = (rn >= 0.74) & (rn <= 1.14) & (wh['overb'] | (wh['mask'] & (dens > 0.35))) & ~far_cover
        a_ = np.arctan2((yy - wh['cy']) / wh['ry'], (xx - wh['cx']) / wh['rx'])
        rs = np.maximum(2.28 - rn, 1.16)
        sx = np.clip(np.rint(wh['cx'] + rs * wh['rx'] * np.cos(a_)).astype(int), 0, Wd - 1)
        sy = np.clip(np.rint(wh['cy'] + rs * wh['ry'] * np.sin(a_)).astype(int), 0, Hh - 1)
        ok = bodym2[sy, sx]
        sy = np.where(ok, sy, iy0[sy, sx])
        sx = np.where(ok, sx, ix0[sy, sx])
        g = gap & ~bodym2
        Wb[g] = Wf[sy[g], sx[g]] * GAP_SHADE
        bodym2 |= g
        wh['cutout'] = np.zeros_like(WM)
    # what is left enclosed (between the body and the cogs' solid middles, where no gap reached): the nearest body
    # paint, in the same shade
    discs = np.zeros_like(WM)
    for wh in wheels:
        if wh['kind'] in ('near', 'far'):
            discs |= wh['rn'] <= 0.8
    hole = ndi.binary_fill_holes(bodym2 | discs) & ~(bodym2 | discs)
    if hole.any():
        _, (iy1, ix1) = ndi.distance_transform_edt(~bodym2, return_indices=True)
        Wb[hole] = Wb[iy1[hole], ix1[hole]] * GAP_SHADE
        bodym2 |= hole
    if R.get('squash'):
        Wb, bodym2 = squash_wheels(R, wheels, Wb, bodym2, painted, xx, yy)
    lab, nl = ndi.label(bodym2)
    if nl > 1:
        sz = ndi.sum(bodym2, lab, range(1, nl + 1))
        bodym2 &= np.isin(lab, [i + 1 for i, s_ in enumerate(sz) if s_ >= 40])
    hub_img = rgba(W, hubm)
    # the payload's place in the cup and the cup's front wall (over the payload)
    rcx, rcy, rrx, rry = R['rim']
    rcx, rcy = rcx - x0, rcy - y0
    inside = np.clip(1 - ((xx - rcx) / rrx) ** 2, 0, 1)
    front = cup & (yy > rcy + rry * np.sqrt(inside) - 1) & (np.abs(xx - rcx) <= rrx + 3)
    return dict(win=win, H=H, J=J, L=L, body=rgba(Wb, bodym2), cup=rgba(W, cup), cupfront=rgba(W, front),
                beam=beam_img, hub=hub_img, wheels=wheels, rim=(rcx, rcy, rrx, rry), size=(Wd, Hh), W=W, WM=WM)


# ------------------------------------------------------------------ the painted arm poses (S and N)

POSES_SHEET = np.array(Image.open('art/redraws/catapult_arm_poses_chatgpt.png').convert('RGB')).astype(int)
# ChatGPT's arm-pose sheet (art/redraws/catapult_arm_poses_chatgpt.png) repeated one view in every row; only these
# cells are used (sheet px): column 2 row 1, the arm STRAIGHT UP ('up'), and column 4 row 1, the arm foreshortened
# TOWARD the viewer with the cup's mouth facing us ('tip', the S follow-through); 'under' (N from N_BACK_T down: the
# arm up or leaning away, the cup's back to us) is column 2 row 3 (UNDER).
# Per piece: the box of the cup and the joint ball, the ball's middle (the joint J), the rim ellipse (cx, cy, rx, ry)
POSE_CELLS = {
    'up': dict(box=(355, 76, 436, 153), ball=(395, 142), rim=(395, 92, 34, 9)),
    'tip': dict(box=(854, 104, 935, 192), ball=(891, 180), rim=(890, 135, 30, 26)),
}
# 'under': column 2 row 3, the cup seen from BELOW: the rim a thin line at the top, the convex outside of the bowl with
# its rivets toward us, no mouth or inside. N and NE use it once the arm is up or past vertical (the cup's mouth faces
# away from a camera behind the machine). ChatGPT drew it smaller than the other cups: it is scaled (LANCZOS) to the
# 'up' cup's width (N) or to the row's own cup (NE). Box (sheet px), the joint ball's middle, the bowl's middle
UNDER = dict(box=(366, 524, 428, 587), ball=(395.6, 578.0), bowl=(396.0, 551.0))
BEAM_TEX = (380, 157, 411, 205)   # column 2's beam between two rivets (one period), tiled down from the joint
BALL_R = 9                        # the joint ball's half height: the beam starts under it
POSE_UP_MIN = 75.0                # S/N: the arm uses the straight-up paint from this angle up to POSE_UP_MAX
POSE_UP_MAX = 155.0               # (and the painted loaded arm above it); below POSE_UP_MIN the follow-through paint


def width(img):
    xs = np.nonzero((img[..., 3] > 0).any(0))[0]
    return float(xs.max() - xs.min() + 1)


UNDER_IMG = None


def under_piece(w):
    """the cup seen from below (UNDER), scaled to w px wide: img, anchor (the joint ball's middle), rim_off (bowl's
    middle from the ball), rim radii"""
    global UNDER_IMG
    if UNDER_IMG is None:
        x0, y0, x1, y1 = UNDER['box']
        C = POSES_SHEET[y0:y1, x0:x1]
        m = solid(C)
        lab, n = ndi.label(m)
        if n > 1:
            sz = ndi.sum(m, lab, range(1, n + 1))
            m &= lab == int(np.argmax(sz)) + 1
        UNDER_IMG = rgba(C, m)
    k = w / width(UNDER_IMG)
    h0, w0 = UNDER_IMG.shape[:2]
    a = UNDER_IMG[..., 3:4].astype(float) / 255
    pre = np.concatenate([UNDER_IMG[..., :3] * a, a * 255], -1).astype(np.uint8)
    big = np.array(Image.fromarray(pre, 'RGBA').resize((int(round(w0 * k)), int(round(h0 * k))), Image.LANCZOS)).astype(float)
    al = big[..., 3:4] / 255
    img = np.zeros(big.shape, np.uint8)
    img[..., :3] = np.clip(np.where(al > 0.02, big[..., :3] / np.maximum(al, 0.02), 0), 0, 255)
    img[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    img[img[..., 3] == 0] = 0
    x0, y0 = UNDER['box'][:2]
    anc = (np.array(UNDER['ball']) - (x0, y0)) * k
    return dict(img=img, front=np.zeros_like(img), anchor=anc, rim_off=(np.array(UNDER['bowl']) - UNDER['ball']) * k,
                rim=(width(img) / 2.0, 3.0))


def pose_pieces():
    out = {}
    for name, c in POSE_CELLS.items():
        x0, y0, x1, y1 = c['box']
        C = POSES_SHEET[y0:y1, x0:x1]
        m = solid(C)
        lab, n = ndi.label(m)
        if n > 1:
            sz = ndi.sum(m, lab, range(1, n + 1))
            m &= lab == int(np.argmax(sz)) + 1
        yy, xx = np.mgrid[y0:y1, x0:x1]
        cx, cy, rx, ry = c['rim']
        front = m & (yy > cy + ry * np.sqrt(np.clip(1 - ((xx - cx) / rx) ** 2, 0, 1)) - 1) & (yy < c['ball'][1] - BALL_R)
        out[name] = dict(img=rgba(C, m), front=rgba(C, front), anchor=np.array(c['ball'], float) - (x0, y0),
                         rim_off=np.array([cx, cy], float) - c['ball'], rim=(rx, ry))
    # 'under' (see UNDER), scaled to the 'up' cup's width
    out['under'] = under_piece(width(out['up']['img'][: int(out['up']['anchor'][1] - BALL_R)]))
    x0, y0, x1, y1 = BEAM_TEX
    C = POSES_SHEET[y0:y1, x0:x1]
    tex = rgba(C, solid(C))
    return out, tex


POSE, BEAM = pose_pieces()


def pose_for(r, T):
    """which painted pose the arm uses at angle T (S and N only), None for the stretched loaded arm"""
    if ROWS[r]['arm'] not in ('front', 'n') or T >= POSE_UP_MAX:
        return None
    if ROWS[r]['arm'] == 'n':
        return 'under'      # (seen from behind: the cup always shows its back, its mouth toward the enemy)
    if T >= POSE_UP_MIN:
        return 'up'
    return 'tip'


def pose_arm(P, pose, H, Jn):
    """the painted arm: the beam tiled (whole px, BEAM_TEX one rivet period at a time) from under the joint ball down
    into the hinge (whose knuckle the body draws over it), the cup and ball at the joint. Returns (beam, cup and ball,
    cup's front wall, the cup's middle, the rim's radii)"""
    Wd, Hh = P['size']
    pc = POSE[pose]
    arm = np.zeros((Hh, Wd, 4), np.uint8)
    top = int(round(Jn[1] + BALL_R - 1))
    bot = int(round(H[1] + 14))
    th, tw = BEAM.shape[:2]
    y = top
    while y < bot:
        n = min(th, bot - y)
        # the beam leans a little where the joint is not straight above the hinge
        f = (y - top) / max(1.0, bot - top)
        x = int(round(Jn[0] + (H[0] - Jn[0]) * f - tw / 2.0))
        _paste(arm, BEAM[:n], x, y)
        y += n
    cup = np.zeros((Hh, Wd, 4), np.uint8)
    ox, oy = int(round(Jn[0] - pc['anchor'][0])), int(round(Jn[1] - pc['anchor'][1]))
    _paste(cup, pc['img'], ox, oy)
    front = np.zeros((Hh, Wd, 4), np.uint8)
    _paste(front, pc['front'], ox, oy)
    return arm, cup, front, Jn + pc['rim_off'], pc['rim']


# ------------------------------------------------------------------ the arm in 3D

def fwd(r, P):
    """the row's forward axis on screen: given, or fitted so the painted arm is the loaded pose"""
    R = ROWS[r]
    if R['F'] is not None:
        return np.array(R['F'], float)
    v = np.array(P, float) - ARM_L * math.sin(math.radians(T0)) * np.array([0.0, -1.0])
    return v / (ARM_L * math.cos(math.radians(T0)))


def arm_vec(r, F, T):
    t = math.radians(T)
    if ROWS[r]['arm'] == 'n' and T < 90:
        # N, the follow-through leaning AWAY from us: depth counts DEPTH_AWAY up the screen (not DEPTH), so the cup
        # stays at least as high as at vertical instead of sinking back toward the machine, which read as the arm
        # tipping toward us (a choice for the eye: the camera's real slope is DEPTH)
        F = F * (DEPTH_AWAY / DEPTH)
    return ARM_L * (math.cos(t) * F + math.sin(t) * np.array([0.0, -1.0]))


PARTS = []
for _r in range(5):
    _p = cut_row(_r)
    _p['F'] = fwd(_r, _p['J'] - _p['H'])
    _p['paint'] = _p['J'] - _p['H']          # the painted arm vector (hinge -> joint)
    _p['vpaint'] = arm_vec(_r, _p['F'], ROWS[_r]['tpaint'])
    _p['M0'] = stretch_to(_p['vpaint'], _p['paint'])
    PARTS.append(_p)
PARTS[4]['under'] = POSE['under']             # N: its loaded back cup the same size as the painted poses'
PAY_GAME = 11.3 * 42.0 / 59.0                # the curled soldier, game px across: the old one (11.3 px with a 59 px
PAY_W = PAY_GAME / GS                         # soldier) shrunk with the new Clock Soldier (42 px tall)
PAYLOAD = payload_at(PAY_W)
LAUNCH = 40.0                                 # the payload flies off this steeply (deg)


def wheel_pitch(wh):
    """tooth pitch in deg: the teeth on a ring just inside the tips, counted by brightness"""
    rn, m = wh['rn'], wh['mask']
    H, Wd = m.shape
    angs = np.radians(np.arange(0, 360, 2.0))
    best = None
    for rr in (0.90, 0.94):
        vals = []
        for a in angs:
            x = int(round(wh['cx'] + rr * wh['rx'] * math.cos(a)))
            y = int(round(wh['cy'] + rr * wh['ry'] * math.sin(a)))
            vals.append(1.0 if 0 <= x < Wd and 0 <= y < H and m[y, x] else 0.0)
        v = np.array(vals) - np.mean(vals)
        f = np.abs(np.fft.rfft(v))
        f[:6] = 0
        k = int(np.argmax(f[:40]))
        if best is None or f[k] > best[0]:
            best = (f[k], k)
    return 360.0 / max(6, best[1])


def arm_now(r, T):
    """the arm's vector (hinge -> joint) on screen at angle T: the model, nudged so the painted angle gives exactly
    the painted vector"""
    P = PARTS[r]
    return P['M0'] @ arm_vec(r, P['F'], T)


def back_cup(r, T):
    """NE and N (seen from behind): the cup's back is to us in EVERY pose (the owner: the cup must always read as
    facing the enemy; its mouth, the hole, is never shown). Was: only from back_t down"""
    return ROWS[r].get('back_t') is not None


def back_axis(r, T):
    """the direction the back cup's axis lies along on screen: the beam's, but never leaning back further than at
    back_t (while the arm is cocked back toward us the cup stays tipped toward the enemy on its joint: a choice for
    the eye, so the loaded cup shows its back too)"""
    return arm_now(r, min(T, ROWS[r]['back_t']))


PEEK = 0.50            # N/NE loaded: this much of the curled soldier's height shows over the back cup's far rim


def cup_top(cup):
    """the back cup's top on screen: (x, y) of the middle of its topmost row"""
    ys, xs = np.nonzero(cup[..., 3])
    y0 = ys.min()
    row = xs[ys <= y0 + 2]
    return float(row.min() + row.max()) / 2.0, float(y0)


def under_on(P, Jn, v):
    """the 'under' cup (UNDER) at the joint Jn, scaled to this row's cup and turned so its axis lies along the beam
    (v: hinge -> joint): the layer and the bowl's middle"""
    if 'under' not in P:
        P['under'] = under_piece(width(P['cup']))
    u = P['under']
    Wd, Hh = P['size']
    canvas = np.zeros((Hh, Wd, 4), np.uint8)
    ox, oy = int(Wd // 2 - u['anchor'][0]), int(Hh // 2 - u['anchor'][1])
    _paste(canvas, u['img'], ox, oy)
    a0 = np.array([ox, oy], float) + u['anchor']
    turn = math.degrees(math.atan2(v[1], v[0]) - math.atan2(-1.0, 0.0))
    M = rotm(turn)
    return place(canvas, a0, Jn, M), Jn + M @ u['rim_off']


def frame(r, T, wheel_frac, payload=None, edge_frac=0.0):
    """one frame of row r at painted scale, as layer groups [(rgba, rides)] bottom to top (rides: moves with the
    body's bob, which is added later in whole game px); and the cup's middle. Arm angle T, wheels turned on by
    wheel_frac of a MOVE loop;
    payload: None, ('cup', drop px above the cup), or ('fly', (dx, dy, spin) from the cup's middle at release)"""
    P = PARTS[r]
    R = ROWS[r]
    Wd, Hh = P['size']
    H = P['H']
    v = arm_now(r, T)
    Jn = H + v
    pose = pose_for(r, T)
    arm = np.zeros((Hh, Wd, 4), np.uint8)
    back = None            # N / NE: the cup seen from behind, drawn over the payload (which peeks over its far rim)
    if pose:
        # S / N: ChatGPT's own painted arm for this pose (no stretched beam), the cup at the joint
        parm, pcup, cupf, mid, (rrx, rry) = pose_arm(P, pose, H, Jn)
        over(arm, parm)
        if pose == 'under':
            back = pcup
        else:
            over(arm, pcup)
        rcx, rcy = mid
        to_screen = lambda img: img
    else:
        beam = place(P['beam'], H, H, stretch_to(P['paint'], v))
        # the cup: turns with the beam on screen (side and 3/4 views); S/N it only moves
        turn = 0.0
        if R['arm'] == 'behind':
            turn = math.degrees(math.atan2(v[1], v[0]) - math.atan2(P['paint'][1], P['paint'][0]))
        Mc = rotm(turn)
        if back_cup(r, T):
            # NE (seen from behind) once the arm is up or past vertical: the cup seen from below (its back), its axis
            # along the beam, its joint ball on the beam's end
            cup, mid = under_on(P, Jn, back_axis(r, T))
            cupf = np.zeros_like(cup)
            (rcx, rcy), rrx, rry = mid, 0.0, 0.0
            back = cup
        else:
            cup = place(P['cup'], P['J'], Jn, Mc)
            cupf = place(P['cupfront'], P['J'], Jn, Mc)
            rcx, rcy, rrx, rry = P['rim']
            mid = Jn + Mc @ (np.array([rcx, rcy]) - P['J'])
        over(arm, beam)
        if back is None:
            over(arm, cup)
        to_screen = lambda img: place(img, P['J'], Jn, Mc)
    fly = None
    pay = None
    cupf_l = None
    if payload is not None:
        ph, pw = PAYLOAD.shape[:2]
        if payload[0] == 'cup' and back is not None:
            # N / NE: behind the cup's back, its top peeking over the far rim (the cup is visibly loaded)
            tx, ty = cup_top(back)
            pay = np.zeros((Hh, Wd, 4), np.uint8)
            _paste(pay, PAYLOAD, int(round(tx - pw / 2.0)), int(round(ty - ph * PEEK - payload[1])))
        elif payload[0] == 'cup':
            # sitting in the bowl (its lower part behind the cup's front wall); turned with the cup
            pim = np.zeros((Hh, Wd, 4), np.uint8)
            _paste(pim, PAYLOAD, int(round(rcx - pw / 2.0)), int(round(rcy + rry * 0.35 - ph * 0.70 - payload[1])))
            pay = to_screen(pim)
            if payload[1] <= 0:
                cupf_l = cupf
        else:
            dx, dy, spin = payload[1]
            pr = np.array(Image.fromarray(PAYLOAD, 'RGBA').rotate(spin, resample=Image.NEAREST, expand=True))
            fly = np.zeros((Hh, Wd, 4), np.uint8)
            _paste(fly, pr, int(round(dx - pr.shape[1] / 2.0)), int(round(dy - pr.shape[0] / 2.0)))
    groups = []

    def add(img, rides, snap=False):
        # (the payload is a layer of its own: its team-colour reds are snapped back to the key after the shrink)
        if groups and groups[-1][1] == rides and not snap and not groups[-1][2]:
            over(groups[-1][0], img)
        else:
            groups.append((img.copy(), rides, snap))

    def add_arm():
        add(arm, True)
        if pay is not None:
            add(pay, True, True)
        if cupf_l is not None:
            add(cupf_l, True)
        if back is not None:
            if fly is not None:
                # N / NE: the soldier leaves over the cup's far rim, behind its back (the mouth side, away from us)
                add(fly, False, True)
            add(back, True)
    for wh in P['wheels']:
        if wh['kind'] == 'far' or (wh['kind'] == 'edge' and wh.get('far')):
            add(cog_layer(P, wh, wheel_frac), False)
    arm_front = R['arm'] == 'front' or (R['arm'] == 'n' and T > 90)
    if not arm_front:
        add_arm()
    add(P['body'], True)
    for wh in P['wheels']:
        if wh['kind'] == 'near' or (wh['kind'] == 'edge' and not wh.get('far')):
            add(cog_layer(P, wh, wheel_frac), False)
    if arm_front:
        add_arm()
        add(P['hub'], True)
    if fly is not None and back is None:
        add(fly, False, True)
    return groups, mid


_COG = {}


def cog_layer(P, wh, frac):
    """the rebuilt painted cog (cog.py) in this wheel's place, turned on by frac of a MOVE loop (TEETH_PER_LOOP
    teeth): face-on squashed into the wheel's fitted ellipse (cw: which way it turns on screen), or edge-on (N) with
    its tread rolling up (moving away) and its hub to the outside"""
    Wd, Hh = P['size']
    deg = TEETH_PER_LOOP * 360.0 / cog.TEETH * frac
    out = np.zeros((Hh, Wd, 4), np.uint8)
    cx, cy, rx, ry = wh['cx'], wh['cy'], wh['rx'], wh['ry']
    if wh['kind'] == 'edge':
        tw = 2 * rx + 3
        h = int(round(2 * ry + 3))
        right = cx > Wd / 2.0
        key = ('e', round(tw), h, right, round(P['roll'] * deg, 3))
        if key not in _COG:
            # (no hub: ChatGPT's N view shows none, and a near wheel's would stick out over the far one)
            # (N: the tread rolls up, away from us; S: down, toward us)
            _COG[key] = cog.render_edge(P['roll'] * deg, int(round(tw)), h, hub_right=right, hub=False)
        img = _COG[key]
        x = int(round(cx - tw / 2.0)) if right else int(round(cx + tw / 2.0)) - img.shape[1]
        _paste(out, img, x, int(round(cy - h / 2.0)))
        return toned(P, wh, out)
    w, h = int(round(2 * rx)), int(round(2 * ry))
    key = ('f', w, h, round(deg * wh['cw'], 3))
    if key not in _COG:
        _COG[key] = cog.render_face(deg * wh['cw'], w, h)
    _paste(out, _COG[key], int(round(cx - w / 2.0)), int(round(cy - h / 2.0)))
    return toned(P, wh, out)


def toned(P, wh, layer):
    """the cog brought to the brightness of the wheel ChatGPT painted there (CODE SHADE: one factor per wheel, so a
    far wheel stays in the machine's shade); the factor is measured once, where the old paint and the cog overlap"""
    if 'tone' not in wh and 'tone_set' in wh:
        wh['tone'] = wh['tone_set']
    if 'tone' not in wh:
        old = wh['mask'] | wh.get('cutout', np.zeros_like(wh['mask']))
        both = old & (layer[..., 3] > 0)
        lum = lambda a: (a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11)
        if both.sum() > 30:
            wh['tone'] = float(np.clip(lum(P['W'][both].astype(float)).mean() / max(lum(layer[both].astype(float)).mean(), 1),
                                       0.5, 1.1))
        else:
            wh['tone'] = 1.0
    if abs(wh['tone'] - 1) > 0.01:
        layer = layer.copy()
        layer[..., :3] = np.clip(layer[..., :3] * wh['tone'], 0, 255).astype(np.uint8)
    return layer


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




for _r, _p in enumerate(PARTS):
    _p['roll'] = ROWS[_r].get('roll', -1)
    for _i, _wh in enumerate(_p['wheels']):
        if _wh['kind'] == 'edge':
            _wh['pitch'] = EDGE_PITCH
            _wh['far'] = _i >= 2              # (edge-on wheels are listed nearest first: two near, two far)
            if ROWS[_r]['arm'] == 'front':
                _wh['tone_set'] = ROWS[_r]['tones'][_i]     # (S: no old edge-on paint to measure: N's tones)
        _wh.setdefault('cw', 1)


def flat(groups, bob=0):
    """the groups composited at painted scale (for looking at), riding ones moved by bob sheet px"""
    H, W = groups[0][0].shape[:2]
    cv = np.zeros((H, W, 4), np.uint8)
    for img, rides, _ in groups:
        over(cv, place(img, (0, 0), (0, bob), np.eye(2)) if (rides and bob) else img)
    return cv


# ------------------------------------------------------------------ the two animations

T_REL = 112.0          # the payload leaves the cup at this arm angle (between frames 2 and 3)
FLY_SPEED = 58.0       # sheet px a frame, along its launch (which is LAUNCH deg up from the row's forward)
SPIN = -35.0           # and it tumbles (deg a frame)
# THROW: (arm angle, payload): 'cup' sits in the cup, 'drop' falls into it from above, a number = frames since
# release (it flies on its own)
THROW = [(T0, 'cup'), (T0 + 4, 'cup'), (134.0, 'cup'), (90.0, 0.8), (55.0, 1.7), (34.0, None), (46.0, None),
         (64.0, None), (91.0, None), (119.0, None), (147.0, None), (T0, 'drop')]
THROW_RELEASE = 3      # the first frame with the payload out of the cup
THROW_BOB = [0, 0, 0, 0, -1, 1, 0, 0, 0, 0, 0, 0]          # the machine jolts as the arm hits its stop (game px)
THROW_MS = [300, 160, 60, 50, 50, 70, 90, 110, 110, 110, 130, 260]   # the GIF's timing (the game's may differ)
MOVE_N = 8             # MOVE: the wheels' teeth 3 pitches round (the edge-on wheels' bars 3 bars on), the bolts a quarter turn
MOVE_BOB = [0, -1, -1, 0, 0, -1, -1, 0]      # the body's ride over the cogs (game px)


def payload_state(r, p):
    if p is None:
        return None
    if p == 'cup':
        return ('cup', 0)
    if p == 'drop':
        return ('cup', 26)
    # in flight, from where the cup was at release
    P = PARTS[r]
    _, mid = frame_mid(r, T_REL)
    d = math.cos(math.radians(LAUNCH)) * P['F'] + math.sin(math.radians(LAUNCH)) * np.array([0.0, -1.0])
    pos = mid + FLY_SPEED * p * d + np.array([0.0, 3.0 * p * p])
    return ('fly', (pos[0], pos[1], SPIN * p))


def frame_mid(r, T):
    """the cup's middle on screen at arm angle T (no drawing)"""
    P = PARTS[r]
    R = ROWS[r]
    v = arm_now(r, T)
    Jn = P['H'] + v
    pose = pose_for(r, T)
    if pose:
        return None, Jn + POSE[pose]['rim_off']
    turn = 0.0
    if R['arm'] == 'behind':
        turn = math.degrees(math.atan2(v[1], v[0]) - math.atan2(P['paint'][1], P['paint'][0]))
    if back_cup(r, T):
        return None, under_on(P, Jn, back_axis(r, T))[1]
    rcx, rcy, rrx, rry = P['rim']
    return None, Jn + rotm(turn) @ (np.array([rcx, rcy]) - P['J'])


def cropped(groups):
    """the layer groups cut to their boxes: [(rgba, x, y, rides)]"""
    out = []
    for img, rides, snap in groups:
        ys, xs = np.nonzero(img[..., 3])
        if len(ys):
            out.append((img[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy(), xs.min(), ys.min(), rides, snap))
    return out


def anim_frames(name, r):
    """[(cropped layer groups, bob game px, cup middle)] of one animation's row"""
    out = []
    if name == 'throw':
        for k, (T, p) in enumerate(THROW):
            g, mid = frame(r, T, 0.0, payload_state(r, p))
            out.append((cropped(g), THROW_BOB[k], mid))
    else:
        for i in range(MOVE_N):
            g, mid = frame(r, T0, i / float(MOVE_N), None, edge_frac=float(TEETH_PER_LOOP) * i / MOVE_N)
            out.append((cropped(g), MOVE_BOB[i], mid))
    return out


def anchor(r):
    """the unit's point in the sheet: under the middle of its wheels, on the ground (their lowest tips)"""
    if ROWS[r].get('anchor'):
        return ROWS[r]['anchor']          # (S: kept where the painted wheels put it, so the unit does not shift)
    ws = [w for w in ROWS[r]['wheels'] if w[4] in ('near', 'edge')]
    return (float(np.mean([w[0] for w in ws])), float(max(w[1] + w[3] for w in ws)))


def shrink(img, w, h):
    """premultiplied box-filter shrink with a hard alpha (tools/import_tier3.py)"""
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
    P = PARTS[r]
    ax, ay = anchor(r)
    ax -= P['win'][0]
    ay -= P['win'][1]
    ox, oy = int(round(ax - AX / GS)), int(round(ay - AY / GS))
    w, h = int(round(CW / GS)), int(round(CH / GS))
    out = np.zeros((CH, CW, 4), np.uint8)
    for img, gx, gy, rides, snap in groups:
        crop = np.zeros((h, w, 4), np.uint8)
        _paste(crop, img, gx - ox, gy - oy)
        sm = shrink(crop, CW, CH)
        if snap:
            sm = snap_key(sm)
        if rides and bob:
            sm = np.roll(sm, bob, axis=0)
            if bob < 0:
                sm[bob:] = 0
            else:
                sm[:bob] = 0
        over(out, sm)
    return out


def extents(frames):
    """how far any frame reaches from its row's anchor (sheet px): left, right, up, down"""
    L = Rr = U = D = 0.0
    for (name, r), fr in frames.items():
        ax, ay = anchor(r)
        ax -= PARTS[r]['win'][0]
        ay -= PARTS[r]['win'][1]
        for groups, bob, _ in fr:
            for img, gx, gy, rides, _ in groups:
                h, w = img.shape[:2]
                lift = (-bob / GS) if (rides and bob < 0) else 0.0
                L, Rr = max(L, ax - gx), max(Rr, gx + w - ax)
                U, D = max(U, ay - gy + lift), max(D, gy + h - ay)
    return L, Rr, U, D


def save(name, rows, cell, dur):
    CW, CH, AX, AY = cell
    n = len(rows[0])
    sheet = Image.new('RGB', (n * CW, 5 * CH), tuple(NAVY))
    for r in range(5):
        for c, img in enumerate(rows[r]):
            im = Image.fromarray(img, 'RGBA')
            sheet.paste(im, (c * CW, r * CH), im)
    sheet.save('art/redraws/catapult_%s.png' % name)
    g = []
    for c in range(n):
        o = Image.new('RGB', (5 * CW, CH), tuple(NAVY))
        for r in range(5):
            o.paste(sheet.crop((c * CW, r * CH, (c + 1) * CW, (r + 1) * CH)), (r * CW, 0))
        g.append(o.resize((o.width * 3, o.height * 3), Image.NEAREST))
    g[0].save('art/redraws/catapult_%s.gif' % name, save_all=True, append_images=g[1:], duration=dur, loop=0)


KEEP_CELL = (158, 141, 79, 139)


def main():
    frames = {(name, r): anim_frames(name, r) for name in ('throw', 'move') for r in range(5)}
    L, Rr, U, D = extents(frames)
    half = int(math.ceil(max(L, Rr) * GS)) + 1
    up, down = int(math.ceil(U * GS)) + 1, int(math.ceil(D * GS)) + 1
    # never smaller than the last pass's cell (158x141, anchor 79, 139): the box shrink samples from the anchor, so a new
    # cell size would resample every row (S, SE and E stay pixel for pixel as they were)
    half, up, down = max(half, KEEP_CELL[2]), max(up, KEEP_CELL[3]), max(down, KEEP_CELL[1] - KEEP_CELL[3])
    cell = (2 * half, up + down, half, up)
    print('cell %dx%d, anchor (%d, %d) (game px, GS %.3f)' % (cell + (GS,)))
    cups = {}
    for name, dur in (('throw', THROW_MS), ('move', 110)):
        rows = []
        for r in range(5):
            fr = frames[(name, r)]
            rows.append([to_cell(r, g, bob, cell) for g, bob, _ in fr])
            if name == 'throw':
                ax, ay = anchor(r)
                cups[DIRS[r]] = []
                for i, (g, bob, mid) in enumerate(fr):
                    x = (mid[0] + PARTS[r]['win'][0] - ax) * GS + cell[2]
                    y = (mid[1] + PARTS[r]['win'][1] - ay) * GS + cell[3] + bob     # (the cup rides the jolt)
                    cups[DIRS[r]].append([round(x, 1), round(y, 1)])
                st = payload_state(r, THROW[THROW_RELEASE + 1][1])
                cups[DIRS[r] + '_fly'] = [round((st[1][0] + PARTS[r]['win'][0] - ax) * GS + cell[2], 1),
                                          round((st[1][1] + PARTS[r]['win'][1] - ay) * GS + cell[3], 1)]
        save(name, rows, cell, dur)
    lines = ['{', ' "note": "cup: the cup\'s middle per THROW frame (cell px from the cell\'s top-left); <dir>_fly: the payload '
             'on the last frame it is painted (release_frame + 1), where the game\'s projectile takes over",',
             ' "cell": %s,' % json.dumps(list(cell)), ' "release_frame": %d,' % THROW_RELEASE, ' "cup": {']
    keys = list(cups)
    for i, k in enumerate(keys):
        lines.append('  "%s": %s%s' % (k, json.dumps(cups[k]), ',' if i < len(keys) - 1 else ''))
    lines += [' }', '}']
    open('art/redraws/catapult_cup.json', 'w').write('\n'.join(lines) + '\n')
    PAYLOAD_SRC.save('art/redraws/catapult_payload.png')
    print('ok')


if __name__ == '__main__' and len(sys.argv) == 1:
    main()


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'parts':
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for r in range(5):
        P = PARTS[r]
        tiles = [P['body'], P['beam'], P['cup'], P['cupfront'], P['hub']]
        for wh in P['wheels']:
            tiles.append(wh['img'])
        ims = []
        for t in tiles:
            im = Image.fromarray(t, 'RGBA')
            bb = im.getbbox() or (0, 0, 4, 4)
            im = im.crop(bb)
            ims.append(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
        W = sum(i.width for i in ims) + 10 * len(ims)
        H = max(i.height for i in ims)
        sheet = Image.new('RGB', (W, H), (40, 70, 40))
        x = 0
        for im in ims:
            sheet.paste(im, (x, 0), im)
            x += im.width + 10
        sheet.save('%s/parts_%s.png' % (out, DIRS[r]))
        print(DIRS[r], 'F', np.round(P['F'], 3), 'paint', P['paint'], 'pitches', [round(w['pitch'], 1) for w in P['wheels']])
    sys.exit(0)
