extends SceneTree
## BLACK POWDER SMOKE (scripts/powder_smoke.gd, docs/powder_smoke.md): shots make puffs, they
## fade and are removed, the cap holds, nothing shows on ground out of sight, the setting OFF
## makes none, the game's random numbers are untouched, and a whole computer match plays out
## the same (the same state hash every 10 s) with the smoke OFF and FULL:
##   godot --headless --fixed-fps 30 --script res://tools/test_powder_smoke.gd [-- secs:<n>]
## (it runs the two matches itself, as child processes: "-- hash smoke:<0|2> secs:<n>").
var main: Node
var t := 0.0
var g: Game
var started := false
var fails := 0
var hash_mode := false
var smoke_lv := 2
var secs := 420.0
var next_at := 10.0


## The sounds without the wall clock (as tools/perf_bench.gd): a match then plays out the same every time.
class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "hash":
			hash_mode = true
		elif a.begins_with("smoke:"):
			smoke_lv = int(a.substr(6))
		elif a.begins_with("secs:"):
			secs = float(a.substr(5))
	PowderSmoke.force = smoke_lv if hash_mode else 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		if hash_mode:
			root.add_child(SilentSfx.new())
			seed(4242)
			main.start({"map": "hollowfen", "seed": 4242, "slots": [
				{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
				{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
			main.game.path_budget_us = 1 << 40
			if Music.me:
				Music.me._faction = ""
		else:
			main.start({"map": "hollowfen", "seed": 4242, "slots": [
				{"who": "you", "faction": "crown", "colour": 0, "side": 0},
				{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if hash_mode:
		if g.clock >= next_at:
			print("HASH %5.0f units=%d bld=%d %d" % [next_at, g.units.size(), g.buildings.size(), state_hash()])
			next_at += 10.0
		if g.clock >= secs or g.over:
			print("PUFFS %d" % (g.powder_smoke.made if g.powder_smoke else 0))
			print("DONE")
			quit(0)
		return false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func state_hash() -> int:
	var h := 17
	for u in g.units:
		if is_instance_valid(u):
			h = hash([h, u.kind, u.team, snappedf(u.position.x, 0.001), snappedf(u.position.y, 0.001), snappedf(u.hp, 0.001), u.dead])
	for b in g.buildings:
		if is_instance_valid(b):
			h = hash([h, b.kind, b.team, b.cell, snappedf(b.hp, 0.001), b.built])
	for p in g.players:
		h = hash([h, int(p["gold"]), snappedf(float(p["res2"]), 0.001)])
	return h


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(secs_: float) -> void:
	var e := 0.0
	while e < secs_:
		await physics_frame
		e += 1.0 / 30.0


func _run() -> void:
	var ps: PowderSmoke = g.powder_smoke
	check(ps != null and ps.level == 2 and ps.cap == PowderSmoke.CAP[2], "the match has the powder smoke at FULL (cap %d)" % ps.cap)
	# a Musketeer of yours and an enemy one in front of him, by your start
	var home: Vector2 = Vector2(g.starts[0]) * Defs.TILE
	var at := home + Vector2(160, 160)
	var me: Unit = g._add_unit("musketeer", 0, at)
	var foe: Unit = g._add_unit("musketeer", 1, at + Vector2(90, 0))
	foe.hp = 1000000.0
	foe.max_hp = 1000000.0
	await wait(0.6)
	check(ps.sees(me.position), "your side sees the ground your Musketeer stands on")
	var m0 := ps.made
	var a0 := ps.alive
	me.facing = Vector2.RIGHT
	g.musket_shot(me, foe, 0.0)
	check(ps.made - m0 == int(PowderSmoke.KINDS["musket"][0]), "a musket shot makes %d puffs (made %d)" % [PowderSmoke.KINDS["musket"][0], ps.made - m0])
	check(ps.alive == a0 + (ps.made - m0), "they are alive (%d)" % ps.alive)
	# they drift on the wind and grow; then fade and are removed
	var p0: Vector2 = ps._pos[(ps._w - 1 + ps.cap) % ps.cap]
	await wait(3.0)
	var p1: Vector2 = ps._pos[(ps._w - 1 + ps.cap) % ps.cap]
	check(p1.distance_to(p0) > 5.0, "the puff drifts (%.0f px in 3 s, wind %.1f px/s)" % [p1.distance_to(p0), ps.wind.length()])
	check(g.powder_smoke._mm.visible_instance_count > 0, "puffs are drawn (%d)" % g.powder_smoke._mm.visible_instance_count)
	var gun: Unit = g._add_unit("cannon", 0, at + Vector2(0, -50))
	gun.facing = Vector2.RIGHT
	g.cannon_shot(gun, foe.position, 0.0)
	# (no more shots from here: the enemy is taken far out of range)
	foe.max_hp = 10.0
	foe.hp = 1.0
	foe.take_damage(100.0, null)
	await wait(0.5)
	var after_shots := ps.alive
	check(ps.alive >= int(PowderSmoke.KINDS["cannon"][0]), "a cannon shot makes a bigger cloud (%d puffs alive)" % ps.alive)
	await wait(float(PowderSmoke.KINDS["cannon"][3]) + 1.5)
	check(ps.alive == 0, "every puff faded and was removed after its life (alive %d of %d)" % [ps.alive, after_shots])
	check(g.powder_smoke._mm.visible_instance_count == 0, "nothing left to draw")
	# the cap: a hundred Powder Wagons going up at once
	for i in 100:
		ps.puff("wagon", me.position + Vector2(i % 10, i / 10) * 8.0)
	check(ps.alive <= ps.cap, "the cap holds (%d alive, cap %d)" % [ps.alive, ps.cap])
	var full := ps.alive
	await wait(2.5)
	check(ps.alive < full, "past %d%% of the cap the oldest fade early (%d -> %d)" % [int(PowderSmoke.SOFT * 100), full, ps.alive])
	ps.clear()
	check(ps.alive == 0, "clear() empties it")
	# out of sight: none made; drifting out of sight: it fades out
	var far := Vector2(g.W, g.H) * Defs.TILE - home
	var r0 := ps.refused
	if not ps.sees(far):
		m0 = ps.made
		ps.puff("cannon", far, Vector2.RIGHT)
		check(ps.made == m0 and ps.refused > r0, "no smoke on ground your side does not see")
	else:
		check(false, "found a spot your side does not see (%s)" % far)
	ps.puff("musket", me.position, Vector2.RIGHT)
	var j := (ps._w - 1 + ps.cap) % ps.cap
	ps._pos[j] = far
	await wait(1.5)
	check(ps._life[j] <= 0.0 or ps._seen[j] < 0.2, "a puff that drifts out of sight fades out (%.2f)" % ps._seen[j])
	ps.clear()
	# the game's random numbers are untouched
	seed(77)
	var x0 := randf()
	seed(77)
	for i in 40:
		g.powder("musket", me.position, Vector2.RIGHT)
		g.powder("wagon", me.position)
	ps.tick(0.5)
	check(is_equal_approx(randf(), x0), "making and moving smoke draws none of the game's random numbers")
	ps.clear()
	# the setting OFF: none
	var off := PowderSmoke.new()
	off.setup(g, 0)
	off.puff("cannon", me.position, Vector2.RIGHT)
	off.puff("musket", me.position, Vector2.RIGHT)
	check(off.made == 0 and off.alive == 0 and off.get_child_count() == 0, "OFF makes no puffs and draws nothing")
	off.free()
	var light := PowderSmoke.new()
	g.add_child(light)
	light.setup(g, 1)
	light.puff("cannon", me.position, Vector2.RIGHT)
	check(light.made == int(PowderSmoke.KINDS["cannon"][1]) and light.cap == PowderSmoke.CAP[1], "LIGHT: fewer puffs (%d) and a smaller cap (%d)" % [light.made, light.cap])
	light.queue_free()
	# Clockwork and Brood shots: no powder smoke
	var cw_kinds := ["rail_rifleman", "springer", "spitter"]
	m0 = ps.made
	for k in cw_kinds:
		if Defs.UNITS.has(k):
			var cu: Unit = g._add_unit(k, 0, at + Vector2(0, 60))
			cu.facing = Vector2.RIGHT
			g.ground_shot_fx(cu, at + Vector2(100, 60))
			check(not g.powder_gun(cu), "%s fires no black powder" % k)
	check(ps.made == m0, "their shots make no powder smoke")
	# the online / replay effect: "powder:<kind>" plays on a guest
	m0 = ps.made
	g.powder_fx("powder:mortar", me.position, 9.0)
	check(ps.made - m0 == int(PowderSmoke.KINDS["mortar"][0]), "a guest's 'powder:mortar' effect makes the mortar's puffs")
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	# the simulation with the smoke OFF and FULL: two child matches, the same hashes
	var hs := []
	for lv in [0, 2]:
		var out := []
		var args := ["--headless", "--fixed-fps", "30", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/test_powder_smoke.gd", "--", "hash", "smoke:%d" % lv, "secs:%d" % int(secs)]
		OS.execute(OS.get_executable_path(), args, out, true)
		var lines: Array = []
		var puffs := -1
		for l in String(out[0]).split("\n"):
			if l.begins_with("HASH"):
				lines.append(l)
			elif l.begins_with("PUFFS"):
				puffs = int(l.substr(6))
		print("smoke %d: %d hash lines, %d puffs made" % [lv, lines.size(), puffs])
		hs.append([lines, puffs])
	check(hs[0][0].size() >= 10 and hs[0][0] == hs[1][0], "the match plays out the same with the smoke OFF and FULL (%d hashes over %d s)" % [hs[0][0].size(), int(secs)])
	if hs[0][0] != hs[1][0]:
		for i in mini(hs[0][0].size(), hs[1][0].size()):
			if hs[0][0][i] != hs[1][0][i]:
				print("  first difference: %s | %s" % [hs[0][0][i], hs[1][0][i]])
				break
	check(int(hs[0][1]) == 0 and int(hs[1][1]) > 0, "OFF made no puffs, FULL made %d" % int(hs[1][1]))
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
