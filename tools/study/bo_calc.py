#!/usr/bin/env python3
"""Build-order TIMING CALCULATOR for Holdfast (docs/build_orders_study.md).

Given a build order (an entry of tools/study/build_orders.json, the same steps the headless bot plays), it simulates the
opening second by second and reports: when each step is placed and done, the army at minutes 3, 4, 5 and 6, and when the
attack arrives at the enemy's ramp and hall on each standard map.

  python3 tools/study/bo_calc.py crown_horse_rush                 # one build, full report
  python3 tools/study/bo_calc.py crown_horse_rush --map kestrel_rise
  python3 tools/study/bo_calc.py --all                             # every build: one summary line each
  python3 tools/study/bo_calc.py --vs crown_horse_rush brood_pool  # both builds, and a rough fight estimate when the attack lands
  python3 tools/study/bo_calc.py --steps "workers:8,horse_breeder,cottage,barracks,horseman*3,attack" --faction crown
  python3 tools/study/bo_calc.py brood_spitter_timing --set units.spitter.cost2=0      # what if (any number, see --help)

Numbers: tools/study/bo_data.json (made by tools/study/bo_data.py from the game itself: every cost, time, supply and the
economy constants, and the walking distances measured on each map) plus the few CALIBRATION constants below (walking
and hand-over times the rules do not state), fitted to headless matches (tools/study/bo_match.gd, see the doc).
It is a model, not the game: expect about +-10 s on step times and +-1 unit on army counts.

Economy modelled per faction:
  Crown      Farms ripen (40 s with a full crew of 8; 15% speed with nobody) into 380-gold harvests; the starting farm is at
             60%. Labourers fill the farm nearest its harvest first, the Powder Mill takes 3 while powder is short (1 once
             there is 20 in the bank) from the Barracks on, 6 after 5:00 (the computer's own rule, AI._mill_cap); a Mill
             hand grinds 0.33 powder/s. A builder walks off his post, builds for the whole build time, walks back.
  Brood      Each grub on a pit earns a fixed rate (calibrated; the farther pits pay more); eggs are laid 1 per 9 s per
             Burrow (+10% per Clutch Mound, up to 3), 5 held (10 in a Warren), and every unit and grub takes an egg; all
             eggs hatch at the same time. A building consumes its grub.
  Clockwork  A Cog Press pays 8 cogs/s with its 3 Winders (15% alone, an equal share each); a Mainspring winds 2 Tension/s
             with 3. A building's Winder fetches its crate from the Clocktower and is back at work soon after.
"""
import argparse, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = json.load(open(os.path.join(HERE, "bo_data.json")))
BUILDS = {b["name"]: b for b in json.load(open(os.path.join(HERE, "build_orders.json")))["builds"]}
U = DATA["units"]
B = DATA["buildings"]
R = DATA["research"]
E = DATA["econ"]

# ---- CALIBRATION (seconds unless noted; fitted to headless runs, see docs/build_orders_study.md "Calculator vs game")
CAL = {
    "think": 0.7,               # the Hard computer thinks every 0.7 s: a step (or a worker) waits for the next think
    "crown_walk": 7.0,          # a Labourer from his post to a building site
    "crown_back": 7.0,          # ... and back to his post afterwards
    "crown_new": 4.0,           # a new Labourer from the Town Hall to his post
    "mount": 8.0,               # a Horseman out of the Barracks walks to his horse at the Breeder and mounts (1.5 s)
    "brood_walk": 2.0,          # a grub to its building site (then it morphs 1.6 s and is gone)
    "brood_new": 3.0,           # a new grub to its pit
    "grub_rate": 0.58,          # biomass per grub-second on the starting pit (near the Burrow)
    "grub_rate_far": 0.62,      # ... on a pit placed by the computer (farther out pays more)
    "cw_crate": 9.0,            # a Winder to the Clocktower, picks the crate up (0.8 s), carries it to the site
    "cw_back": 5.0,             # ... and back to his press
    "cw_new": 3.0,              # a new Winder to his post
    "first_wall_gate": 12.0,    # Crown: the Gate after the ramp Cottage (built by one Labourer)
}

MAP_DEFAULT = "ashford_crossing"
REPORT_AT = [180, 240, 300, 360]


def unit_cycle(u):
    """Seconds between two blows (cooldown + aim + the end of the strike animation, about 0.35 s)."""
    return float(u.get("cooldown", 1.0)) + float(u.get("aim", 0.0)) + 0.35


def unit_dps(kind, armor=0.0):
    if kind == "dragoon":
        # (no weapon in the saddle: it gets off and fires as a Musketeer, reloading a third slower: Defs.HORSES dragoon_reload)
        return unit_dps("musketeer", armor) / float(DATA.get("horses", {}).get("dragoon_reload", 1.3))
    u = U[kind]
    dmg = float(u.get("damage", 0))
    if kind == "musketeer":
        dmg = 20.0
    if dmg <= 0:
        return 0.0
    return max(1.0, dmg - armor) / unit_cycle(u)


def melee_dps(kind, armor=0.0):
    """Close-in damage a second (the Musketeer's bayonet, the Horseman's sabre)."""
    if kind == "musketeer":
        b = DATA["bayonet"]
        return max(1.0, float(b["damage"]) - armor) / (float(b["cooldown"]) + float(b["aim"]) + 0.35)
    return unit_dps(kind, armor)


