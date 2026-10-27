extends AI
## Build-order study (docs/build_orders_study.md): a computer player that FOLLOWS A SCRIPTED OPENING step by step,
## then plays on as the ordinary computer. A TOOL ONLY: it subclasses the game's AI (scripts/ai.gd) and changes nothing
## in it, so the game plays exactly as before. tools/study/bo_match.gd puts it in place of one side's computer.
##
## The opening is an entry of tools/study/build_orders.json ({"faction", "steps", "then", ...}). The steps run in order,
## each one waiting until it can be done (paid for, its requirement met, a spot found), like a player reading a written
## build. While the script runs, the computer's own building, training, research, raids and waves are switched off; its
## worker crews, worker safety, defence at home, horses, abilities and micro stay on. After "end" (or the last step) the
## ordinary AI takes over with the build's "then" plan.
##
## STEPS (strings):
##   workers:N           keep the hall(s) training workers until N are alive (in the background; workers come first)
##   <building>          place one (cottage, barracks, powder_mill, farm, horse_breeder, foundry, armoury, church,
##                       town_hall, warren, brood_pen, gorge_pit, roost, clutch_mound, feeding_pit, hive, cog_press,
##                       mainspring, movement_works, regulator, ratchet_turret, escapement, cuckoo_house, clocktower)
##   <building>@proxy[:F] place it on the way to the enemy, F of the way from home to its hall (default 0.72)
##   wall                Crown: the ramp wall (the computer's own: a Cottage in the ramp's mouth and a Gate); the step is
##                       done once the Cottage is placed, the Gate follows by itself
##   <unit>*N            queue N (train-button keys: musketeer, horseman, dragoon, officer, cannon, mortar, balloon,
##                       horse, raptor, spitter, brute, skywing, bloater, clock_soldier, jack, cuckoo)
##   <unit>*             keep training it from now on (after the current step's cost is covered)
##   stop:<unit>         stop a "<unit>*"
##   research:<key>      start a research (armour, charge, high_leap, owl_morph ...)
##   upgrade             Brood: grow the capital a level (Warren, then Broodmound)
##   morph:N             Clockwork: N Swifts turn into Ticking Owls
##   crew:<kind>:N       send N workers to work that building (e.g. crew:mainspring:3)
##   gear:<kind>:big     Clockwork: swap the newest finished building of that kind onto its big gear (or :small);
##                       25 cogs, 4 s (the Pendulum is made only at a Movement Works on the big gear)
##   sacrifice:N         Brood: offer N Raptors at the Brood Pen for essence (3 each)
##   supply:auto|off     the computer's own supply buildings (default auto)
##   mill:N              Crown: N Labourers on the Powder Mill (else the computer's own rule: 3 while powder is short)
##   attack              the army goes now; attack@S: when it has S supply; attack@S|T: or at T seconds at the latest
##   drop                Crown: a Balloon takes up to 4 Musketeers and drops them by the enemy's workers
##   drop:hover          Crown: the same, but the Balloon stays up over the enemy's economy and the Musketeers fire
##                       from the basket (35% more reach) until their powder runs out or it is badly hurt
##   wait:T              wait until T seconds
##   until:workers:N     wait until N workers are alive (with workers:N before it: a "grubs first" opening)
##   end                 the script is over: the ordinary computer plays on
## The scripted attack: everything in the army goes (later units follow in pairs or more); Horsemen and Raptors hunt
## workers (the computer's own _hunt), the rest attack-move at the enemy's hall; it breaks a wall in its way; it pulls back
## only when clearly beaten (the enemy in sight worth over 1.6x the wave and 150+). Its units stay out of the computer's
## own army orders (_on_errand) until they die or come home.

class QuietScout extends AIScout:
	## The scout waits while the script runs (a written build does not change its plan on what it sees).
	func tick() -> void:
		if bool(ai.get("scripted")):
			return
		super.tick()


var bo: Dictionary = {}
var bo_name := ""
var scripted := true
var steps: Array = []
var si := 0
var step_log: Array = []            # {"step", "issued", "done"}
var worker_goal := 0
var repeats: Dictionary = {}        # train key -> true
var supply_auto := true
var wall_step := false
var _hold := 0                      # cost the current step is waiting for (background training leaves it)
var _hold2 := 0
var _unit_count: Dictionary = {}    # step index -> units queued so far
var _bwatch: Array = []             # [log index, Building] until built
var wave: Array = []
var attack_on := false
var waves_log: Array = []           # one entry per scripted attack
var _cur: Dictionary = {}
var _bdrop: Dictionary = {}
var drop_log: Array = []
var _wait_fails: Dictionary = {}    # step index -> thinks it found no spot
var _own_orders := false           # (while the scripted wave gives its orders)
var _redo: Array = []              # [kind, proxy] of a step's building lost before it stood (a blocked site is refunded)
var mill_fixed := -1                # Crown "mill:N": the Powder Mill's crew while scripted (else the computer's own rule)


