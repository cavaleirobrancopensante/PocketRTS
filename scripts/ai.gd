class_name AI
extends Node
## Computer opponent. Runs its faction's own economy (crews every economy structure,
## builds up to its limits and expands when they're full), techs up, trains a mixed army,
## attacks in growing waves and defends when its buildings are hit.
## Difficulty: 0 easy, 1 normal, 2 hard, 3 brutal. Brutal plays like Hard but faster and
## sharper (focus fire, kiting, pulling back hurt units, retreating from fights it can't win)
## and it cheats: +50% income from everything (set by the match) and it always knows where
## you are.

var game: Game
var team := 1
var difficulty := 1
var strategy := "balanced"      # one of STRATEGIES (picked in the skirmish lobby)
## Debug/benchmark only (tools/econ_bench.gd): never attack, raid or drop; the army just
## gathers at home. Off in every real match.
var peaceful := false

## How each strategy plays.
##  wave: army supply for the first attack (then each wave waits for `step` more)
##  expand: when to take more halls (x the normal time; lower = sooner) and how many at most
##  tech: when to get tech buildings (x the normal time)
##  workers: how many workers (x normal)
##  timing: (timing attack) no attacks before this many seconds, then everything goes
const STRATEGIES := {
	"balanced": {"name": "Balanced", "wave": 14, "step": 8, "expand": 1.0, "halls": 3, "tech": 1.0, "workers": 1.0},
	"rush": {"name": "Rush", "wave": 6, "step": 2, "expand": 2.5, "halls": 2, "tech": 2.0, "workers": 0.75},
	"economy": {"name": "Economy", "wave": 34, "step": 10, "expand": 0.45, "halls": 4, "tech": 1.1, "workers": 1.25},
	"timing": {"name": "Timing attack", "wave": 999, "step": 6, "expand": 0.9, "halls": 3, "tech": 0.75, "workers": 1.0, "timing": 400.0},
	"air": {"name": "Air rush", "wave": 10, "step": 4, "expand": 1.6, "halls": 2, "tech": 0.5, "workers": 0.9, "brood_only": true},
}


## Which strategies this faction can use ("air" needs flyers: only the Brood has them).
static func strategies_for(faction: String) -> Array:
	var out: Array = []
	for k in STRATEGIES:
		if STRATEGIES[k].get("brood_only", false) and faction != "brood":
			continue
		out.append(k)
	return out


func _s(key: String) -> Variant:
	if scout != null and scout.mod.has(key):
		return scout.mod[key]       # (what the scout's report changed: AIScout)
	return STRATEGIES.get(strategy, STRATEGIES["balanced"]).get(key, STRATEGIES["balanced"].get(key))


## Crown: the opening this game: "mill" (Powder Mill first, a Musketeer line: the default) or
## "breeder" (Horse Breeder first, a Horseman rush: on Rush, and else about 3 games in 10).
var opening := "mill"
var scout: AIScout = null       # scouts the enemy first and picks the plan from what it saw (unless rushing)


func _ready() -> void:
	if not strategies_for(game.faction_of(team)).has(strategy):
		strategy = "balanced"
	_opened = strategy
	if game.faction_of(team) == "crown" and (strategy == "rush" or randf() < 0.3):
		opening = "breeder"
	if game.mlog and game.faction_of(team) == "crown":
		game.mlog.add("%s opens with a %s" % [game.mlog.who(team), "Horse Breeder (Horseman rush)" if opening == "breeder" else "Powder Mill (Musketeers)"])
	scout = AIScout.new(self)
	_attack_at = int(_s("wave"))
	if opening == "breeder" and strategy == "rush":
		_attack_at = maxi(_attack_at, RUSH_HORSEMEN * int(Defs.UNITS["cuirassier"]["supply"]))   # (the first 3 Horsemen ride out together)


## A wave goes out: remember what it's worth, to judge it when it's over.
func _wave_start(army: Array) -> void:
	_wave_value = 0.0
	for u in army:
		_wave_value += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	_wave_sup = _army_supply(army)
	_wave_kill0 = int(game.stats[team]["value_killed"])
	_siege_clear()
	_siege_said = ""
	_siege_next = 0.0
	_hold_back.clear()
	_dive_wait.clear()


## A wave is over (it died or fell back). One that killed less than it was worth failed:
## the next must be bigger. A rush (or air rush) that fails doesn't keep trickling in: the
## computer switches to a balanced game (workers, expansions, tech), gathers a real army
## and only then attacks again, in force.
func _wave_end() -> void:
	var gained := int(game.stats[team]["value_killed"]) - _wave_kill0
	if _wave_value <= 0.0 or gained >= _wave_value * 0.6:
		_failed = 0
		return
	_failed += 1
	_attack_at = maxi(_attack_at, int(ceil(_wave_sup * 1.4)))
	if strategy in ["rush", "air"]:
		strategy = "balanced"
		_attack_at = maxi(_attack_at, 30 if _brood() else 24)
		_regroup_until = game.clock + _lv([240.0, 180.0, 150.0])
		if game.mlog:
			game.mlog.add("%s's %s failed: it builds up (economy, tech) and comes back in force" % [game.mlog.who(team), String(STRATEGIES[_opened]["name"]).to_lower()])

var _think := 0.0
var _attack_at := 14            # army supply needed for the next wave
var _attacking := false
var _wave_target := Vector2.ZERO
var _saving := false            # holding gold back for an expansion
var _escort: Array = []         # Clockwork: Winders that follow the army to repair it
var _reserve := 0               # gold held back for the next economy structure
var _swarm: Array = []          # Brood: the groups of a wave, each [units, staging point]
var _swarm_phase := ""          # "", "flank" (getting into position), "strike"
var _swarm_t := 0.0
var _tight := false            # Brood: this wave packs tight (the enemy has little splash damage)
var _no_room := {}              # economy kinds with no free spot, and when we looked
# how the last wave went: what it was worth going out, and the enemy value killed before it
var _wave_value := 0.0
var _wave_sup := 0
var _wave_kill0 := 0
var _failed := 0                # waves in a row that died without paying for themselves
var _regroup_until := 0.0       # after a failed rush: no attack before this (building up)
var _opened := ""               # the strategy it started with (a failed rush switches it)
var _first_wave := false        # (the match log notes the first attack)


func _physics_process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	_tick_ai(delta)
	Prof.add("ai", _p0)


func _tick_ai(delta: float) -> void:
	if game == null or game.over:
		return
	_think -= delta
	if _stage < STAGES:
		_think_stage(_stage)       # (a think goes on over the next ticks, a part each)
		_stage += 1
		return
	if _think > 0.0:
		return
	_think_dt = [2.2, 1.2, 0.7, 0.4][difficulty]
	_think = _think_dt
	_think_stage(0)
	_stage = 1


## A think, in parts on consecutive physics ticks (all in one tick, it made a long frame):
## workers and economy, building, research and training, raids, the army, horses and the
## rest. Each part sees what the parts before it did, as before.
const STAGES := 5
var _stage := STAGES
var _think_dt := 0.0             # the time between thinks (what the parts that count time add)


func _think_stage(i: int) -> void:
	var pt := Time.get_ticks_usec()
	match i:
		0:
			_workers()
			pt = _lap("ai/workers", pt)
			_econ_build()
			_lap("ai/econ", pt)
		1:
			_supply()
			_build_up()
			_lap("ai/build", pt)
		2:
			_research()
			_produce()
			pt = _lap("ai/produce", pt)
			if difficulty >= 1 and _crown() and not peaceful:
				_raid()
				_balloon_drop()
			_lap("ai/raid", pt)
		3:
			scout.tick()
			_army()
			_lap("ai/army", pt)
		4:
			if _crown():
				_tend_wagon()
				_horses()
			pt = _lap("ai/horses", pt)
			_loose_horses()
			pt = _lap("ai/loose", pt)
			if difficulty >= 1:
				_abilities()
			pt = _lap("ai/abil", pt)
			if difficulty >= 2:
				_micro()
			_lap("ai/micro", pt)


## Everything at once (tests and tools that call it).
func _think_all() -> void:
	for i in STAGES:
		_think_stage(i)


## (the match log's "busy with": each part of the computer's think on its own)
func _lap(zone: String, since: int) -> int:
	Prof.add(zone, since)
	return Time.get_ticks_usec()


# ------------------------------------------------------------------ helpers

## Pick the value for this level from [easy, normal, hard]; Brutal is Hard, but sooner.
func _lv(v: Array) -> Variant:
	if difficulty >= 3:
		var h: Variant = v[2]
		return h * 0.8 if h is float else h
	return v[difficulty]


func _mine(kind: String) -> Array:
	return game.buildings.filter(func(b: Building) -> bool: return b.team == team and b.kind == kind and not b.dead)


func _f() -> Dictionary:
	return Defs.FACTIONS[game.faction_of(team)]


func _brood() -> bool:
	return game.faction_of(team) == "brood"


func _clock() -> bool:
	return game.faction_of(team) == "clockwork"


func _crown() -> bool:
	return game.faction_of(team) == "crown"


func _halls() -> Array:
	return _mine(_f()["hall"])


func _busy_building(kind: String) -> bool:
	return _mine(kind).any(func(b: Building) -> bool: return not b.built)


func _gold() -> int:
	return game.players[team]["gold"]


func _res2() -> float:
	return float(game.players[team]["res2"])


# ------------------------------------------------------------------ economy

func _workers() -> void:
	var labs := game.workers(team)
	var cap := 0
	for b in game.buildings:
		if b.team == team and not b.dead and int(b.d.get("crew", 0)) > 0:
			cap += b.crew_max()
	var fill: float = 0.75 if difficulty == 0 else 1.0
	var extra := 2
	if _brood():
		extra = 3          # grubs get used up as buildings
	elif _clock():
		extra = 1 + (2 if game.army(team).size() >= 4 else 0)   # builder + escorts
	var want := mini(int((cap * fill + extra) * float(_s("workers"))), 46 if difficulty >= 3 else _lv([16, 30, 40]))
	if _clock():
		# a base is saturated at ~13 Winders (Clocktower 4, 4-5 a Boiler): the rest of the
		# 100 supply is for the army
		want = mini(want, 14 * _halls().size() + extra + 2)
		want = mini(want, 36 if difficulty >= 3 else _lv([16, 26, 32]))
	var worker: String = _f()["worker"]
	var queued := 0
	for h in _halls():
		queued += h.queue.filter(func(k: String) -> bool: return k == worker).size()
	for h in _halls():
		if h.built and labs.size() + queued < want and (h.uses_eggs() or h.queue.size() < 2):
			if game.train(h, worker) == "":
				queued += 1
	# Everyone idle goes to a post with room (escorts excepted).
	_escort = _escort.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
	for u in labs:
		if u.order == "idle" and u.can_gather() and not _escort.has(u):
			var site := game.free_site(team, u.position)
			if site:
				u.cmd_gather(site)
	if _crown() or _brood():
		_move_off_tired_soil(labs)
	if _clock():
		_tend_sites(labs)


## Clockwork: a site nobody is starting (its Winder was killed or pulled away, dropping the
## crate on the way): the nearest Winder that isn't building goes to fetch or carry its crate.
func _tend_sites(labs: Array) -> void:
	for b in game.buildings:
		if b.team != team or b.dead or b.built or b.seeded or b.d["faction"] != "clockwork":
			continue
		if game.units.any(func(u: Unit) -> bool: return u.team == team and not u.dead and u.order == "build" and u.order_target == b):
			continue
		var at: Vector2 = b.crate_obj.position if b.crate == "ground" and b.crate_obj else b.center()
		var best: Unit = null
		var bd := INF
		for u in labs:
			if u.dead or u.order == "build" or _escort.has(u):
				continue
			var dd: float = u.position.distance_to(at)
			if dd < bd:
				bd = dd
				best = u
		if best:
			best.cmd_build(b)


## Crown: farmers on spent soil walk over to fresh farms with room (a couple at a time);
## Brood: grubs on pits whose Hive's ground is spent, to pits on fresh ground.
func _move_off_tired_soil(labs: Array) -> void:
	var site_kind := "farm" if _crown() else "feeding_pit"
	var fresh := _mine(site_kind).filter(func(f: Building) -> bool: return f.built and f.soil_left() > 0.0 and f.crew.size() < f.crew_max())
	if fresh.is_empty():
		return
	var moved := 0
	for u in labs:
		if moved >= 2 or fresh.is_empty():
			break
		var site = u.home_mine
		if u.order != "gather" or not (site is Building) or (site as Building).kind != site_kind or (site as Building).soil_left() > 0.0:
			continue
		var to: Building = fresh[0]
		u.cmd_gather(to)
		moved += 1
		if to.crew.size() >= to.crew_max():
			fresh.erase(to)


func _econ_build() -> void:
	if _hall_reserve:
		return
	if _halls().filter(func(h: Building) -> bool: return h.built).is_empty():
		return
	_recycle_spent()
	var order: Array = []
	if _crown():
		# the second farm, then the mill; a new hall gets its farms before its mill, the farm on
		# the freshest soil (see _econ_spot). The opening decides what comes first: the Mill for
		# Musketeers, or the Horse Breeder (a production building, one is enough) for Horsemen.
		order = ["farm", "powder_mill"]
		var early := game.workers(team).size() < 7 and game.clock < 100.0     # (the first hands farm: gold for labourers first)
		var barracks_up := not _mine("barracks").filter(func(b: Building) -> bool: return b.built).is_empty()
		var no_breeder := _mine("horse_breeder").is_empty()
		if opening == "breeder" and _mine("barracks").is_empty() and game.clock < 150.0 and game.econ_count(team, "farm") >= 1 and _halls().size() == 1:
			order.erase("farm")      # (a Horseman rush: the second farm once the Barracks is going up)
		if opening == "mill":
			if game.econ_count(team, "powder_mill") == 0 and early:
				order.erase("powder_mill")
			if no_breeder and barracks_up and game.econ_count(team, "powder_mill") > 0:
				order.append("horse_breeder")      # (after the Barracks: the Musketeers first)
		else:
			if no_breeder and not early:
				order.push_front("horse_breeder")
			# no Mill until the rush is out: the first few Horsemen (or the rush is over)
			if game.econ_count(team, "powder_mill") == 0 and (no_breeder or not barracks_up or _rushing()):
				order.erase("powder_mill")
	elif _brood():
		order = ["feeding_pit"]
		if game.clock > _lv([300.0, 200.0, 150.0]) or not _mine("warren").is_empty():
			order.append("brood_pen")
	else:
		# batteries need somewhere to go: a crusher first, then Boilers, a crusher per Boiler
		var crushers := _mine("ore_crusher").size()
		order = ["ore_crusher", "boiler"] if crushers <= _mine("boiler").size() else ["boiler", "ore_crusher"]
	_reserve = 0
	for k in _no_room.keys():
		if game.clock - float(_no_room[k]) > 20.0:
			_no_room.erase(k)
	for kind in order:
		if _no_room.has(kind):
			continue
		if not Defs.is_econ(kind) and not _mine(kind).is_empty():
			continue                 # (the Horse Breeder: one)
		if (Defs.is_econ(kind) and game.econ_count(team, kind) >= game.econ_limit(team, kind)) or _busy_building(kind):
			continue
		if _brood() and kind == "feeding_pit" and not _pit_wanted():
			continue
		if _gold() < int(Defs.BUILDINGS[kind]["cost"]):
			if _threat() == Vector2.INF:
				_reserve = int(Defs.BUILDINGS[kind]["cost"])    # save up for it first
			return
		var spot := _econ_spot(kind)
		if spot.x >= 0:
			_construct(kind, spot)
			return
		_no_room[kind] = game.clock      # nowhere to put it right now; look again later
		if kind == "feeding_pit":
			_spread_swamp()
	if _brood() and _mine("spore_vent").size() < _halls().size() and game.clock > 120.0:
		_spread_swamp()


## Brood: another Feeding Pit is wanted when the ones we have are nearly full (fewer than 3 free
## places) and the grub limit isn't reached; pits have no count cap, only the swamp's reach.
func _pit_wanted() -> bool:
	var room := 0
	for p in _mine("feeding_pit"):
		room += p.crew_max() - p.crew.size() if p.built else p.crew_max()
	var limit: int = 46 if difficulty >= 3 else _lv([16, 30, 40])
	var total := 0
	for p in _mine("feeding_pit"):
		total += p.crew_max()
	return room < 3 and total < limit + 6


## Crown, a Horseman rush: the Mill waits until this many Horsemen are out.
const RUSH_HORSEMEN := 3


## Horsemen we have out (mounted or not, light or armoured).
func _horsemen() -> int:
	return game.army(team).filter(func(u: Unit) -> bool: return u.kind == "cuirassier" or u.kind == "dismounted").size()


## Crown: the Horseman rush is on (the Breeder opening, until its first horsemen are out):
## one Barracks, every spare coin on horses and horsemen.
func _rushing() -> bool:
	return _crown() and opening == "breeder" and strategy == _opened and _horsemen() < RUSH_HORSEMEN and game.clock < 420.0


func _econ_spot(kind: String) -> Vector2i:
	var halls := _halls()
	var lodes := kind == "powder_mill" or kind == "ore_crusher"
	if kind == "feeding_pit":
		# Brood: the pit hauls to the capital and must stand on swamp joined to it, as far out as pays most
		var cap := game.capital(team)
		if cap == null or not cap.built:
			return Vector2i(-1, -1)
		return game.find_spot(team, kind, cap, 7, mini(int(Defs.FOOD_PEAK), int(game.swamp_reach[team])), "far_safe")
	if kind == "farm":
		# farms (pits) go where the soil (the Hive's ground) is freshest: tired land pays a third
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.soil_left() > b.soil_left())
	elif lodes:
		# a Mill (Crusher) goes by the freshest saltpetre (ore); by a spent hall only if it's the first
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
		if game.econ_count(team, kind) > 0:
			halls = halls.filter(func(h: Building) -> bool: return h.lode_left() > 0.05)
	for h in halls:
		if not h.built:
			continue
		var spot: Vector2i
		if kind == "feeding_pit":
			# far from the Hive pays more (best from ~18 to 22 tiles); stay on our side of the map
			spot = game.find_spot(team, kind, h, 7, int(Defs.FOOD_PEAK), "far_safe")
		elif kind == "brood_pen":
			spot = game.find_spot(team, kind, h, 3, 12, "near")
		else:
			# (on the hall's own ground first: never down below the ramp while there's room up top)
			spot = game.find_spot(team, kind, h, 4, Defs.ECON_RANGE - 2, "behind", true)
			if spot.x < 0:
				spot = game.find_spot(team, kind, h, 4, Defs.ECON_RANGE - 2, "behind")
		if spot.x >= 0:
			return spot
	return Vector2i(-1, -1)


## Brood: a Spore Vent at the edge of the swamp pushes it out for richer pits.
func _spread_swamp() -> void:
	if _busy_building("spore_vent") or _mine("spore_vent").size() >= 2 * _halls().size():
		return
	if _no_room.has("spore_vent"):
		return
	_no_room["spore_vent"] = game.clock
	if _gold() < int(Defs.BUILDINGS["spore_vent"]["cost"]) + 40:
		return
	for h in _halls():
		if h.built:
			if game.capital(team) != h:
				continue          # (swamp joined to the capital's is what extends the reach)
			var spot := game.find_spot(team, "spore_vent", h, 6, 22, "far_safe")
			if spot.x >= 0:
				_construct("spore_vent", spot)
				return