class Sim:
    def __init__(self, faction, steps, label="", horizon=480.0, map_name=MAP_DEFAULT):
        self.f = faction
        self.steps = list(steps)
        self.label = label
        self.horizon = horizon
        self.map = map_name
        fd = DATA["factions"][faction]
        self.t = 0.0
        self.gold = float(fd.get("start_gold", E["START_GOLD"]))
        # (what-if only: no faction starts with any of its second resource; --set factions.brood.start_res2=40)
        self.res2 = float(fd.get("start_res2", 0.0))
        self.tension = float(fd.get("start_res2", 0.0)) if faction == "clockwork" else 0.0
        self.hall = fd["hall"]
        self.worker = fd["worker"]
        self.sup_kind = DATA["supply_kind"][faction]
        self.workers = []               # each: {"post": name|None, "busy": t, "then": name|None, "gone": bool}
        self.posts = {}                 # name -> {"kind", "cap", "crew", ...}
        self.blds = []                  # {"kind", "placed", "done", "built", "name"}
        self.army = []                  # {"kind", "t"}
        self.prod = []                  # production queues {"kind", "queue": [[unit, left, extra]], "bld"}
        self.log = []
        self.si = 0
        self.worker_goal = 0
        self.repeats = []
        self.supply_auto = True
        self.unit_count = {}
        self.attack = None
        self.attacks = []
        self.snap = {}
        self.hold = 0
        self.next_think = 0.0
        self.horses = 0                 # horses ready at a breeder (Crown)
        self.horse_q = []               # [time left]
        self.eggs = {}                  # hall index -> [eggs, timer]
        self.ended = -1.0
        self.wall_gate_at = -1.0
        self.researched = {}
        self.upgrading = None
        self.hall_level = 1
        self.morphing = []
        self.mill_cap_fixed = None
        self.notes = []
        self.step_units = {}
        self.pending_essence = []
        # the start: the hall, the starting economy building, the workers
        self._add_bld(self.hall, 0.0, built=True)
        for k in DATA["start_list"][faction]:
            b = self._add_bld(k, 0.0, built=True)
            if k == "farm":
                b["growth"] = 0.6
        # (the starting workers are at work on the starting economy building from the first second)
        first = next((n for n, p in self.posts.items()), None)
        for i in range(int(fd["start_workers"])):
            cap = self.posts[first]["cap"] if first else 0
            self.workers.append({"post": first if first and i < cap else None, "busy": 0.0, "then": None, "gone": False})

    # ------------------------------------------------------------ bookkeeping
    def _add_bld(self, kind, t, built=False):
        b = {"kind": kind, "placed": t, "done": t if built else -1.0, "built": built, "left": 0.0 if built else float(B[kind]["time"]),
             "name": "%s%d" % (kind, sum(1 for x in self.blds if x["kind"] == kind)), "growth": 0.0, "crew": 0}
        self.blds.append(b)
        if built:
            self._on_built(b)
        return b

    def _on_built(self, b):
        k = b["kind"]
        crew = 0
        if k == "farm":
            crew = 8
        elif k == "powder_mill":
            crew = 6
        elif k == "feeding_pit":
            crew = 6 if b["placed"] == 0.0 else 7          # (the crew grows with the distance from the capital: Building.crew_max)
        elif k == "cog_press":
            crew = int(DATA["gear"]["press"]["big" if b.get("big") else "small"]["crew"])
        elif k == "mainspring":
            crew = int(B["mainspring"].get("crew", 3))
        if crew:
            self.posts[b["name"]] = {"kind": k, "cap": crew, "bld": b}
        if B[k].get("trains") and k != "horse_breeder":
            self.prod.append({"kind": k, "queue": [], "bld": b})
        if k == "horse_breeder":
            self.prod.append({"kind": k, "queue": [], "bld": b})
        if B[k].get("eggs"):
            self.eggs[b["name"]] = [int(E["EGGS_MAX"]) if b["placed"] == 0.0 else 0, 0.0]

    def has(self, kind):
        return any(b["kind"] == kind and b["built"] for b in self.blds)

    def count(self, kind, built_only=False):
        return sum(1 for b in self.blds if b["kind"] == kind and (b["built"] or not built_only))

    def cap(self):
        n = 0
        for b in self.blds:
            if b["built"]:
                n += int(B[b["kind"]].get("supply", 0))
        return min(n, int(DATA["factions"][self.f]["max_supply"]))

    def used(self):
        n = sum(1 for w in self.workers if not w["gone"])
        for a in self.army:
            n += int(U[a["kind"]]["supply"])
        for p in self.prod:
            for q in p["queue"]:
                if q[0] in U and not q[0].startswith("@"):
                    n += int(U[q[0]]["supply"]) * int(U[q[0]].get("spawn", 1))
        for w in self.morphing:
            n += int(U["ticking_owl"]["supply"]) - int(U["cuckoo"]["supply"])
        return n

    def alive_workers(self):
        return [w for w in self.workers if not w["gone"]]

    def req_met(self, kind):
        r = B[kind].get("requires", "") if kind in B else U[kind].get("requires", "")
        reqs = r if isinstance(r, list) else ([r] if r else [])
        for x in reqs:
            if x == "escapement" and DATA["gear_mode"]:
                if not (self.has("escapement") and self.has("mainspring")):
                    return False
            elif not self.has(x):
                return False
        return True

    def note(self, text, done=-1.0):
        self.log.append({"step": text, "issued": round(self.t, 1), "done": done})
        return len(self.log) - 1

    # ------------------------------------------------------------ economy, a tick
    def _crew(self, post):
        return sum(1 for w in self.workers if not w["gone"] and w["post"] == post and w["busy"] <= self.t)

    def _mill_cap(self):
        if self.mill_cap_fixed is not None:
            return self.mill_cap_fixed
        if self.t > 300.0:
            return 99
        if not any(b["kind"] == "barracks" for b in self.blds):
            return 0
        return 3 if self.res2 < 20.0 else 1

    def _assign(self):
        """Free workers take a post (the computer's own order)."""
        free = [w for w in self.workers if not w["gone"] and w["post"] is None and w["busy"] <= self.t]
        if not free:
            return
        for w in free:
            post = self._pick_post()
            if post is None:
                break
            w["post"] = post
            w["busy"] = self.t + {"crown": CAL["crown_new"], "brood": CAL["brood_new"], "clockwork": CAL["cw_new"]}[self.f]
            w["walk"] = True        # (walking to a post: he can still be sent to build)

    def _taken(self, name):
        return sum(1 for w in self.workers if not w["gone"] and (w["post"] == name or w["then"] == name))

    def _pick_post(self):
        posts = [(n, p) for n, p in self.posts.items() if p["bld"]["built"]]
        if self.f == "crown":
            farms = [(n, p) for n, p in posts if p["kind"] == "farm"]
            mills = [(n, p) for n, p in posts if p["kind"] == "powder_mill"]
            mill_crew = sum(self._taken(n) for n, _ in mills)
            if mills and mill_crew < self._mill_cap():
                for n, p in mills:
                    if self._taken(n) < p["cap"]:
                        return n
            farms.sort(key=lambda np: -np[1]["bld"]["growth"] if self._taken(np[0]) > 0 else 1.0)
            for n, p in farms:
                if self._taken(n) < p["cap"]:
                    return n
            for n, p in mills:
                if self._taken(n) < p["cap"]:
                    return n
            return None
        for n, p in sorted(posts, key=lambda np: (np[1]["kind"] == "mainspring", np[1]["bld"]["placed"])):
            if self._taken(n) < p["cap"]:
                return n
        return None

    def _rebalance(self):
        """Crown: the computer moves farm hands to the Powder Mill (two at a time) while it is under its cap, and back to
        the farms when over it (AI._balance_mill); one Labourer becomes a hauler once there is a Horse Breeder
        (AI._assign_haulers: he leaves his farm)."""
        if self.f != "crown":
            return
        mills = [n for n, p in self.posts.items() if p["kind"] == "powder_mill" and p["bld"]["built"]]
        if mills:
            cap = self._mill_cap()
            crew = self._taken(mills[0])
            if cap < 99 and crew < cap:
                moved = 0
                for w in self.workers:
                    if moved >= 2 or crew + moved >= min(cap, 6):
                        break
                    if not w["gone"] and w["post"] and w["post"].startswith("farm") and w["busy"] <= self.t:
                        w["post"] = mills[0]
                        w["busy"] = self.t + 5.0
                        w["walk"] = True
                        moved += 1
            elif cap < 99 and crew > cap:
                moved = 0
                for w in self.workers:
                    if moved >= 2 or crew - moved <= cap:
                        break
                    if not w["gone"] and w["post"] == mills[0] and w["busy"] <= self.t:
                        w["post"] = None
                        moved += 1
        if self.has("horse_breeder") and not any(w.get("hauler") for w in self.workers if not w["gone"]):
            for w in self.workers:
                if not w["gone"] and w["busy"] <= self.t and (w["post"] or "").startswith("farm"):
                    w["post"] = "haul"
                    w["hauler"] = True
                    break

    def _income(self, dt):
        for n, p in self.posts.items():
            b = p["bld"]
            if not b["built"]:
                continue
            crew = min(self._crew(n), p["cap"])
            k = p["kind"]
            if k == "farm":
                speed = E["FARM_BASE"] + (1.0 - E["FARM_BASE"]) * crew / 8.0
                b["growth"] += speed / E["FARM_GROW"] * dt
                if b["growth"] >= 1.0:
                    b["growth"] = 0.0
                    self.gold += E["FARM_YIELD"]
                    self.earned += E["FARM_YIELD"]
            elif k == "powder_mill":
                self.res2 += E["MILL_RATE"] * crew * dt
            elif k == "feeding_pit":
                rate = CAL["grub_rate"] if b["placed"] == 0.0 else CAL["grub_rate_far"]
                v = rate * crew * dt
                self.gold += v
                self.earned += v
            elif k == "cog_press":
                g = DATA["gear"]["press"]
                gs = g["big" if b.get("big") else "small"]
                v = gs["full"] * (g["base"] + (1.0 - g["base"]) * crew / gs["crew"]) * dt
                self.gold += v
                self.earned += v
            elif k == "mainspring":
                g = DATA["gear"]["mainspring"]
                self.tension += g["full"] * (g["base"] + (1.0 - g["base"]) * crew / 3.0) * dt
                if g.get("store"):        # (wt-econ: every Mainspring stores so much; winding stops at the cap)
                    self.tension = min(self.tension, float(g["store"]) * self.count("mainspring", True))

    def _eggs(self, dt):
        mounds = min(3, self.count("clutch_mound", True))
        rate = 1.0 + 0.1 * mounds
        hold = 10 if self.hall_level >= 2 else int(E["EGGS_MAX"])
        for name, e in self.eggs.items():
            if e[0] < hold:
                e[1] += dt * rate
                if e[1] >= E["EGG_TIME"]:
                    e[1] = 0.0
                    e[0] += 1

    def _build_tick(self, dt):
        for b in self.blds:
            if b["built"] or b["placed"] < 0:
                continue
            if self.t < b.get("start", b["placed"]):
                continue
            b["left"] -= dt
            if b["left"] <= 0.0:
                b["built"] = True
                b["done"] = round(self.t, 1)
                self._on_built(b)
                if b.get("log") is not None:
                    self.log[b["log"]]["done"] = b["done"]

    def _prod_tick(self, dt):
        for q in self.horse_q:
            q[0] -= dt
        while self.horse_q and self.horse_q[0][0] <= 0:
            self.horse_q.pop(0)
            self.horses += 1
        for p in self.prod:
            if not p["queue"]:
                continue
            if p["bld"].get("swap_until", -1.0) > self.t:
                continue        # (a gear swap: the building idles meanwhile)
            if p["kind"] == self.hall and self.f == "brood":
                # eggs hatch together
                for q in list(p["queue"]):
                    q[1] -= dt
                    if q[1] <= 0:
                        p["queue"].remove(q)
                        self._spawn(q[0], q)
                continue
            q = p["queue"][0]
            q[1] -= dt
            if q[0].startswith("@"):
                if q[1] <= 0:
                    p["queue"].pop(0)
                    self.researched[q[0][1:]] = round(self.t, 1)
                continue
            if q[1] <= 0:
                if U[q[0]].get("needs_horse") and q[2].get("horse_wait", 0) > 0 and q[0] != "cuirassier":
                    continue
                p["queue"].pop(0)
                self._spawn(q[0], q)

    def _spawn(self, kind, q):
        if kind == self.worker:
            self.workers.append({"post": None, "busy": self.t, "then": None, "gone": False})
            return
        if kind == "horse":
            self.horses += 1
            return
        delay = 0.0
        if kind in ("cuirassier", "dragoon"):
            delay = CAL["mount"] + max(0.0, q[2].get("horse_at", self.t) - self.t)
        for _ in range(int(U[kind].get("spawn", 1))):
            self.army.append({"kind": kind, "t": self.t, "ready": self.t + delay})
        si = q[2].get("step")
        if si is not None and si in self.step_units:
            su = self.step_units[si]
            su["out"] += 1
            if su["out"] >= su["need"] and su.get("log") is not None:
                self.log[su["log"]]["done"] = round(self.t + delay, 1)

    # ------------------------------------------------------------ actions
    def price(self, kind):
        u = U[kind]
        return int(u["cost"]), int(u.get("tension", 0) if DATA["gear_mode"] and self.f == "clockwork" else u.get("cost2", 0))

    def can_pay(self, g, r2=0):
        if self.f == "clockwork":
            return self.gold >= g and self.tension >= r2
        return self.gold >= g and self.res2 >= r2

    def pay(self, g, r2=0):
        self.gold -= g
        if self.f == "clockwork":
            self.tension -= r2
        else:
            self.res2 -= r2

    def _builder(self):
        """The worker who builds: an idle one, else one off his post (the nearest: here, the last one assigned)."""
        cands = [w for w in self.workers if not w["gone"] and (w["busy"] <= self.t or w.get("walk"))]
        if not cands:
            return None
        cands.sort(key=lambda w: (w["post"] is not None, w["post"] or ""))
        if self.f == "crown":
            # (the computer prefers farm hands over Mill hands for a site)
            cands.sort(key=lambda w: (w["post"] is not None, (w["post"] or "").startswith("powder_mill")))
        return cands[0]

    def place(self, kind):
        cost = int(B[kind]["cost"])
        t2 = int(B[kind].get("tension", 0)) if self.f == "clockwork" else 0      # (wt-econ: buildings may cost Tension)
        if self.gold < cost or self.tension < t2 or not self.req_met(kind):
            return None
        if self.f == "brood" and len(self.alive_workers()) <= 2 and kind != self.sup_kind:
            return None
        w = self._builder()
        if w is None:
            return None
        self.gold -= cost
        self.tension -= t2
        b = self._add_bld(kind, self.t)
        w["walk"] = False
        if self.f == "crown":
            start = self.t + CAL["crown_walk"]
            b["start"] = start
            back = w["post"]
            w["post"] = None
            w["busy"] = start + float(B[kind]["time"]) + CAL["crown_back"]
            w["then"] = back
            w["post"] = back
        elif self.f == "brood":
            b["start"] = self.t + CAL["brood_walk"] + 1.6
            w["gone"] = True
            w["post"] = None
        else:
            b["start"] = self.t + CAL["cw_crate"]
            w["busy"] = b["start"] + CAL["cw_back"]
        return b

    def makers(self, kind):
        frm = U[kind]["from"] if kind != "dismounted" else "barracks"
        out = [p for p in self.prod if p["kind"] == frm and p["bld"]["built"]]
        if U[kind].get("big_gear"):       # (the Pendulum: only a Works on its big gear, not while it swaps)
            out = [p for p in out if p["bld"].get("big") and p["bld"].get("swap_until", -1.0) <= self.t]
        return out

    def train(self, kind, step_i=None):
        """Queue one unit; True if it was."""
        if kind in ("horseman",):
            kind = "cuirassier"
        if kind == "officer":
            kind = "dismounted"
        g, r2 = self.price(kind)
        if not self.req_met(kind):
            return False
        need = int(U[kind]["supply"]) * int(U[kind].get("spawn", 1))
        if self.used() + need > self.cap():
            return False
        horse = U[kind].get("needs_horse") and kind != "horse"
        horse_cost = 0
        if horse and self.horses <= 0:
            if not self.has("horse_breeder"):
                return False
            horse_cost = int(U["horse"]["cost"])
        if not self.can_pay(g + horse_cost, r2):
            return False
        for p in self.makers(kind):
            if self.f == "brood":
                e = self.eggs.get(p["bld"]["name"])
                if not e or e[0] <= 0:
                    continue
                e[0] -= 1
            elif len(p["queue"]) >= 2:
                continue
            self.pay(g + horse_cost, r2)
            extra = {}
            if horse:
                if self.horses > 0:
                    self.horses -= 1
                    extra["horse_at"] = self.t
                else:
                    t_ready = self.t + float(U["horse"]["time"]) + (self.horse_q[-1][0] if self.horse_q else 0.0)
                    self.horse_q.append([t_ready - self.t])
                    self.horses -= 1          # (kept for him)
                    extra["horse_at"] = t_ready
            if step_i is not None:
                extra["step"] = step_i
            p["queue"].append([kind, float(U[kind]["time"]), extra])
            return True
        return False

    def train_worker(self):
        g = int(U[self.worker]["cost"])
        if self.gold < g or self.used() + 1 > self.cap():
            return False
        for p in self.prod:
            if p["kind"] != self.hall or not p["bld"]["built"]:
                continue
            if self.f == "brood":
                e = self.eggs.get(p["bld"]["name"])
                if not e or e[0] <= 0:
                    continue
                e[0] -= 1
            elif p["queue"]:
                continue
            self.gold -= g
            p["queue"].append([self.worker, float(U[self.worker]["time"]), {}])
            return True
        return False

    def workers_now(self):
        n = len(self.alive_workers())
        for p in self.prod:
            n += sum(1 for q in p["queue"] if q[0] == self.worker)
        return n

    # ------------------------------------------------------------ the AI's supply rule (AI._supply)
    def auto_supply(self):
        cap = self.cap()
        if cap >= int(DATA["factions"][self.f]["max_supply"]):
            return
        used = self.used()
        if self.f == "brood":
            prod = 3 * self.count(self.hall, True)
        elif self.f == "clockwork":
            prod = 3 * self.count("movement_works", True)
        else:
            prod = 3 * self.count("barracks", True) + 2 * self.count("foundry", True)
        margin = 3 + prod
        building = sum(1 for b in self.blds if b["kind"] == self.sup_kind and not b["built"])
        if self.f == "crown" and self.build.get("opening") == "breeder" and self.t < 600 and self.count("barracks") > 0:
            margin += 3 + 3 * self.count("barracks")
            if cap - used <= margin and building < (2 if cap - used <= 6 else 1):
                self.place(self.sup_kind)
            return
        if cap - used <= margin and building == 0:
            self.place(self.sup_kind)

    # ------------------------------------------------------------ the steps
    def step(self, s):
        if s.startswith("workers:"):
            self.worker_goal = int(s[8:])
            self.note(s, round(self.t, 1))
            return True
        if s == "end":
            self.note(s, round(self.t, 1))
            self.ended = self.t
            return True
        if s.startswith("wait:"):
            if self.t < float(s[5:]):
                return False
            self.note(s, round(self.t, 1))
            return True
        if s.startswith("until:workers:"):
            if len(self.alive_workers()) < int(s[14:]):
                return False
            self.note(s, round(self.t, 1))
            return True
        if s.startswith("supply:"):
            self.supply_auto = s[7:] != "off"
            self.note(s, round(self.t, 1))
            return True
        if s.startswith("stop:"):
            k = s[5:]
            if k in self.repeats:
                self.repeats.remove(k)
            self.note(s, round(self.t, 1))
            return True
        if s.startswith("mill:"):
            self.mill_cap_fixed = int(s[5:])
            self.note(s, round(self.t, 1))
            return True
        if s == "wall":
            if self.f != "crown":
                return True
            b = self.place("cottage")
            if b is None:
                self.hold = 100
                return False
            i = self.note("wall (ramp Cottage)")
            b["log"] = i
            self.wall_gate_at = b["start"] + float(B["cottage"]["time"])
            return True
        if s.startswith("attack"):
            need, by = 0, math.inf
            if s.startswith("attack@"):
                p = s[7:].split("|")
                need = int(p[0])
                if len(p) > 1:
                    by = float(p[1])
            army = [a for a in self.army if not a.get("wave")]
            sup = sum(int(U[a["kind"]]["supply"]) for a in army)
            if (sup < need and self.t < by) or not army:
                return False
            for a in army:
                a["wave"] = len(self.attacks) + 1
            self.attacks.append({"go": round(self.t, 1), "units": [a["kind"] for a in army], "supply": sup})
            self.note(s, round(self.t, 1))
            return True
        if s in ("drop", "drop:hover"):
            # (hovering, the men stay aboard and fire from the basket: the balloon gets there all the same)
            balloons = [a for a in self.army if a["kind"] == "balloon"]
            muskets = [a for a in self.army if a["kind"] == "musketeer" and not a.get("wave")]
            if not balloons or len(muskets) < 3:
                return False
            men = muskets[:4]
            for a in men:
                a["wave"] = len(self.attacks) + 1
            self.attacks.append({"go": round(self.t, 1), "units": ["musketeer"] * len(men), "supply": len(men), "drop": True,
                                 "load": 12.0})
            self.note(s, round(self.t, 1))
            return True
        if s.startswith("research:"):
            key = s[9:]
            info = R[key]
            at = [p for p in self.prod if p["kind"] == info["at"] and p["bld"]["built"]]
            if not at and not any(b["kind"] == info["at"] and b["built"] for b in self.blds):
                return False
            if info["at"] in ("armoury", "escapement", "cuckoo_house") and not at:
                bb = [b for b in self.blds if b["kind"] == info["at"] and b["built"]]
                if not bb:
                    return False
                at = [{"kind": info["at"], "queue": [], "bld": bb[0]}]
                self.prod.append(at[0])
            r2 = int(info.get("tension", 0)) if self.f == "clockwork" else int(info.get("cost2", 0))
            if not self.can_pay(int(info["cost"]), r2):
                self.hold = int(info["cost"])
                return False
            self.pay(int(info["cost"]), r2)
            at[0]["queue"].append(["@" + key, float(info["time"]), {}])
            self.note(s)
            return True
        if s == "upgrade":
            if self.upgrading is not None or self.hall_level >= 3:
                return self.upgrading is None
            nl = DATA["hall_levels"][self.hall_level]
            if nl.get("needs") and not self.has(nl["needs"]):
                return False
            if not self.can_pay(int(nl["cost"]), int(nl.get("cost2", 0))):
                self.hold = int(nl["cost"])
                return False
            self.pay(int(nl["cost"]), int(nl.get("cost2", 0)))
            self.upgrading = [self.t + float(nl["time"]), self.note(s)]
            return True
        if s.startswith("morph:"):
            n = int(s[6:])
            done = self.unit_count.get(self.si, 0)
            if "owl_morph" not in self.researched:
                return False
            m = DATA["owl_morph"]
            for a in self.army:
                if done >= n:
                    break
                if a["kind"] == "cuckoo" and not a.get("morph") and self.can_pay(int(m["cost"]), int(m["tension"])):
                    self.pay(int(m["cost"]), int(m["tension"]))
                    a["morph"] = self.t + float(m["time"])
                    self.morphing.append(a)
                    done += 1
            self.unit_count[self.si] = done
            if done >= n:
                self.note(s)
                return True
            self.hold = int(m["cost"])
            return False
        if s.startswith("sacrifice:"):
            n = int(s[10:])
            if not self.has("brood_pen"):
                return False
            done = self.unit_count.get(self.si, 0)
            for a in list(self.army):
                if done >= n:
                    break
                if a["kind"] == "raptor" and not a.get("wave"):
                    self.army.remove(a)
                    # (walks to the Pen; Game.sacrifice_value: a share of its price, at least 1: 3 for a Raptor)
                    ess = max(1, round(float(U["raptor"]["cost"]) / float(U["raptor"].get("spawn", 1)) * float(E["SACRIFICE"])))
                    self.pending_essence.append([self.t + 10.0, float(ess)])
                    done += 1
            self.unit_count[self.si] = done
            if done >= n:
                self.note(s)
                return True
            return False
        if s.startswith("gear:"):
            parts = s.split(":")
            kind = parts[1]
            big = len(parts) < 3 or parts[2] != "small"
            bl = [b for b in self.blds if b["kind"] == kind and b["built"]]
            if not bl:
                return False
            b = bl[-1]
            if bool(b.get("big")) == big:
                self.note(s, round(self.t, 1))
                return True
            swap = int(DATA["gear"]["swap_cost"])
            if self.gold < swap:
                self.hold = swap
                return False
            self.gold -= swap
            b["big"] = big
            b["swap_until"] = self.t + float(DATA["gear"]["swap_time"])
            if kind == "cog_press" and b["name"] in self.posts:
                self.posts[b["name"]]["cap"] = int(DATA["gear"]["press"]["big" if big else "small"]["crew"])
            self.note(s, round(b["swap_until"], 1))
            return True
        if s.startswith("crew:"):
            _, kind, n = s.split(":")
            posts = [nm for nm, p in self.posts.items() if p["kind"] == kind and p["bld"]["built"]]
            if not posts:
                return False
            roomy = [nm for nm in posts if self._taken(nm) < min(int(n), self.posts[nm]["cap"])]
            posts = roomy or posts      # (the first with room for the crew, as the scripted player picks)
            moved = 0
            for w in self.workers:
                if moved >= int(n) - self._taken(posts[0]):
                    break
                if not w["gone"] and w["post"] != posts[0] and w["busy"] <= self.t:
                    w["post"] = posts[0]
                    w["busy"] = self.t + 6.0
                    moved += 1
            self.note(s)
            return True
        if "*" in s:
            name, n = s.split("*")
            kind = {"horseman": "cuirassier", "officer": "dismounted"}.get(name, name)
            if n == "":
                self.repeats.append(kind)
                self.note(s, round(self.t, 1))
                return True
            done = self.unit_count.get(self.si, 0)
            su = self.step_units.setdefault(self.si, {"need": int(n), "out": 0})
            guard = 0
            while done < int(n) and guard < 12:
                guard += 1
                if not self.train(kind, self.si):
                    break
                done += 1
            self.unit_count[self.si] = done
            if done >= int(n):
                su["log"] = self.note(s)
                if su["out"] >= su["need"]:
                    self.log[su["log"]]["done"] = round(self.t, 1)
                return True
            self.hold = self.price(kind)[0]
            return False
        if s in B:
            if s in DATA["factions"][self.f]["econ"]:
                lim = int(DATA["factions"][self.f]["econ"][s]) * max(1, self.count(self.hall, True))
                if s != "feeding_pit" and self.count(s) >= lim:
                    if self.count(self.hall) > self.count(self.hall, True):
                        self.hold = int(B[s]["cost"])
                        return False        # (a new hall is going up: its slots come with it)
                    self.note(s + " (over the limit: skipped)", -3.0)
                    return True
            b = self.place(s)
            if b is None:
                self.hold = int(B[s]["cost"])
                return False
            b["log"] = self.note(s)
            return True
        self.note("?" + s, -3.0)
        return True

    def think(self):
        self.hold = 0
        if self.supply_auto:
            self.auto_supply()
        if self.f == "crown" and self.wall_gate_at >= 0 and self.t >= self.wall_gate_at and self.gold >= 50:
            self.gold -= 50
            self.wall_gate_at = -1.0
            self.notes.append("gate placed at %d s" % self.t)
        # workers first (constant production), then the steps in order, then the background units
        if self.workers_now() < self.worker_goal:
            self.train_worker()
        guard = 0
        while self.si < len(self.steps) and self.ended < 0 and guard < 8:
            guard += 1
            if not self.step(self.steps[self.si]):
                break
            self.si += 1
        for k in self.repeats:
            g, r2 = self.price(k)
            hc = int(U["horse"]["cost"]) if U[k].get("needs_horse") and self.horses <= 0 else 0
            if self.gold >= self.hold + g + hc:
                self.train(k)

    def run(self):
        dt = 0.1
        self.earned = 0.0
        self.build = BUILDS.get(self.label, {})
        while self.t < self.horizon:
            self.t = round(self.t + dt, 2)
            self._income(dt)
            if self.f == "brood":
                self._eggs(dt)
            self._build_tick(dt)
            self._prod_tick(dt)
            if self.upgrading and self.t >= self.upgrading[0]:
                self.log[self.upgrading[1]]["done"] = round(self.t, 1)
                self.hall_level += 1
                self.upgrading = None
            for e in list(self.pending_essence):
                if self.t >= e[0]:
                    self.res2 += e[1]
                    self.pending_essence.remove(e)
            for a in list(self.morphing):
                if self.t >= a["morph"]:
                    a["kind"] = "ticking_owl"
                    self.morphing.remove(a)
            self._assign()
            if self.t >= self.next_think:
                self.next_think = self.t + CAL["think"]
                self._rebalance()
                self.think()
            for at in REPORT_AT:
                if at not in self.snap and self.t >= at:
                    self.snap[at] = self.snapshot()
        return self

    def snapshot(self):
        comp = {}
        val = 0.0
        sup = 0
        hp = 0.0
        dps = 0.0
        for a in self.army:
            if a.get("ready", a["t"]) > self.t + 0.01 and a["kind"] in ("cuirassier", "dragoon"):
                pass
            k = a["kind"]
            comp[k] = comp.get(k, 0) + 1
            val += float(U[k]["cost"]) / max(1, int(U[k].get("spawn", 1))) + 0.5 * float(U[k].get("cost2", U[k].get("tension", 0)) or 0)
            sup += int(U[k]["supply"])
            hp += float(U[k]["hp"])
            dps += unit_dps(k, 1.0)
        return {"army": comp, "value": round(val), "supply": sup, "hp": round(hp), "dps": round(dps, 1), "workers": len(self.alive_workers()),
                "bank": round(self.gold), "res2": round(self.res2 if self.f != "clockwork" else self.tension), "earned": round(self.earned),
                "cap": self.cap(), "used": self.used()}


