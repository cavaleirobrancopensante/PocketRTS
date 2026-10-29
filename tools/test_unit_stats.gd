extends SceneTree
## THE STATS ROW on the unit card (scripts/ui/unit_stats.gd, docs/unit_stats.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_unit_stats.gd
##  1. every kind in Defs.UNITS (and the armoured ones): the stats build from the kind without errors; a fighting unit
##     has a sane damage a second (0.2..80: the Netter's net is the least), reach (0.3..16 tiles) and time between attacks (0.3..20 s); every chip has
##     a known icon (or none) and a title; a unit with no weapon shows "cannot attack"
##  2. the same from a real unit of every kind in a match (UnitStats.of_unit)
##  3. effective values: veterancy raises the damage, a lock shortens the Musketeer's reload, the Armour refit adds
##     armour, a run-down construct hits softer
##  4. the new Brood's structure-units: uprooted they show their attack; rooted "cannot attack" and their armour +3
##  5. the row draws into a narrow (phone) and a wide (computer) rect without overflowing
## Prints PASS / FAIL lines and "unit_stats: N failures".
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 3, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.5:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL  " + what)
		fails += 1


func say(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func sane(k: String, s: Dictionary, src: String) -> void:
	var chips: Array = s["chips"]
	check(not chips.is_empty(), "%s %s: no chips" % [src, k])
	for c in chips:
		check(String(c["icon"]) == "" or UnitStats.ICONS.has(String(c["icon"])), "%s %s: unknown icon %s" % [src, k, c["icon"]])
		check(String(c.get("title", "")) != "", "%s %s: a chip with no title" % [src, k])
	if String(s["type"]) == "none":
		check(chips.any(func(c: Dictionary) -> bool: return c["icon"] == "no_attack"), "%s %s: no weapon but no 'cannot attack'" % [src, k])
		return
	var dps := float(s["dps"])
	var rng := float(s["range"])
	var cyc := float(s["cycle"])
	check(is_finite(dps) and dps >= 0.2 and dps <= 80.0, "%s %s: damage a second %.2f" % [src, k, dps])
	check(rng >= 0.3 and rng <= 16.0, "%s %s: range %.2f tiles" % [src, k, rng])
	check(cyc >= 0.3 and cyc <= 20.0, "%s %s: an attack every %.2f s" % [src, k, cyc])


func chip(s: Dictionary, icon: String) -> Dictionary:
	for c in s["chips"]:
		if c["icon"] == icon:
			return c
	return {}


func _run() -> void:
	await create_timer(0.3).timeout
	# 1. every kind, from Defs
	var f0 := fails
	var n := 0
	for k in Defs.UNITS:
		var s := UnitStats.of_kind(k)
		sane(k, s, "kind")
		n += 1
		if Defs.ARMOURED.has(k):
			sane(k, UnitStats.of_kind(k, true), "armoured kind")
			n += 1
	say(fails == f0, "1. the stats of all %d kinds (and armoured) build, with sane damage a second, range and attack time" % n)
	# a table to read (one line a kind)
	for k in Defs.UNITS:
		var s := UnitStats.of_kind(k)
		print("   %-18s %-6s dps %5.1f  range %4.1f  every %4.1f s  %s" % [k, s["type"], s["dps"], s["range"], s["cycle"],
			", ".join((s["specials"] as Array).map(func(e: Dictionary) -> String: return String(e["name"])))])
	# 2. a real unit of every kind
	f0 = fails
	var at: Vector2 = g.units[0].position + Vector2(200, 0)
	var made := {}
	for k in Defs.UNITS:
		var u: Unit = g._add_unit(k, 0, at)
		made[k] = u
		sane(k, UnitStats.of_unit(u), "unit")
	say(fails == f0, "2. the stats of a real unit of every kind build")
	# 3. effective values
	var m: Unit = made["musketeer"]
	var s0 := UnitStats.of_unit(m)
	m.kills = 20
	m.lock = "flintlock"
	var s1 := UnitStats.of_unit(m)
	say(float(s1["dps"]) > float(s0["dps"]) * 1.3, "3. veterancy (20 kills) and a flintlock: DPS %.2f -> %.2f" % [s0["dps"], s1["dps"]])
	say(String(chip(s1, "ranged")["text"]) == "24", "   a hit 20 -> %s" % chip(s1, "ranged").get("text", "?"))
	m.put_on_armour()
	say(String(chip(UnitStats.of_unit(m), "armour")["text"]) == "1", "   the Armour refit: armour 1 (a Guardsman)")
	var cs: Unit = made["clock_soldier"]
	var full := float(UnitStats.of_unit(cs)["dps"])
	cs.wind = 0.0
	say(float(UnitStats.of_unit(cs)["dps"]) < full * 0.75, "   a run-down Clock Soldier hits softer: %.2f -> %.2f" % [full, UnitStats.of_unit(cs)["dps"]])
	# 4. the new Brood's structure-units
	for k in BroodNew.ROOTERS:
		var u: Unit = made[k]
		u.tesla_mode = "packed"
		var up := UnitStats.of_unit(u)
		var a0 := float(chip(up, "armour")["text"])
		var atk := chip(up, "melee")
		var how := "bites"
		if atk.is_empty():
			atk = chip(up, "ranged")     # (the Venom Sire spits from afar: his venom glob, not a bite)
			how = "spits"
		u.tesla_mode = "deployed"
		var dn := UnitStats.of_unit(u)
		var na := chip(dn, "no_attack")
		say(not atk.is_empty() and float(atk["text"]) > 0.0 and not na.is_empty() and float(chip(dn, "armour")["text"]) == a0 + float(Defs.NB["root_armor"]),
			"4. %s: uprooted %s for %s; rooted '%s' (cannot attack), armour %s -> %s" % [k, how, atk.get("text", "?"), na.get("text", "?"), a0, chip(dn, "armour").get("text", "?")])
	# 5. the row in a narrow and a wide rect
	for w in [200.0, 1100.0]:
		var bad := 0
		for k in Defs.UNITS:
			var r := Rect2(0, 0, w, UnitStats.ROW_H)
			# (drawing outside a draw call only warns: this measures the layout)
			var rs: Array = UnitStats.layout(UnitStats.of_kind(k), r)
			for e in rs:
				if (e[0] as Rect2).end.x > r.end.x + 0.5:
					bad += 1
		say(bad == 0, "5. every unit's row fits %d px (%d chips over the edge)" % [int(w), bad])
	# 6. translated: the lines and titles in Portuguese and Spanish
	for code in ["pt", "es"]:
		Loc.set_lang(code)
		var ps := UnitStats.of_kind("musketeer")
		var line := String((ps["specials"] as Array)[0]["line"])
		var ttl := Loc.title(String(chip(ps, "ranged")["title"]))
		say(not line.begins_with("Up close") and ttl != "Ranged attack", "6. %s: '%s' · %s..." % [code, ttl, line.left(40)])
	Loc.set_lang("en")
	print("unit_stats: %d failures" % fails)
	quit(1 if fails > 0 else 0)
