extends SceneTree
## Every built-in map, with 2 players and with as many as it holds: each main base (the
## plateau its hall stands on) has no tree, rock or solid decoration left on it, every
## start can still reach every other base, and the rest of the map still has its woods.
##   godot --headless --script res://tools/test_main_clear.gd [-- ids...]


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	var failed := 0
	for id in ids:
		for n in ([2, MapGen.max_players(id)] if MapGen.max_players(id) > 2 else [2]):
			var g := Game.new()
			g.map_id = id
			g.demo = true
			g.edit_mode = true
			var facs: Array = []
			var sides: Array = []
			for i in n:
				facs.append("crown")
				sides.append(0 if i < n / 2 else 1)
			g.factions = facs
			g.sides = sides
			root.add_child(g)
			await process_frame
			var bad: Array = []
			var area_cells := 0
			for st in g.starts:
				var area: Array = g.mapgen.main_area(st)
				area_cells += area.size()
				if area.size() < 60:
					bad.append("main %s: only %d cells" % [st, area.size()])
				for c in area:
					var i := g.idx(c)
					if g._terrain_kind.has(i):
						bad.append("main %s: %s left at %s" % [st, g._terrain_kind[i], c])
				for pr in g.mapgen.props:
					if pr["dead"]:
						continue
					for pc in pr["cells"]:
						if area.has(pc):
							bad.append("main %s: decoration %s at %s" % [st, pr["name"], pc])
				for other in g.starts + g.expansions:
					if not g._connected(st, other):
						bad.append("main %s can't reach %s" % [st, other])
			var woods := g._terrain_kind.size()
			if woods < 10:
				bad.append("only %d trees/rocks left on the whole map" % woods)
			print("%-22s %d players  main cells %4d  cleared %3d  thinned %4d  trees/rocks %4d  %s" % [id, n, area_cells, g.mapgen.main_cleared, g.mapgen.thinned, woods, "ok" if bad.is_empty() else "FAIL"])
			for b in bad.slice(0, 8):
				print("    ", b)
			if not bad.is_empty():
				failed += 1
			g.queue_free()
			await process_frame
	print("main clear: %s" % ("PASS" if failed == 0 else "FAIL (%d)" % failed))
	quit(1 if failed > 0 else 0)
