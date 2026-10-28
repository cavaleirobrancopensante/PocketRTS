class_name AIBroodNew
extends AI
## The computer's simple plan for THE NEW BROOD (an experiment: scripts/brood_new.gd, docs/brood_new.md). It plays it
## plainly, so a match against it is possible; it is not clever yet (what it lacks: docs/brood_new.md).
##  - the Brood Mother stays rooted at home (she starts rooted); she is never sent out;
##  - Mound Turtles for supply ahead of need, rooted round the Mother;
##  - Rootmaws: one more every so often, each walked to fresh ground round the Mother and
##    rooted; a spent one is uprooted (it spills what little it holds) and walked to new ground;
##  - grubs: enough to crew the rooted Rootmaws (idle grubs find work by themselves, Unit WORK);
##  - the Tyrannosaur: one, laid early, kept beside the Mother so the warriors' eggs are fertilised;
##  - warriors: Raptors, a Brute now and then (essence from SACRIFICE is not used yet), laid while the father is near;
##  - waves: the army attack-moves to the nearest enemy once it is big enough (the strategy's wave size, growing), falls
##    back to the Mother when it is cut down; anything near the Mother is fought by everything, the father too.
## No cheating: it goes for the enemy's starting spot and what it meets on the way.

var _nb_think := 0.0
var _wave: Array = []
var _spots := {}                 # Rootmaw serial -> the spot it is walking to


func _ready() -> void:
	if not strategies_for("brood").has(strategy):
		strategy = "balanced"
	_attack_at = int(STRATEGIES.get(strategy, STRATEGIES["balanced"])["wave"])
	if strategy == "timing" or _attack_at > 40:
		_attack_at = 24
	if game.mlog:
		game.mlog.add("%s plays the new Brood (experiment): a simple plan" % game.mlog.who(team))


func _tick_ai(delta: float) -> void:
	if game == null or game.over:
		return
	_nb_think -= delta
	if _nb_think > 0.0:
		return
	_nb_think = [1.6, 1.0, 0.6, 0.4][clampi(difficulty, 0, 3)]
	var q := BroodNew.queen(game, team)
	if q == null:
		return
	_nb_mother(q)
	_nb_rootmaws(q)
	_nb_turtles(q)
	_nb_father(q)
	_nb_lay(q)
	_nb_army(q)


func in_wave(u: Unit) -> bool:
	return _attacking and _wave.has(u)


func _nb_mine(k: String) -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and u.kind == k)


func _nb_mother(q: Unit) -> void:
	if q.tesla_mode == "packed" and q.order == "idle" and q.target == null:
		q.cmd_deploy()


# ------------------------------------------------------------------ the economy

func _nb_wanted_maws() -> int:
	return mini(2 + int(game.clock / 100.0), 8)


## Supply ahead of need (the old Clutch Mounds): one more Mound Turtle while the supply is within a few of the cap,
## counting the ones on their way (eggs, walking to their spot).
func _nb_short() -> bool:
	var cap := int(game.players[team]["cap"])
	if cap >= game.max_supply(team):
		return false
	var coming := 0
	for u in game.units:
		if u.team == team and not u.dead and ((u.kind == BroodNew.TURTLE and u.tesla_mode != "deployed") \
				or (u.kind == BroodNew.EGG and String(u.nb.get("k", "")) == BroodNew.TURTLE)):
			coming += int(Defs.NB["turtle_supply"])
	return game.supply_used(team) + 5 + int(game.clock / 60.0) >= cap + coming


## Mound Turtles root a few tiles round the Mother, spread out (their swamp joins hers).
func _nb_turtles(q: Unit) -> void:
	for t in _nb_mine(BroodNew.TURTLE):
		if t.tesla_mode != "packed":
			continue
		var goal = _spots.get(t.serial)
		if goal == null:
			goal = _nb_turtle_spot(q, t)
			if goal == null:
				continue
			_spots[t.serial] = goal
			t.cmd_move(goal)
			continue
		if t.position.distance_to(goal) < 40.0 or t.order == "idle":
			t.cmd_deploy()
			_spots.erase(t.serial)


func _nb_turtle_spot(q: Unit, me: Unit):
	var home := game.region_of(game.cell_of(q.position))
	for ring in [6.0, 9.0, 12.0, 15.0]:
		for i in 12:
			var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 12.0 + ring) * ring * Defs.TILE
			var c := game.cell_of(p)
			if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
				continue
			var ok := true
			for o in game.units:
				if o != me and o.team == team and (o.kind == BroodNew.TURTLE or o.kind == BroodNew.MAW) and not o.dead and o.position.distance_to(p) < 4.0 * Defs.TILE:
					ok = false
					break
			for s in _spots:
				if int(s) != me.serial and (_spots[s] as Vector2).distance_to(p) < 4.0 * Defs.TILE:
					ok = false
			if ok:
				return p
	return null


