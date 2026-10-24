extends SceneTree
## The computer's scout against walls and shooters (scripts/ai_scout.gd):
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_scout_threat.gd
##  1. a worker scout (Labourer, and a Brood Grub) held up by a gate/wall really damages it
##     (the old _blocker() asked unit.has_attack(), which is false for every worker)
##  2. a Musketeer covering the route: the scout backs out of range without being hit, stands
##     off watching, and the scout remembers the foe has shooters / foot soldiers
##  3. driven back again after it has proof of foot soldiers: it goes home
var main: Node
var g: Game
var ai: AI
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4242)
	main.start({"map": "greenhold", "seed": 4242, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	# 1: breaking a gate
	await _start()
	var sc: AIScout = ai.scout
	sc._foe = 1
	var at := Vector2(g.starts[1]) * Defs.TILE + Vector2(0, 300)
	var cell := Vector2i(at / Defs.TILE)
	var gate: Building = g._add_building("gate", 1, cell, true)
	for kind in ["labourer", "grub"]:
		var u: Unit = g._add_unit(kind, 0, gate.center() + Vector2(0, 40))
		sc.unit = u
		check(sc._blocker() == gate, "%s scout finds the gate blocking it" % kind)
		u.cmd_attack(gate)
		var hp0 := gate.hp
		await _frames(150)
		check(gate.hp < hp0, "%s scout really damages the gate (%.0f -> %.0f)" % [kind, hp0, gate.hp])
		u.take_damage(99999.0, null)
		await _frames(5)
		gate.hp = gate.max_hp
	sc.unit = null
	await _stop()

	# 2 and 3: a musketeer on the route
	await _start()
	sc = ai.scout
	await _frames(1)
	while g.clock < 120.0 and sc.state != "going":
		await physics_frame
	check(sc.state == "going" and sc.unit != null, "the scout is on the road")
	var u: Unit = sc.unit
	# a musketeer holding ground ahead of the scout, out of its sight but covering its path
	var dir: Vector2 = (sc._wps[0] - u.position).normalized()
	var mus: Unit = g._add_unit("musketeer", 1, u.position + dir * 330.0)
	mus.cmd_hold()
	var min_d := INF
	for i in 450:
		await physics_frame
		if sc.unit == null or u.dead:
			break
		min_d = minf(min_d, u.position.distance_to(mus.position))
	check(not u.dead, "the scout is not shot")
	check(u.hp >= u.max_hp, "it took no damage (%.0f of %.0f)" % [u.hp, u.max_hp])
	check(min_d > 190.0 + mus.radius + u.radius, "it never came into musket range (closest %.0f px)" % min_d)
	check(sc._flees >= 1 and not sc.standoff_log.is_empty(), "it backed out and chose a stand-off spot")
	check(sc.foe_ranged_seen and sc.foe_kinds_seen.has("musketeer"), "it remembers the enemy has musketeers")
	check(sc.proof_not_horse_rush(), "it knows the enemy has foot soldiers: not a horse rush")
	var spot: Vector2 = sc.standoff_log[0]
	check(spot.distance_to(mus.position) > 190.0 + 10.0 + 80.0, "the stand-off spot is outside the musket's range plus a margin (%.0f px)" % spot.distance_to(mus.position))
	check(sc._log_has_text("not a horse rush"), "what it learned is in the match log")
	var n := 0
	while sc._mode != "watch" and sc.state == "going" and n < 1500:
		await physics_frame
		n += 1
	check(sc._mode == "watch" or sc.state != "going", "it reaches the stand-off spot and watches (mode %s after %d frames)" % [sc._mode, n])
	# driven back again, now with proof: home
	if sc.unit != null and not u.dead:
		var m2: Unit = g._add_unit("musketeer", 1, u.position + Vector2(150, 0))
		m2.cmd_hold()
		await _frames(120)
		check(sc.state == "done", "driven back again with proof of foot soldiers, it goes home (state %s)" % sc.state)
	else:
		check(sc.state == "done", "the trip ended without losing the scout (state %s)" % sc.state)
	check(not u.dead, "and the scout is alive")
	await _stop()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
