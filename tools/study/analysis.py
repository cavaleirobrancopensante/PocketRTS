#!/usr/bin/env python3
"""Tables and figures for docs/ai_balance_study.md from the aggregated CSVs.

  python3 tools/study/analysis.py --data docs/study_data --out docs/study_data/tables.json

Writes <out> (a JSON map name -> markdown table/text, substituted into the report template by build_report.py)
and PNG figures under <data>/figs/.
"""
import argparse, json, math, os
import numpy as np
import pandas as pd
from tabulate import tabulate

FACS = ["crown", "brood", "clockwork"]
PAIRS = [("crown", "crown"), ("brood", "brood"), ("clockwork", "clockwork"),
         ("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork")]
UNIT_NAME = {"musketeer": "Musketeer", "cuirassier": "Cuirassier/Horseman", "horseman": "Horseman"}


def wilson(k, n, z=1.96):
    if n == 0:
        return (float("nan"), float("nan"))
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))


def pct(x):
    return "n/a" if x is None or (isinstance(x, float) and math.isnan(x)) else "%d%%" % round(100 * x)


def md(df, floatfmt=".1f", index=False):
    if df is None or len(df) == 0:
        return "_(no data yet)_"
    return tabulate(df, headers="keys", tablefmt="pipe", floatfmt=floatfmt, showindex=index)


