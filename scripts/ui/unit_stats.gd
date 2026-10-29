class_name UnitStats
extends RefCounted
## THE STATS ROW on the selection card (the owner, 2026-10-28; docs/unit_stats.md): a row of small icons with numbers under
## the selected unit's lines: its attack (damage a hit, how often, damage a second, reach, bonuses, what it can hit), its
## armour, speed, sight and supply. Each number is what the unit has NOW (veterancy, refits, research, wind, rooted, its
## shield...); its tooltip (hover; a tap on a phone) explains it and gives the trained value. Special attacks (pistol,
## bayonet, charge, canister, splash, nets, spells...) are named at the end of the row, a line each in their tooltip.
## Works for every unit of every faction (tools/test_unit_stats.gd); a building shows its armour and sight.
## Icons: assets/ui/stats/<name>.png, the owner's ChatGPT sheet cut by tools/import_stat_icons.py; the shapes drawn in
## draw_icon are only a fallback for a missing file.

## The icons, in the order of the owner's sheet (art/redraws/stat_icons_chatgpt.png), then his second sheet's
## (art/redraws/stat_icons_light_dps_chatgpt.png: bonus vs light, damage a second).
const ICONS := ["melee", "ranged", "area", "range", "attack_speed", "armour", "health", "speed", "sight",
	"vs_armoured", "vs_buildings", "hits_air", "supply", "no_attack", "vs_light", "dps"]
const DIR := "res://assets/ui/stats/"
## The row's height on the card (the selection panel is this much taller than it was: Hud._layout).
const ROW_H := 22.0
const ICON := 18.0
const HI := Color(0.62, 0.9, 1.0)        # a number changed from the trained one (better or worse: see the tooltip)
const LOW := Color(1.0, 0.62, 0.5)       # ...made worse (run down, acid)
const STRIKE := 0.35                     # Unit._strike_time's default


# ------------------------------------------------------------------ the numbers

## A unit's stats as it is now (the trained values in the tooltips).
static func of_unit(u: Unit) -> Dictionary:
	return build(_unit_state(u))


## A kind as trained, with no research (a group's type, the test). `armoured`: the Guardsman, the Cuirassier...
static func of_kind(kind: String, armoured := false) -> Dictionary:
	var base := _base_d(kind, armoured)
	return build({"kind": kind, "d": base, "base": base, "armoured": armoured, "kills": 0, "wind": 1.0, "mode": "",
		"lock": "", "bayonet": false, "deploy": "deployed", "rooted": false, "dug": false, "shield": false, "overload": false,
		"overcharge": false, "sky": "air", "acid": false, "charge_tech": false, "shield_tech": false, "spin": 0.0,
		"hp": float(base["hp"]), "max_hp": float(base["hp"]), "armor": float(base["armor"]), "speed": float(base["speed"]),
		"sight": int(base["sight"]), "unit": null, "auto_mount": false})


## A building: its armour and sight (and the Ratchet Turret's screws).
static func of_building(b: Building) -> Dictionary:
	var chips: Array = []
	var bd: Dictionary = b.d
	chips.append(_armour_chip(float(b.armor), float(bd.get("armor", 0)), [], "", 0.0))
	if b.kind == Defs.CW_TURRET:
		var t: Dictionary = Defs.TURRET["big" if b.gear_big else "small"]
		var cyc := float(t["cooldown"])
		var dps := float(t["damage"]) / cyc
		chips.push_front({"icon": "ranged", "text": "%d" % int(t["damage"]), "title": "Ranged attack",
			"stats": Loc.t("%d damage a screw · every %.1f s · %.1f a second") % [int(t["damage"]), cyc, dps],
			"body": Loc.t("Big screws at ground and air alike. SMALL gear: quick light screws; BIG gear: slow heavy ones, better against armour.")})
		chips.insert(1, {"icon": "range", "text": "%.1f" % (float(Defs.TURRET["range"]) / Defs.TILE), "title": "Range",
			"stats": Loc.t("%.1f tiles") % (float(Defs.TURRET["range"]) / Defs.TILE), "body": ""})
		chips.insert(2, {"icon": "hits_air", "text": "", "title": "Hits flyers", "stats": "", "body": Loc.t("It can hit flyers.")})
	chips.append({"icon": "sight", "text": "%d" % int(b.sight), "title": "Sight", "stats": Loc.t("%d tiles") % int(b.sight),
		"body": Loc.t("How far it sees.")})
	return {"chips": chips, "specials": [], "dps": 0.0, "range": 0.0, "type": "none", "kind": b.kind}


static func _base_d(kind: String, armoured: bool) -> Dictionary:
	var base: Dictionary = (Defs.UNITS[kind] as Dictionary).duplicate()
	if armoured and Defs.ARMOURED.has(kind):
		var info: Dictionary = Defs.ARMOURED[kind]
		base["armor"] = float(base["armor"]) + float(info["armor"])
		base["hp"] = float(base["hp"]) + float(info["hp"])
		base["speed"] = float(base["speed"]) + float(info.get("speed", 0))
		base["tags"] = ["armored"]
		base["name"] = String(info["name"])
	return base


