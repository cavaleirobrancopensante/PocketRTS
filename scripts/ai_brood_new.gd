class_name AIBroodNew
extends AI
## THE BROOD'S COMPUTER (scripts/brood_new.gd, docs/brood_new.md; the only Brood since 0.18.0). Rewritten in 0.22.0 from
## the coached games of docs/brood_new_play_3.md (how it plays, its profiles and its numbers: docs/brood_ai.md):
##  - a BUILD ORDER per profile (PLANS: Extreme rush, Rush, Timing attack, Balanced, Economy, Air rush): when the Tyrant
##    Sire's lure goes down, how many grubs, when the Mother grows, when the Venom and Storm Sires come, how far it
##    expands (Mound Turtles on new ground), when it researches what, and when it attacks with what;
##  - the Mother stays rooted at home and grows on time (food saved for it, spoils kept for her stage 3); she gets up only
##    to fight off an attack at her nest (BroodNew.mother_guard);
##  - the STRUCTURE-UNITS come from grubs (scripts/brood_root.gd): Mound Turtles for supply ahead of need round her, and
##    on NEW GROUND for expansions (the best turtle spots, ExpansionSpots.nb_pick) with Rootmaws following them; the
##    Sires through their lures beside her (the Storm Sire first when the enemy has flyers);
##  - grubs: enough to crew the rooted Rootmaws, never more than the plan's cap;
##  - warriors by the lines it has (Raptors, Brutes; Spitters, Mist Toads; Hatchlings only against flyers it has SEEN);
##    young MATURE into Challengers when food piles up or before a push; spoils come from bodies (HARVEST) and from
##    SACRIFICE of spare Raptors at home, only for what they are wanted for;
##  - research in an order (Bigger Clutch early, Pack Hunt before the first attack, Battering Horns before sieges,
##    Quick Roots mid game...);
##  - a SCOUT (a grub, later a Raptor) looks at the enemy's base; what it and every creature sees is remembered (the fog
##    of war: Game.is_visible_to): an early army or fast riders = RUSH evidence (it holds its army at home, delays its
##    growth and lays warriors), enemy flyers = the Storm Sire first, a wall = Brutes and Battering Horns;
##  - DEFENCE: anything at the Mother is fought by every creature that walks and by the Sires (they get up), a wave out
##    is called home when the attack at her is big;
##  - WAVES: the army gathers at a staging point on the way, attacks together, the new hatched join only in groups, and
##    it RETREATS when the fight is lost (what it sees against what it has); Hatchlings stay home unless the enemy flies.
## No cheating: it knows where the enemy started (as every computer does) and otherwise only what its creatures see.

var _nb_think := 0.0
var _wave: Array = []
var plan := {}                   # this game's build order: PLANS[strategy] + `over` (tools set `over` to coach it)
var over := {}                   # (tools/play_brood_3.gd, tools/measure_brood_ai.gd: settings forced for a coached game)
var note: Array = []             # [clock, text] of what it decided (tests and tools read it)
var held: Array = []             # creatures it leaves alone (a coach's hand orders: tools/play_brood_3.gd)

## THE PROFILES (docs/brood_ai.md has the timelines; docs/ai_build_timelines.md the table). Times in game seconds.
##  sire_g / sire_t   the Tyrant Sire's lure goes down with this many grubs, or at this time (and 2 Rootmaws)
##  grubs0            grubs held at this many until the first wave has left (0: no hold)
##  grubs             the most grubs at any time
##  maws              Rootmaws wanted: [base, one more every N s, at most]
##  grow              [stage 2 from, stage 3 from]: food saved for it from then on
##  venom / storm     the Venom / Storm Sire's lure from this time (needs 3 Rootmaws; the Storm Sire needs stage 2)
##  far               [[time, how many far turtles by then], ...] (expansions on new ground)
##  wave / wave_t     first attack: this much army supply, not before wave_t; step: each next wave this much more
##  pack              Pack Hunt before the first attack (it waits for it once it has the army)
##  mix               warrior mix: "tyrant" (Raptors, Brutes), "venom" (Spitters ahead), "mixed"
##  mature            mature young into Challengers: "push" (before a wave), "bank" (food piling up), "" (never early)
##  home_guard        Raptors kept home when a wave leaves (after the first)
##  drone             grubs a minute on the curve that comes before warriors (from the 5 it starts with)
##  maws0 / ahead0    a rush: Rootmaws before the first wave; supply kept ahead for it (the turtle right after the Sire)
##  eco               the owner's economic build (2026-10-30, docs/brood_eco.md): the natural first, far Rootmaws, grubs
##                    nonstop, her growth when eggs hold it back, the watching grub and the alarm
##  spoils_bank       spoils kept wanted (Raptors laid and offered up for them): the Air rush's Storm line
##  storm_want        Hatchlings kept to mature into Storm Challengers
##  edge              a wave goes only with this share of the biggest enemy army seen lately (0.6; 0.3 against the
##                    Clockwork), or at the supply cap
## Settings only a tool or a coach sets (tools/play_brood_3.gd): "sire_leads" (a Sire walks with the waves:
## "dilophosaurus" was the owner's good idea, the Tyrant Sire a bad one), "storm_want" (Hatchlings kept to mature into
## Storm Challengers), "mother_free" (the computer leaves its Mother alone: the coach's Mother rush).
const PLANS := {
	"xrush": {"drone": 0.0, "sire_g": 5, "sire_t": 0.0, "grubs0": 6, "maws0": 1, "ahead0": 7, "grubs": 26, "maws": [2, 150.0, 6], "grow": [420.0, 780.0],
		"venom": 600.0, "storm": 900.0, "far": [[600.0, 1]], "wave": 8, "wave_t": 0.0, "step": 4, "pack": false,
		"mix": "tyrant", "mature": "bank", "home_guard": 0},
	"rush": {"drone": 3.0, "sire_g": 7, "sire_t": 40.0, "grubs0": 9, "maws0": 2, "grubs": 28, "maws": [2, 120.0, 7], "grow": [330.0, 660.0],
		"venom": 330.0, "storm": 720.0, "far": [[420.0, 1], [660.0, 2]], "wave": 10, "wave_t": 0.0, "step": 6, "pack": false,
		"mix": "tyrant", "mature": "bank", "home_guard": 2},
	"timing": {"drone": 6.0, "sire_g": 11, "sire_t": 120.0, "grubs0": 0, "grubs": 46, "maws": [2, 90.0, 8], "grow": [210.0, 540.0],
		"venom": 420.0, "storm": 660.0, "far": [[0.0, 1], [360.0, 2]], "eco": true, "wave": 24, "wave_t": 330.0, "step": 10, "pack": true,
		"mix": "tyrant", "mature": "push", "home_guard": 3},
	"balanced": {"drone": 7.0, "sire_g": 13, "sire_t": 150.0, "grubs0": 0, "grubs": 54, "maws": [2, 80.0, 10], "grow": [240.0, 480.0],
		"venom": 360.0, "storm": 540.0, "far": [[0.0, 1], [300.0, 2], [540.0, 3]], "eco": true, "wave": 22, "wave_t": 390.0, "step": 10, "pack": true,
		"mix": "mixed", "mature": "push", "home_guard": 3},
	"economy": {"drone": 8.0, "sire_g": 14, "sire_t": 165.0, "grubs0": 0, "grubs": 58, "maws": [2, 70.0, 11], "grow": [200.0, 420.0],
		"venom": 420.0, "storm": 480.0, "far": [[0.0, 1], [240.0, 2], [480.0, 3]], "eco": true, "wave": 34, "wave_t": 510.0, "step": 12,
		"pack": true, "mix": "venom", "mature": "push", "home_guard": 4},
	"air": {"drone": 6.0, "sire_g": 11, "sire_t": 110.0, "grubs0": 0, "grubs": 44, "maws": [2, 85.0, 9], "grow": [180.0, 420.0],
		"venom": 600.0, "storm": 150.0, "far": [[0.0, 1], [360.0, 2]], "eco": true, "spoils_bank": 120.0, "storm_want": 8, "wave": 18, "wave_t": 420.0, "step": 8, "pack": false,
		"mix": "tyrant", "mature": "push", "home_guard": 3},
}


## (a computer made by hand, as the tests do, has its plan from the start: Balanced until it is told otherwise)
func _init() -> void:
	_make_plan()


func _ready() -> void:
	if not strategies_for("brood").has(strategy):
		strategy = "balanced"
	_opened = strategy
	_make_plan()
	if game.mlog:
		game.mlog.add("%s plays the Brood (%s)" % [game.mlog.who(team), STRATEGIES.get(strategy, STRATEGIES["balanced"])["name"]])


## This game's plan: the profile, eased by the level (Easy is slower and smaller), then what a tool forced (`over`).
var _plan_of := ""               # (the strategy the plan was made for: a tool or test that sets `strategy` later gets its plan)


func _make_plan() -> void:
	_plan_of = strategy
	plan = (PLANS.get(strategy, PLANS["balanced"]) as Dictionary).duplicate(true)
	if difficulty == 0:
		plan["wave_t"] = float(plan["wave_t"]) + 120.0
		plan["grubs"] = int(plan["grubs"]) - 6
		plan["grow"] = [float(plan["grow"][0]) + 90.0, float(plan["grow"][1]) + 150.0]
		plan["pack"] = false
	# against the Clockwork, steady Raptor pressure from about 5:00 (round 3: g20 traded 11,020 for 4,345 with small early
	# waves of Pack Hunt Raptors; holding home for a big army only let the richer Clockwork grow): smaller, earlier waves
	if game == null:
		_attack_at = int(plan["wave"])
		return
	if _foe_is("crown") and String(plan["mix"]) == "tyrant" and not strategy in ["xrush", "rush"]:
		plan["mix"] = "mixed"          # (the Crown walls its ramp: claws alone never go in, the wall rule waits for Spitters)
	if _foe_is("clockwork") and not strategy in ["xrush", "rush"]:
		plan["wave"] = mini(int(plan["wave"]), 14)
		plan["wave_t"] = minf(float(plan["wave_t"]), 300.0 if difficulty > 0 else 420.0)
		plan["step"] = mini(int(plan["step"]), 4)
		plan["edge"] = 0.3
		plan["pack"] = false          # (Pack Hunt comes when it comes: the waves don't wait for it)
		plan["grubs"] = mini(int(plan["grubs"]), 44)      # (brood-eco: 54 grubs earned more against the Crown, but against the
		                                                  # Clockwork's early army the extra grubs were an army it lacked)
	for k in over:
		plan[k] = over[k]
	_attack_at = int(plan["wave"])


func say(s: String) -> void:
	note.append([game.clock, s])
	if game.mlog:
		game.mlog.add("%s's Brood: %s" % [game.mlog.who(team), s])


