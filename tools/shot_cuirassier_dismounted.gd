extends SceneTree
## The dismounted Cuirassier's new art in a match (tools/import_cuirassier_dismounted.py):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_cuirassier_dismounted.gd -- /abs/dir
## Top row facing south-east: Musketeer, Armoured Officer (dismounted Cuirassier), Cuirassier. Middle row: eight Armoured
## Officers facing s, se, e, ne, n, nw, w, sw. Bottom: an Armoured Officer shooting his pistol at a Raptor to the south-east. Writes
## dir/ingame.png, and dir/shot_<i>.png over the shot (prints each one's animation and frame, to check that the
## flash frame shows when the ball leaves).
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 1, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 0, "side": 1}]})
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
	var kinds := [["musketeer", false], ["dismounted", true], ["cuirassier", true]]
	for i in kinds.size():
		var u: Unit = g._add_unit(String(kinds[i][0]), 0, g.cell_center(o + Vector2i(2 + i * 2, y)))
		if kinds[i][1]:
			u.put_on_armour()
		u.facing = Vector2(1, 1).normalized()
		u.hold_fire = true
		list.append(u)
	return list


func _run() -> void:
	var o := _open_area(14, 12)
	g.reveal = true
	_row(o, 1)
	# the eight directions, standing: s, se, e, ne, n, nw, w, sw (the west ones are the east strips mirrored)
	for i in 8:
		var u: Unit = g._add_unit("dismounted", 0, g.cell_center(o + Vector2i(i + 1, 4)))
		u.put_on_armour()
		u.facing = Vector2.DOWN.rotated(-TAU * i / 8.0)
		u.hold_fire = true
	var shooter: Unit = g._add_unit("dismounted", 0, g.cell_center(o + Vector2i(3, 8)))
	shooter.put_on_armour()
	shooter.facing = Vector2(1, 1).normalized()
	g.hud.visible = false
	g.camera.zoom = Vector2(3.0, 3.0)
	g.camera.position = g.cell_center(o + Vector2i(5, 5))
	await create_timer(0.45).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/ingame.png")
	var foe: Unit = g._add_unit("raptor", 1, shooter.position + Vector2(60, 60))
	foe.hold_fire = true
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	shooter.pistol = true
	shooter.cmd_attack(foe)
	var shots := 0
	var last := ""
	for i in 90:
		await process_frame
		var key: String = "%s_%s %d" % [shooter.anim, shooter.anim_dir, shooter.frame_i]
		if shooter.anim in ["aim", "fire"] and key != last and shots < 10:
			# (one picture for each frame of the strips shown; the pistol's charge goes when the ball leaves)
			last = key
			print("tick %d: %s, phase %s, pistol loaded %s" % [i, key, shooter.phase, shooter.pistol])
			root.get_viewport().get_texture().get_image().save_png(out + "/shot_%d.png" % shots)
			shots += 1
	print("wrote ", out)
	quit()
