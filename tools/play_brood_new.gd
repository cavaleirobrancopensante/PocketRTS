extends "res://tools/shot_ai_match.gd"
## Claude PLAYS THE NEW BROOD (docs/brood_new_play.md): a coached, filmed game. Side 0 is the new Brood, driven by the
## scripted plan below through the same commands a player uses (lay, root, uproot, haul, move, attack-move, harvest);
## side 1 is the normal computer. Everything of tools/shot_ai_match.gd (fight shots, the match log) plus:
##   <out>/coach.txt   every 30 s: food, essence, supply, the creatures, the Rootmaws' ground, the enemy seen
##   <out>/events.txt  the coach's decisions and what happened (time stamped)
##   <out>/mother_MMSS.png, <out>/<moment>_MMSS.png, <out>/clip_<moment>_NN.png (frames for a GIF: tools/play_brood_new_gif.py)
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_new.gd -- \
##       plan:standard b:crown map:greenhold seed:3 out:/abs/dir [end:900] [db:hard] [sb:balanced] [ai:1 (the computer plays the new Brood)]
## Plans: standard, warcamp, ninja, graze, ramp, tanks, flee, rexfight, best.
## Honest play: the coach knows the enemy's starting spot (a 2-player map) and sees only what its own creatures see.

var plan := "standard"
var sb := "balanced"             # the computer's strategy
var ai_plays := false            # ai:1 the computer plays the new Brood (side 0) too: only filmed
var _ct := 0.0
var _next_line := 30.0
var coach: Array = []
var events: Array = []
var _spots := {}                 # creature serial -> where it is walking to root
var _wave: Array = []
var _attacking := false
var _wave_sup := 0
var _attack_at := 24
var _foe := 1
var _last_kinds := {}
var _egg_kind := {}              # egg instance id -> the kind laid (an egg that hatched as a grub was wasted)
var wasted := 0
var _shots_t := {}               # moment -> last clock
var clips: Array = []            # [name, unit or Vector2, frames, step, zoom]
var _camp := ""                  # warcamp / flee: "" -> "walking" -> "rooted"
var _camp_at := Vector2.INF
var _ninja: Unit = null
var _ninja_at := Vector2.INF
var _ninja_maws: Array = []
var _refuge := Vector2.INF
var _ramp_mid := Vector2.INF
var _ramp_turtle: Unit = null
var _tanks: Array = []
var _fled := false
var _harvest_t := 0.0
var _hauls := 0
var _spills := 0
var _mother_shot := [90.0, 240.0, 420.0, 600.0, 780.0]
# ROUND 2 (0.15.12+: docs/brood_new_stages.md): the new levers, as options on any plan
var grow_on := false             # grow:1 GROW the Mother as soon as she can
var rex_mode := "home"           # rex:home keeps the Tyrannosaur by her; rex:out sends him with every wave
var turtle_mode := ""            # turtles:far2 sends 2 turtles 15+ tiles out (new ground); turtles:home keeps all by her
var sac_mode := ""               # sac:late offers idle grubs after 10:00 for essence (Brutes); sac:cycle runs the grub cycle 6:00-9:00
var mdef := ""                   # mdef:uproot: the Mother uproots to fight when enemies are at her (rooted, nothing attacks)
var _eggs_seen := 0              # (the Mother's held eggs a moment ago: a rise is an egg made)
var eggs_made := 0
var eggs_laid := 0
var _min_made: Array = []        # eggs made in each minute
var _min_laid: Array = []
var _snaps: Array = []
var _sac_n := 0
var _sac_ess := 0.0
var _far_turtles: Array = []
var _mi := 0


func _initialize() -> void:
	super._initialize()
	fa = Defs.BROOD_NEW
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"plan": plan = kv[1]
			"sb": sb = kv[1]
			"ai": ai_plays = kv[1] == "1"
			"grow": grow_on = kv[1] == "1"
			"rex": rex_mode = kv[1]
			"turtles": turtle_mode = kv[1]
			"sac": sac_mode = kv[1]
			"mdef": mdef = kv[1]
	if not Array(OS.get_cmdline_user_args()).any(func(x: String) -> bool: return x.begins_with("end:")):
		end_t = 900.0


func _process(delta: float) -> bool:
	if main.game == null:
		t += delta
		if t > 0.2:
			seed(seed_)
			main.start({"map": map, "seed": seed_, "slots": [
				{"who": da if ai_plays else "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0, "strategy": "balanced"},
				{"who": db, "faction": fb, "colour": 1, "side": 1, "strategy": sb}]})
		return false
	g = main.game
	if g.hud and g.hud.countdown > 0.0:
		g.hud.countdown = 0.0
	if paused:
		paused = false
	g.reveal = true          # (the camera sees everything; the coach only what its creatures see: Game.is_visible_to)
	if not g.over:
		_coach(delta)
	if not shooting and pending.is_empty() and not clips.is_empty():
		_clip_run()
	return super._process(delta)


# ------------------------------------------------------------------ helpers

func say(s: String) -> void:
	var l := "%s %s" % [_mmss(g.clock), s]
	events.append(l)
	print("EV " + l)


func mine(k: String) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and u.kind == k)


func army() -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.dead and not u.is_worker() \
		and not BroodNew.is_nb(u.kind) and u.kind != "horse")


func supply_of(list: Array) -> int:
	var s := 0
	for u in list:
		s += int(u.d["supply"])
	return s


func foe_start() -> Vector2:
	return (Vector2(g.starts[_foe]) + Vector2(2.5, 2.0)) * Defs.TILE


## Enemies my creatures can see (within `r` of `p`).
func seen_foes(p: Vector2, r: float) -> Array:
	var out: Array = []
	for u in g.units_near(p, r):
		if u.team >= 0 and g.hostile(u.team, 0) and not u.dead and not u.off_field and g.is_visible_to(0, u.position):
			out.append(u)
	return out


func foe_army_near(p: Vector2, r: float) -> Array:
	return seen_foes(p, r).filter(func(u: Unit) -> bool: return not u.is_worker())


func shot(name: String, at, zoom := 1.0, gap := 20.0) -> void:
	if g.clock - float(_shots_t.get(name, -999.0)) < gap:
		return
	_shots_t[name] = g.clock
	pending.append(["%s_%s.png" % [name, _mmss(g.clock)], at.position if at is Unit else at, zoom])


func clip(name: String, who, frames := 30, step := 4, zoom := 1.2) -> void:
	if _shots_t.has("clip_" + name):
		return
	_shots_t["clip_" + name] = g.clock
	clips.append([name, who, frames, step, zoom])


## Within `tiles` of a ramp: no rooting there (a rooted Rootmaw at the foot of the home ramp, game 9's first try, jammed
## the Tyrannosaur and the grubs on it for five minutes; only the ramp turtle roots on a ramp, on purpose).
func near_ramp(p: Vector2, tiles: int) -> bool:
	var c := g.cell_of(p)
	for dy in range(-tiles, tiles + 1):
		for dx in range(-tiles, tiles + 1):
			var n := c + Vector2i(dx, dy)
			if g.in_map(n) and g.ramp[g.idx(n)] != 0:
				return true
	return false


func on_map(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(Game.W, Game.H) * Defs.TILE).grow(-Defs.TILE).has_point(p)


