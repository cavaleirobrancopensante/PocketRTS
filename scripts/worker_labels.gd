class_name WorkerLabels
extends RefCounted
## THE WORKER LABELS over your economy buildings (the owner, 2026-10-29): each crew count says whose it is, a small job
## word before it ("HAULERS 2/4" on a Town Hall, "FARMERS 3/8" on a Farm, "POWDER MAKERS 1/6" on a Powder Mill,
## "WINDERS 4/6" on a Cog Press or Mainspring, "GRUBS 4/6" on the Brood's Feeding Pits, Rootmaws and food piles), and
## resting the mouse on it (~0.5 s; a long press on a phone) opens a tooltip saying what those workers do, with the real
## numbers. Drawn on the game's overlay (Game._draw_mine_labels calls draw_all), hit-tested by the same layout (at), so
## what you see is what you hover. The label only draws and explains: a click on it still selects its building
## (Game.entity_at falls back to it).
##
## HAULERS: the Town Hall's label reads "assigned / needed" (the owner, 07:39): the first number the Labourers assigned
## to this hall as haulers, the second how many this hall's base can use now (hauler_need), capped at its "haulers" (6).
## White below the need, green at it, orange over it (Labourers who could be farming), grey at 0/0.

const WORD_SZ := 11          # the job word: small capitals beside the count
const COUNT_SZ := 15         # the count, as it always was
const GAP := 4.0
const BAR_W := 40.0
const HIT_GROW := 6.0        # px of slack round the label for the mouse and a finger

## The job word of each crewed kind (English; Loc.t translates it).
const WORDS := {
	"town_hall": "HAULERS",
	"farm": "FARMERS",
	"powder_mill": "POWDER MAKERS",
	"feeding_pit": "GRUBS",
	"cog_press": "WINDERS",
	"mainspring": "WINDERS",
	"clocktower": "WINDERS",       # (the old Line economy only: in gear mode it has no crew)
	"boiler": "WINDERS",           # (likewise)
	"nb_maw": "GRUBS",
	"nb_pile": "GRUBS",
}

## HAULER NEED (the owner's rule, 2026-10-29 07:49), what the hauling work of Game.haul_dispatch asks for (Defs.HAUL):
## - every finished Horse Breeder: +1 (its horses are led to the Barracks or Foundry);
## - every Powder Wagon on SUPPLY away from a filling building: kegs it needs a second x the round trip of one keg.
##   The kegs a second come from its recent powder use (Unit.powder_out: the shots it handed out over the last
##   USE_WINDOW s, read as a rate over at least USE_MIN s, at Defs.WAGON "keg" shots a keg); the round trip is the walk
##   from the nearest Powder Mill to the wagon and back at the Labourer's speed (straight line x PATH for the way round
##   things) plus Defs.WAGON "keg_load". At least 1 for a wagon that is being drawn from; at most the kegs its store
##   holds (Defs.WAGON store / keg: 4). THE SAME NEED SENDS THE KEGS: Game.keg_requests puts that many on the way
##   (the owner, 08:00: no limit of kegs in flight but the wagon's room).
## Each counts for its nearest Town Hall. The sum is rounded up (a little slack: ROUND_SLACK) and capped at the hall's
## "haulers" (6). It is worked out every UPDATE s and smoothed: it rises at once, and falls only after it has stayed lower
## for DROP_AFTER updates in a row, so the label does not flicker.
const NEED_BREEDER := 1
const USE_WINDOW := 30.0
const USE_MIN := 20.0
const PATH := 1.25
const UPDATE := 3.0
const SAMPLE := 1.0
const DROP_AFTER := 3
const ROUND_SLACK := 0.15


static func word_of(kind: String) -> String:
	return String(WORDS.get(kind, ""))


# ------------------------------------------------------------------ hauler need

## The state kept on the game (display only: nothing in the match depends on it).
static func _st(g: Game) -> Dictionary:
	if g.worker_label_state.is_empty():
		g.worker_label_state = {"sample": 0.0, "update": 0.0, "use": {}, "shown": {}, "low": {}, "parts": {}}
	return g.worker_label_state


