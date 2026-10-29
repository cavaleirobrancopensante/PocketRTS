extends SceneTree
## POWDER KEGS (the owner, 2026-10-29 08:05 and 08:06): haulers wait by a full wagon, kegs never go back into the stores.
##   godot --headless --fixed-fps 30 --script res://tools/test_kegs.gd
##  1. a hauler reaches a full wagon, waits by it keg in hand, follows it as it moves, and unloads when room appears;
##  2. a full wagon nobody draws from pulls no kegs;
##  3. the wagon is destroyed mid-delivery: the keg lies on the ground (PowderKeg) with its powder;
##  4. a Musketeer refills from it;
##  5. a free hauler picks a dropped keg up and delivers it (before fetching a new one);
##  6. an enemy shoots a keg by itself and it blows up (its neighbour is hurt);
##  7. a save and a reload keep the kegs on the ground.
## Prints PASS / FAIL lines and "kegs: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
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


## Keep a wagon's powder use up (as if a line of Musketeers drew from it): the hauler need reads it.
func _busy(w: Unit, shots := 120.0) -> void:
	WorkerLabels._st(g)["use"][w.get_instance_id()] = [[g.clock - 25.0, w.powder_out - shots]]


func _kegs_near(p: Vector2, r: float) -> Array:
	return g.kegs.filter(func(k: PowderKeg) -> bool: return not k.dead and k.position.distance_to(p) < r)


