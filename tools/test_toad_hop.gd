extends SceneTree
## THE MIST TOAD'S HOP (scripts/toad_hop.gd, tools/import_toad_hop.py): its walk is a 6-frame hop in all five views; the
## frames follow the ground covered (one hop per ToadHop.HOP px); the drawn toad holds still on the ground frames
## (crouched, pushing off, landed) and covers the hop in the air; the shift stays small, averages zero, and eases back
## when it stops; idle / tongue / fog / death keep their strips.
##   godot --headless --fixed-fps 30 --script res://tools/test_toad_hop.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# ---- the art
	var art: Dictionary = ArtData.UNITS["mist_toad"]
	var fr: Dictionary = art["frames"]
	for d in ["s", "se", "e", "ne", "n"]:
		check("walk_%s is a 6-frame hop" % d, int(fr.get("walk_" + d, 0)) == 6, str(fr.get("walk_" + d, 0)))
		var tex: Texture2D = load("res://assets/units/mist_toad/walk_%s.png" % d)
		check("walk_%s strip size" % d, tex != null and tex.get_width() == 6 * int(art["cell"].x) and tex.get_height() == int(art["cell"].y))
	for k in ["idle_s", "idle_n", "idle_e", "idle_se", "tongue_e", "fog_e", "death_e"]:
		check("%s kept" % k, fr.has(k))
	# ---- the hop's sums
	var acc := 0.0
	for s in ToadHop.SHARE:
		acc += float(s)
	check("frame shares sum to 1", absf(acc - 1.0) < 0.001, str(acc))
	var mean := 0.0
	var worst := 0.0
	for i in 1000:
		var l := ToadHop.lead(i / 1000.0)
		mean += l / 1000.0
		worst = maxf(worst, absf(l))
	check("the shift averages zero over a hop", absf(mean) < 0.1, "%.2f" % mean)
	check("the shift stays within 9 px", worst <= 9.0, "%.1f" % worst)
	check("the shift is continuous at the loop", absf(ToadHop.lead(0.0) - ToadHop.lead(0.9999)) < 0.1)
	# ---- in a game: a toad walking east, watched
	var g := U.make(root, ["brood", "crown"], "ashford_crossing", true)
	await process_frame
	await process_frame
	g.reveal = true
	var hall := U.hall(g, 0)
	var start := hall.center() + Vector2(-120, 140)
	var toad: Unit = g._add_unit("mist_toad", 0, start)
	toad.auto_work = false
	g.camera.position = start + Vector2(120, 0)
	g.camera.zoom = Vector2(2.0, 2.0)
	await process_frame
	toad.cmd_move(start + Vector2(260, 0))
	var seen := {}
	var planted_bad := 0
	var planted_n := 0
	var prev_f := -1
	var prev_draw := Vector2.INF
	var max_off := 0.0
	var walked0 := toad.position
	var frames0 := 0
	for i in 150:
		await process_frame
		if toad.anim != "walk":
			continue
		var f := toad.sprite.frame
		seen[f] = true
		var drawn := toad.position + toad.sprite.position
		max_off = maxf(max_off, toad.sprite.position.length())
		if f == prev_f and (f == 0 or f == 1 or f == 5) and prev_draw != Vector2.INF:
			planted_n += 1
			if drawn.distance_to(prev_draw) > 1.5:
				planted_bad += 1
		if f != prev_f:
			frames0 += 1
		prev_f = f
		prev_draw = drawn
	var walked := toad.position.distance_to(walked0)
	check("it walks with the walk strip", seen.size() > 0, "anim %s" % toad.anim)
	check("every hop frame shows", seen.size() == 6, str(seen.keys()))
	check("the feet stay put on the ground frames", planted_n > 5 and planted_bad <= planted_n / 10, "%d of %d ticks moved" % [planted_bad, planted_n])
	check("the drawn toad stays near the unit", max_off <= 9.5, "%.1f px" % max_off)
	check("hops follow the ground (%.0f px walked)" % walked, frames0 >= int(walked / ToadHop.HOP * 6.0 * 0.6), "%d frame changes" % frames0)
	# ---- stopped: back on its spot
	toad.cmd_stop() if toad.has_method("cmd_stop") else toad.cmd_move(toad.position)
	for i in 30:
		await process_frame
	check("stopped, it eases back to its spot", toad.sprite.position.length() < 0.5 and toad.anim != "walk", "%s %s" % [toad.anim, toad.sprite.position])
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
