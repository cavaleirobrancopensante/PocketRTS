class_name ShieldWall
extends RefCounted
## The Clock Soldier's SHIELD FORWARD (docs/clock_soldier_shield.md): once its side has researched SHIELD WALL at a
## Movement Works (Defs.RESEARCH "shield_wall"), a Clock Soldier can raise its shield in front of it. Switching takes
## Defs.SHIELD_WALL "switch" s (it stands still and starts no blow meanwhile). Raised: it walks at "speed" of its pace,
## has "armor" more armour, takes "front" less from shots and "front_melee" less from blows from in front of it, and
## swings "cooldown" x slower.
## Splash (shells, blasts, clouds: a blow of kind "") and blows from the side or behind are not stopped.
## Its state: Unit.shield_up (raised or being raised) and Unit.shield_t (the switch under way), both synced to online
## guests (NetSnapshot.UNIT_PROPS). Reached from unit.gd (set_shield, the tick, take_damage, _cooldown, _anim_name),
## the HUD's SHIELD FORWARD button and the Clockwork computer (think).

const KIND := "clock_soldier"
const TECH := "shield_wall"


static func can(u: Unit) -> bool:
	return u.kind == KIND and not u.dead and u.game.has_tech(u.team, TECH)


## Raised and settled: the stance's effects apply.
static func active(u: Unit) -> bool:
	return u.shield_up and u.shield_t <= 0.0


## Why it cannot switch ("" if it can).
static func problem(u: Unit) -> String:
	if u.kind != KIND:
		return "Only Clock Soldiers."
	if not u.game.has_tech(u.team, TECH):
		return "Research SHIELD WALL at a Movement Works first."
	return ""


## Raise (on) or lower the shield. Takes the switch time; nothing if it is already so.
static func set_up(u: Unit, on: bool) -> void:
	if u.dead or u.aboard or u.shield_up == on or problem(u) != "":
		return
	u.shield_up = on
	u.shield_t = float(Defs.SHIELD_WALL["switch"])
	u.armor = float(u.d["armor"])       # (the armour comes once the shield is up: tick)
	u.frame_i = 0
	u.anim_t = 0.0
	if u.visible and u.game.view_rect.has_point(u.position):
		Sfx.play_any(["combat/shield_up" if on else "combat/shield_down", "ratchet"], u.position, -10.0)


## Every tick, after the unit's speed is worked out for the tick: the switch, then the stance's pace and armour.
static func tick(u: Unit, delta: float) -> void:
	if u.shield_t > 0.0:
		u.shield_t = maxf(u.shield_t - delta, 0.0)
		u.speed = 0.0                                   # (it stands to switch)
		u.cooldown = maxf(u.cooldown, u.shield_t)       # (and starts no blow)
		if u.shield_t <= 0.0 and u.shield_up:
			u.armor = float(u.d["armor"]) + float(Defs.SHIELD_WALL["armor"])
		return
	if u.shield_up:
		u.speed *= float(Defs.SHIELD_WALL["speed"])


## A blow or shot at it (Unit.take_damage): less if raised and it came from in front.
static func incoming(u: Unit, amount: float, from: Entity, blow: String) -> float:
	if not active(u) or blow == "" or from == null or not is_instance_valid(from) or from == u:
		return amount
	if not from_front(u, from.center() if from is Building else from.position):
		return amount
	if u.visible and u.game.view_rect.has_point(u.position):
		u.game.spawn_effect("hit", u.center() + u.facing * 9.0 + Vector2(randf_range(-3, 3), randf_range(-6, 3)), 1.0)
	return amount * (1.0 - float(Defs.SHIELD_WALL["front" if blow == Entity.BLOW_RANGED else "front_melee"]))


## Is point p in front of the soldier (inside the shield's cone)?
static func from_front(u: Unit, p: Vector2) -> bool:
	var to := p - u.position
	if to.length() < 0.5:
		return true
	return to.normalized().dot(u.facing.normalized()) >= float(Defs.SHIELD_WALL["cone"])


static func cooldown_mult(u: Unit) -> float:
	return float(Defs.SHIELD_WALL["cooldown"]) if u.shield_up else 1.0


## The strip it shows: raised (or switching) it stands or walks behind its shield.
static func anim(u: Unit, moving: bool) -> String:
	if not u.shield_up:
		return ""
	return u._anim_or("guard_walk", "walk") if moving and u.shield_t <= 0.0 else u._anim_or("guard", "idle")


# ------------------------------------------------------------------ the computer (Clockwork, gear mode)

const AI_NEAR := 280.0              # shooters this close count (px)
const AI_SHOOTERS := 2              # this many raise the shields
const AI_HOLD := 2.5                # s between two switches of one soldier (no flicker)


## Is this enemy a shooter the shield is for (musketeers, spitters, jacks ...; not guns' splash)?
static func shooter(o: Unit) -> bool:
	return not o.dead and not o.off_field and not o.is_worker() and float(o.d.get("range", 0.0)) >= 100.0 \
			and o.kind != "cannon" and o.kind != "mortar" and o.kind != "spore_mother"


## The computer's Clock Soldiers: raise the shields when they walk into ranged fire (2+ shooters within AI_NEAR) and
## are not chasing or falling back; lower them to chase a shooter that walks off, to fall back (a plain move away from
## the enemy), or when no shooter is near.
static func think(game: Game, team: int) -> void:
	if not game.has_tech(team, TECH):
		return
	for u in game.army(team):
		if u.kind != KIND or u.dead or u.shield_t > 0.0 or u.powered_down():
			continue
		if game.clock - float(u.cw.get("sw_t", -99.0)) < AI_HOLD:
			continue
		var shooters := 0
		var near := INF
		var at := Vector2.ZERO
		for o in game.units_near(u.position, AI_NEAR):
			if game.hostile(o.team, team) and shooter(o) and game.side_sees(team, o.position):
				shooters += 1
				at += o.position
				near = minf(near, o.position.distance_to(u.position))
		var want: bool = u.shield_up
		if not u.shield_up:
			want = shooters >= AI_SHOOTERS and not fleeing(u) and not chasing(u)
		else:
			want = shooters >= 1 and not fleeing(u) and not chasing(u)
		if want != u.shield_up:
			set_up(u, want)
			u.cw["sw_t"] = game.clock
			if want and shooters > 0 and u.target == null:
				u.facing = (at / float(shooters) - u.position).normalized()


## Falling back: a plain move (not an attack-move) that takes it away from its nearest seen enemy.
static func fleeing(u: Unit) -> bool:
	if u.order != "move":
		return false
	var foe: Entity = u.game.find_target(u, u.sight * Defs.TILE)
	if foe == null:
		return false
	return (u.order_point - u.position).dot(foe.position - u.position) < 0.0


## Chasing: its target is a unit out of reach and moving away from it.
static func chasing(u: Unit) -> bool:
	var e = u.target if u.target != null and is_instance_valid(u.target) else u.order_target
	if e == null or not is_instance_valid(e) or not (e is Unit):
		return false
	var gap: float = e.edge_distance(u.position) - u.radius
	if gap <= u._range() + 6.0:
		return false
	var away: Vector2 = e.position - u.position
	return (e as Unit).velocity.dot(away) > 10.0 * away.length()
