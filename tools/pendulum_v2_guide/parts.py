"""Pendulum v2 (two arms, nothing between the legs): the painted parts cut out of ChatGPT's direction sheet
art/redraws/pendulum_v2_dirs.png (5 rows S, SE, E, NE, N; column 1 the robot standing with its arms hanging, column 2
one arm alone), and the rig that moves them. Used by anim.py (idle, walk, attack) and death.py.

THE CUT, per facing:
- the ARMS: each painted arm is cut out of the robot along a hand-set polygon (from just under its shoulder hub down
  round the weight and the blade; where a blade's horn touches a knee the polygon runs along the gap and steel pixels
  are let in). An arm is split into layers that move separately: the ROD (from the hub down to the weight; extended up
  under the hub to the pivot), the SLEEVE + CLAMP (the thick rod over the weight and the brass bracket under it), the
  BALL (the weight: it never turns or squashes, a sphere looks the same from every side; its strip hidden behind the
  sleeve is filled across from its own paint, row by row) and the BLADE (behind the ball).
- the SIDE VIEW (E): ChatGPT hung the painted arm from the front corner under the clock, but every other view hangs
  the arms from the shoulder hubs, and the big round disc on the side panel IS the near shoulder hub seen face on: so
  there the arm is cut off (the brass knuckle it hung from goes too, the case's front edge filled from the case) and
  re-hung from that disc (its thin rod stretched along its length to reach). The far arm, hidden behind the body on the
  sheet, is a darker copy hung from behind the body.
- the HUB (the shoulder's brass drum or disc) stays on the body and is drawn again over a front arm's rod, so the rod
  always comes out from under it.
- the LEGS are cut like the old Pendulum's (tools/pendulum_guide/walk.py, same design): thigh (hip ball to knee),
  shin (knee ball and the red skirt), foot (the brass dome and sole), the hip ball riding with the body; the side
  view's far leg is a darker copy behind the near one.
- the lone arms in column 2 are drawn ~1.15x bigger than the arms on the robot and are only used whole, for the arms
  that snap off in the death guide (death.py).

THE ARM SWING (arm_layers): an arm turns about its shoulder's left-right axis (theta: 0 hanging, + forward) and can
turn in towards the middle (yaw, the attack's follow-through). The 3D swing is projected per facing (AZ: which way the
robot faces on screen; K: how much "towards the camera" shows as "down" on screen): seen from the side the swing is in
the picture plane; seen from the front or back it is foreshortened (the rod shortens, the head comes towards us,
lower and bigger, or goes away, higher, smaller and darker); the 3/4 views mix the two. The depth also decides the
drawing order (an arm swung back goes behind the legs and the body).

  python3 tools/pendulum_v2_guide/parts.py [DIR]    writes a preview of the cut parts (art/redraws/pendulum_v2_parts.png)
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SHEET = 'art/redraws/pendulum_v2_dirs.png'
A = np.array(Image.open(SHEET).convert('RGB')).astype(int)
BG = np.array([1, 24, 53])          # the sheet's navy
NAVY = (0, 22, 48)                  # the guides' background (as the old Pendulum's sheets)
DIRS = ['s', 'se', 'e', 'ne', 'n']
PAD = 160                           # room round a row's window for parts that swing out
GS = 0.28                           # game px per sheet px (the old Pendulum: 82 px tall in game)

# ------------------------------------------------------------------------------------------------ the sheet's rows
# per row (sheet px): the window, the case's centre across (the unit's anchor), and per arm: the screen side, which
# of the robot's arms it is, the pivot (shoulder hub centre), the hub ellipse (cx, cy, rx, ry: redrawn over a front
# arm's rod), the ball (cx, cy, r), the clamp (centre along the arm, half length, half width), the cut polygon
ROWS = [
    dict(box=(198, 6, 434, 308), mid=318.5, arms=[
        dict(side='L', robot='right', pivot=(266, 96), hub=(266, 96, 13, 19), ball=(242.5, 199.5, 19.5),
             clamp=(236.5, 225.5, 6.5, 10.0),
             poly=[(255, 112), (281, 112), (279, 126), (270, 150), (265, 170), (266, 200), (264, 222), (262, 232),
                   (262, 254), (204, 254), (204, 200), (222, 180), (236, 160), (250, 125)]),
        dict(side='R', robot='left', pivot=(371, 96), hub=(371, 96, 13, 19), ball=(390.0, 200.0, 19.0),
             clamp=(396.5, 226.0, 6.5, 10.0),
             poly=[(357, 112), (384, 112), (392, 125), (402, 160), (412, 178), (426, 200), (426, 254), (367, 254),
                   (367, 214), (370, 190), (366, 160), (361, 126)])]),
    dict(box=(203, 302, 422, 582), mid=326.0, arms=[
        dict(side='L', robot='right', pivot=(275, 383), hub=(276, 384, 16, 17), ball=(250.0, 484.0, 18.5),
             clamp=(246.0, 505.0, 6.0, 9.5),
             poly=[(259, 398), (284, 398), (281, 425), (274, 445), (271, 462), (271, 505), (268, 512), (268, 537),
                   (214, 537), (214, 488), (222, 465), (240, 440), (253, 410)]),
        dict(side='R', robot='left', pivot=(362, 381), hub=(362, 382, 9, 18), ball=(379.0, 484.0, 17.5),
             clamp=(389.0, 506.0, 6.0, 9.5),
             poly=[(357, 399), (373, 399), (385, 430), (398, 458), (403, 468), (414, 488), (414, 534), (368, 534),
                   (366, 506), (360, 502), (359, 470), (364, 452), (357, 420)])]),
    dict(box=(248, 574, 382, 870), mid=311.0, arms=[
        dict(side='N', robot='right', pivot=(305, 645), hub=(305.5, 645.5, 17, 17), ball=(339.5, 756.0, 17.5),
             clamp=(344.0, 777.0, 6.0, 9.0), drop_above=693, rehang=True,
             poly=[(328, 664), (343, 664), (342, 700), (345, 736), (358, 738), (368, 752), (372, 802), (320, 802),
                   (320, 762), (321, 740), (328, 736), (328, 700)])]),
    dict(box=(203, 859, 426, 1148), mid=318.0, arms=[
        dict(side='L', robot='left', pivot=(266, 938), hub=(266, 938, 15, 19), ball=(250.5, 1038.0, 18.0),
             clamp=(244.0, 1056.0, 6.0, 9.5),
             poly=[(253, 956), (281, 956), (278, 975), (271, 1005), (271, 1056), (266, 1060), (264, 1068),
                   (264, 1086), (214, 1086), (214, 1040), (225, 1012), (240, 990), (250, 970)]),
        dict(side='R', robot='right', pivot=(360, 937), hub=(360, 938, 15, 19), ball=(384.0, 1038.0, 18.5),
             clamp=(390.0, 1061.0, 6.0, 9.5),
             poly=[(349, 957), (376, 957), (386, 980), (398, 1008), (408, 1025), (414, 1040), (414, 1086), (368, 1086),
                   (367, 1062), (364, 1058), (364, 1020), (360, 1000), (356, 985)])]),
    dict(box=(198, 1152, 428, 1458), mid=315.0, arms=[
        dict(side='L', robot='left', pivot=(262, 1243), hub=(262, 1244, 14, 20), ball=(238.0, 1344.0, 19.0),
             clamp=(237.0, 1369.5, 6.0, 10.0),
             poly=[(249, 1264), (277, 1264), (274, 1280), (265, 1310), (262, 1330), (262, 1360), (260, 1368),
                   (260, 1396), (208, 1396), (208, 1345), (220, 1320), (238, 1295), (247, 1275)]),
        dict(side='R', robot='right', pivot=(360, 1243), hub=(360, 1244, 14, 20), ball=(385.5, 1344.0, 18.5),
             clamp=(393.0, 1369.5, 6.0, 10.0),
             poly=[(347, 1264), (373, 1264), (382, 1290), (395, 1316), (412, 1325), (422, 1350), (422, 1396),
                   (368, 1396), (366, 1368), (360, 1365), (363, 1330), (366, 1300), (355, 1280)])]),
]
# the lone arms (column 2): window, pivot (hub centre), ball (cx, cy, r)
LONE = [dict(box=(640, 74, 735, 291), pivot=(693, 109), ball=(688, 227, 22)),
        dict(box=(645, 337, 733, 564), pivot=(694, 381), ball=(687, 496, 21)),
        dict(box=(646, 609, 720, 831), pivot=(701, 652), ball=(688, 766, 20)),
        dict(box=(640, 882, 721, 1111), pivot=(686, 925), ball=(688, 1043, 21)),
        dict(box=(640, 1196, 731, 1439), pivot=(693, 1238), ball=(689, 1373, 22))]

# ------------------------------------------------------------------------------------------------ the swing's 3D
AZ = [0.0, 14.0, 90.0, 166.0, 180.0]   # which way the robot faces: 0 towards us, 90 right, 180 away (degrees;
                                       # the painted 3/4 views are turned only ~20 deg: their legs stand side by side)
K = 0.25                               # screen down per px towards the camera (the camera's tilt)
SHOULDER = 52.0                        # half the shoulder width (px): how far the hubs are out from the middle
E_REST = 18.0                          # side view: the arms hang a little forward, the weight clear of the leg (as
                                       # painted); the walk swings them about a straighter hang (anim.py)
E_LEN = 106.0                          # side view: shoulder (the side disc) to the weight's centre
E_FAR = (5.0, -3.0)                    # side view: the far shoulder, behind the near one
E_FAR_SHADE = 0.62                     # and its arm, darker
DEPTH_SCALE = 0.18                     # a head swung towards us grows (x 1 + this x depth / arm length)
DEPTH_DARK = 0.40                      # and one swung away darkens (front and back views)
FAR_LEG = dict(dx=10, dy=-6, shade=0.66)   # side view: the far leg, a darker copy behind the near one


def fg(a):
    return np.abs(a - BG).sum(-1) > 38


FIG = fg(A)


def poly_mask(pts, shape):
    im = Image.new('L', (shape[1], shape[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
    return np.array(im) > 0


def rgba(rgb, m):
    o = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    o[..., :3] = np.clip(rgb, 0, 255)
    o[..., 3] = m * 255
    o[~m] = 0
    return o


def padded(a):
    """an RGBA array into a PIL image with PAD round it (so parts can move out of the row's window)"""
    h, w = a.shape[:2]
    c = np.zeros((h + 2 * PAD, w + 2 * PAD, 4), np.uint8)
    c[PAD:PAD + h, PAD:PAD + w] = a
    return Image.fromarray(c, 'RGBA')


def place(img, p0, p1, M):
    """draw img (padded) so that p0 lands on p1 and the rest follows matrix M about it (NEAREST: the paint stays)"""
    Mi = np.linalg.inv(M)
    a, b = Mi[0]
    d, e = Mi[1]
    P0 = (p0[0] + PAD, p0[1] + PAD)
    P1 = (p1[0] + PAD, p1[1] + PAD)
    return img.transform(img.size, Image.AFFINE, (a, b, P0[0] - a * P1[0] - b * P1[1], d, e,
                                                  P0[1] - d * P1[0] - e * P1[1]), resample=Image.NEAREST)


def shade(img, k):
    a = np.array(img).astype(float)
    a[..., :3] *= k
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGBA')


def rotm(rad):
    c, s = math.cos(rad), math.sin(rad)
    return np.array([[c, -s], [s, c]])


def matrix(v0, v1):
    """turn v0 onto v1 and stretch along it (a bone keeps its width)"""
    rot = math.atan2(v1[1], v1[0]) - math.atan2(v0[1], v0[0])
    n0 = math.hypot(*v0)
    u = np.array(v0) / n0
    return rotm(rot) @ (np.eye(2) + (math.hypot(*v1) / n0 - 1) * np.outer(u, u))


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def comp_at(mask, x, y):
    lab, n = ndi.label(mask)
    k = lab[y, x]
    if k == 0:
        ys, xs = np.nonzero(mask)
        i = int(np.argmin((xs - x) ** 2 + (ys - y) ** 2))
        k = lab[ys[i], xs[i]]
    return lab == k


# ------------------------------------------------------------------------------------------------ cutting an arm
def steel(F):
    """the blades' steel (light blue-grey to white), not the knee balls' saturated blue"""
    R_, G_, B_ = F[..., 0], F[..., 1], F[..., 2]
    return (B_ >= R_) & (B_ > 110) & (R_ > 60) & (G_ > 70) & (B_ - R_ < 75)


def arm_mask(F, FM, arm, org):
    """the painted arm in the row window: the polygon's paint, plus the steel of a blade horn reaching past it (grown
    through steel pixels only) and the dark outline on the horn's free side (not the outline it shares with a knee)"""
    H, W = FM.shape
    pts = [(x - org[0], y - org[1]) for x, y in arm['poly']]
    pm = poly_mask(pts, (H, W))
    m = pm & FM
    st = steel(F) & FM
    grow = m & st
    near = ndi.binary_dilation(pm, iterations=6)
    for _ in range(8):
        g2 = (ndi.binary_dilation(grow) & st & near) | grow
        if (g2 == grow).all():
            break
        grow = g2
    new = grow & ~m
    m |= grow
    dark = FM & (F.sum(-1) < 200) & ~m
    paint = FM & ~dark & ~m                      # anything painted that is not the arm (a knee, a thigh)
    edge = ndi.binary_dilation(new) & dark & near & ~ndi.binary_dilation(paint)
    m |= edge
    lab, n = ndi.label(m)
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1))
        m &= np.isin(lab, [i + 1 for i, v in enumerate(sz) if v >= 12])
    return m


