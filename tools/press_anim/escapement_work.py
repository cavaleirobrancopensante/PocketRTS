"""The Escapement's working loop: a real escapement's tick... tock... from the painted BUILT cell of
art/redraws/escapement.png (ChatGPT's own working cells wobble: not used).

The anchor (the pallet fork with its crutch) rocks on its arbor like a pendulum, and every time it swings through the
middle the escape wheel jumps forward half a tooth and stops. 24 frames, 4 a beat, 6 beats a loop: the anchor swings
twice each way (tick, tock), the wheel turns 90 degrees, where it looks the same again.

How the frames are made (everything is the painting's own paint; tracked in docs/art_style_inconsistency.md):
- The cell keyed off its navy as before, placed on the 352 x 419 canvas of art/clockwork/gear/escapement_*.png; the
  navy-dark paint inside the building that the key had punched out (the drum, specks on the roof) is kept.
- The wheel's face is turned to the right, so the wheel is an ellipse: every turn is made in the face's plane (the
  ellipse turned into a circle, turned, turned back), and the hub, which stands out of the face, keeps its place (the
  spokes rise from the rim to the hub, a dished wheel).
- The painted wheel is uneven (13 teeth at odd spacings, 8 spokes at odd angles), which can't tick in a loop. It is
  rebuilt from its own pieces: 12 teeth, each the nearest painted tooth set on an even slot (with its side face and
  light), and 8 spokes, each the painted spoke at 3 o'clock, under a fixed light fitted to the painted spokes (bright
  at the right and the bottom, shaded at the upper left). The rim and the hub's nut stay as painted (a turning ring
  and nut look the same). Turning by a full tooth shows the teeth on their home slots again; 45 degrees, the spokes.
- What the moving parts hid is filled from the painting round them: along the circle (the drum's dark rings, the deck,
  the shadow inside the wheel), and a smooth fill behind the anchor.
- Every moving part is sampled 8 x 8 times per pixel through the inverse turn (its pixels as little squares: no
  smearing), with a crisp edge, and snapped back to its own painted colours.

Writes art/clockwork/gear/escapement_built.png (the rest pose: wheel and anchor at rest) and escapement_work_0..23.png,
then a preview art/redraws/escapement_work.png (6 x 4 sheet) and .gif. tools/gear_art/import_buildings.py escapement
makes the game's sprites from them (both in tools/rebuild_art.sh). Frame time: Defs.GEAR "escapement_dt".
  python3 tools/press_anim/escapement_work.py"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.spatial import cKDTree

SHEET = 'art/redraws/escapement.png'
OUT = 'art/clockwork/gear/escapement_'
W, H = 352, 419                 # the canvas of art/clockwork/gear/escapement_*.png
OFF = (19, 35)                  # canvas pixel (x, y) = the built cell's pixel (x + 19, y + 35)
FRAMES = 24                     # 6 beats of 4 frames
BEAT = 4
STEP = 15.0                     # degrees the wheel jumps a beat: half a tooth of 12
ROCK = 7.0                      # degrees the anchor swings each way

# ---------------------------------------------------------------- the painted cell on the canvas
sheet = np.array(Image.open(SHEET).convert('RGB')).astype(int)
cell = sheet[0:512, 0:384]
key = np.abs(cell - np.array([0, 22, 48])).sum(2) >= 40          # the navy backdrop keyed out
lab, n = ndi.label(key)
sz = ndi.sum(key, lab, range(1, n + 1))
key &= np.isin(lab, [k + 1 for k, z in enumerate(sz) if z >= 60])
RGB = cell[OFF[1]:OFF[1] + H, OFF[0]:OFF[0] + W].astype(float)
SOLID = ndi.binary_fill_holes(key[OFF[1]:OFF[1] + H, OFF[0]:OFF[0] + W])   # (the navy paint inside stays)

r, g, b = RGB[..., 0], RGB[..., 1], RGB[..., 2]
LUM = 0.3 * r + 0.59 * g + 0.11 * b
WARM = ((r - b) > 18) & (r >= g - 4) & (LUM > 22)          # brass, bright or in shade
SATBRASS = ((r - b) > 70) & (r > 110)
BLUE = b > r + 6                                         # the drum
DARK = LUM < 34                                          # outlines, deep shade
RED = (r > 120) & (g < 90) & (b < 90)
REDISH = (r > 60) & (r > 1.8 * g) & (r > 1.8 * b)
YY, XX = np.mgrid[0:H, 0:W].astype(float)

# ---------------------------------------------------------------- geometry (measured on the canvas)
# Plane coordinates u = AI (x - CW): rho = |u| = 1 on the rim's outer edge (an ellipse fitted to it). The hub stands out
# of the face and is drawn 6 px right of the rim's centre: a wheel point at plane radius rho is drawn shifted by
# w(rho) * (HUB - CW), 1 at the hub, 0 at the rim.
CW = np.array([222.6, 263.2])
HUB = np.array([228.5, 263.3])
PHI = np.radians(-60.4)
_R = np.array([[np.cos(PHI), -np.sin(PHI)], [np.sin(PHI), np.cos(PHI)]])
A = _R @ np.diag([57.9, 48.2]) @ _R.T
AI = np.linalg.inv(A)
RIM_IN = 0.845                  # the rim's inner edge
RHO_H = 0.20                    # where the spokes meet the hub
PIVOT = np.array([218.8, 158.6])  # the anchor's arbor


def rot(deg):
    t = np.radians(deg)
    return np.array([[np.cos(t), -np.sin(t)], [np.sin(t), np.cos(t)]])


def dish_w(rho):
    return np.clip((RIM_IN - rho) / (RIM_IN - RHO_H), 0.0, 1.0)


def to_plane(x, y, dish=False):
    d = np.stack([x - CW[0], y - CW[1]], -1)
    u = d @ AI.T
    if dish:
        for _ in range(6):
            u = (d - dish_w(np.hypot(u[..., 0], u[..., 1]))[..., None] * (HUB - CW)) @ AI.T
    return u


def from_plane(u, dish=False):
    x = u @ A.T + CW
    if dish:
        x = x + dish_w(np.hypot(u[..., 0], u[..., 1]))[..., None] * (HUB - CW)
    return x


U0 = to_plane(XX, YY)
RHO = np.hypot(U0[..., 0], U0[..., 1])
PSI = np.degrees(np.arctan2(U0[..., 1], U0[..., 0])) % 360          # 0 right, 90 down (clockwise)
UD = to_plane(XX, YY, dish=True)
RHOD = np.hypot(UD[..., 0], UD[..., 1])
PSID = np.degrees(np.arctan2(UD[..., 1], UD[..., 0])) % 360


def poly(pts):
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=1)
    return np.array(im).astype(bool)


# ---------------------------------------------------------------- the parts
HUBM = ((XX - 228.6) / 11.2) ** 2 + ((YY - 263.4) / 13.0) ** 2 <= 1.0          # the hub's nut (stays)
AXLE = (((XX - 213.0) / 13.0) ** 2 + ((YY - 263.0) / 12.5) ** 2 <= 1.0) & ~HUBM  # its barrel going back (stays)

# the anchor: the nut on its arbor, the two arms with their red pallets, the crutch hanging from the arbor with its
# small nut at the end (ChatGPT's own working cells rock all of it together)
ANCHOR_POLYS = {
    'left': [[204, 149], [196, 151], [185, 155], [172, 162], [160, 170], [152, 180], [147, 190], [146, 198], [146, 208],
             [149, 217], [166, 219], [178, 218], [180, 210], [178, 204], [186, 198], [196, 190], [204, 182], [211, 177], [213, 165]],
    'right': [[229, 146], [240, 148], [252, 153], [264, 160], [272, 166], [278, 171], [285, 177], [288, 186], [287, 193],
              [282, 198], [279, 206], [272, 208], [258, 206], [255, 196], [262, 188], [258, 182], [248, 176], [238, 172], [230, 172]],
    'bar': [[210.5, 172], [231.5, 172], [231.5, 231], [210.5, 231]],
    'nut': [[219, 140], [230, 143], [235, 152], [236, 163], [232, 173], [222, 177], [210, 175], [203, 166], [202, 155], [208, 145]],
    'small': [[215, 229], [237, 229], [238, 246], [234, 253], [224, 254], [215, 250]],
}
_nut = poly(ANCHOR_POLYS['nut']) & (YY >= 142)
_small = poly(ANCHOR_POLYS['small']) & ~HUBM
_arms = poly(ANCHOR_POLYS['left']) | poly(ANCHOR_POLYS['right'])
_bar = poly(ANCHOR_POLYS['bar'])
_core = ((_arms | _bar) & ~BLUE & (LUM >= 34) & ~(SATBRASS & ((YY > 195) | _bar))) | ((_arms | _bar) & (RED | REDISH)) \
    | ((_nut | _small) & ~BLUE & (LUM >= 34))
lab, n = ndi.label(_core)
_core &= (ndi.sum(_core, lab, range(n + 1)) >= 25)[lab]
_zone = _arms | _bar | _nut | _small
ANCH = _core | (ndi.binary_dilation(_core, iterations=1) & _zone & DARK)
ANCH = ndi.binary_fill_holes(ndi.binary_closing(ANCH, iterations=1) & _zone)
# (its outline and glints where it stands against the backdrop: the arms' tops, the right pallet; and the specks of
# outline that would be left alone on the backdrop without it)
_rim3 = ndi.distance_transform_edt(SOLID) <= 3.0
ANCH |= ndi.binary_dilation(ANCH, iterations=2) & SOLID & _rim3 & (YY < 200)
lab, n = ndi.label(SOLID & ~ANCH)
ANCH |= (ndi.sum(SOLID & ~ANCH, lab, range(n + 1)) < 40)[lab] & (SOLID & ~ANCH) & _rim3 & ndi.binary_dilation(ANCH, iterations=3)
# the little pin on top of the arbor stays (it holds the arbor)
PIN = poly([[209, 129], [224, 129], [224, 144], [209, 144]]) & ~BLUE & (LUM > 40) & ~ANCH

# the wheel's teeth (bright faces, the dark side faces the turned wheel shows on its left, outlines, glints)
_ann = (RHO > 0.975) & (RHO < 1.32)
_tm = WARM & _ann & ~ANCH
lab, n = ndi.label(_tm | (WARM & (RHO > 0.9) & (RHO <= 0.975)))
_rl = np.unique(lab[(RHO > 0.93) & (RHO < 0.975) & WARM])
_tm &= np.isin(lab, _rl[_rl > 0])
TEETH = (_tm | (ndi.binary_dilation(_tm, iterations=1) & (DARK | WARM) & _ann & ~BLUE)) & ~ANCH
TEETH &= ~(poly([[272, 261], [290, 261], [290, 280], [272, 280]]) & (RHO > 1.03))   # (a bracket behind, not a tooth)
TEETH |= ndi.binary_dilation(TEETH, iterations=1) & _ann & (LUM > 150) & ~BLUE & ~SATBRASS & ~ANCH & (RHO < 1.26)

# the spokes inside the rim (minus the hub, its barrel and the crutch in front)
_sp = WARM & (RHO < RIM_IN - 0.02) & ~HUBM & ~AXLE & ~ANCH
SPOKES = (_sp | (ndi.binary_dilation(_sp, iterations=1) & (RHO < RIM_IN) & ~HUBM & ~AXLE & (DARK | WARM))) & ~ANCH


# ---------------------------------------------------------------- what the moving parts hid
def ring_fill(img, known, need, rho0, rho1, n_psi=1440, d_rho=0.004):
    """Fill `need` pixels ring by ring round the wheel's centre (same rho), between the nearest `known` paint on either
    side along the circle: the drum's rings, the deck and the rim's edges carry on."""
    out = img.copy()
    rhos = np.arange(rho0, rho1 + d_rho, d_rho)
    psis = np.arange(n_psi) * 360.0 / n_psi
    T, P = np.meshgrid(np.radians(psis), rhos)
    pos = from_plane(np.stack([P * np.cos(T), P * np.sin(T)], -1))
    ix = np.clip(np.round(pos[..., 0]).astype(int), 0, W - 1)
    iy = np.clip(np.round(pos[..., 1]).astype(int), 0, H - 1)
    K = known[iy, ix]
    pol = img[iy, ix].astype(float)
    filled = np.full_like(pol, np.nan)
    for j in range(len(rhos)):
        k = np.flatnonzero(K[j])
        if len(k):
            for c in range(pol.shape[2]):
                filled[j, :, c] = np.interp(psis, psis[k], pol[j, k, c], period=360)
    ys, xs = np.nonzero(need & (RHO >= rho0) & (RHO <= rho1))
    rr = (RHO[ys, xs] - rho0) / d_rho
    pp = PSI[ys, xs] / (360.0 / n_psi)
    j0 = np.clip(np.floor(rr).astype(int), 0, len(rhos) - 2)
    fj = np.clip(rr - j0, 0, 1)[:, None]
    p0 = np.floor(pp).astype(int) % n_psi
    p1 = (p0 + 1) % n_psi
    fp = (pp - np.floor(pp))[:, None]
    v = (filled[j0, p0] * (1 - fj) * (1 - fp) + filled[j0, p1] * (1 - fj) * fp
         + filled[j0 + 1, p0] * fj * (1 - fp) + filled[j0 + 1, p1] * fj * fp)
    ok = ~np.isnan(v).any(1)
    out[ys[ok], xs[ok]] = v[ok]
    done = np.zeros((H, W), bool)
    done[ys[ok], xs[ok]] = True
    return out, done


def soft_fill(img, known, need):
    """a smooth average of the known paint round them (normalised Gaussian, the smallest scale that reaches paint)"""
    out = img.copy()
    left = need.copy()
    kf = known.astype(float)
    for s in (1.5, 3.0, 5.0, 8.0, 13.0, 21.0):
        wsum = ndi.gaussian_filter(kf, s)
        ok = left & (wsum > 0.08)
        if ok.any():
            for c in range(img.shape[2]):
                out[..., c][ok] = ndi.gaussian_filter(img[..., c] * kf, s)[ok] / wsum[ok]
            left &= ~ok
        if not left.any():
            break
    return out


BG = RGB.copy()
_known = SOLID & ~(ANCH | TEETH | SPOKES)
BG, _d1 = ring_fill(BG, _known, TEETH | (ANCH & (RHO > 0.95)), 0.95, 1.33)                     # behind the teeth
BG, _d2 = ring_fill(BG, _known, SPOKES | (ANCH & (RHO < RIM_IN + 0.03)), 0.0, RIM_IN + 0.03)   # behind the spokes
_known2 = _known | _d1 | _d2
BG = soft_fill(BG, _known2, SOLID & ~_known2)                                                   # behind the anchor
# where the anchor stood against the backdrop (its arms' tops, the right pallet) the backdrop shows as it moves: its
# paint within 7 px of the backdrop counts as backdrop, the rest has the building behind it
BG_ALPHA = SOLID & ~(ANCH & (ndi.distance_transform_edt(SOLID) <= 7.0))
BG_ALPHA = ndi.binary_opening(BG_ALPHA, iterations=1) | (SOLID & ~ANCH)
# the iron post below the right pallet goes on up behind it (the pallet rests against it): its clean rows just under the
# pallet (206..217, where no tooth crosses it) repeated upward
_py, _px = np.nonzero(poly([[270, 187], [284, 187], [284, 206], [270, 206]]))
_sy = 206 + (_py - 187) % 12
_ok = SOLID[_sy, _px] & ~SATBRASS[_sy, _px]
BG[_py[_ok], _px[_ok]] = RGB[_sy[_ok], _px[_ok]]
BG_ALPHA[_py[_ok], _px[_ok]] = True

# the rim (stays): the painted ring, its inner edge where painted spokes met it and its outer edge under the painted
# teeth carried on along the circle from the clean stretches; over the turning spokes, under the turning teeth
_ai = (PSI * 4).astype(int) % 1440
_spoke_ang = np.zeros(1440, bool)
_tooth_ang = np.zeros(1440, bool)
_spoke_ang[np.unique(_ai[SPOKES & (RHO > 0.70) & (RHO < 0.82)])] = True
_tooth_ang[np.unique(_ai[TEETH & (RHO > 1.01) & (RHO < 1.12)])] = True
_spoke_ang = ndi.binary_dilation(_spoke_ang, iterations=8)
_tooth_ang = ndi.binary_dilation(_tooth_ang, iterations=4)
_band = (RHO > 0.80) & (RHO < 1.035)
_unclean = ANCH | (_spoke_ang[_ai] & (RHO < 0.885)) | (_tooth_ang[_ai] & (RHO > 0.955))
_unclean |= ndi.binary_dilation(BLUE & (RHO > 0.86) & (RHO < 0.99), iterations=1)   # (a rivet would stand still on it)
RIMC, _ = ring_fill(RGB, _band & ~_unclean & SOLID, _band & _unclean, 0.80, 1.035, d_rho=0.003)
_rr, _rg, _rb = RIMC[..., 0], RIMC[..., 1], RIMC[..., 2]
RIM_A = _band & ((_rr - _rb) > 18) & (0.3 * _rr + 0.59 * _rg + 0.11 * _rb > 30) & (RHO > 0.81) & (RHO < 1.02)
RIM_A = ndi.binary_closing(RIM_A, iterations=1) & _band

# ---------------------------------------------------------------- drawing the moving parts
SS = 8                          # samples per pixel side
_OFS = (np.arange(SS) + 0.5) / SS - 0.5


class Sprite:
    """a part cut from the painting, sampled as little squares and snapped back to its own colours"""
    def __init__(self, mask, palette_mask=None):
        self.mask = mask
        self.pre = np.zeros((H * W, 4), np.float32)
        self.pre[:, :3] = (RGB * mask[..., None]).reshape(-1, 3)
        self.pre[:, 3] = mask.reshape(-1)
        ys, xs = np.nonzero(mask)
        self.px, self.py = xs.astype(float), ys.astype(float)
        self.palette = np.unique(RGB[mask if palette_mask is None else palette_mask].astype(np.float32), axis=0)
        self.tree = cKDTree(self.palette)

    def snap(self, col):
        return self.palette[self.tree.query(col)[1]]

    def sample(self, sx, sy):
        """sx, sy (N, SS, SS) source positions -> colour (N, 3) and coverage (N) of N output pixels"""
        ix = np.round(sx).astype(np.int32)
        iy = np.round(sy).astype(np.int32)
        ok = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
        s = (self.pre[np.where(ok, iy * W + ix, 0)] * ok[..., None]).sum((1, 2))
        return s[:, :3] / np.maximum(s[:, 3], 1e-6)[:, None], s[:, 3] / (SS * SS)


def out_pixels(px, py, pad=2):
    """the output pixels round forward-turned source pixels"""
    m = np.zeros((H, W), bool)
    m[np.clip(np.round(py).astype(int), 0, H - 1), np.clip(np.round(px).astype(int), 0, W - 1)] = True
    ys, xs = np.nonzero(ndi.binary_dilation(m, iterations=pad))
    return xs, ys


def subsamples(xs, ys):
    return (xs[:, None, None] + _OFS[None, None, :] + np.zeros((1, SS, 1)),
            ys[:, None, None] + _OFS[None, :, None] + np.zeros((1, 1, SS)))


def plane_turn(centre, deg):
    """the image map of a clockwise turn of `deg` degrees in the face's plane round `centre`"""
    M = A @ rot(deg) @ AI

    def f(X, Y):
        dx, dy = X - centre[0], Y - centre[1]
        return centre[0] + M[0, 0] * dx + M[0, 1] * dy, centre[1] + M[1, 0] * dx + M[1, 1] * dy
    return f


