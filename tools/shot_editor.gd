extends SceneTree
## Screenshots of the editor menu, the map editor (painting, spots, save) and a sandbox
## match on the saved map:  godot --script res://tools/shot_editor.gd -- <outdir> [pc|mobile] [en|pt|es]
var main
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	Settings.load_all()
	Settings.device = a[1] if a.size() > 1 else "pc"
	if a.size() > 2:
		Settings.language = a[2]
		Loc.set_lang(a[2])
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	await process_frame
	main.show_editor_menu()
	await _snap("e0_menu")
	main.show_map_editor()
	await process_frame
	var ed: MapEditor = main._editor
	ed.map_name = "Test Valley"
	ed.mirror = "4-way"
	ed.biome_a = "snow"
	ed.biome_b = "grass"
	# a plateau for each corner, a ramp, a lake in the middle, woods
	for y in range(2, 16):
		for x in range(2, 18):
			ed.cells[y * Game.W + x] = "h"
	ed.cells[15 * Game.W + 16] = "r"
	for x in range(14, 19):
		for y in range(15, 18):
			ed.cells[y * Game.W + x] = "r"
	for y in range(24, 36):
		for x in range(34, 50):
			if Vector2(x - 41.5, (y - 29.5) * 1.3).length() < 8:
				ed.cells[y * Game.W + x] = "w"
	for i in 30:
		ed.cells[(20 + i % 5) * Game.W + 24 + i / 5] = "t"
	# mirror the quarter like the brush would
	for y in Game.H:
		for x in Game.W:
			var sx := mini(x, Game.W - 1 - x)
			var sy := mini(y, Game.H - 1 - y)
			ed.cells[y * Game.W + x] = ed.cells[sy * Game.W + sx]
	ed.starts = [Vector2i(6, 6), Vector2i(Game.W - 11, Game.H - 10), Vector2i(Game.W - 11, 6), Vector2i(6, Game.H - 10)]
	ed.halls = [Vector2i(26, 8), Vector2i(Game.W - 31, Game.H - 12)]
	ed._rebuild()
	ed._build_ui()
	await _snap("e1_editor")
	ed.game.camera.zoom = Vector2(1.2, 1.2)
	ed.game.camera.position = Vector2(14, 14) * Game.T
	ed.tool = "tree"
	ed._build_ui()
	await _snap("e2_editor_zoom")
	print("save ok: ", ed._save())
	main.lobby["map"] = "custom:Test Valley"
	main._preset("1v3")
	main.sandbox_lobby = true
	main.show_skirmish()
	await _snap("e3_lobby_custom")
	var cfg: Dictionary = main.lobby.duplicate(true)
	cfg["sandbox"] = true
	main.start(cfg)
	var g = main.game
	await create_timer(1.0).timeout
	var sb: SandboxPanel = null
	for c in main.ui_layer.get_children():
		if c is SandboxPanel:
			sb = c
	var hall = g._own_hall(g.human)
	var at: Vector2 = hall.center() + Vector2(200, 60)
	for k in ["thresher", "steam_walker", "arc_thrower", "tesla_cart"]:
		for i in 3:
			g._add_unit(k, g.human, at + Vector2(i * 30, ["thresher", "steam_walker", "arc_thrower", "tesla_cart"].find(k) * 40))
	for k in ["raptor", "brute", "spitter"]:
		for i in 4:
			g._add_unit(k, 1, at + Vector2(260 + i * 25, ["raptor", "brute", "spitter"].find(k) * 40))
	g.reveal = true
	sb.spawn = "roost"
	sb._build()
	g.camera.position = at + Vector2(140, 0)
	await _snap("e4_sandbox")
	Engine.time_scale = 1.0
	await create_timer(4.0).timeout
	await _snap("e5_sandbox_fight")
	quit()
