class_name AIScout
extends RefCounted
## The computer's scouting and what it makes of it (design_principles.md section 3: buildings
## reveal strategy fairly; scouting and counter-scouting).
##
## Unless its plan is a rush (or the air rush), which acts from the first second, a Normal or
## Hard computer sends one worker to look at the enemy's base first, and plays a plain opening
## (no early greed) until the scout reports. What it sees decides:
##   rush      the enemy has an early army, or a minimal economy with several production
##             buildings: a defensive game (army first, walls where the faction has them,
##             hold, counter when the army is bigger)
##   greedy    an expansion up early and little or no army, or a full economy with no
##             military building at all: a TIMING ATTACK sized and timed from what was seen
##   balanced  neither: carry on with the plan it was given
##   uncertain the scout was denied (killed, walled out, no path) or saw too little: that is
##             not proof of anything. It plays SAFE (an army and walls, expands without
##             greed) and sends a scout again a minute or two later.
## It only uses what its own side can see (Game.is_visible_to: the fog of war), remembers the
## enemy buildings it has seen, and revises its decision from new sightings, but at most once
## every REDECIDE seconds so it does not flip-flop. Its decisions go to the match log.

const START_AT := 18.0          # (game seconds) the first scout leaves, once it has a few workers
const MIN_WORKERS := 5
const REDECIDE := 75.0          # the least time between two decisions
const RECENT := 150.0           # an army sighting counts for this long
const RESCOUT_DENIED := 85.0    # a denied scout: the next one goes after this long
const RESCOUT_REFRESH := 170.0  # otherwise a fresh look (new hall, new tech) every so often
const MAX_TRIPS := 5
const SHOOTER_MARGIN := 80.0    # (pixels) how far outside a shooter's range the scout stands off
const MELEE_MARGIN := 70.0      # ... and outside an armed melee soldier's reach
const WATCH_FOR := 50.0         # how long it watches the ramp from its stand-off spot
const MAX_FLEES := 3            # driven back this often: it goes home
const DANGER_FOR := 30.0        # a shooter seen this long ago still counts when picking a stand-off spot
const DEFEND_FOR := 210.0       # how long a defensive game lasts before the verdict is looked at again
## Production and tech buildings: seeing them says "this enemy builds an army".
const MILITARY := ["barracks", "horse_breeder", "foundry", "armoury", "warren", "gorge_pit", "roost",
	"assembly_works", "engine_hall", "capacitor_works", "movement_works", "escapement", "cuckoo_house"]
## What a minute of a rush looks like, per faction: the army value seen before 6:00 that counts as a rush
## (the Brood's cheap bodies come early whatever it plays: it takes much more).
const RUSH_VALUE := {"crown": 300.0, "clockwork": 360.0, "brood": 800.0}
## When a timing attack hits by default (game seconds), per faction: a Crown musket / horse
## line, a Brood swarm (earlier: it hatches fast), a Clockwork power spike (later: its
## Engine Hall and Pylon first).
const TIMING_AT := {"crown": 330.0, "brood": 290.0, "clockwork": 400.0}
const TIMING_MIN_SUP := {"crown": 14, "brood": 20, "clockwork": 12}
## What a plain opening leaves out until the scout has reported.
const PENDING_MOD := {"expand": 1.0, "halls": 3, "workers": 1.0}
const SAFE_MOD := {"expand": 1.4, "halls": 3, "tech": 1.0, "workers": 1.0}
const DEFEND_MOD := {"expand": 2.2, "halls": 2, "tech": 1.25, "workers": 0.85}

var ai: AI
var game: Game
var enabled := false
var state := "wait"             # wait, going, done
var verdict := "pending"        # pending, balanced, rush, greedy, uncertain
var reason := ""
var decided_at := -999.0
var unit: Unit = null           # the scout on the road
var trips := 0
var next_trip := START_AT
var sent_at := 0.0
var last_end := 0.0
var mod := {}                   # overrides for AI._s()
var want_wall := false
var timing_target := 0          # supply a scouted timing attack waits for
var defend_until := 0.0
var log_lines: Array = []
## What the scout has learned about the enemy's army (kept across trips; read by the build and
## defence logic: AIScout.proof_not_horse_rush(), enemy_has_ranged()).
var foe_kinds_seen := {}        # armed unit kind -> true
var foe_ranged_seen := false    # a shooter (range beyond a bayonet's reach) was seen
var foe_max_range := 0.0        # the longest weapon range seen (pixels)
var foe_nonhorse_seen := false  # a SLOW armed soldier of a faction whose rush is mounted (the Crown): not a horse rush
var foe_rush_seen := {}         # fast rush unit kind -> {"count" (most seen at once), "first" (clock), "last", "speed", "pos"}
var foe_first_military := -1.0  # when an armed soldier or a military building was first seen
var foe_rush_logged := false
var foe_early_prod := {}        # military building kind -> clock it was first seen
## Production buildings that this early (game seconds) are an opening that goes for units at once.
const EARLY_PROD := {"warren": 140.0, "assembly_works": 100.0, "movement_works": 100.0}
var standoff_log: Array = []    # (the stand-off spots chosen; tests read it)       # (what went to the match log; tests read it)

