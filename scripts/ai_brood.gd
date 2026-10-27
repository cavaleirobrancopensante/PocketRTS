class_name AIBrood
extends RefCounted
## The Brood computer's own judgement (an AI holds one as `brood` when it plays the Brood). Kept apart
## from the shared AI code; ai.gd calls it from its Brood branches. No cheating (docs/design_principles.md):
## it knows only what its own eyes have shown. Measured with tools/measure_brood_ai.gd; the numbers and
## why each rule is as it is: docs/brood_ai_fixes.md.
##  GRUBS    A floor of grubs rising with the clock (grub_floor): under it grubs come first, above it the
##           army while it is behind its plan; the enemy in our base or Horsemen about: the army first.
##  ESSENCE  The Brood Pen goes up after the economy (PEN_GRUBS, PEN_GUARD; at once against Horsemen),
##           its biomass put by. Bodies left on our side of the map after a fight are harvested by a few
##           grubs, who go back to the pits when none are left. Spare Raptors are offered up at the Pen for
##           two eggs of Spitters (offer_target), within OFFER_SHARE of the biomass earned; an egg waits for
##           a Spitter's biomass once the essence is there (egg_choice).
##  SUPPLY   Clutch Mounds go up ahead of need: the margin is what the eggs could fill while one goes up
##           (the recent income and the biomass and eggs in hand); with the supply short its 75 is put by.
##  EGGS     Every egg taken while biomass piles up: another Burrow (hall_due).
##  ATTACKS  Every enemy soldier seen is remembered (until seen to fall, or for MEMORY seconds). No wave
##           goes into an army clearly stronger than ours (it defends and techs meanwhile); on old news two
##           Raptors look first; a wave that is clearly losing its fight pulls back home; the next one
##           waits for a bigger army.

const MEMORY := 240.0           # an enemy soldier seen counts this long (unless we saw it fall)
const ATTACK_RATIO := 1.25      # a wave goes only when worth this many times the enemy army we know of
const RUSH_RATIO := 0.8         # ... a rush plan's first wave (a gamble, but not into a known wall of guns)
const LOST_RATIO := 1.5         # a wave facing this many times its own worth (health counted) ...
const LOST_SHARE := 0.25        # ... after losing this share of what it took out, pulls back
const LOST_ROUT := 2.5          # ... and at once against this many times its worth
const LOST_MIN := 150.0         # (never over less than this much enemy)
const FIGHT_R := 360.0          # enemies this close to any unit of the wave are its fight
const MOUND_URGENT := 6        # free supply (two eggs of Raptors) under which a due mound's biomass is put by
const LEAD := 30.0              # seconds from a Clutch Mound's order to its supply (the walk, 18 s building, slack)
const HARVEST_MAX := 4          # grubs out harvesting at once
const HARVEST_CLEAR := 400.0    # no armed enemy (seen) this close to the bodies
const HARVEST_HOME := 1100.0    # bodies this far from our nearest building at most
const HARVEST_MIN := 2.5        # essence a group of bodies must hold to send a grub
const HARVEST_WORKERS := 8      # no harvesting with fewer grubs than this (they are the economy)
const GUARD := 3                # Raptors always kept at home (never offered up)
const OFFER_SHARE := 0.05       # offerings never cost more than this share of the biomass earned
const OFFER_ALWAYS := 2         # Raptors that may be offered up at a time even with the army under its plan
const PEN_GRUBS := 14           # grubs before the Pen goes up (earlier cost the army half its worth at 5:00)
const PEN_GUARD := 6            # army supply at home before the Pen's biomass is put by (two eggs of Raptors)
const GORGE_ESSENCE := 15.0     # essence earned (or in hand) before the Gorge Pit is due
const RESERVE_MAX := 45.0       # a reserve not spent in this long (no room, no grub) ...
const RESERVE_REST := 30.0      # ... is dropped for this long

## (tools switch it off before a match for a "before" number: the Brood computer as it was)
static var enabled := true
## (measurement only: parts switched off to weigh them one by one; empty in every real match)
static var off := {}