## Each game tick (from Game.haul_dispatch): sample the wagons' powder use, now and then work the needs out again.
static func tick(g: Game, delta: float) -> void:
	var st := _st(g)
	st["sample"] = float(st["sample"]) - delta
	if float(st["sample"]) <= 0.0:
		st["sample"] = SAMPLE
		_sample(g)
	st["update"] = float(st["update"]) - delta
	if float(st["update"]) <= 0.0:
		st["update"] = UPDATE
		update(g)


## One sample of every wagon's handed-out powder: [clock, shots out so far], the last USE_WINDOW s kept.
static func _sample(g: Game) -> void:
	var use: Dictionary = _st(g)["use"]
	var live := {}
	for u in g.units:
		if u.kind != "powder_wagon" or u.dead:
			continue
		var id: int = u.get_instance_id()
		live[id] = true
		var h: Array = use.get(id, [])
		h.append([g.clock, u.powder_out])
		while h.size() > 1 and g.clock - float(h[0][0]) > USE_WINDOW:
			h.pop_front()
		use[id] = h
	for id in use.keys():
		if not live.has(id):
			use.erase(id)


## Shots a second the wagon has handed out lately (0 with no history).
static func use_rate(g: Game, w: Unit) -> float:
	var h: Array = _st(g)["use"].get(w.get_instance_id(), [])
	if h.is_empty():
		return 0.0
	var first: Array = h[0]
	var out := w.powder_out - float(first[1])
	if out <= 0.0:
		return 0.0
	return out / maxf(USE_MIN, g.clock - float(first[0]))


## The kegs a Powder Wagon's store holds (the most that can be on the way to it at once).
static func store_kegs() -> float:
	return floorf(float(Defs.WAGON["store"]) / float(Defs.WAGON["keg"]))


## A wagon's need in haulers (fractional) and what it rests on: {need, rate (kegs/s), dist (tiles), trip (s)}.
static func wagon_need(g: Game, w: Unit) -> Dictionary:
	var r := {"need": 0.0, "want": 0.0, "rate": 0.0, "dist": 0.0, "trip": 0.0}
	if w.kind != "powder_wagon" or w.dead or w.off_field or not w.supplying or w._powder_building() != null:
		return r
	var mill: Building = null
	var bd := INF
	for b in g.buildings:
		if b.team == w.team and b.kind == "powder_mill" and b.built and not b.dead:
			var d: float = b.edge_distance(w.position)
			if d < bd:
				bd = d
				mill = b
	if mill == null:
		return r       # (no Mill: nothing to fetch kegs from)
	var shots := use_rate(g, w)
	r["rate"] = shots / float(Defs.WAGON["keg"])
	r["dist"] = bd / Defs.TILE
	r["trip"] = 2.0 * bd * PATH / float(Defs.UNITS["labourer"]["speed"]) + float(Defs.WAGON["keg_load"])
	if shots > 0.0:
		r["want"] = float(r["rate"]) * float(r["trip"])        # (what it would take without the kegs-in-flight limit)
		r["need"] = clampf(float(r["want"]), 1.0, store_kegs())
	return r


## The need of a Town Hall worked out afresh: {breeders, wagons, powder (fractional), kegs_s, dist, total}.
static func raw_parts(g: Game, hall: Building) -> Dictionary:
	var out := {"breeders": 0, "wagons": 0, "powder": 0.0, "kegs_s": 0.0, "dist": 0.0, "total": 0.0}
	var t := hall.team
	var halls: Array = g.haul_halls(t)
	if not halls.has(hall):
		return out
	for b in g.buildings:
		if b.team == t and b.kind == "horse_breeder" and b.built and not b.dead and _home(halls, b.center()) == hall:
			out["breeders"] += 1
	var dsum := 0.0
	for u in g.units:
		if u.team != t or u.kind != "powder_wagon" or u.dead or u.off_field or not u.supplying:
			continue
		if _home(halls, u.position) != hall:
			continue
		var wn := wagon_need(g, u)
		if float(wn["need"]) <= 0.0:
			continue
		out["wagons"] += 1
		out["powder"] = float(out["powder"]) + float(wn["need"])
		out["kegs_s"] = float(out["kegs_s"]) + float(wn["rate"])
		dsum += float(wn["dist"])
	if int(out["wagons"]) > 0:
		out["dist"] = dsum / float(out["wagons"])
	out["total"] = float(out["breeders"]) * NEED_BREEDER + float(out["powder"])
	return out


