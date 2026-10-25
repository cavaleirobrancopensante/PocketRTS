extends SceneTree
## Lists the English texts a player can reach in a match that have no translation:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/i18n_misses.gd -- <pt|es> > misses.txt
## Starts a match as each faction, selects every unit and building kind, builds the command card's
## tooltips and the panel texts, and prints what Loc.t could not translate.
var main


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Settings.load_all()
	Settings.device = "pc"
	Settings.language = a[0] if a.size() > 0 else "pt"
	Loc.set_lang(Settings.language)
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	Loc.track = true
	for fac in ["crown", "brood", "clockwork"]:
		await process_frame
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown" if fac != "crown" else "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
		await process_frame
		await process_frame
		var g: Game = main.game
		g.hud.countdown = 0.0
		paused = false
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		var hall: Building = g.halls_of(0)[0]
		g.camera.position = hall.center()
		g.players[0]["gold"] = 99999
		g.players[0]["res2"] = 99999
		var ents: Array = []
		for k in Defs.UNITS:
			if Defs.UNITS[k].get("faction", fac) == fac or Defs.UNITS[k].get("faction", "") == "":
				ents.append(g._add_unit(k, 0, hall.center() + Vector2(80, 140)))
		var spots: Array = []
		for r in range(6, 22):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) == r:
						spots.append(hall.cell + Vector2i(dx, dy))
		for k in Defs.BUILDINGS:
			if Defs.BUILDINGS[k].get("faction", fac) != fac:
				continue
			for c in spots:
				if g.placement_problem(0, k, c) == "":
					ents.append(g._add_building(k, 0, c, true))
					break
		ents.append(hall)
		for e in ents:
			if not is_instance_valid(e):
				continue
			g.set_selection([e])
			for i in 3:
				await process_frame
			_tips(g)
		# a mixed selection (page 2 of the card, refits, groups)
		g.set_selection(ents.filter(func(x: Variant) -> bool: return x is Unit))
		for i in 3:
			await process_frame
		_tips(g)
		for i in range(4):
			g.hud._res_tip(i)
		main.show_menu()
	var done := {}      # texts that are already a translation come back through Loc.t unchanged: not misses
	for k in Loc.table(Loc.lang):
		done[Loc.table(Loc.lang)[k]] = true
	var out: Array = []
	for k in Loc.misses:
		if not done.has(String(k).strip_edges()) and not done.has(k):
			out.append(k)
	out.sort()
	for s in out:
		print(String(s).replace("\n", "\\n"))
	print("--- %d untranslated texts" % out.size())
	quit()


func _tips(g: Game) -> void:
	var h = g.hud
	for bt in h._card_buttons:
		var t: Dictionary = h._card_tip(bt["item"])
		for f in ["title", "stats", "need", "body", "hint"]:
			if String(t.get(f, "")) != "":
				Loc.t(String(t[f]))
		Loc.t(String(bt["item"][1]).trim_prefix("> ").trim_prefix("~ "))
		if bt.has("why") and String(bt["why"]) != "":
			Loc.t(String(bt["why"]))
	for e in g.selection:
		var t: Dictionary = h._entity_tip(e)
		for f in ["title", "stats", "need", "body", "hint"]:
			if String(t.get(f, "")) != "":
				Loc.t(String(t[f]))
