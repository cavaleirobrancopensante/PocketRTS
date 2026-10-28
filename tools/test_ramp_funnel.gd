extends SceneTree
## Every ramp of every built-in map (2 players and as many as the map holds) is a FUNNEL
## (docs/ramp_funnel.md): the only way between the levels is the ramp's planks.
##  - beside the ramp's top FUNNEL rows (MapGen.FUNNEL) nothing can be walked on (the cliff wall
##    drawn there: a unit standing on it looked as if it floated),
##  - beside every other row no HIGH ground can be walked on (no stepping onto the ramp sideways
##    from the plateau),
##  - the row past the top is open high ground as wide as the planks, the row past the foot is
##    open low ground, and a walk leads from the top to the foot over the planks.
## Prints a line per map (ramps by the way they go down) and "ramp funnel: PASS" / "FAIL (n)".
##   godot --headless --script res://tools/test_ramp_funnel.gd [-- ids...] [-- before]

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
	root.add_child(g)
	return g


func _run(ids: Array) -> void:
	if ids.has("before"):
		ids.erase("before")
		MapGen.no_funnel = true      # (the old open ramp sides, to see what this test catches)
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
			var per := {}
			for r in MapGen.ramp_parts(g.mapgen):
				var dn: String = _dir_name(r["down"])
				per[dn] = int(per.get(dn, 0)) + 1
				dirs[dn] += 1
			print("%-18s %dp  ramps %s  %s" % [id, n, str(per), "ok" if bad.is_empty() else "BAD"])
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


## The problems of every ramp on g's map (empty: all funnels).
static func check(g: Game) -> Array:
	var bad: Array = []
	for r in MapGen.ramp_parts(g.mapgen):
		var down: Vector2i = r["down"]
		var side: Vector2i = r["side"]
		var rows: Array = r["rows"]            # top row first: each an Array of cells
		var funnel: int = MapGen.funnel_rows(rows.size())
		var tag := "ramp at %s going %s" % [str(rows[0][0]), _dir_name(down)]
		for j in rows.size():
			var row: Array = rows[j]
			for c in [row[0] - side, row[-1] + side]:
				if not g.in_map(c) or not g._walkable(c):
					continue
				if j < funnel:
					bad.append("%s: the cell %s beside its row %d can be walked on (the funnel's wall)" % [tag, str(c), j + 1])
				elif int(g.height[g.idx(c)]) == 1:
					bad.append("%s: high ground %s beside its row %d can be walked on" % [tag, str(c), j + 1])
		var tops := 0
		var shut: Array = []
		for c in rows[0]:
			var a: Vector2i = c - down
			if g._walkable(a) and int(g.height[g.idx(a)]) == 1 and g.ramp[g.idx(a)] == 0:
				tops += 1
			else:
				var i := g.idx(a)
				shut.append("%s (solid %d cliff %d height %d %s)" % [str(a), g.solid[i], g.cliff[i], g.height[i], g._terrain_kind.get(i, "")])
		if tops != rows[0].size():
			bad.append("%s: %d of its %d top lanes open onto the high ground; shut: %s" % [tag, tops, rows[0].size(), ", ".join(shut)])
		var foots := 0
		for c in rows[-1]:
			var b: Vector2i = c + down
			if g._walkable(b) and int(g.height[g.idx(b)]) == 0 and g.ramp[g.idx(b)] == 0:
				foots += 1
		if foots == 0:
			bad.append("%s: its foot opens onto no low ground" % tag)
		# a walk from the top to the foot over the planks
		var from: Vector2i = rows[0][rows[0].size() / 2] - down
		var to: Vector2i = rows[-1][rows[-1].size() / 2] + down
		if not _walk(g, from, to, 40):
			bad.append("%s: no walk from %s (top) to %s (foot)" % [tag, str(from), str(to)])
	return bad


static func _walk(g: Game, a: Vector2i, b: Vector2i, reach: int) -> bool:
	if not g._walkable(a) or not g._walkable(b):
		return false
	var seen := {a: true}
	var todo: Array = [a]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c == b:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and g._walkable(n) and absi(n.x - a.x) <= reach and absi(n.y - a.y) <= reach:
				seen[n] = true
				todo.append(n)
	return false
