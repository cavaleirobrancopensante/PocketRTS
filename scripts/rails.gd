class_name Rails
extends RefCounted
## The Clockwork's rails (phase 2 of the Line, docs/clockwork_rework_plan.md): every Line segment carries a rail,
## so the trains (scripts/train.gd) run wherever the Line goes. This keeps the trains of a match, routes them over
## the finished segments, buys them, saves them and sends them online. The Ore Drill's own logic is in
## scripts/ore_drill.gd.

var net: LineNetwork
var game: Game
var trains: Array = []            # Train (alive)
var _next_id := 1
var _route_cache := {}            # "from>goal" -> path, cleared whenever the Line changes
var _cache_version := -1
var _stats_t := 0.0
var delivered := {}               # team -> ore delivered by trains (a statistic for the tests and the match log)


func _init(n: LineNetwork) -> void:
	net = n
	game = n.game


# ------------------------------------------------------------------ routing

## The finished segments of team t touching building b (where a train meets it).
func access_cells(t: int, b: Building) -> Array:
	var out: Array = []
	for c in net.ring(b):
		var s: PipeSeg = net.segs.get(c)
		if s != null and s.team == t and s.built and not s.dead:
			out.append(c)
	return out


## Shortest run over finished segments of team t from `from` to the nearest of `goals` (a Dictionary or
## Array of cells): the cells in order, both ends included; [] when the Line does not connect them.
func route(t: int, from: Vector2i, goals) -> Array:
	var goal: Dictionary = {}
	for g in goals:
		goal[g] = true
	if goal.has(from):
		return [from]
	var prev := {from: from}
	var q: Array = [from]
	var i := 0
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		for d in LineNetwork.DIRS:
			var n: Vector2i = cur + d
			if prev.has(n):
				continue
			var s: PipeSeg = net.segs.get(n)
			if s == null or s.team != t or not s.built or s.dead:
				continue
			prev[n] = cur
			if goal.has(n):
				var path: Array = [n]
				while path[path.size() - 1] != from:
					path.append(prev[path[path.size() - 1]])
				path.reverse()
				return path
			q.append(n)
	return []


## The finished segment of team t nearest to a world point (within `max_cells`), or (-1, -1).
func nearest_cell(t: int, p: Vector2, max_cells := 6) -> Vector2i:
	var c0 := game.cell_of(p)
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(c0.y - max_cells, c0.y + max_cells + 1):
		for x in range(c0.x - max_cells, c0.x + max_cells + 1):
			var s: PipeSeg = net.segs.get(Vector2i(x, y))
			if s == null or s.team != t or not s.built or s.dead:
				continue
			var dd := game.cell_center(Vector2i(x, y)).distance_to(p)
			if dd < bd:
				bd = dd
				best = Vector2i(x, y)
	return best


# ------------------------------------------------------------------ trains

func count(t: int, kind := "") -> int:
	var n := 0
	for tr in trains:
		if tr.team == t and not tr.dead and (kind == "" or tr.tkind == kind):
			n += 1
	return n


## Put a train of `kind` on the Line at the team's Clocktower (no cost: starts, tests, loads). null if the hall
## has no finished segment beside it.
func add_train(t: int, kind: String, at: Vector2i = Vector2i(-1, -1), hall: Building = null) -> Train:
	if hall == null:
		hall = _hall(t, at)
	if hall == null:
		return null
	if at.x < 0:
		var acc := access_cells(t, hall)
		if acc.is_empty():
			return null
		at = acc[0]
	var tr := Train.new()
	tr.setup(net, _next_id, kind, t, at)
	_next_id += 1
	tr.home = hall
	net.add_child(tr)
	trains.append(tr)
	net.changed()
	return tr


func _hall(t: int, near: Vector2i) -> Building:
	var best: Building = null
	var bd := INF
	for b in game.buildings:
		if b.team == t and b.built and not b.dead and b.kind == game.faction_hall(t):
			var dd: float = (b.center() - game.cell_center(near)).length() if near.x >= 0 else 0.0
			if dd < bd:
				bd = dd
				best = b
	return best


