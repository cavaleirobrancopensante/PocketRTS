class_name RideBy
extends RefCounted
## The Horseman and the Cuirassier fight on the move, like StarCraft 2's Cyclone with a sabre (the owner,
## 2026-10-27; docs/ride_by.md, the numbers in Defs.RIDE_BY):
## - On any order (move, attack-move, attack, patrol, follow, the computer's hunts and raids), while he rides,
##   he strikes an enemy within sabre reach as he passes, on his normal cooldown, without slowing or stopping (blows).
## - Told to attack (or fighting what he picked on an attack-move), he rides AT the target, strikes in passing, rides
##   on a little past it and swings round its far end for the next pass along its other side (a loop round the
##   target, like a racetrack), instead of standing beside it (steer). A fleeing man is ridden down: he aims where the
##   man will be.
## - His one loaded pistol shot is fired on the move too (on an attack or an attack-move; a plain move keeps it).
## - HOLD POSITION, and standing idle (stopped, on guard): he stands and fights as before (Unit._engage). A wall or
##   gate piece is hacked at standing too (a horse can't ride through a wall).
## Everything here runs on the game clock and the units' own state (no randomness): the same in every replay and
## online (the host simulates; ride_n, streamed, tells a guest to draw the sabre arc).


## (tests only: tools/test_ride_by_raid.gd turns it off to measure the old standing fight)
static var enabled := true


## The orders he rides on (a patrol is a move or an attack-move). Standing (idle, on guard) or on HOLD he fights as
## before: told to stop, he stops, and strikes what comes to him.
const ORDERS := ["move", "amove", "attack", "follow"]


## Fights on the move this tick: a Horseman or Cuirassier in the saddle, under way on an order.
static func rides(u: Unit) -> bool:
	return enabled and (Defs.RIDE_BY["kinds"] as Array).has(u.kind) and ORDERS.has(u.order) and u.aboard == null and not u.off_field


## The blows struck in passing: the pistol (his one loaded shot, at a man ahead in its reach, on an attack-move,
## an attack or on guard) and the sabre (whatever enemy comes within reach; on an attack order only the target).
static func blows(u: Unit, delta: float) -> void:
	if u.stun_t > 0.0 or u.phase != "" or u.dead:
		u.rb_aim = 0.0
		return
	var fights := u.order == "attack" or u.order == "amove"
	if u.pistol and not u.hold_fire and fights:
		if u.rb_aim > 0.0:
			# (he takes aim as he comes into reach, a gallop's worth of the aim time early, and fires once in reach)
			var a := u.rb_aim_e
			var rng := float(Defs.PISTOL["range"])
			var dd := a.edge_distance(u.position) - u.radius if a != null and is_instance_valid(a) else INF
			if a == null or not u._valid_target(a) or dd > rng + _early(u) + 8.0:
				u.rb_aim = 0.0           # (he rode out of reach, or the man is gone: no shot yet)
				u.rb_aim_e = null
			else:
				u.rb_aim = maxf(u.rb_aim - delta, 0.001)
				if u.rb_aim <= 0.001 and dd <= rng:
					u.rb_aim = 0.0
					u.rb_aim_e = null
					var was := u.mode
					u.mode = "pistol"
					u._strike(a)
					u.mode = was
					u.cooldown = maxf(u.cooldown, float(Defs.PISTOL["after"]))
				return                   # (aiming: the sabre waits)
		elif u.cooldown <= 0.0:
			var p := _pistol_mark(u)
			if p != null:
				u.rb_aim = float(Defs.PISTOL["aim"])
				u.rb_aim_e = p
				return
	if u.cooldown > 0.0:
		return
	var e := _sabre_mark(u)
	if e == null:
		return
	var was2 := u.mode
	u.mode = ""
	u._ride_blow = true
	u._strike(e)
	u._ride_blow = false
	u.cooldown = u._cooldown()
	u.mode = was2
	u.ride_n += 1
	if e == u.target and u.rb_state == "in":
		u.rb_state = "out"              # (struck: he rides on past it before he turns)
		u.rb_t = 0.0