class Layer:
    def __init__(self):
        self.col = np.zeros((H, W, 3), np.float32)
        self.cov = np.zeros((H, W), np.float32)

    def add(self, xs, ys, col, cov):
        take = cov > self.cov[ys, xs]
        self.col[ys[take], xs[take]] = col[take]
        self.cov[ys[take], xs[take]] = cov[take]


def draw_turned(L, spr, centre, deg):
    xs, ys = out_pixels(*plane_turn(centre, deg)(spr.px, spr.py))
    col, cov = spr.sample(*plane_turn(centre, -deg)(*subsamples(xs.astype(float), ys.astype(float))))
    L.add(xs, ys, spr.snap(col), cov)


# the teeth: each painted tooth (with its side face, outline and the strip of rim it stands on), cut by angle round
# the wheel; 12 even slots, each taking the nearest painted tooth (the one half behind the crutch is not used)
TOOTH_CENTRES = [29.5, 58.0, 87.5, 116.5, 139.5, 162.0, 188.0, 212.5, 237.0, 276.5, 297.0, 328.5, 358.0]
TOOTH_HIDDEN = (276.5,)
N_TEETH = 12
PITCH = 360.0 / N_TEETH
_dps = ((PSI[..., None] - np.array(TOOTH_CENTRES)[None, None, :] + 180) % 360) - 180
_tid = np.argmin(np.abs(_dps), -1)
TEETH_SRC = []
for k, c in enumerate(TOOTH_CENTRES):
    if c in TOOTH_HIDDEN:
        continue
    d = _dps[..., k]
    m = TEETH & (RHO > 0.975) & (_tid == k) & (np.abs(d) <= 13.0)
    lo, hi = np.percentile(d[m & (RHO > 1.0) & (RHO < 1.05) & WARM], [5, 95])
    TEETH_SRC.append((c, Sprite(m | ((RHO > 0.95) & (RHO <= 1.0) & (d >= lo) & (d <= hi) & WARM))))


