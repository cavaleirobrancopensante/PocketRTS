extends SceneTree
## Overview pictures for docs/map_sizes.md (docs/shots/map_sizes/): every built-in map, fog lifted, HUD hidden,
## every base site outlined (white: a player's main; otherwise the colour of the player whose main is nearest by
## land; a thicker line on each player's natural).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_map_sizes.gd -- \
##       out:/abs/dir [maps:a,b,...] [players:max]
## <out>/<map>.png (2 players), and <map>_<n>p.png with as many players as the map holds when players:max.
var main: Node
var out := ""
var maps: Array = []
var full := false
var t := 0.0
var busy := false


class Marks extends Node2D:
	var g: Game
	const COLS := [Color(0.35, 0.6, 1.0), Color(1.0, 0.35, 0.3), Color(0.4, 0.95, 0.4), Color(1.0, 0.85, 0.2),
		Color(0.8, 0.4, 1.0), Color(0.3, 0.95, 0.95), Color(1.0, 0.6, 0.2), Color(0.9, 0.9, 0.9)]

	func _draw() -> void:
		var n := g.n_players()
		var dist: Array = []
		for p in n:
			dist.append(ExpansionSpots._steps(g, g.starts[p]))
		var T := float(Game.T)
		for c in g.base_sites:
			var r := Rect2(Vector2(c) * T, Vector2(MapGen.HALL) * T)
			if g.starts.slice(0, n).has(c):
				draw_rect(r.grow(6), Color(0, 0, 0, 0.7), false, 14.0)
				draw_rect(r.grow(6), Color(1, 1, 1), false, 8.0)
				continue
			var bt := 0
			var bd := INF
			for p in n:
				var d := ExpansionSpots._foot_d(g, dist[p], c)
				if d < bd:
					bd = d
					bt = p
			var nat := g.expansions.slice(0, n).has(c)
			var col: Color = COLS[bt % COLS.size()]
			draw_rect(r.grow(4), Color(0, 0, 0, 0.7), false, 16.0 if nat else 11.0)
			draw_rect(r.grow(4), col, false, 10.0 if nat else 6.0)
			draw_rect(r, Color(col, 0.25))


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"maps": maps = Array(kv[1].split(","))
			"players": full = kv[1] == "max"
	if maps.is_empty():
		maps = MapGen.all_ids()
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.expansion_spots = false
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


func _shot(map: String, n: int, name: String) -> void:
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	var slots: Array = []
	for i in n:
		slots.append({"who": "you" if i == 0 else "normal", "faction": ["crown", "clockwork"][i % 2], "colour": i,
			"side": 0 if i < n / 2 else 1, "strategy": "balanced"})
	main.start({"map": map, "seed": 7, "slots": slots})
	await _frames(5)
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	await _frames(10)
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	if g.controls:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	g.reveal = true
	g.refresh_fog()
	g.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(3)
	g.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var mk := Marks.new()
	mk.g = g
	mk.z_index = 100
	g.add_child(mk)
	var size := Vector2(Game.W, Game.H) * Game.T
	var z := minf(vs.x / size.x, vs.y / size.y)
	g.camera.limit_left = -100000
	g.camera.limit_top = -100000
	g.camera.limit_right = 100000
	g.camera.limit_bottom = 100000
	g.camera.zoom = Vector2(z, z)
	g.camera.position = size * 0.5
	g.camera.reset_smoothing()
	await _frames(30)
	var img: Image = root.get_viewport().get_texture().get_image()
	# crop to the map
	var k := Vector2(img.get_size()) / vs          # (the window may be bigger than the visible rect: content scale)
	var px := size * z * k
	var r := Rect2i(Vector2i((Vector2(img.get_size()) - px) * 0.5), Vector2i(px))
	img = img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name, " ", Game.W, "x", Game.H)
	main.game = null
	g.queue_free()
	await _frames(3)


func _run() -> void:
	for map in maps:
		await _shot(map, 2, map)
		if full and MapGen.max_players(map) > 2:
			var n := MapGen.max_players(map)
			await _shot(map, n, "%s_%dp" % [map, n])
	quit(0)