# ------------------------------------------------------------------ travel

SPRING_RUN = 50.0   # Defs.SPRING "run": a wind-up (spring) soldier runs down 50 s off the field


def wind_walk(dist, speed, decay=None):
    """Clockwork construct off the gear field: speed x lerp(0.75, 1, wind), wind falls 0.012 a second (a spring soldier's
    1/50 a second). (seconds, wind left)"""
    decay = float(E["WIND_DECAY"]) if decay is None else decay
    t, x, w = 0.0, 0.0, 1.0
    while x < dist and t < 600:
        v = speed * (0.75 + 0.25 * w)
        x += v * 0.1
        w = max(0.0, w - decay * 0.1)
        t += 0.1
    return t, w


def arrival(sim, att, map_name):
    m = DATA["maps"][map_name]
    kinds = att["units"]
    if not kinds:
        return None
    out = {}
    if att.get("drop"):
        sp = float(U["balloon"]["speed"])
        fly = m["air"] / sp
        return {"door": round(att["go"] + att["load"] + fly * 0.85, 1), "hall": round(att["go"] + att["load"] + fly, 1), "slowest": "balloon"}
    speeds = sorted((float(U[k]["speed"]), k) for k in set(kinds))
    slow_v, slow_k = speeds[0]
    fast_v, fast_k = speeds[-1]
    flyer = all(U[k].get("air") for k in set(kinds))
    d_hall = m["air"] if flyer else m["to_hall"]
    d_door = m["air"] * 0.85 if flyer else m["to_ramp_foot"]
    go = att["go"]
    ready = max([a.get("ready", a["t"]) for a in sim.army if a.get("wave") == sim.attacks.index(att) + 1] + [go])
    if sim.f == "clockwork" and not flyer:
        dec = 1.0 / SPRING_RUN if any(U[k].get("spring") for k in kinds) else float(E["WIND_DECAY"])
        t_h, w_h = wind_walk(d_hall, slow_v, dec)
        t_d, _ = wind_walk(d_door, slow_v, dec)
        out = {"door": round(ready + t_d, 1), "hall": round(ready + t_h, 1), "first": round(ready + wind_walk(d_hall, fast_v, dec)[0], 1),
               "wind_left": round(w_h, 2), "fight_s": round(w_h / dec), "slowest": slow_k}
    else:
        out = {"door": round(ready + d_door / slow_v, 1), "hall": round(ready + d_hall / slow_v, 1),
               "first": round(ready + d_hall / fast_v, 1), "slowest": slow_k}
    return out


