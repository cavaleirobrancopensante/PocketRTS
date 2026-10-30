extends SceneTree
## CLOCK CHARGE (docs/clock_charge.md, the owner's playtest of 2026-10-30): every Clockwork unit with a charge shows it on
## its card (Unit.charge_text: "Charge 63%", "Winding up: 63%" on the gear field, "Fully wound", "RUN DOWN") and as a thin
## bar over it (Unit.charge_bar_shown: own units, not full, SHOW CHARGE BARS on); the Springer's screw is bigger in flight;
## the Netter's net ROOTS (no move, no abilities) but the caught unit still FIGHTS: a netted Musketeer fires, and it is
## not a stun (no stars).
##   godot --headless --fixed-fps 30 --script res://tools/test_clock_charge.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func step(g: Game, secs: float) -> void:
	var n := int(round(secs * 30.0))
	for i in n:
		U.step(g, 1.0 / 30.0)
		for c in g.get_children():
			if c is ChainNet and is_instance_valid(c) and not c.is_queued_for_deletion():
				c._physics_process(1.0 / 30.0)


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


func _run() -> void:
	Settings.charge_bars = true
	var g := U.make(root)
	await process_frame
	await process_frame
	g.human = 0
	var hall := U.hall(g, 0)
	var home := hall.center() + Vector2(0, 70)
	# ---- which units have a charge
	var cs: Unit = g._add_unit("clock_soldier", 0, _open_near(g, home))
	var sp: Unit = g._add_unit(Defs.SPRINGER, 0, _open_near(g, home + Vector2(30, 0)))
	var wd: Unit = g._add_unit("winder", 0, _open_near(g, home + Vector2(-30, 0)))
	var gw: Unit = g._add_unit(Defs.GREAT_WINDER_KIND, 0, _open_near(g, home + Vector2(0, 40)))
	var mk: Unit = g._add_unit("musketeer", 1, _open_near(g, home + Vector2(900, 0)))
	check("a Clock Soldier and a Springer have a charge", cs.has_charge() and sp.has_charge())
	check("a Winder, the Great Winder and a Musketeer show none", not wd.has_charge() and not gw.has_charge() and not mk.has_charge())
	# ---- the card text and the bar on the gear field
	step(g, 0.5)
	check("on the gear field, full: the card says Fully wound", cs.charge_text() == "Fully wound", cs.charge_text())
	check("full: no bar over it", not cs.charge_bar_shown())
	cs.wind = 0.63
	step(g, 0.1)
	check("on the gear field: it is winding up", cs._in_field and cs.charge_winding())
	check("the card says Winding up: N%", cs.charge_text().begins_with("Winding up: "), cs.charge_text())
	check("the bar shows while it fills", cs.charge_bar_shown())
	step(g, 2.0)
	check("it fills on the field", cs.wind > 0.63 + 0.3, "%.2f" % cs.wind)
	step(g, 1.0)
	check("full again: the bar is gone", cs.wind >= 0.995 and not cs.charge_bar_shown(), "%.3f" % cs.wind)
	# ---- off the field it drains, the bar shows, the card says Charge N%
	var far := _open_near(g, hall.center() + Vector2(1100, 300))
	cs.position = far
	cs._field_t = 0.0
	step(g, 3.0)
	check("off the field: not winding", not cs._in_field and not cs.charge_winding())
	check("off the field it runs down", cs.wind < 0.99, "%.3f" % cs.wind)
	check("the card says Charge N%", cs.charge_text().begins_with("Charge ") and cs.charge_text().ends_with("%"), cs.charge_text())
	check("the bar shows", cs.charge_bar_shown())
	Settings.charge_bars = false
	check("SHOW CHARGE BARS off: no bar", not cs.charge_bar_shown())
	Settings.charge_bars = true
	cs.wind = 0.0
	check("run down: the card says RUN DOWN", cs.charge_text() == "RUN DOWN", cs.charge_text())
	var foe_cs: Unit = g._add_unit("clock_soldier", 1, far + Vector2(0, 60))
	foe_cs.wind = 0.5
	check("an enemy's charge bar is not shown", not foe_cs.charge_bar_shown())
	# ---- the Springer's screw in flight: bigger, its sparks as before
	var tgt: Unit = g._add_unit("musketeer", 1, _open_near(g, sp.position + Vector2(120, 0)))
	tgt.max_hp = 5000.0
	tgt.hp = 5000.0
	tgt.cmd_hold()
	Springer.shoot(sp, tgt, 1.0)
	var shot: Shot = sp.last_shot
	check("the Springer's screw flies at fly_scale", shot != null and is_equal_approx(shot.scale.x, float(Defs.SPRINGER_SHOT["fly_scale"])),
			"%.2f" % (shot.scale.x if shot else -1.0))
	check("it is at least 1.6x its old size", float(Defs.SPRINGER_SHOT["fly_scale"]) >= 1.6 * float(Defs.SPRINGER_SHOT["shot_scale"]))
	check("its sparks stay at shot_scale", shot != null and is_equal_approx(shot.impact_scale, float(Defs.SPRINGER_SHOT["shot_scale"])))
	for u in [tgt, foe_cs, mk]:
		g.units.erase(u)
		u.queue_free()
	# ---- the Netter's net: a netted Musketeer cannot move but still fires
	var at := _open_near(g, hall.center() + Vector2(700, -200))
	var m: Unit = g._add_unit("musketeer", 1, at)
	m.max_hp = 5000.0
	m.hp = 5000.0
	var dummy: Unit = g._add_unit("clock_soldier", 0, _open_near(g, at + Vector2(120, 0)))
	dummy.max_hp = 5000.0
	dummy.hp = 5000.0
	dummy.cmd_hold()
	dummy.wind = 1.0
	Netter.catch(m, null, 0.0)
	check("netted: held by its net, not stunned", m.net_t > 1.0 and m.stun_t <= 0.0 and m.stun_left() == 0.0)
	var p0 := m.position
	m.cmd_move(m.position + Vector2(-300, 0))
	step(g, 1.0)
	check("netted: it does not move", m.position.distance_to(p0) < 2.0, "%.1f px" % m.position.distance_to(p0))
	var hp0 := dummy.hp
	m.cmd_attack(dummy)
	step(g, 2.5)
	check("netted: it still fires its musket at a target in reach", dummy.hp < hp0, "%.0f -> %.0f" % [hp0, dummy.hp])
	check("netted: still in place", m.position.distance_to(p0) < 2.0, "%.1f px" % m.position.distance_to(p0))
	check("netted: no spells (spell_problem says so)", g.spell_problem(m, "fog") != "")
	step(g, float(Defs.NET["time"]))
	m.cmd_move(m.position + Vector2(-200, 0))
	step(g, 1.0)
	check("free again, it moves", m.position.distance_to(p0) > 15.0, "%.1f px" % m.position.distance_to(p0))
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
