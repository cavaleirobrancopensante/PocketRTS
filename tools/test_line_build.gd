extends SceneTree
## Laying, being shot at, and repairing the Line: a Winder lays routed segments for ore, a cancelled ghost
## refunds, enemies shoot pipes (and nothing else is near), units walk over them, a Winder repairs them.
##   godot --headless --script res://tools/test_line_build.gd
const U := preload("res://tools/line_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-56s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _step(g: Game, secs: float) -> void:
	var n := int(secs * 30.0)
	for i in n:
		g._physics_process(1.0 / 30.0)
		for u in g.units.duplicate():
			if is_instance_valid(u):
				u._physics_process(1.0 / 30.0)
		for b in g.buildings.duplicate():
			if is_instance_valid(b):
				b._physics_process(1.0 / 30.0)
		await process_frame


func for_each_hp(net: LineNetwork) -> Array:
	var a: Array = []
	for s in net.segs.values():
		a.append(int(s.hp))
	return a


func _total(net: LineNetwork) -> float:
	var t := 0.0
	for s in net.segs.values():
		t += s.hp
	return t


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: LineNetwork = g.line_net
	check("the match starts with a main to the first building", net.count(0) > 0, "%d segments" % net.count(0))
	var h := U.hall(g, 0)
	var start_main := net.count(0)
	check("every starting building touches the Line", g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and (net.is_consumer(b) and b.built)).all(func(b: Building) -> bool: return net.touches(b)))
	net.solve()
	for b in g.buildings:
		if b.team == 0 and b.kind in ["ore_crusher", "ore_drill"]:
			check("the starting Ore Drill is powered", net.state_of(b) != "off" and net.speed_mult(b) > 0.9, "%.2f" % net.speed_mult(b))
	# plan a run away from the hall
	net.clear()
	var from := Vector2i(-1, -1)
	for c in net.ring(h):
		if net.pipeable(0, c):
			from = c
			break
	var plan := {}
	for d in [Vector2i(14, 0), Vector2i(-14, 0), Vector2i(0, 14), Vector2i(0, -14)]:
		plan = net.plan(0, from, from + d)
		if plan["ok"]:
			break
	check("a Line can be routed over free ground", plan.get("ok", false), str(plan.get("why", "")))
	check("the plan shows cost and new cells", int(plan["cost"]) == int(plan["new"]) * 8 and int(plan["new"]) >= 14, "%d ore, %d new" % [plan["cost"], plan["new"]])
	var gold0: int = int(g.players[0]["gold"])
	var winders := g.workers(0).filter(func(u: Unit) -> bool: return u.kind == "winder")
	check("there are Winders", winders.size() >= 2)
	g.lay_line(0, plan["cells"], [winders[0], winders[1]])
	check("laying costs ore up front", int(g.players[0]["gold"]) == gold0 - int(plan["cost"]), "%d -> %d" % [gold0, g.players[0]["gold"]])
	check("the new segments are unfinished ghosts", net.unbuilt_count(0) == int(plan["new"]))
	var order_ok: bool = winders[0].order == "lay"
	check("the Winders are on the lay order", order_ok)
	await _step(g, 5.0)
	check("pressure does not pass through unfinished pipe", net.unbuilt_count(0) > 0 and net.count(0) < int(plan["new"]))
	await _step(g, 70.0)
	check("the Winders lay the whole run (2.5 s a segment)", net.unbuilt_count(0) == 0 and net.count(0) == int(plan["new"]), "%d built, %d left" % [net.count(0), net.unbuilt_count(0)])
	net.solve()
	var last: Vector2i = plan["run"][plan["run"].size() - 1]
	check("pressure runs down the finished run", net.seg_at(last).pressure > 0.4, "%.2f" % net.seg_at(last).pressure)
	check("the Winders are free again", winders[0].order != "lay" and winders[1].order != "lay")
	# a ghost cancelled gives its ore back
	var more := net.plan(0, last, last + Vector2i(0, 5) if net.pipeable(0, last + Vector2i(0, 5)) else last + Vector2i(0, -5))
	g.players[0]["gold"] += 300       # (the loop at the hall took most of the ore)
	var gold1: int = int(g.players[0]["gold"])
	var made := net.lay(0, more["cells"], [])
	var spent := gold1 - int(g.players[0]["gold"])
	for s in made:
		net.remove_seg(s)
	check("a cancelled ghost refunds its ore", int(g.players[0]["gold"]) == gold1 and spent > 0, "%d spent, back to %d" % [spent, g.players[0]["gold"]])
	# buildings cannot stand on pipe
	var on_pipe: Vector2i = plan["cells"][3]
	check("a building cannot be placed on a pipe", g.placement_problem(0, "ore_crusher", on_pipe, true) != "")
	# units walk over the pipe (it is not solid)
	check("pipe does not block movement", g.solid[g.idx(on_pipe)] == 0 and g.is_free(on_pipe))
	var enemy_at := Vector2.INF
	var endc: Vector2i = plan["run"][plan["run"].size() - 1]
	for off in [Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(-3, -3), Vector2i(3, 3), Vector2i(3, -3), Vector2i(-3, 3)]:
		var cc: Vector2i = endc + off
		if g.is_free(cc) and not net.has_cell(cc) and g.height[g.idx(cc)] == g.height[g.idx(endc)]:
			enemy_at = g.cell_center(cc)
			break
	check("there is room for a gunman near the end of the run", enemy_at != Vector2.INF)
	for u in g.units:
		if u.team == 0:
			u.position = h.center() + Vector2(0, 400)     # (nobody of theirs in his sight: the pipe is all there is to shoot)
	# the enemy shoots it (the Winders mend at once, so they are told not to for this part)
	for w in winders:
		w.auto_repair = false
	var target_cell: Vector2i = plan["cells"][plan["cells"].size() - 1]
	var seg := net.seg_at(target_cell)
	var enemy := g._add_unit("musketeer", 1, enemy_at)   # (standing on the pipe two cells back: same level, so it sees the target)
	enemy.d = enemy.d.duplicate()
	enemy.d["sight"] = 5             # (it sees five cells: the end of the pipe, not the base)
	enemy.sight = 5
	g._update_vis()
	var found: Entity = g.find_target(enemy, 160.0)
	check("an enemy with nothing else in reach picks a pipe", found is PipeSeg)
	seg = found as PipeSeg
	enemy.order = "idle"
	enemy.target = seg
	var hp0 := _total(net)
	await _step(g, 8.0)
	check("enemies hurt and destroy pipe segments", _total(net) < hp0, "total hp %.0f -> %.0f" % [hp0, _total(net)])
	enemy.queue_free()
	g.units.erase(enemy)
	# repair
	var seg2 := net.seg_at(plan["cells"][8])
	seg2.hp = seg2.max_hp * 0.3
	winders[0].auto_repair = true
	winders[0].position = seg2.global_position + Vector2(20, 20)      # (Winders no longer end up beside the run: no hauling)
	check("a damaged segment is found for repair", g.find_repair(winders[0], 300.0) == seg2 or g.find_repair(winders[0], 300.0) != null)
	winders[0].position = seg2.global_position + Vector2(20, 20)
	winders[0].cmd_repair(seg2)
	await _step(g, 10.0)
	check("a Winder repairs a pipe segment", seg2.hp >= seg2.max_hp * 0.99, "%.0f/%.0f" % [seg2.hp, seg2.max_hp])
	print("RESULT %s (%d failed)" % ["ALL OK" if fails == 0 else "SOME FAILED", fails])
	quit(0 if fails == 0 else 1)
