extends SceneTree
## The music has a piece for every moment: for each faction the opening, skirmish, full battle and
## calm moods each have pieces, every piece named in scripts/music_tracks.gd has its file, and every
## piece given a role in Music.ROLES / OPEN_CALM is a real piece of that faction.
## The Clockwork's opening and skirmish pieces come with its own new set: until that set is in
## (no Clockwork piece has a role yet) those two checks are skipped, not failed.
##   godot --headless --script res://tools/test_music_roles.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var titles: Dictionary = Music.titles()
	check(titles.size() > 30, "music_tracks.gd lists the pieces (%d)" % titles.size())
	# every listed piece has its file (and an import, so the game can load it)
	var missing: Array = []
	for stem in titles:
		var path: String = Music.MUSIC_PATH % stem
		if not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".import"):
			missing.append(stem)
	check(missing.is_empty(), "every piece in music_tracks.gd has its .ogg and .import %s" % str(missing))
	# roles name real pieces, of a known kind
	for stem in Music.ROLES:
		check(titles.has(stem), "ROLES names a listed piece: " + stem)
		check(Music.ROLES[stem] in ["open", "skirmish"], "ROLES gives %s a known role" % stem)
		check(String(stem).contains("_battle"), "a role piece is a battle piece: " + stem)
	for stem in Music.OPEN_CALM:
		check(titles.has(stem) and String(stem).contains("_peace"), "OPEN_CALM names a calm piece: " + stem)
	# every faction has pieces for every mood
	for f in ["crown", "brood", "clock"]:
		var has_roles := false
		for stem in Music.ROLES:
			if String(stem).begins_with(f + "_"):
				has_roles = true
		for mood in ["open", "skirmish", "battle", "peace"]:
			var got: Array = Music.pieces(f, mood)
			if (mood == "open" or mood == "skirmish") and f == "clock" and not has_roles and got.is_empty():
				print("SKIP  %s %s: the Clockwork's new set is not in yet" % [f, mood])
				continue
			check(not got.is_empty(), "%s has %s pieces (%d): %s" % [f, mood, got.size(), ", ".join(got)])
		# a skirmish or opening piece never turns up as the full battle
		for stem in Music.pieces(f, "battle"):
			check(not Music.ROLES.has(stem), "%s full battle pool has no role piece (%s)" % [f, stem])
	# the Brood's twenty, in the Crown's shape
	check(Music.all_pieces("brood").size() == 20, "the Brood has 20 pieces (%d)" % Music.all_pieces("brood").size())
	check(Music.pieces("brood", "open").size() >= 2, "the Brood has its two opening pieces")
	check(Music.pieces("brood", "skirmish").size() == 3, "the Brood has three skirmish pieces")
	check(Music.pieces("brood", "battle").size() == 8, "the Brood has eight full battle pieces")
	check(Music.pieces("brood", "peace").size() == 7, "the Brood has seven calm pieces")
	print("%d failed" % fails if fails else "all passed")
	quit(1 if fails else 0)
