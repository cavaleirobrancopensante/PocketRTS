class_name CwConsist
extends RefCounted
## COUPLING (docs/clockwork_units_prototype.md, "Trains"): rail vehicles of the Clockwork roster hook together into ONE train.
## A train (a "consist") is a list of Units, the front one first. The front car is the DRIVER: it alone plans a path, is steered
## by CwRail (lanes, queueing behind a train ahead, loops) and takes the orders. The others are FOLLOWERS: they do not move on
## their own; every tick each is put on the driver's trail at the coupling distance (a rigid chord, so it holds round bends,
## loops and lanes) and takes the driver's speed picture (the train goes at the speed of its slowest car). A car keeps its own
## job: it fires, builds, blocks the track and lands flyers from where it stands in the train.
## Orders reach the driver (selecting any car selects the whole train: Game.set_selection). To turn round the train stands for a
## moment and then swaps ends (the rear car becomes the driver, push-pull), so nothing sticks out. A car that dies, goes off
## the rails or is told to UNCOUPLE splits the train at that car; the rear part becomes a train of its own. Numbers: Defs.CW["couple"].
## State lives in Unit.cw["cons"] (the train) and Unit.cw["join"] (a vehicle on its way to hook on); saved by SaveGame ("cpl")
## and sent to online guests as lists of ids (NetSnapshot "cpl").

const T := Defs.TILE

var id := 0
var game: Game
var cars: Array = []             # the Units, front first
var joiners: Array = []          # vehicles sent to hook onto the last car
var trail: Array = []            # the driver's path (world points, oldest first): the cars are strung along it
var dir := Vector2(1, 0)         # the way the train faces
var rev_t := -1.0                # >= 0: standing to swap ends
var pick: Unit = null            # the car the player tapped (UNCOUPLE splits in front of it)
var puppet := false              # an online guest's copy: drawn and selected, never moved
var alive := true
var last_delta := 0.033
var _slots := {}
var _wait := 0.0


static func cfg() -> Dictionary:
	return Defs.CW["couple"]


static func of(u) -> CwConsist:
	if u == null or not is_instance_valid(u):
		return null
	return u.cw.get("cons") as CwConsist


static func is_follower(u: Unit) -> bool:
	var c := of(u)
	return c != null and not c.cars.is_empty() and c.cars[0] != u


static func driver_of(u: Unit) -> Unit:
	var c := of(u)
	return c.cars[0] if c != null and not c.cars.is_empty() else u


## Is the train this car is in being driven somewhere right now?
static func driving(u: Unit) -> bool:
	var d := driver_of(u)
	return d.order == "move" or d.order == "amove"


static func axis_of(v: Vector2) -> Vector2:
	if v.length() < 0.01:
		return Vector2(1, 0)
	return Vector2(signf(v.x), 0.0) if absf(v.x) >= absf(v.y) else Vector2(0.0, signf(v.y))


static func create(g: Game, list: Array, is_puppet := false) -> CwConsist:
	var c := CwConsist.new()
	c.game = g
	c.id = g.cw_cons_next
	g.cw_cons_next += 1
	c.cars = list.filter(func(u) -> bool: return is_instance_valid(u))
	c.puppet = is_puppet
	for u in c.cars:
		u.cw["cons"] = c
		u.cw.erase("join")
		u.cw.erase("sid")
	g.cw_consists.append(c)
	c.dir = axis_of(c.cars[0].cw.get("axis", Vector2(1, 0)))
	_ensure_links(g)
	return c


func _end(clear_cons := true) -> void:
	alive = false
	game.cw_consists.erase(self)
	if clear_cons:
		for u in cars:
			if is_instance_valid(u) and u.cw.get("cons") == self:
				u.cw.erase("cons")
	for j in joiners:
		if is_instance_valid(j):
			j.cw.erase("join")
	joiners.clear()


static func _ok(u) -> bool:
	return is_instance_valid(u) and not u.dead and not u.is_queued_for_deletion() and not u.off_field and CwRail.bound(u)


# ------------------------------------------------------------------ the length of a coupling

