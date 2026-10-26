class_name Jack
extends RefCounted
## THE JACK (gear mode's Clockwork tier 2, Defs.UNITS "jack"; numbers in Defs.JACK_JUMP and Defs.JACK_SHOT): a
## jack-in-the-box on a coil spring. Its walk is a hop, it shoots spinning screws from its drill arm (Game.screw_shot, the
## Ratchet Turret's projectile, from the drill tip), at the ground and at flyers.
## JUMP: an ability aimed at a point (the card's JUMP, then a tap; Game.cast_order "jump"): the spring presses down (the
## crouch, readable and answerable), then the Jack flies along an arc to the spot and lands. Flat ground and DOWN cliffs:
## always; UP onto higher ground: only once HIGH LEAP is researched and its side sees the spot; never onto water, cliffs,
## buildings or walls. Nothing it does from the crouch to the landing is a fight: it cannot attack in the air (it can be
## hit). Its state lives on the Unit: `jump` (the leap under way, {} when none) and `jump_cd` (seconds to the next one).
## The computer's Jacks jump away from melee when low (ai_tick).
## Art: tools/import_jack.py (strip "jump": crouch 0-2, launch 3, air 4-5, landing 6-7, every frame on its foot plate: the
## lift is the arc's, over the unit's own ground shadow).

const CROUCH_FRAMES := 3


# ------------------------------------------------------------------ jumping

## "" when unit u can start a jump now (the spot aside), else why not.
static func ready_problem(u: Unit) -> String:
	if u == null or u.dead or u.kind != Defs.JACK:
		return "Only a Jack can JUMP."
	if not u.jump.is_empty():
		return "It is already jumping."
	if u.jump_cd > 0.0:
		return "The spring is still winding back: JUMP in %d s." % int(ceil(u.jump_cd))
	if u.powered_down():
		return "It has run down: wind it up first."
	return ""


## Where unit u lands jumping toward p: {"at": the spot} or {"why": why it cannot}. A spot past its reach: the full reach that
## way. The level of the spot clicked decides up or down; a spot it cannot land on gives way to the nearest one within
## Defs.JACK_JUMP "search" tiles on that level (and still in reach).
static func landing(u: Unit, p: Vector2) -> Dictionary:
	var g := u.game
	var from := u.position
	var reach := float(Defs.JACK_JUMP["range"])
	var aim := p
	if from.distance_to(p) > reach:
		aim = from + (p - from).normalized() * reach
	var c_click := g.cell_of(g.on_map(p))
	var lv_to := int(g.height[g.idx(c_click)]) if g.in_map(c_click) else g.level_of(from)
	var up := lv_to > g.level_of(from)
	if up and not g.has_tech(u.team, "high_leap"):
		return {"why": "Jumping UP onto high ground needs HIGH LEAP: research it at the Escapement."}
	var best := Vector2.INF
	if _can_land(u, aim, lv_to):
		best = aim
	else:
		var c0 := g.cell_of(aim)
		var n := int(Defs.JACK_JUMP["search"])
		var bd := INF
		for y in range(-n, n + 1):
			for x in range(-n, n + 1):
				var q := g.cell_center(c0 + Vector2i(x, y))
				if q.distance_to(from) > reach + 2.0:
					continue
				var dd := q.distance_to(aim)
				if dd < bd and _can_land(u, q, lv_to):
					bd = dd
					best = q
	if best == Vector2.INF:
		return {"why": "No room to land there."}
	if up and not g.side_sees(u.team, best):
		return {"why": "A Jack can only jump up where you can see."}
	if best.distance_to(from) < 16.0:
		return {"why": "Too close to jump."}
	return {"at": best}


## Open walkable ground on level `lv`: no water, cliff, building, wall or gate, and room for the unit.
static func _can_land(u: Unit, q: Vector2, lv: int) -> bool:
	var g := u.game
	var c := g.cell_of(q)
	if not g.in_map(c):
		return false
	var i := g.idx(c)
	var sv: int = g.solid[i]
	if (sv != 0 and sv != 5) or g.water[i] != 0 or g.cliff[i] != 0 or int(g.height[i]) != lv:
		return false
	return g._clear_at(q, u.radius, -1)


