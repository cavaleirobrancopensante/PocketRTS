extends SceneTree
## MUSIC MIX (brood-tune, 2026-10-30; docs/music_brood.md "Whose music you hear"). The automatic picker (Music._next,
## setting "vanilla") over 200 picks a moment, for each faction against each other one: the opening, calm and skirmish
## pieces are always your own; in a full battle about ENEMY_CHANCE (20%) are the enemy's battle pieces. Same rule for
## every faction. "faction" mode: never the enemy's.
##   godot --headless --fixed-fps 30 --script res://tools/test_music_mix.gd

const N := 200
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("  FAIL ", what)


func _run() -> void:
	seed(7)
	var m := Music.new()
	for f in ["crown", "brood", "clockwork"]:
		for e in ["crown", "brood", "clockwork"]:
			if e == f:
				continue
			for mode in ["vanilla", "faction"]:
				m.mode = mode
				var line := "%-9s v %-9s %-7s" % [f, e, mode]
				for mood in ["open", "peace", "skirmish", "battle"]:
					m._faction = Music.FACTION_KEY[f]
					m._enemies = [Music.FACTION_KEY[e]]
					m._recent.clear()
					m._current = ""
					var own := 0
					for i in N:
						var s: String = m._next(mood)
						m._current = s
						if s.begins_with(m._faction + "_"):
							own += 1
					var pct := 100.0 * own / N
					line += "  %s %3d%% own" % [mood, int(round(pct))]
					if mood != "battle" or mode == "faction":
						_check(own == N, "%s: %s should be all its own (%d%%)" % [line, mood, int(pct)])
					else:
						_check(pct >= 70.0 and pct <= 90.0, "%s: battle should be about 80%% own (%d%%)" % [line, int(pct)])
				print(line)
	m.free()
	print("music mix: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed > 0 else 0)
