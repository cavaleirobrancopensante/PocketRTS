extends SceneTree
## THE BRUTE AS THE WALL-BREAKER (the owner, 2026-10-29; docs/brute_spitter.md). How fast a group of attackers breaks the
## Crown's Gate in its Cottage wall at the main ramp (Greenhold, AI.plan_cottage_wall), nobody defending or repairing it:
## each group is ordered to ATTACK the gate from the ramp's foot; the time runs from the order to the gate's fall.
##
##   godot --headless --fixed-fps 30 --script res://tools/test_brute_siege.gd -- [bb:2.5] [only:brute4] [check]
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/test_brute_siege.gd \
##       -- only:brute4 film:/abs/dir           (a frame every second and the fall)
##
## bb: sets the Brute's building_bonus for the run (on the spawned Brutes' own copy of their stats) (to compare values; default: Defs). One process per attacking faction
## (faction: brood / clockwork / crown, picked from the groups run; the default runs the Brood groups).
## check: asserts the Brute (as Defs has it) breaks the gate faster than the same cost of Raptors and of Clock Soldiers.

var main: Node
var g: Game
var t := 0.0
var begun := false
var started := false
var only := ""
var film := ""
var bb := -1.0
var faction := "brood"
var checking := false
var fails := 0

## name: [kind, count, faction of the attacking slot]. Prices: a Brute 150 + 20 essence, a Raptor 25 (75 an egg of 3),
## a Clock Soldier 70 cogs, a Field Cannon 170 + its horse 40.
const GROUPS := {
	"brute1": ["brute", 1, "brood"],
	"raptor6": ["raptor", 6, "brood"],          # (150: one Brute's price)
	"brute4": ["brute", 4, "brood"],            # (600 + 80 essence)
	"raptor24": ["raptor", 24, "brood"],        # (600)
	"clock2": ["clock_soldier", 2, "clockwork"],   # (140: about one Brute)
	"clock9": ["clock_soldier", 9, "clockwork"],   # (630)
	"cannon1": ["cannon", 1, "crown"],          # (210)
	"cannon3": ["cannon", 3, "crown"],          # (630)
}


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only:"):
			only = a.substr(5)
		elif a.begins_with("film:"):
			film = a.substr(5)
		elif a.begins_with("bb:"):
			bb = float(a.substr(3))
		elif a.begins_with("faction:"):
			faction = a.substr(8)
		elif a == "check":
			checking = true
	if only != "":
		faction = GROUPS[only][2]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if not begun:
		if t > 0.2:
			begun = true
			if film == "":
				root.add_child(SilentSfx.new())
			main.start({"map": "greenhold", "seed": 4242, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0},
				{"who": "easy", "faction": faction, "colour": 1, "side": 1}]})
			if main.game:
				for ai in main.game.ais:
					ai.process_mode = Node.PROCESS_MODE_DISABLED
				main.game.path_budget_us = 1 << 40
				if Music.me:
					Music.me._faction = ""
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func _open(c: Vector2i, r: int) -> bool:
	var lv := int(g.height[g.idx(c)])
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cc := c + Vector2i(dx, dy)
			if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or int(g.height[g.idx(cc)]) != lv or g.solid[g.idx(cc)] != 0:
				return false
	return true


func _free_near(p: Vector2, lv: int) -> Vector2:
	for r in range(0, 200, 6):
		for i in 12:
			var q := p + Vector2.from_angle(TAU * i / 12.0) * r
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, 8.0, 0):
				return q
	return p


var plan: Array = []
var pieces: Array = []
var foot := Vector2.ZERO
var rdir := Vector2.ZERO
var inside := Vector2.ZERO        # a spot on the high ground behind the wall


## The Crown's Cottage wall at its main ramp (as tools/study_raptor_spitter.gd's ramp group); the foot of the ramp.
func _wall() -> void:
	var ai: AI = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	if plan.is_empty():
		var p: Dictionary = ai.plan_cottage_wall()
		plan = [["cottage", p["cottage"]]]
		for e in p["pieces"]:
			plan.append([e[0], e[1]])
		var bands: Array = ai._ramp_bands()
		var band: Array = bands[0]["band"]
		var rampc: Array = bands[0]["ramp"]
		var bc := Vector2.ZERO
		for c in band:
			bc += g.cell_center(c)
		bc /= band.size()
		var rc := Vector2.ZERO
		for c in rampc:
			rc += g.cell_center(c)
		rc /= rampc.size()
		rdir = (rc - bc).normalized()
		inside = _free_near(bc - rdir * 110.0, int(g.height[g.idx(band[0])]))
		var lv := int(g.height[g.idx(band[0])])
		foot = rc
		for i in 40:
			var q: Vector2 = rc + rdir * (i * 16.0)
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) < lv and _open(c, 3):
				foot = q + rdir * 120.0
				break
		foot = _free_near(foot, int(g.height[g.idx(g.cell_of(foot))]))
		for e in plan:
			pieces.append(g._add_building(e[0], 0, e[1], true))
		# (a gate laid on a palisade piece takes its place: keep only what stands)
		var kp: Array = []
		var kb: Array = []
		for i in pieces.size():
			if is_instance_valid(pieces[i]) and not pieces[i].dead:
				kp.append(plan[i])
				kb.append(pieces[i])
		plan = kp
		pieces = kb
		print("wall: %s" % str(plan))
		return
	# (rebuild what fell, where it stood; mend the rest)
	for i in pieces.size():
		var b = pieces[i]
		if not is_instance_valid(b) or b.dead:
			pieces[i] = g._add_building(plan[i][0], 0, plan[i][1], true)
		else:
			b.hp = b.max_hp


func _gate() -> Building:
	for b in pieces:
		if is_instance_valid(b) and not b.dead and b.kind == "gate":
			return b
	return null