## "" when unit u can jump toward p now, else why not.
static func problem(u: Unit, p: Vector2) -> String:
	var w := ready_problem(u)
	if w != "":
		return w
	return String(landing(u, p).get("why", ""))


## The selected Jacks jump: each one that can, to its own spot of the group round p (one alone: p itself). "" when at
## least one jumps, else why none did.
static func jump_order(game: Game, list: Array, p: Vector2) -> String:
	var jacks: Array = list.filter(func(u) -> bool: return u is Unit and is_instance_valid(u) and not u.dead and u.kind == Defs.JACK)
	if jacks.is_empty():
		return "Only a Jack can JUMP."
	var ready: Array = jacks.filter(func(u: Unit) -> bool: return ready_problem(u) == "")
	if ready.is_empty():
		return ready_problem(jacks[0])
	var spots: Dictionary = game.group_points(ready, p) if ready.size() > 1 else {ready[0]: p}
	var why := ""
	var n := 0
	for u in ready:
		var at: Vector2 = spots.get(u, p)
		var l := landing(u, at)
		if not l.has("at") and at != p:
			l = landing(u, p)          # (its share of the group's spot is no good: the spot itself)
		if l.has("at"):
			start(u, l["at"])
			n += 1
		elif why == "":
			why = String(l["why"])
	if n > 0 and not jacks.is_empty() and jacks[0].team == game.human:
		game._ping(p, Color(0.95, 0.8, 0.4))
	return "" if n > 0 else why


## Unit u leaps to `at` (a spot landing() found): the crouch starts now. Whatever it was doing stops (it stands still once it
## lands); the spring needs Defs.JACK_JUMP "cooldown" s before the next.
static func start(u: Unit, at: Vector2) -> void:
	var jj: Dictionary = Defs.JACK_JUMP
	var dist := u.position.distance_to(at)
	u.cmd_stop()
	u.queue.clear()
	u.jump = {"from": u.position, "to": at, "t": 0.0, "crouch": float(jj["crouch"]),
		"air": float(jj["air"]) + dist / float(jj["air_speed"]), "land": float(jj["land"]),
		"peak": float(jj["peak"]) + float(jj["peak_per"]) * dist, "off": false, "down": false}
	u.jump_cd = float(jj["cooldown"])
	u.phase = ""
	u.velocity = Vector2.ZERO
	if dist > 1.0:
		u.facing = (at - u.position).normalized()
	u.jumps += 1
	if u.visible and u.game.view_rect.has_point(u.position):
		Sfx.play_any(["combat/jack_crouch", "ratchet"], u.position, -6.0)
	if u.game.mlog and u.team == u.game.human and u.jumps == 1:
		u.game.mlog.add("%s's Jack jumped (%.0f tiles)" % [u.game.mlog.who(u.team), dist / Defs.TILE])


## How far through its leap unit u is: the seconds of each part and the time now.
static func _parts(u: Unit) -> Array:
	var j: Dictionary = u.jump
	return [float(j["t"]), float(j["crouch"]), float(j["air"]), float(j["land"])]


## Every tick of a leap (instead of moving and fighting: Unit._tick_unit): the crouch where it stands, the flight along
## the ground line from where it stood to the spot (the sprite lifted by the arc: lift()), the landing; then it is done.
static func tick(u: Unit, delta: float) -> void:
	var j: Dictionary = u.jump
	j["t"] = float(j["t"]) + delta
	var pr := _parts(u)
	var t: float = pr[0]
	var c: float = pr[1]
	var a: float = pr[2]
	var l: float = pr[3]
	u.velocity = Vector2.ZERO
	u.phase = ""
	if t >= c and not bool(j["off"]):
		j["off"] = true          # (off the ground: the launch)
		if u.visible and u.game.view_rect.has_point(u.position):
			Sfx.play_any(["combat/jack_jump", "combat/arrow_whoosh"], u.position, -4.0)
	if t < c:
		pass
	elif t < c + a:
		u.position = (j["from"] as Vector2).lerp(j["to"], (t - c) / a)
	else:
		u.position = j["to"]
		if not bool(j["down"]):
			j["down"] = true     # (touched down: a puff of dust)
			if u.visible and u.game.view_rect.has_point(u.position):
				var fx := u.game.spawn_effect("dust", u.position + Vector2(0, -2), 1.6)
				fx.scale = Vector2(0.55, 0.45)
				Sfx.play_any(["combat/jack_land", "gear_hit"], u.position, -8.0)
		if t >= c + a + l:
			u.jump = {}
			u.leash_from = u.position
			# (an order given in the air: its way is worked out again from here)
			u.path = PackedVector2Array()
			u.path_i = 0
			if (u.order == "move" or u.order == "amove") and u.path_goal != Vector2.INF:
				u._request_path(u.path_goal)
	if u.sprite:
		u.sprite.position = Vector2(0.0, -lift(u))


