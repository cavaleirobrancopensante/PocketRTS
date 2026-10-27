"""Pendulum v2 rig: the legs (the old Pendulum's walk machinery, tools/pendulum_guide/walk.py: two-bone IK with heel
and toe pivots in the side view, a telescoping knee in the front, back and 3/4 views, the body's dip at double
support), the frame compositor (arms, legs, body and hubs drawn far to near), and the sheet and GIF writers.

A pose: legs = [(forward, lift, foot turn deg)] per leg in the row's order (the side view: the near leg, then the far
one), body = (dx, dy, lean deg), arms = {'right': (theta, yaw), 'left': (theta, yaw)} (deg; theta + = forward)."""
import math, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parts as P
import cut
from parts import PAD, place, shade, rotm, matrix, sub, add

A_STEP = 45.0      # a foot travels +-A_STEP px forward/back of the hip (side view px)
LIFT = 19.0        # how high the stepping foot lifts
HEEL = 10.0        # a foot lands heel first, toe up (deg, side view)
PUSH = 14.0        # and pushes off with its heel lifted (deg)
DEPTH = 0.17       # screen y per px of a foot's forward motion towards/away from the camera
FWD = [(0.0, DEPTH), (0.28, 0.7 * DEPTH), (1.0, 0.0), (0.28, -0.7 * DEPTH), (0.0, -DEPTH)]
SIDE = [-1.0, -0.7, 0.0, 0.7, 1.0]      # the unit's RIGHT leg: on screen left (-) or right (+)
LEANK = [0.0, 0.7, 1.0, 0.7, 0.0]       # how much of a forward lean shows as a turn on screen
CW, CH = 256, 307                       # the guide cells (sheet px), the ground 10 px above the bottom
GROUND = CH - 10


def right_leg(r):
    """index of the robot's right leg in the row's legs (sorted by x; the side view: 0 = near = right)"""
    return 0 if SIDE[r] <= 0 else 1


def foot(q):
    """forward offset, lift and foot turn (deg, + = toe down) of a foot at gait phase q: 0 = lands in front on its
    heel, flat by mid-stance, the heel lifts as it pushes off (0.5 = toe-off), then it swings forward in the air"""
    q %= 1.0
    if q < 0.5:
        f = A_STEP * (1 - 4 * q)
        phi = -HEEL * (1 - q / 0.25) ** 2 if q < 0.25 else PUSH * ((q - 0.25) / 0.25) ** 2
        return f, 0.0, phi
    t = (q - 0.5) / 0.5
    return -A_STEP + A_STEP * (1 - math.cos(math.pi * t)), LIFT * math.sin(math.pi * t ** 0.8), PUSH * (1 - t) ** 2 - HEEL * t * t


def ik(F, D, l1, l2, stretch):
    d = math.hypot(F, D)
    k = 1.0
    if d > (l1 + l2) * 0.9995:
        if stretch:
            k = d / ((l1 + l2) * 0.9995)
        else:
            d = (l1 + l2) * 0.9995
    l1, l2 = l1 * k, l2 * k
    d = max(abs(l1 - l2) + 1e-3, d)
    a = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    th = math.atan2(F, D) + a                     # the knee bends forward
    kF, kD = l1 * math.sin(th), l1 * math.cos(th)
    vx, vy = F - kF, D - kD
    n = math.hypot(vx, vy) or 1.0
    return (kF, kD), (kF + vx / n * l2, kD + vy / n * l2)


def foot_place(L, r, f, h, phi_deg):
    """where the ankle goes and how the foot turns: on the ground the foot rocks on its heel or toe (that corner
    stays put), in the air it follows the sole's path; the side view centres the stride under the hip"""
    fx, fy = FWD[r]
    phi = math.radians(phi_deg) * fx
    shift = (L['hip'][0] - L['ankle'][0]) if r == 2 else 0.0
    dx, dy = shift + f * fx, f * fy
    if h == 0.0 and phi != 0.0:
        piv = L['toe'] if phi > 0 else L['heel']
        v = rotm(phi) @ np.array(sub(L['ankle'], piv))
        return (piv[0] + dx + v[0], piv[1] + dy + v[1]), phi
    v = rotm(phi) @ np.array(sub(L['sole'], L['ankle']))
    return (L['sole'][0] + dx - v[0], L['sole'][1] + dy - h - v[1]), phi