func walk_spot_near(p: Vector2, home: int, tiles := 3.0) -> Vector2:
	for r in [0.0, tiles * 0.5, tiles, tiles * 1.5, tiles * 2.0]:
		for i in 16:
			var q: Vector2 = p + Vector2.from_angle(TAU * i / 16.0) * r * Defs.TILE
			var c := g.cell_of(q)
			if on_map(q) and g._walkable(c) and (home < 0 or g.region_of(c) == home):
				return q
	return p


# ------------------------------------------------------------------ the coach

var _qmode := ""


func _coach(delta: float) -> void:
	_ct -= delta
	_watch_eggs()
	var qq := BroodNew.queen(g, 0)
	if qq and qq.tesla_mode != _qmode:
		if _qmode != "":
			say("the Mother: %s -> %s (order %s, target %s, hp %d)" % [_qmode, qq.tesla_mode, qq.order, qq.target.kind if is_instance_valid(qq.target) else "-", int(qq.hp)])
		_qmode = qq.tesla_mode
	if qq:
		var e := int(qq.nb.get("eggs", 0))
		if e > _eggs_seen:
			eggs_made += e - _eggs_seen
			var m := int(g.clock / 60.0)
			while _min_made.size() <= m:
				_min_made.append(0)
			_min_made[m] += e - _eggs_seen
		_eggs_seen = e
	if g.clock >= _next_line:
		_next_line += 30.0
		_line()
		if int(g.clock) in [360, 600, 840]:
			_snap()
	if _ct > 0.0:
		return
	_ct = 0.5
	_watch_losses()
	var q := BroodNew.queen(g, 0)
	if q == null:
		return
	if _mi < _mother_shot.size() and g.clock >= _mother_shot[_mi]:
		_mi += 1
		pending.append(["mother_%s.png" % _mmss(g.clock), q.position + Vector2(0, -30), 0.75])
		var f := BroodNew.father(g, 0)
		if f and f.position.distance_to(q.position) > 6.0 * Defs.TILE:
			pending.append(["father_%s.png" % _mmss(g.clock), f.position + Vector2(0, -30), 1.2])
	if ai_plays:
		return
	match plan:
		"warcamp": _plan_warcamp(q)
		"ninja": _plan_ninja(q)
		"ramp": _plan_ramp(q)
		"flee": _plan_flee(q)
		"tanks": _plan_tanks(q)
		"best": _plan_best(q)
		"graze": _plan_graze(q)
	_mother(q)
	_grow(q)
	_mother_defends(q)
	_rootmaws(q)
	_turtles(q)
	_father(q)
	_sacrifice(q)
	_lay(q)
	_army(q)
	_harvest(q)


func _mother(q: Unit) -> void:
	if _camp == "walking":
		if q.tesla_mode == "deployed" and q.position.distance_to(_camp_at) > 80.0:
			# (a move order to the rooted Mother uproots her and walks on at once, as a player's click does; UPROOT
			# and then a move left her idle a moment, and an idle Mother with an enemy in reach roots again by herself)
			q.cmd_move(_camp_at)
		elif q.tesla_mode == "packed":
			if q.position.distance_to(_camp_at) < 50.0 or (q.order == "idle" and q.position.distance_to(_camp_at) < 160.0):
				q.cmd_deploy()
				_camp = "rooted"
				say("the Mother roots at her new spot (%d tiles from the enemy's start)" % int(q.position.distance_to(foe_start()) / Defs.TILE))
				shot("mother_rooted_again", q, 0.9, 0.0)
			elif q.order == "idle":
				q.cmd_move(_camp_at)
		return
	if q.tesla_mode == "packed" and q.order == "idle" and q.target == null:
		q.cmd_deploy()


## A spot for a Rootmaw on the swamp round `c` (in its region, not overlapping another's ground, not spent).
func maw_spot(c: Vector2, m: Unit, rings := [6.0, 8.0, 10.0, 12.0, 14.0, 17.0]):
	var home := g.region_of(g.cell_of(c))
	var best = null
	var bs := INF
	for ring in rings:
		for i in 16:
			var p: Vector2 = c + Vector2.from_angle(TAU * i / 16.0 + ring * 0.13) * ring * Defs.TILE
			var cc := g.cell_of(p)
			if not on_map(p) or not g._walkable(cc) or g.region_of(cc) != home or near_ramp(p, 4):
				continue
			if not _spot_ok(p, m) or not BroodNew.on_swamp(g, 0, p):
				continue
			var s := p.distance_to(c) + p.distance_to(m.position) * 0.3 - p.distance_to(foe_start()) * 0.1
			if s < bs:
				bs = s
				best = p
		if best != null:
			break
	return best


func _spot_ok(p: Vector2, me: Unit) -> bool:
	var r := float(Defs.PIT_CLAIM) * Defs.TILE * 2.0
	for o in g.units:
		if o != me and o.kind == BroodNew.MAW and not o.dead and o.tesla_mode != "packed" and o.position.distance_to(p) < r:
			return false
	for s in _spots:
		if int(s) != me.serial and (_spots[s] as Vector2).distance_to(p) < r:
			return false
	for id in g.nb_spots:
		var sp: Dictionary = g.nb_spots[id]
		if (sp["p"] as Vector2).distance_to(p) < r and float(sp["left"]) < 500.0:
			return false
	return true


func _rootmaws(q: Unit) -> void:
	for m in mine(BroodNew.MAW):
		var food := float(m.nb.get("food", 0.0))
		var left := BroodNew.ground_left(g, m)
		if m.tesla_mode == "deployed":
			var spent := left < 1.0
			# grazing (graze plan): the odd ones HAUL away the last of their food before the ground is quite done
			if plan == "graze" and m.serial % 2 == 1 and left < 60.0 and food > 80.0:
				BroodNew.uproot(m, false)
				_hauls += 1
				say("graze: Rootmaw #%d HAULS off its spent ground with %d food in it" % [m.serial, int(food)])
				clip("haul", m, 30, 4, 1.6)
				_spots.erase(m.serial)
				continue
			if spent and food < 1.0:
				BroodNew.uproot(m, true)
				_spills += 1
				say("Rootmaw #%d's ground is spent: UPROOT, off to fresh ground" % m.serial)
				_spots.erase(m.serial)
				continue
			# dry (its swamp gone): move it
			if bool(m.nb.get("dry", false)) and g.clock > 6.0:
				BroodNew.uproot(m, food < 40.0)
				say("Rootmaw #%d is dry (no swamp under it): %s" % [m.serial, "uproot" if food < 40.0 else "haul"])
				_spots.erase(m.serial)
			continue
		if m.tesla_mode != "packed":
			continue
		if _ninja_maws.has(m) and _ninja != null and is_instance_valid(_ninja) and not _ninja.dead:
			if not BroodNew.rooted(_ninja):
				continue
			var gl = _spots.get(m.serial)
			if gl == null:
				gl = maw_spot(_ninja.position, m, [5.0, 6.5, 8.0])
				if gl == null:
					continue
				_spots[m.serial] = gl
				m.cmd_move(gl)
				continue
			if m.position.distance_to(gl) < 40.0 or (m.order == "idle" and m.position.distance_to(gl) < 100.0):
				if BroodNew.root_problem(g, m) == "":
					m.cmd_deploy()
					say("ninja: a Rootmaw roots by the far turtle (%d tiles from the Mother)" % int(m.position.distance_to(q.position) / Defs.TILE))
				else:
					_spots.erase(m.serial)
			elif m.order == "idle":
				m.cmd_move(gl)
			continue
		if m.target != null:
			continue
		if _graze_watch.has(m.serial) and _spots.has(m.serial) and m.order == "idle" and m.position.distance_to(_spots[m.serial]) > 90.0:
			m.cmd_move(_spots[m.serial])
			continue
		var centre := q.position
		if _camp == "walking":
			continue          # (wait for the Mother to root)
		var goal = _spots.get(m.serial)
		if goal == null or not _spot_ok(goal, m):
			goal = maw_spot(centre, m)
			if goal == null:
				# any swamp of mine: a turtle's
				for tt in mine(BroodNew.TURTLE):
					if BroodNew.rooted(tt):
						goal = maw_spot(tt.position, m, [5.0, 7.0, 9.0])
						if goal != null:
							break
			if goal == null:
				continue
			_spots[m.serial] = goal
			m.cmd_move(goal)
			continue
		if m.position.distance_to(goal) < 40.0 or (m.order == "idle" and m.position.distance_to(goal) < 90.0):
			if BroodNew.root_problem(g, m) == "":
				m.cmd_deploy()
			else:
				_spots.erase(m.serial)
		elif m.order == "idle":
			m.cmd_move(goal)


