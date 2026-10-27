class_name Ballista
extends RefCounted
## THE SPRING BALLISTA (gear mode's Clockwork tier 2, Defs.UNITS "ballista"; its numbers in Defs.BALLISTA; the owner's
## unit, 2026-10-27; docs/ballista.md): a crewed bolt thrower on cog wheels.
## - THE BOLT (fire, line_shot): a giant screw in a straight line from the bow; it goes through its target into the enemies
##   behind it (Defs.BALLISTA hits: 100%, 50%, 30%), armour and buildings take more, a building stops it.
## - NO SET-UP: it shoots as soon as it stops; on a MOVE order it shoots on the move at an enemy in range ahead (drive_by).
## - THE RELOAD (wind): its spring is wound only while it stands; faster with more crew (rate).
## - THE CREW: a Winder is built in (drawn by look(): a sprite, not a unit). Up to Defs.BALLISTA "crew" more Winders board it
##   (Unit.cmd_board / take_aboard, as into a Balloon; take_crew here). They stay on the field, as units, in their spots
##   beside it (crew_tick): pushing from behind while it moves, cranking at its side while it reloads, standing by it
##   otherwise. They can be hit and killed. Each one: +10% reload and move speed. UNLOAD (unload) sets them down where they
##   stand; any other order given to a crewman takes him off (leave); when the Ballista dies they step off.
## State on the Unit: `crew` (the ballista's boarded Winders, in boarding order), `crew_of` (a crewman's ballista),
## `loaded` (the ballista's bolt is in: streamed online and in replays, so a guest draws loaded or fired and its crew's
## crank).

const B := Defs.BALLISTA
const KIND := Defs.BALLISTA_KIND
## Where the crew stand, from the machine's feet, by the way it faces (f, a unit vector) and its right (r = f turned a
## quarter clockwise on screen). The machine is long front to back and drawn foreshortened from above: an offset along a
## direction d is d.x * the across-screen size + d.y * the up-screen size ("ellipse": BACK, SIDE, ALONG).
const BACK := Vector2(84.0, 46.0)        # behind the machine (the pushers' line)
const SIDE := Vector2(46.0, 24.0)        # out to its right side (the crank is on its right, at the rear)
const REAR := Vector2(40.0, 22.0)        # ... and that far back along it (the crank sits over the rear axle)
const SPREAD := 15.0                     # px between two crewmen side by side
const STEP_BOB := ["e", "se", "ne"]      # views whose push frames barely step (the owner's sheets): a bob in code


# ------------------------------------------------------------------ crew and pace

## The ballista's boarded crewmen still alive (dead ones are dropped from its list).
static func crew_of(b: Unit) -> Array:
	if b.crew.is_empty():
		return b.crew
	var live: Array = b.crew.filter(func(w) -> bool: return is_instance_valid(w) and not w.dead and w.crew_of == b)
	if live.size() != b.crew.size():
		b.crew = live
	return b.crew


## Its pace: 1 + per_crew for every extra crewman (reload speed and move speed).
static func rate(b: Unit) -> float:
	return 1.0 + float(B["per_crew"]) * float(crew_of(b).size())


## Free places for crew, counting the Winders walking over (Unit.room).
static func room(b: Unit) -> int:
	b.incoming = b.incoming.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.order == "board" and u.order_target == b)
	return int(B["crew"]) - crew_of(b).size() - b.incoming.size()


## The reload, every tick (instead of the plain cooldown countdown): the spring is wound only while the machine stands,
## at its crew's rate. `loaded` follows: the bolt is in once the spring is wound and no shot is under way.
static func wind(b: Unit, delta: float) -> void:
	if b.velocity.length() < float(B["still"]) and b.stun_t <= 0.0:
		b.cooldown = maxf(b.cooldown - delta * rate(b), 0.0)
	var was := b.loaded
	b.loaded = b.cooldown <= 0.0 and b.phase != "strike"
	if b.loaded and not was and b.visible and b.game.view_rect.has_point(b.position):
		Sfx.play_any(["combat/ballista_wound", "ratchet"], b.position, -6.0)


