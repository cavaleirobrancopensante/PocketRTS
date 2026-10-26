extends SceneTree
## The gear field's connection graph, the placement rule and what a lost building does to the buildings behind it.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_graph.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
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
	U.step(g, 1.0)
	check("the Clocktower is a root: connected", net.is_linked(tower) and net.linked.has(tower))
	var press: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS:
			press = b
	check("the starting Cog Press stands and is linked to the Clocktower", press != null and net.linked.has(press))
	check("the Clocktower's ring is the biggest", GearNet.b_r(tower) > GearNet.ring_r("assembly_works", Vector2i(5, 4), true))
	check("a BIG ring is bigger than a SMALL one", GearNet.ring_r("boiler", Vector2i(4, 4), true) > GearNet.ring_r("boiler", Vector2i(4, 4), false))
	# the placement rule
	var far_cell := tower.cell + Vector2i(30, 0)
	check("far from the field: refused with a reason", g.gear_net.placement_problem(0, "boiler", far_cell) != "", g.gear_net.placement_problem(0, "boiler", far_cell))
	var inside := tower.cell + Vector2i(1, 5)
	check("a ring cutting into the Clocktower's: refused (clash)", g.gear_net.candidate(0, "boiler", inside)["state"] == "clash")
	var spot := U.linked_spot(g, 0, "boiler", tower.cell)
	check("a ring touching the Clocktower's is accepted", spot.x >= 0 and g.placement_problem(0, "boiler", spot) == "", str(spot))
	check("a new Clocktower needs no link (it starts its own field)", g.gear_net.candidate(0, "clocktower", far_cell)["state"] == "tower")
	# a chain: B touches A touches the tower
	var a := U.put(g, 0, "assembly_works", tower.cell + Vector2i(30, 8))
	check("building A placed on a linking spot", a != null)
	if a == null:
		quit(1)
		return
	check("A is connected", net.linked.has(a))
	var cs := U.chain_spot(g, 0, "boiler", a)
	var b2: Building = null
	if cs.x >= 0:
		b2 = g._add_building("boiler", 0, cs, true)
		net.solve()
	check("a building meshing only with A is connected through A", b2 != null and net.linked.has(b2) and net.parent_of.get(b2) == a, "%s parent %s" % [str(cs), (net.parent_of.get(b2).kind if b2 != null and net.parent_of.get(b2) != null else "-")])
	# a building far from everything is not
	var lone := U.put_far(g, 0, "capacitor_works")
	check("a building with no ring touching the field is NOT connected", lone != null and not net.linked.has(lone) and net.speed_mult(lone) == 0.0)
	# its gears are placed from the parent: counter-rotation and a small gear spins faster
	U.step(g, 1.0)
	var p: Building = net.parent_of.get(a)
	var a0: float = net.ang.get(a, 0.0)
	U.step(g, 0.5)
	var a1: float = net.ang.get(a, 0.0)
	var t0: float = net.ang.get(tower, 0.0)
	U.step(g, 0.5)
	var t1: float = net.ang.get(tower, 0.0)
	var a2: float = net.ang.get(a, 0.0)
	check("the gears turn", absf(a2 - a1) > 0.001 and absf(t1 - t0) > 0.001, "%.3f %.3f" % [a2 - a1, t1 - t0])
	var idl: Dictionary = net.idler_of.get(a, {})
	if idl.is_empty():
		check("neighbouring gears counter-rotate", (a2 - a1) * (t1 - t0) < 0.0 if p == tower else true, "parent %s" % (p.kind if p else "none"))
	else:
		# through an idler the two rings turn the same way (two meshes), the idler against both
		check("through an idler the rings turn the same way", (a2 - a1) * (t1 - t0) > 0.0 if p == tower else true, "parent %s" % (p.kind if p else "none"))
	if p == tower:
		var want := float(GearNet.b_n(tower)) / float(GearNet.b_n(a))
		check("a smaller gear spins faster than the big Clocktower ring, by the tooth ratio", want > 1.0 and absf(absf(a2 - a1) / absf(t1 - t0) - want) < 0.03 * want, "%.3f vs %.3f (want x%.2f)" % [a2 - a1, t1 - t0, want])
	# mesh geometry: at every contact point the teeth interlock (a tooth of one in the gap of the other: GearNet.mesh_error)
	if p != null:
		var np := GearNet.b_n(p)
		var nb := GearNet.b_n(a)
		if idl.is_empty():
			var th: float = (GearNet.b_c(a) - GearNet.b_c(p)).angle()
			var e := GearNet.mesh_error(float(net.ang[p]), np, float(net.ang[a]), nb, th)
			check("teeth interlock at the contact point (tooth meets gap)", e < 0.02, "%.3f teeth off" % e)
		else:
			var ip: Vector2 = idl["pos"]
			var ia := float(net.idler_ang[a])
			var e1 := GearNet.mesh_error(float(net.ang[p]), np, ia, int(idl["n"]), (ip - GearNet.b_c(p)).angle())
			var e2 := GearNet.mesh_error(ia, int(idl["n"]), float(net.ang[a]), nb, (GearNet.b_c(a) - ip).angle())
			check("teeth interlock at both of the idler's contact points", e1 < 0.02 and e2 < 0.02, "%.3f %.3f teeth off" % [e1, e2])
			var ri: float = idl["r"]
			check("the idler's pitch circle touches both rings'", absf(ip.distance_to(GearNet.b_c(p)) - GearNet.b_r(p) - ri) < 0.5 and absf(ip.distance_to(GearNet.b_c(a)) - GearNet.b_r(a) - ri) < 0.5)
	# losing the middle link unlinks what hung on it alone
	var chain_end := b2
	a.take_damage(999999.0, null)
	U.step(g, 0.6)
	check("a dead building is no longer linked", not net.linked.has(a))
	check("what hung on it alone is unlinked (its gears stop)", chain_end != null and not net.linked.has(chain_end) and net.speed_mult(chain_end) == 0.0)
	var frozen: float = net.ang.get(chain_end, 0.0)
	U.step(g, 1.0)
	check("an unlinked gear stands still", absf(float(net.ang.get(chain_end, 0.0)) - frozen) < 0.0001)
	# the Clocktower dies: everything stops
	tower.take_damage(999999.0, null)
	U.step(g, 0.6)
	var any := false
	for b in g.buildings:
		if b.team == 0 and not b.dead and net.linked.has(b):
			any = true
	check("with the Clocktower gone nothing is connected", not any)
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
