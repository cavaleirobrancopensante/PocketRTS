extends SceneTree
## THE GREAT WINDER (scripts/great_winder.gd, Defs.GREAT_WINDER, docs/great_winder.md): made at the Heavy Works (0.14.85) once an
## Escapement works (cogs and Tension); its walk is played so the feet do not slide; it WINDS the constructs inside its
## area (a run-down one wakes) and not the ones outside, and never runs down itself; MEND (autocast, on from the start)
## mends a hurt Clockwork unit near it, costs cogs, and stops when switched off; it never mends a Crown unit; SWEEP
## (autocast) sweeps its own side's Clockwork wrecks into PARTS, never a Crown body, up to the cap; a save keeps its parts
## and switches; online the guest gets its parts (the same snapshot rows a replay records); and the COMPUTER builds one and
## sends it with its army, with a smaller escort of Winders.
##   godot --headless --fixed-fps 30 --script res://tools/test_great_winder.gd
const U := preload("res://tools/gear_test_util.gd")
const K := Defs.GREAT_WINDER_KIND
const G := Defs.GREAT_WINDER
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	_roster(g)
	_winding(g)
	await _mending(g)
	_sweeping(g)
	await _save(g)
	g.queue_free()
	await process_frame
	await _online()
	await _computer()
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers

func _clear(g: Game) -> void:
	for u in g.units.duplicate():
		if is_instance_valid(u) and not u.is_worker():
			g.units.erase(u)
			g.selection.erase(u)
			u.queue_free()
	for b in g.bodies.duplicate():
		if is_instance_valid(b):
			g.bodies.erase(b)
			g.corpses.erase(b)
			g.fallen.erase(b)
			b.queue_free()
	for u in g.units:
		u.auto_work = false
		u.auto_repair = false
		u.cmd_stop()


## An open spot well off the gear field (where constructs run down).
func _off_field(g: Game) -> Vector2:
	var hall := U.hall(g, 0)
	for r in [700.0, 900.0, 1100.0, 1300.0, 600.0]:
		for deg in range(0, 360, 20):
			var p: Vector2 = g.on_map(hall.center() + Vector2.from_angle(deg_to_rad(deg)) * r)
			var c := g.cell_of(p)
			if g.is_free(c) and not g.in_field(0, p):
				var ok := true
				for d in [Vector2(-300, 0), Vector2(300, 0), Vector2(0, 260), Vector2(0, -260)]:
					var q: Vector2 = p + d
					if not g.in_map(g.cell_of(q)) or g.in_field(0, q):
						ok = false
				if ok:
					return g.cell_center(c)
	return g.cell_center(g.cell_of(g.on_map(hall.center() + Vector2(900, 0))))


