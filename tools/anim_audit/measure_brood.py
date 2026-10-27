"""Brood animation audit: measures every Brood unit strip, the Queen and the Brood buildings
(docs/animation_audit_brood.md). Usage (repo root):

    python3 tools/anim_audit/measure_brood.py            # numbers to stdout + /tmp/anim_audit_brood.json
    python3 tools/anim_audit/measure_brood.py --sheets   # also contact sheets and the doc's GIFs in docs/shots/anim_audit_brood/
    python3 tools/anim_audit/measure_brood.py --sheets --all-gifs   # ... and a GIF of every strip

Per frame of every strip (frame counts and cells from scripts/art_data.gd, like the game):
  bbox (opaque px, alpha > 40), foot line (lowest row with >= 2 opaque px), foot x (centre of the lowest 3 rows),
  body centre (centre of mass) and pixel count, half-transparent px (0 < a < 255), team key reds
  ((255,0,0) and (150,0,0) within the shader's 0.08), near-key reds (red-dominant within 0.08..0.2 of a key: they
  stay red for every team), specks (pixel islands of <= 6 px at least 3 px from any other opaque pixel).
Per strip it flags: empty or duplicate frames, foot slide / bob in poses that stand (idle, attack, work, death),
centre jitter, pixel-count and height pops between frames, key reds that come and go, frame-count mismatches with
art_data and strips the game never plays (on disk but not in art_data). Per unit: height and foot-line jumps between
animations and between directions, the body's distance from the anchor's x (the mirror for the west views flips the
sprite about the anchor: a body off it by d px jumps 2d when it turns), the walk's ground speed against its drawn
stride (the earlier audit's method: speed x frames / fps against twice the spread range of the feet).
Play speeds here mirror Unit._animate (scripts/unit.gd); keep them in step.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs/shots/anim_audit_brood")
KINDS = ["grub", "raptor", "spitter", "brute", "skywing", "spore_mother", "bloater", "mist_toad"]
FLYERS = {"skywing", "bloater"}
DIRS = ["s", "se", "e", "ne", "n"]
# poses that stand still on the ground: the feet must not slide
STAND = {"idle", "attack", "death", "wrap", "burrow", "morph", "idle_cocoon", "death_cocoon", "deploy", "deployed",
         "fire", "gidle", "gattack", "gdeath", "fog", "tongue", "refill", "deflate", "ddeath", "land", "flare"}
LOOPS = {"walk", "idle", "idle_cocoon", "carry_cocoon", "gidle", "gwalk", "dwalk", "leap", "charge", "deployed"}
WALK_FPS = 8.0


def play_fps(kind, anim, n):
    """frames a second, as Unit._animate plays the strip (unit.gd); 0 = follows a timer."""
    if anim in ("walk", "carry_cocoon", "gwalk", "dwalk"):
        return WALK_FPS
    if anim in ("idle",):
        return 2.0
    if anim in ("death", "death_cocoon", "gdeath", "ddeath"):
        return 7.0
    if anim == "gidle":
        return 3.0
    if anim == "gattack":
        return 9.0
    if anim == "land":
        return n / 1.2
    if anim in ("deflate", "refill"):
        return n / 0.8
    if anim == "wrap":
        return 5.0 / 1.2
    if anim == "idle_cocoon":
        return 3.0
    if anim == "attack":
        return 6.0 if kind == "spore_mother" else 9.0
    if anim == "fire":
        return 6.0 if kind == "spore_mother" else 9.0
    if anim == "burrow":
        return 7.0
    if anim == "morph":
        return 3.2
    if anim in ("leap", "charge"):
        return 10.0
    if anim == "deploy":
        return n / 2.5
    if anim == "deployed":
        return 3.0 if kind == "spore_mother" else 6.0
    if anim == "fog":
        return 8.0
    if anim == "tongue":
        return 14.0
    return 9.0


def art_data():
    src = open(os.path.join(ROOT, "scripts/art_data.gd")).read()
    units = {}
    for m in re.finditer(r'\t"(\w+)": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), "frames": \{(.*?)\n\t\}', src, re.S):
        fr = {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', m[6])}
        units[m[1]] = {"cell": (int(m[2]), int(m[3])), "anchor": (float(m[4]), float(m[5])), "frames": fr}
    return units


def speeds():
    src = open(os.path.join(ROOT, "scripts/defs.gd")).read()
    out = {}
    for k in KINDS:
        m = re.search(r'\t"%s": \{.*?"speed": (\d+)' % k, src, re.S)
        out[k] = float(m[1]) if m else 0.0
    return out


def load_strip(path, n):
    im = np.array(Image.open(path).convert("RGBA"))
    w = im.shape[1] // max(n, 1)
    return im, [im[:, i * w:(i + 1) * w] for i in range(n)]


def key_masks(f):
    rgb = f[..., :3].astype(float) / 255.0
    a = f[..., 3] > 0
    d1 = np.sqrt(((rgb - [1.0, 0.0, 0.0]) ** 2).sum(-1))
    d2 = np.sqrt(((rgb - [150 / 255.0, 0.0, 0.0]) ** 2).sum(-1))
    key = a & ((d1 < 0.08) | (d2 < 0.08))
    reddish = (rgb[..., 0] > rgb[..., 1] * 2.2) & (rgb[..., 0] > rgb[..., 2] * 2.2) & (rgb[..., 0] > 0.35)
    near = a & ~key & reddish & ((d1 < 0.2) | (d2 < 0.2))
    return key, near


def frame_stats(f):
    a = f[..., 3]
    op = a > 40
    cnt = int(op.sum())
    st = {"px": cnt}
    if cnt == 0:
        st.update(empty=True)
        return st
    rows = np.nonzero(op.any(1))[0]
    cols = np.nonzero(op.any(0))[0]
    rc = op.sum(1)
    feet_rows = np.nonzero(rc >= 2)[0]
    foot = int(feet_rows[-1]) if len(feet_rows) else int(rows[-1])
    zone = op[max(0, foot - 2):foot + 1]
    fx = np.nonzero(zone.any(0))[0]
    ys, xs = np.nonzero(op)
    key, near = key_masks(f)
    lab, nl = ndimage.label(a > 0, structure=np.ones((3, 3)))
    specks = 0
    if nl > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, nl + 1))
        big = (a > 0)
        for i, s in enumerate(sizes):
            if s <= 6:
                comp = lab == i + 1
                rest = big & ~comp
                if not rest.any():
                    continue
                dist = ndimage.distance_transform_edt(~rest)
                if dist[comp].min() >= 3:
                    specks += 1
    st.update(empty=False, top=int(rows[0]), bot=int(rows[-1]), left=int(cols[0]), right=int(cols[-1]),
              h=int(rows[-1] - rows[0] + 1), w=int(cols[-1] - cols[0] + 1), foot=foot,
              foot_x=float((fx[0] + fx[-1]) / 2.0) if len(fx) else 0.0, spread=int(fx[-1] - fx[0] + 1) if len(fx) else 0,
              cx=float(xs.mean()), cy=float(ys.mean()), semi=int(((a > 0) & (a < 255)).sum()),
              key=int(key.sum()), near=int(near.sum()), specks=specks)
    return st


def strip_report(kind, anim, d, frames, n, cell, anchor, spd):
    fs = [frame_stats(f) for f in frames]
    flags = []
    live = [s for s in fs if not s.get("empty")]
    if len(live) < len(fs):
        flags.append("EMPTY frames %s" % [i + 1 for i, s in enumerate(fs) if s.get("empty")])
    med = float(np.median([s["px"] for s in live])) if live else 0
    for i, s in enumerate(fs):
        if not s.get("empty") and s["px"] < med * 0.15 and anim not in ("death", "gdeath", "ddeath", "death_cocoon", "morph", "burrow"):
            flags.append("near-empty frame %d (%d px of %d)" % (i + 1, s["px"], med))
    dups = []
    for i in range(n):
        for j in range(i + 1, n):
            if np.array_equal(frames[i], frames[j]):
                dups.append((i + 1, j + 1))
    if dups:
        flags.append("DUPLICATE frames %s" % dups)
    out = {"n": n, "frames": fs, "flags": flags, "dups": dups}
    if not live:
        return out
    feet = [s["foot"] for s in live]
    fxs = [s["foot_x"] for s in live]
    cxs = [s["cx"] for s in live]
    cys = [s["cy"] for s in live]
    hs = [s["h"] for s in live]
    pxs = [s["px"] for s in live]
    out.update(foot_med=float(np.median(feet)), foot_rng=int(max(feet) - min(feet)), footx_rng=float(max(fxs) - min(fxs)),
               h_med=float(np.median(hs)), h_rng=int(max(hs) - min(hs)), px_med=med, cx_med=float(np.median(cxs)),
               cx_rng=float(max(cxs) - min(cxs)), cy_rng=float(max(cys) - min(cys)),
               semi=int(sum(s["semi"] for s in live)), key=[s["key"] for s in live], near=int(sum(s["near"] for s in live)),
               specks=int(sum(s["specks"] for s in live)))
    standing = anim in STAND and kind not in FLYERS and not anim.startswith("death") and anim != "gdeath"
    if standing and kind not in FLYERS:
        if out["footx_rng"] > 3:
            flags.append("feet slide %.1f px in a standing pose" % out["footx_rng"])
        if out["foot_rng"] > 2:
            flags.append("foot line moves %d px in a standing pose" % out["foot_rng"])
    # jitter / pops between consecutive frames (loops: also last -> first)
    pairs = list(zip(live, live[1:])) + ([(live[-1], live[0])] if anim in LOOPS and len(live) > 2 else [])
    pop = max((max(a["px"], b["px"]) / max(1, min(a["px"], b["px"])) for a, b in pairs), default=1.0)
    hjump = max((abs(a["h"] - b["h"]) for a, b in pairs), default=0)
    cjump = max((abs(a["cx"] - b["cx"]) for a, b in pairs), default=0)
    out.update(pop=float(pop), hjump=int(hjump), cjump=float(cjump))
    if pop > 1.35 and not anim.startswith("death") and anim not in ("gdeath", "ddeath", "morph", "burrow", "deflate", "refill", "land", "deploy", "fog", "tongue", "wrap"):
        flags.append("size pop x%.2f between frames" % pop)
    if anim in ("idle", "gidle", "idle_cocoon", "deployed") and cjump > 2.0:
        flags.append("idle jitter %.1f px" % cjump)
    if out["specks"]:
        flags.append("%d specks" % out["specks"])
    if out["semi"] > 0:
        flags.append("%d half-transparent px" % out["semi"])
    if out["near"] > 0:
        flags.append("%d near-key reds (stay red for every team)" % out["near"])
    ks = out["key"]
    if max(ks) > 0 and min(ks) == 0:
        flags.append("team colour flickers: key reds %s" % ks)
    # anchor: the feet should stand on the anchor's row (the sprite is drawn with offset -anchor)
    yoff = frames[0].shape[0] - cell[1]          # (taller sheets: the game moves the sprite up by the extra rows)
    out["yoff"] = yoff
    out["foot_vs_anchor"] = out["foot_med"] - anchor[1] - yoff
    out["cx_vs_anchor"] = out["cx_med"] - anchor[0]
    if anim in ("walk", "gwalk", "carry_cocoon") and d in ("e", "se", "ne") and kind not in FLYERS:
        g = spd * n / WALK_FPS
        rng = max(s["spread"] for s in live) - min(s["spread"] for s in live)
        out["slide"] = g / max(1.0, 2.0 * rng)
        out["ground_per_cycle"] = g
        out["spread_rng"] = rng
    return out


def audit():
    units = art_data()
    spd = speeds()
    rep = {}
    for k in KINDS:
        u = units[k]
        cell, anchor = u["cell"], u["anchor"]
        folder = os.path.join(ROOT, "assets/units", k)
        files = sorted(f[:-4] for f in os.listdir(folder) if f.endswith(".png"))
        kr = {"cell": cell, "anchor": anchor, "speed": spd[k], "strips": {}, "flags": []}
        for key in files:
            if key not in u["frames"]:
                kr["flags"].append("%s.png is on disk but not in art_data: never played" % key)
        for key, n in sorted(u["frames"].items()):
            p = os.path.join(folder, key + ".png")
            if not os.path.exists(p):
                kr["flags"].append("%s in art_data but no file" % key)
                continue
            im = Image.open(p)
            if im.width % n:
                kr["flags"].append("%s width %d not a multiple of %d frames" % (key, im.width, n))
            if im.width // n != cell[0]:
                kr["flags"].append("%s cell %d wide, art_data says %d" % (key, im.width // n, cell[0]))
            if im.height < cell[1]:
                kr["flags"].append("%s %d tall, cell %d" % (key, im.height, cell[1]))
            anim, d = key.rsplit("_", 1)
            _, frames = load_strip(p, n)
            r = strip_report(k, anim, d, frames, n, cell, anchor, spd[k])
            r["fps"] = play_fps(k, anim, n)
            kr["strips"][key] = r
        # cross-animation / cross-direction checks (ground units: the foot line; everyone: the height)
        st = kr["strips"]
        for d in DIRS:
            ks = [x for x in st if x.endswith("_" + d) and "h_med" in st[x] and not x.startswith(("death", "gdeath", "ddeath", "morph", "burrow", "death_cocoon"))]
            if len(ks) > 1:
                fm = {x: st[x]["foot_vs_anchor"] for x in ks}
                hm = {x: st[x]["h_med"] for x in ks}
                if max(fm.values()) - min(fm.values()) > 2 and k not in FLYERS:
                    kr["flags"].append("view %s: foot line (vs anchor) differs between animations %s" % (d, {x: int(v) for x, v in fm.items()}))
                if max(hm.values()) / max(1, min(hm.values())) > 1.2:
                    kr["flags"].append("view %s: height differs between animations %s" % (d, {x: int(v) for x, v in hm.items()}))
        for a in sorted({x.rsplit("_", 1)[0] for x in st}):
            ks = [a + "_" + d for d in DIRS if a + "_" + d in st and "h_med" in st[a + "_" + d]]
            if len(ks) > 1:
                hm = {x: st[x]["h_med"] for x in ks}
                fm = {x: st[x]["foot_vs_anchor"] for x in ks}
                if max(hm.values()) / max(1, min(hm.values())) > 1.25:
                    kr["flags"].append("%s: height differs between views %s" % (a, {x: int(v) for x, v in hm.items()}))
                if max(fm.values()) - min(fm.values()) > 2 and k not in FLYERS:
                    kr["flags"].append("%s: foot line (vs anchor) differs between views %s" % (a, {x: int(v) for x, v in fm.items()}))
        rep[k] = kr
    rep["_queen"] = queen()
    rep["_buildings"] = buildings()
    return rep


def queen():
    p = os.path.join(ROOT, "assets/buildings/brood_queen.png")
    f = np.array(Image.open(p).convert("RGBA"))
    return {"size": list(f.shape[1::-1]), **{k: v for k, v in frame_stats(f).items() if k in ("px", "h", "w", "semi", "key", "near", "specks", "foot")}}


BUILDINGS = ["hive", "warren_hall", "broodmound", "feeding_pit", "clutch_mound", "warren", "gorge_pit", "roost", "brood_pen"]


def buildings():
    out = {}
    for b in BUILDINGS:
        r = {}
        for s in ("construction", "built", "damaged", "destroyed"):
            p = os.path.join(ROOT, "assets/buildings/%s_%s.png" % (b, s))
            if not os.path.exists(p):
                r[s] = None
                continue
            f = np.array(Image.open(p).convert("RGBA"))
            fs = frame_stats(f)
            r[s] = {"size": list(f.shape[1::-1]), **{k: fs.get(k) for k in ("px", "h", "w", "bot", "left", "right", "semi", "key", "near", "specks")}}
        out[b] = r
    return out


# ------------------------------------------------------------------ pictures

def bg(w, h):
    """a flat dark swamp green (like the ground the creatures walk on), so fringes and specks show."""
    return Image.new("RGBA", (w, h), (52, 60, 47, 255))


TEAM = (58, 120, 232)


def team(f):
    """the strip as blue team: the shader's key swap."""
    f = f.copy()
    key, _ = key_masks(f)
    rgb = f[..., :3].astype(float) / 255.0
    d1 = np.sqrt(((rgb - [1.0, 0.0, 0.0]) ** 2).sum(-1))
    k1 = key & (d1 < 0.08)
    k2 = key & ~k1
    f[k1, :3] = TEAM
    f[k2, :3] = [int(c * 0.6) for c in TEAM]
    return f


