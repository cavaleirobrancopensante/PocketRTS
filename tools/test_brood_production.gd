extends SceneTree
## Watching computers: the PRODUCTION list shows the Brood's eggs, moults and research (it has no buildings; the
## owner, 2026-10-31: "the brood production tab when I am watching a game between 2 AI doesnt show anything").
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_production.gd
var main: Node
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-60s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.start({"map": "twin_crowns", "seed": 7, "slots": [
		{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "random"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "random"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	var seen := 0
	var kinds := {}
	var n := 0
	while g.clock < 150.0 and n < 9000:
		await process_frame
		n += 1
		if n % 30 == 0:
			var it: Array = g.hud.prod_items(0)
			seen = maxi(seen, it.size())
			for x in it:
				kinds[String(x[0])] = true
	check("the Brood's production list is not always empty", seen > 0, "at most %d, icons %s" % [seen, str(kinds.keys())])
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