func turtle_spot(q: Unit, me: Unit):
	var home := g.region_of(g.cell_of(q.position))
	var rings: Array = [16.0, 19.0, 13.0, 22.0] if plan in ["graze", "best"] else [12.0, 14.0, 9.0, 16.0, 18.0]
	if turtle_mode == "home":
		rings = [8.0, 10.0, 12.0, 6.0]       # (all at home: none on new ground, 15+ tiles out)
	for ring in rings:      # (at the edge of her swamp: each turtle widens it, room for Rootmaws)
		for i in 12:
			var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 12.0 + ring) * ring * Defs.TILE
			var c := g.cell_of(p)
			if not on_map(p) or not g._walkable(c) or g.region_of(c) != home or near_ramp(p, 4):
				continue
			var ok := true
			for o in g.units:
				if o != me and o.team == 0 and (o.kind == BroodNew.TURTLE or o.kind == BroodNew.MAW) and not o.dead and o.position.distance_to(p) < 4.0 * Defs.TILE:
					ok = false
					break
			for s in _spots:
				if int(s) != me.serial and (_spots[s] as Vector2).distance_to(p) < 4.0 * Defs.TILE:
					ok = false
			if ok:
				return p
	return null


func _turtles(q: Unit) -> void:
	for tt in mine(BroodNew.TURTLE):
		if tt == _ninja or tt == _ramp_turtle or _tanks.has(tt):
			continue
		if tt.tesla_mode != "packed" or tt.target != null:
			continue
		var goal = _spots.get(tt.serial)
		if goal == null and _camp == "walking":
			continue          # (following her: _plan_warcamp)
		if goal == null:
			# the next jobs first: the ninja base, the ramp, the tanks
			if _want_ninja() and _ninja == null:
				_ninja = tt
				_ninja_at = _far_spot(q)
				tt.cmd_move(_ninja_at)
				say("ninja: a Mound Turtle sets off for a far spot %d tiles away (%d from the enemy)" % [int(_ninja_at.distance_to(q.position) / Defs.TILE), int(_ninja_at.distance_to(foe_start()) / Defs.TILE)])
				continue
			if _want_ramp() and _ramp_turtle == null and _ramp_mid != Vector2.INF:
				_ramp_turtle = tt
				tt.cmd_move(_ramp_mid)
				say("ramp: a Mound Turtle walks to the ramp to close it")
				continue
			if turtle_mode == "far2" and _far_turtles.size() < 2 and g.clock > 150.0:
				var fs := _new_ground_spot(q)
				if fs != Vector2.INF:
					_far_turtles.append(tt)
					_spots[tt.serial] = fs
					tt.cmd_move(fs)
					say("new ground: a Mound Turtle walks to a spot %d tiles from the Mother (far turtle %d of 2)" % [int(fs.distance_to(q.position) / Defs.TILE), _far_turtles.size()])
					continue
			if _want_tank():
				_tanks.append(tt)
				say("tanks: a Mound Turtle joins the army as a tank (%d now)" % _tanks.size())
				continue
			goal = turtle_spot(q, tt)
			if goal == null:
				continue
			_spots[tt.serial] = goal
			tt.cmd_move(goal)
			continue
		if tt.position.distance_to(goal) < 40.0 or tt.order == "idle":
			tt.cmd_deploy()
			_spots.erase(tt.serial)
	# the ninja turtle and the ramp turtle root when they arrive
	if _ninja != null and is_instance_valid(_ninja) and not _ninja.dead and _ninja.tesla_mode == "packed":
		if _ninja.position.distance_to(_ninja_at) < 50.0 or _ninja.order == "idle":
			_ninja.cmd_deploy()
			say("ninja: the far turtle roots (%d tiles from the Mother); its swamp spreads" % int(_ninja.position.distance_to(q.position) / Defs.TILE))
			shot("ninja_base", _ninja, 0.9, 0.0)
	if _ramp_turtle != null and is_instance_valid(_ramp_turtle) and not _ramp_turtle.dead and _ramp_turtle.tesla_mode == "packed" and not _ramp_open:
		if _ramp_turtle.position.distance_to(_ramp_mid) < 30.0 or _ramp_turtle.order == "idle":
			_ramp_turtle.cmd_deploy()
			say("ramp: the turtle roots on the ramp (%d px from its middle)" % int(_ramp_turtle.position.distance_to(_ramp_mid)))
			shot("ramp_wall", _ramp_turtle, 1.1, 0.0)


func _father(q: Unit) -> void:
	var f := BroodNew.father(g, 0)
	if f == null or _wave.has(f):
		return
	var d := f.position.distance_to(q.position)
	if d > 14.0 * Defs.TILE and f.order != "move":
		f.cmd_move(q.position)
		return
	if f.target != null:
		return
	if d > float(Defs.NB["father_r"]) * Defs.TILE * 0.6 and (f.order == "idle" or f.order == "hold"):
		var home := g.region_of(g.cell_of(q.position))
		var best := Vector2.INF
		for i in 12:
			var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 12.0) * (q.radius + f.radius + 24.0)
			var c := g.cell_of(p)
			if on_map(p) and g._walkable(c) and g.region_of(c) == home and (best == Vector2.INF or p.distance_to(f.position) < best.distance_to(f.position)):
				best = p
		if best != Vector2.INF:
			f.cmd_move(best)


func _short() -> bool:
	var cap := int(g.players[0]["cap"])
	if cap >= g.max_supply(0):
		return false
	var coming := 0
	for u in g.units:
		if u.team == 0 and not u.dead and ((u.kind == BroodNew.TURTLE and u.tesla_mode != "deployed" and u != _ninja and not _tanks.has(u)) \
				or (u.kind == BroodNew.EGG and String(u.nb.get("k", "")) == BroodNew.TURTLE)):
			coming += int(Defs.NB["turtle_supply"])
	return g.supply_used(0) + 6 + int(g.clock / 40.0) >= cap + coming


func _want_maws() -> int:
	for m in mine(BroodNew.MAW):
		if m.tesla_mode == "packed" and m.order == "idle" and not _spots.has(m.serial) and not _ninja_maws.has(m):
			return 0          # (one is already waiting for room on the swamp)
	var n := mini(2 + int(g.clock / 90.0), 7)
	if plan in ["graze", "best"]:
		n = mini(3 + int(g.clock / 70.0), 9)
	return n + _ninja_maws.size()