func _tick_ai(delta: float) -> void:
	if game == null or game.over:
		return
	_nb_think -= delta
	if _nb_think > 0.0:
		return
	_nb_think = [1.6, 1.0, 0.6, 0.4][clampi(difficulty, 0, 3)]
	if strategy != _plan_of and PLANS.has(strategy):
		var aa := _attack_at
		_make_plan()
		_attack_at = mini(aa, _attack_at) if aa > 0 else _attack_at
	var q := BroodNew.queen(game, team)
	if q == null:
		return
	_nb_observe(q)
	if int(q.nb.get("eggs", 0)) <= EGG_LOW and float(q.nb.get("grow_t", 0.0)) <= 0.0:
		_egg_low_t = game.clock          # (her clutch run down: eggs hold the Brood back, _nb_grow_time)
	_nb_root_watch()
	if difficulty >= 1:
		_nb_scout(q)
	_nb_mother(q)
	_nb_grow(q)
	_nb_rootmaws(q)
	_nb_turtles(q)
	if _eco():
		_nb_alarm(q)
	_nb_father(q)
	_nb_morphs(q)
	_nb_lay(q)
	_nb_essence(q)
	_nb_mature(q)
	_nb_research(q)
	_nb_army(q)
	if difficulty >= 1:
		_spells()           # (the Mist Toads' FOG and TONGUE, as the old Brood's computer: AI._toad)


func in_wave(u: Unit) -> bool:
	return _attacking and _wave.has(u)


func _nb_mine(k: String) -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and u.kind == k)


func _food() -> int:
	return int(game.players[team]["gold"])


func _spoils() -> float:
	return float(game.players[team]["res2"])


# ------------------------------------------------------------------ what it knows of the enemy (the fog of war)

## What its creatures have SEEN (Game.is_visible_to): the enemy's flyers, its army's value (the most seen lately, fading),
## fast riders early (rush evidence), a wall, where its buildings stand. Never what it can't see.
var seen_air := 0               # the most enemy flyers seen at once lately
var _air_t := -999.0
var seen_army := 0.0            # the biggest enemy army value seen lately (fades)
var seen_wall := false
var rush_seen := ""             # rush evidence: what was seen ("" = none)
var rush_t := -1.0
var _foe_blds := {}             # enemy building -> its centre (seen standing)
var _foe_near_home := 0.0       # enemy army value seen near the Mother now
var _obs_t := 0.0
const ALARM_FOR := 75.0
var alarm_t := -999.0              # when the alarm was last seen (an army out of the enemy's main)
var alarm_at := Vector2.ZERO       # where it was seen


func _alarm_on() -> bool:
	return game.clock - alarm_t < ALARM_FOR


## THE OWNER'S BUILD, its brake: grubs nonstop, but never with an army far smaller than the enemy army its creatures saw
## lately (the watching grub in the Clockwork's main sees it gather). In the first games of this round the Brood had 40
## grubs and no army at 7:00, and a Clockwork army of 2,000 took its Tyrant Sire and a third of its grubs. Warriors
## first (with 16 grubs or more) while its army is under this share of what it saw (0.7 against the Clockwork, which
## comes early; 0.3 against the others).
func _under_armed() -> bool:
	if not _eco() or game.clock < 150.0 or seen_army < 200.0:
		return false
	var share := 0.7 if _foe_is("clockwork") else 0.3
	return _value_of(_nb_army_units()) < seen_army * share


