class_name MarchingBand
extends RefCounted
## THE CROWN'S MARCHING BAND (the owner's idea, 2026-10-30; docs/marching_band.md; an EXPERIMENT behind the setting
## MARCHING BAND (experiment), off by default, kept in the match's setup: cfg "marching_band", Defs.marching_band).
##
## A 17th-century band that follows the soldiers and plays them into battle. ONE per player, trained at the Barracks.
## It starts as the bandmaster alone; MUSICIANS are taken on like a refit (ADD DRUMMER / ADD PIPER / ADD FIFER: a price and
## a few seconds each), each bringing an instrument. Every instrument it has keeps playing as a SECONDARY (a small aura);
## an instrument's SOLO (an active ability: short, then a long cooldown) puts it in the LEAD for a few seconds: its full
## buff. One solo at a time. Mechanical, not magic: a drum sets the pace, the pipes stir the blood, the fife keeps time
## for the loading drill.
##   DRUMS: movement speed        PIPES: melee damage (bayonets, sabres)        FIFE: reload speed (muskets, pistols, guns)
## Everything inside its RING (Defs.MARCHING_BAND "area") of its own side and its allies is covered (soldiers and guns,
## not workers, horses, wagons, medics or the band). The ring is drawn on the ground for everyone who sees the band
## (the telegraph: docs/design_principles.md 1), brighter while a solo plays. It is unarmed and fragile: kill it and the
## music stops (the risk that pays for the buffs).
##
## The state lives on the band unit in `Unit.band` (saved, sent online and recorded in replays as one field):
##   "m": the instruments it has, in the order taken on; "h": the one being taken on now ("" none), "he": the clock it
##   joins; "s": the instrument playing a solo ("" none), "se": the clock it ends; "cd": {instrument: the clock it may
##   solo again}. Clocks are the game clock (Game.clock), so the state only changes when something happens.
## The buff a covered unit gets is on that unit: `band_mul` (speed, melee, reload multipliers) until `band_until`.

const KIND := "band"
const INSTRUMENTS := ["drums", "pipes", "fife"]
const B := Defs.MARCHING_BAND


static func on(g: Game, t: int) -> bool:
	return Defs.marching_band and t >= 0 and t < g.factions.size() and g.factions[t] == "crown"


static func fresh() -> Dictionary:
	return {"m": [], "h": "", "he": 0.0, "s": "", "se": 0.0, "cd": {}}


static func has(u: Unit, ins: String) -> bool:
	return (u.band.get("m", []) as Array).has(ins)


## The instrument leading now ("" none), by the clock (a solo ends at "se").
static func lead(u: Unit) -> String:
	var s := String(u.band.get("s", ""))
	if s != "" and u.game.clock < float(u.band.get("se", 0.0)):
		return s
	return ""


static func solo_left(u: Unit) -> float:
	return maxf(float(u.band.get("se", 0.0)) - u.game.clock, 0.0) if lead(u) != "" else 0.0


static func cooldown_left(u: Unit, ins: String) -> float:
	return maxf(float((u.band.get("cd", {}) as Dictionary).get(ins, 0.0)) - u.game.clock, 0.0)


static func hire_left(u: Unit) -> float:
	if String(u.band.get("h", "")) == "":
		return 0.0
	return maxf(float(u.band.get("he", 0.0)) - u.game.clock, 0.0)


## The share an instrument gives now: its full buff leading, a small share as a secondary, nothing if it isn't there.
static func share(u: Unit, ins: String) -> float:
	if not has(u, ins):
		return 0.0
	return float(B[ins]["lead"]) if lead(u) == ins else float(B[ins]["second"])


## The band's three multipliers now (speed, melee, reload rate).
static func muls(u: Unit) -> Vector3:
	return Vector3(1.0 + share(u, "drums"), 1.0 + share(u, "pipes"), 1.0 + share(u, "fife"))


## Does the band's music reach this unit: its side or an ally's, a fighting unit or a gun (not workers, horses, medics,
## wagons, the band itself), on the ground.
static func covers(band: Unit, o: Unit) -> bool:
	if o == band or o.dead or o.aboard != null or o.off_field or not band.game.allied(band.team, o.team):
		return false
	if o.is_worker() or o.kind == KIND or o.kind == "horse" or o.d.get("medic", false):
		return false
	if o.is_air():
		return false
	return o.has_attack() or o.kind == "dragoon"


# ------------------------------------------------------------------ the tick (host / single player)

