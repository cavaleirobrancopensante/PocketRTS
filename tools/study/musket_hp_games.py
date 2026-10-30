#!/usr/bin/env python3
"""The Musketeer health test's games (docs/musket_hp_test.md), from tools/study_musket_hp_games.sh's logs:
    python3 tools/study/musket_hp_games.py <logdir>...
RESULT lines (tools/study_musket_hp_match.gd): per game, the army values at 3/5/7/10 min, the value each side lost, the
Crown's Musketeers / Guardsmen alive, the winner. OUTCOME lines (tools/study_musket_hp_rush.gd): the walled Crown
against the Extreme rush."""
import glob
import json
import os
import sys


def rows(dirs, tag):
    out = []
    for d in dirs:
        for f in sorted(glob.glob(os.path.join(d, "*.log"))):
            for ln in open(f, errors="replace"):
                if ln.startswith(tag + " "):
                    r = json.loads(ln[len(tag) + 1:])
                    r["_id"] = os.path.basename(f)[:-4]
                    out.append(r)
    return out


def g(dct, k):
    return dct.get(str(k), "-")


def main():
    dirs = sys.argv[1:]
    res = rows(dirs, "RESULT")
    if res:
        print("| Game | Health | Crown army 3/5/7/10 min | Foe army 3/5/7/10 min | Crown lost | Foe lost | Musk+Guards at 10 | Winner |")
        print("|---|---|---|---|---|---|---|---|")
        for r in sorted(res, key=lambda r: (r["foe"], r.get("foeplan", ""), r["map"], r["seed"], r["hpv"] != "now")):
            mins = [3, 5, 7, 10]
            last = str(max(int(k) for k in r["army"])) if r["army"] else "0"
            win = {-1: "none (time)", 0: "Crown", 1: r["foe"]}.get(r["winner"], str(r["winner"]))
            label = f"{r['foe']}{' ' + r['foeplan'] if r.get('foeplan', 'balanced') != 'balanced' else ''}, {r['map']} s{r['seed']}"
            print(f"| {label} | {r['hpv']} | " + " / ".join(str(g(r['army'], m)) for m in mins) + " | "
                  + " / ".join(str(g(r['foe_army'], m)) for m in mins) + f" | {r['lost_total'][0]} | {r['lost_total'][1]} | "
                  + f"{g(r['musk_alive'], last)}+{g(r['guards_alive'], last)} | {win} ({r['end']} s) |")
    out = rows(dirs, "OUTCOME")
    if out:
        print()
        print("| Map, seed | Health | Musketeers made / lost | Labourers lost | Brood fighters made / killed | at 2:30: Musk alive, Brood alive, wall damage | Crown buildings lost |")
        print("|---|---|---|---|---|---|---|")
        for r in sorted(out, key=lambda r: (r["map"], r["seed"], r["hpv"] != "now")):
            s = r["snap"].get("150", {})
            print(f"| {r['map']} {r['seed']} | {r['hpv']} | {r['musk_made']} / {r['musk_lost']} | {r['lab_lost']} | {r['brood_made']} / {r['brood_killed']} | "
                  f"{s.get('musk_alive', '-')}, {s.get('brood_alive', '-')}, {s.get('wall_dmg', '-')} | {r['crown_bld_lost']} |")


main()
