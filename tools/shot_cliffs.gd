extends SceneTree
## Screenshots of cliffs at 2x on each map: the south-facing cliff face seen from the low
## ground (<map>_face.png), and plateau rims seen from the high ground, one for each open side
## (<map>_rim_n / _rim_e / _rim_w .png: the rim of the plateau with the low ground to the north,
## east, west), plus the same face at a ramp (<map>_ramp.png).
##   xvfb-run -a godot --rendering-driver opengl3 --script res://tools/shot_cliffs.gd -- <outdir> [map ids...]
## With no ids: every named map and generated map.
var out := ""
var ids: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	ids = Array(a.slice(1))
	if ids.is_empty():
		ids = MapData.NAMED.keys() + MapGen.MAPS.keys()
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for id in ids:
		var n := maxi(MapGen.max_players(id), 2)
		var g := Game.new()
		g.map_id = id
		g.demo = true
		g.rng.seed = 4242
		var facs: Array = []
		var sides: Array = []
		for i in n:
			facs.append("crown")
			sides.append(0 if i < n / 2 else 1)
		g.factions = facs
		g.sides = sides
		root.add_child(g)
		await process_frame
		await process_frame
		g.reveal = true
		g.explored.fill(1)
		g.fog_base_dirty = true
		g.camera.zoom = Vector2(2, 2)
		var spots := _find(g)
		for k in spots.keys():
			g.camera.position = spots[k]
			await create_timer(0.35).timeout
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, id, k])
		print("%s: %s" % [id, spots.keys()])
		g.queue_free()
		await process_frame
	quit()


## A cell is a cliff edge of kind (dx, dy): a cliff cell whose neighbour that way is plain low ground
func _edge(g: Game, x: int, y: int, d: Vector2i) -> bool:
	var c := Vector2i(x, y)
	var n := c + d
	if not g.in_map(c) or not g.in_map(n):
		return false
	var i := g.idx(c)
	var j := g.idx(n)
	return g.cliff[i] == 1 and g.height[j] == 0 and g.ramp[j] == 0 and g.water[j] == 0 and g.cliff[j] == 0 and g.solid[j] == 0


func _near_ramp(g: Game, x: int, y: int, r: int) -> bool:
	for yy in range(y - r, y + r + 1):
		for xx in range(x - r, x + r + 1):
			if g.in_map(Vector2i(xx, yy)) and g.ramp[g.idx(Vector2i(xx, yy))] == 1:
				return true
	return false


## The camera spot for each view: the middle of a straight run of 4 edge cells, away from ramps.
func _find(g: Game) -> Dictionary:
	var res := {}
	var T := float(Defs.TILE)
	var want := {"face": Vector2i(0, 1), "rim_n": Vector2i(0, -1), "rim_e": Vector2i(1, 0), "rim_w": Vector2i(-1, 0)}
	for name in want.keys():
		var d: Vector2i = want[name]
		var along := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
		var best := Vector2i(-1, -1)
		for run: int in [5, 4, 3, 2]:
			for y in range(8, g.H - 8):
				for x in range(8, g.W - 8):
					var ok := true
					for k in run:
						var c := Vector2i(x, y) + along * k
						if not _edge(g, c.x, c.y, d) or _near_ramp(g, c.x, c.y, 2):
							ok = false
							break
					if ok:
						best = Vector2i(x, y) + along * (run / 2)
						break
				if best.x >= 0:
					break
			if best.x >= 0:
				break
		if best.x >= 0:
			var p := (Vector2(best) + Vector2(0.5, 0.5)) * T
			# the view centred a bit onto the side the viewer stands on
			res[name] = p + Vector2(d) * (T * 0.0)
	# a ramp with cliff beside it
	for y in range(6, g.H - 6):
		for x in range(6, g.W - 6):
			if g.ramp[g.idx(Vector2i(x, y))] == 1:
				res["ramp"] = (Vector2(x, y) + Vector2(0.5, 0.5)) * T
				return res
	return res
