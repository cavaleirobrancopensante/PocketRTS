class_name AI
extends Node
## Computer opponent. Runs its faction's own economy (crews every economy structure,
## builds up to its limits and expands when they're full), techs up, trains a mixed army,
## attacks in growing waves and defends when its buildings are hit.
## Difficulty: 0 easy, 1 normal, 2 hard.

var game: Game
var team := 1
var difficulty := 1

var _think := 0.0
var _attack_at := 14            # army supply needed for the next wave
var _attacking := false
var _wave_target := Vector2.ZERO
var _saving := false            # holding gold back for an expansion
var _escort: Array = []         # Clockwork: Winders that follow the army to repair it
var _reserve := 0               # gold held back for the next economy structure
var _no_room := {}              # economy kinds with no free spot, and when we looked


func _physics_process(delta: float) -> void:
	if game == null or game.over:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = [2.2, 1.2, 0.7][difficulty]
	_workers()
	_econ_build()
	_supply()
	_build_up()
	_produce()
	_army()
	if _clock():
		_energy_split()


# ------------------------------------------------------------------ helpers

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
	var fill: float = [0.75, 1.0, 1.0][difficulty]
	var extra := 2
	if _brood():
		extra = 3          # grubs get used up as buildings
	elif _clock():
		extra = 1 + (2 if game.army(team).size() >= 4 else 0)   # builder + escorts
	var want := mini(int(cap * fill) + extra, [16, 30, 40][difficulty])
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


func _econ_build() -> void:
	if _halls().filter(func(h: Building) -> bool: return h.built).is_empty():
		return
	var order: Array = []
	if _crown():
		order = ["farm", "powder_mill"] if game.econ_count(team, "farm") >= 2 else ["farm"]
	elif _brood():
		order = ["feeding_pit"]
		if game.clock > [300.0, 200.0, 150.0][difficulty] or not _mine("warren").is_empty():
			order.append("bone_midden")
	else:
		order = ["boiler"]
		# a crusher once the energy on ore would overflow the ones we have
		var crushers := _mine("ore_crusher").size()
		var split: Array = game.players[team]["split"]
		if game.energy[team] * float(split[0]) * Defs.ORE_PER_ENERGY > crushers * Defs.CRUSHER_CAP * 0.8 or crushers == 0:
			order.push_front("ore_crusher")
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
	for h in _halls():
		if not h.built:
			continue
		var spot: Vector2i
		if kind == "feeding_pit":
			# far from the Hive pays more; stay on our side of the map
			spot = game.find_spot(team, kind, h, 7, 26, "far_safe")
		elif kind == "bone_midden":
			spot = game.find_spot(team, kind, h, 3, 12, "near")
		else:
			spot = game.find_spot(team, kind, h, 4, Defs.ECON_RANGE - 2, "near")
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
	elif _attacking or game.clock > [600.0, 420.0, 360.0][difficulty]:
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
		prod = 6 * _mine("assembly_works").size()
	var margin := 3 + prod
	if cap - used <= margin and not _busy_building(sup):
		_construct(sup)