static func _unit_state(u: Unit) -> Dictionary:
	var g: Game = u.game
	var t := u.team
	var has := func(k: String) -> bool: return g != null and t >= 0 and t < g.players.size() and g.has_tech(t, k)
	return {"kind": u.kind, "d": u.d, "base": _base_d(u.kind, u.armoured), "armoured": u.armoured, "kills": u.kills,
		"wind": u.wind if String(u.d["faction"]) == "clockwork" else 1.0, "mode": u.mode, "lock": u.lock, "bayonet": u.bayonet,
		"deploy": u.tesla_mode, "rooted": BroodNew.ROOTERS.has(u.kind) and u.tesla_mode != "packed",
		"dug": BroodNew.ROOTERS.has(u.kind) and BroodNew.rooted(u),
		"shield": u.shield_up, "overload": u.overclock_t > 0.0, "overcharge": u.overclock_t <= 0.0 and u.overcharged(),
		"sky": u.sky, "acid": u.acid_t > 0.0, "charge_tech": has.call("charge"), "shield_tech": has.call("shield_wall"),
		"spin": u.spin, "hp": u.hp, "max_hp": u.max_hp, "armor": u.armor, "speed": u.speed, "sight": u.sight, "unit": u,
		"auto_mount": u.auto_mount}


## How a kind attacks: "none", "melee", "ranged" or "area" (its icon).
static func attack_type(kind: String, d: Dictionary) -> String:
	if kind == "dragoon":
		return "ranged"           # (he gets off and fires as a Musketeer)
	if d.get("no_attack", false) or d.get("medic", false) or float(d.get("damage", 0)) <= 0.0:
		return "none"
	if kind in ["cannon", "mortar", "spore_mother", "steam_walker", Defs.PENDULUM] or d.has("splash") or d.get("cone", false):
		return "area"
	if kind == "dismounted":
		return "melee"            # (the sabre; the pistol is a special)
	return "ranged" if float(d.get("range", 0)) >= 100.0 else "melee"


static func _strike_time(kind: String) -> float:
	if Defs.FLYER.has(kind):
		return float(Defs.FLYER[kind]["strike"])
	if kind == Defs.PENDULUM:
		return float(Defs.PENDULUM_SWING["strike"])
	if kind == Defs.NETTER:
		return float(Defs.NET["strike"])
	return STRIKE


