extends SceneTree
## A Missionary is untouchable only within Defs.MISSIONARY_SAFE tiles of one of his side's Churches (the owner,
## 2026-10-31), and never near enemy buildings.
##   godot --headless --fixed-fps 30 --script res://tools/test_missionary_safe.gd
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
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	var hall: Building = g.buildings.filter(func(b) -> bool: return b.team == 0)[0]
	var m: Unit = g._add_unit("missionary", 0, hall.position + Vector2(200, 0))
	check(not m.untouchable(), "no Church: he can be hurt")
	var ch: Building = g._add_building("church", 0, hall.cell + Vector2i(6, 0), true)
	check(ch != null and m.untouchable(), "beside his Church: untouchable")
	m.position = ch.position + Vector2((Defs.MISSIONARY_SAFE + 4) * Defs.TILE, 0)
	check(not m.untouchable(), "far from it: he can be hurt")
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
