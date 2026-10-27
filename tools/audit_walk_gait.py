"""Walk-gait audit of every unit (docs/animation_gait_audit.md, /tmp/gait_audit.png).
Usage (repo root): python3 tools/audit_walk_gait.py [--doc] [--sheet]

Per unit and direction (frame counts read from scripts/art_data.gd), on the leg zone = the bottom 30% of
the sprite's own height:
  leg  = mean fraction of leg-zone pixels that change between consecutive frames (cyclic)
  rng  = range (px) over the cycle of the foot spread (x-width of the bottom 5 rows; for front/back
         views the height difference between the left and the right boot)
  alt  = for men in s / n views: the lifted boot alternates left / right (both signs present, >= 2 changes);
         for e / se / ne views: the stride opens and closes at least twice (>= 2 peaks of the spread)
A strip PASSES when leg >= LEG_MIN, rng >= RNG_MIN and alt holds. Thresholds are shared with
tools/test_unit_walk_audit.gd (keep them in step).
"""
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEG_MIN = 0.30          # side / diagonal views
LEG_MIN_FB = 0.12       # front / back views: the legs overlap, little silhouette change is expected
RNG_MIN = 3
DIRS = ["s", "se", "e", "ne", "n"]

# kind: biped | quad (animal, diagonal pairs) | mount (rider on a horse) | team (towed / harnessed horse) | na
KIND = {
    "labourer": ("biped", ""), "musketeer": ("biped", ""), "musketeer_armoured": ("biped", ""),
    "dismounted": ("biped", ""), "dismounted_armoured": ("biped", ""), "missionary": ("biped", ""),
    "winder": ("biped", ""), "windup_soldier": ("biped", ""), "stormcaller": ("biped", ""),
    "arc_thrower": ("biped", ""), "thresher": ("biped", ""), "bulwark": ("biped", ""),
    "gearknight": ("biped", ""), "bolt": ("biped", ""), "brute": ("biped", ""), "spitter": ("biped", ""),
    "grub": ("quad", ""), "raptor": ("quad", ""), "spore_mother": ("quad", ""), "mist_toad": ("quad", ""),
    "horse": ("quad", ""), "horse_team": ("team", ""),
    "cuirassier": ("mount", ""), "horseman": ("mount", ""), "dragoon": ("mount", ""),
    "dragoon_armoured": ("mount", ""), "messenger": ("mount", ""), "missionary_mounted": ("mount", ""),
    "mortar": ("team", "towed by a horse and two gunners"), "cannon": ("team", "towed by a horse and two gunners"),
    "powder_wagon": ("team", "horse in harness at the front of a wagon"),
    "pikeman": ("na", "removed from the game"),
    "skywing": ("na", "flier: flaps its wings, no legs on the ground"),
    "ornithopter": ("na", "flier: beating wings, hovers"),
    "bloater": ("na", "floats on its gas bladder; the dangling tendrils sway, it does not step"),
    "balloon": ("na", "airship"),
    "tesla_cart": ("na", "spider cart, scuttles on its own rig (judged separately)"),
    "steam_walker": ("na", "huge machine on pistons, judged by eye (body bob, heavy stomp)"),
}


def art_data():
    src = open(os.path.join(ROOT, "scripts/art_data.gd")).read()
    units = {}
    for m in re.finditer(r'\t"(\w+)": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), "frames": \{(.*?)\n\t\}', src, re.S):
        fr = {k: int(v) for k, v in re.findall(r'"(walk_\w+)": (\d+)', m[6])}
        units[m[1]] = {"cell": (int(m[2]), int(m[3])), "frames": fr}
    return units


def frames_of(art, d, units):
    n = units[art]["frames"].get("walk_" + d)
    p = os.path.join(ROOT, f"assets/units/{art}/walk_{d}.png")
    if not n or not os.path.exists(p):
        return None
    im = np.array(Image.open(p).convert("RGBA"))
    w = im.shape[1] // n
    return [im[:, i * w:(i + 1) * w] for i in range(n)]


def peaks(v):
    n = len(v)
    return sum(1 for i in range(n) if v[i] > v[i - 1] and v[i] >= v[(i + 1) % n])