var _foe := -1
var _wps: Array = []
var _wp_i := 0
var _seen_b := {}               # enemy building -> true (alive when last looked)
var _army_hist: Array = []      # [clock, value, supply] of what the enemy army looked like
var _workers_seen := 0
var _far_army_t := -1.0         # when part of its army was last seen out in the field
var _plateau: Array = []
var _cells_seen := {}
var _hall_seen := false
var _stuck := 0.0
var _mode := "route"            # route, flee (backing out of shooters' range), watch (standing off)
var _flees := 0
var _flee_t := 0.0
var _watch_pt := Vector2.ZERO
var _watch_until := 0.0
var _danger := {}               # armed enemy unit -> [position, clock] (seen lately)
var _ramp_pt := Vector2.INF     # the ramp up to the enemy's main nearest to us (pixels)
## The sentry: one cheap worker that keeps watch at the foot of a walled ramp (see _sentry_tick).
var sentry: Unit = null
var sentry_posts := 0           # how many sentries were posted (a lost one is replaced, a few times)
var sentry_flees := 0
var sentry_losses := 0
var denied_trips := 0           # trips that ended blocked / driven off / lost before the enemy's hall was seen
var sentry_log: Array = []      # ([clock, text] of what it did; tests read it)
var _sentry_next := 0.0
var _sentry_pt := Vector2.INF
var _sentry_fleeing := false


func _init(a: AI) -> void:
	ai = a
	game = a.game
	enabled = a.difficulty >= 1 and not a.peaceful and not (a.strategy in ["rush", "air", "xrush"])
	if enabled:
		mod = PENDING_MOD.duplicate() if a.strategy != "balanced" else {}


func _log_has_text(text: String) -> bool:
	return log_lines.any(func(l) -> bool: return String(l).contains(text))


func is_scout(u: Unit) -> bool:
	return (unit != null and u == unit) or (sentry != null and u == sentry)


func _say(msg: String) -> void:
	var line := "%s %s" % [game.mlog.who(ai.team) if game.mlog else "P%d" % (ai.team + 1), msg]
	log_lines.append(line)
	if game.mlog:
		game.mlog.add(line)


func _faction() -> String:
	return game.faction_of(ai.team)


# ------------------------------------------------------------------ the think

func tick() -> void:
	if game.over:
		return
	if not enabled:
		_sentry_alone()
		return
	var foe := ai._foe()
	if foe < 0:
		return
	if foe != _foe:
		_foe = foe
		_seen_b.clear()
		_army_hist.clear()
		_cells_seen.clear()
		_plateau = []
		_workers_seen = 0
		_hall_seen = false
		_danger.clear()
		_ramp_pt = Vector2.INF
		foe_kinds_seen.clear()
		foe_ranged_seen = false
		foe_max_range = 0.0
		foe_nonhorse_seen = false
		foe_rush_seen.clear()
		foe_first_military = -1.0
		foe_rush_logged = false
		foe_early_prod.clear()
	_observe()
	_check_rush_units()
	if state == "going":
		_follow()
	elif state == "wait" or state == "done":
		if verdict == "pending" and game.clock > 260.0 and trips == 0 and state == "wait":
			_apply("uncertain", "no scout got out")
		if trips < MAX_TRIPS and game.clock >= next_trip and not _busy_with_foe():
			_send()
	_redecide()
	_defence()
	_sentry_tick()


## The enemy is in our base right now (a scout would only be a waste).
func _busy_with_foe() -> bool:
	return ai._threat() != Vector2.INF


# ------------------------------------------------------------------ the scout

func _send() -> void:
	var u := _pick()
	if u == null:
		next_trip = game.clock + 10.0
		return
	var home := game.center_of_team(ai.team)
	_wps = _route(home)
	if _wps.is_empty():
		next_trip = game.clock + 30.0
		return
	unit = u
	state = "going"
	trips += 1
	sent_at = game.clock
	_wp_i = 0
	_hall_seen = false
	_stuck = 0.0
	_mode = "route"
	_flees = 0
	u.cmd_move(_wps[0])
	var what: String = Defs.UNITS[u.kind]["name"]
	_say("sends a %s to scout%s" % [what, "" if trips == 1 else " again (trip %d)" % trips])


## The scout: from the second denied trip on, the first army unit that is fast; else a worker
## that is not carrying anything (a farmer at the hall).
func _pick() -> Unit:
	if trips >= 2 and verdict == "uncertain":
		var best: Unit = null
		for u in game.army(ai.team):
			if u.order == "idle" and not ai._raiders.has(u) and (best == null or float(u.d["speed"]) > float(best.d["speed"])):
				best = u
		if best:
			return best
	var labs: Array = game.workers(ai.team)
	if labs.size() < MIN_WORKERS and game.clock < 200.0:
		return null
	var pick: Unit = null
	for u in labs:
		if u.order == "build" or u.carrying > 0 or ai._escort.has(u) or u == sentry:
			continue
		if pick == null or (u.order == "idle" and pick.order != "idle"):
			pick = u
	return pick


