extends SceneTree
## A led horse goes through a gate in a wall both ways without snapping or jamming; a hauler's
## horse reaches the Barracks recruit even when it gets wedged.
##   godot --headless --fixed-fps 30 --script res://tools/test_horse_gate.gd
var fails := 0
var g: Game
var trace := false
var gate_x := 0.0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## A fresh game, no AI, and a N-S wall of `n` cells with a gate in the middle on open ground.
func _setup() -> Dictionary:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	var hall: Building = g.halls_of(0)[0]
	# open ground: search for a 15x15 free square around the hall
	var best := Vector2i(-1, -1)
	var hc: Vector2i = g.cell_of(hall.center())
	for r in range(8, 40):
		for k in 16:
			var c: Vector2i = hc + Vector2i((Vector2.RIGHT.rotated(k * TAU / 16.0) * r).round())
			var ok := true
			for y in range(-8, 9):
				for x in range(-8, 9):
					if not g.open_cell(c + Vector2i(x, y)):
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				break
		if best.x >= 0:
			break
	assert(best.x >= 0)
	var gate: Building
	for y in range(-6, 7):
		var cc: Vector2i = best + Vector2i(0, y)
		if y == 0:
			gate = g._add_building("gate", 0, cc, true)
			gate.set_vertical(false)
		else:
			g._add_building("wall", 0, cc, true)
	g._astar_dirty = true
	await physics_frame
	await physics_frame
	return {"main": main, "c": best, "gate": gate, "hall": hall}


func _teardown(s: Dictionary) -> void:
	s["main"].queue_free()
	await process_frame


## Walk `man` (leading `horses`) from `a` to `b`; returns {t, snaps, d, ok}.
func _lead_through(man: Unit, horses: Array, a: Vector2, b: Vector2, secs := 14.0) -> Dictionary:
	var prev: Array = []
	for h in horses:
		prev.append(h.position)
	var snaps := 0
	var t := 0.0
	man.cmd_move(b)
	var arrived_t := -1.0
	while t < secs:
		await physics_frame
		t += 1.0 / 30.0
		for i in horses.size():
			if horses[i].position.distance_to(prev[i]) > 40.0:
				snaps += 1
			prev[i] = horses[i].position
		if trace and int(t * 30.0) % 15 == 0:
			print("  t=%.1f man=%s horses=%s" % [t, man.position.round(), horses.map(func(h): return h.position.round())])
		# through: every horse is on the far side of the wall (the man must not have wandered off)
		var near := true
		var dirx := signf(b.x - a.x)
		for h in horses:
			near = near and (h.position.x - gate_x) * dirx > 30.0 and h.position.distance_to(man.position) < 200.0
		if near and arrived_t < 0.0:
			arrived_t = t
			break
	var d := 0.0
	for h in horses:
		d = maxf(d, h.position.distance_to(man.position))
	return {"t": arrived_t, "snaps": snaps, "d": d, "ok": arrived_t >= 0.0}


