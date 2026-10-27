#!/usr/bin/env python3
"""Balance study v2 (docs/study_v2.md): report tools. Measurement only. Standard library only (no numpy / pandas).

  aggregate  one machine's run folder into docs/study_v2/data/<machine>/:
               games/*.json and ts/*.csv copied as they are, the match logs in logs.tar.gz, the explorer's
               candidates and draws in explore.tar.gz (machine 4), and csv/ with tools/study/aggregate.py's tables
               (games, sides, timeseries, waves, events) plus the openings: games.csv and sides.csv gain
               opening columns, and openings.csv (one row per scripted side), steps.csv (one row per step) and
               snaps.csv (army, workers, bank at 3, 5, 7, 10, 15, 20 minutes) are added.
       python3 tools/study/report_v2.py aggregate --runs /path/runs --machine m1 [--data docs/study_v2/data]
  combine    every machine's csv/ into docs/ai_balance_study_v2.md (plain prose and small tables).
       python3 tools/study/report_v2.py combine [--data docs/study_v2/data] [--old docs/study_data] [--out docs/ai_balance_study_v2.md]
  check      the build check (one 8-minute game per build) as a markdown table.
       python3 tools/study/report_v2.py check --runs /path/check
"""
import argparse, csv, glob, gzip, io, json, math, os, shutil, statistics, sys, tarfile, time
from collections import defaultdict, Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FACTIONS = ["crown", "brood", "clockwork"]
FNAME = {"crown": "Crown", "brood": "Brood", "clockwork": "Clockwork"}
PAIRS = [("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork")]
SNAPS = ["180", "300", "420", "600", "900", "1200"]


# ------------------------------------------------------------------ small helpers

def wilson(k, n, z=1.96):
    if n == 0:
        return (float("nan"), float("nan"))
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(max(0.0, p * (1 - p) / n + z * z / (4 * n * n))) / d
    return (max(0.0, c - h), min(1.0, c + h))


def pct(x):
    return "n/a" if x is None or (isinstance(x, float) and math.isnan(x)) else "%d%%" % round(100 * x)


def rate(w, l, d=0):
    """Win rate with a draw as half a win, and its Wilson 95% interval (on wins + half the draws)."""
    n = w + l + d
    if n == 0:
        return "n/a"
    k = w + 0.5 * d
    lo, hi = wilson(k, n)
    return "%s (%s to %s)" % (pct(k / n), pct(lo), pct(hi))


