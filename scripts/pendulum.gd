class_name Pendulum
extends RefCounted
## THE PENDULUM (gear mode's Clockwork tier 3, Defs.UNITS "pendulum"; the swing's numbers in Defs.PENDULUM_SWING): a tall,
## slow, tough clock tower on long legs, the Clockwork's melee AREA DAMAGE. Its pendulum blade winds back (the strip's
## frames 2-4: the telegraph) and swings through the front on the 5th frame: every enemy on the ground in the ARC in front
## of it takes the blow (never its own side: the machine's units keep in step with the swing), and a building it swings
## at takes it too. It cannot reach flyers. It is made only while its Movement Works runs on the BIG gear (the heavy
## torque: gear_problem, Game.can_train); a Works with Pendulums queued cannot go back to the small gear meanwhile.
## Art: tools/import_tier3.py (the sway, the swing and the walk were built in code from ChatGPT's direction sheet:
## tools/pendulum_guide/).


## "" when Movement Works b may make a Pendulum as far as its gear goes: it runs on its BIG gear (or is being fitted with
## it: the order waits through the swap like any other), else why not.
static func gear_problem(b: Building) -> String:
	if not Defs.gear_mode or b == null:
		return ""
	var big: bool = b.gear_swap_to if b.gear_swap_t >= 0.0 else b.gear_big
	if big:
		return ""
	return "A Pendulum needs the heavy torque of the BIG gear: swap this Movement Works to its big gear first."


## "" when Movement Works b may swap its gear now as far as the Pendulums go: going to the SMALL gear with a Pendulum in its
## queue is refused (the Pendulum is made only on the big gear).
static func swap_problem(b: Building) -> String:
	if b == null or not b.gear_big or b.gear_swap_t >= 0.0 or not b.queue.has(Defs.PENDULUM):
		return ""
	return "A Pendulum is being made here: it needs the big gear. Cancel it (or let it finish) before going back to the small gear."


## The way the blade swings (on the ground): toward its target's feet, else the way it faces.
static func swing_dir(u: Unit, e: Entity) -> Vector2:
	if e != null and is_instance_valid(e):
		var gp: Vector2 = e.position if e is Unit else e.rect().get_center()
		if gp.distance_to(u.position) > 2.0:
			return (gp - u.position).normalized()
	return u.facing.normalized() if u.facing.length() > 0.01 else Vector2.DOWN


## Is enemy unit o in the arc of unit u's swing (blade toward `dir`)? Within Defs.PENDULUM_SWING "reach" px of its feet
## (to o's edge) and "arc" degrees either side of the way it swings; one right on its feet is always caught.
static func in_arc(u: Unit, o: Unit, dir: Vector2) -> bool:
	var ps: Dictionary = Defs.PENDULUM_SWING
	var to: Vector2 = o.position - u.position
	var dist := to.length()
	if dist - o.radius > float(ps["reach"]):
		return false
	if dist <= o.radius + 4.0:
		return true
	return dir.dot(to / dist) >= cos(deg_to_rad(float(ps["arc"])))


## Every enemy unit on the ground the swing of unit u toward `dir` catches.
static func victims(u: Unit, dir: Vector2) -> Array:
	var g := u.game
	var out: Array = []
	for o in g.units_near(u.position, float(Defs.PENDULUM_SWING["reach"]) + 40.0):
		if o == u or o.dead or o.off_field or o.is_air() or o.untouchable() or not g.hostile(o.team, u.team):
			continue
		if in_arc(u, o, dir):
			out.append(o)
	return out


## The blow (Unit._strike: dmg with its veterancy, and the building bonus already in when it swings at a building): every
## enemy unit in the arc takes the blow (an area blow: a rider's horse goes down with him); the building takes its bonus.
## Returns how many units it caught.
static func swing(u: Unit, e: Entity, dmg: float) -> int:
	var g := u.game
	var dir := swing_dir(u, e)
	var hit := victims(u, dir)
	var on_units := dmg / float(u.d.get("building_bonus", 1.0)) if e is Building else dmg
	for o in hit:
		o.take_damage(on_units, u, "")
		if o.visible and g.view_rect.has_point(o.position):
			g.spawn_effect("hit", o.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.7)
	if e is Building and is_instance_valid(e) and not e.dead:
		e.take_damage(dmg, u, Entity.BLOW_MELEE)
		g.spawn_effect("hit", e.center() + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.8)
	u.swings += 1
	u.last_hits = hit.size()
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["combat/pendulum_attack", "combat/gearknight_attack", "gear_hit"], u.position)
		# a little dust where the blade's arc scrapes the ground ahead of it
		var fx := g.spawn_effect("dust", u.position + dir * 34.0, 1.8)
		fx.scale = Vector2(0.5, 0.35)
		fx.modulate.a = 0.6
	return hit.size()

