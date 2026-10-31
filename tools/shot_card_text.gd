extends SceneTree
## Pictures of the card's short line and the portrait's tooltip (Defs.SHORT, Hud._portrait_tip; docs/shots/card_text/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_card_text.gd -- <outdir> crown
##   ... -- <outdir> clockwork      ... -- <outdir> brood
## crown: labourer_card.png (his card), labourer_tip.png (the mouse on his portrait), guardsman_card.png, hall_card.png
## clockwork: clock_soldier_card.png, clock_soldier_tip.png, clocktower_tip.png
## brood: brood_mother_card.png, brood_mother_tip.png, mist_toad_tip.png
## (a 4th argument, a language code: the same pictures in that language, named <name>_<lang>.png)
var main: Node
var g
var out := ""
var fac := "crown"
var lang := ""
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		fac = a[1]
	if a.size() > 2:
		lang = a[2]
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.tooltips = true
	if lang != "":
		Settings.language = lang
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
	var n := name + ("_" + lang if lang != "" else "")
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
	print("wrote ", n)


func _select(e: Entity) -> void:
	g.set_selection([e])
	g.hud._refresh_card()
	g.camera.position = e.position if e is Unit else (e as Building).center()
	root.warp_mouse(Vector2(640, 250))
	await create_timer(0.6).timeout


## The card, then (tip) the mouse resting on the portrait.
func _card(e: Entity, name: String, tip := true, card := true) -> void:
	Settings.tooltips = false          # (the card alone: no tooltip from the map under the mouse)
	await _select(e)
	if card:
		await _snap(name + "_card")
	Settings.tooltips = true
	if not tip:
		return
	var pr: Rect2 = g.hud._portrait_one.get("rect", Rect2())
	if pr.size == Vector2.ZERO:
		print("no portrait for ", name)
		return
	root.warp_mouse(pr.get_center() * float(g.hud.ui_scale))
	await create_timer(1.0).timeout
	await _snap(name + "_tip")
	root.warp_mouse(Vector2(640, 250))
	await create_timer(0.3).timeout


func _open(p: Vector2) -> Vector2:
	var c: Vector2i = g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 8))


func _run() -> void:
	await create_timer(0.5).timeout
	g.reveal = true
	var me: int = g.human
	if fac == "brood":
		var q: Unit = BroodNew.queen(g, me)
		await create_timer(2.5).timeout          # (she roots at the start: the card shows ROOTING till then)
		await _card(q, "brood_mother")
		var toad: Unit = g._add_unit("mist_toad", me, _open(q.position + Vector2(140, 60)))
		await _card(toad, "mist_toad", true, false)
		quit()
		return
	var hall: Building = g._own_hall(me)
	if fac == "clockwork":
		var cs: Unit = g._add_unit("clock_soldier", me, _open(hall.center() + Vector2(160, 80)))
		cs.cmd_hold()
		await _card(cs, "clock_soldier")
		await _card(hall, "clocktower", true, false)
		quit()
		return
	var lab: Unit = g._add_unit("labourer", me, _open(hall.center() + Vector2(-140, 90)))      # (an idle one: his card's line)
	lab.auto_work = false
	lab.cmd_hold()
	await _card(lab, "labourer")
	var gm: Unit = g._add_unit("musketeer", me, _open(hall.center() + Vector2(160, 80)))
	gm.put_on_armour()
	gm.cmd_hold()
	await _card(gm, "guardsman", false)
	await _card(hall, "hall", false)
	quit()
