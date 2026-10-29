extends SceneTree
## The Brood's own sounds (tools/audio/make_brood_sounds.py, docs/brood_sounds.md), cut from the owner's creature
## recordings: every sound of the script is a file that loads, has a sensible length and a level in SoundMix; every
## Brood creature has its select, move and attack voices and its death (and its blow, if it fights); the Sires their
## arrival and breath roars; a mixed pick the brood_army chorus. Then a Brood match (you) against an Easy Crown: each
## creature is picked, sent off, told to attack, fights a Crown Musketeer and dies, and a mixed group is picked and
## ordered; Sfx's own log (MatchLog.sound) must hold each creature's own sounds and no sword "clash" or synth fallback.
##   godot --headless --fixed-fps 30 --script res://tools/test_brood_sounds.gd
## The creatures still to come (no Defs.UNITS entry yet): their files are checked all the same.
const LATER := ["hatchlings", "storm_challenger"]
## The kinds that keep older sounds: the Raptor (the owner's lizard recording), the Skywing's spines and the Grub's bite.
const OLD_BLOW := ["raptor", "skywing", "grub"]
## Fallbacks a Brood creature played before it had its own sounds (scripts/unit.gd, game.gd, brood_*.gd).
const FALLBACKS := ["clash", "combat/brood_death", "death_brood"]
var main: Node
var g
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## The streams of a sound name as Sfx finds them (the plain file and its numbered takes).
func takes(name: String) -> Array:
	var out: Array = []
	for base in ["res://assets/audio/" + name, "res://assets/" + name]:
		for p in [base + ".wav"] + range(1, 6).map(func(i: int) -> String: return "%s_%d.wav" % [base, i]):
			if ResourceLoader.exists(p):
				out.append(p)
		if not out.is_empty():
			break
	return out


func has_sound(name: String, lo := 0.1, hi := 2.6) -> bool:
	var ps := takes(name)
	if ps.is_empty():
		return false
	for p in ps:
		var st: AudioStream = load(p)
		if st == null or st.get_length() < lo or st.get_length() > hi or not SoundMix.GAIN.has(p):
			print("      %s: %s" % [p, "does not load" if st == null else ("%.2f s, gain %s" % [st.get_length(), SoundMix.GAIN.has(p)])])
			return false
	return true


func brood_kinds() -> Array:
	var out: Array = []
	for k in Defs.UNITS:
		if String(Defs.UNITS[k].get("faction", "")) == "brood" and k != "food_pile":
			out.append(k)
	return out


func fights(k: String) -> bool:
	return not Defs.UNITS.has(k) or not Defs.UNITS[k].get("no_attack", false)