func _clear() -> void:
	for u in g.units.duplicate():
		if is_instance_valid(u) and u.kind != BroodNew.QUEEN:
			g.consume_unit(u)


func trial(name: String) -> Dictionary:
	var spec: Array = GROUPS[name]
	_clear()
	await wait(0.5)
	_wall()
	var gate := _gate()
	if gate == null:
		print("NO GATE in the wall plan")
		return {}
	var lv := int(g.height[g.idx(g.cell_of(foot))])
	var side := Vector2(-rdir.y, rdir.x)
	var list: Array = []
	for i in int(spec[1]):
		var p: Vector2 = foot + rdir * (float(i / 6) * 34.0) + side * (float(i % 6) - 2.5) * 30.0
		var u: Unit = g._add_unit(spec[0], 1, _free_near(p, lv))
		u.auto_work = false
		if bb > 0.0 and u.kind == "brute":
			var dd: Dictionary = u.d.duplicate(true)
			dd["building_bonus"] = bb
			u.d = dd
		list.append(u)
	await wait(0.5)
	var guns := false
	for u in list:
		if u.deploys():
			guns = true
			u.facing = -rdir
			u.cmd_deploy()          # (a gun is set up at the ramp's foot first, facing the gate: the time runs from then)
	if guns:
		# (round shot reaches further than it sees, and the low ground doesn't see the high: a spotter stands just
		# outside the gate, as a player would send one; it does nothing else)
		var sp: Unit = g._add_unit("labourer", 1, gate.center() + rdir * 40.0)
		sp.auto_work = false
		sp.max_hp = 1.0e9
		sp.hp = 1.0e9          # (the guns' splash would kill him)
		sp.process_mode = Node.PROCESS_MODE_DISABLED
		await wait(3.0)
	var t0: float = g.clock
	for u in list:
		u.cmd_attack(gate)
	var first := -1.0
	var hp0: float = gate.hp
	var frame := 0
	var next_film := 0.0
	while g.clock - t0 < 150.0 and is_instance_valid(gate) and not gate.dead:
		if OS.get_environment("BS_DEBUG") != "" and int((g.clock - t0) * 30.0) % 150 == 0:
			var u0: Unit = list[0]
			print("  t %.1f %s order %s target %s phase %s mode %s dist %.0f hp %.0f" % [g.clock - t0, u0.kind, u0.order, str(u0.target), u0.phase, u0.tesla_mode + " cd %.1f" % u0.cooldown, gate.edge_distance(u0.position), gate.hp])
		if first < 0.0 and gate.hp < hp0:
			first = g.clock - t0
		if film != "" and g.clock - t0 >= next_film:
			next_film += 1.0
			await _shot(gate.center(), "%s_%03d" % [name, frame])
			frame += 1
		await physics_frame
	var dur: float = g.clock - t0
	var broke: bool = not is_instance_valid(gate) or gate.dead
	if broke and first < 0.0:
		first = dur          # (it fell to the first blow or volley)
	var through := -1.0
	if broke and spec[0] == "brute":
		# (the Brute, 24 radius, walks up the ramp and through the 1-tile hole the gate leaves)
		var u0: Unit = list[0]
		u0.cmd_move(inside)
		var t1: float = g.clock
		while g.clock - t1 < 30.0 and u0.position.distance_to(inside) > 40.0:
			await physics_frame
		through = g.clock - t1 if u0.position.distance_to(inside) <= 40.0 else -1.0
		print("  a Brute through the gate's hole to the high ground: %s" % ("%.1f s" % through if through >= 0.0 else "STUCK"))
	if film != "":
		await _shot(foot.lerp(g.cell_center(plan[plan.size() - 1][1]), 0.6), "%s_end" % name)
	var r := {"name": name, "kind": spec[0], "n": spec[1], "broke": broke, "time": snapped(dur, 0.1),
		"first_hit": snapped(first, 0.1), "breaking": snapped(dur - first, 0.1) if broke and first >= 0.0 else -1.0,
		"bb": _bb(), "through": snapped(through, 0.1)}
	print("%-9s %2d x %-13s gate %s  order->fall %5.1fs  first hit %5.1fs  hitting %5.1fs" % [
		name, int(spec[1]), spec[0], "BROKEN" if broke else "stands", dur, first, r["breaking"]])
	_clear()
	return r


func _shot(at: Vector2, nm: String) -> void:
	g.camera.position = at
	g.camera.zoom = Vector2(2.6, 2.6)
	if g.hud:
		g.hud.visible = false
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [film, nm])


func _bb() -> float:
	return bb if bb > 0.0 else float(Defs.UNITS["brute"]["building_bonus"])


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	await wait(1.0)
	g.reveal = true          # (the cannons need no spotter)
	g.players[0]["cap"] = 400
	g.players[1]["cap"] = 400
	print("BRUTE SIEGE: Brute building_bonus %s, attacking faction %s" % [str(_bb()), faction])
	var res := {}
	for name in GROUPS.keys():
		if (only != "" and name != only) or GROUPS[name][2] != faction:
			continue
		res[name] = await trial(name)
	if checking and faction == "brood":
		check(res["brute1"]["broke"] and res["brute4"]["broke"], "Brutes break the gate")
		check(float(res["brute1"]["time"]) < float(res["raptor6"]["time"]), "one Brute breaks it faster than its price in Raptors (6)")
		check(float(res["brute4"]["time"]) <= float(res["raptor24"]["time"]), "4 Brutes break it no slower than their price in Raptors (24)")
		check(float(res["brute1"]["through"]) >= 0.0, "a Brute walks up the ramp and through the hole the gate leaves")
	print("BRUTE SIEGE DONE, %d failed" % fails)
	quit(1 if fails > 0 else 0)