## A Winder climbs onto the ballista (Unit.take_aboard): he stays on the field, in his crew spot from now on.
static func take_crew(b: Unit, w: Unit) -> void:
	b.incoming.erase(w)
	if b.dead or w.dead or w.crew_of != null or w.aboard != null or crew_of(b).size() >= int(B["crew"]):
		return
	w.cmd_stop()
	w.release_horses()
	w.order = "crew"
	w.order_target = b
	w.crew_of = b
	w.target = null
	w.phase = ""
	w.path = PackedVector2Array()
	w.selected = false
	w.game.selection.erase(w)
	b.crew.append(w)
	if b.team == b.game.human:
		Sfx.play_any(["ui/click", "click"], b.position)
		b.game.float_text(b.position + Vector2(0, -60), "crew %d" % (crew_of(b).size() + 1), Color(0.95, 0.8, 0.45))
	if b.game.mlog and not b.game._first_of.has("%d:ballista_crew" % b.team):
		b.game._first_of["%d:ballista_crew" % b.team] = true
		b.game.mlog.add("%s's first Winder crews a Spring Ballista" % b.game.mlog.who(b.team))


## A crewman steps off (UNLOAD, another order, the ballista gone): a Winder again, free, where he stands.
static func leave(w: Unit) -> void:
	var b := w.crew_of
	w.crew_of = null
	if b != null and is_instance_valid(b):
		b.crew.erase(w)
	if w.order == "crew":
		w.order = "idle"
		w.order_target = null
	w.sprite.position = Vector2.ZERO
	w.velocity = Vector2.ZERO
	w.last_pos = w.position


## UNLOAD: every crewman steps off (the built-in one stays: he is part of the machine).
static func unload(b: Unit) -> void:
	for w in crew_of(b).duplicate():
		leave(w)
		w.cmd_stop()
	b.crew.clear()


## The ballista is destroyed: its crew step off where they stand (and fight on as Winders).
static func on_death(b: Unit) -> void:
	for w in b.crew.duplicate():
		if is_instance_valid(w) and not w.dead:
			leave(w)
	b.crew.clear()
	if b.has_meta("own_crew"):
		(b.get_meta("own_crew") as Sprite2D).visible = false


# ------------------------------------------------------------------ where the crew stand

## The facing snapped to the eight drawn ways (the crew line up with the picture).
static func snap_face(b: Unit) -> Vector2:
	var f := b.facing if b.facing != Vector2.ZERO else Vector2.DOWN
	return Vector2.from_angle(round(f.angle() / (PI / 4.0)) * (PI / 4.0))


static func _ell(d: Vector2, e: Vector2) -> Vector2:
	return Vector2(d.x * e.x, d.y * e.y)


## What the crew do now: "push" (it moves), "crank" (it stands and reloads), "stand".
static func crew_job(b: Unit) -> String:
	if b.velocity.length() >= float(B["still"]) * 1.5:
		return "push"
	if not b.loaded:
		return "crank"
	return "stand"


## Spot i of n crewmen (0 = the built-in one, then the boarded ones in order), from the machine's feet, for that job.
## Pushers in a line across its back; crankers (and those standing by) in a file along its right side from the crank
## back; the built-in man first in either.
static func spot(b: Unit, i: int, n: int, job: String) -> Vector2:
	var f := snap_face(b)
	var r := Vector2(-f.y, f.x)
	if job == "push":
		var t := (float(i) - float(n - 1) * 0.5) * SPREAD
		return _ell(-f, BACK) + _ell(r, Vector2(1.0, 0.6)) * t
	return _ell(r, SIDE) + _ell(-f, REAR) + _ell(-f, Vector2(1.0, 0.6)) * (float(i) * SPREAD - SPREAD)


## Which way a crewman faces for the job: pushers the way it goes, crankers toward the machine.
static func spot_face(b: Unit, job: String) -> Vector2:
	var f := snap_face(b)
	if job == "push":
		return f
	return -Vector2(-f.y, f.x)


