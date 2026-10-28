extends SceneTree
## AI round 5 (docs/ai_round5.md): the Crown computer against the Clockwork finds its spots behind the ramp wall
## (the firing line on the high ground, three tiles in; the guns six) on every map, and the Clockwork its ramp post.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_r5_hold_spots.gd -- [maps:greenhold,frostmere] [at:<s>]
var fails := 0
var maps := ["greenhold", "frostmere", "hollowfen", "kestrel_rise"]
var at := 150.0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("maps:"):
			maps = Array(a.substr(5).split(","))
		elif a.begins_with("at:"):
			at = float(a.substr(3))
	_run.call_deferred()


func _run() -> void:
	for m in maps:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		seed(3)
		main.start({"map": m, "seed": 3, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
		await process_frame
		await process_frame
		var g: Game = main.game
		if g.hud:
			g.hud.countdown = 0.0
		paused = false
		# (the ramps are found before anything is built on them: AI._ramp_bands skips built cells, and with round 5's Crown
		# part off by default nothing asks for them early in a game; on the 0.15 maps the wall stood first and the spots
		# came out empty)
		for a in g.ais:
			a.r5._bands()
		while g.clock < at and not g.over:
			await physics_frame
		for a in g.ais:
			var hs: Array = a.r5._behind() if a._crown() else a.r5._ramp_cells()
			var what := "Crown hold spots behind the wall (walled %s)" % a._walled if a._crown() else "Clockwork ramp post spots"
			check(hs.size() >= (2 if a._crown() else 1), "%s: %s: %s" % [m, what, str(hs)])
		main.queue_free()
		await process_frame
		await process_frame
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
