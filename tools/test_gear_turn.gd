extends SceneTree
## TURNING GEARS (the owner's experiment, 2026-10-28; scripts/gear_turn.gd, docs/gear_turn.md):
##  1. a unit parked (on HOLD) on a turning band is carried round, the way its ring turns, and stays on the band;
##  2. on the still floor plate inside the band (or anywhere off it) nothing moves;
##  3. a Winder going to a Cog Press crosses its band without drifting and gets there;
##  4. the player's idle unit stays on the band and rides round (the owner's call: no automatic step-off); a unit walking
##     across drifts the full amount and still arrives where it was sent;
##  5. a unit on HOLD of the player stays and is carried; the computer walks its own HOLD and idle units off;
##  6. the big machines and flyers are not carried; meshed rings turn opposite ways;
##  7. the setting off: nothing moves;
##  8. deterministic: the same scene twice gives the same hash.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_turn.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-76s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## A clear spot on the band of building b (its mid radius), as far round as `from_deg` allows; INF if none.
func band_spot(g: Game, b: Building, from_deg := 90.0, frac := 0.5, rad := 12.0) -> Vector2:
	var net := g.gear_net
	for bi in net.bands.size():
		if net.bands[bi][0] != b:
			continue
		var c: Vector2 = net.bands[bi][1]
		var r := lerpf(float(net.bands[bi][2]), float(net.bands[bi][3]), frac)
		for k in 72:
			var a := deg_to_rad(from_deg + 5.0 * k)
			var gp := c + Vector2.from_angle(a) * r
			var w := Vector2(gp.x, gp.y * GearNet.FY)
			if g.in_map(g.cell_of(w)) and g._clear_at(w, rad, 1) and net.band_at(w) == bi:
				return w
	return Vector2.INF


func band_of(g: Game, b: Building) -> Array:
	for bd in g.gear_net.bands:
		if bd[0] == b:
			return bd
	return []


func ang_of(bd: Array, p: Vector2) -> float:
	return (GearNet.gpos(p) - Vector2(bd[1])).angle()


