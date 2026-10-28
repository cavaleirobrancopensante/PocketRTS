extends SceneTree
## Does the new Brood's Mother, grown, still fit her start spot? On every built-in map, at every start (2 players and as
## many as the map holds): her body (radius x her stage's scale) must stand on walkable ground of the start's level, and
## her nest's ground (an ellipse round her feet, the rooted picture's base: STAGE 1 about 176 x 62 px, scaled) is
## measured for how much of it lies off that level (a cliff, water, the map's edge). Prints a line per map and stage.
##   godot --headless --script res://tools/check_mother_fit.gd [-- ids...]

const NEST := Vector2(176.0, 62.0)       # half-width, half-height of the rooted nest's ground at stage 1 (px)
const NEST_UP := 40.0                    # its middle this far above her feet


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String, n: int) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = true
	var facs: Array = []
	var sides: Array = []
	for i in n:
		facs.append("brood")
		sides.append(0 if i < n / 2 else 1)
	g.factions = facs
	g.sides = sides
	root.add_child(g)
	return g


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	var worst := 0.0
	var bad := 0
	for id in ids:
		var counts := [2]
		if MapGen.max_players(id) > 2:
			counts.append(MapGen.max_players(id))
		for n in counts:
			var g := _make(id, n)
			await process_frame
			await process_frame
			var line := "%-18s %d players:" % [id, n]
			for st in (Defs.NB["stages"] as Array).size():
				var k := float(Defs.NB["stages"][st]["scale"])
				var body_bad := 0
				var off_max := 0.0
				for t in n:
					var hall: Building = g._own_hall(t)
					if hall == null:
						continue
					var size: Vector2i = Defs.BUILDINGS["hive"]["size"]
					var c: Vector2 = (Vector2(hall.cell) + Vector2(size) * 0.5) * Defs.TILE
					var h0 := int(g.height[g.idx(g.cell_of(c))])
					var hr := Rect2i(Vector2i(hall.cell), size)      # (the old hall the test map put there: the Mother stands there instead)
					var r := float(Defs.UNITS["brood_mother"]["radius"]) * k
					# her body
					for dy in range(-int(r), int(r) + 1, 8):
						for dx in range(-int(r), int(r) + 1, 8):
							if Vector2(dx, dy).length() > r:
								continue
							var cc := g.cell_of(c + Vector2(dx, dy))
							if not g.in_map(cc) or (not hr.has_point(cc) and not g._walkable(cc)) or int(g.height[g.idx(cc)]) != h0:
								body_bad += 1
					# her nest's ground
					var ax := NEST * k
					var mid := c + Vector2(0, -NEST_UP * k)
					var tot := 0
					var off := 0
					for dy in range(-int(ax.y), int(ax.y) + 1, 8):
						for dx in range(-int(ax.x), int(ax.x) + 1, 8):
							if pow(dx / ax.x, 2) + pow(dy / ax.y, 2) > 1.0:
								continue
							tot += 1
							var cc := g.cell_of(mid + Vector2(dx, dy))
							if not g.in_map(cc) or int(g.height[g.idx(cc)]) != h0 or (not hr.has_point(cc) and not g._walkable(cc)):
								off += 1
					off_max = maxf(off_max, float(off) / maxf(1.0, tot))
				line += "  stage %d: body %s, nest off its ground %d%%" % [st + 1, "ok" if body_bad == 0 else "%d points OFF" % body_bad, int(off_max * 100.0)]
				if st == 2:
					worst = maxf(worst, off_max)
					if body_bad > 0:
						bad += 1
			print(line)
			g.queue_free()
			await process_frame
	print("stage 3: %d starts where her body does not fit; the most of her nest off its ground: %d%%" % [bad, int(worst * 100.0)])
	quit(1 if bad > 0 else 0)