var ai: AI
var game: Game
var team := 1
var _foe_seen := {}             # enemy unit instance id -> {"u": Unit, "v": value, "t": clock seen}
var _watch_t := -99.0
var _inc: Array = []            # [clock, biomass earned so far, supply used] every 5 s (the last minute)
var supply_due := false         # a Clutch Mound is due (its biomass is put by)
var _harvesters := {}           # grub -> {"at": the spot it harvests, "swarm": sent along with a swarm}
var _harvest_t := 0.0
var _offer_t := 0.0
var _hold_said := -999.0        # (the match log: when a held attack was last noted)
var _reserve_t := -1.0
var _reserve := 0
var _res_why := ""              # what the biomass is put by for ("mound", "pen", "gorge") ...
var _res_since := 0.0           # ... since when
var _rest_until := 0.0          # (a reserve that went unspent too long is dropped until then)
## (tests and tools/measure_brood_ai.gd read these)
var harvest_sent := 0           # grubs sent to harvest
var retreats := 0               # waves pulled back from a lost fight
var holds := 0                  # times a wave was held back by what was seen
var offered := 0                # creatures offered up at the Pen


func _init(a: AI) -> void:
	ai = a
	game = a.game
	team = a.team


## Every think (before the army's): what the eyes show, the income, the harvesters.
func tick() -> void:
	_watch()
	_sample()
	_harvest()
	_egg_watch()


func _say(msg: String) -> void:
	if game.mlog:
		game.mlog.add("%s %s" % [game.mlog.who(team), msg])


# ------------------------------------------------------------------ what we know of the enemy army

## Every armed enemy unit in sight is remembered with its value; one seen to fall (in sight, or by our
## hand) is struck off; the rest are forgotten MEMORY seconds after they were last seen.
func _watch() -> void:
	if game.clock - _watch_t < 1.0:
		return
	_watch_t = game.clock
	for u in game.units:
		if u.dead or u.off_field or u.is_worker() or u.kind == "horse" or not game.hostile(u.team, team):
			continue
		if not (u.has_attack() or Defs.MUSKETS.has(u.kind)):
			continue
		if game.is_visible_to(team, u.position):
			_foe_seen[u.get_instance_id()] = {"u": u, "v": float(Game.unit_value(u)), "t": game.clock}
			_last_seen_t = game.clock
	for id in _foe_seen.keys():
		var e: Dictionary = _foe_seen[id]
		if game.clock - float(e["t"]) > MEMORY:
			_foe_seen.erase(id)
			continue
		var u = e["u"]
		if is_instance_valid(u) and u.dead and (game.is_visible_to(team, u.position) or u.last_hit_team == team):
			_foe_seen.erase(id)


## What the enemy army is worth as far as our eyes have shown it: the soldiers seen lately, less the
## ones seen to fall (the match log's value: cost per unit made).
func known_foe_value() -> float:
	_watch()
	var v := 0.0
	for id in _foe_seen:
		v += float(_foe_seen[id]["v"])
	return v


## Our army's worth the same way (eggs hatching count: they are on their way).
func army_value(list: Array) -> float:
	var v := 0.0
	for u in list:
		v += float(Game.unit_value(u))
	return v


## May a wave worth `mine` go? Not into an enemy army clearly stronger than it, as far as we know it.
## A held wave is noted in the match log (once a minute at most).
func attack_ok(mine: float, ratio := ATTACK_RATIO) -> bool:
	if _looking():
		return false        # (two Raptors are out looking: the wave waits for what they see)
	if _need_look() and _start_look():
		return false
	var known := known_foe_value()
	if known <= 0.0 or mine >= known * ratio or game.supply_used(team) >= game.max_supply(team) - 12:
		return true         # (nothing known against it, or at the supply cap: the army cannot grow, it goes)
	if game.clock - _hold_said > 60.0:
		_hold_said = game.clock
		holds += 1
		_say("holds its attack: the enemy army it has seen is worth %d, its own %d; it defends and builds up first" % [int(known), int(mine)])
	return false


## A look before the leap: a wave that would go on old news (no enemy soldier seen for LOOK_FRESH seconds)
## first sends LOOKERS Raptors to the enemy base and waits for what they see (or for them to fall: their
## killers are seen as they do), at most LOOK_MAX seconds. Measured: with nothing seen for minutes,
## "nothing known" let a 1,030 wave walk into an army of 1,860 and die there.
const LOOK_FRESH := 90.0
const LOOK_MAX := 45.0
const LOOK_FROM := 240.0        # (no look before this: a rush goes on what the scout saw)
const LOOKERS := 2
var _last_seen_t := -999.0
var _look: Array = []
var _look_t := -999.0
var looks := 0                  # (tools/measure_brood_ai.gd)


func _need_look() -> bool:
	return game.clock >= LOOK_FROM and game.clock - _last_seen_t > LOOK_FRESH and game.clock - _look_t > LOOK_FRESH