func _ready() -> void:
	super()
	scout = QuietScout.new(self)
	strategy = "balanced"
	_opened = "balanced"
	opening = String(bo.get("opening", "mill"))
	steps = (bo.get("steps", []) as Array).duplicate()
	if game.mlog:
		game.mlog.add("%s follows the scripted opening %s" % [game.mlog.who(team), bo_name])


# ------------------------------------------------------------------ the computer's own parts, off while scripted

func _s(key: String) -> Variant:
	if scripted:
		match key:
			"workers":
				return 0.0
			"wave", "timing":
				return 99999
	return super._s(key)


func _econ_build() -> void:
	if not scripted:
		super._econ_build()


func _produce() -> void:
	if not scripted:
		super._produce()


func _research() -> void:
	if not scripted:
		super._research()


func _raid() -> void:
	if not scripted:
		super._raid()


func _balloon_drop() -> void:
	if not scripted and _bdrop.is_empty():
		super._balloon_drop()


func _supply() -> void:
	if scripted and not supply_auto:
		return
	super._supply()


func _cottage_wall() -> void:
	if scripted and not wall_step:
		return
	super._cottage_wall()
	if not _walled and _wall_done_t < 0.0 and not _wall_pieces.is_empty():
		_tend_wall()        # (the palisade line's pieces nobody is coming to)


func _mill_cap() -> int:
	if scripted and mill_fixed >= 0:
		return mill_fixed
	return super._mill_cap()


func _buy_horses(horses: Array, keep: Dictionary, need: int) -> void:
	if not scripted:
		super._buy_horses(horses, keep, need)


func _on_errand(u: Unit) -> bool:
	if _own_orders:
		return super._on_errand(u)      # (the wave's own orders: AI._hunt asks this too)
	return super._on_errand(u) or wave.has(u) or (not _bdrop.is_empty() and (u == _bdrop.get("b") or (_bdrop.get("men", []) as Array).has(u)))


func _build_up() -> void:
	if scripted:
		_bo_tick()
	else:
		super._build_up()


func _army() -> void:
	if scripted:
		_attack_at = 99999
	elif not _bwatch.is_empty():
		_watch_buildings()
	_wave_tick()
	_drop_tick()
	super._army()


# ------------------------------------------------------------------ the script

func _log(text: String, done := -1.0) -> int:
	step_log.append({"step": text, "issued": snappedf(game.clock, 0.1), "done": done})
	return step_log.size() - 1


func _bo_tick() -> void:
	_watch_buildings()
	_supply_guard()
	_train_workers()
	_hold = 0
	_hold2 = 0
	for r in _redo.duplicate():
		if _do_build(String(r[0]), float(r[1])) == "done":
			_redo.erase(r)
	var guard := 0 if _redo.is_empty() else 8      # (the lost building comes first, as its step did)
	while si < steps.size() and guard < 8:
		guard += 1
		var r := _do(String(steps[si]))
		if r == "wait":
			break
		si += 1
		if not scripted:
			return
	if si >= steps.size() and scripted:
		_end_script("the last step")
		return
	_repeats()


func _end_script(why: String) -> void:
	scripted = false
	strategy = String(bo.get("then", "balanced"))
	if not AI.strategies_for(game.faction_of(team)).has(strategy):
		strategy = "balanced"
	_opened = strategy
	_attack_at = int(AI.STRATEGIES[strategy]["wave"])
	if game.mlog:
		game.mlog.add("%s's scripted opening %s is over (%s): the computer plays on (%s)" % [game.mlog.who(team), bo_name, why, strategy])


func _watch_buildings() -> void:
	var keep: Array = []
	for e in _bwatch:
		var b = e[1]
		if not is_instance_valid(b) or b.dead:
			step_log[e[0]]["done"] = -2.0        # (lost before it stood)
			if e.size() > 2 and scripted:
				_redo.append(e[2])               # (placed again, as a player would after a blocked or cancelled site)
			continue
		if b.built:
			step_log[e[0]]["done"] = snappedf(game.clock, 0.1)
			continue
		keep.append(e)
	_bwatch = keep


## Supply-blocked with the money in hand and no supply building going up (the computer's own Cottage sites can be
## dropped when their builder runs from raiders): one goes up now, as a player would.
func _supply_guard() -> void:
	if not supply_auto:
		return
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team) or game.supply_used(team) < cap - 1 or _busy_building(_sup()):
		return
	if _gold() < int(Defs.BUILDINGS[_sup()]["cost"]):
		return
	var c := _spot_for(_sup())
	if c.x >= 0:
		_place(_sup(), c)


func _worker_kind() -> String:
	return String(_f()["worker"])


