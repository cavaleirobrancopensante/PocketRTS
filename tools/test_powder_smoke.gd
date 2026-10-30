extends SceneTree
## BLACK POWDER SMOKE (scripts/powder_smoke.gd, docs/powder_smoke.md): shots make puffs, they
## fade and are removed, the cap holds, nothing shows on ground out of sight, the setting OFF
## makes none, the game's random numbers are untouched, and a whole computer match plays out
## the same (the same state hash every 10 s) with the smoke OFF and FULL:
##   godot --headless --fixed-fps 30 --script res://tools/test_powder_smoke.gd [-- secs:<n>] [-- quick]
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
	# a hundred Powder Wagons going up at one spot: they merge into one cloud, not 1,600 puffs
	for i in 100:
		ps.puff("wagon", me.position + Vector2(i % 10, i / 10) * 8.0)
	check(ps.alive < 100 * int(PowderSmoke.KINDS["wagon"][0]) / 2 and ps.merged > ps.alive, "a hundred Powder Wagons at one spot merge into one cloud (%d alive, %d merged)" % [ps.alive, ps.merged])
	ps.clear()
	# the cap: puffs all over the field (everything seen), never a live puff overwritten, the oldest age faster
	g.reveal = true
	var mg := ps.merged
	for i in ps.cap + 300:
		ps.puff("musket", Vector2(200 + (i % 28) * 110, 200 + ((i / 28) % 20) * 110), Vector2.RIGHT)
	check(ps.alive == ps.cap and ps.merged > mg, "the cap holds (%d alive, cap %d) and the newest wait instead of overwriting the oldest (%d not made)" % [ps.alive, ps.cap, ps.merged - mg])
	var full := ps.alive
	await wait(5.0)
	check(ps.alive < full, "past %d%% of the cap the oldest fade early (%d -> %d)" % [int(PowderSmoke.SOFT * 100), full, ps.alive])
	g.reveal = false
	ps.clear()
	_volley()
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
	_thick(me)
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
	if "quick" in OS.get_cmdline_user_args():          # (-- quick: without the three 7-minute matches)
		quit(1 if fails > 0 else 0)
		return
	# the simulation with the smoke OFF and FULL: two child matches, the same hashes
	var hs := []
	for lv in [0, 2, 3]:
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
	check(hs[0][0].size() >= 10 and hs[0][0] == hs[2][0], "the match plays out the same with the smoke OFF and THICK (%d hashes over %d s)" % [hs[2][0].size(), int(secs)])
	for k in [1, 2]:
		if hs[0][0] != hs[k][0]:
			for i in mini(hs[0][0].size(), hs[k][0].size()):
				if hs[0][0][i] != hs[k][0][i]:
					print("  first difference (OFF | %s): %s | %s" % [["", "FULL", "THICK"][k], hs[0][0][i], hs[k][0][i]])
					break
	check(int(hs[0][1]) == 0 and int(hs[1][1]) > 0, "OFF made no puffs, FULL made %d" % int(hs[1][1]))
	check(int(hs[2][1]) > int(hs[1][1]), "THICK made more puffs than FULL (%d > %d)" % [int(hs[2][1]), int(hs[1][1])])
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


