extends SceneTree
## ONE CARD, NO PAGES (the owner, 2026-10-30): every selection's command card is one list (no MORE),
## and no two of its commands share a key letter. Plays each faction in turn and builds the card for
## every unit kind alone (with no research and with all of it), every building kind (built, training,
## a site), a worker's build page, typical mixed selections (the whole army, workers with soldiers,
## every production building) and, for the Brood, the Brood Mother rooted and uprooted.
##   godot --headless --fixed-fps 30 --script res://tools/test_card_keys.gd [-- crown|brood|clockwork]
## Prints each card's keys ("KEYS <faction> | <where> | LABEL=K ...") and FAIL for a clash.
## STABLE KEYS (0.24.22, the owner 2026-10-31: "the command card should never or almost never change the hotkeys
## midmatch"): for every kind with research (the Armoury, the Clockwork's research buildings, the Brood Mother and each
## Sire) the letters are recorded, a research started (by its key), the queue filled, the creature uprooted and rooted
## again, the research done: no command left on the card may change its letter, and a research key pressed twice
## queues the next one or does nothing (never STOP or STOP RESEARCH). The letters a kind gets are also the same whether
## it is first seen with no research or with all of it.
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
		var tech0: Dictionary = (g.players[0]["tech"] as Dictionary).duplicate()
		await _sweep(g, f)
		g.players[0]["tech"] = tech0.duplicate()
		await _stable(g, f, tech0)
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
	Settings.load_all()       # (main loads the shared settings file at start: read it first, or its device wins over ours)
	Settings.device = "pc"


# ------------------------------------------------------------------ stable keys

## label -> [letter, stable id] of the card shown now.
func _rec(g: Game) -> Dictionary:
	g.hud._refresh_card()
	var out := {}
	var ids: Array = g.hud._ids_of(g.hud._card_items)
	for i in g.hud._card_items.size():
		var it: Array = g.hud._card_items[i]
		out[String(it[1]).trim_prefix("> ").trim_prefix("~ ")] = [String(it[6]) if it.size() > 6 else "", String(ids[i])]
	return out


## No command on both cards changed its letter, and no letter went to a different command.
func _same(a: Dictionary, b: Dictionary, what: String) -> void:
	cards += 1
	var bad := PackedStringArray()
	for lab in b:
		var k: String = b[lab][0]
		if a.has(lab) and a[lab][0] != k:
			bad.append("%s %s -> %s" % [lab, a[lab][0], k])
		for lab0 in a:
			if lab0 != lab and k != "" and a[lab0][0] == k and a[lab0][1] != b[lab][1] and not b.has(lab0):
				bad.append("%s took %s's %s" % [lab, lab0, k])
	var line := PackedStringArray()
	for lab in b:
		line.append("%s=%s" % [lab, b[lab][0]])
	print("KEYS-STABLE | %s | %s" % [what, " ".join(line)])
	check(bad.is_empty(), "%s: the letters stay put%s" % [what, "" if bad.is_empty() else " (" + "; ".join(bad) + ")"])


func _key_of(r: Dictionary, lab: String) -> int:
	return OS.find_keycode_from_string(String(r[lab][0])) if r.has(lab) and String(r[lab][0]) != "" else 0


## The kind's letters first seen with no research and first seen with all of it: the same.
func _first_sight(g: Game, sel: Array, what: String, tech0: Dictionary) -> void:
	g.hud._key_memo = {}
	g.players[0]["tech"] = tech0.duplicate()
	g.set_selection(sel)
	var a := _rec(g)
	g.hud._key_memo = {}
	for rk in Defs.RESEARCH:
		g.players[0]["tech"][rk] = true
	var b := _rec(g)
	g.players[0]["tech"] = tech0.duplicate()
	g.hud._key_memo = {}
	_same(a, b, what + " first seen with all research")