func _nb_observe(q: Unit) -> void:
	if game.clock - _obs_t < 1.0:
		return
	var dt := game.clock - _obs_t
	_obs_t = game.clock
	seen_army = maxf(0.0, seen_army - dt * 1.0)        # (fades: 60 a minute)
	var air := 0
	var val := 0.0
	var out := 0.0                  # (value seen OUT of the enemy's own base: an army on the move)
	var home := 0.0
	var fast := 0
	var foe := _foe()
	var fst: Vector2 = (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE if foe >= 0 else Vector2.INF
	var past := 0.0                 # (value seen past the foot of its ramp: an army that has left its main)
	var past_at := Vector2.ZERO
	var out_r := 22.0 * Defs.TILE
	if _foot != Vector2.INF and fst != Vector2.INF:
		out_r = minf(out_r, _foot.distance_to(fst) + 3.0 * Defs.TILE)
	for u in game.units:
		if u.dead or u.off_field or u.team < 0 or not game.hostile(u.team, team) or not game.is_visible_to(team, u.position):
			continue
		if u.is_worker() or u.kind == "horse" or u.kind == "messenger" or not u.has_attack() or u.kind == BroodNew.EGG:
			continue
		if u._k_nb and (u.kind == BroodNew.QUEEN or BroodNew.rooted(u)):
			continue
		var v := float(Game.unit_value(u))
		val += v
		var away: bool = fst == Vector2.INF or u.position.distance_to(fst) > 22.0 * Defs.TILE
		if away:
			out += v
		if fst == Vector2.INF or u.position.distance_to(fst) > out_r:
			past += v
			past_at += u.position * v
		if u.is_air():
			air += 1
		if float(u.d.get("speed", 0)) >= 95.0 and not u.is_air() and away:
			fast += 1
		if u.position.distance_to(q.position) < 24.0 * Defs.TILE:
			home += v
	_foe_near_home = home
	seen_army = maxf(seen_army, val)
	if air > 0:
		seen_air = maxi(seen_air, air)
		_air_t = game.clock
	elif game.clock - _air_t > 180.0:
		seen_air = 0
	for b in game.buildings:
		if b.dead or not game.hostile(b.team, team) or b.ghost or _foe_blds.has(b):
			continue
		if game.is_visible_to(team, b.center()):
			_foe_blds[b] = b.center()
			if b.kind in ["wall", "gate", "palisade"]:
				seen_wall = true
	for b in _foe_blds.keys():
		if not is_instance_valid(b) or b.dead:
			_foe_blds.erase(b)
	# THE ALARM (the owner's build: the watching grub sees an attack coming): an army out of the enemy's main, big
	# enough to hurt (200, and 40% of its own army), at any time: for ALARM_FOR s it lays warriors, holds its army at
	# home (gathered at the natural), pulls the grubs back from Rootmaws the enemy comes near and roots a Mound Turtle in
	# front of the natural (_nb_alarm)
	if _eco() and past >= 200.0 and past >= _value_of(_nb_army_units()) * 0.4 and not _attacking:
		if game.clock - alarm_t > ALARM_FOR:
			say("ALARM: an enemy army of %d out of its main at %s: warriors, grubs pulled back, a turtle in front" % [int(past), _mmss()])
		alarm_t = game.clock
		alarm_at = past_at / past
	# rush evidence (before 4:30; what it saw OUT of the enemy's base: an army in its own base is no rush): fast riders
	# in numbers, an army near home, or a big army on the move very early
	if rush_seen == "" and game.clock < 270.0:
		var why := ""
		if fast >= 2:
			why = "%d fast riders seen at %s" % [fast, _mmss()]
		elif home >= 150.0:
			why = "an army (%d) near the Mother at %s" % [int(home), _mmss()]
		elif out >= 300.0 and game.clock < 210.0:
			why = "an army of %d on the move at %s" % [int(out), _mmss()]
		if why != "":
			rush_seen = why
			rush_t = game.clock
			say("rush evidence: %s: holds its army at home and lays warriors" % why)


## The enemy flyers it has seen lately (the most at once): what it knows, not every flyer on the map.
func _nb_foe_air() -> int:
	return seen_air


## The enemy walls itself in (a wall seen, or the Crown, which walls its ramp in its first minute).
func _wall_foe() -> bool:
	if seen_wall:
		return true
	var foe := _foe()
	return foe >= 0 and game.faction_of(foe) == "crown"


func _mmss() -> String:
	return "%d:%02d" % [int(game.clock) / 60, int(game.clock) % 60]


## Rush evidence that still counts (for 3 minutes, and only while the enemy army is not beaten).
func _rush_on() -> bool:
	return rush_seen != "" and game.clock - rush_t < 180.0


## THE SCOUT (Normal and up, not the Extreme rush): a grub at about 1:10 walks to the enemy's start and round it, then
## home (a grub is cheap and its trip reveals the opening); at about 4:30 a Raptor looks again (its army, a wall,
## flyers, an expansion). It runs home from soldiers that come at it.
var _scout: Unit = null
var _scout_trips := 0
var _scout_pts: Array = []
var _scout_i := 0
var _scout_t0 := 0.0


func _nb_scout(q: Unit) -> void:
	if strategy == "xrush" or peaceful:
		return
	var foe := _foe()
	if foe < 0:
		return
	if _eco():
		_nb_watch_scout(q, foe)
		return
	if _scout != null and (not is_instance_valid(_scout) or _scout.dead):
		_scout = null
	if _scout == null:
		var due := 70.0 if _scout_trips == 0 else (270.0 if _scout_trips == 1 else 9999.0)
		if game.clock < due or _scout_trips >= 2:
			return
		var pick: Unit = null
		if _scout_trips == 0:
			for u in _nb_mine("grub"):
				if u.carrying == 0 and u.order == "gather" and u.cocoon <= 0.0:
					pick = u
					break
		else:
			for u in _nb_army_units():
				if u.kind == "raptor" and not _wave.has(u) and u.target == null:
					pick = u
					break
		if pick == null:
			return
		var st := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
		var toward := (q.position - st).normalized()
		_scout_pts = [st + toward * 9.0 * Defs.TILE, st, st + toward.orthogonal() * 7.0 * Defs.TILE, st - toward * 6.0 * Defs.TILE,
			st - toward.orthogonal() * 7.0 * Defs.TILE, q.position]
		_scout_i = 0
		_scout = pick
		_scout_trips += 1
		_scout_t0 = game.clock
		_scout_go(pick, _scout_pts[0])
		say("sends a %s to scout" % Defs.UNITS[pick.kind]["name"])
		return
	# on the road: next point; home after the loop, after 100 s, or when hurt by soldiers
	var hurt := _scout.hp < _scout.max_hp * 0.6
	if hurt or game.clock - _scout_t0 > 100.0 or _scout_i >= _scout_pts.size():
		if _scout.position.distance_to(q.position) > 10.0 * Defs.TILE:
			if _scout.order != "move" or _scout.path_goal.distance_to(q.position) > 200.0:
				_scout.cmd_move(q.position)
			return
		_scout.remove_meta("ai_scout")
		_scout.cmd_stop()        # (home: back to work; WORK finds a grub a Rootmaw)
		_scout = null
		return
	if _scout.position.distance_to(_scout_pts[_scout_i]) < 3.0 * Defs.TILE or _scout.order == "idle":
		_scout_i += 1
		if _scout_i < _scout_pts.size():
			_scout_go(_scout, _scout_pts[_scout_i])


## THE COMPUTER (ALMOST) NEVER USES PLAIN MOVE (owner, 2026-10-30): a Raptor scout goes on attack-move, marked
## "ai_scout" (it bites only what fights back, Unit._pick_target: not every building on its loop); a grub (a worker)
## walks. Going home hurt stays a plain walk (a retreat).
func _scout_go(u: Unit, p: Vector2) -> void:
	if u.is_worker():
		u.cmd_move(p)
		return
	u.set_meta("ai_scout", true)
	u.cmd_move(p, true)


## THE WATCHING GRUB (the owner's build, 2026-10-30 07:15: scouting for a safe economy): from about 1:10 a grub stays
## out on watch for the whole game, to see a rush or a timing attack coming:
##  - against the CROWN it PATROLS at the bottom of the enemy's ramp (a little out from its foot, to and fro across it):
##    everything that leaves the Crown's main walks past it;
##  - against the CLOCKWORK (or any other) it EXPLORES the enemy's main, round and round (what it trains, how big its
##    army is, where it gathers).
## Hurt, or soldiers close to it, it runs home and goes back to work; another grub goes out after WATCH_GAP s (at most
## WATCH_MAX in a game: a grub is an egg and 50 food).
const WATCH_GAP := 60.0
const WATCH_MAX := 4
var _watch_n := 0
var _watch_next := 70.0
var _watch_flee := false
var _foot := Vector2.INF            # the foot of the enemy's ramp (pixels), found once
var _foot_dir := Vector2.ZERO       # out from its foot, away from the enemy's main


func _nb_watch_scout(q: Unit, foe: int) -> void:
	if _scout != null and (not is_instance_valid(_scout) or _scout.dead):
		_scout = null
		_watch_flee = false
		_watch_next = game.clock + WATCH_GAP
	var st := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	if _scout == null:
		if game.clock < _watch_next or _watch_n >= WATCH_MAX or BroodNew.count_of(game, team, "grub") < 8:
			return
		var pick: Unit = null
		for u in _nb_mine("grub"):
			if u.carrying == 0 and u.order == "gather" and u.cocoon <= 0.0 and (pick == null \
					or u.position.distance_squared_to(st) < pick.position.distance_squared_to(st)):
				pick = u
		if pick == null:
			return
		_scout = pick
		_watch_n += 1
		_scout_trips += 1
		_scout_t0 = game.clock
		_watch_flee = false
		_scout_i = 0
		if _foe_is("crown"):
			if _foot == Vector2.INF:
				_find_foe_foot(foe, q)
			var c: Vector2 = _foot + _foot_dir * 5.0 * Defs.TILE if _foot != Vector2.INF else st
			var side := _foot_dir.orthogonal() * 3.0 * Defs.TILE
			_scout_pts = [c + side, c - side]
		else:
			var toward := (q.position - st).normalized()
			_scout_pts = [st + toward * 8.0 * Defs.TILE, st + toward.orthogonal() * 7.0 * Defs.TILE, st - toward * 6.0 * Defs.TILE,
				st - toward.orthogonal() * 7.0 * Defs.TILE, st]
		pick.auto_work = false
		pick.cmd_move(_scout_pts[0])
		say("sends a Grub to %s" % ("watch the foot of the enemy's ramp" if _foe_is("crown") else "explore the enemy's main"))
		return
	# danger: hurt, or soldiers close: home, back to work
	if not _watch_flee:
		var close := false
		for u in game.units_near(_scout.position, 6.5 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() \
					and game.is_visible_to(team, u.position):
				close = true
				break
		if close or _scout.hp < _scout.max_hp * 0.7:
			_watch_flee = true
			_scout.cmd_move(q.position)
			return
	else:
		if _scout.position.distance_to(q.position) < 10.0 * Defs.TILE or _scout.order == "idle":
			_scout.auto_work = true
			_scout.cmd_stop()          # (home: back to work)
			_scout = null
			_watch_flee = false
			_watch_next = game.clock + WATCH_GAP
		elif _scout.order != "move":
			_scout.cmd_move(q.position)
		return
	# on watch: to and fro (the Crown's ramp foot), or round its main
	if _scout.position.distance_to(_scout_pts[_scout_i]) < 1.5 * Defs.TILE or _scout.order == "idle":
		_scout_i = (_scout_i + 1) % _scout_pts.size()
		_scout.cmd_move(_scout_pts[_scout_i])


## The foot of the ramp up to the enemy's main nearest to us (Game.ramp_foot's walk through a ramp, from the enemy's
## plateau), and the way out from it.
func _find_foe_foot(foe: int, q: Unit) -> void:
	var hc := Vector2i(Vector2(game.starts[foe]) + Vector2(2.5, 2.0))
	if not game.in_map(hc):
		return
	var h0 := int(game.height[game.idx(hc)])
	var best := Vector2.INF
	var bd := INF
	for y in range(hc.y - 30, hc.y + 31):
		for x in range(hc.x - 30, hc.x + 31):
			var r := Vector2i(x, y)
			if not game.in_map(r) or game.ramp[game.idx(r)] != 1:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = r + dd
				if not game.in_map(p) or game.ramp[game.idx(p)] != 0 or int(game.height[game.idx(p)]) != h0:
					continue
				var f := r
				var steps := 0
				while game.in_map(f) and game.ramp[game.idx(f)] == 1 and steps < 12:
					f += -dd
					steps += 1
				if not game.in_map(f) or int(game.height[game.idx(f)]) == h0:
					continue
				var fp := (Vector2(f) + Vector2(0.5, 0.5)) * Defs.TILE
				var d := fp.distance_to(q.position)
				if d < bd:
					bd = d
					best = fp
					_foot_dir = Vector2(-dd).normalized()
	_foot = best


## THE ALARM'S REACTIONS (the owner's build; the alarm itself: _nb_observe) and, at any time, grubs pulled back:
##  - the grubs of a Rootmaw that enemy soldiers come near (9 tiles; not the Rootmaws by the Mother, where the army
##    fights) run to the Mother and wait there, then go back to work once the enemy has gone (or after 40 s);
##  - with the alarm on and a natural taken: a Mound Turtle from home (only with 12 supply to spare: rooted, it gives
##    the supply back) walks out in front of the natural, toward the enemy, and roots there (a tank in its way, very hard to
##    hurt); one at a time, it stays there. (Not ON the ramp: a rooted turtle closes it, and the natural's grubs walk up it.)
var _pulled := {}                  # grub -> [its Rootmaw, when]
var _front_t: Unit = null          # the turtle rooting (rooted) in front of the natural
var _front_done := false


func _nb_alarm(q: Unit) -> void:
	# grubs pulled back from a Rootmaw with enemy soldiers at it
	for u in _nb_mine("grub"):
		if u.order != "gather" or u == _scout or _pulled.has(u):
			continue
		var m = u.home_mine
		if m == null or not is_instance_valid(m) or (m as Unit).position.distance_to(q.position) < 14.0 * Defs.TILE:
			continue
		if _foe_near((m as Unit).position, 9.0 * Defs.TILE) or _foe_near(u.position, 6.0 * Defs.TILE):
			_pulled[u] = [m, game.clock]
			u.auto_work = false
			u.cmd_move(q.position)
	for u in _pulled.keys():
		if not is_instance_valid(u) or u.dead:
			_pulled.erase(u)
			continue
		var m = _pulled[u][0]
		var gone: bool = m == null or not is_instance_valid(m) or (m as Unit).dead or not _foe_near((m as Unit).position, 11.0 * Defs.TILE)
		if (gone and game.clock - float(_pulled[u][1]) > 8.0) or game.clock - float(_pulled[u][1]) > 40.0:
			_pulled.erase(u)
			u.auto_work = true
			if m != null and is_instance_valid(m) and not (m as Unit).dead and BroodNew.rooted(m):
				u.cmd_gather(m)
			else:
				u.cmd_stop()
	# a turtle in front of the natural
	if _front_t != null and (not is_instance_valid(_front_t) or _front_t.dead):
		_front_t = null
	if _front_t != null:
		if BroodNew.rooted(_front_t):
			_front_done = true
			say("a Mound Turtle roots in front of the natural")
			_front_t = null
		elif _front_t.tesla_mode == "packed" and _front_t.order != "nb_root" and _front_t.order != "move":
			var fs = _nb_front_spot(q)
			if fs != null:
				_root_to(_front_t, fs)
			else:
				_front_t = null
		return
	if _front_done or not _alarm_on():
		return
	var cap := int(game.players[team]["cap"])
	if cap - game.supply_used(team) < int(Defs.NB["turtle_supply"]) + 2:
		return
	var spot = _nb_front_spot(q)
	if spot == null:
		return
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9
	var pick: Unit = null
	for t in _nb_mine(BroodNew.TURTLE):
		if BroodNew.rooted(t) and t.position.distance_to(q.position) < far and not held.has(t) \
				and (pick == null or t.position.distance_to(spot) < pick.position.distance_to(spot)):
			pick = t
	if pick == null:
		return
	_front_t = pick
	BroodNew.uproot(pick, false)
	say("ALARM: a Mound Turtle gets up to root in front of the natural")


## In front of the natural: 6 tiles out from its turtle toward the enemy (or where the alarm saw the army), on a spot a
## turtle may root (not on a ramp: BroodRoot.place_problem for the computer).
func _nb_front_spot(q: Unit):
	var nat: Unit = null
	for u in BroodNew.expansions(game, q):
		if nat == null or u.position.distance_to(q.position) < nat.position.distance_to(q.position):
			nat = u
	if nat == null:
		return null
	var foe := _foe()
	var toward: Vector2 = (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE if foe >= 0 else alarm_at
	var dir := (toward - nat.position).normalized()
	for dist in [6.0, 5.0, 7.0, 4.0, 8.0]:
		for turn in [0.0, 0.35, -0.35, 0.7, -0.7]:
			var p: Vector2 = BroodRoot.snap(BroodNew.TURTLE, nat.position + dir.rotated(turn) * dist * Defs.TILE)
			if not _nb_on_map(p) or not game._walkable(game.cell_of(p)) or _spot_bad(p):
				continue
			if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, _front_t, true) == "":
				return p
	return null


## The Mother: rooted at home; she CANNOT ATTACK while rooted, so when enemies reach her she uproots and fights, and
## roots again once it is really calm (BroodNew.mother_guard). Only its own Mother: never the player's.
var _q_guard := {}


func _nb_mother(q: Unit) -> void:
	if q.team != team or bool(plan.get("mother_free", false)):
		return          # (mother_free: a coach walks her itself, tools/play_brood_3.gd)
	BroodNew.mother_guard(game, q, _q_guard, [1.6, 1.0, 0.6, 0.4][clampi(difficulty, 0, 3)])


# ------------------------------------------------------------------ the economy

func _nb_wanted_maws() -> int:
	var m: Array = plan["maws"]
	var n := mini(int(m[0]) + int(game.clock / float(m[1])), int(m[2]))
	n = mini(n, 2 + BroodNew.count_of(game, team, "grub") / 5)        # (no Rootmaw without grubs to crew it)
	if _rush_on():
		n = mini(n, 2)
	if int(plan["grubs0"]) > 0 and not _first_out:
		n = mini(n, int(plan.get("maws0", 2)))      # (a rush: the first wave before more ground)
	return n


var _first_out := false         # (the first wave has left)


## Supply ahead of need: one more Mound Turtle while the supply is within a few of the cap (more ahead later, when she
## lays faster), counting the ones on their way (cocoons, grubs going to turn into one, turtles walking to their spot).
func _nb_short() -> bool:
	var cap := int(game.players[team]["cap"])
	if cap >= game.max_supply(team):
		return false
	var coming := 0
	for u in game.units:
		if u.team == team and not u.dead and ((u.kind == BroodNew.TURTLE and not BroodNew.rooted(u)) \
				or (u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.TURTLE)):
			coming += int(Defs.NB["turtle_supply"])
	var ahead := 3 + int(game.clock / 60.0)
	if _food() >= 500:
		ahead += 12          # (food piling up: a turtle more ahead, the eggs it buys will be laid)
	if _eco() and game.clock > 75.0 and _nb_far_have(BroodNew.queen(game, team)) < _nb_far_wanted():
		ahead += 2          # (the next turtle walks out to new ground: it roots later than one at home; not in the first
		                    # minute, when every 50 food is a grub: the first turtle at 0:32 cost a minute of grubs)
	if int(plan["grubs0"]) > 0 and not _first_out:
		ahead = int(plan.get("ahead0", 3))          # (the Extreme rush: the turtle right after the Sire, so its Raptors never wait for supply)
	return game.supply_used(team) + ahead >= cap + coming


## Far turtles wanted by now (the plan's expansions), none while a rush is on.
func _nb_far_wanted() -> int:
	if _rush_on():
		return 0
	var n := 0
	for e in plan["far"]:
		if game.clock >= float(e[0]):
			n = int(e[1])
	return mini(n, int(Defs.NB["expansion_max"]))


func _nb_far_have(q: Unit) -> int:
	var n := 0
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	for u in game.units:
		if u.team == team and not u.dead and u.kind == BroodNew.TURTLE and u.position.distance_to(q.position) >= far * 0.9:
			n += 1
		elif u.team == team and not u.dead and u.kind == "grub" and u.order == "nb_morph" and String(u.nb.get("mk", "")) == BroodNew.TURTLE \
				and u.order_point.distance_to(q.position) >= far * 0.9:
			n += 1
	return n


## THE STRUCTURE-UNITS COME FROM GRUBS (the owner, 19:19; scripts/brood_root.gd): one at a time, the computer picks
## what it needs (a Mound Turtle for supply, a Sire's lure, a turtle on new ground, more Rootmaws), a spot that passes
## the same ROOT placement checks as the player's ghost (BroodRoot.place_problem, keeping its ramps clear), and the
## grub nearest it.
var _morph_keep := 0             # food kept for the structure-unit it saves for, or a grub on its way pays on arrival


func _nb_morphs(q: Unit) -> void:
	_morph_keep = 0
	var walking := 0
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "grub" and u.order == "nb_morph":
			_morph_keep += int(game.unit_price(team, String(u.nb.get("mk", "grub")))[0])       # (it pays when it gets there)
			walking += 1
	# one at a time; a second only with food to spare (brood-eco: with the owner's economy the food came faster than one
	# grub at a time could turn it into turtles, and 900+ food sat for minutes at the supply cap)
	if walking >= 2 or (walking == 1 and _food() - _morph_keep < 400):
		return
	var grubs := BroodNew.count_of(game, team, "grub")
	var maws := BroodNew.count_of(game, team, BroodNew.MAW)
	var k := ""
	var spot = null
	var tyrant := BroodNew.count_of(game, team, BroodNew.FATHER) > 0
	if not tyrant and (grubs >= int(plan["sire_g"]) or game.clock > float(plan["sire_t"]) or _rush_on() or _alarm_on()) and maws >= 1:
		k = BroodNew.FATHER         # (the first Sire: the warriors' line)
	elif _nb_short():
		k = BroodNew.TURTLE
		if _nb_far_have(q) < _nb_far_wanted():
			var fp := _nb_far_spots(q)          # (a turtle on new ground gives the same supply: the expansion first)
			if not fp.is_empty():
				spot = fp[0]
	elif _nb_next_father(q) != "":
		k = _nb_next_father(q)
	elif maws < _nb_wanted_maws() and (maws < 2 or _food() >= 100) and (maws < 3 or not _nb_saving_growth(q)):
		k = BroodNew.MAW
	elif _nb_far_have(q) < _nb_far_wanted() and not _nb_saving_growth(q):          # (her stage before more ground: the Economy plan never grew her)
		var picks := _nb_far_spots(q)
		if not picks.is_empty():
			k = BroodNew.TURTLE
			spot = picks[0]
	if k != "" and BroodRoot.morph_problem(game, team, k).begins_with("Need more supply"):
		k = BroodNew.TURTLE          # (a Sire takes more supply than his grub: a turtle first)
		spot = null
	if k == "" or grubs < 3:
		return
	var why := BroodRoot.morph_problem(game, team, k)
	if why != "":
		if why.begins_with("Not enough") and _food() < int(game.unit_price(team, k)[0]):
			_morph_keep += int(game.unit_price(team, k)[0])      # (saving for it: the eggs wait; only when FOOD is what is short:
			                                                    # food kept for a Sire whose spoils were short stalled eggs and Rootmaws)
		return
	if spot == null:
		spot = _nb_spot_for(q, k, null)
	if spot == null:
		return
	var best: Unit = null
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "grub" and u.carrying == 0 and u.cocoon <= 0.0 and u.order != "nb_morph" \
				and u != _scout and (best == null or u.position.distance_squared_to(spot) < best.position.distance_squared_to(spot)):
			best = u
	if best != null:
		best.give({"o": "nb_morph", "k": k, "p": spot})
		_morph_keep += int(game.unit_price(team, k)[0])      # (it pays when it gets there: the eggs leave it the price)
		if BroodNew.is_father(k):
			say("a grub goes to grow the %s" % BroodRoot.lure_name(k))
		elif k == BroodNew.TURTLE and (spot as Vector2).distance_to(q.position) >= float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9:
			_far_sent[str((spot as Vector2).round())] = game.clock
			_far_last = game.clock
			say("a grub goes to root a Mound Turtle on new ground, %d tiles out" % int((spot as Vector2).distance_to(q.position) / Defs.TILE))


## The best free turtle spots on new ground (ExpansionSpots.nb_pick: room for Rootmaws, ways in, walk, safety), reachable.
var _far_sent := {}               # far spot -> when a grub was last sent there (a grub killed on the way: not again soon)
var _far_last := -999.0


func _nb_far_spots(q: Unit) -> Array:
	var out: Array = []
	if game.exp_spots == null or game.clock - _far_last < 45.0:
		return out
	var picks: Array = _nb_eco_sites(q) if _eco() else ExpansionSpots.nb_pick(game, team, game.exp_spots)
	for s in picks:
		var p := BroodRoot.feet_at(BroodNew.TURTLE, s["tc"])
		if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, null, true) != "":
			continue
		if game.clock - float(_far_sent.get(str(p.round()), -999.0)) < 180.0:
			continue          # (tried lately: the grub did not get there)
		if p.distance_to(q.position) > (28.0 if _eco() and not BroodNew.expansions(game, q).is_empty() else 30.0) * Defs.TILE:
			continue          # (too far to guard: near the enemy's side)
		if _foe_near(p, 12.0 * Defs.TILE):
			continue
		out.append(p)
	return out


## THE OWNER'S BUILD (2026-10-30 07:15, docs/brood_eco.md): the plan's "eco" (every profile but the rushes). The first
## Mound Turtle goes on the NATURAL expansion (the nearest turtle spot by walk that counts as new ground), the third
## Rootmaw at the natural's FAR edge (the farther a load comes, the more it pays and the more grubs a Rootmaw takes:
## Game.food_at, BroodNew.crew_max), grubs nonstop, the second turtle on the THIRD expansion with a Rootmaw there.
func _eco() -> bool:
	return bool(plan.get("eco", false))


## The turtle spots on new ground in WALK order (the natural first, then the third), free and fresh as nb_pick has them
## (ExpansionSpots: its candidates, rated once; nb_pick's tests, without its "two best" cut).
func _nb_eco_sites(q: Unit) -> Array:
	var es: ExpansionSpots = game.exp_spots
	ExpansionSpots.nb_pick(game, team, es)          # (rates the candidates once)
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE
	var counted: Array = BroodNew.expansions(game, q)
	var out: Array = []
	for s in es.nb_cands.get(team, []):
		var feet := BroodRoot.feet_at(BroodNew.TURTLE, s["tc"])
		if q.position.distance_to(feet) < far or counted.any(func(o: Unit) -> bool: return o.position.distance_to(feet) < far):
			continue
		var taken := false
		for u in game.units_near(feet, 7.0 * Defs.TILE):
			if u.team == team and u.kind == BroodNew.TURTLE and not u.dead and u.tesla_mode != "packed":
				taken = true
		if taken or es._taken(s["c"]) or BroodRoot.place_problem(game, team, BroodNew.TURTLE, feet).begins_with("Blocked"):
			continue
		var spent := false
		for id in game.nb_spots:
			var sp: Dictionary = game.nb_spots[id]
			if (sp["p"] as Vector2).distance_to(feet) < float(Defs.NB["turtle_swamp"]) * Defs.TILE and float(sp["left"]) < float(Defs.PIT_GROUND) * 0.5:
				spent = true
		if not spent:
			out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["home"]) < float(b["home"]))
	return out


