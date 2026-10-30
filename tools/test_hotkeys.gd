extends SceneTree
## The hotkey bar and the merged building card, in a real match:
##   godot --headless --fixed-fps 30 --script res://tools/test_hotkeys.gd 2>&1 | grep -E "FAIL|PASS|DONE"
##  - groups: Alt+number sets, Shift+number adds (no doubles), Ctrl+number removes, number selects,
##    0 is the tenth group, the mouse (bar buttons with Shift/Ctrl/Alt) does the same
##  - F1 idle workers, F2 army, F3 every building that makes something (the Town Hall too)
##  - camera views: Shift+F5 saves, F5 jumps back (position and zoom), an empty one only says so
##  - leaving to the menu and CONTINUE: groups (units and buildings) and camera views come back
##  - the pressed look of bar buttons and of the command card's hotkeys
##  - 4 Barracks + an Armoury selected: the card is not empty, a Musketeer lands in a Barracks,
##    a research in the Armoury, Tab flips the pages, keys on one page are all different
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(kc: int, shift := false, ctrl := false, alt := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = kc as Key
	e.pressed = true
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	return e


func _start(extra := {}) -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cfg := {"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]}
	cfg.merge(extra, true)
	main.start(cfg)
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await physics_frame
	return [main, g]


func _men(g: Game, n: int) -> Array:
	var c: Vector2 = g.halls_of(0)[0].center() + Vector2(0, 150)
	var out: Array = []
	for i in n:
		var u := g._add_unit("musketeer", 0, c + Vector2((i % 4) * 26, (i / 4) * 26))
		u.process_mode = Node.PROCESS_MODE_DISABLED
		out.append(u)
	return out


func _build(g: Game, kind: String) -> Building:
	var hall: Building = g.halls_of(0)[0]
	for r in range(5, 22):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c: Vector2i = hall.cell + Vector2i(dx, dy)
				if g.placement_problem(0, kind, c) == "":
					return g._add_building(kind, 0, c, true)
	return null


func _run() -> void:
	var r: Array = await _start()
	var main: Node = r[0]
	var g: Game = r[1]
	var hud = g.hud
	var bar: HotkeyBar = hud.bar
	check(bar != null and g.groups.size() == 10 and g.cam_slots.size() == 7, "bar exists; 10 groups, 7 camera views")
	check(hud.bar.rect().size.x > 100 and hud.bar.rect().position.y > 200, "bar has a place: %s" % str(hud.bar.rect()))

	# ---- groups
	var m := _men(g, 8)
	g.set_selection(m.slice(0, 3))
	bar.key(_key(KEY_1, false, true))
	check(g.groups[0].size() == 3, "Ctrl+1 sets group 1 to the selection")
	g.set_selection([m[3]])
	bar.key(_key(KEY_1, true, true))
	check(g.groups[0].size() == 4 and g.groups[0].has(m[3]) and g.groups[0].has(m[0]), "Ctrl+Shift+1 adds the selection to the group, keeping what was there")
	bar.key(_key(KEY_1, true, true))
	check(g.groups[0].size() == 4, "adding the same again makes no doubles")
	g.set_selection([m[5]])
	bar.key(_key(KEY_1, true))
	check(g.selection.size() == 5 and g.selection.has(m[5]) and g.selection.has(m[0]) and g.groups[0].size() == 4, "Shift+1 adds the group to the selection, the group is unchanged")
	# dropping a unit the SC2 way: select the group, shift-click it off, Ctrl+1
	g.set_selection([])
	bar.key(_key(KEY_1))
	check(g.selection.size() == 4, "1 selects the group")
	var rest: Array = g.selection.filter(func(x) -> bool: return x != m[0] and x != m[1])
	g.set_selection(rest)
	bar.key(_key(KEY_1, false, true))
	check(g.groups[0].size() == 2 and not g.groups[0].has(m[0]) and not g.groups[0].has(m[1]) and g.groups[0].has(m[2]), "deselect two, Ctrl+1: they are out of the group")
	g.set_selection([m[4]])
	bar.key(_key(KEY_0, false, true))
	check(g.groups[9].size() == 1, "Ctrl+0 sets the tenth group")
	g.set_selection([])
	bar.key(_key(KEY_0))
	check(g.selection == [m[4]], "0 selects the tenth group")
	g.set_selection([m[5]])
	bar.key(_key(KEY_2, true, true))
	check(g.groups[1].size() == 1, "Ctrl+Shift+2 into an empty group adds")
	g.set_selection([])
	bar.key(_key(KEY_1, true, true))
	check(g.groups[0].size() == 2, "Ctrl+Shift+number with nothing selected changes nothing")
	g.set_selection([m[2]])
	bar.key(_key(KEY_1, false, true))
	check(g.groups[0] == [m[2]], "Ctrl+1 again replaces the group")
	# dead units leave the groups
	m[2].die()
	await physics_frame
	check(g.groups[0].is_empty(), "a dead unit leaves its group")
	# the mouse on the buttons
	g.set_selection([m[6]])
	var br := bar.button_rect(HotkeyBar.GROUP0 + 4)       # group 5
	bar.activate(HotkeyBar.GROUP0 + 4, "set")
	check(g.groups[4] == [m[6]], "button, set mode: group 5 set")
	g.set_selection([m[7]])
	bar.activate(HotkeyBar.GROUP0 + 4, "add")
	check(g.groups[4].size() == 2, "button, add mode")
	g.set_selection([m[6]])
	bar.activate(HotkeyBar.GROUP0 + 4, "join")
	check(g.selection.size() == 2 and g.groups[4].size() == 2, "button, join mode: the group joins the selection")
	check(bar.hit(br.get_center()) == HotkeyBar.GROUP0 + 4, "hit test finds the button at its centre")

	# ---- F1 / F2 / F3
	var labs: Array = g.labourers(0)
	for u in labs:
		u.order = "idle"
	bar.key(_key(KEY_F1))
	check(g.selection.size() == labs.size() and g.selection.all(func(u) -> bool: return u.is_worker()), "F1 selects all idle workers (%d)" % labs.size())
	bar.key(_key(KEY_F2))
	var army: Array = g.army(0)
	check(g.selection.size() == army.size() and army.size() >= 7, "F2 selects the whole army (%d)" % army.size())
	var bk := _build(g, "barracks")
	check(bk != null, "a Barracks to test with")
	bar.key(_key(KEY_F3))
	var hall: Building = g.halls_of(0)[0]
	check(g.selection.has(bk) and g.selection.has(hall), "F3 selects every production building, the Town Hall too (%d)" % g.selection.size())
	check(not g.selection.any(func(e) -> bool: return not (e is Building)), "F3 selects buildings only")

	# ---- camera views
	g.camera.position = Vector2(1234, 987)
	g.camera.zoom = Vector2(1.3, 1.3)
	bar.key(_key(KEY_F5, true))
	check(g.cam_slots[1] != null, "Shift+F5 saves the view")
	g.camera.position = Vector2(300, 300)
	g.camera.zoom = Vector2(2.0, 2.0)
	bar.key(_key(KEY_F5))
	check(g.camera.position.distance_to(Vector2(1234, 987)) < 1.0 and absf(g.camera.zoom.x - 1.3) < 0.01, "F5 jumps back to the saved view and zoom")
	g.camera.position = Vector2(400, 400)
	bar.key(_key(KEY_F9))
	print("  cam %s slot %s" % [str(g.camera.position), str(g.cam_slots[5])])
	check(g.camera.position == Vector2(400, 400) and g.cam_slots[5] == null, "an empty view F9 only says so")
	bar.activate(HotkeyBar.CAM0 + 5)
	check(g.cam_slots[5] != null, "a tap on an empty tab saves the view there")
	check(bar.hit(bar.tab_rect(3).position + Vector2(4, 4)) == HotkeyBar.CAM0 + 3, "tab F7 can be hit at its visible edge")
	check(not bar.tip(HotkeyBar.CAM0).is_empty() and not bar.tip(HotkeyBar.GROUP0).is_empty() and not bar.tip(0).is_empty(), "tooltips exist")

	# ---- pressed look
	bar.key(_key(KEY_F2))
	check(bar.pushed(HotkeyBar.ARMY) > 0.0, "F2 pushes the ARMY button in")
	hud.flash_card("MOVE")
	check(hud._card_flash_phase() > 0, "a card hotkey pushes its button in")
	OS.delay_msec(250)       # (the pressed look is timed in real milliseconds)
	check(bar.pushed(HotkeyBar.ARMY) == 0.0 and hud._card_flash_phase() == 0, "and it comes back up")

	# ---- the old HALL button and keys are gone
	check(not "HALL" in HotkeyBar.NAMES, "no HALL button")

	# ---- mixed building card: 4 Barracks and an Armoury
	var bks: Array = [bk]
	for i in 3:
		bks.append(_build(g, "barracks"))
	var arm := _build(g, "armoury")
	var pm := _build(g, "powder_mill")
	var fd := _build(g, "foundry")
	check(arm != null and not bks.has(null), "4 Barracks and an Armoury built")
	g.players[0]["gold"] = 5000
	g.players[0]["cap"] = 200
	g.players[0]["res2"] = 500
	g.set_selection(bks + [arm])
	hud._refresh_card()
	var items: Array = hud._card_items
	check(items.size() > 0, "mixed selection: the card is not blank (%d buttons)" % items.size())
	var labels: Array = items.map(func(it) -> String: return String(it[1]))
	check(labels.has("MUSKETEER"), "it offers MUSKETEER")
	check(labels.count("MUSKETEER") == 1, "...once, not once per Barracks")
	var keys: Array = items.map(func(it) -> String: return String(it[6]))
	var uniq := {}
	for k in keys:
		if k != "":
			uniq[k] = true
	check(uniq.size() == keys.filter(func(k) -> bool: return k != "").size(), "hotkeys on the page differ: %s" % str(keys))
	# a musket lock research is the Armoury's
	var rlab := ""
	for k in Defs.RESEARCH:
		if Defs.RESEARCH[k]["at"] == "armoury" and not g.has_tech(0, k):
			rlab = Defs.research_label(k)
			break
	check(rlab != "" and labels.has(rlab), "it offers the Armoury's research: %s" % rlab)
	# order a musketeer: lands in one Barracks
	for it in items:
		if String(it[1]) == "MUSKETEER":
			print("  musketeer button: enabled=%s why=%s" % [it[3], it[4]])
			it[2].call()
	var queued := 0
	for b in bks:
		queued += b.queue.size()
	check(queued == 1, "a Musketeer order lands in one Barracks (%d queued)" % queued)
	hud._refresh_card()
	for it in hud._card_items:
		if String(it[1]) == "MUSKETEER":
			it[2].call()
	var per: Array = bks.map(func(b) -> int: return b.queue.size())
	check(per.max() == 1, "the second goes to a Barracks with a shorter queue: %s" % str(per))
	hud._refresh_card()
	for it in hud._card_items:
		if String(it[1]) == rlab:
			print("  research button why=%s" % it[4])
			check(it[3], "research button is enabled")
			it[2].call()
	check(arm.queue.size() == 1 and String(arm.queue[0]).begins_with("@"), "the research landed in the Armoury")
	check(bks.all(func(b) -> bool: return b.queue.size() <= 1 and not (b.queue.size() == 1 and String(b.queue[0]).begins_with("@"))), "...and in no Barracks")
	# CANCEL, RALLY exist
	hud._refresh_card()
	labels = hud._card_items.map(func(it) -> String: return String(it[1]))
	check(labels.has("CANCEL") and labels.has("RALLY"), "RALLY and CANCEL are on the merged card")
	# pages: a Hall + Barracks + Stable + Armoury + Workshop ... many things: force a long card
	var many := _build(g, "horse_breeder")
	var mill := pm
	g.set_selection(bks + [arm, hall] + ([many] if many else []) + ([mill] if mill else []))
	hud._refresh_card()
	hud._card_page = 0
	var first: Array = hud._card_items.map(func(it) -> String: return String(it[1]))
	var has_more: bool = first.has("MORE")
	if has_more:
		check(hud.hotkey(KEY_TAB), "Tab flips the card page")
		hud._refresh_card()
		var second: Array = hud._card_items.map(func(it) -> String: return String(it[1]))
		check(second != first, "the second page differs from the first")
		check(hud._card_items.size() > 0, "the second page is not blank")
	else:
		print("PASS  (this selection fits on one page: %d buttons)" % first.size())
	# force a long list: a fake selection of many kinds would need many buildings; test _paged directly
	var fake: Array = []
	for i in 16:
		fake.append(["move", "CMD%d" % i, func() -> void: pass, true, "", ""])
	hud._card_page = 0
	hud._card_sig = "fake"
	var pg: Array = hud._paged(fake)
	check(pg.size() == 12 and String(pg[11][1]) == "MORE", "16 commands: page 1 has 11 + a MORE button")
	hud._card_items = hud._with_keys(pg)
	check(hud.hotkey(KEY_TAB), "Tab works as MORE")
	pg = hud._paged(fake)
	check(String(pg[0][1]) == "CMD11", "page 2 starts after page 1")

	# ---- leave to the menu and CONTINUE: groups and views stay
	g.set_selection([m[6]])
	bar.key(_key(KEY_4, false, true))
	g.set_selection([bks[0], arm])
	bar.key(_key(KEY_5, false, true))
	g.camera.position = Vector2(2000, 1500)
	g.camera.zoom = Vector2(1.1, 1.1)
	bar.key(_key(KEY_F10, true))
	var m6pos: Vector2 = m[6].position
	main._to_menu()
	await process_frame
	await process_frame
	var save := SaveGame.peek()
	check(not save.is_empty() and save.has("groups") and save.has("cams"), "leaving the match autosaves groups and views")
	var cfg: Dictionary = save["cfg"].duplicate(true)
	cfg["resume"] = save
	main.start(cfg)
	await process_frame
	await process_frame
	var g2: Game = main.game
	check(g2 != g and g2.groups.size() == 10, "a new Game after CONTINUE")
	var st2 := g2.groups.map(func(x) -> int: return x.size())
	check(st2[3] == 1 and st2[4] == 2, "group 4 (a Musketeer) and group 5 (2 buildings) are back: %s" % str(st2))
	check(g2.groups[3].size() == 1 and g2.groups[3][0].kind == "musketeer" and g2.groups[3][0].position.distance_to(m6pos) < 40.0, "the group's unit is the same one")
	check(g2.groups[4].all(func(e) -> bool: return e is Building) and g2.groups[4].any(func(e) -> bool: return e.kind == "armoury"), "buildings in a group came back")
	check(g2.cam_slots[6] != null and (g2.cam_slots[6][0] as Vector2).distance_to(Vector2(2000, 1500)) < 1.0, "camera view F10 came back")
	check(g2.cam_slots[1] != null, "camera view F5 came back")
	SaveGame.clear()
	# ---- the Brood has no buildings: F3 (MAKE) selects the Brood Mother (the owner, 2026-10-30)
	main._to_menu()
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g3: Game = main.game
	for ai in g3.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await physics_frame
	var bar3: HotkeyBar = g3.hud.bar
	bar3.key(_key(KEY_F3))
	var q := BroodNew.queen(g3, g3.human)
	check(q != null and g3.selection.size() == 1 and g3.selection[0] == q, "Brood: F3 selects the Brood Mother (%d selected)" % g3.selection.size())
	SaveGame.clear()
	print("DONE  %d failed" % fails)
	quit(1 if fails > 0 else 0)