func _want_ninja() -> bool:
	return plan in ["ninja", "best"] and g.clock > 120.0


func _want_ramp() -> bool:
	return plan == "ramp" or (plan == "best" and g.clock < 200.0)


func _want_tank() -> bool:
	return plan == "tanks" and _tanks.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead).size() < 3 and g.clock > 200.0


func _lay(q: Unit) -> void:
	if int(q.nb.get("eggs", 0)) <= 0:
		return
	var gold := int(g.players[0]["gold"])
	var grubs := BroodNew.count_of(g, 0, "grub")
	var maws := BroodNew.count_of(g, 0, BroodNew.MAW)
	var crew := 0
	for m in mine(BroodNew.MAW):
		if BroodNew.rooted(m):
			crew += BroodNew.crew_max(g, m)
	var want_grubs := mini(maxi(crew, 6) + 1, 36)
	var k := ""
	var turtles := BroodNew.count_of(g, 0, BroodNew.TURTLE)
	if _want_ramp() and _ramp_turtle == null and turtles == 0 and _ramp_mid != Vector2.INF:
		k = BroodNew.TURTLE
	elif _want_ninja() and _ninja == null and turtles <= _turtle_jobs() + _supply_turtles_walking():
		k = BroodNew.TURTLE
	elif _want_ninja() and _ninja != null and _ninja_maws.size() + _pending_ninja_maw < 2 and BroodNew.rooted(_ninja):
		k = BroodNew.MAW
	elif sac_mode == "cycle" and g.clock >= 360.0 and g.clock < 540.0:
		k = "grub"            # (the grub cycle: lay a grub, offer it back for an egg and essence, lay again)
	elif turtle_mode == "far2" and _far_turtles.size() < 2 and g.clock > 150.0 and _supply_turtles_walking() == 0:
		k = BroodNew.TURTLE
	elif _want_tank() and turtles <= _turtle_jobs() and BroodNew.count_of(g, 0, BroodNew.EGG) < 3 and gold >= 150:
		k = BroodNew.TURTLE
	elif _short():
		k = BroodNew.TURTLE
	elif BroodNew.count_of(g, 0, BroodNew.FATHER) == 0 and (grubs >= 8 or g.clock > 75.0) and maws >= 2:
		k = BroodNew.FATHER
	elif maws < _want_maws() and (grubs >= maws * 5 or maws < 2):
		k = BroodNew.MAW          # (saved up for: the economy first)
	elif grubs < want_grubs:
		k = "grub"
	elif _camp == "walking":
		k = BroodNew.TURTLE if _walking_turtles() < 2 else ""
	elif BroodNew.father_near(g, 0):
		var ess := float(g.players[0]["res2"])
		if ess >= 25.0 and gold >= 100 and randi() % 4 == 0:
			k = "mist_toad"
		elif ess >= 20.0 and gold >= 150:
			k = "brute"
		else:
			k = "raptor"
	_why_k = "%s: %s" % [k, BroodNew.lay_problem(g, q, k) if k != "" else "nothing wanted"]
	if k == "" or BroodNew.lay_problem(g, q, k) != "":
		if k in [BroodNew.FATHER, BroodNew.MAW, BroodNew.TURTLE, "brute"]:
			return
		if k != "grub" and grubs < want_grubs and BroodNew.lay_problem(g, q, "grub") == "":
			k = "grub"
		else:
			return
	if BroodNew.lay(g, q, k) == "":
		eggs_laid += 1
		_eggs_seen = int(q.nb.get("eggs", 0))
		var mm := int(g.clock / 60.0)
		while _min_laid.size() <= mm:
			_min_laid.append(0)
		_min_laid[mm] += 1
		var e: Unit = null
		for i in range(g.units.size() - 1, maxi(-1, g.units.size() - 6), -1):
			if g.units[i].kind == BroodNew.EGG and g.units[i].team == 0:
				e = g.units[i]
				break
		if e:
			_egg_kind[e.get_instance_id()] = [k, e]
		if k == BroodNew.MAW and _want_ninja() and _ninja != null and _ninja_maws.size() + _pending_ninja_maw < 2 and BroodNew.rooted(_ninja):
			_pending_ninja_maw += 1
		if q.tesla_mode == "packed" and _camp == "walking":
			clip("laying_walking", q, 30, 3, 1.4)


var _pending_ninja_maw := 0
var _why_k := ""


func _walking_turtles() -> int:
	var n := BroodNew.count_of(g, 0, BroodNew.TURTLE) - mine(BroodNew.TURTLE).size()
	for tt in mine(BroodNew.TURTLE):
		if tt.tesla_mode == "packed" and not _spots.has(tt.serial):
			n += 1
	return n


func _supply_turtles_walking() -> int:
	var n := BroodNew.count_of(g, 0, BroodNew.TURTLE) - mine(BroodNew.TURTLE).size()      # (in eggs)
	for tt in mine(BroodNew.TURTLE):
		if tt.tesla_mode == "packed" and tt != _ninja and tt != _ramp_turtle and not _tanks.has(tt):
			n += 1
	return n


## Turtles that have a job other than supply.
func _turtle_jobs() -> int:
	var n := 0
	for x in [_ninja, _ramp_turtle]:
		if x != null and is_instance_valid(x) and not x.dead:
			n += 1
	for x in _tanks:
		if is_instance_valid(x) and not x.dead:
			n += 1
	return n


func _watch_eggs() -> void:
	for id in _egg_kind.keys():
		var pair: Array = _egg_kind[id]
		var e = pair[1]
		if not is_instance_valid(e) or e.dead or e.nb.has("out"):
			if is_instance_valid(e) and e.nb.has("out") and String(e.nb.get("k", "")) == "grub" and String(pair[0]) != "grub":
				wasted += 1
				say("a %s egg was never fertilised: it hatched as a grub" % pair[0])
			_egg_kind.erase(id)
			continue
		if String(e.nb.get("k", "")) == "grub" and String(pair[0]) != "grub" and not e.nb.has("_w"):
			e.nb["_w"] = true
			wasted += 1
			say("a %s egg was not fertilised in 25 s: it turns into a grub egg" % pair[0])
			_egg_kind.erase(id)
	# new Rootmaws from eggs: the ninja's
	if _pending_ninja_maw > 0:
		for m in mine(BroodNew.MAW):
			if m.tesla_mode == "packed" and not _ninja_maws.has(m) and not _spots.has(m.serial) and g.clock - float(m.get_meta("born", g.clock)) < 2.0:
				_ninja_maws.append(m)
				_pending_ninja_maw -= 1
				say("ninja: a new Rootmaw is sent to the far turtle")
				# and grubs go with it: a crew of the new Rootmaw's (they gather there once it roots)
				break
	for m in mine(BroodNew.MAW):
		if not m.has_meta("born"):
			m.set_meta("born", g.clock)


