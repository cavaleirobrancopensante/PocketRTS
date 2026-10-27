extends SceneTree
## QA soak: the SANDBOX and the CLOCKWORK LAB from the EDITOR menu.
## SANDBOX: a 4-player sandbox match (you + three computers, one per faction); the panel's buttons are pressed by their
## text (+1000, +200, FOG, SPEED, CONTROL of another player, AI: OFF / ON, KILL ALL) and every unit and building of the
## panel's lists is put down for every player the way a click on the map does; the match then plays on two minutes.
## LAB: Main.start_lab; the gear field and its units are there, the computer never attacks, and the match plays on.
##   godot --headless --fixed-fps 30 --script res://tools/test_qa_sandbox_lab.gd
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


func _panel() -> SandboxPanel:
	for c in main.ui_layer.get_children():
		if c is SandboxPanel:
			return c
	return null


func _press(p: SandboxPanel, prefix: String) -> bool:
	for b in p.find_children("*", "Button", true, false):
		if is_instance_valid(b) and not b.is_queued_for_deletion() and String(b.text).strip_edges().begins_with(prefix):
			b.pressed.emit()
			return true
	return false


func _wait(g, secs: float) -> void:
	var c0: float = g.clock
	var n := 0
	while g.clock < c0 + secs and n < int(secs * 45) + 200:
		await process_frame
		n += 1


func _run() -> void:
	await process_frame
	# ---- SANDBOX
	main.start({"map": "greenhold", "seed": 21, "sandbox": true, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"},
		{"who": "hard", "faction": "clockwork", "colour": 2, "side": 2, "strategy": "balanced"},
		{"who": "normal", "faction": "crown", "colour": 3, "side": 3, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	paused = false
	var p := _panel()
	check("sandbox: the panel is there", p != null)
	if p == null:
		quit(1)
		return
	await _wait(g, 20.0)
	var gold0 := int(g.players[0]["gold"])
	check("sandbox: +1000 gives money", _press(p, "+1000") and int(g.players[0]["gold"]) >= gold0 + 1000, "%d -> %d" % [gold0, int(g.players[0]["gold"])])
	check("sandbox: +200 (second resource) pressed", _press(p, "+200"))
	await process_frame
	var fog0 := g.reveal
	_press(p, "FOG")
	check("sandbox: FOG switches", g.reveal != fog0)
	await process_frame
	_press(p, "SPEED")
	check("sandbox: SPEED x2", is_equal_approx(Engine.time_scale, 2.0), str(Engine.time_scale))
	await process_frame
	_press(p, "SPEED")
	await process_frame
	_press(p, "SPEED")
	check("sandbox: SPEED back to x1", is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	# put down every unit and building of every faction for every player (as the panel's map click does)
	var made_u := 0
	var made_b := 0
	var no_room := PackedStringArray()
	var mid := Vector2(Game.W, Game.H) * Game.T * 0.5
	for t in g.n_players():
		for f in ["crown", "brood", "clockwork"]:
			var kinds: Array = []
			for k in Defs.UNITS:
				if Defs.UNITS[k]["faction"] == f and not Defs.energy_only(k) and not Defs.retired(k):
					kinds.append(k)
			for k in Defs.FACTIONS[f]["build"] + Defs.build_list(f):
				if not kinds.has(k) and not Defs.energy_only(k) and not Defs.retired(k):
					kinds.append(k)
			for k in kinds:
				var at: Vector2 = mid + Vector2(randf_range(-900, 900), randf_range(-600, 600))
				if Defs.UNITS.has(k):
					for n in int(Defs.UNITS[k].get("spawn", 1)):
						g._add_unit(k, t, at + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
						made_u += 1
				else:
					var size: Vector2i = Defs.BUILDINGS[k]["size"]
					var placed := false
					for tries in 40:
						var c := g.cell_of(mid + Vector2(randf_range(-1400, 1400), randf_range(-900, 900))) - size / 2
						var ok := true
						for y in size.y:
							for x in size.x:
								if not g.is_free(c + Vector2i(x, y)):
									ok = false
						if ok:
							var b := g._add_building(k, t, c, true)
							g.on_building_complete(b)
							g.swamp_dirty = true
							made_b += 1
							placed = true
							break
					if not placed:
						no_room.append(k)
	check("sandbox: every unit and building put down", made_u > 50 and made_b > 30, "%d units, %d buildings (no room for %s)" % [made_u, made_b, ", ".join(no_room)])
	await _wait(g, 30.0)
	check("sandbox: CONTROL of player 2", _press(p, "2") and _press(p, "CONTROL") and g.human == 1, "human %d" % g.human)
	await _wait(g, 10.0)
	var ai_on := 0
	for a in g.ais:
		if a.process_mode != Node.PROCESS_MODE_DISABLED:
			ai_on += 1
	check("sandbox: player 1 got a computer, player 2 lost its own", ai_on == 3 and g.ais.filter(func(a) -> bool: return a.team == 0).size() == 1, "%d on" % ai_on)
	_press(p, "3")
	await process_frame
	_press(p, "AI: ON")
	var ai3_off := false
	for a in g.ais:
		if a.team == 2:
			ai3_off = a.process_mode == Node.PROCESS_MODE_DISABLED
	check("sandbox: AI: OFF for player 3", ai3_off)
	await process_frame
	_press(p, "KILL ALL")
	await process_frame
	check("sandbox: KILL ALL of player 3", g.army(2).is_empty(), "%d left" % g.army(2).size())
	_press(p, "1")
	await process_frame
	_press(p, "CONTROL")
	check("sandbox: CONTROL back to player 1", g.human == 0)
	await _wait(g, 60.0)
	check("sandbox: the match plays on", g.clock > 110.0 and not g.over, "%.0f s" % g.clock)
	main._to_menu()
	Engine.time_scale = 1.0
	await process_frame
	# ---- CLOCKWORK LAB
	main.start_lab()
	await process_frame
	await process_frame
	g = main.game
	paused = false
	var kinds_b := {}
	for b in g.buildings:
		if b.team == 0 and not b.dead:
			kinds_b[b.kind] = int(kinds_b.get(b.kind, 0)) + 1
	var kinds_u := {}
	for u in g.units:
		if u.team == 0 and not u.dead:
			kinds_u[u.kind] = int(kinds_u.get(u.kind, 0)) + 1
	check("lab: the gear field is set out", kinds_b.has("cog_press") and kinds_b.has("mainspring") and kinds_b.has("movement_works"), str(kinds_b))
	check("lab: its units are there", kinds_u.size() >= 5, str(kinds_u))
	check("lab: the computer is peaceful", g.ais.size() == 1 and g.ais[0].peaceful)
	check("lab: the sandbox panel is there", _panel() != null)
	await _wait(g, 240.0)
	check("lab: plays four minutes, nothing of yours attacked", g.clock > 230.0 and int(g.stats[1]["killed"]) == 0 and not g.over, "clock %.0f, the computer killed %d" % [g.clock, int(g.stats[1]["killed"])])
	main._to_menu()
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
