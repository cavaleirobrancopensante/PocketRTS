#!/usr/bin/env python3
"""Tables for docs/build_orders_study.md from the build-order matches (tools/study/bo_run.py matrix / calib).

  python3 tools/study/bo_report.py --runs /tmp/bo/runs             # Markdown tables on stdout
  python3 tools/study/bo_report.py --runs /tmp/bo/calib --calib     # each build alone (a sleeping opponent): its timeline

Result codes (the match ends at 10:00 or on a victory): "W 6:12" won (the enemy has no buildings left) at 6:12;
"W+" ahead at the end (Game.power at least 1.25x the enemy's); "=" about even; "L+" behind; "L 6:12" destroyed at 6:12.
"""
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILDS = {b["name"]: b for b in json.load(open(os.path.join(HERE, "build_orders.json")))["builds"]}
MAPS2 = ["kestrel_rise", "frostmere"]


def fmt_t(t):
    if t is None or t < 0:
        return "-"
    return "%d:%02d" % (int(t) // 60, int(t) % 60)


def load(d):
    out = []
    for f in sorted(os.listdir(d)):
        if f.endswith(".json"):
            try:
                out.append(json.load(open(os.path.join(d, f))))
            except Exception:
                pass
    return out


def sides(r):
    """(team of A, side A, team of B, side B) by spec; for ai-vs-ai rows the sides by faction order a/b."""
    if r["sa"] == r["sb"]:
        ta = r["a_team"]
        return ta, r["sides"][ta], 1 - ta, r["sides"][1 - ta]
    ta = next(i for i, s in enumerate(r["sides"]) if s["spec"] == r["sa"])
    return ta, r["sides"][ta], 1 - ta, r["sides"][1 - ta]


def result_for(r, team):
    w = r["winner_team"]
    if w < 0:
        return "="
    if r["cause"] == "victory":
        return ("W " if w == team else "L ") + fmt_t(r["end_t"])
    return "W+" if w == team else "L+"


def score(code):
    return 1.0 if code.startswith("W") else (0.0 if code.startswith("L") else 0.5)


def first_wave(S):
    bo = S.get("bo")
    if not bo or not bo.get("waves"):
        return None
    return bo["waves"][0]


def wave_text(S):
    w = first_wave(S)
    if not w:
        a = S.get("ai_attack")
        return ("own wave %s" % fmt_t(a)) if a else "-"
    k = w.get("killed_value", None)
    l = w.get("lost_value", None)
    s = "left %s, there %s" % (fmt_t(w["go"]), fmt_t(w["arrive"]))
    if k is not None:
        s += ", killed %d / lost %d" % (k, l)
    return s


def key_of(r):
    return (r["sa"], r["sb"], r["sides"][1 - next(i for i, s in enumerate(r["sides"]) if s["spec"] == r["sa"])]["faction"] if r["sa"] != r["sb"] else r["fb"])


def vs_ai_table(rows):
    """Every build against the ordinary Hard computer (Balanced) of both other factions, on both maps."""
    print("| Build | vs | %s | %s | first attack (Kestrel Rise) | first attack (Frostmere) |" % tuple(m.replace("_", " ").title() for m in MAPS2))
    print("|---|---|---|---|---|---|")
    tot = {}
    for name, b in BUILDS.items():
        for foe in [f for f in ("crown", "brood", "clockwork") if f != b["faction"]]:
            cells = []
            waves = []
            for m in MAPS2:
                hit = [r for r in rows if r["sa"] == name and r["sb"] == "ai:balanced" and r["map"] == m and sides(r)[3]["faction"] == foe]
                if not hit:
                    cells.append("?")
                    waves.append("")
                    continue
                r = hit[0]
                ta, A, tb, Bs = sides(r)
                code = result_for(r, ta)
                cells.append(code)
                waves.append(wave_text(A) + ("; workers lost %d/%d" % (A["workers_lost"], Bs["workers_lost"])))
                tot.setdefault(name, []).append(score(code))
            print("| %s | %s | %s | %s | %s | %s |" % (b["label"], foe.title(), cells[0], cells[1], waves[0], waves[1]))
    print()
    print("| Build | score against the computer (4 games) |")
    print("|---|---|")
    for name in BUILDS:
        s = tot.get(name, [])
        if s:
            print("| %s | %.1f of %d |" % (BUILDS[name]["label"], sum(s), len(s)))


def duel_table(rows):
    print("| Opening A | Opening B | %s | %s | notes |" % tuple(m.replace("_", " ").title() for m in MAPS2))
    print("|---|---|---|---|---|")
    pairs = []
    for r in rows:
        if r["sa"] in BUILDS and r["sb"] in BUILDS and (r["sa"], r["sb"]) not in pairs:
            pairs.append((r["sa"], r["sb"]))
    for a, b in pairs:
        cells = []
        notes = []
        for m in MAPS2:
            hit = [r for r in rows if r["sa"] == a and r["sb"] == b and r["map"] == m]
            if not hit:
                cells.append("?")
                continue
            r = hit[0]
            ta, A, tb, Bs = sides(r)
            cells.append(result_for(r, ta))
            wa, wb = first_wave(A), first_wave(Bs)
            bits = []
            if wa:
                bits.append("A %s" % wave_text(A))
            if wb:
                bits.append("B %s" % wave_text(Bs))
            bits.append("workers lost %d/%d" % (A["workers_lost"], Bs["workers_lost"]))
            notes.append("%s: %s" % (m.split("_")[0], "; ".join(bits)))
        print("| %s | %s | %s | %s | %s |" % (BUILDS[a]["label"], BUILDS[b]["label"], cells[0], cells[1], " / ".join(notes)))


def base_table(rows):
    print("| Match-up | %s | %s |" % tuple(m.replace("_", " ").title() for m in MAPS2))
    print("|---|---|---|")
    pairs = {}
    for r in rows:
        if r["sa"].startswith("ai:") and r["sb"].startswith("ai:"):
            fa, fb = r["fa"], r["fb"]
            pairs.setdefault((fa, fb), {})[r["map"]] = r
    for (fa, fb), by in pairs.items():
        cells = []
        for m in MAPS2:
            r = by.get(m)
            if not r:
                cells.append("?")
                continue
            ta = next(i for i, s in enumerate(r["sides"]) if s["faction"] == fa)
            cells.append(result_for(r, ta) + " (%s first wave %s)" % (fa.title(), fmt_t(r["sides"][ta].get("ai_attack", -1))))
        print("| %s vs %s | %s | %s |" % (fa.title(), fb.title(), cells[0], cells[1]))


def calib_table(rows):
    print("| Build | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | workers 3:00 / 6:00 | attack leaves / arrives |")
    print("|---|---|---|---|---|---|---|---|---|")
    for name, b in BUILDS.items():
        hit = [r for r in rows if r["sa"] == name]
        if not hit:
            continue
        r = hit[0]
        ta, A, tb, Bs = sides(r)
        first = min([min(v) for k, v in A["spawns"].items() if not k in ("labourer", "grub", "winder", "horse")] or [-1])
        def snap(t, key):
            s = A["snaps"].get(str(t))
            return s[key] if s else None
        vals = []
        for t in (180, 240, 300, 360):
            v = snap(t, "value")
            vals.append("%d" % v if v is not None else "-")
        w = first_wave(A)
        att = "%s / %s" % (fmt_t(w["go"]), fmt_t(w["arrive"])) if w else "-"
        print("| %s | %s | %s | %s | %s | %s | %s / %s | %s / %s | %s |" % (b["label"], fmt_t(first), vals[0], vals[1], vals[2], vals[3],
                                                                           snap(180, "earned"), snap(360, "earned"), snap(180, "workers"), snap(360, "workers"), att))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", required=True)
    ap.add_argument("--calib", action="store_true")
    a = ap.parse_args()
    rows = load(a.runs)
    if a.calib:
        calib_table(rows)
        return
    print("## vs the computer\n")
    vs_ai_table(rows)
    print("\n## duels\n")
    duel_table(rows)
    print("\n## baseline\n")
    base_table(rows)


if __name__ == "__main__":
    main()