## Distance between the centres of two coupled vehicles (px): half of each one's length less the hook overlap.
static func link_len(front: Unit, back: Unit, horiz: bool) -> float:
	var i := 0 if horiz else 1
	var lens: Dictionary = cfg()["len"]
	var lf: float = float((lens.get(front.kind, [68.0, 28.0]) as Array)[i])
	var lb: float = float((lens.get(back.kind, [68.0, 28.0]) as Array)[i])
	return (lf + lb) * 0.5 - float((cfg()["hook"] as Array)[i])


## The slowest car's speed (the train goes at this, times the pressure under the driver).
func min_speed() -> float:
	var s := INF
	for u in cars:
		if is_instance_valid(u):
			var v := float(u.d["speed"])
			if u.slow_t > 0.0:
				v *= Defs.ACID_SLOW
			s = minf(s, v)
	return s if s < INF else 0.0


func has_heavy() -> bool:
	for u in cars:
		if is_instance_valid(u) and u.kind == "heavy_loco" and not u.dead:
			return true
	return false


## The car that names the train: the first locomotive-type car, else the front one.
func head_name() -> String:
	for u in cars:
		if is_instance_valid(u) and (cfg()["locos"] as Array).has(u.kind):
			return String(u.d["name"])
	return String(cars[0].d["name"])


# ------------------------------------------------------------------ the tick (from CwUnits.tick_game)

static func tick_all(g: Game, delta: float) -> void:
	for c in g.cw_consists.duplicate():
		if c.alive:
			c.tick(delta)
	if not g.puppet:
		g.cw_bump_t -= delta
		if g.cw_bump_t <= 0.0:
			g.cw_bump_t = 0.2
			_bump(g)
	if g.cw_links != null and is_instance_valid(g.cw_links) and not g.cw_consists.is_empty():
		g.cw_links.queue_redraw()


func tick(delta: float) -> void:
	last_delta = delta
	if puppet:
		for u in cars.duplicate():
			if not is_instance_valid(u) or u.dead:
				cars.erase(u)
		if cars.size() < 2:
			_end()
		return
	for u in cars:
		if not _ok(u):
			remove_car(u)
			return
	if cars.size() < 2 and joiners.is_empty():
		_end()
		return
	_tick_joiners(delta)
	var drv: Unit = cars[0]
	if trail.is_empty() or (trail[trail.size() - 1] as Vector2).distance_squared_to(drv.position) >= 1.0:
		trail.append(drv.position)
	if cars.size() >= 2:
		_layout()
	else:
		_slots.clear()


# ------------------------------------------------------------------ strung along the trail

## The slot of every follower: a point of the trail at the coupling distance (straight line) from the car in front.
func _layout() -> void:
	if not _pass():
		_extend_back(maxf(_shortfall(), 40.0))
		_pass()


## One walk down the trail placing every follower. False if the trail was too short for the last car.
func _pass() -> bool:
	_slots.clear()
	var d0: Unit = cars[0]
	var pts: Array = [d0.position]
	for i in range(trail.size() - 1, -1, -1):
		if (trail[i] as Vector2).distance_squared_to(pts[pts.size() - 1]) > 0.04:
			pts.append(trail[i])
	var back := -dir
	if pts.size() >= 2:
		var tail: Vector2 = pts[pts.size() - 1] - pts[pts.size() - 2]
		if tail.length() > 0.01:
			back = tail.normalized()
	var real := pts.size()
	pts.append(pts[pts.size() - 1] + back * 600.0)       # (a far tail so every car finds a place)
	var prev_pt: Vector2 = d0.position
	var q: Vector2 = prev_pt
	var j := 0
	var all_placed := true
	for n in range(1, cars.size()):
		var placed := false
		while j < pts.size() - 1:
			var b: Vector2 = pts[j + 1]
			var sd: Vector2 = b - prev_pt
			var dd := link_len(cars[n - 1], cars[n], absf(sd.x) >= absf(sd.y))      # (side on or end on, by the way the chord runs)
			if b.distance_squared_to(prev_pt) >= dd * dd:
				var v := b - q
				var a2 := v.length_squared()
				if a2 > 0.0001:
					var w := q - prev_pt
					var bb := 2.0 * v.dot(w)
					var cc := w.length_squared() - dd * dd
					var disc := maxf(0.0, bb * bb - 4.0 * a2 * cc)
					var t := clampf((-bb + sqrt(disc)) / (2.0 * a2), 0.0, 1.0)
					q = q + v * t
				else:
					q = b
				placed = true
				break
			q = b
			j += 1
		if not placed:
			q = pts[pts.size() - 1]
			all_placed = false
		_slots[cars[n]] = q
		prev_pt = q
	if not all_placed or j >= real - 1:
		return false
	var ch: Vector2 = d0.position - (_slots[cars[1]] as Vector2)
	if ch.length() > 1.0:
		dir = axis_of(ch)
	# forget the trail behind the last car (it stays an exact fit, so reversing the trail swaps the ends cleanly)
	var keep: Array = [prev_pt]
	for k in range(j, -1, -1):
		keep.append(pts[k])
	trail = keep
	return true


