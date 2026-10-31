extends SceneTree
## THE MAIN MENU'S ONE ROW (the owner, 2026-10-31): the top row has CONTINUE (only with a saved match),
## PLAY, LEARN, WORKSHOP, SETTINGS; PLAY swaps the row to SKIRMISH, ONLINE, CAMPAIGN (disabled), BACK;
## BACK and Esc return to the top; a page opened from PLAY (SKIRMISH) comes back to the PLAY row.
##   godot --headless --script res://tools/test_menu_row.gd
## Prints PASS / FAIL lines and "menu_row: N fails".
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


func _row() -> Array:
	var out: Array = []
	for b in main._menu_row.get_children():
		if not b.is_queued_for_deletion():
			out.append((b as Button).text.get_slice("\n", 0))
	return out


func _check(what: String, ok: bool, got: Variant) -> void:
	print(("PASS " if ok else "FAIL ") + what + "  " + str(got))
	if not ok:
		fails += 1


func _press(text: String) -> void:
	for b in main._menu_row.get_children():
		if (b as Button).text.get_slice("\n", 0) == text and not b.is_queued_for_deletion():
			(b as Button).pressed.emit()
			return
	_check("button " + text + " found", false, _row())


func _esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)


func _run() -> void:
	await process_frame
	main.show_menu("top")
	await process_frame
	var top := _row()
	var want := ["PLAY", "LEARN", "WORKSHOP", "SETTINGS"]
	var has_cont: bool = top.size() == 5 and top[0] == "CONTINUE"
	_check("top row", top.slice(1 if has_cont else 0) == want and top.size() in [4, 5], top)
	_check("no Esc on the top row", main._esc_button == null, main._esc_button)
	_press("PLAY")
	await process_frame
	_check("PLAY row", _row() == ["SKIRMISH", "ONLINE", "CAMPAIGN", "BACK"], _row())
	var camp: Button = main._menu_row.get_child(2)
	_check("CAMPAIGN disabled", camp.disabled, camp.disabled)
	_press("BACK")
	await process_frame
	_check("BACK -> top", _row().slice(-4) == want and main.menu_level == "top", _row())
	_press("WORKSHOP")
	await process_frame
	_check("WORKSHOP row", _row() == ["EDITOR", "REPLAYS", "MATCH LOGS", "BACK"], _row())
	_esc()
	await process_frame
	await process_frame
	_check("Esc -> top", _row().slice(-4) == want, _row())
	_press("LEARN")
	await process_frame
	_check("LEARN row", _row() == ["HOW TO PLAY", "BACK"], _row())
	_esc()
	await process_frame
	await process_frame
	# a page opened from PLAY comes back to the PLAY row
	_press("PLAY")
	await process_frame
	_press("SKIRMISH")
	await process_frame
	await process_frame
	_esc()             # the skirmish page's BACK
	await process_frame
	await process_frame
	_check("SKIRMISH back -> PLAY row", main.menu_level == "play" and _row() == ["SKIRMISH", "ONLINE", "CAMPAIGN", "BACK"], _row())
	_press("BACK")
	await process_frame
	main.show_settings()
	await process_frame
	_esc()
	await process_frame
	await process_frame
	_check("SETTINGS back -> top", main.menu_level == "top" and _row().slice(-4) == want, _row())
	print("menu_row: %d fails" % fails)
	quit(1 if fails > 0 else 0)
