class_name CwUnits
extends RefCounted
## The Clockwork roster prototype (docs/clockwork_units_prototype.md): Tin Militia, Scrapper, Rail Rifleman, Work Car,
## Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive, Storm Engine, and the sidings (scripts/cw_rail.gd).
## Everything is data in Defs.UNITS / Defs.CW; this file holds the behaviour and is reached from unit.gd, game.gd,
## train.gd and the HUD through a handful of one-line hooks (grep CwUnits). A unit's own state lives in Unit.cw.
## Distances in pixels (32 per tile), times in seconds.

const T := Defs.TILE
const SIEGE_BLOW := 1.5            # a building_bonus at least this big makes a unit a siege unit for the Plate Wagon


static func on(k: String) -> bool:
	return Defs.CW_KINDS.has(k)


## Kinds that run through the hooks: the roster, plus the old Winder (crew) and Ornithopter (landing).
static func hooked(k: String) -> bool:
	return Defs.CW_KINDS.has(k) or k == "winder" or k == "ornithopter"


# ------------------------------------------------------------------ the distance to the Line

## Tiles (Chebyshev) from cell c to the nearest finished Line segment or Clocktower of team t, up to `limit`+3; 99 beyond.
static func line_dist(game: Game, t: int, c: Vector2i) -> int:
	var net := game.line_net
	var f: Dictionary = net.cw_field.get(t, {})
	if f.is_empty() or int(f["v"]) != net.version:
		f = _build_field(game, t)
		net.cw_field[t] = f
	return int((f["d"] as Dictionary).get(c, 99))


static func _build_field(game: Game, t: int) -> Dictionary:
	var net := game.line_net
	var limit := 14
	var dist := {}
	var q: Array = []
	for c in net.segs:
		var s: PipeSeg = net.segs[c]
		if s.team == t and s.built and not s.dead:
			dist[c] = 0
			q.append(c)
	for b in game.buildings:
		if b.team == t and not b.dead and b.built and b.kind == game.faction_hall(t):
			for y in b.size.y:
				for x in b.size.x:
					var c2: Vector2i = b.cell + Vector2i(x, y)
					if not dist.has(c2):
						dist[c2] = 0
						q.append(c2)
	var i := 0
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		var dd: int = dist[cur]
		if dd >= limit:
			continue
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var n := cur + Vector2i(ox, oy)
				if (ox != 0 or oy != 0) and not dist.has(n):
					dist[n] = dd + 1
					q.append(n)
	return {"v": net.version, "d": dist}


static func leash() -> int:
	return int(Defs.CW["militia"]["leash"])


## The nearest ground within the leash to a point: the point itself if it is allowed.
static func clamp_point(game: Game, t: int, p: Vector2, tiles: int) -> Vector2:
	var c0 := game.cell_of(p)
	if line_dist(game, t, c0) <= tiles:
		return p
	for r in range(1, 40):
		var best := Vector2i(-1, -1)
		var bd := INF
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue
				var c := c0 + Vector2i(ox, oy)
				if game.in_map(c) and line_dist(game, t, c) <= tiles:
					var dd := float(ox * ox + oy * oy)
					if dd < bd:
						bd = dd
						best = c
		if best.x >= 0:
			return game.cell_center(best)
	return p


# ------------------------------------------------------------------ creation

## A unit was made (Game._add_unit): rail kinds go onto the nearest Line, a Work Car gets its crew.
static func on_created(game: Game, u: Unit) -> void:
	if not on(u.kind):
		return
	if Defs.CW_RAIL.has(u.kind):
		var c := game.line_net.rails.nearest_cell(u.team, u.position, 12)
		if c.x >= 0:
			u.position = game.cell_center(c)
			u.last_pos = u.position
			u.leash_from = u.position
	if u.kind == "work_car":
		u.cw["crew"] = []
		for i in int(Defs.CW["work_car"]["crew"]):
			var w := game._add_unit("winder", u.team, u.position)
			stow(u, w)
	if u.kind == "plate_wagon":
		game.cw_gates.append(u)
		u.cw["axis"] = Vector2(1, 0)


## Per-kind extra supply a purchase must have room for (a Work Car's crew).
static func extra_supply(k: String) -> int:
	return int(Defs.UNITS[k].get("extra_supply", 0))


## Why a team cannot have another unit of this kind ("" if it can): one Carrier Car a team.
static func limit_problem(game: Game, t: int, k: String, queued: int) -> String:
	var mx := int(Defs.UNITS[k].get("max_team", 0))
	if mx <= 0:
		return ""
	var have := queued
	for u in game.units:
		if u.team == t and not u.dead and u.kind == k:
			have += 1
	if have >= mx:
		return "Only %d %s per side." % [mx, Loc.t(String(Defs.UNITS[k]["name"]))]
	return ""


# ------------------------------------------------------------------ the per-tick hook

static func pre_tick(u: Unit, delta: float) -> void:
	var k := u.kind
	if Defs.CW_RAIL.has(k):
		if CwRail.bound(u):
			u.speed *= CwRail.speed_mult(u)
			u.wind = 1.0                                  # on the Line a vehicle never runs down
		else:
			u.speed *= float(Defs.CW["heavy"]["off_speed"])
			if _crew_needed(u) and crew_count(u) == 0:
				u.speed *= 0.4                            # no crew: it crawls
		var ax: Vector2 = u.cw.get("axis", Vector2(1, 0))
		if u.velocity.length() > 10.0:
			ax = Vector2(signf(u.velocity.x), 0.0) if absf(u.velocity.x) >= absf(u.velocity.y) else Vector2(0.0, signf(u.velocity.y))
			u.cw["axis"] = ax
		if u.cw.has("packing"):
			_packing(u)
	match k:
		"tin_militia":
			_militia(u, delta)
		"scrapper":
			_scrapper(u, delta)
		"rail_rifleman":
			u.cw["near_t"] = float(u.cw.get("near_t", 0.0)) - delta
			if float(u.cw["near_t"]) <= 0.0:
				u.cw["near_t"] = 0.3
				u.cw["near"] = line_dist(u.game, u.team, u.game.cell_of(u.position)) <= int(Defs.CW["rifle"]["near"])
		"work_car":
			_car(u, delta)
		"plate_wagon":
			_plate(u, delta)
		"heavy_loco", "storm_engine":
			_crewed(u, delta)
			if k == "storm_engine":
				_storm(u, delta)
		"carrier_car":
			_carrier(u, delta)
		"tesla_loco":
			_tesla(u, delta)
		"winder":
			if u.cw.has("car"):
				_crew_member(u, delta)
		"ornithopter":
			if not u.cw.is_empty():
				_topter(u, delta)
	if u.cw.has("slowed"):
		u.speed *= float(u.cw["slowed"])