## A crewman, every tick, instead of his own orders: he stands in his spot by the machine (terrain and buildings still
## block him: he stays on his side of them), turns for the job and animates. Any other order takes him off.
static func crew_tick(w: Unit, delta: float) -> void:
	var b := w.crew_of
	if b == null or not is_instance_valid(b) or b.dead or w.order != "crew" or w.order_target != b:
		leave(w)
		return
	var list := crew_of(b)
	var i := list.find(w) + 1
	var job := crew_job(b)
	var to := b.position + spot(b, i, list.size() + 1, job)
	var before := w.position
	var step := to - before
	var far := step.length()
	var reach := maxf(w.speed, b.speed * 1.6) * delta
	var goal := to if far <= reach or far > 160.0 else before + step / far * reach
	w.position = w.game.resolve_terrain(goal, before, w.radius * 0.5, w.team)
	w.velocity = (w.position - before) / maxf(delta, 0.001)
	w.facing = spot_face(b, job)
	w.target = null
	w.phase = ""
	w.last_pos = w.position


## His animation (Unit._anim_name): the crew strips while the machine is pushed or wound, his idle otherwise.
static func crew_anim(w: Unit) -> String:
	var b := w.crew_of
	if b == null or not is_instance_valid(b):
		return "idle"
	var job := crew_job(b)
	return job if job != "stand" else "idle"


## A small step bob on the push strips that barely step (Unit._animate puts it on his sprite).
static func crew_bob(w: Unit) -> float:
	if w.anim != "push" or not STEP_BOB.has(w.anim_dir):
		return 0.0
	return -1.0 if w.frame_i % 2 == 1 else 0.0


## The built-in crewman: a Winder sprite (his own push / crank strips, the team colours of the ballista's sprite) in spot
## 0, behind or in front of the machine's picture by depth. Unit._animate calls this for the ballista.
static func look(b: Unit, delta: float) -> void:
	var s: Sprite2D
	if b.has_meta("own_crew"):
		s = b.get_meta("own_crew")
	else:
		s = Sprite2D.new()
		s.centered = false
		s.material = b.sprite.material
		b.add_child(s)
		b.set_meta("own_crew", s)
		b.set_meta("own_crew_t", 0.0)
	if b.dead or not b.visible:
		s.visible = false
		return
	s.visible = true
	var n := crew_of(b).size() + 1
	var job := crew_job(b)
	var a := job if job != "stand" else "idle"
	var p := spot(b, 0, n, job)
	var f := spot_face(b, job)
	var o := posmod(int(round(f.angle() / (PI / 4.0))), 8)
	var df: Array = Unit.DIR_FLIP[o]
	var dr: String = df[0]
	var frames: Dictionary = ArtData.UNITS["winder"]["frames"]
	if not frames.has("%s_%s" % [a, dr]):
		a = "idle"
	var key := "%s_%s" % [a, dr]
	var tex := Game.tex("res://assets/units/winder/%s.png" % key)
	var cell: Vector2i = ArtData.UNITS["winder"]["cell"]
	var anchor: Vector2 = ArtData.UNITS["winder"]["anchor"]
	s.texture = tex
	s.hframes = int(frames.get(key, 1))
	s.offset = -anchor - Vector2(0, tex.get_height() - cell.y)
	s.scale = Vector2(-1.0 if bool(df[1]) else 1.0, 1.0)
	var t := float(b.get_meta("own_crew_t")) + delta * (9.0 if a != "idle" else 1.0)
	b.set_meta("own_crew_t", t)
	s.frame = int(t) % s.hframes if a != "idle" else 0
	var bob := -1.0 if a == "push" and STEP_BOB.has(dr) and s.frame % 2 == 1 else 0.0
	s.position = p + Vector2(0, bob)
	# depth: behind the machine's picture when standing farther back (smaller y) than its feet
	var want := b.sprite.get_index() if p.y < -2.0 else b.sprite.get_index() + 1
	if s.get_index() != want:
		b.move_child(s, mini(want, b.get_child_count() - 1))


# ------------------------------------------------------------------ the bolt

## The bow's mouth in world px (Defs.BALLISTA "mouth" for the way it faces; the west views mirror the east).
static func mouth(u: Unit) -> Vector2:
	var dd: Array = Unit.DIR_FLIP[posmod(int(round(u.facing.angle() / (PI / 4.0))), 8)]
	var o: Vector2 = B["mouth"][String(dd[0])]
	if bool(dd[1]):
		o.x = -o.x
	return u.position + o


## Its shot at e (Unit._strike): the bolt through e and the line behind it.
static func fire(u: Unit, e: Entity, dmg: float) -> void:
	var at: Vector2 = e.position if e is Unit else e.center()
	line_shot(u, at, dmg, e)


