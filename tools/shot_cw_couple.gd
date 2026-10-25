extends SceneTree
## Screenshots of coupled rail trains (docs/clockwork_units_prototype.md, "Trains"): loose vehicles, the train formed, on the move,
## round a corner, with its command card (COUPLE / UNCOUPLE), uncoupled, and a car lost.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_couple.gd -- <outdir>
const CU := preload("res://tools/cw_test_util.gd")
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
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
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _cam(p: Vector2, z: float) -> void:
	g.camera.zoom = Vector2(z, z)
	g.camera.position = p


func _step(secs: float) -> void:
	await create_timer(secs).timeout


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	g.reveal = true
	if g.hud:
		g.hud.countdown = 0.0
	var cells := CU.row(g, 0, 16)
	if cells.is_empty():
		print("no room for a row")
		quit(1)
		return
	# a leg going up or down from the east end, where a Heavy Locomotive has room
	var last: Vector2i = cells[cells.size() - 1]
	var leg: Array = []
	for end in [cells[cells.size() - 1], cells[0]]:
		for sgn in [1, -1]:
			leg = []
			for k in range(1, 7):
				var c: Vector2i = end + Vector2i(0, k * sgn)
				var ok: bool = g.line_net.pipeable(0, c) and not g.line_net.segs.has(c) and not CU._near_building(g, c)
				for off in [Vector2(5, 5), Vector2(-5, 5), Vector2(5, -5), Vector2(-5, -5), Vector2.ZERO]:
					ok = ok and g._clear_at(g.cell_center(c) + off, 22.0, 0)
				if not ok:
					break
				leg.append(c)
			if leg.size() == 6:
				break
		if leg.size() == 6:
			last = end
			break
	for c in leg:
		g.line_net.add_built(0, c)
	g.line_net.solve()
	var east: bool = last == cells[cells.size() - 1]
	var mid: Vector2 = g.cell_center(cells[cells.size() / 2])
	_cam(mid + Vector2(0, 40), 2.2)
	if g.hud:
		g.hud.visible = false
	for sp in root.find_children("*", "SandboxPanel", true, false):
		sp.open = false
		sp._build()
	# four loose vehicles on the Line
	var i0 := 3 if east else cells.size() - 4
	var step_i := 2 if east else -2
	var heavy: Unit = CU.spawn(g, "heavy_loco", 0, g.cell_center(cells[i0 + 3 * step_i]))
	var tesla: Unit = CU.spawn(g, "tesla_loco", 0, g.cell_center(cells[i0 + 2 * step_i]))
	var wc: Unit = CU.spawn(g, "work_car", 0, g.cell_center(cells[i0 + step_i]))
	var pw: Unit = CU.spawn(g, "plate_wagon", 0, g.cell_center(cells[i0]))
	for u in [heavy, tesla, wc, pw]:
		u.facing = Vector2(1, 0) if east else Vector2(-1, 0)
		u.cw["axis"] = u.facing
	await _snap("couple_1_loose", 5.0)
	# COUPLE: they gather behind the Heavy Locomotive and hook on
	g.set_selection([heavy, tesla, wc, pw])
	CwConsist.couple_order(g, [heavy, tesla, wc, pw])
	await _step(5.0)
	await _snap("couple_2_gathering", 0.1)
	await _step(8.0)
	var tr := CwConsist.of(heavy)
	_cam(heavy.position + Vector2(-60 if east else 60, 10), 2.4)
	await _snap("couple_3_train", 0.4)
	# the card, with the train selected
	g.set_selection([wc])
	if g.hud:
		g.hud.visible = true
	_cam(heavy.position + Vector2(-60 if east else 60, 10), 1.8)
	await _snap("couple_4_selected_card", 0.6)
	if g.hud:
		g.hud.visible = false
	g.set_selection([])
	# on the move (it turns round first if the corner is the other way), round the corner
	var goal: Vector2 = g.cell_center(leg[leg.size() - 1])
	var corner: Vector2 = g.cell_center(last)
	var dy := 80.0 if leg[0].y > last.y else -80.0
	heavy.cmd_move(goal)
	var near_shots := 0
	for k in 40:
		await _step(2.0)
		var lead: Unit = tr.cars[0]
		var near: bool = lead.position.distance_to(corner) < 170.0
		if k == 3:
			_cam(lead.position + Vector2(0, 20), 2.2)
			await _snap("couple_5_moving", 0.1)
		if near and near_shots < 4:
			_cam(corner + Vector2(0, dy * 0.5), 2.0)
			await _snap("couple_6_corner_%d" % near_shots, 0.1)
			near_shots += 1
		if lead.position.distance_to(goal) < 40.0:
			break
	# UNCOUPLE where the Work Car was tapped
	g.set_selection([wc])
	CwConsist.uncouple_order([wc])
	g.set_selection([])
	var lead2: Unit = tr.cars[0]
	_cam(lead2.position + Vector2(0, 40), 2.0)
	await _snap("couple_7_uncoupled", 0.3)
	# a car dies: the train breaks there
	var t2 := CwConsist.of(wc)
	if t2 != null and t2.cars.size() >= 3:
		t2.cars[1].take_damage(99999.0, null)
		await _step(0.6)
		await _snap("couple_8_car_lost", 0.2)
	print("shots done")
	quit(0)
