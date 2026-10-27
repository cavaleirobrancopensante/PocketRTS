extends SceneTree
## Screenshots of the Clockwork units' palette (brass + player colour, tools/cw_palette.py) in the CLOCKWORK LAB, on open
## ground away from the buildings: the six units standing together (Clock Soldier, Springer, Pendulum, Netter on the ground, a
## Swift and a Ticking Owl in the air), the Clock Soldier's size between a Musketeer, a Springer and a Labourer, and one action
## frame each (the Soldier's swing, the Springer's shot, the Pendulum's swing, the Netter's shot, the Swift's stab, the Owl's
## swoop), every picture in three player colours (the game frozen on the moment, the colour swapped); plus the frames of
## two GIFs: the Springer firing its two launchers in turn, the Swift's painted peck.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_palette.gd -- <outdir>
## Writes <outdir>/idle_<colour>.png, idle_se_<colour>.png, size_<colour>.png (the whole screen),
## <outdir>/act_<unit>_<colour>.png (640 x 400 round the unit), <outdir>/gif_springer/f_NNN.png and gif_swift/f_NNN.png
## (+ frames.txt: the game clock of each frame).
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const COLOURS := [["red", 1], ["blue", 0], ["green", 2]]     # [name, Defs.PALETTE index]


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif_springer")
	DirAccess.make_dir_recursive_absolute(out + "/gif_swift")
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


func _snap(name: String, wait := 0.3) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await process_frame
		w += 1.0 / 60.0


## The player's colour on every unit of team 0 (its shader's key reds), now.
func _colour(c: int) -> void:
	g.colours[0] = c
	for u in g.units:
		if u.team == 0 and is_instance_valid(u) and u._mat:
			u._mat.set_shader_parameter("team", g.team_colour(0))


## The game stopped where it is, one picture per player colour, then let go.
func _frozen_all(name: String) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	for cn in COLOURS:
		_colour(int(cn[1]))
		await _snap("%s_%s" % [name, cn[0]], 0.0)
	_colour(0)
	g.process_mode = Node.PROCESS_MODE_INHERIT


func _mine(kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 0, p)
	u.auto_work = false
	u.cmd_hold()
	return u


## An enemy of `kind` at p that does not die (a target); it neither moves nor fights.
func _dummy(kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.auto_work = false
	u.cmd_hold()
	u.d = u.d.duplicate()
	u.d["damage"] = 0
	return u


func _gone(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	g.selection.erase(u)
	u.visible = false
	if not u.dead:
		u.die()
	u.visible = false


## Open low ground away from every building (a 21 x 15 tile patch walkable and flat, no building within 16 tiles), the
## nearest such spot to the base: the stage.
func _open_ground(hall: Building) -> Vector2:
	var centres: Array = []
	for b in g.buildings:
		if not b.dead:
			centres.append(b.center())
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 60, hall.cell.y + 61, 2):
		for x in range(hall.cell.x - 60, hall.cell.x + 61, 2):
			var c := Vector2i(x, y)
			if not g.in_map(c) or c.x < 14 or c.y < 14 or c.x > Game.W - 14 or c.y > Game.H - 14:
				continue
			var d := Vector2(c - hall.cell).length()
			if d >= bd:
				continue
			var p: Vector2 = g.cell_center(c)
			if centres.any(func(q: Vector2) -> bool: return q.distance_to(p) < 16.0 * Defs.TILE):
				continue
			var ok := true
			for yy in range(-7, 8):
				for xx in range(-10, 11):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)] or g.solid[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd = d
	print("stage: ", best, " ", bd)
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 260)


## The game stopped where it is, one picture per player colour of the 640 x 400 screen px round world point `at`, then
## let go.
func _frozen_round(name: String, at: Vector2) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	var scr: Vector2 = root.get_viewport().get_canvas_transform() * at
	var box := Rect2i(int(scr.x) - 320, int(scr.y) - 220, 640, 400)
	box.position.x = clampi(box.position.x, 0, 1280 - 640)
	box.position.y = clampi(box.position.y, 0, 720 - 400)
	for cn in COLOURS:
		_colour(int(cn[1]))
		await process_frame
		await process_frame
		root.get_viewport().get_texture().get_image().get_region(box).save_png("%s/%s_%s.png" % [out, name, cn[0]])
	_colour(0)
	g.process_mode = Node.PROCESS_MODE_INHERIT


