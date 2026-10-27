"""Crown animation audit: measures every Crown unit strip (docs/animation_audit_crown.md).

Usage (repo root):
  python3 tools/anim_audit/measure_crown.py              # report to stdout + /tmp/anim_audit_crown.json
  python3 tools/anim_audit/measure_crown.py --sheets DIR # contact sheets (every anim, every view, 3x) into DIR
  python3 tools/anim_audit/measure_crown.py --gifs DIR   # GIFs at game speed (1x and 3x) into DIR

Per frame (alpha >= 128 counts as opaque): bounding box, feet (lowest opaque row and the mean x of the
bottom 3 opaque rows), centroid and pixel count of the upper body (rows above the bottom 40% of the box),
half-transparent pixels, small islands ("specks": 8-connected pieces of 1-6 px that are not the biggest),
team key reds (the shader swaps #ff0000 and #960000 within 0.08 RGB distance) and near-misses (0.08-0.18,
reds that look like team colour but stay as painted).

Flags (thresholds below):
  COUNT   png width / height disagree with art_data (frames x cell)
  EMPTY   a frame with no opaque pixel; DUP  two consecutive frames identical
  FEETY   still poses (idle, aim, fire, reload, melee, build, mine, shovel, unload, graze, deploy...):
          the foot line moves more than FEET_TOL px between frames
  FEETX   still poses: the feet's mean x moves more than FEETX_TOL px
  JITTER  still poses: the upper body's centroid moves more than JIT_TOL px between consecutive frames
  POP     a frame's height differs from the strip's median by more than POP_TOL px (not deaths)
  SPECK   islands of 1-6 px away from the body
  FRINGE  more than FRINGE_TOL half-transparent pixels in a frame
  NEARKEY red pixels that miss the team key by a little (they stay red for every player)
  GROUND  the strip's foot line is more than GROUND_TOL px off the anchor's y
Unit-level: height of idle against walk and attack per view (switching animations jumps), and each
view's idle height against the others.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CROWN = ["labourer", "musketeer", "musketeer_armoured", "dismounted", "dismounted_armoured", "horseman",
         "cuirassier", "dragoon", "dragoon_armoured", "messenger", "horse", "horse_team", "cannon", "mortar",
         "balloon", "powder_wagon", "missionary", "missionary_bandage_c", "missionary_bandage_h",
         "missionary_mounted"]
DIRS = ["s", "se", "e", "ne", "n"]
STILL = {"idle", "aim", "fire", "aimup", "fireup", "reload", "melee", "build", "mine", "shovel", "unload",
         "graze", "idle_keg", "idle_carry", "idle_packed", "bandage", "pistol", "attack"}
FEET_TOL, FEETX_TOL, JIT_TOL, POP_TOL, FRINGE_TOL, GROUND_TOL = 1, 2.0, 2.0, 3, 6, 2
# speed (Defs) of each kind's walk, for the slide check; the armoured ones: the base speed + Defs.ARMOUR speed
SPEED = {"labourer": 74, "musketeer": 62, "musketeer_armoured": 62, "dismounted": 64, "dismounted_armoured": 62,
         "missionary": 62, "cannon": 38, "mortar": 38, "powder_wagon": 38, "horseman": 112, "cuirassier": 108,
         "horse": 96, "messenger": 124, "dragoon": 112, "dragoon_armoured": 108, "missionary_mounted": 124,
         "horse_team": 38, "balloon": 46}
WALK_FPS = {"musketeer": 12.0, "musketeer_armoured": 12.0, "dismounted": 12.0, "dismounted_armoured": 12.0}
GALLOPERS = ["cuirassier", "horseman", "messenger", "dragoon", "dragoon_armoured", "missionary_mounted"]


def art_data():
    src = open(os.path.join(ROOT, "scripts/art_data.gd")).read()
    units = {}
    for m in re.finditer(r'\t"(\w+)": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), "frames": \{(.*?)\n\t\}', src, re.S):
        units[m[1]] = {"cell": (int(m[2]), int(m[3])), "anchor": (float(m[4]), float(m[5])),
                       "frames": {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', m[6])}}
    return units


def anim_fps(kind, anim, n):
    """How fast unit.gd plays the strip (frames a second) at full speed, and if it loops."""
    if anim == "walk":
        f = WALK_FPS.get(kind, 8.0)
        if kind in GALLOPERS:
            f *= 14.0 / 8.0 * n / 8.0
        return f, True
    if anim in ("idle", "idle_carry", "graze"):
        return 2.0, True
    if anim.startswith("death"):
        return 7.0, False
    if anim in ("aim", "fire", "aimup", "fireup", "melee", "attack"):
        return 9.0, False
    if anim in ("mine", "build"):
        return 6.0, True
    if anim == "idle_keg":
        return 0.75 * n, True
    if anim == "reload":
        return n / 2.0, kind not in ("cannon", "mortar")
    if anim == "bandage":
        return 4.0, True
    if anim == "pistol":
        return n / 0.85, False
    if anim in ("deploy", "mount"):
        return n / 1.5, False
    if anim == "drift":
        return 6.0, True
    return 8.0, True


def islands(mask):
    """Sizes and boxes of 8-connected opaque pieces (small images: a plain flood fill)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        pts = []
        while stack:
            y, x = stack.pop()
            pts.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        out.append(pts)
    return out


