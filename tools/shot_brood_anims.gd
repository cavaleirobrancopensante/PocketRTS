extends SceneTree
## Pictures of THE BROOD ANIMATIONS (docs/brood_anims.md; docs/shots/brood_anims/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 --fixed-fps 30 --script res://tools/shot_brood_anims.gd -- <outdir>
## cocoon_<kind>_NN.png   a grub's cocoon turning into a Rootmaw / a Mound Turtle, step by step, then the empty shell
##                        left on the ground fading (real time)
## moult_<line>_NN.png    a young unit's moult (Spitter, Raptor, Hatchling), step by step, then the Challenger regaining
##                        its colour beside its empty shell and shed skin (real time)
## card_<name>.png        the card of a Spitter, a Venom Challenger, a Tyrant Challenger, the Mother at stages 2 and 3
## tools/shot_brood_anims.py makes the GIFs from them.
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var ui: Array = []


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
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
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


func _spot(q: Unit, k: String, a: float) -> Vector2:
	for d in range(8, 30):
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(a + TAU * i / 24.0) * d * Defs.TILE)
			var why: String = BroodRoot.place_problem(g, 0, k, p, null)
			if (why == "" or why.contains("swamp")) and _clear_round(p):      # (a Rootmaw needs swamp: not for a picture)
				return p
	return Vector2.INF


func _clear_round(p: Vector2) -> bool:
	var area := Rect2(p - Vector2(110, 110), Vector2(220, 200))
	for o in g.nb_fp:
		if BroodRoot.rect_of(o).intersects(area):
			return false
	return true


func _open(q: Unit, d: float) -> Vector2:
	for a in [0.6, 0.0, 1.2, -0.6, 2.0, 2.8, 3.6, 4.4]:
		var p: Vector2 = q.position + Vector2.from_angle(a) * d
		if g.passable(g.cell_of(p), 0) and _clear_round(p):
			return p
	return q.position + Vector2(d, 0)


func _ui(on: bool) -> void:
	for c in ui:
		c.visible = on


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	g.players[0]["gold"] = 9000
	g.players[0]["res2"] = 900.0
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	ui = root.find_children("*", "CanvasLayer", true, false).filter(func(c) -> bool: return c.visible)
	_ui(false)
	# 1. the cocoons
	var ang := {BroodNew.MAW: 0.4, BroodNew.TURTLE: 2.6}
	for k in [BroodNew.MAW, BroodNew.TURTLE]:
		var sp := _spot(q, k, float(ang[k]))
		if sp == Vector2.INF:
			print("no spot for ", k)
			continue
		var u: Unit = BroodRoot.cocoon(g, 0, k, sp)
		var tt := BroodRoot.cocoon_time(u)
		g.camera.position = BroodRoot.rect_of(u).get_center() + Vector2(0, -30)
		g.camera.zoom = Vector2(2.6, 2.6)
		g.set_selection([])
		u.nb["coc"] = 0.0
		await create_timer(0.8).timeout          # (the camera settles)
		var n := 0
		var steps := [0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.75, 0.9]
		for el in steps:
			u.nb["coc"] = el
			await _snap("cocoon_%s_%02d" % [k, n])
			n += 1
		for i in 18:
			u.nb["coc"] = tt * lerpf(0.05, 0.99, float(i) / 17.0)
			await _snap("cocoon_%s_%02d" % [k, n])
			n += 1
		u.nb["coc"] = tt - 0.05
		for i in 22:
			await _snap("cocoon_%s_%02d" % [k, n], 0.15)
			n += 1
	# 2. the moults
	var c := _open(q, 340.0)
	var lines := {"venom": "spitter", "tyrant": "raptor", "storm": "hatchlings"}
	for ln in lines:
		var y: Unit = g._add_unit(String(lines[ln]), 0, c)
		y.facing = Vector2(-0.7071, 0.7071)          # (it turns south-east when it starts)
		y.cmd_hold()
		g.camera.position = c + Vector2(0, -16)
		g.camera.zoom = Vector2(4.0, 4.0)
		await _snap("moult_%s_00" % ln, 0.4)
		var w := BroodMature.problem(y)
		if w != "":
			print("mature ", ln, ": ", w)
		BroodMature.start(y)
		var mt := float(Defs.NB["moult"])
		var n := 1
		for i in 30:
			y.moult_t = mt * float(i) / 30.0
			await _snap("moult_%s_%02d" % [ln, n])
			n += 1
		y.moult_t = mt - 0.03
		for i in 26:
			await _snap("moult_%s_%02d" % [ln, n], 0.15)
			n += 1
		g.consume_unit(y)
		await create_timer(0.2).timeout
	# 3. the cards with the new portraits
	_ui(true)
	var cards := {"spitter": "spitter", "venom_challenger": "venom_challenger", "tyrant_challenger": "tyrant_challenger"}
	for k in cards:
		var u2: Unit = g._add_unit(k, 0, c)
		g.set_selection([u2])
		g.camera.position = c
		g.camera.zoom = Vector2(2.0, 2.0)
		await _snap("card_" + k, 0.5)
		g.consume_unit(u2)
	for st in [0, 1, 2]:
		q.nb["stage"] = st
		BroodNew.apply_stage(q)
		g.set_selection([q])
		g.camera.position = q.position
		g.camera.zoom = Vector2(1.0, 1.0)
		await _snap("card_mother_stage%d" % (st + 1), 0.5)
	quit()
