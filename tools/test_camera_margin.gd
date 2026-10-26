extends SceneTree
## The camera may scroll Defs.CAMERA_MARGIN_TILES past every map edge, and no further; orders
## given out there land on the real map.
##   godot --headless --fixed-fps 30 --script res://tools/test_camera_margin.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := g.camera
	var m := float(Defs.CAMERA_MARGIN_TILES * Game.T)
	var mw := float(Game.W * Game.T)
	var mh := float(Game.H * Game.T)
	cam.zoom = Vector2.ONE
	var half := g.get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	# far past the top-left corner: stops with the view's corner at the margin
	cam.position = Vector2(-100000, -100000)
	g.controls._clamp_camera()
	var tl := cam.position - half
	check(is_equal_approx(tl.x, -m), "left edge of the view reaches -%d px (%.0f)" % [m, tl.x])
	check(tl.y <= -m and tl.y >= -m - 40.0 - 0.5, "top edge of the view reaches the margin (%.0f)" % tl.y)
	# far past the bottom-right corner
	cam.position = Vector2(100000, 100000)
	g.controls._clamp_camera()
	var br := cam.position + half
	check(is_equal_approx(br.x, mw + m), "right edge of the view reaches map + %d px (%.0f)" % [m, br.x])
	check(br.y >= mh + m and br.y <= mh + m + 170.0 + 0.5, "bottom edge of the view reaches the margin (%.0f)" % br.y)
	# the margin is small now (owner: 7 tiles, not 25): a corner can't be centred any more, the view just shows a
	# strip of dark past the edge; a point the margin's width inside the edge can still be brought to the view's middle
	cam.position = Vector2.ZERO
	g.controls._clamp_camera()
	check(cam.position.x - half.x <= -m + 0.5 and cam.position.x > 0.0, "at the top-left corner the view stops %d px past the edge (%s)" % [m, cam.position])
	# zoomed out: still clamped to the bigger rectangle
	cam.zoom = Vector2(0.55, 0.55)
	half = g.get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	cam.position = Vector2(-100000, 0)
	g.controls._clamp_camera()
	check(cam.position.x - half.x >= -m - 0.5, "zoomed out the view stops at the margin (%.0f)" % (cam.position.x - half.x))
	# orders past the edge land on the map
	var p := g.on_map(Vector2(-500, mh + 600))
	check(p.x > 0 and p.x < mw and p.y > 0 and p.y < mh, "a point past the edge is pulled onto the map (%s)" % p)
	var u: Unit = g._add_unit("musketeer", 0, Vector2(80, mh * 0.5))
	g.group_move([u], Vector2(-600, mh * 0.5), false)
	check(u.order_point.x >= 0.0, "a move ordered past the edge stays on the map (%.0f)" % u.order_point.x)
	print("camera margin: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
