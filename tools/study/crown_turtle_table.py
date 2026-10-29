#!/usr/bin/env python3
"""Tables for the Crown turtle study (tools/study_crown_turtle.gd, docs/crown_turtle_study.md).

    python3 -I tools/study/crown_turtle_table.py docs/crown_turtle/v0.16.1/*.jsonl

One row a config, averaged over its seeds. Values are at face value (powder, essence and Tension worth 1 gold).
"held": the attack was spent (or wiped out) and the Crown army stands; "broken": the Crown's fighting army is gone;
"time out": both still fighting at 300 s. The gate time is the average over the fights where the gate fell.
"""
import json
import sys
from collections import OrderedDict


SUPPORT = {"ballista", "netter", "great_winder", "winder", "mist_toad"}


def load(paths):
    rows = OrderedDict()
    for p in paths:
        for line in open(p):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            # (an early version ran on to 300 s while only a Ballista or a Netter, out of reach, was left: the assault was spent)
            if r["result"] == "timeout" and not r["name"].endswith("bsiege") and set(r["foe_alive"]) <= SUPPORT \
                    and any(v for k, v in r["crown_alive"].items() if k in ("musketeer", "cannon", "mortar")):
                r["result"] = "held"
            rows.setdefault(r["name"], []).append(r)
    return rows


def avg(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else 0.0


def fmt_t(x):
    return "%d:%02d" % (int(x) // 60, int(x) % 60)


def main():
    rows = load(sys.argv[1:])
    print("| fight | seeds | held | broken | time out | gate fell (avg time) | first inside | fight time | Crown lost | attacker lost | trade | wall lost | repair gold |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for name, rs in rows.items():
        n = len(rs)
        held = sum(1 for r in rs if r["result"] == "held")
        brk = sum(1 for r in rs if r["result"] == "broken")
        to = n - held - brk
        gates = [r["t_gate_down"] for r in rs if r["t_gate_down"] >= 0]
        ins = [r["t_inside"] for r in rs if r["t_inside"] >= 0]
        cl = [r["crown_lost"][0] + r["crown_lost"][1] + r["wall_lost"] for r in rs]
        fl = [r["foe_lost"][0] + r["foe_lost"][1] for r in rs]
        trade = avg(fl) / max(1.0, avg(cl))
        print("| %s | %d | %d | %d | %d | %s | %s | %s | %d | %d | %.1f | %d | %d |" % (
            name, n, held, brk, to,
            ("%d of %d (%s)" % (len(gates), n, fmt_t(avg(gates)))) if gates else "0",
            ("%d (%s)" % (len(ins), fmt_t(avg(ins)))) if ins else "0",
            fmt_t(avg(r["time"] for r in rs)), avg(cl), avg(fl), trade, avg(r["wall_lost"] for r in rs),
            avg(r["repair_gold"] for r in rs)))
    print()
    print("Tongues (totals over the seeds): marks on a gun; guns pulled; guns staggered; men pulled; Toads killed in the windup; windups broken (stunned or moved); guns killed after the pull; fogs laid (average); escort focus orders on a rider (total)")
    print()
    print("| fight | gun marked | gun pulled | gun staggered | men pulled | Toad killed in windup | windup broken | pulled guns killed | charge stuns in windup | fogs a fight | Spitter focus on riders | Crown dead (avg by kind) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for name, rs in rows.items():
        if rs[0]["att"] == "CW":
            continue
        n = len(rs)
        gm = gp = gs = mp = 0
        for r in rs:
            for e in r.get("tongues", []):
                gun = e["victim"] in ("cannon", "mortar")
                if gun:
                    gm += 1
                if e["result"] == "pulled":
                    if gun:
                        gp += 1
                    else:
                        mp += 1
                elif e["result"] == "staggered" and gun:
                    gs += 1
        tk = sum(r["toad_killed_windup"] for r in rs)
        br = sum(r["broken"] for r in rs)
        pk = sum(r["pulled_guns_killed"] for r in rs)
        fogs = avg(r.get("fogs_laid", 0) for r in rs)
        esc = sum(r.get("escort_focus", 0) for r in rs)
        dead = {}
        for r in rs:
            for k, v in r["crown_dead"].items():
                dead[k] = dead.get(k, 0) + v
        ds = ", ".join("%s %.1f" % (k, v / n) for k, v in sorted(dead.items()))
        cs = sum(r.get("charge_stuns", 0) for r in rs)
        print("| %s | %d | %d | %d | %d | %d | %d | %d | %d | %.1f | %d | %s |" % (name, gm, gp, gs, mp, tk, br, pk, cs, fogs, esc, ds))
    print()
    print("| fight | attacker army | Crown turtle |")
    print("|---|---|---|")
    for name, rs in rows.items():
        r = rs[0]
        comp = ", ".join("%d %s" % (v, k) for k, v in r["foe_comp"].items())
        print("| %s | %s = %d + %d | %d + %d, wall %d |" % (name, comp, r["foe_cost"][0], r["foe_cost"][1], r["turtle_cost"][0], r["turtle_cost"][1], r["wall_cost"]))


if __name__ == "__main__":
    main()