def sheet(kind, u, rep, scale=3):
    """every strip of a unit, one row each, 3x, with its anchor (red cross) and foot line (cyan)."""
    from PIL import ImageDraw
    rows = []
    for key in sorted(u["frames"]):
        p = os.path.join(ROOT, "assets/units", kind, key + ".png")
        if not os.path.exists(p):
            continue
        rows.append((key, u["frames"][key], p))
    cw, ch = u["cell"]
    maxn = max(n for _, n, _ in rows)
    lab = 110
    hh = max(Image.open(p).height for _, _, p in rows)
    W = lab + maxn * cw * scale + (maxn - 1) * 4
    H = len(rows) * (hh * scale + 6)
    img = bg(W, H)
    dr = ImageDraw.Draw(img)
    ax, ay = u["anchor"]
    for r, (key, n, p) in enumerate(rows):
        im, frames = load_strip(p, n)
        y0 = r * (hh * scale + 6)
        dr.text((4, y0 + 4), key, fill=(235, 235, 200))
        dr.text((4, y0 + 16), "%d fr %.1f fps" % (n, play_fps(kind, key.rsplit("_", 1)[0], n)), fill=(170, 190, 160))
        for i, f in enumerate(frames):
            fi = Image.fromarray(team(f)).resize((f.shape[1] * scale, f.shape[0] * scale), Image.NEAREST)
            x0 = lab + i * (cw * scale + 4)
            img.alpha_composite(fi, (x0, y0))
            yoff = (f.shape[0] - ch)
            gy = y0 + int((ay + yoff) * scale)
            dr.line([(x0, gy), (x0 + cw * scale - 1, gy)], fill=(80, 200, 220), width=1)
            gx = x0 + int(ax * scale)
            dr.line([(gx - 4, gy), (gx + 4, gy)], fill=(255, 60, 60), width=1)
            dr.line([(gx, gy - 4), (gx, gy + 4)], fill=(255, 60, 60), width=1)
            dr.text((x0 + 2, y0 + 2), str(i + 1), fill=(255, 255, 255))
    img.save(os.path.join(OUT, "sheet_%s.png" % kind))


