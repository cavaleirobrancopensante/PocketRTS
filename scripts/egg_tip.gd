class_name EggTip
extends RefCounted
## THE MOTHER'S EGG TOOLTIP (the owner, 2026-10-30 09:06; docs/egg_tooltips.md): what the egg line over the Brood
## Mother ("4/10  4.8s · 00:35", BroodNew.draw) means, with her real numbers: her eggs and her clutch's size (her
## stage sets it), the next egg and the time to a full clutch, her laying in all (eggs a minute, one every N s) and
## every lever that makes it (BroodNew.lay_rate: her stage, the Sires near her, Mound Turtles on new ground, her harvest
## veterancy), and what stops her laying. One text for every place that explains her laying: the map label (hover,
## Hud._hover_at), the EGGS chip on her unit card (CardTips) and her card's LAYING button (Hud._nb_buttons).
## Only for her own side (and spectators, the demo): shown_to.


## Who may read it: the side that sees her egg line (BroodNew.draw's rule).
static func shown_to(g: Game, q: Unit) -> bool:
	return q != null and is_instance_valid(q) and not q.dead and q.kind == BroodNew.QUEEN and (q.team == g.human or g.demo or g.spectating())


## {title, stats, body, hint}, already in the player's language.
static func tip(g: Game, q: Unit) -> Dictionary:
	if q == null or not is_instance_valid(q) or q.dead or q.kind != BroodNew.QUEEN:
		return {}
	var lr := BroodNew.lay_rate(g, q)
	var rate := float(lr[0])
	var sx := float(lr[1])
	var nf := int(lr[2])
	var ne := int(lr[3])
	var hv := int(lr[4])
	var et := float(Defs.NB["egg_time"])
	var eggs := int(q.nb.get("eggs", 0))
	var mx := BroodNew.eggs_max(q)
	var st := BroodNew.stage(q)
	var stages: Array = Defs.NB["stages"]
	# the head: her eggs, the next one and a full clutch (the two clocks of her egg line)
	var stats := Loc.t("%d eggs of %d") % [eggs, mx]
	var nl := BroodNew.next_egg_in(q)
	if nl >= 0.0:
		stats += "  ·  " + Loc.t("next egg in %s") % BroodNew.clock_text(nl, true) + "  ·  " + Loc.t("clutch full in %s") % BroodNew.clock_text(BroodNew.full_in(q), false)
	var every := et / maxf(rate, 0.01)
	stats += "\n" + Loc.t("Laying x%.2f: %.1f eggs a minute, one every %.1f s.") % [rate, 60.0 / every, every]
	# the levers, each with its value
	var lines: Array = []
	lines.append(Loc.t("The numbers over her: eggs she holds / her clutch's size, then the time to her next egg (tenths of a second under 10 s) and the time until her clutch is full, at her laying now."))
	var sizes: Array = []
	for i in stages.size():
		sizes.append(Loc.t("stage %d: %d") % [i + 1, int(stages[i]["eggs"])])
	lines.append(Loc.t("Her clutch holds %d at stage %d; GROW raises it (%s).") % [mx, st + 1, ", ".join(sizes)])
	lines.append(Loc.t("At stage 1 with no lever she lays one egg every %d s. Four levers make it faster:") % int(et))
	lines.append("• " + Loc.t("Her stage %d: x%.1f.") % [st + 1, sx])
	var fpct := int(round(float(Defs.NB["father_rate"]) * 100.0))
	if nf > 0:
		var names: Array = BroodNew.fathers_near_list(g, q).map(func(f: Unit) -> String: return Loc.t(String(f.d["name"])))
		lines.append("• " + Loc.t("Sires near her (within %d tiles), their pheromones: %s: +%d%%.") % [int(Defs.NB["father_r"]), ", ".join(names), nf * fpct])
	else:
		lines.append("• " + Loc.t("Sires near her: none (each Sire within %d tiles: +%d%%).") % [int(Defs.NB["father_r"]), fpct])
	var epct := int(round(float(Defs.NB["expansion_rate"]) * 100.0))
	var home := _turtles_home(g, q)
	var tl := Loc.t("Mound Turtles on new ground (%d tiles or more from her and from each other): %d of %d: +%d%%.") % [int(Defs.NB["expansion_tiles"]), ne, int(Defs.NB["expansion_max"]), ne * epct]
	if home > 0:
		tl += " " + Loc.t("%d rooted nearer count for nothing.") % home
	lines.append("• " + tl)
	var hpct := float(Defs.NB["hvet_rate"]) * 100.0
	lines.append("• " + Loc.t("Her veterancy %d of %d (1 for each harvest a grub brings her): +%d%%.") % [hv, int(Defs.NB["hvet_max"]), int(round(hv * hpct))])
	var add := rate / maxf(sx, 0.01) - 1.0
	lines.append(Loc.t("In all: x%.1f x (1 + %.2f) = x%.2f.") % [sx, add, rate])
	# what stops her laying, now first
	var stops: Array = []
	if float(q.nb.get("grow_t", 0.0)) > 0.0:
		stops.append(Loc.t("NOW: she is growing, and lays no eggs until she is done."))
	elif eggs >= mx:
		stops.append(Loc.t("NOW: her clutch is full: she lays again when an egg is used."))
	for f in BroodNew.fathers_near_list(g, q):
		if BroodResearch.busy(f):
			stops.append(Loc.t("NOW: the %s is researching: he fathers no eggs of his line meanwhile (her laying goes on).") % Loc.t(String(f.d["name"])))
	stops.append(Loc.t("Laying stops while she grows and while her clutch is full. A Sire who researches fathers no eggs of his line meanwhile; she keeps laying while she researches."))
	return {"title": Loc.t("The Brood Mother's eggs"), "stats": stats, "body": "\n".join(lines), "hint": " ".join(stops)}


## Her Mound Turtles rooted but too near (to her, or to a counted one): no eggs from them.
static func _turtles_home(g: Game, q: Unit) -> int:
	var counted := BroodNew.expansions(g, q)
	var n := 0
	for u in g.units:
		if u.team == q.team and u.kind == BroodNew.TURTLE and not u.dead and BroodNew.rooted(u) and not counted.has(u):
			n += 1
	return n


# ------------------------------------------------------------------ the egg line on the map

## The egg line's text over her ("Eggs: 4/10  4.8s · 00:35"): BroodNew.draw draws this.
static func label_text(q: Unit) -> String:
	var txt := Loc.t("Eggs: %d/%d") % [int(q.nb.get("eggs", 0)), BroodNew.eggs_max(q)]
	var nl := BroodNew.next_egg_in(q)
	if nl >= 0.0:
		txt += "  " + BroodNew.clock_text(nl, true) + " · " + BroodNew.clock_text(BroodNew.full_in(q), false)
	return txt


const SIZE := 15
const X := -14.0
const HIT_GROW := 5.0


## Where the egg line is, in the world (its whole text, as drawn now; a little slack round it).
static func label_rect(q: Unit) -> Rect2:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label_text(q), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	var base := q.global_position + Vector2(X, q.bar_top() - 6.0)
	return Rect2(base + Vector2(0, -font.get_ascent(SIZE)), Vector2(w, font.get_height(SIZE))).grow(HIT_GROW)


## The Mother whose egg line is under the world point p (one the player may read), or null.
static func at(g: Game, p: Vector2) -> Unit:
	for t in g.n_players():
		var q := BroodNew.queen(g, t)
		if q != null and shown_to(g, q) and q.visible and label_rect(q).has_point(p):
			return q
	return null
