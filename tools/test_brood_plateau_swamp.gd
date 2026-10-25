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
	g._update_swamp()
	var cap = g.capital(0)
	var tot := 0
	var miss := 0
	var start: Vector2i = g.cell_of(cap.rect().get_center())
	for y in g.H:
		for x in g.W:
			if g.height[y * g.W + x] == 1 and g.water[y * g.W + x] != 1:
				var c := Vector2i(x, y)
				# only the capital's own plateau (near it)
				if Vector2(c).distance_to(Vector2(start)) < 20.0:
					tot += 1
					if g.swamp[0][y * g.W + x] != 1:
						miss += 1
	check(tot > 100 and miss == 0, "every high-ground tile near the capital is swamp (%d tiles, %d missing)" % [tot, miss])
	print("DONE  %d failure(s)" % fails)
	quit(fails)