func _train_workers() -> void:
	if worker_goal <= 0:
		return
	var w := _worker_kind()
	var have := game.workers(team).size() + game.haulers_of(team).size() if _crown() else game.workers(team).size()
	for h in _halls():
		have += (h.queue as Array).count(w)
	for h in _halls():
		if have >= worker_goal:
			return
		if not h.built:
			continue
		if h.uses_eggs():
			if h.eggs <= 0:
				continue
		elif not (h.queue as Array).is_empty():
			continue
		if game.train(h, w) == "":
			have += 1


## One step: "done" (go on to the next) or "wait" (try again next think).
func _do(s: String) -> String:
	if s.begins_with("workers:"):
		worker_goal = int(s.substr(8))
		_log(s, game.clock)
		return "done"
	if s == "end":
		_log(s, game.clock)
		_end_script("its end step")
		return "done"
	if s.begins_with("wait:"):
		if game.clock < float(s.substr(5)):
			return "wait"
		_log(s, game.clock)
		return "done"
	if s.begins_with("until:workers:"):
		if game.workers(team).size() < int(s.substr(14)):
			return "wait"
		_log(s, game.clock)
		return "done"
	if s.begins_with("mill:"):
		mill_fixed = int(s.substr(5))
		_log(s, game.clock)
		return "done"
	if s.begins_with("supply:"):
		supply_auto = s.substr(7) != "off"
		_log(s, game.clock)
		return "done"
	if s.begins_with("stop:"):
		repeats.erase(s.substr(5))
		_log(s, game.clock)
		return "done"
	if s == "wall":
		return _do_wall(s)
	if s.begins_with("attack"):
		return _do_attack(s)
	if s == "drop" or s == "drop:hover":
		return _do_drop(s)
	if s.begins_with("research:"):
		return _do_research(s, s.substr(9))
	if s == "upgrade":
		return _do_upgrade(s)
	if s.begins_with("morph:"):
		return _do_morph(s, int(s.substr(6)))
	if s.begins_with("sacrifice:"):
		return _do_sacrifice(s, int(s.substr(10)))
	if s.begins_with("crew:"):
		var p := s.split(":")
		return _do_crew(s, p[1], int(p[2]))
	if s.begins_with("gear:"):
		return _do_gear(s)
	if s.contains("*"):
		var p2 := s.split("*")
		var key := String(p2[0])
		if p2[1] == "":
			repeats[key] = true
			_log(s, game.clock)
			return "done"
		return _do_units(s, key, int(p2[1]))
	if s.contains("@proxy"):
		var pp := s.split("@proxy")
		var frac := 0.72
		if String(pp[1]).begins_with(":"):
			frac = float(String(pp[1]).substr(1))
		if Defs.BUILDINGS.has(String(pp[0])):
			return _do_build(String(pp[0]), frac)
	if Defs.BUILDINGS.has(s):
		return _do_build(s)
	push_warning("bo_ai: unknown step " + s)
	_log("?" + s, game.clock)
	return "done"


func _do_wall(s: String) -> String:
	if not _crown():
		return "done"
	wall_step = true
	if _walled:
		_log(s + (" (palisade line)" if _cw_off else ""))
		return "done"
	if _cw_off:
		# no Cottage plan on this map: the palisade line across the ramp's top, laid in one go once its gold is in
		# (the step waits for it, like the computer's own wall: half a wall is no wall)
		if not _mine("cottage").filter(func(b: Building) -> bool: return b.built).is_empty():
			_wall_off()
			if _walled:
				_log(s + " (palisade line)")
				return "done"
			_hold = maxi(_wall_cost, 100)
			return "wait"
		if _mine("cottage").is_empty() and _gold() >= 100:
			var sp := _spot_for("cottage")      # (the palisade needs a Cottage first)
			if sp.x >= 0:
				_place("cottage", sp)
		_hold = 100
		return "wait"
	if not _cw_plan.is_empty() and _cw_cottage() != null:
		_log(s)
		_bwatch.append([step_log.size() - 1, _cw_cottage()])
		return "done"
	_hold = int(Defs.BUILDINGS["cottage"]["cost"])
	return "wait"


