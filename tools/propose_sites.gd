extends SceneTree
## Helper of the map enlargement (docs/map_sizes.md): proposes more base sites for a built-in map. Builds the map
## with as many players as it holds and looks for hall spots on side A (their twins go to side B) that:
##  - have open ground under the hall and round it (no water, cliff or ramp; trees and rocks are thinned when a
##    site is added), on one level,
##  - stand at least SPACE tiles (middle to middle) from every other site and from their own twin,
##  - are nearer by land to a side-A main than to any side-B main, and at least FOE steps from every main but
##    the nearest one,
## scored by room (as ExpansionSpots rates it, trees not counted), minus a little per step from home.
##   godot --headless --script res://tools/propose_sites.gd -- <map>[:count[:space]] ...
## Prints the picks as "thirds" entries to add to scripts/map_data.gd.

const FOE := 30.0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(args: Array) -> void:
	for a in args:
		var p := String(a).split(":")
		await _one(p[0], int(p[1]) if p.size() > 1 else 2, float(p[2]) if p.size() > 2 else 21.0)
	quit(0)


func _one(id: String, want: int, space: float) -> void:
	var n := MapGen.max_players(id) if MapData.NAMED.has(id) else 2
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
	g.colours = range(n)
	root.add_child(g)
	await process_frame
	var dist: Array = []
	for t in n:
		dist.append(_steps(g, g.starts[t]))
	var taken: Array = g.base_sites.duplicate()
	var picks: Array = []
	var cands: Array = []
	for y in range(2, Game.H - MapGen.HALL.y - 2):
		for x in range(2, Game.W - MapGen.HALL.x - 2):
			var c := Vector2i(x, y)
			if not _clear(g, c):
				continue
			var near_t := -1
			var nd := INF
			var foe := INF
			for t in n:
				var d := ExpansionSpots._foot_d(g, dist[t], c)
				if d < nd:
					foe = minf(foe, nd)
					nd = d
					near_t = t
				else:
					foe = minf(foe, d)
			if near_t < 0 or nd == INF or g.sides[near_t] != 0 or foe < FOE:
				continue
			var room := _room(g, c)
			cands.append({"c": c, "score": 100.0 * room - 0.25 * nd + 0.25 * clampf(foe - nd, -40, 60), "room": room, "home": nd, "foe": foe, "t": near_t})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	for cd in cands:
		if picks.size() >= want:
			break
		var c: Vector2i = cd["c"]
		var tw := g._mirror(c, MapGen.HALL)
		var mid := Vector2(c) + Vector2(MapGen.HALL) * 0.5
		if mid.distance_to(Vector2(tw) + Vector2(MapGen.HALL) * 0.5) < space:
			continue
		var ok := true
		for o in taken:
			if mid.distance_to(Vector2(o) + Vector2(MapGen.HALL) * 0.5) < space or (Vector2(tw) + Vector2(MapGen.HALL) * 0.5).distance_to(Vector2(o) + Vector2(MapGen.HALL) * 0.5) < space:
				ok = false
				break
		if not ok:
			continue
		picks.append(cd)
		taken.append(c)
		taken.append(tw)
	print("%s %dx%d, %d players, sites now %d" % [id, Game.W, Game.H, n, g.base_sites.size()])
	for p in picks:
		print("  [%d, %d]  room %d%%  home %d (p%d)  foe %d" % [p["c"].x, p["c"].y, int(p["room"] * 100), int(p["home"]), int(p["t"]), int(p["foe"])])
	g.queue_free()
	await process_frame


## Steps by land, trees and rocks counted as open (a site's woods get thinned).
func _steps(g: Game, c: Vector2i) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(Game.W * Game.H)
	d.fill(INF)
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			var cc := c + Vector2i(x, y)
			d[g.idx(cc)] = 0.0
			q.append(cc)
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if g.in_map(n2) and d[g.idx(n2)] == INF and g.water[g.idx(n2)] == 0 and g.cliff[g.idx(n2)] == 0:
				d[g.idx(n2)] = d[g.idx(p)] + 1.0
				q.append(n2)
	return d


func _clear(g: Game, c: Vector2i) -> bool:
	var lv := -1
	for y in range(-1, MapGen.HALL.y + 1):
		for x in range(-1, MapGen.HALL.x + 1):
			var cc := c + Vector2i(x, y)
			if not g.in_map(cc):
				return false
			var i := g.idx(cc)
			if g.water[i] != 0 or g.cliff[i] != 0 or g.ramp[i] != 0:
				return false
			if lv < 0:
				lv = int(g.height[i])
			elif int(g.height[i]) != lv:
				return false
	return true


## Room (ExpansionSpots._room) with trees and rocks counted as open.
func _room(g: Game, c: Vector2i) -> float:
	var mid := Vector2(c) + Vector2(MapGen.HALL) * 0.5
	var lv := int(g.height[g.idx(c + Vector2i(2, 2))])
	var reach := float(Defs.ECON_RANGE)
	var seen := {}
	var q: Array = []
	for y in MapGen.HALL.y:
		for x in MapGen.HALL.x:
			seen[c + Vector2i(x, y)] = true
			q.append(c + Vector2i(x, y))
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = p + dd
			if seen.has(n2) or not g.in_map(n2):
				continue
			var i := g.idx(n2)
			if (Vector2(n2) + Vector2(0.5, 0.5)).distance_to(mid) > reach:
				continue
			if g.water[i] != 0 or g.ramp[i] != 0 or g.cliff[i] != 0 or int(g.height[i]) != lv:
				continue
			seen[n2] = true
			q.append(n2)
	return clampf(float(seen.size()) / (PI * reach * reach), 0.0, 1.0)
