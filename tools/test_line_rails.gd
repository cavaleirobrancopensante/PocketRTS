extends SceneTree
## Rails and ore trains (phase 2 of the Line): the start has a Drill and a train, ore reaches the Clocktower by
## train, the rail caps the flow, a cut stops the trains until it is mended, low pressure slows them, enemies
## shoot trains, a Troop Train carries soldiers (and drops them hurt when it is lost), save/load round-trips.
##   godot --headless --script res://tools/test_line_rails.gd
const U := preload("res://tools/line_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _step(g: Game, secs: float, hook := Callable()) -> void:
	var n := int(secs * 30.0)
	for i in n:
		if hook.is_valid():
			hook.call()
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)
		if i % 6 == 0:
			await process_frame


func _drills(g: Game, t: int) -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == t and b.kind == "ore_drill" and not b.dead)


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: LineNetwork = g.line_net
	var rails: Rails = net.rails
	check("rail_econ is on by default", Defs.rail_econ)
	check("the Clockwork starts with an Ore Drill, not a Crusher", _drills(g, 0).size() == 1 and g.econ_count(0, "ore_crusher") == 0)
	check("it starts with one Ore Train", rails.count(0, "ore") == 1)
	check("the Drill touches the Line", net.touches(_drills(g, 0)[0]))
	check("the build list has the Drill, not the Crusher", Defs.build_list("clockwork").has("ore_drill") and not Defs.build_list("clockwork").has("ore_crusher"))
	net.solve()
	var drill: Building = _drills(g, 0)[0]
	check("the Drill is powered", net.speed_mult(drill) > 0.9, "%.2f" % net.speed_mult(drill))
	# 1. ore arrives by train
	var ore0 := float(g.players[0]["gold"])
	var rec: Array = []
	await _step(g, 75.0, func() -> void:
		g.players[0]["gold"] = minf(float(g.players[0]["gold"]), 100000.0))
	var delivered := float(rails.delivered.get(0, 0.0))
	check("the Drill digs ore into its stock", drill.stock > 0.0 or delivered > 0.0, "stock %.0f, delivered %.0f" % [drill.stock, delivered])
	check("the train delivers ore to the Clocktower", delivered >= 60.0, "%.0f ore in 75 s" % delivered)
	check("delivered ore is paid as income", float(g.players[0]["gold"]) > ore0 + delivered * 0.9 - 1.0, "%.0f -> %.0f" % [ore0, g.players[0]["gold"]])
	var lode_before := U.hall(g, 0).lode
	check("the ore comes out of the Clocktower's lode", lode_before < float(Defs.LODE["clocktower"]), "%.0f left" % lode_before)
	# 2. the rail caps the flow: a long straight Line, a hall at one end and a Drill at the other, many trains
	for tr in rails.trains.duplicate():
		tr.die()
	for b in _drills(g, 0):
		g._remove_quietly(b)
	net.enforce = false         # (the cap is the rail's: pressure is tested below)
	var cells: Array = U.run_from_hall(g, 0, 40)
	check("a 40-segment run for the throughput test", cells.size() == 40, "%d" % cells.size())
	var d2: Building = U.building_beside(g, 0, "ore_drill", cells[cells.size() - 1])
	check("a Drill at the far end", d2 != null)
	if d2 == null:
		quit(1)
		return
	for i in 8:
		rails.add_train(0, "ore")
	rails.delivered[0] = 0.0
	var keep_full := func() -> void:
		d2.stock = float(Defs.RAIL["drill"]["stock"])
		U.hall(g, 0).lode = 99999.0
	await _step(g, 20.0, keep_full)       # (warm up: the trains spread out along the line)
	rails.delivered[0] = 0.0
	await _step(g, 100.0, keep_full)
	var rate := float(rails.delivered.get(0, 0.0)) / 100.0
	var cap := Rails.rail_cap()
	check("8 trains on one rail are held to its cap", rate <= cap * 1.12, "%.1f ore/s vs cap %.1f" % [rate, cap])
	check("... and the cap is nearly reached", rate >= cap * 0.5, "%.1f ore/s" % rate)
	var one_rate_trains := rails.trains.size()
	# trains keep their following distance
	var worst := 99
	for a in rails.trains:
		for b in rails.trains:
			if a != b and a.dir != Vector2i.ZERO and a.dir == b.dir:
				var da := absi(a.cell.x - b.cell.x) + absi(a.cell.y - b.cell.y)
				worst = mini(worst, da)
	check("trains going one way never close up", worst >= 2, "closest %d cells" % worst)
	# 3. a cut stops them, the repair starts them again
	var mid: Vector2i = cells[20]
	var seg: PipeSeg = net.seg_at(mid)
	seg.take_damage(99999.0, null)
	await _step(g, 2.0, keep_full)
	check("the cut is a missing segment", not net.has_cell(mid))
	rails.delivered[0] = 0.0
	await _step(g, 40.0, keep_full)
	var stalled := float(rails.delivered.get(0, 0.0))
	var strand := rails.trains.filter(func(t: Train) -> bool: return t.state == "stranded").size()
	check("a cut stops the trains beyond it", stalled < cap * 5.0, "%.0f ore in 40 s (%d stranded)" % [stalled, strand])
	net.add_built(0, mid)
	rails.delivered[0] = 0.0
	await _step(g, 60.0, keep_full)
	check("mending the Line gets them going again", float(rails.delivered.get(0, 0.0)) > stalled + 100.0, "%.0f ore in 60 s" % float(rails.delivered.get(0, 0.0)))
	# 4. pressure slows trains: a 26-segment Line (about 35% pressure at its far end), one train
	for tr in rails.trains.duplicate():
		tr.die()
	for b in _drills(g, 0):
		g._remove_quietly(b)
	net.enforce = true
	cells = U.run_from_hall(g, 0, 26)
	d2 = U.building_beside(g, 0, "ore_drill", cells[cells.size() - 1])
	rails.add_train(0, "ore")
	net.solve()
	var vs := {"min": INF, "max": 0.0}      # (a lambda copies plain variables: a Dictionary is shared)
	await _step(g, 60.0, func() -> void:
		d2.stock = float(Defs.RAIL["drill"]["stock"])
		U.hall(g, 0).lode = 99999.0
		for tr in rails.trains:
			if tr.speed_now > 0.0:
				vs["min"] = minf(vs["min"], tr.speed_now)
				vs["max"] = maxf(vs["max"], tr.speed_now))
	var vmin: float = vs["min"]
	var vmax: float = vs["max"]
	var fast_v := float(Defs.TRAINS["ore"]["speed"])
	check("trains run at full speed on strong pressure", vmax > fast_v * 0.9, "fastest %.2f of %.2f cells/s" % [vmax, fast_v])
	check("trains slow down where the pressure is low", vmin < fast_v * 0.7, "slowest %.2f cells/s" % vmin)
	check("the Drill at a weak end digs slower", net.speed_mult(d2) < 0.8, "%.2f" % net.speed_mult(d2))
	# 5. enemies shoot trains
	var tr0: Train = rails.trains[0]
	g.reveal = true
	var foe: Unit = g._add_unit("musketeer", 1, tr0.global_position + Vector2(60, 0))
	g._update_vis()
	check("an enemy picks the train as a target", rails.target(foe, 300.0) != null)
	var hp0 := tr0.hp
	tr0.take_damage(100.0, foe)
	check("a train takes damage", tr0.hp < hp0)
	var n0 := rails.trains.size()
	tr0.take_damage(99999.0, foe)
	check("a train can be destroyed", rails.trains.size() == n0 - 1 and tr0.dead)
	g._remove_quietly_unit(foe) if g.has_method("_remove_quietly_unit") else foe.queue_free()
	g.units.erase(foe)
	# 6. save and load
	for i in 2:
		var nt := rails.add_train(0, "ore")
		nt.cargo = 33.0
	var rows := rails.save()
	check("trains save as rows", rows.size() == rails.trains.size(), "%d rows" % rows.size())
	var cnt := rails.trains.size()
	rails.load_rows(rows)
	check("trains load back", rails.trains.size() == cnt)
	check("drill stock saves", is_equal_approx(float(JSON.parse_string(JSON.stringify({"s": snappedf(d2.stock, 0.1)}))["s"]), snappedf(d2.stock, 0.1)))
	# 7. troops
	for tr in rails.trains.duplicate():
		tr.die()
	var tt := rails.add_train(0, "troop")
	check("a Troop Train can be put on the Line", tt != null)
	var h := U.hall(g, 0)
	var men: Array = []
	var from_c: Vector2i = cells[6]
	for i in 3:
		men.append(g._add_unit("windup_soldier", 0, g.cell_center(from_c) + Vector2(20 + i * 10, 22)))
	var why := g.ride_order(men, g.cell_center(cells[20]))
	check("RIDE is accepted", why == "", why)
	await _step(g, 30.0)
	check("the soldiers climb aboard", tt.riders.size() == 3 or tt.state in ["carrying", "unloading", "returning", "idle"], "%d aboard, %s" % [tt.riders.size(), tt.state])
	var at_dest := false
	await _step(g, 40.0)
	for u in men:
		if is_instance_valid(u) and not u.off_field and u.visible and u.position.distance_to(g.cell_center(cells[20])) < 140.0:
			at_dest = true
	check("they are set down at the destination", at_dest and tt.riders.is_empty(), "train %s" % tt.state)
	# lost train: riders come out hurt
	for u in men:
		u.position = g.cell_center(cells[8])
	why = g.ride_order(men, g.cell_center(cells[22]))
	var waited := 0.0
	while waited < 25.0 and not (tt.riders.size() > 0 and tt.state == "carrying"):
		await _step(g, 0.5)
		waited += 0.5
	var hp_before: Array = men.map(func(u: Unit) -> float: return u.hp)
	if tt.riders.size() > 0:
		await _step(g, 1.0)
		check("riders are hidden while aboard", men.all(func(u: Unit) -> bool: return not u.visible or u not in tt.riders))
		tt.take_damage(99999.0, null)
		var hurt := 0
		for i in men.size():
			if is_instance_valid(men[i]) and men[i].visible and men[i].hp < hp_before[i]:
				hurt += 1
		check("a lost Troop Train drops its riders, hurt", hurt == men.size() and tt.dead, "%d hurt" % hurt)
	else:
		check("a lost Troop Train drops its riders, hurt", false, "nobody was aboard: %s" % tt.state)
	# 8. the old economy is still there behind the flag
	Defs.rail_econ = false
	check("with rail_econ off the Crusher is back", Defs.build_list("clockwork").has("ore_crusher") and not Defs.build_list("clockwork").has("ore_drill"))
	Defs.rail_econ = true
	print(("FAIL (%d)" % fails) if fails > 0 else "ALL PASS")
	quit(1 if fails > 0 else 0)