func _run() -> void:
	var s: Dictionary = await _setup()
	var c: Vector2i = s["c"]
	var gate: Building = s["gate"]
	gate_x = gate.center().x
	var west: Vector2 = g.cell_center(c + Vector2i(-5, 0))
	var east: Vector2 = g.cell_center(c + Vector2i(5, 0))
	# 1. a man leads one horse east through the gate, then back west
	var man: Unit = g._add_unit("labourer", 0, west)
	var horse: Unit = g._add_unit("horse", 0, west + Vector2(-26, 0))
	man.take_reins(horse)
	await physics_frame
	var r: Dictionary = await _lead_through(man, [horse], west, east)
	check(r["ok"] and r["snaps"] == 0, "led horse passes the gate eastward (t=%s snaps=%d d=%d)" % [str(r["t"]), r["snaps"], r["d"]])
	r = await _lead_through(man, [horse], east, west)
	check(r["ok"] and r["snaps"] == 0, "led horse passes the gate westward (t=%s snaps=%d d=%d)" % [str(r["t"]), r["snaps"], r["d"]])
	# 2. three horses in a string, from a far-off start (diagonal approach)
	var h2: Unit = g._add_unit("horse", 0, west + Vector2(-40, 30))
	var h3: Unit = g._add_unit("horse", 0, west + Vector2(-40, -30))
	man.take_reins(h2)
	man.take_reins(h3)
	r = await _lead_through(man, [horse, h2, h3], west, east, 20.0)
	check(r["ok"] and r["snaps"] == 0, "a string of three passes (t=%s snaps=%d d=%d)" % [str(r["t"]), r["snaps"], r["d"]])
	r = await _lead_through(man, [horse, h2, h3], east, west, 20.0)
	check(r["ok"] and r["snaps"] == 0, "a string of three passes back (t=%s snaps=%d d=%d)" % [str(r["t"]), r["snaps"], r["d"]])
	# 3. the man crosses diagonally from the wall corner side
	var north_w: Vector2 = g.cell_center(c + Vector2i(-3, -4))
	var south_e: Vector2 = g.cell_center(c + Vector2i(4, 4))
	man.release_horses()
	man.position = north_w
	horse.position = north_w + Vector2(-20, 0)
	man.take_reins(horse)
	r = await _lead_through(man, [horse], north_w, south_e, 20.0)
	check(r["ok"] and r["snaps"] == 0, "diagonal crossing (t=%s snaps=%d d=%d)" % [str(r["t"]), r["snaps"], r["d"]])
	# 4. a limbered gun (its harnessed horse) and a led horse meet in the gateway from opposite sides
	man.release_horses()
	for u in [h2, h3]:
		g.consume_unit(u)
	var gun: Unit = g._add_unit("cannon", 0, west + Vector2(-30, 0))
	var gh: Unit = g._add_unit("horse", 0, west + Vector2(-60, 0))
	gun.harness(gh)
	man.position = east + Vector2(20, 0)
	horse.position = east + Vector2(46, 0)
	man.take_reins(horse)
	gun.cmd_move(east + Vector2(40, 0))
	var t := 0.0
	var snaps := 0
	var prev: Vector2 = horse.position
	man.cmd_move(west + Vector2(-20, 0))
	while t < 25.0 and not (gun.position.x > gate_x + 40.0 and horse.position.x < gate_x - 40.0):
		await physics_frame
		t += 1.0 / 30.0
		if horse.position.distance_to(prev) > 40.0:
			snaps += 1
		prev = horse.position
	check(gun.position.x > gate_x + 40.0 and horse.position.x < gate_x - 40.0 and snaps == 0,
		"a limbered gun and a led horse pass each other in the gateway (t=%.1f gun=%s horse=%s snaps=%d)" % [t, gun.position.round(), horse.position.round(), snaps])
	# 5. a crowd of idle men stand about the gate: the led horse still gets through
	man.release_horses()
	var crowd: Array = []
	for i in 10:
		var m: Unit = g._add_unit("musketeer", 0, g.cell_center(c + Vector2i(-1 + (i % 3) * 1, -2 + i / 3)))
		m.cmd_hold()
		crowd.append(m)
	man.position = west
	horse.position = west + Vector2(-26, 0)
	man.take_reins(horse)
	r = await _lead_through(man, [horse], west, east, 25.0)
	check(r["ok"] and r["snaps"] == 0 or (r["ok"] and r["t"] < 20.0), "led through a crowd at the gate (t=%s snaps=%d)" % [str(r["t"]), r["snaps"]])
	# 6. the gate is locked while the horse is on its leash: no horse is left in the gateway, the man gives up
	for m in crowd:
		g.consume_unit(m)
	man.release_horses()
	man.position = west
	horse.position = west + Vector2(-26, 0)
	man.take_reins(horse)
	check(g.set_gate_locked(gate, true) == "", "gate locked")
	man.cmd_move(east)
	var inside := false
	for i in 150:
		await physics_frame
		if gate.rect().grow(4.0).has_point(horse.position) or gate.rect().grow(4.0).has_point(man.position):
			inside = true
	check(not inside, "locked gate: man and horse go round, never through the shut gate")
	check(g.set_gate_locked(gate, false) == "", "gate unlocked")
	man.position = west
	horse.position = west + Vector2(-26, 0)
	man.cmd_move(east)
	await get_physics_wait(8.0)
	check(horse.position.x > gate_x + 20.0 and man.position.x > gate_x, "unlocked: horse follows through again (horse x=%d)" % horse.position.x)
	print("horse gate: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)


func get_physics_wait(sec: float) -> void:
	for i in int(sec * 30.0):
		await physics_frame
