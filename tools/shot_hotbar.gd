extends SceneTree
## Screenshot of the bottom hotkey bar in a match:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_hotbar.gd -- /tmp/hotbar.png [pc|mobile] [sel|barracks|mixed]
var main


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Settings.load_all()
	Settings.device = a[1] if a.size() > 1 else "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	var hall: Building = g.halls_of(0)[0]
	g.camera.position = hall.center() + Vector2(0, 100)
	var men: Array = []
	for i in 6:
		men.append(g._add_unit("musketeer", 0, hall.center() + Vector2(60 + i * 24, 120)))
	g.groups[0] = men.slice(0, 3)
	g.groups[1] = men.slice(3, 6)
	g.groups[4] = [hall]
	g.cam_slots[0] = [hall.center(), 1.0]
	g.cam_slots[3] = [hall.center(), 1.0]
	var mode := a[2] if a.size() > 2 else "sel"
	if mode == "mixed":
		var spots: Array = []
		for r in range(5, 14):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) == r and spots.size() < 40:
						spots.append(hall.cell + Vector2i(dx, dy))
		var bs: Array = []
		for k in ["barracks", "barracks", "armoury", "powder_mill", "foundry"]:
			for c in spots:
				if g.placement_problem(0, k, c) == "":
					bs.append(g._add_building(k, 0, c, true))
					break
		g.set_selection(bs.slice(0, 3))
	else:
		g.set_selection(men.slice(0, 3))
	await create_timer(0.8).timeout
	if a.size() > 3:
		g.hud.bar.key(InputEventKey.new() if false else _k(KEY_F2))
	await create_timer(0.05).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/hotbar.png")
	quit()


func _k(kc: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = kc as Key
	e.pressed = true
	return e
