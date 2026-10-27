class_name GreatWinder
extends RefCounted
## THE GREAT WINDER (gear mode's Clockwork tier 2, Defs.UNITS "great_winder"; its numbers in Defs.GREAT_WINDER; the owner's
## unit, 2026-10-26/27; docs/great_winder.md): the Clockwork's big, slow, walking winding machine. No weapon. It does in the
## field, as one machine, what the escort of ordinary Winders does (AI._follow_with_escort):
## - WINDING (wind_area, every WIND_EVERY s): every Clockwork construct of its side within Defs.GREAT_WINDER "area" px is
##   wound up a little; its ring is drawn on the ground while it is selected (draw_area).
## - MENDING (order "mend", work "mending": its WIND strip, the key arm out and turning): one hurt Clockwork unit at a time,
##   faster than a Winder, paid in cogs like a repair. Autocast MEND = the unit's auto_repair (on from the start).
## - SWEEPING (order "sweep", work "sweeping": its SWEEP strip, the rollers turning): the wrecks of its own side's Clockwork
##   units, into PARTS (Unit.parts, up to the cap). Autocast SWEEP = Unit.auto_sweep (on from the start). Crown and Brood
##   bodies are never swept (owner, 2026-10-27).
## State on the Unit: `parts` (saved, streamed online and in replays), `auto_sweep` (the same), `auto_repair` (MEND), and
## while sweeping the meta "gw_sweep" (seconds at the wreck so far). Nothing here uses the clock or random numbers.

const G := Defs.GREAT_WINDER
const KIND := Defs.GREAT_WINDER_KIND
const WIND_EVERY := 0.5          # s between two winding passes over the area (the amount is per second: the same in all)
const RESCAN := 0.6              # s between two looks round for something to mend or sweep, standing about


## The walk strip's rate at full speed: the art carries it Defs.GREAT_WINDER "stride" px a loop of "frames" frames, so
## at its speed the feet stay planted (Unit.walk_fps_for).
static func walk_fps() -> float:
	return float(Defs.UNITS[KIND]["speed"]) * float(G["frames"]) / float(G["stride"])


# ------------------------------------------------------------------ every tick

## Its own tick (Unit._tick_unit, after the speed is set): it keeps its own spring wound (it is the winding machine: it
## never runs down), and the winding area.
static func tick(u: Unit, delta: float) -> void:
	u.wind = 1.0
	var t := float(u.get_meta("gw_wind_t", 0.0)) + delta
	if t >= WIND_EVERY:
		wind_area(u, t)
		t = 0.0
	u.set_meta("gw_wind_t", t)
	_sounds(u, delta)


## Its working sounds (heard only where the camera is): a heavy ratchet step once a walk loop, the winding crank while it
## mends, the brush sweep while it sweeps (tools/audio/make_clockwork_sounds.py).
static func _sounds(u: Unit, delta: float) -> void:
	var st := float(u.get_meta("gw_snd_t", 0.0)) - delta
	if st <= 0.0:
		st = 0.3
		if u.visible and u.game.view_rect.has_point(u.position):
			if u.work == "mending":
				st = 1.6
				Sfx.play_any(["combat/great_winder_wind", "work/winder_crank"], u.position, -6.0)
			elif u.work == "sweeping":
				st = 1.0
				Sfx.play_any(["combat/great_winder_sweep", "work/winder_crank"], u.position, -6.0)
			elif u.velocity.length() > 10.0:
				st = float(G["stride"]) / maxf(u.speed, 1.0)
				Sfx.play_any(["combat/great_winder_step", "ratchet"], u.position, -9.0)
	u.set_meta("gw_snd_t", st)


## Is `o` one of the units its area winds: a Clockwork construct of its side or an ally's (not a Winder: they wind
## themselves), alive and on the field.
static func windable(u: Unit, o: Unit) -> bool:
	return o != u and not o.dead and not o.off_field and o.aboard == null and not o.is_worker() \
			and String(o.d.get("faction", "")) == "clockwork" and u.game.allied(o.team, u.team)


## Every windable unit within the area: `dt` seconds of winding. Returns how many it wound (tests).
static func wind_area(u: Unit, dt: float) -> int:
	var r := float(G["area"])
	var n := 0
	for o in u.game.units_near(u.position, r):
		if o is Unit and windable(u, o) and o.position.distance_to(u.position) <= r:
			if o.wind < 1.0:
				o.wind = minf(1.0, o.wind + float(G["wind"]) * dt)
				n += 1
	return n


