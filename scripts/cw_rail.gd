class_name CwRail
extends RefCounted
## Rail-bound movement of the Clockwork roster prototype (docs/clockwork_units_prototype.md) and the SIDINGS.
## A rail unit (Defs.CW_RAIL) is an ordinary Unit whose paths are made over the finished Line segments of its team
## (the orders, targeting and cards all work as for any unit), whose position is snapped back onto the track after every
## step, and whose speed follows the pressure under it. Scripts/cw_units.gd calls into here from unit.gd.

const T := Defs.TILE
const DIRS := LineNetwork.DIRS


# ------------------------------------------------------------------ who and where

## Is this unit tied to the rails right now (a rail kind that is not set up off them)?
static func bound(u: Unit) -> bool:
	return Defs.CW_RAIL.has(u.kind) and not bool(u.cw.get("off", false)) and not u.dead


static func net_of(u: Unit) -> LineNetwork:
	return u.game.line_net


static func _seg_ok(net: LineNetwork, t: int, c: Vector2i) -> bool:
	var s: PipeSeg = net.segs.get(c)
	return s != null and s.team == t and s.built and not s.dead


## The finished segment under (or next to) a unit, or (-1, -1).
static func cell_near(u: Unit) -> Vector2i:
	return net_of(u).rails.nearest_cell(u.team, u.position, 2)


## The cells to run from `from` toward a world point over the finished Line of team t: the reachable cell nearest to
## the point (fewest steps on a tie), as the cells in order, both ends included. [] if `from` is not on the Line.
static func route_toward(net: LineNetwork, t: int, from: Vector2i, point: Vector2) -> Array:
	if not _seg_ok(net, t, from):
		return []
	var game := net.game
	var prev := {from: from}
	var q: Array = [from]
	var i := 0
	var best := from
	var bd: float = game.cell_center(from).distance_squared_to(point)
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		var dd: float = game.cell_center(cur).distance_squared_to(point)
		if dd < bd - 1.0:
			bd = dd
			best = cur
		for d in DIRS:
			var n: Vector2i = cur + d
			if not prev.has(n) and _seg_ok(net, t, n):
				prev[n] = cur
				q.append(n)
	var path: Array = [best]
	while path[path.size() - 1] != from:
		path.append(prev[path[path.size() - 1]])
	path.reverse()
	return path


## The waypoints (cell centres) for a rail unit going toward `goal`; empty when it is not on the Line.
static func plan(u: Unit, goal: Vector2) -> PackedVector2Array:
	var net := net_of(u)
	var c0 := cell_near(u)
	var out := PackedVector2Array()
	if c0.x < 0:
		return out
	var cells := route_toward(net, u.team, c0, goal)
	for i in cells.size():
		out.append(u.game.cell_center(cells[i]))
	# already past the first centre on the way to the second: do not turn back for it
	if out.size() > 1 and (u.position - out[0]).dot(out[1] - out[0]) > 0.0:
		out.remove_at(0)
	return out


