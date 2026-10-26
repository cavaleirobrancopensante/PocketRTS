#!/usr/bin/env python3
"""Run build-order matches ONE AT A TIME (the box is shared) and summarise them (docs/build_orders_study.md).

  python3 tools/study/bo_run.py calib  --out /tmp/bo/runs          # every build against a sleeping opponent (timings)
  python3 tools/study/bo_run.py matrix --out /tmp/bo/runs          # the match-ups of the study (see MATRIX)
  python3 tools/study/bo_run.py one sa sb map seed --out /tmp/bo/runs [--end 600]
  python3 tools/study/bo_run.py summary --out /tmp/bo/runs          # tables from the finished matches

A match is done when <out>/<id>.json exists (bo_match.gd writes it last, by rename); a re-run skips it. Touch <out>/STOP to
stop after the current match. Nothing here changes the game.
"""
import argparse, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
GODOT = os.environ.get("GODOT", "/home/claude/godot/godot")
BUILDS = {b["name"]: b for b in json.load(open(os.path.join(HERE, "build_orders.json")))["builds"]}
FOE = {"crown": ["brood", "clockwork"], "brood": ["crown", "clockwork"], "clockwork": ["crown", "brood"]}


def mid(sa, sb, m, seed, swap, fa=None, fb=None):
    a = sa.replace(":", "-") + ("-" + fa if fa and not sa in BUILDS else "")
    b = sb.replace(":", "-") + ("-" + fb if fb and not sb in BUILDS else "")
    return "%s__%s__%s_%d%s" % (a, b, m, seed, "_s" if swap else "")


def run(out, sa, sb, m, seed, swap=0, end=600, fa=None, fb=None, limit=900):
    i = mid(sa, sb, m, seed, swap, fa, fb)
    path = os.path.join(out, i + ".json")
    if os.path.exists(path):
        return path, "skip"
    cmd = [GODOT, "--headless", "--fixed-fps", "30", "--path", PROJECT, "--script", "res://tools/study/bo_match.gd", "--",
           "sa:" + sa, "sb:" + sb, "map:" + m, "seed:%d" % seed, "swap:%d" % swap, "end:%d" % end, "out:" + path]
    if fa:
        cmd.append("a:" + fa)
    if fb:
        cmd.append("b:" + fb)
    t0 = time.time()
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=limit)
    except subprocess.TimeoutExpired:
        pass
    return path, "%.0fs" % (time.time() - t0)


def calib(a):
    for name, b in BUILDS.items():
        if os.path.exists(os.path.join(a.out, "STOP")):
            return
        foe = FOE[b["faction"]][0]
        p, how = run(a.out, name, "idle", a.map or "ashford_crossing", 1, end=a.end or 420, fb=foe)
        print(name, how, flush=True)


# The match-ups (the box is shared, so the list is kept to what the doc needs): every build against the ordinary Hard
# computer (Balanced) of both other factions on a small map; the openings against each other where the doc needs a direct
# answer (rush against greed, and so on); the openings whose worth depends on the walk on a big map too; the ordinary
# computers against each other as the baseline.
MAPS2 = ["kestrel_rise", "frostmere"]
DUELS = [
    # Crown against Brood
    ("crown_horse_rush", "brood_economy"), ("crown_musket_wall", "brood_xrush"), ("crown_fast_expand", "brood_xrush"),
    ("crown_fast_expand", "brood_pool_eco"), ("crown_balloon_drop", "brood_economy"), ("crown_cannon_push", "brood_economy"),
    # Crown against Clockwork
    ("crown_horse_rush", "cw_jack_tech"), ("crown_musket_wall", "cw_soldier_rush"), ("crown_fast_expand", "cw_soldier_rush"),
    ("crown_balloon_drop", "cw_jack_tech"), ("cw_owl_harass", "crown_musket_wall"), ("crown_cannon_push", "cw_turret_expand"),
    ("cw_pendulum_push", "crown_musket_wall"), ("cw_windup_swarm", "crown_musket_wall"),
    # Brood against Clockwork
    ("brood_xrush", "cw_turret_expand"), ("brood_xrush", "cw_jack_tech"), ("brood_economy", "cw_soldier_rush"),
    ("brood_spitter_timing", "cw_jack_tech"), ("cw_pendulum_push", "brood_economy"),
    # mirrors
    ("crown_horse_rush", "crown_musket_wall"), ("brood_xrush", "brood_economy"), ("cw_soldier_rush", "cw_jack_tech"),
    # so that every opening meets at least one opening of another faction
    ("crown_balloon_raid", "brood_economy"), ("crown_balloon_raid", "cw_jack_tech"), ("crown_dragoon_raid", "brood_economy"),
    ("brood_spitter_timing", "crown_musket_wall"), ("brood_air", "crown_musket_wall"), ("brood_brute_timing", "crown_musket_wall"),
    ("cw_owl_harass", "brood_economy"), ("cw_jack_rush", "crown_musket_wall"), ("brood_pool_eco", "cw_jack_tech"),
]
BIG_MAP = [   # (build, foe faction) also played on the big map: the openings whose worth depends on the walk
    ("crown_horse_rush", "brood"), ("crown_balloon_drop", "clockwork"), ("brood_xrush", "crown"), ("brood_pool_eco", "clockwork"),
    ("cw_soldier_rush", "crown"), ("cw_soldier_rush", "brood"), ("cw_jack_tech", "crown"), ("cw_windup_swarm", "crown"),
    ("cw_owl_harass", "brood"),
]