static func _vet(kills: int) -> float:
	return 1.0 + minf(kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"]))


## Everything the row and its tooltips show, from a state (of_unit / of_kind): {chips, specials, dps, range, type}.
## A chip: {icon, text, title, stats, body, col?}; a special: {name, line}.
static func build(st: Dictionary) -> Dictionary:
	var kind: String = st["kind"]
	var d: Dictionary = st["d"]
	var base: Dictionary = st["base"]
	var chips: Array = []
	var specials: Array = []
	var typ := attack_type(kind, d)
	var rooted: bool = st["rooted"]
	var dps := 0.0
	var rng := 0.0
	# ---- the main weapon: damage a hit, aim + strike + reload, reach
	var dmg := float(d.get("damage", 0))
	var bdmg := float(base.get("damage", 0))
	var aim := float(d.get("aim", 0.25))
	var cd := float(d.get("cooldown", 1.0))
	var bcd := float(base.get("cooldown", 1.0))
	var reach := float(d.get("range", 0))
	var breach := float(base.get("range", 0))
	var why: Array = []           # what makes the damage differ from the trained value
	var cwhy: Array = []          # ...and the reload
	if kind == "dragoon":
		var m: Dictionary = Defs.UNITS["musketeer"]
		dmg = float(m["damage"])
		bdmg = dmg
		aim = float(m.get("aim", 0.25))
		bcd = float(m["cooldown"]) * float(Defs.HORSES["dragoon_reload"])
		cd = bcd
		if Defs.RESEARCH.has(st["lock"]):
			cd *= float(Defs.RESEARCH[st["lock"]]["reload"])
			cwhy.append(Loc.t("%s: reload x%.2f") % [Loc.t(String(Defs.RESEARCH[st["lock"]]["name"])), float(Defs.RESEARCH[st["lock"]]["reload"])])
	elif kind == "dismounted":
		var sab: Dictionary = d["sabre"]
		dmg = float(sab["damage"])
		bdmg = dmg
		cd = float(sab["cooldown"])
		bcd = cd
		aim = float(Defs.BAYONET["aim"])
		reach = float(Defs.BAYONET["range"])
		breach = reach
	elif kind == "musketeer":
		if Defs.RESEARCH.has(st["lock"]):
			cd *= float(Defs.RESEARCH[st["lock"]]["reload"])
			cwhy.append(Loc.t("%s: reload x%.2f") % [Loc.t(String(Defs.RESEARCH[st["lock"]]["name"])), float(Defs.RESEARCH[st["lock"]]["reload"])])
		if st["auto_mount"]:
			cd *= float(Defs.HORSES["dragoon_reload"])
			cwhy.append(Loc.t("a Dragoon on foot: reload x%.1f") % float(Defs.HORSES["dragoon_reload"]))
	if kind in ["cannon", "mortar"] and not is_equal_approx(cd, bcd):
		cwhy.append(Loc.t("Prepared Charges: reload x%.1f") % (cd / bcd))
	if st["overload"]:
		cd *= float(Defs.OVERLOAD["cooldown"])
		cwhy.append(Loc.t("OVERLOADED: reload x%.2f") % float(Defs.OVERLOAD["cooldown"]))
	if st["shield"]:
		cd *= float(Defs.SHIELD_WALL["cooldown"])
		cwhy.append(Loc.t("SHIELD FORWARD: reload x%.2f") % float(Defs.SHIELD_WALL["cooldown"]))
	var vet := _vet(int(st["kills"]))
	if vet > 1.0:
		dmg *= vet
		why.append(Loc.t("veterancy +%d%% (%d kills)") % [int(round((vet - 1.0) * 100.0)), int(st["kills"])])
	if float(st["wind"]) < 0.999:
		var wm := lerpf(0.7, 1.0, float(st["wind"]))
		dmg *= wm
		why.append(Loc.t("wound %d%%: x%.2f") % [int(round(float(st["wind"]) * 100.0)), wm])
	if st["overload"]:
		dmg *= float(Defs.OVERLOAD["damage"])
		why.append(Loc.t("OVERLOADED x%.1f") % float(Defs.OVERLOAD["damage"]))
	elif st["overcharge"]:
		dmg *= float(Defs.OVERCHARGE["damage"])
		why.append(Loc.t("OVERCHARGED x%.2f") % float(Defs.OVERCHARGE["damage"]))
	var cycle := aim + _strike_time(kind) + cd
	var bcycle := float(base.get("aim", 0.25)) + _strike_time(kind) + bcd
	if kind == "dragoon":
		bcycle = aim + STRIKE + bcd
	elif kind == "dismounted":
		bcycle = cycle
	var can_fight := typ != "none"
	var blocked := ""             # it can't attack right now: why
	if can_fight and rooted:
		blocked = "Rooted: it cannot attack. UPROOT it to fight."
	elif can_fight and kind == "spore_mother" and st["deploy"] != "deployed":
		blocked = "Walking: she cannot attack. ROOT her to lob spit blobs."
	elif can_fight and kind in ["cannon", "mortar", "tesla_cart"] and st["deploy"] != "deployed":
		blocked = {"cannon": "Limbered: UNLIMBER to fire.", "mortar": "Packed: DEPLOY to fire.", "tesla_cart": "Packed: DEPLOY to fight."}[kind]
	elif can_fight and kind == "skywing" and st["sky"] != "air" and st["sky"] != "ground":
		blocked = "Landing or taking off: it cannot attack."
	if can_fight:
		dps = dmg / maxf(cycle, 0.05)
		rng = reach / Defs.TILE
		var hits := _hits(kind, d)
		var ttl: String = {"melee": "Melee attack", "ranged": "Ranged attack", "area": "Area attack"}[typ]
		var stats := Loc.t("%s damage a hit") % _num(dmg)
		if not is_equal_approx(dmg, bdmg):
			stats += "  ·  " + Loc.t("trained: %s") % _num(bdmg)
		var body := _attack_text(kind, d)
		if not why.is_empty():
			body = Loc.t("Now: %s.") % ", ".join(why) + ("\n" + body if body != "" else "")
		body += ("\n" if body != "" else "") + Loc.t("Hits: %s.") % ", ".join(hits.map(func(x: String) -> String: return Loc.t(x)))
		if blocked != "":
			chips.append({"icon": "no_attack", "text": Loc.t("ROOTED") if rooted else Loc.t("OFF"), "title": "Cannot attack now",
				"stats": Loc.t(blocked), "body": Loc.t("When it fights: %s damage a hit, every %.1f s (%.1f a second), %.1f tiles.") % [_num(dmg), cycle, dps, rng], "col": LOW})
		else:
			chips.append({"icon": typ, "text": _num(dmg), "title": ttl, "stats": stats, "body": body, "col": _col(dmg, bdmg)})
			var aps := 1.0 / maxf(cycle, 0.05)
			var cbody := Loc.t("Aim %.2f s + blow %.2f s + reload %.2f s: %.2f attacks a second.") % [aim, _strike_time(kind), cd, aps]
			if not cwhy.is_empty():
				cbody = Loc.t("Now: %s.") % ", ".join(cwhy) + "\n" + cbody
			chips.append({"icon": "attack_speed", "text": "%.1fs" % cycle, "title": "Attack speed",
				"stats": Loc.t("One attack every %.1f s") % cycle + ("  ·  " + Loc.t("trained: %.1f s") % bcycle if absf(cycle - bcycle) > 0.01 else ""),
				"body": cbody, "col": _col(bcycle, cycle)})
			chips.append({"icon": "dps", "text": _num(dps), "title": "Damage a second",
				"stats": Loc.t("%.1f damage a second") % dps,
				"body": Loc.t("Damage a hit / time between attacks, on one target with no armour (armour takes its value off every hit).") \
					+ ("\n" + Loc.t("Every enemy in its blow takes this.") if typ == "area" else "")})
			var rbody := ""
			if float(d.get("min_range", 0)) > 0.0:
				rbody = Loc.t("Nothing closer than %.1f tiles.") % (float(d["min_range"]) / Defs.TILE)
			if kind in ["cannon", "mortar"] and reach > breach:
				rbody += (" " if rbody != "" else "") + Loc.t("Gunner's Quadrant: +%.1f tiles.") % ((reach - breach) / Defs.TILE)
			if typ == "melee":
				rbody += (" " if rbody != "" else "") + Loc.t("Melee: it must close in.")
			chips.append({"icon": "range", "text": "%.1f" % rng, "title": "Range",
				"stats": Loc.t("%.1f tiles (%d px)") % [rng, int(reach)], "body": rbody, "col": _col(reach, breach)})
			# bonuses
			for bn in _bonuses(kind, d):
				chips.append(bn)
			if "air" in hits:
				chips.append({"icon": "hits_air", "text": "", "title": "Hits flyers",
					"stats": Loc.t("Hits: %s.") % ", ".join(hits.map(func(x: String) -> String: return Loc.t(x))),
					"body": Loc.t("Canister only: round shot cannot hit flyers.") if kind == "cannon" else ""})
	else:
		var nb := Loc.t("No weapon.")
		if d.get("medic", false):
			nb = Loc.t("No weapon: he heals.")
		elif Defs.is_worker(kind):
			nb = Loc.t("No weapon.")
		chips.append({"icon": "no_attack", "text": "", "title": "Cannot attack", "stats": nb, "body": ""})
	# ---- defence and the rest
	chips.append(_armour_chip(float(st["armor"]) + (float(Defs.NB["root_armor"]) if st["dug"] else 0.0) - (2.0 if st["acid"] else 0.0), float(base["armor"]), _armour_why(st), kind, float(base["armor"])))
	var hp_txt := "%d" % int(st["max_hp"])
	chips.append({"icon": "health", "text": hp_txt, "title": "Health", "stats": "%d / %d" % [int(ceil(float(st["hp"]))), int(st["max_hp"])],
		"body": (Loc.t("Trained: %d.") % int(base["hp"])) if int(base["hp"]) != int(st["max_hp"]) else "", "col": _col(float(st["max_hp"]), float(base["hp"])), "low": true})
	var spd := float(st["speed"])
	var bspd := float(base["speed"])
	var sbody := Loc.t("%d px a second (a tile is %d px).") % [int(spd), Defs.TILE]
	if st["shield"]:
		spd *= float(Defs.SHIELD_WALL["speed"])
		sbody += " " + Loc.t("SHIELD FORWARD: x%.1f.") % float(Defs.SHIELD_WALL["speed"])
	if rooted:
		chips.append({"icon": "speed", "text": "0", "title": "Speed", "stats": Loc.t("Rooted: it cannot move."),
			"body": Loc.t("Uprooted: %.1f tiles a second.") % (bspd / Defs.TILE), "col": LOW})
	elif bspd > 0.0:
		chips.append({"icon": "speed", "text": "%.1f" % (spd / Defs.TILE), "title": "Speed",
			"stats": Loc.t("%.1f tiles a second") % (spd / Defs.TILE), "body": sbody, "col": _col(spd, bspd)})
	chips.append({"icon": "sight", "text": "%d" % int(st["sight"]), "title": "Sight", "stats": Loc.t("%d tiles") % int(st["sight"]),
		"body": Loc.t("How far it sees."), "low": true})
	var sup := int(d.get("supply", 0))
	var sup_body := ""
	if kind == BroodNew.TURTLE:
		sup_body = Loc.t("Rooted, it gives %d supply.") % int(Defs.NB["turtle_supply"])
	elif kind == BroodNew.QUEEN:
		sup_body = Loc.t("She gives %d supply.") % int(Defs.NB["queen_supply"])
	if int(d.get("spawn", 1)) > 1:
		sup_body += (" " if sup_body != "" else "") + Loc.t("%d hatch from one egg: the numbers are for each one.") % int(d["spawn"])
	chips.append({"icon": "supply", "text": "%d" % sup, "title": "Supply", "stats": Loc.t("Takes %d supply") % sup, "body": sup_body, "low": true})
	specials = _specials(kind, d, st)
	return {"chips": chips, "specials": specials, "dps": dps, "range": rng, "type": typ, "kind": kind, "cycle": cycle if can_fight else 0.0}


static func _num(v: float) -> String:
	if absf(v - round(v)) < 0.05:
		return "%d" % int(round(v))
	return "%.1f" % v


static func _col(now: float, trained: float) -> Variant:
	if absf(now - trained) < 0.01:
		return null
	return HI if now > trained else LOW


static func _armour_chip(now: float, trained: float, why: Array, kind: String, _b: float) -> Dictionary:
	var body := Loc.t("Every hit loses this much damage (a hit always does at least 1).")
	if not why.is_empty():
		body = Loc.t("Now: %s.") % ", ".join(why) + "\n" + body
	if BroodNew.ROOTERS.has(kind):
		body += "\n" + Loc.t("Rooted: +%d armour, then a quarter less damage.") % int(Defs.NB["root_armor"])
	return {"icon": "armour", "text": _num(now), "title": "Armour",
		"stats": Loc.t("Armour %s") % _num(now) + ("  ·  " + Loc.t("trained: %s") % _num(trained) if absf(now - trained) > 0.01 else ""),
		"body": body, "col": _col(now, trained)}


static func _armour_why(st: Dictionary) -> Array:
	var w: Array = []
	if st["armoured"]:
		w.append(Loc.t("Armour refit +%d") % int(Defs.ARMOURED[st["kind"]]["armor"]))
	if st["dug"]:
		w.append(Loc.t("rooted +%d, and it takes %d%% of each hit") % [int(Defs.NB["root_armor"]), int(round(float(Defs.NB["root_taken"]) * 100.0))])
	if st["shield"]:
		w.append(Loc.t("SHIELD FORWARD +%d, half from shots in front") % int(Defs.SHIELD_WALL["armor"]))
	if st["acid"]:
		w.append(Loc.t("acid -2"))
	return w


## What it can hit: ground, flyers, buildings.
static func _hits(kind: String, d: Dictionary) -> Array:
	var out: Array = []
	var air_only := bool(d.get("air_only", false))
	if not air_only:
		out.append("ground")
	if (bool(d.get("anti_air", false)) and not bool(d.get("ground_only", false))) or kind == "cannon":
		out.append("air")
	if not air_only and kind != Defs.NETTER:
		out.append("buildings")
	return out


## Bonus chips: against armour, against buildings, against flyers, against light units or named kinds.
static func _bonuses(kind: String, d: Dictionary) -> Array:
	var out: Array = []
	var armd := 0.0
	if kind == "cannon":
		armd = float(Defs.ROUND_SHOT["vs_armored"])
	elif kind == Defs.BALLISTA_KIND:
		armd = float(Defs.BALLISTA["vs_armored"])
	if armd > 1.0:
		out.append({"icon": "vs_armoured", "text": "x%s" % _num(armd), "title": "Bonus vs armoured",
			"stats": Loc.t("x%s damage against armoured units") % _num(armd), "body": ""})
	var bb := float(d.get("building_bonus", 1.0))
	if bb > 1.0:
		out.append({"icon": "vs_buildings", "text": "x%s" % _num(bb), "title": "Bonus vs buildings",
			"stats": Loc.t("x%s damage against buildings") % _num(bb), "body": ""})
	var light := 0.0
	if kind == Defs.PENDULUM:
		light = float(Defs.PENDULUM_SWING["vs_light"])
	if light > 1.0:
		out.append({"icon": "vs_light", "text": "x%s" % _num(light), "title": "Bonus vs light",
			"stats": Loc.t("x%s damage against light units") % _num(light), "body": ""})
	if float(d.get("vs_air", 1.0)) > 1.0:
		out.append({"icon": "hits_air", "text": "x%s" % _num(float(d["vs_air"])), "title": "Bonus vs flyers",
			"stats": Loc.t("x%s damage against flyers") % _num(float(d["vs_air"])), "body": ""})
	var bk: Dictionary = d.get("bonus", {})
	if not bk.is_empty():
		var parts: Array = []
		for k in bk:
			parts.append(Loc.t("x%s against %s") % [_num(float(bk[k])), Loc.t(String(Defs.UNITS[k]["name"])) if Defs.UNITS.has(k) else k])
		out.append({"icon": "vs_armoured", "text": "x%s" % _num(float(bk.values().max())), "title": "Bonus damage",
			"stats": ", ".join(parts), "body": ""})
	return out


## The main weapon in one line (the attack chip's tooltip).
static func _attack_text(kind: String, d: Dictionary) -> String:
	match kind:
		"musketeer", "dragoon":
			return Loc.t("A musket ball at one enemy, ground or air.") + (" " + Loc.t("He gets off his horse to fire, and back on to move.") if kind == "dragoon" else "")
		"cuirassier", "dismounted":
			return Loc.t("The sabre.")
		"cannon":
			return Loc.t("Round shot: the ball goes on through the line behind where it lands, with a little splash.")
		"mortar":
			return Loc.t("A shell lobbed high over men and walls: it bursts where it lands, friends too.")
		"spore_mother":
			return Loc.t("A big spit blob that splashes a whole area.")
		"steam_walker":
			return Loc.t("Scalding steam: everything in front of it.")
		Defs.PENDULUM:
			return Loc.t("Each blow cuts EVERY enemy on the ground in the arc in front of it.")
		Defs.BALLISTA_KIND:
			return Loc.t("A giant screw bolt in a straight line.")
		Defs.NETTER:
			return Loc.t("A weighted chain net at one enemy unit.")
	return ""


## The special attacks and abilities, a line each.
static func _specials(kind: String, d: Dictionary, st: Dictionary) -> Array:
	var s: Array = []
	var add := func(n: String, line: String) -> void: s.append({"name": n, "line": line})
	match kind:
		"musketeer", "dragoon":
			var bd := float(Defs.BAYONET["damage"]) + (float(Defs.RESEARCH["bayonet"]["damage"]) if st["bayonet"] else 0.0)
			var bc := float(Defs.BAYONET["cooldown"]) * (float(Defs.RESEARCH["bayonet"]["cooldown"]) if st["bayonet"] else 1.0)
			add.call("BAYONET", Loc.t("Up close (and when his powder runs dry): %s damage every %.1f s; x2 against cannons, x1.5 against Cuirassiers. Not at flyers.") % [_num(bd * _vet(int(st["kills"]))), bc + float(Defs.BAYONET["aim"]) + STRIKE])
			add.call("POWDER", Loc.t("Carries %d shots (%d with the Shot Pouch); refills near a Mill, Barracks, Town Hall or Powder Wagon.") % [int(Defs.POWDER["musketeer"]), int(Defs.POWDER["pouch"])])
		"cuirassier", "dismounted":
			add.call("PISTOL", Loc.t("One loaded shot: %d damage at %.1f tiles, ground units only. He reloads on foot (%d s).") % [int(Defs.PISTOL["damage"]), float(Defs.PISTOL["range"]) / Defs.TILE, int(Defs.PISTOL["reload"])])
			if kind == "cuirassier":
				add.call("CHARGE", (Loc.t("After about %d s at the gallop his next blow hits x%d and throws the enemy back.") % [int(Defs.CHARGE["run"]), int(Defs.CHARGE["mult"])]) \
					+ ("" if st["charge_tech"] else " " + Loc.t("(Needs the Cavalry Charge at the Armoury.)")))
				add.call("RIDE BY", Loc.t("He strikes in passing, on the move."))
		"cannon":
			add.call("CANISTER", Loc.t("Close range: %d damage to everything in a cone up to %.1f tiles, every %.1f s; x%s against light units; also hits flyers.") % [int(Defs.CANISTER["damage"]), float(Defs.CANISTER["range"]) / Defs.TILE, float(Defs.CANISTER["cooldown"]), _num(float(Defs.CANISTER["vs_light"]))])
			add.call("UNLIMBER", Loc.t("It fires only set up (%.1f s); limbered, the horse tows it.") % Defs.CANNON_SWITCH)
		"mortar":
			add.call("SHELL", Loc.t("Bursts over %.1f tiles round where it lands; friends are hurt too.") % (float(d.get("splash", 0)) / Defs.TILE))
			add.call("DEPLOY", Loc.t("It fires only deployed (%.1f s).") % Defs.MORTAR_SWITCH)
		"spitter":
			add.call("ACID", Loc.t("Its acid burns and strips 2 armour for %d s.") % int(d.get("acid", 3.0)))
		"brute":
			add.call("KNOCKBACK", Loc.t("Every blow throws the enemy back."))
		"spore_mother":
			add.call("ROOT", Loc.t("She fires only rooted; walking she cannot attack."))
			add.call("MIASMA", Loc.t("Spell: a cloud that heals the Brood (%d spoils, every %d s).") % [int(Defs.MIASMA["cost2"]), int(Defs.MIASMA["cooldown"])])
		"bloater":
			add.call("GAS", Loc.t("Every spit uses %d gas; out of gas it deflates and cannot attack.") % int(Defs.BLOAT["spit_cost"]))
			add.call("BURST", Loc.t("It bursts as an acid bomb (up to %d damage and a cloud), and is used up.") % int(Defs.BLOAT["burst"]))
		"skywing":
			add.call("SPINES / BITE", Loc.t("Flying it hits only flyers; LANDED it bites ground units (and anything can hit it)."))
		"mist_toad":
			add.call("FOG", Loc.t("Spell (%d energy): shots from or into the fog miss half the time.") % int(Defs.FOG["cost"]))
			add.call("TONGUE", Loc.t("Spell (%d energy): marks one enemy (a flyer too) for %d s, then drags it to the Toad; heavy units, the Brood Mother and the fathers are only staggered.") % [int(Defs.TONGUE["cost"]), int(Defs.TONGUE["windup"])])
		"stormcaller":
			add.call("STORM", Loc.t("Spell: stuns everything inside for %.1f s, friends too; no damage.") % float(Defs.STORM["time"]))
		"thresher":
			add.call("SPIN UP", Loc.t("Its saws spin up while it cuts: from %d%% to %d%% damage over %d s.") % [int(float(Defs.THRESHER["low"]) * 100), int(float(Defs.THRESHER["high"]) * 100), int(Defs.THRESHER["time"])])
			add.call("CLEAVE", Loc.t("Each blow bites %d enemies round its target too (%d%%).") % [int(Defs.THRESHER["cleave"]), int(float(Defs.THRESHER["cleave_dmg"]) * 100)])
		"tesla_cart":
			add.call("CHAIN", Loc.t("Its bolt jumps to %d more enemy at %d%%.") % [int(Defs.TESLA_CHAIN["jumps"]), int(float(Defs.TESLA_CHAIN["falloff"]) * 100)])
		Defs.SPRINGER:
			add.call("JUMP", Loc.t("A leap of up to %.1f tiles (it cannot shoot in the air).") % (float(Defs.SPRINGER_JUMP["range"]) / Defs.TILE))
		Defs.OWL:
			add.call("BOMB", Loc.t("On buildings it drops its weight: %d damage over a small area.") % int(Defs.OWL_BOMB["damage"]))
		Defs.NETTER:
			add.call("NET", Loc.t("Caught, it cannot move or fight for %d s; a flyer comes down to the ground.") % int(Defs.NET["time"]))
		Defs.BALLISTA_KIND:
			add.call("PIERCE", Loc.t("The bolt goes on through: the next enemies in line take 50% and 30%."))
			add.call("CREW", Loc.t("Each Winder aboard: +%d%% reload and speed.") % int(float(Defs.BALLISTA["per_crew"]) * 100))
		Defs.PENDULUM:
			add.call("SWEEP", Loc.t("Hits every enemy on the ground within %.1f tiles in a third of a circle.") % (float(Defs.PENDULUM_SWING["reach"]) / Defs.TILE))
		"clock_soldier":
			add.call("SHIELD FORWARD", Loc.t("+%d armour, half damage from shots in front, slower.") % int(Defs.SHIELD_WALL["armor"]) \
				+ ("" if st["shield_tech"] else " " + Loc.t("(Needs SHIELD WALL at the Light Works.)")))
		"great_winder":
			add.call("WIND / MEND / SWEEP", Loc.t("No weapon: it winds, mends and sweeps wrecks into cogs."))
	if d.get("venom", false):
		add.call("VENOM", Loc.t("Its venom strips 2 armour for %.1f s; ground units only." if d.get("ground_only", false) else "Its venom strips 2 armour for %.1f s.") % float(d.get("acid", 1.5)) \
			+ ((" " + Loc.t("Half the blow splashes on enemies within %.1f tiles of its target.") % (float(d.get("splash", 0)) / Defs.TILE)) if float(d.get("splash", 0)) > 0.0 else ""))
	if BroodMature.mature_of(kind) != "":
		var mk := BroodMature.mature_of(kind)
		add.call("MATURE", Loc.t("In the new Brood it grows into a %s (the Brood Mother at stage %d).") % [Loc.t(String(Defs.UNITS[mk]["name"])), BroodNew.unit_stage(mk) + 1])
	if BroodNew.ROOTERS.has(kind):
		add.call("ROOT", Loc.t("Rooted: +%d armour, it takes %d%% of each hit, and it cannot attack.") % [int(Defs.NB["root_armor"]), int(round(float(Defs.NB["root_taken"]) * 100.0))])
	if String(d.get("faction", "")) == "clockwork" and not Defs.is_worker(kind) and attack_type(kind, d) != "none":
		add.call("WIND", Loc.t("Its blows weaken to 70% as it runs down."))
	return s


# ------------------------------------------------------------------ the row on the card

static var _tex := {}


static func texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


## Where each chip goes in r: [[rect, chip, text]] (text: the specials' names, cut to fit; "" for a chip). Chips that
## don't fit are left out from the end (the low ones first: health, sight, supply); the specials' names take what is
## left. A narrower row (a phone) shows fewer chips; nothing goes past r's right edge.
static func layout(s: Dictionary, r: Rect2, fsz := 14) -> Array:
	var out: Array = []
	var chips: Array = s["chips"]
	var bold := UiStyle.bold_font()
	var ws: Array = []
	for c in chips:
		ws.append(_chip_w(c, bold, fsz))
	var keep: Array = []
	keep.resize(chips.size())
	keep.fill(true)
	var total := 0.0
	for w in ws:
		total += float(w) + GAP
	for pass_low in [true, false]:
		for i in range(chips.size() - 1, -1, -1):
			if total - GAP <= r.size.x:
				break
			if keep[i] and (bool(chips[i].get("low", false)) == pass_low):
				keep[i] = false
				total -= float(ws[i]) + GAP
	var x := r.position.x
	for i in chips.size():
		if not keep[i]:
			continue
		out.append([Rect2(x, r.position.y, ws[i], r.size.y), chips[i], ""])
		x += float(ws[i]) + GAP
	var sp: Array = s["specials"]
	var font := UiStyle.body_font()
	if not sp.is_empty() and r.end.x - x > 40.0:
		var txt := " · ".join(sp.map(func(e: Dictionary) -> String: return Loc.t(String(e["name"]))))
		var room := r.end.x - x - 4.0
		while txt.length() > 3 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz - 1).x > room:
			txt = txt.left(txt.length() - 2).strip_edges() + "…"
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz - 1).x
		out.append([Rect2(x, r.position.y, minf(tw + 4.0, r.end.x - x), r.size.y), {"specials": sp, "icon": "", "title": ""}, txt])
	return out


