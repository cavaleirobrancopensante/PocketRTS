extends SceneTree
## FIRE AT A SPOT (BOMBARD, Ctrl+A; Defs.BOMBARD) and AREA SHOTS DESTROY BODIES (Defs.BODY_BLAST), the Brood's harvest at
## 1.25 essence a supply (Defs.HARVEST), Shift-queueing, save/load and the online order:
##   godot --headless --fixed-fps 30 --script res://tools/test_attack_ground.gd
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0
var landed: Array = []          # where the projectiles watched by _watch() were going (their `to`)
var _seen := {}


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


## Wait (game time) until cond() or the time runs out; also notes the projectiles in flight.
func wait_for(cond: Callable, secs: float) -> bool:
	var e := 0.0
	while e < secs:
		if cond.call():
			return true
		await physics_frame
		_watch()
		e += 1.0 / 30.0
	return cond.call()


func wait(secs: float) -> void:
	await wait_for(func() -> bool: return false, secs)


func _watch() -> void:
	for n in g.get_children():
		if n is Projectile and not _seen.has(n.get_instance_id()):
			_seen[n.get_instance_id()] = true
			landed.append((n as Projectile).to)


func _key(code: int, ctrl := false, shift := false, pressed := true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	ev.pressed = pressed
	if pressed:
		g.controls._key(ev)
	else:
		g.controls._unhandled_input(ev)


func _screen(w: Vector2) -> Vector2:
	return g.get_viewport().get_canvas_transform() * w


func _card_item(label: String) -> Array:
	g.hud._refresh_card()
	for it in g.hud._card_items:
		if String(it[1]).trim_prefix("~ ") == label:
			return it
	return []


## A soldier or creature killed where it stands (its body stays: Game.on_unit_died).
func _body(kind: String, team: int, at: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, team, at)
	await physics_frame
	u.take_damage(99999.0, null)
	return u


func _run() -> void:
	g.explored.fill(1)
	var was_dev := Settings.device
	Settings.device = "pc"
	var c := Vector2i(g.W / 2, g.H / 2)
	var start: Vector2 = g.cell_center(g.nearest_free(c, 10))
	g.camera.position = start

	# ---- 1. the mode: Ctrl+A and the button; A stays attack-move; a Musketeer can't
	var gun: Unit = g._add_unit("cannon", 0, start)
	var mortar: Unit = g._add_unit("mortar", 0, start + Vector2(0, 70))
	var musk: Unit = g._add_unit("musketeer", 0, start + Vector2(-60, 30))
	await physics_frame
	g.set_selection([gun])
	_key(KEY_A, true)
	check(g.controls.mode == "bombard", "Ctrl+A with a Cannon selected: BOMBARD mode")
	g.controls.cancel_mode()
	_key(KEY_A)
	check(g.controls.mode == "attack", "plain A is still attack-move")
	g.controls.cancel_mode()
	var it := _card_item("BOMBARD")
	check(not it.is_empty(), "the Cannon's card has a BOMBARD button")
	if not it.is_empty():
		check(String(it[6]) == "^A", "its hotkey hint is Ctrl+A (^A), got '%s'" % String(it[6]))
		check(String(it[0]) == "ab_bombard" and g.hud._icon("ab_bombard") != null, "with its own icon (ab_bombard)")
		it[2].call()
		check(g.controls.mode == "bombard", "the button sets BOMBARD mode")
		g.controls.cancel_mode()
	check(not g.hud._card_tip(it).get("body", "").is_empty() if not it.is_empty() else false, "and a tooltip")
	g.set_selection([mortar])
	check(not _card_item("BOMBARD").is_empty(), "the Mortar's card has it too")
	g.set_selection([musk])
	check(_card_item("BOMBARD").is_empty(), "a Musketeer's card has no BOMBARD")
	_key(KEY_A, true)
	check(g.controls.mode != "bombard", "Ctrl+A with only a Musketeer: no BOMBARD mode")
	g.controls.cancel_mode()
	check(not musk.can_bombard() and g.bombard_order([musk], start + Vector2(200, 0)) == 0, "a Musketeer cannot get the order")
	musk.give({"o": "bombard", "p": start + Vector2(200, 0)})
	check(musk.order != "bombard", "not even given straight (order '%s')" % musk.order)
	# a mixed selection: the click gives it to the Mortar only
	g.set_selection([musk, mortar])
	_key(KEY_A, true)
	check(g.controls.mode == "bombard", "Ctrl+A with a Musketeer and a Mortar: BOMBARD mode")
	var spot0 := start + Vector2(0, 70 + 240)
	g.controls._tap(_screen(spot0), false, false)
	check(mortar.order == "bombard" and mortar.order_point.distance_to(spot0) < 4.0, "the click: the Mortar fires at the spot")
	check(musk.order != "bombard", "the Musketeer doesn't")
	check(g.controls.mode == "", "and the mode closes")
	g.command_all([mortar, musk, gun], "stop")
	g.consume_unit(musk)
	await wait(4.0)

	# ---- 2. a Cannon and a Mortar fire at an empty spot in the fog, and keep firing
	var spot := start + Vector2(320, 0)
	check(not g.side_sees(0, spot), "the spot is in the fog (nobody of ours sees it)")
	var pw_gun := gun.powder
	var pw_mortar := mortar.powder
	landed.clear()
	var n := g.bombard_order([gun, mortar], spot)
	check(n == 2 and gun.order == "bombard" and mortar.order == "bombard", "both take the order")
	await wait(26.0)
	var shots_gun := int(round(pw_gun - gun.powder))
	var shots_mortar := int(round(pw_mortar - mortar.powder))
	check(shots_gun >= 3, "the Cannon kept firing (%d shots in 26 s)" % shots_gun)
	check(shots_mortar >= 3, "the Mortar kept firing (%d shells in 26 s)" % shots_mortar)
	check(gun.order == "bombard" and mortar.order == "bombard", "still on the order")
	var near := landed.filter(func(p: Vector2) -> bool: return p.distance_to(spot) < 40.0).size()
	check(landed.size() >= 6 and near == landed.size(), "every shot went to the spot (%d of %d within 40 px)" % [near, landed.size()])
	var dry := await wait_for(func() -> bool: return gun.powder < 1.0 and mortar.powder < 1.0, 60.0)
	check(dry, "they fire until the shot runs out (powder %.0f and %.0f left)" % [gun.powder, mortar.powder])
	var n0 := landed.size()
	await wait(8.0)
	check(landed.size() == n0 and gun.order == "bombard", "dry: no more shots, still on the order (waiting for powder)")
	g.command_all([gun, mortar], "stop")
	check(gun.order == "idle" and mortar.order == "idle", "another order (STOP) ends it")

	# ---- 3. bodies in the blast are gone for harvest and revive; bodies outside are not
	var a_spot := start + Vector2(-60, -330)
	var b_spot := a_spot + Vector2(170, 0)
	var ma: Unit = await _body("musketeer", 0, a_spot + Vector2(-8, 4))
	var ra: Unit = await _body("raptor", 1, a_spot + Vector2(10, -6))
	var mb: Unit = await _body("musketeer", 0, b_spot + Vector2(-8, 4))
	var rb: Unit = await _body("raptor", 1, b_spot + Vector2(10, -6))
	await wait(2.0)
	check(g.corpses.has(ma) and g.corpses.has(ra) and g.corpses.has(mb) and g.corpses.has(rb), "four bodies for the Brood to harvest")
	check(g.fallen.has(ma) and g.fallen.has(mb), "and two Musketeers a Missionary could raise")
	var miss: Unit = g._add_unit("missionary", 0, a_spot + Vector2(0, 120))
	await physics_frame
	miss.process_mode = Node.PROCESS_MODE_DISABLED       # (standing by: only asked who he could raise)
	check(g.can_revive(ma, miss) and g.can_revive(mb, miss), "before: he could raise both")
	var m2: Unit = g._add_unit("mortar", 0, a_spot + Vector2(0, 260))
	await physics_frame
	var torn0: int = g.bodies_blasted["aimed"]
	g.bombard_order([m2], a_spot)
	var hit := await wait_for(func() -> bool: return int(g.bodies_blasted["aimed"]) > torn0, 25.0)
	m2.cmd_stop()
	check(hit, "the shell lands on the bodies at the spot")
	check(not g.corpses.has(ma) and not g.corpses.has(ra), "the bodies in the blast are gone for the harvest")
	check(not g.fallen.has(ma) and not g.can_revive(ma, miss), "and for raising (the Crown's own dead too)")
	check(g.corpses.has(mb) and g.corpses.has(rb) and g.fallen.has(mb) and g.can_revive(mb, miss), "the bodies outside the blast are not")
	var grub: Unit = g._add_unit("grub", 1, a_spot + Vector2(0, 40))
	await physics_frame
	var fc: Unit = g.find_corpse(grub, 400.0)
	check(fc == mb or fc == rb, "a grub nearby only finds the bodies outside it")
	g.consume_unit(grub)
	await wait(1.0)
	check(not is_instance_valid(ma) or ma.torn, "the torn bodies go from the field")
	# a man the shell itself kills keeps his body (only what lay there before is torn up)
	var c_spot := b_spot + Vector2(0, -150)
	var weak: Unit = g._add_unit("raptor", 1, c_spot)
	await physics_frame
	weak.hp = 1.0
	weak.process_mode = Node.PROCESS_MODE_DISABLED
	var m3: Unit = g._add_unit("mortar", 0, c_spot + Vector2(-250, 0))
	await physics_frame
	g.bombard_order([m3], c_spot)
	var killed := await wait_for(func() -> bool: return weak.dead, 25.0)
	m3.cmd_stop()
	await wait(0.5)
	check(killed and g.corpses.has(weak), "a Raptor the shell kills falls as a body (not torn up)")
	# the Cannon's canister (its cone) and round shot (where it lands) fired at a spot tear them too
	var e_spot := start + Vector2(-360, 40)
	var cb: Unit = await _body("raptor", 1, e_spot)
	var cg: Unit = g._add_unit("cannon", 0, e_spot + Vector2(0, 110))
	await physics_frame
	cg.set_canister(true)
	g.bombard_order([cg], e_spot)
	await wait_for(func() -> bool: return cb.torn, 15.0)
	cg.cmd_stop()
	check(cb.torn, "canister fired at a spot tears up the body in its cone")
	var f_spot := start + Vector2(-360, -220)
	var rbody: Unit = await _body("raptor", 1, f_spot)
	var rg: Unit = g._add_unit("cannon", 0, f_spot + Vector2(-90, 290))
	await physics_frame
	g.bombard_order([rg], f_spot)
	await wait_for(func() -> bool: return rbody.torn, 15.0)
	rg.cmd_stop()
	check(rbody.torn, "round shot fired at a spot tears up the body where it lands")
	# ordinary fire at an enemy tears the bodies only in its combat share of the blast (Defs.BODY_BLAST.combat)
	var share := float(Defs.BODY_BLAST["combat"])
	var d_spot := c_spot + Vector2(160, 0)
	var under: Unit = await _body("raptor", 1, d_spot)
	var victim: Unit = g._add_unit("brute", 1, d_spot + Vector2(3, 2))
	await physics_frame
	victim.process_mode = Node.PROCESS_MODE_DISABLED
	var m4: Unit = g._add_unit("mortar", 0, d_spot + Vector2(0, 220))
	await physics_frame
	m4.tesla_mode = "deployed"
	m4.cmd_attack(victim)
	var shells0 := m4.powder
	await wait_for(func() -> bool: return m4.powder < shells0 - 0.5, 20.0)
	await wait(2.5)
	m4.cmd_stop()
	check(m4.powder < shells0, "a Mortar fires an ordinary shell at a Brute standing on a body")
	if share > 0.0:
		check(under.torn and not g.corpses.has(under), "ordinary fire tears the body under its target (combat share %.2f)" % share)
	else:
		check(not under.torn and g.corpses.has(under), "ordinary fire leaves the bodies alone (combat share 0: only BOMBARD tears them)")
	g.consume_unit(victim)

	# ---- 4. the essence a body gives (Defs.HARVEST per_supply 1.25)
	check(is_equal_approx(g.corpse_value(mb), 1.25), "a Musketeer's body: 1.25 essence (%.2f)" % g.corpse_value(mb))
	check(is_equal_approx(g.corpse_value(rb), 1.25), "a Raptor's: 1.25")
	var brute: Unit = await _body("brute", 1, b_spot + Vector2(0, 120))
	var rider: Unit = g._add_unit("cuirassier", 0, b_spot + Vector2(80, 120))
	await physics_frame
	rider.take_damage(99999.0, null)
	await wait(0.5)
	check(is_equal_approx(g.corpse_value(brute), 3.75), "a Brute's: 3.75 (%.2f)" % g.corpse_value(brute))
	check(is_equal_approx(g.corpse_value(rider), 5.0), "a Horseman with his horse: 5 (%.2f)" % g.corpse_value(rider))
	check(Game.essence_text(1.25) == "1.25" and Game.essence_text(5.0) == "5" and Game.essence_text(2.5) == "2.5", "essence shown as 1.25, 5, 2.5")
	# a grub carries one home: +1.25 essence at the capital
	var hive: Building = null
	for b in g.buildings:
		if b.team == 1 and b.kind == "hive" and not b.dead:
			hive = b
	if hive:
		var at: Vector2 = g.cell_center(g.nearest_free(g.cell_of(hive.center() + Vector2(0, 150)), 8))
		var mh: Unit = await _body("musketeer", 0, at)
		await wait(1.6)
		var gr: Unit = g._add_unit("grub", 1, at + Vector2(30, 0))
		await physics_frame
		gr.cmd_harvest()
		var r0 := float(g.players[1]["res2"])
		var got := await wait_for(func() -> bool: return float(g.players[1]["res2"]) > r0 + 0.01, 40.0)
		check(got and is_equal_approx(float(g.players[1]["res2"]) - r0, 1.25), "a grub brings it home: +%.2f essence" % (float(g.players[1]["res2"]) - r0))
		g.consume_unit(gr)
	else:
		check(false, "the Brood's hall")

	# ---- 5. Shift-queueing
	var q_from := start + Vector2(0, 260)
	var mq: Unit = g._add_unit("mortar", 0, q_from)
	await physics_frame
	var q_to := q_from + Vector2(-160, 0)
	var q_spot := q_to + Vector2(0, -260)
	mq.give({"o": "move", "p": q_to})
	g.bombard_order([mq], q_spot, true)
	check(mq.order == "move" and mq.queue.size() == 1, "Shift: BOMBARD waits behind the move")
	var went := await wait_for(func() -> bool: return mq.order == "bombard", 20.0)
	check(went and mq.position.distance_to(q_to) < 60.0, "after the move it fires at the spot (%.0f px from the move's end)" % mq.position.distance_to(q_to))
	# the click with Shift: queued, and the mode stays on while Shift is held
	g.set_selection([mq])
	g.controls.begin_bombard()
	var q2 := q_spot + Vector2(-90, 0)
	g.controls._tap(_screen(q2), false, true)
	check(g.controls.mode == "bombard" and mq.queue.size() == 1 and mq.order_point.distance_to(q_spot) < 4.0, "Shift-click: queued behind the spot it fires at, BOMBARD stays on")
	_key(KEY_SHIFT, false, false, false)
	check(g.controls.mode == "", "letting go of Shift closes it")
	# with an order queued behind it, it fires Defs.BOMBARD.queued shots and goes on
	var pw0 := mq.powder
	var moved := await wait_for(func() -> bool: return mq.order_point.distance_to(q2) < 4.0, 60.0)
	check(moved, "then on to the queued spot")
	check(int(round(pw0 - mq.powder)) == int(Defs.BOMBARD["queued"]), "after %d shells at the first (%d fired)" % [int(Defs.BOMBARD["queued"]), int(round(pw0 - mq.powder))])
	# the HUD's waypoints include the BOMBARD spots
	mq.give({"o": "bombard", "p": q_spot}, true)
	check(mq.plan_points().any(func(pp: Array) -> bool: return pp[0] == "bombard"), "its plan shows the BOMBARD spots")
	mq.cmd_stop()

	# ---- 6. save and load: the order goes on
	var ms: Unit = g._add_unit("mortar", 0, start + Vector2(-200, 200))
	await physics_frame
	var s_spot := ms.position + Vector2(0, -250)
	g.bombard_order([ms], s_spot)
	await wait(4.0)
	SaveGame.save(g, {"map": "hollowfen", "seed": 4242})
	var d := SaveGame.peek()
	var rows: Array = Array(d.get("units", [])).filter(func(ud) -> bool: return ud is Dictionary and ud.has("bomb"))
	check(rows.size() == 1 and Vector2(float(rows[0]["bomb"][0]), float(rows[0]["bomb"][1])).distance_to(s_spot) < 1.0, "the save keeps the spot (%d units with one)" % rows.size())
	var g2 := Game.new()
	g2.map_id = "hollowfen"
	g2.demo = true
	g2.factions = ["crown", "brood"]
	g2.sides = [0, 1]
	root.add_child(g2)
	await process_frame
	await process_frame
	SaveGame.restore(g2, d)
	await process_frame
	var back: Array = g2.units.filter(func(u: Unit) -> bool: return u.kind == "mortar" and u.position.distance_to(ms.position) < 2.0)
	check(back.size() == 1 and back[0].order == "bombard" and back[0].order_point.distance_to(s_spot) < 1.0, "loaded: the Mortar is back on its BOMBARD")
	SaveGame.clear()
	g2.queue_free()
	ms.cmd_stop()

	# ---- 7. online: a guest's order reaches the host; a torn body goes on the guest's screen too
	check(NetCommands.GAME.has("bombard_order"), "the order is in the online command funnel")
	var hs := NetSession.new()
	hs.game = g
	hs.is_host = true
	hs.peer_team = {5: 0}
	var mo: Unit = g._add_unit("mortar", 0, start + Vector2(200, 200))
	await physics_frame
	hs.assign(mo)
	hs.by_id = {mo.net_id: mo}
	var o_spot := mo.position + Vector2(0, -240)
	var why := NetCommands.apply(hs, 5, {"o": 0, "f": "bombard_order", "a": [[{"e": mo.net_id}], o_spot, false]})
	check(why == "" and mo.order == "bombard" and mo.order_point.distance_to(o_spot) < 1.0, "the host runs a guest's BOMBARD (%s)" % (why if why != "" else "ok"))
	mo.cmd_stop()
	g.net = hs
	var lone: Unit = await _body("raptor", 1, start + Vector2(-200, -200))
	await wait(1.6)
	g.tear_body(lone, true)
	check(hs.fx.any(func(f: Array) -> bool: return f[0] == "c"), "the host tells the guest a body was torn up")
	g.net = null
	var gb: Unit = await _body("raptor", 1, start + Vector2(-260, -200))
	await wait(1.6)
	g.torn_at(gb.position)
	check(gb.torn, "the guest's copy of it goes too")

	# ---- 8. the Crown computer facing the Brood: an idle Mortar shells a pile of bodies, then stands down; never with
	# an armed enemy about
	var ai := AI.new()
	ai.game = g
	ai.team = 0
	ai.difficulty = 2
	ai.process_mode = Node.PROCESS_MODE_DISABLED       # (only asked to do this one thing)
	g.add_child(ai)
	await physics_frame
	for u in g.units.duplicate():
		if u.team == 0 and u.can_bombard():
			g.consume_unit(u)       # (the guns of the sections before: only this one is idle near the pile)
	var pile: Vector2 = g.cell_center(g.nearest_free(g.cell_of(start + Vector2(260, -420)), 6))
	for k in 4:
		await _body("raptor", 1, pile + Vector2(-12 + k * 8, (k % 2) * 10 - 5))
	var am: Unit = g._add_unit("mortar", 0, pile + Vector2(0, 250))
	var eye: Unit = g._add_unit("musketeer", 0, pile + Vector2(-80, 120))
	await wait(2.0)
	ai._shell_bodies()
	check(am.order == "bombard" and am.order_point.distance_to(pile) < 30.0 and ai.shell_log.size() == 1, "the Crown computer has its idle Mortar shell the bodies (%s)" % am.order)
	var torn1: int = g.bodies_blasted["aimed"]
	var cleared := await wait_for(func() -> bool:
		ai._shell_bodies()
		return am.order == "idle", 40.0)
	check(cleared and int(g.bodies_blasted["aimed"]) > torn1, "and stands down when they are gone (%d torn)" % (int(g.bodies_blasted["aimed"]) - torn1))
	check(g.corpses.filter(func(b) -> bool: return is_instance_valid(b) and b.position.distance_to(pile) < 40.0).is_empty(), "the pile is gone for the Brood")
	# a new pile with an enemy standing by: no shelling
	var pile2: Vector2 = g.cell_center(g.nearest_free(g.cell_of(pile + Vector2(-160, 0)), 6))
	for k in 4:
		await _body("raptor", 1, pile2 + Vector2(-12 + k * 8, (k % 2) * 10 - 5))
	var foe: Unit = g._add_unit("spitter", 1, pile2 + Vector2(60, -100))
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	await wait(2.0)
	ai._shell_t = 0.0
	ai._shell_bodies()
	check(am.order != "bombard", "not with an armed enemy in sight (never mid-battle)")
	g.consume_unit(foe)
	ai._shell_t = 0.0
	ai.shell_bodies_on = false
	ai._shell_bodies()
	check(am.order != "bombard", "and not when switched off")
	ai.queue_free()
	g.consume_unit(eye)

	Settings.device = was_dev
	print("attack ground: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
