extends SceneTree
var main
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var out := OS.get_cmdline_user_args()[0]
	var i := 0
	for m in [["greenhold", "crown"], ["frostfang", "clockwork"], ["twin_fords", "brood"], ["highmoor", "crown"]]:
		main.start({"map": m[0], "slots": [{"who": "you", "faction": m[1], "colour": 0, "side": 0}, {"who": "hard", "faction": "brood", "colour": 1, "side": 1}]})
		await process_frame
		var g = main.game
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		g.reveal = true
		g.camera.zoom = Vector2(0.8, 0.8)
		g.camera.position = Vector2(13, 11) * 32
		await create_timer(0.6).timeout
		root.get_viewport().get_texture().get_image().save_png(out + "/start_%d.png" % i)
		i += 1
		g.queue_free()
		main.game = null
		await process_frame
	quit()