## Work every Town Hall's need out again (snap: take the new number at once, no smoothing; the tests use it).
static func update(g: Game, snap := false) -> void:
	var st := _st(g)
	var shown: Dictionary = st["shown"]
	var low: Dictionary = st["low"]
	var parts: Dictionary = st["parts"]
	var seen := {}
	for t in g.n_players():
		for hall in g.haul_halls(t):
			var id: int = hall.get_instance_id()
			seen[id] = true
			var p := raw_parts(g, hall)
			parts[id] = p
			var target := clampi(ceili(float(p["total"]) - ROUND_SLACK), 0, hall.haul_cap())
			var now := int(shown.get(id, -1))
			if snap or now < 0 or target > now:
				shown[id] = target
				low[id] = 0
			elif target < now:
				low[id] = int(low.get(id, 0)) + 1
				if int(low[id]) >= DROP_AFTER:
					shown[id] = target
					low[id] = 0
			else:
				low[id] = 0
	for id in shown.keys():
		if not seen.has(id):
			shown.erase(id)
			low.erase(id)
			parts.erase(id)


## How many haulers this Town Hall's base can use now (the smoothed number), capped at its haul_cap. 0 for anything else.
static func hauler_need(g: Game, hall: Building) -> int:
	if hall == null or not is_instance_valid(hall) or hall.haul_cap() <= 0:
		return 0
	var st := _st(g)
	if not (st["shown"] as Dictionary).has(hall.get_instance_id()):
		update(g)
	return int(st["shown"].get(hall.get_instance_id(), 0))


## What the hall's need rests on (from the last update): {breeders, wagons, powder, kegs_s, dist, total}.
static func need_parts(g: Game, hall: Building) -> Dictionary:
	hauler_need(g, hall)
	return _st(g)["parts"].get(hall.get_instance_id(), raw_parts(g, hall))


## The hall of `halls` nearest p (edge to point).
static func _home(halls: Array, p: Vector2) -> Building:
	var best: Building = null
	var bd := INF
	for h in halls:
		var d: float = (h as Building).edge_distance(p)
		if d < bd:
			bd = d
			best = h
	return best


# ------------------------------------------------------------------ which entities, and their layout

## The entities with a label now, for the player at this screen (yours; everything for a spectator or the demo).
static func entities(g: Game) -> Array:
	var out: Array = []
	for b in g.buildings:
		if b.dead or not b.built or not b.visible or (b.team != g.human and not g.demo):
			continue
		if not g.view_rect.has_point(b.global_position):
			continue
		if b.haul_cap() > 0 or b.crew_max() > 0 or not b.efficiency().is_empty():
			out.append(b)
	var see_all := g.demo or g.spectating()
	if see_all or BroodNew.on(g, g.human):
		for u in g.units:
			if u.dead or not u.visible or not BroodNew.is_source(u):
				continue
			if u.kind == BroodNew.MAW and (not BroodNew.rooted(u) or (u.team != g.human and not see_all)):
				continue
			if g.view_rect.has_point(u.position):
				out.append(u)
	return out