## His sabre's reach from his edge (Defs.UNITS range).
static func _reach(u: Unit) -> float:
	return float(u.d["range"])


static func _in_reach(u: Unit, e: Entity) -> bool:
	return e.edge_distance(u.position) - u.radius <= _reach(u)


## What the sabre strikes now: the target if it is in reach; on an attack order nothing else (the order is to cut
## that one down); else the nearest enemy man in reach (a fighter before a worker, a horse last).
static func _sabre_mark(u: Unit) -> Entity:
	var t: Entity = u.target if u.target != null and is_instance_valid(u.target) else null
	if u.order == "attack":
		t = u.order_target if u.order_target != null and is_instance_valid(u.order_target) else t
	if t != null and u._valid_target(t) and _in_reach(u, t) and not _wall(t):
		return t
	if u.order == "attack":
		return null
	var best: Entity = null
	var bd := INF
	var r := _reach(u) + u.radius + 24.0
	for o in u.game.units_near(u.position, r):
		if o == u or o.dead or o.off_field or o.is_air() or not u.game.prey(u.team, o) or not u.can_hit(o):
			continue
		if not _in_reach(u, o):
			continue
		var dd: float = o.position.distance_to(u.position)
		if o.kind == "horse":
			dd += 150.0
		elif not Game.fights_back(o):
			dd += 30.0
		if dd < bd or (dd == bd and best != null and o.serial < (best as Unit).serial):
			bd = dd
			best = o
	return best


## The pistol's mark: the target (a man, not a building) within the pistol's reach and seen; on an attack-move or on
## guard also the nearest enemy man ahead of him in reach.
static func _pistol_mark(u: Unit) -> Entity:
	var rng := float(Defs.PISTOL["range"]) + _early(u)
	var t: Entity = u.order_target if u.order == "attack" else u.target
	if t != null and is_instance_valid(t):
		if t is Unit and u._valid_target(t) and t.edge_distance(u.position) - u.radius <= rng and u.game.target_seen(u.team, t, u.position):
			return t
		if u.order == "attack":
			return null
	if u.order == "attack":
		return null
	var head := u.rb_head if u.rb_head != Vector2.ZERO else u.facing
	var best: Entity = null
	var bd := INF
	for o in u.game.units_near(u.position, rng + u.radius + 24.0):
		if o.dead or o.off_field or o.is_air() or not u.game.hostile(o.team, u.team) or not u.can_hit(o) or o.kind == "horse":
			continue
		if o.edge_distance(u.position) - u.radius > rng or (o.position - u.position).dot(head) <= 0.0:
			continue
		if not u.game.target_seen(u.team, o, u.position):
			continue
		var dd: float = o.position.distance_to(u.position) + (0.0 if Game.fights_back(o) else 40.0)
		if dd < bd or (dd == bd and best != null and o.serial < (best as Unit).serial):
			bd = dd
			best = o
	return best


## How much farther than the pistol's reach he takes aim: what he rides in the aim time.
static func _early(u: Unit) -> float:
	return u.speed * float(Defs.PISTOL["aim"])


static func _wall(e: Entity) -> bool:
	return e is Building and (e.kind == "wall" or e.kind == "gate")


## Where to ride for `e`: the place it will be when he gets there (a man on the run), or a building's middle.
static func _aim_point(u: Unit, e: Entity) -> Vector2:
	if e is Unit:
		var eu := e as Unit
		var lead := clampf(eu.position.distance_to(u.position) / maxf(u.speed, 1.0), 0.0, 0.8)
		return eu.position + eu.velocity * lead
	return e.rect().get_center()


## Half the target's width across the line he comes in on (a building is a box; a man his radius).
static func _half(e: Entity, across: Vector2) -> float:
	if e is Unit:
		return (e as Unit).radius
	var r := e.rect()
	return absf(across.x) * r.size.x * 0.5 + absf(across.y) * r.size.y * 0.5