def leg_pose(L, r, hip_s, f, h, phi_deg):
    """knee and ankle on screen, the foot's turn, and the thigh's and shin's matrices (see the old walk.py)"""
    ank_t, phi = foot_place(L, r, f, h, phi_deg)
    if r == 2:
        t0 = sub(L['knee'], L['hip'])
        s0 = sub(L['ankle'], L['knee'])
        (kF, kD), (aF, aD) = ik(ank_t[0] - hip_s[0], ank_t[1] - hip_s[1], math.hypot(*t0), math.hypot(*s0), False)
        knee = (hip_s[0] + kF, hip_s[1] + kD)
        ank = (hip_s[0] + aF, hip_s[1] + aD)
        return knee, ank, phi, matrix(t0, sub(knee, hip_s)), matrix(s0, sub(ank, knee))
    off = sub(ank_t, L['ankle'])
    knee = add(L['knee'], off)
    T0 = sub(L['knee'], L['hip'])
    T1 = sub(knee, hip_s)
    n0, n1 = math.hypot(*T0), math.hypot(*T1)
    if n1 < n0:
        T1 = (T1[0] * n0 / n1, T1[1] * n0 / n1)
    return knee, ank_t, phi, matrix(T0, T1), np.eye(2)


_E = P.PARTS[2]['legs'][0]
_E_L = math.hypot(*sub(_E['knee'], _E['hip'])) + math.hypot(*sub(_E['ankle'], _E['knee']))


def dip(q):
    """how low the hip must come so both standing legs reach the ground (from the side view)"""
    d = 0.0
    for p in (q, q + 0.5):
        f, h, phi = foot(p)
        if h == 0.0:
            a, _ = foot_place(_E, 2, f, h, phi)
            dx = a[0] - _E['hip'][0]
            d = max(d, a[1] - math.sqrt(max(1.0, (0.99 * _E_L) ** 2 - dx * dx)) - _E['hip'][1])
    return d


def blank(D):
    W, H = D['size']
    return Image.new('RGBA', (W + 2 * PAD, H + 2 * PAD), (0, 0, 0, 0))


def compose(r, pose, extra=None):
    """one frame of row r as a padded RGBA canvas in row-window coordinates. extra(cv, stage) may draw more."""
    D = P.PARTS[r]
    legs = D['legs']
    bx, by, lean = pose.get('body', (0.0, 0.0, 0.0))
    piv = (sum(L['hip'][0] for L in legs) / len(legs), sum(L['hip'][1] for L in legs) / len(legs))
    Mb = rotm(math.radians(lean))

    def body_pt(p):
        v = Mb @ np.array(sub(p, piv))
        return (piv[0] + bx + v[0], piv[1] + by + v[1])
    cv = blank(D)

    def draw_leg(L, fhp, off=(0, 0), dark=None):
        Ls = dict(L, **{k: add(L[k], off) for k in ('hip', 'knee', 'ankle', 'sole', 'heel', 'toe')})
        hip_s = body_pt(Ls['hip'])
        f, h, phi = fhp
        knee, ank, phi, Mt, Ms = leg_pose(Ls, r, hip_s, f, h, phi)
        for p in (place(L['thigh'], L['hip'], hip_s, Mt), place(L['shin'], L['knee'], knee, Ms),
                  place(L['foot'], L['ankle'], ank, rotm(phi)), place(L['hipball'], L['hip'], hip_s, Mb)):
            cv.alpha_composite(shade(p, dark) if dark else p)
    # the arms: (depth, robot side, layers, hub image or None)
    arms = []
    th = pose.get('arms', {})
    for a in D['arms']:
        sides = [(a['cfg']['robot'], None, (0.0, 0.0))]
        if r == 2:
            sides.append(('left', P.E_FAR_SHADE, P.E_FAR))
        for side, dark, off in sides:
            spec = th.get(side, (0.0, 0.0))
            arm = a if side == a['cfg']['robot'] else dict(a, cfg=dict(a['cfg'], robot=side))
            pv = body_pt(add(a['pivot'], off))
            if isinstance(spec, dict):
                # a cutting blow (cut.py): windmill angle, blow weight, the blade's turn on its weight
                lay, depth, C1 = cut.cut_layers(r, arm, pv, spec['th'], spec['w'], spec['beta'], dark=dark)
                if spec.get('trail'):
                    # the smear behind the blade's edge: where the edge was over the trail's poses, then now
                    pts = [cut.edge_point(r, arm, pv, t_, w_, b_)[0] for t_, w_, b_ in spec['trail']]
                    pts.append(cut.edge_point(r, arm, pv, spec['th'], spec['w'], spec['beta'])[0])
                    lay = [('smear', pts)] + lay
            else:
                theta, yaw = spec
                lay, depth, C1 = P.arm_layers(r, arm, pv, theta, yaw, dark=dark, e_rest=pose.get('e_rest'))
            hub = place(a['hub'], piv, (piv[0] + bx, piv[1] + by), Mb) if dark is None else None
            arms.append((depth, side, lay, hub, C1))
    arms.sort(key=lambda t: t[0])
    if extra:
        extra(cv, 'back')
    for depth, side, lay, hub, C1 in arms:
        if depth < 0:
            for n_, im in lay:
                if n_ == 'smear':
                    cut.smear(cv, im, cut.SMEAR_W)
                else:
                    cv.alpha_composite(im)
    bodyimg = place(D['body'], piv, (piv[0] + bx, piv[1] + by), Mb)
    lp = pose.get('legs')
    if r == 2:
        draw_leg(legs[0], lp[1], (P.FAR_LEG['dx'], P.FAR_LEG['dy']), P.FAR_LEG['shade'])
        cv.alpha_composite(bodyimg)
        draw_leg(legs[0], lp[0])
    else:
        order = sorted(range(len(legs)), key=lambda i: legs[i]['hip'][1])
        for i in order:
            draw_leg(legs[i], lp[i])
        cv.alpha_composite(bodyimg)
    if extra:
        extra(cv, 'mid')
    for depth, side, lay, hub, C1 in arms:
        if depth >= 0:
            d = dict(lay)
            if 'smear' in d:
                cut.smear(cv, d['smear'], cut.SMEAR_W)
            cv.alpha_composite(d['rod'])
            if hub is not None:
                cv.alpha_composite(hub)
            for n_ in ('blade', 'ball', 'head'):
                cv.alpha_composite(d[n_])
    if extra:
        extra(cv, 'front')
    return cv