## Where and what a label is: {e, p (text baseline, left), rect (its dark plate), word, ww, count, cw, col, pct, pw, f}.
## {} for an entity that has none.
static func layout(g: Game, e: Entity, font: Font = null) -> Dictionary:
	if font == null:
		font = ThemeDB.fallback_font
	var L := {"e": e, "word": "", "ww": 0.0, "count": "", "cw": 0.0, "col": Color(1, 1, 1), "pct": "", "pw": 0.0, "f": 0.0}
	var y := 0.0
	var x := 0.0
	var key := ""
	if e is Building:
		var b := e as Building
		x = b.global_position.x
		y = b.global_position.y + b.bar_top() - 7.0
		if b.haul_cap() > 0:
			key = b.kind if WORDS.has(b.kind) else "town_hall"
			var have := b.haulers().size()
			var need := hauler_need(g, b)
			L["count"] = "%d/%d" % [have, need]
			L["col"] = hauler_colour(have, need)
		else:
			var crew_max: int = b.crew_max()
			var eff: Array = b.efficiency()
			if crew_max == 0 and eff.is_empty():
				return {}
			if crew_max > 0:
				key = b.kind
				# (spent land takes no crew: "spent" rather than a 0/5 that looks like room)
				var spent: bool = b.crew.is_empty() and b.barren()
				var have2: int = b.crew.size()
				L["count"] = Loc.t("spent") if spent else "%d/%d" % [have2, crew_max]
				L["col"] = Color(1, 0.45, 0.4) if spent else (Color(1, 1, 1) if have2 < crew_max else Color(0.45, 1, 0.45))
				if spent:
					key = ""
			if not eff.is_empty():
				L["f"] = float(eff[0])
				L["pct"] = "%d%%" % int(round(float(eff[0]) * 100))
	elif e is Unit and BroodNew.is_source(e):
		var u := e as Unit
		x = u.position.x
		y = u.position.y + BroodNew.label_top(u) - 7.0
		var cm := BroodNew.crew_max(g, u)
		var have3 := BroodNew.crew(g, u)
		var txt := BroodNew.crew_label(g, u)
		var spent3 := txt == Loc.t("spent")
		L["count"] = txt
		L["col"] = Color(1, 0.45, 0.4) if spent3 else (Color(1, 1, 1) if have3 < cm else Color(0.45, 1, 0.45))
		key = "" if spent3 else ("nb_maw" if u.kind == BroodNew.MAW else "nb_pile")
	else:
		return {}
	if key != "" and WORDS.has(key):
		L["word"] = Loc.t(String(WORDS[key]))
		L["ww"] = font.get_string_size(L["word"], HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SZ).x
	if L["count"] != "":
		L["cw"] = font.get_string_size(L["count"], HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_SZ).x
	if L["pct"] != "":
		L["pw"] = font.get_string_size(L["pct"], HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_SZ).x
	var total: float = float(L["ww"]) + (GAP if L["word"] != "" and L["count"] != "" else 0.0) + float(L["cw"])
	if L["pct"] != "":
		total += (GAP if L["count"] != "" else 0.0) + BAR_W + GAP + float(L["pw"])
	var p := Vector2(x - total * 0.5, y)
	L["p"] = p
	L["total"] = total
	L["rect"] = Rect2(p + Vector2(-4, -COUNT_SZ), Vector2(total + 8, COUNT_SZ + 5))
	return L


## HAULERS colours: grey at 0/0, white below the need, green at it, orange over it.
static func hauler_colour(have: int, need: int) -> Color:
	if have == 0 and need == 0:
		return Color(0.6, 0.6, 0.6)
	if have < need:
		return Color(1, 1, 1)
	if have == need:
		return Color(0.45, 1, 0.45)
	return Color(1.0, 0.62, 0.2)


static func draw(g: Game, L: Dictionary, font: Font) -> void:
	var ov: CanvasItem = g.overlay
	var p: Vector2 = L["p"]
	ov.draw_rect(L["rect"], Color(0, 0, 0, 0.6))
	var x := p.x
	var col: Color = L["col"]
	if L["word"] != "":
		ov.draw_string(font, Vector2(x, p.y - 1.0), L["word"], HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SZ, Color(col.lerp(Color(0.85, 0.82, 0.72), 0.45), 0.95))
		x += float(L["ww"]) + GAP
	if L["count"] != "":
		ov.draw_string(font, Vector2(x, p.y), L["count"], HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_SZ, col)
		x += float(L["cw"]) + GAP
	if L["pct"] != "":
		var f: float = L["f"]
		var ec := Game.eff_colour(f)
		var bar := Rect2(x, p.y - 10.0, BAR_W, 8.0)
		ov.draw_rect(bar, Color(0.12, 0.12, 0.12, 0.95))
		ov.draw_rect(Rect2(bar.position, Vector2(BAR_W * clampf(f, 0.0, 1.0), 8.0)), ec)
		ov.draw_rect(bar.grow(0.5), Color(0, 0, 0, 0.9), false, 1.0)
		ov.draw_string(font, Vector2(x + BAR_W + GAP, p.y), L["pct"], HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_SZ, ec)


