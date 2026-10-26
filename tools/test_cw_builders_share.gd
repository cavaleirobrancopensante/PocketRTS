extends SceneTree
## Several Winders given a shift-queue of buildings share the sites out: one site each, not all on the first Winder.
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
		{"who": "you", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for i in 3:
		await physics_frame
	g.players[0]["gold"] = 5000
	var ws: Array = g.units.filter(func(u): return u.team == 0 and u.is_worker() and not u.dead)
	check(ws.size() >= 3, "at least 3 winders to start (%d)" % ws.size())
	ws = ws.slice(0, 3)
	var hall = g.halls_of(0)[0]
	var base: Vector2i = g.cell_of(hall.center())
	var placed := 0
	var sites: Array = []
	for dx in range(-30, 31, 1):
		for dy in range(-30, 31, 1):
			if placed >= 3:
				break
			var c := base + Vector2i(dx, dy)
			var kind: String = ["mainspring", "regulator", "regulator"][placed]      # (gear mode: no Boilers)
			if g.placement_problem(0, kind, c) == "":
				var b = g.place_building(0, kind, c, ws, true)
				if b:
					placed += 1
					sites.append(b)
	check(placed == 3, "three sites queued (%d)" % placed)
	var busy := 0
	for w in ws:
		if w.order == "build" or w.queue.size() > 0:
			busy += 1
	for w in ws:
		print("w ", w.order, " q=", w.queue.size())
	check(busy == 3, "every winder has a site (%d of 3)" % busy)
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