static func tick(u: Unit, delta: float) -> void:
	var g := u.game
	if u.band.is_empty():
		u.band = fresh()
	# a musician joins
	var h := String(u.band.get("h", ""))
	if h != "" and g.clock >= float(u.band.get("he", 0.0)):
		(u.band["m"] as Array).append(h)
		u.band["h"] = ""
		u.max_hp += float(B["hp_per"])
		u.hp = minf(u.max_hp, u.hp + float(B["hp_per"]))
		if u.team == g.human:
			g.float_text(u.position + Vector2(0, -40), Loc.t("+ %s") % Loc.t(String(B[h]["who"])), Color(1.0, 0.9, 0.5))
		u.queue_redraw()
	if String(u.band.get("s", "")) != "" and g.clock >= float(u.band.get("se", 0.0)):
		u.band["s"] = ""
		u.queue_redraw()
	# the music over the ring, a few times a second
	u._band_t -= delta
	if u._band_t <= 0.0:
		u._band_t = float(B["pulse"])
		play_over(u)
	# no orders: it keeps up with the soldiers near it (an escort, like the Missionary's)
	if u.order == "idle" and u.queue.is_empty() and u.phase == "":
		u._band_scan -= delta
		if u._band_scan <= 0.0:
			u._band_scan = 0.5
			var lead_man := escort_pick(u)
			if lead_man:
				u.cmd_follow(lead_man)
	look_tick(u, delta)


## Every covered unit in the ring gets the band's buff for a little longer (the strongest band's, if two overlap).
## Returns how many it reached (tests).
static func play_over(u: Unit) -> int:
	var m := muls(u)
	if m == Vector3.ONE:
		return 0
	var g := u.game
	var until := g.clock + float(B["linger"])
	var n := 0
	for o: Unit in g.units_near(u.position, float(B["area"])):
		if not covers(u, o):
			continue
		if o.band_until > g.clock:
			o.band_mul = Vector3(maxf(o.band_mul.x, m.x), maxf(o.band_mul.y, m.y), maxf(o.band_mul.z, m.z))
		else:
			o.band_mul = m
		o.band_until = until
		n += 1
	return n


## The soldier the band falls in behind when it has no orders: the nearest MOVING one of its side within its leash
## (none moving: it stays where it is).
static func escort_pick(u: Unit) -> Unit:
	var best: Unit = null
	var bd := INF
	for o: Unit in u.game.units_near(u.position, float(B["leash"])):
		if o.team != u.team or not covers(u, o) or o.velocity.length() < 12.0:
			continue
		var dd := o.position.distance_squared_to(u.position)
		if dd < bd:
			bd = dd
			best = o
	return best


# ------------------------------------------------------------------ the buffs, asked by Unit

## The speed multiplier on `o` now.
static func speed_mul(o: Unit) -> float:
	return o.band_mul.x if o.band_until > o.game.clock else 1.0


static func melee_mul(o: Unit) -> float:
	return o.band_mul.y if o.band_until > o.game.clock else 1.0


static func reload_mul(o: Unit) -> float:
	return o.band_mul.z if o.band_until > o.game.clock else 1.0


# ------------------------------------------------------------------ orders (Unit.band_hire / band_solo: the net funnel)

## Why the band can't take on this musician now ("" if it can).
static func hire_problem(u: Unit, ins: String) -> String:
	if not INSTRUMENTS.has(ins):
		return "?"
	if u.dead:
		return ""
	if has(u, ins):
		return "The band already has a %s." % String(B[ins]["who"])
	if String(u.band.get("h", "")) != "":
		return "The band is taking on a musician already."
	var g := u.game
	if int(g.players[u.team]["gold"]) < int(B[ins]["cost"]):
		return "Not enough %s." % "gold"
	if float(g.players[u.team]["res2"]) < float(B[ins]["cost2"]):
		return "Not enough %s." % "powder"
	return ""


static func hire(u: Unit, ins: String) -> String:
	if u.band.is_empty():
		u.band = fresh()
	var why := hire_problem(u, ins)
	if why != "":
		u.game.tell(u.team, why)
		return why
	var g := u.game
	g.pay_refit(u.team, [int(B[ins]["cost"]), float(B[ins]["cost2"])])
	u.band["h"] = ins
	u.band["he"] = g.clock + float(B[ins]["time"])
	u.queue_redraw()
	if g.mlog:
		g.mlog.add("%s's band takes on a %s" % [g.mlog.who(u.team), String(B[ins]["who"])])
	return ""


static func solo_problem(u: Unit, ins: String) -> String:
	if not has(u, ins):
		return "No %s in the band yet." % String(B[ins]["who"])
	if lead(u) != "":
		return "The band is already playing a solo."
	var cd := cooldown_left(u, ins)
	if cd > 0.0:
		return "The %s can solo again in %d s." % [String(B[ins]["who"]), int(ceil(cd))]
	return ""


