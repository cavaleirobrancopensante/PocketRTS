class_name LineNetwork
extends Node2D
## THE LINE (Clockwork, phase 1 of docs/clockwork_rework_plan.md): pipe segments (PipeSeg) on the
## map grid, a pressure solver, the drawing of the pipes and the Line tool's preview. Owned by
## Game (`game.line`). The numbers are Defs.LINE.
##
## Rules in short: Boilers and the Clocktower push pressure into the pipes they touch; pressure
## falls with every segment; the shared load of all consumers on one connected Line lowers it
## for all of them; a Pressure Relay boosts it again; a Clockwork building that touches the Line
## works at a speed that follows the pressure there (Defs.line_speed), one that does not touch it
## does not work. Cutting the Line (a destroyed segment) leaves the far side with no pressure.

const T := Defs.TILE
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]    # N E S W

var game: Game
var segs := {}                    # Vector2i -> PipeSeg
var version := 0                  # bumped whenever the set of segments or their state changes (snapshots)
var enforce := true               # false: Clockwork buildings work without the Line (old tests, sandbox)
var overlay_on := false           # the pressure overlay (hotkey / button)
var bstate := {}                  # Building -> {"p": pressure, "touch": bool, "state": String}
var _team_stats := {}             # team -> {"supply", "draw", "share"} of its biggest Line (for the HUD)
var _dirty := true
var _solve_t := 0.0
var _clock := 0.0
var _redraw_t := 0.0
var _ground: Node2D
var _top: Node2D
var _warned := {}                 # Building instance id -> true: told the player it has no Line
var _occ := {}                    # cell -> the consumer / source Building standing on it (for the joints)

# the Line tool's preview (set by LineTool / Controls)
var tool_on := false
var tool_from := Vector2i(-1, -1)
var tool_path: Array = []
var tool_info := {}


func _ready() -> void:
	_ground = Node2D.new()
	_ground.z_index = -17
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_top = Node2D.new()
	_top.z_index = 30
	_top.draw.connect(_draw_top)
	add_child(_top)


# ------------------------------------------------------------------ the grid

func has_cell(c: Vector2i) -> bool:
	return segs.has(c)


func seg_at(c: Vector2i) -> PipeSeg:
	return segs.get(c)


func changed() -> void:
	_dirty = true
	version += 1


## A building cannot be put on a pipe (or a planned one).
func blocks(cell: Vector2i, size: Vector2i) -> bool:
	if segs.is_empty():
		return false
	for y in size.y:
		for x in size.x:
			if segs.has(cell + Vector2i(x, y)):
				return true
	return false


## Can team t put a pipe on this cell? (free ground: no building, cliff, water, ramp, ghost site, other pipe)
func pipeable(t: int, c: Vector2i) -> bool:
	if not game.in_map(c):
		return false
	if segs.has(c):
		return segs[c].team == t
	var i := game.idx(c)
	if game.solid[i] != 0 or game.cliff[i] != 0 or game.water[i] != 0:
		return false
	if game.ghost_cells.has(i):
		return false
	return true


func _add_seg(t: int, c: Vector2i, complete: bool) -> PipeSeg:
	var s := PipeSeg.new()
	s.setup(self, t, c, complete)
	add_child(s)
	segs[c] = s
	changed()
	return s


## Remove a segment (destroyed, or a ghost cancelled: its ore comes back).
func remove_seg(s: PipeSeg, died := false) -> void:
	if segs.get(s.cell) == s:
		segs.erase(s.cell)
	if not died and not s.built:
		game.players[s.team]["gold"] += int(s.d["cost"])
	s.dead = true
	s.queue_free()
	changed()
	if died and game.mlog and s.team == game.human:
		game.mlog.add("%s lost a pipe segment at %d,%d" % [game.mlog.who(s.team), s.cell.x, s.cell.y])


## Place a finished segment (match start, the AI's first main, tests): no ore, no work.
func add_built(t: int, c: Vector2i) -> PipeSeg:
	if segs.has(c):
		return segs[c]
	return _add_seg(t, c, true)


# ------------------------------------------------------------------ routing

