extends SceneTree
## Tin Militia (Clockwork roster prototype): batches of four, only within a few tiles of the Line: orders are cut at the
## edge of that ground, a militia pushed out is pulled back, targets beyond are refused.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_militia.gd
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
	var n0 := g.units.filter(func(u: Unit) -> bool: return u.kind == "tin_militia").size()
	var b := CU.U.building_beside(g, 0, "assembly_works", cells[2])
	check("an Assembly Works beside the Line", b != null)
	var why: String = g.can_train(b, "tin_militia") if b != null else "no building"
	check("the Assembly Works trains Tin Militia", Defs.BUILDINGS["assembly_works"]["trains"].has("tin_militia") and why == "", why)
	var leash := CwUnits.leash()
	var m := CU.spawn(g, "tin_militia", 0, g.cell_center(cells[6]) + Vector2(0, 40))
	check("the unit data says four to an order", int(Defs.UNITS["tin_militia"]["spawn"]) == 4)
	# 1. an order far from the Line is cut at the edge
	var far := g.cell_center(cells[6]) + Vector2(0, 30 * 32)
	m.cmd_move(far)
	await CU.step(self, g, 14.0)
	var d := CwUnits.line_dist(g, 0, g.cell_of(m.position))
	check("an order far from the Line stops at the leash", d <= leash and d >= leash - 3, "%d tiles from the Line (leash %d)" % [d, leash])
	check("it did not walk to the far point", m.position.distance_to(far) > 300.0)
	# 2. pushed out, it is pulled back
	m.cmd_stop()
	m.position = g.cell_center(cells[6]) + Vector2(0, (leash + 5) * 32)
	m.last_pos = m.position
	await CU.step(self, g, 8.0)
	check("a militia pushed out of its ground walks back", CwUnits.line_dist(g, 0, g.cell_of(m.position)) <= leash,
		"%d tiles" % CwUnits.line_dist(g, 0, g.cell_of(m.position)))
	# 3. a target beyond the leash is not taken
	var foe := CU.spawn(g, "labourer", 1, g.cell_center(cells[6]) + Vector2(0, (leash + 8) * 32))
	m.cmd_attack(foe)
	check("it will not be sent at a target far from the Line", m.order != "attack")
	var near := CU.spawn(g, "labourer", 1, g.cell_center(cells[6]) + Vector2(0, 4 * 32))
	m.cmd_attack(near)
	check("it will attack one within its ground", m.order == "attack")
	# 4. near the Line it does not run down
	m.cmd_stop()
	m.wind = 0.2
	m.position = g.cell_center(cells[6]) + Vector2(0, 32)
	await CU.step(self, g, 4.0)
	check("near the Line it winds up by itself", m.wind > 0.5, "wind %.2f" % m.wind)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
