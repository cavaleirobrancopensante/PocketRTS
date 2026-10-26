extends SceneTree
## THE LEVEL RULE (scripts/gear.gd; owner, 2026-10-26: "you can link a gear down from the high ground to low ground, this
## should not be possible"): gear rings mesh only on the same ground level. A building's level is its footprint's height (a
## ramp is low ground; no building stands on one); two rings of buildings on different levels never link, however close,
## across a cliff or along a ramp; and where two rings on one level meet, the ground is on that level too (the contact point,
## or the idler's spot: no idler across a cliff).
##   The cases: a Clocktower on the high ground by a cliff and a Regulator spot on the low ground below whose ring reaches its
##   ring (and the same along a ramp when the map has one): the placement ghost says NO LINK: OTHER LEVEL, placing is refused
##   with the reason, the efficiency preview has no %, a Regulator put there anyway stays UNLINKED with no idler; a Regulator
##   on the Clocktower's own level links. joint_ok on its own: a contact point or an idler over the other level is refused.
##   Every idler of the home field sits on its rings' level. The computer's site choice (GearEcon.room_spot, GearNet.ring_spot)
##   never picks the other level.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_levels.gd
const U := preload("res://tools/gear_test_util.gd")
const REG := "regulator"
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: GearNet = g.gear_net
	g.players[0]["gold"] = 50000
	var hall := U.hall(g, 0)
	check("the map has two ground levels", g.height.has(0) and g.height.has(1))
	# ---------------------------------------------------------------- every idler of the home field sits on its level
	for k in [Defs.CW_SUPPLY, Defs.CW_SUPPLY, Defs.CW_WORKS, "mainspring", Defs.CW_SUPPLY]:
		U.put(g, 0, k, hall.cell + Vector2i(0, 6))
	net.solve()
	var idlers := 0
	var off := 0
	for b in net.idler_of:
		idlers += 1
		if GearNet.level_at(g, Vector2(net.idler_of[b]["pos"])) != GearNet.b_level(b):
			off += 1
	check("every idler of the home field (%d) sits on its rings' level" % idlers, off == 0, "%d off" % off)
	var cross := 0
	for b in net.linked:
		var p: Building = net.parent_of.get(b)
		if p != null and GearNet.b_level(p) != GearNet.b_level(b):
			cross += 1
	check("no link of the home field joins two levels", cross == 0, "%d" % cross)
	# ---------------------------------------------------------------- joint_ok on its own
	var lowc := _deep_cell(g, 0, 4)
	var highc := _deep_cell(g, 1, 4)
	check("found low ground and high ground away from any cliff", lowc.x >= 0 and highc.x >= 0, "%s %s" % [str(lowc), str(highc)])
	if lowc.x >= 0:
		var m := GearNet.gpos(g.cell_center(lowc))
		var ra := 90.0
		var rb := 60.0
		var u := Vector2(1, 0)
		check("a direct mesh whose contact point is on the low ground: fine for low rings", GearNet.joint_ok(g, m - u * ra, ra, m + u * rb, rb, 0))
		check("... and refused for two high-ground rings (they would meet over the low ground)", not GearNet.joint_ok(g, m - u * ra, ra, m + u * rb, rb, 1))
		var gap := float(Defs.TILE) * 1.2
		var ca := m - u * (ra + gap * 0.5)
		var cb := m + u * (rb + gap * 0.5)
		var spots := GearNet.idler_spots(ca, ra, cb, rb)
		check("a gap gets an idler: two spots", spots.size() == 2, str(spots))
		check("both idler spots are on the low ground here", spots.size() == 2 and GearNet.level_at(g, spots[0]) == 0 and GearNet.level_at(g, spots[1]) == 0)
		check("an idler on the low ground joins two low rings", GearNet.joint_ok(g, ca, ra, cb, rb, 0))
		check("but never two high-ground rings (no idler across a cliff)", not GearNet.joint_ok(g, ca, ra, cb, rb, 1))
		var idl := GearNet.idler_for(ca, ra, cb, rb, [], g, 1)
		check("idler_for still draws one (the best of both) when neither spot is on the level", not idl.is_empty())
	# ---------------------------------------------------------------- a Clocktower by a cliff, a Regulator spot below it
	var pairs := _pairs(g, hall)
	check("found a high-ground Clocktower spot by a cliff with a low-ground Regulator spot in ring reach", pairs.has("cliff"), str(pairs.keys()))
	for kind_of in ["cliff", "ramp"]:
		if not pairs.has(kind_of):
			print("(no %s pair on this map: skipped)" % kind_of)
			continue
		var pr: Array = pairs[kind_of]
		var ct: Vector2i = pr[0]
		var cr: Vector2i = pr[1]
		var tw := g._add_building("clocktower", 0, ct, true)
		net.solve()
		var gap := GearNet.gpos(Vector2(cr) * Defs.TILE + Vector2(Defs.BUILDINGS[REG]["size"]) * Defs.TILE * 0.5).distance_to(GearNet.b_c(tw)) \
			- GearNet.ring_r(REG, Defs.BUILDINGS[REG]["size"], false) - GearNet.b_r(tw)
		print("  %s pair: Clocktower at %s (level %d), Regulator spot at %s (level %d), ring gap %.0f px (link gap %.0f)" % [kind_of, str(ct), GearNet.b_level(tw), str(cr),
			GearNet.foot_level(g, cr, Defs.BUILDINGS[REG]["size"]), gap, float(Defs.GEAR["slack"]) * Defs.TILE])
		var st := net.candidate(0, REG, cr)
		check("[%s] the ring reaches the Clocktower's, but on the other level: no link" % kind_of, st["state"] == "far" and st.get("level", false), str(st))
		var gt := net.ghost_text(0, REG, cr)
		check("[%s] the ghost says NO LINK: OTHER LEVEL" % kind_of, String(gt[0]) == "NO LINK: OTHER LEVEL", String(gt[0]))
		var why := g.placement_problem(0, REG, cr)
		check("[%s] placing it is refused, and the reason names the ground level" % kind_of, why.contains("same ground level"), why)
		check("[%s] the efficiency preview has no %% there" % kind_of, GearEcon.preview_steps(net, 0, Defs.CW_WORKS, cr) < 0 and GearEcon.ghost_note(net, 0, Defs.CW_WORKS, cr) == "")
		var low := g._add_building(REG, 0, cr, true)
		net.solve()
		check("[%s] a Regulator put there anyway stays UNLINKED" % kind_of, not net.is_linked(low) and not net.parent_of.has(low))
		check("[%s] with no idler and no drive" % kind_of, not net.idler_of.has(low) and not net.drive_of.has(low))
		# the same level links
		var same := _same_level_spot(g, tw, cr)
		if same.x >= 0:
			var hi := g._add_building(REG, 0, same, true)
			net.solve()
			check("[%s] a Regulator on the Clocktower's level in reach links (drive 1)" % kind_of, net.is_linked(hi) and int(net.drive_of.get(hi, -1)) == 1,
				"at %s, steps %d" % [str(same), int(net.drive_of.get(hi, -1))])
			g._remove_quietly(hi)
		else:
			check("[%s] (no same-level spot by this Clocktower: skipped)" % kind_of, true)
		# the computer's site choice keeps to the level
		var rs := GearEcon.room_spot(g, 0, REG, [tw], [], g.cell_center(cr))
		check("[%s] the computer's room_spot by the Clocktower stays on its level" % kind_of, rs.x < 0 or GearNet.foot_level(g, rs, Defs.BUILDINGS[REG]["size"]) == GearNet.b_level(tw), str(rs))
		var deg := rad_to_deg((g.cell_center(cr) - tw.center()).angle())
		var ring := GearNet.ring_spot(g, 0, REG, tw, deg, true)
		check("[%s] ring_spot towards the low spot stays on the Clocktower's level" % kind_of, ring.x < 0 or GearNet.foot_level(g, ring, Defs.BUILDINGS[REG]["size"]) == GearNet.b_level(tw),
			"%s at %.0f deg" % [str(ring), deg])
		g._remove_quietly(low)
		g._remove_quietly(tw)
		net.solve()
	_end()


