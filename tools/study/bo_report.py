#!/usr/bin/env python3
"""Tables for docs/build_orders_study.md from the build-order matches (tools/study/bo_run.py matrix / calib).

  python3 tools/study/bo_report.py --runs /tmp/bo/runs             # Markdown tables on stdout
  python3 tools/study/bo_report.py --runs /tmp/bo/calib --calib     # each build alone (a sleeping opponent): its timeline
  python3 tools/study/bo_report.py --runs /tmp/bo/runs --notes      # one line per match: what happened (for writing up)

Results are written as words, for reading aloud (a match ends at 8:00 or on a victory): "won at 6:12" (the enemy has
no buildings left), "ahead" (at the end, Game.power at least 1.25 times the enemy's), "even", "behind", "lost at 6:12".
"""
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILDS = {b["name"]: b for b in json.load(open(os.path.join(HERE, "build_orders.json")))["builds"]}
SMALL, BIG = "kestrel_rise", "frostmere"
FACTIONS = ("crown", "brood", "clockwork")


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
    """(team of A, side A, team of B, side B) by spec; for computer-against-computer rows the sides by faction a / b."""
    if r["sa"] == r["sb"]:
        ta = next(i for i, s in enumerate(r["sides"]) if s["faction"] == r["fa"])
        return ta, r["sides"][ta], 1 - ta, r["sides"][1 - ta]
    ta = next(i for i, s in enumerate(r["sides"]) if s["spec"] == r["sa"])
    return ta, r["sides"][ta], 1 - ta, r["sides"][1 - ta]


def result_for(r, team):
    w = r["winner_team"]
    if w < 0:
        return "even"
    if r["cause"] == "victory":
        return ("won at " if w == team else "lost at ") + fmt_t(r["end_t"])
    return "ahead" if w == team else "behind"


def score(code):
    return 1.0 if code.startswith("won") or code == "ahead" else (0.0 if code.startswith("lost") or code == "behind" else 0.5)


def first_wave(S):
    bo = S.get("bo")
    if not bo or not bo.get("waves"):
        return None
    return bo["waves"][0]


def drop_text(S):
    bo = S.get("bo")
    if not bo or not bo.get("drops"):
        return ""
    d = bo["drops"][0]
    if d.get("hover"):
        s = "balloon over them %s" % fmt_t(d.get("landed", -1))
        if "killed_value" in d:
            s += ", its basket killed %d worth" % d["killed_value"]
        return s + " (%s)" % d.get("result", "?")
    return "dropped %d men at %s" % (d.get("aboard", 0), fmt_t(d.get("landed", -1))) if d.get("result") == "landed" else "drop: %s" % d.get("result", "?")


def wave_text(S):
    w = first_wave(S)
    if not w:
        a = S.get("ai_attack")
        return ("its own first attack %s" % fmt_t(a)) if a else "no attack"
    s = "attack left %s, arrived %s" % (fmt_t(w["go"]), fmt_t(w["arrive"]))
    if w.get("killed_value") is not None:
        s += ", killed %d worth for %d lost (%s)" % (w["killed_value"], w["lost_value"], w.get("why") or "?")
    return s


def match_text(r):
    ta, A, tb, Bs = sides(r)
    ea, eb = A.get("end", {}), Bs.get("end", {})
    bits = ["%s: %s" % (who(r, A), wave_text(A))]
    if drop_text(A):
        bits.append(drop_text(A))
    if first_wave(Bs) or Bs.get("ai_attack"):
        bits.append("%s: %s" % (who(r, Bs), wave_text(Bs)))
    bits.append("workers lost %d and %d" % (A["workers_lost"], Bs["workers_lost"]))
    bits.append("value killed %d and %d" % (ea.get("value_killed", 0), eb.get("value_killed", 0)))
    return "; ".join(bits)


def who(r, S):
    if S["spec"] in BUILDS:
        return BUILDS[S["spec"]]["label"].split(":")[0]
    return "the %s computer" % S["faction"].title()


def label(name):
    return BUILDS[name]["label"]


def vs_ai_table(rows, m=SMALL):
    """Every build against the ordinary Hard computer (Balanced) of both other factions."""
    print("| Opening | against the Crown computer | against the Brood computer (old, being rewritten) | against the Clockwork computer |")
    print("|---|---|---|---|")
    tot = {}
    for name, b in BUILDS.items():
        cells = []
        for foe in FACTIONS:
            if foe == b["faction"]:
                cells.append("")
                continue
            hit = [r for r in rows if r["sa"] == name and r["sb"] == "ai:balanced" and r["map"] == m and sides(r)[3]["faction"] == foe]
            if not hit:
                cells.append("not played")
                continue
            code = result_for(hit[0], sides(hit[0])[0])
            cells.append(code)
            if foe != "brood":
                tot.setdefault(name, []).append(score(code))
        print("| %s | %s | %s | %s |" % (label(name), cells[0], cells[1], cells[2]))
    return tot


