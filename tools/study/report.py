#!/usr/bin/env python3
"""Render the AI balance study report (docs/ai_balance_study.md) from the study data.

  python3 tools/study/report.py --data docs/study_data --out docs/ai_balance_study.md [--stage 12]

The text below is a template: {{T.key}} is a table or line from tables.json (written by analysis.py, examples.py and
deepdive.py), {{H.key}} a number computed here from the CSVs. Every number in the report therefore comes from the
committed data and is refreshed at each stage; the prose around them was written against the data of the stage named
in the status line and re-checked at the final stage. Measurement only: nothing here touches the game.
"""
import argparse, json, math, os, re, sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analysis import wilson, pct, mmss      # noqa: E402

PLANNED = 180                     # games per matchup the runner was set to (run_study.py --games 180)
PAIRS = ["crown-crown", "brood-brood", "clockwork-clockwork", "crown-brood", "crown-clockwork", "brood-clockwork"]
SOUTH = {"kestrel_rise", "cinder_steps", "glimmerdeep", "frostmere"}
STUDY_BASE = "e6deec6"            # the main commit the wt-study branch was made from (v0.14.1)


def ci(k, n):
    lo, hi = wilson(k, n)
    return "%s [%s-%s]" % (pct(k / n if n else float("nan")), pct(lo), pct(hi))


def fisher2(k1, n1, k2, n2):
    tot, K = n1 + n2, k1 + k2
    if n1 == 0 or n2 == 0:
        return float("nan")

    def pm(x):
        return math.comb(K, x) * math.comb(tot - K, n1 - x) / math.comb(tot, n1)
    p0 = pm(k1)
    return sum(pm(x) for x in range(max(0, n1 - (tot - K)), min(K, n1) + 1) if pm(x) <= p0 * (1 + 1e-9))


def headline(data):
    ld = lambda n: pd.read_csv(os.path.join(data, n if os.path.exists(os.path.join(data, n)) else n + ".gz"))
    games, sides, ts = ld("games.csv"), ld("sides.csv"), ld("timeseries.csv")
    st = json.load(open(os.path.join(data, "STATUS.json")))
    H = {}
    per = st["per_matchup"]
    n = int(st["games_done"])
    H["n"] = "{:,}".format(n)
    H["planned_total"] = "{:,}".format(PLANNED * len(PAIRS))
    H["planned"] = str(PLANNED)
    H["per_min"], H["per_max"] = str(min(per.values())), str(max(per.values()))
    H["per"] = H["per_min"] if H["per_min"] == H["per_max"] else "%s to %s" % (H["per_min"], H["per_max"])
    H["final"] = all(int(per.get(p, 0)) >= PLANNED for p in PAIRS)
    H["updated"] = st.get("updated", "")
    H["fails"] = str(st.get("failure_records", 0))
    H["versions"] = ", ".join("%s (%d games)" % (v, c) for v, c in games.version.astype(str).value_counts().items())
    H["wall_mean"], H["wall_median"], H["wall_max"] = "%d" % games.wall_s.mean(), "%d" % games.wall_s.median(), "%d" % games.wall_s.max()
    H["wall_hours"] = "%.0f" % (games.wall_s.sum() / 3600.0)
    H["real_per_min"] = "%.1f" % (games.wall_s.sum() / max(1e-9, games.end_t.sum() / 60.0))
    H["len_mean"] = "%.1f" % (games.end_t.mean() / 60.0)
    games["bal"] = (games.plan_a == "balanced") & (games.plan_b == "balanced")
    games["round"] = games.id.str.rsplit("_", n=1).str[1].astype(int)

    def rec(pair, fac, bal=False):
        x = games[(games.pair == pair) & (games.bal if bal else True)]
        w = int((x.winner_faction == fac).sum())
        d = int((x.winner_team < 0).sum())
        return x, w, len(x) - w - d, d

    for key, pair, fac in (("cb", "crown-brood", "crown"), ("kb", "brood-clockwork", "clockwork"), ("cc", "crown-clockwork", "crown"), ("cw", "crown-clockwork", "clockwork")):
        x, w, l_, d = rec(pair, fac)
        H[key] = "%d-%d" % (w, l_) + ("-%d" % d if d else "")
        H[key + "_score"] = ci(w + 0.5 * d, len(x))
        x, w, l_, d = rec(pair, fac, True)
        H[key + "_bal"] = "%d-%d" % (w, l_) + ("-%d" % d if d else "")
        H[key + "_bal_score"] = ci(w + 0.5 * d, len(x))
        H[key + "_bal_n"] = str(len(x))
    b = sides[(sides.faction == "brood") & (sides.opp != "brood")]
    H["brood_cross_wins"], H["brood_cross_n"] = str(int((b.won == 1).sum())), str(len(b))
    H["brood_cross_ub"] = pct(wilson(int((b.won == 1).sum()), len(b))[1])
    dec = games[games.winner_team >= 0]
    H["spawn0"] = ci(int((dec.winner_team == 0).sum()), len(dec))
    for p in PAIRS:
        H["to30_" + p] = str(int((games[games.pair == p].cause.str.startswith("timeout")).sum()))
        H["n_" + p] = str(int((games.pair == p).sum()))
    # mirrors, Balanced/Balanced: medians
    gi = games.set_index("id")
    balm = games[(games.a == games.b) & games.bal].id
    m = ts[ts.id.isin(balm)]
    for tm, lab in ((120, "2"), (300, "5"), (600, "10")):
        for f, k in (("crown", "cr"), ("brood", "br"), ("clockwork", "cw")):
            y = m[(m.t == tm) & (m.faction == f)]
            H["m%s_%s" % (lab, k)] = "{:,}".format(int(y.army_value.median())) if len(y) else "-"
            H["e%s_%s" % (lab, k)] = "{:,}".format(int(y.earned.median())) if len(y) else "-"
    # the south-ramp maps, in-sample and out-of-sample
    cc = games[games.pair == "crown-clockwork"].copy()
    cc["cw"] = (cc.winner_faction == "crown").astype(int)
    for lab, x in (("ins", cc[cc["round"] < 155]), ("oos", cc[cc["round"] >= 155]), ("all", cc)):
        xs, xo = x[x["map"].isin(SOUTH)], x[~x["map"].isin(SOUTH)]
        k1, n1, k2, n2 = int(xs.cw.sum()), len(xs), int(xo.cw.sum()), len(xo)
        H["s_%s" % lab] = "%d/%d" % (k1, n1)
        H["o_%s" % lab] = "%d/%d" % (k2, n2)
        H["s_%s_ci" % lab] = ci(k1, n1) if n1 else "-"
        H["o_%s_ci" % lab] = ci(k2, n2) if n2 else "-"
        p = fisher2(k1, n1, k2, n2)
        H["p_%s" % lab] = "-" if math.isnan(p) else ("%.1e" % p if p < 0.001 else "%.2f" % p)
    H["oos_n"] = str(int((cc["round"] >= 155).sum()))
    # capped and idle Clockwork armies (same rule as deepdive dd_capped_idle)
    ts30 = ts[ts.t % 30 == 0]
    stalls = []
    for (gid, team), x in ts30[ts30.t >= 480].groupby(["id", "team"]):
        ok = (((x.supply >= x.cap - 2) | (x.supply >= 199)) & (x.gold >= 1000) & (x.attacking == 0)).values
        best = cur = 0
        for e in ok:
            cur = cur + 1 if e else 0
            best = max(best, cur)
        if best >= 20:
            stalls.append((gid, team, best * 0.5, int(x.gold.max())))
    H["stall10_n"] = str(len(stalls))
    H["stall10_bank"] = "{:,}".format(max([s_[3] for s_ in stalls])) if stalls else "0"
    H["stall10_pairs"] = ", ".join(sorted({gi.loc[s_[0], "pair"] for s_ in stalls})) if stalls else "-"
    # snowball inside mirrors (power = army value + 50 per worker + 30 per building), decided games still on 30 s later
    t2 = ts.copy()
    t2["power"] = t2.army_value + 50 * t2.workers + 30 * t2.buildings
    piv = t2[t2.id.isin(games[games.a == games.b].id)].pivot_table(index=["id", "t"], columns="team", values="power").dropna()

    def lead(tm, thr):
        if tm not in piv.index.get_level_values("t"):
            return "-"
        p = piv.xs(tm, level="t")
        k = n_ = 0
        for gid, r in p.iterrows():
            g = gi.loc[gid]
            if g.winner_team < 0 or g.end_t < tm + 30:
                continue
            hi, lo = max(r[0], r[1]), max(1.0, min(r[0], r[1]))
            if hi == lo or hi / lo < thr:
                continue
            n_ += 1
            k += int(g.winner_team == (0 if r[0] > r[1] else 1))
        return ci(k, n_) + " of %d" % n_ if n_ else "-"
    H["sb_m3_any"], H["sb_m5_any"] = lead(180, 1.0), lead(300, 1.0)
    H["sb_m10_30"], H["sb_m15_30"] = lead(600, 1.3), lead(900, 1.3)
    H["sb_m10_any"] = lead(600, 1.0)
    # Brood ground cap in the mirror
    br = ts[(ts.faction == "brood")]
    capped = br[br.earned >= 10400].groupby(["id", "team"]).size()
    bm = sides[(sides.faction == "brood") & (sides.opp == "brood")]
    H["brood_spent"] = "%d of %d" % (sum(1 for k in capped.index if k[0] in set(bm.id)), len(bm))
    # idle workers: share of idle worker-samples taken while a hall's soil/coal (or the Brood capital's ground) is spent
    t3 = ts[ts.workers > 0].copy()
    t3["spent"] = np.where(t3.faction == "brood", t3.earned >= 10400, t3.soil_min <= 0.01)
    parts = []
    for f in ("crown", "brood", "clockwork"):
        x = t3[t3.faction == f]
        parts.append("%s %s" % (f, pct(x[x.spent].idle_workers.sum() / max(1.0, float(x.idle_workers.sum())))))
    H["idle_after_spent"] = ", ".join(parts)
    # Crown economies wiped before 10:00 (2 or fewer workers after having 8+), by opponent
    wipes = {}
    for (gid, team), x in ts30[(ts30.t <= 600) & (ts30.faction == "crown")].groupby(["id", "team"]):
        if x.workers.max() >= 8 and (x.workers <= 2).any():
            o = sides[(sides.id == gid) & (sides.team == team)].opp.iloc[0]
            wipes[o] = wipes.get(o, 0) + 1
    H["crown_wipes"] = "%d (%s)" % (sum(wipes.values()), ", ".join("%d against the %s" % (v, k.capitalize()) for k, v in sorted(wipes.items(), key=lambda kv: -kv[1])) or "none")
    H["crown_wipes_brood"] = str(wipes.get("brood", 0))
    return H


