extends RefCounted
## CROWN WALL EXPAND (the owner, 2026-10-31: "crown ai should attempt to expand making walls, not only palisade but all
## buildings that are not in the main base like churches, barracks, foundries, cottages, buildings that have full sprite
## colliders, should be a part of their wall, they can't expand in the open without walls"). docs/crown_wall_expand.md.
##
## Every Town Hall of the Crown computer (Normal and up) that is not its main gets a WALL PLAN the moment it is laid:
##  1. THE RING. For radii R_MIN..R_MAX round the hall: the hall's area is the ground walked to from the hall without
##     going that far (ramps and the cells beside them are left out: a wall is laid at the top or foot of a ramp, never on
##     it). The ring is the walkable ground just outside that area; its WAYS IN are the ring cells an enemy can walk to
##     from its own base without crossing the area (cells reached only through our own walls and gates need nothing).
##     The radius with the fewest ways-in cells is taken, as long as the area has room for the hall's farms and mill.
##  2. A GATE (two cells where it can) on the ways-in cell nearest our main by land: workers and the army pass it.
##  3. BUILDING SLOTS over the rest of the ways in: 4x3 (a Barracks, Foundry, Horse Breeder or Armoury), 3x3 (a Church)
##     and 2x2 (a Cottage) footprints, each covering at least two ways-in cells, chosen greedily (most cells first).
##     The computer's own buildings go into these slots (AI._find_spot asks slot_for first); while the hall's slots are
##     empty and the gold is there it builds into them (a Cottage while it needs supply, a Barracks, a Church).
##  4. PALISADE fills every ways-in cell no slot covers, laid as soon as the hall is placed (as the hall goes up).
##     SLOT_WAIT s after the hall stands, any slot still empty is closed with palisade instead.
##  5. While the plan is under CLOSED_SHARE closed the hall's guards stay there (AI._guard_new_hall), and the hall's farms and
##     mill go inside the ring (inside_spot), so the workers' walk from the hall to them never leaves the wall.
## Design (docs/design_principles.md 2 and 3): a walled expansion is the defender's advantage early (walls and chokes),
## built from buildings the computer needs anyway (production, supply): placement matters, nothing new costs more.

var ai = null
var on := not OS.get_cmdline_user_args().has("xw:off")     # (tests and studies switch it off for a "before" number: -- xw:off)
var plans: Dictionary = {}      # hall instance id -> plan (see _plan)
var _main_id := -1

const R_MIN := 8
const R_MAX := 16
const AREA_MIN := 230           # open cells inside the ring: the hall (20), two Farms with their margins (2 x 64), the Mill (25)
const SLOT_WAIT := 60.0         # s after the hall stands before an empty slot is closed with palisade
const CLOSED_SHARE := 0.85      # the share of ways-in cells closed before the guards may go home
const GATE_W := 2               # gate cells (the army files out without jamming, as at the main's ramp)
const SLOT_SIZES := [[Vector2i(4, 3), "barracks"], [Vector2i(3, 3), "church"], [Vector2i(2, 2), "cottage"]]
const SLOT_MAX := {"barracks": 3, "church": 1, "cottage": 4}
const SLOT_MIN_COVER := {"barracks": 3, "church": 2, "cottage": 2}
const KINDS_BY_SIZE := {Vector2i(4, 3): ["barracks", "foundry", "horse_breeder", "armoury"], Vector2i(3, 3): ["church"], Vector2i(2, 2): ["cottage"]}


func _init(a) -> void:
	ai = a


func active() -> bool:
	return on and ai.safe_opening and ai._crown() and ai.difficulty >= 1


var game:
	get:
		return ai.game


# ------------------------------------------------------------------ every think