func _run() -> void:
	var me := 0
	var hall: Building = g._own_hall(me)
	var mill: Building = null
	var c: Vector2i = g.find_spot(me, "powder_mill", hall, 3, 14)
	mill = g._add_building("powder_mill", me, c, true)
	g.players[me]["res2"] = 3000.0
	var toward: Vector2 = (Vector2(Game.W, Game.H) * Game.T * 0.5 - mill.center()).normalized()
	# one hauler
	var hauler: Unit = g._add_unit("labourer", me, hall.center() + Vector2(0, 80))
	hauler.cmd_gather(hall)
	await wait(0.5)
	check(hauler.is_hauler(), "a Labourer assigned to the Town Hall is a hauler")

	# --- 1. a full wagon under use: he comes with a keg, waits by it, follows it, unloads when there is room
	var w: Unit = g._add_unit("powder_wagon", me, mill.center() + toward * 10.0 * Game.T)
	w.supplying = true
	w.powder = float(Defs.WAGON["store"])
	_busy(w)
	var waited := await wait_for(func() -> bool: _busy(w); return String(hauler.haul_job.get("ph", "")) == "wait_room", 60.0)
	check(waited and hauler.keg, "a hauler reaches the full wagon and waits by it, keg in hand (%s)" % hauler.haul_job.get("ph", "none"))
	check(hauler.hauler_text().contains("waiting by the wagon for room"), "  his card says so: %s" % hauler.hauler_text())
	var before: Vector2 = hauler.position
	w.position += toward * 4.0 * Game.T            # (the wagon drives off)
	await wait(3.0)
	_busy(w)
	check(hauler.position.distance_to(w.position) < 60.0 and hauler.position.distance_to(before) > 40.0 and hauler.keg,
		"  he follows the wagon as it moves, keg in hand (%.0f px from it, moved %.0f)" % [hauler.position.distance_to(w.position), hauler.position.distance_to(before)])
	w.powder = float(Defs.WAGON["store"]) - 50.0   # (the soldiers drew from it: room for a keg)
	var p0: float = w.powder
	var gave := await wait_for(func() -> bool: return not hauler.keg, 5.0)
	check(gave and w.powder >= p0 + float(Defs.WAGON["keg"]) - 0.1, "  and unloads as soon as there is room (%.0f -> %.0f)" % [p0, w.powder])

	# --- 2. a full wagon nobody draws from pulls no kegs
	w.powder = float(Defs.WAGON["store"])
	WorkerLabels._st(g)["use"][w.get_instance_id()] = [[g.clock - 25.0, w.powder_out]]
	await wait_for(func() -> bool: return hauler.haul_job.is_empty(), 20.0)      # (he walks home first)
	var pulled := false
	var end: float = g.clock + 8.0
	while g.clock < end:
		if hauler.haul_job.get("wagon") == w:
			pulled = true
		await physics_frame
	check(not pulled, "a full wagon nobody draws from pulls no keg (8 s watched)")
	w.supplying = false

	# --- 3. the wagon is destroyed mid-delivery: the keg lies where he stood
	var w2: Unit = g._add_unit("powder_wagon", me, mill.center() + toward * 30.0 * Game.T)
	w2.supplying = true
	w2.powder = 0.0
	_busy(w2)
	var going := await wait_for(func() -> bool: _busy(w2); return hauler.keg and hauler.haul_job.get("wagon") == w2 and hauler.position.distance_to(mill.center()) > 8.0 * Game.T, 60.0)
	check(going, "a hauler on his way to a far wagon with a keg")
	var at: Vector2 = hauler.position
	var n0: int = g.kegs.size()
	w2.die()
	await wait(0.5)
	var lying := _kegs_near(at, 60.0)
	check(not hauler.keg and g.kegs.size() == n0 + 1 and lying.size() == 1 and absf(lying[0].powder - float(Defs.WAGON["keg"])) < 0.1,
		"the wagon blown up mid-delivery: the keg lies on the ground with its %d shots (%d kegs there)" % [int(lying[0].powder) if not lying.is_empty() else -1, lying.size()])
	var keg: PowderKeg = lying[0] if not lying.is_empty() else null

	# --- 4. a Musketeer refills from it
	if keg:
		var m: Unit = g._add_unit("musketeer", me, keg.position + Vector2(20, 0))
		m.powder = 0.0
		var k0: float = keg.powder
		await wait(3.0)
		check(m.powder > 1.0 and keg.powder < k0 - 1.0, "a Musketeer by the keg refills from it (%.0f shots; the keg %.0f -> %.0f)" % [m.powder, k0, keg.powder])
		m.queue_free()
		g.units.erase(m)

	# --- 5. a free hauler picks it up and delivers it, before fetching a new one
	if keg and is_instance_valid(keg) and not keg.dead:
		var left: float = keg.powder
		var w3: Unit = g._add_unit("powder_wagon", me, keg.position + toward * 3.0 * Game.T)
		w3.supplying = true
		w3.powder = 0.0
		_busy(w3)
		var picked := await wait_for(func() -> bool: _busy(w3); return String(hauler.haul_job.get("ph", "")) == "to_pick", 10.0)
		check(picked, "a free hauler goes for the dropped keg first (%s)" % hauler.haul_job.get("ph", "none"))
		var done := await wait_for(func() -> bool: _busy(w3); return w3.powder > 1.0, 60.0)
		check(done and (not is_instance_valid(keg) or keg.dead) and absf(w3.powder - left) < 1.5, "  and delivers it: the wagon gets its %.0f shots (%.0f)" % [left, w3.powder])
		w3.supplying = false

	# --- 6. an enemy shoots a lone keg (nothing else near) and it blows up; its neighbour is hurt
	var spot: Vector2 = mill.center() + toward * 18.0 * Game.T
	var k2: PowderKeg = g.drop_keg(me, spot, float(Defs.WAGON["keg"]))
	var dummy: Unit = g._add_unit("labourer", me, spot + Vector2(22, 6))

	var foe: Unit = g._add_unit("musketeer", 1, spot + toward * 4.5 * Game.T)
	foe.powder = 40.0
	var hp0: float = dummy.hp
	var kref: WeakRef = weakref(k2)
	var blown := await wait_for(func() -> bool: return kref.get_ref() == null or (kref.get_ref() as PowderKeg).dead, 30.0)
	check(blown, "an enemy Musketeer shoots the keg by itself (it was the target: %s)" % ("keg" if blown else str(foe.target)))
	check(dummy.dead or dummy.hp < hp0, "  and it blows up: the Labourer beside it is hurt (%.0f -> %.0f)" % [hp0, dummy.hp if not dummy.dead else 0.0])
	foe.queue_free()
	g.units.erase(foe)

	# --- 7. a save and a reload keep the kegs
	var k3: PowderKeg = g.drop_keg(me, spot + Vector2(0, 120), 17.0)
	k3.hp = 21.0
	var want: int = g.kegs.filter(func(k: PowderKeg) -> bool: return not k.dead).size()
	SaveGame.save(g, {"map": "greenhold", "seed": 5})
	var sd: Dictionary = SaveGame.peek()
	SaveGame.restore(g, sd)
	await wait(0.3)
	var back: Array = g.kegs.filter(func(k: PowderKeg) -> bool: return not k.dead and k.position.distance_to(spot + Vector2(0, 120)) < 20.0)
	check(g.kegs.size() == want and back.size() == 1 and absf(back[0].powder - 17.0) < 0.1 and absf(back[0].hp - 21.0) < 0.1,
		"a save and a reload keep the kegs (%d of %d; the one checked: %s)" % [g.kegs.size(), want, ("%.0f shots, %.0f hp" % [back[0].powder, back[0].hp]) if not back.is_empty() else "missing"])
	SaveGame.clear()
	print("kegs: %d failures" % fails)
	quit(1 if fails > 0 else 0)
