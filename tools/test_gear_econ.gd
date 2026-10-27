extends SceneTree
## THE CLOCKWORK'S ECONOMY RULES (scripts/gear_econ.gd, docs/clockwork_economy_study.md):
##   DRIVE: a building meshing with the Clocktower or a Mainspring works at 100%, each ring farther out at 90 / 80 / 70%; an
##   idler is free; a Cog Press's cogs, a Mainspring's winding and training speed follow it; supply and the turret do not.
##   EFFICIENCY: one % per building (crew x drive x brass), on its label, its card and the placement ghost before it is placed.
##   TENSION: every Mainspring stores 200 (big gear 400) and winding stops there; a big Mainspring takes 6 Winders and winds
##   2.6/s; the Brutal income multiplier applies; the Clock Aviary costs 150 cogs + 50 Tension (refused without, paid when
##   placed, given back when cancelled: all of it from a site, three quarters once begun).
##   THE TENSION RULE: anything that costs Tension is made only at a building whose ring meshes with a Mainspring's: a Movement
##   Works makes Springers only so (Clock Soldiers always), a Clock Aviary works only so (NEEDS MAINSPRING).
##   A save keeps it all (gear sizes, Tension; drive and the store come back from the field).
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_econ.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _clear_workers(g: Game) -> void:
	for u in g.workers(0).duplicate():
		u.auto_work = false
		u.cmd_stop()
		g.units.erase(u)
		u.queue_free()


## n Winders on building b (new ones), stepped until they stand at work.
func _crew(g: Game, b: Building, n: int) -> void:
	for i in n:
		var w: Unit = g._add_unit("winder", 0, b.center() + Vector2(-60 + i * 22, 70))
		w.auto_work = false
		w.cmd_gather(b)
	var guard := 0
	while b.working_crew() < mini(n, b.crew_max()) and guard < 60:
		U.step(g, 0.5)
		guard += 1