func tick() -> void:
	if not active() or game.starts.size() <= ai.team:
		return
	var halls: Array = game.halls_of(ai.team, false)
	var home := Vector2(game.starts[ai.team]) * Defs.TILE
	var main: Building = null
	for h in halls:
		if main == null or h.center().distance_to(home) < main.center().distance_to(home):
			main = h
	if main == null:
		return
	_main_id = main.get_instance_id()
	for id in plans.keys():
		var p: Dictionary = plans[id]
		if not is_instance_valid(p["hall"]) or (p["hall"] as Building).dead:
			plans.erase(id)
	for h in halls:
		var id: int = h.get_instance_id()
		if h == main or plans.has(id):
			continue
		var p := plan_for(h.cell, h)
		plans[id] = p
		if game.mlog:
			if p.is_empty() or not p.get("ok", false):
				game.mlog.add("%s found no wall plan for its new Town Hall" % game.mlog.who(ai.team))
			else:
				game.mlog.add("%s plans a walled expansion: %d ways-in cells (radius %d), %d building slots, %d palisade, %d gate" % [
					game.mlog.who(ai.team), (p["exposed"] as Array).size(), int(p["r"]), (p["slots"] as Array).size(),
					(p["pieces"] as Array).filter(func(e): return e[0] == "wall").size(), (p["pieces"] as Array).filter(func(e): return e[0] == "gate").size()])
	for id in plans:
		var p: Dictionary = plans[id]
		if p.get("ok", false):
			_run(p)
	# a hall laid by another path than the hall plan (AI._hall_first) still gets its guards while its wall goes up
	if ai._new_hall == null:
		for id in plans:
			var p: Dictionary = plans[id]
			if p.get("ok", false) and holding_plan(p):
				ai._new_hall = p["hall"]
				ai._guards.clear()
				break


## The plan's slots and pieces kept up: slot buildings found, slots built into, empty slots closed with palisade after
## SLOT_WAIT, missing palisade and gates laid (and re-laid) as the gold allows, their builders sent.
func _run(p: Dictionary) -> void:
	var hall: Building = p["hall"]
	if hall.built and float(p["built_t"]) < 0.0:
		p["built_t"] = game.clock
	var late: bool = float(p["built_t"]) >= 0.0 and game.clock - float(p["built_t"]) > SLOT_WAIT
	for s in p["slots"]:
		if s["closed"]:
			continue
		var b: Building = s.get("b")
		if b != null and (not is_instance_valid(b) or b.dead):
			s["b"] = null
			b = null
		if b == null:
			b = _building_at(s["cell"], s["size"])
			s["b"] = b
		if b != null:
			continue
		var free: bool = game.placement_problem(ai.team, _slot_kind(s), s["cell"], true) == ""
		if late or not free:
			# (no building came, or the ground is taken: its ways-in cells get palisade)
			s["closed"] = true
			for c in s["cover"]:
				p["pieces"].append(["wall", c])
			if game.mlog:
				game.mlog.add("%s closes an empty wall slot at its new hall with palisade (%d pieces)" % [game.mlog.who(ai.team), (s["cover"] as Array).size()])
		elif hall.built:
			_fill_slot(p, s)
	_lay_pieces(p)
	_tend(p)


## The kind the computer would build into an empty slot now ("" for none).
func _slot_kind(s: Dictionary) -> String:
	var sz: Vector2i = s["size"]
	if sz == Vector2i(2, 2):
		return "cottage"
	if sz == Vector2i(3, 3):
		return "church"
	return "barracks"


func _fill_slot(p: Dictionary, s: Dictionary) -> void:
	var kind := _slot_kind(s)
	if ai._busy_building(kind) or not game.requirement_met(ai.team, kind):
		return
	var spare: int = ai._gold() - int(Defs.BUILDINGS[kind]["cost"]) - (ai._hall_keep() if ai._keeping() else 0)
	if spare < 0:
		return
	if kind == "cottage" and int(game.players[ai.team]["cap"]) >= game.max_supply(ai.team):
		return          # (supply it can't use: palisade at SLOT_WAIT instead)
	if kind == "church" and not ai._mine("church").is_empty():
		return
	if kind == "barracks" and (ai._mine("barracks").size() >= 9 or spare < 100):
		return
	ai._construct(kind, s["cell"])
	s["b"] = _building_at(s["cell"], s["size"])


