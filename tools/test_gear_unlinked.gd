extends SceneTree
## An unlinked building does nothing: no production, no income, no Tension winding, no repairs; its gears stand still
## and the HUD says UNLINKED. Linked ones work.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_unlinked.gd
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
	var net: GearNet = g.gear_net
	var tower := U.hall(g, 0)
	g.players[0]["gold"] = 5000
	var works := U.put(g, 0, "assembly_works", tower.cell)
	var lone := U.put_far(g, 0, "assembly_works", 20)
	var spring_ok := U.put(g, 0, "mainspring", tower.cell)      # (gear mode has no power: the Mainspring, not a Boiler)
	var spring_off := U.put_far(g, 0, "mainspring", 20)
	var press_off := U.put_far(g, 0, Defs.GEAR_PRESS, 20)
	check("set-up: a linked and an unlinked Assembly Works", works != null and lone != null and net.linked.has(works) and not net.linked.has(lone))
	check("is_linked says so (the HUD shows UNLINKED)", net.is_linked(works) and not net.is_linked(lone))
	# production
	g.train(works, "windup_soldier")
	g.train(lone, "windup_soldier")
	U.step(g, 6.0)
	check("a linked works makes progress on its queue", works.prod_t > 3.0 or works.queue.is_empty(), "%.1f" % works.prod_t)
	check("an unlinked works makes none", lone.prod_t == 0.0 and lone.queue.size() == 1, "%.1f" % lone.prod_t)
	# the Cog Press: income 0 and its Winders stand there for nothing
	for i in 3:
		var w: Unit = g._add_unit("winder", 0, press_off.center() + Vector2(i * 20, 70))
		w.cmd_gather(press_off)
	var paid0 := press_off.press_paid
	U.step(g, 10.0)
	check("an unlinked Cog Press pays nothing (even with Winders on it)", press_off.press_paid == paid0 and press_off.press_rate() == 0.0)
	# Tension: a linked Mainspring winds (a little by itself), an unlinked one does not; and no batteries anywhere (no power)
	U.step(g, 2.0)
	check("a linked Mainspring winds Tension", spring_ok != null and spring_ok.spring_rate() > 0.0, "%.2f" % (spring_ok.spring_rate() if spring_ok else -1.0))
	check("an unlinked Mainspring winds none", spring_off != null and spring_off.spring_rate() == 0.0, "%.2f" % (spring_off.spring_rate() if spring_off else -1.0))
	check("no batteries fill anywhere (no power in gear mode)", g.buildings.all(func(b: Building) -> bool: return b.batteries == 0))
	# gears stand still
	var a0: float = net.ang.get(lone, 0.0)
	var m0: float = net.ang.get(works, 0.0)
	U.step(g, 1.0)
	check("the unlinked gear stands still, the linked one turns", absf(float(net.ang.get(lone, 0.0)) - a0) < 0.0001 and absf(float(net.ang.get(works, 0.0)) - m0) > 0.001)
	# linking it later (a new building bridges the gap) makes it work: bridge with a chain of cheap towers is map dependent,
	# so test the opposite: the linked works stops when the tower falls
	tower.take_damage(999999.0, null)
	U.step(g, 0.7)
	check("with the Clocktower gone every building is unlinked and stops", not net.is_linked(works) and net.speed_mult(works) == 0.0)
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
