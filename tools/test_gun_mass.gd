extends SceneTree
## A gun is not shoved by the men behind it; a rally on the Town Hall does not make haulers.
##   godot --headless --fixed-fps 30 --script res://tools/test_gun_mass.gd
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
	var p: Vector2 = hall.center() + Vector2(0, 220)
	var gun: Unit = g._add_unit("cannon", 0, p)
	var man: Unit = g._add_unit("musketeer", 0, p + Vector2(10, 0))
	await physics_frame
	await physics_frame
	var on_man: Vector2 = g.separation(man)
	var on_gun: Vector2 = g.separation(gun)
	check(on_man.length() > on_gun.length() * 5.0, "the man gives way far more than the gun (%.0f vs %.0f)" % [on_man.length(), on_gun.length()])
	# a rally on the Town Hall: the new labourer takes a real post, not the hall
	hall.worker_rally = hall.center()
	hall.worker_rally_target = hall
	var before := hall.haulers().size()
	var workers_before := g.workers(0).size()
	g.players[0]["gold"] = 5000
	hall.queue = ["labourer"]
	for i in 900:
		await physics_frame
	var made := g.workers(0).filter(func(u: Unit) -> bool: return u.is_hauler())
	check(g.workers(0).size() > workers_before, "a labourer was trained (%d workers, were %d)" % [g.workers(0).size(), workers_before])
	check(made.size() == before, "a rally on the Town Hall makes no hauler (%d haulers, were %d)" % [made.size(), before])
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit()
