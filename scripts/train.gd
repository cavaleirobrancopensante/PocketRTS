class_name Train
extends Entity
## A train on the Clockwork's rails (docs/clockwork_rework_plan.md, phase 2). Not selectable and not ordered one
## by one: an Ore Train shuttles between the Ore Drills and the Clocktower by itself; a Troop Train is sent for
## by the RIDE order (Game.ride_order). It runs only over finished Line segments, at the pressure's speed (a
## starved or cut Line stops it), keeps `Defs.RAIL.headway` cells from the train in front on its own track
## (that spacing is the rail's throughput cap), and is a visible target: enemies shoot it before the pipes.
## Managed and ticked by Rails (scripts/rails.gd); drawn here, from the sprites under assets/units/ when they
## exist (tools/import_line_art.py) and from code when they do not.

const T := Defs.TILE

var tid := 0
var tkind := "ore"
var net: LineNetwork
var rails: Rails
var home: Building = null
var state := "idle"           # idle, to_drill, loading, to_hall, unloading, to_pickup, boarding, carrying, returning, stranded
var cargo := 0.0
var drill: Building = null
var riders: Array = []
var path: Array = []          # cells to run, the first is where it stands
var idx := 0                  # the cell it is on (an index of path)
var frac := 0.0               # 0..1 of the way to the next cell
var cell := Vector2i.ZERO
var dir := Vector2i.ZERO      # the way it is going now (ZERO: standing)
var last_dir := Vector2i(1, 0)
var heading := Vector2i.ZERO  # the way it last ran (ZERO: not yet): it does not turn straight back (Rails.route), only at a dead end
var trail: Array = []         # where the locomotive has been (world points, oldest first): the wagons follow it
var _turn_t := 0.0
var turns := 0                # times it has backed out of a dead end (a stat for the tests and the match log)
var _look_dir := Vector2i(1, 0)
var speed_now := 0.0          # cells a second this moment (HUD, tests)
var timer := 0.0
var wait_t := 0.0
var anim_t := 0.0
var dest := Vector2i(-1, -1)  # a troop train's destination cell
var pick := Vector2i(-1, -1)  # ... and where it takes the men aboard
var group: Array = []         # the soldiers told to come aboard
var _goal: Array = []
var _prev_state := "idle"
var _retry := 0.0
var _target_pos := Vector2.ZERO    # online guest: where the host last had it
var _view_state := ""


func setup(n: LineNetwork, id: int, k: String, t: int, c: Vector2i) -> void:
	net = n
	rails = n.rails
	game = n.game
	tid = id
	tkind = k
	team = t
	kind = "train_" + k
	var d: Dictionary = Defs.TRAINS[k]
	max_hp = float(d["hp"])
	hp = max_hp
	armor = float(d["armor"])
	sight = 5
	cell = c
	path = [c]
	position = game.cell_center(c)
	_target_pos = position
	z_index = 6
	set_process(false)
	set_physics_process(false)


func rect() -> Rect2:
	return Rect2(global_position + Vector2(-30, -34), Vector2(60, 44))


func center() -> Vector2:
	return global_position


func untouchable() -> bool:
	return false


## The seat count of a Troop Train.
func seats() -> int:
	return int(Defs.TRAINS[tkind].get("riders", 0))


# ------------------------------------------------------------------ the tick

func step(delta: float) -> void:
	anim_t += delta
	if game.puppet:
		position = position.lerp(_target_pos, minf(1.0, delta * 12.0))
		_trail_push(position)
		queue_redraw()
		return
	speed_now = 0.0
	dir = Vector2i.ZERO if state not in ["to_drill", "to_hall", "to_pickup", "carrying", "returning"] else dir
	match state:
		"idle":
			_idle(delta)
		"to_drill", "to_hall", "to_pickup", "carrying", "returning":
			_move(delta)
		"loading":
			_loading(delta)
		"unloading":
			_unloading(delta)
		"boarding":
			_boarding(delta)
		"stranded":
			_retry -= delta
			if _retry <= 0.0:
				_retry = float(Defs.RAIL["stranded_retry"])
				_replan()
	for r in riders:
		if is_instance_valid(r):
			r.position = position
	if Defs.cw_roster and not riders.is_empty():
		CwUnits.train_fire(self, delta)       # Rail Riflemen shoot from the carriage
	queue_redraw()