## Points to walk: a stand-off point toward us, the hall, then a loop round it.
func _route(home: Vector2) -> Array:
	var st := Vector2(game.starts[_foe]) + Vector2(2.5, 2.0)
	var toward := (home / Defs.TILE - st).normalized()
	if toward == Vector2.ZERO:
		toward = Vector2.RIGHT
	var pts: Array = [st + toward * 9.0]
	if game.expansions.size() > _foe and game.expansions[_foe] is Vector2i:
		pts.append(Vector2(game.expansions[_foe]) + Vector2(2.5, 2.0))      # (its natural expansion)
	pts.append(st + toward * 3.0)
	for off in [Vector2(-9, -8), Vector2(9, -8), Vector2(9, 8), Vector2(-9, 8)]:
		pts.append(st + off)
	var out: Array = []
	for p in pts:
		var c := _free_near(Vector2i(p.round()))
		if c.x >= 0:
			out.append((Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE)
	return out


func _free_near(c: Vector2i) -> Vector2i:
	for r in range(0, 6):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var m := Vector2i(x, y)
				if game.in_map(m) and game.solid[game.idx(m)] == 0:
					return m
	return Vector2i(-1, -1)


func _follow() -> void:
	if unit == null or not is_instance_valid(unit) or unit.dead:
		_finish("killed")
		return
	if unit.order == "gather" or unit.order == "build":
		_finish("pulled away")        # (another part of the computer used it)
		return
	var limit: float = 70.0 + 1.8 * game.center_of_team(ai.team).distance_to(Vector2(game.starts[_foe]) * Defs.TILE) / maxf(20.0, float(unit.d["speed"]))
	if game.clock - sent_at > limit:
		_finish("timeout")
		return
	if _avoid():
		return
	# Held up at a gate or wall on the ramp: a scout is no fighter, but it may break at the
	# structure in its way (the timeout still ends the trip). It does not turn on units.
	if unit.order == "attack" and unit.target is Building and not unit.target.dead:
		return
	var wp: Vector2 = _wps[_wp_i]
	# on past a point before standing on it (it must never idle: the workers' code takes idlers)
	if unit.position.distance_to(wp) < 110.0:
		_wp_i += 1
		_stuck = 0.0
		if _wp_i >= _wps.size():
			_finish("done")
			return
		unit.cmd_move(_wps[_wp_i])
		return
	if unit.order == "idle":
		_stuck += 1.0
		if _stuck > 2.0 and game.clock - sent_at > 8.0:
			var wall := _blocker()
			if wall != null:
				unit.cmd_attack(wall)
				_stuck = 0.0
				return
			_finish("blocked")
			return
		unit.cmd_move(wp)


## The nearest wall or gate of the enemy's right by the scout (what holds it up).
func _blocker() -> Building:
	# (NOT unit.has_attack(): that is false for every worker, and a worker is the scout; it hurts
	# a wall all the same, if slowly: damage less armour, at least 1 a blow)
	if float(unit.d["damage"]) <= 0.0 or unit.d.get("no_attack", false):
		return null
	var best: Building = null
	var bd := 170.0
	for b in game.buildings:
		if b.team != _foe or b.dead or not b.built or not unit.can_hit(b) or not (b.kind in ["gate", "palisade", "wall", "stone_wall"] or b.d.get("wall", false)):
			continue
		var dd: float = b.center().distance_to(unit.position)
		if dd < bd:
			bd = dd
			best = b
	return best


func _finish(how: String) -> void:
	state = "done"
	last_end = game.clock
	if unit != null and is_instance_valid(unit) and not unit.dead:
		var home := game.center_of_team(ai.team)
		unit.cmd_move(home)
	unit = null
	_observe()
	if how in ["blocked", "driven off", "timeout"] and not _hall_seen:
		denied_trips += 1        # (shut out: the sentry's reason to watch the ramp)
	var r := _evaluate()
	# A scout that was stopped before it saw anything decisive proves nothing (a wall, a
	# few guards): uncertainty, not a rush. What it did see before it fell still counts.
	if how in ["killed", "blocked", "timeout", "pulled away", "driven off"] and r["verdict"] == "balanced" and (not _hall_seen or _coverage() < 0.3):
		r = {"verdict": "uncertain", "reason": "the scout was %s before it saw the base" % _how_text(how)}
		_say("scout %s: playing safe, will look again" % _how_text(how))
	next_trip = game.clock + (RESCOUT_DENIED if r["verdict"] == "uncertain" else RESCOUT_REFRESH)
	# (at most one change of mind every REDECIDE seconds; the first report always counts)
	if verdict == "pending" or game.clock - decided_at >= REDECIDE:
		_apply(r["verdict"], r["reason"])


func _how_text(how: String) -> String:
	match how:
		"killed":
			return "killed"
		"blocked":
			return "blocked (walled out or no path)"
		"timeout":
			return "lost on the way"
		"driven off":
			return "driven off by the enemy's guns"
	return "turned back"


# ------------------------------------------------------------------ what it sees

func _observe() -> void:
	if _foe < 0:
		return
	var t := ai.team
	var hall_kind: String = game.faction_hall(_foe)
	for b in game.buildings:
		if b.team != _foe or b.dead or b.ghost:
			continue
		if game.is_visible_to(t, b.center()):
			_seen_b[b] = true
			if EARLY_PROD.has(b.kind) and not foe_early_prod.has(b.kind):
				foe_early_prod[b.kind] = game.clock
			if b.kind == hall_kind and b == _nearest_start_hall(b):
				_hall_seen = true
	for b in _seen_b.keys():
		if not is_instance_valid(b) or b.dead:
			_seen_b.erase(b)
	var value := 0.0
	var sup := 0
	var workers := 0
	var st := Vector2(game.starts[_foe]) * Defs.TILE
	var rush_now := {}
	for u in game.units:
		if u.team != _foe or u.dead or u.off_field or u.aboard != null:
			continue
		if not game.is_visible_to(t, u.position):
			continue
		if u.is_worker():
			workers += 1
			continue
		_learn(u)
		if _is_rush_unit(u):
			rush_now[u.kind] = int(rush_now.get(u.kind, 0)) + 1
			var e: Dictionary = foe_rush_seen.get(u.kind, {"count": 0, "first": game.clock, "last": game.clock, "speed": float(u.d["speed"]), "pos": u.position})
			e["last"] = game.clock
			e["pos"] = u.position
			foe_rush_seen[u.kind] = e
		if u.kind == "horse" or u.kind == "messenger":
			continue
		value += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
		sup += int(u.d["supply"])
		if u.position.distance_to(st) > 20.0 * Defs.TILE:
			_far_army_t = game.clock
	for k in rush_now:
		foe_rush_seen[k]["count"] = maxi(int(foe_rush_seen[k]["count"]), int(rush_now[k]))
	_workers_seen = maxi(_workers_seen, workers)
	if sup > 0 or (_army_hist.is_empty() and _hall_seen):
		_army_hist.append([game.clock, value, sup])
		if _army_hist.size() > 60:
			_army_hist.pop_front()
	# how much of the enemy's main we have looked at
	if _plateau.is_empty():
		_plateau = game.mapgen.main_area(game.starts[_foe])
	if state == "going" and unit != null and is_instance_valid(unit) and unit.position.distance_to(st) < 26.0 * Defs.TILE:
		for c in _plateau:
			if game.vis[t][game.idx(c)] == 1:
				_cells_seen[c] = true


# ------------------------------------------------------------------ danger and stand-off

static func _is_horseman(u: Unit) -> bool:
	return u.kind in ["horse", "messenger", "dragoon", "cuirassier", "mounted_missionary"] or u.d.get("mounted", false)


## What each faction rushes with (fast units that arrive long before an army would). Anything
## else armed and quick (Defs speed >= RUSH_SPEED) counts too.
const RUSH_KINDS := {
	"brood": ["raptor", "skywing"],
	"crown": ["cuirassier", "dragoon"],
	"clockwork": ["ornithopter"],
}
const RUSH_SPEED := 95.0
## Before this (game seconds) fast soldiers in numbers are the enemy's opening, not a raid.
const EARLY_RUSH_BY := 270.0


func _foe_faction() -> String:
	return game.faction_of(_foe) if _foe >= 0 else ""


## Is this a rush unit of the enemy's faction (fast, armed, and not a lone horse or messenger)?
func _is_rush_unit(u: Unit) -> bool:
	if u.kind == "horse" or u.kind == "messenger" or u.is_worker() or not u.has_attack():
		return false
	if RUSH_KINDS.get(_foe_faction(), []).has(u.kind):
		return true
	return float(u.d.get("speed", 0)) >= RUSH_SPEED


## True once the scout has seen a SLOW armed foot soldier of a faction whose rush is mounted
## (only the Crown: its Horsemen and Dragoons are the rush, a Musketeer line is the standard
## opening). Never set against the Brood or Clockwork: their quick units (Raptors, Skywings,
## Ornithopters) are the rush itself, see rush_units_seen().
func proof_not_horse_rush() -> bool:
	return foe_nonhorse_seen


func enemy_has_ranged() -> bool:
	return foe_ranged_seen


## The most fast rush soldiers of the enemy seen at once so far.
func rush_units_seen() -> int:
	var n := 0
	for k in foe_rush_seen:
		n += int(foe_rush_seen[k]["count"])
	return n


## Evidence of a rush from what was seen: fast units in numbers (or any, very early), or a
## great deal of army very early. "rush", or "" when there is none.
func rush_evidence() -> String:
	# (a Movement Works up by 1:40 is every Clockwork's ordinary opening, not a rush: two of them by 2:30 is)
	var works_early := 0
	for b in game.buildings:
		if b.team == _foe and not b.dead and not b.ghost and b.kind == "movement_works" and _seen_b.has(b):
			works_early += 1
	if works_early >= 2 and game.clock <= 150.0:
		return "two Movement Works already up at %d:%02d" % [int(game.clock) / 60, int(game.clock) % 60]
	for k in foe_early_prod:
		if k == "movement_works":
			continue
		if float(foe_early_prod[k]) <= float(EARLY_PROD[k]):
			return "a %s already up at %d:%02d" % [String(Defs.BUILDINGS[k]["name"]), int(foe_early_prod[k]) / 60, int(foe_early_prod[k]) % 60]
	var n := 0
	var first := INF
	for k in foe_rush_seen:
		if game.clock - float(foe_rush_seen[k]["last"]) > 240.0:
			continue          # (old news: the verdict may be looked at again)
		n += int(foe_rush_seen[k]["count"])
		first = minf(first, float(foe_rush_seen[k]["first"]))
	if n <= 0:
		return ""
	if first <= EARLY_RUSH_BY and (n >= 2 or first <= 150.0):
		return "%d fast %s seen at %d:%02d" % [n, _rush_names(), int(first) / 60, int(first) % 60]
	return ""


func _rush_names() -> String:
	var names: Array = []
	for k in foe_rush_seen:
		names.append(String(Defs.UNITS[k]["name"]))
	return " and ".join(names)


## How the enemy opened, from what was seen: "rush" (fast units or a big early army), "standard"
## (the base and its army seen, nothing fast), "unknown" (too little seen).
func foe_opening() -> String:
	if rush_evidence() != "":
		return "rush"
	if verdict == "rush":
		return "rush"
	if _hall_seen and (_coverage() >= 0.35 or foe_nonhorse_seen) and game.clock >= 90.0:
		return "standard"
	return "unknown"


## When the enemy's seen rush units could reach our base (game seconds), or INF when none was
## seen lately. From the nearest one to our hall at its own speed (a straight line: the path is
## no shorter).
func rush_eta() -> float:
	var best := INF
	var home := game.center_of_team(ai.team)
	for k in foe_rush_seen:
		var e: Dictionary = foe_rush_seen[k]
		if game.clock - float(e["last"]) > 40.0:
			continue
		var d := home.distance_to(e["pos"] as Vector2)
		best = minf(best, float(e["last"]) + d / maxf(40.0, float(e["speed"])))
	return best


## A rush seen is a rush: defend at once (escalation never waits for REDECIDE).
func _check_rush_units() -> void:
	var ev := rush_evidence()
	if ev == "" or verdict == "rush":
		return
	_apply("rush", ev)


## Remember an armed enemy unit in sight: what it is, and where the guns are.
func _learn(u: Unit) -> void:
	if not u.has_attack() or u.kind == "horse":
		return
	var rng := float(u.d["range"])
	if foe_first_military < 0.0:
		foe_first_military = game.clock
	if not foe_kinds_seen.has(u.kind):
		foe_kinds_seen[u.kind] = true
		var fac := _foe_faction()
		if _is_rush_unit(u):
			_say("saw an enemy %s (fast, a %s rush unit): evidence of a rush" % [String(Defs.UNITS[u.kind]["name"]), fac.capitalize()])
		elif fac == "crown" and not _is_horseman(u) and not foe_nonhorse_seen:
			foe_nonhorse_seen = true
			_say("saw an enemy %s: a slow foot soldier, the Crown's standard opening (a horse rush would show Horsemen)" % String(Defs.UNITS[u.kind]["name"]))
	if rng > 40.0:
		foe_ranged_seen = true
	foe_max_range = maxf(foe_max_range, rng)
	_danger[u] = [u.position, game.clock]


## Armed enemy units that cover the scout right now (its position is within their weapon
## range plus a margin), seen or the ones that just hit it.
func _threats() -> Array:
	var out: Array = []
	if unit == null or not is_instance_valid(unit) or unit.dead:
		return out
	var cands: Array = game.units_near(unit.position, 520.0)
	if is_instance_valid(unit.last_hitter) and unit.last_hitter is Unit and game.clock - unit.hit_clock < 3.0 and not cands.has(unit.last_hitter):
		cands.append(unit.last_hitter)
	for e in cands:
		if not (e is Unit) or e.dead or e.off_field or e.aboard != null or not game.hostile(e.team, ai.team):
			continue
		if not e.has_attack() or e.kind == "horse" or not e.can_hit(unit):
			continue
		if e != unit.last_hitter and not game.is_visible_to(ai.team, e.position):
			continue
		var rng := float(e.d["range"])
		var reach: float = rng + e.radius + unit.radius + (SHOOTER_MARGIN if rng > 40.0 else MELEE_MARGIN)
		if e.position.distance_to(unit.position) <= reach:
			out.append(e)
			_learn(e)
	return out


func _reach_of(e: Unit) -> float:
	var rng := float(e.d["range"])
	return rng + e.radius + unit.radius + (SHOOTER_MARGIN if rng > 40.0 else MELEE_MARGIN)


## Where to stand off: outside every known shooter's reach (the ones in sight and the ones
## seen lately), as close as it can be to the foot of the enemy's ramp while still seeing it
## (a ring at its own sight radius round the ramp), off the enemy's high ground, near us.
## Else straight back from the shooters.
func _standoff_point(thr: Array) -> Vector2:
	var guns: Array = []
	for e in _danger.keys():
		if not is_instance_valid(e) or e.dead or game.clock - float(_danger[e][1]) > DANGER_FOR:
			_danger.erase(e)
			continue
		guns.append([e.position if game.is_visible_to(ai.team, e.position) else _danger[e][0], _reach_of(e)])
	for e in thr:
		if not guns.any(func(g: Array) -> bool: return g[0] == e.position):
			guns.append([e.position, _reach_of(e)])
	var home := game.center_of_team(ai.team)
	if _ramp_pt == Vector2.INF:
		_ramp_pt = _find_ramp(home)
	var best := Vector2.INF
	var bs := INF
	if _ramp_pt != Vector2.INF:
		var ring: float = maxf(2.0, float(unit.d["sight"]) - 1.0) * Defs.TILE
		var st := Vector2(game.starts[_foe])
		var h0 := int(game.height[game.idx(Vector2i(st + Vector2(2.5, 2.0)))])
		for k in 16:
			var c := _free_near(Vector2i((_ramp_pt + Vector2.from_angle(TAU * k / 16.0) * ring) / Defs.TILE))
			if c.x < 0:
				continue
			var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
			if guns.any(func(g: Array) -> bool: return p.distance_to(g[0]) <= float(g[1]) + 8.0):
				continue
			var score := p.distance_to(home) + (0.0 if int(game.height[game.idx(c)]) != h0 else 4000.0)
			if score < bs:
				bs = score
				best = p
	if best == Vector2.INF:
		var from := Vector2.ZERO
		var need := 0.0
		for g in guns:
			from += g[0]
			need = maxf(need, float(g[1]))
		from /= maxf(1.0, float(guns.size()))
		var away := (unit.position - from).normalized()
		if away == Vector2.ZERO:
			away = (home - unit.position).normalized()
		var c := _free_near(Vector2i((from + away * (need + 40.0)) / Defs.TILE))
		best = (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE if c.x >= 0 else home
	return best


## The ramp cell up to the enemy's main that is nearest to us (pixels), or INF.
func _find_ramp(home: Vector2) -> Vector2:
	var st := Vector2i(Vector2(game.starts[_foe]) + Vector2(2.5, 2.0))
	var best := Vector2.INF
	var bd := INF
	for y in range(st.y - 30, st.y + 31):
		for x in range(st.x - 30, st.x + 31):
			var c := Vector2i(x, y)
			if game.in_map(c) and game.ramp[game.idx(c)] == 1:
				var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
				if p.distance_to(home) < bd:
					bd = p.distance_to(home)
					best = p
	return best


## Shooters (or any armed soldier) cover the scout: back out of their range, stand off where
## it still sees the ramp, and watch. Driven back again after it has proof of foot soldiers,
## or too often, it goes home. True while this is handling the scout.
func _avoid() -> bool:
	var thr := _threats()
	if not thr.is_empty():
		if _mode != "flee":
			if _flees >= MAX_FLEES or (foe_nonhorse_seen and _flees >= 1):
				_finish("driven off")
				return true
			_flees += 1
			_flee_t = -1.0
			_say("scout under guard (%s), backing out of range" % String(Defs.UNITS[thr[0].kind]["name"]))
		_mode = "flee"
		if game.clock - _flee_t >= 1.0:
			_flee_t = game.clock
			_watch_pt = _standoff_point(thr)
			standoff_log.append(_watch_pt)
			unit.cmd_move(_watch_pt)
		return true
	if _mode == "flee":
		# (hold a little short of the spot, before it arrives: an idle worker is taken for work)
		if unit.position.distance_to(_watch_pt) < 70.0 or unit.order == "idle":
			_mode = "watch"
			_watch_until = game.clock + WATCH_FOR
			unit.cmd_hold()
		return true
	if _mode == "watch":
		if game.clock >= _watch_until:
			_finish("done")
		return true
	return false


func _nearest_start_hall(b: Building) -> Building:
	return b if b.center().distance_to(Vector2(game.starts[_foe]) * Defs.TILE + Vector2(80, 64)) < 8.0 * Defs.TILE else null


func _coverage() -> float:
	if _plateau.is_empty():
		return 0.0
	return float(_cells_seen.size()) / float(_plateau.size())


## The best army the enemy showed in the last RECENT seconds: [value, supply].
func _recent_army() -> Array:
	var v := 0.0
	var s := 0
	for h in _army_hist:
		if game.clock - float(h[0]) <= RECENT:
			v = maxf(v, float(h[1]))
			s = maxi(s, int(h[2]))
	return [v, s]


## What the sightings say: {"verdict", "reason", "halls", "econ", "mil", "walls", "value", "sup"}.
func _evaluate() -> Dictionary:
	var halls := 0
	var econ := 0
	var mil := 0
	var walls := 0
	var hall_kind: String = game.faction_hall(_foe)
	for b in _seen_b.keys():
		if b.kind == hall_kind:
			halls += 1
		elif Defs.is_econ(b.kind):
			econ += 1
		elif MILITARY.has(b.kind):
			mil += 1
		elif b.kind == "wall" or b.kind == "gate":
			walls += 1
	var fac: String = game.faction_of(_foe)
	var econ_cap := 0
	for k in Defs.FACTIONS[fac]["econ"]:
		econ_cap += int(Defs.FACTIONS[fac]["econ"][k])
	var ra := _recent_army()
	var value: float = ra[0]
	var sup: int = ra[1]
	var thr: float = RUSH_VALUE.get(fac, 400.0)
	var clock := game.clock
	var out := {"verdict": "balanced", "reason": "", "halls": halls, "econ": econ, "mil": mil, "walls": walls, "value": value, "sup": sup}
	var cov := _coverage()
	var ev := rush_evidence()
	if ev != "":
		out["verdict"] = "rush"
		out["reason"] = ev
	elif clock < 400.0 and (value >= thr or (_far_army_t >= 0.0 and clock - _far_army_t < 60.0 and value >= thr * 0.4)):
		out["verdict"] = "rush"
		out["reason"] = "early army (%d supply) in or out of its base" % sup
	elif mil >= 2 and econ <= econ_cap and halls <= 1 and clock < 240.0 and value > 0.0:
		out["verdict"] = "rush"
		out["reason"] = "%d production buildings, %d economy buildings, %d supply of army" % [mil, econ, sup]
	elif mil >= 1 and halls <= 1 and econ < econ_cap - 1 and clock < 180.0 and _hall_seen and value >= thr * 0.5:
		out["verdict"] = "rush"
		out["reason"] = "a production building, a thin economy and %d supply of army" % sup
	elif halls >= 2 and value < thr * 0.5 and mil <= 1:
		out["verdict"] = "greedy"
		out["reason"] = "%d halls, %d economy buildings, %d military buildings, %d supply of army" % [halls, econ, mil, sup]
	elif clock >= 210.0 and econ >= econ_cap and mil == 0 and value <= 0.0 and cov >= 0.55 and _workers_seen >= 10:
		out["verdict"] = "greedy"
		out["reason"] = "a full economy (%d buildings, %d workers), no military building, no army" % [econ, _workers_seen]
	elif not _hall_seen and cov < 0.35 and halls == 0:
		out["verdict"] = "uncertain"
		out["reason"] = "it saw too little of the base"
	else:
		out["reason"] = "%d halls, %d economy, %d military buildings, %d supply of army" % [halls, econ, mil, sup]
	return out


# ------------------------------------------------------------------ deciding

## Later sightings can change the decision, but never twice within REDECIDE seconds.
func _redecide() -> void:
	if verdict == "pending" or game.clock - decided_at < REDECIDE:
		return
	if state == "going":
		return
	if verdict == "rush" and game.clock < defend_until:
		return        # (a defence is held for its time; a smaller sighting is no reason to drop it)
	var r := _evaluate()
	if r["verdict"] != verdict and not (r["verdict"] == "balanced" and verdict == "uncertain" and _coverage() < 0.35 and not _hall_seen):
		_apply(r["verdict"], r["reason"])


func _apply(v: String, why: String) -> void:
	var was := verdict
	if v == was:
		reason = why
		return
	verdict = v
	reason = why
	decided_at = game.clock
	var fac := _faction()
	# undo what the last decision changed
	mod = {}
	want_wall = false
	if was == "greedy" and ai.strategy == "timing" and ai._opened != "timing" and not ai._attacking:
		ai.strategy = ai._opened
		ai._attack_at = maxi(int(ai._s("wave")), ai._army_supply(game.army(ai.team)) + 2) if ai._attack_at >= 999 else ai._attack_at
	match v:
		"balanced":
			if ai.strategy != ai._opened and ai._opened != "timing":
				ai.strategy = ai._opened
			_say("scouted: %s (%s), carrying on with its %s plan" % [v, why, String(AI.STRATEGIES[ai.strategy]["name"]).to_lower()])
		"rush":
			mod = DEFEND_MOD.duplicate()
			want_wall = true
			defend_until = game.clock + DEFEND_FOR
			var ra := _recent_army()
			# hold at home until the army is a match for what was seen, then counter
			ai._attack_at = maxi(maxi(ai._attack_at, 16), int(ceil(float(ra[1]) * 1.4)) + 6)
			ai._regroup_until = maxf(ai._regroup_until, game.clock + float(ai._lv([200.0, 160.0, 130.0])))
			_say("scouted: rush (%s), switching to a defensive build: army and %s first, then a counter-attack" % [why, "walls" if fac == "crown" else "production"])
		"greedy":
			var plan := _timing_plan(_evaluate())
			timing_target = plan["target"]
			mod = {"timing": plan["at"], "expand": 1.0 if fac == "brood" else 1.2, "halls": 3, "tech": 0.6 if fac == "clockwork" else 0.75, "workers": 1.0}
			if not ai._attacking:
				ai.strategy = "timing"
				ai._attack_at = 999
			_say("scouted: greedy economy (%s), switching to a timing attack at %d:%02d (%d supply)" % [why, int(plan["at"]) / 60, int(plan["at"]) % 60, timing_target])
		"uncertain":
			mod = SAFE_MOD.duplicate()
			want_wall = true
			ai._attack_at = maxi(ai._attack_at, 16) if ai._attack_at < 999 else ai._attack_at
			_say("could not see the enemy (%s): playing safe (army and walls, no greedy economy), scouting again later" % why)


## When a timing attack goes and how big it is: the more economy and the less army was seen
## the earlier it hits (before the economy pays off), and the force is 1.6 times what was
## seen (army and walls) plus a margin: never into a clearly stronger defence.
func _timing_plan(r: Dictionary) -> Dictionary:
	var fac := _faction()
	var base: float = TIMING_AT.get(fac, 360.0)
	var greed: float = clampf(0.35 * (int(r["halls"]) - 1) + 0.1 * maxf(0.0, float(int(r["econ"]) - 3)) + (0.3 if float(r["value"]) < 40.0 else 0.0), 0.0, 1.0)
	var at: float = maxf(base * (1.0 - 0.35 * greed), game.clock + 30.0)
	var seen: float = float(r["sup"]) + float(int(r["walls"])) / 6.0 * 1.5
	var target: int = int(ceil(seen * 1.6)) + 4
	target = clampi(target, int(TIMING_MIN_SUP.get(fac, 12)), 60)
	return {"at": at, "target": target, "greed": greed}


## The supply a timing attack goes out with (AI._army): what the scout worked out; it comes
## down a little the longer the timing has passed, so it does go.
func timing_wave() -> int:
	if timing_target <= 0 or verdict != "greedy":
		return 6
	var late: float = maxf(0.0, game.clock - float(mod.get("timing", 0.0)) - 90.0)
	var f: float = clampf(1.0 - late / 300.0, 0.6, 1.0)
	return maxi(int(TIMING_MIN_SUP.get(_faction(), 12)) - 2, int(round(timing_target * f)))


## A scouted timing attack holds if our army is not worth enough against what the enemy
## showed lately (a clearly stronger defence is not attacked into).
func timing_ok(value: float) -> bool:
	if verdict != "greedy":
		return true
	var ra := _recent_army()
	return value >= float(ra[0]) * 1.2


# ------------------------------------------------------------------ acting on it

## A defensive or a safe game builds production earlier and walls the ramp (Crown only: the
## other factions have no walls).
func _defence() -> void:
	if verdict != "rush" and verdict != "uncertain":
		return
	if ai._hall_reserve or ai._saving:
		return
	# (the wall first, it is cheap and must stand before the enemy is here)
	if want_wall and not ai._walled and _faction() == "crown" and ai._wall_wanted():
		ai._wall_off()
		if not ai._walled:
			return          # (saving for it)
	var plan := {}
	match _faction():
		"crown":
			plan = {"barracks": 1 if game.clock < 200.0 else (2 if ai.difficulty < 2 else 3)}
		"brood":
			plan = {"warren": 1}
		"clockwork":
			plan = {ai._works(): 2}
	for k in plan:
		if ai._mine(k).size() < int(plan[k]) and not ai._busy_building(k) and game.requirement_met(ai.team, k) \
				and ai._gold() >= int(Defs.BUILDINGS[k]["cost"]) and (ai._mine(k).size() > 0 or ai._gold() >= int(Defs.BUILDINGS[k]["cost"]) + 30):
			ai._construct(k)
			return


# ------------------------------------------------------------------ the sentry at a walled ramp

const SENTRY_FROM := 100.0      # (game seconds) the earliest a sentry is posted
const SENTRY_WALLS := 2         # wall pieces seen by the ramp that make it "walled"
const SENTRY_MAX_POSTS := 4
const SENTRY_RETRY := 60.0      # a lost sentry is replaced after this long
const SENTRY_MIN_WORKERS := 7
const SENTRY_MARGIN := 10.0     # (pixels) outside a gun's range: it sees a gun only inside its own sight, so no more


## A scout that is not enabled (a rush plan) still posts a sentry once the plan has fallen back
## to a normal game.
func _sentry_alone() -> void:
	if ai.difficulty < 1 or ai.peaceful or ai.strategy in ["rush", "air", "xrush"] or game.clock < SENTRY_FROM:
		return
	var foe := ai._foe()
	if foe < 0:
		return
	_foe = foe
	_observe()
	_sentry_tick()


## The enemy's ramp is walled: wall or gate pieces seen near it, or a scout shut out of a Crown base
## (walls stand on the high ground and are rarely seen from below). Only the Crown builds walls.
func foe_ramp_walled() -> bool:
	if _foe < 0:
		return false
	if _ramp_pt == Vector2.INF:
		_ramp_pt = _find_ramp(game.center_of_team(ai.team))
	if _ramp_pt == Vector2.INF:
		return false
	var n := 0
	for b in _seen_b.keys():
		if is_instance_valid(b) and not b.dead and (b.kind in ["gate", "palisade", "wall", "stone_wall"] or b.d.get("wall", false)) \
				and b.center().distance_to(_ramp_pt) < 12.0 * Defs.TILE:
			n += 1
	return n >= SENTRY_WALLS or (denied_trips >= 1 and _foe_faction() == "crown")


## Once the foe has walled its ramp the scout is shut out and the computer goes blind. One worker
## (a grub, a labourer) then stands at the foot of the ramp, just inside its own sight of it and
## outside every gun it knows of, and keeps watching: the wall, the Musketeers behind it. It backs
## away from any armed unit that reaches it and comes back when they are gone. Cheap: one worker,
## one post at a time; a lost one is replaced up to SENTRY_MAX_POSTS times.
func _sentry_tick() -> void:
	if sentry != null and (not is_instance_valid(sentry) or sentry.dead):
		sentry = null
		_sentry_pt = Vector2.INF
		_sentry_next = game.clock + SENTRY_RETRY
		sentry_losses += 1        # (the next one stands further back)
		_sentry_log("lost")
	if sentry == null:
		if game.clock < maxf(SENTRY_FROM, _sentry_next) or sentry_posts >= SENTRY_MAX_POSTS or state == "going" or _busy_with_foe():
			return
		if not foe_ramp_walled() or game.workers(ai.team).size() < SENTRY_MIN_WORKERS:
			return
		var u := _pick()
		if u == null:
			_sentry_next = game.clock + 10.0
			return
		sentry = u
		sentry_posts += 1
		_sentry_fleeing = false
		_sentry_pt = _sentry_spot(sentry, [])
		sentry.cmd_move(_sentry_pt)
		_say("posts a %s at the foot of the walled ramp to keep watch" % String(Defs.UNITS[u.kind]["name"]))
		_sentry_log("posted")
		return
	if sentry.order == "gather" or sentry.order == "build":
		sentry = null            # (another part of the computer used it)
		_sentry_next = game.clock + 10.0
		return
	if _busy_with_foe():
		sentry = null            # (the enemy is at home: back to work)
		_sentry_next = game.clock + 30.0
		return
	var thr := _sentry_threats()
	if not thr.is_empty():
		if not _sentry_fleeing:
			_sentry_fleeing = true
			sentry_flees += 1
			_say("the sentry backs away from a %s" % String(Defs.UNITS[thr[0].kind]["name"]))
			_sentry_log("fled")
		_sentry_pt = _sentry_spot(sentry, thr)
		sentry.cmd_move(_sentry_pt)
		return
	if _sentry_fleeing:
		_sentry_fleeing = false
		_sentry_pt = _sentry_spot(sentry, [])
		sentry.cmd_move(_sentry_pt)
		return
	# (hold the post; an idle worker would be taken for work)
	if sentry.position.distance_to(_sentry_pt) > 90.0:
		if sentry.order == "idle":
			sentry.cmd_move(_sentry_pt)
	elif sentry.order != "hold" and (sentry.order == "idle" or sentry.position.distance_to(_sentry_pt) < 50.0):
		sentry.cmd_hold()


func _sentry_log(what: String) -> void:
	sentry_log.append([game.clock, what])


## Armed enemy units that can reach the sentry soon (weapon range plus a margin).
func _sentry_threats() -> Array:
	var out: Array = []
	for e in game.units_near(sentry.position, 520.0):
		if not (e is Unit) or e.dead or e.off_field or e.aboard != null or not game.hostile(e.team, ai.team):
			continue
		if not e.has_attack() or e.kind == "horse" or not e.can_hit(sentry) or not game.is_visible_to(ai.team, e.position):
			continue
		var rng := float(e.d["range"])
		if e.position.distance_to(sentry.position) <= rng + e.radius + sentry.radius + (SENTRY_MARGIN if rng > 40.0 else MELEE_MARGIN):
			out.append(e)
			_learn(e)
	return out


## The watch post: on a ring at the sentry's sight round the foot of the ramp, outside every known
## gun's reach, off the enemy's high ground, the nearest to home. If every spot is covered, the one
## farthest from the guns.
func _sentry_spot(u: Unit, thr: Array) -> Vector2:
	var home := game.center_of_team(ai.team)
	if _ramp_pt == Vector2.INF:
		_ramp_pt = _find_ramp(home)
	if _ramp_pt == Vector2.INF:
		return u.position
	var guns: Array = []
	for e in _danger.keys():
		if not is_instance_valid(e) or e.dead or game.clock - float(_danger[e][1]) > DANGER_FOR:
			_danger.erase(e)
			continue
		var rng := float(e.d["range"])
		guns.append([_danger[e][0], rng + e.radius + u.radius + (SENTRY_MARGIN if rng > 40.0 else MELEE_MARGIN)])
	for e in thr:
		var rng := float(e.d["range"])
		guns.append([e.position, rng + e.radius + u.radius + (SENTRY_MARGIN if rng > 40.0 else MELEE_MARGIN)])
	var st := Vector2(game.starts[_foe])
	var h0 := int(game.height[game.idx(Vector2i(st + Vector2(2.5, 2.0)))])
	var ring: float = maxf(2.0, float(u.d["sight"]) - 2.0) * Defs.TILE + 45.0 * sentry_losses
	var best := Vector2.INF
	var bs := INF
	var safest := Vector2.INF
	var safe_d := -INF
	for k in 16:
		var c := _free_near(Vector2i((_ramp_pt + Vector2.from_angle(TAU * k / 16.0) * ring) / Defs.TILE))
		if c.x < 0:
			continue
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
		if int(game.height[game.idx(c)]) == h0:
			continue
		var slack := INF
		for g in guns:
			slack = minf(slack, p.distance_to(g[0]) - float(g[1]))
		if slack > safe_d:
			safe_d = slack
			safest = p
		if slack <= 8.0:
			continue
		var score := p.distance_to(home)
		if score < bs:
			bs = score
			best = p
	if best == Vector2.INF:
		best = safest if safest != Vector2.INF else home
	return best