static func draw_all(g: Game, font: Font) -> void:
	for e in entities(g):
		var L := layout(g, e, font)
		if not L.is_empty():
			draw(g, L, font)


## The entity whose label is under the world point p (with a little slack), or null.
static func at(g: Game, p: Vector2) -> Entity:
	var best: Entity = null
	var bd := INF
	for e in entities(g):
		if absf(e.global_position.x - p.x) > 220.0 or absf(e.global_position.y - p.y) > 320.0:
			continue          # (far from it: no need to lay its label out; the mouse asks this as it moves)
		var L := layout(g, e)
		if L.is_empty():
			continue
		var r: Rect2 = (L["rect"] as Rect2).grow(HIT_GROW)
		if r.has_point(p):
			var d: float = r.get_center().distance_squared_to(p)
			if d < bd:
				bd = d
				best = e
	return best


# ------------------------------------------------------------------ the tooltip

## {title, stats, body, hint} (already in the player's language) for the label over e; {} for none.
static func tip(g: Game, e: Entity) -> Dictionary:
	if e == null or not is_instance_valid(e) or e.dead:
		return {}
	if e is Unit and BroodNew.is_source(e):
		return _tip_nb(g, e as Unit)
	if not (e is Building):
		return {}
	var b := e as Building
	if b.haul_cap() > 0:
		return _tip_haulers(g, b)
	match b.kind:
		"farm":
			return _tip_farm(g, b)
		"powder_mill":
			return _tip_mill(g, b)
		"feeding_pit":
			return _tip_pit(g, b)
		Defs.GEAR_PRESS, "mainspring":
			if Defs.gear_mode:
				return _tip_gear_crew(g, b)
	if b.crew_max() > 0:
		return {"title": Loc.t("Winders"), "stats": Loc.t("%d of %d at work") % [b.working_crew(), b.crew_max()],
			"body": Loc.t("Winders carry the batteries it fills to an Ore Crusher, where the charge becomes ore: the farther a battery travels, the more it holds.")}
	if not b.efficiency().is_empty():
		return _tip_eff(g, b)
	return {}


static func _tip_haulers(g: Game, b: Building) -> Dictionary:
	var hs := b.haulers()
	var need := hauler_need(g, b)
	var np := need_parts(g, b)
	var parts: Array = []
	var nb := int(np["breeders"])
	if nb > 0:
		parts.append(Loc.t("%d for the Horse Breeder(s)") % (nb * NEED_BREEDER))
	if int(np["wagons"]) > 0:
		var kegs_s := float(np["kegs_s"])
		var every := "%d" % int(round(1.0 / kegs_s)) if kegs_s > 0.0 else "-"
		parts.append(Loc.t("%d for powder: %d wagon(s) about %d tiles from a Powder Mill, using about 1 keg every %s s") % [
			maxi(0, need - nb * NEED_BREEDER), int(np["wagons"]), int(round(float(np["dist"]))), every])
	var st := Loc.t("%d of %d free  ·  this base can use %d (up to %d)") % [b.haulers_free(), hs.size(), need, b.haul_cap()]
	var hint := (Loc.t("Needed %d: %s.") % [need, "; ".join(parts)]) if not parts.is_empty() else Loc.t("Nothing to haul yet: build a Horse Breeder, or put a Powder Wagon on SUPPLY.")
	if float(np["total"]) > float(b.haul_cap()) + 0.5:
		hint += " " + Loc.t("The base could use more than %d: build another Town Hall nearer the fighting.") % b.haul_cap()
	if hs.size() > need:
		hint += " " + Loc.t("More haulers than needed: the spare Labourers could be farming.")
	return {"title": Loc.t("Haulers: %d assigned, %d needed") % [hs.size(), need], "stats": st,
		"body": Loc.t("Haulers are Labourers you right-click onto the Town Hall. They lead new horses from the Horse Breeder to the Barracks or Foundry, bring spare horses to guns and wagons short of a team, and carry powder kegs from a Powder Mill to Powder Wagons on SUPPLY. The base can use 1 for each Horse Breeder, and for each wagon on SUPPLY that is being drawn from as many as keep its kegs coming: the kegs it uses a second x the walk from the Mill and back (at least 1, at most %d: the kegs its store holds). Up to %d in all.") % [int(store_kegs()), b.haul_cap()],
		"hint": hint}