func _stable(g: Game, f: String, tech0: Dictionary) -> void:
	var hud = g.hud
	var c := Vector2i(g.W / 2, g.H / 2)
	var at: Vector2 = g.cell_center(g.nearest_free(c, 10))
	if f != "brood":
		for k in Defs.build_list(f):
			if not Defs.BUILDINGS.has(k) or not hud._has_research_at(k) and (Defs.BUILDINGS[k].get("trains", []) as Array).is_empty():
				continue
			var cell := g.nearest_free(c + Vector2i(8, -6), 30)
			var b: Building = g._add_building(k, 0, cell, true)
			await physics_frame
			if b == null:
				continue
			await _first_sight(g, [b], "%s %s" % [f, k], tech0)
			g.set_selection([b])
			var r0 := _rec(g)
			var keys: Array = []
			for rk in Defs.RESEARCH:
				if String(Defs.RESEARCH[rk]["at"]) == k:
					keys.append(rk)
			if keys.is_empty():
				# a training building: the armoured soldiers come with ARMOUR
				g.players[0]["tech"]["armour"] = true
				_same(r0, _rec(g), "%s %s with ARMOUR researched" % [f, k])
				g.train(b, String((b.d["trains"] as Array)[0]))
				_same(r0, _rec(g), "%s %s training (CANCEL shown)" % [f, k])
				g.players[0]["tech"] = tech0.duplicate()
				b.take_damage(999999.0, null)
				await physics_frame
				continue
			# a research by its key, twice: queued once, then the next of its chain or nothing; never another command
			var lab0 := Defs.research_label(keys[0])
			var q0 := b.queue.size()
			hud.hotkey(_key_of(r0, lab0))
			var started := b.queue.has("@" + String(keys[0])) or g.has_tech(0, keys[0])
			if not started:
				b.add_entry("@" + String(keys[0]))          # (a Clockwork building not meshed: queued by hand)
			_same(r0, _rec(g), "%s %s researching %s" % [f, k, lab0])
			var qn := b.queue.size()
			hud.hotkey(_key_of(r0, lab0))
			check(b.queue.size() >= qn and b.queue.has("@" + String(keys[0])) and g.controls.mode == "",
				"%s %s: %s's key again queues the next or does nothing (queue %d -> %d -> %d)" % [f, k, lab0, q0, qn, b.queue.size()])
			for rk in keys.slice(1):
				if b.queue.size() >= 5:
					break
				if not b.queue.has("@" + String(rk)):
					b.add_entry("@" + String(rk))
				_same(r0, _rec(g), "%s %s with %s queued too" % [f, k, Defs.research_label(rk)])
			for rk in keys:
				g.players[0]["tech"][rk] = true
			b.queue.clear()
			_same(r0, _rec(g), "%s %s with all its research done" % [f, k])
			g.players[0]["tech"] = tech0.duplicate()
			b.take_damage(999999.0, null)
			await physics_frame
		if f == "crown":
			# Musketeers: their REFITs come with the Armoury's research
			var ms: Array = []
			for i in 3:
				ms.append(g._add_unit("musketeer", 0, at + Vector2(i * 20, 0)))
			await physics_frame
			g.set_selection(ms)
			var r1 := _rec(g)
			for rk in ["armour", "matchlock", "bayonet", "pouch"]:
				g.players[0]["tech"][rk] = true
			_same(r1, _rec(g), "crown musketeers with their refits researched")
			g.players[0]["tech"] = tech0.duplicate()
			for u in ms:
				g.consume_unit(u)
			await physics_frame
		return
	# ---- the Brood: the Mother and every Sire, rooted, researching (a queue), uprooted and rooted again
	var q: Unit = BroodNew.queen(g, 0)
	q.tesla_mode = "deployed"
	q.nb["stage"] = 2
	BroodNew.apply_stage(q)
	var who: Array = [q]
	for k in ["tyrannosaur", "dilophosaurus", "pterodactyl"]:
		if not Defs.UNITS.has(k):
			continue
		var u: Unit = g._add_unit(k, 0, q.position + Vector2(randf_range(-120, 120), randf_range(60, 140)))
		await physics_frame
		u.tesla_mode = "deployed"
		who.append(u)
	for u in who:
		var nm := String(u.kind)
		await _first_sight(g, [u], "brood %s" % nm, tech0)
		g.set_selection([u])
		var r0 := _rec(g)
		var keys := BroodResearch.keys_at(u.kind)
		if keys.is_empty():
			continue
		var lab0 := Defs.research_label(keys[0])
		check(r0.has(lab0) and r0[lab0][0] != "", "brood %s: %s has a key (%s)" % [nm, lab0, r0.get(lab0, ["?"])[0]])
		hud.hotkey(_key_of(r0, lab0))
		check(BroodResearch.current(u) == keys[0], "brood %s: its key started %s" % [nm, lab0])
		_same(r0, _rec(g), "brood %s researching %s" % [nm, lab0])
		hud.hotkey(_key_of(r0, lab0))
		check(BroodResearch.current(u) == keys[0], "brood %s: %s's key again did not stop it (STOP RESEARCH has %s)" % [nm, lab0, _rec(g).get("STOP RESEARCH", ["none"])[0]])
		hud.hotkey(_key_of(r0, lab0), true)
		check(BroodResearch.current(u) == keys[0], "brood %s: %s's key held down did not stop it either" % [nm, lab0])
		for rk in keys.slice(1):
			if Defs.research_label(rk) in r0:
				hud.hotkey(_key_of(r0, Defs.research_label(rk)))
			_same(r0, _rec(g), "brood %s with %s queued" % [nm, Defs.research_label(rk)])
		var line_n := BroodResearch.line_of(u).size()
		check(line_n == keys.size(), "brood %s: its keys queued all %d of its research (%d)" % [nm, keys.size(), line_n])
		u.tesla_mode = "packed"
		_same(r0, _rec(g), "brood %s uprooted" % nm)
		u.tesla_mode = "deployed"
		_same(r0, _rec(g), "brood %s rooted again" % nm)
		var r2 := _rec(g)
		if r2.has("STOP RESEARCH"):
			hud.hotkey(_key_of(r2, "STOP RESEARCH"))
		_same(r0, _rec(g), "brood %s after STOP RESEARCH" % nm)
		while BroodResearch.busy(u):
			u.cmd_nb_research_stop()
		for rk in keys:
			g.players[0]["tech"][rk] = true
		_same(r0, _rec(g), "brood %s with all its research done" % nm)
		g.players[0]["tech"] = tech0.duplicate()
	# the Mother and a Sire together
	if who.size() > 1:
		g.set_selection([who[0], who[1]])
		var rm := _rec(g)
		who[1].cmd_nb_research(BroodResearch.keys_at(who[1].kind)[0])
		_same(rm, _rec(g), "brood the Mother and a Sire, the Sire researching")
		who[0].tesla_mode = "packed"
		_same(rm, _rec(g), "brood the Mother uprooted and a Sire")
		who[0].tesla_mode = "deployed"
		while BroodResearch.busy(who[1]):
			who[1].cmd_nb_research_stop()
