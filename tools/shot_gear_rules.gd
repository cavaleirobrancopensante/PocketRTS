extends SceneTree
## Screenshots of THE GEAR RULES (docs/gear_rules.md, 0.14.94) in the CLOCKWORK LAB: the placing ghost of a Ratchet Turret
## refused too near another (TOO NEAR A TURRET, the circles drawn) and accepted far enough; a ghost's meshing teeth (green)
## and a clash (red); the Heavy Works idle (an empty bay) and building a Spring Ballista and a Pendulum, the machine rising
## in its bay; the GEAR VIEW; the base with its brass and iron floor plates; the Light Works' and the turret's cards (the
## ring's trade in one line).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_gear_rules.gd -- <outdir>
var main: Node
var g
var out := ""
var t := 0.0
var started := false


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
		g.hud.visible = true
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


## Wait ~30 frames (the camera settles, the layers redraw), then save the screen.
func _snap(name: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _find(kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


func _hint(on: bool) -> void:
	for c in g.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 40:
			c.visible = on


func _sandbox(on: bool) -> void:
	for c in root.find_children("*", "", true, false):
		if c is SandboxPanel:
			c.visible = on


func _look(p: Vector2, zoom: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(zoom, zoom)


func _run() -> void:
	_hint(false)
	_sandbox(false)
	var hall: Building = _find("clocktower")
	g.players[g.human]["gold"] = 50000
	g.players[g.human]["tension"] = 400.0
	for u in g.units:
		if u.team == g.human and not u.is_worker():
			u.cmd_hold()
	# ---- the base: brass plates under the Tension users, iron under the rest
	_look(hall.center() + Vector2(0, 40), 0.75)
	await _snap("base_plates")
	# ---- THE TURRET CIRCLE: a ghost too near the Lab's turret, then one far enough
	var tur: Building = _find(Defs.CW_TURRET)
	if tur != null:
		var near := Vector2i(-1, -1)
		var far := Vector2i(-1, -1)
		var nd := INF
		var fd := INF
		for y in range(tur.cell.y - 16, tur.cell.y + 17):
			for x in range(tur.cell.x - 16, tur.cell.x + 17):
				var c := Vector2i(x, y)
				if not g.in_map(c):
					continue
				var d := GearNet.turret_mid(c).distance_to(tur.center())
				var st: Dictionary = g.gear_net.candidate(g.human, Defs.CW_TURRET, c)
				if st["state"] == "turret" and d > 2.5 * Defs.TILE and absf(d - 4.5 * Defs.TILE) < nd and g.margin_free(c, Vector2i(2, 2)):
					nd = absf(d - 4.5 * Defs.TILE)
					near = c
				if d >= 2.0 * GearNet.turret_claim() and g.placement_problem(g.human, Defs.CW_TURRET, c) == "" and d < fd:
					fd = d
					far = c
		if near.x >= 0:
			g.controls.begin_place(Defs.CW_TURRET)
			g.controls.ghost_cell = near
			_look((tur.center() + GearNet.turret_mid(near)) * 0.5 + Vector2(0, -10), 1.1)
			await _snap("turret_too_near")
		if far.x >= 0:
			g.controls.begin_place(Defs.CW_TURRET)
			g.controls.ghost_cell = far
			_look((tur.center() + GearNet.turret_mid(far)) * 0.5, 0.9)
			await _snap("turret_far_enough")
		g.controls.cancel_mode()
	# ---- THE GHOST'S TEETH: a Regulator meshing (green), then one cutting into a ring (red)
	var reg_ok := Vector2i(-1, -1)
	var reg_clash := Vector2i(-1, -1)
	for y in range(hall.cell.y - 26, hall.cell.y + 27):
		for x in range(hall.cell.x - 26, hall.cell.x + 27):
			var c := Vector2i(x, y)
			if not g.in_map(c) or not g.margin_free(c, Vector2i(2, 2)):
				continue
			var st: Dictionary = g.gear_net.candidate(g.human, Defs.CW_SUPPLY, c)
			if reg_ok.x < 0 and st["state"] == "ok" and g.placement_problem(g.human, Defs.CW_SUPPLY, c, true) == "":
				reg_ok = c
			if reg_clash.x < 0 and st["state"] == "clash" and g.is_free(c):
				reg_clash = c
	print("teeth spots: ok %s clash %s" % [reg_ok, reg_clash])
	if reg_ok.x >= 0:
		g.controls.begin_place(Defs.CW_SUPPLY)
		g.controls.ghost_cell = reg_ok
		_look(Vector2(reg_ok) * Defs.TILE + Vector2(32, 0), 1.6)
		await _snap("ghost_meshing_teeth")
	if reg_clash.x >= 0:
		g.controls.begin_place(Defs.CW_SUPPLY)
		g.controls.ghost_cell = reg_clash
		_look(Vector2(reg_clash) * Defs.TILE + Vector2(32, 0), 1.6)
		await _snap("ghost_clash_teeth")
	g.controls.cancel_mode()
	# ---- THE HEAVY WORKS: idle, then a Spring Ballista and a Pendulum rising in its bay
	var hw: Building = _find(Defs.CW_HEAVY)
	if hw != null:
		# (the Lab's soldiers out of the picture, and the sandbox panel shut)
		for u in g.units:
			if u.team == g.human and not u.is_worker() and u.position.distance_to(hw.center()) < 260.0:
				u.position = hall.center() + Vector2(randf_range(-200, 200), 260)
		_sandbox(false)
		_look(hw.center() + Vector2(0, -30), 3.2)
		await _snap("heavy_works_idle")
		g.players[g.human]["cap"] = 200
		var why: String = g.train(hw, Defs.BALLISTA_KIND)
		print("train ballista: ", why)
		for f in [0.12, 0.45, 0.75, 0.93]:
			hw.prod_t = f * Building.entry_time(Defs.BALLISTA_KIND)
			await _snap("heavy_ballista_%02d" % int(f * 100))
		g.cancel_train(hw)
		why = g.train(hw, Defs.PENDULUM)
		print("train pendulum: ", why)
		for f in [0.3, 0.6, 0.93]:
			hw.prod_t = f * Building.entry_time(Defs.PENDULUM)
			await _snap("heavy_pendulum_%02d" % int(f * 100))
		g.cancel_train(hw)
		why = g.train(hw, Defs.GREAT_WINDER_KIND)
		print("train great winder: ", why)
		for f in [0.5, 0.93]:
			hw.prod_t = f * Building.entry_time(Defs.GREAT_WINDER_KIND)
			await _snap("heavy_great_winder_%02d" % int(f * 100))
		g.cancel_train(hw)
		# its card: big gear only, what it makes
		g.set_selection([hw])
		_look(hw.center() + Vector2(0, -30), 1.6)
		await _snap("card_heavy_works")
	# ---- the cards: the Light Works' and the turret's trade in one line
	var lw: Building = _find(Defs.CW_WORKS)
	if lw != null:
		g.set_selection([lw])
		_look(lw.center(), 1.3)
		await _snap("card_light_works")
	if tur != null:
		g.set_selection([tur])
		_look(tur.center(), 1.3)
		await _snap("card_turret")
	g.set_selection([])
	# ---- THE GEAR VIEW
	g.toggle_gear_view()
	_look(hall.center() + Vector2(0, 40), 0.75)
	await _snap("gear_view", 150)          # (after its toast has gone)
	if _find("mainspring") != null:
		_look(_find("mainspring").center(), 1.3)
		await _snap("gear_view_close")
	g.toggle_gear_view()
	quit(0)