func _foe_near(p: Vector2, r: float) -> bool:
	for u in game.units_near(p, r):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() and game.is_visible_to(team, u.position):
			return true
	return false


## The later Sires, in the plan's order and time: the Storm Sire first when the enemy flies (it needs her stage 2 and
## 50 spoils), else the Venom Sire at the plan's time, the Storm Sire at his. One of each.
func _nb_next_father(q: Unit) -> String:
	if BroodNew.count_of(game, team, BroodNew.FATHERS[0]) == 0 or BroodNew.count_of(game, team, BroodNew.MAW) < 2:
		return ""
	if _rush_on() and game.clock < 300.0:
		return ""          # (warriors first while a rush is on)
	var order: Array = [BroodNew.DILO, BroodNew.PTERO]
	var storm_t := float(plan["storm"])
	if seen_air >= 2:
		order = [BroodNew.PTERO, BroodNew.DILO]
		storm_t = 0.0
	for f in order:
		var at := float(plan["venom"]) if f == BroodNew.DILO else storm_t
		if game.clock < at or BroodNew.count_of(game, team, f) > 0:
			continue
		if BroodNew.stage(q) < BroodNew.father_stage(f) or BroodRoot.morph_problem(game, team, f) != "":
			if f == BroodNew.PTERO and seen_air >= 2:
				return ""          # (wait for him: her stage 2 and his spoils come first)
			continue
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
	for ring in [7.0, 9.0, 11.0, 13.0]:
		for i in 12:
			var p: Vector2 = BroodRoot.snap(BroodNew.TURTLE, q.position + Vector2.from_angle(TAU * i / 12.0 + ring) * ring * Defs.TILE)
			var c := game.cell_of(p)
			if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
				continue
			if BroodRoot.place_problem(game, team, BroodNew.TURTLE, p, me, true) != "" or _spot_bad(p):
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
			if BroodRoot.place_problem(game, team, k, p, me, true) != "" or BroodRoot.rect_for(k, p).intersects(_nb_mother_ground(q)) or _spot_bad(p):
				continue
			if best == null or p.distance_to(from) < (best as Vector2).distance_to(from):
				best = p
		if best != null:
			return best
	return null


