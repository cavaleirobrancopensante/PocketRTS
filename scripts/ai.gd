class_name AI
extends Node
## Computer opponent: runs an economy, builds up, trains a mixed army and
## attacks in growing waves. Defends its buildings when they're hit.
## Difficulty: 0 easy, 1 normal, 2 hard.

var game: Game
var team := 1
var difficulty := 1

var _think := 0.0
var _attack_at := 14            # army supply needed for the next wave
var _attacking := false
var _wave_target := Vector2.ZERO
var _alarm_t := 0.0
var _saving := false             # holding gold back for an expansion


func _physics_process(delta: float) -> void:
	if game == null or game.over:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = [2.2, 1.2, 0.7][difficulty]
	_economy()
	_supply()
	_build_up()
	_produce()
	_army()


func _mine(kind: String) -> Array:
	return game.buildings.filter(func(b: Building) -> bool: return b.team == team and b.kind == kind and not b.dead)


func _labourers() -> Array:
	return game.workers(team)


func _f() -> Dictionary:
	return Defs.FACTIONS[game.faction_of(team)]


func _brood() -> bool:
	return game.faction_of(team) == "brood"


func _clock() -> bool:
	return game.faction_of(team) == "clockwork"


func _halls() -> Array:
	return _mine(_f()["hall"])


func _busy_building(kind: String) -> bool:
	return _mine(kind).any(func(b: Building) -> bool: return not b.built)


# ------------------------------------------------------------------ economy

func _economy() -> void:
	var labs := _labourers()
	var halls := _halls().filter(func(b: Building) -> bool: return b.built)
	var want: int
	if _clock():
		want = [3, 4, 5][difficulty] + _halls().size() - 1
		# Put a Drill Rig on every mine near our Clocktowers.
		for h in _halls():
			if not h.built:
				continue
			for m in game.mines:
				if m.rig == null and m.gold > 0 and m.center().distance_to(h.center()) < 430.0:
					var spot := game.rig_spot(m, team)
					if spot.x >= 0 and not _busy_building("drill_rig"):
						_construct("drill_rig", spot)
	elif _brood():
		var slots := 0
		for m in game.mines:
			if m.gold > 0 and game.mine_on_swamp(m, team):
				slots += Defs.FEEDERS_PER_MINE
		want = mini(slots + 2, [12, 24, 32][difficulty])
	else:
		want = mini([11, 16, 20][difficulty] * maxi(1, halls.size()), [14, 24, 30][difficulty])
	var worker: String = _f()["worker"]
	var queued := 0
	for h in halls:
		queued += h.queue.filter(func(k: String) -> bool: return k == worker).size()
	for h in halls:
		if labs.size() + queued < want and (h.uses_eggs() or h.queue.size() < 2):
			if game.train(h, worker) == "":
				queued += 1
	for u in labs:
		if u.order == "idle" and u.can_gather():
			var m := game.nearest_mine(u.position, team)
			if m:
				u.cmd_gather(m)


func _supply() -> void:
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team):
		return
	var used := game.supply_used(team)
	var sup: String = _f()["supply"]
	var prod := _halls().size() * 3 if _brood() else 3 * _mine("barracks").size() + 2 * _mine("foundry").size()
	if _clock():
		prod = 4 * _mine("assembly_works").size()
	var margin := 3 + prod
	if cap - used <= margin and not _busy_building(sup):
		_construct(sup)


func _build_up() -> void:
	var labs := _labourers().size()
	var t := game.clock
	var gold: int = game.players[team]["gold"]
	if _clock():
		var works := _mine("assembly_works").size()
		if works == 0 and t > [110.0, 70.0, 50.0][difficulty]:
			_construct("assembly_works")
		elif works == 1 and t > [600.0, 300.0, 220.0][difficulty] and gold > 300:
			_construct("assembly_works")
	elif _brood():
		if _mine("warren").is_empty() and labs >= [9, 7, 6][difficulty]:
			_construct("warren")
		if _mine("gorge_pit").is_empty() and game.requirement_met(team, "gorge_pit") and t > [480.0, 250.0, 190.0][difficulty]:
			_construct("gorge_pit")
	else:
		var barracks := _mine("barracks").size()
		if barracks == 0 and labs >= [10, 8, 7][difficulty]:
			_construct("barracks")
		elif barracks == 1 and t > [420.0, 200.0, 150.0][difficulty] and gold > 200:
			_construct("barracks")
		elif barracks == 2 and difficulty == 2 and t > 330.0 and gold > 300:
			_construct("barracks")
		if _mine("foundry").is_empty() and game.requirement_met(team, "foundry") and t > [480.0, 260.0, 200.0][difficulty]:
			_construct("foundry")
	# Expand to the natural once the main base is running (or running dry).
	var hall: String = _f()["hall"]
	var main_gold := 0
	for h in _halls():
		for m in game.mines:
			if m.center().distance_to(h.center()) < 420.0:
				main_gold += m.gold
	var running_low := main_gold < Defs.MINE_GOLD * 0.8
	var expand_t: float = [9999.0, 480.0, 360.0][difficulty] * (0.6 if _brood() else (0.55 if _clock() else 1.0))
	_saving = false
	if _halls().size() == 1 and (t > expand_t or running_low):
		var spot: Vector2i = game.expansions[team]
		if game.placement_problem(team, hall, spot) == "":
			if gold >= int(Defs.BUILDINGS[hall]["cost"]) + 50:
				_construct(hall, spot)
			elif _clock() and _threat() == Vector2.INF:
				_saving = true