## Its idle look round (Unit._tick_unit, order "idle"): MEND first (the most hurt unit in reach of its look), then SWEEP
## (the nearest wreck). True when it took a job.
static func idle_scan(u: Unit) -> bool:
	if u.auto_repair:
		var p := mend_pick(u, float(G["look"]))
		if p != null and u.game.players[u.team]["gold"] >= 1:
			cmd_mend(u, p)
			return true
	if u.auto_sweep and u.parts < int(G["cap"]):
		var w := sweep_pick(u, float(G["sweep_look"]))
		if w != null:
			cmd_sweep(u, w)
			return true
	return false


# ------------------------------------------------------------------ mending

## Can it mend `e`: a Clockwork unit of its side (or an ally's), hurt or run low, not itself.
static func can_mend(u: Unit, e) -> bool:
	if e == null or not is_instance_valid(e) or not (e is Unit) or e == u:
		return false
	var o := e as Unit
	return not o.dead and not o.off_field and o.aboard == null and String(o.d.get("faction", "")) == "clockwork" \
			and u.game.allied(o.team, u.team) and (o.hp < o.max_hp or (not o.is_worker() and o.wind < 0.98))


## The most hurt mendable unit within r (by its share of health; a run-down statue counts as half hurt), the nearest
## of two as hurt.
static func mend_pick(u: Unit, r: float) -> Unit:
	var best: Unit = null
	var bs := INF
	for o in u.game.units_near(u.position, r):
		if not (o is Unit) or not can_mend(u, o) or o.position.distance_to(u.position) > r:
			continue
		if (o as Unit).hp >= (o as Unit).max_hp - 0.5:
			continue          # (only run low: its area winds it; the arm is for the hurt)
		var s: float = (o as Unit).hp / maxf((o as Unit).max_hp, 1.0) + o.position.distance_to(u.position) * 0.0005
		if (o as Unit).powered_down():
			s -= 0.5
		if s < bs:
			bs = s
			best = o
	return best


## MEND that unit (an order: the autocast's or a right-click's).
static func cmd_mend(u: Unit, e: Unit) -> void:
	u._reset_work()
	u.order = "mend"
	u.order_target = e
	u.target = null
	u.work = ""


## Order "mend", every tick: walks up to it, then mends it with the key arm (work "mending"). Returns the way to go.
static func mend_tick(u: Unit, delta: float) -> Vector2:
	var e = u.order_target
	if not can_mend(u, e):
		u.work = ""
		if u._next_order():
			return Vector2.ZERO
		if u.auto_repair and is_instance_valid(e) and e is Unit:
			var nxt := mend_pick(u, float(G["look"]))
			if nxt != null:
				cmd_mend(u, nxt)
				return Vector2.ZERO
		u.cmd_stop()
		return Vector2.ZERO
	var o := e as Unit
	if o.edge_distance(u.position) < u.radius + float(G["reach"]):
		u.work = "mending"
		u.path = PackedVector2Array()
		if o.position.distance_to(u.position) > 1.0:
			u.facing = (o.position - u.position).normalized()
		mend(u, o, delta)
		return Vector2.ZERO
	u.work = ""
	return u._walk_to(o.position, delta)


## `delta` s of mending on o: health at its rate (paid in cogs, as a Winder's repair), and wind.
static func mend(u: Unit, o: Unit, delta: float) -> float:
	var game: Game = u.game
	if o.hp < o.max_hp:
		var bt: float = maxf(1.0, float(o.d.get("time", 30.0)))
		var rate := float(G["mend"]) * maxf(Defs.REPAIR_RATE, o.max_hp / bt)
		var heal := minf(rate * delta, o.max_hp - o.hp)
		var cost := heal * float(o.d.get("cost", 0)) / maxf(1.0, float(o.d.get("spawn", 1))) * Defs.REPAIR_COST / maxf(o.max_hp, 1.0)
		if game.players[u.team]["gold"] < 1:
			game.tell(u.team, "Not enough cogs to mend.")
			u.work = ""
			u.cmd_stop()
			return 0.0
		game.players[u.team]["gold_f"] = float(game.players[u.team].get("gold_f", 0.0)) - cost
		game.stats[u.team]["repair"] = float(game.stats[u.team].get("repair", 0.0)) + cost
		while float(game.players[u.team]["gold_f"]) <= -1.0:
			game.players[u.team]["gold_f"] = float(game.players[u.team]["gold_f"]) + 1.0
			game.players[u.team]["gold"] -= 1
		o.hp = minf(o.max_hp, o.hp + heal)
		u.set_meta("gw_mended", float(u.get_meta("gw_mended", 0.0)) + heal)
	if not o.is_worker():
		o.wind = minf(1.0, o.wind + float(G["mend_wind"]) * delta)
	return o.hp


