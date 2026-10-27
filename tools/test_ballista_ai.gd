extends SceneTree
## The gear-mode Clockwork COMPUTER and the SPRING BALLISTA (AI._ballista_want, AI._ballista_crew, Ballista.pick /
## ai_crew; scripts/ballista.gd): a Hard Clockwork with two Light Works and a working Escapement (a Mainspring meshing with
## it), cogs and Tension to spare, against a passive Crown. It lays a Heavy Works (0.14.85), trains a couple of Ballistas (a few, not a whole army of
## them), its escort Winders crew them, and a Ballista of its own aims at an armoured Cannon before a Musketeer, and at a
## gate before a lone Musketeer.
##   godot --headless --fixed-fps 30 --script res://tools/test_ballista_ai.gd
var main: Node
var g
var t := 0.0
var started := false
var fails := 0
const K := Defs.BALLISTA_KIND


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(91)
		main.start({"map": "greenhold", "seed": 91, "slots": [
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
	# (the Mainspring first, with room for the Escapement and the Heavy Works' big ring, as the computer places it:
	# AI._spring_spot; the Ballista is made at the Heavy Works since 0.14.85, which the computer lays itself)
	var spring: Building = null
	var rs: Array = GearEcon.room_spot_n(g, 0, "mainspring", [hall], [Defs.CW_TECH, Defs.CW_HEAVY])
	if int(rs[1]) >= 2:
		spring = g._add_building("mainspring", 0, rs[0], true)
		g.gear_net.solve()
	if spring == null:
		spring = _put("mainspring", hall)
	var esc: Building = _put(Defs.CW_TECH, spring) if spring else null
	while _mine(Defs.CW_WORKS).size() < 2:
		if _put(Defs.CW_WORKS, hall) == null:
			break
	for w in _mine(Defs.CW_WORKS):
		if g.gear_net.spring_for(w) == null:
			_put("mainspring", w)
	for i in 3:
		_put(Defs.CW_SUPPLY, hall)
	# (Winders to build with, as a real game has by now; the passive Crown's buildings cannot fall, so the match runs on)
	for i in 8:
		g._add_unit("winder", 0, g.cell_center(g.nearest_free(g.cell_of(hall.center() + Vector2(-140 + i * 36, 120)), 6)))
	for b in g.buildings:
		if b.team == 1:
			b.max_hp = 1.0e7
			b.hp = 1.0e7
	await physics_frame
	g.gear_net.solve()
	check("the computer's Escapement works", esc != null and g.gear_net.speed_mult(esc) > 0.0)
	g.clock = maxf(g.clock, 330.0)
	var ai = g.ais.filter(func(a) -> bool: return a.team == 0)[0]
	check("it wants a Ballista once its Escapement works", ai._ballista_want() >= 1, "%d" % ai._ballista_want())
	var waited := await _wait(func() -> bool: return not _mine(Defs.CW_HEAVY).is_empty(), 150.0)
	check("it lays a Heavy Works for it (0.14.85)", not _mine(Defs.CW_HEAVY).is_empty(), "%.0f s" % waited)
	waited = await _wait(func() -> bool: return not _units(K).is_empty(), 300.0)
	check("it trains a Spring Ballista", not _units(K).is_empty(), "%d after %.0f s" % [_units(K).size(), waited])
	waited = await _wait(func() -> bool: return _units(K).any(func(b: Unit) -> bool: return Ballista.crew_of(b).size() >= 1), 150.0)
	var crewed: Array = _units(K).filter(func(b: Unit) -> bool: return Ballista.crew_of(b).size() >= 1)
	check("its escort Winders crew it", not crewed.is_empty(), "%.0f s, crews %s" % [waited, str(_units(K).map(func(b: Unit) -> int: return Ballista.crew_of(b).size()))])
	check("not more crew than AI.BALLISTA_CREW", _units(K).all(func(b: Unit) -> bool: return Ballista.crew_of(b).size() <= AI.BALLISTA_CREW))
	await _wait(func() -> bool: return false, 60.0)
	check("a couple of Ballistas, not a whole army of them", _units(K).size() <= 3, "%d" % _units(K).size())
	# its own pick: an armoured Cannon before a Musketeer; a gate before a lone Musketeer
	var b: Unit = _units(K)[0]
	b.cmd_hold()
	var p: Vector2 = b.position
	var gun: Unit = g._add_unit("cannon", 1, g.cell_center(g.nearest_free(g.cell_of(p + Vector2(230, 30)), 5)))
	var mus: Unit = g._add_unit("musketeer", 1, g.cell_center(g.nearest_free(g.cell_of(p + Vector2(160, -20)), 5)))
	for o in [gun, mus]:
		o.auto_work = false
		o.max_hp = 5000.0
		o.hp = 5000.0
		o.cmd_hold()
	await _wait(func() -> bool: return false, 1.0)       # (the fog: they are seen)
	var pick: Entity = Ballista.pick(b, 300.0)
	check("its Ballista aims at the armoured Cannon first", pick == gun, str(pick.kind if pick else "none"))
	gun.take_damage(100000.0, null)
	await _wait(func() -> bool: return false, 0.3)
	var gate: Building = null
	for c in [Vector2i(5, 0), Vector2i(6, 1), Vector2i(5, -2), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6)]:
		var cc: Vector2i = g.cell_of(p) + c
		if g.is_free(cc):
			gate = g._add_building("gate", 1, cc, true)
			break
	if gate:
		g.side_sees(0, gate.center())
		pick = Ballista.pick(b, 300.0)
		check("and at a gate before a lone Musketeer", pick == gate, str(pick.kind if pick else "none"))
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
