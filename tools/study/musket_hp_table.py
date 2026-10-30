#!/usr/bin/env python3
"""The Musketeer health test's tables (docs/musket_hp_test.md), from tools/study_musket_hp.sh's JSON lines:
    python3 tools/study/musket_hp_table.py <outdir>
Fights: per config (group, foe, scenario, Musketeer/Guardsman) today's health against the variant side by side: Crown
wins of n, the trade (value the enemy lost / value the Crown lost, the mean of the fights' totals), men lost, the line's
shots before contact, enemy units down before contact, when the first man fell and when half the line was down.
Tongue: per Toad setup, how often the pulled man died, and how fast."""
import glob
import json
import os
import sys
from collections import defaultdict


def load(d):
    rows = []
    for f in sorted(glob.glob(os.path.join(d, "**", "*.jsonl"), recursive=True)):
        for ln in open(f):
            ln = ln.strip()
            if ln.startswith("{"):
                rows.append(json.loads(ln))
    return rows


def mean(xs):
    xs = [x for x in xs if x is not None and x >= 0]
    return sum(xs) / len(xs) if xs else None


def fmt(x, p=1):
    return "-" if x is None else f"{x:.{p}f}"


NAMES = {"raptor": "Raptors", "tyrant_challenger": "Tyrant Challengers", "brute": "Brutes", "spitter": "Spitters",
         "clock_soldier": "Clock Soldiers", "springer": "Springers", "cuirassier": "Horsemen"}


def main():
    rows = list({(r["name"], r["seed"]): r for d in sys.argv[1:] for r in load(d)}.values())     # (a run in two dirs counts once)
    fights = defaultdict(list)
    tongues = defaultdict(list)
    for r in rows:
        if r.get("scen") == "tongue":
            tongues[(r["who"], r["raptors"], r["hp"])].append(r)
        else:
            fights[(r["foe"], r["scen"], r["who"], r["hp"])].append(r)
    keys = sorted({k[:3] for k in fights}, key=lambda k: (list(NAMES).index(k[0]), ["range", "close", "ramp"].index(k[1]), k[2]))
    hps = sorted({k[3] for k in fights}, key=lambda h: (h != "now", h))
    print("| Enemy (n) | Where | Line | " + " | ".join(f"{h}: wins, trade, men lost" for h in hps)
          + " | " + " | ".join(f"{h}: shots / foes down before contact, 1st man down, half down (s)" for h in hps) + " |")
    print("|---" * (3 + 2 * len(hps)) + "|")
    for k in keys:
        cells = []
        cells2 = []
        nf = None
        for h in hps:
            rs = fights.get(k + (h,), [])
            if not rs:
                cells.append("-")
                cells2.append("-")
                continue
            nf = rs[0]["n_foe"]
            w = sum(1 for r in rs if r["winner"] == "crown")
            tr = sum(r["foe_lost"] for r in rs) / max(1.0, sum(r["crown_lost"] for r in rs))
            ml = mean([r["n"] - r["crown_alive"] for r in rs])
            cells.append(f"{w}/{len(rs)}, {tr:.2f}, {ml:.1f}")
            cells2.append(f"{fmt(mean([r['shots_at_contact'] for r in rs]),0)} / {fmt(mean([r['foe_lost_at_contact'] for r in rs]))}, "
                          f"{fmt(mean([r['first_man_t'] for r in rs]))}, {fmt(mean([r['half_line_t'] for r in rs]))}")
        print(f"| {NAMES[k[0]]} ({nf}) | {k[1]} | {'Musketeers' if k[2] == 'M' else 'Guardsmen'} | " + " | ".join(cells) + " | " + " | ".join(cells2) + " |")
    if tongues:
        print()
        print("| Line | Raptors at the Toad | Health | pulled | killed | escaped | survivors' health left (lowest) | death after landing (s) |")
        print("|---|---|---|---|---|---|---|---|")
        for k in sorted(tongues, key=lambda k: (k[0], k[1], k[2] != "now", k[2])):
            rs = tongues[k]
            pulled = [r for r in rs if r["result"] in ("killed", "escaped")]
            kd = [r for r in rs if r["result"] == "killed"]
            es = [r for r in pulled if r["result"] == "escaped"]
            low = min([r.get("min_hp", r.get("hp_left", 0)) for r in es], default=None)
            print(f"| {'Musketeer' if k[0] == 'M' else 'Guardsman'} | {k[1]} | {k[2]} ({int(rs[0]['max_hp'])}) | {len(pulled)}/{len(rs)} | {len(kd)} | "
                  f"{len(es)} | {fmt(mean([r.get('min_hp', r.get('hp_left')) for r in es]),0)} ({fmt(low,0)}) | {fmt(mean([r['death_after_land'] for r in kd]))} |")


main()