## The route for a Line order from cell a to cell b: {ok, why, cells, new (cells still to lay), cost,
## pressure (estimated at b once laid)}. 4-way A* over free ground; existing pipes of the team are
## nearly free to reuse, a turn costs a little, so runs are straight where they can be.
func plan(t: int, a: Vector2i, b: Vector2i) -> Dictionary:
	var out := {"ok": false, "why": "", "cells": [], "new": 0, "cost": 0, "pressure": 0.0}
	if not pipeable(t, a) or not pipeable(t, b):
		out["why"] = "Pipes need free ground at both ends."
		return out
	if a == b:
		out["why"] = "Pick a second point."
		return out
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y)) - Vector2i(14, 14)
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y)) + Vector2i(14, 14)
	var best := {}              # state -> cost
	var prev := {}              # state -> previous state
	var heap: Array = []        # [f, g, cell, dir]
	var start_state := _st(a, 4)
	best[start_state] = 0.0
	_heap_push(heap, [float(absi(a.x - b.x) + absi(a.y - b.y)), 0.0, a, 4])
	var goal_state := -1
	var guard := 0
	while not heap.is_empty() and guard < 40000:
		guard += 1
		var cur: Array = _heap_pop(heap)
		var c: Vector2i = cur[2]
		var dir: int = cur[3]
		var g: float = cur[1]
		var cs := _st(c, dir)
		if g > float(best.get(cs, INF)) + 0.0001:
			continue
		if c == b:
			goal_state = cs
			break
		for di in 4:
			var n: Vector2i = c + DIRS[di]
			if n.x < lo.x or n.y < lo.y or n.x > hi.x or n.y > hi.y or not pipeable(t, n):
				continue
			var step := 0.15 if segs.has(n) else 1.0
			if dir != 4 and dir != di:
				step += 0.35
			var ng := g + step
			var ns := _st(n, di)
			if ng < float(best.get(ns, INF)):
				best[ns] = ng
				prev[ns] = cs
				_heap_push(heap, [ng + float(absi(n.x - b.x) + absi(n.y - b.y)), ng, n, di])
	if goal_state < 0:
		out["why"] = "No free route."
		return out
	var cells: Array = []
	var s := goal_state
	while true:
		cells.append(_unst(s))
		if s == start_state:
			break
		s = prev[s]
	cells.reverse()
	if cells.size() > int(Defs.LINE["max_run"]):
		out["why"] = Loc.t("Too long: lay it in runs of %d.") % int(Defs.LINE["max_run"])
		out["cells"] = cells
		return out
	var fresh := 0
	for c in cells:
		if not segs.has(c):
			fresh += 1
	out["ok"] = true
	out["cells"] = cells
	out["new"] = fresh
	out["cost"] = fresh * int(Defs.LINE["pipe"]["cost"])
	out["pressure"] = estimate_at(t, cells, b)
	return out


func _st(c: Vector2i, dir: int) -> int:
	return ((c.y + 4096) * 8192 + (c.x + 4096)) * 5 + dir


func _unst(s: int) -> Vector2i:
	var k := s / 5
	return Vector2i(k % 8192 - 4096, k / 8192 - 4096)


func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if float(h[p][0]) <= float(h[i][0]):
			break
		var tmp = h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p


func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i := 0
		var n := h.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and float(h[l][0]) < float(h[m][0]):
				m = l
			if r < n and float(h[r][0]) < float(h[m][0]):
				m = r
			if m == i:
				break
			var tmp = h[m]
			h[m] = h[i]
			h[i] = tmp
			i = m
	return top


## Pressure that would reach cell `at` if `extra` cells were laid (all unfinished pipes of the team count
## as laid too). 0 when no source touches the Line.
func estimate_at(t: int, extra: Array, at: Vector2i) -> float:
	var r := _solve(t, extra)
	return float(r["p"].get(at, 0.0))


# ------------------------------------------------------------------ laying

## Lay a Line order for team t along `cells` (already routed): ghost segments for the cells that have no
## pipe, paid in ore up front; the builders (Winders) are sent to lay them. Returns the new segments.
func lay(t: int, cells: Array, builders: Array, queued := false) -> Array:
	var fresh: Array = []
	for c in cells:
		if not segs.has(c) and pipeable(t, c):
			fresh.append(c)
	var cost := fresh.size() * int(Defs.LINE["pipe"]["cost"])
	if fresh.size() > int(Defs.LINE["max_run"]) * 2 or int(game.players[t]["gold"]) < cost:
		if t == game.human and not game.demo:
			game.notify("Not enough ore for the pipe.")
		return []
	game.players[t]["gold"] -= cost
	game.stats[t]["spent"] += cost
	var made: Array = []
	for c in fresh:
		made.append(_add_seg(t, c, false))
	if made.is_empty():
		return made
	for u in builders:
		if u is Unit and not u.dead and u.kind == "winder":
			LineWork.cmd_lay(u, _nearest_seg(made, u.position))
	return made


func _nearest_seg(list: Array, p: Vector2) -> PipeSeg:
	var best: PipeSeg = list[0]
	var bd := INF
	for s in list:
		var dd: float = s.global_position.distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = s
	return best


## The nearest unfinished segment of team t to p (for a Winder who finished one), or null.
func next_unbuilt(t: int, p: Vector2, within := INF) -> PipeSeg:
	var best: PipeSeg = null
	var bd := within * within
	for s in segs.values():
		if s.team == t and not s.built and not s.dead:
			var dd: float = s.global_position.distance_squared_to(p)
			if dd < bd:
				bd = dd
				best = s
	return best


func unbuilt_count(t: int) -> int:
	var n := 0
	for s in segs.values():
		if s.team == t and not s.built:
			n += 1
	return n


func count(t: int, built_only := true) -> int:
	var n := 0
	for s in segs.values():
		if s.team == t and (s.built or not built_only):
			n += 1
	return n


