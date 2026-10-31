class_name AIHarass
extends RefCounted
## THE COMPUTER'S HARASS (owner, 2026-10-31, Hard Clockwork v Hard Brood on Highmoor, 0.24.21: "clockwork ai sent 1 clock
## soldier to harass and stopped to attack a turtle, instead of stopping he should have pushed and scouted and tried to
## harass the worker line of brood, forcing brood to uproot the tyrant to deal with it"). docs/ai_harass.md.
##
## A small party out in the enemy's land (a Clock Soldier that chased a scout out of our base, the Crown's raiding
## Horsemen, a soldier scout) is steered here, never left on a bare attack-move (which hits the nearest thing):
##  - it does NOT lock onto STRUCTURES: buildings, walls, turrets and ROOTED Brood creatures (Mound Turtles, Rootmaws, a
##    rooted Sire or Mother, eggs): it walks past them (a plain move) unless they block its only way (stuck: then it
##    breaks through) or nothing else is in reach;
##  - its prey is the WORKERS (grubs, Labourers, Winders) and units that can't fight back, those away from defenders
##    first (no rooted creature attacks: a grub loading at its Rootmaw stands still for it); with none in sight it keeps walking to the worker line (the enemy's workers or economy, else its base);
##  - a REAL DEFENDER (a Sire or the Mother on her feet, or armed units worth more than the party) makes it pull back
##    for a few seconds, then it comes back; a weaker armed unit that reaches it is fought;
##  - hurt, run down (a construct out of wind) or out too long, it goes home and is let go.
## Orders are refreshed every think (about once a second). A big army push keeps its own targeting (AI._army).

const MAX_UNITS := 3            # the most units harassing at once (strays adopted by adopt_strays)
const STRAY_FROM := 900.0       # (pixels from our nearest building) an army unit out alone this far is a stray
const PREY_R := 12.0            # (tiles) how far a harasser looks for workers
const DANGER_R := 330.0         # (pixels) armed enemies this close to the party count as its danger
const BACK_FOR := 6.0           # (s) a pull-back lasts this long, then it comes back
const MAX_BACKS := 3            # pulled back this often: it goes home
const HOME_HP := 0.35           # below this share of its hit points it goes home
const MAX_TIME := 150.0         # (s) out this long: home
const STUCK_FOR := 3.0          # (s) a plain walk that gets nowhere this long: it breaks through what is in the way

var ai: AI
var game: Game
var units := {}                 # Unit -> {"t0", "back_until", "backs", "goal", "home" (walking home), "last_pos", "still"}
var done := {}                  # Unit -> clock until which it is not adopted again
var log_lines: Array = []       # [clock, text] (tests read it)
var _last_t := -1.0
var _dt := 1.0                  # (s) since the last tick


func _init(a: AI) -> void:
	ai = a
	game = a.game


func _say(u: Unit, msg: String) -> void:
	log_lines.append([game.clock, msg])
	if game.mlog:
		game.mlog.add("%s's %s %s" % [game.mlog.who(ai.team), String(Defs.UNITS[u.kind]["name"]), msg])


# ------------------------------------------------------------------ what is what

## A thing that stands still for the fight: a building (walls, turrets) or a rooted Brood creature (Mound Turtle,
## Rootmaw, a rooted Sire or Mother, a cocoon), an egg or a food pile.
static func is_static(e) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if e is Building:
		return true
	if not (e is Unit):
		return false
	var u := e as Unit
	if u.kind == BroodNew.EGG or u.kind == BroodNew.PILE:
		return true
	return bool(u.d.get("new_brood", false)) and u.tesla_mode != "packed"


## Prey: a worker, or a unit on its feet that can't fight back (not a loose horse, not a structure).
static func is_prey(e) -> bool:
	if not (e is Unit) or e.dead or e.off_field or e.aboard != null or is_static(e):
		return false
	return e.is_worker() or (not Game.fights_back(e) and e.kind != "horse")


## A real defender: an armed enemy on its feet (a worker or a rooted creature is not).
static func is_defender(e) -> bool:
	return Game.fights_back(e) and not e.off_field and not is_static(e)


## A defender the party never stands against: a Sire (a father) or the Brood Mother on her feet.
static func is_big(e) -> bool:
	return is_defender(e) and (bool(e.d.get("father", false)) or e.kind == BroodNew.QUEEN)


# ------------------------------------------------------------------ the measures

## The party's strength (the computer's own measure: value, less when hurt).
func strength(party: Array) -> float:
	var v := 0.0
	for u in party:
		v += ai._unit_value(u)
	return v


## The armed enemies on their feet near `c` it can see (or that just hit one of the party).
func defenders_near(c: Vector2, party: Array) -> Array:
	var out: Array = []
	for o in game.units_near(c, DANGER_R):
		if not game.hostile(o.team, ai.team) or not is_defender(o) or not game.is_visible_to(ai.team, o.position):
			continue
		if party.any(func(u: Unit) -> bool: return o.can_hit(u)):
			out.append(o)
	for u in party:
		var h = u.last_hitter
		if is_instance_valid(h) and h is Unit and not h.dead and game.clock - u.hit_clock < 2.0 and is_defender(h) and not out.has(h):
			out.append(h)
	return out


