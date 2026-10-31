extends SceneTree
## The main menu's row levels as pictures (docs/shots/main_menu/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_menu_row.gd -- <outdir> [pc|mobile] [prefix] [lang] [cont]
## (cont: a pretend saved match, to see the widest top row with CONTINUE)
## writes <prefix>top.png and <prefix>play.png (a phone: --resolution 2400x1080 ... -- <outdir> mobile phone_).
var main
var out := "/tmp"
var prefix := ""
var cont := false
var lang := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	Settings.load_all()
	Settings.device = a[1] if a.size() > 1 else "pc"
	prefix = a[2] if a.size() > 2 else ""
	Settings.apply()
	lang = a[3] if a.size() > 3 else ""
	cont = a.size() > 4
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String) -> void:
	await create_timer(0.8).timeout
	var p := "%s/%s%s.png" % [out, prefix, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("wrote ", p)


func _run() -> void:
	await create_timer(1.5).timeout
	if lang != "":
		Settings.language = lang     # (not saved)
		Loc.set_lang(lang)
	main.show_menu("top")
	if cont:
		main._fill_menu_row({"version": main.version, "cfg": {"slots": [{"faction": "crown"}, {"faction": "clockwork"}]}, "clock": 754}, false)
	await _snap("top")
	main.menu_level = "play"
	main._fill_menu_row(SaveGame.peek(), false)
	await _snap("play")
	quit()
