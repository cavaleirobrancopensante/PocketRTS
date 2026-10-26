#!/usr/bin/env python3
"""Merge what tools/study/bo_dump.gd read from the game into tools/study/bo_data.json (the calculator's numbers).

  # one Godot process at a time (the box is shared):
  godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- defs out:/tmp/bo/defs.json
  for m in kestrel_rise ashford_crossing ...; do
      godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- map:$m seed:1 out:/tmp/bo/maps/${m}_1.json
  done
  python3 tools/study/bo_data.py --defs /tmp/bo/defs.json --maps /tmp/bo/maps

Keeps only what the calculator reads: units, buildings, research, factions, the economy constants, and per map the
walking distances (pixels; 32 px = one tile) from a side's rally point to the other side's ramp foot and hall, the
hall-to-hall walk and the straight line between the halls (flyers, balloons).
"""
import argparse, glob, json, os, statistics

KEEP_UNIT = ["name", "hp", "armor", "speed", "cost", "cost2", "tension", "time", "supply", "spawn", "sight", "range", "damage",
             "cooldown", "aim", "from", "requires", "faction", "worker", "air", "anti_air", "air_only", "ground_only", "tags",
             "needs_horse", "mounted", "no_attack", "splash", "min_range", "building_bonus", "bonus", "acid", "sabre", "spring",
             "wind_drain", "charge"]
KEEP_BLD = ["name", "hp", "armor", "cost", "time", "size", "supply", "trains", "requires", "faction", "crew", "eggs", "haulers", "field"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--defs", required=True)
    ap.add_argument("--maps", required=True)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "bo_data.json"))
    a = ap.parse_args()
    d = json.load(open(a.defs))
    out = {"version": d["version"], "gear_mode": d["gear_mode"],
           "units": {k: {kk: v[kk] for kk in KEEP_UNIT if kk in v} for k, v in d["UNITS"].items()},
           "buildings": {k: {kk: v[kk] for kk in KEEP_BLD if kk in v} for k, v in d["BUILDINGS"].items()},
           "research": d["RESEARCH"], "factions": d["FACTIONS"], "hall_levels": d["HALL_LEVELS"],
           "gear": {k: d["GEAR"][k] for k in ("press", "mainspring", "swap_cost", "swap_time", "start_cogs", "spent")},
           "owl_morph": d["OWL_MORPH"], "turret": {k: d["TURRET"][k] for k in ("range", "damage", "cooldown")},
           "pistol": d["PISTOL"], "bayonet": d["BAYONET"], "crate": d["CRATE"], "dropship": d["DROPSHIP"],
           "econ": d["econ"], "build_list": d["build_list"], "start_list": d["start_list"], "supply_kind": d["supply_kind"],
           "res_names": d["res_names"], "maps": {}}
    by_map = {}
    for p in sorted(glob.glob(os.path.join(a.maps, "*.json"))):
        m = json.load(open(p))
        by_map.setdefault(m["map"], []).append(m)
    for name, runs in by_map.items():
        r0 = [r["routes"][0] for r in runs]        # (side 0's rally point is in front of its hall; the walk is mirrored)
        def med(key):
            vals = [x[key] for x in r0 if x.get(key) is not None]
            return round(statistics.median(vals)) if vals else None
        out["maps"][name] = {"size": runs[0]["size"], "seeds": [r["seed"] for r in runs],
                             "to_ramp_foot": med("to_ramp_foot"), "to_ramp_top": med("to_ramp_top"), "to_hall": med("to_hall"),
                             "hall_to_hall_walk": med("hall_to_hall_walk"), "air": med("air"), "own_ramp_top": med("own_ramp_top")}
    json.dump(out, open(a.out, "w"), indent=1, sort_keys=True)
    print("wrote", a.out, "maps:", ", ".join(sorted(out["maps"])))


if __name__ == "__main__":
    main()
