extends SceneTree
## EXPANSION SPOTS (scripts/expansion_spots.gd, docs/expansion_spots.md). Every built-in map, with 2 players and with as
## many as it holds:
##  - every player has at least one marked spot, and every side has the same number of each rank,
##  - mirror-fair: each marked spot's twin (the map turned through its middle) is marked too, with the same rank and score,
##  - a marked spot is free, buildable ground for a hall (nobody's start; no blocked cell, no ramp),
##  - shown to a Crown and a Clockwork player and when watching; hidden for a Brood player, hidden once a building the
##    viewer knows of stands on it, and hidden with Settings.expansion_spots off.
##   godot --headless --fixed-fps 30 --script res://tools/test_expansion_spots.gd [-- ids...]   (prints each map's spots)

var failed := 0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String, facs: Array, demo := true) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = demo
	var sides: Array = []
	for i in facs.size():
		sides.append(0 if i < facs.size() / 2 else 1)
	g.factions = facs
	g.sides = sides
	g.colours = range(facs.size())
	root.add_child(g)
	return g


func _fmt(s: Dictionary) -> String:
	return "p%d #%d %s score %.0f room %d%% ways %d (gap %d) walk %d foe %s" % [int(s["team"]), int(s["rank"]), str(s["c"]), float(s["score"]),
		int(round(float(s["room"]) * 100)), int(s["ways"]), int(s["gap"]), int(s["home"]), str(int(s["foe"])) if float(s["foe"]) < INF else "-"]


func _check_map(g: Game, bad: Array) -> void:
	var sp: Array = g.exp_spots.spots
	var by := {}
	for t in g.n_players():
		by[t] = [0, 0]
	for s in sp:
		by[int(s["team"])][int(s["rank"]) - 1] += 1
	for t in g.n_players():
		if int(by[t][0]) < 1:
			bad.append("player %d has no marked spot" % t)
		if by[t] != by[0] and g.n_players() == 2:
			bad.append("player %d has %s marks, player 0 %s" % [t, str(by[t]), str(by[0])])
	var at := {}
	for s in sp:
		at[s["c"]] = s
	for s in sp:
		var c: Vector2i = s["c"]
		var tw: Vector2i = g._mirror(c, MapGen.HALL)
		if not at.has(tw):
			bad.append("%s is marked, its twin %s is not" % [c, tw])
		elif int(at[tw]["rank"]) != int(s["rank"]) or absf(float(at[tw]["score"]) - float(s["score"])) > 0.01:
			bad.append("%s and its twin %s differ: %s / %s" % [c, tw, _fmt(s), _fmt(at[tw])])
		if g.starts.has(c):
			bad.append("%s is a player's start" % c)
		if not g.base_sites.has(c):
			bad.append("%s is not a base site" % c)
		for y in MapGen.HALL.y:
			for x in MapGen.HALL.x:
				var cc := c + Vector2i(x, y)
				if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0:
					bad.append("%s: cell %s is not buildable" % [c, cc])


func _run(ids: Array) -> void:
	Settings.expansion_spots = true
	if ids.is_empty():
		ids = MapGen.all_ids()
	for id in ids:
		var counts: Array = [2]
		if MapGen.max_players(id) > 2:
			counts.append(MapGen.max_players(id))
		for n in counts:
			var facs: Array = []
			for i in n:
				facs.append(["crown", "clockwork"][i % 2])
			var g := _make(id, facs)
			await process_frame
			var bad: Array = []
			_check_map(g, bad)
			print("%-18s %d players: %d spots  %s" % [id, n, g.exp_spots.spots.size(), "ok" if bad.is_empty() else "FAIL"])
			for s in g.exp_spots.spots:
				if int(s["team"]) < 2 or n == 2:
					print("    ", _fmt(s))
			for m in bad.slice(0, 8):
				print("    BAD ", m)
			if not bad.is_empty():
				failed += 1
			g.queue_free()
			await process_frame
	await _viewer_checks()
	print("expansion spots: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failed += 1


## Who sees them, taken spots, the toggle.
func _viewer_checks() -> void:
	print("viewer checks (ashford_crossing):")
	for fac in ["crown", "clockwork", "brood"]:
		var g := _make("ashford_crossing", [fac, "crown"], false)
		g.human = 0
		await process_frame
		g.exp_spots.refresh()
		var n: int = g.exp_spots.shown.size()
		if fac == "brood":
			_expect(n == 0, "a Brood player sees no spots (%d shown)" % n)
		else:
			_expect(n == g.exp_spots.spots.size() and n > 0, "a %s player sees every spot (%d of %d)" % [fac, n, g.exp_spots.spots.size()])
		if fac == "crown":
			# taken: a hall of ours on our best spot, an unseen enemy building on another, then seen
			var mine: Dictionary = {}
			var other: Dictionary = {}
			for s in g.exp_spots.spots:
				if int(s["team"]) == 0 and int(s["rank"]) == 1:
					mine = s
				elif int(s["team"]) == 1 and int(s["rank"]) == 1:
					other = s
			g._add_building("town_hall", 0, mine["c"], true)
			var eb: Building = g._add_building("town_hall", 1, other["c"], true)
			eb.seen_by_human = false
			g.exp_spots.refresh()
			var cs: Array = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
			_expect(not cs.has(mine["c"]), "our hall on a spot hides it")
			_expect(cs.has(other["c"]), "an enemy hall not yet seen does not hide its spot")
			eb.seen_by_human = true
			g.exp_spots.refresh()
			cs = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
			_expect(not cs.has(other["c"]), "once seen, the enemy hall hides it")
			eb.dead = true
			g.exp_spots.refresh()
			cs = g.exp_spots.shown.map(func(s: Dictionary) -> Vector2i: return s["c"])
			_expect(cs.has(other["c"]), "the spot shows again when the building is gone")
			Settings.expansion_spots = false
			g.exp_spots.refresh()
			_expect(g.exp_spots.shown.is_empty(), "the setting off hides them all")
			Settings.expansion_spots = true
			g.exp_spots.refresh()
			_expect(not g.exp_spots.shown.is_empty(), "the setting on shows them again")
		g.queue_free()
		await process_frame
	# watching (spectator / replay): shown even with Brood players
	var w := _make("kestrel_rise", ["brood", "brood"], true)
	await process_frame
	w.exp_spots.refresh()
	_expect(w.exp_spots.shown.size() == w.exp_spots.spots.size() and w.exp_spots.shown.size() > 0, "watching: shown (%d)" % w.exp_spots.shown.size())
	w.queue_free()
	await process_frame
