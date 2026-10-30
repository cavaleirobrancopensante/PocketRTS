extends SceneTree
## Pictures for docs/clock_charge.md (0.24.4) in the CLOCKWORK LAB: charge bars over Clockwork units off the gear field
## (draining) and on it (winding, pale gold), the Springer's card with its charge, a group's portraits with charge lines,
## and the Springer's bigger screw in flight.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_clock_charge.gd -- <outdir>
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
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _run() -> void:
	Settings.charge_bars = true
	g.reveal = true
	var me: int = g.human
	var hall = null
	for b in g.buildings:
		if b.team == me and b.kind == g.faction_hall(me):
			hall = b
	# off the field: a spot well away from the base, toward the map's middle
	var mid := Vector2(g.W, g.H) * g.T * 0.5
	var off: Vector2 = hall.center().lerp(mid, 0.55)
	var us: Array = []
	var kinds := ["clock_soldier", "clock_soldier", Defs.SPRINGER, "clock_soldier", Defs.SPRINGER, Defs.NETTER, "clock_soldier", Defs.PENDULUM]
	var winds := [0.85, 0.6, 0.45, 0.3, 0.75, 0.55, 0.15, 0.95]
	for i in kinds.size():
		var u: Unit = g._add_unit(kinds[i], me, _open(off + Vector2((i % 4) * 46 - 70, (i / 4) * 52 - 26)))
		u.auto_work = false
		u.cmd_hold()
		u.wind = winds[i]
		u._field_t = 0.0
		us.append(u)
	# one hurt, to show both bars
	(us[1] as Unit).hp = (us[1] as Unit).max_hp * 0.6
	await _frames(20)
	for i in us.size():
		(us[i] as Unit).wind = winds[i]
	g.camera.position = off + Vector2(0, 30)
	g.camera.zoom = Vector2(2.2, 2.2)
	g.set_selection([us[2]])
	await _frames(6)
	await _snap("1_bars_off_field_springer_card")
	g.set_selection(us)
	await _frames(6)
	await _snap("2_group_portraits")
	# on the field: winding up (pale gold), one full (no bar)
	var on: Vector2 = hall.center() + Vector2(0, 120)
	var ws: Array = []
	for i in 4:
		var u: Unit = g._add_unit("clock_soldier" if i != 1 else Defs.SPRINGER, me, _open(on + Vector2(i * 46 - 70, 0)))
		u.auto_work = false
		u.cmd_hold()
		ws.append(u)
	await _frames(20)
	var ww := [0.2, 0.5, 0.8, 1.0]
	for i in 4:
		(ws[i] as Unit).wind = ww[i]
	await _frames(3)
	g.camera.position = on
	g.set_selection([ws[1]])
	await _frames(6)
	await _snap("3_winding_on_the_gear_field")
	# the Springer's screw in flight
	var sp: Unit = ws[1]
	var foe: Unit = g._add_unit("musketeer", 1, _open(sp.position + Vector2(200, 0)))
	foe.max_hp = 99999.0
	foe.hp = 99999.0
	foe.cmd_hold()
	foe.hold_fire = true
	g.set_selection([])
	g.camera.position = sp.position + Vector2(100, -10)
	g.camera.zoom = Vector2(3.0, 3.0)
	await _frames(10)
	Springer.shoot(sp, foe, 0.0)
	await _frames(6)
	g.process_mode = Node.PROCESS_MODE_DISABLED
	await _snap("4_springer_screw_in_flight", 0.0)
	g.process_mode = Node.PROCESS_MODE_INHERIT
	quit(0)