def travel_table():
    """Every standard map: the walk from a side's rally point to the enemy's hall, and how long it takes (a Clockwork
    construct slows down and runs down off its gear field: the wind it has left on arrival)."""
    rows = []
    for name, m in DATA["maps"].items():
        d = float(m["to_hall"])
        cs_t, cs_w = wind_walk(d, float(U["clock_soldier"]["speed"]))
        rows.append((d, name, d / 32.0, d / float(U["raptor"]["speed"]), d / float(U["cuirassier"]["speed"]),
                     d / float(U["musketeer"]["speed"]), cs_t, cs_w, d / float(U["cannon"]["speed"]),
                     float(m["air"]) / float(U["balloon"]["speed"]), float(m["air"]) / 32.0))
    rows.sort()
    print("| Map | walk (tiles) | Raptor | Horseman | Musketeer | Clock Soldier (wind left) | Field Cannon | Balloon (straight line) |")
    print("|---|---|---|---|---|---|---|---|")
    for _, name, tiles, rap, hor, mus, cs_t, cs_w, can, bal, air in rows:
        print("| %s | %d | %d s | %d s | %d s | %d s (%d%%) | %d s | %d s (%d tiles) |" % (
            name.replace("_", " ").title(), round(tiles), round(rap), round(hor), round(mus), round(cs_t), round(cs_w * 100), round(can),
            round(bal), round(air)))


