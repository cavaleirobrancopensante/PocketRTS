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
## With a second argument "fixes2" (the owner's playtest of 0.15.14; docs/shots/brood_fixes_2/):
##   xvfb-run -a godot ... --script res://tools/shot_brood_structures.gd -- docs/shots/brood_fixes_2 fixes2
## grub_build_menu.png   a grub's BUILD (B) menu: the Rootmaw, the Mound Turtle, the Tyrannosaur, BACK
## grub_card.png         a grub's card: BUILD on it, its own text (Rootmaws, the Brood Mother)
## rootmaw_count.png     a rooted Rootmaw with its worker count over it (grubs at work / the most it takes)
## spots_map.png         the new Brood's best turtle spots in gold on the ground, and on the minimap
## spots_placing.png     the same while placing a Mound Turtle: brighter, with the swamp it would spread
## father_eggs.png       the Tyrannosaur still fertilising with warrior eggs in his nest
## boxed_mother.png      the Mother boxed in by her rooted creatures: her eggs laid on them, drawn on top
## mother_growing.png    the Mother GROWING: the bar over her and on her card, STOP GROWING
## With a second argument "align<prefix>" (the rooted art on its footprint, 2026-10-29; docs/shots/rooted_align/):
##   xvfb-run -a godot ... --script res://tools/shot_brood_structures.gd -- <outdir> alignafter_
## <prefix>mother_stage1(_close).png, mother_stage3(_close).png  the Mother selected (her footprint's frame)
## <prefix>mother_hover.png  the pointer over her: the hover corners; tyrannosaur, mound_turtle, rootmaw, cocoon.png
## With a second argument "fathers" (the three fathers, 2026-10-29; docs/shots/brood_fathers/):
##   xvfb-run -a godot ... --script res://tools/shot_brood_structures.gd -- docs/shots/brood_fathers fathers
## grub_build_locked(_tip).png  a grub's BUILD menu at her stage 1: the Dilophosaurus and Pterodactyl locked (the reason)
## mother_card_refusals.png, mother_card_refusal_<spitter|skywing>.png  her card without fathers: each line refused,
##   the tooltip naming its father
## fathers_rooted(_fertilised).png  the three fathers rooted round a stage-3 Mother, eggs of each line in each nest
## nest_<father>.png     each father's nest close up, selected (his queue over him)
## ptero_takeoff.png, ptero_flying.png, ptero_diving.png  the Pterodactyl taking off, flying, diving on a Musketeer
## dilo_spitting.png, dilo_spit_glob.png  the Dilophosaurus spitting venom
## grub_build_stage3.png  the BUILD menu at stage 3 (one of each: the fathers alive say so)
## With a second argument "mature" (YOUNG AND MATURE and the Mother's stage art, 2026-10-29; docs/shots/brood_mature/;
## tools/brood_mature_sheet.py then puts the Mother's stages side by side):
##   xvfb-run -a godot ... --script res://tools/shot_brood_structures.gd -- <outdir> mature
## mother_s<N>_rooted.png, mother_s<N>_walk.png  the Mother at each stage, rooted and walking (the same zoom)
## moult_<N>.png         a Raptor maturing: before, moulting (twice), a Tyrant Challenger beside two Raptors
## venom_<N>.png         a Venom Challenger spitting at Musketeers (and a Spitter beside it)
## card_mature(_tip).png the MATURE button on the Raptors' card (and its tooltip)
var main: Node
var g
var out := ""
var t := 0.0
var started := false


var mode := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1:
		mode = OS.get_cmdline_user_args()[1]
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
	if mode == "fixes2":
		await _fixes2()
		print("shots done")
		quit(0)
		return
	if mode == "fathers":
		await _fathers()
		print("shots done")
		quit(0)
		return
	if mode == "mature":
		await _mature()
		print("shots done")
		quit(0)
		return
	if mode.begins_with("align"):
		await _align(mode.trim_prefix("align"))
		print("shots done")
		quit(0)
		return
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


