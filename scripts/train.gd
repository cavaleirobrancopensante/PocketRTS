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
	return Rect2(global_position - Vector2(14, 12), Vector2(28, 20))


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
	queue_redraw()


func _hall() -> Building:
	if home != null and is_instance_valid(home) and home.built and not home.dead:
		return home
	home = rails._hall(team, cell)
	return home


## Run to one of `goals` over the Line; stranded (and trying again) when there is no way.
func _go(goals: Array, moving: String) -> void:
	_goal = goals
	var p := rails.route(team, cell, goals)
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
		if sc > bs and not rails.route(team, cell, acc).is_empty():
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
	dir = d
	last_dir = d
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
				dir = d2
				last_dir = d2
				if _blocked(d2):
					frac = 0.0
					break
	if idx >= path.size() - 1:
		frac = 0.0
		cell = path[path.size() - 1]
		_arrive()
	position = _pos_at(float(idx) + frac)


## Is the track ahead taken: a train going the same way within `headway` cells, or one standing within 2?
func _blocked(d: Vector2i) -> bool:
	var head := int(Defs.RAIL["headway"])
	for o in rails.trains:
		if o == self or o.dead or o.team != team:
			continue
		for k in range(1, head + 1):
			if idx + k >= path.size():
				break
			var c: Vector2i = path[idx + k]
			if not o.occupies(c):
				continue
			if o.dir == Vector2i.ZERO:
				if k <= 2:
					return true
			elif o.dir == d:
				return true
	return false


func occupies(c: Vector2i) -> bool:
	if c == cell:
		return true
	return frac > 0.0 and idx + 1 < path.size() and c == path[idx + 1]


## A point `s` cells along the path (before the start: back along the way it came).
func _pos_at(s: float) -> Vector2:
	if path.is_empty():
		return position
	if s <= 0.0:
		return game.cell_center(path[0]) + Vector2(last_dir) * s * T
	var i := int(floor(s))
	if i >= path.size() - 1:
		return game.cell_center(path[path.size() - 1])
	return game.cell_center(path[i]).lerp(game.cell_center(path[i + 1]), s - i)


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

func _draw() -> void:
	if dead:
		return
	var moving := speed_now > 0.05
	var d := last_dir
	var cars := int(Defs.TRAINS[tkind]["cars"])
	var s := float(idx) + frac
	var parts: Array = []        # [world offset, kind] back to front
	parts.append([Vector2.ZERO, "loco"])
	for i in cars:
		var gap := 1.5 + 1.4 * float(i)       # (cells behind the locomotive: the art's cars are 45 px, it is 52)
		var back := _pos_at(s - gap) - global_position
		if game.puppet:
			back = -Vector2(d) * gap * T
		parts.append([back, "car"])
	parts.sort_custom(func(a, b) -> bool: return a[0].y < b[0].y)
	for p in parts:
		if p[1] == "loco":
			_draw_loco(p[0], d, moving)
		else:
			_draw_car(p[0], d)
	draw_health(-34.0, 36.0)
	if flash > 0.0:
		flash = maxf(0.0, flash - 0.05)


func _view_of(d: Vector2i) -> String:
	if d.y > 0:
		return "s"
	if d.y < 0:
		return "n"
	return "e"


func _draw_loco(off: Vector2, d: Vector2i, moving: bool) -> void:
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
	var base := Vector2(0, 8) + off
	draw_set_transform(base, 0.0, Vector2(-1 if flip else 1, 1))
	draw_texture_rect_region(tex, Rect2(Vector2(-fw * 0.5, -fh + 2), Vector2(fw, fh)), Rect2(f * fw, 0, fw, fh), Color.WHITE if flash <= 0.0 else Color(1.6, 1.6, 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_car(off: Vector2, d: Vector2i) -> void:
	var v := _view_of(d)
	var flip := d.x < 0
	var rel := "units/troop_car/idle_%s.png" % v if tkind == "troop" else "units/ore_car/%s_%s.png" % ["full" if cargo > 0.0 else "empty", v]
	var tex: Texture2D = LineArt.tex(rel)
	if tex == null:
		_code_car(off, v)
		return
	var w := tex.get_width()
	var h := tex.get_height()
	draw_set_transform(Vector2(0, 8) + off, 0.0, Vector2(-1 if flip else 1, 1))
	draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -h + 2), Vector2(w, h)), false, Color.WHITE if flash <= 0.0 else Color(1.6, 1.6, 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# code-drawn stand-ins (docs/art_style_inconsistency.md)

func _code_loco(off: Vector2, v: String) -> void:
	var c := Vector2(0, 0) + off
	var body := Color(0.65, 0.16, 0.12)
	var w := 30.0 if v == "e" else 16.0
	var h := 14.0 if v == "e" else 20.0
	draw_rect(Rect2(c - Vector2(w * 0.5, h), Vector2(w, h)), body)
	draw_rect(Rect2(c - Vector2(w * 0.5, h), Vector2(w, 4)), Color(0.15, 0.15, 0.17))
	draw_rect(Rect2(c + Vector2(w * 0.25, -h - 6), Vector2(4, 8)), Color(0.12, 0.12, 0.13))
	draw_rect(Rect2(c - Vector2(w * 0.5, 1), Vector2(w, 3)), Color(0.2, 0.2, 0.22))


func _code_car(off: Vector2, v: String) -> void:
	var c := Vector2(0, 0) + off
	var w := 26.0 if v == "e" else 14.0
	var h := 9.0 if v == "e" else 11.0
	var col := Color(0.45, 0.2, 0.15) if tkind == "ore" else Color(0.3, 0.3, 0.34)
	draw_rect(Rect2(c - Vector2(w * 0.5, h), Vector2(w, h)), col)
	if tkind == "ore" and cargo > 0.0:
		draw_rect(Rect2(c - Vector2(w * 0.5 - 2, h + 2), Vector2(w - 4, 3)), Color(0.85, 0.55, 0.2))
	draw_rect(Rect2(c - Vector2(w * 0.5, 1), Vector2(w, 3)), Color(0.2, 0.2, 0.22))
