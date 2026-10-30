extends SceneTree
## Screenshots of THE MARCHING BAND (scripts/marching_band.gd, docs/marching_band.md): the bandmaster alone and his card
## (the ADD buttons), the full band behind a Musketeer line with its ring and card (the SOLO buttons), the fife's solo
## while the line fires at Clock Soldiers coming in, the pipes' solo when they reach it, the Settings switch.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_marching_band.gd -- <outdir>
var main: Node
var g: Game
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
	if t > 0.2 and main.game == null and not started:
		Settings.marching_band = true
		main.start({"map": "dune_sea", "seed": 4242, "marching_band": true, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, wait := 0.4) -> void:
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
	g.reveal = true
	await _frames(10)
	g.players[0]["gold"] = 3000
	g.players[0]["res2"] = 300
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	for u in g.units.duplicate():
		if u.is_worker():
			u.auto_work = false
			u.cmd_stop()
			u.position = hall.center() + Vector2(-200, -60)
	var dir := (Vector2(Game.W, Game.H) * 16.0 - hall.center()).normalized()
	var mid := _open(hall.center() + dir * 420.0)
	var perp := Vector2(-dir.y, dir.x)
	# ---- 0. the bandmaster alone and his card
	var band: Unit = g._add_unit("band", 0, _open(mid - dir * 70.0))
	band.cmd_hold()
	g.camera.position = band.position
	g.camera.zoom = Vector2(2.2, 2.2)
	g.set_selection([band])
	await _frames(20)
	await _snap("0_bandmaster_alone_card")
	# ---- 1. the full band behind a line, selected
	for k in ["drums", "pipes", "fife"]:
		(band.band["m"] as Array).append(k)
	band.max_hp = float(band.d["hp"]) + 45.0
	band.hp = band.max_hp
	var line: Array = []
	for i in 12:
		var rank := i / 6
		var p: Vector2 = mid + perp * ((i % 6 - 2.5) * 24.0 + rank * 12.0) - dir * rank * 26.0
		var u: Unit = g._add_unit("musketeer", 0, _open(p))
		u.set_kit({"lock": "matchlock", "bayonet": true})
		u.facing = dir
		u.cmd_hold()
		line.append(u)
	g.camera.position = mid - dir * 40.0
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(20)
	await _snap("1_full_band_ring_and_card")
	# ---- 2. Clock Soldiers come in; the fife's solo at the first shot
	var foes: Array = []
	for i in 10:
		var p2: Vector2 = mid + dir * (430.0 + (i / 5) * 24.0) + perp * ((i % 5 - 2) * 26.0)
		var e: Unit = g._add_unit("clock_soldier", 1, _open(p2))
		foes.append(e)
	for e in foes:
		e.cmd_move(mid, true)
	var c0 := g.clock
	while g.clock - c0 < 20.0:
		await physics_frame
		var shot := false
		for u in line:
			if is_instance_valid(u) and u.powder < u._pmax:
				shot = true
		if shot:
			break
	band.band_solo("fife")
	g.camera.position = mid + dir * 60.0
	await _frames(25)
	await _snap("2_fife_solo_volleys", 0.0)
	# ---- 3. the pipes' solo when they reach the line
	c0 = g.clock
	while g.clock - c0 < 25.0:
		await physics_frame
		var close := false
		for u in line:
			if is_instance_valid(u) and not u.dead and u.mode == "bayonet":
				close = true
		if close and MarchingBand.lead(band) == "":
			break
	if MarchingBand.solo_problem(band, "pipes") == "":
		band.band_solo("pipes")
	await _frames(12)
	g.camera.position = mid
	await _frames(6)
	await _snap("3_pipe_solo_bayonets", 0.0)
	# ---- 4. the settings page with the switch
	g.set_selection([])
	quit(0)
