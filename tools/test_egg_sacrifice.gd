extends SceneTree
## SACRIFICE on an egg (the owner, 2026-10-31): its young go straight to the Brood Mother to be devoured as they hatch.
##   godot --headless --fixed-fps 30 --script res://tools/test_egg_sacrifice.gd
var fails := 0


func check(ok: bool, name: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start({"map": "greenhold", "seed": 3, "slots": [
		{"who": "you", "faction": "brood", "colour": 0, "side": 0},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	var q: Unit = BroodNew.queen(g, 0)
	var e: Unit = g._add_unit(BroodNew.EGG, 0, q.position + Vector2(0, 140))
	e.nb["k"] = "raptor"
	e.nb["t"] = 0.0
	check(e.can_sacrifice(), "an egg can be offered up")
	e.cmd_sacrifice()
	check(bool(e.nb.get("sac", false)), "SACRIFICE marks it")
	e.nb["t"] = BroodNew.egg_time("raptor") - 0.05
	var n := 0
	while not e.nb.has("out") and n < 200:
		await physics_frame
		n += 1
	var young: Array = g.units.filter(func(u: Unit) -> bool: return u.kind == "raptor" and u.team == 0 and not u.dead)
	check(not young.is_empty() and young.all(func(u: Unit) -> bool: return u.order == "sacrifice"), "its young hatch straight onto SACRIFICE (%d, %s)" % [young.size(), str(young.map(func(u): return u.order))])
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
