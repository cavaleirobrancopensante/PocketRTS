"""Shared leg-rebuild for the gait passes (tools/import_gait_<unit>.py), after tools/import_labourer_gait.py.

A man's walk strip keeps each frame's torso, head, arms and gear (every row above the hip line `cut`) and
the legs below it are drawn again in code, with hard pixels in the colours the frame's own legs had:

  side / diagonal views (e, se, ne; the west views are these mirrored by DIR_FLIP in unit.gd):
      one foot after the other. Each foot has a phase; the other is half a cycle behind. In the first half
      of its cycle a foot is planted and slides back (heel strike ahead of the body, flat, then toe push-off);
      in the second half it swings forward, lifted, knee forward. The body drops 1 px at the passing frames
      and is 1 px higher when the legs cross.
  front / back views (s, n): two legs side by side; each foot lifts in turn (the lifted boot rises and the
      leg is shorter), the body dips on the planted frame, the feet spread a pixel as they pass.

The feet stand on the strip's ground line (median bottom row), the frame count and cell size are unchanged.
Every pass keeps a pristine snapshot of its source strips in art/redraws/gait_src/<unit>/ so reruns are idempotent.
"""
import math
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lum(c):
    return 0.3 * int(c[0]) + 0.59 * int(c[1]) + 0.11 * int(c[2])


