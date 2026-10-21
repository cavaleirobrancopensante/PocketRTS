"""The Crown Observation Balloon, second basket: the wide wicker basket with its pilot,
hung under the envelope of the first sheet, and the pilot's rope and powder barrel.

Sources:
  art/crown/balloon_v2.png            the envelope (drift / idle / death), as in
                                      tools/import_balloon.py (its old small basket is cut off)
  art/crown/balloon_basket_pilot.png  5 rows (s, se, e, ne, n; the n row shows the pilot's
                                      back) x 4 frames: holding the rim, looking about (2),
                                      pulling a rope. Two ropes go up from the basket's ends.
  art/crown/balloon_rope_barrel.png   one row: the rope dropping and coiling (3), the powder
                                      barrel tied on and rising (4).
  assets/units/musketeer/*            the musketeers who ride in the basket (waist up, as before)
All on flat slate, cut with the import_round4 / import_cannon2 pipeline.

How it's layered in the game (scripts/unit.gd, Unit._update_basket):
  body      drift_<dir>, idle_<dir>, death_<dir>   the envelope and the rigging down to the
                                                   basket's own ropes (no basket); death is
                                                   the first sheet's collapse
  basket    basket_<dir>        4 frames, the whole basket with the pilot (drawn over the body)
  riders    gunner_<pose>_<dir> the carried musketeers, waist up, at the slots in Unit.BASKET
  front     basket_front_<dir>  4 frames, the basket's front wall and rim (and the pilot's hands
                                on it) over the riders' legs
All body and basket strips share one cell and anchor (the middle of the basket's bottom).
  assets/effects/haul_coil.png    3 frames: the rope's end landing and coiling (bottom-anchored)
  assets/effects/haul_barrel.png  4 frames: the barrel tied on, rising (rope knot on top)

Usage (from the repo root): python3 tools/import_balloon2.py
Needs Pillow, NumPy and SciPy. Re-runnable. Replaces the "balloon" entry of
scripts/art_data.gd and the files of assets/units/balloon/.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import import_round4 as R  # noqa: E402
import import_balloon as B  # noqa: E402
sys.argv = _argv

DIRS = B.DIRS
OUT = B.OUT
BASKET_W = 46       # wicker width of the new basket, game px
ENV_W = 60          # envelope width, game px (in proportion to the wider basket)
RING_UP = 9         # the envelope's load ring this far above the tops of the basket's ropes
BARREL_W = 9        # the hauled barrel's width, game px
CAN_W, CAN_H, CAN_AX, CAN_AY = 200, 240, 100, 190

R.SHEETS["balloon_basket"] = dict(
    path="art/crown/balloon_basket_pilot.png", rows=[200, 392, 585, 778],
    groups=["basket"], counts=[[4]] * 5, panels=[[0, 1536]] * 5)
R.SHEETS["balloon_rope"] = dict(
    path="art/crown/balloon_rope_barrel.png", rows=[],
    groups=["rope"], counts=[[7]], panels=[[0, 2079]])
NEW_ROW = {"s": 0, "se": 1, "e": 2, "ne": 3, "n": 4}


def basket_width(img):
    """Width of the wicker (sandbags left out): the widest wicker row in the lower half."""
    a = img[..., 3] > 0
    wk = a & B.wicker(img[..., :3])
    ys = np.flatnonzero(a.any(1))
    wk[:ys.min() + int((ys.max() - ys.min()) * 0.55)] = False
    wk = B.largest(ndimage.binary_closing(wk, iterations=2) & a)
    rows = [np.ptp(np.flatnonzero(r)) + 1 for r in wk if r.sum() > 3]
    return float(np.percentile(rows, 90))


def rope_tops(g):
    """Top ends of the basket's two ropes (game image): the topmost opaque pixel in the
    left and right quarter of the image."""
    a = g[..., 3] > 0
    w = a.shape[1]
    out = []
    for x0, x1 in ((0, w // 4), (w - w // 4, w)):
        ys, xs = np.nonzero(a[:, x0:x1])
        i = np.argmin(ys)
        out.append((x0 + xs[i] + 0.5, ys[i]))
    return out


def front_rim(g):
    """Row of the front rim's top edge (game image): below the dark inside of the basket,
    in the columns a quarter in from each end (clear of the pilot)."""
    a = g[..., 3] > 0
    xs = np.flatnonzero(a.any(0))
    w = xs.max() - xs.min()
    lum = g[..., :3].astype(int).sum(-1)
    rows = []
    for x in (xs.min() + int(w * 0.2), xs.min() + int(w * 0.28), xs.max() - int(w * 0.28), xs.max() - int(w * 0.2)):
        col = a[:, x]
        ys = np.flatnonzero(col)
        dark = [y for y in ys if lum[y, x] < 170]
        # the lowest dark run in the upper part of the wicker, then the first light row under it
        top = ys.min()
        mid = top + (ys.max() - top) * 0.7
        dk = [y for y in dark if y < mid]
        if not dk:
            continue
        y = max(dk) + 1
        rows.append(y)
    return int(round(np.median(rows)))


def basket_frames(fr, bgc, d):
    """Game-scale basket frames of one direction, each scaled to BASKET_W and hung from the
    middle of its bottom: [(image, (anchor x, anchor y))]."""
    out = []
    for f in fr[(NEW_ROW[d], "basket")]:
        img = f["img"]
        s = BASKET_W / basket_width(img)
        g = B.to_game(img, s, bgc)
        a = g[..., 3] > 0
        ys = np.flatnonzero(a.any(1))
        bot = ys.max() + 1
        bx = np.flatnonzero(a[bot - 3:bot].any(0))
        out.append((g, ((bx.min() + bx.max() + 1) / 2.0, bot)))
    return out


def env_frame(D, src, anim, tops):
    """The envelope of one body frame, its ring RING_UP above the rope tops, and rigging
    from the ring to them. tops: rope tops on the work canvas."""
    img = src["img"]
    lean, _ = B.lean_of(img)
    th = D.theta(lean, anim)
    env, wmax, (rx0, rx1, ry), _ = B.envelope_part(img)
    s = ENV_W / wmax
    rcx = (rx0 + rx1) / 2.0
    turned, fwd = B.rotate(env, th, rcx, ry)
    g = B.to_game(turned, s, D.bgc)
    pts = [fwd(x, ry) for x in (rx0, rx0 + (rx1 - rx0) * 0.3, rx0 + (rx1 - rx0) * 0.7, rx1)]
    pts = [(px * s, py * s) for px, py in pts]
    rc = fwd(rcx, ry)
    rc = (rc[0] * s, rc[1] * s)
    mid = ((tops[0][0] + tops[1][0]) / 2.0, min(tops[0][1], tops[1][1]))
    t = np.deg2rad(th)
    tx = mid[0] - RING_UP * np.sin(t) * 2.0
    ty = mid[1] - RING_UP * np.cos(t)
    ex, ey = int(round(tx - rc[0])), int(round(ty - rc[1]))
    can = np.zeros((CAN_H, CAN_W, 4), np.uint8)
    P = [(px + ex, py + ey) for px, py in pts]
    # two back ropes to the far rim (behind the basket), the two of the basket's own
    w = tops[1][0] - tops[0][0]
    B.line(can, P[1], (tops[0][0] + w * 0.22, tops[0][1] + 3), B.ROPE_DARK)
    B.line(can, P[2], (tops[1][0] - w * 0.22, tops[1][1] + 3), B.ROPE_DARK)
    B.line(can, P[0], tops[0], B.ROPE_COL)
    B.line(can, P[3], tops[1], B.ROPE_COL)
    B.paste(can, g, ex, ey)
    return can


def death_frames(D, fr):
    # the first sheet's collapse at the new envelope's scale (its own small basket and all)
    best = min(D.idle_src, key=lambda f: abs(B.lean_of(f["img"])[0]))
    s0 = ENV_W / B.envelope_part(best["img"])[1]
    out = []
    srcs = [(f["img"], B.wicker_geom(f["img"])[1:]) for f in fr[(D.r, "death")]]
    wimg = fr[(D.r, "wreck")][0]["img"]
    srcs.append((wimg, B.wreck_ground(wimg)))
    for img, (bot, cx) in srcs:
        g = B.to_game(img, s0, D.bgc)
        can = np.zeros((CAN_H, CAN_W, 4), np.uint8)
        B.paste(can, g, int(round(CAN_AX - cx * s0)), int(round(CAN_AY - bot * s0)))
        out.append(can)
    return out


def haul_art(bgc):
    """The rope's coil (3 frames, the bottom of each) and the barrel (4 frames, barrel and
    knot with a stub of rope), scaled so the barrel is BARREL_W wide."""
    fr, bgc2 = R.extract("balloon_rope")
    frames = fr[(0, "rope")]
    # the barrel's width: the widest rows of frame 4
    b4 = frames[3]["img"]
    a = b4[..., 3] > 0
    widths = [np.ptp(np.flatnonzero(r)) + 1 if r.any() else 0 for r in a]
    s = BARREL_W / float(np.percentile([w for w in widths if w > 0], 95))
    coil, barrel = [], []
    for i, f in enumerate(frames):
        g = B.to_game(f["img"], s, bgc2)
        a = g[..., 3] > 0
        ys = np.flatnonzero(a.any(1))
        if i < 3:
            # the rope's end on the ground: the lowest 9 px
            coil.append(g[max(0, ys.max() - 8):ys.max() + 1])
        else:
            # the barrel and its knot, with 3 px of rope above the knot
            rows = a.sum(1)
            first = next(y for y in ys if rows[y] >= 4)
            barrel.append(g[max(0, first - 6):ys.max() + 1])

    def bottom_strip(fs):
        w = max(f.shape[1] for f in fs)
        h = max(f.shape[0] for f in fs)
        out = []
        for f in fs:
            c = np.zeros((h, w, 4), np.uint8)
            # centre the rope's column, align the bottoms
            a = f[..., 3] > 0
            top = np.flatnonzero(a[0])
            rx = int(round(top.mean())) if top.size else f.shape[1] // 2
            B.paste(c, f, w // 2 - rx, h - f.shape[0])
            out.append(c)
        return np.concatenate(out, 1), (w, h)
    cs, ccell = bottom_strip(coil)
    bs, bcell = bottom_strip(barrel)
    B.save(cs, "assets/effects/haul_coil.png")
    B.save(bs, "assets/effects/haul_barrel.png")
    return ccell, bcell


def main():
    fr, bgc = R.extract("balloon")
    nfr, nbgc = R.extract("balloon_basket")
    os.makedirs(OUT, exist_ok=True)
    body, death, bask, front = {}, {}, {}, {}
    slots = {}
    for d in DIRS:
        D = B.Direction(fr, bgc, d)
        bfs = basket_frames(nfr, nbgc, d)
        # every basket frame on the work canvas, hung from the anchor
        bk, fk = [], []
        tops = None
        for g, (ax, ay) in bfs:
            ox, oy = int(round(CAN_AX - ax)), int(round(CAN_AY - ay))
            can = np.zeros((CAN_H, CAN_W, 4), np.uint8)
            B.paste(can, g, ox, oy)
            fy = front_rim(g)
            fc = can.copy()
            fc[:oy + fy] = 0
            bk.append(can)
            fk.append(fc)
            if tops is None:
                tops = [(x + ox, y + oy) for x, y in rope_tops(g)]
                rim = (CAN_AX, oy + fy)
        bask[d], front[d] = bk, fk
        slots[d] = rim
        for anim, src in (("drift", D.drift_src), ("idle", D.idle_src)):
            body[(anim, d)] = [env_frame(D, f, anim, tops) for f in src]
        death[d] = death_frames(D, fr)
    allf = [f for v in body.values() for f in v] + [f for v in death.values() for f in v] \
        + [f for v in bask.values() for f in v]
    box = B.union_box(allf)
    x0, y0, x1, y1 = box
    cell = (int(x1 - x0), int(y1 - y0))
    anchor = (int(CAN_AX - x0), int(CAN_AY - y0))
    counts = {}
    # stale files from the first importer (its basket fronts)
    keep = {f"{a}_{d}.png" for a in ("drift", "idle", "death", "basket", "basket_front",
                                     "gunner_idle", "gunner_down", "gunner_up") for d in DIRS}
    for f in os.listdir(OUT):
        if f.endswith(".png") and f not in keep:
            os.remove(os.path.join(OUT, f))
            if os.path.exists(os.path.join(OUT, f + ".import")):
                os.remove(os.path.join(OUT, f + ".import"))
    for (anim, d), fs in body.items():
        B.save(B.strip(fs, box), f"{OUT}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(fs)
    for d, fs in death.items():
        B.save(B.strip(fs, box), f"{OUT}/death_{d}.png")
        counts[f"death_{d}"] = len(fs)
    for d in DIRS:
        B.save(B.strip(bask[d], box), f"{OUT}/basket_{d}.png")
        B.save(B.strip(front[d], box), f"{OUT}/basket_front_{d}.png")
    # the riders: the first importer's waist-up musketeers (unchanged files, same cell)
    G = {d: B.Gunners(d) for d in DIRS}
    gw = max(g.waist for g in G.values())
    gp = max(g.px for g in G.values())
    gun = {}
    for d, g in G.items():
        for k, fs in g.anims.items():
            gun[(k, d)] = [B.shift(f, gp - g.px, gw - g.waist) for f in fs]
    gbox = B.union_box([f for v in gun.values() for f in v])
    gx0, gy0, gx1, gy1 = gbox
    gcell = (int(gx1 - gx0), int(gy1 - gy0))
    ganchor = (int(gp - gx0), int(B.Gunners.PAD + gw - gy0))
    gframes = {}
    for (k, d), fs in gun.items():
        B.save(B.strip(fs, gbox), f"{OUT}/gunner_{k}_{d}.png")
        gframes[k] = len(fs)
    ccell, bcell = haul_art(nbgc)

    def v2(p):
        return f"Vector2({p[0]:g}, {p[1]:g})"
    # "gunners": the basket's middle on the front rim line, twice (Unit.BASKET's slots are
    # offsets from there)
    sl = {d: (int(round(slots[d][0] - x0)), int(round(slots[d][1] - y0))) for d in DIRS}
    lines = [f'\t"balloon": {{"cell": Vector2i({cell[0]}, {cell[1]}), "anchor": {v2(anchor)}, "frames": {{']
    lines += [f'\t\t"{k}": {counts[k]},' for k in sorted(counts)]
    lines.append(f'\t}}, "basket_frames": 4, "haul_coil": Vector2i({ccell[0]}, {ccell[1]}), "haul_barrel": Vector2i({bcell[0]}, {bcell[1]}), "gunners": {{')
    lines += [f'\t\t"{d}": [{v2(sl[d])}, {v2(sl[d])}],' for d in DIRS]
    lines.append(f'\t}}, "gunner_cell": Vector2i({gcell[0]}, {gcell[1]}), "gunner_anchor": {v2(ganchor)}, '
                 f'"gunner_frames": {{"idle": {gframes["idle"]}, "down": {gframes["down"]}, "up": {gframes["up"]}}}}},')
    B.write_art_data("\n".join(lines) + "\n")
    print(f"balloon: cell {cell}, anchor {anchor}; rim {sl}; coil {ccell} barrel {bcell}")


if __name__ == "__main__":
    main()