def gif(kind, key, n, scale, fps, name=None):
    """the strip at the game's frame rate (frames held on the 15 Hz animation tick), standing on its anchor."""
    p = os.path.join(ROOT, "assets/units", kind, key + ".png")
    _, frames = load_strip(p, n)
    ms = max(66, int(round(1000.0 / max(fps, 0.5) / 66.0)) * 66)
    loop = key.rsplit("_", 1)[0] in LOOPS
    out = []
    for f in frames:
        im = bg(f.shape[1], f.shape[0])
        im.alpha_composite(Image.fromarray(team(f)))
        out.append(im.resize((f.shape[1] * scale, f.shape[0] * scale), Image.NEAREST).convert("RGB"))
    durs = [ms] * len(out)
    if not loop:
        durs[-1] = 1200
    out[0].save(os.path.join(OUT, name or "%s_%s_x%d.gif" % (kind, key, scale)), save_all=True,
                append_images=out[1:], duration=durs, loop=0)


def building_sheet():
    from PIL import ImageDraw
    ims = []
    for b in BUILDINGS + ["brood_queen"]:
        row = []
        for s in ("construction", "built", "damaged", "destroyed"):
            p = os.path.join(ROOT, "assets/buildings/%s_%s.png" % (b, s)) if b != "brood_queen" else os.path.join(ROOT, "assets/buildings/brood_queen.png")
            if os.path.exists(p):
                row.append((s, Image.open(p).convert("RGBA")))
            if b == "brood_queen":
                break
        ims.append((b, row))
    W = 1800
    H = sum(max(im.height for _, im in row) + 24 for _, row in ims)
    img = bg(W, H)
    dr = ImageDraw.Draw(img)
    y = 0
    for b, row in ims:
        x = 0
        hh = max(im.height for _, im in row)
        for s, im in row:
            fi = Image.fromarray(team(np.array(im)))
            img.alpha_composite(fi, (x, y + 18))
            dr.text((x + 2, y + 2), "%s %s" % (b, s), fill=(235, 235, 200))
            x += im.width + 12
        y += hh + 24
    img.save(os.path.join(OUT, "sheet_buildings.png"))


