extends SceneTree
## The Brute's size next to a Raptor, a Musketeer and a Gate in its palisade (the owner, 2026-10-29: drawn 20% bigger):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_brute_size.gd -- /abs/dir [scale:1.0]
## scale: sets the Brute's art_scale (and its radius, 20 x scale) for the picture: scale:1.0 shows the old size.
## Writes dir/size_<scale>.png (the Brute hurt a little, so its health bar shows; selected, so its ring shows).
var main: Node
var g
var out := ""
var sc := -1.0
var t := 0.0
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scale:"):
			sc = float(a.substr(6))
		else:
			out = a
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "brood", "colour": 1, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 0, "side": 1}]})
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


func _run() -> void:
	var o := _open_area(14, 8)
	g.reveal = true
	# a palisade line with a gate in it, behind the row of units
	for i in 7:
		g._add_building("gate" if i == 3 else "wall", 0, o + Vector2i(4 + i, 2), true)
	var row := [["raptor", 0], ["musketeer", 0], ["brute", 0]]     # (one side: nobody fights)
	var brute: Unit = null
	for i in row.size():
		var u: Unit = g._add_unit(String(row[i][0]), int(row[i][1]), g.cell_center(o + Vector2i(5 + i * 2, 5)))
		u.facing = Vector2(1, 1).normalized()
		u.hold_fire = true
		if u.kind == "brute":
			brute = u
			if sc > 0.0:
				var dd: Dictionary = u.d.duplicate(true)
				dd["art_scale"] = sc
				dd["radius"] = int(round(20.0 * sc))
				u.d = dd
				u.radius = dd["radius"]
	brute.hp = brute.max_hp * 0.8
	g.set_selection([brute])
	g.hud.visible = false
	g.camera.zoom = Vector2(3.2, 3.2)
	g.camera.position = g.cell_center(o + Vector2i(7, 4))
	await create_timer(0.6).timeout
	var name := "size_%s.png" % ("%.1f" % float(brute.d.get("art_scale", 1.0)))
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name)
	print("brute radius %d art_scale %s; wrote %s/%s" % [brute.radius, str(brute.d.get("art_scale", 1.0)), out, name])
	quit()
