extends SceneTree
## The computer Clockwork with the roster switched on (Clockwork roster prototype, Settings CLOCKWORK LAB on): 3 game
## minutes against a passive Crown: it must not crash or stall and must not train the experimental units.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_ai.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	Settings.cw_lab = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(77)
		main.start({"map": "ashford_crossing", "seed": 77, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
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
			if ai.team != 0:
				ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	check(Defs.cw_roster, "the roster is on (Settings)")
	while g.clock < 180.0 and not g.over:
		await physics_frame
	var mine: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead)
	check(g.clock >= 180.0, "the match ran 3 minutes")
	check(mine.size() >= 6, "it has units (%d)" % mine.size())
	check(float(g.stats[0]["spent"]) > 800.0, "it kept spending (%d)" % int(g.stats[0]["spent"]))
	check(not mine.any(func(u: Unit) -> bool: return Defs.CW_KINDS.has(u.kind)), "it trained none of the experimental units")
	check(not g.buildings.any(func(b: Building) -> bool: return b.team == 0 and b.kind == "rail_yard"), "it built no Rail Yard")
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
