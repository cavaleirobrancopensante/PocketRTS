#!/usr/bin/env python3
"""The Clockwork v Crown economy study's tables and charts (docs/cw_economy_study.md).

    python3 tools/study/cw_economy_report.py RESULTS.jsonl [OUT_DIR]

RESULTS.jsonl: the RESULT lines of tools/measure_economy.gd (tools/study/cw_economy_run.sh writes them). Prints markdown
tables; writes PNG charts to OUT_DIR (default docs/shots/cw_economy)."""
import json
import os
import sys
from statistics import mean

TENSION_UNITS = ["springer", "netter", "pendulum", "ballista", "great_winder", "cuckoo", "ticking_owl"]
NAMES = {"springer": "Springer", "netter": "Netter", "pendulum": "Pendulum", "ballista": "Ballista", "great_winder": "Great Winder",
         "cuckoo": "Swift", "ticking_owl": "Owl"}


def load(path):
    out = []
    for line in open(path):
        line = line.strip()
        if line:
            r = json.loads(line)
            # GROSS income: the Clockwork's stats "gold" is net of the repairs it pays (Unit's repair draws on the same
            # fraction the presses fill), so its earned = presses + sweep; the Crown's "gold" is the farms' harvests
            for row in r["min"]:
                for x in row:
                    x["earned_stat"] = x["earned"]
                    if x["fac"] == "clockwork":
                        x["earned"] = x["press"] + x["sweep"]
            out.append(r)
    return out


def defs_costs():
    """kind -> (cost, tension, cost2), read from scripts/defs.gd (the first "cost" in the three lines after `"kind": {`)."""
    import re
    lines = open(os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "defs.gd")).read().split("\n")
    out = {}
    for i, l in enumerate(lines):
        m = re.match(r'^\t"([a-z_]+)": \{\s*$', l)
        if not m:
            continue
        for j in range(i + 1, min(i + 4, len(lines))):
            c = re.search(r'"cost": (\d+)', lines[j])
            if c:
                t = re.search(r'"tension": (\d+)', lines[j])
                c2 = re.search(r'"cost2": (\d+)', lines[j])
                out.setdefault(m.group(1), (int(c.group(1)), int(t.group(1)) if t else 0, int(c2.group(1)) if c2 else 0))
                break
    out["ticking_owl"] = (100, 50, 0)      # (a Swift's MORPH TO OWL: Defs.OWL_MORPH)
    out["dismounted"] = (0, 0, 0)          # (a Cuirassier off his horse: no new purchase)
    return out


CATS = {"supply": ["cottage", "regulator"], "economy": ["farm", "powder_mill", "cog_press", "mainspring"], "halls": ["town_hall", "clocktower"]}


def spend(r, side, costs):
    """What side spent by the end (counted from what it built and trained), by category."""
    out = {"supply": 0, "economy": 0, "halls": 0, "other buildings": 0, "workers": 0, "army": 0, "horses": 0}
    for k, n in r["built%d" % side].items():
        c = costs.get(k, (0, 0, 0))[0] * n
        cat = next((c2 for c2, ks in CATS.items() if k in ks), "other buildings")
        out[cat] += c
    for k, n in r["trained%d" % side].items():
        c = costs.get(k, (0, 0, 0))[0] * n
        if k in ("labourer", "winder"):
            out["workers"] += c
        elif k == "horse":
            out["horses"] += c
        else:
            out["army"] += c
    return out


def kind(r):
    t = r["tag"]
    return t.rsplit("_", 2)[0]       # cw_idle_ms0, cr_idle, hvh_ms0


def at(r, side, m, key, default=None):
    """The value of `key` for side `side` at minute m (the last row at or before m)."""
    best = default
    for row in r["min"]:
        s = row[side]
        if s["m"] <= m:
            best = s.get(key, default)
    return best


def side_of(r, fac):
    return 0 if r["a"] == fac else 1


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, float):
        return f"{v:,.0f}"
    return f"{v:,}"


def mrange(vals):
    vals = [v for v in vals if v is not None]
    if not vals:
        return "-"
    if len(vals) == 1:
        return fmt(vals[0])
    return f"{mean(vals):,.0f} ({min(vals):,.0f}-{max(vals):,.0f})"


