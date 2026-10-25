#!/usr/bin/env python3
"""Turn <runs>/games/*.json, ts/*.csv and logs/*.log into flat CSVs (pandas-friendly):

  games.csv       one row per game (setup, result, length, cause)
  sides.csv       one row per game and side (faction, plan, economy totals, tech timings, losses, waves ...)
  timeseries.csv  one row per game, side and 30 s (see study_game.gd HEADER)
  waves.csv       one row per attack wave / raiding party
  events.csv      key lines of the match logs (walls, expansions, lost buildings, failed rushes, ...)

  python3 tools/study/aggregate.py --runs /home/claude/study_runs --out docs/study_data
"""
import argparse, csv, glob, json, os, re

TS_HEADER = ["id", "t", "team", "faction", "gold", "res2", "earned", "res2_in", "spent", "supply", "cap", "workers",
             "idle_workers", "army_value", "army_supply", "army_units", "army_idle", "halls", "buildings", "wall_pieces",
             "prod_bld", "prod_idle", "units_lost", "units_killed", "value_killed", "value_lost", "bld_lost", "soil_mean",
             "soil_min", "lode_mean", "attacking", "blocked_s", "bank500_s", "bank1000_s", "idle_w_s", "worker_s",
             "hopeless", "strategy"]
BUILD_KEYS = ["barracks", "powder_mill", "horse_breeder", "armoury", "foundry", "church", "farm", "cottage", "gate",
              "warren", "brood_pen", "gorge_pit", "roost", "feeding_pit", "clutch_mound",
              "assembly_works", "engine_hall", "capacitor_works", "ore_crusher", "boiler", "spring_tower", "charging_pylon"]
EVENT_PATTERNS = [
    ("scouted", re.compile(r"scouted:|could not see the enemy")),
    ("wall", re.compile(r"walled its ramp|ramp wall stands|Cottage wall plan")),
    ("expand", re.compile(r"is expanding to fresh|\(expansion\)")),
    ("attack", re.compile(r"first attack goes out")),
    ("rush", re.compile(r"rush|failed: it builds up|saw Horsemen")),
    ("dropped_site", re.compile(r"dropped a .*nobody was coming|couldn't start a")),
    ("lost_building", re.compile(r" lost a ")),
    ("soil", re.compile(r"is spent|is running low")),
    ("capital", re.compile(r"capital fell")),
    ("out", re.compile(r" is out$")),
    ("hopeless", re.compile(r"hopeless")),
    ("drop", re.compile(r"balloon")),
    ("refit", re.compile(r"refit")),
    ("pulled_down", re.compile(r"pulled down")),
]


def flat_team(g, t):
    d = {"id": g["id"], "team": t["team"], "role": "A" if t["team"] == g["a_team"] else "B",
         "faction": t["faction"], "opp": g["teams"][1 - t["team"]]["faction"], "map": g["map"], "swap": int(g["swap"]),
         "won": 1 if g["winner_team"] == t["team"] else (0 if g["winner_team"] >= 0 else -1),
         "end_t": g["end_t"], "cause": g["cause"]}
    for k in ["plan_start", "plan_end", "crown_opening", "failed_waves", "scout_verdict", "earned", "spent", "trained", "built",
              "killed", "lost", "razed", "bld_lost", "value_killed", "peak_army", "res2_in", "sacrificed", "end_army", "end_workers",
              "end_buildings", "end_gold", "end_res2", "end_halls", "end_power", "blocked_s", "capped_s", "bank500_s",
              "bank1000_s", "idle_w_s", "worker_s", "army_idle_s", "army_s", "prod_idle_s", "prod_s", "peak_supply",
              "peak_workers", "peak_gold", "first_blood_t", "first_attack_t", "first_worker_lost_t", "hope_first", "hope_flips",
              "gg_t", "min_workers_after_3", "soil_zero_t", "wall_start_t", "wall_done_t", "workers_lost", "cap200_t"]:
        d[k] = t.get(k, "")
    d["value_lost"] = g["teams"][1 - t["team"]]["value_killed"]
    fb = t["first_built"]
    for k in BUILD_KEYS:
        d["t_" + k] = fb.get(k, "")
    hs = t["halls"]
    d["hall_n"] = len(hs)
    d["hall2_t"] = hs[1] if len(hs) > 1 else ""
    d["hall3_t"] = hs[2] if len(hs) > 2 else ""
    d["n_waves"] = len(t["waves"])
    d["plan_changes"] = json.dumps(t["plan_changes"])
    d["kills_by"] = json.dumps(t["kills_by"])
    d["produced"] = json.dumps(t["produced"])
    d["produced_value"] = json.dumps(t["produced_value"])
    d["lost_by_kind"] = json.dumps(t["lost_kind"])
    d["lost_value_by_kind"] = json.dumps(t.get("lost_value", {}))
    d["loss_tracking"] = 2 if g.get("loss_tracking") == 2 else 0
    d["first_built"] = json.dumps(fb)
    d["hall_times"] = json.dumps(hs)
    return d