# the GIFs kept in docs/shots/anim_audit_brood/ (the ones the doc points at); --all-gifs writes every strip
GIFS = {("grub", "walk_e"), ("grub", "walk_se"), ("grub", "wrap_e"), ("grub", "carry_cocoon_e"), ("grub", "burrow_e"),
        ("grub", "morph_e"), ("grub", "death_cocoon_e"), ("raptor", "walk_e"), ("raptor", "attack_e"), ("raptor", "death_e"),
        ("raptor", "leap_e"), ("spitter", "walk_e"), ("spitter", "attack_e"), ("spitter", "death_e"), ("brute", "walk_e"),
        ("brute", "idle_e"), ("brute", "attack_e"), ("brute", "charge_e"), ("brute", "death_e"), ("skywing", "walk_e"),
        ("skywing", "idle_s"), ("skywing", "land_e"), ("skywing", "gwalk_e"), ("skywing", "gattack_e"), ("skywing", "death_e"),
        ("spore_mother", "walk_e"), ("spore_mother", "deploy_e"), ("spore_mother", "fire_e"), ("spore_mother", "death_e"),
        ("bloater", "walk_e"), ("bloater", "attack_e"), ("bloater", "deflate_e"), ("bloater", "death_e"), ("bloater", "ddeath_e"),
        ("mist_toad", "walk_e"), ("mist_toad", "tongue_e"), ("mist_toad", "fog_e"), ("mist_toad", "death_e"), ("mist_toad", "idle_n")}


