#!/usr/bin/env python3
"""Balance study v2, machine 4 (docs/study_v2.md): an evolutionary search for OUTLIER OPENINGS, the strong build orders
nobody wrote down. Measurement only: candidates are build orders in bo_ai.gd's step grammar, played by the scripted player
(tools/study/bo_ai_v2.gd), which then hands over to the Hard computer on the build's "then" plan.

Run it through the batch runner:   python3 tools/study/run_study_v2.py --mode explore --games 100 --out <dir>

How a game is chosen (game k, k = 0 .. games-1):
  * the candidate's faction is FACTIONS[k % 3], so every faction gets a third of the games;
  * the first SEED_GAMES games of each faction mutate its documented builds; after that each game is, by a seeded draw:
      RETEST 15%  the faction's best candidate so far with fewer than 4 games (a new map and opponent: confirm or drop it)
      FRESH  20%  a new build from the step grammar (see make_fresh)
      DOC    25%  1-3 mutations of a documented working build
      POOL   40%  1-3 mutations of a pool winner (tournament of 3 among the faction's tried candidates, by fitness)
  * the opponent is another faction: 40% its standard opening, 30% another of its working builds, 30% the plain Hard computer;
  * the map is drawn from the 12 study maps, the side swapped half the time, the seed fixed by k.
Mutations: worker count up or down, two steps swapped, a step dropped, a step added, an earlier or later attack (or one
added / dropped), a proxy building, a fast expansion, no wall (Crown), an early tech switch, another unit mix, another
"then" plan. Missing prerequisites are put in by themselves (ensure_prereqs), so a mutant stays playable.
Score of a game for the candidate: 1 a win (victory or gg), 0 a loss, at the 30-minute cap 0.75 / 0.25 for a power lead
(1.25x, the study's rule) and 0.5 for even. Fitness = (sum of scores + 0.5) / (games + 1): one lucky win is 0.75, two 0.83.
Everything is kept in <out>/explore/: candidates/<name>.json (the full script, parent, origin, mutations), specs/x_NNN.json
(each game's draw), bfiles/x_NNN.json (the build file the game read). Resumable: a drawn game is played again as drawn.
"""
import json, os, random, threading, time

from run_study_v2 import MAPS, FACTIONS, load_builds, working_builds

SEED_GAMES = 3
STANDARD = {"crown": "crown_musket_wall", "brood": "brood_economy", "clockwork": "cw_jack_tech"}
THEN = {"crown": ["balanced", "rush", "economy", "timing"], "clockwork": ["balanced", "rush", "economy", "timing"],
        "brood": ["balanced", "rush", "economy", "timing", "air", "xrush"]}
HALL = {"crown": "town_hall", "brood": "hive", "clockwork": "clocktower"}
# what each step needs before it (from the game's rules, tools/study/bo_dump.gd): buildings and units by train key
NEEDS = {
    "crown": {"barracks": ["cottage"], "armoury": ["barracks"], "foundry": ["barracks"], "church": ["barracks"],
              "musketeer": ["barracks", "powder_mill"], "horseman": ["barracks", "horse_breeder"],
              "dragoon": ["barracks", "powder_mill", "horse_breeder"], "cannon": ["foundry"], "mortar": ["foundry"],
              "balloon": ["foundry"], "drop": ["balloon"], "drop:hover": ["balloon"]},
    "brood": {"gorge_pit": ["warren"], "roost": ["warren"], "raptor": ["warren"], "spitter": ["warren", "brood_pen"],
              "brute": ["gorge_pit"], "mist_toad": ["gorge_pit"], "skywing": ["roost"], "bloater": ["roost"],
              "sacrifice": ["brood_pen", "raptor"]},
    "clockwork": {"ratchet_turret": ["movement_works"], "escapement": ["movement_works"], "cuckoo_house": ["escapement"],
                  "clock_soldier": ["movement_works"], "jack": ["escapement", "mainspring"], "netter": ["escapement", "mainspring"],
                  "pendulum": ["escapement", "mainspring", "gear:movement_works:big"], "cuckoo": ["cuckoo_house", "mainspring"],
                  "gear:movement_works:big": ["movement_works"], "morph": ["cuckoo"], "research:high_leap": ["escapement"],
                  "research:owl_morph": ["cuckoo_house"], "mainspring": []},
}
BUILDINGS = {
    "crown": ["cottage", "barracks", "powder_mill", "farm", "horse_breeder", "foundry", "armoury", "church", "town_hall"],
    "brood": ["warren", "feeding_pit", "brood_pen", "clutch_mound", "gorge_pit", "roost", "hive"],
    "clockwork": ["cog_press", "mainspring", "movement_works", "regulator", "ratchet_turret", "escapement", "cuckoo_house", "clocktower"],
}
# (buildings that may go forward as a proxy: production with no Tension rule to meet; a Clockwork Tension user must mesh
# with a Mainspring at home)
PRODUCTION = {"crown": ["barracks", "horse_breeder", "foundry"], "brood": ["warren", "gorge_pit", "roost"],
              "clockwork": ["movement_works", "clocktower"]}
