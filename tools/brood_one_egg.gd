extends RefCounted
## THE NEW SACRIFICE RULE, for the measuring tools (tools/measure_brood_ai.gd, tools/play_brood_3.gd; docs/brood_eco.md):
## the owner (2026-10-30 07:15) changes SACRIFICE so that the young of ONE egg give back only ONE egg between them
## (two Raptors offered up gave the Mother two eggs; spoils unchanged). That fix is made on its own branch (brood-fixes);
## until it is in, the tools take the extra eggs back here so the numbers they measure are the new rule's. Each young
## creature offered up beyond the first of its egg's brood (2 Raptors to an egg, 3 with BIGGER CLUTCH) takes back the egg
## the Mother was given for it (or the next one she lays). Since 0.22.3 (brood-fixes merged) the game does it itself
## (BroodNew.devour: egg parts), so this is OFF by default; `onegg:1` switches it on for measuring an older build.
var on := false
var _seen := 0
var _n := {}                    # kind -> young of it offered up so far
var _debt := 0                  # eggs still to take back (the Mother had none when one was due)
var taken := 0


func tick(g: Game, t: int) -> void:
	if not on:
		return
	var q := BroodNew.queen(g, t)
	if q == null:
		return
	var n := int(g.stats[t].get("sacrificed", 0))
	while _seen < n:
		_seen += 1
		# (the computer offers up Raptors; a Spitter's brood is the same size)
		var spawn := 3 if g.has_tech(t, "nb_clutch_raptor") else 2
		_n["raptor"] = int(_n.get("raptor", 0)) + 1
		if int(_n["raptor"]) % spawn != 1 and spawn > 1:
			_debt += 1          # (not the first young of its egg: its egg was already given back)
	if _debt > 0 and int(q.nb.get("eggs", 0)) > 0:
		var k := mini(_debt, int(q.nb["eggs"]))
		q.nb["eggs"] = int(q.nb["eggs"]) - k
		_debt -= k
		taken += k
