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
  basket    basket_<dir>        4 frames, the basket (drawn over the body); frames 0-2 empty,
                                the pilot cut out and the wicker under him filled in; frame 3
                                (pulling the rope) keeps him in it as drawn
  pilot     pilot_<dir>         4 frames, the pilot on his own (frame 3 empty): Unit lifts him
                                onto a crate (Unit.PILOT_LIFT) when the middle places are full
  riders    gunner_<pose>_<dir> the carried musketeers, waist up, at the slots in Unit.BASKET
  front     basket_front_<dir>  4 frames, the basket's front wall and rim (and the pilot's hands
                                on it) over the riders' legs
All body and basket strips share one cell and anchor (the middle of the basket's bottom).
The envelope's red gores are snapped to the two team key reds in full (clean_stripes), so
every team colour comes out as even stripes. ArtData "pilot_hand": per facing, the pilot's
hand on the rope in frame 3 and the front rim under it (the haul rope runs between them).
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
from import_art import TEAM_DARK, TEAM_LIGHT  # noqa: E402
sys.argv = _argv

DIRS = B.DIRS
OUT = B.OUT
BASKET_W = 46       # wicker width of the new basket, game px
ENV_W = 84          # envelope width, game px: its load ring about as wide as the basket's corner ropes
RING_UP = 12        # the envelope's load ring this far above the tops of the basket's corner ropes
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


def back_rim(g):
    """Row of the top of the basket's back rim (game image): the first row the opaque
    basket spans most of its width."""
    a = g[..., 3] > 0
    w = np.ptp(np.flatnonzero(a.any(0))) + 1
    for y in range(a.shape[0]):
        xs = np.flatnonzero(a[y])
        if xs.size and np.ptp(xs) + 1 >= w * 0.7 and a[y].sum() >= w * 0.5:
            return y
    return a.shape[0] // 2


def _hsv(rgb):
    """Hue (degrees), saturation and value (0-1) of an RGB uint8 array."""
    c = rgb.astype(float) / 255.0
    mx, mn = c.max(-1), c.min(-1)
    d = mx - mn
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    dd = np.where(d > 0, d, 1.0)
    h = np.select([mx == r, mx == g], [((g - b) / dd) % 6.0, (b - r) / dd + 2.0], (r - g) / dd + 4.0) * 60.0
    h = np.where(d > 0, h, 0.0)
    s = np.where(mx > 0, d / np.where(mx > 0, mx, 1.0), 0.0)
    return h, s, mx


def clean_stripes(img):
    """The envelope's red gores as clean team colour: the shader only swaps the two exact
    key reds, so every other red pixel on the envelope (the sheen on a gore, the
    anti-aliased edge against the cream, a shaded fold) stayed red on a blue or green
    balloon. Every pixel in the red hue window (widened to take the orange-ish edge blends
    and the pink sheen) next to the gores becomes a key red; the light / dark split is
    smoothed so each gore shades in even areas instead of specks; reddish outline pixels
    too dark to be gore turn to a neutral dark brown."""
    img = img.copy()
    a = img[..., 3] > 0
    rgb = img[..., :3].astype(int)
    keyl = a & (rgb[..., 0] == TEAM_LIGHT[0]) & (rgb[..., 1] == 0) & (rgb[..., 2] == 0)
    keyd = a & (rgb[..., 0] == TEAM_DARK[0]) & (rgb[..., 1] == 0) & (rgb[..., 2] == 0)
    key = keyl | keyd
    if not key.any():
        return img
    h, s, v = _hsv(img[..., :3])
    reddish = a & ((h <= 24.0) | (h >= 335.0))
    near = ndimage.binary_dilation(key, structure=np.ones((3, 3)), iterations=4)
    # the hue window reaches into orange only for strong colour: the cream's shadows are
    # orange-ish too, but greyer
    strong = (s >= 0.38) & ((h <= 18.0) | (h >= 335.0) | (s >= 0.55))
    gore = (key | (reddish & strong & (v >= 0.3) & near))
    k8 = np.ones((3, 3), int)
    k8[1, 1] = 0
    for _ in range(2):
        ng = ndimage.convolve(gore.astype(int), k8, mode="constant")
        # the pale sheen ticks inside a gore join it; a stray converted pixel out in the
        # cream goes back
        warm = a & ((h <= 40.0) | (h >= 330.0))
        gore = (gore & ~(~key & (ng <= 2))) | (warm & ~gore & (ng >= 6))
    # the paler sheen in clumps, closed in by a gore on every side: gore too
    holes = ndimage.binary_fill_holes(gore) & ~gore & a
    lab, n = ndimage.label(holes)
    if n:
        sz = ndimage.sum(holes, lab, np.arange(1, n + 1))
        gore |= np.isin(lab, 1 + np.flatnonzero(sz <= 40)) & ((h <= 40.0) | (h >= 330.0))
    # a gore pixel's light / dark: the keys as they are, the rest by brightness; then
    # smoothed over the gore so the shading comes in even areas
    lit = np.where(keyl, 1.0, np.where(keyd, 0.0, np.clip((v - 0.52) / 0.3, 0.0, 1.0)))
    w = ndimage.gaussian_filter(gore.astype(float), 0.9)
    sm = ndimage.gaussian_filter(np.where(gore, lit, 0.0), 0.9) / np.maximum(w, 1e-6)
    light = gore & (sm >= 0.5)
    # lone light or dark pixels inside a gore take their neighbours' tone
    for _ in range(2):
        nl = ndimage.convolve(light.astype(int), np.ones((3, 3), int), mode="constant")
        ng = ndimage.convolve(gore.astype(int), np.ones((3, 3), int), mode="constant")
        nd = ng - nl
        light = (light & ~(nd >= 6)) | (gore & ~light & (nl >= 6))
    img[light, :3] = TEAM_LIGHT
    img[gore & ~light, :3] = TEAM_DARK
    # reddish specks left round the gores (dark outline blends): neutral dark brown
    spk = reddish & ~gore & (s >= 0.45) & ndimage.binary_dilation(gore, iterations=2)
    lum = rgb[spk].max(1) * 0.7
    img[spk, 0] = np.clip(lum, 0, 255).astype(np.uint8)
    img[spk, 1] = np.clip(lum * 0.78, 0, 255).astype(np.uint8)
    img[spk, 2] = np.clip(lum * 0.66, 0, 255).astype(np.uint8)
    return img


def split_pilot(g, fy):
    """The pilot of a basket frame (game image) on his own layer: (empty basket, pilot).
    fy: the front rim's top row (the front layer covers everything from there down).
    The pilot is what grows from his coat, scarf and skin above the front rim; under him
    the basket's inside and back rim are filled in from the wicker either side of him."""
    a = g[..., 3] > 0
    rgb = g[..., :3].astype(int)
    r, gg, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    xs = np.flatnonzero(a[fy:].any(0))
    bx0, bx1 = xs.min(), xs.max()
    W = bx1 - bx0 + 1
    up = np.zeros_like(a)
    up[:fy] = True
    navy = a & (b > r + 4) & (b > 30)
    scarf = a & (r >= 140) & (gg <= r * 0.35) & (b <= r * 0.35)
    skin = a & (r >= 200) & (gg >= 120) & (b >= 80) & (r - b <= 140)
    mid = np.zeros_like(a)
    mid[:, bx0 + int(W * 0.2):bx1 - int(W * 0.2) + 1] = True
    back = back_rim(g)
    seed = (navy | scarf | skin) & up & mid
    # frame 3's hand on the corner rope is well out to the side: skin above the back rim
    # counts too (in a clump: lone light pixels are the rim's and ropes' highlights)
    hs = skin & (np.arange(a.shape[0])[:, None] < back)
    lab, n = ndimage.label(hs, structure=np.ones((3, 3)))
    if n:
        sz = ndimage.sum(hs, lab, np.arange(1, n + 1))
        seed |= np.isin(lab, 1 + np.flatnonzero(sz >= 3))
    sx = np.flatnonzero(seed.any(0))
    px0, px1 = sx.min() - 2, sx.max() + 2
    cols = np.zeros_like(a)
    cols[:, px0:px1 + 1] = True
    inside = a & ~navy & ~scarf & ~skin & (r >= b + 8)
    # above the back rim: everything between the ropes that touches him (head and hat);
    # from there to the front rim: his clothes (not the basket's brown inside)
    cand = a & up & cols & ~(inside & (np.arange(a.shape[0])[:, None] >= back))
    lab, n = ndimage.label(cand, structure=np.ones((3, 3)))
    ids = np.unique(lab[seed & cand])
    pil = np.isin(lab, ids[ids > 0])
    # fill a pixel or two of shading enclosed by him
    pil = ndimage.binary_closing(pil, structure=np.ones((3, 3))) & a & up & cols
    pil = B.largest(pil)
    pilot = np.zeros_like(g)
    pilot[pil] = g[pil]
    basket = g.copy()
    basket[pil] = 0
    # the wicker either side of him, mirrored in (kept clear of the side walls)
    hx0 = int(np.flatnonzero(pil.any(0)).min())
    hx1 = int(np.flatnonzero(pil.any(0)).max())
    cx = (hx0 + hx1) / 2.0
    pl_ = max(2, (hx0 - bx0) // 2)
    pr_ = max(2, (bx1 - hx1) // 2)
    for y in range(max(0, back - 2), fy):
        for x in range(hx0, hx1 + 1):
            if not pil[y, x]:
                continue
            cands = []
            if x < cx:
                cands = [hx0 - 1 - ((x - hx0) % pl_), hx1 + 1 + ((x - hx0) % pr_)]
            else:
                cands = [hx1 + 1 + ((hx1 - x) % pr_), hx0 - 1 - ((hx1 - x) % pl_)]
            for sx_ in cands:
                if bx0 <= sx_ <= bx1 and a[y, sx_] and not pil[y, sx_]:
                    basket[y, x] = g[y, sx_]
                    break
    return basket, pilot, pil


def pilot_hand(pilot):
    """The pilot's right hand (the one up on the rope in the pulling frame): the middle of
    the skin pixels farthest out to the right, in the image."""
    a = pilot[..., 3] > 0
    rgb = pilot[..., :3].astype(int)
    skin = a & (rgb[..., 0] >= 170) & (rgb[..., 1] >= 80) & (rgb[..., 0] > rgb[..., 2] + 40)
    ys, xs = np.nonzero(skin)
    far = xs >= xs.max() - 2
    return float(xs[far].mean()) + 0.5, float(ys[far].min()) + 1.0


def env_frame(D, src, anim, tops, back):
    """The envelope of one body frame, its ring RING_UP above the rope tops, and rigging
    from the ring to them. tops: rope tops on the work canvas; back: the canvas row of the
    basket's back rim, where the two back ropes are tied (behind the pilot)."""
    img = src["img"]
    lean, _ = B.lean_of(img)
    th = D.theta(lean, anim)
    env, wmax, (rx0, rx1, ry), _ = B.envelope_part(img)
    s = ENV_W / wmax
    rcx = (rx0 + rx1) / 2.0
    turned, fwd = B.rotate(env, th, rcx, ry)
    g = clean_stripes(B.to_game(turned, s, D.bgc))
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
    B.line(can, P[1], (tops[0][0] + w * 0.22, back), B.ROPE_DARK)
    B.line(can, P[2], (tops[1][0] - w * 0.22, back), B.ROPE_DARK)
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
        g = clean_stripes(B.to_game(img, s0, D.bgc))
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
    body, death, bask, front, pilot = {}, {}, {}, {}, {}
    slots, hands = {}, {}
    for d in DIRS:
        D = B.Direction(fr, bgc, d)
        bfs = basket_frames(nfr, nbgc, d)
        # every basket frame on the work canvas, hung from the anchor
        bk, fk, pk = [], [], []
        tops = None
        for i, (g, (ax, ay)) in enumerate(bfs):
            ox, oy = int(round(CAN_AX - ax)), int(round(CAN_AY - ay))
            fy = front_rim(g)
            eb, pl, _ = split_pilot(g, fy)
            if i == 3:
                # pulling the rope he stands tall (never lifted, Unit._update_basket): that
                # frame keeps him in the basket as drawn, his own layer stays empty
                eb, pl = g, (pl_hand := pl) * 0
            can = np.zeros((CAN_H, CAN_W, 4), np.uint8)
            B.paste(can, g, ox, oy)
            fc = can.copy()
            fc[:oy + fy] = 0
            bc = np.zeros((CAN_H, CAN_W, 4), np.uint8)
            B.paste(bc, eb, ox, oy)
            pc = np.zeros((CAN_H, CAN_W, 4), np.uint8)
            B.paste(pc, pl, ox, oy)
            bk.append(bc)
            fk.append(fc)
            pk.append(pc)
            if i == 3:
                # the hand on the rope in the pulling frame, and the front rim below it
                hx, hy = pilot_hand(pl_hand)
                col = fc[:, int(hx + ox), 3] > 0
                hands[d] = ((hx + ox, hy + oy), (hx + ox, float(np.flatnonzero(col).min())))
            if tops is None:
                tops = [(x + ox, y + oy) for x, y in rope_tops(g)]
                rim = (CAN_AX, oy + fy)
                back = oy + back_rim(g)
        bask[d], front[d], pilot[d] = bk, fk, pk
        slots[d] = rim
        for anim, src in (("drift", D.drift_src), ("idle", D.idle_src)):
            body[(anim, d)] = [env_frame(D, f, anim, tops, back) for f in src]
        death[d] = death_frames(D, fr)
    allf = [f for v in body.values() for f in v] + [f for v in death.values() for f in v] \
        + [f for v in bask.values() for f in v] + [f for v in pilot.values() for f in v]
    box = B.union_box(allf)
    x0, y0, x1, y1 = box
    cell = (int(x1 - x0), int(y1 - y0))
    anchor = (int(CAN_AX - x0), int(CAN_AY - y0))
    counts = {}
    # stale files from the first importer (its basket fronts)
    keep = {f"{a}_{d}.png" for a in ("drift", "idle", "death", "basket", "basket_front", "pilot",
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
        B.save(B.strip(pilot[d], box), f"{OUT}/pilot_{d}.png")
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
    # "pilot_hand": his hand on the rope in the pulling frame, and the front rim under it
    hd = {d: [(hands[d][k][0] - x0, hands[d][k][1] - y0) for k in (0, 1)] for d in DIRS}
    lines.append('\t}, "pilot_hand": {')
    lines += [f'\t\t"{d}": [{v2(hd[d][0])}, {v2(hd[d][1])}],' for d in DIRS]
    lines.append(f'\t}}, "basket_frames": 4, "haul_coil": Vector2i({ccell[0]}, {ccell[1]}), "haul_barrel": Vector2i({bcell[0]}, {bcell[1]}), "gunners": {{')
    lines += [f'\t\t"{d}": [{v2(sl[d])}, {v2(sl[d])}],' for d in DIRS]
    lines.append(f'\t}}, "gunner_cell": Vector2i({gcell[0]}, {gcell[1]}), "gunner_anchor": {v2(ganchor)}, '
                 f'"gunner_frames": {{"idle": {gframes["idle"]}, "down": {gframes["down"]}, "up": {gframes["up"]}}}}},')
    B.write_art_data("\n".join(lines) + "\n")
    print(f"balloon: cell {cell}, anchor {anchor}; rim {sl}; coil {ccell} barrel {bcell}")


if __name__ == "__main__":
    main()
