class_name AIBroodNew
extends AI
## The computer's simple plan for THE NEW BROOD (an experiment: scripts/brood_new.gd, docs/brood_new.md). It plays it
## plainly, so a match against it is possible; it is not clever yet (what it lacks: docs/brood_new.md).
##  - the Brood Mother stays rooted at home (she starts rooted); she gets up only to fight off an attack at her nest;
##  - the STRUCTURE-UNITS come from grubs (the owner, 19:19; scripts/brood_root.gd): Mound Turtles for supply ahead of
##    need, rooted round the Mother; Rootmaws on fresh swamp round her; the fathers on nests beside her (the
##    Tyrannosaur early, the Dilophosaurus once she reaches stage 2, the Pterodactyl at stage 3). Each spot
##    passes the same ROOT placement checks as the player's ghost (BroodRoot.place_problem) and keeps the ramps clear;
##  - a spent Rootmaw is uprooted (it spills what little it holds) and walked to new ground (ROOT like BUILD);
##  - grubs: enough to crew the rooted Rootmaws (idle grubs find work by themselves, Unit WORK);
##  - warriors: each line while its father is rooted beside her: Raptors and a Brute now and then (Tyrannosaur),
##    Spitters behind them and a Mist Toad or two (Dilophosaurus), Skywings against flyers or as a share (Pterodactyl);
##  - waves: the army attack-moves to the nearest enemy once it is big enough (the strategy's wave size, growing), falls
##    back to the Mother when it is cut down; anything near the Mother is fought by everything, the father too.
## No cheating: it goes for the enemy's starting spot and what it meets on the way.

var _nb_think := 0.0
var _wave: Array = []


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
	_nb_grow(q)
	_nb_rootmaws(q)
	_nb_turtles(q)
	_nb_father(q)
	_nb_morphs(q)
	_nb_lay(q)
	_nb_essence(q)
	_nb_army(q)
	if difficulty >= 1:
		_spells()           # (the Mist Toads' FOG and TONGUE, as the old Brood's computer: AI._toad)
		_skywings()         # (Skywings land to bite the ground and take off for flyers)


func in_wave(u: Unit) -> bool:
	return _attacking and _wave.has(u)


func _nb_mine(k: String) -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and u.kind == k)


## The Mother: rooted at home; she CANNOT ATTACK while rooted, so when enemies reach her she uproots and fights, and
## roots again once it is really calm (BroodNew.mother_guard). Only its own Mother: never the player's.
var _q_guard := {}


func _nb_mother(q: Unit) -> void:
	if q.team != team:
		return
	BroodNew.mother_guard(game, q, _q_guard, [1.6, 1.0, 0.6, 0.4][clampi(difficulty, 0, 3)])


# ------------------------------------------------------------------ the economy

func _nb_wanted_maws() -> int:
	return mini(2 + int(game.clock / 100.0), 8)


## Supply ahead of need (the old Clutch Mounds): one more Mound Turtle while the supply is within a few of the cap,
## counting the ones on their way (cocoons, grubs going to turn into one, turtles walking to their spot).
func _nb_short() -> bool:
	var cap := int(game.players[team]["cap"])
	if cap >= game.max_supply(team):
		return false
	var coming := 0
	for u in game.units:
		if u.team == team and not u.dead and ((u.kind == BroodNew.TURTLE and not BroodNew.rooted(u)) \
				or (u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.TURTLE)):
			coming += int(Defs.NB["turtle_supply"])
	return game.supply_used(team) + 5 + int(game.clock / 60.0) >= cap + coming


## THE STRUCTURE-UNITS COME FROM GRUBS (the owner, 19:19; scripts/brood_root.gd): one at a time, the computer picks
## what it needs (a Mound Turtle for supply, the Tyrannosaur, more Rootmaws), a spot that passes the same ROOT
## placement checks as the player's ghost (BroodRoot.place_problem, keeping its ramps clear), and the grub nearest it.
func _nb_morphs(q: Unit) -> void:
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "grub" and u.order == "nb_morph":
			return          # (one at a time: it is on its way)
	var grubs := BroodNew.count_of(game, team, "grub")
	var maws := BroodNew.count_of(game, team, BroodNew.MAW)
	var rush := strategy in ["rush", "xrush"]
	var k := ""
	if _nb_short():
		k = BroodNew.TURTLE
	elif BroodNew.count_of(game, team, BroodNew.FATHERS[0]) == 0 and (grubs >= (6 if rush else 9) or game.clock > (40.0 if rush else 80.0)) and maws >= 2:
		k = BroodNew.FATHERS[0]         # (the first father, from the start)
	elif _nb_next_father(q) != "":
		k = _nb_next_father(q)
	elif maws < _nb_wanted_maws() and (maws < 2 or int(game.players[team]["gold"]) >= 120):
		k = BroodNew.MAW
	if k == "" or grubs < 3 or BroodRoot.morph_problem(game, team, k) != "":
		return
	var spot = _nb_spot_for(q, k, null)
	if spot == null:
		return
	var best: Unit = null
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "grub" and u.carrying == 0 and u.cocoon <= 0.0 and u.order != "nb_morph" \
				and (best == null or u.position.distance_squared_to(spot) < best.position.distance_squared_to(spot)):
			best = u
	if best != null:
		best.give({"o": "nb_morph", "k": k, "p": spot})


