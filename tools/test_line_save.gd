extends SceneTree
## The Line in a save and in the online snapshot: rows round-trip, damage and unfinished segments too.
##   godot --headless --script res://tools/test_line_save.gd
const U := preload("res://tools/line_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-56s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var cells := U.run_from_hall(g, 0, 18)
	g.line_net.seg_at(cells[4]).hp = 33.0
	var ghosts := g.line_net.lay(0, g.line_net.plan(0, cells[17], cells[17] + Vector2i(0, 4))["cells"].slice(1), [])
	g.line_net.solve()
	var rows: Array = g.line_net.save()
	check("one row per segment", rows.size() == g.line_net.segs.size(), "%d rows" % rows.size())
	# through JSON as the save file does
	var back: Array = JSON.parse_string(JSON.stringify(rows))
	var g2 := U.make(root)
	await process_frame
	await process_frame
	g2.line_net.clear()
	g2.line_net.load_rows(back)
	g2.line_net.solve()
	check("same segments after a save and load", g2.line_net.segs.size() == g.line_net.segs.size())
	check("same pressure after a load", absf(g2.line_net.seg_at(cells[12]).pressure - g.line_net.seg_at(cells[12]).pressure) < 0.001, "%.3f" % g2.line_net.seg_at(cells[12]).pressure)
	check("damage is kept", absf(g2.line_net.seg_at(cells[4]).hp - 33.0) < 0.2)
	check("unfinished segments are kept", g2.line_net.unbuilt_count(0) == ghosts.size() and ghosts.size() > 0)
	check("the fingerprint matches", g2.line_net.fingerprint() == g.line_net.fingerprint())
	# the snapshot applies to a puppet: rows change -> updates, removals
	g.line_net.seg_at(cells[10]).take_damage(99999.0, null)
	rows = g.line_net.save()
	g2.line_net.load_rows(rows)
	check("a segment destroyed on the host is gone on the guest", g2.line_net.seg_at(cells[10]) == null and g2.line_net.segs.size() == g.line_net.segs.size())
	g2.line_net.solve()
	check("and the far side has no pressure there either", g2.line_net.seg_at(cells[14]).pressure == 0.0)
	# SaveGame restore of an older save with no "line" key lays the start main
	var g3 := U.make(root)
	await process_frame
	await process_frame
	var n3 := g3.line_net.count(0)
	check("a new Clockwork game has its start main", n3 > 0)
	print("RESULT %s (%d failed)" % ["ALL OK" if fails == 0 else "SOME FAILED", fails])
	quit(0 if fails == 0 else 1)
