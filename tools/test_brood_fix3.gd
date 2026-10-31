extends SceneTree
## THE OWNER'S BROOD PLAYTEST OF 2026-10-31 (brood-fix3):
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_fix3.gd
##  1. a selected egg that hatches: its young (2 of a clutch) take its place in the selection and its control group;
##     a selected grub that morphs: its cocoon does
##  2. an UPROOTING creature, through the real input (Controls mouse events, the card's buttons): a right-click, a
##     Shift+right-click and a Shift-placed ROOT are all kept and carried out once it is up; the card's MOVE too
##  3. a Rootmaw whose swamp is gone (its Mound Turtle uprooted) uproots by itself (an alert), keeping its food; one on
##     the Mother's swamp stays
##  4. the swamp grows 1 tile a second from a newly rooted Mound Turtle and recedes as fast when it gets up; a Rootmaw
##     can't root where it hasn't reached yet; saves keep the swamp and the radius
##  5. a grub with HARVEST on, PATROLLING (and on HOLD): it breaks off for a body, harvests it, delivers it and goes back
##     to its patrol between the same two points (its hold spot)
## Prints PASS / FAIL lines and "brood_fix3: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func mine(k: String) -> Array:
	return g.units.filter(func(u) -> bool: return u.team == 0 and not u.dead and u.kind == k)


func free_spot(k: String, p: Vector2, tiles: float, swamp := false) -> Vector2:
	for r in [tiles, tiles + 1.0, tiles - 1.0, tiles + 2.0, tiles + 3.0, tiles + 4.0, tiles + 6.0]:
		for i in 32:
			var s: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 32.0) * maxf(r, 0.0) * Defs.TILE)
			if g.region_of(g.cell_of(s)) == BroodRoot.home_region(g, p) and BroodRoot.place_problem(g, 0, k, s, null, false, 1.0, swamp) == "":
				return s
	return Vector2.INF


## The swamp's reach round c (px): the farthest swamp cell (tiles, the swamp's own stretched measure) within `upto` tiles.
func reach(c: Vector2, upto: float) -> float:
	var ct: Vector2 = c / Defs.TILE
	var best := 0.0
	for y in range(int(ct.y - upto) - 1, int(ct.y + upto) + 2):
		for x in range(int(ct.x - upto) - 1, int(ct.x + upto) + 2):
			if x < 0 or y < 0 or x >= Game.W or y >= Game.H or g.swamp[0][y * Game.W + x] != 1:
				continue
			var dx: float = x + 0.5 - ct.x
			var dy: float = (y + 0.5 - ct.y) * 1.15
			var d := sqrt(dx * dx + dy * dy)
			if d <= upto:
				best = maxf(best, d)
	return best


func card() -> Array:
	return g.hud._build_card()


func press(label: String) -> bool:
	for it in card():
		if String(it[1]) == label:
			(it[2] as Callable).call()
			return true
	return false


func screen(w: Vector2) -> Vector2:
	return g.get_viewport().get_canvas_transform() * w


