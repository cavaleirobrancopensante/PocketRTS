extends SceneTree
## MAP SIZES (docs/map_sizes.md): every built-in map, with 2 players and with as many as it holds:
## its size, the walk from main to main (A* path, tiles, and seconds for a Musketeer at 62 px/s), the
## base sites each player gets (the free ones nearest his main by land), the walk to his natural, and
## the nearest free site to another player's main (a site right beside a main is a problem).
##   godot --headless --script res://tools/map_sizes.gd [-- ids... | named | classic] [detail] [json:/abs/file.json]
## Fails (exit 1) when a side has fewer sites than its twin, a free site is within NEAR steps of
## another player's main, or a main can't reach another.

const SPEED := 62.0          # px/s, a Musketeer
const NEAR := 24.0           # steps: a free site this close to someone else's main is "beside" it
var rows: Array = []
var detail := false


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
	g.colours = range(n)
	root.add_child(g)
	return g


func _path_tiles(g: Game, a: Vector2i, b: Vector2i) -> float:
	var pa := (Vector2(a) + Vector2(MapGen.HALL) * 0.5) * Game.T
	var pb := (Vector2(b) + Vector2(MapGen.HALL) * 0.5) * Game.T
	var pts := g.find_path(pa + Vector2(0, Game.T * 3), pb + Vector2(0, Game.T * 3))
	var d := 0.0
	var prev := pa + Vector2(0, Game.T * 3)
	for p in pts:
		d += prev.distance_to(p)
		prev = p
	return d / Game.T


func _run(args: Array) -> void:
	var ids: Array = []
	var json := ""
	for a in args:
		if a == "detail":
			detail = true
		elif a == "named":
			ids.append_array(MapData.NAMED.keys())
		elif a == "classic":
			ids.append_array(MapGen.MAPS.keys())
		elif String(a).begins_with("json:"):
			json = String(a).substr(5)
		else:
			ids.append(a)
	if ids.is_empty():
		ids = MapGen.all_ids()
	var failed := 0
	print("%-18s %-3s %-8s %8s %6s %6s %8s %6s  %s" % ["map", "n", "size", "walk", "secs", "sites", "natural", "near", "per player"])
	for id in ids:
		var counts: Array = [2]
		if MapGen.max_players(id) > 2:
			counts.append(MapGen.max_players(id))
		for n in counts:
			var g := _make(id, n)
			await process_frame
			var bad: Array = []
			var dist: Array = []
			for t in n:
				dist.append(ExpansionSpots._steps(g, g.starts[t]))
			# main to main: the nearest enemy main of player 0
			var walk := INF
			for t in range(1, n):
				if g.hostile(0, t):
					walk = minf(walk, _path_tiles(g, g.starts[0], g.starts[t]))
			for t in n:
				for o in n:
					if o != t and ExpansionSpots._foot_d(g, dist[t], g.starts[o]) == INF:
						bad.append("player %d can't walk to player %d" % [t, o])
			# free sites: each to the nearest main by land
			var per: Array = []
			for t in n:
				per.append([])
			var near := INF
			var mains := g.starts.slice(0, n)
			for c in g.base_sites:
				if mains.has(c):
					continue
				var bt := -1
				var bd := INF
				for t in n:
					var d := ExpansionSpots._foot_d(g, dist[t], c)
					if d < bd:
						bd = d
						bt = t
				if bt < 0:
					continue
				per[bt].append(c)
				if detail:
					var ds: Array = []
					for t in n:
						ds.append(int(ExpansionSpots._foot_d(g, dist[t], c)))
					print("    site %s -> p%d  steps %s  room %d%%" % [c, bt, str(ds), int(ExpansionSpots._room(g, c) * 100)])
				for t in n:
					if t != bt:
						var d2 := ExpansionSpots._foot_d(g, dist[t], c)
						near = minf(near, d2)
						if d2 < NEAR:
							bad.append("site %s (player %d's) is %d steps from player %d's main" % [c, bt, int(d2), t])
				for y in MapGen.HALL.y:
					for x in MapGen.HALL.x:
						var cc: Vector2i = c + Vector2i(x, y)
						if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0:
							bad.append("site %s: cell %s not buildable" % [c, cc])
			var nat_walk := 0.0
			if g.expansions.size() > 0:
				nat_walk = _path_tiles(g, g.starts[0], g.expansions[0])
			var cnt: Array = per.map(func(l: Array) -> int: return l.size())
			if n == 2 and cnt[0] != cnt[1]:
				bad.append("players have %s sites" % str(cnt))
			var sz := Vector2i(Game.W, Game.H)
			print("%-18s %-3d %-8s %8.0f %6.0f %6s %8.0f %6s  %s %s" % [id, n, "%dx%d" % [sz.x, sz.y], walk, walk * Game.T / SPEED,
				str(g.base_sites.size()), nat_walk, str(int(near)) if near < INF else "-", str(cnt), "ok" if bad.is_empty() else "FAIL"])
			for m in bad.slice(0, 6):
				print("    BAD ", m)
			if not bad.is_empty():
				failed += 1
			var sites: Array = []
			for c in g.base_sites:
				sites.append([c.x, c.y])
			var st: Array = []
			for c in mains:
				st.append([c.x, c.y])
			rows.append({"id": id, "n": n, "w": sz.x, "h": sz.y, "walk": walk, "secs": walk * Game.T / SPEED, "sites": sites,
				"starts": st, "per": cnt, "natural": nat_walk, "near": near if near < INF else -1})
			g.queue_free()
			await process_frame
	if json != "":
		var f := FileAccess.open(json, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, " "))
		f.close()
	print("map sizes: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed > 0 else 0)