UNITS = {"crown": ["musketeer", "horseman", "dragoon", "cannon", "mortar", "balloon"],
         "brood": ["raptor", "spitter", "brute", "skywing", "bloater", "mist_toad"],
         "clockwork": ["clock_soldier", "jack", "netter", "pendulum", "cuckoo"]}
TECH_UNITS = {"crown": ["cannon", "mortar", "dragoon", "horseman"], "brood": ["brute", "spitter", "bloater", "skywing"],
              "clockwork": ["jack", "pendulum", "netter", "cuckoo"]}
EXTRAS = {"crown": ["wall", "farm", "mill:3", "mill:4", "research:armour", "research:charge"],
          "brood": ["feeding_pit", "clutch_mound", "upgrade", "sacrifice:8", "brood_pen"],
          "clockwork": ["cog_press", "crew:mainspring:3", "ratchet_turret", "regulator", "research:high_leap"]}
MAX_STEPS = 26


# ------------------------------------------------------------------ step helpers

def kind_of(step):
    """What a step is, for prerequisites: a building, a unit train key, or the step itself."""
    s = step.split("@")[0]
    if "*" in s:
        return s.split("*")[0]
    if s.startswith("sacrifice:"):
        return "sacrifice"
    if s.startswith("morph:"):
        return "morph"
    return s


def provides(step):
    s = step.split("@")[0]
    if "*" in s:
        return s.split("*")[0]
    return s


def ensure_prereqs(faction, steps):
    """Put in any missing requirement right before the step that needs it (recursively)."""
    needs = NEEDS[faction]
    out = []
    have = set()
    if faction == "clockwork":
        have.add("clocktower")
    if faction == "brood":
        have.add("hive")
    if faction == "crown":
        have.add("town_hall")

    auto = set()

    def add(step, depth=0):
        k = kind_of(step)
        for r in needs.get(k, []):
            if r not in have and depth < 6:
                add(r if r not in UNITS[faction] else r + ("*4" if r == "raptor" else "*1"), depth + 1)
        if depth == 0 and step in auto and step in BUILDINGS[faction] and step != HALL[faction]:
            auto.discard(step)      # (put in earlier as a prerequisite: this later one is the same building)
            return
        out.append(step)
        have.add(provides(step))
        if depth > 0:
            auto.add(step)
            if step == "mainspring" and faction == "clockwork":
                out.append("crew:mainspring:3")
        if step == "wall":
            have.add("cottage")

    for s in steps:
        add(s)
    return out


def tidy(faction, steps, R=None):
    steps = [s for s in steps if s != "end"]
    if not steps or not steps[0].startswith("workers:"):
        steps.insert(0, "workers:%d" % (R or random).randint(7, 10))
    steps = ensure_prereqs(faction, steps)
    # drop exact repeats of setting steps right after each other
    clean = []
    for s in steps:
        if clean and clean[-1] == s and (s.startswith("workers:") or s.endswith("*") or s.startswith("crew:")):
            continue
        clean.append(s)
    clean = clean[:MAX_STEPS - 1]
    return clean + ["end"]


def unit_steps(steps):
    return [i for i, s in enumerate(steps) if "*" in s]


# ------------------------------------------------------------------ mutations (each returns (steps, label) or None)