## Pull a rail unit back onto the track (the nearest point of the Line's centre lines).
static func snap(u: Unit) -> void:
	var net := net_of(u)
	var game := u.game
	var c := game.cell_of(u.position)
	var best := u.position
	var bd := INF
	for k in [Vector2i.ZERO] + DIRS:
		var cc: Vector2i = c + k
		if not _seg_ok(net, u.team, cc):
			continue
		var a := game.cell_center(cc)
		var da := a.distance_squared_to(u.position)
		if da < bd:
			bd = da
			best = a
		for d in DIRS:
			var nn: Vector2i = cc + d
			if not _seg_ok(net, u.team, nn):
				continue
			var b := game.cell_center(nn)
			var ab := b - a
			var tt := clampf((u.position - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
			var qp := a + ab * tt
			var dq := qp.distance_squared_to(u.position)
			if dq < bd:
				bd = dq
				best = qp
	if bd < INF and bd < 96.0 * 96.0:
		# two tracks: drive on the right of the way it goes (Train.lane_of)
		var vd: Vector2i = u.cw.get("lane_d", Vector2i.ZERO)
		if u.velocity.length() > 8.0:
			vd = Vector2i(int(signf(u.velocity.x)), 0) if absf(u.velocity.x) >= absf(u.velocity.y) else Vector2i(0, int(signf(u.velocity.y)))
			u.cw["lane_d"] = vd
		u.position = best + (Train.lane_of(vd) if vd != Vector2i.ZERO else Vector2.ZERO)


## The pressure's share of its speed under a rail unit (1.0 with enforcement off).
static func speed_mult(u: Unit) -> float:
	var net := net_of(u)
	if not net.enforce:
		return 1.0
	var s: PipeSeg = net.segs.get(u.game.cell_of(u.position))
	if s == null:
		return 1.0
	return Defs.line_speed(s.pressure)


## Where a rail vehicle trained at building b appears: the Line cell beside it nearest to the rally point.
## (-1, -1) if no finished segment touches the building.
static func spawn_cell(game: Game, b: Building, toward: Vector2) -> Vector2i:
	var acc := game.line_net.rails.access_cells(b.team, b)
	var best := Vector2i(-1, -1)
	var bd := INF
	for c in acc:
		var dd: float = game.cell_center(c).distance_squared_to(toward)
		if dd < bd:
			bd = dd
			best = c
	return best


# ------------------------------------------------------------------ sidings

## Why team t cannot put a siding on cell c ("" if it can): a straight, finished segment with a free side and
## no other siding within `gap` tiles.
static func siding_problem(game: Game, t: int, c: Vector2i) -> String:
	var net := game.line_net
	var s: PipeSeg = net.segs.get(c)
	if s == null or s.team != t or not s.built:
		return "Tap a finished piece of your Line."
	if net.sidings.has(c):
		return "There is a siding here already."
	var m := net._mask(s) | net._building_mask(s)
	if m != 5 and m != 10:
		return "A siding needs a straight piece with no joint."
	if int(game.players[t]["gold"]) < int(Defs.CW["siding"]["cost"]):
		return "Not enough ore."
	if side_for(game, t, c) == Vector2i.ZERO:
		return "No free ground beside it for the side arm."
	var gap := int(Defs.CW["siding"]["gap"])
	for o in net.sidings:
		if absi(o.x - c.x) < gap and absi(o.y - c.y) < gap:
			return "Too close to another siding (%d tiles apart at least)." % gap
	return ""


## The free side of a straight piece (the first free of the two), or ZERO.
static func side_for(game: Game, t: int, c: Vector2i) -> Vector2i:
	var net := game.line_net
	var s: PipeSeg = net.segs.get(c)
	if s == null:
		return Vector2i.ZERO
	var m := net._mask(s) | net._building_mask(s)
	var sides: Array = [Vector2i(0, -1), Vector2i(0, 1)] if m == 10 else [Vector2i(-1, 0), Vector2i(1, 0)]
	for sd in sides:
		var n: Vector2i = c + sd
		if game.in_map(n):
			var i := game.idx(n)
			if game.solid[i] == 0 and game.cliff[i] == 0 and game.water[i] == 0 and not net.segs.has(n):
				return sd
	return Vector2i.ZERO


## Build (or, on a cell that has one, remove) a siding. Returns "" or the reason it was refused.
static func toggle_siding(game: Game, t: int, c: Vector2i) -> String:
	var net := game.line_net
	if net.sidings.has(c) and net.segs.has(c) and net.segs[c].team == t:
		net.sidings.erase(c)
		net.changed()
		return ""
	var why := siding_problem(game, t, c)
	if why != "":
		return why
	game.players[t]["gold"] -= int(Defs.CW["siding"]["cost"])
	net.sidings[c] = side_for(game, t, c)
	net.changed()
	return ""


## The little side arm drawn beside the track (code art: docs/art_style_inconsistency.md).
static func draw_siding(cv: Node2D, o: Vector2, side: Vector2i, built: bool) -> void:
	var sd := Vector2(side)
	var perp := Vector2(-sd.y, sd.x)
	var a := 0.95 if built else 0.4
	var dark := Color(0.10, 0.10, 0.12, a)
	var steel := Color(0.34, 0.36, 0.40, a)
	var base := o + sd * 8.0
	var tip := o + sd * 22.0
	cv.draw_line(base + perp * 0.0, tip, dark, 12.0)
	cv.draw_line(base, tip, steel, 9.0)
	for k in 3:
		var q := o + sd * (11.0 + 4.0 * k)
		cv.draw_line(q + perp * 5.0, q - perp * 5.0, Color(0.28, 0.17, 0.09, a), 2.0)
	cv.draw_line(base + perp * 2.6, tip + perp * 2.6, Color(0.75, 0.77, 0.8, a), 1.2)
	cv.draw_line(base - perp * 2.6, tip - perp * 2.6, Color(0.75, 0.77, 0.8, a), 1.2)
	cv.draw_line(tip + perp * 6.0, tip - perp * 6.0, Color(0.9, 0.7, 0.2, a), 2.5)      # the buffer at the end


## Every vehicle of the team on the rails: [position, direction (ZERO standing), priority, the thing].
static func vehicles(game: Game, t: int) -> Array:
	var out: Array = []
	for tr in game.line_net.rails.trains:
		if is_instance_valid(tr) and not tr.dead and tr.team == t and tr.state != "in_siding":
			out.append([tr.global_position, Vector2(tr.dir), 2, tr])
	for u in game.units:
		if u.team == t and not u.dead and not u.off_field and bound(u):
			var v: Vector2 = u.velocity
			out.append([u.position, v.normalized() if v.length() > 8.0 else Vector2.ZERO, 1, u])
	return out


## The nearest siding cell within `reach` steps of `from` along the Line with nobody in it, or (-1, -1).
static func find_siding(game: Game, t: int, from: Vector2i, me: Unit) -> Vector2i:
	var net := game.line_net
	if net.sidings.is_empty():
		return Vector2i(-1, -1)
	var reach := int(Defs.CW["siding"]["reach"])
	var dist := {from: 0}
	var q: Array = [from]
	var i := 0
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		if net.sidings.has(cur) and _siding_free(game, t, cur, me):
			return cur
		if dist[cur] >= reach:
			continue
		for d in DIRS:
			var n: Vector2i = cur + d
			if not dist.has(n) and _seg_ok(net, t, n):
				dist[n] = dist[cur] + 1
				q.append(n)
	return Vector2i(-1, -1)


static func _siding_free(game: Game, t: int, c: Vector2i, me: Unit) -> bool:
	for u in game.units:
		if u != me and u.team == t and not u.dead and u.cw.has("sid") and u.cw["sid"]["cell"] == c:
			return false
	return true


## The vehicle ahead of `u` in its own lane (same way, within `follow` px, not a lane over), or null: [thing, speed, gap].
static func _leader(game: Game, u: Unit, wdir: Vector2) -> Array:
	var follow := float(Defs.CW["siding"].get("follow", 34.0))
	var best: Array = []
	var bg := follow
	for v in vehicles(game, u.team):
		var o = v[3]
		if o == u:
			continue
		var od: Vector2 = v[1]
		var vel: Vector2 = o.velocity if o is Unit else od * float(Defs.TRAINS[o.tkind]["speed"]) * T
		var standing: bool = od == Vector2.ZERO
		if standing and not (o is Unit):
			continue                           # (a train waiting at a stop does not block a rail unit)
		var rel: Vector2 = v[0] - u.position
		var ahead := rel.dot(wdir)
		if ahead <= 0.0 or ahead > follow:
			continue
		if absf(rel.dot(Vector2(-wdir.y, wdir.x))) > 6.5:
			continue                           # the other lane
		if not standing and od.dot(wdir) < 0.5:
			continue
		if ahead < bg:
			bg = ahead
			best = [o, vel.length(), ahead]
	return best


## Called every tick for a rail unit with the movement it wants; returns the movement it will make. Two tracks, one
## per direction (drive on the right): vehicles going opposite ways pass; one queues only behind a vehicle ahead going the
## SAME way in its own lane (it keeps the leader's speed and stops a few px behind it). The siding rule: a slow
## vehicle (or a standing one) that a faster one comes up behind in its lane, or that has a queue behind it, goes into
## a free siding within `reach` cells, waits there until the others have passed, and rejoins; with no siding near it
## the queue gives up after a few seconds and passes through (nobody waits for ever).
static func steer(u: Unit, want: Vector2, delta: float) -> Vector2:
	var game := u.game
	var net := game.line_net
	var sid: Dictionary = u.cw.get("sid", {})
	var cfg: Dictionary = Defs.CW["siding"]
	if sid.is_empty():
		var out := want
		u.cw.erase("q_for")
		if want.length() > 1.0:
			var ld := _leader(game, u, want.normalized())
			if not ld.is_empty():
				u.cw["q_t"] = float(u.cw.get("q_t", 0.0)) + delta
				if float(u.cw["q_t"]) < 6.0:
					u.cw["q_for"] = ld[0]
					if float(ld[2]) < float(cfg.get("stop_gap", 24.0)):
						out = Vector2.ZERO
					else:
						out = want.normalized() * minf(want.length(), maxf(float(ld[1]), 14.0))
				elif float(u.cw["q_t"]) > 9.0:
					u.cw["q_t"] = 0.0           # (gave up waiting: passed through for a few seconds, then looks again)
			else:
				u.cw["q_t"] = maxf(0.0, float(u.cw.get("q_t", 0.0)) - delta * 2.0)
		if net.sidings.is_empty():
			return out
		u.cw["sid_scan"] = float(u.cw.get("sid_scan", 0.0)) - delta
		if float(u.cw["sid_scan"]) > 0.0:
			return out
		u.cw["sid_scan"] = 0.3
		_look_for_meeting(u)
		return out
	var c: Vector2i = sid["cell"]
	if not net.sidings.has(c) or not _seg_ok(net, u.team, c):
		u.cw.erase("sid")
		return want
	var ctr := game.cell_center(c)
	var spot := ctr + Vector2(net.sidings[c]) * float(cfg["offset"])
	sid["t"] = float(sid["t"]) + delta
	match String(sid["phase"]):
		"to":
			var pts: PackedVector2Array = sid["path"]
			while not pts.is_empty() and u.position.distance_to(pts[0]) < 7.0:
				pts.remove_at(0)
			sid["path"] = pts
			if pts.is_empty():
				sid["phase"] = "in"
				return Vector2.ZERO
			return (pts[0] - u.position).normalized() * u.speed
		"in":
			if u.position.distance_to(spot) < 3.0:
				sid["phase"] = "wait"
				sid["t"] = 0.0
				return Vector2.ZERO
			return (spot - u.position).normalized() * minf(u.speed, 30.0)
		"wait":
			u.position = spot
			if float(sid["t"]) >= float(cfg["hold_min"]) and (float(sid["t"]) >= float(cfg["hold_max"]) or _track_clear(game, u, ctr)):
				sid["phase"] = "out"
			return Vector2.ZERO
		_:
			if u.position.distance_to(ctr) < 3.0:
				u.position = ctr
				u.cw.erase("sid")
				u.cw["sid_scan"] = 2.0
				if (u.order == "move" or u.order == "amove") and u.path_goal != Vector2.INF:
					u._request_path(u.path_goal)          # on its way again
				return Vector2.ZERO
			return (ctr - u.position).normalized() * minf(u.speed, 30.0)


## Nobody coming along the track within a few cells of the siding?
static func _track_clear(game: Game, me: Unit, ctr: Vector2) -> bool:
	var near := float(Defs.CW["siding"]["meet"] + 1) * T
	for v in vehicles(game, me.team):
		if v[3] == me:
			continue
		var p: Vector2 = v[0]
		if p.distance_to(ctr) < near and ((v[1] as Vector2) != Vector2.ZERO or p.distance_to(ctr) < 20.0):
			return false
	return true


static func _look_for_meeting(u: Unit) -> void:
	var game := u.game
	var meet := float(Defs.CW["siding"]["meet"]) * T
	var mine: Vector2 = u.velocity.normalized() if u.velocity.length() > 8.0 else Vector2.ZERO
	var go := false
	for v in vehicles(game, u.team):
		var o = v[3]
		if o == u:
			continue
		var p: Vector2 = v[0]
		var dist := p.distance_to(u.position)
		if dist > meet or dist < 4.0:
			continue
		var od: Vector2 = v[1]
		var queued: bool = o is Unit and o.cw.get("q_for") == u        # waiting right behind me
		if od == Vector2.ZERO and not queued:
			continue
		var back := (u.position - p).normalized()
		var same_lane: bool = absf((u.position - p).dot(Vector2(-back.y, back.x))) < 7.0
		if not same_lane:
			continue                                   # the other track: it passes me
		var same_way: bool = mine == Vector2.ZERO or mine.dot(od if od != Vector2.ZERO else back) > 0.3
		if not same_way:
			continue
		var o_speed: float = o.speed if o is Unit else float(Defs.TRAINS[o.tkind]["speed"]) * T
		var faster: bool = o_speed > u.speed * 1.15 + 4.0
		var coming: bool = queued or (back.dot(od) > 0.6)       # it is coming up behind me
		if coming and (faster or mine == Vector2.ZERO):
			go = true
			break
	if not go:
		return
	var from := cell_near(u)
	if from.x < 0:
		return
	var site := find_siding(game, u.team, from, u)
	if site.x < 0:
		return                                         # no siding near: the queue passes through in time
	var cells := route_toward(game.line_net, u.team, from, game.cell_center(site))
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(game.cell_center(c))
	u.cw["sid"] = {"cell": site, "phase": "to", "t": 0.0, "path": pts}
