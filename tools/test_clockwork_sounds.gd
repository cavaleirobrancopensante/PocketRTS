extends SceneTree
## The Clockwork's own sounds (tools/audio/make_clockwork_sounds.py, docs/clockwork_sounds.md) really play in a match.
## A Clockwork player (you) against an Easy Crown: every gear-mode building is picked, every new unit is picked, ordered
## to move and to attack, fights a Crown man (the Swift a Crown balloon in the air), and dies; a Jack jumps, a Swift is
## morphed into a Ticking Owl (the research done rings), the Owl bombs a Crown building, a Netter nets, the Ratchet Turret
## shoots, a Winder cranks a Cog Press and builds, a building finishes, a unit comes out of the Works, men and base are
## attacked. Sfx's own log (MatchLog.sound) is read at the end: it FAILS if any sound the script makes never played, or
## if a Clockwork thing still played a generic or Crown fallback ("clash", "gear_hit", the bolt, the musket ...).
##   godot --headless --fixed-fps 30 --script res://tools/test_clockwork_sounds.gd
const U := preload("res://tools/gear_test_util.gd")
## The fallbacks the Clockwork's things played before they had their own sounds (scripts/unit.gd, game.gd, jack.gd,
## netter.gd, pendulum.gd, cw_air.gd, sfx.gd): none of them may be heard now.
const FALLBACKS := ["clash", "gear_hit", "combat/gear_hit", "combat/gearknight_attack", "combat/bolt_attack", "bolt",
	"combat/arrow_whoosh", "combat/clock_death", "death_clock", "clock/select_building", "ui/alert_all", "combat/skywing_attack",
	"bite", "combat/mortar_hit", "combat/cannon_hit", "boom", "combat/musketeer_attack_clock"]
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


## Let the game run (game time) and clear Sfx's limits, which count real milliseconds: the test runs faster than real
## time, so a sound's GAP or the cap on the din could otherwise hide a sound that would be heard in a real match.
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


func heard() -> Dictionary:
	var out := {}
	for sec in MatchLog.current._snd:
		for n in MatchLog.current._snd[sec]:
			out[n] = true
	return out


## A finished building whose gear ring meshes with b's; null if none fits (tools/test_cw_air.gd).
func beside(kind: String, b: Building) -> Building:
	for deg in [0.0, 90.0, 180.0, -90.0, 45.0, 135.0, -45.0, -135.0]:
		var c := GearNet.ring_spot(g, 0, kind, b, deg)
		if c.x >= 0:
			var m: Building = g._add_building(kind, 0, c, true)
			g.gear_net.solve()
			return m
	return null


func foe(kind: String, p: Vector2):
	var u = g._add_unit(kind, 1, p)
	u.auto_work = false
	u.cmd_hold()
	return u


