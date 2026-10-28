extends SceneTree
## The shown name comes from one place and old match logs still read: godot --headless --script res://tools/test_game_name.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	check(GameName.title() == ProjectSettings.get_setting("application/config/name"), "the name is project.godot's config/name: " + GameName.title())
	check(not "holdfast" in GameName.title().to_lower(), "the shown name is not Holdfast")
	check(ProjectSettings.get_setting("application/config/use_custom_user_dir") == true and ProjectSettings.get_setting("application/config/custom_user_dir_name") == "Pocket RTS", "the user folder stays Pocket RTS")
	check(GameName.is_log_header(GameName.title() + " v0.14.102 match log  (2026-10-28 10:00:00)"), "a new match log header reads")
	check(GameName.is_log_header("Holdfast v0.14.90 match log  (2026-10-27 10:00:00)"), "an old Holdfast match log header reads")
	check(not GameName.is_log_header("[00:12] P1 Crown says: gg"), "a timeline line is not a header")
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg parses")
	for s in cfg.get_sections():
		if cfg.get_value(s, "platform", "") == "Android":
			check(String(cfg.get_value(s + ".options", "package/name", "")) == "", "the Android app name follows config/name")
			check(String(cfg.get_value(s + ".options", "package/unique_name", "")).ends_with(".pocketrts"), "the Android package id is unchanged")
	var shell := FileAccess.get_file_as_string("res://tools/web/shell.html")
	check(not "HOLDFAST</h1>" in shell and "$GODOT_PROJECT_NAME</h1>" in shell, "the web loading page shows config/name")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
