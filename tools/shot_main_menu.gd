extends SceneTree
## The main menu as it opens: xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_main_menu.gd -- <out.png>
var main
var out := "/tmp/main_menu.png"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	# a shot or test that quit mid-session leaves the "running" marker: without this the crash page shows
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func _run() -> void:
	await create_timer(2.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out)
	print("wrote ", out)
	quit()