def frame_stats(a):
    alpha = a[:, :, 3]
    op = alpha >= 128
    st = {"px": int(op.sum())}
    if st["px"] == 0:
        return st
    ys, xs = np.nonzero(op)
    top, bot, left, right = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
    st.update(top=top, bot=bot, left=left, right=right, h=bot - top + 1, w=right - left + 1)
    feet = op[bot - 2:bot + 1]
    fy, fx = np.nonzero(feet)
    st["foot_x"] = float(fx.mean())
    upper = op[top:top + max(1, int((bot - top + 1) * 0.6))]
    uy, ux = np.nonzero(upper)
    st["cx"], st["cy"] = float(ux.mean()), float(uy.mean() + top)
    st["fringe"] = int(((alpha > 0) & (alpha < 255)).sum())
    rgb = a[:, :, :3].astype(float) / 255.0
    d1 = np.sqrt(((rgb - [1, 0, 0]) ** 2).sum(2))
    d2 = np.sqrt(((rgb - [150 / 255, 0, 0]) ** 2).sum(2))
    vis = alpha > 0
    st["key"] = int((((d1 < 0.08) | (d2 < 0.08)) & vis).sum())
    near = ((d1 >= 0.08) & (d1 < 0.18)) | ((d2 >= 0.08) & (d2 < 0.18))
    redish = (rgb[:, :, 0] > 0.35) & (rgb[:, :, 1] < 0.12) & (rgb[:, :, 2] < 0.12)
    st["nearkey"] = int((near & redish & vis).sum())
    isl = islands(alpha > 0)
    if len(isl) > 1:
        big = max(len(p) for p in isl)
        st["specks"] = [[int(np.mean([p[1] for p in pts])), int(np.mean([p[0] for p in pts])), len(pts)]
                        for pts in isl if len(pts) <= 6 and len(pts) < big]
    else:
        st["specks"] = []
    return st


def load_strip(kind, key, cell):
    p = os.path.join(ROOT, "assets/units", kind, key + ".png")
    if not os.path.exists(p):
        return None, None
    im = Image.open(p).convert("RGBA")
    return im, np.array(im)