## The later fathers, once her stage unlocks them (the owner, 21:45 and 2026-10-29 11:10): one of each, in order.
func _nb_next_father(q: Unit) -> String:
	if BroodNew.count_of(game, team, BroodNew.FATHERS[0]) == 0 or BroodNew.count_of(game, team, BroodNew.MAW) < 3 or game.clock < 150.0:
		return ""          # (the first Sire and the economy first: the others after him, from about 2:30)
	for f in BroodNew.FATHERS:
		if f == BroodNew.FATHERS[0]:
			continue
		if BroodNew.count_of(game, team, f) == 0 and BroodNew.stage(q) >= BroodNew.father_stage(f) and BroodRoot.morph_problem(game, team, f) == "":
			return f
	return ""


func _nb_spot_for(q: Unit, k: String, me: Unit):
	match k:
		BroodNew.TURTLE:
			return _nb_turtle_spot(q, me)
		BroodNew.MAW:
			return _nb_find_spot(q, me)
	return _nb_father_spot(q, me, k)


## Mound Turtles root a few tiles round the Mother, spread out (their swamp joins hers), never on the ramps.
func _nb_turtle_spot(q: Unit, me: Unit):
	var home := BroodRoot.home_region(game, q.position)
	for ring in [7.0, 9.0, 11.0, 13.0, 15.0]:
		for i in 12:
			var p: Vector2 = BroodRoot.snap(BroodNew.TURTLE, q.position + Vector2.from_angle(TAU * i / 12.0 + ring) * ring * Defs.TILE)
			var c := game.cell_of(p)
			if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
				continue
			if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, me, true) != "":
				continue
			var ok := true
			for o in game.units:
				if o != me and o.team == team and (o.kind == BroodNew.TURTLE or o.kind == BroodNew.MAW) and not o.dead and o.position.distance_to(p) < 5.0 * Defs.TILE:
					ok = false
					break
			if ok:
				return p
	return null


## A father's nest: beside the Mother, three quarters of his reach out (clear of her nest and of the other fathers'),
## the spot nearest him.
func _nb_father_spot(q: Unit, me: Unit, k: String = BroodNew.FATHER):
	var home := BroodRoot.home_region(game, q.position)
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	var from: Vector2 = me.position if me != null else q.position + Vector2(0, reach)
	for frac in [0.75, 0.6, 0.9, 0.5, 1.0]:
		var best = null
		for i in 24:
			var p: Vector2 = BroodRoot.snap(k, q.position + Vector2.from_angle(TAU * i / 24.0) * reach * frac)
			var c := game.cell_of(p)
			if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
				continue
			if BroodRoot.place_problem(game, team, k, p, me, true) != "" or BroodRoot.rect_for(k, p).intersects(_nb_mother_ground(q)):
				continue
			if best == null or p.distance_to(from) < (best as Vector2).distance_to(from):
				best = p
		if best != null:
			return best
	return null


## A Mound Turtle that is up (it was uprooted): walked to a spot and rooted there (ROOT like BUILD).
func _nb_turtles(q: Unit) -> void:
	for t in _nb_mine(BroodNew.TURTLE):
		if t.tesla_mode != "packed" or t.order == "nb_root" or t.target != null:
			continue
		var goal = _nb_turtle_spot(q, t)
		if goal != null:
			t.give({"o": "nb_root", "p": goal})


func _nb_rootmaws(q: Unit) -> void:
	for m in _nb_mine(BroodNew.MAW):
		if BroodNew.rooted(m) and float(m.nb.get("food", 0.0)) < 1.0 and BroodNew.ground_left(game, m) < 1.0:
			BroodNew.uproot(m, true)          # spent: off to fresh ground
			continue
		if m.tesla_mode != "packed" or m.target != null or m.order == "nb_root":
			continue
		var goal = _nb_find_spot(q, m)
		if goal != null:
			m.give({"o": "nb_root", "p": goal})        # (it walks there and roots on that spot)


