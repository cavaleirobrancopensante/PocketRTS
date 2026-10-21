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
	return STRATEGIES.get(strategy, STRATEGIES["balanced"]).get(key, STRATEGIES["balanced"].get(key))


func _ready() -> void:
	if not strategies_for(game.faction_of(team)).has(strategy):
		strategy = "balanced"
	_attack_at = int(_s("wave"))

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
var _no_room := {}              # economy kinds with no free spot, and when we looked


func _physics_process(delta: float) -> void:
	if game == null or game.over:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = [2.2, 1.2, 0.7, 0.4][difficulty]
	_workers()
	_econ_build()
	_supply()
	_build_up()
	_research()
	_produce()
	if difficulty >= 1 and _crown() and not peaceful:
		_raid()
		_balloon_drop()
	_army()
	if _crown():
		_tend_wagon()
	if difficulty >= 1:
		_abilities()
	if difficulty >= 2:
		_micro()


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
			cap += int(b.d["crew"])
	var fill: float = 0.75 if difficulty == 0 else 1.0
	var extra := 2
	if _brood():
		extra = 3          # grubs get used up as buildings
	elif _clock():
		extra = 1 + (2 if game.army(team).size() >= 4 else 0)   # builder + escorts
	var want := mini(int((cap * fill + extra) * float(_s("workers"))), 46 if difficulty >= 3 else _lv([16, 30, 40]))
	if _clock():
		# a base is saturated at ~13 Winders (Clocktower 4, 4-5 a Boiler): the rest of the
		# 80 supply is for the army
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


## Crown: farmers on spent soil walk over to fresh farms with room (a couple at a time);
## Brood: grubs on pits whose Hive's ground is spent, to pits on fresh ground.
func _move_off_tired_soil(labs: Array) -> void:
	var site_kind := "farm" if _crown() else "feeding_pit"
	var fresh := _mine(site_kind).filter(func(f: Building) -> bool: return f.built and f.soil_left() > 0.0 and f.crew.size() < int(f.d["crew"]))
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
		if to.crew.size() >= int(to.d["crew"]):
			fresh.erase(to)


func _econ_build() -> void:
	if _hall_reserve:
		return
	if _halls().filter(func(h: Building) -> bool: return h.built).is_empty():
		return
	_recycle_spent()
	var order: Array = []
	if _crown():
		# the second farm first (the start has one), then the mill; a new hall gets its two
		# farms before its mill, and they go on the freshest soil (see _econ_spot)
		order = ["farm", "powder_mill"]
		if game.econ_count(team, "powder_mill") == 0 and game.workers(team).size() < 8 and game.clock < 120.0:
			order.erase("powder_mill")      # (the first hands farm: gold for labourers first)
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
		if game.econ_count(team, kind) >= game.econ_limit(team, kind) or _busy_building(kind):
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


func _econ_spot(kind: String) -> Vector2i:
	var halls := _halls()
	var dep: String = Defs.DEPOSIT_FOR.get(kind, "")
	if kind == "farm" or kind == "feeding_pit":
		# farms (pits) go where the soil (the Hive's ground) is freshest: tired land pays a third
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.soil_left() > b.soil_left())
	elif dep != "":
		# a Mill (Crusher) goes by the freshest saltpetre (ore); by spent rock only if it's the first
		halls.sort_custom(func(a: Building, b: Building) -> bool: return game.site_left(a, dep) > game.site_left(b, dep))
		if game.econ_count(team, kind) > 0:
			halls = halls.filter(func(h: Building) -> bool: return game.site_left(h, dep) > 0.05)
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
	if cap - used <= margin and not _busy_building(sup):
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
	else:
		var barracks := _mine("barracks").size()
		if barracks == 0 and labs >= _lv([9, 8, 7]):
			_construct("barracks")
		elif barracks == 1 and (t > _lv([420.0, 200.0, 150.0]) or strategy == "rush") and gold > 150:
			_construct("barracks")
		elif barracks == 2 and difficulty >= 2 and t > _lv([9999.0, 9999.0, 330.0]) and gold > 300:
			_construct("barracks")
		if _mine("foundry").is_empty() and game.requirement_met(team, "foundry") and t > _lv([480.0, 260.0, 200.0]):
			_construct("foundry")
		if _mine("church").is_empty() and game.requirement_met(team, "church") and t > _lv([500.0, 280.0, 220.0]):
			_construct("church")
		if not _walled and t > _lv([300.0, 170.0, 120.0]) and gold >= 140:
			_wall_off()
	# Money in the bank: more production (and for the Brood, more Hives to lay eggs).
	if gold > 400 and not _saving:
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
	if _halls().size() == 1 and ((full and t > expand_t * 0.6) or t > expand_t):
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
	# the map's base sites, with their deposit lines
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
		score -= _deposit_value(c)
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
	var best := 0.0
	for h in _halls():
		if h.built:
			best = maxf(best, _land(h))
	return best if not _halls().is_empty() else 1.0


