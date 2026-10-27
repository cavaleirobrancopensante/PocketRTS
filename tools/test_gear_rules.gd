extends SceneTree
## THE GEAR RULES for base building (owner, 2026-10-27; docs/gear_rules.md):
##  1. THE TURRET CIRCLE: a Ratchet Turret claims a circle of ground (Defs.TURRET "claim" tiles) and two turrets' circles may
##     not overlap: a second turret too close is refused with the reason (TOO NEAR A TURRET on the ghost), one far enough is
##     accepted; the computer's spot search (Game.find_spot, the one AI._construct uses) never picks a spot too close; an
##     old save with two turrets side by side loads and keeps both.
##  2. THE HEAVY WORKS trains the Pendulum and the Spring Ballista, only while a Mainspring's ring meshes with its ring
##     (idle and refusing them otherwise); it sits on its big gear only; the Light Works (internal id movement_works) no
##     longer makes them, and is called the Light Works.
##  3. SIZE SETS THE TEMPO: a Light Works trains 15% faster on its small ring and 15% slower on its big one; the Escapement
##     researches 10% faster or slower; a Ratchet Turret fires quick light screws on its small ring and slow heavy ones on
##     its big ring (the numbers in Defs.TURRET), the reach the same.
##  4. THE MACHINE IN THE BAY: while the Heavy Works trains, its bay shows that unit, built up as the training goes on;
##     an empty bay when idle.
##  5. The brass floor plate for the Tension users, the gear view's toggle, and saves keep the Heavy Works, its queue and the
##     ring sizes.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_rules.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-76s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	g.players[0]["gold"] = 50000
	g.players[0]["tension"] = 5000.0
	var hall := U.hall(g, 0)
	var T := float(Defs.TILE)
	var claim := float(Defs.TURRET["claim"]) * T
	# ---------------------------------------------------------------- 1. the turret circles
	var lw := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	check("a Light Works stands (needed for turrets)", lw != null)
	var t1 := U.put(g, 0, Defs.CW_TURRET, hall.cell)
	check("a first Ratchet Turret stands", t1 != null)
	var near := Vector2i(-1, -1)
	var far := Vector2i(-1, -1)
	for y in range(hall.cell.y - 26, hall.cell.y + 27):
		for x in range(hall.cell.x - 26, hall.cell.x + 27):
			var c := Vector2i(x, y)
			if not g.in_map(c) or not g.margin_free(c, Defs.BUILDINGS[Defs.CW_TURRET]["size"]):
				continue
			var d := GearNet.turret_mid(c).distance_to(t1.center())
			# (a spot that would link by the ring rule, so only the circle can refuse it)
			var gst: Dictionary = g.gear_net.candidate(0, Defs.CW_TURRET, c)
			if near.x < 0 and d < 2.0 * claim - 8.0 and gst["state"] == "turret":
				near = c
			if far.x < 0 and d >= 2.0 * claim and g.placement_problem(0, Defs.CW_TURRET, c) == "":
				far = c
	check("a spot too near the first turret exists on the field", near.x >= 0)
	if near.x >= 0:
		var why := g.placement_problem(0, Defs.CW_TURRET, near)
		check("a second turret too near is refused, with the reason", why.contains("Too near a Ratchet Turret"), why)
		var gt: Array = g.gear_net.ghost_text(0, Defs.CW_TURRET, near)
		check("the ghost says TOO NEAR A TURRET, in red", String(gt[0]).contains("TOO NEAR A TURRET") and (gt[1] as Color).r > 0.9 and (gt[1] as Color).g < 0.6, String(gt[0]))
		check("another kind may go there (the circle is only for turrets)", g.gear_net.candidate(0, Defs.CW_SUPPLY, near)["state"] != "turret")
	check("a turret far enough (two circles apart) is accepted", far.x >= 0 and g.place_building(0, Defs.CW_TURRET, far, []) != null, str(far))
	# a site counts too: no third one inside the new site's circle
	if far.x >= 0:
		var hit := GearNet.turret_overlaps(g, 0, GearNet.turret_mid(far) + Vector2(T, 0))
		check("a planned turret claims its circle too", not hit.is_empty())
	# the computer's spot search (AI._construct -> AI._find_spot -> Game.find_spot) obeys it
	var spot := g.find_spot(0, Defs.CW_TURRET, hall, 3, 26, "near", true)
	var ok := spot.x >= 0
	if ok:
		for b in g.buildings:
			if b.kind == Defs.CW_TURRET and b.team == 0 and not b.dead and GearNet.turret_circles_overlap(b.center(), GearNet.turret_mid(spot)):
				ok = false
	check("the computer's spot search picks a turret spot clear of every circle", ok, str(spot))
	# the enemy's turrets do not count (a side's own circles only)
	check("another side's turret circle does not stop this one", GearNet.turret_overlaps(g, 1, t1.center()).is_empty())
	# ---------------------------------------------------------------- 2. the Heavy Works
	var hd: Dictionary = Defs.BUILDINGS[Defs.CW_HEAVY]
	check("the Heavy Works is called the Heavy Works", String(hd["name"]) == "Heavy Works")
	check("the Movement Works is called the Light Works", String(Defs.BUILDINGS[Defs.CW_WORKS]["name"]) == "Light Works")
	check("the Heavy Works trains the Pendulum and the Ballista", (hd["trains"] as Array).has(Defs.PENDULUM) and (hd["trains"] as Array).has(Defs.BALLISTA_KIND))
	check("the Light Works trains the Clock Soldier, the Springer and the Netter only", Defs.BUILDINGS[Defs.CW_WORKS]["trains"] == ["clock_soldier", "springer", "netter"], str(Defs.BUILDINGS[Defs.CW_WORKS]["trains"]))
	check("it is in the gear-mode build list", Defs.build_list("clockwork").has(Defs.CW_HEAVY))
	check("it is a Tension user (it must mesh with a Mainspring)", Defs.TENSION_USERS.has(Defs.CW_HEAVY))
	check("it needs a working Escapement to be placed", g.requirement_text(0, Defs.CW_HEAVY) != "", g.requirement_text(0, Defs.CW_HEAVY))
	var esc := U.put(g, 0, Defs.CW_TECH, hall.cell)
	var sp := _spring_beside(g, esc)
	U.step(g, 0.6)
	check("an Escapement works by a Mainspring", sp != null and g.has_working(0, Defs.CW_TECH))
	check("then the Heavy Works may be placed", g.requirement_text(0, Defs.CW_HEAVY) == "", g.requirement_text(0, Defs.CW_HEAVY))
	var hw := _heavy_alone(g, hall)
	check("a Heavy Works stands away from every Mainspring", hw != null)
	if hw == null:
		_end(g)
		return
	U.step(g, 0.6)
	g.players[0]["cap"] = 200
	check("it sits on its BIG gear (the big ring's teeth)", hw.gear_big and GearNet.b_n(hw) == GearNet.ring_n(Defs.CW_HEAVY, hw.size, true))
	check("it cannot swap to the small gear", g.gear_swap_problem(hw) != "", g.gear_swap_problem(hw))
	check("without a Mainspring it stands idle (NEEDS MAINSPRING)", g.gear_net.needs_spring(hw))
	var why2 := g.can_train(hw, Defs.PENDULUM)
	check("and refuses the Pendulum", why2 != "", why2)
	why2 = g.can_train(hw, Defs.BALLISTA_KIND)
	check("and the Ballista", why2 != "", why2)
	var hsp := _spring_beside(g, hw)
	U.step(g, 0.6)
	g.players[0]["cap"] = 200
	check("a Mainspring put beside it meshes with it", hsp != null and g.gear_net.spring_for(hw) == hsp)
	why2 = g.can_train(hw, Defs.PENDULUM)
	check("now it trains the Pendulum", why2 == "", why2)
	why2 = g.can_train(hw, Defs.BALLISTA_KIND)
	check("and the Ballista", why2 == "", why2)
	if lw != null:
		check("the Light Works refuses the Pendulum", g.can_train(lw, Defs.PENDULUM) != "")
		check("and the Ballista", g.can_train(lw, Defs.BALLISTA_KIND) != "")
	check("its floor plate is brass, the Light Works' iron", GearNet.brass_plate(Defs.CW_HEAVY) and GearNet.brass_plate("mainspring") and GearNet.brass_plate(Defs.CW_TECH) \
			and GearNet.brass_plate(Defs.CW_AIR) and not GearNet.brass_plate(Defs.CW_WORKS) and not GearNet.brass_plate(Defs.CW_TURRET))
	# ---------------------------------------------------------------- 4. the machine in the bay
	check("idle: the bay is empty", hw.bay != null and HeavyWorks.machine_of(hw) == "")
	g.train(hw, Defs.PENDULUM)
	U.step(g, 2.0)
	hw.bay._process(0.0)
	check("training: the bay shows the Pendulum", hw.bay.shown == Defs.PENDULUM, hw.bay.shown)
	var s0: float = hw.bay.built_share
	U.step(g, float(Defs.UNITS[Defs.PENDULUM]["time"]) * 0.6)
	hw.bay._process(0.0)
	var s1: float = hw.bay.built_share
	check("it is built up as the training goes on", s0 > 0.0 and s1 > s0 and s1 < 1.01, "%.2f -> %.2f" % [s0, s1])
	U.step(g, float(Defs.UNITS[Defs.PENDULUM]["time"]) * 0.5 + 1.0)
	hw.bay._process(0.0)
	check("the Pendulum came out and the bay is empty again", hw.bay.shown == "" and g.units.any(func(u: Unit) -> bool: return u.team == 0 and u.kind == Defs.PENDULUM and not u.dead))
	g.train(hw, Defs.BALLISTA_KIND)
	U.step(g, 3.0)
	hw.bay._process(0.0)
	check("a Ballista in training is shown in the bay", hw.bay.shown == Defs.BALLISTA_KIND, hw.bay.shown)
	# ---------------------------------------------------------------- 3. size sets the tempo
	if lw != null:
		var m_small := g.gear_net.speed_mult(lw)
		lw.gear_big = true
		g.gear_net.solve()
		var m_big := g.gear_net.speed_mult(lw)
		check("the Light Works: small ring 15% faster, big 15% slower than its drive", m_small > 0.0 and is_equal_approx(m_small / GearEcon.work_mult(g.gear_net, lw), 1.15) \
				and is_equal_approx(m_big / GearEcon.work_mult(g.gear_net, lw), 0.85), "%.3f / %.3f" % [m_small, m_big])
		# and in training: the same Clock Soldier, the same seconds, on each ring
		var made := _train_share(g, lw, "clock_soldier", 3.0)
		lw.gear_big = false
		g.gear_net.solve()
		var made2 := _train_share(g, lw, "clock_soldier", 3.0)
		check("a Clock Soldier's training goes 1.15/0.85 as fast on the small ring", made > 0.0 and absf(made2 / made - 1.15 / 0.85) < 0.06, "%.3f vs %.3f" % [made2, made])
		check("its card says the trade in one line", GearEcon.trade_line(Defs.CW_WORKS, false).contains("15% faster"), GearEcon.trade_line(Defs.CW_WORKS, false))
		check("its efficiency (crew x drive) does not count the tempo", lw.efficiency().is_empty() or float(lw.efficiency()[0]) <= 1.0001)
	var e_small := g.gear_net.speed_mult(esc)
	esc.gear_big = true
	g.gear_net.solve()
	var e_big := g.gear_net.speed_mult(esc)
	esc.gear_big = false
	g.gear_net.solve()
	check("the Escapement researches 10% faster on its small ring (and 10% slower on its big one)", e_small > 0.0 and absf(e_small / e_big - 1.1 / 0.9) < 0.01, "%.3f / %.3f" % [e_small, e_big])
	check("the Heavy Works' card says big gear only", GearEcon.trade_line(Defs.CW_HEAVY, true).contains("Big gear only"))
	# the turret: small quick and light, big slow and heavy, the same reach
	# (nothing else of ours fights: the Pendulum out, the Heavy Works' order cancelled)
	g.cancel_train(hw)
	for u in g.units.duplicate():
		if u.team == 0 and not u.is_worker():
			g.units.erase(u)
			u.queue_free()
	await process_frame
	var sw: Dictionary = RatchetTurret.screw(t1)
	check("a small-ring turret fires %d every %.1f s" % [int(Defs.TURRET["small"]["damage"]), float(Defs.TURRET["small"]["cooldown"])], not t1.gear_big and float(sw["damage"]) == float(Defs.TURRET["small"]["damage"]))
	var hits_small := await _turret_volley(g, t1, false)
	var hits_big := await _turret_volley(g, t1, true)
	var dmg_s := float(Defs.TURRET["small"]["damage"])
	var dmg_b := float(Defs.TURRET["big"]["damage"])
	check("small ring: quick light screws (shots and damage per shot)", hits_small[0] >= 6 and absf(float(hits_small[1]) - (dmg_s - 2.0)) < 0.6, str(hits_small))
	check("big ring: slow heavy screws, fewer shots that each hit harder", hits_big[0] >= 3 and hits_big[0] < hits_small[0] and absf(float(hits_big[1]) - (dmg_b - 2.0)) < 0.6, str(hits_big))
	check("against armour 2, the big screw does more a second", float(hits_big[2]) > float(hits_small[2]), "%.1f vs %.1f" % [hits_big[2], hits_small[2]])
	check("the reach is the same and under a Crown gun's", float(Defs.TURRET["range"]) < 400.0)
	# ---------------------------------------------------------------- 6. the gear view
	g.toggle_gear_view()
	check("the gear view turns on", g.gear_net.view)
	g.gear_net.queue_redraw()
	await process_frame
	check("the gear view colours a driver gold and a full-speed ring green", g.gear_net.view_colour(sp).r > 0.9 and g.gear_net.view_colour(sp).b < 0.6 and g.gear_net.view_colour(esc).g > 0.9)
	g.toggle_gear_view()
	check("and off again", not g.gear_net.view)
	# ---------------------------------------------------------------- 5. saves keep it all, and old turrets side by side
	var tA: Building = g._add_building(Defs.CW_TURRET, 0, t1.cell + Vector2i(0, 3), true)      # (too close: as an old save had it)
	if tA != null:
		tA.gear_big = true
	g.gear_net.solve()
	if lw != null:
		lw.gear_big = true
	g.train(hw, Defs.PENDULUM)
	var q0 := hw.queue.duplicate()
	g.demo = false          # (a demo game is never saved)
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 4242})
	var d := SaveGame.peek()
	var g2 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g2, d)
	await process_frame
	g2.gear_net.solve()
	var hw2 := _find(g2, Defs.CW_HEAVY, hw.cell)
	check("the Heavy Works is there after a load, on its big gear", hw2 != null and hw2.gear_big)
	check("with its queue", hw2 != null and hw2.queue == q0, str(hw2.queue if hw2 else []))
	check("it meshes with its Mainspring again", hw2 != null and g2.gear_net.spring_for(hw2) != null)
	check("its bay is drawn again", hw2 != null and hw2.bay != null)
	var turrets2 := g2.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.kind == Defs.CW_TURRET and not b.dead)
	check("an old save's turrets inside each other's circles are all kept", tA != null and turrets2.size() == g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.kind == Defs.CW_TURRET and not b.dead).size(), "%d" % turrets2.size())
	var tA2 := _find(g2, Defs.CW_TURRET, t1.cell + Vector2i(0, 3))
	check("and the big-ring turret is still on its big gear", tA2 != null and tA2.gear_big)
	if lw != null:
		var lw2 := _find(g2, Defs.CW_WORKS, lw.cell)
		check("the Light Works' big gear is kept", lw2 != null and lw2.gear_big)
	SaveGame.clear()
	_end(g)