def mmss(s):
    try:
        s = float(s)
    except (TypeError, ValueError):
        return "-"
    if s < 0:
        return "-"
    return "%d:%02d" % (int(s) // 60, int(s) % 60)


def num(x, default=None):
    try:
        return float(x)
    except (TypeError, ValueError):
        return default


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def fmt(x, nd=0):
    if x is None:
        return "-"
    return ("{:,.%df}" % nd).format(x)


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


def read_csv(path):
    if not os.path.exists(path):
        return []
    op = gzip.open(path, "rt", newline="") if path.endswith(".gz") else open(path, newline="")
    with op as f:
        return list(csv.DictReader(f))


def write_csv(path, rows, header=None):
    import aggregate
    aggregate.write(path, rows, header)


def opening_label(nm, builds):
    if nm.startswith("ai:"):
        return "plain computer (%s)" % nm[3:]
    b = builds.get(nm)
    if b and b.get("label"):
        return b["label"]
    return nm


# ------------------------------------------------------------------ aggregate (one machine)

def side_rows(g):
    """openings.csv, steps.csv and snaps.csv rows of one game."""
    op, st, sn = [], [], []
    for t in g["teams"]:
        i = t["team"]
        won = 1 if g["winner_team"] == i else (0 if g["winner_team"] >= 0 else -1)
        opp = g["teams"][1 - i]
        base = {"id": g["id"], "team": i, "faction": t["faction"], "opp": opp["faction"], "opening": t.get("opening", ""),
                "opp_opening": opp.get("opening", ""), "map": g["map"], "won": won, "end_t": g["end_t"], "cause": g["cause"]}
        bo = t.get("bo")
        r = dict(base)
        if bo:
            sv = bo.get("steps_v2", [])
            r.update({"scripted": 1, "steps": len(sv), "steps_done": sum(1 for s in sv if s["status"] == "done"),
                      "steps_timeout": sum(1 for s in sv if s["status"] == "timeout"),
                      "steps_skipped": sum(1 for s in sv if s["status"] == "skipped"),
                      "steps_lost": sum(1 for s in sv if s["status"] == "lost"),
                      "steps_pending": sum(1 for s in sv if s["status"] == "pending"),
                      "script_end_t": bo.get("script_end_t", -1), "script_end_why": bo.get("script_end_why", ""),
                      "then": bo.get("then", ""), "scripted_attacks": len(bo.get("waves", [])),
                      "first_scripted_attack": bo["waves"][0]["go"] if bo.get("waves") else "",
                      "scripted_kills": sum(int(w.get("killed_value", 0) or 0) for w in bo.get("waves", [])),
                      "scripted_losses": sum(int(w.get("lost_value", 0) or 0) for w in bo.get("waves", [])),
                      "drops": len(bo.get("drops", [])), "steps_list": json.dumps(bo.get("steps_list", []))})
            for k, s in enumerate(sv):
                st.append({"id": g["id"], "team": i, "faction": t["faction"], "opening": t.get("opening", ""), "k": k,
                           "step": s["step"], "first": s["first"], "issued": s["issued"], "built": s["built"],
                           "status": s["status"], "note": s.get("note", "")})
        else:
            r.update({"scripted": 0})
        op.append(r)
        for at, s in (t.get("snaps") or {}).items():
            sn.append({"id": g["id"], "team": i, "faction": t["faction"], "opening": t.get("opening", ""), "t": at,
                       "army_value": s["value"], "army_supply": s["supply"], "workers": s["workers"], "bank": s["bank"],
                       "earned": s["earned"], "res2": s["res2"], "tension": s.get("tension", 0), "buildings": s["buildings"],
                       "halls": s.get("halls", ""), "army": json.dumps(s["army"])})
    return op, st, sn


def cmd_aggregate(a):
    import aggregate
    runs = os.path.abspath(a.runs)
    dest = os.path.join(os.path.abspath(a.data), a.machine)
    csvd = os.path.join(dest, "csv")
    os.makedirs(csvd, exist_ok=True)
    for sub in ("games", "ts"):
        os.makedirs(os.path.join(dest, sub), exist_ok=True)
        for p in glob.glob(os.path.join(runs, sub, "*")):
            if not p.endswith(".tmp"):
                shutil.copy2(p, os.path.join(dest, sub, os.path.basename(p)))
    logs = sorted(glob.glob(os.path.join(runs, "logs", "*.log")))
    with tarfile.open(os.path.join(dest, "logs.tar.gz"), "w:gz") as tf:
        for p in logs:
            tf.add(p, arcname="logs/" + os.path.basename(p))
    ex = os.path.join(runs, "explore")
    if os.path.isdir(ex):
        with tarfile.open(os.path.join(dest, "explore.tar.gz"), "w:gz") as tf:
            tf.add(ex, arcname="explore", filter=lambda ti: None if ti.name.endswith(".tmp") else ti)
        # the candidates also as one readable file
        cands = {}
        for p in glob.glob(os.path.join(ex, "candidates", "*.json")):
            c = json.load(open(p))
            cands[c["name"]] = c
        json.dump(cands, open(os.path.join(dest, "candidates.json"), "w"), indent=1, sort_keys=True)
        specs = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(ex, "specs", "*.json")))]
        json.dump(specs, open(os.path.join(dest, "explore_specs.json"), "w"), indent=1)
    for p in ("failures.jsonl", "run.log"):
        if os.path.exists(os.path.join(runs, p)):
            shutil.copy2(os.path.join(runs, p), os.path.join(dest, p))
    # aggregate.py's tables
    old = sys.argv
    sys.argv = ["aggregate.py", "--runs", runs, "--out", csvd]
    try:
        aggregate.main()
    finally:
        sys.argv = old
    # openings on top
    gj = {}
    for p in sorted(glob.glob(os.path.join(runs, "games", "*.json"))):
        g = json.load(open(p))
        gj[g["id"]] = g
    games = read_csv(os.path.join(csvd, "games.csv"))
    for r in games:
        g = gj.get(r["id"], {})
        r["opening_a"] = g.get("opening_a", "")
        r["opening_b"] = g.get("opening_b", "")
        r["machine"] = a.machine
    write_csv(os.path.join(csvd, "games.csv"), games)
    sides = read_csv(os.path.join(csvd, "sides.csv"))
    for r in sides:
        g = gj.get(r["id"], {})
        t = g.get("teams", [{}, {}])[int(r["team"])]
        r["opening"] = t.get("opening", "")
        r["opp_opening"] = g.get("teams", [{}, {}])[1 - int(r["team"])].get("opening", "")
        r["machine"] = a.machine
    write_csv(os.path.join(csvd, "sides.csv"), sides)
    op, st, sn = [], [], []
    for gid in sorted(gj):
        o, s, n = side_rows(gj[gid])
        op += o
        st += s
        sn += n
    for rows in (op, st, sn):
        for r in rows:
            r["machine"] = a.machine
    write_csv(os.path.join(csvd, "openings.csv"), op)
    write_csv(os.path.join(csvd, "steps.csv"), st)
    write_csv(os.path.join(csvd, "snaps.csv"), sn)
    print("%s: %d games, %d sides, %d steps, %d snaps -> %s" % (a.machine, len(gj), len(op), len(st), len(sn), dest))


