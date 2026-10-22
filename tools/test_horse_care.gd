extends SceneTree
## Horse care and seasoning:
##   godot --headless --fixed-fps 30 --script res://tools/test_horse_care.gd
##  1. a riderless horse heals by itself
##  2. a ridden horse seasons with the ground it covers (rider and horse get the health) and
##     keeps it when he gets off; a gun's team horses season too
##  3. a seasoned carcass, and a rider's body, are worth more to the Brood
##  4. a fallen Dragoon raised: back on foot as a Musketeer, his horse left dead
##  5. a Missionary bandaging a Dragoon: the Dragoon gets off, is bandaged, gets back on
##  6. a Mounted Missionary bandaging a Horseman: both get off, then both back on
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


## Wait until cond() is true (at most `sec` game seconds). True if it came true.
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
		if u.team == 0 and u.is_worker() and u.order == "gather":
			continue
		if u.position.distance_to(at(400, 300)) < 900.0:
			g.consume_unit(u)
	await physics_frame


func _run() -> void:
	origin = _open_area(26, 20)
	await _clear_units()
	var T := Defs.TILE
	# 1
	var h := unit("horse", at(100, 100))
	h.hp = 20.0
	await wait(10.0)
	check(h.hp > 23.0 and h.hp < 27.0, "a lone horse heals by itself (%.1f)" % h.hp)
	# 2
	var m := unit("musketeer", at(140, 100))
	h.horse_miles = 95.0
	h.hp = h.max_hp
	m.cmd_mount(h)
	await wait_for(func() -> bool: return m.kind == "dragoon", 10.0)
	check(m.kind == "dragoon", "he mounts")
	var hp0 := float(m.max_hp)
	m.cmd_move(m.position + Vector2(12 * T, 0))
	await wait_for(func() -> bool: return Unit.horse_rank(m.horse_miles) >= 1, 15.0)
	check(Unit.horse_rank(m.horse_miles) == 1 and m.max_hp > hp0 + 8.0, "riding seasons it: rank 1, the Dragoon %.0f -> %.0f health" % [hp0, m.max_hp])
	await wait(1.0)
	m.cmd_dismount()
	await wait_for(func() -> bool: return m.kind == "musketeer", 10.0)
	var st: Unit = m.steed
	check(st != null and st.horse_miles >= 100.0 and st.max_hp > 68.0, "off again: the horse keeps it (%.0f tiles, %.0f health)" % [st.horse_miles if st else 0.0, st.max_hp if st else 0.0])
	var c := unit("cannon", at(200, 300))
	var th := unit("horse", at(240, 300))
	c.harness(th)
	var th2 := unit("horse", at(240, 300))
	th2.horse_miles = 50.0
	c.harness(th2)
	c.cmd_move(c.position + Vector2(8 * T, 0))
	await wait(6.0)
	check(c.horse_miles > 1.0 and float(c.team_horses.back().get("m", 0.0)) > 51.0, "a gun's horses season too (%.1f, team %.1f)" % [c.horse_miles, float(c.team_horses.back().get("m", 0.0))])
	# 3
	var vh := unit("horse", at(100, 400))
	vh.horse_miles = 250.0
	check(Game.body_supply(vh) == 3, "a rank-2 horse's carcass is worth 3 supply (%d)" % Game.body_supply(vh))
	var cu := unit("cuirassier", at(140, 400))
	check(Game.body_supply(cu) == int(cu.d["supply"]) + 1, "a Horseman's body: his supply and his horse's (%d)" % Game.body_supply(cu))
	g.consume_unit(vh)
	g.consume_unit(cu)
	# 4
	var dg := unit("dragoon", at(300, 500))
	dg.coat = "bay" if HorseCoat.COATS.has("bay") else HorseCoat.pick()
	var miss := unit("missionary", at(240, 500))
	dg.take_damage(9999.0, null)
	await wait(0.5)
	check(dg.dead and g.fallen.has(dg), "a fallen Dragoon can be raised")
	miss.cmd_revive(dg)
	await wait_for(func() -> bool: return not dg.dead, 15.0)
	check(not dg.dead and dg.kind == "musketeer", "raised on foot as a %s" % dg.kind)
	var carcass: Array = g.corpses.filter(func(u) -> bool: return u.kind == "horse" and u.dead and u.position.distance_to(dg.position) < 60.0)
	check(carcass.size() == 1 and g.corpses.has(carcass[0]), "his horse stays dead, for the Brood to harvest")
	# 5
	var d2 := unit("dragoon", at(500, 200))
	d2.hp = d2.max_hp * 0.4
	var m2 := unit("missionary", at(440, 200))
	await wait(0.5)
	m2.cmd_heal(d2)
	var got_off := await wait_for(func() -> bool: return d2.kind == "musketeer", 15.0)
	check(got_off, "the Dragoon gets off to be bandaged")
	var back := await wait_for(func() -> bool: return d2.kind == "dragoon" and d2.hp >= d2.max_hp - 0.5, 30.0)
	check(back, "bandaged, he's back on his horse (%s, %.0f/%.0f)" % [d2.kind, d2.hp, d2.max_hp])
	# 6
	var c3 := unit("cuirassier", at(500, 450))
	c3.hp = c3.max_hp * 0.4
	var m3 := unit("mounted_missionary", at(420, 450))
	await wait(0.5)
	m3.cmd_heal(c3)
	var both_off := await wait_for(func() -> bool: return m3.kind == "missionary" and c3.kind == "dismounted", 20.0)
	check(both_off, "both get off")
	var both_on := await wait_for(func() -> bool: return m3.kind == "mounted_missionary" and c3.kind == "cuirassier", 30.0)
	check(both_on and c3.hp >= c3.max_hp - 0.5, "both back on, the Horseman healed (%s %s, %.0f/%.0f)" % [m3.kind, c3.kind, c3.hp, c3.max_hp])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