func _start_look() -> bool:
	var base: Vector2 = ai._enemy_base()
	if base == Vector2.INF:
		return false
	var pool := game.army(team).filter(func(u: Unit) -> bool: return u.kind == "raptor" and u.order in ["idle", "move", "amove"] and u.target == null)
	if pool.size() < LOOKERS + 4:
		return false
	pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(base) < b.position.distance_squared_to(base))
	_look = pool.slice(0, LOOKERS)
	for u in _look:
		u.cmd_move(base + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
	_look_t = game.clock
	looks += 1
	_say("sends %d Raptors to look at the enemy before its wave goes (nothing seen of its army for %d s)" % [LOOKERS, int(game.clock - maxf(0.0, _last_seen_t))])
	return true


## The lookers are still on their way (alive, not there yet, not seen anything, within LOOK_MAX).
func _looking() -> bool:
	if _look.is_empty():
		return false
	_look = _look.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
	var base: Vector2 = ai._enemy_base()
	var there := _look.any(func(u: Unit) -> bool: return base != Vector2.INF and u.position.distance_to(base) < 300.0)
	if _look.is_empty() or there or _last_seen_t >= _look_t + 1.0 or game.clock - _look_t > LOOK_MAX:
		var front: Vector2 = ai._front()
		for u in _look:
			u.cmd_move(ai._home_spot(front))
		_look.clear()
		return false
	return true


## Is this wave clearly losing its fight? The armed enemies in sight within FIGHT_R of any of its units
## against the wave's own worth (health counted): a rout at once, a clear loss once it has bled.
func wave_lost(wave: Array, sent: float) -> bool:
	if wave.is_empty():
		return false
	var mine := 0.0
	var foes := {}
	for u in wave:
		mine += ai._unit_value(u)
		for o in game.units_near(u.position, FIGHT_R):
			if not foes.has(o) and game.hostile(o.team, team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o):
				foes[o] = true
	var theirs := 0.0
	for o in foes:
		theirs += ai._unit_value(o)
	if theirs < LOST_MIN:
		return false
	var bled := 1.0 - mine / maxf(1.0, sent)
	return theirs > mine * LOST_ROUT or (theirs > mine * LOST_RATIO and bled >= LOST_SHARE)


## Two or more Horsemen in sight by this raid spot (AI._defend): a raiding party hunting the grubs, not a
## lone rider. Four Raptors are no match for two of them (and AI._defend sent nobody when they were
## worth too little against them): the Raptors answer it as a pack, which also drives the party home.
func raid_party(spot: Vector2) -> bool:
	var riders := 0
	for o in game.units_near(spot, 300.0):
		if game.hostile(o.team, team) and not o.dead and not o.off_field and ai._armed(o) and AIScout._is_horseman(o) and ai._sighted(o):
			riders += 1
	return riders >= 2


## The wave pulls back home (a lost fight is a lost fight, not a lost army): noted in the match log.
func retreat(wave: Array, why_theirs: float) -> void:
	retreats += 1
	var front: Vector2 = ai._front()
	for u in wave:
		if is_instance_valid(u) and not u.dead:
			u.siege_t = 0.0
			u.cmd_move(ai._home_spot(front))
	_say("pulls its swarm back: the fight is lost (%d of its own against %d in sight); the next wave waits for a bigger army" % [int(army_value(wave)), int(why_theirs)])


## The enemy value in sight around a wave (for the log line of a retreat).
func fight_value(wave: Array) -> float:
	var foes := {}
	for u in wave:
		for o in game.units_near(u.position, FIGHT_R):
			if game.hostile(o.team, team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o):
				foes[o] = true
	var v := 0.0
	for o in foes:
		v += ai._unit_value(o)
	return v


# ------------------------------------------------------------------ supply

func _sample() -> void:
	if _inc.is_empty() or game.clock - float(_inc[_inc.size() - 1][0]) >= 5.0:
		_inc.append([game.clock, float(game.stats[team]["gold"]), float(game.supply_used(team))])
		while _inc.size() > 13:
			_inc.pop_front()


## Biomass earned a second over the last minute (4 until there is a history).
func income() -> float:
	if _inc.size() < 3:
		return 4.0
	var a: Array = _inc[0]
	var b: Array = _inc[_inc.size() - 1]
	return maxf(0.0, (float(b[1]) - float(a[1])) / maxf(1.0, float(b[0]) - float(a[0])))


## Supply taken up a second over the last minute (what was actually hatched, less what fell).
func supply_growth() -> float:
	if _inc.size() < 3:
		return 0.0
	var a: Array = _inc[0]
	var b: Array = _inc[_inc.size() - 1]
	return maxf(0.0, (float(b[2]) - float(a[2])) / maxf(1.0, float(b[0]) - float(a[0])))


## How much free supply to keep: what the eggs will fill while a Clutch Mound goes up (the supply taken
## up lately, never under the income spent on grubs, 50 biomass a supply, nor over the income spent on
## Raptors once the Spawning Den stands, 25, nor faster than the Burrows lay: one egg every 9 s each),
## plus what could hatch at once from the eggs and biomass in hand, plus a little.
func supply_margin() -> int:
	var eggs := 0
	var halls := 0
	for h in ai._halls():
		if h.built:
			eggs += h.eggs
			halls += 1
	var den := game._has_built(team, "warren")
	var per := 25.0 if den else 50.0
	var per_egg := 3 if den else 1
	var lay := float(per_egg * halls) * game.egg_rate(team) / Defs.EGG_TIME
	var rate := minf(clampf(supply_growth(), income() / 50.0, income() / per), lay)
	var now := mini(eggs * per_egg, int(float(ai._gold()) / per))
	return clampi(int(ceil(rate * LEAD)) + now + 2, 4, 30)


## Clutch Mounds ahead of need (in place of AI._supply for the Brood): a second one at once when the
## margin is wide. Without the 75 biomass the mound is put by first (reserve).
func supply() -> void:
	supply_due = false
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team):
		return
	var sup: String = ai._sup()
	var going := 0
	for b in ai._mine(sup):
		if not b.built:
			going += 1
	var coming := going * int(Defs.BUILDINGS[sup]["supply"])
	for h in ai._halls():
		if not h.built:
			coming += int(Defs.BUILDINGS[h.kind]["supply"])
	if cap + coming >= game.max_supply(team):
		return
	var margin := supply_margin()
	if ai.strategy in ["rush", "xrush"] and not ai._first_wave:
		margin = 2          # (a rush's first wave first: a mound only once an egg of Raptors would not fit)
	var free := cap + coming - game.supply_used(team)
	if free > margin or going >= (2 if margin > 14 else 1):
		return
	# (its biomass is put by only once the supply is short: the margin itself is wide, up to 30, and putting
	# 75 by every time it was reached held the eggs and the grubs back for much of the game)
	supply_due = free <= MOUND_URGENT
	if ai._gold() < int(Defs.BUILDINGS[sup]["cost"]):
		return
	ai._construct(sup, ai._mound_spot())