## BOMBARD / ATTACK GROUND (Game.bombard_shot): the bolt through the spot.
static func fire_at(u: Unit, p: Vector2, dmg: float) -> void:
	line_shot(u, p, dmg, null)


## The bolt: from the mouth through `aim` and on Defs.BALLISTA "line" px past it, hitting the enemies within "width" of the
## line in order (up to "hits": each takes dmg x its share, x vs_armored on an armoured unit, x building_bonus on a
## building, which stops it). `first`: the target it was fired at, hit first even if it stands just off the line (it was
## aimed at). Never its own side, never flyers. Returns the entities hit, in order (tests).
static func line_shot(u: Unit, aim: Vector2, dmg: float, first: Entity) -> Array:
	var g := u.game
	var from := mouth(u)
	var dir := aim - u.position
	if dir.length() < 1.0:
		dir = u.facing
	dir = dir.normalized()
	var to := aim + dir * float(B["line"])
	var w := float(B["width"])
	var found: Array = []          # [distance along, entity]
	var mid := (u.position + to) * 0.5
	for o in g.units_near(mid, u.position.distance_to(to) * 0.5 + 40.0):
		if o.dead or o.off_field or o.is_air() or o.untouchable() or not g.hostile(o.team, u.team) or o == first:
			continue
		var q := Geometry2D.get_closest_point_to_segment(o.position, u.position, to)
		if q.distance_to(o.position) <= o.radius + w and (q - u.position).dot(dir) > 0.0:
			found.append([(q - u.position).dot(dir), o])
	for bd in g.buildings:
		if bd.dead or not g.hostile(bd.team, u.team) or bd == first:
			continue
		var c: Vector2 = bd.center()
		var q := Geometry2D.get_closest_point_to_segment(c, u.position, to)
		if bd.edge_distance(q) <= w:
			found.append([(q - u.position).dot(dir) - bd.rect().size.length() * 0.25, bd])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var order: Array = []
	if first != null and is_instance_valid(first) and not first.dead:
		order.append(first)
	for f in found:
		order.append(f[1])
	var shares: Array = B["hits"]
	var hit: Array = []
	var end := to
	for e in order:
		if hit.size() >= shares.size():
			break
		var k := float(shares[hit.size()])
		var amount := dmg * k
		if e is Building:
			amount *= float(u.d.get("building_bonus", 1.0))
		elif (e as Unit).has_tag("armored"):
			amount *= float(B["vs_armored"])
		e.take_damage(amount, u, Entity.BLOW_RANGED)
		hit.append(e)
		var hp_at: Vector2 = Geometry2D.get_closest_point_to_segment(e.center() if e is Building else (e as Unit).center(), from, to)
		if g.view_rect.has_point(hp_at):
			var fx := g.spawn_effect("screw_impact" if ArtData.EFFECTS.has("screw_impact") else "hit", hp_at, 1.2)
			fx.scale = Vector2(0.9, 0.9) * (1.0 if hit.size() == 1 else 0.7)
			fx.z_index = 6
		if e is Building:
			end = hp_at          # (it sticks in the building)
			break
	u.bolts += 1
	u.bolt_hits = hit
	# the picture: the bolt flies the whole line (or into the building), sparks where it struck
	var s := Shot.new()
	s.impact = "screw_impact" if ArtData.EFFECTS.has("screw_impact") else "hit"
	s.impact_scale = 0.8
	s.launch(g, "ballista_bolt", from, end, float(B["speed"]))
	u.loaded = false
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["combat/ballista_attack", "combat/bolt_attack", "bolt"], u.position)
	return hit


# ------------------------------------------------------------------ picking and the move

## Unit u's own pick (Unit._pick_target): what game.find_target gives, unless an enemy in reach is worth more to it: an
## ARMOURED unit, and then the most enemies on the line behind (a column, a gun line). Buildings: find_target's.
static func pick(u: Unit, r: float) -> Entity:
	var g := u.game
	var base := g.find_target(u, r)
	var best: Entity = base
	var bs := _worth(u, base) if base != null else -INF
	var reach := u._range() + u.radius
	var min_r := float(u.d.get("min_range", 0.0))
	for o in g.units_near(u.position, reach + 20.0):
		if o.dead or o.off_field or o.is_air() or not g.hostile(o.team, u.team) or not u.can_hit(o):
			continue
		var dd: float = o.edge_distance(u.position) - u.radius
		if dd > u._range() or dd < min_r or not g.target_seen(u.team, o, u.position):
			continue
		var s := _worth(u, o)
		if s > bs:
			bs = s
			best = o
	return best


