extends SceneTree
## The computer's Horseman rush, end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_rush.gd [-- map:<id> seed:<n>]
## A Hard Crown computer on the Rush plan (Horse Breeder opening) against a Brood player
## whose AI is switched off (its grubs only gather), on a fixed map and seed, for 6.5 game
## minutes. Prints the counts every 30 s, PASS / FAIL per check and "ALL PASS" at the end
## (exit 1 on a failure).
##  1. its riders get on their horses: at 3:00, 4:00 and 5:00 no Dismounted Horseman stands
##     without a horse coming (his own on its way, or walking to one), and no more than the
##     intended spares (2 in the rush) stand unridden (a moment's lag allowed: the best of
##     three looks 5 s apart)
##  1b. a Dismounted Horseman of its own put down at its rally point at 3:10 with no horse
##     kept for him (as after a fight) is found a horse and gets on (the 4:00 look counts him)
##  2. it has at least RUSH_MIN mounted Horsemen by 4:00
##  3. it's never supply-blocked with gold in the bank (cap reached, 150+ gold) for 20 s
##  4. its buildings stand on its main's own ground (up on the plateau, not below the ramp)
##  5. the rush rides down workers first: the Hive is hit only once grubs have been (or none
##     was to be seen)
const RUSH_MIN := 3
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var map := "redrock_canyon"
var seed_ := 4242
var ai_team := 1
var next_print := 30.0
var first_grub_kill := -1.0
var first_hive_hit := -1.0
var grubs0 := -1
var blocked_t := 0.0
var worst_block := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "rush"}]})
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
			if ai.team != ai_team:
				ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## Run the match on to `clock` (game seconds), or until it's over (the clock stops then).
func wait_until(clock: float) -> void:
	while g.clock < clock and not g.over:
		await physics_frame
		_watch()


## Every frame: the first grub killed, the first blow on the Hive, supply blocks.
func _watch() -> void:
	var grubs := 0
	for u in g.units:
		if u.team == 0 and not u.dead and u.kind == "grub":
			grubs += 1
	if grubs0 < 0:
		grubs0 = grubs
	if first_grub_kill < 0.0 and int(g.stats[0]["lost"]) > 0:
		first_grub_kill = g.clock
	if first_hive_hit < 0.0:
		var mo := BroodNew.queen(g, 0)          # (0.18.0: the Brood's base is its Mother)
		if mo != null and mo.hp < mo.max_hp:
			first_hive_hit = g.clock
	var cap: int = g.players[ai_team]["cap"]
	if g.supply_used(ai_team) >= cap and cap < g.max_supply(ai_team) and int(g.players[ai_team]["gold"]) >= 150:
		blocked_t += 1.0 / 30.0
		worst_block = maxf(worst_block, blocked_t)
	else:
		blocked_t = 0.0
	if g.clock >= next_print:
		next_print += 30.0
		var c := counts()
		print("%d:%02d  horsemen %d  dismounted %d (no horse coming %d)  horses %d (free %d, reserved %d)  gold %d  supply %d/%d  grubs lost %d" % [
			int(g.clock) / 60, int(g.clock) % 60, c["mounted"], c["dismounted"], c["stranded"], c["horses"], c["free"], c["reserved"],
			g.players[ai_team]["gold"], g.supply_used(ai_team), g.players[ai_team]["cap"], int(g.stats[0]["lost"])])


## The computer's horse picture now.
func counts() -> Dictionary:
	var c := {"mounted": 0, "dismounted": 0, "stranded": 0, "horses": 0, "free": 0, "reserved": 0}
	for u in g.units:
		if u.team != ai_team or u.dead:
			continue
		if u.kind == "cuirassier":
			c["mounted"] += 1
		elif u.kind == "dismounted":
			c["dismounted"] += 1
			var coming: bool = u.order == "mount" or (u.horse_rid != 0 and (g.reserved_horse(ai_team, u.horse_rid) != null or g.rid_breeder(ai_team, u.horse_rid) != null))
			if not coming:
				c["stranded"] += 1
		elif u.kind == "horse":
			c["horses"] += 1
			if u.horse_rid != 0:
				c["reserved"] += 1
			elif u.leader == null and u.into == null and not _coming_for(u):
				c["free"] += 1
	return c


