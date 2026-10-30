extends SceneTree
## Pictures of the egg tooltip and the card's worker chips (docs/egg_tooltips.md; docs/shots/egg_tooltips/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_egg_tooltips.gd -- <outdir> brood
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_egg_tooltips.gd -- <outdir> crown
## brood: map_hover.png (the mouse resting on the egg line over the Mother: stage 2, the Tyrant Sire near, a turtle far
##        out, veterancy 12), card_egg_chip.png (the same tooltip from the EGGS chip on her card),
##        card_rootmaw_grubs.png (a Rootmaw's GRUBS chip: its label's tooltip)
## crown: card_hall_haulers.png (the Town Hall's HAULERS chip), card_farm_soil.png (a Farm's soil chip)
var main: Node
var g
var out := ""
var fac := "brood"
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		fac = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.tooltips = true
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": fac, "colour": 0, "side": 0},
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


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("wrote ", name)


## Rest the mouse on screen point p (HUD coordinates x ui_scale) long enough for its tooltip, then the picture.
func _rest(p: Vector2, name: String) -> void:
	root.warp_mouse(p)
	await create_timer(1.0).timeout
	await _snap(name)
	root.warp_mouse(Vector2(640, 300))
	await create_timer(0.4).timeout


func _chip_at(title: String) -> Vector2:
	for sr in g.hud._stat_rects:
		if String(sr[1].get("title", "")) == title:
			return (sr[0] as Rect2).get_center() * float(g.hud.ui_scale)
	print("no chip ", title)
	return Vector2(640, 360)


func _select(e: Entity) -> void:
	g.set_selection([e])
	g.hud._refresh_card()
	await create_timer(0.4).timeout


func _run() -> void:
	await create_timer(0.5).timeout
	g.reveal = true
	if fac == "crown":
		await _crown()
		quit()
		return
	var q: Unit = BroodNew.queen(g, 0)
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	q.nb["hvet"] = 12
	var s: Unit = BroodRoot.cocoon(g, 0, BroodNew.FATHER, q.position + Vector2(4.0 * Defs.TILE, 2.0 * Defs.TILE))
	s.nb.erase("coc")
	s.hp = s.max_hp
	for i in 48:
		var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 48.0) * 18.0 * Defs.TILE
		var c: Vector2i = g.cell_of(p)
		if c.x > 3 and c.y > 3 and c.x < g.W - 4 and c.y < g.H - 4 and g.passable(c, 0):
			var tu: Unit = BroodRoot.cocoon(g, 0, BroodNew.TURTLE, p)
			tu.nb.erase("coc")
			break
	BroodNew.recount(g, 0)
	g.players[0]["gold"] = 400
	await create_timer(3.0).timeout
	q.nb["eggs"] = 6
	# the map: the mouse on her egg line
	var lr: Rect2 = EggTip.label_rect(q)
	g.camera.position = lr.get_center() + Vector2(160, 120)
	g.set_selection([])
	await create_timer(0.4).timeout
	var sp: Vector2 = g.get_viewport().get_canvas_transform() * (lr.get_center() + Vector2(10, 0))
	await _rest(sp, "map_hover")
	# her card's EGGS chip
	await _select(q)
	await _rest(_chip_at("Eggs"), "card_egg_chip")
	# a Rootmaw's GRUBS chip
	for u in g.units:
		if u.team == 0 and u.kind == BroodNew.MAW and BroodNew.rooted(u):
			g.camera.position = u.position
			await _select(u)
			await _rest(_chip_at("Grubs"), "card_rootmaw_grubs")
			break
	quit()


func _crown() -> void:
	var hall: Building = g._own_hall(0)
	g.camera.position = hall.center()
	await _select(hall)
	await _rest(_chip_at("Haulers"), "card_hall_haulers")
	var farm: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "farm":
			farm = b
	if farm == null:
		var c: Vector2i = g.find_spot(0, "farm", hall, 2, 30)
		if c.x >= 0:
			farm = g._add_building("farm", 0, c, true)
	if farm:
		g.camera.position = farm.center()
		await _select(farm)
		await _rest(_chip_at("Soil"), "card_farm_soil")
