extends SceneTree
## Screenshots of the GREAT WINDER's SWEEP into cogs (owner, 2026-10-28; docs/great_winder.md): standing idle by its army,
## it rolls to a Clockwork wreck of its own side, sweeps it with its rollers ("+N cogs"), then an enemy Clockwork's wreck
## (the mirror match), rolls back to the army, and leaves a wreck with an enemy soldier near it. Helpers copied from
## tools/shot_great_winder.gd. Writes docs/shots/great_winder_sweep/*.png:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_great_winder_sweep.gd -- <outdir>
## (Old header of the copied helpers:) Screenshots of the GREAT WINDER (scripts/great_winder.gd, docs/great_winder.md) in the CLOCKWORK LAB: its five views and
## the west mirror; walking with an army of Clock Soldiers and a Pendulum (selected: its winding ring); run-down soldiers
## (cold statues) inside its ring, then wound up again; mending a hurt Pendulum with its key arm; after a fight, sweeping
## the Clockwork wrecks (the Crown bodies are left lying); its card. Plus frames for GIFs of the walk and
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
	DirAccess.make_dir_recursive_absolute(out)
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
			u.visible = false
			u.die()
	await _frames(5)


func _run() -> void:
	_hint(false)
	_ui(false)
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == "clocktower":
			hall = b
	var at := _open_ground(hall)
	print("stage at ", g.cell_of(at), " hall ", hall.cell, " map ", Game.W, "x", Game.H)
	var gw := _gw(at, Vector2(1, 0.4).normalized())
	gw.auto_repair = false
	var army: Array = []
	for i in 4:
		var s := _soldier("clock_soldier", at + Vector2(-70 + (i % 2) * 40, -50 + (i / 2) * 100))
		s.wind = 1.0
		army.append(s)
	var own := _soldier("clock_soldier", at + Vector2(150, 70))
	var foe_w := _soldier("clock_soldier", at + Vector2(-60, 170), 1)
	var crown := _soldier("musketeer", at + Vector2(120, -110), 1)
	gw.auto_sweep = false
	for u in [own, foe_w, crown]:
		u.take_damage(100000.0, null)
	await _frames(90)
	for b in g.bodies:
		if is_instance_valid(b):
			print("body ", b.kind, " team ", b.team, " at ", b.position - at)
	g.set_selection([gw])
	await _cam(at + Vector2(30, 30), 1.7)
	await _snap("1_idle_by_the_army_wrecks_near", 0.0)
	var home: Vector2 = gw.position
	var gold0 := int(gw.get_meta("gw_cogs", 0))
	gw.auto_sweep = true
	await _wait(func() -> bool: return gw.order == "sweep" and gw.position.distance_to(home) > 40.0, 10.0)
	await _snap("2_rolls_to_a_wreck", 0.0)
	print("first target ", gw.order_target.kind, " team ", gw.order_target.team, " at ", gw.order_target.position - at)
	await _wait(func() -> bool: return gw.work == "sweeping", 10.0)
	await _frames(20)
	await _cam(gw.position + Vector2(10, -10), 2.3)
	await _snap("3_sweeping_it_with_its_rollers", 0.0)
	await _wait(func() -> bool: return int(gw.get_meta("gw_cogs", 0)) > gold0, 10.0)
	await _frames(10)
	await _snap("4_plus_cogs", 0.0)
	print("first wreck: +", int(gw.get_meta("gw_cogs", 0)) - gold0, " cogs")
	var gold1 := int(gw.get_meta("gw_cogs", 0))
	await _wait(func() -> bool: return int(gw.get_meta("gw_cogs", 0)) > gold1, 20.0)
	await _frames(10)
	g.camera.position = gw.position + Vector2(10, -10)
	await _frames(4)
	await _snap("5_second_wreck_into_cogs", 0.0)
	print("second wreck: +", int(gw.get_meta("gw_cogs", 0)) - gold1, " cogs")
	await _wait(func() -> bool: return gw.order == "idle", 30.0)
	await _frames(20)
	await _cam(at + Vector2(30, 30), 1.7)
	await _snap("6_back_by_the_army_crown_body_left", 0.0)
	print("back: ", gw.position.distance_to(home), " px from where it stood")
	# a wreck with an enemy soldier near it: left lying
	var risky := _soldier("clock_soldier", gw.position + Vector2(190, 10))
	risky.take_damage(100000.0, null)
	var foe := _soldier("musketeer", risky.position + Vector2(140, -20), 1)
	foe.hold_fire = true
	await _frames(240)
	await _cam((gw.position + foe.position) * 0.5, 1.4)
	await _snap("7_wreck_with_an_enemy_near_left_lying", 0.0)
	print("risky left lying: ", is_instance_valid(risky) and g.bodies.has(risky), " gw order ", gw.order)
	_gone([foe])
	# its card and the SWEEP tip
	_ui(true)
	_hint(false)
	g.set_selection([gw])
	await _cam(gw.position + Vector2(0, 60), 1.6)
	await _snap("8_card", 0.6)
	print("done")
	quit()