# ------------------------------------------------------------------ targeting and repair

## Enemy pipes in reach of a unit (the lowest priority: nothing else to shoot).
func pipe_target(u: Unit, r: float) -> Entity:
	if segs.is_empty():
		return null
	var uc := game.cell_of(u.position)
	var rc := int(ceil(r / T)) + 1
	var best: Entity = null
	var bd := r
	for y in range(uc.y - rc, uc.y + rc + 1):
		for x in range(uc.x - rc, uc.x + rc + 1):
			var s: PipeSeg = segs.get(Vector2i(x, y))
			if s == null or s.dead or not game.hostile(s.team, u.team) or not u.can_hit(s):
				continue
			var dd := s.edge_distance(u.position)
			if dd < bd and game.side_sees(u.team, s.center()):
				bd = dd
				best = s
	return best


## A damaged or unfinished segment of team t within r of a Winder (Game.find_repair).
func damaged_near(t: int, p: Vector2, r: float) -> Entity:
	var uc := game.cell_of(p)
	var rc := int(ceil(r / T)) + 1
	var best: Entity = null
	var bd := r
	for y in range(uc.y - rc, uc.y + rc + 1):
		for x in range(uc.x - rc, uc.x + rc + 1):
			var s: PipeSeg = segs.get(Vector2i(x, y))
			if s == null or s.dead or s.team != t or s.hp >= s.max_hp * 0.95:
				continue
			var dd := s.edge_distance(p)
			if dd < bd:
				bd = dd
				best = s
	return best


# ------------------------------------------------------------------ buildings and the Line

## The cells round a footprint's four sides (corners left out).
func ring(b: Building) -> Array:
	return ring_of(b.cell, b.size)


static func ring_of(cell: Vector2i, size: Vector2i) -> Array:
	var out: Array = []
	for x in size.x:
		out.append(cell + Vector2i(x, -1))
		out.append(cell + Vector2i(x, size.y))
	for y in size.y:
		out.append(cell + Vector2i(-1, y))
		out.append(cell + Vector2i(size.x, y))
	return out


## Does a finished pipe of the building's team touch it?
func touches(b: Building) -> bool:
	for c in ring(b):
		var s: PipeSeg = segs.get(c)
		if s != null and s.team == b.team and s.built:
			return true
	return false


func is_consumer(b: Building) -> bool:
	return Defs.LINE["draw"].has(b.kind)


func is_source(b: Building) -> bool:
	return Defs.LINE["supply"].has(b.kind)


## Pressure (0..1) at a building, from the last solve.
func pressure_at(b: Building) -> float:
	if b.kind == "clocktower" and b.built and not b.dead:
		return 1.0
	return float(bstate.get(b, {}).get("p", 0.0))


## Work speed of a building: 1.0 for everything that is not a Clockwork consumer.
func speed_mult(b: Building) -> float:
	if not enforce or not Defs.LINE["draw"].has(b.kind):
		return 1.0
	return Defs.line_speed(pressure_at(b))


## "ok", "weak" (below full speed), "starved" (touches a Line with no pressure), "off" (touches none).
func state_of(b: Building) -> String:
	if not enforce or not is_consumer(b) or not b.built or b.dead:
		return "ok"
	var st: Dictionary = bstate.get(b, {})
	if st.is_empty() or not st.get("touch", false):
		return "off"
	var p := float(st["p"])
	if p < float(Defs.LINE["speed"]["off"]):
		return "starved"
	return "weak" if p < float(Defs.LINE["speed"]["full"]) else "ok"


func stats_of(t: int) -> Dictionary:
	return _team_stats.get(t, {"supply": 0.0, "draw": 0.0, "share": 1.0})


# ------------------------------------------------------------------ the solver