def m_workers(f, st, R):
    idx = [i for i, s in enumerate(st) if s.startswith("workers:")]
    if not idx:
        return None
    i = R.choice(idx)
    n = int(st[i].split(":")[1])
    d = R.choice([-3, -2, -1, 1, 2, 3, 4])
    n2 = max(4, min(30, n + d))
    if n2 == n:
        return None
    st = list(st)
    st[i] = "workers:%d" % n2
    return st, "workers %d->%d" % (n, n2)


def m_swap(f, st, R):
    cand = [i for i in range(1, len(st) - 2)]
    if not cand:
        return None
    i = R.choice(cand)
    st = list(st)
    st[i], st[i + 1] = st[i + 1], st[i]
    return st, "swap %s / %s" % (st[i + 1], st[i])


def m_drop(f, st, R):
    cand = [i for i in range(1, len(st) - 1)]
    if not cand:
        return None
    i = R.choice(cand)
    st = list(st)
    s = st.pop(i)
    return st, "drop " + s


def m_add(f, st, R):
    pool = BUILDINGS[f] + [u + "*%d" % R.randint(1, 4) for u in UNITS[f]] + EXTRAS[f]
    s = R.choice(pool)
    st = list(st)
    i = R.randint(1, len(st) - 1)
    st.insert(i, s)
    return st, "add " + s


def m_attack(f, st, R):
    st = list(st)
    idx = [i for i, s in enumerate(st) if s.startswith("attack")]
    if not idx or R.random() < 0.2:
        if idx and R.random() < 0.5:
            s = st.pop(idx[0])
            return st, "drop " + s
        S = R.choice([4, 6, 8, 10, 12, 16, 20, 24])
        T = R.choice([150, 180, 210, 240, 300, 360, 420, 480])
        pos = max(i for i, s in enumerate(st) if "*" in s) + 1 if unit_steps(st) else len(st) - 1
        st.insert(pos, "attack@%d|%d" % (S, T))
        return st, "add attack@%d|%d" % (S, T)
    i = idx[0]
    s = st[i]
    S, T = 0, 600
    if "@" in s:
        p = s.split("@")[1].split("|")
        S = int(p[0])
        if len(p) > 1:
            T = int(float(p[1]))
    if R.random() < 0.5:
        T2 = max(90, T + R.choice([-120, -90, -60, -30, 30, 60, 90]))
        S2 = S
    else:
        S2 = max(2, S + R.choice([-6, -4, -2, 2, 4, 6]))
        T2 = T
    st[i] = "attack@%d|%d" % (S2, T2)
    return st, "%s -> %s" % (s, st[i])


def m_proxy(f, st, R):
    idx = [i for i, s in enumerate(st) if s in PRODUCTION[f] and "@" not in s]
    if not idx:
        return None
    i = R.choice(idx)
    st = list(st)
    frac = R.choice(["", ":0.6", ":0.65", ":0.5"])
    st[i] = st[i] + "@proxy" + frac
    return st, "proxy " + st[i]


def m_expand(f, st, R):
    st = list(st)
    h = HALL[f]
    if f == "brood":
        h = R.choice(["hive", "feeding_pit"])
    i = R.randint(1, min(4, len(st) - 1))
    st.insert(i, h)
    return st, "fast expansion: %s at step %d" % (h, i)


def m_nowall(f, st, R):
    if "wall" not in st:
        return None
    st = [s for s in st if s != "wall"]
    return st, "no wall"