## How much more trail the cars need (the longest the couplings can be, less what there is).
func _shortfall() -> float:
	var need := 0.0
	for n in range(1, cars.size()):
		need += link_len(cars[n - 1], cars[n], true)
	var have := 0.0
	var prev: Vector2 = cars[0].position
	for i in range(trail.size() - 1, -1, -1):
		have += prev.distance_to(trail[i])
		prev = trail[i]
	return need - have


## Make the trail reach back `extra` px further: walk back along the Line from its oldest point.
func _extend_back(extra: float) -> void:
	var net := game.line_net
	var team: int = cars[0].team
	var oldest: Vector2 = trail[0] if not trail.is_empty() else cars[0].position
	var ref := Vector2.ZERO
	for i in range(1, trail.size()):
		var dv: Vector2 = (trail[0] as Vector2) - (trail[i] as Vector2)
		if dv.length() > 1.0:
			ref = dv
			break
	if ref == Vector2.ZERO:
		ref = -dir
	var ax := axis_of(ref)
	var bd := Vector2i(int(ax.x), int(ax.y))
	var cell := game.cell_of(oldest)
	var visited := {cell: true}
	var out: Array = []
	var cur: Vector2 = oldest
	var remaining := extra
	for step in 40:
		var nxt := Vector2i(-1, -1)
		var nd := bd
		for cand in [bd, Vector2i(-bd.y, bd.x), Vector2i(bd.y, -bd.x)]:
			var c2: Vector2i = cell + cand
			if CwRail._seg_ok(net, team, c2) and not visited.has(c2):
				nxt = c2
				nd = cand
				break
		if nxt.x < 0:
			break
		visited[nxt] = true
		var p: Vector2 = game.cell_center(nxt) + Train.lane_of(-nd)
		out.append(p)
		remaining -= cur.distance_to(p)
		cur = p
		cell = nxt
		bd = nd
		if remaining <= 0.0:
			break
	if remaining > 0.0:
		out.append(cur + Vector2(bd) * remaining)        # (the track ends: the rest hangs over the end)
	out.reverse()
	trail = out + trail


## Called by each follower's tick (CwUnits.post_move): slide it into its place on the train.
static func place(u: Unit) -> void:
	var c := of(u)
	if c == null or c.puppet or c.cars.is_empty() or c.cars[0] == u or not c._slots.has(u):
		return
	var slot: Vector2 = c._slots[u]
	u.position = u.position.move_toward(slot, float(cfg()["close"]) * c.last_delta + 4.0)
	var idx := c.cars.find(u)
	var ahead: Unit = c.cars[maxi(idx - 1, 0)]
	var drv: Unit = c.cars[0]
	var sp := drv.velocity.length()
	var dv: Vector2 = ahead.position - u.position
	if sp > 8.0 and dv.length() > 12.0:
		u.facing = axis_of(dv)
	u.velocity = u.facing * sp if sp > 8.0 else Vector2.ZERO
	u.last_pos = u.position


## The driver's movement for this tick (the train waits for its crews, swaps ends to turn round). Followers do not move.
static func steer(u: Unit, want: Vector2, delta: float) -> Vector2:
	var c := of(u)
	if c == null or c.puppet:
		return want
	if c.cars[0] != u:
		u.velocity = Vector2.ZERO
		return Vector2.ZERO
	if c.cars.size() < 2:
		return want
	if c.rev_t >= 0.0:
		c.rev_t -= delta
		if c.rev_t <= 0.0:
			c.rev_t = -1.0
			c.swap_ends()
		return Vector2.ZERO
	for car in c.cars:
		if car.cw.has("cast_left"):
			return Vector2.ZERO                  # a Storm Engine is casting: the train holds still
	if want.length() > 5.0 and want.normalized().dot(c.dir) < -0.55:
		c.rev_t = float(cfg()["reverse"])
		return Vector2.ZERO
	# a Work Car's crew climb back aboard before the train leaves
	if u.order == "move" or u.order == "amove":
		var out := false
		for car in c.cars:
			if car.kind == "work_car" and CwUnits._crew_out(car):
				out = true
				CwUnits._recall(car)
		if out:
			c._wait += delta
			if c._wait < float(Defs.CW["work_car"]["depart_wait"]):
				return Vector2.ZERO
		else:
			c._wait = 0.0
	return want


