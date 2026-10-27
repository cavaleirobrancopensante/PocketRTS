extends SceneTree
## A man getting on or off a horse, and a gun limbering or unlimbering, stays selected, in its
## control groups, clickable and box-selectable all the while; an order given meanwhile is
## carried out once he is in the saddle (or on foot), a Shift-queued one after it:
##   godot --headless --fixed-fps 30 --script res://tools/test_mount_select.gd
## Prints PASS / FAIL lines and "mount select: PASS" (exit 1 on a failure).
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


## Where the player sees the unit: its sprite's middle on screen (world coordinates).
func _seen_at(u: Unit) -> Vector2:
	return u.position + (u.sprite.position if u.sprite else Vector2.ZERO) + Vector2(0, -12)


## A click on what is drawn, and a small box dragged over it (through the view's transform).
func _clicks_to(u: Unit) -> bool:
	return g.entity_at(_seen_at(u)) == u


func _box_gets(u: Unit) -> bool:
	var xf: Transform2D = g.get_viewport().get_canvas_transform()
	var c: Vector2 = xf * _seen_at(u)
	g.set_selection([])
	g.controls._box_from = c - Vector2(14, 14)
	g.controls._box_to = c + Vector2(14, 14)
	g.controls._finish_box(false)
	return g.selection.has(u)


func _wait(sec: float, cond: Callable) -> void:
	var t0 := 0.0
	while t0 < sec and not cond.call():
		await physics_frame
		t0 += 1.0 / 30.0


## Open, level ground w x h cells, away from the start bases (as tools/test_mount_anim.gd).
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


func _run() -> void:
	g.explored.fill(1)
	g.reveal = true
	var o := _open_area(24, 16)
	var start: Vector2 = g.cell_center(o + Vector2i(14, 6))
	g.camera.position = start
	await physics_frame
	# ---- mounting
	var m: Unit = g._add_unit("dismounted", 0, start)
	var h: Unit = g._add_unit("horse", 0, start + Vector2(70, 0))
	await physics_frame
	g.set_selection([m])
	g.groups[1] = [m]
	check(m.cmd_mount(h), "he goes for the horse")
	await _wait(10.0, func() -> bool: return m.work == "mounting")
	check(m.work == "mounting", "he is getting on")
	await physics_frame
	await physics_frame
	check(g.selection.has(m) and m.selected, "still selected while getting on")
	check(g.groups[1].has(m), "still in his control group while getting on")
	check(_clicks_to(m), "a click on him while he gets on picks him (not the hidden horse)")
	check(_box_gets(m), "a box over him while he gets on picks him")
	g.set_selection([m])
	var dest := start + Vector2(0, 200)
	var dest2 := start + Vector2(200, 200)
	m.give({"o": "move", "p": dest}, false)
	m.give({"o": "move", "p": dest2}, true)
	check(m.work == "mounting" and m.order == "mount", "an order given while he gets on doesn't call it off")
	await _wait(10.0, func() -> bool: return m.is_mounted())
	check(m.is_mounted(), "he got on")
	check(g.selection.has(m) and g.groups[1].has(m), "and is still selected and grouped")
	check(m.order == "move" and m.order_point.distance_to(dest) < 40.0, "then rides off to the spot ordered meanwhile (%s)" % m.order)
	check(m.queue.size() == 1, "with the Shift-queued move still behind it (%d)" % m.queue.size())
	await _wait(20.0, func() -> bool: return m.order == "idle")
	check(m.position.distance_to(dest2) < 60.0, "and rode on to the queued spot (%.0f px off)" % m.position.distance_to(dest2))
	# ---- dismounting
	m.cmd_dismount()
	await physics_frame
	check(m.work == "dismounting", "he is getting off")
	check(g.selection.has(m) and g.groups[1].has(m), "still selected and grouped while getting off")
	check(_clicks_to(m), "a click on him while he gets off picks him")
	g.set_selection([m])
	var dest3: Vector2 = m.position + Vector2(-150, 0)
	m.give({"o": "move", "p": dest3}, false)
	check(m.work == "dismounting", "an order given while he gets off doesn't call it off")
	await _wait(10.0, func() -> bool: return not m.is_mounted())
	await physics_frame
	check(not m.is_mounted() and m.order == "move" and m.order_point.distance_to(dest3) < 40.0, "on foot he walks to the spot ordered meanwhile")
	check(g.selection.has(m) and g.groups[1].has(m), "and is still selected and grouped")
	# ---- limbering
	var gun: Unit = g._add_unit("cannon", 0, start + Vector2(-300, -150))
	await physics_frame
	gun.tesla_mode = "deployed"
	g.set_selection([gun])
	g.groups[2] = [gun]
	gun.cmd_pack()
	await physics_frame
	check(gun.tesla_mode == "packing", "the gun limbers")
	check(g.selection.has(gun) and g.groups[2].has(gun), "still selected and grouped while limbering")
	check(_clicks_to(gun), "a click on it while it limbers picks it")
	check(_box_gets(gun), "a box over it while it limbers picks it")
	g.set_selection([gun])
	var gd: Vector2 = gun.position + Vector2(0, 160)
	gun.give({"o": "move", "p": gd}, false)
	await _wait(20.0, func() -> bool: return gun.order == "idle")
	check(gun.position.distance_to(gd) < 60.0, "and it rolls to the spot ordered while limbering")
	gun.cmd_deploy()
	await physics_frame
	check(gun.tesla_mode == "deploying" and g.selection.has(gun) and _clicks_to(gun), "unlimbering: still selected and clickable")
	print("mount select: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
