extends SceneTree
## MAP EDITOR: a mouse click on a button works after painting (0.14.64: the editor's _input
## ate every release over the panel, so BACK, SAVE, HELP... never fired with a mouse), and a
## stroke that ends over the panel still ends.
##   godot --headless --fixed-fps 30 --script res://tools/test_map_editor_buttons.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _mouse(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	root.push_input(e, true)


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	root.push_input(e, true)


func _click(p: Vector2) -> void:
	_move(p)
	_mouse(p, true)
	await process_frame
	_mouse(p, false)
	await process_frame
	await process_frame


func _button(ed: Control, text: String) -> Button:
	for b in ed.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


func _run() -> void:
	Settings.device = "pc"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.show_map_editor("", {})
	for i in 5:
		await process_frame
	var ed: Control = main._editor
	check(ed != null, "the map editor opened")
	var backs := [0]
	ed.back_requested.connect(func() -> void: backs[0] += 1)
	var vs: Vector2 = root.get_visible_rect().size
	var mid := vs * Vector2(0.6, 0.55)
	# paint a stroke on the map
	_move(mid)
	_mouse(mid, true)
	await process_frame
	_move(mid + Vector2(60, 30))
	await process_frame
	_mouse(mid + Vector2(60, 30), false)
	await process_frame
	check(not ed._painting, "the stroke ended")
	# then a click on HELP opens the help (the bar is rebuilt after a stroke: find it again)
	var help := _button(ed, "HELP")
	check(help != null, "HELP button found")
	if help:
		await _click(help.get_global_rect().get_center())
		var close := _button(ed, "CLOSE")
		check(close != null, "HELP opens the help after painting")
		if close:
			await _click(close.get_global_rect().get_center())
			check(_button(ed, "CLOSE") == null, "CLOSE closes the help")
	# a stroke that ends over the panel ends without pressing what is under it
	_move(mid)
	_mouse(mid, true)
	await process_frame
	var back := _button(ed, "BACK")
	check(back != null, "BACK button found")
	if back:
		var bp := back.get_global_rect().get_center()
		_move(bp)
		await process_frame
		_mouse(bp, false)
		await process_frame
		check(not ed._painting and backs[0] == 0, "a stroke released over BACK ends and does not go back")
		await _click(bp)
		check(backs[0] == 1, "BACK fires (%d)" % backs[0])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