## Turn the train round: the rear car becomes the driver (push-pull), the order goes with it.
func swap_ends() -> void:
	var old: Unit = cars[0]
	var o := old.order
	var op := old.order_point
	var tgt = old.order_target
	cars.reverse()
	var nd: Unit = cars[0]
	trail.reverse()
	trail = _trail_part(nd)
	dir = -dir
	old.cmd_stop()
	nd.velocity = Vector2.ZERO
	nd.cw.erase("lane_d")
	if o == "move" or o == "amove":
		nd.cmd_move(op, o == "amove")
	elif o == "attack" and is_instance_valid(tgt):
		nd.cmd_attack(tgt)


## The part of the trail up to a car (oldest first, ending at the car).
func _trail_part(drv: Unit) -> Array:
	if trail.is_empty():
		return [drv.position]
	var bi := 0
	var bd := INF
	for k in trail.size():
		var d2: float = (trail[k] as Vector2).distance_squared_to(drv.position)
		if d2 < bd:
			bd = d2
			bi = k
	var out := trail.slice(0, bi + 1)
	out.append(drv.position)
	return out


# ------------------------------------------------------------------ splitting

## Take a car out of the train (it died, went off the rails ...): the cars in front stay a train, the cars behind become
## one of their own and carry on to the same place.
func remove_car(u) -> void:
	var idx := cars.find(u)
	if idx < 0:
		return
	var old: Unit = cars[0]
	var o := ""
	var op := Vector2.ZERO
	if is_instance_valid(old):
		o = old.order
		op = old.order_point
	if is_instance_valid(u):
		u.cw.erase("cons")
	_split(cars.slice(0, idx), cars.slice(idx + 1), o, op, false)


## UNCOUPLE: the cars from `idx` on become a train of their own (standing); the front part carries on.
func split_at(idx: int) -> void:
	if idx <= 0 or idx >= cars.size():
		return
	_split(cars.slice(0, idx), cars.slice(idx), "", Vector2.ZERO, true)


func _split(front: Array, rear: Array, o: String, op: Vector2, cool: bool) -> void:
	front = front.filter(func(u) -> bool: return is_instance_valid(u))
	rear = rear.filter(func(u) -> bool: return is_instance_valid(u))
	var rc: CwConsist = null
	if rear.size() >= 2:
		rc = CwConsist.create(game, rear, puppet)
		rc.trail = _trail_part(rear[0])
		rc.dir = dir
	elif rear.size() == 1 and is_instance_valid(rear[0]):
		rear[0].cw.erase("cons")
	if front.size() >= 2 or (front.size() == 1 and not joiners.is_empty()):
		cars = front
	else:
		cars = front
		_end()
	rev_t = -1.0
	if (o == "move" or o == "amove") and not rear.is_empty() and is_instance_valid(rear[0]):
		rear[0].cmd_move(op, o == "amove")
	if cool:
		var until := game.clock + float(cfg()["cool"])
		for u in front + rear:
			if is_instance_valid(u):
				u.cw["no_cpl"] = until
	pick = null


# ------------------------------------------------------------------ hooking on

static func tail_of(c: CwConsist) -> Unit:
	return c.cars[c.cars.size() - 1]


