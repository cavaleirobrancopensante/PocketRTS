"""Pendulum v2 ATTACK as a LOW SWEEP (owner, 2026-10-27: "the pendulum attack is overhead, but it shouldn't be, because it
is a ground unit that mostly kills Raptors, so it should be sweeping the ground"; and earlier: "the blades should always
face the enemy, or at least be a cutting motion, not just a shoving"). The windmill chop over the shoulder is gone: each
blow is a SCYTHE stroke that mows at ankle height, the crescent's edge leading.

THE ARM (a 3D direction, projected per facing like parts.arm_screen) hangs from its shoulder on a CONE about the
vertical: d = cos(c) down + sin(c) h(phi), h(phi) = cos(phi) out + sin(phi) F, where out is the arm's own side (the
robot's right for the right arm), F the robot's forward axis and c the cone's opening (how far the weight is swung out
of the hang). Swinging phi turns the weight round the shoulder at (nearly) one height, so it stays LOW:
  phi = -90 straight back, 0 out to its own side, +90 straight forward, +150 across the front of the body.
A blow swings BACK (phi to about -75, never up over the shoulder), then sweeps FORWARD and ACROSS (phi climbing past
its own side, through the front, to the far side), follows through low and settles. The hang is the painted rest
direction (rest_dir, as the old guide); a pose blends it with the cone by its blow weight w.
  - side view (E): a low forward arc, the weight and blade skimming just above the ground in front of the feet;
  - front: a sweep across the front of the body at the feet's height;
  - back: the same sweep, seen from behind: it is CUT SHORT (CROSS) so the weight never passes behind the gap between
    the legs (from behind it must never read as the old pendulum hanging between the legs);
  - 3/4 views: in between.
The body dips (the knees give) and leans into the blow, so the swung-out weight (a cone lifts it a little) still runs
at ankle height.

THE BLADE turns on its weight (beta 0..1): at 0 it hangs under the ball as painted (rest, idle, walk); at 1 the
crescent's convex EDGE points along LEAD = the weight's travel round the cone bent towards the front and down (travel +
forward + down, so the blade dips under the weight towards the ground), its horns square to it: so through the sweep the edge LEADS, and at the hit (the weight in front of its own shoulder,
coming round) it faces forward, at the target; through the follow-through it leads across. Its paint is mapped to the
screen by an affine map (the crescent is flat), foreshortened with the rod but never under 0.6 of its width (an edge-on
crescent would be a line at game scale: CODE EDIT, a readability floor).

THE SLEEVE, CLAMP and ROD follow the arm (the rod turned and stretched or shortened along its length, the sleeve and
clamp turned and squashed along the rod, their width kept); the BALL is only moved and scaled (a sphere); a weight
swung towards the camera grows (to 1.22x), one swung away shrinks and darkens (parts.DEPTH_SCALE / DEPTH_DARK).

THE SMEAR: on the sweep frames a faint steel-white streak trails the blade's edge along its low path (CODE-DRAWN,
docs/art_style_inconsistency.md), so the cut reads at game scale.

A pose q is a dict: th (the hang's own forward swing, deg: the other arm's counter-swing), phi, c (deg), w (0 hang ..
1 on the cone), beta (the blade's turn)."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parts as P
from parts import place, sub

EDGE_FLOOR = 0.6                       # the crescent's width never shows under this share of its painted width
LEAD_FWD = 0.7                         # the edge's lead: the travel round the cone + this much of the forward axis
LEAD_DOWN = 0.55                       # ... + this much of straight down: the blade dips under the weight, skimming the ground


def _axes(r, robot_right):
    a = math.radians(P.AZ[r])
    Fw = np.array([math.sin(a), math.cos(a), 0.0])          # forward (world: x east, y towards the camera, z up)
    Rw = np.array([-math.cos(a), math.sin(a), 0.0])          # the robot's right
    return a, Fw, Rw


def proj(v):
    return np.array([v[0], P.K * v[1] - v[2]])


def rest_frame(r, arm):
    """(down, out, F, sigma deg, length) of an arm: out = the side its painted arm splays to, sigma its painted splay
    (the side view: the arm's own side, no splay; its rest hang forward is parts.E_REST, added to th)"""
    g = arm['geo']
    robot_right = arm['cfg']['robot'] == 'right'
    a, Fw, Rw = _axes(r, robot_right)
    down = np.array([0.0, 0.0, -1.0])
    if r == 2:
        out = Rw if robot_right else -Rw
        return down, out, Fw, 0.0, P.E_LEN
    C = np.array(g['C']) - np.array(arm['pivot'])
    out = np.array([1.0 if C[0] >= 0 else -1.0, 0.0, 0.0])
    return down, out, Fw, math.degrees(math.atan2(abs(C[0]), C[1])), float(np.linalg.norm(C))


def rest_dir(r, arm, th):
    """the hang, swung th deg forward in its painted plane (the idle's and the other arm's)"""
    down, out, F, sigma, L = rest_frame(r, arm)
    s = math.radians(sigma)
    t = math.radians(th + (P.E_REST if r == 2 else 0.0))
    v = math.cos(s) * down + math.sin(s) * out
    d = math.cos(t) * v + math.sin(t) * F
    return d / np.linalg.norm(d), L


def cone_dir(r, arm, phi, c):
    """the arm on the cone: c deg out of the vertical, at azimuth phi round the shoulder (0 its own side, 90 forward)"""
    robot_right = arm['cfg']['robot'] == 'right'
    a, F, Rw = _axes(r, robot_right)
    out = Rw if robot_right else -Rw
    p, cc = math.radians(phi), math.radians(c)
    h = math.cos(p) * out + math.sin(p) * F
    return math.cos(cc) * np.array([0.0, 0.0, -1.0]) + math.sin(cc) * h, F, out


def direction(r, arm, q, dphi=0.0):
    """the arm's 3D unit direction for pose q (see the top)"""
    d0, L = rest_dir(r, arm, q.get('th', 0.0))
    w = q.get('w', 0.0)
    if w <= 0.0:
        return d0, L
    d1 = cone_dir(r, arm, q['phi'] + dphi, q['c'])[0]
    d = (1.0 - w) * d0 + w * d1
    return d / np.linalg.norm(d), L


def _perp(v):
    return np.array([-v[1], v[0]])


def _unit(v, fallback):
    n = float(np.linalg.norm(v))
    return (v / n, n) if n > 1e-4 else (np.array(fallback, float), 0.0)


def cut_screen(r, arm, q):
    """screen offsets and maps of an arm for pose q: the weight's centre offset from the pivot, the head's map, the
    blade's map, the depth of the weight (px towards the camera), the arm's length and the edge's screen direction"""
    g = arm['geo']
    robot_right = arm['cfg']['robot'] == 'right'
    a = math.radians(P.AZ[r])
    side = 1.0 if robot_right else -1.0
    d, L = direction(r, arm, q)
    beta = q.get('beta', 0.0)
    if q.get('w', 0.0) > 0.0:
        # the travel round the cone (phi climbing), bent towards the front: the way the edge leads
        t3, _ = _unit(direction(r, arm, q, 2.0)[0] - direction(r, arm, q, -2.0)[0], d)
        F = _axes(r, robot_right)[1]
        lead, _ = _unit(t3 + LEAD_FWD * F + LEAD_DOWN * np.array([0.0, 0.0, -1.0]), t3)
        lead = lead - d * float(lead @ d)          # square to the rod (the blade turns on the weight)
        lead, _ = _unit(lead, t3)
    else:
        lead = d
    v = proj(d) * L
    u_p = np.array(g['u'], float)
    n_p = _perp(u_p)
    Pm = np.linalg.inv(np.column_stack([u_p, n_p]))
    a_s, la = _unit(proj(d), u_p)
    la = max(la, 0.25)
    Mh = np.column_stack([a_s * la, _perp(a_s)]) @ Pm
    # the blade: the edge turned from along the rod (beta 0) to the lead (beta 1)
    b = beta * math.pi / 2
    edge = math.cos(b) * d + math.sin(b) * lead
    e_s, le = _unit(proj(edge), a_s)
    le = max(le, 0.75)
    lh = 1.0 + (max(EDGE_FLOOR, min(1.0, la)) - 1.0) * math.sin(b)
    Mb = np.column_stack([e_s * le, _perp(e_s) * lh]) @ Pm
    depth = side * P.SHOULDER * math.sin(a) + float(d[1]) * L
    return v, Mh, Mb, depth, L, e_s


def cut_layers(r, arm, pivot_s, q, dark=None):
    """the arm's paint (as parts.arm_layers: [(name, image)], depth, the weight's screen centre)"""
    g = arm['geo']
    lay = arm['lay']
    v, Mh, Mb, depth, L, e_s = cut_screen(r, arm, q)
    rest = cut_screen(r, arm, {})[3]
    dd = depth - rest
    C1 = (pivot_s[0] + v[0], pivot_s[1] + v[1])
    s, k = 1.0, 1.0
    if r != 2:
        s = max(0.85, min(1.22, 1.0 + P.DEPTH_SCALE * dd / L))
        if dd < 0:
            k = 1.0 - P.DEPTH_DARK * min(1.0, -dd / L)
    if dark is not None:
        k *= dark
    head = place(lay['head'], g['C'], C1, Mh * s)
    blade = place(lay['blade'], g['C'], C1, Mb * s)
    ball = place(lay['ball'], g['C'], C1, np.eye(2) * s)
    S0 = np.array(g['S'])
    S1 = np.array(C1) + (Mh * s) @ (S0 - np.array(g['C']))
    P0 = np.array(g['T'])
    rod = place(lay['rod'], tuple(P0), pivot_s, P.matrix(tuple(S0 - P0), tuple(S1 - np.array(pivot_s))))
    out = [('rod', rod), ('blade', blade), ('ball', ball), ('head', head)]
    if k != 1.0:
        out = [(n_, P.shade(im, k)) for n_, im in out]
    return out, depth, C1


# ------------------------------------------------------------------------------------------------ the smear
def edge_point(r, arm, pivot_s, q):
    """the blade's leading edge on screen (the crescent's outer middle, carried by the blade's map)"""
    g = arm['geo']
    v, Mh, Mb, depth, L, e_s = cut_screen(r, arm, q)
    C1 = np.array(pivot_s) + v
    # the painted blade's outer middle: the farthest blade pixel along the painted arm axis from the ball
    tip = arm.setdefault('_edge_off', _edge_off(arm))
    return C1 + Mb @ tip, depth


def _edge_off(arm):
    g = arm['geo']
    a = np.array(arm['lay']['blade'])[..., 3] > 0
    ys, xs = np.nonzero(a)
    pts = np.c_[xs - P.PAD, ys - P.PAD] - np.array(g['C'])
    u = np.array(g['u'])
    t = pts @ u
    sel = t >= np.percentile(t, 96)
    return pts[sel].mean(0)


SMEAR = (232, 238, 244)      # steel white
SMEAR_W = 26                 # its widest (sheet px; ~3 px in game)


def smear(cv, pts, width):
    """a tapering streak along screen points pts (oldest first), see-through, onto canvas cv (padded coordinates)"""
    if len(pts) < 2:
        return
    lay = Image.new('RGBA', cv.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    n = len(pts)
    for i in range(n - 1):
        f = (i + 1) / float(n - 1)
        wdt = max(1, int(round(width * f)))
        al = int(50 + 170 * f)
        p0 = (pts[i][0] + P.PAD, pts[i][1] + P.PAD)
        p1 = (pts[i + 1][0] + P.PAD, pts[i + 1][1] + P.PAD)
        d.line([p0, p1], fill=SMEAR + (al,), width=wdt)
        d.ellipse([p1[0] - wdt / 2, p1[1] - wdt / 2, p1[0] + wdt / 2, p1[1] + wdt / 2], fill=SMEAR + (al,))
    cv.alpha_composite(lay)