## A Mound Turtle that is up (it was uprooted): walked to a spot and rooted there (ROOT like BUILD).
func _nb_turtles(q: Unit) -> void:
	for t in _nb_mine(BroodNew.TURTLE):
		if t.tesla_mode != "packed" or t.order == "nb_root" or t.target != null or held.has(t) or t == _front_t:
			continue
		var goal = _nb_turtle_spot(q, t)
		if goal != null:
			_root_to(t, goal)


func _nb_rootmaws(q: Unit) -> void:
	for m in _nb_mine(BroodNew.MAW):
		if BroodNew.rooted(m) and float(m.nb.get("food", 0.0)) < 1.0 and BroodNew.ground_left(game, m) < 1.0:
			BroodNew.uproot(m, true)          # spent: off to fresh ground
			continue
		if m.tesla_mode != "packed" or m.target != null or m.order == "nb_root" or held.has(m):
			continue
		var goal = _nb_find_spot(q, m)
		if goal != null:
			_root_to(m, goal)        # (it walks there and roots on that spot)


## ROOT a creature at a spot (ROOT like BUILD). A spot it was sent to lately and never rooted on (blocked, or no way to
## it: a Tyrant Sire walked to the same unreachable nest for five minutes in a test game, and no Raptor was laid) is
## left alone for 3 minutes; the spot finders skip it (_spot_bad).
var _root_last := {}            # creature id -> [spot, clock]
var _nb_bad_spots := {}            # spot (rounded) -> until when


func _root_to(u: Unit, p: Vector2) -> void:
	var id: int = u.get_instance_id()
	var last = _root_last.get(id)
	if last != null and (last[0] as Vector2).distance_to(p) < Defs.TILE and game.clock - float(last[1]) < 40.0:
		_nb_bad_spots[str(p.round())] = game.clock + 180.0
		_root_last.erase(id)
		return
	if last == null or (last[0] as Vector2).distance_to(p) >= Defs.TILE:
		_root_last[id] = [p, game.clock]
	u.give({"o": "nb_root", "p": p})


## A creature on its way to root for more than 30 s (it can't get there: jostled on a crowded spot, a path that never
## ends) is stopped and the spot left alone; it is sent somewhere else on the next think.
var _root_since := {}           # creature id -> [spot, clock first seen on its way there]


func _nb_root_watch() -> void:
	var seen := {}
	for u in game.units:
		if u.team != team or u.dead or u.order != "nb_root":
			continue
		var id: int = u.get_instance_id()
		seen[id] = true
		var r = _root_since.get(id)
		if r == null or (r[0] as Vector2).distance_to(u.order_point) > 1.0:
			_root_since[id] = [u.order_point, game.clock]
		elif game.clock - float(r[1]) > 30.0:
			_nb_bad_spots[str(u.order_point.round())] = game.clock + 180.0
			_root_since.erase(id)
			u.cmd_stop()
	for id in _root_since.keys():
		if not seen.has(id):
			_root_since.erase(id)


func _spot_bad(p: Vector2) -> bool:
	for k in _nb_bad_spots.keys():
		if game.clock > float(_nb_bad_spots[k]):
			_nb_bad_spots.erase(k)
			continue
		var v = str_to_var("Vector2" + String(k))
		if v is Vector2 and (v as Vector2).distance_to(p) < 2.0 * Defs.TILE:
			return true
	return false


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


## A Rootmaw's spot: on the swamp round the Mother first, then round the turtles on new ground (their swamp; a far
## turtle with Rootmaws round it is a real expansion), on fresh ground, a little away from the enemy.
func _nb_find_spot(q: Unit, m: Unit):
	var centres: Array = [[q.position, [8.0, 11.0, 14.0, 17.0, 20.0]]]
	var far := float(Defs.NB["expansion_tiles"]) * Defs.TILE * 0.9
	for t in _nb_mine(BroodNew.TURTLE):
		if BroodNew.rooted(t) and t.position.distance_to(q.position) >= far:
			centres.append([t.position, [4.5, 6.0, 7.5]])
	var from: Vector2 = m.position if m != null else q.position
	var best = null
	var bs := INF
	for ci in centres.size():
		var cpos: Vector2 = centres[ci][0]
		var h := int(game.height[game.idx(game.cell_of(cpos))])
		var home := BroodRoot.home_region(game, cpos)
		for ring in centres[ci][1]:
			for i in 16:
				var p: Vector2 = BroodRoot.snap(BroodNew.MAW, cpos + Vector2.from_angle(TAU * i / 16.0 + ring * 0.13) * ring * Defs.TILE)
				var c := game.cell_of(p)
				if not _nb_on_map(p) or not game._walkable(c) or game.region_of(c) != home:
					continue
				# (the ROOT checks: its footprint, on its side's swamp, its circle clear of the others' and of their plans)
				if not _nb_spot_ok(p) or BroodRoot.place_problem(game, team, BroodNew.MAW, p, m, true) != "" or _spot_bad(p):
					continue
				var s := p.distance_to(q.position) * (1.0 if ci == 0 else 0.6) + (60.0 if int(game.height[game.idx(c)]) != h else 0.0) + p.distance_to(from) * 0.3
				if _eco():
					# (the owner's build: a Rootmaw at the FAR edge of the ground it roots on, the expansions first: a load
					# from farther pays more and the Rootmaw takes more grubs; its draw is the same, so fewer eggs make it pay)
					s = -p.distance_to(q.position) * 0.5 + (0.0 if ci > 0 else 400.0) + (60.0 if int(game.height[game.idx(c)]) != h else 0.0) + p.distance_to(from) * 0.1
				var foe := _nb_nearest_foe_pos(p)
				if foe != Vector2.INF:
					s -= foe.distance_to(p) * 0.15         # (a little away from the enemy)
				if _foe_near(p, 10.0 * Defs.TILE):
					s += 2000.0
				if s < bs:
					bs = s
					best = p
	return best


func _nb_nearest_foe_pos(p: Vector2) -> Vector2:
	var best := Vector2.INF
	for o in game.enemies_of(team):
		var c: Vector2 = (Vector2(game.starts[o]) + Vector2(2.5, 2.0)) * Defs.TILE
		if best == Vector2.INF or c.distance_to(p) < best.distance_to(p):
			best = c
	return best


# ------------------------------------------------------------------ the Sires

## Each Sire: walked (flown) to a nest spot beside the Mother (ROOT like BUILD) and rooted there (he is one of the
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
		if d > reach or (threat and _nb_sires_needed(q)):
			f.cmd_uproot(false)       # (no rooted creature attacks: to fight off a real attack at the Mother he gets up)
		return
	if threat and _nb_sires_needed(q):
		return          # (uprooted, he fights with the others: _nb_army; a scout or a few raiders near her do not keep him off his nest)
	if f.tesla_mode == "packed" and d > 14.0 * Defs.TILE and f.order != "move" and f.order != "nb_root":
		# (on a leash: an enemy he chased off from her could lead him across the map, and while he is away her
		# warrior eggs wait for him; seen in a 0.18.0 match, the Tyrannosaur 62 tiles off with 1,600 food banked)
		f.cmd_move(q.position)
		return
	if f.tesla_mode == "packed" and f.target != null and not _nb_sires_needed(q):
		f.cmd_stop()          # (a fight he picked up by himself, nothing at the Mother: back to his nest)
	if f.tesla_mode != "packed" or f.target != null or f.order == "nb_root":
		return
	var spot = _nb_father_spot(q, f, f.kind)
	if spot != null:
		_root_to(f, spot)
	elif d > 14.0 * Defs.TILE and f.order != "move":
		f.cmd_move(q.position)       # (on a leash: by her, never off after a scout)


# ------------------------------------------------------------------ eggs

## GROW her (the owner's tiers, 12:20: Hatchlings and the Storm Sire need her stage 2; Brutes, Mist Toads and Storm
## Challengers stage 3): from the plan's times it SAVES for it (_nb_saving_growth: warriors only out of what is above
## the price) and grows her once the price is there; never while enemies are at her or a rush is on.
func _nb_grow(q: Unit) -> void:
	if BroodNew.grow_problem(game, q) != "" or _nb_threat(q) != Vector2.INF or BroodResearch.busy(q):
		return
	var st := BroodNew.stage(q)
	if st >= (Defs.NB["stages"] as Array).size() - 1 or game.clock < float(plan["grow"][st]):
		return
	if _rush_on() and st == 0:
		return
	if not _nb_grow_time(q):
		return
	if BroodNew.count_of(game, team, BroodNew.FATHER) == 0:
		return          # (the Tyrant Sire first: without him no warriors at all)
	var nx: Dictionary = Defs.NB["stages"][st + 1]
	if _food() >= int(nx["cost"]) + _morph_keep and _spoils() >= float(nx.get("cost2", 0)):
		if BroodNew.grow(game, q) == "":
			say("grows the Mother to stage %d" % (st + 2))


## Food kept back for her next stage (from the plan's time on): warrior eggs only out of what is above it. Grubs and
## supply go on. Her stage 3 also wants its spoils (kept by _nb_spoils_keep).
## THE OWNER'S BUILD: her growth only once EGGS are what holds the Brood back (her clutch run down: EGG_LOW or fewer in
## the last EGG_BOUND s), or GROW_LATE s after the plan's time at the latest. In the first coached games of this round
## her clutch sat FULL (10 eggs) until 8:00: food, not eggs, held the Brood back, and 300 food and 45 s without laying
## for her stage 2 only took a minute of grubs away. (The Air rush keeps its times: the Storm line needs her stages.)
const EGG_LOW := 2
const EGG_BOUND := 45.0
const GROW_LATE := 240.0
var _egg_low_t := -999.0


func _nb_grow_time(q: Unit) -> bool:
	if not _eco() or strategy == "air" or bool(plan.get("grow_now", false)):
		return true
	var st := BroodNew.stage(q)
	return game.clock - _egg_low_t < EGG_BOUND or game.clock >= float(plan["grow"][mini(st, 1)]) + GROW_LATE


func _nb_growth_keep(q: Unit) -> int:
	var st := BroodNew.stage(q)
	if st >= (Defs.NB["stages"] as Array).size() - 1 or float(q.nb.get("grow_t", 0.0)) > 0.0 or _rush_on():
		return 0
	if game.clock < float(plan["grow"][st]) or BroodNew.count_of(game, team, BroodNew.FATHER) == 0 or not _nb_grow_time(q):
		return 0
	var need2 := float(Defs.NB["stages"][st + 1].get("cost2", 0))
	if need2 > 0.0 and _spoils() < need2 * 0.6:
		return 0          # (her spoils are far off: saving food for her meanwhile only starves the army, round 2's trap)
	return int(Defs.NB["stages"][st + 1]["cost"])