func _tick_joiners(delta: float) -> void:
	for j in joiners.duplicate():
		if not _ok(j) or j.cw.get("join") != self:
			joiners.erase(j)
			if is_instance_valid(j):
				j.cw.erase("join")
			continue
		var tail: Unit = cars[cars.size() - 1]
		if j.position.distance_to(tail.position) <= float(cfg()["reach"]):
			_absorb(j)
			continue
		j.cw["join_t"] = float(j.cw.get("join_t", 0.0)) + delta
		if float(j.cw["join_t"]) > float(cfg()["give_up"]):
			joiners.erase(j)
			j.cw.erase("join")
			j.cmd_stop()
			if j.team == game.human:
				game.notify("A vehicle could not reach the train to couple.")
			continue
		j.cw["aim_t"] = float(j.cw.get("aim_t", 0.0)) - delta
		if float(j.cw["aim_t"]) <= 0.0:
			j.cw["aim_t"] = 0.5
			var ap: Vector2 = j.cw.get("aim_pos", Vector2.INF)
			if j.order != "move" or ap.distance_to(tail.position) > 16.0:
				j.cw["aim_pos"] = tail.position
				j.cmd_move(tail.position)


## Hook the vehicle `j` (with the train it leads, if any) onto the last car.
func _absorb(j: Unit) -> void:
	var cj := CwConsist.of(j)
	var add: Array = cj.cars.duplicate() if cj != null else [j]
	if cars.size() + add.size() > int(cfg()["max"]):
		joiners.erase(j)
		j.cw.erase("join")
		j.cmd_stop()
		if j.team == game.human:
			game.notify("A train holds %d cars at most." % int(cfg()["max"]))
		return
	joiners.erase(j)
	if cj != null:
		for x in cj.joiners:
			if is_instance_valid(x):
				x.cw["join"] = self
				joiners.append(x)
		cj.joiners.clear()
		cj._end(false)
	j.cmd_stop()
	for u in add:
		u.cw.erase("join")
		u.cw.erase("sid")
		u.cw["cons"] = self
		cars.append(u)
		u.cmd_stop()
	if team_is_human():
		Sfx.play_any(["combat/gear_hit", "gear_hit"], j.position)
	pick = null


func team_is_human() -> bool:
	return not cars.is_empty() and cars[0].team == game.human


## Driving into an idle vehicle that is straight ahead in the same lane hooks onto it (the moving one goes behind).
static func _bump(g: Game) -> void:
	var rail: Array = []
	for u: Unit in g.units:
		if not u.dead and not u.off_field and Defs.CW_RAIL.has(u.kind) and CwRail.bound(u):
			rail.append(u)
	if rail.size() < 2:
		return
	var age := float(cfg()["age"])
	for u: Unit in rail:
		if u.order != "move" and u.order != "amove":
			continue
		if u.cw.has("join") or u.cw.has("sid") or u.velocity.length() < 12.0 or is_follower(u):
			continue
		if float(u.cw.get("no_cpl", 0.0)) > g.clock or g.clock - float(u.cw.get("born", -99.0)) < age:
			continue
		var cu := of(u)
		var mv: Vector2 = u.velocity.normalized()
		var perp := Vector2(-mv.y, mv.x)
		for o: Unit in rail:
			if o == u or o.team != u.team or o.cw.has("sid") or float(o.cw.get("no_cpl", 0.0)) > g.clock or g.clock - float(o.cw.get("born", -99.0)) < age:
				continue
			var co := of(o)
			if co != null and (co == cu or co.cars[co.cars.size() - 1] != o):
				continue                      # (only the last car of a train can be hooked onto from behind)
			var odrv := driver_of(o)
			if odrv.order != "idle" or odrv.velocity.length() > 8.0 or o.cw.has("join"):
				continue
			var rel: Vector2 = o.position - u.position
			var ahead := rel.dot(mv)
			if ahead < 4.0 or ahead > float(cfg()["bump"]) or absf(rel.dot(perp)) > 8.0:
				continue
			var n := (cu.cars.size() if cu != null else 1) + (co.cars.size() if co != null else 1)
			if n > int(cfg()["max"]):
				continue
			_bump_couple(g, u, cu, o, co)
			return


## `mover` ran into the idle `o`: o's train (or o alone) leads, the mover's train follows, and the whole goes where the mover was going.
static func _bump_couple(g: Game, mover: Unit, cm: CwConsist, o: Unit, co: CwConsist) -> void:
	var op := mover.order_point
	var oo := mover.order
	var main := co if co != null else CwConsist.create(g, [o])
	var add: Array = cm.cars.duplicate() if cm != null else [mover]
	if cm != null:
		for x in cm.joiners:
			if is_instance_valid(x):
				x.cw["join"] = main
				main.joiners.append(x)
		cm.joiners.clear()
		cm._end(false)
	for u in add:
		u.cw["cons"] = main
		u.cw.erase("sid")
		main.cars.append(u)
		u.cmd_stop()
	main.pick = null
	if oo == "move" or oo == "amove":
		main.cars[0].cmd_move(op, oo == "amove")
	if mover.team == g.human:
		Sfx.play_any(["combat/gear_hit", "gear_hit"], mover.position)
		g.float_text(mover.position + Vector2(0, -40), "coupled", Color(0.9, 0.85, 0.5))


