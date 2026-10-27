class_name Netter
extends RefCounted
## THE NETTER (gear mode's Clockwork tier 3, Defs.UNITS "netter"; the net's numbers in Defs.NET): the STOPPER, made of
## machinery (no magic in the setting): a low iron drum on four short legs with a spring cannon on top. Its attack is the
## NET: on the 2nd frame of the recoil a weighted chain net leaves the muzzle (fire) and flies at ONE enemy unit (ChainNet,
## scripts/chain_net.gd, visible in flight, following it); where it lands the unit is CAUGHT (catch): for Defs.NET "time" s
## it cannot move or fight, and a flyer comes down to the ground (Unit.is_air is false meanwhile: anything can hit it,
## flyer hunters cannot). Then the long reload (its UNITS "cooldown"). It nets units only (never buildings), and by itself
## the most dangerous enemy in reach that is not caught already nor about to be (pick); an ATTACK order on a caught one
## nets it again (its time is topped up, never stacked). The computer's Netters pick the same way (AI._micro leaves them to
## it). The caught unit's state lives on the Unit: `net_t` (s left), `nets_in` (nets flying at it).

const NET_AT := {"balloon": -30.0}      # where the spread net sits over a caught unit (px over its feet), else its body


## How much enemy unit o is worth catching: its price (Tension and the second resource count double), more while it fights,
## a flyer more (brought down, the whole army can hit it), a veteran more; workers and unarmed units much less.
static func danger(o: Unit) -> float:
	var d: Dictionary = o.d
	var v := (float(d["cost"]) + 2.0 * float(d.get("cost2", 0)) + 2.0 * float(d.get("tension", 0))) / maxf(1.0, float(d.get("spawn", 1)))
	if o.kind == "balloon":
		v += 70.0 * float(o.passengers.size())       # (the men in its basket come down with it)
	if o.is_worker():
		v *= 0.25
	elif not o.has_attack() and o.kind != "balloon":
		v *= 0.4
	if o.target != null and is_instance_valid(o.target):
		v *= 1.3
	if o.d.get("air", false):
		v += 60.0
	return v * (1.0 + minf(float(o.kills) * 0.05, 1.0))


## Is unit o caught (more than a moment left) or about to be (a net flying at it)?
static func caught(o: Unit) -> bool:
	return o.net_t > 0.3 or o.nets_in > 0


## Unit u's own pick (idle, attack-move: Unit._pick_target): the most dangerous enemy unit within r it can net and may
## shoot at (the rules of Game.find_target: nothing unseen up a cliff, beyond its sight only what its side sees), that is
## not caught already nor about to be; those it reaches without walking count fully, the others less the farther they are.
static func pick(u: Unit, r: float) -> Entity:
	var g := u.game
	var best: Unit = null
	var bs := -INF
	var reach := u._range() + u.radius
	for o in g.units_near(u.position, r):
		if not g.hostile(o.team, u.team) or o.dead or o.off_field or not u.can_hit(o) or caught(o):
			continue
		if not o.is_air() and g.on_high(o.position) and not g.on_high(u.position) and not g.is_visible_to(u.team, o.position):
			continue
		if o.position.distance_to(u.position) > u.sight * Defs.TILE + 8.0 and not g.side_sees(u.team, o.position):
			continue
		var s := danger(o) - 0.6 * maxf(0.0, o.edge_distance(u.position) - reach)
		if s > bs:
			bs = s
			best = o
	return best


## The muzzle of unit u's spring cannon in world px (Defs.NET "mouth" for the way it faces; the west views mirror the east).
static func mouth(u: Unit) -> Vector2:
	var dd: Array = Unit.DIR_FLIP[posmod(int(round(u.facing.angle() / (PI / 4.0))), 8)]
	var o: Vector2 = Defs.NET["mouth"][String(dd[0])]
	if bool(dd[1]):
		o.x = -o.x
	return u.position + o


## The net leaves the muzzle (Unit._strike, on the recoil's 2nd frame): a ChainNet flies at e and catches it where it lands.
static func fire(u: Unit, e: Entity) -> ChainNet:
	if not (e is Unit) or not is_instance_valid(e) or e.dead:
		return null
	var g := u.game
	var cn := ChainNet.new()
	cn.game = g
	cn.from = mouth(u)
	cn.target = e
	cn.shooter = u
	cn.team = u.team
	cn.speed = float(Defs.NET["speed"])
	cn.damage = float(Defs.NET["damage"]) * (1.0 + minf(u.kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])))
	g.add_child(cn)
	(e as Unit).nets_in += 1
	u.nets += 1
	u.last_net = cn
	if g.net != null and not g.puppet:
		g.net.note_net(cn)          # (online host: the guest sees it fly)
	if g.rec != null and not g.puppet:
		g.rec.note_net(cn)
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["combat/netter_attack", "combat/arrow_whoosh", "ratchet"], u.position, -4.0)
		var mz := g.spawn_effect("smoke", cn.from, 1.6)       # (a puff from the spring cannon's mouth)
		mz.scale = Vector2(0.55, 0.55)
		mz.modulate = Color(1.2, 1.2, 1.2, 0.7)
	return cn