func _building_at(c: Vector2i, size: Vector2i) -> Building:
	for b in game.buildings:
		if b.team == ai.team and not b.dead and b.cell == c and b.size == size:
			return b
	return null


## Palisade and gates of the plan not standing (or planned): laid as the gold allows, the cells nearest the enemy first;
## each batch gets a crew of the nearest free labourers (2, 3 for a long stretch).
func _lay_pieces(p: Dictionary) -> void:
	var todo: Array = []
	for e in p["pieces"]:
		var c: Vector2i = e[1]
		if game._own_gate_at(ai.team, c) != null or game._own_wall_at(ai.team, c) != null:
			continue
		if game.solid[game.idx(c)] == 2:
			continue          # (a building of ours stands there now)
		todo.append(e)
	if todo.is_empty():
		return
	if game.clock < float(p.get("next_lay", 0.0)):
		return
	# (the wall before the gold kept for the next hall; only the first Farm of a hall on fresh land while the rest is dry
	# comes before it: nothing else pays, test_ai_expand)
	var keep: int = ai._first_econ_cost() if _farm_first() else 0
	if ai._unsafe(((p["hall"] as Building).center())):
		return          # (a fight at the hall: the army first, the wall after)
	var foe: Vector2 = p["foe"]
	todo.sort_custom(func(a, b) -> bool: return Vector2(a[1]).distance_to(foe) < Vector2(b[1]).distance_to(foe))
	# gates first (the way out), then the cells nearest the enemy
	todo.sort_custom(func(a, b) -> bool: return a[0] == "gate" and b[0] != "gate")
	var made: Array = []
	for e in todo:
		var cost := int(Defs.BUILDINGS[e[0]]["cost"])
		if ai._gold() - cost < keep:
			break
		if game.placement_problem(ai.team, e[0], e[1], true) != "":
			continue
		var nb: Building = game.place_building(ai.team, e[0], e[1], [])
		if nb != null:
			made.append(nb)
	p["next_lay"] = game.clock + 3.0
	if made.is_empty():
		return
	var at: Vector2 = (made[0] as Building).center()
	var labs: Array = game.workers(ai.team).filter(func(u: Unit) -> bool:
		return not u.dead and u.order != "build" and not ai._escort.has(u) and not (ai.scout != null and ai.scout.is_scout(u)) and not ai._fled.has(u))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.position.distance_to(at) + (150.0 if a.carrying > 0 else 0.0) < b.position.distance_to(at) + (150.0 if b.carrying > 0 else 0.0))
	var crew: Array = labs.slice(0, 3 if made.size() > 8 else 2)
	ai._assign_wall(crew, made)
	p["laid"] = int(p.get("laid", 0)) + made.size()
	if game.mlog:
		game.mlog.add("%s lays %d wall pieces at its new hall (%d labourers on it)" % [game.mlog.who(ai.team), made.size(), crew.size()])


## Pieces nobody is coming to (a builder killed or pulled off): the nearest free labourer takes each up.
func _tend(p: Dictionary) -> void:
	if game.clock < float(p.get("next_tend", 0.0)):
		return
	p["next_tend"] = game.clock + 2.0
	for e in p["pieces"]:
		var c: Vector2i = e[1]
		var b: Building = game._own_gate_at(ai.team, c) if e[0] == "gate" else game._own_wall_at(ai.team, c)
		if b == null or b.built:
			continue
		var served: bool = game.units.any(func(u: Unit) -> bool:
			return u.team == ai.team and not u.dead and ((u.order == "build" and u.order_target == b) or u.line_rest.has(b)))
		if served:
			continue
		var best: Unit = null
		var bd := INF
		for u in game.workers(ai.team):
			if u.dead or u.order == "build" or ai._escort.has(u) or (ai.scout != null and ai.scout.is_scout(u)):
				continue
			var dd: float = u.position.distance_to(b.center()) + (150.0 if u.carrying > 0 else 0.0)
			if dd < bd:
				bd = dd
				best = u
		if best != null:
			best.give({"o": "build", "e": b})


# ------------------------------------------------------------------ what the rest of the AI asks