func _hall() -> Building:
	if home != null and is_instance_valid(home) and home.built and not home.dead:
		return home
	home = rails._hall(team, cell)
	return home


## Run to one of `goals` over the Line; stranded (and trying again) when there is no way.
func _go(goals: Array, moving: String) -> void:
	_goal = goals
	var p := rails.route(team, cell, _free_goals(goals), heading)
	if p.is_empty():
		_prev_state = moving
		state = "stranded"
		_retry = float(Defs.RAIL["stranded_retry"])
		path = [cell]
		idx = 0
		frac = 0.0
		return
	path = p
	idx = 0
	frac = 0.0
	state = moving
	if p.size() == 1:
		_arrive()


## Goal cells without the ones where another train of the team stands working (when others remain): a Drill or the
## hall has a whole ring of cells to stop at.
func _free_goals(goals: Array) -> Array:
	if goals.size() < 2:
		return goals
	var out: Array = []
	for g in goals:
		var taken := false
		for o in rails.trains:
			if o != self and not o.dead and o.team == team and o.cell == g and o.state in ["loading", "unloading", "boarding"]:
				taken = true
				break
		if not taken:
			out.append(g)
	return out if not out.is_empty() else goals


func _replan() -> void:
	var moving := _prev_state
	if moving == "to_drill" and (drill == null or not is_instance_valid(drill) or drill.dead):
		state = "idle"
		return
	if moving in ["to_hall", "returning"]:
		var h := _hall()
		if h == null:
			return
		_goal = rails.access_cells(team, h)
	elif moving == "to_drill":
		_goal = rails.access_cells(team, drill)
	elif moving == "to_pickup":
		_goal = [pick]
	elif moving == "carrying":
		_goal = [dest]
	_go(_goal, moving)


