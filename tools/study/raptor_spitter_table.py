#!/usr/bin/env python3
"""Tables for the Raptor + Spitter study (tools/study_raptor_spitter.gd, docs/raptor_spitter_study.md).

    python3 tools/study/raptor_spitter_table.py docs/raptor_spitter/*.jsonl

Averages each config over its seeds. Values: K is what one unit of the second resource (Crown powder, Brood essence)
is worth in the first (gold, biomass): 1 (face value), 3, and 9.5 (the Crown's full-base income ratio, ~1,140 gold
to ~120 powder a minute, Defs). Trade = Brood value lost / Crown value lost (above 1: the Crown trades better).
"""
import json
import sys
from collections import OrderedDict

KS = [1.0, 3.0, 9.5]


def val(pair, k):
    return pair[0] + k * pair[1]


def main(paths):
    rows = OrderedDict()
    for p in paths:
        with open(p) as f:
            for line in f:
                line = line.strip()
                if not line.startswith("{"):
                    continue
                r = json.loads(line)
                rows.setdefault(r["name"], []).append(r)
    print("| fight | Crown army | Brood army | supply C/B | Crown wins | time s | Crown lost (gold/powder) | Brood lost (bio/ess) "
          "| Crown left | Brood left | trade K=1 | K=3 | K=9.5 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for name, rs in rows.items():
        n = len(rs)
        r0 = rs[0]
        cw = sum(1 for r in rs if r["winner"] == "crown")
        bw = sum(1 for r in rs if r["winner"] == "brood")
        avg = lambda key, i: sum(r[key][i] for r in rs) / n
        cl = (avg("crown_lost", 0), avg("crown_lost", 1))
        bl = (avg("brood_lost", 0), avg("brood_lost", 1))
        ccost = r0["crown_cost"]
        bcost = r0["brood_cost"]
        trades = []
        for k in KS:
            c = val(cl, k)
            b = val(bl, k)
            trades.append("%.2f" % (b / c) if c > 0 else "inf")
        guns = " + %d %s" % (r0["guns"], r0["gun"]) if r0["guns"] else ""
        army_c = "%d musk%s (%s kit) = %d+%d" % (r0["musk"], guns, r0["kit"], ccost[0], ccost[1])
        army_b = "%dR + %dS = %d+%g" % (r0["raptors"], r0["spitters"], bcost[0], bcost[1])
        left_c = sum(r["crown_left_hp"] for r in rs) / n
        left_b = sum(r["brood_left_hp"] for r in rs) / n
        t = sum(r["time"] for r in rs) / n
        extra = ""
        if "wall_broken" in r0:
            extra = " (wall pieces lost %.1f)" % (sum(r["wall_broken"] for r in rs) / n)
        print("| %s%s | %s | %s | %d/%d | %d of %d%s | %.0f | %.0f/%.0f | %.0f/%.1f | %.0f | %.0f | %s | %s | %s |" % (
            name, " (form %s, gap %g)" % (r0["form"], r0["sp"]) if r0["form"] != "front" or r0["sp"] != 18 else "",
            army_c, army_b, r0["supply_crown"], r0["supply_brood"], cw, n, "" if bw + cw == n else " (%d draw)" % (n - bw - cw),
            t, cl[0], cl[1], bl[0], bl[1], left_c, left_b, trades[0], trades[1], trades[2]) + extra)
    print()
    print("Army price under each K (Crown / Brood):")
    for name, rs in rows.items():
        r0 = rs[0]
        print("  %-20s " % name + "  ".join("K=%g: %d / %d" % (k, val(r0["crown_cost"], k), val(r0["brood_cost"], k)) for k in KS))


if __name__ == "__main__":
    main(sys.argv[1:])
