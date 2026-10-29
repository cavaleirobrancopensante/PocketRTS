class_name BroodResearch
extends RefCounted
## THE BROOD'S RESEARCH (the owner, 2026-10-29 18:31 and 18:59; docs/brood_research.md). The Brood has no buildings, so
## its rooted creatures research: each SIRE his own line's upgrades while rooted on his nest, the BROOD MOTHER the
## Brood-wide ones. The research is Defs.RESEARCH with "at" = the creature's kind ("faction": "brood"); when done it is a
## tech flag in players[t]["tech"] as the Crown's and the Clockwork's (saved, sent online and kept in replays with the
## players). The research in hand lives on the creature (nb "rs": its key, "rs_t": seconds done), so saves, snapshots and
## replays carry it with the creature.
##  - one at a time each; paid up front; the creature must be ROOTED (the Mother: not while she grows, nor grow while she
##    researches);
##  - a SIRE researching fathers NO eggs: the Mother can't lay an egg of his line meanwhile (lay_problem) and the eggs
##    already in his nest wait (their 25 s count holds); his fertilising loop keeps playing (BroodNew.producing), so a
##    scout sees him busy. The Mother keeps laying while she researches (Claude's choice);
##  - UPROOTED (UPROOT, a tongue, anything) or STOP RESEARCH: it stops, paid back in full; KILLED: the research in hand is
##    lost and paid back, as a building's queue is when it falls (Building.die); research already done stays.
## Effects (applied where the stat is read): BIGGER CLUTCH (clutch, egg_price), speed (speed_add, Unit tick), range and
## building bonus (apply, on the unit's own copy of its stats, from Game.apply_drills), Quick Roots (root_mult, Unit.switch_time),
## Swamp Mending (mend, the Unit's swamp healing).

const BAR := Color(0.55, 0.9, 0.85)        # (a research's bar: teal, apart from her growing's violet)


## Every Brood research key, in the order of Defs.RESEARCH.
static func keys() -> Array:
	var out: Array = []
	for k in Defs.RESEARCH:
		if String(Defs.RESEARCH[k].get("faction", "")) == "brood":
			out.append(k)
	return out


## The research a creature of this kind can do (a Sire's line, the Mother's).
static func keys_at(kind: String) -> Array:
	return keys().filter(func(k) -> bool: return String(Defs.RESEARCH[k]["at"]) == kind)


static func has(g: Game, t: int, key: String) -> bool:
	return g != null and t >= 0 and t < g.players.size() and g.has_tech(t, key)


## The research this creature has in hand ("" for none).
static func current(u: Unit) -> String:
	return String(u.nb.get("rs", "")) if u != null and u.nb != null else ""


static func busy(u: Unit) -> bool:
	return u != null and not u.dead and u.nb.has("rs")


## Is this side's research `key` in hand anywhere?
static func in_hand(g: Game, t: int, key: String) -> bool:
	for u in g.units:
		if u.team == t and not u.dead and String(u.nb.get("rs", "")) == key:
			return true
	return false


## Is the Sire of this line (k: the young or warrior kind, or the Sire's own kind) researching now?
static func line_busy(g: Game, t: int, k: String) -> bool:
	var fk := k if BroodNew.is_father(k) else BroodNew.father_of(k)
	if fk == "":
		return false
	return busy(BroodNew.father(g, t, fk))


# ------------------------------------------------------------------ BIGGER CLUTCH

## The research that makes `young` three to an egg ("" for none).
static func clutch_key(young: String) -> String:
	if _ck.is_empty():
		for k in keys():
			if Defs.RESEARCH[k].has("young"):
				_ck[String(Defs.RESEARCH[k]["young"])] = k
		_ck["-"] = ""
	return String(_ck.get(young, ""))


static var _ck := {}


## A young kind's young per egg (Defs "spawn"; a kind not in the game yet: 2), one more with its BIGGER CLUTCH.
static func base_clutch(k: String) -> int:
	return int(Defs.UNITS[k].get("spawn", 1)) if Defs.UNITS.has(k) else 2


static func clutch(g: Game, t: int, k: String) -> int:
	var n := base_clutch(k)
	var ck := clutch_key(k)
	if ck != "" and has(g, t, ck):
		n += 1
	return n


## The price of an egg of `n` young of kind k: the price per young (Defs: cost / spawn) times n, so a bigger clutch
## costs more and each young the same. [food, spoils] (spoils rounded: a Spitter's 2.5 each is 5 for two, 8 for three).
static func egg_price(k: String, n: int) -> Array:
	var u: Dictionary = Defs.UNITS[k]
	var s := maxf(1.0, float(u.get("spawn", 1)))
	return [int(round(float(u["cost"]) * n / s)), int(round(float(u.get("cost2", 0)) * n / s))]


# ------------------------------------------------------------------ the other effects

