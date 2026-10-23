extends SceneTree
## The computer's scouting (scripts/ai_scout.gd), end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_scout.gd [-- map:<id>]
## A Hard Crown computer (team 0) against a second player whose own AI is switched off (its
## workers only gather), on a fixed map and seed. The enemy's base is dressed for each case:
##  1. a non-rush computer sends a worker to scout at the start
##  2. a rush enemy (barracks, Horse Breeder, a dozen Musketeers) is detected: a defensive
##     plan (army and walls first, no early expansion, no early attack)
##  3. a greedy enemy (a second hall up, no military) makes it choose a timing attack, sized
##     and timed from what it saw
##  4. an enemy walled in (the scout is denied): the computer plays safe (not greedy, walls
##     or an army), and sends a second scout later
##  5. the rush plan itself still opens at once, with no scout
## Prints PASS / FAIL per check and "ALL PASS" at the end (exit 1 on a failure).
var main: Node
var g: Game
var ai: AI
var foe_hall: Building
var fails := 0
var map := "greenhold"
var _t := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _start(strategy: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4242)
	main.start({"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": strategy},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	foe_hall = g.halls_of(1)[0]


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _until(clock: float, cond := Callable()) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		if cond.is_valid() and cond.call():
			return


func _spot(kind: String, lo := 4, hi := 16) -> Vector2i:
	return g.find_spot(1, kind, foe_hall, lo, hi, "near", true)


func _add(kind: String, lo := 4, hi := 16) -> void:
	var sp := _spot(kind, lo, hi)
	if sp.x >= 0:
		g._add_building(kind, 1, sp, true)


func _log_has(text: String) -> bool:
	for l in ai.scout.log_lines:
		if String(l).contains(text):
			return true
	return false


func _run() -> void:
	# 1 + 5 first: the opening
	await _start("balanced")
	await _until(40.0)
	check(ai.scout.enabled, "a balanced Hard computer scouts")
	check(ai.scout.state == "going" and ai.scout.unit != null, "its scout is on the road by 0:40 (state %s)" % ai.scout.state)
	check(_log_has("sends a Labourer to scout"), "the scout's departure is in the match log")
	check(ai.scout.verdict == "pending", "no decision before the scout has seen anything")
	await _stop()

	await _start("rush")
	await _until(60.0)
	check(not ai.scout.enabled and ai.scout.unit == null and ai.scout.state == "wait", "the rush plan does not scout")
	var opened := ai._mine("horse_breeder").size() + ai._mine("barracks").size() + ai._mine("farm").size()
	check(opened > 0 and ai._mine("horse_breeder").size() + ai._mine("barracks").size() > 0 or ai._rushing(), "the rush plan opens at once (buildings: %d)" % opened)
	await _stop()

	# 2: a rush enemy
	await _start("balanced")
	_add("barracks")
	_add("horse_breeder")
	_add("barracks")
	var at := foe_hall.center()
	for i in 12:
		g._add_unit("musketeer", 1, at + Vector2(60 + (i % 4) * 30, 90 + (i / 4) * 30))
	await _until(240.0, func() -> bool: return ai.scout.verdict != "pending")
	print("   verdict at %d s: %s (%s)" % [int(g.clock), ai.scout.verdict, ai.scout.reason])
	check(ai.scout.verdict == "rush", "a rush enemy is detected")
	check(float(ai._s("expand")) >= 2.0 and int(ai._s("halls")) <= 2, "the answer is defensive: no early expansion (expand x%s)" % ai._s("expand"))
	check(ai._attack_at >= 16 and ai._regroup_until > g.clock, "it holds at home first (attack at %d supply, regroup until %d)" % [ai._attack_at, int(ai._regroup_until)])
	check(ai.strategy == "balanced", "it keeps its own plan underneath")
	check(_log_has("defensive"), "the decision is in the match log")
	g.players[0]["gold"] += 800
	await _until(g.clock + 70.0)
	check(ai._walled or ai._mine("barracks").size() >= 2, "walls or a second Barracks go up (walled %s, Barracks %d)" % [ai._walled, ai._mine("barracks").size()])
	await _stop()

	# 3: a greedy enemy
	await _start("balanced")
	g._add_building("town_hall", 1, g.expansions[1], true)
	_add("farm")
	await _until(240.0, func() -> bool: return ai.scout.verdict != "pending")
	print("   verdict at %d s: %s (%s)" % [int(g.clock), ai.scout.verdict, ai.scout.reason])
	check(ai.scout.verdict == "greedy", "a greedy enemy is detected")
	check(ai.strategy == "timing", "it chooses the timing attack (strategy %s)" % ai.strategy)
	var tm := float(ai._s("timing")) if ai._s("timing") != null else 0.0
	check(tm >= g.clock and tm < 400.0, "the timing is earlier than the default 6:40, from what it saw (%d:%02d)" % [int(tm) / 60, int(tm) % 60])
	check(ai.scout.timing_target >= 14 and ai.scout.timing_target <= 40, "the force is sized from what was seen (%d supply)" % ai.scout.timing_target)
	check(ai._attack_at >= 999, "nothing goes out before the timing")
	check(_log_has("timing attack"), "the decision is in the match log")
	await _stop()

	# 4: a walled-in enemy: the scout is denied
	await _start("economy")
	_wall_in()
	await _until(260.0, func() -> bool: return ai.scout.verdict != "pending")
	print("   verdict at %d s: %s (%s)" % [int(g.clock), ai.scout.verdict, ai.scout.reason])
	check(ai.scout.verdict == "uncertain", "a denied scout is uncertainty, not a rush or a greedy enemy (verdict %s)" % ai.scout.verdict)
	check(ai.strategy == "economy" and float(ai._s("expand")) >= 1.3 and ai.scout.mod.get("halls", 9) <= 3, "it plays safe: no greedy expansion (expand x%s, was x0.45)" % ai._s("expand"))
	check(ai.scout.want_wall, "it walls up")
	check(_log_has("playing safe"), "the decision is in the match log")
	await _until(g.clock + 140.0, func() -> bool: return ai.scout.trips >= 2)
	check(ai.scout.trips >= 2, "it scouts again later (trips %d)" % ai.scout.trips)
	await _stop()

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


## Walls on every cell of the enemy's plateau that touches a ramp: nobody gets in.
func _wall_in() -> void:
	var st := Vector2i(Vector2(g.starts[1]) + Vector2(2.5, 2.0))
	var h0 := int(g.height[g.idx(st)])
	var done := {}
	for y in range(st.y - 26, st.y + 27):
		for x in range(st.x - 26, st.x + 27):
			var r := Vector2i(x, y)
			if not g.in_map(r) or g.ramp[g.idx(r)] != 1:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := r + Vector2i(dx, dy)
					if g.in_map(c) and not done.has(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == h0 and g.solid[g.idx(c)] == 0:
						done[c] = true
						g._add_building("wall", 1, c, true)
	print("   %d wall pieces round the enemy's main" % done.size())