static func solo(u: Unit, ins: String) -> String:
	if u.band.is_empty():
		u.band = fresh()
	var why := solo_problem(u, ins)
	if why != "":
		u.game.tell(u.team, why, true)
		return why
	var g := u.game
	u.band["s"] = ins
	u.band["se"] = g.clock + float(B["solo"])
	(u.band["cd"] as Dictionary)[ins] = g.clock + float(B["cooldown"])
	u._band_t = 0.0                  # (the lead reaches the ring at once)
	u._sound_t = 0.0
	u.queue_redraw()
	if g.mlog:
		g.mlog.add("%s's band: %s solo" % [g.mlog.who(u.team), ins])
	return ""


## The train problem at a Barracks: one band per player (counting one waiting in a queue).
static func limit_problem(g: Game, t: int) -> String:
	if not on(g, t):
		return "The marching band is an experiment: switch it on in Settings."
	var have := 0
	for o in g.units:
		if o.team == t and not o.dead and o.kind == KIND:
			have += 1
	for b in g.buildings:
		if b.team == t and not b.dead:
			have += b.queue.count(KIND)
	if have >= 1:
		return "Only one Marching Band per player."
	return ""


# ------------------------------------------------------------------ the computer (simple: optional)

## The computer's band, if it has one: musicians as money allows (drums first), solos when its soldiers near the band
## fight (fife for a musket line, pipes when enemies are at bayonet reach, drums when it is walking far).
static func ai_tick(g: Game, t: int) -> void:
	var u: Unit = null
	for o in g.units:
		if o.team == t and not o.dead and o.kind == KIND:
			u = o
			break
	if u == null:
		return
	if u.band.is_empty():
		u.band = fresh()
	for ins in ["drums", "fife", "pipes"]:
		if not has(u, ins) and hire_problem(u, ins) == "" and int(g.players[t]["gold"]) >= int(B[ins]["cost"]) + 40:
			hire(u, ins)
			break
	if lead(u) != "":
		return
	var fighting := 0
	var close := 0
	for o: Unit in g.units_near(u.position, float(B["area"])):
		if o.team == t and covers(u, o) and o.target != null and is_instance_valid(o.target):
			fighting += 1
			if o.mode == "bayonet":
				close += 1
	if fighting >= 3:
		var want := "pipes" if close * 2 >= fighting else "fife"
		if solo_problem(u, want) == "":
			solo(u, want)
		elif solo_problem(u, "fife" if want == "pipes" else "pipes") == "":
			solo(u, "fife" if want == "pipes" else "pipes")


# ------------------------------------------------------------------ the look and the sound (host, guest, replay)

## The sound loops and the redraw while the ring pulses (also on an online guest and in a replay: NetPuppet).
static func look_tick(u: Unit, delta: float) -> void:
	u._sound_t -= delta
	if u._sound_t <= 0.0:
		u._sound_t = float(B["phrase"])
		var g := u.game
		if u.visible and g.view_rect.grow(200.0).has_point(u.position) and not Sfx.hush:
			var ld := lead(u)
			for ins in u.band.get("m", []):
				Sfx.play("band/%s%s" % [ins, "_lead" if ins == ld else ""], u.position, 0.0 if ins == ld else -7.0)
	u._band_draw_t -= delta
	if u._band_draw_t <= 0.0 and u.visible and u.game.view_rect.has_point(u.position):
		u._band_draw_t = 0.1
		u.queue_redraw()
		if u._band_fx:
			u._band_fx.queue_redraw()


## Its ring on the ground (Unit._draw_unit, under it): gold, in the leading instrument's colour and pulsing during a solo;
## little ticks round it, one colour per instrument it has. Drawn for everyone who sees the band (the telegraph).
static func draw_ring(u: Unit) -> void:
	if u.band.get("m", []).is_empty() and String(u.band.get("h", "")) == "":
		return
	var r := float(B["area"])
	var ld := lead(u)
	var pulse := 0.5 + 0.5 * sin(u.game.clock * 5.0)
	var c := Color(1.0, 0.86, 0.45, 0.6)
	if ld != "":
		c = (B[ld]["col"] as Color)
		c.a = 0.6 + 0.3 * pulse
	# (a true circle: the reach is measured flat on the map, as the Great Winder's; a dark edge under it reads on sand)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.15, 0.09, 0.03, 0.35), 4.0 if ld != "" else 3.0, true)
	u.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, c, 2.5 if ld != "" else 1.5, true)
	var ins: Array = u.band.get("m", [])
	for i in 24:
		if ins.is_empty():
			break
		var a := TAU * float(i) / 24.0 + u.game.clock * 0.3
		var k: String = ins[i % ins.size()]
		var cc: Color = B[k]["col"]
		cc.a = 0.7
		var dv := Vector2.from_angle(a)
		u.draw_line(dv * (r - 7.0), dv * r, cc, 2.0, true)


