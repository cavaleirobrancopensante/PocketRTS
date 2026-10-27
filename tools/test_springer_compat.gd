extends SceneTree
## The Springer was called "jack" inside the game until 0.14.82. A save, a replay or an online snapshot from before still
## carries "jack" (a unit's kind and art, a building's queue and auto-train, kills by kind, the log's first-of keys): each
## must come back as a Springer (Defs.OLD_UNIT_KINDS, Defs.unit_kind). The test writes today's data, turns every
## "springer" in it back into "jack" (as an old version wrote it) and reads it in again.
##   godot --headless --fixed-fps 30 --script res://tools/test_springer_compat.gd
const U := preload("res://tools/gear_test_util.gd")
const OLD := "jack"
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## Today's data as an old version wrote it: every "springer" (a value, a key, or a "team:springer" key) as "jack".
func _old(v):
	if v is String or v is StringName:
		var s := String(v)
		if s == Defs.SPRINGER:
			return OLD
		if s.ends_with(":" + Defs.SPRINGER):
			return s.trim_suffix(Defs.SPRINGER) + OLD
		return v
	if v is Array:
		var a: Array = (v as Array).duplicate()
		for i in a.size():
			a[i] = _old(a[i])
		return a
	if v is Dictionary:
		var d := {}
		for k in v:
			d[_old(k)] = _old(v[k])
		return d
	return v


func _count(g: Game, kind: String) -> int:
	return g.units.filter(func(u: Unit) -> bool: return u.kind == kind and not u.dead).size()


func _works(g: Game) -> Building:
	for b in g.buildings:
		if b.team == 0 and b.kind == "movement_works" and not b.dead:
			return b
	return null


func _run() -> void:
	check("Defs.unit_kind maps the old id", Defs.unit_kind(OLD) == Defs.SPRINGER and Defs.SPRINGER == "springer")
	check("and leaves today's ids alone", Defs.unit_kind("springer") == "springer" and Defs.unit_kind("clock_soldier") == "clock_soldier")
	check("no unit or building is called jack any more", not Defs.UNITS.has(OLD) and not Defs.BUILDINGS.has(OLD) and not ArtData.UNITS.has(OLD))
	var g := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	var tower := U.hall(g, 0)
	g.players[0]["gold"] = 5000
	var works := U.put(g, 0, "movement_works", tower.cell)
	check("a Movement Works stands", works != null)
	if works == null:
		print("RESULT: %d failures" % fails)
		quit(1)
		return
	works.queue = [Defs.SPRINGER]
	works.kits = [{}]
	works.auto_train = Defs.SPRINGER
	var sp: Unit = g._add_unit(Defs.SPRINGER, 0, tower.center() + Vector2(0, 160))
	sp.cmd_stop()
	g.stats[0]["kills_by"][Defs.SPRINGER] = 3
	g._first_of["0:" + Defs.SPRINGER] = true
	U.step(g, 0.5)
	# ---- an old save
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 4242})
	var d: Dictionary = _old(SaveGame.peek())
	var saved_old := (d["units"] as Array).any(func(ud) -> bool: return String(ud["k"]) == OLD)
	check("the old save carries \"jack\"", saved_old)
	var g2 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g2, d)
	await process_frame
	check("an old save's Jack loads as a Springer", _count(g2, Defs.SPRINGER) == 1 and _count(g2, OLD) == 0, "%d springers, %d jacks" % [_count(g2, Defs.SPRINGER), _count(g2, OLD)])
	var w2 := _works(g2)
	check("its Works' queue holds a Springer", w2 != null and w2.queue == [Defs.SPRINGER], str(w2.queue if w2 else []))
	check("and it keeps auto-training Springers", w2 != null and w2.auto_train == Defs.SPRINGER, w2.auto_train if w2 else "")
	check("kills by kind count the Springer", int(g2.stats[0]["kills_by"].get(Defs.SPRINGER, 0)) == 3 and not g2.stats[0]["kills_by"].has(OLD))
	check("the log's first-of keys name the Springer", g2._first_of.has("0:" + Defs.SPRINGER) and not g2._first_of.has("0:" + OLD))
	SaveGame.clear()
	# ---- an old online snapshot / replay picture: host (g) -> guest
	var hs := NetSession.new()
	hs.game = g
	hs.is_host = true
	g.net = hs
	var m: Dictionary = _old(NetSnapshot.build(hs))
	var rows_old := (m.get("u", []) as Array).any(func(r) -> bool: return String(r[1]) == OLD)
	check("the old snapshot carries \"jack\"", rows_old)
	var guest := Game.new()
	guest.puppet = true
	guest.map_id = "ashford_crossing"
	guest.demo = true
	guest.factions = ["clockwork", "crown"]
	guest.sides = [0, 1]
	root.add_child(guest)
	await process_frame
	var gs := NetSession.new()
	gs.game = guest
	gs.is_host = false
	guest.net = gs
	NetSnapshot.apply(gs, m)
	check("the guest makes a Springer of an old row", _count(guest, Defs.SPRINGER) == 1 and _count(guest, OLD) == 0, "%d springers, %d jacks" % [_count(guest, Defs.SPRINGER), _count(guest, OLD)])
	var gsp: Array = guest.units.filter(func(u: Unit) -> bool: return u.kind == Defs.SPRINGER)
	check("wearing the Springer's art", not gsp.is_empty() and (gsp[0] as Unit).art == Defs.SPRINGER, (gsp[0] as Unit).art if not gsp.is_empty() else "")
	var gw := _works(guest)
	check("the guest's Works queues a Springer and auto-trains them", gw != null and gw.queue == [Defs.SPRINGER] and gw.auto_train == Defs.SPRINGER,
		"%s / %s" % [str(gw.queue), gw.auto_train] if gw else "")
	# ---- an old replay's picture (ReplayPlayer._sanitize: an unknown kind would be drawn as a greyed placeholder)
	var rp := ReplayPlayer.new()
	var pic := {"u": [[77, OLD, 0, Vector2(10, 10), 90.0, 0.0]]}
	rp._sanitize(pic)
	check("an old replay's Jack is shown as a Springer, not a placeholder", String(pic["u"][0][1]) == Defs.SPRINGER and not rp._ph.has(77), String(pic["u"][0][1]))
	rp.free()
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
