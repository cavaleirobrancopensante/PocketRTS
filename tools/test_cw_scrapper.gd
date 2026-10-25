extends SceneTree
## Scrapper (Clockwork roster prototype): stacking, quickly decaying bonuses from deaths nearby (friend or foe), Tin
## Militia bodies count double, stacks are capped and a splash that kills many counts once.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_scrapper.gd
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
	var cells := CU.row(g, 0, 10)
	var p := g.cell_center(cells[4]) + Vector2(0, 64)
	var s := CU.spawn(g, "scrapper", 0, p)
	var cfg: Dictionary = Defs.CW["scrapper"]
	await CU.step(self, g, 0.3)
	# 1. a foe dies beside it
	var f := CU.spawn(g, "labourer", 1, p + Vector2(60, 0))
	f.take_damage(9999.0, null)
	check("a death nearby gives a stack", int(s.cw.get("stacks", 0)) == 1, "%d" % int(s.cw.get("stacks", 0)))
	# 2. a second death at once counts once (gain cooldown)
	var f2 := CU.spawn(g, "labourer", 1, p + Vector2(60, 10))
	f2.take_damage(9999.0, null)
	check("a splash of deaths counts once", int(s.cw.get("stacks", 0)) == 1)
	await CU.step(self, g, float(cfg["gain_cd"]) + 0.2)
	# 3. a friend's death counts too, Tin Militia double
	var m := CU.spawn(g, "tin_militia", 0, p + Vector2(-50, 0))
	m.take_damage(9999.0, null)
	check("a fallen Tin Militia counts double", int(s.cw.get("stacks", 0)) == 3, "%d" % int(s.cw.get("stacks", 0)))
	# 4. the stacks are capped
	for i in 8:
		await CU.step(self, g, float(cfg["gain_cd"]) + 0.1)
		var x := CU.spawn(g, "tin_militia", 1, p + Vector2(40, 20))
		x.take_damage(9999.0, null)
	check("stacks are capped", int(s.cw.get("stacks", 0)) == int(cfg["max"]), "%d" % int(s.cw.get("stacks", 0)))
	# 5. the bonus is real: damage and speed
	var base_speed := float(s.d["speed"])
	await CU.step(self, g, 0.1)
	check("speed rises with the stacks", s.speed > base_speed * 1.1, "%.0f vs %.0f" % [s.speed, base_speed])
	var t1 := CU.spawn(g, "town_hall", 1, p) if false else null
	var victim := CU.spawn(g, "cuirassier", 1, p + Vector2(500, 300))
	victim.max_hp = 5000.0
	victim.armor = 0
	victim.hp = 5000.0
	var hp0 := victim.hp
	s.cooldown = 0.0
	CwUnits.strike(s, victim, float(s.d["damage"]))
	var hit_full := hp0 - victim.hp
	s.cw["stacks"] = 0
	victim.hp = hp0
	CwUnits.strike(s, victim, float(s.d["damage"]))
	var hit_none := hp0 - victim.hp
	check("damage rises with the stacks", hit_full > hit_none * 1.3, "%.1f vs %.1f" % [hit_full, hit_none])
	# 6. it decays quickly
	s.cw["stacks"] = int(cfg["max"])
	s.cw["decay_t"] = float(cfg["decay"])
	await CU.step(self, g, float(cfg["decay"]) * float(cfg["max"]) + 1.0)
	check("the stacks run out on their own", int(s.cw.get("stacks", 0)) == 0, "%d" % int(s.cw.get("stacks", 0)))
	# 7. far deaths do not count
	var far := CU.spawn(g, "labourer", 1, p + Vector2(900, 0))
	far.take_damage(9999.0, null)
	check("a death far away gives nothing", int(s.cw.get("stacks", 0)) == 0)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