# ------------------------------------------------------------------ the commands

## The blocks of a selection: each train as its list of cars, each lone vehicle as [vehicle].
static func blocks_of(units: Array) -> Array:
	var seen := {}
	var out: Array = []
	for u in units:
		if not (u is Unit) or u.dead or not Defs.CW_RAIL.has(u.kind) or not CwRail.bound(u):
			continue
		var c := of(u)
		if c != null:
			if seen.has(c):
				continue
			seen[c] = true
			out.append(c.cars.duplicate())
		else:
			out.append([u])
	return out


## Why COUPLE cannot be done with this selection ("" if it can).
static func couple_problem(units: Array) -> String:
	var bl := blocks_of(units)
	if bl.size() < 2:
		return "Select two or more rail vehicles (or trains) to couple."
	var n := 0
	for b in bl:
		n += b.size()
	if n > int(cfg()["max"]):
		return "A train holds %d cars at most." % int(cfg()["max"])
	return ""


static func _score(b: Array) -> int:
	var s := 0
	for i in b.size():
		var k: String = b[i].kind
		if k == "heavy_loco":
			s = maxi(s, 6 if i == 0 else 4)
		elif (cfg()["locos"] as Array).has(k):
			s = maxi(s, 5 if i == 0 else 3)
	return s


## COUPLE: the selected vehicles and trains join into one train. The one with a Heavy Locomotive (else another locomotive,
## else the biggest) is the main train and waits; the others drive to its last car and hook on.
static func couple_order(g: Game, units: Array) -> String:
	var why := couple_problem(units)
	if why != "":
		return why
	var bl := blocks_of(units)
	var main: Array = bl[0]
	for b in bl:
		if _score(b) > _score(main) or (_score(b) == _score(main) and b.size() > main.size()):
			main = b
	var mc := of(main[0])
	if mc == null:
		mc = create(g, main)
	mc.cars[0].cmd_stop()
	mc.rev_t = -1.0
	for b in bl:
		if b == main:
			continue
		var j: Unit = b[0]
		j.cw["join"] = mc
		j.cw["join_t"] = 0.0
		j.cw["aim_t"] = 0.0
		j.cw.erase("sid")
		if not mc.joiners.has(j):
			mc.joiners.append(j)
		j.cw["aim_pos"] = tail_of(mc).position
		j.cmd_move(tail_of(mc).position)
	return ""


## UNCOUPLE: split each selected train in front of the car the player tapped (the front car alone if that is the first,
## the last car if none was tapped).
static func uncouple_order(units: Array) -> int:
	var done := 0
	var seen := {}
	for u in units:
		var c := of(u)
		if c == null or seen.has(c) or c.puppet:
			continue
		seen[c] = true
		var idx := c.cars.size() - 1
		if c.pick != null and c.cars.has(c.pick):
			idx = maxi(1, c.cars.find(c.pick))
		c.split_at(idx)
		done += 1
	return done


## A selected vehicle is told to go off the rails (SET UP): it leaves its train.
static func detach(u: Unit) -> void:
	var c := of(u)
	if c != null:
		c.remove_car(u)


static func on_death(u: Unit) -> void:
	var c := of(u)
	if c != null:
		c.remove_car(u)


## Game.set_selection: tapping any car selects the whole train; remembers a single tapped car (UNCOUPLE splits there).
static func expand_selection(list: Array) -> Array:
	var counts := {}
	for e in list:
		if e is Unit and is_instance_valid(e):
			var c := of(e)
			if c != null:
				counts[c] = int(counts.get(c, 0)) + 1
	if counts.is_empty():
		return list
	var out: Array = list.duplicate()
	for c in counts:
		for u in c.cars:
			if is_instance_valid(u) and not out.has(u):
				out.append(u)
		c.pick = null
		if int(counts[c]) == 1:
			for e in list:
				if e is Unit and of(e) == c:
					c.pick = e
	return out


