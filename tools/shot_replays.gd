extends SceneTree
## Screenshots of the replays (docs/shots/replays/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_replays.gd -- <outdir>
## Records a short match between two computers at high speed (unless a replay of 3 minutes or more is already there),
## then writes menu.png (the REPLAYS page), viewer.png (the viewer with its bar and timeline, a unit selected),
## fog.png (one player's fog) and end.png (the end screen's "Replay saved" and WATCH REPLAY), each at 960 px wide.
var main
var out := "/tmp/shots_replays"


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


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.resize(960, int(960.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out.path_join(name))
	print("wrote ", out.path_join(name))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	# a match to watch: two computers, three minutes at 8x
	main.start({"map": "hollowfen", "seed": 777, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "rush"},
		{"who": "hard", "faction": "brood", "colour": 3, "side": 1, "strategy": "rush"}]})
	await process_frame
	var g: Game = main.game
	Engine.time_scale = 8.0
	while g.clock < 330.0 and not g.over:
		await process_frame
	Engine.time_scale = 1.0
	g.rec.finish(g.winner if g.over else -1)
	# the end screen, as after a match
	g.over = true
	main._on_end(-1)
	await create_timer(1.6).timeout
	await _shot("end.png")
	main._to_menu()
	await process_frame
	main.show_replays()
	await create_timer(0.5).timeout
	await _shot("menu.png")
	var newest: Dictionary = ReplayFile.list()[0]
	main.start_replay(String(newest["path"]))
	await create_timer(0.5).timeout
	g = main.game
	var rp: ReplayPlayer = g.replay
	rp.seek(rp.length * 0.7)
	await create_timer(0.6).timeout
	# the camera on the busiest place, a soldier selected (its card)
	var best: Unit = null
	var best_n := -1
	for u in g.units:
		if u.is_worker() or u.kind == "horse":
			continue
		var n := 0
		for o in g.units:
			if o.position.distance_to(u.position) < 300.0:
				n += 1
		if n > best_n:
			best_n = n
			best = u
	if best == null and not g.units.is_empty():
		best = g.units[0]
	if best:
		g.camera.position = best.position
		g.camera.zoom = Vector2(1.1, 1.1)
		g.set_selection([best])
	await create_timer(1.0).timeout
	await _shot("viewer.png")
	g.spectator.set_mode("free", 0)
	g.set_selection([])
	var h0: Vector2 = g.cell_center(g.starts[0])
	var h1: Vector2 = g.cell_center(g.starts[1])
	g.camera.position = h0.lerp(h1, 0.62)       # (from the edge of P1's sight into the fog toward P2)
	g.camera.zoom = Vector2(0.55, 0.55)
	await create_timer(1.0).timeout
	await _shot("fog.png")
	main._to_replays()
	await process_frame
	quit(0)