## A finished building of `kind` whose ring meshes with `around`'s ring and with no other ring (a chain link); null if none.
func _hang(g: Game, kind: String, around: Building, big := false) -> Building:
	var c := U.chain_spot(g, 0, kind, around, big)
	if c.x < 0:
		return null
	var b := g._add_building(kind, 0, c, true)
	b.gear_big = big
	g.gear_net.solve()
	return b


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: GearNet = g.gear_net
	var hall := U.hall(g, 0)
	_clear_workers(g)
	g.players[0]["gold"] = 50000
	g.players[0]["cap"] = 200
	var press: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS:
			press = b
	net.solve()
	# ---------------------------------------------------------------- DRIVE
	check("the starting Cog Press meshes with the Clocktower: drive 1 (100%)", int(net.drive_of.get(press, -1)) == 1 and is_equal_approx(net.speed_mult(press), 1.0),
		"steps %d, speed %.2f" % [int(net.drive_of.get(press, -1)), net.speed_mult(press)])
	check("the Clocktower itself has no drive entry and works at 1", not net.drive_of.has(hall) and net.speed_mult(hall) == 1.0)
	var reg := U.put(g, 0, Defs.CW_SUPPLY, hall.cell + Vector2i(0, 9))
	check("a Regulator on the field", reg != null and net.is_linked(reg))
	var works := _hang(g, Defs.CW_WORKS, reg) if reg != null and int(net.drive_of.get(reg, 9)) == 1 else null
	if works == null and reg != null:
		# (the Regulator landed farther out: hang the Works on whatever meshes with the Clocktower)
		works = _hang(g, Defs.CW_WORKS, press)
	check("a Light Works hung on a ring next to the Clocktower's (2nd ring)", works != null and int(net.drive_of.get(works, -1)) == 2,
		"steps %d" % (int(net.drive_of.get(works, -1)) if works else -1))
	if works == null:
		_end()
		return
	check("2nd ring: drive 90% (times its ring's tempo, 0.14.94)", is_equal_approx(net.speed_mult(works) / GearNet.tempo(works), 0.9), "%.2f" % net.speed_mult(works))
	check("supply is not touched by drive (a Regulator's speed stays 1)", reg == null or net.speed_mult(reg) == 1.0)
	# the Works' training follows its drive
	var t0 := g.can_train(works, "clock_soldier")
	check("the Works trains a Clock Soldier", t0 == "" and g.train(works, "clock_soldier") == "", t0)
	U.step(g, 10.0)
	check("in 10 s its training got 9 s along (90%, times its tempo)", absf(works.prod_t - 9.0 * GearNet.tempo(works)) < 0.25, "%.2f" % works.prod_t)
	g.cancel_train(works)
	# a Cog Press on the 3rd ring presses at 80%
	var p2 := _hang(g, Defs.GEAR_PRESS, works)
	check("a second Cog Press hung on the Works (3rd ring): drive 80%", p2 != null and int(net.drive_of.get(p2, -1)) == 3 and is_equal_approx(net.speed_mult(p2), 0.8),
		"steps %d" % (int(net.drive_of.get(p2, -1)) if p2 else -1))
	if p2 != null:
		var gp: Dictionary = Defs.GEAR["press"]
		var want := float(gp["small"]["full"]) * float(gp["base"]) * 0.8
		check("its trickle is 80%% of a press by the Clocktower (%.2f/s)" % want, absf(p2.press_rate() - want) < 0.01, "%.3f" % p2.press_rate())
		var e2: Array = p2.efficiency()
		check("its efficiency shows the trickle share times drive (12%)", not e2.is_empty() and absf(float(e2[0]) - float(gp["base"]) * 0.8) < 0.01, str(e2))
		var sc := int(gp["small"]["crew"])
		_crew(g, p2, sc)
		check("crewed by its %d Winders it presses 80%% of the full rate" % sc, absf(p2.press_rate() - float(gp["small"]["full"]) * 0.8) < 0.05 and absf(float(p2.efficiency()[0]) - 0.8) < 0.01,
			"%.2f/s, eff %s" % [p2.press_rate(), str(p2.efficiency())])
		var ct := GearEcon.card_text(p2)
		check("its card says 80% and why", ct.contains("80%") and ct.contains("%d/%d" % [sc, sc]) and ct.contains("rings from"), ct)
	# a Mainspring meshing with the Works re-drives it (and the press beyond it, when there is room for both)
	var sp := _hang(g, "mainspring", works)
	if sp == null and p2 != null:
		# (no room for one more ring by the Works on the plateau's level: the press makes way for the Mainspring)
		g._remove_quietly(p2)
		net.solve()
		p2 = null
		sp = _hang(g, "mainspring", works)
	check("a Mainspring hung on the Works", sp != null)
	if sp != null:
		check("the Works now meshes with a driver: 100%", int(net.drive_of.get(works, -1)) == 1 and is_equal_approx(net.speed_mult(works) / GearNet.tempo(works), 1.0), "steps %d" % int(net.drive_of.get(works, -1)))
		check("the press beyond the Works is the 2nd ring from the Mainspring: 90%", p2 == null or int(net.drive_of.get(p2, -1)) == 2, "steps %d" % (int(net.drive_of.get(p2, -1)) if p2 else -1))
		check("the Mainspring counts the other drivers only: 3rd ring from the Clocktower (80%)", int(net.drive_of.get(sp, -1)) == 3 and is_equal_approx(net.speed_mult(sp), 0.8),
			"steps %d" % int(net.drive_of.get(sp, -1)))
		# the placement ghost predicts the drive before the building is placed
		var gc := U.chain_spot(g, 0, Defs.CW_TECH, sp)
		if gc.x >= 0:
			var steps := GearEcon.preview_steps(net, 0, Defs.CW_TECH, gc)
			var note := GearEcon.ghost_note(net, 0, Defs.CW_TECH, gc)
			var esc := g._add_building(Defs.CW_TECH, 0, gc, true)
			net.solve()
			check("the ghost's drive (%d) is the built drive" % steps, steps == int(net.drive_of.get(esc, -1)) and note.contains("%d%%" % int(round(100.0 * GearNet.tempo(esc)))), "built %d, note '%s'" % [int(net.drive_of.get(esc, -1)), note])
			g._remove_quietly(esc)
			net.solve()
	# an idler is free: a ring linked through an idler to the Clocktower is still the 1st ring
	var idl := _idler_spot(g, hall)
	if idl.x >= 0:
		var ib := g._add_building(Defs.CW_SUPPLY, 0, idl, true)
		net.solve()
		check("a Regulator linked to the Clocktower through an idler is the 1st ring", net.idler_of.has(ib) and int(net.drive_of.get(ib, -1)) == 1,
			"idler %s, steps %d" % [str(net.idler_of.has(ib)), int(net.drive_of.get(ib, -1))])
	else:
		check("(no idler spot by the Clocktower on this map: skipped)", true)
	# ---------------------------------------------------------------- TENSION
	check("one small Mainspring stores 200", sp == null or is_equal_approx(GearEcon.tension_cap(g, 0), 200.0), "%.0f" % GearEcon.tension_cap(g, 0))
	if sp != null:
		sp.gear_big = true
		net.solve()
		check("a big one stores 400 and takes 6 Winders", is_equal_approx(GearEcon.tension_cap(g, 0), 400.0) and sp.crew_max() == 6, "%.0f, crew %d" % [GearEcon.tension_cap(g, 0), sp.crew_max()])
		_crew(g, sp, 6)
		var mult := net.speed_mult(sp)
		check("a big Mainspring with 6 Winders winds 2.6/s (x its drive %.0f%%)" % (mult * 100.0), absf(sp.spring_rate() - 2.6 * mult) < 0.02, "%.3f" % sp.spring_rate())
		g.players[0]["tension"] = 395.0
		var in0 := float(g.stats[0].get("tension_in", 0.0))
		U.step(g, 4.0)
		check("winding stops at the store (400)", is_equal_approx(g.tension(0), 400.0), "%.2f" % g.tension(0))
		check("and the wound Tension is counted (5)", absf(float(g.stats[0].get("tension_in", 0.0)) - in0 - 5.0) < 0.01, "%.2f" % (float(g.stats[0].get("tension_in", 0.0)) - in0))
		check("a full Mainspring stands still (rate 0, its card says Tension full)", sp.spring_rate() == 0.0 and GearEcon.card_text(sp).contains("Tension full"), GearEcon.card_text(sp))
		check("and its card says what it stores of the side's store", GearEcon.card_info(sp).contains("400 of your 400"), GearEcon.card_info(sp))
		g.players[0]["tension"] = 100.0
		g.income_mult[0] = 2.0
		var a0 := g.tension(0)
		U.step(g, 2.0)
		check("the Brutal income multiplier winds double", absf(g.tension(0) - a0 - 2.0 * 2.0 * sp.spring_rate()) < 0.3, "%.2f in 2 s at %.2f/s" % [g.tension(0) - a0, sp.spring_rate()])
		g.income_mult[0] = 1.0
		sp.gear_big = false
		net.solve()
		U.step(g, 1.0)
		check("back to the small gear: crew 3 (the extra Winders let go)", sp.crew_max() == 3 and sp.crew.size() <= 3, "%d" % sp.crew.size())
	# ---------------------------------------------------------------- THE TENSION RULE
	g.players[0]["tension"] = 1000.0
	var esc2 := g._add_building(Defs.CW_TECH, 0, U.chain_spot(g, 0, Defs.CW_TECH, sp) if sp != null else Vector2i(-1, -1), true) if sp != null and U.chain_spot(g, 0, Defs.CW_TECH, sp).x >= 0 else null
	net.solve()
	check("an Escapement meshing with the Mainspring works", esc2 != null and net.speed_mult(esc2) > 0.0)
	var works2 := U.put(g, 0, Defs.CW_WORKS, hall.cell + Vector2i(-6, -6))
	net.solve()
	if works2 != null and net.spring_for(works2) != null:
		works2 = null          # (it happened to mesh with the Mainspring: no test of the refusal there)
	if works2 != null:
		var why := g.can_train(works2, Defs.SPRINGER)
		check("a Works meshing with no Mainspring refuses the Springer", why.contains("meshes with no Mainspring"), why)
		check("but trains Clock Soldiers", g.can_train(works2, "clock_soldier") == "", g.can_train(works2, "clock_soldier"))
		check("its card says why", GearEcon.card_info(works2).contains("No Mainspring"), GearEcon.card_info(works2))
	check("the Works by the Mainspring trains the Springer", g.can_train(works, Defs.SPRINGER) == "", g.can_train(works, Defs.SPRINGER))
	check("its card says it may", GearEcon.card_info(works).contains("Meshes with a Mainspring"), GearEcon.card_info(works))
	# the Clock Aviary: a Tension user
	check("the Clock Aviary costs 150 cogs + 50 Tension", int(Defs.BUILDINGS[Defs.CW_AIR]["cost"]) == 150 and Defs.tension_cost(Defs.BUILDINGS[Defs.CW_AIR]) == 50)
	var av_far := U.put(g, 0, Defs.CW_AIR, hall.cell + Vector2i(6, -6))
	net.solve()
	if av_far != null and net.spring_for(av_far) == null:
		check("an Aviary meshing with no Mainspring stands idle (NEEDS MAINSPRING)", net.needs_spring(av_far) and net.speed_mult(av_far) == 0.0)
		var aw := g.can_train(av_far, Defs.CUCKOO)
		check("and refuses the Swift", aw != "", aw)
		g._remove_quietly(av_far)
		net.solve()
	if sp != null:
		var avc := GearNet.ring_spot(g, 0, Defs.CW_AIR, sp, 0.0)
		for deg in [60.0, 120.0, 180.0, 240.0, 300.0]:
			if avc.x < 0:
				avc = GearNet.ring_spot(g, 0, Defs.CW_AIR, sp, deg)
		if avc.x >= 0:
			var av := g._add_building(Defs.CW_AIR, 0, avc, true)
			net.solve()
			check("an Aviary meshing with the Mainspring works and trains the Swift", net.speed_mult(av) > 0.0 and g.can_train(av, Defs.CUCKOO) == "", g.can_train(av, Defs.CUCKOO))
			g._remove_quietly(av)
			net.solve()
	# ---------------------------------------------------------------- THE AVIARY'S PRICE
	var spot := U.linked_spot(g, 0, Defs.CW_AIR, hall.cell)
	g.players[0]["tension"] = 20.0
	var builder: Unit = g._add_unit("winder", 0, hall.center() + Vector2(0, 90))
	check("short of Tension, the Aviary is not placed", g.place_building(0, Defs.CW_AIR, spot, [builder]) == null)
	check("the build card says why", g.tension_problem(0, Defs.tension_cost(Defs.BUILDINGS[Defs.CW_AIR])).contains("Tension"))
	g.players[0]["tension"] = 100.0
	var cogs0 := int(g.players[0]["gold"])
	var site := g.place_building(0, Defs.CW_AIR, spot, [builder])
	check("with 50 Tension it is placed: 150 cogs and 50 Tension paid", site != null and int(g.players[0]["gold"]) == cogs0 - 150 and is_equal_approx(g.tension(0), 50.0),
		"%d cogs, %.0f Tension" % [cogs0 - int(g.players[0]["gold"]), 100.0 - g.tension(0)])
	if site != null:
		g.abandon(site)
		check("cancelled before it began: all of it back", int(g.players[0]["gold"]) == cogs0 and is_equal_approx(g.tension(0), 100.0), "%d, %.0f" % [int(g.players[0]["gold"]), g.tension(0)])
	var site2 := g.place_building(0, Defs.CW_AIR, spot, [builder])
	if site2 != null:
		var guard := 0
		while not site2.seeded and guard < 120 and not site2.dead:
			U.step(g, 0.5)
			guard += 1
		U.step(g, 2.0)
		var c1 := int(g.players[0]["gold"])
		var t1 := g.tension(0)
		check("the site has begun", site2.seeded and not site2.built and not site2.dead, "seeded %s" % str(site2.seeded))
		g.abandon(site2)
		check("cancelled once begun: three quarters back (112 cogs, 37 Tension)", int(g.players[0]["gold"]) - c1 == 112 and is_equal_approx(g.tension(0) - t1, 37.0),
			"%d, %.1f" % [int(g.players[0]["gold"]) - c1, g.tension(0) - t1])
	# the HUD's price chip shows cogs + Tension
	if g.hud != null:
		check("the build button's price reads 150+50", g.hud._price_chip([150, 50], true) == "150+50")
	# ---------------------------------------------------------------- SAVE AND LOAD, AND ONLINE
	if sp != null:
		sp.gear_big = true
		net.solve()
		g.players[0]["tension"] = 321.0
		var drv := int(net.drive_of.get(works, -1))
		g.demo = false              # (a demo match is never saved)
		SaveGame.save(g, {"map": g.map_id, "seed": 4242})
		g.demo = true
		var d := SaveGame.peek()
		var g2 := U.make(root, ["clockwork", "crown"], g.map_id, false)
		await process_frame
		await process_frame
		SaveGame.restore(g2, d)
		await process_frame
		g2.gear_net.solve()
		var sp2 := _find(g2, "mainspring", sp.cell)
		var w2 := _find(g2, Defs.CW_WORKS, works.cell)
		check("loaded: the big Mainspring and its store (400)", sp2 != null and sp2.gear_big and is_equal_approx(GearEcon.tension_cap(g2, 0), 400.0), "%.0f" % GearEcon.tension_cap(g2, 0))
		check("loaded: the Tension (321; it may have wound a frame since)", absf(g2.tension(0) - 321.0) < 1.0, "%.2f" % g2.tension(0))
		check("loaded: the Works' drive comes back from the field (%d)" % drv, w2 != null and int(g2.gear_net.drive_of.get(w2, -1)) == drv)
		check("loaded: the Works may still make Springers (it meshes with the Mainspring)", w2 != null and g2.gear_net.spring_for(w2) != null)
		SaveGame.clear()
		# the online guest: Tension comes in the players' rows, drive and the store are worked out from the buildings
		var hs := NetSession.new()
		hs.game = g
		hs.is_host = true
		g.net = hs
		var m := NetSnapshot.build(hs)
		var host_t := g.tension(0)
		g.net = null
		var guest := Game.new()
		guest.puppet = true
		guest.map_id = g.map_id
		guest.demo = true
		guest.factions = ["clockwork", "crown"]
		guest.sides = [0, 1]
		root.add_child(guest)
		await process_frame
		var gs := NetSession.new()
		gs.game = guest
		gs.is_host = false
		guest.net = gs
		NetSnapshot.apply(gs, m)
		guest.gear_net.tick(0.1)
		guest.gear_net.tick(0.1)
		var gw := _find(guest, Defs.CW_WORKS, works.cell)
		check("the guest sees the Tension and the store (of 400)", absf(guest.tension(0) - host_t) < 0.01 and is_equal_approx(GearEcon.tension_cap(guest, 0), 400.0),
			"%.0f of %.0f" % [guest.tension(0), GearEcon.tension_cap(guest, 0)])
		check("the guest works out the same drive and Mainspring mesh for the Works", gw != null and int(guest.gear_net.drive_of.get(gw, -1)) == drv and guest.gear_net.spring_for(gw) != null)
	_end()


