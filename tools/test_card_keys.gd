extends SceneTree
## ONE CARD, NO PAGES (the owner, 2026-10-30): every selection's command card is one list (no MORE),
## and no two of its commands share a key letter. Plays each faction in turn and builds the card for
## every unit kind alone (with no research and with all of it), every building kind (built, training,
## a site), a worker's build page, typical mixed selections (the whole army, workers with soldiers,
## every production building) and, for the Brood, the Brood Mother rooted and uprooted.
##   godot --headless --fixed-fps 30 --script res://tools/test_card_keys.gd [-- crown|brood|clockwork]
## Prints each card's keys ("KEYS <faction> | <where> | LABEL=K ...") and FAIL for a clash.
var main: Node
var t := 0.0
var facs: Array = ["crown", "brood", "clockwork"]
var fi := 0
var busy := false
var fails := 0
var cards := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		facs = [args[0]]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if busy or t < 0.2:
		return false
	busy = true
	_run()
	return false


func _start(f: String) -> Game:
	var foe := "brood" if f == "crown" else "crown"
	if main.game != null:
		main._to_menu()
		await process_frame
		await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": f, "colour": 0, "side": 0},
		{"who": "easy", "faction": foe, "colour": 1, "side": 1}]})
	for i in 30:
		await physics_frame
	var g: Game = main.game
	g.hud.countdown = 0.0
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	g.players[0]["gold"] = 99999
	g.players[0]["res2"] = 99999.0
	g.players[0]["tension"] = 9999.0
	g.players[0]["cap"] = 200
	return g


func _run() -> void:
	for f in facs:
		var g: Game = await _start(f)
		await _sweep(g, f)
	print("%d cards checked" % cards)
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func _card(g: Game, f: String, where: String) -> void:
	g.hud._refresh_card()
	var items: Array = g.hud._card_items
	if items.is_empty():
		return
	cards += 1
	var seen := {}
	var line := PackedStringArray()
	var bad := PackedStringArray()
	for it in items:
		var lab := String(it[1]).trim_prefix("> ").trim_prefix("~ ")
		var k: String = String(it[6]) if it.size() > 6 else ""
		line.append("%s=%s" % [lab, k])
		if lab == "MORE":
			bad.append("a MORE button")
		if k == "":
			continue
		if seen.has(k):
			bad.append("%s and %s both %s" % [seen[k], lab, k])
		seen[k] = lab
	if g.hud._card_buttons.size() > 12:
		bad.append("%d buttons shown" % g.hud._card_buttons.size())
	print("KEYS %s | %s | %s" % [f, where, " ".join(line)])
	if not bad.is_empty():
		fails += 1
		print("FAIL  %s %s: %s" % [f, where, "; ".join(bad)])


func _sweep(g: Game, f: String) -> void:
	var c := Vector2i(g.W / 2, g.H / 2)
	var at: Vector2 = g.cell_center(g.nearest_free(c, 10))
	var tech0: Dictionary = (g.players[0]["tech"] as Dictionary).duplicate()
	var kinds: Array = []
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if String(d.get("faction", "")) != f or Defs.energy_only(k) or (Defs.CW_KINDS.has(k) and not Defs.cw_roster):
			continue
		kinds.append(k)
	for pass_i in 2:
		if pass_i == 1:
			for rk in Defs.RESEARCH:
				g.players[0]["tech"][rk] = true
		var tag := " (all research)" if pass_i == 1 else ""
		# ---- each unit alone, and in its other mode
		for k in kinds:
			var u: Unit = g._add_unit(k, 0, at)
			await physics_frame
			g.set_selection([u])
			_card(g, f, "unit %s%s" % [k, tag])
			if u.deploys():
				u.tesla_mode = "deployed" if u.tesla_mode == "packed" else "packed"
				_card(g, f, "unit %s (other mode)%s" % [k, tag])
			g.consume_unit(u)
			await physics_frame
		# ---- mixed: the whole army, workers with soldiers
		var army: Array = []
		for k in kinds:
			if k == BroodNew.QUEEN or k == BroodNew.EGG:
				continue
			var u: Unit = g._add_unit(k, 0, at + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
			army.append(u)
		await physics_frame
		g.set_selection(army)
		_card(g, f, "every unit kind together%s" % tag)
		var wk := String(Defs.FACTIONS[f]["worker"])
		var mixed: Array = army.filter(func(u: Unit) -> bool: return u.kind == wk or not u.is_worker()).slice(0, 6)
		g.set_selection(mixed)
		_card(g, f, "workers and soldiers%s" % tag)
		for u in army:
			g.consume_unit(u)
		await physics_frame
		# ---- a worker's build page
		var w: Unit = g._add_unit(wk, 0, at)
		await physics_frame
		g.set_selection([w])
		_card(g, f, "worker%s" % tag)
		g.hud.page = "build"
		_card(g, f, "worker build page%s" % tag)
		g.hud.page = ""
		g.consume_unit(w)
		# ---- buildings (the Brood has none): each alone, training, and all production buildings together
		var prod: Array = []
		for k in Defs.build_list(f):
			if not Defs.BUILDINGS.has(k):
				continue
			var cell := g.nearest_free(c + Vector2i(6, 6), 30)
			var b: Building = g._add_building(k, 0, cell, true)
			await physics_frame
			if b == null:
				continue
			g.set_selection([b])
			_card(g, f, "building %s%s" % [k, tag])
			var tr: Array = b.d.get("trains", [])
			if not tr.is_empty():
				g.train(b, String(tr[0]))
				_card(g, f, "building %s (training)%s" % [k, tag])
				prod.append(b)
			else:
				b.take_damage(999999.0, null)
		if not prod.is_empty():
			g.set_selection(prod)
			_card(g, f, "every production building%s" % tag)
		for b in prod:
			b.take_damage(999999.0, null)
		await physics_frame
	# ---- the Brood Mother: rooted and uprooted, with eggs to lay and research done
	if f == "brood":
		var qs: Array = g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == BroodNew.QUEEN)
		if qs.is_empty():
			fails += 1
			print("FAIL  no Brood Mother")
			return
		var q: Unit = BroodNew.queen(g, 0)
		q.tesla_mode = "deployed"        # (at the start she is still rooting)
		q.nb["eggs"] = 6
		g.set_selection([q])
		_card(g, f, "the Brood Mother rooted (all research)")
		var mode: String = q.tesla_mode
		q.tesla_mode = "packed"
		_card(g, f, "the Brood Mother uprooted")
		q.tesla_mode = mode
		g.players[0]["tech"] = tech0.duplicate()
		_card(g, f, "the Brood Mother rooted (no research)")
		q.nb["stage"] = 1
		BroodNew.apply_stage(q)
		_card(g, f, "the Brood Mother rooted at stage 2 (no research)")
		await _scroll_checks(g, q)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## The Mother's long card: Raptors keep R, RALLY works by its key while scrolled out of view; the