# ------------------------------------------------------------------ output

def fmt_t(t):
    if t is None or t < 0:
        return "-"
    return "%d:%02d" % (int(t) // 60, int(t) % 60)


def comp_text(comp):
    names = {k: U[k]["name"] for k in comp}
    return ", ".join("%d %s" % (n, names[k]) for k, n in sorted(comp.items(), key=lambda kv: -kv[1])) or "none"


def simulate(name=None, steps=None, faction=None, horizon=480.0, map_name=MAP_DEFAULT):
    if name:
        b = BUILDS[name]
        return Sim(b["faction"], b["steps"], name, horizon, map_name).run()
    return Sim(faction, steps, "custom", horizon, map_name).run()


def report(sim, maps):
    b = BUILDS.get(sim.label, {})
    print("=" * 100)
    print("%s  (%s, %s)" % (b.get("label", sim.label), sim.label, sim.f))
    print("-" * 100)
    print("%-34s %8s %8s" % ("step", "placed", "done"))
    for e in sim.log:
        print("%-34s %8s %8s" % (e["step"][:34], fmt_t(e["issued"]), fmt_t(e["done"]) if e["done"] >= 0 else ("skipped" if e["done"] == -3.0 else "-")))
    print()
    print("%-6s %-44s %6s %6s %8s %8s %6s" % ("time", "army", "value", "supply", "workers", "earned", "bank"))
    for at in REPORT_AT:
        s = sim.snap.get(at)
        if s:
            print("%-6s %-44s %6d %6s %8d %8d %6d" % (fmt_t(at), comp_text(s["army"])[:44], s["value"], "%d/%d" % (s["used"], s["cap"]),
                                                     s["workers"], s["earned"], s["bank"]))
    for i, att in enumerate(sim.attacks):
        print()
        print("attack %d leaves %s with %s (%d supply)%s" % (i + 1, fmt_t(att["go"]), comp_text({k: att["units"].count(k) for k in set(att["units"])}),
                                                           att["supply"], " by balloon" if att.get("drop") else ""))
        for m in maps:
            a = arrival(sim, att, m)
            if a:
                extra = ""
                if "wind_left" in a:
                    extra = "  wind left %.0f%% (about %d s of fight before it runs down)" % (a["wind_left"] * 100, a["fight_s"])
                print("   %-18s at the ramp %s, at the hall %s (first unit %s; slowest %s)%s" % (m, fmt_t(a["door"]), fmt_t(a["hall"]),
                                                                                             fmt_t(a.get("first", a["hall"])), U[a["slowest"]]["name"], extra))
    if sim.notes:
        print("notes:", "; ".join(sim.notes))


def strength(sim, t, wave_only=False):
    """Lanchester strength at time t: total hp x total dps (vs 1 armour), the army that exists then."""
    hp = dps = 0.0
    for a in sim.army:
        if a["t"] > t or (wave_only and not a.get("wave")):
            continue
        hp += float(U[a["kind"]]["hp"])
        dps += unit_dps(a["kind"], 1.0)
    return hp, dps


def vs(a_name, b_name, map_name):
    A = simulate(a_name, map_name=map_name)
    Bs = simulate(b_name, map_name=map_name)
    report(A, [map_name])
    report(Bs, [map_name])
    print("=" * 100)
    for att in A.attacks:
        arr = arrival(A, att, map_name)
        t = arr["hall"]
        ah, ad = strength(A, att["go"], True)
        dh, dd = strength(Bs, t)
        static = ""
        if Bs.f == "clockwork":
            n = sum(1 for b in Bs.blds if b["kind"] == "ratchet_turret" and b["built"] and b["done"] <= t)
            if n:
                dh += 450 * n
                dd += n * float(DATA["turret"]["damage"]) / float(DATA["turret"]["cooldown"])
                static = " (+%d Ratchet Turret)" % n
        ratio = (ah * ad) / max(1.0, dh * dd)
        print("%s's attack (left %s) reaches the %s hall at %s: wave hp %d x dps %.0f vs the defenders' hp %d x dps %.0f%s -> ratio %.2f"
              % (a_name, fmt_t(att["go"]), b_name, fmt_t(t), ah, ad, dh, dd, static, ratio))
        print("   (>1.5 the wave should win the fight, <0.67 it should lose; walls, range, bayonets, splash and micro are not in it)")


## Named sets of "what if" changes (--preset). econ28: the Clockwork economy being built in the wt-econ worktree (its
## 0.14.28, PROVISIONAL, not in the game yet): a Cog Press takes 6 Winders (big gear 12) for the same top rate, so a
## Winder adds about what a Labourer adds on a Farm; every Mainspring stores 200 Tension (winding stops at the cap); the
## Clock Aviary costs 150 cogs + 50 Tension. Its DRIVE rule (a building one ring away from the Clocktower or a Mainspring
## works at 90%, two rings 80%...) is taken at its best case (100%: the computer's presses and Works mesh with the
## Clocktower), and its placement rules (a Works makes Jacks only beside a Mainspring) are not modelled.
PRESETS = {
    "econ28": [("gear.press.small.crew", 6), ("gear.press.big.crew", 12), ("gear.mainspring.store", 200),
               ("buildings.cuckoo_house.cost", 150), ("buildings.cuckoo_house.tension", 50)],
}


def apply_set(path, val):
    """One what-if: DATA (or CAL with a cal. prefix) at the dotted path takes the value (a number when it reads as one)."""
    keys = path.split(".")
    root = CAL if keys[0] == "cal" else DATA
    node = root
    for k in (keys[1:-1] if keys[0] == "cal" else keys[:-1]):
        node = node[k]
    last = keys[-1]
    old_v = node.get(last)
    try:
        num = float(val)
        new_v = int(num) if (isinstance(old_v, int) and not isinstance(old_v, bool)) or (old_v is None and num == int(num)) else num
    except (TypeError, ValueError):
        new_v = val
    node[last] = new_v
    return old_v, new_v


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("build", nargs="?")
    ap.add_argument("--map", default=None)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--vs", nargs=2)
    ap.add_argument("--steps")
    ap.add_argument("--faction")
    ap.add_argument("--horizon", type=float, default=480.0)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--set", action="append", default=[], metavar="PATH=VALUE",
                    help="try a change: units.spitter.cost2=0, buildings.warren.time=30, econ.FARM_BASE=0.25, cal.crown_walk=5")
    ap.add_argument("--preset", choices=sorted(PRESETS), help="a named set of changes (econ28: the provisional Clockwork economy of wt-econ)")
    ap.add_argument("--travel", action="store_true", help="the walk to the enemy's hall on every standard map (a Markdown table)")
    a = ap.parse_args()
    if a.travel:
        travel_table()
        return
    for path, val in PRESETS.get(a.preset, []):
        old_v, new_v = apply_set(path, val)
        print("(preset %s: %s = %s, was %s)" % (a.preset, path, new_v, old_v))
    for kv in a.set:
        path, val = kv.split("=", 1)
        old_v, new_v = apply_set(path, val)
        print("(what if: %s = %s, was %s)" % (path, new_v, old_v))
    maps = [a.map] if a.map else ["kestrel_rise", "ashford_crossing", "frostmere"]
    maps = [m for m in maps if m in DATA["maps"]] or [m for m in DATA["maps"]][:3]
    if a.vs:
        vs(a.vs[0], a.vs[1], a.map or MAP_DEFAULT)
        return
    if a.steps:
        sim = simulate(steps=a.steps.split(","), faction=a.faction, horizon=a.horizon)
        report(sim, maps)
        return
    if a.all:
        rows = []
        for name in BUILDS:
            sim = simulate(name, horizon=a.horizon)
            att = sim.attacks[0] if sim.attacks else None
            arr = arrival(sim, att, a.map or MAP_DEFAULT) if att else None
            rows.append((name, sim, att, arr))
        print("%-26s %-9s %-7s %-9s %-7s %-7s %-7s %-7s" % ("build", "faction", "attack", "arrives", "3:00", "4:00", "5:00", "6:00"))
        for name, sim, att, arr in rows:
            vals = ["%d" % sim.snap[t]["value"] if t in sim.snap else "-" for t in REPORT_AT]
            print("%-26s %-9s %-7s %-9s %-7s %-7s %-7s %-7s" % (name, sim.f, fmt_t(att["go"]) if att else "-", fmt_t(arr["hall"]) if arr else "-", *vals))
        print("(army value in cost; arrival at the enemy hall on %s)" % (a.map or MAP_DEFAULT))
        return
    if not a.build:
        ap.print_help()
        return
    sim = simulate(a.build, horizon=a.horizon)
    if a.json:
        print(json.dumps({"log": sim.log, "snap": sim.snap, "attacks": sim.attacks}, indent=1))
        return
    report(sim, maps)


if __name__ == "__main__":
    main()