## The rooted art on its footprint (the owner, 2026-10-29; docs/brood_new.md "Rooted art on its footprint"): each rooted
## creature selected, the Mother at stages 1 and 3 (as his phone screenshot), with a prefix ("before_" / "after_").
func _align(pre: String) -> void:
	await wait(2.5)
	var q: Unit = BroodNew.queen(g, 0)
	var maw: Unit = mine(BroodNew.MAW)[0]
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 400.0
	for gr in mine("grub"):
		gr.auto_work = false
		gr.cmd_stop()
		gr.position = q.position + Vector2(randf_range(-260, 260), 15.0 * Defs.TILE)
		g.note_move(gr)
	await wait(0.3)
	g.set_selection([q])
	g.camera.position = q.position + Vector2(0, 40)
	g.camera.zoom = Vector2(1.3, 1.3)
	await _snap(pre + "mother_stage1", 1.0)
	# the pointer over her (not selected): the hover frame's corners
	g.set_selection([])
	root.warp_mouse(Vector2(800, 250))
	await _snap(pre + "mother_hover", 0.8)
	root.warp_mouse(Vector2(5, 5))
	g.set_selection([q])
	# her nest from close by, the bottom edge
	g.camera.position = q.position + Vector2(-120, 30)
	g.camera.zoom = Vector2(3.0, 3.0)
	await _snap(pre + "mother_stage1_close", 0.6)
	# the Tyrannosaur, a Mound Turtle and a cocoon round her
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, spot(BroodNew.FATHER, q.position, 5.5))
	f.facing = BroodNew.SE
	f.cmd_deploy()
	var tu := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, spot(BroodNew.TURTLE, q.position, 12.0))
	tu.nb.erase("coc")
	var cc := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, spot(BroodNew.TURTLE, q.position, 16.0))
	BroodNew.recount(g, 0)
	await wait(4.0)
	for u in [f, tu, maw]:
		g.set_selection([u])
		g.camera.position = u.position + Vector2(0, 30)
		g.camera.zoom = Vector2(2.6, 2.6) if u != f else Vector2(2.0, 2.0)
		await _snap(pre + String(u.kind), 0.8)
	g.set_selection([cc])
	g.camera.position = cc.position + Vector2(0, 30)
	g.camera.zoom = Vector2(2.6, 2.6)
	await _snap(pre + "cocoon", 0.6)
	# the Mother at stage 3 (the Tyrannosaur out of her bigger nest's way)
	g.set_selection([])
	g.consume_unit(f)
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	await wait(0.5)
	g.set_selection([q])
	g.camera.position = q.position + Vector2(0, 60)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap(pre + "mother_stage3", 1.0)
	g.camera.position = q.position + Vector2(-140, 30)
	g.camera.zoom = Vector2(2.6, 2.6)
	await _snap(pre + "mother_stage3_close", 0.6)
	g.set_selection([])