# ------------------------------------------------------------------ sweeping

## Is `b` a wreck it may sweep: the body of a Clockwork unit of its side (or an ally's), lying at rest, not torn up, not
## already being swept by another Great Winder. Never a Crown or Brood body (owner, 2026-10-27).
static func sweepable(u: Unit, b) -> bool:
	if b == null or not is_instance_valid(b) or not (b is Unit):
		return false
	var w := b as Unit
	if not w.dead or w.torn or not u.game.bodies.has(w):
		return false
	if String(w.d.get("faction", "")) != "clockwork" or not u.game.allied(w.team, u.team) or w.kind == "horse":
		return false
	if not w.has_meta("gw_by"):
		return true
	var by = w.get_meta("gw_by")
	return by == null or by == u or not is_instance_valid(by) or (by as Unit).dead or (by as Unit).order != "sweep" \
			or (by as Unit).order_target != w


## The nearest sweepable wreck within r.
static func sweep_pick(u: Unit, r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for b in u.game.bodies:
		if not is_instance_valid(b):
			continue
		var dd: float = (b as Unit).position.distance_to(u.position)
		if dd <= bd and sweepable(u, b):
			bd = dd
			best = b
	return best


## SWEEP that wreck (the autocast's order).
static func cmd_sweep(u: Unit, b: Unit) -> void:
	u._reset_work()
	u.order = "sweep"
	u.order_target = b
	u.target = null
	u.work = ""
	u.set_meta("gw_sweep", 0.0)
	b.set_meta("gw_by", u)


## How many parts a wreck gives: its price (one of a spawn) / per_part, by how much of it is left (rot and damage), at
## least 1.
static func parts_of(b: Unit) -> int:
	var cost := float(b.d.get("cost", 0)) / maxf(1.0, float(b.d.get("spawn", 1)))
	var left := clampf(b.body_left() / maxf(b.body_size(), 1.0), 0.0, 1.0)
	return maxi(1, int(round(cost / float(G["per_part"]) * left)))


## Order "sweep", every tick: walks up to the wreck, rollers first, then sweeps it (work "sweeping") for sweep_time s.
static func sweep_tick(u: Unit, delta: float) -> Vector2:
	var b = u.order_target
	if not sweepable(u, b) or u.parts >= int(G["cap"]):
		u.work = ""
		if u.parts >= int(G["cap"]) and u.team == u.game.human and not u.has_meta("gw_full_told"):
			u.set_meta("gw_full_told", true)
			u.game.tell(u.team, "Your Great Winder's hopper is full of parts.")
		if u._next_order():
			return Vector2.ZERO
		if u.auto_sweep and u.parts < int(G["cap"]):
			var nxt := sweep_pick(u, float(G["sweep_look"]))
			if nxt != null:
				cmd_sweep(u, nxt)
				return Vector2.ZERO
		u.cmd_stop()
		return Vector2.ZERO
	var w := b as Unit
	if w.position.distance_to(u.position) < u.radius + float(G["sweep_reach"]):
		u.work = "sweeping"
		u.path = PackedVector2Array()
		if w.position.distance_to(u.position) > 1.0:
			u.facing = (w.position - u.position).normalized()
		var t := float(u.get_meta("gw_sweep", 0.0)) + delta
		u.set_meta("gw_sweep", t)
		if t >= float(G["sweep_time"]):
			take(u, w)
			u.set_meta("gw_sweep", 0.0)
		return Vector2.ZERO
	u.work = ""
	return u._walk_to(w.position, delta)


## The wreck goes into the hopper: its parts are kept (up to the cap) and it is gone from the field (online and in
## replays too: Game.sweep_body).
static func take(u: Unit, w: Unit) -> int:
	var n := mini(parts_of(w), int(G["cap"]) - u.parts)
	u.parts += n
	u.set_meta("gw_swept", int(u.get_meta("gw_swept", 0)) + 1)
	u.game.sweep_body(w)
	if u.visible and u.game.view_rect.has_point(u.position):
		Sfx.play_any(["combat/great_winder_sweep", "work/winder_crank"], u.position, -4.0)
		if u.team == u.game.human:
			u.game.float_text(u.position + Vector2(0, -56), "+%d parts" % n, Color(0.95, 0.8, 0.45))
	if u.game.mlog and not u.game._first_of.has("%d:gw_sweep" % u.team):
		u.game._first_of["%d:gw_sweep" % u.team] = true
		u.game.mlog.add("%s's Great Winder sweeps up its first wreck" % u.game.mlog.who(u.team))
	return n


# ------------------------------------------------------------------ the picture

## Its strip: the key arm turning while it mends, the rollers while it sweeps, else walk or stand.
static func anim(u: Unit, moving: bool) -> String:
	if u.work == "mending":
		return "wind"
	if u.work == "sweeping":
		return "sweep"
	return "walk" if moving else "idle"


## Its winding ring on the ground, drawn under it (Unit._draw) while it is selected or its side's player is placing
## the army near it: a thin brass circle with ticks, like a clock face.
static func draw_area(u: Unit) -> void:
	var r := float(G["area"])
	var c := Color(0.95, 0.78, 0.35, 0.55)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, c, 1.5, true)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var d := Vector2.from_angle(a)
		u.draw_line(d * (r - 6.0), d * r, c, 2.0 if i % 3 == 0 else 1.0, true)