## Called just before _move: the movement the unit really makes.
static func steer(u: Unit, want: Vector2, delta: float) -> Vector2:
	if u.cw.has("landed") or u.cw.has("cast_left"):
		return Vector2.ZERO
	if u.kind == "heavy_loco" or u.kind == "storm_engine":
		if bool(u.cw.get("set", false)) and not u.cw.has("packing"):
			return Vector2.ZERO                  # set up: it stays
	if u.kind == "work_car" and _crew_out(u) and (u.order == "move" or u.order == "amove"):
		u.cw["wait"] = float(u.cw.get("wait", 0.0)) + delta
		_recall(u)
		if float(u.cw["wait"]) < float(Defs.CW["work_car"]["depart_wait"]):
			return Vector2.ZERO                  # waits for its crew to climb aboard
	elif u.kind == "work_car":
		u.cw["wait"] = 0.0
	if CwRail.bound(u):
		return CwRail.steer(u, want, delta)
	return want


static func post_move(u: Unit) -> void:
	if CwRail.bound(u) and not (u.cw.has("sid") and String(u.cw["sid"]["phase"]) != "to"):
		CwRail.snap(u)


# ------------------------------------------------------------------ orders

## Called at the top of cmd_move: where the unit may really go. Landed flyers take off, a Militia's order is cut at the leash.
static func order_point(u: Unit, p: Vector2) -> Vector2:
	if u.cw.has("landed"):
		undock(u)
	if u.cw.has("boarding") and u.order_target != u.cw["boarding"]:
		u.cw.erase("boarding")
	if Defs.UNITS[u.kind].get("line_bound", false):
		return clamp_point(u.game, u.team, p, leash())
	return p


## Can the Militia take this target (inside its ground)?
static func target_ok(u: Unit, e: Entity) -> bool:
	if not Defs.UNITS[u.kind].get("line_bound", false):
		return true
	return line_dist(u.game, u.team, u.game.cell_of(e.global_position)) <= leash() + 2


## Rail units path along the rails: the waypoints toward `goal`, or false if the unit is not tied to them.
static func plan_path(u: Unit, goal: Vector2) -> bool:
	if not CwRail.bound(u):
		return false
	u.path = CwRail.plan(u, goal)
	u.path_i = 0
	u.path_pending = false
	u.stuck_t = 0.0
	return true


## A unit that has no business leaving the track does not chase in a straight line.
static func chases_straight(u: Unit) -> bool:
	return not CwRail.bound(u)


static func can_fire(u: Unit) -> bool:
	match u.kind:
		"heavy_loco":
			return CwRail.bound(u) or (bool(u.cw.get("set", false)) and not u.cw.has("deploy_t") and crew_count(u) > 0)
		"storm_engine":
			return false
		"rail_rifleman", "tesla_loco":
			return true
	return true


## The weapon's reach: a Rail Rifleman beside the Line shoots farther.
static func range_of(u: Unit) -> float:
	var r := float(u.d["range"])
	if u.kind == "rail_rifleman" and bool(u.cw.get("near", false)):
		r *= float(Defs.CW["rifle"]["range"])
	return r


static func cooldown_mult(u: Unit) -> float:
	if u.kind == "heavy_loco" and not CwRail.bound(u):
		return 1.0 / maxf(power(u), 0.2)
	return 1.0


## Share of its strength an off-rail crewed machine has (1.0 on the rails).
static func power(u: Unit) -> float:
	if CwRail.bound(u):
		return 1.0
	var n := crew_count(u)
	if n <= 0:
		return 0.0
	var seats := float(Defs.CW["heavy"]["crew"])
	return float(Defs.CW["heavy"]["power"]) * (0.4 + 0.6 * minf(1.0, float(n) / seats))


## A weapon of the new kinds fires (called from Unit._strike with the damage worked out so far). True if handled.
static func strike(u: Unit, e: Entity, dmg: float) -> bool:
	var game := u.game
	match u.kind:
		"scrapper":
			dmg *= 1.0 + float(Defs.CW["scrapper"]["damage"]) * float(u.cw.get("stacks", 0))
			e.take_damage(dmg, u, Unit.BLOW_MELEE)
			Sfx.play_any(["combat/thresher_attack", "gear_hit"], u.position)
			game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
			return true
		"tin_militia":
			e.take_damage(dmg, u, Unit.BLOW_MELEE)
			Sfx.play_any(["combat/windup_soldier_attack", "clash"], u.position)
			game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.5)
			return true
		"rail_rifleman":
			rifle_shot(u, e, bool(u.cw.get("near", false)))
			return true
		"heavy_loco":
			if not can_fire(u):
				return true
			var p := power(u)
			dmg *= p * (float(u.d.get("building_bonus", 1.0)) if e.is_building() else 1.0) / maxf(float(u.d.get("building_bonus", 1.0)), 1.0)
			var muzzle := u.center() + u.facing * 34.0
			game.spawn_effect("smoke", muzzle, 0.9)
			e.take_damage(dmg, u)
			game.explode(e.center(), dmg * float(Defs.CW["heavy"]["splash_dmg"]), float(Defs.CW["heavy"]["splash"]), u.team, u)
			Sfx.play_any(["combat/cannon_attack", "cannon"], u.global_position)
			return true
		"tesla_loco":
			tesla_zap(u, e, dmg)
			return true
	return false


static func rifle_shot(u: Unit, e: Entity, near: bool, rate := 1.0) -> void:
	var game := u.game
	var dmg := float(u.d["damage"]) * (float(Defs.CW["rifle"]["damage"]) if near else 1.0) * (1.0 + minf(u.kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])))
	dmg *= lerpf(0.7, 1.0, u.wind)
	e = game.intercept(u, e)
	e.take_damage(dmg * rate, u, Unit.BLOW_RANGED)
	game._zap_visual(u.center() + Vector2(0, -6), e.center(), false, true)
	Sfx.play_any(["combat/tesla_attack", "zap"], u.position)


# ------------------------------------------------------------------ damage taken

## Called from Unit.take_damage: Plate Wagon cover and its weakness to siege.
static func incoming(u: Unit, amount: float, from: Entity, blow: String) -> float:
	var game := u.game
	if u.kind == "plate_wagon" and from is Unit:
		var f: Unit = from
		if float(f.d.get("building_bonus", 1.0)) >= SIEGE_BLOW or float(f.d.get("splash", 0.0)) >= 30.0:
			amount *= float(Defs.CW["plate"]["siege"])
	if blow == Entity.BLOW_RANGED and not game.cw_gates.is_empty():
		for w in game.cw_gates:
			if is_instance_valid(w) and not w.dead and w.team == u.team and float(w.cw.get("cover_t", 0.0)) > 0.0 \
					and w.position.distance_to(u.position) <= float(Defs.CW["plate"]["radius"]):
				return amount * float(Defs.CW["plate"]["cover"])
	return amount


# ------------------------------------------------------------------ Tin Militia