## A slot of a walled expansion for a building of this kind (its top-left cell), or (-1, -1).
func slot_for(kind: String) -> Vector2i:
	if not active():
		return Vector2i(-1, -1)
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	if not KINDS_BY_SIZE.has(size) or not (KINDS_BY_SIZE[size] as Array).has(kind):
		return Vector2i(-1, -1)
	for id in plans:
		var p: Dictionary = plans[id]
		if not p.get("ok", false):
			continue
		for s in p["slots"]:
			if s["closed"] or s["size"] != size:
				continue
			var b: Building = s.get("b")
			if b != null and is_instance_valid(b) and not b.dead:
				continue
			if game.placement_problem(ai.team, kind, s["cell"], true) == "":
				return s["cell"]
	return Vector2i(-1, -1)


## Gold set aside for the walls' next pieces (AI._hide_kept hides it from the army, research and horses): the price of
## the palisade and gates not laid yet, up to WALL_KEEP; 0 with a fight at the hall or a bare hall's first Farm to pay.
const WALL_KEEP := 100


func keep() -> int:
	if not active() or plans.is_empty() or _farm_first():
		return 0
	var debt := 0
	for id in plans:
		var p: Dictionary = plans[id]
		if not p.get("ok", false) or ai._unsafe((p["hall"] as Building).center()):
			continue
		for e in p["pieces"]:
			var c: Vector2i = e[1]
			if game.solid[game.idx(c)] != 0 or game.side_ghost_at(ai.team, c) != null:
				continue          # (standing, going up, planned, or a building there)
			debt += int(Defs.BUILDINGS[e[0]]["cost"])
			if debt >= WALL_KEEP:
				return WALL_KEEP
	return debt


## Our land is dry (or a new hall stands bare on fresh land): the first Farm there before any wall piece.
func _farm_first() -> bool:
	return ai._bare_hall() or (ai._dry() and game.econ_count(ai.team, "farm") <= _dry_farms())


## Farms of ours by a hall with dry land (they pay nothing).
func _dry_farms() -> int:
	var n := 0
	for b in ai._mine("farm"):
		var h: Building = game.nearest_hall(b.center(), ai.team)
		if h != null and ai._land(h) < ai.DRY_LAND:
			n += 1
	return n


## The plan of this hall, if any ({} if none).
func plan_of(h: Building) -> Dictionary:
	if h == null:
		return {}
	var p: Dictionary = plans.get(h.get_instance_id(), {})
	return p if p.get("ok", false) else {}


## The share of the plan's ways-in cells closed now (a building, palisade or gate going up or standing).
func closed_share(p: Dictionary) -> float:
	var ex: Array = p["exposed"]
	if ex.is_empty():
		return 1.0
	var n := 0
	for c in ex:
		var v: int = game.solid[game.idx(c)]
		if v == 2 or v == 3 or v == 4:
			n += 1
	return float(n) / float(ex.size())


func holding_plan(p: Dictionary) -> bool:
	return p.get("ok", false) and closed_share(p) < CLOSED_SHARE


## True while this hall's wall is not (mostly) up: its guards stay.
func holding(h: Building) -> bool:
	if not active():
		return false
	var p := plan_of(h)
	return not p.is_empty() and holding_plan(p)


## Cells kept free for the plans (slots not yet built into, palisade and gates not laid): other buildings may not take them.
func reserved() -> Array:
	var out: Array = []
	if not active():
		return out
	for id in plans:
		var p: Dictionary = plans[id]
		if not p.get("ok", false):
			continue
		for s in p["slots"]:
			if s["closed"]:
				continue
			var b: Building = s.get("b")
			if b != null and is_instance_valid(b) and not b.dead:
				continue
			for y in (s["size"] as Vector2i).y:
				for x in (s["size"] as Vector2i).x:
					out.append((s["cell"] as Vector2i) + Vector2i(x, y))
		for e in p["pieces"]:
			out.append(e[1])
		# (the room packed for the hall's Farms and Mill: no Cottage or Barracks on it)
		for e in p.get("econ", []):
			var sz: Vector2i = Defs.BUILDINGS[e[0]]["size"]
			if _building_at(e[1], sz) != null:
				continue
			for y in sz.y:
				for x in sz.x:
					out.append((e[1] as Vector2i) + Vector2i(x, y))
	return out


