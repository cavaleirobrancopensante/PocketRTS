"""Pendulum v2 ATTACK as a CUT (owner, 2026-10-26: "the blades should always face the enemy or at least be a cutting
motion, not just a shoving"). The first guide swung each arm forward like a punch: the weight led and the blade trailed
under it, its flat face first. Here each blow is a windmill CHOP and the crescent's convex edge LEADS the whole way.

THE ARM (a 3D direction, projected per facing like parts.arm_screen): the arm turns on its shoulder in a swing plane
that holds the robot's forward axis F and a tilted "down" v(tau) = cos(tau) down + sin(tau) out (out = the arm's own
side). At rest tau is the painted splay (the arm hangs exactly as painted); during a blow the plane tilts the other
way (tau = -TILT: "down" leans IN across the body), so a blow that goes back, up over the shoulder (up and OUT), then
forward and down (down and IN, across the front of the body) is
  - seen from the side (E, TILT 0): an overhead-to-low forward arc in the picture plane;
  - seen from the front or the back: a diagonal slash from high on its own side to low across the body;
  - the 3/4 views: in between.
  theta (deg) runs the windmill: 0 = hanging at rest, -90 = straight back, -180 = straight up, -270 = straight forward,
  -360 = hanging again; a blow only ever turns one way (theta falling), so the travel never reverses mid-stroke.

THE BLADE turns on its weight (beta 0..1): at 0 it hangs under the ball as painted (rest, idle, walk); at 1 the
crescent lies in the swing plane with its convex EDGE pointing the way the weight travels (the tangent of the windmill)
and its horns along the rod, like an axe head: so it leads the wind-up (back and up), points forward-up at the top of
the wind-up (towards the enemy) and leads the chop down into the space in front, where the enemy stands. Its paint is
mapped to the screen by an affine map (the crescent is flat): the edge's screen direction from the projected tangent,
the horn axis square to it, foreshortened with the rod but never under 0.6 of its width (an edge-on crescent would be
a line at game scale: CODE EDIT, a readability floor).

THE SLEEVE, CLAMP and ROD follow the arm (the rod turned and stretched or shortened along its length, the sleeve and
clamp turned and squashed along the rod, their width kept); the BALL is only moved and scaled (a sphere); a weight
swung towards the camera grows (to 1.22x), one swung away shrinks and darkens (parts.DEPTH_SCALE / DEPTH_DARK).

THE SMEAR: on the slash frames a faint steel-white crescent of motion blur trails the blade's edge along its path
(CODE-DRAWN, docs/art_style_inconsistency.md), so the cut reads at game scale."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parts as P
from parts import place, sub

TILT = [36.0, 30.0, 0.0, -24.0, -30.0] # how far a blow's swing plane leans across the body, per facing (deg). Seen from
                                       # BEHIND a slash across the front of the body would pass out of sight behind the
                                       # case, so the back views lean it the other way (from over the head down past its
                                       # own hip, beside the body): a fudge for readability, a view-only choice
EDGE_FLOOR = 0.6                       # the crescent's width never shows under this share of its painted width


def _axes(r, robot_right):
    a = math.radians(P.AZ[r])
    Fw = np.array([math.sin(a), math.cos(a), 0.0])          # forward (world: x east, y towards the camera, z up)
    Rw = np.array([-math.cos(a), math.sin(a), 0.0])          # the robot's right
    return a, Fw, Rw


def proj(v):
    return np.array([v[0], P.K * v[1] - v[2]])


def rest_frame(r, arm):
    """(down, out, F, sigma deg, length) of an arm: out = the side its painted arm splays to, sigma its painted splay
    (the side view: the arm's own side, no splay; its rest hang forward is parts.E_REST, added to theta)"""
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


def direction(r, arm, theta, w):
    """the arm's 3D unit direction for windmill angle theta (deg) and blow weight w (0 rest .. 1 in the blow)"""
    down, out, F, sigma, L = rest_frame(r, arm)
    tau = math.radians(sigma + (-TILT[r] - sigma) * w)
    th = math.radians(theta + (P.E_REST if r == 2 else 0.0))    # (+ forward from hanging)
    v = math.cos(tau) * down + math.sin(tau) * out
    d = math.cos(th) * v + math.sin(th) * F
    return d / np.linalg.norm(d), L


def _perp(v):
    return np.array([-v[1], v[0]])


def _unit(v, fallback):
    n = float(np.linalg.norm(v))
    return (v / n, n) if n > 1e-4 else (np.array(fallback, float), 0.0)


def cut_screen(r, arm, theta, w, beta):
    """screen offsets and maps of an arm for (theta, w, beta): the weight's centre offset from the pivot, the head's
    map, the blade's map, the depth of the weight (px towards the camera) and the edge's screen direction"""
    g = arm['geo']
    robot_right = arm['cfg']['robot'] == 'right'
    a = math.radians(P.AZ[r])
    side = 1.0 if robot_right else -1.0
    d, L = direction(r, arm, theta, w)
    # the travel (theta falling): the tangent, from two nearby directions
    d1, _ = direction(r, arm, theta - 2.0, w)
    d0, _ = direction(r, arm, theta + 2.0, w)
    t3, _ = _unit(d1 - d0, d)
    v = proj(d) * L
    u_p = np.array(g['u'], float)
    n_p = _perp(u_p)
    Pm = np.linalg.inv(np.column_stack([u_p, n_p]))
    a_s, la = _unit(proj(d), u_p)
    la = max(la, 0.25)
    Mh = np.column_stack([a_s * la, _perp(a_s)]) @ Pm
    # the blade: the edge turned from along the rod (beta 0) to the travel (beta 1), in the swing plane
    b = beta * math.pi / 2
    edge = math.cos(b) * d + math.sin(b) * t3
    e_s, le = _unit(proj(edge), a_s)
    le = max(le, 0.75)
    lh = 1.0 + (max(EDGE_FLOOR, min(1.0, la)) - 1.0) * math.sin(b)
    Mb = np.column_stack([e_s * le, _perp(e_s) * lh]) @ Pm
    depth = side * P.SHOULDER * math.sin(a) + float(d[1]) * L
    return v, Mh, Mb, depth, L, e_s


def cut_layers(r, arm, pivot_s, theta, w, beta, dark=None):
    """the arm's paint (as parts.arm_layers: [(name, image)], depth, the weight's screen centre)"""
    g = arm['geo']
    lay = arm['lay']
    v, Mh, Mb, depth, L, e_s = cut_screen(r, arm, theta, w, beta)
    rest = cut_screen(r, arm, 0.0, 0.0, 0.0)[3]
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
def edge_point(r, arm, pivot_s, theta, w, beta):
    """the blade's leading edge on screen (the crescent's outer middle, carried by the blade's map)"""
    g = arm['geo']
    v, Mh, Mb, depth, L, e_s = cut_screen(r, arm, theta, w, beta)
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