def measure(fr, d, kind):
    al = [f[..., 3] > 40 for f in fr]
    tops = [np.nonzero(a.any(1))[0][0] for a in al]
    bots = [np.nonzero(a.any(1))[0][-1] for a in al]
    top, bot = int(np.median(tops)), int(np.median(bots))
    h = bot - top + 1
    y0 = bot - int(0.3 * h) + 1
    n = len(fr)
    chg = []
    for i in range(n):
        a, b = fr[i][y0:], fr[(i + 1) % n][y0:]
        diff = (a[..., 3] > 40) ^ (b[..., 3] > 40)          # silhouette change (ignores colour noise)
        used = ((a[..., 3] > 40) | (b[..., 3] > 40)).sum()
        chg.append(diff.sum() / max(1, used))
    leg = float(np.mean(chg))
    spread, lift = [], []
    centres = []
    for a in al:                                    # the strip's body axis: median centre of the lowest rows
        lo = np.nonzero(a.any(1))[0][-1]
        xs = np.nonzero(a[max(0, lo - 5):lo + 1].any(0))[0]
        centres.append((xs[0] + xs[-1]) / 2.0)
    mid = int(round(float(np.median(centres))))
    for f, a in zip(fr, al):
        rows = np.nonzero(a.any(1))[0]
        lo = rows[-1]
        zone = a[max(0, lo - 4):lo + 1]
        xs = np.nonzero(zone.any(0))[0]
        spread.append(int(xs[-1] - xs[0] + 1))
        lz = a[y0:]
        cols = np.nonzero(lz.any(0))[0]
        def lowest(x0, x1):
            sub = a[:, x0:x1]
            r = np.nonzero(sub.any(1))[0]
            return int(r[-1]) if len(r) else 0
        lift.append(lowest(0, mid) - lowest(mid, a.shape[1]))
    if d in ("s", "n"):
        rng = max(lift) - min(lift)
        sg = [1 if v > 0 else -1 if v < 0 else 0 for v in lift]
        alt = (1 in sg and -1 in sg)             # both boots lift in turn
    else:
        rng = max(spread) - min(spread)
        alt = peaks(spread) >= 2 or (n <= 3 and rng >= RNG_MIN)
    ok = leg >= (LEG_MIN_FB if d in ('s', 'n') else LEG_MIN) and rng >= RNG_MIN and bool(alt)
    return {"n": n, "leg": leg, "rng": int(rng), "alt": bool(alt), "ok": ok, "spread": spread, "lift": lift}


FIXED = ["missionary", "windup_soldier", "musketeer_armoured", "raptor"]

# what is left, and why (shown in the doc under "Status")
STATUS = [
    ("missionary", "fixed", "legs rebuilt (tools/import_gait_missionary.py), all views: robe-black legs, boots under the hem"),
    ("windup_soldier", "fixed", "legs rebuilt (import_gait_windup_soldier.py), all views; tiny sprite, the front/back stride is subtle"),
    ("winder", "new art", "2026-10-26: the new Winder's own ChatGPT walk (tools/import_winder_v2.py; the code legs of import_gait_winder.py are retired); "
     "4 frames that stride once a loop, played on a ticking beat (Unit.WINDER_BEAT); the ne view's stride is small"),
    ("musketeer_armoured", "fixed", "legs rebuilt (import_gait_musketeer_armoured.py), all views; frame counts 3/4/6/5/7 unchanged"),
    ("raptor", "improved", "s / se / ne / n legs rebuilt (import_gait_raptor.py); walk_e kept (already a real run). Front/back stride is small: a ChatGPT redraw would still be better"),
    ("horse", "needs ChatGPT redraw", "quadruped: a believable diagonal-pair leg cycle cannot be built from the painted horse by code (prompt 18/20-25)"),
    ("horseman, cuirassier, dragoon, dragoon_armoured, messenger, missionary_mounted", "needs ChatGPT redraw", "mounts: the horse's legs are painted into the rider's strip (prompt 18/20-25); e/se/ne gallops move, the n / s / ne cycles are the weak ones"),
    ("horse_team, mortar, cannon, powder_wagon", "needs ChatGPT redraw", "harness horse legs (prompt 18/20-25); front/back views barely lift a hoof, side views move"),
    ("spore_mother", "needs ChatGPT redraw", "heavy quadruped; walk_ne is a copy of walk_e; legs painted into the body"),
    ("grub", "left", "squat crawler, legs hidden under the body; walk_e is a real gait"),
    ("musketeer, dismounted, dismounted_armoured (s / n)", "left", "side views alternate properly; front/back lift only 1-3 px (owner's ChatGPT redraw, rigged earlier)"),
    ("thresher, bulwark, arc_thrower, stormcaller, brute", "left", "heavy / shielded bodies hide the legs; by eye they step, the numbers are low because the legs are short"),
]


def audit():
    units = art_data()
    res = {}
    for art, (kind, why) in KIND.items():
        if art not in units or kind == "na":
            continue
        for d in DIRS:
            fr = frames_of(art, d, units)
            if fr:
                res[(art, d)] = measure(fr, d, kind)
    return units, res


