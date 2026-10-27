extends SceneTree
## Screenshots of the GREAT WINDER (scripts/great_winder.gd, docs/great_winder.md) in the CLOCKWORK LAB: its five views and
## the west mirror; walking with an army of Clock Soldiers and a Pendulum (selected: its winding ring); run-down soldiers
## (cold statues) inside its ring, then wound up again; mending a hurt Pendulum with its key arm; after a fight, sweeping
## the Clockwork wrecks (the Crown bodies are left lying); its card with the parts. Plus frames for GIFs of the walk and
## the sweep.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_great_winder.gd -- <outdir>
## Writes <outdir>/*.png and <outdir>/gif_walk/, gif_sweep/ f_NNN.png (frames for GIFs, not kept in the repository:
## docs/shots/great_winder/*.gif were made from them with PIL).
var main: Node
var g
var out := ""
var t := 0.0
var started := false
const K := Defs.GREAT_WINDER_KIND


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif_walk")
	DirAccess.make_dir_recursive_absolute(out + "/gif_sweep")
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


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _wait(cond: Callable, secs: float) -> void:
	var t0: float = g.clock
	while not cond.call() and g.clock - t0 < secs:
		await physics_frame


func _open_ground(hall: Building) -> Vector2:
	# open low ground away from every building and off the gear field (no rings in the picture; constructs run down)
	var near_b := func(c: Vector2i) -> bool:
		for bd in g.buildings:
			if not bd.dead and Vector2(bd.cell - c).length() < 13.0:
				return true
		return false
	var best := Vector2i(-1, -1)
	var bd2 := INF
	for y in range(18, Game.H - 18, 2):
		for x in range(24, Game.W - 24, 2):
			var c := Vector2i(x, y)
			var d := Vector2(c - hall.cell).length()
			if d >= bd2 or d < 24.0 or near_b.call(c) or g.in_field(g.human, g.cell_center(c)):
				continue
			var ok := true
			for yy in range(-4, 5):
				for xx in range(-8, 9):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)] or g.solid[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd2 = d
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 300)


func _gw(p: Vector2, f: Vector2) -> Unit:
	var u: Unit = g._add_unit(K, g.human, _open(p))
	u.facing = f
	u.cmd_stop()
	return u


func _soldier(kind: String, p: Vector2, team := -1) -> Unit:
	var u: Unit = g._add_unit(kind, g.human if team < 0 else team, _open(p))
	u.auto_work = false
	u.cmd_hold()
	return u


func _gone(list: Array) -> void:
	for u in list:
		if is_instance_valid(u) and not u.dead:
			g.units.erase(u)          # (gone, leaving no wreck for the sweep below)
			g.selection.erase(u)
			u.queue_free()
	await _frames(5)