def _fit(p0):
    s = (p0 + PITCH * np.arange(N_TEETH)) % 360
    pick = [int(np.argmin([abs(((a - t[0] + 180) % 360) - 180) for t in TEETH_SRC])) for a in s]
    return sum((((a - TEETH_SRC[k][0] + 180) % 360) - 180) ** 2 for a, k in zip(s, pick)), s, pick


_, SLOTS, SLOT_SRC = min((_fit(p0) for p0 in np.arange(0, PITCH, 0.25)), key=lambda t: t[0])

# the spokes: the painted spoke at 3 o'clock, eight times round the hub, under a fixed light: the painted spokes'
# brightness fitted round the wheel (a + b cos + c sin of the angle), relative to that spoke's place
_sel = SPOKES & (RHOD > 0.3) & (RHOD < 0.8) & ((PSID > 330) | (PSID < 25))
_a = np.radians(PSID[_sel])
SPOKE_ANG = np.degrees(np.arctan2(np.sin(_a).mean(), np.cos(_a).mean())) % 360
_t = np.radians(SPOKE_ANG)
_strip = (np.abs(-UD[..., 0] * np.sin(_t) + UD[..., 1] * np.cos(_t)) < 0.12) \
    & (UD[..., 0] * np.cos(_t) + UD[..., 1] * np.sin(_t) > 0.17) & (UD[..., 0] * np.cos(_t) + UD[..., 1] * np.sin(_t) < 0.93)