func _run() -> void:
	# ---- the files
	var src := FileAccess.get_file_as_string("res://tools/audio/make_brood_sounds.py")
	var rx := RegEx.create_from_string('^    "([a-z0-9_/]+)": \\[')
	var names := {}
	for line in src.split("\n"):
		var m := rx.search(line)
		if m:
			var n := m.get_string(1)
			var tail := n.get_slice("_", n.get_slice_count("_") - 1)
			names[n.substr(0, n.length() - tail.length() - 1) if tail.is_valid_int() else n] = true
	check(names.size() > 80, "the script's %d sound names were read" % names.size())
	for n in names:
		check(has_sound(n), "%s: loads, 0.1-2.6 s, levelled" % n)
	for k in brood_kinds() + LATER:
		var whats := ["select"] if k == "brood_egg" else ["select", "move", "attack"]
		for w in whats:
			check(has_sound("voice/%s/%s" % [k, w], 0.1, 1.6), "%s answers %s" % [k, w])
		check(has_sound("combat/%s_death" % k), "%s has its death" % k)
		if fights(k) and k != "brood_egg":
			var blow := "combat/%s_attack" % k
			check(has_sound(blow, 0.08, 1.0) or k in OLD_BLOW, "%s has its own blow" % k)
	for f in ["tyrannosaur", "dilophosaurus", "pterodactyl"]:
		check(has_sound("brood/arrive_" + f), "the %s's arrival roar" % f)
		check(has_sound("brood/breath_" + f), "the %s's breath on an egg" % f)
	for m in ["tyrant_challenger", "venom_challenger", "storm_challenger"]:
		check(has_sound("brood/mature_" + m), "%s matured" % m)
	for w in ["select", "move", "attack"]:
		check(has_sound("voice/brood_army/" + w), "a mixed Brood group answers %s" % w)
	# ---- a match
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	g = main.game
	g.hud.countdown = 0.0
	paused = false
	await run(2.0)
	for ai in g.ais:
		ai.set_process(false)
	g.players[0]["cap"] = 200
	var q: Unit = BroodNew.queen(g, 0)
	check(q != null, "a Brood match, the Brood Mother stands")
	var at: Vector2 = q.position + Vector2(0, 300)
	g.camera.position = at
	var kinds: Array = brood_kinds().filter(func(k: String) -> bool: return k != "brood_mother" and k != "brood_egg")
	var us := {}
	for i in kinds.size():
		us[kinds[i]] = g._add_unit(kinds[i], 0, at + Vector2(-240 + 50 * i, 0))
	await run(0.3)
	var egg = g._add_unit("brood_egg", 0, at + Vector2(0, -60))
	for k in kinds + ["brood_mother", "brood_egg"]:
		var u: Unit = q if k == "brood_mother" else (egg if k == "brood_egg" else us[k])
		for what in (["select"] if k == "brood_egg" else ["select", "move", "attack"]):
			_free_sfx()
			if what == "select":
				g.set_selection([])
				g.set_selection([u])
			else:
				g.command_sound([u], what, what)
			await run(0.1)
	# a mixed group: the chorus
	var mixed: Array = [us["raptor"], us["spitter"], us["brute"]]
	for what in ["select", "move", "attack"]:
		_free_sfx()
		if what == "select":
			g.set_selection([])
			g.set_selection(mixed)
		else:
			g.command_sound(mixed, what, what)
		await run(0.1)
	g.set_selection([])
	# ---- fights: each fighter on its own against a Crown Musketeer standing still, till it hits
	for k in kinds:
		if not fights(k) or Defs.UNITS[k].get("air_only", false):
			continue
		var u: Unit = us[k]
		if BroodNew.rooted(u) or u.nb.has("coc"):
			continue
		var ranged := float(Defs.UNITS[k]["range"]) >= 100.0
		var f = g._add_unit("musketeer", 1, u.position + Vector2(0, 120 if ranged else 30))
		f.auto_work = false
		f.cmd_hold()
		f.hp = 5000.0
		u.cmd_attack(f)
		g.camera.position = u.position
		for n in 8:
			await run(0.5)
			if u.order == "idle" and not u.dead:
				u.cmd_attack(f)
		print("  %s: it did %.0f damage" % [k, 5000.0 - f.hp])
		f.hp = 0.0
		f.die()
		await run(0.1)
	# ---- deaths (near the camera)
	g.camera.position = at
	for k in kinds + ["brood_egg"]:
		var was = egg if k == "brood_egg" else us[k]
		var u: Unit = was if is_instance_valid(was) and not was.dead else null
		if u == null:
			u = g._add_unit(k, 0, at)
			await run(0.1)
		g.camera.position = u.position
		_free_sfx()
		u.hp = 0.0
		u.die()
		await run(0.3)
	# ---- what was heard
	var h := {}
	for sec in MatchLog.current._snd:
		for n in MatchLog.current._snd[sec]:
			h[n] = true
	for k in kinds + ["brood_mother", "brood_egg"]:
		for what in (["select"] if k == "brood_egg" else ["select", "move", "attack"]):
			check(h.has("voice/%s/%s" % [k, what]), "heard %s %s" % [k, what])
		if k != "brood_mother":
			check(h.has("combat/%s_death" % k), "heard the %s die" % k)
	for what in ["select", "move", "attack"]:
		check(h.has("voice/brood_army/" + what), "heard the brood_army %s" % what)
	for k in kinds:
		if fights(k) and not Defs.UNITS[k].get("air_only", false) and not k in OLD_BLOW:
			check(h.has("combat/%s_attack" % k), "heard the %s's blow" % k)
	for n in FALLBACKS:
		check(not h.has(n), "no fallback: " + n)
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


## Let the game run and clear Sfx's limits (real milliseconds: the test runs faster than real time).
func run(secs: float) -> void:
	for i in int(secs * 30.0):
		await physics_frame
		if i % 3 == 0:
			_free_sfx()


func _free_sfx() -> void:
	Sfx.me._last.clear()
	Sfx.me._starts.clear()
	Sfx.me._said.clear()
	Sfx.me._duck_until = 0
	Sfx.me._voice.stop()
