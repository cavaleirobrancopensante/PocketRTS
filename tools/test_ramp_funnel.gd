extends SceneTree
## The ramps of every built-in map (2 players and as many as the map holds), against the owner's
## approved spec (docs/ramp_funnel.md, docs/shots/ramp_funnel/owner_spec.png):
##  1. the cliff edge runs straight up to both sides of the ramp: beside every ramp row the cell next
##     to the planks has the height of the cell past it (no tile jutting, none pulled back), and the
##     map differs from the old notch only in those cells,
##  2. the ramp is exactly 3 tiles wide, the same cells as before,
##  3. a unit gets onto it straight on at the top or the bottom end, or from the side onto its bottom
##     row: paths from the landing to the foot and from beside the bottom row onto it,
##  4. every other row is closed from the sides: a rail on the edge between each ramp cell and its
##     side neighbour (MapGen.ramp_rails); paths from beside those rows reach the ramp only round
##     its ends and never cross a rail, nor do paths off the ramp; the walk fill and movement
##     (Game.rail_fix) keep to it, also for a unit already on a rail (an old save),
##  5. units walking (Greenhold, every direction): from beside a closed row to the ramp (round the
##     end), from beside the bottom row onto it (straight), and pressing at a rail: none crosses or
##     stands on a rail.
## Prints a line per map (ramps by the way they go down) and "ramp funnel: PASS" / "FAIL (n)".
##   godot --headless --fixed-fps 30 --script res://tools/test_ramp_funnel.gd [-- ids...] [-- before]

var fails := 0
var dirs := {"south": 0, "north": 0, "east": 0, "west": 0}


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String, n: int) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = true
	var facs: Array = []
	var sides: Array = []
	for i in n:
		facs.append("crown")
		sides.append(0 if i < n / 2 else 1)
	g.factions = facs
	g.sides = sides
	g.rng.seed = 4242            # (the same map each time: the generated maps use it)
	root.add_child(g)
	return g