## The owner's playtest of 0.15.14 (docs/brood_new.md): the pictures listed at the top.
func _fixes2() -> void:
	await wait(2.5)
	var T := Defs.TILE
	var q: Unit = BroodNew.queen(g, 0)
	var maw: Unit = mine(BroodNew.MAW)[0]
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 400.0
	var ctl = g.controls
	# room in the supply: a rooted turtle out of the way
	var st := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, spot(BroodNew.TURTLE, q.position, 16.0))
	st.nb.erase("coc")
	BroodNew.recount(g, 0)
	# the grub's card, then its BUILD menu
	var gr0: Unit = mine("grub")[0]
	g.set_selection([gr0])
	g.hud.page = ""
	g.camera.position = gr0.position
	g.camera.zoom = Vector2(1.4, 1.4)
	await _snap("grub_card", 1.0)
	g.hud.page = "build"
	await _snap("grub_build_menu", 0.8)
	g.hud.page = ""
	g.set_selection([])
	# the Rootmaw's worker count: four grubs on it
	maw.nb["food"] = 200.0
	var gs: Array = mine("grub")
	for i in mini(4, gs.size()):
		gs[i].auto_work = true
		gs[i].cmd_gather(maw)
	for i in range(4, gs.size()):
		gs[i].auto_work = false
		gs[i].cmd_stop()
		gs[i].position = q.position + Vector2(-200.0 + i * 20.0, -160.0)
	await wait(3.0)
	g.camera.position = maw.position + Vector2(0, -30)
	g.camera.zoom = Vector2(1.8, 1.8)
	await _snap("rootmaw_count", 1.0)
	# the turtle spots, on the ground and the minimap
	Settings.expansion_spots = true
	g.exp_spots._key = "-"
	g.exp_spots.refresh()
	var shown: Array = g.exp_spots.shown
	if not shown.is_empty():
		var sp: Dictionary = shown[0]
		var mid: Vector2 = (Vector2(sp["tc"]) + Vector2(1.5, 1.5)) * T
		g.camera.position = mid
		g.camera.zoom = Vector2(1.1, 1.1)
		await _snap("spots_map", 1.2)
		g.camera.zoom = Vector2(0.6, 0.6)
		await _snap("spots_far", 1.2)          # (zoomed out: the label gives way, the gold and the minimap squares stay)
		g.set_selection([gr0])
		ctl.begin_nb_root(BroodNew.TURTLE, true)
		ctl.ghost_cell = Vector2i(sp["tc"]) + Vector2i(1, 6)
		g.camera.zoom = Vector2(0.7, 0.7)
		await _snap("spots_placing", 1.2)
		ctl.cancel_mode()
		g.set_selection([])
	# the Tyrannosaur fertilising, eggs in his nest
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, spot(BroodNew.FATHER, q.position, 5.5))
	f.cmd_deploy()
	await wait(3.5)
	q.nb["eggs"] = 8
	q.cmd_lay("raptor")
	q.cmd_lay("raptor")
	q.cmd_lay("raptor")
	await wait(3.6)
	g.set_selection([f])
	g.camera.position = f.position + Vector2(0, -30)
	g.camera.zoom = Vector2(1.8, 1.8)
	await _snap("father_eggs", 0.5)
	g.set_selection([])
	await wait(float(Defs.UNITS["brute"]["time"]) + 4.0)
	# the Mother boxed in by her rooted creatures, her eggs on top
	f.cmd_uproot(false)
	await wait(3.0)
	f.position = q.position + Vector2(0, 18.0 * T)
	g.note_move(f)
	for u in g.units:
		if u.team == 0 and not u.dead and u != q and q.rect().grow(4.0 * T).has_point(u.position) and (u.kind == "grub" or u.kind == "raptor" or u.kind == "brute" or u.kind == BroodNew.EGG):
			u.position = q.position + Vector2(randf_range(-300, 300), 14.0 * T)
			g.note_move(u)
	var qr: Rect2 = q.rect()
	var c0 := Vector2i(qr.position / T)
	var sz := Vector2i(qr.size / T)
	var x := c0.x - 3
	var n := 0
	while x < c0.x + sz.x + 3:
		for yy in [c0.y - 3, c0.y + sz.y]:
			var k: String = BroodNew.TURTLE          # (3 tiles deep: no gap left between the rows and her rim)
			var u: Unit = g._add_unit(k, 0, BroodRoot.feet_at(k, Vector2i(x, yy)))
			u.facing = BroodNew.SE
			u.tesla_mode = "deployed"
			u.nb["m"] = "deployed"
			BroodRoot.footprint_on(g, u, false)
			if k == BroodNew.MAW:
				BroodNew._claim(g, u)
				u.nb["food"] = 150.0
			n += 1
		x += 3
	for side in [c0.x - 3, c0.x + sz.x]:
		var y := c0.y
		while y < c0.y + sz.y:
			var left: int = c0.y + sz.y - y
			var k2: String = BroodNew.TURTLE if left >= 3 else BroodNew.MAW
			var u2: Unit = g._add_unit(k2, 0, BroodRoot.feet_at(k2, Vector2i(side, y if left >= 3 else y - (2 - left))))
			u2.facing = BroodNew.SE
			u2.tesla_mode = "deployed"
			u2.nb["m"] = "deployed"
			BroodRoot.footprint_on(g, u2, false)
			if k2 == BroodNew.MAW:
				BroodNew._claim(g, u2)
				u2.nb["food"] = 150.0
			y += 3 if left >= 3 else left
	BroodNew.recount(g, 0)
	q.nb["eggs"] = 8
	for i in 3:
		q.cmd_lay("grub")
		await wait(0.2)
	await wait(BroodNew.lay_time(q) + 0.8)
	g.set_selection([])
	for e in mine(BroodNew.EGG):
		print("    boxed: egg at %s, on a creature: %s" % [str(e.position), str(e.nb.get("top", false))])
	g.camera.position = q.position + Vector2(0, 70)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("boxed_mother", 0.5)
	# the hatchlings walk out through their own creatures
	await wait(float(Defs.UNITS["grub"]["time"]) + 2.0)
	await _snap("boxed_hatched", 0.3)
	# her growing: the bar over her and on her card
	q.nb["stage"] = 0
	BroodNew.apply_stage(q)
	q.cmd_grow()
	await wait(12.0)
	g.set_selection([q])
	g.camera.position = q.position + Vector2(0, -150)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("mother_growing", 0.8)
	g.set_selection([])


