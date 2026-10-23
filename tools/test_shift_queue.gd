extends SceneTree
## A Shift-queued instant command (RELEASE HORSE) runs only after the move before it:
##   godot --headless --fixed-fps 30 --script res://tools/test_shift_queue.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
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


## High-ground cells with a free cliff-side neighbour two tiles away on the low ground:
## [cell, direction towards the low ground].
func _run() -> void:
	g.explored.fill(1)
	var start: Vector2 = g.cell_center(Vector2i(g.W / 2, g.H / 2))
	var gun: Unit = g._add_unit("cannon", 0, start)
	await physics_frame
	check(gun.harnessed, "the gun starts with a horse")
	var dest := start + Vector2(260, 0)
	gun.give({"o": "move", "p": dest}, false)
	gun.give({"o": "act", "fn": func(m: Unit) -> void: m.release_horse()}, true)
	check(gun.harnessed, "queued RELEASE HORSE waits while the gun is moving")
	var t0 := 0.0
	while t0 < 40.0 and gun.order != "idle":
		await physics_frame
		t0 += 1.0 / 30.0
	await physics_frame
	check(not gun.harnessed, "the horse is released after the move")
	check(gun.position.distance_to(dest) < 60.0, "and the gun got there first (%.0f px away)" % gun.position.distance_to(dest))
	# idle: a queued command runs at once
	var gun2: Unit = g._add_unit("cannon", 0, start + Vector2(0, 120))
	await physics_frame
	gun2.give({"o": "act", "fn": func(m: Unit) -> void: m.release_horse()}, true)
	check(not gun2.harnessed, "queued on an idle gun it runs at once")
	# REFIT: paid at once, back where he was sent from when fitted, paid back if killed on the way
	var armoury: Building = g._add_building("armoury", 0, Vector2i(g.W / 2 + 8, g.H / 2 + 8), true) if g.has_method("_add_building") else null
	g.players[0]["tech"]["pouch"] = true
	g.players[0]["tech"]["bayonet"] = true
	if armoury != null:
		var m: Unit = g._add_unit("musketeer", 0, start + Vector2(0, 240))
		await physics_frame
		var gold0: int = int(g.players[0]["gold"])
		var home := m.position
		var r: Array = g.refit_order([m], "pouch")
		check(r[0] == 1 and int(g.players[0]["gold"]) < gold0, "the refit fee is paid at once")
		var t1 := 0.0
		while t1 < 90.0 and not m.pouch:
			await physics_frame
			t1 += 1.0 / 30.0
		check(m.pouch, "he got the Shot Pouch")
		t1 = 0.0
		while t1 < 40.0 and m.position.distance_to(home) > 60.0:
			await physics_frame
			t1 += 1.0 / 30.0
		check(m.position.distance_to(home) <= 60.0, "and walked back to where he was sent from (%.0f px)" % m.position.distance_to(home))
		var m2: Unit = g._add_unit("musketeer", 0, start + Vector2(0, 300))
		await physics_frame
		var gold1: int = int(g.players[0]["gold"])
		g.refit_order([m2], "bayonet")
		var paid: bool = int(g.players[0]["gold"]) < gold1
		m2.take_damage(99999.0, null) if m2.has_method("take_damage") else g.consume_unit(m2)
		await physics_frame
		check(paid and int(g.players[0]["gold"]) == gold1, "killed on the way: the fee is refunded")
	print("shift queue: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
