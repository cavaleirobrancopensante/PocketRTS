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
	# the new art (tools/import_mill_chatgpt.py): the three heaps stand under the shed at the
	# stations' columns (white, yellow, black in that order) and the hopper is up at column 72
	var bt := (load("res://assets/buildings/powder_mill_built.png") as Texture2D).get_image()
	var pile_cols := [Color8(205, 212, 224), Color8(232, 188, 38), Color8(48, 52, 60)]
	for k in 3:
		var px := 62 + int(Unit.MILL_PILE_DX[k])
		var hit := 0
		for y in range(78, 94):
			for x in range(px - 4, px + 5):
				var c := bt.get_pixel(x, y)
				if c.a > 0.0 and absf(c.r - pile_cols[k].r) + absf(c.g - pile_cols[k].g) + absf(c.b - pile_cols[k].b) < (0.45 if k < 2 else 0.2):
					hit += 1
		check(hit >= 12, "heap %d is in the art at its station column %d (%d px of its colour)" % [k, px, hit])
	var wood := 0
	for y in range(60, 70):
		for x in range(64, 82):
			var c := bt.get_pixel(x, y)
			if c.a > 0.0 and c.r > c.b + 0.12 and c.r < 0.75:
				wood += 1
	check(wood >= 40, "the hopper's timber rim is in the art at column 72, row 65 (%d px)" % wood)
	var dm := (load("res://assets/buildings/powder_mill_damaged.png") as Texture2D).get_image()
	check(dm.get_width() == 125 and dm.get_height() == 113 and bt.get_width() == 124 and bt.get_height() == 113, "built is 124x113, damaged 125x113")
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
	# the work yard (Building.MILL_YARD, the footprint's front row): walkable, the shed solid,
	# nothing built on it, every place and lane inside it with a man's room to stand
	var yard_ok := true
	var shed_ok := true
	for y in sz.y:
		for x in sz.x:
			var v: int = g.solid[g.idx(cell + Vector2i(x, y))]
			if Building.MILL_YARD.has_point(Vector2i(x, y)):
				yard_ok = yard_ok and v == 5
			else:
				shed_ok = shed_ok and v == 2
	check(yard_ok and shed_ok, "the yard (front row) is walkable, the shed and hopper behind it solid")
	var yc := cell + Building.MILL_YARD.position
	var blocked: bool = g.placement_problem(0, "cottage", yc + Vector2i(1, 0), true, true) != "" \
		and g.placement_problem(0, "cottage", yc + Vector2i(0, 0), true, true) != "" \
		and g.placement_problem(0, "wall", yc + Vector2i(1, 0), true, true) != "" \
		and g.placement_problem(0, "wall", yc + Vector2i(0, 1), true, true) == ""
	check(blocked, "nothing can be built on the yard (a Cottage or a wall piece over it is refused; beside it is fine)")
	var lab_r := float(Defs.UNITS["labourer"]["radius"])
	var room := Rect2(Vector2(-48.0, -32.0), Vector2(96.0, 32.0)).grow_individual(-lab_r * 0.6 - 0.1, -lab_r * 0.36 - 0.1, -lab_r * 0.6 - 0.1, -lab_r * 0.36 - 0.1)
	var places_in := true
	for pl in Unit.MILL_DIG_AT + Unit.MILL_TIP_AT:
		for p in pl:
			places_in = places_in and room.has_point(p)
	for ly in [Unit.MILL_LANE_OUT, Unit.MILL_LANE_BACK]:
		places_in = places_in and room.has_point(Vector2(0.0, ly))
	check(places_in, "every heap and hopper place and both lanes lie inside the yard, a man's room from its edges (neighbours, walls and cliffs can't block them)")
	check(m.sprite.global_position.y < m.rect().end.y - 32.0 and m.sprite.global_position.y > m.rect().position.y,
		"the mill's body sorts behind its yard (a man working there is drawn over the shed, heaps and hopper; one behind the mill under it)")
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
