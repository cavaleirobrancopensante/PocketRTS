extends SceneTree
## StarCraft 2's group keys (the owner's friend, 2026-10-31): Ctrl+N set, Shift+N add the selection, Alt+N steal (set,
## taken out of every other group), Shift+Alt+N steal and add; N alone selects.
##   godot --headless --fixed-fps 30 --script res://tools/test_group_keys.gd
var main: Node
var g: Game
var fails := 0


func check(ok: bool, name: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func key(n: int, ctrl := false, shift := false, alt := false) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_0 + n
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	e.alt_pressed = alt
	g.hud.bar.key(e)


func _run() -> void:
	await process_frame
	Settings.load_all()
	Settings.device = "pc"
	main.start({"map": "hollowfen", "seed": 1, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	g = main.game
	var men: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human)
	check(men.size() >= 4, "4+ of our units to work with (%d)" % men.size())
	var a: Array = men.slice(0, 2)
	var b: Array = men.slice(2, 4)
	g.set_selection(a)
	key(1, true)
	check(g.groups[0].size() == 2, "Ctrl+1 sets group 1 (2)")
	g.set_selection(b)
	key(1, false, true)
	check(g.groups[0].size() == 4, "Shift+1 adds the selection to group 1 (now %d)" % g.groups[0].size())
	g.set_selection([b[0]])
	key(2, false, false, true)
	check(g.groups[1].size() == 1 and not g.groups[0].has(b[0]) and g.groups[0].size() == 3, "Alt+2 steals: group 2 = it, group 1 loses it (%d, %d)" % [g.groups[1].size(), g.groups[0].size()])
	g.set_selection([a[0]])
	key(2, false, true, true)
	check(g.groups[1].size() == 2 and not g.groups[0].has(a[0]), "Shift+Alt+2 steals and adds (group 2: %d, group 1: %d)" % [g.groups[1].size(), g.groups[0].size()])
	g.set_selection([])
	key(1)
	check(g.selection.size() == g.groups[0].size() and g.selection.size() == 2, "1 selects group 1 (%d)" % g.selection.size())
	# F2 twice: the camera goes to the army's biggest clump
	for i in 5:
		g._add_unit("musketeer", g.human, Vector2(2000, 1500) + Vector2(randf() * 40.0, randf() * 40.0))
	g._add_unit("musketeer", g.human, Vector2(400, 1500))
	g.camera.position = Vector2(200, 200)
	var f2 := InputEventKey.new()
	f2.pressed = true
	f2.keycode = KEY_F2
	g.hud.bar.key(f2)
	var once: Vector2 = g.camera.position
	g.hud.bar.key(f2)
	await process_frame
	check(once.distance_to(Vector2(200, 200)) < 1.0 and g.camera.position.distance_to(Vector2(2020, 1520)) < 300.0, "F2 once selects; twice: the camera goes to the army (%s)" % str(g.camera.position))
	# PATROL on the minimap: the order is given at the minimap's point (not a view move)
	var pu: Unit = g._add_unit("musketeer", g.human, Vector2(600, 600))
	g.set_selection([pu])
	g.hud.controls.mode = "patrol"
	var m: Rect2 = g.hud.mini_rect()
	var cam0: Vector2 = g.camera.position
	g.hud._minimap_to(m.position + m.size * 0.75)
	var want := Vector2(0.75, 0.75) * Vector2(Game.W, Game.H) * Game.T
	check((pu.order == "patrol" or pu.patrol_b != Vector2.INF) and g.camera.position == cam0 and pu.order_point.distance_to(want) < 200.0, "PATROL on the minimap patrols there (order %s, to %s; want %s)" % [pu.order, str(pu.order_point), str(want)])
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