static func _militia(u: Unit, delta: float) -> void:
	var game := u.game
	u.cw["chk"] = float(u.cw.get("chk", 0.0)) - delta
	if u.cw.has("in"):
		u.wind = 1.0
		return
	var ok := line_dist(game, u.team, game.cell_of(u.position)) <= leash()
	if ok:
		u.wind = minf(1.0, u.wind + 0.5 * delta)          # near the Line they never run down
	if float(u.cw["chk"]) > 0.0:
		return
	u.cw["chk"] = 0.5
	if not ok and u.order != "move":
		u.cmd_move(clamp_point(game, u.team, u.position, leash() - 1))      # pulled back to its ground
	if u.cw.has("boarding"):
		var v = u.cw["boarding"]
		if not is_instance_valid(v) or v.dead or crew_count(v) >= seats(v):
			u.cw.erase("boarding")
		elif u.position.distance_to(v.position) < 36.0:
			stow(v, u)


# ------------------------------------------------------------------ Scrapper

## A unit died: every Scrapper near it salvages the wreck.
static func on_death(game: Game, dead: Unit) -> void:
	if dead.kind == "work_car" or dead.kind == "heavy_loco" or dead.kind == "storm_engine":
		_strand(dead)
	if dead.kind == "carrier_car":
		for f in dead.cw.get("deck", []).duplicate():
			if is_instance_valid(f):
				undock(f)
	if dead.kind == "plate_wagon":
		game.cw_gates.erase(dead)
	if dead.kind == "ornithopter" and dead.cw.has("cargo"):
		drop_cargo(dead, dead.position, 0.3)
	if dead.cw.has("landed"):
		undock(dead, true)
	var cfg: Dictionary = Defs.CW["scrapper"]
	var fuel := int(Defs.CW["militia"]["fuel"]) if dead.kind == "tin_militia" else 1
	for s in game.units_near(dead.position, float(cfg["reach"])):
		if s.kind != "scrapper" or s.dead or s == dead or s.off_field:
			continue
		if float(s.cw.get("gain_cd", 0.0)) > 0.0:
			continue
		s.cw["gain_cd"] = float(cfg["gain_cd"])
		var st := mini(int(cfg["max"]), int(s.cw.get("stacks", 0)) + fuel)
		s.cw["stacks"] = st
		s.cw["decay_t"] = float(cfg["decay"])
		s.hp = minf(s.max_hp, s.hp + float(cfg["heal"]) * float(fuel))
		if game.view_rect.has_point(s.position):
			game.float_text(s.position + Vector2(0, -34), "scrap x%d" % st, Color(0.95, 0.7, 0.35))


static func _scrapper(u: Unit, delta: float) -> void:
	var cfg: Dictionary = Defs.CW["scrapper"]
	u.cw["gain_cd"] = maxf(0.0, float(u.cw.get("gain_cd", 0.0)) - delta)
	var st := int(u.cw.get("stacks", 0))
	if st > 0:
		u.cw["decay_t"] = float(u.cw.get("decay_t", 0.0)) - delta
		if float(u.cw["decay_t"]) <= 0.0:
			st -= 1
			u.cw["stacks"] = st
			u.cw["decay_t"] = float(cfg["decay"])
	u.speed *= 1.0 + float(cfg["speed"]) * float(st)


# ------------------------------------------------------------------ crews (Heavy Locomotive, Storm Engine)

static func _crew_needed(u: Unit) -> bool:
	return u.kind == "heavy_loco" or u.kind == "storm_engine"


static func seats(v: Unit) -> int:
	return int(Defs.CW["heavy"]["crew"]) if v.kind == "heavy_loco" else int(Defs.CW["storm"]["crew"])


static func crew_count(v: Unit) -> int:
	var l: Array = v.cw.get("passengers", [])
	var n := 0
	for m in l:
		if is_instance_valid(m) and not m.dead:
			n += 1
	return n


## Can this unit climb in as crew?
static func can_crew(m: Unit, v: Unit) -> bool:
	return m.kind == "tin_militia" and not m.dead and not m.off_field and v != null and is_instance_valid(v) and not v.dead \
		and m.team == v.team and _crew_needed(v) and crew_count(v) < seats(v)


static func board_order(men: Array, v: Unit) -> int:
	var n := 0
	var room := seats(v) - crew_count(v)
	for m in men:
		if n >= room:
			break
		if can_crew(m, v):
			m.cmd_move(v.position)
			m.cw["boarding"] = v
			n += 1
	return n


## A man climbs aboard (a Militia into a loco, a Winder into the Work Car): hidden, safe, wound.
static func stow(v: Unit, m: Unit) -> void:
	var key := "crew" if v.kind == "work_car" else "passengers"
	var l: Array = v.cw.get(key, [])
	if key == "passengers" and l.has(m):
		return
	m.cmd_stop()
	m.release_horses()
	m.velocity = Vector2.ZERO
	m.off_field = true
	m.visible = false
	m.selected = false
	m.target = null
	m.phase = ""
	m.aboard = v
	m.game.selection.erase(m)
	m.position = v.position
	m.cw.erase("boarding")
	if v.kind == "work_car":
		m.cw["car"] = v
		m.auto_work = false
		m.cw.erase("rtn")
		m.cw["idle_t"] = 0.0
	else:
		m.cw["in"] = v
	if not l.has(m):
		l.append(m)
	v.cw[key] = l


static func unstow(v: Unit, m: Unit, at: Vector2) -> void:
	m.off_field = false
	m.aboard = null
	m.visible = true
	m.position = at
	m.last_pos = at
	m.velocity = Vector2.ZERO
	m.cw.erase("in")
	m.cmd_stop()
	var key := "crew" if v.kind == "work_car" else "passengers"
	if key == "passengers":
		(v.cw.get(key, []) as Array).erase(m)


static func _crewed(u: Unit, delta: float) -> void:
	var l: Array = u.cw.get("passengers", [])
	for m in l.duplicate():
		if not is_instance_valid(m) or m.dead:
			l.erase(m)
			continue
		m.position = u.position
		m.wind = 1.0                       # aboard they stay wound
	if u.cw.has("deploy_t"):
		u.cw["deploy_t"] = float(u.cw["deploy_t"]) - delta
		if float(u.cw["deploy_t"]) <= 0.0:
			u.cw.erase("deploy_t")
	if bool(u.cw.get("set", false)) and not u.cw.has("packing"):
		# set up on the ground: without a crew it is helpless (no fire; the storm engine casts nothing)
		pass
	elif u.cw.has("setting") and u.order == "idle":
		# arrived at its spot: it sets up
		u.cw.erase("setting")
		u.cw["set"] = true
		u.cw["deploy_t"] = float(Defs.CW["heavy"]["deploy"])
	if u.cw.has("setting") and not bool(u.cw.get("off", false)):
		u.cw.erase("setting")


## SET UP: take it off the rails to a spot within `reach` tiles of the Line. Returns "" or why not.
static func set_up_order(u: Unit, p: Vector2) -> String:
	var game := u.game
	var reach: int = int(Defs.CW["heavy"]["reach"]) if u.kind == "heavy_loco" else int(Defs.CW["storm"]["reach"])
	if bool(u.cw.get("set", false)):
		return "It is set up already: PACK it first."
	var c := game.cell_of(p)
	if line_dist(game, u.team, c) > reach:
		return "Too far from the Line (%d tiles at most)." % reach
	if not game.is_free(c):
		return "No room to set up there."
	u.cw["off"] = true
	u.cw["setting"] = true
	u.cw.erase("sid")
	u.cmd_move(p)
	return ""


