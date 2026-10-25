extends SceneTree
## The Line's pressure solver: distance falloff, a Pressure Relay, a cut Line, shared load, the speed rules.
##   godot --headless --script res://tools/test_line_pressure.gd
const U := preload("res://tools/line_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-52s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: LineNetwork = g.line_net
	var cells := U.run_from_hall(g, 0, 30)
	check("a 30-segment run could be laid", cells.size() == 30)
	if cells.size() < 30:
		quit(1)
		return
	net.solve()
	var p0: float = net.seg_at(cells[0]).pressure
	var p10: float = net.seg_at(cells[10]).pressure
	var p20: float = net.seg_at(cells[20]).pressure
	check("segment beside the Clocktower is at full pressure", absf(p0 - 1.0) < 0.001, "%.3f" % p0)
	check("pressure falls 2.5%% a segment (10: 0.75)", absf(p10 - 0.75) < 0.01, "%.3f" % p10)
	check("pressure falls 2.5%% a segment (20: 0.50)", absf(p20 - 0.50) < 0.01, "%.3f" % p20)
	# a consumer at the far end works slower than one at the near end
	var near := U.building_beside(g, 0, "assembly_works", cells[1])
	net.solve()
	check("a workshop beside the Line is connected", net.state_of(near) != "off", net.state_of(near))
	var far := U.building_beside(g, 0, "capacitor_works", cells[22])
	net.solve()
	check("work speed follows pressure (far < near)", net.speed_mult(far) < net.speed_mult(near), "%.2f < %.2f" % [net.speed_mult(far), net.speed_mult(near)])
	check("the near workshop runs at full speed", net.speed_mult(near) > 0.99, "%.2f" % net.speed_mult(near))
	# no Line: no work
	var lone: Building = null
	for dy in range(-16, 17, 4):
		for dx in range(-25, 26, 4):
			var c: Vector2i = cells[0] + Vector2i(dx, dy)
			if lone == null and U._free(g, c, Vector2i(3, 3)):
				var cand := g._add_building("ore_crusher", 0, c, true)
				if net.touches(cand):
					g.buildings.erase(cand)
					cand.queue_free()
				else:
					lone = cand
	net.solve()
	check("a building with no Line beside it does not work", lone != null and net.speed_mult(lone) == 0.0 and net.state_of(lone) == "off")
	# the shared load: pile consumers on a Clocktower-only Line (supply 40)
	for b in g.buildings.duplicate():
		if b.team == 0 and b != U.hall(g, 0) and (net.is_consumer(b) or net.is_source(b)):
			g._remove_quietly(b)
	var made := 0
	for i in range(1, 12):
		if made >= 5:
			break
		var b := U.building_beside(g, 0, "engine_hall" if made % 2 == 0 else "assembly_works", cells[i * 2])
		if b != null:
			made += 1
	net.solve()
	var st: Dictionary = net.stats_of(0)
	check("load is shared: draw above supply cuts every pressure", float(st["draw"]) > float(st["supply"]) and float(st["share"]) < 1.0, "supply %.0f draw %.0f share %.2f" % [st["supply"], st["draw"], st["share"]])
	var p1: float = net.seg_at(cells[0]).pressure
	check("the first segment loses the same share", absf(p1 - float(st["share"])) < 0.01, "%.3f" % p1)
	# a Boiler on the Line adds supply
	var boiler: Building = null
	for i in range(3, 28):
		boiler = U.building_beside(g, 0, "boiler", cells[i])
		if boiler != null:
			break
	net.solve()
	var st2: Dictionary = net.stats_of(0)
	check("a Boiler touching the Line adds supply (+30)", boiler != null and absf(float(st2["supply"]) - float(st["supply"]) - 30.0) < 0.1, "%.0f -> %.0f boiler=%s" % [st["supply"], st2["supply"], str(boiler)])
	# the relay
	for b in g.buildings.duplicate():
		if b.team == 0 and b != U.hall(g, 0) and b.kind != "clocktower":
			g._remove_quietly(b)
	net.solve()
	var before: float = net.seg_at(cells[28]).pressure
	var relay := U.building_beside(g, 0, "pressure_relay", cells[24])
	net.solve()
	var after: float = net.seg_at(cells[28]).pressure
	check("a Pressure Relay raises the pressure beyond it", relay != null and after > before + 0.25, "%.2f -> %.2f" % [before, after])
	check("the relay's output is capped (0.9 at its side)", net.seg_at(cells[24]).pressure <= 0.9 + 0.001)
	# a lone relay with nothing feeding it does nothing
	var g2 := U.make(root, ["clockwork", "crown"])
	await process_frame
	await process_frame
	g2.line_net.clear()
	var c2 := U.run_from_hall(g2, 0, 6)
	g2.line_net.clear()
	for c in c2:
		g2.line_net.add_built(0, c)
	# (cut the run from the hall by removing the first segments' neighbours: a relay far from any source)
	var island := Vector2i(c2[3].x, c2[3].y)
	g2.line_net.remove_seg(g2.line_net.seg_at(c2[1]), true)
	g2.line_net.remove_seg(g2.line_net.seg_at(c2[2]), true)
	var rl := U.building_beside(g2, 0, "pressure_relay", c2[4])
	g2.line_net.solve()
	check("a Relay with no pressure coming in stays dead", rl != null and g2.line_net.seg_at(c2[5]).pressure == 0.0)
	# cutting the Line
	var g3 := U.make(root)
	await process_frame
	await process_frame
	var c3 := U.run_from_hall(g3, 0, 20)
	g3.line_net.solve()
	var downstream := g3.line_net.seg_at(c3[15]).pressure
	g3.line_net.seg_at(c3[8]).take_damage(99999.0, null)
	g3.line_net.solve()
	check("before the cut the far side had pressure", downstream > 0.3, "%.2f" % downstream)
	check("a cut Line: everything downstream is zero", g3.line_net.seg_at(c3[15]).pressure == 0.0 and g3.line_net.seg_at(c3[9]).pressure == 0.0)
	check("upstream of the cut is unaffected", g3.line_net.seg_at(c3[5]).pressure > 0.8)
	print("RESULT %s (%d failed)" % ["ALL OK" if fails == 0 else "SOME FAILED", fails])
	quit(0 if fails == 0 else 1)
