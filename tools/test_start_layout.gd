extends SceneTree
## Every built-in map, every faction, with 2 players and with as many as it holds: the
## STARTING economy buildings (Farm / Feeding Pit / Ore Crusher...) hug the edge of the main
## base's ground, away from the front, and:
##  - sit in the edge band (Game.edge_gap <= 1: touching the cliff / map rim / a tree, or one
##    lane off it), on the hall's ground level, off every ramp, on solid building cells,
##  - overlap nothing (no building, not the hall),
##  - leave a walking gap to the hall and can be walked up to from it, and every start can still
##    reach every other base,
##  - are mirror-fair: every player of one faction has the same distance to his hall (and the
##    same edge gap) within a small tolerance,
##  - are not farther from the hall than the old "behind the hall" spot by more than a few tiles.
##   godot --headless --script res://tools/test_start_layout.gd [-- ids...]     (prints the per-map table)

const TOL := 1.0              # tiles: players of one faction on one map differ at most this much
const MAX_WORSE := 3.0        # tiles: farther than the old spot by at most this
var rows: Array = []


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String, facs: Array, edge := true) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = true
	g.start_edge_layout = edge
	var sides: Array = []
	for i in facs.size():
		sides.append(0 if i < facs.size() / 2 else 1)
	g.factions = facs
	g.sides = sides
	root.add_child(g)
	return g


## [{b, d, gap}] per team: the starting economy buildings and their distances.
func _starts_of(g: Game, t: int) -> Array:
	var out: Array = []
	var hall: Building = g._own_hall(t)
	var hc: Vector2 = hall.rect().get_center() / Game.T
	var want: Array = Defs.start_list(g.factions[t])
	for b in g.buildings:
		if b.team == t and want.has(b.kind):
			var h0 := int(g.height[g.idx(g.cell_of(hall.rect().get_center()))])
			out.append({"b": b, "d": (b.rect().get_center() / Game.T).distance_to(hc), "gap": g.edge_gap(b.cell, b.size, h0)})
	return out


## Walk from round the hall to a cell touching the building, over free ground.
func _reachable(g: Game, hall: Building, b: Building) -> bool:
	var hr := Rect2i(Vector2i(hall.cell), hall.size)
	var br := Rect2i(Vector2i(b.cell), b.size)
	var seen := {}
	var todo: Array = []
	for y in range(hr.position.y - 1, hr.end.y + 1):
		for x in range(hr.position.x - 1, hr.end.x + 1):
			var c := Vector2i(x, y)
			if not hr.has_point(c) and g._walkable(c):
				seen[c] = true
				todo.append(c)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if br.grow(1).has_point(c) and not br.has_point(c) and (c.x >= br.position.x and c.x < br.end.x or c.y >= br.position.y and c.y < br.end.y):
			return true
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dd
			if not seen.has(n) and g._walkable(n) and not hr.has_point(n) and absi(n.x - hr.position.x) < 60 and absi(n.y - hr.position.y) < 60:
				seen[n] = true
				todo.append(n)
	return false