func _energy_split() -> void:
	# Ore while building up, a balance while an attack is out, all-out war only at home.
	var want := "ECONOMY"
	if _threat() != Vector2.INF:
		want = "WAR"
	elif _attacking or game.clock > _lv([600.0, 420.0, 360.0]):
		want = "BALANCED"
	if game.players[team]["split_name"] != want:
		game.set_split(team, want)


func _supply() -> void:
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team):
		return
	var used := game.supply_used(team)
	var sup: String = _f()["supply"]
	var prod := _halls().size() * 3 if _brood() else 3 * _mine("barracks").size() + 2 * _mine("foundry").size()
	if _clock():
		prod = 6 * _mine("assembly_works").size() + 5 * _mine("engine_hall").size()
	var margin := 3 + prod
	var building := _mine(sup).filter(func(b: Building) -> bool: return not b.built).size()
	if _crown() and opening == "breeder" and game.clock < 600.0 and not _mine("barracks").is_empty():
		# a Horseman rush: horsemen (3 supply each) and labourers come out together and every
		# coin goes on them, so the Cottages go up ahead (a second one at once when it's tight)
		margin += 3 + 3 * _mine("barracks").size()
		if cap - used <= margin and building < (2 if cap - used <= 6 else 1):
			_construct(sup)
		return
	if cap - used <= margin and building == 0:
		_construct(sup)


func _build_up() -> void:
	if _hall_first():
		return
	var labs := game.workers(team).size()
	# tech comes sooner or later by strategy (and sooner with money in the bank)
	var t := game.clock / float(_s("tech")) + (60.0 if _gold() > 500 else 0.0)
	var gold := _gold()
	if _clock():
		var works := _mine("assembly_works").size()
		if works == 0 and t > _lv([110.0, 70.0, 50.0]):
			_construct("assembly_works")
		elif works == 1 and t > _lv([600.0, 300.0, 220.0]) and gold > 300:
			_construct("assembly_works")
		if works > 0 and _mine("engine_hall").is_empty() and game.requirement_met(team, "engine_hall") and t > _lv([620.0, 340.0, 270.0]) and gold > 250:
			_construct("engine_hall")
		if works > 0 and _mine("charging_pylon").is_empty() and t > _lv([520.0, 280.0, 220.0]):
			_construct("charging_pylon")
		if works > 0 and _mine("capacitor_works").is_empty() and game.requirement_met(team, "capacitor_works") and (t > _lv([700.0, 400.0, 320.0]) or gold > 450):
			_construct("capacitor_works")
	elif _brood():
		if _mine("warren").is_empty() and labs >= _lv([8, 7, 6]):
			_construct("warren")
		if _mine("gorge_pit").is_empty() and game.requirement_met(team, "gorge_pit") and t > _lv([480.0, 250.0, 190.0]):
			_construct("gorge_pit")
		if _mine("roost").is_empty() and game.requirement_met(team, "roost") and t > _lv([560.0, 320.0, 260.0]):
			_construct("roost")
		elif strategy == "air" and _mine("roost").is_empty() and game.requirement_met(team, "roost"):
			_construct("roost")
		_grow_hall()
	else:
		var barracks := _mine("barracks").size()
		# the Barracks (and the palisade) need a Cottage
		if barracks == 0 and labs >= _lv([7, 6, 5]) and _mine("cottage").is_empty():
			_construct("cottage")
		if barracks == 0 and labs >= _lv([9, 8, 7]):
			_construct("barracks")
		elif barracks == 1 and (t > _lv([420.0, 200.0, 150.0]) or strategy == "rush") and gold > 150 and not _rushing():
			_construct("barracks")
		elif barracks == 2 and difficulty >= 2 and t > _lv([9999.0, 9999.0, 330.0]) and gold > 300:
			_construct("barracks")
		if _mine("foundry").is_empty() and game.requirement_met(team, "foundry") and t > _lv([480.0, 260.0, 200.0]):
			_construct("foundry")
		# the Armoury: all the Crown's research (and a second place to refit at)
		if _mine("armoury").is_empty() and game.requirement_met(team, "armoury") and (t > _lv([450.0, 240.0, 180.0]) or gold > 400) and gold >= 150 and not _rushing():
			_construct("armoury")
		if _mine("church").is_empty() and game.requirement_met(team, "church") and t > _lv([500.0, 280.0, 220.0]):
			_construct("church")
		if not _walled and t > _lv([300.0, 170.0, 120.0]) and gold >= 140 and game.requirement_met(team, "wall"):
			_wall_off()
	# Money in the bank: more production (and for the Brood, more Hives to lay eggs).
	if gold > 400 and not _saving and not _rushing():
		if _crown() and _mine("foundry").size() < 3 and gold > 700 and not _mine("foundry").is_empty() and not _busy_building("foundry"):
			_construct("foundry")
		elif _crown() and _mine("barracks").size() < 9 and not _busy_building("barracks") and not _mine("barracks").is_empty():
			_construct("barracks")
		elif _clock() and _mine("assembly_works").size() < 5 and not _busy_building("assembly_works") and not _mine("assembly_works").is_empty():
			_construct("assembly_works")
		elif _brood() and gold > 700:
			_more_halls(true)
	# Expand once our economy structures are all up (a new hall brings more slots).
	var hall: String = _f()["hall"]
	var full := true
	for kind in _f()["econ"]:
		if game.econ_count(team, kind) < game.econ_limit(team, kind):
			full = false
	var expand_t: float = _lv([9999.0, 420.0, 330.0]) * (0.7 if _brood() else 1.0) * float(_s("expand"))
	# Crown: tired soil makes expanding urgent (from ~40% of the best hall's reserve left
	# the wait shrinks to nothing as it runs out)
	var soil := _best_soil()
	if soil < 0.4:
		expand_t *= soil / 0.4
	if _halls().size() >= 2 and (game.clock > expand_t * 1.8 or soil < 0.4) and gold > int(Defs.BUILDINGS[hall]["cost"]) + (150 if soil >= 0.4 else 0):
		_more_halls(false)
	_saving = false
	# (with the soil nearly spent, the next hall is worth saving for even under attack)
	var urgent := soil < 0.25 and not _busy_building(hall)
	if _brood():
		# no far expansions: more Burrows at home for more eggs
		if t > expand_t and gold > int(Defs.BUILDINGS[hall]["cost"]) + 150:
			_more_halls(true)
	elif _halls().size() == 1 and ((full and t > expand_t * 0.6) or t > expand_t):
		var spot: Vector2i = game.expansions[team]
		if game.placement_problem(team, hall, spot, true) == "":
			if gold >= int(Defs.BUILDINGS[hall]["cost"]) + 50:
				_construct(hall, spot)
			elif _threat() == Vector2.INF or urgent:
				_saving = true
		elif urgent:
			_more_halls(false)          # our usual spot is taken: any free ground will do
			_saving = gold < int(Defs.BUILDINGS[hall]["cost"])
	elif _halls().size() >= 2 and urgent and gold < int(Defs.BUILDINGS[hall]["cost"]):
		_saving = _halls().filter(func(h: Building) -> bool: return _land(h) > 0.0).size() < int(_s("halls"))


## Brood: grow the main hall (the highest level, the oldest first) a level at a time: a
## Warren once there's a Spawning Den and a first army out (with biomass to spare), a
## Broodmound later (a Gorge Pit and 300 biomass in the bank). One upgrade at a time.
func _grow_hall() -> void:
	if _saving or _rushing() or game.over:
		return
	var main: Building = null
	for h in _halls():
		if not h.built or h.dead:
			continue
		if h.upgrade_t >= 0.0:
			return                      # already growing
		if main == null or h.level > main.level:
			main = h
	if main == null or main.next_level().is_empty():
		return
	var nl := main.next_level()
	if main.level == 1:
		var army_out: bool = _wave_sup > 0 or _army_supply(game.army(team)) >= _lv([16, 12, 10])
		if not army_out or _gold() < int(nl["cost"]) + _lv([200, 120, 60]):
			return
	elif main.level == 2:
		if _gold() < 300 or _res2() < float(nl.get("cost2", 0)) + 20.0:
			return
	if game.hall_upgrade_problem(main) == "":
		game.start_hall_upgrade(main)


## Brood: a Warren that could grow into a Broodmound (a Gorge Pit, 300 biomass banked)
## waits only for the essence: meanwhile the eggs go to creatures that cost none, and spare
## Raptors are offered up for it (_offer).
func _mound_saving() -> bool:
	if not _brood() or _gold() < 300 or not game._has_built(team, "gorge_pit"):
		return false
	var top := 0
	for h in _halls():
		if h.built and not h.dead:
			if h.upgrade_t >= 0.0:
				return false
			top = maxi(top, h.level)
	return top == 2 and _res2() < float(Defs.HALL_LEVELS[2]["cost2"]) + 20.0


var _walled := false
var _hall_reserve := false      # Crown: holding gold for a Town Hall on fresh land
var _new_hall: Building = null  # Crown: the expansion the guards stand over
var _guards: Array = []         # Crown: the part of the army guarding it
const HALL_FIRST_SOIL := 0.65   # Crown/Brood: the next hall comes first from this share of soil left
var _stage_spot := Vector2i(-1, -1)   # where the next hall goes (the escort walks there first)
var _stage_t := 0.0


## Crown (and Brood): once the freshest soil (ground) is under HALL_FIRST_SOIL and there's no second
## fresh hall coming, a new hall comes before anything else: gold is held for it whatever
## the army's size (training, tech and new buildings wait; the army keeps what it has), it
## goes on the safest free ground and (Crown) part of the army walks over to guard it.
## True while saving.
func _hall_first() -> bool:
	_hall_reserve = false
	var hall: String = _f()["hall"]
	if _halls().size() >= 7 or _best_soil() >= HALL_FIRST_SOIL:
		return false
	# halls with a fair share of soil left (one going up counts: it's fresh land)
	var fresh := _halls().filter(func(h: Building) -> bool: return not h.built or _land(h) > 0.25).size()
	if fresh >= 2 or _busy_building(hall):
		return false
	_hall_reserve = true
	_saving = true
	var cost := int(Defs.BUILDINGS[hall]["cost"])
	if _stage_spot.x < 0 or game.placement_problem(team, hall, _stage_spot, true) != "":
		_stage_spot = _safe_hall_spot()
		_stage_t = game.clock
		if _stage_spot.x < 0:
			_hall_reserve = false
			_saving = false
			return false
	if _gold() < cost:
		return true
	var spot := _stage_spot
	if _crown():
		# the escort walks over first; the hall goes down once it's there (or after a while)
		var site := (Vector2(spot) + Vector2(Defs.BUILDINGS[hall]["size"]) * 0.5) * Defs.TILE
		var there := _guards.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead and u.position.distance_to(site) < 300.0).size()
		if there < _guards.size() * 0.6 and game.clock - _stage_t < 35.0:
			return true
		# three labourers build it together (faster: less time at 10% health)
		var builders: Array = []
		var labs := game.workers(team).filter(func(u: Unit) -> bool: return u.order != "build" and not u.dead)
		labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(site) < b.position.distance_squared_to(site))
		builders = labs.slice(0, 3)
		if not builders.is_empty():
			game.place_building(team, hall, spot, builders)
	else:
		_construct(hall, spot)
	_stage_spot = Vector2i(-1, -1)
	for b in _mine(hall):
		if not b.built and b.cell == spot:
			_new_hall = b
			_guards.clear()
			if game.mlog:
				game.mlog.add("%s is expanding to fresh %s (left at its best hall: %d%%), %d tiles from its main" % [game.mlog.who(team), "land" if _crown() else ("ore" if _clock() else "ground"),
					int(round(_best_soil() * 100)), int(b.center().distance_to(Vector2(game.starts[team]) * Defs.TILE) / Defs.TILE)])
	return true


## Where a new hall is safest: free ground near our main (the usual expansion
## first), away from the enemy's side and from enemies in sight.
func _safe_hall_spot() -> Vector2i:
	var hall: String = _f()["hall"]
	var cands: Array = []
	var ex: Vector2i = game.expansions[team] if game.expansions.size() > team else Vector2i(-1, -1)
	if ex.x >= 0 and game.placement_problem(team, hall, ex, true) == "":
		cands.append(ex)
	# the map's base sites
	for bs in game.base_sites:
		if not cands.has(bs) and game.placement_problem(team, hall, bs, true) == "":
			cands.append(bs)
	for h in _halls():
		if not h.built:
			continue
		for pref in ["near", "far_safe"]:
			var sp := game.find_spot(team, hall, h, Defs.HALL_SPACING, Defs.HALL_SPACING + 12, pref)
			if sp.x >= 0 and not cands.has(sp):
				cands.append(sp)
	if _clock():
		# the Clockwork lives on ore: a Clocktower where one fell with its ore spent is wasted
		cands = cands.filter(func(c: Vector2i) -> bool: return _lode_value(c) > 1.0)
	if cands.is_empty():
		return Vector2i(-1, -1)
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var best := Vector2i(-1, -1)
	var bs := INF
	for c in cands:
		var cc := Vector2(c) + Vector2(Defs.BUILDINGS[hall]["size"]) * 0.5
		var score := cc.distance_to(home)
		var foe_d := INF
		for o in game.n_players():
			if game.hostile(team, o):
				foe_d = minf(foe_d, cc.distance_to(Vector2(game.starts[o]) + Vector2(2.5, 2.0)))
		score += maxf(0.0, cc.distance_to(home) - foe_d * 0.8) * 3.0
		for u in game.units_near(cc * Defs.TILE, 14.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.is_worker() and game.is_visible_to(team, u.position):
				score += float(u.d["supply"]) * 3.0
		if c == ex:
			score -= 4.0           # (the map's own expansion spot: open ground, near a ramp of ours)
		score -= _lode_value(c)
		if score < bs:
			bs = score
			best = c
	return best


## Crown: two thirds of the army (at least 4) escort a new Town Hall: they walk to its spot
## before it's laid down and stand guard until it's been up a minute; then a third stays
## there as its garrison while it stands. Returns the army without them.
var _guard_until := 0.0


func _guard_new_hall(army: Array) -> Array:
	if _new_hall != null and (not is_instance_valid(_new_hall) or _new_hall.dead):
		_new_hall = null
	var staging := _new_hall == null and _hall_reserve and _stage_spot.x >= 0
	if _new_hall == null and not staging:
		_guards.clear()
		return army
	var site: Vector2 = _new_hall.center() if _new_hall else (Vector2(_stage_spot) + Vector2(Defs.BUILDINGS[_f()["hall"]]["size"]) * 0.5) * Defs.TILE
	if staging:
		_guard_until = 0.0
	if _new_hall and _new_hall.built and _guard_until <= 0.0:
		_guard_until = game.clock + 60.0
	_guards = _guards.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
	# two thirds while it goes up and for its first minute, then a third stays as its garrison
	var want := maxi(4, army.size() * 2 / 3)
	if _new_hall and _new_hall.built and game.clock > _guard_until:
		want = maxi(3, army.size() / 3)
		while _guards.size() > want:
			_guards.pop_back()
	if _guards.size() < want:
		var pool := army.filter(func(u: Unit) -> bool: return not _guards.has(u) and u.kind != "powder_wagon" and not u.is_air())
		pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(site) < b.position.distance_squared_to(site))
		for u in pool.slice(0, want - _guards.size()):
			_guards.append(u)
	for u in _guards:
		if u.position.distance_to(site) > 180.0 and (u.order == "idle" or (u.order != "attack" and u.target == null and u.order_point.distance_to(site) > 200.0)):
			u.cmd_move(site + Vector2(randf_range(-70, 70), randf_range(-70, 70)), true)
	return army.filter(func(u: Unit) -> bool: return not _guards.has(u))


## The share of soil (Crown), ground (Brood) or ore (Clockwork) left at our freshest hall.
func _best_soil() -> float:
	if _brood():
		return 1.0          # (the Brood's ground is the capital's alone: no fresh ground to expand to)
	var best := 0.0
	for h in _halls():
		if h.built:
			best = maxf(best, _land(h))
	return best if not _halls().is_empty() else 1.0


## What's left of what a hall lives on: its soil (Crown), its ground (Brood), its ore (Clockwork).
func _land(h: Building) -> float:
	# (Clockwork: its ore, or its Boilers' coal if that runs out first)
	return minf(h.lode_left(), h.soil_left()) if _clock() else h.soil_left()


## How much a hall spot is worth for the lode a hall there would find (fresh, unless a hall of
## ours fell there), in tiles of walking: the Clockwork lives on ore, the Crown wants fresh
## saltpetre for powder, the Brood has none. Only the map's own base sites count (they have
## room for a hall's whole economy); other free ground is a last resort.
func _lode_value(c: Vector2i) -> float:
	if _brood() or not game.base_sites.has(c):
		return 0.0
	return game.lode_at_spot(c, _f()["hall"]) * (16.0 if _clock() else 6.0)


## Crown / Clockwork: a Mill (Crusher) on spent saltpetre (ore) is pulled down when the limit
## leaves no room for one by a hall that still has fresh saltpetre (ore) and none working it.
func _recycle_spent() -> void:
	for kind in ["powder_mill", "ore_crusher"]:
		if Defs.BUILDINGS[kind]["faction"] != game.faction_of(team) or game.econ_count(team, kind) < game.econ_limit(team, kind):
			continue
		var dep: String = Defs.LODE_NAME[Defs.LODE_FOR[kind]]
		var spent: Array = _mine(kind).filter(func(b: Building) -> bool: return b.built and b.lode_left() <= 0.0)
		if spent.is_empty():
			continue
		for h in _halls():
			if not h.built or h.lode_left() < 0.15:
				continue
			var worked := _mine(kind).any(func(b: Building) -> bool: return game.lode_hall(b) == h)
			if not worked:
				game.demolish(spent[0])
				if game.mlog:
					game.mlog.add("%s pulled down a %s by spent %s (fresh %s by another hall)" % [game.mlog.who(team), Defs.BUILDINGS[kind]["name"], dep, dep])
				return


## Take more ground: a new hall at a free spot on our side of the map, 18-30 tiles from one
## of ours. `macro`: the Brood just needs more Hives to spend its food (eggs come from Hives).
func _more_halls(macro: bool) -> void:
	var hall: String = _f()["hall"]
	# (halls on spent soil don't count toward the strategy's limit: the land has run out)
	var live := _halls().filter(func(h: Building) -> bool: return _brood() or _land(h) > 0.0).size()
	if live >= int(_s("halls")) + (1 if macro else 0) or _halls().size() >= 7 or _busy_building(hall):
		return
	if _gold() < int(Defs.BUILDINGS[hall]["cost"]):
		return
	if _brood():
		# Burrows only lay eggs: they go close round the capital (no ground of their own to find)
		var cap := game.capital(team)
		if cap == null or not cap.built:
			return
		var home := game.find_spot(team, hall, cap, Defs.BROOD_HALL_SPACING, Defs.BROOD_HALL_SPACING + 8, "near", true)
		if home.x < 0:
			home = game.find_spot(team, hall, cap, Defs.BROOD_HALL_SPACING, Defs.BROOD_HALL_SPACING + 12, "near")
		if home.x >= 0:
			_construct(hall, home)
		return
	if not macro and not _brood():
		# a base site with a fresh lode first (the Clockwork lives on ore)
		var sp := _safe_hall_spot()
		if sp.x >= 0 and _lode_value(sp) > 0.0:
			_construct(hall, sp)
			return
		if _clock():
			return          # (a Clocktower away from ore only adds Boilers with nowhere to crush)
	for h in _halls():
		if not h.built:
			continue
		var spot := game.find_spot(team, hall, h, Defs.HALL_SPACING, Defs.HALL_SPACING + 12, "far_safe")
		if spot.x >= 0:
			_construct(hall, spot)
			return


