#!/usr/bin/env python3
"""Concrete examples of AI faults (game id + game time) found in the aggregated CSVs.
Merges the markdown bullet lists into tables.json under ex_* keys.

  python3 tools/study/examples.py --data docs/study_data --out docs/study_data/tables.json
"""
import argparse, json, os
import numpy as np
import pandas as pd


def mmss(s):
    s = int(round(float(s)))
    return "%d:%02d" % (s // 60, s % 60)


def bullets(rows, n=6):
    return "\n".join("- " + r for r in rows[:n]) if rows else "_none seen in this sample_"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="docs/study_data")
    ap.add_argument("--out", default="docs/study_data/tables.json")
    a = ap.parse_args()
    ld = lambda n: pd.read_csv(os.path.join(a.data, n if os.path.exists(os.path.join(a.data, n)) else n + ".gz"))
    games, sides, ts, waves = ld("games.csv"), ld("sides.csv"), ld("timeseries.csv"), ld("waves.csv")
    T = json.load(open(a.out)) if os.path.exists(a.out) else {}
    ts = ts.sort_values(["id", "team", "t"])
    gi = games.set_index("id")
    for c in ["gg_t", "hope_first", "soil_zero_t"]:
        sides[c] = pd.to_numeric(sides[c], errors="coerce").where(lambda x: x >= 0)

    # idle workers: the worst samples
    d = ts[(ts.workers >= 10) & (ts.t >= 120)].copy()
    d["f"] = d.idle_workers / d.workers
    top = d.sort_values(["f", "idle_workers"], ascending=False)
    rows, seen = [], set()
    for r in top.itertuples():
        if (r.id, r.team) in seen:
            continue
        seen.add((r.id, r.team))
        rows.append("`%s` at %s: %s side had %d of %d workers idle (bank %d)" % (r.id, mmss(r.t), r.faction, r.idle_workers, r.workers, r.gold))
    T["ex_idle"] = bullets(rows)
    # side-games with the largest share of worker time idle
    s = sides.copy()
    s["idle_pct"] = 100 * s.idle_w_s / s.worker_s.clip(lower=1)
    rows = ["`%s` %s side: %.0f%% of worker-time idle over %s" % (r.id, r.faction, r.idle_pct, mmss(r.end_t)) for r in s.sort_values("idle_pct", ascending=False).head(6).itertuples()]
    T["ex_idle_total"] = bullets(rows)

    # supply blocks
    rows = []
    s = sides.sort_values("blocked_s", ascending=False)
    for r in s.head(8).itertuples():
        x = ts[(ts.id == r.id) & (ts.team == r.team)].copy()
        x["db"] = x.blocked_s.diff().fillna(x.blocked_s)
        w = x[x.db >= 15]
        first = mmss(w.t.iloc[0]) if len(w) else "-"
        rows.append("`%s` %s side: %d s supply-blocked with 100+ gold in hand (first long block at %s; supply %s)" % (
            r.id, r.faction, r.blocked_s, first, "%d/%d" % (int(w.supply.iloc[0]), int(w.cap.iloc[0])) if len(w) else "-"))
    T["ex_block"] = bullets(rows)

    # banked gold
    rows = []
    s = sides.sort_values("bank1000_s", ascending=False)
    for r in s.head(8).itertuples():
        if r.bank1000_s <= 0:
            break
        x = ts[(ts.id == r.id) & (ts.team == r.team)]
        pk = x.loc[x.gold.idxmax()]
        first = x[x.gold > 1000]
        rows.append("`%s` %s side: %d s with more than 1000 banked (first at %s; peak %d at %s, supply %d/%d)" % (
            r.id, r.faction, r.bank1000_s, mmss(first.t.iloc[0]) if len(first) else "-", pk.gold, mmss(pk.t), pk.supply, pk.cap))
    T["ex_bank"] = bullets(rows)

    # trickling waves: small waves that lost more than they killed, after 4:00
    rows = []
    if not waves.empty:
        w = waves[(waves.kind == "wave") & (waves.supply < 10) & (waves.t0 > 240) & (waves.lost_value > waves.killed_value)]
        for r in w.sort_values("lost_value", ascending=False).head(6).itertuples():
            rows.append("`%s` %s wave at %s-%s: %d supply (value %d) lost %d and killed %d" % (r.id, r.faction, mmss(r.t0), mmss(r.t1), r.supply, r.value, r.lost_value, r.killed_value))
    T["ex_trickle"] = bullets(rows)

    # no expansion by 12:00 while the game goes on
    rows = []
    x = ts[(ts.t == 720) & (ts.halls == 1)]
    for r in x.itertuples():
        if gi.loc[r.id].end_t > 780:
            rows.append("`%s` %s side: still one hall at 12:00 (bank %d, supply %d/%d, soil %.0f%%)" % (r.id, r.faction, r.gold, r.supply, r.cap, 100 * max(r.soil_mean, 0)))
    T["ex_noexpand"] = bullets(rows, 8)
    T["ex_noexpand_n"] = str(len(rows))

    # no gg when hopeless
    rows = []
    s = sides[(sides.won == 0) & sides.gg_t.notna() & (sides.cause == "victory")].copy()
    s["gap"] = s.end_t - s.gg_t
    for r in s.sort_values("gap", ascending=False).head(6).itertuples():
        rows.append("`%s` %s side: hopeless by the AI's own rule from %s, but the game went on until %s (%d s)" % (r.id, r.faction, mmss(r.gg_t), mmss(r.end_t), r.gap))
    T["ex_gg"] = bullets(rows)

    # lost workers: down to 2 or fewer after 4:00
    rows = []
    x = ts[(ts.t >= 240) & (ts.workers <= 2)].groupby(["id", "team"]).first().reset_index()
    for r in x.head(8).itertuples():
        pk = ts[(ts.id == r.id) & (ts.team == r.team)].workers.max()
        rows.append("`%s` %s side: %d workers left at %s (peak %d, bank %d, army value %d)" % (r.id, r.faction, r.workers, mmss(r.t), pk, r.gold, r.army_value))
    T["ex_workers"] = bullets(rows)

    # an army that stands still while the AI is attacking
    rows = []
    x = ts[(ts.attacking == 1) & (ts.army_units >= 12) & (ts.army_idle / ts.army_units.clip(lower=1) >= 0.6)]
    seen = set()
    for r in x.itertuples():
        if (r.id, r.team) in seen:
            continue
        seen.add((r.id, r.team))
        rows.append("`%s` %s side at %s: wave out but %d of %d army units idle" % (r.id, r.faction, mmss(r.t), r.army_idle, r.army_units))
    T["ex_idle_army"] = bullets(rows)
    json.dump(T, open(a.out, "w"), indent=1)


if __name__ == "__main__":
    main()