## A net lands on unit o (ChainNet): o is CAUGHT for Defs.NET "time" s (topped up if it was caught already, never stacked):
## it stops where it is, cannot move or fight (Unit.stun_t; a blow it was winding up is lost), a flyer comes down to the
## ground; the weights hurt a little (`dmg`).
static func catch(o: Unit, by: Entity, dmg: float) -> void:
	if o == null or not is_instance_valid(o) or o.dead or o.off_field or o.aboard != null:
		return
	var g := o.game
	var t := float(Defs.NET["time"])
	var fresh := o.net_t <= 0.0
	o.net_t = maxf(o.net_t, t)
	o.stun_t = maxf(o.stun_t, t)
	o.phase = ""
	o.velocity = Vector2.ZERO
	o.nets_taken += 1
	o.net_drop = 0.0
	if not is_instance_valid(by):
		by = null
	o.take_damage(dmg, by, Entity.BLOW_RANGED)
	if o.visible and g.view_rect.has_point(o.position):
		Sfx.play_any(["combat/netter_hit", "clash", "gear_hit"], o.position, -3.0)
		var fx := g.spawn_effect("dust", o.position + Vector2(0, -2), 1.6)
		fx.scale = Vector2(0.5, 0.4)
	if fresh and g.mlog and by != null and (by.team == g.human or o.team == g.human):
		g.mlog.add("%s's Netter caught %s's %s" % [g.mlog.who(by.team), g.mlog.who(o.team), String(o.d["name"])])


## Where the spread net sits over caught unit u (local px from its feet): its body, a flyer's on the ground.
static func net_at(u: Unit) -> Vector2:
	if NET_AT.has(u.kind):
		return Vector2(0.0, float(NET_AT[u.kind]))
	if Defs.FLYER.has(u.kind):
		var f: Dictionary = Defs.FLYER[u.kind]
		return Vector2(0.0, -float(f["centre"]) + float(f["lift"]) * u._low)
	var a: Vector2 = ArtData.UNITS[u.art]["anchor"] if ArtData.UNITS.has(u.art) else Vector2(0, 24)
	return Vector2(0.0, -clampf(a.y * 0.45, 8.0, 40.0))


## The spread net over a caught unit (a child sprite over its body, Unit._animate): it drops onto it (a little bigger at
## first), shivers now and then while the unit struggles, and is gone when the time is up.
static func update_net(u: Unit, delta: float) -> void:
	var on := u.net_t > 0.0 and not u.dead
	if not on:
		if u._net_spr:
			u._net_spr.queue_free()
			u._net_spr = null
		return
	if u._net_spr == null:
		u._net_spr = Sprite2D.new()
		u._net_spr.z_index = 1
		u.add_child(u._net_spr)
	var w := u.radius * float(Defs.NET["cover"])
	var big := w > 56.0
	var tex_name := "netter_net_open_big" if big else "netter_net_open"
	var tex: Texture2D = Game.tex("res://assets/effects/%s.png" % tex_name)
	if u._net_spr.texture != tex:
		u._net_spr.texture = tex
	u.net_drop = minf(u.net_drop + delta, 1.0)
	var land := clampf(u.net_drop / float(Defs.NET["drop"]), 0.0, 1.0)
	var sc := w / float(ArtData.EFFECTS[tex_name]["size"].x) * lerpf(1.35, 1.0, land)
	u._net_spr.scale = Vector2(sc, sc)
	u._net_spr.position = net_at(u) + Vector2(0.0, -10.0 * (1.0 - land))
	u._net_spr.rotation = sin(u._bob_t * 7.0) * 0.035      # (it struggles under it)
	u._net_spr.modulate.a = clampf(u.net_t / 0.25, 0.0, 1.0)


# ------------------------------------------------------------------ the unit card

## The Netter's line on the unit card: whether its net is ready.
static func card_line(u: Unit) -> String:
	if u.phase != "":
		return "Firing its net."
	if u.cooldown > 0.0:
		return "NET in %d s (the spring cannon is winding)." % int(ceil(u.cooldown))
	return "NET ready: it fires at the most dangerous enemy in reach that is not caught."
