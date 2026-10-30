extends SceneTree
## EXHAUSTED MEANS EXHAUSTED (0.24.0, the owner 2026-10-30; docs/exhaust_economy.md):
##   NO TRICKLE anywhere: a Farm, Cog Press or Mainspring with nobody on it makes nothing; a Crown and a Clockwork base with
##   every worker gone earn nothing at all.
##   PRIMARY RESOURCES, SPENT PAY 0: spent soil (harvest 0), brass (the press presses 0, barren: crew let go), a Rootmaw's
##   spent ground.
##   SECONDARY RESOURCES FALL TO A FLOOR (the owner, 14:44): a Powder Mill and a Mainspring yield less as their reserve runs
##   down (saltpetre, SPRING LIFE), Defs.POWDER_FLOOR / TENSION_FLOOR once spent, and keep it while worked (nothing with nobody on them); the
##   spent Mainspring is FATIGUED (its card says so); its crew stays.
##   MAINSPRINGS EXHAUST: winding draws its Clocktower's spring life (Defs.TENSION_RESERVE), what went into the pool only.
##   LIMITS: 2 Cog Presses and 1 Mainspring per Clocktower (a second Mainspring is refused; a second tower allows another);
##   a Mainspring placed past the limit by an old save keeps working.
##   The numbers: press small 7.2/s with 5, big 10/s with 8, Winder 60, brass 9,000, spring life 1,320.
##   The "cogs earned" statistic counts income whole (repairs keep their own fraction).
##   godot --headless --fixed-fps 30 --script res://tools/test_exhaust.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _clear_workers(g: Game, t: int) -> void:
	for u in g.workers(t).duplicate():
		u.auto_work = false
		u.cmd_stop()
		g.units.erase(u)
		u.queue_free()


## n new workers of `kind` on building b, stepped until they stand at work.
func _crew(g: Game, b: Building, n: int, kind := "winder") -> Array:
	var ws: Array = []
	for i in n:
		var w: Unit = g._add_unit(kind, b.team, b.center() + Vector2(-60 + i * 22, 70))
		w.auto_work = false
		w.cmd_gather(b)
		ws.append(w)
	var guard := 0
	while b.working_crew() < mini(n, b.crew_max()) and guard < 60:
		U.step(g, 0.5)
		guard += 1
	return ws


func _first(g: Game, t: int, kind: String) -> Building:
	for b in g.buildings:
		if b.team == t and b.kind == kind and not b.dead:
			return b
	return null


