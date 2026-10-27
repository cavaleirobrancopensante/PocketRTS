extends SceneTree
## The gear-mode Clockwork COMPUTER and tier 3 (AI._tier3, AI._produce; scripts/pendulum.gd, scripts/netter.gd): a Hard
## Clockwork with two Light Works, a working Escapement (a Mainspring meshing with it), six Springers (the Springers come
## first: 0.14.73), cogs and Tension to spare, against a passive Crown. It lays ONE Heavy Works (0.14.83) by a Mainspring, then mixes a few Pendulums (from it) and Netters
## into its army; a Netter of its own nets the most dangerous enemy that comes in reach (a Cuirassier before a Labourer
## with less health left: the focus fire of AI._micro leaves the Netters to their own pick).
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_tier3_ai.gd
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
		seed(91)
		main.start({"map": "ashford_crossing", "seed": 91, "slots": [
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
	g.players[0]["gold"] = 8000
	g.players[0]["tension"] = 2000.0
	# its tier 2, ready: two Light Works, a Mainspring and an Escapement meshing with it
	while _mine(Defs.CW_WORKS).size() < 2:
		if _put(Defs.CW_WORKS, hall) == null:
			break
	var spring: Building = _mine("mainspring")[0] if not _mine("mainspring").is_empty() else _put("mainspring", hall)
	var esc: Building = _put(Defs.CW_TECH, spring) if spring else null
	for i in 3:
		_put(Defs.CW_SUPPLY, hall)
	# (0.14.73: the Springers first: a Works goes on its big gear once three Springers are out and two Works may make them, or six
	# with one, AI._tier3; six Springers stand by here)
	for i in 6:
		g._add_unit(Defs.SPRINGER, 0, g.cell_center(g.nearest_free(g.cell_of(hall.center() + Vector2(-120 + i * 40, 160)), 6)))
	await physics_frame
	g.gear_net.solve()
	check("the computer's Escapement works (meshed with its Mainspring)", esc != null and g.gear_net.speed_mult(esc) > 0.0)
	check("it has two Light Works, both on the small gear", _mine(Defs.CW_WORKS).size() >= 2 and _mine(Defs.CW_WORKS).all(func(b: Building) -> bool: return not b.gear_big))
	g.clock = maxf(g.clock, 330.0)
	var waited := await _wait(func() -> bool: return not _mine(Defs.CW_HEAVY).is_empty(), 60.0)
	check("it lays a Heavy Works (0.14.83)", not _mine(Defs.CW_HEAVY).is_empty(), "%.0f s" % waited)
	check("only one", _mine(Defs.CW_HEAVY).size() == 1)
	waited = await _wait(func() -> bool: return _mine(Defs.CW_HEAVY).any(func(b: Building) -> bool: return b.built and g.gear_net.spring_for(b) != null), 150.0)
	check("its Heavy Works stands and meshes with a Mainspring", _mine(Defs.CW_HEAVY).any(func(b: Building) -> bool: return b.built and g.gear_net.spring_for(b) != null), "%.0f s" % waited)
	waited = await _wait(func() -> bool: return not _units(Defs.PENDULUM).is_empty() and not _units(Defs.NETTER).is_empty(), 200.0)
	check("it trains Pendulums", not _units(Defs.PENDULUM).is_empty(), "%d after %.0f s" % [_units(Defs.PENDULUM).size(), waited])
	check("and Netters", not _units(Defs.NETTER).is_empty(), "%d" % _units(Defs.NETTER).size())
	check("the Light Works stay on the small gear and never queued a Pendulum", _mine(Defs.CW_WORKS).all(func(b: Building) -> bool: return not b.gear_big and not b.queue.has(Defs.PENDULUM)))
	var army: Array = g.army(0)
	var others: int = army.filter(func(u: Unit) -> bool: return not (u.kind in [Defs.SPRINGER, Defs.PENDULUM, Defs.NETTER])).size()
	check("a few, not a whole army of them", _units(Defs.PENDULUM).size() <= 4 and _units(Defs.NETTER).size() <= 3,
			"%d Pendulums, %d Netters, %d others" % [_units(Defs.PENDULUM).size(), _units(Defs.NETTER).size(), others])
	# its Netter nets the most dangerous enemy in reach
	if not _units(Defs.NETTER).is_empty():
		var nt: Unit = _units(Defs.NETTER)[0]
		nt.cooldown = 0.0
		var p: Vector2 = nt.position
		var cav: Unit = g._add_unit("cuirassier", 1, g.cell_center(g.nearest_free(g.cell_of(p + Vector2(150, 40)), 5)))
		var lab: Unit = g._add_unit("labourer", 1, g.cell_center(g.nearest_free(g.cell_of(p + Vector2(90, -20)), 5)))
		lab.hp = 10.0
		for o in [cav, lab]:
			o.auto_work = false
			o.cmd_hold()
		waited = await _wait(func() -> bool: return cav.nets_taken > 0 or lab.nets_taken > 0, 12.0)
		check("its Netter nets the most dangerous enemy in reach (the Cuirassier)", cav.nets_taken > 0 and lab.nets_taken == 0,
				"cuirassier %d, labourer %d, %.1f s" % [cav.nets_taken, lab.nets_taken, waited])
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