## Run `f` (a find_spot call) with the plans' kept cells marked as terrain, so nothing else is put on them.
var _held: PackedInt32Array = PackedInt32Array()


func hold() -> void:
	_held.clear()
	for c in reserved():
		var i: int = game.idx(c)
		if game.in_map(c) and game.solid[i] == 0:
			game.solid[i] = 1
			_held.append(i)


func release() -> void:
	for i in _held:
		game.solid[i] = 0
	_held.clear()


## An economy building of a walled hall (Farm, Mill) inside its ring: every cell of its footprint (and the free ring round
## it) in the hall's area, nearest the hall first. (-1, -1) if there's no room inside.
func inside_spot(kind: String, h: Building) -> Vector2i:
	var p := plan_of(h)
	if p.is_empty():
		return Vector2i(-1, -1)
	# (the spot packed for it when the wall was planned, first)
	for e in p.get("econ", []):
		if e[0] == kind and game.placement_problem(ai.team, kind, e[1], true) == "" and game.margin_free(e[1], Defs.BUILDINGS[kind]["size"]):
			return e[1]
	var inside: Dictionary = p["inside"]
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hc: Vector2 = h.center() / Defs.TILE
	var best := Vector2i(-1, -1)
	var bd := INF
	hold()
	for c in inside:
		var tl: Vector2i = c
		var mid := Vector2(tl) + Vector2(size) * 0.5
		var d := mid.distance_to(hc)
		if d >= bd or d > float(Defs.ECON_RANGE) - 0.5 or d < 4.0:
			continue
		var ok := true
		for y in range(-1, size.y + 1):
			for x in range(-1, size.x + 1):
				if not inside.has(tl + Vector2i(x, y)):
					ok = false
					break
			if not ok:
				break
		if not ok or not game.margin_free(tl, size) or game.placement_problem(ai.team, kind, tl, true) != "":
			continue
		bd = d
		best = tl
	release()
	return best


# ------------------------------------------------------------------ the plan

## Ground an army walks (open, crop rows) on the bare map plus what stands now.
func _walk(c: Vector2i) -> bool:
	if not game.in_map(c):
		return false
	var i: int = game.idx(c)
	var v: int = game.solid[i]
	return (v == 0 or v == 5) and game.cliff[i] == 0


## The enemy walks open ground and its own side's gates.
func _foe_walk(c: Vector2i) -> bool:
	if not game.in_map(c):
		return false
	var i: int = game.idx(c)
	var v: int = game.solid[i]
	if game.cliff[i] != 0:
		return false
	if v == 0 or v == 5:
		return true
	return v == 3 and game.hostile(int(game.gate_team.get(i, ai.team)), ai.team)


