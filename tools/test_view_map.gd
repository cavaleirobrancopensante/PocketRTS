extends SceneTree
## After the match is over, VIEW MAP lets the camera pan (drag) and zoom (wheel); without it the end screen freezes input.
var main: Node
var fails := 0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1
func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for i in 3:
		await physics_frame
	g.over = true
	var p0: Vector2 = g.camera.position
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(60, 0)
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	g.controls._unhandled_input(drag)
	check(g.camera.position == p0, "over: the camera stays frozen")
	g.map_view = true
	var mid := InputEventMouseButton.new()
	mid.button_index = MOUSE_BUTTON_MIDDLE
	mid.pressed = true
	mid.position = Vector2(400, 300)
	g.controls._unhandled_input(mid)
	g.controls._unhandled_input(drag)
	check(g.camera.position != p0, "VIEW MAP: the camera pans")
	var z0: float = g.camera.zoom.x
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(400, 300)
	g.controls._unhandled_input(wheel)
	check(not is_equal_approx(g.camera.zoom.x, z0), "VIEW MAP: the wheel zooms")
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