# ------------------------------------------------------------------ drawing

static func _ensure_links(g: Game) -> void:
	if g.cw_links != null and is_instance_valid(g.cw_links):
		return
	var n := Node2D.new()
	n.z_index = 1
	n.draw.connect(func() -> void: draw_links(g, n))
	g.add_child(n)
	g.cw_links = n


## The steel link between two coupled cars (code art, docs/art_style_inconsistency.md): a bar with a pin ring at buffer height.
static func draw_links(g: Game, cv: Node2D) -> void:
	for c in g.cw_consists:
		for i in range(c.cars.size() - 1):
			var a = c.cars[i]
			var b = c.cars[i + 1]
			if not is_instance_valid(a) or not is_instance_valid(b) or a.dead or b.dead or a.off_field:
				continue
			var diff: Vector2 = (b.position - a.position)
			if absf(diff.x) < absf(diff.y) or diff.length() < 1.0:
				continue                 # end on the hooks hide behind the car in front
			var mid: Vector2 = (a.position + b.position) * 0.5 + Vector2(0, -6.0)
			var u := diff.normalized()
			var perp := Vector2(-u.y, u.x)
			var half := 6.0
			cv.draw_line(mid - u * half, mid + u * half, Color(0.08, 0.07, 0.07), 4.2)
			cv.draw_line(mid - u * half, mid + u * half, Color(0.72, 0.74, 0.78), 2.4)
			cv.draw_circle(mid, 3.0, Color(0.08, 0.07, 0.07))
			cv.draw_circle(mid, 1.8, Color(0.95, 0.75, 0.25))
			cv.draw_line(mid + perp * 3.5 - u * half, mid - perp * 3.5 - u * half, Color(0.15, 0.15, 0.17), 1.8)
			cv.draw_line(mid + perp * 3.5 + u * half, mid - perp * 3.5 + u * half, Color(0.15, 0.15, 0.17), 1.8)


# ------------------------------------------------------------------ save and online

## Saved with each unit: [train id, place in it].
static func save_tag(u: Unit):
	var c := of(u)
	if c == null:
		return null
	return [c.id, c.cars.find(u)]


## After a load: put the cars back into their trains. `rows` are the saved unit rows, `made` the units made from them.
static func restore(g: Game, rows: Array, made: Array) -> void:
	var groups := {}
	for i in rows.size():
		var tag = rows[i].get("cpl")
		if tag is Array and tag.size() == 2 and i < made.size() and made[i] != null:
			var key := int(tag[0])
			if not groups.has(key):
				groups[key] = []
			groups[key].append([int(tag[1]), made[i]])
	for key in groups:
		var l: Array = groups[key]
		l.sort_custom(func(a, b) -> bool: return a[0] < b[0])
		var us: Array = l.map(func(p) -> Unit: return p[1])
		us = us.filter(func(u: Unit) -> bool: return CwRail.bound(u))
		if us.size() >= 2:
			create(g, us)


## Host: the trains as lists of net ids.
static func net_rows(s, g: Game) -> Array:
	var out: Array = []
	for c in g.cw_consists:
		var ids: Array = []
		for u in c.cars:
			if is_instance_valid(u):
				var id: int = NetSnapshot.ref(s, u)
				if id != 0:
					ids.append(id)
		if ids.size() >= 2:
			out.append(ids)
	return out


## Guest: rebuild the copies (drawn and selected as trains; the host moves the cars).
static func net_apply(s, g: Game, rows: Array) -> void:
	var want: Array = []
	for ids in rows:
		var us: Array = []
		for id in ids:
			var e = s.by_id.get(int(id))
			if is_instance_valid(e) and e is Unit:
				us.append(e)
		if us.size() >= 2:
			want.append(us)
	var have: Array = []
	for c in g.cw_consists:
		have.append(c.cars.duplicate())
	if str(want.map(func(l: Array) -> Array: return l.map(func(u: Unit) -> int: return u.net_id))) \
			== str(have.map(func(l: Array) -> Array: return l.map(func(u: Unit) -> int: return u.net_id))):
		return                                  # (unchanged: keep the copies, and which car was tapped)
	for c in g.cw_consists.duplicate():
		c._end()
	for us in want:
		create(g, us, true)