## Inside the map, a tile in from its edge (Game.cell_of clamps a point off the map to the edge cell: a spot out
## there was taken for the edge's walkable cell, and the creature walked to the edge and stood stuck on its way).
func _nb_on_map(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(Game.W, Game.H) * Defs.TILE).grow(-Defs.TILE).has_point(p)


## Fresh ground: not spent (an old circle with little left).
func _nb_spot_ok(p: Vector2) -> bool:
	var r := float(Defs.PIT_CLAIM) * Defs.TILE * 2.0
	for id in game.nb_spots:
		var sp: Dictionary = game.nb_spots[id]
		if (sp["p"] as Vector2).distance_to(p) < r and float(sp["left"]) < 400.0:
			return false       # (spent ground)
	return true


func _nb_find_spot(q: Unit, m: Unit):
	var best = null
	var bs := INF
	var h := int(game.height[game.idx(game.cell_of(q.position))])
	var home := BroodRoot.home_region(game, q.position)
	var from: Vector2 = m.position if m != null else q.position
	for ring in [8.0, 11.0, 14.0, 17.0, 20.0]:
		for i in 16:
			var p: Vector2 = BroodRoot.snap(BroodNew.MAW, q.position + Vector2.from_angle(TAU * i / 16.0 + ring * 0.13) * ring * Defs.TILE)
			var c := game.cell_of(p)
			if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
				continue
			# (the ROOT checks: its footprint, on its side's swamp, its circle clear of the others' and of their plans)
			if not _nb_spot_ok(p) or BroodRoot.place_problem(game, team, BroodNew.MAW, p, m, true) != "":
				continue
			var s := p.distance_to(q.position) + (60.0 if int(game.height[game.idx(c)]) != h else 0.0) + p.distance_to(from) * 0.3
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

## Each father: walked (flown) to a nest spot beside the Mother (ROOT like BUILD) and rooted there (he is one of the
## Brood's barracks: the eggs of his line are fertilised and hatch in it). Rooted too far from her (she moved), he gets
## up and follows.
func _nb_father(q: Unit) -> void:
	for fk in BroodNew.FATHERS:
		var f := BroodNew.father(game, team, fk)
		if f != null:
			_nb_one_father(q, f)


func _nb_one_father(q: Unit, f: Unit) -> void:
	if f in _wave or BroodRoot.in_cocoon(f):
		return
	var d := f.position.distance_to(q.position)
	var reach := float(Defs.NB["father_r"]) * Defs.TILE
	var threat := _nb_threat(q) != Vector2.INF
	if f.tesla_mode == "deployed":
		if d > reach or threat:
			f.cmd_uproot(false)       # (no rooted creature attacks: to fight off an attack at the Mother he gets up)
		return
	if threat:
		return          # (uprooted, he fights with the others: _nb_army; he roots again when it is calm)
	if f.tesla_mode != "packed" or f.target != null or f.order == "nb_root":
		return
	var spot = _nb_father_spot(q, f, f.kind)
	if spot != null:
		f.give({"o": "nb_root", "p": spot})
	elif d > 14.0 * Defs.TILE and f.order != "move":
		f.cmd_move(q.position)       # (on a leash: by her, never off after a scout)


# ------------------------------------------------------------------ eggs

## GROW her (the owner's tiers, 12:20: Spitters need her stage 2; Brutes, Mist Toads and Skywings stage 3, the Storm
## Sire stage 2): from about 3:30 (stage 2) and 7:00 (stage 3) it SAVES for it (_nb_saving_growth: no warrior eggs
## meanwhile) and grows her once the price and a reserve are there; never while enemies are at her.
func _nb_grow(q: Unit) -> void:
	if BroodNew.grow_problem(game, q) != "" or _nb_threat(q) != Vector2.INF:
		return
	var st := BroodNew.stage(q)
	var nx: Dictionary = Defs.NB["stages"][st + 1]
	if game.clock < (210.0 if st == 0 else 420.0):
		return
	if int(game.players[team]["gold"]) >= int(nx["cost"]) + 100:
		BroodNew.grow(game, q)


