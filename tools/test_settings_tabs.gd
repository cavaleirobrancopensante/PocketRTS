extends SceneTree
## The Settings page in tabs (scripts/main.gd show_settings / settings_rows):
##   godot --headless --script res://tools/test_settings_tabs.gd
##   (under xvfb-run with a real display it also checks the window really goes full screen)
## 1. the five tabs are on the page and each one opens;
## 2. every setting shows in exactly one tab (computer and phone), none missing;
## 3. FULL SCREEN (computer) flips Settings.window_full, is saved in settings.cfg and, with a
##    display, switches the window mode;
## 4. each small mute button beside a volume bar mutes its sound (the Music / SFX bus, the ambience).
## The player's settings file is put back at the end. Prints PASS / FAIL; exit code 1 on a failure.

const PC_IDS := ["language", "device", "grid_keys", "layout", "tooltips", "build_grid", "replays_keep", "relay_url",
	"window_full", "ui_size", "mini_alpha", "powder_smoke", "area_marks", "expansion_spots", "health_bars", "charge_bars",
	"music", "sound", "ambience", "music_player", "gear_turn", "marching_band", "cw_lab", "patch_notes", "anim_viewer", "reset"]

var main
var fails := 0
var saved_cfg := ""


func _initialize() -> void:
	if FileAccess.file_exists(Settings.PATH):
		saved_cfg = FileAccess.get_file_as_string(Settings.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ids(tab: String) -> Array:
	main.show_settings(tab)
	var rows: Node = main.menu.find_child("Rows", true, false)
	var out: Array = []
	for r in rows.get_children():
		if r.has_meta("setting"):
			out.append(String(r.get_meta("setting")))
	return out


func _run() -> void:
	await process_frame
	var dev := Settings.device
	for device in ["pc", "mobile"]:
		Settings.device = device
		main.show_settings("GAMEPLAY")
		await process_frame
		var tabs: Node = main.menu.find_child("Tabs", true, false)
		_check(tabs != null and tabs.get_child_count() == main.SETTINGS_TABS.size(), "%s: %d tabs on the page" % [device, main.SETTINGS_TABS.size()])
		var seen := {}
		for t in main.SETTINGS_TABS:
			for id in _ids(t):
				seen[id] = seen.get(id, []) + [t]
		var want: Array = PC_IDS.duplicate()
		if device == "mobile":
			want[want.find("grid_keys")] = "drag_mode"
		if not Settings.can_window_full():
			want.erase("window_full")
		for id in want:
			_check(seen.has(id) and (seen[id] as Array).size() == 1, "%s: %s in exactly one tab %s" % [device, id, str(seen.get(id, []))])
		for id in seen:
			_check(want.has(id), "%s: %s expected" % [device, id])
	_check(main.settings_tab == "OTHER", "the last tab picked is remembered (%s)" % main.settings_tab)

	# FULL SCREEN
	Settings.device = "pc"
	main.show_settings("DISPLAY")
	await process_frame
	var fs_row: Node = null
	for r in main.menu.find_child("Rows", true, false).get_children():
		if r.get_meta("setting", "") == "window_full":
			fs_row = r
	_check(fs_row != null, "FULL SCREEN row in DISPLAY")
	if fs_row:
		var b: Button = fs_row.get_child(fs_row.get_child_count() - 1)
		var was := Settings.window_is_full()
		b.pressed.emit()
		for i in 10:
			await process_frame
		_check(Settings.window_full != was, "FULL SCREEN flips the setting")
		var cfg := ConfigFile.new()
		cfg.load(Settings.PATH)
		_check(bool(cfg.get_value("display", "fullscreen", was)) == Settings.window_full, "FULL SCREEN saved in settings.cfg")
		if DisplayServer.get_name() != "headless":
			var m := DisplayServer.window_get_mode()
			var full := m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			_check(full == Settings.window_full, "the window mode follows (mode %d)" % m)
		else:
			print("(headless: the window mode itself is not checked)")
		b.pressed.emit()
		for i in 10:
			await process_frame
		_check(Settings.window_full == was, "FULL SCREEN back")

	# the mute buttons
	main.show_settings("SOUND")
	await process_frame
	for r in main.menu.find_child("Rows", true, false).get_children():
		var id := String(r.get_meta("setting", ""))
		if not id in ["music", "sound", "ambience"]:
			continue
		var mb: Button = r.find_child("Mute", true, false)
		_check(mb != null, "%s: a small mute button beside its bar" % id)
		if mb == null:
			continue
		_check(mb.size.x <= 60.0 and mb.custom_minimum_size.x <= 60.0, "%s: the mute button is small (%.0f px)" % [id, mb.size.x])
		var before := Music.me.is_muted(id)
		mb.pressed.emit()
		_check(Music.me.is_muted(id) != before, "%s: the button mutes it" % id)
		if id != "ambience":
			var bus := AudioServer.get_bus_index("Music" if id == "music" else "SFX")
			_check(AudioServer.is_bus_mute(bus) == Music.me.is_muted(id), "%s: its bus follows" % id)
		mb.pressed.emit()
		_check(Music.me.is_muted(id) == before, "%s: pressed again, back" % id)

	Settings.device = dev
	if saved_cfg != "":
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_string(saved_cfg)
		f.close()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
