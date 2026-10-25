## Storm Engine (Clockwork roster prototype): THUNDER raises a thunderstorm (slow damage plus slow) on the enemy at range,
## it ends by itself and the engine recharges; off the rails it needs crew and storms weaker and smaller.
##   godot --headless --fixed-fps 30 --script res://tools/test_cw_storm.gd
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
	var eng := CU.spawn(g, "storm_engine", 0, mid)
	var foes: Array = []
	for i in 3:
		var f := CU.spawn(g, "labourer", 1, mid + Vector2(-30 + 30 * i, 220))
		f.max_hp = 4000.0
		f.hp = 4000.0
		f.armor = 0
		f.auto_work = false
		foes.append(f)
	var outside := CU.spawn(g, "labourer", 1, mid + Vector2(0, 220 + 260))
	outside.max_hp = 4000.0
	outside.hp = 4000.0
	var friend := CU.spawn(g, "labourer", 0, mid + Vector2(0, 220))
	friend.max_hp = 4000.0
	friend.hp = 4000.0
	friend.auto_work = false
	outside.auto_work = false
	await CU.step(self, g, 0.3)
	check("it has no gun of its own", not eng.can_hit(foes[0]))
	var target := mid + Vector2(0, 220)
	var why := CwUnits.cast_order([eng], target)
	check("THUNDER is ordered", why == "", why)
	await CU.step(self, g, float(Defs.CW["storm"]["cast"]) + 0.6)
	check("a storm gathers over the spot", g.cw_storms.size() == 1)
	await CU.step(self, g, 4.0)
	var lost: float = 4000.0 - foes[1].hp
	check("it hurts the enemy inside", lost > 15.0, "%.0f lost" % lost)
	check("the enemy are slowed", foes[1].slow_t > 0.0)
	check("the enemy outside are untouched", outside.hp == 4000.0)
	check("and so are friends", friend.hp == 4000.0)
	check("it is recharging", CwUnits.storm_problem(eng) != "")
	await CU.step(self, g, float(Defs.CW["storm"]["time"]) + 1.0)
	check("the storm blows itself out", g.cw_storms.is_empty())
	# off the rails: no crew, no storm; with crew, a weaker one
	eng.cw["cd"] = 0.0
	var spot := mid + Vector2(0, 4 * 32)
	check("it can be set up near the Line", CwUnits.set_up_order(eng, spot) == "")
	await CU.step(self, g, 16.0)
	check("set up and uncrewed it cannot storm", CwUnits.storm_problem(eng) != "", CwUnits.storm_problem(eng))
	var men: Array = []
	for i in 3:
		men.append(CU.spawn(g, "tin_militia", 0, eng.position + Vector2(20, 6 * i)))
	CwUnits.board_order(men, eng)
	await CU.step(self, g, 4.0)
	check("with crew it can", CwUnits.storm_problem(eng) == "", CwUnits.storm_problem(eng))
	for f in foes:
		f.hp = 4000.0
		f.position = eng.position + Vector2(0, 200)
	CwUnits.cast_order([eng], eng.position + Vector2(0, 200))
	await CU.step(self, g, float(Defs.CW["storm"]["cast"]) + 0.3)
	check("the crewed storm is smaller and weaker", g.cw_storms.size() == 1 and float(g.cw_storms[0]["r"]) < float(Defs.CW["storm"]["radius"]) * 0.8 \
		and float(g.cw_storms[0]["dps"]) < float(Defs.CW["storm"]["dps"]) * 0.8)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
