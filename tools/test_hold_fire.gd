extends SceneTree
## HOLD FIRE for every Crown firearm (Musketeer / Guardsman, Dragoon, Field Cannon, Mortar,
## Observation Balloon; the cavalry pistol has its own test, tools/test_pistol.gd):
##   godot --headless --fixed-fps 30 --script res://tools/test_hold_fire.gd
##  1. held, a Musketeer never fires by himself: not at an enemy in range, not back at one
##     shooting him, not on attack-move; an ATTACK order on a target still fires
##  2. held, he still fights with the bayonet when an enemy comes at him
##  3. a Field Cannon and a Mortar the same: no shot of their own, ATTACK fires
##  4. a Dragoon in the saddle on attack-move doesn't get down to shoot; HOLD FIRE stays
##     through mounting and dismounting; ATTACK makes him dismount and fire
##  5. a balloon's basket keeps its fire while the balloon holds
##  6. the card's HOLD FIRE button toggles a mixed selection at once
##  7. save / load keeps HOLD FIRE
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
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


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func unit(k: String, p: Vector2, team := 0) -> Unit:
	return g._add_unit(k, team, p)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _clear_units() -> void:
	for u in g.units.duplicate():
		if u.position.distance_to(at(400, 300)) < 1100.0:
			g.consume_unit(u)
	await physics_frame


## A tough enemy that stands still and can't hit back.
func dummy(p: Vector2) -> Unit:
	var e := unit("musketeer", p, 1)
	e.max_hp = 5000.0
	e.hp = 5000.0
	e.powder = 0.0
	e._pmax = 0.0
	e.cmd_hold()
	e.stun_t = 9999.0
	return e


func tough(u: Unit) -> Unit:
	u.max_hp = 5000.0
	u.hp = 5000.0
	return u


