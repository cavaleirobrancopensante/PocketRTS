extends SceneTree
## Screenshots of the Clockwork units' palette (brass + player colour, tools/cw_palette.py) in the CLOCKWORK LAB: the six
## units standing together (Clock Soldier, Jack, Pendulum, Netter on the ground, a Swift and a Ticking Owl in the air) and
## one action frame each (the Soldier's swing, the Jack's shot, the Pendulum's swing, the Netter's shot, the Swift's stab,
## the Owl's swoop), every picture in three player colours (the game frozen on the moment, the colour swapped); plus the
## frames of two GIFs: the Jack firing its two launchers in turn, the Swift's painted peck.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_palette.gd -- <outdir>
## Writes <outdir>/idle_<colour>.png, <outdir>/act_<unit>_<colour>.png (the camera on the unit: crop the middle),
## <outdir>/gif_jack/f_NNN.png and <outdir>/gif_swift/f_NNN.png.
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const COLOURS := [["red", 1], ["blue", 0], ["green", 2]]     # [name, Defs.PALETTE index]


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif_jack")
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


## Open low ground near the base (every cell within 6 tiles walkable): the stage.
func _open_ground(hall: Building) -> Vector2:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 34, hall.cell.y + 35):
		for x in range(hall.cell.x - 34, hall.cell.x + 35):
			var c := Vector2i(x, y)
			if not g.in_map(c) or c.x < 14 or c.y < 14 or c.x > Game.W - 14 or c.y > Game.H - 14:
				continue
			var d := Vector2(c - hall.cell).length()
			if d >= bd or d < 14.0:
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
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 260)


## Every 2nd rendered frame for `secs` of game time (slowed), the camera where it is, the middle 640 x 360 of the screen:
## <out>/<dir>/f_NNN.png (and the game clock of each in frames.txt).
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
	# (the Lab's own army out of the picture)
	for u in g.units.duplicate():
		if u.team == 0 and not (u.kind in ["winder"]):
			_gone(u)
	var open := _open_ground(hall)
	# ---- the six standing together, facing the camera
	var kinds := [Defs.CUCKOO, "clock_soldier", Defs.JACK, Defs.PENDULUM, Defs.NETTER, Defs.OWL]
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
	# ---- the size: the Clock Soldier (42 px since 0.14.32) between a Musketeer and a Jack (59), facing the camera
	var size_line: Array = []
	var size_kinds := ["musketeer", "clock_soldier", Defs.JACK, "labourer", "clock_soldier"]
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
	await _frozen_all("act_soldier")
	_gone(cs)
	_gone(foe)
	# ---- the Jack's shot (the screw leaving, the burst)
	var jk := _mine(Defs.JACK, open)
	var tgt := _dummy("labourer", open + Vector2(120, 40))
	g.camera.position = open + Vector2(40, -10)
	await create_timer(0.4).timeout
	Engine.time_scale = 0.3
	jk.cmd_attack(tgt)
	await _wait(func() -> bool: return jk.shots > 0 and String(jk.anim).begins_with("attack"), 20.0)
	Engine.time_scale = 1.0
	await _frozen_all("act_jack")
	# ---- its GIF: two launchers in turn
	g.camera.position = open + Vector2(50, -20)
	await _gif("gif_jack", 2.6)
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
	await _frozen_all("act_pendulum")
	_gone(pd)
	for u in crowd:
		_gone(u)
	# ---- the Netter's shot (the net in flight)
	var nt := _mine(Defs.NETTER, open)
	var br := _dummy("brute", open + Vector2(150, -10))
	g.camera.position = open + Vector2(60, -20)
	g.camera.zoom = Vector2(3.6, 3.6)
	await create_timer(0.4).timeout
	nt.cooldown = 0.0
	Engine.time_scale = 0.25
	nt.cmd_attack(br)
	await _wait(func() -> bool: return nt.nets > 0 and is_instance_valid(nt.last_net) and nt.last_net.t > nt.last_net.duration * 0.3, 20.0)
	Engine.time_scale = 1.0
	await _frozen_all("act_netter")
	_gone(nt)
	_gone(br)
	# ---- the Swift's stab and the Owl's swoop
	var sw := _mine(Defs.CUCKOO, open)
	var prey := _dummy("balloon", open + Vector2(56, -6))
	g.camera.position = open + Vector2(28, -40)
	g.camera.zoom = Vector2(4.5, 4.5)
	await create_timer(0.5).timeout
	Engine.time_scale = 0.25
	sw.cmd_attack(prey)
	await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i == 2, 20.0)
	Engine.time_scale = 1.0
	await _frozen_all("act_swift")
	# its GIF: the painted peck
	await _gif("gif_swift", 2.4, 0.3)
	_gone(sw)
	_gone(prey)
	var ow := _mine(Defs.OWL, open)
	var mouse := _dummy("labourer", open + Vector2(40, 14))
	g.camera.position = open + Vector2(20, -40)
	await create_timer(0.5).timeout
	Engine.time_scale = 0.25
	ow.cmd_attack(mouse)
	await _wait(func() -> bool: return ow.anim == "attack" and ow.frame_i == 3, 20.0)
	Engine.time_scale = 1.0
	await _frozen_all("act_owl")
	quit(0)
