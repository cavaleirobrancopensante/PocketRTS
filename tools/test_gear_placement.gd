extends SceneTree
## The placement rule: a new Clockwork building's ring must touch the connected field and may not cut into another ring;
## the ghost reports it; a site that is not built yet does not conduct; a Clocktower starts its own field; place_building
## enforces it; the Crown and Brood are not affected.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_placement.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: GearNet = g.gear_net
	var tower := U.hall(g, 0)
	g.players[0]["gold"] = 5000
	var spot := U.linked_spot(g, 0, "assembly_works", tower.cell)
	check("a linking spot for an Assembly Works exists", spot.x >= 0)
	check("candidate says ok there", net.candidate(0, "assembly_works", spot)["state"] == "ok")
	check("placement_problem accepts it", g.placement_problem(0, "assembly_works", spot) == "")
	var far := tower.cell + Vector2i(0, 40)
	check("a spot far away says 'far' and gives a reason", net.candidate(0, "assembly_works", far)["state"] == "far" and g.placement_problem(0, "assembly_works", far).contains("gear"))
	var clash := tower.cell + Vector2i(0, 4)
	check("a ring cutting deep into another says 'clash'", net.candidate(0, "boiler", clash)["state"] == "clash")
	# place_building enforces the rule
	var w: Unit = g.workers(0)[0]
	check("place_building refuses an unlinked spot", g.place_building(0, "assembly_works", far, [w]) == null)
	var b := g.place_building(0, "assembly_works", spot, [w])
	check("place_building accepts a linking one (a ghost site)", b != null and not b.built)
	# a site does not conduct: a building that would link only to the site is 'far'
	if b:
		var only_site := Vector2i(-1, -1)
		var size: Vector2i = Defs.BUILDINGS["spring_tower"]["size"]
		var slack := float(Defs.GEAR["slack"]) * Defs.TILE
		for y in range(b.cell.y - 14, b.cell.y + 15):
			for x in range(b.cell.x - 14, b.cell.x + 15):
				var c := Vector2i(x, y)
				if only_site.x >= 0 or not g.in_map(c) or not g.margin_free(c, size):
					continue
				var st := net.candidate(0, "spring_tower", c)
				if st["state"] != "far":
					continue
				var centre := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
				var gap := centre.distance_to(GearNet.b_c(b)) - (GearNet.ring_r("spring_tower", size, false) + GearNet.b_r(b))
				if gap > -float(Defs.GEAR["overlap"]) * Defs.TILE and gap <= slack:
					only_site = c
		check("a ring touching only an unfinished site does not link (site does not conduct)", only_site.x >= 0, str(only_site))
		if only_site.x >= 0:
			b.built = true
			b.ghost = false
			b.progress = 1.0
			net.solve()
			check("...but does once the site is finished", net.candidate(0, "spring_tower", only_site)["state"] == "ok")
	# a Clocktower starts its own field
	check("a Clocktower anywhere: 'tower' (its own field)", net.candidate(0, "clocktower", far)["state"] == "tower")
	# a second Clocktower, finished, is a root: a building meshing with only it is connected
	var t2 := g._add_building("clocktower", 0, Vector2i(60, 60), true)
	net.solve()
	check("a finished second Clocktower is a root", net.linked.has(t2))
	var near2 := Vector2i(-1, -1)
	var size2: Vector2i = Defs.BUILDINGS["boiler"]["size"]
	for y in range(t2.cell.y - 14, t2.cell.y + 15):
		for x in range(t2.cell.x - 14, t2.cell.x + 15):
			var c := Vector2i(x, y)
			if near2.x < 0 and g.in_map(c) and g.margin_free(c, size2) and net.candidate(0, "boiler", c)["state"] == "ok":
				near2 = c
	check("a building can mesh with the second field", near2.x >= 0)
	# other factions are untouched
	check("a Crown building needs no gear ring", g.gear_net.candidate(1, "barracks", Vector2i(5, 5))["state"] == "ok")
	check("the build list has the Cog Press and no Ore Drill/Rail Yard/Relay", Defs.build_list("clockwork").has(Defs.GEAR_PRESS) and not Defs.build_list("clockwork").has("ore_drill") and not Defs.build_list("clockwork").has("rail_yard") and not Defs.build_list("clockwork").has("pressure_relay") and not Defs.build_list("clockwork").has("ore_crusher"))
	check("rail vehicles are hidden from the train lists", not Defs.train_keys(["windup_soldier", "work_car", "heavy_loco"], false).has("work_car"))
	check("the Clockwork starts with 300 cogs", int(Defs.FACTIONS["clockwork"]["start_gold"]) == 300 and String(Defs.FACTIONS["clockwork"]["res"][0]) == "Cogs")
	check("the Winder is like the Labourer (74 speed, 50 cost, 46 hp, 12 s)", Defs.UNITS["winder"]["speed"] == 74 and Defs.UNITS["winder"]["cost"] == 50 and Defs.UNITS["winder"]["hp"] == 46 and Defs.UNITS["winder"]["time"] == 12.0)
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