## PACK: back to the rails.
static func pack_order(u: Unit) -> void:
	if not bool(u.cw.get("off", false)):
		return
	u.cw.erase("set")
	u.cw.erase("setting")
	u.cw.erase("deploy_t")
	u.cw["packing"] = true
	var c := u.game.line_net.rails.nearest_cell(u.team, u.position, 14)
	if c.x >= 0:
		u.cmd_move(u.game.cell_center(c))


static func _packing(u: Unit) -> void:
	var c := u.game.line_net.rails.nearest_cell(u.team, u.position, 14)
	if c.x < 0:
		u.cw.erase("packing")
		return
	if u.position.distance_to(u.game.cell_center(c)) < 14.0:
		u.cw.erase("packing")
		u.cw.erase("off")
		CwRail.snap(u)


## Everyone aboard (or the stranded crew of a Work Car) gets out around the vehicle.
static func disembark(v: Unit) -> void:
	var l: Array = v.cw.get("passengers", [])
	var i := 0
	for m in l.duplicate():
		if is_instance_valid(m):
			unstow(v, m, v.position + Vector2.from_angle(float(i) * 1.3) * (v.radius + 16.0))
		i += 1
	l.clear()


# ------------------------------------------------------------------ Work Car

static func _crew_out(car: Unit) -> bool:
	for w in car.cw.get("crew", []):
		if is_instance_valid(w) and not w.dead and not w.off_field:
			return true
	return false


static func _aboard(car: Unit) -> Array:
	var out: Array = []
	for w in car.cw.get("crew", []):
		if is_instance_valid(w) and not w.dead and w.off_field:
			out.append(w)
	return out


static func _recall(car: Unit) -> void:
	for w in car.cw.get("crew", []):
		if is_instance_valid(w) and not w.dead and not w.off_field and not w.cw.has("rtn"):
			w.cw["rtn"] = true
			w.cmd_move(car.position)


## One crew member steps out at the car.
static func eject(car: Unit, w: Unit) -> void:
	var ang := randf() * TAU
	w.off_field = false
	w.aboard = null
	w.visible = true
	w.position = car.position + Vector2.from_angle(ang) * (car.radius + 10.0)
	w.last_pos = w.position
	w.velocity = Vector2.ZERO
	w.cw.erase("rtn")
	w.cw["idle_t"] = 0.0
	w.auto_repair = true
	w.auto_work = false
	w.cmd_stop()


## BUILD with a Work Car selected (Game.place_building, lay_line): the car takes the job; its crew do it near the site.
static func assign_builders(game: Game, builders: Array, site: Building) -> Array:
	var out: Array = []
	for b in builders:
		if b is Unit and b.kind == "work_car" and not b.dead:
			var sites: Array = b.cw.get("sites", [])
			sites.append(site)
			b.cw["sites"] = sites
			b.cw["job_t"] = 0.0
		else:
			out.append(b)
	return out


static func car_claims(game: Game, site: Building) -> bool:
	for u in game.units:
		if u.kind == "work_car" and not u.dead and (u.cw.get("sites", []) as Array).has(site):
			return true
	return false


## LAY with a Work Car: its crew come out and lay (they return when they are done).
static func expand_layers(builders: Array) -> Array:
	var out: Array = []
	for b in builders:
		if b is Unit and b.kind == "work_car" and not b.dead:
			for w in _aboard(b):
				eject(b, w)
				out.append(w)
			for w in b.cw.get("crew", []):
				if is_instance_valid(w) and not w.dead and not w.off_field and not out.has(w):
					out.append(w)
		else:
			out.append(b)
	return out


static func _car(car: Unit, delta: float) -> void:
	var cfg: Dictionary = Defs.CW["work_car"]
	var game := car.game
	var crew: Array = car.cw.get("crew", [])
	for w in crew.duplicate():
		if not is_instance_valid(w) or w.dead:
			crew.erase(w)
		elif w.off_field:
			w.position = car.position
			w.wind = 1.0
	car.cw["job_t"] = float(car.cw.get("job_t", 0.0)) - delta
	if float(car.cw["job_t"]) > 0.0:
		return
	car.cw["job_t"] = 1.0
	var r := float(cfg["radius"]) * T
	# crew who are out: idle ones walk back
	for w in crew:
		if w.off_field:
			continue
		if w.cw.has("rtn"):
			if w.position.distance_to(car.position) < float(cfg["board"]):
				stow(car, w)
			elif w.order == "idle":
				w.cmd_move(car.position)
			continue
		var busy: bool = w.order != "idle" or w.work != ""
		if busy:
			w.cw["idle_t"] = 0.0
		else:
			w.cw["idle_t"] = float(w.cw.get("idle_t", 0.0)) + 1.0
		var far: bool = w.position.distance_to(car.position) > r * 1.6
		if (float(w.cw["idle_t"]) >= float(cfg["idle_back"]) or far and not busy) and not bool(car.cw.get("out", false)):
			w.cw["rtn"] = true
			w.cmd_move(car.position)
	if (car.order == "move" or car.order == "amove"):
		return                                  # driving: no new jobs
	# sites queued with BUILD
	var sites: Array = car.cw.get("sites", [])
	for s in sites.duplicate():
		if not is_instance_valid(s) or s.dead or s.built or (s.seeded and not s.ghost):
			sites.erase(s)
			continue
		if car.position.distance_to(s.center()) > r:
			if CwRail.bound(car) and car.order == "idle":
				car.cmd_move(s.center())
			continue
		var w := _free_hand(car)
		if w != null:
			eject(car, w)
			if s.crate != "" and s.crate != "carried":
				w.crate_site = s                  # the car carries the crates
				s.crate = "carried"
				s.crate_carrier = w
			w.cmd_build(s)
			sites.erase(s)
	# mending and winding within the radius
	if bool(car.cw.get("out", false)):
		for w in _aboard(car):
			eject(car, w)
		return
	if _aboard(car).is_empty() or int(game.players[car.team]["gold"]) < 1:
		return
	var hurt := game.find_repair(car, r)
	if hurt != null:
		var w2 := _free_hand(car)
		if w2 != null:
			eject(car, w2)
			if w2.can_repair(hurt):
				w2.cmd_repair(hurt)
			else:
				stow(car, w2)


static func _free_hand(car: Unit) -> Unit:
	var a := _aboard(car)
	return a[0] if not a.is_empty() else null


static func _crew_member(w: Unit, _delta: float) -> void:
	var car = w.cw.get("car")
	if car == null or not is_instance_valid(car) or car.dead:
		return
	w.auto_work = false


## CREW OUT / CREW IN on the card.
static func crew_toggle(car: Unit, out: bool) -> void:
	car.cw["out"] = out
	if not out:
		_recall(car)


