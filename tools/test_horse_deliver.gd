extends SceneTree
## A Town Hall hauler leads a Horse Breeder's horse to the Barracks recruit across a wall with a
## gate: through a crowd, and with the gate locked (the stuck-recovery fallback).
##   godot --headless --fixed-fps 30 --script res://tools/test_horse_deliver.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
var hall: Building
var bar: Building
var br: Building
var gate: Building


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


func _clear_horses() -> void:
	for h in g.horses_of(0).duplicate():
		g.consume_unit(h)
	for b in [br, bar]:
		b.queue.clear()
		b.kits.clear()
		b.prod_t = 0.0
	for u in g.units.duplicate():
		if u.team == 0 and (u.kind == "cuirassier" or u.kind == "musketeer"):
			g.consume_unit(u)
	await physics_frame


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
	g._add_building("cottage", 0, origin + Vector2i(23, 17), true)
	hall = g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)
	br = g._add_building("horse_breeder", 0, origin + Vector2i(9, 1), true)
	bar = g._add_building("barracks", 0, origin + Vector2i(19, 1), true)
	for y in 20:
		if y == 5:
			gate = g._add_building("gate", 0, origin + Vector2i(15, y), true)
		else:
			g._add_building("wall", 0, origin + Vector2i(15, y), true)
	for b in g.buildings:
		if b.team == 0:
			b.supply()
	bar.rally = at(700, 330)
	g._astar_dirty = true
	await physics_frame
	await physics_frame
	for i in 2:
		var w: Unit = g._add_unit("labourer", 0, at(150 + i * 40, 260))
		w.auto_work = false
		g.smart_command([w], hall.center())
	await wait(1.0)
	check(hall.haulers().size() == 2, "two haulers")
	await _deliver("through the gate", 0)
	await _deliver("through a crowd at the gate", 12)
	gate_locked = true
	await _deliver("with the gate locked (fallback)", 0, true)
	print("horse deliver: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)


var gate_locked := false


func _deliver(what: String, crowd: int, lock := false) -> void:
	await _clear_horses()
	if lock:
		check(g.set_gate_locked(gate, true) == "", "gate locked")
	else:
		gate.locked = false
	var crowd_us: Array = []
	for i in crowd:
		var u: Unit = g._add_unit("musketeer", 0, g.cell_center(origin + Vector2i(13 + (i % 2) * 4, 3 + i / 2)))
		u.cmd_hold()
		crowd_us.append(u)
	await physics_frame
	var t0: float = g.clock
	check(g.train(bar, "horseman") == "", "%s: HORSEMAN queued" % what)
	var rid := int(bar.kit_at(bar.queue.size() - 1).get("rid", 0))
	var ok: bool = await wait_for(func() -> bool: return g.units.any(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead), 100.0)
	check(ok and g.clock - t0 < 40.0, "%s: the Horseman rode out (%.0f s after queueing)" % [what, g.clock - t0])
	var stuck := 0
	for u in hall.haulers():
		if not u.haul_job.is_empty():
			stuck += 1
	await wait_for(func() -> bool: return hall.haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), 40.0)
	check(hall.haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), "%s: haulers back home (free %d/%d)" % [what, hall.haulers_free(), hall.haulers().size()])
	for u in crowd_us:
		if is_instance_valid(u):
			g.consume_unit(u)
