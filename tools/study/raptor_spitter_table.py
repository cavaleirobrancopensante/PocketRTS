#!/usr/bin/env python3
"""Tables for the Raptor + Spitter study and the Toad and health study (tools/study_raptor_spitter.gd,
docs/raptor_spitter_study.md, docs/toad_hp_study.md).

    python3 tools/study/raptor_spitter_table.py docs/raptor_spitter/*.jsonl
    python3 tools/study/raptor_spitter_table.py docs/toad_hp/*.jsonl

Averages each config over its seeds. Values: K is what one unit of the second resource (Crown powder, Brood essence)
is worth in the first (gold, biomass): 1 (face value), 3, and 9.5 (the Crown's full-base income ratio, ~1,140 gold
to ~120 powder a minute, Defs). Trade = enemy value lost / Crown value lost (above 1: the Crown trades better).
The enemy is the Brood, or (group X) Clock Soldiers: 70 cogs each, no Tension, so K does not touch their side.
Toad rows (group T) get a column of what the tongues did; the break-even scan (group HS) gets a pivot table.
"""
import json
import re
import sys
from collections import OrderedDict

KS = [1.0, 3.0, 9.5]


def val(pair, k):
    return pair[0] + k * pair[1]


def tongue_note(rs):
    n = len(rs)
    fogs = sum(len(r["toad"]["fogs"]) for r in rs) / n
    res = {}
    gun_pulled = 0
    after = []
    gun_dead_after = 0
    for r in rs:
        for e in r["toad"]["tongues"]:
            key = "%s %s" % (e["victim"], e["result"] or "unfinished")
            res[key] = res.get(key, 0) + 1
            if e["victim"] == "cannon" and e["result"] == "pulled":
                gun_pulled += 1
                if "gun_shots_after" in e:
                    after.append(e["gun_shots_after"])
                if e.get("gun_dead_t", -1) >= 0:
                    gun_dead_after += 1
    toads_dead = sum(sum(1 for t in r["toad"]["toad_dead_t"] if t >= 0) for r in rs) / n
    parts = ["fogs %.1f" % fogs]
    parts += ["%s %d" % (k, v) for k, v in sorted(res.items())]
    if gun_pulled:
        parts.append("pulled guns killed %d of %d" % (gun_dead_after, gun_pulled))
        if after:
            parts.append("shots after pull %.1f" % (sum(after) / len(after)))
    parts.append("toads lost %.1f" % toads_dead)
    return "; ".join(parts)


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
    print("| fight | Crown army | enemy army | supply C/E | Crown wins | time s | Crown lost (gold/powder) | enemy lost "
          "| Crown left | enemy left | trade K=1 | K=3 | K=9.5 | notes |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
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
        hp = r0.get("hp", 70)
        army_c = "%d musk%s (%s kit%s) = %d+%d" % (r0["musk"], guns, r0["kit"], ", %d hp" % hp if hp != 70 or name.startswith("H") or name.startswith("X") else "", ccost[0], ccost[1])
        if r0.get("clock"):
            army_b = "%d Clock Soldiers%s = %d cogs" % (r0["clock"], " (shield wall)" if r0.get("shield") else "", bcost[0])
        else:
            army_b = "%dR + %dS%s = %d+%g" % (r0["raptors"], r0["spitters"],
                " + %d toad%s (%s energy%s)" % (r0["toads"], "s" if r0["toads"] > 1 else "", r0["toad_e"],
                    ", " + r0["toad_plan"] if r0.get("toad_plan") else "") if r0.get("toads") else "", bcost[0], bcost[1])
        left_c = sum(r["crown_left_hp"] for r in rs) / n
        left_b = sum(r["brood_left_hp"] for r in rs) / n
        t = sum(r["time"] for r in rs) / n
        extra = ""
        if "wall_broken" in r0:
            extra = "wall pieces lost %.1f" % (sum(r["wall_broken"] for r in rs) / n)
        if r0.get("toads"):
            extra = tongue_note(rs)
        print("| %s%s | %s | %s | %d/%d | %d of %d%s | %.0f | %.0f/%.0f | %.0f/%.1f | %.0f | %.0f | %s | %s | %s | %s |" % (
            name, " (form %s, gap %g)" % (r0["form"], r0["sp"]) if r0["form"] != "front" or (r0["sp"] != 18 and not r0.get("clock")) else "",
            army_c, army_b, r0["supply_crown"], r0["supply_brood"], cw, n, "" if bw + cw == n else " (%d draw)" % (n - bw - cw),
            t, cl[0], cl[1], bl[0], bl[1], left_c, left_b, trades[0], trades[1], trades[2], extra))
    print()
    print("Army price under each K (Crown / enemy):")
    for name, rs in rows.items():
        r0 = rs[0]
        print("  %-26s " % name + "  ".join("K=%g: %d / %d" % (k, val(r0["crown_cost"], k), val(r0["brood_cost"], k)) for k in KS))
    # the break-even scan with health (group HS): Crown wins by mix, health and Musketeer count
    scan = OrderedDict()
    counts = set()
    for name, rs in rows.items():
        m = re.match(r"HS_(\w+?)_m(\d+)_hp(\d+)$", name)
        if not m:
            continue
        mix, nm, hp = m.group(1), int(m.group(2)), int(m.group(3))
        counts.add(nm)
        scan.setdefault((mix, hp), {})[nm] = (sum(1 for r in rs if r["winner"] == "crown"), len(rs))
    if scan:
        cs = sorted(counts)
        print()
        print("Break-even scan (Crown wins of seeds):")
        print("| Brood mix | health | " + " | ".join("%d musk" % c for c in cs) + " |")
        print("|---|---|" + "---|" * len(cs))
        mixname = {"991": "48 Raptors", "31": "36 Raptors, 6 Spitters", "11": "24 Raptors, 12 Spitters"}
        for (mix, hp), d in sorted(scan.items(), key=lambda kv: (kv[0][0] != "991", kv[0][0], -kv[0][1])):
            print("| %s | %d | " % (mixname.get(mix, mix), hp) + " | ".join(
                "%d of %d" % d[c] if c in d else "-" for c in cs) + " |")


if __name__ == "__main__":
    main(sys.argv[1:])