## The instruments (code-drawn stand-ins, docs/art_style_inconsistency.md): the drum at the bandmaster's hip, the pipes'
## bag and drones over his shoulder, the fife; the lead one bigger, and notes rising over the band while it plays.
static func draw_kit(u: Unit, ci: CanvasItem) -> void:
	var ins: Array = u.band.get("m", [])
	var ld := lead(u)
	var t := u.game.clock
	if ins.has("drums"):
		var s := 1.25 if ld == "drums" else 1.0
		var at := Vector2(-11, -9)
		ci.draw_set_transform(at, 0.0, Vector2(s, s))
		ci.draw_rect(Rect2(-5, -4, 10, 8), Color(0.75, 0.1, 0.1))
		ci.draw_rect(Rect2(-5, -4, 10, 8), Color(0.2, 0.1, 0.05), false, 1.0)
		ci.draw_line(Vector2(-5, -4), Vector2(5, 4), Color(0.95, 0.85, 0.5), 1.0)
		ci.draw_line(Vector2(-5, 4), Vector2(5, -4), Color(0.95, 0.85, 0.5), 1.0)
		ci.draw_rect(Rect2(-5, -5, 10, 1.5), Color(0.95, 0.92, 0.85))
		var hit := 1.5 * sin(t * (16.0 if ld == "drums" else 8.0))
		ci.draw_line(Vector2(-3, -7 + hit), Vector2(-1, -5), Color(0.4, 0.25, 0.1), 1.2)
		ci.draw_line(Vector2(3, -7 - hit), Vector2(1, -5), Color(0.4, 0.25, 0.1), 1.2)
	if ins.has("pipes"):
		var s2 := 1.25 if ld == "pipes" else 1.0
		var at2 := Vector2(10, -20)
		ci.draw_set_transform(at2, 0.0, Vector2(s2, s2))
		ci.draw_circle(Vector2(0, 3), 4.0, Color(0.15, 0.35, 0.2))
		ci.draw_circle(Vector2(0, 3), 4.0, Color(0.05, 0.1, 0.05), false, 1.0)
		for k in 3:
			ci.draw_line(Vector2(-1 + k * 2, 0), Vector2(-4 + k * 3, -9 + k), Color(0.3, 0.2, 0.1), 1.2)
		ci.draw_line(Vector2(-2, 5), Vector2(-6, 9), Color(0.3, 0.2, 0.1), 1.2)
	if ins.has("fife"):
		var s3 := 1.3 if ld == "fife" else 1.0
		var at3 := Vector2(6, -25)
		ci.draw_set_transform(at3, 0.0, Vector2(s3, s3))
		ci.draw_line(Vector2(-6, 1), Vector2(6, -1), Color(0.85, 0.75, 0.55), 1.6)
		ci.draw_circle(Vector2(6, -1), 0.9, Color(0.2, 0.15, 0.1))
	ci.draw_set_transform(Vector2.ZERO)
	if ins.is_empty():
		return
	# notes over the band: more and coloured while one leads
	var n := 2 + (2 if ld != "" else 0)
	for i in n:
		var ph := fmod(t * 0.7 + float(i) / float(n), 1.0)
		var k: String = ld if ld != "" else String(ins[i % ins.size()])
		var c: Color = B[k]["col"]
		c.a = (1.0 - ph) * 0.9
		var p := Vector2(-10.0 + 20.0 * float(i) / maxf(n - 1, 1) + 3.0 * sin(t * 3.0 + i), -36.0 - ph * 22.0)
		ci.draw_circle(p, 2.0, c)
		ci.draw_line(p + Vector2(1.8, 0), p + Vector2(1.8, -6), c, 1.0)


## A number that changes when the drawing should (Unit's redraw key).
static func draw_key(u: Unit) -> int:
	var ld := lead(u)
	return (u.band.get("m", []) as Array).size() + (8 if ld != "" else 0) + (int(u.game.clock * 6.0) % 97) * 16