const GAP := 5.0


## Draws the row in r; returns layout()'s list (the chips' rects, for the tooltips).
static func draw_row(ci: CanvasItem, r: Rect2, s: Dictionary, fsz := 14) -> Array:
	var bold := UiStyle.bold_font()
	var cy := r.position.y + r.size.y * 0.5
	var lay := layout(s, r, fsz)
	for e in lay:
		var cr: Rect2 = e[0]
		var c: Dictionary = e[1]
		if c.has("specials"):
			ci.draw_string(UiStyle.body_font(), Vector2(cr.position.x + 2.0, cy + (fsz - 1) * 0.36), String(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz - 1, Color(1.0, 0.85, 0.5))
			continue
		ci.draw_rect(cr, Color(0, 0, 0, 0.32))
		ci.draw_rect(cr, Color(UiStyle.TRIM_DIM, 0.35), false, 1.0)
		var tx := cr.position.x + 4.0
		if String(c["icon"]) != "":
			draw_icon(ci, String(c["icon"]), Rect2(cr.position.x + 3.0, cy - ICON * 0.5, ICON, ICON))
			tx += ICON + 3.0
		if String(c["text"]) != "":
			var col: Color = c["col"] if c.get("col") != null else UiStyle.TEXT
			ci.draw_string(bold, Vector2(tx, cy + fsz * 0.36), String(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
	return lay


static func _chip_w(c: Dictionary, bold: Font, fsz: int) -> float:
	var w := 6.0
	if String(c["icon"]) != "":
		w += ICON + 3.0
	if String(c["text"]) != "":
		w += bold.get_string_size(String(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + 2.0
	return w


## The tooltip of a chip of draw_row ({title, stats, body}).
static func tip(c: Dictionary) -> Dictionary:
	if c.has("specials"):
		var lines: Array = (c["specials"] as Array).map(func(e: Dictionary) -> String: return "%s: %s" % [Loc.t(String(e["name"])), String(e["line"])])
		return {"title": "Special attacks and abilities", "stats": "", "body": "\n".join(lines)}
	return {"title": String(c["title"]), "stats": String(c.get("stats", "")), "body": String(c.get("body", ""))}


# ------------------------------------------------------------------ fallback icons (a missing assets/ui/stats file)

const INK := Color(0.93, 0.88, 0.74)
const INK_DIM := Color(0.93, 0.88, 0.74, 0.45)


## The icon `name` in rect r: the cut sheet's picture if there is one, else a simple drawing.
static func draw_icon(ci: CanvasItem, name: String, r: Rect2) -> void:
	var tex := texture(name)
	if tex:
		ci.draw_texture_rect(tex, r, false)
		return
	var c := r.get_center()
	var k := r.size.x / 16.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
	var w := 1.6 * k
	match name:
		"melee":
			ci.draw_line(P.call(-5, 5), P.call(5, -5), INK, w)                     # a blade
			ci.draw_line(P.call(-6, 1), P.call(-1, 6), Color(0.85, 0.65, 0.3), w)  # its guard
			ci.draw_line(P.call(-7, 7), P.call(-5, 5), Color(0.85, 0.65, 0.3), w)
		"ranged":
			ci.draw_circle(P.call(4, 0), 2.6 * k, INK)                              # a ball
			for i in 3:
				ci.draw_line(P.call(-7, -3 + i * 3), P.call(-1, -3 + i * 3), INK_DIM, 1.0 * k)
		"area":
			ci.draw_circle(c, 2.6 * k, Color(1.0, 0.7, 0.3))                        # a burst
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * 4.0 * k, c + Vector2.from_angle(a) * 7.0 * k, INK, 1.2 * k)
		"range":
			ci.draw_line(P.call(-7, 0), P.call(7, 0), INK, w)                       # <-->
			ci.draw_line(P.call(-7, 0), P.call(-4, -3), INK, w)
			ci.draw_line(P.call(-7, 0), P.call(-4, 3), INK, w)
			ci.draw_line(P.call(7, 0), P.call(4, -3), INK, w)
			ci.draw_line(P.call(7, 0), P.call(4, 3), INK, w)
		"attack_speed":
			ci.draw_arc(c, 6.5 * k, 0, TAU, 20, INK, 1.3 * k)                       # a clock
			ci.draw_line(c, P.call(0, -4.5), INK, 1.3 * k)
			ci.draw_line(c, P.call(3, 1), INK, 1.3 * k)
		"armour", "vs_armoured":
			var sh := PackedVector2Array([P.call(-6, -6), P.call(6, -6), P.call(6, 0), P.call(0, 7), P.call(-6, 0)])
			if name == "armour":
				ci.draw_colored_polygon(sh, Color(0.55, 0.62, 0.72))
				ci.draw_polyline(sh + PackedVector2Array([sh[0]]), INK, 1.0 * k)
			else:
				ci.draw_polyline(sh + PackedVector2Array([sh[0]]), INK, 1.2 * k)       # a shield with a blow through it
				ci.draw_line(P.call(-7, 7), P.call(7, -7), Color(1.0, 0.55, 0.4), w)
		"health":
			ci.draw_rect(Rect2(P.call(-2, -6), Vector2(4, 12) * k), Color(0.45, 0.85, 0.4))
			ci.draw_rect(Rect2(P.call(-6, -2), Vector2(12, 4) * k), Color(0.45, 0.85, 0.4))
		"speed":
			for dx in [-5.0, 0.0]:                                                 # >>
				ci.draw_line(P.call(dx, -5), P.call(dx + 5, 0), INK, w)
				ci.draw_line(P.call(dx + 5, 0), P.call(dx, 5), INK, w)
		"sight":
			var eye := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				eye.append(P.call(-7 * cos(a), -4 * sin(a)))
			for i in range(1, 12):
				var a := PI * i / 12.0
				eye.append(P.call(7 * cos(a), 4 * sin(a)))
			eye.append(eye[0])
			ci.draw_polyline(eye, INK, 1.2 * k)
			ci.draw_circle(c, 2.2 * k, INK)
		"vs_buildings":
			var hs := PackedVector2Array([P.call(-6, 6), P.call(-6, -1), P.call(0, -6), P.call(6, -1), P.call(6, 6), P.call(-6, 6)])
			ci.draw_polyline(hs, INK, 1.2 * k)                                     # a house with a blow through it
			ci.draw_line(P.call(-7, 7), P.call(7, -7), Color(1.0, 0.55, 0.4), w)
		"hits_air":
			ci.draw_arc(P.call(-3, 1), 3.5 * k, PI * 1.1, PI * 1.9, 8, INK, 1.3 * k)   # a bird
			ci.draw_arc(P.call(3, 1), 3.5 * k, PI * 1.1, PI * 1.9, 8, INK, 1.3 * k)
			ci.draw_line(P.call(0, 7), P.call(0, 3), INK_DIM, 1.0 * k)
		"supply":
			ci.draw_circle(P.call(0, -3.5), 2.6 * k, INK)                           # a head and shoulders
			ci.draw_arc(P.call(0, 7), 6.0 * k, PI * 1.05, PI * 1.95, 10, INK, 2.0 * k)
		"no_attack":
			ci.draw_arc(c, 6.5 * k, 0, TAU, 20, Color(1.0, 0.5, 0.4), 1.5 * k)
			ci.draw_line(P.call(-4.6, 4.6), P.call(4.6, -4.6), Color(1.0, 0.5, 0.4), 1.5 * k)
		_:
			ci.draw_circle(c, 3.0 * k, INK_DIM)
