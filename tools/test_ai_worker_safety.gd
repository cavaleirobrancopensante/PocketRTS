extends SceneTree
## Worker safety: raiders hit the computer's economy while its army is small or away. A good
## player keeps mining away from the raid, pulls workers out of reach of what they cannot beat,
## fights only when the hands clearly outnumber a weak raider, calls the army home in proportion,
## and puts everybody back to work afterwards.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_worker_safety.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _start() -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI
	for a in g.ais:
		if a.team == 1:
			ai = a
	ai.peaceful = true
	return [main, g, ai]


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## the economy the raid hits: the farm with the biggest crew
func _farm(g: Game) -> Building:
	var best: Building = null
	for b in g.buildings:
		if b.team == 1 and b.kind == "farm" and b.built and not b.dead:
			if best == null or b.crew.size() > best.crew.size():
				best = b
	return best


func _idle_with_work(g: Game) -> int:
	var n := 0
	for u in g.workers(1):
		if u.order == "idle" and u.can_gather() and g.free_site(1, u.position) != null:
			n += 1
	return n


func _clear_army(g: Game) -> void:
	for u in g.army(1):
		u.die()


func _raid(g: Game, kind: String, n: int, farm: Building, hp := 0.0) -> Array:
	var out: Array = []
	for i in n:
		var u: Unit = g._add_unit(kind, 0, farm.center() + Vector2(260 + 14 * i, 60))
		if hp > 0.0:
			u.max_hp = hp
			u.hp = hp
		u.cmd_move(farm.center(), true)
		out.append(u)
	return out


func _alive(list: Array) -> int:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()


func game_order(u) -> String:
	return str(u.order_point)


func _case_small() -> void:
	var r := await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _wait(2700)
	_clear_army(g)
	var farm := _farm(g)
	var w0 := g.workers(1).size()
	print("  [small raid] workers before: %d, farm crew %d" % [w0, farm.crew.size() if farm else -1])
	check(farm != null and w0 >= 6, "the computer has a working economy after 90 s (%d workers)" % w0)
	if farm == null:
		main.queue_free()
		return
	var raiders := _raid(g, "raptor", 2, farm)
	var low := w0
	var stuck_fled := 0
	for i in 20:
		await _wait(60)
		low = mini(low, g.workers(1).size())
	check(low >= w0 - 2, "two raptors do not cut the workers down (%d -> lowest %d)" % [w0, low])
	check(_alive(raiders) == 0, "the hands that outnumber two raptors kill them (%d left)" % _alive(raiders))
	await _wait(600)
	var idle := _idle_with_work(g)
	check(idle == 0, "nobody idles with a free post after the raid (%d)" % idle)
	check(ai._fled.size() == 0, "nobody stays in the fled state (%d)" % ai._fled.size())
	main.queue_free()
	await process_frame


func _case_strong() -> void:
	var r := await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _wait(2700)
	_clear_army(g)
	var farm := _farm(g)
	var w0 := g.workers(1).size()
	var raiders := _raid(g, "brute", 2, farm)
	var low := w0
	var fought := 0
	var last := {}
	for i in 20 * 45:
		await physics_frame
		if OS.get_environment("AI_DBG") != "":
			for u in g.workers(1):
				last[u] = [u.position, u.order, game_order(u)]
			for u in last.keys():
				if not is_instance_valid(u) or u.dead:
					var bp = raiders.map(func(r): return r.position if is_instance_valid(r) else Vector2.ZERO)
					print("   DIED f=%d at %s order %s; brutes %s farm %s" % [i, str(last[u][0]), last[u][1], str(bp), str(farm.center())])
					last.erase(u)
		if i % 45 != 44:
			continue
		low = mini(low, g.workers(1).size())
		if OS.get_environment("AI_DBG") != "":
			var md := 9999.0
			for u in raiders:
				if is_instance_valid(u) and not u.dead:
					md = minf(md, u.position.distance_to(farm.center()))
			print("   t=%d workers %d fled %d fighters %d brutes@farm %.0f hp %s" % [i, g.workers(1).size(), ai._fled.size(), ai._fighters.size(), md, str(raiders.map(func(u): return int(u.hp)))])
		fought = maxi(fought, g.workers(1).filter(func(u: Unit) -> bool: return u.order == "attack").size())
	print("  [strong raid] workers %d -> lowest %d, most attacking at once %d" % [w0, low, fought])
	check(low >= int(w0 * 0.6), "two brutes (unbeatable for the hands) do not kill the workers off (%d -> lowest %d)" % [w0, low])
	check(low > 0, "the computer never loses all its workers")
	# the raid is over: the workers are all back to work
	for u in raiders:
		if is_instance_valid(u) and not u.dead:
			u.die()
	await _wait(900)
	var w1 := g.workers(1)
	var working := w1.filter(func(u: Unit) -> bool: return u.order in ["gather", "build", "repair"]).size()
	check(ai._fled.size() == 0, "nobody stays in the fled state after the raid (%d)" % ai._fled.size())
	check(working >= int(w1.size() * 0.8), "the workers are back at work (%d of %d)" % [working, w1.size()])
	var far := 0
	for u in w1:
		if ai._home_dist(u.position) > 400.0:
			far += 1
	check(far == 0, "no worker stranded far from home (%d)" % far)
	main.queue_free()
	await process_frame


func _case_army_away() -> void:
	var r := await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var ai: AI = r[2]
	await _wait(2700)
	_clear_army(g)
	var farm := _farm(g)
	var hall: Building = g.halls_of(1)[0]
	var out_at := hall.center() + Vector2(0, -900)
	var army: Array = []
	for i in 8:
		var u: Unit = g._add_unit("musketeer", 1, out_at + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		army.append(u)
	ai._attacking = true
	ai._wave_target = out_at + Vector2(0, -400)
	var w0 := g.workers(1).size()
	var raiders := _raid(g, "raptor", 6, farm)
	var home := 0
	var low := w0
	for i in 20:
		await _wait(45)
		low = mini(low, g.workers(1).size())
	for u in army:
		if is_instance_valid(u) and not u.dead and u.position.distance_to(out_at) > 500.0:
			home += 1
	print("  [army away] workers %d -> lowest %d, army back %d of 8, raiders left %d" % [w0, low, home, _alive(raiders)])
	check(home >= 3, "a big raid calls part of the army home (%d of 8 left their post)" % home)
	check(low > 0 and low >= w0 / 2, "six raptors do not wipe the economy out (%d -> %d)" % [w0, low])
	main.queue_free()
	await process_frame


func _run() -> void:
	await _case_small()
	await _case_strong()
	await _case_army_away()
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit()
