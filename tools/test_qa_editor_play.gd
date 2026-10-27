extends SceneTree
## QA soak: the MAP EDITOR end to end. A new map is made in the editor (Main.show_map_editor), two start spots go on it
## (one per team), CHECK runs, it is saved (the editor's own _save: the file and its picture), loaded again through
## MapGen.load_custom, PLAY takes it to the skirmish lobby, and a computer-only skirmish on it plays two minutes.
##   godot --headless --fixed-fps 30 --script res://tools/test_qa_editor_play.gd
var main: Node
var fails := 0
const NAME := "QA soak test map"


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
	MapGen.delete_custom(NAME)
	main.show_map_editor("", {"name": NAME, "size": [96, 72], "biome": "grass", "mirror": "rotate"})
	await process_frame
	await process_frame
	var ed: MapEditor = main._editor
	check("editor opens at the asked size", Game.W == 96 and Game.H == 72, "%dx%d" % [Game.W, Game.H])
	ed.starts = [Vector2i(12, 12), Vector2i(83, 59)]
	ed.teams = [0, 1]
	ed._rebuild()
	ed._run_check()
	var faults: int = ed._faults()
	check("CHECK runs and lists a bare map's problems (no cliffs, no hall spots)", faults > 0, str(ed.problems.map(func(p: Dictionary) -> String: return String(p["text"]))))
	var played := [""]
	ed.play_requested.connect(func(id: String, n: int) -> void: played[0] = "%s/%d" % [id, n])
	ed._play()
	await process_frame
	check("saved as one of your maps", MapGen.custom_names().has(NAME))
	var d := MapGen.load_custom(NAME)
	check("loads back (size, starts, teams)", MapGen.custom_size(d) == Vector2i(96, 72) and (d["starts"] as Array).size() == 2 and MapGen.custom_mode(d) == "1v1", "%s %s" % [MapGen.custom_size(d), MapGen.custom_mode(d)])
	check("PLAY goes to the skirmish with it", played[0] == "custom:%s/2" % NAME, played[0])
	await process_frame
	# a skirmish on it, computers only
	main.start({"map": "custom:" + NAME, "seed": 3, "slots": [
		{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g = main.game
	paused = false
	check("the match is on the saved map", Game.W == 96 and Game.H == 72 and g.n_players() == 2)
	var n := 0
	while g.clock < 120.0 and n < 6000:
		await process_frame
		n += 1
	var earned := [int(g.stats[0]["gold"]), int(g.stats[1]["gold"])]
	check("both computers play on it (earn, build)", earned[0] > 150 and earned[1] > 150 and g.buildings.filter(func(b) -> bool: return b.built and not b.dead).size() > 4, str(earned))
	main._to_menu()
	MapGen.delete_custom(NAME)
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