func _army(q: Unit) -> void:
	var arm := army()
	var f := BroodNew.father(g, 0)
	var threat := foe_army_near(q.position, 14.0 * Defs.TILE)
	if threat.size() > 0:
		var defenders := arm.duplicate()
		if f:
			defenders.append(f)
		for u in defenders:
			if u.target == null and (u.order == "idle" or u in _wave):
				u.cmd_move(threat[0].position, true)
		if threat.size() >= 3:
			shot("defence", threat[0].position, 1.1, 30.0)
		return
	var sup := supply_of(arm)
	if _attacking:
		_wave = _wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		var left := supply_of(_wave.filter(func(u) -> bool: return u.kind != BroodNew.FATHER))
		if left * 2 < _wave_sup:
			_attacking = false
			say("the wave is cut down (%d of %d supply left): back to the Mother" % [left, _wave_sup])
			for u in _wave:
				u.cmd_move(q.position + Vector2(0, q.radius + 40.0))
			_wave.clear()
			_attack_at += 8
			return
		for u in _wave:
			if u.order == "idle" and u.target == null:
				u.cmd_move(foe_start(), true)
		# (new hatchlings do not trickle after the wave one by one: they wait by the Mother for the next one; game 1 did
		# trickle, and lost 300 Raptors to a walled Crown)
		var home := q.position + Vector2(0, q.radius + 60.0)
		for u in arm:
			if not _wave.has(u) and u.order == "idle" and u.target == null and u.position.distance_to(home) > 200.0:
				u.cmd_move(home)
		if f and not _wave.has(f) and _rex_fights():
			_wave.append(f)
			f.cmd_move(foe_start(), true)
		return
	if sup >= _attack_at and _camp != "walking":
		_wave = arm.duplicate()
		_wave_sup = sup
		_attacking = true
		if f and _rex_fights():
			_wave.append(f)
		for u in _wave:
			u.cmd_move(foe_start(), true)
		say("attack: %d supply (%s)%s" % [sup, _kinds(arm), ", the Tyrannosaur leads it" if f and _rex_fights() else ""])
		if not arm.is_empty():
			_later.append([g.clock + 6.0, "wave_%s.png" % _mmss(g.clock), arm[0]])
	else:
		var spot := q.position + Vector2(0, q.radius + 60.0)
		for u in arm:
			if u.order == "idle" and u.target == null and u.position.distance_to(spot) > 200.0:
				u.cmd_move(spot)


func _rex_fights() -> bool:
	return plan == "rexfight" or rex_mode == "out"


# ------------------------------------------------------------------ round 2: GROW, SACRIFICE, the Mother's own defence

var _bn: GDScript = load("res://scripts/brood_new.gd")


func _bn_has(f: String) -> bool:
	for m in _bn.get_script_method_list():
		if m["name"] == f:
			return true
	return false


func _stage(q: Unit) -> int:
	return int(q.nb.get("stage", 1))


## GROW: whatever the build calls it (a button on her card): Unit.cmd_grow, else BroodNew.grow.
func _grow(q: Unit) -> void:
	if not grow_on or q.nb.get("growing", false) or not BroodNew.rooted(q):
		return
	var why := ""
	if q.has_method("grow_problem"):
		why = q.grow_problem()
	elif _bn_has("grow_problem"):
		why = _bn.call("grow_problem", g, q)
	else:
		return
	if why != "":
		return
	var st := _stage(q)
	if q.has_method("cmd_grow"):
		q.cmd_grow()
	else:
		_bn.call("grow", g, q)
	say("GROW: the Mother starts growing from stage %d (food %d)" % [st, int(g.players[0]["gold"])])
	shot("grow", q, 0.8, 0.0)


var _last_stage := 1


func _stage_watch(q: Unit) -> void:
	if _stage(q) != _last_stage:
		_last_stage = _stage(q)
		say("the Mother is now stage %d" % _last_stage)
		shot("stage%d" % _last_stage, q, 0.7, 0.0)


## With mdef:uproot the Mother uproots and fights what is at her (rooted, she can't attack); back to her nest after.
var _mfight := false


func _mother_defends(q: Unit) -> void:
	_stage_watch(q)
	if mdef != "uproot" or _camp == "walking":
		return
	var foes := foe_army_near(q.position, 6.0 * Defs.TILE)
	if foes.size() >= 2 and not _mfight:
		_mfight = true
		_mhome = q.position
		q.cmd_move(foes[0].position, true)
		say("the Mother uproots to fight (%d enemies within 6 tiles, %d hp)" % [foes.size(), int(q.hp)])
		clip("mother_fights", q, 30, 4, 1.1)
	elif _mfight and foes.is_empty() and seen_foes(q.position, 10.0 * Defs.TILE).is_empty():
		_mfight = false
		q.cmd_move(_mhome)
		say("the fight at the Mother is over (%d hp): back to her nest" % int(q.hp))
	elif _mfight and q.order == "idle" and q.tesla_mode == "packed" and not foes.is_empty():
		q.cmd_move(foes[0].position, true)


var _mhome := Vector2.ZERO


## SACRIFICE (each one gives the Mother 1 egg and essence): sac:late offers spare grubs after 10:00, sac:cycle runs the
## grub cycle (lay a grub, offer it back, lay again) from 6:00 to 9:00 to measure what it gives.
func _sacrifice(q: Unit) -> void:
	if sac_mode == "":
		return
	var cyc := sac_mode == "cycle" and g.clock >= 360.0 and g.clock < 540.0
	var late := sac_mode == "late" and g.clock >= 600.0
	if not cyc and not late:
		return
	var crew := 0
	for m in mine(BroodNew.MAW):
		if BroodNew.rooted(m):
			crew += BroodNew.crew_max(g, m)
	var grubs := mine("grub")
	var spare := grubs.size() - (crew + 2 if late else crew)
	var going := grubs.filter(func(u: Unit) -> bool: return u.order == "sacrifice").size()
	for gr in grubs:
		if spare - going <= 0:
			break
		if gr.order != "sacrifice" and gr.carrying == 0 and gr.can_sacrifice():
			gr.cmd_sacrifice()
			going += 1
	if cyc:
		# idle grubs that hatched from the cycle go straight back
		for gr in grubs:
			if gr.order == "idle" and gr.can_sacrifice():
				gr.cmd_sacrifice()


func _snap() -> void:
	var q := BroodNew.queen(g, 0)
	var arm := army()
	var val := 0
	for u in arm:
		val += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
	var m := int(g.clock / 60.0) - 1
	var made := int(_min_made[m]) if m < _min_made.size() else 0
	var laid := int(_min_laid[m]) if m < _min_laid.size() else 0
	_snaps.append("SNAP %s stage %d | eggs made last minute %d, laid %d (all game %d made, %d laid) | food unspent %d, essence %d | army supply %d value %d | earned %d | egg rate x%.2f | sacrificed %d (+%d essence)" % [_mmss(g.clock), _stage(q) if q else 0, made, laid, eggs_made, eggs_laid,
		int(g.players[0]["gold"]), int(g.players[0]["res2"]), supply_of(arm), val, int(g.stats[0].get("gold", 0)), BroodNew.egg_rate(g, 0), int(g.stats[0].get("sacrificed", 0)), int(g.stats[0].get("sacrifice_essence", 0))])
	say(_snaps[-1])


## After fights near home, two grubs harvest the bodies (essence for Brutes and Mist Toads).
var _to_harvest := {}


func _harvest(q: Unit) -> void:
	for gr in _to_harvest.keys():
		if not is_instance_valid(gr) or gr.dead or gr.order != "move":
			if is_instance_valid(gr) and not gr.dead and gr.order == "idle":
				gr.cmd_harvest()      # (arrived: HARVEST round here)
			_to_harvest.erase(gr)
	if g.clock < _harvest_t:
		return
	_harvest_t = g.clock + 15.0
	var near: Array = g.corpses.filter(func(c) -> bool: return is_instance_valid(c) and c.position.distance_to(q.position) < 20.0 * Defs.TILE)
	if near.size() < 3:
		return
	var busy := mine("grub").filter(func(u: Unit) -> bool: return u.order == "harvest").size()
	if busy >= 2:
		return
	for gr in mine("grub"):
		if gr.carrying == 0 and gr.order == "gather" and not _to_harvest.has(gr):
			gr.cmd_move(near[0].position)
			_to_harvest[gr] = near[0].position
			busy += 1
			if busy >= 2:
				break
	say("two grubs go to harvest %d bodies for essence" % near.size())