## The sprite's height over its ground shadow now (px): 0 on the ground, the arc in the air.
static func lift(u: Unit) -> float:
	if u.jump.is_empty():
		return 0.0
	var pr := _parts(u)
	var t: float = pr[0]
	var c: float = pr[1]
	var a: float = pr[2]
	if t < c or t >= c + a:
		return 0.0
	var f := (t - c) / a
	return float(u.jump["peak"]) * 4.0 * f * (1.0 - f)


## In the air (off the ground)?
static func airborne(u: Unit) -> bool:
	return lift(u) > 0.0


## The frame of the "jump" strip now: crouch 0-2 over the crouch, launch 3 and the air 4 (going up) and 5 (coming down)
## over the flight, landing 6-7.
static func frame(u: Unit) -> int:
	if u.jump.is_empty():
		return 0
	var pr := _parts(u)
	var t: float = pr[0]
	var c: float = pr[1]
	var a: float = pr[2]
	var l: float = pr[3]
	if t < c:
		return mini(CROUCH_FRAMES - 1, int(t / maxf(c, 0.01) * CROUCH_FRAMES))
	if t < c + a:
		var f := (t - c) / a
		return 3 if f < 0.18 else (4 if f < 0.55 else 5)
	return 6 if t < c + a + l * 0.5 else 7


# ------------------------------------------------------------------ the shot

## Does it shoot UP now (its target a flyer): it raises its arm (the "attack_up" strip; Defs.JACK_SHOT_UP).
static func aims_up(u: Unit) -> bool:
	return u.target != null and is_instance_valid(u.target) and u.target.is_air() and ArtData.UNITS[u.art]["frames"].has("attack_up_s")


## The drill tip in world px for the way it faces now (Defs.JACK_SHOT "tips": from its feet, per drawn direction; the
## west views mirror the east ones), lifted with it; the raised arm's tip (Defs.JACK_SHOT_UP) when it shoots at a flyer.
static func tip(u: Unit, up := false) -> Vector2:
	var dd: Array = Unit.DIR_FLIP[posmod(int(round(u.facing.angle() / (PI / 4.0))), 8)]
	var o: Vector2 = (Defs.JACK_SHOT_UP if up else Defs.JACK_SHOT)["tips"][String(dd[0])]
	if bool(dd[1]):
		o.x = -o.x
	return u.position + o - Vector2(0.0, lift(u))


## The raised barrel's direction (world) for the way it faces now: the muzzle burst blows along it.
static func barrel_up(u: Unit) -> Vector2:
	var dd: Array = Unit.DIR_FLIP[posmod(int(round(u.facing.angle() / (PI / 4.0))), 8)]
	var b: Vector2 = Defs.JACK_SHOT_UP["barrel"][String(dd[0])]
	if bool(dd[1]):
		b.x = -b.x
	return b


## Its screw: the damage lands now; the screw flies from the drill tip with a muzzle burst there (Game.screw_shot). At a
## flyer the arm is raised: the screw leaves the raised tip and the burst blows along the raised barrel.
static func shoot(u: Unit, e: Entity, dmg: float) -> void:
	var js: Dictionary = Defs.JACK_SHOT
	var up: bool = e != null and e.is_air() and ArtData.UNITS[u.art]["frames"].has("attack_up_s")
	u.shots += 1
	u.last_shot = u.game.screw_shot(u, e, dmg, tip(u, up), [], float(js["shot_scale"]), float(js["muzzle_scale"]), float(js["speed"]),
		barrel_up(u) if up else Vector2.ZERO)
	u.last_tip = tip(u, up)


