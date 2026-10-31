extends SceneTree
## The new-version box (scripts/update_check.gd): the version compare, and the main menu showing the box when the site
## is newer, with DOWNLOAD and LATER (LATER closes it for the run).
##   godot --headless --script res://tools/test_update_check.gd
var fails := 0


func check(ok: bool, name: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func _find(n: Node, txt: String) -> Node:
	if (n is Label or n is Button) and String(n.text) == txt:
		return n
	for c in n.get_children():
		var f := _find(c, txt)
		if f:
			return f
	return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(UpdateCheck.newer("0.24.33", "0.24.32") and UpdateCheck.newer("0.25.0", "0.24.99") and UpdateCheck.newer("1.0", "0.99.99"), "newer: a higher number wins, part by part")
	check(not UpdateCheck.newer("0.24.32", "0.24.32") and not UpdateCheck.newer("0.24.9", "0.24.10"), "newer: the same or an older one is not newer")
	var main = load("res://scenes/main.tscn").instantiate()
	UpdateCheck.asked = true            # (no network here)
	UpdateCheck.latest = "99.0.0"
	root.add_child(main)
	await process_frame
	await process_frame
	main.show_menu()
	await process_frame
	check(_find(main, Loc.t("A NEW VERSION IS OUT")) != null, "the site is newer: the box is on the main menu")
	var later: Button = _find(main, Loc.t("LATER"))
	check(later != null and _find(main, Loc.t("DOWNLOAD")) != null, "with DOWNLOAD and LATER")
	if later:
		later.pressed.emit()
	await process_frame
	await process_frame
	main.show_menu()
	await process_frame
	check(_find(main, Loc.t("A NEW VERSION IS OUT")) == null, "LATER: not shown again this run")
	UpdateCheck.dismissed = false
	UpdateCheck.latest = main.version
	main.show_menu()
	await process_frame
	check(_find(main, Loc.t("A NEW VERSION IS OUT")) == null, "the same version: no box")
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
