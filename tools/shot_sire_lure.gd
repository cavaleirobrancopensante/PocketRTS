extends SceneTree
## Pictures of THE SIRE LURES (docs/sire_lure.md; docs/shots/sire_lure/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 --fixed-fps 30 --script res://tools/shot_sire_lure.gd -- <outdir>
## <kind>_grow_N.png    his lure growing (the 4 steps), then ripe (pulsing, its haze puffing)
## <kind>_arrive_NN.png his arrival, a picture every 0.2 s from the ripe lure to him rooted on his nest (the GIFs:
##                      made from them: docs/sire_lure.md)
## eggs_front*.png      the Tyrant Sire rooted beside the Mother, his eggs in a row in front of his footprint (reddening)
## killed_N.png         a ripe Venom Lure killed: it bursts and shrinks away
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
			if g.region_of(g.cell_of(p)) == BroodRoot.home_region(g, q.position) and BroodRoot.place_problem(g, 0, k, p, null) == "" and _clear_south(p):
				return p
	print("no spot for ", k, ": ", BroodRoot.place_problem(g, 0, k, q.position + Vector2.from_angle(a) * reach * 0.75, null))
	return Vector2.INF


## Nothing rooted just south of p (it would be drawn over the lure and the Sire).
func _clear_south(p: Vector2) -> bool:
	var area := Rect2(p - Vector2(90, 20), Vector2(180, 150))
	for o in g.nb_fp:
		if BroodRoot.rect_of(o).intersects(area):
			return false
	return true


## A free spot for k farther out (a supply turtle for the eggs).
func _spot2(q: Unit, k: String) -> Vector2:
	for d in range(12, 30):
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(TAU * i / 24.0) * d * Defs.TILE)
			if BroodRoot.place_problem(g, 0, k, p, null) == "":
				return p
	return q.position + Vector2(0, 600)


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	var ui: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(c) -> bool: return c.visible)
	for c in ui:
		c.visible = false
	var ang := {BroodNew.FATHER: 0.3, BroodNew.DILO: 2.8, BroodNew.PTERO: 1.57}
	for fk in BroodNew.FATHERS:
		var sp := _spot(q, fk, float(ang[fk]))
		if sp == Vector2.INF:
			continue
		var u: Unit = BroodRoot.cocoon(g, 0, fk, sp)
		var lt := BroodRoot.lure_times(fk)
		g.camera.position = BroodRoot.rect_of(u).get_center() + Vector2(0, -30)
		g.camera.zoom = Vector2(2.4, 2.4)
		var gt := float(lt[0])
		var i := 0
		for f in [0.02, 0.2, 0.4, 0.6, 0.8, 0.95]:
			u.nb["coc"] = gt * f
			await _snap("%s_grow_%d" % [fk, i], 0.1)
			i += 1
		u.nb["coc"] = gt - 1.0
		var n := 0
		while BroodRoot.in_cocoon(u) or n < 30:
			await _snap("%s_arrive_%02d" % [fk, n], 0.2)
			n += 1
			if n > 40:
				break
	# his eggs in front of his footprint
	var tr: Unit = BroodNew.father(g, 0, BroodNew.FATHER)
	var tsup := BroodRoot.cocoon(g, 0, BroodNew.TURTLE, _spot2(q, BroodNew.TURTLE))
	tsup.nb.erase("coc")
	BroodNew.recount(g, 0)
	q.nb["eggs"] = 8
	g.players[0]["gold"] = 2000
	for k in ["raptor", "raptor", "raptor"]:
		var w: String = q.cmd_lay(k)
		if w != "":
			print("lay: ", w)
	g.camera.position = BroodRoot.rect_of(tr).get_center() + Vector2(0, -10)
	g.camera.zoom = Vector2(2.2, 2.2)
	await _snap("eggs_front", 1.2)
	await _snap("eggs_front_red", 1.5)
	# a lure killed
	var dl: Unit = BroodNew.father(g, 0, BroodNew.DILO)
	g.consume_unit(dl)
	var sp2 := _spot(q, BroodNew.DILO, 2.8)
	if sp2 == Vector2.INF:
		quit()
		return
	var l2: Unit = BroodRoot.cocoon(g, 0, BroodNew.DILO, sp2)
	l2.nb["coc"] = BroodRoot.lure_times(BroodNew.DILO)[0] * 0.9
	g.camera.position = BroodRoot.rect_of(l2).get_center() + Vector2(0, -40)
	g.camera.zoom = Vector2(2.4, 2.4)
	await _snap("killed_0", 0.3)
	l2.take_damage(99999.0, null)
	await _snap("killed_1", 0.1)
	await _snap("killed_2", 0.3)
	quit()
