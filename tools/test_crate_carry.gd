extends SceneTree
## A Winder carries the building crate IN FRONT in his hands (Unit.CRATE_HELD: over the body facing us or side on) and
## lowers it to the ground at the site (work "crate_drop", Unit.CRATE_DROP) before it lands and unfolds (owner, 2026-10-27).
var main: Node
var fails := 0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1
func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for i in 3:
		await physics_frame
	g.players[0]["gold"] = 5000
	var w = g.units.filter(func(u): return u.team == 0 and u.kind == "winder" and not u.dead)[0]
	var hall = g.halls_of(0)[0]
	var base: Vector2i = g.cell_of(hall.center())
	var site = null
	for r in range(6, 20):
		for dx in range(-r, r + 1):
			if site == null and g.placement_problem(0, "regulator", base + Vector2i(dx, r)) == "":
				site = g.place_building(0, "regulator", base + Vector2i(dx, r), [w])
	check(site != null, "a Regulator placed for the Winder")
	var carried_front := false
	var carried_seen := false
	var dropped := false
	var drop_low := false
	var landed_after_drop := false
	for i in 1800:
		await physics_frame
		if not is_instance_valid(site) or site.dead:
			break
		if w.crate_site == site and w._crate_spr and w._crate_spr.visible:
			carried_seen = true
			if w.work != "crate_drop" and w.anim_dir in ["s", "se", "e"]:
				carried_front = carried_front or (not w._crate_spr.show_behind_parent and w._crate_spr.position.y > -20.0)
			if w.work == "crate_drop":
				dropped = true
				if w.work_t < 0.05:
					drop_low = drop_low or w._crate_spr.position.y > -10.0
		if site.crate == "" and site.seeded:
			landed_after_drop = dropped
			break
	check(carried_seen, "the Winder carried the crate (its picture shown)")
	check(carried_front, "facing us or side on, the crate is in front of him at chest height, over the body")
	check(dropped, "at the site he sets it down (crate_drop) before it lands")
	check(drop_low, "lowered to the ground in front of him")
	check(landed_after_drop, "it lands and unfolds after he set it down")
	print("FAILS: %d" % fails if fails else "ALL PASS")
	quit()
