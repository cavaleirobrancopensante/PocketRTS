#!/usr/bin/env python3
"""Balance study v2 (docs/study_v2.md): the batch runner. Measurement only; it never touches game code.

Every game is tools/study/study_game_v2.gd: study_game.gd's full recording, and either side may open with a documented
build order (tools/study/build_orders.json, played by bo_ai_v2.gd), then play on as the Hard computer.

  python3 tools/study/run_study_v2.py --mode openings --pair crown,brood --games 100 --out /path/runs
  python3 tools/study/run_study_v2.py --mode explore --games 100 --out /path/runs
  python3 tools/study/run_study_v2.py --mode check --out /path/check            (every build once, 8 minutes)

* openings: game n of a pair is on MAPS[n % 12], sides swapped half the time, a fixed seed; each side's opening is
  drawn from its faction's working builds (not "retired" in build_orders.json) by a seeded shuffled deck, so every
  opening gets an equal share (within one) and the order is random. The draw is in games/<id>.json ("opening_a/b").
* explore: an evolutionary search for outlier openings (tools/study/explore_v2.py); every candidate's full script is in
  <out>/explore/candidates/<id>.json and travels in its game's JSON ("builds_used").
* check: one game per working build, 8 minutes, against the plain Hard computer of the next faction, gg off.
* Resumable: a game is done when <out>/games/<id>.json exists. A game whose process dies or hangs goes to
  <out>/failures.jsonl and is tried once more. touch <out>/STOP to stop after the games under way.
* At most --workers games at once (default 2: the machines have about 2 cores). Each Godot run's output goes through
  `head -c 20000000` into <out>/proc/<id>.txt (removed when the game is fine), so a looping error can't fill the disk.
"""
import argparse, concurrent.futures as cf, json, os, random, shutil, signal, subprocess, sys, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
GODOT = os.environ.get("GODOT") or shutil.which("godot") or "/usr/local/bin/godot"
FACTIONS = ["crown", "brood", "clockwork"]
PAIR_INDEX = {("crown", "brood"): 0, ("crown", "clockwork"): 1, ("brood", "clockwork"): 2}
# the 12 maps of the first balance study (tools/study/run_study.py), in the same rotation
MAPS = ["greenhold", "frostmere", "ashford_crossing", "amberfall_vale", "kestrel_rise", "glimmerdeep",
        "hollowfen", "highmoor", "thornwood_maze", "saltmarsh_isles", "twin_fords", "cinder_steps"]
OUT_CAP = 20000000


def load_builds(path=None):
    j = json.load(open(path or os.path.join(HERE, "build_orders.json")))
    return {b["name"]: b for b in j["builds"]}


def working_builds(faction, builds=None):
    builds = builds or load_builds()
    return sorted(n for n, b in builds.items() if b["faction"] == faction and not b.get("retired"))


def deck_pick(names, seed, n):
    """The n-th draw from a seeded shuffled deck: every name once per len(names) games, in a random order."""
    L = len(names)
    block, k = divmod(n, L)
    deck = list(names)
    random.Random("%d:%d" % (seed, block)).shuffle(deck)
    return deck[k]