func _near_ramp(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if game.in_map(n) and game.ramp[game.idx(n)] == 1:
				return true
	return false


const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Every cell an enemy reaches from its main by land (4 ways), the whole map. {} when no enemy start is known.
func _foe_reach() -> Dictionary:
	var seen := {}
	var q: Array = []
	for o in game.n_players():
		if not game.hostile(o, ai.team) or game.starts.size() <= o:
			continue
		var s: Vector2i = game.starts[o]
		for y in range(s.y - 4, s.y + 9):
			for x in range(s.x - 4, s.x + 10):
				var c := Vector2i(x, y)
				if not seen.has(c) and _foe_walk(c):
					seen[c] = true
					q.append(c)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if not seen.has(n) and _foe_walk(n):
				seen[n] = true
				q.append(n)
	return seen


## The hall's area at radius r: the ground walked to from round the hall (4 ways) within r tiles of its middle, no ramp
## nor the cells beside one, not nearer another hall of ours.
func _inside(cell: Vector2i, hsize: Vector2i, r: float, others: Array) -> Dictionary:
	var hc := Vector2(cell) + Vector2(hsize) * 0.5
	var inside := {}
	var q: Array = []
	var ok := func(c: Vector2i) -> bool:
		if not _walk(c) or game.ramp[game.idx(c)] == 1 or _near_ramp(c):
			return false
		var cc := Vector2(c) + Vector2(0.5, 0.5)
		var d := cc.distance_to(hc)
		if d >= r:
			return false
		for o in others:
			if cc.distance_to(o) < d:
				return false
		return true
	for y in range(cell.y - 1, cell.y + hsize.y + 1):
		for x in range(cell.x - 1, cell.x + hsize.x + 1):
			var c := Vector2i(x, y)
			if Rect2i(cell, hsize).has_point(c):
				continue
			if not inside.has(c) and ok.call(c):
				inside[c] = true
				q.append(c)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if not inside.has(n) and not Rect2i(cell, hsize).has_point(n) and ok.call(n):
				inside[n] = true
				q.append(n)
	return inside


## The ring's cells an enemy walks to without crossing the area: a flood inside a box round the hall from the box's
## edge cells the enemy reaches (foe), over walkable ground outside the area.
func _exposed(cell: Vector2i, hsize: Vector2i, inside: Dictionary, foe: Dictionary) -> Array:
	var box := Rect2i(cell - Vector2i(R_MAX + 4, R_MAX + 4), hsize + Vector2i(2 * R_MAX + 8, 2 * R_MAX + 8))
	var seen := {}
	var q: Array = []
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var edge := y == box.position.y or y == box.end.y - 1 or x == box.position.x or x == box.end.x - 1
			var c := Vector2i(x, y)
			if edge and foe.has(c) and not inside.has(c):
				seen[c] = true
				q.append(c)
	# (an enemy start inside the box: its own cells seed too)
	for c in foe:
		if box.has_point(c) and not seen.has(c) and not inside.has(c) and _is_foe_home(c):
			seen[c] = true
			q.append(c)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if seen.has(n) or inside.has(n) or not box.has_point(n) or not _foe_walk(n):
				continue
			seen[n] = true
			q.append(n)
	var out: Array = []
	for c in seen:
		for d in DIRS4:
			if inside.has(c + d):
				out.append(c)
				break
	return out


func _is_foe_home(c: Vector2i) -> bool:
	for o in game.n_players():
		if game.hostile(o, ai.team) and game.starts.size() > o and Vector2(c).distance_to(Vector2(game.starts[o])) < 8.0:
			return true
	return false


func _wall_ok(c: Vector2i) -> bool:
	return game.in_map(c) and game.solid[game.idx(c)] == 0 and game.ramp[game.idx(c)] == 0 and game.placement_problem(ai.team, "wall", c, true) == ""


## The wall plan for a hall at `cell` (a Building `h` if laid): {ok, hall, r, inside, exposed, slots, pieces, foe, built_t}.
func plan_for(cell: Vector2i, h: Building = null) -> Dictionary:
	var hsize: Vector2i = Defs.BUILDINGS["town_hall"]["size"]
	var hc := Vector2(cell) + Vector2(hsize) * 0.5
	var others: Array = []
	for o in game.halls_of(ai.team, false):
		if o != h and o.cell != cell:
			others.append(o.center() / Defs.TILE)
	var foe := _foe_reach()
	var best := {}
	var best_score := INF
	for r in range(R_MIN, R_MAX + 1):
		var inside := _inside(cell, hsize, float(r), others)
		var area := 0
		for c in inside:
			if game.solid[game.idx(c)] == 0:
				area += 1
		if area < AREA_MIN and r < R_MAX:
			continue
		if foe.is_empty():
			continue
		var ex := _exposed(cell, hsize, inside, foe)
		var bad := false
		for c in ex:
			if not _wall_ok(c):
				bad = true
				break
		if bad:
			continue
		# (the hall's two Farms and its Mill must fit inside: else its workers walk out of the wall to them)
		var econ := _pack(cell, hsize, inside)
		var score := float(ex.size()) - float(area) / 150.0 + float(ECON_KINDS.size() - econ.size()) * 1000.0
		if score < best_score:
			best_score = score
			best = {"r": r, "inside": inside, "exposed": ex, "area": area, "econ": econ}
	if best.is_empty():
		return {"ok": false}
	var ex: Array = best["exposed"]
	var p := {"ok": true, "hall": h, "cell": cell, "r": best["r"], "inside": best["inside"], "exposed": ex, "slots": [], "pieces": [],
		"built_t": -1.0, "area": best["area"], "econ": best["econ"]}
	var foe_at := Vector2.ZERO
	var nf := 0
	for o in game.n_players():
		if game.hostile(o, ai.team) and game.starts.size() > o:
			foe_at += Vector2(game.starts[o])
			nf += 1
	p["foe"] = foe_at / maxf(1.0, float(nf))
	if ex.is_empty():
		return p          # (nothing to close: a pocket only our own walls lead to)
	var ex_set := {}
	for c in ex:
		ex_set[c] = true
	# the gate: the ways-in cell nearest our main by land (and the next one along, if it touches)
	var gates: Array = _gate_cells(ex, ex_set, cell, hsize)
	var gate_set := {}
	for c in gates:
		gate_set[c] = true
	# building slots over the rest
	var covered := {}
	var used := {}
	var hall_zone := Rect2i(cell - Vector2i(1, 1), hsize + Vector2i(2, 2))
	var counts := {"barracks": 0, "church": 0, "cottage": 0}
	while true:
		var pick := {}
		var pick_score := -INF
		for sz_kind in SLOT_SIZES:
			var sz: Vector2i = sz_kind[0]
			var kind: String = sz_kind[1]
			if int(counts[kind]) >= int(SLOT_MAX[kind]):
				continue
			if kind == "church" and not ai._mine("church").is_empty():
				continue
			var tried := {}
			for e in ex:
				if covered.has(e) or gate_set.has(e):
					continue
				for oy in sz.y:
					for ox in sz.x:
						var tl: Vector2i = e - Vector2i(ox, oy)
						if tried.has(tl):
							continue
						tried[tl] = true
						var cov := 0
						var ins := 0
						var fine := true
						for y in sz.y:
							for x in sz.x:
								var c := tl + Vector2i(x, y)
								if used.has(c) or gate_set.has(c) or hall_zone.has_point(c) or not game.is_free(c):
									fine = false
									break
								# (next to a gate: the way through stays clear)
								for d in DIRS4:
									if gate_set.has(c + d):
										fine = false
								if ex_set.has(c) and not covered.has(c):
									cov += 1
								elif p["inside"].has(c):
									ins += 1
							if not fine:
								break
						if not fine or cov < int(SLOT_MIN_COVER[kind]) or ins > sz.x * sz.y / 2:
							continue
						if game.placement_problem(ai.team, kind, tl, true) != "":
							continue
						var sc := float(cov) * 10.0 - float(ins) - float(sz.x * sz.y) * 0.5
						if sc > pick_score:
							pick_score = sc
							pick = {"cell": tl, "size": sz, "kind": kind, "cov": cov}
		if pick.is_empty():
			break
		var cover: Array = []
		var sz2: Vector2i = pick["size"]
		for y in sz2.y:
			for x in sz2.x:
				var c: Vector2i = (pick["cell"] as Vector2i) + Vector2i(x, y)
				used[c] = true
				if ex_set.has(c) and not covered.has(c):
					covered[c] = true
					cover.append(c)
		# (the footprint's ring stays free of other slots: a gap between two buildings is palisade, not a stuck man)
		counts[pick["kind"]] = int(counts[pick["kind"]]) + 1
		p["slots"].append({"cell": pick["cell"], "size": pick["size"], "cover": cover, "closed": false, "b": null})
	for c in gates:
		p["pieces"].append(["gate", c])
	for c in ex:
		if not covered.has(c) and not gate_set.has(c):
			p["pieces"].append(["wall", c])
	return p


const ECON_KINDS := ["farm", "farm", "powder_mill"]


## Room inside for the hall's economy: a spot for each of ECON_KINDS (its footprint and the free ring round it inside,
## within the hall's economy reach, off the ramps; footprints apart, rings may touch), nearest the hall first. [[kind, cell]...]
func _pack(cell: Vector2i, hsize: Vector2i, inside: Dictionary) -> Array:
	var hc := Vector2(cell) + Vector2(hsize) * 0.5
	var foot := {}          # cells under the hall or a packed footprint
	for y in hsize.y:
		for x in hsize.x:
			foot[cell + Vector2i(x, y)] = true
	var ring := {}          # cells beside them (no footprint may take one)
	for y in range(cell.y - 1, cell.y + hsize.y + 1):
		for x in range(cell.x - 1, cell.x + hsize.x + 1):
			ring[Vector2i(x, y)] = true
	var cells: Array = inside.keys()
	var out: Array = []
	for kind in ECON_KINDS:
		var size: Vector2i = Defs.BUILDINGS[kind]["size"]
		var best := Vector2i(-1, -1)
		var half := Vector2(size) * 0.5
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) + half).distance_squared_to(hc) < (Vector2(b) + half).distance_squared_to(hc))
		for c in cells:
			var tl: Vector2i = c
			if (Vector2(tl) + half).distance_to(hc) > float(Defs.ECON_RANGE) - 0.5:
				break
			var ok := true
			for y in range(-1, size.y + 1):
				for x in range(-1, size.x + 1):
					var q := tl + Vector2i(x, y)
					var on_foot := x >= 0 and y >= 0 and x < size.x and y < size.y
					if not inside.has(q) or foot.has(q):
						ok = false
					elif on_foot and (ring.has(q) or not game.is_free(q) or game._near_ramp(q)):
						ok = false
					if not ok:
						break
				if not ok:
					break
			if ok:
				best = tl
				break
		if best.x < 0:
			continue
		out.append([kind, best])
		for y in range(-1, size.y + 1):
			for x in range(-1, size.x + 1):
				var q := best + Vector2i(x, y)
				if x >= 0 and y >= 0 and x < size.x and y < size.y:
					foot[q] = true
				else:
					ring[q] = true
	return out


