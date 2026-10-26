"""Pendulum v2 IDLE, WALK and ATTACK in code from the painted parts (parts.py) on the rig (rig.py). Nothing hangs or
swings between the legs: the arms hang outside them, a swung-back weight tucks in behind the hip only where "back" is
away from us, and from behind it never comes in front of the crotch.

IDLE (4 frames): it stands and sways a little over its feet; the arms tick and tock a few degrees, in opposition.
WALK (8 frames): the old Pendulum's long stride (rig.py), driven by the arms: they swing in opposition, the arm
  opposite a leg forward as that leg steps (the left arm forward while the right leg is forward). From the side the
  near arm swings in front of the body and legs and the far one, darker, behind them; from the front and back a
  forward arm comes towards us (lower, bigger, in front of its leg), a back arm goes away (higher, smaller, darker,
  tucked behind the hip).
ATTACK (12 frames, two blows, tick... tock...): the right arm winds back, swings through low and fast, and strikes
  forward and up across the front of the body, then follows through while the left arm swings back (its wind-up);
  the left arm strikes the same way, and both settle. Seen from the side the blow swings forward and up in the picture
  plane; from the front the blade slashes from its side across the belly to the other side; from behind the weight
  rises forward beside the shoulder. The body leans into each blow. THE HITS: frames 4 and 8 (0-based 3 and 7).

Out (sheet px; the unit's point, under the case's middle on the ground, at the middle of each cell 10 px above its
bottom): art/redraws/pendulum_v2_idle.png (rows S, SE, E, NE, N x 4 frames) and pendulum_v2_walk.png (5 x 8), cells
236 x 302; pendulum_v2_attack.png (5 x 12), cells 320 x 326 (the sizes are worked out from the frames); and a GIF of
each: the five facings side by side at game scale (GS = 0.28) x 3, the attack's hit frames marked by a red bar.
  python3 tools/pendulum_v2_guide/anim.py            (... anim.py review DIR: contact sheets for checking)"""
import math, os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parts as P
import rig as G
from rig import foot, dip, SIDE, LEANK, right_leg

N_WALK = 8
ARM_WALK = 32.0     # the arms' swing while walking (deg either way)
WALK_REST = 6.0     # side view: the walk swings the arms about a nearly straight hang (the idle hangs them at 18)
TUCK = 14.0         # a swinging arm turns in a little (deg of yaw at the end of the swing): swung back, its weight
                    # tucks in behind the hip; swung forward, it comes in front of the leg
LEAN = 2.5          # the body leans into the walk (side view, deg)
ROCK = 3.0          # it sways over the standing leg (front view, px)
ROLL = 1.5          # and tilts with it (deg)
IDLE_ARM = 3.5      # the idle's tick and tock (deg)

# the attack, per frame: right arm (theta, yaw), left arm (theta, yaw), the body's lean (deg, + forward) and dip (px).
# A blow is a forward swing that turns in across the front of the body (yaw): seen from the front the blade slashes
# from the side across the belly; seen from the side the same sweep shows as forward and up (PITCHK turns part of
# the yaw into more lift where the yaw cannot be seen, SWEEPK keeps the sweep where it can, and from behind keeps it
# small so the weight is not lost behind the body). An arm swung back tucks in behind the body (negative yaw).
ATTACK = [
    ((-35, -8), (12, 0), -1.5, 0),      # 1  the right arm winds back, tucking in behind
    ((-66, -12), (18, 4), -3.0, 1),     # 2  wound up
    ((14, 4), (-20, -4), 1.5, 2),       # 3  it swings through, low and fast
    ((74, 38), (-44, -8), 4.0, 3),      # 4  THE BLOW: forward and in, the blade sweeping the space in front
    ((86, 62), (-60, -12), 3.0, 2),     # 5  follow-through across the body; the left arm is wound back
    ((42, 18), (-66, -12), -1.0, 1),    # 6  the right arm falls back; the left one holds
    ((-16, -4), (14, 4), 1.5, 2),       # 7  the left arm swings through
    ((-42, -8), (74, 38), 4.0, 3),      # 8  THE BLOW
    ((-56, -12), (86, 62), 3.0, 2),     # 9  follow-through
    ((-34, -6), (42, 18), -1.0, 1),     # 10 it falls back
    ((-14, -2), (18, 4), 0.0, 0),       # 11 settling
    ((-4, 0), (5, 0), 0.0, 0),          # 12 almost at rest (loops into 1)
]
HITS = [3, 7]
ATTACK_DUR = [130, 130, 60, 130, 100, 110, 70, 130, 100, 110, 120, 120]
SWEEPK = [1.0, 0.85, 1.0, -0.1, -0.15]  # how much of a blow's sweep across shows, per facing (from behind it turns a
                                        # little OUT instead, so the weight rises beside the shoulder, not behind it)
PITCHK = [0.0, 0.1, 0.25, 0.5, 0.6]     # how much of it becomes lift instead
WINDK = [0.72, 0.72, 1.0, 0.9, 0.9]     # the wind-up's reach per facing: from the front a full wind-up hides behind
                                        # the shoulder (or juts out sideways in 3/4), so it goes less far there
TUCKK = [1.0, 1.0, 0.0, 0.0, 0.0]       # a swung-back arm tucks in behind the hip only where "back" is away from us:
                                        # from behind, back is towards us and a tucked weight would hang in front of
                                        # the crotch
STAND = [(0.0, 0.0, 0.0), (0.0, 0.0, 0.0)]


