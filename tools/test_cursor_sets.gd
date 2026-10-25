extends SceneTree
## Every faction has all nine cursors and their hotspots, and a match of that faction switches to its set.
var fails := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1
func _run() -> void:
	var c := Cursors.new()
	root.add_child(c)
	await process_frame
	for fac in ["crown", "brood", "clockwork"]:
		var ok: bool = c._tex.has(fac) and c._tex[fac].size() == Cursors.NAMES.size() and c._hot[fac].size() == Cursors.NAMES.size()
		for n in Cursors.NAMES:
			ok = ok and c._tex[fac][n] is Texture2D and c._hot[fac].has(n)
		check(ok, "%s: nine cursors with hotspots" % fac)
	check(c._tex["brood"]["pointer"] != c._tex["crown"]["pointer"] and c._tex["clockwork"]["pointer"] != c._tex["crown"]["pointer"], "the sets are different pictures")
	c._use("brood")
	check(c._set == "brood", "switching to the Brood's set")
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