func _spot(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	return g.cell_center(c if g.is_free(c) else g.nearest_free(c, 6))


func _gw(g: Game, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(K, 0, p)
	u.cmd_stop()
	g.camera.position = p
	g.view_rect = Rect2(p - Vector2(900, 600), Vector2(1800, 1200))
	return u


func _man(g: Game, kind: String, team: int, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, team, _spot(g, p))
	u.auto_work = false
	u.auto_repair = false
	u.cmd_hold()
	if team != 0:
		u.d = u.d.duplicate()
		u.d["damage"] = 0
	return u


## A unit killed and lying at rest (a body: Game.bodies).
func _wreck(g: Game, u: Unit) -> void:
	u.take_damage(100000.0, null)
	u._rest_in_peace()


# ------------------------------------------------------------------ the unit

func _roster(g: Game) -> void:
	var wd: Dictionary = Defs.BUILDINGS[Defs.CW_HEAVY]
	check("the Heavy Works trains the Great Winder (0.14.85)", (wd["trains"] as Array).has(K))
	check("the Light Works does not", not (Defs.BUILDINGS[Defs.CW_WORKS]["trains"] as Array).has(K))
	check("it is in the gear-mode roster (not retired)", Defs.CW_NEW_UNITS.has(K) and not Defs.retired(K))
	check("its price is cogs and Tension", g.unit_price(0, K) == [int(Defs.UNITS[K]["cost"]), int(Defs.UNITS[K]["tension"])], str(g.unit_price(0, K)))
	check("it has no weapon", Defs.UNITS[K].get("no_attack", false) and not g._add_unit(K, 0, U.hall(g, 0).center() + Vector2(0, 200)).has_attack())
	check("its walk is played so the feet do not slide (16 px a 12-frame loop)", is_equal_approx(Unit.walk_fps_for(K), GreatWinder.walk_fps()),
		"%.2f vs %.2f" % [Unit.walk_fps_for(K), GreatWinder.walk_fps()])
	var fr: Dictionary = ArtData.UNITS[K]["frames"]
	check("its strips are in: walk 12, wind 8, sweep 8, idle, death", int(fr.get("walk_se", 0)) == 12 and int(fr.get("wind_e", 0)) == 8 \
		and int(fr.get("sweep_n", 0)) == 8 and int(fr.get("idle_s", 0)) >= 1 and int(fr.get("death_ne", 0)) >= 3, str(fr))
	g.players[0]["gold"] = 50000
	g.players[0]["tension"] = 5000.0
	var hall := U.hall(g, 0)
	var lw := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	g._recount_supply(0)
	g.players[0]["cap"] = 200
	check("no Escapement: the Heavy Works cannot be placed", g.requirement_text(0, Defs.CW_HEAVY) != "", g.requirement_text(0, Defs.CW_HEAVY))
	var esc := U.put(g, 0, Defs.CW_TECH, hall.cell)
	_spring_beside(g, esc)
	U.step(g, 0.6)
	var works := U.put(g, 0, Defs.CW_HEAVY, hall.cell)
	if g.gear_net.spring_for(works) == null:
		_spring_beside(g, works)
	U.step(g, 0.6)
	g.players[0]["cap"] = 200
	var why := g.can_train(works, K)
	check("with a working Escapement (and a Mainspring at the Heavy Works) it trains", why == "", why)
	check("the Light Works refuses it", lw == null or g.can_train(lw, K) != "")
	var ten0 := g.tension(0)
	why = g.train(works, K)
	check("the order spends its Tension", why == "" and is_equal_approx(g.tension(0), ten0 - float(Defs.UNITS[K]["tension"])), why)
	U.step(g, float(Defs.UNITS[K]["time"]) + 2.0)
	var made := g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == K and not u.dead)
	check("a Great Winder came out, MEND and SWEEP on", made.size() >= 1 and made.all(func(u: Unit) -> bool: return u.auto_repair and u.auto_sweep), "%d" % made.size())
	_clear(g)


func _winding(g: Game) -> void:
	var at := _off_field(g)
	check("the test spot is off the gear field", not g.in_field(0, at))
	var gw := _gw(g, at)
	gw.auto_repair = false
	gw.auto_sweep = false
	var near := _man(g, "clock_soldier", 0, at + Vector2(110, 30))
	var far := _man(g, "clock_soldier", 0, at + Vector2(0, float(G["area"]) + 140.0))
	near.wind = 0.0          # (a run-down statue)
	far.wind = 0.5
	U.step(g, 0.5)
	check("the soldier inside is run down to start with", near.powered_down() or near.wind < 0.05, "%.2f" % near.wind)
	U.step(g, 10.0)
	var gain := float(G["wind"]) - Defs.WIND_DECAY
	check("inside its area a run-down soldier winds up and wakes", near.wind > 10.0 * gain * 0.8 and not near.powered_down(), "%.3f (expected about %.3f)" % [near.wind, 10.0 * gain])
	check("outside it a soldier runs down as before", far.wind < 0.5 - 10.0 * Defs.WIND_DECAY * 0.5, "%.3f" % far.wind)
	check("the Great Winder never runs down itself", gw.wind >= 0.99 and not gw.powered_down(), "%.2f" % gw.wind)
	check("a Winder is not wound by it (Winders wind themselves)", not GreatWinder.windable(gw, _man(g, "winder", 0, at + Vector2(-60, 40))))
	_clear(g)


func _mending(g: Game) -> void:
	var at := _off_field(g)
	var gw := _gw(g, at)
	gw.auto_sweep = false
	var hurt := _man(g, "clock_soldier", 0, at + Vector2(140, 40))
	hurt.hp = hurt.max_hp * 0.3
	var foe_hurt := _man(g, "musketeer", 1, at + Vector2(-120, 30))
	foe_hurt.hp = foe_hurt.max_hp * 0.3
	var spent0 := float(g.stats[0].get("repair", 0.0))
	var t := 0.0
	var seen_wind := false
	while hurt.hp < hurt.max_hp and t < 20.0:
		g.camera.position = gw.position         # (units animate only on screen: the camera follows it)
		await process_frame
		U.step(g, 0.2)
		t += 0.2
		if gw.anim == "wind" and gw.work == "mending":
			seen_wind = true
	check("MEND: it walks over and mends the hurt Clock Soldier", hurt.hp >= hurt.max_hp - 0.5, "%.0f/%.0f after %.1f s" % [hurt.hp, hurt.max_hp, t])
	var winder_t := hurt.max_hp * 0.7 / maxf(Defs.REPAIR_RATE, hurt.max_hp / float(hurt.d["time"]))
	check("faster than a Winder would (x%.1f)" % float(G["mend"]), t < winder_t + 6.0, "%.1f s (a Winder: %.1f s at the unit)" % [t, winder_t])
	check("it plays its key arm (wind) while mending", seen_wind)
	check("mending costs cogs", float(g.stats[0].get("repair", 0.0)) > spent0, "%.1f cogs" % (float(g.stats[0].get("repair", 0.0)) - spent0))
	check("it never mends an enemy (nor a Crown unit)", foe_hurt.hp <= foe_hurt.max_hp * 0.3 + 0.01 and not GreatWinder.can_mend(gw, foe_hurt))
	# MEND off: it leaves a hurt one alone
	gw.auto_repair = false
	gw.cmd_stop()
	var hurt2 := _man(g, "clock_soldier", 0, gw.position + Vector2(-80, 50))
	hurt2.hp = hurt2.max_hp * 0.4
	U.step(g, 6.0)
	check("MEND off: it leaves the hurt soldier alone", hurt2.hp <= hurt2.max_hp * 0.4 + 0.01, "%.0f" % hurt2.hp)
	# a right-click order mends too (its cmd_repair is MEND)
	gw.cmd_repair(hurt2)
	U.step(g, 8.0)
	check("a right-click on a hurt unit sends it to mend it", hurt2.hp > hurt2.max_hp * 0.8, "%.0f/%.0f" % [hurt2.hp, hurt2.max_hp])
	_clear(g)


func _sweeping(g: Game) -> void:
	var at := _off_field(g)
	var gw := _gw(g, at)
	gw.auto_repair = false
	var own: Array = []
	for i in 3:
		own.append(_man(g, "clock_soldier", 0, at + Vector2(90 + i * 30, 60)))
	var pend := _man(g, "pendulum", 0, at + Vector2(-90, 60))
	var crown := _man(g, "musketeer", 1, at + Vector2(-60, -80))
	for u in own + [pend, crown]:
		_wreck(g, u)
	check("the wrecks and the Crown body lie there", own.all(func(u: Unit) -> bool: return g.bodies.has(u)) and g.bodies.has(crown) and g.bodies.has(pend))
	check("a Crown body is never sweepable", not GreatWinder.sweepable(gw, crown))
	var expect := 0
	for u in own + [pend]:
		expect += GreatWinder.parts_of(u)
	var t := 0.0
	var seen_sweep := false
	while (own + [pend]).any(func(u) -> bool: return is_instance_valid(u) and g.bodies.has(u)) and t < 40.0:
		U.step(g, 0.2)
		t += 0.2
		if gw.anim == "sweep":
			seen_sweep = true
	check("SWEEP: it sweeps up its own side's Clockwork wrecks", (own + [pend]).all(func(u) -> bool: return not is_instance_valid(u) or not g.bodies.has(u)), "%.1f s" % t)
	check("it plays its rollers (sweep) while sweeping", seen_sweep)
	check("and keeps them as parts (by their price)", gw.parts == expect and gw.parts > 0, "%d (expected %d)" % [gw.parts, expect])
	check("a Pendulum's wreck gives more parts than a Clock Soldier's", GreatWinder.parts_of(pend) > GreatWinder.parts_of(own[0]) if is_instance_valid(pend) and is_instance_valid(own[0]) else true)
	U.step(g, 3.0)
	check("the Crown body is left lying (its bodies are never swept)", is_instance_valid(crown) and g.bodies.has(crown) and not crown.torn)
	# the cap
	gw.parts = int(G["cap"]) - 1
	var a := _man(g, "clock_soldier", 0, gw.position + Vector2(70, 40))
	var b := _man(g, "clock_soldier", 0, gw.position + Vector2(-70, 40))
	_wreck(g, a)
	_wreck(g, b)
	U.step(g, 12.0)
	check("parts stop at the cap (%d)" % int(G["cap"]), gw.parts == int(G["cap"]), "%d" % gw.parts)
	check("a full hopper leaves the next wreck lying", (is_instance_valid(a) and g.bodies.has(a)) or (is_instance_valid(b) and g.bodies.has(b)))
	# SWEEP off
	gw.parts = 0
	var c := _man(g, "clock_soldier", 0, gw.position + Vector2(60, -40))
	_wreck(g, c)
	gw.auto_sweep = false
	gw.cmd_stop()
	U.step(g, 6.0)
	check("SWEEP off: it leaves the wrecks alone", gw.parts == 0 and is_instance_valid(c) and g.bodies.has(c), "%d" % gw.parts)
	_clear(g)


func _save(g: Game) -> void:
	var at := _off_field(g)
	var gw := _gw(g, at)
	gw.parts = 37
	gw.auto_sweep = false
	gw.auto_repair = true
	g.demo = false
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 4242})
	g.demo = true
	var sd := SaveGame.peek()
	var g3 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g3, sd)
	await process_frame
	var back: Array = g3.units.filter(func(u: Unit) -> bool: return u.kind == K and not u.dead)
	check("a save keeps the Great Winder, its parts and its switches", back.size() == 1 and back[0].parts == 37 and not back[0].auto_sweep and back[0].auto_repair,
		"%s" % str(back.map(func(u: Unit) -> Array: return [u.parts, u.auto_repair, u.auto_sweep])))
	SaveGame.clear()
	g3.process_mode = Node.PROCESS_MODE_DISABLED
	g3.queue_free()
	_clear(g)


