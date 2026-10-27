extends SceneTree
## Shift + PATROL (and Shift with the other targeted commands: attack-move, repair, attack
## ground) queues behind the move the unit is on, as in StarCraft: it finishes the move, then
## patrols between the end of the move and the clicked point:
##   godot --headless --fixed-fps 30 --script res://tools/test_shift_patrol.gd
## Prints PASS / FAIL lines and "shift patrol: PASS" (exit 1 on a failure).
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


func _wait(sec: float, cond: Callable) -> void:
	var t0 := 0.0
	while t0 < sec and not cond.call():
		await physics_frame
		t0 += 1.0 / 30.0


## A click in `mode` at world point p, Shift held or not (as controls reads it at the click).
func _click(mode: String, p: Vector2, shift: bool) -> void:
	g.controls.mode = mode
	var xf: Transform2D = g.get_viewport().get_canvas_transform()
	g.controls._tap(xf * p, true, shift)


func _run() -> void:
	Settings.device = "pc"
	g.explored.fill(1)
	var start: Vector2 = g.cell_center(Vector2i(g.W / 2, g.H / 2))
	g.camera.position = start
	await physics_frame
	# ---- Shift + PATROL behind a move
	var u: Unit = g._add_unit("musketeer", 0, start)
	await physics_frame
	g.set_selection([u])
	var dest := start + Vector2(160, 0)
	var pp := start + Vector2(160, 160)
	g.group_move([u], dest, false, false)
	await physics_frame
	_click("patrol", pp, true)
	check(u.order == "move" and u.order_point.distance_to(dest) < 30.0, "Shift + PATROL leaves the move going (%s)" % u.order)
	check(u.queue.size() == 1 and String(u.queue[0]["o"]) == "patrol", "and queues the patrol behind it")
	check(g.controls.mode == "patrol", "the PATROL mode stays on while Shift is held")
	g.controls.cancel_mode()
	await _wait(20.0, func() -> bool: return u.patrol_a != Vector2.INF)
	check(u.patrol_a != Vector2.INF and u.patrol_a.distance_to(dest) < 40.0, "after the move he patrols from where it ended (%s)" % str(u.patrol_a))
	check(u.patrol_b.distance_to(pp) < 30.0, "to the clicked point")
	await _wait(20.0, func() -> bool: return u.position.distance_to(pp) < 30.0)
	await _wait(20.0, func() -> bool: return u.position.distance_to(dest) < 30.0)
	check(u.position.distance_to(dest) < 30.0 and u.patrol_a != Vector2.INF, "and walks back and forth between them")
	# a plain PATROL still replaces the move
	var u2: Unit = g._add_unit("musketeer", 0, start + Vector2(0, -120))
	await physics_frame
	g.set_selection([u2])
	g.group_move([u2], u2.position + Vector2(200, 0), false, false)
	await physics_frame
	_click("patrol", u2.position + Vector2(0, -100), false)
	check(u2.queue.is_empty() and u2.patrol_a != Vector2.INF, "a plain PATROL replaces the move at once")
	# ---- Shift + attack-move, repair, attack ground behind a move
	var u3: Unit = g._add_unit("musketeer", 0, start + Vector2(-200, 0))
	await physics_frame
	g.set_selection([u3])
	g.group_move([u3], u3.position + Vector2(0, 150), false, false)
	await physics_frame
	_click("attack", u3.position + Vector2(-150, 0), true)
	check(u3.order == "move" and u3.queue.size() == 1 and String(u3.queue[0]["o"]) == "amove", "Shift + attack-move queues")
	g.controls.cancel_mode()
	var gun: Unit = g._add_unit("cannon", 0, start + Vector2(-200, 200))
	await physics_frame
	g.set_selection([gun])
	g.group_move([gun], gun.position + Vector2(0, 120), false, false)
	await physics_frame
	_click("bombard", gun.position + Vector2(300, 0), true)
	check(gun.order == "move" and gun.queue.size() == 1, "Shift + ATTACK GROUND queues (%s, %d)" % [gun.order, gun.queue.size()])
	g.controls.cancel_mode()
	var lab: Unit = g._add_unit("labourer", 0, start + Vector2(200, -200))
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and not b.dead:
			hall = b
			break
	await physics_frame
	if hall:
		hall.hp = hall.max_hp * 0.5
		g.set_selection([lab])
		g.group_move([lab], lab.position + Vector2(0, 100), false, false)
		await physics_frame
		_click("repair", hall.center(), true)
		check(lab.order == "move" and lab.queue.size() == 1 and String(lab.queue[0]["o"]) == "repair", "Shift + REPAIR queues")
		g.controls.cancel_mode()
	print("shift patrol: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
