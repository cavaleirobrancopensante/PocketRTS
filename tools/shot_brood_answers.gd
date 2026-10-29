extends SceneTree
## Pictures of the owner's answers of 2026-10-29 20:09 (docs/sire_lure.md, docs/brood_research.md; docs/shots/brood_answers/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 --fixed-fps 30 --script res://tools/shot_brood_answers.gd -- <outdir>
## storm_NN.png     the Storm Sire flying in to his ripe lure, landing, eating it and settling (a picture every 0.1 s:
##                  the GIF storm_arrival.gif is made from them)
## eggs_<kind>.png  each Sire rooted beside the Mother with his line's eggs in front of his nest, faintly in his lure's
##                  colour, and a plain grub egg beside them (eggs_tinted.png: the three side by side)
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
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _spot(q: Unit, k: String, a: float) -> Vector2:
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	for frac in [0.75, 0.6, 0.9, 0.5, 0.4, 0.97]:
		for i in 36:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(a + TAU * i / 24.0) * reach * frac)
			if g.region_of(g.cell_of(p)) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, k, p, null) == "":
				return p
	return Vector2.INF


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	for c in root.find_children("*", "CanvasLayer", true, false):
		if c.visible:
			c.visible = false
	# the Storm Sire's arrival
	var k := BroodNew.PTERO
	var sp := _spot(q, k, 1.57)
	var u: Unit = BroodRoot.cocoon(g, 0, k, sp)
	var lt := BroodRoot.lure_times(k)
	g.camera.position = BroodRoot.rect_of(u).get_center() + Vector2(-60, -70)
	g.camera.zoom = Vector2(1.9, 1.9)
	u.nb["coc"] = float(lt[0]) - 0.6
	var n := 0
	while BroodRoot.in_cocoon(u) or n < 64:
		await _snap("storm_%02d" % n, 0.1)
		n += 1
		if n > 90:
			break
	# the eggs, tinted
	for i in 4:
		var tsup := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, _spot(q, BroodNew.TURTLE, 4.0 + i))
		tsup.nb.erase("coc")
		BroodNew.recount(g, 0)
	var ang := {BroodNew.FATHER: 0.0, BroodNew.DILO: 3.14}
	for fk in ang:
		var f: Unit = BroodRoot.cocoon(g, 0, fk, _spot(q, fk, float(ang[fk])))
		f.nb.erase("coc")
	BroodNew.recount(g, 0)
	await create_timer(0.3).timeout
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 500.0
	var young := {BroodNew.FATHER: "raptor", BroodNew.DILO: "spitter", BroodNew.PTERO: "skywing"}
	for fk in young:
		var f: Unit = BroodNew.father(g, 0, fk)
		if f == null:
			continue
		for i in 3:
			q.nb["eggs"] = BroodNew.eggs_max(q)
			var w: String = q.cmd_lay(young[fk])
			if w != "":
				print("lay ", young[fk], ": ", w)
	await create_timer(float(Defs.NB["fert_time"]) + 1.0).timeout
	var qs := q.get_node_or_null(BroodRoot.SORT) as Node2D
	if qs:
		qs.visible = false        # (her stage-3 body would hide a Sire's row: the pictures are of the eggs)
	for fk in young:
		var f: Unit = BroodNew.father(g, 0, fk)
		if f == null:
			continue
		var np := BroodNew.nest_point(f)
		var ge: Unit = g._add_unit(BroodNew.EGG, 0, np + Vector2(-70, 0))       # (a plain grub egg beside his row)
		ge.nb["k"] = "grub"
		g.camera.position = np + Vector2(0, -40)
		g.camera.zoom = Vector2(2.6, 2.6)
		await _snap("eggs_%s" % fk, 0.4)
		g.consume_unit(ge)
	quit()
