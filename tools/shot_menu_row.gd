extends SceneTree
## The main menu's flat grid as pictures (docs/shots/main_menu/, kept there as jpg):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_menu_row.gd -- <outdir> [pc|mobile] [prefix] [lang] [cont]
## writes <prefix>menu.png (cont: also <prefix>menu_continue.png with a pretend saved match in the CONTINUE slot).
## A phone: --resolution 2400x1080 ... -- <outdir> mobile phone_
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
	if lang != "" and lang != "-":
		Settings.language = lang     # (not saved)
		Loc.set_lang(lang)
	main.show_menu()
	var c: Button = main.menu_buttons.get("continue")
	if c:
		c.queue_free()                 # (the picture without CONTINUE)
		main.menu_buttons.erase("continue")
	await _snap("menu")
	if cont:
		var b: Button = main._menu_button("continue", {"version": main.version, "cfg": {"slots": [{"faction": "crown"}, {"faction": "clockwork"}]}, "clock": 754}, Settings.pc())
		main.menu_buttons["continue"] = b
		main._menu_grid.add_child(b)
		main._layout_menu()
		await _snap("menu_continue")
	quit()
