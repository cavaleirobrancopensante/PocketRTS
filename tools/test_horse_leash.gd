extends SceneTree
## A led horse far from its leader (or jammed) is brought back beside him: the leash has a length.
##   godot --headless --fixed-fps 30 --script res://tools/test_horse_leash.gd
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
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var hall: Building = g.halls_of(0)[0]
	var p: Vector2 = hall.center() + Vector2(0, 200)
	var man: Unit = g._add_unit("labourer", 0, p)
	var horse: Unit = g._add_unit("horse", 0, p + Vector2(500, 0))     # (a horse far away)
	man.take_reins(horse)
	for i in 120:
		await physics_frame
	var d := horse.position.distance_to(man.position)
	check(d < Unit.LEASH_MAX * 1.6, "a horse 500 px off is back at its leader's side (%d px)" % d)
	# the leader walks away through the base: the horse keeps up
	man.cmd_move(p + Vector2(-300, 0))
	for i in 240:
		await physics_frame
	d = horse.position.distance_to(man.position)
	check(d < Unit.LEASH_MAX * 1.6 and man.led.has(horse), "it follows the walking leader (%d px)" % d)
	print("horse leash: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
