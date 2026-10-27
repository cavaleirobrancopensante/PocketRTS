extends SceneTree
## A computer's site dropped as "abandoned" (its builder fled from raiders, so nobody is coming) keeps the AI's
## look-again wait for that kind (AI._no_room): before, AI.site_failed always cleared it, so the Brood placed a Clutch
## Mound again at once in the same danger, its grub fled again and the site was dropped a second later, over and over
## (0.14.53 QA soak: up to 160 "dropped a Clutch Mound: nobody was coming to start it" lines in one match).
## A site that couldn't start because its spot was blocked still clears it (plan again at once).
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_abandoned_site.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-60s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root, ["brood", "crown"])
	await process_frame
	await process_frame
	var ai := AI.new()
	ai.game = g
	ai.team = 0
	ai.difficulty = 2
	ai.process_mode = Node.PROCESS_MODE_DISABLED       # (only its bookkeeping is used here)
	g.add_child(ai)
	g.ais.append(ai)
	g.players[0]["gold"] = 2000
	var cap := U.hall(g, 0)
	for why in ["abandoned", "blocked"]:
		var grub: Unit = null
		for w in g.workers(0):
			grub = w
		var spot := g.find_spot(0, "clutch_mound", cap, 3, 12, "near")
		var b := g.place_building(0, "clutch_mound", spot, [grub])
		check("%s: a Clutch Mound site is placed" % why, b != null and b.ghost)
		if b == null:
			continue
		ai._no_room["clutch_mound"] = g.clock         # (as AI._spread_swamp sets it when it places one)
		grub.cmd_move(grub.position + Vector2(200, 0))  # (the grub flees)
		g.site_failed(b, why)
		var kept: bool = ai._no_room.has("clutch_mound")
		if why == "abandoned":
			check("abandoned: the look-again wait stays (no re-place at once)", kept)
		else:
			check("blocked: the wait is cleared (plan again at once)", not kept)
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
