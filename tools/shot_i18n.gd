extends SceneTree
## Screenshots of the menus in one language:
##   godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_i18n.gd -- <outdir> <en|pt|es> [pc|mobile]
var main
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	Settings.load_all()
	Settings.device = a[2] if a.size() > 2 else "pc"
	Settings.language = a[1]
	Loc.set_lang(a[1])
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, Loc.lang, name])


func _run() -> void:
	await process_frame
	main.show_menu()
	await _snap("menu")
	main.show_settings()
	await _snap("settings")
	main.show_help("CROWN")
	await _snap("help")
	main._preset("1v1")
	main.lobby["map"] = "highmoor"
	main.show_skirmish()
	await _snap("lobby")
	main._preset("2v2")
	main.lobby["map"] = "random_2v2"
	main.show_skirmish()
	await _snap("lobby2")
	main.show_device()
	await _snap("device")
	quit()
