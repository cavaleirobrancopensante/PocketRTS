extends SceneTree
## THE BROOD MOTHER FITS EVERY RAMP AT EVERY STAGE (the owner, 2026-10-30 07:38/07:43: her picture grows x1.0 / x1.15 /
## x1.3 with her stage, her walking body must still fit the narrowest ramp; BroodNew.BODY_R, docs/brood_fixes.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_mother_ramps.gd [-- ids...] [-- nomain]
## On every built-in map (2 players), at stages 1, 2 and 3, an UPROOTED Mother at every ramp at once (3 tiles wide, and
## the 2-wide ramps of a few middle hills) walks from 3 tiles past its foot to 3 tiles past its top, then back down: each
## must arrive (within 16 px) in time, never standing on or crossing a ramp rail. Then (unless "nomain") at stage 3 a
## Mother walks from beside one start to beside the other (the way crosses the map's chokes, fords and bridges), where a
## ground path exists. Also checks the numbers: her body (radius) at most BODY_R at every stage, her drawn size growing,
## her ground footprint narrower than the narrowest ramp with a margin.
## Prints a line per map and "mother ramps: PASS" / "FAIL (n)".

var fails := 0
var main_walk := true


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _make(id: String) -> Game:
	var g := Game.new()
	g.map_id = id
	g.demo = true
	g.factions = ["crown", "crown"]
	g.sides = [0, 1]
	g.rng.seed = 4242
	root.add_child(g)
	return g


