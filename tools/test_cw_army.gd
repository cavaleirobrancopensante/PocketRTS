extends SceneTree
## The new-style Clockwork army in gear mode: a linked Movement Works trains a Clock Soldier (an unlinked one does not),
## the soldier walks to an enemy and kills it, and a Regulator raises supply; the build list swaps the Spring Tower for
## the Regulator and adds the Works.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_army.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var bl := Defs.build_list("clockwork")
	check("gear mode builds the Regulator, not the Spring Tower", bl.has("regulator") and not bl.has("spring_tower"))
	check("gear mode builds the Movement Works", bl.has("movement_works"))
	check("the Clockwork's supply building is the Regulator", Defs.supply_kind("clockwork") == "regulator")
	g.players[0]["gold"] = 5000
	var hall := U.hall(g, 0)
	# the Regulator raises the supply cap
	var cap0 := int(g.players[0]["cap"])
	var reg := U.put(g, 0, "regulator", hall.cell)
	check("a Regulator links to the field", reg != null and g.gear_net.is_linked(reg))
	g._recount_supply(0)
	var cap1 := int(g.players[0]["cap"])
	check("a Regulator raises supply by 10", cap1 == cap0 + 10, "%d -> %d" % [cap0, cap1])
	# a linked Movement Works trains a Clock Soldier
	var works := U.put(g, 0, "movement_works", hall.cell)
	check("a Movement Works links to the field", works != null and g.gear_net.is_linked(works))
	if works == null:
		_end()
		return
	var why := g.train(works, "clock_soldier")
	check("it takes a Clock Soldier order", why == "", why)
	var n0 := g.units.filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and u.team == 0).size()
	U.step(g, float(Defs.UNITS["clock_soldier"]["time"]) * 0.5)
	check("it shows its working loop while it trains", works.drill_anim and works.sprite.texture != null \
			and works.sprite.texture.resource_path.contains("movement_works_work_"))
	U.step(g, float(Defs.UNITS["clock_soldier"]["time"]) * 0.5 + 2.0)
	var soldiers := g.units.filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and u.team == 0 and not u.dead)
	check("a Clock Soldier came out", soldiers.size() == n0 + 1, "%d" % soldiers.size())
	check("the Works stops its loop once idle", not works.drill_anim)
	# the Regulator's pendulum swings while it is linked
	U.step(g, 0.6)
	check("the Regulator's pendulum swings", reg.drill_anim and reg.sprite.texture.resource_path.contains("regulator_work_"))
	if soldiers.is_empty():
		_end()
		return
	var s: Unit = soldiers[0]
	# it walks to an enemy dummy (a Crown Labourer standing still) and kills it
	var foe: Unit = g._add_unit("labourer", 1, s.position + Vector2(260, 40))
	foe.auto_work = false
	foe.cmd_stop()
	foe.set_physics_process(false)
	var p0 := s.position
	s.cmd_attack(foe)
	var t := 0.0
	var saw_attack := false
	while t < 30.0 and not foe.dead:
		U.step(g, 0.2)
		t += 0.2
		s._animate(0.2)
		if s.anim == "attack":
			saw_attack = true
	check("the Clock Soldier walked to it", s.position.distance_to(p0) > 150.0, "%.0f px" % s.position.distance_to(p0))
	check("the Clock Soldier killed the enemy", foe.dead, "%.1f s" % t)
	check("it played its attack strip", saw_attack)
	# an unlinked Works does not train
	var far := U.put_far(g, 0, "movement_works")
	if far != null:
		g.gear_net.solve()
		g.train(far, "clock_soldier")
		var before := g.units.filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and u.team == 0).size()
		U.step(g, float(Defs.UNITS["clock_soldier"]["time"]) + 2.0)
		var after := g.units.filter(func(u: Unit) -> bool: return u.kind == "clock_soldier" and u.team == 0).size()
		check("an UNLINKED Movement Works trains nothing", after == before and not g.gear_net.is_linked(far))
	_end()


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