## ONLINE (and replays, which record the same snapshot rows): the guest gets its parts and its SWEEP switch.
func _online() -> void:
	var h := U.make(root, ["clockwork", "crown"])
	var gu := Game.new()
	gu.map_id = h.map_id
	gu.demo = true
	gu.factions = ["clockwork", "crown"]
	gu.sides = [0, 1]
	gu.puppet = true
	root.add_child(gu)
	await process_frame
	await process_frame
	var sh := NetSession.attach(h, NetLink.new(), true, 0, {1: 1})
	var sg := NetSession.attach(gu, NetLink.new(), false, 1, {})
	sh.set_process(false)
	var sync := func() -> void:
		sh.snap_n = 1
		var m := NetSnapshot.build(sh)
		NetSnapshot.apply(sg, NetCodec.unpack(NetCodec.pack(m)))
	var hall := U.hall(h, 0)
	var gw: Unit = h._add_unit(K, 0, _spot(h, hall.center() + Vector2(0, 260)))
	gw.parts = 12
	gw.auto_sweep = false
	sync.call()
	var gg: Unit = null
	for u in gu.units:
		if u.net_id == gw.net_id:
			gg = u
	check("online: the guest sees its parts and its SWEEP switch", gg != null and gg.parts == 12 and not gg.auto_sweep)
	gw.parts = 13
	gw.work = "sweeping"
	gw.order = "sweep"
	sync.call()
	check("online: and the next wreck swept, sweeping", gg != null and gg.parts == 13 and gg.work == "sweeping")
	check("online: the check lists match", NetSnapshot.check_lists(gw, null) == "", NetSnapshot.check_lists(gw, null))
	check("replays carry the parts (a snapshot property)", NetSnapshot.UNIT_PROPS.has("parts") and NetSnapshot.UNIT_PROPS.has("auto_sweep"))
	sg.queue_free()
	sh.queue_free()
	h.queue_free()
	gu.queue_free()
	await process_frame