## What's left of what a hall lives on: its soil (Crown), its ground (Brood), the ore at its
## base site (Clockwork: none there counts as spent).
func _land(h: Building) -> float:
	# (Clockwork: its ore, or its Boilers' coal if that runs out first)
	return minf(game.site_left(h, "ore"), h.soil_left()) if _clock() else h.soil_left()


## How much a hall spot is worth for the deposits beside it, in tiles of walking: the
## Clockwork lives on ore, the Crown wants fresh saltpetre for powder, the Brood ignores them.
func _deposit_value(c: Vector2i) -> float:
	if _brood():
		return 0.0
	var mid := (Vector2(c) + Vector2(Defs.BUILDINGS[_f()["hall"]]["size"]) * 0.5) * Defs.TILE
	var left := game.site_left_at(mid, "ore" if _clock() else "saltpetre")
	return maxf(0.0, left) * (16.0 if _clock() else 6.0)


## Crown / Clockwork: a Mill (Crusher) by spent rock is pulled down when the limit leaves no
## room for one by a hall that still has fresh saltpetre (ore) and none working it.
func _recycle_spent() -> void:
	for kind in Defs.DEPOSIT_FOR:
		if Defs.BUILDINGS[kind]["faction"] != game.faction_of(team) or game.econ_count(team, kind) < game.econ_limit(team, kind):
			continue
		var dep: String = Defs.DEPOSIT_FOR[kind]
		var spent: Array = _mine(kind).filter(func(b: Building) -> bool: return b.built and game.deposit_left(b) <= 0.0)
		if spent.is_empty():
			continue
		for h in _halls():
			if not h.built or game.site_left(h, dep) < 0.15:
				continue
			var worked := _mine(kind).any(func(b: Building) -> bool: return game.deposit_left(b) > 0.0 and b.center().distance_to(h.center()) < 16.0 * Defs.TILE)
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
	var live := _halls().filter(func(h: Building) -> bool: return _land(h) > 0.0).size()
	if live >= int(_s("halls")) + (1 if macro else 0) or _halls().size() >= 7 or _busy_building(hall):
		return
	if _gold() < int(Defs.BUILDINGS[hall]["cost"]):
		return
	if not macro and not _brood():
		# a base site with fresh deposits first (the Clockwork lives on ore)
		var sp := _safe_hall_spot()
		if sp.x >= 0 and _deposit_value(sp) > 0.0:
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


## The tech step to the first ranged unit, as soon as there's a little money for it.
func _research() -> void:
	if _hall_reserve:
		return
	for key in Defs.RESEARCH:
		var info: Dictionary = Defs.RESEARCH[key]
		if info["faction"] != game.faction_of(team) or game.has_tech(team, key) or game.researching(team, key):
			continue
		if _gold() < int(info["cost"]) + _lv([150, 60, 20]):
			continue
		for b in _mine(info["at"]):
			if game.research_problem(b, key) == "":
				game.start_research(b, key)
				break
var _raiders: Array = []        # Crown: cuirassiers out hunting the enemy's workers
var _raid_home := 0.0