def m_tech(f, st, R):
    u = R.choice(TECH_UNITS[f])
    st = list(st)
    i = R.randint(1, max(1, min(len(st) - 1, len(st) // 2)))
    st.insert(i, u + "*%d" % R.randint(1, 3))
    return st, "early tech: %s at step %d" % (u, i)


def m_mix(f, st, R):
    idx = unit_steps(st)
    if not idx:
        return None
    i = R.choice(idx)
    k, n = st[i].split("*")
    others = [u for u in UNITS[f] if u != k]
    k2 = R.choice(others)
    st = list(st)
    st[i] = k2 + "*" + n
    return st, "unit mix %s -> %s" % (k, k2)


MUTATIONS = [(m_workers, 3), (m_swap, 2), (m_drop, 2), (m_add, 2), (m_attack, 3), (m_proxy, 1), (m_expand, 1),
             (m_nowall, 1), (m_tech, 2), (m_mix, 2)]


def mutate(f, steps, then, R, n):
    labels = []
    st = [s for s in steps if s != "end"] + ["end"]
    tries = 0
    while len(labels) < n and tries < 30:
        tries += 1
        if R.random() < 0.1:
            t2 = R.choice([t for t in THEN[f] if t != then])
            labels.append("then %s -> %s" % (then, t2))
            then = t2
            continue
        fn = R.choices([m for m, _ in MUTATIONS], weights=[w for _, w in MUTATIONS])[0]
        r = fn(f, st, R)
        if r is None:
            continue
        st, lab = r
        labels.append(lab)
    return tidy(f, st, R), then, labels


def make_fresh(f, R):
    """A new build from the grammar: a worker count, one main unit with its buildings, maybe a second production
    building, a tech unit, more workers, a wall, an expansion and an attack, then a plan."""
    st = ["workers:%d" % R.randint(5, 12)]
    if f == "crown" and R.random() < 0.6:
        st.append("wall")
    if R.random() < 0.15:
        st.append(HALL[f])
    main = R.choice(UNITS[f])
    st.append(main + ("*%d" % R.randint(2, 6) if R.random() < 0.5 else "*"))
    if R.random() < 0.3:
        prod = [p for p in PRODUCTION[f] if p in (NEEDS[f].get(main, []) or [])] or PRODUCTION[f][:1]
        st.append(R.choice(prod))
    if f == "brood" and R.random() < 0.4:
        st.append("feeding_pit")
    if f == "clockwork" and R.random() < 0.5:
        st.append("cog_press")
    if R.random() < 0.35:
        st.append(R.choice(TECH_UNITS[f]) + "*%d" % R.randint(1, 3))
    if R.random() < 0.8:
        st.append("workers:%d" % R.randint(10, 20))
    if R.random() < 0.7:
        st.append("attack@%d|%d" % (R.choice([4, 6, 8, 10, 14, 18, 24]), R.choice([150, 200, 240, 300, 360, 420, 480])))
    if "*" not in st[-1] and not st[-1].endswith("*") and R.random() < 0.5:
        st.append(main + "*")
    return tidy(f, st, R), R.choice(THEN[f])


# ------------------------------------------------------------------ results and fitness

def game_score(g):
    """The candidate's score in one finished game (the candidate is side A)."""
    w = g.get("a_won", -1)
    cause = g.get("cause", "")
    if w == 1:
        return 0.75 if cause == "timeout_lead" else 1.0
    if w == 0:
        return 0.25 if cause == "timeout_lead" else 0.0
    return 0.5


class Explorer:
    def __init__(self, runner, total):
        self.r = runner
        self.total = total
        self.dir = os.path.join(runner.out, "explore")
        for sub in ("candidates", "specs", "bfiles"):
            os.makedirs(os.path.join(self.dir, sub), exist_ok=True)
        self.lock = threading.Lock()
        self.builds = load_builds()
        self.working = {f: working_builds(f, self.builds) for f in FACTIONS}
        self.taken = set()

    # -- storage
    def cand_path(self, name):
        return os.path.join(self.dir, "candidates", name + ".json")

    def candidates(self):
        out = {}
        d = os.path.join(self.dir, "candidates")
        for fn in os.listdir(d):
            if fn.endswith(".json"):
                c = json.load(open(os.path.join(d, fn)))
                out[c["name"]] = c
        return out

    def results(self):
        """candidate name -> [scores]"""
        res = {}
        d = os.path.join(self.dir, "specs")
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".json"):
                continue
            sp = json.load(open(os.path.join(d, fn)))
            gp = os.path.join(self.r.out, "games", sp["id"] + ".json")
            if os.path.exists(gp):
                try:
                    g = json.load(open(gp))
                except Exception:
                    continue
                res.setdefault(sp["cand"], []).append(game_score(g))
        return res

    @staticmethod
    def fitness(scores):
        return (sum(scores) + 0.5) / (len(scores) + 1)

    # -- drawing a game
    def new_name(self, f, k):
        return "x_%s_%03d" % ({"crown": "cr", "brood": "br", "clockwork": "cw"}[f], k)

    def draw(self, k):
        R = random.Random(880000 + 7919 * k + len(self.results()))
        f = FACTIONS[k % 3]
        cands = self.candidates()
        res = self.results()
        mine = {n: c for n, c in cands.items() if c["faction"] == f and n in res}
        nth = k // 3
        if nth < SEED_GAMES or not mine:
            action = "DOC"
        else:
            action = R.choices(["RETEST", "FRESH", "DOC", "POOL"], weights=[15, 20, 25, 40])[0]
        cand = None
        if action == "RETEST":
            best = sorted((n for n in mine if len(res[n]) < 4), key=lambda n: -self.fitness(res[n]))
            if best:
                cand = cands[best[0]]
            else:
                action = "POOL"
        if action == "POOL":
            pool = list(mine)
            pick = max(R.sample(pool, min(3, len(pool))), key=lambda n: self.fitness(res[n]))
            par = cands[pick]
            st, then, labels = mutate(f, par["steps"], par["then"], R, R.randint(1, 3))
            cand = {"name": self.new_name(f, k), "faction": f, "steps": st, "then": then, "parent": par["name"],
                    "origin": par.get("origin", par["name"]), "mutations": par.get("mutations", []) + [labels], "made": "POOL"}
        elif action == "DOC":
            base = R.choice(self.working[f])
            b = self.builds[base]
            st, then, labels = mutate(f, b["steps"], b.get("then", "balanced"), R, R.randint(1, 3))
            cand = {"name": self.new_name(f, k), "faction": f, "steps": st, "then": then, "parent": base,
                    "origin": base, "mutations": [labels], "made": "DOC"}
        elif action == "FRESH":
            st, then = make_fresh(f, R)
            cand = {"name": self.new_name(f, k), "faction": f, "steps": st, "then": then, "parent": "",
                    "origin": "grammar", "mutations": [], "made": "FRESH"}
        if cand["name"] == self.new_name(f, k):
            cand["label"] = "explore %s (%s of %s)" % (cand["name"], cand["made"], cand["parent"] or "the grammar")
            self._atomic(self.cand_path(cand["name"]), cand)
        # the opponent
        of = R.choice([x for x in FACTIONS if x != f])
        u = R.random()
        if u < 0.4:
            ob = STANDARD[of]
        elif u < 0.7:
            ob = R.choice(self.working[of])
        else:
            ob = "ai"
        bfile = os.path.join(self.dir, "bfiles", "x_%03d.json" % k)
        self._atomic(bfile, {"builds": [{k2: v for k2, v in cand.items() if k2 in ("name", "faction", "steps", "then", "label")}]})
        spec = {"id": "x_%03d" % k, "a": f, "b": of, "oa": cand["name"], "ob": ob, "pb": "balanced",
                "map": R.choice(MAPS), "seed": 500000 + 37 * k + 11, "swap": R.randint(0, 1), "n": k,
                "builds": bfile, "cand": cand["name"], "action": action}
        self._atomic(os.path.join(self.dir, "specs", "x_%03d.json" % k), spec)
        return spec

    def _atomic(self, path, obj):
        tmp = path + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(obj, fh, indent=1)
        os.replace(tmp, path)

    def next_spec(self):
        with self.lock:
            for k in range(self.total):
                if k in self.taken:
                    continue
                gid = "x_%03d" % k
                if self.r.done(gid) or self.r.given_up(gid):
                    self.taken.add(k)
                    continue
                self.taken.add(k)
                sp_path = os.path.join(self.dir, "specs", gid + ".json")
                if os.path.exists(sp_path):
                    return json.load(open(sp_path))       # (drawn before a restart: played as drawn)
                return self.draw(k)
        return None

    def worker(self):
        while not self.r.stopped():
            s = self.next_spec()
            if s is None:
                return
            secs = self.r.play(s)
            if secs is None:
                self.r.say("not done %s" % s["id"])
            else:
                sc = self.results().get(s["cand"], [])
                self.r.say("done %s %s %s (%s) vs %s:%s %s in %ds: candidate fitness %.2f over %d" % (
                    s["id"], s["action"], s["cand"], s["a"], s["b"], s["ob"], s["map"], secs, self.fitness(sc), len(sc)))


def run(runner, total):
    ex = Explorer(runner, total)
    runner.say("explore: %d games (workers %d)" % (total, runner.workers))
    ths = [threading.Thread(target=ex.worker) for _ in range(runner.workers)]
    for t in ths:
        t.start()
        time.sleep(2)
    for t in ths:
        t.join()
    runner.say("finished")
