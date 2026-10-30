extends SceneTree
## The multi-selection panel (scripts/ui/hud.gd, _draw_sel_icons / sel_icon_click), in a real match:
##   godot --headless --fixed-fps 30 --script res://tools/test_selection_panel.gd 2>&1 | grep -E "FAIL|PASS|DONE"
##  - 60 units of 4 kinds: 4 type icons first, each with its count, then 60 unit icons grouped by kind
##  - every unit icon is reached by scrolling (wheel rows), the scroll stops at the ends, a new selection starts at the top
##  - clicks: a unit = only him; Ctrl = his kind; Shift = drop him; Ctrl+Shift = drop his kind;
##    a type icon = that kind, Shift = drop that kind; a real press and release on an icon (the PC click); a drag scrolls
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits real time (the panel's tap and long press count real milliseconds; --fixed-fps runs faster).
func _ms(n: int) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < n:
		await process_frame


func _run() -> void:
	Settings.device = "pc"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	var hud = g.hud
	hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	var c: Vector2 = g.halls_of(0)[0].center() + Vector2(0, 200)
	var kinds := {"musketeer": 25, "cuirassier": 15, "cannon": 8, "labourer": 12}
	var men: Array = []
	var i := 0
	for k in kinds:
		for n in int(kinds[k]):
			var u: Unit = g._add_unit(k, 0, c + Vector2((i % 10) * 24, (i / 10) * 24))
			u.process_mode = Node.PROCESS_MODE_DISABLED
			men.append(u)
			i += 1
	# mixed order in the selection, as a box would give
	var mixed: Array = men.duplicate()
	mixed.shuffle()
	g.set_selection(mixed)
	await _frames(4)
	hud.queue_redraw()
	await _frames(4)
	var items: Array = hud._sel_items
	check(items.size() == 64, "64 icons: 4 type icons + 60 units (%d)" % items.size())
	var types_ok := true
	for t in 4:
		var it: Dictionary = items[t]
		types_ok = types_ok and it.has("type") and int(it["n"]) == int(kinds[it["type"]])
	check(types_ok, "the first 4 icons are the kinds with their counts: %s" % str(items.slice(0, 4).map(func(x): return "%s %d" % [x["type"], x["n"]])))
	var grouped := true
	for t in range(5, 64):
		if items[t]["e"].kind != items[t - 1]["e"].kind:
			# a new kind starts: it must not have been seen before
			for t2 in range(4, t - 1):
				if items[t2]["e"].kind == items[t]["e"].kind:
					grouped = false
	check(grouped and not items[4].has("type"), "then the units, grouped by kind")
	check(hud._sel_rows > 2 and hud._sel_bar.size.x > 0.0, "too many to fit: a scroll bar (%d rows of %d)" % [hud._sel_rows, hud._sel_cols])
	# scrolling reaches everyone
	var seen := {}
	for s in hud._sel_rows + 3:
		for pt in hud._portraits:
			if not pt["it"].has("type"):
				seen[pt["e"]] = true
		hud.sel_scroll_by(1)
		hud.queue_redraw()
		await _frames(2)
	check(seen.size() == 60, "every unit icon is reached by scrolling (%d of 60)" % seen.size())
	check(hud._sel_scroll == hud._sel_rows - 2, "the scroll stops at the end")
	# the wheel
	var wh := InputEventMouseButton.new()
	wh.button_index = MOUSE_BUTTON_WHEEL_UP
	wh.pressed = true
	wh.position = hud._sel_area.get_center()
	var before: int = hud._sel_scroll
	hud._on_input(wh)
	check(hud._sel_scroll == before - 1, "the mouse wheel over the icons scrolls a row")
	# a drag scrolls and selects nothing
	hud.queue_redraw()
	await _frames(2)
	before = hud._sel_scroll
	var p0: Vector2 = hud._portraits[0]["rect"].get_center()
	hud._press(p0)
	hud._sel_move(p0 + Vector2(0, 45))
	hud._release(p0 + Vector2(0, 45))
	check(hud._sel_scroll == before - 1 and g.selection.size() == 60, "a drag down on the icons scrolls up a row and keeps the selection")
	hud.sel_scroll_by(-100)
	hud.queue_redraw()
	await _frames(2)
	check(hud._sel_scroll == 0, "the scroll stops at the top")

	var musk: Array = men.filter(func(u): return u.kind == "musketeer")
	var cui: Array = men.filter(func(u): return u.kind == "cuirassier")
	var one: Unit = musk[3]
	# a plain click on a unit icon, by a real press and release
	var at := Rect2()
	for pt in hud._portraits:
		if not pt["it"].has("type"):
			at = pt["rect"]
			break
	var who: Entity = hud._sel_hit(at.get_center())["e"]
	hud._press(at.get_center())
	hud._release(at.get_center())
	check(g.selection.size() == 1 and g.selection[0] == who, "click on a unit icon: only he is selected")
	# the rules, from the full selection
	g.set_selection(mixed)
	hud.sel_icon_click({"e": one}, true, false)
	check(g.selection.size() == 25 and g.selection.all(func(x): return x.kind == "musketeer"), "Ctrl+click on a unit: all of his kind in the selection")
	g.set_selection(mixed)
	hud.sel_icon_click({"e": one}, false, true)
	check(g.selection.size() == 59 and not g.selection.has(one), "Shift+click on a unit: he alone is dropped")
	g.set_selection(mixed)
	hud.sel_icon_click({"e": one}, true, true)
	check(g.selection.size() == 35 and g.selection.all(func(x): return x.kind != "musketeer"), "Ctrl+Shift+click on a unit: his kind is dropped")
	g.set_selection(mixed)
	hud.sel_icon_click({"type": "cuirassier", "e": cui[0], "n": 15}, false, false)
	check(g.selection.size() == 15 and g.selection.all(func(x): return x.kind == "cuirassier"), "click on a type icon: that kind")
	g.set_selection(mixed)
	hud.sel_icon_click({"type": "cuirassier", "e": cui[0], "n": 15}, false, true)
	check(g.selection.size() == 45 and g.selection.all(func(x): return x.kind != "cuirassier"), "Shift+click on a type icon: that kind dropped")
	# a type icon clicked for real
	g.set_selection(mixed)
	hud.queue_redraw()
	await _frames(3)
	var tr: Rect2 = hud._portraits[1]["rect"]
	var tk: String = hud._portraits[1]["it"]["type"]
	hud._press(tr.get_center())
	hud._release(tr.get_center())
	check(g.selection.size() == int(kinds[tk]) and g.selection.all(func(x): return x.kind == tk), "a press on the 2nd type icon selects its kind (%s)" % tk)
	# phones: a tap waits for a second one, then keeps only him; a double tap = his kind; a long press drops him
	Settings.device = "phone"
	g.set_selection(mixed)
	hud.queue_redraw()
	await _frames(3)
	var up: Dictionary = hud._portraits[6]
	var upc: Vector2 = (up["rect"] as Rect2).get_center()
	hud._press(upc)
	hud._release(upc)
	check(g.selection.size() == 60, "phone: a tap waits a moment for a second one")
	await _ms(400)
	await _frames(2)
	check(g.selection == [up["e"]], "phone: a lone tap keeps only him")
	g.set_selection(mixed)
	hud.queue_redraw()
	await _frames(3)
	up = hud._portraits[6]
	upc = (up["rect"] as Rect2).get_center()
	hud._press(upc)
	hud._release(upc)
	hud._press(upc)
	hud._release(upc)
	var uk: String = up["e"].kind
	check(g.selection.size() == int(kinds[uk]) and g.selection.all(func(x): return x.kind == uk), "phone: a double tap = his kind (%s, %d)" % [uk, g.selection.size()])
	g.set_selection(mixed)
	hud.queue_redraw()
	await _frames(3)
	up = hud._portraits[6]
	upc = (up["rect"] as Rect2).get_center()
	hud._press(upc)
	await _ms(600)
	await _frames(2)
	hud._release(upc)
	await _ms(400)
	await _frames(2)
	check(g.selection.size() == 59 and not g.selection.has(up["e"]), "phone: a long press drops him")
	Settings.device = "pc"
	# a new selection starts at the top
	g.set_selection(mixed)
	hud.queue_redraw()
	await _frames(2)
	hud.sel_scroll_by(3)
	g.set_selection(mixed.slice(0, 40))
	hud.queue_redraw()
	await _frames(2)
	check(hud._sel_scroll == 0, "a new selection starts at the top")
	# a small selection fits: no bar
	g.set_selection(musk.slice(0, 5))
	hud.queue_redraw()
	await _frames(2)
	check(hud._sel_bar.size.x == 0.0 and hud._sel_items.size() == 6, "5 Musketeers: 1 type icon + 5, no scroll bar")
	# the same rules on the map (Controls.map_click): every unit is on screen
	var ctl: Controls = hud.controls
	g.camera.position = c + Vector2(110, 40)
	g.camera.zoom = Vector2(0.6, 0.6)
	await _frames(2)
	g.set_selection(mixed)
	ctl.map_click(one, false, false)
	check(g.selection == [one], "map: a click selects only that unit")
	ctl.map_click(one, true, false)
	check(g.selection.size() == 25 and g.selection.all(func(x): return x.kind == "musketeer"), "map: Ctrl+click = all of its kind on screen (%d)" % g.selection.size())
	ctl.map_click(cui[0], false, true)
	check(g.selection.size() == 26 and g.selection.has(cui[0]), "map: Shift+click adds one not selected")
	ctl.map_click(one, false, true)
	check(g.selection.size() == 25 and not g.selection.has(one), "map: Shift+click drops one selected")
	ctl.map_click(one, true, true)
	check(g.selection == [cui[0]], "map: Ctrl+Shift+click drops its kind")
	ctl.map_click(one, true, true)
	check(g.selection.size() == 26 and g.selection.has(cui[0]), "map: Ctrl+Shift+click with none of its kind selected adds its kind on screen")
	# a click on a worker label (HAULERS over the Town Hall) selects its workers; Shift adds them
	var hall: Building = g.halls_of(0)[0]
	var hl: Array = []
	for k in 3:
		var w: Unit = g._add_unit("labourer", 0, hall.center() + Vector2(-60 + k * 20, 90))
		w.process_mode = Node.PROCESS_MODE_DISABLED
		w.home_mine = hall
		hall.crew.append(w)
		hl.append(w)
	g.camera.position = hall.center()
	g.camera.zoom = Vector2(1, 1)
	await _frames(3)
	var L := WorkerLabels.layout(g, hall)
	check(not L.is_empty() and WorkerLabels.at(g, (L["rect"] as Rect2).get_center()) == hall, "the hall has a HAULERS label (%s)" % str(L.get("count", "")))
	var sp: Vector2 = g.get_viewport().get_canvas_transform() * (L["rect"] as Rect2).get_center()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = sp
	ev.pressed = true
	g.set_selection([one])
	ctl._left_pc(ev)
	var ev2: InputEventMouseButton = ev.duplicate()
	ev2.pressed = false
	ctl._left_pc(ev2)
	check(g.selection.size() == 3 and hl.all(func(x): return g.selection.has(x)), "a click on the HAULERS label selects the hall's 3 haulers, not the hall (%d)" % g.selection.size())
	g.set_selection([one])
	ev.shift_pressed = true
	ev2.shift_pressed = true
	ctl._left_pc(ev)
	ctl._left_pc(ev2)
	check(g.selection.size() == 4 and g.selection.has(one), "Shift+click on the label adds them")
	# the card's worker chip
	g.set_selection([hall])
	var ch: Array = CardTips.chips(g, hall).filter(func(x): return x.has("crew_of"))
	check(ch.size() == 1 and ch[0]["crew_of"] == hall, "the hall's card has a worker chip that knows its hall")
	WorkerLabels.select_workers(g, ch[0]["crew_of"])
	check(g.selection.size() == 3, "the chip's action selects the haulers")
	# the screenshot (with a display): a mixed army, scrolled a little
	if DisplayServer.get_name() != "headless":
		g.set_selection(mixed)
		g.camera.position = c + Vector2(110, 40)
		hud.queue_redraw()
		await _frames(10)
		var img := root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/shots/selection_panel"))
		img.save_png(ProjectSettings.globalize_path("res://docs/shots/selection_panel/mixed_60.png"))
		print("shot saved")
	print("DONE  fails=%d" % fails)
	quit(1 if fails > 0 else 0)