# ------------------------------------------------------------------ check (the build check table)

def cmd_check(a):
    from run_study_v2 import load_builds
    builds = load_builds()
    rows = []
    for p in sorted(glob.glob(os.path.join(a.runs, "games", "*.json"))):
        g = json.load(open(p))
        for t in g["teams"]:
            bo = t.get("bo")
            if not bo:
                continue
            sv = bo.get("steps_v2", [])
            bad = ["%s (%s)" % (s["step"], s["status"]) for s in sv if s["status"] not in ("done",) and not (s["status"] == "pending" and s["step"] in ("end",) )]
            sn = t.get("snaps", {})

            def army(k):
                s = sn.get(k)
                return "%d / %d" % (s["supply"], s["value"]) if s else "-"
            won = "win" if g["winner_team"] == t["team"] else ("loss" if g["winner_team"] >= 0 else "even")
            rows.append([bo["name"], "%d of %d" % (sum(1 for s in sv if s["status"] == "done"), len(sv)),
                         mmss(bo.get("script_end_t", -1)) if bo.get("script_end_t", -1) >= 0 else "still scripted",
                         army("180"), army("300"), army("420"), won + " (%s)" % g["cause"], "; ".join(bad) or "none"])
    print(table(["build", "steps done", "script ended", "army 3:00 (supply / value)", "5:00", "7:00", "result at 8:00",
                 "steps not done"], rows))


# ------------------------------------------------------------------ combine (all machines -> the report)

def load_all(data):
    D = {"games": [], "sides": [], "openings": [], "snaps": [], "ts": [], "steps": []}
    machines = sorted(d for d in os.listdir(data) if os.path.isdir(os.path.join(data, d, "csv")))
    for m in machines:
        c = os.path.join(data, m, "csv")
        D["games"] += read_csv(os.path.join(c, "games.csv"))
        D["sides"] += read_csv(os.path.join(c, "sides.csv"))
        D["openings"] += read_csv(os.path.join(c, "openings.csv"))
        D["snaps"] += read_csv(os.path.join(c, "snaps.csv"))
        D["steps"] += read_csv(os.path.join(c, "steps.csv"))
        D["ts"] += read_csv(os.path.join(c, "timeseries.csv.gz"))
    cands = {}
    specs = []
    for m in machines:
        p = os.path.join(data, m, "candidates.json")
        if os.path.exists(p):
            cands.update(json.load(open(p)))
        p2 = os.path.join(data, m, "explore_specs.json")
        if os.path.exists(p2):
            specs += json.load(open(p2))
    D["machines"] = machines
    D["cands"] = cands
    D["specs"] = specs
    return D