func _end(g: Game) -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)


func _find(g: Game, kind: String, cell: Vector2i) -> Building:
	for b in g.buildings:
		if b.kind == kind and b.cell == cell and not b.dead:
			return b
	return null


## A finished Mainspring whose ring meshes with b's, linked; null if none fits.
func _spring_beside(g: Game, b: Building) -> Building:
	for deg in [0.0, 60.0, 120.0, 180.0, -60.0, -120.0, 30.0, 150.0, -30.0, -150.0, 90.0, -90.0]:
		var c := GearNet.ring_spot(g, 0, "mainspring", b, deg, true)
		if c.x >= 0:
			var m: Building = g._add_building("mainspring", 0, c, true)
			g.gear_net.solve()
			return m
	return null


## A finished Heavy Works on a spot that links but meshes with no Mainspring (so it starts idle).
func _heavy_alone(g: Game, hall: Building) -> Building:
	for y in range(hall.cell.y - 24, hall.cell.y + 25):
		for x in range(hall.cell.x - 24, hall.cell.x + 25):
			var c := Vector2i(x, y)
			if not g.in_map(c) or g.placement_problem(0, Defs.CW_HEAVY, c) != "" or not g.margin_free(c, Defs.BUILDINGS[Defs.CW_HEAVY]["size"]):
				continue
			var st: Dictionary = g.gear_net.candidate(0, Defs.CW_HEAVY, c)
			if st["state"] == "ok" and st.get("spring") == null:
				var b := g._add_building(Defs.CW_HEAVY, 0, c, true)
				g.gear_net.solve()
				return b
	return null