func _run() -> void:
	_hint(false)
	_ui(false)
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			hall = b
	var at := _open_ground(hall)
	print("stage at ", g.cell_of(at), " in field ", g.in_field(g.human, at), " map ", Game.W, "x", Game.H, " hall ", hall.cell)
	# ---- the views: s, se, e, ne, n and the west mirror (sw, w, nw)
	var views: Array = []
	for i in 8:
		var f := Vector2.from_angle(PI * 0.5 - i * PI / 4.0)
		var x := -390 + (i % 4) * 260
		var y := -90 if i < 4 else 90
		var u := _gw(at + Vector2(x, y), f)
		u.auto_repair = false
		u.auto_sweep = false
		views.append(u)
	await _cam(at + Vector2(0, 0), 1.25)
	await _snap("views", 0.8)
	await _gone(views)
	# ---- walking with an army (selected: its ring)
	var army: Array = []
	var gw := _gw(at + Vector2(-330, 40), Vector2.RIGHT)
	for i in 8:
		army.append(_soldier("clock_soldier", at + Vector2(-250 + (i % 4) * 30, -30 + (i / 4) * 40)))
	army.append(_soldier("pendulum", at + Vector2(-170, 80)))
	for u in army:
		u.cmd_move(u.position + Vector2(380, 0))
	gw.cmd_move(gw.position + Vector2(380, 0))
	g.set_selection([gw])
	await _frames(60)
	await _cam(gw.position + Vector2(90, -20), 1.6)
	await _snap("walking_with_the_army", 0.0)
	var gi := 0
	g.camera.zoom = Vector2(2.6, 2.6)
	for f in 48:
		g.camera.position = gw.position + Vector2(0, -30)
		await _frames(2)
		root.get_viewport().get_texture().get_image().save_png("%s/gif_walk/f_%03d.png" % [out, gi])
		gi += 1
	await _frames(60)
	# ---- run-down soldiers inside its ring, then wound up again
	gw.cmd_stop()
	gw.auto_repair = false
	gw.auto_sweep = false
	gw.set_meta("gw_wind_t", -3.0)        # (its next winding pass waits 3 s: the statues stand for the picture)
	for u in army:
		u.cmd_hold()
		u.wind = 0.0
	await _frames(20)
	g.set_selection([gw])
	await _cam(gw.position + Vector2(40, -20), 1.5)
	await _snap("run_down_inside_the_ring", 0.0)
	for u in army:
		u.wind = maxf(u.wind, 0.45)     # (a few seconds later, fast-forwarded: its area winds them at 0.06 a second)
	await _frames(40)
	await _snap("wound_up_again", 0.0)
	g.set_selection([])
	# ---- mending a hurt Pendulum with its key arm
	var pend: Unit = army[army.size() - 1]
	for u in army:
		u.cmd_hold()
	gw.position = _open(army[0].position + Vector2(-120, 60))     # (the walk left it behind: it catches up)
	gw.cmd_stop()
	pend.position = _open(gw.position + Vector2(110, 10))
	pend.hp = pend.max_hp * 0.35
	gw.auto_repair = true
	await _wait(func() -> bool: return gw.work == "mending", 12.0)
	await _frames(20)
	await _cam((gw.position + pend.position) * 0.5 + Vector2(0, -20), 2.4)
	await _snap("mending_a_pendulum", 0.0)
	await _wait(func() -> bool: return pend.hp >= pend.max_hp, 20.0)
	# ---- a fight: Crown Musketeers shoot down some of the Clock Soldiers, then die themselves; it sweeps the wrecks
	var foes: Array = []
	for i in 4:
		foes.append(_soldier("musketeer", gw.position + Vector2(180 + i * 20, -60 + i * 30), 1))
	for i in 5:
		army[i].take_damage(100000.0, null)
	for f in foes:
		f.take_damage(100000.0, null)
	await _frames(60)
	gw.auto_sweep = true
	gw.cmd_stop()
	await _wait(func() -> bool: return gw.work == "sweeping", 15.0)
	await _frames(8)
	g.camera.zoom = Vector2(2.2, 2.2)
	g.camera.position = gw.position + Vector2(20, -20)
	await _frames(20)
	await _snap("sweeping_a_wreck", 0.0)
	gi = 0
	for f in 45:
		g.camera.position = gw.position + Vector2(20, -20)
		await _frames(2)
		root.get_viewport().get_texture().get_image().save_png("%s/gif_sweep/f_%03d.png" % [out, gi])
		gi += 1
	await _wait(func() -> bool: return gw.order == "idle" and gw.parts > 0 and not g.bodies.any(func(b) -> bool: return is_instance_valid(b) and b.team == g.human and String(b.d["faction"]) == "clockwork"), 40.0)
	await _frames(20)
	await _cam(gw.position + Vector2(100, -20), 1.6)
	await _snap("wrecks_swept_crown_bodies_left", 0.0)
	print("parts ", gw.parts, " swept ", g.bodies_swept)
	# ---- its card
	_ui(true)
	_hint(false)
	g.set_selection([gw])
	await _cam(gw.position + Vector2(0, 60), 1.6)
	await _snap("card", 0.6)
	print("done")
	quit()
