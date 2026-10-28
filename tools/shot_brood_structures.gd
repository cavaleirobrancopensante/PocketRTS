extends SceneTree
## Pictures of the new Brood's ROOTED = A BUILDING pass (the owner's playtest of 0.15.13; docs/brood_new.md, scripts/brood_root.gd):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_brood_structures.gd -- <outdir>
##   (docs/shots/brood_structures/ holds them shrunk to 1000 px and 200 colours; grub_morph.png is the six morph_N frames
##   cropped round the turtle's spot, in two rows)
## father_ring.png      a grub placing a Tyrannosaur: the father range round the Mother, the ghost IN RANGE
## father_ring_out.png  the same ghost out of range (red)
## ghost_green.png      a Rootmaw's ROOT ghost on the grid, green (its ground circle drawn)
## ghost_red.png        a Rootmaw's ghost over another's ground: red, with the reason
## grubs_over_mother.png  the rooted Mother in the building layer: the grubs at her rim drawn over her
## card_rooted.png      a rooted Rootmaw's card: a building's (UPROOT, HAUL, RALLY; no MOVE, ATTACK, STOP, HOLD)
## card_egg.png         an egg's card: what it will hatch and when
## rally_mother.png     the Mother's rally point (a flag and a dashed line), given to her eggs
## morph_N.png          a grub turning into a Mound Turtle: the grub's morph, the cocoon growing, the turtle coming out
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


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
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


func _snap(name: String, wait := 0.8) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func mine(k: String) -> Array:
	return g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == k)


func spot(k: String, p: Vector2, tiles: float, swamp := true) -> Vector2:
	for r in [tiles, tiles + 1.0, tiles - 1.0, tiles + 2.0, tiles + 3.0]:
		for i in 32:
			var s: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 32.0 + 0.4) * r * Defs.TILE)
			if BroodRoot.home_region(g, s) == BroodRoot.home_region(g, p) and BroodRoot.place_problem(g, 0, k, s, null, false, 1.0, swamp) == "":
				return s
	return p


func _run() -> void:
	await wait(2.5)
	var q: Unit = BroodNew.queen(g, 0)
	var maw: Unit = mine(BroodNew.MAW)[0]
	g.players[0]["gold"] = 3000
	g.players[0]["res2"] = 200.0
	var ctl = g.controls
	# the grubs at her rim, drawn over her (the building layer)
	var qr: Rect2 = q.rect()
	for i in 7:
		var gp := Vector2(qr.position.x + 20.0 + i * 40.0, qr.end.y + 12.0)
		if i >= 5:
			gp = Vector2(qr.position.x - 12.0 if i == 5 else qr.end.x + 12.0, qr.get_center().y + 10.0)
		var gr: Unit = g._add_unit("grub", 0, gp)
		gr.auto_work = false
		gr.facing = (q.position - gp).normalized()
	await wait(0.5)
	g.camera.position = q.position + Vector2(0, -40)
	g.camera.zoom = Vector2(1.6, 1.6)
	await _snap("grubs_over_mother")
	# the Mother's rally (flag, dashed line) and the egg she lays takes it
	var rp: Vector2 = q.position + Vector2(-200.0, 230.0)
	g.smart_command([q], rp)
	q.cmd_lay("grub")
	g.set_selection([q])
	g.camera.position = q.position + Vector2(-60, 60)
	g.camera.zoom = Vector2(1.2, 1.2)
	await _snap("rally_mother", 1.6)
	# an egg's card
	var eggs := mine(BroodNew.EGG)
	if not eggs.is_empty():
		g.set_selection([eggs.back()])
		g.camera.position = (eggs.back() as Unit).position
		await _snap("card_egg", 0.8)
	# a rooted Rootmaw's card
	g.set_selection([maw])
	g.camera.position = maw.position + Vector2(0, -20)
	g.camera.zoom = Vector2(1.6, 1.6)
	await _snap("card_rooted", 0.8)
	# a Rootmaw's ROOT ghost: green, then red over the first Rootmaw's ground
	var gr0: Unit = mine("grub")[0]
	g.set_selection([gr0])
	ctl.begin_nb_root(BroodNew.MAW, true)
	var gs := spot(BroodNew.MAW, q.position, 9.0)
	ctl.ghost_cell = BroodRoot.cell_for(BroodNew.MAW, gs)
	g.camera.position = gs + Vector2(0, -10)
	g.camera.zoom = Vector2(1.3, 1.3)
	await _snap("ghost_green", 1.0)
	var red_at: Vector2 = maw.position + Vector2(0, 5.0 * Defs.TILE)
	var far_d := -1.0
	for r in [5.0, 6.0, 4.0, 7.0]:
		for i in 24:
			# (over the first Rootmaw's ground, as far from the Mother as can be)
			var c2: Vector2 = BroodRoot.snap(BroodNew.MAW, maw.position + Vector2.from_angle(TAU * i / 24.0) * r * Defs.TILE)
			if BroodRoot.place_problem(g, 0, BroodNew.MAW, c2, gr0).begins_with("Too close") and c2.distance_to(q.position) > far_d:
				red_at = c2
				far_d = c2.distance_to(q.position)
	ctl.ghost_cell = BroodRoot.cell_for(BroodNew.MAW, red_at)
	g.camera.position = (maw.position + red_at) * 0.5
	await _snap("ghost_red", 1.0)
	ctl.cancel_mode()
	# the father range while a grub places a Tyrannosaur: in range, then out of range
	ctl.begin_nb_root(BroodNew.FATHER, true)
	var fs := spot(BroodNew.FATHER, q.position, 5.5)
	ctl.ghost_cell = BroodRoot.cell_for(BroodNew.FATHER, fs)
	g.camera.position = q.position + Vector2(0, -20)
	g.camera.zoom = Vector2(0.9, 0.9)
	await _snap("father_ring", 1.0)
	var far := spot(BroodNew.MAW, q.position, 10.0, false)
	ctl.ghost_cell = BroodRoot.cell_for(BroodNew.FATHER, far)
	await _snap("father_ring_out", 1.0)
	ctl.cancel_mode()
	g.set_selection([])
	# a grub turning into a Mound Turtle: frames through its cocoon
	var ts := spot(BroodNew.TURTLE, q.position, 11.0)
	var mg: Unit = mine("grub")[1]
	mg.position = ts + Vector2(0, 90)
	mg.give({"o": "nb_morph", "k": BroodNew.TURTLE, "p": ts})
	g.camera.position = ts + Vector2(0, -20)
	g.camera.zoom = Vector2(2.2, 2.2)
	var tt := BroodNew.egg_time(BroodNew.TURTLE)
	var got := false
	for i in 200:
		await wait(0.1)
		if mine(BroodNew.TURTLE).any(func(u) -> bool: return u.position.distance_to(ts) < 1.0):
			got = true
			break
	if got:
		var tu: Unit = mine(BroodNew.TURTLE).filter(func(u) -> bool: return u.position.distance_to(ts) < 1.0)[0]
		var at := [0.4, 1.2, BroodRoot.MORPH_GRUB + 1.0, tt * 0.5, tt * 0.85, tt + 0.6]
		for i in at.size():
			while float(tu.nb.get("coc", tt + 1.0)) < float(at[i]) and BroodRoot.in_cocoon(tu):
				await physics_frame
			if not BroodRoot.in_cocoon(tu):
				await wait(0.6)
			await _snap("morph_%d" % i, 0.05)
	print("shots done")
	quit(0)