## The share of a unit's training a building gets through in `secs` (from an empty queue; refunded after).
func _train_share(g: Game, b: Building, kind: String, secs: float) -> float:
	b.queue.clear()
	b.prod_t = 0.0
	g.players[0]["cap"] = 200
	if g.train(b, kind) != "":
		return 0.0
	U.step(g, secs)
	var f := b.prod_t / Building.entry_time(kind)
	g.cancel_train(b)
	return f


## A Ratchet Turret on its small (or big) ring against one armoured target (armour 2) standing in its reach for 10 s:
## [shots, damage per shot, damage a second].
func _turret_volley(g: Game, tr: Building, big: bool) -> Array:
	tr.gear_big = big
	g.gear_net.solve()
	tr.turret.cd = 0.0
	var at := tr.center() + Vector2(0, 120)
	var foe: Unit = g._add_unit("musketeer", 1, g.cell_center(g.nearest_free(g.cell_of(at), 4)))
	foe.auto_work = false
	foe.cmd_hold()
	foe.armor = 2
	foe.max_hp = 100000.0
	foe.hp = 100000.0
	await process_frame
	var n0 := tr.turret.shots
	var hp0: float = foe.hp
	U.step(g, 10.0)
	var shots := tr.turret.shots - n0
	var lost := hp0 - foe.hp
	g.units.erase(foe)
	foe.queue_free()
	await process_frame
	tr.gear_big = false
	g.gear_net.solve()
	return [shots, lost / maxf(shots, 1), lost / 10.0]