## Where a building of this kind goes (the computer's own placement rules).
func _spot_for(kind: String) -> Vector2i:
	if Defs.is_econ(kind):
		return _econ_spot(kind)
	if kind == _sup() and _brood():
		return _mound_spot()
	if kind == "hive":
		var cap := game.capital(team)
		if cap == null:
			return Vector2i(-1, -1)
		var home := game.find_spot(team, "hive", cap, Defs.BROOD_HALL_SPACING, Defs.BROOD_HALL_SPACING + 8, "near", true)
		if home.x < 0:
			home = game.find_spot(team, "hive", cap, Defs.BROOD_HALL_SPACING, Defs.BROOD_HALL_SPACING + 12, "near")
		return home
	if kind == "town_hall" or kind == "clocktower":
		if game.expansions.size() > team and game.expansions[team] is Vector2i and game.placement_problem(team, kind, game.expansions[team], true) == "":
			return game.expansions[team]
		return _safe_hall_spot()
	if Defs.TENSION_USERS.has(kind) and Defs.gear_mode:
		for sp in _mine("mainspring"):
			if sp.built:
				for deg in [90.0, 0.0, 180.0, 270.0]:
					var c := GearNet.ring_spot(game, team, kind, sp, deg, true)
					if c.x >= 0:
						return c
		return Vector2i(-1, -1)
	if kind == _sup() and not _halls().is_empty():
		var c3 := _find_spot(kind)
		if c3.x < 0:
			c3 = game.find_spot(team, kind, _halls()[0], 3, 30, "near")     # (the plateau is full: anywhere near)
		return c3
	if kind == "mainspring" and Defs.gear_mode and not _halls().is_empty():
		# (a Mainspring with room round it: a Tension user must mesh with it, a boxed-in one leaves none)
		var c2: Vector2i = game.find_spot(team, kind, _halls()[0], 6, 18, "near", true)
		if c2.x >= 0:
			return c2
	return _find_spot(kind)


func _do_build(kind: String, proxy := -1.0) -> String:
	var cost := int(Defs.BUILDINGS[kind]["cost"])
	if not game.requirement_met(team, kind) or _gold() < cost:
		_hold = cost
		return "wait"
	if Defs.is_econ(kind) and game.econ_count(team, kind) >= game.econ_limit(team, kind):
		if _busy_building(String(_f()["hall"])):
			_hold = cost
			return "wait"       # (a new hall is going up: its slots come with it)
		_log(kind + " (over the limit: skipped)", -3.0)
		return "done"
	var spot := _spot_for(kind) if proxy < 0.0 else _proxy_spot(kind, proxy)
	if spot.x < 0:
		_wait_fails[si] = int(_wait_fails.get(si, 0)) + 1
		var spring_cost := int(Defs.BUILDINGS["mainspring"]["cost"])
		if Defs.TENSION_USERS.has(kind) and int(_wait_fails[si]) % 12 == 0 and _gold() >= spring_cost and not _busy_building("mainspring"):
			# (no room to mesh with the Mainspring we have: a second Mainspring out where there is room, as a player would;
			# looked for again every dozen thinks while the first stays boxed in)
			var c2: Vector2i = game.find_spot(team, "mainspring", _halls()[0], 8, 22, "far_safe", true) if not _halls().is_empty() else Vector2i(-1, -1)
			if c2.x >= 0 and _place("mainspring", c2) != null:
				_log("mainspring (a second one: the first had no room for the %s)" % kind)
		if Defs.TENSION_USERS.has(kind) and _busy_building("mainspring"):
			_hold = cost
			return "wait"       # (its new Mainspring is going up)
		if int(_wait_fails[si]) > 90:
			_log(kind + " (no spot: skipped)", -3.0)
			return "done"
		_hold = cost
		return "wait"
	var b := _place(kind, spot)
	if b == null:
		_hold = cost
		return "wait"
	var i := _log(kind + (" (proxy)" if proxy >= 0.0 else ""))
	_bwatch.append([i, b, [kind, proxy]])
	return "done"


## "<building>@proxy[:F]" (study only): a spot on the way to the enemy, F of the way from home to its hall (0.72 by
## default: near their base but outside it), as a player hiding a proxy building would pick. Grey fog (0.14.32) lets
## any side build anywhere. The builder walks there from home.
func _proxy_spot(kind: String, frac: float) -> Vector2i:
	if _halls().is_empty() or _foe() < 0:
		return Vector2i(-1, -1)
	var home: Vector2 = (_halls()[0] as Building).center()
	var at: Vector2 = home.lerp(_enemy_base(), frac) / Defs.TILE
	var c: Vector2i = game.find_spot(team, kind, _halls()[0], 0, 9, "near", false, at)
	if c.x < 0:
		c = game.find_spot(team, kind, _halls()[0], 0, 16, "near", false, at)
	return c


