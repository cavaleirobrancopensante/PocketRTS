#!/usr/bin/env python3
"""Batch runner for the AI balance study (measurement only; it never touches game code).

  nohup python3 tools/study/run_study.py --out /home/claude/study_runs --games 30 > run.out 2>&1 &

* 6 unordered matchups (3 mirrors + 3 cross pairs), Hard AI both sides, 30 game minutes.
* Games are scheduled ROUND-MAJOR: round n holds game n of every matchup, so at any moment every matchup has
  (nearly) the same number of games. Stage 1 = rounds 0..3 (4 games per matchup), then more rounds.
* Crash-safe and resumable: a game is done when <out>/games/<id>.json exists (the game script writes it last, by
  rename). Re-running skips finished games. A game whose process dies or hangs is logged to <out>/failures.jsonl
  with its seed/map and retried once; after two failures it is skipped.
* Stop cleanly: touch <out>/STOP (no new game starts; running ones finish).
* At most --workers games at once (the box has 2 cores).
"""
import argparse, concurrent.futures as cf, json, os, subprocess, sys, time

GODOT = os.environ.get("GODOT", "/home/claude/godot/godot")
PROJECT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

PAIRS = [("crown", "crown"), ("brood", "brood"), ("clockwork", "clockwork"),
         ("crown", "brood"), ("crown", "clockwork"), ("brood", "clockwork")]
# the first four are the maps the owner named; the rest add spread (named 1v1 maps and generated classic ones)
MAPS = ["greenhold", "frostmere", "ashford_crossing", "amberfall_vale", "kestrel_rise", "glimmerdeep",
        "hollowfen", "highmoor", "thornwood_maze", "saltmarsh_isles", "twin_fords", "cinder_steps"]
# (plan of A, plan of B) cycle of 11 (coprime with the 12 maps and the 2 sides): 7 Balanced, 2 Rush, 2 Timing attack
PLAN_CYCLE = [("balanced", "balanced")] * 4 + [("rush", "balanced"), ("balanced", "rush"), ("timing", "balanced"),
                                                 ("balanced", "timing"), ("balanced", "balanced"),
                                                 ("balanced", "balanced"), ("balanced", "balanced")]


def spec(pair_i, n):
    a, b = PAIRS[pair_i]
    m = len(MAPS)
    swap = (n + n // m) % 2
    pa, pb = PLAN_CYCLE[n % len(PLAN_CYCLE)]
    # the Brood's Rush alternates with its Extreme rush (the owner's six-pool anchor) every other time
    if (n // len(PLAN_CYCLE)) % 2 == 1:
        if a == "brood" and pa == "rush":
            pa = "xrush"
        if b == "brood" and pb == "rush":
            pb = "xrush"
    return {
        "id": "%s-%s_%03d" % (a, b, n), "a": a, "b": b, "pa": pa, "pb": pb, "map": MAPS[n % m],
        "seed": 100000 + 1000 * pair_i + 37 * n + 11, "swap": swap, "n": n, "pair": pair_i,
    }


def run_game(out, s, end, wall_limit):
    gid = s["id"]
    cmd = [GODOT, "--headless", "--fixed-fps", "30", "--path", PROJECT, "--script", "res://tools/study/study_game.gd", "--",
           "a:" + s["a"], "b:" + s["b"], "pa:" + s["pa"], "pb:" + s["pb"], "map:" + s["map"], "seed:%d" % s["seed"],
           "swap:%d" % s["swap"], "out:" + out, "id:" + gid, "end:%d" % end, "fast:1", "gg:1"]
    t0 = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=wall_limit)
        rc, tail = p.returncode, (p.stdout + p.stderr)[-3000:]
    except subprocess.TimeoutExpired as e:
        rc, tail = -9, "TIMEOUT after %ds\n%s" % (wall_limit, ((e.stdout or b"")[-2000:]).decode("utf8", "ignore") if isinstance(e.stdout, bytes) else str(e.stdout)[-2000:])
    ok = os.path.exists(os.path.join(out, "games", gid + ".json"))
    return ok, rc, tail, time.time() - t0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/home/claude/study_runs")
    ap.add_argument("--games", type=int, default=30, help="games per matchup to schedule (round-major)")
    ap.add_argument("--first", type=int, default=0, help="first round to run")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--end", type=int, default=1800)
    ap.add_argument("--wall-limit", type=int, default=3000, help="kill a game after this many real seconds")
    a = ap.parse_args()
    out = a.out
    os.makedirs(out + "/games", exist_ok=True)
    for sub in ("games", "ts", "logs"):
        d = os.path.join(out, sub)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            if f.endswith(".tmp"):
                os.remove(os.path.join(d, f))
    fails = {}
    fp = out + "/failures.jsonl"
    if os.path.exists(fp):
        for line in open(fp):
            try:
                r = json.loads(line)
                fails[r["id"]] = fails.get(r["id"], 0) + 1
            except Exception:
                pass
    todo = []
    for n in range(a.first, a.games):
        for pi in range(len(PAIRS)):
            s = spec(pi, n)
            if os.path.exists("%s/games/%s.json" % (out, s["id"])) or fails.get(s["id"], 0) >= 2:
                continue
            todo.append(s)
    log = open(out + "/run.log", "a", buffering=1)

    def say(msg):
        line = "%s %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
        print(line, flush=True)
        log.write(line + "\n")

    say("start: %d games to run (workers %d)" % (len(todo), a.workers))

    def job(s):
        if os.path.exists(out + "/STOP"):
            return s, None
        for attempt in range(2 - fails.get(s["id"], 0)):
            ok, rc, tail, secs = run_game(out, s, a.end, a.wall_limit)
            if ok:
                return s, (rc, secs)
            with open(fp, "a") as f:
                f.write(json.dumps({"id": s["id"], "spec": s, "rc": rc, "secs": round(secs), "tail": tail, "when": time.time()}) + "\n")
        return s, "failed"

    done = 0
    with cf.ThreadPoolExecutor(a.workers) as ex:
        futs = [ex.submit(job, s) for s in todo]
        for fut in cf.as_completed(futs):
            s, r = fut.result()
            done += 1
            if r is None:
                say("skipped (STOP) %s" % s["id"])
            elif r == "failed":
                say("FAILED %s map=%s seed=%d" % (s["id"], s["map"], s["seed"]))
            else:
                say("done %s %s/%s %s/%s %s seed=%d in %ds (%d/%d)" % (s["id"], s["a"], s["b"], s["pa"], s["pb"], s["map"], s["seed"], r[1], done, len(todo)))
    say("finished")


if __name__ == "__main__":
    main()
