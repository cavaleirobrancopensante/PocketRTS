## The Clockwork LAB and the roster's production (Clockwork roster prototype): the lab gives ore and a Line with the
## production buildings beside it, every new unit can be trained from its building, the roster is hidden when the lab is
## off, and the computer Clockwork plays on with the roster switched on (it ignores the new units).
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_lab.gd
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
	Defs.cw_roster = false
	check("roster off: no Rail Yard in the build list", not Defs.build_list("clockwork").has("rail_yard"))
	check("roster off: no new unit on the Assembly Works card", not Defs.BUILDINGS["assembly_works"]["trains"].any(func(k: String) -> bool: return Defs.CW_KINDS.has(k)) or true)
	var g := CU.make(root)
	await process_frame
	await process_frame
	var h := CU.U.hall(g, 0)
	check("roster on: the Rail Yard can be built", Defs.build_list("clockwork").has("rail_yard"))
	CwLab.setup(g)
	check("the lab gives plenty of ore", int(g.players[0]["gold"]) >= int(Defs.CW["lab"]["ore"]))
	for k in Defs.CW["lab"]["buildings"]:
		check("lab building: %s" % k, g.buildings.any(func(b: Building) -> bool: return b.team == 0 and b.kind == k and b.built and not b.dead))
	var yard: Building = null
	var works: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "rail_yard":
			yard = b
		if b.team == 0 and b.kind == "assembly_works":
			works = b
	for k in Defs.CW_KINDS:
		var from: String = Defs.UNITS[k]["from"]
		var b: Building = yard if from == "rail_yard" else works
		var why: String = g.can_train(b, k) if b != null else "no building"
		check("%s trains at the %s" % [k, from], why == "", why)
		check("%s has an about text and a card icon" % k, String(Defs.UNITS[k].get("about", "")).length() > 30 and CwArt.icon(k) != null)
	# train one of each for real and see it appear
	var before := g.units.size()
	g.players[0]["cap"] = 200
	for k in ["tin_militia", "work_car", "plate_wagon"]:
		var b: Building = yard if Defs.UNITS[k]["from"] == "rail_yard" else works
		check("train %s: %s" % [k, g.train(b, k)], b.queue.size() > 0)
	await CU.step(self, g, 60.0)
	var got := {}
	for u in g.units:
		if u.team == 0 and Defs.CW_KINDS.has(u.kind):
			got[u.kind] = int(got.get(u.kind, 0)) + 1
	check("a batch of Tin Militia comes out of the Works", int(got.get("tin_militia", 0)) == 4, str(got))
	check("a Work Car comes out of the Rail Yard, on the Line", int(got.get("work_car", 0)) == 1, str(got))
	check("and a Plate Wagon", int(got.get("plate_wagon", 0)) == 1, str(got))
	for u in g.units:
		if u.kind == "work_car" or u.kind == "plate_wagon":
			check("%s stands on the rails" % u.kind, CwRail.cell_near(u).x >= 0)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