## AI._construct, returning the site (the nearest worker that is not building; idle ones first).
func _place(kind: String, spot: Vector2i) -> Building:
	if _brood() and game.workers(team).size() <= 2 and kind != _sup():
		return null
	var best: Unit = null
	var bd := INF
	var target := Vector2(spot) * Defs.TILE
	var towers: Array = _halls().filter(func(h: Building) -> bool: return h.built and h.kind == "clocktower") if _clock() else []
	for u in game.workers(team):
		if u.order == "build" or _escort.has(u) or (scout != null and scout.is_scout(u)) or u.cocoon != 0:
			continue
		var trip: float = u.position.distance_to(target)
		if not towers.is_empty():
			trip = INF
			for h in towers:
				trip = minf(trip, u.position.distance_to(h.center()) + h.center().distance_to(target))
		var dd: float = trip + (0.0 if u.order == "idle" else 150.0) + (200.0 if u.carrying > 0 else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best == null:
		return null
	return game.place_building(team, kind, spot, [best])


## The building that trains this key, and its unit kind.
func _maker_of(key: String) -> String:
	var k := Defs.train_kind(key)
	if k == "dismounted":
		return "barracks"
	return String(Defs.UNITS[k]["from"])


func _key_of(name: String) -> String:
	match name:
		"horseman":
			return "horseman"
		"officer":
			return "dismounted"
	return name


func _try_train(key: String) -> bool:
	var k := Defs.train_kind(key)
	var from := _maker_of(key)
	for b in _mine(from):
		if not b.built:
			continue
		if b.uses_eggs():
			if b.eggs <= 0:
				continue
		elif (b.queue as Array).size() >= 2:
			continue
		if game.can_train(b, key) == "" and game.train(b, key) == "":
			return true
	return false


func _price(key: String) -> Array:
	return game.unit_price(team, key)


func _do_units(s: String, name: String, n: int) -> String:
	var key := _key_of(name)
	var done: int = int(_unit_count.get(si, 0))
	var guard := 0
	while done < n and guard < 12:
		guard += 1
		if not _try_train(key):
			break
		done += 1
	_unit_count[si] = done
	if done >= n:
		_log(s)
		return "done"
	var p := _price(key)
	_hold = int(p[0])
	_hold2 = int(p[1])
	return "wait"


## Background training ("<unit>*"): only with the current step's cost covered.
func _repeats() -> void:
	for key in repeats.keys():
		var k := _key_of(String(key))
		var p := _price(k)
		var guard := 0
		while guard < 6 and _gold() >= _hold + int(p[0]):
			guard += 1
			if not _try_train(k):
				break


func _do_research(s: String, key: String) -> String:
	var info: Dictionary = Defs.RESEARCH[key]
	for b in _mine(String(info["at"])):
		if b.built and game.research_problem(b, key) == "":
			game.start_research(b, key)
			_log(s)
			return "done"
	if game.has_tech(team, key) or game.researching(team, key):
		_log(s + " (already)", game.clock)
		return "done"
	_hold = int(info["cost"])
	return "wait"


func _do_upgrade(s: String) -> String:
	var main: Building = null
	for h in _halls():
		if h.built and not h.dead and (main == null or h.level > main.level):
			main = h
	if main == null:
		return "wait"
	if main.upgrade_t >= 0.0:
		return "wait"
	var why := game.hall_upgrade_problem(main)
	if why == "":
		game.start_hall_upgrade(main)
		_log(s)
		return "done"
	if why.begins_with("Already a"):
		_log(s + " (top level)", game.clock)
		return "done"
	var nl: Dictionary = main.next_level()
	_hold = int(nl.get("cost", 0))
	return "wait"


func _do_morph(s: String, n: int) -> String:
	var done: int = int(_unit_count.get(si, 0))
	for u in game.army(team):
		if done >= n:
			break
		if u.kind == Defs.CUCKOO and CwAir.morph_problem(u) == "":
			CwAir.start_morph(u)
			done += 1
	_unit_count[si] = done
	if done >= n:
		_log(s)
		return "done"
	_hold = int(Defs.OWL_MORPH["cost"])
	return "wait"


## Brood: offer N Raptors at the Brood Pen (3 essence each): the only early essence when nobody is fighting.
func _do_sacrifice(s: String, n: int) -> String:
	if game.nearest_of(game.center_of_team(team), team, "brood_pen") == null or _mine("brood_pen").filter(func(b: Building) -> bool: return b.built).is_empty():
		return "wait"
	var done: int = int(_unit_count.get(si, 0))
	for u in game.army(team):
		if done >= n:
			break
		if u.kind == "raptor" and not wave.has(u) and u.order != "sacrifice" and u.target == null and u.can_sacrifice():
			u.cmd_sacrifice()
			if u.order == "sacrifice":
				done += 1
	_unit_count[si] = done
	if done >= n:
		_log(s)
		return "done"
	return "wait"


func _do_crew(s: String, kind: String, n: int) -> String:
	var site: Building = null
	for b in _mine(kind):
		if b.built and (site == null or (site.crew.size() >= mini(n, site.crew_max()) and b.crew.size() < mini(n, b.crew_max()))):
			site = b        # (the first finished one, or the first with room for the crew)
	if site == null:
		return "wait"
	var sent := 0
	var labs: Array = game.workers(team).filter(func(u: Unit) -> bool: return u.order != "build" and u.home_mine != site and u.carrying == 0 and u.cocoon == 0)
	labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(site.center()) < b.position.distance_to(site.center()))
	for u in labs:
		if site.crew.size() + sent >= mini(n, site.crew_max()):
			break
		u.cmd_gather(site)
		sent += 1
	_log(s)
	return "done"