def notes(rows):
    for r in sorted(rows, key=lambda r: (r["map"], r["sa"], r["sb"])):
        ta, A, tb, Bs = sides(r)
        opp = label(r["sb"]) if r["sb"] in BUILDS else "the %s computer" % Bs["faction"].title()
        print("- %s against %s on %s: %s. %s." % (label(r["sa"]) if r["sa"] in BUILDS else "the %s computer" % A["faction"].title(),
                                               opp, r["map"].replace("_", " ").title(), result_for(r, ta), match_text(r)))


def duel_table(rows, m=SMALL):
    print("| Opening | against | result for the first | what happened |")
    print("|---|---|---|---|")
    for r in rows:
        if r["map"] != m or not (r["sa"] in BUILDS and r["sb"] in BUILDS):
            continue
        ta, A, tb, Bs = sides(r)
        print("| %s | %s | %s | %s |" % (label(r["sa"]), label(r["sb"]), result_for(r, ta), match_text(r)))


def big_table(rows):
    print("| Opening | against | Kestrel Rise (small) | Frostmere (big) |")
    print("|---|---|---|---|")
    for r in rows:
        if r["map"] != BIG or not r["sa"] in BUILDS or r["sb"] != "ai:balanced":
            continue
        ta, A, tb, Bs = sides(r)
        small = [x for x in rows if x["map"] == SMALL and x["sa"] == r["sa"] and x["sb"] == "ai:balanced" and sides(x)[3]["faction"] == Bs["faction"]]
        print("| %s | the %s computer | %s | %s |" % (label(r["sa"]), Bs["faction"].title(), result_for(small[0], sides(small[0])[0]) if small else "not played",
                                                   result_for(r, ta)))


def base_table(rows):
    print("| Match-up | Kestrel Rise (small) | Frostmere (big) |")
    print("|---|---|---|")
    pairs = {}
    for r in rows:
        if r["sa"].startswith("ai:") and r["sb"].startswith("ai:"):
            pairs.setdefault((r["fa"], r["fb"]), {})[r["map"]] = r
    for (fa, fb), by in pairs.items():
        cells = []
        for m in (SMALL, BIG):
            r = by.get(m)
            if not r:
                cells.append("not played")
                continue
            ta = next(i for i, s in enumerate(r["sides"]) if s["faction"] == fa)
            cells.append("the %s %s (its first attack %s; the %s's %s)" % (fa.title(), result_for(r, ta), fmt_t(r["sides"][ta].get("ai_attack", -1)),
                                                                        fb.title(), fmt_t(r["sides"][1 - ta].get("ai_attack", -1))))
        print("| %s computer against the %s computer | %s | %s |" % (fa.title(), fb.title(), cells[0], cells[1]))


def calib_table(rows, faction=None):
    print("| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the hall |")
    print("|---|---|---|---|---|---|---|---|")
    for name, b in BUILDS.items():
        if faction and b["faction"] != faction:
            continue
        hit = [r for r in rows if r["sa"] == name]
        if not hit:
            continue
        r = hit[0]
        ta, A, tb, Bs = sides(r)
        first = min([min(v) for k, v in A["spawns"].items() if k not in ("labourer", "grub", "winder", "horse")] or [-1])

        def snap(t, key):
            s = A["snaps"].get(str(t))
            return s[key] if s else None
        vals = []
        for t in (180, 240, 300, 360):
            v = snap(t, "value")
            vals.append("{:,}".format(v) if v is not None else "(over)")
        w = first_wave(A)
        att = "%s, %s" % (fmt_t(w["go"]), fmt_t(w["arrive"])) if w else "none"
        bo = A.get("bo") or {}
        if bo.get("drops"):
            d = bo["drops"][0]
            att = "balloon %s, %s" % (fmt_t(d.get("fly", -1)), fmt_t(d.get("landed", -1)))
        e3, e6 = snap(180, "earned"), snap(360, "earned")
        print("| %s | %s | %s | %s | %s | %s | %s / %s | %s |" % (label(name), fmt_t(first), vals[0], vals[1], vals[2], vals[3],
                                                             "{:,}".format(e3) if e3 is not None else "-", "{:,}".format(e6) if e6 is not None else "(over)", att))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", required=True)
    ap.add_argument("--calib", action="store_true")
    ap.add_argument("--faction")
    ap.add_argument("--notes", action="store_true")
    a = ap.parse_args()
    rows = load(a.runs)
    if a.calib:
        calib_table(rows, a.faction)
        return
    if a.notes:
        notes(rows)
        return
    print("## against the computer (Kestrel Rise)\n")
    vs_ai_table(rows)
    print("\n## duels (Kestrel Rise)\n")
    duel_table(rows)
    print("\n## the big map\n")
    big_table(rows)
    print("\n## the computers against each other\n")
    base_table(rows)


if __name__ == "__main__":
    main()
