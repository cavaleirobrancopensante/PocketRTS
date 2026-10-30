extends SceneTree
## THE BROOD COMPUTER'S TIMELINE (docs/brood_ai.md, docs/ai_build_timelines.md "Brood"): one profile per run, a Hard
## Brood (side 0) against a Hard Crown that defends but never attacks (`peaceful`, as tools/measure_ai_timelines.gd), so
## each milestone is the plan's own build. Checks the profile's milestones (MILESTONES: the latest time each may come),
## that the computer never banks more than BANK_MAX food for long, keeps its grubs under the plan's cap, and that it
## made no script error. Prints the timeline.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_brood.gd [-- profile:balanced] [map:greenhold] [seed:3]
## Profiles: xrush, rush, timing, balanced, economy, air (run each: tools/test_ai_brood.sh).
var main: Node
var t := 0.0
var g
var profile := "balanced"
var map := "greenhold"
var seed_ := 3
var fails := 0
var ai: AIBroodNew
var seen := {}                  # milestone -> clock
var bank_long := 0.0            # seconds in a row with food over BANK_MAX
var bank_worst := 0.0
var grubs_max := 0
var natural_at := Vector2.INF         # the natural's turtle spot (the eco plans), from the start

## The latest each milestone may come (game seconds), per profile. "attack": the first wave leaves; "raptors8": 8
## Raptors at once; "stage2"/"stage3": the Mother grown; "venom"/"storm": the Sire came; "research": the first research
## done; "pack": Pack Hunt done (and before the first attack where the plan wants it); "far": a Mound Turtle on new ground;
## "scout": a scout sent.
## THE OWNER'S BUILD (docs/brood_eco.md; the plans with "eco"): "natural": the first Mound Turtle on new ground is ON THE
## NATURAL (the nearest turtle spot by walk, ExpansionSpots, as AIBroodNew._nb_eco_sites ranks them at the start);
## "maw3": the third Rootmaw rooted (on new ground: the natural's far edge); "watch": the grub on watch sent out (the
## Crown: the foot of its ramp); "income6": food earned by 6:00 at least INCOME6 (the profile's measured figure, less a
## margin). (Against the Crown, Balanced does not attack this early: its wall rule waits for Spitters or
## Brutes with Battering Horns, docs/brood_ai.md.)
const MILESTONES := {
	"xrush": {"tyrant": 45.0, "raptors8": 180.0, "attack": 190.0},
	"rush": {"tyrant": 100.0, "scout": 90.0, "attack": 270.0},
	"timing": {"tyrant": 150.0, "scout": 90.0, "watch": 90.0, "natural": 200.0, "maw3": 330.0, "stage2": 420.0, "far": 200.0, "income6": 360.0, "attack": 600.0},
	"balanced": {"tyrant": 160.0, "scout": 90.0, "watch": 90.0, "natural": 200.0, "maw3": 330.0, "venom": 450.0, "stage2": 450.0, "far": 200.0, "income6": 360.0, "pack": 720.0},
	"economy": {"tyrant": 170.0, "scout": 90.0, "watch": 90.0, "natural": 200.0, "maw3": 330.0, "far": 200.0, "venom": 450.0, "stage2": 500.0, "income6": 360.0, "research": 560.0},
	"air": {"tyrant": 160.0, "scout": 90.0, "watch": 90.0, "natural": 200.0, "maw3": 330.0, "stage2": 380.0, "storm": 560.0, "income6": 360.0, "attack": 600.0},
}
## (measured on 0.22.0, Greenhold seed 3, with about a minute's margin: docs/ai_build_timelines.md "Brood")
## food earned by 6:00 (the "income6" milestone, checked at its time), per profile
const INCOME6 := {"timing": 1300, "balanced": 1300, "economy": 1300, "air": 1300}
const BANK_MAX := 900
const BANK_FOR := 60.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"profile": profile = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _mark(k: String) -> void:
	if not seen.has(k):
		seen[k] = g.clock
		print("  %5.0f s  %s" % [g.clock, k])


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": profile},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
		for a in main.game.ais:
			if a.team == 1:
				a.peaceful = true
			elif a is AIBroodNew:
				ai = a
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ms: Dictionary = MILESTONES.get(profile, {})
	var last := 0.0
	for k in ms:
		last = maxf(last, float(ms[k]))
	_watch()
	if g.clock >= last + 30.0 or g.over:
		_report(ms)
		quit()
	return false


