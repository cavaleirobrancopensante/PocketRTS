extends SceneTree
## The round 14 icons (tools/import_round14.py) on the game's own command card, at real size (docs/shots/brood_icons/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_brood_icons.gd -- <outdir>
## card_grub_build.png   a grub's BUILD page: the Rootmaw, the Mound Turtle and the three Sire LURES
## card_tyrant.png       the rooted Tyrant Sire: BIGGER CLUTCH, PACK HUNT, BATTERING HORNS
## card_venom.png        the Venom Sire: BIGGER CLUTCH, SLITHER, LONG SPIT
## card_storm.png        the Storm Sire: BIGGER CLUTCH (greyed: the Hatchlings are not in yet), UPDRAFT
## card_mother.png       the Brood Mother at stage 3: QUICK ROOTS, SWAMP MENDING
## Each is the card cut 1:1 from a 1280x720 screen (the Mother at stage 3); contact.png puts the five side by side.
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
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


func _card(name: String, wait := 0.4) -> void:
	await create_timer(wait).timeout
	g.hud._refresh_card()
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var r: Rect2i = Rect2i(g.hud.card_rect().grow(8)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("%s/%s.png" % [out, name])
	print("wrote ", name)


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
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 500.0
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	# the grub's BUILD page first (no Sire yet: every lure button lit)
	var grubs: Array = g.units.filter(func(u): return u.team == 0 and u.kind == "grub")
	g.camera.position = q.position + Vector2(0, 30)
	g.set_selection(grubs.slice(0, 1))
	g.hud.page = "build"
	await _card("card_grub_build")
	g.hud.page = ""
	var f := _sire(q, BroodNew.FATHER, 0.3)
	var d := _sire(q, BroodNew.DILO, 2.8)
	var p := _sire(q, BroodNew.PTERO, 4.6)
	await create_timer(0.5).timeout
	for pr in [[f, "card_tyrant"], [d, "card_venom"], [p, "card_storm"], [q, "card_mother"]]:
		g.set_selection([pr[0]])
		g.camera.position = (pr[0] as Unit).position
		await _card(pr[1])
	quit()