## Pressure on one team's Line. `extra`: cells counted as pipe on top of the finished ones (the unfinished
## ones of the team count too when extra is given: a preview). Returns {"p": cell -> pressure,
## "b": Building -> pressure at the consumer, "supply", "draw", "share"}.
func _solve(t: int, extra: Array = []) -> Dictionary:
	var nodes := {}
	for c in segs:
		var s: PipeSeg = segs[c]
		if s.team == t and not s.dead and (s.built or not extra.is_empty()):
			nodes[c] = true
	for c in extra:
		nodes[c] = true
	var sources: Array = []
	var consumers: Array = []
	var relays: Array = []
	var heads := {}
	for b in game.buildings:
		if b.team != t or b.dead or not b.built:
			continue
		var tc: Array = []
		if is_source(b) or is_consumer(b):
			for c in ring(b):
				if nodes.has(c):
					tc.append(c)
		if is_source(b):
			sources.append([b, tc])
			for c in tc:
				heads[c] = 1.0
		if is_consumer(b):
			consumers.append([b, tc])
			if b.kind == "pressure_relay":
				relays.append([b, tc])
	var fall := float(Defs.LINE["fall"])
	var raw := _relax(nodes, heads, fall)
	var rl: Dictionary = Defs.LINE["relay"]
	var done := {}
	while true:
		var pick: Array = []
		var pin := 0.0
		for r in relays:
			if done.has(r[0]):
				continue
			var m := 0.0
			for c in r[1]:
				m = maxf(m, float(raw.get(c, 0.0)))
			if m >= float(rl["min_in"]) and m > pin:
				pin = m
				pick = r
		if pick.is_empty():
			break
		done[pick[0]] = true
		var head := minf(float(rl["max_out"]), pin + float(rl["boost"]))
		if head > pin + 0.001:
			for c in pick[1]:
				heads[c] = maxf(float(heads.get(c, 0.0)), head)
			raw = _relax(nodes, heads, fall)
	# connected pieces, the supply and the draw of each
	var comp := {}
	var n_comp := 0
	for c in nodes:
		if comp.has(c):
			continue
		var q: Array = [c]
		comp[c] = n_comp
		var qi := 0
		while qi < q.size():
			var cur: Vector2i = q[qi]
			qi += 1
			for d in DIRS:
				var nb: Vector2i = cur + d
				if nodes.has(nb) and not comp.has(nb):
					comp[nb] = n_comp
					q.append(nb)
		n_comp += 1
	var supply := []
	var draw := []
	supply.resize(n_comp)
	draw.resize(n_comp)
	supply.fill(0.0)
	draw.fill(0.0)
	for s in sources:
		var c0 := _best_cell(s[1], raw)
		if c0.x > -9999:
			supply[comp[c0]] += float(Defs.LINE["supply"][s[0].kind])
	for cn in consumers:
		var c1 := _best_cell(cn[1], raw)
		if c1.x > -9999:
			draw[comp[c1]] += float(Defs.LINE["draw"][cn[0].kind])
	var share := []
	share.resize(n_comp)
	for i in n_comp:
		share[i] = 0.0 if supply[i] <= 0.0 else (1.0 if draw[i] <= supply[i] else supply[i] / draw[i])
	var eff := {}
	for c in nodes:
		eff[c] = float(raw.get(c, 0.0)) * float(share[comp[c]])
	var bp := {}
	for cn in consumers:
		var m2 := 0.0
		for c in cn[1]:
			m2 = maxf(m2, float(eff.get(c, 0.0)))
		bp[cn[0]] = [m2, not (cn[1] as Array).is_empty()]
	# the team's biggest Line, for the HUD
	var bi := -1
	var bs := -1.0
	for i in n_comp:
		if supply[i] + draw[i] > bs:
			bs = supply[i] + draw[i]
			bi = i
	var out := {"p": eff, "b": bp, "supply": 0.0, "draw": 0.0, "share": 1.0}
	if bi >= 0:
		out["supply"] = supply[bi]
		out["draw"] = draw[bi]
		out["share"] = share[bi]
	return out


func _best_cell(cells: Array, raw: Dictionary) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	var bp := -1.0
	for c in cells:
		var p := float(raw.get(c, 0.0))
		if p > bp:
			bp = p
			best = c
	return best


## Label-correcting spread of the highest pressure: each segment gets (neighbour's - fall).
func _relax(nodes: Dictionary, heads: Dictionary, fall: float) -> Dictionary:
	var raw := {}
	var q: Array = []
	for c in heads:
		if nodes.has(c):
			raw[c] = float(heads[c])
			q.append(c)
	var i := 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		var p: float = float(raw[c]) - fall
		if p <= 0.0:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if nodes.has(n) and float(raw.get(n, -1.0)) < p - 0.00001:
				raw[n] = p
				q.append(n)
	return raw


## Solve every Clockwork team's Line and store the result on the segments and the buildings.
func solve() -> void:
	_dirty = false
	bstate = {}
	_occ = {}
	for b in game.buildings:
		if not b.dead and (is_consumer(b) or is_source(b)):
			for y in b.size.y:
				for x in b.size.x:
					_occ[b.cell + Vector2i(x, y)] = b
	_team_stats = {}
	var teams := {}
	for s in segs.values():
		teams[s.team] = true
	for b in game.buildings:
		if b.d.get("faction", "") == "clockwork" and not b.dead:
			teams[b.team] = true
	for t in teams:
		var r := _solve(t)
		for c in segs:
			var s: PipeSeg = segs[c]
			if s.team == t:
				s.pressure = float(r["p"].get(c, 0.0))
		for b in r["b"]:
			bstate[b] = {"p": r["b"][b][0], "touch": r["b"][b][1]}
		_team_stats[t] = {"supply": r["supply"], "draw": r["draw"], "share": r["share"]}
	for b in game.buildings:
		if is_consumer(b) and b.built and not b.dead and not bstate.has(b):
			bstate[b] = {"p": 0.0, "touch": false}
	_warn_players()
	_ground.queue_redraw()


