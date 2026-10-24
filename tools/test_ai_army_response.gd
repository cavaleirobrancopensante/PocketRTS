extends SceneTree
## The computer's defence is sized to the threat: a lone horseman / scout draws a small, leashed
## detachment (or nobody), a decoy never drags more than that, a real army gets most of the army.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_army_response.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _setup(main: Node, ai_faction: String) -> Game:
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": ai_faction, "colour": 1, "side": 1, "strategy": "balanced"}]})
	return main.game


## soldiers of the computer standing at its post, a mix of slow and fast
func _army(g: Game, ai: AI, n_slow: int, n_fast: int) -> Array:
	var hall: Building = g.halls_of(1)[0]
	var front: Vector2 = ai._rally_front(hall)
	var out: Array = []
	var slow := "musketeer" if ai._crown() else "spitter"
	var fast := "dragoon" if ai._crown() else "raptor"
	for i in n_slow:
		out.append(g._add_unit(slow, 1, front + Vector2(randf_range(-50, 50), randf_range(-50, 50))))
	for i in n_fast:
		out.append(g._add_unit(fast, 1, front + Vector2(randf_range(-50, 50), randf_range(-50, 50))))
	return out


func _moved(list: Array, from: Dictionary) -> int:
	var n := 0
	for u in list:
		if is_instance_valid(u) and not u.dead and u.position.distance_to(from[u]) > 90.0:
			n += 1
	return n


func _case(ai_faction: String) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var g := _setup(main, ai_faction)
	await process_frame
	await process_frame
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI
	for a in g.ais:
		if a.team == 1:
			ai = a
	ai.peaceful = true      # (no attack waves of its own: only the defence is under test)
	var hall: Building = g.halls_of(1)[0]
	var army := _army(g, ai, 8, 6)
	for u in g.army(1):
		if not army.has(u):
			army.append(u)
	for i in 60:
		await physics_frame
	var start := {}
	for u in army:
		start[u] = u.position
	var tag := " [%s]" % ai_faction
	# 1) a lone horseman parked in the zone: a small detachment at most
	var raider: Unit = g._add_unit("cuirassier", 0, hall.center() + Vector2(0, 280))
	raider.max_hp = 9000.0
	raider.hp = 9000.0
	var most := 0
	for i in 450:
		await physics_frame
		most = maxi(most, ai._det.size())
	check(most <= AI.LONE_CAP, "lone horseman draws at most %d men (most %d)%s" % [AI.LONE_CAP, most, tag])
	check(_moved(army, start) <= AI.LONE_CAP + 1, "the rest of the army (%d) stays at its post (moved: %d)%s" % [army.size(), _moved(army, start), tag])
	# it gives up after the time limit
	for i in 900:
		await physics_frame
	check(ai._det.size() <= AI.LONE_CAP and game_time_ok(g, ai), "the detachment gave up at the leash (cooldown set; out now: %d)%s" % [ai._det.size(), tag])
	# 2) a decoy: pops in and out of the zone five times, never more than the detachment
	var worst := 0
	for k in 5:
		raider.position = hall.center() + Vector2(0, 280)
		raider.cmd_stop()
		for i in 120:
			await physics_frame
			worst = maxi(worst, ai._det.size())
		raider.position = hall.center() + Vector2(0, 1100)
		for i in 120:
			await physics_frame
			worst = maxi(worst, ai._det.size())
	check(worst <= AI.LONE_CAP, "a decoy never pulls more than the detachment (%d)%s" % [worst, tag])
	check(_moved(army, start) <= AI.LONE_CAP + 2, "after the decoy the army is still home (moved: %d)%s" % [_moved(army, start), tag])
	raider.dead = true
	raider.hp = 0.0
	# 3) a real army arrives: most of ours goes
	for i in 150:
		await physics_frame
	var foes: Array = []
	var spot := hall.center() + Vector2(0, 280)
	for i in 10:
		var f: Unit = g._add_unit("musketeer", 0, spot + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		f.max_hp = 600.0
		f.hp = 600.0
		foes.append(f)
	var sent := 0
	for i in 150:
		await physics_frame
		var near := 0
		for u in army:
			if is_instance_valid(u) and not u.dead and (ai._det.has(u) or u.position.distance_to(spot) < 450.0):
				near += 1
		sent = maxi(sent, near)
	check(sent >= int(army.size() * 0.6), "a real army (10 musketeers) gets most of ours (%d of %d)%s" % [sent, army.size(), tag])
	main.queue_free()
	await process_frame


func game_time_ok(_g: Game, ai: AI) -> bool:
	return ai._lone_cool > 0.0


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	if only.is_empty() or only[0] == "crown":
		await _case("crown")
	if only.is_empty() or only[0] == "brood":
		await _case("brood")
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit()