def axis_fit(m, top_y, bot_y):
    """the rod's centre line from the mask rows between top_y and bot_y: x = x0 + sx * (y - top_y)"""
    ys, cs = [], []
    for y in range(int(top_y), int(bot_y)):
        xs = np.nonzero(m[y])[0]
        if len(xs) < 3:
            continue
        # the rod is one run here: take the run nearest the previous centre
        runs = np.split(xs, np.nonzero(np.diff(xs) > 1)[0] + 1)
        run = max(runs, key=len)
        ys.append(y)
        cs.append((run[0] + run[-1]) / 2.0)
    ys, cs = np.array(ys, float), np.array(cs, float)
    sx, x0 = np.polyfit(ys, cs, 1)
    return x0, sx


def fill_ball(F, vis, disc, C):
    """paint the ball's hidden pixels (the strip behind the sleeve and the clamp) from its own paint: a lit sphere
    looks the same mirrored across the line from its centre through its highlight, so a hidden pixel takes the paint
    of its mirror image across that line; where that is hidden too, the nearest visible paint"""
    out = F.copy()
    ys, xs = np.nonzero(vis)
    lum = F[ys, xs].sum(-1)
    top = lum >= np.percentile(lum, 94)
    l = np.array([xs[top].mean() - C[0], ys[top].mean() - C[1]])
    l = l / (np.linalg.norm(l) or 1.0)
    hy, hx = np.nonzero(disc & ~vis)
    left = []
    for y, x in zip(hy, hx):
        d = np.array([x - C[0], y - C[1]])
        q = 2 * (d @ l) * l - d + C
        qx, qy = int(round(q[0])), int(round(q[1]))
        if 0 <= qy < vis.shape[0] and 0 <= qx < vis.shape[1] and vis[qy, qx]:
            out[y, x] = F[qy, qx]
        else:
            left.append((y, x))
    if left:
        _, (iy, ix) = ndi.distance_transform_edt(~vis, return_indices=True)
        for y, x in left:
            out[y, x] = F[iy[y, x], ix[y, x]]
    return out