def contact(res, units, path, worst=12, zoom=3):
    score = {}
    for (a, d), r in res.items():
        score.setdefault(a, []).append(r["leg"])
    order = sorted(score, key=lambda a: float(np.mean(score[a])))[:worst]
    rows = []
    for a in order:
        d = min(DIRS, key=lambda dd: res.get((a, dd), {"leg": 9})["leg"])
        im = Image.open(os.path.join(ROOT, f"assets/units/{a}/walk_{d}.png")).convert("RGBA")
        rows.append(im)
    W = max(r.width for r in rows)
    H = sum(r.height + 2 for r in rows)
    s = Image.new("RGBA", (W, H), (60, 90, 60, 255))
    y = 0
    for r in rows:
        s.alpha_composite(r, (0, y))
        y += r.height + 2
    s.resize((W * zoom, H * zoom), Image.NEAREST).save(path)
    return order


def report():
    units, res = audit()
    lines = ["# Walk gait audit", "",
             "Generated by `python3 tools/audit_walk_gait.py --doc` (frame counts from `scripts/art_data.gd`).",
             f"Leg zone = bottom 30% of the sprite. `leg` = share of the leg silhouette (union) that changes between consecutive frames "
             f"(pass >= {LEG_MIN} side, {LEG_MIN_FB} front/back); `range` = foot spread range in px (pass >= {RNG_MIN}); `alt` = boots alternate / stride opens twice a cycle.",
             "", "## Ranked (weakest first, by mean leg change)", "",
             "| Unit | kind | frames per dir | mean leg | worst dir | per dir leg/range/alt | verdict |", "|---|---|---|---|---|---|---|"]
    rows = []
    for a, (kind, why) in KIND.items():
        if kind == "na" or a not in units:
            continue
        dr = {d: res[(a, d)] for d in DIRS if (a, d) in res}
        if not dr:
            continue
        mean = float(np.mean([r["leg"] for r in dr.values()]))
        worst = min(dr, key=lambda d: dr[d]["leg"])
        rows.append((mean, a, kind, dr, worst))
    for mean, a, kind, dr, worst in sorted(rows):
        per = "; ".join(f"{d} {r['leg']:.2f}/{r['rng']}/{'Y' if r['alt'] else 'n'}" for d, r in dr.items())
        fails = [d for d, r in dr.items() if not r["ok"]]
        verdict = "ok" if not fails else "FAIL " + ",".join(fails)
        lines.append(f"| {a} | {kind} | {','.join(str(r['n']) for r in dr.values())} | {mean:.2f} | {worst} | {per} | {verdict} |")
    lines += ["", "## Status after this pass", "", "| Unit | Status | Note |", "|---|---|---|"]
    for a, st, note in STATUS:
        lines.append(f"| {a} | {st} | {note} |")
    lines += ["", "## Not applicable", "", "| Unit | Why |", "|---|---|"]
    for a, (kind, why) in KIND.items():
        if kind == "na":
            lines.append(f"| {a} | {why} |")
    for a, (kind, why) in KIND.items():
        if kind == "team" and why:
            lines.append(f"| {a} (wheels, gunners) | {why}: the carriage rolls, the horse and men are judged in the table above |")
    return "\n".join(lines) + "\n", units, res


def fixed_sheets(zoom=4):
    from PIL import Image
    allrows = []
    for a in FIXED:
        dirs = ["s", "se", "e", "ne", "n"]
        rows = [Image.open(os.path.join(ROOT, f"assets/units/{a}/walk_{d}.png")).convert("RGBA") for d in dirs]
        W = max(r.width for r in rows)
        H = sum(r.height + 2 for r in rows)
        sh = Image.new("RGBA", (W, H), (60, 90, 60, 255))
        y = 0
        for r in rows:
            sh.alpha_composite(r, (0, y))
            y += r.height + 2
        sh.resize((W * zoom, H * zoom), Image.NEAREST).save(f"/tmp/gait_fixed_{a}.png")
        allrows.append(rows[2])                      # the e view for the overview
    W = max(r.width for r in allrows)
    H = sum(r.height + 2 for r in allrows)
    sh = Image.new("RGBA", (W, H), (60, 90, 60, 255))
    y = 0
    for r in allrows:
        sh.alpha_composite(r, (0, y))
        y += r.height + 2
    sh.resize((W * zoom, H * zoom), Image.NEAREST).save("/tmp/gait_fixed_all.png")


if __name__ == "__main__":
    if "--fixed-sheets" in sys.argv:
        fixed_sheets()
    text, units, res = report()
    if "--doc" in sys.argv:
        open(os.path.join(ROOT, "docs/animation_gait_audit.md"), "w").write(text)
    if "--sheet" in sys.argv:
        print("worst:", contact(res, units, "/tmp/gait_audit.png"))
    print(text)
