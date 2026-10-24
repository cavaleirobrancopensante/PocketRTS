extends SceneTree
## The Farm is a true square (6x6 tiles) with no fence along its bottom:
##   godot --headless --fixed-fps 30 --script res://tools/test_farm_square.gd
##  footprint square, field art the same size, no fence pixels along the bottom of the field
##  art, the windmill's block and body centred on it, scarecrow spots, crew work stretches
##  and sails inside it, placement works on open ground, and a labourer farms it.
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


func _run() -> void:
	origin = _open_area(20, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.explored.fill(1)
	g.players[0]["gold"] = 20000
	var sz: Vector2i = Defs.BUILDINGS["farm"]["size"]
	check(sz.x == sz.y and sz.x == 6, "the farm's footprint is a 6x6 square (%s)" % sz)
	var px := Vector2(sz) * Defs.TILE
	var blk: Rect2i = Building.FARM_BLOCK
	check(blk.position.x * 2 + blk.size.x == sz.x and blk.position.y * 2 + blk.size.y == sz.y, "the windmill's block %s is centred on the footprint" % blk)
	for stage in ["bare", "young", "ripe"]:
		var t: Texture2D = Game.tex("res://assets/buildings/farm_field_%s.png" % stage)
		check(Vector2(t.get_size()) == px, "field art '%s' is %s px = the footprint" % [stage, t.get_size()])
	# no fence along the bottom of the field art: none of the fence colours in its last 14 rows
	var fence := [Color8(124, 80, 36), Color8(166, 116, 60), Color8(88, 54, 24), Color8(150, 102, 52), Color8(40, 26, 14)]
	var im: Image = (Game.tex("res://assets/buildings/farm_field_ripe.png") as Texture2D).get_image()
	var bad := 0
	for y in range(im.get_height() - 14, im.get_height()):
		for x in range(8, im.get_width() - 8):
			var c := im.get_pixel(x, y)
			for f in fence:
				if c.is_equal_approx(f):
					bad += 1
	check(bad == 0, "no fence pixels along the bottom of the field art (%d found)" % bad)
	# the windmill body's pixels centred sideways on the footprint, inside it
	var body: Image = Building.farm_body("built").get_image()
	var used := body.get_used_rect()
	var anc: Vector2 = Building.anchor("farm", Rect2(Vector2.ZERO, px))
	var left := anc.x + used.position.x - Vector2(Building.FARM_ART["anchor"]).x
	var right := anc.x + used.end.x - Vector2(Building.FARM_ART["anchor"]).x
	check(absf((left + right) * 0.5 - px.x * 0.5) <= 4.0, "the windmill body is centred sideways (%.1f..%.1f of %.0f)" % [left, right, px.x])
	var top := anc.y + used.position.y - Vector2(Building.FARM_ART["anchor"]).y
	var bottom := anc.y + used.end.y - Vector2(Building.FARM_ART["anchor"]).y
	check(top >= 0.0 and bottom <= px.y and left >= 0.0 and right <= px.x, "the windmill body lies inside the footprint (y %.0f..%.0f)" % [top, bottom])
	check(anc.y <= (blk.position.y + blk.size.y) * Defs.TILE and anc.y >= blk.position.y * Defs.TILE, "its door foot stands on the block")
	# scarecrow spots and work stretches inside the footprint and off the block
	var brect := Rect2(Vector2(blk.position) * Defs.TILE, Vector2(blk.size) * Defs.TILE)
	var all_in := true
	for p: Vector2 in Building.FARM_SCARECROW_SPOTS:
		if not Rect2(Vector2.ZERO, px).has_point(p) or brect.has_point(p):
			all_in = false
	check(all_in, "every scarecrow spot is inside the footprint and off the windmill block")
	all_in = true
	for i in 8:
		var seg: Array = Building.row_stretch(Rect2(Vector2.ZERO, px), i)
		for p: Vector2 in seg:
			if not Rect2(Vector2.ZERO, px).has_point(p) or brect.grow(4.0).has_point(p):
				all_in = false
	check(all_in, "all 8 crew stretches are inside the footprint and clear of the block")
	var st: Texture2D = Game.tex(Building.FARM_ART["sails"])
	var fw: float = st.get_width() / int(Building.FARM_ART["sail_frames"])
	var hub: Vector2 = anc + Vector2(Building.FARM_ART["hub"])
	check(hub.x - fw * 0.4 >= 0.0 and hub.x + fw * 0.4 <= px.x and hub.y - fw * 0.4 >= -20.0, "the sails turn over the footprint")
	# placement on open ground, and the cells beyond the footprint stay free
	var cell := origin + Vector2i(2, 2)
	g._add_building("town_hall", 0, origin + Vector2i(10, 8), true)
	check(g.placement_problem(0, "farm", cell) == "", "a farm can be placed on open ground: '%s'" % g.placement_problem(0, "farm", cell))
	var f: Building = g._add_building("farm", 0, cell, true)
	check(f.rect().size == px, "the built farm's rect is %s" % f.rect().size)
	var walk_ok := true
	var solid_n := 0
	for y in sz.y:
		for x in sz.x:
			var c := cell + Vector2i(x, y)
			var s: int = g.solid[g.idx(c)]
			if blk.has_point(Vector2i(x, y)):
				if s != 2:
					walk_ok = false
				solid_n += 1
			elif s != 5:
				walk_ok = false
	check(walk_ok and solid_n == 8, "only the windmill block is solid; the other %d cells are walkable field" % (sz.x * sz.y - 8))
	var below := cell + Vector2i(0, sz.y)
	check(g.solid[g.idx(below)] == 0 and g.solid[g.idx(cell + Vector2i(sz.x, 0))] == 0, "the ground just outside the footprint is untouched")
	var hits := 0
	for c in field_sprites(f):
		hits += 1
	check(hits >= 1, "the field sprite exists")
	check(f.field != null and Vector2(f.field.texture.get_size()) == px, "the farm draws a square field")
	# a second farm right beside it needs a gap only where the footprints overlap
	check(g.placement_problem(0, "farm", cell + Vector2i(sz.x - 1, 0)) != "", "overlapping a farm is refused")
	# workers can farm it
	f.growth = 0.0
	var us: Array = []
	for i in 3:
		us.append(await _labourer(f))
	await wait(14.0)
	var inside := 0
	for u: Unit in us:
		if f.rect().grow(8.0).has_point(u.position):
			inside += 1
	check(f.working_crew() >= 2, "labourers work the farm (crew %d)" % f.working_crew())
	check(inside == 3, "all 3 labourers are inside the footprint (%d)" % inside)
	check(f.growth > 0.1 or g.players[0]["gold"] > 20000, "the farm grows while worked (%.2f)" % f.growth)
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func field_sprites(f: Building) -> Array:
	return [f.field] if f.field else []


func _labourer(b: Building) -> Unit:
	var u: Unit = g._add_unit("labourer", 0, b.center() + Vector2(0, b.rect().size.y * 0.5 + 20))
	await physics_frame
	u.auto_work = false
	u.cmd_gather(b)
	return u