func mouse(btn: int, w: Vector2, pressed: bool, shift := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.position = screen(w)
	g.controls._unhandled_input(ev)


func motion(w: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = screen(w)
	g.controls._unhandled_input(ev)


func click(btn: int, w: Vector2, shift := false) -> void:
	motion(w)
	mouse(btn, w, true, shift)
	mouse(btn, w, false, shift)


func open_cocoon(k: String, p: Vector2) -> Unit:
	var u: Unit = BroodRoot.cocoon(g, 0, k, p)
	u.nb["coc"] = 999.0
	await wait_for(func() -> bool: return not u.nb.has("coc"), 2.0)
	return u


func _run() -> void:
	var was_dev := Settings.device
	Settings.device = "pc"
	g.explored.fill(1)
	var p: Dictionary = g.players[0]
	p["gold"] = 9000
	p["res2"] = 9000.0
	var q: Unit = BroodNew.queen(g, 0)
	await wait_for(func() -> bool: return q.tesla_mode == "deployed", 12.0)
	await wait(1.5)
	var full_q: float = BroodNew.swamp_full(q)
	check(reach(q.position, full_q + 1.0) >= full_q - 1.0, "4. the Mother's swamp is there in full at the start (%.1f of %.1f tiles)" % [reach(q.position, full_q + 1.0), full_q])
	await _selection(q)
	await _swamp(q)
	await _uprooting_input(q)
	await _patrol_harvest(q)
	Settings.device = was_dev
	print("brood_fix3: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## 1.
func _selection(q: Unit) -> void:
	var at: Vector2 = g.cell_center(g.nearest_free(g.cell_of(q.position + Vector2(-40, 170)), 6))
	var e: Unit = g._add_unit(BroodNew.EGG, 0, at)
	e.nb["k"] = "raptor"
	e.nb["n"] = 2
	e.nb["t"] = BroodNew.egg_time("raptor") - 0.4
	var other: Unit = g._add_unit("raptor", 0, at + Vector2(60, 0))
	other.cmd_hold()
	var r0 := mine("raptor")
	g.set_selection([e, other])
	g.groups[2] = [e]
	await wait_for(func() -> bool: return mine("raptor").size() >= r0.size() + 2, 3.0)
	var young: Array = mine("raptor").filter(func(x) -> bool: return not r0.has(x))
	check(young.size() == 2, "1. the egg hatched 2 Raptors")
	check(young.all(func(x) -> bool: return g.selection.has(x) and x.selected) and g.selection.has(other) and not g.selection.has(e),
		"   both young are selected in the egg's place, the other unit stays selected (%d selected)" % g.selection.size())
	check(young.all(func(x) -> bool: return g.groups[2].has(x)) and not g.groups[2].has(e), "   and they are in the egg's control group 3")
	# a grub that morphs: its cocoon
	var gr: Unit = g._add_unit("grub", 0, g.cell_center(g.nearest_free(g.cell_of(q.position + Vector2(0, 150)), 6)))
	await physics_frame
	var spot := free_spot(BroodNew.TURTLE, q.position, 8.0)
	g.set_selection([gr])
	g.groups[4] = [gr]
	var n0 := mine(BroodNew.TURTLE).size()
	gr.give({"o": "nb_morph", "k": BroodNew.TURTLE, "p": spot})
	await wait_for(func() -> bool: return mine(BroodNew.TURTLE).size() > n0, 20.0)
	var tt: Array = mine(BroodNew.TURTLE)
	check(tt.size() > n0 and g.selection.has(tt.back()) and g.groups[4].has(tt.back()), "   a selected grub's cocoon takes its place in the selection and group 5")
	for u in young + [other]:
		g.consume_unit(u)
	if tt.size() > n0:
		g.consume_unit(tt.back())
	g.set_selection([])


## 3 and 4.
func _swamp(q: Unit) -> void:
	var full := float(Defs.NB["turtle_swamp"])
	var far := free_spot(BroodNew.TURTLE, q.position, 28.0)
	var tries := 0
	while far != Vector2.INF and g.on_swamp(0, far) and tries < 4:
		tries += 1
		far = free_spot(BroodNew.TURTLE, q.position, 30.0 + tries * 3.0)
	check(far != Vector2.INF and not g.on_swamp(0, far), "4. a Mound Turtle spot off the swamp, %d tiles from the Mother" % int(far.distance_to(q.position) / Defs.TILE))
	if far == Vector2.INF:
		return
	var tu: Unit = await open_cocoon(BroodNew.TURTLE, far)
	check(BroodNew.rooted(tu), "   the Mound Turtle is rooted")
	var t0: float = g.clock
	# a Rootmaw spot 6 tiles out, away from the Mother
	var away: Vector2 = (far - q.position).normalized()
	var maw_at: Vector2 = BroodRoot.snap(BroodNew.MAW, far + away * 6.5 * Defs.TILE)
	if BroodRoot.place_problem(g, 0, BroodNew.MAW, maw_at, null, false, 1.0, false) != "":
		maw_at = free_spot(BroodNew.MAW, far, 6.5)
	await wait(1.2)
	var r1 := reach(far, full + 2.0)
	var why_early: String = BroodRoot.place_problem(g, 0, BroodNew.MAW, maw_at, null, false, 1.0)
	check(r1 <= 2.5, "   1.2 s after rooting its swamp reaches only %.1f tiles (not its %d at once)" % [r1, int(full)])
	check(why_early.begins_with("No swamp"), "   a Rootmaw can't root 6.5 tiles out yet: %s" % why_early)
	await wait(3.0)
	var r4 := reach(far, full + 2.0)
	check(r4 >= 2.5 and r4 <= 6.0, "   4.2 s: %.1f tiles (1 a second)" % r4)
	# saved halfway: the radius and the swamp
	var sv: Dictionary = BroodNew.unit_save(tu)
	var sd: Dictionary = BroodNew.save(g)
	var grid: PackedByteArray = (g.swamp[0] as PackedByteArray).duplicate()
	(g.swamp[0] as PackedByteArray).fill(0)
	BroodNew.load(g, sd)
	check(sv.has("swr") and float(sv["swr"]) > 1.0 and float(sv["swr"]) < full, "   a save keeps the radius it has reached (%.1f)" % float(sv.get("swr", -1.0)))
	check(g.swamp[0] == grid, "   and the swamp as it lies (loaded back the same)")
	await wait_for(func() -> bool: return reach(far, full + 2.0) >= full - 0.6, 12.0)
	check(reach(far, full + 2.0) >= full - 0.6 and g.clock - t0 >= full - 2.5, "   full (%d tiles) after %.1f s" % [int(full), g.clock - t0])
	check(BroodRoot.place_problem(g, 0, BroodNew.MAW, maw_at, null, false, 1.0) == "", "   now the Rootmaw may root there")
	# 3. the Rootmaw on the turtle's swamp
	var m: Unit = await open_cocoon(BroodNew.MAW, maw_at)
	await wait(1.5)
	check(BroodNew.rooted(m) and float(m.nb.get("food", 0.0)) > 0.0, "3. a Rootmaw rooted on the turtle's swamp feeds (%.1f food)" % float(m.nb.get("food", 0.0)))
	var home_maw: Unit = null
	for mm in mine(BroodNew.MAW):
		if mm != m and BroodNew.rooted(mm):
			home_maw = mm
	var lines0: int = g.mlog.lines.size() if g.mlog else 0
	tu.cmd_uproot(true)
	var tu0: float = g.clock
	await wait_for(func() -> bool: return tu.tesla_mode == "packed", 6.0)
	await wait(2.2)
	var rr := reach(far, full + 2.0)
	check(rr < full - 0.9 and rr > full - 5.0, "4. the turtle up: its swamp recedes about 1 tile a second (%.1f tiles, %.1f s after UPROOT)" % [rr, g.clock - tu0])
	var food0 := float(m.nb.get("food", 0.0))
	await wait_for(func() -> bool: return m.tesla_mode != "deployed", 14.0)
	check(m.tesla_mode in ["packing", "packed"], "3. its swamp gone, the Rootmaw uproots by itself (%.1f s after the turtle's UPROOT)" % (g.clock - tu0))
	var told := false
	if g.mlog:
		for i in range(lines0, g.mlog.lines.size()):
			if g.mlog.lines[i].contains("lost its swamp"):
				told = true
	check(told, "   with an alert (the match log has it)")
	check(float(m.nb.get("food", 0.0)) >= food0 - 0.5, "   it keeps its food (%.1f, was %.1f)" % [float(m.nb.get("food", 0.0)), food0])
	var id := int(m.nb.get("spot", -1))
	check(id < 0 or g.nb_spots.has(id), "   its ground keeps what is left")
	await wait(2.0)
	check(home_maw == null or BroodNew.rooted(home_maw), "   the Rootmaw on the Mother's swamp stays rooted")
	await wait_for(func() -> bool: return reach(far, full + 2.0) == 0.0, 14.0)
	check(reach(far, full + 2.0) == 0.0, "4. the turtle's swamp is gone (%.1f s after UPROOT)" % (g.clock - tu0))
	g.consume_unit(m)
	g.consume_unit(tu)


## 2. the real input: a right-click, a Shift+right-click and a Shift-placed ROOT while it uproots
func _uprooting_input(q: Unit) -> void:
	var spot := free_spot(BroodNew.TURTLE, q.position, 14.0)
	var tu: Unit = await open_cocoon(BroodNew.TURTLE, spot)
	var away: Vector2 = (spot - q.position).normalized()
	var side := Vector2(-away.y, away.x)
	var a: Vector2 = g.cell_center(g.nearest_free(g.cell_of(spot + away * 4.0 * Defs.TILE), 4))
	var b: Vector2 = g.cell_center(g.nearest_free(g.cell_of(spot + (away * 4.0 + side * 4.0) * Defs.TILE), 4))
	var c: Vector2 = free_spot(BroodNew.TURTLE, spot + side * 6.0 * Defs.TILE, 1.0)
	check(c != Vector2.INF, "2. spots: a, b and a ROOT spot c")
	g.camera.position = spot
	g.camera.reset_smoothing()
	await process_frame
	await process_frame
	g.set_selection([tu])
	check(press("UPROOT"), "   UPROOT on its card (pressed)")
	await wait_for(func() -> bool: return tu.tesla_mode == "packing", 2.0)
	check(tu.tesla_mode == "packing", "   it is uprooting")
	var labs: Array = card().map(func(it) -> String: return String(it[1]))
	check(labs.has("ROOT") and labs.has("MOVE"), "   its card while uprooting has ROOT and MOVE: %s" % str(labs))
	click(MOUSE_BUTTON_RIGHT, a)
	click(MOUSE_BUTTON_RIGHT, b, true)
	check(press("ROOT") and g.controls.mode == "nb_root", "   ROOT pressed: the ghost is up")
	var cc: Vector2 = BroodRoot.rect_for(BroodNew.TURTLE, c).get_center()       # (the ghost is centred on the pointer)
	motion(cc)
	mouse(MOUSE_BUTTON_LEFT, cc, true, true)
	mouse(MOUSE_BUTTON_LEFT, cc, false, true)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.pressed = false
	g.controls._unhandled_input(ev)
	var qs: Array = tu.queue.map(func(o) -> String: return String(o["o"]))
	check(tu.order == "move" and qs == ["move", "nb_root"], "   right-click: a move; Shift+right-click and Shift+ROOT queued (%s, then %s)" % [tu.order, str(qs)])
	var start: Vector2 = tu.position
	await wait(0.4)
	check(tu.tesla_mode == "packed" or tu.position.distance_to(start) < 2.0, "   it stays put till it is up")
	var got_a := await wait_for(func() -> bool: return tu.position.distance_to(a) < 30.0, 20.0)
	check(got_a, "   up: it walks to a")
	var got_b := await wait_for(func() -> bool: return tu.position.distance_to(b) < 30.0, 20.0)
	check(got_b, "   then to b")
	var rooted := await wait_for(func() -> bool: return BroodNew.rooted(tu), 25.0)
	check(rooted and tu.position.distance_to(BroodRoot.snap(BroodNew.TURTLE, c)) < 4.0, "   then roots at c (%d px off)" % int(tu.position.distance_to(BroodRoot.snap(BroodNew.TURTLE, c))))
	# the card's MOVE while uprooting
	g.set_selection([tu])
	press("UPROOT")
	await wait_for(func() -> bool: return tu.tesla_mode == "packing", 2.0)
	check(press("MOVE") and g.controls.mode == "move", "   uprooting again: MOVE on its card")
	click(MOUSE_BUTTON_LEFT, a)
	check(tu.order == "move", "   a click gives the move (%s)" % tu.order)
	var got := await wait_for(func() -> bool: return tu.position.distance_to(a) < 30.0, 25.0)
	check(got, "   carried out once up")
	g.set_selection([])
	g.consume_unit(tu)


## 5. HARVEST autocast on patrol and on hold
func _patrol_harvest(q: Unit) -> void:
	var p1: Vector2 = g.cell_center(g.nearest_free(g.cell_of(q.position + Vector2(-200, 230)), 6))
	var p2: Vector2 = g.cell_center(g.nearest_free(g.cell_of(q.position + Vector2(140, 230)), 6))
	var gr: Unit = g._add_unit("grub", 0, p1)
	gr.auto_work = false
	gr.auto_harvest = true
	await physics_frame
	gr.give({"o": "patrol", "p": p2})
	await wait(1.5)
	var pa: Vector2 = gr.patrol_a
	var pb: Vector2 = gr.patrol_b
	check(pa != Vector2.INF and gr.order in ["move", "amove"], "5. a grub with HARVEST on patrols (%s)" % gr.order)
	var foe: Unit = g._add_unit("raptor", 1, gr.position + Vector2(50, 0))
	await physics_frame
	foe.take_damage(9999.0, null)
	var h := await wait_for(func() -> bool: return gr.order == "harvest", 4.0)
	check(h, "   a body falls near it: it breaks off its patrol to harvest")
	var wrapped := await wait_for(func() -> bool: return gr.cocoon > 0.0, 12.0)
	check(wrapped, "   it wraps the body")
	var r0 := float(g.players[0]["res2"])
	var back := await wait_for(func() -> bool: return gr.order != "harvest", 30.0)
	check(back and float(g.players[0]["res2"]) > r0, "   delivers it to the Mother (+%.1f spoils)" % (float(g.players[0]["res2"]) - r0))
	check(gr.order in ["move", "amove"] and gr.patrol_a == pa and gr.patrol_b == pb, "   and goes back to the same patrol (%s, %s -> %s)" % [gr.order, str(gr.patrol_a.round()), str(gr.patrol_b.round())])
	var at_b := await wait_for(func() -> bool: return gr.position.distance_to(pb) < 40.0, 25.0)
	var at_a := await wait_for(func() -> bool: return gr.position.distance_to(pa) < 40.0, 25.0)
	check(at_b and at_a, "   patrolling on between its two points")
	# on HOLD
	var hp: Vector2 = gr.position
	gr.give({"o": "hold"})
	await wait(1.2)
	var foe2: Unit = g._add_unit("raptor", 1, hp + Vector2(0, 60))
	await physics_frame
	foe2.take_damage(9999.0, null)
	var h2 := await wait_for(func() -> bool: return gr.order == "harvest", 4.0)
	check(h2, "   on HOLD: it harvests a body near it too")
	var back2 := await wait_for(func() -> bool: return gr.order == "hold", 40.0)
	check(back2 and gr.position.distance_to(hp) < 40.0, "   then back on HOLD where it was (%d px off)" % int(gr.position.distance_to(hp)))
	g.consume_unit(gr)
