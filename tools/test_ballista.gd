extends SceneTree
## THE SPRING BALLISTA (scripts/ballista.gd, Defs.BALLISTA, docs/ballista.md): made at the Movement Works once an Escapement
## works (cogs and Tension); its bolt PIERCES a line (the first enemy whole, the next ones 50% and 30%, not one off the line,
## never its own side); ARMOURED units and BUILDINGS take more, a building stops the bolt; the spring winds only while it
## stands, 10% faster per crewman (0..4), and it moves 10% faster per crewman; Winders BOARD it (4 at most), stand beside
## it as crew, can be hit and killed (the bonus goes with them), UNLOAD sets them down; it fires ON THE MOVE at what is
## ahead; it cannot hit flyers nor shoot under its least range; a save keeps its crew and its reload; online the guest gets
## its loaded/fired state and the crew. The computer's side: tools/test_ballista_ai.gd.
##   godot --headless --fixed-fps 30 --script res://tools/test_ballista.gd
const U := preload("res://tools/gear_test_util.gd")
const K := Defs.BALLISTA_KIND
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func step(g: Game, secs: float) -> void:
	U.step(g, secs)


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var wd: Dictionary = Defs.BUILDINGS[Defs.CW_WORKS]
	check("the Movement Works trains the Spring Ballista", (wd["trains"] as Array).has(K))
	check("it is in the gear-mode roster (not retired)", Defs.CW_NEW_UNITS.has(K) and not Defs.retired(K))
	check("the Spring Catapult is not in the roster", not Defs.CW_NEW_UNITS.has("spring_catapult") and not Defs.UNITS.has("spring_catapult"))
	check("its price is cogs and Tension", g.unit_price(0, K) == [int(Defs.UNITS[K]["cost"]), int(Defs.UNITS[K]["tension"])], str(g.unit_price(0, K)))
	g.players[0]["gold"] = 50000
	g.players[0]["tension"] = 5000.0
	var hall := U.hall(g, 0)
	var works := U.put(g, 0, Defs.CW_WORKS, hall.cell)
	g._recount_supply(0)
	g.players[0]["cap"] = 200
	var why := g.can_train(works, K)
	check("no Escapement: the Ballista is refused", why.contains("Escapement"), why)
	var esc := U.put(g, 0, Defs.CW_TECH, hall.cell)
	_spring_beside(g, esc)
	if g.gear_net.spring_for(works) == null:
		_spring_beside(g, works)
	U.step(g, 0.6)
	g.players[0]["cap"] = 200
	why = g.can_train(works, K)
	check("with a working Escapement (and a Mainspring at the Works) it trains", why == "", why)
	var ten0 := g.tension(0)
	why = g.train(works, K)
	check("the order spends its Tension", why == "" and is_equal_approx(g.tension(0), ten0 - float(Defs.UNITS[K]["tension"])), why)
	U.step(g, float(Defs.UNITS[K]["time"]) + 2.0)
	var made := g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == K and not u.dead)
	check("a Spring Ballista came out", made.size() == 1, "%d" % made.size())
	_clear(g, made)
	# ---- the BOLT through a line: the first enemy whole, then 50% and 30%; not one off the line, never a friend
	var at := _open_near(g, hall.center() + Vector2(0, 300))
	var b: Unit = g._add_unit(K, 0, at)
	b.cmd_stop()
	b.facing = Vector2.RIGHT
	g.camera.position = at
	g.view_rect = Rect2(at - Vector2(900, 600), Vector2(1800, 1200))
	var dmg := float(Defs.UNITS[K]["damage"])
	var line: Array = []
	for i in 4:
		line.append(_foe(g, "musketeer", at + Vector2(170 + i * 34, 0)))
	var off: Unit = _foe(g, "musketeer", at + Vector2(220, 60))
	var friend: Unit = g._add_unit("clock_soldier", 0, at + Vector2(187, 3))
	friend.cmd_hold()
	for o in line + [off, friend]:
		_tough(o)
	var fhp: float = friend.hp
	b.cmd_attack(line[0])
	var t := 0.0
	while b.bolts == 0 and t < 5.0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
	var lost := func(o: Unit) -> float: return 1000.0 - o.hp
	var shares: Array = Defs.BALLISTA["hits"]
	check("it fired a bolt (no set-up)", b.bolts == 1, "%.2f s" % t)
	check("the first enemy took the whole shot", absf(lost.call(line[0]) - (dmg * float(shares[0]) - line[0].armor)) < 1.5, "%.1f" % lost.call(line[0]))
	check("the next one in the line took half", absf(lost.call(line[1]) - (dmg * float(shares[1]) - line[1].armor)) < 1.5, "%.1f" % lost.call(line[1]))
	check("the third took 30%", absf(lost.call(line[2]) - (dmg * float(shares[2]) - line[2].armor)) < 1.5, "%.1f" % lost.call(line[2]))
	check("no fourth (three at most)", lost.call(line[3]) < 0.5, "%.1f" % lost.call(line[3]))
	check("not the enemy off the line", lost.call(off) < 0.5)
	check("never its own side in the line", friend.hp >= fhp)
	check("it shows fired while it winds", not b.loaded and b._anim_name() == "attack", "%s %s" % [str(b.loaded), b._anim_name()])
	_clear(g, line + [off, friend])
	b.cmd_stop()
	b.cooldown = 99.0          # (it holds its own fire: the shots below are fired by hand)
	step(g, 0.2)
	# ---- ARMOUR and BUILDINGS take more; a building stops the bolt
	var gun: Unit = _foe(g, "cannon", at + Vector2(200, 0))
	_tough(gun)
	b.cooldown = 0.0
	b.loaded = true
	var n0 := b.bolts
	Ballista.fire(b, gun, dmg)
	var want := dmg * float(Defs.BALLISTA["vs_armored"])
	check("an armoured unit (a Crown Cannon) takes x%.2f" % float(Defs.BALLISTA["vs_armored"]), absf(lost.call(gun) - (want - gun.armor)) < 2.0 and b.bolts == n0 + 1, "%.1f" % lost.call(gun))
	_clear(g, [gun])
	step(g, 0.2)
	var wall_c := g.cell_of(at + Vector2(200, 0))
	var gate: Building = g._add_building("gate", 1, wall_c, true)
	var past: Unit = _foe(g, "musketeer", at + Vector2(280, 0))
	_tough(past)
	var ghp := gate.hp
	var hits := Ballista.line_shot(b, gate.center(), dmg, gate)
	check("a gate takes the building bonus (x%.1f)" % float(Defs.UNITS[K]["building_bonus"]), ghp - gate.hp >= dmg * float(Defs.UNITS[K]["building_bonus"]) - gate.armor - 1.0, "%.1f" % (ghp - gate.hp))
	check("the bolt sticks in it: the man behind is not hit", lost.call(past) < 0.5 and hits.size() == 1, "%d hit" % hits.size())
	var php := past.hp
	ghp = gate.hp
	hits = Ballista.line_shot(b, past.position, dmg, past)
	check("aimed at the man behind the gate, the bolt hits the gate and stops", gate.hp < ghp and past.hp >= php and hits.size() == 1 and hits[0] == gate,
			str(hits.map(func(e) -> String: return e.kind)))
	_clear(g, [past])
	gate.queue_free()
	g.buildings.erase(gate)
	# ---- no flyers, nothing under its least range
	var bl: Unit = _foe(g, "balloon", at + Vector2(150, -40))
	check("it cannot hit flyers", not b.can_hit(bl))
	_clear(g, [bl])
	# ---- the RELOAD: wound only while it stands; 7 s alone, 10% faster per crewman
	var base := float(Defs.UNITS[K]["cooldown"])
	b.cooldown = base
	b.loaded = false
	b.cmd_stop()
	b.phase = ""
	t = _wind_time(g, b)
	check("alone it winds in %.0f s" % base, absf(t - base) < 0.2, "%.2f s" % t)
	# moving: no winding
	b.cooldown = base
	b.cmd_move(at + Vector2(-200, 0))
	step(g, 1.5)
	check("on the move the spring is not wound", b.cooldown > base - 0.3, "%.2f s left" % b.cooldown)
	var sp1 := b.velocity.length()
	b.cmd_stop()
	step(g, 1.0)
	# ---- the CREW: Winders board it (4 at most), stand by it, each +10%
	var ws: Array = []
	for i in 5:
		var w: Unit = g._add_unit("winder", 0, _open_near(g, b.position + Vector2(-60 - i * 20, 60)))
		w.auto_work = false
		w.cmd_stop()
		ws.append(w)
	check("a Winder can board it, a Musketeer cannot", ws[0].can_board(b) and not g._add_unit("musketeer", 0, b.position + Vector2(0, 80)).can_board(b))
	g.load_order(ws, [b])
	step(g, 12.0)
	var crew := Ballista.crew_of(b)
	check("four Winders crew it (its room is 4)", crew.size() == 4, "%d" % crew.size())
	check("the fifth one could not board", ws[4].crew_of == null and b.room() == 0)
	check("the crew stay on the field, by it", crew.all(func(w: Unit) -> bool: return not w.off_field and w.visible and w.position.distance_to(b.position) < 140.0),
			str(crew.map(func(w: Unit) -> int: return int(w.position.distance_to(b.position)))))
	check("they are not workers any more (the economy leaves them)", not g.workers(0).has(crew[0]))
	check("its own crewman is drawn (a sprite, not a unit)", b.has_meta("own_crew") and (b.get_meta("own_crew") as Sprite2D).visible)
	check("rate with four crew: 1.4", is_equal_approx(Ballista.rate(b), 1.4), "%.2f" % Ballista.rate(b))
	b.cooldown = base
	b.loaded = false
	var crank_seen := [false]
	t = _wind_time(g, b, crank_seen, crew[0])
	check("with four crew it winds in %.1f s" % (base / 1.4), absf(t - base / 1.4) < 0.2, "%.2f s" % t)
	check("the crew crank while it winds", crank_seen[0])
	b.cmd_move(at + Vector2(300, 0))
	step(g, 1.5)
	var sp4 := b.velocity.length()
	check("with four crew it moves 40% faster", absf(sp4 / maxf(sp1, 1.0) - 1.4) < 0.08, "%.1f vs %.1f" % [sp4, sp1])
	check("the crew push while it moves", crew.all(func(w: Unit) -> bool: return w.anim == "push"), str(crew.map(func(w: Unit) -> String: return w.anim)))
	check("pushers stand behind it", crew.all(func(w: Unit) -> bool: return (w.position - b.position).dot(b.facing) < 0.0))
	b.cmd_stop()
	step(g, 1.0)
	# selecting a crewman selects the machine
	g.set_selection([crew[1]])
	check("picking a crewman picks the Ballista", g.selection.size() == 1 and g.selection[0] == b)
	g.set_selection([])
	# the crew can be hit: shoot one down, the bonus goes
	var victim: Unit = crew[0]
	var shooter: Unit = _foe(g, "musketeer", _open_near(g, victim.position + Vector2(-90, 40)))
	shooter.max_hp = 5000.0          # (the Ballista shoots back: it must outlast it)
	shooter.hp = 5000.0
	shooter.cmd_attack(victim)
	t = 0.0
	while not victim.dead and t < 30.0:
		step(g, 0.5)
		t += 0.5
	check("an enemy can shoot a crewman dead", victim.dead, "%.0f s" % t)
	check("then three crew, rate 1.3", Ballista.crew_of(b).size() == 3 and is_equal_approx(Ballista.rate(b), 1.3), "%d" % Ballista.crew_of(b).size())
	_clear(g, [shooter])
	# a save keeps the crew and the reload
	b.cooldown = 3.3
	b.loaded = false
	g.demo = false
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 4242})
	g.demo = true
	var sd := SaveGame.peek()
	var g3 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g3, sd)
	await process_frame
	var b3: Array = g3.units.filter(func(u: Unit) -> bool: return u.kind == K and u.team == 0 and not u.dead)
	check("a save keeps the Ballista, its crew and its reload", b3.size() == 1 and Ballista.crew_of(b3[0]).size() == 3 and absf(b3[0].cooldown - 3.3) < 0.05 and not b3[0].loaded,
			"%d, crew %d, %.2f" % [b3.size(), Ballista.crew_of(b3[0]).size() if not b3.is_empty() else -1, b3[0].cooldown if not b3.is_empty() else -1.0])
	SaveGame.clear()
	g3.process_mode = Node.PROCESS_MODE_DISABLED
	g3.queue_free()
	await process_frame
	# UNLOAD: they step off, free Winders again
	var crew_now := Ballista.crew_of(b).duplicate()
	g.unload_order([b], Vector2.ZERO, true)
	step(g, 0.5)
	check("UNLOAD: the crew step off (free Winders, where they stood)", Ballista.crew_of(b).is_empty() and crew_now.all(func(w: Unit) -> bool: return w.crew_of == null and w.order != "crew" and g.workers(0).has(w)))
	check("then rate 1.0", is_equal_approx(Ballista.rate(b), 1.0))
	# another order takes a crewman off
	g.load_order([crew_now[0]], [b])
	step(g, 4.0)
	check("one boards again", crew_now[0].crew_of == b)
	crew_now[0].cmd_move(b.position + Vector2(0, 200))
	step(g, 0.2)
	check("a crewman given another order steps off", crew_now[0].crew_of == null and Ballista.crew_of(b).is_empty())
	# ON THE MOVE: loaded, it shoots at an enemy in range ahead without stopping
	b.cooldown = 0.0
	b.loaded = true
	b.cmd_stop()
	step(g, 0.2)
	var ahead: Unit = _foe(g, "musketeer", _open_near(g, b.position + Vector2(260, 0)))
	_tough(ahead)
	ahead.d = ahead.d.duplicate()
	ahead.d["range"] = 0
	b.facing = Vector2.RIGHT
	var n1 := b.bolts
	b.cmd_move(b.position + Vector2(140, 0))
	var moved_fire := false
	t = 0.0
	while t < 3.0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if b.bolts > n1:
			moved_fire = b.order == "move"
			break
	check("it fires on the move at an enemy ahead (a MOVE order, still moving)", moved_fire and lost.call(ahead) > 0.0, "%d bolts, order %s" % [b.bolts - n1, b.order])
	# the Ballista dies: its crew step off
	b.cmd_stop()
	g.load_order([ws[4]], [b])
	step(g, 12.0)
	var last: Unit = ws[4]
	var on := last.crew_of == b
	b.take_damage(10000.0, null)
	step(g, 0.3)
	check("destroyed, its crew step off alive", on and not last.dead and last.crew_of == null, str(on))
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.queue_free()
	await process_frame
	await process_frame
	await _online()
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)


