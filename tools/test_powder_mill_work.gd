extends SceneTree
## The Powder Mill's shed and hopper, and the labourer's shovel work:
##   godot --headless --fixed-fps 30 --script res://tools/test_powder_mill_work.gd
##  footprint unchanged (3x3, sprite sizes, a lowest row at the base), the shovel strips exist
##  with 12 frames (3 loads x 4) per view and each load's colour is in its frames, a labourer
##  manning a mill picks the shovel pose (not the hammer), stands at a heap's station, the
##  load follows the heap he is at, he moves on to the next heap, and a farm hand still hoes.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
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
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


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


func _has_colour(im: Image, x0: int, near: Color, tol: float) -> bool:
	for y in 35:
		for x in 42:
			var c := im.get_pixel(x0 + x, y)
			if c.a > 0.0 and absf(c.r - near.r) + absf(c.g - near.g) + absf(c.b - near.b) < tol:
				return true
	return false


func _run() -> void:
	var origin := _open_area(20, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.explored.fill(1)
	# footprint and art
	var sz: Vector2i = Defs.BUILDINGS["powder_mill"]["size"]
	check(sz == Vector2i(3, 3), "the mill's footprint is still 3x3 (%s)" % sz)
	check(ArtData.BUILDING_SIZE["powder_mill"] == Vector2i(124, 113), "the mill's art size is still 124x113")
	for st in ["built", "damaged", "construction", "destroyed"]:
		var t := load("res://assets/buildings/powder_mill_%s.png" % st) as Texture2D
		check(t != null and t.get_height() >= 95 and t.get_width() >= 120 and t.get_width() <= 126, "powder_mill_%s.png exists (%s)" % [st, t.get_size() if t else "missing"])
	# strips
	var fr: Dictionary = ArtData.UNITS["labourer"]["frames"]
	var cols := [Color8(205, 212, 224), Color8(232, 188, 38), Color8(48, 48, 56)]
	for d in ["s", "se", "e", "ne", "n"]:
		var key: String = "shovel_" + d
		var tex := load("res://assets/units/labourer/%s.png" % key) as Texture2D
		check(int(fr.get(key, 0)) == 12 and tex != null and tex.get_width() == 12 * 42 and tex.get_height() == 35, "%s: 12 frames of 42x35" % key)
		if tex == null:
			continue
		var im := tex.get_image()
		var ok := true
		for k in 3:
			ok = ok and _has_colour(im, (k * 4 + 1) * 42, cols[k], 0.12)
		check(ok, "%s: the lifted load is grey-white, yellow, black in turn" % key)
	# a labourer at the mill
	g.players[0]["gold"] = 20000
	var cell := origin + Vector2i(8, 4)
	g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)      # (the mill grinds its hall's saltpetre)
	var m: Building = g._add_building("powder_mill", 0, cell, true)
	check(m.rect().size == Vector2(sz) * Defs.TILE, "the built mill's rect is the 3x3 footprint")
	var u: Unit = g._add_unit("labourer", 0, m.center() + Vector2(0, m.rect().size.y * 0.5 + 24))
	await physics_frame
	u.auto_work = false
	u.cmd_gather(m)
	g.camera.position = m.center()
	var seen := {}
	var ks := {}
	var near_st := false
	var end: float = g.clock + 14.0
	while g.clock < end:
		await physics_frame
		if u.work == "manning":
			seen[u.anim] = true
			if u.anim == "shovel":
				ks[u._mill_k] = true
				if u.position.distance_to(u.mill_station(m, u._mill_k)) < 4.0:
					near_st = true
	check(seen.has("shovel") and not seen.has("build"), "a mill worker shovels, never hammers (%s)" % str(seen.keys()))
	check(near_st, "he stands at a heap's station")
	check(ks.size() >= 3, "he works all three heaps in turn (%s)" % str(ks.keys()))
	check(u.frame_i < 12 and u.sprite.hframes == 12 or u.anim == "walk", "the shovel strip plays its 12 frames")
	check(Unit.mill_step(0.1) == 0 and Unit.mill_step(0.9) == 1 and Unit.mill_step(1.2) == 2 and Unit.mill_step(1.8) == 3, "the shovel steps run dig, lift, swing, tip")
	# a farm hand still hoes
	var fo := _open_area(20, 14)
	var f: Building = g._add_building("farm", 0, fo + Vector2i(2, 2), true)
	var w: Unit = g._add_unit("labourer", 0, f.center() + Vector2(0, f.rect().size.y * 0.5 + 20))
	await physics_frame
	w.auto_work = false
	w.cmd_gather(f)
	g.camera.position = f.center()
	var farm_seen := {}
	end = g.clock + 12.0
	while g.clock < end:
		await physics_frame
		if w.work == "manning":
			farm_seen[w.anim] = true
	check(farm_seen.has("mine") and not farm_seen.has("shovel"), "a farm hand still hoes (%s)" % str(farm_seen.keys()))
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
