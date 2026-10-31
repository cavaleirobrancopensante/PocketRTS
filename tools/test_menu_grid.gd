extends SceneTree
## THE MAIN MENU'S FLAT GRID (the owner's layout, 2026-10-31): 3 x 3 slots, row by row
##   CAMPAIGN (disabled) SKIRMISH ONLINE / HOW TO PLAY REPLAYS EDITOR / CONTINUE (only with a save) SETTINGS EXIT (not on the web)
## all inside the painting's top-left sky; Esc does nothing on the menu; every page's BACK returns to it;
## MATCH LOGS is on the REPLAYS page.
##   godot --headless --script res://tools/test_menu_grid.gd
## Prints PASS / FAIL lines and "menu_grid: N fails".
var main
var fails := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://running.txt"))
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	Loc.set_lang("en")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(what: String, ok: bool, got: Variant) -> void:
	print(("PASS " if ok else "FAIL ") + what + "  " + str(got))
	if not ok:
		fails += 1


func _esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)


func _on_menu() -> bool:
	return is_instance_valid(main._menu_grid) and main._menu_grid.is_inside_tree()


## Open a page with `open`, press Esc (its BACK): back on the main menu?
func _back_from(name: String, open: Callable) -> void:
	open.call()
	await process_frame
	await process_frame
	_check(name + " has a BACK", is_instance_valid(main._esc_button), main._esc_button)
	_esc()
	await process_frame
	await process_frame
	_check(name + " BACK -> main menu", _on_menu(), name)


func _run() -> void:
	await process_frame
	main.show_menu()
	await process_frame
	await process_frame
	var b: Dictionary = main.menu_buttons
	var fixed := ["campaign", "skirmish", "online", "help", "replays", "editor", "settings", "exit"]
	var miss := fixed.filter(func(id: String) -> bool: return not b.has(id))
	_check("the 8 fixed slots", miss.is_empty(), miss)
	_check("slot order", main.MENU_SLOTS == ["campaign", "skirmish", "online", "help", "replays", "editor", "continue", "settings", "exit"], main.MENU_SLOTS)
	_check("CAMPAIGN disabled", b["campaign"].disabled and b["campaign"].tooltip_text != "", b["campaign"].text)
	_check("SKIRMISH text", b["skirmish"].text == "SKIRMISH", b["skirmish"].text)
	_check("no Esc on the main menu", main._esc_button == null, main._esc_button)
	var save: Dictionary = SaveGame.peek()
	var want_cont: bool = not save.is_empty() and not SaveGame.old_brood(save) and save.get("version", "") == main.version
	_check("CONTINUE only with a save of this version", b.has("continue") == want_cont, [b.has("continue"), want_cont])
	var fake := {"version": main.version, "cfg": {"slots": [{"faction": "crown"}, {"faction": "clockwork"}]}, "clock": 754}
	var c: Button = main._menu_button("continue", fake, true)
	_check("CONTINUE with a save", c != null and c.text.begins_with("CONTINUE\n("), c.text if c else null)
	_check("no CONTINUE without a save", main._menu_button("continue", {}, true) == null, "")
	var old := fake.duplicate(true)
	old["version"] = "0.0.1"
	_check("no CONTINUE for another version's save", main._menu_button("continue", old, true) == null, "")
	# the grid: inside the sky (top-left 36% x 43%), no overlaps, the owner's fractions at 16:9
	var vs: Vector2 = main._menu_grid.size
	var sky := Rect2(Vector2.ZERO, vs * Vector2(0.36, 0.43))
	var rects: Array = []
	for id in b:
		var r := Rect2(b[id].position, b[id].size)
		rects.append(r)
		if not sky.encloses(r):
			_check(id + " inside the sky", false, [r, sky])
	var lap := false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			lap = lap or (rects[i] as Rect2).intersects(rects[j])
	_check("no two buttons overlap", not lap, rects)
	_check("button size ~10.5% x 8.5%", absf(b["online"].size.x / vs.x - 0.105) < 0.01 and absf(b["online"].size.y / vs.y - 0.085) < 0.01, b["online"].size / vs)
	_check("SETTINGS in row 3, column 2", absf(b["settings"].position.x / vs.x - 0.12) < 0.01 and absf(b["settings"].position.y / vs.y - 0.33) < 0.01, b["settings"].position / vs)
	_check("title box", main._menu_title.position.x <= vs.x * 0.01 and main._menu_title.size.x <= vs.x * 0.53 + 1, Rect2(main._menu_title.position, main._menu_title.size))
	# a phone (2400 x 1080 shows 1600 x 720) and a 4:3 tablet: no smaller than the mobile minimum, still compact
	for ph in [Vector2(1600, 720), Vector2(1280, 960)]:
		var g: Array = main.menu_geometry(ph, false)
		var bs: Vector2 = g[0]
		var far: Vector2 = g[2] + 2.0 * (bs + g[1]) + bs
		_check("phone %s: min size" % ph, bs.x >= main.MENU_MIN_MOBILE.x and bs.y >= main.MENU_MIN_MOBILE.y, bs)
		_check("phone %s: grid compact" % ph, far.x <= ph.x * 0.42 and far.y <= ph.y * 0.5, far / ph)
	# EXIT hidden on the web (its slot empty)
	main.menu_web = true
	main.show_menu()
	await process_frame
	_check("no EXIT on the web", not main.menu_buttons.has("exit") and main.menu_buttons.has("settings"), main.menu_buttons.keys())
	main.menu_web = false
	main.show_menu()
	await process_frame
	# Esc on the menu does nothing
	_esc()
	await process_frame
	_check("Esc on the menu: still the menu", _on_menu(), "")
	# MATCH LOGS from the REPLAYS page
	var rm = main.show_replays()
	await process_frame
	var logs: Button = rm.find_child("MatchLogs", true, false)
	_check("MATCH LOGS on the REPLAYS page", logs != null and logs.text == "MATCH LOGS", logs)
	if logs:
		logs.pressed.emit()
		await process_frame
		_check("MATCH LOGS opens the logs", is_instance_valid(main._esc_button) and not _on_menu(), "")
		_esc()
		await process_frame
		await process_frame
		_check("logs BACK -> main menu", _on_menu(), "")
	# every page's BACK comes back to the main menu
	await _back_from("SKIRMISH", func() -> void: main.menu_buttons["skirmish"].pressed.emit())
	await _back_from("HOW TO PLAY", func() -> void: main.menu_buttons["help"].pressed.emit())
	await _back_from("REPLAYS", func() -> void: main.menu_buttons["replays"].pressed.emit())
	await _back_from("EDITOR", func() -> void: main.menu_buttons["editor"].pressed.emit())
	await _back_from("SETTINGS", func() -> void: main.menu_buttons["settings"].pressed.emit())
	await _back_from("ONLINE", func() -> void: main.menu_buttons["online"].pressed.emit())
	print("menu_grid: %d fails" % fails)
	quit(1 if fails > 0 else 0)