func _nb_rootmaws(q: Unit) -> void:
	for m in _nb_mine(BroodNew.MAW):
		if m.tesla_mode == "deployed" and float(m.nb.get("food", 0.0)) < 1.0 and BroodNew.ground_left(game, m) < 1.0:
			BroodNew.uproot(m, true)          # spent: off to fresh ground
			_spots.erase(m.serial)
			continue
		if m.tesla_mode != "packed" or m.target != null:
			continue
		var goal = _spots.get(m.serial)
		if goal == null or not _nb_spot_ok(goal, m):
			goal = _nb_find_spot(q, m)
			if goal == null:
				continue
			_spots[m.serial] = goal
			m.cmd_move(goal)
			continue
		if m.position.distance_to(goal) < 40.0 or (m.order == "idle" and m.position.distance_to(goal) < 90.0):
			if BroodNew.root_problem(game, m) == "":
				m.cmd_deploy()
			else:
				_spots.erase(m.serial)
		elif m.order == "idle":
			m.cmd_move(goal)


## Inside the map, a tile in from its edge (Game.cell_of clamps a point off the map to the edge cell: a spot out
## there was taken for the edge's walkable cell, and the creature walked to the edge and stood stuck on its way).
func _nb_on_map(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(Game.W, Game.H) * Defs.TILE).grow(-Defs.TILE).has_point(p)


func _nb_spot_ok(p: Vector2, me: Unit) -> bool:
	var r := float(Defs.PIT_CLAIM) * Defs.TILE * 2.0
	for o in game.units:
		if o != me and o.kind == BroodNew.MAW and not o.dead and o.tesla_mode != "packed" and o.position.distance_to(p) < r:
			return false
	for s in _spots:
		if int(s) != me.serial and (_spots[s] as Vector2).distance_to(p) < r:
			return false
	for id in game.nb_spots:
		var sp: Dictionary = game.nb_spots[id]
		if (sp["p"] as Vector2).distance_to(p) < r and float(sp["left"]) < 400.0:
			return false       # (spent ground)
	return true


func _nb_find_spot(q: Unit, m: Unit):
	var best = null
	var bs := INF
	var h := int(game.height[game.idx(game.cell_of(q.position))])
	var home := game.region_of(game.cell_of(q.position))
	for ring in [8.0, 11.0, 14.0, 17.0, 20.0]:
		for i in 16:
			var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 16.0 + ring * 0.13) * ring * Defs.TILE
			var c := game.cell_of(p)
			if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
				continue
			if not _nb_spot_ok(p, m) or not BroodNew.on_swamp(game, team, p):      # (a Rootmaw roots only on its side's swamp)
				continue
			var s := p.distance_to(q.position) + (60.0 if int(game.height[game.idx(c)]) != h else 0.0) + p.distance_to(m.position) * 0.3
			var foe := _nb_nearest_foe_pos(p)
			if foe != Vector2.INF:
				s -= foe.distance_to(p) * 0.15         # (a little away from the enemy)
			if s < bs:
				bs = s
				best = p
		if best != null:
			break
	return best


func _nb_nearest_foe_pos(p: Vector2) -> Vector2:
	var best := Vector2.INF
	for o in game.enemies_of(team):
		var c: Vector2 = game.center_of_team(o)
		if best == Vector2.INF or c.distance_to(p) < best.distance_to(p):
			best = c
	return best


# ------------------------------------------------------------------ the father

func _nb_father(q: Unit) -> void:
	var f := BroodNew.father(game, team)
	if f == null or f in _wave:
		return
	var d := f.position.distance_to(q.position)
	# on a leash: he fights by her, never chases off after a scout (away from her, no warriors are fathered)
	if d > 14.0 * Defs.TILE and not f.order == "move":
		f.cmd_move(q.position)
		return
	if f.target != null:
		return
	if d > float(Defs.NB["father_r"]) * Defs.TILE * 0.6 and (f.order == "idle" or f.order == "hold"):
		# a walkable spot beside her (she may sit by the map's edge or a cliff), the one nearest him
		var home := game.region_of(game.cell_of(q.position))
		var best := Vector2.INF
		for i in 12:
			var p: Vector2 = q.position + Vector2.from_angle(TAU * i / 12.0) * (q.radius + f.radius + 24.0)
			var c := game.cell_of(p)
			if _nb_on_map(p) and game._walkable(c) and game.region_of(c) == home and (best == Vector2.INF or p.distance_to(f.position) < best.distance_to(f.position)):
				best = p
		if best != Vector2.INF:
			f.cmd_move(best)


