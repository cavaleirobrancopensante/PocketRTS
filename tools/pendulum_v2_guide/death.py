"""Pendulum v2 DEATH guide in code, for a ChatGPT clean-up (like tools/pendulum_guide/death.py): it is struck and
jolts (the arms fling loose), the legs buckle and crumple, both arms snap off at the shoulders and fall, the tower body
topples over sideways, hits the ground in a burst of dust and a few loose cogs, bounces once and lies still.

The arms that snap off are the LONE arms of the direction sheet's column 2 (hub, rod, weight and blade: a clean whole
arm), scaled to the arm on the body, so each takes its gear joint with it; the shoulder drums stay on the body. The
dust puffs and the cogs are drawn in code (guide only: ChatGPT repaints them).

Two 1536 x 1024 guide images (6 frames of 256 x 307 per row, rows 327 px apart): rows S, SE, E (part 1) and NE, N
(part 2), each at the unit's own scale, so each fits one ChatGPT request. Out: art/redraws/pendulum_v2_death_guide_1.png,
pendulum_v2_death_guide_2.png and pendulum_v2_death_guide.gif (the five facings side by side at game scale x 3)."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parts as P
import rig as G
from parts import PAD, place, shade, rotm, sub, add

DW, DH = 256, 307
GROUND = DH - 10
FALL = [1, 1, 1, 1, -1]                  # the screen side it topples to, per row
SQUASH = [1.0, 0.80, 0.52, 0.34, 0.30, 0.30]   # the legs: how much of their height is left
SPREAD = [0.0, 0.10, 0.25, 0.35, 0.38, 0.38]   # and how far they splay
TILT = [5, 16, 46, 78, 90, 90]           # the body: degrees towards FALL
BOUNCE = [0, 0, 0, 0, -6, 0]
DARK = [1, 1, 1, 1, 0.94, 0.86]
JOLT = [(-4, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)]   # struck: it rocks back first
# the arms: frame 0 still on, flung loose (theta per robot side); then snapped off at the shoulder: an arm falls weight
# first, its weight dropping close to where it hung while its light hub end tips outward: (drop px, outward px, tip deg,
# squash) per frame for the arm on the falling side ("near") and the other one; from frame 3 they lie on the ground at
# a slant (squashed: foreshortened), weight in by the body, hub out, at the fallen body's two ends
FLING = {'right': 34.0, 'left': -28.0}
FALL_NEAR = [None, (16, 4, 16, 1.0), (52, 10, 46, 0.9), 'lie', 'lie', 'lie']
FALL_FAR = [None, (12, 4, 20, 1.0), (46, 12, 52, 0.9), 'lie', 'lie', 'lie']
LIE = dict(near=dict(tip=74, squash=0.6, x=50, lift=1), far=dict(tip=100, squash=0.58, x=58, lift=12))
DUST = [0, 0, 0.35, 0.75, 1.0, 0.6]     # dust cloud size per frame (0 = none)
DUST_A = [0, 0, 0.55, 0.7, 0.75, 0.45]   # and opacity


def lone_arm(r):
    """the lone arm of column 2 for row r: (RGBA padded image in its own box, pivot, ball centre)"""
    L = P.LONE[r]
    x0, y0, x1, y1 = L['box']
    F = P.A[y0:y1, x0:x1]
    m = P.fg(F)
    holes = ndi.binary_fill_holes(m) & ~m
    lab, n = ndi.label(holes)
    if n:
        sz = ndi.sum(holes, lab, range(1, n + 1))
        m |= np.isin(lab, [i + 1 for i, v in enumerate(sz) if v <= 6])
    lab, n = ndi.label(m)
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1))
        m &= lab == (1 + int(np.argmax(sz)))
    img = P.padded(P.rgba(F, m))
    return img, (L['pivot'][0] - x0, L['pivot'][1] - y0), (L['ball'][0] - x0, L['ball'][1] - y0)


def scaled_arm(r, arm):
    """the lone arm scaled to the length of this arm on the body (pivot to weight), as an RGBA image with its pivot"""
    img, pv, bc = lone_arm(r)
    g = arm['geo']
    Lb = math.hypot(*sub(g['C'], arm['pivot'])) if r != 2 else P.E_LEN
    Ll = math.hypot(*sub(bc, pv))
    k = Lb / Ll
    w, h = img.size
    sm = img.resize((max(1, int(round(w * k))), max(1, int(round(h * k)))), Image.NEAREST)
    return sm, ((pv[0] + PAD) * k, (pv[1] + PAD) * k), ((bc[0] + PAD) * k, (bc[1] + PAD) * k)


def gear(d, cx, cy, rad, teeth=8, col=(196, 150, 60)):
    pts = []
    for i in range(teeth * 2):
        a = math.pi * i / teeth
        rr = rad if i % 2 == 0 else rad * 0.72
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=col, outline=(60, 40, 20))
    d.ellipse((cx - rad * 0.3, cy - rad * 0.3, cx + rad * 0.3, cy + rad * 0.3), fill=(70, 50, 30))


def dust(cv, cx, gy, size, alpha, fall):
    """a low cloud of dust along the ground (soft tan puffs, darker underneath), size 0..1"""
    if size <= 0:
        return
    lay = Image.new('RGBA', cv.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    rnd = np.random.RandomState(7)
    for i in range(11):
        t = (i / 10.0 - 0.5)
        x = cx + fall * 30 * size + t * 190 * size + rnd.uniform(-6, 6)
        rr = (14 + 16 * (1 - abs(t) * 1.6)) * (0.5 + 0.5 * size) + rnd.uniform(-3, 3)
        y = gy - rr * 0.55 - rnd.uniform(0, 8) * size
        for col, k_, dy in (((96, 82, 70), 1.0, 3), ((150, 132, 112), 0.85, 0), ((186, 170, 150), 0.55, -rr * 0.25)):
            a = int(255 * alpha * (0.9 if col[0] < 120 else 0.75))
            d.ellipse((x - rr * k_, y + dy - rr * 0.62 * k_, x + rr * k_, y + dy + rr * 0.62 * k_), fill=col + (a,))
    cv.alpha_composite(lay)


def frame(r, k):
    D = P.PARTS[r]
    W, H = D['size']
    fall = FALL[r]
    legs = D['legs']
    ax, ay = G.anchor(r)
    ground = ay
    hip_y = min(L['hip'][1] for L in legs)
    jx, jy = JOLT[k]
    # the legs at rest, crumpling down onto the ground and splaying
    lg = G.blank(D)
    def draw(L, off=(0, 0), dark=None):
        for key in ('thigh', 'shin', 'foot', 'hipball'):
            p_ = L[key] if off == (0, 0) else place(L[key], (0, 0), off, np.eye(2))
            lg.alpha_composite(shade(p_, dark) if dark else p_)
    if r == 2:
        draw(legs[0], (P.FAR_LEG['dx'], P.FAR_LEG['dy']), P.FAR_LEG['shade'])
    for L in legs:
        draw(L)
    s = SQUASH[k]
    M = np.array([[1 + SPREAD[k], 0.0], [0.0, s]])
    lg = place(lg, (ax, ground), (ax + jx * 0.3, ground), M)
    # the body (with its shoulder drums) sinks with the legs and tips over about its bottom corner on the falling side
    drop = (1 - s) * (ground - hip_y)
    xs = [L['hip'][0] for L in legs]
    corner = ((max(xs) + 16) if fall > 0 else (min(xs) - 16), hip_y)
    a = math.radians(TILT[k]) * fall
    piv_new = (corner[0] + jx, corner[1] + drop + BOUNCE[k] + jy)
    body = G.blank(D)
    body.alpha_composite(D['body'])
    for arm in D['arms']:
        body.alpha_composite(arm['hub'])
    bodyimg = place(body, corner, piv_new, rotm(a))
    bb = bodyimg.getbbox()
    if bb and k >= 3:
        # it lands: across the unit's point, a little to the falling side, resting on the ground
        tx = ax + fall * 22
        ty = ground + BOUNCE[k] - (14 if k == 3 else 0)
        bodyimg = place(bodyimg, (0, 0), (tx - ((bb[0] + bb[2]) / 2 - PAD), ty - (bb[3] - PAD)), np.eye(2))
    elif bb and bb[3] - PAD > ground + 2:
        bodyimg = place(bodyimg, (0, 0), (0, ground + 2 - (bb[3] - PAD)), np.eye(2))
    cv = G.blank(D)
    # the arms
    arm_imgs_back, arm_imgs_front = [], []
    sides = [(arm, arm['cfg']['robot'], None, (0.0, 0.0)) for arm in D['arms']]
    if r == 2:
        sides.append((D['arms'][0], 'left', P.E_FAR_SHADE, P.E_FAR))
    for arm, side, dark, off in sides:
        if k == 0:
            a_ = arm if side == arm['cfg']['robot'] else dict(arm, cfg=dict(arm['cfg'], robot=side))
            pv = add(add(arm['pivot'], off), (jx, jy))
            lay, depth, C1 = P.arm_layers(r, a_, pv, FLING[side], 0.0, dark=dark)
            comp = G.blank(D)
            for n_, im in lay:
                comp.alpha_composite(im)
            (arm_imgs_back if depth < 0 else arm_imgs_front).append(comp)
            continue
        img, pv_l, bc_l = scaled_arm(r, arm)
        # the arm whose shoulder is on the falling side lands in front at that end; the other one behind, at the other
        sx = arm['pivot'][0] + off[0] - ax
        near_fall = (sx * fall > 0) if r != 2 else (side == 'right')
        out = fall if near_fall else -fall                 # which way is "outward" for this arm on screen
        key = FALL_NEAR[k] if near_fall else FALL_FAR[k]
        if r == 2:
            ball0 = add(add(arm['pivot'], off), (P.E_LEN * math.sin(math.radians(P.E_REST)),
                                                  P.E_LEN * math.cos(math.radians(P.E_REST))))
        else:
            ball0 = arm['geo']['C']
        if key == 'lie':
            q = LIE['near' if near_fall else 'far']
            M = np.array([[1.0, 0.0], [0.0, q['squash']]]) @ rotm(math.radians(q['tip'] * out))
            rot = place_lone(img, bc_l, M)
            bb2 = rot.getbbox()
            low = bb2[3] - (bc_l[1] + img.height)
            pos = [ax + out * q['x'], ground - q['lift'] - low + (BOUNCE[k] // 2 if near_fall else 0)]
        else:
            drop, ox, tip, sq = key
            M = np.array([[1.0, 0.0], [0.0, sq]]) @ rotm(math.radians(tip * out))
            rot = place_lone(img, bc_l, M)
            bb2 = rot.getbbox()
            pos = [ball0[0] + out * ox, min(ball0[1] + drop, ground - 2 - (bb2[3] - (bc_l[1] + img.height)))]
        # keep it in the cell
        lft = pos[0] + (bb2[0] - (bc_l[0] + img.width)) - (ax - DW / 2)
        rgt = pos[0] + (bb2[2] - (bc_l[0] + img.width)) - (ax - DW / 2)
        if lft < 3:
            pos[0] += 3 - lft
        if rgt > DW - 3:
            pos[0] -= rgt - (DW - 3)
        im = place_at(D, img, bc_l, tuple(pos), M)
        if dark is not None:
            im = shade(im, dark)
        (arm_imgs_front if near_fall else arm_imgs_back).append(im)
    for im in arm_imgs_back:
        cv.alpha_composite(im)
    cv.alpha_composite(lg)
    cv.alpha_composite(bodyimg)
    for im in arm_imgs_front:
        cv.alpha_composite(im)
    if k >= 4:
        d = ImageDraw.Draw(cv)
        gx = ax + PAD + fall * 30
        for (dx_, dy_, rr) in [(-46, -5, 7), (26, -3, 5), (58, -8, 6), (-14, -2, 4)]:
            gear(d, gx + dx_ * (1 if k == 5 else 0.85), PAD + ground + dy_ - (7 if k == 4 else 0), rr)
    if DUST[k]:
        dust(cv, ax + PAD, ground + PAD + 2, DUST[k], DUST_A[k], fall)
    if DARK[k] != 1:
        cv = shade(cv, DARK[k])
    return G.to_cell(r, cv, cw=DW, ch=DH, ground=GROUND)


def place_lone(img, pv, M):
    """turn a lone-arm image about its pivot (in its own image px)"""
    c = Image.new('RGBA', (img.width * 3, img.height * 3), (0, 0, 0, 0))
    c.alpha_composite(img, (img.width, img.height))
    Mi = np.linalg.inv(M)
    a, b = Mi[0]
    d, e = Mi[1]
    P0 = (pv[0] + img.width, pv[1] + img.height)
    out = c.transform(c.size, Image.AFFINE, (a, b, P0[0] - a * P0[0] - b * P0[1], d, e, P0[1] - d * P0[0] - e * P0[1]),
                      resample=Image.NEAREST)
    return out


def place_at(D, img, pv, pos, M):
    """a lone-arm image turned by M about its pivot pv and put with the pivot at pos (row-window px) on a row canvas"""
    rot = place_lone(img, pv, M)
    cv = G.blank(D)
    x = int(round(pos[0] + PAD - (pv[0] + img.width)))
    y = int(round(pos[1] + PAD - (pv[1] + img.height)))
    tmp = Image.new('RGBA', cv.size, (0, 0, 0, 0))
    tmp.paste(rot, (x, y), rot)
    cv.alpha_composite(tmp)
    return cv


if __name__ == '__main__':
    frames = {r: [frame(r, k) for k in range(6)] for r in range(5)}
    for part, rows in ((1, [0, 1, 2]), (2, [3, 4])):
        g = Image.new('RGB', (1536, 1024), P.NAVY)
        for i, r in enumerate(rows):
            for k in range(6):
                g.paste(frames[r][k], (k * DW, i * (DH + 20)), frames[r][k])
        g.save('art/redraws/pendulum_v2_death_guide_%d.png' % part)
    gif = []
    for k in range(6):
        smalls = [G.shrink(frames[r][k]) for r in range(5)]
        w, h = smalls[0].size
        o = Image.new('RGB', (5 * w, h), P.NAVY)
        for r, s_ in enumerate(smalls):
            o.paste(s_, (r * w, 0), s_)
        gif.append(o.resize((o.width * 3, o.height * 3), Image.NEAREST))
    gif[0].save('art/redraws/pendulum_v2_death_guide.gif', save_all=True, append_images=gif[1:],
                duration=[150, 110, 100, 100, 140, 900], loop=0)
    print('ok')
