extends SceneTree
## Screenshots of the two-armed Pendulum's LOW SWEEP (tools/pendulum_v2_guide/cut.py) in the CLOCKWORK LAB: its blows
## mowing through Raptors (light units: the bonus) seen from the side and from the front, close up and at 1x.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_pendulum_sweep.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false


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
		g.hud.visible = true
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


func _hint(on: bool) -> void:
	for c in g.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 40:
			c.visible = on


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await process_frame
		w += 1.0 / 60.0


## The game stopped where it is for a screenshot, then let go.
func _frozen(name: String) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.selection.clear()
	for u in g.units:
		u.selected = false
		u.flash = 0.0            # (no hit flash: the picture is of the swing)
		if u._mat:
			u._mat.set_shader_parameter("flash", 0.0)
	await process_frame
	await process_frame
	await _snap(name, 0.0)
	g.process_mode = Node.PROCESS_MODE_INHERIT


## An enemy of `kind` at p that does not die (a target); `still`: it neither moves nor fights.
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


## A unit off the picture: hidden and dead (not freed: lists may still hold it).
func _gone(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	g.selection.erase(u)
	u.visible = false
	if not u.dead:
		u.die()
	u.visible = false


func _mine(kind: String) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == kind and not u.dead)


## Open low ground near the base (every cell within 6 tiles walkable): the stage.
func _open_ground(hall: Building) -> Vector2:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 34, hall.cell.y + 35):
		for x in range(hall.cell.x - 34, hall.cell.x + 35):
			var c := Vector2i(x, y)
			if not g.in_map(c) or c.x < 12 or c.y < 12 or c.x > Game.W - 12 or c.y > Game.H - 12:
				continue
			var d := Vector2(c - hall.cell).length()
			if d >= bd or d < 14.0:
				continue
			var ok := true
			for yy in range(-6, 7):
				for xx in range(-8, 9):
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


## The mouse over the card button for `kind` (or labelled `lab`), so its tooltip shows.
## A target that never shoots back (no hit flash on the Pendulum).
func _quiet(u: Unit) -> Unit:
	u.hold_fire = true
	u.d["range"] = 1
	return u


func _raptors(pd: Unit, angles: Array, dist: float) -> Array:
	var crowd: Array = []
	for a in angles:
		var r := _quiet(_dummy("raptor", pd.position + Vector2.from_angle(deg_to_rad(a)) * dist))
		r.team = 1
		crowd.append(r)
	return crowd


func _blows(pd: Unit, tag: String, frames: Array, zooms: Array) -> void:
	await _wait(func() -> bool: return pd.anim == "attack_l", 20.0)     # (one pair first: it has turned to face them)
	Engine.time_scale = 0.2
	for anim in ["attack_r", "attack_l"]:
		for k in frames:
			await _wait(func() -> bool: return pd.anim == anim and pd.frame_i == k, 20.0)
			for z in zooms:
				g.camera.zoom = Vector2(z, z)
				await _frozen("%s_%s_%d_x%d" % [tag, anim, k + 1, int(z)])
	Engine.time_scale = 1.0


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "clocktower":
			hall = b
	_hint(false)
	_ui(false)
	g.reveal = true
	var open := _open_ground(hall)
	var pends := _mine(Defs.PENDULUM)
	for u in g.units.filter(func(u: Unit) -> bool: return u.team == g.human and not u.dead and u.kind != "winder"):
		if not (u in pends):
			u.position = open + Vector2(600, 600)
	var pd: Unit = pends[0]
	pends[1].position = open + Vector2(-400, 300)
	pends[1].cmd_stop()
	pd.position = open
	pd.cmd_stop()
	# ---- side view: Raptors at its feet to the east
	var crowd := _raptors(pd, [-35.0, 0.0, 35.0], 32.0)
	g.camera.position = pd.position + Vector2(14, -22)
	await create_timer(0.4).timeout
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(crowd[1])
	await _blows(pd, "side", [1, 3, 4], [3.0, 1.0])
	pd.cmd_stop()
	print("side: the sweep caught %d" % pd.last_hits)
	for u in crowd:
		_gone(u)
	# ---- front view: Raptors to its south
	crowd = _raptors(pd, [55.0, 90.0, 125.0], 32.0)
	g.camera.position = pd.position + Vector2(0, -16)
	await create_timer(0.3).timeout
	pd.facing = Vector2.DOWN
	pd.cmd_attack(crowd[1])
	await _blows(pd, "front", [1, 3, 4], [3.0, 1.0])
	print("front: the sweep caught %d" % pd.last_hits)
	pd.cmd_stop()
	quit()
