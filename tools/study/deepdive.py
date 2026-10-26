#!/usr/bin/env python3
"""Second-pass tables for the AI balance study: the questions the first pass raised (plans within a matchup, the Brood
ground cap, stalled games, siege pull-backs, scouting accuracy, build-order and expansion effects ...).
Everything here is computed from the committed CSVs, so every number quoted from the study can be re-derived:

  python3 tools/study/deepdive.py --data docs/study_data --out docs/study_data/tables.json

Adds `dd_*` keys (markdown tables / lines) to the tables.json written by analysis.py and examples.py.
Measurement only: it never touches the game.
"""
import argparse, json, math, os, sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analysis import wilson, pct, md, mmss, score_line      # noqa: E402

HALL_COST = {"crown": 400, "brood": 350, "clockwork": 400}
FACS = ["crown", "brood", "clockwork"]
BROOD_CAP = 10400          # the capital's ground reserve is 10,500 biomass: "earned" this high means it is spent


def ci(k, n):
    lo, hi = wilson(k, n)
    return "%d/%d = %s [%s-%s]" % (round(k), n, pct(k / n if n else float("nan")), pct(lo), pct(hi))


def chi2_sf(x, k):
    """Survival function of chi-square(k): regularised upper incomplete gamma (series / continued fraction)."""
    a, xx = k / 2.0, x / 2.0
    if xx <= 0:
        return 1.0
    if xx < a + 1:
        s, term, n = 1.0 / a, 1.0 / a, 1
        while abs(term) > 1e-12 * abs(s) and n < 500:
            term *= xx / (a + n)
            s += term
            n += 1
        return max(0.0, 1.0 - s * math.exp(-xx + a * math.log(xx) - math.lgamma(a)))
    b, c, d = xx + 1 - a, 1e300, 1.0 / (xx + 1 - a)
    h = d
    for i in range(1, 500):
        an = -i * (i - a)
        b += 2
        d = an * d + b
        d = 1e-300 if abs(d) < 1e-300 else d
        c = b + an / c
        c = 1e-300 if abs(c) < 1e-300 else c
        d = 1.0 / d
        dl = d * c
        h *= dl
        if abs(dl - 1) < 1e-12:
            break
    return min(1.0, math.exp(-xx + a * math.log(xx) - math.lgamma(a)) * h)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="docs/study_data")
    ap.add_argument("--out", default="docs/study_data/tables.json")
    a = ap.parse_args()
    ld = lambda n: pd.read_csv(os.path.join(a.data, n if os.path.exists(os.path.join(a.data, n)) else n + ".gz"))
    games, sides, ts, waves, events = ld("games.csv"), ld("sides.csv"), ld("timeseries.csv"), ld("waves.csv"), ld("events.csv")
    T = json.load(open(a.out)) if os.path.exists(a.out) else {}
    ts = ts.drop_duplicates(["id", "team", "t"], keep="last").sort_values(["id", "team", "t"])
    gi = games.set_index("id")
    for c in ["hall2_t", "hall3_t", "soil_zero_t", "cap200_t", "gg_t"]:
        sides[c] = pd.to_numeric(sides[c], errors="coerce")
    sides["score"] = sides.won.map({1: 1.0, 0: 0.0, -1: 0.5})
    opp = sides[["id", "team", "plan_start"]].copy()
    opp["team"] = 1 - opp["team"]
    sides = sides.merge(opp.rename(columns={"plan_start": "opp_plan"}), on=["id", "team"])
    ts["power"] = ts.army_value + 50 * ts.workers + 30 * ts.buildings
    ts30 = ts[ts.t % 30 == 0]

    # ------------------------------------------------------------------ plans inside one matchup (no faction mix)
    rows = []
    for f, o in [("crown", "crown"), ("brood", "brood"), ("clockwork", "clockwork"), ("crown", "clockwork"), ("clockwork", "crown")]:
        d = sides[(sides.faction == f) & (sides.opp == o)]
        base = d[(d.plan_start == "balanced") & (d.opp_plan == "balanced")]
        lab = "%s vs %s%s" % (f, o, " (mirror)" if f == o else "")
        for plan in ["balanced", "rush", "xrush", "timing"]:
            x = d[(d.plan_start == plan) & (d.opp_plan == ("balanced"))] if plan != "balanced" else base
            if len(x) == 0:
                continue
            rows.append({"matchup": lab, "this side plays": plan, "against": "Balanced", "n": len(x), "score": score_line((x.won == 1).sum(), (x.won < 0).sum(), len(x))})
        # the Balanced side facing a rush or a timing attack
        for plan in ["rush", "xrush", "timing"]:
            x = d[(d.plan_start == "balanced") & (d.opp_plan == plan)]
            if len(x):
                rows.append({"matchup": lab, "this side plays": "balanced", "against": plan, "n": len(x), "score": score_line((x.won == 1).sum(), (x.won < 0).sum(), len(x))})
    T["dd_plans"] = md(pd.DataFrame(rows))
    b = sides[(sides.faction == "brood") & (sides.opp != "brood")]
    T["dd_brood_cross"] = "Brood in a cross matchup: %d wins in %d side-games (%d with a Rush, Extreme rush or Timing plan on either side)" % (
        (b.won == 1).sum(), len(b), ((b.plan_start != "balanced") | (b.opp_plan != "balanced")).sum())

    # ------------------------------------------------------------------ the Brood ground cap (one 10,500 reserve at the capital)
    br = ts[ts.faction == "brood"]
    capt = br[br.earned >= BROOD_CAP].groupby(["id", "team"]).t.min().rename("cap_t").reset_index()
    idle80 = br[(br.workers >= 10) & (br.idle_workers / br.workers.clip(lower=1) >= 0.8)].groupby(["id", "team"]).t.min().rename("idle80_t").reset_index()
    sb = sides[sides.faction == "brood"].merge(capt, on=["id", "team"], how="left").merge(idle80, on=["id", "team"], how="left")
    sb["cause"] = sb.id.map(gi.cause)
    rows = []
    for o in ["brood", "crown", "clockwork"]:
        x = sb[sb.opp == o]
        c = x[x.cap_t.notna()]
        rows.append({"Brood side-games vs": o, "n": len(x), "ground spent (earned >= 10,400)": "%d (%s)" % (len(c), pct(len(c) / len(x))),
                     "median time it was spent": mmss(c.cap_t.median()) if len(c) else "-",
                     "then 80%+ of grubs idle": "%d of %d" % (c.idle80_t.notna().sum(), len(c)),
                     "of those, won": "%d" % (c.won == 1).sum(), "game went to 30:00": "%d" % (c.cause.str.startswith("timeout")).sum()})
    T["dd_brood_cap"] = md(pd.DataFrame(rows))
    # earned biomass at fixed times, all three factions (own currency)
    rows = []
    for tm in (300, 600, 900, 1200, 1500):
        r = {"at": mmss(tm)}
        for f in FACS:
            v = ts[(ts.t == tm) & (ts.faction == f)].earned
            r[f + " earned (median, n)"] = "%d (%d)" % (v.median(), len(v)) if len(v) else "-"
        rows.append(r)
    T["dd_earned"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ games that reached 30:00: why
    ev = events[events.kind == "siege"] if "siege" in set(events.kind) else events.iloc[0:0]
    pulls = ev[ev.text.str.contains("pulls back")].groupby("id").agg(n_pull=("t", "size"), last_pull=("t", "max"))
    to = games[games.cause.str.startswith("timeout")]
    rows = []
    for gid in to.id:
        x = ts30[ts30.id == gid]
        r = {"id": gid, "pair": gi.loc[gid, "pair"], "cause": gi.loc[gid, "cause"]}
        for tm in (0, 1):
            y = x[x.team == tm].set_index("t")
            if 1800 not in y.index or 1500 not in y.index:
                break
            r["inc%d" % tm] = y.loc[1800, "earned"] - y.loc[1500, "earned"]
            r["army%d" % tm] = y.loc[1800, "army_value"]
            r["att%d" % tm] = y.loc[1500:1800, "attacking"].max()
        else:
            rows.append(r)
    st = pd.DataFrame(rows)
    st["n_pull"] = st.id.map(pulls.n_pull).fillna(0)
    st["dead"] = (st.inc0 < 150) & (st.inc1 < 150)
    hi, lo = st[["army0", "army1"]].max(axis=1), st[["army0", "army1"]].min(axis=1).clip(lower=1)
    st["ratio"] = hi / lo
    st["kind"] = np.where(st.dead, "dead economy on both sides (nobody can rebuild)",
                          np.where((st.n_pull > 0) & (st.ratio >= 3), "one side 3x+ bigger after a siege pull-back at a gate",
                                   np.where(st.ratio >= 3, "one side 3x+ bigger, no siege decision logged", "even armies, both still fighting")))
    tab = st.groupby(["pair", "kind"]).size().unstack(fill_value=0)
    T["dd_stalls"] = md(tab.reset_index())

    # ------------------------------------------------------------------ closing time: sustained 3x power lead -> end of game
    p = ts30.pivot_table(index=["id", "t"], columns="team", values="power").dropna()
    p.columns = ["p0", "p1"]
    rows = []
    for gid in gi.index:
        wt = int(gi.loc[gid, "winner_team"])
        if wt < 0 or gid not in p.index.get_level_values(0):
            continue
        x = p.loc[gid]
        pw, pl = x["p%d" % wt], x["p%d" % (1 - wt)]
        ok = pw >= 3.0 * pl.clip(lower=1)
        sus = np.nan
        for t in x.index[::-1]:
            if ok.loc[t]:
                sus = t
            else:
                break
        if not np.isnan(sus):
            rows.append({"id": gid, "pair": gi.loc[gid, "pair"], "winner": gi.loc[gid, "winner_faction"], "cause": gi.loc[gid, "cause"], "finish": gi.loc[gid, "end_t"] - sus})
    cl = pd.DataFrame(rows)
    out = []
    for w in FACS:
        x = cl[cl.winner == w].finish
        out.append({"winner": w, "decided games with a sustained 3x power lead": len(x), "median s to the end": int(x.median()), "90th pct s": int(x.quantile(.9)),
                    "10+ minutes of lead before the end": int((x >= 600).sum())})
    T["dd_closing"] = md(pd.DataFrame(out))
    T["dd_closing_ids"] = ", ".join("`%s` (%s, %d s)" % (r.id, r.winner, r.finish) for r in cl[cl.finish >= 600].sort_values("finish", ascending=False).itertuples())

    # ------------------------------------------------------------------ siege pull-backs at gates
    if len(ev):
        sg = games[["id", "pair", "cause", "end_t"]].merge(pulls, on="id", how="left").fillna({"n_pull": 0})
        sg["timeout"] = sg.cause.str.startswith("timeout")
        out = []
        for pr, x in sg.groupby("pair"):
            t = x[x.timeout]
            out.append({"matchup": pr.replace("-", " vs "), "games": len(x), "games with a pull-back": "%d (%s)" % ((x.n_pull > 0).sum(), pct((x.n_pull > 0).mean())),
                        "pull-backs in all": int(x.n_pull.sum()), "30:00 games": len(t), "of those with a pull-back": int((t.n_pull > 0).sum()),
                        "median minutes from the last pull-back to the end (30:00 games)": "%.0f" % ((t[t.n_pull > 0].end_t - t[t.n_pull > 0].last_pull).median() / 60.0) if (t.n_pull > 0).any() else "-"})
        T["dd_siege"] = md(pd.DataFrame(out))
        txt = ev[ev.text.str.contains("pulls back")].text.str.replace(r"\d+", "N", regex=True).str.replace(r"^P\w ", "", regex=True)
        T["dd_siege_text"] = "; ".join("%d x %s" % (v, k) for k, v in txt.value_counts().head(4).items())
    else:
        T["dd_siege"] = "_(events.csv has no siege rows yet: re-run aggregate.py)_"

    # ------------------------------------------------------------------ the scout's verdict against the foe's real plan
    foe = sides[["id", "team", "plan_start", "scout_verdict"]].copy()
    foe["team"] = 1 - foe["team"]
    foe = foe.rename(columns={"plan_start": "foe_plan", "scout_verdict": "_"})
    s2 = sides.merge(foe[["id", "team", "foe_plan"]], on=["id", "team"])
    s2["foe_rush"] = s2.foe_plan.isin(["rush", "xrush"])
    rows = []
    for f in FACS:
        x = s2[s2.faction == f]
        r = {"scouting side": f}
        for lab, m in [("foe really rushes", x.foe_rush), ("foe plays Timing", x.foe_plan == "timing"), ("foe plays Balanced", x.foe_plan == "balanced")]:
            y = x[m]
            r["verdict 'rush' when " + lab] = "%d/%d = %s" % ((y.scout_verdict == "rush").sum(), len(y), pct((y.scout_verdict == "rush").mean()))
        rows.append(r)
    T["dd_scout_acc"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ abandoned build sites
    dr = events[events.kind == "dropped_site"].copy()
    dr["site"] = dr.text.str.extract(r"(?:dropped a|couldn't start a) ([^:]+):")[0]
    dr["reason"] = np.where(dr.text.str.contains("nobody was coming"), "nobody was coming (abandoned)", "spot blocked")
    dr["team"] = dr.who.str.replace("P", "").astype(int) - 1
    tot = sides.groupby("faction").size()
    rows = []
    for (site, rs), x in dr.groupby(["site", "reason"]):
        f = x.merge(sides[["id", "team", "faction"]], on=["id", "team"]).faction.mode().iloc[0]
        n_sg = x[["id", "team"]].drop_duplicates().shape[0]
        rows.append({"site": site, "reason": rs, "faction": f, "drops": len(x), "side-games with any": "%d of %d" % (n_sg, tot[f]), "most in one game": "%s (%d)" % (x.groupby("id").size().idxmax(), x.groupby("id").size().max())})
    T["dd_drops"] = md(pd.DataFrame(rows).sort_values("drops", ascending=False).head(10))
    mound = dr[dr.site == "Clutch Mound"].groupby(["id", "team"]).size().rename("mound").reset_index()
    pit = dr[dr.site == "Feeding Pit"].groupby(["id", "team"]).size().rename("pit").reset_index()
    bm = sides[(sides.faction == "brood") & (sides.opp == "brood") & (sides.won >= 0)].merge(mound, on=["id", "team"], how="left").merge(pit, on=["id", "team"], how="left").fillna({"mound": 0, "pit": 0})
    T["dd_drops_mirror"] = md(bm.groupby(bm.won.map({1: "winner", 0: "loser"})).agg(side_games=("id", "size"), mound_drops_mean=("mound", "mean"), pit_drops_mean=("pit", "mean"),
                                                                                       peak_supply_mean=("peak_supply", "mean")).reset_index().rename(columns={"won": "Brood mirror side"}), floatfmt=".1f")

    # ------------------------------------------------------------------ economies that stop (80%+ of workers idle for 90 s)
    rows = []
    for (gid, team), x in ts30[ts30.t >= 420].groupby(["id", "team"]):
        x = x.reset_index(drop=True)
        stl = ((x.workers >= 8) & (x.idle_workers / x.workers.clip(lower=1) >= 0.8)).values
        on = next((i for i in range(len(stl) - 2) if stl[i] and stl[i + 1] and stl[i + 2]), None)
        if on is None:
            continue
        r = x.iloc[on]
        rows.append({"id": gid, "team": team, "fac": r.faction, "onset": r.t, "gold": r.gold, "soil": r.soil_mean, "halls": r.halls, "workers": r.workers, "idle": r.idle_workers,
                     "earned": r.earned})
    es = pd.DataFrame(rows).merge(sides[["id", "team", "won", "end_t", "opp"]], on=["id", "team"])
    es["afford"] = es.apply(lambda r: r.gold >= HALL_COST[r.fac], axis=1)
    # (the Brood's pits all draw on the capital's ground, and a second Burrow shows a full, unused 100%: "spent" for the Brood is
    #  its capital's reserve drawn, i.e. earned >= BROOD_CAP; for the others every hall's soil/coal at 0 somewhere = soil_mean 0)
    es["spent"] = np.where(es.fac == "brood", es.earned >= BROOD_CAP, es.soil <= 0.01)
    out = []
    for f in FACS:
        x = es[es.fac == f]
        n_all = (sides.faction == f).sum()
        out.append({"faction": f, "side-games": n_all, "economy stalled": "%d (%s)" % (len(x), pct(len(x) / n_all)), "median onset": mmss(x.onset.median()) if len(x) else "-",
                    "ground/soil already spent": pct(x.spent.mean()) if len(x) else "-", "vs (side-games)": ", ".join("%s %d" % (k, v) for k, v in x.opp.value_counts().items()) if len(x) else "-", "could afford a new hall": "%d of %d" % (x.afford.sum(), len(x)),
                    "went on to lose": pct((x.won == 0).mean()) if len(x) else "-"})
    T["dd_econ_stall"] = md(pd.DataFrame(out))
    T["dd_econ_stall_ids"] = "; ".join("`%s` (%s side, from %s: %d of %d workers idle, %d gold, %d hall%s)" % (r.id, r.fac, mmss(r.onset), r.idle, r.workers, r.gold, r.halls, "" if r.halls == 1 else "s")
                                       for r in es[es.fac == "crown"].sort_values("onset").head(5).itertuples())

    # ------------------------------------------------------------------ Crown opening, and who expands first (mirrors)
    c = sides[sides.faction == "crown"]
    rows = []
    for o in ["crown", "clockwork"]:
        for op in ["mill", "breeder"]:
            x = c[(c.opp == o) & (c.plan_start == "balanced") & (c.opp_plan == "balanced") & (c.crown_opening == op)]
            rows.append({"Crown vs": o, "opening": op, "Balanced/Balanced side-games": len(x), "score": score_line((x.won == 1).sum(), (x.won < 0).sum(), len(x))})
    m = c[(c.opp == "crown") & (c.plan_start == "balanced") & (c.opp_plan == "balanced")]
    j = m[m.team == 0].set_index("id").join(m[m.team == 1].set_index("id"), lsuffix="_a", rsuffix="_b")
    j2 = j[(j.crown_opening_a != j.crown_opening_b) & (j.won_a >= 0)]
    am = j2.crown_opening_a == "mill"
    w = int((((am) & (j2.won_a == 1)) | ((~am) & (j2.won_b == 1))).sum())
    T["dd_crown_open"] = md(pd.DataFrame(rows)) + "\n\nHead to head in the Balanced/Balanced Crown mirror (one Mill opening against one Breeder opening): the Mill side won %s." % ci(w, len(j2))
    rows = []
    for f in FACS:
        m = sides[(sides.faction == f) & (sides.opp == f) & (sides.won >= 0)]
        j = m[m.team == 0].set_index("id").join(m[m.team == 1].set_index("id"), lsuffix="_a", rsuffix="_b", how="inner")
        both = j[j.hall2_t_a.notna() & j.hall2_t_b.notna() & (j.hall2_t_a != j.hall2_t_b)]
        ea = both.hall2_t_a < both.hall2_t_b
        w = int(((ea & (both.won_a == 1)) | ((~ea) & (both.won_b == 1))).sum())
        one = j[j.hall2_t_a.notna() ^ j.hall2_t_b.notna()]
        ex = one.hall2_t_a.notna()
        w1 = int(((ex & (one.won_a == 1)) | ((~ex) & (one.won_b == 1))).sum())
        rows.append({"mirror": f, "both expanded: the earlier one won": ci(w, len(both)), "only one side expanded: it won": ci(w1, len(one)) if len(one) else "-"})
    T["dd_expand_first"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ what leads predict, inside mirrors only (and Balanced/Balanced)
    rows = []
    feats = ["power", "workers", "army_value", "halls", "buildings", "supply", "gold"]
    mir = [i for i in gi.index if gi.loc[i, "a"] == gi.loc[i, "b"]]
    for label, ids0 in (("mirrors", mir), ("Balanced/Balanced mirrors", [i for i in mir if gi.loc[i, "plan_a"] == "balanced" and gi.loc[i, "plan_b"] == "balanced"])):
        for tm in (180, 300, 420, 600, 900):
            sub = ts[(ts.t == tm) & ts.id.isin(ids0)]
            a0, a1 = sub[sub.team == 0].set_index("id"), sub[sub.team == 1].set_index("id")
            ids = [i for i in a0.index.intersection(a1.index) if gi.loc[i, "winner_team"] >= 0 and gi.loc[i, "end_t"] >= tm + 30]
            y = np.array([1 if gi.loc[i, "winner_team"] == 0 else 0 for i in ids])
            r = {"sample": label, "at": mmss(tm), "games": len(ids)}
            for f in feats:
                d = np.array([a0.loc[i, f] - a1.loc[i, f] for i in ids], dtype=float)
                nz = d != 0
                r[f] = "%d%% (n=%d)" % (round(100 * ((d > 0) == (y == 1))[nz].mean()), nz.sum()) if nz.any() else "-"
            rows.append(r)
    T["dd_predictors_mirror"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ is any map unfair to one spawn? (mirrors only, so the faction cannot matter)
    def homog(df, kcol, ncol):
        ph = df[kcol].sum() / df[ncol].sum()
        chi_ = float((((df[kcol] - df[ncol] * ph) ** 2) / (df[ncol] * ph * (1 - ph))).sum())
        pv_ = chi2_sf(chi_, len(df) - 1)
        return chi_, pv_

    def ptxt(pv_):
        return "p < 0.001" if pv_ < 0.001 else "p = %.3f" % pv_

    mm = games[(games.a == games.b) & (games.winner_team >= 0)].copy()
    mm["bal"] = (mm.plan_a == "balanced") & (mm.plan_b == "balanced")
    rows = []
    for mp, x in mm.groupby("map"):
        xb = x[x.bal]
        rows.append({"map": mp, "all plans: decided mirror games": len(x), "spawn 0 won": ci(int((x.winner_team == 0).sum()), len(x)),
                     "Balanced/Balanced only": len(xb), "spawn 0 won ": ci(int((xb.winner_team == 0).sum()), len(xb)),
                     "k": int((x.winner_team == 0).sum()), "n": len(x), "kb": int((xb.winner_team == 0).sum()), "nb": len(xb)})
    sp = pd.DataFrame(rows)
    c1, p1 = homog(sp, "k", "n")
    c2, p2 = homog(sp, "kb", "nb")
    T["dd_spawn_maps"] = md(sp.drop(columns=["k", "n", "kb", "nb"])) + "\n\nHomogeneity of the spawn-0 share across the %d maps: all plans chi-square %.1f, %s; Balanced/Balanced only chi-square %.1f, %s." % (
        len(sp), c1, ptxt(p1), c2, ptxt(p2))

    # ------------------------------------------------------------------ Crown against Clockwork, map by map
    cc = sides[(sides.faction == "crown") & (sides.opp == "clockwork")].copy()
    cc["bal"] = (cc.plan_start == "balanced") & (cc.opp_plan == "balanced")
    rows = []
    for mp, x in cc.groupby("map"):
        xb = x[x.bal]
        rows.append({"map": mp, "all plans: Crown won": ci(int((x.won == 1).sum()), len(x)), "Balanced/Balanced only: Crown won": ci(int((xb.won == 1).sum()), len(xb)),
                     "k": int((x.won == 1).sum()), "n": len(x), "kb": int((xb.won == 1).sum()), "nb": len(xb)})
    g = pd.DataFrame(rows)
    c1, p1 = homog(g, "k", "n")
    c2, p2 = homog(g, "kb", "nb")
    T["dd_cc_maps"] = md(g.drop(columns=["k", "n", "kb", "nb"])) + "\n\nHomogeneity of the Crown's result across the %d maps: all plans chi-square %.1f, %s (%s); Balanced/Balanced only chi-square %.1f, %s (%s)." % (
        len(g), c1, ptxt(p1), "the maps differ" if p1 < 0.05 else "no evidence that the maps differ", c2, ptxt(p2), "the maps differ" if p2 < 0.05 else "no evidence that the maps differ")

    # ------------------------------------------------------------------ early worker wipe-outs and the saltpetre bank
    rows = []
    for (gid, team), x in ts30[(ts30.t <= 600)].groupby(["id", "team"]):
        if x.workers.max() < 8:
            continue
        w = x[x.workers <= 2]
        if len(w):
            rows.append({"id": gid, "team": team, "faction": x.faction.iloc[0], "first": w.t.iloc[0], "peak": x.workers.max(), "army": w.army_value.iloc[0], "opp": gi.loc[gid, "pair"]})
    ew = pd.DataFrame(rows)
    out = []
    for f in FACS:
        n_all = (sides.faction == f).sum()
        x = ew[ew.faction == f] if len(ew) else ew
        out.append({"faction": f, "side-games": n_all, "down to 2 or fewer workers before 10:00": len(x)})
    T["dd_early_wipe"] = md(pd.DataFrame(out)) + ("\n\n" + "\n".join("- `%s` %s side at %s: workers down to 2 or fewer (peak %d), army value %d" % (r.id, r.faction, mmss(r.first), r.peak, r.army) for r in ew.sort_values("first").head(6).itertuples()) if len(ew) else "")
    cr = ts[(ts.faction == "crown")]
    rows = []
    for tm in (600, 900, 1200, 1500):
        v = cr[cr.t == tm].res2
        rows.append({"at": mmss(tm), "Crown sides still playing": len(v), "median powder banked": int(v.median()), "share with 500+ powder": pct((v >= 500).mean())})
    T["dd_powder"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ long supply blocks: does the AI keep buying production meanwhile?
    rows = []
    for f in FACS:
        bl = sides[(sides.faction == f) & (sides.blocked_s >= 120)]
        for r in bl.itertuples():
            y = ts[(ts.id == r.id) & (ts.team == r.team)].sort_values("t").copy()
            y["db"] = y.blocked_s.diff().fillna(y.blocked_s)
            w = y[y.db >= 15]
            if len(w) == 0:
                continue
            t0, t1 = w.t.iloc[0], w.t.iloc[-1]
            a0, b1 = y[y.t == max(t0 - 30, 0)], y[y.t == t1]
            if len(a0) and len(b1):
                rows.append({"id": r.id, "team": r.team, "faction": f, "blocked": r.blocked_s, "from": t0, "to": t1,
                             "production_gained": int(b1.prod_bld.iloc[0] - a0.prod_bld.iloc[0]), "buildings_gained": int(b1.buildings.iloc[0] - a0.buildings.iloc[0]),
                             "gold_peak": int(w.gold.max()), "supply": int(w.supply.iloc[0]), "cap": int(w.cap.iloc[0]), "idle_at_end": int(b1.prod_idle.iloc[0]), "prod_at_end": int(b1.prod_bld.iloc[0])})
    bb = pd.DataFrame(rows)
    out = []
    for f in FACS:
        x = bb[bb.faction == f] if len(bb) else bb
        n_all = (sides.faction == f).sum()
        n120 = int((sides[sides.faction == f].blocked_s >= 120).sum())
        out.append({"faction": f, "side-games": n_all, "blocked 120 s or more (supply at the cap, 100+ gold)": "%d (%s)" % (n120, pct(n120 / n_all)),
                    "median production buildings added during the block": int(x.production_gained.median()) if len(x) else "-",
                    "median peak gold in the block": int(x.gold_peak.median()) if len(x) else "-"})
    T["dd_block_build"] = md(pd.DataFrame(out))
    T["dd_block_examples"] = "\n".join("- `%s` %s side: supply-blocked %d s between %s and %s; %d production buildings added in that span (%d of %d idle at its end), gold up to %d" % (
        r.id, r.faction, r.blocked, mmss(r["from"]), mmss(r.to), r.production_gained, r.idle_at_end, r.prod_at_end, r.gold_peak)
        for _, r in bb.sort_values("blocked", ascending=False).head(5).iterrows()) if len(bb) else ""

    # ------------------------------------------------------------------ the AI's own attack gate (only games run from stage 9 on carry it)
    if "attack_at_end" in sides.columns and sides.attack_at_end.notna().any():
        x = sides[sides.attack_at_end.notna()].copy()
        x["cause"] = x.id.map(gi.cause)
        x["short"] = x.army_supply_end < x.attack_at_end
        def idle_share(js):
            try:
                o = json.loads(js)
                return o.get("idle", 0) / max(1, sum(o.values()))
            except Exception:
                return float("nan")
        x["idle_share"] = x.army_orders.map(idle_share)
        out = []
        for f in FACS:
            y = x[(x.faction == f) & x.cause.str.startswith("timeout")]
            if len(y):
                out.append({"faction": f, "30:00 side-games with the gate logged": len(y), "army supply below the next-wave threshold": int(y.short.sum()),
                            "median threshold": int(y.attack_at_end.median()), "median army supply": int(y.army_supply_end.median()),
                            "enemy near one of its buildings": int(y.threat_end.astype(str).str.lower().eq("true").sum()),
                            "siege plan active": int(y.siege_end.astype(str).str.lower().eq("true").sum()),
                            "median share of army idle": pct(y.idle_share.median())})
        T["dd_attack_gate"] = md(pd.DataFrame(out)) if out else "_(no 30:00 games with the gate logged yet)_"
        T["dd_attack_gate_n"] = str(len(x))
    else:
        T["dd_attack_gate"] = "_(no games with the gate logged yet)_"
        T["dd_attack_gate_n"] = "0"
    # ------------------------------------------------------------------ is a waiting army held by the wave threshold or by "an enemy is near a building"?
    # (the threat / attack_at / siege columns exist from the stage-9b harness on; older games have them empty)
    if "threat" in ts.columns and ts.threat.notna().any():
        tg = ts[ts.threat.notna()].copy()
        T["dd_threat_games"] = str(tg.id.nunique())
        z = tg[(tg.t >= 600) & (tg.army_units >= 5) & (tg.attacking == 0)].copy()
        A, B, C = "A: army supply below the next-wave threshold", "B: threshold met, an enemy is near a building", "C: threshold met, nobody near"
        z["why"] = np.where(z.army_supply < z.attack_at, A, np.where(z.threat == 1, B, C))
        z["idle80"] = z.army_idle >= 0.8 * z.army_units
        rows = []
        for f in FACS:
            x = z[z.faction == f]
            if not len(x):
                continue
            r = {"faction": f, "side-games": x.groupby(["id", "team"]).ngroups, "30 s samples": len(x)}
            for k in (A, B, C):
                m = x.why == k
                r[k + " (share of samples; of those, army 80%+ idle)"] = "%s; %s" % (pct(m.mean()), pct(x[m].idle80.mean()) if m.any() else "-")
            rows.append(r)
        T["dd_threat_freeze"] = md(pd.DataFrame(rows)) if rows else "_(no samples yet)_"
        runs = []
        for (gid, team), x in tg[tg.t >= 600].sort_values("t").groupby(["id", "team"]):
            v = x.threat.astype(int).values
            best = cur = 0
            for e in v:
                cur = cur + 1 if e else 0
                best = max(best, cur)
            runs.append({"id": gid, "team": team, "faction": x.faction.iloc[0], "share": float(v.mean()), "longest_min": best * 0.5, "won": int(gi.loc[gid, "winner_team"] == team) if gi.loc[gid, "winner_team"] >= 0 else -1})
        rr = pd.DataFrame(runs)
        out = []
        for f in FACS:
            x = rr[rr.faction == f]
            if len(x):
                out.append({"faction": f, "side-games with the gate logged": len(x), "enemy near a building for 50%+ of the time after 10:00": int((x.share >= 0.5).sum()),
                            "median longest unbroken stretch (min)": "%.1f" % x.longest_min.median(), "longest of all (min)": "%.1f" % x.longest_min.max()})
        T["dd_threat_runs"] = md(pd.DataFrame(out)) if out else "_(no samples yet)_"
        T["dd_threat_examples"] = "\n".join("- `%s` %s side (team %d, %s): an enemy unit within reach of one of its buildings for %.1f unbroken minutes after 10:00 (%s of the time overall)" % (
            r.id, r.faction, r.team, {1: "won", 0: "lost", -1: "draw"}[r.won], r.longest_min, pct(r.share)) for r in rr.sort_values("longest_min", ascending=False).head(6).itertuples())
    else:
        T["dd_threat_freeze"] = "_(no games with the gate logged per 30 s yet)_"
        T["dd_threat_games"] = "0"

    # ------------------------------------------------------------------ Crown against Clockwork: the four maps with a south ramp (post hoc)
    # Found after the per-map table above: the four maps where the Crown never wins share one base layout in scripts/map_data.gd
    # (plateau ramp at about (9-12, 24), natural at (5-6, 26-28)). The grouping is post hoc: it is a lead, not a pre-registered test.
    SOUTH = {"kestrel_rise", "cinder_steps", "glimmerdeep", "frostmere"}

    def fisher2(k1, n1, k2, n2):
        tot, K = n1 + n2, k1 + k2

        def pm(x):
            return math.comb(K, x) * math.comb(tot - K, n1 - x) / math.comb(tot, n1)
        p0 = pm(k1)
        return sum(pm(x) for x in range(max(0, n1 - (tot - K)), min(K, n1) + 1) if pm(x) <= p0 * (1 + 1e-9))

    ccg = games[games.pair == "crown-clockwork"].copy()
    ccg["grp"] = np.where(ccg["map"].isin(SOUTH), "south-ramp maps (Kestrel Rise, Cinder Steps, Glimmerdeep, Frostmere)", "the other 8 maps")
    ccg["bal"] = (ccg.plan_a == "balanced") & (ccg.plan_b == "balanced")
    ccg["crown_won"] = (ccg.winner_faction == "crown").astype(int)
    lostb = events[(events.kind == "lost_building") & events.text.str.contains(" Crown lost ")].groupby("id").t.min()
    army9 = ts[(ts.t == 540) & ts.id.isin(ccg.id)].pivot_table(index="id", columns="faction", values="army_value")
    rows, kn = [], {}
    for gname, x in ccg.groupby("grp"):
        xb = x[x.bal]
        kn[gname] = ((int(x.crown_won.sum()), len(x)), (int(xb.crown_won.sum()), len(xb)))
        rows.append({"maps": gname, "games": len(x), "Crown won (all plans)": ci(int(x.crown_won.sum()), len(x)),
                     "Crown won (Balanced/Balanced)": ci(int(xb.crown_won.sum()), len(xb)), "median game length": mmss(x.end_t.median()),
                     "first Crown building lost (median)": mmss(lostb.reindex(x.id).median()),
                     "army value at 9:00, Crown / Clockwork (median)": "%d / %d" % (army9.reindex(x.id).crown.median(), army9.reindex(x.id).clockwork.median())})
    ks = [v for v in kn if v.startswith("south")][0]
    ko = [v for v in kn if v.startswith("the other")][0]
    T["dd_layout"] = md(pd.DataFrame(rows)) + "\n\nFisher exact test, Crown wins on the south-ramp maps against the other maps: all plans p = %.1e; Balanced/Balanced p = %.1e (post hoc grouping)." % (
        fisher2(kn[ks][0][0], kn[ks][0][1], kn[ko][0][0], kn[ko][0][1]), fisher2(kn[ks][1][0], kn[ks][1][1], kn[ko][1][0], kn[ko][1][1]))

    wv = waves[(waves.faction == "clockwork") & (waves.opp == "crown")].copy()
    for c in ["t0", "killed_value", "lost_value", "supply"]:
        wv[c] = pd.to_numeric(wv[c], errors="coerce")
    wv["grp"] = np.where(wv["map"].isin(SOUTH), "south-ramp maps", "the other 8 maps")
    wv["rank"] = wv.sort_values("t0").groupby(["id", "team"]).cumcount() + 1
    rows = []
    for gname, x in wv[wv["rank"] <= 3].groupby("grp"):
        for rk, y in x.groupby("rank"):
            rows.append({"maps": gname, "Clockwork wave": "#%d" % rk, "waves": len(y), "median start": mmss(y.t0.median()), "median supply": int(y.supply.median()),
                         "value it killed (mean)": int(y.killed_value.mean()), "value it lost (mean)": int(y.lost_value.mean()),
                         "killed per value lost": "%.1f" % (y.killed_value.sum() / max(1.0, y.lost_value.sum()))})
    T["dd_layout_waves"] = md(pd.DataFrame(rows)) if rows else "_(no waves)_"

    # ------------------------------------------------------------------ does the 30:00 adjudication (power lead of 25%+ = win) change the matrix?
    rows = []
    for pr, x in games.groupby("pair", sort=False):
        a_, b_ = pr.split("-")
        fa = a_
        won_a = (x.winner_faction == fa).astype(float) if a_ != b_ else (x.winner_team == 0).astype(float)
        draw = (x.winner_team < 0)
        to = x.cause.str.startswith("timeout")
        as_is = won_a + 0.5 * draw
        k1 = as_is.sum()
        # 30:00 games all counted as draws
        k2 = (won_a.where(~to, 0.5)).sum()
        # 30:00 games left out
        xx = x[~to]
        k3 = ((xx.winner_faction == fa).astype(float) if a_ != b_ else (xx.winner_team == 0).astype(float)).sum()
        lab = "%s vs %s%s" % (a_, b_, " (spawn 0)" if a_ == b_ else "")
        rows.append({"matchup (first side's score)": lab, "30:00 games": int(to.sum()), "as run (lead of 25%+ wins)": score_line(k1, 0, len(x)),
                     "all 30:00 games drawn": score_line(k2, 0, len(x)), "30:00 games left out": score_line(k3, 0, len(xx))})
    T["dd_sensitivity"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ the same south-ramp grouping on games run AFTER it was chosen (stage 11)
    # The grouping above was picked at about 930 games, after looking at the per-map table. Crown-Clockwork games from round
    # 155 on had not finished when it was picked: they are a fresh, out-of-sample check of the same prediction.
    ccg["round"] = ccg.id.str.rsplit("_", n=1).str[1].astype(int)
    rows = []
    for lab, x in (("rounds 0-154 (the games the grouping was found in)", ccg[ccg["round"] < 155]), ("rounds 155 on (run after it was chosen)", ccg[ccg["round"] >= 155])):
        xs, xo = x[x["map"].isin(SOUTH)], x[~x["map"].isin(SOUTH)]
        k1, n1, k2, n2 = int(xs.crown_won.sum()), len(xs), int(xo.crown_won.sum()), len(xo)
        rows.append({"games": lab, "Crown won on the 4 south-ramp maps": ci(k1, n1) if n1 else "-", "Crown won on the other 8 maps": ci(k2, n2) if n2 else "-",
                     "Fisher p (two-sided)": ("p = %.2g" % fisher2(k1, n1, k2, n2)) if n1 and n2 else "-"})
    T["dd_layout_oos"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ economies side by side, where the opponent is the same faction (Balanced/Balanced mirrors)
    gb = games.set_index("id")
    balm = [i for i in gi.index if gi.loc[i, "a"] == gi.loc[i, "b"] and gi.loc[i, "plan_a"] == "balanced" and gi.loc[i, "plan_b"] == "balanced"]
    m = ts[ts.id.isin(balm)]
    rows = []
    for tm in (120, 180, 240, 300, 420, 600, 900):
        r = {"at": mmss(tm)}
        for f in FACS:
            y = m[(m.t == tm) & (m.faction == f)]
            r[f + ": army value / earned / workers"] = "%d / %d / %d (n=%d)" % (y.army_value.median(), y.earned.median(), y.workers.median(), len(y)) if len(y) else "-"
        rows.append(r)
    T["dd_mirror_econ"] = md(pd.DataFrame(rows))

    # ------------------------------------------------------------------ the Brood against the other two, minute by minute (Balanced/Balanced)
    rows = []
    for pr, foe in (("crown-brood", "crown"), ("brood-clockwork", "clockwork")):
        ids = games[(games.pair == pr) & (games.plan_a == "balanced") & (games.plan_b == "balanced")].id
        y = ts[ts.id.isin(ids)]
        for tm in (180, 240, 300, 360, 420, 480, 600):
            b, o = y[(y.t == tm) & (y.faction == "brood")], y[(y.t == tm) & (y.faction == foe)]
            if len(b) == 0:
                continue
            rows.append({"Brood vs": foe, "at": mmss(tm), "games still on": len(b), "Brood grubs / army value": "%d / %d" % (b.workers.median(), b.army_value.median()),
                         "%s workers / army value" % foe: "%d / %d" % (o.workers.median(), o.army_value.median()),
                         "Brood units lost so far": int(b.units_lost.median())})
    T["dd_brood_vs"] = md(pd.DataFrame(rows).fillna("-"))
    kb = []
    for f in ("crown", "clockwork"):
        x = sides[(sides.faction == f) & (sides.opp == "brood")]
        tot = {}
        for js in x.kills_by:
            for k, v in json.loads(js).items():
                tot[k] = tot.get(k, 0) + v
        n_ = max(1, sum(tot.values()))
        kb.append("the %s's kills of Brood units were made by %s" % (f.capitalize(), ", ".join("%s %d%%" % (k.replace("_", " "), round(100 * v / n_)) for k, v in sorted(tot.items(), key=lambda kv: -kv[1])[:4] if round(100 * v / n_) >= 1)))
    T["dd_brood_killers"] = "; ".join(kb)

    # ------------------------------------------------------------------ armies that sit at the supply cap with a bank and do not attack
    # From the 30 s samples: the longest unbroken stretch (after 8:00) where a side is within 2 of its cap (or at 199+), has 1,000+
    # in the bank and has no wave out, while the game goes on.
    rows = []
    for (gid, team), x in ts30[ts30.t >= 480].groupby(["id", "team"]):
        ok = (((x.supply >= x.cap - 2) | (x.supply >= 199)) & (x.gold >= 1000) & (x.attacking == 0)).values
        best = cur = 0
        start = bstart = None
        tv = x.t.values
        for i_, e in enumerate(ok):
            if e:
                cur += 1
                if cur == 1:
                    start = tv[i_]
                if cur > best:
                    best, bstart = cur, start
            else:
                cur = 0
        if best >= 2:
            y = x[x.t >= bstart].iloc[:best]
            rows.append({"id": gid, "team": team, "faction": x.faction.iloc[0], "from": bstart, "minutes": best * 0.5, "bank_max": int(y.gold.max()),
                         "army": int(y.army_value.median()), "won": int(gi.loc[gid, "winner_team"] == team) if gi.loc[gid, "winner_team"] >= 0 else -1,
                         "cause": gi.loc[gid, "cause"], "pair": gi.loc[gid, "pair"]})
    st_ = pd.DataFrame(rows)
    out = []
    for f in FACS:
        x = st_[st_.faction == f] if len(st_) else st_
        n_all = (sides.faction == f).sum()
        out.append({"faction": f, "side-games": n_all, "capped with 1,000+ banked and no wave out for 5+ min": int((x.minutes >= 5).sum()) if len(x) else 0,
                    "for 10+ min": int((x.minutes >= 10).sum()) if len(x) else 0, "of the 10+ min ones, side won": int(((x.minutes >= 10) & (x.won == 1)).sum()) if len(x) else 0,
                    "longest (min)": "%.1f" % x.minutes.max() if len(x) else "-"})
    T["dd_capped_idle"] = md(pd.DataFrame(out))
    T["dd_capped_idle_examples"] = "\n".join("- `%s` %s side (%s): at the cap with 1,000+ banked and no wave out for %.1f minutes from %s, bank up to %d, army value about %d; the game ended by %s" % (
        r.id, r.faction, {1: "won", 0: "lost", -1: "draw"}[r.won], r.minutes, mmss(r["from"]), r.bank_max, r.army, r.cause) for _, r in st_.sort_values("minutes", ascending=False).head(6).iterrows()) if len(st_) else ""

    # ------------------------------------------------------------------ the other kind of stall: a wave that stays out for 10+ minutes
    lw = waves[waves.kind == "wave"].copy()
    for c in ["t0", "t1"]:
        lw[c] = pd.to_numeric(lw[c], errors="coerce")
    lw["dur"] = lw.t1 - lw.t0
    lw = lw[lw.dur >= 600]
    lw["pair"] = lw.id.map(gi.pair)
    lw["cause"] = lw.id.map(gi.cause)
    lw["won"] = [int(gi.loc[r.id, "winner_team"] == r.team) for r in lw.itertuples()]
    out = []
    for (f, pr), x in lw.groupby(["faction", "pair"]):
        out.append({"attacker": f, "matchup": pr.replace("-", " vs "), "waves out 10+ min": len(x), "median minutes": "%.0f" % (x.dur.median() / 60.0),
                    "attacker won": "%d of %d" % (x.won.sum(), len(x)), "game reached 30:00": int(x.cause.str.startswith("timeout").sum())})
    T["dd_long_waves"] = md(pd.DataFrame(out).sort_values("waves out 10+ min", ascending=False)) if out else "_(none)_"
    T["dd_long_waves_note"] = "%d waves stayed out 10 minutes or more in %d games" % (len(lw), lw.id.nunique())

    # ------------------------------------------------------------------ could the next-wave threshold have been out of reach? (rebuilt from ai.gd)
    # ai.gd: a failed wave (killed under 60% of its value) sets _attack_at >= ceil(1.4 x the wave's supply) with no upper bound
    # (_wave_end); a pull-back at a gate sets it >= min(ceil(1.4 x supply), supply + 40) (_siege_plan); only a launched wave caps
    # it at 70. The most army a side can field is 200 minus its workers. Rebuilt here from the logged waves and pull-backs.
    pbk = events[(events.kind == "siege") & events.text.str.contains("pulls back")].copy()
    pbk["team"] = pbk.who.str[1].astype(int) - 1
    wv2 = waves[waves.kind == "wave"].copy()
    for c in ["t0", "t1", "supply", "killed_value", "value"]:
        wv2[c] = pd.to_numeric(wv2[c], errors="coerce")
    wv2 = wv2.dropna(subset=["t0", "t1", "supply", "killed_value", "value"])
    pbset = {}
    for r in pbk.itertuples():
        pbset.setdefault((r.id, r.team), []).append(r.t)
    wv2["pullback"] = [any(r.t0 - 1 <= tt <= r.t1 + 3 for tt in pbset.get((r.id, r.team), [])) for r in wv2.itertuples()]
    wv2["failed"] = wv2.killed_value < 0.6 * wv2.value
    wv2["thr"] = [max(math.ceil(1.4 * s_) if f_ else 0, min(math.ceil(1.4 * s_), s_ + 40) if p_ else 0) for s_, f_, p_ in zip(wv2.supply, wv2.failed, wv2.pullback)]
    tsi = ts.set_index(["id", "team", "t"])
    def wk(r):
        tt = int(r.t1 // 30 * 30)
        for d in (0, 30, -30):
            k = (r.id, r.team, tt + d)
            if k in tsi.index:
                return float(tsi.loc[k, "workers"])
        return float("nan")
    wv2["room"] = [200 - wk(r) for r in wv2.itertuples()]
    fz = wv2[wv2.thr > wv2.room]
    T["dd_freeze_thr"] = ("%d of %d waves ended with a next-wave threshold (rebuilt) above 200 minus the side's workers, in %d games: %s." % (
        len(fz), len(wv2), fz.id.nunique(), ", ".join("`%s` (%s, wave of %d supply at %s, threshold %d, room %d, %s)" % (
            r.id, r.faction, r.supply, mmss(r.t1), r.thr, r.room, gi.loc[r.id, "cause"]) for r in fz.sort_values("t1").itertuples()))) if len(fz) else "No wave ended with a threshold out of reach."

    # ------------------------------------------------------------------ the scout's "rush" verdict against a Balanced foe: why it fired
    sc = events[(events.kind == "scouted") & events.text.str.contains("scouted: rush")].copy()
    sc["team"] = sc.who.str[1].astype(int) - 1
    sc = sc.merge(sides[["id", "team", "faction", "opp", "opp_plan"]], on=["id", "team"])
    sc["why"] = np.select([sc.text.str.contains("Spawning Den already up"), sc.text.str.contains("Assembly Works already up"), sc.text.str.contains("early army"),
                           sc.text.str.contains("fast")], ["a Spawning Den seen before 2:20", "an Assembly Works seen before 1:40", "an early army", "fast units seen (Horsemen)"], "other")
    fb = sc[sc.opp_plan == "balanced"].sort_values("t").groupby(["id", "team"]).first().reset_index()
    rows = []
    for o in FACS:
        x = fb[fb.opp == o]
        n_bal = int(((sides.opp == o) & (sides.opp_plan == "balanced")).sum())
        rows.append({"foe (playing Balanced)": o, "side-games": n_bal, "scout said 'rush'": "%d (%s)" % (len(x), pct(len(x) / max(1, n_bal))),
                     "median time": mmss(x.t.median()) if len(x) else "-", "first reason": ", ".join("%s %d" % (k, v) for k, v in x.why.value_counts().items())})
    T["dd_scout_false"] = md(pd.DataFrame(rows))
    early = sc[sc.t <= 240].groupby(["id", "team"]).size().rename("er").reset_index()
    s3 = sides.merge(early, on=["id", "team"], how="left")
    s3["er"] = s3.er.notna()
    lines_ = []
    for f in FACS:
        mm_ = s3[(s3.faction == f) & (s3.opp == f) & (s3.won >= 0)]
        mm_ = mm_[mm_.id.isin(balm)]
        j = mm_[mm_.team == 0].set_index("id").join(mm_[mm_.team == 1].set_index("id"), lsuffix="_a", rsuffix="_b", how="inner")
        d_ = j[j.er_a != j.er_b]
        k_ = int(((d_.er_a) & (d_.won_a == 1)).sum() + ((d_.er_b) & (d_.won_b == 1)).sum())
        lines_.append("in the %s mirror, %d game%s where only one side got a 'rush' verdict by 4:00, that side won %s" % (f.capitalize(), len(d_), "" if len(d_) == 1 else "s", ci(k_, len(d_)) if len(d_) else "-"))
    T["dd_scout_cost"] = "; ".join(lines_)

    # ------------------------------------------------------------------ what a bigger sample would decide
    def n_half(p, h):
        """Smallest n whose Wilson 95% interval around a rate of p has a half-width of h or less."""
        for n in range(20, 60001, 10):
            lo, hi = wilson(p * n, n)
            if (hi - lo) / 2.0 <= h:
                return n
        return None

    def n_vs_half(p):
        """Games needed to tell a true rate of p from 50% (two-sided 5%, 80% power)."""
        d = abs(p - 0.5)
        return None if d < 0.01 else int(math.ceil(7.85 * max(p * (1 - p), 0.05 * 0.95) / (d * d)))

    def cap(n):
        return "more than 5,000" if n is None or n > 5000 else "%d" % n

    def capm(need, have):
        return cap(need) + (" (met)" if need is not None and have >= need else "")

    def prow(question, k, n, what):
        p = k / n
        lo, hi = wilson(k, n)
        return {"question": question, "now": "%s [%s-%s] in %d %s" % (pct(p), pct(lo), pct(hi), n, what), "half-width now": "%.1f pts" % (50 * (hi - lo)),
                "CI excludes 50%": "yes" if (lo > 0.5 or hi < 0.5) else "no", "games for +-5 pts": capm(n_half(p, 0.05), n), "games for +-3 pts": capm(n_half(p, 0.03), n),
                "games to tell it from 50% (80% power)": capm(n_vs_half(p), n)}

    rows = []
    cw = games[games.pair == "crown-clockwork"]
    rows.append(prow("Crown against Clockwork: how lopsided?", (cw.winner_faction == "crown").sum() + 0.5 * (cw.winner_team < 0).sum(), len(cw), "games (score)"))
    dec = games[games.winner_team >= 0]
    rows.append(prow("Does the first spawn win more often (all matchups)?", int((dec.winner_team == 0).sum()), len(dec), "decided games"))
    bc = sides[(sides.faction == "brood") & (sides.opp != "brood")]
    kb, nb_ = int((bc.won == 1).sum()), len(bc)
    rows.append({"question": "Can the Brood beat the other two at all?", "now": "%d wins in %d side-games (95%% upper bound %s)" % (kb, nb_, pct(wilson(kb, nb_)[1])),
                 "half-width now": "-", "CI excludes 50%": "yes", "games for +-5 pts": "0 more", "games for +-3 pts": "0 more", "games to tell it from 50% (80% power)": "0 more"})
    for f in FACS:
        for plan in ("rush", "xrush", "timing"):
            x = sides[(sides.faction == f) & (sides.opp == f) & (sides.plan_start == plan) & (sides.opp_plan == "balanced")]
            if len(x) >= 8:
                rows.append(prow("%s mirror: is the %s plan better or worse than Balanced?" % (f, plan), float(x.score.sum()), len(x), "side-games (score)"))
    mmx = games[(games.a == games.b) & (games.winner_team >= 0)]
    per_map = mmx.groupby("map").size()
    nmed = int(per_map.median())
    hw = 50 * (wilson(nmed / 2, nmed)[1] - wilson(nmed / 2, nmed)[0])
    rows.append({"question": "Does one map favour one spawn by 15 points (65:35)?", "now": "%d to %d decided mirror games per map (median %d)" % (per_map.min(), per_map.max(), nmed),
                 "half-width now": "%.0f pts per map" % hw, "CI excludes 50%": "-", "games for +-5 pts": "-", "games for +-3 pts": "-",
                 "games to tell it from 50% (80% power)": "%s per map" % cap(int(math.ceil(7.85 * 0.65 * 0.35 / (0.15 ** 2))))})
    T["dd_power"] = md(pd.DataFrame(rows))
    json.dump(T, open(a.out, "w"), indent=1)
    print("deepdive: %d dd tables" % sum(1 for k in T if k.startswith("dd_")))


if __name__ == "__main__":
    main()