## A cell for a Regulator whose ring links with the Clocktower's through an IDLER (a gap wider than a direct mesh), touching
## no other ring; (-1, -1) when there is none.
func _idler_spot(g: Game, hall: Building) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[Defs.CW_SUPPLY]["size"]
	var r := GearNet.ring_r(Defs.CW_SUPPLY, size, false)
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var tol := float(Defs.GEAR["mesh_tol"])
	for y in range(hall.cell.y - 14, hall.cell.y + 15):
		for x in range(hall.cell.x - 14, hall.cell.x + 15):
			var c := Vector2i(x, y)
			if not g.in_map(c) or g.placement_problem(0, Defs.CW_SUPPLY, c) != "" or not g.margin_free(c, size):
				continue
			var gc := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var gap := gc.distance_to(GearNet.b_c(hall)) - r - GearNet.b_r(hall)
			if gap <= tol + 8.0 or gap > slack * 0.9:
				continue
			var alone := true
			for o in g.buildings:
				if o != hall and o.team == 0 and not o.dead and GearNet.has_gear(o):
					if gc.distance_to(GearNet.b_c(o)) - r - GearNet.b_r(o) <= slack:
						alone = false
						break
			if alone:
				return c
	return Vector2i(-1, -1)


func _find(g: Game, kind: String, cell: Vector2i) -> Building:
	for b in g.buildings:
		if b.team == 0 and b.kind == kind and b.cell == cell and not b.dead:
			return b
	return null


func _end() -> void:
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