## A cell of `level` with no cell of the other level (nor a ramp or a cliff) within `pad` cells; (-1, -1) when none.
func _deep_cell(g: Game, level: int, pad: int) -> Vector2i:
	for y in range(pad, Game.H - pad):
		for x in range(pad, Game.W - pad):
			var ok := true
			for dy in range(-pad, pad + 1):
				for dx in range(-pad, pad + 1):
					var i := g.idx(Vector2i(x + dx, y + dy))
					if int(g.height[i]) != level or g.ramp[i] == 1 or g.cliff[i] == 1:
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A footprint of `size` at c on free buildable ground, all of it on `level`.
func _ground(g: Game, c: Vector2i, size: Vector2i, level: int) -> bool:
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if not g.in_map(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] == 1 or int(g.height[g.idx(cc)]) != level:
				return false
	return g.margin_free(c, size)


## {"cliff": [Clocktower cell, Regulator cell], "ramp": [...]}: a Clocktower spot on the high ground and a Regulator spot on
## the low ground whose rings are within the link gap (not clashing), at least 26 cells from team 0's own Clocktower (so
## nothing else of the field is near); "ramp" when the line between them crosses a ramp, "cliff" when it crosses a cliff.
func _pairs(g: Game, hall: Building) -> Dictionary:
	var out := {}
	var ts: Vector2i = Defs.BUILDINGS["clocktower"]["size"]
	var rs: Vector2i = Defs.BUILDINGS[REG]["size"]
	var rt := GearNet.ring_r("clocktower", ts, false)
	var rg := GearNet.ring_r(REG, rs, false)
	var slack := float(Defs.GEAR["slack"]) * Defs.TILE
	var over := float(Defs.GEAR["overlap"]) * Defs.TILE
	for y in range(2, Game.H - ts.y - 2):
		for x in range(2, Game.W - ts.x - 2):
			if out.size() >= 2:
				return out
			var ct := Vector2i(x, y)
			if Vector2(ct - hall.cell).length() < 26.0:
				continue
			if not _near_edge(g, ct + ts / 2, 5) or not _ground(g, ct, ts, 1):
				continue
			var tc := GearNet.gpos(Vector2(ct) * Defs.TILE + Vector2(ts) * Defs.TILE * 0.5)
			for yy in range(y - 10, y + 12):
				for xx in range(x - 10, x + 12):
					var cr := Vector2i(xx, yy)
					if not _ground(g, cr, rs, 0):
						continue
					var rc := GearNet.gpos(Vector2(cr) * Defs.TILE + Vector2(rs) * Defs.TILE * 0.5)
					var gap := rc.distance_to(tc) - rt - rg
					if gap < -over * 0.8 or gap > slack * 0.8:
						continue
					var kind := _crossing(g, Vector2(ct) * Defs.TILE + Vector2(ts) * Defs.TILE * 0.5, Vector2(cr) * Defs.TILE + Vector2(rs) * Defs.TILE * 0.5)
					if kind != "" and not out.has(kind):
						out[kind] = [ct, cr]
	return out