func _run(ids: Array) -> void:
	if ids.has("before"):
		ids.erase("before")
		MapGen.no_funnel = true      # (the old notch and no rails, to see what this test catches)
	if ids.is_empty():
		ids = MapGen.all_ids()
	for id in ids:
		var counts := [2]
		if MapGen.max_players(id) > 2:
			counts.append(MapGen.max_players(id))
		for n in counts:
			var g := _make(id, n)
			await process_frame
			var bad: Array = check(g)
			if n == 2 and not MapGen.no_funnel:
				MapGen.no_funnel = true
				var g0 := _make(id, n)
				await process_frame
				MapGen.no_funnel = false
				bad.append_array(same_map(g0, g))
				g0.queue_free()
			if n == 2 and id == "greenhold":
				bad.append_array(await walks(g))
			var per := {}
			for r in MapGen.ramp_parts(g.mapgen):
				var dn: String = _dir_name(r["down"])
				per[dn] = int(per.get(dn, 0)) + 1
				dirs[dn] += 1
			print("%-18s %dp  ramps %s  rails %d  %s" % [id, n, str(per), g.rails.size(), "ok" if bad.is_empty() else "BAD"])
			for b in bad:
				print("    " + str(b))
			fails += bad.size()
			g.queue_free()
			await process_frame
	print("ramps by direction: %s" % str(dirs))
	print("ramp funnel: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


static func _dir_name(d: Vector2i) -> String:
	if d == Vector2i(0, 1):
		return "south"
	if d == Vector2i(0, -1):
		return "north"
	return "east" if d == Vector2i(1, 0) else "west"


static func _cen(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * Game.T


## The problems of every ramp on g's map (empty: all as the spec says).
static func check(g: Game) -> Array:
	var bad: Array = []
	for r in MapGen.ramp_parts(g.mapgen):
		var down: Vector2i = r["down"]
		var side: Vector2i = r["side"]
		var rows: Array = r["rows"]            # top row first: each an Array of cells
		var n: int = rows.size()
		var tag := "ramp at %s going %s" % [str(rows[0][0]), _dir_name(down)]
		var widths := {}
		for j in n:
			widths[(rows[j] as Array).size()] = true
		if widths.size() != 1:
			bad.append("%s: its rows aren't all as wide (%s)" % [tag, str(widths.keys())])
		elif not widths.has(3):
			# (the middle hills of a few maps have 2-wide ramps: noted, the same cells as before)
			print("    note: %s is %d wide" % [tag, rows[0].size()])
		for k in 2:
			var step: Vector2i = -side if k == 0 else side
			for j in n:
				var lane: Vector2i = rows[j][0] if k == 0 else rows[j][-1]
				var c: Vector2i = lane + step
				var o: Vector2i = c + step
				if not g.in_map(c) or g.ramp[g.idx(c)] == 1:
					continue
				# 1. a straight edge: the side cell as high as the one past it
				if g.in_map(o) and g.ramp[g.idx(o)] == 0 and g.water[g.idx(o)] == 0 and g.water[g.idx(c)] == 0 \
						and int(g.height[g.idx(c)]) != int(g.height[g.idx(o)]):
					bad.append("%s: the edge isn't straight beside row %d: %s is %s, %s past it is %s" % [tag, j + 1,
							str(c), "high" if g.height[g.idx(c)] == 1 else "low", str(o), "high" if g.height[g.idx(o)] == 1 else "low"])
				# 3/4. a rail beside every row but the bottom one
				var cut := g.rail_cut(lane, c)
				if j < n - 1 and not cut:
					bad.append("%s: no rail between %s (row %d) and %s beside it" % [tag, str(lane), j + 1, str(c)])
				elif j == n - 1 and cut:
					bad.append("%s: the bottom row is shut from the side at %s" % [tag, str(c)])
				if not g._walkable(c):
					continue
				if j == n - 1:
					# onto the bottom tile from the side: one straight step
					var p := g.find_path(_cen(c), _cen(lane))
					if p.is_empty() or p[p.size() - 1].distance_to(_cen(lane)) > 2.0 or _length(_cen(c), p) > Game.T * 1.6:
						bad.append("%s: no straight step from %s beside the bottom row onto it" % [tag, str(c)])
					continue
				# from beside a closed row onto the ramp (and back): round an end, never over a rail
				for pair in [[c, lane], [lane, c]]:
					var a: Vector2 = _cen(pair[0])
					var b: Vector2 = _cen(pair[1])
					var p := g.find_path(a, b)
					if p.is_empty() or p[p.size() - 1].distance_to(b) > 2.0:
						bad.append("%s: no path from %s to %s" % [tag, str(pair[0]), str(pair[1])])
					elif _crosses(g, a, p):
						bad.append("%s: the path from %s to %s crosses a rail" % [tag, str(pair[0]), str(pair[1])])
				var fill: Dictionary = g._walk_fill(c, 0, 400, 30)
				if int(fill.get(lane, 0)) <= 2:
					bad.append("%s: the walk fill steps from %s straight onto %s" % [tag, str(c), str(lane)])
				# movement: a step at the rail stops on its own side; a unit on the rail is pushed off
				var at := g.resolve_terrain(_cen(lane), _cen(c), 10.0)
				if (at - _cen(c)).dot(Vector2(step)) < -Game.T * 0.5 + g.RAIL_GAP - 0.5:
					bad.append("%s: a step from %s onto %s gets over the rail" % [tag, str(c), str(lane)])
				var edge := (_cen(c) + _cen(lane)) * 0.5
				var off := g.rail_fix(edge + Vector2(step), edge + Vector2(step), 10.0)
				if absf((off - edge).dot(Vector2(step))) < g.RAIL_GAP - 0.5:
					bad.append("%s: a unit standing on the rail at %s isn't pushed off" % [tag, str(edge)])
		# 3. straight on at both ends, over the planks
		var tops := 0
		for c in rows[0]:
			var a: Vector2i = c - down
			if g._walkable(a) and int(g.height[g.idx(a)]) == 1 and g.ramp[g.idx(a)] == 0:
				tops += 1
		if tops != rows[0].size():
			bad.append("%s: %d of its %d top lanes open onto the high ground" % [tag, tops, rows[0].size()])
		var foots := 0
		for c in rows[-1]:
			var b: Vector2i = c + down
			if g._walkable(b) and int(g.height[g.idx(b)]) == 0 and g.ramp[g.idx(b)] == 0:
				foots += 1
		if foots == 0:
			bad.append("%s: its foot opens onto no low ground" % tag)
		for w in rows[0].size():
			var from: Vector2 = _cen(rows[0][w] - down)
			var to: Vector2 = _cen(rows[-1][w] + down)
			for pair in [[from, to], [to, from]]:
				var p := g.find_path(pair[0], pair[1])
				if p.is_empty() or p[p.size() - 1].distance_to(pair[1]) > 2.0:
					bad.append("%s: no path between the landing and the foot in lane %d" % [tag, w + 1])
				elif _crosses(g, pair[0], p) or _length(pair[0], p) > (n + 2) * Game.T * 1.3:
					bad.append("%s: the path between the landing and the foot in lane %d crosses a rail or goes round" % [tag, w + 1])
	return bad


static func _length(a: Vector2, p: PackedVector2Array) -> float:
	var l := 0.0
	for q in p:
		l += a.distance_to(q)
		a = q
	return l


## Does the walk from a along the path p cross a rail's line?
static func _crosses(g: Game, a: Vector2, p: PackedVector2Array) -> bool:
	for q in p:
		for rl in g.rails:
			if Game._seg_hits_rect(a, q, (rl["rect"] as Rect2).grow(0.5)):
				return true
		a = q
	return false


## The two maps (built with the old notch and with the new straight edge): the same ramps, water,
## trees and rocks; the heights differ only in cells beside a ramp's rows (rule 1: no extra tiles).
static func same_map(g0: Game, g: Game) -> Array:
	var bad: Array = []
	if g0.ramp != g.ramp:
		bad.append("the ramps differ from the map with the old notch")
	if g0.water != g.water:
		bad.append("the water differs from the map with the old notch")
	var beside := {}
	for r in MapGen.ramp_parts(g.mapgen):
		var side: Vector2i = r["side"]
		for row in r["rows"]:
			beside[row[0] - side] = true
			beside[row[-1] + side] = true
	for i in g.W * g.H:
		var c := Vector2i(i % g.W, i / g.W)
		if g0.height[i] != g.height[i] and not beside.has(c):
			bad.append("the height differs at %s, not beside a ramp" % str(c))
			break
	return bad


## 5. Units walking on Greenhold, one ramp of each direction: Clock Soldiers from beside a closed
## row to the ramp beside them, from beside the bottom row onto it, and a Great Winder pressed at
## a rail from the side. Every tick: no unit crosses a rail or stands on one (its middle closer
## than RAIL_GAP to the rail's line). Who gets there and how long it took is checked too.
func walks(g: Game) -> Array:
	var bad: Array = []
	for r in MapGen.ramp_parts(g.mapgen):
		var down: Vector2i = r["down"]
		var side: Vector2i = r["side"]
		var rows: Array = r["rows"]
		var n: int = rows.size()
		var tag := "walk at the ramp going %s" % _dir_name(down)
		var cases: Array = []      # [unit, goal, must arrive within s, what]
		for k in 2:
			var step: Vector2i = -side if k == 0 else side
			var mid: Vector2i = rows[1][0] if k == 0 else rows[1][-1]
			var low: Vector2i = rows[-1][0] if k == 0 else rows[-1][-1]
			cases.append(["clock_soldier", _cen(mid + step), _cen(mid), 12.0, "beside row 2 to the ramp beside it"])
			cases.append(["clock_soldier", _cen(low + step * 2), _cen(low), 3.0, "beside the bottom row onto it"])
			if k == 0:
				cases.append(["great_winder", _cen(rows[n - 2][0] + step * 3 if k == 0 else rows[n - 2][-1] + step * 3), _cen(rows[n - 2][0] if k == 0 else rows[n - 2][-1]), 14.0, "a Great Winder from beside row %d to the ramp" % (n - 1)])
		var us: Array = []
		for cs in cases:
			var u: Unit = g._add_unit(cs[0], 0, cs[1])
			if u == null:
				bad.append("%s: no %s" % [tag, cs[0]])
				continue
			u.cmd_move(cs[2])
			us.append([u, cs[2], cs[3], cs[4], u.position, -1.0])
		var t := 0.0
		while t < 16.0:
			await physics_frame
			t += 1.0 / 30.0
			for e in us:
				var u: Unit = e[0]
				if u.dead:
					continue
				var prev: Vector2 = e[4]
				for rl in g.rails:
					var rr: Rect2 = rl["rect"]
					if Game._seg_hits_rect(prev, u.position, rr.grow(0.01)):
						bad.append("%s: %s (%s) crossed a rail at %s" % [tag, u.kind, e[3], str(u.position)])
					elif rr.grow(g.RAIL_GAP - 1.0).has_point(u.position):
						bad.append("%s: %s (%s) stands on a rail at %s" % [tag, u.kind, e[3], str(u.position)])
				e[4] = u.position
				if e[5] < 0.0 and u.position.distance_to(e[1]) < 14.0:
					e[5] = t
		for e in us:
			if e[5] < 0.0 or e[5] > e[2]:
				bad.append("%s: %s %s: %s" % [tag, e[0].kind, e[3], "never got there (%s from it)" % str(e[0].position - e[1]) if e[5] < 0.0 else "took %.1f s" % e[5]])
			g.consume_unit(e[0])
		await physics_frame
	# dedupe (a unit pressing at a rail is reported once)
	var seen := {}
	var out: Array = []
	for b in bad:
		var key: String = b.substr(0, b.find(" at ("))
		if not seen.has(key):
			seen[key] = true
			out.append(b)
	return out