def per_min(r, side, key):
    rows = [row[side] for row in r["min"]]
    out = []
    prev = 0
    for s in rows:
        out.append(s[key] - prev)
        prev = s[key]
    return out


def main():
    rs = load(sys.argv[1])
    outdir = sys.argv[2] if len(sys.argv) > 2 else "docs/shots/cw_economy"
    os.makedirs(outdir, exist_ok=True)
    groups = {}
    for r in rs:
        groups.setdefault(kind(r), []).append(r)
    print("runs:", {k: len(v) for k, v in sorted(groups.items())})
    mins = [3, 5, 6, 8, 10, 12, 15]

    # ---- 1. against the idle dummy: earned, by minute
    print("\n## Earned against an idle dummy (mean (min-max); games: %s)\n" % {k: len(v) for k, v in sorted(groups.items())})
    print("| | " + " | ".join(f"{m}:00" for m in mins) + " |")
    print("|---|" + "---|" * len(mins))
    for g, fac, label in [("cr_idle", "crown", "Crown gold"), ("cw_idle_ms0", "clockwork", "Clockwork cogs (today)"),
                          ("cw_idle_ms2", "clockwork", "Clockwork cogs, 2 Mainsprings/tower"), ("cw_idle_ms1", "clockwork", "Clockwork cogs, 1 Mainspring/tower")]:
        rr = groups.get(g, [])
        if not rr:
            continue
        print(f"| {label} | " + " | ".join(mrange([at(r, side_of(r, fac), m, "earned") for r in rr]) for m in mins) + " |")
    for g, fac, key, label in [("cr_idle", "crown", "powder_in", "Crown powder"), ("cw_idle_ms0", "clockwork", "tension_in", "Clockwork Tension (today)"),
                               ("cw_idle_ms2", "clockwork", "tension_in", "Tension, 2/tower"), ("cw_idle_ms1", "clockwork", "tension_in", "Tension, 1/tower")]:
        rr = groups.get(g, [])
        if rr:
            print(f"| {label} | " + " | ".join(mrange([at(r, side_of(r, fac), m, key) for r in rr]) for m in mins) + " |")
    # ratio
    cr = groups.get("cr_idle", [])
    cw = groups.get("cw_idle_ms0", [])
    if cr and cw:
        print("| **ratio Clockwork / Crown** | " + " | ".join(
            "%.2f" % (mean([at(r, side_of(r, "clockwork"), m, "earned") for r in cw]) / max(1, mean([at(r, side_of(r, "crown"), m, "earned") for r in cr]))) for m in mins) + " |")

    # ---- workers, halls, army
    print("\n## Workers / halls / army value against the idle dummy (mean)\n")
    print("| | " + " | ".join(f"{m}:00" for m in mins) + " |")
    print("|---|" + "---|" * len(mins))
    for g, fac, label in [("cr_idle", "crown", "Crown"), ("cw_idle_ms0", "clockwork", "Clockwork today"), ("cw_idle_ms1", "clockwork", "Clockwork 1/tower")]:
        rr = groups.get(g, [])
        if not rr:
            continue
        for key, nm in [("workers", "workers"), ("halls", "halls"), ("army", "army value"), ("bank", "bank")]:
            print(f"| {label} {nm} | " + " | ".join(fmt(round(mean([at(r, side_of(r, fac), m, key) or 0 for r in rr]))) for m in mins) + " |")

    # ---- per-minute income
    print("\n## Income per minute (mean)\n")
    rowsm = list(range(1, 16))
    print("| | " + " | ".join(str(m) for m in rowsm) + " |")
    print("|---|" + "---|" * len(rowsm))
    curves = {}
    for g, fac, key, label in [("cr_idle", "crown", "earned", "Crown gold"), ("cr_idle", "crown", "powder_in", "Crown powder"),
                               ("cw_idle_ms0", "clockwork", "earned", "Clockwork cogs"), ("cw_idle_ms0", "clockwork", "tension_in", "Clockwork Tension"),
                               ("cw_idle_ms1", "clockwork", "earned", "Clockwork cogs 1/tower"), ("cw_idle_ms1", "clockwork", "tension_in", "Tension 1/tower")]:
        rr = groups.get(g, [])
        if not rr:
            continue
        pm = [per_min(r, side_of(r, fac), key) for r in rr]
        n = min(len(p) for p in pm)
        avg = [mean(p[i] for p in pm) for i in range(n)]
        curves[label] = avg
        print(f"| {label} | " + " | ".join(fmt(round(v)) for v in avg) + " |")

    # ---- Clockwork income by source
    print("\n## Clockwork income by source, against the idle dummy, today's rules (each game)\n")
    print("| Game | cogs by 15:00 | presses (each, in build order) | sweep | other | Tension (each Mainspring) | pool full (s) | lode left (of) | presses / big / crew at 15 |")
    print("|---|---|---|---|---|---|---|---|---|")
    for g in ["cw_idle_ms0", "cw_idle_ms2", "cw_idle_ms1"]:
        for r in groups.get(g, []):
            s = side_of(r, "clockwork")
            last = r["min"][-1][s]
            print(f"| {g} {r['map']} {r['seed']} | {fmt(last['earned'])} | {', '.join(fmt(x) for x in last['presses'])} | {fmt(last['sweep'])} | {fmt(last['other'])} | "
                  f"{fmt(last['tension_in'])} ({', '.join(fmt(x) for x in last['springs'])}) | {fmt(last['full_s'])} | {fmt(last['lode'])} ({fmt(last['lode_full'])}) | "
                  f"{last['n_press']} / {last['n_press_big']} / {last['crew_press']} |")

    # ---- Mainspring variants
    print("\n## The Mainspring question (against the idle dummy; mean (min-max))\n")
    print("| | Mainsprings at 15 | Tension by 8 / 15 | pool full, s | Tension spent units / buildings | army 5:00 | army 8:00 | army 12:00 | cogs by 15 | first Escapement | first Heavy Works | first Aviary | Tension units by 15 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for g, label in [("cw_idle_ms0", "today (no cap)"), ("cw_idle_ms2", "2 per tower"), ("cw_idle_ms1", "1 per tower")]:
        rr = groups.get(g, [])
        if not rr:
            continue
        s = lambda r: side_of(r, "clockwork")
        tu = {}
        for r in rr:
            for k in TENSION_UNITS:
                tu[k] = tu.get(k, 0) + r["trained%d" % s(r)].get(k, 0)
        tus = ", ".join(f"{NAMES[k]} {tu[k] / len(rr):.1f}" for k in TENSION_UNITS if tu.get(k, 0))
        def first(r, k):
            return r["firsts%d" % s(r)].get(k)
        def mm(v):
            v = [x for x in v if x is not None]
            return ("%d:%02d" % divmod(int(mean(v)), 60)) + (f" ({len(v)}/{len(rr)})" if len(v) < len(rr) else "") if v else "never"
        print(f"| {label} | {mrange([at(r, s(r), 15, 'n_spring') for r in rr])} | {mrange([at(r, s(r), 8, 'tension_in') for r in rr])} / {mrange([at(r, s(r), 15, 'tension_in') for r in rr])} | "
              f"{mrange([at(r, s(r), 15, 'full_s') for r in rr])} | {mrange([at(r, s(r), 15, 'spend_t_units') for r in rr])} / {mrange([at(r, s(r), 15, 'spend_t_bld') for r in rr])} | "
              f"{mrange([at(r, s(r), 5, 'army') for r in rr])} | {mrange([at(r, s(r), 8, 'army') for r in rr])} | {mrange([at(r, s(r), 12, 'army') for r in rr])} | "
              f"{mrange([at(r, s(r), 15, 'earned') for r in rr])} | {mm([first(r, 'escapement') for r in rr])} | {mm([first(r, 'heavy_works') for r in rr])} | "
              f"{mm([first(r, 'cuckoo_house') for r in rr])} | {tus} |")

    # ---- the late game, decomposed: what the empty-building TRICKLE pays (a Farm 15% of 9.5 g/s = 85.5 gold a minute, a
    # small Cog Press 15% of 8 = 72 cogs a minute, with nobody on it) and what each worker on it adds (a Labourer 0.85 x
    # 9.5 / 8 x 60 = 60.6 a minute, a Winder on a small press 0.85 x 8 / 6 x 60 = 68)
    print("\n## Late income decomposed (mean against the idle dummy): buildings, crews, the model's trickle + crew, the measured minute\n")
    print("| minute | Crown halls / Farms / farm crew | Crown trickle + crew = model | Crown measured (that minute, mean of the 3 minutes round it) | Clockwork towers / presses / press crew | Clockwork trickle + crew = model | Clockwork measured |")
    print("|---|---|---|---|---|---|---|")
    for m in (4, 6, 8, 10, 12, 14):
        cells = []
        for g, fac, nb, cr, tr, per in [("cr_idle", "crown", "n_farm", "crew_farm", 85.5, 60.6), ("cw_idle_ms0", "clockwork", "n_press", "crew_press", 72.0, 68.0)]:
            rr = groups.get(g, [])
            if not rr:
                cells += ["-", "-", "-"]
                continue
            h = mean(at(r, side_of(r, fac), m, "halls") for r in rr)
            n = mean(at(r, side_of(r, fac), m, nb) for r in rr)
            c = mean(at(r, side_of(r, fac), m, cr) for r in rr)
            meas = mean(mean(per_min(r, side_of(r, fac), "earned")[max(0, m - 2):m + 1]) for r in rr)
            cells += [f"{h:.1f} / {n:.1f} / {c:.0f}", f"{tr * n:,.0f} + {per * c:,.0f} = {tr * n + per * c:,.0f}", f"{meas:,.0f}"]
        print(f"| {m}:00 | " + " | ".join(cells) + " |")

    # ---- Crown late game
    print("\n## The Crown's late game against the idle dummy (each game: halls / farms / farm crew / soil left / gold that minute)\n")
    for r in groups.get("cr_idle", []):
        s = side_of(r, "crown")
        pm = per_min(r, s, "earned")
        cells = []
        for i, row in enumerate(r["min"]):
            x = row[s]
            if x["m"] in (6, 8, 10, 12, 14, 15):
                cells.append(f"{x['m']}: {x['halls']}h {x['n_farm']}f {x['crew_farm']}c soil {x['soil']:,} +{pm[i]:,}")
        print(f"- {r['map']} {r['seed']}: " + "; ".join(cells))

    # ---- spending
    costs = defs_costs()
    print("\n## Where the money went by 15:00 against the idle dummy (mean; from what was built and trained, start buildings excluded)\n")
    cols = ["supply", "economy", "halls", "other buildings", "workers", "horses", "army"]
    print("| | " + " | ".join(cols) + " | total counted | the game's own \"spent\" (all of it: research, kits, repairs too) |")
    print("|---|" + "---|" * (len(cols) + 2))
    for g, fac, label in [("cr_idle", "crown", "Crown"), ("cw_idle_ms0", "clockwork", "Clockwork today"), ("cw_idle_ms1", "clockwork", "Clockwork 1/tower")]:
        # (only games that counted buildings once finished: they carry the game's own "spent" stat)
        rr = [r for r in groups.get(g, []) if "spent_stat" in r["min"][-1][side_of(r, fac)]]
        if not rr:
            continue
        sp = [spend(r, side_of(r, fac), costs) for r in rr]
        st = [r["min"][-1][side_of(r, fac)]["spent_stat"] for r in rr]
        print(f"| {label} ({len(rr)} games) | " + " | ".join(fmt(round(mean(x[c] for x in sp))) for c in cols) +
              f" | {fmt(round(mean(sum(x.values()) for x in sp)))} | {fmt(round(mean(st)))} |")

    # ---- head to head
    print("\n## Hard Crown v Hard Clockwork (fighting)\n")
    print("| Game | Mainsprings | result | Crown earned 6 / 10 / 15 | Clockwork earned 6 / 10 / 15 | army 5 / 8 / 12 (Crown v Clockwork) | Clockwork springs at end | killed (Crown / Clockwork) |")
    print("|---|---|---|---|---|---|---|---|")
    for g in ["hvh_ms0", "hvh_ms1"]:
        for r in groups.get(g, []):
            c, w = side_of(r, "crown"), side_of(r, "clockwork")
            res = "draw" if r["winner"] < 0 else (("Crown" if r["winner"] == c else "Clockwork") + " won %d:%02d" % divmod(r["end"], 60))
            arm = " / ".join(f"{fmt(at(r, c, m, 'army'))} v {fmt(at(r, w, m, 'army'))}" for m in (5, 8, 12))
            last = r["min"][-1]
            print(f"| {r['map']} {r['seed']} | {'1/tower' if r['ms'] == 1 else 'today'} | {res} | " + " / ".join(fmt(at(r, c, m, 'earned')) for m in (6, 10, 15)) + " | "
                  + " / ".join(fmt(at(r, w, m, 'earned')) for m in (6, 10, 15)) + f" | {arm} | {last[w].get('n_spring')} | {fmt(last[c]['killed'])} / {fmt(last[w]['killed'])} |")

    # ---- charts
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return
    plt.rcParams.update({"font.size": 10})
    col = {"crown": "#2a6fdb", "clockwork": "#c9822b", "ms1": "#7a4fb5", "ms2": "#3aa37a"}
    # cumulative earned
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    for g, fac, label, c, ls in [("cr_idle", "crown", "Crown gold", col["crown"], "-"), ("cw_idle_ms0", "clockwork", "Clockwork cogs (today)", col["clockwork"], "-"),
                                 ("cw_idle_ms2", "clockwork", "Clockwork, 2 Mainsprings/tower", col["ms2"], "--"), ("cw_idle_ms1", "clockwork", "Clockwork, 1 Mainspring/tower", col["ms1"], ":")]:
        rr = groups.get(g, [])
        if not rr:
            continue
        xs = list(range(1, 16))
        ys = [mean([at(r, side_of(r, fac), m, "earned") or 0 for r in rr]) for m in xs]
        ax.plot(xs, ys, ls, color=c, lw=2, label=label)
    ax.set_xlabel("minute")
    ax.set_ylabel("earned so far")
    ax.set_title("Earned against an idle dummy (Hard, peaceful; mean of each set's games)")
    ax.grid(alpha=0.3)
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "earned_cumulative.png"), dpi=110)
    plt.close(fig)
    # per minute
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    for label, c, ls in [("Crown gold", col["crown"], "-"), ("Clockwork cogs", col["clockwork"], "-"), ("Clockwork cogs 1/tower", col["ms1"], ":"),
                         ("Crown powder", col["crown"], "--"), ("Clockwork Tension", col["clockwork"], "--"), ("Tension 1/tower", col["ms1"], "-.")]:
        if label in curves:
            ax.plot(range(1, len(curves[label]) + 1), curves[label], ls, color=c, lw=2, label=label)
    ax.set_xlabel("minute")
    ax.set_ylabel("earned in that minute")
    ax.set_title("Income per minute against an idle dummy (mean of each set's games)")
    ax.grid(alpha=0.3)
    ax.legend(frameon=False, ncol=2)
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "income_per_minute.png"), dpi=110)
    plt.close(fig)
    # army value
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    for g, fac, label, c, ls in [("cr_idle", "crown", "Crown", col["crown"], "-"), ("cw_idle_ms0", "clockwork", "Clockwork today", col["clockwork"], "-"),
                                 ("cw_idle_ms2", "clockwork", "Clockwork 2/tower", col["ms2"], "--"), ("cw_idle_ms1", "clockwork", "Clockwork 1/tower", col["ms1"], ":")]:
        rr = groups.get(g, [])
        if not rr:
            continue
        xs = list(range(1, 16))
        ax.plot(xs, [mean([at(r, side_of(r, fac), m, "army") or 0 for r in rr]) for m in xs], ls, color=c, lw=2, label=label)
    ax.set_xlabel("minute")
    ax.set_ylabel("army value (cost + powder / Tension)")
    ax.set_title("Army value against an idle dummy (peaceful; mean of each set's games)")
    ax.grid(alpha=0.3)
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "army_value.png"), dpi=110)
    plt.close(fig)
    # lode / soil left
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    for g, fac, key, label, c in [("cr_idle", "crown", "soil", "Crown soil left (all halls)", col["crown"]), ("cw_idle_ms0", "clockwork", "lode", "Clockwork brass left (all towers)", col["clockwork"])]:
        rr = groups.get(g, [])
        if rr:
            xs = list(range(1, 16))
            ax.plot(xs, [mean([at(r, side_of(r, fac), m, key) or 0 for r in rr]) for m in xs], color=c, lw=2, label=label)
    ax.set_xlabel("minute")
    ax.set_ylabel("left in the ground")
    ax.set_title("What the land holds (mean, against an idle dummy)")
    ax.grid(alpha=0.3)
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "land_left.png"), dpi=110)
    plt.close(fig)


if __name__ == "__main__":
    main()
