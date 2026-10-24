extends SceneTree
## The supply tooltip shows the workers / army split:
##   godot --headless --fixed-fps 30 --script res://tools/test_supply_tip.gd
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
	main.start({"map": "greenhold", "seed": 1, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	var h = g.hud
	var sp: Dictionary = h._supply_split(g.human)
	check(sp["workers"] > 0, "workers counted: %s" % str(sp))
	check(int(sp["workers"]) + int(sp["army"]) + int(sp["queued"]) == g.supply_used(g.human), "split adds up to the supply used")
	var t: Dictionary = h._res_tip(2)
	check(String(t.get("body", "")).begins_with("Workers "), "tip body starts with the split: " + String(t.get("body", "")).split("\n")[0])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