# ------------------------------------------------------------------ grubs: the economy never stands still

## Eggs for the army before more grubs? As before, only while the army is under what the plan wants
## (AI._army_want: the plan's curve, or 1.2x an enemy army in sight); but never while there are fewer
## grubs than `grub_floor`, which rises by a grub every FLOOR_STEP seconds after FLOOR_FROM (up to
## FLOOR_MAX). The old rule held the grubs at 9 for as long as the army was behind: in the owner's game
## against a growing Crown army it could never catch up with, the Brood sat on 13 Raptors from minute 4 to
## 6 with an income that stood still. With the enemy in our base or Horsemen about, the floor stays at the
## working minimum: the army first. Far above the floor (FLOOR_OVER) the eggs go to the army anyway (with
## the plan's small curve met, every egg went to grubs: 40 grubs at 9:30, none left for the army).
const FLOOR_OVER := 8
const FLOOR_FROM := 150.0
const FLOOR_STEP := 20.0


func grub_floor() -> int:
	var base := 10 if ai.strategy == "economy" else 9
	if ai.strategy == "rush" and not ai._first_wave:
		return 6            # (a rush's first wave first)
	if ai._threat() != Vector2.INF or ai._horse_alert():
		return base         # (the enemy is in our base, or Horsemen are hunting the grubs: the army first)
	return mini(base + int(maxf(0.0, game.clock - FLOOR_FROM) / FLOOR_STEP * _floor_k()), FLOOR_MAX)


## How fast the floor rises: the plan's worker share (faster on Economy); a Rush keeps its slower pace
## after its first wave (the plan switches to Balanced then): a rush trades grubs for Raptors.
func _floor_k() -> float:
	if ai._opened in ["rush", "xrush"]:
		return float(AI.STRATEGIES["rush"]["workers"])
	return float(ai._s("workers"))


