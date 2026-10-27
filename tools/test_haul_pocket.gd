extends SceneTree
## A Town Hall hauler leads a Breeder's horse to the Barracks recruit when the side of the Barracks
## nearest the Breeder is a pocket shut in by a palisade (its edge cells can't be walked to):
## he goes round to a side he can reach instead of walking into the palisade until the
## stuck-recovery fallback, and the horse is hitched on open ground.
##   godot --headless --fixed-fps 30 --script res://tools/test_haul_pocket.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
var hall: Building
var bar: Building
var br: Building


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


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


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
	origin = _open_area(28, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["cap"] = 200
	for u in g.units.duplicate():
		if u.position.distance_to(at(500, 300)) < 1100.0:
			g.consume_unit(u)
	await physics_frame
	hall = g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)
	br = g._add_building("horse_breeder", 0, origin + Vector2i(9, 1), true)
	bar = g._add_building("barracks", 0, origin + Vector2i(19, 1), true)
	# a palisade shuts in the Barracks' west side (the side facing the Breeder): a pocket 3 cells
	# long between it and the Barracks; its ends wrap round the corners, so the nearest ground he
	# can reach to the pocket is outside the palisade, out of reach of the Barracks
	for y in range(0, 5):
		g._add_building("wall", 0, origin + Vector2i(17, y), true)
	g._add_building("wall", 0, origin + Vector2i(18, 0), true)
	g._add_building("wall", 0, origin + Vector2i(19, 0), true)
	g._add_building("wall", 0, origin + Vector2i(19, 4), true)
	g._add_building("wall", 0, origin + Vector2i(18, 4), true)
	for b in g.buildings:
		if b.team == 0:
			b.supply()
	bar.rally = at(700, 330)
	g._astar_dirty = true
	await physics_frame
	await physics_frame
	var pocket_c: Vector2i = origin + Vector2i(18, 2)
	check(not g.in_open_map(pocket_c), "the Barracks' west side is a shut-in pocket")
	var w: Unit = g._add_unit("labourer", 0, at(150, 200))
	w.auto_work = false
	g.smart_command([w], hall.center())
	await physics_frame
	check(hall.haulers().size() == 1, "a hauler")
	var t0: float = g.clock
	check(g.train(bar, "horseman") == "", "HORSEMAN queued")
	var rid := int(bar.kit_at(bar.queue.size() - 1).get("rid", 0))
	await wait_for(func() -> bool: return g.reserved_horse(0, rid) != null and g.reserved_horse(0, rid).leader == w, 40.0)
	var horse: Unit = g.reserved_horse(0, rid)
	check(horse != null and horse.leader == w, "the hauler has the horse on his leash")
	if horse == null:
		quit(1)
		return
	var t_lead: float = g.clock
	var max_still := 0.0
	var still := 0.0
	var last: Vector2 = w.position
	while g.clock < t_lead + 60.0 and horse.leader == w:
		await physics_frame
		if w.position.distance_to(last) < 0.5:
			still += 1.0 / 30.0
		else:
			still = 0.0
		max_still = maxf(max_still, still)
		last = w.position
	var took: float = g.clock - t_lead
	check(horse.leader != w, "he lets the horse go at the Barracks (%.1f s after taking it)" % took)
	check(took < 7.0 and max_still < 1.0, "without standing stuck against the palisade (longest standstill %.1f s; the fallback comes at 16 s)" % max_still)
	await wait_for(func() -> bool: return not is_instance_valid(horse) or horse.dead or horse.get("hitch_p") == null or horse.hitch_p != Vector2.INF, 10.0)
	if is_instance_valid(horse) and not horse.dead and horse.get("hitch_p") != null:
		await wait_for(func() -> bool: return not is_instance_valid(horse) or horse.position.distance_to(horse.hitch_p) < 4.0, 25.0)
		if is_instance_valid(horse) and not horse.dead:
			check(g.in_open_map(g.cell_of(horse.position)), "the horse is hitched on open ground, not in the pocket (%s)" % g.cell_of(horse.position))
	var rider_ok: bool = await wait_for(func() -> bool: return g.units.any(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead), 60.0)
	check(rider_ok, "the Horseman rides out (%.0f s after queueing)" % (g.clock - t0))
	for u in g.units:
		if u.team == 0 and u.kind == "cuirassier" and not u.dead:
			check(g.in_open_map(g.cell_of(u.position)), "and he is out on open ground (%s)" % g.cell_of(u.position))
	print("haul pocket: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