func _idle(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = 0.6
	if tkind == "troop":
		return                 # waits at the Clocktower until it is sent for
	if cargo > 0.0:
		var h := _hall()
		if h != null:
			_go(rails.access_cells(team, h), "to_hall")
		return
	var b := _pick_drill()
	if b != null:
		drill = b
		_go(rails.access_cells(team, b), "to_drill")


## The Ore Drill with the most waiting ore that no other train is already coming for.
func _pick_drill() -> Building:
	var best: Building = null
	var bs := -INF
	for b in game.buildings:
		if b.team != team or b.kind != "ore_drill" or not b.built or b.dead:
			continue
		var acc := rails.access_cells(team, b)
		if acc.is_empty():
			continue
		var claims := 0
		for o in rails.trains:
			if o != self and o.tkind == "ore" and o.drill == b and o.state in ["to_drill", "loading"]:
				claims += 1
		var sc: float = b.stock - claims * float(Defs.TRAINS["ore"]["cargo"]) * 0.9 - Vector2(cell - acc[0]).length() * 0.4
		if sc > bs and not rails.route(team, cell, acc, heading).is_empty():
			bs = sc
			best = b
	return best


func _move(delta: float) -> void:
	if idx >= path.size() - 1:
		_arrive()
		return
	var here: PipeSeg = net.segs.get(path[idx])
	var nxt: Vector2i = path[idx + 1]
	var s: PipeSeg = net.segs.get(nxt)
	if s == null or s.dead or not s.built or s.team != team:
		# the Line is cut ahead: find another way round, or wait for the repair
		_goal = _goal if not _goal.is_empty() else [path[path.size() - 1]]
		_prev_state = state
		_go(_goal, state)
		return
	var d: Vector2i = nxt - path[idx]
	if frac <= 0.0 and heading != Vector2i.ZERO and d == -heading:
		# a dead end: stand a moment, then back out (the wagons swing in behind)
		dir = Vector2i.ZERO
		_turn_t += delta
		if _turn_t < float(Defs.RAIL["reverse"]):
			return
		_turn_t = 0.0
		turns += 1
		trail.clear()
	dir = d
	last_dir = d
	heading = d
	if frac <= 0.0 and _blocked(d):
		return
	var mult := 1.0
	if net.enforce:
		mult = Defs.line_speed(here.pressure if here != null else s.pressure)
	var v := float(Defs.TRAINS[tkind]["speed"]) * mult
	if v <= 0.0:
		return
	speed_now = v
	frac += v * delta
	while frac >= 1.0 and idx < path.size() - 1:
		frac -= 1.0
		idx += 1
		cell = path[idx]
		if idx < path.size() - 1:
			var nn: Vector2i = path[idx + 1]
			var s2: PipeSeg = net.segs.get(nn)
			if s2 == null or s2.dead or not s2.built:
				frac = 0.0
				break
			var d2: Vector2i = nn - path[idx]
			if d2 != dir:
				if d2 == -dir:
					frac = 0.0          # (a turn round: the pause and the swing are done on the next tick)
					break
				dir = d2
				last_dir = d2
				heading = d2
				if _blocked(d2):
					frac = 0.0
					break
	if idx >= path.size() - 1:
		frac = 0.0
		cell = path[path.size() - 1]
		_arrive()
	position = _pos_at(float(idx) + frac)
	_trail_push(position)


## Remember where the locomotive was (the wagons are drawn along this trail).
func _trail_push(p: Vector2) -> void:
	if trail.is_empty() or (trail[trail.size() - 1] as Vector2).distance_squared_to(p) >= 2.0:
		trail.append(p)
		if trail.size() > 300:
			trail = trail.slice(60)


## Is the track ahead taken: a train going the same way within `headway` cells, or one standing within `stand_clear`
## (its wagons stand behind it, toward us; a parked idle one: 2)?
func _blocked(d: Vector2i) -> bool:
	var head := int(Defs.RAIL["headway"])
	for o in rails.trains:
		if o == self or o.dead or o.team != team:
			continue
		var clear := 2 if o.state == "idle" else int(Defs.RAIL["stand_clear"])
		for k in range(1, head + 1):
			if idx + k >= path.size():
				break
			var c: Vector2i = path[idx + k]
			if not o.occupies(c):
				continue
			if o.dir == Vector2i.ZERO:
				# a standing train is in ITS lane (the one for the way it faces): trains going the other way pass it
				if k <= clear and (o.heading == d or o.heading == Vector2i.ZERO):
					return true
			elif o.dir == d:
				return true
	return false


func occupies(c: Vector2i) -> bool:
	if c == cell:
		return true
	return frac > 0.0 and idx + 1 < path.size() and c == path[idx + 1]


## Two tracks: a train keeps to the right of the way it goes (Defs.RAIL.lane px off the centre line), so trains
## going opposite ways never share a lane. The shift at path cell i: the right-hand offset of the way in plus the way
## out, which is the corner of the inner/outer lane on a bend, zero at a dead end (where it changes lanes).
static func lane_of(d: Vector2i) -> Vector2:
	return Vector2(-d.y, d.x) * float(Defs.RAIL["lane"])


func _lane_shift(i: int) -> Vector2:
	var d_out := Vector2i.ZERO
	var d_in := Vector2i.ZERO
	if i + 1 < path.size():
		d_out = path[i + 1] - path[i]
	if i > 0:
		d_in = path[i] - path[i - 1]
	elif heading != Vector2i.ZERO:
		d_in = heading
	if d_in == Vector2i.ZERO:
		d_in = d_out
	if d_out == Vector2i.ZERO:
		d_out = d_in
	if d_in == Vector2i.ZERO:
		return Vector2.ZERO
	if d_in == d_out:
		return lane_of(d_in)
	return lane_of(d_in) + lane_of(d_out)


## A point `s` cells along the path (before the start: back along the way it came), in the train's lane.
func _pos_at(s: float) -> Vector2:
	if path.is_empty():
		return position
	if s <= 0.0:
		return game.cell_center(path[0]) + Vector2(last_dir) * s * T + _lane_shift(0)
	var i := int(floor(s))
	if i >= path.size() - 1:
		return game.cell_center(path[path.size() - 1]) + _lane_shift(path.size() - 1)
	return (game.cell_center(path[i]) + _lane_shift(i)).lerp(game.cell_center(path[i + 1]) + _lane_shift(i + 1), s - i)


func _arrive() -> void:
	dir = Vector2i.ZERO
	match state:
		"to_drill":
			state = "loading"
			timer = 0.0
			wait_t = 0.0
		"to_hall":
			state = "unloading"
			timer = 0.0
		"to_pickup":
			state = "boarding"
			timer = 0.0
		"carrying":
			state = "unloading"
			timer = 0.0
		"returning":
			state = "idle"
			timer = 0.0


func _loading(delta: float) -> void:
	if drill == null or not is_instance_valid(drill) or drill.dead:
		state = "idle"
		return
	timer += delta
	if timer < float(Defs.RAIL["load"]):
		return
	var cap := float(Defs.TRAINS["ore"]["cargo"])
	if drill.stock < minf(cap, float(Defs.RAIL["wait_stock"])) and wait_t < float(Defs.RAIL["wait_max"]):
		wait_t += delta                 # the ore is still coming up
		return
	var take := minf(cap, drill.stock)
	if take < 1.0 and wait_t >= float(Defs.RAIL["wait_max"]):
		state = "idle"                  # (nothing to carry: look for another drill)
		timer = 0.0
		return
	if drill.stock < cap and wait_t < float(Defs.RAIL["wait_max"]) * 0.5:
		wait_t += delta                 # wait a little longer for a fuller load
		return
	drill.stock -= take
	cargo = take
	var h := _hall()
	if h == null:
		state = "idle"
		return
	_go(rails.access_cells(team, h), "to_hall")


func _unloading(delta: float) -> void:
	timer += delta
	if tkind == "troop":
		if timer < float(Defs.RAIL["unload"]):
			return
		drop_riders(true)
		var h := _hall()
		if h != null:
			_go(rails.access_cells(team, h), "returning")
		else:
			state = "idle"
		return
	if timer < float(Defs.RAIL["unload"]):
		return
	if cargo > 0.0:
		game.add_gold_f(team, cargo)
		rails.delivered[team] = float(rails.delivered.get(team, 0.0)) + cargo
		if team == game.human and not game.demo:
			game.float_text(position + Vector2(0, -34), "+%d" % int(round(cargo)), Color(0.95, 0.85, 0.4))
			Sfx.play_any(["done"], position)
		cargo = 0.0
	state = "idle"
	timer = 0.0


# ------------------------------------------------------------------ troops

## Sent for by Game.ride_order: take `men` aboard at `pickup_cell` and set them down at `to_cell`.
func send_for(men: Array, pickup_cell: Vector2i, to_cell: Vector2i) -> void:
	group = men.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	pick = pickup_cell
	dest = to_cell
	if not riders.is_empty():
		drop_riders(true)
	_go([pickup_cell], "to_pickup")


func _boarding(delta: float) -> void:
	timer += delta
	group = group.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.aboard == null and not u.off_field)
	var here := game.cell_center(cell)
	for u in group.duplicate():
		if riders.size() >= seats():
			break
		if u.position.distance_to(here) < 46.0:
			_board(u)
			group.erase(u)
	if (group.is_empty() or riders.size() >= seats() or timer >= float(Defs.RAIL["board_max"])) and not riders.is_empty():
		group = []
		_go([dest], "carrying")
	elif group.is_empty() and riders.is_empty():
		var h := _hall()
		if h != null:
			_go(rails.access_cells(team, h), "returning")
		else:
			state = "idle"
	elif timer >= float(Defs.RAIL["board_max"]) and riders.is_empty():
		group = []
		var h2 := _hall()
		if h2 != null:
			_go(rails.access_cells(team, h2), "returning")


