extends SceneTree
## The gear field's MESH RULE and IDLERS (scripts/gear.gd mesh_phase / mesh_error / idler_for), and the Clockwork Lab's
## showcase (two Cog Presses and a Mainspring meshing round the Clocktower).
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_mesh.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-62s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


## The teeth of two rings at their contact point: sampled straight from the tooth positions (not through mesh_error), the
## nearest tooth of A to the contact and the nearest of B sit half a pitch apart along the rims.
func contact_offset(pa: float, na: int, pb: float, nb: int, phi: float) -> float:
	var p := float(Defs.GEAR["pitch"])
	var best_a := INF
	for k in na:
		var a := pa + TAU * float(k) / float(na)
		var off := angle_difference(phi, a) * GearNet.radius_of_teeth(na)      # arc from the contact to this tooth of A
		if absf(off) < absf(best_a):
			best_a = off
	var best_b := INF
	for k in nb:
		var b := pb + TAU * float(k) / float(nb)
		# B's rim runs the other way at the contact: its arc offset counts in the opposite sense
		var off := -angle_difference(phi + PI, b) * GearNet.radius_of_teeth(nb)
		if absf(off) < absf(best_b):
			best_b = off
	return fposmod(best_a - best_b, p)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var p := float(Defs.GEAR["pitch"])
	# 1. two meshing rings, driven over time: a tooth of one always faces a gap of the other at the contact
	var na := 33
	var nb := 19
	var ok := true
	var worst := 0.0
	for phi in [0.3, 1.9, -2.4, PI]:
		for i in 40:
			var pa := 0.37 + 0.11 * float(i) + float(phi)
			var pb := GearNet.mesh_phase(pa, na, phi, nb)
			var off := contact_offset(pa, na, pb, nb, phi)
			var e := absf(off - p * 0.5)
			worst = maxf(worst, e)
			if e > 0.05 * p or GearNet.mesh_error(pa, na, pb, nb, phi) > 0.01:
				ok = false
	check("mesh rule: tooth opposite gap at the contact, at all times", ok, "worst %.3f px off half a pitch" % worst)
	# the driven ring counter-rotates at the tooth ratio
	var pb0 := GearNet.mesh_phase(1.0, na, 0.5, nb)
	var pb1 := GearNet.mesh_phase(1.01, na, 0.5, nb)
	var dd := angle_difference(pb0, pb1)
	check("the driven ring turns the other way, na/nb as fast", dd < 0.0 and absf(absf(dd) / 0.01 - float(na) / float(nb)) < 0.01, "%.4f" % dd)
	# a phase that is half a tooth off is caught
	var bad := GearNet.mesh_phase(1.0, na, 0.5, nb) + PI / float(nb)
	check("half a tooth off reads as tooth on tooth", GearNet.mesh_error(1.0, na, bad, nb, 0.5) > 0.45)
	# 2. idlers: no idler when the rings touch, one that meshes both across a gap
	var ra := GearNet.radius_of_teeth(na)
	var rb := GearNet.radius_of_teeth(nb)
	var ca := Vector2(100, 100)
	check("touching rings mesh directly (no idler)", GearNet.idler_for(ca, ra, ca + Vector2(ra + rb + 1.0, 0), rb).is_empty())
	var all_ok := true
	var detail := ""
	for gap in [6.0, 20.0, 40.0, 63.0]:
		for dir in [0.0, 0.8, 2.5, -1.2]:
			var cb: Vector2 = ca + Vector2.from_angle(dir) * (ra + rb + gap)
			var idl := GearNet.idler_for(ca, ra, cb, rb)
			if idl.is_empty():
				all_ok = false
				detail = "none at gap %.0f" % gap
				continue
			var ip: Vector2 = idl["pos"]
			var ri: float = idl["r"]
			var n: int = idl["n"]
			var touch_a := absf(ip.distance_to(ca) - ra - ri)
			var touch_b := absf(ip.distance_to(cb) - rb - ri)
			if n < int(Defs.GEAR["idler_min"]) or absf(ri - GearNet.radius_of_teeth(n)) > 0.01 or touch_a > 0.1 or touch_b > 0.1:
				all_ok = false
				detail = "gap %.0f: n %d, off %.2f %.2f" % [gap, n, touch_a, touch_b]
			# and its teeth mesh both, driven as in the game
			var pa := 0.7 + float(dir)
			var ia := GearNet.mesh_phase(pa, na, (ip - ca).angle(), n)
			var pbb := GearNet.mesh_phase(ia, n, (cb - ip).angle(), nb)
			if GearNet.mesh_error(pa, na, ia, n, (ip - ca).angle()) > 0.01 or GearNet.mesh_error(ia, n, pbb, nb, (cb - ip).angle()) > 0.01:
				all_ok = false
				detail = "gap %.0f: teeth off" % gap
	check("an idler's pitch circle touches both rings and its teeth mesh both", all_ok, detail)
	var wide := GearNet.idler_for(ca, ra, ca + Vector2(ra + rb + 90.0, 0), rb)
	check("a wider gap gets a bigger idler", int(wide["n"]) > int(Defs.GEAR["idler_min"]), "n %d" % int(wide["n"]))
	# it keeps clear of a third ring when it can
	var cb2 := ca + Vector2(ra + rb + 10.0, 0)
	var free_side := GearNet.idler_for(ca, ra, cb2, rb)
	var blocker: Vector2 = free_side["pos"]
	var other_side := GearNet.idler_for(ca, ra, cb2, rb, [[blocker, 30.0]])
	check("the idler goes to the side away from another ring", Vector2(other_side["pos"]).distance_to(blocker) > 20.0)
	# 3. in a game: linked rings with idlers keep meshing while they turn
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: GearNet = g.gear_net
	var tower := U.hall(g, 0)
	for i in 3:
		U.put(g, 0, "mainspring", tower.cell + Vector2i([-12, 12, 0][i], [6, 6, 12][i]))
	U.step(g, 2.0)
	var n_links := 0
	var n_idlers := 0
	var max_e := 0.0
	for b in net.order:
		var par: Building = net.parent_of.get(b)
		if par == null:
			continue
		n_links += 1
		var idl: Dictionary = net.idler_of.get(b, {})
		if idl.is_empty():
			max_e = maxf(max_e, GearNet.mesh_error(net.ang[par], GearNet.b_n(par), net.ang[b], GearNet.b_n(b), (GearNet.b_c(b) - GearNet.b_c(par)).angle()))
		else:
			n_idlers += 1
			var ip: Vector2 = idl["pos"]
			max_e = maxf(max_e, GearNet.mesh_error(net.ang[par], GearNet.b_n(par), net.idler_ang[b], int(idl["n"]), (ip - GearNet.b_c(par)).angle()))
			max_e = maxf(max_e, GearNet.mesh_error(net.idler_ang[b], int(idl["n"]), net.ang[b], GearNet.b_n(b), (GearNet.b_c(b) - ip).angle()))
	check("every link in a game meshes exactly while turning", n_links >= 3 and max_e < 0.01, "%d links, %d idlers, worst %.4f teeth" % [n_links, n_idlers, max_e])
	check("the Mainspring is in the Clockwork build list", Defs.build_list("clockwork").has("mainspring"))
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
