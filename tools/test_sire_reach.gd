extends SceneTree
## THE BIG CREATURES REACH WHAT THEY ARE SENT AT (the Crown turtle study, docs/crown_turtle_study.md: sent with the wave,
## the new Brood's Tyrant Sire stood 370 px from the gate on his attack order and never reached it):
##   godot --headless --fixed-fps 30 --script res://tools/test_sire_reach.gd
## On Greenhold (seed 4242) the Crown computer's own wall closes its main ramp (AI.plan_cottage_wall, as in the study);
## each creature in turn starts at the ramp's foot, 300 px down, UPROOTED, and is ordered:
##  1. ATTACK the gate: it must come within its reach of the gate and strike it within 40 s;
##  2. ATTACK-MOVE past the gate (to the Crown's hall): it must reach the wall (it is in the way) and strike the gate or
##     a wall piece beside it.
## Kinds: the Tyrant Sire, the Venom Sire, the Mound Turtle, a Rootmaw; the Brute and the Tyrant Challenger for reference.
## Prints PASS / FAIL lines and "sire_reach: N failures".
var main: Node
var g
var t := 0.0
var begun := false
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if not begun and t > 0.2:
		begun = true
		main.start({"map": "greenhold", "seed": 4242, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0},
			{"who": "hard", "faction": Defs.BROOD_NEW, "colour": 1, "side": 1}]})
		for ai in main.game.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
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


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func _free_near(p: Vector2, lv: int, r := 8.0) -> Vector2:
	for k in 14:
		for i in maxi(1, k * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, k * 6.0)) * k * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, r, 1):
				return q
	return p


func _run() -> void:
	var crown_ai: AI = null
	for a in g.ais:
		if a.team == 0:
			crown_ai = a
	var plan: Dictionary = crown_ai.plan_cottage_wall()
	var bands: Array = crown_ai._ramp_bands()
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
	var dir: Vector2 = (rc - bc).normalized()
	var pieces: Array = [g._add_building("cottage", 0, plan["cottage"], true)]
	for e in plan["pieces"]:
		pieces.append(g._add_building(e[0], 0, e[1], true))
	var gate: Building = null
	for b in pieces:
		if is_instance_valid(b) and not b.dead and b.kind == "gate":
			gate = b
	check(gate != null, "0. the Crown's wall at its ramp, with a gate (%d pieces)" % pieces.size())
	if gate == null:
		_end()
		return
	var lv := int(g.height[g.idx(band[0])])
	var foot := rc
	for i in 40:
		var q: Vector2 = rc + dir * (i * 16.0)
		var c: Vector2i = g.cell_of(q)
		if g.in_map(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) < lv:
			foot = q
			break
	var flv := int(g.height[g.idx(g.cell_of(foot))])
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			hall = b
	for k in [BroodNew.FATHER, BroodNew.DILO, BroodNew.TURTLE, BroodNew.MAW, "brute", "tyrant_challenger"]:
		for how in ["attack", "amove"]:
			gate.hp = gate.max_hp
			var u: Unit = g._add_unit(k, 1, _free_near(foot + dir * 300.0, flv, 34.0))
			u.auto_work = false
			await wait(0.3)
			var start: Vector2 = u.position
			if how == "attack":
				u.cmd_attack(gate)
			else:
				u.cmd_move(hall.center() if hall else gate.center() - dir * 300.0, true)
			var hit := false
			var best := INF
			var end: float = g.clock + 40.0
			while g.clock < end and not u.dead:
				best = minf(best, gate.edge_distance(u.position) - u.radius)
				var tg = u.target
				if u.phase != "" and is_instance_valid(tg) and pieces.has(tg) and tg.edge_distance(u.position) - u.radius <= u._range() + 6.0:
					hit = true          # (striking it, or the wall piece beside it: the way in is broken either way)
					break
				await physics_frame
			check(hit, "%s. %s (radius %d) %s the gate from %d px: %s (closest %d px from it, reach %d)" % [
				"1" if how == "attack" else "2", k, int(u.radius), "ATTACK" if how == "attack" else "ATTACK-MOVE past", int(start.distance_to(gate.center())),
				"strikes it" if hit else "never strikes it (order %s, target %s, phase '%s', velocity %d)" % [u.order, u.target.kind if is_instance_valid(u.target) else "none", u.phase, int(u.velocity.length())], int(best), int(u._range())])
			if is_instance_valid(u) and not u.dead:
				g.consume_unit(u)
			await wait(0.2)
	# 3. IN A WAVE (the study's case): each Sire behind 14 Raptors and 2 Brutes, all told to ATTACK the gate (kept whole
	# meanwhile, so the crowd stays packed at it): he must get in reach of it and strike within 40 s
	for k in [BroodNew.FATHER, BroodNew.DILO]:
		var wave: Array = []
		for i in 16:
			var wk := "brute" if i < 2 else "raptor"
			wave.append(g._add_unit(wk, 1, _free_near(foot + dir * (200.0 + 12.0 * (i % 4)) + dir.orthogonal() * 18.0 * float(i / 4 - 2), flv, 8.0)))
		var u: Unit = g._add_unit(k, 1, _free_near(foot + dir * 300.0, flv, 34.0))
		await wait(0.3)
		for w in wave + [u]:
			w.cmd_attack(gate)
		var hit := false
		var best := INF
		var end: float = g.clock + 40.0
		while g.clock < end and not u.dead:
			gate.hp = gate.max_hp
			best = minf(best, gate.edge_distance(u.position) - u.radius)
			if u.phase != "" and u.target == gate and best <= u._range() + 6.0:
				hit = true
				break
			await physics_frame
		check(hit, "3. %s in a wave of 16 at the gate: %s (closest %d px, reach %d; order %s, path %d/%d)" % [k, "strikes it" if hit else "never strikes it",
			int(best), int(u._range()), u.order, u.path_i, u.path.size()])
		for w in wave + [u]:
			if is_instance_valid(w) and not w.dead:
				g.consume_unit(w)
		await wait(0.3)
	_end()


func _end() -> void:
	print("sire_reach: %d failures" % fails)
	quit(1 if fails > 0 else 0)