func _board(u: Unit) -> void:
	u.cmd_stop()
	u.release_horses()
	u.velocity = Vector2.ZERO
	u.off_field = true
	u.visible = false
	u.selected = false
	u.target = null
	u.phase = ""
	game.selection.erase(u)
	u.position = position
	u.set_meta("train", self)
	riders.append(u)
	if team == game.human:
		Sfx.play_any(["ui/click", "click"], position)


## Let the riders off around the train (arrived, or the train was lost: hurt by `hurt` of their health).
func drop_riders(arrive: bool, hurt := 0.0) -> void:
	var n := riders.size()
	for i in n:
		var u: Unit = riders[i]
		if not is_instance_valid(u) or u.dead:
			continue
		u.remove_meta("train")
		u.off_field = false
		u.visible = true
		var a := TAU * float(i) / maxf(1.0, float(n))
		u.position = position + Vector2(cos(a), sin(a) * 0.6) * (22.0 + 6.0 * (i % 3))
		if hurt > 0.0:
			u.hp = maxf(1.0, u.hp - u.max_hp * hurt)
		u.velocity = Vector2.ZERO
	riders = []


func die() -> void:
	if dead:
		return
	dead = true
	var fx := game.spawn_effect("dust", global_position, 1.0)
	if fx:
		fx.scale = Vector2(0.9, 0.9)
	Sfx.play_any(["combat/gear_hit", "gear_hit"], global_position)
	drop_riders(false, 0.3)         # (they climb out of the wreck, hurt)
	if game.mlog and team == game.human:
		game.mlog.add("%s lost a %s" % [game.mlog.who(team), Defs.TRAINS[tkind]["name"]])
	rails.remove(self)
	queue_free()


