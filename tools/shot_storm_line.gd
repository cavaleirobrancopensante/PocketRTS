extends SceneTree
## Pictures of THE STORM LINE (docs/storm_line.md; docs/shots/storm_line/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_storm_line.gd -- <outdir>
## line_side_by_side.png   a Hatchling, a Storm Challenger and the Storm Sire flying side by side (with a Raptor for size)
## line_zoom.png           the same, zoomed in
## hatchlings_vs_swift.png a Hatchling flock biting an enemy Swift (a Musketeer under them left alone)
## challenger_swoop.png    a Storm Challenger swooping on ground units (enemy Musketeers)
## challenger_n_swoop.png  a Storm Challenger swooping NORTH (the flipped frames), zoomed in
## mother_card.png         the Brood Mother's card with the Hatchlings' egg; hatchlings_card.png: MATURE on their card
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
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, wait := 0.0) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _open(q: Unit, d: float) -> Vector2:
	# open walkable ground about d px south-east of her (on the swamp's far side)
	for a in [0.6, 0.0, 1.2, -0.6, 2.0, 2.8]:
		var p: Vector2 = q.position + Vector2.from_angle(a) * d
		if g.passable(g.cell_of(p), 0):
			return p
	return q.position + Vector2(d, 0)


func _spot(q: Unit, k: String, a: float) -> Vector2:
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	for frac in [0.75, 0.6, 0.9, 0.5]:
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(a + TAU * i / 24.0) * reach * frac)
			if g.region_of(g.cell_of(p)) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, k, p, null) == "":
				return p
	return q.position + Vector2(200, 0)


func _clear() -> void:
	for u in g.units.duplicate():
		if not u.dead and u.kind in ["hatchlings", "storm_challenger", "cuckoo", "musketeer", "raptor", BroodNew.PTERO, "clock_soldier"]:
			g.consume_unit(u)


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 500.0
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	var c := _open(q, 330.0)
	# 1. the line side by side, flying (and a Raptor on the ground for size)
	var h: Unit = g._add_unit("hatchlings", 0, c + Vector2(-110, 0))
	var sc: Unit = g._add_unit("storm_challenger", 0, c + Vector2(-35, 0))
	var sire: Unit = g._add_unit(BroodNew.PTERO, 0, c + Vector2(90, 0))
	var ra: Unit = g._add_unit("raptor", 0, c + Vector2(-160, 10))
	for u in [h, sc, sire, ra]:
		u.facing = Vector2(0.7071, 0.7071)
		u.cmd_hold()
	g.camera.position = c + Vector2(-20, -20)
	g.camera.zoom = Vector2(2.0, 2.0)
	g.set_selection([])
	await _snap("line_side_by_side", 0.8)
	g.camera.zoom = Vector2(3.2, 3.2)
	await _snap("line_zoom", 0.3)
	_clear()
	# 2. a Hatchling flock biting a Swift
	await create_timer(0.2).timeout
	var flock: Array = []
	for i in 6:
		flock.append(g._add_unit("hatchlings", 0, c + Vector2(-90 + (i % 3) * 14, -10 + (i / 3) * 14)))
	var sw: Unit = g._add_unit("cuckoo", 1, c + Vector2(10, 0))
	sw.hp = sw.max_hp * 4.0
	var mu: Unit = g._add_unit("musketeer", 1, c + Vector2(-40, 40))
	mu.hold_fire = true
	for u in flock:
		u.cmd_attack(sw)
	g.camera.position = c + Vector2(-20, 0)
	g.camera.zoom = Vector2(2.4, 2.4)
	await _snap("hatchlings_vs_swift", 2.2)
	_clear()
	# 3. a Storm Challenger swooping on ground units
	await create_timer(0.2).timeout
	var sc2: Unit = g._add_unit("storm_challenger", 0, c + Vector2(-60, 0))
	var men: Array = []
	for i in 3:
		var m: Unit = g._add_unit("clock_soldier", 1, c + Vector2(10 + i * 18, (i - 1) * 16))
		m.hold_fire = true
		m.cmd_hold()
		m.hp = m.max_hp * 5.0
		men.append(m)
	sc2.cmd_attack(men[0])
	g.camera.position = c + Vector2(-10, -10)
	g.camera.zoom = Vector2(2.6, 2.6)
	# (caught as it swoops: its attack strip playing)
	for i in 120:
		await process_frame
		if sc2.anim == "attack" and sc2.frame_i in [2, 3]:
			break
	await _snap("challenger_swoop")
	_clear()
	# 4. the N swoop (flipped frames): a target north of it
	await create_timer(0.2).timeout
	var sc3: Unit = g._add_unit("storm_challenger", 0, c + Vector2(0, 30))
	var m2: Unit = g._add_unit("clock_soldier", 1, c + Vector2(0, -8))
	m2.hold_fire = true
	m2.cmd_hold()
	m2.hp = m2.max_hp * 5.0
	sc3.cmd_attack(m2)
	g.camera.position = c + Vector2(0, 0)
	g.camera.zoom = Vector2(4.0, 4.0)
	for i in 150:
		await process_frame
		if sc3.anim == "attack" and sc3.frame_i == 2:
			break
	await _snap("challenger_n_swoop")
	print("N swoop: facing %s, strip %s, frame %d" % [str(sc3.facing), sc3.anim, sc3.frame_i])
	_clear()
	# 5. the cards
	var f: Unit = BroodRoot.cocoon(g, 0, BroodNew.PTERO, _spot(q, BroodNew.PTERO, 1.57))
	f.nb.erase("coc")
	BroodNew.recount(g, 0)
	await create_timer(0.5).timeout
	q.nb["eggs"] = 6
	q.cmd_lay("hatchlings")
	g.set_selection([q])
	g.camera.position = q.position + Vector2(0, 30)
	g.camera.zoom = Vector2(1.2, 1.2)
	await _snap("mother_card", 0.6)
	var hs: Array = []
	for i in 3:
		hs.append(g._add_unit("hatchlings", 0, q.position + Vector2(-140 + i * 16, 120)))
	g.set_selection(hs)
	g.camera.position = q.position + Vector2(-120, 110)
	g.camera.zoom = Vector2(2.0, 2.0)
	await _snap("hatchlings_card", 0.6)
	quit()
