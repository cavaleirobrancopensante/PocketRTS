class_name CwAir
extends RefCounted
## THE CLOCKWORK'S AIR (gear mode; numbers in Defs.FLYER, Defs.OWL_MORPH, Defs.OWL_BOMB; docs/clockwork_gear_prototype.md).
## The SWIFT (kind "cuckoo", made at the CLOCK AVIARY, kind "cuckoo_house") hunts flyers with a pecking lunge; once TICKING
## OWL is researched at an Aviary each Swift can be MORPHED into a TICKING OWL on its own (it hovers in place meanwhile,
## a progress bar over it and a clock hand sweeping its shadow; CANCEL MORPH pays it back). The Owl swoops on units with its
## talons and lets its pendulum weight fall on buildings as a BOMB (OwlBomb, scripts/owl_bomb.gd).
## Art: tools/import_cuckoo.py aligns every painted frame on the body; the motion is drawn here (sprite_offset): the hover
## over the shadow, the Swift's lunge, the Owl's dive and bob, the fall of a dead flyer to the ground.


# ------------------------------------------------------------------ the morph

## "" when unit u can start turning into a Ticking Owl now, else why not.
static func morph_problem(u: Unit) -> String:
	if u == null or u.dead or u.kind != Defs.CUCKOO:
		return "Only a Swift can be rebuilt into a Ticking Owl."
	if u.owl_t >= 0.0:
		return "It is already turning into a Ticking Owl."
	if u.net_t > 0.0:
		return "It is caught in a net."
	var g := u.game
	if not g.has_tech(u.team, "owl_morph"):
		return "Research TICKING OWL at a Clock Aviary first."
	var m: Dictionary = Defs.OWL_MORPH
	if int(g.players[u.team]["gold"]) < int(m["cost"]):
		return "Not enough cogs."
	var tw := g.tension_problem(u.team, int(m["tension"]))
	if tw != "":
		return tw
	var more := int(Defs.UNITS[Defs.OWL]["supply"]) - int(Defs.UNITS[Defs.CUCKOO]["supply"])
	if g.supply_used(u.team) + more > int(g.players[u.team]["cap"]):
		if int(g.players[u.team]["cap"]) >= g.max_supply(u.team):
			return "Supply is maxed out."
		return "Need more supply: build a %s." % Defs.BUILDINGS[Defs.supply_kind(g.faction_of(u.team))]["name"]
	return ""


## The selected Swifts start turning into Owls (each that can, paying for itself). "" when at least one starts, else why
## none did.
static func morph_order(game: Game, list: Array) -> String:
	var why := ""
	var n := 0
	for u in list:
		if not (u is Unit) or not is_instance_valid(u) or u.dead or u.kind != Defs.CUCKOO:
			continue
		var w := morph_problem(u)
		if w != "":
			if why == "":
				why = w
			continue
		start_morph(u)
		n += 1
	if n == 0 and why == "":
		why = "Only a Swift can be rebuilt into a Ticking Owl."
	return "" if n > 0 else why


## Pay and begin: it stops where it is and hovers; nothing it was doing goes on.
static func start_morph(u: Unit) -> void:
	var g := u.game
	var m: Dictionary = Defs.OWL_MORPH
	g.players[u.team]["gold"] -= int(m["cost"])
	g.add_tension(u.team, -float(m["tension"]))
	g.stats[u.team]["spent"] += int(m["cost"])
	u.cmd_stop()
	u.queue.clear()
	u.target = null
	u.phase = ""
	u.velocity = Vector2.ZERO
	u.owl_t = 0.0
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["combat/owl_morph", "ratchet"], u.position, -6.0)


## Stop turning into an Owl: everything paid comes back.
static func cancel_morph(u: Unit) -> void:
	if u.owl_t < 0.0 or u.dead:
		return
	var g := u.game
	var m: Dictionary = Defs.OWL_MORPH
	g.players[u.team]["gold"] += int(m["cost"])
	g.add_tension(u.team, float(m["tension"]))
	g.stats[u.team]["spent"] -= int(m["cost"])
	u.owl_t = -1.0


## The selected Swifts that are turning into Owls stop (paid back). Returns how many.
static func cancel_order(list: Array) -> int:
	var n := 0
	for u in list:
		if u is Unit and is_instance_valid(u) and not u.dead and u.owl_t >= 0.0:
			cancel_morph(u)
			n += 1
	return n


