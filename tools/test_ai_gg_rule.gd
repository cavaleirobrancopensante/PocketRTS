extends SceneTree
## The computer's "gg" rule as a pure function (scripts/ai_resign.gd), no match needed:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_gg_rule.gd
## A hopeless position says gg; a comeback position (income and production, no army) never does; the
## early game never does (except no hall and no workers); thresholds are the AIResign constants.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## A middle-game position; each case changes a few fields.
func view(over := {}) -> Dictionary:
	var v := {"clock": 600.0, "halls": 2, "halls_peak": 2, "workers": 14, "workers_peak": 14, "army": 800.0,
		"enemy_army": 900.0, "production": 3, "gold": 150, "hall_cost": 400}
	v.merge(over, true)
	return v


func _initialize() -> void:
	# an even game: nothing
	check(AIResign.verdict(view()) == "", "an even game is not hopeless")
	# no army against a big one, but income and production: a comeback is possible
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0})) == "", "no army but income and production: NOT hopeless")
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0, "halls": 1, "workers": 5})) == "", "no army, one hall, 5 workers, production: NOT hopeless (it can rebuild)")
	# broken: no army, no production, lost workers
	var broken := view({"army": 20.0, "enemy_army": 2000.0, "production": 0, "workers": 4, "halls": 1, "gold": 50})
	check(AIResign.verdict(broken) == "broken", "no army, no production, workers lost, hall lost: hopeless (broken)")
	# the same with workers but no production and no money
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0, "production": 0, "workers": 6, "halls": 1})) == "broken",
		"no production and little gold: hopeless")
	# ... but a bank to build with is a way back
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0, "production": 0, "workers": 6, "halls": 1, "gold": 900})) == "",
		"no production but 900 gold and workers: NOT hopeless")
	# production with no income (no workers) and no money
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0, "production": 2, "workers": 0, "halls": 1, "gold": 10})) == "broken",
		"production but no income and no gold: hopeless")
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0, "production": 2, "workers": 0, "halls": 1, "gold": 600})) == "",
		"production, no workers, 600 gold in hand: NOT hopeless")
	# not losing (never lost a hall or workers): no
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 2000.0, "production": 0, "gold": 10})) == "",
		"never lost workers or halls: NOT hopeless (it is not being beaten down)")
	# an army that is more than a sliver of theirs
	check(AIResign.verdict(view({"army": 300.0, "enemy_army": 2000.0, "production": 0, "workers": 4, "halls": 1, "gold": 50})) == "",
		"army at 15% of theirs: NOT hopeless (margin)")
	# an enemy army seen that is small proves nothing
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 150.0, "production": 0, "workers": 4, "halls": 1, "gold": 50})) == "",
		"enemy army seen is tiny: NOT hopeless")
	# nothing seen of the enemy: no cheating, no verdict
	check(AIResign.verdict(view({"army": 0.0, "enemy_army": 0.0, "production": 0, "workers": 4, "halls": 1, "gold": 50})) == "",
		"it has seen no enemy army: NOT hopeless")
	# no hall
	var nohall := view({"army": 100.0, "enemy_army": 2000.0, "halls": 0, "workers": 5, "gold": 100})
	check(AIResign.verdict(nohall) == "no_hall", "no hall, cannot afford one, small army: hopeless (no_hall)")
	check(AIResign.verdict(view({"army": 100.0, "enemy_army": 2000.0, "halls": 0, "workers": 5, "gold": 500})) == "",
		"no hall but workers and gold for a new one: NOT hopeless")
	check(AIResign.verdict(view({"army": 1500.0, "enemy_army": 2000.0, "halls": 0, "workers": 5, "gold": 100})) == "",
		"no hall but a big army: NOT hopeless")
	# the early game
	check(AIResign.verdict(view({"clock": 240.0, "army": 20.0, "enemy_army": 2000.0, "production": 0, "workers": 2, "halls": 1, "gold": 0})) == "",
		"before 5:00 a broken position does not resign")
	check(AIResign.verdict(view({"clock": 240.0, "army": 100.0, "enemy_army": 2000.0, "halls": 0, "workers": 5, "gold": 0})) == "",
		"before 5:00 no hall alone does not resign")
	check(AIResign.verdict(view({"clock": 120.0, "army": 0.0, "enemy_army": 0.0, "halls": 0, "workers": 0, "gold": 0, "production": 1})) == "wiped",
		"before 5:00 with no hall AND no workers it may")
	check(AIResign.verdict(view({"army": 3000.0, "enemy_army": 0.0, "halls": 0, "workers": 0})) == "",
		"no hall and no workers but a big army alive: not wiped")
	# the sustain times are constants
	check(AIResign.sustain_for("wiped") < AIResign.sustain_for("broken") and AIResign.sustain_for("broken") >= 45.0, "wiped is quick, the rest wait about a minute")
	check(AIResign.MIN_CLOCK >= 300.0 and AIResign.MAX_SAYS <= 2, "constants: 5:00 minimum, at most two gg")
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