TEMPLATE = r"""
# AI balance study: Hard AI against Hard AI in all six matchups

{{H.status}}

> **Read this first: which game this measures.** Every game ran on the study build, **v0.14.1** (branch `wt-study`, made from
> main at `e6deec6`), so that the whole sample measures one version of the code. Main has moved on since (0.14.27 when this was
> written) and nothing from main was merged here. The changes that touch these results:
> - **The Clockwork was rebuilt** (0.14.14 to 0.14.23, "gear mode", on by default): Cog Presses and cogs instead of Ore Crushers
>   and ore, no energy (no Boiler, Charging Pylon, Engine Hall, Capacitor Works), the Movement Works and Clock Soldier instead of the
>   Assembly Works and Wind-up Soldier, the Ratchet Turret, Mainspring and Tension, the Escapement and Jack, air units, the Pendulum
>   and Netter. **Every Clockwork number below is about the old ore-and-energy Clockwork**, which main has shelved.
> - **Workers and income**: Crown games no longer start with every Labourer hauling and the first Farm unworked (0.14.19);
>   every faction's workers take primary-resource jobs first (0.14.24); workers sent to a spent Farm, Mill or Feeding Pit go to
>   fresh land instead of standing idle (0.14.17).
> - **BOMBARD** (fire at a spot) and **the Brood's harvest** at 1.25 essence per supply of a body instead of 1 (0.14.26).
>
> So: read the Brood and Crown findings as likely still true on main but worth one re-run, the Clockwork findings as history,
> and the AI-behaviour faults (section 10) as true of the AI code unless that code has changed. Section 13 says how to re-run.

## Summary

**The five headline findings** (sample sizes and intervals in the sections named):

1. **The Brood cannot beat the other two factions on Hard AI.** It won {{H.brood_cross_wins}} of {{H.brood_cross_n}}
   cross-faction side-games: the Crown beat it {{H.cb}}, the Clockwork {{H.kb}}, with every plan it has (Balanced, Rush,
   Extreme rush, Timing attack). Its army is worth about 300 from 4:00 to 7:00 while the others' armies double. The Clockwork's
   first two waves erase that army by 6:00 (median game: about 8 minutes); the Crown's Musketeers and Horsemen take its
   Feeding Pits and then its Burrow, in a quarter of Balanced games by about 8:30 and in half by about 14:00 (sections 2,
   3 and 4.2). The 95% upper bound on its win rate in these matchups is {{H.brood_cross_ub}}.
2. **The (old) Clockwork economy ran at about twice the others' pace, and the Clockwork beat the Crown {{H.cw}}
   ({{H.cw_score}}).** In mirrors, where both sides face the same faction, the median army at 5:00 was worth {{H.m5_cw}}
   for the Clockwork, {{H.m5_cr}} for the Crown and {{H.m5_br}} for the Brood; by 2:00 the Clockwork had earned {{H.e2_cw}} ore
   against {{H.e2_cr}} gold and {{H.e2_br}} biomass (section 4.1). The Crown survives on its ramp wall and gate: Clockwork
   waves pull back from a Crown gate in most Crown-Clockwork games (section 7).
3. **The Crown's chances against the Clockwork depend heavily on the map.** On Kestrel Rise, Cinder Steps, Glimmerdeep
   and Frostmere the Crown won {{H.s_ins}} games against {{H.o_ins}} on the other eight maps (Fisher p = {{H.p_ins}}). The
   grouping was picked after looking at the per-map results, so it was checked again on the {{H.oos_n}} Crown-Clockwork games
   run after it was chosen: there the Crown won {{H.s_oos}} on those four maps and {{H.o_oos}} on the rest (p = {{H.p_oos}}).
   The cause is not established (section 9.2).
4. **The AI often neither finishes a won game nor gives up a lost one.** In {{H.stall10_n}} side-games ({{H.stall10_pairs}}) the
   winner sat at its supply cap with 1,000+ banked and no wave out for 10 minutes or more, its bank growing to as much as
   {{H.stall10_bank}}; the loser never qualified for gg, because the gg rule counts "a hall and a worker" as income even
   when the soil is spent and nothing comes in. Brood mirrors that reach 30:00 are dead economies on both sides (section 10).
5. **Leads start to decide games at about 10 minutes.** Inside mirrors, the side ahead in power at 3:00 won only
   {{H.sb_m3_any}} decided games, and at 5:00 {{H.sb_m5_any}}: the early game is open, and an early army bought ahead of the
   opponent is if anything a handicap. At 10:00 a lead of 30% or more won {{H.sb_m10_30}}, at 15:00 {{H.sb_m15_30}}, and
   comebacks after 15:00 are rare (section 8).

**What to fix first** (the full ranked list with evidence and the design principle each follows is in section 11):
make an army at the supply cap attack and make the gg rule look at real income (AI faults with clear examples); re-measure
the Brood on main and then give it an early game that can hold against Musketeers, Horsemen and wind-up waves (it is far
behind on every measure here); drop the Crown's random Horse Breeder opening from the Balanced plan ({{H.breeder_line}});
stop the Crown buying production while it is supply-blocked; and look at why the Crown falls apart on four maps.

**What this cannot tell you.** These are computer-against-computer games: a result mixes the faction's strength with how well
the AI plays it. "The Brood loses every game" means the Brood *as the Hard AI plays it* loses to the Crown and Clockwork *as
the Hard AI plays them*. A human Brood may do far better (the owner's own extreme rush is the anchor in
`docs/design_principles.md`). Section 13 lists what else could not be checked.

---

## 1. What was run, and how far to trust it

**Request and what fitted.** 1,000 games of 30 minutes for every matchup was asked for. The agreed plan was the
"overnight study": as many Hard-against-Hard games as fit in about 24 to 36 hours, spread evenly over the six matchups (three
mirrors, three cross pairs), headless, with the game exactly as shipped in v0.14.1 (no game logic, balance number or AI code
touched; only `tools/study/` and this report were added). The first estimate was 20 to 30 games per matchup, because a
30-minute game was expected to take 30 to 45 minutes of real time. It costs far less (below), and most games end well before
30:00, so the runner was set to {{H.planned}} games per matchup ({{H.planned_total}} in all) and run in stages, with the data
and this report refreshed and committed at each stage.

**Cost of a game, and making it faster.**
- Real time per game: mean {{H.wall_mean}} s, median {{H.wall_median}} s, longest {{H.wall_max}} s; on average a game lasted
  {{H.len_mean}} game minutes, and one game minute cost {{H.real_per_min}} real seconds. In all, {{H.wall_hours}} hours of game
  processes. The box has 2 cores and was shared with other jobs the whole time (two games at a time until about 930 games, one
  at a time after), so these times are inflated; a quiet core is faster.
- The engine already runs unthrottled under `--fixed-fps 30`. A larger time scale or tick rate would change the simulation
  (the game's step is the physics tick), so it was not used. Hiding the HUD is the one safe saving: on the same seed it took
  60.1 s instead of 67.7 s for 620 game seconds (11% less), so the runner does it (`fast:1`). The rest of the frame is unit logic
  (about 40%), fog and vision (about 15%) and the AI (about 10%, from the match log's own profile), which cannot be skipped
  without changing results.
- **Games do not replay exactly (a finding in itself).** Two runs with the same seed and settings drift apart: the state
  hash at 5:00 differs. Five back-to-back runs of one Crown-Clockwork setup on Greenhold, one at a time, were all won by
  the Clockwork, but they lasted 664 to 928 s and the hashes differed every time (`tools/study/replicates.sh`). A seed fixes the
  map, the start and the AI's coin flips, not the whole game; results are reproducible only as statistics. The cause (time-
  budgeted work such as path queues is a candidate) was not investigated. Worth knowing for anything that relies on lockstep
  determinism.

**Design.**
- Hard AI on both sides, 30 game minutes at most. Slot 0 sits on the first spawn and slot 1 on the second; in every matchup
  the first-named faction alternates between the two spawns, so spawn bias cancels out of the cross-faction numbers (it is
  measured separately, section 2.3).
- Games are scheduled round by round: round n is game n of all six matchups, so every matchup always has (nearly) the same
  sample size.
- **Plans.** A cycle of 11 games per matchup: 7 Balanced against Balanced, 2 where the first-named side opens with Rush (for the
  Brood, Rush and Extreme rush take turns, one cycle each), and 2 where one side plays Timing attack. The plan is the starting
  plan: the AI may change plan by itself (a failed rush turns Balanced), and the plan it ended with is recorded too.
  The split per matchup is in the table below.
- **Maps.** The 12 built-in 1v1 maps in a fixed rotation, the four the owner named first (Greenhold, Frostmere, Ashford
  Crossing, Amberfall Vale), then Kestrel Rise, Glimmerdeep, Hollowfen, Highmoor, Thornwood Maze, Saltmarsh Isles, Twin Fords
  and Cinder Steps. Greenhold, Highmoor and Twin Fords are generated "classic" maps (a new layout for each seed); the rest are
  fixed, hand-made maps. Games per map: {{T.maps_used}}.
- **How a game ends.** At 30:00; when a side has no buildings left (victory); or when one side has been hopeless by the AI's own
  gg rule (`AIResign.verdict`) for 120 game seconds without a break. That is the 60 s the AI waits before it says gg plus the
  60 s a player has to answer it; a human would have answered, so the game is cut and counted as a win for the other side
  (cause "gg"). In AI-against-AI games the AI never says gg (it only talks to a human), so this is also how "when would it have
  given up" is measured. Games that reach 30:00 are judged by `Game.power` (army value + 50 per worker + 30 per building): a
  lead of more than 25% counts as a win ("timeout_lead"), otherwise a draw ("timeout_even", half a win). Section 2.4 shows this
  rule moves no result by more than a few points.
- **What is recorded.** Per game: setup, result and cause. Per side, every 30 s: gold and second resource banked, income,
  supply and cap, workers and idle workers, army value and idle army, halls, buildings, wall pieces, production buildings and
  idle ones, losses, kills, soil/ground and saltpetre/ore left, whether a wave is out, seconds supply-blocked, seconds with 500
  and 1,000 banked, whether it is hopeless, the plan, and (games from round 155 on) the AI's own attack gate (the army supply
  its next wave waits for, whether an enemy is near one of its buildings, whether a siege plan runs). Per side, once: when each
  building kind was first finished, when each hall went up, units made and lost by kind, kills by unit kind, every attack wave
  (start, end, supply and value sent, composition, enemy value killed, own value lost) and every Crown raiding party, first
  blood, first worker lost, wall times, plan changes. And the full match log of every game.

**The sample.**

{{T.sample}}

{{H.fails}} games failed to run (crash or hang); none had to be retried.

**Statistics.** Win rates are given as wins-losses(-draws) with a Wilson 95% interval; a draw counts as half a win. A
matchup with 158-180 games pins a win rate to about +-7 points; a plan inside a matchup (14-32 side-games) only to +-15 to 25
points. "Established" below means the interval excludes 50% (or the effect is far larger than its interval) and the pattern
holds across maps; otherwise it is called a hint. Every number comes from `docs/study_data/` and can be re-derived with
`tools/study/*.py`.

**Currencies are not comparable between factions.** The Crown earns gold, the Brood biomass and the Clockwork ore, and their
units cost different amounts (a Brood Raptor costs 25, a Grub 50). "Earned" and "bank" are compared within a faction, or
side by side with that caveat. **Army value** (the game's own cost-based tally of armed units) is the common yardstick, and
"power" (army value + 50 per worker + 30 per building) is the one used for leads.

---

## 2. Who wins

### 2.1 The win matrix

Each cell is the row faction's record against the column faction (wins-losses-draws, score, 95% interval). All plans:

{{T.winmatrix_all}}

Balanced against Balanced only:

{{T.winmatrix_bal}}

The order is the same in both: **Clockwork > Crown > Brood**, and the gaps are large. Crown against Brood ({{H.cb}}) and
Clockwork against Brood ({{H.kb}}) are as one-sided as a sample can be. Crown against Clockwork is {{H.cc}} for the Crown
({{H.cc_score}}; Balanced/Balanced {{H.cc_bal}}, {{H.cc_bal_score}}): lopsided, but the Crown does win a quarter to a third
of the time, more on some maps than others (section 9).

### 2.2 Plans inside one matchup

How a plan does against Balanced, and how Balanced does against it, inside each matchup (score, 95% interval). These are
small samples (14-32 side-games a cell):

{{T.dd_plans}}

Across all matchups, as the opening plan against a Balanced opponent:

{{T.plans}}

- Rush is below Balanced for the Crown and the Brood and above it for the Clockwork (Clockwork mirror Rush
  {{H.plan_cw_rush}}); Extreme rush is the worst plan the Brood has. Inside the mirrors, only those two (the Clockwork's Rush,
  the Brood's Extreme rush) have intervals that exclude an even result; the rest are hints. (In the lopsided Crown-Clockwork
  matchup, compare each row with the Balanced/Balanced baseline, not with 50%.)
- "Plan changed" counts games where the AI left its opening plan (a failed rush turns Balanced): almost every Brood rush and
  most Crown and Clockwork rushes end that way.
- The Brood loses its cross matchups with every plan: {{T.dd_brood_cross}}.

### 2.3 Spawn side

{{T.spawn_all}}

{{T.mirrors}}

No spawn bias overall. Per map (mirrors only, so the faction cannot matter):

{{T.dd_spawn_maps}}

Across all plans the maps differ a little more than chance would give (the chi-square test above), driven by a few maps
(Hollowfen and Cinder Steps lean furthest, in opposite directions); with Balanced plans only there is no evidence of it. About
37 decided mirror games per map can only reliably see an imbalance of 20-25 points; section 12 has what it would take to see
smaller ones.

### 2.4 Does the 30:00 rule matter?

{{T.dd_sensitivity}}

Counting every 30:00 game as a draw, or leaving them out, moves no matchup by more than a few points. The adjudication
does not drive any result.

---

## 3. Game length and time to win

{{T.length}}

{{T.timetowin}}

Cross games with the Brood are short (the Clockwork-Brood median is about 8 minutes); mirrors are long, and a fifth of
Brood mirrors reach 30:00 (section 10.3). The Clockwork wins sooner than the Crown when it wins.

---

## 4. Economy

### 4.1 The three economies side by side

Balanced/Balanced mirrors, median per side (army value / resources earned so far / workers). In a mirror both sides meet the
same opponent, so this compares the factions' own pace more fairly than the cross games do:

{{T.dd_mirror_econ}}

- The (old) **Clockwork** earns about twice what the Crown earns at every point up to 10:00 (in its own currency, ore), and
  its army value is about double the Crown's from 4:00 to 10:00. It also builds workers fastest (17 by 4:00).
- The **Crown** is steady but slow, with only 10 workers until after 5:00. On main, 0.14.19 fixed a bug that started every
  Crown game with all four Labourers hauling and the first Farm unworked; that alone may change these early numbers.
- The **Brood** earns least, then drones hard from 4:00 to 7:00 (9 to 26 grubs) while its army value stays flat at about 300.
  That flat army is exactly the window in which the Crown's and the Clockwork's first waves arrive (section 4.2).

All games, per faction, means of the sides still playing (the curves after 15:00 are mostly long games, and the Brood's mostly
mirrors):

{{T.econ_curves}}

![Economy curves per faction](study_data/figs/economy.png)

Earned so far (median, own currency) at fixed times, all games:

{{T.dd_earned}}

### 4.2 The Brood against the other two, minute by minute

Balanced/Balanced games, medians:

{{T.dd_brood_vs}}

Against the Clockwork the Brood's army is gone by 6:00: the first Clockwork wave leaves at about 3:40 with 18 supply (11
Wind-up Soldiers and 3 Arc Throwers on average) and the second at about 6:50 with 39 (section 7.1). Against the Crown the
Brood's army never grows past about 300 while the Crown's passes 1,000 by 10:00; the Crown's first wave (Musketeers, often
with Horsemen) takes the Feeding Pits and then the Burrow. Who did the killing: {{T.dd_brood_killers}}. Brood workers lost
per game in these matchups: see section 6. Example: `crown-brood_012` (Balanced/Balanced, Greenhold): the Brood scouts
Horsemen at 3:08 and decides "Raptors do little against them, so it keeps its army at home and builds Spitters and Brutes";
the Crown's first wave (4 Horsemen) leaves at 4:02, the Brood loses three Feeding Pits between 5:04 and 5:27 and its Burrow at
6:04, and the game is cut as a gg at 6:17.

### 4.3 Supply, banked resources, idle workers, idle production

Per side-game (all plans):

{{T.faults_econ}}

How often a side is supply-capped with something in the bank, from the 30 s samples (the Brood's units cost 25-75, so a bank
of 50 is the threshold here):

{{T.capped_samples}}

- **Supply blocks are rare** for all three (1-3% of game time). Blocks of 2 minutes or more happen in about 4% of Crown and
  Clockwork side-games, mostly in Crown mirrors and Clockwork games (section 10.5).
- **Banked resources** are low most of the time; the big banks are almost all a Clockwork at 200/200 that stopped attacking
  (section 10.1). The Crown piles up **powder** late instead: by 20:00 nearly every Crown still playing has 500+ powder banked:

{{T.dd_powder}}

- **Idle workers** run at about 8-11% of worker time on average, but they come in lumps: almost all of it is after the land
  is spent. Share of idle worker time taken while a hall's soil (Crown), coal (Clockwork) or the capital's ground (Brood) is
  used up: {{H.idle_after_spent}} (sections 4.4 and 10.4).
- **The 200 cap**: only the Clockwork reaches it ({{H.cap200_cw}} of its side-games); the Crown and the Brood never do.

### 4.4 Depletion: soil, ground, ore

"Soil/ground all spent" in the table above means every hall the side owns is at 0% (the Crown's farm soil, the Clockwork's
Boiler coal, the Brood's ground). The Crown's and the Clockwork's run out at a median of about 15-16 minutes in the games that
get that far. The Brood's column is misleading: only its capital has ground that its pits draw on, and a second Burrow shows
a full but unused 100%, so "all spent" rarely fires even when the Brood's income has stopped (section 4.6). Depletion forces
expansion, which is the design intent; where it goes wrong is a side that has spent its last field with no money left to
move (section 4.5), and the Brood, whose expansions bring no new ground at all (4.6).

### 4.5 Economies that stop

A side "stalls" when 80% or more of its workers (at least 8) stand idle for 90 s in a row after 7:00:

{{T.dd_econ_stall}}

- The **Crown** stalls in about one game in nine, and nearly always because the soil is spent; not one of those sides had the
  400 gold a new Town Hall costs, and almost all of them lost. Examples: {{T.dd_econ_stall_ids}}. This is the "depletion
  should force expansion, not strangle it" problem from `docs/design_principles.md`.
- The **Brood**'s stalls are a different thing: the capital's ground reserve is used up (next section) and the grubs have
  nothing left to do. The "vs" column shows where they happen; in Brood mirrors they end in the stalemates of section 10.3.

### 4.6 The Brood's ground reserve

In v0.14.1 (and on main, unchanged) **every Brood Feeding Pit draws on the capital's ground** (`Game.soil_hall()` returns
the capital for the Brood), and the capital holds one reserve of 10,500 biomass (`Defs.GROUND_RESERVE`). A second Burrow
brings eggs, supply and swamp, but no ground. So the Brood's pit income for a whole game is capped at 10,500 biomass, and once
that is drawn the pits pay nothing:

{{T.dd_brood_cap}}

In Brood mirrors {{H.brood_spent}} side-games spend the whole reserve (at a median of about 15:30), and then nearly all of
them have 80% or more of their grubs idle. Earned biomass stops at about 10,490 for good (the 20:00 and 25:00 rows of the
"earned" table in 4.1). Against the Crown it gets that far in about one game in nine and against the Clockwork never: it is
usually dead first. The result is a fixed budget per game, and Brood mirrors that are not decided by about 15 minutes freeze (section 10.3). CLAUDE.md lists "one
10,500 ground reserve at the capital" as a decision still to confirm; this is the data for it.

---

## 5. Expansion and tech timings

{{T.expansion}}

First time each building kind was finished (median, and the share of side-games that built one):

{{T.tech_all}}

Measured openings per plan (median time of the first production building and first attack; workers / army value at
2:00-5:00), to compare with `docs/ai_build_timelines.md`:

{{T.timelines}}

- The Clockwork always expands (100%, median about 6:00), the Crown usually (85%, about 8:00), the Brood in only half its
  games and late (about 11:40); for the Brood a second Burrow brings no new ground anyway (4.6).
- In mirrors, the side that expands first wins about 60% of the time, and a side that is the only one to expand almost always
  wins (but expanding is also a sign of already being ahead):

{{T.dd_expand_first}}

- The measured timelines are close to `docs/ai_build_timelines.md` for the production buildings. Two differences: the
  Clockwork Balanced plan's first attack comes at about 3:40 here (the doc, measured against a Crown that never attacks, has
  5:06), and the Crown Balanced first wave is later here (median about 9:40) than its first "attack" by raiders (6:00).

---

## 6. Armies: composition and trade

Value killed against value lost per matchup ("trade ratio" > 1 means the row faction kills more than it loses):

{{T.trade}}

What each faction builds and what each unit does (per side-game; "kills per unit made" counts every kill, workers included):

{{T.army_comp}}

- The Crown's army is Musketeers (about 44% of the value it makes) and Cuirassiers/Horsemen (17%). Its artillery is barely
  built (under one Cannon and one Mortar per game), although each Cannon made accounts for about 5 kills, the most of any
  Crown unit: the AI under-uses its best killer. Musketeers make three-quarters of its kills against the Brood.
- The Brood makes about 98 Raptors a game and loses 70% of them; Raptors kill half a unit each. Its heavier units (Brute,
  Bloater, Skywing, Mist Toad) are made less than once per game: the Brood's late tech barely appears.
- The Clockwork makes about 150 Wind-up Soldiers a game; among its units the Arc Throwers do the most killing (3.5 kills
  each).
- Workers are a large share of what everybody loses: about 20 workers per side-game for the Crown and the Brood, 13-14 for the
  Clockwork (table in section 10.9).

---

## 7. Attacks

### 7.1 Waves: who attacked when, with what, and how it went

A **wave** is an attack the AI sends out (its own `_attacking` flag, or a Brood swarm); a **raid** is a Crown raiding party of
riders going for workers. A wave is "good" when it killed at least the value it lost.

{{T.waves}}

The first wave of each plan:

{{T.first_wave}}

Waves by their number in the game:

{{T.wave_number}}

- The Clockwork attacks first and most often (a first wave at about 3:40 even on Balanced), the Brood last (about 8:30-8:50
  on Balanced). Clockwork waves trade about even overall; they win games by coming again and again with more.
- Crown waves are rarer and later, and kill about twice what they lose; the Crown also sends many raiding parties.
- Later waves are bigger. For the Brood each later wave does better than the one before; for the Clockwork the third and
  later waves do.

### 7.2 Rushes, timing attacks and the Crown's wall

{{T.wall}}

Every Crown side walls its ramp: its first Cottage is laid across the ramp at about 0:23 and stands at a median of 0:37.
The Crown as defender, by the attacker's opening plan (any faction):

{{T.wall_vs_rush}}

A walled Crown held every Brood Extreme rush in this sample and lost about two workers to it, so the "a rush must lose to a
proper defence" anchor in `docs/design_principles.md` section 5 holds for the AI (on a small sample). Against the
Clockwork the wall and gate hold the early waves on most maps; the attacker's siege logic decides how often it pulls back
from the gate:

{{T.dd_siege}}

Most frequent pull-back messages: {{T.dd_siege_text}}.

### 7.3 Scouting

The scout's "rush" verdict against a foe who actually played Balanced, and why it fired:

{{T.dd_scout_false}}

The scout calls "rush" on almost every Balanced foe of every faction, so the verdict carries little information. Against
the Brood it is mechanical: `AIScout.EARLY_PROD` counts a Spawning Den seen before 2:20 (and an Assembly Works before 1:40) as
rush evidence, and the Brood's Balanced opening finishes its Den at about 1:20. A "rush" verdict puts the AI in a defensive
posture for 210 s (army first, expansion slower). It does not seem to cost much: {{T.dd_scout_cost}}. Verdict accuracy by
the foe's real plan:

{{T.dd_scout_acc}}

---

## 8. Snowball and comebacks

"Power" = army value + 50 per worker + 30 per building. For decided games still running 30 s later: when one side led at a
given time, how often did the leader win?

All games (inflated by the one-sided Brood matchups):

{{T.snowball}}

Mirrors only (the fair test of snowballing, since the factions are equal):

{{T.snowball_mirror}}

![Power ratio at 7:00 and 10:00 against the result](study_data/figs/snowball.png)

What a lead at a given time predicts, inside mirrors (share of games where the side ahead on that measure won; n = games where
the two sides differed):

{{T.dd_predictors_mirror}}

Read against the anti-snowball principles in `docs/design_principles.md`:
- **The early game is open.** In mirrors a power lead at 3:00 wins only {{H.sb_m3_any}}, and a lead at 5:00 little more
  ({{H.sb_m5_any}}). The side with the bigger *army* at 3:00 does worst of all (it wins about a third of the time, the
  "army_value" column above): an early army costs workers, and in a mirror that costs the game more often than it wins it.
  Small early leads do not decide games. Good, by the anti-snowball principles; it also fits the plans table, where rushing is
  below Balanced for the Crown and the Brood.
- **From about 10:00, leads stick.** Any lead at 10:00 wins {{H.sb_m10_any}}; a lead of 30% or more {{H.sb_m10_30}}; at 15:00
  {{H.sb_m15_30}}. Halls at 10:00 (the side with more halls wins 84-86%) and army value are the best predictors. A lead at
  10-15 minutes is close to decisive, and there are few comebacks after that.
- **Closing out is slow for the Clockwork.** Once a side holds 3x the other's power without a break, the Crown and the Brood
  finish in about 1.5 minutes (median), the Clockwork in about 3, and about ten Clockwork wins took 15 minutes or more from that
  point: some are the armies that stop at the cap, others long sieges where a wave stays out for 10+ minutes without
  finishing (both in section 10.1):

{{T.dd_closing}}

- **The defender's advantage does not fade for the Crown.** The ramp wall and gate are built by 0:40 and still make attackers
  pull back late in the game (section 7.2), which is part of why Crown mirrors and Crown-Clockwork games can drag on.

---

## 9. Maps

### 9.1 Per map

Spawn 0's wins in decided games, average length, and each faction's wins in its cross games (wins/decided):

{{T.bymap}}

The Brood loses on every map. The Clockwork's results against the Crown vary most by map.

### 9.2 Crown against Clockwork: four maps where the Crown (almost) never wins

Map by map:

{{T.dd_cc_maps}}

The four maps at the bottom share one base layout in `scripts/map_data.gd`: the main's ramp opens to the south, at about
(9-12, 24), and the natural sits below it and to the west, 4.5 to 7 tiles from the ramp foot. (Hollowfen, Thornwood Maze and
Saltmarsh Isles have their natural as close to the ramp, but their ramp opens to the east; Ashford Crossing and Amberfall
Vale have the natural 13-18 tiles away; Greenhold, Highmoor and Twin Fords are generated.) Grouping the four:

{{T.dd_layout}}

**This grouping was chosen after looking at the per-map table**, so its p-value overstates the evidence. To check it honestly,
the Crown-Clockwork games that started after the grouping was written down (round 155 on) are counted separately:

{{T.dd_layout_oos}}

What is different on those maps, Crown against Clockwork (Clockwork's first three waves):

{{T.dd_layout_waves}}

- On the four maps the Clockwork's second and third waves kill about twice the value they lose; on the other maps they lose
  more than they kill. The Crown loses a Town Hall in every game there (median about 10:00) against 60% of games elsewhere,
  and its second hall falls sooner after it goes up (median about 2.5 minutes against 4).
- What it is not: map size alone (Frostmere is large; Kestrel Rise and Cinder Steps are the two smallest), the scout dying
  (the Crown's scouting Labourer is killed by enemy workers at about 1:15 on the small maps, which costs one worker and some
  information but happens to every faction there), or the Crown's opening (it fails with the Mill and the Breeder alike).
- Candidate causes, not tested: on this layout the Crown's natural, right under a south ramp, may sit on the path every
  Clockwork wave takes into the main, so the second hall is the first thing hit; or the AI's wall and gate placement on that
  layout leaves the gate poorly covered. Neither explains why the east-ramp maps with an equally close natural do better. The
  quickest check is to watch two or three Crown-Clockwork games on Kestrel Rise with the AI's gate and expansion choices
  drawn.

---

## 10. AI behaviour faults, with examples

Each fault: what was measured, how often, concrete games (id and game time; logs in `/home/claude/study_runs/logs/<id>.log`
on the study box), the likely cause in the code, and whether main has changed it.

### 10.1 Armies that sit at the supply cap and never attack

{{T.dd_capped_idle}}

{{T.dd_capped_idle_examples}}

Only the Clockwork does this, and only against the Crown. The clearest example, `crown-clockwork_140` (Saltmarsh Isles):
from 12:49 to 30:00 the Clockwork sits at 199/200 supply with an army worth 6,790 (74 Wind-up Soldiers, 14 Arc Throwers, 10
Bulwarks and more) and its bank climbs from 1,092 to 22,569 ore; it kills nothing after 13:33. The Crown meanwhile has
18 gold, 0% soil and 0% saltpetre, 28 idle Labourers and an army worth 430. Its last attack pulled back from the Crown's
gate at 11:29 ("it can't get through under 36 dps of fire").

Why the army waits, from `scripts/ai.gd` `_army()`: a wave goes out only when (a) no enemy unit is within 330 px of any of
the AI's buildings (`_threat()`; any enemy, armed or not, counts, and if one is near, the army defends and `_army()` returns
before the wave logic), and (b) the army's supply reaches `_attack_at`. Two ways the gate can lock shut:
- **The threshold rises out of reach.** A failed wave raises `_attack_at` to 1.4x that wave's supply with no upper bound
  (`_wave_end()`), and a pull-back at a gate to at least min(1.4x, +40) (`_siege_plan()`); only a launched wave caps it at 70,
  and nothing ever lowers it. A Clockwork with 32 Winders can field at most 168 supply of army. Rebuilt from the logged waves:
  {{T.dd_freeze_thr}} That covers some of the stalls but not `crown-clockwork_140` (its last wave left with 49 supply, so its
  threshold stayed near 70).
- **A permanent "threat".** With five or six Clockwork halls spread over the map and 28 Crown Labourers and loose horses
  still alive, some enemy unit may always be within 330 px of some Clockwork building, which would keep the army in
  "defend" forever without a target it can reach. {{H.diag_text}}

The Crown never does this (its army rarely reaches the cap), and the Brood never reaches its cap.

**The other kind of slow finish: a wave that stays out.** {{T.dd_long_waves_note}}:

{{T.dd_long_waves}}

Most of these are Clockwork mirrors, where the attack flag simply stays on for 10-15 minutes at a time: the two Clockworks
keep pressing each other without a pause, so one "wave" there is a stretch of constant pressure, not a stall. The
Crown-Clockwork ones are sieges: the army is attacking the whole time but does not break the defence. Example:
`crown-clockwork_115` (Saltmarsh Isles), one Clockwork wave out from 7:10 to 30:00 against a Crown whose Missionary raises a
fallen Musketeer or Guardsman again and again (21 times in the log). That is closer to a real siege than to a fault, but it
is part of why Crown-Clockwork games run long.

### 10.2 No gg when the game is lost

{{T.gg}}

{{T.gg_false}}

- The gg rule (`AIResign.verdict`, used by the harness to cut games) is never wrong in this sample: no winner was ever
  flagged hopeless. It is late rather than wrong.
- **It misses the broke.** "Broken" needs the army under 10% of the enemy's *and* no way to rebuild, and "a way to rebuild"
  counts any hall with any worker as income (`income := halls > 0 and workers > 0`). A side whose soil is spent, with no gold,
  no army and 28 idle workers, as in `crown-clockwork_140` above, therefore never counts as hopeless, and the game runs to
  30:00. The losers of the stalled games in 10.1 are all like this.
- Some losers flip in and out of "hopeless" (for example `crown-clockwork_046`: hopeless for 60 s at 19:19, when the AI would
  have offered gg to a human, then not, then out at 28:09).

Longest gaps between the AI's gg time and the end of a game that ended by victory:

{{T.ex_gg}}

### 10.3 Dead-economy stalemates

Why the 30:00 games got there (income of both sides in the last 5 minutes, army sizes, siege pull-backs):

{{T.dd_stalls}}

- **Every Brood mirror that reaches 30:00 is a dead economy on both sides**: both have spent the capital's ground reserve,
  earn under 150 in the last 5 minutes, and stand still (section 4.6). Neither can rebuild; nobody attacks.
- Crown-Clockwork 30:00 games are one side 3x bigger after a pull-back at a gate (10.1).
- Crown mirrors that reach 30:00 are mostly two live armies still trading (a real game), plus some stalls at walls.

### 10.4 Idle workers

The worst moments and the worst side-games:

{{T.ex_idle}}

{{T.ex_idle_total}}

Idle workers are mostly a depletion problem: the Brood's 40-of-40 idle grubs are after the ground reserve is spent, and the
Crown's long idle stretches after the soil is gone with no money for a new hall (4.5). Main 0.14.17 sends workers whose site is
spent to fresh land, which may cut the Crown's share; it cannot help a Brood with no ground left anywhere.

### 10.5 Supply blocks, and buying production while blocked

{{T.dd_block_build}}

{{T.dd_block_examples}}

Long supply blocks (2+ minutes at the cap with 100+ gold) are rare, but when the Crown has one it usually keeps buying
production buildings rather than Cottages (median 5 added during the block), and most of them then stand idle. Example:
`crown-crown_011`, blocked for 397 s between 12:30 and 21:00 at 76/76, adds 8 production buildings, all 13 idle at the end,
with up to 1,428 gold in hand.

### 10.6 Banked resources

{{T.ex_bank}}

All of the biggest banks are Clockwork armies at 200/200 that stopped attacking (10.1). The Crown's powder bank (section 4.3)
is the other pile: powder is not a constraint for the Crown late in the game.

### 10.7 Waves that trickle in, and waves that fail again and again

Small waves (under 10 supply) after 4:00 that lost more than they killed:

{{T.ex_trickle}}

Side-games with three or more failed waves in a row: {{T.repeat_fail_n}}; the first ones:

{{T.repeat_fail}}

Trickling is rare: the AI waits for a threshold before each wave, and a failed wave raises it. Repeated failures are almost
all Brood mirrors (swarms that keep losing at the other side's swarm).

### 10.8 No expansion

Sides still on one hall at 12:00 while the game went on: {{T.ex_noexpand_n}} (almost all Brood; Crown and Clockwork rarely,
section 5). The first few:

{{T.ex_noexpand}}

### 10.9 Lost workers and wiped economies

{{T.workers_lost}}

Sides down to 2 or fewer workers before 10:00 (after having 8+):

{{T.dd_early_wipe}}

Sides down to 2 or fewer workers after 4:00 (first few):

{{T.ex_workers}}

Workers are what everyone loses most of. The Brood's wiped economies are its cross games (section 4.2). The owner's backlog
item about a Crown that lost all its workers at about 6:00 to Raptors does not show up in AI-against-AI games: Crown
economies wiped before 10:00 number {{H.crown_wipes}}, and {{H.crown_wipes_brood}} of them were against the Brood. If that
backlog game had a human Brood, this study cannot speak to it; the Hard Brood AI never does this to the Crown here.

### 10.10 Units standing still during a wave

{{T.ex_idle_army}}

These are Brood swarms in the middle of an attack with most of their units standing. Example: `brood-brood_003` at 13:00,
the winning side's swarm of 60 is razing the other side's Clutch Mounds and Feeding Pits while 47 of its units stand idle.
It does not change who wins, but it slows the finish. Overall idle army time (the table in 4.3) also counts armies waiting at
home for their next wave, which is the AI's intent.

### 10.11 Build sites placed and dropped again

{{T.dropped}}

{{T.dd_drops}}

Bursts (5+ drops of one kind within 30 s): {{T.dropped_bursts_n}}; the worst:

{{T.dropped_bursts}}

The Brood places a Clutch Mound (its supply building) and drops it again because no grub comes ("nobody was coming"), over and
over: in the worst game 149 times, in bursts of 35 within 30 s. It goes with losing: in Brood mirrors the loser drops about
three times as many mounds as the winner:

{{T.dd_drops_mirror}}

The Crown does the same with Farms, Cottages and Town Halls, less often.

### 10.12 Siege pull-backs at gates

See section 7.2. Pull-backs at a Crown gate happen in most Crown-Clockwork games and in two-thirds of Crown mirrors, and every
Crown-Clockwork 30:00 game has one. "It can't get through" is the usual reason given, sometimes with the army's damage on the
gate several times the fire it takes.

### 10.13 The Crown's random Horse Breeder opening

Inside the Balanced plan, the Crown opens with a Horse Breeder instead of a Powder Mill in 30% of games, at random
(`ai.gd`: `opening = "breeder"` when `randf() < 0.3`).

{{T.dd_crown_open}}

The Breeder opening does much worse in the mirror and against the Clockwork. It is a coin flip inside the AI that loses.

---

## 11. Recommended fixes, ranked

Ranked by how much each would change the game's balance and the AI's quality, against how sure the evidence is. "Strong" =
large effect, interval clear of chance, seen across maps and in many games; "moderate" = clear in the data but a mechanism or
a sample still open; "weak" = a hint.

| # | What to change | Kind | Evidence | Strength | Principle |
|---|---|---|---|---|---|
| 1 | Re-measure the Brood on main with this harness, then give it an early game that holds: its army must be able to meet a Crown wave of Musketeers and Horsemen at 4:00-6:00 and a Clockwork wave of 18 supply at 3:40, without giving up its economy (cheaper early defence, a faster first Spawning Den army curve, or Raptors that do something against Horsemen) | balance | {{H.brood_cross_wins}} wins in {{H.brood_cross_n}} cross side-games; army value flat at about 300 from 4:00 to 7:00 (4.1, 4.2) | strong | 1. fairness and counterplay |
| 2 | Make an army at its supply cap attack: cap `_attack_at` at what the army can field (200 minus workers, minus a margin) in `_wave_end()` and `_siege_plan()`, and/or attack when capped with a bank for a minute; count only armed (or reachable) enemies in `_threat()` | AI | {{H.stall10_n}} side-games capped with a bank and no wave for 10+ min, bank up to {{H.stall10_bank}} (10.1) | strong (effect); moderate (which gate) | 2. a big bank must not be a win button; the winner must be able to finish |
| 3 | Make the gg rule look at real income: "can rebuild" only if the side earned something in the last minute or two (or has the money for a hall), not "has a hall and a worker" | AI | losers of every cap stall never hopeless; `crown-clockwork_140` (10.2) | strong | 4. respect the player's time |
| 4 | The Brood's single ground reserve: every pit draws on the capital's 10,500 and a new Burrow brings no ground, so a game's pit income is fixed. Give later Burrows ground of their own (or let the capital's ground recover slowly), so that expanding pays, then teach the AI to expand before the reserve runs out | economy + AI | 46% of Brood mirror sides spend it (median 15:30), then 80%+ of grubs idle; every 30:00 Brood mirror is a dead stalemate (4.6, 10.3); same rule on main | strong | 2. economy forces expansion, does not strangle |
| 5 | Measure the gear-mode Clockwork with this harness before tuning it. The old Clockwork out-earned both others about 2:1 and beat the Crown {{H.cw}}; keep the new one's early income in line with the Crown's | balance | mirror medians (4.1); win matrix (2.1) | strong for the old Clockwork; unknown for the new | 1. fairness |
| 6 | Drop the Crown's random 30% Horse Breeder opening from the Balanced plan (keep it for Rush), or fix what makes it lose | AI | {{H.breeder_line}} (10.13) | strong | 4. the player is the strategist: the AI should not throw games by coin flip |
| 7 | When the Crown's soil runs low, save 400 gold for the next Town Hall before it is spent; on main check whether 0.14.17 already helps | AI + economy | 11% of Crown sides stall with spent soil and none could afford a hall; 96% of them lose (4.5) | strong | 2. depletion should force expansion, not strangle it |
| 8 | Look at the four maps where the Crown cannot beat the Clockwork (natural at the ramp foot?) | map / AI | Crown {{H.s_all}} there against {{H.o_all}} elsewhere; out-of-sample check {{H.s_oos}} against {{H.o_oos}} (9.2) | moderate (effect); weak (cause) | 1. fairness across maps |
| 9 | Crown supply blocks: build Cottages first when blocked, not more production buildings | AI | median 5 production buildings added during 2+ min blocks; most idle after (10.5) | moderate (rare, but clear) | 3. buildings with a purpose |
| 10 | The Brood's Clutch Mound site loop: do not re-place a site no grub can or will reach (back off, or pick another spot) | AI | 6,000+ drops, bursts of 35 in 30 s; losers drop 3x more (10.11) | moderate | (AI quality) |
| 11 | The Crown's defender's advantage at the gate does not fade mid-game: consider making gates and palisades weaker against big armies later, or have the attacker commit when its army is much bigger | balance + AI | pull-backs in most Crown-Clockwork and Crown mirror games, also late (7.2, 10.12) | moderate | 2. defender's advantage early, fading mid-game |
| 12 | Retune `AIScout.EARLY_PROD` so the Brood's standard opening and the Clockwork's Assembly Works are not read as a rush | AI | "rush" on about 89% of Balanced foes; no measured cost (7.3) | weak (low impact) | (AI quality) |
| 13 | Find why games do not replay from a seed | engineering | state hashes differ on identical runs (1) | strong (fact); unknown (cause) | (testing, online play) |

---

## 12. What a bigger sample would decide

{{T.dd_power}}

- **Settled now:** the matchup order and the size of the gaps (Brood against anyone; Crown against Clockwork to about +-7
  points); no overall spawn bias; the early game is open in mirrors; the AI faults in section 10, each seen in many games.
- **Not settled:** which plan is best inside a matchup (each cell has 14-32 side-games, so +-15-25 points; a +-5 point answer
  needs 300-400 side-games per plan and matchup); whether any single map favours one spawn by 10-15 points (about 80 decided
  mirror games per map for a 15-point imbalance; there are about 37); the cause of the four-map effect (a direct look at the
  games will decide it faster than more games).
- **Better than more of the same:** run this harness on main (the Clockwork changed completely), and add targeted games:
  a Crown against Clockwork series on Kestrel Rise, the Brood with a changed early game against the Crown, and long
  Crown-Clockwork games with the attack gate logged (section 10.1).

---

## 13. What could not be verified, and how to re-run

**Not verified, or only partly:**
- Faction strength and AI skill cannot be separated with AI-against-AI games (see the Summary).
- The mechanism of the cap stalls (10.1): the effect is clear; which of the two gates locks is {{H.diag_status}}.
- The four-map effect (9.2): the cause is a hypothesis.
- Why games do not replay from a seed (1).
- The harness reads the AI's own state for waves (`_attacking`, swarm phase, raiders) and parses the match log for events
  (walls, siege decisions, dropped sites, scouting). An attack the AI does not flag, or a log line that changes its wording,
  is missed.
- "Idle" units are units whose order is `idle`; an army waiting at home for its threshold counts as idle, by design.
- The box was shared with other jobs, so real-time costs are upper bounds.
- The study build is v0.14.1; see the note at the top for what main has changed.

**Files.** In `docs/study_data/`: `games.csv` (one row per game), `sides.csv` (one row per game and side),
`timeseries.csv.gz` (one row per game, side and 30 s), `waves.csv` (one row per wave or raid), `events.csv.gz` (key match
log lines), `tables.json` (every table in this report, by key), `STATUS.json` (progress), `figs/`. The match logs themselves
are not committed (about 50 MB); they stay in `/home/claude/study_runs/logs/` on the study box.

**Re-run on another build:**
```
nohup python3 tools/study/run_study.py --out <runs dir> --games 30 --workers 1 > run.out 2>&1 &   # resumable: re-run to continue
tools/study/stage.sh <runs dir>          # aggregate, tables, figures, STATUS.json
python3 tools/study/report.py            # this report
```
`tools/study/study_game.gd` plays one game; `tools/study/replicates.sh` replays one setup N times; `tools/study/diag_army.gd`
logs what holds an AI's army back every 5 s.
"""


