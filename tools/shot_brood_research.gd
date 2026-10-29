extends SceneTree
## Pictures of THE BROOD'S RESEARCH (docs/brood_research.md; docs/shots/brood_research/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_brood_research.gd -- <outdir>
## tyrant_card.png        the rooted Tyrant Sire selected: his research on his card (BATTERING HORNS greyed: stage 3)
## tyrant_researching.png researching: RESEARCHING and its bar on his card and over him, STOP RESEARCH, no eggs
## mother_card.png        the Brood Mother at stage 2: QUICK ROOTS and SWAMP MENDING on her card
## mother_researching.png she researches and keeps laying
## venom_card.png         the Venom Sire's card: BIGGER CLUTCH, SLITHER, LONG SPIT
## icons.png              the ten placeholder icons side by side (made with python, docs/brood_research.md)
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
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _spot(q: Unit, k: String, a: float) -> Vector2:
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	for frac in [0.75, 0.6, 0.9, 0.5]:
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(a + TAU * i / 24.0) * reach * frac)
			if g.region_of(g.cell_of(p)) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, k, p, null) == "":
				return p
	return q.position + Vector2(200, 0)


func _sire(q: Unit, k: String, a: float) -> Unit:
	var u: Unit = BroodRoot.cocoon(g, 0, k, _spot(q, k, a))
	u.nb.erase("coc")
	u.hp = u.max_hp
	BroodNew.recount(g, 0)
	return u


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	g.players[0]["gold"] = 3000
	g.players[0]["res2"] = 300.0
	var f := _sire(q, BroodNew.FATHER, 0.3)
	var d := _sire(q, BroodNew.DILO, 2.8)
	await create_timer(0.5).timeout
	g.camera.position = BroodRoot.rect_of(f).get_center() + Vector2(0, 20)
	g.camera.zoom = Vector2(1.6, 1.6)
	g.set_selection([f])
	await _snap("tyrant_card", 0.4)
	f.cmd_nb_research("nb_pack_hunt")
	q.nb["eggs"] = 5
	f.nb["rs_t"] = 12.0
	await _snap("tyrant_researching", 0.6)
	g.set_selection([d])
	g.camera.position = BroodRoot.rect_of(d).get_center() + Vector2(0, 20)
	await _snap("venom_card", 0.4)
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	g.set_selection([q])
	g.camera.position = q.position + Vector2(0, 30)
	g.camera.zoom = Vector2(1.2, 1.2)
	await _snap("mother_card", 0.5)
	q.cmd_nb_research("nb_quick_roots")
	q.nb["rs_t"] = 15.0
	q.cmd_lay("grub")
	await _snap("mother_researching", 1.0)
	quit()