## Every tick of the morph (instead of moving and fighting: Unit._tick_unit): it hovers in place; when the time is up the
## Swift becomes the Owl (its health share kept).
static func morph_tick(u: Unit, delta: float) -> void:
	u.velocity = Vector2.ZERO
	u.phase = ""
	u.owl_t += delta
	if u.owl_t < float(Defs.OWL_MORPH["time"]):
		return
	u.owl_t = -1.0
	var g := u.game
	u.morph(Defs.OWL)
	u.cmd_stop()
	if u.visible and g.view_rect.has_point(u.position):
		var fx := g.spawn_effect("smoke", u.position + Vector2(0, -float(Defs.FLYER[Defs.OWL]["centre"])), 0.9)
		fx.scale = Vector2(1.3, 1.3)
		Sfx.play_any(["combat/owl_ready", "ratchet"], u.position, -4.0)
	if g.mlog:
		g.mlog.add("%s's Swift became a Ticking Owl" % g.mlog.who(u.team))
	if u.team == g.human:
		g.notify("A Ticking Owl is ready.")


## How far through its morph unit u is (0..1; 0 when not morphing).
static func morph_frac(u: Unit) -> float:
	return clampf(u.owl_t / float(Defs.OWL_MORPH["time"]), 0.0, 1.0) if u.owl_t >= 0.0 else 0.0


# ------------------------------------------------------------------ the motion over the painted frames

## Piecewise linear through one value per frame, at `at` frames into the strip (held after the last).
static func curve(vals: Array, at: float) -> float:
	if vals.is_empty():
		return 0.0
	var i := clampi(int(floor(at)), 0, vals.size() - 1)
	if i >= vals.size() - 1:
		return float(vals[vals.size() - 1])
	return lerpf(float(vals[i]), float(vals[i + 1]), clampf(at - float(i), 0.0, 1.0))


## The sprite's offset from the unit's ground point now: the hover over its shadow (with a slow bob), and the Swift's
## lunge toward its target, the Owl's dive (down and toward its prey) or its bob after a bomb; dead, the fall to the
## ground (the wreck frames lie on it).
static func sprite_offset(u: Unit) -> Vector2:
	var f: Dictionary = Defs.FLYER[u.kind]
	var lift := float(f["lift"]) * (1.0 - u._low)       # (caught in a Netter's net: down on the ground, scripts/netter.gd)
	var at := float(u.frame_i) + clampf(u.anim_t, 0.0, 1.0)
	if u.dead:
		return Vector2(0.0, -lift * curve(f["fall"], at))
	var p := Vector2(0.0, -lift + sin(u._bob_t * 4.0) * 2.5 * (1.0 - u._low))
	if u.owl_t >= 0.0:
		p.y += sin(u._bob_t * 9.0) * 1.0          # (a shiver while it is rebuilt)
	if u.anim == "attack" and f.has("lunge"):
		p += reach(u) * curve(f["lunge"], at)      # (the Swift darts at its prey and back)
	elif u.anim == "attack" and f.has("dive"):
		p += reach(u) * curve(f["dive"], at)       # (the Owl swoops down onto it and climbs back)
	elif u.anim == "bomb" and f.has("bob"):
		p.y += curve(f["bob"], at)
	return p


## The Swift's pitch on its peck now (Defs.FLYER "tilt" by the frame of the attack strip, "tilt_view" for the drawn view; a
## west view mirrors the east one): nose up as it winds back, nose down into the blow. Unit._animate turns the sprite
## about its body by it. 0 when it is not pecking.
static func sprite_tilt(u: Unit) -> float:
	var f: Dictionary = Defs.FLYER[u.kind]
	if u.dead or u.anim != "attack" or not f.has("tilt"):
		return 0.0
	var tv: Dictionary = f["tilt_view"]
	var k := float(u.view_entry(tv, 0.0))
	if k == 0.0:
		return 0.0
	return curve(f["tilt"], float(u.frame_i) + clampf(u.anim_t, 0.0, 1.0)) * k * (-1.0 if u.anim_flip or u.view_mirror(tv) else 1.0)


## The full lunge or swoop now: from the bird's beak or talons (Defs.FLYER "strike_y" px over its hovering anchor) to its
## prey's body (Entity.center), less "contact" px, at most "reach" px. Kept while the prey is gone (the strike goes on).
static func reach(u: Unit) -> Vector2:
	var f: Dictionary = Defs.FLYER[u.kind]
	var e := u.target
	if e != null and is_instance_valid(e) and not e.dead:
		var from := u.position - Vector2(0.0, float(f["lift"]) + float(f["strike_y"]))
		var v := e.center() - from
		var n := v.length()
		u._reach = v / n * clampf(n - float(f["contact"]), 0.0, float(f["reach"])) if n > 0.5 else Vector2.ZERO
	return u._reach