func _construct(kind: String, at := Vector2i(-1, -1)) -> void:
	if game.players[team]["gold"] < int(Defs.BUILDINGS[kind]["cost"]):
		return
	if not game.requirement_met(team, kind):
		return
	var spot := at if at.x >= 0 else _find_spot(kind)
	if spot.x < 0:
		return
	# Brood: the grub is used up, so don't eat into a tiny economy.
	if _brood() and _labourers().size() <= 4 and kind != _f()["supply"]:
		return
	# Use the worker nearest the spot that isn't carrying gold home.
	var best: Unit = null
	var bd := INF
	var target := Vector2(spot) * Defs.TILE
	for u in _labourers():
		if u.order == "build":
			continue
		var dd: float = u.position.distance_to(target) + (200.0 if u.carrying > 0 else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best:
		game.place_building(team, kind, spot, [best])


func _find_spot(kind: String) -> Vector2i:
	var halls := _halls()
	if halls.is_empty():
		return Vector2i(-1, -1)
	var hall: Building = halls[0]
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hc := hall.center()
	# Mining lanes: don't build between a hall and its mines.
	var lanes: Array = []
	for h in halls:
		for m in game.mines:
			if m.center().distance_to(h.center()) < 420.0:
				lanes.append([h.center(), m.center()])
	var best := Vector2i(-1, -1)
	var bd := INF
	var c0 := hall.cell + hall.size / 2
	for y in range(c0.y - 20, c0.y + 21):
		for x in range(c0.x - 20, c0.x + 21):
			var cell := Vector2i(x, y)
			var center := (Vector2(cell) + Vector2(size) * 0.5) * Defs.TILE
			var dd := center.distance_to(hc)
			if dd < 150.0 or dd >= bd:
				continue
			if game.placement_problem(team, kind, cell) != "" or not _margin_free(cell, size):
				continue
			var blocked := false
			for ln in lanes:
				var q := Geometry2D.get_closest_point_to_segment(center, ln[0], ln[1])
				if q.distance_to(center) < 70.0 + size.x * 10.0:
					blocked = true
					break
			if blocked:
				continue
			best = cell
			bd = dd
	return best


func _margin_free(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				continue
			if not game.is_free(cell + Vector2i(x, y)):
				return false
	return true


# ------------------------------------------------------------------ army

func _produce() -> void:
	if _saving:
		return
	var army := game.army(team)
	if _clock():
		var walkers := army.filter(func(u: Unit) -> bool: return u.kind == "steam_walker").size()
		for w in _mine("assembly_works"):
			if w.built and w.queue.size() < 2:
				var k := "gearknight" if randf() < 0.5 else "bolt"
				if walkers * 5 < army.size() + 2 and game.can_train(w, "steam_walker") == "":
					k = "steam_walker"
					walkers += 1
				game.train(w, k)
		return
	if _brood():
		var brutes := army.filter(func(u: Unit) -> bool: return u.kind == "brute").size()
		for h in _halls():
			if not h.built:
				continue
			while h.eggs > 0:
				var k := "raptor" if randf() < 0.6 else "spitter"
				if game.requirement_met(team, "gorge_pit") and _mine("gorge_pit").any(func(b: Building) -> bool: return b.built) and brutes * 12 < army.size() + 6:
					k = "brute"
				if game.train(h, k) != "":
					break
				if k == "brute":
					brutes += 1
		return
	var cannons := army.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	for b in _mine("barracks"):
		if b.built and b.queue.size() < 2:
			var k := "musketeer" if randf() < 0.6 else "pikeman"
			game.train(b, k)
	for f in _mine("foundry"):
		if f.built and f.queue.size() < 1 and cannons * 4 < army.size() + 2:
			game.train(f, "cannon")


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
		# Labourers pitch in when the base is being overrun and there's no army.
		if army.size() < 3:
			for u in _labourers():
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
			return
		_wave_target = _enemy_base()
		for u in army:
			if u.order == "idle":
				u.cmd_move(_wave_target + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
	else:
		# Gather at a rally spot in front of the base.
		var hall: Array = _halls()
		if hall.is_empty():
			return
		var front: Vector2 = hall[0].center().lerp(_enemy_base(), 0.15)
		for u in army:
			if u.order == "idle" and u.position.distance_to(front) > 160.0:
				u.cmd_move(front + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)


func _threat() -> Vector2:
	for b in game.buildings:
		if b.team != team or b.dead:
			continue
		for u in game.units_near(b.center(), 330.0):
			if u.team != team and not u.dead:
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