# ------------------------------------------------------------------ save and online

func save_row() -> Array:
	var rs: Array = []
	for u in riders:
		if is_instance_valid(u) and not u.dead:
			rs.append({"k": u.kind, "hp": u.hp, "mode": u.mode, "kills": u.kills, "kit": u.get_kit(), "pw": u.powder})
	return [tid, tkind, team, cell.x, cell.y, snappedf(hp, 0.1), snappedf(cargo, 0.1), rs, dest.x, dest.y]


func load_row(r: Array) -> void:
	hp = float(r[5])
	cargo = float(r[6])
	if r.size() > 9:
		dest = Vector2i(int(r[8]), int(r[9]))
	for pd in r[7]:
		var k := String(pd.get("k", ""))
		if not Defs.UNITS.has(k):
			continue
		var u := game._add_unit(k, team, position)
		if Defs.ARMOURED.has(k) and pd.get("kit") is Dictionary:
			u.set_kit(pd["kit"])
		u.hp = minf(float(pd.get("hp", u.max_hp)), u.max_hp)
		u.mode = String(pd.get("mode", ""))
		u.kills = int(pd.get("kills", 0))
		u.powder = minf(float(pd.get("pw", u.powder)), u._pmax)
		_board(u)
	if not riders.is_empty() and dest.x >= 0:
		_go([dest], "carrying")


func view_row() -> Array:
	return [tid, tkind, team, snappedf(position.x, 0.1), snappedf(position.y, 0.1), snappedf(hp, 0.1), state, snappedf(cargo, 0.1), last_dir.x, last_dir.y, riders.size()]


func load_view_row(r: Array) -> void:
	_target_pos = Vector2(float(r[3]), float(r[4]))
	hp = float(r[5])
	state = String(r[6])
	cargo = float(r[7])
	last_dir = Vector2i(int(r[8]), int(r[9]))
	speed_now = 1.0 if state in ["to_drill", "to_hall", "to_pickup", "carrying", "returning"] else 0.0
	_view_state = state


# ------------------------------------------------------------------ drawing

## Sprite lengths along the track in sprite pixels, per view ("h": seen from the side, "v": end on, where only the
## depth shows) and the part of the buffers that overlaps at a coupling.
const LEN := {"loco": {"h": 52.0, "v": 30.0}, "car": {"h": 45.0, "v": 19.0}}
const HOOK := {"h": 4.0, "v": 1.0}
const FOOT := 4.0              # where the wheels stand: px below the cell centre (the rail deck)