func _watch() -> void:
	var q := BroodNew.queen(g, 0)
	if q == null:
		return
	if BroodNew.father(g, 0, BroodNew.FATHER) and not BroodRoot.in_cocoon(BroodNew.father(g, 0, BroodNew.FATHER)):
		_mark("tyrant")
	if BroodNew.father(g, 0, BroodNew.DILO) and not BroodRoot.in_cocoon(BroodNew.father(g, 0, BroodNew.DILO)):
		_mark("venom")
	if BroodNew.father(g, 0, BroodNew.PTERO) and not BroodRoot.in_cocoon(BroodNew.father(g, 0, BroodNew.PTERO)):
		_mark("storm")
	if BroodNew.stage(q) >= 1:
		_mark("stage2")
	if BroodNew.stage(q) >= 2:
		_mark("stage3")
	if BroodNew.count_of(g, 0, "raptor") >= 8:
		_mark("raptors8")
	for k in BroodResearch.keys():
		if g.has_tech(0, k):
			_mark("research")
	if g.has_tech(0, "nb_pack_hunt"):
		_mark("pack")
	if not BroodNew.expansions(g, q).is_empty():
		_mark("far")
	if natural_at == Vector2.INF and ai._eco() and g.clock > 1.0:
		var sites: Array = ai._nb_eco_sites(q)
		natural_at = BroodRoot.feet_at(BroodNew.TURTLE, sites[0]["tc"]) if not sites.is_empty() else Vector2(-1, -1)
		print("  the natural: %s, %d tiles from the Mother" % [str(natural_at), int(natural_at.distance_to(q.position) / Defs.TILE)])
	for e in BroodNew.expansions(g, q):
		if natural_at != Vector2.INF and e.position.distance_to(natural_at) < 3.0 * Defs.TILE:
			_mark("natural")
	var rm := 0
	for u in g.units:
		if u.team == 0 and not u.dead and u.kind == BroodNew.MAW and BroodNew.rooted(u):
			rm += 1
	if rm >= 3:
		_mark("maw3")
	if g.clock >= 360.0 and not seen.has("income6"):
		print("  food earned by 6:00: %d" % int(g.stats[0]["gold"]))
		if int(g.stats[0]["gold"]) >= int(INCOME6.get(profile, 0)):
			_mark("income6")
		else:
			seen["income6"] = 99999.0
	for n in ai.note:
		var s := String(n[1])
		if s.begins_with("attacks with"):
			_mark("attack")
		elif s.begins_with("sends a"):
			_mark("scout")
			if s.contains("watch"):
				_mark("watch")
	grubs_max = maxi(grubs_max, BroodNew.count_of(g, 0, "grub"))
	var food := int(g.players[0]["gold"])
	if food > BANK_MAX:
		bank_long += 1.0 / 30.0          # (--fixed-fps 30: one frame)
		bank_worst = maxf(bank_worst, bank_long)
	else:
		bank_long = 0.0


func _report(ms: Dictionary) -> void:
	print("Brood computer, %s, %s seed %d, against a peaceful Hard Crown:" % [profile, map, seed_])
	for k in ms:
		var at := float(seen.get(k, -1.0))
		check(at >= 0.0 and at <= float(ms[k]), "%s by %d s (at %s)" % [k, int(ms[k]), ("%d s" % int(at)) if at >= 0.0 else "never"])
	if ms.has("pack") and ms.has("attack") and seen.has("attack"):
		check(seen.has("pack") and float(seen["pack"]) <= float(seen["attack"]), "Pack Hunt before the first attack")
	check(bank_worst < BANK_FOR, "never more than %d food banked for %d s (longest %.0f s)" % [BANK_MAX, int(BANK_FOR), bank_worst])
	check(grubs_max <= int(ai.plan["grubs"]) + 2, "grubs at most the plan's %d, +2 for the ones turning into something (most %d)" % [int(ai.plan["grubs"]), grubs_max])
	print("%d failures" % fails)