## Every 2nd rendered frame for `secs` of game time (slowed to `scale`, so no sprite frame is skipped), the camera where
## it is, the middle 640 x 360 of the screen: <out>/<dir>/f_NNN.png (and the game clock of each in frames.txt, for the
## GIF's frame times).
func _gif(dir: String, secs: float, scale := 0.35) -> void:
	var n := 0
	var k := 0
	Engine.time_scale = scale
	var t0: float = g.clock
	var log := FileAccess.open("%s/%s/frames.txt" % [out, dir], FileAccess.WRITE)
	while g.clock - t0 < secs:
		await process_frame
		k += 1
		if k % 2 == 0:
			continue
		var img := root.get_viewport().get_texture().get_image()
		var sz := img.get_size()
		img.get_region(Rect2i(sz.x / 2 - 320, sz.y / 2 - 180, 640, 360)).save_png("%s/%s/f_%03d.png" % [out, dir, n])
		log.store_line("%d %.3f" % [n, g.clock - t0])
		n += 1
	log.close()
	Engine.time_scale = 1.0
	print("%s: %d frames" % [dir, n])


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "clocktower":
			hall = b
	if hall == null:
		print("NO CLOCKTOWER")
		quit(1)
		return
	_ui(false)
	g.reveal = true
	root.get_viewport().warp_mouse(Vector2(2, 2))       # (no hover ring on a unit)
	# (the Lab's own army out of the picture)
	for u in g.units.duplicate():
		if u.team == 0 and not (u.kind in ["winder"]):
			_gone(u)
	var open := _open_ground(hall)
	# ---- the six standing together, facing the camera
	var kinds := [Defs.CUCKOO, "clock_soldier", Defs.SPRINGER, Defs.PENDULUM, Defs.NETTER, Defs.OWL]
	var line: Array = []
	for i in kinds.size():
		var u := _mine(kinds[i], open + Vector2(-125.0 + 50.0 * float(i), 0.0))
		u.facing = Vector2.DOWN
		line.append(u)
	g.camera.position = open + Vector2(0, -24)
	g.camera.zoom = Vector2(3.6, 3.6)
	await create_timer(1.0).timeout
	await _frozen_all("idle")
	# the same, three-quarter view (facing down and right)
	for u in line:
		(u as Unit).facing = Vector2(1, 1).normalized()
	await create_timer(0.6).timeout
	await _frozen_all("idle_se")
	for u in line:
		_gone(u)
	await create_timer(0.3).timeout
	# ---- the size: the Clock Soldier (42 px since 0.14.32) between a Musketeer and a Springer (59), facing the camera
	var size_line: Array = []
	var size_kinds := ["musketeer", "clock_soldier", Defs.SPRINGER, "labourer", "clock_soldier"]
	for i in size_kinds.size():
		var su := _mine(size_kinds[i], open + Vector2(-80.0 + 40.0 * float(i), 0.0))
		su.facing = Vector2.DOWN
		size_line.append(su)
	g.camera.position = open + Vector2(0, -20)
	g.camera.zoom = Vector2(4.5, 4.5)
	await create_timer(0.8).timeout
	await _frozen_all("size")
	for u in size_line:
		_gone(u)
	await create_timer(0.3).timeout
	# ---- the Clock Soldier's swing (the sword raised, the 3rd frame)
	var cs := _mine("clock_soldier", open)
	var foe := _dummy("raptor", open + Vector2(24, 10))
	g.camera.position = open + Vector2(10, -20)
	g.camera.zoom = Vector2(4.5, 4.5)
	await create_timer(0.4).timeout
	Engine.time_scale = 0.3
	cs.cmd_attack(foe)
	await _wait(func() -> bool: return cs.anim == "attack" and cs.frame_i == 2, 20.0)
	Engine.time_scale = 1.0
	await _frozen_round("act_soldier", cs.position + Vector2(10, -20))
	_gone(cs)
	_gone(foe)
	# ---- the Springer's shot: the next screw leaving, the burst at the tip. Facing the camera (the target due south, a
	# Raptor that stands its ground: a Labourer runs and the Springer would follow), so both launchers show.
	var jk := _mine(Defs.SPRINGER, open)
	var tgt := _dummy("raptor", open + Vector2(10, 130))
	g.camera.position = open + Vector2(0, -12)
	g.camera.zoom = Vector2(3.2, 3.2)
	await create_timer(0.4).timeout
	Engine.time_scale = 0.3
	jk.cmd_attack(tgt)
	var s0 := jk.shots
	await _wait(func() -> bool: return jk.shots > s0, 20.0)
	Engine.time_scale = 1.0
	await _frozen_round("act_springer", jk.position + Vector2(0, -12))
	# ---- its GIF: two launchers in turn
	await _gif("gif_springer", 3.0, 0.15)
	_gone(jk)
	_gone(tgt)
	# ---- the Pendulum's swing (the blow)
	var pd := _mine(Defs.PENDULUM, open)
	var crowd: Array = []
	for a in [-30.0, 0.0, 30.0]:
		crowd.append(_dummy("raptor", open + Vector2.from_angle(deg_to_rad(a)) * 42.0))
	g.camera.position = open + Vector2(20, -30)
	g.camera.zoom = Vector2(4.0, 4.0)
	await create_timer(0.4).timeout
	Engine.time_scale = 0.3
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(crowd[1])
	await _wait(func() -> bool: return pd.anim == "attack" and pd.frame_i >= 4, 20.0)
	Engine.time_scale = 1.0
	await _frozen_round("act_pendulum", pd.position + Vector2(20, -35))
	_gone(pd)
	for u in crowd:
		_gone(u)
	# ---- the Netter's shot (the net in flight)
	var nt := _mine(Defs.NETTER, open)
	var br := _dummy("brute", open + Vector2(100, -10))
	g.camera.position = open + Vector2(50, -20)
	g.camera.zoom = Vector2(3.0, 3.0)
	await create_timer(0.4).timeout
	nt.cooldown = 0.0
	Engine.time_scale = 0.25
	nt.cmd_attack(br)
	await _wait(func() -> bool: return nt.nets > 0 and is_instance_valid(nt.last_net) and nt.last_net.t > nt.last_net.duration * 0.35, 20.0)
	Engine.time_scale = 1.0
	await _frozen_round("act_netter", nt.position + Vector2(50, -20))
	_gone(nt)
	_gone(br)
	# ---- the Swift's stab
	var sw := _mine(Defs.CUCKOO, open)
	var prey := _dummy("balloon", open + Vector2(56, -6))
	g.camera.position = open + Vector2(28, -40)
	g.camera.zoom = Vector2(4.5, 4.5)
	await create_timer(0.5).timeout
	Engine.time_scale = 0.25
	sw.cmd_attack(prey)
	await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i == 2, 20.0)
	Engine.time_scale = 1.0
	await _frozen_round("act_swift", sw.position + Vector2(28, -45))
	# its GIF: the painted peck
	g.camera.position = sw.position + Vector2(28, -40)
	await _gif("gif_swift", 2.6, 0.15)
	_gone(sw)
	_gone(prey)
	# ---- the Owl's swoop
	var ow := _mine(Defs.OWL, open)
	var mouse := _dummy("raptor", open + Vector2(40, 14))     # (stands its ground: a Labourer runs and the Owl follows)
	g.camera.position = open + Vector2(20, -40)
	await create_timer(0.5).timeout
	print("owl at ", ow.position, " dead ", ow.dead, " visible ", ow.visible, " mouse at ", mouse.position)
	Engine.time_scale = 0.25
	ow.cmd_attack(mouse)
	await _wait(func() -> bool: return ow.anim == "attack" and ow.frame_i == 3, 20.0)
	Engine.time_scale = 1.0
	print("owl swoop: anim ", ow.anim, " frame ", ow.frame_i, " at ", ow.position)
	await _frozen_round("act_owl", ow.position + Vector2(15, -18))
	quit(0)