const FLOOR_MAX := 34


## The army the plan's curve wants by now (AI.ARMY_CURVE), without the answer to an enemy army in sight.
func army_first(grubs: int) -> bool:
	if off.has("floor"):
		return ai._army_behind() and grubs >= 9
	if not game._has_built(team, "warren"):
		return false
	var fl := grub_floor()
	return (ai._army_behind() and grubs >= fl) or (game.clock > 200.0 and grubs >= fl + FLOOR_OVER)


# ------------------------------------------------------------------ eggs: the army's real mix, and a Burrow when eggs run short

const SPITTER_SHARE := 0.6      # Spitters wanted for every Raptor once the Pen stands (by count)
const STARVE_T := 20.0          # every egg taken this long with biomass in hand: one Burrow is not enough
const STARVE_GOLD := 150        # ... "biomass in hand"
var _starve := 0.0
var _starve_last := 0.0
var burrows_added := 0          # (tools/measure_brood_ai.gd)


## What this egg hatches, given what AI._produce picked (`k`); "" = keep the egg and wait. The old
## pick made a Spitter only when 90 biomass happened to be in hand at that moment, so with the income
## spent as it came in (Raptors cost 75) the essence sat unused for minutes (12 essence banked from
## minute 5:30 to 7:30 and two Spitters by 9:00). Now, once the Pen stands and the essence is there, the
## egg waits for a Spitter's biomass while the Spitters are under SPITTER_SHARE of the Raptors (unless
## the enemy is in our base: then whatever hatches now).
func egg_choice(h: Building, army: Array, k: String) -> String:
	if k != "raptor" or not game._has_built(team, "brood_pen") or not spitter_ok():
		return k
	var raptors := 0
	var spitters := 0
	for u in army:
		if u.kind == "raptor":
			raptors += 1
		elif u.kind == "spitter":
			spitters += 1
	for hh in ai._halls():
		raptors += int(Defs.UNITS["raptor"]["spawn"]) * (hh.queue as Array).count("raptor")
		spitters += int(Defs.UNITS["spitter"]["spawn"]) * (hh.queue as Array).count("spitter")
	if float(spitters) >= float(raptors) * SPITTER_SHARE:
		return k
	var why := game.can_train(h, "spitter")
	if why == "":
		return "spitter"
	if not off.has("wait") and why.begins_with("Not enough") and ai._res2() >= float(Defs.UNITS["spitter"]["cost2"]) and ai._threat() == Vector2.INF:
		return ""           # (the essence is there: wait for the biomass)
	return k


## Every egg taken while biomass piles up: the Burrows are the limit, not the income (seen from about
## minute 7 with one Burrow: no eggs, 200-480 biomass banked). Another Burrow goes up by the capital.
func _egg_watch() -> void:
	var dt := game.clock - _starve_last
	_starve_last = game.clock
	var eggs := 0
	for h in ai._halls():
		if h.built:
			eggs += h.eggs
	if eggs == 0 and ai._gold() >= STARVE_GOLD:
		_starve += dt
	else:
		_starve = maxf(0.0, _starve - dt * 0.5)
	if hall_due() and ai._gold() >= int(Defs.BUILDINGS[ai._f()["hall"]]["cost"]):
		var before := ai._halls().size()
		ai._more_halls(true)
		if ai._halls().size() > before:
			burrows_added += 1
			_starve = 0.0
			_say("lays out another Burrow: its eggs, not its biomass, were holding the army back")


## A Burrow is due: eggs have been short with biomass in hand for STARVE_T seconds and none is going up.
func hall_due() -> bool:
	if ai.strategy == "xrush" or _starve < STARVE_T or ai._busy_building(ai._f()["hall"]):
		return false
	return ai._halls().size() < int(ai._s("halls")) + 1


# ------------------------------------------------------------------ biomass put by for what is due

## The Brood Pen is due: the Spawning Den stands and the army has caught up with what the plan wants by
## now (Horsemen seen: at once, Spitters answer them; on a rush plan: once the first wave has gone). The
## six-pool builds none while it lasts.
func pen_due() -> bool:
	if ai.strategy == "xrush" or not ai._mine("brood_pen").is_empty() or not game._has_built(team, "warren"):
		return false
	if ai._no_room.has("brood_pen"):
		return false
	if ai.strategy == "rush" and not ai._first_wave:
		return false
	# (a few Raptors at home are enough: the army is nearly always "behind" an enemy army in sight, and
	# waiting for it to catch up left the Pen until minute 5 or 6, so no essence and only Raptors)
	if game.workers(team).size() < PEN_GRUBS and not ai._horse_alert():
		return false        # (the economy first: a Pen by 3:30 cost the army half its worth at 5:00 and a fifth of the income by 7:00)
	return not ai._army_behind() or ai._horse_alert() or ai._army_supply(game.army(team)) >= PEN_GUARD


