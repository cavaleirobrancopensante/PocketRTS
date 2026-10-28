extends SceneTree
## Pictures of the east and west cliff walls (docs/cliff_sides.md, docs/shots/cliff_sides/), per map:
##  - <tag>_<map>_ramp_east / _ramp_west: the first sideways ramp of each way, empty, at zoom 1.5,
##  - <tag>_<map>_plateau: a small plateau whole, all four edges in sight,
##  - <tag>_<map>_foot: (units=1) a Musketeer at the foot of an east wall and one at a west wall, zoom 3.
## It also prints the maps' 2-wide ramps (a ramp whose rows are 2 cells across); list=1 only that
## (it runs headless too: godot --headless --script res://tools/shot_cliff_sides.gd -- list=1).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_cliff_sides.gd -- out=docs/shots/cliff_sides tag=after [maps=greenhold,frostfang] [units=1]

var main: Node
var g
var t := 0.0
var started := false
var out := "user://cliff_sides"
var tag := "after"
var maps: Array = []
var units := false
var list := false             # list=1: only print the 2-wide ramps, no pictures
var rz := 1.5                 # the ramps' zoom
var map_i := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"tag": tag = kv[1]
			"maps": maps = Array(kv[1].split(","))
			"units": units = kv[1] == "1"
			"rz": rz = float(kv[1])
			"list": list = kv[1] == "1"
	if maps.is_empty():
		maps = MapGen.all_ids()
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if map_i < 0 and t > 0.2:
		_next_map()
		return false
	if main.game == null or started:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	if t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		if g.controls:
			g.controls.process_mode = Node.PROCESS_MODE_DISABLED
		_run_map()
	return false


func _next_map() -> void:
	map_i += 1
	if map_i >= maps.size():
		print("cliff sides: done")
		quit(0)
		return
	started = false
	t = 0.3
	if main.game:
		main.game.queue_free()
		main.game = null
	seed(77)
	main.start({"map": maps[map_i], "seed": 77, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})


func _run_map() -> void:
	g.explored.fill(1)
	if g.fog_sprite:
		g.fog_sprite.visible = false
	for u in g.units.duplicate():
		g.consume_unit(u)
	await physics_frame
	var map: String = maps[map_i]
	var done := {}
	var two: Array = []
	for r in MapGen.ramp_parts(g.mapgen):
		var d: Vector2i = r["down"]
		if (r["rows"][0] as Array).size() <= 2:
			two.append(str(r["rows"][0][0]))
		if d.y != 0 or list:
			continue
		var dn := "east" if d.x > 0 else "west"
		if done.has(dn) or not _clear(r["rows"][0][0]):
			continue
		done[dn] = true
		var a: Vector2 = (Vector2(r["rows"][0][0]) + Vector2(r["rows"][-1][-1])) * 0.5 + Vector2(0.5, 0.5)
		await _aim(a * Game.T, rz)
		_shot("%s_%s_ramp_%s%s" % [tag, map, dn, "" if rz == 1.5 else "_z%d" % int(rz)])
	if not two.is_empty():
		print("two-wide ramps on %s: %d at %s" % [map, two.size(), ", ".join(two)])
	if list:
		_next_map()
		return
	var pl := _plateau()
	if pl.size.x > 0:
		var z := clampf(minf(1600.0 / ((pl.size.x + 4) * Game.T), 900.0 / ((pl.size.y + 4) * Game.T)), 0.5, 2.0)
		await _aim((Vector2(pl.position) + Vector2(pl.size) * 0.5) * Game.T, z)
		_shot("%s_%s_plateau" % [tag, map])
	if units:
		await _feet(map)
	_next_map()


## A ramp spot with no buildings near (a start would hide it).
func _clear(c: Vector2i) -> bool:
	var mid: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * Game.T
	for b in g.buildings:
		if b.rect().get_center().distance_to(mid) < 7 * Game.T:
			return false
	return true


## The smallest plateau (a connected patch of high ground and its cliffs) at least 6 x 5 cells
## and no more than 30 x 18, with no buildings on it; its cell rectangle.
func _plateau() -> Rect2i:
	var seen := PackedByteArray()
	seen.resize(g.W * g.H)
	var best := Rect2i()
	var best_n := 1 << 30
	for y in g.H:
		for x in g.W:
			var i: int = y * g.W + x
			if seen[i] == 1 or g.height[i] != 1 or g.ramp[i] != 0:
				continue
			var todo: Array = [Vector2i(x, y)]
			seen[i] = 1
			var r := Rect2i(x, y, 1, 1)
			var n := 0
			while not todo.is_empty():
				var c: Vector2i = todo.pop_back()
				n += 1
				r = r.expand(c).expand(c + Vector2i.ONE)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var m: Vector2i = c + d
					if g.in_map(m) and seen[g.idx(m)] == 0 and g.height[g.idx(m)] == 1 and g.ramp[g.idx(m)] == 0:
						seen[g.idx(m)] = 1
						todo.append(m)
			if r.size.x >= 6 and r.size.y >= 5 and r.size.x <= 30 and r.size.y <= 18 and n < best_n \
					and _clear(r.get_center()):
				best = r
				best_n = n
	return best


## A Musketeer at the foot of an east-facing wall and one at the foot of a west-facing wall (the
## straight stretch of 5 cells nearest the map's middle).
func _feet(map: String) -> void:
	for dx in [1, -1]:
		var spot := Vector2i(-1, -1)
		var best := 1e9
		var mid := Vector2(g.W, g.H) * 0.5
		for y in range(4, g.H - 4):
			for x in range(4, g.W - 4):
				var i: int = y * g.W + x
				if g.cliff[i] != 1:
					continue
				var ok := true
				for k in range(-2, 3):
					var c := Vector2i(x, y + k)
					var lo := c + Vector2i(dx, 0)
					if g.cliff[g.idx(c)] != 1 or g.height[g.idx(lo)] != 0 or g.ramp[g.idx(lo)] != 0 or not g._walkable(lo):
						ok = false
						break
				if ok and Vector2(x, y).distance_to(mid) < best and _clear(Vector2i(x, y)):
					spot = Vector2i(x, y)
					best = Vector2(x, y).distance_to(mid)
		if spot.x < 0:
			continue
		var lo := spot + Vector2i(dx, 0)
		var us: Array = []
		for k in [-1, 1]:
			var u = g._add_unit("musketeer", 0, (Vector2(lo + Vector2i(0, k)) + Vector2(0.5, 0.5)) * Game.T)
			if u:
				us.append(u)
		await _aim((Vector2(spot) + Vector2(0.5 + dx * 0.5, 0.5)) * Game.T, 3.0)
		_shot("%s_%s_foot_%s" % [tag, map, "east" if dx > 0 else "west"])
		for u in us:
			if is_instance_valid(u) and not u.dead:
				g.consume_unit(u)
		await physics_frame


func _aim(at: Vector2, z: float) -> void:
	var cam: Camera2D = g.camera
	cam.position = at
	cam.zoom = Vector2(z, z)
	cam.reset_smoothing()
	for i in 30:
		await process_frame


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(out.path_join(name + ".png"))
	print("shot " + out.path_join(name + ".png"))
