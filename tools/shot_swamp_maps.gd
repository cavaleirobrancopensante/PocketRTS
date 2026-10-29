extends SceneTree
## The Brood swamp on a map: xvfb-run -a godot --rendering-driver opengl3 --resolution 1000x700 --script res://tools/shot_swamp_maps.gd -- /tmp/swamp_x.png <map>
var main
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())
func _run(a: Array) -> void:
	await process_frame
	main.start({"map": a[1], "seed": 5, "slots": [
		{"who": "human", "faction": "brood", "colour": (int(a[2]) if a.size() > 2 else 0), "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g = main.game
	Engine.time_scale = 8.0
	await create_timer(60.0 / 8.0, true, false, true).timeout
	Engine.time_scale = 1.0
	var q = BroodNew.queen(g, g.human)       # (0.18.0: the swamp round the rooted Brood Mother)
	g.camera.position = q.position + Vector2(120, 60)
	g.camera.zoom = Vector2(1.0, 1.0)
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
