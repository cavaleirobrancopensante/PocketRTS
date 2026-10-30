extends SceneTree
## ONE CARD, NO PAGES (0.24.8): the Brood Mother's long command card scrolled, with its scroll bar
## (docs/shots/card_scroll/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_card_scroll.gd -- <outdir>
## mother_top.png       the rooted Mother at stage 2 (GROW) (QUICK ROOTS, SWAMP MENDING to research): the card's first 3 rows, the bar at the top
## mother_scrolled.png  the same card scrolled to its last row: RALLY and WORKERS, the bar at the bottom
## mother_uprooted.png  the uprooted Mother (MOVE ... HOLD first, her eggs below)
## screen.png           the whole screen with the card scrolled
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


func _shot(name: String, whole := false) -> void:
	await create_timer(0.4).timeout
	g.hud._card_fresh = true
	await process_frame
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if not whole:
		var r: Rect2i = Rect2i(g.hud.card_rect().grow(10)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(r)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	var labs: Array = g.hud._card_items.map(func(it) -> String: return "%s=%s" % [String(it[1]), String(it[6])])
	print("wrote %s: scroll %d of %d rows; %s" % [name, g.hud._card_scroll, g.hud._card_rows, " ".join(labs)])


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 500.0
	q.nb["stage"] = 1
	BroodNew.apply_stage(q)
	q.nb["eggs"] = 6
	q.tesla_mode = "deployed"        # (at the start she is still rooting)
	g.camera.position = q.position + Vector2(0, 30)
	g.set_selection([q])
	await _shot("mother_top")
	g.hud.card_scroll_by(9)
	await _shot("mother_scrolled")
	await _shot("screen", true)
	q.tesla_mode = "packed"
	g.set_selection([])
	await process_frame
	g.set_selection([q])
	await _shot("mother_uprooted")
	quit()