## Research once the army it's for is there and the money allows (never with an expansion
## to save for). Crown, at the Armoury, roughly in this order: the Socket Bayonet from 3
## Musketeers, the Matchlock from 4, the Cavalry Charge from 2 horsemen, Armour from 6
## soldiers, Prepared Charges from 1 gun (cannon or mortar), Flintlock from 8 Musketeers,
## the Gunner's Quadrant from 2 guns, Caplock from 12. [what's counted, how many]
const RESEARCH_AT := {"bayonet": ["musket", 3], "matchlock": ["musket", 4], "charge": ["horse", 2], "pouch": ["musket", 6],
	"armour": ["soldier", 6], "charges": ["gun", 1], "flintlock": ["musket", 8], "quadrant": ["gun", 2],
	"caplock": ["musket", 12]}


func _research() -> void:
	_refit_army()
	if _hall_reserve:
		return
	var army := game.army(team)
	var n := {"musket": 0, "horse": 0, "soldier": 0, "gun": 0}
	for u in army:
		if Defs.MUSKETS.has(u.kind):
			n["musket"] += 1
		elif u.kind == "cuirassier":
			n["horse"] += 1
		elif u.kind in ["cannon", "mortar"]:
			n["gun"] += 1
	n["soldier"] = n["musket"] + n["horse"]
	for key in Defs.RESEARCH:
		var info: Dictionary = Defs.RESEARCH[key]
		if info["faction"] != game.faction_of(team) or game.has_tech(team, key) or game.researching(team, key):
			continue
		var at: Array = RESEARCH_AT.get(key, ["musket", 0])
		if int(n[at[0]]) < int(at[1]) * (1.5 if difficulty == 0 else 1.0):
			continue
		if _gold() < int(info["cost"]) + _lv([150, 60, 20]) or _res2() < float(info.get("cost2", 0)) + 20.0:
			continue
		for b in _mine(info["at"]):
			if game.research_problem(b, key) == "":
				game.start_research(b, key)
				break


## Crown: research only unlocks the soldiers' equipment; each man is refitted at a Barracks,
## an Armoury or a Powder Wagon. AUTO REFIT stays on at our Barracks and Armouries, and
## between attacks (nothing on our base) idle soldiers that lack an upgrade walk back to get
## it while the money allows. (Light soldiers kept light on purpose, against an enemy strong
## against armour, aren't sent for Armour: _want_armour.)
func _refit_army() -> void:
	if not _crown():
		return
	for k in Defs.REFIT_AT:
		for b in _mine(k):
			b.auto_refit = true
	if _attacking or _gold() < _lv([200, 120, 80]) or _threat() != Vector2.INF:
		return
	var sent := 0
	for u in game.army(team):
		if sent >= 6 or _gold() < _lv([200, 120, 80]):
			break
		if not Defs.ARMOURED.has(u.kind) or u.order != "idle" or u.target != null or _on_errand(u):
			continue
		var went := false
		for w in game.refit_options(u):
			if w == "armour" and not _want_armour():
				continue
			if int(game.refit_order([u], w, true)[0]) > 0:
				went = true
		if went:
			sent += 1
	if sent > 0 and game.mlog:
		game.mlog.add("%s sent %d soldier%s back to refit" % [game.mlog.who(team), sent, "" if sent == 1 else "s"])
var _raiders: Array = []        # Crown: cuirassiers out hunting the enemy's workers
var _raid_home := 0.0


## Crown: up to four Cuirassiers ride out to hunt the enemy's workers and economy, the
## farther from the enemy's main the better (Brood grubs hauling from distant pits,
## undefended farms). They avoid armies and ride home to mend when badly hurt.
func _raid() -> void:
	_raiders = _raiders.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
	if opening == "breeder" and strategy == "rush":
		_raiders.clear()             # (a Horseman rush: they ride out together with the wave)
		return
	for u in game.army(team):
		if _raiders.size() >= 4:
			break
		if u.kind == "cuirassier" and not _raiders.has(u):
			_raiders.append(u)
	if _raiders.size() < 2:
		return
	var foe := _foe()
	if foe < 0:
		return
	var c := Vector2.ZERO
	var hp := 0.0
	for u in _raiders:
		c += u.position
		hp += u.hp / u.max_hp
	c /= _raiders.size()
	hp /= _raiders.size()
	var home: Vector2 = _halls()[0].center() if not _halls().is_empty() else c
	# badly hurt, or an army closing in: ride home
	var danger := 0
	for o in game.units_near(c, 260.0):
		if game.hostile(o.team, team) and not o.dead and not o.is_worker() and o.kind != "grub":
			danger += int(o.d["supply"])
	if hp < 0.45 or danger >= 6:
		_raid_home = 12.0
	if _raid_home > 0.0:
		_raid_home -= 1.0
		for u in _raiders:
			if u.position.distance_to(home) > 200.0:
				u.cmd_move(home + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		return
	var best := _prey_spot(c)
	for u in _raiders:
		_hunt(u, best)


## Where cavalry finds its prey: the enemy's workers we can see (the farther from its main
## the better: grubs hauling from distant pits, labourers at outlying farms), else the
## economy buildings they work at (Farms, Feeding Pits, Mills...), else its base.
func _prey_spot(from: Vector2) -> Vector2:
	var foe := _foe()
	if foe < 0:
		return _enemy_base()
	var their_main: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if game.starts.size() > foe else from
	var best := Vector2.INF
	var score := -INF
	for o in game.units:
		if o.dead or o.off_field or not game.hostile(o.team, team) or not o.is_worker() or not game.is_visible_to(team, o.position):
			continue
		var s: float = o.position.distance_to(their_main) - o.position.distance_to(from) * 0.5
		if s > score:
			score = s
			best = o.position
	if best == Vector2.INF:
		for b in game.buildings:
			if b.dead or b.ghost or not game.hostile(b.team, team) or not Defs.is_econ(b.kind):
				continue
			var s: float = b.center().distance_to(their_main) - b.center().distance_to(from) * 0.5
			if s > score:
				score = s
				best = b.center()
	if best == Vector2.INF:
		best = _enemy_base()
	return best


## Cavalry on a raid (or the Horseman rush) hunts workers first, then fights what fights
## it, and goes for buildings only with no prey left: a worker it can see within 10 tiles is
## ridden down; a fight with soldiers goes on; a building it set about on the way (a Hive,
## a Town Hall) is left for the prey still farther on: it rides there (not an attack-move,
## which would stop at every building) and only attack-moves once it's there.
func _hunt(u: Unit, prey: Vector2) -> void:
	if u.dead or u.off_field or u.order == "mount" or u.order == "dismount" or _on_errand(u):
		return
	var T := Defs.TILE
	var w: Unit = null
	var wd := 10.0 * T
	for o in game.units_near(u.position, wd):
		if o.dead or o.off_field or not o.is_worker() or not game.hostile(o.team, team) or not u.can_hit(o) or not game.is_visible_to(team, o.position):
			continue
		var dd: float = o.position.distance_to(u.position)
		if dd < wd:
			wd = dd
			w = o
	var tgt = u.target if u.target != null and is_instance_valid(u.target) and not u.target.dead else null
	var fighting: bool = tgt is Unit and not (tgt as Unit).is_worker() and (tgt as Unit).kind != "horse"
	if w and not fighting:
		if u.order != "attack" or u.order_target == null or not is_instance_valid(u.order_target) or u.order_target.dead or not (u.order_target is Unit and (u.order_target as Unit).is_worker()):
			u.cmd_attack(w)
		return
	if fighting or (u.order == "attack" and u.order_target is Unit):
		return                           # (soldiers: the fight goes on; a worker: run him down)
	var far := u.position.distance_to(prey) > 5.0 * T
	if far and (tgt is Building or u.order == "idle" or u.order_point.distance_to(prey) > 160.0 or u.order == "attack"):
		u.cmd_move(prey + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	elif not far and (u.order == "idle" or u.order == "move"):
		u.cmd_move(prey + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)


## Crown: wall the top of each ramp up to the main base, with a two-wide gate in the
## middle. The wall is every free high-ground cell touching the ramp, so nothing slips by.
func _wall_off() -> void:
	_walled = true
	if game.starts.size() <= team:
		return
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var left := {}
	for y in range(int(home.y) - 22, int(home.y) + 23):
		for x in range(int(home.x) - 22, int(home.x) + 23):
			var c := Vector2i(x, y)
			if game.in_map(c) and game.ramp[game.idx(c)] == 1:
				left[c] = true
	var builder: Unit = null
	var bd := INF
	for u in game.workers(team):
		if u.order == "build":
			continue
		var dd: float = u.position.distance_to(home * Defs.TILE)
		if dd < bd:
			bd = dd
			builder = u
	var first := true
	while not left.is_empty():
		# one ramp: the cells joined to the first one left
		var start: Vector2i = left.keys()[0]
		var ramp_cells: Array = []
		var todo: Array = [start]
		left.erase(start)
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			ramp_cells.append(c)
			for dd2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dd2
				if left.has(n):
					left.erase(n)
					todo.append(n)
		var band := {}
		for rc in ramp_cells:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c: Vector2i = rc + Vector2i(dx, dy)
					if game.in_map(c) and game.height[game.idx(c)] == 1 and game.ramp[game.idx(c)] == 0 and game.is_free(c):
						band[c] = true
		if band.size() < 2:
			continue
		var mid := Vector2.ZERO
		for rc in ramp_cells:
			mid += Vector2(rc)
		mid /= ramp_cells.size()
		var cells: Array = band.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
		var gates: Array = [cells[0]]
		for c in cells.slice(1):
			if (c - cells[0]).length() <= 1.01:
				gates.append(c)
				break
		var placed := 0
		for c in cells:
			var k := "gate" if gates.has(c) else "wall"
			if game.place_building(team, k, c, [builder] if first and builder else []):
				first = false
				placed += 1
		if game.mlog and placed > 0:
			game.mlog.add("%s walled its ramp (%d pieces)" % [game.mlog.who(team), placed])


## One of our ghost sites couldn't start (blocked): plan again. A wall piece: the ramp gets
## walled again (only its gaps); anything else is simply missing and gets placed anew.
func site_failed(b: Building) -> void:
	if Defs.BUILDINGS[b.kind].get("line", false):
		_walled = false
	_no_room.erase(b.kind)


func _construct(kind: String, at := Vector2i(-1, -1)) -> void:
	if _gold() < int(Defs.BUILDINGS[kind]["cost"]):
		return
	if not game.requirement_met(team, kind):
		return
	var spot := at if at.x >= 0 else _find_spot(kind)
	if spot.x < 0:
		return
	# Brood: the grub is used up, so don't eat into a tiny economy.
	if _brood() and game.workers(team).size() <= 3 and kind != _f()["supply"]:
		return
	# The nearest worker that isn't busy building; idle ones first.
	var best: Unit = null
	var bd := INF
	var target := Vector2(spot) * Defs.TILE
	# Clockwork: the Winder fetches the crate from a Clocktower first, so the trip that
	# counts is to the nearest Clocktower and on to the site (Defs.CRATE)
	var towers: Array = _halls().filter(func(h: Building) -> bool: return h.built and h.kind == "clocktower") if _clock() else []
	for u in game.workers(team):
		if u.order == "build" or _escort.has(u) or (scout != null and scout.is_scout(u)):
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
	if best:
		game.place_building(team, kind, spot, [best])


## Where a building goes: by the main hall, on its own ground (up on the main's plateau,
## inside its walls: any room there, even close to the hall or along the cliff edge, beats
## lower ground), then by another hall on that hall's ground. Only when no hall's plateau has
## room does it go down, and then to the foot of the nearest ramp (a short walk from the hall,
## never over a cliff, never in the ramp's way), else anywhere by a hall.
func _find_spot(kind: String) -> Vector2i:
	var halls: Array = _halls().filter(func(h: Building) -> bool: return h.built)
	if game.starts.size() > team:
		var home := Vector2(game.starts[team]) * Defs.TILE
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.center().distance_to(home) < b.center().distance_to(home))
	for h in halls:
		# (on the main's own plateau it looks a little farther: all of it is safe ground)
		var far := 26 if h == halls[0] else 20
		# (supply buildings tuck in behind the hall, away from the middle of the map: the room
		# close to the hall is for the production and tech buildings)
		var spot := game.find_spot(team, kind, h, 3, far, "behind" if kind == String(_f()["supply"]) else "near", true)
		if spot.x >= 0:
			return spot
	# the plateau is full: the foot of the nearest ramp, hall by hall
	for h in halls:
		var foot := game.ramp_foot(h)
		if foot != Vector2.INF:
			var spot := game.find_spot(team, kind, h, 3, 14, "near", false, foot)
			if spot.x < 0:
				spot = game.find_spot(team, kind, h, 3, 24, "near", false, foot)
			if spot.x >= 0:
				return spot
	for h in halls:
		var spot := game.find_spot(team, kind, h, 5, 18, "near")
		if spot.x >= 0:
			return spot
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ army

func _produce() -> void:
	# Saving up only pauses the army once there is a minimum army to hold the line.
	var minimum := mini(40, 6 + int(game.clock / 20.0))
	if _hall_reserve and _gold() < int(Defs.BUILDINGS[_f()["hall"]]["cost"]) + 30:
		return          # (Crown: the new Town Hall first, whatever the army)
	if (_saving or (_reserve > 0 and _gold() < _reserve + 60)) and _army_supply(game.army(team)) >= minimum:
		return
	var army := game.army(team)
	if _clock():
		var n_of := func(kind: String) -> int: return army.filter(func(u: Unit) -> bool: return u.kind == kind).size()
		var walkers: int = n_of.call("steam_walker")
		var carts: int = n_of.call("tesla_cart")
		var callers: int = n_of.call("stormcaller")
		var topters: int = n_of.call("ornithopter")
		var threshers: int = n_of.call("thresher")
		var shields: int = n_of.call("bulwark")
		var arcs: int = n_of.call("arc_thrower")
		var tins: int = n_of.call("windup_soldier")
		var big := army.size() - tins
		# the line: wind-ups early (cheap, three an order), then Threshers, Bulwarks and Arc
		# Throwers; wind-ups stay a share of it all game
		for w in _mine("assembly_works"):
			if w.built and w.queue.size() < (3 if _gold() > 600 else 2):
				var k := "windup_soldier"
				# against a swarm the saws (Threshers cut crowds that stand); against
				# musket lines Arc Throwers behind Bulwarks
				var swarm := _foe() >= 0 and game.faction_of(_foe()) == "brood"
				if game.clock > _lv([300.0, 200.0, 160.0]) or big >= 2:
					var r := randf()
					if tins < (3 + big / 2 if swarm else 3 + big / 3) or r < (0.12 if swarm else 0.06):
						k = "windup_soldier"
					elif arcs * (4 if swarm else 2) < big + 1 and game.can_train(w, "arc_thrower") == "":
						k = "arc_thrower"
					elif shields * (10 if swarm else 4) < big and game.can_train(w, "bulwark") == "":
						k = "bulwark"
					else:
						k = "thresher"
				var why := game.can_train(w, k)
				if why.begins_with("Not enough") or why.begins_with("Need more supply") or why.begins_with("Supply"):
					continue          # save up for it (don't spend it all on tin soldiers)
				if why != "":
					k = "thresher" if game.can_train(w, "thresher") == "" else "windup_soldier"
				if game.train(w, k) == "":
					match k:
						"windup_soldier":
							tins += 3
						"thresher":
							threshers += 1
							big += 1
						"bulwark":
							shields += 1
							big += 1
						"arc_thrower":
							arcs += 1
							big += 1
		# the big engines (they cost stored batteries too)
		for w in _mine("engine_hall"):
			if w.built and w.queue.size() < (2 if _gold() > 600 else 1):
				var k := ""
				if walkers * 5 < big + 2 and game.can_train(w, "steam_walker") == "":
					k = "steam_walker"
					walkers += 1
				elif carts * 6 < big and game.can_train(w, "tesla_cart") == "":
					k = "tesla_cart"
					carts += 1
				elif topters * 6 < big and game.can_train(w, "ornithopter") == "" and randf() < 0.4:
					k = "ornithopter"
					topters += 1
				elif difficulty >= 1 and callers * 8 < big and game.can_train(w, "stormcaller") == "":
					k = "stormcaller"
					callers += 1
				if k != "":
					game.train(w, k)
		return
	if _brood():
		var brutes := army.filter(func(u: Unit) -> bool: return u.kind == "brute").size()
		var wings := army.filter(func(u: Unit) -> bool: return u.kind == "skywing").size()
		var mothers := army.filter(func(u: Unit) -> bool: return u.kind == "spore_mother").size()
		var toads := army.filter(func(u: Unit) -> bool: return u.kind == "mist_toad").size()
		for h in _halls():
			toads += (h.queue as Array).count("mist_toad")     # (hatching ones too)
		var saving_mound := _mound_saving()
		for h in _halls():
			if not h.built:
				continue
			while h.eggs > 0:
				var k := "raptor" if randf() < 0.6 or game.can_train(h, "spitter") != "" else "spitter"
				# a Roost and too few Skywings: they come first whenever the essence is there
				# (spare raptors are offered up at the Brood Pen for it: see _offer)
				var want_wing: bool = game._has_built(team, "roost") and wings * (2 if strategy == "air" else 6) < army.size() + (6 if strategy == "air" else 0)
				if want_wing and game.can_train(h, "skywing") == "":
					k = "skywing"
					wings += 1
				elif army.size() >= 12 and toads < (1 if army.size() < 24 else 2) and game.can_train(h, "mist_toad") == "":
					# a Mist Toad or two in the middle game: fog for the swarm, a tongue for their guns
					k = "mist_toad"
					toads += 1
				elif game.can_train(h, "brute") == "" and brutes * 12 < army.size() + 6:
					k = "brute"
					brutes += 1
				elif game.can_train(h, "bloater") == "" and army.filter(func(u: Unit) -> bool: return u.kind == "bloater").size() * 10 < army.size() and randf() < 0.3:
					k = "bloater"
				elif game.can_train(h, "spore_mother") == "" and mothers * 14 < army.size():
					k = "spore_mother"
					mothers += 1
				if saving_mound and int(Defs.UNITS[k].get("cost2", 0)) > 0:
					k = "raptor"            # (the essence goes to the Broodmound first)
				if game.train(h, k) != "":
					break
		return
	var cannons := army.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	var mortars := army.filter(func(u: Unit) -> bool: return u.kind == "mortar").size()
	var muskets := army.filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind)).size()
	var short_powder := _res2() < 20.0
	# a horse waits at a Foundry for a gun we want: the Barracks saves the gold for it
	var gun_wait := false
	if not short_powder and army.size() >= 6 and _gold() < int(Defs.UNITS["cannon"]["cost"]):
		for f in _mine("foundry"):
			if f.built and f.queue.is_empty() and game.horses_at(f) > 0 and (cannons * 4 < army.size() + 2 or mortars < mini(2, int(muskets / 6.0))):
				gun_wait = true
	for b in _mine("barracks"):
		if gun_wait:
			break
		# (a little room left for the research going on here)
		if b.built and b.queue.size() < (3 if _gold() > 600 else 2):
			# the line is Musketeers (they stab when the enemy closes); horsemen to raid and
			# to run down guns
			# (light or armoured: _soldier_key)
			var k := _soldier_key(b, "musketeer")
			var horse := army.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size()
			var hk := _soldier_key(b, "cuirassier")
			var rush := opening == "breeder" and game.clock < 600.0
			if (horse < 3 or horse * 6 < army.size() or rush) and randf() < (0.85 if rush else (0.6 if short_powder else 0.3)) and hk != "":
				k = hk
			elif k == "":
				k = hk
			if k != "":
				game.train(b, k)
	for f in _mine("foundry"):
		if not f.built or short_powder:
			continue
		# a Mortar or two behind the musketeers (one per 6 of them, 2 at most)
		if f.queue.size() < 2 and mortars < mini(2, int(muskets / 6.0)) and not f.queue.has("mortar") and game.can_train(f, "mortar") == "":
			game.train(f, "mortar")
			mortars += 1
		elif f.queue.size() < (2 if _gold() > 600 else 1) and cannons * 4 < army.size() + 2:
			game.train(f, "cannon")
	# one Powder Wagon once there's a real firing line (6+ musketeers) to keep in powder
	if _wagon() == null and army.filter(func(u: Unit) -> bool: return u.kind == "musketeer").size() >= 6:
		var queued := false
		for f in _mine("foundry"):
			queued = queued or f.queue.has("powder_wagon")
		if not queued:
			for f in _mine("foundry"):
				if f.built and f.queue.size() < 2 and game.can_train(f, "powder_wagon") == "":
					game.train(f, "powder_wagon")
					break
	var balloons := army.filter(func(u: Unit) -> bool: return u.kind == "balloon").size()
	for f in _mine("foundry"):
		if f.built and f.queue.is_empty() and balloons * 8 < army.size() and _gold() > 350 and game.can_train(f, "balloon") == "":
			game.train(f, "balloon")
			balloons += 1
	for c in _mine("church"):
		if c.built and c.queue.is_empty() and game.can_train(c, "missionary") == "":
			game.train(c, "missionary")