## Speed added to this unit by its side's research (px/s); the flyers' only while flying.
static func speed_add(u: Unit) -> float:
	var add := 0.0
	for k in _speed_keys(u.kind):
		if has(u.game, u.team, k):
			var info: Dictionary = Defs.RESEARCH[k]
			if bool(info.get("air", false)) and not u.is_air():
				continue
			add += float(info["speed"][u.kind])
	return add


static var _sk := {}


static func _speed_keys(kind: String) -> Array:
	if _sk.is_empty():
		for k in keys():
			for uk in (Defs.RESEARCH[k].get("speed", {}) as Dictionary):
				if not _sk.has(uk):
					_sk[uk] = []
				_sk[uk].append(k)
		_sk["-"] = []
	return _sk.get(kind, [])


## On the unit's own copy of its stats (Game.apply_drills: every new unit, a matured one, and when research is done):
## LONG SPIT's range, BATTERING HORNS' building bonus.
static func apply(g: Game, u: Unit) -> void:
	if u.team < 0 or u.team >= g.players.size() or not Defs.UNITS.has(u.kind) or String(Defs.UNITS[u.kind].get("faction", "")) != "brood":
		return
	for k in keys():
		var info: Dictionary = Defs.RESEARCH[k]
		var rg: Dictionary = info.get("range", {})
		var bb: Dictionary = info.get("bonus", {})
		if not rg.has(u.kind) and not bb.has(u.kind):
			continue
		if is_same(u.d, Defs.UNITS[u.kind]):
			u.d = u.d.duplicate(true)       # (its own copy: Defs stay as they are)
		var on := g.has_tech(u.team, k)
		if rg.has(u.kind):
			u.d["range"] = float(Defs.UNITS[u.kind]["range"]) + (float(rg[u.kind]) if on else 0.0)
		if bb.has(u.kind):
			u.d["building_bonus"] = float(bb[u.kind]) if on else float(Defs.UNITS[u.kind].get("building_bonus", 1.0))


## QUICK ROOTS: its ROOT and UPROOT time x this.
static func root_mult(u: Unit) -> float:
	if u.game != null and has(u.game, u.team, "nb_quick_roots"):
		return float(Defs.RESEARCH["nb_quick_roots"]["root"])
	return 1.0


## SWAMP MENDING: the hp a second it heals more (on its side's swamp: the caller looks), not hit for "calm" s.
static func mend(u: Unit) -> float:
	if not has(u.game, u.team, "nb_swamp_mending"):
		return 0.0
	var info: Dictionary = Defs.RESEARCH["nb_swamp_mending"]
	if u.game.clock - u.hit_clock < float(info["calm"]):
		return 0.0
	return clampf(u.max_hp * float(info["heal"]), float(info["heal_min"]), float(info["heal_max"]))


# ------------------------------------------------------------------ researching