SPOKE = Sprite(ndi.binary_fill_holes(_strip & (SPOKES | (WARM & (RHOD > 0.80)) | (HUBM & WARM))))
SPOKE_PAL = Sprite(SPOKE.mask, SPOKES | SPOKE.mask)          # (snaps to all the painted spokes' colours, shaded ones too)
_SPOKE_U = to_plane(SPOKE.px, SPOKE.py, dish=True)
N_SPOKES = 8
_lit = SPOKES & WARM & (RHOD > 0.35) & (RHOD < 0.78)
_an = np.radians(PSID[_lit])
LIGHT = np.linalg.lstsq(np.stack([np.ones_like(_an), np.cos(_an), np.sin(_an)], 1), LUM[_lit], rcond=None)[0]


def spoke_light(psi_deg):
    t = np.radians(psi_deg)
    return np.clip((LIGHT[0] + LIGHT[1] * np.cos(t) + LIGHT[2] * np.sin(t))
                   / (LIGHT[0] + LIGHT[1] * np.cos(_t) + LIGHT[2] * np.sin(_t)), 0.4, 1.1)


ANCHOR = Sprite(ANCH)
_cache = {}


def teeth_layer(theta):
    if ('t', theta) not in _cache:
        L = Layer()
        for s, k in zip(SLOTS, SLOT_SRC):
            draw_turned(L, TEETH_SRC[k][1], CW, s - TEETH_SRC[k][0] + theta)
        _cache[('t', theta)] = L
    return _cache[('t', theta)]