def anchor(r):
    """the unit's point in row-window px: the case's middle across, the ground (the lowest sole)"""
    D = P.PARTS[r]
    return D['mid'], max(L['sole'][1] for L in D['legs']) + 1.0


def to_cell(r, cv, cw=CW, ch=CH, ground=None):
    """a padded canvas into a cell (sheet px) with the anchor at the cell's middle, on its ground line"""
    ax, ay = anchor(r)
    g = GROUND if ground is None else ground
    cell = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
    cell.alpha_composite(cv, (int(round(cw / 2 - (ax + PAD))), int(round(g - (ay + PAD)))))
    return cell


def shrink(img, k=P.GS):
    """an RGBA cell to game scale (premultiplied box filter, then a hard alpha like the game's import)"""
    a = np.array(img).astype(np.float32)
    al = a[..., 3:4] / 255.0
    pre = np.concatenate([a[..., :3] * al, al * 255.0], -1).clip(0, 255).astype(np.uint8)
    w, h = max(1, int(round(img.width * k))), max(1, int(round(img.height * k)))
    s_ = np.array(Image.fromarray(pre, 'RGBA').resize((w, h), Image.BOX)).astype(np.float32)
    al2 = s_[..., 3:4] / 255.0
    rgb = np.where(al2 > 0.01, s_[..., :3] / np.maximum(al2, 0.01), 0)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al2[..., 0] >= 0.45, 255, 0)
    out[out[..., 3] == 0] = 0
    return Image.fromarray(out, 'RGBA')


def on_navy(img):
    o = Image.new('RGB', img.size, P.NAVY)
    o.paste(img, (0, 0), img)
    return o


def save(name, cells, durs, marks=None, cw=CW, ch=CH):
    """cells[r][i] (RGBA, sheet px) -> art/redraws/<name>.png (5 rows x n, on navy) and <name>.gif (the five facings
    side by side at game scale x3; marks: frame indices flagged under the strip, e.g. the hits)"""
    n = len(cells[0])
    sheet = Image.new('RGB', (n * cw, 5 * ch), P.NAVY)
    for r in range(5):
        for i, c in enumerate(cells[r]):
            sheet.paste(c, (i * cw, r * ch), c)
    sheet.save('art/redraws/%s.png' % name)
    gif = []
    for i in range(n):
        smalls = [shrink(cells[r][i]) for r in range(5)]
        w, h = smalls[0].size
        strip = Image.new('RGB', (5 * w, h + (3 if marks is not None else 0)), P.NAVY)
        for r, s in enumerate(smalls):
            strip.paste(s, (r * w, 0), s)
        if marks is not None and i in marks:
            strip.paste((230, 40, 30), (0, h, 5 * w, h + 3))
        gif.append(strip.resize((strip.width * 3, strip.height * 3), Image.NEAREST))
    gif[0].save('art/redraws/%s.gif' % name, save_all=True, append_images=gif[1:], duration=durs, loop=0)
    return sheet
