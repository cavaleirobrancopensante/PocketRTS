extends SceneTree
## Screenshots of every menu, a match HUD and the report:
##   godot --script res://tools/shot_ui.gd -- <outdir> [pc|mobile]
var main
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	Settings.load_all()
	Settings.device = a[1] if a.size() > 1 else "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	await process_frame
	main.show_device()
	await _snap("0_device")
	main.show_menu()
	await _snap("1_menu")
	main.show_settings()
	await _snap("2_settings")
	main.show_help("CROWN")
	await _snap("3_help")
	main._preset("1v1")
	main.lobby["map"] = "highmoor"
	main.show_skirmish()
	await _snap("4_lobby_1v1")
	main._preset("2v2")
	main.lobby["slots"][2]["who"] = "brutal"
	main.lobby["map"] = "twin_fords"
	main.show_skirmish()
	await _snap("5_lobby_2v2")
	main._preset("FFA")
	main.lobby["map"] = "random"
	main.show_skirmish()
	await _snap("5b_lobby_ffa")
	main._preset("1v3")
	main.lobby["slots"][0]["faction"] = "clockwork"
	main.start(main.lobby.duplicate(true))
	var g = main.game
	Engine.time_scale = 8.0
	await create_timer(160.0 / 8.0, true, false, true).timeout
	Engine.time_scale = 1.0
	var hall = g.buildings.filter(func(b): return b.team == g.human and b.kind == g.faction_hall(g.human))
	if not hall.is_empty():
		g.camera.position = hall[0].center() + Vector2(120, -40)
		g.set_selection([hall[0]])
	await _snap("6_hud")
	var us = g.army(g.human) + g.workers(g.human)
	g.set_selection(us)
	await _snap("7_hud_units")
	g.hud.set_paused(true)
	await _snap("8_pause")
	g.hud.set_paused(false)
	g.over = true
	g._sample_stats()
	main._on_end(g.human)
	await create_timer(1.8).timeout
	await _snap("9_report")
	quit()