def spokes_layer(theta):
    if ('s', theta) not in _cache:
        L = Layer()
        for k in range(N_SPOKES):
            deg = 360.0 / N_SPOKES * k + theta
            f = from_plane(_SPOKE_U @ rot(deg).T, dish=True)
            xs, ys = out_pixels(f[:, 0], f[:, 1])
            X, Y = subsamples(xs.astype(float), ys.astype(float))
            p = from_plane(to_plane(X, Y, dish=True) @ rot(-deg).T, dish=True)
            col, cov = SPOKE.sample(p[..., 0], p[..., 1])
            L.add(xs, ys, SPOKE_PAL.snap(col * spoke_light(PSID[ys, xs])[:, None]), cov)
        _cache[('s', theta)] = L
    return _cache[('s', theta)]


def anchor_layer(deg):
    if ('a', deg) not in _cache:
        L = Layer()
        draw_turned(L, ANCHOR, PIVOT, deg)
        _cache[('a', deg)] = L
    return _cache[('a', deg)]


def put(img, opa, L):
    m = L.cov >= 0.5                    # a crisp edge, like the painting's
    img[m] = L.col[m]
    opa |= m


def compose(theta, rock):
    """a frame: the wheel turned `theta` degrees clockwise, the anchor rocked `rock` degrees clockwise"""
    img = BG.copy()
    opa = BG_ALPHA.copy()
    put(img, opa, spokes_layer(round(theta % (360.0 / N_SPOKES), 4)))
    img[RIM_A] = RIMC[RIM_A]
    img[HUBM] = RGB[HUBM]
    put(img, opa, teeth_layer(round(theta % PITCH, 4)))
    put(img, opa, anchor_layer(round(rock, 4)))
    img[PIN] = RGB[PIN]
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.clip(np.round(img), 0, 255).astype(np.uint8)
    out[..., 3] = opa * 255
    out[~opa, :3] = 0
    return Image.fromarray(out, 'RGBA')


