extends SceneTree
## Grubs told to ATTACK (attack-move) fight what they meet, like Raptors; Labourers still just walk.
##   godot --headless --fixed-fps 30 --script res://tools/test_grub_attack.gd
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
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await physics_frame
	var grubs: Array = g.units.filter(func(u): return u.team == 0 and u.kind == "grub" and not u.dead).slice(0, 6)
	var c: Vector2 = grubs[0].position
	var foe = g._add_unit("musketeer", 1, c + Vector2(160, 0))
	foe.order = "hold"
	g.set_selection(grubs)
	g.group_move(grubs, c + Vector2(190, 0), true)
	check(grubs[0].order == "amove", "ATTACK gives a grub an attack-move (%s)" % grubs[0].order)
	var t0: float = g.clock
	while g.clock < t0 + 25.0 and not foe.dead:
		await physics_frame
	check(foe.dead or foe.hp < foe.max_hp, "the grubs attacked the musketeer (hp %d of %d, %.0f s)" % [int(foe.hp), int(foe.max_hp), g.clock - t0])
	# Labourers still just walk
	var lab = g.units.filter(func(u): return u.kind == "labourer")
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