## wheel and the bar scroll it; on a phone a finger's drag scrolls (no button fires) and a tap acts.
func _scroll_checks(g: Game, q: Unit) -> void:
	var hud = g.hud
	g.set_selection([q])
	hud._refresh_card()
	var keys := {}
	for it in hud._card_items:
		keys[String(it[1]).trim_prefix("> ").trim_prefix("~ ")] = String(it[6])
	check(hud._card_rows > 3, "the stage 2 Mother's card is long (%d rows: %s)" % [hud._card_rows, ", ".join(keys.keys())])
	check(keys.get("RAPTORS", "") == "R" and keys.get("RALLY", "") not in ["", "R"], "Raptors keep R, RALLY has its own key (%s)" % keys.get("RALLY", ""))
	var wk_shown: bool = hud._card_buttons.any(func(bt) -> bool: return String(bt["item"][1]).ends_with("WORKERS"))
	check(not wk_shown, "WORKERS (a rare one, last) is below the first 3 rows")
	check(hud.hotkey(OS.find_keycode_from_string(keys["WORKERS"])) and g.controls.mode == "nb_rally_worker", "its key (%s) works while it is scrolled out of view" % keys["WORKERS"])
	g.controls.cancel_mode()
	hud._refresh_card()
	check(hud._card_scroll == 0, "back from the RALLY card: still at the top")
	hud.card_scroll_by(1)
	hud._refresh_card()
	check(hud._card_scroll == 1, "the wheel scrolls a row")
	g.controls.mode = "nb_rally"
	hud._refresh_card()
	g.controls.cancel_mode()
	hud._refresh_card()
	check(hud._card_scroll == 1, "the scroll comes back with the card after a targeting card")
	var bar: Rect2 = hud._card_bar
	hud._press(Vector2(bar.get_center().x, bar.position.y + 1))
	hud._release(Vector2(bar.get_center().x, bar.position.y + 1))
	hud._refresh_card()
	check(hud._card_scroll == 0, "a press at the bar's top scrolls to the top")
	Settings.device = "phone"
	hud._refresh_card()
	var b0: Rect2 = hud._card_buttons[0]["rect"]
	var p := b0.get_center()
	hud._press(p)
	hud._card_move(p + Vector2(0, -hud._btn() - 4))
	hud._release(p + Vector2(0, -hud._btn() - 4))
	hud._refresh_card()
	check(hud._card_scroll == 1 and g.controls.mode == "" and q.nb.get("eggs", 0) == 6, "phone: a finger's drag scrolls a row and presses nothing")
	hud._card_scroll = 9
	hud._refresh_card()
	var rb := {}
	for bt in hud._card_buttons:
		if String(bt["item"][1]).ends_with("RALLY"):
			rb = bt
	check(not rb.is_empty(), "scrolled to the bottom: RALLY shown")
	if not rb.is_empty():
		hud._press((rb["rect"] as Rect2).get_center())
		check(g.controls.mode == "", "phone: a press alone does nothing yet (it might be a drag)")
		hud._release((rb["rect"] as Rect2).get_center())
		check(g.controls.mode == "nb_rally", "phone: the tap's release presses RALLY")
		g.controls.cancel_mode()
	Settings.device = "pc"