# ------------------------------------------------------------------ the computer's Jacks

## A computer's Jack, a few times a second: low on health with an enemy that fights hand to hand close by, it jumps away
## from it (back toward its own side), on flat ground or down.
static func ai_tick(u: Unit) -> void:
	if u.hp > u.max_hp * float(Defs.JACK_JUMP["ai_low"]) or ready_problem(u) != "":
		return
	var near: Unit = null
	var nd := INF
	for o in u.game.units_near(u.position, 90.0):
		if o.dead or o.off_field or o.is_air() or not u.game.hostile(o.team, u.team) or not o.has_attack():
			continue
		if float(o.d["range"]) > 60.0:
			continue          # (a shooter: running does not help)
		var dd: float = o.position.distance_to(u.position)
		if dd < nd:
			nd = dd
			near = o
	if near == null:
		return
	var away := (u.position - near.position).normalized()
	var home := u.game.center_of_team(u.team)
	if home != Vector2.ZERO:
		away = (away + (home - u.position).normalized() * 0.6).normalized()
	for turn in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var to := u.position + away.rotated(turn) * float(Defs.JACK_JUMP["range"])
		var l := landing(u, to)
		if l.has("at") and u.game.level_of(l["at"]) <= u.game.level_of(u.position):
			start(u, l["at"])
			return


# ------------------------------------------------------------------ the JUMP target (the player's cast mode)

## While the player picks where to jump (Game._draw_overlay_all, over the rings and buildings): every selected Jack's reach, and the spot
## the nearest ready one would land on (green, with its arc) or a red cross where it cannot.
static func draw_target(game: Game, ci: CanvasItem, at: Vector2) -> void:
	var best: Unit = null
	var bd := INF
	var reach := float(Defs.JACK_JUMP["range"])
	for e in game.selection:
		if not (e is Unit) or not is_instance_valid(e) or e.dead or e.kind != Defs.JACK:
			continue
		var u: Unit = e
		var ok := ready_problem(u) == ""
		var col := Color(0.95, 0.85, 0.45, 0.55) if ok else Color(0.6, 0.6, 0.6, 0.35)
		ci.draw_set_transform(u.position, 0.0, Vector2(1.0, Game.FIELD_Y))
		ci.draw_arc(Vector2.ZERO, reach, 0.0, TAU, 64, col, 1.5)
		ci.draw_set_transform(Vector2.ZERO)
		var dd: float = u.position.distance_to(at)
		if ok and dd < bd:
			bd = dd
			best = u
	if best == null:
		return
	var l := landing(best, at)
	if l.has("at"):
		var p: Vector2 = l["at"]
		var green := Color(0.55, 1.0, 0.5, 0.9)
		ci.draw_set_transform(p, 0.0, Vector2(1.0, Game.FIELD_Y))
		ci.draw_circle(Vector2.ZERO, best.radius + 6.0, Color(green.r, green.g, green.b, 0.18))
		ci.draw_arc(Vector2.ZERO, best.radius + 6.0, 0.0, TAU, 24, green, 2.0)
		ci.draw_set_transform(Vector2.ZERO)
		# the arc it would fly
		var from := best.position
		var dist := from.distance_to(p)
		var peak := float(Defs.JACK_JUMP["peak"]) + float(Defs.JACK_JUMP["peak_per"]) * dist
		for i in range(1, 12):
			var f := float(i) / 12.0
			ci.draw_circle(from.lerp(p, f) - Vector2(0.0, peak * 4.0 * f * (1.0 - f)), 1.6, Color(green.r, green.g, green.b, 0.7))
	else:
		var red := Color(1.0, 0.35, 0.3, 0.9)
		ci.draw_line(at + Vector2(-7, -7), at + Vector2(7, 7), red, 2.5)
		ci.draw_line(at + Vector2(-7, 7), at + Vector2(7, -7), red, 2.5)
