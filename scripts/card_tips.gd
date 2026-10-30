class_name CardTips
extends RefCounted
## THE UNIT CARD'S WORKER, RESOURCE AND EGG CHIPS (the owner, 2026-10-30 09:06; docs/egg_tooltips.md): at the front of
## the card's stats row (UnitStats.draw_row), small icons with their numbers for what a building or creature works
## with, each opening the SAME tooltip as its label on the map (a mouse resting on it, a tap on a phone, as the other
## stat chips):
## - the WORKERS: a Town Hall's haulers, a Farm's farmers, a Powder Mill's powder makers, a Cog Press's or Mainspring's
##   Winders, a Rootmaw's or food pile's grubs (the worker's portrait and "have/max"); a Horse Breeder shows its Town
##   Hall's haulers (they lead its horses). Tooltip: WorkerLabels.tip (the label over the building).
## - the RESOURCE it draws on: a Farm's soil, a Mill's saltpetre, a Cog Press's brass, a Rootmaw's or pile's food.
##   Same tooltip as its workers.
## - the Brood Mother: her EGGS (an egg and "4/10": EggTip.tip, as her egg line on the map) and the GRUBS bringing her
##   food (mother_food_tip).
## Only for its own side (spectators and the demo see all), as the labels.
## Each chip: {icon: "", pic: Texture2D or dot: Color, text, title, col, tipf: Callable -> {title, stats, body, hint}}.

const FOOD := Color(0.55, 0.85, 0.3)
const SOIL := Color(0.98, 0.8, 0.2)
const SALT := Color(0.88, 0.88, 0.92)
const BRASS := Color(0.85, 0.68, 0.32)
const SPRING := Color(0.55, 0.85, 1.0)        # (a Mainspring's spring life: the Tension blue)

static var _pics := {}


## The worker's (or the egg's) picture.
static func pic(name: String) -> Texture2D:
	if _pics.has(name):
		return _pics[name]
	var t: Texture2D = null
	if name == "egg":
		var sheet := "res://assets/units/brood_egg/idle_s.png"
		if ResourceLoader.exists(sheet):
			var at := AtlasTexture.new()
			at.atlas = Game.tex(sheet)
			var cell: Vector2i = ArtData.UNITS["brood_egg"]["cell"]
			at.region = Rect2(0, 0, cell.x, cell.y)
			t = at
	else:
		for p in ["res://assets/icons/%s.png" % name, "res://assets/icons/brood/%s.png" % name]:
			if ResourceLoader.exists(p):
				t = Game.tex(p)
				break
	_pics[name] = t
	return t


static func _mine(g: Game, e: Entity) -> bool:
	if g.demo or g.spectating() or e.team == g.human:
		return true
	return e.team < 0 and BroodNew.is_source(e) and BroodNew.on(g, g.human)        # (a food pile nobody owns: the Brood's)


