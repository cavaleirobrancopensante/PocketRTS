extends SceneTree
## BODIES HAVE HEALTH, AND IT ROTS AWAY (Defs.ROT), beefy bodies take a little longer to harvest (Defs.HARVEST), and
## ATTACK GROUND for every unit that can attack (Ctrl+A, then a click or a held left-drag; Defs.GROUND):
##   godot --headless --fixed-fps 30 --script res://tools/test_ground_attack.gd
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait_for(cond: Callable, secs: float) -> bool:
	var e := 0.0
	while e < secs:
		if cond.call():
			return true
		await physics_frame
		e += 1.0 / 30.0
	return cond.call()


func wait(secs: float) -> void:
	await wait_for(func() -> bool: return false, secs)


func _screen(w: Vector2) -> Vector2:
	return g.get_viewport().get_canvas_transform() * w


## A unit killed where it stands; it lies down as a body (Unit._rest_in_peace) a moment later.
func _body(kind: String, team: int, at: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, team, at)
	await physics_frame
	u.take_damage(99999.0, null)
	return u


func _spot(near: Vector2) -> Vector2:
	return g.cell_center(g.nearest_free(g.cell_of(near), 8))


func _gone(b) -> bool:
	return not is_instance_valid(b) or b.torn or b.modulate.a < 0.99


