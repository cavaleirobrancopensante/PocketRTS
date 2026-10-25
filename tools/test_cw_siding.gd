extends SceneTree
## Two tracks and sidings (Clockwork roster prototype): head-on vehicles pass in their own lanes; a faster one queues behind a
## slower one in the same lane; a siding lets the slow one step aside so the fast one gets by (and rejoins).
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_siding.gd
const CU := preload("res://tools/cw_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := CU.make(root)
	await process_frame
	await process_frame
	CU.rich(g)
	var cells := CU.row(g, 0, 14)
	check("a straight 14-cell Line", cells.size() == 14, "%d" % cells.size())
	if cells.size() < 14:
		quit(1)
		return
	var a_pos := g.cell_center(cells[1])
	var b_pos := g.cell_center(cells[12])
	# 1. two tracks: vehicles going opposite ways pass each other, in lanes on opposite sides, without waiting
	var a := CU.spawn(g, "plate_wagon", 0, a_pos)
	var b := CU.spawn(g, "plate_wagon", 0, b_pos)
	a.cmd_move(b_pos)
	b.cmd_move(a_pos)
	var lane := {"a": 0.0, "b": 0.0}
	await CU.step(self, g, 12.0, func() -> void:
		var mid := (a.position.x + b.position.x) * 0.5
		if absf(a.position.x - b.position.x) < 30.0:
			lane["a"] = a.position.y - g.cell_center(cells[0]).y
			lane["b"] = b.position.y - g.cell_center(cells[0]).y)
	check("head-on vehicles pass and arrive", a.position.distance_to(b_pos) < 40.0 and b.position.distance_to(a_pos) < 40.0,
		"a %.0f from goal, b %.0f" % [a.position.distance_to(b_pos), b.position.distance_to(a_pos)])
	check("they passed in separate lanes (right-hand drive)", float(lane["a"]) > 2.0 and float(lane["b"]) < -2.0, "a %.1f b %.1f" % [lane["a"], lane["b"]])
	# 2. same way, same lane: a fast Work Car behind a slow Heavy Locomotive queues behind it (no siding, never ahead)
	var slow := CU.spawn(g, "heavy_loco", 0, g.cell_center(cells[3]))
	var fast := CU.spawn(g, "work_car", 0, g.cell_center(cells[1]))
	slow.cw["set"] = false
	slow.cmd_move(b_pos)
	fast.cmd_move(b_pos)
	var ahead := {"v": false}
	await CU.step(self, g, 4.0, func() -> void:
		if fast.position.x > slow.position.x + 2.0:
			ahead["v"] = true)
	check("the fast one queues behind the slow one in its lane", not ahead["v"] and fast.position.x < slow.position.x,
		"fast %.0f slow %.0f" % [fast.position.x, slow.position.x])
	# 3. a siding lets the slow one step aside so the fast one gets by
	var why := CwRail.toggle_siding(g, 0, cells[7])
	check("a siding can be built on a straight piece", why == "" and g.line_net.sidings.has(cells[7]), why)
	check("a second siding too close is refused", CwRail.toggle_siding(g, 0, cells[8]) != "")
	slow.position = g.cell_center(cells[2])
	fast.position = g.cell_center(cells[0])
	slow.cmd_stop()
	fast.cmd_stop()
	slow.cmd_move(b_pos)
	fast.cmd_move(b_pos)
	var used := {"v": false, "passed": false}
	await CU.step(self, g, 14.0, func() -> void:
		if slow.cw.has("sid"):
			used["v"] = true
		if fast.position.x > slow.position.x + 20.0:
			used["passed"] = true)
	check("the slow one pulled into the siding", used["v"])
	check("the fast one got past it", used["passed"])
	await CU.step(self, g, 12.0)
	check("nobody is left parked", not slow.cw.has("sid") and not fast.cw.has("sid"))
	# 4. the siding can be taken away
	check("a tap on it again removes it", CwRail.toggle_siding(g, 0, cells[7]) == "" and not g.line_net.sidings.has(cells[7]))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
