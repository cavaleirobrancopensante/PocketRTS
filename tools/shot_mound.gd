extends SceneTree
## Before / after screenshots of a Brood base with a Clutch Mound spreading swamp:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x1000 --script res://tools/shot_mound.gd -- /tmp/mound_before.png /tmp/mound_after.png
var main


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())


func _spot(g, cap, d: float) -> Vector2i:
	var c0: Vector2 = cap.center() / Defs.TILE
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y - d - 4), int(c0.y + d + 5)):
		for x in range(int(c0.x - d - 4), int(c0.x + d + 5)):
			var cell := Vector2i(x, y)
			if not g.in_map(cell) or not g._footprint_open(cell, Vector2i(2, 2)) or not g.margin_free(cell, Vector2i(2, 2)):
				continue
			if cell.x < c0.x + 5 or cell.y > c0.y + 2 or g.placement_problem(0, "clutch_mound", cell, true) != "":
				continue
			var sc := absf((Vector2(cell) + Vector2(1, 1)).distance_to(c0) - d)
			if sc < bs:
				bs = sc
				best = cell
	return best


func _run(a: Array) -> void:
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "brood", "colour": 0, "side": 0},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	var g = main.game
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if g.hud:
		g.hud.countdown = 0.0
	g.explored.fill(1)
	if g.fog_sprite:
		g.fog_sprite.visible = false
	await create_timer(1.5).timeout
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var cap = g.capital(0)
	var reach0: float = g.swamp_reach[0]
	var spot := _spot(g, cap, reach0 - 2.0)
	var mid: Vector2 = (cap.center() + Vector2(spot) * Defs.TILE) * 0.5
	var vs := root.get_viewport().get_visible_rect().size
	var z := minf(vs.x, vs.y) / (20.0 * float(Defs.TILE))
	for i in 5:
		g.camera.position = mid
		g.camera.zoom = Vector2(z, z)
		await create_timer(0.2).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	g.players[0]["gold"] = 1000
	var m = g._add_building("clutch_mound", 0, spot, true)
	m.hp = m.max_hp
	await create_timer(0.5).timeout
	m.hp = m.max_hp
	for i in 40:
		g.camera.position = mid
		g.camera.zoom = Vector2(z, z)
		await create_timer(0.4).timeout
	print("cam ", g.camera.position, " mid ", mid, " cap ", cap.center(), " spot ", spot, " zoom ", g.camera.zoom, " limits ", g.camera.limit_left, g.camera.limit_top, g.camera.limit_right, g.camera.limit_bottom)
	print("clock ", g.clock, " mound built ", m.built, " swamp_r ", m.swamp_r)
	root.get_viewport().get_texture().get_image().save_png(a[1])
	quit()
