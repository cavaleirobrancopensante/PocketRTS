extends SceneTree
## Drags end when their button is let go over the UI (playtest 0.14.82: "the drag line running out of control, I think
## it is when the mouse touches the UI"). A release over the HUD is taken by it and never reaches
## Controls._unhandled_input; the drag must end all the same (Controls._end_lost_drags, _touch_lost).
##   godot --headless --fixed-fps 30 --script res://tools/test_drag_release_ui.gd
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _btn(btn: int, at: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.position = _win(at)
	ev.global_position = _win(at)
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_RIGHT if btn == MOUSE_BUTTON_RIGHT else (MOUSE_BUTTON_MASK_LEFT if btn == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE)
	return ev


## Input.parse_input_event takes window positions (the root viewport scales them to its own: headless, the window
## is not the viewport's size)
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _motion(at: Vector2, mask: int) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.button_mask = mask
	return ev


## (the button presses and releases go through Input, as the real ones do: the HUD sees them first and Input knows
## the button is held; the mouse motions go straight to the field, as the HUD lets them through there)
func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var c: Controls = g.controls
	Settings.device = "pc"
	g.explored.fill(1)
	var men: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.is_worker()).slice(0, 4)
	g.set_selection(men)
	g.camera.position = g.halls_of(0)[0].center() + Vector2(0, 120)     # (the field spot on open ground in the map)
	g.camera.force_update_scroll()
	c._mouse_inside = false        # (no edge scrolling: headless, the viewport's mouse position is not the events')
	c._exit_dir = Vector2.ZERO
	await _frames(3)
	var vs: Vector2 = g.get_viewport().get_visible_rect().size
	var field := vs * Vector2(0.45, 0.4)
	var hud_p: Vector2 = g.hud.card_rect().get_center() * g.hud.ui_scale
	check(g.hud._hud_has(hud_p / g.hud.ui_scale) and not g.hud._hud_has(field / g.hud.ui_scale), "the test spots: one on the field, one on the command card")

	# 1. a right-drag line let go over the HUD: the HUD takes the release; the line still ends (carried out)
	Input.parse_input_event(_btn(MOUSE_BUTTON_RIGHT, field, true))
	await _frames(2)
	check(c._line_btn == "right", "a right press on the field starts a line")
	for k in range(1, 9):
		c._unhandled_input(_motion(field.lerp(hud_p, k / 8.0), MOUSE_BUTTON_MASK_RIGHT))
		await _frames(1)
	Input.parse_input_event(_btn(MOUSE_BUTTON_RIGHT, hud_p, false))
	await _frames(3)
	check(c._line_btn == "" and c.line.is_empty(), "released over the HUD: the line ended (%s, %d points)" % [c._line_btn, c.line.size()])
	check(men.any(func(u: Unit) -> bool: return u.order == "move"), "the line as drawn was carried out (the men move)")
	var n0: int = c.line.size()
	for k in 4:
		c._unhandled_input(_motion(field + Vector2(k * 30, 0), 0))
		await _frames(1)
	check(c.line.size() == n0 and c.line.is_empty(), "the mouse moving on after the release draws nothing")

	# 2. a right press whose release never arrives anywhere (the button is not held): ended next frame
	c._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, field, true))
	check(c._line_btn == "right", "a line started by a press seen only by the field")
	await _frames(2)
	check(c._line_btn == "", "the button not held: the line ends by itself")

	# 3. an ordinary right drag let go on the field still works once (no second order from the check)
	g.set_selection(men)
	Input.parse_input_event(_btn(MOUSE_BUTTON_RIGHT, field, true))
	await _frames(1)
	for k in range(1, 6):
		c._unhandled_input(_motion(field + Vector2(k * 25, 0), MOUSE_BUTTON_MASK_RIGHT))
		await _frames(1)
	check(c._line_btn == "right" and c.line.size() >= 2, "held: the line follows the mouse, the check leaves it be (%d points)" % c.line.size())
	Input.parse_input_event(_btn(MOUSE_BUTTON_RIGHT, field + Vector2(125, 0), false))
	await _frames(2)
	check(c._line_btn == "" and c.line.is_empty(), "let go on the field: ended as usual")

	# 4. a box drag let go over the HUD: the box ends (selects what it covered)
	g.set_selection([])
	var a := field + Vector2(-200, -150)
	Input.parse_input_event(_btn(MOUSE_BUTTON_LEFT, a, true))
	await _frames(1)
	c._unhandled_input(_motion(a + Vector2(40, 40), MOUSE_BUTTON_MASK_LEFT))
	await _frames(1)
	check(c._lmb_down and c._box_from != Vector2.INF, "a left drag on the field draws a box")
	# the HUD has the release (as a Control would): it never reaches the field
	c._unhandled_input(_motion(hud_p, MOUSE_BUTTON_MASK_LEFT))
	await _frames(1)
	g.hud._mouse_hud = true           # (the HUD takes this release: _input sets it handled)
	Input.parse_input_event(_btn(MOUSE_BUTTON_LEFT, hud_p, false))
	await _frames(3)
	g.hud._mouse_hud = false
	check(not c._lmb_down and c._box_from == Vector2.INF, "released over the HUD: the box ended")

	# 5. the middle-button map drag
	Input.parse_input_event(_btn(MOUSE_BUTTON_MIDDLE, field, true))
	await _frames(1)
	check(c._mid_pan, "a middle press pans")
	Input.parse_input_event(_btn(MOUSE_BUTTON_MIDDLE, hud_p, false))
	await _frames(2)
	check(not c._mid_pan, "the middle button let go over the HUD: the pan ended")

	# 6. touch: a MOVE line drawn with a finger lifted over a Control (the release only seen by _input)
	Settings.device = "phone"
	g.set_selection(men)
	c.mode = "move"
	var tp := InputEventScreenTouch.new()
	tp.index = 0
	tp.pressed = true
	tp.position = field
	c._unhandled_input(tp)
	for k in range(1, 6):
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = field + Vector2(k * 30, 0)
		dr.relative = Vector2(30, 0)
		c._unhandled_input(dr)
	check(c._line_btn == "touch", "a finger drag after MOVE draws a line")
	var tr := InputEventScreenTouch.new()
	tr.index = 0
	tr.pressed = false
	tr.position = field + Vector2(150, 0)
	if c.has_method("_input"):
		c._input(tr)                      # (only _input sees it: a Control takes it before _unhandled_input)
	await _frames(2)
	check(c._line_btn == "" and c._touches.is_empty() and c.mode == "", "the finger lifted over the UI: the line ended")
	# and a finger lift that reaches the field is handled once, as before
	c.mode = "move"
	c._unhandled_input(tp)
	for k in range(1, 6):
		var dr2 := InputEventScreenDrag.new()
		dr2.index = 0
		dr2.position = field + Vector2(k * 30, 0)
		dr2.relative = Vector2(30, 0)
		c._unhandled_input(dr2)
	if c.has_method("_input"):
		c._input(tr)
	c._unhandled_input(tr)
	await _frames(2)
	check(c._line_btn == "" and c._touches.is_empty() and c.mode == "", "a lift on the field: ended as usual")
	Settings.device = "pc"
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
