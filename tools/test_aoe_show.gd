extends SceneTree
## AREA MARKS and the Clockwork's "+N" (docs/aoe_show.md):
##  - a Pendulum blow lays its wedge on the ground (and the blade's smear over the units), a Mortar shell a warning while
##    it flies and a ring where it lands, a canister its cone, a Spore Mother's spit a warning and an oval;
##  - only where the watching side sees the ground (a shell an enemy fires into the fog on its own ground: nothing);
##  - the marks fade away; Settings.area_marks off: none;
##  - a Cog Press's cogs come up as one "+N" over it every few seconds, for its owner only; a Mainspring's Tension the same.
##   godot --headless --fixed-fps 30 --script res://tools/test_aoe_show.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-78s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _marks(g: Game, shape: String, warn := false) -> Array:
	return g.ground_marks.marks.filter(func(m: Dictionary) -> bool: return String(m["s"]) == shape and bool(m.get("warn", false)) == warn)


func _run() -> void:
	Settings.area_marks = true
	var g := U.make(root, ["clockwork", "crown"], "", false)      # (not a demo: team 0 is ours, with its fog)
	await process_frame
	await process_frame
	g.view_rect = Rect2(Vector2(-100000, -100000), Vector2(200000, 200000))
	U.step(g, 0.5)                    # (the fog is worked out)
	var hall := U.hall(g, 0)
	var foe_hall := U.hall(g, 1)
	var at := _open_near(g, hall.center() + Vector2(0, 260))
	check("our ground is seen, the enemy's base is not", g.side_sees(0, at) and not g.side_sees(0, foe_hall.center()))

	# --- the Pendulum
	var pd: Unit = g._add_unit(Defs.PENDULUM, 0, at)
	pd.cmd_stop()
	var foe := _foe(g, "labourer", at + Vector2(40, 0))
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(foe)
	var t := 0.0
	while pd.swings < 1 and t < 5.0:
		U.step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
	var w := _marks(g, "wedge")
	check("a Pendulum blow lays its wedge on the ground", w.size() == 1 and (w[0]["p"] as Vector2) == pd.position, str(w.size()))
	if w.size() == 1:
		check("  the wedge is the blow's arc (62 px, 60 degrees either side, toward the foe)", absf(float(w[0]["r"]) - 62.0) < 0.1
			and absf(float(w[0]["h"]) - deg_to_rad(60.0)) < 0.001 and (w[0]["a"] as Vector2).dot(Vector2.RIGHT) > 0.95)
	var sm: Array = g.swipe_marks.marks.filter(func(m: Dictionary) -> bool: return m["s"] == "smear")
	check("  and the blade's smear over the units, lasting 0.3-0.4 s", sm.size() == 1 and float(sm[0]["life"]) >= 0.3 and float(sm[0]["life"]) <= 0.4)
	U.step(g, 0.2)
	check("  the smear still shows 0.2 s after the blow", g.swipe_marks.marks.size() == 1)
	g.ground_marks._process(0.6)
	g.swipe_marks._process(0.6)
	check("the marks fade away (gone after 0.6 s)", g.ground_marks.marks.is_empty() and g.swipe_marks.marks.is_empty())
	check("  and the nodes stop processing once empty", not g.ground_marks.is_processing() and not g.swipe_marks.is_processing())
	pd.cmd_stop()
	pd.queue_free()
	g.units.erase(pd)

	# --- a Mortar shell (an enemy's, landing on our ground): a warning while it flies, a ring where it lands
	var mortar: Unit = _foe(g, "mortar", at + Vector2(-300, 0))
	g.mortar_shot(mortar, at + Vector2(0, 40), 20.0)
	var warn := _marks(g, "ring", true)
	check("an enemy Mortar shell on our ground: a warning ring where it will land", warn.size() == 1, str(warn.size()))
	var landed := false
	for i in 90:
		_step(g, 1.0 / 30.0)
		if not _marks(g, "ring", false).is_empty():
			landed = true
			break
	check("  and a ring where it lands (its splash)", landed and absf(float(_marks(g, "ring", false)[0]["r"]) - float(mortar.d["splash"])) < 0.1)
	g.ground_marks._process(1.0)
	# into the fog, on the enemy's own ground: we see nothing of it
	var n0: int = g.ground_marks.shown_total
	var fogged := foe_hall.center() + Vector2(0, 80)
	g.mortar_shot(mortar, fogged, 20.0)
	check("a shell into ground we don't see lays no mark for us", g.ground_marks.shown_total == n0,
		"%d -> %d, sees %s, all %s" % [n0, g.ground_marks.shown_total, g.side_sees(0, fogged), g.sees_all()])
	_step(g, 2.0)
	check("  not when it lands either", g.ground_marks.shown_total == n0, str(g.ground_marks.marks.map(func(m: Dictionary) -> String: return "%s %s t%d %s" % [m["s"], m["p"], m["team"], m.get("warn")])))

	# --- a canister
	var gun: Unit = _foe(g, "cannon", at + Vector2(-120, 0))
	gun.mode = "canister"
	g.canister_at(gun, at, 10.0)
	var cone := _marks(g, "wedge")
	check("a canister lays its cone", cone.size() == 1 and absf(float(cone[0]["h"]) - acos(float(Defs.CANISTER["cone"]))) < 0.001)
	g.ground_marks._process(1.0)

	# --- a Spore Mother's spit
	var sp: Unit = _foe(g, "spore_mother", at + Vector2(-200, 60))
	g.blob_shot(sp, at, 10.0)
	check("a Spore Mother's spit: a warning oval while it flies", _marks(g, "oval", true).size() == 1)
	landed = false
	for i in 60:
		_step(g, 1.0 / 30.0)
		if not _marks(g, "oval", false).is_empty():
			landed = true
			break
	check("  and an oval where it lands", landed)
	g.ground_marks._process(2.0)

	# --- the setting
	Settings.area_marks = false
	g.canister_at(gun, at, 10.0)
	g.mortar_shot(mortar, at, 20.0)
	check("AREA MARKS off: no marks", g.ground_marks.marks.is_empty())
	Settings.area_marks = true
	_step(g, 2.0)
	g.ground_marks._process(2.0)

	# --- the Clockwork's "+N"
	var press := U.put(g, 0, "cog_press", g.cell_of(hall.center()))
	check("a Cog Press stands", press != null)
	if press:
		var floats := func() -> Array: return g._floats.filter(func(f: Array) -> bool: return String(f[1]).begins_with("+") and (f[0] as Vector2).distance_to(press.center()) < 60.0)
		g._floats.clear()
		var got0: int = int(g.players[0]["gold"])
		var seen: Array = []
		for i in 30 * 9:
			U.step(g, 1.0 / 30.0)
			for f in floats.call():
				if not seen.has(f[1]):
					seen.append(f[1])
		var popped: Array = []
		for f in g._floats:
			if String(f[1]).begins_with("+") and (f[0] as Vector2).distance_to(press.center()) < 60.0:
				popped.append(f[1])
		check("a working Cog Press shows \"+N\" over itself every few seconds", seen.size() >= 1, "%s (gold %d -> %d)" % [str(seen), got0, int(g.players[0]["gold"])])
		check("  not every tick (at most one every 4 s)", g._floats.filter(func(f: Array) -> bool: return (f[0] as Vector2).distance_to(press.center()) < 60.0).size() <= 1)
	# an enemy's press: we see none of its numbers
	g._floats.clear()
	var theirs := g._add_building("cog_press", 1, g.cell_of(foe_hall.center()) + Vector2i(0, 6), true)
	for i in 10:
		theirs.pop_income(5.0, 1.0)
	check("the enemy's Cog Press shows us nothing", g._floats.is_empty())
	var ours := g._add_building("mainspring", 0, g.cell_of(hall.center()) + Vector2i(6, 6), true)
	for i in 8:
		ours.pop_income(2.0, 1.0)
	check("our Mainspring's Tension: one \"+N tension\" every 6 s", g._floats.size() == 1 and String(g._floats[0][1]).contains("12"), str(g._floats.map(func(f: Array) -> String: return f[1])))
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails else 0)


## U.step and the shells, spit and bombs in flight.
func _step(g: Game, secs: float) -> void:
	var n := maxi(1, int(round(secs * 30.0)))
	for i in n:
		U.step(g, 1.0 / 30.0)
		for c in g.get_children():
			if (c is Projectile or c is OwlBomb) and not c.is_queued_for_deletion():
				c._physics_process(1.0 / 30.0)
		for gm in [g.ground_marks, g.swipe_marks]:
			if gm.is_processing():
				gm._process(1.0 / 30.0)


func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, _open_near(g, p))
	u.auto_work = false
	u.cmd_hold()
	u.hold_fire = true          # (it fires only when the test says so)
	return u


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))