def openings_spec(pair, n):
    a, b = pair
    pi = PAIR_INDEX[(a, b)]
    m = len(MAPS)
    swap = (n + n // m) % 2
    seed = 400000 + 1000 * pi + 37 * n + 11
    oa = deck_pick(working_builds(a), 9100 + 10 * pi, n)
    ob = deck_pick(working_builds(b), 9200 + 10 * pi, n)
    return {"id": "%s-%s_%03d" % (a, b, n), "a": a, "b": b, "oa": oa, "ob": ob, "map": MAPS[n % m], "seed": seed,
            "swap": swap, "n": n}


CHECK_OPP = {"crown": "brood", "brood": "clockwork", "clockwork": "crown"}


def check_specs(names=None):
    builds = load_builds()
    out = []
    for i, nm in enumerate(sorted(builds)):           # (the seed follows the build's place in the whole list)
        b = builds[nm]
        if (names and nm not in names) or (b.get("retired") and not names):
            continue
        out.append({"id": "check_" + nm, "a": b["faction"], "b": CHECK_OPP[b["faction"]], "oa": nm, "ob": "ai",
                    "pb": "balanced", "map": "ashford_crossing", "seed": 777001 + i, "swap": 0, "n": i})
    return out


def _godot_cmd(out, s, end, gg, extra=None):
    cmd = [GODOT, "--headless", "--fixed-fps", "30", "--path", PROJECT, "--script", "res://tools/study/study_game_v2.gd", "--",
           "a:" + s["a"], "b:" + s["b"], "oa:" + s.get("oa", "ai"), "ob:" + s.get("ob", "ai"),
           "pa:" + s.get("pa", "balanced"), "pb:" + s.get("pb", "balanced"), "map:" + s["map"], "seed:%d" % s["seed"],
           "swap:%d" % s["swap"], "out:" + out, "id:" + s["id"], "end:%d" % end, "fast:1", "gg:%d" % gg]
    if s.get("builds"):
        cmd.append("builds:" + s["builds"])
    return cmd + (extra or [])


def run_game(out, s, end, gg, wall_limit):
    """One game in its own process group; its output capped by head -c. Returns (ok, rc, tail, seconds)."""
    gid = s["id"]
    os.makedirs(out + "/proc", exist_ok=True)
    proc_path = "%s/proc/%s.txt" % (out, gid)
    cmd = " ".join("'" + c.replace("'", "'\\''") + "'" for c in _godot_cmd(out, s, end, gg))
    sh = "%s 2>&1 | head -c %d > '%s'" % (cmd, OUT_CAP, proc_path)
    t0 = time.time()
    p = subprocess.Popen(["bash", "-c", sh], start_new_session=True)
    try:
        rc = p.wait(timeout=wall_limit)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except Exception:
            pass
        p.wait()
        rc = -9
    tail = ""
    try:
        with open(proc_path, "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 3000))
            tail = f.read().decode("utf8", "ignore")
    except Exception:
        pass
    ok = os.path.exists(os.path.join(out, "games", gid + ".json"))
    if ok:
        try:
            os.remove(proc_path)
        except Exception:
            pass
    return ok, rc, tail, time.time() - t0


class Runner:
    def __init__(self, out, workers, end, gg, wall_limit):
        self.out, self.workers, self.end, self.gg, self.wall_limit = out, workers, end, gg, wall_limit
        for sub in ("games", "ts", "logs"):
            d = os.path.join(out, sub)
            os.makedirs(d, exist_ok=True)
            for f in os.listdir(d):
                if f.endswith(".tmp"):
                    os.remove(os.path.join(d, f))
        self.fails = {}
        self.fp = out + "/failures.jsonl"
        if os.path.exists(self.fp):
            for line in open(self.fp):
                try:
                    r = json.loads(line)
                    self.fails[r["id"]] = self.fails.get(r["id"], 0) + 1
                except Exception:
                    pass
        self.logf = open(out + "/run.log", "a", buffering=1)
        self.lock = threading.Lock()

    def say(self, msg):
        line = "%s %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
        with self.lock:
            print(line, flush=True)
            self.logf.write(line + "\n")

    def done(self, gid):
        return os.path.exists("%s/games/%s.json" % (self.out, gid))

    def given_up(self, gid):
        return self.fails.get(gid, 0) >= 2

    def stopped(self):
        return os.path.exists(self.out + "/STOP")

    def play(self, s):
        """Play one spec (with one retry). Returns seconds, or None (failed / stopped)."""
        for _ in range(2 - self.fails.get(s["id"], 0)):
            if self.stopped():
                return None
            ok, rc, tail, secs = run_game(self.out, s, s.get("end", self.end), self.gg if "gg" not in s else s["gg"], self.wall_limit)
            if ok:
                return secs
            with self.lock:
                self.fails[s["id"]] = self.fails.get(s["id"], 0) + 1
                with open(self.fp, "a") as f:
                    f.write(json.dumps({"id": s["id"], "spec": s, "rc": rc, "secs": round(secs), "tail": tail, "when": time.time()}) + "\n")
            self.say("game %s failed (rc %s); %s" % (s["id"], rc, "trying again" if self.fails[s["id"]] < 2 else "giving up"))
        return None

    def run_list(self, specs):
        todo = [s for s in specs if not self.done(s["id"]) and not self.given_up(s["id"])]
        self.say("start: %d games to run of %d (workers %d)" % (len(todo), len(specs), self.workers))
        n = 0
        with cf.ThreadPoolExecutor(self.workers) as ex:
            futs = {ex.submit(self.play, s): s for s in todo}
            for fut in cf.as_completed(futs):
                s = futs[fut]
                secs = fut.result()
                n += 1
                if secs is None:
                    self.say("not done %s (%d/%d)" % (s["id"], n, len(todo)))
                else:
                    self.say("done %s %s:%s vs %s:%s %s seed=%d in %ds (%d/%d)" % (s["id"], s["a"], s.get("oa"), s["b"], s.get("ob"),
                                                                                s["map"], s["seed"], secs, n, len(todo)))
        self.say("finished")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mode", choices=["openings", "explore", "check"], required=True)
    ap.add_argument("--pair", default="", help="openings mode: two factions, e.g. crown,brood")
    ap.add_argument("--games", type=int, default=100)
    ap.add_argument("--first", type=int, default=0, help="openings mode: first game number")
    ap.add_argument("--out", required=True)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--end", type=int, default=0, help="game seconds (default 1800; check mode 480)")
    ap.add_argument("--gg", type=int, default=-1, help="1: the computer's own gg rule ends a hopeless game (default; check mode 0)")
    ap.add_argument("--wall-limit", type=int, default=3600, help="kill a game after this many real seconds")
    ap.add_argument("--builds", default="", help="check mode: only these builds (comma list; retired ones too)")
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    end = a.end or (480 if a.mode == "check" else 1800)
    gg = a.gg if a.gg >= 0 else (0 if a.mode == "check" else 1)
    r = Runner(out, a.workers, end, gg, a.wall_limit)
    if not os.path.exists(GODOT):
        sys.exit("Godot not found: set GODOT=/path/to/Godot_v4.7-stable_linux.x86_64")
    if a.mode == "openings":
        pair = tuple(a.pair.split(","))
        if pair not in PAIR_INDEX:
            sys.exit("--pair must be one of " + ", ".join(",".join(p) for p in PAIR_INDEX))
        r.run_list([openings_spec(pair, n) for n in range(a.first, a.games)])
    elif a.mode == "check":
        r.run_list(check_specs([x for x in a.builds.split(",") if x] or None))
    else:
        import explore_v2
        explore_v2.run(r, a.games)


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    main()
