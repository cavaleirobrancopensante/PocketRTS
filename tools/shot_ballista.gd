extends SceneTree
## Screenshots of the SPRING BALLISTA (scripts/ballista.gd, docs/ballista.md) in the CLOCKWORK LAB: the machine in its five
## views (loaded and fired), with its built-in crewman; four Winders boarding it; the crew pushing it across the field;
## the crew cranking while it winds; a bolt in flight through a line of Crown Cannons and Musketeers (sparks on each one
## hit); a bolt into a Crown gate; a crewman shot down; the card. Plus a run of frames for a GIF of a shot and a reload.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_ballista.gd -- <outdir>
## Writes <outdir>/*.png and <outdir>/gif/f_NNN.png (frames for a GIF, not kept in the repository: docs/shots/ballista/
## reload_and_shot.gif was made from them with PIL, cropped to the middle and shrunk).
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const K := Defs.BALLISTA_KIND


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start_lab()
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _snap(name: String, wait := 0.5) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _cam(p: Vector2, z: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(z, z)
	await _frames(30)


func _hint(on: bool) -> void:
	for c in g.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 40:
			c.visible = on


func _dummy(kind: String, p: Vector2, still := true) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.auto_work = false
	u.cmd_hold()
	if still:
		u.d = u.d.duplicate()
		u.d["damage"] = 0
	return u


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _open_ground(hall: Building) -> Vector2:
	# open low ground away from every building (no gear rings in the picture): 15 x 29 walkable cells, nearest the hall
	var near_b := func(c: Vector2i) -> bool:
		for bd in g.buildings:
			if not bd.dead and Vector2(bd.cell - c).length() < 13.0:
				return true
		return false
	var best := Vector2i(-1, -1)
	var bd2 := INF
	for y in range(14, Game.H - 14, 2):
		for x in range(16, Game.W - 16, 2):
			var c := Vector2i(x, y)
			var d := Vector2(c - hall.cell).length()
			if d >= bd2 or near_b.call(c):
				continue
			var ok := true
			for yy in range(-5, 6):
				for xx in range(-11, 12):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)] or g.solid[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd2 = d
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 260)


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _clear_foes() -> void:
	for u in g.units.duplicate():
		if u.team != g.human and not u.dead:
			u.visible = false
			u.die()


