extends SceneTree
## The computer expands before its land runs out and rebuilds lost halls (0.24.2, branch ai-expand; the owner's game
## 2026-10-30, v0.24.0 Cinder Steps: the Brood took the Hard Crown's second Town Hall at 12:00, the main's soil was spent at
## 13:41 and from then to 23:30 the Crown earned nothing, 36 Labourers idle, 162 gold banked, no new Town Hall).
##  [crown] / [clock]: a Hard Balanced computer plays to 4:00; then every hall but its main is razed and the main is left
##          with LEFT of its soil (Crown) / brass (Clockwork), its bank cut to POOR. Within WITHIN s it must lay a new hall
##          and in the last of 240 s still be earning.
##  [brood] the Brood computer whose Rootmaws' ground is spent roots a new Rootmaw on fresh ground.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_expand.gd
const LEFT := 0.08
const POOR := 150
const WITHIN := 90.0
var fails := 0
var _lastg := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _start(fac: String, other: String) -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(3)
	main.start({"map": "cinder_steps", "seed": 3, "slots": [
		{"who": "hard", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": other, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the other side stands still: the test's prop)
		else:
			a.peaceful = true
	return main


func _case(fac: String) -> void:
	var main: Node = await _start(fac, "brood")
	var g: Game = main.game
	var ai = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	while g.clock < 240.0:
		await physics_frame
	var halls: Array = g.halls_of(0, false)
	var home: Building = null
	for h in halls:
		if home == null or h.center().distance_to(Vector2(g.starts[0]) * Defs.TILE) < home.center().distance_to(Vector2(g.starts[0]) * Defs.TILE):
			home = h
	for h in halls:
		if h != home:
			g.demolish(h)
	if fac == "crown":
		home.soil = home.reserve() * LEFT
	else:
		home.lode = home.lode_full() * LEFT
	g.players[0]["gold"] = POOR
	var t0 := g.clock
	var laid := -1.0
	var earned0 := 0
	var line := 0.0
	while g.clock < t0 + 240.0:
		await physics_frame
		if OS.get_environment("EXPAND_LOG") != "":
			var gnow: int = g.players[0]["gold"]
			if gnow < _lastg:
				var what := []
				for b in g.buildings:
					if b.team == 0 and not b.dead and (not b.built and b.hp < 50.0 or b.queue.size() > 0):
						what.append("%s%s" % [b.kind, b.queue])
				print("    spent %d at %.1f: %s" % [_lastg - gnow, g.clock - t0, what])
			_lastg = gnow
		if laid < 0.0 and g.halls_of(0, false).any(func(h: Building) -> bool: return h != home and not h.dead):
			laid = g.clock - t0
		if earned0 == 0 and g.clock > t0 + 180.0:
			earned0 = int(g.stats[0]["gold"])
		if g.clock > line:
			line = g.clock + 15.0
			var idle: int = g.workers(0).filter(func(u: Unit) -> bool: return u.order == "idle").size()
			print("  %s %5.0f s: gold %4d earned %6d halls %d (laid %.0f) soil/brass %.2f workers %d idle %d" % [fac, g.clock - t0, g.players[0]["gold"],
				g.stats[0]["gold"], g.halls_of(0, false).size(), laid, ai._best_soil(), g.workers(0).size(), idle])
	if g.mlog and OS.get_environment("EXPAND_LOG") != "":
		for l in g.mlog.lines.slice(-60):
			print("    | " + l)
	if OS.get_environment("EXPAND_LOG") != "":
		var orders := {}
		for u in g.units:
			if u.team == 0 and not u.dead and u.kind == ("labourer" if fac == "crown" else "winder"):
				var hm = u.home_mine
				var k := "%s/%s/%s/%.2f/%s/%d" % [u.order, u.work, hm.kind if hm is Building else "-", hm.soil_left() if hm is Building else -1.0, str(u.auto_work), int(u.position.distance_to(hm.center()) / Defs.TILE) if hm is Building else -1]
				orders[k] = int(orders.get(k, 0)) + 1
		print("    workers by order: ", orders)
		for b in g.buildings:
			if b.team == 0 and not b.dead and b.crew_max() > 0:
				print("    %s crew %d/%d soil %.2f lode %.2f built %s" % [b.kind, b.working_crew(), b.crew_max(), b.soil_left(), b.lode_left(), b.built])
	var late := int(g.stats[0]["gold"]) - earned0
	check(laid >= 0.0 and laid <= WITHIN, "[%s] a new hall laid within %.0f s (at %.0f s)" % [fac, WITHIN, laid])
	check(late > 60, "[%s] still earning in the last 60 s (%d)" % [fac, late])
	main.queue_free()
	await process_frame
	await process_frame


## The Brood: every Rootmaw's ground nearly spent at 4:00; within 240 s it must root Rootmaws on fresh ground and keep earning.
func _brood() -> void:
	var main: Node = await _start("brood", "crown")
	var g: Game = main.game
	while g.clock < 240.0:
		await physics_frame
	var old := {}
	for id in g.nb_spots:
		g.nb_spots[id]["left"] = minf(float(g.nb_spots[id]["left"]), 30.0)
		old[id] = true
	var t0 := g.clock
	var earned0 := 0
	var fresh_rooted := 0
	var line := 0.0
	while g.clock < t0 + 240.0:
		await physics_frame
		if earned0 == 0 and g.clock > t0 + 180.0:
			earned0 = int(g.stats[0]["gold"])
		if g.clock > line:
			line = g.clock + 30.0
			fresh_rooted = 0
			for u in g.units:
				if u.team == 0 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u) and not old.has(int(u.nb.get("spot", 0))):
					fresh_rooted += 1
			print("  brood %5.0f s: food %4d earned %6d Rootmaws on fresh ground %d" % [g.clock - t0, g.players[0]["gold"], g.stats[0]["gold"], fresh_rooted])
	var late := int(g.stats[0]["gold"]) - earned0
	check(fresh_rooted >= 1, "[brood] Rootmaws rooted on fresh ground (%d)" % fresh_rooted)
	check(late > 60, "[brood] still earning in the last 60 s (%d)" % late)
	main.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	var only := OS.get_environment("EXPAND_ONLY")      # (crown, clockwork or brood: one case)
	if only in ["", "crown"]:
		await _case("crown")
	if only in ["", "clockwork"]:
		await _case("clockwork")
	if only in ["", "brood"]:
		await _brood()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