## The Gorge Pit (Brutes, Mist Toads, the Broodmound) is due: its time by the plan, once the Pen stands,
## the army has caught up (Horsemen seen: at once) and essence is coming in (GORGE_ESSENCE earned or in
## hand: everything it unlocks costs essence, so without it the Pit is 200 biomass and a grub for nothing).
func gorge_due(t: float) -> bool:
	if not ai._mine("gorge_pit").is_empty() or not game.requirement_met(team, "gorge_pit") or not game._has_built(team, "brood_pen"):
		return false
	if ai._army_behind() and not ai._horse_alert():
		return false
	if float(game.stats[team]["res2_in"]) < GORGE_ESSENCE and ai._res2() + essence_coming() < GORGE_ESSENCE:
		return false
	return t > float(ai._lv([480.0, 250.0, 190.0]))


## Biomass to keep in hand for a building that is due (worked out once a think): eggs and grubs wait for
## it, or they would eat every coin as it comes in and the building would never go up. A Clutch Mound is
## always put by (nothing hatches without supply); the Pen (100: the door to essence) only with a few
## Raptors at home (PEN_GUARD supply) and not while the enemy is in our base. Nothing else is put by:
## measured, holding back for the Gorge Pit (200) and a second Burrow (350) as well cost the army half
## its worth at 5:00 and a fifth of the income by 7:00 (eggs and grubs kept waiting); those go up when
## the biomass is there. A reserve not spent in RESERVE_MAX seconds (no room, no grub to build it) is
## dropped for RESERVE_REST seconds: it must never starve the eggs for good.
func reserve() -> int:
	if _reserve_t == game.clock:
		return _reserve
	_reserve_t = game.clock
	var r := 0
	var why := ""
	if supply_due:
		r = int(Defs.BUILDINGS[ai._sup()]["cost"])
		why = "mound"
	if ai._threat() == Vector2.INF and game.clock >= _rest_until:
		if pen_due() and ai._army_supply(game.army(team)) >= PEN_GUARD and not off.has("pen"):
			r = maxi(r, int(Defs.BUILDINGS["brood_pen"]["cost"]))
			why = "pen"
	if why != _res_why:
		_res_why = why
		_res_since = game.clock
	elif why != "" and why != "mound" and game.clock - _res_since > RESERVE_MAX:
		_rest_until = game.clock + RESERVE_REST
		r = int(Defs.BUILDINGS[ai._sup()]["cost"]) if supply_due else 0
	_reserve = r
	return r


## Would spending `price` now eat into what is put by?
func holding(price: int) -> bool:
	if off.has("reserve"):
		return false
	var r := reserve()
	return r > 0 and ai._gold() - price < r


# ------------------------------------------------------------------ essence

## The essence to have in hand for the next tech creature: two eggs of Spitters once the Pen stands;
## a Brute or a Mist Toad with the Gorge Pit; the Broodmound's 50 when it is saved for; a Skywing's
## 40 with a Roost.
func essence_want() -> float:
	var want := 0.0
	if game._has_built(team, "brood_pen"):
		want = 2.0 * float(Defs.UNITS["spitter"]["cost2"])
	if game._has_built(team, "gorge_pit"):
		want = maxf(want, float(Defs.UNITS["mist_toad"]["cost2"]))
	if game._has_built(team, "roost"):
		want = maxf(want, float(Defs.UNITS["skywing"]["cost2"]))
	if ai._mound_saving():
		want = maxf(want, float(Defs.HALL_LEVELS[2]["cost2"]) + 20.0)
	return want


