extends SceneTree
## The ANIMATION VIEWER page builds for every unit and shows each strip's real frame count.
##   godot --headless --fixed-fps 30 --script res://tools/test_anim_viewer.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL  " + what)
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var av: AnimViewer = main.show_anim_viewer()
	await process_frame
	var units := 0
	var strips := 0
	for a in ArtData.UNITS:
		av.select_art(a)
		units += 1
		check(av.art == a, "%s selected" % a)
		var anims := AnimViewer.anims_of(a)
		check(not anims.is_empty(), "%s has animations" % a)
		for nm in anims:
			av.select_anim(nm)
			for d in AnimViewer.SHOW_DIRS:
				var want: int = ArtData.UNITS[a]["frames"].get(nm + "_" + AnimViewer.MIRROR.get(d, d), 0)
				av.select_dir(d)
				if want == 0:
					continue
				strips += 1
				check(av.dir == d and av.frame_count() == want, "%s %s %s frames %d == %d" % [a, nm, d, av.frame_count(), want])
				check(av._frame_lbl.text.ends_with("/ %d" % want), "%s %s %s label '%s'" % [a, nm, d, av._frame_lbl.text])
				var tex := Game.tex("res://assets/units/%s/%s_%s.png" % [a, nm, AnimViewer.MIRROR.get(d, d)]) as Texture2D
				check(tex != null and tex.get_width() % want == 0, "%s %s %s strip width divides" % [a, nm, d])
				check(AnimViewer.fps_for(a, nm, want) > 0.0, "%s %s fps" % [a, nm])
	# stepping and flagging
	av.select_art("musketeer")
	av.select_anim("walk")
	av.select_dir("e")
	av.step(1)
	check(av.paused and av.frame == 1, "step goes to frame 1 and pauses")
	av.step(-2)
	check(av.frame == av.frame_count() - 1, "step back wraps")
	av.flag_frame()
	check(av.flagged.size() == 1 and av.flagged[0].begins_with("musketeer / walk / e / frame"), "flag line: %s" % str(av.flagged))
	# quick switching: direction around the compass, pose list, unit list, needs-art filter
	av.select_art("labourer")
	av.select_anim("walk")
	av.select_dir("e")
	av.cycle_dir(1)
	check(av.dir == "ne", "dir right of e is ne (got %s)" % av.dir)
	av.cycle_dir(-2)
	check(av.dir == "se", "dir two left of ne is se (got %s)" % av.dir)
	var names := AnimViewer.anims_of("labourer").keys()
	av.cycle_anim(1)
	check(av.anim != "walk" and names.has(av.anim), "pose down from walk: %s" % av.anim)
	av.cycle_anim(-1)
	check(av.anim == "walk", "pose up returns to walk")
	var a0 := av.art
	av.cycle_art(1)
	check(av.art != a0, "unit next changes the unit")
	av.cycle_art(-1)
	check(av.art == a0, "unit previous returns")
	av.needs_only = true
	av._fill_units()
	av.cycle_art(1)
	check(AnimViewer.NEEDS_ART.has(av.art), "filtered unit cycling stays in the needs-art list: %s" % av.art)
	for k in AnimViewer.NEEDS_ART:
		check(ArtData.UNITS.has(k), "needs-art key %s is a real art" % k)
	av.needs_only = false
	av.grid_mode = true
	av._refresh()
	await process_frame
	print("%d units, %d strips checked" % [units, strips])
	print("PASS  anim viewer" if fails == 0 else "FAIL  %d problems" % fails)
	quit(fails)
