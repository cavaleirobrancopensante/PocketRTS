"""Animation audit of the Clockwork (docs/animation_audit_clockwork.md).

Measures every strip of every Clockwork unit (assets/units/<kind>/<anim>_<dir>.png), the coming Spring Catapult and Great
Winder (art/redraws sheets, 5 rows S SE E NE N) and every gear-mode Clockwork building (assets/buildings/<kind>_*.png),
then draws contact sheets and GIFs at game speed.

Per frame: the opaque box, the foot line (the lowest row with >= 2 opaque px), the feet's x middle (opaque px in the
bottom 3 rows), the body's centre of mass and its pixel count, half-transparent fringe px (0 < a < 250), specks (8-way
pixel islands of < 8 px lying 3+ px from the biggest island), the team key reds (the shader's two: 255,0,0 and 150,0,0,
distance < 0.08) and "near reds" (pure red px the shader misses: r > 100, g and b < 0.22 r, not a key).
Per strip: frame counts against the metadata, empty and duplicate frames, foot slide (foot line range and feet x range
in the strips that should stand still), centre jitter (the largest frame-to-frame jump of the centre), height pops
(largest frame-to-frame change of the box height), the loop seam (last -> first change against the mean change).
Per unit: the first frame's height and foot line of idle / walk / attack in each view (switching pops), and the walk's
ground speed against the drawn step (feet slide).

Usage (repo root):  python3 tools/anim_audit/measure_clockwork.py [--no-gifs]
Out: docs/shots/anim_audit_clockwork/measure.md and measure.json, sheet_<kind>.png (every strip, 2x, the anchor line in
cyan, the foot line in magenta), and GIFs in $AUDIT_GIFS (default /tmp/anim_audit_clockwork/gifs): <kind>_<anim>.gif
(all views side by side, game speed, 3x) and <kind>_<anim>_1x.gif.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs/shots/anim_audit_clockwork")
GIFS = os.environ.get("AUDIT_GIFS", "/tmp/anim_audit_clockwork/gifs")
DIRS = ["s", "se", "e", "ne", "n"]
WEST = ["sw", "w", "nw"]
ALL_DIRS = DIRS + WEST
NAVY = (0, 22, 48)

# gear mode's live roster (Defs.CW_NEW_UNITS) and the old roster (retired in gear mode, kept for the shelved Line)
LIVE = ["winder", "clock_soldier", "springer", "cuckoo", "ticking_owl", "pendulum", "netter"]
OLD = ["gearknight", "bolt", "steam_walker", "stormcaller", "tesla_cart", "ornithopter", "arc_thrower", "thresher",
       "bulwark", "windup_soldier"]
BUILDINGS = {"clocktower": 0, "cog_press": 8, "mainspring": 8, "escapement": 24, "movement_works": 8,
             "cuckoo_house": 4, "regulator": 8, "ratchet_turret": 0}
# seconds a work frame (Defs.GEAR frame_dt, works_dt, regulator_dt, escapement_dt, aviary_dt)
BUILD_DT = {"cog_press": 0.11, "mainspring": 0.11, "movement_works": 0.12, "regulator": 0.15, "escapement": 0.125,
            "cuckoo_house": 0.15}
# the coming units: sheets of 5 rows (S SE E NE N), frames per row
COMING = {"spring_catapult": {"throw": ("art/redraws/catapult_throw.png", 12), "move": ("art/redraws/catapult_move.png", 8)},
          "great_winder": {"walk": ("art/redraws/great_winder_walk.png", 12), "wind": ("art/redraws/great_winder_wind.png", 12),
                           "sweep": ("art/redraws/great_winder_sweep.png", 8)}}
STILL = ("idle", "attack", "attack_l", "attack_r", "attack_up", "bomb", "death", "wind", "repair", "guard", "crank",
         "block", "vent", "cast", "brace", "braced_hit", "deploy", "deployed", "drained", "spinup", "windup", "rundown",
         "throw", "sweep")
FLYERS = ("cuckoo", "ticking_owl", "ornithopter")


# ------------------------------------------------------------------ the game's numbers

def _src(p):
    return open(os.path.join(ROOT, p)).read()


def sheets():
    """kind -> (cell w, cell h, anchor x, anchor y, frames from the metadata or None)"""
    out = {}
    src = _src("scripts/art_data.gd")
    for m in re.finditer(r'\t"(\w+)": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), "frames": \{(.*?)\n\t\}', src, re.S):
        out[m[1]] = (int(m[2]), int(m[3]), float(m[4]), float(m[5]), {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', m[6])})
    cw = _src("scripts/cw_art.gd")
    block = cw[cw.find("const SHEETS"):cw.find("}", cw.find("const SHEETS"))]
    for k, a, b, c, d in re.findall(r'"(\w+)": \[(\d+), (\d+), (\d+), (\d+)\]', block):
        out[k] = (int(a), int(b), float(c), float(d), None)     # (CwArt reads the frame counts from the files)
    return out


def unit_defs():
    src = _src("scripts/defs.gd")
    out = {}
    for k in LIVE + OLD:
        m = re.search(r'\n\t"%s": \{(.*?)\n\t\},?\n' % k, src, re.S)
        t = m.group(1) if m else ""
        g = lambda key: (float(re.search(r'"%s": ([\d.]+)' % key, t).group(1)) if re.search(r'"%s": ([\d.]+)' % key, t) else None)
        out[k] = {"speed": g("speed"), "aim": g("aim"), "cooldown": g("cooldown")}
    return out


def walk_fps(kind):
    src = _src("scripts/unit.gd")
    blk = src[src.find("const WALK_FPS_ART"):src.find("}", src.find("const WALK_FPS_ART"))]
    m = re.search(r'"%s": ([\d.]+)' % kind, blk)
    return float(m.group(1)) if m else 8.0


def flap(kind):
    src = _src("scripts/defs.gd")
    m = re.search(r'"%s": \{"lift": [\d.]+, "flap": ([\d.]+)' % kind, src)
    return float(m.group(1)) if m else None


WINDER_BEAT = {"walk": [1, 2, 1, 2], "wind": [7, 2, 7, 2], "idle": [15, 15], "attack": [1, 2, 4, 6], "death": [1, 2, 3, 3, 4, 30]}


def frame_ms(kind, anim, n):
    """Milliseconds each frame shows in the game (Unit._animate at full speed; the Winder's beat)."""
    if kind == "winder":
        b = WINDER_BEAT.get("wind" if anim == "repair" else anim)
        if b:
            return [round(1000 * x / 15.0) for x in b[:n]]
    fl = flap(kind)
    if anim in ("idle", "guard"):
        fps = fl * 0.85 if fl else 2.0
    elif anim in ("walk", "guard_walk", "move"):
        fps = walk_fps(kind) if anim != "move" else 8.0
        if kind == "great_winder":
            fps = 8.0
    elif anim == "death":
        fps = 7.0
    elif anim in ("jump",):
        fps = 9.0      # (the Springer's leap follows Springer.frame: crouch 0.35 s, air 0.3 s, land 0.2 s; shown at 9 fps)
    elif anim in ("wind", "repair", "vent"):
        fps = 5.0
    elif anim in ("sweep", "throw"):
        fps = 10.0
    else:
        fps = 9.0
    return [round(1000.0 / fps)] * n


# ------------------------------------------------------------------ measuring

def frames_of(path, cw, ch=None, n=None):
    im = np.array(Image.open(path).convert("RGBA"))
    if ch is None:
        ch = im.shape[0]
    cnt = im.shape[1] // cw
    fr = [im[:ch, i * cw:(i + 1) * cw] for i in range(cnt)]
    return im, fr


def key_masks(f):
    rgb = f[..., :3].astype(float) / 255.0
    a = f[..., 3] > 0
    k1 = (np.linalg.norm(rgb - [1, 0, 0], axis=-1) < 0.08) & a
    k2 = (np.linalg.norm(rgb - [150 / 255, 0, 0], axis=-1) < 0.08) & a
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    near = a & (r > 100 / 255) & (g < 0.22 * r) & (b < 0.22 * r) & ~k1 & ~k2 & (f[..., 3] > 128)
    return k1, k2, near


def specks(a):
    lab, n = ndi.label(a, structure=np.ones((3, 3)))
    if n <= 1:
        return 0, []
    sizes = ndi.sum(a, lab, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    dist = ndi.distance_transform_edt(lab != big)
    out = []
    for i in range(1, n + 1):
        if i == big or sizes[i - 1] >= 8:
            continue
        ys, xs = np.nonzero(lab == i)
        if dist[ys, xs].min() >= 3:
            out.append((int(xs.mean()), int(ys.mean()), int(sizes[i - 1])))
    return len(out), out


def measure_frame(f):
    al = f[..., 3]
    a = al > 0
    op = al >= 128
    if not a.any():
        return {"empty": True}
    ys, xs = np.nonzero(op if op.any() else a)
    rows = np.nonzero((op.sum(1)) >= 2)[0]
    foot = int(rows[-1]) if len(rows) else int(ys.max())
    fb = op[max(0, foot - 2):foot + 1]
    fxs = np.nonzero(fb.any(0))[0]
    k1, k2, near = key_masks(f)
    ns, sp = specks(a)
    kk = k1 | k2
    kc = (float(np.nonzero(kk)[1].mean()), float(np.nonzero(kk)[0].mean())) if kk.sum() >= 4 else None
    return {"kc": kc, "empty": False, "x0": int(xs.min()), "x1": int(xs.max()), "y0": int(ys.min()), "y1": int(ys.max()),
            "h": int(ys.max() - ys.min() + 1), "w": int(xs.max() - xs.min() + 1), "foot": foot,
            "footx": float(fxs.mean()) if len(fxs) else None, "footw": int(fxs.max() - fxs.min() + 1) if len(fxs) else 0,
            "cx": float(xs.mean()), "cy": float(ys.mean()), "px": int(op.sum()),
            "fringe": int(((al > 0) & (al < 250)).sum()), "key1": int(k1.sum()), "key2": int(k2.sum()), "near": int(near.sum()),
            "specks": ns, "speck_at": sp[:6]}


def strip_stats(fr, still):
    ms = [measure_frame(f) for f in fr]
    full = [m for m in ms if not m["empty"]]
    st = {"n": len(fr), "empty": [i for i, m in enumerate(ms) if m["empty"]], "frames": ms}
    dup = []
    for i in range(len(fr)):
        for j in range(i):
            if np.array_equal(fr[i], fr[j]) and not ms[i]["empty"]:
                dup.append((j, i))
                break
    st["dup"] = dup
    if not full:
        return st
    feet = [m["foot"] for m in full]
    fx = [m["footx"] for m in full if m["footx"] is not None]
    hs = [m["h"] for m in full]
    cx = [m["cx"] for m in full]
    cy = [m["cy"] for m in full]
    st["foot_rng"] = int(max(feet) - min(feet))
    st["footx_rng"] = round(max(fx) - min(fx), 1) if fx else 0
    st["h_rng"] = int(max(hs) - min(hs))
    st["h_pop"] = int(max([abs(hs[i] - hs[i - 1]) for i in range(1, len(hs))] or [0]))
    st["c_jump"] = round(max([np.hypot(cx[i] - cx[i - 1], cy[i] - cy[i - 1]) for i in range(1, len(cx))] or [0]), 1)
    kcs = [m["kc"] for m in full]
    # the team-colour patch (a cap, a body) as a marker of the body: how far it jumps between frames
    st["key_jump"] = round(max([np.hypot(kcs[i][0] - kcs[i - 1][0], kcs[i][1] - kcs[i - 1][1]) for i in range(1, len(kcs))
                               if kcs[i] and kcs[i - 1]] or [0]), 1)
    st["specks"] = sum(m["specks"] for m in full)
    st["fringe"] = int(np.mean([m["fringe"] for m in full]))
    st["fringe_pct"] = round(100.0 * np.mean([m["fringe"] / max(1, m["px"]) for m in full]), 1)
    st["key"] = [m["key1"] + m["key2"] for m in full]
    st["near"] = [m["near"] for m in full]
    st["px"] = [m["px"] for m in full]
    # the loop seam: the last -> first change against the mean consecutive change (alpha masks)
    if len(fr) > 2:
        d = [np.mean((fr[i][..., 3] > 0) != (fr[i - 1][..., 3] > 0)) for i in range(1, len(fr))]
        seam = np.mean((fr[0][..., 3] > 0) != (fr[-1][..., 3] > 0))
        st["seam_k"] = round(float(seam / max(1e-9, np.mean(d))), 2)
        st["max_step_k"] = round(float(max(d) / max(1e-9, np.mean(d))), 2)
    st["still"] = still
    return st


def flags_for(kind, anim, dr, st, anchor_y, ms):
    fl = []
    if st.get("empty"):
        fl.append("empty frames %s" % [i + 1 for i in st["empty"]])
    if st.get("dup"):
        fl.append("duplicate frames %s" % ["%d=%d" % (b + 1, a + 1) for a, b in st["dup"]])
    if "foot_rng" not in st:
        return fl
    air = kind in FLYERS
    if st["still"] and not air and anim not in ("death", "jump"):
        if st["foot_rng"] > 2:
            fl.append("foot line moves %d px" % st["foot_rng"])
        if st["footx_rng"] > 3 and anim in ("idle", "guard", "wind", "repair"):
            fl.append("feet slide %.0f px sideways" % st["footx_rng"])
    if anim in ("idle", "guard") and st["c_jump"] > 3:
        fl.append("centre jumps %.1f px between frames" % st["c_jump"])
    if anim in ("idle", "guard", "wind", "repair") and st.get("key_jump", 0) > 2.5:
        fl.append("body (team colour) jumps %.1f px between frames" % st["key_jump"])
    if st["h_pop"] > 4 and anim not in ("death", "jump", "attack_up", "bomb"):
        fl.append("height pops %d px between frames" % st["h_pop"])
    if st["specks"]:
        fl.append("%d stray specks" % st["specks"])
    if st["fringe_pct"] > 6:
        fl.append("half-transparent fringe %.0f%% of the body" % st["fringe_pct"])
    if not air and anchor_y is not None and anim not in ("death", "jump"):
        d = np.median([m["foot"] for m in ms if not m.get("empty")]) - (anchor_y - 1)
        if abs(d) > 2:
            fl.append("feet %+.0f px from the anchor" % d)
    if st.get("seam_k") is not None and anim in ("idle", "walk", "guard_walk", "wind", "repair", "move", "sweep") and st["seam_k"] > 2.2:
        fl.append("loop seam %.1fx the mean frame change" % st["seam_k"])
    k = st["key"]
    if k and max(k) > 0 and min(k) == 0:
        fl.append("team colour missing in frames %s" % [i + 1 for i, v in enumerate(k) if v == 0])
    if st["near"] and max(st["near"]) > 6:
        fl.append("up to %d red px the team shader misses" % max(st["near"]))
    return fl


# ------------------------------------------------------------------ pictures

def tile(fr, scale, bg=NAVY, lines=None):
    cw, ch = fr[0].shape[1], fr[0].shape[0]
    im = Image.new("RGBA", (cw * len(fr) * scale, ch * scale), bg + (255,))
    for i, f in enumerate(fr):
        p = Image.fromarray(f).resize((cw * scale, ch * scale), Image.NEAREST)
        im.alpha_composite(p, (i * cw * scale, 0))
    return im


def make_gif(rows, ms, path, scale):
    """rows: one frame list per view (side by side); every view plays its own count, looped to the longest."""
    if not rows:
        return
    total = max(sum(m) for m in ms)
    step = 50
    t = 0
    images = []
    cw = max(r[0].shape[1] for r in rows)
    ch = max(r[0].shape[0] for r in rows)
    while t < max(total, 600):
        canvas = Image.new("RGB", (cw * len(rows) * scale, ch * scale), NAVY)
        for vi, (r, m) in enumerate(zip(rows, ms)):
            tt = t % sum(m)
            i = 0
            while tt >= m[i]:
                tt -= m[i]
                i += 1
            p = Image.fromarray(r[i]).resize((r[i].shape[1] * scale, r[i].shape[0] * scale), Image.NEAREST)
            canvas.paste(p, (vi * cw * scale, 0), p)
        images.append(canvas)
        t += step
    images[0].save(path, save_all=True, append_images=images[1:], duration=step, loop=0, optimize=True)


def contact(kind, strips, cell, anchor, path):
    """strips: {(anim, dir): frames}; rows = anims, views left to right."""
    anims = []
    for a, _ in strips:
        if a not in anims:
            anims.append(a)
    sc = 2
    cw, ch = cell
    maxn = {a: max(len(strips[(a, d)]) for d in ALL_DIRS if (a, d) in strips) for a in anims}
    rows = []
    for a in anims:
        for d in ALL_DIRS:
            if (a, d) in strips:
                rows.append((a, d))
    width = max(maxn.values()) * cw * sc + 90
    im = Image.new("RGB", (width, len(rows) * (ch * sc + 4) + 4), (20, 24, 30))
    dr = ImageDraw.Draw(im)
    y = 4
    for a, d in rows:
        fr = strips[(a, d)]
        dr.text((4, y + 4), "%s %s (%d)" % (a, d, len(fr)), fill=(230, 230, 230))
        for i, f in enumerate(fr):
            x = 90 + i * cw * sc
            im.paste(NAVY, (x, y, x + cw * sc, y + ch * sc))
            p = Image.fromarray(f).resize((cw * sc, ch * sc), Image.NEAREST)
            im.paste(p, (x, y), p)
            if anchor:
                ay = y + int(anchor[1]) * sc
                dr.line((x, ay, x + cw * sc - 1, ay), fill=(0, 200, 220))
            m = measure_frame(f)
            if not m["empty"]:
                fy = y + m["foot"] * sc + 1
                dr.line((x, fy, x + 6, fy), fill=(255, 0, 200))
            dr.rectangle((x, y, x + cw * sc - 1, y + ch * sc - 1), outline=(60, 60, 70))
        y += ch * sc + 4
    im.save(path)


# ------------------------------------------------------------------ the audit

def audit_unit(kind, sh, ud, gifs):
    cw, ch, ax, ay, meta = sh
    folder = os.path.join(ROOT, "assets/units", kind)
    res = {"kind": kind, "cell": [cw, ch], "anchor": [ax, ay], "strips": {}, "flags": []}
    strips = {}
    for fn in sorted(os.listdir(folder)):
        m = re.match(r"(.+)_(s|se|e|ne|n|sw|w|nw)\.png$", fn)
        if not m:
            continue
        anim, dr = m[1], m[2]
        im, fr = frames_of(os.path.join(folder, fn), cw)
        key = "%s_%s" % (anim, dr)
        st = strip_stats(fr, anim.split("_")[0] in STILL or anim in STILL)
        if im.shape[1] % cw:
            st.setdefault("bad", []).append("strip width %d is not a whole number of %d px cells" % (im.shape[1], cw))
        if im.shape[0] != ch:
            st.setdefault("bad", []).append("strip height %d, cell %d" % (im.shape[0], ch))
        if meta is not None and key in meta and meta[key] != len(fr):
            st.setdefault("bad", []).append("art_data says %d frames, the file has %d" % (meta[key], len(fr)))
        if meta is not None and key not in meta:
            st.setdefault("bad", []).append("not in art_data (never played)")
        # (a strip taller than the cell has its extra room on top: Unit._set_anim keeps the feet where they were)
        extra = im.shape[0] - ch
        if extra > 0:
            st["bad"] = [b for b in st.get("bad", []) if not b.startswith("strip height")]
            st["taller"] = extra
        fl = st.get("bad", []) + flags_for(kind, anim, dr, st, ay + max(0, extra), st["frames"])
        st["flags"] = fl
        del st["frames"]
        res["strips"][key] = st
        strips[(anim, dr)] = fr
    # switching pops: the first frame of idle / walk / attack per view
    for dr in ALL_DIRS:
        cand = [a for a in ("idle", "walk", "attack", "attack_r", "guard") if (a, dr) in strips]
        hs = {a: measure_frame(strips[(a, dr)][0]) for a in cand}
        hs = {a: m for a, m in hs.items() if not m["empty"]}
        for a, m in hs.items():
            m["foot"] -= strips[(a, dr)][0].shape[0] - ch      # (the taller strips' extra room on top)
        if len(hs) >= 2:
            h = [m["h"] for m in hs.values()]
            f = [m["foot"] for m in hs.values()]
            cxs = [m["cx"] for m in hs.values()]
            if max(h) - min(h) > 4 or max(f) - min(f) > 2 or max(cxs) - min(cxs) > 4:
                res["flags"].append("%s: switching %s pops (heights %s, foot lines %s, centre x %s)" % (
                    dr, "/".join(hs), [m["h"] for m in hs.values()], [m["foot"] for m in hs.values()],
                    [round(m["cx"]) for m in hs.values()]))
    # between views: idle height
    ih = {dr: measure_frame(strips[("idle", dr)][0])["h"] for dr in ALL_DIRS if ("idle", dr) in strips}
    if ih and max(ih.values()) - min(ih.values()) > 6:
        res["flags"].append("idle height differs by view: %s" % ih)
    # walk: ground speed against the drawn step (side view)
    spd = ud.get("speed")
    if ("walk", "e") in strips and spd and kind not in FLYERS:
        fr = strips[("walk", "e")]
        ms = [measure_frame(f) for f in fr]
        spread = [m["footw"] for m in ms if not m["empty"]]
        step = max(spread) - min(spread) if spread else 0
        fps = walk_fps(kind)
        cyc = len(fr) / fps
        res["walk"] = {"speed": spd, "frames": len(fr), "fps": fps, "cycle_s": round(cyc, 2), "ground_per_cycle": round(spd * cyc, 1),
                       "foot_spread_range": int(step), "slide_k": round(spd * cyc / max(1, 2 * step), 2) if step else None}
    # attack timing: the blow lands `aim` s into the strip
    aim = ud.get("aim") or 0.25
    for a in ("attack", "attack_r", "attack_up"):
        if (a, "e") in strips or (a, "s") in strips:
            n = len(strips.get((a, "e"), strips.get((a, "s"))))
            res.setdefault("attack", {})[a] = {"frames": n, "fps": 9.0, "hit_frame": int(aim * 9.0) + 1, "strip_s": round(n / 9.0, 2),
                                               "aim": aim}
    if gifs:
        anims = []
        for a, _ in strips:
            if a not in anims:
                anims.append(a)
        for a in anims:
            rows, mss = [], []
            for dr in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
                if (a, dr) in strips:
                    rows.append(strips[(a, dr)])
                    mss.append(frame_ms(kind, a, len(strips[(a, dr)])))
                elif dr in WEST and (a, {"sw": "se", "w": "e", "nw": "ne"}[dr]) in strips:
                    rows.append([f[:, ::-1] for f in strips[(a, {"sw": "se", "w": "e", "nw": "ne"}[dr])]])
                    mss.append(frame_ms(kind, a, len(rows[-1])))
            make_gif(rows, mss, os.path.join(GIFS, "%s_%s.gif" % (kind, a)), 3)
            make_gif(rows, mss, os.path.join(GIFS, "%s_%s_1x.gif" % (kind, a)), 1)
    # (the old roster's sheets go with the GIFs: they are big and the units are retired)
    contact(kind, strips, (cw, ch), (ax, ay), os.path.join(OUT if kind in LIVE else GIFS, "sheet_%s.png" % kind))
    return res


def audit_coming(kind, spec, gifs):
    res = {"kind": kind, "strips": {}, "flags": []}
    strips = {}
    cell = None
    for anim, (p, n) in spec.items():
        im = np.array(Image.open(os.path.join(ROOT, p)).convert("RGBA"))
        cw, ch = im.shape[1] // n, im.shape[0] // 5
        cell = (cw, ch)
        if im.shape[1] % n or im.shape[0] % 5:
            res["flags"].append("%s sheet %dx%d is not 5 rows x %d whole cells" % (anim, im.shape[1], im.shape[0], n))
        for r, dr in enumerate(DIRS):
            fr = [im[r * ch:(r + 1) * ch, i * cw:(i + 1) * cw] for i in range(n)]
            st = strip_stats(fr, anim in STILL)
            st["flags"] = flags_for(kind, anim, dr, st, None, st["frames"])
            del st["frames"]
            res["strips"]["%s_%s" % (anim, dr)] = st
            strips[(anim, dr)] = fr
        res["cell_" + anim] = [cw, ch]
    sizes = {tuple(v) for k, v in res.items() if k.startswith("cell_")}
    if len(sizes) > 1:
        res["flags"].append("the sheets disagree on the cell: %s" % sorted(sizes))
    if gifs:
        for anim in spec:
            rows = [strips[(anim, d)] for d in DIRS]
            make_gif(rows, [frame_ms(kind, anim, len(r)) for r in rows], os.path.join(GIFS, "%s_%s.gif" % (kind, anim)), 2)
            make_gif(rows, [frame_ms(kind, anim, len(r)) for r in rows], os.path.join(GIFS, "%s_%s_1x.gif" % (kind, anim)), 1)
    contact(kind, strips, cell, None, os.path.join(OUT, "sheet_%s.png" % kind))
    return res


def audit_building(kind, n, gifs):
    res = {"kind": kind, "flags": [], "states": {}}
    base = os.path.join(ROOT, "assets/buildings", kind)
    pics = {}
    for s in ("built", "construction", "damaged", "destroyed"):
        p = base + "_%s.png" % s
        if os.path.exists(p):
            pics[s] = np.array(Image.open(p).convert("RGBA"))
    work = []
    for i in range(n):
        p = base + "_work_%d.png" % i
        if os.path.exists(p):
            work.append(np.array(Image.open(p).convert("RGBA")))
        else:
            res["flags"].append("work frame %d missing" % i)
    for s, im in pics.items():
        m = measure_frame(im)
        res["states"][s] = {k: m[k] for k in ("w", "h", "foot", "px", "specks", "fringe", "key1", "key2", "near")}
        res["states"][s]["size"] = list(im.shape[1::-1])
        res["states"][s]["fringe_pct"] = round(100.0 * m["fringe"] / max(1, m["px"]), 1)
        # (bottom-centred, 6 px up: Building.body_offset; a foot line far off the bottom floats)
        res["states"][s]["foot_from_bottom"] = im.shape[0] - 1 - m["foot"]
        if m["specks"]:
            res["flags"].append("%s: %d stray specks at %s" % (s, m["specks"], m["speck_at"]))
    if "built" in pics:
        bf = res["states"]["built"]["foot_from_bottom"]
        for s in pics:
            d = res["states"][s]["foot_from_bottom"] - bf
            if abs(d) > 2:
                res["flags"].append("%s sits %+d px higher than built (foot line)" % (s, d))
    if work:
        st = strip_stats(work, True)
        b = pics.get("built")
        if b is not None and b.shape == work[0].shape:
            # how much of the building changes when it starts and stops working (built <-> work frames)
            diff_b = [float(np.mean(np.any(np.abs(w.astype(int) - b.astype(int)) > 24, axis=-1) & (w[..., 3] > 0))) for w in work]
            st["vs_built_pct"] = [round(100 * x, 2) for x in diff_b]
            cons = [float(np.mean(np.any(np.abs(work[i].astype(int) - work[i - 1].astype(int)) > 24, axis=-1))) for i in range(len(work))]
            st["step_pct"] = [round(100 * x, 2) for x in cons]
            st["seam_k"] = round(cons[0] / max(1e-9, np.mean(cons[1:])), 2) if len(cons) > 1 else None
            st["built_is_frame"] = [i for i, w in enumerate(work) if np.array_equal(w, b)]
        elif b is not None:
            res["flags"].append("work frames %s, built %s: different sizes" % (work[0].shape, b.shape))
        res["work"] = {k: v for k, v in st.items() if k != "frames"}
        if st.get("dup"):
            res["flags"].append("work: duplicate frames %s" % ["%d=%d" % (q + 1, p + 1) for p, q in st["dup"]])
        if st.get("seam_k") and st["seam_k"] > 2.2:
            res["flags"].append("work loop seam %.1fx the mean frame change" % st["seam_k"])
        if st["specks"]:
            res["flags"].append("work: %d stray specks" % st["specks"])
        if st.get("vs_built_pct") and min(st["vs_built_pct"]) > 3:
            res["flags"].append("work frames all differ from built by >= %.1f%% of px (start/stop pop)" % min(st["vs_built_pct"]))
        if gifs:
            ms = [round(1000 * BUILD_DT.get(kind, 0.11))] * len(work)
            make_gif([work], [ms], os.path.join(GIFS, "%s_work.gif" % kind), 2)
            make_gif([work], [ms], os.path.join(GIFS, "%s_work_1x.gif" % kind), 1)
    # a sheet: states then work frames
    row = [pics[s] for s in ("construction", "built", "damaged", "destroyed") if s in pics]
    hmax = max(p.shape[0] for p in row + work)
    allp = row + work
    sheet = Image.new("RGB", (sum(p.shape[1] for p in allp) + 4 * len(allp), hmax + 4), NAVY)
    x = 0
    for p in allp:
        q = Image.fromarray(p)
        sheet.paste(q, (x, hmax - p.shape[0] + 2), q)
        x += p.shape[1] + 4
    sheet.save(os.path.join(OUT, "sheet_b_%s.png" % kind))
    return res


def main():
    gifs = "--no-gifs" not in sys.argv
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(GIFS, exist_ok=True)
    sh = sheets()
    ud = unit_defs()
    report = {"units": {}, "coming": {}, "buildings": {}}
    for k in LIVE + OLD:
        report["units"][k] = audit_unit(k, sh[k], ud.get(k, {}), gifs and k in LIVE)
    for k, spec in COMING.items():
        report["coming"][k] = audit_coming(k, spec, gifs)
    for k, n in BUILDINGS.items():
        report["buildings"][k] = audit_building(k, n, gifs)
    json.dump(report, open(os.path.join(OUT, "measure.json"), "w"), indent=1, default=str)
    lines = ["# Clockwork animation measurements", "", "Made by tools/anim_audit/measure_clockwork.py. Frames are 1-based.", ""]
    for grp in ("units", "coming"):
        for k, r in report[grp].items():
            lines.append("## %s%s" % (k, " (old roster, retired in gear mode)" if k in OLD else ""))
            if "cell" in r:
                lines.append("cell %s, anchor %s" % (r["cell"], r["anchor"]))
            if r.get("walk"):
                lines.append("walk: %s" % r["walk"])
            if r.get("attack"):
                lines.append("attack: %s" % r["attack"])
            for f in r["flags"]:
                lines.append("- %s" % f)
            for key, st in r["strips"].items():
                if st["flags"]:
                    lines.append("- %s (%d): %s" % (key, st["n"], "; ".join(st["flags"])))
            lines.append("")
    for k, r in report["buildings"].items():
        lines.append("## building %s" % k)
        for s, v in r["states"].items():
            lines.append("- %s: %s" % (s, v))
        if r.get("work"):
            w = r["work"]
            lines.append("- work: %d frames, step %% %s, seam %s, vs built %% %s, h_rng %s, c_jump %s, specks %s" % (
                w["n"], w.get("step_pct"), w.get("seam_k"), w.get("vs_built_pct"), w.get("h_rng"), w.get("c_jump"), w.get("specks")))
        for f in r["flags"]:
            lines.append("- FLAG %s" % f)
        lines.append("")
    open(os.path.join(OUT, "measure.md"), "w").write("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
