extends SceneTree
## Screenshots of the chat on both devices:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_chat.gd -- <png> pc|mobile
var main
var out := ""
var dev := "pc"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	dev = a[1] if a.size() > 1 else "pc"
	Settings.load_all()
	Settings.device = dev
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _snap(path: String) -> void:
	await create_timer(0.5, true, false, true).timeout
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g = main.game
	await create_timer(0.5, true, false, true).timeout
	g.hud.countdown = 0.0
	paused = false
	await create_timer(1.0, true, false, true).timeout
	var h = g.hud._vs()
	g.chat._last_player_ms = -10000
	g.chat.post(0, "gl hf")
	g.chat.post(1, "gl")
	g.chat.post(0, "thanks")
	g.chat.post(1, "gg")
	g.hud.chat_banner("%s says gg: reply gg to end the match" % g.chat.name_of(1))
	g.chat.post(0, "gg wp")
	if dev == "pc":
		g.hud._open_chat()
		g.hud.chat_buf = "gg, well played"
	else:
		await _snap(out.replace(".png", "_log.png"))
		g.hud.quick_open = true
	await _snap(out)
	quit()