def measure():
    units = art_data()
    report = {}
    lines = []
    for kind in CROWN:
        if kind not in units:
            lines.append(f"{kind}: not in art_data")
            continue
        u = units[kind]
        cw, ch = u["cell"]
        ax, ay = u["anchor"]
        rk = report[kind] = {}
        lines.append(f"\n=== {kind}  cell {cw}x{ch} anchor ({ax:g},{ay:g})")
        anims = {}
        for key, n in u["frames"].items():
            a, d = key.rsplit("_", 1)
            anims.setdefault(a, {})[d] = n
        files = set(f[:-4] for f in os.listdir(os.path.join(ROOT, "assets/units", kind)) if f.endswith(".png"))
        for f in sorted(files - set(u["frames"])):
            if not any(f.endswith(s) for s in ("_mask", "_coat", "_trim", "_skin")) and "mask" not in f:
                lines.append(f"  file not in art_data: {f}.png")
        for a in sorted(anims):
            missing = [d for d in DIRS if d not in anims[a]]
            if missing:
                lines.append(f"  {a}: no strip for {' '.join(missing)} (the game falls back)")
            for d in DIRS:
                if d not in anims[a]:
                    continue
                n = anims[a][d]
                key = f"{a}_{d}"
                im, arr = load_strip(kind, key, u["cell"])
                flags = []
                if im is None:
                    lines.append(f"  {key}: MISSING FILE")
                    continue
                if im.width != n * cw or im.height < ch:
                    flags.append(f"COUNT png {im.width}x{im.height} = {im.width / cw:.2f} cells, art_data {n}x{cw}x{ch}")
                extra = im.height - ch      # (unit.gd: a taller strip has its extra room on top, the feet stay put)
                nn = min(n, im.width // cw)
                fr = [frame_stats(arr[:, i * cw:(i + 1) * cw]) for i in range(nn)]
                rk[key] = fr
                for i, s in enumerate(fr):
                    if s["px"] == 0:
                        flags.append(f"EMPTY f{i + 1}")
                for i in range(1, nn):
                    if np.array_equal(arr[:, (i - 1) * cw:i * cw], arr[:, i * cw:(i + 1) * cw]):
                        flags.append(f"DUP f{i}=f{i + 1}")
                ok = [s for s in fr if s["px"]]
                if not ok:
                    lines.append(f"  {key} n{n}: " + "; ".join(flags))
                    continue
                bots = [s["bot"] for s in ok]
                hs = [s["h"] for s in ok]
                med_h = float(np.median(hs))
                still = a in STILL
                if still and len(ok) > 1:
                    if max(bots) - min(bots) > FEET_TOL:
                        flags.append(f"FEETY foot row {bots}")
                    fxs = [s["foot_x"] for s in ok]
                    if max(fxs) - min(fxs) > FEETX_TOL:
                        flags.append(f"FEETX foot x {[round(x, 1) for x in fxs]}")
                    for i in range(1, len(ok)):
                        dx, dy = ok[i]["cx"] - ok[i - 1]["cx"], ok[i]["cy"] - ok[i - 1]["cy"]
                        if abs(dx) > JIT_TOL or abs(dy) > JIT_TOL:
                            flags.append(f"JITTER f{i}->f{i + 1} body moves ({dx:+.1f},{dy:+.1f})")
                if not a.startswith("death") and a not in ("mount", "deploy", "drift"):
                    for i, s in enumerate(fr):
                        if s["px"] and abs(s["h"] - med_h) > POP_TOL:
                            flags.append(f"POP f{i + 1} h{s['h']} vs median {med_h:g}")
                if not a.startswith("death") and kind != "balloon":
                    gb = float(np.median(bots))
                    if abs(gb - ay - extra) > GROUND_TOL:
                        flags.append(f"GROUND foot row {gb - extra:g} vs anchor y {ay:g}")
                sp = [(i + 1, s["specks"]) for i, s in enumerate(fr) if s["px"] and s["specks"]]
                if sp:
                    tot = sum(len(x[1]) for x in sp)
                    flags.append(f"SPECK {tot} islands in frames {[x[0] for x in sp]} e.g. {sp[0][1][:3]}")
                fri = [s["fringe"] for s in ok]
                if max(fri) > FRINGE_TOL:
                    flags.append(f"FRINGE up to {max(fri)} half-transparent px")
                nk = [s["nearkey"] for s in ok]
                if max(nk) > 0:
                    flags.append(f"NEARKEY {max(nk)} px")
                keys = [s["key"] for s in ok]
                info = f"n{n} h{min(hs)}-{max(hs)} feet{min(bots)}-{max(bots)} key{min(keys)}-{max(keys)}"
                fps, loop = anim_fps(kind, a, n)
                info += f" {fps:.1f}fps {'loop' if loop else 'once'} {n / fps:.2f}s"
                lines.append(f"  {key:16s} {info}" + ("" if not flags else "\n      " + "\n      ".join(flags)))
        # cross-animation size: idle against walk / attack per view
        for d in DIRS:
            hv = {}
            for a in ("idle", "walk", "aim", "fire", "melee", "attack", "reload", "build", "mine", "carry", "pistol"):
                fr = rk.get(f"{a}_{d}")
                if fr:
                    ok = [s for s in fr if s["px"]]
                    if ok:
                        ex = Image.open(os.path.join(ROOT, "assets/units", kind, f"{a}_{d}.png")).height - ch
                        hv[a] = (float(np.median([s["h"] for s in ok])), float(np.median([s["px"] for s in ok])),
                                 float(np.median([s["bot"] for s in ok])) - ex)
            if "idle" in hv:
                ih, ip, ib = hv["idle"]
                for a, (h, p, b) in hv.items():
                    if a == "idle":
                        continue
                    if abs(h - ih) > 3 or abs(b - ib) > 1 or (ip and abs(p - ip) / ip > 0.3):
                        lines.append(f"  SWITCH {d}: idle h{ih:g} px{ip:g} feet{ib:g} -> {a} h{h:g} px{p:g} feet{b:g}")
        # views that are copies of another view (the same picture: turning shows no change)
        for a in sorted(anims):
            seen = {}
            for d in DIRS:
                if d in anims[a]:
                    pth = os.path.join(ROOT, "assets/units", kind, f"{a}_{d}.png")
                    h = hash(np.array(Image.open(pth).convert("RGBA")).tobytes())
                    if h in seen:
                        lines.append(f"  COPY {a}_{d} is the same picture as {a}_{seen[h]}")
                    else:
                        seen[h] = d
        # transitions: how far the body jumps when one animation hands over to the next (best shift of the
        # upper body's mask between the last frame shown and the next strip's first frame)
        for d in DIRS:
            for a0, i0, a1, i1 in (("idle", 0, "walk", 0), ("walk", -1, "idle", 0), ("idle", 0, "aim", 0),
                                   ("fire", -1, "reload", 0), ("reload", -1, "idle", 0), ("idle", 0, "melee", 0),
                                   ("melee", -1, "idle", 0), ("idle", 0, "attack", 0), ("attack", -1, "idle", 0),
                                   ("idle", 0, "pistol", 0), ("pistol", -1, "idle", 0), ("deploy", -1, "idle", 0),
                                   ("idle", 0, "fire", 0), ("idle", 0, "death", 0), ("idle", 0, "build", 0),
                                   ("idle", 0, "mine", 0), ("mount", -1, "idle", 0), ("idle", 0, "graze", 0)):
                k0, k1 = f"{a0}_{d}", f"{a1}_{d}"
                if k0 not in u["frames"] or k1 not in u["frames"]:
                    continue
                f0 = strip_frames(kind, k0, units)
                f1 = strip_frames(kind, k1, units)
                if not f0 or not f1:
                    continue
                m0 = np.array(f0[i0])[:, :, 3] >= 128
                m1 = np.array(f1[i1])[:, :, 3] >= 128
                hh = max(m0.shape[0], m1.shape[0])      # (a taller strip has its extra room on top)
                m0 = np.vstack([np.zeros((hh - m0.shape[0], m0.shape[1]), bool), m0])
                m1 = np.vstack([np.zeros((hh - m1.shape[0], m1.shape[1]), bool), m1])
                sh = best_shift(m0, m1)
                if sh and (abs(sh[0]) >= 2 or abs(sh[1]) >= 2):
                    lines.append(f"  JUMP {d}: {a0} -> {a1} the figure moves ({sh[0]:+d},{sh[1]:+d}) px (overlap {sh[2]:.2f})")
        idl = {d: rk[f"idle_{d}"] for d in DIRS if f"idle_{d}" in rk}
        if idl:
            hs = {d: float(np.median([s["h"] for s in v if s["px"]])) for d, v in idl.items()}
            if max(hs.values()) - min(hs.values()) > 4:
                lines.append(f"  VIEWS idle height by view {hs}")
        # walk slide (the earlier audit's measure): ground covered per drawn stride
        if kind in SPEED:
            for d in ("e",):
                fr = rk.get(f"walk_{d}")
                if not fr:
                    continue
                n = len(fr)
                spreads = []
                im, arr = load_strip(kind, f"walk_{d}", u["cell"])
                for i in range(n):
                    s = fr[i]
                    if not s["px"]:
                        continue
                    op = arr[:, i * cw:(i + 1) * cw, 3] >= 128
                    zone = op[s["bot"] - 4:s["bot"] + 1]
                    xs = np.nonzero(zone.any(0))[0]
                    spreads.append(int(xs.max() - xs.min()) if len(xs) else 0)
                fps, _ = anim_fps(kind, "walk", n)
                ground = SPEED[kind] * n / fps
                if spreads:
                    lines.append(f"  SLIDE walk_e: {ground:.0f} px a cycle at {SPEED[kind]} px/s, {fps:.1f} fps; foot spread {min(spreads)}-{max(spreads)} px"
                                 f" (rough ratio ground / (2 x spread range) = {ground / max(1, 2 * (max(spreads) - min(spreads))):.1f})")
    json.dump(report, open("/tmp/anim_audit_crown.json", "w"))
    print("\n".join(lines))


def best_shift(m0, m1, r=8):
    """The (dx, dy) that best lays mask m1 over m0 (upper 70% of m0's box only: legs and wheels move), with its
    overlap (intersection / union); None when nothing overlaps."""
    ys, xs = np.nonzero(m0)
    if not len(ys):
        return None
    top, bot = ys.min(), ys.max()
    cut = top + int((bot - top + 1) * 0.7)
    a = m0.copy()
    a[cut:] = False
    b = m1.copy()
    best = None
    H, W = a.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            sb = np.zeros_like(b)
            ys0, ys1 = max(0, dy), min(H, H + dy)
            xs0, xs1 = max(0, dx), min(W, W + dx)
            sb[ys0:ys1, xs0:xs1] = b[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
            sb[cut:] = False
            inter = (a & sb).sum()
            uni = (a | sb).sum()
            if uni and (best is None or inter / uni > best[2] + 1e-9 or (abs(inter / uni - best[2]) < 1e-9 and abs(dx) + abs(dy) < abs(best[0]) + abs(best[1]))):
                best = (dx, dy, inter / uni)
    return best


def strip_frames(kind, key, units):
    u = units[kind]
    cw, ch = u["cell"]
    im, _ = load_strip(kind, key, u["cell"])
    if im is None:
        return []
    n = min(u["frames"].get(key, im.width // cw), im.width // cw)
    return [im.crop((i * cw, 0, (i + 1) * cw, im.height)) for i in range(n)]     # (taller strips: room on top)


def sheets(out):
    """One contact sheet per unit and animation: a row per view (s, se, e, ne, n, then sw, w, nw mirrored as the
    game draws them), every frame at 3x on a grass-grey ground, the anchor's ground line in cyan."""
    from PIL import ImageDraw
    units = art_data()
    os.makedirs(out, exist_ok=True)
    for kind in CROWN:
        u = units.get(kind)
        if not u:
            continue
        ax, ay = u["anchor"]
        anims = sorted(set(k.rsplit("_", 1)[0] for k in u["frames"]))
        for a in anims:
            cw, ch = u["cell"]
            rows = []
            for d, flip in [(d, False) for d in DIRS] + [("se", True), ("e", True), ("ne", True)]:
                fr = strip_frames(kind, f"{a}_{d}", units)
                rows.append(({"se": "sw", "e": "w", "ne": "nw"}[d] + " (mirror)" if flip else d,
                             [f.transpose(Image.FLIP_LEFT_RIGHT) if flip else f for f in fr]))
            nmax = max((len(r[1]) for r in rows), default=0)
            if nmax == 0:
                continue
            z = 4 if ch <= 44 else 3 if ch <= 70 else 2 if ch <= 130 else 1
            rh = max(f.height for r in rows for f in r[1])
            ext = rh - ch
            # crop every cell to the columns any frame uses (+3 px), so the figures are not lost in empty cells
            xs = [x for r in rows for f in r[1] for x in np.nonzero((np.array(f)[:, :, 3] > 0).any(0))[0]]
            x0c, x1c = max(0, min(xs) - 3), min(cw, max(xs) + 4)
            rows = [(d, [f.crop((x0c, 0, x1c, f.height)) for f in fr]) for d, fr in rows]
            cw = x1c - x0c
            W, H = 40 + nmax * cw * z, len(rows) * rh * z
            sheet = Image.new("RGBA", (W, H), (96, 108, 84, 255))
            dr = ImageDraw.Draw(sheet)
            for r, (d, fr) in enumerate(rows):
                y0 = r * rh * z
                dr.text((4, y0 + 4), d, fill=(255, 255, 255, 255))
                gy = y0 + int((ay + ext) * z + z - 1)
                dr.line([(40, gy), (W, gy)], fill=(0, 220, 220, 255))
                for i, f in enumerate(fr):
                    x0 = 40 + i * cw * z
                    dr.rectangle([x0, y0, x0 + cw * z - 1, y0 + rh * z - 1], outline=(70, 80, 64, 255))
                    big = f.resize((cw * z, f.height * z), Image.NEAREST)
                    sheet.alpha_composite(big, (x0, y0 + (rh - f.height) * z))
            sheet.convert("RGB").save(os.path.join(out, f"{kind}__{a}.png"))
    print("sheets in", out)


def gifs(out, kinds=None, anims=None, zoom=3):
    """GIFs at game speed: all five views side by side, each frame held as long as unit.gd holds it."""
    units = art_data()
    os.makedirs(out, exist_ok=True)
    for kind in kinds or CROWN:
        u = units.get(kind)
        if not u:
            continue
        cw, ch = u["cell"]
        for a in sorted(set(k.rsplit("_", 1)[0] for k in u["frames"])):
            if anims and a not in anims:
                continue
            per = [strip_frames(kind, f"{a}_{d}", units) for d in DIRS]
            per = [p for p in per if p]
            if not per:
                continue
            fps, loop = anim_fps(kind, a, max(len(p) for p in per))
            dur = 1.0 / fps
            # a common timeline of 1/30 s ticks over 2 s (or one play for one-shots + a hold)
            T = 2.0 if loop else max(len(p) for p in per) * dur + 0.6
            ticks = int(T * 30)
            frames = []
            rh = max(f.height for p in per for f in p)
            for t in range(ticks):
                canvas = Image.new("RGBA", (cw * len(per), rh), (96, 108, 84, 255))
                for j, p in enumerate(per):
                    fps_j, _ = anim_fps(kind, a, len(p))
                    k = int(t / 30.0 * fps_j)
                    k = k % len(p) if loop else min(k, len(p) - 1)
                    canvas.alpha_composite(p[k], (j * cw, rh - p[k].height))
                frames.append(canvas.resize((canvas.width * zoom, canvas.height * zoom), Image.NEAREST).convert("RGB"))
            # merge equal neighbours
            outf, durs = [], []
            for f in frames:
                if outf and np.array_equal(np.array(outf[-1]), np.array(f)):
                    durs[-1] += 33
                else:
                    outf.append(f)
                    durs.append(33)
            outf[0].save(os.path.join(out, f"{kind}__{a}_x{zoom}.gif"), save_all=True, append_images=outf[1:],
                         duration=durs, loop=0)
    print("gifs in", out)


if __name__ == "__main__":
    if "--sheets" in sys.argv:
        sheets(sys.argv[sys.argv.index("--sheets") + 1])
    elif "--gifs" in sys.argv:
        z = 3
        if "--zoom" in sys.argv:
            z = int(sys.argv[sys.argv.index("--zoom") + 1])
        ks = None
        if "--kind" in sys.argv:
            ks = sys.argv[sys.argv.index("--kind") + 1].split(",")
        gifs(sys.argv[sys.argv.index("--gifs") + 1], ks, zoom=z)
    else:
        measure()
