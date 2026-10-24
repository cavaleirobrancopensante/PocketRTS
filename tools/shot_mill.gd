extends SceneTree
## Screenshots of the Powder Mill with three labourers shovelling:
##   xvfb-run -a godot --rendering-driver opengl3 --script res://tools/shot_mill.gd -- <outdir>
## Writes <outdir>/mill.png (zoomed) and mill_<n>.png (a few moments of the work).
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
	origin = _open_area(20, 14)
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.camera.zoom = Vector2(4, 4)
	g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)
	var m: Building = g._add_building("powder_mill", 0, origin + Vector2i(8, 4), true)
	for i in 3:
		var u: Unit = g._add_unit("labourer", 0, m.center() + Vector2(-60 + 30 * i, 80))
		u.auto_work = false
		u.cmd_gather(m)
	g.camera.position = m.center() + Vector2(0, 10)
	await create_timer(5.0).timeout
	for i in 4:
		root.get_viewport().get_texture().get_image().save_png("%s/mill_%d.png" % [out, i])
		await create_timer(0.45).timeout
	quit()
