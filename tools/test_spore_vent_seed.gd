extends SceneTree
## SEED VENT: the Brood capital and finished Spore Vents grow Spore Vents (no grub):
##   godot --headless --fixed-fps 30 --script res://tools/test_spore_vent_seed.gd
##  1. the capital seeds a vent: no grub lost, 90 paid, one at a time, finished after ~16 s, swamp grows
##  2. a finished vent seeds another (a chain)
##  3. an out-of-reach or off-swamp spot is refused; a grub-built vent is gone from the build list
##  4. ABANDON on a growing vent pays everything back
##  5. the Brood AI seeds a vent from its capital in a game
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4243, "slots": [
			{"who": "you", "faction": "brood", "colour": 1, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 0, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func unit(k: String, p: Vector2, team := 0) -> Unit:
	return g._add_unit(k, team, p)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _gold() -> int:
	return int(g.players[0]["gold"])


func _swamp_cells(team: int) -> int:
	var n := 0
	for v in g.swamp[team]:
		n += int(v)
	return n


func _run() -> void:
	g.explored.fill(1)
	g.players[0]["gold"] = 5000
	g.players[1]["gold"] = 5000
	var cost := int(Defs.BUILDINGS["spore_vent"]["cost"])
	var vt := float(Defs.BUILDINGS["spore_vent"]["time"])
	check(not Defs.FACTIONS["brood"]["build"].has("spore_vent"), "the grub's build list has no Spore Vent")
	var cap: Building = g.capital(0)
	check(cap != null and g.can_seed(0, cap), "the capital can seed")
	var grubs0: int = g.workers(0).size()
	var sw0 := _swamp_cells(0)
	var spot: Vector2i = g.find_seed_spot(0, cap, 4, 10, "far")
	check(spot.x >= 0, "a seed spot within reach of the capital")
	var g0 := _gold()
	var v1: Building = g.seed_vent(0, cap, spot)
	check(v1 != null and not v1.built and v1.seeded and not v1.ghost, "seeded: a vent is growing")
	check(_gold() == g0 - cost, "cost paid: %d" % (g0 - _gold()))
	check(g.workers(0).size() == grubs0, "no grub lost")
	check(g.seed_busy(cap) and g.seed_vent(0, cap, g.find_seed_spot(0, cap, 4, 10, "near")) == null, "a source grows one vent at a time")
	check(g.place_building(0, "spore_vent", spot, g.workers(0).slice(0, 1)) == null, "a grub can no longer build a vent")
	await wait(vt - 3.0)
	check(not v1.built, "not finished before its time")
	var done := await wait_for(func() -> bool: return v1.built, 6.0)
	check(done, "finished after about %d s" % int(vt))
	await wait(14.0)
	var sw1 := _swamp_cells(0)
	check(sw1 > sw0, "the swamp grew: %d -> %d cells" % [sw0, sw1])
	check(not g.seed_busy(cap), "the capital is free to seed again")

	# a finished vent seeds another: a chain
	check(g.can_seed(0, v1), "a finished vent can seed")
	var spot2: Vector2i = g.find_seed_spot(0, v1, 4, 10, "far")
	check(spot2.x >= 0, "a spot for the second vent")
	var v2: Building = g.seed_vent(0, v1, spot2)
	check(v2 != null and g.seed_busy(v1), "the vent seeds a second vent")
	check(g.seed_vent(0, v2, spot2) == null, "an unfinished vent can't seed")
	var done2 := await wait_for(func() -> bool: return v2.built, vt + 3.0)
	check(done2, "the second vent finishes")
	check(v2.center().distance_to(cap.center()) / Defs.TILE > 0.0, "(chained %.1f tiles from the capital)" % (v2.center().distance_to(cap.center()) / Defs.TILE))

	# refusals
	var far := Vector2i(-1, -1)
	var dry := Vector2i(-1, -1)
	var c0: Vector2i = g.cell_of(cap.center())
	for r in range(11, 16):
		for a in range(0, 360, 15):
			var c: Vector2i = c0 + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
			if g.in_map(c) and g.in_map(c + Vector2i(1, 1)) and g._footprint_open(c, Vector2i(2, 2)) and far.x < 0:
				far = c
	var dry_src: Building = cap
	for sb in [cap, v1, v2]:
		var sc: Vector2i = g.cell_of(sb.center())
		for dy in range(-10, 11):
			for dx in range(-10, 11):
				var c: Vector2i = sc + Vector2i(dx, dy)
				if dry.x >= 0 or Vector2(dx, dy).length() > 9.0 or not g.in_map(c + Vector2i(1, 1)) or not g._footprint_open(c, Vector2i(2, 2)):
					continue
				var wet := false
				for y in 2:
					for x in 2:
						if g.swamp[0][g.idx(c + Vector2i(x, y))] == 1:
							wet = true
				if not wet:
					dry = c
					dry_src = sb
	if far.x >= 0:
		var why: String = g.seed_problem(0, cap, far)
		check(why != "" and g.seed_vent(0, cap, far) == null, "a spot beyond 10 tiles is refused (%s)" % why)
	else:
		check(false, "found no open cell beyond reach to test")
	if dry.x >= 0:
		var why2: String = g.seed_problem(0, dry_src, dry)
		check(why2 != "" and g.seed_vent(0, dry_src, dry) == null, "a spot off the swamp is refused (%s)" % why2)
	else:
		print("SKIP  no dry cell within 10 tiles of the capital on this map")
	var g1 := _gold()
	check(g.seed_vent(0, cap, g.cell_of(cap.center())) == null and _gold() == g1, "a spot on the capital itself is refused, nothing paid")

	# cancel pays everything back
	var spot3: Vector2i = g.find_seed_spot(0, v2, 4, 10, "far")
	g1 = _gold()
	var v3: Building = g.seed_vent(0, v2, spot3)
	check(v3 != null and _gold() == g1 - cost, "a third vent is growing")
	await wait(3.0)
	g.abandon(v3)
	await wait(0.5)
	check(not is_instance_valid(v3) or v3.dead, "the abandoned vent is gone")
	check(_gold() >= g1, "ABANDON refunds all %d (%d / %d)" % [cost, _gold(), g1])
	check(not g.seed_busy(v2), "the source is free again")

	# the Brood AI seeds one from its capital
	var ai = null
	for a in g.ais:
		if a.team == 1:
			ai = a
	check(ai != null and ai._brood(), "a Brood computer is in the game")
	var cap1: Building = g.capital(1)
	var w1: int = g.workers(1).size()
	ai._no_room.erase("spore_vent")
	ai._spread_swamp()
	var vents: Array = g.buildings.filter(func(b: Building) -> bool: return b.team == 1 and b.kind == "spore_vent" and not b.dead)
	check(vents.size() == 1 and vents[0].seeded and g.seed_busy(cap1), "the computer seeded a vent from its capital")
	check(g.workers(1).size() == w1, "the computer lost no grub")
	var av: Building = vents[0] if not vents.is_empty() else null
	var adone := await wait_for(func() -> bool: return av != null and av.built, vt + 3.0)
	check(adone, "the computer's vent finishes")
	if av != null and av.built:
		# a second one chains from the vent (the capital is free too; the farthest source goes first)
		ai._no_room.erase("spore_vent")
		ai._spread_swamp()
		var vs2: Array = g.buildings.filter(func(b: Building) -> bool: return b.team == 1 and b.kind == "spore_vent" and not b.dead)
		check(vs2.size() == 2 and (g.seed_busy(av) or g.seed_busy(cap1)), "the computer seeds a second vent from a source")
	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