static func _cen(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * Game.T


func _spot(g: Game, p: Vector2, r: float) -> Vector2:
	for k in 10:
		for i in maxi(1, k * 6):
			var q: Vector2 = p + Vector2.from_angle(TAU * i / maxf(1.0, k * 6.0)) * k * 8.0
			var c: Vector2i = g.cell_of(q)
			if g.in_map(c) and g._walkable(c) and g.ramp[g.idx(c)] == 0 and g._clear_at(q, r, 0):
				return q
	return Vector2.INF


func _mother(g: Game, at: Vector2, st: int) -> Unit:
	var q: Unit = g._add_unit(BroodNew.QUEEN, 0, at)
	q.nb["stage"] = st
	BroodNew.apply_stage(q)
	q.auto_work = false
	return q


func _run(args: Array) -> void:
	var ids: Array = args.duplicate()
	if ids.has("nomain"):
		ids.erase("nomain")
		main_walk = false
	if ids.is_empty():
		ids = MapGen.all_ids()
	# the numbers
	var narrow := 99
	for id in ids:
		var g := _make(id)
		await process_frame
		for r in MapGen.ramp_parts(g.mapgen):
			narrow = mini(narrow, (r["rows"][0] as Array).size())
		g.queue_free()
		await process_frame
	var base_r := float(Defs.UNITS[BroodNew.QUEEN]["radius"])
	var sizes := []
	for st in 3:
		var sc := float(Defs.NB["stages"][st]["scale"])
		sizes.append("stage %d: drawn radius %d, body radius %d, ground footprint %d px across" % [st + 1, int(base_r * sc), int(minf(base_r * sc, BroodNew.BODY_R)),
			int(2.0 * 0.6 * minf(minf(base_r * sc, BroodNew.BODY_R), BroodNew.GROUND_R))])
	var foot := 2.0 * 0.6 * BroodNew.GROUND_R
	check(foot <= narrow * Game.T * 0.5 and 0.6 * BroodNew.GROUND_R < Game.T * 0.5 - 1.0, "0. her ground footprint fits the narrowest ramp (%d tiles, %d px) and its side lane (16 px from the rail) with a margin: %s" % [narrow, narrow * Game.T, "; ".join(sizes)])
	for id in ids:
		var g := _make(id)
		await process_frame
		var bad: Array = []
		var parts: Array = MapGen.ramp_parts(g.mapgen)
		var widths := {}
		for r in parts:
			widths[(r["rows"][0] as Array).size()] = true
		for st in 3:
			# every ramp at once: [mother, foot spot, top spot, ramp tag]
			var ms: Array = []
			for r in parts:
				var rows: Array = r["rows"]
				var down: Vector2i = r["down"]
				var top: Array = rows[0]
				var bot: Array = rows[-1]
				var tc := (_cen(top[0]) + _cen(top[-1])) * 0.5
				var bc := (_cen(bot[0]) + _cen(bot[-1])) * 0.5
				var lo := _spot(g, bc + Vector2(down) * 3.0 * Game.T, BroodNew.BODY_R)
				var hi := _spot(g, tc - Vector2(down) * 3.0 * Game.T, BroodNew.BODY_R)
				if lo == Vector2.INF or hi == Vector2.INF:
					continue
				var q := _mother(g, lo, st)
				ms.append([q, lo, hi, "%d-wide ramp at %s" % [top.size(), str(top[0])]])
			for leg in 2:
				var t0 := 0.0
				var done := {}
				for m in ms:
					(m[0] as Unit).cmd_move(m[2] if leg == 0 else m[1])
				var prev := {}
				while t0 < 45.0 and done.size() < ms.size():
					await physics_frame
					t0 += 1.0 / 30.0
					for m in ms:
						var q: Unit = m[0]
						if done.has(q):
							continue
						var goal: Vector2 = m[2] if leg == 0 else m[1]
						var pp: Vector2 = prev.get(q, q.position)
						for rl in g.rails:
							var rr: Rect2 = rl["rect"]
							if Game._seg_hits_rect(pp, q.position, rr.grow(0.01)):
								bad.append("stage %d, %s, %s: crossed a rail at %s" % [st + 1, m[3], "up" if leg == 0 else "down", str(q.position.round())])
						prev[q] = q.position
						if q.position.distance_to(goal) < 16.0:
							done[q] = t0
				for m in ms:
					if not done.has(m[0]):
						var goal: Vector2 = m[2] if leg == 0 else m[1]
						bad.append("stage %d, %s, %s: never got there (%d px from it, at %s)" % [st + 1, m[3], "up" if leg == 0 else "down",
							int((m[0] as Unit).position.distance_to(goal)), str((m[0] as Unit).position.round())])
			for m in ms:
				g.consume_unit(m[0])
			await physics_frame
		var walked := ""
		if main_walk and g.starts.size() >= 2:
			var a := _spot(g, _cen(g.starts[0]) + Vector2(0, 5.0 * Game.T), BroodNew.BODY_R)
			var b := _spot(g, _cen(g.starts[1]) + Vector2(0, 5.0 * Game.T), BroodNew.BODY_R)
			var p := g.find_path(a, b) if a != Vector2.INF and b != Vector2.INF else PackedVector2Array()
			if p.is_empty() or p[p.size() - 1].distance_to(b) > 20.0:
				walked = ", no ground way between the starts"
			else:
				var plen := 0.0
				var last := a
				for v in p:
					plen += last.distance_to(v)
					last = v
				var q := _mother(g, a, 2)
				q.cmd_move(b)
				var t1 := 0.0
				var lim := plen / maxf(q.speed, 1.0) * 1.6 + 15.0
				while t1 < lim and q.position.distance_to(b) >= 16.0:
					await physics_frame
					t1 += 1.0 / 30.0
				if q.position.distance_to(b) >= 16.0:
					bad.append("stage 3, start to start (%d px of path): stuck %d px from it at %s after %d s" % [int(plen), int(q.position.distance_to(b)), str(q.position.round()), int(t1)])
				walked = ", start to start %d px in %d s" % [int(plen), int(t1)]
				g.consume_unit(q)
		print("%-18s ramps %d (widths %s)%s  %s" % [id, parts.size(), str(widths.keys()), walked, "ok" if bad.is_empty() else "BAD"])
		for x in bad:
			print("    " + x)
		fails += bad.size()
		g.queue_free()
		await process_frame
	print("mother ramps: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1
