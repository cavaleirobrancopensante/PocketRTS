extends SceneTree
## Screenshots of the fog of war at a match start (Crown vs Brood on Ashford Crossing): the whole
## map zoomed out, the minimap cut out of it (scaled up), and a Cottage being placed far away on
## ground nobody has looked at yet:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_fog_grey.gd -- /abs/prefix
## writes <prefix>_start.png, <prefix>_minimap.png and <prefix>_ghost.png.
var main


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap() -> Image:
	await create_timer(0.5).timeout
	return root.get_viewport().get_texture().get_image()


func _run() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0]
	await process_frame
	main.start({"map": "ashford_crossing", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	await create_timer(1.5).timeout
	# the whole map in view
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	var z: float = minf(vs.x / float(g.W * Game.T), (vs.y - 120.0) / float(g.H * Game.T))
	g.camera.zoom = Vector2(z, z)
	g.camera.position = Vector2(g.W, g.H) * Game.T * 0.5 + Vector2(0, 30)
	var img: Image = await _snap()
	img.save_png(prefix + "_start.png")
	var m: Rect2 = g.hud.mini_rect().grow(8.0)
	var mini := img.get_region(Rect2i(m))
	mini.resize(mini.get_width() * 2, mini.get_height() * 2, Image.INTERPOLATE_BILINEAR)
	mini.save_png(prefix + "_minimap.png")
	# a Cottage planned far away, where nobody has looked yet
	var me = g.buildings.filter(func(b): return b.team == g.human and b.kind == g.faction_hall(g.human))[0]
	var far := Vector2i(-1, -1)
	var bd := -1.0
	for y in range(6, g.H - 8, 2):
		for x in range(6, g.W - 8, 2):
			var c := Vector2i(x, y)
			if g.explored[g.idx(c)] == 1 or g.placement_problem(g.human, "cottage", c, true) != "":
				continue
			var d := Vector2(c - me.cell).length()
			if d > 30.0 and d < 45.0 and (bd < 0.0 or absf(d - 38.0) < absf(bd - 38.0)):
				bd = d
				far = c
	if far.x >= 0:
		g.camera.zoom = Vector2(1.0, 1.0)
		g.camera.position = g.cell_center(far)
		g.controls.mode = "place"
		g.controls.place_kind = "cottage"
		g.controls.ghost_cell = far
		g.overlay.queue_redraw()
		img = await _snap()
		img.save_png(prefix + "_ghost.png")
	print("shots: %s_start.png %s_minimap.png %s" % [prefix, prefix, "%s_ghost.png" % prefix if far.x >= 0 else "(no far spot)"])
	quit()