def mmss(s):
    if s is None or (isinstance(s, float) and math.isnan(s)):
        return "-"
    s = int(round(s))
    return "%d:%02d" % (s // 60, s % 60)


def score_line(wins, draws, n):
    """'W-L-D  rate [CI]' with a draw counted as half a win."""
    k = wins + 0.5 * draws
    lo, hi = wilson(k, n)
    return "%s [%s-%s]" % (pct(k / n if n else float("nan")), pct(lo), pct(hi))


def load(data):
    r = lambda n: pd.read_csv(os.path.join(data, n)) if os.path.exists(os.path.join(data, n)) else pd.DataFrame()
    return r("games.csv"), r("sides.csv"), r("timeseries.csv"), r("waves.csv"), r("events.csv")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="docs/study_data")
    ap.add_argument("--out", default="docs/study_data/tables.json")
    a = ap.parse_args()
    games, sides, ts, waves, events = load(a.data)
    T = {}
    os.makedirs(a.data + "/figs", exist_ok=True)
    if games.empty:
        json.dump({"empty": "no games"}, open(a.out, "w"))
        return
    for c in ["first_blood_t", "first_attack_t", "first_worker_lost_t", "hope_first", "gg_t", "soil_zero_t", "wall_start_t", "wall_done_t", "cap200_t"]:
        sides[c] = pd.to_numeric(sides[c], errors="coerce").where(lambda x: x >= 0)
    for c in ["hall2_t", "hall3_t"] + [c for c in sides.columns if c.startswith("t_")]:
        sides[c] = pd.to_numeric(sides[c], errors="coerce")
    games["draw"] = (games.winner_team < 0).astype(int)
    games["bal"] = ((games.plan_a == "balanced") & (games.plan_b == "balanced"))
    games["len_min"] = games.end_t / 60.0
    sides["won1"] = (sides.won == 1).astype(int)
    sides["draw"] = (sides.won < 0).astype(int)
    sides["bal"] = sides.id.map(games.set_index("id").bal)
    sides["pair"] = sides.id.map(games.set_index("id").pair)
    n_games = len(games)
    T["n_games"] = str(n_games)

    # ------------------------------------------------------------------ sample
    rows = []
    for pa, pb in PAIRS:
        g = games[games.pair == "%s-%s" % (pa, pb)]
        rows.append({"matchup": "%s vs %s" % (pa, pb), "games": len(g), "Balanced/Balanced": int(g.bal.sum()),
                     "with a Rush": int(((g.plan_a.isin(["rush", "xrush"])) | (g.plan_b.isin(["rush", "xrush"]))).sum()),
                     "with a Timing attack": int(((g.plan_a == "timing") | (g.plan_b == "timing")).sum()),
                     "ended by victory": int((g.cause == "victory").sum()), "ended by gg": int((g.cause == "gg").sum()),
                     "reached 30:00": int(g.cause.str.startswith("timeout").sum()),
                     "failed runs": 0, "maps": g["map"].nunique()})
    T["sample"] = md(pd.DataFrame(rows))
    T["maps_used"] = ", ".join("%s (%d)" % (m, c) for m, c in games["map"].value_counts().items())
    T["wall"] = "mean %.0f s, median %.0f s, max %.0f s of real time per game (%.1f game minutes on average)" % (
        games.wall_s.mean(), games.wall_s.median(), games.wall_s.max(), games.len_min.mean())
    T["wall_per_gamemin"] = "%.1f" % (games.wall_s.sum() / max(1e-9, games.len_min.sum()))

    # ------------------------------------------------------------------ win matrix
    def cross_table(sub_sides, label):
        rows = []
        for f in FACS:
            r = {"faction": f}
            for o in FACS:
                s = sub_sides[(sub_sides.faction == f) & (sub_sides.opp == o)]
                if f == o:
                    # a mirror: the share won by the first spawn (team 0) is the only thing that varies
                    r["vs " + o] = "(mirror)"
                    continue
                n = len(s)
                if n == 0:
                    r["vs " + o] = "-"
                    continue
                w = int(s.won1.sum())
                d = int(s.draw.sum())
                r["vs " + o] = "%d-%d-%d  %s" % (w, n - w - d, d, score_line(w, d, n))
            allx = sub_sides[(sub_sides.faction == f) & (sub_sides.opp != f)]
            n = len(allx)
            r["vs both others"] = "%d games  %s" % (n, score_line(int(allx.won1.sum()), int(allx.draw.sum()), n)) if n else "-"
            rows.append(r)
        return md(pd.DataFrame(rows))
    T["winmatrix_all"] = cross_table(sides, "all")
    T["winmatrix_bal"] = cross_table(sides[sides.bal], "bal")

    # per-pair cross list (a vs b)
    rows = []
    for pa, pb in PAIRS[3:]:
        for lab, sub in (("all plans", games[games.pair == "%s-%s" % (pa, pb)]), ("Balanced vs Balanced", games[(games.pair == "%s-%s" % (pa, pb)) & games.bal])):
            n = len(sub)
            w = int((sub.a_won == 1).sum())
            d = int(sub.draw.sum())
            rows.append({"matchup (first vs second)": "%s vs %s" % (pa, pb), "sample": lab, "n": n, "first won": w, "second won": n - w - d, "draws": d,
                         "first faction's score [95% CI]": score_line(w, d, n) if n else "-"})
    T["pairlist"] = md(pd.DataFrame(rows))

    # mirrors: spawn side
    rows = []
    for f in FACS:
        sub = games[games.pair == "%s-%s" % (f, f)]
        n = len(sub)
        w0 = int((sub.winner_team == 0).sum())
        d = int(sub.draw.sum())
        rows.append({"mirror": f, "n": n, "spawn 0 wins": w0, "spawn 1 wins": n - w0 - d, "draws": d, "spawn-0 score [95% CI]": score_line(w0, d, n) if n else "-"})
    T["mirrors"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ sides (spawn) overall
    rows = []
    for lab, sub in (("all games", games), ("cross matchups only", games[games.a != games.b]), ("Balanced/Balanced only", games[games.bal])):
        n = len(sub)
        w0 = int((sub.winner_team == 0).sum())
        d = int(sub.draw.sum())
        rows.append({"sample": lab, "n": n, "spawn 0": w0, "spawn 1": n - w0 - d, "draws": d, "spawn-0 score [95% CI]": score_line(w0, d, n) if n else "-"})
    T["spawn_all"] = md(pd.DataFrame(rows))

    # by map
    rows = []
    for m, g in games.groupby("map"):
        cross = g[g.a != g.b]
        r = {"map": m, "games": len(g), "spawn 0 won": "%d/%d" % ((g.winner_team == 0).sum(), (g.draw == 0).sum()), "avg length": mmss(g.end_t.mean())}
        for f in FACS:
            s = sides[(sides.id.isin(cross.id)) & (sides["map"] == m) & (sides.faction == f)]
            s = s[s.opp != f]
            r[f] = "%d/%d" % (s.won1.sum(), len(s) - s.draw.sum()) if len(s) else "-"
        rows.append(r)
    T["bymap"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ length
    rows = []
    for pa, pb in PAIRS:
        g = games[games.pair == "%s-%s" % (pa, pb)]
        if g.empty:
            continue
        q = g.end_t.quantile([0.1, 0.5, 0.9])
        dec = g[g.cause.isin(["victory", "gg"])]
        rows.append({"matchup": "%s vs %s" % (pa, pb), "n": len(g), "median": mmss(q[0.5]), "10th pct": mmss(q[0.1]), "90th pct": mmss(q[0.9]),
                     "decided (victory or gg)": "%d%%" % round(100 * len(dec) / len(g)), "reached 30:00": int(g.cause.str.startswith("timeout").sum()),
                     "first 8 min": int((g.end_t < 480).sum())})
    T["length"] = md(pd.DataFrame(rows))
    # by winner faction (cross)
    rows = []
    cross = games[(games.a != games.b) & (games.draw == 0)]
    for f in FACS:
        g = cross[cross.winner_faction == f]
        if len(g):
            rows.append({"winner": f, "wins": len(g), "median time to win": mmss(g.end_t.median()), "mean": mmss(g.end_t.mean())})
    T["timetowin"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ economy
    if not ts.empty:
        ts["power"] = ts.army_value + 50 * ts.workers + 30 * ts.buildings
        ts = ts.sort_values(["id", "team", "t"])
        ts["income_min"] = ts.groupby(["id", "team"]).earned.diff().fillna(ts.earned) * 2.0      # per minute (30 s samples)
        ts["res2_min"] = ts.groupby(["id", "team"]).res2_in.diff().fillna(ts.res2_in) * 2.0
        ts["idle_frac"] = ts.idle_workers / ts.workers.clip(lower=1)
        ts["supply_left"] = ts.cap - ts.supply
        # observations are only counted while the game is still on
        rows = []
        for f in FACS:
            for tm in (300, 600, 900, 1200, 1500):
                s = ts[(ts.faction == f) & (ts.t == tm) & (ts.halls > 0)]
                if len(s) < 2:
                    continue
                rows.append({"faction": f, "at": mmss(tm), "n": len(s), "workers": s.workers.mean(), "idle workers": s.idle_workers.mean(),
                             "income/min": s.income_min.mean(), "bank": s.gold.mean(), "2nd res": s.res2.mean(), "supply": s.supply.mean(), "cap": s.cap.mean(),
                             "halls": s.halls.mean(), "army value": s.army_value.mean(), "buildings": s.buildings.mean(),
                             "soil %": 100 * s[s.soil_mean >= 0].soil_mean.mean()})
        T["econ_curves"] = md(pd.DataFrame(rows), floatfmt=".0f")

        # Figures
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt
            cols = {"crown": "#b8860b", "brood": "#2e8b57", "clockwork": "#4682b4"}
            fig, axs = plt.subplots(2, 3, figsize=(13, 7))
            for ax, (col, ttl) in zip(axs.flat, [("income_min", "income per minute"), ("gold", "bank (unspent gold/biomass/ore)"),
                                                  ("workers", "workers"), ("army_value", "army value"), ("halls", "halls"), ("supply", "supply used")]):
                for f in FACS:
                    s = ts[(ts.faction == f) & (ts.halls > 0)]
                    g = s.groupby("t")[col].agg(["mean", "count"])
                    g = g[g["count"] >= 3]
                    if len(g):
                        ax.plot(g.index / 60.0, g["mean"], label=f, color=cols[f])
                ax.set_title(ttl)
                ax.set_xlabel("game minute")
                ax.grid(alpha=0.3)
            axs.flat[0].legend()
            plt.tight_layout()
            plt.savefig(a.data + "/figs/economy.png", dpi=70)
            plt.close()
        except Exception as e:
            print("figure failed", e)

        # supply cap / block / bank / idle per faction (per side-game)
        sd = sides.copy()
        sd["idle_pct"] = 100 * sd.idle_w_s / sd.worker_s.clip(lower=1)
        sd["armyidle_pct"] = 100 * sd.army_idle_s / sd.army_s.clip(lower=1)
        sd["prodidle_pct"] = 100 * sd.prod_idle_s / sd.prod_s.clip(lower=1)
        sd["len_s"] = sd.end_t
        sd["blocked_pct"] = 100 * sd.blocked_s / sd.len_s.clip(lower=1)
        sd["bank500_pct"] = 100 * sd.bank500_s / sd.len_s.clip(lower=1)
        sd["bank1000_pct"] = 100 * sd.bank1000_s / sd.len_s.clip(lower=1)
        rows = []
        for f in FACS:
            s = sd[sd.faction == f]
            if s.empty:
                continue
            rows.append({"faction": f, "side-games": len(s), "idle worker time %": s.idle_pct.mean(), "idle army time %": s.armyidle_pct.mean(),
                         "idle production %": s.prodidle_pct.mean(),
                         "supply-blocked s (median / p90)": "%d / %d" % (s.blocked_s.median(), s.blocked_s.quantile(0.9)),
                         "blocked % of game": s.blocked_pct.mean(),
                         "gold>500 % of game": s.bank500_pct.mean(), "gold>1000 % of game": s.bank1000_pct.mean(),
                         "peak bank (median)": s.peak_gold.median(), "peak supply (median)": s.peak_supply.median(),
                         "reached 200 cap": "%d/%d" % (s.cap200_t.notna().sum(), len(s)),
                         "soil/ground all spent": "%d/%d" % (s.soil_zero_t.notna().sum(), len(s)),
                         "median spent at": mmss(s.soil_zero_t.median()) if s.soil_zero_t.notna().any() else "-"})
        T["faults_econ"] = md(pd.DataFrame(rows), floatfmt=".1f")

        # expansion timing
        rows = []
        for f in FACS:
            s = sd[sd.faction == f]
            if s.empty:
                continue
            rows.append({"faction": f, "side-games": len(s), "2nd hall median": mmss(s.hall2_t.median()) if s.hall2_t.notna().any() else "never",
                         "2nd hall reached": "%d%%" % round(100 * s.hall2_t.notna().mean()),
                         "3rd hall reached": "%d%%" % round(100 * s.hall3_t.notna().mean()),
                         "no 2nd hall by 12:00 (of games lasting 12+ min)": "%d/%d" % (((s.hall2_t.isna()) | (s.hall2_t > 720)).where(s.end_t > 720).sum(), (s.end_t > 720).sum())})
        T["expansion"] = md(pd.DataFrame(rows))

        # tech timings
        rows = []
        for f in FACS:
            s = sd[sd.faction == f]
            if s.empty:
                continue
            cols_t = {"crown": ["t_barracks", "t_powder_mill", "t_horse_breeder", "t_armoury", "t_foundry", "t_church"],
                      "brood": ["t_warren", "t_brood_pen", "t_gorge_pit", "t_roost", "t_clutch_mound"],
                      "clockwork": ["t_assembly_works", "t_engine_hall", "t_capacitor_works", "t_spring_tower", "t_charging_pylon"]}[f]
            r = {"faction": f}
            for c in cols_t:
                v = s[c]
                r[c[2:]] = "%s (%d%%)" % (mmss(v.median()), round(100 * v.notna().mean())) if v.notna().any() else "never"
            rows.append(r)
        T["tech_" + "all"] = "\n\n".join(md(pd.DataFrame([r])) for r in rows)

        # ---------------------------------------------------------- snowball / comebacks
        piv = ts.pivot_table(index=["id", "t"], columns="team", values="power")
        piv = piv.dropna()
        gi = games.set_index("id")

        def snowball(id_ok):
            rows = []
            for tm in (180, 300, 420, 600, 900, 1200):
                if tm not in piv.index.get_level_values("t"):
                    continue
                p = piv.xs(tm, level="t")
                p = p[p.index.isin(gi.index)]
                for thr, lab in ((1.0, "any lead"), (1.3, "lead of 30%+"), (2.0, "lead of 2x+")):
                    tot = led_won = 0
                    for gid, r in p.iterrows():
                        if not id_ok(gid):
                            continue
                        g = gi.loc[gid]
                        if g.winner_team < 0 or g.end_t < tm + 30:
                            continue
                        hi = max(r[0], r[1])
                        lo = max(1.0, min(r[0], r[1]))
                        if hi / lo < thr or hi == lo:
                            continue
                        leader = 0 if r[0] > r[1] else 1
                        tot += 1
                        led_won += int(g.winner_team == leader)
                    if tot:
                        lo_ci, hi_ci = wilson(led_won, tot)
                        rows.append({"at": mmss(tm), "lead": lab, "games": tot, "leader went on to win": "%d (%s) [%s-%s]" % (led_won, pct(led_won / tot), pct(lo_ci), pct(hi_ci)),
                                     "comebacks": tot - led_won})
            return md(pd.DataFrame(rows))
        T["snowball"] = snowball(lambda gid: True)
        like = lambda gid: ("brood" not in gi.loc[gid].pair) or gi.loc[gid].a == gi.loc[gid].b
        T["snowball_nobroodcross"] = snowball(like)
        T["snowball_mirror"] = snowball(lambda gid: gi.loc[gid].a == gi.loc[gid].b)

        # lead at 10:00 in more detail for the games that were decided later
        try:
            plt = __import__("matplotlib.pyplot", fromlist=["x"])
            fig, ax = plt.subplots(1, 2, figsize=(11, 4))
            for k, tm in enumerate((420, 600)):
                if tm not in piv.index.get_level_values("t"):
                    continue
                p = piv.xs(tm, level="t")
                xs, ys, cs = [], [], []
                for gid, r in p.iterrows():
                    if gid not in gi.index:
                        continue
                    g = gi.loc[gid]
                    if g.winner_team < 0 or g.end_t < tm + 30:
                        continue
                    ratio = math.log2(max(r[0], 1) / max(r[1], 1))
                    xs.append(ratio)
                    ys.append(1 if g.winner_team == 0 else 0)
                ax[k].scatter(xs, np.array(ys) + np.random.uniform(-0.05, 0.05, len(ys)), alpha=0.6)
                ax[k].set_title("power ratio team0/team1 at %s (log2) vs team 0 won" % mmss(tm))
                ax[k].set_yticks([0, 1])
                ax[k].axvline(0, color="gray")
            plt.tight_layout()
            plt.savefig(a.data + "/figs/snowball.png", dpi=70)
            plt.close()
        except Exception as e:
            print("snowball fig failed", e)

        # ---------------------------------------------------------- what predicts the winner (difference team0 - team1 at a time)
        rows = []
        feats = ["power", "workers", "army_value", "halls", "buildings", "income_min", "supply", "gold"]
        for tm in (180, 300, 420, 600, 900):
            sub = ts[ts.t == tm]
            if sub.empty:
                continue
            a0 = sub[sub.team == 0].set_index("id")
            a1 = sub[sub.team == 1].set_index("id")
            ids = a0.index.intersection(a1.index).intersection(gi.index)
            ids = [i for i in ids if gi.loc[i].winner_team >= 0 and gi.loc[i].end_t >= tm + 30]
            if len(ids) < 8:
                continue
            y = np.array([1 if gi.loc[i].winner_team == 0 else 0 for i in ids])
            r = {"at": mmss(tm), "games": len(ids)}
            for f in feats:
                d = np.array([a0.loc[i, f] - a1.loc[i, f] for i in ids], dtype=float)
                nz = d != 0
                agree = ((d > 0) == (y == 1))[nz].mean() if nz.any() else float("nan")
                r[f] = "%d%%" % round(100 * agree) if not math.isnan(agree) else "-"
            rows.append(r)
        T["predictors"] = md(pd.DataFrame(rows))

        # ---------------------------------------------------------- measured timelines (compare docs/ai_build_timelines.md)
        rows = []
        prod_key = {"crown": "t_barracks", "brood": "t_warren", "clockwork": "t_assembly_works"}
        other = sides.set_index(["id", "team"]).plan_start
        for f in FACS:
            for plan in ["balanced", "rush", "xrush", "timing"]:
                x = sides[(sides.faction == f) & (sides.plan_start == plan)]
                if len(x) < 2:
                    continue
                r = {"faction": f, "plan": plan, "n": len(x), "production bldg (median)": mmss(x[prod_key[f]].median()), "first attack (median)": mmss(x.first_attack_t.median()) if x.first_attack_t.notna().any() else "never"}
                for tm in (120, 180, 240, 300):
                    q = ts[(ts.t == tm) & (ts.faction == f) & ts.id.isin(x.id)]
                    q = q.merge(x[["id", "team"]], on=["id", "team"])
                    r["%d:%02d wk/army" % (tm // 60, tm % 60)] = "%d / %d" % (q.workers.median(), q.army_value.median()) if len(q) else "-"
                rows.append(r)
        T["timelines"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ trade efficiency and army
    rows = []
    for f in FACS:
        for o in FACS:
            s = sides[(sides.faction == f) & (sides.opp == o)]
            if s.empty:
                continue
            kv, vl = s.value_killed.sum(), s.value_lost.sum()
            rows.append({"faction": f, "vs": o, "side-games": len(s), "value killed": kv, "value lost": vl, "trade ratio": kv / max(1, vl),
                         "units killed": s.killed.sum(), "units lost": s.lost.sum(), "peak army (median)": s.peak_army.median(),
                         "workers lost (mean)": s.workers_lost.mean(), "buildings lost (mean)": s.bld_lost.mean()})
    T["trade"] = md(pd.DataFrame(rows), floatfmt=".2f")

    comp = {}
    lt_sides = sides[sides.loss_tracking == 2]
    T["n_loss_tracked"] = str(len(lt_sides) // 2)
    for f in FACS:
        s = lt_sides[lt_sides.faction == f]
        pv, lost_k, prod_k = {}, {}, {}
        kills = {}
        for _, r in s.iterrows():
            for k, v in json.loads(r.produced_value).items():
                pv[k] = pv.get(k, 0) + v
            for k, v in json.loads(r.produced).items():
                prod_k[k] = prod_k.get(k, 0) + v
            for k, v in json.loads(r.lost_by_kind).items():
                lost_k[k] = lost_k.get(k, 0) + v
            for k, v in json.loads(r.kills_by).items():
                kills[k] = kills.get(k, 0) + v
        comp[f] = (pv, prod_k, lost_k, kills, len(s))
    rows = []
    for f in FACS:
        pv, prod_k, lost_k, kills, n = comp[f]
        tot = sum(v for k, v in pv.items() if k not in ("horse", "messenger")) or 1
        for k in sorted(pv, key=lambda x: -pv[x]):
            if k in ("horse", "messenger"):
                continue
            rows.append({"faction": f, "unit": k, "per game made": prod_k.get(k, 0) / max(1, n), "share of value made": "%d%%" % round(100 * pv[k] / tot),
                         "per game lost": lost_k.get(k, 0) / max(1, n), "lost / made": lost_k.get(k, 0) / max(1, prod_k.get(k, 1)),
                         "kills per game": kills.get(k, 0) / max(1, n), "kills per unit made": kills.get(k, 0) / max(1, prod_k.get(k, 1))})
    T["army_comp"] = md(pd.DataFrame(rows), floatfmt=".2f")

    # ------------------------------------------------------------------ waves and aggression
    if not waves.empty:
        waves["good"] = waves.killed_value >= waves.lost_value
        waves["min0"] = waves.t0 / 60.0
        rows = []
        for f in FACS:
            w = waves[waves.faction == f]
            if w.empty:
                continue
            w2 = w[w.kind == "wave"]
            rows.append({"faction": f, "waves": len(w2), "raids": int((w.kind == "raid").sum()), "per side-game": len(w2) / max(1, len(sides[sides.faction == f])),
                         "median supply": w2.supply.median() if len(w2) else 0, "first wave median": mmss(w2.groupby("id").t0.min().median()) if len(w2) else "-",
                         "waves that killed >= lost": "%d%%" % round(100 * w2.good.mean()) if len(w2) else "-",
                         "value killed / lost": w2.killed_value.sum() / max(1, w2.lost_value.sum()) if len(w2) else 0,
                         "small waves (<8 supply) after 5:00": int(((w2.supply < 8) & (w2.t0 > 300)).sum())})
        T["waves"] = md(pd.DataFrame(rows), floatfmt=".2f")
        # repeated failures
        rep = []
        for (gid, tm), w in waves[waves.kind == "wave"].groupby(["id", "team"]):
            w = w.sort_values("t0")
            run = 0
            best = 0
            start = None
            bstart = None
            for _, r in w.iterrows():
                if r.lost_value > r.killed_value and r.lost_value > 0:
                    run += 1
                    start = r.t0 if run == 1 else start
                    if run > best:
                        best, bstart = run, start
                else:
                    run = 0
            if best >= 3:
                rep.append({"game": gid, "team": tm, "faction": w.faction.iloc[0], "failed waves in a row": best, "first at": mmss(bstart)})
        T["repeat_fail"] = md(pd.DataFrame(rep).head(12)) if rep else "_none seen yet_"
        T["repeat_fail_n"] = str(len(rep))

    # ------------------------------------------------------------------ rush / timing outcomes
    rows = []
    for (pa, pb), g in games.groupby(["plan_a", "plan_b"]):
        for pair, gg in g.groupby("pair"):
            pass
    sd2 = sides.copy()
    sd2["plan_open"] = sd2.plan_start
    rows = []
    for plan in ["balanced", "rush", "xrush", "timing"]:
        for opp_plan in ["balanced"]:
            s = sd2[(sd2.plan_open == plan)]
            # opponent plan = plan_start of the other side of the same game
            other = sd2.set_index(["id", "team"]).plan_start
            s = s.assign(opp_plan=[other.get((r.id, 1 - r.team), "") for r in s.itertuples()])
            s = s[s.opp_plan == "balanced"] if plan != "balanced" else s[s.opp_plan == "balanced"]
            if s.empty:
                continue
            for f in FACS:
                x = s[s.faction == f]
                if len(x) < 1:
                    continue
                w = int(x.won1.sum())
                d = int(x.draw.sum())
                rows.append({"plan": plan, "faction": f, "vs Balanced": "n=%d" % len(x), "wins": w, "draws": d, "score [95% CI]": score_line(w, d, len(x)),
                             "first attack (median)": mmss(x.first_attack_t.median()) if x.first_attack_t.notna().any() else "-",
                             "workers lost (mean)": x.workers_lost.mean(), "game length (median)": mmss(x.end_t.median()),
                             "plan changed": "%d/%d" % ((x.plan_end != x.plan_start).sum(), len(x))})
    T["plans"] = md(pd.DataFrame(rows), floatfmt=".1f")

    # Crown wall
    cw = sides[(sides.faction == "crown")]
    if len(cw):
        rows = [{"Crown side-games": len(cw), "built a ramp wall": int(cw.wall_start_t.notna().sum()),
                 "wall finished (median)": mmss(cw.wall_done_t.median()),
                 "Horse Breeder opening": int((cw.crown_opening == "breeder").sum())}]
        T["wall"] = md(pd.DataFrame(rows))
        # outcome of Crown vs early rush
        rows = []
        r = sides.set_index(["id", "team"])
        for plan in ["rush", "xrush"]:
            x = sides[(sides.faction == "crown") & (sides.plan_start == "balanced")]
            x = x.assign(opp_plan=[r.plan_start.get((q.id, 1 - q.team), "") for q in x.itertuples()])
            x = x[x.opp_plan == plan]
            if x.empty:
                continue
            walled = x.wall_done_t.notna()
            for lab, sub in (("walled before the first blow", x[walled]), ("not walled", x[~walled])):
                if len(sub):
                    rows.append({"attacker plan": plan, "Crown defender": lab, "games": len(sub), "Crown won": int(sub.won1.sum()),
                                 "Crown workers lost (mean)": sub.workers_lost.mean(), "game length (median)": mmss(sub.end_t.median())})
        T["wall_vs_rush"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ scouting: the last verdict against what the foe really was
    oplan = sides.set_index(["id", "team"]).plan_start
    sv = sides.copy()
    sv["opp_plan"] = [oplan.get((r.id, 1 - r.team), "") for r in sv.itertuples()]
    sv["verdict"] = sv.scout_verdict.fillna("")
    sv["verdict"] = sv.verdict.str.split().str[0].replace("", "(none)")
    rows = []
    for f in FACS:
        for op in ["balanced", "rush", "xrush", "timing"]:
            x = sv[(sv.faction == f) & (sv.opp_plan == op)]
            if len(x) < 2:
                continue
            vc = x.verdict.value_counts()
            rows.append({"scouting side": f, "foe's real plan": op, "side-games": len(x), "verdicts": ", ".join("%s %d" % (k, v) for k, v in vc.items())})
    T["scout"] = md(pd.DataFrame(rows))

    if not events.empty:
        sc = events[events.kind == "scouted"].copy()
        sc = sc[sc.text.str.contains("scouted: rush")]
        if len(sc):
            sc["reason"] = sc.text.str.extract(r"scouted: rush \((.*?)\)")[0].str.replace(r"\d+(\.\d+)?", "N", regex=True)
            sc["reason"] = sc.reason.str.replace(r"N:N", "T", regex=True)
            first = sc.sort_values("t").groupby(["id", "who"]).first().reset_index()
            first["foe_plan"] = [oplan.get((r.id, 1 - int(r.who[1]) + 1 - 1), "") if False else "" for r in first.itertuples()]
            vc = first.reason.str.replace(r"at N.*", "", regex=True).value_counts().head(8)
            T["scout_reasons"] = "\n".join("- %d x \"%s\"" % (v, k) for k, v in vc.items())
            T["scout_first_rush_t"] = "median %s (10th-90th pct %s - %s), %d first verdicts" % (mmss(first.t.median()), mmss(first.t.quantile(0.1)), mmss(first.t.quantile(0.9)), len(first))

    # ------------------------------------------------------------------ no-gg when hopeless
    sd3 = sides.copy()
    rows = []
    for f in FACS:
        s = sd3[(sd3.faction == f)]
        lost = s[s.won == 0]
        if lost.empty:
            continue
        rows.append({"faction": f, "losing side-games": len(lost), "AI would say gg (hopeless 60 s)": "%d%%" % round(100 * lost.gg_t.notna().mean()),
                     "median time of the gg": mmss(lost.gg_t.median()) if lost.gg_t.notna().any() else "-",
                     "of those, ended by victory not gg": int(((lost.gg_t.notna()) & (lost.cause == "victory")).sum()),
                     "median s from gg-time to the end (victory only)": (lost[(lost.gg_t.notna()) & (lost.cause == "victory")].end_t - lost[(lost.gg_t.notna()) & (lost.cause == "victory")].gg_t).median() if ((lost.gg_t.notna()) & (lost.cause == "victory")).any() else float("nan"),
                     "hopeless flag flipped back (mean)": lost.hope_flips.mean()})
    T["gg"] = md(pd.DataFrame(rows), floatfmt=".0f")
    # false hopeless: winners who were flagged hopeless at some point
    wins = sd3[sd3.won == 1]
    T["gg_false"] = "%d of %d winning side-games had been flagged hopeless at some time (%d of them for 60 s or more)." % (
        int(wins.hope_first.notna().sum()), len(wins), int(wins.gg_t.notna().sum()))

    # ------------------------------------------------------------------ lost workers
    s = sides[sides.loss_tracking == 2].copy()
    rows = []
    for f in FACS:
        x = s[s.faction == f]
        if x.empty:
            continue
        rows.append({"faction": f, "side-games": len(x), "workers lost (mean)": x.workers_lost.mean(), "p90": x.workers_lost.quantile(0.9),
                     "lost >= 20 workers": int((x.workers_lost >= 20).sum()), "min workers after 3:00 <= 3": int((x.min_workers_after_3 <= 3).sum()),
                     "first worker lost (median)": mmss(x.first_worker_lost_t.median()) if x.first_worker_lost_t.notna().any() else "-"})
    T["workers_lost"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ sites placed and dropped again (a retry loop)
    if not events.empty:
        dv = events[events.kind == "dropped_site"].copy()
        if len(dv):
            m = dv.text.str.extract(r"P\d (\w+) (?:dropped|couldn't start) an? (.+?):")
            dv["faction"] = m[0].str.lower()
            dv["building"] = m[1]
            rows = []
            for (f, b), x in dv.groupby(["faction", "building"]):
                per = x.groupby("id").size()
                nside = len(sides[sides.faction == f])
                rows.append({"faction": f, "site": b, "drops": len(x), "games with any": len(per), "worst game": "%s (%d)" % (per.idxmax(), per.max()),
                             "drops per side-game": len(x) / max(1, nside)})
            rows.sort(key=lambda r: -r["drops"])
            T["dropped"] = md(pd.DataFrame(rows[:10]), floatfmt=".1f")
            # bursts: 5+ drops of the same kind inside 30 s
            bursts = []
            for (gid, f, b), x in dv.groupby(["id", "faction", "building"]):
                ts_ = sorted(x.t.tolist())
                i = 0
                while i < len(ts_):
                    j = i
                    while j + 1 < len(ts_) and ts_[j + 1] - ts_[i] <= 30:
                        j += 1
                    if j - i + 1 >= 5:
                        bursts.append((j - i + 1, gid, f, b, ts_[i]))
                        i = j + 1
                    else:
                        i += 1
            bursts.sort(reverse=True)
            T["dropped_bursts"] = "\n".join("- `%s` %s: %d drops of a %s within 30 s from %s" % (g_, f_, n_, b_, mmss(t_)) for n_, g_, f_, b_, t_ in bursts[:6]) or "_none seen yet_"
            T["dropped_bursts_n"] = str(len(bursts))

    json.dump(T, open(a.out, "w"), indent=1)
    print("tables:", len(T))


if __name__ == "__main__":
    main()