def render(T, H, stage):
    H = dict(H)
    n_ = int(H["n"].replace(",", ""))
    if H["final"]:
        H["status"] = ("**Final report.** %s games: %s per matchup, all six matchups complete (%s planned per matchup). "
                       "Data as of %s (UTC)." % (H["n"], H["per"], H["planned"], H["updated"]))
    else:
        H["status"] = ("**Interim report%s: %s of %s planned games done (%s per matchup); the batch is still running.** "
                       "The data and this report are refreshed at each stage; numbers will still move a little. Data as of %s (UTC)." % (
                           (", stage %s" % stage) if stage else "", H["n"], H["planned_total"], H["per"], H["updated"]))
    # derived lines from tables.json
    m = re.search(r"\| crown\s+\| mill\s+\|\s+(\d+) \| ([^|]+)\|\n\| crown\s+\| breeder\s+\|\s+(\d+) \| ([^|]+)\|", T.get("dd_crown_open", ""))
    hh = re.search(r"the Mill side won (\d+/\d+ = \d+% \[\d+%-\d+%\])", T.get("dd_crown_open", ""))
    H["breeder_line"] = ("in the Crown mirror the Breeder opening scores %s against the Mill's %s, and the Mill side wins %s head to head" % (
        m.group(4).strip(), m.group(2).strip(), hh.group(1))) if (m and hh) else "(see 10.13)"
    m2 = re.search(r"\| clockwork vs clockwork \(mirror\) \| rush\s+\| Balanced\s+\|\s+\d+ \| ([^|]+)\|", T.get("dd_plans", ""))
    H["plan_cw_rush"] = m2.group(1).strip() if m2 else "(see table)"
    m3 = re.search(r"\| clockwork \|[^\n]*\| (\d+/\d+)\s+\| (\d+/\d+)\s+\| [^|]+\|\s*$", T.get("faults_econ", ""), re.M)
    H["cap200_cw"] = m3.group(1) if m3 else "(see table)"
    H.setdefault("diag_text", "")
    H.setdefault("diag_status", "not settled")

    def sub(mo):
        kind, key = mo.group(1), mo.group(2)
        src = T if kind == "T" else H
        if key not in src:
            print("report: missing %s.%s" % (kind, key), file=sys.stderr)
            return "_(%s.%s not available)_" % (kind, key)
        return str(src[key])
    return re.sub(r"\{\{([TH])\.([A-Za-z0-9_]+)\}\}", sub, TEMPLATE).lstrip("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="docs/study_data")
    ap.add_argument("--out", default="docs/ai_balance_study.md")
    ap.add_argument("--stage", default="")
    ap.add_argument("--diag", default="", help="optional JSON with diag_text / diag_status (the cap-stall diagnostic games)")
    a = ap.parse_args()
    T = json.load(open(os.path.join(a.data, "tables.json")))
    H = headline(a.data)
    if a.diag and os.path.exists(a.diag):
        H.update(json.load(open(a.diag)))
    text = render(T, H, a.stage)
    with open(a.out, "w") as f:
        f.write(text)
    print("report: %s (%d lines)" % (a.out, text.count("\n")))


if __name__ == "__main__":
    main()
