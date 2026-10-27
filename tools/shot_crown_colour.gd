extends SceneTree
## A Crown base in a player's colour, to look at the buildings' team colours (the flags, banners,
## awnings and cloth: tools/recolour_crown_buildings.py; the Farm's terracotta roof):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_crown_colour.gd -- /abs/out.png [colour]
## colour: Defs.PALETTE index (default 4, Purple). Writes out.png (the whole base), out_close.png
## (closer) and out_ghost.png (the HUD on with the Armoury selected, another Armoury being placed).
var main: Node
var g
var out := ""
var colour := 4
var t := 0.0
var started := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	if args.size() > 1:
		colour = int(args[1])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": colour, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 0 if colour == 1 else 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
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


func _shot(path: String) -> void:
	await create_timer(1.0).timeout   # ~30 frames at --fixed-fps 30 after the camera moved
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote ", path)


func _run() -> void:
	var o := _open_area(31, 17)
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	var th: Building = g._add_building("town_hall", 0, o + Vector2i(1, 1), true)
	var br: Building = g._add_building("barracks", 0, o + Vector2i(8, 2), true)
	g._add_building("foundry", 0, o + Vector2i(14, 2), true)
	var ar: Building = g._add_building("armoury", 0, o + Vector2i(20, 2), true)
	g._add_building("church", 0, o + Vector2i(26, 2), true)
	g._add_building("farm", 0, o + Vector2i(1, 8), true)
	g._add_building("powder_mill", 0, o + Vector2i(9, 9), true)
	var hb: Building = g._add_building("horse_breeder", 0, o + Vector2i(14, 9), true)
	g._add_building("cottage", 0, o + Vector2i(20, 9), true)
	g._add_building("cottage", 0, o + Vector2i(23, 9), true)
	for x in range(19, 31):
		g._add_building("gate" if x == 24 else "wall", 0, o + Vector2i(x, 14), true)
	for i in 3:
		g._add_unit("musketeer", 0, g.cell_center(o + Vector2i(10 + i, 7)))
	g.train(th, "labourer")
	g.train(br, "musketeer")
	g.train(hb, "horse")
	ar.add_entry("@flintlock")
	await create_timer(2.0).timeout
	g.hud.visible = false
	var mid: Vector2 = (g.cell_center(o) + g.cell_center(o + Vector2i(31, 15))) * 0.5
	g.camera.zoom = Vector2(1.25, 1.25)
	g.camera.position = mid
	await _shot(out)
	g.camera.zoom = Vector2(2.4, 2.4)
	g.camera.position = g.cell_center(o + Vector2i(13, 6))
	await _shot(out.get_basename() + "_close.png")
	# the HUD with the Armoury selected, and an Armoury being placed (the ghost in the side's colour)
	g.hud.visible = true
	g.camera.zoom = Vector2(1.8, 1.8)
	g.camera.position = g.cell_center(o + Vector2i(22, 8))
	g.selection = [ar]
	g.controls.begin_place("armoury")
	g.controls.ghost_cell = o + Vector2i(26, 9)
	await _shot(out.get_basename() + "_ghost.png")
	quit()