## The car was destroyed (or a loco): its crew are stranded, slow on their feet; a loco's crew climb out hurt.
static func _strand(v: Unit) -> void:
	if v.kind == "work_car":
		for w in v.cw.get("crew", []):
			if is_instance_valid(w) and not w.dead:
				if w.off_field:
					unstow(v, w, v.position + Vector2.from_angle(randf() * TAU) * (v.radius + 14.0))
				w.cw.erase("car")
				w.cw.erase("rtn")
				w.cw["slowed"] = float(Defs.CW["work_car"]["stranded"])
				w.cw["stranded"] = true
				w.auto_work = true
		v.cw["crew"] = []
		return
	var l: Array = v.cw.get("passengers", [])
	for m in l.duplicate():
		if is_instance_valid(m) and not m.dead:
			unstow(v, m, v.position + Vector2.from_angle(randf() * TAU) * (v.radius + 14.0))
			m.hp = maxf(1.0, m.hp - m.max_hp * 0.3)
	l.clear()


# ------------------------------------------------------------------ Plate Wagon

static func _plate(u: Unit, delta: float) -> void:
	u.cw["cd"] = maxf(0.0, float(u.cw.get("cd", 0.0)) - delta)
	var ct := float(u.cw.get("cover_t", 0.0))
	if ct > 0.0:
		ct -= delta
		u.cw["cover_t"] = ct
		u.cw["up_k"] = minf(1.0, float(u.cw.get("up_k", 0.0)) + delta / float(Defs.CW["plate"]["deploy"]))
		if ct <= 0.0:
			u.cw["cover_t"] = 0.0
			u.cw["cd"] = float(Defs.CW["plate"]["cooldown"])
	else:
		u.cw["up_k"] = maxf(0.0, float(u.cw.get("up_k", 0.0)) - delta / float(Defs.CW["plate"]["deploy"]))


static func plates_problem(u: Unit) -> String:
	if float(u.cw.get("cover_t", 0.0)) > 0.0:
		return "The plates are up already."
	if float(u.cw.get("cd", 0.0)) > 0.0:
		return "The plates are cooling: %d s." % int(ceil(float(u.cw["cd"])))
	return ""


static func plates_up(u: Unit) -> void:
	if plates_problem(u) == "":
		u.cw["cover_t"] = float(Defs.CW["plate"]["time"])


## The half-width of the gate right now.
static func gate_half(w: Unit) -> float:
	return lerpf(float(Defs.CW["plate"]["half"]), float(Defs.CW["plate"]["half_up"]), float(w.cw.get("up_k", 0.0)))


## Called after an enemy ground unit moved: it cannot pass a Plate Wagon. Returns the corrected position.
static func gate_push(u: Unit, before: Vector2, now: Vector2) -> Vector2:
	var game := u.game
	for w in game.cw_gates:
		if not is_instance_valid(w) or w.dead or w.off_field or not game.hostile(w.team, u.team):
			continue
		if w.position.distance_squared_to(now) > 160.0 * 160.0:
			continue
		var ax: Vector2 = w.cw.get("axis", Vector2(1, 0))
		var perp := Vector2(-ax.y, ax.x)
		var h := gate_half(w)
		var a: Vector2 = w.position - perp * h
		var b: Vector2 = w.position + perp * h
		var q := Geometry2D.get_closest_point_to_segment(now, a, b)
		var mind := 14.0 + u.radius
		if now.distance_to(q) < mind:
			var n := (before - q)
			if n.length() < 0.5:
				n = now - q
			n = n.normalized() if n.length() > 0.01 else perp
			now = q + n * mind
			if u.target == null and u.has_attack() and u.can_hit(w) and u.order in ["idle", "amove", "attack"]:
				u.target = w
	return now


# ------------------------------------------------------------------ Carrier Car and docked Ornithopters

static func _carrier(c: Unit, delta: float) -> void:
	var deck: Array = c.cw.get("deck", [])
	var i := 0
	for f in deck.duplicate():
		if not is_instance_valid(f) or f.dead or not f.cw.has("landed"):
			deck.erase(f)
			continue
		f.position = c.position + Vector2(-14.0 + 28.0 * float(i), -16.0)
		i += 1
	c.cw["deck"] = deck


static func deck_room(c: Unit) -> int:
	var n := 0
	for f in c.cw.get("deck", []):
		if is_instance_valid(f) and not f.dead:
			n += 1
	return int(Defs.CW["carrier"]["deck"]) - n


## DOCK: Ornithopters fly to a Carrier Car and land on its deck.
static func dock_order(flyers: Array, car: Unit) -> int:
	var n := 0
	var room := deck_room(car)
	for f in flyers:
		if n >= room:
			break
		if f.kind == "ornithopter" and not f.cw.has("landed") and not f.dead:
			f.cw["dock"] = car
			f.cmd_move(car.position)
			n += 1
	return n


static func _topter(u: Unit, delta: float) -> void:
	var cfg: Dictionary = Defs.CW["carrier"]
	if u.cw.has("dock"):
		var car = u.cw["dock"]
		if not is_instance_valid(car) or car.dead or deck_room(car) <= 0:
			u.cw.erase("dock")
		elif u.position.distance_to(car.position) < 36.0:
			u.cw.erase("dock")
			u.cmd_stop()
			u.cw["landed"] = car
			var deck: Array = car.cw.get("deck", [])
			deck.append(u)
			car.cw["deck"] = deck
			u.velocity = Vector2.ZERO
	if u.cw.has("landed"):
		u.hp = minf(u.max_hp, u.hp + float(cfg["heal"]) * delta)
		u.wind = minf(1.0, u.wind + float(cfg["wind"]) * delta)
		u.cw["bat_t"] = float(u.cw.get("bat_t", 0.0)) + delta
		if u.topter_bat == "" and float(u.cw["bat_t"]) > 3.0:
			u.topter_bat = "yellow"            # a fresh battery from the car
		u.speed = 0.0
	if u.cw.has("drop_at") and u.cw.has("cargo") and u.position.distance_to(u.cw["drop_at"]) < 44.0:
		drop_cargo(u, u.position, 0.0)
		u.cw.erase("drop_at")


static func undock(f: Unit, dying := false) -> void:
	var car = f.cw.get("landed")
	f.cw.erase("landed")
	f.cw.erase("dock")
	if car != null and is_instance_valid(car):
		(car.cw.get("deck", []) as Array).erase(f)


## CARRY: a landed Ornithopter takes the nearest small unit by the car aboard.
static func carry_problem(f: Unit) -> String:
	if not f.cw.has("landed"):
		return "It must be landed on a Carrier Car."
	if f.cw.has("cargo"):
		return "It carries one already."
	return ""


static func carry_order(f: Unit) -> String:
	var why := carry_problem(f)
	if why != "":
		return why
	var car: Unit = f.cw["landed"]
	var best: Unit = null
	var bd := float(Defs.CW["carrier"]["pick"])
	for u in f.game.units_near(car.position, bd):
		if u.team != f.team or u.dead or u.off_field or u.is_air() or Defs.CW_RAIL.has(u.kind) or u == f or u.kind == "horse":
			continue
		if int(u.d["supply"]) > 1 or u.is_mounted() or Defs.CROWN_MACHINES.has(u.kind):
			continue
		var dd: float = u.position.distance_to(car.position)
		if dd < bd:
			bd = dd
			best = u
	if best == null:
		return "No small unit beside the car."
	best.cmd_stop()
	best.velocity = Vector2.ZERO
	best.off_field = true
	best.visible = false
	best.selected = false
	best.aboard = f
	best.game.selection.erase(best)
	best.target = null
	f.cw["cargo"] = best
	return ""


