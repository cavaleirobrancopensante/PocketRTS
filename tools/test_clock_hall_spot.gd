extends SceneTree
## The Clockwork computer's next Clocktower goes on safe ground (playtests 0.14.82 and 0.14.84, Greenhold: a Hard
## Clockwork on Rush sent its Clocktower crate into the Crown's base at 8:20 and again and again, "60 tiles from its
## main", each one lost to the Crown's Musketeers). Set up as in the logs: the Crown (side 1) on its main and its
## natural, the Clockwork on its main and natural; then ask AI._safe_hall_spot for the next Clocktower spot. It must be
## nearer its own halls than any enemy hall, never in the enemy's base; and a spot where a crate or a Clocktower was
## lost is not tried again soon (nor ground near it).
##   godot --headless --fixed-fps 30 --script res://tools/test_clock_hall_spot.gd [-- map:<id> seed:<n>]
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var map := "greenhold"
var seed_ := 3352327084


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "clockwork", "colour": 1, "side": 1, "strategy": "rush"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ai(team: int) -> AI:
	for a in g.ais:
		if a.team == team:
			return a
	return null


func _c(cell: Vector2i, kind: String) -> Vector2:
	return Vector2(cell) + Vector2(Defs.BUILDINGS[kind]["size"]) * 0.5


## The nearest hall of each side to a spot, in tiles.
func _d_to(team: int, spot: Vector2i, kind: String) -> float:
	var best := INF
	for h in g.halls_of(team, false):
		best = minf(best, _c(spot, kind).distance_to(h.center() / Defs.TILE))
	return best


func _run() -> void:
	var ai := _ai(1)
	var hall: String = g.faction_hall(1)
	var crown_hall: String = g.faction_hall(0)
	print("starts %s  expansions %s" % [g.starts, g.expansions])
	print("base sites %s" % [g.base_sites])
	var crown_nat: Vector2i = g.expansions[0]
	var crown_main := Vector2(g.starts[0]) + Vector2(2.5, 2.0)
	# the Clockwork on its main and its natural (its first expansion, "24 tiles from its main", ~6:00)
	var kx: Vector2i = ai._safe_hall_spot()
	check(kx == g.expansions[1], "its first expansion is its own natural (%s)" % kx)
	g._add_building(hall, 1, kx, true)
	# the Crown's second Town Hall stands a few tiles off its natural's base site (the player's own choice of ground),
	# leaving the base site itself free: the only base site with fresh ore left on the map
	var off := Vector2i(-1, -1)
	var main_hall: Building = g.halls_of(0)[0]
	var bd := INF
	for y in range(crown_nat.y - 10, crown_nat.y + 11):
		for x in range(crown_nat.x - 10, crown_nat.x + 11):
			var c := Vector2i(x, y)
			var dn := Vector2(c).distance_to(Vector2(crown_nat))
			if dn < 6.0 or dn > 10.0 or g.placement_problem(0, crown_hall, c, true) != "":
				continue
			if dn < bd:
				bd = dn
				off = c
	check(off.x >= 0, "a spot for the Crown's hall off its natural's site (%s)" % off)
	g._add_building(crown_hall, 0, off, true)
	await physics_frame
	await physics_frame
	var free_nat: bool = g.placement_problem(1, hall, crown_nat, true) == ""
	print("the Crown's natural site %s is free for a Clocktower: %s" % [crown_nat, free_nat])
	# the next Clocktower (~8:00 in both logs)
	g.clock = 480.0
	for round in 3:
		var sp: Vector2i = ai._safe_hall_spot()
		if sp.x < 0:
			check(true, "round %d: no spot on its side left: it does not expand into the Crown's base" % round)
			break
		var main_d := _c(sp, hall).distance_to(Vector2(g.starts[1]) + Vector2(2.5, 2.0))
		var foe := minf(_d_to(0, sp, hall), _c(sp, hall).distance_to(crown_main))
		print("round %d: spot %s  %.0f tiles from its main, %.0f from the Crown's halls" % [round, sp, main_d, foe])
		check(foe >= main_d and foe >= 22.0, "round %d: the spot is not on the Crown's side or in its base (own main %.0f, Crown %.0f)" % [round, main_d, foe])
		# lost there (its crate shot on the road or the Clocktower razed): that spot and the ground round it wait
		if ai.has_method("note_lost_site"):
			ai.note_lost_site(sp)
		else:
			ai._hall_bad[sp] = g.clock + 240.0     # (before: what a razed hall did)
		var again: Vector2i = ai._safe_hall_spot()
		check(again != sp and (again.x < 0 or Vector2(again).distance_to(Vector2(sp)) > 16.0), "round %d: after a loss there, not that spot or the ground next to it (%s)" % [round, again])
	# its own natural lost (the Clocktower razed there): not that spot again at once
	ai._note_lost_halls()
	for h in g.halls_of(1, false):
		if h.cell == kx:
			g._remove_quietly(h)
	ai._note_lost_halls()
	var back: Vector2i = ai._safe_hall_spot()
	check(back != kx, "its natural just lost: not straight back there (%s)" % back)
	g.clock += 250.0
	back = ai._safe_hall_spot()
	check(back == kx, "after LOST_HALL_WAIT its natural is taken again (%s)" % back)
	# a lost crate tells the computer (Crate.die -> AI.note_lost_site)
	var ok_site := Vector2i(-1, -1)
	for c in g.base_sites:
		if g.placement_problem(1, hall, c, true) == "":
			ok_site = c
	if ok_site.x >= 0 and ai.has_method("note_lost_site"):
		g.players[1]["gold"] = 5000
		g._gear_relax = true            # (the gear field's own link rules aside: only the crate is looked at here)
		var site: Building = g.place_building(1, hall, ok_site, [])
		g._gear_relax = false
		check(site != null, "a Clocktower site placed for the crate test (%s)" % [g.requirement_text(1, hall)])
		if site:
			var cr: Crate = g.drop_crate(site, site.center() + Vector2(0, 80))
			await physics_frame
			cr.die()
			check(float(ai._hall_bad.get(ok_site, -1.0)) > g.clock + 200.0, "a Clocktower crate lost on the road marks its spot as lost")
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
