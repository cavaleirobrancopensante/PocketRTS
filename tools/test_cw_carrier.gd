## Carrier Car (Clockwork roster prototype): Ornithopters land on its deck, are healed, rewound and recharged; a landed one
## carries a small unit away; one car per team; a lost car throws its flyers back into the air.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_carrier.gd
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
	var car := CU.spawn(g, "carrier_car", 0, mid)
	check("only one Carrier Car a side", CwUnits.limit_problem(g, 0, "carrier_car", 0) != "")
	check("the other side may have one", CwUnits.limit_problem(g, 1, "carrier_car", 0) == "")
	var o1 := CU.spawn(g, "ornithopter", 0, mid + Vector2(0, -160))
	var o2 := CU.spawn(g, "ornithopter", 0, mid + Vector2(60, -160))
	var o3 := CU.spawn(g, "ornithopter", 0, mid + Vector2(-60, -160))
	for o in [o1, o2, o3]:
		o.hp = o.max_hp * 0.4
		o.wind = 0.3
	await CU.step(self, g, 0.3)
	var sent := CwUnits.dock_order([o1, o2, o3], car)
	check("two flyers fit the deck", sent == 2, "%d sent" % sent)
	await CU.step(self, g, 6.0)
	check("they land on the car", o1.cw.has("landed") and o2.cw.has("landed"), "%s %s" % [o1.cw.has("landed"), o2.cw.has("landed")])
	check("the deck is full", CwUnits.deck_room(car) == 0)
	o1.hp = o1.max_hp * 0.4
	o1.wind = 0.3
	var hp0 := o1.hp
	var w0 := o1.wind
	await CU.step(self, g, 5.0)
	check("a landed flyer is healed", o1.hp > hp0 + 20.0, "%.0f -> %.0f" % [hp0, o1.hp])
	check("and rewound", o1.wind > w0 + 0.3, "%.2f -> %.2f" % [w0, o1.wind])
	check("and gets a fresh battery", o1.topter_bat != "", o1.topter_bat)
	# the car drives, the flyers ride along
	var p0 := car.position
	car.cmd_move(g.cell_center(cells[10]))
	await CU.step(self, g, 5.0)
	check("the car carries them along", car.position.distance_to(p0) > 60.0 and o1.position.distance_to(car.position) < 40.0, "%.0f" % o1.position.distance_to(car.position))
	# carrying a small unit
	var w := CU.spawn(g, "winder", 0, car.position + Vector2(40, 30))
	w.auto_work = false
	await CU.step(self, g, 0.3)
	var why := CwUnits.carry_order(o1)
	check("a landed flyer takes the Winder beside the car", why == "" and o1.cw.has("cargo") and w.off_field, why)
	var drop_at := g.cell_center(cells[2]) + Vector2(0, 100)
	check("DROP sets a place", CwUnits.drop_order(o1, drop_at) == "")
	var seen := {"p": Vector2.INF}
	await CU.step(self, g, 8.0, func() -> void:
		if seen["p"] == Vector2.INF and not w.off_field:
			seen["p"] = w.position)
	check("it flies there and sets him down", not o1.cw.has("cargo") and not w.off_field and seen["p"].distance_to(drop_at) < 120.0, "set down %.0f from the spot" % seen["p"].distance_to(drop_at))
	check("and has left the deck", not o1.cw.has("landed"))
	# losing the car frees the other flyer
	car.take_damage(100000.0, null)
	await CU.step(self, g, 0.3)
	check("a lost car frees its flyers", not o2.cw.has("landed") and not o2.dead)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