# ------------------------------------------------------------------ "fathers" (the three fathers, 2026-10-29; docs/shots/brood_fathers/)

## A spot beside the Mother where a father of kind k may nest, looked for round her from the angle a.
func father_spot(q: Unit, k: String, a: float) -> Vector2:
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	for frac in [0.75, 0.6, 0.9, 0.5]:
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(a + TAU * i / 24.0) * reach * frac)
			if BroodRoot.home_region(g, p) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, k, p, null) == "":
				return p
	return q.position


## The card's tooltip for the button labelled lab, held on screen for the picture.
func _tip_snap(name: String, lab: String) -> void:
	var item = null
	for b in g.hud._card_buttons:
		if String(b["item"][1]) == lab:
			item = b
	if item == null:
		print("no card button ", lab)
		await _snap(name, 0.3)
		return
	for i in 8:
		g.hud._tip = g.hud._card_tip(item["item"])
		g.hud._tip_at = (item["rect"] as Rect2).get_center()
		g.hud._tip_ms = Time.get_ticks_msec()
		g.hud.queue_redraw()
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	g.hud._tip = {}


func _mature() -> void:
	await wait(2.5)
	var q: Unit = BroodNew.queen(g, 0)
	var T := Defs.TILE
	g.players[0]["gold"] = 9000
	g.players[0]["res2"] = 900.0
	for gr in mine("grub"):
		gr.auto_work = false
		gr.cmd_stop()
		gr.position = q.position + Vector2(randf_range(-200, 200), 16.0 * T)
		g.note_move(gr)
	# (supply: Mound Turtles out of the way)
	for i in 3:
		var tu: Unit = BroodRoot.cocoon(g, 0, BroodNew.TURTLE, spot(BroodNew.TURTLE, q.position + Vector2(18.0 * T, 0.0), 2.0 + 4.0 * i))
		tu.nb["coc"] = BroodRoot.cocoon_time(tu) - 0.05
	await wait(0.5)
	var home := q.position
	# the Mother at each stage, rooted and walking, at one zoom
	for st in 3:
		q.nb["stage"] = st
		BroodNew.apply_stage(q)
		if q.tesla_mode != "packed":
			BroodRoot.footprint_on(g, q)
		g.swamp_dirty = true
		await wait(0.4)
		q.nb["eggs"] = BroodNew.eggs_max(q)
		g.set_selection([])
		g.camera.position = home + Vector2(0, -40)
		g.camera.zoom = Vector2(1.1, 1.1)
		await _snap("mother_s%d_rooted" % (st + 1), 0.6)
		q.cmd_uproot(true)
		await wait(float(Defs.NB["queen_switch"]) + 0.3)
		q.cmd_move(home + Vector2(3.0 * T, 2.0 * T))
		await wait(1.6)
		g.camera.position = q.position + Vector2(0, -40)
		await _snap("mother_s%d_walk" % (st + 1), 0.3)
		q.cmd_stop()
		q.position = home
		g.note_move(q)
		q.facing = BroodNew.SE
		q.cmd_deploy()
		await wait(float(Defs.NB["queen_switch"]) + 0.5)
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	await wait(0.3)
	# a Raptor maturing into a Tyrant Challenger (two Raptors beside it for its size)
	var at := Vector2(home.x - 4.0 * T, BroodRoot.rect_of(q).end.y + 4.0 * T)      # (in front of her nest, in sight)
	var r: Unit = g._add_unit("raptor", 0, at)
	var r2: Unit = g._add_unit("raptor", 0, at + Vector2(-40, 18))
	var r3: Unit = g._add_unit("raptor", 0, at + Vector2(-40, -18))
	for u in [r, r2, r3]:
		u.facing = BroodNew.SE
	await wait(0.4)
	g.camera.position = at + Vector2(-10, -10)
	g.camera.zoom = Vector2(3.2, 3.2)
	await _snap("moult_1_before", 0.4)
	g.set_selection([r, r2, r3])
	await _snap("card_mature", 0.5)
	await _tip_snap("card_mature_tip", "MATURE")
	g.set_selection([])
	g.mature_order([r])
	await wait(2.0)
	await _snap("moult_2_moulting", 0.1)
	await wait(5.0)
	await _snap("moult_3_moulting", 0.1)
	await wait(float(Defs.NB["moult"]) - 6.5)
	r.facing = BroodNew.SE
	await wait(0.4)
	await _snap("moult_4_after", 0.3)
	# a Venom Challenger (a matured Spitter) spitting at Musketeers, a Spitter beside it
	var vat := Vector2(home.x + 4.0 * T, BroodRoot.rect_of(q).end.y + 4.0 * T)
	var sp: Unit = g._add_unit("spitter", 0, vat)
	var sp2: Unit = g._add_unit("spitter", 0, vat + Vector2(-10, 80))
	g.mature_order([sp])
	await wait(float(Defs.NB["moult"]) + 0.5)
	var foes: Array = []
	for i in 3:
		foes.append(g._add_unit("musketeer", 1, vat + Vector2(4.5 * T, -10.0 + 14.0 * i)))
	for u in foes:
		u.cmd_stop()
	sp.cmd_attack(foes[1])
	sp2.cmd_attack(foes[0])
	g.camera.position = vat + Vector2(2.0 * T, 0)
	g.camera.zoom = Vector2(2.4, 2.4)
	g.set_selection([])
	for i in 12:
		await wait(0.2)
		await _snap("venom_%d" % i, 0.05)
	print("venom challenger kind %s, foes hp %s" % [sp.kind, str(foes.map(func(u) -> float: return u.hp if not u.dead else 0.0))])