def cut_arm(F, FM, arm, org):
    """an arm's layers (padded RGBA in row-window coordinates) and its geometry. The axis is the painted rod's
    centre line (fitted above the ball, carried on through the sleeve and the clamp)."""
    H, W = FM.shape
    m_all = arm_mask(F, FM, arm, org)
    m = m_all.copy()
    if arm.get('drop_above'):
        m[:int(arm['drop_above'] - org[1])] = False      # cut off the body, not part of the arm (the E knuckle)
    yy, xx = np.mgrid[0:H, 0:W]
    bx, by, br = arm['ball'][0] - org[0], arm['ball'][1] - org[1], arm['ball'][2]
    ys = np.nonzero(m.any(1))[0]
    top = ys.min()
    x0, sx = axis_fit(m, top + 3, by - br - 3)
    u = np.array([sx, 1.0]) / math.hypot(sx, 1.0)
    C = np.array([bx, by])
    T = np.array([x0 + sx * top, float(top)])
    nrm = np.array([-u[1], u[0]])
    t = (xx - T[0]) * u[0] + (yy - T[1]) * u[1]
    n = (xx - T[0]) * nrm[0] + (yy - T[1]) * nrm[1]
    tC = float((C - T) @ u)
    # the rod's half width, measured above the ball (perpendicular extent of the mask)
    def half_width(t0, t1):
        sel = m & (t >= t0) & (t < t1)
        if not sel.any():
            return 4.0
        return float(np.percentile(np.abs(n[sel]), 97)) + 0.8
    w_rod = half_width(4, tC - br - 14)
    w_slv = max(w_rod, half_width(tC - br - 8, tC - br - 1))
    # the clamp: along the axis at the clamp's centre
    cxp = np.array([arm['clamp'][0] - org[0], arm['clamp'][1] - org[1]])
    tK = float((cxp - T) @ u)
    kl, kw = arm['clamp'][2], arm['clamp'][3]
    front = m & (((t < tK) & (np.abs(n) <= np.where(t < tC - br - 6, w_rod, w_slv))) |
                 ((np.abs(t - tK) <= kl) & (np.abs(n) <= kw)))
    front &= t > -2
    rr = np.hypot(xx - bx, yy - by)
    disc = rr <= br
    st = steel(F)
    stn = ndi.binary_dilation(st & m, iterations=2)          # the blade and its outline
    ball_vis = m & (rr <= br + 1.5) & ~front & ~(st | (stn & (rr > br - 2.5)))
    blade = m & ~front & ~ball_vis
    # leftovers far from the steel (bits of the ball's or the sleeve's outline): to the nearer of ball and front
    odd = blade & ~stn
    if odd.any():
        dball = rr - br
        dfront = ndi.distance_transform_edt(~front)
        to_ball = odd & (dball <= dfront)
        ball_vis |= to_ball
        front |= odd & ~to_ball
        blade &= ~odd
    # the ball's true circle, fitted to its free edge (the edge pixels that touch the navy, not the sleeve or blade)
    outside = ~ndi.binary_dilation(m, iterations=1)
    free = ball_vis & ndi.binary_dilation(~m & ~FM, iterations=1) & ~ndi.binary_dilation(front | blade, iterations=2)
    fy, fx = np.nonzero(free)
    if len(fx) >= 12:
        Am = np.c_[2 * fx, 2 * fy, np.ones(len(fx))]
        sol = np.linalg.lstsq(Am, fx * fx + fy * fy, rcond=None)[0]
        cx_, cy_ = sol[0], sol[1]
        r_ = math.sqrt(max(1.0, sol[2] + cx_ * cx_ + cy_ * cy_))
        if math.hypot(cx_ - bx, cy_ - by) < 6 and abs(r_ - br) < 4:
            bx, by, br = float(cx_), float(cy_), float(r_)
            rr = np.hypot(xx - bx, yy - by)
            disc = rr <= br
            C = np.array([bx, by])
            tC = float((C - T) @ u)
    ballrgb = fill_ball(F, ball_vis, disc, (bx, by))
    ball_m = ball_vis | (disc & m)                # whatever hid it (the sleeve, the clamp, a blade's horn), filled
    t_split = tC - br - 4.0
    rod = front & (t < t_split)
    head = front & (t >= t_split)
    # the rod extended under the hub up to the pivot and down under the sleeve: copies of a cross-section
    P = np.array([arm['pivot'][0] - org[0], arm['pivot'][1] - org[1]], float)
    tP = float((P - T) @ u)
    t_top = float(t[rod].min()) if rod.any() else 0.0
    rodrgb = F.copy()
    rod_m = rod.copy()
    def extend(t_from, t_to, t_src):
        ts = np.arange(min(t_from, t_to), max(t_from, t_to) + 0.5, 0.5)
        ns = np.arange(-w_rod, w_rod + 0.01, 0.5)
        for tt in ts:
            for nn in ns:
                px, py = T + u * tt + nrm * nn
                qx, qy = T + u * t_src + nrm * nn
                ix, iy, jx, jy = int(round(px)), int(round(py)), int(round(qx)), int(round(qy))
                if 0 <= ix < W and 0 <= iy < H and 0 <= jx < W and 0 <= jy < H and rod[jy, jx] and not rod_m[iy, ix]:
                    rodrgb[iy, ix] = F[jy, jx]
                    rod_m[iy, ix] = True
    if arm.get('rehang'):
        extend(t_top - 3, t_top + 2, t_top + 3)          # re-hung elsewhere: only a little under the new hub
        T0 = T + u * t_top
    else:
        extend(min(tP, t_top) - 2, t_top + 2, t_top + 3)
        T0 = P
    extend(t_split - 3, t_split + 10, t_split - 4)
    geo = dict(P=tuple(P), C=(bx, by), r=br, T=tuple(T0), u=tuple(u), tC=tC, t_split=t_split,
               S=tuple(T + u * t_split), w_rod=w_rod)
    lay = dict(rod=padded(rgba(rodrgb, rod_m)), head=padded(rgba(F, head)), ball=padded(rgba(ballrgb, ball_m)),
               blade=padded(rgba(F, blade)))
    return m_all, lay, geo