# ------------------------------------------------------------------ the plans

## (2) The Mother walks forward with the army as a moving war camp, the Tyrannosaur beside her.
func _plan_warcamp(q: Unit) -> void:
	if _camp == "" and g.clock > 330.0 and supply_of(army()) >= 14:
		_camp = "walking"
		var to := foe_start()
		var path := g.find_path(q.position, to)
		var at := q.position.lerp(to, 0.6)
		if path.size() > 2:
			# along the path, to where some 34 tiles of it are left to the enemy's start (game 2's first try went 92
			# tiles, to 16 from their start: a three-minute march, and she died there)
			var total := 0.0
			for i in range(1, path.size()):
				total += path[i].distance_to(path[i - 1])
			var acc := 0.0
			var stop := maxf(total * 0.5, total - 34.0 * Defs.TILE)
			for i in range(1, path.size()):
				var seg := path[i].distance_to(path[i - 1])
				if acc + seg >= stop:
					at = path[i - 1].lerp(path[i], (stop - acc) / maxf(seg, 1.0))
					break
				acc += seg
		_camp_at = walk_spot_near(at, g.region_of(g.cell_of(q.position)))
		say("warcamp: the Mother uproots and walks %d tiles toward the enemy with the army and the Tyrannosaur" % int(q.position.distance_to(_camp_at) / Defs.TILE))
		clip("warcamp_march", q, 30, 6, 0.9)
	if _camp == "walking":
		# the army walks round her (a step ahead, toward the enemy), the father beside her
		var ahead := q.position + (_camp_at - q.position).normalized() * 110.0
		for u in army():
			if u.target == null and u.position.distance_to(ahead) > 160.0 and (u.order == "idle" or u.position.distance_to(u.path_goal) < 60.0):
				u.cmd_move(ahead + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
		# the turtles laid on the march follow her, to root by her at the front
		for tt in mine(BroodNew.TURTLE):
			if tt.tesla_mode == "packed" and not _spots.has(tt.serial) and tt.order == "idle" and tt.position.distance_to(q.position) > 120.0 and not _tanks.has(tt) and tt != _ninja:
				tt.cmd_move(q.position)
	if _camp == "rooted" and not _shots_t.has("warcamp_front"):
		shot("warcamp_front", q, 0.8, 0.0)


## (4) Grazing: full Rootmaws near the Mother are HAULED out to fresh ground farther away (the farther, the more a trip
## pays, and the bigger the crew); one is UPROOTED instead, spilling its food, to compare.
var _graze_at := [360.0, 450.0, 540.0, 630.0, 720.0]
var _graze_i := 0
var _graze_watch := {}       # serial -> [clock moved, pay per trip before, how]


func _plan_graze(q: Unit) -> void:
	for sid in _graze_watch.keys():
		var w: Array = _graze_watch[sid]
		for m in mine(BroodNew.MAW):
			if m.serial == int(sid) and BroodNew.rooted(m) and w.size() == 3:
				w.append(g.clock)
				say("graze: Rootmaw #%d (%s) rooted again after %d s: %d food kept, a trip now pays %.1f (was %.1f), crew %d" % [m.serial, w[2], int(g.clock - float(w[0])), int(m.nb.get("food", 0.0)), BroodNew.load_value(g, m, 0), float(w[1]), BroodNew.crew_max(g, m)])
				shot("graze_rooted", m, 1.2, 0.0)
	if _graze_i >= _graze_at.size() or g.clock < float(_graze_at[_graze_i]):
		return
	var best: Unit = null
	for m in mine(BroodNew.MAW):
		if BroodNew.rooted(m) and float(m.nb.get("food", 0.0)) >= 150.0 and not _graze_watch.has(m.serial) and (best == null or m.position.distance_to(q.position) < best.position.distance_to(q.position)):
			best = m
	if best == null:
		return
	var to = maw_spot(q.position, best, [17.0, 19.0, 21.0, 23.0, 15.0])
	if to == null or (to as Vector2).distance_to(q.position) < best.position.distance_to(q.position) + 3.0 * Defs.TILE:
		_graze_at[_graze_i] = g.clock + 30.0       # (no fresh swamp farther out yet: a turtle must spread it first)
		return
	var spill := _graze_i == _graze_at.size() - 1
	var pay := BroodNew.load_value(g, best, 0)
	say("graze: Rootmaw #%d (%d tiles out, %d food in it, a trip pays %.1f) %s to fresh ground %d tiles out" % [best.serial, int(best.position.distance_to(q.position) / Defs.TILE), int(best.nb.get("food", 0.0)), pay, "UPROOTS (spilling its food) and walks" if spill else "is HAULED", int((to as Vector2).distance_to(q.position) / Defs.TILE)])
	_graze_watch[best.serial] = [g.clock, pay, "uproot" if spill else "haul"]
	BroodNew.uproot(best, spill)
	if spill:
		_spills += 1
	else:
		_hauls += 1
	_spots[best.serial] = to
	clip("graze_" + ("uproot" if spill else "haul"), best, 30, 5, 1.3)
	_graze_i += 1


## NEW GROUND for a turtle (round 2): 16 to 24 tiles from the Mother and 15+ from the other far turtles, walkable in her
## region, off ramps, on our side of the map.
func _new_ground_spot(q: Unit) -> Vector2:
	var home := g.region_of(g.cell_of(q.position))
	var best := Vector2.INF
	var bs := -INF
	var foe := foe_start()
	for y in range(3, Game.H - 3, 2):
		for x in range(3, Game.W - 3, 2):
			var c := Vector2i(x, y)
			if not g._walkable(c) or g.region_of(c) != home:
				continue
			var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
			var dq := p.distance_to(q.position) / Defs.TILE
			if dq < 16.0 or dq > 24.0 or p.distance_to(foe) < q.position.distance_to(foe) * 0.75 or near_ramp(p, 3):
				continue
			var ok := true
			for o in _far_turtles:
				if is_instance_valid(o) and not o.dead and (_spots.get(o.serial, o.position) as Vector2).distance_to(p) < 15.0 * Defs.TILE:
					ok = false
			if not ok:
				continue
			var room := 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if g._walkable(c + Vector2i(dx, dy)):
						room += 1
			if room < 22:
				continue
			var sc := p.distance_to(foe) / Defs.TILE - dq * 0.5 + randf()
			if sc > bs:
				bs = sc
				best = p
	return best


## (3) A lone Mound Turtle sent far away with Rootmaws: a hidden base.
func _far_spot(q: Unit) -> Vector2:
	var home := g.region_of(g.cell_of(q.position))
	var best := q.position
	var bs := -INF
	var foe := foe_start()
	var mine_d := q.position.distance_to(foe)
	for y in range(4, Game.H - 4, 3):
		for x in range(4, Game.W - 4, 3):
			var c := Vector2i(x, y)
			if not g._walkable(c) or g.region_of(c) != home or g.ramp[g.idx(c)] != 0:
				continue
			var p := (Vector2(c) + Vector2(0.5, 0.5)) * Defs.TILE
			var dq := p.distance_to(q.position) / Defs.TILE
			var df := p.distance_to(foe) / Defs.TILE
			if dq < 26.0 or dq > 48.0 or df < mine_d / Defs.TILE * 0.7:
				continue
			# room: the cells round it walkable
			var room := 0
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var c2 := c + Vector2i(dx, dy)
					if g.in_map(c2) and g._walkable(c2):
						room += 1
			if room < 44:
				continue
			var s := df - dq * 0.3 + randf() * 2.0
			if s > bs:
				bs = s
				best = p
	return best


func _plan_ninja(_q: Unit) -> void:
	if _ninja != null and is_instance_valid(_ninja) and not _ninja.dead and BroodNew.rooted(_ninja):
		var rooted := _ninja_maws.filter(func(m) -> bool: return is_instance_valid(m) and not m.dead and BroodNew.rooted(m))
		for m in rooted:
			var c := BroodNew.crew(g, m)
			if c < 4:
				var sent := 0
				for gr in mine("grub"):
					if gr.order == "gather" and gr.carrying == 0 and gr.home_mine != m and not _ninja_maws.has(gr.home_mine):
						gr.cmd_gather(m)
						sent += 1
						if sent >= 5 - c:
							break
				if sent > 0:
					say("ninja: %d grubs sent on the long trip to a far Rootmaw (each trip pays %.1f there, %.1f at home)" % [sent, BroodNew.load_value(g, m, 0), _home_load()])
		if rooted.size() > 0 and not _shots_t.has("clip_ninja_grubs"):
			clip("ninja_grubs", rooted[0], 30, 6, 1.0)
	if _ninja != null and (not is_instance_valid(_ninja) or _ninja.dead) and not _shots_t.has("ninja_lost"):
		_shots_t["ninja_lost"] = g.clock
		say("ninja: the far turtle is dead: its swamp shrinks")


func _home_load() -> float:
	for m in mine(BroodNew.MAW):
		if BroodNew.rooted(m) and not _ninja_maws.has(m):
			return BroodNew.load_value(g, m, 0)
	return 0.0


## (5) A turtle rooted on the ramp as a wall.
var _ramp_open := false


func _plan_ramp(q: Unit) -> void:
	if _ramp_mid == Vector2.INF:
		_ramp_mid = _find_ramp_mid(q.position)
		say("ramp: my ramp's middle is %d tiles from the Mother" % int(_ramp_mid.distance_to(q.position) / Defs.TILE) if _ramp_mid != Vector2.INF else "ramp: no ramp found")
	# the army wants out: the turtle uproots to let it through? No: its own side climbs over the shell.
	if _ramp_turtle != null and is_instance_valid(_ramp_turtle) and not _ramp_turtle.dead and BroodNew.rooted(_ramp_turtle):
		var at := foe_army_near(_ramp_turtle.position, 8.0 * Defs.TILE)
		if at.size() >= 3:
			shot("ramp_held", _ramp_turtle, 1.1, 25.0)
			clip("ramp_held", _ramp_turtle, 30, 4, 1.2)


func _find_ramp_mid(home: Vector2) -> Vector2:
	var hc := g.cell_of(home)
	var h0 := int(g.height[g.idx(hc)])
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hc.y - 32, hc.y + 33):
		for x in range(hc.x - 32, hc.x + 33):
			var r := Vector2i(x, y)
			if not g.in_map(r) or g.ramp[g.idx(r)] == 0:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = r + dd
				if g.in_map(p) and g.ramp[g.idx(p)] == 0 and int(g.height[g.idx(p)]) == h0 and g._walkable(p):
					var d := Vector2(p).distance_to(Vector2(hc))
					if d < bd:
						bd = d
						best = r
	if best.x < 0:
		return Vector2.INF
	var cells: Array = [best]
	var seen := {best: true}
	var ki := 0
	while ki < cells.size():
		var c: Vector2i = cells[ki]
		ki += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if g.in_map(n) and not seen.has(n) and g.ramp[g.idx(n)] != 0:
				seen[n] = true
				cells.append(n)
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-1, -1)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return (Vector2(lo + hi) * 0.5 + Vector2(0.5, 0.5)) * Defs.TILE