func _fathers() -> void:
	await wait(2.5)
	var q: Unit = BroodNew.queen(g, 0)
	g.players[0]["gold"] = 9000
	g.players[0]["res2"] = 900.0
	var ctl = g.controls
	for gr in mine("grub"):
		gr.auto_work = false
	# the grub's BUILD menu at stage 1: the later fathers locked, with the reason
	var gr0: Unit = mine("grub")[0]
	g.set_selection([gr0])
	g.camera.position = gr0.position
	g.camera.zoom = Vector2(1.3, 1.3)
	g.hud.page = "build"
	await _snap("grub_build_locked", 0.8)
	await _tip_snap("grub_build_locked_tip", "STORM SIRE")
	g.hud.page = ""
	# her card at stage 1 with no father: each line refused, naming its father
	q.nb["eggs"] = 10
	g.set_selection([q])
	g.camera.position = q.position + Vector2(0, -30)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("mother_card_refusals", 0.8)
	for k in ["raptor", "spitter", "mist_toad", "skywing"]:
		print("refusal %s: %s" % [k, BroodNew.lay_problem(g, q, k)])
	await _tip_snap("mother_card_refusal_spitter", "SPITTERS")
	await _tip_snap("mother_card_refusal_skywing", "SKYWING")
	# stage 3, the three fathers rooted round her, each with eggs of his line in his nest
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	BroodRoot.footprint_on(g, q)
	g.swamp_dirty = true
	await wait(0.3)
	var made := {}
	# (supply for the eggs: two Mound Turtles rooted out of the way, east of her)
	for i in 2:
		var tu: Unit = BroodRoot.cocoon(g, 0, BroodNew.TURTLE, spot(BroodNew.TURTLE, q.position + Vector2(16.0 * Defs.TILE, 0.0), 2.0 + 4.0 * i))
		tu.nb["coc"] = BroodRoot.cocoon_time(tu) - 0.05
	await wait(0.3)
	var ang := {BroodNew.FATHER: 1.0, BroodNew.DILO: 2.2, BroodNew.PTERO: -0.1}
	for fk in [BroodNew.PTERO, BroodNew.FATHER, BroodNew.DILO]:
		var c: Unit = BroodRoot.cocoon(g, 0, fk, father_spot(q, fk, float(ang[fk])))
		c.nb["coc"] = BroodRoot.cocoon_time(c) - 0.05
		made[fk] = c
		print("father %s at %s (Mother %s, %.1f tiles)" % [fk, str(c.position), str(q.position), c.position.distance_to(q.position) / Defs.TILE])
	await wait(0.5)
	q.nb["eggs"] = BroodNew.eggs_max(q)
	for k in ["raptor", "raptor", "brute", "spitter", "spitter", "mist_toad", "skywing", "skywing"]:
		var w: String = q.cmd_lay(k)
		if w != "":
			print("lay %s: %s" % [k, w])
	await wait(0.6)
	g.set_selection([])
	g.camera.position = q.position + Vector2(30, 70)
	g.camera.zoom = Vector2(0.8, 0.8)
	await _snap("fathers_rooted", 0.6)
	g.set_selection([q])
	await _snap("fathers_rooted_ring", 0.6)
	g.set_selection([])
	for fk in BroodNew.FATHERS:
		var f: Unit = made[fk]
		g.camera.position = BroodRoot.rect_of(f).get_center() + Vector2(0, -20)
		g.camera.zoom = Vector2(2.0, 2.0)
		g.set_selection([f])
		await _snap("nest_%s" % fk, 0.5)
	g.set_selection([])
	await wait(float(Defs.NB["fert_time"]) + 0.3)
	g.camera.position = q.position + Vector2(30, 70)
	g.camera.zoom = Vector2(0.8, 0.8)
	await _snap("fathers_rooted_fertilised", 0.4)
	# the Pterodactyl takes off and flies; dives on a Musketeer
	var pt: Unit = made[BroodNew.PTERO]
	pt.cmd_uproot(false)
	await wait(float(Defs.NB["father_switch"]) * 0.5)
	g.camera.position = pt.position + Vector2(0, -30)
	g.camera.zoom = Vector2(2.0, 2.0)
	await _snap("ptero_takeoff", 0.05)
	await wait(float(Defs.NB["father_switch"]) * 0.5 + 0.3)
	# out over open ground east of her (clear of the nests, for the pictures)
	var open: Vector2 = g.cell_center(g.nearest_free(g.cell_of(q.position + Vector2(20.0 * Defs.TILE, 4.0 * Defs.TILE)), 10))
	pt.cmd_move(open)
	# (the camera takes a moment to get there: it is put ahead of him and waited for)
	g.camera.position = pt.position.lerp(open, 0.5) + Vector2(0, -30)
	await _snap("ptero_flying", 0.9)
	for i in 300:
		if pt.position.distance_to(open) < 12.0:
			break
		await physics_frame
	g.camera.position = open + Vector2(30, -10)
	await wait(0.8)
	var foe: Unit = g._add_unit("musketeer", 1, open + Vector2(70, 30))
	foe.hp = 99999.0
	foe.max_hp = 99999.0
	foe.cmd_stop()
	pt.cmd_attack(foe)
	var dived := false
	for i in 400:
		await physics_frame
		if pt.anim == "attack" and pt.sprite.frame >= 2:
			dived = true
			break
	await _snap("ptero_diving", 0.0)
	print("dive caught: ", dived)
	g.consume_unit(foe)
	pt.cmd_move(open + Vector2(-6.0 * Defs.TILE, -3.0 * Defs.TILE))
	# the Dilophosaurus gets up and spits at an enemy (out on the open ground too)
	var di: Unit = made[BroodNew.DILO]
	di.cmd_uproot(false)
	await wait(float(Defs.NB["father_switch"]) + 0.3)
	di.position = g.cell_center(g.nearest_free(g.cell_of(open + Vector2(0.0, 5.0 * Defs.TILE)), 10))
	g.note_move(di)
	di.cmd_stop()
	g.camera.position = di.position + Vector2(60, -10)
	g.camera.zoom = Vector2(2.2, 2.2)
	await wait(0.8)
	var foe2: Unit = g._add_unit("musketeer", 1, di.position + Vector2(150, 50))
	foe2.hp = 99999.0
	foe2.max_hp = 99999.0
	foe2.cmd_stop()
	di.cmd_attack(foe2)
	var spat := false
	for i in 300:
		await physics_frame
		if di.anim == "attack" and di.sprite.frame >= 3:
			spat = true
			break
	await _snap("dilo_spitting", 0.0)
	await wait(0.15)
	await _snap("dilo_spit_glob", 0.0)
	print("spit caught: ", spat)
	# the grub's BUILD menu at stage 3: all unlocked (one of each: the ones alive say so)
	g.consume_unit(foe2)
	g.set_selection([mine("grub")[0]])
	g.hud.page = "build"
	await _snap("grub_build_stage3", 0.8)
	g.hud.page = ""