## What offerings are made for (less than essence_want: an offered Raptor gives back Defs.SACRIFICE (35%) of its biomass).
## Two eggs of Spitters always (5 essence an egg: two Raptors' worth, a good trade); a Brute's 20 only with
## Horsemen about (the Brute is the answer to them), a Skywing's 40 only against flyers, the Broodmound's
## when it is saved for. Mist Toads and the other Brutes wait for bodies: offering Raptors for all of
## them burned up to 32 Raptors (800 biomass) a game for 96 essence.
func offer_target() -> float:
	if not game._has_built(team, "brood_pen"):
		return 0.0
	var want := 2.0 * float(Defs.UNITS["spitter"]["cost2"])
	if ai._horse_alert() and game._has_built(team, "gorge_pit"):
		want = maxf(want, float(Defs.UNITS["brute"]["cost2"]) + float(Defs.UNITS["spitter"]["cost2"]))
	if ai._foe_air() > 0 and game._has_built(team, "roost"):
		want = maxf(want, float(Defs.UNITS["skywing"]["cost2"]))
	if ai._mound_saving():
		want = maxf(want, float(Defs.HALL_LEVELS[2]["cost2"]) + 20.0)
	return want


## A Roost (Skywings: 40 essence each) only once the essence for one is there or the enemy has shown flyers
## (Skywings hunt them): without essence it is 175 biomass and a grub for nothing.
func roost_ok() -> bool:
	return ai._res2() >= float(Defs.UNITS["skywing"]["cost2"]) or ai._foe_air() > 0


## An egg of Spitters (5 essence) only from essence beyond what the next Brute needs when Horsemen are
## about and there is a Gorge Pit (Brutes are the answer to them); otherwise Spitters may spend it (the
## offerings are made for them: offer_target), and Brutes come from the bodies of a fight.
func spitter_ok() -> bool:
	if not game._has_built(team, "gorge_pit") or ai._foe_air() > 0 or not ai._horse_alert():
		return true
	return ai._res2() - float(Defs.UNITS["spitter"]["cost2"]) >= float(Defs.UNITS["brute"]["cost2"])


## The essence on its way: offerings walking to the Pen, cocoons carried home, bodies being wrapped.
func essence_coming() -> float:
	var v := 0.0
	for u in game.army(team):
		if u.order == "sacrifice":
			v += float(Game.sacrifice_value(u.kind))
	for g in game.workers(team):
		if g.order == "harvest":
			v += g.cocoon
			if g._corpse != null and is_instance_valid(g._corpse):
				v += game.corpse_value(g._corpse)
	return v


## With too little essence for the next tech creature and no bodies coming, spare Raptors at home are
## offered up at the Pen (9 essence each since 0.14.40): only the army's surplus over what the plan wants by now
## (AI._army_want: an army under it needs every Raptor), never from a wave, never with the enemy in our
## base, never the last GUARD of them; a few at a time.
func offer() -> void:
	if off.has("offer"):
		return
	if game.clock < _offer_t or ai._hall_reserve or ai._threat() != Vector2.INF:
		return
	var pen := game.nearest_of(game.center_of_team(team), team, "brood_pen")
	if pen == null or not pen.built:
		return
	if float(offered) * float(Defs.UNITS["raptor"]["cost"]) / float(Defs.UNITS["raptor"]["spawn"]) > OFFER_SHARE * float(game.stats[team]["gold"]):
		return              # (offerings are dear: a Raptor gives back only a third of its biomass; a budget, not a habit)
	var want := offer_target()
	var have := ai._res2() + essence_coming()
	if want <= 0.0 or have >= want:
		return
	if not _bodies().is_empty():
		return              # (bodies to harvest: the grubs bring the essence)
	var in_wave := {}
	for g in ai._swarm:
		for u in g[0]:
			in_wave[u] = true
	for u in ai._xr_wave:
		in_wave[u] = true
	var raptors := game.army(team).filter(func(u: Unit) -> bool: return u.kind == "raptor" and not in_wave.has(u) \
		and u.order in ["idle", "move", "amove"] and u.target == null and u.can_sacrifice())
	var per_value := float(Game.unit_value(raptors[0])) if not raptors.is_empty() else 25.0
	# (the army's surplus over the plan; with too few Raptors over the plan, still one or two of
	# them: a Raptor offered up is the essence for an egg of Spitters, which beat Raptors at a line of
	# guns, so the army gets better, not smaller, and without essence the Brood has only Raptors)
	var surplus := maxi(int(floor((ai._army_value() - ai._army_want()) / per_value)), OFFER_ALWAYS)
	var spare := mini(raptors.size() - GUARD, surplus)
	if spare <= 0:
		return
	raptors.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(pen.center()) < b.position.distance_squared_to(pen.center()))
	var per := float(Game.sacrifice_value("raptor"))
	var n := mini(mini(int(ceil((want - have) / per)), 4), spare)
	for u in raptors.slice(0, n):
		u.cmd_sacrifice()
		offered += 1
	_offer_t = game.clock + float(ai._lv([40.0, 25.0, 15.0]))


