## Heavy Locomotive (Clockwork roster prototype): full damage on the rails; set up off them it needs Tin Militia crew
## (reduced power with crew, helpless without); crew aboard stay wound and safe; PACK goes back to the rails.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_heavy.gd
extends SceneTree
const CU := preload("res://tools/cw_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _hit(g: Game, loco: Unit, foe: Unit) -> float:
	foe.hp = foe.max_hp
	var h0 := foe.hp
	loco.cooldown = 0.0
	loco._strike(foe)
	return h0 - foe.hp


func _run() -> void:
	var g := CU.make(root)
	await process_frame
	await process_frame
	CU.rich(g)
	var cells := CU.row(g, 0, 12)
	var mid := g.cell_center(cells[6])
	var loco := CU.spawn(g, "heavy_loco", 0, mid)
	var foe := CU.spawn(g, "cuirassier", 1, mid + Vector2(0, 150))
	foe.max_hp = 9000.0
	foe.armor = 0
	foe.hp = 9000.0
	await CU.step(self, g, 0.3)
	check("it starts on the rails", CwRail.bound(loco))
	var on_rails := _hit(g, loco, foe)
	check("on the rails it fires at full damage", on_rails >= float(loco.d["damage"]) * 0.9, "%.0f (card %d)" % [on_rails, int(loco.d["damage"])])
	# SET UP too far from the Line is refused
	var far_why := CwUnits.set_up_order(loco, mid + Vector2(0, 12 * 32))
	check("it will not set up too far from the Line", far_why != "", far_why)
	# SET UP in reach
	var spot := mid + Vector2(0, 4 * 32)
	var why := CwUnits.set_up_order(loco, spot)
	check("it can set up within reach", why == "", why)
	await CU.step(self, g, 14.0)
	check("it leaves the rails and sets up", not CwRail.bound(loco) and bool(loco.cw.get("set", false)), "off %s set %s at %.0f from the spot" % [loco.cw.get("off"), loco.cw.get("set"), loco.position.distance_to(spot)])
	await CU.step(self, g, float(Defs.CW["heavy"]["deploy"]) + 0.5)
	check("set up with no crew it is helpless", not loco.can_hit(foe) and _hit(g, loco, foe) == 0.0)
	# crew: Tin Militia climb in
	var men: Array = []
	for i in 3:
		men.append(CU.spawn(g, "tin_militia", 0, loco.position + Vector2(20 + 6 * i, 0)))
	var sent := CwUnits.board_order(men, loco)
	check("BOARD sends the militia", sent == 3, "%d" % sent)
	await CU.step(self, g, 4.0)
	check("they climb aboard", CwUnits.crew_count(loco) == 3, "%d aboard" % CwUnits.crew_count(loco))
	check("aboard they are safe (off the field)", men.all(func(m: Unit) -> bool: return m.off_field and m.untouchable()))
	men[0].wind = 0.1
	await CU.step(self, g, 1.0)
	check("aboard they stay wound", men[0].wind >= 0.99)
	var crewed := _hit(g, loco, foe)
	check("with a full crew it fires at reduced power", crewed > 0.0 and crewed < on_rails * 0.8, "%.0f vs %.0f on rails" % [crewed, on_rails])
	# half the crew
	CwUnits.disembark(loco)
	check("CREW OUT lets them off", CwUnits.crew_count(loco) == 0 and men.all(func(m: Unit) -> bool: return not m.off_field))
	check("and it is helpless again", _hit(g, loco, foe) == 0.0)
	CwUnits.board_order([men[0]], loco)
	await CU.step(self, g, 3.0)
	var one := _hit(g, loco, foe)
	check("one man gives less power than three", one > 0.0 and one < crewed, "%.0f vs %.0f" % [one, crewed])
	# the loco dies: the crew climb out hurt
	var hp0: float = men[0].hp
	loco.take_damage(100000.0, null)
	await CU.step(self, g, 0.3)
	check("a lost loco puts its crew on the ground, hurt", not men[0].off_field and men[0].hp < hp0, "%.0f -> %.0f" % [hp0, men[0].hp])
	# PACK back
	var l2 := CU.spawn(g, "heavy_loco", 0, mid)
	await CU.step(self, g, 0.3)
	CwUnits.set_up_order(l2, spot)
	await CU.step(self, g, 14.0)
	CwUnits.pack_order(l2)
	await CU.step(self, g, 14.0)
	check("PACK drives it back onto the rails", CwRail.bound(l2) and not l2.cw.has("set"), "off %s" % l2.cw.get("off"))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
