extends SceneTree
## The map checks (scripts/map_check.gd, the same as the map editor's CHECK) on every named
## map, or the ones given; "custom:<name>" checks one of your own maps:
##   godot --headless --script res://tools/check_maps.gd [-- ids...]
## Prints each map's problems (and warnings); exits with 1 when any map has a problem.


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapData.NAMED.keys()
	var failed := 0
	for id in ids:
		var n := maxi(MapGen.max_players(id), 2)
		var g := Game.new()
		g.map_id = id
		g.demo = true
		g.edit_mode = true            # just the ground: no players, fog or log
		var facs: Array = []
		var sides: Array = []
		for i in n:
			facs.append("crown")
			sides.append(0 if i < n / 2 else 1)
		g.factions = facs
		g.sides = sides
		root.add_child(g)
		await process_frame
		var cells := ""
		var mirror := "off"
		if String(id).begins_with("custom:"):
			var d := MapGen.load_custom(String(id).substr(7))
			cells = String(d.get("cells", ""))
			mirror = String(d.get("mirror", "off"))
		var halls: Array = g.base_sites.filter(func(s: Vector2i) -> bool: return not g.starts.has(s))
		var probs := MapCheck.run(g, g.starts, halls, cells, mirror)
		var bad := probs.filter(func(p: Dictionary) -> bool: return not p["warn"])
		print("%-22s %dx%d  %s" % [id, Game.W, Game.H, "ok" if bad.is_empty() else "%d problem(s)" % bad.size()])
		for p in probs:
			print("    %s %s" % ["warning:" if p["warn"] else "PROBLEM:", p["text"]])
		if not bad.is_empty():
			failed += 1
		g.queue_free()
		await process_frame
	print("%d of %d maps pass" % [ids.size() - failed, ids.size()])
	quit(1 if failed > 0 else 0)