## Distance between the centres of two coupled vehicles (world px), `front` in front of `back`.
static func coupling(front: String, back: String, horiz: bool) -> float:
	var v := "h" if horiz else "v"
	return ((float(LEN[front][v]) + float(LEN[back][v])) * 0.5 - float(HOOK[v])) * float(Defs.LINE["scale"])


## The parts of the train, locomotive first: [offset from the train's position, the way it faces, "loco" / "car"].
## The wagons are strung along the locomotive's trail at the coupling distance (a rigid link: the straight-line
## distance holds on bends too, so they follow the track round corners and the hooks stay together).
func layout() -> Array:
	var out: Array = [[Vector2.ZERO, last_dir, "loco"]]
	var cars := int(Defs.TRAINS[tkind]["cars"])
	if cars <= 0:
		return out
	var pts: Array = [position]
	for i in range(trail.size() - 1, -1, -1):
		if (trail[i] as Vector2).distance_squared_to(pts[pts.size() - 1]) > 0.04:
			pts.append(trail[i])
	var back := -Vector2(last_dir)
	if pts.size() >= 2:
		var tail: Vector2 = pts[pts.size() - 1] - pts[pts.size() - 2]
		if tail.length() > 0.01:
			back = tail.normalized()
	pts.append(pts[pts.size() - 1] + back * 600.0)
	var prev_pt: Vector2 = position
	var prev_kind := "loco"
	var j := 0
	var q: Vector2 = position
	for n in cars:
		var sd: Vector2 = pts[j + 1] - pts[j]
		var dd := coupling(prev_kind, "car", absf(sd.x) >= absf(sd.y))
		var placed := false
		while j < pts.size() - 1:
			var b: Vector2 = pts[j + 1]
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
		var ch := prev_pt - q
		var cd := Vector2i(int(signf(ch.x)), 0) if absf(ch.x) >= absf(ch.y) else Vector2i(0, int(signf(ch.y)))
		if cd == Vector2i.ZERO:
			cd = last_dir
		out.append([q - position, cd, "car"])
		prev_pt = q
		prev_kind = "car"
	return out


func _draw() -> void:
	if dead:
		return
	var moving := speed_now > 0.05
	var parts := layout()
	var order: Array = parts.duplicate()
	order.sort_custom(func(a, b) -> bool: return a[0].y < b[0].y)
	for p in order:
		if p[2] == "loco":
			_draw_loco(p[0], p[1], moving)
		else:
			_draw_car(p[0], p[1])
	# the couplings: a drawn link between the buffers, over the sprites so it reads at a glance
	for i in range(parts.size() - 1):
		_draw_link(parts[i][0], parts[i + 1][0], parts[i][1])
	var k := float(Defs.LINE["scale"])
	draw_health(-34.0 * k, 36.0 * k)
	if flash > 0.0:
		flash = maxf(0.0, flash - 0.05)


## The coupling between two vehicles (code art, docs/art_style_inconsistency.md): two buffers' worth of steel bar with a
## pin ring, at buffer height, along the line from one centre to the next.
func _draw_link(a: Vector2, b: Vector2, d: Vector2i) -> void:
	var k := float(Defs.LINE["scale"])
	var diff := b - a
	var horiz := absf(diff.x) >= absf(diff.y)
	if not horiz:
		return                       # end on the hooks are hidden behind the vehicle in front
	var mid := (a + b) * 0.5 + Vector2(0, FOOT - 5.0 * k)
	var u := diff.normalized()
	var perp := Vector2(-u.y, u.x)
	var half := 4.0 * k
	draw_line(mid - u * half, mid + u * half, Color(0.08, 0.07, 0.07), 3.6)
	draw_line(mid - u * half, mid + u * half, Color(0.72, 0.74, 0.78), 2.0)
	draw_circle(mid, 2.6, Color(0.08, 0.07, 0.07))
	draw_circle(mid, 1.5, Color(0.95, 0.75, 0.25))
	draw_line(mid + perp * 3.0 - u * half, mid - perp * 3.0 - u * half, Color(0.15, 0.15, 0.17), 1.5)
	draw_line(mid + perp * 3.0 + u * half, mid - perp * 3.0 + u * half, Color(0.15, 0.15, 0.17), 1.5)