# ------------------------------------------------------------------ harvesting the fallen

## Is this spot safe for a grub: no armed enemy seen within HARVEST_CLEAR, and on our side (within
## HARVEST_HOME of one of our buildings)?
func _safe(p: Vector2) -> bool:
	if ai._home_dist(p) > HARVEST_HOME:
		return false
	for o in game.units_near(p, HARVEST_CLEAR):
		if game.hostile(o.team, team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o):
			return false
	return not ai._gun_danger(p)


## The bodies we can harvest now, in groups (each [centre, essence, count]): in sight, not torn, not
## claimed, on safe ground our grubs can walk to.
func _bodies() -> Array:
	var groups: Array = []
	var cap := game.capital(team)
	if cap == null:
		return groups
	var home_reg: int = ai._region_at(cap.center() + Vector2(0, cap.rect().size.y * 0.5 + 20.0))
	for c in game.corpses:
		if not is_instance_valid(c) or c.torn:
			continue
		var h = c.harvester
		if h != null and is_instance_valid(h) and not h.dead and h.order == "harvest":
			continue
		if not game.is_visible_to(team, c.position):
			continue
		var placed := false
		for gr in groups:
			if (gr[0] as Vector2).distance_to(c.position) < float(Defs.HARVEST["range"]) * Defs.TILE * 0.6:
				gr[1] = float(gr[1]) + game.corpse_value(c)
				gr[2] = int(gr[2]) + 1
				placed = true
				break
		if not placed:
			groups.append([c.position, game.corpse_value(c), 1])
	return groups.filter(func(gr: Array) -> bool: return float(gr[1]) >= HARVEST_MIN and _safe(gr[0]) \
		and (home_reg < 0 or ai._region_at(gr[0]) == home_reg or ai._region_at(gr[0]) < 0))


## Grubs harvest the bodies left after a fight (a few, the nearest that are not carrying food), and go
## back to their pits when none are left by their spot or it turns dangerous (the swarm's own
## harvesters too: they used to stand at the staging point for good).
func _harvest() -> void:
	if game.clock < _harvest_t:
		return
	_harvest_t = game.clock + 2.0
	for g in game.workers(team):
		if g.order == "harvest" and not _harvesters.has(g):
			_harvesters[g] = {"at": g.harvest_home, "swarm": true}      # (sent with a swarm by AI._swarm_army)
	for g in _harvesters.keys():
		if not is_instance_valid(g) or g.dead or g.order != "harvest":
			_harvesters.erase(g)
			continue
		if g.cocoon > 0.0 or (g._corpse != null and is_instance_valid(g._corpse)):
			continue            # (wrapping one, or carrying one home)
		var job: Dictionary = _harvesters[g]
		var spot: Vector2 = job["at"]
		var left := false
		for c in game.corpses:
			if is_instance_valid(c) and not c.torn and c.position.distance_to(spot) < float(Defs.HARVEST["range"]) * Defs.TILE:
				left = true
				break
		if job["swarm"] and ai._swarm_phase != "" and _safe(g.position):
			continue            # (the swarm's harvesters wait by it while it fights: bodies are coming)
		if not left or not _safe(g.position):
			_harvesters.erase(g)
			ai._resume(g)
	var room := HARVEST_MAX - _harvesters.size()
	if room <= 0 or game.corpses.is_empty() or game.workers(team).size() < HARVEST_WORKERS:
		return
	var groups := _bodies()
	if groups.is_empty():
		return
	groups.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var free: Array = game.workers(team).filter(func(g: Unit) -> bool: return g.order == "gather" and g.carrying == 0 \
		and g.cocoon <= 0.0 and not ai._fled.has(g) and not ai._fighters.has(g) and not (ai.scout != null and ai.scout.is_scout(g)))
	for gr in groups:
		if room <= 0 or free.is_empty():
			break
		var at: Vector2 = gr[0]
		var n := mini(mini(int(ceil(float(gr[2]) / 3.0)), 3), room)
		free.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
		for g in free.slice(0, n):
			g.cmd_harvest()
			g.harvest_home = at
			_harvesters[g] = {"at": at, "swarm": false}
			harvest_sent += 1
			room -= 1
		free = free.slice(n)