func _build_up() -> void:
	var labs := game.workers(team).size()
	var t := game.clock
	var gold := _gold()
	if _clock():
		var works := _mine("assembly_works").size()
		if works == 0 and t > [110.0, 70.0, 50.0][difficulty]:
			_construct("assembly_works")
		elif works == 1 and t > [600.0, 300.0, 220.0][difficulty] and gold > 300:
			_construct("assembly_works")
		if works > 0 and _mine("charging_pylon").is_empty() and t > [520.0, 280.0, 220.0][difficulty]:
			_construct("charging_pylon")
	elif _brood():
		if _mine("warren").is_empty() and labs >= [8, 7, 6][difficulty]:
			_construct("warren")
		if _mine("gorge_pit").is_empty() and game.requirement_met(team, "gorge_pit") and t > [480.0, 250.0, 190.0][difficulty]:
			_construct("gorge_pit")
		if _mine("roost").is_empty() and game.requirement_met(team, "roost") and t > [560.0, 320.0, 260.0][difficulty]:
			_construct("roost")
	else:
		var barracks := _mine("barracks").size()
		if barracks == 0 and labs >= [9, 8, 7][difficulty]:
			_construct("barracks")
		elif barracks == 1 and t > [420.0, 200.0, 150.0][difficulty] and gold > 200:
			_construct("barracks")
		elif barracks == 2 and difficulty == 2 and t > 330.0 and gold > 300:
			_construct("barracks")
		if _mine("foundry").is_empty() and game.requirement_met(team, "foundry") and t > [480.0, 260.0, 200.0][difficulty]:
			_construct("foundry")
		if _mine("church").is_empty() and game.requirement_met(team, "church") and t > [500.0, 280.0, 220.0][difficulty]:
			_construct("church")
	# Floating money: more production.
	if gold > 550 and not _saving and _threat() == Vector2.INF:
		if _crown() and _mine("barracks").size() < 4 and not _busy_building("barracks") and not _mine("barracks").is_empty():
			_construct("barracks")
		elif _clock() and _mine("assembly_works").size() < 3 and not _busy_building("assembly_works") and not _mine("assembly_works").is_empty():
			_construct("assembly_works")
	# Expand once our economy structures are all up (a new hall brings more slots).
	var hall: String = _f()["hall"]
	var full := true
	for kind in _f()["econ"]:
		if game.econ_count(team, kind) < game.econ_limit(team, kind):
			full = false
	var expand_t: float = [9999.0, 420.0, 330.0][difficulty] * (0.7 if _brood() else 1.0)
	_saving = false
	if _halls().size() == 1 and ((full and t > expand_t * 0.6) or t > expand_t):
		var spot: Vector2i = game.expansions[team]
		if game.placement_problem(team, hall, spot, true) == "":
			if gold >= int(Defs.BUILDINGS[hall]["cost"]) + 50:
				_construct(hall, spot)
			elif _threat() == Vector2.INF:
				_saving = true


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
	if _saving or (_reserve > 0 and _gold() < _reserve + 60):
		return
	var army := game.army(team)
	if _clock():
		var walkers := army.filter(func(u: Unit) -> bool: return u.kind == "steam_walker").size()
		var carts := army.filter(func(u: Unit) -> bool: return u.kind == "tesla_cart").size()
		for w in _mine("assembly_works"):
			if w.built and w.queue.size() < 2:
				var k := "gearknight" if randf() < 0.5 else "bolt"
				if walkers * 5 < army.size() + 2 and game.can_train(w, "steam_walker") == "":
					k = "steam_walker"
					walkers += 1
				elif carts * 6 < army.size() and game.can_train(w, "tesla_cart") == "":
					k = "tesla_cart"
					carts += 1
				game.train(w, k)
		return
	if _brood():
		var brutes := army.filter(func(u: Unit) -> bool: return u.kind == "brute").size()
		var wings := army.filter(func(u: Unit) -> bool: return u.kind == "skywing").size()
		for h in _halls():
			if not h.built:
				continue
			while h.eggs > 0:
				var k := "raptor" if randf() < 0.6 else "spitter"
				if game.can_train(h, "brute") == "" and brutes * 12 < army.size() + 6:
					k = "brute"
					brutes += 1
				elif game.can_train(h, "skywing") == "" and wings * 6 < army.size():
					k = "skywing"
					wings += 1
				if game.train(h, k) != "":
					break
		return
	var cannons := army.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	var short_powder := _res2() < 20.0
	for b in _mine("barracks"):
		if b.built and b.queue.size() < 2:
			var k := "musketeer" if randf() < (0.25 if short_powder else 0.6) else "pikeman"
			game.train(b, k)
	for f in _mine("foundry"):
		if f.built and f.queue.size() < 1 and cannons * 4 < army.size() + 2 and not short_powder:
			game.train(f, "cannon")
	for c in _mine("church"):
		if c.built and c.queue.is_empty() and game.can_train(c, "missionary") == "":
			game.train(c, "missionary")


func _army_supply(list: Array) -> int:
	var n := 0
	for u in list:
		n += int(u.d["supply"])
	return n


func _army() -> void:
	var army := game.army(team)
	# Defend: enemies near our buildings get everyone's attention.
	var threat := _threat()
	if threat != Vector2.INF:
		for u in army:
			if u.order != "attack" and (u.target == null or u.order == "idle"):
				u.cmd_move(threat + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
		# Workers pitch in when the base is being overrun and there's no army.
		if army.size() < 3:
			for u in game.workers(team):
				if u.position.distance_to(threat) < 260.0 and u.order == "gather":
					u.cmd_move(threat, true)
		return
	var sup := _army_supply(army)
	if _brood() and _attack_at < 22:
		_attack_at = 22     # a swarm waits until it's a swarm
	if not _attacking and sup >= _attack_at:
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + [6, 8, 10][difficulty], 70)
		for u in army:
			u.cmd_move(_wave_target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	elif _attacking:
		if sup < 6:
			_attacking = false
			_release_escort()
			return
		_wave_target = _enemy_base()
		for u in army:
			if u.order == "idle" and not (u.kind == "tesla_cart" and u.tesla_mode == "deployed" and u.target):
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
			elif u.kind == "tesla_cart" and u.order == "idle" and u.tesla_mode == "packed":
				u.cmd_deploy()


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
	for u in _escort:
		if u.order == "repair":
			continue
		if u.position.distance_to(c) > 140.0:
			u.cmd_move(c + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


func _release_escort() -> void:
	for u in _escort:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	_escort.clear()


func _threat() -> Vector2:
	for b in game.buildings:
		if b.team != team or b.dead:
			continue
		for u in game.units_near(b.center(), 330.0):
			if u.team != team and not u.dead and not u.off_field:
				return u.position
	return Vector2.INF


func _enemy_base() -> Vector2:
	var enemy := 1 - team
	var best := Vector2.INF
	var bd := INF
	var me := game.center_of_team(team)
	for b in game.buildings:
		if b.team == enemy and not b.dead:
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best == Vector2.INF:
		return Vector2(game.starts[enemy]) * Defs.TILE
	return best
