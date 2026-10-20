extends SceneTree
var main
var out := ""
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	Settings.load_all()
	Settings.device = "mobile"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _run() -> void:
	await process_frame
	main._preset("1v1")
	main.lobby["slots"][0]["faction"] = "crown"
	main.start(main.lobby.duplicate(true))
	var g = main.game
	await process_frame
	var hall = g.buildings.filter(func(b): return b.team == g.human and b.kind == g.faction_hall(g.human))[0]
	var c: Vector2i = hall.cell
	g.players[g.human]["gold"] = 5000
	g.players[g.human]["res2"] = 500
	for k in ["barracks", "foundry", "church", "powder_mill"]:
		var done := false
		for r in range(4, 16):
			for dx in range(-r, r + 1):
				for dy in [-r, r]:
					if not done and g.placement_problem(g.human, k, c + Vector2i(dx, dy)) == "":
						g._add_building(k, g.human, c + Vector2i(dx, dy), true)
						done = true
	var hud = g.hud
	hud._group_pressed(6, 0.0)
	print("MAKE selected: ", g.selection.map(func(e): return e.kind))
	await _snap("make")
	var items = hud._build_card()
	print("card: ", items.map(func(it): return it[1]))
	for i in 3:
		g._add_unit(["musketeer","pikeman","musketeer"][i], g.human, hall.center() + Vector2(80 + i * 10, 80))
	g.set_selection(g.army(g.human) + g.workers(g.human))
	await _snap("multi")
	var mus = g.selection.filter(func(e): return e.kind == "musketeer")[0]
	hud._portrait_pressed(mus)
	print("after portrait: ", g.selection.map(func(e): return e.kind))
	hud._portrait_pressed(mus)
	print("after 2nd: ", g.selection.size())
	quit()