# ------------------------------------------------------------------------------------------------ the legs
def blue_balls(F, FM):
    R_, G_, B_ = F[..., 0], F[..., 1], F[..., 2]
    blue = FM & (B_ > R_ + 40) & (B_ > 110) & (R_ < 110)
    lab, n = ndi.label(blue)
    out = []
    for i, s in enumerate(ndi.find_objects(lab)):
        m = lab[s] == i + 1
        w, h = s[1].stop - s[1].start, s[0].stop - s[0].start
        if m.sum() < 120 or w > 28 or h > 28:
            continue
        ys, xs = np.nonzero(m)
        out.append(dict(x=float(xs.mean() + s[1].start), y=float(ys.mean() + s[0].start), r=max(w, h) / 2.0))
    return out


def ankle_row(F, lm, ky, sy):
    """where the red skirt ends and the brass dome begins"""
    R_, G_, B_ = F[..., 0], F[..., 1], F[..., 2]
    red = lm & (R_ > 140) & (G_ < 90)
    brass = lm & (R_ > 120) & (G_ > 70) & (B_ < 90) & ~red
    for y in range(int(ky) + 15, sy):
        nb, nr = int(brass[y].sum()), int(red[y].sum())
        if nb >= 8 and nb > nr * 1.2:
            return y
    return int(sy - 20)