def matrix_specs(a):
    """In the order they are worth running (a stop part-way still leaves the most useful ones done): every build against
    the ordinary computer of both other factions on the small map, the duels, the big map, then the computer's baseline."""
    specs = []
    small, big = MAPS2
    for name, b in BUILDS.items():
        for foe in FOE[b["faction"]]:
            specs.append((name, "ai:balanced", small, 11, 0, None, foe))
    for x, y in DUELS:
        specs.append((x, y, small, 21, 1, None, None))
    for name, foe in BIG_MAP:
        specs.append((name, "ai:balanced", big, 12, 1, None, foe))
    for fa, fb in (("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork")):
        specs.append(("ai:balanced", "ai:balanced", small, 31, 0, fa, fb))
    for fa, fb in (("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork")):
        specs.append(("ai:balanced", "ai:balanced", big, 32, 1, fa, fb))
    return specs


def matrix(a):
    specs = matrix_specs(a)
    if a.only:
        specs = [s for s in specs if a.only in s[0] or a.only in s[1]]
    n = 0
    for sa, sb, m, seed, swap, fa, fb in specs:
        if os.path.exists(os.path.join(a.out, "STOP")):
            print("STOP", flush=True)
            return
        p, how = run(a.out, sa, sb, m, seed, swap, end=a.end or 600, fa=fa, fb=fb)
        n += 1
        print("%d/%d %s %s %s %s" % (n, len(specs), sa, sb, m, how), flush=True)


def load(out):
    rows = []
    for f in sorted(os.listdir(out)):
        if f.endswith(".json"):
            try:
                rows.append(json.load(open(os.path.join(out, f))))
            except Exception:
                pass
    return rows


def fmt_t(t):
    if t is None or t < 0:
        return "-"
    return "%d:%02d" % (int(t) // 60, int(t) % 60)


def side_of(r, spec):
    for i, s in enumerate(r["sides"]):
        if s["spec"] == spec:
            return i, s
    return None, None


def summary(a):
    rows = load(a.out)
    print("%d matches" % len(rows))
    for r in rows:
        ta, A = side_of(r, r["sa"])
        tb, Bs = side_of(r, r["sb"])
        if A is None or Bs is None:
            continue
        res = "draw" if r["winner_team"] < 0 else ("A" if r["winner_team"] == ta else "B")
        def wv(S):
            if not S.get("bo") or not S["bo"]["waves"]:
                return "-"
            w = S["bo"]["waves"][0]
            return "go %s arr %s kill %s lost %s" % (fmt_t(w["go"]), fmt_t(w["arrive"]), w.get("killed_value", "?"), w.get("lost_value", "?"))
        print("%-22s %-22s %-16s %-6s %-5s A:%s | B:%s | wk lost %d/%d" % (r["sa"], r["sb"], r["map"], r["cause"], res, wv(A), wv(Bs),
                                                                            A["workers_lost"], Bs["workers_lost"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["calib", "matrix", "one", "summary"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--out", required=True)
    ap.add_argument("--map")
    ap.add_argument("--end", type=int)
    ap.add_argument("--only")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    if a.mode == "calib":
        calib(a)
    elif a.mode == "matrix":
        matrix(a)
    elif a.mode == "one":
        sa, sb, m, seed = a.args[:4]
        print(run(a.out, sa, sb, m, int(seed), end=a.end or 600))
    else:
        summary(a)


if __name__ == "__main__":
    main()
