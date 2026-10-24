extends SceneTree
## Screenshot of the animation viewer: godot --script res://tools/shot_anim_viewer.gd -- /tmp/anim_viewer.png [unit] [anim]
var main


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var av: AnimViewer = main.show_anim_viewer()
	await process_frame
	av.select_art(a[1] if a.size() > 1 else "musketeer")
	av.select_anim(a[2] if a.size() > 2 else "walk")
	av.select_dir("e")
	await create_timer(0.5).timeout
	av.step(1)
	av.flag_frame()
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/anim_viewer.png")
	quit()