func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
	await process_frame
	g = main.game
	g.hud.countdown = 0.0
	paused = false
	await run(2.0)
	check(Defs.gear_mode and g.faction_of(g.human) == "clockwork", "a gear-mode Clockwork match")
	g.players[0]["gold"] = 100000
	g.players[0]["tension"] = 10000.0
	g.players[0]["cap"] = 200
	var hall: Building = U.hall(g, 0)
	var base: Vector2 = hall.center()
	# ---- every gear-mode building, put down linked, then picked
	var built := {}
	for k in ["cog_press", "mainspring", "movement_works", "ratchet_turret", "escapement", "cuckoo_house", "regulator"]:
		# (the Escapement and the Aviary mesh with the Mainspring's ring: the Aviary needs a working Escapement)
		var b: Building = beside(k, built["mainspring"]) if k in ["escapement", "cuckoo_house"] else null
		if b == null:
			b = U.put(g, 0, k, hall.cell, k == "movement_works")
		check(b != null, "a %s stands" % k)
		if b:
			built[k] = b
	await run(1.0)
	for k in ["clocktower"] + built.keys():
		_free_sfx()
		g.set_selection([])
		g.set_selection([hall if k == "clocktower" else built[k]])
		await run(0.2)
	g.set_selection([])
	# a building finishes (the carriage slides back, the bell rings)
	_free_sfx()
	g.on_building_complete(built["regulator"])
	await run(0.3)
	# ---- the units: picked, sent off, told to attack
	var at := base + Vector2(0, 260)
	var kinds := ["winder", "clock_soldier", "jack", "cuckoo", "ticking_owl", "pendulum", "netter", "ballista", "great_winder"]
	var us := {}
	for i in kinds.size():
		var k: String = kinds[i]
		us[k] = g._add_unit(k, 0, at + Vector2(-180 + 60 * i, 0))
	await run(0.3)
	for k in kinds:
		for what in ["select", "move", "attack"]:
			_free_sfx()
			if what == "select":
				g.set_selection([])
				g.set_selection([us[k]])
			else:
				g.command_sound([us[k]], what, what)
			await run(0.1)
	g.set_selection([])
	# a unit out of the Works (the ready sound)
	_free_sfx()
	g.spawn_trained(built["movement_works"], "clock_soldier")
	await run(0.3)
	# ---- fights: each kind on its own against Crown Musketeers standing still (a balloon for the Swift), till it hits
	for k in ["clock_soldier", "winder", "pendulum", "ticking_owl", "jack", "netter", "cuckoo", "ballista"]:
		var u: Unit = us[k]
		var target_kind := "balloon" if k == "cuckoo" else "musketeer"
		var p: Vector2 = u.position + (Vector2(90, -30) if k == "cuckoo" else Vector2(0, 160 if k == "ballista" else (90 if k in ["jack", "netter"] else 30)))
		var f = foe(target_kind, p)
		f.hp = 5000.0
		u.cmd_attack(f)
		g.camera.position = u.position          # (units animate only on screen)
		for n in (24 if k == "ballista" else 16):         # (the Ballista: a shot, its crew's crank, the spring wound home)
			await run(0.5)
			if u.order == "idle" and not u.dead:
				u.cmd_attack(f)
		print("  %s vs %s: it took %.0f damage%s" % [k, target_kind, 5000.0 - f.hp, (" (%d bolts)" % u.bolts) if k == "ballista" else ""])
		f.hp = 0.0
		f.die()
		await run(0.1)
	# ---- the Ratchet Turret shoots a Musketeer standing by it
	var tur: Building = built["ratchet_turret"]
	var ft = foe("musketeer", tur.center() + Vector2(120, 40))
	ft.hp = 5000.0
	await run(6.0)
	ft.hp = 0.0
	ft.die()
	# ---- a Jack jumps (crouch, boing, landing)
	var j: Unit = us["jack"]
	j.cmd_stop()
	await run(0.5)
	var why: String = Jack.jump_order(g, [j], j.position + Vector2(110, 0))
	if why != "":
		why = Jack.jump_order(g, [j], j.position + Vector2(-110, 0))
	check(why == "", "a Jack jumps (%s)" % why)
	await run(2.0)
	# ---- the Ticking Owl's bomb on a Crown building (a house put down near our base)
	var owl: Unit = us["ticking_owl"]
	var house: Building = null
	for dx in range(6, 20):
		var c := Vector2i(hall.cell.x + dx, hall.cell.y + 8)
		if g.placement_problem(1, "cottage", c) == "":
			house = g._add_building("cottage", 1, c, true)
			break
	check(house != null, "a Crown house stands for the Owl to bomb")
	if house:
		house.hp = 50000.0
		owl.cmd_attack(house)
		await run(10.0)
	# ---- a Swift morphed into an Owl: the research done (the old bell), the crank, the bell when it is ready
	_free_sfx()
	g.research_done(built["cuckoo_house"], "owl_morph")
	await run(0.3)
	var sw: Unit = g._add_unit("cuckoo", 0, at + Vector2(0, -120))
	await run(0.2)
	g._recount_supply(0)
	g.players[0]["cap"] = 200
	why = g.morph_order([sw])
	check(why == "", "a Swift morphs into a Ticking Owl (%s)" % why)
	await run(float(Defs.OWL_MORPH["time"]) + 2.0)
	# ---- a Winder cranks a Cog Press, then builds
	var w: Unit = g._add_unit("winder", 0, built["cog_press"].center() + Vector2(0, 60))     # (a fresh one: the first fought)
	await run(0.2)
	w.cmd_gather(built["cog_press"])
	await run(10.0)
	var site_c := Vector2i(-1, -1)
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var c := Vector2i(hall.cell.x + dx, hall.cell.y + dy)
			if site_c.x < 0 and g.placement_problem(0, "regulator", c) == "" and g.gear_net.candidate(0, "regulator", c, false)["state"] == "ok":
				site_c = c
	check(site_c.x >= 0, "a spot for a Winder to build a Regulator")
	if site_c.x >= 0:
		var site: Building = g.place_building(0, "regulator", site_c, [w])
		check(site != null, "the Winder is sent to build")
		await run(30.0)
		check(site != null and is_instance_valid(site) and site.built, "the Regulator is built")
		if site and is_instance_valid(site):
			print("  site crate=%s seeded=%s built=%s; winder order=%s work=%s" % [site.crate, site.seeded, site.built, w.order, w.work])
	# ---- a Winder repairs a damaged building (the build/repair sound)
	var hurt: Building = built["regulator"]
	hurt.hp = hurt.max_hp * 0.4
	w.cmd_repair(hurt)
	g.camera.position = hurt.center()
	await run(8.0)
	# ---- attacked: the men (the alarm clock), then the base (another ring)
	g.camera.position = base + Vector2(4000, 4000)
	g.camera.force_update_scroll()
	await run(0.1)
	_free_sfx()
	g._alert_ms = -99999
	# (a Clock Soldier of ours: the first may have fallen in the fights above: 75 health since 0.14.53)
	var hit: Unit = us["clock_soldier"] if is_instance_valid(us["clock_soldier"]) and not us["clock_soldier"].dead else g._add_unit("clock_soldier", 0, at)
	g.under_attack(hit)
	await run(0.2)
	_free_sfx()
	g._alert_ms = -99999
	g.under_attack(built["regulator"])
	await run(0.2)
	# ---- a Great Winder mends a hurt Clock Soldier (the winding crank) and sweeps a wreck (the brush sweep)
	g.camera.position = at
	g.camera.force_update_scroll()
	var gwu: Unit = us["great_winder"] if is_instance_valid(us["great_winder"]) and not us["great_winder"].dead else g._add_unit("great_winder", 0, at)
	gwu.cmd_stop()
	var patient: Unit = g._add_unit("clock_soldier", 0, gwu.position + Vector2(70, 30))
	patient.cmd_hold()
	patient.hp = patient.max_hp * 0.3
	_free_sfx()
	await run(5.0)
	var wreck: Unit = g._add_unit("clock_soldier", 0, gwu.position + Vector2(-60, 40))
	wreck.hp = 0.0
	wreck.die()
	wreck._rest_in_peace()
	_free_sfx()
	await run(6.0)
	check(gwu.parts > 0, "the Great Winder swept a wreck (%d parts)" % gwu.parts)
	# ---- deaths, one kind at a time (near the camera: a sound far off screen is not played)
	g.camera.position = at
	g.camera.force_update_scroll()
	for k in kinds:
		var u: Unit = us[k] if is_instance_valid(us[k]) and not us[k].dead else g._add_unit(k, 0, at)
		_free_sfx()
		u.hp = 0.0
		u.die()
		await run(0.3)
	# ---- what was heard
	var h := heard()
	var want := {}
	var src := FileAccess.get_file_as_string("res://tools/audio/make_clockwork_sounds.py")
	var rx := RegEx.create_from_string('^    "([a-z0-9_/]+)": \\[')
	for line in src.split("\n"):
		var m := rx.search(line)
		if m:
			var n := m.get_string(1)
			var base_n := n
			var tail := n.get_slice("_", n.get_slice_count("_") - 1)
			if tail.is_valid_int():
				base_n = n.substr(0, n.length() - tail.length() - 1)
			want[base_n] = true
	check(want.size() > 40, "the script's %d sound names were read" % want.size())
	for n in want:
		var key: String = n
		check(h.has(key), "heard " + key)
	for n in FALLBACKS:
		check(not h.has(n), "no fallback: " + n)
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