## The ride for a fight: replaces Unit._engage (which walks up and stands) for a rider on the move. Returns the
## velocity he wants.
static func steer(u: Unit, e: Entity, delta: float) -> Vector2:
	if _wall(e) or u.phase != "" or e == null or not is_instance_valid(e):
		u.rb_state = ""
		return u._engage(e, delta, true)          # (a wall piece is hacked at standing; a blow under way finishes)
	var R: Dictionary = Defs.RIDE_BY
	var tp := _aim_point(u, e)
	var to := tp - u.position
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else (u.rb_head if u.rb_head != Vector2.ZERO else u.facing)
	if u.rb_head == Vector2.ZERO:
		u.rb_head = u.facing if u.facing != Vector2.ZERO else dir
	var across := Vector2(-dir.y, dir.x)
	var side := float(R["side"]) + (0.0 if e is Unit else 6.0)     # (a building's corners: a little more room)
	var lat := _half(e, across) + u.radius + side
	if u.rb_state == "":
		u.rb_state = "in"
	if u.rb_state == "out":
		u.rb_t += delta
		var ahead := u.position + u.rb_head * (u.radius + 26.0)
		var blocked := _blocked(u, ahead)
		if u.rb_t >= float(R["out_max"]) or dist >= lat + float(R["over"]) or blocked or u.stuck_t > 0.4:
			u.rb_state = "in"
			u.rb_t = -1.0                        # (turning back: no new pass begins until he faces it again)
			if blocked:
				u.rb_head = dir                  # (a wall or a cliff edge ahead: he wheels round at once)
		else:
			return _ride(u, u.rb_head, delta, float(R["turn"]))
	# riding in. Far off, or no straight way to it: the pathing brings him in (as before)
	var goal := tp + across * float(u.rb_side) * lat
	if dist <= float(R["near"]) and _blocked(u, goal):
		# no straight line to the side point (the target itself in the way: a building's corner): its own side's corner
		# first, else the other side's
		var found := false
		for k in [1.0, -1.0]:
			var sd: float = float(u.rb_side) * float(k)
			for p: Vector2 in [tp + across * sd * lat, tp + (across * sd - dir * 0.9) * lat]:
				if not _blocked(u, p):
					goal = p
					u.rb_side = int(sd)
					found = true
					break
			if found:
				break
	if dist > float(R["near"]) or _blocked(u, goal):
		var w := u._engage_path(e, delta)
		if w != Vector2.ZERO:
			u.rb_head = w.normalized()
		u.rb_t = 0.0
		return w
	if u.rb_t < 0.0 and to.dot(u.rb_head) > 0.0:
		u.rb_t = 0.0                             # (turned back toward it: the next pass is on)
	# passed it (it's behind him, close by): he rides on
	if u.rb_t >= 0.0 and dist < lat + 30.0 and to.dot(u.rb_head) < 0.0:
		u.rb_state = "out"
		u.rb_t = 0.0
		return _ride(u, u.rb_head, delta, float(R["turn"]))
	var goal_dir := (goal - u.position).normalized()
	# something in his way just ahead (the target's corner, a cliff edge, a wall), or he's stuck: he turns for the
	# side point at once
	if u.stuck_t > 0.4 or _blocked(u, u.position + u.rb_head * (u.radius + 12.0)):
		if dist < lat + float(R["commit"]):
			# (up against the target itself: he wheels away from it to come again)
			u.rb_head = -dir
			u.rb_state = "out"
			u.rb_t = 0.0
		else:
			u.rb_head = goal_dir
		return u.rb_head * u.speed
	# close: he rides straight through the pass (the line no longer swings round the target) if it goes clear of it
	var perp := Vector2(-u.rb_head.y, u.rb_head.x)
	var miss := absf(to.dot(perp))               # (how far beside the target's middle his line goes)
	var clear := _half(e, perp) + u.radius + 2.0
	if u.rb_t >= 0.0 and dist < lat + float(R["commit"]) and miss >= clear and miss <= clear + side + 12.0 and to.dot(u.rb_head) > 0.0:
		return _ride(u, u.rb_head, delta, 0.0)
	return _ride(u, goal_dir, delta, float(R["turn"]))