def is_explore(gid):
    return gid.startswith("x_")


def econ_at(ts_rows, t_list=(300, 600, 900, 1200)):
    """faction -> t -> dict of medians: income a minute (main resource, over the minute before), bank, workers, army."""
    by = defaultdict(dict)       # (id, team) -> t -> row
    for r in ts_rows:
        by[(r["id"], r["team"])][int(r["t"])] = r
    acc = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
    for (gid, team), rows in by.items():
        for t in t_list:
            r = rows.get(t)
            p = rows.get(t - 60)
            if r is None or p is None:
                continue
            f = r["faction"]
            A = acc[f][t]
            A["income"].append(num(r["earned"], 0) - num(p["earned"], 0))
            A["res2_income"].append(num(r["res2_in"], 0) - num(p["res2_in"], 0))
            A["bank"].append(num(r["gold"], 0))
            A["workers"].append(num(r["workers"], 0))
            A["army"].append(num(r["army_value"], 0))
            A["n"].append(1)
    out = {}
    for f, T in acc.items():
        out[f] = {t: {k: (len(v) if k == "n" else med(v)) for k, v in A.items()} for t, A in T.items()}
    return out


def tally(rows):
    w = sum(1 for r in rows if r == 1)
    l = sum(1 for r in rows if r == 0)
    d = sum(1 for r in rows if r == -1)
    return w, l, d


