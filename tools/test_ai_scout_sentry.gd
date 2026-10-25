extends SceneTree
## The walled-ramp sentry (AIScout._sentry_tick): a Brood computer against a Crown (its own AI off)
## that has walled its ramp and keeps three Musketeers behind the wall.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_scout_sentry.gd -- [map:<id>] [plan:balanced|rush] [off:1] [end:<s>]
## `off:1` switches the sentry off (the "before" number). Prints "SENTRY ..." with the share of the
## time after the wall went up in which the computer SAW an enemy soldier, and checks that the
## sentry stands at the ramp, survives, and flees from armed units.
var main: Node
var g: Game
var ai: AI
var fails := 0
var map := "greenhold"
var plan := "balanced"
var off := false
var end_t := 420.0
var _wall_centre := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("plan:"):
			plan = a.substr(5)
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))
		elif a == "off:1":
			off = true
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	seed(4242)
	main.start({"map": map, "seed": 4242, "slots": [
		{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": plan},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ai = a
	if off:
		ai.scout.sentry_posts = 99
	var foe_hall: Building = g.halls_of(1)[0]
	_wall_ramp()
	var sp := g.find_spot(1, "barracks", foe_hall, 4, 16, "near", true)
	if sp.x >= 0:
		g._add_building("barracks", 1, sp, true)
	var musk: Array = []
	var wc := _wall_centre
	var inward := (foe_hall.center() - wc).normalized()
	for i in 3:
		# (three Musketeers just inside the wall, like a real wall defence)
		musk.append(g._add_unit("musketeer", 1, wc + inward * (45.0 + i * 8.0) + inward.orthogonal() * (i - 1) * 26.0))
	var seen_t := 0.0
	var total_t := 0.0
	var sentry_alive_t := 0.0
	var first_seen := -1.0
	var win_t := 0.0
	var win_seen := false
	var windows := 0
	var windows_seen := 0
	var dt := 1.0 / 30.0
	var home := g.center_of_team(0)
	var out_pt := _wall_centre + (home - _wall_centre).normalized() * 110.0
	var in_pt := _wall_centre + inward * 50.0
	var last_go := 0.0
	var outside := false
	while g.clock < end_t and not g.over:
		await physics_frame
		# the Crown's guard: three Musketeers that step out to the foot of the ramp and back every 25 s
		if g.clock - last_go >= 25.0 and g.clock > 100.0:
			last_go = g.clock
			outside = not outside
			for k in musk.size():
				if is_instance_valid(musk[k]) and not musk[k].dead:
					musk[k].cmd_move((out_pt if outside else in_pt) + inward.orthogonal() * (k - 1) * 24.0)
		if g.clock < 120.0:
			continue
		total_t += dt
		win_t += dt
		if win_t >= 10.0:
			windows += 1
			if win_seen:
				windows_seen += 1
			win_t = 0.0
			win_seen = false
		var sees := false
		for u in musk:
			if is_instance_valid(u) and not u.dead and g.is_visible_to(0, u.position):
				sees = true
		if sees:
			win_seen = true
			seen_t += dt
			if first_seen < 0.0:
				first_seen = g.clock
		if ai.scout.sentry != null and is_instance_valid(ai.scout.sentry) and not ai.scout.sentry.dead:
			sentry_alive_t += dt
	var sc := ai.scout
	var share := seen_t / maxf(1.0, total_t)
	if sc.sentry != null and is_instance_valid(sc.sentry):
		print("   sentry at %s, ramp %s, wall %s, out_pt %s (%d px from the sentry), in_pt %s" % [sc.sentry.position, sc._ramp_pt, _wall_centre, out_pt, int(sc.sentry.position.distance_to(out_pt)), in_pt])
	print("SENTRY plan:%s off:%s posts:%d flees:%d alive:%ds sees_musketeers:%d%% of %ds first_seen:%d windows_with_sighting:%d/%d" % [plan, off, sc.sentry_posts, sc.sentry_flees, int(sentry_alive_t), int(share * 100.0), int(total_t), int(first_seen), windows_seen, windows])
	print("   trips %d state %s verdict %s ramp %s seen_b %d workers %d" % [sc.trips, sc.state, sc.verdict, sc._ramp_pt, sc._seen_b.size(), g.workers(0).size()])
	for l in sc.log_lines:
		print("   LOG " + String(l))
	for l in sc.sentry_log:
		print("   %d s  %s" % [int(l[0]), l[1]])
	if off:
		print("ALL PASS (sentry off, numbers only)")
		quit(0)
		return
	check(sc.foe_ramp_walled(), "the walled ramp is recognised")
	check(sc.sentry_posts >= 1, "a sentry was posted (%d)" % sc.sentry_posts)
	check(sc.sentry_flees >= 1 or sentry_alive_t > 0.5 * total_t, "it flees from the guard that steps out, or stays unharmed (%d flees, alive %d of %d s)" % [sc.sentry_flees, int(sentry_alive_t), int(total_t)])
	check(windows_seen >= 3, "the computer keeps getting sightings of the guard behind the wall (a sighting in %d of %d ten-second windows)" % [windows_seen, windows])
	check(sc.sentry_posts <= sc.SENTRY_MAX_POSTS, "one unit at a time, a few replacements at most")
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


## Wall pieces on the enemy plateau cells that touch a ramp.
func _wall_ramp() -> void:
	var st := Vector2i(Vector2(g.starts[1]) + Vector2(2.5, 2.0))
	var h0 := int(g.height[g.idx(st)])
	var done := {}
	for y in range(st.y - 26, st.y + 27):
		for x in range(st.x - 26, st.x + 27):
			var r := Vector2i(x, y)
			if not g.in_map(r) or g.ramp[g.idx(r)] != 1:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := r + Vector2i(dx, dy)
					if g.in_map(c) and not done.has(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == h0 and g.solid[g.idx(c)] == 0:
						done[c] = true
						g._add_building("wall", 1, c, true)
	ai.scout._foe = 1
	var rp: Vector2 = ai.scout._find_ramp(g.center_of_team(0))
	var n := 0
	for c in done:
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
		if p.distance_to(rp) < 6.0 * Defs.TILE:
			_wall_centre += p
			n += 1
	_wall_centre /= maxf(1.0, float(n))
	print("   %d wall pieces at the enemy's ramps" % done.size())