def cut_legs(F, BM, side_view):
    """legs out of the body mask (arms already off): thigh, shin, foot and hip ball per leg (as the old walk.py)"""
    H, W = BM.shape
    balls = sorted(blue_balls(F, BM & ~ndi.binary_dilation(steel(F) & BM, iterations=1)), key=lambda b: b['y'])
    nl = 1 if side_view else 2
    hips = sorted(balls[:nl], key=lambda b: b['x'])
    knees = sorted(balls[nl:2 * nl], key=lambda b: b['x'])
    yy, xx = np.mgrid[0:H, 0:W]
    legs = []
    rest = BM.copy()
    for hb, kb in zip(hips, knees):
        hx, hy, kx, ky = hb['x'], hb['y'], kb['x'], kb['y']
        below = BM.copy()
        below[:int(hy) - 12] = False
        lm = comp_at(below, int(hx), int(hy))
        rest &= ~lm
        ys, xs = np.nonzero(lm)
        sy = int(ys.max())
        ay = ankle_row(F, lm, ky, sy)
        hipd = np.hypot(xx - hx, yy - hy) <= hb['r'] + 2
        kned = np.hypot(xx - kx, yy - ky) <= kb['r'] + 2
        thigh = lm & ~hipd & ~kned & (yy < ky)
        shin = lm & ~hipd & ((yy >= ky) | kned) & (yy < ay)
        foot = lm & (yy >= ay)
        axs = np.nonzero(shin[ay - 1])[0]
        ax = float(axs.mean()) if len(axs) else kx
        bys, bxs = np.nonzero(lm & (yy >= sy - 4))
        legs.append(dict(hip=(hx, hy), knee=(kx, ky), ankle=(ax, float(ay)), sole=(float(bxs.mean()), float(sy)),
                         heel=(float(bxs.min()), float(sy)), toe=(float(bxs.max()), float(sy)),
                         thigh=padded(rgba(F, thigh)), shin=padded(rgba(F, shin)), foot=padded(rgba(F, foot)),
                         hipball=padded(rgba(F, lm & hipd)), mask=lm))
    return legs, rest