## Why team t cannot buy a train of `kind` right now ("" if it can).
func buy_problem(t: int, kind: String, hall: Building = null) -> String:
	if not Defs.TRAINS.has(kind):
		return "No such train."
	if hall == null:
		hall = _hall(t, Vector2i(-1, -1))
	if hall == null or not hall.built:
		return "Needs a Clocktower."
	if access_cells(t, hall).is_empty():
		return "Lay the Line to the Clocktower first."
	if int(game.players[t]["gold"]) < int(Defs.TRAINS[kind]["cost"]):
		return "Not enough %s." % String(Defs.FACTIONS[game.faction_of(t)]["res"][0]).to_lower()
	if count(t) >= int(Defs.TRAIN_MAX):
		return "Limit reached: %d trains." % int(Defs.TRAIN_MAX)
	return ""


func buy(t: int, kind: String, hall: Building = null) -> String:
	var why := buy_problem(t, kind, hall)
	if why != "":
		return why
	game.players[t]["gold"] -= int(Defs.TRAINS[kind]["cost"])
	var tr := add_train(t, kind, Vector2i(-1, -1), hall)
	if tr == null:
		game.players[t]["gold"] += int(Defs.TRAINS[kind]["cost"])
		return "Lay the Line to the Clocktower first."
	if game.mlog:
		game.mlog.add("%s bought a %s" % [game.mlog.who(t), Defs.TRAINS[kind]["name"]])
	Sfx.play_any(["ui/click", "click"], tr.global_position)
	return ""


func remove(tr: Train) -> void:
	trains.erase(tr)
	net.changed()


func tick(delta: float) -> void:
	if _cache_version != net.version:
		_cache_version = net.version
		_route_cache.clear()
	for tr in trains.duplicate():
		if is_instance_valid(tr) and not tr.dead:
			tr.step(delta)


## The nearest enemy train a unit can shoot (below units and buildings, above pipes; Game.find_target).
func target(u: Unit, r: float) -> Entity:
	var best: Entity = null
	var bd := r
	for tr in trains:
		if tr.dead or not game.hostile(tr.team, u.team) or not u.can_hit(tr):
			continue
		var dd: float = tr.edge_distance(u.position)
		if dd < bd and game.side_sees(u.team, tr.global_position):
			bd = dd
			best = tr
	return best


## Ore a second the team's trains can bring along its busiest rail at full pressure (the cap the plan asks for).
static func rail_cap() -> float:
	return float(Defs.TRAINS["ore"]["cargo"]) * float(Defs.TRAINS["ore"]["speed"]) / float(Defs.RAIL["headway"])


# ------------------------------------------------------------------ save and online

## One row per train: [id, kind, team, cell x, cell y, hp, cargo, riders].
func save() -> Array:
	var rows: Array = []
	for tr in trains:
		if not tr.dead:
			rows.append(tr.save_row())
	return rows


func load_rows(rows: Array) -> void:
	for tr in trains.duplicate():
		if is_instance_valid(tr):
			tr.drop_riders(false)
			tr.dead = true
			tr.queue_free()
	trains.clear()
	for r in rows:
		var tr := add_train(int(r[2]), String(r[1]), Vector2i(int(r[3]), int(r[4])))
		if tr == null:
			continue
		tr.tid = int(r[0])
		_next_id = maxi(_next_id, tr.tid + 1)
		tr.load_row(r)


## What the host streams every snapshot: [id, kind, team, x, y, hp, state, cargo, dir x, dir y, riders].
func view_rows() -> Array:
	var rows: Array = []
	for tr in trains:
		if not tr.dead:
			rows.append(tr.view_row())
	return rows


## The online guest: put the trains where the host's rows say.
func load_view(rows: Array) -> void:
	var seen := {}
	for r in rows:
		var id := int(r[0])
		seen[id] = true
		var tr: Train = null
		for t in trains:
			if t.tid == id:
				tr = t
				break
		if tr == null:
			tr = Train.new()
			tr.setup(net, id, String(r[1]), int(r[2]), game.cell_of(Vector2(float(r[3]), float(r[4]))))
			net.add_child(tr)
			trains.append(tr)
			tr.position = Vector2(float(r[3]), float(r[4]))
		tr.load_view_row(r)
	for tr in trains.duplicate():
		if not seen.has(tr.tid):
			trains.erase(tr)
			tr.dead = true
			tr.queue_free()