## THICK (the owner's experiment, the default for now): over the units, their bars, the rings and
## the orders (the overlay), under the HUD; denser and longer lived than FULL; the default when
## the settings file holds no choice, while a saved choice stays.
func _thick(me: Unit) -> void:
	var th := PowderSmoke.new()
	g.add_child(th)
	th.setup(g, PowderSmoke.THICK)
	check(th.level == 3 and th.cap > PowderSmoke.CAP[2], "THICK: level 3, a bigger cap (%d > %d)" % [th.cap, PowderSmoke.CAP[2]])
	var lay: MultiMeshInstance2D = th._under
	check(th.get_child_count() == 1 and lay != null, "THICK draws in one MultiMesh (%d layers)" % th.get_child_count())
	var top := th.z_index + lay.z_index
	var unit_z := me.z_index
	for b in g.buildings:
		unit_z = maxi(unit_z, b.z_index)
	check(top > unit_z and top > g.body_bars.z_index and top > g.overlay.z_index and top > g.fog_sprite.z_index,
		"THICK is drawn above the units (z %d), the bars (%d), the overlay with rings and orders (%d) and the fog (%d): z %d" % [unit_z, g.body_bars.z_index, g.overlay.z_index, g.fog_sprite.z_index, top])
	var hud_under := true
	for c in g.get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).layer <= 0:
			hud_under = false
	check(hud_under, "the HUD, minimap and menus are CanvasLayers above the world (the smoke stays under them)")
	var m0 := th.made
	th.puff("cannon", me.position, Vector2.RIGHT)
	var nc := th.made - m0
	check(nc > int(PowderSmoke.KINDS["cannon"][0]), "THICK: denser, a cannon shot makes %d puffs (FULL %d)" % [nc, PowderSmoke.KINDS["cannon"][0]])
	m0 = th.made
	th.puff("musket", me.position, Vector2.RIGHT)
	check(th.made - m0 > int(PowderSmoke.KINDS["musket"][0]), "THICK: a musket shot makes %d puffs (FULL %d)" % [th.made - m0, PowderSmoke.KINDS["musket"][0]])
	var j := (th._w - 1 + th.cap) % th.cap
	var full_max := float(PowderSmoke.KINDS["musket"][3])
	var longest := 0.0
	var solid := 0.0
	for i in th.cap:
		longest = maxf(longest, th._life[i])
		solid = maxf(solid, th._a[i])
	check(longest > float(PowderSmoke.KINDS["cannon"][3]) * 0.999 or th._life[j] > float(PowderSmoke.KINDS["musket"][2]) * 1.2,
		"THICK: the puffs last longer (longest %.1f s; FULL's cannon at most %.0f s, its musket %.0f)" % [longest, PowderSmoke.KINDS["cannon"][3], full_max])
	check(is_equal_approx(PowderSmoke.LIFE_K[3], 1.25) and PowderSmoke.THICK_A > 1.0, "THICK: lives x%.2f, %.0f%% more solid" % [PowderSmoke.LIFE_K[3], (PowderSmoke.THICK_A - 1.0) * 100.0])
	th.tick(0.1)
	check(th._mm.visible_instance_count > 0, "THICK puffs are drawn (%d)" % th._mm.visible_instance_count)
	th.queue_free()
	# the default: no choice in the settings file -> THICK; a saved choice stays
	var keep := Settings.powder_smoke
	var path := ProjectSettings.globalize_path(Settings.PATH)
	var old := FileAccess.get_file_as_bytes(Settings.PATH) if FileAccess.file_exists(Settings.PATH) else PackedByteArray()
	var had := FileAccess.file_exists(Settings.PATH)
	var cfg := ConfigFile.new()
	cfg.set_value("input", "device", "pc")
	cfg.save(Settings.PATH)
	Settings._loaded = false
	Settings.load_all()
	check(Settings.powder_smoke == -1 and Settings.powder_smoke_level() == 3, "no choice in the settings file: THICK by default (%d)" % Settings.powder_smoke_level())
	for lv in [0, 1, 2]:
		cfg.set_value("ui", "powder_smoke", lv)
		cfg.save(Settings.PATH)
		Settings._loaded = false
		Settings.load_all()
		check(Settings.powder_smoke_level() == lv, "a saved choice stays as saved (%d -> %d)" % [lv, Settings.powder_smoke_level()])
	Settings.powder_smoke = -1
	Settings.save_all()
	Settings._loaded = false
	Settings.load_all()
	check(Settings.powder_smoke_level() == 3, "saved untouched (automatic) it is still THICK")
	# put the file back
	if had:
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_buffer(old)
		f.close()
	else:
		DirAccess.remove_absolute(path)
	Settings._loaded = false
	Settings.load_all()
	Settings.powder_smoke = keep


