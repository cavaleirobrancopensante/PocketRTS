extends SceneTree
## A unit's OWN west views (Unit.WEST_OF; owner, 2026-10-27: the Clock Soldier's sword is always in its right hand, so its
## west views cannot be the east ones mirrored). A Clock Soldier facing SW, W and NW draws its own sw / w / nw strip
## UNFLIPPED, in every animation it has (idle, walk, attack, death), with the east strip's frame count; facing SE, E and NE
## it draws the east strips as before. A unit with no west files (the Jack, a Musketeer) still mirrors SE, E and NE.
## Per-view tables keyed by the east views read the east twin and mirror it (Unit.view_entry / view_mirror), and the
## animation viewer shows the own strips unflipped (no "*").
##   godot --headless --fixed-fps 30 --script res://tools/test_west_views.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0

# octant (facing angle / 45 degrees, screen y down) -> the compass view
const VIEW := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _face(u: Unit, o: int, a: String) -> void:
	u.facing = Vector2.from_angle(float(o) * PI / 4.0)
	u._set_anim(a, true)


func _tex_of(u: Unit) -> String:
	return u.sprite.texture.resource_path if u.sprite.texture != null else ""


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var fr: Dictionary = ArtData.UNITS["clock_soldier"]["frames"]
	for a in ["idle", "walk", "attack", "death"]:
		for w in ["sw", "w", "nw"]:
			var e: String = Unit.EAST_OF[w]
			check("clock_soldier has its own %s_%s strip, as many frames as %s_%s" % [a, w, a, e],
				fr.has(a + "_" + w) and int(fr[a + "_" + w]) == int(fr.get(a + "_" + e, -1)),
				"%s vs %s" % [fr.get(a + "_" + w, "none"), fr.get(a + "_" + e, "none")])
	var at := U.hall(g, 0).position + Vector2(0, 160)
	var cs: Unit = g._add_unit("clock_soldier", 0, at)
	var jack: Unit = g._add_unit("jack", 0, at + Vector2(60, 0))
	var musk: Unit = g._add_unit("musketeer", 1, at + Vector2(-60, 0)) if Defs.UNITS.has("musketeer") else null
	await process_frame
	for a in ["idle", "walk", "attack", "death"]:
		for o in 8:
			_face(cs, o, a)
			var v: String = VIEW[o]
			var west := Unit.EAST_OF.has(v)
			var want := "res://assets/units/clock_soldier/%s_%s.png" % [a, v]
			var ok: bool = cs.anim == a and cs.anim_dir == v and not cs.anim_flip and _tex_of(cs) == want and cs.sprite.scale.x > 0.0
			check("clock soldier %s facing %s draws %s_%s unflipped" % [a, v.to_upper(), a, v], ok,
				"dir %s flip %s tex %s" % [cs.anim_dir, cs.anim_flip, _tex_of(cs)])
			if west:
				check("  ... and counts as a west view (view_dir %s, view_mirrored)" % Unit.EAST_OF[v],
					cs.view_dir() == Unit.EAST_OF[v] and cs.view_mirrored())
	# a unit without west files mirrors the east strips, as before
	for u in [jack, musk]:
		if u == null:
			continue
		for o in 8:
			_face(u, o, "idle")
			var v: String = VIEW[o]
			var dr: String = Unit.DIR_FLIP[o][0]
			var flip: bool = Unit.DIR_FLIP[o][1]
			check("%s facing %s draws idle_%s %s" % [u.kind, v.to_upper(), dr, "mirrored" if flip else "as is"],
				u.anim_dir == dr and u.anim_flip == flip and (u.sprite.scale.x < 0.0) == flip,
				"dir %s flip %s" % [u.anim_dir, u.anim_flip])
	# per-view tables: an own west strip reads its east twin, mirrored once; a table with the west key uses it as is
	_face(cs, 4, "idle")      # W
	var tab := {"e": Vector2(10, -20), "s": Vector2(0, -20)}
	check("view_entry: W reads E's entry", cs.view_entry(tab, Vector2.ZERO) == Vector2(10, -20))
	check("view_mirror: and mirrors it", cs.view_mirror(tab))
	var tab2 := {"e": Vector2(10, -20), "w": Vector2(-7, -21)}
	check("view_entry: a table with a W key uses it unmirrored", cs.view_entry(tab2, Vector2.ZERO) == Vector2(-7, -21) and not cs.view_mirror(tab2))
	_face(jack, 4, "idle")
	check("view_mirror is false for a flipped east strip (the sprite's flip does it)", not jack.view_mirror(tab) and jack.view_mirrored())
	# the animation viewer: own west strips are not marked mirrored, the Jack's are
	check("anim viewer: the soldier's SW is its own", not AnimViewer.mirrored("clock_soldier", "walk", "sw") and AnimViewer.strip_frames("clock_soldier", "walk", "sw") == int(fr["walk_sw"]))
	check("anim viewer: the Jack's SW is SE mirrored", AnimViewer.mirrored("jack", "idle", "sw") and AnimViewer.strip_frames("jack", "idle", "sw") == int(ArtData.UNITS["jack"]["frames"]["idle_se"]))
	# the strips: frames the cell's size
	var cell: Vector2i = ArtData.UNITS["clock_soldier"]["cell"]
	for a in ["idle", "walk", "attack", "death"]:
		for w in ["sw", "w", "nw"]:
			var t := load("res://assets/units/clock_soldier/%s_%s.png" % [a, w]) as Texture2D
			check("%s_%s is %d frames of %dx%d" % [a, w, int(fr[a + "_" + w]), cell.x, cell.y],
				t != null and t.get_height() == cell.y and t.get_width() == cell.x * int(fr[a + "_" + w]),
				"%dx%d" % [t.get_width(), t.get_height()] if t else "missing")
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