## A dead flyer still falling (not yet on the ground)?
static func falling(u: Unit) -> bool:
	if not u.dead or not Defs.FLYER.has(u.kind) or u._low >= 0.99:
		return false          # (one a net had brought down was on the ground already)
	return curve(Defs.FLYER[u.kind]["fall"], float(u.frame_i) + clampf(u.anim_t, 0.0, 1.0)) > 0.0


# ------------------------------------------------------------------ the Owl's bomb

## Where the Owl's weight hangs now (world px, in the air): its anchor lifted with the sprite, plus Defs.OWL_BOMB "drop"
## for the way it faces (W/SW/NW mirror E/SE/NE).
static func drop_point(u: Unit) -> Vector2:
	var dd: Array = Unit.DIR_FLIP[posmod(int(round(u.facing.angle() / (PI / 4.0))), 8)]
	var o: Vector2 = Defs.OWL_BOMB["drop"][String(dd[0])]
	if bool(dd[1]):
		o.x = -o.x
	var sp := u.sprite.position if u.sprite else Vector2(0.0, -float(Defs.FLYER[u.kind]["lift"]))
	return u.position + sp + o


## Where a bomb let go by unit u over building b lands: the point of b's footprint nearest u's ground point, `inside` px in.
static func impact_point(u: Unit, b: Building) -> Vector2:
	var r := b.rect()
	var near := u.position.clamp(r.position, r.end)
	var inward := (r.get_center() - near)
	if inward.length() > 0.5:
		near += inward.normalized() * minf(float(Defs.OWL_BOMB["inside"]), inward.length())
	return near


## The weight is let go: a real bomb falls from where it hung onto the building and bursts there (the damage is the
## bomb's, when it lands: Game.owl_bomb_land).
static func drop_bomb(u: Unit, b: Building) -> OwlBomb:
	var g := u.game
	var ob: Dictionary = Defs.OWL_BOMB
	var bomb := OwlBomb.new()
	bomb.game = g
	bomb.from = drop_point(u)
	bomb.to = impact_point(u, b)
	bomb.ground_from = Vector2(bomb.from.x, u.position.y)
	bomb.duration = float(ob["fall"]) + float(ob["fall_per"]) * bomb.ground_from.distance_to(bomb.to)
	bomb.damage = float(ob["damage"]) * (1.0 + minf(u.kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])))
	bomb.team = u.team
	bomb.shooter = u
	g.add_child(bomb)
	g.area_mark("ring", u.team, bomb.to, Vector2.ZERO, float(ob["radius"]), 0.0, "brass", bomb.duration, true)     # (where it will land)
	u.bombs += 1
	u.last_bomb = bomb
	if g.net != null and not g.puppet:
		g.net.note_bomb(bomb)          # (online host: the guest sees it fall and burst)
	if g.rec != null and not g.puppet:
		g.rec.note_bomb(bomb)
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["combat/owl_drop", "ratchet"], u.position, -6.0)
	return bomb


# ------------------------------------------------------------------ drawing (Unit._draw_unit)

## A Swift turning into an Owl: a clock hand sweeping round its shadow (the share done, from twelve o'clock) and a bar over
## it.
static func draw_morph(u: Unit, top: float, bw: float) -> void:
	var fr := morph_frac(u)
	var col := Color(0.95, 0.78, 0.35, 0.9)
	u.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Game.FIELD_Y))
	var r := u.radius + 8.0
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.1, 0.08, 0.05, 0.45), 3.0)
	if fr > 0.0:
		u.draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * fr, 32, col, 2.5)
	var hand := Vector2.from_angle(-PI * 0.5 + TAU * fr) * r
	u.draw_line(Vector2.ZERO, hand, col, 1.5)
	u.draw_set_transform(Vector2.ZERO)
	var y := top - 7.0
	u.draw_rect(Rect2(-bw * 0.5, y, bw, 3).grow(0.5), Color(0, 0, 0, 0.7))
	u.draw_rect(Rect2(-bw * 0.5, y, bw * fr, 3), col)


## A dead flyer's shadow while it falls (fading as it comes down onto it).
static func draw_fall_shadow(u: Unit) -> void:
	var f := curve(Defs.FLYER[u.kind]["fall"], float(u.frame_i) + clampf(u.anim_t, 0.0, 1.0))
	if f <= 0.0:
		return
	u.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	u.draw_circle(Vector2.ZERO, u.radius + 2.0, Color(0, 0, 0, 0.25 * f))
	u.draw_set_transform(Vector2.ZERO)