## THE 30-MUSKETEER VOLLEY (0.24.2: "clippy and blinky, takes too long to dissipate"), on THICK (the default), ticked
## by hand at 20 Hz: 30 Musketeers and 4 Field Cannons fire six volleys 2.5 s apart. No puff's alpha may jump by more
## than STEP between two ticks (a puff fading in, thinning in the cloud or fading out; none vanishes while still seen),
## the cloud must be bounded while they fire, still there 5 s after the last volley (it lingers), under a summed alpha of
## 1 in any 64 px square within THIN_BY s and gone within GONE_BY s.
const STEP := 0.10                    # (at 20 Hz: a puff takes at least half a second to go from nothing to solid)
const THIN_BY := 16.0
const GONE_BY := 30.0


func _cloud(ps: PowderSmoke) -> float:
	var cells := {}
	var top := 0.0
	for j in ps.cap:
		if ps._life[j] > 0.0:
			var k := Vector2i(int(floor(ps._pos[j].x / 64.0)), int(floor(ps._pos[j].y / 64.0)))
			var s: float = cells.get(k, 0.0) + ps._al[j]
			cells[k] = s
			top = maxf(top, s)
	return top


func _volley() -> void:
	var ps := PowderSmoke.new()          # (not in the tree: no _process, only the ticks below)
	ps.setup(g, PowderSmoke.THICK)
	g.reveal = true
	var at: Vector2 = Vector2(g.starts[0]) * Defs.TILE + Vector2(160, 0)
	var dt := 0.05
	var prev := PackedFloat32Array()
	prev.resize(ps.cap)
	prev.fill(0.0)
	var jump := 0.0
	var vanish := 0.0
	var peak_fire := 0.0
	var t := 0.0
	var thin_at := -1.0
	var gone_at := -1.0
	var at5 := 0.0
	var last := 5 * 2.5
	while t < last + GONE_BY + 5.0:
		var v := int(round(t / 2.5))
		if v <= 5 and absf(t - v * 2.5) < dt * 0.5:
			for i in 30:
				ps.puff("musket", at + Vector2(-(i / 15) * 26, -210 + (i % 15) * 30), Vector2.RIGHT)
			for i in 4:
				ps.puff("cannon", at + Vector2(-100, -150 + i * 100), Vector2.RIGHT)
		var life0 := ps._life.duplicate()
		ps.tick(dt)
		t += dt
		for j in ps.cap:
			if ps._life[j] > 0.0:
				if life0[j] > 0.0:
					jump = maxf(jump, absf(ps._al[j] - prev[j]))
				else:
					jump = maxf(jump, ps._al[j])          # (born this tick: from nothing)
			elif life0[j] > 0.0:
				vanish = maxf(vanish, prev[j])            # (removed: what it still showed)
			prev[j] = ps._al[j]
		var c := _cloud(ps)
		if t <= last + 0.01:
			peak_fire = maxf(peak_fire, c)
		elif absf(t - last - 5.0) < dt * 0.5:
			at5 = c
		if t > last + 0.01:
			if thin_at < 0.0 and c < 1.0:
				thin_at = t - last
			if gone_at < 0.0 and ps.alive == 0:
				gone_at = t - last
	print("VOLLEY made %d, merged %d, peak while firing %.2f, 5 s after %.2f, under 1 after %.1f s, gone after %.1f s, biggest alpha step %.3f, biggest vanish %.3f" % [
		ps.made, ps.merged, peak_fire, at5, thin_at, gone_at, jump, vanish])
	check(jump <= STEP, "the volley: no puff's alpha jumps more than %.2f a tick (biggest %.3f)" % [STEP, jump])
	check(vanish <= 0.01, "the volley: no puff vanishes while it still shows (biggest %.3f)" % vanish)
	check(peak_fire < 8.0, "the volley: the cloud is bounded while they fire (most in one 64 px square: %.2f summed alpha)" % peak_fire)
	check(at5 > 0.3, "the volley: it still lingers 5 s after the last volley (%.2f)" % at5)
	check(thin_at >= 0.0 and thin_at <= THIN_BY, "the volley: thinned under a summed alpha of 1 within %.0f s (%.1f s)" % [THIN_BY, thin_at])
	check(gone_at >= 0.0 and gone_at <= GONE_BY, "the volley: gone within %.0f s of the last volley (%.1f s)" % [GONE_BY, gone_at])
	g.reveal = false
	ps.free()