## GATE_W touching ways-in cells nearest our main by land.
func _gate_cells(ex: Array, ex_set: Dictionary, cell: Vector2i, hsize: Vector2i) -> Array:
	var main_at := Vector2(game.starts[ai.team]) + Vector2(2.5, 2.0)
	var d := _walk_dist(Vector2i(main_at))
	var best := Vector2i(-1, -1)
	var bd := INF
	for c in ex:
		var v: float = float(d.get(c, INF))
		if v == INF:
			v = 100000.0 + Vector2(c).distance_to(main_at)
		if v < bd:
			bd = v
			best = c
	var out: Array = [best]
	var nb := Vector2i(-1, -1)
	var nd := INF
	for dd in DIRS4:
		var n: Vector2i = best + dd
		if ex_set.has(n) and float(d.get(n, 1e9)) < nd:
			nd = float(d.get(n, 1e9))
			nb = n
	if GATE_W >= 2 and nb.x >= 0:
		out.append(nb)
	return out


## Steps by land from round `from` (our main) over walkable ground and our own gates.
func _walk_dist(from: Vector2i) -> Dictionary:
	var d := {}
	var q: Array = []
	for y in range(from.y - 5, from.y + 6):
		for x in range(from.x - 5, from.x + 6):
			var c := Vector2i(x, y)
			if _own_walk(c):
				d[c] = 0.0
				q.append(c)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for dd in DIRS4:
			var n: Vector2i = c + dd
			if not d.has(n) and _own_walk(n):
				d[n] = float(d[c]) + 1.0
				q.append(n)
	return d


func _own_walk(c: Vector2i) -> bool:
	if not game.in_map(c):
		return false
	var i: int = game.idx(c)
	var v: int = game.solid[i]
	if game.cliff[i] != 0:
		return false
	return v == 0 or v == 5 or (v == 3 and not game.hostile(int(game.gate_team.get(i, ai.team)), ai.team))
