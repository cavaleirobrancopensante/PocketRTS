extends SceneTree
## The Officers and riders in white coats (tools/recolour_officers.py) in a player's colour, next to
## a Musketeer, standing and walking:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_officer_white.gd -- /abs/out.png [colour]
## colour: Defs.PALETTE index (default 1, Red). Left to right: Musketeer, Officer, Armoured Officer,
## Horseman, Cuirassier; the top row stands, the bottom row walks east.
var main: Node
var g
var out := ""
var colour := 1
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


func _row(o: Vector2i, y: int) -> Array:
	var list := []
	var kinds := [["musketeer", false], ["dismounted", false], ["dismounted", true], ["cuirassier", false], ["cuirassier", true]]
	for i in kinds.size():
		var u: Unit = g._add_unit(String(kinds[i][0]), 0, g.cell_center(o + Vector2i(2 + i * 2, y)))
		if kinds[i][1]:
			u.put_on_armour()
		list.append(u)
	return list


func _run() -> void:
	var o := _open_area(24, 10)
	g.reveal = true
	_row(o, 2)
	var walkers := _row(o, 6)
	await create_timer(0.5).timeout
	for u in walkers:
		u.cmd_move(u.position + Vector2(400, 0))
	g.hud.visible = false
	g.camera.zoom = Vector2(2.6, 2.6)
	g.camera.position = g.cell_center(o + Vector2i(7, 4)) + Vector2(40, 0)
	await create_timer(0.7).timeout
	root.get_viewport().get_texture().get_image().save_png(out)
	print("wrote ", out)
	quit()
