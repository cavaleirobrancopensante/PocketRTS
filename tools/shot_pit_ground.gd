extends SceneTree
## Screenshots of the Brood's pit ground circles (docs/brood_pit_ground.md):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_pit_ground.gd -- <out dir> [map]
## Writes <out dir>/place_free.png (placing a pit on a free spot), place_refused.png (a spot whose circle
## overlaps a pit of yours) and selected.png (a selected pit with its circle and its ground), 960 x 540.
var main


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())


func _snap(path: String) -> void:
	await create_timer(0.7).timeout
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("saved ", path)


func _spot(g, from: Vector2, d0: float, d1: float, want_ok: bool) -> Vector2i:
	var c0: Vector2 = from / Defs.TILE
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y - d1 - 3), int(c0.y + d1 + 3)):
		for x in range(int(c0.x - d1 - 3), int(c0.x + d1 + 3)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell):
				continue
			var dd: float = g.pit_mid(cell).distance_to(from) / Defs.TILE
			if dd < d0 or dd > d1:
				continue
			var why: String = g.placement_problem(g.human, "feeding_pit", cell, true)
			var ok: bool = why == "" and g.margin_free(cell, Vector2i(3, 3))
			if want_ok != ok:
				continue
			if not want_ok and not why.begins_with("Too close"):
				continue
			if dd < bs:
				bs = dd
				best = cell
	return best


func _run(a: Array) -> void:
	await process_frame
	var out: String = a[0] if a.size() > 0 else "/tmp"
	var map: String = a[1] if a.size() > 1 else "greenhold"
	Settings.device = "pc"
	main.start({"map": map, "seed": 5, "slots": [
		{"who": "human", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.countdown = 0.0
	Engine.time_scale = 8.0
	await create_timer(40.0 / 8.0, true, false, true).timeout
	Engine.time_scale = 1.0
	var cap = g.capital(g.human)
	var start = g.buildings.filter(func(b): return b.team == g.human and b.kind == "feeding_pit")[0]
	start.soil = 2150.0
	# a second pit, and two that fell (one spent, one with ground left): old ground
	var c2: Vector2i = _spot(g, start.center(), 10.0, 12.0, true)
	var p2 = g._add_building("feeding_pit", g.human, c2, true)
	p2.soil = 900.0
	var c3: Vector2i = _spot(g, cap.center(), 9.0, 14.0, true)
	var p3 = g._add_building("feeding_pit", g.human, c3, true)
	p3.soil = 0.0
	p3.hp = 0.0
	p3.die()
	await create_timer(0.2).timeout
	for b in [start, p2]:
		b._update_sprite()
	var mid: Vector2 = (start.center() + p2.center() + cap.center()) / 3.0
	g.camera.position = mid
	g.camera.zoom = Vector2(1.15, 1.15)
	g.selection.clear()
	# 1. placing on a free spot
	g.controls.begin_place("feeding_pit")
	var free: Vector2i = _spot(g, mid, 6.0, 16.0, true)
	g.controls.ghost_cell = free
	g.camera.position = (g.pit_mid(free) + start.center() + p2.center()) / 3.0 + Vector2(0, 60)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap(out + "/place_free.png")
	# 2. a refused spot (its circle overlaps the second pit's)
	var bad: Vector2i = _spot(g, p2.center(), 5.0, 8.0, false)
	g.controls.ghost_cell = bad
	await _snap(out + "/place_refused.png")
	print("refused: ", g.placement_problem(g.human, "feeding_pit", bad))
	# 3. a selected pit
	g.controls.cancel_mode()
	g.selection.clear()
	g.selection.append(start)
	if g.hud:
		g.hud.queue_redraw()
	g.camera.position = start.center() + Vector2(0, 40)
	await _snap(out + "/selected.png")
	quit()
