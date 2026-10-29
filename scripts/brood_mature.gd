class_name BroodMature
extends RefCounted
## YOUNG AND MATURE (the owner, 2026-10-29 12:40-12:45: a unifying Brood feature; docs/brood_new.md "Young and mature").
## The Brood Mother lays only YOUNG units. A young unit MATURES (MATURE on its card) into its mature form, one into one
## (a Raptor egg gives three Raptors; each matures alone), once the Mother has reached the mature form's stage
## (Defs.NB "unit_stage"; its Sire is not needed: the young one is already fathered). It pays the mature form's price
## less its own share of its egg (price()), MOULTS for Defs.NB "moult" s (it can't move or fight; a shimmer drawn in code
## until the art comes: docs/art_style_inconsistency.md), then it IS the mature unit (Unit.morph: its kills, so its
## veterancy, and its health share kept). Pairs: Defs.NB "mature" (young -> mature): the Raptor into the YOUNG TYRANT;
## the Venom line's pair is a data slot until the owner settles it (Defs.NB "lines_later", NB_PARKED). MATURE on a
## group: each selected matures as far as the food allows.
## Also here: a "venom" unit's glob, and the Mother's stage art (her stage-2 and stage-3 sheets).


## The mature form of k ("" when k does not mature).
static func mature_of(k: String) -> String:
	return String((Defs.NB["mature"] as Dictionary).get(k, ""))


## The young form k matures from ("" when k is not a mature form).
static func young_of(k: String) -> String:
	for y in Defs.NB["mature"]:
		if String(Defs.NB["mature"][y]) == k:
			return y
	return ""


static func is_mature(k: String) -> bool:
	return young_of(k) != ""


## What maturing a young `k` costs a side: [food, spoils]: the mature form's price less the young one's share of its egg
## (a Raptor is a third of its 75-food egg: 25). No bargain (docs/design_principles.md 1): young + this = the mature
## form's full price, as if it had been laid.
static func price(g: Game, t: int, k: String) -> Array:
	var m := mature_of(k)
	if m == "":
		return [0, 0]
	var mp := g.unit_price(t, m)
	var yp := g.unit_price(t, k)
	var n := maxf(1.0, float(Defs.UNITS[k].get("spawn", 1)))
	return [maxi(0, int(mp[0]) - int(round(float(yp[0]) / n))), maxi(0, int(mp[1]) - int(round(float(yp[1]) / n)))]


## The supply a maturing unit adds (the mature form's less its own), held from the moment it starts.
static func more_supply(k: String) -> int:
	var m := mature_of(k)
	return maxi(0, int(Defs.UNITS[m]["supply"]) - int(Defs.UNITS[k]["supply"])) if m != "" else 0


## "" when unit u can start maturing now, else why not.
static func problem(u: Unit) -> String:
	if u == null or u.dead:
		return "Nothing to mature."
	var m := mature_of(u.kind)
	var g := u.game
	if m == "" or not BroodNew.on(g, u.team):
		return "It has no mature form."
	if u.moult_t >= 0.0:
		return "It is already moulting."
	if u.net_t > 0.0:
		return "It is held fast."
	var q := BroodNew.queen(g, u.team)
	if q == null:
		return "No Brood Mother."
	if BroodNew.stage(q) < BroodNew.unit_stage(m):
		return "Needs the Brood Mother at stage %d." % (BroodNew.unit_stage(m) + 1)
	var p := price(g, u.team, u.kind)
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if int(g.players[u.team]["gold"]) < int(p[0]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[u.team]["res2"]) < float(p[1]):
		return "Not enough %s." % String(res[1]).to_lower()
	var more := more_supply(u.kind)
	if more > 0 and g.supply_used(u.team) + more > int(g.players[u.team]["cap"]):
		if int(g.players[u.team]["cap"]) >= g.max_supply(u.team):
			return "Supply is maxed out."
		return "Need more supply: root more Mound Turtles."
	return ""


## MATURE on a selection: each young unit that can starts its moult, paying for itself, as far as the food allows. ""
## when at least one started, else why none did.
static func order(g: Game, list: Array) -> String:
	var why := ""
	var n := 0
	for u in list:
		if not (u is Unit) or not is_instance_valid(u) or u.dead or mature_of(u.kind) == "":
			continue
		var w := problem(u)
		if w != "":
			if why == "":
				why = w
			continue
		start(u)
		n += 1
	if n == 0 and why == "":
		why = "Nothing selected can mature."
	return "" if n > 0 else why


## Pay and begin: it stops where it is and moults; nothing it was doing goes on.
static func start(u: Unit) -> void:
	var g := u.game
	var p := price(g, u.team, u.kind)
	g.players[u.team]["gold"] -= int(p[0])
	g.add_res2(u.team, -float(p[1]))
	g.stats[u.team]["spent"] += int(p[0])
	u.cmd_stop()
	u.queue.clear()
	u.target = null
	u.phase = ""
	u.velocity = Vector2.ZERO
	u.moult_t = 0.0
	if u.visible and g.view_rect.has_point(u.position):
		Sfx.play_any(["hatch", "work/grub_deliver"], u.position, -6.0)