## Tell the player (once per building) that a finished building has no Line.
func _warn_players() -> void:
	if game.demo or game.hud == null:
		return
	for b in bstate:
		if b.team != game.human or not b.built or b.dead:
			continue
		var id: int = b.get_instance_id()
		if state_of(b) == "off" and not _warned.has(id):
			_warned[id] = true
			game.hud.toast(Loc.t("The %s has no Line beside it: it will not work. Lay pipe to it (LINE).") % Loc.t(String(b.d["name"])), false)
		elif state_of(b) != "off":
			_warned.erase(id)


# ------------------------------------------------------------------ ticking

func tick(delta: float) -> void:
	_clock += delta
	_solve_t -= delta
	if _solve_t <= 0.0:
		_solve_t = float(Defs.LINE["solve"])
		solve()
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.12
		_ground.queue_redraw()
		_top.queue_redraw()


## The online guest does not simulate, but solves its own copy of the pipes for display.
func tick_view(delta: float) -> void:
	tick(delta)


# ------------------------------------------------------------------ save and online

## One row per segment: [x, y, team, hp, progress, built].
func save() -> Array:
	var rows: Array = []
	for c in segs:
		var s: PipeSeg = segs[c]
		if s.dead:
			continue
		rows.append([c.x, c.y, s.team, snappedf(s.hp, 0.1), snappedf(s.progress, 0.01), 1 if s.built else 0])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] * 100000 + a[0] < b[1] * 100000 + b[0])
	return rows


## Put the segments back as the rows say (adding, updating and removing as needed).
func load_rows(rows: Array) -> void:
	var seen := {}
	for r in rows:
		var c := Vector2i(int(r[0]), int(r[1]))
		seen[c] = true
		var s: PipeSeg = segs.get(c)
		if s == null or s.team != int(r[2]):
			if s != null:
				remove_seg(s, true)
			s = _add_seg(int(r[2]), c, int(r[5]) == 1)
		s.hp = float(r[3])
		s.progress = float(r[4])
		if (int(r[5]) == 1) != s.built:
			s.built = int(r[5]) == 1
			changed()
	for c in segs.keys():
		if not seen.has(c):
			remove_seg(segs[c], true)
	_dirty = true


func clear() -> void:
	for c in segs.keys():
		var s: PipeSeg = segs[c]
		segs.erase(c)
		s.queue_free()
	changed()


## A short fingerprint of the segments (snapshots send them only when it changes).
func fingerprint() -> int:
	var h := segs.size()
	for c in segs:
		var s: PipeSeg = segs[c]
		h = (h + (c.x * 7919 + c.y * 104729 + (1 if s.built else 0) * 31 + int(s.hp / 10.0)) * 2654435761) & 0x7fffffff    # (a sum: the order of the dictionary does not matter)
	return h


# ------------------------------------------------------------------ the start of a match

## Lay a finished main from the team's Clocktower to its starting buildings (the Ore Crusher).
func lay_start(t: int) -> void:
	var hall: Building = null
	for b in game.buildings:
		if b.team == t and b.kind == "clocktower":
			hall = b
			break
	if hall == null:
		return
	for b in game.buildings:
		if b.team == t and b != hall and (is_consumer(b) or is_source(b)) and not touches(b):
			connect_building(t, hall, b, true)


## Route a pipe from whatever Line the team has beside `from_b` to a cell touching `to_b`. Returns the plan.
## complete: lay it finished (no ore, no work).
func connect_building(t: int, from_b: Building, to_b: Building, complete := false, builders: Array = []) -> Dictionary:
	var best := {}
	var bd := INF
	var starts: Array = []
	for c in ring(from_b):
		if pipeable(t, c):
			starts.append(c)
	# any finished pipe of ours that is part of the Line the source touches is a start too
	for c in network_cells(t, from_b):
		starts.append(c)
	var goals: Array = []
	for c in ring(to_b):
		if pipeable(t, c):
			goals.append(c)
	if starts.is_empty() or goals.is_empty():
		return {"ok": false}
	goals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(Vector2(to_b.cell)) < Vector2(b).distance_squared_to(Vector2(to_b.cell)))
	var pairs: Array = []
	for s in starts:
		for g in goals:
			pairs.append([s, g, absi(s.x - g.x) + absi(s.y - g.y)])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	var tried := 0
	for pr in pairs:
		if tried >= 4:
			break
		tried += 1
		var p := plan(t, pr[0], pr[1]) if pr[0] != pr[1] else {"ok": true, "cells": [pr[0]], "new": 1, "cost": 0}
		if p["ok"] and p["cells"].size() > 0:
			var score := float(p["new"])
			if score < bd:
				bd = score
				best = p
	if best.is_empty():
		return {"ok": false}
	if complete:
		for c in best["cells"]:
			add_built(t, c)
	else:
		lay(t, best["cells"], builders)
	best["laid"] = true
	return best