func _nb_saving_growth(q: Unit) -> bool:
	return _nb_growth_keep(q) > 0 and _food() < _nb_growth_keep(q)


## Spoils kept for what comes first: her stage 3 (from its time), the Storm Sire (when wanted).
func _nb_spoils_keep(q: Unit) -> float:
	var keep := 0.0
	if _food() >= 900:
		return 0.0          # (a big bank: spend it, warriors and moults first; never sit on food for spoils)
	var st := BroodNew.stage(q)
	if st == 1 and game.clock >= float(plan["grow"][1]) - 60.0 and _food() >= int(Defs.NB["stages"][2]["cost"]) - 150:
		keep = maxf(keep, float(Defs.NB["stages"][2]["cost2"]))      # (only once her food is nearly there: else the spoils work meanwhile)
	if st >= 1 and BroodNew.count_of(game, team, BroodNew.PTERO) == 0 and (seen_air >= 2 or game.clock >= float(plan["storm"]) - 30.0):
		keep = maxf(keep, float(Defs.UNITS[BroodNew.PTERO].get("cost2", 0)))
	if BroodNew.count_of(game, team, BroodNew.DILO) == 0 and game.clock >= float(plan["venom"]) - 45.0 and float(Defs.UNITS[BroodNew.DILO].get("cost2", 0)) > 0.0:
		keep = maxf(keep, float(Defs.UNITS[BroodNew.DILO].get("cost2", 0)))      # (the Venom Sire's spoils, when he costs any)
	return keep


## SPOILS (her stage 3, the Storm Sire, research, Brutes, Spitters, Hatchlings, maturing): grubs HARVEST the bodies near
## home (two at most, while there are bodies); and while that is not enough for what is wanted NOW, a Raptor at home
## (not in a wave, a home guard always kept) is offered up at the Mother (SACRIFICE), one every 4 s at most; none
## during an attack on her.
var _nb_offer_t := 0.0


func _nb_spoils_want(q: Unit) -> float:
	var want := _nb_spoils_keep(q)
	if BroodNew.count_of(game, team, BroodNew.FATHER) > 0 and game.clock >= 150.0 and not game.has_tech(team, "nb_clutch_raptor"):
		want = maxf(want, float(Defs.RESEARCH["nb_clutch_raptor"]["cost2"]) + 2.0)
	if bool(plan["pack"]) and not game.has_tech(team, "nb_pack_hunt") and _army_supply_now() * 10 >= _attack_at * 5:
		want = maxf(want, float(Defs.RESEARCH["nb_pack_hunt"]["cost2"]) + 2.0)
	if BroodNew.stage(q) >= 2 and (seen_wall or BroodNew.count_of(game, team, "brute") >= 2) and not game.has_tech(team, "nb_battering_horns"):
		want = maxf(want, float(Defs.RESEARCH["nb_battering_horns"]["cost2"]))
	if BroodNew.stage(q) >= 2:
		want = maxf(want, 45.0)          # (Brutes and Challengers)
	if _wall_foe() and BroodNew.count_of(game, team, BroodNew.DILO) > 0:
		want = maxf(want, 25.0)          # (against a wall: Spitters, 5 spoils an egg)
	if float(plan.get("spoils_bank", 0.0)) > 0.0 and BroodNew.count_of(game, team, BroodNew.FATHER) > 0 and game.clock >= 150.0:
		want = maxf(want, float(plan["spoils_bank"]))     # (the air rush: the Storm line's spoils, from offered-up Raptors)
	return want


## Raptors to be laid for spoils: the plan banks spoils ("spoils_bank": the Air rush) or its Storm Sire / her stage 3
## waits for them, and the spare Raptors at home are not enough to cover what is short.
func _nb_feed_raptors(q: Unit) -> bool:
	if float(plan.get("spoils_bank", 0.0)) <= 0.0 or _rush_on() or _attacking:
		return false
	var short := _nb_spoils_want(q) - _spoils()
	if short <= 0.0:
		return false
	var spare := _nb_mine("raptor").filter(func(u: Unit) -> bool: return u.position.distance_to(q.position) < 16.0 * Defs.TILE \
		and not _wave.has(u)).size() - maxi(2, int(plan["home_guard"]))
	return float(spare) * float(Game.sacrifice_value("raptor")) < short


func _nb_essence(q: Unit) -> void:
	var want := _nb_spoils_want(q)
	var have := _spoils()
	var grubs := _nb_mine("grub")
	var bodies := game.corpses.filter(func(c) -> bool: return is_instance_valid(c) and c.position.distance_to(q.position) < 22.0 * Defs.TILE)
	var harvesting := grubs.filter(func(u: Unit) -> bool: return u.order == "harvest")
	if not bodies.is_empty() and _nb_threat(q) == Vector2.INF:
		for u in grubs:
			if harvesting.size() >= mini(5, 2 + bodies.size() / 4):        # (bodies pay double since 0.22.4 and each harvest feeds her veterancy)
				break
			if u.order == "gather" and u.carrying == 0 and not harvesting.has(u) and u != _scout:
				u.cmd_harvest()
				harvesting.append(u)
	elif bodies.is_empty():
		for u in harvesting:
			if u.cocoon <= 0.0:
				u.cmd_stop()          # (no bodies left: back to work, WORK finds it a Rootmaw)
	if have >= want or game.clock < _nb_offer_t or _nb_threat(q) != Vector2.INF or _rush_on() \
			or (int(plan["grubs0"]) > 0 and not _first_out):          # (a rush keeps every Raptor for its first wave)
		return
	var raptors := _nb_mine("raptor").filter(func(u: Unit) -> bool: return u.position.distance_to(q.position) < 16.0 * Defs.TILE \
		and u.target == null and u.order != "sacrifice" and not _wave.has(u) and u != _scout)      # (at home, not fighting)
	if raptors.size() <= maxi(2, int(plan["home_guard"])):
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
	var food := _food()
	var grubs := BroodNew.count_of(game, team, "grub")
	var want_grubs := _nb_want_grubs()
	var k := ""
	# saving up for a structure-unit the economy needs: warriors only out of what is above its price
	var keep := _morph_keep          # (the structure-unit it saves for, or the one a grub is walking to: _nb_morphs)
	if _nb_short():
		keep = maxi(keep, 100)
	elif BroodNew.count_of(game, team, BroodNew.FATHER) == 0 and grubs >= int(plan["sire_g"]) - 1:
		keep = maxi(keep, int(Defs.UNITS[BroodNew.FATHER]["cost"]))          # (the Tyrant Sire's lure first)
	keep = maxi(keep, _nb_growth_keep(q) + (_morph_keep if _nb_growth_keep(q) > 0 else 0))
	var any_father := BroodNew.FATHERS.any(func(f) -> bool: return BroodNew.father_near(game, team, f))
	# grubs on the plan's curve ("drone": grubs a minute, from the 5 it starts with) come before warriors, unless the enemy
	# is at the Mother or a rush is on; above the curve only with food to spare
	var curve := 5.0 + game.clock / 60.0 * float(plan.get("drone", 4.0))
	var danger := _nb_threat(q) != Vector2.INF or _rush_on() or _alarm_on() or (_under_armed() and grubs >= 16)
	if grubs < want_grubs and (grubs < 6 or not any_father or (grubs < curve and not danger) or food - keep >= 200):
		k = "grub"
	# SPOILS FROM RAPTORS (the owner, 07:15: the Storm line and the Air rush are paid by offering Raptors up): while the
	# spoils wanted now are short and too few spare Raptors stand at home to offer, a Raptor egg comes before the grub
	# curve (with 12 grubs or more); _nb_essence offers them up as they hatch
	if k == "grub" and grubs >= 12 and _nb_feed_raptors(q) and BroodNew.father_near(game, team, BroodNew.FATHER) and food - keep >= 50:
		k = "raptor"
	if k == "" and any_father:
		k = _nb_warrior(food - keep)
	if k == "" or BroodNew.lay_problem(game, q, k) != "":
		if grubs < want_grubs and BroodNew.lay_problem(game, q, "grub") == "" and (food - 50 >= keep - (_nb_growth_keep(q) if grubs * 10 < want_grubs * 7 else 0) or grubs < 6):
			k = "grub"
		else:
			return
	if k == "grub" and food - 50 < keep - (_nb_growth_keep(q) if grubs * 10 < want_grubs * 7 else 0) and grubs >= 6:
		return          # (the workforce is far short: grubs come before her growth's savings)
	BroodNew.lay(game, q, k)


## Grubs wanted: a crew for each rooted Rootmaw (and those on their way), a couple to turn into things; held at the
## plan's early count until the first wave has left (a rush), never above its cap.
func _nb_want_grubs() -> int:
	var crew := 0
	for m in _nb_mine(BroodNew.MAW):
		crew += BroodNew.crew_max(game, m) if BroodNew.rooted(m) else 3
	var n := maxi(crew + 2, 6)
	if int(plan["grubs0"]) > 0 and not _first_out:
		n = mini(n, int(plan["grubs0"]))
	if _rush_on() and game.clock < 300.0:
		n = mini(n, 14)
	return mini(n, int(plan["grubs"]))


