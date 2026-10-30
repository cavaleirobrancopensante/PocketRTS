extends RefCounted
## THE MUSKETEER HEALTH TEST (the owner, 2026-10-30; docs/musket_hp_test.md). A TEST-ONLY override, used by the
## measuring tools (tools/study_musket_hp.gd and its wrappers): the game's numbers (Defs.UNITS musketeer 70, Defs.ARMOURED
## musketeer +20) are NOT changed. Called every frame, it gives every Musketeer on the map the variant's health:
## `base` light (the Musketeer), `base + arm_bonus` armoured (the Guardsman), keeping each man's share of his health,
## and treating an Armour refit as the variant would (+arm_bonus health, as the game gives +20).
##   const MH := preload("res://tools/musket_hp.gd")
##   MH.apply(game, 55.0, 10.0)        (55 / 65)          MH.parse("55/65") -> [55.0, 10.0] ("" or "now" -> [0, 0]: off)
## Only the "musketeer" kind (light and armoured). The Dragoon (a Musketeer on a horse, 90) is left as he is.


static func parse(s: String) -> Array:
	if s == "" or s == "now" or s == "70/90":
		return [0.0, 0.0]
	var p := s.split("/")
	var b := float(p[0])
	var a := float(p[1]) if p.size() > 1 else b + float(Defs.ARMOURED["musketeer"]["hp"])
	return [b, a - b]


static func apply(g, base: float, arm_bonus: float) -> void:
	if base <= 0.0 or g == null:
		return
	var game_bonus := float(Defs.ARMOURED["musketeer"]["hp"])
	for u in g.units:
		if not is_instance_valid(u) or u.dead or u.kind != "musketeer":
			continue
		var want: float = base + (arm_bonus if u.armoured else 0.0)
		var was = u.get_meta("mhp_arm") if u.has_meta("mhp_arm") else null
		if absf(u.max_hp - want) < 0.01 and was == u.armoured:
			continue
		if was != null and was == false and u.armoured:
			# (refitted with Armour: the game added +20 to what he had; the variant adds arm_bonus)
			u.hp = clampf(u.hp - game_bonus + arm_bonus, 1.0, want)
		else:
			# (a new man, or his health changed under him (mount, revival): keep his share)
			u.hp = maxf(1.0, u.hp * want / maxf(1.0, u.max_hp))
		u.max_hp = want
		u.d["hp"] = want
		u.set_meta("mhp_arm", u.armoured)
