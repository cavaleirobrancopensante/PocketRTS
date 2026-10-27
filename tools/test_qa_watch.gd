extends SceneTree
## QA soak: WATCHING the computers play (no "you" in the lobby). A 4-player free-for-all, one of each faction plus one
## more; the VIEW options are walked: all vision, each player's vision (fog hides the others), and Follow each player
## (the camera moves on its own); hotkeys 0-4 too. The match plays on four minutes with the HUD as it is in a real game.
##   godot --headless --fixed-fps 30 --script res://tools/test_qa_watch.gd
var main: Node
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-60s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _wait(g, secs: float) -> void:
	var c0: float = g.clock
	var n := 0
	while g.clock < c0 + secs and n < int(secs * 45) + 200:
		await process_frame
		n += 1


func _run() -> void:
	await process_frame
	main.start({"map": "twin_crowns", "seed": 5, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "random"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "random"},
		{"who": "normal", "faction": "clockwork", "colour": 2, "side": 2, "strategy": "random"},
		{"who": "easy", "faction": "brood", "colour": 3, "side": 3, "strategy": "random"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	check("watching: demo match with a spectator", g.demo and g.spectator != null and g.ais.size() == 4)
	await _wait(g, 90.0)
	var sp: Spectator = g.spectator
	check("watching: four options per player plus all vision", sp.options().size() >= 5, str(sp.options().size()))
	for t in 4:
		sp.set_mode("free", t, true)
		g.refresh_fog()
		var hidden := g.units.filter(func(u: Unit) -> bool: return u.team != t and not g.allied(u.team, t) and not u.visible).size()
		check("watching: P%d's vision hides others" % (t + 1), hidden > 0, "%d hidden" % hidden)
	for t in 4:
		sp.set_mode("follow", t, true)
		var p0: Vector2 = g.camera.position
		await _wait(g, 15.0)
		check("watching: following P%d moves the camera" % (t + 1), g.camera.position.distance_to(p0) > 4.0, "moved %.0f px" % g.camera.position.distance_to(p0))
	for n in 5:
		check("watching: hotkey %d" % n, sp.hotkey(n))
		await _wait(g, 2.0)
	sp.set_mode("all", 0, true)
	await _wait(g, 90.0)
	check("watching: the match plays on", g.clock > 200.0, "%.0f s" % g.clock)
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
