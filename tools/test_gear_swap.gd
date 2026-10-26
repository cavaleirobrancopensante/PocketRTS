extends SceneTree
## GEAR SWAP: the SMALL GEAR / BIG GEAR toggle on a building: costs cogs, takes seconds, the ring changes size, the
## building idles meanwhile, a smaller crew cap lets the extra Winders go. Not offered for the Clocktower.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_swap.gd
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
	var press: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS:
			press = b
	var r_small := GearNet.b_r(press)
	var cost := int(Defs.GEAR["swap_cost"])
	check("the Clocktower's gear cannot be swapped", g.gear_swap_problem(tower) != "")
	g.players[0]["gold"] = cost - 1
	check("not enough cogs: refused with a reason", g.gear_swap_problem(press).begins_with("Not enough"), g.gear_swap_problem(press))
	g.players[0]["gold"] = 1000
	check("with cogs it is allowed", g.gear_swap_problem(press) == "")
	# crew it fully (3), swap to big: the rate changes, the building idles during the swap
	for u in g.workers(0):
		u.cmd_gather(press)
	U.step(g, 8.0)
	var crew0 := press.working_crew()
	check("Winders wind the small press", crew0 >= 1, "%d" % crew0)
	var gold0 := int(g.players[0]["gold"])
	check("swap_gear starts a swap", g.swap_gear(press) == "" and press.gear_swap_t > 0.0 and press.gear_swap_to == true)
	check("it cost the swap price", int(g.players[0]["gold"]) == gold0 - cost, "%d -> %d" % [gold0, int(g.players[0]["gold"])])
	check("a second swap while swapping is refused", g.gear_swap_problem(press) != "")
	check("while swapping the building does not work (speed 0, no income)", net.speed_mult(press) == 0.0 and press.press_rate() == 0.0)
	U.step(g, float(Defs.GEAR["swap_time"]) * 0.5)
	check("halfway: still the old size in the graph, swapping", press.gear_swap_t > 0.0 and absf(GearNet.b_r(press) - r_small) < 0.01)
	U.step(g, float(Defs.GEAR["swap_time"]) * 0.5 + 0.3)
	check("done: the ring is BIG now (bigger radius)", press.gear_big and press.gear_swap_t < 0.0 and GearNet.b_r(press) > r_small * 1.3, "%.0f -> %.0f px" % [r_small, GearNet.b_r(press)])
	check("the crew cap is 6 now", press.crew_max() == 6)
	net.solve()
	check("it is still connected to the field after growing", net.linked.has(press))
	# back to small with a big crew: the extra Winders are let go
	var extra: Array = []
	for i in 5:
		var w: Unit = g._add_unit("winder", 0, press.center() + Vector2(-50 + i * 20, 70))
		extra.append(w)
		w.cmd_gather(press)
	U.step(g, 6.0)
	var crew_big := press.crew.size()
	check("big press holds more than 3 Winders", crew_big > 3, "%d" % crew_big)
	g.swap_gear(press)
	U.step(g, float(Defs.GEAR["swap_time"]) + 0.5)
	check("back to the small gear", not press.gear_big and press.crew_max() == 3)
	U.step(g, 1.0)
	check("the extra Winders were let go (crew <= 3)", press.crew.size() <= 3, "%d" % press.crew.size())
	# the card button exists for a building and the HUD lists BIG GEAR / SMALL GEAR
	check("the ring radius is the small one again", absf(GearNet.b_r(press) - r_small) < 0.01)
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