def cmd_combine(a):
    from run_study_v2 import load_builds
    builds = load_builds()
    D = load_all(a.data)
    games = [g for g in D["games"] if not is_explore(g["id"])]
    xgames = [g for g in D["games"] if is_explore(g["id"])]
    sides = [s for s in D["sides"] if not is_explore(s["id"])]
    L = []
    say = L.append
    say("# Holdfast balance study v2: the new economy, with build orders")
    say("")
    vers = sorted(set(g["version"] for g in D["games"]))
    say("Written by tools/study/report_v2.py on %s from %d games on %d machines (%s), game version %s. "
        "Measurement only: nothing in the game was changed. How it was run: docs/study_v2.md."
        % (time.strftime("%Y-%m-%d"), len(D["games"]), len(D["machines"]), ", ".join(D["machines"]) or "none", ", ".join(vers) or "unknown"))
    say("")
    say("In every match-up game each side opened with one of its faction's documented build orders "
        "(tools/study/build_orders.json), drawn so each opening got an equal share, and then the Hard computer played on. "
        "Games run to 30 minutes at most; a side the computer's own rule calls hopeless gives up (the cause is \"gg\"); "
        "at the 30-minute cap the side with 1.25 times the other's power counts as the winner (\"timeout lead\"), "
        "otherwise the game is even. A win rate counts an even game as half a win. The numbers in brackets are the 95% "
        "confidence range: with 100 games a true 50% can come out anywhere from about 40% to 60%.")
    say("")

    # ---- match-ups
    say("## Who wins each match-up")
    say("")
    rows = []
    summary = []
    for fa, fb in PAIRS:
        res = []
        for s in sides:
            if s["faction"] == fa and s["opp"] == fb:
                res.append(int(s["won"]))
        w, l, d = tally(res)
        n = w + l + d
        if n == 0:
            rows.append([FNAME[fa] + " against " + FNAME[fb], 0, "-", "-", "-", "n/a"])
            continue
        rows.append([FNAME[fa] + " against " + FNAME[fb], n, w, l, d, rate(w, l, d)])
        k = w + 0.5 * d
        lo, hi = wilson(k, n)
        if lo > 0.5:
            summary.append("the %s beats the %s (%s of the games)" % (FNAME[fa], FNAME[fb], pct(k / n)))
        elif hi < 0.5:
            summary.append("the %s beats the %s (%s of the games)" % (FNAME[fb], FNAME[fa], pct(1 - k / n)))
        else:
            summary.append("the %s and the %s are within chance of even (%s for the %s)" % (FNAME[fa], FNAME[fb], pct(k / n), FNAME[fa]))
    say(table(["match-up", "games", "wins", "losses", "even", "win rate (95% range)"], rows))
    say("")
    if summary:
        say("In short: " + "; ".join(summary) + ".")
        say("")

    # by map, briefly
    say("### By map")
    say("")
    say("Each map has only about eight games per match-up, so these are hints, not findings.")
    say("")
    maps = sorted(set(s["map"] for s in sides))
    rows = []
    for m in maps:
        row = [m.replace("_", " ").title()]
        for fa, fb in PAIRS:
            res = [int(s["won"]) for s in sides if s["map"] == m and s["faction"] == fa and s["opp"] == fb]
            w, l, d = tally(res)
            row.append("%d-%d-%d" % (w, l, d) if res else "-")
        rows.append(row)
    say(table(["map"] + ["%s v %s (W-L-even)" % (FNAME[a_], FNAME[b_]) for a_, b_ in PAIRS], rows))
    say("")

    # ---- openings
    say("## How each opening did")
    say("")
    say("Each documented opening against everything it met (both other factions together), then against each faction. "
        "With about 100 games a faction split over its openings, each opening has some 15 to 30 games, so only large "
        "differences are real.")
    say("")
    for f in FACTIONS:
        ops = sorted(set(s["opening"] for s in sides if s["faction"] == f and s["opening"]))
        if not ops:
            continue
        say("### The %s" % FNAME[f])
        say("")
        rows = []
        for o in ops:
            mine = [s for s in sides if s["faction"] == f and s["opening"] == o]
            w, l, d = tally([int(s["won"]) for s in mine])
            row = [opening_label(o, builds) + " (%s)" % o, w + l + d, rate(w, l, d)]
            for of in FACTIONS:
                if of == f:
                    continue
                w2, l2, d2 = tally([int(s["won"]) for s in mine if s["opp"] == of])
                row.append("%d-%d-%d" % (w2, l2, d2) if w2 + l2 + d2 else "-")
            lens = [num(s["end_t"]) for s in mine]
            row.append(mmss(med(lens)))
            rows.append(row)
        rows.sort(key=lambda r: -r[1])
        say(table(["opening", "games", "win rate (95% range)"] + ["v %s (W-L-even)" % FNAME[x] for x in FACTIONS if x != f] + ["median length"], rows))
        say("")
    # pairs
    say("### Opening against opening")
    say("")
    say("Only pairs with at least %d games are shown; the win rate is the first opening's." % a.min_pair)
    say("")
    pc = defaultdict(list)
    for s in sides:
        if (s["faction"], s["opp"]) in PAIRS:      # (each game once: from the first faction of its pair)
            pc[(s["opening"], s["opp_opening"])].append(int(s["won"]))
    rows = []
    for (o1, o2), res in sorted(pc.items(), key=lambda kv: -len(kv[1])):
        if len(res) < a.min_pair:
            continue
        w, l, d = tally(res)
        rows.append([o1, o2, len(res), "%d-%d-%d" % (w, l, d), rate(w, l, d)])
    say(table(["opening", "against", "games", "W-L-even", "win rate (95% range)"], rows) if rows else
        "No pair has %d games yet." % a.min_pair)
    say("")

    # did the scripts run
    say("### Did the scripts run as written")
    say("")
    ops = [o for o in D["openings"] if o.get("scripted") == "1" and not is_explore(o["id"])]
    by = defaultdict(list)
    for o in ops:
        by[o["opening"]].append(o)
    rows = []
    for nm in sorted(by):
        lst = by[nm]
        full = sum(1 for o in lst if num(o["script_end_t"], -1) >= 0 and int(o["steps_timeout"]) == 0 and int(o["steps_skipped"]) == 0
                   and "time limit" not in o["script_end_why"])
        to = sum(int(o["steps_timeout"]) for o in lst)
        ends = [num(o["script_end_t"]) for o in lst if num(o["script_end_t"], -1) >= 0]
        rows.append([nm, len(lst), "%d of %d" % (full, len(lst)), to, mmss(med(ends))])
    say(table(["opening", "games", "script finished", "steps timed out (all games)", "median hand-over"], rows) if rows else "_(no data)_")
    say("")

    # ---- economy
    say("## The economy by faction")
    say("")
    say("Medians over every side still playing at that minute (games that ended earlier drop out, so later rows lean on "
        "the closer games). Income is the main resource (gold, biomass or cogs) earned in the minute before; the bank is "
        "what is unspent; the army is its value. The earlier study (docs/study_data, version 0.14.1, plain Hard "
        "computers, mirrors left out here) is in brackets.")
    say("")
    new_e = econ_at([r for r in D["ts"] if not is_explore(r["id"])])
    old_ts = []
    if a.old and os.path.exists(os.path.join(a.old, "timeseries.csv.gz")):
        og = {r["id"]: r for r in read_csv(os.path.join(a.old, "games.csv"))}
        old_ts = [r for r in read_csv(os.path.join(a.old, "timeseries.csv.gz")) if r["id"] in og and og[r["id"]]["a"] != og[r["id"]]["b"]]
    old_e = econ_at(old_ts)
    for f in FACTIONS:
        if f not in new_e:
            continue
        say("### The %s" % FNAME[f])
        say("")
        rows = []
        for t in (300, 600, 900, 1200):
            N = new_e[f].get(t)
            O = old_e.get(f, {}).get(t)
            if not N:
                continue

            def both(k, nd=0):
                return "%s (%s)" % (fmt(N.get(k), nd), fmt(O.get(k), nd) if O else "-")
            rows.append(["%d:00" % (t // 60), N["n"], both("income"), both("res2_income"), both("bank"), both("workers"), both("army")])
        say(table(["minute", "sides", "income a minute", "second resource a minute", "bank", "workers", "army value"], rows))
        say("")

    # ---- lengths and causes
    say("## How long the games lasted and how they ended")
    say("")
    rows = []
    for fa, fb in PAIRS:
        gl = [g for g in games if {g["a"], g["b"]} == {fa, fb}]
        if not gl:
            continue
        lens = sorted(num(g["end_t"]) for g in gl)
        q = lambda p: lens[min(len(lens) - 1, int(p * len(lens)))]
        cz = Counter(g["cause"] for g in gl)
        rows.append([FNAME[fa] + " v " + FNAME[fb], len(gl), mmss(q(0.25)), mmss(statistics.median(lens)), mmss(q(0.75)),
                     cz.get("victory", 0), cz.get("gg", 0), cz.get("timeout_lead", 0), cz.get("timeout_even", 0)])
    say(table(["match-up", "games", "quarter of games over by", "median", "three quarters by", "destroyed", "gave up (gg)",
               "30:00 with a lead", "30:00 even"], rows) if rows else "_(no data)_")
    say("")
    # wins by cause and faction
    rows = []
    for f in FACTIONS:
        ws = [s for s in sides if s["faction"] == f and s["won"] == "1"]
        if not ws:
            continue
        cz = Counter(s["cause"] for s in ws)
        early = sum(1 for s in ws if num(s["end_t"], 9999) < 600)
        rows.append([FNAME[f], len(ws), early, cz.get("victory", 0), cz.get("gg", 0), cz.get("timeout_lead", 0)])
    if rows:
        say(table(["faction", "wins", "won before 10:00", "by destroying", "by gg", "by a lead at 30:00"], rows))
        say("")

    # ---- the explorer
    explore_section(L, D, xgames, builds, a)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w").write("\n".join(L) + "\n")
    print("wrote %s (%d games, %d explore games)" % (a.out, len(games), len(xgames)))


def explore_section(L, D, xgames, builds, a):
    say = L.append
    say("## The exploratory games: looking for outlier openings")
    say("")
    if not xgames:
        say("_(no exploratory games in the data)_")
        return
    import explore_v2
    spec_of = {s["id"]: s for s in D["specs"]}
    gmap = {g["id"]: g for g in xgames}
    sides = {(s["id"], s["team"]): s for s in D["sides"]}
    snaps = defaultdict(dict)
    for s in D["snaps"]:
        snaps[(s["id"], s["team"])][s["t"]] = s
    ops = {(o["id"], o["team"]): o for o in D["openings"]}
    res = defaultdict(list)
    for gid, g in gmap.items():
        sp = spec_of.get(gid)
        if not sp:
            continue
        a_team = 1 if g["swap"] in ("1", "True", "true") else 0
        res[sp["cand"]].append((gid, a_team, sp))
    say("%d games tried %d candidate openings (%s). Each candidate played an opening of another faction (its standard, "
        "another documented one, or the plain computer) on a random map. A candidate's score is 1 for a win, 0 for a loss, "
        "0.75 or 0.25 for a lead at 30:00, 0.5 for even; its fitness is (score + 0.5) / (games + 1), so a candidate needs "
        "more than one game to rise far. Winners were mutated more often, and the best were played again to confirm them."
        % (len(xgames), len(res), ", ".join("%d %s" % (sum(1 for c in res if D["cands"].get(c, {}).get("faction") == f), FNAME[f]) for f in FACTIONS)))
    say("")
    # baseline: documented openings in the match-up machines, army at 5:00 by faction
    base5 = defaultdict(list)
    for s in D["snaps"]:
        if not is_explore(s["id"]) and s["t"] == "300":
            base5[s["faction"]].append(num(s["army_value"]))
    rows = []
    stats = []
    for c, lst in res.items():
        cand = D["cands"].get(c, {})
        scores = []
        rec = []
        for gid, at, sp in lst:
            g = gmap[gid]
            sc = explore_v2.game_score({"a_won": int(g["a_won"]), "cause": g["cause"]})
            scores.append(sc)
            rec.append((gid, at, sp, g, sc))
        fit = explore_v2.Explorer.fitness(scores)
        stats.append((fit, c, cand, rec, scores))
    stats.sort(key=lambda x: (-x[0], -len(x[4])))
    for f in FACTIONS:
        fs = [x for x in stats if x[2].get("faction") == f]
        if not fs:
            continue
        say("### The %s's best candidates" % FNAME[f])
        say("")
        rows = []
        for fit, c, cand, rec, scores in fs[:8]:
            wins = sum(1 for x in scores if x >= 0.75)
            opp = ", ".join(sorted(set("%s %s" % (r[3]["b"], r[2]["ob"]) for r in rec)))
            rows.append([c, len(scores), wins, "%.2f" % fit, cand.get("origin", ""), opp])
        say(table(["candidate", "games", "wins", "fitness", "grown from", "met"], rows))
        say("")
    # the outliers in detail: fitness >= threshold with 2+ games, else the top 3
    out = [x for x in stats if len(x[4]) >= 2 and x[0] >= a.outlier]
    if not out:
        out = [x for x in stats if len(x[4]) >= 2][:3] or stats[:3]
        say("No candidate reached a fitness of %.2f over two or more games; the best ones are below." % a.outlier)
        say("")
    say("### The outliers in detail")
    say("")
    for fit, c, cand, rec, scores in out[:a.max_outliers]:
        f = cand.get("faction", "")
        say("**%s** (%s, fitness %.2f over %d games; grown from %s%s)." % (
            c, FNAME.get(f, f), fit, len(scores), cand.get("origin", "?"),
            ", by " + "; ".join(", ".join(m) for m in cand.get("mutations", []) if m) if any(cand.get("mutations", [])) else ""))
        say("")
        say("The script: `%s`, then the computer plays on with the %s plan." % (", ".join(cand.get("steps", [])), cand.get("then", "balanced")))
        say("")
        rows = []
        why = []
        for gid, at, sp, g, sc in rec:
            sd = sides.get((gid, str(at)), {})
            o = ops.get((gid, str(at)), {})
            sn = snaps.get((gid, str(at)), {})
            osn = snaps.get((gid, str(1 - at)), {})
            res_txt = {1.0: "win", 0.0: "loss", 0.75: "lead at 30:00", 0.25: "behind at 30:00", 0.5: "even"}[sc]
            a5 = num(sn.get("300", {}).get("army_value")) if sn.get("300") else None
            o5 = num(osn.get("300", {}).get("army_value")) if osn.get("300") else None
            rows.append([gid, g["map"].replace("_", " "), "%s %s" % (g["b"], sp["ob"]), res_txt + " (%s, %s)" % (g["cause"], mmss(g["end_t"])),
                         fmt(a5), fmt(o5), mmss(o.get("first_scripted_attack")), fmt(num(o.get("scripted_kills"))),
                         fmt(num(sd.get("workers_lost"))), mmss(o.get("script_end_t"))])
        say(table(["game", "map", "against", "result", "its army 5:00", "theirs 5:00", "first scripted attack",
                   "scripted attacks killed", "own workers lost", "script ended"], rows))
        say("")
        # a short automatic reading of why it works
        a5s = [num(snaps[(gid, str(at))]["300"]["army_value"]) for gid, at, sp, g, sc in rec if "300" in snaps[(gid, str(at))]]
        b5 = med(base5.get(f, []))
        kills = [num(ops.get((gid, str(at)), {}).get("scripted_kills"), 0) for gid, at, sp, g, sc in rec]
        firsts = [num(ops.get((gid, str(at)), {}).get("first_scripted_attack")) for gid, at, sp, g, sc in rec]
        firsts = [x for x in firsts if x is not None]
        lens = [num(g["end_t"]) for gid, at, sp, g, sc in rec if sc == 1.0]
        if a5s and b5:
            m5 = med(a5s)
            if m5 > 1.25 * b5:
                why.append("it has more army at 5:00 than the documented %s openings (%s against a median of %s)" % (FNAME[f], fmt(m5), fmt(b5)))
            elif m5 < 0.75 * b5:
                why.append("it is light on army at 5:00 (%s against a median of %s for the documented openings), so its edge comes later" % (fmt(m5), fmt(b5)))
        if firsts:
            why.append("its scripted attack goes out at %s" % mmss(med(firsts)) + (" and kills %s worth on the way" % fmt(med(kills)) if med(kills) else ""))
        if lens:
            why.append("its wins come at a median of %s" % mmss(med(lens)))
        steps = cand.get("steps", [])
        wn = [int(s.split(":")[1]) for s in steps if s.startswith("workers:")]
        if wn:
            why.append("it trains up to %d workers in the script" % max(wn))
        if any("@proxy" in s for s in steps):
            why.append("it builds forward (a proxy)")
        if why:
            say("What the numbers say: " + "; ".join(why) + ". With so few games each, treat it as a lead to test, not a result.")
            say("")
    # what the search tried: success by kind of mutation
    mc = defaultdict(list)
    for fit, c, cand, rec, scores in stats:
        labs = cand.get("mutations", [])
        last = labs[-1] if labs else []
        kinds = set()
        for lab in last:
            kinds.add(lab.split(" ")[0] if not lab.startswith("fast") else "fast expansion")
        if cand.get("origin") == "grammar" and not labs:
            kinds = {"fresh build"}
        for k in kinds:
            mc[k] += scores
    rows = []
    for k, sc in sorted(mc.items(), key=lambda kv: -len(kv[1])):
        rows.append([k, len(sc), "%.2f" % (sum(sc) / len(sc))])
    if rows:
        say("### What kind of change paid")
        say("")
        say("The mean game score of candidates by the last change made to them (1 is always winning, 0.5 even).")
        say("")
        say(table(["change", "games", "mean score"], rows))
        say("")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("aggregate")
    p.add_argument("--runs", required=True)
    p.add_argument("--machine", required=True, help="m1, m2, m3 or m4 (any short name)")
    p.add_argument("--data", default=os.path.join(HERE, "..", "..", "docs", "study_v2", "data"))
    p = sub.add_parser("combine")
    p.add_argument("--data", default=os.path.join(HERE, "..", "..", "docs", "study_v2", "data"))
    p.add_argument("--old", default=os.path.join(HERE, "..", "..", "docs", "study_data"))
    p.add_argument("--out", default=os.path.join(HERE, "..", "..", "docs", "ai_balance_study_v2.md"))
    p.add_argument("--min-pair", type=int, default=5)
    p.add_argument("--outlier", type=float, default=0.7)
    p.add_argument("--max-outliers", type=int, default=6)
    p = sub.add_parser("check")
    p.add_argument("--runs", required=True)
    a = ap.parse_args()
    {"aggregate": cmd_aggregate, "combine": cmd_combine, "check": cmd_check}[a.cmd](a)


if __name__ == "__main__":
    main()