## Can't ride on to `p`: a cliff edge, water, a wall or a building between.
static func _blocked(u: Unit, p: Vector2) -> bool:
	return not u.game.line_clear(u.position, p, u._path_margin()) or u.game.level_of(p) != u.game.level_of(u.position)


## Turns his heading toward `want_dir` by at most `turn` rad/s and gallops on it.
static func _ride(u: Unit, want_dir: Vector2, delta: float, turn: float) -> Vector2:
	if turn > 0.0 and want_dir != Vector2.ZERO:
		var ang := u.rb_head.angle_to(want_dir)
		if absf(ang) > 1.6:
			# (turning right round after a pass: round the far end, toward the target's side (it was on his rb_side), so the
			# next pass comes back along its other side: a loop round the target, not hairpins off to one side of it)
			ang = absf(ang) * float(-u.rb_side)
		var step := turn * delta
		u.rb_head = u.rb_head.rotated(clampf(ang, -step, step)).normalized()
	return u.rb_head * u.speed


# ------------------------------------------------------------------ the sabre arc (code-drawn: docs/art_style_inconsistency.md)

## A blow struck in passing: the gallop goes on (his attack strip stands the horse still) and a sabre arc sweeps
## across his front, forehand and backhand in turn.
static func slash(u: Unit) -> void:
	var s: Slash = u.get_node_or_null("RideSlash")
	if s == null:
		s = Slash.new()
		s.name = "RideSlash"
		s.z_index = 2
		u.add_child(s)
	s.t = 0.0
	s.back = u.ride_n % 2 == 1
	s.ang = u.facing.angle()
	s.visible = true
	s.set_process(true)
	s.queue_redraw()


class Slash extends Node2D:
	var t := 0.0
	var back := false
	var ang := 0.0

	func _process(delta: float) -> void:
		t += delta
		var u := get_parent() as Unit
		if u and u.facing != Vector2.ZERO:
			ang = u.facing.angle()
		if t >= float(Defs.RIDE_BY["slash"]):
			visible = false
			set_process(false)
			return
		queue_redraw()

	func _draw() -> void:
		var life := float(Defs.RIDE_BY["slash"])
		var f := clampf(t / life, 0.0, 1.0)
		# the blade sweeps 150 degrees across his front at the rider's shoulder height, the trail fading behind it
		var c := Vector2(0, -26)
		var r := 34.0
		var a0 := ang - 1.3
		var a1 := ang + 1.3
		if back:
			var tmp := a0
			a0 = a1
			a1 = tmp
		var tip := lerpf(a0, a1, ease(f, 0.6))
		var tail := lerpf(a0, tip, 0.35)
		var n := 10
		var pts := PackedVector2Array()
		for i in n + 1:
			var a := lerpf(tail, tip, float(i) / n)
			pts.append(c + Vector2(cos(a), sin(a) * 0.55) * r)
		var fade := 1.0 - f * f
		draw_polyline(pts, Color(0.1, 0.08, 0.06, 0.45 * fade), 5.0, true)      # (a dark edge: it reads on bright ground too)
		draw_polyline(pts, Color(1.0, 0.97, 0.88, 0.5 * fade), 3.5, true)
		draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.95 * fade), 1.6, true)
		var e := c + Vector2(cos(tip), sin(tip) * 0.55) * r
		draw_line(e, c + Vector2(cos(tip), sin(tip) * 0.55) * (r - 12.0), Color(0.85, 0.88, 0.95, fade), 2.0, true)