def tri(px, fallback):
    """light / mid / dark colours picked from real pixels of a region (list of RGB)."""
    if len(px) < 3:
        return fallback
    px = sorted(px, key=lum)
    n = len(px)
    return [tuple(int(v) for v in px[min(n - 1, int(n * .85))]), tuple(int(v) for v in px[n // 2]),
            tuple(int(v) for v in px[int(n * .1)])]


def put(f, x, y, c):
    h, w = f.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        f[y, x, :3] = c
        f[y, x, 3] = 255


def seg(f, x0, y0, x1, y1, wid, cols):
    ya, yb = int(round(min(y0, y1))), int(round(max(y0, y1)))
    for y in range(ya, yb + 1):
        t = 0.0 if y1 == y0 else min(max((y - y0) / (y1 - y0), 0.0), 1.0)
        cx = x0 + (x1 - x0) * t
        xl = int(round(cx - wid / 2.0 + 0.001))
        for i in range(wid):
            c = cols[0] if i == 0 and wid > 2 else cols[2] if i == wid - 1 else cols[1]
            put(f, xl + i, y, c)


def boot(f, hx, fy, kind, cols, L, bh, wid):
    """boot with its heel column at hx, sole on row fy, toe forward (+x); bh rows tall."""
    lt, md, dk = cols
    for k in range(bh):                      # k = 0 sole ... bh-1 top of the shaft
        y = fy - k
        if kind == "toe":                    # push-off: only the toe is down, heel raised and trailing
            a, b = (L - max(2, L // 2), L) if k == 0 else (0, wid) if k > 1 else (1, L - 1)
        elif kind == "swing" and k == 0:     # lifted boot, toe hanging
            a, b = 0, L - 1
        else:
            a, b = 0, (L if k < 2 else wid)
        for x in range(a, b):
            c = lt if k == bh - 1 else dk if (k == 0 and kind != "toe") else md
            put(f, hx + x, y, c)


def foot_state(phi, amp, lift):
    """x offset (px, + = ahead), lift (px), kind for a foot at cycle phase phi in [0, 1)."""
    phi %= 1.0
    if phi < 0.5:
        t = phi / 0.5
        x = amp - 2 * amp * t
        return x, 0, ("heel" if t < 0.12 else "toe" if t > 0.85 else "flat")
    u = (phi - 0.5) / 0.5
    x = -amp + 2 * amp * u
    l = lift * math.sin(math.pi * u)
    return x, int(round(l)), ("swing" if l >= 0.6 else "flat")


def build_frame(fr, k, n, d, P, ground, pal):
    """P: legH, cut_from_ground, legw, boot_L, boot_h, amp, lift, bob (dict)."""
    H, W = fr.shape[:2]
    cut = ground - P["legH"] + 1
    alpha = fr[..., 3] > 40
    out = np.zeros_like(fr)
    phi = k / n
    side = d in ("e", "se", "ne")
    amp = P["amp"] * (0.72 if d in ("se", "ne") else 1.0)
    xa, la, ka = foot_state(phi, amp, P["lift"])
    xb, lb, kb = foot_state(phi + 0.5, amp, P["lift"])
    # body bob: 1 px up at the passing frames (side views) / while a boot is at the top of its swing (front)
    dy = 0
    if n >= 4 and P.get("bob", 1):
        if side and abs(xa) < amp * 0.45:
            dy = -1
        if not side and max(la, lb) >= max(1, P["lift"] - 1):
            dy = -1
    # torso
    xs = np.nonzero(alpha[cut - 2:cut + 1].any(0))[0]
    cx = int(round(xs.mean())) if len(xs) else W // 2
    if P.get("cx") is not None:
        cx = cx + P["cx"] if P["cx"] < 8 else P["cx"]
    body = fr.copy()
    body[cut:] = 0
    for y in range(cut):
        ny = y + dy
        if 0 <= ny < H:
            out[ny] = body[y]
    ytop = cut + dy
    lw = P["legw"]
    tn, bn = pal["trouser"], pal["boot"]
    tf = [pal["trouser_far"][i] for i in range(3)]
    bf = [pal["boot_far"][i] for i in range(3)]
    # hip block (joins torso to the legs)
    hw = lw if side else P.get('spread', 2) + lw // 2 + 1
    for y in range(ytop, ytop + P.get("hip", 2)):
        for x in range(cx - hw, cx + hw + 1):
            put(out, x, y, tf[1] if x < cx else tn[1])
    BL, BH = P["boot_L"], P["boot_h"]

    def side_leg(hipx, x, lift, kind, cols_t, cols_b, ydepth):
        fy = ground - lift - ydepth
        hx = cx - BL // 2 - 1 + int(round(x))
        ax = hx + 1.5
        ay = fy - BH + 1
        if kind == "swing":
            kx = hipx + P.get("knee", 2)
            ky = ytop + max(2, (ay - ytop) // 2)
            seg(out, hipx, ytop + 1, kx, ky, lw, cols_t)
            seg(out, kx, ky + 1, ax, ay, max(2, lw - 1), cols_t)
        else:
            seg(out, hipx, ytop + 1, ax, ay, lw, cols_t)
        boot(out, hx, fy, kind, cols_b, BL, BH, max(3, lw))

    if side:
        far = (cx - 1, xb, lb, kb, tf, bf)
        near = (cx + 1, xa, la, ka, tn, bn)
        for (hip, x, l, kd, ct, cb) in (far, near):
            dep = 0
            if d == "se" and x < 0 and min(la, lb) == 0:
                dep = 1
            if d == "ne" and x > 0 and min(la, lb) == 0:
                dep = 1
            side_leg(hip, x, l, kd, ct, cb, dep)
    else:
        sp = P.get("spread", 2)
        lifts = (la, lb)
        for i, (lx, l) in enumerate(((cx - sp - lw // 2, la), (cx + sp - lw // 2 + 1, lb))):
            cols_t = tf if i == 0 else tn
            cols_b = bf if i == 0 else bn
            fy = ground - l
            ay = fy - BH + 1
            seg(out, lx + lw / 2.0 - 0.5, ytop + 1, lx + lw / 2.0 - 0.5, ay, lw, cols_t)
            bw = lw + 1
            for kk in range(BH):
                for xx in range(bw):
                    c = cols_b[1]
                    if kk == BH - 1:
                        c = cols_b[0]
                    if kk == 0:
                        c = cols_b[2]
                    put(out, lx - 1 + xx + (0 if i == 0 else 0), fy - kk, c)
    return out


def _skip(p):
    """pixels never sampled as leg colour: the bright red crest / tail and yellow claw tips (raptor)."""
    return (int(p[0]) > 1.6 * int(p[1]) + 15 and p[0] > 60) or (p[0] > 170 and p[1] > 170 and p[2] < 90)


def sample_palette(frs, ground, legH, skip=False):
    """trouser and boot colours from the leg zones of all frames (real pixels of the source art)."""
    px, bp = [], []
    for fr in frs:
        reg = fr[ground - legH + 1:ground - 3]
        px += [tuple(p[:3]) for p in reg.reshape(-1, 4) if p[3] > 200 and not (skip and _skip(p))]
        bt = fr[ground - 2:ground + 1]
        bp += [tuple(p[:3]) for p in bt.reshape(-1, 4) if p[3] > 200 and not (skip and _skip(p))]
    trouser = tri(px, [(120, 120, 120), (90, 90, 90), (50, 50, 50)])
    boot = tri(bp, [(120, 70, 30), (90, 50, 20), (40, 20, 5)])

    def shade(c, f):
        return [tuple(int(v * f) for v in col) for col in c]
    return {"trouser": trouser, "boot": boot, "trouser_far": shade(trouser, 0.82), "boot_far": shade(boot, 0.82)}


class Pass:
    """One unit's gait pass: strips walk_<d>.png of assets/units/<art>."""

    def __init__(self, art, cell, params, dirs=("s", "se", "e", "ne", "n"), pose="walk"):
        self.art, self.cell, self.P, self.dirs, self.pose = art, cell, params, dirs, pose
        self.out = os.path.join(ROOT, "assets/units", art)
        self.src = os.path.join(ROOT, "art/redraws/gait_src", art)

    def p(self, d):
        return os.path.join(self.out, f"{self.pose}_{d}.png")

    def snapshot(self):
        os.makedirs(self.src, exist_ok=True)
        for d in self.dirs:
            shutil.copy(self.p(d), os.path.join(self.src, f"{self.pose}_{d}.png"))

    def run(self):
        if not os.path.isdir(self.src):
            self.snapshot()
        cw = self.cell[0]
        for d in self.dirs:
            im = np.array(Image.open(os.path.join(self.src, f"{self.pose}_{d}.png")).convert("RGBA"))
            n = im.shape[1] // cw
            frs = [im[:, i * cw:(i + 1) * cw] for i in range(n)]
            bots = [np.nonzero((f[..., 3] > 40).any(1))[0][-1] for f in frs]
            ground = int(np.median(bots))
            P = self.P.get(d, self.P["*"]) if "*" in self.P or d in self.P else self.P
            pal = sample_palette(frs, ground, P["legH"], P.get("skip_bright", False))
            outs = [build_frame(f, i, n, d, P, ground, pal) for i, f in enumerate(frs)]
            Image.fromarray(np.concatenate(outs, 1)).save(self.p(d))


def contact(art, cell, path, dirs=("s", "se", "e", "ne", "n"), zoom=4, pose="walk"):
    rows = [Image.open(os.path.join(ROOT, f"assets/units/{art}/{pose}_{d}.png")).convert("RGBA") for d in dirs]
    W = max(r.width for r in rows)
    H = sum(r.height + 2 for r in rows)
    s = Image.new("RGBA", (W, H), (60, 90, 60, 255))
    y = 0
    for r in rows:
        s.alpha_composite(r, (0, y))
        y += r.height + 2
    s.resize((W * zoom, H * zoom), Image.NEAREST).save(path)
