extends SceneTree
## Screenshots of the Clockwork roster prototype (code placeholder art, or the sheets in assets/units/<kind>/ if present):
## the Lab, each unit close up, and the mechanics at work (storm, plates, set-up heavy with crew, carrier deck, tesla bolt).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_units.gd -- <outdir>
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
	var h: Building = CU.U.hall(g, 0)
	_cam(g.cell_center(h.cell) + Vector2(260, 140), 1.1)
	await _snap("lab_overview", 1.0)
	# a fresh straight row for the close-ups
	var cells := CU.row(g, 0, 14)
	if cells.is_empty():
		cells = CU.row(g, 0, 10, false)
	g.line_net.solve()
	var mid: Vector2 = g.cell_center(cells[cells.size() / 2])
	
	if g.hud:
		g.hud.visible = false
	for k in Defs.CW_KINDS:
		var u: Unit = CU.spawn(g, k, 0, mid)
		if Defs.CW_RAIL.has(k):
			u.facing = Vector2(1, 0)
		_cam(u.position + Vector2(0, -6), 4.0)
		await _snap("unit_" + k, 0.45)
		u.take_damage(99999.0, null)
		await _step(0.3)
		for x in g.units.duplicate():
			if is_instance_valid(x) and x.dead:
				pass
	# every unit in a line, side by side on the ground
	for u in g.units.duplicate():
		if u.team == 0 and Defs.CW_KINDS.has(u.kind) and not u.dead:
			u.take_damage(99999.0, null)
	var i := 0
	var spawned: Array = []
	for k in Defs.CW_KINDS:
		var cell: Vector2i = cells[mini(i, cells.size() - 1)]
		spawned.append(CU.spawn(g, k, 0, g.cell_center(cell)))
		i += 1
	_cam(g.cell_center(cells[cells.size() / 2]), 2.0)
	await _snap("roster_row", 0.8)
	# the plate wagon with plates up, a storm over enemies, a loco set up with its crew
	var wagon: Unit = spawned[Defs.CW_KINDS.find("plate_wagon")]
	CwUnits.plates_up(wagon)
	var eng: Unit = spawned[Defs.CW_KINDS.find("storm_engine")]
	var foes: Array = []
	for j in 5:
		var f := CU.spawn(g, "musketeer", 1, eng.position + Vector2(-60 + 30 * j, 200 + 14 * (j % 2)))
		f.hold_fire = true
		f.cmd_stop()
		foes.append(f)
	CwUnits.cast_order([eng], eng.position + Vector2(0, 200))
	_cam(eng.position + Vector2(0, 110), 2.2)
	await _step(3.0)
	await _snap("storm", 0.2)
	var tl: Unit = spawned[Defs.CW_KINDS.find("tesla_loco")]
	for j in 3:
		var e := CU.spawn(g, "musketeer", 1, tl.position + Vector2(-50 + 50 * j, 90))
		e.hold_fire = true
	_cam(tl.position + Vector2(0, 40), 2.4)
	await _step(1.4)
	await _snap("tesla", 0.15)
	# the heavy locomotive set up beside the Line with its crew aboard
	var hv: Unit = spawned[Defs.CW_KINDS.find("heavy_loco")]
	CwUnits.set_up_order(hv, hv.position + Vector2(0, 4 * 32))
	for j in 3:
		var m := CU.spawn(g, "tin_militia", 0, hv.position + Vector2(-30 + 12 * j, 90))
		m.cmd_stop()
	await _step(9.0)
	_cam(hv.position + Vector2(0, 20), 2.6)
	await _snap("heavy_set_up", 0.4)
	# the carrier with two flyers, one with a passenger
	var car: Unit = spawned[Defs.CW_KINDS.find("carrier_car")]
	var fl: Array = []
	for j in 2:
		fl.append(CU.spawn(g, "ornithopter", 0, car.position + Vector2(-40 + 80 * j, -120)))
	CwUnits.dock_order(fl, car)
	await _step(5.0)
	_cam(car.position + Vector2(0, -10), 3.2)
	await _snap("carrier", 0.3)
	# a siding with a car waiting in it
	var sc: Vector2i = cells[1]
	CwRail.toggle_siding(g, 0, sc)
	_cam(g.cell_center(sc), 3.2)
	await _snap("siding", 0.4)
	# the work car with its crew out
	var wc: Unit = spawned[Defs.CW_KINDS.find("work_car")]
	CwUnits.crew_toggle(wc, true)
	await _step(1.5)
	_cam(wc.position, 3.0)
	await _snap("work_car_crew", 0.2)
	# the HUD: the Lab's hint and a rail unit's card
	if g.hud:
		g.hud.visible = true
	for u in g.selection.duplicate():
		u.selected = false
	g.selection.clear()
	hv.selected = true
	g.selection.append(hv)
	_cam(hv.position, 1.6)
	await _snap("hud_heavy", 0.5)
	quit()