func _mouse(btn: int, at_world: Vector2, pressed: bool, shift := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.position = _screen(at_world)
	g.controls._mouse(ev)


func _motion(at_world: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _screen(at_world)
	g.controls._unhandled_input(ev)


## Ctrl+A, then hold the left button at a, drag to b in steps, let go (Shift held if `shift`).
func _drag_ground(a: Vector2, b: Vector2, shift := false) -> void:
	g.camera.position = a.lerp(b, 0.5)
	g.camera.force_update_scroll()
	for k in 10:
		await process_frame
	g.controls.begin_bombard()
	_mouse(MOUSE_BUTTON_LEFT, a, true, shift)
	for k in range(1, 9):
		_motion(a.lerp(b, k / 8.0))
	_mouse(MOUSE_BUTTON_LEFT, b, false, shift)


func _run() -> void:
	g.explored.fill(1)
	var was_dev := Settings.device
	Settings.device = "pc"
	Unit.bolt_force = 0.0          # (a rider's horse always falls with him: the body is a rider and his horse)
	var c := Vector2i(g.W / 2, g.H / 2)
	var start: Vector2 = g.cell_center(g.nearest_free(c, 10))
	g.camera.position = start

	# ---- 1. a body's health is its unit's in life (a rider's adds his horse's)
	var bm: Unit = await _body("musketeer", 0, _spot(start + Vector2(-300, -300)))
	var br: Unit = await _body("raptor", 1, _spot(start + Vector2(-260, -300)))
	var bb: Unit = await _body("brute", 1, _spot(start + Vector2(-220, -300)))
	var bc: Unit = await _body("cuirassier", 0, _spot(start + Vector2(-180, -300)))
	var t0 := g.clock
	await wait(2.0)
	check(is_equal_approx(bm.body_size(), 70.0), "a Musketeer's body has 70 health (%.0f)" % bm.body_size())
	check(is_equal_approx(br.body_size(), 36.0), "a Raptor's 36 (%.0f)" % br.body_size())
	check(is_equal_approx(bb.body_size(), 240.0), "a Brute's 240 (%.0f)" % bb.body_size())
	check(bc.is_mounted() and is_equal_approx(bc.body_size(), 200.0), "a Horseman's with his horse 140 + 60 = 200 (%.0f)" % bc.body_size())
	check(g.bodies.has(bm) and bm.body_left() < 70.0 and bm.body_left() > 69.0, "lying there, a little rotted already (%.2f)" % bm.body_left())

	# ---- 2. the rot: one base speed, doubling every minute (closed form, and live)
	var lm := Unit.rot_life(70.0)
	var lr := Unit.rot_life(36.0)
	var lb := Unit.rot_life(240.0)
	check(absf(lm - 120.0) < 3.0, "an untouched Musketeer's body lasts about 2:00 (%.1f s)" % lm)
	check(absf(lr - 80.0) < 4.0, "a Raptor's about 1:20 (%.1f s)" % lr)
	check(absf(lb - 210.0) < 4.0, "a Brute's about 3:30 (%.1f s)" % lb)
	check(absf(Unit.rot_lost(60.0) - float(Defs.ROT["base"]) * 60.0 / log(2.0)) < 0.01 and Unit.rot_lost(120.0) > Unit.rot_lost(60.0) * 2.9,
		"it rots faster the longer it lies (lost %.1f in the first minute, %.1f in the second)" % [Unit.rot_lost(60.0), Unit.rot_lost(120.0) - Unit.rot_lost(60.0)])
	check(lm > float(Defs.REVIVE["window"]) and lr > float(Defs.REVIVE["window"]), "every body outlasts the Missionary's 60 s window")
	# without the Brood: the same rot (a body nobody harvests lies as long)
	g.eliminated[1] = true
	var nb: Unit = await _body("musketeer", 0, _spot(start + Vector2(-140, -300)))
	g.eliminated[1] = false
	await wait(2.0)
	check(not g.corpses.has(nb) and g.bodies.has(nb) and absf(nb.rot_end() - nb.died_at - lm) < 0.5, "with no Brood in the match: not for harvest, the same rot (%.1f s)" % (nb.rot_end() - nb.died_at))
	# live: wait and see them go
	var went := {}
	for b in [bm, br, bb, nb]:
		went[b] = -1.0
	await wait_for(func() -> bool:
		for b in went:
			if went[b] < 0.0 and _gone(b):
				went[b] = g.clock - t0
		return not went.values().has(-1.0), 240.0)
	check(absf(float(went[br]) - lr) < 4.0, "live: the Raptor's body went at %.1f s" % float(went[br]))
	check(absf(float(went[bm]) - lm) < 4.0, "the Musketeer's at %.1f s (a match with the Brood)" % float(went[bm]))
	check(absf(float(went[nb]) - lm) < 6.0, "the one that fell with no Brood in the match at %.1f s" % float(went[nb]))
	check(absf(float(went[bb]) - lb) < 4.0, "the Brute's at %.1f s" % float(went[bb]))

	# ---- 3. damage speeds it up; at 0 it is torn up: no harvest, no raising
	var dm: Unit = await _body("musketeer", 0, _spot(start + Vector2(-300, -200)))
	await wait(2.0)
	var end0 := dm.rot_end()
	g.hit_body(dm, 30.0)
	check(dm.rot_end() < end0 - 20.0 and absf(dm.body_left() - (70.0 - 30.0 - Unit.rot_lost(g.clock - dm.died_at))) < 0.01,
		"30 damage: %.0f left, it goes %.0f s sooner" % [dm.body_left(), end0 - dm.rot_end()])
	check(g.corpses.has(dm) and g.fallen.has(dm), "hurt, it can still be harvested and raised")
	var miss: Unit = g._add_unit("missionary", 0, dm.position + Vector2(0, 90))
	await physics_frame
	miss.process_mode = Node.PROCESS_MODE_DISABLED
	g.hit_body(dm, 60.0)
	check(dm.torn and not g.corpses.has(dm) and not g.fallen.has(dm), "brought to 0 it is torn up")
	check(not g.can_revive(dm, miss), "a torn body can't be raised")
	var grub: Unit = g._add_unit("grub", 1, dm.position + Vector2(30, 0))
	await physics_frame
	check(g.find_corpse(grub, 120.0) != dm, "nor harvested")
	g.consume_unit(grub)
	# the Missionary still raises a fallen soldier within the 60 s
	var rm: Unit = await _body("musketeer", 0, _spot(start + Vector2(-300, -120)))
	await wait(50.0)
	check(g.can_revive(rm, miss) and Game.lying(rm), "50 s on, the body still lies there and can be raised")
	miss.position = rm.position + Vector2(0, 40)
	miss.process_mode = Node.PROCESS_MODE_INHERIT
	miss.cmd_revive(rm)
	var up := await wait_for(func() -> bool: return is_instance_valid(rm) and not rm.dead, 12.0)
	check(up, "the Missionary raises him (%.0f s after he fell)" % (g.clock - rm.died_at))
	g.consume_unit(miss)
	if is_instance_valid(rm):
		g.consume_unit(rm)

	# ---- 4. a beefy body takes a little longer to harvest
	var hr := g.harvest_time(br) if is_instance_valid(br) else 0.0
	var hraptor: Unit = await _body("raptor", 1, _spot(start + Vector2(-300, -40)))
	var hbrute: Unit = await _body("brute", 1, _spot(start + Vector2(-260, -40)))
	var hrider: Unit = await _body("cuirassier", 0, _spot(start + Vector2(-220, -40)))
	await wait(1.6)
	hr = g.harvest_time(hraptor)
	var hb := g.harvest_time(hbrute)
	var hh := g.harvest_time(hrider)
	var hm := g.harvest_time(nb) if is_instance_valid(nb) else float(Defs.HARVEST["take"])
	check(hb > hr, "harvest: a Brute's body takes longer (%.2f s) than a Raptor's (%.2f s)" % [hb, hr])
	check(absf(hr - 0.86) < 0.05 and absf(hb - 2.22) < 0.05 and absf(hh - 2.03) < 0.05, "Raptor %.2f, Horseman %.2f, Brute %.2f s" % [hr, hh, hb])
	check(hr >= float(Defs.HARVEST["take_min"]) and hb <= float(Defs.HARVEST["take_max"]), "within %.1f-%.1f s" % [float(Defs.HARVEST["take_min"]), float(Defs.HARVEST["take_max"])])
	var big: Unit = await _body("pendulum", 1, _spot(start + Vector2(-180, -40)))
	await wait(1.6)
	check(g.harvest_time(big) <= float(Defs.HARVEST["take_max"]) and g.harvest_time(big) > hb, "a Pendulum's %.2f s (never slow)" % g.harvest_time(big))
	g.hit_body(hbrute, 200.0)
	check(is_equal_approx(g.harvest_time(hbrute), hb), "its size counts, not what is left of it")
	var gw: Unit = g._add_unit("grub", 1, hraptor.position + Vector2(20, 0))
	await physics_frame
	gw.cmd_harvest()
	var wrap := {"t": -1.0}
	await wait_for(func() -> bool:
		if gw.work == "wrapping" and float(wrap["t"]) < 0.0:
			wrap["t"] = g.clock
		return gw.cocoon > 0.0, 15.0)
	check(gw.cocoon > 0.0 and absf(g.clock - float(wrap["t"]) - hr) < 0.15, "a grub wraps the Raptor in %.2f s" % (g.clock - float(wrap["t"])))
	g.consume_unit(gw)

	# ---- 5. who can attack the ground
	var can := []
	var cannot := []
	for k in ["labourer", "musketeer", "cannon", "mortar", "cuirassier", "dismounted", "grub", "raptor", "spitter", "brute",
			"spore_mother", "winder", "clock_soldier", "springer", "pendulum", "thresher", "arc_thrower", "missionary", "powder_wagon",
			"horse", "balloon", "messenger", "dragoon", "netter", "bloater", "cuckoo"]:
		var u: Unit = g._add_unit(k, 0 if Defs.UNITS[k]["faction"] == "crown" else (1 if Defs.UNITS[k]["faction"] == "brood" else 0), start + Vector2(400, 400))
		await physics_frame
		(can if u.can_ground_attack() else cannot).append(k)
		g.consume_unit(u)
	print("  can attack the ground: %s" % ", ".join(can))
	print("  cannot: %s" % ", ".join(cannot))
	check(can.has("labourer") and can.has("grub") and can.has("winder") and can.has("musketeer") and can.has("brute") and can.has("mortar"),
		"workers, shooters, melee units and area weapons can")
	check(cannot.has("missionary") and cannot.has("powder_wagon") and cannot.has("horse") and cannot.has("balloon") and cannot.has("netter"),
		"medics, wagons, horses, balloons and the Netter can't")

	# ---- 6. 8 Musketeers dragged along a line of 8 bodies tear them all, and spend powder
	var row0 := _spot(start + Vector2(-120, 260))
	var row: Array = []
	for k in 8:
		row.append(await _body("musketeer", 1 if k % 2 else 0, row0 + Vector2(k * 40, (k % 2) * 6)))
	var musks: Array = []
	for k in 8:
		musks.append(g._add_unit("musketeer", 0, _spot(row0 + Vector2(k * 40, 170))))
	await wait(2.0)
	var pw0 := 0.0
	for m in musks:
		pw0 += m.powder
	g.set_selection(musks)
	g.camera.position = row0 + Vector2(140, 80)
	await process_frame
	await _drag_ground(row0 + Vector2(-10, 0), row0 + Vector2(290, 0))
	var orders := musks.filter(func(m: Unit) -> bool: return m.order == "bombard").size()
	check(orders == 8, "the drag gives all 8 the order (%d)" % orders)
	var stretches := {}
	for m in musks:
		stretches[snappedf(m.order_point.x, 1.0)] = true
	check(stretches.size() == 8 and musks.all(func(m: Unit) -> bool: return m.gnd_a.distance_to(m.gnd_b) > 30.0), "each its own stretch of the line (%d)" % stretches.size())
	check(g.controls.mode == "" and g.controls.line.is_empty(), "the mode closes and the line goes")
	var torn_all := await wait_for(func() -> bool: return row.all(func(b) -> bool: return _gone(b)), 60.0)
	var pw1 := 0.0
	for m in musks:
		pw1 += m.powder
	check(torn_all and row.all(func(b) -> bool: return not is_instance_valid(b) or b.torn), "all 8 bodies torn up (%.0f s)" % (g.clock - row[0].died_at if is_instance_valid(row[0]) else -1.0))
	check(pw1 < pw0 - 8.0, "and powder spent (%.0f shots)" % (pw0 - pw1))
	check(musks.all(func(m: Unit) -> bool: return m.order == "bombard"), "they keep on afterwards (no bodies left)")
	# ---- 7. they keep attacking until another order: the shooters keep shooting the empty stretch
	var pw2 := pw1
	await wait(10.0)
	var pw3 := 0.0
	for m in musks:
		pw3 += m.powder
	check(pw3 < pw2 - 4.0 and musks.all(func(m: Unit) -> bool: return m.order == "bombard"), "10 s more at the empty line: %.0f more shots, still on it" % (pw2 - pw3))
	g.command_all(musks, "stop")
	check(musks.all(func(m: Unit) -> bool: return m.order != "bombard"), "another order ends it")
	for m in musks:
		g.consume_unit(m)

	# ---- 8. melee units and workers walk up and strike the bodies; workers take longer
	var pa := _spot(start + Vector2(300, -260))
	var pb := _spot(start + Vector2(300, 60))
	var bodies_b: Array = [await _body("musketeer", 0, pa), await _body("musketeer", 0, pa + Vector2(24, 8))]
	var bodies_l: Array = [await _body("musketeer", 0, pb), await _body("musketeer", 0, pb + Vector2(24, 8))]
	var brute: Unit = g._add_unit("brute", 1, pa + Vector2(0, 120))
	var lab: Unit = g._add_unit("labourer", 0, pb + Vector2(0, 120))
	await wait(2.0)
	g.bombard_order([brute], pa)
	g.bombard_order([lab], pb)
	var tt := {"b": -1.0, "l": -1.0, "0": g.clock}
	await wait_for(func() -> bool:
		if float(tt["b"]) < 0.0 and bodies_b.all(func(b) -> bool: return _gone(b)):
			tt["b"] = g.clock - float(tt["0"])
		if float(tt["l"]) < 0.0 and bodies_l.all(func(b) -> bool: return _gone(b)):
			tt["l"] = g.clock - float(tt["0"])
		return float(tt["b"]) >= 0.0 and float(tt["l"]) >= 0.0, 60.0)
	var t_b := float(tt["b"])
	var t_l := float(tt["l"])
	check(t_b > 0.0, "a Brute tears up both bodies within 1.5 tiles of its spot (%.1f s)" % t_b)
	check(t_l > 0.0, "a Labourer does too (%.1f s)" % t_l)
	check(t_l > t_b * 1.5, "the worker takes longer")
	# they wait at the spot, and strike a new body that falls there later
	await wait(5.0)
	check(brute.order == "bombard" and lab.order == "bombard" and brute.position.distance_to(pa) < 60.0, "with none left they wait there, still on the order")
	var late: Array = [await _body("raptor", 1, pa + Vector2(-20, 0))]
	var hit_late := await wait_for(func() -> bool: return _gone(late[0]), 25.0)
	check(hit_late and (not is_instance_valid(late[0]) or late[0].torn), "a body that falls there later is struck too")
	g.command_all([brute, lab], "stop")

	# ---- 9. a short drag counts as a click; Shift-queueing
	var sq := _spot(start + Vector2(0, -420))
	var mq: Unit = g._add_unit("musketeer", 0, sq + Vector2(0, 200))
	var mq2: Unit = g._add_unit("musketeer", 0, sq + Vector2(30, 200))
	await physics_frame
	g.set_selection([mq, mq2])
	g.camera.position = sq + Vector2(0, 100)
	await process_frame
	await _drag_ground(sq, sq + Vector2(12, 4))
	check(mq.order == "bombard" and mq2.order == "bombard" and mq.order_point.distance_to(mq2.order_point) < 1.0 \
		and mq.gnd_a.distance_to(mq.gnd_b) < 1.0, "a short drag acts as a click: one spot for both")
	var q_to := sq + Vector2(-120, 200)
	g.command_all([mq, mq2], "stop")
	mq.give({"o": "move", "p": q_to})
	mq2.give({"o": "move", "p": q_to + Vector2(30, 0)})
	await _drag_ground(sq + Vector2(-60, 0), sq + Vector2(60, 0), true)
	check(mq.order == "move" and mq.queue.size() == 1 and mq.queue[0]["o"] == "bombard" and mq.queue[0].has("a"), "Shift-drag: ATTACK GROUND waits behind the move")
	check(g.controls.mode == "bombard", "and the mode stays on while Shift is held")
	g.controls.cancel_mode()
	var went2 := await wait_for(func() -> bool: return mq.order == "bombard", 20.0)
	check(went2 and mq.gnd_a.distance_to(mq.gnd_b) > 30.0, "after the move it attacks its stretch")
	g.consume_unit(mq)
	g.consume_unit(mq2)

	# ---- 10. a Mortar still bombards as before and tears most bodies in its blast
	var ms := _spot(start + Vector2(-420, 120))
	var pile: Array = []
	var kinds := ["raptor", "musketeer", "brute", "cuirassier", "pendulum"]
	for k in kinds.size():
		pile.append(await _body(kinds[k], 1 if k % 2 == 0 else 0, ms + Vector2(-16 + (k % 3) * 16, -8 + (k / 3) * 14)))
	var mortar: Unit = g._add_unit("mortar", 0, ms + Vector2(0, 260))
	await wait(2.0)
	var hit0 := g.bodies_hit
	g.bombard_order([mortar], ms)
	var landed := await wait_for(func() -> bool: return g.bodies_hit > hit0, 25.0)
	await wait(0.2)
	mortar.cmd_stop()
	var torn_n := pile.filter(func(b) -> bool: return not is_instance_valid(b) or b.torn).size()
	check(landed and torn_n >= 4, "one shell tears up %d of the 5 bodies in its blast (all but the Pendulum's)" % torn_n)
	var pend: Unit = pile[4]
	check(Game.lying(pend) and pend.body_left() < 60.0, "the Pendulum's body is left with %.0f of 340" % (pend.body_left() if Game.lying(pend) else 0.0))
	g.consume_unit(mortar)

	# ---- 11. online: the guest's order (the line and each unit's stretch) and the bodies' health
	check(NetCommands.GAME.has("ground_order"), "the order is in the online command funnel")
	var hs := NetSession.new()
	hs.game = g
	hs.is_host = true
	hs.peer_team = {5: 0}
	var o1: Unit = g._add_unit("musketeer", 0, start + Vector2(200, 300))
	var o2: Unit = g._add_unit("brute", 1, start + Vector2(240, 300))
	var o3: Unit = g._add_unit("labourer", 0, start + Vector2(280, 300))
	await physics_frame
	hs.assign(o1)
	hs.assign(o2)
	hs.assign(o3)
	hs.by_id = {o1.net_id: o1, o2.net_id: o2, o3.net_id: o3}
	var la := start + Vector2(180, 120)
	var lb2 := start + Vector2(340, 120)
	var why := NetCommands.apply(hs, 5, {"o": 0, "f": "ground_order", "a": NetCodec.enc([[o1, o2, o3], PackedVector2Array([la, lb2]), false], [true])})
	check(why == "" and o1.order == "bombard" and o3.order == "bombard" and o1.gnd_a.distance_to(o1.gnd_b) > 30.0, "the host runs a guest's ATTACK GROUND line (%s)" % (why if why != "" else "ok"))
	check(o2.order != "bombard", "but not for a unit that isn't the guest's")
	check(o1.gnd_b.distance_to(o3.gnd_a) < 1.0, "each its own stretch, in order along the line")
	g.command_all([o1, o2, o3], "stop")
	g.net = hs
	var nb2: Unit = await _body("musketeer", 0, start + Vector2(-200, 380))
	await wait(1.6)
	hs.fx.clear()
	g.hit_body(nb2, 25.0)
	var hfx: Array = hs.fx.filter(func(f: Array) -> bool: return f[0] == "h")
	check(hfx.size() == 1 and absf(float(hfx[0][3]) - nb2.body_left()) < 0.5, "the host tells the guest a body's health when a hit changes it")
	g.net = null
	# the guest: it works out the rot itself and takes the health the host sends
	var gb: Unit = await _body("musketeer", 0, start + Vector2(-260, 380))
	await wait(1.6)
	var left0 := gb.body_left()
	g.body_health_at(gb.position, 30.0)
	check(absf(gb.body_left() - 30.0) < 0.1 and gb.rot_end() < gb.died_at + Unit.rot_life(70.0) - 10.0, "the guest's copy takes it (%.0f -> %.0f) and goes sooner" % [left0, gb.body_left()])
	for u in [o1, o2, o3]:
		g.consume_unit(u)

	Unit.bolt_force = -1.0
	Settings.device = was_dev
	print("ground attack: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
