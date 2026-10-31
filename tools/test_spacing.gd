extends SceneTree
## Spacing between units (docs/spacing.md): how far apart a group stands after a move and in a melee.
##   godot --headless --fixed-fps 30 --script res://tools/test_spacing.gd [-- shots=<dir>]
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/test_spacing.gd -- shots=docs/shots/spacing/after
## Cases (on Dune Sea, open level ground, the computers off):
##   musket_move   30 Musketeers made shoulder to shoulder (14 px apart), sent 640 px away
##   musket_spread 30 Musketeers made spread out (44 px apart), sent 640 px away (group_points closes them in)
##   raptor_move   30 Raptors made shoulder to shoulder, sent 640 px away
##   melee         30 Raptors attack-move into 20 Musketeers (their fire held, unkillable: the fight stays put)
##   surround      16 Raptors and 4 Brutes ATTACK one unkillable Musketeer
## For each: the average distance from each unit to its nearest friend ("nn"), the smallest ("min"), the group's
## radius round its middle, and for the fights how many of the attackers are in reach of an enemy and striking.
var main: Node
var g
var t := 0.0
var started := false
var shots := ""
var cases: Array = ["musket_move", "musket_spread", "raptor_move", "melee", "surround"]
var ci := -1
var ct := 0.0
var us: Array = []
var foes: Array = []
var at := Vector2.ZERO
var goal := Vector2.ZERO
var samples: Array = []
var shot_done := false
const DUR := {"musket_move": 18.0, "musket_spread": 22.0, "raptor_move": 14.0, "melee": 14.0, "surround": 10.0}


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.substr(6)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if not started:
		if t > 0.2 and main.game == null:
			root.add_child(SilentSfx.new())
			seed(4242)
			main.start({"map": "dune_sea", "seed": 4242, "slots": [
				{"who": "you", "faction": "crown", "colour": 0, "side": 0},
				{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
			return false
		if main.game == null or t < 1.0:
			return false
		g = main.game
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		g.path_budget_us = 1 << 40
		if Music.me:
			Music.me._faction = ""
		if shots != "":
			g.reveal = true          # (pictures: no fog over the other side's units; the numbers are taken without this)
			g.refresh_fog()
		started = true
		_next()
		return false
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	ct += delta
	var cname: String = cases[ci]
	if cname in ["melee", "surround"]:
		for f in foes:
			if is_instance_valid(f):
				f.hp = f.max_hp
		for u in us:
			if is_instance_valid(u) and not u.dead:
				u.hp = u.max_hp
		if ct >= 4.0 and fmod(ct, 1.0) < delta:
			samples.append(_measure())
	if g.camera:
		# (a little below the group's middle: the HUD covers the bottom of the screen)
		g.camera.position = (_middle(us) if cname != "melee" else (_middle(us) + _middle(foes)) * 0.5) + Vector2(0, 70)
	if not shot_done and shots != "" and ((cname in ["melee", "surround"] and ct >= 8.0) or ct >= DUR[cname] - 0.5):
		shot_done = true
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, cname])
	if ct >= DUR[cname]:
		_report(cname)
		if ci + 1 >= cases.size():
			print("SPACING done")
			return true
		_next()
	return false


func _next() -> void:
	# (the last case's units leave the field: each case stands alone)
	for u in us + foes:
		if is_instance_valid(u) and not u.dead:
			u.off_field = true
			u.position = Vector2(-5000, -5000)
			u.visible = false
			u.process_mode = Node.PROCESS_MODE_DISABLED
	ci += 1
	ct = 0.0
	samples.clear()
	shot_done = false
	us = []
	foes = []
	var cname: String = cases[ci]
	var h0 := _hall(0)
	var h1 := _hall(1)
	var mid := (h0.center() + h1.center()) * 0.5
	var dir := (h1.center() - h0.center()).normalized()
	at = _open_near(mid - dir * 320.0)
	goal = _open_near(at + dir * 640.0)
	match cname:
		"musket_move":
			us = _make("musketeer", 0, at, 30, 14.0)
			g.group_move(us, goal, false)
		"musket_spread":
			us = _make("musketeer", 0, at, 30, 44.0)
			g.group_move(us, goal, false)
		"raptor_move":
			us = _make("raptor", 1, at, 30, 12.0)
			g.group_move(us, goal, false)
		"melee":
			foes = _make("musketeer", 0, goal, 20, 22.0)
			for f in foes:
				f.hold_fire = true
				f.cmd_hold()
			us = _make("raptor", 1, at, 30, 12.0)
			g.group_move(us, goal, true)
		"surround":
			var m: Unit = g._add_unit("musketeer", 0, goal)
			m.auto_work = false
			m.hold_fire = true
			m.cmd_hold()
			foes = [m]
			us = _make("raptor", 1, goal - dir * 160.0, 16, 12.0) + _make("brute", 1, goal - dir * 220.0, 4, 40.0)
			for u in us:
				u.give({"o": "attack", "e": m})
	g.set_selection(us)


func _make(k: String, team: int, p: Vector2, n: int, sp: float) -> Array:
	var out: Array = []
	for q in _spots(p, n, sp):
		# (a loose clump, not rows: each a few px off its grid spot, the same every run)
		var j := Vector2(float((out.size() * 37) % 11) - 5.0, float((out.size() * 53) % 11) - 5.0) * sp / 14.0
		var u: Unit = g._add_unit(k, team, q + j)
		u.auto_work = false
		u._sep_n = out.size() % 3
		out.append(u)
	return out


func _measure() -> Dictionary:
	var live: Array = us.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var nn := 0.0
	var mn := INF
	for u in live:
		var best := INF
		for o in live:
			if o != u:
				best = minf(best, u.position.distance_to(o.position))
		nn += best
		mn = minf(mn, best)
	var c := _middle(live)
	var rad := 0.0
	for u in live:
		rad += u.position.distance_to(c)
	var reach := 0
	var striking := 0
	for u in live:
		for f in foes:
			if is_instance_valid(f) and not f.dead and f.edge_distance(u.position) - u.radius <= u._range():
				reach += 1
				break
		if u.target != null and u.phase != "":
			striking += 1
	var n := maxi(live.size(), 1)
	return {"nn": nn / n, "min": mn, "rad": rad / n, "reach": reach, "striking": striking, "n": live.size()}


func _report(cname: String) -> void:
	var m: Dictionary
	if samples.is_empty():
		m = _measure()
		var arrived := 0
		for u in us:
			if u.position.distance_to(goal) < 160.0:
				arrived += 1
		print("SPACING %-14s nn %.1f px  min %.1f  radius %.1f  arrived %d/%d" % [cname, m["nn"], m["min"], m["rad"], arrived, us.size()])
		return
	var acc := {"nn": 0.0, "min": 0.0, "rad": 0.0, "reach": 0.0, "striking": 0.0}
	for s in samples:
		for k in acc:
			acc[k] += float(s[k])
	for k in acc:
		acc[k] /= samples.size()
	print("SPACING %-14s nn %.1f px  min %.1f  radius %.1f  in reach %.1f/%d  striking %.1f  (%d samples)" % [cname, acc["nn"], acc["min"], acc["rad"], acc["reach"], us.size(), acc["striking"], samples.size()])


func _middle(list: Array) -> Vector2:
	var c := Vector2.ZERO
	var k := 0
	for u in list:
		if is_instance_valid(u) and not u.dead:
			c += u.position
			k += 1
	return c / k if k > 0 else at


func _hall(team: int) -> Entity:
	for b in g.buildings:
		if b.team == team and not b.dead and b.kind in ["hive", "town_hall", "clocktower", "brood_mother"]:
			return b
	for u in g.units:
		if u.team == team and not u.dead and u.kind == BroodNew.QUEEN:
			return u
	return null


func _spots(p: Vector2, k: int, sp: float) -> Array:
	var out: Array = []
	var c0: Vector2i = g.cell_of(p)
	var lv := int(g.height[g.idx(c0)])
	var r := 0
	while out.size() < k and r < 60:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var q := p + Vector2(x, y) * sp
				var c: Vector2i = g.cell_of(q)
				if g.in_map(c) and g.is_free(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, 10.0, 0):
					out.append(q)
					if out.size() >= k:
						return out
		r += 1
	return out


func _open_near(p: Vector2) -> Vector2:
	var c0: Vector2i = g.cell_of(p)
	for r in 40:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := c0 + Vector2i(x, y)
				if _open(c, 5):
					return g.cell_center(c)
	return p


func _open(c: Vector2i, r: int) -> bool:
	if not g.in_map(c):
		return false
	var lv := int(g.height[g.idx(c)])
	for yy in range(-r, r + 1):
		for xx in range(-r, r + 1):
			var cc: Vector2i = c + Vector2i(xx, yy)
			if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or int(g.height[g.idx(cc)]) != lv or g.solid[g.idx(cc)] != 0:
				return false
	return true