## Seconds for b's spring to wind from its cooldown to loaded, standing. crank: [seen] set when w plays "crank".
func _wind_time(g: Game, b: Unit, crank := [false], w: Unit = null) -> float:
	var t := 0.0
	while not b.loaded and t < 20.0:
		step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if w != null and w.anim == "crank":
			crank[0] = true
	return t


## ONLINE: the guest gets the loaded/fired state and the crew (their ballista, their crank).
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
	var at := _open_near(h, hall.center() + Vector2(0, 260))
	var b: Unit = h._add_unit(K, 0, at)
	var w: Unit = h._add_unit("winder", 0, at + Vector2(-40, 40))
	w.auto_work = false
	Ballista.take_crew(b, w)
	b.cooldown = 4.0
	b.loaded = false
	sync.call()
	var gb: Unit = null
	var gw: Unit = null
	for u in gu.units:
		if u.net_id == b.net_id:
			gb = u
		elif u.net_id == w.net_id:
			gw = u
	check("online: the guest sees the Ballista fired (winding)", gb != null and not gb.loaded)
	check("online: the guest knows its crewman", gw != null and gw.crew_of == gb and gb.crew.has(gw))
	b.cooldown = 0.0
	b.loaded = true
	sync.call()
	check("online: and then loaded", gb != null and gb.loaded)
	check("online: the check lists match", NetSnapshot.check_lists(b, null) == "", NetSnapshot.check_lists(b, null))
	sg.queue_free()
	sh.queue_free()
	h.queue_free()
	gu.queue_free()


func _tough(o: Unit) -> void:
	o.max_hp = 1000.0
	o.hp = 1000.0
	o.d = o.d.duplicate()
	o.d["damage"] = 0


func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.auto_work = false
	u.cmd_hold()
	return u


func _clear(g: Game, list: Array) -> void:
	for u in list:
		if is_instance_valid(u):
			g.units.erase(u)
			g.selection.erase(u)
			u.queue_free()


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


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