## Which warrior egg out of `spend` food (what is above the reserve): a mix by the lines it has (each line only while
## its Sire is rooted beside her and not researching) and by her stage; the plan's mix decides the share of Spitters.
## HATCHLINGS only against enemy flyers it has SEEN (they bite only flyers: docs/storm_line.md), about two for each, and
## at her stage 3 a few more to mature into Storm Challengers. A Brute now and then at stage 3 (more against a wall), a
## Mist Toad per 12 army supply (up to 3).
func _nb_warrior(spend: int) -> String:
	var q := BroodNew.queen(game, team)
	var st := BroodNew.stage(q) if q else 0
	var spoils := _spoils() - _nb_spoils_keep(q)
	var trex := BroodNew.father_near(game, team, BroodNew.FATHER) and not BroodResearch.line_busy(game, team, BroodNew.FATHER)
	var dilo := BroodNew.father_near(game, team, BroodNew.DILO) and not BroodResearch.line_busy(game, team, BroodNew.DILO)
	var ptero := BroodNew.father_near(game, team, BroodNew.PTERO) and st >= BroodNew.unit_stage("hatchlings") and not BroodResearch.line_busy(game, team, BroodNew.PTERO)
	var toads_ok := dilo and st >= BroodNew.unit_stage("mist_toad")
	var brutes_ok := trex and st >= BroodNew.unit_stage("brute")
	var raptors := BroodNew.count_of(game, team, "raptor") + BroodNew.count_of(game, team, "tyrant_challenger")
	var spitters := BroodNew.count_of(game, team, "spitter") + BroodNew.count_of(game, team, "venom_challenger")
	var toads := BroodNew.count_of(game, team, "mist_toad")
	var brutes := BroodNew.count_of(game, team, "brute")
	var hatch := BroodNew.count_of(game, team, "hatchlings")
	var storm := BroodNew.count_of(game, team, "storm_challenger")
	var army := _army_supply_now()
	var price := func(k: String) -> Array: return game.unit_price(team, k)
	if ptero and spoils >= float(price.call("hatchlings")[1]) and spend >= int(price.call("hatchlings")[0]):
		var air := hatch + storm * 2
		if (seen_air > 0 and air < mini(HATCH_MAX, seen_air * HATCH_PER_FLYER)) \
				or (st >= BroodNew.unit_stage("storm_challenger") and hatch + storm < STORM_WANT and raptors + spitters >= 6) \
				or (hatch + storm < int(plan.get("storm_want", 0))):          # (the air plan: Hatchlings to mature into Storm Challengers)
			return "hatchlings"
	if toads_ok and spoils >= 25.0 and spend >= 100 and toads < mini(3, army / 12):
		return "mist_toad"
	if brutes_ok and spoils >= 20.0 and spend >= 150 and brutes < (6 if seen_wall else 4) and brutes * 6 < raptors + spitters + 2:
		return "brute"
	var venom_share := {"tyrant": 4, "mixed": 2, "venom": 1}.get(String(plan["mix"]), 2) as int      # (one Spitter for this many Raptors)
	if _wall_foe() and String(plan["mix"]) != "tyrant":
		venom_share = 1          # (round 3: Raptors alone die on a musket wall; Spitters reach the shooters)
	var sp_price: Array = price.call("spitter")
	if dilo and spoils >= float(sp_price[1]) and spend >= int(sp_price[0]) and (not trex or spitters * venom_share < raptors + 2):
		return "spitter"
	if trex and spend >= int(price.call("raptor")[0]):
		return "raptor"
	if dilo and spoils >= float(sp_price[1]) and spend >= int(sp_price[0]):
		return "spitter"
	return ""


## MATURE (YOUNG AND MATURE, scripts/brood_mature.gd): young units resting near home (no target, not in a wave) mature
## when food piles up (the plan's "bank") or while an attack gathers ("push": the wave's young first), up to
## MATURE_EACH a think, keeping MATURE_KEEP food back; at most half of each young kind (both forms matter: the young
## ones' numbers, the mature ones' toughness). Hatchlings all mature when no enemy flyer was seen (they are useless
## against the ground), half with flyers about.
const MATURE_FOOD := 300
const MATURE_KEEP := 150
const MATURE_EACH := 2
## The Storm line (docs/storm_line.md): Hatchlings for each enemy flyer seen, at most; the Storm line it keeps at her stage 3
const HATCH_PER_FLYER := 2
const HATCH_MAX := 16
const STORM_WANT := 4


func _nb_mature(q: Unit) -> void:
	if _nb_saving_growth(q) or BroodNew.stage(q) < 1:
		return
	var food := _food()
	var push: bool = String(plan["mature"]) == "push" and _army_supply_now() * 10 >= _attack_at * 7 and not _attacking
	if food < (MATURE_FOOD if not push else 200):
		return
	var n := 0
	for yk in Defs.NB["mature"]:
		var mk := String(Defs.NB["mature"][yk])
		if BroodNew.stage(q) < BroodNew.unit_stage(mk):
			continue
		var young := _nb_mine(String(yk))
		var grown := _nb_mine(mk).size()
		var all_up: bool = yk == "hatchlings" and seen_air == 0
		for u in young:
			if n >= MATURE_EACH or (grown * 2 >= young.size() + grown and not all_up):
				break
			if u.moult_t >= 0.0 or (u.target != null and is_instance_valid(u.target)) or in_wave(u) or u == _scout \
					or u.position.distance_to(q.position) > 22.0 * Defs.TILE:
				continue
			var p := BroodMature.price(game, team, u.kind)
			if _food() - int(p[0]) < MATURE_KEEP + _morph_keep or _spoils() - float(p[1]) < _nb_spoils_keep(q) or BroodMature.problem(u) != "":
				continue
			BroodMature.start(u)
			n += 1
			grown += 1


# ------------------------------------------------------------------ research

## THE BROOD'S RESEARCH (scripts/brood_research.gd), sensibly and without starving the army (docs/design_principles.md 4:
## every choice an opportunity cost): never with enemies at her or while saving for her growth; only with the price
## and a reserve in hand; ONE Sire researching at a time (a Sire researching fathers nothing, so the army keeps coming
## from the others; the Tyrant Sire's research only while the Mother has eggs stocked); the Mother's alongside. In order:
##  - BIGGER CLUTCH on the Raptors early (from about 2:30, once a few Raptors stand);
##  - PACK HUNT before the first attack (the plan's "pack": the army at half the wave) or while attacking;
##  - BATTERING HORNS before a siege: her stage 3 with Brutes, or a wall seen;
##  - the Venom line's BIGGER CLUTCH once Spitters are laid (4), SLITHER and LONG SPIT with 6 of the line;
##  - the Storm line's BIGGER CLUTCH with 4 Hatchlings and flyers seen (3 or more); UPDRAFT with 4 of the line;
##  - QUICK ROOTS mid game (her stage 2, from 8:00), SWAMP MENDING later (from 10:00, food to spare).
const RES_KEEP := 100


func _nb_research(q: Unit) -> void:
	if _nb_threat(q) != Vector2.INF or (_nb_saving_growth(q) and BroodNew.stage(q) == 0) or peaceful or (_rush_on() and game.clock < 300.0):
		return
	var food := _food()
	var spoils := _spoils()
	var keep := RES_KEEP + (150 if difficulty == 0 else 0) + _morph_keep
	var st := BroodNew.stage(q)
	var keep2 := _nb_spoils_keep(q)
	var sup := _army_supply_now()
	var sire_busy := BroodNew.FATHERS.any(func(f) -> bool: return BroodResearch.busy(BroodNew.father(game, team, f)))
	var line := func(k: String) -> int: return BroodNew.count_of(game, team, k)
	var soon: bool = _attacking or sup * 10 >= _attack_at * 5
	var want: Array = []
	if not sire_busy:
		if bool(plan["pack"]) and soon and line.call("raptor") + line.call("tyrant_challenger") >= 6:
			want.append("nb_pack_hunt")
		if game.clock >= (210.0 if strategy in ["rush", "xrush"] else 150.0) and line.call("raptor") >= 4:
			want.append("nb_clutch_raptor")
		if (soon or _attacking) and line.call("raptor") + line.call("tyrant_challenger") >= 10:
			want.append("nb_pack_hunt")
		if st >= 2 and (line.call("brute") >= 2 or seen_wall):
			want.append("nb_battering_horns")
		if line.call("spitter") >= 4:
			want.append("nb_clutch_spitter")
		if line.call("spitter") + line.call("venom_challenger") >= 6:
			want.append("nb_long_spit")
			want.append("nb_slither")
		if line.call("hatchlings") >= 4 and seen_air >= 3:
			want.append("nb_clutch_hatchlings")
		if line.call("hatchlings") + line.call("storm_challenger") >= 4:
			want.append("nb_updraft")
	if st >= 1 and game.clock >= 480.0:
		want.append("nb_quick_roots")
	if st >= 1 and game.clock >= 600.0 and food >= 400:
		want.append("nb_swamp_mending")
	for key in want:
		if game.has_tech(team, key) or BroodResearch.in_hand(game, team, key):
			continue
		var info: Dictionary = Defs.RESEARCH[key]
		# (the army's own research, Bigger Clutch, Pack Hunt and Battering Horns, never waits for her stage's spoils)
		var k2 := 0.0 if key in ["nb_clutch_raptor", "nb_pack_hunt", "nb_battering_horns"] else keep2
		if food < int(info["cost"]) + keep or spoils < float(info.get("cost2", 0)) + k2:
			continue
		var at: String = info["at"]
		var who: Unit = q if at == BroodNew.QUEEN else BroodNew.father(game, team, at)
		if who == null or BroodResearch.busy(who) or BroodResearch.problem(game, who, key) != "":
			continue
		if BroodResearch.start(game, who, key) == "":
			say("researches %s" % String(info.get("name", key)))
		return


# ------------------------------------------------------------------ the army

func _nb_army_units() -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and not u.is_worker() \
		and not BroodNew.is_nb(u.kind) and u.kind != "horse")


func _army_supply_now() -> int:
	var s := 0
	for u in _nb_army_units():
		if u.kind != "hatchlings" or seen_air > 0:
			s += int(u.d["supply"])
	return s


func _value_of(list: Array) -> float:
	var v := 0.0
	for u in list:
		if is_instance_valid(u) and not u.dead:
			v += float(Game.unit_value(u))
	return v