## The selection card's line.
static func card_line(u: Unit) -> String:
	var ins: Array = u.band.get("m", [])
	var a := int(round(float(B["area"]) / Defs.TILE))
	if ins.is_empty() and String(u.band.get("h", "")) == "":
		return Loc.t("The bandmaster alone: ADD a drummer, a piper or a fifer.")
	var parts := PackedStringArray()
	for k in ins:
		parts.append(Loc.t(String(B[k]["label"])))
	var line := Loc.t("Plays: %s · %d tiles") % [", ".join(parts) if not parts.is_empty() else "-", a]
	var ld := lead(u)
	if ld != "":
		line += " · " + Loc.t("%s SOLO: %d s") % [Loc.t(String(B[ld]["label"])), int(ceil(solo_left(u)))]
	var h := String(u.band.get("h", ""))
	if h != "":
		line += " · " + Loc.t("a %s joins in %d s") % [Loc.t(String(B[h]["who"])), int(ceil(hire_left(u)))]
	return line


## Its command card (HUD._ability_buttons): ADD a musician (each once, one at a time) and each hired instrument's SOLO.
static func card(hud, list: Array, units: Array) -> void:
	var bands := units.filter(func(o: Unit) -> bool: return o.kind == KIND and o.team == hud.game.human)
	if bands.is_empty():
		return
	var u: Unit = bands[0]
	var a := int(round(float(B["area"]) / Defs.TILE))
	for ins in INSTRUMENTS:
		var info: Dictionary = B[ins]
		var stat := String(info["stat_text"])
		if not has(u, ins):
			var lab := "ADD " + String(info["who"]).to_upper()
			hud._tip_for[lab] = [String(info["add_title"]), "Takes on a %s (%d s): the band plays the %s from then on. As a secondary it gives %s +%d%% to your soldiers within %d tiles of the band; its SOLO gives +%d%% for %d s (then %d s before the next). The band gets %d more health." % [
				String(info["who"]).to_lower(), int(info["time"]), String(info["label"]).to_lower(), stat, int(round(float(info["second"]) * 100.0)), a,
				int(round(float(info["lead"]) * 100.0)), int(B["solo"]), int(B["cooldown"]), int(B["hp_per"])]]
			var why := hire_problem(u, ins)
			var cost := str(int(info["cost"])) + ("+%d" % int(info["cost2"]) if int(info["cost2"]) > 0 else "")
			list.append(["ab_band_" + ins, lab, func() -> void:
				u.band_hire(ins), why == "", why, cost])
		else:
			var lab2 := String(info["label"]).to_upper() + " SOLO"
			hud._tip_for[lab2] = [String(info["solo_title"]), "The %s leads for %d s: %s +%d%% to your soldiers within %d tiles of the band (the other instruments keep playing as secondaries). Then %d s before it can solo again; one solo at a time." % [
				String(info["label"]).to_lower(), int(B["solo"]), stat, int(round(float(info["lead"]) * 100.0)), a, int(B["cooldown"])]]
			var why2 := solo_problem(u, ins)
			var cd := cooldown_left(u, ins)
			var corner := ("%ds" % int(ceil(solo_left(u)))) if lead(u) == ins else (("%ds" % int(ceil(cd))) if cd > 0.0 else "")
			list.append(["ab_band_" + ins, ("~ " if lead(u) == ins else "") + lab2, func() -> void:
				u.band_solo(ins), why2 == "", why2, corner])


# ------------------------------------------------------------------ save / net

static func save(u: Unit) -> Dictionary:
	if u.band.is_empty():
		return {}
	var cd := {}
	for k in u.band.get("cd", {}):
		cd[k] = snappedf(float(u.band["cd"][k]), 0.01)
	return {"m": (u.band.get("m", []) as Array).duplicate(), "h": String(u.band.get("h", "")), "he": snappedf(float(u.band.get("he", 0.0)), 0.01),
		"s": String(u.band.get("s", "")), "se": snappedf(float(u.band.get("se", 0.0)), 0.01), "cd": cd}


static func load_state(u: Unit, d: Dictionary) -> void:
	u.band = fresh()
	for k in d.get("m", []):
		if INSTRUMENTS.has(String(k)):
			(u.band["m"] as Array).append(String(k))
	u.band["h"] = String(d.get("h", ""))
	u.band["he"] = float(d.get("he", 0.0))
	u.band["s"] = String(d.get("s", ""))
	u.band["se"] = float(d.get("se", 0.0))
	var cd: Dictionary = d.get("cd", {})
	for k in cd:
		u.band["cd"][String(k)] = float(cd[k])
	u.max_hp = float(u.d["hp"]) + float(B["hp_per"]) * (u.band["m"] as Array).size()
