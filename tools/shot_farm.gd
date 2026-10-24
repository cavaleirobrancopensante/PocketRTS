extends SceneTree
## Screenshots of the Farm (before/after the square footprint):
##   xvfb-run -a godot --rendering-driver opengl3 --script res://tools/shot_farm.gd -- <outdir>
## Writes <outdir>/<name>_<n>.png (the screen around each building, zoomed); tools/strip.py cuts and joins them.
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _run() -> void:
	origin = _open_area(32, 14)
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.camera.zoom = Vector2(2.5, 2.5)
	var f: Building = g._add_building("farm", 0, origin + Vector2i(2, 2), true)
	f.growth = 0.6
	var us: Array = []
	for i in 8:
		var u: Unit = g._add_unit("labourer", 0, f.center() + Vector2(0, 150))
		u.cmd_gather(f)
		us.append(u)
	# a second farm with a ghost-free neighbour: the ground between them
	var f2: Building = g._add_building("farm", 0, origin + Vector2i(10, 2), true)
	f2.growth = 0.3
	g.camera.position = f.center() + Vector2(100, 10)
	await create_timer(6.0).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/farm.png" % out)
	g.camera.zoom = Vector2(1.5, 1.5)
	g.camera.position = f.center() + Vector2(100, 10)
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/farm_wide.png" % out)
	print("farm rect ", f.rect(), " center ", f.center())
	quit()
