extends SceneTree
## Screenshot of a patrol path: godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_patrol.gd -- out.png
var main: Node
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())
func _run(a: Array) -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await physics_frame
	var c: Vector2 = g.halls_of(0)[0].center()
	var men: Array = g.units.filter(func(u): return u.team == 0 and not u.dead).slice(0, 3)
	g.set_selection(men)
	g.camera.position = c + Vector2(0, 120)
	for u in men:
		u.cmd_patrol(c + Vector2(260, 140))
	for i in 40:
		await physics_frame
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	# the preview while choosing
	men[0].order = "idle"
	g.set_selection(men)
	g.controls.mode = "patrol"
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0].replace(".png", "_choose.png"))
	quit()
