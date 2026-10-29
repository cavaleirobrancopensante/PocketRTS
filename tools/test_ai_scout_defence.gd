extends SceneTree
## A lone enemy scout in the computer's base: two workers go for it with an ATTACK order (they
## hurt it), the rest keep working.   godot --headless --fixed-fps 30 --script res://tools/test_ai_scout_defence.gd
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
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})      # (0.18.0: was the old Brood; the Brood of creatures has no hall and its own computer)
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var hive: Building = g.halls_of(1)[0]
	var scout: Unit = g._add_unit("labourer", 0, hive.center() + Vector2(0, 150))
	scout.max_hp = 4000.0
	scout.hp = 4000.0
	var most := 0
	for i in 600:
		await physics_frame
		var n := g.workers(1).filter(func(u: Unit) -> bool: return u.order == "attack" and u.target == scout).size()
		most = maxi(most, n)
	check(most >= 1, "workers go for the scout with an attack order (most at once: %d)" % most)
	check(most <= 2, "no more than two at once (%d)" % most)
	check(scout.hp < 4000.0, "the scout is actually hurt (%.0f of 4000)" % scout.hp)
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit()
