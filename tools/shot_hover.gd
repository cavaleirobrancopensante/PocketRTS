extends SceneTree
## Hover feedback screenshots: godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_hover.gd -- out.png
var main: Node
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())
func _run(a: Array) -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.reveal = true
	var c: Vector2 = g.halls_of(0)[0].center() + Vector2(0, 110)
	g.camera.position = c
	var foe = g._add_unit("raptor", 1, c + Vector2(60, 0))
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	var mine = g.units.filter(func(u): return u.team == 0 and not u.dead)[0]
	mine.position = c + Vector2(-60, 0)
	for i in 5:
		await physics_frame
	g.hover_target = foe
	await create_timer(0.4).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	g.hover_target = mine
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0].replace(".png", "_own.png"))
	g.hover_target = g.halls_of(0)[0]
	g.camera.position = g.halls_of(0)[0].center()
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0].replace(".png", "_building.png"))
	quit()