## A cliff or a ramp cell within r cells of c.
func _near_edge(g: Game, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cc := c + Vector2i(dx, dy)
			if g.in_map(cc) and (g.cliff[g.idx(cc)] == 1 or g.ramp[g.idx(cc)] == 1):
				return true
	return false


## "ramp" when the straight line a-b (world px) crosses a ramp cell and no cliff cell, "cliff" when it crosses a cliff cell, else "".
func _crossing(g: Game, a: Vector2, b: Vector2) -> String:
	var ramp := false
	for i in 41:
		var cc := g.cell_of(a.lerp(b, float(i) / 40.0))
		if not g.in_map(cc):
			continue
		if g.cliff[g.idx(cc)] == 1:
			return "cliff"
		if g.ramp[g.idx(cc)] == 1:
			ramp = true
	return "ramp" if ramp else ""


## A Regulator spot on `tw`'s level whose ring meshes with tw's ring, nearest `near` first; (-1, -1) when none.
func _same_level_spot(g: Game, tw: Building, near: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(tw.cell.y - 12, tw.cell.y + 14):
		for x in range(tw.cell.x - 12, tw.cell.x + 14):
			var c := Vector2i(x, y)
			if not g.in_map(c) or g.placement_problem(0, REG, c) != "" or not g.margin_free(c, Vector2i(2, 2)):
				continue
			var st := g.gear_net.candidate(0, REG, c)
			if st["state"] != "ok" or st.get("with") != tw:
				continue
			var d := Vector2(c - near).length()
			if d < bd:
				bd = d
				best = c
	return best


func _end() -> void:
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