## Clockwork "gear:<kind>:big|small": the newest finished building of that kind onto that gear (Game.swap_gear).
func _do_gear(s: String) -> String:
	var p := s.split(":")
	var kind := String(p[1])
	var big := p.size() < 3 or String(p[2]) != "small"
	var list: Array = _mine(kind).filter(func(b: Building) -> bool: return b.built)
	if list.is_empty():
		return "wait"
	var b: Building = list[list.size() - 1]
	if (b.gear_swap_to if b.gear_swap_t >= 0.0 else b.gear_big) == big:
		_log(s, game.clock)
		return "done"
	if game.gear_swap_problem(b) != "":
		_hold = int(Defs.GEAR["swap_cost"])
		return "wait"
	game.swap_gear(b)
	_log(s, game.clock + float(Defs.GEAR["swap_time"]))
	return "done"


# ------------------------------------------------------------------ the scripted attack

func _army_now() -> Array:
	return game.army(team).filter(func(u: Unit) -> bool: return u.kind != "powder_wagon" and u.kind != "balloon" and u.order != "sacrifice" \
		and u.owl_t < 0.0 and not super._on_errand(u))


func _do_attack(s: String) -> String:
	var need := 0
	var by := INF
	if s.begins_with("attack@"):
		var p := s.substr(7).split("|")
		need = int(p[0])
		if p.size() > 1:
			by = float(p[1])
	var army := _army_now().filter(func(u: Unit) -> bool: return not wave.has(u))
	if _army_supply(army) < need and game.clock < by:
		return "wait"
	if army.is_empty():
		return "wait"
	_log(s)
	_start_wave(army)
	return "done"


func _start_wave(army: Array) -> void:
	for u in army:
		if not wave.has(u):
			wave.append(u)
	attack_on = true
	var comp := {}
	for u in army:
		comp[u.kind] = int(comp.get(u.kind, 0)) + 1
	_cur = {"go": snappedf(game.clock, 0.1), "supply": _army_supply(army), "value": _wave_worth(army), "comp": comp,
		"arrive": -1.0, "contact": -1.0, "dmg0": float(game.stats[team]["damage"]), "kv0": int(game.stats[team]["value_killed"]),
		"lv0": int(game.stats[_foe()]["value_killed"]) if _foe() >= 0 else 0, "wk0": _foe_workers_lost(), "end": -1.0, "why": ""}
	waves_log.append(_cur)
	if game.mlog:
		game.mlog.add("%s's scripted attack goes out (%d supply: %s)" % [game.mlog.who(team), _army_supply(army), str(comp)])


func _wave_worth(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("cost2", u.d.get("tension", 0))) * 0.5
	return v


func _foe_workers_lost() -> int:
	var f := _foe()
	if f < 0:
		return 0
	return int(game.stats[f].get("workers_lost", -1))


func _wave_tick() -> void:
	_own_orders = true
	_wave_orders()
	_own_orders = false