func _run() -> void:
	Defs.gear_turn = true
	var g := U.make(root)
	await process_frame
	await process_frame
	g.players[0]["gold"] = 50000
	var hall := U.hall(g, 0)
	U.step(g, 0.6)
	var net := g.gear_net
	check("the Clocktower's ring has a band", not band_of(g, hall).is_empty())
	var hb := band_of(g, hall)
	check("its band turns", net.band_turning(net.bands.find(hb)), str(net.spin_w.get(hall)))
	check("the band starts where the still plate ends (inner radius > 0, < outer)", float(hb[2]) > 20.0 and float(hb[2]) < float(hb[3]), "%.0f..%.0f" % [hb[2], hb[3]])
	# ---------------------------------------------------------------- 1. a unit on HOLD on the band rides round
	var p0 := band_spot(g, hall, 90.0)
	check("a clear spot on the Clocktower's band", p0 != Vector2.INF, str(p0))
	var mus: Unit = g._add_unit("musketeer", 1, p0)
	mus.cmd_hold()
	var a0 := ang_of(hb, mus.position)
	var w := float(net.spin_w[hall])
	var r0 := GearNet.gpos(mus.position).distance_to(hb[1])
	U.step(g, 4.0)
	var a1 := ang_of(hb, mus.position)
	var da := wrapf(a1 - a0, -PI, PI)
	var moved := mus.position.distance_to(p0)
	check("an enemy Musketeer on HOLD on the band is carried round (moved)", moved > 40.0, "%.0f px in 4 s" % moved)
	check("...the way the ring turns", signf(da) == signf(w), "da %.2f w %.3f" % [da, w])
	check("...by about the teeth's speed (w x r x 4 s, within 35%)", absf(absf(da) - absf(w) * 4.0) < absf(w) * 4.0 * 0.35, "da %.2f expect %.2f" % [absf(da), absf(w) * 4.0])
	check("...staying on the band (same distance from the centre within 12 px)", absf(GearNet.gpos(mus.position).distance_to(hb[1]) - r0) < 12.0)
	check("...still on HOLD", mus.order == "hold")
	U.step(g, 6.0)
	check("it keeps going round (another 6 s on)", absf(wrapf(ang_of(hb, mus.position) - a1, -PI, PI)) > absf(w) * 6.0 * 0.5)
	mus.die()
	# ---------------------------------------------------------------- 2. on the plate (or off the band): still
	var inner := Vector2.INF
	var c: Vector2 = hb[1]
	for k in 72:
		var gp := c + Vector2.from_angle(deg_to_rad(5.0 * k)) * (float(hb[2]) - 9.0)
		var wpt := Vector2(gp.x, gp.y * GearNet.FY)
		if g._clear_at(wpt, 9.0, 1) and net.band_at(wpt) < 0:
			inner = wpt
			break
	check("the plate inside the band carries nothing", inner == Vector2.INF or net.carry_at(inner) == Vector2.ZERO, str(inner))
	var outside := Vector2.INF
	for k in 72:
		var gp := c + Vector2.from_angle(deg_to_rad(5.0 * k)) * (float(hb[3]) + 30.0)
		var wpt := Vector2(gp.x, gp.y * GearNet.FY)
		if g._clear_at(wpt, 10.0, 1) and net.band_at(wpt, 12.0) < 0:
			outside = wpt
			break
	var still: Unit = g._add_unit("musketeer", 1, outside)
	still.cmd_hold()
	U.step(g, 3.0)
	check("a unit on HOLD just off the band does not move", still.position.distance_to(outside) < 3.0, "%.1f px" % still.position.distance_to(outside))
	if inner != Vector2.INF:
		var pl: Unit = g._add_unit("musketeer", 1, inner)
		pl.cmd_hold()
		U.step(g, 3.0)
		check("a unit on HOLD on the still plate does not move", pl.position.distance_to(inner) < 3.0, "%.1f px" % pl.position.distance_to(inner))
		pl.die()
	still.die()
	# ---------------------------------------------------------------- 3. a Winder walks in to a Cog Press across its band
	var press := U.put(g, 0, Defs.GEAR_PRESS, hall.cell)
	U.step(g, 0.6)
	check("a Cog Press links and turns", press != null and net.band_turning(net.bands.find(band_of(g, press))))
	if press != null:
		var pb := band_of(g, press)
		var far := Vector2.INF
		var pc: Vector2 = pb[1]
		var hc: Vector2 = hb[1]
		var away := (pc - hc).normalized()
		for k in 36:
			var gp := pc + away.rotated(deg_to_rad(10.0 * k * (1 if k % 2 == 0 else -1))) * (float(pb[3]) + 40.0)
			var wpt := Vector2(gp.x, gp.y * GearNet.FY)
			if g._clear_at(wpt, 10.0, 0) and net.band_at(wpt, 10.0) < 0:
				far = wpt
				break
		check("a spot outside the press's ring", far != Vector2.INF)
		var wd: Unit = g._add_unit("winder", 0, far)
		wd.cmd_gather(press)
		var drift := 0.0
		var got := false
		for i in 30 * 20:
			U.step(g, 1.0 / 30.0)
			drift = maxf(drift, wd.gt_carry.length())
			if wd.work == "manning":
				got = true
				break
		check("a Winder sent to a Cog Press gets there and cranks it", got, "work %s" % wd.work)
		check("...never carried on the way", drift == 0.0, "carry %.1f" % drift)
		wd.die()
	# a Winder repairing the Clocktower walks in across its band (the plate round it is narrow: he stands on the band)
	var far2 := Vector2.INF
	for k in 72:
		var gp := c + Vector2.from_angle(deg_to_rad(5.0 * k + 90.0)) * (float(hb[3]) + 40.0)
		var wpt := Vector2(gp.x, gp.y * GearNet.FY)
		if g._clear_at(wpt, 10.0, 0) and net.band_at(wpt, 10.0) < 0:
			far2 = wpt
			break
	hall.hp = hall.max_hp * 0.5
	var rp: Unit = g._add_unit("winder", 0, far2)
	rp.auto_work = false
	rp.cmd_repair(hall)
	var crossed := false
	var drift2 := 0.0
	var fixing := false
	for i in 30 * 20:
		U.step(g, 1.0 / 30.0)
		if net.band_at(rp.position) >= 0:
			crossed = true
		drift2 = maxf(drift2, rp.gt_carry.length())
		if hall.hp > hall.max_hp * 0.5 + 1.0:
			fixing = true
			break
	check("a Winder sent to repair the Clocktower crosses its band", crossed)
	check("...without being carried", drift2 == 0.0, "carry %.1f" % drift2)
	var at := rp.position
	U.step(g, 2.0)
	check("...gets there and repairs it, standing still meanwhile", fixing and rp.position.distance_to(at) < 3.0, "moved %.1f px" % rp.position.distance_to(at))
	rp.die()
	hall.hp = hall.max_hp
	# ---------------------------------------------------------------- 4. idle units ride; walkers drift fully and arrive
	var p1 := band_spot(g, hall, 200.0, 0.5, 12.0)
	var cs: Unit = g._add_unit("clock_soldier", 0, p1)
	cs.auto_work = false
	U.step(g, 0.2)
	check("an idle Clock Soldier of the player on the band is carried", cs.gt_carry != Vector2.ZERO)
	U.step(g, 4.0)
	check("...and STAYS on it, riding round (no step-off: the owner's call)", net.band_at(cs.position) >= 0 and cs.steps_taken == 0 and cs.position.distance_to(p1) > 40.0, "steps %d, %.0f px" % [cs.steps_taken, cs.position.distance_to(p1)])
	check("...still idle", cs.order == "idle")
	cs.die()
	# walking across: from one side of the band to the other, it arrives
	var a_out := Vector2.INF
	var a_in := Vector2.INF
	for k in 72:
		var dir := Vector2.from_angle(deg_to_rad(5.0 * k))
		var go := c + dir * (float(hb[3]) + 34.0)
		var gi := c + dir * (float(hb[2]) - 6.0)
		var wo := Vector2(go.x, go.y * GearNet.FY)
		var wi := Vector2(gi.x, gi.y * GearNet.FY)
		# (an outside spot and a spot across the band on the plate, or, if the plate is all building, further round outside)
		if g._clear_at(wo, 10.0, 0) and net.band_at(wo, 10.0) < 0:
			var go2 := c + dir.rotated(1.9) * (float(hb[3]) + 34.0)      # (the straight line between cuts across the band)
			var wo2 := Vector2(go2.x, go2.y * GearNet.FY)
			if g._clear_at(wo2, 10.0, 0) and net.band_at(wo2, 10.0) < 0:
				a_out = wo
				a_in = wo2
				break
	if a_out != Vector2.INF:
		var walker: Unit = g._add_unit("clock_soldier", 0, a_out)
		walker.auto_work = false
		walker.cmd_move(a_in)
		var touched := false
		for i in 30 * 8:
			U.step(g, 1.0 / 30.0)
			if walker.gt_carry != Vector2.ZERO:
				touched = true
				check_walk_share(walker)
		check("a soldier walking across a band is nudged (felt the band)", touched)
		check("...and arrives where it was sent (within 14 px)", walker.position.distance_to(a_in) < 14.0, "%.1f px" % walker.position.distance_to(a_in))
		walker.die()
	# ---------------------------------------------------------------- 5. HOLD: the player's stays, the computer's steps off
	var p2 := band_spot(g, hall, 300.0)
	var hold0: Unit = g._add_unit("clock_soldier", 0, p2)
	hold0.cmd_hold()
	U.step(g, 4.0)
	check("the player's Clock Soldier on HOLD stays on the band and is carried", net.band_at(hold0.position) >= 0 and hold0.position.distance_to(p2) > 30.0 and hold0.steps_taken == 0)
	hold0.die()
	var ai := AI.new()
	ai.team = 1
	g.ais.append(ai)
	var p3 := band_spot(g, hall, 20.0)
	var hold1: Unit = g._add_unit("musketeer", 1, p3)
	hold1.cmd_hold()
	U.step(g, 4.0)
	check("the computer walks its own unit on HOLD off the band", net.band_at(hold1.position) < 0 and hold1.steps_taken >= 1 and hold1.order == "hold")
	ai.team = 0          # (its own idle unit: a Clockwork one on its own Clocktower's band, so it has nothing to shoot at)
	var p3b := band_spot(g, hall, 160.0)
	var idle1: Unit = g._add_unit("clock_soldier", 0, p3b)
	idle1.auto_work = false
	U.step(g, 4.0)
	check("...and its idle unit too, its order unchanged", net.band_at(idle1.position) < 0 and idle1.steps_taken >= 1 and idle1.order == "idle")
	var off1 := idle1.position
	U.step(g, 4.0)
	check("...which then stays off (no back and forth)", net.band_at(idle1.position) < 0 and idle1.position.distance_to(off1) < 20.0)
	idle1.die()
	g.ais.erase(ai)
	ai.free()
	hold1.die()
	# ---------------------------------------------------------------- 6. who is not carried; meshed rings
	var p4 := band_spot(g, hall, 120.0, 0.5, 26.0)
	if p4 != Vector2.INF:
		var gw: Unit = g._add_unit(Defs.GREAT_WINDER_KIND, 0, p4)
		gw.cmd_hold()
		U.step(g, 2.0)
		check("a Great Winder (a big machine) is not carried", gw.position.distance_to(p4) < 3.0, "%.1f" % gw.position.distance_to(p4))
		gw.die()
	var flyers := Defs.UNITS.keys().filter(func(k) -> bool: return bool(Defs.UNITS[k].get("air", false)))
	if not flyers.is_empty():
		var fl: Unit = g._add_unit(flyers[0], 0, band_spot(g, hall, 60.0))
		fl.cmd_hold()
		U.step(g, 1.0)
		check("a flyer (%s) is not carried" % flyers[0], fl.gt_carry == Vector2.ZERO)
		fl.die()
	if press != null and net.parent_of.get(press) == hall and not net.idler_of.has(press):
		check("a ring meshing directly with the Clocktower turns the other way", signf(float(net.spin_w[press])) == -signf(float(net.spin_w[hall])))
		check("...at the same rim speed (w x teeth equal)", absf(absf(float(net.spin_w[press])) * GearNet.b_n(press) - absf(float(net.spin_w[hall])) * GearNet.b_n(hall)) < 0.001)
	# ---------------------------------------------------------------- 7. the setting off
	Defs.gear_turn = false
	var p5 := band_spot(g, hall, 90.0)
	var off_u: Unit = g._add_unit("musketeer", 1, p5)
	off_u.cmd_hold()
	U.step(g, 3.0)
	check("TURNING GEARS off: a unit on HOLD on the band stays put", off_u.position.distance_to(p5) < 2.0, "%.1f" % off_u.position.distance_to(p5))
	Defs.gear_turn = true
	g.queue_free()
	await process_frame
	# ---------------------------------------------------------------- 8. deterministic
	var h1 := await _scene_hash()
	var h2 := await _scene_hash()
	check("the same scene twice gives the same hash", h1 == h2, "%d / %d" % [h1, h2])
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func check_walk_share(u: Unit) -> void:
	# (walking, it feels only the walk share of the band's push)
	var full := u.game.gear_net.carry_at(u.position) * float(Defs.GEAR_TURN["carry"])
	if full.length() > 1.0 and u.velocity.length() > 5.0 and u.gt_carry.length() > full.length() * float(Defs.GEAR_TURN["walk"]) + 0.5:
		check("walking: only the walk share of the push", false, "%.1f of %.1f" % [u.gt_carry.length(), full.length()])


