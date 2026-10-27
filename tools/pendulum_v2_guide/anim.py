"""Pendulum v2 IDLE, WALK and ATTACK in code from the painted parts (parts.py) on the rig (rig.py). Nothing hangs or
swings between the legs: the arms hang outside them, a swung-back weight tucks in behind the hip only where "back" is
away from us, and from behind it never comes in front of the crotch.

IDLE (4 frames): it stands and sways a little over its feet; the arms tick and tock a few degrees, in opposition.
WALK (8 frames): the old Pendulum's long stride (rig.py), driven by the arms: they swing in opposition, the arm
  opposite a leg forward as that leg steps (the left arm forward while the right leg is forward). From the side the
  near arm swings in front of the body and legs and the far one, darker, behind them; from the front and back a
  forward arm comes towards us (lower, bigger, in front of its leg), a back arm goes away (higher, smaller, darker,
  tucked behind the hip).
ATTACK (12 frames, two CUTTING blows: cut.py): the right arm (frames 1-6), then the left (frames 7-12). Each blow is a
  windmill chop with the crescent turned on its weight so its convex edge LEADS: the arm winds back and up over its
  shoulder (the edge turned forward, at the enemy), comes over the top, slashes forward and down through the space in
  front of the unit, follows through low past the target and settles, while the other arm swings a little against it.
  Side view: overhead to low in the picture plane; front: a diagonal from high on its own side to low across the body;
  back: from over the head down past its own hip (cut.TILT); 3/4 in between. A steel-white smear trails the edge on the
  slash frames. THE HITS: frames 4 and 10 (0-based 3 and 9; they were 4 and 8 when the two blows overlapped: now each
  blow is a strip of its own in the game, attack_r = frames 1-6, attack_l = frames 7-12, starting and ending at rest).

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

# the attack: two CUTTING blows (cut.py), the right arm (frames 1-6, THE HIT on frame 4), then the left (frames 7-12,
# THE HIT on frame 10). Each blow is a windmill chop, the blade turned on its weight so its convex edge leads: the arm
# winds back and up over its shoulder (the edge turned forward, towards the enemy), comes over the top and slashes
# forward and down through the space in front of the unit (side view: overhead to low in the picture plane; front and
# back: a diagonal from high on its own side to low across the body), follows through past the target and settles.
# The other arm swings a little against it. Per frame of a blow: the striking arm (windmill theta, blow weight w, blade
# turn beta), the other arm (theta: + forward), the body's lean (deg, + into the blow) and dip (px).
BLOW = [
    ((-55, 0.5, 0.55), 6, -1.5, 0),     # 1  it winds back, the edge turning to lead
    ((-150, 1.0, 1.0), 12, -3.0, 1),    # 2  wound up, high over its shoulder: the edge faces forward, at the enemy
    ((-205, 1.0, 1.0), 4, 1.0, 2),      # 3  over the top, fast
    ((-255, 1.0, 1.0), -8, 4.0, 3),     # 4  THE HIT: forward of the shoulder, chopping down into the enemy
    ((-310, 1.0, 1.0), -12, 3.0, 2),    # 5  follow-through: low, past the target
    ((-345, 0.45, 0.4), -4, 0.5, 1),    # 6  it settles back to the hang
]
LAG = [30.0, 20.0, 0.0, 20.0, 30.0]    # per facing: the chop runs this much further (deg) by the hit; seen from the front or
                                        # the back the arm points at (or away from) us as it passes forward, its weight on the
                                        # shoulder: a little further on it is already slashing down and across the body
LAGW = [0.0, 0.0, 0.6, 1.0, 0.7, 0.0]   # ... per frame of a blow
SMEARED = {2: 3, 3: 5, 4: 5}            # frames of a blow with a smear behind the edge (and its length in steps)
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
    """frame i of the two-blow cut (0-5 the right arm's blow, 6-11 the left's)"""
    k_ = i % 6
    (th, w, beta), other, lean, d = BLOW[k_]
    th -= LAG[r] * LAGW[k_]
    strike = {'th': th, 'w': w, 'beta': beta}
    if k_ in SMEARED:
        prev = BLOW[k_ - 1][0][0] - LAG[r] * LAGW[k_ - 1]
        n = SMEARED[k_]
        strike['trail'] = [(prev + (th - prev) * j / float(n), w, beta) for j in range(n)]
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
