extends SceneTree
## X from a gun at a cliff edge stays on the gun's level, and a line drawn with
## the mouse outside the window stays on the screen:
##   godot --headless --fixed-fps 30 --script res://tools/test_cliff_horse.gd
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
func _edges(limit: int) -> Array:
	var out: Array = []
	for y in range(6, g.H - 6):
		for x in range(6, g.W - 6):
			var c := Vector2i(x, y)
			if g.height[g.idx(c)] != 1 or g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var lo: Vector2i = c + d * 3
				var mid: Vector2i = c + d
				if g.height[g.idx(lo)] == 0 and g.solid[g.idx(lo)] == 0 and g.ramp[g.idx(lo)] == 0 and g.ramp[g.idx(mid)] == 0 and g.height[g.idx(c + d * 2)] == 0:
					out.append([c, d])
					break
			if out.size() >= limit:
				return out
	return out


func _run() -> void:
	var edges := _edges(60)
	check(edges.size() >= 1, "cliff edges found (%d)" % edges.size())
	var ok_cell: Array = []
	for e in edges:
		var cell: Vector2i = e[0]
		var d: Vector2i = e[1]
		# nothing of the low side's must see the shooter's cell beforehand
		ok_cell = [cell, d]
		break
	var cell: Vector2i = ok_cell[0]
	var d: Vector2i = ok_cell[1]
	var low_cell: Vector2i = cell + d * 3
	var shooter: Unit = g._add_unit("musketeer", 0, g.cell_center(cell))
	var idle: Unit = g._add_unit("musketeer", 0, g.cell_center(cell - d * 5) if g.height[g.idx(cell - d * 5)] == 1 else g.cell_center(cell + Vector2i(d.y, d.x) * 5))
	var target: Unit = g._add_unit("grub", 1, g.cell_center(low_cell))
	target.hold_fire = true
	shooter.hold_fire = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g._update_vis()
	var ic: Vector2 = idle.position
	check(not g.side_sees(1, shooter.position), "before any shot: the high ground shooter is hidden from the low side")
	check(not g.side_sees(1, ic), "an idle high ground unit is hidden")
	target.hp = 100000.0
	shooter.cmd_attack(target)
	var seen := false
	for i in 240:
		await physics_frame
		if g.side_sees(1, shooter.position):
			seen = true
			break
	check(seen, "after it fires, the low side sees the shooter")
	check(g.side_sees(1, ic) == false, "the idle unit on the plateau stays hidden")
	var far := cell - d * 6
	if g.in_map(far):
		check(not g.side_sees(1, g.cell_center(far)), "the rest of the plateau stays hidden")
	# stop shooting: hidden again after ~2 s
	shooter.cmd_stop() if shooter.has_method("cmd_stop") else shooter.stop_all()
	shooter.target = null
	await physics_frame
	var gone_after := -1.0
	var el := 0.0
	while el < 6.0:
		await physics_frame
		el += 1.0 / 30.0
		g._update_vis()
		if not g.side_sees(1, shooter.position):
			gone_after = el
			break
	check(gone_after > 0.0 and gone_after <= 2.6, "hidden again about 2 s after the last shot (%.2f s)" % gone_after)
	# a low-ground shooter: rules unchanged (the shot adds no reveal)
	g._shot_reveals.clear()
	var lo_shooter: Unit = g._add_unit("musketeer", 0, g.cell_center(low_cell + d * 2))
	var hi_target: Unit = g._add_unit("grub", 1, g.cell_center(cell))
	g.note_shot(lo_shooter, hi_target)
	check(g._shot_reveals.is_empty(), "a low ground shooter firing up reveals nothing")
	g.note_shot(lo_shooter, target)
	check(g._shot_reveals.is_empty(), "a low ground shooter firing at low ground reveals nothing")
	g.note_shot(idle, idle)
	check(g._shot_reveals.is_empty(), "no reveal on a friendly target")
	print("fog shot reveal: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
