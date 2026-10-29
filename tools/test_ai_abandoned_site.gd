extends SceneTree
## A computer's site dropped as "abandoned" (its builder fled from raiders, so nobody is coming) keeps the AI's
## look-again wait for that kind (AI._no_room): before, AI.site_failed always cleared it, so the computer placed a
## supply building again at once in the same danger, its builder fled again and the site was dropped a second later,
## over and over (0.14.53 QA soak: up to 160 "dropped a Clutch Mound: nobody was coming to start it" lines in one match,
## the old Brood's). Any kind the computer places (AI._construct) waits AI.ABANDON_WAIT s after a site of it was dropped
## so, then is placed. A site that couldn't start because its spot was blocked still clears it (plan again at once).
## (0.18.0: the old Brood is gone; the Crown's Cottage plays the part its Clutch Mound played.)
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_abandoned_site.gd
const U := preload("res://tools/gear_test_util.gd")
const KIND := "cottage"
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-60s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _ghosts(g: Game) -> int:
	return g.buildings.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead and x.kind == KIND and x.ghost and x.team == 0).size()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root, ["crown", "clockwork"])
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
	var hall := U.hall(g, 0)
	for why in ["abandoned", "blocked"]:
		var lab: Unit = null
		for w in g.workers(0):
			lab = w
		var spot := g.find_spot(0, KIND, hall, 3, 12, "near")
		var b := g.place_building(0, KIND, spot, [lab])
		check("%s: a Cottage site is placed" % why, b != null and b.ghost)
		if b == null:
			continue
		ai._no_room[KIND] = g.clock         # (as the computer sets it when it places one)
		lab.cmd_move(lab.position + Vector2(200, 0))  # (the builder flees)
		g.site_failed(b, why)
		var kept: bool = ai._no_room.has(KIND)
		if why == "abandoned":
			check("abandoned: the look-again wait stays (no re-place at once)", kept)
			ai._no_room.erase(KIND)        # (only the abandoned-wait of _construct is looked at below)
			var n0 := _ghosts(g)
			ai._construct(KIND, spot)
			check("abandoned: _construct doesn't place that kind again at once", _ghosts(g) == n0, "%d -> %d sites" % [n0, _ghosts(g)])
			g.clock += AI.ABANDON_WAIT + 1.0
			ai._construct(KIND, spot)
			check("abandoned: a few seconds later _construct places it", _ghosts(g) == n0 + 1, "%d -> %d sites" % [n0, _ghosts(g)])
			for x in g.buildings.duplicate():
				if x.ghost and x.team == 0:
					g.site_failed(x, "blocked")
		else:
			check("blocked: the wait is cleared (plan again at once)", not kept)
	print("ALL OK" if fails == 0 else "SOME FAILED (%d)" % fails)
	quit(1 if fails else 0)