func _wave_orders() -> void:
	wave = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if not attack_on:
		return
	if wave.is_empty():
		_wave_over("wiped out")
		return
	# the Clockwork: a construct running low on wind leaves the attack for the gear field, as the computer's own army does
	# (AI._army: below 20%; the spring-driven Wind-ups fight on)
	if _clock():
		var homes: Array = _halls()
		for u in wave.duplicate():
			if u.wind < 0.2 and not u.runs_on_spring() and not u._in_field and not u.powered_down():
				wave.erase(u)
				if not homes.is_empty():
					u.cmd_move((homes[0] as Building).center() + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		if wave.is_empty():
			_wave_over("wound down: back to the gear field")
			return
	# later units follow in groups (two or more) while the attack is on
	var front := _front()
	var fresh: Array = _army_now().filter(func(u: Unit) -> bool: return not wave.has(u) and u.position.distance_to(front) < 500.0)
	if fresh.size() >= GROUP_MIN:
		wave.append_array(fresh)
	var c := Vector2.ZERO
	for u in wave:
		c += u.position
	c /= wave.size()
	# arrival and contact
	var foe := _foe()
	if foe >= 0 and float(_cur["arrive"]) < 0.0:
		for h in game.halls_of(foe):
			for u in wave:
				if u.position.distance_to(h.center()) < 14.0 * Defs.TILE:
					_cur["arrive"] = snappedf(game.clock, 0.1)
					break
	if float(_cur["contact"]) < 0.0 and float(game.stats[team]["damage"]) > float(_cur["dmg0"]) + 1.0:
		_cur["contact"] = snappedf(game.clock, 0.1)
	# clearly beaten: home
	var mine := 0.0
	for u in wave:
		mine += _unit_value(u)
	var a := _assess(c)
	if game.clock - float(_cur["go"]) > 8.0 and float(a["value"]) >= 150.0 and float(a["value"]) > mine * 1.6 and float(a["value"]) != DEF_UNSEEN:
		for u in wave:
			u.cmd_move(_home_spot(front))
		_wave_over("pulled back (beaten)")
		return
	# a wall in the way (melee): break it; else armed defenders near: fight them together; else go for the workers / hall
	var brk := _piece_to_break(wave, c)
	var guard: Unit = null
	var gd := 340.0
	for o in game.units_near(c, 340.0):
		if o.dead or o.off_field or not game.hostile(o.team, team) or not _armed(o) or not game.is_visible_to(team, o.position):
			continue
		var dd: float = o.position.distance_to(c)
		if dd < gd:
			gd = dd
			guard = o
	var target := _enemy_base()
	for u in wave:
		if u.siege_t > 0.0 or u.off_field or u.order in ["mount", "dismount", "board", "unload"]:
			continue
		var hunter: bool = u.kind == "cuirassier" or u.kind == "raptor"
		if brk != null and float(u.d.get("range", 0)) <= 40.0 and not u.is_air():
			if u.target != brk or u.order != "attack":
				u.cmd_attack(brk)
			continue
		if hunter and guard == null:
			_hunt(u, _prey_spot(u.position))
			continue
		if guard != null:
			if u.target == null and (u.order == "idle" or u.order == "move" or u.position.distance_to(guard.position) > 220.0):
				u.cmd_move(guard.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
			continue
		# (a Dragoon's attack-move is its own order: it rides on and gets off to fire at what comes in range)
		var amoving: bool = u.order in ["amove", "d_amove", "d_attack", "attack", "dismount", "mount"]
		if u.order == "idle" or (not amoving and u.target == null) or (u.order_point.distance_to(target) > 200.0 and u.target == null and u.order != "attack"):
			u.cmd_move(target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)


func _wave_over(why: String) -> void:
	attack_on = false
	_cur["end"] = snappedf(game.clock, 0.1)
	_cur["why"] = why
	_cur["killed_value"] = int(game.stats[team]["value_killed"]) - int(_cur["kv0"])
	var foe := _foe()
	_cur["lost_value"] = (int(game.stats[foe]["value_killed"]) - int(_cur["lv0"])) if foe >= 0 else 0
	wave.clear()
	if game.mlog:
		game.mlog.add("%s's scripted attack is over (%s)" % [game.mlog.who(team), why])


# ------------------------------------------------------------------ the balloon drop (Crown)

func _do_drop(s: String) -> String:
	if not _bdrop.is_empty():
		return "wait"
	var balloon: Unit = null
	for u in game.army(team):
		if u.kind == "balloon" and u.passengers.is_empty() and u.order in ["idle", "amove", "move", "hold"]:
			balloon = u
			break
	if balloon == null or not game._clear_at(balloon.position, 8.0, team):
		return "wait"
	var men: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "musketeer" and not wave.has(u) and u.target == null \
		and u.position.distance_to(balloon.position) < 900.0)
	if men.size() < 3:
		return "wait"
	men.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(balloon.position) < b.position.distance_squared_to(balloon.position))
	men = men.slice(0, int(Defs.DROPSHIP["capacity"]))
	var at := _drop_spot()
	if at == Vector2.INF:
		return "wait"
	balloon.cmd_stop()
	game.load_order(men, [balloon])
	_bdrop = {"b": balloon, "men": men, "phase": "load", "at": at, "t": 0.0, "hover": s == "drop:hover", "retarget": 0.0,
		"log": {"load": snappedf(game.clock, 0.1), "men": men.size(), "hover": s == "drop:hover"}}
	_log(s)
	return "done"


## The shots the men in the basket have left, their own and the balloon's store.
func _basket_shots(b: Unit) -> float:
	var n := float(b.powder)
	for p in b.passengers:
		if is_instance_valid(p) and not p.dead:
			n += float(p.powder)
	return n


## A hovering raid is over: the balloon floats home with the men aboard; what it did goes in the log.
func _hover_over(b: Unit, why: String) -> void:
	var lg: Dictionary = _bdrop["log"]
	lg["result"] = why
	lg["end"] = snappedf(game.clock, 0.1)
	lg["killed_value"] = int(game.stats[team]["value_killed"]) - int(lg.get("kv0", game.stats[team]["value_killed"]))
	lg["hp_left"] = snappedf(b.hp / maxf(1.0, b.max_hp), 0.01) if is_instance_valid(b) and not b.dead else 0.0
	drop_log.append(lg)
	if is_instance_valid(b) and not b.dead:
		var hall: Array = _halls()
		if not hall.is_empty():
			b.cmd_move(hall[0].center())
	_bdrop = {}


