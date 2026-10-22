extends SceneTree
## Buildings animate only while they're in use (Building.in_use):
##   godot --headless --fixed-fps 30 --script res://tools/test_building_anim.gd
##  1. the Powder Mill's horse: none while it's built up, none on the ruin; it stands still on
##     its track while nobody works the mill, walks round it (the sweep from the post to it)
##     while a Labourer works there, and comes to a halt again when he leaves; behind the post
##     and millstone on the far half of the track, in front of them on the near half
##  2. the Farm's sails: still while nobody works its fields, turning while somebody does
##  3. the Foundry's smoke: none while it's idle, puffs while it trains something
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


func _run() -> void:
	origin = _open_area(22, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	g.camera.position = Vector2(origin + Vector2i(11, 7)) * Defs.TILE
	await _mill()
	await _farm()
	await _foundry()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _labourer(b: Building) -> Unit:
	var u: Unit = g._add_unit("labourer", 0, b.center() + Vector2(0, b.rect().size.y * 0.5 + 20))
	await physics_frame
	u.auto_work = false          # (stopped, it stays idle: doesn't go back to a post by itself)
	u.cmd_gather(b)
	return u


func _mill() -> void:
	var site: Building = g._add_building("powder_mill", 0, origin + Vector2i(14, 2), false)
	await wait(0.6)
	check(site._mill_state == "" and not site._mill_horse.visible, "no horse while the mill is built up")
	site.die()
	var m: Building = g._add_building("powder_mill", 0, origin + Vector2i(2, 2), true)
	await wait(2.0)
	check(m._mill_state == "built" and m._mill_horse.visible and m._mill_arm.visible, "the built mill shows its horse and sweep")
	var a0: float = m._mill_a
	await wait(1.0)
	check(m._mill_v == 0.0 and m._mill_a == a0 and m._mill_horse.frame == 0, "nobody working it: the horse stands still")
	var u := await _labourer(m)
	check(await wait_for(func() -> bool: return m.working_crew() > 0, 25.0), "a Labourer works the mill")
	await wait(2.0)
	var a1: float = m._mill_a
	await wait(1.0)
	var step := fposmod(m._mill_a - a1, TAU)
	check(m._mill_v == 1.0 and absf(step - TAU / float(Building.MILL_ART["lap"])) < 0.05,
		"worked: the horse walks round at a lap every %d s (%.2f rad in 1 s)" % [int(Building.MILL_ART["lap"]), step])
	var frames := {}
	for i in 30:
		frames[m._mill_horse.frame] = true
		await physics_frame
	check(frames.size() >= 3, "its walk frames play (%d seen)" % frames.size())
	# the far half: behind the post and stone, the sweep in front; the near half: in front
	m._mill_a = PI * 1.5
	m._place_mill_horse(true)
	var hi: int = m._mill_horse.get_index()
	check(m._mill_stone.visible and hi < m._mill_stone.get_index() and m._mill_stone.get_index() < m._mill_arm.get_index(),
		"far half: the millstone over the horse, the sweep over both")
	m._mill_a = PI * 0.5
	m._place_mill_horse(true)
	check(not m._mill_stone.visible and m._mill_arm.get_index() < m._mill_horse.get_index(), "near half: the horse over the sweep")
	check(m._mill_arm.get_point_position(0) == Vector2(Building.MILL_ART["states"]["built"]["post"]), "the sweep starts at the post")
	u.cmd_stop()
	await wait(0.6)
	check(m.working_crew() == 0, "the Labourer leaves")
	await wait(2.0)
	var a2: float = m._mill_a
	await wait(0.5)
	check(m._mill_v == 0.0 and m._mill_a == a2 and m._mill_horse.frame == 0, "nobody working it: the horse halts")
	m.hp = m.max_hp * 0.3
	m._update_sprite()
	check(m._mill_state == "damaged" and m._mill_horse.visible, "damaged: the horse still there")
	m.die()
	check(m._mill_state == "" and not m._mill_horse.visible, "destroyed: no horse")


func _farm() -> void:
	var f: Building = g._add_building("farm", 0, origin + Vector2i(2, 7), true)
	await wait(2.5)
	var fr: int = f.sails.frame
	await wait(1.5)
	check(f._sail_v == 0.0 and f.sails.frame == fr, "nobody in the fields: the sails stand still")
	var u := await _labourer(f)
	check(await wait_for(func() -> bool: return f.working_crew() > 0, 25.0), "a Labourer works the farm")
	await wait(2.0)
	var seen := {}
	for i in 60:
		seen[f.sails.frame] = true
		await physics_frame
	check(f._sail_v == 1.0 and seen.size() >= 3, "worked: the sails turn (%d frames in 2 s)" % seen.size())
	u.cmd_stop()
	await wait(0.6)
	var v_mid: float = f._sail_v
	await wait(2.0)
	check(v_mid > 0.0 and v_mid < 1.0 and f._sail_v == 0.0, "left: the sails slow to a stop (%.2f after 0.6 s)" % v_mid)


func _smoke_near(b: Building) -> int:
	var n := 0
	for c in g.get_children():
		if c is Effect and c.position.distance_to(b.global_position + Vector2(0, -50)) < 90.0:
			n += 1
	return n


func _foundry() -> void:
	var f: Building = g._add_building("foundry", 0, origin + Vector2i(14, 8), true)
	g.camera.position = f.center()
	await wait(3.0)
	check(not f._in_use and _smoke_near(f) == 0, "an idle Foundry: no smoke")
	f.queue.append("balloon")
	f.kits.append({})
	var puffs := 0
	for i in 90:
		puffs = maxi(puffs, _smoke_near(f))
		await physics_frame
	check(f._in_use and puffs > 0, "training: it smokes (%d puffs)" % puffs)
