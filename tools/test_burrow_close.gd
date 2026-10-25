extends SceneTree
## A second Burrow may stand right beside the first (no spacing rule for the Brood).
var main: Node
var fails := 0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1
func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for i in 3:
		await physics_frame
	g.explored.fill(1)
	g.players[0]["gold"] = 5000
	var cap = g.capital(0)
	var found := 0
	var best := 999.0
	for gap in [1, 2, 3]:
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var s: Vector2i = Defs.BUILDINGS["hive"]["size"]
			var off := Vector2i(dir.x * (s.x + gap), dir.y * (s.y + gap))
			var cell: Vector2i = cap.cell + off
			if g.in_map(cell) and g.placement_problem(0, "hive", cell, true) == "":
				found += 1
				best = minf(best, (Vector2(cell) + Vector2(s) * 0.5).distance_to(cap.center() / Defs.TILE))
	check(found > 0, "a Burrow can be planted right beside the capital (%d spots, nearest %.1f tiles centre to centre)" % [found, best])
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