## Finished pipe cells of team t that are part of the Line `b` touches (empty if it touches none).
func network_cells(t: int, b: Building) -> Array:
	var seeds: Array = []
	for c in ring(b):
		var s: PipeSeg = segs.get(c)
		if s != null and s.team == t and s.built:
			seeds.append(c)
	if seeds.is_empty():
		return []
	var seen := {}
	var q: Array = []
	for c in seeds:
		seen[c] = true
		q.append(c)
	var i := 0
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		for d in DIRS:
			var nb: Vector2i = cur + d
			var s: PipeSeg = segs.get(nb)
			if not seen.has(nb) and s != null and s.team == t and s.built:
				seen[nb] = true
				q.append(nb)
	return q


# ------------------------------------------------------------------ drawing

func _visible_seg(s: PipeSeg) -> bool:
	var me := game.controlled_team()
	if me >= 0 and game.allied(me, s.team):
		return true
	if me < 0 and game.view_team < 0:
		return true
	return game.is_visible_to(me if me >= 0 else game.view_team, s.center())


func pressure_colour(p: float) -> Color:
	var tint: Array = Defs.LINE["tint"]
	p = clampf(p, 0.0, 1.0)
	if p < 0.5:
		return (tint[0] as Color).lerp(tint[1], p / 0.5)
	return (tint[1] as Color).lerp(tint[2], (p - 0.5) / 0.5)


func _mask(s: PipeSeg) -> int:
	var m := 0
	for i in 4:
		var n: Vector2i = s.cell + DIRS[i]
		var o: PipeSeg = segs.get(n)
		if o != null and o.team == s.team:
			m |= 1 << i
	return m


## Bits for the sides of this cell that face a Clockwork building which uses the Line.
func _building_mask(s: PipeSeg) -> int:
	var m := 0
	for i in 4:
		var n: Vector2i = s.cell + DIRS[i]
		var occ: Building = _occ.get(n)
		if occ != null and is_instance_valid(occ) and occ.team == s.team:
			m |= 1 << i
	return m


func overlay() -> bool:
	return overlay_on or tool_on


func redraw() -> void:
	if _ground:
		_ground.queue_redraw()
		_top.queue_redraw()


func _draw_ground() -> void:
	if segs.is_empty():
		return
	var view: Rect2 = game.view_rect
	var steam_n := 0
	for c in segs:
		var s: PipeSeg = segs[c]
		if s.dead or not view.intersects(s.rect()) or not _visible_seg(s):
			continue
		var m := _mask(s) | _building_mask(s)
		steam_n += _draw_pipe(_ground, s, m, steam_n)
	if tool_on and not tool_path.is_empty():
		_draw_tool(_ground)