## (6) Turtles as tanks: they walk in front of the wave and root when the enemy is close.
func _plan_tanks(_q: Unit) -> void:
	_tanks = _tanks.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead)
	for tt in _tanks:
		var foes := foe_army_near(tt.position, 6.0 * Defs.TILE)
		if tt.tesla_mode == "packed":
			if foes.size() >= 2 and tt.order != "deploy":
				tt.cmd_deploy()
				say("tanks: a turtle roots in the fight (%d enemies within 6 tiles)" % foes.size())
				clip("tank_rooted", tt, 30, 4, 1.2)
			elif _attacking and tt.order == "idle":
				# lead the wave: a little ahead of its middle
				var mid := Vector2.ZERO
				var n := 0
				for u in _wave:
					if is_instance_valid(u) and not u.dead and u.kind != BroodNew.TURTLE:
						mid += u.position
						n += 1
				if n > 0:
					mid /= n
					tt.cmd_move(mid + (foe_start() - mid).normalized() * 90.0)
			elif not _attacking and tt.order == "idle" and tt.position.distance_to(BroodNew.queen(g, 0).position) > 300.0:
				tt.cmd_move(BroodNew.queen(g, 0).position + Vector2(randf_range(-150, 150), 160))
		elif tt.tesla_mode == "deployed" and foes.is_empty() and seen_foes(tt.position, 9.0 * Defs.TILE).is_empty():
			tt.cmd_pack()
			say("tanks: the fight is over there: the turtle uproots")


## (7) A refuge far away (a turtle and its Rootmaws); when the Mother's fight is lost, she uproots and runs there.
func _plan_flee(q: Unit) -> void:
	if _refuge == Vector2.INF:
		_refuge = q.position        # (home: the turtles and Rootmaws stay rooted there)
	if not _fled:
		_plan_warcamp(q)
	else:
		if _camp == "rooted" and not _shots_t.has("fled_home"):
			_shots_t["fled_home"] = g.clock
			say("flee: the Mother is rooted at home again, %d hp" % int(q.hp))
			shot("flee_home", q, 0.9, 0.0)
		return
	if _camp != "rooted":
		return
	var foes := foe_army_near(q.position, 12.0 * Defs.TILE)
	var mine_n := army().filter(func(u: Unit) -> bool: return u.position.distance_to(q.position) < 12.0 * Defs.TILE).size()
	if q.hp < q.max_hp * 0.7 and foes.size() > mine_n:
		_fled = true
		_camp = "walking"
		_camp_at = walk_spot_near(_refuge, g.region_of(g.cell_of(q.position)))
		say("flee: the war camp's fight is lost (%d hp, %d enemies v %d of mine near her): she UPROOTS and runs %d tiles home" % [int(q.hp), foes.size(), mine_n, int(q.position.distance_to(_camp_at) / Defs.TILE)])
		clip("flee", q, 40, 6, 0.9)
		_attacking = false
		_wave.clear()
		var f := BroodNew.father(g, 0)
		if f:
			f.cmd_move(_camp_at)
		for u in army():
			u.cmd_move(q.position + (_camp_at - q.position).normalized() * 60.0)
		# the Rootmaws by her at the front HAUL their food home
		for m in mine(BroodNew.MAW):
			if BroodNew.rooted(m) and m.position.distance_to(q.position) < 20.0 * Defs.TILE:
				BroodNew.uproot(m, false)
				_hauls += 1
				_spots.erase(m.serial)


