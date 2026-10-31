extends SceneTree
## SETTINGS IN A MATCH (the owner, 2026-10-31): the match MENU's SETTINGS opens the tabbed Settings page over the match
## (main.gd open_match_settings). Checks: it pauses a single-player match; the hotkey setting (COMMAND KEYS: grid) and
## HEALTH BARS change in the match; the next-match rows are dimmed, the main-menu-only rows left out; Esc closes it back
## to the MENU, the match is unpaused and goes on.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/test_match_settings.gd [-- shots]
## With "shots" it saves pictures to docs/shots/match_settings/.
var main: Node
var t := 0.0
var busy := false
var fails := 0
var shots := false


func _initialize() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if busy or t < 0.3:
		return false
	busy = true
	_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	if not shots:
		return
	for i in 4:
		await process_frame
	var dir := ProjectSettings.globalize_path("res://docs/shots/match_settings")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot " + name)


func _row(id: String) -> Control:
	var o: Control = main._match_overlay
	if o == null:
		return null
	for n in o.find_children("*", "Control", true, false):
		if n.has_meta("setting") and String(n.get_meta("setting")) == id:
			return n
	return null


func _press_row(id: String) -> bool:
	var r := _row(id)
	if r == null:
		return false
	for c in r.get_children():
		if c is Button:
			(c as Button).pressed.emit()
			return true
	return false


func _tab(name: String) -> void:
	main.show_settings(name)
	await process_frame


func _run() -> void:
	Settings.device = "pc"
	Settings.grid_keys = false
	Settings.health_bars = 0
	main.start({"map": "hollowfen", "seed": 77, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	for i in 40:
		await physics_frame
	var g: Game = main.game
	var hud = g.hud
	hud.countdown = 0.0
	var w: Unit = null
	for u in g.units:
		if u.team == 0 and u.is_worker():
			w = u
			break
	g.set_selection([w])
	hud._refresh_card()
	var k0 := ""
	for it in hud._card_items:
		if String(it[1]) == "BUILD":
			k0 = String(it[6])
	# MENU, then SETTINGS
	hud.toggle_menu(true)
	var labels: Array = hud._menu_buttons().map(func(b: Dictionary) -> String: return String(b["label"]))
	check(labels.has("SETTINGS"), "the match MENU has SETTINGS (%s)" % ", ".join(labels))
	await _shot("1_match_menu")
	for b in hud._menu_buttons():
		if b["label"] == "SETTINGS":
			b["cb"].call()
	await process_frame
	check(main._match_settings and is_instance_valid(main._match_overlay) and hud.settings_open, "SETTINGS opens the Settings page over the match")
	check(hud.paused and paused, "single player: the match is paused under it")
	check(g.hud != null and is_instance_valid(hud), "the match is still there (the HUD was not cleared)")
	check(_row("device") != null and _row("device").modulate.a < 0.9, "PLAYING ON is dimmed (next match)")
	await _shot("2_gameplay")
	# the hotkeys: COMMAND KEYS -> GRID
	check(_press_row("grid_keys") and Settings.grid_keys, "COMMAND KEYS switched to GRID")
	await _tab("DISPLAY")
	check(_press_row("health_bars") and Settings.health_bars == 1, "HEALTH BARS switched to ALWAYS")
	await _shot("3_display")
	await _tab("EXPERIMENTAL")
	check(_row("gear_turn") != null and _row("gear_turn").modulate.a < 0.9, "the experiments are dimmed (next match)")
	await _shot("4_experimental")
	await _tab("OTHER")
	check(_row("reset") == null and _row("anim_viewer") == null, "RESET SETTINGS and the animation viewer are left out in a match")
	await _tab("SOUND")
	check(_row("music") != null and _row("music_player") == null, "SOUND: the volumes, no music player page")
	await _shot("5_sound")
	await _tab("GAMEPLAY")
	# the layout editor (hotkeys) opens over the match too, and its BACK returns to the overlay
	main.show_layout()
	await process_frame
	var eds: Array = main._match_overlay.find_children("*", "LayoutEditor", true, false)
	check(not eds.is_empty() and is_instance_valid(g), "INTERFACE LAYOUT & HOTKEYS opens over the match")
	await _shot("6_hotkeys_editor")
	if not eds.is_empty():
		eds[0].done.emit()
		await process_frame
	check(main._match_settings and _row("grid_keys") != null, "its BACK returns to the Settings over the match")
	# Esc closes it, back to the MENU
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.get_viewport().push_input(esc)
	await process_frame
	await process_frame
	check(not main._match_settings and not hud.settings_open and not is_instance_valid(main._match_overlay), "Esc closes Settings")
	check(hud.menu_open, "back on the match MENU")
	check(not hud.paused and not paused, "the match is unpaused again")
	hud.toggle_menu(false)
	# the settings took effect in the match
	g.set_selection([w])
	hud._refresh_card()
	var k1 := ""
	for it in hud._card_items:
		if String(it[1]) == "BUILD":
			k1 = String(it[6])
	check(k1 != "" and k1 == hud.GRID_KEYS[hud._card_items.find(hud._card_items.filter(func(it) -> bool: return String(it[1]) == "BUILD")[0])], "the worker's BUILD key follows the grid now (%s -> %s)" % [k0, k1])
	var other: Unit = null
	for u in g.units:
		if u.team == 0 and u != w and u.hp >= u.max_hp:
			other = u
			break
	g.set_selection([w])
	check(other != null and other.health_bar_shown(), "an unhurt, unselected unit shows its health bar (ALWAYS)")
	var c0: float = g.clock
	for i in 60:
		await physics_frame
	check(g.clock > c0, "the match goes on (clock %.1f -> %.1f)" % [c0, g.clock])
	await _shot("7_match_after")
	Settings.grid_keys = false
	Settings.health_bars = 0
	Settings.save_all()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
