extends SceneTree
## Headless benchmark: a 4-player match fast-forwarded, then a 150-unit fight; prints
## the real milliseconds per simulated frame.
var main
func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func _run() -> void:
	seed(7)
	await process_frame
	var slots := []
	for i in 4:
		slots.append({"who": "hard", "faction": ["crown", "brood", "clockwork", "crown"][i], "colour": i, "side": i})
	main.start({"map": "greenhold", "slots": slots})
	var g = main.game
	g.rng.seed = 7
	while g.clock < 120.0:
		await physics_frame
	var c := Vector2(42, 30) * Game.T
	var ks := ["musketeer", "cuirassier", "raptor", "spitter", "gearknight", "bolt"]
	for k in ks:
		for i in 14:
			g._add_unit(k, ks.find(k) / 2, c + Vector2(randf_range(-220, 220), randf_range(-140, 140)))
	g.camera.position = c
	var t0 := Time.get_ticks_usec()
	var n := 0
	while n < 300:
		await physics_frame
		n += 1
	print("BENCH units=%d ms_per_frame=%.2f" % [g.units.size(), (Time.get_ticks_usec() - t0) / 1000.0 / n])
	quit()