## Crown: armoured recruits (Guardsmen, Cuirassiers) by default once Armour is researched
## and the money is there; light ones when the enemy fields a lot that is strong against
## armour (_anti_armour).
func _want_armour() -> bool:
	return game.has_tech(team, "armour") and _anti_armour() < 0.35


var _aa_t := -100.0
var _aa := 0.0


## The share (by supply) of the enemy's army that does extra harm to armoured men: guns
## whose round shot hits armour harder (Defs.ROUND_SHOT vs_armored), units whose bonus
## names our soldiers, armour-stripping acid. Counted once every 10 s.
func _anti_armour() -> float:
	if game.clock - _aa_t < 10.0:
		return _aa
	_aa_t = game.clock
	var all := 0.0
	var anti := 0.0
	for u in game.units:
		if u.dead or u.team < 0 or not game.hostile(u.team, team) or u.is_worker() or not u.has_attack():
			continue
		var w := float(u.d["supply"])
		all += w
		var bonus: Dictionary = u.d.get("bonus", {})
		if u.kind == "cannon" or u.d.has("acid") or bonus.has("musketeer") or bonus.has("cuirassier"):
			anti += w
	_aa = anti / all if all > 0.0 else 0.0
	return _aa


## The train button for a soldier of this kind: armoured when we want armour and can pay
## for it, else light; "" if neither can be trained.
func _soldier_key(b: Building, kind: String) -> String:
	if _want_armour():
		var ak := Defs.train_key(kind, true)
		if game.can_train(b, ak) == "" and _gold() >= game.unit_price(team, ak)[0] + _lv([60, 30, 0]):
			return ak
	var lk := Defs.train_key(kind, false)
	return lk if game.can_train(b, lk) == "" else ""


## Units busy with something of their own the army orders must leave alone: a balloon
## drop, an Ornithopter fetching or delivering a battery, a Bloater out of gas.
func _on_errand(u: Unit) -> bool:
	if u.order in ["courier", "overload", "board", "unload", "heal", "revive", "refit", "restock"]:
		return true
	if u.kind == "bloater" and u.deflate != "":
		return true
	if not _drop.is_empty() and (u == _drop.get("b") or (_drop.get("men", []) as Array).has(u)):
		return true
	return false


func _army_supply(list: Array) -> int:
	var n := 0
	for u in list:
		n += int(u.d["supply"])
	return n


## Crown: our Powder Wagon (there's only ever one).
func _wagon() -> Unit:
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "powder_wagon":
			return u
	return null


var _wagon_refill := false


## The Powder Wagon follows a little behind the army (never in front), has SUPPLY on while
## it's out in the field so labourers bring it kegs, and goes back to a Barracks, Mill or Town Hall to fill up when it's
## nearly empty. Musketeers out of powder with nothing to fight fall back to it.
func _tend_wagon() -> void:
	var w := _wagon()
	if w == null:
		return
	# keg runs only while it's out in the field (at home it fills from the buildings itself)
	var away := w._powder_building() == null
	if w.supplying != away:
		w.set_supply(away)
	var army: Array = game.army(team).filter(func(u: Unit) -> bool: return u != w and not _raiders.has(u) and not u.is_air())
	if w.powder < w.max_powder() * 0.25:
		_wagon_refill = true
	elif w.powder > w.max_powder() * 0.9:
		_wagon_refill = false
	if _wagon_refill:
		if w._powder_building() == null and w.order != "move":
			var best: Building = null
			var bd := INF
			for b in game.buildings:
				if b.team == team and b.built and not b.dead and (Defs.POWDER["from"] as Array).has(b.kind):
					var dd: float = b.edge_distance(w.position)
					if dd < bd:
						bd = dd
						best = b
			if best:
				w.cmd_move(game.approach_point(best, w.position))
		return
	if army.is_empty():
		return
	var c := Vector2.ZERO
	for u in army:
		c += u.position
	c /= army.size()
	var halls := _halls()
	var home: Vector2 = halls[0].center() if not halls.is_empty() else game.center_of_team(team)
	var spot := c + (home - c).normalized() * 120.0 if home.distance_to(c) > 120.0 else home
	if w.position.distance_to(spot) > 100.0 and (w.order != "move" or w.order_point.distance_to(spot) > 140.0):
		w.cmd_move(spot)
	if w.powder >= 6.0:
		for u in army:
			if u.kind == "musketeer" and u.powder < 1.0 and u.target == null and u.order != "move":
				var dd: float = u.position.distance_to(w.position)
				if dd > 70.0 and dd < 700.0:
					u.cmd_move(w.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))