static func _tip_farm(g: Game, b: Building) -> Dictionary:
	var crew := int(b.d["crew"])
	var full_per_s := float(Defs.FARM_YIELD) / Defs.FARM_GROW
	var each := full_per_s * (1.0 - Defs.FARM_BASE) / float(crew) * 60.0
	var st := Loc.t("%d of %d at work") % [b.working_crew(), crew] + "  ·  " + Loc.t("soil left %d%%") % int(round(b.soil_left() * 100.0))
	return {"title": Loc.t("Farmers"), "stats": st,
		"body": Loc.t("Labourers working the Farm. With all %d it ripens a %d-gold harvest every %d s; with nobody it grows at %d%% of that speed, and each farmer adds the same share: about %d gold a minute each. Harvests draw on the Town Hall's soil: once it is spent the Farm pays nothing.") % [
			crew, Defs.FARM_YIELD, int(Defs.FARM_GROW), int(round(Defs.FARM_BASE * 100.0)), int(round(each))]}


static func _tip_mill(g: Game, b: Building) -> Dictionary:
	var crew := int(b.d["crew"])
	var st := Loc.t("%d of %d at work") % [b.working_crew(), crew] + "  ·  " + Loc.t("saltpetre left %d%%") % int(round(b.lode_left() * 100.0))
	return {"title": Loc.t("Powder makers"), "stats": st,
		"body": Loc.t("Labourers grinding the Town Hall's saltpetre into black powder, about %d powder a minute each (%d with all %d). Powder buys Musketeers and Powder Wagons and refills your soldiers' shots. Once the saltpetre is spent the Mill grinds nothing.") % [
			int(round(Defs.MILL_RATE * 60.0)), int(round(Defs.MILL_RATE * 60.0 * crew)), crew]}


static func _tip_pit(g: Game, b: Building) -> Dictionary:
	var dist := g.capital_dist(b.team, b.center())
	var trip := g.food_value(b)
	var per_min := _per_min(dist, trip)
	var st := Loc.t("%d of %d at work") % [b.crew.size(), b.crew_max()] + "  ·  " + Loc.t("%d tiles from the capital") % int(round(dist)) + "  ·  " + Loc.t("ground left %d%%") % int(round(b.soil_left() * 100.0))
	return {"title": Loc.t("Grubs"), "stats": st,
		"body": Loc.t("Grubs carry food from this pit's ground to the Burrow. A trip from here pays about %d food, about %d a minute for each grub: the farther the pit, the more a trip pays (best about %d to %d tiles out). It takes %d grubs, one more for every %d tiles beyond %d, up to %d.") % [
			int(round(trip)), int(round(per_min)), int(Defs.FOOD_FAR), int(Defs.FOOD_PEAK), Defs.crew_cap(b.d), int(Defs.PIT_CREW_STEP), int(Defs.FOOD_NEAR), Defs.PIT_CREW_MAX]}


## Food a minute for one grub: a load pays for the time its round trip takes (Game.food_at: a rate a grub-second that
## rises with the distance), so a grub earns that rate whatever the trip.
static func _per_min(dist: float, trip_value: float) -> float:
	if trip_value <= 0.0:
		return 0.0
	return _rate_guess(dist) * 60.0


## Game.food_at's rate (food a grub-second) at a distance.
static func _rate_guess(d: float) -> float:
	d = minf(d, Defs.FOOD_MAX_D)
	var rate := Defs.FOOD_RATE * (1.0 + Defs.FOOD_BONUS * clampf((d - Defs.FOOD_NEAR) / (Defs.FOOD_FAR - Defs.FOOD_NEAR), 0.0, 1.0))
	if d > Defs.FOOD_PEAK:
		rate *= 1.0 - Defs.FOOD_FADE * (d - Defs.FOOD_PEAK)
	return rate


