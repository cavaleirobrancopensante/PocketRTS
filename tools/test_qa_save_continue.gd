extends SceneTree
## QA soak: save in the middle of a match for each faction and CONTINUE it the way the main menu does
## (main._autosave, back to the menu, the CONTINUE button's cfg + "resume"). Checks the units, buildings and money come
## back and the match plays on.
##   godot --headless --fixed-fps 30 --script res://tools/test_qa_save_continue.gd
var main: Node
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _wait(secs: float) -> void:
	var g = main.game
	var c0: float = g.clock
	var n := 0
	while g.clock < c0 + secs and n < int(secs * 40) + 200:
		await process_frame
		n += 1


func _counts(g) -> Dictionary:
	var d := {}
	for u in g.units:
		if is_instance_valid(u) and not u.dead:
			var k := "u%d:%s" % [u.team, u.kind]
			d[k] = int(d.get(k, 0)) + 1
	for b in g.buildings:
		if is_instance_valid(b) and not b.dead and not b.ghost:
			var k := "b%d:%s%s" % [b.team, b.kind, "" if b.built else "(site)"]
			d[k] = int(d.get(k, 0)) + 1
	for t in g.n_players():
		d["gold%d" % t] = int(g.players[t]["gold"])
		d["res2_%d" % t] = int(g.players[t]["res2"])
	return d


func _run() -> void:
	await process_frame
	var pairs := [["crown", "brood"], ["brood", "clockwork"], ["clockwork", "crown"]]
	for pr in pairs:
		var me: String = pr[0]
		main.start({"map": "ashford_crossing", "seed": 11, "slots": [
			{"who": "you", "faction": me, "colour": 0, "side": 0},
			{"who": "hard", "faction": pr[1], "colour": 1, "side": 1, "strategy": "balanced"}]})
		await process_frame
		await process_frame
		var g = main.game
		paused = false
		# the human side does a little: its workers' start is the game's own (idle); let the computer play 4 minutes
		await _wait(240.0)
		var before := _counts(g)
		var clock0: float = g.clock
		main._autosave()
		check("%s: autosave written" % me, SaveGame.exists())
		main._to_menu()
		await process_frame
		await process_frame
		var save := SaveGame.peek()
		check("%s: the menu offers CONTINUE (save of this version)" % me, not save.is_empty() and save.get("version", "") == ProjectSettings.get_setting("application/config/version", "dev"))
		if save.is_empty():
			continue
		var cfg: Dictionary = save["cfg"].duplicate(true)
		cfg["resume"] = save
		main.start(cfg)
		await process_frame
		await process_frame
		g = main.game
		var after := _counts(g)
		check("%s: clock comes back" % me, absf(g.clock - clock0) < 1.0, "%.1f vs %.1f" % [g.clock, clock0])
		var diff := PackedStringArray()
		for k in before.keys() + after.keys():
			if int(before.get(k, 0)) != int(after.get(k, 0)):
				if not diff.has(k):
					diff.append("%s %d->%d" % [k, int(before.get(k, 0)), int(after.get(k, 0))])
		check("%s: units, buildings and money come back" % me, diff.is_empty(), ", ".join(diff))
		check("%s: factions come back" % me, g.faction_of(0) == me and g.faction_of(1) == pr[1])
		var ai_n: int = g.ais.size()
		check("%s: the computer is back" % me, ai_n == 1)
		var earned0 := int(g.stats[1]["gold"])
		await _wait(90.0)
		check("%s: the match plays on (clock)" % me, g.clock > clock0 + 80.0, "%.1f" % g.clock)
		check("%s: the computer keeps earning" % me, int(g.stats[1]["gold"]) > earned0, "%d -> %d" % [earned0, int(g.stats[1]["gold"])])
		main._to_menu()
		SaveGame.clear()
		await process_frame
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