## Someone of its side is walking up to horse h to take it.
func _coming_for(h) -> bool:
	var c = h.claimed
	return c != null and is_instance_valid(c) and not c.dead and c.order_target == h


## At 3:10 a Dismounted Horseman of the computer's appears at its rally point with no horse
## kept for him (as after a fight: his horse killed, or he was raised): it must find him one.
func _stray_rider() -> Unit:
	var ai = null
	for a in g.ais:
		if a.team == ai_team:
			ai = a
	var halls: Array = ai._halls()
	if halls.is_empty():
		return null
	var p: Vector2 = ai._rally_front(halls[0])
	var c: Vector2i = g.nearest_free(g.cell_of(p), 6)
	var u: Unit = g._add_unit("dismounted", ai_team, g.cell_center(c))
	print("%s: a Dismounted Horseman left on foot at the rally point" % _mmss(g.clock))
	return u


func _run() -> void:
	print("Hard Crown on the Rush plan vs a Brood player doing nothing, %s, seed %d" % [map, seed_])
	var by4 := 0
	var stray: Unit = null
	for m in [3, 4, 5]:
		if g.over:
			print("(the match is over: no %d:00 look)" % m)
			continue
		var stranded := 99
		var free := 99
		for k in 3:
			await wait_until(m * 60.0 + k * 5.0)
			var c := counts()
			stranded = mini(stranded, c["stranded"])
			free = mini(free, c["free"])
			if m == 4 and k == 0:
				by4 = c["mounted"]
		check(stranded == 0, "%d:00 no Dismounted Horseman left without a horse coming (%d)" % [m, stranded])
		check(free <= 2, "%d:00 unridden free horses within the rush's 2 spares (%d)" % [m, free])
		if m == 3 and not g.over:
			stray = _stray_rider()
	if stray:
		check(stray.dead or stray.kind == "cuirassier", "a rider left on foot by the rally point (no horse kept for him) got on a horse (%s)" % ("dead" if stray.dead else stray.kind))
	check(by4 >= RUSH_MIN, "%d mounted Horsemen by 4:00 (want %d)" % [by4, RUSH_MIN])
	await wait_until(390.0)
	if g.over:
		print("match over at %s, winner team %d" % [_mmss(g.clock), g.winner])
	check(worst_block < 20.0, "never supply-blocked with 150+ gold for 20 s (longest %.0f s)" % worst_block)
	# its buildings on its main's ground
	var hall: Building = null
	for b in g.buildings:
		if b.team == ai_team and b.kind == "town_hall" and not b.dead:
			hall = b
			break
	var off := []
	if hall:
		var h0: int = g.height[g.idx(g.cell_of(hall.rect().get_center()))]
		for b in g.buildings:
			if b.team != ai_team or b.dead or b.kind in ["wall", "gate", "town_hall"]:
				continue
			if b.center().distance_to(hall.center()) > 20.0 * Defs.TILE:
				continue
			# (a Farm of a natural expansion's hall, below the main: that hall's ground, not the main's)
			var near_hall: Building = hall
			for h2 in g.buildings:
				if h2.team == ai_team and h2.kind == "town_hall" and not h2.dead and h2.center().distance_to(b.center()) < near_hall.center().distance_to(b.center()):
					near_hall = h2
			if near_hall != hall:
				continue
			if int(g.height[g.idx(g.cell_of(b.rect().get_center()))]) != h0:
				off.append(b.kind)
	check(hall != null and off.is_empty(), "its buildings stand on its main's ground (off it: %s)" % [off])
	print("first grub killed at %s, Brood Mother first hit at %s" % [_mmss(first_grub_kill), _mmss(first_hive_hit)])
	check(first_grub_kill >= 0.0, "the rush killed grubs")
	check(first_hive_hit < 0.0 or (first_grub_kill >= 0.0 and first_grub_kill <= first_hive_hit), "workers before the Brood Mother")
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _mmss(s: float) -> String:
	return "never" if s < 0.0 else "%d:%02d" % [int(s) / 60, int(s) % 60]
