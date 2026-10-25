extends SceneTree
## Rail Rifleman (Clockwork roster prototype): more range and damage on or beside the Line; he can ride a Troop Train and
## fire from the carriage.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_rifleman.gd
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
	var on := CU.spawn(g, "rail_rifleman", 0, g.cell_center(cells[5]))
	var off := CU.spawn(g, "rail_rifleman", 0, g.cell_center(cells[5]) + Vector2(0, 8 * 32))
	await CU.step(self, g, 0.8)
	check("beside the Line he knows it", bool(on.cw.get("near", false)) and not bool(off.cw.get("near", false)))
	check("his reach is longer beside the Line", on._range() > off._range() * 1.2, "%.0f vs %.0f" % [on._range(), off._range()])
	var victim := CU.spawn(g, "cuirassier", 1, g.cell_center(cells[5]) + Vector2(0, 12 * 32))
	victim.max_hp = 9000.0
	victim.armor = 0
	victim.hp = 9000.0
	var hp0 := victim.hp
	CwUnits.rifle_shot(on, victim, true)
	var d_near := hp0 - victim.hp
	victim.hp = hp0
	CwUnits.rifle_shot(off, victim, false)
	var d_far := hp0 - victim.hp
	check("and his shot hits harder", d_near > d_far * 1.2, "%.1f vs %.1f" % [d_near, d_far])
	# riding a Troop Train
	var rails: Rails = g.line_net.rails
	var tr: Train = rails.add_train(0, "troop")
	check("a Troop Train can be had", tr != null)
	if tr == null:
		quit(1)
		return
	on.position = tr.global_position
	tr.riders.append(on)
	on.off_field = true
	on.aboard = null
	var enemy := CU.spawn(g, "cuirassier", 1, tr.global_position + Vector2(100, 0))
	enemy.max_hp = 9000.0
	enemy.hp = 9000.0
	await CU.step(self, g, 4.0)
	check("a rifleman on a train fires from it", enemy.hp < 9000.0, "%.0f" % enemy.hp)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
