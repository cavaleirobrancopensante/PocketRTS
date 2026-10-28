extends SceneTree
## Pictures of the ramps (docs/ramp_funnel.md, docs/shots/ramp_funnel/): one ramp of each direction,
## with Clockwork units on the move:
##  - a Clock Soldier walking up from below the foot (straight on at the bottom end),
##  - a Clock Soldier coming from beside the bottom row, stepping onto it from the side and walking up,
##  - two Clock Soldiers and a Great Winder beside the closed rows, pushing straight at the ramp
##    (their way forced onto the ramp beside them): the rails stop them.
## The units' paths are drawn as thin green lines. "before=1" builds the map with the old notch and no
## rails (MapGen.no_funnel); "grid=1" shades the cells that can't be walked on (red) and the rails'
## edges (yellow). tools/ramp_funnel_sheet.py puts the pictures beside the owner's spec and 0.15.3.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_ramp_funnel.gd -- out=docs/shots/ramp_funnel [before=1] [grid=1] [maps=greenhold] [dirs=south,north]

var main: Node
var g
var t := 0.0
var started := false
var out := "user://ramp_funnel"
var before := false
var grid := false
var maps: Array = []
var want_dirs: Array = ["south", "north", "east", "west"]
var map_i := -1
var done_dirs := {}


class Marks extends Node2D:
	var cells: Array = []
	var edges: Array = []
	var units: Array = []
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		for c in cells:
			draw_rect(Rect2(Vector2(c) * Game.T, Vector2(Game.T, Game.T)), Color(1, 0.1, 0.1, 0.28))
			draw_rect(Rect2(Vector2(c) * Game.T, Vector2(Game.T, Game.T)), Color(1, 0.2, 0.2, 0.7), false, 1.0)
		for r in edges:
			draw_line((r as Rect2).position, (r as Rect2).end, Color(1, 0.9, 0.1, 0.9), 2.0)
		for u in units:
			if not is_instance_valid(u) or u.dead:
				continue
			var a: Vector2 = u.position
			for i in range(u.path_i, u.path.size()):
				draw_line(a, u.path[i], Color(0.3, 1.0, 0.4, 0.85), 1.5)
				a = u.path[i]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"before": before = kv[1] == "1"
			"grid": grid = kv[1] == "1"
			"maps": maps = Array(kv[1].split(","))
			"dirs": want_dirs = Array(kv[1].split(","))
	if maps.is_empty():
		maps = MapGen.all_ids()
	MapGen.no_funnel = before
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
	if map_i >= maps.size() or done_dirs.size() >= want_dirs.size():
		print("ramp shots: done %s" % str(done_dirs))
		quit(0)
		return
	started = false
	t = 0.3
	if main.game:
		main.game.queue_free()
		main.game = null
	seed(77)
	main.start({"map": maps[map_i], "seed": 77, "slots": [
		{"who": "you", "faction": "clockwork", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})


func _run_map() -> void:
	g.explored.fill(1)
	if g.fog_sprite:
		g.fog_sprite.visible = false
	for u in g.units.duplicate():
		g.consume_unit(u)
	await physics_frame
	var map: String = maps[map_i]
	for r in MapGen.ramp_parts(g.mapgen):
		var dn: String = _dir_name(r["down"])
		if not want_dirs.has(dn) or done_dirs.has(dn):
			continue
		if not _clear_round(r):
			continue
		done_dirs[dn] = map
		await _ramp_case(map, dn, r)
	_next_map()


static func _dir_name(d: Vector2i) -> String:
	if d == Vector2i(0, 1):
		return "south"
	if d == Vector2i(0, -1):
		return "north"
	return "east" if d == Vector2i(1, 0) else "west"


## Nothing built near the ramp (a start's buildings would hide it).
func _clear_round(r: Dictionary) -> bool:
	var mid: Vector2 = (Vector2(r["rows"][0][0]) + Vector2(0.5, 0.5)) * Game.T
	for b in g.buildings:
		if b.rect().get_center().distance_to(mid) < 7 * Game.T:
			return false
	return true


func _ramp_case(map: String, dn: String, r: Dictionary) -> void:
	var down: Vector2i = r["down"]
	var side: Vector2i = r["side"]
	var rows: Array = r["rows"]
	var n: int = rows.size()
	var mid: int = rows[0].size() / 2
	var cen := func(c: Vector2i) -> Vector2: return (Vector2(c) + Vector2(0.5, 0.5)) * Game.T
	var us: Array = []
	var push: Array = []
	# (the camera first, so the picture catches the walkers on their way)
	await _aim((cen.call(rows[0][mid]) + cen.call(rows[-1][mid])) * 0.5)
	var plan: Array = [
		# straight on at the bottom end, up to the landing
		["clock_soldier", rows[-1][mid] + down * 3, rows[0][mid] - down * 2, false],
		# from beside the bottom row: onto it from the side, then up
		["clock_soldier", rows[-1][-1] + side * 3, rows[0][-1] - down * 2, false],
		# beside the closed rows, pushing straight at the ramp beside them
		["clock_soldier", rows[1][0] - side * 2, rows[1][0], true],
		["clock_soldier", rows[mini(2, n - 2)][0] - side * 2 + down * 0, rows[mini(2, n - 2)][0], true],
		["great_winder", rows[1][-1] + side * 3, rows[1][-1], true],
	]
	for p in plan:
		var u: Unit = g._add_unit(p[0], 0, cen.call(p[1]))
		if u:
			u.cmd_move(cen.call(p[2]))
			us.append(u)
			if p[3]:
				push.append([u, cen.call(p[2])])
	var m := Marks.new()
	m.z_index = 50
	m.units = us
	if grid:
		var area := Rect2i(rows[0][0] - side * 6 - down * 4, Vector2i.ZERO).expand(rows[-1][-1] + side * 6 + down * 4)
		for y in range(area.position.y, area.end.y + 1):
			for x in range(area.position.x, area.end.x + 1):
				var c := Vector2i(x, y)
				if g.in_map(c) and not g._walkable(c):
					m.cells.append(c)
		for rl in g.rails:
			m.edges.append(rl["rect"])
	g.add_child(m)
	for i in 3:
		await physics_frame
	# (the pushers' way forced straight at the ramp: as a player's unit would try if it could)
	for pu in push:
		var u: Unit = pu[0]
		u.path = PackedVector2Array([pu[1]])
		u.path_i = 0
		u.repath_t = 999.0
	for i in 55:
		await physics_frame
		for pu in push:
			var u: Unit = pu[0]
			if u.path.size() != 1:
				u.path = PackedVector2Array([pu[1]])
				u.path_i = 0
				u.repath_t = 999.0
	var tag := "%s_%s_%s%s" % ["before" if before else "new", dn, map, "_grid" if grid else ""]
	_shot(tag)
	m.queue_free()
	for u in us:
		if is_instance_valid(u) and not u.dead:
			g.consume_unit(u)
	await physics_frame


func _aim(at: Vector2) -> void:
	var cam: Camera2D = g.camera
	cam.position = at
	cam.zoom = Vector2(2.0, 2.0)
	cam.reset_smoothing()
	for i in 30:
		await process_frame


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(out.path_join(name + ".png"))
	print("shot " + out.path_join(name + ".png"))