func _run() -> void:
	# ---------------------------------------------------------------- the numbers
	check("no Farm trickle (FARM_BASE 0)", Defs.FARM_BASE == 0.0)
	check("no Cog Press trickle (GEAR press base 0)", float(Defs.GEAR["press"]["base"]) == 0.0)
	check("no Mainspring trickle (GEAR mainspring base 0)", float(Defs.GEAR["mainspring"]["base"]) == 0.0)
	check("spent brass, soil, coal pay 0", float(Defs.GEAR["spent"]) == 0.0 and Defs.LODE_SPENT == 0.0 and Defs.SOIL_TIRED == 0.0 and Defs.COAL_SPENT == 0.0)
	var fl := Defs.TENSION_FLOOR
	var pf := Defs.POWDER_FLOOR
	check("the floors: powder 15%, Tension 5% (the owner, 14:47)", is_equal_approx(pf, 0.15) and is_equal_approx(fl, 0.05), "%.2f / %.2f" % [pf, fl])
	check("second_share: 100% fresh, the floor spent, linear between", is_equal_approx(Defs.second_share(1.0, pf), 1.0) and is_equal_approx(Defs.second_share(0.0, pf), pf)
		and is_equal_approx(Defs.second_share(0.5, fl), fl + (1.0 - fl) * 0.5))
	var gp: Dictionary = Defs.GEAR["press"]
	check("press small 7.2/s with 5, big 10/s with 8", is_equal_approx(float(gp["small"]["full"]), 7.2) and int(gp["small"]["crew"]) == 5 \
		and is_equal_approx(float(gp["big"]["full"]), 10.0) and int(gp["big"]["crew"]) == 8, str(gp))
	check("a Winder costs 60", int(Defs.UNITS["winder"]["cost"]) == 60)
	check("brass 9,000 and spring life 1,320 a Clocktower", float(Defs.LODE["clocktower"]) == 9000.0 and Defs.TENSION_RESERVE == 1320.0)
	check("2 Cog Presses and 1 Mainspring per Clocktower", Defs.econ_per_hall("clockwork", "cog_press") == 2 and Defs.econ_per_hall("clockwork", "mainspring") == 1
		and Defs.is_econ("mainspring"), str(Defs.econ_of("clockwork")))
	check("the retired kinds are out of the Clockwork's limits", not Defs.econ_of("clockwork").has("boiler") and not Defs.econ_of("clockwork").has("ore_crusher"))
	check("no Boiler in the worker priority list", not Defs.CREW_TIER.has("boiler"))

	# ---------------------------------------------------------------- no trickle: an empty base earns nothing
	var g := U.make(root)
	await process_frame
	await process_frame
	_clear_workers(g, 0)
	_clear_workers(g, 1)
	await process_frame
	var hall := U.hall(g, 0)
	var th := U.hall(g, 1)
	var press := _first(g, 0, Defs.GEAR_PRESS)
	var farm := _first(g, 1, "farm")
	check("a Clocktower, a Cog Press, a Town Hall and a Farm stand", hall != null and press != null and th != null and farm != null)
	check("the Clocktower holds 9,000 brass and 1,320 spring life", is_equal_approx(hall.lode, 9000.0) and is_equal_approx(hall.soil, 1320.0), "%.0f / %.0f" % [hall.lode, hall.soil])
	var e0 := [int(g.stats[0]["gold"]), int(g.stats[1]["gold"])]
	var gr0 := farm.growth
	U.step(g, 30.0)
	check("nobody at work: the Clockwork earns nothing in 30 s", int(g.stats[0]["gold"]) == e0[0], "%d" % (int(g.stats[0]["gold"]) - e0[0]))
	check("nobody at work: the Crown earns nothing in 30 s", int(g.stats[1]["gold"]) == e0[1], "%d" % (int(g.stats[1]["gold"]) - e0[1]))
	check("an empty Cog Press presses 0", press.press_rate() == 0.0 and press.press_paid == 0.0, "%.2f" % press.press_rate())
	check("an empty Farm grows nothing", farm.farm_speed() == 0.0 and farm.growth == gr0, "%.3f -> %.3f" % [gr0, farm.growth])
	var eff: Array = press.efficiency()
	check("an empty press's efficiency is 0%", not eff.is_empty() and float(eff[0]) == 0.0, str(eff))

	# ---------------------------------------------------------------- the press: crew, then spent brass
	var ws := _crew(g, press, 5)
	check("5 Winders: 7.2 cogs a second", absf(press.press_rate() - 7.2) < 0.01, "%.2f" % press.press_rate())
	var b0 := hall.lode
	var paid0 := press.press_paid
	U.step(g, 5.0)
	check("its cogs come out of the Clocktower's brass", absf((b0 - hall.lode) - (press.press_paid - paid0)) < 0.5 and press.press_paid - paid0 > 30.0,
		"brass -%.1f, paid %.1f" % [b0 - hall.lode, press.press_paid - paid0])
	hall.lode = 0.0
	var paid1 := press.press_paid
	var gold1 := int(g.stats[0]["gold"])
	U.step(g, 5.0)
	check("spent brass: the press is barren and presses 0", press.barren() and press.press_rate() == 0.0 and press.press_paid == paid1, "%.2f" % (press.press_paid - paid1))
	check("spent brass: no cogs earned", int(g.stats[0]["gold"]) == gold1)
	check("spent brass: its crew is let go", press.working_crew() == 0, "%d" % press.working_crew())
	check("spent brass: the card says brass spent", GearEcon.card_text(press).contains(Loc.t("brass spent")), GearEcon.card_text(press))
	for w in ws:
		if is_instance_valid(w):
			w.cmd_stop()
	hall.lode = 9000.0

	# ---------------------------------------------------------------- the Mainspring: spring life, fatigue
	var spring := U.put(g, 0, "mainspring", hall.cell + Vector2i(0, -9))
	check("a Mainspring on the field", spring != null and g.gear_net.is_linked(spring))
	if spring != null:
		check("an empty Mainspring winds 0", spring.spring_rate() == 0.0)
		check("it draws its Clocktower's spring life", g.soil_hall(spring) == hall and is_equal_approx(spring.soil_left(), 1.0))
		var sw := _crew(g, spring, 3)
		check("3 Winders on fresh spring life: 2.0 Tension a second", absf(spring.spring_rate() - 2.0) < 0.01, "%.2f" % spring.spring_rate())
		g.players[0]["tension"] = 0.0
		var life0 := hall.soil
		var tin0 := float(g.stats[0].get("tension_in", 0.0))
		U.step(g, 10.0)
		var wound := float(g.stats[0].get("tension_in", 0.0)) - tin0
		check("what it winds comes out of the spring life", wound > 15.0 and absf((life0 - hall.soil) - wound) < 0.5, "wound %.1f, life -%.1f" % [wound, life0 - hall.soil])
		g.players[0]["tension"] = 190.0           # (the pool all but full: only what goes in is drawn)
		var life1 := hall.soil
		U.step(g, 10.0)
		check("a full pool draws nothing more from the spring life", absf((life1 - hall.soil) - 10.0) < 0.6, "life -%.1f" % (life1 - hall.soil))
		g.players[0]["tension"] = 0.0
		hall.soil = 660.0
		check("half its spring life: it winds less (%.2f/s)" % (2.0 * Defs.second_share(0.5, fl)), absf(spring.spring_rate() - 2.0 * Defs.second_share(0.5, fl)) < 0.01, "%.2f" % spring.spring_rate())
		hall.soil = 0.3          # (near the end it winds at about the floor: 0.1 a second)
		U.step(g, 6.0)
		check("the last of the spring life is drawn", hall.soil <= 0.0, "life %.2f" % hall.soil)
		check("spent: the Mainspring is FATIGUED, not barren", spring.fatigued() and not spring.barren())
		check("spent: it winds at the floor (%.2f/s)" % (2.0 * fl), absf(spring.spring_rate() - 2.0 * fl) < 0.01, "%.2f" % spring.spring_rate())
		var t3 := g.tension(0)
		U.step(g, 10.0)
		check("  and keeps winding at it (10 s: %.1f)" % (20.0 * fl), absf((g.tension(0) - t3) - 20.0 * fl) < 0.5, "+%.2f" % (g.tension(0) - t3))
		check("spent: its crew stays", spring.working_crew() == 3, "%d" % spring.working_crew())
		check("its card says FATIGUED", GearEcon.card_text(spring).contains(Loc.t("FATIGUED")) and GearEcon.card_info(spring).begins_with("FATIGUED"),
			GearEcon.card_text(spring) + " | " + GearEcon.card_info(spring).left(40))
		check("a fatigued Mainspring still drives its rings and stores Tension", GearEcon.tension_cap(g, 0) >= 200.0 and g.gear_net.is_linked(spring))
		var cs := U.chain_spot(g, 0, Defs.CW_WORKS, spring)
		if cs.x >= 0:
			var lw := g._add_building(Defs.CW_WORKS, 0, cs, true)
			g.gear_net.solve()
			check("a Light Works meshing with a FATIGUED Mainspring still counts as meshed (Tension rule)", g.gear_net.spring_for(lw) == spring)
		check("its efficiency is the floor", absf(float(spring.efficiency()[0]) - fl) < 0.01, str(spring.efficiency()))
		for w in sw:
			if is_instance_valid(w):
				w.cmd_stop()
		U.step(g, 2.0)
		check("FATIGUED with nobody on it: it winds nothing (no trickle)", spring.working_crew() == 0 and spring.spring_rate() == 0.0, "%.2f" % spring.spring_rate())
		# ------------------------------------------------------------ the limits
		var c2 := U.linked_spot(g, 0, "mainspring", hall.cell + Vector2i(9, 0))
		var why := g.placement_problem(0, "mainspring", c2) if c2.x >= 0 else ""
		check("1 Mainspring per Clocktower: a second one is refused", g.econ_limit(0, "mainspring") == 1 and (c2.x < 0 or why.contains("allows")), why)
		check("2 Cog Presses per Clocktower", g.econ_limit(0, Defs.GEAR_PRESS) == 2)
		# an old save with two Mainsprings by one Clocktower: both keep working (here: a fresh spring life)
		hall.soil = 1320.0
		hall.soil_warned = 0
		var extra: Building = null
		var cx := Vector2i(-1, -1)
		for y in range(hall.cell.y - 26, hall.cell.y + 27):
			for x in range(hall.cell.x - 26, hall.cell.x + 27):
				var c := Vector2i(x, y)
				if cx.x < 0 and g.in_map(c) and g.margin_free(c, Vector2i(3, 3)) and g.gear_net.candidate(0, "mainspring", c, false)["state"] == "ok" and U._free_fp(g, c, Vector2i(3, 3)) \
						and Vector2(c - hall.cell).length() < 14.0:
					cx = c
		if cx.x >= 0:
			extra = g._add_building("mainspring", 0, cx, true)       # (as a save loads it: past the limit)
			g.gear_net.solve()
		check("an old save's second Mainspring loads", extra != null)
		if extra != null:
			var ew := _crew(g, extra, 2)
			check("and keeps working (winds with its crew)", extra.spring_rate() > 0.0, "%.2f" % extra.spring_rate())
			for w in ew:
				if is_instance_valid(w):
					w.cmd_stop()

	# ---------------------------------------------------------------- the Crown: soil and saltpetre spent pay 0
	var fws := _crew(g, farm, 8, "labourer")
	check("8 Labourers: the Farm at full speed", is_equal_approx(farm.farm_speed(), 1.0), "%.2f" % farm.farm_speed())
	th.soil = 0.0
	check("spent soil: the Farm is barren, a harvest pays 0", farm.barren() and g.harvest_value(farm) == 0)
	var cg := int(g.stats[1]["gold"])
	U.step(g, 45.0)
	check("spent soil: no gold in 45 s", int(g.stats[1]["gold"]) == cg, "%d" % (int(g.stats[1]["gold"]) - cg))
	for w in fws:
		if is_instance_valid(w):
			w.cmd_stop()
	th.soil = 9000.0
	var mc := Vector2i(-1, -1)
	for y in range(th.cell.y - 12, th.cell.y + 13):
		for x in range(th.cell.x - 12, th.cell.x + 13):
			var c := Vector2i(x, y)
			if mc.x < 0 and g.placement_problem(1, "powder_mill", c) == "" and g.margin_free(c, Defs.BUILDINGS["powder_mill"]["size"]):
				mc = c
	var mill: Building = g._add_building("powder_mill", 1, mc, true) if mc.x >= 0 else null
	check("a Powder Mill stands", mill != null)
	if mill != null:
		check("fresh saltpetre: the Mill grinds in full and draws it", absf(g.draw_lode(mill, 10.0) - 10.0) < 0.001 and absf(th.lode - 1310.0) < 0.001, "%.1f left" % th.lode)
		th.lode = 660.0
		check("half the saltpetre: it grinds less", absf(g.draw_lode(mill, 10.0) - 10.0 * Defs.second_share(0.5, pf)) < 0.001)
		th.lode = 0.0
		check("spent saltpetre: the Mill grinds at the floor, is not barren", not mill.barren() and absf(g.draw_lode(mill, 10.0) - 10.0 * pf) < 0.001 and th.lode == 0.0)
		var mw := _crew(g, mill, 6, "labourer")
		var p0 := float(g.players[1]["res2"])
		U.step(g, 10.0)
		var want := Defs.MILL_RATE * 6.0 * 10.0 * pf
		check("6 hands on spent saltpetre: %.1f powder in 10 s" % want, absf((float(g.players[1]["res2"]) - p0) - want) < 1.0 and mill.working_crew() == 6,
			"%.2f, %d at work" % [float(g.players[1]["res2"]) - p0, mill.working_crew()])
		for w in mw:
			if is_instance_valid(w):
				w.cmd_stop()
		U.step(g, 2.0)
		var p1 := float(g.players[1]["res2"])
		U.step(g, 5.0)
		check("nobody at the Mill: no powder (no trickle)", float(g.players[1]["res2"]) == p1)
		var tip := Defs.tip("powder_mill") + " " + String(Defs.BUILDINGS["powder_mill"]["about"])
		check("the Mill's texts never say spent saltpetre pays a quarter", not tip.contains("quarter"))

	# ---------------------------------------------------------------- the statistic: income counted whole
	var s0 := int(g.stats[0]["gold"])
	g.players[0]["repair_f"] = -0.9          # (a repair's fraction pending: it no longer eats the income's)
	g.add_gold_f(0, 5.0)
	check("cogs earned count income whole (repairs keep their own fraction)", int(g.stats[0]["gold"]) - s0 == 5, "%d" % (int(g.stats[0]["gold"]) - s0))
	g.queue_free()
	await process_frame

	# ---------------------------------------------------------------- the Brood: a spent Rootmaw's ground
	var gb := U.make(root, ["brood", "crown"])
	await process_frame
	await process_frame
	var maw: Unit = null
	for u in gb.units:
		if u.team == 0 and u.kind == BroodNew.MAW and not u.dead:
			maw = u
	if maw != null and maw.nb.has("spot") and gb.nb_spots.has(int(maw.nb["spot"])):
		gb.nb_spots[int(maw.nb["spot"])]["left"] = 0.0
		maw.nb["food"] = 0.0
		U.step(gb, 10.0)
		check("the Brood: a Rootmaw on spent ground drinks nothing", float(maw.nb.get("food", 0.0)) < 0.01, "%.2f" % float(maw.nb.get("food", 0.0)))
	else:
		check("the Brood starts with a rooted Rootmaw (to test its ground)", maw != null and maw.nb.has("spot"), "none" if maw == null else "not rooted")
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
