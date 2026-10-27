#!/usr/bin/env python3
"""Summarise the diagnostic games of tools/study/diag_army.gd: when an army sits at its supply cap with a bank and no wave
out, which gate in AI._army() holds it (an enemy near one of its buildings, the next-wave threshold, a regroup, or none of
these). Writes a JSON the report reads (report.py --diag):

  python3 tools/study/diag_summary.py --dir docs/study_data/diag --out docs/study_data/diag/diag.json

Measurement only.
"""
import argparse, glob, json, os, re
import pandas as pd


def mmss(s):
    s = int(round(float(s)))
    return "%d:%02d" % (s // 60, s % 60)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="docs/study_data/diag")
    ap.add_argument("--out", default="docs/study_data/diag/diag.json")
    a = ap.parse_args()
    rows, notes = [], []
    for p in sorted(glob.glob(os.path.join(a.dir, "*.csv"))):
        gid = os.path.basename(p)[:-4]
        d = pd.read_csv(p)
        if d.empty or d.t.max() < 600:
            continue
        log = os.path.join(a.dir, gid + ".log")
        result = ""
        if os.path.exists(log):
            m = re.search(r"RESULT at (\d+:\d+): winner (P\d \w+)", open(log, errors="ignore").read())
            result = ("%s won at %s" % (m.group(2), m.group(1))) if m else ""
        end = d.t.max()
        for team, x in d.groupby("team"):
            x = x.sort_values("t")
            fac = x.faction.iloc[0]
            cap = x[(x.t >= 480) & ((x.supply >= x.cap - 2) | (x.supply >= 199)) & (x.gold >= 1000) & (x.attacking == 0)]
            if len(cap) < 12:          # under a minute capped and idle: nothing to explain
                continue
            n = len(cap)
            thr = cap.threat == 1
            armed = thr & (cap.threat_armed == 1)
            below = ~thr & (cap.army_sup < cap.attack_at)
            regroup = ~thr & ~below & (cap.regroup > 0) & (cap.army_sup < 60)
            other = ~thr & ~below & ~regroup
            kinds = cap[thr].threat_kind.value_counts()
            blds = cap[thr].threat_bld.value_counts()
            rows.append({"game": gid, "side": "%s (team %d)" % (fac, team), "result": result or ("ran to %s" % mmss(end)),
                         "capped and idle": "%.1f min from %s" % (n * 5 / 60.0, mmss(cap.t.min())),
                         "enemy near a building": "%d%%" % round(100 * thr.mean()),
                         "of which armed": "%d%%" % round(100 * armed.sum() / max(1, thr.sum())),
                         "nearest enemy kinds": ", ".join("%s %d" % (k, v) for k, v in kinds.head(3).items()) or "-",
                         "next to": ", ".join("%s %d" % (k, v) for k, v in blds.head(2).items()) or "-",
                         "below the wave threshold": "%d%%" % round(100 * below.mean()),
                         "regrouping": "%d%%" % round(100 * regroup.mean()), "none of these": "%d%%" % round(100 * other.mean()),
                         "threshold / army supply (median)": "%d / %d" % (cap.attack_at.median(), cap.army_sup.median())})
        notes.append(gid)
    out = {"diag_games": notes}
    if rows:
        df = pd.DataFrame(rows)
        from tabulate import tabulate
        out["diag_table"] = tabulate(df, headers="keys", tablefmt="pipe", showindex=False)
        out["diag_status"] = "measured in %d diagnostic side-games (section 10.1)" % len(rows)
        out["diag_text"] = ("Diagnostic games with `tools/study/diag_army.gd` (Crown against Clockwork, the AI's gates logged every 5 s): "
                            "%d run, %d side(s) stalled at the cap with 1,000+ banked for a minute or more. What held each stalled army "
                            "(share of its stalled 5 s samples):" % (len(notes), len(rows)))
    else:
        out["diag_table"] = ""
        out["diag_status"] = "not settled: %d diagnostic game(s) run, none stalled at the cap" % len(notes)
        out["diag_text"] = ("%d diagnostic game(s) with `tools/study/diag_army.gd` (same settings as stalled games, logging every 5 s which "
                            "gate holds the army) did not stall at the cap, so which gate locks is not measured yet." % len(notes)) if notes else ""
    json.dump(out, open(a.out, "w"), indent=1)
    print("diag: %d games, %d stalled sides" % (len(notes), len(rows)))


if __name__ == "__main__":
    main()