func _run() -> void:
	origin = _open_area(26, 20)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	seed(11)
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	await _clear_units()
	await _musket()
	await _bayonet()
	await _guns()
	await _dragoon()
	await _balloon()
	await _button()
	await _save_load()
	print("hold fire: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- 1

func _musket() -> void:
	var m := tough(unit("musketeer", at(200, 300)))
	m.put_on_armour()                 # (a Guardsman: the same musket)
	m.set_hold_fire(true)
	check(m.hold_fire, "a Guardsman takes HOLD FIRE")
	var e := dummy(at(350, 300))
	var p0 := m.powder
	var h0 := e.hp
	await wait(6.0)
	check(m.powder == p0 and e.hp == h0, "held: no shot at an enemy in range (powder %d/%d, hp %.0f)" % [int(m.powder), int(p0), h0 - e.hp])
	# an enemy shooting at him: no fire back
	var shooter := tough(unit("musketeer", at(360, 340), 1))
	await wait(8.0)
	check(m.hp < m.max_hp and m.powder == p0, "held: shot at (%.0f damage taken), he doesn't fire back" % (m.max_hp - m.hp))
	g.consume_unit(shooter)
	# attack-move past it: no shot
	m.cmd_move(at(250, 120), true)
	await wait(5.0)
	check(m.powder == p0 and e.hp == h0, "held: attack-move doesn't fire")
	# an ATTACK order fires
	m.cmd_attack(e)
	var shot := await wait_for(func() -> bool: return e.hp < h0, 8.0)
	check(shot and m.powder < p0 and m.hold_fire, "held: an ATTACK order still fires (%.0f damage)" % (h0 - e.hp))
	# HOLD FIRE off: he picks his own targets again
	m.cmd_stop()
	m.set_hold_fire(false)
	var h1 := e.hp
	shot = await wait_for(func() -> bool: return e.hp < h1, 8.0)
	check(shot, "HOLD FIRE off: he fires by himself")
	g.consume_unit(m)
	g.consume_unit(e)
	await physics_frame


# ---------------------------------------------------------------- 2

func _bayonet() -> void:
	var m := tough(unit("musketeer", at(200, 300)))
	m.set_hold_fire(true)
	var r := tough(unit("raptor", at(320, 300), 1))
	r.cmd_attack(m)
	var p0 := m.powder
	var h0 := r.hp
	var hit := await wait_for(func() -> bool: return r.hp < h0 - 30.0, 10.0)
	check(hit and m.powder == p0, "held: a Raptor at him gets the bayonet (%.0f damage, powder %d/%d)" % [h0 - r.hp, int(m.powder), int(p0)])
	g.consume_unit(m)
	g.consume_unit(r)
	await physics_frame


# ---------------------------------------------------------------- 3

func _guns() -> void:
	for k in ["cannon", "mortar"]:
		var c := tough(unit(k, at(150, 300)))
		c.set_hold_fire(true)
		var e := dummy(at(420, 300))
		var p0 := c.powder
		var h0 := e.hp
		await wait(9.0)
		check(c.hold_fire and c.powder == p0, "%s held: no shot of its own (powder %d -> %d)" % [k, int(p0), int(c.powder)])
		c.cmd_attack(e)
		var shot := await wait_for(func() -> bool: return c.powder < p0, 12.0)
		check(shot, "%s held: an ATTACK order fires (powder %d -> %d)" % [k, int(p0), int(c.powder)])
		c.cmd_stop()
		c.set_hold_fire(false)
		var p1 := c.powder
		shot = await wait_for(func() -> bool: return c.powder < p1, 12.0)
		check(shot, "%s: HOLD FIRE off, it fires by itself" % k)
		g.consume_unit(c)
		g.consume_unit(e)
		await physics_frame


# ---------------------------------------------------------------- 4

func _dragoon() -> void:
	var d := tough(unit("dragoon", at(100, 300)))
	d.auto_mount = true
	d.set_hold_fire(true)
	var e := dummy(at(330, 430))       # (in musket range of his way, not in his way)
	var h0 := e.hp
	d.cmd_move(at(560, 300), true)
	await wait(5.0)
	check(e.hp == h0 and d.kind == "dragoon", "held Dragoon on attack-move: rides on, no shot (%s, %.0f px from the enemy)" % [d.kind, d.position.distance_to(e.position)])
	d.cmd_dismount()
	await wait_for(func() -> bool: return d.kind == "musketeer", 5.0)
	check(d.kind == "musketeer" and d.hold_fire, "dismounted: HOLD FIRE kept")
	var pw := d.powder
	await wait(3.0)
	check(d.powder == pw, "on foot: still no shot of his own (powder %d -> %d, %.0f px off, mode '%s', hp lost %.0f)" % [int(pw), int(d.powder), d.position.distance_to(e.position), d.mode, h0 - e.hp])
	var st: Unit = d.steed
	d.cmd_mount(st)
	await wait_for(func() -> bool: return d.kind == "dragoon", 6.0)
	check(d.kind == "dragoon" and d.hold_fire, "back in the saddle: HOLD FIRE kept")
	d.cmd_attack(e)
	var shot := await wait_for(func() -> bool: return e.hp < h0, 14.0)
	check(shot, "held Dragoon: ATTACK makes him get down and fire (%s)" % d.kind)
	if d.steed and is_instance_valid(d.steed):
		g.consume_unit(d.steed)
	g.consume_unit(d)
	g.consume_unit(e)
	await physics_frame


# ---------------------------------------------------------------- 5

func _balloon() -> void:
	var b := tough(unit("balloon", at(200, 300)))
	for i in 2:
		var m := unit("musketeer", at(200, 300))
		b.take_aboard(m)
	check(b.passengers.size() == 2, "two Musketeers in the basket")
	b.set_hold_fire(true)
	var e := dummy(at(330, 300))
	var h0 := e.hp
	await wait(6.0)
	check(b.hold_fire and e.hp == h0, "balloon held: the basket keeps its fire")
	b.set_hold_fire(false)
	var shot := await wait_for(func() -> bool: return e.hp < h0, 8.0)
	check(shot, "balloon free: the basket fires")
	for p in b.passengers.duplicate():
		g.consume_unit(p)
	g.consume_unit(b)
	g.consume_unit(e)
	await physics_frame


# ---------------------------------------------------------------- 6

func _button() -> void:
	var sel: Array = [unit("musketeer", at(200, 300)), unit("cannon", at(240, 300)), unit("cuirassier", at(280, 300)),
		unit("mortar", at(320, 300)), unit("balloon", at(360, 300)), unit("labourer", at(400, 300))]
	g.set_selection(sel)
	await physics_frame
	var press := func() -> bool:
		var list: Array = []
		g.hud._ability_buttons(list, g.selected_units())
		for it in list:
			if String(it[1]).ends_with("HOLD FIRE"):
				(it[2] as Callable).call()
				return true
		return false
	check(press.call(), "a mixed selection shows one HOLD FIRE button")
	var guns: Array = sel.filter(func(u: Unit) -> bool: return u.kind != "labourer")
	check(guns.all(func(u: Unit) -> bool: return u.hold_fire) and not sel[5].hold_fire, "one press: every gun in the selection holds (the labourer has none)")
	press.call()
	check(guns.all(func(u: Unit) -> bool: return not u.hold_fire), "pressed again: all fire at will")
	# some held, some not: the button holds them all
	sel[0].set_hold_fire(true)
	press.call()
	check(guns.all(func(u: Unit) -> bool: return u.hold_fire), "partly held: one press holds them all")
	g.set_selection([])
	for u in sel:
		g.consume_unit(u)
	await physics_frame


# ---------------------------------------------------------------- 7

func _save_load() -> void:
	await _clear_units()
	var a := unit("musketeer", at(200, 300))
	a.set_hold_fire(true)
	var b := unit("mortar", at(260, 300))
	b.set_hold_fire(true)
	var c := unit("cannon", at(320, 300))
	SaveGame.save(g, {"map": "random", "seed": 4242})
	var d := SaveGame.peek()
	SaveGame.restore(g, d)
	await physics_frame
	var ms: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "musketeer")
	var mo: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "mortar")
	var cs: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cannon")
	check(ms.size() == 1 and ms[0].hold_fire, "loaded: the Musketeer still holds")
	check(mo.size() == 1 and mo[0].hold_fire, "loaded: the Mortar still holds")
	check(cs.size() == 1 and not cs[0].hold_fire, "loaded: the Cannon fires at will")
	SaveGame.clear()
	await _clear_units()