## Saving food for her next stage: past its time, not grown yet, nothing at her, and the essence for it there (or
## coming: _nb_essence).
func _nb_saving_growth(q: Unit) -> bool:
	var st := BroodNew.stage(q)
	if st >= (Defs.NB["stages"] as Array).size() - 1 or float(q.nb.get("grow_t", 0.0)) > 0.0 or _nb_threat(q) != Vector2.INF or q.tesla_mode != "deployed":
		return false
	if game.clock < (210.0 if st == 0 else 420.0):
		return false
	var nx: Dictionary = Defs.NB["stages"][st + 1]
	return int(game.players[team]["gold"]) < int(nx["cost"]) + 100 and float(game.players[team]["res2"]) >= float(nx["cost2"])


## ESSENCE (her stage 3, the Venom and Storm Sires, the warriors that cost it): grubs HARVEST the bodies near home
## (two at most, while there are bodies); and while that is not enough, a Raptor at home (not in a wave; 6 always kept) is offered up
## at the Mother (SACRIFICE: about a third of its food as essence, and an egg back; grubs can't be offered), one every
## 4 s at most, while the essence wanted is short (and in an attack on her, none).
var _nb_offer_t := 0.0


func _nb_essence(q: Unit) -> void:
	var st := BroodNew.stage(q)
	var want := 0.0
	if BroodNew.count_of(game, team, BroodNew.DILO) == 0:
		want = maxf(want, float(Defs.UNITS[BroodNew.DILO].get("cost2", 0)))
	if st == 1:
		want = maxf(want, float(Defs.NB["stages"][2]["cost2"]) + 10.0)
		if BroodNew.count_of(game, team, BroodNew.PTERO) == 0:
			want = maxf(want, float(Defs.UNITS[BroodNew.PTERO].get("cost2", 0)) + 10.0)
	elif st >= 2:
		want = 60.0
	var have := float(game.players[team]["res2"])
	var grubs := _nb_mine("grub")
	var bodies := game.corpses.filter(func(c) -> bool: return is_instance_valid(c) and c.position.distance_to(q.position) < 22.0 * Defs.TILE)
	var harvesting := grubs.filter(func(u: Unit) -> bool: return u.order == "harvest")
	if not bodies.is_empty() and _nb_threat(q) == Vector2.INF:
		for u in grubs:
			if harvesting.size() >= 2:
				break
			if u.order == "gather" and u.carrying == 0 and not harvesting.has(u):
				u.cmd_harvest()
				harvesting.append(u)
	elif bodies.is_empty():
		for u in harvesting:
			if u.cocoon <= 0.0:
				u.cmd_stop()          # (no bodies left: back to work, WORK finds it a Rootmaw)
	if have + 9.0 * harvesting.size() >= want or game.clock < _nb_offer_t or _nb_threat(q) != Vector2.INF:
		return
	var raptors := _nb_mine("raptor").filter(func(u: Unit) -> bool: return u.position.distance_to(q.position) < 16.0 * Defs.TILE and u.target == null and u.order != "sacrifice")      # (at home, not fighting)
	if raptors.size() <= 6:          # (some always kept at home)
		return
	for u in raptors:
		if u.can_sacrifice():
			u.cmd_sacrifice()
			_nb_offer_t = game.clock + 4.0
			return


## Her eggs: grubs and warriors only (the structure-units come from grubs: _nb_morphs).
func _nb_lay(q: Unit) -> void:
	var eggs := int(q.nb.get("eggs", 0))
	if eggs <= 0:
		return
	var gold := int(game.players[team]["gold"])
	var grubs := BroodNew.count_of(game, team, "grub")
	var rooted := _nb_mine(BroodNew.MAW).filter(func(m: Unit) -> bool: return BroodNew.rooted(m)).size()
	var want_grubs := mini(maxi(rooted, 1) * int(Defs.NB["maw_crew"]) + 3, 36)      # (+ the ones that turn into creatures)
	var k := ""
	# saving up for a structure-unit the economy needs: no warriors meanwhile
	var saving := _nb_short() or (BroodNew.count_of(game, team, BroodNew.MAW) < 2)
	var any_father := BroodNew.FATHERS.any(func(f) -> bool: return BroodNew.father_near(game, team, f))
	var growing := _nb_saving_growth(q)       # (saving for her next stage: grubs as needed, no warriors)
	if grubs < want_grubs and (grubs < 8 or not any_father or gold < 200):
		k = "grub"
	elif any_father and not (saving and gold < 250) and not growing:
		k = _nb_warrior(gold)
	if k == "" or BroodNew.lay_problem(game, q, k) != "":
		if k != "grub" and grubs < want_grubs and BroodNew.lay_problem(game, q, "grub") == "":
			k = "grub"
		else:
			return
	if k == "grub" and saving and gold < 75 + 50:
		return          # (the turtle or Rootmaw first)
	BroodNew.lay(game, q, k)


