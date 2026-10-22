extends SceneTree
## The lobby's pictures of the named maps: builds each map (MapData.NAMED) and saves its
## minimap to assets/maps/<id>.png. Run again after changing a map or the map generator:
##   godot --headless --script res://tools/make_map_previews.gd [-- ids...]


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapData.NAMED.keys()
	DirAccess.make_dir_recursive_absolute("res://assets/maps")
	for id in ids:
		var n := MapGen.max_players(id)
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
		var img: Image = g.minimap_img.duplicate()
		# high ground a touch lighter, its cliffs dark and the ramps light, so the
		# plateaus read at a glance
		for y in Game.H:
			for x in Game.W:
				var i := y * Game.W + x
				var col := img.get_pixel(x, y)
				if g.cliff[i] == 1:
					col = col.darkened(0.6)
				elif g.ramp[i] == 1:
					col = col.lightened(0.35)
				elif g.height[i] == 1:
					col = col.lightened(0.18)
				img.set_pixel(x, y, col)
		img.resize(Game.W * 2, Game.H * 2, Image.INTERPOLATE_NEAREST)
		img.save_png("res://assets/maps/%s.png" % id)
		print("preview ", id, " ", Game.W, "x", Game.H)
		g.queue_free()
		await process_frame
	quit()
