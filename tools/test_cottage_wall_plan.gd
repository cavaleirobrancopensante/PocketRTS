extends SceneTree
## The Crown's Cottage wall plan (AI.plan_cottage_wall) on every map, for both start positions:
##   godot --headless --script res://tools/test_cottage_wall_plan.gd [-- map ids...]
## For each ramp plan: the Cottage footprint is legal and covers band cells (the high-ground cells
## touching the ramp), there is a Gate, and an independent flood fill from the ramp (8 ways, no corner cutting, the
## plan's pieces and the Cottage built, gates shut) cannot reach anything near the Town Hall,
## while with the gates open it can (the army gets out and the labourers get in).
## Prints one line per map and team: Cottage cell, pieces, cost (without the Cottage's own 100).
var main: Node
var fails := 0
var rows: Array = []


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	for id in ids:
		await _one(id)
	print("--- plan table (map, team: cottage cell, band, covered, pieces, extra cost without the Cottage) ---")
	for r in rows:
		print(r)
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL  " + what)
		fails += 1


func _one(id: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": id, "seed": 777, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g: Game = main.game
	if g == null:
		check(false, "%s: no game" % id)
		return
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED       # (before the first think: the AI would put its Cottage there)
	await process_frame
	await process_frame
	for a in g.ais:
		var plan: Dictionary = a.plan_cottage_wall()
		var tag := "%s team %d" % [id, a.team]
		if plan.is_empty():
			check(false, tag + ": no plan")
			rows.append(tag + ": NO PLAN")
			continue
		var tl: Vector2i = plan["cottage"]
		var csize: Vector2i = Defs.BUILDINGS["cottage"]["size"]
		var bands: Array = a._ramp_bands()
		var band := {}
		for c in bands[0]["band"]:
			band[c] = true
		var covered := 0
		var fp := {}
		for dy in csize.y:
			for dx in csize.x:
				var c := tl + Vector2i(dx, dy)
				fp[c] = true
				if band.has(c):
					covered += 1
				check(g.is_free(c) and g.ramp[g.idx(c)] == 0 and g.height[g.idx(c)] == 1, tag + ": cottage cell %s is free high ground" % str(c))
		check(covered >= 1, tag + ": the Cottage footprint is on the band")
		check(g.placement_problem(a.team, "cottage", tl) == "", tag + ": the Cottage site is a legal placement (%s)" % g.placement_problem(a.team, "cottage", tl))
		var gates: Array = []
		var blocked := fp.duplicate()
		var kinds := {}
		for e in plan["pieces"]:
			kinds[e[1]] = e[0]
			if e[0] == "gate":
				gates.append(e[1])
			check(g.placement_problem(a.team, e[0], e[1]) == "", tag + ": %s site %s legal" % [e[0], str(e[1])])
		check(not gates.is_empty(), tag + ": a gate")
		# (every band cell is the Cottage, a piece, or already solid: nothing slips past)
		for c in band:
			check(fp.has(c) or kinds.has(c), tag + ": band cell %s covered" % str(c))
		for e in plan["pieces"]:
			if e[0] == "wall":
				blocked[e[1]] = true
		var home := Vector2(g.starts[a.team]) + Vector2(2.5, 2.0)
		var shut: Dictionary = a.cw_reach(bands[0]["ramp"], blocked, gates, false)
		var open: Dictionary = a.cw_reach(bands[0]["ramp"], blocked, gates, true)
		var leak := false
		var home_open := false
		for c in shut:
			if g.height[g.idx(c)] == 1 and g.ramp[g.idx(c)] == 0 and Vector2(c).distance_to(home) < 24.0:
				leak = true
		for c in open:
			if g.height[g.idx(c)] == 1 and g.ramp[g.idx(c)] == 0 and Vector2(c).distance_to(home) < 9.0:
				home_open = true
		check(not leak, tag + ": sealed (the flood from the ramp, gates shut, reaches nothing up at the base)")
		check(home_open, tag + ": the gate lets the army and labourers through to the Town Hall")
		var names: Array = []
		for e in plan["pieces"]:
			names.append("%s%s" % [e[0], str(e[1])])
		rows.append("%s: cottage %s, band %d, covered %d, pieces %s, cost %d" % [tag, str(tl), band.size(), covered, ", ".join(names), int(plan["cost"])])
	main.queue_free()
	await process_frame
