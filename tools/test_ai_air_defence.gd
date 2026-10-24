extends SceneTree
## A raid of flyers only is not answered by soldiers who cannot hit flyers (cuirassiers stay put,
## musketeers go), and labourers do not pitch in.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_air_defence.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(77)
	main.start({"map": "greenhold", "seed": 77, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI = null
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	var hall: Building = g.halls_of(0)[0]
	var home: Vector2 = hall.center() + Vector2(0, 160)
	var pikes: Array = []
	var guns: Array = []
	for i in 3:
		pikes.append(g._add_unit("cuirassier", 0, home + Vector2(i * 20, 0)))
		guns.append(g._add_unit("musketeer", 0, home + Vector2(i * 20, 30)))
	var far := hall.center() + Vector2(-200, -120)     # (the raid is at the other side of the base)
	var fly: Unit = g._add_unit("skywing", 1, far)
	fly.max_hp = 99999.0
	fly.hp = fly.max_hp
	check(fly != null and fly.is_air(), "a Skywing is in the air over the base")
	for u in pikes + guns:
		u.cmd_stop()
	for i in 360:
		await physics_frame
		if is_instance_valid(fly):
			fly.position = far
			fly.hp = fly.max_hp
	for u in pikes + guns:
		u.cmd_stop()
	ai._army()
	var pike_moved := 0
	var gun_moved := 0
	for u in pikes:
		if u.order_point.distance_to(far) < 200.0 and u.order != "idle":
			pike_moved += 1
	for u in guns:
		if u.order != "idle" and (u.order_point.distance_to(far) < 200.0 or u.target == fly):
			gun_moved += 1
	check(pike_moved == 0, "cuirassiers are not sent after the flyer (%d sent)" % pike_moved)
	check(gun_moved > 0, "musketeers answer the flyer (%d sent)" % gun_moved)
	print("ai air defence: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
