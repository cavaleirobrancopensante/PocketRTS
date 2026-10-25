extends SceneTree
## Turnarounds, couplings and two tracks on the Clockwork Line: a rail stub that ends at a Drill or the Clocktower
## gets a loop (Line.plan) that trains drive round instead of backing up; a dead end is a reverse point (the fallback);
## wagons keep the coupling distance round bends; trains keep to the right of their way and head-on trains pass.
##   godot --headless --fixed-fps 30 --script res://tools/test_line_loop.gd
const U := preload("res://tools/line_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _step(g: Game, secs: float, hook := Callable()) -> void:
	var n := int(secs * 30.0)
	for i in n:
		if hook.is_valid():
			hook.call()
		g._physics_process(1.0 / 30.0)
		if i % 10 == 0:
			await process_frame


## Hall, a run of about `dist` cells and a Drill at its end; `with_loops`: lay it through Line.plan (loops) or as a bare run.
func _setup(g: Game, dist: int, with_loops: bool) -> Dictionary:
	var net: LineNetwork = g.line_net
	net.clear()
	for b in g.buildings.duplicate():
		if b.team == 0 and b.kind in ["ore_drill", "ore_crusher"]:
			g._remove_quietly(b)
	var h := U.hall(g, 0)
	for d in [Vector2i(dist, 0), Vector2i(-dist, 0), Vector2i(0, dist), Vector2i(0, -dist), Vector2i(dist, dist), Vector2i(-dist, dist)]:
		for c in net.ring(h):
			if not net.pipeable(0, c):
				continue
			var target: Vector2i = c + d
			if not net.pipeable(0, target):
				continue
			# a Drill beside the target cell, off the run's own cells
			var drill := U.building_beside(g, 0, "ore_drill", target)
			if drill == null:
				continue
			var p := net.plan(0, c, target)
			if not p["ok"]:
				g._remove_quietly(drill)
				continue
			var cells: Array = p["cells"] if with_loops else p["run"]
			for q in cells:
				net.add_built(0, q)
			net.solve()
			return {"plan": p, "drill": drill, "hall": h, "cells": cells}
	return {}


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: LineNetwork = g.line_net
	var rails: Rails = net.rails
	net.enforce = false
	g.players[0]["gold"] = 5000
	# 1. the plan carries loops and their cost
	var cyc := LineNetwork.cycle_cells_of({Vector2i(0, 0): 1, Vector2i(1, 0): 1, Vector2i(1, 1): 1, Vector2i(0, 1): 1, Vector2i(5, 5): 1, Vector2i(5, 6): 1})
	check("cycle finder: a 2x2 square is a cycle, a stub is not", cyc.size() == 4 and not cyc.has(Vector2i(5, 5)))
	var S := _setup(g, 14, true)
	check("a run to a Drill is planned", not S.is_empty())
	if S.is_empty():
		quit(1)
		return
	var p: Dictionary = S["plan"]
	check("the plan has loops for both ends (Clocktower and Drill)", (p["loop"] as Array).size() >= 16, "%d loop cells" % (p["loop"] as Array).size())
	check("the loop is on top of the run, in the cost", int(p["loop_new"]) > 0 and int(p["cost"]) == int(p["new"]) * 8, "%d new, %d of them loop, %d ore" % [p["new"], p["loop_new"], p["cost"]])
	check("both buildings have a loop of rail round or beside them", net.has_loop(0, S["drill"]) and net.has_loop(0, S["hall"]))
	check("a second plan to the same Drill adds no loop", int(net.plan(0, (p["run"] as Array)[0], (p["run"] as Array)[(p["run"] as Array).size() - 1])["loop_new"]) == 0)
	# 2. a train turns round on the loop and never backs up
	var tr: Train = rails.add_train(0, "ore")
	S["drill"].stock = 160.0
	var keep := func() -> void:
		S["drill"].stock = maxf(S["drill"].stock, 120.0)
		U.hall(g, 0).lode = 99999.0
	rails.delivered[0] = 0.0
	await _step(g, 70.0, keep)
	check("with loops a train delivers ore", float(rails.delivered.get(0, 0.0)) >= 80.0, "%.0f ore" % float(rails.delivered.get(0, 0.0)))
	check("... and never backs out of a dead end", tr.turns == 0, "%d turns" % tr.turns)
	# 3. the train keeps to the right of its way
	var st := {"lane_ok": true, "seen": 0, "worst": 0.0, "min": 999.0, "samples": 0, "off": 0.0}
	await _step(g, 20.0, func() -> void:
		keep.call()
		if tr.dir != Vector2i.ZERO and tr.idx > 0 and tr.idx < tr.path.size() - 1:
			var d := Vector2(tr.dir)
			var c: Vector2 = g.cell_center(tr.path[tr.idx]).lerp(g.cell_center(tr.path[tr.idx + 1]), tr.frac)
			if tr.path[tr.idx] - tr.path[tr.idx - 1] == tr.dir and tr.path[tr.idx + 1] - tr.path[tr.idx] == tr.dir:
				st["seen"] += 1
				if (tr.position - c).dot(Vector2(-d.y, d.x)) < 3.0:
					st["lane_ok"] = false)
	check("a train drives on the right of its way (lane offset)", st["lane_ok"] and st["seen"] > 20, "%d samples" % st["seen"])
	# 4. wagons keep the coupling distance round bends; and stay on the track
	await _step(g, 60.0, func() -> void:
		keep.call()
		var lay: Array = tr.layout()
		if lay.size() < 3 or tr.speed_now <= 0.0:
			return
		st["samples"] += 1
		var kinds := ["loco", "car", "car"]
		for i in range(1, lay.size()):
			var dv: Vector2 = lay[i][0] - lay[i - 1][0]
			var hi := maxf(Train.coupling(kinds[i - 1], "car", true), Train.coupling(kinds[i - 1], "car", false))
			var lo2 := minf(Train.coupling(kinds[i - 1], "car", true), Train.coupling(kinds[i - 1], "car", false))
			st["worst"] = maxf(st["worst"], dv.length() - hi)
			st["min"] = minf(st["min"], dv.length() / lo2)
			var wp: Vector2 = tr.position + lay[i][0]
			var cc := g.cell_of(wp)
			var near := false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if net.segs.has(cc + Vector2i(dx, dy)):
						near = true
			if not near:
				st["off"] += 1.0)
	check("wagons never trail more than a hand from the vehicle ahead", st["samples"] > 50 and st["worst"] < 3.0, "%d samples, worst +%.1f px over" % [st["samples"], st["worst"]])
	check("... and never ride up into it (at least 85% of the coupling)", st["min"] > 0.85, "closest %.2f of it" % st["min"])
	check("the wagons stay on the track round bends", st["off"] < 3.0, "%.0f off-track samples" % st["off"])
	# 5. a dead end is a reverse point: no loops, the train backs out and still delivers
	for t2 in rails.trains.duplicate():
		t2.die()
	S = _setup(g, 12, false)
	check("a bare run to a Drill (no loop)", not S.is_empty() and not net.has_loop(0, S["drill"]))
	var t3: Train = rails.add_train(0, "ore")
	rails.delivered[0] = 0.0
	S["drill"].stock = 160.0
	var keep3 := func() -> void:
		S["drill"].stock = maxf(S["drill"].stock, 120.0)
		U.hall(g, 0).lode = 99999.0
	await _step(g, 80.0, keep3)
	check("at a dead end the train reverses (and does not deadlock)", t3.turns >= 2 and float(rails.delivered.get(0, 0.0)) >= 80.0, "%d turns, %.0f ore" % [t3.turns, float(rails.delivered.get(0, 0.0))])
	# 6. head-on trains pass: two trains on one bare run, going opposite ways
	for t2 in rails.trains.duplicate():
		t2.die()
	var a: Train = rails.add_train(0, "ore")
	var b: Train = rails.add_train(0, "ore")
	var cells: Array = S["cells"]
	# put b at the far end, both with a job at the opposite end
	b.cell = cells[cells.size() - 1]
	b.path = [b.cell]
	b.position = g.cell_center(b.cell)
	b.heading = Vector2i.ZERO
	a.cargo = 1.0              # a heads for the hall's access cell... both just shuttle; track their lanes
	var passed := false
	var lanes := [0.0, 0.0]
	b.state = "to_hall"
	b._go(rails.access_cells(0, U.hall(g, 0)), "to_hall")
	b.cargo = 1.0
	a._go([b.cell], "to_pickup")
	a.state = "to_pickup"
	var seen2 := {"a_far": false, "b_hall": false, "met": false}
	await _step(g, 30.0, func() -> void:
		if a.cell == cells[cells.size() - 1]:
			seen2["a_far"] = true
		if b.state in ["unloading", "idle"] and b.cargo <= 0.0 or b.state == "unloading":
			seen2["b_hall"] = true
		if a.position.distance_to(b.position) < 40.0:
			seen2["met"] = true)
	var far: Vector2i = cells[cells.size() - 1]
	check("head-on trains pass: the first reached the far end", seen2["a_far"] and seen2["met"], "a at %s (%s), far end %s" % [a.cell, a.state, far])
	check("... and the second reached the hall", seen2["b_hall"], "b %s" % b.state)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
