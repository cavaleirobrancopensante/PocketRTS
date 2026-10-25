extends SceneTree
## Sidings (Clockwork roster prototype): a rail vehicle meeting another head-on on a single track pulls into a free
## siding within a few cells and rejoins; with none near it passes through (no deadlock).
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
	var cells := CU.row(g, 0, 12)
	check("a straight 12-cell Line", cells.size() == 12, "%d" % cells.size())
	if cells.size() < 12:
		quit(1)
		return
	var a_pos := g.cell_center(cells[1])
	var b_pos := g.cell_center(cells[10])
	# 1. no siding: both pass through and arrive
	var a := CU.spawn(g, "plate_wagon", 0, a_pos)
	var b := CU.spawn(g, "plate_wagon", 0, b_pos)
	a.cmd_move(b_pos)
	b.cmd_move(a_pos)
	await CU.step(self, g, 14.0)
	check("without a siding they pass through and arrive", a.position.distance_to(b_pos) < 40.0 and b.position.distance_to(a_pos) < 40.0,
		"a %.0f from goal, b %.0f" % [a.position.distance_to(b_pos), b.position.distance_to(a_pos)])
	# 2. a siding mid-track
	var why := CwRail.toggle_siding(g, 0, cells[6])
	check("a siding can be built on a straight piece", why == "" and g.line_net.sidings.has(cells[6]), why)
	check("a second siding too close is refused", CwRail.toggle_siding(g, 0, cells[7]) != "")
	a.position = a_pos
	b.position = b_pos
	a.cmd_stop()
	b.cmd_stop()
	a.cmd_move(b_pos)
	b.cmd_move(a_pos)
	var used := {"v": false}
	var gold0 := float(g.players[0]["gold"])
	await CU.step(self, g, 16.0, func() -> void:
		if a.cw.has("sid") or b.cw.has("sid"):
			used["v"] = true)
	check("one of them pulled into the siding", used["v"])
	check("both arrived anyway", a.position.distance_to(b_pos) < 40.0 and b.position.distance_to(a_pos) < 40.0,
		"a %.0f b %.0f" % [a.position.distance_to(b_pos), b.position.distance_to(a_pos)])
	check("nobody is left parked", not a.cw.has("sid") and not b.cw.has("sid"))
	# 3. the siding can be taken away
	check("a tap on it again removes it", CwRail.toggle_siding(g, 0, cells[6]) == "" and not g.line_net.sidings.has(cells[6]))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