## Which warrior egg: a mix by the fathers rooted beside her (each line only while its father is there) and by her
## stage (the owner's tiers, 12:20: Raptors from the start, Spitters at stage 2, Brutes, Mist Toads and Skywings at
## stage 3). Raptors are the base; Spitters about one egg in three behind them; a Brute now and then; a Mist Toad per
## 12 army supply (up to 3); Skywings when the enemy flies (or as one egg in five).
func _nb_warrior(gold: int) -> String:
	var q := BroodNew.queen(game, team)
	var st := BroodNew.stage(q) if q else 0
	var essence := float(game.players[team]["res2"])
	var trex := BroodNew.father_near(game, team, BroodNew.FATHER)
	var dilo := BroodNew.father_near(game, team, BroodNew.DILO) and st >= BroodNew.unit_stage("spitter")
	var ptero := BroodNew.father_near(game, team, BroodNew.PTERO) and st >= BroodNew.unit_stage("skywing")
	var toads_ok := dilo and st >= BroodNew.unit_stage("mist_toad")
	var brutes_ok := trex and st >= BroodNew.unit_stage("brute")
	var raptors := BroodNew.count_of(game, team, "raptor")
	var spitters := BroodNew.count_of(game, team, "spitter")
	var toads := BroodNew.count_of(game, team, "mist_toad")
	var wings := BroodNew.count_of(game, team, "skywing")
	var army := 0
	for u in _nb_army_units():
		army += int(u.d["supply"])
	var foe_air := 0
	for u in game.units:
		if game.hostile(u.team, team) and not u.dead and u.is_air():
			foe_air += 1
	if ptero and essence >= 40.0 and gold >= 100 and (wings < foe_air or (wings * 5 < raptors + spitters and wings < 8)):
		return "skywing"
	if toads_ok and essence >= 25.0 and gold >= 100 and toads < mini(3, army / 12):
		return "mist_toad"
	var keep := float(Defs.NB["stages"][2]["cost2"]) if st == 1 and game.clock >= 360.0 else 0.0      # (her stage 3 needs essence: kept for it)
	if dilo and essence >= 5.0 + keep and gold >= 90 and (not trex or spitters * 3 < raptors + 3):
		return "spitter"
	if trex:
		return "brute" if brutes_ok and essence >= 20.0 and gold >= 180 and randi() % 3 == 0 else "raptor"
	if dilo:
		return "spitter"
	return "skywing" if ptero else ""


# ------------------------------------------------------------------ the army

func _nb_army_units() -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and not u.is_worker() \
		and not BroodNew.is_nb(u.kind) and u.kind != "horse")


## An enemy near the Mother (13 tiles), or Vector2.INF.
func _nb_threat(q: Unit) -> Vector2:
	for u in game.units_near(q.position, 13.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field:
			return u.position
	return Vector2.INF


func _nb_army(q: Unit) -> void:
	var army := _nb_army_units()
	# defence: anything at the Mother is fought by every creature that walks, and by the father, who gets up from his
	# nest for it (rooted creatures don't attack: the Rootmaws and turtles stay rooted, the Mother: BroodNew.mother_guard)
	var threat := _nb_threat(q)
	if threat != Vector2.INF:
		var defenders := army.duplicate()
		for fk in BroodNew.FATHERS:
			var f := BroodNew.father(game, team, fk)
			if f and f.tesla_mode == "packed" and not BroodRoot.in_cocoon(f):
				defenders.append(f)      # (rooted on his nest he stays: it is the barracks)
		for u in defenders:
			if u.target == null and (u.order == "idle" or u.order == "nb_root" or u in _wave):
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
				u.cmd_move(q.position + Vector2(0, q.radius + 90.0))
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
		# gather by the Mother (south of her nest's ground)
		var spot := q.position + Vector2(0, q.radius + 110.0)
		for u in army:
			if u.order == "idle" and u.target == null and u.position.distance_to(spot) > 180.0:
				u.cmd_move(spot)


## The ground the Mother roots on at home (her footprint at her stage, one tile round it): a Sire never nests there,
## even while she is up fighting, or she could not root again when it is calm.
func _nb_mother_ground(q: Unit) -> Rect2:
	var home: Vector2 = _q_guard.get("home", q.position)
	return BroodRoot.rect_for(BroodNew.QUEEN, home, BroodRoot.scale_of(q)).grow(Defs.TILE)
