extends SceneTree
## Match screenshots in one language (command card, panels, top bar):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_i18n_match.gd -- <outdir> <pt|es|en> <crown|brood|clockwork>
var main
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	Settings.load_all()
	Settings.device = "pc"
	Settings.language = a[1]
	Loc.set_lang(a[1])
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String) -> void:
	await create_timer(0.7).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/m_%s_%s_%s.png" % [out, Loc.lang, OS.get_cmdline_user_args()[2], name])


func _run() -> void:
	var fac: String = OS.get_cmdline_user_args()[2]
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	var hall: Building = g.halls_of(0)[0]
	g.camera.position = hall.center() + Vector2(0, 60)
	var kinds: Array = {"crown": ["musketeer", "cannon"], "brood": ["raptor", "spitter"], "clockwork": ["windup_soldier", "steam_walker"]}[fac]
	var us: Array = []
	for i in 4:
		us.append(g._add_unit(kinds[i % 2], 0, hall.center() + Vector2(60 + i * 24, 120)))
	g.selection = [hall]
	g.hud.page = ""
	await _snap("hall")
	g.selection = us
	await _snap("army")
	g.selection = [us[0]]
	await _snap("one")
	g.hud.toast("Not enough gold.")
	await _snap("toast")
	quit()