# ------------------------------------------------------------------ the computer

var _main: Node = null


func _computer() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	seed(91)
	_main.start({"map": "greenhold", "seed": 91, "slots": [
		{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	while _main.game == null:
		await process_frame
	var g: Game = _main.game
	for i in 10:
		await process_frame
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		if ai.team != 0:
			ai.process_mode = Node.PROCESS_MODE_DISABLED      # (a passive Crown)
	var hall: Building = _mine(g, "clocktower")[0]
	g.players[0]["gold"] = 8000
	g.players[0]["tension"] = 2000.0
	# (the Mainspring first, with room for the Escapement and the Heavy Works' big ring, as the computer places it: the
	# Great Winder is made at the Heavy Works since 0.14.85, which the computer lays itself)
	var spring: Building = null
	var rs: Array = GearEcon.room_spot_n(g, 0, "mainspring", [hall], [Defs.CW_TECH, Defs.CW_HEAVY])
	if int(rs[1]) >= 2:
		spring = g._add_building("mainspring", 0, rs[0], true)
		g.gear_net.solve()
	if spring == null:
		spring = _put(g, "mainspring", hall)
	var esc: Building = _put(g, Defs.CW_TECH, spring) if spring else null
	while _mine(g, Defs.CW_WORKS).size() < 2:
		if _put(g, Defs.CW_WORKS, hall) == null:
			break
	for w in _mine(g, Defs.CW_WORKS):
		if g.gear_net.spring_for(w) == null:
			_put(g, "mainspring", w)
	for i in 8:
		_put(g, Defs.CW_SUPPLY, hall)       # (room in the supply for a 4-supply machine beside its army)
	# (Winders to build with, as a real game has by now; the passive Crown's buildings cannot fall, so the match runs on)
	for i in 8:
		g._add_unit("winder", 0, g.cell_center(g.nearest_free(g.cell_of(hall.center() + Vector2(-140 + i * 36, 120)), 6)))
	for b in g.buildings:
		if b.team == 1:
			b.max_hp = 1.0e7
			b.hp = 1.0e7
	await physics_frame
	g.gear_net.solve()
	check("the computer's Escapement works", esc != null and g.gear_net.speed_mult(esc) > 0.0)
	g.clock = maxf(g.clock, 330.0)
	var ai = g.ais.filter(func(a) -> bool: return a.team == 0)[0]
	var waited := await _wait(g, func() -> bool:
		for w in _mine(g, Defs.CW_WORKS):
			if w.built and g.gear_net.spring_for(w) == null and Engine.get_physics_frames() % 60 == 0:
				_put(g, "mainspring", w)       # (every Works it adds may make Tension units: the test's help, not the computer's)
		return not _units(g, K).is_empty(), 480.0)
	check("the computer trains a Great Winder", not _units(g, K).is_empty(), "after %.0f s" % waited)
	var kinds := {}
	for u in g.army(0):
		kinds[u.kind] = int(kinds.get(u.kind, 0)) + 1
	print("  army %s, tension %.0f, cogs %d" % [str(kinds), g.tension(0), int(g.players[0]["gold"])])
	for w in _mine(g, Defs.CW_HEAVY):
		print("  heavy works queue %s: %s" % [str(w.queue), g.can_train(w, K)])
	await _wait(g, func() -> bool: return false, 90.0)
	check("one, not more", _units(g, K).size() == 1, "%d" % _units(g, K).size())
	var army: Array = g.army(0).filter(func(u: Unit) -> bool: return u.kind != K and not u.is_air())
	check("the escort is smaller while a Great Winder goes with the army", ai._escort_want(army) <= maxi(1, clampi(2 + army.size() / 5, 2, 10) - AI.GREAT_WINDER_ESCORT) + 2 * AI.BALLISTA_CREW,
		"%d escort for %d constructs" % [ai._escort_want(army), army.size()])
	# send the army out: it walks behind it
	var far: Vector2 = hall.center() + Vector2(700, 300)
	ai._follow_with_escort(army)
	if _units(g, K).is_empty():
		_main.queue_free()
		return
	var gw: Unit = _units(g, K)[0]
	var c := Vector2.ZERO
	for u in army:
		c += u.position
	c /= maxi(1, army.size())
	check("it is sent to the army (just behind it)", gw.order == "move" and gw.order_point.distance_to(c) < 140.0 or gw.position.distance_to(c) < 170.0 or gw.order == "mend" or gw.order == "sweep",
		"order %s, %.0f px from the army" % [gw.order, gw.position.distance_to(c)])
	for u in army:
		u.cmd_move(far)
	await _wait(g, func() -> bool: return false, 6.0)
	c = Vector2.ZERO
	for u in army:
		c += u.position
	c /= maxi(1, army.size())
	ai._follow_with_escort(army)
	check("and follows it when it moves", gw.order == "move" and gw.order_point.distance_to(c) < 140.0, "order %s to %s, army at %s" % [gw.order, str(gw.order_point), str(c)])
	_main.queue_free()


func _mine(g: Game, kind: String) -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and not b.dead and b.kind == kind)


func _units(g: Game, kind: String) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.kind == kind)


func _wait(g: Game, cond: Callable, secs: float) -> float:
	var t0: float = g.clock
	while not cond.call() and g.clock - t0 < secs and not g.over:
		await physics_frame
	return g.clock - t0


func _put(g: Game, kind: String, around: Building) -> Building:
	for deg in [0.0, 60.0, 120.0, 180.0, -60.0, -120.0, 30.0, 150.0, -30.0, -150.0, 90.0, -90.0]:
		var c := GearNet.ring_spot(g, 0, kind, around, deg, true)
		if c.x >= 0:
			var b: Building = g._add_building(kind, 0, c, true)
			g.gear_net.solve()
			return b
	return null


## A finished Mainspring whose ring meshes with b's (directly or through an idler), linked; null if none fits.
func _spring_beside(g: Game, b: Building) -> Building:
	for deg in [0.0, 60.0, 120.0, 180.0, -60.0, -120.0, 30.0, 150.0, -30.0, -150.0, 90.0, -90.0]:
		var c := GearNet.ring_spot(g, 0, "mainspring", b, deg, true)
		if c.x >= 0:
			var sp: Building = g._add_building("mainspring", 0, c, true)
			g.gear_net.solve()
			if g.gear_net.spring_for(b) != null:
				return sp
	return null