## An enemy near the Mother (13 tiles), or Vector2.INF.
func _nb_threat(q: Unit) -> Vector2:
	for u in game.units_near(q.position, 13.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field:
			return u.position
	return Vector2.INF


## The attack at her is more than a scout or a lone rider (its Sires get up for it).
func _nb_threat_big(q: Unit) -> bool:
	var v := 0.0
	for u in game.units_near(q.position, 14.0 * Defs.TILE):
		if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker():
			v += float(Game.unit_value(u))
	return v >= 120.0


## The Sires get up for an attack at the Mother only when it is big and her army can't hold it alone (a Sire away from
## his nest fathers nothing, and a dead one stops his line for minutes: round 3's games lost their Tyrant Sire this way).
func _nb_sires_needed(q: Unit) -> bool:
	return _nb_threat_big(q) and _foe_near_home > _value_of(_nb_army_units()) * 0.8


## The staging point: a little out from the Mother toward the enemy, on her ground (the army gathers there and goes
## together).
func _nb_stage_point(q: Unit) -> Vector2:
	var foe := _foe()
	if _eco() and _alarm_on() and not _attacking:
		# (the alarm: the army waits at the natural, where an attack lands first, a little toward where it was seen)
		var nat: Unit = null
		for u in BroodNew.expansions(game, q):
			if nat == null or u.position.distance_to(q.position) < nat.position.distance_to(q.position):
				nat = u
		if nat != null:
			var p: Vector2 = nat.position + (alarm_at - nat.position).normalized() * 3.0 * Defs.TILE
			if _nb_on_map(p) and game._walkable(game.cell_of(p)):
				return p
			return nat.position + Vector2(0, nat.radius + 40.0)
	var tgt: Vector2 = q.position + Vector2(0, BroodNew.drawn_r(q) + 110.0)
	if foe >= 0:
		var st := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
		var p: Vector2 = q.position + (st - q.position).normalized() * 9.0 * Defs.TILE
		var c := game.cell_of(p)
		if _nb_on_map(p) and game._walkable(c) and game.region_of(c) == BroodRoot.home_region(game, q.position):
			tgt = p
	return tgt


## Where a wave goes: the nearest enemy building it has seen (its creatures saw it), else the enemy's start.
func _nb_wave_goal(q: Unit) -> Vector2:
	var foe := _foe()
	if foe < 0:
		return Vector2.INF
	var best := (Vector2(game.starts[foe]) + Vector2(2.5, 2.0)) * Defs.TILE
	var bd := best.distance_to(q.position)
	for b in _foe_blds:
		if is_instance_valid(b) and not b.dead and b.team == foe and not (b.kind in ["wall", "gate", "palisade", "tower"]):
			# (not a wall piece: claws on a wall under musket fire was round 3's costliest mistake; a hall, a farm, an
			# expansion: the army goes round to them and fights what comes out)
			var d: float = (_foe_blds[b] as Vector2).distance_to(q.position)
			if d < bd:
				bd = d
				best = _foe_blds[b]
	return best


var _wave_v0 := 0.0              # the wave's value when it left
var _wave_t0 := 0.0
var _wave_kills0 := 0
var _retreat_until := 0.0
var _gather_t := -1.0


func _nb_army(q: Unit) -> void:
	var army := _nb_army_units()
	if _scout != null:
		army.erase(_scout)
	# defence: anything at the Mother is fought by every creature that walks, and by the Sires, who get up from their
	# nests for a real attack (rooted creatures don't attack: the Rootmaws and turtles stay rooted, the Mother:
	# BroodNew.mother_guard). A wave out is called home when the attack at her is big and the home guard can't hold it.
	var threat := _nb_threat(q)
	if threat != Vector2.INF:
		var defenders := army.filter(func(u: Unit) -> bool: return not _wave.has(u) or not _attacking or u.position.distance_to(q.position) < 30.0 * Defs.TILE)
		if _nb_sires_needed(q):
			for fk in BroodNew.FATHERS:
				var f := BroodNew.father(game, team, fk)
				if f and f.tesla_mode == "packed" and not BroodRoot.in_cocoon(f):
					defenders.append(f)      # (rooted on his nest he gets up: _nb_one_father)
			if _attacking and _foe_near_home > _value_of(defenders) * 0.8:
				say("calls its wave home: an attack at the Mother (%d)" % int(_foe_near_home))
				_wave_end_nb(q, false)
				defenders = army
		for u in defenders:
			if u.kind == "hatchlings" and seen_air == 0:
				continue
			if u.target == null and (u.order == "idle" or u.order == "nb_root" or u.order == "move" or u in _wave):
				u.cmd_move(threat, true)
		if not _attacking:
			return
	var sup := 0
	for u in army:
		if u.kind != "hatchlings" or seen_air > 0:
			sup += int(u.d["supply"])
	if _attacking:
		_nb_wave_tick(q, army)
		return
	var home := _nb_stage_point(q)
	# Hatchlings guard the Mother's sky; everyone else gathers at the staging point
	for u in army:
		if u.order == "idle" and u.target == null and u.position.distance_to(home) > 200.0:
			u.cmd_move(home, true)          # (gathering at the staging point: on attack-move)
	if peaceful or game.clock < _retreat_until or game.clock < float(plan["wave_t"]) or _rush_on() or _alarm_on():
		return
	if sup < _attack_at:
		return
	# not into a hopeless fight: its army's value against the biggest enemy army it has seen lately (fading; 0.6 of it is
	# enough: round 3's best game, g20, traded 11,020 for 4,345 with Pack Hunt Raptors against a bigger Clockwork army), unless
	# it is at its supply cap (then it must spend its army) or this is a rush's first wave (a gamble by design)
	var mine_v := _value_of(army)
	var capped := game.supply_used(team) >= mini(int(game.players[team]["cap"]), game.max_supply(team)) - 6
	var first_rush := int(plan["grubs0"]) > 0 and not _first_out
	if not first_rush and not capped and mine_v < seen_army * float(plan.get("edge", 0.6)):
		return
	# a wall seen (the Crown's ramp wall): not with claws alone (round 3: Raptor waves into Musketeers behind a wall lost
	# three to four times what they killed); Brutes with Battering Horns or a real line of Spitters first, or at the cap
	if seen_wall and not first_rush and not capped:
		var br := BroodNew.count_of(game, team, "brute")
		var sp := BroodNew.count_of(game, team, "spitter") + BroodNew.count_of(game, team, "venom_challenger")
		if not ((br >= 2 and game.has_tech(team, "nb_battering_horns")) or sp >= 8):
			return
	if bool(plan["pack"]) and not game.has_tech(team, "nb_pack_hunt") and (BroodResearch.in_hand(game, team, "nb_pack_hunt") \
			or (game.clock < float(plan["wave_t"]) + 60.0 and BroodNew.father_near(game, team, BroodNew.FATHER))):
		return          # (Pack Hunt first: it is coming, or wanted and a minute's grace)
	var stage2 := BroodNew.stage(q) >= 2 and seen_wall and not game.has_tech(team, "nb_battering_horns") and BroodResearch.in_hand(game, team, "nb_battering_horns")
	if stage2:
		return          # (Battering Horns before a siege of a wall)
	# gathered? most of the army near the staging point (or waited 25 s)
	var near := 0
	for u in army:
		if u.position.distance_to(home) < 9.0 * Defs.TILE:
			near += int(u.d["supply"])
	if _gather_t < 0.0:
		_gather_t = game.clock
	if near * 10 < sup * 7 and game.clock - _gather_t < 25.0:
		return
	_gather_t = -1.0
	var goal := _nb_wave_goal(q)
	if goal == Vector2.INF:
		return
	_wave_target = goal
	_wave = army.filter(func(u: Unit) -> bool: return (u.kind != "hatchlings" or seen_air > 0) and u.moult_t < 0.0)
	# a home guard stays (not on the first wave of a rush)
	var guard := int(plan["home_guard"]) if _first_out else 0
	for u in _wave.duplicate():
		if guard <= 0:
			break
		if u.kind == "raptor":
			_wave.erase(u)
			guard -= 1
	_wave_sup = 0
	for u in _wave:
		_wave_sup += int(u.d["supply"])
	_wave_v0 = _value_of(_wave)
	_wave_t0 = game.clock
	_wave_kills0 = int(game.stats[team]["value_killed"])
	_attacking = true
	_first_out = true
	# a Sire may lead the wave (the plan's "sire_leads": he gets up from his nest and walks with it; his line lays no
	# eggs meanwhile)
	var lead := String(plan.get("sire_leads", ""))
	if lead != "":
		var f := BroodNew.father(game, team, lead)
		if f and not BroodRoot.in_cocoon(f) and not BroodResearch.busy(f):
			if f.tesla_mode == "deployed":
				f.cmd_uproot(false)
			_wave.append(f)
	for u in _wave:
		u.cmd_move(goal, true)
	say("attacks with %d supply (%s)" % [_wave_sup, _kinds_of(_wave)])
	if game.mlog:
		game.mlog.add("%s's Brood attacks with %d supply" % [game.mlog.who(team), _wave_sup])


## A wave out: keep it going at the goal; new ones join only as a group (6+ supply gathered at the staging point);
## RETREAT when the fight is lost: what is left is under half of what went and what it sees ahead is stronger, or it
## made no headway for long.
func _nb_wave_tick(q: Unit, army: Array) -> void:
	_wave = _wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var left := _value_of(_wave)
	var ahead := 0.0
	var mid := Vector2.ZERO
	for u in _wave:
		mid += u.position
	if not _wave.is_empty():
		mid /= _wave.size()
		for u in game.units_near(mid, 12.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.off_field and u.has_attack() and not u.is_worker() and game.is_visible_to(team, u.position):
				ahead += float(Game.unit_value(u))
	var gained := int(game.stats[team]["value_killed"]) - _wave_kills0
	var lost := _wave_v0 - left
	if _wave.is_empty() or (left < _wave_v0 * 0.5 and ahead > left * 1.2) or left < _wave_v0 * 0.25 \
			or (left < _wave_v0 * 0.7 and ahead > left * 1.6 and gained < lost * 0.5) \
			or (game.clock - _wave_t0 > 150.0 and gained < lost * 0.5 and ahead > left):
		say("pulls back: %d of %d left, %d ahead (killed %d)" % [int(left), int(_wave_v0), int(ahead), gained])
		_wave_end_nb(q, gained < _wave_v0 * 0.6)
		return
	for u in _wave:
		if u.order == "idle" and u.target == null:
			u.cmd_move(_wave_target, true)
	# reinforcements: a group gathered at home joins
	var home := _nb_stage_point(q)
	var fresh := army.filter(func(u: Unit) -> bool: return not _wave.has(u) and u.order == "idle" and u.target == null and u.moult_t < 0.0 \
		and (u.kind != "hatchlings" or seen_air > 0) and u.position.distance_to(home) < 9.0 * Defs.TILE)
	var fs := 0
	for u in fresh:
		fs += int(u.d["supply"])
	if fs >= 6:
		for u in fresh:
			_wave.append(u)
			u.cmd_move(_wave_target, true)
	for u in army:
		if not _wave.has(u) and u.order == "idle" and u.target == null and u.position.distance_to(home) > 200.0:
			u.cmd_move(home, true)          # (gathering at the staging point: on attack-move)


## The wave is over (pulled back or called home): back to the staging point; a lost wave makes the next bigger and
## gives it time to build (a failed rush becomes a Balanced game).
func _wave_end_nb(q: Unit, failed: bool) -> void:
	_attacking = false
	var home := _nb_stage_point(q)
	for u in _wave:
		if is_instance_valid(u) and not u.dead:
			u.cmd_move(home)
	_wave.clear()
	_attack_at += int(plan["step"])
	if failed:
		_attack_at = maxi(_attack_at, int(ceil(_wave_sup * 1.3)))
		_retreat_until = game.clock + 60.0
		if strategy in ["rush", "xrush"]:
			strategy = "balanced"
			_plan_of = strategy
			var keep_wave := _attack_at
			var was := plan.duplicate()
			plan = (PLANS["balanced"] as Dictionary).duplicate(true)
			for k in over:
				plan[k] = over[k]
			plan["wave_t"] = 0.0
			plan["far"] = was["far"]
			_attack_at = maxi(keep_wave, 20)
			_retreat_until = game.clock + 90.0
			say("its rush failed: it builds up (economy, tech) and comes back in force")


func _kinds_of(list: Array) -> String:
	var c := {}
	for u in list:
		c[u.kind] = int(c.get(u.kind, 0)) + 1
	var parts: Array = []
	for k in c:
		parts.append("%d %s" % [c[k], k])
	return ", ".join(parts)


## The ground the Mother roots on at home (her footprint at her stage, one tile round it): a Sire never nests there,
## even while she is up fighting, or she could not root again when it is calm.
func _nb_mother_ground(q: Unit) -> Rect2:
	var home: Vector2 = _q_guard.get("home", q.position)
	return BroodRoot.rect_for(BroodNew.QUEEN, home, BroodRoot.scale_of(q)).grow(Defs.TILE)