static func drop_order(f: Unit, p: Vector2) -> String:
	if not f.cw.has("cargo"):
		return "It carries nothing."
	f.cw["drop_at"] = p
	f.cmd_move(p)
	return ""


static func drop_cargo(f: Unit, at: Vector2, hurt: float) -> void:
	var m = f.cw.get("cargo")
	f.cw.erase("cargo")
	if m == null or not is_instance_valid(m) or m.dead:
		return
	var spots := f.game.drop_spots(at, 1, f.team)
	m.off_field = false
	m.aboard = null
	m.visible = true
	m.position = spots[0] if not spots.is_empty() else at
	m.last_pos = m.position
	if hurt > 0.0:
		m.hp = maxf(1.0, m.hp - m.max_hp * hurt)
	m.cmd_stop()


# ------------------------------------------------------------------ Tesla Locomotive

static func pressure_under(u: Unit) -> float:
	var s: PipeSeg = u.game.line_net.segs.get(u.game.cell_of(u.position))
	return s.pressure if s != null else 0.0


static func tesla_zap(u: Unit, e: Entity, dmg: float) -> void:
	var game := u.game
	var cfg: Dictionary = Defs.CW["tesla"]
	var p := pressure_under(u) if game.line_net.enforce else 1.0
	var k := lerpf(float(cfg["min_p"]), 1.0, clampf(p / 0.8, 0.0, 1.0)) + float(cfg["pressure_bonus"]) * maxf(0.0, p - 0.5)
	dmg *= k
	var from := u.center() + Vector2(0, -22)
	var hit: Array = [e]
	e.take_damage(dmg, u)
	game._zap_visual(from, e.center(), false, true)
	var last: Entity = e
	var d2 := dmg
	for j in int(cfg["jumps"]):
		d2 *= float(cfg["falloff"])
		var nxt: Entity = null
		var bd := 80.0
		for o in game.units_near(last.center(), 80.0):
			if not game.hostile(o.team, u.team) or o.dead or o.off_field or hit.has(o):
				continue
			var dd: float = o.center().distance_to(last.center())
			if dd < bd:
				bd = dd
				nxt = o
		if nxt == null:
			break
		nxt.take_damage(d2, u)
		game._zap_visual(last.center(), nxt.center(), false)
		hit.append(nxt)
		last = nxt
	# along the pipe: enemies standing at the Line within reach of the cells near the loco
	var net := game.line_net
	var here := game.cell_of(u.position)
	var along := 0
	for c in net.segs:
		if absi(c.x - here.x) > 5 or absi(c.y - here.y) > 5 or along >= 2:
			continue
		var cc := game.cell_center(c)
		for o in game.units_near(cc, float(cfg["reach"]) * 0.45):
			if along >= 2:
				break
			if not game.hostile(o.team, u.team) or o.dead or o.off_field or hit.has(o) or o.position.distance_to(u.position) > float(u.d["range"]) + 60.0:
				continue
			o.take_damage(d2 * 0.8, u)
			game._zap_visual(cc, o.center(), false)
			hit.append(o)
			along += 1
	Sfx.play_any(["combat/tesla_attack", "zap"], u.global_position)


static func _tesla(u: Unit, delta: float) -> void:
	u.cw["ovc_t"] = float(u.cw.get("ovc_t", 0.0)) - delta
	if float(u.cw["ovc_t"]) > 0.0:
		return
	u.cw["ovc_t"] = 0.4
	for o in u.game.units_near(u.position, float(Defs.CW["tesla"]["pass"])):
		if o.team == u.team and o != u and not o.dead and not o.off_field and o.d["faction"] == "clockwork" and not o.is_worker() and not Defs.CW_RAIL.has(o.kind):
			o.overcharge_t = maxf(o.overcharge_t, float(Defs.OVERCHARGE["time"]))      # passing it charges them at once


# ------------------------------------------------------------------ Storm Engine

static func storm_problem(u: Unit) -> String:
	if float(u.cw.get("cd", 0.0)) > 0.0:
		return "Recharging: %d s." % int(ceil(float(u.cw["cd"])))
	if not CwRail.bound(u):
		if not bool(u.cw.get("set", false)) or u.cw.has("deploy_t"):
			return "Set up first (or pack onto the rails)."
		if crew_count(u) <= 0:
			return "No Tin Militia aboard: it cannot steam."
	return ""


static func cast_order(units: Array, p: Vector2) -> String:
	var why := ""
	var sent := 0
	for u in units:
		if u.kind != "storm_engine" or u.dead:
			continue
		var w := storm_problem(u)
		if w != "":
			why = w
			continue
		u.cw["target"] = p
		sent += 1
		if u.position.distance_to(p) > float(Defs.CW["storm"]["range"]):
			if CwRail.bound(u):
				u.cmd_move(p)                    # runs along the Line until the spot is in range
	if sent == 0 and why != "":
		return why
	return ""


static func _storm(u: Unit, delta: float) -> void:
	var cfg: Dictionary = Defs.CW["storm"]
	u.cw["cd"] = maxf(0.0, float(u.cw.get("cd", 0.0)) - delta)
	if u.cw.has("cast_left"):
		u.cw["cast_left"] = float(u.cw["cast_left"]) - delta
		if float(u.cw["cast_left"]) <= 0.0:
			u.cw.erase("cast_left")
			var off := not CwRail.bound(u)
			raise_storm(u.game, u.team, u.cw["cast_at"], u,
				float(cfg["radius"]) * (float(cfg["off_radius"]) if off else 1.0),
				float(cfg["dps"]) * (float(cfg["off_dps"]) if off else 1.0), float(cfg["time"]))
			u.cw["cd"] = float(cfg["cooldown"])
		return
	if u.cw.has("target"):
		var p: Vector2 = u.cw["target"]
		if u.position.distance_to(p) <= float(cfg["range"]):
			u.cw.erase("target")
			if storm_problem(u) == "":
				u.cw["cast_at"] = p
				u.cw["cast_left"] = float(cfg["cast"])
				u.cmd_stop()
				u.facing = (p - u.position).normalized()
		elif u.order == "idle":
			u.cw.erase("target")


static func raise_storm(game: Game, t: int, p: Vector2, owner: Unit, r: float, dps: float, secs: float) -> void:
	game.cw_storms.append({"pos": p, "team": t, "r": r, "dps": dps, "t": secs, "age": 0.0, "bolt": 0.0, "owner": owner})
	if game.cw_fx == null:
		var n := Node2D.new()
		n.z_index = 25
		n.draw.connect(func() -> void: draw_storms(game, n))
		game.add_child(n)
		game.cw_fx = n
	Sfx.play_any(["combat/tesla_attack", "zap"], p)


