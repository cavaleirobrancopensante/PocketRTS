extends SceneTree
## Coupling rail vehicles into a train (Clockwork roster prototype, scripts/cw_consist.gd): COUPLE gathers and hooks the
## selected vehicles (the Heavy Locomotive leads); the train moves as one at its slowest car's speed, holds its couplings
## round a corner, takes the Heavy Locomotive's shield, turns round by swapping ends, uncouples where the player tapped, splits
## where a car dies, hooks on when one vehicle drives into an idle one, and survives a save.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_couple.gd
const CU := preload("res://tools/cw_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## Largest gap, over the couplings of a train, between the distance of two neighbours and the coupling length.
func _slack(c: CwConsist) -> float:
	var worst := 0.0
	for i in range(c.cars.size() - 1):
		var a: Unit = c.cars[i]
		var b: Unit = c.cars[i + 1]
		var d := a.position.distance_to(b.position)
		var horiz: bool = absf(a.position.x - b.position.x) >= absf(a.position.y - b.position.y)
		worst = maxf(worst, absf(d - CwConsist.link_len(a, b, horiz)))
	return worst


## Distance from a point to the nearest Line cell centre (the track is 32 px between centres).
func _off_track(g: Game, p: Vector2) -> float:
	var best := INF
	for c in g.line_net.segs:
		best = minf(best, g.cell_center(c).distance_to(p))
	return best


func _run() -> void:
	var g := CU.make(root)
	await process_frame
	await process_frame
	CU.rich(g)
	var cells := CU.row(g, 0, 22)
	check("a straight 22-cell Line", cells.size() == 22, "%d" % cells.size())
	if cells.size() < 22:
		quit(1)
		return
	# a corner: 8 more cells going up or down from one end, where even a Heavy Locomotive (the widest) has room
	var last: Vector2i = cells[21]
	var down: Array = []
	for end in [cells[21], cells[0]]:
		for sgn in [1, -1]:
			down = []
			for k in range(1, 9):
				var c: Vector2i = end + Vector2i(0, k * sgn)
				var ok: bool = g.line_net.pipeable(0, c) and not g.line_net.segs.has(c) and not CU._near_building(g, c)
				for off in [Vector2(5, 5), Vector2(-5, 5), Vector2(5, -5), Vector2(-5, -5), Vector2.ZERO]:
					ok = ok and g._clear_at(g.cell_center(c) + off, 22.0, 0)
				if not ok:
					break
				down.append(c)
			if down.size() == 8:
				break
		if down.size() == 8:
			last = end
			break
	for c in down:
		g.line_net.add_built(0, c)
	check("a corner of 8 cells", down.size() == 8, "%d" % down.size())

	# ---- 1. COUPLE: the Heavy Locomotive leads; the others drive to its last car and hook on
	var heavy := CU.spawn(g, "heavy_loco", 0, g.cell_center(cells[8]))
	var wc := CU.spawn(g, "work_car", 0, g.cell_center(cells[5]))
	var pw := CU.spawn(g, "plate_wagon", 0, g.cell_center(cells[2]))
	await CU.step(self, g, 5.0)       # (new vehicles are left alone by bumps for a few seconds)
	g.set_selection([wc, pw, heavy])
	check("a lone vehicle is not in a train", CwConsist.of(heavy) == null)
	check("COUPLE needs two", CwConsist.couple_problem([heavy]) != "")
	var why := CwConsist.couple_order(g, [wc, pw, heavy])
	check("COUPLE is accepted", why == "", why)
	await CU.step(self, g, 14.0)
	var tr := CwConsist.of(heavy)
	check("one train of three", tr != null and tr.cars.size() == 3 and CwConsist.of(wc) == tr and CwConsist.of(pw) == tr)
	check("the Heavy Locomotive is the head", tr != null and tr.cars[0] == heavy, "head %s" % (tr.cars[0].kind if tr != null else "-"))
	check("couplings hold at rest", tr != null and _slack(tr) < 8.0, "slack %.1f" % _slack(tr))
	check("the cars stand behind the head on the track", wc.position.x < heavy.position.x and pw.position.x < wc.position.x,
		"%.0f %.0f %.0f" % [heavy.position.x, wc.position.x, pw.position.x])
	check("the train is two couplings long (about 128 px)", absf(heavy.position.x - pw.position.x - 128.0) < 12.0, "%.0f" % (heavy.position.x - pw.position.x))

	# ---- 2. selecting any car selects the whole train; an order to a car goes to the head
	g.set_selection([pw])
	check("tapping one car selects the train", g.selection.size() == 3 and g.selection.has(heavy) and g.selection.has(wc))
	check("the tapped car is remembered", tr.pick == pw)
	var shield := CwUnits.incoming(wc, 100.0, null, "")
	check("a Heavy Locomotive shields the cars behind it", absf(shield - 100.0 * float(Defs.CW["couple"]["guard"])) < 0.01, "%.1f" % shield)
	check("it does not shield itself", absf(CwUnits.incoming(heavy, 100.0, null, "") - 100.0) < 0.01)

	# ---- 3. one order, one speed (the slowest car)
	g.set_selection([])
	var goal := g.cell_center(cells[19])
	wc.cmd_move(goal)       # (a follower: the order goes to the head)
	check("an order given to a car is the head's", heavy.order == "move" and wc.order != "move", "%s %s" % [heavy.order, wc.order])
	var x0 := heavy.position.x
	var worst := {"v": 0.0, "slack": 0.0, "dist": 0.0}
	await CU.step(self, g, 4.0, func() -> void:
		worst["slack"] = maxf(worst["slack"], _slack(tr))
		worst["v"] = maxf(worst["v"], heavy.velocity.length()))
	var moved := heavy.position.x - x0
	var slowest := float(Defs.UNITS["heavy_loco"]["speed"])
	check("it moves", moved > 60.0, "%.0f px in 4 s" % moved)
	check("at the slowest car's speed, not the fastest", moved / 4.0 <= slowest * 1.12 and moved / 4.0 >= slowest * 0.7, "%.1f px/s (heavy %d, work car %d)" % [moved / 4.0, slowest, int(Defs.UNITS["work_car"]["speed"])])
	check("the cars keep up (couplings hold while moving)", float(worst["slack"]) < 10.0, "slack %.1f" % float(worst["slack"]))
	check("every car moved too", wc.position.x > g.cell_center(cells[5]).x + 30.0 and pw.position.x > g.cell_center(cells[2]).x + 30.0)
	await CU.step(self, g, 8.0)
	check("the train arrives as one", heavy.position.distance_to(goal) < 40.0 and tr.cars.size() == 3, "head %.0f from goal" % heavy.position.distance_to(goal))

	# ---- 4. round a corner
	var goal2 := g.cell_center(down[7])
	heavy.cmd_move(goal2)
	var cw := {"off": 0.0, "slack": 0.0, "turned": false, "gap_min": 999.0, "gap_max": 0.0}
	await CU.step(self, g, 45.0, func() -> void:
		for u in tr.cars:
			cw["off"] = maxf(cw["off"], _off_track(g, u.position))
		for i in range(tr.cars.size() - 1):
			var gp: float = tr.cars[i].position.distance_to(tr.cars[i + 1].position)
			cw["gap_min"] = minf(cw["gap_min"], gp)
			cw["gap_max"] = maxf(cw["gap_max"], gp))
	var cx := g.cell_center(last).x
	var lead4: Unit = tr.cars[0]
	check("the train swapped ends to go the other way, then reached the end of the corner leg", lead4 == pw and lead4.position.distance_to(goal2) < 40.0,
		"head %s, %.0f from goal" % [lead4.kind, lead4.position.distance_to(goal2)])
	var on_leg := true
	for u in tr.cars:
		on_leg = on_leg and absf(u.position.x - cx) < 20.0
	check("the whole train went round the corner (every car is on the leg)", on_leg, "x of cars: %.0f %.0f %.0f, leg at %.0f" % [tr.cars[0].position.x, tr.cars[1].position.x, tr.cars[2].position.x, cx])
	check("every car stayed on the track", float(cw["off"]) < 24.0, "%.1f px off" % float(cw["off"]))
	check("couplings held on the bend (no gap opened, no overlap)", float(cw["gap_max"]) < 72.0 and float(cw["gap_min"]) > 24.0, "gaps %.0f to %.0f" % [float(cw["gap_min"]), float(cw["gap_max"])])
	check("still one train", CwConsist.of(pw) == tr and tr.cars.size() == 3)

	# ---- 5. turn round: the train stands, swaps ends (the last car leads) and goes back
	var rear5: Unit = tr.cars[2]
	var back := g.cell_center(cells[12])
	tr.cars[0].cmd_move(back)
	await CU.step(self, g, 0.5)
	check("a train told to go back stands to swap ends", tr.rev_t >= 0.0 or tr.cars[0] != lead4, "rev_t %.2f" % tr.rev_t)
	await CU.step(self, g, 40.0)
	check("the ends were swapped (the rear car leads)", tr.cars[0] == rear5, "head %s" % tr.cars[0].kind)
	check("it got back to the place", tr.cars[0].position.distance_to(back) < 50.0, "%.0f from it" % tr.cars[0].position.distance_to(back))
	check("nothing was left behind", tr.cars.size() == 3 and _slack(tr) < 14.0, "slack %.1f" % _slack(tr))

	# ---- 6. UNCOUPLE where the player tapped (the Work Car); the cars from it on become a train of their own
	g.set_selection([wc])
	check("the Work Car was tapped", tr.pick == wc)
	var front6: Unit = tr.cars[0]
	var n := CwConsist.uncouple_order([wc])
	check("UNCOUPLE splits it", n == 1)
	check("the front car is alone now", CwConsist.of(front6) == null)
	var rear := CwConsist.of(wc)
	check("the rest is a train of its own", rear != null and rear != tr)
	check("the Work Car now leads a train of the cars behind it", rear != null and rear.cars[0] == wc and rear.cars.size() == 2, "%d cars" % (rear.cars.size() if rear != null else -1))
	var rear_x := wc.position
	var front_x := front6.position
	front6.cmd_move(g.cell_center(cells[19]))
	await CU.step(self, g, 6.0)
	check("the front car drove off alone", front6.position.distance_to(front_x) > 80.0, "%.0f px" % front6.position.distance_to(front_x))
	check("the rear train stayed", wc.position.distance_to(rear_x) < 6.0)

	# ---- 7. a car that dies breaks the train at that point; both parts carry on
	var kill_cells := cells.slice(2, 8)
	var a := CU.spawn(g, "tesla_loco", 0, g.cell_center(cells[3]))
	var b := CU.spawn(g, "carrier_car", 0, g.cell_center(cells[3]))
	var c3 := CU.spawn(g, "plate_wagon", 0, g.cell_center(cells[3]))
	for u in [heavy, wc, pw]:
		u.position = g.cell_center(cells[20])
		u.cw["no_cpl"] = 1e9
	await CU.step(self, g, 5.0)
	CwConsist.couple_order(g, [a, b, c3])
	await CU.step(self, g, 5.0)
	var t3 := CwConsist.of(a)
	check("a second train formed", t3 != null and t3.cars.size() == 3, "%d" % (t3.cars.size() if t3 != null else 0))
	if t3 != null and t3.cars.size() == 3:
		var head: Unit = t3.cars[0]
		var mid: Unit = t3.cars[1]
		var tail: Unit = t3.cars[2]
		var dest := g.cell_center(cells[17])
		head.cmd_move(dest)
		await CU.step(self, g, 3.0)
		mid.die()
		await CU.step(self, g, 0.3)
		check("the dead car left the train", CwConsist.of(mid) == null)
		check("the head is no longer coupled to the tail", CwConsist.of(head) == null and CwConsist.of(tail) == null)
		await CU.step(self, g, 22.0)
		check("the front part kept going to the goal", head.position.distance_to(dest) < 60.0, "%.0f away" % head.position.distance_to(dest))
		check("the rear part went on to the same place", tail.position.distance_to(dest) < 90.0, "%.0f away" % tail.position.distance_to(dest))

	# ---- 8. driving into an idle vehicle hooks on
	for u in [a, b, c3]:
		if is_instance_valid(u) and not u.dead:
			u.position = g.cell_center(cells[21])
			u.cw["no_cpl"] = 1e9
	var idle := CU.spawn(g, "carrier_car", 0, g.cell_center(cells[8]))
	var mover := CU.spawn(g, "work_car", 0, g.cell_center(cells[1]))
	await CU.step(self, g, 5.0)
	idle.position = g.cell_center(cells[9])
	var dest2 := g.cell_center(cells[15])
	mover.cmd_move(dest2)
	await CU.step(self, g, 14.0)
	var t4 := CwConsist.of(idle)
	check("a vehicle that ran into an idle one hooked on", t4 != null and t4 == CwConsist.of(mover) and t4.cars[0] == idle, "")
	check("the pair went on to where the mover was going", t4 != null and idle.position.distance_to(dest2) < 80.0, "%.0f away" % idle.position.distance_to(dest2))

	# ---- 9. a Heavy Locomotive set up leaves the train
	if t4 != null:
		var h2 := CU.spawn(g, "heavy_loco", 0, g.cell_center(cells[16]))
		await CU.step(self, g, 5.0)
		CwConsist.couple_order(g, [h2, idle])
		await CU.step(self, g, 8.0)
		var t5 := CwConsist.of(h2)
		check("a loco coupled onto the pair leads it", t5 != null and t5.cars[0] == h2 and t5.cars.size() == 3, "%d" % (t5.cars.size() if t5 != null else 0))
		var max_cars := int(Defs.CW["couple"]["max"])
		check("a train holds only a limited number of cars", CwConsist.couple_problem([h2, a, b, c3, wc, pw, mover]) != "" or max_cars >= 7)

	# ---- 9b. a Tesla Locomotive coupled behind a Heavy Locomotive still fires; the Heavy Locomotive's train shields it
	var h3 := CU.spawn(g, "heavy_loco", 0, g.cell_center(cells[4]))
	var te := CU.spawn(g, "tesla_loco", 0, g.cell_center(cells[2]))
	await CU.step(self, g, 5.0)
	CwConsist.couple_order(g, [h3, te])
	await CU.step(self, g, 8.0)
	var t6 := CwConsist.of(te)
	check("the Tesla Locomotive is coupled behind the Heavy Locomotive", t6 != null and t6.cars[0] == h3 and t6.cars[1] == te)
	var foe := CU.spawn(g, "musketeer", 1, te.position + Vector2(0, 90))
	foe.hold_fire = true
	foe.cmd_stop()
	var hp0 := foe.hp
	await CU.step(self, g, 6.0)
	check("a coupled Tesla Locomotive fires from the train", is_instance_valid(foe) and (foe.dead or foe.hp < hp0), "foe hp %.0f of %.0f" % [foe.hp if is_instance_valid(foe) else 0.0, hp0])

	# ---- 10. saved and loaded
	g.set_selection([])
	g.demo = false
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 1})
	g.demo = true
	var rows_ok := false
	for u in g.units:
		if CwConsist.of(u) != null:
			rows_ok = true
	var d := SaveGame.peek()
	var tagged := 0
	for ud in d.get("units", []):
		if ud.has("cpl"):
			tagged += 1
	check("coupled cars carry their place in the save", rows_ok and tagged >= 2, "%d tagged" % tagged)
	var before := g.cw_consists.size()
	for c in g.cw_consists.duplicate():
		c._end()
	SaveGame.restore(g, d)
	var after := 0
	for c in g.cw_consists:
		if c.cars.size() >= 2:
			after += 1
	check("the trains come back after a load", after >= 1 and after <= before + 1, "%d before, %d after" % [before, after])
	SaveGame.clear()

	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