# ------------------------------------------------------------------ the card

## The selection card's line: its parts, the area and what it does now.
static func card_line(u: Unit) -> String:
	var a := [u.parts, int(G["cap"]), int(round(float(G["area"]) / Defs.TILE))]
	if u.work == "mending":
		return "Parts %d/%d · winds everything within %d tiles · mending." % a
	if u.work == "sweeping":
		return "Parts %d/%d · winds everything within %d tiles · sweeping a wreck." % a
	return "Parts %d/%d · winds everything within %d tiles." % a


## Its command card buttons (HUD._ability_buttons): MEND and SWEEP, both autocasts that glow while on (a press switches
## them for every Great Winder selected, online through the PROPS funnel: Game.net_set).
static func card(hud, list: Array, units: Array) -> void:
	var gws := units.filter(func(o: Unit) -> bool: return o.kind == KIND and o.team == hud.game.human)
	if gws.is_empty():
		return
	var game: Game = hud.game
	var mend_on: bool = gws.all(func(o: Unit) -> bool: return o.auto_repair)
	var sweep_on: bool = gws.all(func(o: Unit) -> bool: return o.auto_sweep)
	var parts := 0
	for o in gws:
		parts += o.parts
	hud._tip_for["MEND"] = ["Mend (automatic)", "On: standing about, the Great Winder mends the most hurt Clockwork unit near it with its key arm, one at a time, %d%% faster than a Winder (it costs cogs, like a repair), and winds it up. Right-click a hurt unit to send it there. Press to switch it off or on." % int(round((float(G["mend"]) - 1.0) * 100.0))]
	hud._tip_for["SWEEP"] = ["Sweep (automatic)", "On: with nothing to mend, the Great Winder walks to the wrecks of your Clockwork units near it and sweeps them into its hopper as PARTS (%d at most; for reassembly, later). It never sweeps Crown or Brood bodies. Press to switch it off or on." % int(G["cap"])]
	list.append(["ab_mend", ("~ " if mend_on else "") + "MEND", func() -> void:
		for o in game.selected_units():
			if o.kind == KIND:
				game.net_set(o, "auto_repair", not mend_on)
		hud.toast("Mending off." if mend_on else "Mending on: it mends the hurt Clockwork units near it."), true, "", ""])
	list.append(["ab_sweep", ("~ " if sweep_on else "") + "SWEEP", func() -> void:
		for o in game.selected_units():
			if o.kind == KIND:
				game.net_set(o, "auto_sweep", not sweep_on)
		hud.toast("Sweeping off." if sweep_on else "Sweeping on: it sweeps up your Clockwork wrecks near it."), true, "", "%d" % parts])
