extends SceneTree
## Screenshots of ATTACK GROUND along a dragged line (Defs.GROUND) and of the bodies' health bars (Defs.ROT):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_ground_attack.gd -- <outdir>
## Writes drag_preview.png (Ctrl+A, the left button held: the line shared out into each Musketeer's stretch),
## stretches.png (let go: each one's stretch while selected, the shots going in), body_bars.png (bodies close up: fresh,
## an older one, one hit). Small crops of the screen.
var main
var out := "/tmp/shots_ground_attack"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _shot(name: String, crop := Rect2i()) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
	img.save_png(out.path_join(name))
	print("wrote ", out.path_join(name), " ", img.get_size())


func _scr(g: Game, w: Vector2) -> Vector2:
	return g.get_viewport().get_canvas_transform() * w


func _mouse(g: Game, w: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _scr(g, w)
	g.controls._mouse(ev)


func _motion(g: Game, w: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _scr(g, w)
	g.controls._unhandled_input(ev)
	root.get_viewport().warp_mouse(ev.position)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	var c := Vector2i(g.W / 2, g.H / 2)
	var spot: Vector2 = g.cell_center(g.nearest_free(c, 10))
	# a field of the fallen across the line, and 6 Musketeers below it
	var kinds := ["raptor", "musketeer", "raptor", "brute", "musketeer", "raptor", "raptor", "musketeer"]
	for k in kinds.size():
		var u: Unit = g._add_unit(kinds[k], 1 if kinds[k] != "musketeer" else 0, spot + Vector2(-150 + k * 42, (k % 3) * 9 - 9))
		await process_frame
		u.take_damage(99999.0, null)
	var musks: Array = []
	for i in 6:
		musks.append(g._add_unit("musketeer", 0, spot + Vector2(-110 + i * 44, 150)))
	g.camera.position = spot + Vector2(0, 60)
	g.camera.zoom = Vector2(1.6, 1.6)
	await create_timer(2.6).timeout
	g.set_selection(musks)
	await create_timer(0.2).timeout
	# Ctrl+A, the left button held and dragged along the bodies (not let go yet)
	g.controls.begin_bombard()
	var a := spot + Vector2(-170, -4)
	var b := spot + Vector2(175, 4)
	_mouse(g, a, true)
	for k in range(1, 13):
		_motion(g, a.lerp(b, k / 12.0))
	await create_timer(0.4).timeout
	var vs := root.get_viewport().get_visible_rect().size
	var crop := Rect2i(Vector2i(int(vs.x * 0.5) - 330, int(vs.y * 0.5) - 230), Vector2i(660, 380))
	await _shot("drag_preview.png", crop)
	_mouse(g, b, false)
	await create_timer(3.5).timeout
	await _shot("stretches.png", crop)
	g.command_all(musks, "stop")
	# bodies close up: a fresh one, one lying 90 s, one hit hard
	var spot2: Vector2 = spot + Vector2(10, 75)
	var trio: Array = []
	for k in 3:
		var u: Unit = g._add_unit(["musketeer", "musketeer", "brute"][k], 0 if k < 2 else 1, spot2 + Vector2(-46 + k * 46, 0))
		await process_frame
		u.take_damage(99999.0, null)
		trio.append(u)
	await create_timer(2.0).timeout
	trio[1].died_at -= 90.0
	trio[1]._schedule_rot()
	g.hit_body(trio[2], 170.0)
	g.set_selection([])
	g.camera.position = spot2
	g.camera.zoom = Vector2(2.6, 2.6)
	await create_timer(0.5).timeout
	await _shot("body_bars.png", Rect2i(Vector2i(int(vs.x * 0.5) - 200, int(vs.y * 0.5) - 110), Vector2i(400, 180)))
	print("health: ", trio.map(func(u: Unit) -> String: return "%.0f/%.0f" % [u.body_left(), u.body_size()]))
	quit()