# ------------------------------------------------------------------------------------------------ one facing
def fill_from_body(F, body, hole, keep):
    """paint hole pixels that stay inside the body (keep) from the nearest body paint"""
    fill = hole & keep
    if not fill.any():
        return F, body
    _, (iy, ix) = ndi.distance_transform_edt(~body, return_indices=True)
    F2 = F.copy()
    F2[fill] = F[iy[fill], ix[fill]]
    return F2, body | fill


def cut_row(r):
    R = ROWS[r]
    x0, y0, x1, y1 = R['box']
    org = (x0, y0)
    F = A[y0:y1, x0:x1].copy()
    FM = FIG[y0:y1, x0:x1].copy()
    holes = ndi.binary_fill_holes(FM) & ~FM            # only pinholes in the paint: the navy that the arms, blades
    lab, n = ndi.label(holes)                           # and legs enclose stays background
    if n:
        sz = ndi.sum(holes, lab, range(1, n + 1))
        FM |= np.isin(lab, [i + 1 for i, v in enumerate(sz) if v <= 6])
    lab, n = ndi.label(FM)
    if n > 1:
        sz = ndi.sum(FM, lab, range(1, n + 1))
        FM &= lab == (1 + int(np.argmax(sz)))
    H, W = FM.shape
    arms = []
    cut = np.zeros_like(FM)
    for arm in R['arms']:
        m, lay, geo = cut_arm(F, FM, arm, org)
        cut |= m
        hx, hy, hrx, hry = arm['hub']
        yy, xx = np.mgrid[0:H, 0:W]
        hubm = FM & ~m & ((((xx - (hx - x0)) / hrx) ** 2 + ((yy - (hy - y0)) / hry) ** 2) <= 1.0)
        arms.append(dict(cfg=arm, lay=lay, geo=geo, hub=padded(rgba(F, hubm)), mask=m,
                         pivot=(arm['pivot'][0] - x0, arm['pivot'][1] - y0)))
    body = FM & ~cut
    lab, n = ndi.label(body)                     # loose slivers an arm's cut left behind (a ball's edge, an outline)
    if n > 1:
        sz = ndi.sum(body, lab, range(1, n + 1))
        body &= np.isin(lab, [i + 1 for i, v in enumerate(sz) if v >= 300])
    if r == 2:
        # the side view: the knuckle the painted arm hung from sat on the case's front edge: fill the case there
        # (to the case's own edge, x <= 333 on the sheet) from the case's paint, with a dark outline at the edge
        yy, xx = np.mgrid[0:H, 0:W]
        keep = (xx + x0 <= 333) & (yy + y0 >= 664) & (yy + y0 <= 700)
        F, body = fill_from_body(F, body, cut, keep)
        edge = keep & body & ~ndi.binary_erosion(body | ~keep, iterations=1) & (xx + x0 == 333)
        F[edge] = (F[edge] * 0.25).astype(int)
    legs, rest = cut_legs(F, body, r == 2)
    D = dict(F=F, size=(W, H), org=org, body=padded(rgba(F, rest)), bodymask=rest, legs=legs, arms=arms,
             mid=R['mid'] - x0)
    return D


