extends SceneTree
## ROOTMAW FIT (brood-tune, 2026-10-30; docs/brood_new.md "Rootmaw ground"). On every built-in map, how many rooted
## Rootmaws fit (their middles APART tiles from each other, greedy, the outer ring first) on the Brood Mother's swamp at
## each start (stage 1; her starting Rootmaw counted) and round a Mound Turtle on each expansion site
## (ExpansionSpots.nb_rate's turtle spot, its swamp less 1.5 tiles), for several spacings.
##   godot --headless --fixed-fps 30 --script res://tools/study_rootmaw_fit.gd [-- ids...]
## Prints one line a map: the least / most per start and per turtle site, for each spacing.

const APARTS := [10.0, 15.0, 20.0, 30.0]


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _greedy(cands: Array, apart: float, got: Array) -> int:
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	for c in cands:
		var p: Vector2 = c[0]
		if got.all(func(o: Vector2) -> bool: return o.distance_to(p) >= apart * Defs.TILE - 0.5):
			got.append(p)
	return got.size()


func _mother(g: Game, t: int, apart: float) -> int:
	var q := BroodNew.queen(g, t)
	if q == null:
		return -1
	var got: Array = []
	var cands: Array = []
	for u in g.units:
		if u.team == t and u.kind == BroodNew.MAW and not u.dead:
			got.append(u.position)
	# (her swamp, stage 1, as a circle: at the start of a match it is not spread yet) and the ROOT footprint rules
	var sw := float(Defs.NB["stages"][0]["swamp"])
	var qrect := BroodRoot.rect_for(BroodNew.QUEEN, q.position, 1.0).grow(Defs.TILE)
	var lv := int(g.height[g.idx(g.cell_of(q.position))])
	var ms: Vector2i = BroodRoot.fp(BroodNew.MAW)[0]
	var qc := g.cell_of(q.position)
	for dy in range(-16, 17):
		for dx in range(-16, 17):
			var p := BroodRoot.snap(BroodNew.MAW, (Vector2(qc + Vector2i(dx, dy)) + Vector2(0.5, 0.5)) * Defs.TILE)
			if p.distance_to(q.position) > sw * Defs.TILE:
				continue
			var mc := BroodRoot.cell_for(BroodNew.MAW, p, 1.0)
			if not ExpansionSpots._ground_ok(g, mc, ms) or int(g.height[g.idx(mc)]) != lv:
				continue
			if Rect2(Vector2(mc) * Defs.TILE, Vector2(ms) * Defs.TILE).intersects(qrect):
				continue
			cands.append([p, p.distance_to(q.position)])
	return _greedy(cands, apart, got)


func _turtle(g: Game, s: Dictionary, apart: float) -> int:
	var fs: Vector2i = BroodRoot.fp(BroodNew.TURTLE)[0]
	var c: Vector2i = s["c"]
	var mid0 := Vector2(c) + Vector2(MapGen.HALL) * 0.5
	var tc := Vector2i(-1, -1)
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if tc.x >= 0 or (absi(dx) != r and absi(dy) != r):
					continue
				var cc := Vector2i(int(mid0.x - fs.x * 0.5), int(mid0.y - fs.y * 0.5)) + Vector2i(dx, dy)
				if ExpansionSpots._ground_ok(g, cc, fs):
					tc = cc
	if tc.x < 0:
		return -1
	var mid := Vector2(tc) + Vector2(fs) * 0.5
	var lv := int(g.height[g.idx(tc)])
	var ms: Vector2i = BroodRoot.fp(BroodNew.MAW)[0]
	var reach := float(Defs.NB["turtle_swamp"]) - 1.5
	var trect := Rect2i(tc, fs).grow(1)
	var cands: Array = []
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var p := mid + Vector2(dx, dy)
			if p.distance_to(mid) > reach:
				continue
			var mc := Vector2i(int(p.x - ms.x * 0.5), int(p.y - ms.y * 0.5))
			if Rect2i(mc, ms).intersects(trect) or not ExpansionSpots._ground_ok(g, mc, ms) or int(g.height[g.idx(mc)]) != lv:
				continue
			cands.append([p * Defs.TILE, p.distance_to(mid)])
	return _greedy(cands, apart, [])


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	var head := "%-18s" % "map"
	for a in APARTS:
		head += "  apart %2d: mother  turtle" % int(a)
	print(head)
	for id in ids:
		var g := Game.new()
		g.map_id = id
		g.demo = true
		g.factions = ["brood", "brood"]
		g.sides = [0, 1]
		g.colours = [0, 1]
		root.add_child(g)
		await process_frame
		await process_frame
		var line := "%-18s" % id
		for a in APARTS:
			var mo: Array = []
			for t in 2:
				mo.append(_mother(g, t, a))
			var tu: Array = []
			for s in g.exp_spots.all:
				if int(s["team"]) < 2:
					var n := _turtle(g, s, a)
					if n >= 0:
						tu.append(n)
			tu.sort()
			line += "  %8s  %4s  %-10s" % ["", "%d-%d" % [mo.min(), mo.max()], ("%d-%d (%d sites)" % [tu[0], tu[-1], tu.size()]) if not tu.is_empty() else "-"]
		print(line)
		g.queue_free()
		await process_frame
	quit(0)