func _army() -> void:
	var army: Array = game.army(team).filter(func(u: Unit) -> bool: return not _raiders.has(u) and not _on_errand(u) and u.kind != "powder_wagon" and u.order != "sacrifice")
	if _crown():
		army = _guard_new_hall(army)
	# Bloaters out of gas float home to fill up again (faster on the swamp)
	for u in game.army(team):
		if u.kind == "bloater" and u.deflate == "flat" and u.order != "move":
			var hall: Array = _halls()
			if not hall.is_empty() and u.position.distance_to(hall[0].center()) > 220.0:
				u.cmd_move(hall[0].center() + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	# Ornithopters fetch batteries for the constructs that run down
	if _clock():
		for u in army:
			if u.kind == "ornithopter" and not u.courier:
				u.courier = true
	# Defend: enemies near our buildings get everyone's attention.
	var threat := _threat()
	if threat != Vector2.INF:
		# attacked from several sides at once: each soldier goes to the nearest raid
		var spots := _threats()
		# (a raid of flyers only is answered by the men who can hit flyers: grubs, pikes and the
		# rest would just run after something out of their reach)
		var air_spot := {}
		for sp in spots + [threat]:
			var near: Array = game.units_near(sp, 300.0).filter(func(o: Unit) -> bool: return game.hostile(o.team, team) and not o.dead and not o.off_field)
			air_spot[sp] = not near.is_empty() and near.all(func(o: Unit) -> bool: return o.is_air())
		for u in army:
			if u.order != "attack" and (u.target == null or u.order == "idle"):
				var best: Vector2 = threat
				for sp in spots:
					if u.position.distance_to(sp) < u.position.distance_to(best):
						best = sp
				if air_spot.get(best, false) and not _hits_air(u):
					continue
				u.cmd_move(best + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
		# Workers pitch in when the base is being overrun and there's no army.
		if army.size() < 3:
			# (a lone worker scout is no invasion: two hands deal with it, the rest keep working)
			var foes: Array = game.units_near(threat, 260.0).filter(func(o: Unit) -> bool: return game.hostile(o.team, team) and not o.dead and not o.off_field and game.is_visible_to(team, o.position))
			var scouts_only: bool = foes.all(func(o: Unit) -> bool: return o.is_worker() or not o.has_attack())
			var cap: int = 2 if scouts_only else 999
			if not foes.is_empty() and foes.all(func(o: Unit) -> bool: return o.is_air()):
				cap = 0                  # flyers only: labourers can't hit them, they keep working
			# the hands already sent count against the cap (the intruder moves, so "the two nearest
			# gatherers" changes every tick and used to draft the whole mine, one pair at a time)
			var guards: Array = game.workers(team).filter(func(u: Unit) -> bool: return bool(u.get_meta("guard", false)) and not u.dead and u.order in ["move", "attack", "amove"])
			var hands: Array = game.workers(team).filter(func(u: Unit) -> bool: return u.position.distance_to(threat) < 260.0 and u.order == "gather" and not guards.has(u))
			hands.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(threat) < b.position.distance_to(threat))
			for g in guards:
				if guards.find(g) >= cap:
					g.set_meta("guard", false)
					g.cmd_gather(g.home_mine) if g.home_mine != null and is_instance_valid(g.home_mine) else g.cmd_stop()
				elif g.order == "move":
					g.cmd_move(threat, true)
			var free := cap - mini(guards.size(), cap)
			for i in mini(free, hands.size()):
				hands[i].set_meta("guard", true)
				hands[i].cmd_move(threat, true)
		return
	# Clockwork: constructs running low on charge go back into a field first
	if _clock():
		var fields: Array = game.buildings.filter(func(b: Building) -> bool: return b.team == team and not b.dead and b.built and b.d.has("field"))
		for u in army:
			if u.wind < 0.2 and not u.runs_on_spring() and not u._in_field and not u.powered_down() and u.order != "move" and not fields.is_empty():
				var best: Building = fields[0]
				for f in fields:
					if f.center().distance_to(u.position) < best.center().distance_to(u.position):
						best = f
				u.cmd_move(best.center() + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		army = army.filter(func(u: Unit) -> bool: return u.wind >= 0.2 or u._in_field or u.runs_on_spring())   # (wind-ups fight on; the escort cranks them)
	var sup := _army_supply(army)
	var swarm_min := 10 if strategy in ["rush", "air"] or scout.verdict == "greedy" else 30
	if _brood() and _attack_at < swarm_min:
		_attack_at = swarm_min     # a swarm waits until it's a swarm
	# timing attack: nothing goes out before the timing; then everything does, wave after wave
	if strategy == "timing" and game.clock >= float(_s("timing")) * (1.0 if difficulty >= 2 else 1.25) and _attack_at >= 999:
		_attack_at = scout.timing_wave()    # (6 unless the scout sized the attack from what it saw)
	if peaceful:
		_attack_at = 99999
	# a failed rush: building up again; nothing goes out until the regroup is over (unless
	# the army is already huge)
	var regrouping := game.clock < _regroup_until and sup < 60
	if _brood():
		_swarm_army(army, sup, regrouping)
		return
	# (riders still on foot, their horses on the way, don't count yet: they follow mounted)
	var ready := army.filter(func(u: Unit) -> bool: return not _horse_coming(u))
	if not _attacking and _army_supply(ready) >= _attack_at and not regrouping and _timing_ok(ready):
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + int(_s("step")), 70)
		_wave_start(ready)
		if game.mlog and not _first_wave:
			_first_wave = true
			game.mlog.add("%s's first attack goes out (%d supply, %d Horsemen)" % [game.mlog.who(team), _army_supply(ready), ready.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size()])
		var prey0 := _prey_spot(game.center_of_team(team)) if _cavalry_wave(ready) else Vector2.INF
		for u in ready:
			if prey0 != Vector2.INF and u.kind == "cuirassier":
				_hunt(u, prey0)
				continue
			u.cmd_move(_wave_target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	elif _attacking:
		if sup < 6:
			_attacking = false
			_release_escort()
			_wave_end()
			return
		_wave_target = _enemy_base()
		# a wall in the way: the army weighs it up as one (break in, or pull back)
		_siege_tick(army)
		if not _attacking:
			return
		var wagon := _wagon() if _crown() else null
		var cav := _cavalry_wave(ready)
		var prey := Vector2.INF
		for u in ready:
			if cav and u.kind == "cuirassier" and u.siege_t <= 0.0 and u.wall_flee_t <= 0.0:
				if prey == Vector2.INF:
					prey = _prey_spot(u.position)
				_hunt(u, prey)
				continue
			if u.order == "idle" and u.wall_flee_t <= 0.0 and u.siege_t <= 0.0 and not (u.deploys() and u.tesla_mode == "deployed" and u.target):
				# a dry musketeer topping up at the wagon waits there until it can shoot again
				if wagon and u.kind == "musketeer" and u.powder < float(Defs.POWDER["rearm"]) + 2.0 \
						and wagon.powder >= 1.0 and u.position.distance_to(wagon.position) < 120.0 and u.target == null:
					continue
				u.cmd_move(_wave_target + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
		if _clock():
			_follow_with_escort(army)
	else:
		# Gather at a rally spot in front of the base.
		var hall: Array = _halls()
		if hall.is_empty():
			return
		var front: Vector2 = _rally_front(hall[0])
		for u in ready:
			if u.order == "idle" and u.position.distance_to(front) > 160.0:
				u.cmd_move(_home_spot(front), true)
			elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
				u.cmd_deploy()


## A timing attack the scout sized waits while the army is not worth enough against what
## the enemy showed (never into a clearly stronger defence).
func _timing_ok(list: Array) -> bool:
	if strategy != "timing" or scout.verdict != "greedy":
		return true
	var v := 0.0
	for u in list:
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	return scout.timing_ok(v)


## Crown: a wave that's mostly horsemen (the Horseman rush) raids the economy: its riders
## hunt workers (_hunt) rather than ride at the enemy's hall.
func _cavalry_wave(list: Array) -> bool:
	if not _crown():
		return false
	var cav := 0
	var all := 0
	for u in list:
		all += int(u.d["supply"])
		if u.kind == "cuirassier":
			cav += int(u.d["supply"])
	return cav > 0 and cav * 2 >= all


## A rider on foot whose horse is on its way: he's going to get on (or waits at the breeder
## for the one kept for him). The army leaves him be until he's mounted.
func _horse_coming(u: Unit) -> bool:
	return Defs.RIDERS.values().has(u.kind) and (u.order == "mount" or u.horse_rid != 0) and (u.kind == "dismounted" or u.horse_rid != 0 or u.auto_mount)


## Where the army waits at home: a little in front of the hall toward the enemy, but on the
## hall's own ground (same height, same walkable area): the straight line to the enemy can
## cross a cliff, and the men then stood down the hill outside the main.
func _rally_front(hall: Building) -> Vector2:
	var home := hall.center()
	var hc: Vector2i = game.cell_of(home + Vector2(0, hall.rect().size.y * 0.5 + 24.0))
	var h: int = game.height[game.idx(hc)] if game.in_map(hc) else 0
	var reg: int = game.region_of(hc)
	var want: Vector2 = home.lerp(_enemy_base(), 0.15)
	for k in 11:
		var p: Vector2 = want.lerp(home, k / 10.0)
		var c: Vector2i = game.cell_of(p)
		if game.in_map(c) and game.open_cell(c) and game.height[game.idx(c)] == h and (reg < 0 or game.region_of(c) == reg):
			return p
	return game.cell_center(hc)


## A spot near the rally point, scattered a little, but never over the edge of the plateau.
func _home_spot(front: Vector2) -> Vector2:
	var spot: Vector2 = front + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var sc: Vector2i = game.cell_of(spot)
	var fc: Vector2i = game.cell_of(front)
	if not game.in_map(sc) or not game.in_map(fc) or game.height[game.idx(sc)] != game.height[game.idx(fc)] \
			or game.region_of(sc) != game.region_of(fc):
		return front
	return spot


## Brood: a swarm never walks into the guns in one lump. Each wave splits into groups
## that circle round to different sides of the target, wait until everyone is in place,
## and then all go in at once. Hatchlings that come out mid-attack wait at home for the
## next wave instead of trickling in one by one.
func _swarm_army(army: Array, sup: int, regrouping := false) -> void:
	var hall: Array = _halls()
	var front: Vector2 = _rally_front(hall[0]) if not hall.is_empty() else game.center_of_team(team)
	# don't throw a small swarm at a much bigger army: wait until it's worth as much
	var mine := 0.0
	for u in army:
		mine += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	var theirs := 0.0
	var foe := _foe()
	if foe >= 0:
		for u in game.army(foe):
			theirs += float(u.d["cost"])
	var big_enough := mine >= theirs * 0.8 or sup >= 70 or strategy in ["rush", "air"] or (strategy == "timing" and scout.timing_ok(mine))
	if _swarm_phase == "" and sup >= _attack_at and big_enough and not regrouping:
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + int(_s("step")), 70)
		_wave_start(army)
		_plan_swarm(army)
		_swarm_phase = "flank"
		_swarm_t = 0.0
	elif _swarm_phase != "":
		_swarm_t += 1.0
		var alive := 0
		var wave: Array = []
		for g in _swarm:
			g[0] = (g[0] as Array).filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead and not _on_errand(u))
			alive += _army_supply(g[0])
			wave.append_array(g[0])
		var sieging := false
		if alive >= 6:
			# a wall in the way: the swarm weighs it up as one (break in, or pull back), and
			# doesn't circle round to flanking spots it can't reach
			sieging = _siege_tick(wave)
			if sieging and _swarm_phase == "flank":
				_swarm_phase = "strike"
		if _swarm_phase == "":
			pass                     # (it just pulled back from a wall)
		elif alive < 6:
			_swarm_phase = ""
			_swarm.clear()
			_attacking = false
			_wave_end()
		elif _swarm_phase == "flank":
			# everyone in place (or it's taking too long, or we were spotted and hit): go
			var ready := true
			var hit := false
			for g in _swarm:
				var there := 0
				for u in g[0]:
					if u.position.distance_to(g[1]) < 200.0:
						there += 1
					if u.target != null:
						hit = true
				if there < (g[0] as Array).size() * 0.6:
					ready = false
			if ready or hit or _swarm_t > 40.0:
				_swarm_phase = "strike"
				_wave_target = _enemy_base()
				# caught a fight on the way: everyone goes there together, not on to the base
				var fs := _fight_spot()
				if fs != Vector2.INF:
					_wave_target = fs
				# a few grubs follow the swarm to harvest the fallen
				var spare := game.workers(team).filter(func(u: Unit) -> bool: return u.kind == "grub" and u.order != "build" and u.cocoon == 0)
				var want_h := 2 if spare.size() > 10 else (1 if spare.size() > 6 else 0)
				var have := game.workers(team).filter(func(u: Unit) -> bool: return u.order == "harvest").size()
				for g2 in spare.slice(0, maxi(0, want_h - have)):
					g2.cmd_harvest()
					g2.harvest_home = (_swarm[0][1] as Vector2) if not _swarm.is_empty() else _wave_target
				var sp := _spread()
				for g in _swarm:
					for u in g[0]:
						u.cmd_move(_wave_target + Vector2(randf_range(-sp, sp), randf_range(-sp, sp)), true)
		else:
			# strike: wherever part of the wave is fighting, the rest joins that fight
			var fs := _fight_spot()
			_wave_target = fs if fs != Vector2.INF else _enemy_base()
			var sp := _spread()
			for g in _swarm:
				for u in g[0]:
					if u.deploys() and u.tesla_mode == "deployed" and u.target:
						continue
					if u.siege_t > 0.0:
						continue             # breaking in at a wall: the siege gives its orders
					var join: bool = fs != Vector2.INF and u.target == null and u.position.distance_to(fs) > 140.0
					if (u.order == "idle" or join) and u.wall_flee_t <= 0.0:
						u.cmd_move(_wave_target + Vector2(randf_range(-sp, sp), randf_range(-sp, sp)), true)
	# everyone not in the wave gathers at home
	var in_wave := {}
	for g in _swarm:
		for u in g[0]:
			in_wave[u] = true
	for u in army:
		if in_wave.has(u):
			continue
		if u.order == "idle" and u.position.distance_to(front) > 160.0:
			u.cmd_move(_home_spot(front), true)
		elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
			u.cmd_deploy()


## Split the army into groups (two or three, mixed: every group gets its share of
## raptors, spitters and brutes) and give each a spot on a different side of the target.
func _plan_swarm(army: Array) -> void:
	_swarm.clear()
	var target := _wave_target
	var home := game.center_of_team(team)
	var n := 1
	_tight = _splash_share() < 0.25
	if _tight:
		n = 1               # single-target shooters: one packed swarm hits all at once
	elif army.size() >= 24:
		n = 3
	elif army.size() >= 10:
		n = 2
	var dir := (home - target).normalized()
	var angles: Array = [0.0] if n == 1 else ([-1.1, 1.1] if n == 2 else [0.0, -1.3, 1.3])
	var dist := 520.0
	for a in angles:
		var p: Vector2 = target + dir.rotated(a) * dist
		var c: Vector2i = game.cell_of(p)
		c = Vector2i(clampi(c.x, 1, game.W - 2), clampi(c.y, 1, game.H - 2))
		c = game.nearest_free(c, 12)
		if c.x < 0:
			c = game.cell_of(target.lerp(home, 0.4))
		_swarm.append([[], Vector2(c) * Defs.TILE + Vector2(16, 16)])
	# deal the units out kind by kind so each group is a mix; slow casters go up the middle
	var by_kind := {}
	for u in army:
		if not by_kind.has(u.kind):
			by_kind[u.kind] = []
		by_kind[u.kind].append(u)
	var i := 0
	for k in by_kind:
		for u in by_kind[k]:
			var gi := 0 if k == "spore_mother" else i % n
			_swarm[gi][0].append(u)
			i += 1
	var sp := _spread()
	for g in _swarm:
		for u in g[0]:
			u.cmd_move(g[1] + Vector2(randf_range(-sp, sp), randf_range(-sp, sp)), false)


## How much of the enemy army (by cost) deals splash damage: against splash the swarm
## spreads out and flanks; against single-target shooters it packs tight and goes in together.
const SPLASH_KINDS := ["cannon", "mortar", "steam_walker", "spore_mother", "bloater", "stormcaller", "thresher", "tesla_cart"]

func _splash_share() -> float:
	var foe := _foe()
	if foe < 0:
		return 0.0
	var all := 0.0
	var splash := 0.0
	for u in game.army(foe):
		var c := float(u.d["cost"])
		all += c
		if SPLASH_KINDS.has(u.kind):
			splash += c
	return splash / all if all > 0.0 else 0.0


func _spread() -> float:
	return 22.0 if _tight else 60.0


## Where the wave is fighting right now (the middle of its engaged units), or INF.
func _fight_spot() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for g in _swarm:
		for u in g[0]:
			if is_instance_valid(u) and not u.dead and u.target != null and is_instance_valid(u.target):
				sum += u.position
				n += 1
	return sum / n if n > 0 else Vector2.INF


# ------------------------------------------------------------------ sieges (every faction)

## When the way to the wave's target is shut by an enemy wall or gate, the army decides as
## one whether to break in, instead of every unit making up its own mind at the wall:
##  * how fast it can knock down one piece (the melee units that fit at the wall face plus
##    every ranged unit that can shoot it, less any repair), against
##  * how fast the defenders in reach of that spot (muskets, canister, round shot...) shoot
##    the men doing it.
## A short simulation races one against the other, for each piece the army can reach that
## opens the way. If one piece falls in time, with enough of the army left to win the fight
## behind it, everything goes for that one piece: melee at its face (only as many as fit,
## the rest waiting out of reach to step up), ranged units standing back off the melee lane
## and shooting the same piece. If none does, the wave pulls back out of range and the
## computer gathers a bigger army (and goes for another of the enemy's halls meanwhile, if
## there's one). Weighed up again every SIEGE_EVAL seconds.
const SIEGE_EVAL := 3.0
var _siege := {}                # {"piece", "out" (outward dir), "stage", "cap" (melee at the face), "spots" {unit: point}, "splash", "flood"}
var _siege_next := 0.0          # (match clock) when the siege is weighed up again
var _siege_said := ""           # the last siege decision written to the match log (not said twice running)
var _walled_halls := {}         # enemy hall -> clock until which waves leave it be (walled too strongly)
var _dive_wait := {}            # after a breach: light melee -> [clock, gun]: they follow the tough ones in once
                                # the gun has fired (its canister spent on the Brutes, not on them), or at clock
var _hold_back := {}            # after a breach: unit -> clock when it goes on after the base (the melee walk
                                # through the gap first, the ranged hold a moment so they don't block it)


func _siege_clear() -> void:
	_siege.clear()


## Is this unit out with the attacking wave? (Unit._wall_watch leaves those to the siege.)
func in_wave(u: Unit) -> bool:
	if not _attacking:
		return false
	if not _brood():
		return not _guards.has(u) and not _raiders.has(u)
	for g in _swarm:
		if (g[0] as Array).has(u):
			return true
	return false


func _melee(u: Unit) -> bool:
	return float(u.d["range"]) <= 40.0


## The time one blow takes: aim, strike and reload (as Unit._attack_cycle runs it).
func _cycle(u: Unit) -> float:
	var cd := float(u.d["cooldown"])
	if u.kind == "musketeer":
		cd = u.musket_cooldown()
	return float(u.d.get("aim", 0.25)) + 0.35 + maxf(cd, 0.1)


## The cells reachable on foot from `cells` (4-way, as the pathfinder walks), with gates
## open only to team `t`'s side. 1 = reachable.
func _flood_from(cells: Array, t: int) -> PackedByteArray:
	# (cell indices and the grids read directly: a whole-map flood of Vector2i and calls
	# took the computer's think 40-50 ms)
	var w: int = game.W
	var h: int = game.H
	var solid: PackedByteArray = game.solid
	var seen := PackedByteArray()
	seen.resize(w * h)
	# the gates open to t's side (the only solid cells walkable here)
	var open_gates := {}
	if t >= 0:
		for gi in game.gate_team:
			if solid[int(gi)] == 3 and game.allied(int(game.gate_team[gi]), t):
				open_gates[int(gi)] = true
	var q := PackedInt32Array()
	for c in cells:
		if game.in_map(c) and seen[game.idx(c)] == 0 and _walkable(c, t):
			seen[game.idx(c)] = 1
			q.append(game.idx(c))
	var qi := 0
	while qi < q.size():
		var i: int = q[qi]
		qi += 1
		var x := i % w
		var n: int
		var v: int
		if x + 1 < w:
			n = i + 1
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
		if x > 0:
			n = i - 1
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
		if i + w < w * h:
			n = i + w
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
		if i >= w:
			n = i - w
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
	return seen


func _walkable(c: Vector2i, t: int) -> bool:
	var v: int = game.solid[game.idx(c)]
	if v == 0 or v == 5:
		return true
	return v == 3 and t >= 0 and game.allied(int(game.gate_team.get(game.idx(c), -1)), t)


func _is_piece(b) -> bool:
	return b is Building and (b.kind == "wall" or b.kind == "gate")


## Called every think while a wave is out. True while a siege runs the wave (the caller then
## leaves units with siege_t > 0 alone) or the wave has just pulled back from one.
func _siege_tick(wave: Array) -> bool:
	# after a breach: the melee walk through the gap, the ranged let them by first; then
	# everyone goes on after the base
	for u in _dive_wait.keys():
		if not is_instance_valid(u) or u.dead:
			_dive_wait.erase(u)
		elif game.clock >= float(_dive_wait[u][0]) or not is_instance_valid(_dive_wait[u][1]) or _dive_wait[u][1].dead \
				or _dive_wait[u][1].cooldown > 1.5:
			# (its gun has just fired, on the tough ones: in now, before it's loaded again)
			var gun = _dive_wait[u][1]
			_dive_wait.erase(u)
			if is_instance_valid(gun) and not gun.dead:
				u.cmd_attack(gun)
			else:
				u.cmd_move(_enemy_base() + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
	for u in _hold_back.keys():
		if not is_instance_valid(u) or u.dead:
			_hold_back.erase(u)
		elif game.clock >= float(_hold_back[u]) or (u.order == "idle" and u.target == null):
			_hold_back.erase(u)
			u.siege_t = 0.0
			if u.order == "hold" or u.order == "move" or u.order == "idle":
				u.cmd_move(_enemy_base() + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
	var ground: Array = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.is_air() and not u.off_field)
	if ground.is_empty():
		_siege_clear()
		return false
	var piece = _siege.get("piece")
	if piece != null and (not is_instance_valid(piece) or piece.dead):
		# through: the melee go in through the gap after the defenders behind it; the ranged
		# step up to the wall face beside the gap (not into it, in front of the melee) and shoot
		# over the wall; a few seconds on, all after the base
		var at: Vector2 = _siege["at"]
		var out: Vector2 = _siege["out"]
		var flood: PackedByteArray = _siege["flood"]
		var inner: PackedByteArray = _siege["inner"]
		var inside: Vector2 = _flood_point(inner, at - out * 90.0, at)
		_siege_clear()
		_siege_said = ""
		_siege_next = game.clock + 5.0          # (another wall behind it? weigh that up once through)
		var target := _enemy_base()
		# the guns behind the wall (canister, shells) are what kill a crowd in the gap: the
		# melee dive on them first, split between them, then go on after the rest
		var guns: Array = []
		for o in game.units_near(at, 340.0):
			if not o.dead and game.hostile(o.team, team) and not o.is_air() and SPLASH_KINDS.has(o.kind) \
					and inner[game.idx(game.cell_of(o.position))] == 1:
				guns.append(o)
		guns.sort_custom(func(a, b) -> bool: return a.position.distance_to(at) < b.position.distance_to(at))
		var gi := 0
		# tough melee (armoured) go first when there are any: the light ones wait out of reach
		# until the gun they're after has fired (at the tough ones), then rush it while it loads
		var tanks := not guns.is_empty() and wave.any(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.is_air() \
				and _melee(u) and u.has_attack() and not u.has_tag("light"))
		for u in wave:
			if is_instance_valid(u) and not u.dead:
				u.wall_flee_t = 0.0
				if u.is_air():
					u.siege_t = 0.0
					u.cmd_move(target + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
				elif u.has_attack() and not _melee(u) and not u.deploys():
					# up to the wall face beside the gap (not in it): from there they shoot over
					# the wall at the defenders behind it
					var side: Vector2 = out.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
					var face: Vector2 = _flood_point(flood, at + out * 30.0 + side * randf_range(56.0, 90.0), u.position)
					u.cmd_move(face, true)
					u.siege_t = 7.0
					_hold_back[u] = game.clock + 6.0
				else:
					if not guns.is_empty() and u.has_attack() and u.can_hit(guns[gi % guns.size()]):
						if tanks and u.has_tag("light"):
							u.cmd_hold()
							_dive_wait[u] = [game.clock + 5.0, guns[gi % guns.size()]]
						else:
							u.cmd_attack(guns[gi % guns.size()])
						gi += 1
					else:
						u.cmd_move(inside + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
					u.siege_t = 8.0
					_hold_back[u] = game.clock + 7.0
		return true
	if game.clock >= _siege_next:
		_siege_next = game.clock + SIEGE_EVAL
		if not _siege_plan(ground, wave):
			return true            # pulled back: the wave is over
	if _siege.is_empty():
		return false
	_siege_orders(ground)
	return true


## Weigh up the wall in the way. Returns false when the wave pulls back (it's over).
func _siege_plan(ground: Array, wave: Array) -> bool:
	var objective := _enemy_base()
	var starts: Array = []
	var centre := Vector2.ZERO
	for u in ground:
		starts.append(game.cell_of(u.position))
		centre += u.position
	centre /= ground.size()
	var ours := _flood_from(starts, team)
	# can we walk up to the target? (any open cell next to it)
	var oc: Vector2i = game.cell_of(objective)
	var goal_cells: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := oc + Vector2i(dx, dy)
			if game.in_map(c) and _walkable(c, -1):
				goal_cells.append(c)
				if ours[game.idx(c)] == 1:
					_siege_release(ground)
					return true          # an open way in: no siege
	if goal_cells.is_empty():
		_siege_release(ground)
		return true
	var inner := _flood_from(goal_cells, _foe())
	# the enemy walls and gates we can stand against that open the way
	var pieces: Array = []
	var touching: Array = []
	for b in game.buildings:
		if b.dead or not b.built or not _is_piece(b) or not game.hostile(b.team, team):
			continue
		var out_side := false
		var in_side: bool = inner[game.idx(b.cell)] == 1
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = b.cell + dv
			if not game.in_map(n):
				continue
			if ours[game.idx(n)] == 1:
				out_side = true
			if inner[game.idx(n)] == 1:
				in_side = true
		if out_side:
			touching.append(b)
			if in_side:
				pieces.append(b)
	if pieces.is_empty():
		# several layers: the piece we can reach nearest to the target
		touching.sort_custom(func(a, b) -> bool: return a.center().distance_to(objective) < b.center().distance_to(objective))
		pieces = touching.slice(0, 1)
	if pieces.is_empty():
		_siege_release(ground)
		return true                  # shut out by something it can't break: carry on as before
	pieces.sort_custom(func(a, b) -> bool: return a.center().distance_to(centre) < b.center().distance_to(centre))
	var best: Dictionary = {}
	var cur = _siege.get("piece")
	if cur != null and (not is_instance_valid(cur) or cur.dead):
		cur = null
	for b in pieces.slice(0, 6):
		var r := _siege_sim(b, ground, ours, centre)
		# once in, it keeps going unless it's clearly lost (no dithering at the wall)
		var ok: bool = r["win"] or (b == cur and r["breach"] and r["left"] >= 0.15)
		if not ok:
			if best.is_empty() or (not best["ok"] and r["t"] < best["t"]):
				best = r.merged({"ok": false, "piece": b})
			continue
		var score: float = r["t"] + b.center().distance_to(centre) / 90.0 - (4.0 if b == cur else 0.0)
		if best.is_empty() or not best["ok"] or score < best["score"]:
			best = r.merged({"ok": true, "piece": b, "score": score})
	var who: String = game.mlog.who(team) if game.mlog else "AI"
	if best["ok"]:
		var piece: Building = best["piece"]
		if piece != cur:
			_siege = {"piece": piece, "out": best["out"], "stage": best["stage"], "cap": best["cap"], "spots": {}, "splash": best["splash"], "flood": ours,
				"since": game.clock, "formed": false, "inner": inner, "at": piece.center(), "mreach": best["mreach"]}
		else:
			_siege["cap"] = best["cap"]
			_siege["mreach"] = best["mreach"]
			_siege["stage"] = best["stage"]
			_siege["flood"] = ours
			_siege["inner"] = inner
		_say("breach", "%s breaks in at a %s: down in ~%d s (%d dps on it) against %d dps of fire" % [who, String(piece.d["name"]).to_lower(), int(best["t"]), int(best["dps"]), int(best["inc"])])
		return true
	# lost: pull back out of reach, gather more, and leave this hall be for a while
	var b0: Building = best["piece"]
	var back: Vector2 = _flood_point(ours, b0.center() + best["out"] * (best["reach"] + 160.0), centre)
	_say("back", "%s pulls back from the %s: %s under %d dps of fire (%d dps on it)" % [who, String(b0.d["name"]).to_lower(),
		("down in ~%d s, too dear" % int(best["t"])) if best["breach"] else "it can't get through", int(best["inc"]), int(best["dps"])])
	for u in wave:
		if is_instance_valid(u) and not u.dead:
			u.siege_t = 0.0
			u.cmd_move(back + Vector2(randf_range(-70, 70), randf_range(-70, 70)))
			u.wall_flee_t = 10.0
	var hall := _hall_at(objective)
	if hall:
		_walled_halls[hall] = game.clock + 120.0
	_siege_clear()
	_attacking = false
	_swarm_phase = ""
	_swarm.clear()
	_release_escort()
	_wave_end()
	# it comes back only with a bigger army (not straight back at the same wall)
	_attack_at = maxi(_attack_at, mini(int(ceil(_wave_sup * 1.4)), _wave_sup + 40))
	return false


func _say(kind: String, msg: String) -> void:
	if _siege_said == kind:
		return
	_siege_said = kind
	if game.mlog:
		game.mlog.add(msg)


func _hall_at(p: Vector2) -> Building:
	for b in game.buildings:
		if not b.dead and b.kind == game.faction_hall(b.team) and b.center().distance_to(p) < 8.0:
			return b
	return null


## The siege is off (an open way in): the units go back to the wave's ordinary orders.
func _siege_release(ground: Array) -> void:
	if _siege.is_empty():
		return
	_siege_clear()
	_siege_said = ""
	for u in ground:
		if u.siege_t > 0.0:
			u.siege_t = 0.0
			u.cmd_move(_enemy_base() + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)


## The reachable cell nearest to p (searched outward from p), or `fallback`.
func _flood_point(flood: PackedByteArray, p: Vector2, fallback: Vector2) -> Vector2:
	var c0: Vector2i = game.cell_of(p)
	for r in 14:
		var best := Vector2.INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if game.in_map(c) and flood[game.idx(c)] == 1:
					var q: Vector2 = game.cell_center(c)
					if best == Vector2.INF or q.distance_to(p) < best.distance_to(p):
						best = q
		if best != Vector2.INF:
			return best
	return fallback


## Race the army against one piece. Returns {win, breach, t, left, dps, inc, cap, out, stage,
## reach, splash}.
func _siege_sim(piece: Building, ground: Array, flood: PackedByteArray, centre: Vector2) -> Dictionary:
	var pc := piece.center()
	var out: Vector2 = (centre - pc).normalized()
	if out == Vector2.ZERO:
		out = (game.center_of_team(team) - pc).normalized()
	# --- the defenders that reach the wall face, and how far out past it they reach
	var our_armor := 0.0
	for u in ground:
		our_armor += float(u.d["armor"])
	our_armor /= maxf(1.0, ground.size())
	var single := 0.0            # dps on the man in front
	var spray := 0.0             # dps on each man of a crowd (canister, round shot, shells)
	var reach := 0.0             # how far out past the wall their muskets and canister reach
	var art_reach := 0.0         # ... and their round shot and shells
	var their_hp := 0.0
	var their_armor := 0.0
	var all_single := 0.0        # (all of them, in reach of the wall or not: the fight once we're through)
	var all_spray := 0.0
	var splash := false
	var seen_out := 0.0          # how far out past the wall they see (their guns fire on what they see)
	for o in game.units_near(pc, 520.0):
		if o.dead or o.off_field or not game.hostile(o.team, team) or o.is_worker() or not o.has_attack():
			continue
		if o.d.get("air_only", false):
			continue
		var dd: float = o.position.distance_to(pc)
		seen_out = maxf(seen_out, float(o.sight) * Defs.TILE - dd)
		var dps := maxf(1.0, float(o.d["damage"]) - our_armor) / _cycle(o)
		if o.d.has("gunners"):
			dps *= float(o.d["gunners"])
		their_hp += o.hp
		their_armor += float(o.d["armor"]) * o.hp
		var o_out := float(o.d["range"]) - dd + 16.0
		if o.kind == "cannon":
			var can_out: float = float(Defs.CANISTER["range"]) - dd + 16.0
			var can_dps: float = float(Defs.CANISTER["damage"]) * float(Defs.CANISTER["vs_light"]) / (float(Defs.CANISTER["cooldown"]) + 0.95)
			all_spray += can_dps
			if can_out >= 0.0:
				# canister into the crowd at the wall: a cone of balls into every man there
				spray += can_dps
				reach = maxf(reach, can_out)
				splash = true
			elif o_out >= 0.0:
				spray += dps * 0.6       # round shot through a line of men
				art_reach = maxf(art_reach, o_out)
				splash = true
			continue
		if SPLASH_KINDS.has(o.kind):
			all_spray += dps * 0.7
		else:
			all_single += dps
		if o_out < 0.0:
			continue
		if SPLASH_KINDS.has(o.kind):
			spray += dps * 0.7
			splash = true
			if float(o.d["range"]) > 250.0:
				art_reach = maxf(art_reach, o_out)
			else:
				reach = maxf(reach, o_out)
			continue
		single += dps
		reach = maxf(reach, o_out)
	art_reach = maxf(art_reach, reach)
	their_armor /= maxf(their_hp, 1.0)
	# --- our side: who can hurt the piece (spitter acid strips 2 of its armour)
	var acid := false
	for u in ground:
		if u.kind == "spitter" and u.can_hit(piece):
			acid = true
	var arm := maxf(0.0, piece.armor - (2.0 if acid else 0.0))
	var melee: Array = []       # [hp, dps on the wall, room it takes, how long it lasts there, dps on men]
	var ranged: Array = []      # [hp, dps on the wall, how far back it stands, dps on men]
	var hp_hit := 0.0
	for u in ground:
		if not u.has_attack() or not u.can_hit(piece):
			continue
		var dmg := float(u.d["damage"]) * float(u.d.get("building_bonus", 1.0))
		var wd := maxf(1.0, dmg - arm) / _cycle(u)
		if u.deploys():
			wd *= 0.8            # (it has to set up)
		hp_hit += u.hp
		if _melee(u):
			var side: float = u.radius * 2.0 + 4.0
			# (canister shreds light troops: a tough one lasts longer at the face)
			var lasts: float = u.hp / (float(Defs.CANISTER["vs_light"]) if u.has_tag("light") else 1.0)
			melee.append([u.hp, wd, side * side, lasts, maxf(1.0, float(u.d["damage"]) - their_armor) / _cycle(u)])
		else:
			ranged.append([u.hp, wd, maxf(float(u.d["range"]) * 0.85, float(u.d.get("min_range", 0.0)) + 24.0), maxf(1.0, float(u.d["damage"]) - their_armor) / _cycle(u)])
	var none := {"win": false, "breach": false, "t": INF, "left": 0.0, "dps": 0.0, "inc": single + spray, "cap": 0,
		"out": out, "stage": pc + out * 200.0, "reach": art_reach, "splash": splash}
	if melee.is_empty() and ranged.is_empty():
		return none
	# room at the wall face: the reachable cells touching the piece (a second rank reaches past the first)
	var room := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = piece.cell + Vector2i(dx, dy)
			if (dx != 0 or dy != 0) and game.in_map(c) and flood[game.idx(c)] == 1:
				room += float(Defs.TILE * Defs.TILE) * (1.0 if dx == 0 or dy == 0 else 0.5)
	room *= 2.0
	# the best wall-breakers go to the face first: the most damage for the room they take,
	# for the longest (a Brute before Raptors); the room left is filled with smaller ones,
	# and the rest queue up behind (in that order) to step up as the first fall
	melee.sort_custom(func(a, b) -> bool: return a[1] * a[3] / a[2] > b[1] * b[3] / b[2])
	var at_face: Array = []
	var queue: Array = []
	var used := 0.0
	for m in melee:
		if used + m[2] <= room or at_face.is_empty():
			used += m[2]
			at_face.append(m)
		else:
			queue.append(m)
	var cap := at_face.size()
	melee = at_face + queue
	# repairers on the wall (and those close enough to start)
	var rep := 0.0
	for o in game.units_near(pc, 220.0):
		if not o.dead and game.hostile(o.team, team) and (o.kind == "labourer" or o.kind == "winder"):
			var rate := maxf(float(Defs.REPAIR_RATE), piece.max_hp / maxf(float(piece.d.get("time", 10.0)), 1.0))
			rep += rate * (1.0 if o.work == "repairing" else 0.5)
	# --- the race, half a second at a time. First the wall: the men at the face (the next
	# stepping up as each falls) and the ranged behind against the piece; the defenders in
	# reach fire on the men in front (canister on all of the crowd there), and on the
	# ranged once no melee are left (if they reach that far). Then the fight through the
	# gap: only so many get through at once, against all the defenders behind the wall.
	var mhp: Array = []
	for m in melee:
		mhp.append(m[0])
	var rhp: Array = []
	for r in ranged:
		rhp.append(r[0])
	var wall_hp: float = piece.hp
	var foe_hp := their_hp
	var t := 0.0
	var dt := 0.5
	var limit := 90.0 if single + spray > 0.0 else 200.0
	var next_m := mini(cap, melee.size())
	var active: Array = []
	for i in next_m:
		active.append(i)
	var breached := false
	var t_breach := INF
	var won := false
	var dps0 := -1.0
	while t < limit and not won:
		var dps := 0.0
		for i in active:
			dps += melee[i][1 if not breached else 4]
		for j in ranged.size():
			if rhp[j] > 0.0:
				dps += ranged[j][1 if not breached else 3]
		if dps0 < 0.0:
			dps0 = dps
		if not breached:
			dps -= rep
		if dps <= 0.0:
			break
		t += dt
		if not breached:
			wall_hp -= dps * dt
			if wall_hp <= 0.0:
				breached = true
				t_breach = t
				limit = t + 60.0
				# through the gap: a few more fit than at the wall face
				var cap2 := int(ceil(cap * 1.5))
				while active.size() < cap2 and next_m < melee.size():
					active.append(next_m)
					next_m += 1
				continue
		else:
			foe_hp -= dps * dt
			if foe_hp <= 0.0:
				won = true
				break
		var f_single := single if not breached else all_single
		var f_spray := spray if not breached else all_spray
		var scale := foe_hp / maxf(their_hp, 1.0)
		if not active.is_empty():
			var fire: float = (f_single + f_spray * minf(active.size() + 2.0, 8.0)) * scale * dt     # (canister catches the next in line too)
			while fire > 0.0 and not active.is_empty():
				var i: int = active[0]
				var take: float = minf(fire, mhp[i])
				mhp[i] -= take
				fire -= take
				if mhp[i] <= 0.0:
					active.pop_front()
					if next_m < melee.size():
						active.append(next_m)
						next_m += 1
		else:
			var fire_r: float = (f_single + f_spray * 2.0) * scale * dt
			for j in ranged.size():
				if fire_r <= 0.0:
					break
				if rhp[j] > 0.0 and (breached or ranged[j][2] <= reach):
					var take: float = minf(fire_r, rhp[j])
					rhp[j] -= take
					fire_r -= take
	var hp_left := 0.0
	for v in mhp:
		hp_left += maxf(0.0, v)
	for v in rhp:
		hp_left += maxf(0.0, v)
	var all_hp := 0.0
	for u in ground:
		all_hp += u.hp
	var frac_left := clampf((all_hp - (hp_hit - hp_left)) / maxf(all_hp, 1.0), 0.0, 1.0)
	# through, the defenders beaten, and enough left to go on and raze the base
	var win := breached and won and frac_left >= 0.25
	# the reserve waits out of their muskets' reach, and out of sight of their guns if it can
	var stage: Vector2 = _flood_point(flood, pc + out * clampf(maxf(reach + 70.0, minf(art_reach, seen_out) + 50.0), 130.0, 420.0), centre)
	return {"win": win, "breach": breached, "t": t_breach, "left": frac_left, "dps": maxf(dps0, 0.0),
		"inc": single + spray * minf(cap + 2.0, 8.0), "cap": cap, "out": out, "stage": stage, "reach": art_reach, "mreach": reach, "splash": splash}


## Orders while breaking in: first the army forms up out of the defenders' reach (the melee
## at a staging spot, the ranged at their firing spots, which they open fire from), so it
## doesn't arrive at the wall a few at a time; then the melee go to the face (as many as fit;
## the rest wait out of reach and step up as the first fall). All on the one piece; units
## that can't hurt a wall wait with the reserve.
func _siege_orders(ground: Array) -> void:
	var piece: Building = _siege["piece"]
	var pc := piece.center()
	var out: Vector2 = _siege["out"]
	var stage: Vector2 = _siege["stage"]
	var spots: Dictionary = _siege["spots"]
	var flood: PackedByteArray = _siege["flood"]
	var gap := 44.0 if _siege["splash"] else 26.0      # (against splash the waiting men spread)
	var melee: Array = []
	for u in ground:
		u.siege_t = SIEGE_EVAL + 2.0
		u.wall_flee_t = 0.0
		if not u.has_attack() or not u.can_hit(piece):
			_to_spot(u, stage, gap * 2.0)
			continue
		if _melee(u):
			melee.append(u)
			continue
		# ranged: to its own spot first, then shoot the piece from there
		if not spots.has(u):
			spots[u] = _ranged_spot(u, piece, out, flood, spots, gap)
		var spot: Vector2 = spots[u]
		var in_reach: bool = piece.edge_distance(u.position) - u.radius <= u._range() - 4.0
		if u.order == "attack" and u.order_target == piece and in_reach:
			continue
		if in_reach and (u.position.distance_to(spot) < 28.0 or u.stuck_t > 0.8):
			u.cmd_attack(piece)
		elif u.order != "move" or u.order_point.distance_to(spot) > 8.0:
			u.cmd_move(spot)
	if not _siege["formed"]:
		var there := 0
		for u in melee:
			if u.position.distance_to(stage) < 110.0 or piece.edge_distance(u.position) < 60.0:
				there += 1
		if there >= melee.size() * 0.75 or game.clock - float(_siege["since"]) > 15.0:
			_siege["formed"] = true
		else:
			for u in melee:
				if u.order == "attack" and u.order_target == piece and piece.edge_distance(u.position) < 60.0:
					continue         # (already at it)
				_to_spot(u, stage, gap * 2.0)
			return
	# melee: the best wall-breakers to the face (a Brute before Raptors: the most damage on the
	# piece for the room it takes, for longest under fire), as many as fit; the rest wait at
	# the stage out of reach, holding there (not wandering up to the wall on their own)
	var arm := _piece_armor(piece, ground)
	var val := {}
	for u in melee:
		val[u] = _breaker_value(u, piece, arm)
	melee.sort_custom(func(a, b) -> bool:
		if absf(val[a] - val[b]) > 0.01:
			return val[a] > val[b]
		return a.position.distance_to(pc) < b.position.distance_to(pc))
	var cap: int = maxi(1, int(ceil(float(_siege["cap"]) * 1.15)))
	# a few seconds before the piece falls the reserve moves up to the edge of the defenders'
	# reach, so the whole lot goes through the gap together, not in a trickle from the stage
	var now := game.clock
	if _siege.has("hp_at"):
		var dt: float = now - float(_siege["hp_at"])
		if dt > 0.1:
			var rate: float = (float(_siege["hp_was"]) - piece.hp) / dt
			_siege["rate"] = lerpf(float(_siege.get("rate", rate)), rate, 0.5)
	_siege["hp_at"] = now
	_siege["hp_was"] = piece.hp
	var rate_now: float = float(_siege.get("rate", 0.0))
	var close_in: bool = rate_now > 1.0 and piece.hp / rate_now < 3.0
	var near_pt: Vector2 = _flood_point(flood, pc + out * maxf(float(_siege.get("mreach", 50.0)) + 20.0, 60.0), stage)
	# the chosen ones not at the face yet leave room for those already hacking there
	var spare := 0
	for i in mini(cap, melee.size()):
		if piece.edge_distance(melee[i].position) > 50.0:
			spare += 1
	for i in melee.size():
		var u: Unit = melee[i]
		if i < cap:
			if not (u.order == "attack" and u.order_target == piece):
				u.cmd_attack(piece)
			continue
		if u.order == "attack" and u.order_target == piece and piece.edge_distance(u.position) < 40.0 and spare > 0:
			spare -= 1
			continue                 # (keeps its place until a better breaker gets there)
		_to_spot(u, near_pt if close_in else stage, gap * (1.0 if close_in else 2.0))


## Waiting in a siege's reserve: walk to the spot, then hold there (a unit left idle would go
## for the wall by itself, into the defenders' fire).
## (They spread along the wall and back from it, never forward of the spot: into reach.)
func _to_spot(u: Unit, pt: Vector2, spread: float) -> void:
	var out: Vector2 = _siege.get("out", Vector2.ZERO)
	var off := u.position - pt
	if off.length() < spread * 1.5 + 16.0 and off.dot(out) > -16.0:
		if u.order != "hold" and u.order != "move":
			u.cmd_hold()
		return
	if u.order != "move" or u.order_point.distance_to(pt) > spread * 1.5 + 10.0:
		var side := out.orthogonal()
		var p := pt + side * randf_range(-1.4, 1.4) * spread + out * randf_range(0.0, 1.0) * spread
		u.cmd_move(_flood_point(_siege["flood"], p, pt) if _siege.has("flood") else p)


## The piece's armour against this army (Spitter acid strips 2).
func _piece_armor(piece: Building, ground: Array) -> float:
	for u in ground:
		if u.kind == "spitter" and u.can_hit(piece):
			return maxf(0.0, piece.armor - 2.0)
	return piece.armor


## How good a wall-breaker a melee unit is: damage on the piece per second, for the room it
## takes at the face, for how long it lasts there (canister shreds light troops).
func _breaker_value(u: Unit, piece: Building, arm: float) -> float:
	var dmg := float(u.d["damage"]) * float(u.d.get("building_bonus", 1.0))
	var wd := maxf(1.0, dmg - arm) / _cycle(u)
	var side: float = u.radius * 2.0 + 4.0
	var lasts: float = u.hp / (float(Defs.CANISTER["vs_light"]) if u.has_tag("light") else 1.0)
	return wd * lasts / (side * side)


## A firing spot for a ranged unit: in its range of the piece, off the lane the melee walk up
## (straight out from the piece), apart from the others' spots, on ground it can reach.
func _ranged_spot(u: Unit, piece: Building, out: Vector2, flood: PackedByteArray, spots: Dictionary, gap: float) -> Vector2:
	var pc := piece.center()
	var rng: float = u._range()
	var lo: float = maxf(float(u.d.get("min_range", 0.0)) + 24.0, minf(70.0, rng * 0.6))
	var want: float = clampf(rng * 0.85, lo, rng - 10.0)
	var r := int(ceil(rng / Defs.TILE)) + 1
	var best := u.position
	var bs := INF
	var side := out.orthogonal()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = piece.cell + Vector2i(dx, dy)
			if not game.in_map(c) or flood[game.idx(c)] == 0:
				continue
			var p: Vector2 = game.cell_center(c)
			var e: float = piece.edge_distance(p)
			if e > rng - 10.0 or e < lo:
				continue
			var v := p - pc
			var s := absf(e - want) * 0.5 + p.distance_to(u.position) * 0.15
			if v.dot(out) > 0.0 and absf(v.dot(side)) < 52.0:
				s += 200.0           # the melee lane
			for o in spots:
				if is_instance_valid(o) and o != u and (spots[o] as Vector2).distance_to(p) < gap:
					s += 150.0
			if s < bs:
				bs = s
				best = p
	return best + Vector2(randf_range(-6, 6), randf_range(-6, 6))


## Clockwork: two Winders walk behind the army and repair it (they repair whatever is
## hurt near them on their own when they stop).
func _follow_with_escort(army: Array) -> void:
	if army.is_empty():
		return
	var c := Vector2.ZERO
	for u in army:
		c += u.position
	c /= army.size()
	var tins := army.filter(func(o: Unit) -> bool: return o.runs_on_spring()).size()
	while _escort.size() < 2 + mini(tins / 6, 3):
		var pick: Unit = null
		for u in game.workers(team):
			if not _escort.has(u) and u.order != "build":
				pick = u
				if u.order == "idle":
					break
		if pick == null:
			break
		_escort.append(pick)
	# run-down Wind-up Soldiers first: the escort cranks them back up
	var down: Array = game.units.filter(func(o: Unit) -> bool: return o.team == team and not o.dead and o.runs_on_spring() and o.powered_down())
	for u in _escort:
		if u.order == "repair":
			continue
		var crank: Unit = null
		var cd := 700.0
		for o in down:
			var dd: float = o.position.distance_to(u.position)
			if dd < cd and not game.units.any(func(x: Unit) -> bool: return x != u and x.order == "repair" and x.order_target == o):
				cd = dd
				crank = o
		if crank:
			u.cmd_repair(crank)
			down.erase(crank)
			continue
		if u.position.distance_to(c) > 140.0:
			u.cmd_move(c + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


func _release_escort() -> void:
	for u in _escort:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	_escort.clear()


## Every place our buildings are under attack (one spot per raid, at least 300 px apart).
## Can this soldier hit a flyer at all (anti-air men, the cannon's canister)?
func _hits_air(u: Unit) -> bool:
	return bool(u.d.get("anti_air", false)) or u.kind == "cannon"


func _threats() -> Array:
	var out: Array = []
	for b in game.buildings:
		if b.team != team or b.dead:
			continue
		for u in game.units_near(b.center(), 330.0):
			if game.hostile(u.team, team) and not u.dead and not u.off_field:
				if out.all(func(p: Vector2) -> bool: return p.distance_to(u.position) > 300.0):
					out.append(u.position)
				break
	return out


func _threat() -> Vector2:
	for b in game.buildings:
		if b.team != team or b.dead:
			continue
		for u in game.units_near(b.center(), 330.0):
			if game.hostile(u.team, team) and not u.dead and not u.off_field:
				return u.position
	return Vector2.INF


## Which enemy to go after: the nearest one; Brutal hunts the human player first.
func _foe() -> int:
	var foes := game.enemies_of(team)
	if foes.is_empty():
		return -1
	if difficulty >= 3 and not game.demo and foes.has(game.human):
		return game.human
	var me := game.center_of_team(team)
	var best: int = foes[0]
	var bd := INF
	for f in foes:
		var dd: float = game.center_of_team(f).distance_to(me)
		if dd < bd:
			bd = dd
			best = f
	return best


func _enemy_base() -> Vector2:
	var enemy := _foe()
	if enemy < 0:
		return game.center_of_team(team)
	var best := Vector2.INF
	var bd := INF
	var me := game.center_of_team(team)
	# go for the economy: the enemy's nearest hall (its workers and farms are around it);
	# the army fights whatever is in the way on the walk there. A hall walled too strongly
	# for the last wave is left be for a while, if there's another one.
	var open_hall := false
	for b in game.buildings:
		if b.team == enemy and not b.dead and not b.ghost and b.kind == game.faction_hall(enemy) and float(_walled_halls.get(b, 0.0)) <= game.clock:
			open_hall = true
	for b in game.buildings:
		if b.team == enemy and not b.dead and not b.ghost and b.kind == game.faction_hall(enemy):
			if open_hall and float(_walled_halls.get(b, 0.0)) > game.clock:
				continue
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best != Vector2.INF:
		return best
	for b in game.buildings:
		if b.team == enemy and not b.dead and not b.ghost:
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best == Vector2.INF:
		return Vector2(game.starts[enemy]) * Defs.TILE
	return best


# ------------------------------------------------------------------ abilities (Normal and up)

## Canister when a crowd closes on a cannon. (Musketeers pick musket or bayonet by themselves.)
func _abilities() -> void:
	_spells()
	if _brood():
		_skywings()
		_offer()
	if _clock():
		_overloads()
		_braces()
	if not _crown():
		return
	for u in game.army(team):
		if u.kind == "cannon":
			var crowd := 0
			var flyers := 0
			for o in game.units_near(u.position, Defs.CANISTER["range"] + 20.0):
				if game.hostile(o.team, team) and not o.dead:
					crowd += 1
					if o.is_air():
						flyers += 1
			u.set_canister(crowd >= 3 or flyers >= 1)


## Stormcallers drop storms on packed enemies (not on our own men); Spore Mothers heal a
## hurt swarm in the middle of a fight.
func _spells() -> void:
	for u in game.army(team):
		# half the Bloaters keep their gas for big bursts (on walls and clumps)
		if u.kind == "bloater" and u.mode == "" and u.get_instance_id() % 2 == 0:
			u.set_hold_gas(true)
		if u.order == "cast" or u.order == "tongue" or u.tongue_stage != "":
			continue
		if u.kind == "mist_toad":
			_toad(u)
		elif u.kind == "stormcaller" and u.charge >= float(Defs.STORM["cost"]):
			var best := Vector2.INF
			var score := 3.5 if difficulty >= 2 else 4.5
			var r: float = Defs.STORM["radius"]
			for e in game.units_near(u.position, float(Defs.STORM["range"]) + 60.0):
				if not game.hostile(e.team, team) or e.dead or e.off_field:
					continue
				var s := 0.0
				for o in game.units_near(e.position, r):
					if o.dead or o.off_field:
						continue
					if game.hostile(o.team, team):
						s += 1.0 + float(o.d["supply"]) * 0.25
					else:
						s -= 2.0
				if s > score:
					score = s
					best = e.position
			# the storm only stuns: worth it when our own army is there to hit them meanwhile
			if best != Vector2.INF and game.units_near(best, r + 160.0).any(func(f: Unit) -> bool: return f.team == team and not f.dead and not f.is_worker() and f.kind != "stormcaller" and f.position.distance_to(best) > r):
				u.cmd_cast("storm", best)
		elif u.kind == "spore_mother" and u.spell_cd <= 0.0 and _res2() >= float(Defs.MIASMA["cost2"]) + 10.0:
			var hurt := 0
			var at := Vector2.ZERO
			for o in game.units_near(u.position, float(Defs.MIASMA["range"])):
				if o.team == team and not o.dead and o.hp < o.max_hp * 0.65:
					hurt += 1
					at += o.position
			if hurt >= 4:
				u.cmd_cast("miasma", at / hurt)


## Mist Toad: TONGUE drags a high-value target (guns, casters, a Missionary) into the swarm,
## once our army is close enough to eat it; FOG goes down on an enemy firing line while our
## army is engaging it. It keeps the energy for a TONGUE when there's a prize about.
const TONGUE_PRIZES := ["cannon", "mortar", "stormcaller", "tesla_cart", "arc_thrower", "missionary", "spore_mother"]


func _toad(u: Unit) -> void:
	# (Toads share the work: one prize per tongue, one fog bank at a time)
	var taken := {}
	var fogging := false
	for o in game.army(team):
		if o.kind == "mist_toad" and o != u:
			if o.tongue_victim:
				taken[o.tongue_victim] = true
			if o.order == "tongue" and o.order_target:
				taken[o.order_target] = true
			if o.order == "cast":
				fogging = true
	var near: Array = game.units_near(u.position, float(Defs.TONGUE["range"]) + 120.0)
	var friends := 0
	for f in game.units_near(u.position, 220.0):
		if f.team == team and not f.dead and not f.is_worker() and f != u:
			friends += 1
	# TONGUE: the best prize in reach (round to it if it's just out of range)
	var prize: Unit = null
	var pv := 0.0
	for e in near:
		if not TONGUE_PRIZES.has(e.kind) or taken.has(e) or not u.can_tongue(e) or not game.side_sees(team, e.position):
			continue
		var dd: float = e.position.distance_to(u.position)
		var v := float(e.d["cost"]) + float(e.d.get("cost2", 0)) * 2.0 - dd * 0.3
		if v > pv:
			pv = v
			prize = e
	if prize and u.charge >= float(Defs.TONGUE["cost"]) and friends >= 3:
		u.cmd_tongue(prize)
		return
	# FOG: on the enemy's shooters, while our army is in the fight
	var keep := float(Defs.TONGUE["cost"]) if prize else 0.0
	if fogging or u.charge < float(Defs.FOG["cost"]) + keep:
		return
	var best := Vector2.INF
	var score := 2.5
	var r := float(Defs.FOG["radius"])
	for e in game.units_near(u.position, float(Defs.FOG["range"]) + r):
		if not game.hostile(e.team, team) or e.dead or e.off_field or e.is_worker() or float(e.d["range"]) < 100.0:
			continue
		if game.in_fog(e.position):
			continue
		var s := 0.0
		for o in game.units_near(e.position, r):
			if o.dead or o.off_field or o.is_worker():
				continue
			if game.hostile(o.team, team):
				s += (1.0 + float(o.d["supply"]) * 0.25) if float(o.d["range"]) >= 100.0 else 0.2
			elif float(o.d["range"]) >= 100.0:
				s -= 0.6      # our own shooters in there would miss too
		if s > score:
			score = s
			best = e.position
	if best == Vector2.INF:
		return
	# only while our army engages them: someone of ours fighting close by
	var engaged := game.units_near(best, r + 200.0).any(func(f: Unit) -> bool: return f.team == team and not f.dead and not f.is_worker() and f.kind != "mist_toad" and (f.target != null or f.position.distance_to(best) < r + 60.0))
	if engaged:
		var at := best
		if at.distance_to(u.position) > float(Defs.FOG["range"]):
			at = u.position + (best - u.position).normalized() * float(Defs.FOG["range"])
		u.cmd_cast("fog", at)


## Brood: Skywings hunt flyers in the air; with no enemy flyers about they land on enemy
## ground forces and bite, and take off again when flyers show up.
func _skywings() -> void:
	for u in game.army(team):
		if u.kind != "skywing" or u.sky_cd > 0.0 or u.order in ["move", "cast"]:
			continue
		var flyers := 0
		var ground := 0
		for o in game.units_near(u.position, 380.0):
			if not game.hostile(o.team, team) or o.dead or o.off_field:
				continue
			if o.is_air():
				flyers += 1
			elif not o.is_worker() or o.position.distance_to(u.position) < 200.0:
				ground += 1
		if u.sky == "air" and flyers == 0 and ground >= 2 and (u.target == null or u.order == "idle"):
			u.cmd_land()
			u.sky_cd = 6.0
		elif u.sky == "ground" and (flyers > 0 or (ground == 0 and u.target == null)):
			u.cmd_take_off()
			u.sky_cd = 6.0


## Brood: when it can hatch essence-costing creatures (Skywings, Bloaters, Brutes, Spore
## Mothers; Spitters too) but lacks the essence and its biomass bank is high, spare Raptors
## at home are offered up at the Brood Pen (3 essence each). With almost none left, a few
## go whatever the bank (Spitters need 5 an egg).
var _offer_next := 0.0


func _offer() -> void:
	if game.clock < _offer_next or _hall_reserve:
		return
	var pen := game.nearest_of(game.center_of_team(team), team, "brood_pen")
	if pen == null:
		return
	var want := 0
	for k in ["skywing", "bloater", "brute", "spore_mother", "mist_toad", "spitter"]:
		var u: Dictionary = Defs.UNITS[k]
		var reqs: Array = u["requires"] if u.get("requires", "") is Array else [u["requires"]]
		if reqs.all(func(r: String) -> bool: return game._has_built(team, r)):
			want = maxi(want, int(u.get("cost2", 0)))
	if _mound_saving():
		want = maxi(want, int(Defs.HALL_LEVELS[2]["cost2"]) + 20)     # (for the Broodmound)
	if want == 0:
		return
	var target := want
	var pending := 0
	for u in game.army(team):
		if u.order == "sacrifice":
			pending += Game.sacrifice_value(u.kind)
	var have := _res2() + pending
	# a little essence always (Spitters, 5 an egg, are the swarm's answer to armour and
	# flyers): a few raptors whatever the bank; more only with biomass piling up
	var small := have < 10.0
	if have >= target or (not small and _gold() < _lv([700, 550, 450])):
		return
	if small and _gold() < 100:
		return
	var in_wave := {}
	for g in _swarm:
		for u in g[0]:
			in_wave[u] = true
	var raptors := game.army(team).filter(func(u: Unit) -> bool: return u.kind == "raptor" and not in_wave.has(u) \
		and u.order in ["idle", "move", "amove"] and u.target == null)
	if raptors.size() <= 6:
		return              # (keep a few at home)
	raptors.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(pen.center()) < b.position.distance_squared_to(pen.center()))
	var n := mini(mini(int(ceil((target - have) / 3.0)), 4 if small and _gold() < _lv([700, 550, 450]) else 9), raptors.size() - 6)
	for u in raptors.slice(0, n):
		u.cmd_sacrifice()
	_offer_next = game.clock + _lv([40.0, 25.0, 15.0])


## Clockwork: Bulwarks BRACE when the army faces a firing line (musketeers, spitters and
## the like shooting at it) with friends behind the shield to cover; they lift it again
## when the shooting stops, the others have moved on, or melee is all over them.
func _braces() -> void:
	for u in game.army(team):
		if u.kind != "bulwark" or u.powered_down() or u.brace_t > 0.0:
			continue
		var shooters := 0
		var melee := 0
		var at := Vector2.ZERO
		for o in game.units_near(u.position, 340.0):
			if not game.hostile(o.team, team) or o.dead or o.off_field or o.is_worker():
				continue
			if float(o.d["range"]) >= 100.0 and o.kind != "cannon" and o.kind != "spore_mother":
				shooters += 1
				at += o.position
			elif o.position.distance_to(u.position) < 70.0:
				melee += 1
		var friends := 0
		for f in game.units_near(u.position, float(Defs.BRACE["reach"])):
			if f != u and f.team == team and not f.dead and not f.is_air() and f.kind != "bulwark":
				friends += 1
		if not u.braced:
			if shooters >= 2 and friends >= 2 and melee < 3:
				u.set_brace(true)
				u.facing = (at / shooters - u.position).normalized()
		elif shooters == 0 or friends < 1 or melee >= 4:
			u.set_brace(false)


## Clockwork: an Ornithopter with a battery overloads a Thresher (or a Steam Walker)
## that's just getting into a fight.
func _overloads() -> void:
	var topters: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "ornithopter" and u.topter_bat != "" and u.order != "overload" and u.work != "winding")
	if topters.is_empty():
		return
	for k in ["thresher", "steam_walker"]:
		for c in game.army(team):
			if c.kind != k or c.overclock_t > 0.0 or c.powered_down() or c.target == null or not is_instance_valid(c.target):
				continue
			if c.target.edge_distance(c.position) > 140.0:
				continue
			var best: Unit = null
			var bd := 600.0
			for t in topters:
				var dd: float = t.position.distance_to(c.position)
				if dd < bd:
					bd = dd
					best = t
			if best:
				best.cmd_overload(c)
				topters.erase(best)
				if topters.is_empty():
					return


## Crown: now and then a balloon takes four Musketeers aboard and drops them on the
## enemy's workers, away from its army; then it floats home.
var _drop := {}                 # {"b": balloon, "men": [..], "phase": "load"/"fly", "at": spot, "t": seconds}
var _drop_next := 300.0         # (match clock) the earliest next drop


func _balloon_drop() -> void:
	# balloons low on powder (their store refills the Musketeers aboard) go and restock
	for u in game.army(team):
		if u.kind == "balloon" and u.passengers.is_empty() and u.powder < u._pmax * 0.5 and u.order in ["idle", "amove", "move"] \
				and (_drop.is_empty() or _drop.get("b") != u):
			u.cmd_restock()
	if _drop.is_empty():
		if game.clock < _drop_next or _threat() != Vector2.INF:
			return
		var balloon: Unit = null
		for u in game.army(team):
			if u.kind == "balloon" and u.passengers.is_empty() and u.hp > u.max_hp * 0.6 and u.order in ["idle", "amove", "move"]:
				balloon = u
				break
		if balloon == null or not game._clear_at(balloon.position, 8.0, team):
			return
		var men: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "musketeer" and u.order in ["idle", "amove"] \
			and u.target == null and u.position.distance_to(balloon.position) < 700.0 and not _raiders.has(u))
		if men.size() < 3:
			_drop_next = game.clock + 30.0
			return
		men.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(balloon.position) < b.position.distance_squared_to(balloon.position))
		men = men.slice(0, int(Defs.DROPSHIP["capacity"]))
		var at := _drop_spot()
		if at == Vector2.INF:
			_drop_next = game.clock + 60.0
			return
		balloon.cmd_stop()
		game.load_order(men, [balloon])
		_drop = {"b": balloon, "men": men, "phase": "load", "at": at, "t": 0.0}
		return
	var b = _drop["b"]
	_drop["t"] = float(_drop["t"]) + _think_dt
	_drop["men"] = (_drop["men"] as Array).filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if not is_instance_valid(b) or b.dead:
		_end_drop()
		return
	match _drop["phase"]:
		"load":
			var walking: bool = (_drop["men"] as Array).any(func(u: Unit) -> bool: return u.order == "board")
			if not walking or float(_drop["t"]) > 30.0:
				if b.passengers.is_empty():
					_end_drop()
					return
				b.cmd_unload(_drop["at"])
				_drop["phase"] = "fly"
				_drop["t"] = 0.0
		"fly":
			if b.passengers.is_empty():
				# they're down: at them, and the balloon goes home
				for u in _drop["men"]:
					u.cmd_move(_drop["at"] + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
				if game.mlog:
					game.mlog.add("%s dropped %d Musketeers from a balloon" % [game.mlog.who(team), (_drop["men"] as Array).size()])
				var hall: Array = _halls()
				if not hall.is_empty():
					b.cmd_move(hall[0].center())
				_end_drop()
			elif b.hp < b.max_hp * 0.4 and b.work != "dropping":
				b.cmd_unload(b.position)        # being shot down: let them off now
			elif b.order != "unload":
				b.cmd_unload(_drop["at"])


func _end_drop() -> void:
	for u in _drop.get("men", []):
		if is_instance_valid(u) and not u.dead and u.order == "board":
			u.cmd_stop()
	_drop = {}
	_drop_next = game.clock + randf_range(150.0, 240.0)


## Where to drop: next to the enemy's workers or economy, the farther from its army the better.
func _drop_spot() -> Vector2:
	var foe := _foe()
	if foe < 0:
		return Vector2.INF
	var foes_army: Array = game.army(foe)
	var best := Vector2.INF
	var score := -INF
	for b in game.buildings:
		if b.team != foe or b.dead or b.ghost or not (Defs.is_econ(b.kind) or b.kind == game.faction_hall(foe)):
			continue
		var guard := 0
		for o in foes_army:
			if o.position.distance_to(b.center()) < 350.0:
				guard += int(o.d["supply"])
		var s: float = -float(guard) * 10.0 + (30.0 if Defs.is_econ(b.kind) else 0.0) - b.center().distance_to(game.center_of_team(team)) * 0.01
		if s > score:
			score = s
			best = b.center()
	if best == Vector2.INF:
		return Vector2.INF
	# beside it, on the side away from the enemy's base centre
	var away: Vector2 = (best - game.center_of_team(foe)).normalized()
	return best + (away if away != Vector2.ZERO else Vector2.RIGHT) * 70.0


# ------------------------------------------------------------------ micro (Hard and Brutal)

var _kite := {}       # unit -> seconds until it turns back to the fight
var _mending := {}    # hurt units sent home to heal


func _value(u: Unit) -> float:
	return float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) * (u.hp / maxf(1.0, u.max_hp)) + 20.0


## Focus fire on the weakest enemy in reach; Brutal also kites with ranged units, sends
## badly hurt big units home to heal and backs off from a fight that's lost.
func _micro() -> void:
	var army := game.army(team)
	if army.is_empty():
		return
	var brutal := difficulty >= 3
	var halls := _halls()
	var home: Vector2 = halls[0].center() if not halls.is_empty() else game.center_of_team(team)
	if brutal and _attacking:
		var c := Vector2.ZERO
		var mine := 0.0
		for u in army:
			c += u.position
			mine += _value(u)
		c /= army.size()
		var theirs := 0.0
		for o in game.units_near(c, 380.0):
			if game.hostile(o.team, team) and not o.dead and not o.is_worker() and not o.off_field:
				theirs += _value(o)
		if theirs > mine * 1.5 and theirs > 300.0:
			_attacking = false
			_release_escort()
			for u in army:
				u.cmd_move(home.lerp(c, 0.25) + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
			return
	for k in _kite.keys():
		if not is_instance_valid(k) or k.dead:
			_kite.erase(k)
	for k in _mending.keys():
		if not is_instance_valid(k) or k.dead or k.hp > k.max_hp * 0.85:
			_mending.erase(k)
	for u in army:
		if u.deploys() or u.d.get("medic", false) or _mending.has(u) or _on_errand(u) or u.siege_t > 0.0:
			continue
		if brutal and u.hp < u.max_hp * 0.25 and int(u.d["supply"]) >= 2 and u.target:
			_mending[u] = true
			u.cmd_move(home + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
			continue
		if _kite.has(u):
			_kite[u] = float(_kite[u]) - _think_dt
			if float(_kite[u]) <= 0.0:
				_kite.erase(u)
				u.cmd_move(_wave_target if _attacking else u.position, true)
			continue
		var reach: float = float(u.d["range"]) + u.radius + 30.0
		# (Musketeers stand and use the bayonet instead)
		if brutal and float(u.d["range"]) >= 100.0 and u.cooldown > 0.4 and not u.is_air() and u.kind != "musketeer":
			var close: Unit = null
			var cd := 70.0
			for o in game.units_near(u.position, 70.0):
				if game.hostile(o.team, team) and not o.dead and float(o.d["range"]) < 50.0 and o.can_hit(u):
					var dd: float = o.position.distance_to(u.position)
					if dd < cd:
						cd = dd
						close = o
			if close:
				u.cmd_move(u.position + (u.position - close.position).normalized() * 60.0)
				_kite[u] = 0.6
				continue
		if u.order in ["idle", "amove", "hold"] and u.target:
			var best: Entity = null
			var bh := INF
			for o in game.units_near(u.position, reach):
				if game.hostile(o.team, team) and not o.dead and not o.off_field and u.can_hit(o) and not o.untouchable():
					var h: float = o.hp - (200.0 if o.d.get("medic", false) else 0.0) - (40.0 if float(o.d["damage"]) > 20.0 else 0.0)
					if h < bh:
						bh = h
						best = o
			if best and best != u.target:
				u.target = best


# ------------------------------------------------------------------ horses (Crown)

## Crown horses: a Horseman, cannon, mortar or wagon in a queue gets its own horse by
## itself (Game.train: a free one at a breeder, else the breeder trains one), so the
## computer only keeps a spare or two bought at its breeder (_buy_horses); the Town Hall's
## haulers (_assign_haulers) bring them to the buildings; stray horses are sent home; guns and wagons at home get a second horse (_team_up); spare horses become
## Dragoons' mounts; dismounted cavalry gets back on a horse.
func _horses() -> void:
	var horses: Array = game.horses_of(team)
	var halls := _halls()
	if halls.is_empty():
		return
	# where horses are wanted, and how many short each place is
	var short := {}
	var need := 0
	var places: Array = _mine("foundry").filter(func(b: Building) -> bool: return b.built)
	for b in places:
		var want := 2 if _gold() > 600 else 1
		var have: int = game.horses_at(b)
		for h in horses:
			if h.order == "move" and b.edge_distance(h.order_point) < 40.0:
				have += 1       # (on its way there)
		if have < want:
			short[b] = want - have
			need += want - have
	# horses standing at those places stay there (and the ones kept for a recruit)
	var keep := {}
	for h in horses:
		if h.horse_rid != 0:
			keep[h] = true
			continue
		for b in places:
			if b.edge_distance(h.position) <= float(Defs.HORSES["at_building"]) * Defs.TILE + h.radius:
				keep[h] = true
	# strays (far from all our buildings, nobody with them): home to a breeder or the hall
	var homes: Array = _mine("horse_breeder").filter(func(b: Building) -> bool: return b.built)
	if homes.is_empty():
		homes = halls
	for h in horses:
		if h.leader != null or h.into != null or h.order != "idle" or keep.has(h):
			continue
		var near_home := false
		for b in game.buildings:
			if b.team == team and not b.dead and b.edge_distance(h.position) < 8.0 * Defs.TILE:
				near_home = true
				break
		if not near_home and not game.units_near(h.position, 80.0).any(func(o: Unit) -> bool: return o.team == team and o.kind != "horse"):
			var hb: Building = homes[0]
			for b in homes:
				if b.center().distance_to(h.position) < hb.center().distance_to(h.position):
					hb = b
			h.cmd_move(game.approach_point(hb, h.position) + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	_remount_riders(horses, keep)
	_spares_home(horses, keep)
	var teams := _team_up(horses, keep)
	_buy_horses(horses, keep, need + teams)
	_assign_haulers()
	if difficulty >= 1:
		_mount_men(horses, keep, need + teams)


## Crown: workers assigned to the Town Hall as haulers (Game.haul_dispatch: they lead the
## horses to the Barracks and Foundries and carry kegs to the wagons). One once there is a
## Horse Breeder, a gun or a wagon, two from 6 horse-using units, three from 12. The man comes
## from the idle ones first, else a farm hand (never the Mill, never a builder); the farm is
## refilled by the next hire, as haulers aren't counted among game.workers.
func _assign_haulers() -> void:
	var halls: Array = _halls().filter(func(h: Building) -> bool: return h.built and h.haul_cap() > 0)
	if halls.is_empty():
		return
	var users := game.army(team).filter(func(u: Unit) -> bool: return Defs.RIDERS.has(u.kind) or Defs.HARNESSED.has(u.kind)).size()
	var want := 0
	if users > 0 or not _mine("horse_breeder").is_empty():
		want = 1 + (1 if users >= 6 else 0) + (1 if users >= 12 else 0)
	if game.haulers_of(team).size() >= want:
		return
	var hall: Building = halls[0]
	var best: Unit = null
	var bd := INF
	for u in game.workers(team):
		if u.kind != "labourer" or u.order == "build" or u.keg or _escort.has(u):
			continue
		var farm: bool = u.order == "gather" and u.home_mine is Building and (u.home_mine as Building).kind == "farm"
		if u.order != "idle" and not farm:
			continue
		var dd: float = u.position.distance_to(hall.center()) + (0.0 if u.order == "idle" else 3000.0)
		if dd < bd:
			bd = dd
			best = u
	if best:
		best.cmd_gather(hall)


## A man of ours on foot who should be on a horse: a Dismounted Horseman or Cuirassier, or
## one of our Dragoons left on foot (auto_mount) once the fight is over.
func _wants_horse(u: Unit) -> bool:
	if u.kind == "dismounted":
		return true
	return u.kind == "musketeer" and (u.auto_mount or u.horse_rid != 0)    # (a Dragoon on foot, or one trained, his horse kept for him)


## Fighting, or enemy fighters close by: not the moment to walk off for a horse.
func _in_fight(u: Unit) -> bool:
	if u.target != null and is_instance_valid(u.target) and not u.target.dead and game.hostile(u.target.team, team):
		return true
	for o in game.units_near(u.position, 7.0 * Defs.TILE):
		if not o.dead and game.hostile(o.team, team) and not o.is_worker() and o.kind != "horse" and o.has_attack():
			return true
	return false


var _mount_t := {}               # rider -> when he set off for his horse (_remount_riders)
var _bad_horse := {}             # horse -> until when riders leave it be (they couldn't reach it)


## Every rider of ours left on foot gets on a horse: his own reserved one (Unit._wait_horse
## takes him there), or, when that isn't to be had (still at the breeder, killed, stolen,
## taken by another; or he has none: he dismounted, was raised, his horse bolted), the
## nearest free horse of ours (not kept for someone else, not led or hitched, not standing
## ready at a Foundry), wherever it stands, out of a fight. Taking another horse frees his
## reservation (Unit.do_mount): one still being bred comes out a spare.
func _remount_riders(horses: Array, keep: Dictionary) -> void:
	# (a man who has been walking to a horse for long without getting there can't reach it:
	# he lets it go, and that horse is left out for a while)
	for u in _mount_t.keys():
		if not is_instance_valid(u) or u.dead or u.order != "mount":
			_mount_t.erase(u)
	for h in _bad_horse.keys():
		if not is_instance_valid(h) or game.clock > float(_bad_horse[h]):
			_bad_horse.erase(h)
	for u in game.army(team):
		if u.order == "mount" and u.work != "mounting" and u.order_target is Unit:
			if not _mount_t.has(u):
				_mount_t[u] = game.clock
			elif game.clock - float(_mount_t[u]) > 35.0:
				_bad_horse[u.order_target] = game.clock + 40.0
				_mount_t.erase(u)
				u.cmd_stop()
	var free := horses.filter(func(h: Unit) -> bool: return not h.off_field and h.horse_rid == 0 and h.leader == null and h.into == null \
		and not Unit._claim_live(h) and not keep.has(h) and not _bad_horse.has(h))
	if free.is_empty():
		return
	for u in game.army(team):
		if free.is_empty():
			return
		if not _wants_horse(u) or u.order == "mount" or u.work != "" or u.aboard or u.off_field or u._heal_remount or _on_errand(u) or u.order == "hold":
			continue
		if u.kind == "musketeer" and u.order != "idle" and u.horse_rid == 0:
			continue                         # (a Dragoon on foot remounts by himself to move)
		if u.horse_rid != 0:
			var mine: Unit = game.reserved_horse(team, u.horse_rid)
			if (mine and Unit.horse_free_for(mine, u)) or game.hauler_serves_rid(team, u.horse_rid):
				continue                     # (his own is there for him, or a hauler brings it: Unit._wait_horse)
		if _in_fight(u):
			continue
		var reach := (40.0 if u.kind == "dismounted" or u.horse_rid != 0 else 12.0) * Defs.TILE
		var h: Unit = null
		var bd := reach
		for o in free:
			var dd: float = o.position.distance_to(u.position)
			if dd < bd and Unit.horse_free_for(o, u):
				bd = dd
				h = o
		if h == null:
			continue
		var aft := {}
		if u.order == "amove" or u.order == "move":
			aft = {"o": u.order, "p": u.order_point}
		if u.cmd_mount(h, aft):
			free.erase(h)


## Spare horses standing about away from home (where a rider left them, a loose one caught)
## with nobody of ours by them: home to a breeder, where a new recruit takes one instead of a
## new one being bought (Game.spare_horse). Horses at a Barracks stay: a recruit there takes
## one straight away (Game.free_horse_at).
func _spares_home(horses: Array, keep: Dictionary) -> void:
	var brs: Array = _mine("horse_breeder").filter(func(b: Building) -> bool: return b.built)
	if brs.is_empty():
		return
	var near := float(Defs.HORSES["near_breeder"]) * Defs.TILE
	var at := float(Defs.HORSES["at_building"]) * Defs.TILE
	var bars: Array = _mine("barracks").filter(func(b: Building) -> bool: return b.built)
	for h in horses:
		if h.off_field or h.order != "idle" or h.horse_rid != 0 or h.leader != null or h.into != null or keep.has(h) or Unit._claim_live(h):
			continue
		if brs.any(func(b: Building) -> bool: return b.edge_distance(h.position) <= near + h.radius):
			continue
		if bars.any(func(b: Building) -> bool: return b.edge_distance(h.position) <= at + h.radius):
			continue
		# (a Dragoon's horse while he fights on foot, a rider of ours close by who'll take it: it stays)
		if game.units_near(h.position, 6.0 * Defs.TILE).any(func(o: Unit) -> bool: return o.team == team and not o.dead and _wants_horse(o)):
			continue
		var hb: Building = brs[0]
		for b in brs:
			if b.center().distance_to(h.position) < hb.center().distance_to(h.position):
				hb = b
		h.cmd_move(game.approach_point(hb, h.position) + Vector2(randf_range(-24, 24), randf_range(-24, 24)))


var _loose_at := 0.0
var _catchers: Array = []        # men sent to catch a loose horse (they let it go once it's ours)


## Loose horses (nobody's: their riders fell, Unit._rider_falls). The Crown sends its
## nearest free man who can lead horses (an idle Labourer or soldier, a Labourer at work; not
## its groom) to catch one in its base or by its army, with no enemy close; a Clockwork
## Winder close by takes one; the Brood kills one near its creatures (cheap essence) with
## nobody to fight there, but doesn't chase them across the map.
func _loose_horses() -> void:
	# the ones caught: let go where they stand (strays are sent home: _horses)
	for u in _catchers.duplicate():
		if not is_instance_valid(u) or u.dead:
			_catchers.erase(u)
		elif u.order != "lead" and not u.queue.any(func(o: Dictionary) -> bool: return o["o"] == "lead"):
			if not u.led.is_empty():
				u.release_horses()
			_catchers.erase(u)
			if u.is_worker() and u.order == "idle":
				u.auto_work = true
	if game.clock < _loose_at:
		return
	_loose_at = game.clock + 2.0
	var fac := game.faction_of(team)
	if fac != "crown" and fac != "brood" and fac != "clockwork":
		return
	var T := Defs.TILE
	for h in game.units:
		if not Game.loose_horse(h) or h.off_field or h.bolt_t > 0.0:
			continue
		if h.claimed and is_instance_valid(h.claimed) and not h.claimed.dead and h.claimed.is_coming_for(h):
			continue                     # (someone's on his way to it)
		var near: Array = game.units_near(h.position, 9.0 * T)
		if near.any(func(o: Unit) -> bool: return not o.dead and game.hostile(o.team, team) and o.kind != "horse" \
				and o.position.distance_to(h.position) < 6.0 * T):
			continue                     # enemies there: not worth it
		if fac == "brood":
			var biter: Unit = null
			var bd := 8.0 * T
			for o in near:
				if o.team != team or o.dead or o.is_worker() or not o.has_attack() or not o.can_hit(h) or o.target != null \
						or not (o.order == "idle" or o.order == "hold") or _on_errand(o):
					continue
				var dd: float = o.position.distance_to(h.position)
				if dd < bd:
					bd = dd
					biter = o
			if biter:
				biter.cmd_attack(h)
			continue
		# the Crown: in its base, or by its army; the Clockwork: a Winder close by
		var reach := 6.0 * T
		if fac == "crown":
			reach = 16.0 * T
			var home := game.buildings.any(func(b: Building) -> bool: return b.team == team and not b.dead and b.edge_distance(h.position) < 12.0 * T)
			var by_army := near.any(func(o: Unit) -> bool: return o.team == team and not o.dead and not o.is_worker() and o.kind != "horse" \
				and o.position.distance_to(h.position) < 8.0 * T)
			if not home and not by_army:
				continue
		var best: Unit = null
		var bd2 := reach
		for o in game.units_near(h.position, reach):
			if o.team != team or o.dead or not o.can_lead() or o.is_hauler() or o.lead_count() > 0 or o.target != null \
					or o.keg or o.order == "keg" or _on_errand(o) or _catchers.has(o) or not Unit.horse_free_for(h, o):
				continue
			if fac == "clockwork" and o.kind != "winder":
				continue
			if not (o.order == "idle" or (o.is_worker() and o.order == "gather")):
				continue
			var dd: float = o.position.distance_to(h.position)
			if dd < bd2:
				bd2 = dd
				best = o
		if best and best.cmd_lead(h):
			_catchers.append(best)


## Guns and wagons at home with a single horse get a second one (from Normal up, with the
## gold for it): a free horse walks over and is hitched. Returns how many still want one.
func _team_up(horses: Array, keep: Dictionary) -> int:
	if difficulty < 1 or _gold() < 200:
		return 0
	var want := 0
	for g in game.army(team):
		if not Defs.HARNESSED.has(g.kind) or g.horse_count() != 1 or g.aboard:
			continue
		var hall: Building = game.nearest_hall(g.position, team)
		if hall == null or hall.edge_distance(g.position) > 16.0 * Defs.TILE:
			continue                       # (out in the field: not now)
		if horses.any(func(h: Unit) -> bool: return h.into == g):
			continue                       # one's on its way
		var h: Unit = null
		var bd := INF
		for o in horses:
			if keep.has(o) or o.leader != null or o.into != null or o.horse_rid != 0 or o.order == "move":
				continue
			var dd: float = o.position.distance_to(g.position)
			if dd < bd and dd < 30.0 * Defs.TILE:
				bd = dd
				h = o
		if h and game.hauler_serves(team):
			g.team_want = 2                  # (a hauler brings a spare: Game.haul_dispatch)
		elif h:
			h.walk_into(g)
			keep[h] = true
		else:
			want += 1
	return mini(want, 2)


## Horses are bought (Defs.UNITS.horse at a Horse Breeder): a spare (two during a Horseman
## rush) beyond the ones the Foundries and the guns' teams want, counting the free ones and
## the spares in the breeders' queues. (Recruits get theirs by themselves: Game.train.)
func _buy_horses(horses: Array, keep: Dictionary, need: int) -> void:
	var breeders := _mine("horse_breeder").filter(func(b: Building) -> bool: return b.built)
	if breeders.is_empty() or (_mine("barracks").is_empty() and _mine("foundry").is_empty() and not _rushing()):
		return
	# (unridden horses of ours standing about, or walking home to a breeder, are spares too:
	# none is bought while they're there; one a rider is on his way to isn't)
	var near := float(Defs.HORSES["near_breeder"]) * Defs.TILE
	var free := horses.filter(func(h: Unit) -> bool: return h.leader == null and h.into == null and not keep.has(h) and h.horse_rid == 0 \
		and not Unit._claim_live(h) and (h.order != "move" or breeders.any(func(b: Building) -> bool: return b.edge_distance(h.order_point) <= near))).size()
	var coming := 0
	for b in breeders:
		for i in b.queue.size():
			if b.queue[i] == "horse" and int(b.kit_at(i).get("rid", 0)) == 0:
				coming += 1
	var spare := 2 if _rushing() else 1
	if free + coming >= need + spare:
		return
	breeders.sort_custom(func(a: Building, b: Building) -> bool: return a.queue.size() < b.queue.size())
	var b: Building = breeders[0]
	if b.queue.size() < 2:
		game.train(b, "horse")


## Spare horses at home (beyond what the buildings want): idle Musketeers there mount up as
## Dragoons (up to a quarter of the line), and dismounted cavalry rides again.
func _mount_men(horses: Array, keep: Dictionary, need: int) -> void:
	var spare := horses.filter(func(h: Unit) -> bool: return h.leader == null and h.into == null and h.claimed == null and h.horse_rid == 0 and not keep.has(h))
	if spare.is_empty():
		return
	spare = spare.filter(func(h: Unit) -> bool: return not Unit._claim_live(h))   # (riders took theirs: _remount_riders)
	var army := game.army(team)
	if spare.size() <= need + 1:
		return
	var muskets := army.filter(func(u: Unit) -> bool: return u.kind == "musketeer").size()
	var dragoons := army.filter(func(u: Unit) -> bool: return u.kind == "dragoon" or (u.kind == "musketeer" and u.auto_mount)).size()
	var want := int((muskets + dragoons) / 4.0)
	for u in army:
		if dragoons >= want or spare.size() <= need + 1:
			break
		if u.kind != "musketeer" or u.auto_mount or u.order != "idle" or u.target != null or _on_errand(u) or game.nearest_hall(u.position, team) == null or game.nearest_hall(u.position, team).edge_distance(u.position) > 14.0 * Defs.TILE:
			continue
		var h: Unit = u.nearest_free_horse(10.0)
		if h and spare.has(h) and u.cmd_mount(h):
			spare.erase(h)
			dragoons += 1
			u.auto_mount = true         # (the computer's Dragoons always get back on to move)