PARTS = [cut_row(r) for r in range(5)]


# ------------------------------------------------------------------------------------------------ the swing
def arm_screen(r, arm, theta, yaw=0.0, e_rest=None):
    """where the weight's centre goes (offset from the pivot, screen px), the linear map for the head's paint, and
    the depth (px towards the camera) of the weight, for a swing theta (deg, + forward) and a yaw (deg, + towards
    the middle)"""
    g = arm['geo']
    a = math.radians(AZ[r])
    th, ps = math.radians(theta), math.radians(yaw)
    robot_right = arm['cfg']['robot'] == 'right'
    # robot axes on the ground (east = screen right, south = towards the camera)
    Fw = np.array([math.sin(a), math.cos(a), 0.0])       # forward
    Rw = np.array([-math.cos(a), math.sin(a), 0.0])       # the robot's right
    Dw = np.array([0.0, 0.0, -1.0])                      # down
    def proj(v):
        return np.array([v[0], K * v[1] - v[2]])
    if r == 2:
        # side view: the arm re-hung from the side disc, swung in the picture plane
        phi = math.radians(theta + (E_REST if e_rest is None else e_rest))
        L = E_LEN
        v = np.array([math.sin(phi), math.cos(phi)]) * L
        u0 = np.array(g['u'])
        ang = phi - math.atan2(u0[0], u0[1])
        Mh = rotm(-ang)
        side = 1.0 if robot_right else -1.0
        depth = side * SHOULDER
        return v, Mh, depth, L
    # the painted arm lies in the picture plane: a point (px, py) from the pivot is px east and py down. The arm
    # swings on a hinge square to it (the hub's axle follows the arm's splay), so it turns from where it hangs
    # straight towards "forward": seen from the front it shortens along its own line (it does not lift sideways)
    inward = Rw if not robot_right else -Rw             # the right arm turns in towards its left, and v.v.
    C = np.array(g['C']) - np.array(arm['pivot'])
    d0 = np.array([C[0], 0.0, -C[1]])
    d0 /= np.linalg.norm(d0)
    Fp = Fw - (Fw @ d0) * d0
    Fp /= np.linalg.norm(Fp)
    hn = np.cross(d0, Fp)
    def turn(v):
        a_, b_, c_ = v @ d0, v @ Fp, v @ hn
        w = (a_ * (d0 * math.cos(th) + Fp * math.sin(th)) + b_ * (Fp * math.cos(th) - d0 * math.sin(th)) + c_ * hn)
        # then about the vertical (yaw): the horizontal part turns from forward towards the inside
        hf, hi = w @ Fw, w @ inward
        vert = w - Fw * hf - inward * hi
        return vert + Fw * (hf * math.cos(ps) - hi * math.sin(ps)) + inward * (hf * math.sin(ps) + hi * math.cos(ps))
    E_ = np.array([1.0, 0.0, 0.0])
    def screen_map(p):
        w = E_ * p[0] + Dw * p[1]
        return proj(turn(w)), turn(w)
    v, w3 = screen_map(C)
    ex, _ = screen_map((1.0, 0.0))
    ey, _ = screen_map((0.0, 1.0))
    Mh = np.array([[ex[0], ey[0]], [ex[1], ey[1]]])
    side = 1.0 if robot_right else -1.0
    depth = side * SHOULDER * math.sin(a) + w3[1]
    return v, Mh, depth, float(np.linalg.norm(C))


