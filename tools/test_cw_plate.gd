## Plate Wagon (Clockwork roster prototype): its body blocks the track against enemy ground units (own pass), the plates give cover, siege hurts it.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_plate.gd
extends SceneTree
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
	var mid := g.cell_center(cells[6])
	# an enemy walks along the track: first with nothing in the way
	var e := CU.spawn(g, "labourer", 1, mid + Vector2(-110, 0))
	var goal := mid + Vector2(110, 0)
	e.auto_work = false
	e.cmd_move(goal)
	await CU.step(self, g, 6.0)
	check("with no wagon the enemy walks through", e.position.distance_to(goal) < 40.0, "%.0f from goal" % e.position.distance_to(goal))
	# the wagon in the way
	var w := CU.spawn(g, "plate_wagon", 0, mid)
	await CU.step(self, g, 0.5)
	e.cmd_stop()
	e.position = mid + Vector2(-110, 0)
	e.last_pos = e.position
	e.cmd_move(goal)
	await CU.step(self, g, 6.0)
	check("the wagon blocks the enemy", e.position.x < w.position.x, "enemy x %.0f wagon x %.0f" % [e.position.x, w.position.x])
	# a friend walks through
	e.cmd_stop()
	e.position = mid + Vector2(-110, 150)
	var f := CU.spawn(g, "labourer", 0, mid + Vector2(-110, 36))
	f.auto_work = false
	f.cmd_move(goal + Vector2(0, 36))
	await CU.step(self, g, 6.0)
	check("own units pass", f.position.x > w.position.x + 20.0, "friend x %.0f wagon x %.0f" % [f.position.x, w.position.x])
	# plates: cover for ranged hits on friends
	var shot_base := CwUnits.incoming(f, 100.0, e, Entity.BLOW_RANGED)
	CwUnits.plates_up(w)
	check("PLATES starts the cover", float(w.cw.get("cover_t", 0.0)) > 0.0)
	f.position = w.position + Vector2(0, 40)
	var shot_cover := CwUnits.incoming(f, 100.0, e, Entity.BLOW_RANGED)
	check("friends near it take less from ranged hits", shot_cover < shot_base * 0.6, "%.0f vs %.0f" % [shot_cover, shot_base])
	check("melee hits are not reduced", CwUnits.incoming(f, 100.0, e, Entity.BLOW_MELEE) == 100.0)
	await CU.step(self, g, 1.5)
	check("the plates widen the gate", CwUnits.gate_half(w) > float(Defs.CW["plate"]["half"]) + 5.0, "%.0f" % CwUnits.gate_half(w))
	await CU.step(self, g, float(Defs.CW["plate"]["time"]) + 1.0)
	check("the cover ends after a few seconds", float(w.cw.get("cover_t", 0.0)) <= 0.0 and float(w.cw.get("cd", 0.0)) > 0.0)
	check("and cannot be raised again at once", CwUnits.plates_problem(w) != "")
	# weak to siege
	var cannon := CU.spawn(g, "cannon", 1, mid + Vector2(0, 200))
	var plain := CwUnits.incoming(w, 100.0, e, Entity.BLOW_RANGED)
	var siege := CwUnits.incoming(w, 100.0, cannon, Entity.BLOW_RANGED)
	check("siege hurts it twice as much", siege > plain * 1.8, "%.0f vs %.0f" % [siege, plain])
	w.take_damage(100000.0, null)
	await CU.step(self, g, 0.3)
	check("a dead wagon is no gate", not g.cw_gates.has(w))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
