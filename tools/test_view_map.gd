extends SceneTree
## After SURRENDER the battle report has VIEW MAP: the report steps aside, no fog, a bar brings it back.
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
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for i in 5:
		await physics_frame
	g.player_surrender()
	var rep: Control = null
	for i in 400:
		await physics_frame
		for c in main.ui_layer.get_children():
			if c.has_signal("view_map"):
				rep = c
		if rep:
			break
	check(rep != null, "the battle report appears after surrender")
	if rep:
		check(not g.reveal, "the map is still under fog on the report")
		rep.view_map.emit()
		await process_frame
		check(g.reveal and g.over, "VIEW MAP shows the whole map")
		check(not rep.visible, "the report steps aside")
		var bar: Control = null
		for c in main.ui_layer.get_children():
			if c is HBoxContainer and c.get_child_count() == 2:
				bar = c
		check(bar != null, "a bar with BATTLE REPORT / MENU is there")
		if bar:
			(bar.get_child(0) as Button).pressed.emit()
			await process_frame
			check(rep.visible, "BATTLE REPORT brings it back")
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