def arm_layers(r, arm, pivot_s, theta, yaw=0.0, dark=None, scale_on=True, e_rest=None):
    """the arm's paint for a swing: [(layer name, image)] (rod, blade, ball, head = sleeve and clamp), the depth of
    its weight (px towards the camera) and the weight's screen centre. A head swung towards us (from where the
    painting has it) grows a little, one swung away shrinks and darkens (front, back and 3/4 views)."""
    g = arm['geo']
    lay = arm['lay']
    v, Mh, depth, L = arm_screen(r, arm, theta, yaw, e_rest)
    rest = arm_screen(r, arm, 0.0, 0.0, e_rest)[2]
    dd = depth - rest
    C1 = (pivot_s[0] + v[0], pivot_s[1] + v[1])
    s = 1.0
    k = 1.0
    if r != 2:
        if scale_on:
            s = max(0.85, min(1.22, 1.0 + DEPTH_SCALE * dd / L))
        if dd < 0:
            k = 1.0 - DEPTH_DARK * min(1.0, -dd / L)
    if dark is not None:
        k *= dark
    Ms = Mh * s
    head = place(lay['head'], g['C'], C1, Ms)
    blade = place(lay['blade'], g['C'], C1, Ms)
    ball = place(lay['ball'], g['C'], C1, np.eye(2) * s)
    # the rod: from its top (the pivot; in the side view the painted rod's own top) to where the sleeve starts on the
    # moved head, turned and stretched along its length
    S0 = np.array(g['S'])
    S1 = np.array(C1) + Ms @ (S0 - np.array(g['C']))
    P0 = np.array(g['T'])
    rod = place(lay['rod'], tuple(P0), pivot_s, matrix(tuple(S0 - P0), tuple(S1 - np.array(pivot_s))))
    out = [('rod', rod), ('blade', blade), ('ball', ball), ('head', head)]
    if k != 1.0:
        out = [(n_, shade(im, k)) for n_, im in out]
    return out, depth, C1


# ------------------------------------------------------------------------------------------------ preview
def preview(path):
    tiles = []
    for r in range(5):
        D = PARTS[r]
        row = [D['body']]
        for a in D['arms']:
            row += [a['hub'], a['lay']['rod'], a['lay']['blade'], a['lay']['ball'], a['lay']['head']]
        for L in D['legs']:
            row += [L['thigh'], L['shin'], L['foot'], L['hipball']]
        ims = []
        for t in row:
            bb = t.getbbox()
            if bb is None:
                continue
            ims.append(t.crop(bb))
        tiles.append(ims)
    Wt = max(sum(i.width + 8 for i in ims) for ims in tiles)
    Ht = sum(max(i.height for i in ims) + 8 for ims in tiles)
    sheet = Image.new('RGB', (Wt, Ht), (40, 70, 40))
    y = 0
    for ims in tiles:
        x = 0
        for im in ims:
            sheet.paste(im, (x, y), im)
            x += im.width + 8
        y += max(i.height for i in ims) + 8
    sheet.save(path)


if __name__ == '__main__':
    preview(sys.argv[1] if len(sys.argv) > 1 else 'art/redraws/pendulum_v2_parts.png')
    for r in range(5):
        for a in PARTS[r]['arms']:
            g = a['geo']
            print(DIRS[r], a['cfg']['side'], 'rod w %.1f' % g['w_rod'], 'axis u (%.2f,%.2f)' % g['u'], 'tC %.1f' % g['tC'])
        print(DIRS[r], 'legs', [(round(L['hip'][0]), round(L['hip'][1]), round(L['knee'][0]), round(L['knee'][1])) for L in PARTS[r]['legs']])
    print('ok')