## Too strong to stand against: a Sire or the Mother on her feet, or armed units worth more than the party.
func outmatched(party: Array, foes: Array) -> bool:
	if foes.is_empty():
		return false
	var theirs := 0.0
	for o in foes:
		if is_big(o):
			return true
		theirs += ai._unit_value(o)
	return theirs > strength(party) * 1.05


## The best worker (or unarmed unit) for `u` to go after: the nearest it can see within PREY_R tiles, the ones in reach
## of an armed defender counted farther (no rooted creature attacks: a grub loading at its Rootmaw is fair game).
func pick_prey(u: Unit) -> Unit:
	var best: Unit = null
	var bs := INF
	var near: Array = game.units_near(u.position, PREY_R * Defs.TILE + 120.0)
	var biters: Array = near.filter(func(o: Unit) -> bool:
		return game.hostile(o.team, ai.team) and is_defender(o) and o.can_hit(u))
	for o in near:
		if not game.hostile(o.team, ai.team) or not is_prey(o) or not u.can_hit(o) or not game.is_visible_to(ai.team, o.position):
			continue
		var s: float = o.position.distance_to(u.position)
		if s > PREY_R * Defs.TILE:
			continue
		for b in biters:
			if b.position.distance_to(o.position) <= float(b.d["range"]) + b.radius + u.radius + 30.0:
				s += 400.0
		# one walking away as fast as it is is not caught: the ones standing (a grub loading at its Rootmaw) or coming
		# towards it first; the one it is after already is kept unless another is clearly better (no to and fro)
		if o.velocity.length() > 10.0 and o.velocity.dot(o.position - u.position) > 0.0 and float(o.d["speed"]) >= float(u.d["speed"]) * 0.9:
			s += 160.0
		if o == u.order_target:
			s -= 90.0
		if s < bs:
			bs = s
			best = o
	return best


## Where the worker line is: the enemy's workers it can see (the farther from their main the better), else its economy
## buildings, else the Brood's Rootmaws or Mother it has seen, else its base (AI._prey_spot).
func work_line(from: Vector2) -> Vector2:
	var p: Vector2 = ai._prey_spot(from)
	var foe: int = ai._foe()
	if foe >= 0 and game.faction_of(foe) == "brood":
		# (the Brood has no economy buildings: its grubs walk between the Rootmaws and the Mother)
		var best := Vector2.INF
		var bd := INF
		var seen_worker := false
		for o in game.units:
			if o.team == foe and not o.dead and o.is_worker() and game.is_visible_to(ai.team, o.position):
				seen_worker = true
				break
		if not seen_worker:
			for o in game.units:
				if o.team != foe or o.dead or not (o.kind == BroodNew.MAW or o.kind == BroodNew.QUEEN):
					continue
				if not game.is_visible_to(ai.team, o.position) and not (ai.scout != null and ai.scout._nb_seen.has(o)):
					continue
				var dd: float = o.position.distance_to(from)
				if dd < bd:
					bd = dd
					best = o.position
			if best != Vector2.INF:
				p = best
	return p


# ------------------------------------------------------------------ one unit, one step