## Every tick of the moult (instead of moving and fighting: Unit._tick_unit). When the time is up it is the mature unit.
static func tick(u: Unit, delta: float) -> void:
	u.velocity = Vector2.ZERO
	u.phase = ""
	u.moult_t += delta
	if u.moult_t < float(Defs.NB["moult"]):
		return
	u.moult_t = -1.0
	var g := u.game
	var was := u.kind
	var m := mature_of(was)
	if m == "":
		return
	u.morph(m)
	u.cmd_stop()
	if u.sprite:
		u.sprite.self_modulate = Color.WHITE
	if u.visible and g.view_rect.has_point(u.position):
		g.spawn_effect("acid_splash", u.position + Vector2(0, -8), 0.9)
		Sfx.play_any(["hatch", "roar"], u.position, -6.0)
	if g.mlog:
		g.mlog.add("%s's %s matured into a %s" % [g.mlog.who(u.team), Defs.UNITS[was]["name"], Defs.UNITS[m]["name"]])
	if u.team == g.human:
		g.notify(Loc.t("A %s has matured.") % Loc.t(String(Defs.UNITS[m]["name"])), true)
	BroodNew.recount(g, u.team)


## How far through its moult (0..1; 0 when not moulting).
static func frac(u: Unit) -> float:
	return clampf(u.moult_t / float(Defs.NB["moult"]), 0.0, 1.0) if u.moult_t >= 0.0 else 0.0


## THE MOULT'S LOOK (code until the owner's moult art; docs/art_style_inconsistency.md): the young one still, its skin
## shimmering pale green-gold (Unit._animate: BroodMature.look), a cocoon-like glow of slime round it that thickens and
## splits at the end, and a bar over it.
static func look(u: Unit) -> void:
	if u.sprite == null:
		return
	if u.moult_t < 0.0:
		return
	var p := frac(u)
	var w := 0.5 + 0.5 * sin(u.moult_t * 7.0 + float(u.serial))
	var k := clampf(0.35 + 0.35 * w + 0.3 * p, 0.0, 1.0)
	u.sprite.self_modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.5, 1.6, 0.85), k)
	u.sprite.frame = 0


static func draw(u: Unit, top: float, bw: float) -> void:
	var p := frac(u)
	var t := u.moult_t
	var r := u.radius + 6.0
	# the slime round it: a soft glowing shell that swells as it moults, its rim shimmering
	u.draw_set_transform(Vector2(0, -r * 0.55), 0.0, Vector2(1.0, 0.8))
	var a := 0.16 + 0.1 * sin(t * 5.0)
	u.draw_circle(Vector2.ZERO, r * (0.85 + 0.25 * p), Color(0.75, 0.95, 0.35, a))
	for i in 3:
		var ph := fmod(t * 0.9 + float(i) / 3.0, 1.0)
		u.draw_arc(Vector2.ZERO, r * (0.5 + 0.7 * ph), 0.0, TAU, 28, Color(0.9, 1.0, 0.55, 0.45 * (1.0 - ph)), 1.5)
	if p > 0.85:
		# the shell splits: a few cracks
		var c := (p - 0.85) / 0.15
		for i in 4:
			var d := Vector2.from_angle(float(i) * TAU / 4.0 + 0.4) * r
			u.draw_line(d * 0.2, d * (0.2 + 0.8 * c), Color(1.0, 1.0, 0.7, 0.8), 1.5)
	u.draw_set_transform(Vector2.ZERO)
	var y := top - 7.0
	u.draw_rect(Rect2(-bw * 0.5, y, bw, 3).grow(0.5), Color(0, 0, 0, 0.7))
	u.draw_rect(Rect2(-bw * 0.5, y, bw * p, 3), Color(0.75, 1.0, 0.35))


# ------------------------------------------------------------------ a "venom" unit's glob

## A unit whose data says "venom" (the Venom line's young and mature forms, whichever they turn out to be: the parked
## Viper and Hooded Serpent, Defs.NB_PARKED): a venom glob, the full blow (and its acid, the kind's "acid" s) on the
## target, and with a "splash", half on the other enemies on the ground within that many px of it (telegraphed by the
## glob's flight).
static func venom_shot(g: Game, u: Unit, e: Entity, dmg: float) -> void:
	g.acid_shot(u, e, dmg)
	var sp := float(u.d.get("splash", 0.0))
	if sp <= 0.0:
		return
	var at: Vector2 = e.position if e is Unit else e.center()
	for o in g.units_near(at, sp + 12.0):
		if o == e or o.dead or o.off_field or o.is_air() or not g.hostile(o.team, u.team):
			continue
		if o.position.distance_to(at) <= sp + o.radius * 0.5:
			o.take_damage(dmg * 0.5, u, Entity.BLOW_RANGED)


# ------------------------------------------------------------------ the Mother's stage art

## Her picture at stage st (0 = stage 1): the owner's stage sheets (tools/import_brood_mature.py), else stage 1's.
static func stage_art(st: int) -> String:
	if st <= 0:
		return BroodNew.QUEEN
	var a := "%s_%d" % [BroodNew.QUEEN, st + 1]
	return a if ArtData.UNITS.has(a) else BroodNew.QUEEN


## Her stage from a stage scale (the ROOT ghost knows only the scale).
static func stage_of_scale(sc: float) -> int:
	var st: Array = Defs.NB["stages"]
	for i in st.size():
		if absf(float(st[i]["scale"]) - sc) < 0.001:
			return i
	return 0


## Where her laying frames draw the new egg (its bottom), from her feet, at stage 1's size (the game scales by the
## stage): tools/import_brood_new.py and import_brood_mature.py measure it.
const LAY_EGG := {"brood_mother": Vector2(14.0, -57.0), "brood_mother_2": Vector2(38.0, -41.0), "brood_mother_3": Vector2(41.0, -43.0)}


static func lay_egg_at(art: String) -> Vector2:
	return LAY_EGG.get(art, LAY_EGG["brood_mother"])
