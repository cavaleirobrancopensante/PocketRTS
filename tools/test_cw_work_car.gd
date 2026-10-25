extends SceneTree
## Work Car (Clockwork roster prototype): it carries a crew of Winders and the building crates; the crew leave the car
## to build near it and walk back aboard when done; a lost car strands the crew, slow on their feet.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_work_car.gd
const CU := preload("res://tools/cw_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _aboard(car: Unit) -> int:
	var n := 0
	for w in car.cw.get("crew", []):
		if is_instance_valid(w) and w.off_field:
			n += 1
	return n


func _run() -> void:
	var g := CU.make(root)
	await process_frame
	await process_frame
	CU.rich(g)
	var cells := CU.row(g, 0, 12)
	var car := CU.spawn(g, "work_car", 0, g.cell_center(cells[5]))
	check("the car comes with a crew of 3 Winders", (car.cw["crew"] as Array).size() == 3 and _aboard(car) == 3)
	check("the crew are stowed (untouchable, hidden)", not (car.cw["crew"][0] as Unit).visible)
	# a building next to the car: the crew come out, build, and go back aboard
	var site_cell := Vector2i(-1, -1)
	for r in range(2, 6):
		for off in [Vector2i(0, -r - 2), Vector2i(0, r), Vector2i(3, -r - 2)]:
			var c: Vector2i = cells[5] + off
			if site_cell.x < 0 and g.placement_problem(0, "boiler", c) == "":
				site_cell = c
	check("a free spot for a building beside the car", site_cell.x >= 0)
	var b := g.place_building(0, "boiler", site_cell, [car])
	check("the site is placed and claimed by the car", b != null and CwUnits.car_claims(g, b))
	var out := {"max": 0}
	await CU.step(self, g, 3.0, func() -> void:
		out["max"] = maxi(out["max"], 3 - _aboard(car)))
	check("a crew member comes out to build", out["max"] >= 1, "%d out" % out["max"])
	g.sweep_ghosts()
	check("the sweep does not cancel the car's site", is_instance_valid(b) and not b.dead)
	await CU.step(self, g, 70.0, func() -> void:
		out["max"] = maxi(out["max"], 3 - _aboard(car)))
	check("the building gets built", is_instance_valid(b) and b.built, "built %s hp %.0f" % [b.built if is_instance_valid(b) else "gone", b.hp if is_instance_valid(b) else 0.0])
	await CU.step(self, g, 12.0)
	check("the crew walk back aboard when done", _aboard(car) == 3, "%d aboard" % _aboard(car))
	# killing the car strands the crew
	var crew: Array = (car.cw["crew"] as Array).duplicate()
	car.cw["out"] = true
	await CU.step(self, g, 4.0)
	car.take_damage(100000.0, null)
	await CU.step(self, g, 0.5)
	check("the car is dead", car.dead)
	var alive := crew.filter(func(w: Unit) -> bool: return is_instance_valid(w) and not w.dead and not w.off_field)
	check("the crew are stranded alive on the ground", alive.size() == 3, "%d" % alive.size())
	check("stranded crew walk slowly", alive.size() > 0 and float(alive[0].cw.get("slowed", 1.0)) < 1.0)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
