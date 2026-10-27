"""Pendulum v2 IDLE, WALK and ATTACK in code from the painted parts (parts.py) on the rig (rig.py). Nothing hangs or
swings between the legs: the arms hang outside them, a swung-back weight tucks in behind the hip only where "back" is
away from us, and from behind it never comes in front of the crotch.

IDLE (4 frames): it stands and sways a little over its feet; the arms tick and tock a few degrees, in opposition.
WALK (8 frames): the old Pendulum's long stride (rig.py), driven by the arms: they swing in opposition, the arm
  opposite a leg forward as that leg steps (the left arm forward while the right leg is forward). From the side the
  near arm swings in front of the body and legs and the far one, darker, behind them; from the front and back a
  forward arm comes towards us (lower, bigger, in front of its leg), a back arm goes away (higher, smaller, darker,
  tucked behind the hip).
ATTACK (12 frames, two LOW SWEEPS: cut.py): the right arm (frames 1-6), then the left (frames 7-12). Each blow is a
  scythe stroke at ankle height (owner, 2026-10-27: a ground unit that mostly kills Raptors sweeps the ground): the arm
  turns on a cone round its shoulder, swings BACK behind its hip (not up), then sweeps forward and across just above the
  ground in front of the feet, the crescent's edge leading and facing the target at the hit, follows through low and
  settles; the knees give and the body leans into it so the weight runs low, while the other arm swings a little
  against it. Side view: a low forward arc in front of the feet; front: across the front of the body at the feet's
  height; back: cut short beside its own leg (CROSS: from behind nothing may pass behind the gap between the legs);
  3/4 in between. A steel-white smear trails the edge on the sweep frames. THE HITS: frames 4 and 10 (0-based 3 and 9);
  each blow is a strip of its own in the game (attack_r = frames 1-6, attack_l = frames 7-12, starting and ending at
  rest).

Out (sheet px; the unit's point, under the case's middle on the ground, at the middle of each cell 10 px above its
bottom): art/redraws/pendulum_v2_idle.png (rows S, SE, E, NE, N x 4 frames) and pendulum_v2_walk.png (5 x 8), cells
236 x 302; pendulum_v2_attack.png (5 x 12), cells 314 x 368 (the sizes are worked out from the frames); and a GIF of
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

# the attack: two LOW SWEEPS (cut.py), the right arm (frames 1-6, THE HIT on frame 4), then the left (frames 7-12, THE
# HIT on frame 10). Each blow is a scythe stroke at ankle height: the arm swings BACK (not up), then sweeps forward and
# across low in front of the unit, the blade's edge leading and facing the target at the hit, follows through low past
# it and settles. The other arm swings a little against it. Per frame of a blow: the striking arm (phi round the
# shoulder: -90 back, 0 its own side, 90 forward, 150 across the front; c how far out of the hang; blow weight w; blade
# turn beta), the other arm (th: + forward), the body's lean (deg, + into the blow) and dip (px, down: the knees give).
BLOW = [
    ((-45, 20, 0.55, 0.5), 6, -1.0, 6),     # 1  it swings back, low, the edge turning to lead; the knees start to give
    ((-75, 34, 1.0, 0.9), 12, -2.0, 16),    # 2  swung back behind its hip, out and low: the edge faces forward
    ((15, 30, 1.0, 1.0), 4, 3.0, 26),       # 3  sweeping forward fast, skimming the ground beside its feet
    ((70, 26, 1.0, 1.0), -8, 7.0, 30),      # 4  THE HIT: in front of the feet, at ankle height, the edge at the target
    ((135, 28, 1.0, 1.0), -12, 5.0, 24),    # 5  follow-through: low, across the front, past the target
    ((120, 14, 0.45, 0.4), -4, 1.0, 8),     # 6  it rises and settles back to the hang
]
CROSS = [165.0, 150.0, 120.0, 80.0, 75.0]  # per facing: the farthest round the front a sweep goes (phi). From behind,
                                        # a weight that crossed the front would show through the gap between the legs
                                        # (the old pendulum's look): there the sweep stops beside its own leg
SMEARED = {2: 4, 3: 4, 4: 4}            # frames of a blow with a smear behind the edge (and its length in steps)
HITS = [3, 9]
BLOW_DUR = [130, 150, 70, 90, 100, 140]
ATTACK_DUR = BLOW_DUR * 2
TUCKK = [1.0, 1.0, 0.0, 0.0, 0.0]       # a swung-back walking arm tucks in behind the hip only where "back" is away from
                                        # us: from behind, back is towards us and a tucked weight would hang in front of
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


def attack_pose(r, i):
    """frame i of the two-blow sweep (0-5 the right arm's blow, 6-11 the left's)"""
    k_ = i % 6

    def q_of(j):
        (phi, c, w, beta) = BLOW[j][0]
        return {'phi': min(float(phi), CROSS[r]), 'c': float(c), 'w': w, 'beta': beta}
    strike = q_of(k_)
    other, lean, d = BLOW[k_][1:]
    if k_ in SMEARED:
        q0 = q_of(k_ - 1)
        n = SMEARED[k_]
        strike['trail'] = [{'phi': q0['phi'] + (strike['phi'] - q0['phi']) * j / float(n),
                            'c': q0['c'] + (strike['c'] - q0['c']) * j / float(n),
                            'w': strike['w'], 'beta': strike['beta']} for j in range(n)]
    rest = {'th': float(other), 'w': 0.0, 'beta': 0.0}
    arms = {'right': strike, 'left': rest} if i < 6 else {'right': rest, 'left': strike}
    k = LEANK[r]
    return dict(legs=STAND, body=(0.0, d + (1 - k) * max(0.0, lean) * 0.5, lean * k), arms=arms)


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
