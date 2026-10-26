extends SceneTree
## No horse vanishes: a horse bought for a recruit walks to the building and stands HITCHED beside
## it (visible, untouchable, its own spot) until the rider is trained and mounts it; cancelling frees it.
##   godot --headless --fixed-fps 30 --script res://tools/test_horse_vanish.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
var hall: Building
var bar: Building
var gate: Building


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4243, "slots": [
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


func _horse(p: Vector2) -> Unit:
	var h: Unit = g._add_unit("horse", 0, p)
	h.graze_at = h.position
	return h


func _run() -> void:
	origin = _open_area(26, 20)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["cap"] = 200
	for u in g.units.duplicate():
		if u.position.distance_to(at(500, 400)) < 1100.0:
			g.consume_unit(u)
	await physics_frame
	g.players[0]["tech"] = {}
	var brd: Building = g._add_building("horse_breeder", 0, origin + Vector2i(2, 2), true)
	bar = g._add_building("barracks", 0, origin + Vector2i(12, 2), true)
	await physics_frame
	# 1. a horse standing at the Barracks is taken for a Horseman: it walks over and is hitched
	var h1 := _horse(g.approach_point(bar, bar.center() + Vector2(0, 200)))
	await physics_frame
	var coat: String = h1.coat
	check(g.train(bar, "horseman") == "", "a Horseman is trained with the horse at the Barracks")
	await wait(15.0)
	check(is_instance_valid(h1) and not h1.dead, "the horse is still there after it reached the Barracks")
	check(h1.hitch_p != Vector2.INF and h1.into == bar, "it stands hitched at a spot beside the Barracks")
	check(h1.untouchable(), "a hitched horse is untouchable")
	check(g.horses_of(0).has(h1) and bar.edge_distance(h1.position) < 60.0, "and it is visible beside the building")
	check(g.free_horse_at(bar) == null and g.spare_horse(0, bar) == null, "nobody else can take or reserve it")
	# 2. cancelling frees it, a Crown horse on the spot
	g.cancel_train(bar)
	await wait(1.0)
	check(is_instance_valid(h1) and h1.into == null and h1.hitch_p == Vector2.INF and h1.team == 0 and not h1.untouchable(), "cancelled: the hitched horse is free again, still ours")
	check(g.horses_of(0).filter(func(h: Unit) -> bool: return h.coat == coat).size() == 1, "and no second horse appeared")
	# 3. it comes out: the rider mounts in its place, on its coat
	g.train(bar, "horseman")
	await wait(6.0)
	check(is_instance_valid(h1) and h1.hitch_p != Vector2.INF, "hitched again for the next Horseman")
	var hp: Vector2 = h1.position
	var riders0: int = g.units.filter(func(u: Unit) -> bool: return u.kind == "cuirassier" and u.team == 0).size()
	await wait_for(func() -> bool: return g.units.filter(func(u: Unit) -> bool: return u.kind == "cuirassier" and u.team == 0).size() > riders0, 40.0)
	var rider: Unit = null
	for u in g.units:
		if u.kind == "cuirassier" and u.team == 0:
			rider = u
	check(rider != null and rider.coat == coat and rider.position.distance_to(hp) < 80.0, "the Horseman came out on that horse's coat, by the hitch")
	check(not is_instance_valid(h1) or h1.dead, "and the hitched horse was used (exactly one rider for one horse)")
	await _clear_all()
	# 4. many queued: separate hitch spots
	var hs: Array = []
	for i in 4:
		hs.append(_horse(g.approach_point(bar, bar.center() + Vector2(0, 200)) + Vector2(-45 + i * 30, 0)))
	await physics_frame
	g.players[0]["cap"] = 400
	for i in 4:
		g.train(bar, "horseman")
	bar.prod_t = -1000.0      # (nobody comes out: they all wait hitched)
	await wait(15.0)
	var spots: Array = []
	for h in hs:
		if is_instance_valid(h) and h.hitch_p != Vector2.INF:
			spots.append(h.hitch_p)
	check(spots.size() >= 3, "queued horses wait hitched (%d)" % spots.size())
	var apart := true
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			if (spots[i] as Vector2).distance_to(spots[j]) < 24.0:
				apart = false
	check(apart, "each hitched horse has its own spot")
	await _clear_all()
	# 5. a horse that cannot get there for 90 s is hitched where it can, never deleted
	var far := _horse(bar.center() + Vector2(0, 420))
	far.walk_into(bar)
	bar.add_entry("cuirassier", {"coat": far.coat, "hid": far.get_instance_id()})
	far._into_t = 95.0
	bar.prod_t = -1000.0
	await wait(30.0)
	check(is_instance_valid(far) and not far.dead and far.hitch_p != Vector2.INF and bar.edge_distance(far.position) < 80.0, "a delayed horse is brought to the hitch, not deleted")
	await _clear_all()
	print("FAILED: %d" % fails if fails > 0 else "ALL PASSED")
	quit(1 if fails > 0 else 0)


func _clear_all() -> void:
	for h in g.horses_of(0).duplicate():
		g.consume_unit(h)
	for b in [bar]:
		if b != null:
			b.queue.clear()
			b.kits.clear()
			b.prod_t = 0.0
	for u in g.units.duplicate():
		if u.team == 0 and (u.kind == "cuirassier" or u.kind == "musketeer"):
			g.consume_unit(u)
	await physics_frame