## Steer one harassing unit for a second: pull back from a real defender, go after prey, fight a weak defender in its
## face, else walk on (never stopping at a structure). Returns "back", "prey", "fight", "walk" or "stuck".
func steer(u: Unit, party: Array, goal: Vector2, home: Vector2, e: Dictionary) -> String:
	var foes := defenders_near(u.position, party)
	if outmatched(party, foes):
		var away := Vector2.ZERO
		for o in foes:
			away += (u.position - o.position).normalized()
		var dir := (home - u.position).normalized()
		if away != Vector2.ZERO:
			dir = (dir + away.normalized()).normalized()
		if e.get("back_until", 0.0) < game.clock:
			e["backs"] = int(e.get("backs", 0)) + 1
			_say(u, "pulls back from %s" % String(Defs.UNITS[foes[0].kind]["name"]))
		e["back_until"] = game.clock + BACK_FOR
		u.cmd_move(u.position + dir * 260.0)
		return "back"
	if float(e.get("back_until", 0.0)) > game.clock:
		if u.order == "idle":
			u.cmd_move(u.position + (home - u.position).normalized() * 160.0)
		return "back"
	var w := pick_prey(u)
	if w:
		if u.order != "attack" or u.order_target != w:
			u.cmd_attack(w)
		e["still"] = 0.0
		return "prey"
	# an armed enemy it can beat is in its face: it fights it (it does not turn its back)
	if not foes.is_empty():
		var f: Unit = foes[0]
		if u.order != "attack" or u.order_target == null or not is_instance_valid(u.order_target) or u.order_target.dead or is_static(u.order_target):
			u.cmd_attack(f)
		return "fight"
	# walk on to the worker line, past structures (a plain move); stuck there: break through
	var lp: Vector2 = e.get("last_pos", u.position)
	if lp.distance_to(u.position) < 12.0:
		e["still"] = float(e.get("still", 0.0)) + _dt
	else:
		e["still"] = 0.0
	e["last_pos"] = u.position
	if float(e["still"]) >= STUCK_FOR and u.position.distance_to(goal) > 140.0:
		if not (u.order == "amove" or u.order == "attack"):
			u.cmd_move(goal, true)      # (the way is shut: it breaks what is in it)
			e["still"] = 0.0
			e["stuck_t"] = game.clock
		return "stuck"
	if game.clock - float(e.get("stuck_t", -99.0)) < 6.0 and u.order == "attack" and is_static(u.order_target):
		return "stuck"
	var tgt = u.target if u.target != null and is_instance_valid(u.target) else null
	var wrong: bool = u.order == "idle" or u.order == "amove" or (u.order == "attack" and is_static(u.order_target)) \
		or (tgt != null and is_static(tgt)) or u.order_point.distance_to(goal) > 160.0
	if wrong and u.position.distance_to(goal) > 120.0:
		u.cmd_move(goal + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	elif u.position.distance_to(goal) <= 120.0:
		e["goal_done"] = true
	return "walk"


# ------------------------------------------------------------------ the party

func has(u: Unit) -> bool:
	return units.has(u)


## Take a unit on (a stray chaser, a lone survivor out in the field). False if it may not.
func add(u: Unit, why: String) -> bool:
	if units.has(u):
		return true
	if units.size() >= MAX_UNITS or float(done.get(u, -1.0)) > game.clock:
		return false
	units[u] = {"t0": game.clock, "back_until": 0.0, "backs": 0, "home": false, "last_pos": u.position, "still": 0.0}
	u.remove_meta("ai_scout")
	_say(u, "goes on to harass the workers (%s)" % why)
	return true


func _let_go(u: Unit) -> void:
	units.erase(u)
	done[u] = game.clock + 60.0


## Army units out alone far from home, chasing or wandering (not in a wave, a detachment, a guard, the Crown's raid, the
## scout or on an errand): they become harassers instead of standing at the first thing they meet.
func adopt_strays(army: Array) -> void:
	if ai.difficulty < 1 or ai.peaceful or ai._foe() < 0:
		return
	for u in army:
		if units.size() >= MAX_UNITS:
			return
		if units.has(u) or u.dead or u.off_field or u.is_air() or u.deploys() or not u.has_attack() or u.is_worker():
			continue
		if not (u.order == "amove" or u.order == "attack" or u.order == "idle"):
			continue
		if ai._wave_set.has(u) or ai._det.has(u) or ai._raiders.has(u) or ai._on_errand(u) or (ai.scout != null and (u == ai.scout.unit or u == ai.scout.sentry)):
			continue
		if ai._clock() and ai.r5.busy(u):
			continue
		if float(u.d.get("speed", 0)) < 55.0 or ai._home_dist(u.position) < STRAY_FROM:
			continue
		add(u, "out alone")


## Every army think: each harasser steers (see steer); hurt, run down, out too long or driven back too often, it goes
## home and is let go when there.
func tick() -> void:
	_dt = clampf(game.clock - _last_t, 0.0, 3.0) if _last_t >= 0.0 else 1.0
	_last_t = game.clock
	if units.is_empty():
		return
	var party: Array = []
	for u in units.keys():
		if not is_instance_valid(u) or u.dead:
			units.erase(u)
			continue
		party.append(u)
	if party.is_empty():
		return
	var post: Vector2 = ai._post_spot()
	var home: Vector2 = post if post != Vector2.INF else game.center_of_team(ai.team)
	var c := Vector2.ZERO
	for u in party:
		c += u.position
	c /= party.size()
	var goal := work_line(c)
	for u in party:
		var e: Dictionary = units[u]
		if not e["home"]:
			var why := ""
			if u.hp < u.max_hp * HOME_HP:
				why = "hurt"
			elif ai._clock() and u.wind < 0.25 and not u.runs_on_spring() and not u._in_field:
				why = "running down"
			elif game.clock - float(e["t0"]) > MAX_TIME:
				why = "out long enough"
			elif int(e["backs"]) >= MAX_BACKS and float(e["back_until"]) < game.clock:
				why = "driven back too often"
			if why != "":
				e["home"] = true
				_say(u, "goes home (%s)" % why)
		if e["home"]:
			if ai._home_dist(u.position) < 300.0:
				_let_go(u)
				u.cmd_move(home, true)
			elif u.order != "move" or u.order_point.distance_to(home) > 120.0:
				u.cmd_move(home)
			continue
		var g := goal
		if e.get("goal_done", false):
			# (at the worker line and nothing to hunt: a loop round the enemy's base, then the line again)
			g = ai._enemy_base() + Vector2.from_angle(fmod(game.clock * 0.05, TAU)) * 6.0 * Defs.TILE
			if u.position.distance_to(g) < 140.0:
				e["goal_done"] = false
		e["state"] = steer(u, party, g, home, e)