## The chips for e's card ([] for none).
static func chips(g: Game, e: Entity) -> Array:
	var out: Array = []
	if e == null or not is_instance_valid(e) or e.dead or not _mine(g, e):
		return out
	if e is Unit:
		var u := e as Unit
		if u.kind == BroodNew.QUEEN:
			var q := u
			out.append({"icon": "", "pic": pic("egg"), "text": "%d/%d" % [int(q.nb.get("eggs", 0)), BroodNew.eggs_max(q)], "title": "Eggs",
				"col": Color(0.85, 1.0, 0.55) if int(q.nb.get("eggs", 0)) > 0 else Color(1.0, 0.55, 0.45),
				"tipf": func() -> Dictionary: return EggTip.tip(g, q)})
			out.append({"icon": "", "pic": pic("grub"), "text": "%d" % mother_grubs(g, q.team)[0], "title": "Grubs bringing food",
				"tipf": func() -> Dictionary: return mother_food_tip(g, q)})
		elif BroodNew.is_source(u) and (u.kind == BroodNew.PILE or BroodNew.rooted(u)):
			var L := WorkerLabels.layout(g, u)
			if not L.is_empty() and String(L["count"]) != "":
				out.append({"icon": "", "pic": pic("grub"), "text": String(L["count"]), "title": "Grubs", "col": L["col"], "crew_of": u,
					"tipf": func() -> Dictionary: return WorkerLabels.tip(g, u)})
			out.append({"icon": "", "dot": FOOD, "text": "%d" % int(float(u.nb.get("food", 0.0))), "title": "Food",
				"tipf": func() -> Dictionary: return WorkerLabels.tip(g, u)})
		return out
	if not (e is Building):
		return out
	var b := e as Building
	if not b.built:
		return out
	var worker := "winder" if String(b.d.get("faction", "")) == "clockwork" else "labourer"
	if b.haul_cap() > 0 or b.crew_max() > 0:
		var L2 := WorkerLabels.layout(g, b)
		if not L2.is_empty() and String(L2["count"]) != "":
			var ttl := String(WorkerLabels.WORDS.get(b.kind, "HAULERS" if b.haul_cap() > 0 else "WORKERS")).capitalize()
			out.append({"icon": "", "pic": pic(worker), "text": String(L2["count"]), "title": ttl, "col": L2["col"], "crew_of": b,
				"tipf": func() -> Dictionary: return WorkerLabels.tip(g, b)})
	elif b.kind == "horse_breeder":
		var hall := home_hall(g, b)
		if hall != null:
			var L3 := WorkerLabels.layout(g, hall)
			if not L3.is_empty():
				out.append({"icon": "", "pic": pic("labourer"), "text": String(L3["count"]), "title": "Haulers", "col": L3["col"], "crew_of": hall,
					"tipf": func() -> Dictionary: return WorkerLabels.tip(g, hall) if is_instance_valid(hall) and not hall.dead else {}})
	var res := {"farm": ["Soil", SOIL], "powder_mill": ["Saltpetre", SALT], Defs.GEAR_PRESS: ["Brass", BRASS], "mainspring": ["Spring life", SPRING]}
	if res.has(b.kind) and (b.crew_max() > 0 or b.haul_cap() > 0):
		var left := b.soil_left() if b.kind == "farm" or b.kind == "mainspring" else b.lode_left()      # (a Mainspring: its Clocktower's spring life)
		out.append({"icon": "", "dot": res[b.kind][1], "text": "%d%%" % int(round(left * 100.0)), "title": res[b.kind][0],
			"col": Color(1, 0.45, 0.4) if left <= 0.0 else null,
			"tipf": func() -> Dictionary: return WorkerLabels.tip(g, b)})
	return out


## The Town Hall a Horse Breeder's horses are led from (the haulers' hall nearest it), or null.
static func home_hall(g: Game, b: Building) -> Building:
	var halls: Array = g.haul_halls(b.team)
	if halls.is_empty():
		return null
	return WorkerLabels._home(halls, b.center())


## [grubs at work on her side's Rootmaws and piles, of them carrying food now, sources worked].
static func mother_grubs(g: Game, t: int) -> Array:
	var n := 0
	var carrying := 0
	var srcs := {}
	for u in g.units:
		if u.kind != "grub" or u.dead or u.team != t or u.order != "gather":
			continue
		var m = u.home_mine
		if m == null or not is_instance_valid(m) or not BroodNew.is_source(m):
			continue
		n += 1
		srcs[m.get_instance_id()] = true
		if u.carrying > 0:
			carrying += 1
	return [n, carrying, srcs.size()]


## The tooltip of the GRUBS chip on her card: who brings her the food.
static func mother_food_tip(g: Game, q: Unit) -> Dictionary:
	if q == null or not is_instance_valid(q) or q.dead:
		return {}
	var mg := mother_grubs(g, q.team)
	var food := int(g.players[q.team]["gold"]) if q.team >= 0 else 0
	return {"title": Loc.t("Grubs bringing her food"),
		"stats": Loc.t("%d grubs at work on %d Rootmaws and food piles, %d carrying food now") % [int(mg[0]), int(mg[2]), int(mg[1])] + "  ·  " + Loc.t("%d food stored") % food,
		"body": Loc.t("Grubs carry food from the Rootmaws and the food piles to the Brood Mother: she keeps it as the Brood's food, the green figure at the top. The farther a Rootmaw from her, the more a trip pays; each Rootmaw takes more grubs the farther it is. Select a Rootmaw (or rest the mouse on its GRUBS label) for its own numbers.")}