## Ticked by Game: the storms in the field (they outlast their engine).
static func tick_game(game: Game, delta: float) -> void:
	if game.cw_storms.is_empty():
		return
	for s in game.cw_storms.duplicate():
		s["age"] = float(s["age"]) + delta
		var p: Vector2 = s["pos"]
		var r: float = s["r"]
		for u in game.units_near(p, r + 24.0):
			if u.dead or u.off_field or not game.hostile(u.team, int(s["team"])):
				continue
			if not game.in_ellipse(p, u.position, r + u.radius):
				continue
			u.slow_t = maxf(u.slow_t, 0.4)
			u.take_damage(float(s["dps"]) * delta, s["owner"] if is_instance_valid(s["owner"]) else null)
		for b in game.buildings.duplicate():
			pass
		s["bolt"] = float(s["bolt"]) - delta
		if float(s["bolt"]) <= 0.0:
			s["bolt"] = 0.22
			var a := randf() * TAU
			var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.7) * r * sqrt(randf())
			if ArtData.EFFECTS.has("zap_strike"):
				var fx := game.spawn_effect("zap_strike", q, 1.6)
				fx.offset = Vector2(0, -float(ArtData.EFFECTS["zap_strike"]["size"].y) * 0.45)
			else:
				game.spawn_effect("hit", q, 1.0)
		if float(s["age"]) >= float(s["t"]):
			game.cw_storms.erase(s)
	if game.cw_fx != null:
		game.cw_fx.queue_redraw()


static func draw_storms(game: Game, cv: Node2D) -> void:
	for s in game.cw_storms:
		var p: Vector2 = s["pos"]
		var r: float = s["r"]
		var k := clampf(float(s["age"]) / 0.8, 0.0, 1.0) * clampf((float(s["t"]) - float(s["age"])) / 1.0, 0.0, 1.0)
		cv.draw_set_transform(p, 0.0, Vector2(1.0, 0.7))
		cv.draw_circle(Vector2.ZERO, r, Color(0.2, 0.18, 0.34, 0.38 * k))
		for i in 7:
			var a := float(i) * TAU / 7.0 + float(s["age"]) * 0.6
			cv.draw_circle(Vector2.from_angle(a) * r * 0.55, r * 0.38, Color(0.3, 0.27, 0.45, 0.22 * k))
		cv.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.6, 0.55, 0.9, 0.55 * k), 2.0)
		cv.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ riding a Troop Train

## The riflemen on a Troop Train shoot from it (called by Train.step).
static func train_fire(tr: Train, delta: float) -> void:
	for m in tr.riders:
		if not is_instance_valid(m) or m.dead or m.kind != "rail_rifleman":
			continue
		m.cw["tcd"] = float(m.cw.get("tcd", 0.0)) - delta
		if float(m.cw["tcd"]) > 0.0:
			continue
		var e := tr.game.find_target(m, float(m.d["range"]) * float(Defs.CW["rifle"]["range"]))
		if e == null:
			m.cw["tcd"] = 0.4
			continue
		m.cw["tcd"] = float(m.d["cooldown"]) / float(Defs.CW["rifle"]["train"])
		rifle_shot(m, e, true)


# ------------------------------------------------------------------ the HUD

static func info(u: Unit) -> String:
	var cfg: Dictionary = Defs.CW
	match u.kind:
		"tin_militia":
			if u.cw.has("in"):
				return "Aboard a machine: wound and safe."
			return "Holds ground within %d tiles of the Line." % leash()
		"scrapper":
			var st := int(u.cw.get("stacks", 0))
			var c: Dictionary = cfg["scrapper"]
			return "Salvage x%d of %d: +%d%% damage, +%d%% speed, one stack lost every %d s." % [st, int(c["max"]), int(round(st * float(c["damage"]) * 100.0)), int(round(st * float(c["speed"]) * 100.0)), int(c["decay"])]
		"rail_rifleman":
			var rg := int(round((float(cfg["rifle"]["range"]) - 1.0) * 100.0))
			var dm := int(round((float(cfg["rifle"]["damage"]) - 1.0) * 100.0))
			if bool(u.cw.get("near", false)):
				return "Beside the Line: +%d%% range, +%d%% damage." % [rg, dm]
			return "Too far from the Line for the bonus (+%d%% range, +%d%% damage)." % [rg, dm]
		"work_car":
			var crew: Array = u.cw.get("crew", [])
			return "Crew %d (%d aboard, %d out)." % [crew.size(), _aboard(u).size(), crew.size() - _aboard(u).size()]
		"plate_wagon":
			if float(u.cw.get("cover_t", 0.0)) > 0.0:
				return "Plates up for %d s: ranged hits on your units near it do %d%%." % [int(ceil(float(u.cw["cover_t"]))), int(float(cfg["plate"]["cover"]) * 100.0)]
			if float(u.cw.get("cd", 0.0)) > 0.0:
				return "Plates cooling: %d s." % int(ceil(float(u.cw["cd"])))
			return "A gate across the track for enemy ground units."
		"heavy_loco", "storm_engine":
			var n := crew_count(u)
			var sn := seats(u)
			if CwRail.bound(u):
				return "On the rails. Crew %d/%d." % [n, sn]
			var pw := int(round(power(u) * 100.0))
			var set_up: bool = bool(u.cw.get("set", false)) and not u.cw.has("deploy_t")
			if pw > 0:
				return ("SET UP. Crew %d/%d: power %d%%." if set_up else "Off the rails. Crew %d/%d: power %d%%.") % [n, sn, pw]
			return ("SET UP. Crew %d/%d: helpless without crew." if set_up else "Off the rails. Crew %d/%d: helpless without crew.") % [n, sn]
		"carrier_car":
			return "Deck: %d of %d seats free." % [deck_room(u), int(cfg["carrier"]["deck"])]
		"tesla_loco":
			return "Pressure under it: %d%%." % int(round(pressure_under(u) * 100.0))
		"ornithopter":
			if u.cw.has("landed"):
				return "Landed on a Carrier Car: healing, winding up, recharging."
			if u.cw.has("cargo"):
				return "Carrying a %s." % Loc.t(String(u.cw["cargo"].d["name"]))
	return ""