def tucked(r, theta):
    """a walking arm turns in a little at the ends of its swing: swung away from us, in behind the hip; never in front
    of the crotch"""
    away = theta < 0 if r in (0, 1) else theta > 0
    k = (TUCKK[r] if r in (0, 1) else 0.5) if away else (0.4 if r in (0, 1) else 0.0)
    return TUCK * theta / ARM_WALK * k


def walk_pose(r, q):
    rl = right_leg(r)
    lp = [None, None]
    if r == 2:
        lp = [foot(q), foot(q + 0.5)]
    else:
        lp[rl] = foot(q)
        lp[1 - rl] = foot(q + 0.5)
    s = math.sin(2 * math.pi * q)
    c = math.cos(2 * math.pi * q)
    tr, tl = -ARM_WALK * c, ARM_WALK * c
    return dict(legs=lp, body=(SIDE[r] * ROCK * s, dip(q), LEAN * LEANK[r] + SIDE[r] * ROLL * s),
                arms={'right': (tr, tucked(r, tr)), 'left': (tl, tucked(r, tl))}, e_rest=WALK_REST)


def idle_pose(r, i):
    q = i / 4.0
    s = math.sin(2 * math.pi * q)
    c = math.cos(2 * math.pi * q)
    lean = (0.8 * s) if r == 2 else (SIDE[r] * 0.6 * s if SIDE[r] else 0.0)
    sway = (SIDE[r] if r != 2 else 0.0) * 1.5 * s
    return dict(legs=STAND, body=(sway, 1.0 * (1 - abs(c)), lean),
                arms={'right': (IDLE_ARM * s, 0.0), 'left': (-IDLE_ARM * s, 0.0)})


def blow(r, th, yw):
    if th > 0:
        return th + PITCHK[r] * yw, yw * SWEEPK[r]
    return th * WINDK[r], yw * TUCKK[r]


def attack_pose(r, i):
    (tr, yr), (tl, yl), lean, d = ATTACK[i]
    # the lean turns the body in the side views; seen from the front or back it dips a little more instead
    k = LEANK[r]
    return dict(legs=STAND, body=(0.0, d + (1 - k) * max(0.0, lean) * 0.5, lean * k),
                arms={'right': blow(r, tr, yr), 'left': blow(r, tl, yl)})


def frames_of(poses):
    return [[G.compose(r, p) for p in poses(r)] for r in range(5)]


def cell_for(*anims):
    """the smallest cell (sheet px, even sizes) that holds every frame with the unit's point in the middle across and
    10 px above the bottom"""
    L = U = 0.0
    for fr in anims:
        for r in range(5):
            ax, ay = G.anchor(r)
            for cv in fr[r]:
                x0, y0, x1, y1 = cv.getbbox()
                L = max(L, ax - (x0 - P.PAD), (x1 - P.PAD) - ax)
                U = max(U, ay - (y0 - P.PAD))
    cw = 2 * int(math.ceil(L + 4))
    ch = int(math.ceil(U + 4)) + (G.CH - G.GROUND)
    return cw + cw % 2, ch + ch % 2


def write(name, fr, cell, durs, marks=None):
    cw, ch = cell
    cells = [[G.to_cell(r, cv, cw=cw, ch=ch, ground=ch - (G.CH - G.GROUND)) for cv in fr[r]] for r in range(5)]
    G.save(name, cells, durs, marks, cw=cw, ch=ch)
    return cells


def all_anims():
    idle = frames_of(lambda r: [idle_pose(r, i) for i in range(4)])
    walk = frames_of(lambda r: [walk_pose(r, i / N_WALK) for i in range(N_WALK)])
    attack = frames_of(lambda r: [attack_pose(r, i) for i in range(12)])
    c1 = cell_for(idle, walk)
    c2 = cell_for(attack)
    print('cells: idle and walk %dx%d, attack %dx%d (sheet px; the unit\'s point at the middle, 10 px up)' % (c1 + c2))
    return dict(idle=write('pendulum_v2_idle', idle, c1, [220] * 4),
                walk=write('pendulum_v2_walk', walk, c1, 120),
                attack=write('pendulum_v2_attack', attack, c2, ATTACK_DUR, HITS))


def review(out):
    """contact sheets for checking: each animation at sheet scale and at game scale x3, frames numbered"""
    os.makedirs(out, exist_ok=True)
    A = all_anims()
    for name, cells in A.items():
        n = len(cells[0])
        cw, ch = cells[0][0].size
        big = Image.new('RGB', (n * cw, 5 * ch), P.NAVY)
        d = ImageDraw.Draw(big)
        for r in range(5):
            for i, c in enumerate(cells[r]):
                big.paste(c, (i * cw, r * ch), c)
                d.text((i * cw + 4, r * ch + 4), str(i + 1), fill=(255, 255, 0))
        big.save('%s/%s_big.png' % (out, name))
        sm = [[G.shrink(c) for c in row] for row in cells]
        w, h = sm[0][0].size
        g = Image.new('RGB', (n * w, 5 * h), P.NAVY)
        for r in range(5):
            for i, c in enumerate(sm[r]):
                g.paste(c, (i * w, r * h), c)
        g.resize((g.width * 3, g.height * 3), Image.NEAREST).save('%s/%s_game3x.png' % (out, name))
        g.save('%s/%s_game1x.png' % (out, name))


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'review':
        review(sys.argv[2])
    else:
        all_anims()
    print('ok')