def main():
    rep = audit()
    with open("/tmp/anim_audit_brood.json", "w") as fh:
        json.dump(rep, fh, indent=1, default=float)
    for k in KINDS:
        kr = rep[k]
        print("==", k, "cell", kr["cell"], "anchor", kr["anchor"], "speed", kr["speed"])
        for f in kr["flags"]:
            print("   !", f)
        for key, r in kr["strips"].items():
            if "h_med" not in r:
                print("  %-18s EMPTY" % key, r["flags"])
                continue
            extra = ""
            if "slide" in r:
                extra = " ground/cycle %.0f spread %d slide x%.1f" % (r["ground_per_cycle"], r["spread_rng"], r["slide"])
            print("  %-18s n%-2d fps%4.1f h%3.0f(+-%d) foot%3.0f(%+.0f vs anchor, rng %d) footx rng %4.1f cx%+5.1f vs anchor, cx rng %4.1f pop x%.2f key %s%s" % (
                key, r["n"], r["fps"], r["h_med"], r["h_rng"], r["foot_med"], r["foot_vs_anchor"], r["foot_rng"], r["footx_rng"],
                r["cx_vs_anchor"], r["cx_rng"], r["pop"], r["key"], extra))
            for f in r["flags"]:
                print("       -", f)
    print("== queen", rep["_queen"])
    for b, r in rep["_buildings"].items():
        print("== building", b, {s: (v and {kk: v[kk] for kk in ("size", "semi", "key", "near", "specks")}) for s, v in r.items()})
    if "--sheets" in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        units = art_data()
        for k in KINDS:
            sheet(k, units[k], rep[k])
            for key, n in sorted(units[k]["frames"].items()):
                if not os.path.exists(os.path.join(ROOT, "assets/units", k, key + ".png")):
                    continue
                fps = play_fps(k, key.rsplit("_", 1)[0], n)
                if "--all-gifs" in sys.argv or (k, key) in GIFS:
                    gif(k, key, n, 3, fps)
                if key in ("walk_e", "gwalk_e") and (k, key) in GIFS:
                    gif(k, key, n, 1, fps)          # (at game size too)
        building_sheet()


if __name__ == "__main__":
    main()
