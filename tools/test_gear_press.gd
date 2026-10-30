extends SceneTree
## The Cog Press: nothing by itself (no trickle since 0.24.0), an equal share per Winder winding it up to its crew cap, small vs
## big gear (the numbers and crews from Defs.GEAR "press"), the 2-presses-per-Clocktower limit and what spent brass does
## (nothing: barren, its crew let go; docs/exhaust_economy.md).
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_press.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
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


## Put n Winders on the press and wait until they all stand winding; return the measured cogs a second over 12 s.
func _measure(g: Game, press: Building, n: int) -> Array:
	_clear_workers(g)
	await process_frame
	press.crew.clear()
	var ws: Array = []
	for i in n:
		var w: Unit = g._add_unit("winder", 0, press.center() + Vector2(-60 + i * 22, 70))
		w.auto_work = false
		ws.append(w)
		w.cmd_gather(press)
	var guard := 0
	while press.working_crew() < mini(n, press.crew_max()) and guard < 40:
		U.step(g, 0.5)
		guard += 1
	var before := press.press_paid
	var gold0 := int(g.players[0]["gold"])
	U.step(g, 12.0)
	var rate := (press.press_paid - before) / 12.0
	var res := [rate, press.press_rate(), press.working_crew(), (int(g.players[0]["gold"]) - gold0) / 12.0]
	for w in ws:
		w.cmd_stop()
	return res


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var press: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS:
			press = b
	check("a starting Cog Press stands", press != null)
	if press == null:
		quit(1)
		return
	var gp: Dictionary = Defs.GEAR["press"]
	var base := float(gp["base"])
	var small_full := float(gp["small"]["full"])
	var big_full := float(gp["big"]["full"])
	var sc := int(gp["small"]["crew"])
	var bc := int(gp["big"]["crew"])
	# (the crossovers worked out from Defs.GEAR: the first crew where the big gear pays more than the full small press,
	# with a margin the measurement can tell)
	var cross := bc
	for n in range(1, bc + 1):
		if big_full * (base + (1.0 - base) * float(n) / float(bc)) > small_full + 0.3:
			cross = n
			break
	# SMALL gear
	var r0 = await _measure(g, press, 0)
	check("nobody on it: nothing (no trickle)", base == 0.0 and absf(r0[0]) < 0.01, "%.2f" % r0[0])
	var prev := r0[0] as float
	var small_tot := {}
	for n in [1, sc / 2, sc]:
		var r = await _measure(g, press, n)
		small_tot[n] = r[0]
		var want := small_full * (base + (1.0 - base) * float(n) / float(sc))
		check("small gear, %d Winder%s winding: %.2f cogs/s" % [n, "" if n == 1 else "s", want], absf(r[0] - want) < 0.2 and r[2] == n, "%.2f (%d at work)" % [r[0], r[2]])
		check("  each Winder adds the same share", r[0] > prev, "%.2f > %.2f" % [r[0], prev])
		prev = r[0]
	var r4 = await _measure(g, press, sc + 1)
	check("small gear: Winder %d cannot join (crew cap %d)" % [sc + 1, sc], press.crew_max() == sc and r4[2] == sc and absf(r4[0] - small_full) < 0.2, "%.2f, %d at work" % [r4[0], r4[2]])
	check("the cogs reach the bank (gold rose by the same rate)", absf(r4[3] - r4[0]) < 0.6, "%.2f vs %.2f" % [r4[3], r4[0]])
	# BIG gear
	press.gear_big = true
	var big_tot := {}
	for n in [1, cross - 1, cross, bc]:
		var r = await _measure(g, press, n)
		big_tot[n] = r[0]
		var want := big_full * (base + (1.0 - base) * float(n) / float(bc))
		check("big gear, %d Winder%s: %.2f cogs/s (crew cap %d)" % [n, "" if n == 1 else "s", want, bc], absf(r[0] - want) < 0.25 and r[2] == n, "%.2f (%d at work)" % [r[0], r[2]])
	check("big gear is slower per Winder at low crew (1 Winder)", big_tot[1] < small_tot[1], "%.2f < %.2f" % [big_tot[1], small_tot[1]])
	check("big gear does NOT clearly beat the full small press at %d Winders" % (cross - 1), big_tot[cross - 1] <= small_full + 0.3, "%.2f <= %.2f" % [big_tot[cross - 1], small_full + 0.3])
	check("big gear beats it at %d Winders" % cross, big_tot[cross] > small_full + 0.3, "%.2f > %.2f" % [big_tot[cross], small_full])
	check("big gear has the higher total at full crew", big_tot[bc] > small_full * 1.2, "%.2f" % big_tot[bc])
	# the brass: spent, it yields nothing (EXHAUSTED MEANS EXHAUSTED, 0.24.0)
	var tower := U.hall(g, 0)
	press.gear_big = false
	tower.lode = 0.0
	var rs = await _measure(g, press, sc)
	check("spent brass: the press yields nothing", absf(rs[0]) < 0.01, "%.2f" % rs[0])
	check("and it is barren: its crew is let go", press.barren() and rs[2] == 0, "%d at work" % rs[2])
	tower.lode = tower.lode_full()
	# at most 2 presses per Clocktower
	var second := U.put(g, 0, Defs.GEAR_PRESS, tower.cell)
	check("a second press can be built", second != null and g.econ_count(0, Defs.GEAR_PRESS) == 2)
	var third := Vector2i(-1, -1)
	for y in range(tower.cell.y - 20, tower.cell.y + 21):
		for x in range(tower.cell.x - 20, tower.cell.x + 21):
			var c := Vector2i(x, y)
			if third.x < 0 and g.in_map(c) and g.margin_free(c, Vector2i(3, 3)) and g.gear_net.candidate(0, Defs.GEAR_PRESS, c)["state"] == "ok":
				third = c
	var why := g.placement_problem(0, Defs.GEAR_PRESS, third) if third.x >= 0 else "no spot"
	check("a third press is refused (2 per Clocktower)", why != "" and why.contains("Each"), why)
	# the winders come from the Crown farm logic: right-click a worker onto the press (cmd_gather) is what _measure used
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