func _drop_tick() -> void:
	if _bdrop.is_empty():
		return
	var b = _bdrop["b"]
	_bdrop["t"] = float(_bdrop["t"]) + _think_dt
	_bdrop["men"] = (_bdrop["men"] as Array).filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var lg: Dictionary = _bdrop["log"]
	if not is_instance_valid(b) or b.dead:
		lg["result"] = "balloon lost"
		lg["end"] = snappedf(game.clock, 0.1)
		if lg.has("kv0"):
			lg["killed_value"] = int(game.stats[team]["value_killed"]) - int(lg["kv0"])
		drop_log.append(lg)
		_bdrop = {}
		return
	var hover: bool = bool(_bdrop.get("hover", false))
	match _bdrop["phase"]:
		"load":
			var walking: bool = (_bdrop["men"] as Array).any(func(u: Unit) -> bool: return u.order == "board")
			if not walking or float(_bdrop["t"]) > 30.0:
				if b.passengers.is_empty():
					lg["result"] = "nobody aboard"
					drop_log.append(lg)
					_bdrop = {}
					return
				lg["fly"] = snappedf(game.clock, 0.1)
				lg["aboard"] = b.passengers.size()
				lg["kv0"] = int(game.stats[team]["value_killed"])
				if hover:
					b.cmd_move(_bdrop["at"])
				else:
					b.cmd_unload(_bdrop["at"])
				_bdrop["phase"] = "fly"
				_bdrop["t"] = 0.0
		"hover":
			# over the enemy's economy: the basket fires by itself; stay over the workers (the spot is looked for again
			# now and then: the best economy building away from the enemy's army), home when hurt or out of powder
			if b.hp < b.max_hp * 0.4:
				_hover_over(b, "turned back hurt")
				return
			if _basket_shots(b) < 1.0:
				_hover_over(b, "out of powder")
				return
			if float(_bdrop["t"]) > 150.0:
				_hover_over(b, "time up")
				return
			_bdrop["retarget"] = float(_bdrop["retarget"]) - _think_dt
			if float(_bdrop["retarget"]) <= 0.0:
				_bdrop["retarget"] = 8.0
				var at2 := _drop_spot()
				if at2 != Vector2.INF:
					_bdrop["at"] = at2
			if b.position.distance_to(_bdrop["at"]) > 40.0 and (b.order != "move" or (b.order_point as Vector2).distance_to(_bdrop["at"]) > 1.0):
				b.cmd_move(_bdrop["at"])
		"fly":
			if hover:
				if b.position.distance_to(_bdrop["at"]) < 60.0:
					lg["landed"] = snappedf(game.clock, 0.1)        # (over the spot)
					_bdrop["phase"] = "hover"
					_bdrop["t"] = 0.0
				elif b.hp < b.max_hp * 0.4:
					_hover_over(b, "turned back hurt")
				elif b.order != "move" or (b.order_point as Vector2).distance_to(_bdrop["at"]) > 1.0:
					b.cmd_move(_bdrop["at"])
				return
			if b.passengers.is_empty():
				lg["landed"] = snappedf(game.clock, 0.1)
				lg["result"] = "landed"
				drop_log.append(lg)
				var men: Array = _bdrop["men"]
				_bdrop = {}
				var hall: Array = _halls()
				if not hall.is_empty():
					b.cmd_move(hall[0].center())
				if not men.is_empty():
					if attack_on:
						for u in men:
							if not wave.has(u):
								wave.append(u)
					else:
						_start_wave(men)
						_cur["drop"] = true
			elif b.hp < b.max_hp * 0.4 and b.work != "dropping":
				b.cmd_unload(b.position)
			elif b.order != "unload":
				b.cmd_unload(_bdrop["at"])


## Everything the match tool reads back. (A drop or a hovering raid still under way when the match ends is reported as it
## stands, so a raid that outlasts the match is not lost from the record.)
func report() -> Dictionary:
	var drops: Array = drop_log.duplicate(true)
	if not _bdrop.is_empty():
		var lg: Dictionary = (_bdrop["log"] as Dictionary).duplicate(true)
		lg["result"] = "still over them at the end" if String(_bdrop["phase"]) == "hover" else "under way at the end (%s)" % String(_bdrop["phase"])
		if lg.has("kv0"):
			lg["killed_value"] = int(game.stats[team]["value_killed"]) - int(lg["kv0"])
		var b = _bdrop.get("b")
		lg["hp_left"] = snappedf(b.hp / maxf(1.0, b.max_hp), 0.01) if is_instance_valid(b) and not b.dead else 0.0
		drops.append(lg)
	return {"name": bo_name, "scripted_until": -1.0 if scripted else 0.0, "step": si, "steps": steps.size(), "log": step_log,
		"waves": waves_log, "drops": drops}