## A scene: a Clocktower, a press, a crowd of both sides' soldiers on HOLD, idle and walking on its bands, played 12 s.
func _scene_hash() -> int:
	seed(4242)              # (the game's dice are the global ones: tools/test_determinism.gd seeds them the same way)
	var g := U.make(root)
	await process_frame
	await process_frame
	var hall := U.hall(g, 0)
	U.put(g, 0, Defs.GEAR_PRESS, hall.cell)
	U.step(g, 0.5)
	var us: Array = []
	for k in 10:
		var p := band_spot(g, hall, 36.0 * k, 0.3 + 0.05 * k)
		if p == Vector2.INF:
			continue
		var u: Unit = g._add_unit("musketeer" if k % 2 == 0 else "clock_soldier", k % 2, p)
		if k % 3 == 0:
			u.cmd_hold()
		elif k % 3 == 1:
			u.cmd_move(hall.center() + Vector2(260, 0).rotated(float(k)))
		us.append(u)
	U.step(g, 12.0)
	var h := 17
	for u in g.units:
		if is_instance_valid(u):
			h = hash([h, u.kind, u.team, snappedf(u.position.x, 0.001), snappedf(u.position.y, 0.001), snappedf(u.hp, 0.001)])
	g.queue_free()
	await process_frame
	return h