func _check(g: Game, bad: Array) -> void:
	for t in g.n_players():
		var hall: Building = g._own_hall(t)
		var hr := Rect2i(Vector2i(hall.cell), hall.size)
		var h0 := int(g.height[g.idx(g.cell_of(hall.rect().get_center()))])
		var mine := _starts_of(g, t)
		var want: Array = Defs.start_list(g.factions[t])
		if mine.size() != want.size():
			bad.append("team %d: %d starting buildings, expected %d" % [t, mine.size(), want.size()])
		for s in mine:
			var b: Building = s["b"]
			var br := Rect2i(Vector2i(b.cell), b.size)
			var tag := "team %d %s at %s" % [t, b.kind, b.cell]
			if int(s["gap"]) > 1:
				bad.append("%s: %d free cells to the edge (not hugging it)" % [tag, int(s["gap"])])
			if float(s["d"]) > Game.START_REACH:
				bad.append("%s: %.1f tiles from the hall" % [tag, float(s["d"])])
			for y in range(br.position.y, br.end.y):
				for x in range(br.position.x, br.end.x):
					var c := Vector2i(x, y)
					if not g.in_map(c) or (g.solid[g.idx(c)] != 2 and g.solid[g.idx(c)] != 5):
						bad.append("%s: cell %s isn't a building cell" % [tag, c])
					elif int(g.height[g.idx(c)]) != h0 or g.ramp[g.idx(c)] != 0:
						bad.append("%s: cell %s is on a ramp / another level" % [tag, c])
			if br.intersects(hr):
				bad.append("%s overlaps the hall" % tag)
			if br.grow(Game.START_SIDE_CLEAR - 1).intersects(hr):
				bad.append("%s is closer than %d free cells to the hall" % [tag, Game.START_SIDE_CLEAR])
			for o in g.buildings:
				if o != b and o != hall and Rect2i(Vector2i(o.cell), o.size).intersects(br):
					bad.append("%s overlaps %s" % [tag, o.kind])
			if not _reachable(g, hall, b):
				bad.append("%s can't be walked up to from the hall" % tag)
		for other in g.starts + g.expansions:
			if not g._connected(g.starts[t], other):
				bad.append("start %s can't reach %s" % [g.starts[t], other])


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	var failed := 0
	var worst := 0.0
	for id in ids:
		var counts: Array = [2]
		if MapGen.max_players(id) > 2:
			counts.append(MapGen.max_players(id))
		for n in counts:
			for fac in ["crown", "brood", "clockwork"]:
				var facs: Array = []
				for i in n:
					facs.append(fac)
				var g := _make(id, facs)
				await process_frame
				var bad: Array = []
				_check(g, bad)
				# mirror fairness: one faction, one distance (and one edge gap)
				var ds: Array = []
				var gaps: Array = []
				for t in n:
					for s in _starts_of(g, t):
						ds.append(float(s["d"]))
						gaps.append(int(s["gap"]))
				if ds.is_empty():
					bad.append("no starting economy building")
				else:
					if ds.max() - ds.min() > TOL:
						bad.append("not mirror-fair: distances %s" % str(ds.map(func(v: float) -> String: return "%.1f" % v)))
					if gaps.max() - gaps.min() > 1:
						bad.append("not mirror-fair: edge gaps %s" % str(gaps))
				g.queue_free()
				await process_frame
				# the old spot, for comparison (two-player games)
				var olds: Array = []
				if n == 2:
					var go := _make(id, facs, false)
					await process_frame
					for t in n:
						for s in _starts_of(go, t):
							olds.append(float(s["d"]))
					go.queue_free()
					await process_frame
				if not ds.is_empty() and not olds.is_empty():
					worst = maxf(worst, ds.max() - olds.max())
					if ds.max() - olds.max() > MAX_WORSE:
						bad.append("farther than the old spot: %.1f vs %.1f tiles" % [ds.max(), olds.max()])
				print("%-18s %d players %-9s dist to hall: now %s  was %s  gaps %s  %s" % [id, n, fac, _fmt(ds), _fmt(olds), str(gaps.slice(0, 4)), "ok" if bad.is_empty() else "FAIL"])
				for m in bad.slice(0, 6):
					print("    ", m)
				if not bad.is_empty():
					failed += 1
		# mixed factions on the two-player start
		for pair in [["crown", "brood"], ["brood", "clockwork"], ["clockwork", "crown"]]:
			var g := _make(id, pair)
			await process_frame
			var bad: Array = []
			_check(g, bad)
			print("%-18s 2 players %s v %s: %s" % [id, pair[0], pair[1], "ok" if bad.is_empty() else "FAIL"])
			for m in bad.slice(0, 6):
				print("    ", m)
			if not bad.is_empty():
				failed += 1
			g.queue_free()
			await process_frame
	print("start layout: %s (farthest vs old spot: %+.1f tiles)" % ["PASS" if failed == 0 else "FAIL (%d)" % failed, worst])
	quit(1 if failed > 0 else 0)


func _fmt(v: Array) -> String:
	var parts: PackedStringArray = []
	for x in v.slice(0, 4):
		parts.append("%.1f" % float(x))
	return "[" + ", ".join(parts) + "]"
