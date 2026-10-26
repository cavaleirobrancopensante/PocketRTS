extends SceneTree
## The gear-mode Clockwork COMPUTER and the air (AI._air, scripts/cw_air.gd): a Hard Clockwork with a working Escapement (a
## Mainspring meshing with it) and a Movement Works, cogs and Tension to spare, against a passive Crown. A Crown balloon
## shows itself over its base: it builds ONE Clock Aviary (meshing with a Mainspring: THE TENSION RULE; with no room by
## one it builds another Mainspring first) and trains Swifts against it (they kill it). Later, with no enemy
## flyer about, it researches TICKING OWL and morphs a Swift into a Ticking Owl where it is safe (its Swifts may be out with
## the army by then).
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_air_ai.gd
var main: Node
var g
var t := 0.0
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(77)
		main.start({"map": "ashford_crossing", "seed": 77, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
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
			if ai.team != 0:
				ai.process_mode = Node.PROCESS_MODE_DISABLED      # (a passive Crown)
		_run()
	return false


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _mine(kind: String) -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and b.kind == kind)


func _units(kind: String) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.kind == kind)


func _wait(cond: Callable, secs: float) -> float:
	var t0: float = g.clock
	while not cond.call() and g.clock - t0 < secs and not g.over:
		await physics_frame
	return g.clock - t0


## A finished building of `kind` meshing with `around`'s ring (or the hall's), linked.
func _put(kind: String, around: Building) -> Building:
	for deg in [0.0, 60.0, 120.0, 180.0, -60.0, -120.0, 30.0, 150.0, -30.0, -150.0, 90.0, -90.0]:
		var c := GearNet.ring_spot(g, 0, kind, around, deg, true)
		if c.x >= 0:
			var b: Building = g._add_building(kind, 0, c, true)
			g.gear_net.solve()
			return b
	return null


func _run() -> void:
	var hall: Building = _mine("clocktower")[0]
	g.players[0]["gold"] = 6000
	g.players[0]["tension"] = 1500.0
	# its tier 2, ready: a Movement Works, a Mainspring meshing with it and an Escapement meshing with the Mainspring (the AI's
	# own would come later; THE TENSION RULE: Tension is spent only where a Mainspring meshes)
	var works: Building = _mine(Defs.CW_WORKS)[0] if not _mine(Defs.CW_WORKS).is_empty() else _put(Defs.CW_WORKS, hall)
	var spring: Building = _mine("mainspring")[0] if not _mine("mainspring").is_empty() else null
	if spring == null and works != null:
		spring = _put("mainspring", works)
	if spring == null:
		spring = _put("mainspring", hall)
	var esc: Building = _put(Defs.CW_TECH, spring) if spring else null
	await physics_frame
	g.gear_net.solve()
	check("the computer's Escapement works (meshed with its Mainspring)", esc != null and g.gear_net.speed_mult(esc) > 0.0)
	# (its tech clock past the tier-2 point)
	g.clock = maxf(g.clock, 330.0)
	# a Crown balloon over its base, in sight
	var bal: Unit = g._add_unit("balloon", 1, hall.center() + Vector2(160, -60))
	bal.cmd_hold()
	var waited := await _wait(func() -> bool: return not _mine(Defs.CW_AIR).is_empty(), 60.0)
	check("seeing a flyer, it places a Clock Aviary", not _mine(Defs.CW_AIR).is_empty(), "%.0f s" % waited)
	waited = await _wait(func() -> bool: return _mine(Defs.CW_AIR).any(func(b: Building) -> bool: return b.built), 150.0)
	check("the Aviary is built", _mine(Defs.CW_AIR).any(func(b: Building) -> bool: return b.built), "%.0f s" % waited)
	var av_list := _mine(Defs.CW_AIR)
	check("only one Aviary", av_list.size() == 1, "%d" % av_list.size())
	await _wait(func() -> bool: return false, 1.0)
	if not av_list.is_empty():
		check("the Aviary is linked to its gear field", g.gear_net.is_linked(av_list[0]))
	waited = await _wait(func() -> bool: return _units(Defs.CUCKOO).size() >= 1, 90.0)
	check("it trains Swifts against the flyer", _units(Defs.CUCKOO).size() >= 1, "%d after %.0f s" % [_units(Defs.CUCKOO).size(), waited])
	waited = await _wait(func() -> bool: return bal.dead, 90.0)
	check("its Swifts bring the balloon down", bal.dead, "%.0f s" % waited)
	# later, the sky clear: TICKING OWL and a morph (its tech clock past the research point, more than 90 s since a flyer)
	g.clock = maxf(g.clock + 120.0, 1000.0)
	waited = await _wait(func() -> bool: return g.has_tech(0, "owl_morph"), 120.0)
	check("late, with no flyer about, it researches TICKING OWL", g.has_tech(0, "owl_morph"), "%.0f s" % waited)
	waited = await _wait(func() -> bool: return not _units(Defs.OWL).is_empty() or _units(Defs.CUCKOO).any(func(u: Unit) -> bool: return u.owl_t >= 0.0), 120.0)
	check("then it morphs a Swift into a Ticking Owl", not _units(Defs.OWL).is_empty() or _units(Defs.CUCKOO).any(func(u: Unit) -> bool: return u.owl_t >= 0.0),
			"%d owls, %d morphing" % [_units(Defs.OWL).size(), _units(Defs.CUCKOO).filter(func(u: Unit) -> bool: return u.owl_t >= 0.0).size()])
	await _wait(func() -> bool: return not _units(Defs.OWL).is_empty(), 30.0)
	check("an Owl comes out", not _units(Defs.OWL).is_empty())
	check("never more than one Aviary", _mine(Defs.CW_AIR).size() == 1)
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
