## Tesla Locomotive (Clockwork roster prototype): zaps along the Line, harder with pressure, hits flyers, its bolt jumps
## to more enemies and along the pipe, and it overcharges the constructs it passes.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_tesla.gd
extends SceneTree
const CU := preload("res://tools/cw_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := CU.make(root)
	await process_frame
	await process_frame
	CU.rich(g)
	var cells := CU.row(g, 0, 12)
	var mid := g.cell_center(cells[6])
	var loco := CU.spawn(g, "tesla_loco", 0, mid)
	var e1 := CU.spawn(g, "cuirassier", 1, mid + Vector2(0, 100))
	var e2 := CU.spawn(g, "cuirassier", 1, mid + Vector2(40, 130))
	var e3 := CU.spawn(g, "cuirassier", 1, mid + Vector2(-40, 135))
	var fly := CU.spawn(g, "ornithopter", 1, mid + Vector2(120, -40))
	for e in [e1, e2, e3, fly]:
		e.max_hp = 4000.0
		e.hp = 4000.0
		e.armor = 0
		e.hold_fire = false
	await CU.step(self, g, 0.3)
	# one bolt: the chain
	var dmg := float(loco.d["damage"])
	CwUnits.tesla_zap(loco, e1, dmg)
	check("a bolt hurts its target", e1.hp < 4000.0, "%.0f" % e1.hp)
	check("and jumps to others nearby", e2.hp < 4000.0 or e3.hp < 4000.0, "%.0f %.0f" % [e2.hp, e3.hp])
	check("the jump is weaker than the first hit", (4000.0 - e2.hp) < (4000.0 - e1.hp) or (4000.0 - e3.hp) < (4000.0 - e1.hp))
	# pressure
	g.line_net.enforce = true
	var s: PipeSeg = g.line_net.segs[g.cell_of(loco.position)]
	s.pressure = 1.0
	for e in [e1, e2, e3]:
		e.hp = 4000.0
	CwUnits.tesla_zap(loco, e1, dmg)
	var hard := 4000.0 - e1.hp
	s.pressure = 0.2
	e1.hp = 4000.0
	CwUnits.tesla_zap(loco, e1, dmg)
	var soft := 4000.0 - e1.hp
	check("more pressure, harder bolt", hard > soft * 1.2, "%.1f vs %.1f" % [hard, soft])
	g.line_net.enforce = false
	# it fights by itself, flyers too
	for e in [e1, e2, e3, fly]:
		e.hp = 4000.0
	loco.cooldown = 0.0
	await CU.step(self, g, 8.0)
	check("it shoots the ground by itself", e1.hp < 4000.0 or e2.hp < 4000.0 or e3.hp < 4000.0)
	check("and flyers", fly.hp < 4000.0, "%.0f" % fly.hp)
	# along the pipe: an enemy standing at the Line a few cells off the loco
	var pipe_foe := CU.spawn(g, "cuirassier", 1, g.cell_center(cells[9]) + Vector2(0, 12))
	pipe_foe.max_hp = 4000.0
	pipe_foe.hp = 4000.0
	pipe_foe.armor = 0
	await CU.step(self, g, 0.2)
	e1.hp = 4000.0
	var pf0 := pipe_foe.hp
	CwUnits.tesla_zap(loco, e1, dmg)
	check("the bolt runs along the pipe to an enemy at the Line", pipe_foe.hp < pf0 or e2.hp < 4000.0, "%.0f" % pipe_foe.hp)
	# overcharge (the enemies gone, the loco stands still)
	for e in [e1, e2, e3, fly, pipe_foe]:
		e.take_damage(99999.0, null)
	loco.cmd_stop()
	await CU.step(self, g, 1.0)
	var walker := CU.spawn(g, "steam_walker", 0, loco.position + Vector2(30, -30))
	await CU.step(self, g, 2.0)
	check("units it passes are overcharged", walker.overcharged(), "t %.1f" % walker.overcharge_t)
	var far_walker := CU.spawn(g, "steam_walker", 0, loco.position + Vector2(300, 300))
	await CU.step(self, g, 2.0)
	check("units far from it are not", not far_walker.overcharged())
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
