extends SceneTree
## Gear sizes (and a swap under way) survive a save and load and travel in the online snapshot; the guest works out the
## same connected field and turns the gears.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_save.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _find(g: Game, kind: String, cell: Vector2i) -> Building:
	for b in g.buildings:
		if b.kind == kind and b.cell == cell and not b.dead:
			return b
	return null


func _run() -> void:
	var g := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	var tower := U.hall(g, 0)
	g.players[0]["gold"] = 5000
	var press: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS:
			press = b
	press.gear_big = true
	var works := U.put(g, 0, "assembly_works", tower.cell, false)
	U.step(g, 1.0)
	# ---- the save
	SaveGame.save(g, {"map": "ashford_crossing", "seed": 4242})
	var d := SaveGame.peek()
	var g2 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g2, d)
	await process_frame
	var press2 := _find(g2, Defs.GEAR_PRESS, press.cell)
	var works2 := _find(g2, "assembly_works", works.cell)
	check("the saved BIG gear is big after a load", press2 != null and press2.gear_big)
	check("the small-gear works stays small after a load", works2 != null and not works2.gear_big)
	# an old save with a gear swap under way ("gs", "gst": the swap was removed in 0.24.4) still loads, the fields ignored
	var old := d.duplicate(true)
	for bd in old.get("buildings", []):
		if bd is Dictionary and bd.has("gb"):
			bd["gs"] = 2.5
			bd["gst"] = true
	var g3 := U.make(root, ["clockwork", "crown"], "", false)
	await process_frame
	await process_frame
	SaveGame.restore(g3, old)
	await process_frame
	var works3 := _find(g3, "assembly_works", works.cell)
	check("an old save with a gear swap under way loads (the swap ignored)", works3 != null and not works3.gear_big)
	g2.gear_net.solve()
	check("the loaded game connects its field again", works2 != null and g2.gear_net.linked.has(press2))
	SaveGame.clear()
	# ---- the online snapshot: host (g) -> guest (a puppet)
	var hs := NetSession.new()
	hs.game = g
	hs.is_host = true
	g.net = hs
	var m := NetSnapshot.build(hs)
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
	var gp := _find(guest, Defs.GEAR_PRESS, press.cell)
	var gw := _find(guest, "assembly_works", works.cell)
	check("the guest sees the host's BIG gear", gp != null and gp.gear_big)
	check("and the small gear of the works", gw != null and not gw.gear_big)
	guest.gear_net.tick(0.1)
	guest.gear_net.tick(0.1)
	var gt := U.hall(guest, 0)
	check("the guest works out the same connected field", gt != null and guest.gear_net.linked.size() >= 3 and guest.gear_net.linked.has(gp))
	var a0: float = guest.gear_net.ang.get(gt, 0.0)
	guest.gear_net.tick(0.5)
	check("and the guest sees the gears turn", absf(float(guest.gear_net.ang.get(gt, 0.0)) - a0) > 0.001)
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
