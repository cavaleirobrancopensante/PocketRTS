#!/usr/bin/env python3
"""Tables for docs/armoury_study.md and docs/marching_band.md from tools/study_armoury_band.sh's fights.
   python3 tools/study_armoury_band_report.py <dir with *.jsonl>
Each row: the config's mean over its seeds against each enemy: who won (crown wins / fights), the Crown's and the enemy's
losses (resources), what is left of each side (resources weighted by health), the MARGIN (Crown left minus enemy left:
above 0 the Crown is ahead), and how long it took. The margin's change against the config's baseline is the upgrade's worth
in one fight, in resources. A band's own value left (its price by its health) is NOT in the margin (the soldiers' result
only); it is given apart ("kept")."""
import glob
import json
import os
import sys
from collections import defaultdict

BASE = {"AR_same": "AR_same_none", "AR_eq": "AR_eq_none", "AG": "AG_guns", "AC": "AC_horse", "MB_cap": "MB_cap_none",
        "MB_eq": "MB_eq_none", "MB": "MB_none", "MD": "MD_none"}


def base_of(name):
    for pre in sorted(BASE, key=len, reverse=True):
        if name.startswith(pre + "_") or name == BASE[pre]:
            return BASE[pre]
    return None


def main(d):
    rows = defaultdict(list)
    for p in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
        for line in open(p):
            line = line.strip()
            if line:
                r = json.loads(line)
                rows[(r["name"], r["enemy"])].append(r)
    mean = {}
    for k, rs in rows.items():
        n = len(rs)
        m = {
            "n": n,
            "win": sum(1 for r in rs if r["winner"] == "crown"),
            "crown_cost": sum(r["crown_cost"] for r in rs) / n,
            "crown_lost": sum(r["crown_lost"] for r in rs) / n,
            "foe_lost": sum(r["foe_lost"] for r in rs) / n,
            "crown_left": sum(r["crown_left_hp"] for r in rs) / n,
            "foe_left": sum(r["foe_left_hp"] for r in rs) / n,
            "time": sum(r["time"] for r in rs) / n,
            "musk": rs[0]["musk"],
            "band_died": sum(1 for r in rs if r.get("band_died", -1) >= 0),
            "band": bool(rs[0].get("band")),
        }
        # (the band's own value left is not the soldiers' result: the margin counts the soldiers only; "band left" apart)
        m["band_left"] = sum(r.get("band_left", 0.0) for r in rs) / n
        m["margin"] = m["crown_left"] - m["band_left"] - m["foe_left"]
        ms = [r["crown_left_hp"] - r.get("band_left", 0.0) - r["foe_left_hp"] for r in rs]
        m["sd"] = (sum((x - m["margin"]) ** 2 for x in ms) / max(n - 1, 1)) ** 0.5
        mean[k] = m
    enemies = ["raptor", "clock", "musk"]
    groups = defaultdict(list)
    for (name, e) in mean:
        groups[name.split("_")[0]].append(name)
    for gname in ["AR", "AG", "AC", "MB", "MD"]:
        names = sorted(set(groups.get(gname, [])), key=lambda s: (base_of(s) or "", s != base_of(s), s))
        if not names:
            continue
        print("\n### %s\n" % gname)
        print("| config | men | " + " | ".join("vs %s: won · lost/killed · margin ±sd (Δ)" % e for e in enemies) + " |")
        print("|---|---|" + "---|" * len(enemies))
        for nm in names:
            cells = []
            men = ""
            for e in enemies:
                m = mean.get((nm, e))
                if not m:
                    cells.append("-")
                    continue
                men = str(m["musk"])
                b = base_of(nm)
                delta = ""
                if b and b != nm and (b, e) in mean:
                    delta = " (%+d)" % round(m["margin"] - mean[(b, e)]["margin"])
                bd = (" · band died %d/%d, kept %d" % (m["band_died"], m["n"], round(m["band_left"]))) if m["band"] else ""
                cells.append("%d/%d · %d/%d · %+d ±%d%s%s" % (m["win"], m["n"], round(m["crown_lost"]), round(m["foe_lost"]), round(m["margin"]), round(m["sd"]), delta, bd))
            print("| %s | %s | %s |" % (nm, men, " | ".join(cells)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