static func _worth(u: Unit, e: Entity) -> float:
	if e is Building:
		var gate := e.kind == "gate" or e.kind == "wall"
		return 2.2 if gate else 1.6
	var o := e as Unit
	var v := (2.0 if o.has_tag("armored") else 1.0) + (0.3 if o.has_attack() else 0.0)
	if o.is_worker():
		v *= 0.6
	# the line behind it
	var dir := (o.position - u.position).normalized()
	for x in u.game.units_near(o.position + dir * float(B["line"]) * 0.5, float(B["line"]) * 0.5 + 20.0):
		if x == o or x.dead or x.off_field or x.is_air() or not u.game.hostile(x.team, u.team):
			continue
		var q := Geometry2D.get_closest_point_to_segment(x.position, o.position, o.position + dir * float(B["line"]))
		if q.distance_to(x.position) <= x.radius + float(B["width"]):
			v += 0.5 if x.has_tag("armored") else 0.3
	return v


## On a MOVE order (Unit._tick_unit): loaded, it shoots without stopping at an enemy in range ahead of it (within
## Defs.BALLISTA "move_cone" of the way it faces; the best by _worth). HOLD FIRE does not exist for it.
static func drive_by(u: Unit) -> void:
	if not u.loaded or u.phase != "" or u.stun_t > 0.0 or u.velocity.length() < float(B["still"]):
		return
	u._db_t -= u.get_physics_process_delta_time()
	if u._db_t > 0.0:
		return
	u._db_t = 0.25
	var g := u.game
	var best: Unit = null
	var bs := -INF
	var f := u.facing.normalized()
	for o in g.units_near(u.position, u._range() + u.radius + 20.0):
		if o.dead or o.off_field or o.is_air() or not g.hostile(o.team, u.team) or not u.can_hit(o):
			continue
		var to: Vector2 = o.position - u.position
		var dd: float = o.edge_distance(u.position) - u.radius
		if dd > u._range() or dd < float(u.d.get("min_range", 0.0)) or f.dot(to.normalized()) < float(B["move_cone"]):
			continue
		if not g.target_seen(u.team, o, u.position):
			continue
		var s := _worth(u, o)
		if s > bs:
			bs = s
			best = o
	if best == null:
		return
	var dmg := u._blow_damage()
	g.note_shot(u, best)
	fire(u, best, dmg)
	u.cooldown = u._cooldown()


## Its line on the unit card.
static func card_line(u: Unit) -> String:
	var n := crew_of(u).size()
	var crew := "Crew %d of %d (+%d%% reload and speed)" % [n + 1, int(B["crew"]) + 1, int(round(float(B["per_crew"]) * 100.0 * n))]
	if u.loaded:
		return "Loaded. " + crew
	if u.velocity.length() >= float(B["still"]):
		return "Winding stops while it moves (%d s left). %s" % [int(ceil(u.cooldown / rate(u))), crew]
	return "Winding the spring: %d s. %s" % [int(ceil(u.cooldown / rate(u))), crew]


# ------------------------------------------------------------------ the computer

## The computer's escort Winders (AI._follow_with_escort) crew its Ballistas: each Ballista with the army gets up to
## `want` crewmen from the escort, the nearest first. Returns the Winders sent (they leave the escort).
static func ai_crew(ballistas: Array, escort: Array, want: int) -> Array:
	var sent: Array = []
	for b in ballistas:
		if b.dead or b.off_field:
			continue
		var need: int = mini(want, int(B["crew"])) - crew_of(b).size() - b.incoming.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead and x.order == "board").size()
		while need > 0:
			var pick: Unit = null
			var pd := INF
			for w in escort:
				if sent.has(w) or not is_instance_valid(w) or w.dead or w.crew_of != null or w.order == "board" or not w.can_board(b):
					continue
				var dd: float = w.position.distance_to(b.position)
				if dd < pd:
					pd = dd
					pick = w
			if pick == null or pd > 900.0:
				break
			pick.cmd_board(b)
			sent.append(pick)
			need -= 1
	return sent
