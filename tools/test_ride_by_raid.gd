extends SceneTree
## How strong a raid of 4 Horsemen is, BEFORE (the old standing fight) and AFTER the fight on the move
## (scripts/ride_by.gd; docs/ride_by.md has the table):
##   godot --headless --fixed-fps 30 --script res://tools/test_ride_by_raid.gd [-- only:<case>]
## Each case is played twice on the same open ground, RideBy.enabled off then on:
##  labourers / grubs / winders : 8 workers bunched at their work (standing), the riders attack-move onto them
##  labourers_fight / grubs_fight / winders_fight : the same, but the workers fight back (all go for the nearest rider)
##  musketeers_hold : 5 Musketeers on HOLD; the riders attack-move onto them
##  raptors : 6 Raptors on guard (they go for the riders)
##  clock_soldiers : 5 Clock Soldiers on guard
##  walled : 6 Labourers inside a palisade ring (one piece thick); the riders attack-move onto them
## Prints a RESULT line per case and mode: workers / soldiers killed, riders lost, the riders' health left, and when
## half the defenders were down. The checks are the counters: soldiers cost the riders at least as much as before,
## workers who fight back still hurt them, and a wall holds them off as long as before.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
var only := ""
var rows: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only:"):
			only = a.substr(5)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
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


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _clear() -> void:
	for u in g.units.duplicate():
		if u.position.distance_to(at(450, 320)) < 1300.0:
			g.consume_unit(u)
	for b in g.buildings.duplicate():
		if not b.dead and b.team >= 0 and b.center().distance_to(at(450, 320)) < 1000.0:
			b.die()
	for i in 3:
		await physics_frame


func _run() -> void:
	origin = _open_area(32, 22)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.players[0]["cap"] = 300
	g.players[1]["cap"] = 300
	g.players[0]["tech"] = {}
	var cases := ["labourers", "grubs", "winders", "labourers_fight", "grubs_fight", "winders_fight",
		"musketeers_hold", "raptors", "clock_soldiers", "walled"]
	for c in cases:
		if only != "" and c != only:
			continue
		for on in [false, true]:
			RideBy.enabled = on
			await _case(c, on)
	RideBy.enabled = true
	print("")
	print("| case | mode | killed | riders lost | riders' health left | half down at |")
	print("|---|---|---|---|---|---|")
	for r in rows:
		print("| %s | %s | %s | %d of 4 | %d%% | %s |" % r)
	_checks()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _row(c: String, on: bool) -> Array:
	for r in rows:
		if r[0] == c and r[1] == ("on the move" if on else "standing"):
			return r
	return []


func _checks() -> void:
	# soldiers: riding by is no stronger against them than the standing fight was (the riders come away with no more
	# health than before, a few points either way)
	for k in ["musketeers_hold", "raptors", "clock_soldiers"]:
		var a := _row(k, true)
		var b := _row(k, false)
		if not a.is_empty() and not b.is_empty():
			check(int(a[4]) <= int(b[4]) + 5, "%s: the riders on the move come away with %d%% health (standing: %d%%)" % [k, int(a[4]), int(b[4])])
	var wl := _row("walled", true)
	var wl0 := _row("walled", false)
	if not wl.is_empty() and not wl0.is_empty():
		var now := 999.0 if String(wl[5]) == "-" else String(wl[5]).to_float()
		var was := 999.0 if String(wl0[5]) == "-" else String(wl0[5]).to_float()
		check(now >= was - 3.0, "a palisade ring holds them off as long as before (half the hands down at %s s; before %s s)" % [wl[5], wl0[5]])
	for k in ["labourers_fight", "grubs_fight", "winders_fight"]:
		var a := _row(k, true)
		var b := _row(k, false)
		if not a.is_empty() and not b.is_empty():
			# (bunched workers fighting back still cost the riders: they don't come away untouched)
			check(int(a[4]) < 100, "%s: workers who fight back still hurt the riders (health left %d%%)" % [k, int(a[4])])


func _case(c: String, on: bool) -> void:
	await _clear()
	var kind := "labourer"
	var n := 8
	var fight := c.ends_with("_fight")
	var secs := 30.0
	var hold := false
	match c.trim_suffix("_fight"):
		"grubs":
			kind = "grub"
		"winders":
			kind = "winder"
		"musketeers_hold":
			kind = "musketeer"
			n = 5
			hold = true
			secs = 40.0
		"raptors":
			kind = "raptor"
			n = 6
			secs = 40.0
		"clock_soldiers":
			kind = "windup_soldier"
			n = 5
			secs = 40.0
		"walled":
			n = 6
	var mid := at(620, 320)
	var men: Array = []
	for i in n:
		var p := mid + Vector2((i % 4) * 26.0 - 39.0, (i / 4) * 26.0 - 13.0)
		var m: Unit = g._add_unit(kind, 1, p)
		m.auto_work = false
		if hold:
			m.cmd_hold()
		men.append(m)
	if c == "walled":
		# a palisade ring round them (one piece thick), two tiles clear inside
		var cc: Vector2i = g.cell_of(mid)
		for dy in range(-3, 4):
			for dx in range(-4, 5):
				if absi(dx) == 4 or absi(dy) == 3:
					g._add_building("wall", 1, cc + Vector2i(dx, dy), true)
		await physics_frame
	var riders: Array = []
	for i in 4:
		var r: Unit = g._add_unit("cuirassier", 0, at(150, 270 + i * 34))
		riders.append(r)
	var hp_all := 0.0
	for r in riders:
		hp_all += r.max_hp
	await physics_frame
	for r in riders:
		r.cmd_move(mid, true)
	var t0: float = g.clock
	var half_at := -1.0
	var look := 0.0
	while g.clock - t0 < secs:
		await physics_frame
		if fight and g.clock - t0 >= look:
			look = g.clock - t0 + 1.0
			# the hands drop their work and all go for the nearest rider (a player's answer to a raid)
			for m in men:
				if is_instance_valid(m) and not m.dead:
					var best: Unit = null
					var bd := 400.0
					for r in riders:
						if is_instance_valid(r) and not r.dead and r.position.distance_to(m.position) < bd:
							bd = r.position.distance_to(m.position)
							best = r
					if best and (m.order != "attack" or m.order_target != best):
						m.cmd_attack(best)
		var down := men.filter(func(m) -> bool: return not is_instance_valid(m) or m.dead).size()
		if half_at < 0.0 and down * 2 >= n:
			half_at = g.clock - t0
		var alive := riders.filter(func(r) -> bool: return is_instance_valid(r) and not r.dead).size()
		if alive == 0 or down == n:
			break
	var killed := men.filter(func(m) -> bool: return not is_instance_valid(m) or m.dead).size()
	var lost := riders.filter(func(r) -> bool: return not is_instance_valid(r) or r.dead).size()
	var hp_left := 0.0
	for r in riders:
		if is_instance_valid(r) and not r.dead:
			hp_left += r.hp
	var row := [c, "on the move" if on else "standing", "%d of %d %s" % [killed, n, kind], lost, int(round(100.0 * hp_left / hp_all)),
		"-" if half_at < 0.0 else "%.1f" % half_at]
	rows.append(row)
	print("RESULT %s %s: killed %s, riders lost %d, health left %d%%, half down at %s (%.0f s played)" % [row[0], row[1], row[2], lost, row[4], row[5], g.clock - t0])