func _view_of(d: Vector2i) -> String:
	if d.y > 0:
		return "s"
	if d.y < 0:
		return "n"
	return "e"


func _draw_loco(off: Vector2, d: Vector2i, moving: bool) -> void:
	var k := float(Defs.LINE["scale"])
	var v := _view_of(d)
	var flip := d.x < 0
	var tex: Texture2D = LineArt.tex("units/ore_locomotive/%s_%s.png" % ["run" if moving else "idle", v])
	if tex == null:
		_code_loco(off, v)
		return
	var frames := 4 if moving else 1
	var fw := tex.get_width() / frames
	var fh := tex.get_height()
	var f := int(anim_t * 8.0) % frames if moving else 0
	var base := Vector2(0, FOOT) + off
	draw_set_transform(base, 0.0, Vector2(-k if flip else k, k))
	draw_texture_rect_region(tex, Rect2(Vector2(-fw * 0.5, -fh + 2), Vector2(fw, fh)), Rect2(f * fw, 0, fw, fh), Color.WHITE if flash <= 0.0 else Color(1.6, 1.6, 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_car(off: Vector2, d: Vector2i) -> void:
	var k := float(Defs.LINE["scale"])
	var v := _view_of(d)
	var flip := d.x < 0
	var rel := "units/troop_car/idle_%s.png" % v if tkind == "troop" else "units/ore_car/%s_%s.png" % ["full" if cargo > 0.0 else "empty", v]
	var tex: Texture2D = LineArt.tex(rel)
	if tex == null:
		_code_car(off, v)
		return
	var w := tex.get_width()
	var h := tex.get_height()
	draw_set_transform(Vector2(0, FOOT) + off, 0.0, Vector2(-k if flip else k, k))
	draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -h + 2), Vector2(w, h)), false, Color.WHITE if flash <= 0.0 else Color(1.6, 1.6, 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# code-drawn stand-ins (docs/art_style_inconsistency.md)

func _code_loco(off: Vector2, v: String) -> void:
	var k := float(Defs.LINE["scale"])
	draw_set_transform(Vector2(0, FOOT) + off, 0.0, Vector2(k, k))
	var c := Vector2.ZERO
	var body := Color(0.65, 0.16, 0.12)
	var w := 46.0 if v == "e" else 24.0
	var h := 22.0 if v == "e" else 28.0
	draw_rect(Rect2(c - Vector2(w * 0.5, h), Vector2(w, h)), body)
	draw_rect(Rect2(c - Vector2(w * 0.5, h), Vector2(w, 5)), Color(0.15, 0.15, 0.17))
	draw_rect(Rect2(c + Vector2(w * 0.25, -h - 8), Vector2(5, 10)), Color(0.12, 0.12, 0.13))
	draw_rect(Rect2(c - Vector2(w * 0.5, 1), Vector2(w, 3)), Color(0.2, 0.2, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _code_car(off: Vector2, v: String) -> void:
	var k := float(Defs.LINE["scale"])
	draw_set_transform(Vector2(0, FOOT) + off, 0.0, Vector2(k, k))
	var c := Vector2.ZERO
	var w := 40.0 if v == "e" else 20.0
	var h := 14.0 if v == "e" else 17.0
	var col := Color(0.45, 0.2, 0.15) if tkind == "ore" else Color(0.3, 0.3, 0.34)
	draw_rect(Rect2(c - Vector2(w * 0.5, h), Vector2(w, h)), col)
	if tkind == "ore" and cargo > 0.0:
		draw_rect(Rect2(c - Vector2(w * 0.5 - 2, h + 3), Vector2(w - 4, 4)), Color(0.85, 0.55, 0.2))
	draw_rect(Rect2(c - Vector2(w * 0.5, 1), Vector2(w, 3)), Color(0.2, 0.2, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
