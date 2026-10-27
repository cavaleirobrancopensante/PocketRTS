extends SceneTree
## The Clockwork's music: every mood the game asks for (open, skirmish, battle, peace) has Clockwork
## pieces, the new pieces have the roles tools/music/clock_more.py gives them, the faction has twenty
## pieces, and every piece named in scripts/music_tracks.gd has its file in assets/music.
##   godot --headless --script res://tools/test_music_clock.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var M: GDScript = load("res://scripts/music.gd")
	var titles: Dictionary = M.titles()
	# every piece the music player lists has its file
	var missing: Array = []
	for stem in titles:
		if not FileAccess.file_exists("res://assets/music/%s.ogg" % stem):
			missing.append(stem)
	check(missing.is_empty(), "every piece in music_tracks.gd has its .ogg %s" % str(missing))
	var all: Array = M.all_pieces("clock")
	check(all.size() == 20, "the Clockwork has 20 pieces (%d)" % all.size())
	var want := {
		"open": ["clock_battle_6", "clock_battle_7", "clock_peace"],
		"skirmish": ["clock_battle_8", "clock_battle_9", "clock_battle_10"],
		"battle": ["clock_battle", "clock_battle_2", "clock_battle_3", "clock_battle_4", "clock_battle_5",
			"clock_battle_11", "clock_battle_12", "clock_battle_13"],
		"peace": ["clock_peace", "clock_peace_2", "clock_peace_3", "clock_peace_4", "clock_peace_5",
			"clock_peace_6", "clock_peace_7"],
	}
	for mood in want:
		var got: Array = M.pieces("clock", mood)
		var lack: Array = []
		for s in want[mood]:
			if not got.has(s):
				lack.append(s)
		check(not got.is_empty() and lack.is_empty(), "mood %s: %s %s" % [mood, str(got), ("missing " + str(lack)) if lack else ""])
	# an opening or skirmish piece is never also played as the full battle
	for s in M.pieces("clock", "battle"):
		check(not M.ROLES.has(s), "%s plays as the full battle and has no other role" % s)
	# the new pieces have titles
	for s in ["clock_battle_6", "clock_battle_7", "clock_battle_8", "clock_battle_9", "clock_battle_10",
			"clock_battle_11", "clock_battle_12", "clock_battle_13", "clock_peace_6", "clock_peace_7"]:
		check(str(titles.get(s, "")) != "", "%s has a title (%s)" % [s, titles.get(s, "")])
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