## Why this creature can't start `key` now ("" = it can).
static func problem(g: Game, u: Unit, key: String) -> String:
	if not Defs.RESEARCH.has(key):
		return "Can't research that here."
	var info: Dictionary = Defs.RESEARCH[key]
	if u == null or u.dead or u.kind != String(info["at"]):
		return "Can't research that here."
	var t := u.team
	if g.has_tech(t, key):
		return "Already done."
	if busy(u):
		return "Already researching: one at a time."
	if in_hand(g, t, key):
		return "Already being researched."
	if not BroodNew.rooted(u):
		return "She must be rooted to research." if u.kind == BroodNew.QUEEN else "He must be rooted on his nest to research."
	if u.kind == BroodNew.QUEEN and float(u.nb.get("grow_t", 0.0)) > 0.0:
		return "She is growing."
	var q := BroodNew.queen(g, t)
	if q == null or BroodNew.stage(q) < int(info.get("stage", 0)):
		return "Needs the Brood Mother at stage %d." % (int(info.get("stage", 0)) + 1)
	var y := String(info.get("young", ""))
	if y != "" and not Defs.UNITS.has(y):
		return "Not in the Brood yet."
	var res: Array = Defs.FACTIONS["brood"]["res"]
	if int(g.players[t]["gold"]) < int(info["cost"]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(g.players[t]["res2"]) < float(info.get("cost2", 0)):
		return "Not enough %s." % String(res[1]).to_lower()
	return ""


## Start it: paid now, then "time" s rooted.
static func start(g: Game, u: Unit, key: String) -> String:
	var why := problem(g, u, key)
	if why != "":
		return why
	var info: Dictionary = Defs.RESEARCH[key]
	g.players[u.team]["gold"] -= int(info["cost"])
	g.add_res2(u.team, -float(info.get("cost2", 0)))
	g.stats[u.team]["spent"] += int(info["cost"])
	u.nb["rs"] = key
	u.nb["rs_t"] = 0.0
	if g.mlog:
		g.mlog.add("%s's %s researches %s" % [g.mlog.who(u.team), u.d["name"], info["name"]])
	if u.team == g.human:
		Sfx.play_any(["research", "work/grub_deliver"], u.position, -6.0)
	return ""


## Stopped (STOP RESEARCH, uprooted, killed): all of it paid back; why: "stop", "up" or "dead".
static func stop(g: Game, u: Unit, why := "stop") -> void:
	var key := current(u)
	if key == "" or not Defs.RESEARCH.has(key):
		u.nb.erase("rs")
		u.nb.erase("rs_t")
		return
	var info: Dictionary = Defs.RESEARCH[key]
	u.nb.erase("rs")
	u.nb.erase("rs_t")
	if u.team < 0 or u.team >= g.players.size():
		return
	g.players[u.team]["gold"] += int(info["cost"])
	g.add_res2(u.team, float(info.get("cost2", 0)))
	g.stats[u.team]["spent"] -= int(info["cost"])
	var who := Loc.t(String(u.d["name"]))
	var what := Loc.t(String(info["name"]))
	match why:
		"up":
			g.tell(u.team, Loc.t("The %s got up: research stopped (%s, paid back).") % [who, what], true)
		"dead":
			g.tell(u.team, Loc.t("The %s fell: his research is lost (%s, paid back).") % [who, what], true)
		_:
			g.tell(u.team, Loc.t("Research stopped: %s, paid back.") % what, true)
	if g.mlog:
		g.mlog.add("%s's %s stopped researching %s (%s)" % [g.mlog.who(u.team), u.d["name"], info["name"], why])


## Each tick of a researching creature (BroodNew.tick): got up, it stops; else it counts, and when done the side has it.
static func tick(g: Game, u: Unit, delta: float) -> void:
	if not u.nb.has("rs"):
		return
	if not BroodNew.rooted(u):
		stop(g, u, "up")
		return
	var key := current(u)
	u.nb["rs_t"] = float(u.nb.get("rs_t", 0.0)) + delta
	if float(u.nb["rs_t"]) >= float(Defs.RESEARCH[key]["time"]):
		u.nb.erase("rs")
		u.nb.erase("rs_t")
		done(g, u.team, key)


## The side has it now: the flag, and its units' own stats.
static func done(g: Game, t: int, key: String) -> void:
	g.players[t]["tech"][key] = true
	var info: Dictionary = Defs.RESEARCH[key]
	for u in g.units:
		if u.team == t and not u.dead:
			g.apply_drills(u)
	var msg := Loc.t("%s researched: %s") % [Loc.t(String(info["name"])), Loc.t(String(info["about"]))]
	if t == g.human:
		g.notify(msg, true)
		Sfx.announce(g.faction_of(t), "research_done", 3.0, "")
	elif not g.demo:
		g.tell(t, msg, true)
	if g.mlog:
		g.mlog.add("%s researched %s" % [g.mlog.who(t), info["name"]])


## WHO SEES WHAT IT RESEARCHES (the owner, 2026-10-29 20:09): its own side and its allies, and a spectator (watching
## computers play), as with the other overlays. An enemy sees only his production loop (the
## Sire's fertilising animation keeps playing): no bar, no label, nothing on his card, no tooltip, nothing on the map.
static func shown_to(g: Game, u: Unit) -> bool:
	if g == null or u == null:
		return false
	return g.demo or g.spectating() or g.allied(u.team, g.human)


## Its progress for the bar and the card (BroodNew.progress), {} when none.
static func progress(u: Unit) -> Dictionary:
	var key := current(u)
	if key == "" or not Defs.RESEARCH.has(key):
		return {}
	var tt := float(Defs.RESEARCH[key]["time"])
	var dn := float(u.nb.get("rs_t", 0.0))
	return {"label": "RESEARCHING · %s" % Defs.research_label(key), "f": clampf(dn / maxf(tt, 0.1), 0.0, 1.0), "left": maxf(0.0, tt - dn),
		"icon": String(Defs.RESEARCH[key]["icon"]), "col": BAR}


## Its tooltip: [title, body, stats].
static func tip(key: String) -> Array:
	var info: Dictionary = Defs.RESEARCH[key]
	var res: Array = Defs.FACTIONS["brood"]["res"]
	var st := "%d %s" % [int(info["cost"]), Loc.t(String(res[0]).to_lower())]
	if int(info.get("cost2", 0)) > 0:
		st += " + %d %s" % [int(info["cost2"]), Loc.t(String(res[1]).to_lower())]
	st += "  ·  %d s" % int(info["time"])
	var body := Loc.t(String(info["about"]))
	if String(info["at"]) != BroodNew.QUEEN:
		body += " " + Loc.t("While he researches he fathers no eggs of his line (the Mother can't lay them); getting up stops it (paid back).")
	else:
		body += " " + Loc.t("She keeps laying while she researches; getting up stops it (paid back).")
	return [Loc.t("Research: %s") % Loc.t(String(info["name"])), body, st]