def write(path, rows, header=None):
    if not rows and header is None:
        return
    if header is None:
        header = []
        for r in rows:
            for k in r:
                if k not in header:
                    header.append(k)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=header, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", default="/home/claude/study_runs")
    ap.add_argument("--out", default="docs/study_data")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    games, sides, waves, events, ts = [], [], [], [], []
    for p in sorted(glob.glob(a.runs + "/games/*.json")):
        g = json.load(open(p))
        gid = g["id"]
        games.append({"id": gid, "pair": "%s-%s" % (g["a"], g["b"]), "a": g["a"], "b": g["b"], "plan_a": g["plan_a"], "plan_b": g["plan_b"],
                      "map": g["map"], "seed": g["seed"], "swap": int(g["swap"]), "winner_team": g["winner_team"],
                      "winner_faction": g["winner_faction"], "a_won": g["a_won"], "end_t": g["end_t"], "cause": g["cause"],
                      "wall_s": g["wall_s"], "version": g["version"]})
        for t in g["teams"]:
            sides.append(flat_team(g, t))
            for w in t["waves"]:
                d = {"id": gid, "team": t["team"], "faction": t["faction"], "opp": g["teams"][1 - t["team"]]["faction"], "map": g["map"]}
                d.update({k: w.get(k, "") for k in ["t0", "t1", "kind", "supply", "value", "killed_value", "lost_value", "kills", "losses", "army_end", "plan", "rush_state", "open"]})
                d["comp"] = json.dumps(w.get("comp", {}))
                waves.append(d)
        tp = "%s/ts/%s.csv" % (a.runs, gid)
        if os.path.exists(tp):
            with open(tp) as f:
                for row in csv.reader(f):
                    if len(row) == len(TS_HEADER):
                        ts.append(row)
        lp = "%s/logs/%s.log" % (a.runs, gid)
        if os.path.exists(lp):
            for line in open(lp, errors="ignore"):
                m = re.match(r"\[(\d\d):(\d\d)\] (.*)", line.rstrip("\n"))
                if not m:
                    continue
                tsec = int(m.group(1)) * 60 + int(m.group(2))
                txt = m.group(3)
                for kind, pat in EVENT_PATTERNS:
                    if pat.search(txt):
                        who = re.match(r"(P\d) ", txt)
                        events.append({"id": gid, "t": tsec, "kind": kind, "who": who.group(1) if who else "", "text": txt})
                        break
    write(a.out + "/games.csv", games)
    write(a.out + "/sides.csv", sides)
    write(a.out + "/waves.csv", waves)
    write(a.out + "/events.csv", events)
    with open(a.out + "/timeseries.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(TS_HEADER)
        w.writerows(ts)
    print("games %d, sides %d, waves %d, events %d, ts rows %d" % (len(games), len(sides), len(waves), len(events), len(ts)))


if __name__ == "__main__":
    main()