# ------------------------------------------------------------------ eggs

func _nb_lay(q: Unit) -> void:
	var eggs := int(q.nb.get("eggs", 0))
	if eggs <= 0:
		return
	var gold := int(game.players[team]["gold"])
	var grubs := BroodNew.count_of(game, team, "grub")
	var maws := BroodNew.count_of(game, team, BroodNew.MAW)
	var rooted := _nb_mine(BroodNew.MAW).filter(func(m: Unit) -> bool: return m.tesla_mode == "deployed").size()
	var want_grubs := mini(maxi(rooted, 1) * int(Defs.NB["maw_crew"]) + 1, 34)
	var want_maws := _nb_wanted_maws()
	var rush := strategy in ["rush", "xrush"]
	var k := ""
	if _nb_short():
		k = BroodNew.TURTLE
	elif BroodNew.count_of(game, team, BroodNew.FATHER) == 0 and (grubs >= (6 if rush else 9) or game.clock > (40.0 if rush else 80.0)) and maws >= 2:
		k = BroodNew.FATHER
	elif maws < want_maws and (maws < 2 or gold >= 120):
		k = BroodNew.MAW
	elif grubs < want_grubs and (grubs < 8 or not BroodNew.father_near(game, team) or gold < 200):
		k = "grub"
	elif BroodNew.father_near(game, team):
		var essence := float(game.players[team]["res2"])
		k = "brute" if essence >= 20.0 and gold >= 180 and randi() % 3 == 0 else "raptor"
	if k == "" or BroodNew.lay_problem(game, q, k) != "":
		if k == BroodNew.FATHER or k == BroodNew.MAW or k == BroodNew.TURTLE:
			return       # (saving up for it)
		if k != "grub" and grubs < want_grubs and BroodNew.lay_problem(game, q, "grub") == "":
			k = "grub"
		else:
			return
	BroodNew.lay(game, q, k)


# ------------------------------------------------------------------ the army

func _nb_army_units() -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and not u.is_worker() \
		and not BroodNew.is_nb(u.kind) and u.kind != "horse")


func _nb_army(q: Unit) -> void:
	var army := _nb_army_units()
	# defence: anything at the Mother is fought by everything (the father too)
	var threat := Vector2.INF
	for u in game.units_near(q.position, 13.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field:
			threat = u.position
			break
	if threat != Vector2.INF:
		var f := BroodNew.father(game, team)
		var defenders := army.duplicate()
		if f:
			defenders.append(f)
		for u in defenders:
			if u.target == null and (u.order == "idle" or u in _wave):
				u.cmd_move(threat, true)
		return
	var sup := 0
	for u in army:
		sup += int(u.d["supply"])
	if _attacking:
		_wave = _wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		var left := 0
		for u in _wave:
			left += int(u.d["supply"])
		if left * 3 < _wave_sup:
			# cut down: back to the Mother; the next wave waits for more
			_attacking = false
			for u in _wave:
				u.cmd_move(q.position + Vector2(0, q.radius + 40.0))
			_wave.clear()
			_attack_at += int(STRATEGIES.get(strategy, STRATEGIES["balanced"])["step"])
			return
		for u in _wave:
			if u.order == "idle" and u.target == null:
				u.cmd_move(_wave_target, true)
		# newly hatched join the wave
		for u in army:
			if not _wave.has(u) and u.order == "idle":
				_wave.append(u)
				u.cmd_move(_wave_target, true)
		return
	if sup >= _attack_at and not peaceful:
		var foe := _foe()
		if foe < 0:
			return
		_wave_target = game.center_of_team(foe)
		_wave = army.duplicate()
		_wave_sup = sup
		_attacking = true
		for u in _wave:
			u.cmd_move(_wave_target, true)
		if game.mlog:
			game.mlog.add("%s's new Brood attacks with %d supply" % [game.mlog.who(team), sup])
	else:
		# gather by the Mother
		var spot := q.position + Vector2(0, q.radius + 60.0)
		for u in army:
			if u.order == "idle" and u.target == null and u.position.distance_to(spot) > 180.0:
				u.cmd_move(spot)