## The extra buttons of the roster for a selection: [icon, label, callback, enabled, why, count] pushed onto `list`.
static func card(hud, list: Array, units: Array) -> void:
	var game: Game = hud.game
	var ctl = hud.controls
	var own := units.filter(func(u: Unit) -> bool: return u.team == game.human)
	for lab in TIPS:
		hud._tip_for[lab] = TIPS[lab]
	# SIDING (Winders and Work Cars)
	if own.any(func(u: Unit) -> bool: return u.kind == "winder" or u.kind == "work_car"):
		hud._tip_for["SIDING"] = ["Siding", "Tap a straight piece of your Line to give it (or take away) a side arm where a vehicle waits for another to pass (%d ore; one every %d tiles)." % [int(Defs.CW["siding"]["cost"]), int(Defs.CW["siding"]["gap"])]]
		list.append(["ab_siding", "SIDING", func() -> void:
			ctl.mode = "cwsiding"
			hud.toast("Tap a straight piece of the Line."), true, "", str(Defs.CW["siding"]["cost"])])
	var cars := own.filter(func(u: Unit) -> bool: return u.kind == "work_car")
	if not cars.is_empty():
		var out: bool = cars.any(func(u: Unit) -> bool: return bool(u.cw.get("out", false)))
		list.append(["ab_cw_crew_out", "CREW OUT", func() -> void:
			for c in cars:
				crew_toggle(c, true)
			hud.toast("The crew come out and work within %d tiles of the car." % int(Defs.CW["work_car"]["radius"])), not out, "They are out already.", ""])
		list.append(["ab_cw_crew_in", "CREW IN", func() -> void:
			for c in cars:
				crew_toggle(c, false)
			hud.toast("The crew walk back aboard."), true, "", ""])
	var plates := own.filter(func(u: Unit) -> bool: return u.kind == "plate_wagon")
	if not plates.is_empty():
		var why := ""
		for w in plates:
			why = plates_problem(w)
			if why == "":
				break
		list.append(["ab_cw_plates", "PLATES", func() -> void:
			for w in plates:
				plates_up(w)
			hud.toast("Side plates up for %d s." % int(Defs.CW["plate"]["time"])), why == "", why, ""])
	var machines := own.filter(func(u: Unit) -> bool: return u.kind == "heavy_loco" or u.kind == "storm_engine")
	if not machines.is_empty():
		var any_off: bool = machines.any(func(u: Unit) -> bool: return bool(u.cw.get("off", false)))
		if any_off:
			list.append(["ab_cw_pack", "PACK", func() -> void:
				for m in machines:
					pack_order(m)
				hud.toast("Packing: back onto the rails."), true, "", ""])
		else:
			list.append(["ab_cw_setup", "SET UP", func() -> void:
				ctl.mode = "cwsetup"
				hud.toast("Tap the ground (up to %d tiles from the Line) to set up. It needs Tin Militia aboard there." % int(Defs.CW["heavy"]["reach"])), true, "", ""])
		var men := own.filter(func(u: Unit) -> bool: return u.kind == "tin_militia")
		list.append(["ab_cw_board", "BOARD", func() -> void:
			var sent := 0
			var sel := game.selected_units().filter(func(u: Unit) -> bool: return u.kind == "tin_militia")
			for m in machines:
				sent += board_order(sel, m)
				sel = sel.filter(func(u: Unit) -> bool: return not u.cw.has("boarding"))
			hud.toast("%d Tin Militia climb aboard." % sent if sent > 0 else "Select Tin Militia with it first (they must be within their ground)."), true, "", ""])
		list.append(["ab_cw_crew_out", "CREW OUT", func() -> void:
			for m in machines:
				disembark(m)
			hud.toast("The crew climb out."), machines.any(func(u: Unit) -> bool: return crew_count(u) > 0), "Nobody aboard.", ""])
	var engines := own.filter(func(u: Unit) -> bool: return u.kind == "storm_engine")
	if not engines.is_empty():
		var sw := ""
		for e in engines:
			sw = storm_problem(e)
			if sw == "":
				break
		list.append(["ab_cw_thunder", "THUNDER", func() -> void:
			ctl.mode = "cwcast"
			hud.toast("Tap where the storm should break (up to %d px away)." % int(Defs.CW["storm"]["range"])), sw == "", sw, ""])
	var flyers := own.filter(func(u: Unit) -> bool: return u.kind == "ornithopter")
	if not flyers.is_empty() and game.units.any(func(u: Unit) -> bool: return u.kind == "carrier_car" and u.team == game.human and not u.dead):
		list.append(["ab_cw_dock", "DOCK", func() -> void:
			var best: Unit = null
			for c in game.units:
				if c.kind == "carrier_car" and c.team == game.human and not c.dead and deck_room(c) > 0:
					best = c
			if best == null:
				hud.toast("The Carrier Car's deck is full.")
				return
			hud.toast("%d Ornithopter(s) fly to the deck." % dock_order(flyers, best)), true, "", ""])
		var landed: bool = flyers.any(func(u: Unit) -> bool: return u.cw.has("landed"))
		list.append(["ab_cw_carry", "CARRY", func() -> void:
			var msg := ""
			for f in flyers:
				var r := carry_order(f)
				if r != "":
					msg = r
			hud.toast(msg if msg != "" else "A small unit climbs aboard."), landed, "Land on a Carrier Car first (DOCK).", ""])
		var loaded: bool = flyers.any(func(u: Unit) -> bool: return u.cw.has("cargo"))
		list.append(["ab_cw_drop", "DROP", func() -> void:
			ctl.mode = "cwdrop"
			hud.toast("Tap where to set it down."), loaded, "It carries nothing.", ""])


## Tooltips of the roster's buttons: label -> [title, body].
const TIPS := {
	"CREW OUT": ["Crew out", "Work Car: every Winder comes out and works (builds, mends, winds) near the car. Heavy Locomotive and Storm Engine: the Tin Militia aboard climb down."],
	"CREW IN": ["Crew in", "The Winders walk back aboard the car and wait there, safe."],
	"PLATES": ["Raise the plates", "Side plates go up for a few seconds: the gate widens and your units near the wagon take far less from ranged fire. Then they cool down."],
	"SET UP": ["Set up off the rails", "Drive off the Line (a few tiles at most) and set up on the ground. Without Tin Militia aboard it is helpless; with a full crew it works at reduced power."],
	"BOARD": ["Board", "The Tin Militia selected with the machine climb aboard as its crew. Aboard they are wound and safe."],
	"THUNDER": ["Thunder", "Raise a big thunderstorm at a spot in range: slow damage and slowed movement for the enemy inside. Then it recharges."],
	"DOCK": ["Dock", "The selected Ornithopters fly to the Carrier Car and land: they are healed, rewound and recharged there."],
	"CARRY": ["Carry", "A landed Ornithopter takes a small unit standing by the car aboard."],
	"DROP": ["Drop", "Fly to a spot and set the passenger down."],
}


## Map taps for the roster's targeted commands (Controls._tap). True if handled.
static func tap(ctl, game: Game, mode: String, units: Array, p: Vector2) -> bool:
	match mode:
		"cwsiding":
			var t := game.human
			var why: String = game.siding_order(t, game.cell_of(p))
			if why != "":
				game.notify(why)
			ctl.cancel_mode()
			return true
		"cwsetup":
			var why2 := ""
			for u in units:
				if (u.kind == "heavy_loco" or u.kind == "storm_engine") and u.team == game.human:
					var r := set_up_order(u, p + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
					if r != "":
						why2 = r
			if why2 != "":
				game.notify(why2)
			ctl.cancel_mode()
			return true
		"cwcast":
			var w := cast_order(units, p)
			if w != "":
				game.notify(w)
			ctl.cancel_mode()
			return true
		"cwdrop":
			for u in units:
				if u.kind == "ornithopter":
					var r2 := drop_order(u, p)
					if r2 != "":
						game.notify(r2)
			ctl.cancel_mode()
			return true
	return false
