extends SceneTree
## The computer keeps every tech / production / supply building on its Town Hall's own
## plateau (same height level, no ramp cell), and only goes down to lower ground when the
## plateau truly has no room for that building.
##   godot --headless --script res://tools/test_ai_placement.gd [-- map ids...]
## For each map and each faction, a Hard computer (its thinking switched off) is asked for
## spots through the same path its build code uses (AI._find_spot) for a long list of
## buildings, each put up at once. Prints how many ended on another level than the hall
## (and how many of those had plateau room left = the bug), PASS / FAIL, exit 1 on a failure.
const KINDS := {
	"crown": ["cottage", "barracks", "horse_breeder", "foundry", "armoury", "church", "cottage", "barracks", "foundry",
		"cottage", "barracks", "cottage", "foundry", "barracks", "cottage", "barracks", "cottage", "barracks"],
	"clockwork": ["spring_tower", "assembly_works", "engine_hall", "charging_pylon", "capacitor_works", "spring_tower",
		"assembly_works", "spring_tower", "assembly_works", "spring_tower"],
}
var main: Node
var fails := 0
var total_off := 0
var total_bug := 0
var total_n := 0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(ids: Array) -> void:
	if ids.is_empty():
		ids = MapGen.all_ids()
	for id in ids:
		for fac in ["crown", "clockwork"]:      # (the Brood has no buildings since 0.18.0)
			await _one(id, fac)
	print("TOTAL: %d buildings, %d on another level than their hall, %d of those with plateau room left" % [total_n, total_off, total_bug])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func _one(id: String, fac: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": id, "seed": 777, "slots": [
		{"who": "hard", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g == null:
		print("FAIL  %s: no game" % id)
		fails += 1
		return
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var ai: AI = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	var hall: Building = ai._halls()[0]
	var h0 := int(g.height[g.idx(g.cell_of(hall.rect().get_center()))])
	g.players[0]["gold"] = 99999
	var plateau := {}
	for c in g.mapgen.main_area(g.starts[0]):
		plateau[c] = true
	var n := 0
	var off: Array = []
	var bug: Array = []
	var far: Array = []
	for rep in 3:
		for k in KINDS[fac]:
			if not Defs.BUILDINGS.has(k):
				continue
			var spot: Vector2i = ai._find_spot(k)
			if spot.x < 0:
				continue
			var sz: Vector2i = Defs.BUILDINGS[k]["size"]
			if not _on_plateau(g, spot, sz, plateau):
				off.append(k)
				# was there room up top (the main plateau, as far as the AI looks)?
				var alt: Vector2i = g.find_spot(0, k, hall, 0, 40, "near", true)
				if alt.x >= 0 and _on_plateau(g, alt, sz, plateau):
					bug.append(k)
					print("   %s #%d went to %s, plateau had room at %s (hall %s)" % [k, n, spot, alt, hall.rect().get_center() / Defs.TILE])
				# lower ground only at the foot of the nearest ramp (a short walk, not across a cliff)
				var foot := g.ramp_foot(hall)
				var mid := Vector2(spot) + Vector2(sz) * 0.5
				if foot != Vector2.INF and mid.distance_to(foot) > 36.0:
					far.append(k)
			g._add_building(k, 0, spot, true)
			n += 1
	total_n += n
	total_off += off.size()
	total_bug += bug.size()
	var ok := bug.is_empty() and far.is_empty()
	if not far.is_empty():
		print("   far from the ramp: ", far)
	print("%-20s %-9s placed %2d  other level %2d %s  with room up top %2d  %s" % [id, fac, n, off.size(), off, bug.size(), "ok" if ok else "FAIL"])
	if not ok:
		fails += 1
	main.queue_free()
	await process_frame


## Every cell of the footprint is on the hall's own plateau (the connected main area).
func _on_plateau(g: Game, cell: Vector2i, size: Vector2i, plateau: Dictionary) -> bool:
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			if not plateau.has(Vector2i(x, y)):
				return false
	return true