static func _tip_nb(g: Game, u: Unit) -> Dictionary:
	var q := BroodNew.queen(g, g.human if u.team < 0 else u.team)
	var dist := q.position.distance_to(u.position) / Defs.TILE if q else 0.0
	var trip := BroodNew.load_value(g, u, g.human if u.team < 0 else u.team)
	var per_min := _per_min(dist, trip)
	var food := int(float(u.nb.get("food", 0.0)))
	if u.kind == BroodNew.PILE:
		return {"title": Loc.t("Grubs"), "stats": Loc.t("%d of %d at work") % [BroodNew.crew(g, u), BroodNew.crew_max(g, u)] + "  ·  " + Loc.t("%d food left") % food,
			"body": Loc.t("Food spilled on the ground by an uprooted Rootmaw (or a hauling one killed). Up to %d grubs carry it to the Brood Mother; a trip from here pays about %d food. It rots slowly.") % [BroodNew.crew_max(g, u), int(round(trip))]}
	var st := Loc.t("%d of %d at work") % [BroodNew.crew(g, u), BroodNew.crew_max(g, u)] + "  ·  " + Loc.t("%d tiles from the Mother") % int(round(dist)) + "  ·  " + Loc.t("%d food in it, %d in its ground") % [food, int(BroodNew.ground_left(g, u))]
	return {"title": Loc.t("Grubs"), "stats": st,
		"body": Loc.t("Grubs carry the food this Rootmaw draws from its ground to the Brood Mother. A trip from here pays about %d food, about %d a minute for each grub: the farther from her, the more a trip pays. It takes %d grubs, one more for every %d tiles beyond %d from her, up to %d.") % [
			int(round(trip)), int(round(per_min)), int(Defs.NB["maw_crew"]), int(Defs.PIT_CREW_STEP), int(Defs.FOOD_NEAR), Defs.PIT_CREW_MAX]}


static func _tip_gear_crew(g: Game, b: Building) -> Dictionary:
	var st := GearEcon.card_text(b)
	var why := Loc.t("The % is how hard it works now: its Winders' share x its DRIVE (100% when its ring meshes with the Clocktower's or a Mainspring's, 90, 80, 70% for each ring farther out; 0 unlinked)")
	if b.kind == Defs.GEAR_PRESS:
		var info: Dictionary = Defs.GEAR["press"]["big" if b.gear_big else "small"]
		var base := float(Defs.GEAR["press"]["base"])
		var each := float(info["full"]) * (1.0 - base) / float(info["crew"])
		return {"title": Loc.t("Winders"), "stats": st,
			"body": Loc.t("Winders winding the Cog Press: it presses cogs from the Clocktower's brass, %.1f a second with all %d; alone it makes %d%% of that and each Winder adds the same share, about %.2f a second.") % [float(info["full"]), int(info["crew"]), int(round(base * 100.0)), each] + " " + why + " " + Loc.t("x the brass (a quarter once it is spent).")}
	var si := GearEcon.spring_info(b.gear_big)
	var base2 := float(Defs.GEAR["mainspring"]["base"])
	var each2 := float(si["full"]) * (1.0 - base2) / float(si["crew"])
	return {"title": Loc.t("Winders"), "stats": st,
		"body": Loc.t("Winders cranking the Mainspring: it winds Tension, %.1f a second with all %d; alone it makes %d%% of that and each Winder adds the same share, about %.2f a second. Winding stops when you hold what your Mainsprings store.") % [float(si["full"]), int(si["crew"]), int(round(base2 * 100.0)), each2] + " " + why + "."}


static func _tip_eff(g: Game, b: Building) -> Dictionary:
	if Defs.gear_mode and String(b.d.get("faction", "")) == "clockwork":
		return {"title": Loc.t("Drive"), "stats": GearEcon.card_text(b),
			"body": Loc.t("How fast it works now: 100% when its gear ring meshes with the Clocktower's or a Mainspring's, 90%, 80%, 70% for each ring farther out, 0 when it is not linked to the gear field.")}
	return {"title": Loc.t("Efficiency"),
		"body": Loc.t("How hard it works now: the share of its crew at work x what is left of the reserve it draws on.")}