func _draw_pipe(cv: Node2D, s: PipeSeg, mask: int, steam_n: int) -> int:
	var o := s.global_position
	var ghost := not s.built
	var p := s.pressure if s.built else 0.0
	var steel := Color(0.34, 0.36, 0.40) if not ghost else Color(0.55, 0.62, 0.70, 0.45)
	var dark := Color(0.10, 0.10, 0.12) if not ghost else Color(0.15, 0.2, 0.25, 0.5)
	var hi := Color(0.62, 0.65, 0.70) if not ghost else Color(0.8, 0.9, 1.0, 0.4)
	var tx := LineArt.pipe(mask)
	if tx != null:
		var tl := o - Vector2(T, T) * 0.5
		var straight := "ew" if mask == 10 else ("ns" if mask == 5 else "")
		var dmg: Texture2D = null
		if straight != "" and s.built and s.hp < s.max_hp * 0.5:
			dmg = LineArt.damage(straight, "damaged")
		cv.draw_texture(dmg if dmg != null else tx, tl, Color(0.6, 0.8, 1.0, 0.5) if ghost else Color.WHITE)
		if s.built:
			# the pressure lamp (the art has no tint layer): a small coloured bar on the top deck
			var gc := pressure_colour(p)
			cv.draw_rect(Rect2(o + Vector2(-4, -9), Vector2(8, 3)), Color(0, 0, 0, 0.7))
			cv.draw_rect(Rect2(o + Vector2(-3, -8), Vector2(6, 1)), gc)
			if overlay():
				cv.draw_rect(Rect2(tl + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(gc.r, gc.g, gc.b, 0.35))
		elif s.progress > 0.0:
			cv.draw_rect(Rect2(tl + Vector2(2, T - 5), Vector2((T - 4) * s.progress, 3)), Color(0.7, 0.9, 1.0, 0.8))
		return _draw_damage(cv, s, o, dmg != null)
	var w := 14.0
	var arms: Array = []
	for i in 4:
		if mask & (1 << i):
			arms.append(Vector2(DIRS[i]) * (T * 0.5))
	if arms.is_empty():
		arms = [Vector2(-T * 0.2, 0), Vector2(T * 0.2, 0)]
	if arms.size() == 1:
		arms.append(-arms[0] * 0.35)
	var col := pressure_colour(p) if s.built else Color(0.7, 0.85, 1.0, 0.5)
	if overlay() and s.built:
		col = col.lightened(0.05)
	# body: outline, steel, pressure stripe, highlight
	for a in arms:
		cv.draw_line(o, o + a, dark, w + 4.0, true)
	cv.draw_circle(o, w * 0.5 + 2.0, dark)
	for a in arms:
		cv.draw_line(o, o + a, steel, w, true)
	cv.draw_circle(o, w * 0.5, steel)
	var stripe := w * (0.62 if overlay() else 0.34)
	if s.built:
		for a in arms:
			cv.draw_line(o, o + a, col, stripe, true)
		cv.draw_circle(o, stripe * 0.5, col)
	elif s.progress > 0.0:
		for a in arms:
			cv.draw_line(o, o + a * s.progress, Color(0.7, 0.85, 1.0, 0.6), 4.0, true)
	for a in arms:
		cv.draw_line(o + Vector2(0, -w * 0.32), o + a + Vector2(0, -w * 0.32), hi, 1.5) if absf(a.y) < 1.0 else cv.draw_line(o + Vector2(-w * 0.32, 0), o + a + Vector2(-w * 0.32, 0), hi, 1.5)
	# the rail on the top deck: two steel rails and sleepers along every arm
	if s.built:
		for a in arms:
			var dir: Vector2 = a.normalized()
			var perp := Vector2(-dir.y, dir.x)
			var n := int(a.length() / 7.0)
			for k in range(1, n + 1):
				var q: Vector2 = o + dir * (7.0 * k - 3.0)
				cv.draw_line(q + perp * 4.5, q - perp * 4.5, Color(0.28, 0.17, 0.09), 2.0)
			cv.draw_line(o + perp * 2.6, o + a + perp * 2.6, Color(0.75, 0.77, 0.8), 1.2)
			cv.draw_line(o - perp * 2.6, o + a - perp * 2.6, Color(0.75, 0.77, 0.8), 1.2)
	var deg := 0
	for i in 4:
		if mask & (1 << i):
			deg += 1
	# flanges: a collar on each open end, a bolted ring at corners, T and cross, a cap on an end
	for a in arms:
		if mask != 0 and a.length() > 8.0:
			var dir: Vector2 = a.normalized()
			var perp := Vector2(-dir.y, dir.x)
			var e: Vector2 = o + a * 0.94
			cv.draw_line(e + perp * (w * 0.62), e - perp * (w * 0.62), dark, 5.0)
			cv.draw_line(e + perp * (w * 0.6), e - perp * (w * 0.6), hi if not ghost else steel, 2.0)
	if deg == 1 or deg == 0:
		cv.draw_circle(o + (arms[1] if deg == 1 else Vector2.ZERO), 5.0, dark)
		cv.draw_circle(o + (arms[1] if deg == 1 else Vector2.ZERO), 3.2, hi)
	if deg >= 3 or (deg == 2 and (mask == 3 or mask == 6 or mask == 12 or mask == 9)):
		cv.draw_circle(o, w * 0.5 + 3.0, dark)
		cv.draw_circle(o, w * 0.5 + 1.0, steel)
		cv.draw_circle(o, 3.0, hi)
		for k in 4:
			var ang := PI * 0.25 + k * PI * 0.5
			cv.draw_circle(o + Vector2(cos(ang), sin(ang)) * (w * 0.5 - 0.5), 1.2, dark)
	return _draw_damage(cv, s, o)


func _draw_damage(cv: Node2D, s: PipeSeg, o: Vector2, art_done := false) -> int:
	if s.built and s.hp < s.max_hp * 0.6 and not art_done:
		if true:
			cv.draw_line(o + Vector2(-5, -3), o + Vector2(0, 2), Color(0.05, 0.03, 0.03), 2.0)
			cv.draw_line(o + Vector2(0, 2), o + Vector2(5, -1), Color(0.05, 0.03, 0.03), 2.0)
	if s.hp < s.max_hp and s.built:
		var f := s.hp / s.max_hp
		cv.draw_rect(Rect2(o + Vector2(-9, 9), Vector2(18, 3)), Color(0, 0, 0, 0.6))
		cv.draw_rect(Rect2(o + Vector2(-9, 9), Vector2(18.0 * f, 3)), Color(0.9, 0.3, 0.2) if f < 0.4 else Color(0.95, 0.8, 0.2))
	return 0


func _puff(cv: Node2D, at: Vector2, phase: float, big: float, p: float) -> void:
	var st := LineArt.steam(1)
	if st != null:
		var f := LineArt.steam(1 + int(phase * 3.99))
		if f != null:
			cv.draw_texture(f, at - f.get_size() * Vector2(0.5, 1.0) * big, Color(1, 1, 1, clampf(0.4 + p, 0.0, 1.0)))
		return
	var a := (1.0 - phase) * 0.55 * clampf(p + 0.2, 0.0, 1.0)
	cv.draw_circle(at + Vector2(sin(phase * 5.0) * 3.0, -phase * 16.0 * big - 3.0), (2.5 + phase * 5.0) * big, Color(0.93, 0.95, 0.97, a))


func _draw_top() -> void:
	var view: Rect2 = game.view_rect
	var font := ThemeDB.fallback_font
	# steam puffs at joints and leaks
	var n_puff := 0
	for c in segs:
		var s: PipeSeg = segs[c]
		if s.dead or not s.built or n_puff > 60 or not view.intersects(s.rect()) or not _visible_seg(s):
			continue
		var h: int = (c.x * 73856093) ^ (c.y * 19349663)
		var leaking := s.hp < s.max_hp * 0.5
		if s.pressure > 0.15 and ((h & 7) == 0 or leaking):
			var ph := fposmod(_clock * (0.45 if not leaking else 0.9) + float(h & 255) / 255.0, 1.0)
			_puff(_top, s.global_position + Vector2(4, -4), ph, 1.6 if leaking else 1.0, s.pressure)
			n_puff += 1
	# gauges and warnings over the Clockwork buildings that use the Line
	var me := game.controlled_team()
	for b in game.buildings:
		if b.dead or not b.built or not view.intersects(b.rect()):
			continue
		if me >= 0 and not game.allied(me, b.team):
			continue
		if not (is_consumer(b) or is_source(b)):
			continue
		var st := state_of(b)
		var top: Vector2 = b.rect().get_center() + Vector2(0, -b.rect().size.y * 0.5 - 14.0)
		if is_source(b):
			if overlay():
				_badge(font, top, "%d" % int(Defs.LINE["supply"][b.kind]), Color(0.55, 0.85, 1.0), false)
			if b.kind == "boiler" and not touches(b):
				_badge(font, top, "NO LINE", Color(0.9, 0.35, 0.25), true)
			continue
		if st == "off":
			_badge(font, top, "NO LINE", Color(0.9, 0.3, 0.25), true)
		elif st == "starved":
			_badge(font, top, "NO PRESSURE", Color(0.9, 0.3, 0.25), true)
		elif st == "weak":
			_badge(font, top, "%d%%" % int(round(pressure_at(b) * 100.0)), Color(0.95, 0.75, 0.25), false)
		elif overlay():
			_badge(font, top, "%d%%" % int(round(pressure_at(b) * 100.0)), pressure_colour(pressure_at(b)), false)
	if tool_on and not tool_path.is_empty():
		_draw_tool_text(font)


func _badge(font: Font, p: Vector2, txt: String, col: Color, alarm: bool) -> void:
	txt = Loc.t(txt)
	var sz := 12
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var r := Rect2(p + Vector2(-w * 0.5 - 14.0, -9.0), Vector2(w + 22.0, 17.0))
	_top.draw_rect(r, Color(0.05, 0.05, 0.07, 0.82))
	_top.draw_rect(r, col, false, 1.5)
	# a small pressure dial
	var dc := r.position + Vector2(9.0, 8.5)
	_top.draw_arc(dc, 5.0, PI * 0.8, PI * 2.2, 10, col, 1.5)
	var need := 0.25 if alarm else 0.6
	_top.draw_line(dc, dc + Vector2(cos(PI * (0.8 + 1.4 * need)), sin(PI * (0.8 + 1.4 * need))) * 4.0, col, 1.5)
	_top.draw_string(font, r.position + Vector2(18.0, 13.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw_tool(cv: Node2D) -> void:
	var ok: bool = tool_info.get("ok", false)
	var col := Color(0.6, 0.9, 1.0, 0.55) if ok else Color(1.0, 0.4, 0.3, 0.5)
	for c in tool_path:
		var r := Rect2(Vector2(c) * T + Vector2(8, 8), Vector2(T - 16, T - 16))
		var have: bool = segs.has(c)
		cv.draw_rect(r, Color(col.r, col.g, col.b, 0.25 if have else 0.55))
		cv.draw_rect(r, col, false, 1.5)
	if tool_from.x >= 0:
		cv.draw_rect(Rect2(Vector2(tool_from) * T + Vector2(3, 3), Vector2(T - 6, T - 6)), Color(1, 1, 1, 0.9), false, 2.0)


func _draw_tool_text(font: Font) -> void:
	var last: Vector2i = tool_path[tool_path.size() - 1]
	var p := Vector2(last) * T + Vector2(T * 0.5, -10.0)
	var lines: Array = []
	if tool_info.get("ok", false):
		lines.append("%d %s · %d %s" % [int(tool_info["cost"]), Loc.t("ore"), int(tool_info["new"]), Loc.t("new")])
		lines.append(Loc.t("pressure there") + " ~%d%%" % int(round(float(tool_info["pressure"]) * 100.0)))
	else:
		lines.append(String(tool_info.get("why", "")))
	var y := 0.0
	for ln in lines:
		var t := Loc.t(String(ln))
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_top.draw_rect(Rect2(p + Vector2(-w * 0.5 - 4, y - 12), Vector2(w + 8, 17)), Color(0, 0, 0, 0.75))
		_top.draw_string(font, p + Vector2(-w * 0.5, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.97, 1.0) if tool_info.get("ok", false) else Color(1, 0.55, 0.45))
		y -= 19.0