## Crown: up to four Cuirassiers ride out to hunt the enemy's workers and economy, the
## farther from the enemy's main the better (Brood grubs hauling from distant pits,
## undefended farms). They avoid armies and ride home to mend when badly hurt.
func _raid() -> void:
	_raiders = _raiders.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
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
	# the best prey: workers and economy buildings far from the enemy's main, few guards
	var their_main: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if game.starts.size() > foe else c
	var best := Vector2.INF
	var score := -INF
	for o in game.units:
		if o.dead or not game.hostile(o.team, team) or not o.is_worker() or not game.is_visible_to(team, o.position):
			continue
		var s: float = o.position.distance_to(their_main) - o.position.distance_to(c) * 0.5
		if s > score:
			score = s
			best = o.position
	if best == Vector2.INF:
		for b in game.buildings:
			if b.dead or not game.hostile(b.team, team) or not Defs.is_econ(b.kind):
				continue
			var s: float = b.center().distance_to(their_main) - b.center().distance_to(c) * 0.5
			if s > score:
				score = s
				best = b.center()
	if best == Vector2.INF:
		best = _enemy_base()
	for u in _raiders:
		if u.order == "idle" or (u.order == "amove" and u.order_point.distance_to(best) > 160.0 and u.target == null):
			u.cmd_move(best + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)


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
	for u in game.workers(team):
		if u.order == "build" or _escort.has(u):
			continue
		var dd: float = u.position.distance_to(target) + (0.0 if u.order == "idle" else 150.0) + (200.0 if u.carrying > 0 else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best:
		game.place_building(team, kind, spot, [best])


func _find_spot(kind: String) -> Vector2i:
	for h in _halls():
		if h.built:
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
				if game.clock > _lv([300.0, 200.0, 160.0]) or big >= 2:
					var r := randf()
					if tins < 6 + big or r < 0.15:
						k = "windup_soldier"
					elif arcs * 3 < big + 1 and game.can_train(w, "arc_thrower") == "":
						k = "arc_thrower"
					elif shields * 6 < big and game.can_train(w, "bulwark") == "":
						k = "bulwark"
					else:
						k = "thresher"
				if game.can_train(w, k) != "":
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
				elif game.can_train(h, "brute") == "" and brutes * 12 < army.size() + 6:
					k = "brute"
					brutes += 1
				elif game.can_train(h, "bloater") == "" and army.filter(func(u: Unit) -> bool: return u.kind == "bloater").size() * 10 < army.size() and randf() < 0.3:
					k = "bloater"
				elif game.can_train(h, "spore_mother") == "" and mothers * 14 < army.size():
					k = "spore_mother"
					mothers += 1
				if game.train(h, k) != "":
					break
		return
	var cannons := army.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	var short_powder := _res2() < 20.0
	for b in _mine("barracks"):
		if b.built and b.queue.size() < (3 if _gold() > 600 else 2):
			# (more musketeers while powder piles up: it's what the powder is for)
			var k := "musketeer" if randf() < (0.25 if short_powder else (0.75 if _res2() > 150.0 else 0.6)) and game.can_train(b, "musketeer") == "" else "pikeman"
			var horse := army.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size()
			if (horse < 3 or horse * 6 < army.size()) and randf() < 0.45 and game.can_train(b, "cuirassier") == "":
				k = "cuirassier"
			game.train(b, k)
	for f in _mine("foundry"):
		if f.built and f.queue.size() < (2 if _gold() > 600 else 1) and cannons * 4 < army.size() + 2 and not short_powder:
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


## Units busy with something of their own the army orders must leave alone: a balloon
## drop, an Ornithopter fetching or delivering a battery, a Bloater out of gas.
func _on_errand(u: Unit) -> bool:
	if u.order in ["courier", "overload", "board", "unload"]:
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
		for u in army:
			if u.order != "attack" and (u.target == null or u.order == "idle"):
				var best: Vector2 = threat
				for sp in spots:
					if u.position.distance_to(sp) < u.position.distance_to(best):
						best = sp
				u.cmd_move(best + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
		# Workers pitch in when the base is being overrun and there's no army.
		if army.size() < 3:
			for u in game.workers(team):
				if u.position.distance_to(threat) < 260.0 and u.order == "gather":
					u.cmd_move(threat, true)
		return
	# Clockwork: constructs running low on charge go back into a field first
	if _clock():
		var fields: Array = game.buildings.filter(func(b: Building) -> bool: return b.team == team and not b.dead and b.built and b.d.has("field"))
		for u in army:
			if u.wind < 0.3 and not u._in_field and not u.powered_down() and u.order != "move" and not fields.is_empty():
				var best: Building = fields[0]
				for f in fields:
					if f.center().distance_to(u.position) < best.center().distance_to(u.position):
						best = f
				u.cmd_move(best.center() + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		army = army.filter(func(u: Unit) -> bool: return u.wind >= 0.3 or u._in_field)
	var sup := _army_supply(army)
	var swarm_min := 10 if strategy in ["rush", "air"] else 30
	if _brood() and _attack_at < swarm_min:
		_attack_at = swarm_min     # a swarm waits until it's a swarm
	# timing attack: nothing goes out before the timing; then everything does, wave after wave
	if strategy == "timing" and game.clock >= float(_s("timing")) * (1.0 if difficulty >= 2 else 1.25) and _attack_at >= 999:
		_attack_at = 6
	if peaceful:
		_attack_at = 99999
	if _brood():
		_swarm_army(army, sup)
		return
	if not _attacking and sup >= _attack_at:
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + int(_s("step")), 70)
		if not game.demo and _foe() == game.human and randf() < 0.5:
			Sfx.taunt(game.faction_of(team))
		for u in army:
			u.cmd_move(_wave_target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	elif _attacking:
		if sup < 6:
			_attacking = false
			_release_escort()
			return
		_wave_target = _enemy_base()
		var wagon := _wagon() if _crown() else null
		for u in army:
			if u.order == "idle" and not (u.deploys() and u.tesla_mode == "deployed" and u.target):
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
		var front: Vector2 = hall[0].center().lerp(_enemy_base(), 0.15)
		for u in army:
			if u.order == "idle" and u.position.distance_to(front) > 160.0:
				u.cmd_move(front + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
			elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
				u.cmd_deploy()


## Brood: a swarm never walks into the guns in one lump. Each wave splits into groups
## that circle round to different sides of the target, wait until everyone is in place,
## and then all go in at once. Hatchlings that come out mid-attack wait at home for the
## next wave instead of trickling in one by one.
func _swarm_army(army: Array, sup: int) -> void:
	var hall: Array = _halls()
	var front: Vector2 = hall[0].center().lerp(_enemy_base(), 0.15) if not hall.is_empty() else game.center_of_team(team)
	# don't throw a small swarm at a much bigger army: wait until it's worth as much
	var mine := 0.0
	for u in army:
		mine += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	var theirs := 0.0
	var foe := _foe()
	if foe >= 0:
		for u in game.army(foe):
			theirs += float(u.d["cost"])
	var big_enough := mine >= theirs * 0.8 or sup >= 70 or strategy in ["rush", "air", "timing"]
	if _swarm_phase == "" and sup >= _attack_at and big_enough:
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + int(_s("step")), 70)
		if not game.demo and _foe() == game.human and randf() < 0.5:
			Sfx.taunt(game.faction_of(team))
		_plan_swarm(army)
		_swarm_phase = "flank"
		_swarm_t = 0.0
	elif _swarm_phase != "":
		_swarm_t += 1.0
		var alive := 0
		for g in _swarm:
			g[0] = (g[0] as Array).filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead and not _on_errand(u))
			alive += _army_supply(g[0])
		if alive < 6:
			_swarm_phase = ""
			_swarm.clear()
			_attacking = false
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
				# a few grubs follow the swarm to harvest the fallen
				var spare := game.workers(team).filter(func(u: Unit) -> bool: return u.kind == "grub" and u.order != "build" and u.cocoon == 0)
				var want_h := 2 if spare.size() > 10 else (1 if spare.size() > 6 else 0)
				var have := game.workers(team).filter(func(u: Unit) -> bool: return u.order == "harvest").size()
				for g2 in spare.slice(0, maxi(0, want_h - have)):
					g2.cmd_harvest()
					g2.harvest_home = (_swarm[0][1] as Vector2) if not _swarm.is_empty() else _wave_target
				for g in _swarm:
					for u in g[0]:
						u.cmd_move(_wave_target + Vector2(randf_range(-70, 70), randf_range(-70, 70)), true)
		else:
			_wave_target = _enemy_base()
			for g in _swarm:
				for u in g[0]:
					if u.order == "idle" and not (u.deploys() and u.tesla_mode == "deployed" and u.target):
						u.cmd_move(_wave_target + Vector2(randf_range(-70, 70), randf_range(-70, 70)), true)
	# everyone not in the wave gathers at home
	var in_wave := {}
	for g in _swarm:
		for u in g[0]:
			in_wave[u] = true
	for u in army:
		if in_wave.has(u):
			continue
		if u.order == "idle" and u.position.distance_to(front) > 160.0:
			u.cmd_move(front + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
		elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
			u.cmd_deploy()


## Split the army into groups (two or three, mixed: every group gets its share of
## raptors, spitters and brutes) and give each a spot on a different side of the target.
func _plan_swarm(army: Array) -> void:
	_swarm.clear()
	var target := _wave_target
	var home := game.center_of_team(team)
	var n := 1
	if army.size() >= 24:
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
	for g in _swarm:
		for u in g[0]:
			u.cmd_move(g[1] + Vector2(randf_range(-50, 50), randf_range(-50, 50)), false)


## Clockwork: two Winders walk behind the army and repair it (they repair whatever is
## hurt near them on their own when they stop).
func _follow_with_escort(army: Array) -> void:
	if army.is_empty():
		return
	var c := Vector2.ZERO
	for u in army:
		c += u.position
	c /= army.size()
	while _escort.size() < 2:
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
	# the army fights whatever is in the way on the walk there
	for b in game.buildings:
		if b.team == enemy and not b.dead and b.kind == game.faction_hall(enemy):
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best != Vector2.INF:
		return best
	for b in game.buildings:
		if b.team == enemy and not b.dead:
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best == Vector2.INF:
		return Vector2(game.starts[enemy]) * Defs.TILE
	return best


# ------------------------------------------------------------------ abilities (Normal and up)

## Bayonets when the powder runs dry; canister when a crowd closes on a cannon.
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
		if u.kind == "musketeer":
			# (out of powder they fix bayonets by themselves) fix them when the enemy is
			# already on top of us
			if difficulty >= 2:
				var close := 0
				for o in game.units_near(u.position, 40.0):
					if game.hostile(o.team, team) and not o.dead and float(o.d["range"]) < 50.0 and float(o.d["damage"]) > 0.0:
						close += 1
				u.set_bayonet(close >= 2)
		elif u.kind == "cannon":
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
		if u.order == "cast":
			continue
		if u.kind == "stormcaller" and u.charge >= float(Defs.STORM["cost"]):
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
			if best != Vector2.INF:
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
	for k in ["skywing", "bloater", "brute", "spore_mother", "spitter"]:
		var u: Dictionary = Defs.UNITS[k]
		var reqs: Array = u["requires"] if u.get("requires", "") is Array else [u["requires"]]
		if reqs.all(func(r: String) -> bool: return game._has_built(team, r)):
			want = maxi(want, int(u.get("cost2", 0)))
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
	_drop["t"] = float(_drop["t"]) + _think
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
		if b.team != foe or b.dead or not (Defs.is_econ(b.kind) or b.kind == game.faction_hall(foe)):
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
		if u.deploys() or u.d.get("medic", false) or _mending.has(u) or _on_errand(u):
			continue
		if brutal and u.hp < u.max_hp * 0.25 and int(u.d["supply"]) >= 2 and u.target:
			_mending[u] = true
			u.cmd_move(home + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
			continue
		if _kite.has(u):
			_kite[u] = float(_kite[u]) - _think
			if float(_kite[u]) <= 0.0:
				_kite.erase(u)
				u.cmd_move(_wave_target if _attacking else u.position, true)
			continue
		var reach: float = float(u.d["range"]) + u.radius + 30.0
		if brutal and float(u.d["range"]) >= 100.0 and u.cooldown > 0.4 and not u.is_air():
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
