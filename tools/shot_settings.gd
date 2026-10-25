extends SceneTree
var main
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())
func _run(a: Array) -> void:
	await process_frame
	Settings.device = "mobile"
	main.show_settings()
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