## (9) The best of what was learned (set after games 1 to 8: see docs/brood_new_play.md).
func _plan_best(q: Unit) -> void:
	_plan_ramp(q)
	_plan_ninja(q)
	_plan_graze(q)
	if _ramp_turtle != null and is_instance_valid(_ramp_turtle) and BroodNew.rooted(_ramp_turtle) and g.clock > 300.0 and not _ramp_open:
		_ramp_open = true
		_ramp_turtle.cmd_pack()
		_ramp_turtle = null
		say("best: the early danger is past: the ramp turtle uproots and goes back to supply duty")


# ------------------------------------------------------------------ the record

var _still := {}       # serial -> [position, since]


## A walking rooter that has not moved a tile in 15 s while ordered to move: stuck (a picture, a line).
func _watch_stuck() -> void:
	for u in mine(BroodNew.MAW) + mine(BroodNew.TURTLE) + mine(BroodNew.QUEEN) + mine(BroodNew.FATHER):
		if u.tesla_mode != "packed" or not (u.order == "move" or (u.order == "amove" and u.kind == BroodNew.FATHER)):
			_still.erase(u.serial)
			continue
		var r = _still.get(u.serial)
		if r == null or (r[0] as Vector2).distance_to(u.position) > 32.0:
			_still[u.serial] = [u.position, g.clock]
		elif g.clock - float(r[1]) > 15.0 and not bool(r.size() > 2):
			r.append(true)
			say("STUCK: %s #%d has not moved for 15 s (order move, %d tiles from its goal, path %d/%d, pending %s; at %s walkable %s)" % [Defs.UNITS[u.kind]["name"], u.serial, int(u.position.distance_to(u.path_goal) / Defs.TILE) if u.path_goal != Vector2.INF else -1, u.path_i, u.path.size(), str(u.path_pending), str(g.cell_of(u.position)), str(g._walkable(g.cell_of(u.position)))])
			shot("stuck", u, 1.5, 60.0)


func _watch_losses() -> void:
	_watch_stuck()


func _fstate(q: Unit) -> String:
	var f := BroodNew.father(g, 0)
	if f == null or q == null:
		return "none"
	var tg := ""
	if is_instance_valid(f.target):
		tg = " fighting %s (t%d, %d px away, can get at %s)" % [f.target.kind, f.target.team, int(f.target.edge_distance(f.position)), str(f._can_get_at(f.target))]
	return "%d tiles, %s%s at %s" % [int(f.position.distance_to(q.position) / Defs.TILE), f.order, tg, str((f.position / Defs.TILE).round())]


func _line() -> void:
	var q := BroodNew.queen(g, 0)
	var kinds := {}
	for u in g.units:
		if u.team == 0 and not u.dead:
			var k: String = u.kind
			if BroodNew.ROOTERS.has(k):
				k += "(r)" if BroodNew.rooted(u) else "(w)"
			kinds[k] = int(kinds.get(k, 0)) + 1
	var grounds: Array = []
	for m in mine(BroodNew.MAW) + mine(BroodNew.TURTLE):
		if m.kind == BroodNew.MAW and m.tesla_mode == "deployed":
			grounds.append("%d/%d%s" % [int(m.nb.get("food", 0.0)), int(BroodNew.ground_left(g, m)), "d" if bool(m.nb.get("dry", false)) else ""])
		elif m.tesla_mode != "deployed":
			var gl = _spots.get(m.serial)
			grounds.append("%s %s %s goal %s" % ["M" if m.kind == BroodNew.MAW else "T", m.tesla_mode, m.order, str(int(m.position.distance_to(gl) / Defs.TILE)) if gl != null else "-"])
	var foe := {}
	for u in g.units:
		if u.team == _foe and not u.dead:
			foe[u.kind] = int(foe.get(u.kind, 0)) + 1
	var st: Dictionary = g.stats[0]
	var fs: Dictionary = g.stats[_foe]
	coach.append("%s mother at %s | food %d (earned %d) essence %d supply %d/%d | mother %s %d hp eggs %d | maws food/ground %s | %s | killed %d lost %d (value killed %d) | wasted eggs %d | lay %s | father %s | FOE %s killed %d lost %d" % [_mmss(g.clock), str((q.position / Defs.TILE).round()) if q else "-",
		int(g.players[0]["gold"]), int(st.get("gold", 0)), int(g.players[0]["res2"]), g.supply_used(0), int(g.players[0]["cap"]),
		(q.tesla_mode if q else "dead"), int(q.hp) if q else 0, int(q.nb.get("eggs", 0)) if q else 0, str(grounds), str(kinds),
		int(st["killed"]), int(st["lost"]), int(st["value_killed"]), wasted, _why_k, _fstate(q), str(foe), int(fs["killed"]), int(fs["lost"])])
	print("CO " + coach[-1].left(400))


## Fights (Brood eggs and food piles are not soldiers).
func _look_for_fight(c: float) -> void:
	if c - last_fight < FIGHT_GAP:
		return
	var arm: Array = []
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.team >= 0 and not u.is_worker() and u.kind != BroodNew.EGG and u.kind != BroodNew.PILE and u.kind != "horse":
			arm.append(u)
	var best := 0
	var at := Vector2.ZERO
	for u in arm:
		var m := 0
		var th := 0
		for o in arm:
			if o.position.distance_to(u.position) < NEAR:
				if o.team == u.team:
					m += 1
				else:
					th += 1
		var s := mini(m, th)
		if s > best:
			best = s
			at = u.position
	if best >= FIGHT_MIN:
		last_fight = c
		pending.append(["fight_%s_%d_%d.png" % [_mmss(c), int(at.x), int(at.y)], at, 1.15])


## Clips: a few seconds drawn live, a picture every `step` frames, the camera on the creature.
func _clip_run() -> void:
	shooting = true
	var c: Array = clips.pop_front()
	var cam: Camera2D = g.camera
	var keep_pos := cam.position
	var keep_zoom := cam.zoom
	cam.zoom = Vector2(c[4], c[4])
	RenderingServer.render_loop_enabled = true
	var who = c[1]
	for i in int(c[2]):
		if who is Unit and is_instance_valid(who) and not who.dead:
			cam.position = who.position + Vector2(0, -30)
		elif who is Vector2:
			cam.position = who
		cam.reset_smoothing()
		for k in int(c[3]):
			await process_frame
		if i == 0:
			for k in 6:
				await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join("clip_%s_%02d.png" % [c[0], i]))
	print("CLIP %s %d frames" % [c[0], int(c[2])])
	say("(filmed the clip %s)" % c[0])
	RenderingServer.render_loop_enabled = live
	cam.position = keep_pos
	cam.zoom = keep_zoom
	shooting = false


func _finish() -> void:
	super._finish()
	var f := FileAccess.open(out.path_join("coach.txt"), FileAccess.WRITE)
	for l in coach:
		f.store_line(l)
	f.store_line("hauls %d spills %d wasted eggs %d" % [_hauls, _spills, wasted])
	for l in _snaps:
		f.store_line(l)
	f.store_line("eggs made per minute %s" % str(_min_made))
	f.store_line("eggs laid per minute %s" % str(_min_laid))
	f.close()
	var e := FileAccess.open(out.path_join("events.txt"), FileAccess.WRITE)
	for l in events:
		e.store_line(l)
	e.close()