def timing(f):
    """frame f: the anchor swings like a pendulum (8 frames a swing there and back); as it passes the middle (frames
    2 and 6 of the 8) the wheel jumps forward half a tooth and stops"""
    return STEP * ((f + BEAT // 2) // BEAT), ROCK * np.cos(2 * np.pi * f / (2 * BEAT))


if __name__ == '__main__':
    compose(0.0, 0.0).save(OUT + 'built.png')
    frames = [compose(*timing(f)) for f in range(FRAMES)]
    for i, fr in enumerate(frames):
        fr.save(OUT + 'work_%d.png' % i)
    # preview: the building on the painting's navy, a 6 x 4 sheet and a gif at the game's frame time
    box = (0, 50, W, H)
    navy = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]), (0, 22, 48, 255))
    pv = []
    for fr in frames:
        c = navy.copy()
        c.alpha_composite(fr.crop(box))
        pv.append(c.convert('RGB'))
    cw, ch = pv[0].size
    s = Image.new('RGB', (6 * cw, 4 * ch))
    for i, c in enumerate(pv):
        s.paste(c, ((i % 6) * cw, (i // 6) * ch))
    s.save('art/redraws/escapement_work.png')
    pv[0].save('art/redraws/escapement_work.gif', save_all=True, append_images=pv[1:], duration=125, loop=0)
    print('escapement: %d frames, %d tooth slots from painted teeth at %s' % (
        FRAMES, N_TEETH, [TEETH_SRC[k][0] for k in SLOT_SRC]))
