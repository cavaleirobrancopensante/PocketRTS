#!/usr/bin/env python3
"""THE VENOM LINE'S COLOURS (the Spitter, the Venom Challenger, the Venom Sire, art "dilophosaurus").

0.18.0 (the owner, 2026-10-29 15:17): the whole body in the team colour, the spikes and frill olive.
0.18.2, THE VENOM BELLY (the owner, 2026-10-29 18:05: "a good idea, it still is, but the whole body is too
much"; docs/venom_belly.md): the spikes and the frill in the team colour again, as every Brood creature
(the key reds as painted take the normal path of shaders/team.gdshader), the scales olive as painted, and
the team colour on the BELLY (throat, chest, belly, the tail's underside) and on a STRIPE of scales along
the middle of the flank. The venom's glow (glands, drool, glob), claws, teeth and eyes stay as painted.
The Mist Toad is not in this (0.18.1: its own colours, its details in the team colour).

The strips are not changed: this pass writes, next to them, one mask per strip that
shaders/team.gdshader reads when the unit's `venom_swap` is on (VetLook.update_mask sets it):

  assets/units/venom_masks/<unit>/<anim>_<dir>.png   the same size as the strip
      R = 255 on a belly or stripe pixel (the team colour goes there)
      G = that pixel's tone (its rank among all the creature's marked pixels, 0 dark .. 255 light),
          so the shading survives in every team colour
      B = 0 (it was the olive spikes in 0.18.0/0.18.1)

Where (every frame on its own; only the olive-to-cream skin, tools/import_vet_skin.py, is painted):
  - side and three-quarter views (E, SE, NE; the game mirrors the west ones): per column the BACK LINE
    (the first creature pixel under the spikes) and the BELLY LINE (the lowest pixel of the creature's
    CORE: the creature opened with a disk 15% of its length across, so the shins and feet are not body;
    and no thicker than 1.1x the body standing in that view, so a leg under a rearing body is not
    either), both smoothed along the body. The BELLY: the lowest 30% between them, from the tail's tip
    to under the jaw (NE, seen from behind: only the tail's underside). The STRIPE: 16% of the
    thickness (2 to 4 px) centred half way between the lines, from behind the shoulder down the tail
    (where the body is at least 5 px thick).
  - front (S) and back (N) views: per row, out from the spine (the key reds in the middle) to each
    side's edge, the stripe half way on both flanks (rows with the spine); in front also the throat
    and chest: the skin just under the head in the middle.
Outline darks stay dark (the shader keeps pixels darker than ~0.08).

Usage (from the repo root; after the importers of these units and tools/import_vet_skin.py in
tools/rebuild_art.sh): python3 tools/import_venom_colours.py [--contact DIR] [--only UNIT]
--contact writes one sheet per unit and view: every strip of that view, as painted and in red, blue,
green and purple (the shader's sums done here in NumPy, keep the two in step). Needs Pillow, NumPy and SciPy.
Re-runnable.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_vet_trim import hsv, lum, team_red        # noqa: E402
from import_vet_skin import skin_mask                 # noqa: E402

UNITS_DIR = "assets/units"
OUT = "assets/units/venom_masks"
UNITS = ["spitter", "venom_challenger", "dilophosaurus"]   # (not the Mist Toad: the owner, 2026-10-29, it keeps its own colours, details in the team colour)
SCALE_HUE = (0.095, 0.30)
BODY_L = 0.08
CELL = {"spitter": 74, "venom_challenger": 142, "dilophosaurus": 176}   # frame widths (scripts/art_data.gd "cell")
BELLY = 0.30        # the belly: the lowest 30% of the body's thickness (back line to belly line) in each column
STRIPE_AT = 0.50    # the flank stripe's middle: half way from the back line to the belly line
STRIPE_W = 0.16     # its width: 16% of the thickness (2 to 4 px)
TCAP = 1.1          # no thicker than 1.1x the body standing (the idle frame of that view): a leg under a rearing body


def strips(unit):
    d = os.path.join(UNITS_DIR, unit)
    for f in sorted(os.listdir(d)):
        if f.endswith(".png") and not f.startswith("glow_"):      # (glow_*: the glow masks, not pictures)
            yield f[:-4], os.path.join(d, f)


def spikes(px):
    """The spikes and the frill as painted (the team reds, their red shading, the frill's orange folds): they take the
    normal team-colour path now; here they only mark the back line."""
    a = px[..., 3] > 0
    rgb = px[..., :3].astype(np.float32) / 255.0
    h, s, v = hsv(rgb)
    key_red = team_red(px) & a
    reds = a & ((h < 0.06) | (h > 0.92)) & (s > 0.45) & (v > 0.15)
    near = ndimage.binary_dilation(key_red, iterations=2)
    frill = a & (h > 0.04) & (h < 0.15) & (s > 0.55) & (v > 0.56) & ndimage.binary_dilation(key_red, iterations=3)
    return key_red | (reds & near) | frill


def _smooth(vals, ok, w, q):
    """Per column (or row): the q-th percentile of the valid values within w of it."""
    out = np.zeros(len(vals), np.float32)
    for i in range(len(vals)):
        lo, hi = max(0, i - w), min(len(vals), i + w + 1)
        sel = vals[lo:hi][ok[lo:hi]]
        out[i] = np.percentile(sel, q) if sel.size else 0
    return out


def _box(vals, ok, w):
    out = vals.copy()
    for i in np.nonzero(ok)[0]:
        lo, hi = max(0, i - w), min(len(vals), i + w + 1)
        out[i] = vals[lo:hi][ok[lo:hi]].mean()
    return out


def side_frame(a, spike, paint, tcap=None, face_right=True, belly_to=0.80):
    """A side or three-quarter view (E, SE, NE; head to the right): per column the BACK LINE (the first creature
    pixel under the spikes) and the BELLY LINE (the end of that column's run of body, cut where a leg hangs below:
    at the core's lowest pixel, see below). The belly: the lowest BELLY share of that thickness; the
    stripe: a band STRIPE_W wide centred at STRIPE_AT of it. Both only where `paint` (the olive skin)."""
    H, W = a.shape
    cols = np.nonzero(a.any(0))[0]
    belly = np.zeros_like(a)
    stripe = np.zeros_like(a)
    if cols.size < 6:
        return belly, stripe, 0.0
    x0, x1 = cols.min(), cols.max()
    bw = x1 - x0 + 1
    body = a & ~spike
    # the CORE: the creature opened with a disk 15% of its length across (the shins, feet and the thin tail go;
    # the torso, the neck and the head stay), its biggest piece
    r = max(1, int(0.075 * bw))
    yy0, xx0 = np.mgrid[-r:r + 1, -r:r + 1]
    core = ndimage.binary_opening(a, structure=(yy0 * yy0 + xx0 * xx0 <= r * r))
    lab, n = ndimage.label(core)
    if n:
        core = lab == (1 + int(np.argmax(ndimage.sum(core, lab, range(1, n + 1)))))
    top = np.zeros(W, np.int32)
    bot = np.zeros(W, np.int32)
    ok = np.zeros(W, bool)
    for x in range(x0, x1 + 1):
        ys = np.nonzero(body[:, x])[0]
        if ys.size == 0:
            continue
        y = ys[0]
        b = y
        while b + 1 < H and (a[b + 1, x] or (b + 2 < H and a[b + 2, x])):
            b += 1
        cy = np.nonzero(core[:, x])[0]
        if cy.size:
            b = min(b, cy.max() + 1)          # the belly line: the core's lowest pixel (a leg below is not body)
        top[x], bot[x], ok[x] = y, b, b > y
    sw = max(2, int(0.045 * bw))      # (smoothed along the body: the spikes' bases and pale ridge scales are jagged)
    top_s = _smooth(top.astype(np.float32), ok, sw, 50)
    bot_s = _smooth(bot.astype(np.float32), ok, sw, 50)
    # then averaged (a step becomes a slope: the stripe follows the body without jumps)
    top_s, bot_s = _box(top_s, ok, sw), _box(bot_s, ok, sw)
    t = bot_s - top_s + 1
    # the body's thickness in this view standing (the idle frame: its thickest tenth): a leg straight under a
    # rearing body is still a leg
    tref = float(np.percentile(t[ok], 90)) if ok.any() else 0.0
    if tcap:
        t = np.minimum(t, tcap)
    yy = np.arange(H)[:, None]
    xs = np.arange(W)
    # how far along the body from the tail tip (0) to the snout (1)
    f = (xs - x0) / max(bw - 1, 1)
    if not face_right:
        f = 1 - f
    tt, tp = t[None, :], top_s[None, :]
    rel = (yy - tp) / np.maximum(tt, 1)
    inside = ok[None, :] & (yy >= tp) & (rel <= 1.0)
    belly = inside & (rel >= 1 - BELLY) & (tt >= 3) & (f >= 0.04)[None, :] & (f <= belly_to)[None, :]
    half = np.clip(np.round(STRIPE_W * tt), 2, 4) / 2.0 / np.maximum(tt, 1)
    stripe = inside & (np.abs(rel - STRIPE_AT) <= half) & (tt >= 5) & (f >= 0.14)[None, :] & (f <= 0.66)[None, :]
    return belly & paint, stripe & paint & ~belly, tref


def front_frame(a, spike, key_red, paint, front):
    """The S (front) and N (back) views: per row, out from the spine (the key reds near the middle) to the side's
    edge: the stripe at STRIPE_AT of that half-width on both flanks (torso rows only: rows with the spine). In front
    the throat and chest: the skin in the middle under the head (the rows just under the lowest key red, under a
    fifth of the body's width either side)."""
    H, W = a.shape
    belly = np.zeros_like(a)
    stripe = np.zeros_like(a)
    xs_all = np.nonzero(a.any(0))[0]
    if xs_all.size < 4:
        return belly, stripe
    cx = (xs_all.min() + xs_all.max()) / 2.0
    bw = xs_all.max() - xs_all.min() + 1
    rows = np.nonzero(a.any(1))[0]
    bh = rows.max() - rows.min() + 1
    mid = np.zeros_like(a)
    mid[:, max(0, int(cx - 0.2 * bw)):int(cx + 0.2 * bw) + 1] = True
    spine = key_red & mid
    spine_rows = np.nonzero(spine.any(1))[0]
    for y in spine_rows:
        sx = np.nonzero(spine[y])[0]
        for side, start in ((-1, sx.min()), (1, sx.max())):
            x = start
            while 0 <= x + side < W and a[y, x + side]:
                x += side
            L = abs(x - start)
            if L < 5:
                continue
            c = start + side * STRIPE_AT * L
            hw = max(1.0, min(2.0, STRIPE_W * L))
            for xx in range(min(start, x), max(start, x) + 1):
                if abs(xx - c) <= hw:
                    stripe[y, xx] = True
    if front and spine_rows.size:
        y0 = spine_rows.max() - int(0.04 * bh)
        y1 = spine_rows.max() + int(0.12 * bh)
        m = np.zeros_like(a)
        m[max(0, y0):y1 + 1, max(0, int(cx - 0.18 * bw)):int(cx + 0.18 * bw) + 1] = True
        belly = m & ~ndimage.binary_dilation(spike, iterations=1)
    return belly & paint, stripe & paint & ~belly


def masks(unit, key, px):
    """The belly and the flank stripe of one strip (every frame on its own), both to take the team colour."""
    a = px[..., 3] > 0
    rgb = px[..., :3].astype(np.float32) / 255.0
    h, s, v = hsv(rgb)
    spike = spikes(px)
    skin = skin_mask(unit if unit != "venom_challenger" else "spitter", key, px)
    lime = (h > 0.16) & (s > 0.6) & (v > 0.45)        # (the venom's drool and drops, darker ones too: they keep their glow)
    # olive-to-cream skin (the belly's pale cream is lighter and less saturated: s > 0.15 keeps it)
    paint = skin & (h >= SCALE_HUE[0]) & (h <= SCALE_HUE[1]) & (s > 0.15) & ~spike & ~lime
    view = key.rsplit("_", 1)[1]
    cw = CELL[unit]
    tcap = None
    if view not in ("s", "n"):
        ip = os.path.join(UNITS_DIR, unit, "idle_%s.png" % view)
        if os.path.exists(ip):
            ia = np.asarray(Image.open(ip).convert("RGBA"))[:, :cw]
            isp = spikes(ia)
            icr = isp | skin_mask(unit if unit != "venom_challenger" else "spitter", "idle_" + view, ia)
            tcap = TCAP * side_frame(icr, isp, icr)[2]
    # the creature: its skin and spikes (not the Sire's nest, his dust and fire, nor the venom's spray)
    creature = skin | spike
    belly = np.zeros_like(a)
    stripe = np.zeros_like(a)
    for i in range(px.shape[1] // cw):
        sl = slice(i * cw, (i + 1) * cw)
        if view in ("s", "n"):
            b, st = front_frame(creature[:, sl], spike[:, sl], team_red(px[:, sl]) & a[:, sl], paint[:, sl], view == "s")
        else:
            # (NE: the creature seen from behind, its belly hidden: only the tail's underside)
            b, st, _ = side_frame(creature[:, sl], spike[:, sl], paint[:, sl], tcap, belly_to=0.45 if view == "ne" else 0.80)
        belly[:, sl] = b
        stripe[:, sl] = st
    return belly | stripe, belly, stripe


def ranker(values):
    vs = np.sort(values[values >= BODY_L]) if values.size else values
    def rank(l):
        return np.searchsorted(vs, l, side="right") / max(len(vs), 1)
    return rank


# what shaders/team.gdshader does (keep in step): the team ramp on a marked pixel


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a * (1 - t) + b * t


def team_ramp(team, t):
    t = t[..., None]
    c = mix(team * 0.24, team * 0.85, smoothstep(0.0, 0.7, t))
    return mix(c, mix(team, np.ones(3), 0.35), smoothstep(0.7, 1.0, t))


def preview(im, m, team):
    rgb = im[..., :3].astype(np.float32) / 255.0
    l = lum(rgb)
    tc = np.array(team) / 255.0
    o = rgb.copy()
    kr = team_red(im) & (im[..., 3] > 0)
    o[kr & (im[..., 0] == 255)] = tc
    o[kr & (im[..., 0] == 150)] = tc * 0.6
    k = ((m[..., 0] > 127) * smoothstep(0.035, 0.10, l))[..., None]
    o = o * (1 - k) + team_ramp(tc, m[..., 1].astype(np.float32) / 255.0) * k
    out = im.copy()
    out[..., :3] = np.clip(o * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


def frames_row(im, cw, scale):
    """The strip's frames side by side, each cut to the figure (all frames: the sheet shows every pose)."""
    n = im.shape[1] // cw
    ys = np.nonzero(im[..., 3].any(1))[0]
    y0, y1 = (ys.min(), ys.max() + 1) if ys.size else (0, im.shape[0])
    parts = []
    for i in range(n):
        f = im[y0:y1, i * cw:(i + 1) * cw]
        xs = np.nonzero(f[..., 3].any(0))[0]
        if xs.size:
            f = f[:, max(0, xs.min() - 1):xs.max() + 2]
        parts.append(f)
        parts.append(np.zeros((y1 - y0, 2, 4), np.uint8))
    r = np.concatenate(parts, 1)
    return np.asarray(Image.fromarray(r).resize((r.shape[1] * scale, r.shape[0] * scale), Image.NEAREST))


def main():
    args = sys.argv[1:]
    contact_dir = args[args.index("--contact") + 1] if "--contact" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    for unit in UNITS:
        if only and unit != only:
            continue
        data = {}
        for key, p in strips(unit):
            im = np.asarray(Image.open(p).convert("RGBA"))
            data[key] = (im,) + masks(unit, key, im)
        ls = np.concatenate([lum(im[..., :3].astype(np.float32) / 255.0)[m] for im, m, b, st in data.values()])
        rank = ranker(ls)
        udir = os.path.join(OUT, unit)
        os.makedirs(udir, exist_ok=True)
        for f in os.listdir(udir):
            if f.endswith(".png"):
                os.remove(os.path.join(udir, f))
        shown = []
        n_b = n_s = 0
        for key, (im, m, b, st) in data.items():
            l = lum(im[..., :3].astype(np.float32) / 255.0)
            o = np.zeros(m.shape + (3,), np.uint8)
            o[..., 0] = m * 255
            o[..., 1] = np.where(m, np.clip(rank(l) * 255 + 0.5, 0, 255), 0).astype(np.uint8)
            Image.fromarray(o).save(os.path.join(udir, key + ".png"))
            n_b += int(b.sum())
            n_s += int(st.sum())
            shown.append((key, im, o))
        print("%s: %d strips, %d belly and %d stripe pixels" % (unit, len(data), n_b, n_s))
        if contact_dir:
            os.makedirs(contact_dir, exist_ok=True)
            scale = {"spitter": 3, "venom_challenger": 2, "dilophosaurus": 2}[unit]
            groups = {}
            for key, im, o in shown:
                groups.setdefault(key.rsplit("_", 1)[1], []).append((key, im, o))
            for view, items in groups.items():
                rows = []
                for key, im, o in items:
                    rows.append(frames_row(im, CELL[unit], scale))     # as painted, then red, blue, green, purple
                    for team in ((214, 40, 40), (46, 98, 230), (40, 170, 60), (140, 60, 200)):
                        rows.append(frames_row(preview(im, o, team), CELL[unit], scale))
                    rows.append(np.zeros((6, 4, 4), np.uint8))
                W = max(r.shape[1] for r in rows)
                H = sum(r.shape[0] for r in rows)
                sheet = Image.new("RGBA", (W, H), (58, 64, 52, 255))
                y = 0
                for r in rows:
                    sheet.alpha_composite(Image.fromarray(r), (0, y))
                    y += r.shape[0]
                sheet.save(os.path.join(contact_dir, "%s_%s.png" % (unit, view)))


if __name__ == "__main__":
    main()
