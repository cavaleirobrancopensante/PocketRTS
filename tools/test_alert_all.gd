extends SceneTree
## The universal attack alarm exists and plays for every faction when something of yours is hit.
var main: Node
var fails := 0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1
func _run() -> void:
	await process_frame
	for fac in ["crown", "brood", "clockwork"]:
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		await process_frame
		var g = main.game
		g.hud.countdown = 0.0
		paused = false
		for i in 3:
			await physics_frame
		check(Sfx.has("ui/alert_all"), "%s: the alarm sound is found" % fac)
		var u = g.units.filter(func(x): return x.team == 0 and not x.dead)[0]
		g.camera.position = g.halls_of(1)[0].center()
		g.camera.force_update_scroll()
		await physics_frame
		g._alert_ms = -99999
		u.global_position = g.camera.get_screen_center_position() + Vector2(1500, 0)
		g.under_attack(u)
		check(g._alert_ms > 0, "%s: an attack on a unit raises the alarm" % fac)
		await create_timer(1.5).timeout
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