func _run() -> void:
	_hint(false)
	_ui(false)
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			hall = b
	var at := _open_ground(hall)
	print("stage at ", g.cell_of(at), " hall ", hall.cell, " map ", Game.W, "x", Game.H)
	# ---- the five views, loaded and fired, each with its own crewman
	var views: Array = []
	for i in 5:
		var f := Vector2.from_angle(PI * 0.5 - i * PI / 4.0)
		var bl: Unit = g._add_unit(K, g.human, _open(at + Vector2(-360 + i * 180, -110)))
		bl.facing = f
		bl.cmd_stop()
		views.append(bl)
		var bf: Unit = g._add_unit(K, g.human, _open(at + Vector2(-360 + i * 180, 70)))
		bf.facing = f
		bf.cmd_stop()
		bf.cooldown = 30.0
		bf.loaded = false
		views.append(bf)
	await _cam(at + Vector2(0, -20), 1.6)
	await _snap("views_loaded_top_fired_bottom", 0.8)
	for u in views:
		u.visible = false
		u.die()
	await _frames(10)
	# ---- boarding: four Winders walk over
	var b: Unit = g._add_unit(K, g.human, _open(at + Vector2(-260, 0)))
	b.facing = Vector2.RIGHT
	b.cmd_stop()
	var ws: Array = []
	for i in 4:
		var w: Unit = g._add_unit("winder", g.human, _open(at + Vector2(-420 + i * 30, 120)))
		w.auto_work = false
		w.cmd_stop()
		ws.append(w)
	g.load_order(ws, [b])
	await _cam(b.position + Vector2(-40, 30), 2.0)
	await _snap("boarding", 1.0)
	await _wait(func() -> bool: return Ballista.crew_of(b).size() == 4, 15.0)
	g.set_selection([b])
	await _snap("crewed_selected", 0.6)
	g.set_selection([])
	# ---- pushing: it rolls east, the crew shoving from behind
	b.cmd_move(b.position + Vector2(300, 0))
	await _frames(40)
	g.camera.position = b.position
	await _frames(25)
	await _snap("crew_push_e", 0.0)
	b.cmd_move(b.position + Vector2(0, 220))
	await _frames(50)
	g.camera.position = b.position + Vector2(0, -20)
	await _frames(20)
	await _snap("crew_push_s", 0.0)
	b.cmd_move(b.position + Vector2(160, -160))
	await _frames(50)
	g.camera.position = b.position
	await _frames(20)
	await _snap("crew_push_ne", 0.0)
	b.cmd_stop()
	await _frames(30)
	# ---- the line: Crown Cannons and Musketeers in a row east of it
	b.facing = Vector2.RIGHT
	b.cooldown = 99.0          # (it holds its fire until the camera is ready)
	b.loaded = false
	var p0: Vector2 = b.position
	var foes: Array = []
	foes.append(_dummy("musketeer", _open(p0 + Vector2(190, 0))))
	foes.append(_dummy("cannon", _open(p0 + Vector2(240, 4))))
	foes.append(_dummy("musketeer", _open(p0 + Vector2(290, -2))))
	foes.append(_dummy("cannon", _open(p0 + Vector2(345, 6))))
	await _frames(10)
	b.cooldown = 0.0
	b.loaded = true
	g.camera.position = p0 + Vector2(160, 0)
	g.camera.zoom = Vector2(1.8, 1.8)
	await _frames(20)
	var n0: int = b.bolts
	b.cmd_attack(foes[0])
	b.cooldown = 0.0
	await _wait(func() -> bool: return b.bolts > n0, 4.0)
	var gi := [0]
	for k in 2:
		await physics_frame
	await _snap("bolt_through_the_line", 0.0)
	print("line hit: ", b.bolt_hits.map(func(e) -> String: return e.kind))
	for k in 6:
		await physics_frame
	await _snap("bolt_through_the_line_2", 0.0)
	# its crew crank while it winds (GIF: the reload, then the next shot)
	b.cmd_hold()
	await _frames(20)
	g.camera.zoom = Vector2(2.4, 2.4)
	g.camera.position = p0 + Vector2(40, 0)
	await _frames(20)
	await _snap("crew_crank", 0.0)
	for f in 75:
		for k in 2:
			await physics_frame
		root.get_viewport().get_texture().get_image().save_png("%s/gif/f_%03d.png" % [out, gi[0]])
		gi[0] += 1
	for u in foes:
		u.visible = false
		u.die()
	await _frames(10)
	# ---- a gate: a palisade with a gate across its way
	var gc: Vector2i = g.cell_of(p0 + Vector2(240, 0))
	var gate: Building = null
	for dy in range(-2, 3):
		var c := gc + Vector2i(0, dy)
		if g.is_free(c):
			var kd := "gate" if dy == 0 else "wall"
			var bb: Building = g._add_building(kd, 1, c, true)
			if dy == 0:
				gate = bb
	if gate:
		g.relink_walls(gate.cell)
	b.cooldown = 99.0
	var behind := _dummy("musketeer", _open(p0 + Vector2(300, 0)))
	g.camera.zoom = Vector2(1.8, 1.8)
	g.camera.position = p0 + Vector2(130, -10)
	await _frames(25)
	if gate:
		n0 = b.bolts
		b.cmd_attack(gate)
		b.cooldown = 0.0
		await _wait(func() -> bool: return b.bolts > n0, 4.0)
		for k in 2:
			await physics_frame
		await _snap("bolt_into_gate", 0.0)
		print("gate hit: ", b.bolt_hits.map(func(e) -> String: return e.kind), " gate hp ", gate.hp, "/", gate.max_hp, " man behind ", behind.hp)
	behind.visible = false
	behind.die()
	# ---- the counter: a Musketeer shoots the crew
	b.cmd_hold()
	var sniper: Unit = g._add_unit("musketeer", 1, _open(p0 + Vector2(-60, 190)))
	sniper.max_hp = 99999.0
	sniper.hp = 99999.0
	sniper.cmd_attack(Ballista.crew_of(b)[0])
	g.camera.position = p0 + Vector2(-30, 80)
	await _wait(func() -> bool: return Ballista.crew_of(b).size() < 4, 25.0)
	await _snap("crewman_shot", 0.3)
	g.set_selection([b])
	_ui(true)
	_hint(false)
	await _snap("card_after", 0.6)
	print("ALL SHOTS")
	quit(0)


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await physics_frame
		w += 1.0 / 30.0
