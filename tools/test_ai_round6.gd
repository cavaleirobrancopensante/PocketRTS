extends SceneTree
## AI round 6 (docs/ai_round6.md), on the four study maps, Hard Crown against Hard Clockwork:
##  - the Crown opens with the Powder Mill (Musketeers) against the Clockwork, never the Horse Breeder rush,
##  - each side's hall spots by land (AI._enemy_side): the enemy's main and natural are on its side, our natural on ours,
##    and no base site counts as both sides' own (the Clockwork's Clocktower under the Crown's cliff, 0.14.100),
##  - the first hall spot of each side is its natural (a cell beside it when the drawn site touches a ramp),
##  - the Crown keeps a spot for its Armoury (or has laid it) on its main's plateau, at the main hall's height.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_round6.gd -- [maps:greenhold,frostmere] [at:<s>]
var fails := 0
var maps := ["greenhold", "frostmere", "hollowfen", "kestrel_rise", "saltmarsh_isles", "cinder_steps"]
var at := 330.0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("maps:"):
			maps = Array(a.substr(5).split(","))
		elif a.begins_with("at:"):
			at = float(a.substr(3))
	_run.call_deferred()


func _h(g: Game, c: Vector2i) -> int:
	return int(g.height[g.idx(c)])


func _run() -> void:
	for m in maps:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		seed(14)
		main.start({"map": m, "seed": 14, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "balanced"}]})
		await process_frame
		await process_frame
		var g: Game = main.game
		if g.hud:
			g.hud.countdown = 0.0
		paused = false
		var crown = null
		for a in g.ais:
			if a._crown():
				crown = a
		check(crown != null and crown.opening == "mill", "%s: the Crown opens with the Powder Mill against the Clockwork (%s)" % [m, crown.opening if crown else "-"])
		# the sides of the map's base sites, by land
		var own := {}
		for a in g.ais:
			var mine: Array = []
			for c in g.base_sites:
				if g.starts.has(c):
					continue
				if not a._enemy_side(c):
					mine.append(c)
					own[c] = int(own.get(c, 0)) + 1
			print("  %s %s: its side's free base sites %s" % [m, g.faction_of(a.team), str(mine)])
			var o: int = 1 - a.team
			check(a._enemy_side(g.expansions[o]), "%s %s: the enemy's natural %s is on the enemy's side" % [m, g.faction_of(a.team), str(g.expansions[o])])
			check(not a._enemy_side(g.expansions[a.team]), "%s %s: our natural %s is on our side" % [m, g.faction_of(a.team), str(g.expansions[a.team])])
		# the first expansion goes to our natural (or the cell beside it when the computer may not use it as drawn:
		# Hollowfen's, Saltmarsh Isles' and Cinder Steps' naturals touch a ramp, "Keep the ramp clear")
		for a in g.ais:
			var sp: Vector2i = a._safe_hall_spot()
			var nat: Vector2i = g.expansions[a.team]
			check(sp.x >= 0 and Vector2(sp).distance_to(Vector2(nat)) <= float(a.SITE_NUDGE), "%s %s: the first hall spot %s is at our natural %s" % [m, g.faction_of(a.team), str(sp), str(nat)])
		var both: Array = own.keys().filter(func(c) -> bool: return int(own[c]) > 1)
		check(both.is_empty(), "%s: no base site is both sides' own %s" % [m, str(both)])
		while g.clock < at and not g.over:
			await physics_frame
		var arm: Array = crown._mine("armoury")
		var hall_h := _h(g, g.starts[crown.team] + Vector2i(2, 2))
		if not arm.is_empty():
			var b: Building = arm[0]
			check(_h(g, b.cell + Vector2i(1, 1)) == hall_h, "%s: the Armoury %s stands on the main's plateau (height %d, main %d)" % [m, str(b.cell), _h(g, b.cell + Vector2i(1, 1)), hall_h])
		else:
			var keep: Dictionary = g.ai_keep.get(crown.team, {}).get("armoury", {})
			check(not keep.is_empty() and _h(g, (keep["cell"] as Vector2i) + Vector2i(1, 1)) == hall_h, "%s: a spot is kept for the Armoury on the main's plateau %s" % [m, str(keep)])
		main.queue_free()
		await process_frame
		await process_frame
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
