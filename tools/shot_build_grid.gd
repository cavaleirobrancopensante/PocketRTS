extends SceneTree
## Screenshot of the build grid: xvfb-run -a godot --rendering-driver opengl3 --script res://tools/shot_build_grid.gd -- /tmp/build_grid.png [kind] [dx dy]
var main


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(a: Array) -> void:
	await process_frame
	Settings.device = "mobile"
	main.start({"map": "highmoor", "seed": 5, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g = main.game
	Engine.time_scale = 8.0
	await create_timer(120.0 / 8.0, true, false, true).timeout
	Engine.time_scale = 1.0
	var hall = g.buildings.filter(func(b): return b.team == g.human and b.kind == g.faction_hall(g.human))[0]
	g.camera.position = hall.center()
	g.camera.zoom = Vector2(2.2, 2.2)
	var kind: String = a[1] if a.size() > 1 else "barracks"
	g.controls.begin_place(kind)
	var off := Vector2i(int(a[2]), int(a[3])) if a.size() > 3 else Vector2i(4, 3)
	g.controls.ghost_cell = hall.cell + off
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
