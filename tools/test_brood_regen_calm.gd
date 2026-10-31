extends SceneTree
## The Brood heals on its swamp (and the rooted Mother) only OUT OF THE FIGHT (the owner, 2026-10-31: "a clock soldier
## cant kill a rooted turtle, the regeneration should only trigger after combat, not during combat").
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_regen_calm.gd
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


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	var n := 0
	while g.clock < end and n < int(sec * 60) + 300:
		await physics_frame
		n += 1


func _run() -> void:
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "brood", "colour": 0, "side": 0},
		{"who": "you", "faction": "clockwork", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	g = main.game
	paused = false
	for a in g.ais:
		a.set_process(false)
	var q: Unit = BroodNew.queen(g, 0)
	# a turtle rooted on the Mother's swamp
	var p: Vector2 = BroodRoot.snap(BroodNew.TURTLE, q.position + Vector2(6, 0) * Defs.TILE)
	var t: Unit = g._add_unit(BroodNew.TURTLE, 0, p)
	t.cmd_deploy()
	await wait(float(Defs.NB["turtle_switch"]) + 1.5)
	check(BroodRoot.fixed(t) and g.on_swamp(0, t.position), "a Mound Turtle rooted on the swamp")
	# heals out of the fight
	t.hp = t.max_hp * 0.5
	var h0 := t.hp
	await wait(3.0)
	check(t.hp > h0 + 3.0, "out of the fight it heals (%.0f -> %.0f)" % [h0, t.hp])
	# under a steady hit it doesn't
	t.hp = t.max_hp * 0.5
	var foe: Unit = g._add_unit("clock_soldier", 1, t.position + Vector2(90, 0))
	for i in 10:
		t.take_damage(1.0, foe)
		h0 = t.hp
		await wait(1.0)
		check(t.hp <= h0 + 0.01, "    hit every second: no healing (%.1f -> %.1f)" % [h0, t.hp]) if i == 9 else null
	# 5 s after the last hit it heals again (the soldier gone)
	foe.take_damage(999999.0, null)
	h0 = t.hp
	await wait(float(Defs.NB["regen_calm"]) + 1.5)
	check(t.hp > h0 + 1.0, "5 s after the last hit it heals again (%.0f -> %.0f)" % [h0, t.hp])
	# the Mother rooted: the same
	if BroodRoot.fixed(q):
		q.hp = q.max_hp * 0.5
		var foe2: Unit = g._add_unit("clock_soldier", 1, q.position + Vector2(400, 0))
		q.take_damage(1.0, foe2)
		var qh := q.hp
		await wait(2.0)
		check(q.hp <= qh + 0.01, "the rooted Mother doesn't heal right after a hit")
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
