extends SceneTree
## Pictures of the EXPANSION SPOTS (docs/expansion_spots.md) for docs/shots/expansion_spots/:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_expansion_spots.gd -- \
##       out:/abs/dir [maps:a,b,...] [close:1]
## <out>/<map>.png: the whole map, fog lifted, HUD hidden (a Crown player against a Clockwork computer);
## close:1 also <out>/close_crown_<map>.png, close_clockwork_<map>.png (the player's natural, HUD and minimap on) and
## place_crown_<map>.png / place_clockwork_<map>.png (placing a hall: the spots a touch brighter).
var main: Node
var out := ""
var maps: Array = []
var close := false
var t := 0.0
var busy := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"maps": maps = Array(kv[1].split(","))
			"close": close = kv[1] == "1"
	if maps.is_empty():
		maps = MapGen.all_ids()
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.expansion_spots = true
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.3 and not busy:
		busy = true
		_run()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start(map: String, me: String, foe: String) -> Game:
	var slots: Array = [{"who": "you", "faction": me, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "normal", "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]
	main.start({"map": map, "seed": 7, "slots": slots})
	await _frames(5)
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	await _frames(20)
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.camera.process_mode = Node.PROCESS_MODE_ALWAYS      # (the camera follows its position only while it processes)
	if g.controls:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	return g


func _end() -> void:
	var g: Game = main.game
	main.game = null
	g.queue_free()
	await _frames(3)


func _snap(name: String) -> void:
	await _frames(30)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _ui(g: Game, on: bool) -> void:
	if g.hud:
		g.hud.visible = on
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _run() -> void:
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	for map in maps:
		var g := await _start(map, "crown", "clockwork")
		g.reveal = true
		g.refresh_fog()
		g.process_mode = Node.PROCESS_MODE_INHERIT
		await _frames(3)
		g.process_mode = Node.PROCESS_MODE_DISABLED
		_ui(g, false)
		var size := Vector2(Game.W, Game.H) * Game.T
		var z := minf(vs.x / size.x, vs.y / size.y) * 0.98
		g.camera.limit_left = -100000
		g.camera.limit_top = -100000
		g.camera.limit_right = 100000
		g.camera.limit_bottom = 100000
		g.camera.zoom = Vector2(z, z)
		g.camera.position = size * 0.5
		g.camera.reset_smoothing()
		await _snap(map)
		await _end()
		if not close:
			continue
		for fac in ["crown", "clockwork"]:
			var g2 := await _start(map, fac, "crown" if fac == "clockwork" else "clockwork")
			_ui(g2, true)
			var nat := Vector2i(-1, -1)
			for s in g2.exp_spots.spots:
				if int(s["team"]) == g2.human and int(s["rank"]) == 1:
					nat = s["c"]
			var home := g2.cell_center(g2.starts[g2.human])
			var spot := (Vector2(nat) + Vector2(MapGen.HALL) * 0.5) * Game.T if nat.x >= 0 else home
			g2.camera.zoom = Vector2(0.75, 0.75)
			g2.camera.position = home.lerp(spot, 0.8)
			g2.camera.reset_smoothing()
			await _snap("close_%s_%s" % [fac, map])
			g2.controls.begin_place(g2.faction_hall(g2.human))
			g2.exp_spots._placing = true
			g2.exp_spots._key = "-"
			g2.exp_spots.refresh()
			await _snap("place_%s_%s" % [fac, map])
			await _end()
	quit(0)
